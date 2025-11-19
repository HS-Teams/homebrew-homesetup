#!/usr/bin/env bash
# shellcheck disable=2181,2034

#  Script: services.bash
# Purpose: Contains all HHS service management functions
# Created: Nov 19, 2025
#  Author: Hugo Saporetti Junior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs#homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

# Current plugin name
PLUGIN_NAME="services"

UNSETS=(
  help version cleanup execute
)

# Current hhs services version
VERSION="1.0.0"

# Usage message
USAGE="usage: ${APP_NAME} ${PLUGIN_NAME} <operation> [service_name]
                     _
 ___  ___ _ ____   _(_) ___ ___  ___
/ __|/ _ \\ '__\\ \\ / / |/ __/ _ \\/ __|
\\__ \\  __/ |   \\ V /| | (_|  __/\\__ \\
|___/\\___|_|    \\_/ |_|\\___\\___||___\\/

  HomeSetup services v${VERSION}.

    operations:
      start     : Start a service.
      stop      : Stop a service.
      restart   : Restart a service.
      status    : Check the status of a service or all services.
"

[[ -s "${HHS_DIR}/bin/app-commons.bash" ]] && source "${HHS_DIR}/bin/app-commons.bash"

# @purpose: Print usage message
function help() {
  usage 0
}

# @purpose: Print plugin version
function version() {
  echo "HomeSetup ${PLUGIN_NAME} plugin v${VERSION}"
  quit 0
}

# @purpose: Clean up plugin functions
function cleanup() {
  unset -f "${UNSETS[@]}"
  echo -n ''
}

# @purpose: Detect the underlying OS (alpine, debian, fedora, centos, darwin)
function detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then
    os="darwin"
  elif [[ -f /etc/alpine-release ]]; then
    os="alpine"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID}" in
      ubuntu|debian) os="debian" ;;
      fedora)        os="fedora" ;;
      centos|rhel)   os="centos" ;;
    esac
  fi

  echo "${os}"
}

# @param $1 [Req]: operation (start, stop, restart, status)
# @param $2 [Req]: service name
# @purpose: Run a service command based on OS and method
function manage_service() {
  local action="${1}" service="${2}" os

  os="$(detect_os)"

  case "${os}" in
    darwin) brew services "${action}" "${service}" ;;
    alpine) rc-service "${service}" "${action}" ;;
    debian|fedora|centos) systemctl "${action}" "${service}" ;;
    *) quit 1 "Unsupported OS: ${os}" ;;
  esac
}

# @param $1 [Opt]: service filter (case-insensitive)
# @purpose: List all services with standardized dot-padded and colorized status
function list_services_status() {
  local filter="${1:-}"
  local os service status longest=0 line
  local service_name_padded=""
  local -a raw_services=()

  os="$(detect_os)"

  # Populate raw_services array
  case "${os}" in
    darwin)
      while IFS= read -r line; do
        raw_services+=("${line}")
      done < <(brew services list | awk 'NR>1 { print $1 ":" $2 }')
      ;;
    alpine)
      while IFS= read -r line; do
        raw_services+=("${line}")
      done < <(rc-status -a | awk '{ print $1 ":" $2 }')
      ;;
    debian|fedora|centos)
      while IFS= read -r line; do
        raw_services+=("${line}")
      done < <(systemctl list-units --type=service --all --no-pager | awk '
        NR>1 && $1 ~ /\.service$/ {
          name=$1;
          sub(/\.service$/, "", name);
          state=$4;
          print name ":" state;
        }')
      ;;
    *)
      quit 2 "Unsupported OS: ${os}"
      ;;
  esac

  # First pass: find longest service name
  for line in "${raw_services[@]}"; do
    service="${line%%:*}"
    [[ -n "${filter}" && ! "${service,,}" =~ ${filter,,} ]] && continue
    [[ ${#service} -gt ${longest} ]] && longest=${#service}
  done

  # Print header (unpadded)
  printf "%b\n" "${WHITE}Service$(printf '%*s' $((longest + 3 - 7)) '') Status${NC}"

  # Second pass: print results with proper dot padding
  for line in "${raw_services[@]}"; do
    service="${line%%:*}"
    status="${line##*:}"

    [[ -n "${filter}" && ! "${service,,}" =~ ${filter,,} ]] && continue

    service_name_padded="${service}"
    while [[ ${#service_name_padded} -lt $((longest + 3)) ]]; do
      service_name_padded+="."
    done

    if [[ "${status}" =~ ^(started|running|enabled|active)$ ]]; then
      printf "%b %b\n" "${YELLOW}${service_name_padded}${NC}" "${GREEN} up${NC}"
    else
      printf "%b %b\n" "${YELLOW}${service_name_padded}${NC}" "${RED} down${NC}"
    fi
  done
}

# @purpose: HHS plugin required function to route service commands
function execute() {
  local operation="${1:-status}" service="${2:-}" os

  os="$(detect_os)"

  case "${operation}" in
    help)
      help ;;
    version)
      version ;;
    start|stop|restart)
      [[ -z "${service}" ]] && quit 1 "Missing service name."
      manage_service "${operation}" "${service}" || quit 1
      ;;
    status)
      list_services_status "${service}"
      ;;
    *)
      quit 2 "Unknown operation: ${operation}" ;;
  esac
}
