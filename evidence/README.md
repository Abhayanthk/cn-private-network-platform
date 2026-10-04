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

> [!CAUTION]
> Private keys (`team-CA.key`, `app.key`) are never stored here. `.gitignore` excludes `*.key`.
