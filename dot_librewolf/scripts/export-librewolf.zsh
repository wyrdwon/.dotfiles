#!/usr/bin/env zsh
# export-librewolf.zsh
#
# Captures current LibreWolf config state back into the dotfiles source tree.
# Run this when you've made changes in the browser that you want to persist.
#
# What gets captured:
#   - user.js (if you edited it manually in the profile)
#   - containers.json
#   - handlers.json
#   - search.json.mozlz4
#   - persdict.dat
#   - chrome/ directory
#   - bookmarks: decodes the most recent bookmarkbackups/*.jsonlz4
#                into bookmarks-latest.json (plain JSON, human-readable)
#
# NOTE: bookmarks exported via File > Export Bookmarks (HTML) are a separate
# artifact and are NOT managed here. Keep them alongside as bookmarks.html.
# This script handles the programmatic backup path only.
#
# LibreWolf must be CLOSED when this runs for clean reads.

set -euo pipefail

SYMLINK="${HOME}/.config/librewolf/librewolf/active-profile"
DOTFILES_LIBREWOLF="${CHEZMOI_SOURCE_DIR:-${HOME}/.local/share/chezmoi}/dot_librewolf"

if [[ ! -L "${SYMLINK}" ]]; then
  print -u2 "Error: ${SYMLINK} does not exist."
  print -u2 "Run resolve-librewolf-profile.zsh first."
  exit 1
fi

PROFILE="$(readlink -f "${SYMLINK}")"
mkdir -p "${DOTFILES_LIBREWOLF}"

print "Exporting from: ${PROFILE}"

# --- user.js ---
if [[ -f "${PROFILE}/user.js" ]]; then
  cp "${PROFILE}/user.js" "${DOTFILES_LIBREWOLF}/user.js"
  print "  Exported user.js"
fi

# --- chrome/ ---
if [[ -d "${PROFILE}/chrome" ]]; then
  mkdir -p "${DOTFILES_LIBREWOLF}/chrome"
  cp -r "${PROFILE}/chrome/"* "${DOTFILES_LIBREWOLF}/chrome/"
  print "  Exported chrome/"
fi

# --- Optional files ---
for tracked_file in containers.json handlers.json search.json.mozlz4 persdict.dat; do
  src="${PROFILE}/${tracked_file}"
  if [[ -f "${src}" ]]; then
    cp "${src}" "${DOTFILES_LIBREWOLF}/${tracked_file}"
    print "  Exported ${tracked_file}"
  fi
done

# --- Bookmarks: decode latest jsonlz4 backup to plain JSON ---
BACKUPS_DIR="${PROFILE}/bookmarkbackups"
if [[ -d "${BACKUPS_DIR}" ]]; then
  # Most recent backup by modification time
  latest_backup=$(ls -t "${BACKUPS_DIR}"/*.jsonlz4 2>/dev/null | head -1)
  if [[ -n "${latest_backup}" ]]; then
    out="${DOTFILES_LIBREWOLF}/bookmarks-latest.json"
    python3 - "${latest_backup}" "${out}" << 'PYEOF'
import sys, json, lz4.block, struct

src, dst = sys.argv[1], sys.argv[2]
with open(src, 'rb') as f:
    magic = f.read(8)
    assert magic == b'mozLz40\0', f"Not a mozlz4 file: {src}"
    raw = lz4.block.decompress(f.read(), uncompressed_size=struct.unpack('<I', f.read(4))[0]
                               if False else 64 * 1024 * 1024)
data = json.loads(raw)
with open(dst, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(f"  Decoded bookmarks -> {dst}")
PYEOF
  else
    print "  No bookmark backups found in ${BACKUPS_DIR}"
  fi
fi

print "Export complete."
print "Review changes with: chezmoi diff"
print "Stage with:          chezmoi re-add ${DOTFILES_LIBREWOLF}"
