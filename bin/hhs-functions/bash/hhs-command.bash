#!/usr/bin/env bash

#  Script: hhs-command.bash
# Created: Oct 5, 2019
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: taius.hhs@gmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
#
# Copyright (c) 2024, HomeSetup team

# !NOTICE: Do not change this file. To customize your functions edit the file ~/.functions

# @function: Add/Remove/List/Execute saved bash commands.
# @param $1 [Opt] : The command index or alias.
# @param $2..$N [Con] : The command expression. This is required when alias is provided.
function __hhs_command() {

  HHS_CMD_FILE=${HHS_CMD_FILE:-$HHS_DIR/.cmd_file}

  local cmd_name cmd_alias cmd_expr pad pad_len mselect_file all_cmds=() index=1 sel_cmd ret_val=1
  local columns col_offset=26

  touch "${HHS_CMD_FILE}"

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "usage: ${FUNCNAME[0]} [options [cmd_alias] <cmd_expression>] | [cmd_index]"
    echo ''
    echo '    Options: '
    echo '      [cmd_index]   : Execute the command specified by the command index.'
    echo '      -e | --edit   : Edit the commands file.'
    echo '      -a | --add    : Store a command.'
    echo '      -r | --remove : Remove a command.'
    echo '      -l | --list   : List all stored commands.'
    echo ''
    echo '  Notes: '
    echo '    MSelect default : When no arguments is provided, a menu with options will be displayed.'
  else

    IFS=$'\n' read -d '' -r -a all_cmds <"${HHS_CMD_FILE}"
    IFS="${OLDIFS}"

    case "$1" in
    -e | --edit)
      __hhs_edit "${HHS_CMD_FILE}"
      ret_val=$?
      ;;
    -a | --add)
      shift
      cmd_name=$(echo -en "${1//[:space:]/_}" | tr '[:lower:]' '[:upper:]')
      shift
      cmd_expr="${*//\"/\\\"}"
      if [[ -z "${cmd_name}" || -z "${cmd_expr}" ]]; then
        __hhs_errcho "${FUNCNAME[0]}" "Invalid arguments: \"${cmd_name}\"\t\"${cmd_expr}\"${NC}"
      fi
      ised -e "s#(^Command ${cmd_name}: .*)##g" -e '/^\s*$/d' "${HHS_CMD_FILE}"
      all_cmds+=("Command ${cmd_name}: ${cmd_expr}")
      printf "%s\n" "${all_cmds[@]}" >"${HHS_CMD_FILE}"
      sort -u "${HHS_CMD_FILE}" -o "${HHS_CMD_FILE}"
      echo "${GREEN}Command stored: ${WHITE}\"${cmd_name}\" as ${HHS_HIGHLIGHT_COLOR}${cmd_expr} ${NC}"
      ret_val=0
      ;;
    -r | --remove)
      shift
      # Command ID can be the index or the alias
      cmd_alias=$(echo -en "$1" | tr -s '[:space:]' '_' | tr '[:lower:]' '[:upper:]')
      local re='^[1-9]+$'
      if [[ ${cmd_alias} =~ $re ]]; then
        cmd_expr=$(awk "NR==$1" "${HHS_CMD_FILE}" | awk -F ': ' '{ print $0 }')
        [[ -z "${cmd_expr}" ]] && __hhs_errcho "${FUNCNAME[0]}" "Command index not found: \"${cmd_alias}\"" && return 1
        ised -e "/^${cmd_expr}$/d" "${HHS_CMD_FILE}"
        echo "${YELLOW}Command ${WHITE}(${cmd_alias})${NC} removed !"
      elif [[ -n "${cmd_alias}" ]]; then
        cmd_expr=$(grep "${cmd_alias}" "${HHS_CMD_FILE}")
        [[ -z "${cmd_expr}" ]] && __hhs_errcho "${FUNCNAME[0]}" "Command not found: \"${cmd_alias}\"" && return 1
        ised -e "s#(^Command ${cmd_alias}: .*)*##g" -e '/^\s*$/d' "${HHS_CMD_FILE}"
        echo "${YELLOW}Command removed: ${WHITE}\"${cmd_alias}\" ${NC}"
        ret_val=0
      else
        __hhs_errcho "${FUNCNAME[0]}" "Invalid arguments: \"${cmd_alias}\"\t\"${cmd_expr}\""
      fi
      ;;
    -l | --list)
      if [[ ${#all_cmds[@]} -ne 0 ]]; then
        pad=$(printf '%0.1s' "."{1..60})
        pad_len=35
        columns="$(($(tput cols) - pad_len - col_offset))"
        echo ' '
        echo "${YELLOW}Available commands (${#all_cmds[@]}) stored:"
        echo ' '
        IFS=$'\n'
        for next in "${all_cmds[@]}"; do
          printf "${WHITE}(%03d) " $((index))
          cmd_name="$(echo -en "${next}" | awk -F ':' '{ print $1 }')"
          cmd_expr="$(echo -en "${next}" | awk -F ': ' '{ print $2 }')"
          echo -n "${HHS_HIGHLIGHT_COLOR}${cmd_name}${WHITE}"
          printf '%*.*s' 0 $((pad_len - ${#cmd_name})) "${pad}"
          echo -n "${GREEN} is stored as: ${WHITE}'${cmd_expr:0:${columns}}'"
          [[ ${#cmd_expr} -ge ${columns} ]] && echo -n "..."
          echo -e "${NC}"
          index=$((index + 1))
        done
        IFS="${OLDIFS}"
        echo -e "${NC}"
        ret_val=0
      else
        echo "${YELLOW}No commands were found in \"${HHS_CMD_FILE}\" !${NC}"
      fi
      ;;
    $'')
      if [[ ${#all_cmds[@]} -ne 0 ]]; then
        clear
        mselect_file=$(mktemp)
        if __hhs_mselect "${mselect_file}" "Available commands (${#all_cmds[@]}) stored:" "${all_cmds[@]}"; then
          sel_cmd=$(grep . "${mselect_file}")
          cmd_expr="${sel_cmd##*: }"
          [[ -n "${cmd_expr}" ]] && echo "#> ${cmd_expr}" && eval "${cmd_expr}" && ret_val=$?
          [[ -f "${mselect_file}" ]] && \rm -f "${mselect_file}"
        else
          [[ -f "${mselect_file}" ]] && \rm -f "${mselect_file}"
          return 1
        fi
      else
        echo "${YELLOW}No commands were found in \"${HHS_CMD_FILE}\" !${NC}"
      fi
      ;;
    [[:digit:]]*)
      cmd_expr="${all_cmds[$(($1 - 1))]##*: }"
      [[ -n "${cmd_expr}" ]] && echo -e "#> ${cmd_expr}" && eval "${cmd_expr}" && ret_val=$?
      [[ -z "${cmd_expr}" ]] && __hhs_errcho "${FUNCNAME[0]}" "Command indexed by \"$1\" was not found !"
      ;;
    [a-zA-Z0-9_]*)
      cmd_name=$(echo -en "$1" | tr -s '[:space:]' '_' | tr '[:lower:]' '[:upper:]')
      cmd_expr=$(grep "Command ${cmd_name}:" "${HHS_CMD_FILE}" | awk -F ': ' '{ print $2 }')
      [[ -n "${cmd_expr}" ]] && echo -e "#> ${cmd_expr}" && eval "${cmd_expr}" && ret_val=$?
      [[ -z "${cmd_expr}" ]] && __hhs_errcho "${FUNCNAME[0]}" "Command aliased by \"${cmd_name}\" was not found !"
      ;;
    *)
      __hhs_errcho "${FUNCNAME[0]}" "Invalid arguments: \"$1\"${NC}"
      ;;
    esac
    echo ''
  fi

  return ${ret_val}
}
