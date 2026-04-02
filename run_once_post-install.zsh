#!/usr/bin/env zsh
# =============================================================
# run_once_post-install.zsh
#
# Executed by chezmoi exactly once after dotfiles are applied
# (re-runs only if this file's content changes).
#
# Assumes install.sh has already run: zsh, mise, antidote,
# neovim, and cargo are all expected to be present.
# =============================================================

set -euo pipefail

info()    { printf '\e[34m[chezmoi/post]\e[0m  %s\n' "$*"; }
success() { printf '\e[32m[chezmoi/post]\e[0m  %s\n' "$*"; }
warn()    { printf '\e[33m[chezmoi/post]\e[0m  %s\n' "$*"; }

# -------------------------------------------------------------
# 1. Antidote — compile plugin bundle
# Generates ~/.zsh_plugins.zsh from ~/.zsh_plugins.txt
# -------------------------------------------------------------
if [[ -f ~/.zsh_plugins.txt ]]; then
  info "Compiling antidote plugin bundle..."
  source /usr/share/zsh-antidote/functions/antidote 2>/dev/null \
    || { warn "antidote not found at expected path — skipping."; }
  antidote bundle < ~/.zsh_plugins.txt >| ~/.zsh_plugins.zsh
  success "antidote bundle compiled."
else
  warn "~/.zsh_plugins.txt not found — skipping antidote."
fi

# -------------------------------------------------------------
# 2. mise — install all configured runtimes
# Reads ~/.config/mise/config.toml (applied by chezmoi already)
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
  nvim --headless "+Lazy! sync" +qa 2>/dev/null \
    && success "Neovim plugins synced." \
    || warn "Neovim plugin sync exited non-zero — check manually with 'nvim +Lazy'."
else
  warn "nvim not found — skipping plugin sync."
fi

# -------------------------------------------------------------
# 4. Broot — install launcher
# Generates the shell launcher scripts under ~/.config/broot/launcher/
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
# 5. zoxide — nothing to install, init is handled in .zshrc
# -------------------------------------------------------------
success "zoxide init is handled in .zshrc — nothing to do here."

# -------------------------------------------------------------
# Done
# -------------------------------------------------------------
printf '\n'
success "Post-install complete."
