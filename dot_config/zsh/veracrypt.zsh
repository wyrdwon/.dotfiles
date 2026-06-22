# veracrypt.zsh — VeraCrypt convenience wrappers
#
#
# Source from .zshrc or a dedicated sourced file, e.g.:
#   source "${ZDOTDIR:-$HOME}/.config/zsh/veracrypt.zsh"
#
# Runtime deps: veracrypt, findmnt (util-linux), sudo

# ─────────────────────────────────────────────────────────────────────────────
# veramount <device> [mountpoint=/mnt/vc] [options]
# ─────────────────────────────────────────────────────────────────────────────
veramount() {
  emulate -L zsh

  # ── help ──────────────────────────────────────────────────────────────────
  local _short="Usage: veramount <device> [mountpoint=/mnt/vc]
       [--pim N] [--keyfile PATH]... [--readonly] [--protect-hidden]
       [-h] [-H]"

  local _long="veramount — VeraCrypt mount convenience wrapper

USAGE
  veramount <device> [mountpoint] [options]

ARGUMENTS
  <device>           Container file or block device (e.g. /dev/sdb1, vault.vc)
  [mountpoint]       Mount target directory (default: /mnt/vc)

OPTIONS
  --pim <n>          PIM value; 0 = standard iteration count (default: 0)
  --keyfile <path>   Keyfile path; repeatable for multiple keyfiles
  --readonly         Mount volume read-only
  --protect-hidden   Mount the outer volume while protecting the hidden volume.
                     VeraCrypt will prompt for both passwords interactively —
                     piping a second password is not possible without a CLI
                     argument leak, so this hands off to VeraCrypt's own prompts.
  -h                 Short usage
  -H                 This help

MOUNTPOINT BEHAVIOUR
  If the default mountpoint is occupied you will be prompted:
    y  →  dismounts the current volume, then mounts here
    n  →  prompts for an alternate path (default: /mnt/vcN, lowest free N)
  Auto-created /mnt/vcN directories are removed after successful dismount.

PASSWORDS
  Read via 'read -s'; never passed as CLI arguments or recorded in history.
  Post-use zeroing is best-effort — zsh cannot zero heap-allocated strings.

EXAMPLES
  veramount ~/vault.vc
  veramount /dev/sdb1 /mnt/vc --pim 42 --keyfile ~/.keys/main.key
  veramount ~/outer.vc /mnt/vc --protect-hidden
  veramount ~/data.vc --readonly"

  # ── option parsing ─────────────────────────────────────────────────────────
  local -a _fh _fH _fro _fph _opim _okf

  zparseopts -D -E -- \
    h=_fh H=_fH   \
    -pim:=_opim   \
    -keyfile:=_okf \
    -readonly=_fro  \
    -protect-hidden=_fph \
    2>/dev/null \
    || { print -u2 "veramount: unknown option — try 'veramount -h'"; return 1 }

  (( ${#_fh} )) && { print -- "$_short"; return 0 }
  (( ${#_fH} )) && { print -- "$_long";  return 0 }

  # ── positional args ────────────────────────────────────────────────────────
  local device=${1:-}
  local mp=${2:-/mnt/vc}

  if [[ -z $device ]]; then
    print -u2 "veramount: <device> is required"
    print -u2 "$_short"
    return 1
  fi

  # ── validate device ────────────────────────────────────────────────────────
  if [[ ! -f $device && ! -b $device ]]; then
    print -u2 "veramount: '${device}' is not a regular file or block device"
    return 1
  fi

  # ── extract option values ──────────────────────────────────────────────────
  local pim=${_opim[2]:-0}
  if [[ ! $pim =~ ^[0-9]+$ ]]; then
    print -u2 "veramount: --pim requires a non-negative integer, got '${pim}'"
    return 1
  fi

  local -a keyfiles=()
  local i kf
  for (( i = 2; i <= ${#_okf}; i += 2 )); do
    kf=${_okf[$i]}
    if [[ ! -e $kf ]]; then
      print -u2 "veramount: keyfile '${kf}' not found"
      return 1
    fi
    keyfiles+=("$kf")
  done

  local is_readonly=$(( ${#_fro} > 0 ))
  local is_protect=$(( ${#_fph} > 0 ))

  # ── sudo credential warmup ─────────────────────────────────────────────────
  # Authenticate now so the password → VeraCrypt password ordering is clean.
  print 'veramount: caching sudo credentials…'
  sudo -v || { print -u2 'veramount: sudo authentication failed'; return 1 }

  # ── mountpoint handling ────────────────────────────────────────────────────
  if [[ ! -d $mp ]]; then
    sudo mkdir -p "$mp" || {
      print -u2 "veramount: cannot create mountpoint '${mp}'"
      return 1
    }
  fi

  if findmnt "$mp" &>/dev/null; then
    print "veramount: '${mp}' is already in use."
    local ans
    print -n '  Override? (dismount current volume and mount here) [y/N]: '
    read -r ans

    if [[ ${ans:l} == y ]]; then
      sudo veracrypt --text --dismount "$mp" || {
        print -u2 "veramount: failed to dismount existing volume at '${mp}'"
        return 1
      }
    else
      # Propose next free /mnt/vcN as the default
      local x=1
      while [[ -e /mnt/vc${x} ]]; do (( x++ )); done
      local default_alt=/mnt/vc${x}

      local alt
      print -n "  Alternate mountpoint [${default_alt}]: "
      read -r alt
      mp=${alt:-$default_alt}

      if [[ ! -d $mp ]]; then
        sudo mkdir -p "$mp" || {
          print -u2 "veramount: cannot create '${mp}'"
          return 1
        }
      fi
    fi
  fi

  # ── build VeraCrypt args ───────────────────────────────────────────────────
  # Volume and mountpoint go last; options precede them.
  local -a vc_args=(--text "--pim=${pim}")

  (( is_readonly )) && vc_args+=(--mount-options=ro)

  for kf in "${keyfiles[@]}"; do
    vc_args+=(--keyfiles="$kf")
  done

  vc_args+=("$device" "$mp")

  # ── mount ──────────────────────────────────────────────────────────────────
  local rc
  if (( is_protect )); then
    # --stdin can only deliver one password; a second would require --protection-password
    # which leaks in ps(1). Hand off to VeraCrypt's own interactive prompts instead.
    vc_args+=(--protect-hidden=yes)
    print 'veramount: --protect-hidden active — VeraCrypt will prompt for both passwords'
    sudo veracrypt "${vc_args[@]}"
    rc=$?
  else
    local pass=''
    print -n 'VeraCrypt password: '
    read -rs pass
    print  # restore newline after silent read
    # print is a zsh builtin; the variable never appears in a process argument list.
    print -r -- "$pass" | sudo veracrypt --stdin "${vc_args[@]}"
    rc=$?
    pass=''  # best-effort; zsh cannot zero heap-allocated string memory
  fi

  # ── result ─────────────────────────────────────────────────────────────────
  if (( rc == 0 )); then
    print "veramount: ✓ '${device}' → '${mp}'"
  else
    print -u2 "veramount: VeraCrypt exited with status ${rc}"
    # Remove an auto-created ephemeral mountpoint if the mount failed
    if [[ $mp != /mnt/vc && $mp =~ ^/mnt/vc[0-9]+$ ]]; then
      sudo rmdir "$mp" 2>/dev/null
    fi
    return $rc
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# veradismount <device|mountpoint> [--force]
# veradismount --all [--force]
# ─────────────────────────────────────────────────────────────────────────────
veradismount() {
  emulate -L zsh

  # ── help ──────────────────────────────────────────────────────────────────
  local _short="Usage: veradismount <device|mountpoint> [--force] [-h|-H]
       veradismount --all [--force]"

  local _long="veradismount — VeraCrypt dismount convenience wrapper

USAGE
  veradismount <device|mountpoint> [options]
  veradismount --all [--force]

ARGUMENTS
  <device|mountpoint>   Block device (e.g. /dev/sdb1) or mountpoint
                        (e.g. /mnt/vc) of the volume to dismount.
                        VeraCrypt accepts either form.

OPTIONS
  --all      Dismount all currently mounted VeraCrypt volumes
  --force    Force dismount even if the volume is in use
  -h         Short usage
  -H         This help

NOTES
  Auto-created ephemeral mountpoints (/mnt/vcN) are removed after a
  successful dismount. /mnt/vc itself is never removed.

EXAMPLES
  veradismount /mnt/vc
  veradismount /dev/sdb1 --force
  veradismount --all
  veradismount --all --force"

  # ── option parsing ─────────────────────────────────────────────────────────
  local -a _fh _fH _fforce _fall

  zparseopts -D -E -- \
    h=_fh H=_fH   \
    -force=_fforce \
    -all=_fall     \
    2>/dev/null \
    || { print -u2 "veradismount: unknown option — try 'veradismount -h'"; return 1 }

  (( ${#_fh} )) && { print -- "$_short"; return 0 }
  (( ${#_fH} )) && { print -- "$_long";  return 0 }

  local target=${1:-}
  local is_force=$(( ${#_fforce} > 0 ))
  local is_all=$(( ${#_fall} > 0 ))

  if (( !is_all )) && [[ -z $target ]]; then
    print -u2 "veradismount: target required (or use --all)"
    print -u2 "$_short"
    return 1
  fi

  # ── sudo credential warmup ─────────────────────────────────────────────────
  print 'veradismount: caching sudo credentials…'
  sudo -v || { print -u2 'veradismount: sudo authentication failed'; return 1 }

  # ── dismount ───────────────────────────────────────────────────────────────
  local -a vc_args=(--text --dismount)
  (( is_force )) && vc_args+=(--force)
  # Without a target, VeraCrypt dismounts all volumes.
  (( !is_all  )) && vc_args+=("$target")

  sudo veracrypt "${vc_args[@]}"
  local rc=$?

  if (( rc != 0 )); then
    print -u2 "veradismount: VeraCrypt exited with status ${rc}"
    return $rc
  fi

  # ── cleanup: remove auto-created ephemeral mountpoints ────────────────────
  # (N) is a zsh null-glob qualifier: silently expands to nothing if no match.
  if (( is_all )); then
    print 'veradismount: ✓ all volumes dismounted'
    local d
    for d in /mnt/vc*(N); do
      if [[ $d =~ ^/mnt/vc[0-9]+$ ]] && [[ -d $d ]]; then
        sudo rmdir "$d" 2>/dev/null \
          && print "veradismount: removed ephemeral mountpoint '${d}'"
      fi
    done
  else
    print "veradismount: ✓ '${target}' dismounted"
    if [[ $target =~ ^/mnt/vc[0-9]+$ ]]; then
      sudo rmdir "$target" 2>/dev/null \
        && print "veradismount: removed ephemeral mountpoint '${target}'"
    fi
  fi
}
