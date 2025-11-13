#!/usr/bin/env bash

#  Script: ask.bash
# Purpose: Offline ollama-AI agent integration for HomeSetup.
# Created: Nov 12, 2025
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs#homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

# Current script version.
VERSION="1.0.0"

# Current plugin name
PLUGIN_NAME="ask"

UNSETS=(
  help version cleanup execute
)

# Usage message
USAGE="usage: ${APP_NAME} <question>

    _        _
   / \\   ___| | __
  / _ \\ / __| |/ /
 / ___ \\__ \\   <
/_/   \\_\\___/_|\\_\\...Ollama-AI

  Offline ollama-AI agent integration for HomeSetup v${VERSION}.

    arguments:
      question    : the question to make to Ollama.
"

# Read context from ollama history file
[[ -s "${HHS_OLLAMA_HISTORY_FILE}" ]] && \
  CONTEXT="\n### CONTEXT ###\n$(grep . "${HHS_OLLAMA_HISTORY_FILE}")"

# Ollama-AI prompt
HHS_OLLAMA_PROMPT="### INSTRUCTIONS ###
Your task is to act as an advanced AI assistant integrated into **HomeSetup** (acronym 'hhs').
You are responsible for system setup, configuration, and management.
You MUST deliver concise, technically accurate, unbiased responses.
You are running in a ${HHS_MY_SHELL} shell on the following OS: ${HHS_MY_OS_RELEASE}.

### IMPORTANT ###
Always look the provided context before answering. If the context does not contain relevant information for the
response, answer based on your best knowledge but keep it brief.

### REQUIREMENTS ###
- All answers MUST match the system SHELL and OS specified above.
- Understand the user's intent precisely.
- Provide only relevant information.
- Suggest practical, actionable solutions and commands.
- Maintain clarity and avoid unnecessary jargon.
- Use a professional and helpful tone.
- Reflect current best practices in system configuration.
- Respond with the minimum necessary detail.
- For terminal commands: - explain briefly - provide only the command(s) needed - avoid lengthy explanations
- When suggesting configurations or commands, consider security, efficiency, and user-friendliness.
- If unsure about a solution, ask the user to search google, create a good google query for the user to copy and paste.
- Ensure that your answer is unbiased and does not rely on stereotypes.
- When the question is personal, or, unrelated to (HomeSetup, terminals, or system configuration), be kind, answering
using your best knowledge but keep it brief.

You must answer the following question as shortly and accurately as possible:
${CONTEXT}
"

[[ -s "${HHS_DIR}/bin/app-commons.bash" ]] && source "${HHS_DIR}/bin/app-commons.bash"

# @purpose: HHS plugin required function
function help() {
  usage 0
}

# @purpose: HHS plugin required function
function version() {
  echo "HomeSetup ${PLUGIN_NAME} plugin ${VERSION}"
  quit 0
}

# @purpose: HHS plugin required function
function cleanup() {
  unset -f "${UNSETS[@]}"
  echo -n ''
}

# @purpose: HHS plugin required function
function execute() {
  local args ans query resp viewer='cat' ret_val

  declare -a args=()

  [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]] && usage 0
  [[ "$1" == "-v" || "$1" == "--version" ]] && version

  if [[ "${HHS_USE_OFFLINE_AI}" -ne 1 ]] && ! __hhs_has ollama; then
    echo -en "${YELLOW}Offline Ollama-AI is not available. Install it [y]/n? ${NC}"
    read -r -n 1 ans
    echo
    if [[ "$ans" =~ ^[yY]$ || -z "$ans" ]]; then
      echo -en "${BLUE}Installing HomeSetup offline model... "
      if "${HHS_HOME}/bin/apps/bash/hhs-app/plugins/ask/install-ollama.bash"; then
        echo -e "${GREEN}OK${NC}\n"
        echo -e "${YELLOW}${TIP_ICON} Tip: Type \"__hhs ask execute 'what can you do for me?'\"${NC}\n"
        quit 0
      else
        echo -e "${RED}FAILED${NC}"
        quit 1 "Offline Ollama-AI failed to install."
      fi
    else
      quit 1 "Offline Ollama-AI is required to use this feature."
    fi
  fi

  [[ "${HHS_USE_OFFLINE_AI}" -eq 1 ]] || quit 1 "Ollama-AI is not enabled. Enable it and try again (__hhs setup) !"

  for arg in "$@"; do
    [[ ! "$arg" =~ ^-[a-zA-Z] ]] && args+=("$arg")
  done

  # Max history file size: 10MB
  HHS_OLLAMA_MAX_HIST_FILE_SIZE=$((10 * 1024 * 1024))

  if [[ -f "${HHS_OLLAMA_HISTORY_FILE}" ]] && (( $(stat -f%z "${HHS_OLLAMA_HISTORY_FILE}" 2>/dev/null) > HHS_OLLAMA_MAX_HIST_FILE_SIZE )); then
    tail -c 10M "${HHS_OLLAMA_HISTORY_FILE}" > "${HHS_OLLAMA_HISTORY_FILE}.tmp"
    mv "${HHS_OLLAMA_HISTORY_FILE}.tmp" "${HHS_OLLAMA_HISTORY_FILE}"
  fi

  resp="$(mktemp /tmp/hhs-ollama-response.XXXXXX)" || quit 1 "Failed to create temporary file."
  query="${args[*]}"
  grep -q '^### Started:' "${HHS_OLLAMA_HISTORY_FILE}" || echo "### Started: $(date +%F)" >> "${HHS_OLLAMA_HISTORY_FILE}"
  echo -e "## [$(date '+%H:%M')] User: \n${query}" >> "${HHS_OLLAMA_HISTORY_FILE}"
  echo -e "✨ ${GREEN}HomeSetup:"
  printf '\n%s:\n### USER INPUT ###\n\n%s' \
    "${HHS_OLLAMA_PROMPT}" "${query}" \
    | ollama run "${HHS_OLLAMA_MODEL}" \
    | tee -a "${resp}"
  echo -e "## [$(date '+%H:%M')] AI: \n$(cat "${resp}")" >> "${HHS_OLLAMA_HISTORY_FILE}"
  ret_val=${PIPESTATUS[1]}
  printf '\033[H\033[2J\033[3J'
  echo -e "✨ ${GREEN}HomeSetup:\n${NC}"

  __hhs_has "${HHS_OLLAMA_MD_VIEWER}" && viewer="${HHS_OLLAMA_MD_VIEWER}"
  $viewer "${resp}"

  [[ -f "${resp}" ]] && rm -f "${resp}" &> /dev/null
  [[ ${ret_val} -eq 0 ]] && quit 0

  quit 1 "Failed to execute Ask"
}
