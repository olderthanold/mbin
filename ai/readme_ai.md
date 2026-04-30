# ==== Llama router POC =================================================

```bash
# Build/update llama.cpp, then create/restart llama-router.service.
# If llama-router.service is already running, this prints status and exits.
sudo bash /m/mbin/0buildai.sh

# Print router/build status without changing anything.
sudo bash /m/mbin/0buildai.sh --status

# Full reset: remove llama-router.service and /m/llama.cpp, then rebuild.
sudo bash /m/mbin/0buildai.sh --force

# Build check only, without touching the systemd service.
sudo bash /m/mbin/0buildai.sh --build-only

# Service only, after a successful build.
sudo bash /m/mbin/0buildai.sh --service-only

# Optional custom HF cache location.
sudo env HF_CACHE_DIR=/m/ai-cache bash /m/mbin/0buildai.sh --service-only

# Serve copied llmweb from the domain first.
sudo bash /m/mbin/0web.sh llm129.duckdns.org

# Add nginx :1234 alias and optional domain /llama/ proxy.
sudo bash /m/mbin/ai/bai1_build_nginx_proxy.sh llm129.duckdns.org

# Remote model control.
bash /m/mbin/ai/llama_control.sh list
bash /m/mbin/ai/llama_control.sh loaded
bash /m/mbin/ai/llama_control.sh load lfm25vl450
bash /m/mbin/ai/llama_control.sh status lfm25vl450
bash /m/mbin/ai/llama_control.sh chat "Ahoj, odpovez kratce."
bash /m/mbin/ai/llama_control.sh chat lfm25vl450 "Ahoj, odpovez kratce."
bash /m/mbin/ai/llama_control.sh unload lfm25vl450
```

Router profiles live in `/m/mbin/ai/llama_models.ini`.
Default sampling: `--temp 0.7 --top-p 0.9 --top-k 40 --min-p 0.05 --repeat-penalty 1.05 -c 4096`.
Public POC endpoints: `http://<public-ip>:8080/v1`, `http://<public-ip>:1234/v1`, `https://<domain>/llama/v1`.
`load <model>` waits until the router reports the model as ready; override wait time with `LLAMA_LOAD_TIMEOUT=<seconds>`.
`chat <prompt>` uses the single currently loaded model; pass `chat <model> <prompt>` to choose explicitly.
`list` prints local router IDs plus status, quant, HF repo, and HF file or alias.
Use `models` for the raw router JSON when debugging.
Existing builds are only smoke-tested unless `--force` is used. `--force` does not remove `/m/hfcache`, nginx proxy config, or webroot files.
If an older wrapper left `/m/llama.cpp` as a non-git directory, plain `0buildai.sh` removes it automatically and clones a fresh checkout.
If the router service is already active, default `0buildai.sh` is status-only; use `--service-only` for an intentional service rewrite/restart.
Hugging Face model cache is stored under `/m/hfcache` by default. HF cache setup and UFW allow rules are handled by `ai/bai1_build_settings.sh`.
Default `0buildai.sh` order is build/verify -> settings -> router service.

 ==== USE =================================================
# ==== CLI =================================================
ai/llama.cpp/build/bin/
```bash
/m/llama.cpp/build/bin/llama-cli \
  -hf unsloth/LFM2.5-1.2B-Instruct-GGUF:Q3_K_M \
  --jinja \
  --temp 0.7 \
  --top-k 50 \
  --top-p 0.9 \
  --repeat-penalty 1.05 \
  --no-mmproj \
  -c 4096
```
|  # | ID                                      | quant  | size MB | date       | HF link
| -: | --------------------------------------- | ------ | ------: | ---------- | ---------------------------------------------------------------|
|  1 | `unsloth/Qwen3.5-0.8B-GGUF`             | `Q4_K_M` |   533 | 2026-03-02 | (https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF)
|  2 | `Jackrong/Qwopus3.5-0.8B-v3-GGUF`       | `Q4_K_M` |   529 | 2026-04    | (https://huggingface.co/Jackrong/Qwopus3.5-0.8B-v3-GGUF)
|  3 | `LiquidAI/LFM2-700M-GGUF`               | `Q6_K` |     612 | 2025-07-10 | (https://huggingface.co/LiquidAI/LFM2-700M-GGUF)
|  4 | `bartowski/Qwen_Qwen3-0.6B-GGUF`        | `Q6_K` |     623 | 2025-04-28 | (https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF)
|  5 | `Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF` | `q6_k` |     650 | 2024-09    | (https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF)
|  6 | `bartowski/Qwen2.5-0.5B-Instruct-GGUF`  | `Q8_0` |     531 | 2024-09    | (https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF)
|  7 | `LiquidAI/LFM2.5-350M-GGUF`             | `Q8_0` |     379 | 2026-03-31 | (https://huggingface.co/LiquidAI/LFM2.5-350M-GGUF)
|  8 | `LiquidAI/LFM2-350M-GGUF`               | `Q8_0` |     379 | 2025-07-10 | (https://huggingface.co/LiquidAI/LFM2-350M-GGUF)
|  9 | `bartowski/h2o-danube3-500m-chat-GGUF`  | `Q8_0` |     547 | 2024-07-17 | (https://huggingface.co/bartowski/h2o-danube3-500m-chat-GGUF)
| 10 | `bartowski/SmolLM2-360M-Instruct-GGUF`  | `Q8_0` |     386 | 2024-10-31 | (https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF)
| 11 | `bartowski/SmolLM2-135M-Instruct-GGUF`  | `Q8_0` |     271 | 2024-10-31 | (https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF)
| 12 | `unsloth/gemma-3-270m-it-qat-GGUF`      | `Q8_0` |     543 | 2025-08-14 | (https://huggingface.co/unsloth/gemma-3-270m-it-qat-GGUF)


```bash
# ===== models up to 650M ========================================================
# fast ok bad cs
/m/llama.cpp/build/bin/llama-cli -hf ZuzeTt/LFM2.5-VL-450M-GGUF -hff LFM2.5-VL-450M-imatrix-Q8_0.gguf --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192
# slow like qwen, brief
/m/llama.cpp/build/bin/llama-cli -hf unsloth/gemma-3-270m-it-qat-GGUF:Q8_0 --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192
#not too good, fast
/m/llama.cpp/build/bin/llama-cli -hf bartowski/SmolLM2-360M-Instruct-GGUF:Q8_0 --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192
#slow like qwen, ok
/m/llama.cpp/build/bin/llama-cli -hf LiquidAI/LFM2-700M-GGUF:Q6_K --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192

/m/llama.cpp/build/bin/llama-cli -hf unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M --reasoning off --temp 0.7 --no-mmproj --jinja --repeat-penalty 1.05 -c 8192
/m/llama.cpp/build/bin/llama-cli -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q4_K_M  --reasoning off --temp 0.7 --no-mmproj --jinja --repeat-penalty 1.05 -c 8192
/m/llama.cpp/build/bin/llama-cli -hf Jackrong/Qwopus3.5-0.8B-v3-GGUF:Q4_K_M --reasoning off --temp 0.7 --no-mmproj --jinja --repeat-penalty 1.05 -c 8192

/m/llama.cpp/build/bin/llama-cli -hf unsloth/LFM2.5-1.2B-Instruct-GGUF:Q3_K_M --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192
# ===== gemma ========================================================
## **** gemma 3 1B ------------------------------*OK* slow
/m/llama.cpp/build/bin/llama-cli -hf unsloth/gemma-3-1b-it-GGUF:Q4_K_S --reasoning off --temp 0.7 --no-mmproj
## ---- gemma 3 2B
/m/llama.cpp/build/bin/llama-cli -hf bartowski/gemma-2-2b-it-GGUF:Q3_K_S --reasoning off --temp 0.7
## ---- gemma 4 E2B NOT FEASIBLE
/m/llama.cpp/build/bin/llama-cli -hf daniloreddy/gemma-4-E2B-it_GGUF:Q4_K_S --reasoning off -n 512 --temp 0.7 --no-mmproj
## ---- gemma 4 E4B  NO WAY
/m/llama.cpp/build/bin/llama-cli -hf daniloreddy/gemma-4-E4B-it_GGUF:Q4_K_S -p "User: Hello! Assistant:" -n 512 --temp 0.7
# ===== Qwen 3.5 ========================================================
## **** Qwen 3.5 0.8B ---- non thinking ---------*too bad*
/m/llama.cpp/build/bin/llama-cli -hf unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M --reasoning off --temp 0.7 --no-mmproj --jinja --repeat-penalty 1.05 -c 8192
/m/llama.cpp/build/bin/llama-cli -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q4_K_M  --reasoning off --temp 0.7 --no-mmproj --jinja --repeat-penalty 1.05 -c 8192
/m/llama.cpp/build/bin/llama-cli -hf Jackrong/Qwopus3.5-0.8B-v3-GGUF:Q4_K_M --reasoning off --temp 0.7 --no-mmproj --jinja --repeat-penalty 1.05 -c 8192
## ---- Qwen 3.5 2B
/m/llama.cpp/build/bin/llama-cli -hf bartowski/Qwen_Qwen3.5-2B-GGUF:Q3_K_S  --reasoning off -n 512 --temp 0.7 --no-mmproj
## ---- Qwen 3.5 0.8B ---- THINKING
```
# ==== Server local =================================================

``` bash
/m/llama.cpp/build/bin/llama-server -hf ZuzeTt/LFM2.5-VL-450M-GGUF -hff LFM2.5-VL-450M-imatrix-Q8_0.gguf --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192 --host 127.0.0.1 --port 8080
/m/llama.cpp/build/bin/llama-server -hf ZuzeTt/LFM2.5-VL-450M-GGUF -hff LFM2.5-VL-450M-imatrix-Q8_0.gguf --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192 --host 129.159.30.72 --port 80

/m/llama.cpp/build/bin/llama-server -hf ZuzeTt/LFM2.5-VL-450M-GGUF -hff LFM2.5-VL-450M-imatrix-Q8_0.gguf --reasoning off --temp 0.7 --no-mmproj  --jinja --repeat-penalty 1.05 -c 8192 --host 0.0.0.0 --port 80

/m/llama.cpp/build/bin/llama-server \
 -m /m/models/gemma-4-E4B-it-GGUF \
 -t 6 \
 -c 8192 \
 --port 8080

/m/llama.cpp/build/bin/llama-server \
 -m /m/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf \
 -t 6 \
 -c 16384 \
 --port 8080

# ===== gemma 3 1B
llama-server -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-server -hf Andycurrent/Gemma-3-1B-it-GLM-4.7-Flash-Heretic-Uncensored-Thinking_GGUF:Q3_K_M -hff gemma-3-1b-it-Q4_K_M.gguf  --host 10.0.0.11 --port 8080
# ===== Qwen 3.5 0.8B
llama-server -hf unsloth/Qwen3.5-0.8B-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-server -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S --host 10.0.0.11 --port 8080

```
# ==== Server public =================================================
## ---- web llm local 10.0.159.254
/m/llama.cpp/build/bin/llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj --host 10.0.159.254 --port 8080 --reasoning off

## ---- web 129 remote 129.159.30.72
/m/llama.cpp/build/bin/llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj --host 129.159.30.72 --port 80 --reasoning off

# ===== API
/m/llama.cpp/build/bin/llama-server \
  -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S \
  --host 127.0.0.1 \
  --port 8080 \
  --no-webui




# Link to llama.cpp GitHub page: https://github.com/ggml-org/llama.cpp
```
# ==== tmux ================================================
```bash
# install tmux (only once)
sudo apt install tmux
# start a new tmux session named "llamabuild"
tmux new -s llamabuild
# inside tmux: run setup or build-only foreground
sudo bash /m/mbin/0buildai.sh
# detach from tmux (leave build running)
## press: Ctrl+b then d
# later: list tmux sessions
tmux ls
# reattach to the session
tmux attach -t llamabuild
# (optional) kill the session when done
tmux kill-session -t llamabuild
```
