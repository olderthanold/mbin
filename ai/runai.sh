~/ai/llama.cpp/build/bin/llama-server \
    -hf bartowski/Qwen_Qwen3.5-0.8B-GGUF:Q3_K_S \
    --reasoning off \
    --no-mmproj \
    -t 6 \
    -c 4096 \
    --host 10.0.0.11 \
    --port 8080
