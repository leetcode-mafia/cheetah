import os
import requests

class OpenAIHandler:
    def __init__(self, api_key):
        self.headers = {
            "Authorization": f"Bearer {api_key}",
        }

    def generate_code(self, prompt: str) -> str:
        payload = {
            "model": "gpt-4o-mini",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,  # lower temp for more focused code
        }
        headers = self.headers.copy()
        headers["Content-Type"] = "application/json"

        response = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]

    def transcribe_audio(self, audio_file_path: str) -> str:
        headers = self.headers.copy()
        with open(audio_file_path, "rb") as audio_file:
            files = {
                "file": (audio_file_path, audio_file, "audio/mpeg"),
            }
            data = {
                "model": "whisper-1",
                "language": "en"
            }
            response = requests.post("https://api.openai.com/v1/audio/transcriptions", headers=headers, data=data, files=files)
            response.raise_for_status()
        data = response.json()
        return data["text"]
