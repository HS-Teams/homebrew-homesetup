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
  help version cleanup execute show_context clear_context show_models
)

# Usage message
USAGE="usage: ${APP_NAME} [options] <question>

    _        _
   / \\   ___| | __
  / _ \\ / __| |/ /
 / ___ \\__ \\   <
/_/   \\_\\___/_|\\_\\...Ollama-AI

  Offline ollama-AI agent integration for HomeSetup v${VERSION}.

    options:
      -h, --help        show this help message and exit
      -v, --version     show version and exit
      -c, --context     show current ollama context (history) and exit
      -r, --reset       reset history before executing (fresh new session) and exit
      -m, --models      list available ollama models and exit

    arguments:
      question         the question to ask Ollama
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
Prioritize platform-specific commands for ${HHS_MY_SHELL} and ${HHS_MY_OS_RELEASE}, then fall back to generic Linux kernel utilities.

### HomeSetup Information ###
- installed at: ${HHS_HOME}
- usage document: ${HHS_HOME}/docs/USAGE.md
- handbook document: ${HHS_HOME}/docs/handbook/handbook.md
- repository is: ${HHS_GITHUB_URL}

### SYSTEM RULES ###
1. ALWAYS read the provided CONTEXT before answering.
2. If the context does not contain relevant information, answer using your best knowledge, but be brief.
3. All answers MUST follow the system SHELL and OS declared above.
4. Understand the user’s intent precisely and answer only what is being asked.
5. Provide practical, actionable steps or commands when useful.
6. Keep the response short, clear, and technically correct.
7. Avoid unnecessary jargon or explanations.
8. For terminal commands:
   - give only what is required
   - add a one-line explanation only if needed
   - avoid long descriptions
9. When suggesting configurations or commands:
   - prioritize security, efficiency, and simplicity
10. If you are unsure about the answer, reply: 'Sorry, but I don't know.'
11. Do NOT invent information. No guesses.
12. Maintain a professional, neutral, and helpful tone.
13. Personal or unrelated questions: answer kindly, briefly, and without bias.

${CONTEXT}

### TASK ###
Answer the following question accurately and as briefly as possible.
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

# @purpose: Show ollama history file contents (context)
function show_context() {
  local viewer='cat'
  __hhs_has "${HHS_OLLAMA_MD_VIEWER}" && viewer="${HHS_OLLAMA_MD_VIEWER}"
  if [[ -f "${HHS_OLLAMA_HISTORY_FILE}" ]]; then
    $viewer "${HHS_OLLAMA_HISTORY_FILE}"
    quit 0
  fi

  quit 1 "${RED}Ollama history file not found${NC}"
}

# @purpose: Clear ollama history file (context)
function clear_context() {
  if [[ -s "${HHS_OLLAMA_HISTORY_FILE}" ]]; then
    : > "${HHS_OLLAMA_HISTORY_FILE}" || quit 2 "Unable to clear ollama history file"
    echo -e "${GREEN}Ollama history cleared${NC}"
    quit 0
  fi

  quit 1 "${RED}Ollama history file not found or empty${NC}"
}

# @purpose: Show available ollama models (local and for download)
function show_models() {
    local viewer='cat'
  __hhs_has "${HHS_OLLAMA_MD_VIEWER}" && viewer="${HHS_OLLAMA_MD_VIEWER}"
  echo -e "${BLUE}Available to download:"
  $viewer "${HHS_HOME}/bin/apps/bash/hhs-app/plugins/ask/ollama-models.md"
  __hhs_has ollama && {
    echo -e "${BLUE}Available locally:\n${WHITE}"
    IFS=$'\n'
    for m in $(ollama list | nl); do
      [[ "${m}" =~ .*${HHS_OLLAMA_MODEL}.* ]] && echo -e "${HHS_HIGHLIGHT_COLOR}${m}\t (current)${NC}" && continue
      echo -e "${m}"
    done
    IFS="$OLDIFS"
  }
  quit 0
}

# @purpose: HHS plugin required function
function execute() {
  local args ans query resp viewer='cat' ret_val mb_size=10

  declare -a args=()

  [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]] && usage 0
  [[ "$1" == "-v" || "$1" == "--version" ]] && version
  [[ "$1" == "-c" || "$1" == "--context" ]] && show_context
  [[ "$1" == "-r" || "$1" == "--reset" ]] && clear_context
  [[ "$1" == "-m" || "$1" == "--models" ]] && show_models

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

  # Max history file size
  HHS_OLLAMA_MAX_HIST_FILE_SIZE=$((mb_size * 1024 * 1024))
  # Use markdown viewer if available
  __hhs_has "${HHS_OLLAMA_MD_VIEWER}" && viewer="${HHS_OLLAMA_MD_VIEWER}"
  if [ -f "$HHS_OLLAMA_HISTORY_FILE" ]; then
    size=$(stat -c %s "$HHS_OLLAMA_HISTORY_FILE" 2>/dev/null || wc -c < "$HHS_OLLAMA_HISTORY_FILE")
    if [ "$size" -gt "$HHS_OLLAMA_MAX_HIST_FILE_SIZE" ]; then
      tail -c "${mb_size}M" "${HHS_OLLAMA_HISTORY_FILE}" > "${HHS_OLLAMA_HISTORY_FILE}.tmp"
      mv "${HHS_OLLAMA_HISTORY_FILE}.tmp" "${HHS_OLLAMA_HISTORY_FILE}"
    fi
  fi

  # Question & Answer
  resp="$(mktemp /tmp/hhs-ollama-response.XXXXXX)" || quit 1 "Failed to create temporary file."
  query="${args[*]}"
  grep -q '^### Started:' "${HHS_OLLAMA_HISTORY_FILE}" || echo "### Started: $(date +%F)" >> "${HHS_OLLAMA_HISTORY_FILE}"
  echo -e "## [$(date '+%H:%M')] User: \n${query}" >> "${HHS_OLLAMA_HISTORY_FILE}"
  echo -e "✨ ${GREEN}${HHS_OLLAMA_MODEL}:\n${NC}"
  printf '\n%s:\n### USER INPUT ###\n\n%s' \
    "${HHS_OLLAMA_PROMPT}" "${query}" \
    | ollama run "${HHS_OLLAMA_MODEL}" \
    | tee -a "${resp}"
  echo -e "## [$(date '+%H:%M')] AI: \n$(cat "${resp}")" >> "${HHS_OLLAMA_HISTORY_FILE}"
  ret_val=${PIPESTATUS[1]}
  printf '\033[H\033[2J\033[3J'
  echo -e "✨ ${GREEN}${HHS_OLLAMA_MODEL}:\n${NC}"
  $viewer "${resp}"

  #Cleanup
  [[ -f "${resp}" ]] && rm -f "${resp}" &> /dev/null
  [[ ${ret_val} -eq 0 ]] && quit 0

  quit 1 "Failed to execute Ask"
}
