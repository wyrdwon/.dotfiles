#!/usr/bin/env zsh
# resolve-librewolf-profile.zsh
#
# Reads ~/.config/librewolf/librewolf/profiles.ini, resolves the default profile path,
# and creates a stable symlink at ~/.config/librewolf/librewolf/active-profile.
#
# Intended to run once after LibreWolf has been installed and launched
# at least once (profile directory must already exist).
#
# Safe to re-run: symlink is updated if profile path changes.

set -euo pipefail

PROFILES_INI="${HOME}/.config/librewolf/librewolf/profiles.ini"
SYMLINK="${HOME}/.config/librewolf/librewolf/active-profile"

if [[ ! -f "${PROFILES_INI}" ]]; then
  print -u2 "Error: ${PROFILES_INI} not found."
  print -u2 "Launch LibreWolf at least once before running this script."
  exit 1
fi

# Parse the Default= key from profiles.ini.
# profiles.ini uses Windows-style INI; Default= points to the relative path.
# Example line: Default=xxxxxxxx.default-default
profile_rel=$(awk -F= '/^Default=/ && $2 !~ /^[0-9]+$/ { print $2; exit }' "${PROFILES_INI}")

if [[ -z "${profile_rel}" ]]; then
  # Fallback: find Path= under the first [Profile] section marked Default=1
  profile_rel=$(awk '
    /^\[Profile/ { in_profile=1; path=""; is_default=0 }
    in_profile && /^Path=/ { path=$0; sub(/^Path=/, "", path) }
    in_profile && /^Default=1/ { is_default=1 }
    in_profile && /^\[/ && !/^\[Profile/ { if (is_default && path) { print path; exit } in_profile=0 }
    END { if (is_default && path) print path }
  ' "${PROFILES_INI}")
fi

if [[ -z "${profile_rel}" ]]; then
  print -u2 "Error: Could not determine default profile from ${PROFILES_INI}."
  exit 1
fi

# profiles.ini paths are relative to the directory containing profiles.ini
LIBREWOLF_DIR="${HOME}/.config/librewolf/librewolf"
profile_abs="${LIBREWOLF_DIR}/${profile_rel}"

if [[ ! -d "${profile_abs}" ]]; then
  print -u2 "Error: Resolved profile directory does not exist: ${profile_abs}"
  print -u2 "Launch LibreWolf at least once to generate the profile."
  exit 1
fi

# Remove stale symlink if it points somewhere wrong
if [[ -L "${SYMLINK}" && "$(readlink "${SYMLINK}")" != "${profile_abs}" ]]; then
  rm "${SYMLINK}"
fi

if [[ ! -L "${SYMLINK}" ]]; then
  ln -s "${profile_abs}" "${SYMLINK}"
  print "Created symlink: ${SYMLINK} -> ${profile_abs}"
else
  print "Symlink already correct: ${SYMLINK} -> ${profile_abs}"
fi
