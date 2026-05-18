## 0buildai execution tree (what is run)

This document describes the run modes started by `0buildai.sh`, including status-only behavior and explicit build/service actions.

## Usage

```bash
sudo bash /m/mbin/0buildai.sh [--status|--force|--build-only|--service-only]
```

- Without arguments, `0buildai.sh` prints build/router status, then help, and exits without building or changing the service.
- `--status` prints build/router status and exits.
- `--build-only` verifies/builds llama.cpp only.
- `--service-only` verifies runtime, writes settings, and recreates/restarts `llama-router.service`.
- `--force` removes `llama-router.service` and `/m/llama.cpp`, rebuilds, then recreates/restarts the service.

## Examples

```bash
# Print build/router status and help without making changes.
sudo bash /m/mbin/0buildai.sh

# Print build/router status only.
sudo bash /m/mbin/0buildai.sh --status

# Verify/setup llama.cpp build only.
sudo bash /m/mbin/0buildai.sh --build-only

# Refresh settings and recreate/restart llama-router.service only.
sudo bash /m/mbin/0buildai.sh --service-only

# Full reset: service + /m/llama.cpp, preserving HF cache and web/nginx files.
sudo bash /m/mbin/0buildai.sh --force
```

```text
0buildai.sh v06
|-- Args: [--status|--force|--build-only|--service-only]
|   |-- no args prints build/router status + help and exits with no changes
|   |-- --status prints build/router status only
|   |-- --build-only runs ai/bai1_build_llama.sh only
|   |-- --service-only runs settings + router service scripts only
|   |-- --force resets service + LLAMA_DIR, then rebuilds and recreates service
|   `-- -h|--help prints usage and exits
|-- Status includes
|   |-- llama.cpp built: yes/no based on llama-server and llama-cli executables
|   |-- llama-router.service active/enabled state
|   |-- listening ports 8080 and 1234 when ss is available
|   |-- UFW status when ufw is available
|   |-- HF cache/settings paths
|   |-- llama.cpp binary/linker diagnostics when tools are available
|   `-- local API probes for health/models endpoints
|-- Action flow, when an explicit action is requested
|   |-- ai/bai1_build_llama.sh
|   |-- ai/bai1_build_settings.sh
|   `-- ai/bai1_build_router_service.sh
```

## Notes

- No-argument mode is safe/status-only as of `v06`.
- `llama.cpp built: yes` means both `$LLAMA_DIR/build/bin/llama-server` and `$LLAMA_DIR/build/bin/llama-cli` exist and are executable.
- `--status` is useful for scripts or logs when help text is not wanted.
- `--service-only` is what `0ainit.sh` uses when domain initialization needs the router service refreshed.
- `--force` does not remove `/m/hfcache`, nginx proxy config, or webroot files.