#!/bin/zsh

# =========================================================
# Clipboard — resolve once, use everywhere
# Precedence: WSL → Wayland → X11 (xclip) → X11 (xsel) → macOS
# =========================================================
_clipboard_copy() {
  if command -v clip.exe &>/dev/null; then
    clip.exe
  elif command -v wl-copy &>/dev/null; then
    wl-copy
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard
  elif command -v xsel &>/dev/null; then
    xsel --clipboard --input
  elif command -v pbcopy &>/dev/null; then
    pbcopy
  else
    echo "No clipboard utility found." >&2
    return 1
  fi
}

# Copy a file's contents to clipboard
copyfile() {
  [[ $# -eq 1 && -f $1 ]] || return 1
  cat "$1" | _clipboard_copy
}

# Copy the current ZLE buffer to clipboard (bound to ^O)
copybuffer() {
  [[ -n $BUFFER ]] || return 1
  print -rn -- "$BUFFER" | _clipboard_copy
  zle -M "Copied to clipboard."
}
zle -N copybuffer
bindkey -M {emacs,viins,vicmd} '^O' copybuffer

