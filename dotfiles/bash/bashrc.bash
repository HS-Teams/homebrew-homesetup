#!/usr/bin/env bash

#  Script: bashrc.bash
# Purpose: This is user specific file that gets loaded each time user creates a new non-login
#          shell. It simply loads the required HomeSetup dotfiles and set some required paths.
# Created: Aug 26, 2018
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

# !NOTICE: Do not change this file. To customize your shell create/change the following files:
#   ~/.colors     : To customize your colors
#   ~/.env        : To customize your environment variables
#   ~/.aliases    : To customize your aliases
#   ~/.aliasdef   : To customize your aliases definitions
#   ~/.prompt     : To customize your prompt
#   ~/.functions  : To customize your functions
#   ~/.profile    : To customize your profile
#   ~/.path       : To customize your paths

# If not running interactively or as a CI build, skip it.
[[ -z "${JOB_NAME}" && -z "${GITHUB_ACTIONS}" && -z "${PS1}" && -z "${PS2}" ]] && return

# Unset all HomeSetup variables
unset "${!HHS_@}" "${!__hhs@}"

export HHS_ACTIVE_DOTFILES='bashrc'

if [[ ${HHS_SET_DEBUG} -eq 1 ]]; then
  echo -e "\033[33mStarting HomeSetup in debug mode\033[m"
  PS4='+ $(date "+%s.%S")\011 '
  exec 3>&2 2>~/hhsrc.$$.log
  set -x
else
  echo -e "\033[1;34m[${SHELL##*\/}] HomeSetup is starting...\033[m"
fi

# Load the dotfiles according to the user's SHELL.
case "${SHELL##*\/}" in
  'bash')
    if [[ -s "${HOME}/.hhsrc" ]]; then
      source "${HOME}/.hhsrc"
    else
      echo -e "\033[31mHomeSetup was not loaded because it's resource file was not found:' ${HOME}/.hhsrc' \033[m"
    fi
    ;;
  *)
    echo ''
    echo "Sorry ! HomeSetup is not compatible with ${SHELL##*\/} for now."
    echo 'You can change your default shell by typing: '
    echo "$ sudo chsh -s $(command -v "${SHELL##*\/}")"
    echo ''
    ;;
esac

if [[ ${HHS_SET_DEBUG} -eq 1 ]]; then
  set +x
  exec 2>&3 3>&-
fi
