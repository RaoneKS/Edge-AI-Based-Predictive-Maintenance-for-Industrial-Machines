import h5py
import numpy as np
from pathlib import Path

source = Path("ml/data/online/sample_motor.hdf5")
output = Path("quartus/de10_motor_vibration/motor_vibration.hex")

WINDOW = 256
SCALE = 1000

with h5py.File(source, "r") as f:
    vibration = f["open_DC_motor"][:, 0].astype(np.float64)

# First window of the real vibration recording.
window = vibration[:WINDOW]

# Fixed-point conversion: engineering units multiplied by 1000.
samples = np.rint(window * SCALE).astype(np.int32)
samples = np.clip(samples, -32768, 32767).astype(np.int16)

output.parent.mkdir(parents=True, exist_ok=True)
with output.open("w") as f:
    for value in samples:
        f.write(f"{int(value) & 0xffff:04x}\n")

print("Generated:", output)
print("Samples:", len(samples))
print("Scale: 1000 counts per vibration unit")
print("Original mean:", float(window.mean()))
print("Original standard deviation:", float(window.std()))
print("Fixed-point minimum:", int(samples.min()))
print("Fixed-point maximum:", int(samples.max()))
print("Fixed-point peak-to-peak:", int(samples.max()) - int(samples.min()))
print("Software RMS:", float(np.sqrt(np.mean(samples.astype(np.float64)**2))))
