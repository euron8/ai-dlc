#!/usr/bin/env bash
# BL-809 receipt (item 3, the shipped part: arm (m) K-UNQUOTED refuses, arm (n) PLACEHOLDER warns). Usage:
#   bash receipt-bl809.sh <path to validate-handoff-evidence.sh>
# Drives the validator over one scratch repository. Every capture below is in range, tracked, and carries
# a `$ ` command line and a `head:` line, so only (m) and (n) can name it. A cell is the sorted set of
# finding KINDS (k-unquoted, placeholder, no-command) on REFUSED/WARN lines naming that capture.
#   kunq   `$ pytest -k alpha or beta tests/t.py`         -> k-unquoted
#   kq     `$ pytest -k "alpha or beta" tests/t.py`       -> -  (quoted: the shell keeps one argument)
#   kq1    `$ pytest -k 'alpha and beta' tests/t.py`      -> -  (single-quoted)
#   k1     `$ pytest -k alpha tests/t.py`                 -> -  (single word)
#   ph     `$ npm --prefix <tree>/web run lint`           -> placeholder
#   red    `$ curl -H 'Authorization: <redacted>' ...`    -> -  (exempt)
#   bw     `$ npm --prefix <base-worktree>/web run lint`  -> -  (exempt)
#   ctl    a capture with no command line                 -> no-command (the unchanged control)
#   rc     a second story citing only `ph`, labels present -> exit 0 with the placeholder WARN
#   lvl    the `ph` line in story 1 is a WARN, the `kunq` line a REFUSED
# 0 = every cell answered as above. 1 = a cell did not (one `FAIL <cell>` line each). 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ -f "$1" ] \
  || { echo "REFUSED: usage: bash receipt-bl809.sh <path to validate-handoff-evidence.sh> [<cells>]" >&2; exit 9; }
HE="$1"; CELLS="${2:-}"
# With <cells> only story-1's run (every cell but rc, and the ctl cell) and, for rc, story-2's run: a mutant run
# names the one cell that decides it. Without it every cell runs.
want() { [ -z "$CELLS" ] || case " $CELLS " in *" $1 "*) return 0 ;; esac; return 1; }
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/he-inproc.sh" || { echo "REFUSED: he-inproc.sh is not beside this receipt" >&2; exit 9; }
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
# With RCPT_WORLD set (run.sh's rcpt_run), the world is seeded ONCE into that directory and every later call
# reads it (no call writes into it: the validator reads its repository and writes only under its own mktemp).
if [ -n "${RCPT_WORLD:-}" ]; then
  R="$RCPT_WORLD"; mkdir -p "$R" || exit 9
else
  R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl809.XXXXXX")" || exit 9
  trap 'rm -rf "$R"' EXIT
fi
W="$R/w"
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
if [ -f "$R/.seeded" ]; then
  B="$(cat "$R/.B")"; T="$(cat "$R/.T")"
else
mkdir -p "$W/stories" "$W/test-results" || exit 9
g init -q || exit 9
LABELS='Full-collection run: `pytest -q` from the root, 1 passed.
Dependency setup: none, system pytest.'
printf -- '---\nstatus: review\n---\n# Story 1\n\n%s\n' "$LABELS" > "$W/stories/story-1.md"
cp "$W/stories/story-1.md" "$W/stories/story-2.md"
g add -A && g commit -qm base || exit 9
B="$(g rev-parse HEAD)"
cap() { printf '$ %s\nhead: %s\n1 passed\n' "$2" "$B" > "$W/test-results/bm-$1.txt"; }
cap kunq "pytest -k alpha or beta tests/t.py"
cap kq   'pytest -k "alpha or beta" tests/t.py'
cap kq1  "pytest -k 'alpha and beta' tests/t.py"
cap k1   "pytest -k alpha tests/t.py"
cap ph   "npm --prefix <tree>/web run lint"
cap red  "curl -H 'Authorization: <redacted>' https://example.invalid/api"
cap bw   "npm --prefix <base-worktree>/web run lint"
printf 'no command line here\n1 passed\n' > "$W/test-results/bm-ctl.txt"
{ printf -- '---\nstatus: review\n---\n# Story 1\n\n%s\n\n## Dev Agent Record\n\n' "$LABELS"
  for n in kunq kq kq1 k1 ph red bw ctl; do printf -- '- %s: `test-results/bm-%s.txt`\n' "$n" "$n"; done
} > "$W/stories/story-1.md"
printf -- '---\nstatus: review\n---\n# Story 2\n\n%s\n\nLint: `test-results/bm-ph.txt`.\n' "$LABELS" > "$W/stories/story-2.md"
g add -A && g commit -qm frozen || exit 9
T="$(g rev-parse HEAD)"
printf '%s\n' "$B" > "$R/.B" && printf '%s\n' "$T" > "$R/.T" && : > "$R/.seeded" || exit 9
fi
o="$(he_run "$HE" -C "$W" stories/story-1.md "$B" "$T" 2>/dev/null)"
[ -n "$o" ] || { echo "REFUSED: the validator printed nothing for story-1" >&2; exit 9; }
fails=0
cell() { # <name> <want>
  local got t="test-results/bm-$1.txt"
  got="$(awk -v t="$t" '($1 == "REFUSED" || $1 == "WARN") && index($0, " " t ":") && ($2 == "k-unquoted" || $2 == "placeholder" || $2 == "no-command") {print $2}' <<<"$o" | sort | tr '\n' ',')"
  got="${got%,}"; [ -n "$got" ] || got=-
  [ "$got" = "$2" ] || { echo "FAIL $1: want [$2] got [$got]"; fails=$((fails + 1)); }
}
cell kunq k-unquoted
cell kq   -
cell kq1  -
cell k1   -
cell ph   placeholder
cell red  -
cell bw   -
cell ctl  no-command
{ grep -q '^REFUSED k-unquoted test-results/bm-kunq.txt: ' <<<"$o" \
  && grep -q '^WARN placeholder test-results/bm-ph.txt: line 1 carries <tree>' <<<"$o"; } \
  || { echo "FAIL lvl: want k-unquoted REFUSED and placeholder WARN naming <tree>"; fails=$((fails + 1)); }
if want rc; then
o2="$(he_run "$HE" -C "$W" stories/story-2.md "$B" "$T" 2>/dev/null)"; rc=$?
{ [ "$rc" -eq 0 ] && grep -q '^WARN placeholder test-results/bm-ph.txt: ' <<<"$o2"; } \
  || { echo "FAIL rc: want exit 0 with the placeholder WARN, got exit $rc"; fails=$((fails + 1)); }
fi
[ "$fails" -eq 0 ] || exit 1
exit 0
