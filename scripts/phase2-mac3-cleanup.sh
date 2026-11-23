#!/usr/bin/env bash
# Mac 3, Extension E Step 5: retire the standby edge after the DNS record is back on Mac 2, then a final health check.
. "$HOME/cn-team.env"
NGINX_DIR="$(brew --prefix)/etc/nginx"
clear
echo "== Mac 3 cleanup: standby edge off   $(date '+%Y-%m-%d %H:%M:%S') =="
echo
echo "\$ dig @Mac1 / @Mac4 app.$TEAM.test +short     (both must be Mac 2 = $MAC2_IP)"
echo "  Mac 1: $(dig @"$MAC1_IP" app.$TEAM.test +short +time=2 +tries=1 | tail -1)    Mac 4: $(dig @"$MAC4_IP" app.$TEAM.test +short +time=2 +tries=1 | tail -1)"
echo
echo "Waiting 30 s (one TTL) so no client still has Mac 3 cached ..."
sleep 30
echo
echo "\$ brew services stop nginx"
brew services stop nginx 2>&1 | tail -1
echo "\$ rm $NGINX_DIR/certs/app.key"
rm -f "$NGINX_DIR/certs/app.key"
[ -f "$NGINX_DIR/certs/app.key" ] && echo "  ✘ app.key still there" || echo "  ✔ private key deleted"
lsof -nP -iTCP:8443 -sTCP:LISTEN >/dev/null 2>&1 && echo "  ✘ something still listens on 8443" || echo "  ✔ nothing listens on 8443 on Mac 3"
echo
echo "== Final health check (from Mac 3) =="
./scripts/demo.sh check 2>&1 | tail -4
echo
echo "\$ curl https://app.$TEAM.test:8443/api/status   (4x)"
for i in 1 2 3 4; do /usr/bin/curl -s -m5 -D - -o /dev/null https://app.$TEAM.test:8443/api/status | grep -iE '^HTTP|x-backend|x-edge' | tr -d '\r' | paste -sd' ' -; done
echo
lsof -nP -iTCP:3001 -sTCP:LISTEN >/dev/null 2>&1 && echo "  ✔ Backend A still running on *:3001" || echo "  ✘ Backend A not running"
echo "Done. Post \"standby off\" in the group chat."
