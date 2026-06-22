#!/bin/zsh

# used in .file aliases
chez_edit() {
  local file="$1"

  if [[ -z "$file" ]]; then
    echo "usage: chez_edit <file>"
    return 1
  fi

  # Open the real file in your editor
  ${EDITOR:-nvim} "$file"

  # Re-add it to chezmoi after editing
  chezmoi re-add "$file"
}
