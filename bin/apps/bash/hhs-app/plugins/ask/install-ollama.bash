#!/usr/bin/env bash

#  Script: ask.bash
# Purpose: Offline ollama-AI agent installation for HomeSetup.
# Created: Nov 13, 2025
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs#homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2025, HomeSetup team

[[ -s "${HHS_DIR}/bin/app-commons.bash" ]] && source "${HHS_DIR}/bin/app-commons.bash"

# Install Ollama-AI
install_ollama() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    brew install ollama || return 2
    brew services start ollama || return 2
  else
    curl -fsSL https://ollama.com/install.sh | sh
    if systemctl enable ollama && systemctl start ollama; then
      return 0
    else
      nohup ollama serve >/var/log/ollama.log 2>&1 &
      pid=$!
      kill -0 "$pid" 2>/dev/null || return 2
    fi
  fi

  return 0
}

# Pull the HomeSetup model
pull_model() {
  ollama pull "${HHS_OLLAMA_MODEL}"

  return $?
}

# Main function: Install Ollama-AI and pull the selected HHS model
main() {
  if __hhs_has ollama; then
    echo -e "${GREEN}Ollama-AI is already installed.${NC}"
  elif install_ollama &>"${HHS_LOG_FILE} "; then
    if ollama list | grep -q "^${HHS_OLLAMA_MODEL}" || pull_model &>"${HHS_LOG_FILE}"; then
      __hhs_toml_set "${HHS_SETUP_FILE}" "hhs_use_offline_ai=true"
    fi
  else
    quit 2 "Failed to install Ollama-AI or pull the model."
  fi
}

main "$@"
quit 0
