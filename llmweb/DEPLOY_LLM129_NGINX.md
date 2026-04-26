# llm129 + llama.cpp internet exposure (nginx reverse proxy)

This setup keeps your website on `/` and exposes llama.cpp web UI/API on `/llama/`.

> Why not `--host 0.0.0.0 --port 80` directly?
>
> You *can* do that, but with nginx already in place it is safer and cleaner to run llama on
> `127.0.0.1:8080` and publish it through nginx on `https://llm129.duckdns.org/llama/`.
> This still gives internet access while preserving TLS and your existing website routes.

## 1) Run `llama-server` locally (not public bind)

Create a systemd unit so it survives reboot and restarts on failure.

```bash
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
```

### One-shot setup script (with colored progress echos)

```bash
# ===== colors =====
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}[1/5] Writing systemd service unit for llama-server...${NC}"
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

echo -e "${YELLOW}[2/5] Reloading systemd manager config...${NC}"
sudo systemctl daemon-reload

echo -e "${YELLOW}[3/5] Enabling + starting llama-server service at boot/runtime...${NC}"
sudo systemctl enable --now llama-server.service

echo -e "${YELLOW}[4/5] Verifying service status (no pager for non-interactive output)...${NC}"
sudo systemctl status llama-server.service --no-pager

echo -e "${YELLOW}[5/5] Testing local backend endpoint on loopback 127.0.0.1:8080...${NC}"
curl -sS http://127.0.0.1:8080/ | head -n 5

echo -e "${GREEN}llama-server local backend setup complete.${NC}"
```

### Command notes
- `-hf` = HuggingFace repository.
- `-hff` = exact GGUF filename from that repository.
- `--host 127.0.0.1` = only local loopback (safe behind nginx).
- `--port 8080` = backend port for nginx proxy.
- `Restart=always` = auto-recover service after crash.

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server.service
sudo systemctl status llama-server.service --no-pager
```

Quick local health checks:

```bash
curl -sS http://127.0.0.1:8080/ | head -n 5
curl -sS http://127.0.0.1:8080/health
```

---

## 2) nginx: keep site at `/`, proxy `/llama/` to local llama-server

Edit your active nginx server block for `llm129.duckdns.org` and add:

```nginx
# llama.cpp reverse proxy endpoint
location /llama/ {
    proxy_pass http://127.0.0.1:8080/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # long-running generation / streaming safe timeouts
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    send_timeout 3600;

    # larger prompts/uploads if needed
    client_max_body_size 64m;

    # optional: websocket/upgrade friendliness (safe to keep)
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

Reload nginx safely:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

If iframe is blank due to frame headers from upstream, add inside `location /llama/`:

```nginx
proxy_hide_header X-Frame-Options;
add_header X-Frame-Options "SAMEORIGIN" always;
```

---

## 3) Firewall expectations

- Public open: `80/tcp`, `443/tcp`
- Not public: `8080/tcp` (backend only)

If UFW is used:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 8080/tcp
sudo ufw status verbose
```

---

## 4) Validate from internet

```bash
curl -I https://llm129.duckdns.org/
curl -I https://llm129.duckdns.org/llama/
```

Expected:
- `/` serves your normal `mbin/llm129/index.htm` page.
- `/llama/` serves llama.cpp web UI/API.

---

## 5) Frontend status (already prepared in this repo)

- `index.htm` now has:
  - **Open LLM in new tab** link (`/llama/`)
  - **Show embedded LLM** iframe toggle (`/llama/`)
- `index.js` now uses a stable static page manifest (no nginx autoindex dependency).
- `lego.htm` stylesheet path corrected to `_style/vyvod.css`.
