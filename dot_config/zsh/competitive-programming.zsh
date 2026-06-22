#!/bin/zsh

# for CP :)
problem() {
  if [[ -z "$1" ]]; then
    echo "usage: problem <id>  (e.g. problem 1a)" >&2
    return 1
  fi

  local input="${1}"

  if [[ ! "$input" =~ '^[0-9]+[a-zA-Z0-9]*$' ]]; then
    echo "error: input must match [int][alphanum] (e.g. 1a, 42b3)" >&2
    return 1
  fi

  local dir_name="${input:u}"
  local file_name="${input:l}"
  local dir="$HOME/CP/${dir_name}"
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
typedef pair<int,int> pii;
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
  while (t--) solve();
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

cpcomp() {
  # feat: compile CP problem by ID, emit binary in cwd

  if [[ -z "$1" ]]; then
    echo "usage: cpcomp <id>  (e.g. cpcomp 1a)" >&2
    return 1
  fi

  local input="${1}"

  if [[ ! "$input" =~ '^[0-9]+[a-zA-Z0-9]*$' ]]; then
    echo "error: input must match [int][alphanum]" >&2
    return 1
  fi

  local dir_name="${input:u}"
  local file_name="${input:l}"
  local file="$HOME/CP/${dir_name}/${file_name}.cpp"
  local binary="./${file_name}"

  if [[ ! -f "$file" ]]; then
    echo "error: no file found at ${file}" >&2
    return 1
  fi

  echo "compiling: ${file} -> ${binary}"
  g++ -O2 -std=c++17 -Wall -Wextra -o "$binary" "$file"

  if [[ $? -eq 0 ]]; then
    echo "ok: binary at ${binary}"
  else
    return 1
  fi
}
