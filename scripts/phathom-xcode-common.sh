#!/usr/bin/env bash
# Shared Xcode paths + simulator picker for Phathom CLI scripts.

PHATHOM_XCODE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "${PHATHOM_XCODE_SCRIPT_DIR}/.." && pwd)"

export PROJECT="${REPO_ROOT}/Phathom/Phathom.xcodeproj"
export SCHEME="Phathom"
export CONFIGURATION="${CONFIGURATION:-Debug}"

# Prefer Pro-line simulators first, then newer non-Pro (matches README / AGENTS.md).
SIMULATOR_NAME_PREFS=(
  "iPhone 16 Pro"
  "iPhone 16 Pro Max"
  "iPhone 17 Pro"
  "iPhone 17 Pro Max"
  "iPhone 18 Pro"
  "iPhone 18 Pro Max"
  "iPhone 17"
)

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
