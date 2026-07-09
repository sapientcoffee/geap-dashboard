import os
from google import genai

def main():
    project = "coffee-and-codey"
    location = "us-central1"
    
    client = genai.Client(
        vertexai=True,
        project=project,
        location=location
    )
    
    print("API client variables:")
    for k, v in client._api_client.__dict__.items():
        if k not in ["_credentials"]: # skip sensitive credentials
            print(f"  {k}: {v}")
            
    print("\nClient models variables:")
    print("  ", client.models.__dict__)

if __name__ == "__main__":
    main()
