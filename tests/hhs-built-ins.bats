#!/usr/bin/env bats

HHS_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HHS_HOME="${HHS_REPO_ROOT}"

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-text.bash"
load "${HHS_FUNCTIONS_DIR}/hhs-toml.bash"
load "${HHS_FUNCTIONS_DIR}/hhs-built-ins.bash"
load_bats_libs

DEFAULT_PATH="${PATH}"

__hhs_restart__() {
  printf '__hhs_restart__ invoked\n' >>"${HHS_TEST_LOG_DIR}/restart.log"
}

create_stub_scripts() {
  cat <<'STUB' >"${STUB_DIR}/open"
#!/usr/bin/env bash
printf 'open %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/open.log"
exit "${HHS_STUB_OPEN_EXIT:-0}"
STUB
  chmod +x "${STUB_DIR}/open"

  cat <<'STUB' >"${STUB_DIR}/xdg-open"
#!/usr/bin/env bash
printf 'xdg-open %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/open.log"
exit "${HHS_STUB_XDG_OPEN_EXIT:-0}"
STUB
  chmod +x "${STUB_DIR}/xdg-open"

  cat <<'STUB' >"${STUB_DIR}/stub-editor"
#!/usr/bin/env bash
printf 'stub-editor %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/edit.log"
exit "${HHS_STUB_EDITOR_EXIT:-0}"
STUB
  chmod +x "${STUB_DIR}/stub-editor"

  cat <<'STUB' >"${STUB_DIR}/gedit"
#!/usr/bin/env bash
printf 'gedit %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/edit.log"
exit "${HHS_STUB_GEDIT_EXIT:-1}"
STUB
  chmod +x "${STUB_DIR}/gedit"

  cat <<'STUB' >"${STUB_DIR}/emacs"
#!/usr/bin/env bash
printf 'emacs %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/edit.log"
exit "${HHS_STUB_EMACS_EXIT:-1}"
STUB
  chmod +x "${STUB_DIR}/emacs"

  cat <<'STUB' >"${STUB_DIR}/vim"
#!/usr/bin/env bash
printf 'vim %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/edit.log"
exit "${HHS_STUB_VIM_EXIT:-1}"
STUB
  chmod +x "${STUB_DIR}/vim"

  cat <<'STUB' >"${STUB_DIR}/vi"
#!/usr/bin/env bash
printf 'vi %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/edit.log"
exit "${HHS_STUB_VI_EXIT:-1}"
STUB
  chmod +x "${STUB_DIR}/vi"

  cat <<'STUB' >"${STUB_DIR}/cat"
#!/usr/bin/env bash
printf 'cat %s\n' "$@" >>"${HHS_TEST_LOG_DIR}/edit.log"
exit "${HHS_STUB_CAT_EXIT:-1}"
STUB
  chmod +x "${STUB_DIR}/cat"

  cat <<'STUB' >"${STUB_DIR}/tput"
#!/usr/bin/env bash
if [[ "$1" == 'cols' ]]; then
  printf '100\n'
else
  printf '0\n'
fi
STUB
  chmod +x "${STUB_DIR}/tput"

  cat <<'STUB' >"${STUB_DIR}/brew"
#!/usr/bin/env bash
if [[ "$1" == '--prefix' ]]; then
  printf '/mock/prefix/%s\n' "$2"
fi
exit 0
STUB
  chmod +x "${STUB_DIR}/brew"

  cat <<'STUB' >"${STUB_DIR}/python3"
#!/usr/bin/env bash
if [[ "$1" == '-V' ]]; then
  printf 'System Python 3.10.0\n'
else
  printf 'system python stub\n'
fi
STUB
  chmod +x "${STUB_DIR}/python3"

  mkdir -p "${HHS_VENV_PATH}/bin"
  cat <<'STUB' >"${HHS_VENV_PATH}/bin/activate"
#!/usr/bin/env bash
VIRTUAL_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VIRTUAL_ENV
_OLD_PATH="${PATH}"
export _OLD_PATH
PATH="${VIRTUAL_ENV}/bin:${PATH}"
export PATH
deactivate() {
  PATH="${_OLD_PATH}"
  unset _OLD_PATH
  unset VIRTUAL_ENV
}
STUB
  chmod +x "${HHS_VENV_PATH}/bin/activate"

  cat <<'STUB' >"${HHS_VENV_PATH}/bin/python3"
#!/usr/bin/env bash
if [[ "$1" == '-V' ]]; then
  printf 'Python 3.11.0\n'
else
  printf 'venv python stub\n'
fi
STUB
  chmod +x "${HHS_VENV_PATH}/bin/python3"

  cat <<'STUB' >"${STUB_DIR}/stubcmd"
#!/usr/bin/env bash
printf 'stubcmd executed\n' >>"${HHS_TEST_LOG_DIR}/about.log"
exit 0
STUB
  chmod +x "${STUB_DIR}/stubcmd"
}

setup() {
  TMP_ROOT="$(mktemp -d)"
  STUB_DIR="${TMP_ROOT}/bin"
  export STUB_DIR
  mkdir -p "${STUB_DIR}"
  export PATH="${STUB_DIR}:${DEFAULT_PATH}"

  export HHS_TEST_LOG_DIR="${TMP_ROOT}"
  : >"${HHS_TEST_LOG_DIR}/open.log"
  : >"${HHS_TEST_LOG_DIR}/edit.log"
  : >"${HHS_TEST_LOG_DIR}/restart.log"
  : >"${HHS_TEST_LOG_DIR}/about.log"

  export HHS_DIR="${TMP_ROOT}/hhs"
  export HHS_CACHE_DIR="${TMP_ROOT}/cache"
  export HHS_BACKUP_DIR="${TMP_ROOT}/backup"
  export HHS_LOG_DIR="${TMP_ROOT}/logs"
  export HHS_MOTD_DIR="${TMP_ROOT}/motd"
  export HHS_PROMPTS_DIR="${TMP_ROOT}/prompts"
  export HHS_VENV_PATH="${TMP_ROOT}/venv"
  export HHS_ENV_FILE="${TMP_ROOT}/hhs/.env"
  export HHS_SETUP_FILE="${TMP_ROOT}/hhs/.homesetup.toml"
  export HHS_ALIASDEF_FILE="${TMP_ROOT}/hhs/.aliasdef"
  export HHS_MY_OS='Linux'
  export HOME="${TMP_ROOT}/home"

  mkdir -p "${HHS_DIR}" "${HHS_CACHE_DIR}" "${HHS_BACKUP_DIR}" \
    "${HHS_LOG_DIR}" "${HHS_MOTD_DIR}" "${HHS_PROMPTS_DIR}" "${HOME}"

  cat <<'TOML' >"${HHS_SETUP_FILE}"
[setup]
hhs_python_venv_enabled = false
TOML

  cat <<'ALIAS' >"${HHS_ALIASDEF_FILE}"
__hhs_alias foo='echo foo'
__hhs_alias bar-tool='echo bar'
__hhs_alias baz='printf "baz value"'
ALIAS

  : >"${HHS_ENV_FILE}"

  create_stub_scripts
}

teardown() {
  PATH="${DEFAULT_PATH}"
  rm -rf "${TMP_ROOT}"
  unset -f sample_function 2>/dev/null || true
  unalias sample_alias 2>/dev/null || true
  unset HHS_STUB_OPEN_EXIT HHS_STUB_XDG_OPEN_EXIT HHS_STUB_EDITOR_EXIT \
    HHS_STUB_GEDIT_EXIT HHS_STUB_EMACS_EXIT HHS_STUB_VIM_EXIT \
    HHS_STUB_VI_EXIT HHS_STUB_CAT_EXIT
  unset EDITOR
}

@test "__hhs_random requires min and max arguments" {
  run __hhs_random
  assert_failure
  assert_output --partial 'usage: __hhs_random <min> <max>'
}

@test "__hhs_random returns values within the inclusive range" {
  for _ in $(seq 1 10); do
    value="$(__hhs_random 3 7)"
    [[ $? -eq 0 ]]
    [[ "${value}" =~ ^[0-9]+$ ]]
    (( value >= 3 && value <= 7 ))
  done
}

@test "__hhs_open uses the primary opener when available" {
  run __hhs_open '/tmp/example.txt'
  assert_success
  mapfile -t log <"${HHS_TEST_LOG_DIR}/open.log"
  [[ "${#log[@]}" -eq 1 ]]
  [[ "${log[0]}" == 'open /tmp/example.txt' ]]
}

@test "__hhs_open falls back to xdg-open when open fails" {
  export HHS_STUB_OPEN_EXIT=1
  run __hhs_open '/tmp/example.txt'
  assert_success
  mapfile -t log <"${HHS_TEST_LOG_DIR}/open.log"
  [[ "${log[0]}" == 'open /tmp/example.txt' ]]
  [[ "${log[1]}" == 'xdg-open /tmp/example.txt' ]]
}

@test "__hhs_open reports an error when no opener succeeds" {
  export HHS_STUB_OPEN_EXIT=1
  export HHS_STUB_XDG_OPEN_EXIT=1
  export HHS_STUB_VIM_EXIT=1
  export HHS_STUB_VI_EXIT=1
  run __hhs_open '/tmp/example.txt'
  assert_failure
  assert_output --partial "Unable to open \"/tmp/example.txt\". No suitable application found"
}

@test "__hhs_edit requires a file path argument" {
  run __hhs_edit
  assert_failure
  assert_output --partial 'usage: __hhs_edit <file_path>'
}

@test "__hhs_edit creates missing files and invokes configured editor" {
  export EDITOR='stub-editor'
  run __hhs_edit "${TMP_ROOT}/notes.txt"
  assert_success
  [[ -f "${TMP_ROOT}/notes.txt" ]]
  mapfile -t log <"${HHS_TEST_LOG_DIR}/edit.log"
  [[ "${log[0]}" == "stub-editor ${TMP_ROOT}/notes.txt" ]]
}

@test "__hhs_edit falls back to gedit when the configured editor is missing" {
  export EDITOR='missing-editor'
  export HHS_STUB_GEDIT_EXIT=0
  run __hhs_edit "${TMP_ROOT}/notes.txt"
  assert_success
  mapfile -t log <"${HHS_TEST_LOG_DIR}/edit.log"
  last_index=$(( ${#log[@]} - 1 ))
  [[ "${log[last_index]}" == "gedit ${TMP_ROOT}/notes.txt" ]]
}

@test "__hhs_edit reports a failure when no editor succeeds" {
  export EDITOR='missing-editor'
  export HHS_STUB_GEDIT_EXIT=1
  export HHS_STUB_EMACS_EXIT=1
  export HHS_STUB_VIM_EXIT=1
  export HHS_STUB_VI_EXIT=1
  export HHS_STUB_CAT_EXIT=1
  run __hhs_edit "${TMP_ROOT}/notes.txt"
  assert_failure
  assert_output --partial 'Unable to find a suitable editor for the file'
}

@test "__hhs_about reports alias expansions" {
  alias sample_alias='sample_function'
  sample_function() {
    echo 'sample body'
  }
  run __hhs_about sample_alias
  assert_success
  assert_output --partial 'Aliased:'
  assert_output --partial 'Function:'
  assert_output --partial 'sample_function'
  unset -f sample_function
  unalias sample_alias
}

@test "__hhs_about reports function definitions" {
  sample_function() {
    echo 'sample body'
  }
  run __hhs_about sample_function
  assert_success
  assert_output --partial 'Function:'
  assert_output --partial 'sample body'
  unset -f sample_function
}

@test "__hhs_about reports command metadata and brew prefix" {
  run __hhs_about stubcmd
  assert_success
  assert_output --partial 'Command:'
  assert_output --partial 'stubcmd'
  assert_output --partial '/mock/prefix/stubcmd'
}

@test "__hhs_defs lists all alias definitions" {
  run __hhs_defs
  assert_success
  assert_output --partial 'Listing all alias definitions matching'
  assert_output --partial 'foo'
  assert_output --partial 'bar-tool'
}

@test "__hhs_defs filters alias definitions by pattern" {
  run __hhs_defs foo
  assert_success
  assert_output --partial 'foo'
  refute_output --partial 'bar-tool'
}

@test "__hhs_defs -e opens the alias definition file for editing" {
  export EDITOR='stub-editor'
  run __hhs_defs -e
  assert_success
  mapfile -t log <"${HHS_TEST_LOG_DIR}/edit.log"
  [[ "${log[0]}" == "stub-editor ${HHS_ALIASDEF_FILE}" ]]
}

@test "__hhs_envs lists environment variables with default filter" {
  export HHS_APP_FOO='foo'
  export HHS_APP_BAR='bar'
  run __hhs_envs
  assert_success
  assert_output --partial 'HHS_APP_FOO'
  assert_output --partial 'HHS_APP_BAR'
}

@test "__hhs_envs filters environment variables" {
  export HHS_APP_FOO='foo'
  export HHS_APP_BAR='bar'
  run __hhs_envs FOO
  assert_success
  assert_output --partial 'HHS_APP_FOO'
  refute_output --partial 'HHS_APP_BAR'
}

@test "__hhs_envs -e opens the env file" {
  export EDITOR='stub-editor'
  run __hhs_envs -e
  assert_success
  mapfile -t log <"${HHS_TEST_LOG_DIR}/edit.log"
  [[ "${log[0]}" == "stub-editor ${HHS_ENV_FILE}" ]]
}

@test "__hhs_venv reports the current status when no option is given" {
  run __hhs_venv
  assert_success
  assert_output --partial 'Virtual environment is'
}

@test "__hhs_venv activates and deactivates the virtual environment" {
  run __hhs_venv --activate
  assert_success
  assert_output --partial 'activated'
  [[ "${HHS_PYTHON_VENV_ACTIVE}" -eq 1 ]]
  run __hhs_toml_get "${HHS_SETUP_FILE}" 'hhs_python_venv_enabled' 'setup'
  assert_output --partial 'hhs_python_venv_enabled=true'

  run __hhs_venv --deactivate
  assert_success
  assert_output --partial 'deactivated'
  [[ "${HHS_PYTHON_VENV_ACTIVE}" -eq 0 ]]
  run __hhs_toml_get "${HHS_SETUP_FILE}" 'hhs_python_venv_enabled' 'setup'
  assert_output --partial 'hhs_python_venv_enabled=false'
}

@test "__hhs_venv toggles between active and inactive states" {
  run __hhs_venv --toggle
  assert_success
  assert_output --partial 'activated'
  [[ "${HHS_PYTHON_VENV_ACTIVE}" -eq 1 ]]

  run __hhs_venv --toggle
  assert_success
  assert_output --partial 'deactivated'
  [[ "${HHS_PYTHON_VENV_ACTIVE}" -eq 0 ]]
}
