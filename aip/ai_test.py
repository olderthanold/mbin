import requests

# Send the request to the local server
r = requests.post(
    "http://localhost:8080/completion",  # Ensure this is the correct URL
    json={"prompt": "rekni mi neco o cechach", "temperature": 0.9, "max_tokens": 0}  # Add any necessary parameters
)

# Check if the request was successful (status code 200)
if r.status_code == 200:
    # Print the response from the Llama server
    print(r.json())
else:
    print(f"Error: {r.status_code}, {r.text}")