#!/usr/bin/env python3
import tkinter as tk
import os 
TEXT_FILE = "/scripts/version.txt"
REFRESH_MS = 1000

last_mtime = None
cached_text = "keine Datei"

def read_text():
    global last_mtime, cached_text
    try:
        current_mtime = os.path.getmtime(TEXT_FILE)
        if current_mtime != last_mtime:
            with open(TEXT_FILE) as f:
                cached_text = f.read().strip()
            last_mtime = current_mtime
    except:
        cached_text = "keine Datei"
        last_mtime = None
    return cached_text

def update():
    label.config(text=read_text())
    root.after(REFRESH_MS, update)
if __name__ == '__main__':
    if os.environ.get('DISPLAY','') == '':
        print('no display found. Using :0.0')
        os.environ.__setitem__('DISPLAY', ':0.0')
    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    # halbtransparentes Fenster
    root.attributes("-alpha", 0.0)
    frame = tk.Frame(root, bg="")
    frame.pack()
    label = tk.Label(
        frame,
        text="",
        font=("DejaVu Sans", 6, "bold"),
        fg="white",
        bg="black"
    )
    label.pack()
    root.update_idletasks()
    screen_width = root.winfo_screenwidth()
    x = screen_width - 95
    y = 0
    root.geometry(f"+{x}+{y}")
    update()
    root.mainloop()
