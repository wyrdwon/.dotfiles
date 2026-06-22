#!/bin/zsh

# eza-backed ls
ls() { command eza -a --group-directories-first --icons "$@"; }

# Fastfetch widget
fastfetch-widget() {
  zle reset-prompt
  fastfetch --config examples/13
  print
  zle reset-prompt
}
zle -N fastfetch-widget
bindkey '^[f' fastfetch-widget

