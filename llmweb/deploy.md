# Split deployment: web server + separate llama.cpp server

This document is for your **2-server architecture** (not single-VM):

- **Public web/nginx server**
  - IP: `89.168.88.88`
  - Domain: `olderthanold.duckdns.org`
  - Exposes: `https://olderthanold.duckdns.org/` and proxied `https://olderthanold.duckdns.org/llama/`

- **LLM server (llama.cpp host)**
  - IP: `129.159.30.72`
  - Domain: `llm129.duckdns.org`
  - Runs `llama-server`

Goal:
- Keep your website on `https://olderthanold.duckdns.org/`
- Expose llama UI + OpenAI-like API through:
  - `https://olderthanold.duckdns.org/llama/`
  - `https://olderthanold.duckdns.org/llama/v1/...`

---

## 0) Traffic flow (clear picture)

```text
Client (phone / other web app)
  -> https://olderthanold.duckdns.org/llama/v1/...
     (89.168.88.88, public nginx)
       -> reverse proxy to llm backend on second host
          -> https://llm129.duckdns.org/   (129.159.30.72)
             -> llama-server
```

---

## 1) Configure llama server host (129.159.30.72)

Run llama on LLM host only.

### 1A) Start test command manually first

```bash
# Starts llama-server on port 8080, listening on all interfaces for remote nginx proxy access.
/home/ubun2/ai/llama.cpp/build/bin/llama-server \
  -hf ZuzeTt/LFM2.5-VL-450M-GGUF \
  -hff LFM2.5-VL-450M-imatrix-Q8_0.gguf \
  --reasoning off \
  --temp 0.7 \
  --no-mmproj \
  --jinja \
  --repeat-penalty 1.05 \
  -c 8192 \
  --host 0.0.0.0 \
  --port 8080
```

### 1B) Quick local checks on LLM host

```bash
# Confirms process is listening on 8080.
sudo ss -ltnp | grep 8080 || true

# Basic health probes against local listener.
curl -sS http://127.0.0.1:8080/ | head -n 5
curl -sS http://127.0.0.1:8080/health
```

### 1C) Optional systemd on LLM host

Use script already created:

```bash
# Creates/starts systemd unit for llama-server.
bash /opt/mbin/llmweb/llama_systemd_service.sh
```

If using split-server mode, make sure service uses remote-bind host (`0.0.0.0` or private NIC IP),
not `127.0.0.1`, otherwise web server cannot reach it.

---

## 2) Configure public nginx server (89.168.88.88)

Edit nginx config for `olderthanold.duckdns.org` and add this in the active `server {}` block.

### Option A (recommended): proxy to domain over HTTPS upstream

```nginx
location /llama/ {
    # Forward /llama/* traffic to remote LLM server domain.
    proxy_pass https://llm129.duckdns.org/;
    proxy_http_version 1.1;

    # Preserve request/client context.
    proxy_set_header Host llm129.duckdns.org;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Generation and streaming can be long.
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    send_timeout 3600;

    # Allow larger prompts.
    client_max_body_size 64m;

    # Upgrade headers (safe for streaming/websocket-like behavior).
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### Option B: proxy directly to IP/port over HTTP

```nginx
location /llama/ {
    # Use this only if LLM host does not expose TLS upstream.
    proxy_pass http://129.159.30.72:8080/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    send_timeout 3600;
    client_max_body_size 64m;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

Validate + reload nginx:

```bash
# Syntax test before reload.
sudo nginx -t

# Apply config without hard restart.
sudo systemctl reload nginx

# Confirm nginx healthy.
sudo systemctl status nginx --no-pager
```

---

## 3) Firewall and network rules (important)

### Web server (89.168.88.88)

Public inbound open:
- `80/tcp`
- `443/tcp`

### LLM server (129.159.30.72)

Allow inbound from web server IP (`89.168.88.88`) to llama port `8080`.
Prefer allow-list (not public-open to world).

Example with UFW on LLM host:

```bash
# Allow only web server to hit llama backend port.
sudo ufw allow from 89.168.88.88 to any port 8080 proto tcp

# Optional: deny everyone else on 8080.
sudo ufw deny 8080/tcp

# Show effective rules.
sudo ufw status verbose
```

---

## 4) Validation checklist (both servers + external)

### 4A) On LLM server (129.159.30.72)

```bash
# Service status + logs.
sudo systemctl status llama-server.service --no-pager
sudo journalctl -u llama-server.service -n 100 --no-pager

# Listener and health checks.
sudo ss -ltnp | grep 8080 || true
curl -sS http://127.0.0.1:8080/health
```

### 4B) On web/nginx server (89.168.88.88)

```bash
# Verify web server can reach remote llm endpoint.
curl -I https://llm129.duckdns.org/
# or if using direct HTTP upstream:
curl -I http://129.159.30.72:8080/

# Verify public routed endpoint.
curl -I https://olderthanold.duckdns.org/llama/
```

### 4C) External client test (from your laptop/phone)

```bash
# OpenAI-compatible endpoint test through public web domain.
curl -sS https://olderthanold.duckdns.org/llama/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [
      {"role":"system","content":"You are concise."},
      {"role":"user","content":"Say hello from split-server setup."}
    ],
    "temperature": 0.7
  }'
```

---

## 5) OpenAI-compatible client settings

For your other web app / phone app, use:

- `base_url`: `https://olderthanold.duckdns.org/llama/v1`
- endpoint: `/chat/completions`
- `api_key`: placeholder if your SDK requires one (unless you add auth)

Example JS:

```js
const res = await fetch("https://olderthanold.duckdns.org/llama/v1/chat/completions", {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "local-model",
    messages: [{ role: "user", content: "Hello from phone" }],
    temperature: 0.7
  })
});
const data = await res.json();
console.log(data);
```

---

## 6) Operations quick commands

```bash
# llama service control (run on LLM server)
sudo systemctl stop llama-server.service
sudo systemctl disable llama-server.service
sudo systemctl restart llama-server.service
sudo systemctl status llama-server.service --no-pager
sudo journalctl -u llama-server.service -n 100 --no-pager

# nginx control (run on web server)
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx --no-pager
```

---

## Expected final URLs

- Main website: `https://olderthanold.duckdns.org/`
- Llama UI via proxy: `https://olderthanold.duckdns.org/llama/`
- OpenAI-like API via proxy: `https://olderthanold.duckdns.org/llama/v1/chat/completions`

Upstream LLM host direct URL remains:
- `https://llm129.duckdns.org/` (or `http://129.159.30.72:8080/` if you run HTTP-only upstream)
