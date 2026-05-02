## 0ainit execution tree (what is run)

This document describes the run order started by `0ainit.sh`, including step numbering and script versions as detected from script headers by the wrapper.

## Usage

```bash
sudo bash /m/mbin/0ainit.sh [domain] [web_root]
```

- `domain` is optional, but when provided it must contain `.`.
- `web_root` is optional and is used only when `domain` is provided.
- If `domain` is provided and `web_root` is omitted, `web_root` defaults to the domain prefix before the first dot.
- Without `domain`, the script refreshes the AI router service, ensures configured models are cached, then lists current nginx llama aliases.
- With `domain`, the script also runs `0web.sh` and adds/updates the nginx `/llama/` alias for that domain.

## Examples

```bash
# Refresh AI router service, ensure configured models are cached, and list nginx llama aliases.
sudo bash /m/mbin/0ainit.sh

# Initialize AI runtime and wire https://emp2.duckdns.org/llama/ using web root argument "emp2".
sudo bash /m/mbin/0ainit.sh emp2.duckdns.org

# Initialize AI runtime and wire domain alias using an explicit relative web root.
sudo bash /m/mbin/0ainit.sh emp2.duckdns.org emp2

# Override nginx proxy paths while initializing/listing aliases.
sudo SNIPPET_PATH=/etc/nginx/snippets/llama-router-proxy.conf \
  PORT_ALIAS_CONF=/etc/nginx/conf.d/llama-router-1234.conf \
  bash /m/mbin/0ainit.sh
```

```text
0ainit.sh v01
|-- Args: [domain] [web_root]
|   |-- -h|--help prints usage and exits
|   |-- domain is optional, but when provided it must contain "."
|   |-- web_root is optional and used only when domain is provided
|   |-- if domain is provided and web_root is omitted: web_root defaults to domain prefix before first dot
|   `-- child scripts are resolved from 0ainit.sh location and its ai/ subdir
|-- Config paths
|   |-- SNIPPET_PATH default: /etc/nginx/snippets/llama-router-proxy.conf
|   `-- PORT_ALIAS_CONF default: /etc/nginx/conf.d/llama-router-1234.conf
|-- [1/3] 0buildai.sh v03 --service-only
|   `-- 0buildai.sh v03
|       |-- --service-only skips rebuild, but verifies llama-server runtime before service restart
|       |-- resolves child scripts from the ai subdir of 0buildai.sh location
|       |-- uses SERVICE_NAME default llama-router
|       |-- uses LLAMA_DIR default /m/llama.cpp
|       |-- uses HF_CACHE_DIR default /m/hfcache
|       |-- uses SETTINGS_ENV_FILE default /etc/default/llama-router
|       |-- [1/2] ai/bai1_build_settings.sh v01
|       |   |-- ensure Hugging Face cache directories exist
|       |   |-- write router environment file
|       |   |-- ensure UFW exists and allow AI ports 8080/tcp and 1234/tcp by default
|       |   |-- leave UFW enable state unchanged unless AI_UFW_ENABLE=true
|       |   `-- print current AI build settings summary
|       `-- [2/2] ai/bai1_build_router_service.sh v07
|           |-- pre-flight: require sudo, systemctl, service user, runnable llama-server binary, models preset, and settings env file
|           |-- autoheal legacy RUNPATH via /home/<user>/ai/llama.cpp -> /m/llama.cpp symlink when safe
|           |-- write /etc/systemd/system/llama-router.service by default
|           |-- configure llama-server router mode with --models-preset, --no-models-autoload, and idle sleep
|           |-- reload systemd, enable service, and restart service
|           |-- show service status and local health check
|           `-- list available router models through lctl.sh or raw API fallback
|-- [2/3] ai/bai1_init_model_cache.sh v04
|   `-- bai1_init_model_cache.sh v04
|       |-- load settings from /etc/default/llama-router when present
|       |-- use LLAMA_MODELS_PRESET or ai/llama_models.ini
|       |-- use LLAMA_CONTROL_SCRIPT or /m/mbin/lctl.sh
|       |-- require llama router health endpoint at LLAMA_BASE_URL, default http://127.0.0.1:8080
|       |-- parse configured model entries from the preset
|       |-- check Hugging Face cache for full GGUF files, minimum size MIN_GGUF_BYTES
|       |-- for missing models: load model through llama router to trigger download
|       |-- unload model after download attempt
|       `-- fail if loaded model still cannot be found in cache
`-- [3/3]
    |-- when no domain argument is provided
    |   `-- list nginx llama aliases and exit
    `-- when domain argument is provided
        |-- 0web.sh v13 <domain> <web_root>
        |   `-- create/update web root, nginx entry, certificate, and final HTTPS config
        |-- ai/bai1_build_nginx_proxy.sh v02 <domain>
        |   |-- write nginx /llama/ proxy snippet
        |   |-- write public port 1234 nginx alias
        |   |-- idempotently include /llama/ snippet in /etc/nginx/sites-available/<domain> when site exists
        |   |-- test nginx config and reload nginx
        |   |-- public API alias: http://<public-ip>:1234/v1
        |   `-- domain API alias: https://<domain>/llama/v1
        `-- list nginx llama aliases after update
```

## Notes

- `0ainit.sh` is the AI runtime initializer: refresh router service, ensure configured GGUF models are cached, then either list nginx aliases or wire a domain alias.
- `0ainit.sh` can be run without root, but root-required child operations are executed through `sudo` via `run_root`.
- Running without arguments still preflights required child script files, but does not call `0web.sh` or modify domain site configs; it refreshes the router service, checks/downloads models, then lists current nginx llama aliases.
- Running with a domain calls `0web.sh` before `bai1_build_nginx_proxy.sh`, so the domain Nginx site should exist before the `/llama/` include is added.
- If `<web_root>` is omitted for a domain, `0ainit.sh` passes the domain prefix as the web root argument, e.g. `emp2.duckdns.org` becomes `emp2`.
- The public port alias uses port `1234`; the router backend defaults to `http://127.0.0.1:8080`.
- `SNIPPET_PATH`, `PORT_ALIAS_CONF`, `LLAMA_BACKEND_URL`, `LLAMA_BASE_URL`, `LLAMA_LOAD_TIMEOUT`, `LLAMA_MODELS_PRESET`, `HF_CACHE_DIR`, and related AI environment variables can override defaults.
- Detailed website provisioning behavior is documented in `0web.md`.

## Selected shell scripts in this directory that are not used directly by 0ainit flow

- `0ini.sh` - system/user initialization flow.
- `delete_cloned_user.sh` - removes a cloned user account safely, with guardrails.
- `delete_website.sh` - removes Nginx site entry and cert artifacts for a domain, leaving web content untouched.
- `mgit_ssh.sh`, `mgit_https.sh`, `mgit_oldssh.sh`, `mgit_oldhttps.sh` - git helper/update scripts.
- `symlink_m.sh` - creates `/m` layout and compatibility symlinks for legacy paths.
- `mstats.sh`, `mtest.sh` - utility/testing scripts.
