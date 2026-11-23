#!/usr/bin/env bash
# Extension E evidence from Mac 3, run while app.elu.test points at the standby edge (Mac 3).
. "$HOME/cn-team.env"
clear
echo "== Extension E: DNS cutover to standby edge (Mac 3)   $(date '+%Y-%m-%d %H:%M:%S') =="
echo
echo "\$ dig @Mac1 / @Mac4 app.elu.test +short"
echo "  Mac 1 ($MAC1_IP): $(dig @"$MAC1_IP" app.$TEAM.test +short +time=2 +tries=1 | tail -1)"
echo "  Mac 4 ($MAC4_IP): $(dig @"$MAC4_IP" app.$TEAM.test +short +time=2 +tries=1 | tail -1)   (Mac 3 = $MAC3_IP)"
echo
echo "\$ dig app.$TEAM.test | grep -E '^app'      (TTL = 2nd column)"
dig app.$TEAM.test | grep -E "^app"
echo
echo "\$ curl https://app.$TEAM.test:8443/api/status   (by name, 4x)"
for i in 1 2 3 4; do /usr/bin/curl -s -m5 -D - -o /dev/null https://app.$TEAM.test:8443/api/status | grep -iE '^HTTP|x-backend|x-edge' | tr -d '\r' | paste -sd' ' -; done
echo
echo "\$ curl --resolve ...:$MAC2_IP   (old edge, still up for cached clients)"
/usr/bin/curl -s -m5 -D - -o /dev/null --resolve app.$TEAM.test:8443:"$MAC2_IP" https://app.$TEAM.test:8443/api/status | grep -iE '^HTTP|x-backend|x-edge' | tr -d '\r' | paste -sd' ' -
echo
echo "\$ tail -4 nginx access.log on Mac 3   (who used the standby edge)"
tail -4 "$(brew --prefix)/var/log/nginx/access.log" | cut -c1-80
