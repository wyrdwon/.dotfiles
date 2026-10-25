#!/bin/zsh

# for CP :)
problem() {
  local is_contest=0
  local -a args=()

  # parse flags; keep first non-flag arg as the id
  for arg in "$@"; do
    case "$arg" in
    --contest | -c) is_contest=1 ;;
    *) args+=("$arg") ;;
    esac
  done

  if [[ -z "${args[1]}" ]]; then
    echo "usage: problem [--contest|-c] <id>  (e.g. problem 1a, problem -c 1a)" >&2
    return 1
  fi

  local input="${args[1]}"

  if [[ ! "$input" =~ '^[0-9]+[a-zA-Z0-9]*$' ]]; then
    echo "error: input must match [int][alphanum] (e.g. 1a, 42b3)" >&2
    return 1
  fi

  local dir_name="${input:u}"
  local file_name="${input:l}"
  local root
  if ((is_contest)); then
    root="$HOME/CP/CONTESTS"
  else
    root="$HOME/CP/GYM"
  fi
  local dir="${root}/${dir_name}"
  local file="${dir}/${file_name}.cpp"
  local is_reopen=0

  mkdir -p "$dir" || return 1

  if [[ -f "$file" ]]; then
    echo "note: ${file} already exists, opening without overwriting (re-attempt will be recorded)"
    is_reopen=1
  else
    cat >"$file" <<'EOF'
#include <bits/stdc++.h>
using namespace std;

typedef long long ll;
typedef pair<int, int> pii;
typedef vector<int> vi;
typedef vector<ll> vl;

#define rep(i, a, b) for (int i = (a); i < (b); i++)
#define all(x) (x).begin(), (x).end()
#define sz(x) (int)(x).size()
#define pb push_back

// --- globals (reset in solve() if using multi-test) ---

void solve() {
  
}

int main() {
  ios_base::sync_with_stdio(false);
  cin.tie(nullptr);
  int t = 1;
  // cin >> t;
  while (t--)
    solve();
  return 0;
}
EOF
  fi

  local start_ts=$EPOCHSECONDS

  if [[ "$(basename ${EDITOR:-vi})" == "nvim" ]]; then
    nvim "+/void solve" "+normal! jA" "$file"
  else
    ${EDITOR:-${VISUAL:-vi}} "$file"
  fi

  local elapsed=$((EPOCHSECONDS - start_ts))
  local minutes=$((elapsed / 60))
  local seconds=$((elapsed % 60))
  local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local attempt_label=""
  [[ $is_reopen -eq 1 ]] && attempt_label=" (re-attempt)"

  local record="// solved: ${timestamp} | time: ${minutes}m ${seconds}s${attempt_label}"

  # Prepend record to file
  local tmpfile="$(mktemp)"
  {
    echo "$record"
    cat "$file"
  } >"$tmpfile" && mv "$tmpfile" "$file"

  echo "recorded: ${record}"
}

_cpcomp_usage() {
  cat <<'EOF'
usage: cpcomp [-d|--debug | -s|--sanitize] <id>   (e.g. cpcomp 1a, cpcomp -s 1a)

  default     judge-mirror build, based on Codeforces GNU G++ flags:
              g++ -static -DONLINE_JUDGE -O2 -std=c++17 -Wall -Wextra -Wconversion
              Codeforces sets a 256 MB stack; ld rejects its -Wl,--stack flag on
              Linux, so set it in the shell before running:
                ulimit -s 262144
  -d, --debug     -O0 -g, -D_GLIBCXX_DEBUG (bounds-checked STL), -DLOCAL, -Wshadow
  -s, --sanitize  -O1 -g, AddressSanitizer + UBSan (abort on first error), -DLOCAL
  -h, --help      show this help

  -d and -s are mutually exclusive. Sanitizer and debug builds are not
  static and run slower; use them to find bugs, not to time solutions.
EOF
}

cpcomp() {
  # feat: compile CP problem by ID, emit binary in cwd
  # searches both CP/GYM and CP/CONTESTS since problem() may have
  # written to either root; no --contest flag needed here.

  local is_debug=0
  local is_sanitize=0
  local arg
  local -a args=()

  for arg in "$@"; do
    case "$arg" in
    -d | --debug) is_debug=1 ;;
    -s | --sanitize) is_sanitize=1 ;;
    -h | --help)
      _cpcomp_usage
      return 0
      ;;
    *) args+=("$arg") ;;
    esac
  done

  if ((is_debug && is_sanitize)); then
    echo "error: -d/--debug and -s/--sanitize are mutually exclusive" >&2
    return 1
  fi

  if [[ -z "${args[1]}" ]]; then
    _cpcomp_usage >&2
    return 1
  fi

  local input="${args[1]}"

  if [[ ! "$input" =~ '^[0-9]+[a-zA-Z0-9]*$' ]]; then
    echo "error: input must match [int][alphanum]" >&2
    return 1
  fi

  local dir_name="${input:u}"
  local file_name="${input:l}"

  local contest_file="$HOME/CP/CONTESTS/${dir_name}/${file_name}.cpp"
  local gym_file="$HOME/CP/GYM/${dir_name}/${file_name}.cpp"
  local file=""

  if [[ -f "$contest_file" && -f "$gym_file" ]]; then
    echo "note: ${input} exists in both CONTESTS and GYM — using CONTESTS" >&2
    file="$contest_file"
  elif [[ -f "$contest_file" ]]; then
    file="$contest_file"
  elif [[ -f "$gym_file" ]]; then
    file="$gym_file"
  else
    echo "error: no file found for '${input}' in CP/CONTESTS or CP/GYM" >&2
    return 1
  fi

  local binary="./${file_name}"

  local -a cxxflags
  if ((is_sanitize)); then
    cxxflags=(-DLOCAL -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -std=c++17 -Wall -Wextra -Wshadow -Wconversion)
  elif ((is_debug)); then
    cxxflags=(-DLOCAL -D_GLIBCXX_DEBUG -O0 -g -std=c++17 -Wall -Wextra -Wshadow -Wconversion)
  else
    cxxflags=(-static -DONLINE_JUDGE -O2 -std=c++17 -Wall -Wextra -Wconversion)
  fi

  echo "compiling: ${file} -> ${binary}"
  g++ "${cxxflags[@]}" -o "$binary" "$file"

  if [[ $? -eq 0 ]]; then
    echo "ok: binary at ${binary}"
  else
    return 1
  fi
}
