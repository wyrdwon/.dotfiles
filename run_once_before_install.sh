#!/usr/bin/env bash
# =============================================================
# run_once_before_install.sh
#
# Executed by chezmoi exactly once, BEFORE dotfiles are applied.
# Re-runs only if this file's content changes.
#
# Prerequisites (the only manual step on a fresh machine):
#   sudo pacman -S --needed git chezmoi
#   chezmoi init --apply https://github.com/you/dotfiles
#
# This script then handles everything else:
#   1. System update
#   2. Pacman packages
#   3. yay bootstrap + AUR packages
#   4. rustup + cargo packages
#   5. uv packages
#   6. zsh as default shell
#
# TODO look into agent API key insertion (via .tmpl)
# would be using rbw as the secrets manager, same as before
# =============================================================

set -euo pipefail

PACKAGES_FILE="$(chezmoi source-path)/packages.txt"
JULIA_CHANNEL="${JULIA_CHANNEL:-release}" # release | lts | 1.x

# -------------------------------------------------------------
# Helpers
# -------------------------------------------------------------
info()    { printf '\e[34m[bootstrap]\e[0m  %s\n' "$*"; }
success() { printf '\e[32m[bootstrap]\e[0m  %s\n' "$*"; }
warn()    { printf '\e[33m[bootstrap]\e[0m  %s\n' "$*"; }
die()     { printf '\e[31m[bootstrap]\e[0m  %s\n' "$*" >&2; exit 1; }

parse_section() {
  local section="$1"
  awk "/^\[${section}\]/{found=1; next} /^\[/{found=0} found && /^[^#]/ && NF" "$PACKAGES_FILE"
}

# -------------------------------------------------------------
# Sanity checks
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
  sudo pacman -S --needed --noconfirm base-devel git
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
  success "rustup installed."
else
  success "rustup already present."
fi

# rustup may come from pacman (no ~/.cargo/env, no toolchain yet)
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
export PATH="$HOME/.cargo/bin:$PATH"
rustup default stable
rustup component add rust-analyzer

info "Installing cargo packages..."
mapfile -t cargo_pkgs < <(parse_section cargo)

for pkg in "${cargo_pkgs[@]}"; do
  if grep -q "^${pkg} " < <(cargo install --list); then
    success "cargo: $pkg already installed."
  else
    info "cargo install $pkg"
    cargo install --locked "$pkg"
  fi
done

# -------------------------------------------------------------
# 6. uv bootstrap
# -------------------------------------------------------------
if ! command -v uv &>/dev/null; then
  info "uv not found — installing via official installer..."
  curl --proto '=https' --tlsv1.2 -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh
  # installer writes to ~/.local/bin by default
  export PATH="$HOME/.local/bin:$PATH"
  success "uv installed."
else
  success "uv already present."
fi

# -------------------------------------------------------------
# 7. uv tools 
# -------------------------------------------------------------
info "Installing uv tools..."
mapfile -t uv_pkgs < <(parse_section uv)

for pkg in "${uv_pkgs[@]}"; do
  if grep -q "^${pkg} " < <(uv tool list 2>/dev/null); then
    success "uv: $pkg already installed."
  else
    info "uv tool install $pkg"
    uv tool install "$pkg"
  fi
done

# -------------------------------------------------------------
# 8. juliaup + Julia (before any Mason julia-lsp install)
# -------------------------------------------------------------
export PATH="$HOME/.juliaup/bin:$PATH"
if ! command -v juliaup &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -fsSL https://install.julialang.org |
    sh -s -- --yes --add-to-path=no --default-channel "$JULIA_CHANNEL"
fi

# -------------------------------------------------------------
# 9. Default shell → zsh
# -------------------------------------------------------------
ZSH_PATH="$(command -v zsh)" || die "zsh not installed (add it to [pacman])."
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  info "Setting default shell to zsh ($ZSH_PATH)..."
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
  chsh -s "$ZSH_PATH"
  success "Default shell set to zsh. Takes effect on next login."
else
  success "zsh is already the default shell."
fi

# -------------------------------------------------------------
# Done
# -------------------------------------------------------------
printf '\n'
success "Bootstrap complete — chezmoi will now apply dotfiles."
