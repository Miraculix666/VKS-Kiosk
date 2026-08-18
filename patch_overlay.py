import re

with open('Raspi/overlay.py', 'r') as f:
    content = f.read()

new_func = """def read_text():
    global last_mtime, cached_text
    try:
        current_mtime = os.path.getmtime(TEXT_FILE)
        if current_mtime != last_mtime:
            with open(TEXT_FILE) as f:
                cached_text = f.read().strip()
            last_mtime = current_mtime
        return cached_text
    except Exception:
        cached_text = "keine Datei"
        return cached_text
"""

content = re.sub(r'def read_text\(\):.*?(?=def update\(\):)', new_func, content, flags=re.DOTALL)

with open('Raspi/overlay.py', 'w') as f:
    f.write(content)
