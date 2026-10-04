#!/usr/bin/env bash
# Terminal demo for the Phase 1 video and review.
# Read-only: it never changes DNS settings, configs or services. Every command it runs is printed first.
#
#   ./scripts/demo.sh <command>      e.g.  ./scripts/demo.sh check
#   CN_ENV=/path/to/env ./scripts/demo.sh …   to use a settings file other than ~/cn-team.env

set -u

ENV_FILE="${CN_ENV:-$HOME/cn-team.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Settings file not found: $ENV_FILE  (copy config/cn-team.env.example to ~/cn-team.env and fill it in)" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$ENV_FILE"

CURL=/usr/bin/curl                     # macOS curl reads the System keychain, where the team CA is trusted
APP="app.${TEAM}.test"
API="api.${TEAM}.test"
URL="https://${APP}:8443"

if [ -t 1 ]; then
  BOLD=$(tput bold); DIM=$(tput dim); RED=$(tput setaf 1); GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3); CYAN=$(tput setaf 6); RESET=$(tput sgr0)
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

title() { printf '\n%s%s━━ %s ━━%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
note()  { printf '%s%s%s\n' "$DIM" "$1" "$RESET"; }
run()   { printf '%s$ %s%s\n' "$YELLOW" "$1" "$RESET"; eval "$1"; }
pass()  { printf '  %s✔ %-5s%s %s\n' "$GREEN" "$1" "$RESET" "$2"; }
fail()  { printf '  %s✘ %-5s%s %s\n' "$RED" "$1" "$RESET" "$2"; }

resolve() { dig +short +time=2 +tries=1 "$1" | grep -E '^[0-9.]+$' | tail -1; }

cmd_lan() {
  title "LAN: every Mac answers ping (IP layer)"
  local n var ip
  for n in 1 2 3 4; do
    var="MAC${n}_IP"; ip=${!var}
    if ping -c 1 -t 2 "$ip" >/dev/null 2>&1; then pass "Mac $n" "$ip replies"; else fail "Mac $n" "$ip no reply"; fi
  done
}

cmd_dns() {
  title "DNS: names resolve through Mac 1"
  run "dig $APP | grep -E '^;; SERVER|^$APP'"
  run "dig +short $API"
  run "dig nothere.$TEAM.test | grep -o 'status: [A-Z]*'"
  note "Expected: SERVER = Mac 1 ($MAC1_IP, or 127.0.0.1 on Mac 1), answers = Mac 2 ($MAC2_IP), unknown name = NXDOMAIN"
}

cmd_backends() {
  title "Backends: direct HTTP, bypassing the edge (run on Mac 2)"
  run "$CURL -s -D - -o /dev/null http://$MAC3_IP:3001/api/status | grep -i '^x-backend'"
  run "$CURL -s -D - -o /dev/null http://$MAC4_IP:3002/api/status | grep -i '^x-backend'"
  local a b
  a=$($CURL -sI "http://$MAC3_IP:3001/api/info" | grep -i '^etag' | tr -d '\r')
  b=$($CURL -sI "http://$MAC4_IP:3002/api/info" | grep -i '^etag' | tr -d '\r')
  if [ -n "$a" ] && [ "$a" = "$b" ]; then pass "ETag" "identical on A and B ($a)"; else fail "ETag" "A='$a' B='$b' (must match)"; fi
}

cmd_lb() {
  title "Load balancing: 6 requests through the edge"
  note "$CURL -s -D - -o /dev/null $URL/api/status   (×6, showing x-backend + x-upstream-addr)"
  local i line
  for i in 1 2 3 4 5 6; do
    line=$($CURL -s -D - -o /dev/null "$URL/api/status" | grep -iE '^(x-backend|x-upstream-addr)' | tr -d '\r' | tr '\n' ' ')
    printf '  #%d  %s\n' "$i" "${line:-no response}"
  done
}

cmd_tls() {
  title "TLS: trusted certificate, no -k"
  run "$CURL -sv -o /dev/null $URL/api/status 2>&1 | grep -E 'SSL connection|ALPN: server|subject:|subjectAltName|issuer:|^< HTTP'"
}

cmd_http() {
  title "HTTP versions and redirect"
  run "$CURL -sI --http1.1 $URL/ | head -1"
  run "$CURL -sI --http2 $URL/ | head -1"
  run "$CURL -sI http://$APP:8080/ | grep -iE '^HTTP|^location'"
}

cmd_cache() {
  title "Caching: fresh headers, conditional 304, no-store"
  run "$CURL -sI $URL/api/info | grep -iE '^HTTP|^cache-control|^etag'"
  local etag
  etag=$($CURL -sI "$URL/api/info" | grep -i '^etag' | awk '{print $2}' | tr -d '\r')
  run "$CURL -sI -H 'If-None-Match: $etag' $URL/api/info | head -1"
  run "$CURL -sI $URL/api/status | grep -iE '^HTTP|^cache-control'"
}

# Layered diagnosis: DNS → TCP → TLS → HTTP. Stops at the first broken layer and names it.
cmd_check() {
  local port="${1:-8443}" ip code rc backend
  title "Layered check: https://$APP:$port/api/status"

  ip=$(resolve "$APP")
  if [ -z "$ip" ]; then
    fail "DNS" "no answer for $APP (client DNS not Mac 1? dnsmasq down?)"
    if ping -c 1 -t 2 "$MAC2_IP" >/dev/null 2>&1; then
      note "        IP layer is fine: Mac 2 ($MAC2_IP) still answers ping → only name resolution failed"
    fi
    return 1
  fi
  if [ "$ip" = "$MAC2_IP" ]; then
    pass "DNS" "$APP → $ip (Mac 2)"
  else
    pass "DNS" "$APP → $ip  ${YELLOW}(expected Mac 2 = $MAC2_IP: the record is wrong)${RESET}"
  fi

  if nc -z -G 3 "$ip" "$port" >/dev/null 2>&1; then
    pass "TCP" "$ip:$port accepts connections"
  else
    fail "TCP" "nothing accepted a connection on $ip:$port (transport layer)"
    return 1
  fi

  code=$($CURL -sS -o /dev/null -w '%{http_code}' --max-time 6 "https://$APP:$port/api/status" 2>/dev/null)
  rc=$?
  case $rc in
    0) pass "TLS" "certificate trusted, SAN matches $APP" ;;
    35|51|58|60) fail "TLS" "handshake or certificate failed (curl exit $rc)"; return 1 ;;
    *) fail "TLS" "connection dropped during TLS (curl exit $rc)"; return 1 ;;
  esac

  backend=$($CURL -s -D - -o /dev/null --max-time 6 "https://$APP:$port/api/status" | grep -i '^x-backend' | awk '{print $2}' | tr -d '\r')
  case $code in
    200) pass "HTTP" "200 OK from Backend ${backend:-?}" ;;
    502|503|504) fail "HTTP" "$code: the edge is up, the backends behind it are not (upstream failure)"; return 1 ;;
    *) fail "HTTP" "$code from the application"; return 1 ;;
  esac
}

cmd_all() { cmd_lan; cmd_dns; cmd_lb; cmd_tls; cmd_http; cmd_cache; cmd_check; }

usage() {
  cat <<EOF
Usage: ./scripts/demo.sh <command>

  lan        ping all four Macs
  dns        resolve app/api through Mac 1, plus an NXDOMAIN
  backends   hit Backend A and B directly and compare ETags (run on Mac 2)
  lb         6 requests through nginx: A, B, A, B…
  tls        certificate chain, SAN, TLS version, ALPN
  http       HTTP/1.1 vs HTTP/2, and the 8080 → 8443 redirect
  cache      Cache-Control, ETag → 304, no-store
  check [p]  layered diagnosis DNS → TCP → TLS → HTTP (optional port, e.g. 9443)
  all        lan, dns, lb, tls, http, cache, check
EOF
}

case "${1:-}" in
  lan|dns|backends|lb|tls|http|cache|all) "cmd_$1" ;;
  check) shift; cmd_check "$@" ;;
  *) usage ;;
esac
