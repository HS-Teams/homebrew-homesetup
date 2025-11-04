#!/usr/bin/env bats

#  Script: hhs-toolcheck.bats
# Purpose: hhs-toolcheck tests.
# Created: Mar 15, 2025
#  Author: OpenAI Assistant
# License: MIT

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-toolcheck.bash"
load_bats_libs

setup_file() {
  FIXTURE_BIN_DIR="${BATS_RUN_TMPDIR}/fixtures/bin"
  mkdir -p "${FIXTURE_BIN_DIR}"
  ORIGINAL_PATH="${PATH}"
  export PATH="${FIXTURE_BIN_DIR}:${PATH}"
}

teardown_file() {
  export PATH="${ORIGINAL_PATH}"
  rm -rf "${FIXTURE_BIN_DIR}"
}

# Provide deterministic icons and OS label for output assertions.
export HHS_MY_OS="TestOS"
CHECK_ICN="[ok]"
ALIAS_ICN="[alias]"
FUNC_ICN="[func]"
CROSS_ICN="[x]"
STAR_ICN="*"
POINTER_ICN="->"

# Maintain stubbed metadata for command resolution.
declare -Ag STUB_TOOL_STATES=()
declare -Ag STUB_COMMAND_PATHS=()
declare -Ag STUB_ALIAS_BODIES=()

# Override command -v lookups to use stubbed metadata when available.
command() {
  if [[ "$1" == "-v" ]]; then
    local tool="$2"
    local kind="${STUB_TOOL_STATES[$tool]}"
    case "${kind}" in
    path)
      local path_result="${STUB_COMMAND_PATHS[$tool]}"
      printf '%s' "${path_result:-/usr/bin/${tool}}"
      return 0
      ;;
    alias)
      printf "alias %s='%s'" "${tool}" "${STUB_ALIAS_BODIES[$tool]}"
      return 0
      ;;
    function)
      printf '%s' "${tool}"
      return 0
      ;;
    missing|'')
      return 1
      ;;
    esac
  fi

  builtin command "$@"
}

# Override alias lookup to rely on stubbed metadata.
alias() {
  if [[ "$#" -eq 1 && "$1" != "-p" ]]; then
    local tool="$1"
    if [[ "${STUB_TOOL_STATES[$tool]}" == "alias" ]]; then
      printf "alias %s='%s'\n" "${tool}" "${STUB_ALIAS_BODIES[$tool]}"
      return 0
    fi
    return 1
  fi

  builtin alias "$@"
}

# Override __hhs_has to leverage the stubbed metadata.
__hhs_has() {
  if [[ "$#" -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "usage: __hhs_has <command>"
    return 1
  fi

  local tool="$1"
  case "${STUB_TOOL_STATES[$tool]}" in
  path | alias | function)
    return 0
    ;;
  missing | '')
    return 1
    ;;
  esac
}

setup() {
  STUB_TOOL_STATES=()
  STUB_COMMAND_PATHS=()
  STUB_ALIAS_BODIES=()
  OLDIFS="${IFS}"

  SAMPLE_VERSION_PATH="${FIXTURE_BIN_DIR}/sample-version"
  cat <<'EOF' >"${SAMPLE_VERSION_PATH}"
#!/usr/bin/env bash

case "$1" in
  --version)
    echo "sample-version 1.0.0"
    exit 0
    ;;
  -v)
    echo "sample-version v1.0.0"
    exit 0
    ;;
  -V)
    echo "sample-version V1.0.0"
    exit 0
    ;;
esac

exit 1
EOF
  chmod +x "${SAMPLE_VERSION_PATH}"
}

teardown() {
  rm -f "${SAMPLE_VERSION_PATH}"
  IFS="${OLDIFS}"
}

stub_path_tool() {
  local tool="$1"
  local path="$2"
  STUB_TOOL_STATES["${tool}"]='path'
  STUB_COMMAND_PATHS["${tool}"]="${path}"
}

stub_alias_tool() {
  local tool="$1"
  local body="$2"
  STUB_TOOL_STATES["${tool}"]='alias'
  STUB_ALIAS_BODIES["${tool}"]="${body}"
}

stub_function_tool() {
  local tool="$1"
  STUB_TOOL_STATES["${tool}"]='function'
}

stub_missing_tool() {
  local tool="$1"
  STUB_TOOL_STATES["${tool}"]='missing'
}

# TC - 1
@test "when-invoking-toolcheck-without-arguments-then-prints-usage" {
  run __hhs_toolcheck
  assert_failure
  assert_output --partial "usage: __hhs_toolcheck"
}

# TC - 2
@test "when-tool-exists-on-path-then-reports-installed" {
  stub_path_tool "path-tool" "/stub/bin/path-tool"

  run __hhs_toolcheck "path-tool"

  assert_success
  assert_output --partial "[TestOS] Checking: path-tool"
  assert_output --partial "INSTALLED => /stub/bin/path-tool"
}

# TC - 3
@test "when-tool-is-aliased-then-reports-alias" {
  stub_alias_tool "alias-tool" "echo aliased"

  run __hhs_toolcheck "alias-tool"

  assert_success
  assert_output --partial "ALIASED   => alias alias-tool='echo aliased'"
}

# TC - 4
@test "when-tool-is-a-function-then-reports-function" {
  stub_function_tool "function-tool"

  run __hhs_toolcheck "function-tool"

  assert_success
  assert_output --partial "function function-tool(){...}"
}

# TC - 5
@test "when-tool-is-missing-then-reports-not-found" {
  stub_missing_tool "missing-tool"

  run __hhs_toolcheck "missing-tool"

  assert_failure
  assert_output --partial "NOT FOUND"
}

# TC - 6
@test "when-tool-is-missing-in-quiet-mode-then-suppresses-output" {
  stub_missing_tool "missing-tool"

  run __hhs_toolcheck -q "missing-tool"

  assert_failure
  assert_output --empty
}

# TC - 7
@test "when-checking-version-of-installed-tool-then-shows-version" {
  stub_path_tool "sample-version" "${FIXTURE_BIN_DIR}/sample-version"

  run __hhs_version "sample-version"

  assert_success
  assert_output --partial "sample-version 1.0.0"
}

# TC - 8
@test "when-checking-version-of-missing-tool-then-shows-error" {
  stub_missing_tool "ghost"

  run __hhs_version "ghost"

  assert_failure
  assert_output --partial "Can't check version"
}

# TC - 9
@test "when-running-tools-with-custom-list-then-invokes-toolcheck-for-each" {
  stub_path_tool "tool-a" "/stub/bin/tool-a"
  stub_alias_tool "tool-b" "echo B"
  stub_missing_tool "tool-c"

  run __hhs_tools tool-a tool-b tool-c

  assert_success
  assert_output --partial "Checking (3) development tools"
  assert_output --partial "Checking: tool-a"
  assert_output --partial "Checking: tool-b"
  assert_output --partial "Checking: tool-c"
  assert_output --partial "To check the current installed version"
}

# TC - 10
@test "when-running-tools-with-default-list-containing-missing-tool-then-returns-success" {
  HHS_DEV_TOOLS=(tool-a missing-tool)
  stub_path_tool "tool-a" "/stub/bin/tool-a"
  stub_missing_tool "missing-tool"

  run __hhs_tools

  assert_success
  assert_output --partial "Checking (2) development tools"
  assert_output --partial "Checking: tool-a"
  assert_output --partial "Checking: missing-tool"
}
