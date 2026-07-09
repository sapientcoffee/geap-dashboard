import os
import vertexai
from vertexai.generative_models import GenerativeModel

def main():
    project = "coffee-and-codey"
    location = "us-central1"
    
    print(f"Initializing vertexai with project={project}, location={location}...")
    vertexai.init(project=project, location=location)
    
    print("Initializing GenerativeModel for gemini-2.5-flash...")
    model = GenerativeModel("gemini-2.5-flash")
    
    print("Calling generate_content...")
    try:
        response = model.generate_content("Hello, this is an enterprise SDK test. Reply with 'OK'")
        print("Response received successfully!")
        print("Response text:", response.text)
    except Exception as e:
        print("Error during call:")
        print(e)

if __name__ == "__main__":
    main()
