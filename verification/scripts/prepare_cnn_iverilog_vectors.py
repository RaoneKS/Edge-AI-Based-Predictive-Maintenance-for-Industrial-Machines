#!/usr/bin/env python3
"""Convert authoritative CNN .npy vectors into Icarus $readmemh files.
Does not regenerate or modify the reference vectors."""
from pathlib import Path
import sys
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "cnn_vectors"))
from generate_vectors import load_manifest, load_reference_data, reference_inference

ROOT = Path(__file__).resolve().parents[2]
V = ROOT / "verification" / "cnn_vectors"
OUT = ROOT / "sim" / "cnn_vectors"

def hex_lines(a, bits):
    mask = (1 << bits) - 1
    flat = np.asarray(a).reshape(-1)
    return "\n".join(f"{int(x) & mask:0{bits//4}x}" for x in flat) + "\n"

def emit(name, arr, bits):
    p = OUT / name
    p.write_text(hex_lines(arr, bits))
    print(f"{p}: {np.asarray(arr).shape}, {np.asarray(arr).dtype}")

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    emit("input.hex", np.load(V/"input_int8.npy"), 8)
    emit("reference_logits.hex", np.load(V/"reference_logits_int8.npy"), 32)
    emit("reference_predictions.hex", np.load(V/"reference_predictions.npy"), 8)
    emit("reference_labels.hex", np.load(V/"reference_labels.npy"), 8)
    emit("conv1_weights.hex", np.load(V/"conv1_weights.npy"), 8)
    emit("conv1_bias.hex", np.load(V/"conv1_bias.npy"), 32)
    emit("conv2_weights.hex", np.load(V/"conv2_weights.npy"), 8)
    emit("conv2_bias.hex", np.load(V/"conv2_bias.npy"), 32)
    emit("classifier_weights.hex", np.load(V/"classifier_weights.npy")[:, :4], 8)
    emit("classifier_bias.hex", np.load(V/"classifier_bias.npy"), 32)

    # Build expected intermediate tensors for the first 32 windows using the
    # same reference_inference() routine that generated the final logits.
    inputs = np.load(V / "input_int8.npy")
    ref_logits = np.load(V / "reference_logits_int8.npy")
    if inputs.shape != (512, 256) or ref_logits.shape != (512, 4):
        raise SystemExit(
            f"ERROR: unexpected authoritative shapes {inputs.shape}, {ref_logits.shape}"
        )
    manifest = load_manifest()
    ref_data = load_reference_data()
    stage_data = {"conv1": [], "pool": [], "conv2": [], "gap": []}
    for wi in range(32):
        result = reference_inference(inputs[wi], manifest, ref_data)
        if not np.array_equal(result["logits"].astype(np.int32), ref_logits[wi]):
            raise SystemExit(f"ERROR: intermediate reference recompute differs at window {wi}")
        for stage in stage_data:
            stage_data[stage].append(result[stage].astype(np.int8))
    for stage, values in stage_data.items():
        arr = np.stack(values, axis=0)
        emit(f"{stage}_first32.hex", arr, 8)
    print("Generated golden Conv1/MaxPool/Conv2/GAP tensors for first 32 windows.")
    print("Authoritative vectors converted; source .npy files were not modified.")

if __name__ == "__main__":
    main()
