#!/usr/bin/env bats

#  Script: hhs-toml.bats
# Purpose: hhs-toml tests.
# Created: Dec 05, 2023
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

load test_helper

export HHS_FUNCTIONS_DIR_REPO="${BATS_TEST_DIRNAME%/tests}/bin/hhs-functions/bash"

# shellcheck disable=1090
source "${HHS_FUNCTIONS_DIR_REPO}/hhs-text.bash"
# shellcheck disable=1090
source "${HHS_FUNCTIONS_DIR_REPO}/hhs-toml.bash"
load_bats_libs

test_file=

setup() {

  test_file=$(mktemp)

  cat <<'TOML' >"${test_file}"
# root comment
answer = 42
name = "Home Setup" # inline comment should be ignored

[tests]
list = ["one", "two", "three"]
flag = true

[my.group]
valid_key_two = "my valid value two"
valid_key_one = "my valid value one"
TOML
}

teardown() {
  [[ -f "${test_file}" ]] && \rm -f "${test_file}"
}

# TC - 1
@test "when invoking with help option then toml get should print usage" {
  run __hhs_toml_get -h
  assert_failure
  assert_output --partial "usage: __hhs_toml_get <file> <key> [group]"
}

# TC - 2
@test "when invoking with missing file then toml get should raise an error" {
  run __hhs_toml_get ''
  assert_failure
  assert_output --partial "The file parameter must be provided."
}

# TC - 3
@test "when invoking with missing key then toml get should raise an error" {
  run __hhs_toml_get "${test_file}" ''
  assert_failure
  assert_output --partial "The key parameter must be provided."
}

# TC - 4
@test "when invoking with invalid file then toml get should raise an error" {
  run __hhs_toml_get "non-existent.toml" "any_key"
  assert_failure
  assert_output --partial "The file \"non-existent.toml\" does not exists or is empty."
}

# TC - 5
@test "when invoking with incorrect key value pair then set should raise an error" {
  run __hhs_toml_set "${test_file}" "test.key.1" "tests"
  assert_failure
  assert_output --partial "The key/value parameter must be on the form of 'key=value', but it was 'test.key.1'."
}

# TC - 6
@test "when invoking without group then toml get should read from root" {
  run __hhs_toml_get "${test_file}" "name"
  assert_success
  assert_output 'name="Home Setup"'
}

# TC - 7
@test "when invoking with group then toml get should return the value" {
  run __hhs_toml_get "${test_file}" "valid_key_one" "my.group"
  assert_success
  assert_output 'valid_key_one="my valid value one"'
}

# TC - 8
@test "when invoking set with correct options then value should be updated" {
  run __hhs_toml_set "${test_file}" "flag=false" "tests"
  assert_success
  assert_output ""

  run __hhs_toml_get "${test_file}" "flag" "tests"
  assert_success
  assert_output "flag=false"
}

# TC - 9
@test "when setting new key without existing group then new table is created" {
  run __hhs_toml_set "${test_file}" "added=100" "new.group"
  assert_success
  assert_output ""

  run __hhs_toml_get "${test_file}" "added" "new.group"
  assert_success
  assert_output "added=100"
}

# TC - 10
@test "when enumerating groups then all tables should be listed" {
  run __hhs_toml_groups "${test_file}"
  assert_success
  assert_line --index 0 "tests"
  assert_line --index 1 "my.group"
}

# TC - 11
@test "when enumerating keys in group then all key assignments are listed" {
  run __hhs_toml_keys "${test_file}" "tests"
  assert_success
  assert_line --partial "list = [\"one\", \"two\", \"three\"]"
  assert_line --partial "flag = true"
}

# TC - 12
@test "when enumerating root keys then values outside groups are returned" {
  run __hhs_toml_keys "${test_file}"
  assert_success
  assert_line --partial "answer = 42"
  assert_line --partial "name = \"Home Setup\""
}
