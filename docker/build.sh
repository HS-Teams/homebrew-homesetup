#!/bin/bash

if [[ $# -ne 1 || "${1}" == -h || "${1}" == --help ]]; then
  echo 'Usage: build.bash <container_type>'
  echo ''
  echo '  Arguments'
  echo '    - container_type  : The OS to be installed. One of [ubuntu|centos]'
else
  if [[ "${1}" == "ubuntu" || "${1}" == "centos" ]]; then
    [[ -d "${1}/" ]] && docker build -t "yorevs/hhs-${1}" "${1}/"
    [[ -d "${1}/" ]] || echo -e "${RED}Unable to find directory: ${1}/${NC}"
  else
    echo "Invalid container type: \"${1}\". Please use one of [ubuntu|centos]"
  fi
fi
