#!/usr/bin/env bats

#  Script: hhs-profile-tools.bats
# Purpose: __hhs_activate_* profile helper tests.
# Created: Feb 16, 2025
#  Author: OpenAI Assistant
# License: Please refer to <https://opensource.org/licenses/MIT>

load test_helper
load_bats_libs

declare -Ag HHS_HAS_RESULTS=()
declare -Ag HHS_SOURCE_RESULTS=()
declare -ag HHS_SOURCE_CALLS=()
declare -ag HHS_OPEN_CALLS=()
declare -ag HHS_COLIMA_CALLS=()

reset_stub_state() {
  HHS_HAS_RESULTS=()
  HHS_SOURCE_RESULTS=()
  HHS_SOURCE_CALLS=()
  HHS_OPEN_CALLS=()
  HHS_COLIMA_CALLS=()
  HHS_OPEN_RETURN=0
  HHS_COLIMA_RETURN=0
  HHS_ERRCHO_RETURN_CODE=0
  HHS_ERRCHO_PRINT=1
}

__hhs_source() {
  local target="$1"
  HHS_SOURCE_CALLS+=("${target}")
  local rc=0
  if [[ -v HHS_SOURCE_RESULTS["${target}"] ]]; then
    rc="${HHS_SOURCE_RESULTS["${target}"]}"
  fi
  return "${rc}"
}

__hhs_errcho() {
  local origin="$1"
  shift
  local message="$*"
  if [[ "${HHS_ERRCHO_PRINT:-1}" -eq 1 ]]; then
    printf '%s %s\n' "${origin}" "${message}" 1>&2
  fi
  return "${HHS_ERRCHO_RETURN_CODE:-0}"
}

__hhs_has() {
  local cmd="$1"
  if [[ -z "${cmd}" ]]; then
    echo "usage: __hhs_has <command>"
    return 1
  fi
  if [[ -v HHS_HAS_RESULTS["${cmd}"] ]]; then
    return "${HHS_HAS_RESULTS["${cmd}"]}"
  fi
  return 1
}

open() {
  HHS_OPEN_CALLS+=("$*")
  return "${HHS_OPEN_RETURN:-0}"
}

colima() {
  local subcommand="$1"
  HHS_COLIMA_CALLS+=("$*")
  if [[ "${subcommand}" == "start" ]]; then
    return "${HHS_COLIMA_RETURN:-0}"
  fi
  return 0
}

load_profile_tools() {
  unset -f __hhs_activate_nvm 2>/dev/null || true
  unset -f __hhs_activate_rvm 2>/dev/null || true
  unset -f __hhs_activate_jenv 2>/dev/null || true
  unset -f __hhs_activate_docker 2>/dev/null || true
  # shellcheck source=/dev/null
  source "${HHS_FUNCTIONS_DIR}/hhs-profile-tools.bash"
}

setup() {
  reset_stub_state
  export GREEN=""
  export NC=""
  export HHS_HAS_DOCKER=""
  export AUTO_CPL_D="${BATS_TEST_TMPDIR}/auto-completions"
  mkdir -p "${AUTO_CPL_D}"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  ORIGINAL_PATH="${PATH}"
}

teardown() {
  PATH="${ORIGINAL_PATH}"
  rm -f /Applications/Docker.app
  unset -f jenv 2>/dev/null || true
}

@test "activates nvm when sourcing succeeds" {
  mkdir -p "${HOME}/.nvm"
  printf '#!/usr/bin/env bash\n' >"${HOME}/.nvm/nvm.sh"
  printf '#!/usr/bin/env bash\n' >"${HOME}/.nvm/bash_completion"
  HHS_SOURCE_RESULTS["${HOME}/.nvm/nvm.sh"]=0

  load_profile_tools

  run __hhs_activate_nvm

  assert_success
  assert_output --partial "Activating NVM app..."
  assert_output --partial "OK"
  [[ ":${PATH}:" == *":${HOME}/.nvm:"* ]]
  [[ "${#HHS_SOURCE_CALLS[@]}" -eq 1 ]]
  [[ "${HHS_SOURCE_CALLS[0]}" == "${HOME}/.nvm/nvm.sh" ]]
}

@test "fails to activate nvm when sourcing fails" {
  mkdir -p "${HOME}/.nvm"
  printf '#!/usr/bin/env bash\n' >"${HOME}/.nvm/nvm.sh"
  HHS_SOURCE_RESULTS["${HOME}/.nvm/nvm.sh"]=1

  load_profile_tools

  run __hhs_activate_nvm

  assert_failure
  assert_output --partial "Activating NVM app..."
  [[ "${error}" == *"FAILED => NVM could not be started"* ]]
}

@test "activates rvm when sourcing succeeds" {
  mkdir -p "${HOME}/.rvm/scripts"
  printf '#!/usr/bin/env bash\n' >"${HOME}/.rvm/scripts/rvm"
  HHS_SOURCE_RESULTS["${HOME}/.rvm/scripts/rvm"]=0

  load_profile_tools

  run __hhs_activate_rvm

  assert_success
  assert_output --partial "Activating RVM app..."
  assert_output --partial "OK"
  [[ ":${PATH}:" == *":${HOME}/.rvm/bin:"* ]]
  [[ "${HHS_SOURCE_CALLS[0]}" == "${HOME}/.rvm/scripts/rvm" ]]
}

@test "fails to activate rvm when sourcing fails" {
  mkdir -p "${HOME}/.rvm/scripts"
  printf '#!/usr/bin/env bash\n' >"${HOME}/.rvm/scripts/rvm"
  HHS_SOURCE_RESULTS["${HOME}/.rvm/scripts/rvm"]=1

  load_profile_tools

  run __hhs_activate_rvm

  assert_failure
  assert_output --partial "Activating RVM app..."
  [[ "${error}" == *"FAILED => RVM could not be started"* ]]
}

@test "activates jenv when init succeeds" {
  HHS_HAS_RESULTS[jenv]=0
  jenv() { printf 'export JENV_INITIALIZED=1\n'; }

  load_profile_tools

  run __hhs_activate_jenv

  assert_success
  assert_output --partial "Activating JENV app..."
  assert_output --partial "OK"
  [[ "${JENV_INITIALIZED}" == "1" ]]
}

@test "fails to activate jenv when init command fails" {
  HHS_HAS_RESULTS[jenv]=0
  jenv() { printf 'false\n'; }

  load_profile_tools

  run __hhs_activate_jenv

  assert_failure
  [[ "${error}" == *"FAILED => JENV could not be started"* ]]
}

@test "launches Docker desktop when application bundle exists" {
  mkdir -p /Applications
  printf '' > /Applications/Docker.app
  HHS_OPEN_RETURN=0

  load_profile_tools

  run __hhs_activate_docker

  assert_success
  assert_output --partial "Activating Docker..."
  assert_output --partial "OK"
  [[ "${#HHS_OPEN_CALLS[@]}" -eq 1 ]]
  [[ "${HHS_OPEN_CALLS[0]}" == "/Applications/Docker.app" ]]
}

@test "starts Colima when Docker app is absent" {
  HHS_HAS_RESULTS[colima]=0
  HHS_HAS_RESULTS[docker]=0
  HHS_COLIMA_RETURN=0

  load_profile_tools

  run __hhs_activate_docker

  assert_success
  assert_output --partial "Activating Colima..."
  assert_output --partial "OK"
  [[ "${#HHS_COLIMA_CALLS[@]}" -eq 1 ]]
  [[ "${HHS_COLIMA_CALLS[0]}" == "start" ]]
}

@test "fails to activate docker tools when no backend is available" {
  HHS_HAS_RESULTS[colima]=1
  HHS_HAS_RESULTS[docker]=1

  load_profile_tools

  run __hhs_activate_docker

  assert_failure
  [[ "${error}" == *"FAILED => Docker/Colima could not be started"* ]]
}
