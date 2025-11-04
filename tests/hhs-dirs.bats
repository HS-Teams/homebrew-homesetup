#!/usr/bin/env bats

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-dirs.bash"
load_bats_libs

declare -ag __HHS_MSELECT_STUB_RESPONSES=()
declare -g __HHS_MSELECT_STUB_STATUS=""

__hhs_mselect() {
  local outfile="$1"
  shift 2 || true
  local selection=""
  if ((${#__HHS_MSELECT_STUB_RESPONSES[@]} > 0)); then
    selection="${__HHS_MSELECT_STUB_RESPONSES[0]}"
    __HHS_MSELECT_STUB_RESPONSES=("${__HHS_MSELECT_STUB_RESPONSES[@]:1}")
  elif (($# > 0)); then
    selection="$1"
  fi

  if [[ -n "${selection}" ]]; then
    printf '%s\n' "${selection}" >"${outfile}"
  else
    : >"${outfile}"
  fi

  if [[ -n "${__HHS_MSELECT_STUB_STATUS}" ]]; then
    return "${__HHS_MSELECT_STUB_STATUS}"
  fi

  [[ -n "${selection}" ]]
}

setup() {
  __HHS_ORIG_PWD="$PWD"
  TEST_ROOT="$(mktemp -d)"
  export HHS_DIR="${TEST_ROOT}/hhs"
  export HOME="${TEST_ROOT}/home"
  mkdir -p "${HHS_DIR}" "${HOME}"
  export HHS_SAVED_DIRS_FILE="${HHS_DIR}/.saved_dirs"
  : >"${HHS_SAVED_DIRS_FILE}"
  export OLDIFS="${IFS}"
  WORK_DIR="${TEST_ROOT}/workspace"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  __HHS_MSELECT_STUB_RESPONSES=()
  __HHS_MSELECT_STUB_STATUS=""
}

teardown() {
  cd "${__HHS_ORIG_PWD}"
  rm -rf "${TEST_ROOT}"
  __HHS_MSELECT_STUB_RESPONSES=()
  __HHS_MSELECT_STUB_STATUS=""
}

@test "change_dir changes into provided directory" {
  mkdir -p "alpha"
  __hhs_change_dir "${WORK_DIR}/alpha"
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/alpha"
  assert_equal "${CURPWD}" "${WORK_DIR}/alpha"
  [[ -f "${HHS_DIR}/.last_dirs" ]] || fail "expected .last_dirs to be created"
}

@test "change_dir reports missing directories" {
  run __hhs_change_dir "${WORK_DIR}/missing"
  assert_failure
  assert_output --partial "Directory \"${WORK_DIR}/missing\" was not found !"
}

@test "changeback_ndirs navigates backwards multiple levels" {
  mkdir -p "one/two/three"
  __hhs_change_dir "${WORK_DIR}/one/two/three"
  local out_file
  out_file="$(mktemp)"
  __hhs_changeback_ndirs 2 >"${out_file}"
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/one"
  assert_equal "${OLDPWD}" "${WORK_DIR}/one/two/three"
  run cat "${out_file}"
  assert_output --partial "Changed directory backwards by 2 time(s)"
  rm -f "${out_file}"
}

@test "changeback_ndirs surfaces seq errors for invalid counts" {
  mkdir -p "base/nested"
  __hhs_change_dir "${WORK_DIR}/base/nested"
  local err_file out_file
  err_file="$(mktemp)"
  out_file="$(mktemp)"
  __hhs_changeback_ndirs invalid >"${out_file}" 2>"${err_file}"
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/base/nested"
  run cat "${err_file}"
  assert_output --partial "invalid floating point argument"
  rm -f "${out_file}" "${err_file}"
}

@test "godir cd into provided path directly" {
  mkdir -p "direct"
  __hhs_godir "${WORK_DIR}/direct"
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/direct"
}

@test "godir selects from multiple matches via mselect" {
  mkdir -p "search/a/target" "search/b/target"
  cd "${WORK_DIR}/search"
  __HHS_MSELECT_STUB_RESPONSES=("./b/target")
  __hhs_godir "${WORK_DIR}/search" target
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/search/b/target"
}

@test "godir reports when directory is missing" {
  mkdir -p "search"
  cd "${WORK_DIR}/search"
  run __hhs_godir "${WORK_DIR}/search" nomatch
  assert_failure
  assert_output --partial "No matches for directory with name \"nomatch\""
}

@test "mkcd creates dotted path and jumps into it" {
  __hhs_mkcd "foo.bar.baz"
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/foo/bar/baz"
  [[ -d "${WORK_DIR}/foo/bar/baz" ]] || fail "expected directory tree to exist"
}

@test "mkcd fails when path points to existing file" {
  touch "conflict"
  run __hhs_mkcd conflict
  assert_failure
  assert_output --partial "cannot create directory"
}

@test "dirs selects saved entries via mselect" {
  mkdir -p "first" "second"
  __hhs_change_dir "${WORK_DIR}/first"
  __hhs_change_dir "${WORK_DIR}/second"
  __HHS_MSELECT_STUB_RESPONSES=("${WORK_DIR}/first")
  __hhs_dirs
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/first"
}

@test "dirs returns failure when selection is cancelled" {
  mkdir -p "first" "second"
  __hhs_change_dir "${WORK_DIR}/first"
  __hhs_change_dir "${WORK_DIR}/second"
  __HHS_MSELECT_STUB_RESPONSES=()
  __HHS_MSELECT_STUB_STATUS=1
  run __hhs_dirs
  assert_failure
}

@test "save_dir persists absolute path entries" {
  mkdir -p "persist"
  run __hhs_save_dir "${WORK_DIR}/persist" workspace
  assert_success
  assert_output --partial "saved as WORKSPACE"
  run cat "${HHS_SAVED_DIRS_FILE}"
  assert_output --partial "WORKSPACE=${WORK_DIR}/persist"
}

@test "save_dir warns when directory is absent" {
  run __hhs_save_dir "${WORK_DIR}/missing" ghost
  assert_success
  assert_output --partial "Directory \"${WORK_DIR}/missing\" does not exist"
  [[ ! -s "${HHS_SAVED_DIRS_FILE}" ]] || fail "unexpected entry for missing directory"
}

@test "load_dir changes to saved alias" {
  mkdir -p "persist"
  printf 'WORK=${WORK_DIR}/persist\n' >"${HHS_SAVED_DIRS_FILE}"
  __hhs_load_dir WORK
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/persist"
}

@test "load_dir uses mselect when no alias is provided" {
  mkdir -p "persist" "other"
  printf 'WORK=${WORK_DIR}/persist\nOTHER=${WORK_DIR}/other\n' >"${HHS_SAVED_DIRS_FILE}"
  __HHS_MSELECT_STUB_RESPONSES=("  WORK=${WORK_DIR}/persist")
  __hhs_load_dir
  local exit_code=$?
  assert_equal "${exit_code}" 0
  assert_equal "$(pwd)" "${WORK_DIR}/persist"
}

@test "load_dir warns about missing saved path" {
  printf 'GHOST=${WORK_DIR}/ghost\n' >"${HHS_SAVED_DIRS_FILE}"
  run __hhs_load_dir GHOST
  assert_success
  assert_output --partial "Directory \"${WORK_DIR}/ghost\" does not exist"
}
