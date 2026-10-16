this is preliminary.

noticed i won't remember my workflow if it's not hot in memory.

the basic gist is that this is based on chezmoi, and i've added some logic before & after chezmoi's dotfile initialization.
some tools are at the same "level". one was mise, but it's not anymore because it wasn't worth the (figurative) buck.

i intend to use the repo by initializing a bunch of machines a bunch of times, and correcting the inefficiencies.

might all be in vain, though, since your space always has more entropy by virtue of it being your space.
the difference between its actual state and its "neat" save-able state is never zero.
i'd have to keep doing this perpetual audit for efficiency, so i'll probably call it quits at some point

i track total package state of my machine (that is, managed by the distro's pacman and my own tech stack) via a custom script 'pmsync'

pmsync doesn't auto-commit bc it's not perfect. sometimes i forget to exclude some package, sometimes i want packages tracked/un-tracked regardless
either way, i retian veto muahaha
