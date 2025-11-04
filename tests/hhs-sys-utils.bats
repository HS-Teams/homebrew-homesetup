#!/usr/bin/env bats

HHS_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HHS_HOME="${HHS_TEST_ROOT}"

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-sys-utils.bash"
load_bats_libs

# Mock helper functions used by the sys utils module.
__hhs_ip() {
  printf 'eth0:10.0.0.2\n'
  printf 'lo:127.0.0.1\n'
}

__hhs_docker_ps() {
  printf 'mock_container_one\n'
  printf 'mock_container_two\n'
}

__hhs_docker_count() {
  printf '2\n'
}

setup() {
  REPO_ROOT="${HHS_HOME}"
  export REPO_ROOT

  SYS_UTILS_TMPDIR="$(mktemp -d)"
  export SYS_UTILS_TMPDIR

  PATH_BACKUP="${PATH}"

  REAL_DF="$(command -v df)"
  REAL_PS="$(command -v ps)"
  REAL_ID="$(command -v id)"
  REAL_WHO="$(command -v who)"
  REAL_GREP="$(command -v grep)"
  REAL_UNAME="$(command -v uname)"
  export REAL_DF REAL_PS REAL_ID REAL_WHO REAL_GREP REAL_UNAME

  PATH="${SYS_UTILS_TMPDIR}:${PATH}"
  export PATH

  export HHS_MY_OS="Linux"
  export HHS_HIGHLIGHT_COLOR=""
  export ORANGE=""
  export GREEN=""
  export WHITE=""
  export YELLOW=""
  export RED=""
  export NC=""
  export CHECK_ICN="[ok]"
  export CROSS_ICN="[x]"
  export OLDIFS=$' \t\n'

  KILL_LOG="${SYS_UTILS_TMPDIR}/kills.log"
  export KILL_LOG

  SYS_UTILS_LICENSE_PATTERN=""
  export SYS_UTILS_LICENSE_PATTERN

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/whoami"
#!/usr/bin/env bash
printf 'testuser\n'
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/whoami"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/groups"
#!/usr/bin/env bash
printf 'testgroup testuser\n'
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/groups"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/id"
#!/usr/bin/env bash
if [[ "$1" == "-u" ]]; then
  printf '1000\n'
elif [[ "$1" == "-g" ]]; then
  printf '1000\n'
else
  exec "${REAL_ID}" "$@"
fi
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/id"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/uname"
#!/usr/bin/env bash
if [[ $# -eq 0 ]]; then
  printf '%s\n' "${HHS_MY_OS}"
elif [[ "$1" == "-pmr" ]]; then
  printf 'x86_64 mock-kernel 1.0\n'
else
  exec "${REAL_UNAME}" "$@"
fi
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/uname"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/uptime"
#!/usr/bin/env bash
printf '10:00 up 1 day, 2 users, load average: 0.10, 0.20, 0.30\n'
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/uptime"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/hostname"
#!/usr/bin/env bash
printf 'mock-host\n'
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/hostname"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/who"
#!/usr/bin/env bash
if [[ "$1" == "-H" ]]; then
  cat <<'USERS'
NAME     LINE         TIME
mockuser pts/0        Jan 01 10:00
USERS
else
  exec "${REAL_WHO}" "$@"
fi
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/who"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/df"
#!/usr/bin/env bash
if [[ "$1" == "-h" ]]; then
  cat <<'DFH'
Filesystem Size Used Avail Use% Mounted on
/dev/sda1 100G 55G 45G 55% /
tmpfs 2G 1G 1G 50% /run
DFH
elif [[ "$1" == "-H" ]]; then
  if [[ "${HHS_MY_OS}" == "Linux" ]]; then
    cat <<'DFLINUX'
Filesystem Size Used Avail Use% Mounted on
/dev/sda1 100G 40G 60G 40% /
/dev/sdb1 1T 200G 800G 20% /data
DFLINUX
  else
    cat <<'DFDARWIN'
Filesystem Size Used Avail Capacity iused ifree %iused Mounted on
/dev/disk1s1 500G 200G 300G 40% 1234 5678 12% /Volumes/MacintoshHD
DFDARWIN
  fi
else
  exec "${REAL_DF}" "$@"
fi
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/df"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/ps"
#!/usr/bin/env bash
if [[ "$1" == "-A" && "$2" == "-o" ]]; then
  case "$3" in
  %mem)
    cat <<'MEM'
%MEM
10.0
15.5
MEM
    ;;
  %cpu)
    cat <<'CPU'
%CPU
5.0
7.5
CPU
    ;;
  *)
    exec "${REAL_PS}" "$@"
    ;;
  esac
elif [[ "$1" == "-axco" ]]; then
  cat <<'PSLIST'
UID   PID  PPID COMMAND
1000  200  1    sample-proc
1000  201  200  sample-ghost
PSLIST
elif [[ "$1" == "-p" ]]; then
  if [[ "$2" == "200" ]]; then
    exit 0
  else
    exit 1
  fi
else
  exec "${REAL_PS}" "$@"
fi
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/ps"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/kill"
#!/usr/bin/env bash
if [[ "$1" == "-9" ]]; then
  pid="$2"
else
  pid="$1"
fi
printf '%s\n' "${pid}" >>"${KILL_LOG}"
if [[ "${pid}" == "200" ]]; then
  exit 0
else
  exit 1
fi
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/kill"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/docker"
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/docker"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/grep"
#!/usr/bin/env bash
if [[ -n "${SYS_UTILS_LICENSE_PATTERN}" && "$#" -ge 3 && "${!#}" == "/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf" ]]; then
  printf '%s\n' "${SYS_UTILS_LICENSE_PATTERN}"
  exit 0
fi
if [[ "$#" -ge 2 && "$1" == "-E" && "$2" == -* && "$2" != "-" ]]; then
  pattern="$2"
  shift 2
  exec "${REAL_GREP}" -E -- "${pattern}" "$@"
fi
exec "${REAL_GREP}" "$@"
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/grep"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/save-cursor-pos"
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/save-cursor-pos"

  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/restore-cursor-pos"
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/restore-cursor-pos"
}

teardown() {
  PATH="${PATH_BACKUP}"
  unset KILL_LOG
  unset SYS_UTILS_LICENSE_PATTERN
  rm -rf "${SYS_UTILS_TMPDIR}"
}

@test "sysinfo help flag prints usage" {
  run __hhs_sysinfo -h
  assert_failure
  assert_output --partial 'usage: __hhs_sysinfo'
}

@test "sysinfo prints mocked linux data" {
  run __hhs_sysinfo
  assert_success
  assert_output --partial 'Username..... : testuser'
  assert_output --partial 'Group........ : testgroup'
  assert_output --partial 'OS........... : Linux x86_64 mock-kernel 1.0'
  assert_output --partial 'Hostname..... : mock-host'
  assert_output --partial 'IP-eth0'
  assert_output --partial '10.0.0.2'
  assert_output --partial 'Currently Logged in Users:'
  assert_output --partial 'Disk'
  assert_output --partial 'mock_container_one'
}

@test "process list shows activity states" {
  run __hhs_process_list sample
  assert_success
  assert_output --partial 'sample-proc'
  assert_output --partial '[ok]  active process'
  assert_output --partial '[x]  ghost process'
}

@test "process list kill option uses mock kill command" {
  run __hhs_process_list -f -k sample
  assert_success
  assert_output --partial 'Killed "200"'
  assert_output --partial 'Skipped "201"'
  run cat "${KILL_LOG}"
  assert_output --partial '200'
  assert_output --partial '201'
}

@test "process list warns when no matches" {
  run __hhs_process_list missing
  assert_success
  assert_output --partial 'No active PIDs for process named: "missing"'
}

@test "process kill help prints usage" {
  run __hhs_process_kill -h
  assert_failure
  assert_output --partial 'usage: __hhs_process_kill'
}

@test "process kill executes with interactive confirmation" {
  export -f __hhs_process_list
  export -f __hhs_process_kill
  run bash -c 'printf yy | __hhs_process_kill sample'
  assert_success
  assert_output --partial 'Killed "200"'
  assert_output --partial 'Skipped "201"'
  run cat "${KILL_LOG}"
  assert_output --partial '200'
  assert_output --partial '201'
}

@test "partitions summarizes linux output" {
  run __hhs_partitions
  assert_success
  assert_output --partial 'Size'
  assert_output --partial '/data'
}

@test "partitions summarizes darwin output" {
  export HHS_MY_OS="Darwin"
  run __hhs_partitions
  assert_success
  assert_output --partial '/Volumes/MacintoshHD'
}

@test "os info reports linux metadata" {
  export HHS_MY_OS="Linux"
  run __hhs_os_info
  assert_success
  source /etc/os-release
  expected_name="${ID:-N/D}"
  expected_version="${VERSION:-${VERSION_ID:-N/D}}"
  expected_codename="${VERSION_CODENAME:-${PRETTY_NAME:-N/D}}"
  expected_home="${HOME_URL:-N/D}"
  assert_output --partial "Type: Linux"
  assert_output --partial "Name: ${expected_name}"
  assert_output --partial "Version: ${expected_version}"
  assert_output --partial "Codename: ${expected_codename}"
  assert_output --partial "Home URL: ${expected_home}"
}

@test "os info reports darwin metadata" {
  export HHS_MY_OS="Darwin"
  SYS_UTILS_LICENSE_PATTERN='SOFTWARE LICENSE AGREEMENT FOR macOS Redwood'
  export SYS_UTILS_LICENSE_PATTERN
  cat <<'SCRIPT' >"${SYS_UTILS_TMPDIR}/sw_vers"
#!/usr/bin/env bash
cat <<'SWVERS'
ProductName:    macOS
ProductVersion: 14.0
BuildVersion:   23A344
SWVERS
SCRIPT
  chmod +x "${SYS_UTILS_TMPDIR}/sw_vers"
  run __hhs_os_info
  assert_success
  assert_output --partial 'Type: Darwin'
  assert_output --partial 'Name: macOS'
  assert_output --partial 'Version: 14.0'
  assert_output --partial 'Codename: Redwood'
  assert_output --partial 'Home URL: https://www.apple.com/support'
}

@test "get codename falls back to linux release" {
  export HHS_MY_OS="Linux"
  source /etc/os-release
  run __hhs_get_codename
  if [[ -n "${VERSION_CODENAME:-}" ]]; then
    assert_output --partial "${VERSION_CODENAME}"
  else
    assert_output --partial "${PRETTY_NAME}"
  fi
}

@test "get codename parses darwin license" {
  export HHS_MY_OS="Darwin"
  SYS_UTILS_LICENSE_PATTERN='SOFTWARE LICENSE AGREEMENT FOR macOS Sequoia'
  export SYS_UTILS_LICENSE_PATTERN
  run __hhs_get_codename
  assert_success
  assert_output 'Sequoia'
}
