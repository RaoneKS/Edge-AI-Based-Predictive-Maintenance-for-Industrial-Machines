import csv
import time
import serial
from pathlib import Path

PORT = "/dev/ttyACM0"
BAUD = 115200
DURATION = 30

output = Path("ml/data/motor_running.csv")
output.parent.mkdir(parents=True, exist_ok=True)

print(f"Connecting to {PORT}...")

with serial.Serial(PORT, BAUD, timeout=2) as ser:
    time.sleep(2)
    ser.reset_input_buffer()

    with output.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp_us", "ax_raw", "ay_raw", "az_raw"])

        start = time.time()
        count = 0

        print("Collecting vibration samples for 30 seconds...")

        while time.time() - start < DURATION:
            line = ser.readline().decode("ascii", errors="ignore").strip()

            if not line or line.startswith("timestamp"):
                continue

            parts = line.split(",")

            if len(parts) != 4:
                continue

            try:
                row = [int(x) for x in parts]
            except ValueError:
                continue

            writer.writerow(row)
            count += 1

    print(f"\nSamples collected: {count}")
    print(f"Saved to: {output}")
