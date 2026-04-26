#!/usr/bin/env zsh
# deploy-librewolf.zsh
#
# Deploys tracked config files from dotfiles into the active LibreWolf profile.
# Must run AFTER resolve-librewolf-profile.zsh has created the symlink.
#
# Copies:
#   user.js              — preference overrides
#   chrome/              — userChrome.css, userContent.css (if present)
#   containers.json      — Multi-Account Containers (if present)
#   handlers.json        — protocol/MIME handlers (if present)
#   search.json.mozlz4   — custom search engines (if present)
#
# LibreWolf must be CLOSED when this runs, or prefs will be overwritten on exit.

set -euo pipefail

SYMLINK="${HOME}/.config/librewolf/librewolf/active-profile"
DOTFILES_LIBREWOLF="${CHEZMOI_SOURCE_DIR:-${HOME}/.local/share/chezmoi}/dot_config/librewolf/bewtstrap"

if [[ ! -L "${SYMLINK}" ]]; then
  print -u2 "Error: ${SYMLINK} does not exist."
  print -u2 "Run resolve-librewolf-profile.zsh first."
  exit 1
fi

PROFILE="$(readlink -f "${SYMLINK}")"

print "Deploying to: ${PROFILE}"

# --- user.js ---
if [[ -f "${DOTFILES_LIBREWOLF}/user.js" ]]; then
  cp "${DOTFILES_LIBREWOLF}/user.js" "${PROFILE}/user.js"
  print "  Deployed user.js"
fi

# --- chrome/ directory ---
if [[ -d "${DOTFILES_LIBREWOLF}/chrome" ]]; then
  mkdir -p "${PROFILE}/chrome"
  cp -r "${DOTFILES_LIBREWOLF}/chrome/"* "${PROFILE}/chrome/"
  print "  Deployed chrome/"
fi

# --- Optional tracked files ---
for tracked_file in containers.json handlers.json search.json.mozlz4 persdict.dat; do
  src="${DOTFILES_LIBREWOLF}/${tracked_file}"
  if [[ -f "${src}" ]]; then
    cp "${src}" "${PROFILE}/${tracked_file}"
    print "  Deployed ${tracked_file}"
  fi
done

print "Done. Launch LibreWolf to apply."
