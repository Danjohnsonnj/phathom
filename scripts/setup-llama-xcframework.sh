#!/usr/bin/env bash
# Copies a pre-built llama.xcframework into Phathom (e.g. after building via intrai-llama's setup script).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${REPO_ROOT}/Phathom/vendor/llama"
DEST_XCFRAMEWORK="${DEST_DIR}/llama.xcframework"

INTRAI_XCF="${HOME}/Local Documents/repos/intrai-llama/vendor/llama/llama.xcframework"

if [ ! -d "${INTRAI_XCF}" ]; then
  echo "Expected: ${INTRAI_XCF}"
  echo "Build it first, e.g.: bash \"${HOME}/Local Documents/repos/intrai-llama/scripts/setup-llama-xcframework.sh\""
  exit 1
fi

mkdir -p "${DEST_DIR}"
rm -rf "${DEST_XCFRAMEWORK}"
cp -R "${INTRAI_XCF}" "${DEST_XCFRAMEWORK}"
echo "Installed ${DEST_XCFRAMEWORK}"
