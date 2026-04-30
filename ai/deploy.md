# Llama router POC deployment

This document covers the llama.cpp router setup used by `/m/mbin/ai`.
The static web files stay in `llmweb`; service and proxy scripts stay in `ai`.

## 1) Start llama router

```bash
# Build/update llama.cpp first if needed.
/m/mbin/ai/build_llama.sh

# Create and start systemd service on port 8080.
sudo bash /m/mbin/ai/llama_router_service.sh
```

The service runs:

```bash
/m/llama.cpp/build/bin/llama-server \
  --models-preset /m/mbin/ai/llama_models.ini \
  --host 0.0.0.0 \
  --port 8080 \
  --models-max 1 \
  --no-models-autoload \
  --sleep-idle-seconds 900
```

Models are loaded on demand through the router API. Only one model should be
loaded at a time on the small OCI VM.

## 2) Configure nginx aliases

Single-VM mode:

```bash
# Serve static llmweb content from the domain first.
sudo bash /m/mbin/0web.sh llm129.duckdns.org /m/mbin/llmweb

# Adds public :1234 alias and, if the domain site exists, /llama/ proxy.
sudo bash /m/mbin/ai/llama_nginx_proxy.sh llm129.duckdns.org
```

Split web/LLM mode:

```bash
# Run on the public web VM. Point nginx at the LLM VM.
sudo bash /m/mbin/0web.sh olderthanold.duckdns.org /m/mbin/llmweb

sudo env LLAMA_BACKEND_URL=http://129.159.30.72:8080 \
  bash /m/mbin/ai/llama_nginx_proxy.sh olderthanold.duckdns.org
```

Expected URLs:

- `http://<public-ip>:8080/`
- `http://<public-ip>:8080/v1`
- `http://<public-ip>:1234/`
- `http://<public-ip>:1234/v1`
- `https://<domain>/llama/`
- `https://<domain>/llama/v1`

Open OCI ingress and UFW for `8080/tcp` and `1234/tcp` when using direct public
POC access.

## 3) Remote model control

```bash
# Local host.
bash /m/mbin/ai/llama_control.sh models
bash /m/mbin/ai/llama_control.sh load lfm25vl450
bash /m/mbin/ai/llama_control.sh chat lfm25vl450 "Ahoj, odpovez kratce."
bash /m/mbin/ai/llama_control.sh unload lfm25vl450

# Public 1234 alias.
LLAMA_BASE_URL=http://<public-ip>:1234 bash /m/mbin/ai/llama_control.sh v1models

# Domain proxy.
LLAMA_BASE_URL=https://<domain>/llama bash /m/mbin/ai/llama_control.sh chat gemma270 "Hello."
```

Raw API examples:

```bash
curl -sS http://127.0.0.1:8080/models

curl -sS http://127.0.0.1:8080/models/load \
  -H "Content-Type: application/json" \
  -d '{"model":"lfm25vl450"}'

curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "lfm25vl450",
    "messages": [{"role":"user","content":"Say hello."}],
    "temperature": 0.7
  }'
```

## 4) Profiles

Profiles are defined in `ai/llama_models.ini`:

- `lfm25vl450`
- `gemma270`
- `smollm360`
- `lfm2_700`

Shared defaults:

- `c = 4096`
- `reasoning = off`
- `jinja = true`
- `no-mmproj = true`
- `temp = 0.7`
- `top-p = 0.9`
- `top-k = 40`
- `min-p = 0.05`
- `repeat-penalty = 1.05`

If the VM starts swapping heavily, lower `c` from `4096` to `2048`.

## 5) Checks

```bash
bash -n /m/mbin/ai/llama_router_service.sh
bash -n /m/mbin/ai/llama_control.sh
bash -n /m/mbin/ai/llama_nginx_proxy.sh

sudo systemctl status llama-router.service --no-pager
sudo journalctl -u llama-router.service -n 100 --no-pager
sudo ss -ltnp | grep -E ':8080|:1234' || true

curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/models
curl -sS http://127.0.0.1:1234/v1/models
```
