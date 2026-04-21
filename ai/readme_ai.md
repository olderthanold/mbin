Link to llama.cpp GitHub page: https://github.com/ggml-org/llama.cpp 

# ==== tmux ================================================
# install tmux (only once)
sudo apt install tmux
# start a new tmux session named "build"
tmux new -s build
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
# ==== tmux ================================================

# Test
~/ai/llama.cpp/build/bin/llama-cli -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf
~/ai/llama.cpp/build/bin/llama-cli -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf

~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/Jackrong_Qwen3.5-9B-Neo-Q4_K_M.gguf --port 8000
~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf --port 8000
~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/Qwen_Qwen3.5-0.8B-Q6_K.gguf --port 8000

~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/gemma-4-26B-A4B-it-UD-Q3_K_M.gguf --port 8000
~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/gemma-4-E4B-it-Q4_K_M.gguf --port 8000
