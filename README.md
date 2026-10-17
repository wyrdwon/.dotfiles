# dotfiles

> this is preliminary.

## Overview

The basic gist is that this is based on chezmoi, and I've added some logic before and after chezmoi's dotfile initialization.

Some tools are at the same "level". One was mise, but it's not anymore because it wasn't worth the (figurative) buck.

noticed I won't remember my workflow if it's not hot in memory, so this doc is mostly for future me.

## Process

1. Acquire a fresh machine.
2. follow the Arch wiki, get stuck trying to encrypt partitions & fix sysconfigs, [...], profit ???
3. On the fresh install:

```sh
sudo pacman -S --needed base-devel git chezmoi
chezmoi init --apply https://github.com/you/dotfiles
```

This then bootstraps stuffies (see `before_install`) and adds some sprinkles (see `post_install`).

I intend to use the repo by initializing a bunch of machines a bunch of times, and correcting the inefficiencies.

It might all be in vain, though, since your space always has more entropy by virtue of it being your space. The difference between its actual state and its "neat" save-able state is never zero. I'd have to keep doing this perpetual audit for efficiency, so I'll probably call it quits at some point.

## pmsync

I track the total package state of my machine (that is, managed by the distro's pacman and my own tech stack) via a custom script, `pmsync`.

`pmsync` doesn't auto-commit because it's not perfect. Sometimes I forget to exclude some package, and sometimes I want packages tracked or untracked regardless. Either way, I retain veto muahaha.

## Known issues

I often have to manually clear state (`cm state reset`) because it keeps fucking me over. This is currently a duct tape solution.

```
chezmoi: timeout obtaining persistent state lock, is another instance of chezmoi running?
chezmoi: install.sh: exit status 1
```

A lot of stuff needs at least tentative documentation, otherwise I'll waste time rederiving stuff. The stuff below should be made more programmatic, but I'm lazy rn.

## Neovim setup

If not already explicit/obvious from the files, in ordered list:

- **Python:** basedpyright, ruff
- **C++:** clangd, clang-format
- **Julia:** julia-lsp, not opinionated enough to care about a formatter
- **Quarto:** panache (LSP + formatter)
- **JS/TS:** typescript-language-server, prettierd

## Mason

Look at the folder names in `~/.local/share/nvim/mason/packages`. They correspond to the individual LSPs, linters, and formatters. It might help to process the receipts in each, rather than just going off names.

On second thought, just run `:MasonInstall <name>`. It seems to me that names have a uniqueness guarantee.
