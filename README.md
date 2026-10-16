this is preliminary.

noticed i won't remember my workflow if it's not hot in memory.

the basic gist is that this is based on chezmoi, and i've added some logic before & after chezmoi's dotfile initialization.
some tools are at the same "level". one was mise, but it's not anymore because it wasn't worth the (figurative) buck.

the process is:

1. acquire fresh machine
2. go through the process of bootstarpping arch (which has proven a pain for me, despite having done it like n times)
3. on the fresh install:

> sudo pacman -S --needed git chezmoi
> chezmoi init --apply https://github.com/you/dotfiles

> this then bootstraps stuffies (see before_install) and adds some sprinkles (see post_install)

i intend to use the repo by initializing a bunch of machines a bunch of times, and correcting the inefficiencies.

might all be in vain, though, since your space always has more entropy by virtue of it being your space.
the difference between its actual state and its "neat" save-able state is never zero.
i'd have to keep doing this perpetual audit for efficiency, so i'll probably call it quits at some point

i track total package state of my machine (that is, managed by the distro's pacman and my own tech stack) via a custom script 'pmsync'

pmsync doesn't auto-commit bc it's not perfect. sometimes i forget to exclude some package, sometimes i want packages tracked/un-tracked regardless
either way, i retian veto muahaha

i often have to manually clear state (cm state reset), because it keeps fucking me over. this is currently a duct tape solution.

chezmoi: timeout obtaining persistent state lock, is another instance of chezmoi running?
chezmoi: install.sh: exit status 1

a lot of stuff needs at least tentative documetnation, otherwise i'll waste time rederiving stuff. stuff below should be made more programmatic but i'm lazy rn

nvim setup (not already explicit), in ordered list:
for python: basedpyright LSP, ruff & isort linter/formatter
for c++: clangd & clang-format
for julia: julia-lsp, not opinionated to care about formatter.
form quarto: panache lsp + formatter
for js/ts: tsc LSP, prettierd formatting

Mason setup: look at the folder names in ~/.local/share/nvim/mason/packages. they correspond to the individual LSP/linter/formatters
might help to process the receipts in each, rather than just go off name. On second thought, just run :MasonInstall <name>
it seems to me that names have a uniqueness guarantee
