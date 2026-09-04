import numpy as np
import matplotlib.pyplot as plt

data = np.load("data/test/P-1.npy")

data = data[:, 0]
start, end = 2149, 2349


plt.plot(data)
plt.axvspan(start, end, alpha=0.3)  # anomaly

plt.title("Telemetry Data with Anomaly Region")
plt.xlabel("Time Index")
plt.ylabel("Value")

plt.show()

plt.plot(data)
plt.axvspan(start, end, alpha=0.3, label="Anomaly")
plt.legend()
