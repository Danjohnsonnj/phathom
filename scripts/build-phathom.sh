#!/usr/bin/env bash
# Canonical Phathom builds: iOS Simulator (iPhone 16 Pro or newer sim) + generic iOS device (real iPhone 16 Pro+).
# Vendored llama.xcframework is arm64 simulator + arm64 device only; project excludes x86_64 simulator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${REPO_ROOT}/Phathom/Phathom.xcodeproj"
SCHEME="Phathom"
CONFIGURATION="${CONFIGURATION:-Debug}"

# Prefer Pro-line simulators first, then newer non-Pro (matches README / handoff).
SIMULATOR_NAME_PREFS=(
  "iPhone 16 Pro"
  "iPhone 16 Pro Max"
  "iPhone 17 Pro"
  "iPhone 17 Pro Max"
  "iPhone 18 Pro"
  "iPhone 18 Pro Max"
  "iPhone 17"
)

usage() {
  echo "Usage: $0 {sim|device|all}"
  echo "  sim     — build for iOS Simulator (first available name from the iPhone 16 Pro+ preference list)"
  echo "  device  — build for generic iOS Device (iphoneos; use for real iPhone 16 Pro or newer)"
  echo "  all     — sim then device"
  echo "Override: CONFIGURATION=Release $0 all"
}

pick_simulator_name() {
  local dest_lines
  dest_lines="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -showdestinations 2>/dev/null || true)"
  local name
  for name in "${SIMULATOR_NAME_PREFS[@]}"; do
    if echo "${dest_lines}" | grep -F "name:${name}" >/dev/null 2>&1; then
      echo "${name}"
      return 0
    fi
  done
  echo "No preferred simulator found. Install an iPhone 16 Pro or newer simulator runtime, then retry." >&2
  echo "Available destinations:" >&2
  echo "${dest_lines}" >&2
  return 1
}

build_sim() {
  local sim_name
  sim_name="$(pick_simulator_name)"
  echo "Building ${SCHEME} for iOS Simulator: ${sim_name} (${CONFIGURATION})"
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "platform=iOS Simulator,name=${sim_name}" \
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

main() {
  local mode="${1:-}"
  case "${mode}" in
    sim) build_sim ;;
    device) build_device ;;
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
