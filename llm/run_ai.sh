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
llama-server -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-server -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S --host 10.0.0.11 --port 8080

llama-cli -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-cli -hf Andycurrent/Gemma-3-1B-it-GLM-4.7-Flash-Heretic-Uncensored-Thinking_GGUF:Q3_K_M -hff gemma-3-1b-it-Q4_K_M.gguf  --host 10.0.0.11 --port 8080

llama-cli -hf unsloth/Qwen3.5-0.8B-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-cli -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
llama-cli -hf Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q3_K_S --host 10.0.0.11 --port 8080
