# Deploy llama.cpp behind nginx on `olderthanold.duckdns.org`

This guide lets you run:
- your normal website on `/`
- llama.cpp Web UI + OpenAI-like API on `/llama/`

It solves your VM conflict by **not** running both on port 80 directly.
Instead:
- `nginx` stays public on `80/443`
- `llama-server` runs private on `127.0.0.1:8080`

---

## 0) Architecture (what and why)

```text
Internet (web/phone/other app)
  -> https://olderthanold.duckdns.org/
      nginx (80/443 public)
        /         -> your existing website files
        /llama/   -> proxy to http://127.0.0.1:8080/
                         llama-server (private, local only)
```

Why this is better:
- avoids port-80 conflict (`nginx` vs `llama-server`)
- keeps TLS/domain handling in one place (nginx)
- keeps llama backend hidden from direct internet access

---

## 1) Run llama-server as a systemd service (local bind only)

> You currently run `llama-server` on `--port 80`. Change to `127.0.0.1:8080`.

```bash
# ===== colors for progress messages =====
GREEN='\033[0;32m'   # success
YELLOW='\033[1;33m'  # in-progress
RED='\033[0;31m'     # errors (reserved)
NC='\033[0m'         # reset

echo -e "${YELLOW}[1/6] Writing /etc/systemd/system/llama-server.service ...${NC}"
sudo tee /etc/systemd/system/llama-server.service >/dev/null <<'EOF'
[Unit]
Description=llama.cpp server (LFM2.5-VL-450M)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubun2
WorkingDirectory=/home/ubun2/ai/llama.cpp
ExecStart=/home/ubun2/ai/llama.cpp/build/bin/llama-server \
  -hf ZuzeTt/LFM2.5-VL-450M-GGUF \
  -hff LFM2.5-VL-450M-imatrix-Q8_0.gguf \
  --reasoning off \
  --temp 0.7 \
  --no-mmproj \
  --jinja \
  --repeat-penalty 1.05 \
  -c 8192 \
  --host 127.0.0.1 \
  --port 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}[2/6] Reloading systemd daemon to pick up new unit...${NC}"
sudo systemctl daemon-reload

echo -e "${YELLOW}[3/6] Enabling + starting llama-server at boot and now...${NC}"
sudo systemctl enable --now llama-server.service

echo -e "${YELLOW}[4/6] Checking service status...${NC}"
sudo systemctl status llama-server.service --no-pager

echo -e "${YELLOW}[5/6] Testing local root endpoint...${NC}"
curl -sS http://127.0.0.1:8080/ | head -n 5

echo -e "${YELLOW}[6/6] Testing local health endpoint...${NC}"
curl -sS http://127.0.0.1:8080/health

echo -e "${GREEN}llama-server local backend setup complete.${NC}"
```

### Important flags explained
- `-hf` = Hugging Face model repository.
- `-hff` = exact GGUF file inside that repo.
- `--host 127.0.0.1` = bind only to local loopback (not internet).
- `--port 8080` = backend port for nginx reverse proxy.
- `-c 8192` = context window size.
- `Restart=always` = auto-restart on crash.

---

## 2) Configure nginx reverse proxy on `/llama/`

Edit your active nginx site config for `olderthanold.duckdns.org` and add this inside the correct `server { ... }` block:

```nginx
location /llama/ {
    proxy_pass http://127.0.0.1:8080/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # long generation/streaming support
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    send_timeout 3600;

    # allow larger prompt payloads
    client_max_body_size 64m;

    # optional compatibility for upgraded connections
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

Then validate and reload nginx:

```bash
echo -e "${YELLOW}[nginx] Testing nginx config syntax before reload...${NC}"
sudo nginx -t

echo -e "${YELLOW}[nginx] Reloading nginx without dropping active connections...${NC}"
sudo systemctl reload nginx

echo -e "${GREEN}[nginx] Reload complete.${NC}"
```

---

## 3) Firewall / security expectations

Publicly exposed:
- `80/tcp`
- `443/tcp`

Must stay private:
- `8080/tcp` (do not expose directly)

If using UFW:

```bash
echo -e "${YELLOW}[ufw] Opening HTTP/HTTPS and denying backend 8080...${NC}"
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 8080/tcp
sudo ufw status verbose
```

---

## 4) Validate endpoints

### From VM

```bash
echo -e "${YELLOW}[check] Local llama backend...${NC}"
curl -I http://127.0.0.1:8080/

echo -e "${YELLOW}[check] Public website root through domain...${NC}"
curl -I https://olderthanold.duckdns.org/

echo -e "${YELLOW}[check] Public llama route through nginx...${NC}"
curl -I https://olderthanold.duckdns.org/llama/
```

### OpenAI-like API test (chat completions)

```bash
echo -e "${YELLOW}[api] Testing OpenAI-compatible chat/completions endpoint...${NC}"
curl -sS https://olderthanold.duckdns.org/llama/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [
      {"role":"system","content":"You are a concise assistant."},
      {"role":"user","content":"Say hello in one short sentence."}
    ],
    "temperature": 0.7
  }'
```

Notes:
- Base URL for clients: `https://olderthanold.duckdns.org/llama/v1`
- Typical endpoint: `/chat/completions`

---

## 5) How to call from your other web / phone app

Use OpenAI-compatible client settings:

- `base_url`: `https://olderthanold.duckdns.org/llama/v1`
- `api_key`: any placeholder if client library requires one (unless you add auth)
- `model`: use value accepted by your llama-server build/model route (often any label works with llama.cpp-compatible servers)

Example (JavaScript fetch):

```js
const res = await fetch("https://olderthanold.duckdns.org/llama/v1/chat/completions", {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
    // "Authorization": "Bearer YOUR_KEY" // only if you add auth/protection
  },
  body: JSON.stringify({
    model: "local-model",
    messages: [{ role: "user", content: "Hello from phone web app" }],
    temperature: 0.7
  })
});
const data = await res.json();
console.log(data);
```

---

## 6) Optional hardening (recommended on public internet)

Because `olderthanold.duckdns.org` is public, add protection.

### Option A: Basic Auth on `/llama/`

```bash
echo -e "${YELLOW}[auth] Installing htpasswd tool (apache2-utils)...${NC}"
sudo apt update
sudo apt install -y apache2-utils

echo -e "${YELLOW}[auth] Creating password file for user 'llmuser'...${NC}"
sudo htpasswd -c /etc/nginx/.htpasswd_llama llmuser
```

Then inside `location /llama/`:

```nginx
auth_basic "Restricted LLM";
auth_basic_user_file /etc/nginx/.htpasswd_llama;
```

Reload:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Option B: IP allow-list (if you have static trusted IPs)

```nginx
location /llama/ {
    allow 1.2.3.4;   # your trusted public IP
    deny all;
    proxy_pass http://127.0.0.1:8080/;
    ...
}
```

---

## 7) Operations quick commands

```bash
# service control
sudo systemctl restart llama-server
sudo systemctl status llama-server --no-pager
sudo journalctl -u llama-server -n 100 --no-pager

# nginx control
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx --no-pager
```

---

## Result you should see

- `https://olderthanold.duckdns.org/` -> your normal site
- `https://olderthanold.duckdns.org/llama/` -> llama.cpp web UI
- `https://olderthanold.duckdns.org/llama/v1/chat/completions` -> OpenAI-like API endpoint
