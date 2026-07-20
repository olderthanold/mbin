# Llama router – working notes

For deployment, router configuration, nginx, `lctl.sh`, and validation commands,
use [deploy.md](deploy.md). This file contains only manual experiments and notes
that are not part of the operational guide.

## Manual model tests

These commands bypass the router and run a model directly with `llama-cli`.
Active router profiles and aliases remain the source of truth in
`llama_models.ini` and `llama_aliases.ini`.

```bash
# Gemma 270M
/m/llama.cpp/build/bin/llama-cli \
  -hf unsloth/gemma-3-270m-it-qat-GGUF:Q8_0 \
  --reasoning off --temp 0.7 --no-mmproj --jinja -c 4096

# Gemma 3 1B
/m/llama.cpp/build/bin/llama-cli \
  -hf unsloth/gemma-3-1b-it-GGUF \
  -hff gemma-3-1b-it-UD-IQ3_XXS.gguf \
  --reasoning off --temp 0.7 --no-mmproj --jinja -c 4096

# Ternary Bonsai 1.7B
/m/llama.cpp/build/bin/llama-cli \
  -hf prism-ml/Ternary-Bonsai-1.7B-gguf \
  -hff Ternary-Bonsai-1.7B-Q2_0_g64.gguf \
  --reasoning off --temp 0.7 --no-mmproj --jinja -c 4096

# LFM2.5 VL 450M
/m/llama.cpp/build/bin/llama-cli \
  -hf LiquidAI/LFM2.5-VL-450M-GGUF \
  -hff LFM2.5-VL-450M-Q8_0.gguf \
  --reasoning off --temp 0.7 --no-mmproj --jinja -c 4096

# LFM2.5 1.2B Instruct
/m/llama.cpp/build/bin/llama-cli \
  -hf bartowski/LiquidAI_LFM2.5-1.2B-Instruct-GGUF \
  -hff LiquidAI_LFM2.5-1.2B-Instruct-Q3_K_M.gguf \
  --reasoning off --temp 0.7 --no-mmproj --jinja -c 4096
```

## tmux for long builds

It is safer to run installation in `tmux`; the build continues after the
terminal disconnects.

```bash
# Only for the initial installation.
sudo apt install tmux

# Create a session and run the build.
tmux new -s llamabuild
sudo bash /m/mbin/0buildai.sh

# Detach the session: Ctrl+b, then d.
tmux ls
tmux attach -t llamabuild
tmux kill-session -t llamabuild
```

Upstream: <https://github.com/ggml-org/llama.cpp>
