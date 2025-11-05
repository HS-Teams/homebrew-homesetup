#!/usr/bin/env bats

#  Script: hhs-clitt.bats
# Purpose: hhs-clitt tests.
# Created: Feb 06, 2025
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-clitt.bash"
load_bats_libs

setup() {

  export HHS_TEST_VENV_ACTIVE=0
  export PYTHON3_CALL_LOG="$(mktemp)"
  __HHS_PYTHON_STUB_DIR="$(mktemp -d)"

  cat <<'PYEOF' >"${__HHS_PYTHON_STUB_DIR}/python3"
#!/usr/bin/env bash
printf "%s\n" "$@" >>"${PYTHON3_CALL_LOG}"
if [[ -n "${PYTHON3_STDOUT}" ]]; then
  printf "%s" "${PYTHON3_STDOUT}"
fi
if [[ -n "${PYTHON3_EXIT_CODE}" ]]; then
  exit "${PYTHON3_EXIT_CODE}"
fi
exit 0
PYEOF
  chmod +x "${__HHS_PYTHON_STUB_DIR}/python3"
  export __HHS_OLD_PATH="${PATH}"
  export PATH="${__HHS_PYTHON_STUB_DIR}:${PATH}"

  export CLASSIC_MCHOOSE_LOG="$(mktemp)"
  export CLASSIC_MSELECT_LOG="$(mktemp)"
  export CLASSIC_MCHOOSE_CALLED=0
  export CLASSIC_MSELECT_CALLED=0
  unset PYTHON3_EXIT_CODE PYTHON3_STDOUT

  function __hhs_is_venv() {
    [[ "${HHS_TEST_VENV_ACTIVE}" == "1" ]]
  }

  function __hhs_classic_mchoose() {
    CLASSIC_MCHOOSE_CALLED=1
    printf "%s\n" "$@" >>"${CLASSIC_MCHOOSE_LOG}"
    echo "classic-mchoose" >"$1"
    return "${CLASSIC_MCHOOSE_STATUS:-0}"
  }

  function __hhs_classic_mselect() {
    CLASSIC_MSELECT_CALLED=1
    printf "%s\n" "$@" >>"${CLASSIC_MSELECT_LOG}"
    echo "classic-mselect" >"$1"
    return "${CLASSIC_MSELECT_STATUS:-0}"
  }
}

teardown() {
  [[ -n "${__HHS_OLD_PATH}" ]] && export PATH="${__HHS_OLD_PATH}"
  [[ -d "${__HHS_PYTHON_STUB_DIR}" ]] && rm -rf "${__HHS_PYTHON_STUB_DIR}"
  [[ -f "${PYTHON3_CALL_LOG}" ]] && rm -f "${PYTHON3_CALL_LOG}"
  [[ -f "${CLASSIC_MCHOOSE_LOG}" ]] && rm -f "${CLASSIC_MCHOOSE_LOG}"
  [[ -f "${CLASSIC_MSELECT_LOG}" ]] && rm -f "${CLASSIC_MSELECT_LOG}"
}

# TC - 1
@test "when-venv-active-mchoose-invokes-python-backend" {
  HHS_TEST_VENV_ACTIVE=1
  outfile="$(mktemp)"
  run __hhs_mchoose "${outfile}" "Pick" "one" "two"
  assert_success
  grep -q "clitt.core.tui.mchoose.mchoose" "${PYTHON3_CALL_LOG}"
  [[ "${CLASSIC_MCHOOSE_CALLED}" -eq 0 ]]
  [[ -f "${outfile}" ]]
  rm -f "${outfile}"
}

# TC - 2
@test "when-venv-inactive-mchoose-falls-back-to-classic" {
  skip "pending fix"
  HHS_TEST_VENV_ACTIVE=0
  outfile="$(mktemp)"
  : >"${PYTHON3_CALL_LOG}"
  run __hhs_mchoose "${outfile}" "Pick" "alpha" "beta"
  assert_success
  [[ "${CLASSIC_MCHOOSE_CALLED}" -eq 1 ]]
  grep -q "alpha" "${CLASSIC_MCHOOSE_LOG}"
  [[ ! -s "${PYTHON3_CALL_LOG}" ]]
  [[ "$(<"${outfile}")" == "classic-mchoose" ]]
  rm -f "${outfile}"
}

# TC - 3
@test "when-venv-active-mselect-invokes-python-backend" {
  HHS_TEST_VENV_ACTIVE=1
  outfile="$(mktemp)"
  run __hhs_mselect "${outfile}" "Select" "one" "two" "three"
  assert_success
  grep -q "clitt.core.tui.mselect.mselect" "${PYTHON3_CALL_LOG}"
  [[ "${CLASSIC_MSELECT_CALLED}" -eq 0 ]]
  [[ -f "${outfile}" ]]
  rm -f "${outfile}"
}

# TC - 4
@test "when-venv-inactive-mselect-falls-back-to-classic" {
  skip "pending fix"
  HHS_TEST_VENV_ACTIVE=0
  outfile="$(mktemp)"
  : >"${PYTHON3_CALL_LOG}"
  run __hhs_mselect "${outfile}" "Select" "alpha" "beta"
  assert_success
  [[ "${CLASSIC_MSELECT_CALLED}" -eq 1 ]]
  grep -q "alpha" "${CLASSIC_MSELECT_LOG}"
  [[ ! -s "${PYTHON3_CALL_LOG}" ]]
  [[ "$(<"${outfile}")" == "classic-mselect" ]]
  rm -f "${outfile}"
}

# TC - 5
@test "when-venv-active-minput-invokes-python-backend" {
  HHS_TEST_VENV_ACTIVE=1
  outfile="$(mktemp)"
  run __hhs_minput "${outfile}" "Form" "Name|||" "Age|||"
  assert_success
  grep -q "clitt.core.tui.minput.minput" "${PYTHON3_CALL_LOG}"
  rm -f "${outfile}"
}

# TC - 6
@test "when-venv-inactive-minput-returns-an-error" {
  skip "pending fix"
  HHS_TEST_VENV_ACTIVE=0
  outfile="$(mktemp)"
  run __hhs_minput "${outfile}" "Form" "Name|||"
  assert_failure
  assert_output --partial "Not available when HomeSetup python venv is not active!"
  rm -f "${outfile}"
}

# TC - 7
@test "when-venv-active-punch-runs-default-command" {
  skip "pending fix"
  HHS_TEST_VENV_ACTIVE=1
  run __hhs_punch
  assert_success
  grep -q "-m" "${PYTHON3_CALL_LOG}"
  grep -q "widgets" "${PYTHON3_CALL_LOG}"
  grep -q "punch" "${PYTHON3_CALL_LOG}"
  tail -n1 "${PYTHON3_CALL_LOG}" | grep -q "punch"
}

# TC - 8
@test "when-venv-active-punch-runs-listed-options" {
  HHS_TEST_VENV_ACTIVE=1

  run __hhs_punch --list
  assert_success
  grep -q "widgets" "${PYTHON3_CALL_LOG}"
  tail -n1 "${PYTHON3_CALL_LOG}" | grep -q "list"

  : >"${PYTHON3_CALL_LOG}"
  run __hhs_punch --edit
  assert_success
  tail -n1 "${PYTHON3_CALL_LOG}" | grep -q "edit"

  : >"${PYTHON3_CALL_LOG}"
  run __hhs_punch --reset
  assert_success
  tail -n1 "${PYTHON3_CALL_LOG}" | grep -q "reset"

  : >"${PYTHON3_CALL_LOG}"
  run __hhs_punch --week 42
  assert_success
  tail -n2 "${PYTHON3_CALL_LOG}" | grep -q "week"
  tail -n1 "${PYTHON3_CALL_LOG}" | grep -q "42"
}

# TC - 9
@test "when-venv-inactive-punch-returns-an-error" {
  HHS_TEST_VENV_ACTIVE=0
  : >"${PYTHON3_CALL_LOG}"
  run __hhs_punch --list
  assert_failure
  assert_output --partial "Not available when HomeSetup python venv is not active!"
  [[ ! -s "${PYTHON3_CALL_LOG}" ]]
}
