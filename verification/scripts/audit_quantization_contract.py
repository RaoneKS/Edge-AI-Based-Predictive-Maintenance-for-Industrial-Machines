#!/usr/bin/env python3
"""Compare the exact deployed shift/truncation contract with training's rounded INT8 path."""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys_path = ROOT / "verification" / "cnn_vectors"
import sys
sys.path.insert(0, str(sys_path))
from generate_vectors import load_manifest, load_reference_data, reference_inference, im2col_1d

V = ROOT / "verification" / "cnn_vectors"
OUT = ROOT / "verification" / "results" / "quantization_contract_audit.json"


def round_shift_away_from_zero(values: np.ndarray, shift: int) -> np.ndarray:
    """Mirror train_and_export.rq for positive right shifts."""
    values = np.asarray(values, dtype=np.int64)
    if shift == 0:
        return values.copy()
    if shift < 0:
        return values << (-shift)
    bias = 1 << (shift - 1)
    return np.where(values >= 0,
                    (values + bias) >> shift,
                    -(((-values) + bias) >> shift))


def quantize(values, shift: int, relu: bool, rounded: bool) -> np.ndarray:
    values = np.asarray(values, dtype=np.int64)
    if relu:
        values = np.maximum(values, 0)
    q = round_shift_away_from_zero(values, shift) if rounded else (values >> shift)
    lo = -127 if rounded else -128
    return np.clip(q, lo, 127).astype(np.int8)


def rounded_inference(window: np.ndarray, ref: dict) -> np.ndarray:
    c1x = im2col_1d(window, 5).astype(np.int64)
    c1w = ref["conv1_w"][:5, :].astype(np.int64)
    c1 = c1x @ c1w + ref["conv1_b"].astype(np.int64)
    c1q = quantize(c1, 8, True, True)

    pool = np.maximum(c1q[::2], c1q[1::2]).astype(np.int8)
    c2x = im2col_1d(pool, 3).astype(np.int64)
    c2w = ref["conv2_w"][:24, :].astype(np.int64)
    c2 = c2x @ c2w + ref["conv2_b"].astype(np.int64)
    c2q = quantize(c2, 8, True, True)

    gap_sum = c2q.astype(np.int64).sum(axis=0)
    # torch.round uses ties-to-even, matching np.rint.
    gap = np.rint(gap_sum.astype(np.float64) / 128.0).astype(np.int8)[None, :]

    fc = gap.astype(np.int64) @ ref["clf_w"].astype(np.int64)
    fc = fc + ref["clf_b"].astype(np.int64)
    logits = quantize(fc, 5, False, True)[0, :4]
    return logits.astype(np.int32)


def main():
    inputs = np.load(V / "input_int8.npy")
    labels = np.load(V / "reference_labels.npy").astype(np.int32)
    expected_logits = np.load(V / "reference_logits_int8.npy").astype(np.int32)
    expected_predictions = np.load(V / "reference_predictions.npy").astype(np.int32)
    if inputs.shape != (512, 256):
        raise SystemExit(f"Unexpected input shape: {inputs.shape}")

    manifest = load_manifest()
    ref = load_reference_data()
    floor_logits = np.empty((512, 4), dtype=np.int32)
    round_logits = np.empty((512, 4), dtype=np.int32)

    for idx in range(512):
        floor_result = reference_inference(inputs[idx], manifest, ref)
        floor_logits[idx] = floor_result["logits"].astype(np.int32)
        round_logits[idx] = rounded_inference(inputs[idx], ref)

    if not np.array_equal(floor_logits, expected_logits):
        mismatch = np.argwhere(floor_logits != expected_logits)
        raise SystemExit(f"ERROR: floor/trunc path did not reproduce committed reference; first mismatches={mismatch[:10].tolist()}")

    floor_pred = np.argmax(floor_logits, axis=1)
    round_pred = np.argmax(round_logits, axis=1)
    floor_correct = int(np.sum(floor_pred == labels))
    round_correct = int(np.sum(round_pred == labels))
    logit_diff = np.argwhere(floor_logits != round_logits)
    pred_diff = np.flatnonzero(floor_pred != round_pred).tolist()
    result = {
        "windows": 512,
        "deployed_floor_shift_trunc_gap": {
            "correct": floor_correct,
            "accuracy": floor_correct / 512,
            "matches_authoritative_reference_logits": True,
        },
        "training_symmetric_round_shift_round_gap": {
            "correct": round_correct,
            "accuracy": round_correct / 512,
        },
        "comparison": {
            "different_logit_elements": int(len(logit_diff)),
            "different_logit_windows": int(len(set(int(x[0]) for x in logit_diff))),
            "different_prediction_windows": pred_diff,
            "prediction_difference_count": len(pred_diff),
        },
        "interpretation": (
            "The deployed RTL/reference uses arithmetic right-shift (floor for negatives), "
            "INT8 saturation to [-128,127], and GAP truncation toward zero. "
            "The training integer metric uses symmetric rounded requantization, "
            "GAP torch.round ties-to-even, and clamps to [-127,127]. "
            "Only the deployed contract is used for the RTL golden vectors."
        ),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    print(f"QUANTIZATION_CONTRACT_AUDIT_WRITTEN={OUT}")


if __name__ == "__main__":
    main()
