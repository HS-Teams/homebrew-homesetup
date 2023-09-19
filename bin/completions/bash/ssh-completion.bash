#  Script: ssh-completion.bash
# Purpose: Bash completion for ssh
# Created: Apr 28, 2020
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: homesetup@gmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <https://opensource.org/licenses/MIT>

__ssh_complete() {
  
  local suggestions=()
  
  [ "${#COMP_WORDS[@]}" != "2" ] && return 0
  
  suggestions=($(compgen -W "$(grep '^Host .*' ~/.ssh/config | cut -d ' ' -f2-)" -- "${COMP_WORDS[1]}"))
  COMPREPLY=("${suggestions[@]}")
  
  return 0
}

complete -o default -F __ssh_complete ssh
