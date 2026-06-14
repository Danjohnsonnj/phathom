#!/usr/bin/env bash
# Shared Xcode paths + simulator picker for Phathom CLI scripts.
#
# Simulator overrides (when default picker hits sim-clone / missing-runtime failures):
#   PHATHOM_SIMULATOR_NAME      — device name (default: iPhone 17 Pro)
#   PHATHOM_SIMULATOR_OS_PREFIX — OS version prefix, e.g. 26.4 (default: 26.4)
# Example: PHATHOM_SIMULATOR_NAME="iPhone 16 Pro" PHATHOM_SIMULATOR_OS_PREFIX=26.4 bash scripts/test-phathom.sh

PHATHOM_XCODE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "${PHATHOM_XCODE_SCRIPT_DIR}/.." && pwd)"

export PROJECT="${REPO_ROOT}/Phathom/Phathom.xcodeproj"
export SCHEME="Phathom"
export CONFIGURATION="${CONFIGURATION:-Debug}"

# Default sim unless user overrides in chat/session: iPhone 17 Pro @ iOS 26.4.x
export PHATHOM_SIMULATOR_NAME="${PHATHOM_SIMULATOR_NAME:-iPhone 17 Pro}"
export PHATHOM_SIMULATOR_OS_PREFIX="${PHATHOM_SIMULATOR_OS_PREFIX:-26.4}"

# Fallback names when default device/runtime not installed.
SIMULATOR_NAME_PREFS=(
  "iPhone 17 Pro"
  "iPhone 17 Pro Max"
  "iPhone 16 Pro"
  "iPhone 16 Pro Max"
  "iPhone 18 Pro"
  "iPhone 18 Pro Max"
  "iPhone 17"
)

_phathom_simulator_dest_lines() {
  xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -showdestinations 2>/dev/null || true
}

# Echo xcodebuild -destination value (id-based when possible).
pick_simulator_destination() {
  local dest_lines line id name os_prefix
  dest_lines="$(_phathom_simulator_dest_lines)"
  os_prefix="${PHATHOM_SIMULATOR_OS_PREFIX}"

  line="$(echo "${dest_lines}" | grep -F "name:${PHATHOM_SIMULATOR_NAME}" | grep -E "OS:${os_prefix}" | head -1)"
  if [[ -z "${line}" ]]; then
    line="$(echo "${dest_lines}" | grep -F "name:${PHATHOM_SIMULATOR_NAME}" | head -1)"
  fi
  if [[ -n "${line}" ]]; then
    id="$(echo "${line}" | sed -n 's/.*id:\([^,} ]*\).*/\1/p')"
    if [[ -n "${id}" ]]; then
      echo "platform=iOS Simulator,id=${id}"
      return 0
    fi
  fi

  for name in "${SIMULATOR_NAME_PREFS[@]}"; do
    line="$(echo "${dest_lines}" | grep -F "name:${name}" | head -1)"
    if [[ -n "${line}" ]]; then
      id="$(echo "${line}" | sed -n 's/.*id:\([^,} ]*\).*/\1/p')"
      if [[ -n "${id}" ]]; then
        echo "platform=iOS Simulator,id=${id}"
        return 0
      fi
      echo "platform=iOS Simulator,name=${name}"
      return 0
    fi
  done

  echo "No preferred simulator found. Install ${PHATHOM_SIMULATOR_NAME} (iOS ${os_prefix}+) or another iPhone Pro simulator, then retry." >&2
  echo "Available destinations:" >&2
  echo "${dest_lines}" >&2
  return 1
}

pick_simulator_name() {
  local dest_lines line
  dest_lines="$(_phathom_simulator_dest_lines)"

  line="$(echo "${dest_lines}" | grep -F "name:${PHATHOM_SIMULATOR_NAME}" | grep -E "OS:${PHATHOM_SIMULATOR_OS_PREFIX}" | head -1)"
  if [[ -n "${line}" ]]; then
    echo "${PHATHOM_SIMULATOR_NAME}"
    return 0
  fi
  if echo "${dest_lines}" | grep -F "name:${PHATHOM_SIMULATOR_NAME}" >/dev/null 2>&1; then
    echo "${PHATHOM_SIMULATOR_NAME}"
    return 0
  fi

  local name
  for name in "${SIMULATOR_NAME_PREFS[@]}"; do
    if echo "${dest_lines}" | grep -F "name:${name}" >/dev/null 2>&1; then
      echo "${name}"
      return 0
    fi
  done

  echo "No preferred simulator found. Install ${PHATHOM_SIMULATOR_NAME} (iOS ${PHATHOM_SIMULATOR_OS_PREFIX}+) or another iPhone Pro simulator, then retry." >&2
  echo "Available destinations:" >&2
  echo "${dest_lines}" >&2
  return 1
}
