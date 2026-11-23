#!/usr/bin/env bash
# Phase 2 helper for Mac 3 (Backend A, firewall, standby edge).
# Wraps the steps of "CN Phase 2 - 3 Mac 3" so each one is a single command. Every command it runs is printed first.
#
#   ./scripts/phase2-mac3.sh <command>
#
#   check           Step 0  is this Mac ready? (settings, IP, Backend A, nginx)
#   dns-both        Step 1  use Mac 1 + Mac 4 as DNS servers            (sudo)
#   dns-test        Step 1  flush cache and show which DNS server answers (sudo)
#   fw-on           Step 2  firewall: only Mac 2 may reach port 3001     (sudo)
#   fw-status       Step 2  show our firewall rules                      (sudo)
#   fw-off          Step 2  remove our rules, put pf back as it was      (sudo)
#   standby-setup   Step 4  install Mac 2's config + cert from ~/Downloads and start nginx
#   standby-test    Step 4  ask this Mac's nginx directly (must show x-edge + x-backend)
#   standby-stop    Step 5  stop nginx and delete the private key
#   stop                    end of session: DNS back to automatic, firewall rules removed (sudo)
#
#   CN_ENV=/path/to/env ./scripts/phase2-mac3.sh …   to use a settings file other than ~/cn-team.env

set -u

ENV_FILE="${CN_ENV:-$HOME/cn-team.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Settings file not found: $ENV_FILE  (copy config/cn-team.env.example to ~/cn-team.env and fill it in)" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$ENV_FILE"

CURL=/usr/bin/curl
PORT=3001                                   # Backend A
PF_ANCHOR="com.apple/cn"                    # macOS pf.conf already loads every com.apple/* anchor
PF_RULES="$HOME/cn-pf.rules"
PF_TOKEN_FILE="$HOME/.cn-pf-token"          # pf "enable" reference: lets fw-off undo exactly what fw-on did
PF_ROLLBACK="$HOME/pf.conf.rollback"
NGINX_DIR="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/etc/nginx"

if [ -t 1 ]; then
  BOLD=$(tput bold); DIM=$(tput dim); RED=$(tput setaf 1); GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3); CYAN=$(tput setaf 6); RESET=$(tput sgr0)
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

title() { printf '\n%s%s━━ %s ━━%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
note()  { printf '%s%s%s\n' "$DIM" "$1" "$RESET"; }
say()   { printf '%s%s%s\n' "$BOLD" "$1" "$RESET"; }
run()   { printf '%s$ %s%s\n' "$YELLOW" "$1" "$RESET"; eval "$1"; }
pass()  { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$1"; }
fail()  { printf '  %s✘%s %s\n' "$RED" "$RESET" "$1"; }

need_settings() {
  local missing=0 v
  for v in TEAM MAC1_IP MAC2_IP MAC3_IP MAC4_IP; do
    if [ -z "${!v:-}" ] || [ "${!v}" = CHANGE_ME ]; then fail "$v is not set in $ENV_FILE"; missing=1; fi
  done
  [ "$missing" = 0 ] || { echo "Fix $ENV_FILE first." >&2; exit 1; }
  APP="app.${TEAM}.test"
}

my_ip() { ipconfig getifaddr en0 2>/dev/null; }

cmd_check() {
  title "Step 0: is Mac 3 ready?"
  need_settings
  pass "settings: TEAM=$TEAM  Mac1=$MAC1_IP  Mac2=$MAC2_IP  Mac3=$MAC3_IP  Mac4=$MAC4_IP"
  local ip; ip=$(my_ip)
  if [ "$ip" = "$MAC3_IP" ]; then pass "this Mac's Wi-Fi IP ($ip) matches MAC3_IP"
  else fail "this Mac's Wi-Fi IP is ${ip:-unknown}, but MAC3_IP says $MAC3_IP: update ~/cn-team.env (and tell the team)"; fi
  if lsof -nP -iTCP:$PORT -sTCP:LISTEN 2>/dev/null | grep -q "\*:$PORT"; then pass "Backend A listens on *:$PORT"
  else fail "Backend A is not listening on *:$PORT  →  python3 backend/server.py A $PORT"; fi
  if command -v nginx >/dev/null; then pass "nginx installed ($(nginx -v 2>&1 | sed 's/.*\///'))"
  else fail "nginx not installed  →  brew install nginx"; fi
  if [ -f "$PF_ROLLBACK" ]; then pass "firewall rollback copy: $PF_ROLLBACK"
  else fail "no firewall rollback copy  →  cp /etc/pf.conf $PF_ROLLBACK"; fi
  note "Current DNS servers: $(networksetup -getdnsservers Wi-Fi | tr '\n' ' ')"
}

cmd_dns_both() {
  title "Step 1 (A): use Mac 1 and Mac 4 for DNS"
  need_settings
  note "Wait for \"backup DNS ready\" from Mac 4 first."
  run "sudo networksetup -setdnsservers Wi-Fi $MAC1_IP $MAC4_IP"
  run "networksetup -getdnsservers Wi-Fi"
  note "Expected: 2 lines, Mac 1 ($MAC1_IP) then Mac 4 ($MAC4_IP)."
}

cmd_dns_test() {
  title "Step 1 (A): who answers DNS now?"
  need_settings
  note "Run this after \"primary down\" from Mac 1."
  run "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
  run "dig $APP | grep -E 'SERVER|^$APP|refused|timed out'"
  note "Expected while Mac 1 is off: SERVER = Mac 4 ($MAC4_IP). Screenshot this."
}

cmd_fw_on() {
  title "Step 2 (C): firewall on port $PORT (only Mac 2 allowed)"
  need_settings
  [ -f "$PF_ROLLBACK" ] || run "cp /etc/pf.conf $PF_ROLLBACK"
  cat > "$PF_RULES" <<EOF
pass in quick on lo0 all
pass in quick proto tcp from $MAC2_IP to any port $PORT
block drop in quick proto tcp from any to any port $PORT
EOF
  say "Rules written to $PF_RULES:"; cat "$PF_RULES"
  run "sudo pfctl -a $PF_ANCHOR -f $PF_RULES 2>&1 | grep -v -e 'flushing of rules' -e 'present in the main ruleset' -e 'ALTQ' || true"
  # -E enables pf and returns a reference token; fw-off releases that token, so pf ends up exactly as it was before.
  local out token
  printf '%s$ sudo pfctl -E%s\n' "$YELLOW" "$RESET"
  out=$(sudo pfctl -E 2>&1); echo "$out" | grep -v ALTQ
  token=$(echo "$out" | sed -n 's/^Token : //p')
  [ -n "$token" ] && echo "$token" > "$PF_TOKEN_FILE"
  run "sudo pfctl -a $PF_ANCHOR -s rules"
  note "Expected: 3 rules with Mac 2's real IP ($MAC2_IP). Screenshot it, then post \"firewall on\"."
}

cmd_fw_status() {
  title "Firewall status"
  run "sudo pfctl -s info 2>/dev/null | grep Status"
  run "sudo pfctl -a $PF_ANCHOR -s rules 2>/dev/null"
}

cmd_fw_off() {
  title "Step 2 (C): firewall off"
  run "sudo pfctl -a $PF_ANCHOR -F all 2>&1 | grep -v ALTQ || true"
  if [ -f "$PF_TOKEN_FILE" ]; then
    run "sudo pfctl -X $(cat "$PF_TOKEN_FILE") 2>&1 | grep -v ALTQ || true"
    rm -f "$PF_TOKEN_FILE"
  fi
  run "sudo pfctl -a $PF_ANCHOR -s rules 2>/dev/null"
  note "(nothing above = our rules are gone)"
  if diff -q /etc/pf.conf "$PF_ROLLBACK" >/dev/null 2>&1; then pass "/etc/pf.conf unchanged (matches $PF_ROLLBACK)"
  else fail "/etc/pf.conf differs from $PF_ROLLBACK"; fi
  note "Post \"firewall off\"."
}

cmd_standby_setup() {
  title "Step 4 (E): standby nginx edge"
  need_settings
  note "Needs: firewall off on Mac 4, and team-https.conf + app.crt + app.key from Mac 2 in ~/Downloads."
  local f missing=0
  for f in team-https.conf app.crt app.key; do
    if [ -f "$HOME/Downloads/$f" ]; then pass "~/Downloads/$f"; else fail "~/Downloads/$f missing"; missing=1; fi
  done
  [ "$missing" = 0 ] || { echo "Wait for the AirDrop from Mac 2. If a file arrived as 'name 2.conf', delete the old copy and ask again." >&2; exit 1; }
  command -v nginx >/dev/null || run "brew install nginx"
  run "mkdir -p '$NGINX_DIR/certs' '$NGINX_DIR/servers'"
  run "mv ~/Downloads/app.crt ~/Downloads/app.key '$NGINX_DIR/certs/'"
  run "chmod 600 '$NGINX_DIR/certs/app.key'"
  run "mv ~/Downloads/team-https.conf '$NGINX_DIR/servers/'"
  run "sed -i '' 's#/opt/homebrew/etc/nginx#$NGINX_DIR#g' '$NGINX_DIR/servers/team-https.conf'"
  say "Upstreams in the config (must be today's Mac 3 / Mac 4 IPs):"
  grep -E '^\s*server [0-9]' "$NGINX_DIR/servers/team-https.conf"
  grep -q "X-Edge" "$NGINX_DIR/servers/team-https.conf" && pass "X-Edge header present" || fail "no X-Edge header: ask Mac 2 to do its Step 6 and send the file again"
  run "nginx -t" || { fail "nginx -t failed: read the file name it prints"; exit 1; }
  run "brew services start nginx"
  sleep 1
  cmd_standby_test
  note "If macOS asks to allow nginx incoming connections: Allow. Then post \"standby ready\"."
}

cmd_standby_test() {
  title "Step 4 (E): ask this Mac's nginx directly"
  need_settings
  local ip; ip=$(my_ip); ip=${ip:-$MAC3_IP}
  run "$CURL -s -D - -o /dev/null --resolve $APP:8443:$ip https://$APP:8443/api/status | grep -iE 'x-edge|x-backend'"
  note "Expected: x-edge: $(hostname | tr 'A-Z' 'a-z') and an x-backend line."
}

cmd_standby_stop() {
  title "Step 5 (E): clean up the standby"
  note "Only after the cutover demo, once Mac 1 and Mac 4 have pointed app back to Mac 2."
  run "brew services stop nginx"
  run "rm -f '$NGINX_DIR/certs/app.key'"
  [ -f "$NGINX_DIR/certs/app.key" ] && fail "app.key still there" || pass "private key deleted"
}

cmd_stop() {
  title "End of session (Mac 3)"
  run "sudo networksetup -setdnsservers Wi-Fi empty"
  run "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
  cmd_fw_off
  note "Then press Ctrl+C in the Backend A window."
}

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
  check)          cmd_check ;;
  dns-both)       cmd_dns_both ;;
  dns-test)       cmd_dns_test ;;
  fw-on)          cmd_fw_on ;;
  fw-status)      cmd_fw_status ;;
  fw-off)         cmd_fw_off ;;
  standby-setup)  cmd_standby_setup ;;
  standby-test)   cmd_standby_test ;;
  standby-stop)   cmd_standby_stop ;;
  stop)           cmd_stop ;;
  *)              usage; exit 1 ;;
esac
