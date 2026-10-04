<div align="center">

# Helper Scripts

[← README](../README.md)

</div>

Optional shortcuts. Every task they perform is documented step by step in [`docs/`](../docs/) and was originally done by hand; the scripts only save typing. All three read the shared settings file `~/cn-team.env` (template: [`config/cn-team.env.example`](../config/cn-team.env.example)).

| Script | Runs on | What it does | Changes anything? |
| :-- | :-: | :-- | :-- |
| [`demo.sh`](demo.sh) | any Mac | Runs the verification commands from the docs (`dig`, `curl`, `nc`) and prints each command before its output | No, read-only |
| [`render-configs.sh`](render-configs.sh) | any Mac | Replaces the placeholders in `config/*.template` with the real IPs and writes the results to `config/rendered/` | Writes `config/rendered/` only |
| [`make-certs.sh`](make-certs.sh) | Mac 2 | Creates the team CA and the server certificate in `~/team-certs` and copies the server certificate and key into nginx's `certs/` folder | Yes; refuses to run if a CA already exists |

## demo.sh

```bash
./scripts/demo.sh <command>
```

| Command | Equivalent manual check | Documented in |
| :-- | :-- | :-- |
| `lan` | `ping` to all four Macs | [01 · Architecture](../docs/01-architecture.md) |
| `dns` | `dig app.elu.test`, `dig api.elu.test`, an unknown name | [03 · DNS](../docs/03-dns.md) |
| `backends` | direct `curl` to both backends + ETag comparison (run on Mac 2) | [04 · Backends](../docs/04-backends.md) |
| `lb` | six requests through nginx, showing `x-backend` and `x-upstream-addr` | [05 · Load balancer](../docs/05-load-balancer.md) |
| `tls` | `curl -v` filtered to TLS version, certificate, SAN and ALPN | [06 · TLS](../docs/06-tls.md) |
| `http` | HTTP/1.1 vs HTTP/2, and the 8080 → 8443 redirect | [06 · TLS](../docs/06-tls.md) |
| `cache` | `Cache-Control` and `ETag`, conditional `304`, `no-store` | [07 · Caching](../docs/07-caching.md) |
| `check [port]` | DNS → TCP → TLS → HTTP in order; stops at the first failing layer and names it | [09 · Failure demonstrations](../docs/09-failure-demos.md) |

## render-configs.sh

```bash
./scripts/render-configs.sh
```

Produces `config/rendered/dnsmasq.conf`, `nginx-team-http.conf` and `nginx-team-https.conf`. It stops with an error if any IP in `~/cn-team.env` is missing or still `CHANGE_ME`.

## make-certs.sh

```bash
./scripts/make-certs.sh          # Mac 2 only
```

Runs the six `openssl` steps from [06 · TLS](../docs/06-tls.md). Private keys stay in `~/team-certs` and are excluded from the repository by `.gitignore`. Afterwards, distribute `~/team-certs/team-CA.pem` (never a `.key` file) and trust it on every Mac.
