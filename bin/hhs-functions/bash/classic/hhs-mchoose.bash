#!/usr/bin/env bash

#  Script: hhs-mchoose.bash
# Created: Jan 14, 2020
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: yorevs@hotmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>
# !NOTICE: Do not change this file. To customize your functions edit the file ~/.functions

# @function: Choose options from a list using a navigable menu.
# @param $1 [Req] : The response file.
# @param $2 [Req] : The render title.
# @param $3 [Req] : The array of items.
function __hhs_classic_mchoose() {

  local outfile title ret_val=1 all_options=() sel_options=() cur_index=0 show_from=0 re_render=1 selector
  local index_len len show_to diff_index typed_index columns option_line init_value=0 mark

  if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "usage: ${FUNCNAME[0]} <output_file> <title> <items...>"
    echo ''
    echo '    Options: '
    echo '      -c  : All options are initially checked instead of unchecked.'
    echo ''
    echo '    Arguments: '
    echo '      output_file : The output file where the result will be stored.'
    echo '            title : The text to be displayed before rendering the items.'
    echo '            items : The items to be displayed for selecting.'
    echo ''
    echo '    Examples: '
    echo '      Choose numbers from 1 to 20 (start with all options checked):'
    echo "        => ${FUNCNAME[0]} /tmp/out.txt {1..20} && cat /tmp/out.txt"
    echo '      Choose numbers from 1 to 20 (start with all options unchecked):'
    echo "        => ${FUNCNAME[0]} -c /tmp/out.txt {1..20} && cat /tmp/out.txt"
    echo ''
    echo '  Notes: '
    echo '    - A temporary file is suggested to used with this command: $ mktemp.'
    echo '    - The outfile must not exist or it be an empty file.'
    return 1
  fi

  [[ '-c' = "${1}" ]] && shift && init_value=1

  HHS_TUI_MAX_ROWS=${HHS_TUI_MAX_ROWS:=15}
  outfile="${1}" && shift
  title="${1}" && shift
  show_to="$((HHS_TUI_MAX_ROWS - 1))"
  diff_index="$((show_to - show_from))"
  all_options=("${@}")
  len=${#all_options[*]}

  # Initialize all options
  for idx in "${!all_options[@]}"; do
    sel_options[idx]=${init_value}
  done

  tput rmam
  echo -e "\033[2J"
  echo -e "\033[H${ORANGE}${title}${NC}\033[K"
  tput sc

  while :; do

    # Menu Renderization {
    if [[ -n "$re_render" ]]; then
      columns="$(($(tput cols) - 7))"
      tput civis
      # Restore the cursor to the home position
      tput rc
      echo -e "${NC}"
      for idx in $(seq "${show_from}" "${show_to}"); do
        selector=' '
        mark="${UNMARKED_ICN}"
        [[ ${idx} -ge ${len} ]] && break # When the number of items is lower than the max rows, skip the other lines
        option_line="${all_options[idx]:0:${columns}}"
        # Erase current line before repaint
        echo -ne "\033[2K\r"
        [[ ${idx} -eq ${cur_index} ]] && echo -en "${HHS_HIGHLIGHT_COLOR}" && selector="${POINTER_ICN}"
        [[ ${sel_options[${idx}]} -eq 1 ]] && mark="${MARKED_ICN}"
        printf "  %${#len}s  %0.2b %0.2b %s" "$((idx + 1))" "${selector}  " "${mark}" "${option_line}"
        # Check if the text fits the screen and print it, otherwise print '...'
        [[ ${#option_line} -ge ${columns} ]] && echo -e "\033[4D\033[K..."
        echo -e "${NC}"
      done
      echo ''
      echo -ne "${YELLOW}[Enter] Accept  [↑↓] Navigate  [Space] Mark  [I] Invert  [Q] Quit  [1..${len:0:5}] Goto: \033[0K"
      unset re_render
      tput cnorm
    fi
    # } Menu Renderization

    # Navigation input {
    IFS= read -rsn 1 keypress
    case "${keypress}" in
      [[:space:]]) # Mark option
        if [[ sel_options["${cur_index}"] -eq 0 ]]; then
          sel_options["${cur_index}"]=1
        else
          sel_options["${cur_index}"]=0
        fi
        re_render=1 && continue
        ;;
      'i' | 'I') # Invert selection
        for i in "${!sel_options[@]}"; do
          sel_options[i]=$((1 - sel_options[i]))
        done
        re_render=1 && continue
       ;;
      'q' | 'Q') # Exit requested
        echo -e "\n${NC}"
        ret_val=127
        break
        ;;
      [[:digit:]]) # An index was typed
        typed_index="${keypress}"
        echo -en "${keypress}" && index_len=1
        while [[ ${#typed_index} -lt ${#len} ]]; do
          IFS= read -rsn1 num_press
          [[ -z "${num_press}" ]] && break
          [[ ! "${num_press}" =~ ^[0-9]*$ ]] && unset typed_index && break
          typed_index="${typed_index}${num_press}"
          echo -en "${num_press}" && index_len=$((index_len + 1))
        done
        echo -ne "\033[${index_len}D\033[K"
        if [[ ${typed_index} -ge 1 ]] && [[ ${typed_index} -le ${len} ]]; then
          show_to=$((typed_index - 1))
          [[ "${show_to}" -le "${diff_index}" ]] && show_to=${diff_index}
          show_from=$((show_to - diff_index))
          cur_index=$((typed_index - 1)) && re_render=1
        fi
        ;;
      $'\033') # Handle escape '\e[nX' codes
        IFS= read -rsn2 -t 1 keypress
        case "${keypress}" in
          [A) # Cursor up
            if [[ ${cur_index} -eq ${show_from} ]] && [[ ${show_from} -gt 0 ]]; then
              show_from=$((show_from - 1))
              show_to=$((show_to - 1))
            elif [[ ${cur_index} -eq 0 ]]; then
              continue
            fi
            if [[ $((cur_index - 1)) -ge 0 ]]; then
              cur_index=$((cur_index - 1)) && re_render=1
            fi
            ;;
          [B) # Cursor down
            if [[ ${cur_index} -eq ${show_to} ]] && [[ $((show_to + 1)) -lt ${len} ]]; then
              show_from=$((show_from + 1))
              show_to=$((show_to + 1))
            elif [[ $((cur_index + 1)) -ge ${len} ]]; then
              continue
            fi
            if [[ $((cur_index + 1)) -lt ${len} ]]; then
              cur_index=$((cur_index + 1)) && re_render=1
            fi
            ;;
        esac
        ;;
      $'') # Keep the current index and exit
        ret_val=0
        echo ''
        break
        ;;
    esac
    # } Navigation input

  done

  [[ ${ret_val} -eq 0 ]] && echo "${sel_options[*]}" > "$outfile"

  return ${ret_val}
}
