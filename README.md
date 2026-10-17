# dotfiles

> this is preliminary.

## overview

the basic gist is that this is based on chezmoi, and i've added some logic before and after
chezmoi's dotfile initialization.

some tools are at the same "level". one was mise, but it's not anymore because it wasn't worth the
(figurative) buck. rn it's uv, rustup, juliaup (anything with its own entry in
[before_install][before])

noticed i won't remember my workflow if it's not hot in memory, so this doc is mostly for future me.

## process

1. acquire a fresh machine.

   > make sure the hostname is wyrd, for obvious reasons

2. follow the arch wiki:
   - get stuck trying to encrypt partitions
   - fix sysconfig shenanigans
   - [???]
   - profit

3. on the fresh install:

```sh
sudo pacman -S --needed base-devel git chezmoi
chezmoi init --apply https://github.com/you/dotfiles
```

this then bootstraps stuffies (see [`before_install`][before]) and adds some sprinkles (see
[`after_install`][after]).

i intend to use the repo by initializing a bunch of machines a bunch of times, and correcting the
inefficiencies.

it might all be in vain, though, since your space always has more entropy by virtue of it being your
space. the difference between its actual state and its "neat" save-able state is never zero. i'd
have to keep doing this perpetual audit for efficiency, so i'll probably call it quits at some
point.

## pmsync

i track the total package state of my machine (that is, managed by the distro's pacman and my own
tech stack) via a custom script, `pmsync`.

`pmsync` doesn't auto-commit because it's not perfect. sometimes i forget to exclude some package,
and sometimes i want packages tracked or untracked regardless. either way, i retain veto muahaha.

## known issues

i often have to manually clear state (`cm state reset`) because it keeps fucking me over. this is
currently a duct tape solution.

```
chezmoi: timeout obtaining persistent state lock, is another instance of chezmoi running?
chezmoi: install.sh: exit status 1
```

a lot of stuff needs at least tentative documentation, otherwise i'll waste time rederiving stuff.
the stuff below should be made more programmatic, but i'm lazy rn.

## neovim setup

if not already explicit/obvious from the files, in ordered list:

- **python:** basedpyright, ruff
- **c++:** clangd, clang-format
- **julia:** julia-lsp, not opinionated enough to care about a formatter
- **quarto:** panache (lsp + formatter)
- **js/ts:** typescript-language-server, prettierd

## mason

look at the folder names in `~/.local/share/nvim/mason/packages`. they correspond to the individual
lsps, linters, and formatters. it might help to process the receipts in each, rather than just going
off names.

on second thought, just run `:MasonInstall <name>`. it seems to me that names have a uniqueness
guarantee.

[before]: ./run_onchange_before_install.sh.tmpl
[after]: ./run_onchange_after_install.zsh.tmpl
