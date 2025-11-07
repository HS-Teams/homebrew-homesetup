#!/usr/bin/env bats

load test_helper
load "${HHS_FUNCTIONS_DIR}/hhs-text.bash"
load_bats_libs

# Provide deterministic helpers for predictable test output
__hhs_highlight() {
  local pattern="$1"
  local file="${2:-/dev/stdin}"

  if [[ -z "${pattern}" ]]; then
    cat "${file}"
  else
    grep -Ei "${pattern}" "${file}"
  fi
}

__hhs_has() {
  local cmd="$1"

  if [[ $# -eq 0 || "$1" == "-h" ]]; then
    echo "usage: ${FUNCNAME[0]} <command>"
    return 1
  fi

  if [[ ",${HHS_MISSING_CMDS:-}," == *",${cmd},"* ]]; then
    return 1
  fi

  type "${cmd}" &>/dev/null
}

setup() {
  ORIGINAL_PATH="${PATH}"
  NETWORK_STUB_DIR="$(mktemp -d)"
  PATH="${NETWORK_STUB_DIR}:${PATH}"

  export NETWORK_STUB_DIR
  export HHS_MY_OS="Linux"
  export OLDIFS="${IFS}"
  export HHS_HIGHLIGHT_COLOR=""
  export YELLOW=""
  export NC=""
  unset HHS_MISSING_CMDS
}

teardown() {
  PATH="${ORIGINAL_PATH}"
  rm -rf "${NETWORK_STUB_DIR}"
  reset_network_functions
  unset STUB_CURL_FAIL
  unset HHS_MISSING_CMDS
}

reset_network_functions() {
  for fn in __hhs_active_ifaces __hhs_ip __hhs_ip_info __hhs_ip_lookup __hhs_ip_resolve __hhs_port_check; do
    if declare -F "${fn}" >/dev/null; then
      unset -f "${fn}"
    fi
  done
}

stub_ifconfig() {
  cat <<'SCRIPT' >"${NETWORK_STUB_DIR}/ifconfig"
#!/usr/bin/env bash

if [[ "$1" == "-a" ]]; then
  cat <<'OUT'
en0: flags=8863<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
tun0: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1500
OUT
  exit 0
fi

case "$1" in
  en0)
    cat <<'OUT'
en0: flags=8863<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    inet 192.168.1.42 netmask 0xffffff00 broadcast 192.168.1.255
OUT
    ;;
  lo0)
    cat <<'OUT'
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    inet 127.0.0.1 netmask 0xff000000
OUT
    ;;
  tun0)
    cat <<'OUT'
tun0: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1500
    inet 10.8.0.5 netmask 0xffffff00 destination 10.8.0.1
OUT
    ;;
  *)
    exit 1
    ;;
esac
SCRIPT
  chmod +x "${NETWORK_STUB_DIR}/ifconfig"
}

stub_route() {
  cat <<'SCRIPT' >"${NETWORK_STUB_DIR}/route"
#!/usr/bin/env bash

if [[ "$1" == "-n" ]]; then
  cat <<'OUT'
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.1.1     0.0.0.0         UG    0      0        0 en0
OUT
else
  printf 'usage: route -n\n' >&2
  exit 1
fi
SCRIPT
  chmod +x "${NETWORK_STUB_DIR}/route"
}

stub_curl() {
  cat <<'SCRIPT' >"${NETWORK_STUB_DIR}/curl"
#!/usr/bin/env bash

if [[ "${STUB_CURL_FAIL:-0}" -eq 1 ]]; then
  exit 22
fi

url="${@: -1}"

if [[ "${url}" == *"ipinfo.io"* ]]; then
  printf '{ "ip": "198.51.100.5" }\n'
elif [[ "${url}" == *"ip-api.com"* ]]; then
  printf '{ "query": "1.1.1.1", "country": "Australia", "city": "Sydney" }\n'
else
  exit 1
fi
SCRIPT
  chmod +x "${NETWORK_STUB_DIR}/curl"
}

stub_netstat() {
  cat <<'SCRIPT' >"${NETWORK_STUB_DIR}/netstat"
#!/usr/bin/env bash
cat <<'OUT'
Proto Recv-Q Send-Q Local Address          Foreign Address        State
udp        0      0 0.0.0.0:53             0.0.0.0:*
udp        0      0 127.0.0.1:9999         0.0.0.0:*
tcp        0      0 0.0.0.0:22             0.0.0.0:*              LISTEN
tcp        0      0 127.0.0.1:5432         0.0.0.0:*              ESTABLISHED
OUT
SCRIPT
  chmod +x "${NETWORK_STUB_DIR}/netstat"
}

stub_host() {
  cat <<'SCRIPT' >"${NETWORK_STUB_DIR}/host"
#!/usr/bin/env bash

if [[ "$#" -eq 0 ]]; then
  exit 1
fi

echo "$1 has address 93.184.216.34"
SCRIPT
  chmod +x "${NETWORK_STUB_DIR}/host"
}

stub_dig() {
  cat <<'SCRIPT' >"${NETWORK_STUB_DIR}/dig"
#!/usr/bin/env bash

if [[ "$1" == "+short" && "$2" == "-x" ]]; then
  echo "example.com"
else
  exit 1
fi
SCRIPT
  chmod +x "${NETWORK_STUB_DIR}/dig"
}

load_network() {
  reset_network_functions
  # shellcheck source=/dev/null
  source "${HHS_FUNCTIONS_DIR}/hhs-network.bash"
}

# TC - 1
@test "__hhs_active_ifaces displays a formatted interface list" {
  stub_ifconfig

  load_network

  run __hhs_active_ifaces

  assert_success
  assert_output --partial 'Listing all network interfaces'
  assert_output --partial 'en0'
  assert_output --partial 'lo0'
  assert_output --partial 'tun0'
}

# TC - 2
@test "__hhs_active_ifaces -flat returns space separated interface names" {
  stub_ifconfig

  load_network

  run __hhs_active_ifaces -flat

  assert_success
  assert_output --partial 'en0'
  assert_output --partial 'lo0'
  assert_output --partial 'tun0'
}

# TC - 3
@test "__hhs_ip reports gateway, local, and vpn addresses" {
  stub_ifconfig
  stub_route
  stub_curl

  load_network

  run __hhs_ip all

  assert_success
  assert_output --partial 'Gateway'
  assert_output --partial 'en0'
  assert_output --partial 'tun0'
}

# TC - 4
@test "__hhs_ip vpn restricts output to vpn interfaces" {
  stub_ifconfig
  stub_route
  stub_curl

  load_network

  run __hhs_ip vpn

  assert_success
  assert_output --partial 'tun0'
  run ! assert_output --partial 'en0'
}

# TC - 5
@test "__hhs_port_check filters results based on the provided criteria" {
  stub_netstat

  load_network

  run __hhs_port_check 22 LISTEN tcp

  assert_success
  assert_output --partial 'Proto Recv-Q Send-Q'
  assert_output --partial 'tcp        0      0 0.0.0.0:22'
  assert_output --partial 'LISTEN'
}

# TC - 6
@test "__hhs_ip_info pretty prints data when curl succeeds" {
  stub_curl

  load_network

  run __hhs_ip_info 1.1.1.1

  assert_success
  assert_output --partial '"query": "1.1.1.1"'
  assert_output --partial '"city": "Sydney"'
}

# TC - 7
@test "__hhs_ip_lookup forwards to host when available" {
  stub_ifconfig
  stub_host

  load_network

  run __hhs_ip_lookup example.com

  assert_success
  assert_output 'example.com has address 93.184.216.34'
}

# TC - 8
@test "__hhs_ip_lookup is not defined when host command is missing" {
  stub_ifconfig
  HHS_MISSING_CMDS="host"

  load_network

  run type __hhs_ip_lookup

  assert_failure
}

# TC - 9
@test "__hhs_ip_resolve forwards to dig when available" {
  stub_ifconfig
  stub_dig

  load_network

  run __hhs_ip_resolve 93.184.216.34

  assert_success
  assert_output 'example.com'
}

# TC - 10
@test "__hhs_ip_resolve is not defined when dig command is missing" {
  stub_ifconfig
  HHS_MISSING_CMDS="dig"

  load_network

  run type __hhs_ip_resolve

  assert_failure
}
