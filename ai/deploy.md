# Llama router POC deployment

This document covers the llama.cpp router setup used by `/m/mbin/ai`.
The static web files stay in `llmweb`; AI build/setup scripts stay in `ai`.

## 1) Start llama router

```bash
# Build/update llama.cpp, then create/restart llama-router.service.
# If llama-router.service is already running, this prints status and exits.
sudo bash /m/mbin/0buildai.sh

# Print router/build status without changing anything.
sudo bash /m/mbin/0buildai.sh --status

# Full reset: stop/remove llama-router.service, delete /m/llama.cpp,
# rebuild from scratch, then recreate/restart the service.
sudo bash /m/mbin/0buildai.sh --force

# Build check only, without touching the systemd service.
sudo bash /m/mbin/0buildai.sh --build-only

# Service only, after a successful build.
sudo bash /m/mbin/0buildai.sh --service-only

# Optional custom HF cache location.
sudo env HF_CACHE_DIR=/m/ai-cache bash /m/mbin/0buildai.sh --service-only
```

Without `--force`, an existing git checkout is not updated or rebuilt. The
wrapper only verifies that `llama-server` and `llama-cli` exist, are executable,
and pass a cheap `--version` or `--help` smoke test. Use `--force` for a fresh
checkout/rebuild. `--force` does not remove `/m/hfcache`, nginx proxy config,
or webroot files.
If an older wrapper left `/m/llama.cpp` as a non-git directory, plain
`0buildai.sh` removes it automatically and clones a fresh checkout.
If the router service is already active, default `0buildai.sh` is status-only; use
`--service-only` for an intentional service rewrite/restart.
Hugging Face model cache is stored under `/m/hfcache` by default. The cache and
UFW port rules are handled by `ai/bai1_build_settings.sh`, not by the router
service script.
Default `0buildai.sh` order is build/verify -> settings -> router service.

The service runs:

```bash
EnvironmentFile=-/etc/default/llama-router

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
# Serve copied llmweb content from the domain first.
sudo bash /m/mbin/0web.sh llm129.duckdns.org

# Adds public :1234 alias and, if the domain site exists, /llama/ proxy.
sudo bash /m/mbin/ai/bai1_build_nginx_proxy.sh llm129.duckdns.org
```

Split web/LLM mode:

```bash
# Run on the public web VM. Point nginx at the LLM VM.
sudo bash /m/mbin/0web.sh olderthanold.duckdns.org

sudo env LLAMA_BACKEND_URL=http://129.159.30.72:8080 \
  bash /m/mbin/ai/bai1_build_nginx_proxy.sh olderthanold.duckdns.org
```

Expected URLs:

- `http://<public-ip>:8080/`
- `http://<public-ip>:8080/v1`
- `http://<public-ip>:1234/`
- `http://<public-ip>:1234/v1`
- `https://<domain>/llama/`
- `https://<domain>/llama/v1`

Open OCI ingress for `8080/tcp` and `1234/tcp` when using direct public POC
access. `bai1_build_settings.sh` adds matching UFW allow rules idempotently,
but leaves the current UFW enable state unchanged unless `AI_UFW_ENABLE=true`
is set.

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
bash -n /m/mbin/0buildai.sh
bash -n /m/mbin/ai/bai1_build_settings.sh
bash -n /m/mbin/ai/bai1_build_llama.sh
bash -n /m/mbin/ai/bai1_build_brew_llama.sh
bash -n /m/mbin/ai/bai1_build_router_service.sh
bash -n /m/mbin/ai/llama_control.sh
bash -n /m/mbin/ai/bai1_build_nginx_proxy.sh

sudo bash /m/mbin/0buildai.sh --status
sudo systemctl status llama-router.service --no-pager
sudo systemctl cat llama-router.service | grep -E 'EnvironmentFile|ExecStart'
sudo grep -E 'HF_HOME|HF_HUB_CACHE|HUGGINGFACE_HUB_CACHE|TRANSFORMERS_CACHE|XDG_CACHE_HOME' /etc/default/llama-router
sudo journalctl -u llama-router.service -n 100 --no-pager
sudo ss -ltnp | grep -E ':8080|:1234' || true
sudo ls -ld /m/hfcache /m/hfcache/hub /m/hfcache/transformers /m/hfcache/xdg
find /m/hfcache -maxdepth 2 -type d
du -sh /m/hfcache

curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/models
curl -sS http://127.0.0.1:1234/v1/models
```
