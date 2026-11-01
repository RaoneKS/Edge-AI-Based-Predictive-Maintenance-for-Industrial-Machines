#!/usr/bin/env bash
# Build a teammate ZIP from the exact committed Git snapshot.
# Usage: bash scripts/package_teammate_bundle.sh [output-directory]
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: Run this script from inside the Git repository." >&2
  exit 2
}
cd "$ROOT"

command -v git >/dev/null || { echo "ERROR: git is required." >&2; exit 127; }
command -v zip >/dev/null || { echo "ERROR: zip is required (install with: sudo apt install zip)." >&2; exit 127; }
command -v unzip >/dev/null || { echo "ERROR: unzip is required (install with: sudo apt install unzip)." >&2; exit 127; }

BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
SHORT_COMMIT="$(git rev-parse --short=12 HEAD)"
PROJECT="$(basename "$ROOT")"
BUNDLE_NAME="$PROJECT-$BRANCH-$SHORT_COMMIT"
OUT_DIR="$ROOT/../teammate_bundles"
if [[ $# -ge 1 ]]; then OUT_DIR="$1"; fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
ZIP_PATH="$OUT_DIR/$BUNDLE_NAME.zip"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
STAGE_ROOT="$TMP_ROOT/$BUNDLE_NAME"
mkdir -p "$STAGE_ROOT"

echo "Exporting every Git-tracked file from $COMMIT ..."
git archive --format=tar "$COMMIT" | tar -xf - -C "$STAGE_ROOT"

TRACKED_COUNT="$(git ls-tree -r --name-only "$COMMIT" | wc -l | tr -d ' ')"
cat > "$STAGE_ROOT/BUNDLE_INFO.txt" <<INFO
Project: $PROJECT
Branch: $BRANCH
Commit: $COMMIT
Tracked files exported: $TRACKED_COUNT

This is a source snapshot of the committed Git tree. It does not contain
.git history, untracked local files, local backup copies, simulator scratch
files, or Quartus temporary databases. Use Git clone if the team needs
history and ongoing collaboration.

The repository's committed RTL, testbenches, scripts, model artifacts,
datasets, documentation, and third-party reference files are included
where they are tracked by Git.
INFO

EVIDENCE_LOG="$ROOT/sim/cnn_systolic_integration_run.log"
if [[ -s "$EVIDENCE_LOG" ]] &&
   grep -q "CNN_E2E_TEST_PASSED" "$EVIDENCE_LOG" &&
   grep -q "CNN_SYSTOLIC_E2E_EXIT_STATUS=0" "$EVIDENCE_LOG"; then
  mkdir -p "$STAGE_ROOT/verification/evidence"
  cp "$EVIDENCE_LOG" "$STAGE_ROOT/verification/evidence/cnn_systolic_512_window_pass.log"
  cat > "$STAGE_ROOT/verification/evidence/README.txt" <<'EVIDENCE'
This is the raw console log from the completed 512-window systolic CNN E2E run.
It records exact logits, RTL/reference predictions, true-label accuracy,
back-to-back inference, and same-window-repeat results. The run's source
commit is printed near the top of the log. This evidence is simulation-only;
it is not Quartus timing, FPGA programming, or physical-board evidence.
EVIDENCE
  echo "Included verified 512-window systolic E2E log."
else
  echo "NOTE: No complete 512-window E2E log found at sim/cnn_systolic_integration_run.log; evidence log omitted."
fi

(
  cd "$STAGE_ROOT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

rm -f "$ZIP_PATH"
(
  cd "$TMP_ROOT"
  zip -qr "$ZIP_PATH" "$BUNDLE_NAME"
)

unzip -t "$ZIP_PATH" | tail -n 1
echo
echo "BUNDLE_PATH=$ZIP_PATH"
echo "TRACKED_FILES=$TRACKED_COUNT"
sha256sum "$ZIP_PATH"
