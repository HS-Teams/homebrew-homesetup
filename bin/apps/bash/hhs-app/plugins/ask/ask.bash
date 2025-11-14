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
  help version cleanup execute show_context clear_context show_models start_ollama select_ollama_model
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
      -h, --help                        show this help message and exit
      -v, --version                     show version and exit
      -c, --context                     show current ollama context (history) and exit
      -r, --reset                       reset history before executing (fresh new session) and exit
      -m, --models                      list available ollama models and exit
      -s, --select-model [model_name]   select the ollama model to use

    arguments:
      question         the question to ask Ollama
"

# Read context from ollama history file if not piped
[[ "${IS_PIPED}" -ne 1 && -s "${HHS_OLLAMA_HISTORY_FILE}" ]] && \
  CONTEXT="$(grep . "${HHS_OLLAMA_HISTORY_FILE}")"

# Read context from stdin if piped
[[ "${IS_PIPED}" -eq 1 ]] &&
  read -t 0 < /dev/stdin && CONTEXT="$(cat -)"

# Ollama-AI prompt
HHS_OLLAMA_PROMPT="### INSTRUCTIONS ###
You are an advanced AI assistant integrated into **HomeSetup** (acronym: hhs).
Your responsibilities include system setup, configuration, diagnostics, and management.

You execute inside a ${HHS_MY_SHELL} shell on **${HHS_MY_OS_RELEASE}**.
Always prefer macOS-specific commands, falling back to generic POSIX/Linux only when unavoidable.

### HomeSetup Information ###
- installation path: ${HHS_HOME}
- usage docs: ${HHS_HOME}/docs/USAGE.md
- handbook: ${HHS_HOME}/docs/handbook/handbook.md
- repository: ${HHS_GITHUB_URL}

### SYSTEM RULES ###

1. **The CONTEXT provided with every request is the primary and authoritative source of truth.**
2. You MUST ALWAYS read and analyze the CONTEXT fully before answering.
3. Derive the answer strictly from the CONTEXT when possible.
4. Only when the CONTEXT does not contain the required information, you may fall back to your internal knowledge.
5. NEVER contradict or ignore the CONTEXT.
6. Before answering, silently follow this reasoning flow:
   a) Read the entire CONTEXT.
   b) Extract all relevant data.
   c) Check if the question can be answered only from the CONTEXT.
   d) If YES → answer using ONLY the CONTEXT.
   e) If NO → answer briefly using internal knowledge.
7. When providing terminal commands:
   - keep them minimal
   - no unnecessary flags
   - add at most a one-line explanation
8. Keep all answers short, direct, and technically accurate.
9. Avoid any unnecessary explanations, filler, or narrative text.
10. Do NOT guess. If uncertain, respond exactly: **\"Sorry, but I don't know.\"**
11. Maintain a professional, neutral tone.
12. Personal or unrelated questions: answer briefly and without bias.

### TASK ###
Answer the user’s question accurately and as briefly as possible.
"

# Ollama model to use
ollama_model=$(__hhs_toml_get "${HHS_SETUP_FILE}" "hhs_ollama_model" "ollama")
ollama_model="${ollama_model#*=}"
ollama_model="${ollama_model//\"/}"
ollama_model="${ollama_model//\'/}"

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

# @purpose: Start ollama server, if not running, in background
function start_ollama() {
  if ! ollama ps &>/dev/null; then
    nohup ollama serve >"${HHS_LOG_DIR}/ollama.log" 2>&1 &
    pid=$!
    kill -0 "$pid" 2>/dev/null || return 2
  fi

  return 0
}

# @purpose: Show ollama history file contents (context)
function show_context() {
  if [[ -f "${HHS_OLLAMA_HISTORY_FILE}" ]]; then
    ${HHS_OLLAMA_MD_VIEWER} < "${HHS_OLLAMA_HISTORY_FILE}"
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
  echo -e "${BLUE}Available to download:"
  ${HHS_OLLAMA_MD_VIEWER} < "${HHS_HOME}/bin/apps/bash/hhs-app/plugins/ask/ollama-models.md"
  __hhs_has ollama && ollama ps &>/dev/null && {
    echo -e "${BLUE}Available locally:\n${WHITE}"
    IFS=$'\n'
    for m in $(ollama list | nl); do
      [[ "${m}" =~ .*${ollama_model}.* ]] && echo -e "${HHS_HIGHLIGHT_COLOR}${m}\t (current)${NC}" && continue
      echo -e "${m}"
    done
    IFS="$OLDIFS"
  }
  quit 0
}

# @purpose: Select ollama model to use
# shellcheck disable=SC2120
function select_ollama_model() {
  local model_name="${1}" title all_models model available
  declare -a all_models=() available=()

  if [[ -z "${model_name}" ]]; then
    # Available models
    while IFS= read -r line; do available+=( "$line" ); done < <(ollama list | tail -n +2 | awk '{print $1}')
    # All models
    while IFS= read -r model; do
      model_name=$(printf "%s" "$model" | cut -d':' -f1-2)
      [[ $model == *"${ollama_model}"* ]] && model="${GREEN}${model}${NC}"
      [[ " ${available[*]} " == *" ${model_name} "* ]] || model="${GRAY}${model}${NC}"
      all_models+=("${model}")
    done < <(grep . "$HHS_HOME/bin/apps/bash/hhs-app/plugins/ask/ollama-models.txt")
    title="${BLUE}Select the Ask Ollama model${NC}"
    mchoose_file=$(mktemp)
    if __hhs_mselect "${mchoose_file}" "${title}" "${all_models[@]}"; then
      model_name=$(cut -d':' -f1-2 <<< "$(grep . "${mchoose_file}")")
      model_name=$(printf '%s' "${model_name}" | sed 's/\x1b\[[0-9;]*m//g')
      if ! __hhs_toml_set "${HHS_SETUP_FILE}" "hhs_ollama_model=${model_name}" "ollama"; then
        quit 2 "Unable to change ollama model: \"${model}\""
      fi
    else
      quit 1
    fi
  fi

  if [[ -n "${model_name}" ]]; then
    if ! __hhs_toml_set "${HHS_SETUP_FILE}" "hhs_ollama_model=${model_name}" "ollama"; then
      quit 2 "Unable to set ollama model: ${model_name}!"
    fi
  fi

  echo -e "${GREEN}Ollama model set to '${model_name}'.${NC}"
  quit 0
}

# @purpose: HHS plugin required function
function execute() {
  local args ans query="Hello" resp ret_val kb_size=128 model
  declare -a args=()

  [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]] && usage 0
  [[ "$1" == "-v" || "$1" == "--version" ]] && version
  [[ "$1" == "-c" || "$1" == "--context" ]] && show_context
  [[ "$1" == "-r" || "$1" == "--reset" ]] && clear_context
  [[ "$1" == "-m" || "$1" == "--models" ]] && show_models
  [[ "$1" == "-s" || "$1" == "--select-model" ]] && shift && select_ollama_model "$@"

  [[ "${HHS_OLLAMA_AI_AUTOSTART}" -eq 1 ]] || quit 1 "Ollama-AI is not enabled. Enable it and try again (__hhs setup) !"

  if [[ "${HHS_OLLAMA_AI_AUTOSTART}" -ne 1 ]] || ! __hhs_has ollama; then
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

  for arg in "$@"; do [[ ! "$arg" =~ ^-[a-zA-Z] ]] && args+=("$arg"); done

  query="${args[*]}";

  HHS_OLLAMA_MAX_HIST_FILE_SIZE=$((kb_size * 1024))
  if [ -f "$HHS_OLLAMA_HISTORY_FILE" ]; then
    size=$(stat -c %s "$HHS_OLLAMA_HISTORY_FILE" 2>/dev/null || wc -c < "$HHS_OLLAMA_HISTORY_FILE")
    if [ "$size" -gt "$HHS_OLLAMA_MAX_HIST_FILE_SIZE" ]; then
      tail -c "${kb_size}K" "${HHS_OLLAMA_HISTORY_FILE}" > "${HHS_OLLAMA_HISTORY_FILE}.tmp"
      mv "${HHS_OLLAMA_HISTORY_FILE}.tmp" "${HHS_OLLAMA_HISTORY_FILE}"
    fi
  fi

  # Question & Answer
  start_ollama &> /dev/null
  resp="$(mktemp /tmp/hhs-ollama-response.XXXXXX)" || quit 1 "Failed to create temporary file."
  grep -q '^### Started:' "${HHS_OLLAMA_HISTORY_FILE}" || echo "### Started: $(date +%F)" >> "${HHS_OLLAMA_HISTORY_FILE}"
  echo -e "## [$(date '+%H:%M')] User: \n${query}" >> "${HHS_OLLAMA_HISTORY_FILE}"
  echo -e "✨ ${GREEN}${ollama_model}:\n${NC}"
  printf '%s### CONTEXT ###\n%s\n\n### USER INPUT ###\n\n%s\n' \
    "$HHS_OLLAMA_PROMPT" "$CONTEXT" "${query}" |
    ollama run "${ollama_model}" |
    tee -a "$resp"
  ret_val=${PIPESTATUS[1]}

  # Display the response
  if [[ -s "${resp}" ]]; then
    echo -e "## [$(date '+%H:%M')] AI: \n$(cat "${resp}")" >> "${HHS_OLLAMA_HISTORY_FILE}"
    printf '\033[H\033[2J\033[3J'
    echo -e "✨ ${GREEN}${ollama_model}:\t${GRAY}${resp}\n${NC}"
    ${HHS_OLLAMA_MD_VIEWER} < "${resp}"
  else
    echo -e "${ERROR_ICN} ${RED}Ollama failed to respond${NC}"
    ret_val=1
  fi

  # Cleanup
  [[ -f "${resp}" ]] && rm -f "${resp}" &> /dev/null

  quit "${ret_val}"
}
