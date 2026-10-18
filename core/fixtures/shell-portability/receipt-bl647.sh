#!/usr/bin/env bash
# Receipt for the S13 arm (command substitution bash 3.2 closes early). Exit 0 only when, in a
# throwaway repo, the validator reports S13 on each failing form (a), (b), (c-in-argument-context)
# and stays silent on each paired passing form, including (c) in assignment context.
# VALIDATOR=<path> scores a mutated copy instead of the shipped script.
# Scored against: the fix (0); S13 dropped from ARMS (non-zero); the (c) rule reverted to the
# entry's prose rule (non-zero); and a SECOND CORRECT SPELLING, the shipped validator with S13's
# awk program read from a file instead of the inline literal (0). The seeds cover nested forms,
# because a `set -n` oracle inside the outer `$(` once hid them.
# Run from the repo root: bash core/fixtures/shell-portability/receipt-bl647.sh
set -uo pipefail
V="${VALIDATOR:-scripts/validate-shell-portability.sh}"
[ -f "$V" ] || { echo "receipt: no validator at $V" >&2; exit 2; }
V="$(cd "$(dirname "$V")" && pwd)/$(basename "$V")"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/scripts" "$T/core/skills" "$T/core/fixtures/u"
echo 0.0.0 > "$T/VERSION"
cp "$V" "$T/scripts/validate-shell-portability.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo clean' > "$T/scripts/clean.sh"
printf '%s\n' '# clean' > "$T/core/skills/clean.md"
printf '%s\n' '#!/usr/bin/env bash' 'cd "$W" || exit 2' > "$T/core/fixtures/u/seed.sh"
run() { # run <body-file> -> prints FLAG or ok
  cp "$1" "$T/scripts/subject.sh"
  ( cd "$T" && git init -q . 2>/dev/null; git add -A >/dev/null 2>&1
    bash scripts/validate-shell-portability.sh 2>&1 </dev/null ) > "$T/out" || true
  if grep -q '^FAIL: S13:' "$T/out"; then echo FLAG; else echo ok; fi
}
body() { printf '%s\n' '#!/usr/bin/env bash' "$@" > "$T/body"; }
bad=0
expect() { # expect <label> <FLAG|ok>
  local got; got="$(run "$T/body")"
  if [ "$got" = "$2" ]; then echo "ok    $1 -> $got"; else echo "FAIL  $1 -> $got, wanted $2"; bad=1; fi
}
body 'x="$(' "  # the scorer's own subshell (bash -c's PPID) is excluded" '  echo "1 0"' ')"'
expect "form (a) apostrophe comment" FLAG
body 'x="$(' "  # the scorer own subshell, 'a pair' is excluded" '  echo "1 0"' ')"'
expect "form (a) balanced pair" ok
body 'x="$(echo "$(' "  # a lone ) here" '  echo "1 0"' ')")"'
expect "form (a) nested lone paren" FLAG
body 'x="$(' "  case \"\$h\" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac" '  echo "$k"' ')"'
expect "form (b) bare case pattern" FLAG
body 'x="$(echo "$(' "  case \"\$h\" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac" '  echo "$k"' ')")"'
expect "form (b) nested bare case pattern" FLAG
body 'x="$(' "  case \"\$h\" in (''|*[!0-9]*) k=x ;; (*) k=1 ;; esac" '  echo "$k"' ')"'
expect "form (b) leading-paren pattern" ok
body 'if true; then' '  amutant_arm a "$(amut n '"'"'x "$(p"){y} 1'"'"')" z' 'fi'
expect "form (c) argument context" FLAG
body 'if true; then' '  f a "$(amut n '"'"'x "$(p" {y} 1'"'"')" z' 'fi'
expect "form (c) no later ) (the prose rule misses it, bash breaks it)" FLAG
body 'if true; then' '  for x in "$(amut n '"'"'x "$(p"){y} 1'"'"')"; do :; done' 'fi'
expect "form (c) for list" FLAG
body 'if true; then' '  v="$(amut n '"'"'x "$(p"){y} 1'"'"')"' 'fi'
expect "form (c) assignment context" ok
body 'if true; then' '  [[ -n "$(amut n '"'"'x "$(p"){y} 1'"'"')" ]] && :' 'fi'
expect "form (c) [[ ]] operand" ok
body 'if true; then' '  amutant_arm a "$(amut n '"'"'x $(p){y} 1'"'"')" z' '  amutant_arm a "$(amut n '"'"'a "$(printf" b'"'"')" z' 'fi'
expect "form (c) balanced and unclosed spellings" ok
exit "$bad"
