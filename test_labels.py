# Copyright 2026 Google LLC.
# SPDX-License-Identifier: Apache-2.0

import os
# Remove API keys from environment so the google-genai SDK uses Application Default Credentials (ADC) for Vertex AI
os.environ.pop("GOOGLE_API_KEY", None)
os.environ.pop("GEMINI_API_KEY", None)

from google import genai
from google.genai import types

def main():
    project = "coffee-and-codey"
    
    # Using global location for testing label-based extraction workaround
    location = "global"
    model_name = "gemini-3.5-flash"
    
    print(f"Initializing google-genai Client with vertexai=True, project={project}, location={location}...")
    client = genai.Client(
        vertexai=True,
        project=project,
        location=location
    )
    
    print("Calling generate_content with labels in types.GenerateContentConfig...")
    try:
        response = client.models.generate_content(
            model=model_name,
            contents="Say: 'Native labels parsed successfully!'",
            config=types.GenerateContentConfig(
                labels={"developer_email": "test_developer_types@sapientcoffee.com"}
            )
        )
        print("Success using GenerateContentConfig! Response:")
        print(response.text.strip())
    except Exception as e:
        print("Error with types.GenerateContentConfig:", e)
        print("Trying dictionary configuration fallback...")
        try:
            response = client.models.generate_content(
                model=model_name,
                contents="Say: 'Native labels parsed successfully!'",
                config={
                    "labels": {"developer_email": "test_developer_dict@sapientcoffee.com"}
                }
            )
            print("Success using dictionary config! Response:")
            print(response.text.strip())
        except Exception as e2:
            print("Dictionary configuration fallback also failed:")
            print(e2)

if __name__ == "__main__":
    main()
