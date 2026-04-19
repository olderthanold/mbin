import requests

def chat_with_llama():
    URL = "http://localhost:8080/completion"
    
    print("--- Llama.cpp Chat Interface (type 'exit' to quit) ---")

    while True:
        user_input = input("\nYou: ").strip()

        if not user_input:
            continue
        if user_input.lower() in ["exit", "quit"]:
            break

        # We use a more standard prompt format. 
        # We REMOVE "\n\n" from the stop list so the thinking can finish.
        payload = {
            "prompt": f"\nUser: {user_input}\nAssistant:",
            "n_predict": 2048,
            "temperature": 0.7,
            "top_p": 0.9,
            "stop": ["User:", "<end_of_turn>"] 
        }

        try:
            response = requests.post(URL, json=payload)
            response.raise_for_status()
            
            data = response.json()
            answer = data.get("content", "").strip()
            
            print(f"\nLlama: {answer}")

        except requests.exceptions.RequestException as e:
            print(f"\n[Error]: {e}")

if __name__ == "__main__":
    chat_with_llama()