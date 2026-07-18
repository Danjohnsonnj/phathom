#!/usr/bin/env bash
# Copies a pre-built llama.xcframework into Phathom.
# Prefer building in-repo: bash scripts/rebuild-llama-xcframework-with-mtmd.sh
# Or set SOURCE_XCF to an existing llama.xcframework path.
# Upstream packaging is arm64 iOS Simulator + arm64 device; Phathom excludes x86_64 simulator at the project level.
# After refreshing the framework, verify builds: bash scripts/build-phathom.sh all
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${REPO_ROOT}/Phathom/vendor/llama"
DEST_XCFRAMEWORK="${DEST_DIR}/llama.xcframework"

SOURCE_XCF="${SOURCE_XCF:-}"

if [ -z "${SOURCE_XCF}" ] || [ ! -d "${SOURCE_XCF}" ]; then
  echo "Set SOURCE_XCF to an existing llama.xcframework directory."
  echo "Example: SOURCE_XCF=/path/to/llama.xcframework bash scripts/setup-llama-xcframework.sh"
  echo "Or build and install directly: bash scripts/rebuild-llama-xcframework-with-mtmd.sh"
  exit 1
fi

mkdir -p "${DEST_DIR}"
rm -rf "${DEST_XCFRAMEWORK}"
cp -R "${SOURCE_XCF}" "${DEST_XCFRAMEWORK}"
echo "Installed ${DEST_XCFRAMEWORK}"
