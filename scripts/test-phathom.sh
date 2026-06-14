#!/usr/bin/env bash
# Run PhathomTests on Simulator (Swift Testing). UITests skipped by default.
# Token-efficient: -quiet default, tee log locally, surface failures with short grep snippets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phathom-xcode-common.sh
source "${SCRIPT_DIR}/phathom-xcode-common.sh"

DISCOVER_CMD=(python3 "${SCRIPT_DIR}/phathom-tests-discover.py" --repo-root "${REPO_ROOT}")
TEST_SRC="${REPO_ROOT}/Phathom/PhathomTests"
LOG="${PHATHOM_TEST_LOG:-${TMPDIR:-/tmp}/phathom-test.log}"
QUIET_XC=( -quiet )
declare -a ONLY_TEST_ARGS=()

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [options]

Options:
  -h, --help              Show this help
  -v, --verbose           Omit xcodebuild -quiet (louder stdout)
      --no-tee            Write log only (no tee to terminal)
      --log PATH          Log file (${LOG})
      --list              List Swift Testing identifiers (delegates to phathom-tests-discover.py)
      --grep REGEX        Run tests matching regex (suite / @Suite label / func)
      --test NAME         Single target: func name, Struct/func(), struct suite name, or full path

Examples:
  $(basename "$0")                                              # full PhathomTests bundle
  $(basename "$0") --test shareCaptureInsertMediaItemQueuesEmbedding
  $(basename "$0") --grep media
USAGE
}

USE_TEE=1
RUN_WIDE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|help)
      usage
      exit 0
      ;;
    -v|--verbose)
      QUIET_XC=()
      shift
      ;;
    --no-tee)
      USE_TEE=0
      shift
      ;;
    --log)
      LOG="${2:?--log requires path}"
      shift 2
      ;;
    --list)
      "${DISCOVER_CMD[@]}" --root "${TEST_SRC}" --list
      exit 0
      ;;
    --grep)
      pat="${2:?--grep requires pattern}"
      shift 2
      GREP_IDS=""
      GREP_IDS="$("${DISCOVER_CMD[@]}" --root "${TEST_SRC}" --grep "${pat}")" || exit $?
      ONLY_TEST_ARGS=()
      RUN_WIDE=0
      while IFS= read -r line || [[ -n "${line:-}" ]]; do
        [[ -z "${line}" ]] && continue
        ONLY_TEST_ARGS+=( "-only-testing:${line}" )
      done <<< "${GREP_IDS}"$'\n'
      ;;
    --test)
      name="${2:?--test requires name}"
      shift 2
      tid=""
      tid="$("${DISCOVER_CMD[@]}" --root "${TEST_SRC}" --resolve "${name}")" || exit $?
      ONLY_TEST_ARGS=( "-only-testing:${tid}" )
      RUN_WIDE=0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

sim_name=""
sim_dest=""
sim_name="$(pick_simulator_name)"
sim_dest="$(pick_simulator_destination)"

if [[ "${RUN_WIDE}" -eq 1 ]]; then
  ONLY_TEST_ARGS=( "-only-testing:PhathomTests" )
fi

XB=(
  xcodebuild test
  -project "${PROJECT}"
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -destination "${sim_dest}"
)

XB+=( "${ONLY_TEST_ARGS[@]}" )
XB+=( "-skip-testing:PhathomUITests" )
XB+=( "-parallel-testing-enabled" "NO" )
XB+=( "${QUIET_XC[@]}" )

set +e
xv=0
if [[ "${USE_TEE}" -eq 1 ]]; then
  "${XB[@]}" 2>&1 | tee "${LOG}"
  xv=${PIPESTATUS[0]}
else
  "${XB[@]}" >"${LOG}" 2>&1
  xv=$?
fi
set -e

echo "PhathomTests: $( [[ "${xv}" -eq 0 ]] && echo passed || echo failed )"

if [[ "${xv}" -ne 0 ]] && [[ -f "${LOG}" ]]; then
  echo "--- failures / errors (max 40 lines) ---" >&2
  grep -E 'failed|Failure|error:' "${LOG}" 2>/dev/null | head -40 >&2 || true
fi

exit "${xv}"
