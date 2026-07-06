import os
# Remove API keys from environment so the google-genai SDK uses Application Default Credentials (ADC) for Vertex AI
os.environ.pop("GOOGLE_API_KEY", None)
os.environ.pop("GEMINI_API_KEY", None)

from google import genai

def main():
    project = "coffee-and-codey"
    
    # Try location="global" (the global/multi-region endpoint)
    location = "global"
    model_name = "gemini-3.5-flash"
    
    print(f"Initializing google-genai Client with vertexai=True, project={project}, location={location}...")
    client = genai.Client(
        vertexai=True,
        project=project,
        location=location
    )
    
    prompt = "Hello! Reply with OK and your model name."
    print(f"Calling generate_content on model={model_name}...")
    try:
        response = client.models.generate_content(
            model=model_name,
            contents=prompt
        )
        print("Response received successfully!")
        print("Response text:", response.text.strip())
        if response.usage_metadata:
            print("Usage Metadata:")
            print(f"  Prompt tokens: {response.usage_metadata.prompt_token_count}")
            print(f"  Candidates tokens: {response.usage_metadata.candidates_token_count}")
            print(f"  Total tokens: {response.usage_metadata.total_token_count}")
    except Exception as e:
        print(f"Error calling {model_name}:")
        print(e)

if __name__ == "__main__":
    main()
