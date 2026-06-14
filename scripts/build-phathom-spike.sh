#!/usr/bin/env bash
# Build PhathomMacSpike CLI (macOS arm64). Requires macos-arm64 slice in llama.xcframework.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Capture caller override before phathom-xcode-common exports CONFIGURATION=Debug.
SPIKE_CONFIGURATION="${CONFIGURATION-Release}"
# shellcheck source=phathom-xcode-common.sh
source "${SCRIPT_DIR}/phathom-xcode-common.sh"

echo "Building PhathomMacSpike (${SPIKE_CONFIGURATION}, macOS arm64)"
xcodebuild \
  -project "${PROJECT}" \
  -scheme PhathomMacSpike \
  -configuration "${SPIKE_CONFIGURATION}" \
  -destination "platform=macOS,arch=arm64" \
  build

DERIVED="$(xcodebuild \
  -project "${PROJECT}" \
  -scheme PhathomMacSpike \
  -configuration "${SPIKE_CONFIGURATION}" \
  -destination "platform=macOS,arch=arm64" \
  -showBuildSettings 2>/dev/null | awk -F ' = ' '/^ *BUILT_PRODUCTS_DIR/ {print $2; exit}')"
SPIKE_BIN="${DERIVED}/PhathomMacSpike"
if [ ! -x "${SPIKE_BIN}" ]; then
  echo "Expected spike binary at: ${SPIKE_BIN}" >&2
  exit 1
fi
echo "Built ${SPIKE_BIN}"
