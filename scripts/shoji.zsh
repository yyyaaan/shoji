# Shoji shell integration for zsh, sourced by the .zshenv Shoji puts in ZDOTDIR for its threads.
# Your own dotfiles load exactly as usual; this hooks in on the first prompt, after your .zshrc.
#
# - Reports the folder and each command to Shoji (iTerm2-style OSC 1337 sequences, never output scraping).
# - Gives `claude` Shoji's status hooks for this shell only (--settings; ~/.claude is untouched).
# - After a relaunch, resumes the thread's Claude session, or leaves its last command at the prompt.

typeset -gi _shoji_running=0

_shoji_report() {
  builtin print -rn -- $'\e]1337;ShojiEvent='"${1//[[:cntrl:]]/ }"$'\a'
}

_shoji_precmd() {
  local code=$?
  if (( _shoji_running )); then
    _shoji_running=0
    _shoji_report "done;$code"
  fi
  _shoji_report "cwd;$PWD"
}

_shoji_preexec() {
  _shoji_running=1
  _shoji_report "cmd;$1"
}

_shoji_autorun() {
  add-zle-hook-widget -d line-init _shoji_autorun
  BUFFER="claude --resume ${(q)SHOJI_RESUME_CLAUDE}"
  unset SHOJI_RESUME_CLAUDE
  zle accept-line
}

_shoji_init() {
  precmd_functions=(_shoji_precmd ${precmd_functions:#_shoji_init})
  preexec_functions=(_shoji_preexec $preexec_functions)
  if [[ -n ${SHOJI_CLAUDE_SETTINGS-} ]]; then
    claude() { command claude --settings "$SHOJI_CLAUDE_SETTINGS" "$@" }
  fi
  _shoji_precmd
  if [[ -n ${SHOJI_RESUME_CLAUDE-} ]]; then
    # Accepted like a typed line, so it lands in history and runs through preexec.
    autoload -Uz add-zle-hook-widget
    zle -N _shoji_autorun
    add-zle-hook-widget line-init _shoji_autorun
  elif [[ -n ${SHOJI_PREFILL-} ]]; then
    builtin print -z -- "$SHOJI_PREFILL"
  fi
  unset SHOJI_PREFILL
}

precmd_functions+=(_shoji_init)
