#!/usr/bin/env bash
# Create a clean teammate ZIP from committed Git files, with verified local run logs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
OUTPUT="${2:-$HOME/fpga-ai-accelerator-team-bundle.zip}"
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$ROOT/$OUTPUT"
fi
mkdir -p "$(dirname "$OUTPUT")"

if ! git rev-parse --verify "${REF}^{commit}" >/dev/null 2>&1; then
  echo "ERROR: Git ref '$REF' does not resolve to a commit." >&2
  exit 2
fi

COMMIT="$(git rev-parse "${REF}^{commit}")"
BRANCH="$(git branch --show-current)"
TRACKED_COUNT="$(git ls-tree -r --name-only "$REF" | wc -l | tr -d ' ')"

echo "Creating source archive"
echo "  Ref: $REF"
echo "  Commit: $COMMIT"
echo "  Current branch: $BRANCH"
echo "  Tracked files: $TRACKED_COUNT"
echo "  Output: $OUTPUT"

# git archive intentionally includes committed files only: no .git directory,
# local stash, untracked backups, virtualenvs, ignored simulator output or build DBs.
git archive --format=zip --prefix=fpga-ai-accelerator/ "$REF" > "$OUTPUT"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/evidence"

# Include the previously reported full regression log only if it proves the
# 512-window pass and exact 2048-logit comparison. Do not package partial logs.
E2E_LOG="$ROOT/sim/cnn_systolic_integration_run.log"
if [[ -f "$E2E_LOG" ]] \
  && grep -qF "CNN_E2E_TEST_PASSED" "$E2E_LOG" \
  && grep -qF "Exact logits: 2048/2048" "$E2E_LOG" \
  && grep -qF "Prediction/reference: 512/512" "$E2E_LOG"; then
  cp "$E2E_LOG" "$TMP_DIR/evidence/cnn_systolic_512_window_pass.log"
  echo "Included verified 512-window CNN log."
else
  echo "No complete 512-window CNN log found; source archive will be created without it."
fi

ADAPTER_LOG="$ROOT/sim/cnn_systolic_adapter/run.log"
if [[ -f "$ADAPTER_LOG" ]] \
  && grep -qF "CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS" "$ADAPTER_LOG"; then
  cp "$ADAPTER_LOG" "$TMP_DIR/evidence/cnn_systolic_adapter_pass.log"
  echo "Included verified adapter regression log."
else
  echo "No complete adapter regression log found; skipping it."
fi

if [[ -n "$(find "$TMP_DIR/evidence" -type f -print -quit)" ]]; then
  (cd "$TMP_DIR" && zip -q -r "$OUTPUT" evidence)
fi

echo
echo "Checking ZIP integrity..."
unzip -t "$OUTPUT" | tail -n 2
echo
sha256sum "$OUTPUT"
echo "TEAM_BUNDLE_CREATED=$OUTPUT"
