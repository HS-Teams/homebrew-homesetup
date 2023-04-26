#!/usr/bin/env bash
# shellcheck disable=SC2155

#  Script: bash_env.bash
# Purpose: This file is used to configure shell environment variables
# Created: Aug 26, 2018
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: yorevs@hotmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
# !NOTICE: Do not change this file. To customize your environment variables edit the file ~/.env

export HHS_ACTIVE_DOTFILES="${HHS_ACTIVE_DOTFILES} bash_env"

# System locale (defaults)
export LANG=${LANG:-en_US.UTF-8}
export LANGUAGE=${LANGUAGE:-en_US:en}
export LC_ALL=${LANG}

# Save the original IFS
export RESET_IFS="$IFS"

# ----------------------------------------------------------------------------
# Home Sweet Homes

# Java
if __hhs_has java; then
  export JAVA_HOME=${JAVA_HOME:-$(dirname "$(command -v java)")}
  export JDK_HOME="${JDK_HOME:-$JAVA_HOME}"
fi

# Python
if __hhs_has  python3; then
  export PYTHON_HOME=${PYTHON_HOME:-$(dirname "$(command -v python3)")}
fi

# Qt
if __hhs_has qmake; then
  export QT_HOME=${QT_HOME:-$(dirname "$(command -v qmake)")}
fi

# MacOs
if [[ "Darwin" == "$(uname -s)" ]]; then
  # Hide the annoying warning about zsh
  export BASH_SILENCE_DEPRECATION_WARNING=1
  if command -v xcode-select &>/dev/null; then
    export XCODE_HOME=$(xcode-select -p)
    if [[ -d "${XCODE_HOME}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" ]]; then
      export MACOS_SDK="${XCODE_HOME}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    elif [[ -d "${XCODE_HOME}/SDKs/MacOSX" ]]; then
      export MACOS_SDK="${XCODE_HOME}/SDKs/MacOSX"
    fi
  fi
fi

# ----------------------------------------------------------------------------
# Commonly used folders
export TEMP="${TEMP:-$TMPDIR}"
export TRASH="${TRASH:-${HOME}/.Trash}"
export EDITOR="${EDITOR:-vi}"

# ----------------------------------------------------------------------------
# Bash History

# Setting history length ( HISTSIZE and HISTFILESIZE ) in bash
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTTIMEFORMAT="[${USER}, %F %T]  "

# History control ( ignore duplicates and spaces )
export HISTCONTROL=${HISTCONTROL:-"ignoreboth:erasedups"}
export HISTFILE="${HISTFILE:-${HOME}/.bash_history}"
export HISTIGNORE="pwd:?:-:l:q:rl:exit:gs:gl:.."

# ----------------------------------------------------------------------------
# HomeSetup variables

# Fixed

# Current OS and Terminal
export HHS_MY_OS="$(uname -s)"
export HHS_MY_SHELL="${SHELL//\/bin\//}"
export HHS_VERSION="$(head -1 "${HHS_HOME}"/.VERSION)"
export HHS_MOTD="$(eval "echo -e \"$(<"${HHS_HOME}"/.MOTD)\"")"

# Customizable
export HHS_ALIASES_FILE="${HHS_DIR}/.aliases"
export HHS_ENV_FILE="${HHS_DIR}/.env"
export HHS_SAVED_DIRS_FILE="${HHS_DIR}/.saved_dirs"
export HHS_CMD_FILE="${HHS_DIR}/.cmd_file"
export HHS_PATHS_FILE="${HHS_DIR}/.path"
export HHS_DEFAULT_EDITOR=${HHS_DEFAULT_EDITOR:-vi}
export HHS_MENU_MAXROWS=${HHS_MENU_MAXROWS:-15}
export HHS_PUNCH_FILE="${HHS_PUNCH_FILE:-${HHS_DIR}/.punches}"
export HHS_VAULT_FILE="${HHS_VAULT_FILE:-${HHS_DIR}/.vault}"
export HHS_VAULT_USER="${HHS_VAULT_USER:-${USER}}"
export HHS_FIREBASE_CONFIG_FILE="${HHS_FIREBASE_CONFIG_FILE:-${HHS_DIR}/firebase.properties}"
export HHS_FIREBASE_CREDS_FILE="$HOME/.ssh/{project_id}-firebase-credentials.json"
export HHS_DISABLE_COMPLETIONS=

__hhs_has git && export GIT_REPOS="${GIT_REPOS:-${HOME}/GIT-Repository}"
__hhs_has svn && export SVN_REPOS="${SVN_REPOS:-${HOME}/SVN-Repository}"

[[ -d "${HOME}/Workspace" ]] && export WORKSPACE="${WORKSPACE:-${HOME}/Workspace}"
[[ -d "${HOME}/Desktop" ]] && export DESKTOP="${DESKTOP:-${HOME}/Desktop}"
[[ -d "${HOME}/Downloads" ]] && export DOWNLOADS="${DOWNLOADS:-${HOME}/Downloads}"
[[ -d "${HOME}/Dropbox" ]] && export DROPBOX="${DROPBOX:-${HOME}/Dropbox}"

# Development tools. To override it please export HHS_DEV_TOOLS variable at <HHS_ENV_FILE>
DEVELOPER_TOOLS=(
  'hexdump' 'vim' 'bats' 'tree' 'perl' 'groovy'
  'pcregrep' 'shfmt' 'shellcheck' 'java' 'rvm' 'jq'
  'gcc' 'make' 'mvn' 'gradle' 'ruby'
  'docker' 'nvm' 'node' 'vue' 'eslint' 'pylint' 'gpg'
  'shasum' 'base64' 'git' 'go' 'python3' 'pip3'
)

if [[ "Darwin" == "${HHS_MY_OS}" ]]; then
  DEVELOPER_TOOLS+=('brew' 'xcode-select')
fi

export HHS_DEV_TOOLS=${HHS_DEV_TOOLS:-$(tr ' ' '\n' <<<"${DEVELOPER_TOOLS[@]}" | uniq | sort | tr '\n' ' ')}
