#!/usr/bin/env bash
# Canonical Phathom builds: iOS Simulator (default iPhone 17 Pro iOS 26.4) + generic iOS device (iPhone 16 Pro+).
# Vendored llama.xcframework is arm64 simulator + arm64 device only; project excludes x86_64 simulator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=phathom-xcode-common.sh
source "${SCRIPT_DIR}/phathom-xcode-common.sh"

usage() {
  echo "Usage: $0 {sim|device|macos|all}"
  echo "  sim     — build for iOS Simulator (default: iPhone 17 Pro iOS 26.4; see phathom-xcode-common.sh)"
  echo "  device  — build for generic iOS Device (iphoneos; use for real iPhone 16 Pro or newer)"
  echo "  macos   — build for generic macOS (Apple Silicon, macOS 26+)"
  echo "  all     — sim then device"
  echo "Override: CONFIGURATION=Release $0 all"
}

build_sim() {
  local sim_name sim_dest
  sim_name="$(pick_simulator_name)"
  sim_dest="$(pick_simulator_destination)"
  echo "Building ${SCHEME} for iOS Simulator: ${sim_name} (${CONFIGURATION})"
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "${sim_dest}" \
    build
}

build_device() {
  echo "Building ${SCHEME} for generic iOS Device (${CONFIGURATION}) — deploy to iPhone 16 Pro or newer"
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=iOS" \
    build
}

build_macos() {
  echo "Building ${SCHEME} for generic macOS (${CONFIGURATION}) — Apple Silicon, macOS 26+"
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=macOS" \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    build
}

main() {
  local mode="${1:-}"
  case "${mode}" in
    sim) build_sim ;;
    device) build_device ;;
    macos) build_macos ;;
    all)
      build_sim
      build_device
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
