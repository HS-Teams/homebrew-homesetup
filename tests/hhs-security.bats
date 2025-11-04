#!/usr/bin/env bats

load test_helper
load_bats_libs

quit() {
  local exit_code="$1"
  shift
  if [[ $# -gt 0 ]]; then
    printf "%s\n" "$@"
  fi
  return "${exit_code}"
}

__hhs_clipboard() {
  cat >"${HHS_CLIPBOARD_CAPTURE}"
}

setup_file() {
  export PATH="${BATS_TEST_DIRNAME}/stubs:${PATH}"
  export HHS_CLIPBOARD_CAPTURE="${BATS_TEST_TMPDIR}/clipboard"
  : >"${HHS_CLIPBOARD_CAPTURE}"
  source "${HHS_FUNCTIONS_DIR}/hhs-security.bash"
}

setup() {
  : >"${HHS_CLIPBOARD_CAPTURE}"
  unset HHS_GPG_FAIL_MODE HHS_ENCODE_FAIL HHS_DECODE_FAIL HHS_SHA_SUM
}

@test "encrypt-file succeeds and removes temporary artifacts" {
  local file="${BATS_TEST_TMPDIR}/secret.txt"
  echo "classified" >"${file}"

  run __hhs_encrypt_file "${file}" "passphrase"

  assert_success
  assert_output --partial "File \"${file}\" has been encrypted !"
  [[ ! -f "${file}.gpg" ]]
}

@test "encrypt-file with --keep preserves gpg artifact" {
  local file="${BATS_TEST_TMPDIR}/secret-keep.txt"
  echo "classified" >"${file}"

  run __hhs_encrypt_file "${file}" "passphrase" --keep

  assert_success
  [[ -f "${file}.gpg" ]]
}

@test "encrypt-file reports failure when gpg fails" {
  local file="${BATS_TEST_TMPDIR}/secret-fail.txt"
  echo "classified" >"${file}"
  export HHS_GPG_FAIL_MODE="encrypt"

  run __hhs_encrypt_file "${file}" "passphrase"

  assert_failure
  assert_output --partial "Unable to encrypt file"
  [[ ! -f "${file}.gpg" ]]
}

@test "decrypt-file succeeds and removes temporary artifacts" {
  local file="${BATS_TEST_TMPDIR}/vault.txt"
  echo "encoded" >"${file}"

  run __hhs_decrypt_file "${file}" "passphrase"

  assert_success
  assert_output --partial "File \"${file}\" has been decrypted !"
  [[ ! -f "${file}.gpg" ]]
}

@test "decrypt-file accepts --keep flag" {
  local file="${BATS_TEST_TMPDIR}/vault-keep.txt"
  echo "encoded" >"${file}"

  run __hhs_decrypt_file "${file}" "passphrase" --keep

  assert_success
  # Keep flag should prevent cleanup of the intermediate artifact once implemented.
}

@test "decrypt-file reports failure when decode fails" {
  local file="${BATS_TEST_TMPDIR}/vault-fail.txt"
  echo "encoded" >"${file}"
  export HHS_DECODE_FAIL="1"

  run __hhs_decrypt_file "${file}" "passphrase"

  assert_failure
  assert_output --partial "Unable to decrypt file"
}

@test "pwgen prints usage when help flag is provided" {
  run __hhs_pwgen --help

  assert_success
  assert_output --partial "usage: __hhs_pwgen"
}

@test "pwgen validates numeric password length" {
  run __hhs_pwgen --length invalid --type 1

  assert_failure
  assert_output --partial "Password length must be a positive integer"
}

@test "pwgen validates password type range" {
  run __hhs_pwgen --length 8 --type 9

  assert_failure
  assert_output --partial "Password type must be between [1..4]"
}

@test "pwgen generates letters-only password for type 1" {
  export HHS_SHA_SUM="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

  run __hhs_pwgen --length 10 --type 1

  assert_success
  assert_output --partial "Password copied to the clipboard"
  assert_equal "bsJarIZqHY" "$(cat "${HHS_CLIPBOARD_CAPTURE}")"
}

@test "pwgen generates numbers-only password for type 2" {
  export HHS_SHA_SUM="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

  run __hhs_pwgen --length 10 --type 2

  assert_success
  assert_equal "1852963074" "$(cat "${HHS_CLIPBOARD_CAPTURE}")"
}

@test "pwgen generates alphanumeric password for type 3" {
  export HHS_SHA_SUM="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

  run __hhs_pwgen --length 10 --type 3

  assert_success
  assert_equal "bsJ0hyP6nE" "$(cat "${HHS_CLIPBOARD_CAPTURE}")"
}

@test "pwgen generates strong password with symbols for type 4" {
  export HHS_SHA_SUM="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

  run __hhs_pwgen --length 10 --type 4

  assert_success
  assert_equal "+VhnP>Jtb@" "$(cat "${HHS_CLIPBOARD_CAPTURE}")"
}
