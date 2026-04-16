#!/usr/bin/env zsh
# =============================================================
# run_once_post-install.zsh
#
# Executed by chezmoi exactly once, AFTER dotfiles are applied.
# Re-runs only if this file's content changes.
#
# Assumes run_once_before_install.sh has already completed:
# zsh, mise, antidote, neovim, cargo are all expected present.
# =============================================================

set -euo pipefail

info() { printf '\e[34m[post-install]\e[0m  %s\n' "$*"; }
success() { printf '\e[32m[post-install]\e[0m  %s\n' "$*"; }
warn() { printf '\e[33m[post-install]\e[0m  %s\n' "$*"; }

# -------------------------------------------------------------
# 1. Antidote — compile plugin bundle from ~/.zsh_plugins.txt
# -------------------------------------------------------------
if [[ -f ~/.zsh_plugins.txt ]]; then
  info "Compiling antidote plugin bundle..."
  if [[ -f /usr/share/zsh-antidote/functions/antidote ]]; then
    set +u
    source /usr/share/zsh-antidote/functions/antidote
    set -u
    antidote bundle <~/.zsh_plugins.txt >|~/.zsh_plugins.zsh
    success "antidote bundle compiled."
  else
    warn "antidote not found at expected path — skipping."
  fi
else
  warn "~/.zsh_plugins.txt not found — skipping antidote."
fi

# -------------------------------------------------------------
# 2. mise — install all runtimes defined in ~/.config/mise/config.toml
# -------------------------------------------------------------
if command -v mise &>/dev/null; then
  info "Installing mise runtimes..."
  mise install
  success "mise runtimes installed."
else
  warn "mise not found — skipping runtime installs."
fi

# -------------------------------------------------------------
# 3. Neovim — headless plugin sync via lazy.nvim
# -------------------------------------------------------------
if command -v nvim &>/dev/null; then
  info "Syncing neovim plugins (headless)..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null &&
    success "Neovim plugins synced." ||
    warn "Neovim plugin sync exited non-zero — check manually with 'nvim +Lazy'."
else
  warn "nvim not found — skipping plugin sync."
fi

# -------------------------------------------------------------
# 4. Broot — generate shell launcher if not already present
# Chezmoi does not track the launcher (generated output);
# broot --install writes it fresh on each new machine.
# -------------------------------------------------------------
if command -v broot &>/dev/null; then
  if [[ ! -f ~/.config/broot/launcher/zsh/br ]]; then
    info "Installing broot launcher..."
    broot --install
    success "broot launcher installed."
  else
    success "broot launcher already present."
  fi
else
  warn "broot not found — skipping launcher install."
fi

# -------------------------------------------------------------
# Done
# -------------------------------------------------------------
printf '\n'
success "Post-install complete."
info "Start a new zsh session to pick up the full environment."
