#!/usr/bin/env python3
"""Prepare DE10 board ROM images from the authoritative CNN vectors.

The physical demo uses two representative windows:
  demo_inputs[0:256]   = reference window 0 (normal)
  demo_inputs[256:512] = reference window 384 (outer)

Weight artifacts use hardware-oriented layouts:
  Conv1:       [kernel_position][output_channel] = (8, 8)
  Conv2:       [input_channel * kernel + tap][output_channel] = (24, 8)
  Classifier:  [input_feature][physical_output] = (8, 8)

The three unused Conv1 kernel positions and four unused classifier
output lanes must be zero-padded in the authoritative vectors.
"""

from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
V = ROOT / "verification" / "cnn_vectors"
OUT = ROOT / "quartus" / "de10_standard_hw" / "model_data"


def hex_signed8(x):
    return f"{int(x) & 0xff:02x}"


def hex_signed32(x):
    return f"{int(x) & 0xffffffff:08x}"


def write_hex(path, values, formatter):
    path.write_text("\n".join(formatter(v) for v in values) + "\n")


def require(path):
    if not path.exists():
        raise SystemExit(
            f"ERROR: missing {path}. Do not regenerate authoritative vectors "
            "as part of this ROM-preparation step; restore the expected "
            "verification/cnn_vectors/*.npy files first."
        )


def main():
    required = [
        "input_int8.npy",
        "conv1_weights.npy", "conv1_bias.npy",
        "conv2_weights.npy", "conv2_bias.npy",
        "classifier_weights.npy", "classifier_bias.npy",
    ]
    for name in required:
        require(V / name)

    inp = np.load(V / "input_int8.npy")
    c1w = np.load(V / "conv1_weights.npy")
    c1b = np.load(V / "conv1_bias.npy")
    c2w = np.load(V / "conv2_weights.npy")
    c2b = np.load(V / "conv2_bias.npy")
    fcw = np.load(V / "classifier_weights.npy")
    fcb = np.load(V / "classifier_bias.npy")

    # Input shape validation.
    if inp.ndim == 2 and inp.shape[1:] == (256,):
        windows = inp
    elif inp.ndim == 3 and inp.shape[1:] == (1, 256):
        windows = inp[:, 0, :]
    else:
        raise SystemExit(
            f"ERROR: unexpected input shape {inp.shape}; "
            "expected (N, 256) or (N, 1, 256)"
        )

    if windows.shape[0] < 385:
        raise SystemExit(
            f"ERROR: found {windows.shape[0]} input windows; "
            "at least 385 are required for demo windows 0 and 384"
        )

    # Current authoritative artifact shapes.
    if c1w.shape != (8, 8) or c1b.shape != (8,):
        raise SystemExit(
            f"ERROR: unexpected Conv1 shapes {c1w.shape}, {c1b.shape}; "
            "expected weights (8, 8) and bias (8,)"
        )

    if c2w.shape != (24, 8) or c2b.shape != (8,):
        raise SystemExit(
            f"ERROR: unexpected Conv2 shapes {c2w.shape}, {c2b.shape}; "
            "expected weights (24, 8) and bias (8,)"
        )

    if fcw.shape != (8, 8) or fcb.shape != (4,):
        raise SystemExit(
            f"ERROR: unexpected classifier shapes {fcw.shape}, {fcb.shape}; "
            "expected weights (8, 8) and bias (4,)"
        )

    # Never silently discard nonzero trained weights.
    if not np.all(c1w[5:, :] == 0):
        raise SystemExit(
            "ERROR: Conv1 weight rows 5..7 are not all zero; "
            "refusing to discard them when producing the 5-tap hardware ROM."
        )

    if not np.all(fcw[:, 4:] == 0):
        raise SystemExit(
            "ERROR: classifier output lanes 4..7 are not all zero; "
            "refusing to write unexpected values into unused hardware lanes."
        )

    OUT.mkdir(parents=True, exist_ok=True)

    # Board wrapper selects window 0 for normal and window 384 for outer.
    demo = np.concatenate((windows[0, :], windows[384, :])).astype(np.int8)
    write_hex(OUT / "demo_inputs.hex", demo, hex_signed8)

    # RTL indexes c1_w[tap * 8 + output_channel].
    # Physical hardware has 5 taps, so write the first five rows.
    c1_hw = c1w[:5, :].reshape(-1)
    write_hex(OUT / "conv1_weights.hex", c1_hw, hex_signed8)
    write_hex(OUT / "conv1_bias.hex", c1b, hex_signed32)

    # Artifact layout already matches RTL indexing:
    # c2_w[(input_channel * 3 + tap) * 8 + output_channel].
    c2_hw = c2w.reshape(-1)
    write_hex(OUT / "conv2_weights.hex", c2_hw, hex_signed8)
    write_hex(OUT / "conv2_bias.hex", c2b, hex_signed32)

    # Artifact layout already matches RTL indexing:
    # fc_w[input_feature * 8 + physical_output].
    # The final four physical output lanes were checked to be zero above.
    write_hex(OUT / "classifier_weights.hex", fcw.reshape(-1), hex_signed8)

    # Four logical class biases plus four zero-padded physical lanes.
    fc_bias_hw = np.zeros(8, dtype=np.int32)
    fc_bias_hw[:4] = fcb
    write_hex(OUT / "classifier_bias.hex", fc_bias_hw, hex_signed32)

    print("DE10 model ROMs prepared successfully.")
    print("Source: verification/cnn_vectors/*.npy")
    print("Normal demo window: 0")
    print("Outer demo window: 384")
    print("Conv1: 40 weights; Conv2: 192 weights; classifier: 64 weights")
    for p in sorted(OUT.glob("*.hex")):
        with p.open() as f:
            words = sum(1 for _ in f)
        print(f"{p.name}: {words} words")


if __name__ == "__main__":
    main()
