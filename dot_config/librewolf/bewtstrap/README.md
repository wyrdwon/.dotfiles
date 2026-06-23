# LibreWolf dotfiles

## Layout

```
dot_config/librewolf/bewtstrap
  user.js                    # preference overrides — the only file you edit
  chrome/
    userChrome.css           # UI modifications
    userContent.css          # page content modifications
  containers.json            # Multi-Account Containers config
  handlers.json              # protocol/MIME handlers
  search.json.mozlz4         # custom search engines
  persdict.dat               # personal spellcheck dictionary
  bookmarks-latest.json      # decoded from most recent bookmarkbackups/*.jsonlz4
  extensions.yml             # manually maintained list of extension IDs/AMO slugs

  scripts/
    resolve-librewolf-profile.zsh   # run once after install: creates symlink
    deploy-librewolf.zsh            # dotfiles → profile (on fresh machine)
    export-librewolf.zsh            # profile → dotfiles (after in-browser changes)
```

> couldn't use dot_librewolf since librewolf interprets that as config path (over XDG one)
> perk of the arch version is that you'll have to make the dir first before starting librewolf

## Profile path resolution

LibreWolf generates a hex-prefixed profile directory (`xxxxxxxx.default-default`).
`resolve-librewolf-profile.zsh` reads `~/.config/librewolf/librewolf/profiles.ini`, resolves the
default profile path, and creates:

```
~/.config/librewolf/librewolf/active-profile -> ~/.librewolf/xxxxxxxx.default-default
```

All scripts reference this symlink. Run it once after first LibreWolf launch.
It is safe to rerun (idempotent).

## Workflow

### Fresh machine

```zsh
# 1. Install LibreWolf, launch it once (creates profile), close it.
# 2. Resolve profile path:
zsh ~/.local/share/chezmoi/dot_config/librewolf/bewtstrap/scripts/resolve-librewolf-profile.zsh
# 3. Deploy config:
zsh ~/.local/share/chezmoi/dot_config/librewolf/bewtstrap/scripts/deploy-librewolf.zsh
# 4. Install extensions (see extensions.yml), then restore:
#    - containers.json is already deployed; Firefox Containers reads it on launch
#    - search engines are in search.json.mozlz4
#    - import bookmarks.html via Bookmarks > Import
```

### After changing settings in the browser

```zsh
zsh ~/.local/share/chezmoi/dot_config/librewolf/bewtstrap/scripts/export-librewolf.zsh
chezmoi diff          # review
chezmoi re-add ~/.local/share/chezmoi/dot_config/librewolf/bewtstrap
git -C ~/.local/share/chezmoi add -p && git commit
```

### After editing user.js directly in dotfiles

```zsh
zsh ~/.local/share/chezmoi/dot_config/librewolf/bewtstrap/scripts/deploy-librewolf.zsh
# Then launch LibreWolf.
```

## user.js vs prefs.js

`user.js` is read by LibreWolf on every launch and overrides `prefs.js`.
`prefs.js` is runtime state written by the browser — do not track it.
Only `user.js` belongs in dotfiles.

## Extensions

Extensions cannot be reliably automated across platforms because:

- XPI binaries are profile-local, not portable
- Extension UUIDs are regenerated per profile
- Some extensions (Tree Style Tab, Simple Tab Groups) store substantial state
  in IndexedDB, not in trackable files

**Recommended approach: `extensions.yml`**

Maintain a plain-text list of AMO page URLs or extension IDs.
On a fresh machine, install from this list manually or via a policy file.

LibreWolf supports a `policies.json` at the browser level (not profile level)
to auto-install extensions:

```json
{
	"policies": {
		"ExtensionSettings": {
			"*": { "installation_mode": "allowed" },
			"uBlock0@raymondhill.net": {
				"installation_mode": "force_installed",
				"install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
			}
		}
	}
}
```

Place at: `/usr/lib/librewolf/distribution/policies.json` (system-wide)
or: `~/.config/librewolf/librewolf/policies.json` (user-level, if supported by your LibreWolf build).

Extension _preferences_ (not the binaries) can be partially preserved via
`extension-preferences.json` — track it alongside the others if desired,
but note that UUIDs will differ on a fresh install, so permissions may not
map correctly. It is better treated as a reference, not a deploy target.

## Bookmarks

Two separate flows — keep them separate:

| Method                  | Format                                               | Trigger                               |
| ----------------------- | ---------------------------------------------------- | ------------------------------------- |
| `export-librewolf.zsh`  | `bookmarks-latest.json` (decoded from mozlz4 backup) | run manually after changes            |
| File > Export Bookmarks | `bookmarks.html`                                     | run manually; import on fresh machine |

`bookmarks.html` is the portable, importable format. Keep it in the repo root
(not in `dot_librewolf/`) so it is not deployed by the deploy script.
