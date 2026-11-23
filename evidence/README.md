<div align="center">

# Evidence

[← README](../README.md)

</div>

> [!NOTE]
> Evidence required by the project brief (section 9, Evidence Folder): DNS resolution, curl/browser output with headers, Wireshark captures of DNS, the TCP handshake and the TLS handshake, the HTTP caching demonstration, and all failure scenarios. Each folder corresponds to one Phase 1 task; the commands are documented in [`docs/`](../docs/).

| Folder | File | Content | Task |
| :-- | :-- | :-- | :-- |
| [`A-lan/`](A-lan/) | [`topology.png`](A-lan/topology.png) | Network topology diagram | A |
| | [`request-flow.png`](A-lan/request-flow.png) | Request flow across the protocol layers | A |
| | `ping-mac1.png` … `ping-mac4.png` | `ping -c 4` from each Mac to the other three (all six pairs) | A |
| [`B-dns/`](B-dns/) | `dig-mac3.png`, `dig-mac4.png` | `dig app.elu.test` on two client Macs → answer Mac 2, `SERVER: <Mac 1 IP>#53` | B |
| [`C-backends/`](C-backends/) | `backends-from-mac2.png` | Direct requests from Mac 2 to Mac 3:3001 and Mac 4:3002 → `X-Backend: A` / `B` | C |
| [`D-load-balancing/`](D-load-balancing/) | `lb-alternating.png` | Repeated requests through nginx → `x-backend` A/B alternating | D |
| [`E-tls/`](E-tls/) | `curl-tls.png` | `/usr/bin/curl -v`: TLS version, issuer, SAN match, request and response headers | E |
| | `browser-padlock.png` | `https://app.elu.test:8443/api/status` with no certificate warning | E |
| [`F-caching/`](F-caching/) | `cache-curl.png` | `cache-control` + `etag` on `/api/info`, conditional request → `304`, `no-store` on `/api/status` | F |
| [`G-packet-capture/`](G-packet-capture/) | `phase1-full-flow-tls12.pcapng` | Saved capture of one request (TLS 1.2 forced) | G |
| | `ws-dns.png` | DNS query and response (filter `dns.qry.name contains "elu"`) | G |
| | `ws-tcp-handshake.png` | SYN, SYN-ACK, ACK to port 8443 | G |
| | `ws-tls-handshake.png` | ClientHello, ServerHello, Certificate, ChangeCipherSpec | G |
| [`failures/`](failures/) | `F1-wrong-dns-server.png` | `NXDOMAIN` from `dig`; `ping` to Mac 2 succeeds | 6.3 |
| | `F2-wrong-dns-record.png` | `dig` returns Mac 3; connection to 8443 fails | 6.3 |
| | `F3-one-backend-down.png` | Backend A stopped; all responses `200` from Backend B | 6.3 |
| | `F4-both-backends-down.png` | Both backends stopped; `HTTP/2 502` | 6.3 |
| | `F5-wrong-port.png` | Port 9443 refused; port 8443 succeeds | 6.3 |

The configuration files that actually ran are kept in [`config/live/`](../config/): `dnsmasq.conf` from Mac 1 and `team-https.conf` from Mac 2.

## Phase 2 Evidence

| Folder | File | Content | Extension |
| :-- | :-- | :-- | :-: |
| [`phase2/A-backup-dns/`](phase2/A-backup-dns/) | `mac1-primary-off.png` / `.txt` | dnsmasq stopped on Mac 1; primary times out, Mac 4 answers | A |
| [`phase2/B-ttl/`](phase2/B-ttl/) | `mac1-ttl-30.png` / `.txt` | TTL 30 on Mac 1 and Mac 4 | B |
| | `mac1-record-changed.png` / `.txt` | `app` changed to Mac 3 on both DNS servers | B |
| [`phase2/C-firewall/`](phase2/C-firewall/) | `mac1-blocked-client.png` / `.txt` | Direct requests to 3001/3002 time out; through the edge `200` | C |
| [`phase2/E-cutover/`](phase2/E-cutover/) | `mac1-cutover.png` / `.txt` | `app` moved to the standby edge; `x-edge` shows Mac 3 | E |
| [`phase2/A-backup-dns/`](phase2/A-backup-dns/) | `mac2-two-dns-servers` | Mac 2 lists Mac 1 and Mac 4 as resolvers; Mac 4 answers | A |
| | `mac2-primary-down` | Mac 1 stopped: `dig` answered by Mac 4, `curl` still `200` | A |
| [`phase2/B-ttl/`](phase2/B-ttl/) | `mac2-ttl-and-cache` | TTL 30 on both servers, macOS cache filled | B |
| | `mac2-dig-vs-cache` | Right after the change: `dig` new IP, `dscacheutil` old IP | B |
| | `mac2-after-ttl` | Cache switched to the new IP by itself after 17 s | B |
| [`phase2/C-firewall/`](phase2/C-firewall/) | `mac2-allowed-client` | Mac 2 (allowed) reaches 3001 and 3002 directly while pf is on | C |
| [`phase2/D-failover/`](phase2/D-failover/) | `mac2-before` | Both backends up: A, B, A, B | D |
| | `mac2-a-down` | Backend A stopped: 6 × `200` from B, nginx log `Connection refused` | D |
| | `mac2-a-back` | A restarted, after 10 s: A, B again | D |
| [`phase2/E-cutover/`](phase2/E-cutover/) | `mac2-standby-ready` | Standby tested with `curl --resolve` before DNS moved | E |
| | `mac2-client-y` | Client Y after the change: new IP, `x-edge` = Mac 3 | E |
| [`phase2/A-backup-dns/`](phase2/A-backup-dns/) | `mac3-dig-server-mac4.jpg` | Mac 3 with Mac 1 stopped: `SERVER: 10.7.15.46` (Mac 4) | A |
| | `mac3-dig-while-mac1-down` | Mac 3 lists both resolvers; Mac 1 times out, Mac 4 answers, `curl` still `200` | A |
| [`phase2/C-firewall/`](phase2/C-firewall/) | `mac3-firewall-on-rules.jpg` | pf rules loaded on Mac 3: only Mac 2 may reach 3001 | C |
| | `mac3-pf-on-off` | Rules active, edge still reaches A; then rules flushed, pf back off, `pf.conf` unchanged | C |
| [`phase2/D-failover/`](phase2/D-failover/) | `mac3-backend-a-stopped` | Backend A stopped on Mac 3: 6 × B, first request retried A → B; A back after 10 s | D |
| [`phase2/E-cutover/`](phase2/E-cutover/) | `mac3-standby-ready` | Standby nginx on Mac 3: `nginx -t`, listening on 8443, `x-edge` = Mac 3, TLS verify ok | E |
| | `mac3-cutover-live` | Both DNS servers → Mac 3; requests by name served by Mac 3's edge; access log shows client Y (Mac 2) | E |
| [`phase2/F-troubleshooting/`](phase2/F-troubleshooting/) | `mac1-practice-fault` | Practice fault: ladder stops at TCP, `Connection refused`, nginx not running on Mac 2 | F |

Each `mac2-*` and `mac3-*` file has a `.txt` (raw command output) and a `.png` (the same output as an image); the two `mac3-*.jpg` files are direct screenshots.

Report: [docs/10-phase2-report.md](../docs/10-phase2-report.md).

> [!CAUTION]
> Private keys (`team-CA.key`, `app.key`) are never stored here. `.gitignore` excludes `*.key`.
