# 🚀 Telemetry Anomaly Detector

A hybrid **C + Python** tool that detects anomalies in telemetry sensor data using the **KMP (Knuth-Morris-Pratt) string matching algorithm**, with an interactive GUI for visualization.

---

## 📌 Overview

This project converts raw telemetry sensor readings into Up/Down (`U`/`D`) trend patterns and uses KMP pattern matching to locate known anomaly signatures within the full data stream. A Python-based GUI allows users to run detection and visualize results with a single click.

---

## 🧠 How It Works

```
Raw .npy Data  →  CSV Export  →  U/D Pattern Encoding  →  KMP Search  →  Anomaly Index
```

1. **`convert.py`** — Loads a `.npy` telemetry file and exports the first sensor column to `telemetry.csv`
2. **`kmp_telemetry.c`** — Reads the CSV, encodes data as a trend pattern (`U` = up, `D` = down), and uses KMP to find where a known anomaly pattern appears
3. **`gui_2.py`** — Launches a dark-themed GUI with buttons to run detection and plot the data
4. **`PLOT.py`** — Standalone script to visualize the telemetry data with the anomaly region highlighted

---

## 📁 Project Structure

```
├── convert.py           # Convert .npy → telemetry.csv
├── kmp_telemetry.c      # C program: KMP anomaly detection
├── gui_2.py             # Python GUI (tkinter + matplotlib)
├── PLOT.py              # Standalone plot script
├── telemetry.csv        # Generated CSV (auto-created by convert.py)
└── data/
    └── test/
        └── P-1.npy      # Input telemetry dataset
```

---

## ⚙️ Setup & Usage

### 1. Prerequisites

- Python 3.x
- GCC compiler
- Python packages:

```bash
pip install numpy matplotlib
```

### 2. Prepare the Data

```bash
python convert.py
```

This creates `telemetry.csv` from `data/test/P-1.npy`.

### 3. Compile the C Program

```bash
gcc kmp_telemetry.c -o anomaly
```

### 4. Run the GUI

```bash
python gui_2.py
```

- Click **Run Detection** → executes the C binary and shows anomaly indices
- Click **Show Graph** → plots the telemetry data with the anomaly region highlighted in red

### 5. (Optional) Standalone Plot

```bash
python PLOT.py
```

---

## 🔍 Algorithm Details

### Trend Encoding
Each pair of consecutive data points is encoded as:
- `U` → current value > previous value
- `D` → current value ≤ previous value

### KMP Matching
- The **full telemetry stream** is encoded as a pattern string
- A known anomaly segment (indices `2149–2349`) is encoded as the search pattern
- KMP finds all occurrences of this pattern in O(n + m) time

---

## 📊 Sample Output

```
Telemetry Anomaly Detection

✔ Anomaly detected at index: 2149
```

The GUI highlights the anomaly region in red on the time-series plot:

> Anomaly region: indices **2149 – 2349**

---

## 🖥️ GUI Preview

The dark-themed interface includes:
- A **Run Detection** button that calls the compiled C binary
- A **Show Graph** button that renders the telemetry plot inline
- A console output area for detection results

---

## 📦 Dataset

This project uses the **SKAB (Skoltech Anomaly Benchmark)** or a similar `.npy` format telemetry dataset. Place your dataset at:

```
data/test/P-1.npy
```

> The first column of the array is used as the sensor signal.

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| Anomaly Detection | C (KMP Algorithm) |
| GUI | Python, Tkinter |
| Visualization | Matplotlib |
| Data Handling | NumPy |

---

## 📄 License

This project is open source. Feel free to use and modify it.
