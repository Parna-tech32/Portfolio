import numpy as np

data = np.load("data/test/P-1.npy")

# Take only first column
data_1d = data[:, 0]

np.savetxt("telemetry.csv", data_1d, delimiter=",")