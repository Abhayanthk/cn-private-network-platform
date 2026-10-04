#!/usr/bin/env bash
# Mac 2 only. Creates the team CA and the server certificate for app/api.$TEAM.test,
# then gives nginx its copy. Keys stay in ~/team-certs and never enter this repo.
set -euo pipefail

ENV_FILE="${CN_ENV:-$HOME/cn-team.env}"
# shellcheck source=/dev/null
. "$ENV_FILE"
WORK="$HOME/team-certs"
NGINX_CERTS="$(brew --prefix)/etc/nginx/certs"

# A new CA would silently break trust on every Mac that already trusts the old one.
if [ -e "$WORK/team-CA.key" ]; then
  echo "$WORK/team-CA.key already exists. Delete ~/team-certs first if you really want a new CA." >&2
  exit 1
fi

mkdir -p "$WORK" "$NGINX_CERTS"
cd "$WORK"

# 1) Team root CA: self-signed, the trust anchor every client imports
openssl genrsa -out team-CA.key 4096
openssl req -x509 -new -nodes -key team-CA.key -sha256 -days 365 \
  -out team-CA.pem -subj "/CN=$TEAM Local Root CA"

# 2) Server key + certificate signing request
openssl genrsa -out app.key 2048
openssl req -new -key app.key -out app.csr -subj "/CN=app.$TEAM.test"

# 3) Extensions: browsers match the hostname against SAN, not CN
cat > app.ext <<EXT
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:app.$TEAM.test, DNS:api.$TEAM.test
EXT

# 4) CA signs the server certificate
openssl x509 -req -in app.csr -CA team-CA.pem -CAkey team-CA.key \
  -CAcreateserial -out app.crt -days 365 -sha256 -extfile app.ext

# 5) Verify the chain and show what clients will see
openssl verify -CAfile team-CA.pem app.crt
openssl x509 -in app.crt -noout -text | grep -A1 -E "Issuer|Subject:|Alternative"

# 6) nginx's copy; the private key readable by the owner only
cp app.crt app.key "$NGINX_CERTS/"
chmod 600 "$NGINX_CERTS/app.key"

echo
echo "Done. AirDrop $WORK/team-CA.pem (never the .key) to Macs 1, 3 and 4, then trust it on every Mac:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain team-CA.pem"
