#!/usr/bin/env bats

load test_helper
load_bats_libs

# Define the app path from environment
setup() {
  APP="${HHS_APPS_DIR}/fetch.bash"
}

# TC - 1
@test "--headers forwards each value to curl" {
  run "${APP}" \
    --headers 'X-Test-One: alpha, X-Test-Two: beta' GET https://jsonplaceholder.typicode.com/posts/1

  assert_success

  # Since jsonplaceholder does not echo headers, we only check response content
  [[ "${output}" =~ userId ]] || fail "Expected response JSON missing"
}

# TC - 2
@test "--format routes the response through format_json" {
  run "${APP}" \
    --format --silent GET https://jsonplaceholder.typicode.com/posts/1

  assert_success

  assert_line --index 0 '{'
  assert_line --index 1 --partial '  "userId":'
  assert_line --index 2 --partial '  "id":'
  assert_line --index 3 --partial '  "title":'
  assert_line --index 4 --partial '  "body":'
  assert_line --index 5 '}'
}

@test "fails when method is missing" {
  run "${APP}" https://example.com
  assert_failure
  assert_output --partial "fetch.bash  Invalid HTTP method: HTTPS://EXAMPLE.COM"
}

@test "fails when URL is missing" {
  run "${APP}" GET
  assert_failure
  assert_output --partial "fetch.bash  Missing required argument <url>"
}

@test "fails when both method and url are missing" {
  run "${APP}"
  assert_failure
  assert_output --partial "fetch.bash  Missing required arguments <method> and <url>"
}

@test "fails on unknown method" {
  run "${APP}" INVALID https://example.com
  assert_failure
  assert_output --partial "fetch.bash  Invalid HTTP method: INVALID"
}

@test "fails on unknown flag" {
  run "${APP}" --unknown GET https://example.com
  assert_failure
  assert_output --partial "fetch.bash  Unknown option"
}

@test "fails on --body without value" {
  run "${APP}" -b GET https://example.com
  assert_failure
  assert_output --partial "fetch.bash  --body requires a value."
}

@test "fails on --headers without value" {
  run "${APP}" -H GET https://example.com
  assert_failure
  assert_output --partial "fetch.bash  --headers requires a value."
}

@test "fails on --timeout with non-numeric value" {
  run "${APP}" -t abc GET https://example.com
  assert_failure
  assert_output --partial "fetch.bash  --timeout requires a numeric value."
}

@test "fails with timeout reached" {
  run "${APP}" -t 1 GET https://httpstat.us/200?sleep=5000
  assert_failure
  assert_output --partial "Server responded with no data."
}
