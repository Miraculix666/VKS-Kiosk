#!/usr/bin/env python3
import tkinter as tk
import os 
TEXT_FILE = "/scripts/version.txt"
REFRESH_MS = 1000
def read_text():
    try:
        with open(TEXT_FILE) as f:
            return f.read().strip()
    except:
        return "keine Datei"
def update():
    label.config(text=read_text())
    root.after(REFRESH_MS, update)
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
