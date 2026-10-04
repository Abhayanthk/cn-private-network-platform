<div align="center">

# Evidence

[← README](../README.md)

</div>

> [!NOTE]
> Each folder corresponds to one Phase 1 task, and each file name describes what it shows. The commands are documented in [`docs/`](../docs/).

| Folder | Task | Assessment area |
| :-- | :-- | :-- |
| [`A-lan/`](A-lan/) | A · Private LAN | LAN + DNS |
| [`B-dns/`](B-dns/) | B · Private DNS | LAN + DNS |
| [`C-backends/`](C-backends/) | C · Backends | Backends + load balancing |
| [`D-load-balancing/`](D-load-balancing/) | D · Reverse proxy + load balancer | Backends + load balancing |
| [`E-tls/`](E-tls/) | E · HTTPS / TLS | TLS |
| [`F-caching/`](F-caching/) | F · Caching | Caching + transport |
| [`G-packet-capture/`](G-packet-capture/) | G · Packet capture | Packet analysis |
| [`failures/`](failures/) | Failure demonstrations | All areas |

<details open>
<summary><b>A · LAN</b></summary>

| File | Content |
| :-- | :-- |
| `mac1-getinfo.png` … `mac4-getinfo.png` | `networksetup -getinfo Wi-Fi` and `ifconfig en0 \| grep -E "inet \|ether"` on each Mac |
| `ping-mac1.png` … `ping-mac4.png` | `ping -c 4` from each Mac to the other three |
| [`topology.png`](A-lan/topology.png) | Network topology diagram ([docs/01](../docs/01-architecture.md#topology)) |
| [`request-flow.png`](A-lan/request-flow.png) | Request flow across the layers ([docs/01](../docs/01-architecture.md#request-flow-across-the-layers)) |

</details>

<details>
<summary><b>B · DNS</b></summary>

| File | Content |
| :-- | :-- |
| `dig-mac1.png` | `dig app.elu.test` on Mac 1 → `SERVER: 127.0.0.1#53` |
| `dig-mac2.png`, `dig-mac3.png`, `dig-mac4.png` | `dig app.elu.test` → answer Mac 2, `SERVER: <Mac 1 IP>#53` |
| `client-dns-settings.png` | `scutil --dns \| grep nameserver \| head -2` |
| `dnsmasq-log.png` | Mac 1: `log stream --predicate 'process == "dnsmasq"' --info` during queries |

</details>

<details>
<summary><b>C · Backends</b></summary>

| File | Content |
| :-- | :-- |
| `backend-a.png` | Mac 3: `lsof -nP -iTCP:3001 -sTCP:LISTEN` → `*:3001`, and `curl -i http://127.0.0.1:3001/api/status` → `X-Backend: A` |
| `backend-b.png` | Mac 4: `lsof` → `*:3002`, `X-Backend: B`, and an ETag identical to Backend A's |
| `backends-from-mac2.png` | Mac 2: direct requests to both backends across the LAN + identical ETags |

</details>

<details>
<summary><b>D · Load balancing</b></summary>

| File | Content |
| :-- | :-- |
| `lb-alternating.png` | Six requests through nginx: `x-backend` A/B alternating, two upstream addresses |
| `backend-a-log.png` | Backend A's request log (Mac 3): every second request |
| `backend-b-log.png` | Backend B's request log (Mac 4): the other requests |

</details>

<details>
<summary><b>E · TLS</b></summary>

| File | Content |
| :-- | :-- |
| `cert-details.png` | `openssl x509 -in app.crt -noout -text \| grep -A1 -E "Issuer\|Subject:\|Alternative"` |
| `curl-tls.png` | `/usr/bin/curl -v` showing TLS version, issuer, SAN match, ALPN |
| `browser-padlock.png` | `https://app.elu.test:8443/api/status` with the certificate viewer open |
| `http-versions.png` | `--http1.1` vs `--http2`, and the `301` redirect from 8080 |

</details>

<details>
<summary><b>F · Caching</b></summary>

| File | Content |
| :-- | :-- |
| `cache-curl.png` | `/api/info` → `cache-control: public, max-age=60` + `etag`; conditional request → `HTTP/2 304`; `/api/status` → `cache-control: no-store` |
| `devtools-cache.png` | Network panel: memory/disk cache hit, then `304` on reload |

</details>

<details>
<summary><b>G · Packet capture</b></summary>

| File | Content |
| :-- | :-- |
| `phase1-full-flow-tls12.pcapng` | Capture with TLS 1.2 forced |
| `phase1-full-flow-tls13.pcapng` | Capture with default TLS 1.3 |
| `ws-dns.png` | Filter `dns.qry.name contains "elu"` |
| `ws-tcp-handshake.png` | Filter `tcp.port == 8443 && tcp.flags.syn == 1` |
| `ws-tls-handshake.png` | Filter `tls.handshake`, Certificate expanded |
| `ws-encrypted-data.png` | Filter `tls.record.content_type == 23` |
| `ws-tls-termination.png` | Filter `tcp.port == 3001`, Follow TCP Stream |
| `ws-seq-ack.png` | One TCP segment expanded |
| `ws-flow-graph.png` | Statistics → Flow Graph |

</details>

<details>
<summary><b>Failure demonstrations</b></summary>

| File | Content |
| :-- | :-- |
| `F1-wrong-dns-server.png` | `NXDOMAIN` from `dig`; `ping` to Mac 2 succeeds |
| `F2-wrong-dns-record.png` | `dig` returns Mac 3; connection to 8443 fails |
| `F3-one-backend-down.png` | All responses `200` from Backend B |
| `F4-both-backends-down.png` | `HTTP/2 502` |
| `F5-wrong-port.png` | Port 9443 refused; `nc -vz` to 8443 succeeds |
| `F3b-machine-offline.png` | Mac 4 offline; all responses from Backend A |

</details>

The configuration files that were actually running are kept next to the templates in [`config/live/`](../config/): `dnsmasq.conf` from Mac 1 and `team-https.conf` from Mac 2.

> [!CAUTION]
> Private keys (`team-CA.key`, `app.key`) are never stored here. `.gitignore` excludes `*.key`.
