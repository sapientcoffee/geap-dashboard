import os
# Remove API keys from environment so the google-genai SDK uses Application Default Credentials (ADC) for Vertex AI
os.environ.pop("GOOGLE_API_KEY", None)
os.environ.pop("GEMINI_API_KEY", None)

from google import genai

def main():
    project = "coffee-and-codey"
    model_name = "gemini-3.5-flash"
    
    # Try common Vertex AI regions
    regions = ["us-central1", "us-east4", "us-east1", "us-west1", "us-west4"]
    for region in regions:
        print(f"\n--- Testing location={region} ---")
        try:
            client = genai.Client(
                vertexai=True,
                project=project,
                location=region
            )
            prompt = "Hello! Reply with OK and your model name."
            response = client.models.generate_content(
                model=model_name,
                contents=prompt
            )
            print(f"SUCCESS in {region}!")
            print("Response text:", response.text.strip())
            return
        except Exception as e:
            print(f"Error in {region}:")
            # Print just the message/summary of error
            lines = str(e).split('\n')
            print(lines[0] if lines else str(e))

if __name__ == "__main__":
    main()
