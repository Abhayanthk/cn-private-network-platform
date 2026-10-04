#!/usr/bin/env bash
# Fill the config templates with the values from ~/cn-team.env.
# Writes config/rendered/, so the exact files the Macs ran can be committed as evidence.
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${CN_ENV:-$HOME/cn-team.env}"
# shellcheck source=/dev/null
. "$ENV_FILE"
NGINX_DIR="${NGINX_DIR:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)/etc/nginx}"

for var in TEAM MAC1_IP MAC2_IP MAC3_IP MAC4_IP COLLEGE_DNS; do
  if [ -z "${!var:-}" ] || [ "${!var}" = CHANGE_ME ]; then
    echo "$var is missing or still CHANGE_ME in $ENV_FILE" >&2
    exit 1
  fi
done

render() {
  sed -e "s/MAC1_IP/$MAC1_IP/g" -e "s/MAC2_IP/$MAC2_IP/g" \
      -e "s/MAC3_IP/$MAC3_IP/g" -e "s/MAC4_IP/$MAC4_IP/g" \
      -e "s/COLLEGE_DNS/$COLLEGE_DNS/g" -e "s|NGINX_DIR|$NGINX_DIR|g" \
      -e "s/TEAM/$TEAM/g" "$1" > "$2"
  echo "wrote $2"
}

mkdir -p config/rendered
render config/dnsmasq.conf.template           config/rendered/dnsmasq.conf
render config/nginx/team-http.conf.template   config/rendered/nginx-team-http.conf
render config/nginx/team-https.conf.template  config/rendered/nginx-team-https.conf
