#!/usr/bin/env bash
# BL-749 receipt. Usage: bash receipt-bl749.sh <validate-mutation-red.sh>
# Builds its own mktemp world and runs the given script on a GREEN, discriminating test whose
# argv carries tilde words, three ways: T (`~root`, `~+` and the mid-word `a~root`), X
# (`x=~root` and `FOO=a:~/b`, a `~` after `=` and after `:`), and D (`~root<TAB>z`, which %q
# renders in $'...' form). For each, the `$ ` line and the `test:` line are handed to `set --`
# in a child bash, which tilde-expands whatever the rendering left bare — parsed, never run
# as a command — and compared word for word against the argv passed. `~root` is used because
# root exists on every macOS and Linux box; a user that does not exist is never expanded.
# 0 = every case round-trips on both lines.
# 1 = a case does not round-trip (a FAIL line names the case and the line).
# 9 = the receipt could not run: no script, no world, `~root` does not expand on this box (so
#     nothing here could discriminate), a case did not exit 0, or printed no `test:` line.
set -uo pipefail
V="${1:-}"
[ -n "$V" ] && [ -f "$V" ] || { echo "REFUSED: usage: bash receipt-bl749.sh <validate-mutation-red.sh>" >&2; exit 9; }
[ "$(bash -c 'printf %s ~root')" != '~root' ] || { echo "REFUSED: ~root does not expand here, so a bare tilde would round-trip" >&2; exit 9; }
d="$(mktemp -d)" || exit 9
trap 'rm -rf "$d"' EXIT
printf '#!/usr/bin/env bash\nvalue() { printf %s; }\nvalue\n' "'42\\n'" > "$d/s.sh" || exit 9
printf '#!/usr/bin/env bash\n[ "$(bash "%s/s.sh")" = 42 ]\n' "$d" > "$d/t.sh" || exit 9
[ "$(bash "$d/s.sh")" = 42 ] && bash "$d/t.sh" || { echo "REFUSED: the seeded world is not GREEN" >&2; exit 9; }

split() { bash -c "set -- $1; printf '%s\037' \"\$@\"" 2>/dev/null; }
join()  { printf '%s\037' "$@"; }
fails=0
# check <case> <test-words...>: the test argv is `bash <t.sh> <test-words...>`.
check() {
  local c="$1" o rc first tl; shift
  local t=(bash "$d/t.sh" "$@")
  local all=("$d/s.sh" 2 'value() { printf 9; }' "${t[@]}")
  o="$(bash "$V" "${all[@]}" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "REFUSED: case $c: the script exited $rc" >&2; exit 9; }
  tl="$(sed -n 's/^  test://p' <<<"$o")"
  [ -n "$tl" ] || { echo "REFUSED: case $c: no test: line" >&2; exit 9; }
  first=""; IFS= read -r first <<<"$o"
  case "$first" in
    '$ '*) [ "$(split "${first#\$ }")" = "$(join "$V" "${all[@]}")" ] \
             || { echo "FAIL case $c: the \$ line does not replay to the argv: $first"; fails=$((fails + 1)); } ;;
    *)     echo "FAIL case $c: the first stdout line is not a \$ line: $first"; fails=$((fails + 1)) ;;
  esac
  [ "$(split "$tl")" = "$(join "${t[@]}")" ] \
    || { echo "FAIL case $c: the test: line does not replay to the test argv:$tl"; fails=$((fails + 1)); }
}
check T '~root' 'a~root' '~+'
check X 'x=~root' 'FOO=a:~/b'
check D $'~root\tz'
[ "$fails" -eq 0 ] || exit 1
exit 0
