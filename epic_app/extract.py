import json
with open(r'C:\Users\ASUS\.gemini\antigravity\brain\1021378f-f12a-4290-a2f3-16f4bf600925\.system_generated\logs\transcript.jsonl', 'r', encoding='utf-8') as f:
    lines = f.readlines()
count = 0
for line in reversed(lines):
    try:
        data = json.loads(line)
        if data.get('type') == 'USER_INPUT':
            print("--- USER INPUT ---")
            print(data.get('content'))
            count += 1
            if count == 15:
                break
    except:
        pass
