easy using brew 
https://www.youtube.com/watch?v=1KkNOZpl2ko

Link to llama.cpp GitHub page: https://github.com/ggml-org/llama.cpp 
Homebrew install command page: https://brew.sh/


# Test
~/ai/llama.cpp/build/bin/llama-cli -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf
~/ai/llama.cpp/build/bin/llama-cli -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf

~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/Jackrong_Qwen3.5-9B-Neo-Q4_K_M.gguf --port 8000
~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/Jackrong_Qwen3.5-4B-Neo-Q5_K_M.gguf --port 8000
~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/Qwen_Qwen3.5-0.8B-Q6_K.gguf --port 8000

~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/gemma-4-26B-A4B-it-UD-Q3_K_M.gguf --port 8000
~/ai/llama.cpp/build/bin/llama-server -m ~/ai/models/gemma-4-E4B-it-Q4_K_M.gguf --port 8000