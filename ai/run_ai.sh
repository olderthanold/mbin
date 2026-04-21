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

llama-server -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-server -hf Andycurrent/Gemma-3-1B-it-GLM-4.7-Flash-Heretic-Uncensored-Thinking_GGUF:Q3_K_M -hff gemma-3-1b-it-Q4_K_M.gguf  --host 10.0.0.11 --port 8080

llama-server -hf unsloth/Qwen3.5-0.8B-GGUF:Q3_K_S --host 10.0.0.11 --port 8080

llama-server -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S --host 10.0.0.11 --port 8080

llama-cli -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-cli -hf Andycurrent/Gemma-3-1B-it-GLM-4.7-Flash-Heretic-Uncensored-Thinking_GGUF:Q3_K_M -hff gemma-3-1b-it-Q4_K_M.gguf  --host 10.0.0.11 --port 8080
# ====================== web old local
/home/ubun2/ai/llama.cpp/build/bin/llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj --host 10.0.159.254 --port 8080 --reasoning off

# ====================== web old local remote
/home/ubun2/ai/llama.cpp/build/bin/llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj --host 129.159.30.72 --port 80 --reasoning off

# ====================== CLI undone
llama-cli -hf unsloth/Qwen3.5-0.8B-GGUF:Q3_K_S --no-mmproj
llama-cli -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S --no-mmproj

# ====================== CLI done
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --reasoning off --no-mmproj
/home/ubun2/ai/llama.cpp/build/bin/llama-cli -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --no-mmproj
/home/ubun2/ai/llama.cpp/build/bin/
/home/ubun2/ai/llama.cpp/build/bin/