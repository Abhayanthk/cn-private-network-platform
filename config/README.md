<div align="center">

# Configuration Bundle

[← README](../README.md)

</div>

| File | Machine | Installed at | Documentation |
| :-- | :-: | :-- | :-- |
| [`cn-team.env.example`](cn-team.env.example) | all | `~/cn-team.env` | [02 · Setup flow](../docs/02-setup-flow.md#shared-settings-file) |
| [`dnsmasq.conf.template`](dnsmasq.conf.template) | Mac 1 | `$(brew --prefix)/etc/dnsmasq.conf` | [03 · DNS](../docs/03-dns.md) |
| [`nginx/team-http.conf.template`](nginx/team-http.conf.template) | Mac 2 | `…/etc/nginx/servers/team-http.conf` (stage 1 only) | [05 · Load balancer](../docs/05-load-balancer.md) |
| [`nginx/team-https.conf.template`](nginx/team-https.conf.template) | Mac 2 | `…/etc/nginx/servers/team-https.conf` (final) | [05](../docs/05-load-balancer.md) · [06 · TLS](../docs/06-tls.md) |

## Templates

Words in capitals (`MAC1_IP`, `MAC2_IP`, `MAC3_IP`, `MAC4_IP`, `COLLEGE_DNS`, `TEAM`, `NGINX_DIR`) are placeholders, replaced with the values from the shared settings file `~/cn-team.env`. Every Mac uses the same settings file, so all configuration files agree on every IP.

The replacement is a plain `sed` substitution, for example on Mac 1:

```bash
source ~/cn-team.env
sed -e "s/MAC1_IP/$MAC1_IP/g" -e "s/MAC2_IP/$MAC2_IP/g" \
    -e "s/COLLEGE_DNS/$COLLEGE_DNS/g" -e "s/TEAM/$TEAM/g" \
    config/dnsmasq.conf.template > "$(brew --prefix)/etc/dnsmasq.conf"
```

`config/live/` holds copies of the files that were actually running during the Phase 1 demonstration: `dnsmasq.conf` from Mac 1 and `team-https.conf` from Mac 2.

> [!NOTE]
> Homebrew's main `nginx.conf` is never edited. It already contains `include servers/*;`, so placing our file in `servers/` is sufficient. Only one of `team-http.conf` and `team-https.conf` may be present at a time; otherwise nginx reports `duplicate upstream "team_backends"`.

<details>
<summary><b>Applying changes</b></summary>

```bash
# Mac 1
dnsmasq --test && sudo brew services restart dnsmasq

# Mac 2 (nginx runs without sudo; ports 8080/8443 do not need root)
nginx -t && brew services restart nginx
```

</details>

TLS certificates and keys are not configuration files and are not committed: see [06 · TLS](../docs/06-tls.md).
