#!/usr/bin/env bash
# shellcheck disable=2034

#  Script: docker-build.bash
# Purpose: Validate and check information about a provided IP address.
# Created: Mar 20, 2018
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

# Current script version.
VERSION=2.0.0

# Application name.
APP_NAME="$(basename "$0")"

# Read folders containing images.
IFS=$'\n'
read -r -d '' -a images < <(find "${HHS_HOME}/docker" -mindepth 1 -type d -exec basename {} \;)
IFS="${OLDIFS}"

read -r -d '' USAGE <<EOF
usage: ${APP_NAME} <image_type...> [options]
    Build HomeSetup docker images with buildx (arm64 and amd64).

    options:
      -p | --push             : Push images after a successful build.
      -h | --help             : Display this help message.

    arguments:
      image_type              : One or more images to build from [${images[*]}].

    examples:
      Build specific images locally:
        => ${APP_NAME} base dev
      Build and push all images:
        => ${APP_NAME} --push ${images[*]}

    exit status:
      (0) Success
      (1) Failure due to missing/wrong client input or similar issues
      (2) Failure due to program execution failures

  Notes:
    - Images are tagged as yorevs/hhs-<image>-<arch>:latest using docker buildx.

EOF

declare -a platforms

# Common application functions
[[ -s "${HHS_DIR}/bin/app-commons.bash" ]] && source "${HHS_DIR}/bin/app-commons.bash"

# We need to load the dotfiles below due to non-interactive shell.
[[ -f "${HOME}"/.bash_commons ]] && source "${HOME}"/.bash_commons


if [[ $# -lt 1 || "${1}" == -h || "${1}" == --help ]]; then
  echo "${USAGE}"
  exit 1
else
  [[ "${1}" == "-p" || "${1}" == "--push" ]] && push_image=1 && shift
  for next_image in "${@}"; do
    # shellcheck disable=SC2199
    if [[ ${images[@]} =~ ${next_image} ]]; then
      image_dir="${HHS_HOME}/docker/${next_image}"
      [[ -d "${image_dir}/" ]] || { __hhs_errcho "${APP_NAME}" "Unable to find directory: ${image_dir}/"; exit 1; }
      # Docker build tag: ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
      echo ''
      echo -e "${PURPLE}Building ${BLUE}[${next_image}-arm64:latest] ... ${NC}"
      echo ''
      if ! docker buildx build --no-cache --progress=plain -t "yorevs/hhs-${next_image}-arm64:latest" \
           --platform linux/arm64/v8 "${image_dir}/"; then
            __hhs_errcho "${APP_NAME}" "Failed to build image: \"${next_image}\" !"
            exit 1
      fi
      echo ''
      echo -e "${PURPLE}Building ${BLUE}[${next_image}-amd64:latest] ... ${NC}"
      echo ''
      if ! docker buildx build --no-cache --progress=plain -t "yorevs/hhs-${next_image}-amd64:latest" \
           --platform linux/amd64 "${image_dir}/"; then
            __hhs_errcho "${APP_NAME}" "Failed to build image: \"${next_image}\" !"
            exit 1
      else
        echo "Finished building \"${next_image}\""
      fi
    else
      __hhs_errcho "${APP_NAME}" "Invalid container type: \"${next_image}\". Please use one of [${images[*]}] !"
      exit 1
    fi
  done
fi

exit 0
