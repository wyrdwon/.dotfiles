#!/usr/bin/env bash
# =============================================================
# install.sh — bootstrap a fresh Arch installation
#
# Idempotent: safe to run multiple times. Each step checks
# before acting. Run this BEFORE chezmoi apply.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# What it does, in order:
#   1. Verify we're on Arch
#   2. Full system update
#   3. Install pacman packages from packages.txt
#   4. Bootstrap yay if absent
#   5. Install AUR packages from packages.txt
#   6. Install rustup + cargo packages from packages.txt
#   7. Install pipx packages from packages.txt
#   8. Set zsh as default shell if not already
#   9. Install chezmoi and apply dotfiles
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/packages.txt"

# -------------------------------------------------------------
# Helpers
# -------------------------------------------------------------
info()    { printf '\e[34m[info]\e[0m  %s\n' "$*"; }
success() { printf '\e[32m[ok]\e[0m    %s\n' "$*"; }
warn()    { printf '\e[33m[warn]\e[0m  %s\n' "$*"; }
die()     { printf '\e[31m[error]\e[0m %s\n' "$*" >&2; exit 1; }

# Parse a section from packages.txt, stripping comments and blanks
parse_section() {
  local section="$1"
  awk "/^\[${section}\]/{found=1; next} /^\[/{found=0} found && /^[^#]/ && NF" "$PACKAGES_FILE"
}

# -------------------------------------------------------------
# 0. Sanity checks
# -------------------------------------------------------------
[[ -f /etc/arch-release ]] || die "This script is for Arch Linux only."
[[ -f "$PACKAGES_FILE" ]] || die "packages.txt not found at $PACKAGES_FILE"

# -------------------------------------------------------------
# 1. System update
# -------------------------------------------------------------
info "Updating system..."
sudo pacman -Syu --noconfirm
success "System up to date."

# -------------------------------------------------------------
# 2. Pacman packages
# -------------------------------------------------------------
info "Installing pacman packages..."
mapfile -t pacman_pkgs < <(parse_section pacman)

to_install=()
for pkg in "${pacman_pkgs[@]}"; do
  pacman -Qi "$pkg" &>/dev/null || to_install+=("$pkg")
done

if [[ ${#to_install[@]} -gt 0 ]]; then
  info "Installing: ${to_install[*]}"
  sudo pacman -S --noconfirm --needed "${to_install[@]}"
else
  success "All pacman packages already installed."
fi

# -------------------------------------------------------------
# 3. Bootstrap yay
# -------------------------------------------------------------
if ! command -v yay &>/dev/null; then
  info "yay not found — bootstrapping from AUR..."
  tmp=$(mktemp -d)
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  success "yay installed."
else
  success "yay already present."
fi

# -------------------------------------------------------------
# 4. AUR packages
# -------------------------------------------------------------
info "Installing AUR packages..."
mapfile -t aur_pkgs < <(parse_section aur)

if [[ ${#aur_pkgs[@]} -eq 0 ]]; then
  info "No AUR packages listed."
else
  to_install=()
  for pkg in "${aur_pkgs[@]}"; do
    yay -Qi "$pkg" &>/dev/null || to_install+=("$pkg")
  done
  if [[ ${#to_install[@]} -gt 0 ]]; then
    yay -S --noconfirm --needed "${to_install[@]}"
  else
    success "All AUR packages already installed."
  fi
fi

# -------------------------------------------------------------
# 5. Rust / Cargo
# -------------------------------------------------------------
if ! command -v rustup &>/dev/null; then
  info "rustup not found — installing..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
  success "rustup installed."
else
  success "rustup already present."
  source "$HOME/.cargo/env"
fi

info "Installing cargo packages..."
mapfile -t cargo_pkgs < <(parse_section cargo)

for pkg in "${cargo_pkgs[@]}"; do
  if cargo install --list | grep -q "^${pkg} "; then
    success "cargo: $pkg already installed."
  else
    info "cargo install $pkg"
    cargo install "$pkg"
  fi
done

# -------------------------------------------------------------
# 6. pipx packages
# -------------------------------------------------------------
if ! command -v pipx &>/dev/null; then
  warn "pipx not found — skipping pipx packages. Install python-pipx first."
else
  info "Installing pipx packages..."
  mapfile -t pipx_pkgs < <(parse_section pipx)

  for pkg in "${pipx_pkgs[@]}"; do
    if pipx list --short 2>/dev/null | grep -q "^${pkg} "; then
      success "pipx: $pkg already installed."
    else
      info "pipx install $pkg"
      pipx install "$pkg"
    fi
  done
fi

# -------------------------------------------------------------
# 7. Default shell → zsh
# -------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  info "Setting default shell to zsh ($ZSH_PATH)..."
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
  chsh -s "$ZSH_PATH"
  success "Default shell set to zsh. Takes effect on next login."
else
  success "zsh is already the default shell."
fi

# -------------------------------------------------------------
# 8. chezmoi — apply dotfiles
# -------------------------------------------------------------
if ! command -v chezmoi &>/dev/null; then
  die "chezmoi not found. It should have been installed in the pacman step — check packages.txt."
fi

CHEZMOI_SOURCE="${CHEZMOI_SOURCE:-}"   # allow override via env var
CHEZMOI_REPO="${CHEZMOI_REPO:-}"       # e.g. https://github.com/you/dotfiles

if [[ -d "$HOME/.local/share/chezmoi/.git" ]]; then
  info "chezmoi source already initialised — running apply..."
  chezmoi apply
elif [[ -n "$CHEZMOI_REPO" ]]; then
  info "Initialising chezmoi from $CHEZMOI_REPO..."
  chezmoi init --apply "$CHEZMOI_REPO"
else
  warn "No chezmoi repo specified. Set CHEZMOI_REPO=https://github.com/you/dotfiles and re-run,"
  warn "or run 'chezmoi init --apply <repo>' manually."
fi

# -------------------------------------------------------------
# Done
# -------------------------------------------------------------
printf '\n'
success "Bootstrap complete."
info "Open a new shell or run 'exec zsh' to pick up the new environment."
