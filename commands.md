```bash
clear
echo "=== MAC 1 DNS ==="
echo "IP: $(ipconfig getifaddr en0)"
sudo brew services list | grep dnsmasq

echo "=== DNS CONFIG ==="
grep -E "^(listen-address|host-record)" "$(brew --prefix)/etc/dnsmasq.conf"

echo "=== PRIVATE DNS ==="
dig app.elu.test
dig api.elu.test

echo "=== INTERNET DNS ==="
dig google.com

echo "=== MAC 1 → MAC 2 ==="
ping -c 4 10.7.7.100
```

### F2

```bash
echo "=== F2: WRONG DNS ==="

sudo sed -i '' \
"s/^host-record=app.elu.test,.*/host-record=app.elu.test,$MAC3_IP/"

sudo brew services restart dnsmasq
sleep 2

dig +short app.elu.test

curl -sS --max-time 5 https://app.elu.test:8443/api/status
```

### Restore

```bash
echo "=== RESTORE DNS ==="

sudo sed -i '' \
"s/^host-record=app.elu.test,.*/host-record=app.elu.test,$MAC2_IP/"

sudo brew services restart dnsmasq
sleep 2

dig +short app.elu.test
```