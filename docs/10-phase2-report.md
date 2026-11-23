<div align="center">

# 10 · Phase 2 Report

**Harden, recover and troubleshoot the Phase 1 network.**

[← README](../README.md) · [Architecture](01-architecture.md) · [Evidence](../evidence/README.md)

</div>

> [!NOTE]
> This report covers the Mac 1 (DNS) side of Phase 2: Extensions A, B, C and E. Extension D (failover) and Extension F (troubleshooting challenge) are reported by the machines that ran them and are marked below.

## What Changed From Phase 1

| Area | Phase 1 | Phase 2 |
| :-- | :-- | :-- |
| DNS servers | One: Mac 1 | Two: Mac 1 (primary) and Mac 4 (backup), same records |
| Client resolver list | Mac 1 only | Mac 1 first, Mac 4 second |
| DNS answer lifetime | TTL 0 (dnsmasq default for its own records) | TTL 30 s (`local-ttl=30`) |
| Backend ports 3001/3002 | Open to the whole LAN | Limited to Mac 2 with a pf firewall (during the demo) |
| Edge | One nginx on Mac 2 | Standby nginx on Mac 3, reached by a DNS change |
| Mac 3 address | 10.7.7.0 | 10.7.1.186 (changed before Phase 2) |

Configuration that ran on Mac 1 in Phase 2: [`config/live/dnsmasq-phase2.conf`](../config/live/dnsmasq-phase2.conf). The only difference from Phase 1 is the line `local-ttl=30`.

## Resilience Tests and Results (Mac 1)

| Ext | Test | Result | Evidence |
| :-: | :-- | :-- | :-- |
| A | Stop dnsmasq on Mac 1 | No dnsmasq process. `dig @10.7.16.231` times out. `dig @10.7.15.46` (Mac 4) still returns `app.elu.test` → 10.7.7.100 | [`mac1-primary-off.txt`](../evidence/phase2/A-backup-dns/mac1-primary-off.txt) |
| B | Set `local-ttl=30` | `dig` shows TTL 30 on Mac 1 and on Mac 4 | [`mac1-ttl-30.txt`](../evidence/phase2/B-ttl/mac1-ttl-30.txt) |
| B | Change `app` to Mac 3 on both DNS servers | Both servers answer 10.7.1.186 | [`mac1-record-changed.txt`](../evidence/phase2/B-ttl/mac1-record-changed.txt) |
| C | Mac 1 connects directly to the backends while pf is on | `curl -m 3` to 10.7.1.186:3001 and 10.7.15.46:3002 both time out. Through the edge: `HTTP/2 200` | [`mac1-blocked-client.txt`](../evidence/phase2/C-firewall/mac1-blocked-client.txt) |
| C | Same direct requests after pf is off | 3001 returns `X-Backend: A`, 3002 returns `X-Backend: B` | observed in the live session |
| E | Change `app` to the standby edge on Mac 3 | Both DNS servers answer 10.7.1.186. Mac 1 reaches `x-edge: aryans-macbook-pro-9.local` | [`mac1-cutover.txt`](../evidence/phase2/E-cutover/mac1-cutover.txt) |
| D | One backend stopped, requests continue | Reported by Mac 2 / Mac 3 | *to be added by Mac 2 / Mac 3* |
| F | Faculty-injected fault | Diagnosed during the evaluation | *to be added by the team* |

## Troubleshooting Findings

| Finding | Layer | Cause | Fix |
| :-- | :-- | :-- | :-- |
| `demo.sh check` showed a DNS failure on Mac 1 although dnsmasq answered | DNS (client) | Mac 1's own resolver list was `8.8.8.8` and `10.5.7.1`, not itself | `sudo networksetup -setdnsservers Wi-Fi 127.0.0.1` |
| Backend A (Mac 3) timed out on 3001 | TCP | Backend not running or blocked by the Mac's firewall | Start `server.py A 3001` and allow incoming connections |
| Backend B (Mac 4) refused 3002 | TCP | Nothing listening yet | Start `server.py B 3002` |
| Mac 4 returned `app` → Mac 3 while Mac 1 returned Mac 2 (seen before Extension A, and again after the restore in B and in E) | DNS (answer) | The two servers held different records, because the change or restore had not been applied on Mac 4 yet | Apply the change on Mac 4 and restart dnsmasq. Compare both servers with `dig +short app.elu.test @<IP>` after every change |
| Standby edge refused port 8443 | TCP | nginx on Mac 3 was not listening yet | Fixed on Mac 3, then `curl --resolve` returned `HTTP/2 200` |
| Mac 3 unreachable at 10.7.7.0 | IP | DHCP gave Mac 3 a new address (10.7.1.186) | Update `~/cn-team.env` on every Mac |

## Learning Summary

**Extension A, backup DNS.** A second resolver on Mac 4 holds the same records as Mac 1, and clients list both. With dnsmasq stopped on Mac 1, name resolution kept working through Mac 4. A DNS failure and an application failure look different: when all DNS servers are down, the lookup fails (`Could not resolve host`); when a backend is down but DNS works, the name resolves and the edge returns an error such as `502`.

**Extension B, TTL and controlled change.** dnsmasq answers its own records with TTL 0 by default, so clients never cached them. With `local-ttl=30` a client keeps an answer for 30 seconds, so after a record change a client may still use the old IP until its cached answer expires. Because there are two DNS servers, a record change has to be made on both at once, otherwise different clients get different answers. This is why production migrations lower the TTL before a cutover.

**Extension C, service isolation.** A pf rule on each backend Mac lets only Mac 2 reach ports 3001 and 3002 and drops everything else. From Mac 1 a direct connection times out because the firewall drops the packet silently, whereas a closed port would answer `Connection refused`. Requests through the edge still work, so the backends are reachable only by the component that should reach them.

**Extension E, DNS-based edge migration.** A second nginx on Mac 3 serves the same site. Changing the `app` record to Mac 3 moves new lookups to the standby edge without touching any client, and clients with a cached answer move after the TTL expires. The old edge has to stay up for at least one TTL.

**Extension D, failover.** *To be added by Mac 2 / Mac 3.*

**Extension F, troubleshooting challenge.** *To be added by the team after the evaluation.*

<div align="center">

[← README](../README.md)

</div>
