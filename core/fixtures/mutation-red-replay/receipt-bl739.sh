#!/usr/bin/env bash
# BL-739 receipt. Usage: bash receipt-bl739.sh <validate-mutation-red.sh>
# Builds its own mktemp world and runs the given script four times: case A
# (`--syntax-check 'bash -n' -- <sut> 2 <repl> bash <test> -k 'a or b' one`) and case Q (a
# replacement holding single and double quotes). For each, the first stdout line must be a
# `$ ` line, and that line and the `test:` line are each handed to `set --` in a child bash —
# parsed, never run as a command — and compared word for word against the argv passed.
# Then case R: a pre-restore refusal (a test that is RED before any mutation) must exit 2 and
# print no `$ ` line, because nothing was mutated and there is no run to replay. And case H:
# a HARD refusal (the mutated run removes the target's directory, so the restore cannot
# verify and the tree is left mutated) must exit 3 and print no `$ ` line either.
# 0 = both cases round-trip: `$ ` is the script path as invoked plus the whole argv (flags and
#     `--` included), and `test:` is the test argv; case R exits 2 and case H exits 3, each
#     with no `$ ` line.
# 1 = a case does not round-trip, or case R or H printed a `$ ` line (a FAIL line names it).
# 9 = the receipt could not run: no script, no world, a round-trip case did not exit 0 or
#     printed no `test:` line, case R did not exit 2, or case H did not exit 3.
set -uo pipefail
V="${1:-}"
[ -n "$V" ] && [ -f "$V" ] || { echo "REFUSED: usage: bash receipt-bl739.sh <validate-mutation-red.sh>" >&2; exit 9; }
d="$(mktemp -d)" || exit 9
trap 'rm -rf "$d"' EXIT
printf '#!/usr/bin/env bash\nvalue() { printf %s; }\nvalue\n' "'42\\n'" > "$d/s.sh" || exit 9
printf '#!/usr/bin/env bash\n[ "$(bash "%s/s.sh")" = 42 ]\n' "$d" > "$d/t.sh" || exit 9
[ "$(bash "$d/s.sh")" = 42 ] && bash "$d/t.sh" || { echo "REFUSED: the seeded world is not GREEN" >&2; exit 9; }

split() { bash -c "set -- $1; printf '%s\037' \"\$@\"" 2>/dev/null; }
join()  { printf '%s\037' "$@"; }
fails=0
# check <case> <ntest> <args...>: the last <ntest> args are the test argv.
check() {
  local c="$1" nt="$2" o rc first tl; shift 2
  o="$(bash "$V" "$@" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "REFUSED: case $c: the script exited $rc" >&2; exit 9; }
  tl="$(sed -n 's/^  test://p' <<<"$o")"
  [ -n "$tl" ] || { echo "REFUSED: case $c: no test: line" >&2; exit 9; }
  first=""; IFS= read -r first <<<"$o"
  case "$first" in
    '$ '*) [ "$(split "${first#\$ }")" = "$(join "$V" "$@")" ] \
             || { echo "FAIL case $c: the \$ line does not replay to the argv: $first"; fails=$((fails + 1)); } ;;
    *)     echo "FAIL case $c: the first stdout line is not a \$ line: $first"; fails=$((fails + 1)) ;;
  esac
  local all=("$@"); local t=("${all[@]:$(( ${#all[@]} - nt ))}")
  [ "$(split "$tl")" = "$(join "${t[@]}")" ] \
    || { echo "FAIL case $c: the test: line does not replay to the test argv:$tl"; fails=$((fails + 1)); }
}
check A 5 --syntax-check 'bash -n' -- "$d/s.sh" 2 'value() { printf 9; }' bash "$d/t.sh" -k 'a or b' one
check Q 2 "$d/s.sh" 2 "x='it'\"'\"'s'" bash "$d/t.sh"
# refusal <case> <want-rc> <args...>: the run must exit <want-rc> and its stdout must carry
# no `$ ` line.
refusal() {
  local c="$1" want="$2" o rc; shift 2
  o="$(bash "$V" "$@" 2>/dev/null)"; rc=$?
  [ "$rc" -eq "$want" ] || { echo "REFUSED: case $c: the script exited $rc, not $want" >&2; exit 9; }
  if grep -q '^\$ ' <<<"$o"; then
    echo "FAIL case $c: a refusal printed a \$ line: $(grep -m 1 '^\$ ' <<<"$o")"; fails=$((fails + 1))
  fi
}
refusal R 2 "$d/s.sh" 2 'value() { printf 9; }' false
# Case H: a test that removes the target's directory on its SECOND run (the mutated one), so
# the restore has nowhere to write. Seeded inside $d, with TMPDIR=$d/h/tmp so the script's
# backup, logs and mutant land there too: nothing mutated is left outside $d.
mkdir -p "$d/h/hard" "$d/h/tmp" && cp "$d/s.sh" "$d/h/hard/s.sh" && printf '0\n' > "$d/h/count" || exit 9
printf '#!/usr/bin/env bash\nn=$(( $(cat "%s/h/count") + 1 ))\nprintf "%%s\\n" "$n" > "%s/h/count"\n[ "$n" -ge 2 ] && rm -rf "%s/h/hard"\nexit 0\n' "$d" "$d" "$d" > "$d/h/t.sh" || exit 9
export TMPDIR="$d/h/tmp"
refusal H 3 "$d/h/hard/s.sh" 2 'value() { printf 9; }' bash "$d/h/t.sh"
[ "$fails" -eq 0 ] || exit 1
exit 0
