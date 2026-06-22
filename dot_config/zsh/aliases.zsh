#!/bin/zsh

alias c=clear reload='exec $SHELL' cd=z
alias v=$EDITOR vim=$EDITOR lg=lazygit
alias ll='eza -al --icons' lt='eza -a --tree --level=1 --icons'
alias tar_extract='tar -xzf'
alias nf=fastfetch ff=fastfetch pf=fastfetch
alias shutdown='systemctl poweroff'
alias celar=clear py=python

alias sshback='ssh-add ~/.ssh/id_ed25519_backend_cadera'
alias sshfront='ssh-add ~/.ssh/id_ed25519_frontend_cadera'

alias qt='gping ping.archlinux.org'
alias ght='gh auth switch'

alias recite='eval $(poetry env activate)'
alias cm=chezmoi
alias batman=btop
alias sshserver='ssh-add -t 10800 ~/.ssh/id_ed25519'

# hot dotfile conf
alias hyprconf='chez_edit ~/.config/hypr/hyprland.lua'
alias shellconf='chez_edit ~/.zshrc'
alias termconf='chez_edit ~/.config/alacritty/alacritty.toml'
