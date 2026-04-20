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

llama-server -hf ggml-org/gemma-3-1b-it-GGUF:Q4_K_M --host 0.0.0.0 --port 8080