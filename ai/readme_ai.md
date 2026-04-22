 ==== USE =================================================
# ==== CLI =================================================
ai/llama.cpp/build/bin/
-n 512 respons size
-c 8192 context
--temp 0.7 temperature

```bash
# ===== gemma ========================================================
## ---- gemma 3 1B ------------------------------*OK* 
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --reasoning off --temp 0.7 --no-mmproj
## ---- gemma 3 2B
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf bartowski/gemma-2-2b-it-GGUF:Q3_K_S --reasoning off --temp 0.7 
## ---- gemma 4 E2B NOT FEASIBLE
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf daniloreddy/gemma-4-E2B-it_GGUF:Q4_K_S --reasoning off -n 512 --temp 0.7 --no-mmproj
## ---- gemma 4 E4B  NO WAY
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf daniloreddy/gemma-4-E4B-it_GGUF:Q4_K_S -p "User: Hello! Assistant:" -n 512 --temp 0.7

# ===== Qwen 3.5 ========================================================
## ---- Qwen 3.5 0.8B ---- non thinking ---------*OK*
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S  --reasoning off -n 512 --temp 0.7 --no-mmproj
## ---- Qwen 3.5 2B
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf bartowski/Qwen_Qwen3.5-2B-GGUF:Q3_K_S  --reasoning off -n 512 --temp 0.7 --no-mmproj
## ---- Qwen 3.5 0.8B ---- THINKING
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S  --reasoning off -n 512 --temp 0.7 --no-mmproj
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S  --reasoning off -n 512 --temp 0.7 --no-mmproj
```
# ==== Server local =================================================
``` bash
~/ai/llama.cpp/build/bin/llama-server \
 -m ~/ai/models/gemma-4-E4B-it-GGUF \
 -t 6 \
 -c 16384 \
 --port 8080

~/ai/llama.cpp/build/bin/llama-server \
 -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf \
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
/home/ubun2/ai/llama.cpp/build/bin/llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj --host 10.0.159.254 --port 8080 --reasoning off

## ---- web 129 remote 129.159.30.72
/home/ubun2/ai/llama.cpp/build/bin/llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj --host 129.159.30.72 --port 80 --reasoning off

# ===== API 
/home/ubun2/ai/llama.cpp/build/bin/llama-server \
  -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S \
  --host 127.0.0.1 \
  --port 8080 \
  --no-webui




# Link to llama.cpp GitHub page: https://github.com/ggml-org/llama.cpp 
```
# ==== tmux ================================================

# ==== nohup ================================================
## just run buildrun
# run build detached from terminal, log output to file
```bash
nohup bash -c 'sudo -E bash -c "export PATH=$PATH; /opt/mbin/ai/aibuild.sh" && touch aibuild_script_completed.txt' > aibuild.log 2>aibuild.log &
echo $!

# explanation:
# nohup      = ignore terminal disconnect (SIGHUP)
# > build.log = stdout to file
# 2>&1       = stderr to same file / error.log
# &          = run in background

# check if running
pgrep -af aibuild.sh
# monitor output
tail -f build.log
# stop if needed
kill -9 <PID>
```
# ==== tmux ================================================
```bash
# install tmux (only once)
sudo apt install tmux
# start a new tmux session named "build"
tmux new -s aibuild
# inside tmux: run your build script
/opt/mbin/ai/aibuild.sh
# detach from tmux (leave build running)
## press: Ctrl+b then d
# later: list tmux sessions
tmux ls
# reattach to the session
tmux attach -t build
# (optional) kill the session when done
tmux kill-session -t build
```