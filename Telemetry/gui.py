import subprocess
import tkinter as tk
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import matplotlib.pyplot as plt
import numpy as np
import os

def run_detection():
    base_path = os.path.dirname(os.path.abspath(__file__))
    exe_path = os.path.join(base_path, "anomaly")

    result = subprocess.run([exe_path], capture_output=True, text=True) 
    
    output_box.config(state="normal")
    output_box.delete("1.0", tk.END)
    output_box.insert(tk.END, result.stdout)
    output_box.config(state="disabled")

# GRAPH
def show_graph():
    base_path = os.path.dirname(os.path.abspath(__file__))
    data_path = os.path.join(base_path, "data/test/P-1.npy")

    data = np.load(data_path)
    data = data[:, 0]

    start, end = 2149, 2349

    ax.clear()

    ax.plot(data, linewidth=0.6, color="#00FFAA")
    ax.axvspan(start, end, color="red", alpha=0.3)

    ax.set_title("Telemetry Data with Anomaly", color="white")
    ax.set_xlabel("Time Index", color="white")
    ax.set_ylabel("Sensor Value", color="white")

    ax.tick_params(axis='x', colors='white')
    ax.tick_params(axis='y', colors='white')

    ax.set_facecolor("#1e1e1e")
    fig.patch.set_facecolor("#121212")
    ax.grid(True, alpha=0.2)

    canvas.draw()

# WINDOW
root = tk.Tk()
root.title("🚀 Telemetry Anomaly Detector")
root.geometry("850x600")
root.configure(bg="#121212")

title = tk.Label(
    root,
    text="🚀 Telemetry Anomaly Detector",
    font=("Helvetica", 20, "bold"),
    fg="#00FFAA",
    bg="#121212"
)
title.pack(pady=15)

# BUTTON
button_frame = tk.Frame(root, bg="#121212")
button_frame.pack(pady=10)

run_btn = tk.Button(
    button_frame,
    text="Run Detection",
    command=run_detection,
    bg="#00FFAA",          # bright 
    fg="black",
    activebackground="#00CC88",
    activeforeground="black",
    font=("Arial", 12, "bold"),
    width=18,
    relief="flat"
)
run_btn.grid(row=0, column=0, padx=15)

graph_btn = tk.Button(
    button_frame,
    text="Show Graph",
    command=show_graph,
    bg="#00FFAA",
    fg="black",
    activebackground="#00CC88",
    activeforeground="black",
    font=("Arial", 12, "bold"),
    width=18,
    relief="flat"
)
graph_btn.grid(row=0, column=1, padx=15)

output_label = tk.Label(
    root,
    text="Output",
    fg="#aaaaaa",
    bg="#121212",
    font=("Arial", 11)
)
output_label.pack(anchor="w", padx=30)

output_box = tk.Text(
    root,
    height=6,
    width=80,
    bg="#1e1e1e",
    fg="#00FFAA",
    insertbackground="white",
    relief="flat"
)
output_box.pack(padx=30, pady=10)
output_box.config(state="disabled")

fig = plt.Figure(figsize=(7,3), dpi=100)
ax = fig.add_subplot(111)

canvas = FigureCanvasTkAgg(fig, master=root)
canvas.get_tk_widget().pack(pady=10)

root.mainloop()
