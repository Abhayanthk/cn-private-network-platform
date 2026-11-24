<div align="center">

# 10 · Phase 2 Report

**Harden, recover and troubleshoot the Phase 1 network.**

[← README](../README.md) · [Architecture](01-architecture.md) · [Evidence](../evidence/README.md)

</div>

> [!NOTE]
> This report covers the Mac 1 (DNS) and Mac 2 (edge) sides of Phase 2: Extensions A to E. Extension F (troubleshooting challenge) is added by the team after the evaluation.

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

## Resilience Tests and Results

| Ext | Test | Result | Evidence |
| :-: | :-- | :-- | :-- |
| A | Stop dnsmasq on Mac 1 | No dnsmasq process. `dig @10.7.16.231` times out. `dig @10.7.15.46` (Mac 4) still returns `app.elu.test` → 10.7.7.100 | [`mac1-primary-off.txt`](../evidence/phase2/A-backup-dns/mac1-primary-off.txt) |
| B | Set `local-ttl=30` | `dig` shows TTL 30 on Mac 1 and on Mac 4 | [`mac1-ttl-30.txt`](../evidence/phase2/B-ttl/mac1-ttl-30.txt) |
| B | Change `app` to Mac 3 on both DNS servers | Both servers answer 10.7.1.186 | [`mac1-record-changed.txt`](../evidence/phase2/B-ttl/mac1-record-changed.txt) |
| C | Mac 1 connects directly to the backends while pf is on | `curl -m 3` to 10.7.1.186:3001 and 10.7.15.46:3002 both time out. Through the edge: `HTTP/2 200` | [`mac1-blocked-client.txt`](../evidence/phase2/C-firewall/mac1-blocked-client.txt) |
| C | Same direct requests after pf is off | 3001 returns `X-Backend: A`, 3002 returns `X-Backend: B` | observed in the live session |
| E | Change `app` to the standby edge on Mac 3 | Both DNS servers answer 10.7.1.186. Mac 1 reaches `x-edge: aryans-macbook-pro-9.local` | [`mac1-cutover.txt`](../evidence/phase2/E-cutover/mac1-cutover.txt) |
| D | Backend A stopped on Mac 3, Mac 2 sends 6 requests | All 6 `HTTP/2 200` from B; nginx error log shows `connect() failed (61: Connection refused)` for 10.7.1.186:3001 | [`mac2-a-down.txt`](../evidence/phase2/D-failover/mac2-a-down.txt) |
| D | Backend A restarted, wait 10 s (`fail_timeout`) | A, B, A, B again | [`mac2-a-back.txt`](../evidence/phase2/D-failover/mac2-a-back.txt) |
| A | Mac 2 resolves with Mac 1 stopped | `dig` answered by `SERVER: 10.7.15.46` (Mac 4), `curl` still `HTTP/2 200` | [`mac2-primary-down.txt`](../evidence/phase2/A-backup-dns/mac2-primary-down.txt) |
| B | Mac 2 compares server and cache right after the change | `dig` returns 10.7.1.186 (new), `dscacheutil` still 10.7.7.100 (old); cache switches after 17 s | [`mac2-dig-vs-cache.txt`](../evidence/phase2/B-ttl/mac2-dig-vs-cache.txt), [`mac2-after-ttl.txt`](../evidence/phase2/B-ttl/mac2-after-ttl.txt) |
| C | Mac 2 (the allowed client) connects directly while pf is on | 3001 `X-Backend: A`, 3002 `X-Backend: B` | [`mac2-allowed-client.txt`](../evidence/phase2/C-firewall/mac2-allowed-client.txt) |
| E | Standby tested before the DNS change, then Mac 2 as client Y | `--resolve` to Mac 3 returns Mac 3's `x-edge`; after the change Mac 2 also reaches Mac 3's edge | [`mac2-standby-ready.txt`](../evidence/phase2/E-cutover/mac2-standby-ready.txt), [`mac2-client-y.txt`](../evidence/phase2/E-cutover/mac2-client-y.txt) |
| A | Mac 3 resolves with Mac 1 stopped | Resolvers Mac 1 + Mac 4; `dig @10.7.16.231` times out; `dig` answered by `SERVER: 10.7.15.46`, `curl` still `HTTP/2 200` | [`mac3-dig-while-mac1-down.txt`](../evidence/phase2/A-backup-dns/mac3-dig-while-mac1-down.txt) |
| C | pf on Mac 3: only Mac 2 (10.7.7.100) may reach 3001 | 3 rules loaded in anchor `com.apple/cn`; through the edge A and B still alternate; after `-F all` and releasing the pf token, pf is disabled again and `/etc/pf.conf` matches the rollback copy | [`mac3-pf-on-off.txt`](../evidence/phase2/C-firewall/mac3-pf-on-off.txt) |
| D | Backend A stopped on Mac 3, requests sent from Mac 3 | 6 × `x-backend: B`; first `x-upstream-addr: 10.7.1.186:3001, 10.7.15.46:3002` (same request retried on B); after restart + 10 s A is back | [`mac3-backend-a-stopped.txt`](../evidence/phase2/D-failover/mac3-backend-a-stopped.txt) |
| E | Standby nginx on Mac 3 with Mac 2's config and certificate | `nginx -t` OK, listening on 8443, `x-edge: aryans-macbook-pro-9.local`, `SSL certificate verify ok`; during the cutover both DNS servers answer 10.7.1.186 and Mac 3's access log shows client Y (10.7.7.100). Afterwards: waited one TTL, stopped nginx, deleted `app.key` | [`mac3-standby-ready.txt`](../evidence/phase2/E-cutover/mac3-standby-ready.txt), [`mac3-cutover-live.txt`](../evidence/phase2/E-cutover/mac3-cutover-live.txt) |
| F | Practice fault: nginx stopped on Mac 2 | Ladder from Mac 1: DNS and IP pass, TCP `Connection refused` on 8443 and every other port, so nginx was not running | [`mac1-practice-fault.txt`](../evidence/phase2/F-troubleshooting/mac1-practice-fault.txt) |
| F | Practice fault set on Mac 3: Backend A bound to `127.0.0.1` only | `lsof` shows `127.0.0.1:3001`; local request `200`, request to 10.7.1.186:3001 refused, so the edge served only B. Fixed by restarting `server.py A 3001` (`*:3001`) | [`mac3-fault-backend-a-localhost.txt`](../evidence/phase2/F-troubleshooting/mac3-fault-backend-a-localhost.txt), [`mac3-fixed-backend-a.txt`](../evidence/phase2/F-troubleshooting/mac3-fixed-backend-a.txt) |
| F | Practice fault on Mac 2, diagnosed from Mac 3: upstream port 3001 → 3009 | First four rungs pass; HTTP `200` but only B. Backend A answers directly, and `x-upstream-addr: 10.7.1.186:3009` points to the wrong port in nginx | [`mac3-diag-mac2-upstream-port.txt`](../evidence/phase2/F-troubleshooting/mac3-diag-mac2-upstream-port.txt) |
| F | Practice fault on Mac 1, diagnosed from Mac 3: `app` record → Mac 4's IP | Rung 1 answers 10.7.15.46 (wrong); TCP 8443 refused because Mac 4 runs no edge. `dig @Mac1` wrong, `dig @Mac4` right, so the record on Mac 1 | [`mac3-diag-mac1-wrong-record.txt`](../evidence/phase2/F-troubleshooting/mac3-diag-mac1-wrong-record.txt) |
| F | Practice fault on Mac 4, diagnosed from Mac 3: Backend B down | DNS, TCP, TLS pass; HTTP `200` but only A; `nc` to 10.7.15.46:3002 refused (not a timeout), so B was not listening | [`mac3-diag-mac4-backend-b-down.txt`](../evidence/phase2/F-troubleshooting/mac3-diag-mac4-backend-b-down.txt) |
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
| Every request answered by Backend B only | HTTP (edge) | nginx's `upstream` still had Mac 3's old IP 10.7.7.0; error log: `upstream timed out … 10.7.7.0:3001` | Change the `server` line to 10.7.1.186, `nginx -t`, restart nginx. A changed IP must also be fixed in the nginx config, not only in `cn-team.env` |
| `X-Edge $hostname` printed `app.elu.test` on Mac 2 | DNS (reverse) | Mac 2 has no fixed HostName, so macOS takes it from reverse DNS, and dnsmasq's `host-record` maps 10.7.7.100 back to `app.elu.test` | Use a fixed label (`X-Edge "mac2-edge"`) |

## Learning Summary

**Extension A, backup DNS.** A second resolver on Mac 4 holds the same records as Mac 1, and clients list both. With dnsmasq stopped on Mac 1, name resolution kept working through Mac 4. A DNS failure and an application failure look different: when all DNS servers are down, the lookup fails (`Could not resolve host`); when a backend is down but DNS works, the name resolves and the edge returns an error such as `502`.

**Extension B, TTL and controlled change.** dnsmasq answers its own records with TTL 0 by default, so clients never cached them. With `local-ttl=30` a client keeps an answer for 30 seconds, so after a record change a client may still use the old IP until its cached answer expires. Because there are two DNS servers, a record change has to be made on both at once, otherwise different clients get different answers. This is why production migrations lower the TTL before a cutover.

**Extension C, service isolation.** A pf rule on each backend Mac lets only Mac 2 reach ports 3001 and 3002 and drops everything else. From Mac 1 a direct connection times out because the firewall drops the packet silently, whereas a closed port would answer `Connection refused`. Requests through the edge still work, so the backends are reachable only by the component that should reach them.

**Extension E, DNS-based edge migration.** A second nginx on Mac 3 serves the same site. Changing the `app` record to Mac 3 moves new lookups to the standby edge without touching any client, and clients with a cached answer move after the TTL expires. The old edge has to stay up for at least one TTL.

**Extension D, failover.** nginx uses a passive health check: it only notices a dead backend on a real request. With `max_fails=1 fail_timeout=10s`, one failed connect marks Backend A down for 10 seconds, and `proxy_next_upstream` retries the same request on B, so the client never sees an error. When A came back, nginx tried it again after the 10 seconds and the A, B rotation returned. Mac 2 itself stays a single point of failure, which is what Extension E addresses.

**Extension F, troubleshooting challenge.** *To be added by the team after the evaluation.*

<div align="center">

[← README](../README.md)

</div>
