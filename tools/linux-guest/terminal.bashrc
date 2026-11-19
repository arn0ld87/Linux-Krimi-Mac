shopt -s histappend
export HISTSIZE=1000 HISTFILESIZE=2000
if (( EUID == 0 )); then
    # Leave the previous shell's full-screen buffer and start on a fresh line.
    printf '\033[?1049l\n'
    PS1='\[\e[1;33m\]\u@\h:\w#\[\e[0m\] '
else
    PS1='\[\e[32m\]\u@\h:\w$\[\e[0m\] '
    bildschirm() { printf '\033]633;StaffelDesktop\007'; }
fi

__staffel_prompt() {
    local status=$?
    history -a
    printf '\033]633;StaffelPrompt\007'
    return "$status"
}
PROMPT_COMMAND=__staffel_prompt
