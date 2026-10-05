```md
# MAC 1 — DNS RECORDING

## 1. Introduce

Say:

> "This is Mac 1. It provides DNS for our private team network."

Run:

```bash
clear
echo "=== MAC 1 ==="
echo "IP: $(ipconfig getifaddr en0)"
sudo brew services list | grep dnsmasq
```

Say:

> "Mac 1 is running dnsmasq and its current IP is 10.7.16.231."

---

## 2. Show DNS Configuration

Run:

```bash
echo "=== DNS CONFIG ==="
grep -E "^(listen-address|host-record)" "$(brew --prefix)/etc/dnsmasq.conf"
```

Say:

> "The private domains app.elu.test and api.elu.test both point to Mac 2."

Expected:

```text
app.elu.test → 10.7.7.100
api.elu.test → 10.7.7.100
```

---

## 3. Test Private DNS

Run:

```bash
echo "=== PRIVATE DNS ==="
dig app.elu.test
```

Say:

> "The DNS server resolves app.elu.test to Mac 2."

Then:

```bash
dig api.elu.test
```

Say:

> "The API domain also resolves to Mac 2."

---

## 4. Test Normal Internet DNS

Run:

```bash
echo "=== INTERNET DNS ==="
dig google.com
```

Say:

> "Normal internet DNS also continues to work through the DNS forwarder."

---

## 5. Show Mac 1 → Mac 2 Connectivity

Run:

```bash
echo "=== MAC 1 TO MAC 2 ==="
ping -c 4 10.7.7.100
```

Say:

> "Mac 1 can reach Mac 2 over the local network."

---

# F2 — WRONG DNS RECORD

Say:

> "Now I will demonstrate a DNS failure by intentionally pointing app.elu.test to Mac 3 instead of Mac 2."

Run:

```bash

sudo sed -i '' "s/^host-record=app.elu.test,.*/host-record=app.elu.test,10.7.7.0/" "$(brew --prefix)/etc/dnsmasq.conf"

sudo brew services restart dnsmasq
sleep 2

dig +short app.elu.test
```

Say:

> "The DNS server is now incorrectly resolving app.elu.test to Mac 3."

Expected:

```text
10.7.7.0
```

Then run:

```bash
curl -sS --max-time 5 https://app.elu.test:8443/api/status
```

Say:

> "The request fails because DNS sent the client to the wrong machine."

---

# RESTORE DNS

Run:

```bash
sudo sed -i '' \
"s/^host-record=app.elu.test,.*/host-record=app.elu.test,$MAC2_IP/"

sudo brew services restart dnsmasq
sleep 2

dig +short app.elu.test
```

Say:

> "I have restored the correct DNS record."

Expected:

```text
10.7.7.100
```

## END MAC 1
```

This is the complete **Mac 1 recording only**: normal DNS → DNS forwarding → connectivity → F2 failure → restore.
