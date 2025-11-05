#!/usr/bin/env bats

#  Script: hhs-taylor.bats
# Purpose: hhs-taylor tests.
# Created: Feb 14, 2025
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-taylor.bash"
load_bats_libs

setup() {
  export GREEN='<INFO>'
  export WHITE='<DEBUG>'
  export YELLOW='<WARN>'
  export RED='<ERROR>'
  export PURPLE='<THREAD>'
  export CYAN='<FQDN>'
  export VIOLET='<DATE>'
  export BLUE='<URI>'
  export NC='<NC>'

  log_line="[worker-1] 2024-04-21T12:00:00 INFO connecting to host example.local http://example.local/path"
}

# TC - 1
@test "when-invoking-with-help-option-then-should-print-usage-message" {
  run __hhs_tailor -h
  assert_failure
  assert_output --partial "usage: __hhs_tailor [-F | -f | -r] [-q] [-b # | -c # | -n #] <file>"
}

# TC - 2
@test "when-streaming-from-stdin-then-should-highlight-log-patterns" {
  run __hhs_tailor <<<"${log_line}"
  assert_success
  assert_output --partial "<THREAD>worker-1<NC>"
  assert_output --partial "<DATE>2024-04-21T12:00:00<NC>"
  assert_output --partial "<INFO>INFO<NC>"
  assert_output --partial "<FQDN> example.local <NC>"
  assert_output --partial "<URI>http://example.local/path<NC>"
}

# TC - 3
@test "when-tailoring-a-file-with-options-then-should-forward-tail-arguments" {
  local log_file
  log_file="$(mktemp)"
  trap '[[ -f "${log_file}" ]] && rm -f "${log_file}"' RETURN

  {
    echo "ignored line"
    echo "${log_line}"
  } >"${log_file}"

  run __hhs_tailor -n 1 "${log_file}"
  assert_success
  assert_output --partial "<INFO>INFO<NC>"
  assert_equal "1" "$(wc -l <<<"${output}" | tr -d ' ')"
}

mock_sed_and_uname() {
  local mock_uname_value="${1}" stub_dir
  stub_dir="$(mktemp -d)"

  export SYSTEM_SED="$(command -v sed)"
  export SYSTEM_UNAME="$(command -v uname)"
  export MOCK_UNAME_S="${mock_uname_value}"
  export SED_FLAG_LOG="${stub_dir}/flag.log"

  cat <<'STUB' >"${stub_dir}/sed"
#!/usr/bin/env bash
printf "%s" "$1" >"${SED_FLAG_LOG}"
exec "${SYSTEM_SED}" "$@"
STUB
  chmod +x "${stub_dir}/sed"

  cat <<'STUB' >"${stub_dir}/uname"
#!/usr/bin/env bash
if [[ "$1" == "-s" ]]; then
  echo "${MOCK_UNAME_S}"
else
  exec "${SYSTEM_UNAME}" "$@"
fi
STUB
  chmod +x "${stub_dir}/uname"

  PATH="${stub_dir}:${PATH}"

  echo "${stub_dir}"
}

# TC - 4
@test "when-running-on-macos-then-should-use-extended-sed-flag" {
  skip "pending fix"
  local stub_dir
  stub_dir="$(mock_sed_and_uname "Darwin")"
  trap '[[ -d "${stub_dir}" ]] && rm -rf "${stub_dir}"' RETURN

  run __hhs_tailor <<<"${log_line}"
  assert_success
  assert_output --partial "<INFO>INFO<NC>"
  assert_equal "-E" "$(cat "${SED_FLAG_LOG}")"
}

# TC - 5
@test "when-running-on-linux-then-should-use-extended-regular-expression-flag" {
  skip "pending fix"
  local stub_dir
  stub_dir="$(mock_sed_and_uname "Linux")"
  trap '[[ -d "${stub_dir}" ]] && rm -rf "${stub_dir}"' RETURN

  run __hhs_tailor <<<"${log_line}"
  assert_success
  assert_output --partial "<INFO>INFO<NC>"
  assert_equal "-r" "$(cat "${SED_FLAG_LOG}")"
}
