#!/usr/bin/env bash
# BL-809 receipt (item 3, the shipped part: arm (m) K-UNQUOTED refuses, arm (n) PLACEHOLDER and arm (q)
# AC-CITATION-UNRESOLVED warn). Usage:
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
# Arm (q) AC-CITATION-UNRESOLVED, story 1's `## Strategy Test IDs` table, one row per input shape. A q-cell is
# `q` when a `WARN ac-citation-unresolved stories/story-1.md: Q-<cell> case` line names its row, else `-`:
#   qoff     test row, bare leading `tests/test_qoff.py::test_x`, never committed       -> q (not tracked)
#   qtrk     test row, backticked `tests/test_t.py::test_x` and `tests/test_t.py:12`, tracked -> -  (one token: the :line twin of qln)
#   qkind    the qoff row with Kind `predicate`, `tests/test_pred.py::test_x` untracked -> -  (test rows only)
#   The decoy rows below lead with `see`, a word with no extension, so the leading word is never a path
#   and a mutant that judges every path (path-always) trips only qtrk, the one row whose citation is tracked.
#   qbare    bare basename `bm-ev.evidence.md`, tracked as evidence/bm-ev.evidence.md   -> -  (basename rule)
#   qbareoff bare basename `bm-gone.evidence.md`, tracked nowhere                       -> q (basename)
#   qext     bare `result.tx_hashes`, an extension no tracked file carries              -> -  (not a path)
#   qcap     untracked capture `test-results/bm-qcap.txt`                               -> -  and WARN capture-unresolved
#   qabs     absolute `/api/v1/pools.json`, outside the toplevel                        -> -  (not read)
#   qabsin   absolute `<physical toplevel>/tests/test_qabsin.py::test_x`, untracked    -> q (judged under the toplevel)
#   Worktree cells: two worktrees of the receipt repository registered INSIDE the toplevel, the Claude Code
#   layout, `.claude/worktrees/wtf` detached at <frozen> and `.claude/worktrees/wtb` detached at <base>:
#   qwt      `<top>/.claude/worktrees/wtf/tests/test_t.py`, tracked at <frozen>          -> -  (judged by its worktree-relative rest)
#   qwtf     `<top>/.claude/worktrees/wtf/tests/test_qwtf.py`, untracked                 -> q (judged by its worktree-relative rest)
#   qwtb     `<top>/.claude/worktrees/wtb/tests/test_qwtb.py`, HEAD is not <frozen>      -> -  (not read)
#   qwtun    `<top>/.claude/worktrees/zz/tests/test_t.py`, no worktree registered there  -> q (no special case: rest .claude/worktrees/zz/...)
#   qemp     an EMPTY Case cell, `tests/test_qemp.py` untracked                          -> q, printed as `case -`
#   qel      elided `tests/.../test_el.py`                                              -> -  (not read)
#   qtel     trailing elision `tests/test_tel.py...`                                    -> -  (not read: elision tested before the strip)
#   qglob    glob `tests/test_glob*.py`                                                 -> -  (not read)
#   qdot     `../outside/test_dot.py::test_x`                                           -> q (outside the repository)
#   qdel     `tests/test_del.py::test_x`, tracked at base and deleted in range          -> q (no deleted-in-range acquittal)
#   qign     `ignored/test_ign.py::test_x`, on disk and ignored by the frozen .gitignore -> q (no .gitignore acquittal)
#   qnl      unbackticked non-leading `see tests/test_qnl.py::test_x`, untracked       -> -  (acquitted, the header says so)
#   qln      `tests/test_qln.py:12`, untracked                                          -> q (the :line cut)
#   qac      an `| AC | Kind | Status | Evidence |` table in the section, untracked path -> -  (not this population)
#   qsec     a strategy table under a later `## Notes` heading, untracked path         -> -  (the section ended)
#   qlvl     the qoff line is a WARN and no REFUSED ac-citation-unresolved line exists
#   qrc      story-3, no refusal, one untracked `test`-row citation                     -> exit 0 with the (q) WARN
# Every q-cell but qlvl and qrc matches its line at ANY level, so only qlvl owns the tier.
# 0 = every cell answered as above. 1 = a cell did not (one `FAIL <cell>` line each). 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ -f "$1" ] \
  || { echo "REFUSED: usage: bash receipt-bl809.sh <path to validate-handoff-evidence.sh> [<cells>]" >&2; exit 9; }
HE="$1"; CELLS="${2:-}"
# With <cells> only story-1's run (every cell but rc and qrc, and the ctl cell), for rc story-2's run and for qrc
# story-3's: a mutant run names the one cell that decides it. Without it every cell runs.
want() { [ -z "$CELLS" ] && return 0; case " $CELLS " in *" $1 "*) return 0 ;; esac; return 1; }
# ran <cell>: printed inside each want-gated block, once per cell whose assertion that block evaluates.
ran() { echo "RAN $1"; }
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
mkdir -p "$W/stories" "$W/test-results" "$W/tests" "$W/evidence" "$W/ignored" || exit 9
g init -q || exit 9
# qabsin spells the PHYSICAL toplevel, which the validator compares lexically; a path outside (q)'s token
# charset could never be read, so the cell could not fire: refuse to run rather than pass vacuously.
WP="$(cd -P "$W" && pwd -P)" || exit 9
case "$WP" in *[!A-Za-z0-9_./-]*) echo "REFUSED: the scratch toplevel $WP carries a character outside (q)'s token charset" >&2; exit 9 ;; esac
printf 'def test_x():\n    pass\n' > "$W/tests/test_t.py"
printf 'def test_x():\n    pass\n' > "$W/tests/test_del.py"
printf 'evidence\n' > "$W/evidence/bm-ev.evidence.md"
printf 'ignored/\n' > "$W/.gitignore"
LABELS='Full-collection run: `pytest -q` from the root, 1 passed.
Dependency setup: none, system pytest.'
printf -- '---\nstatus: review\n---\n# Story 1\n\n%s\n' "$LABELS" > "$W/stories/story-1.md"
cp "$W/stories/story-1.md" "$W/stories/story-2.md"
cp "$W/stories/story-1.md" "$W/stories/story-3.md"
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
  printf '\n## Strategy Test IDs\n\n| Strategy id | Case | Kind | Resolves to |\n|---|---|---|---|\n'
  # The `| - |` row is a data row whose first cell is a dash and no separator: it must not rebind the
  # header, or every row after it goes unread.
  printf '%s\n' '| Q-qoff | - | test | tests/test_qoff.py::test_x |' \
    '| - | - | test | see |' \
    '| Q-qtrk | - | test | `tests/test_t.py::test_x` `tests/test_t.py:12` |' \
    '| Q-qkind | - | predicate | tests/test_pred.py::test_x |' \
    '| Q-qbare | - | test | see (capture: `bm-ev.evidence.md`) |' \
    '| Q-qbareoff | - | test | see (capture: `bm-gone.evidence.md`) |' \
    '| Q-qext | - | test | see (asserts `result.tx_hashes`) |' \
    '| Q-qcap | - | test | see (capture: `test-results/bm-qcap.txt`) |' \
    '| Q-qabs | - | test | see (route `/api/v1/pools.json`) |' \
    '| Q-qel | - | test | see (`tests/.../test_el.py`) |' \
    '| Q-qtel | - | test | see `tests/test_tel.py...` |' \
    '| Q-qglob | - | test | see (`tests/test_glob*.py`) |' \
    '| Q-qdot | - | test | `../outside/test_dot.py::test_x` |' \
    '| Q-qdel | - | test | `tests/test_del.py::test_x` |' \
    '| Q-qign | - | test | `ignored/test_ign.py::test_x` |' \
    '| Q-qnl | - | test | see tests/test_qnl.py::test_x |' \
    '| Q-qln | - | test | `tests/test_qln.py:12` |'
  printf '| Q-qabsin | - | test | `%s/tests/test_qabsin.py::test_x` |\n' "$WP"
  printf '| Q-qwt | - | test | `%s/.claude/worktrees/wtf/tests/test_t.py::test_x` |\n' "$WP"
  printf '| Q-qwtf | - | test | `%s/.claude/worktrees/wtf/tests/test_qwtf.py::test_x` |\n' "$WP"
  printf '| Q-qwtb | - | test | `%s/.claude/worktrees/wtb/tests/test_qwtb.py::test_x` |\n' "$WP"
  printf '| Q-qwtun | - | test | `%s/.claude/worktrees/zz/tests/test_t.py::test_x` |\n' "$WP"
  printf '%s\n' '| Q-qemp |  | test | `tests/test_qemp.py` |'
  # qac: an AC-keyed table inside the section; its third cell is `test`, so a reader that keeps the strategy
  # header bound past this table reads the row. qsec: a strategy table under a later `## ` heading.
  printf '\n| AC | Kind | Status | Evidence |\n|---|---|---|---|\n| Q-qac | - | test | `tests/test_qac.py` |\n'
  printf '\n## Notes\n\n| Strategy id | Case | Kind | Resolves to |\n|---|---|---|---|\n| Q-qsec | - | test | `tests/test_qsec.py` |\n'
} > "$W/stories/story-1.md"
g rm -q tests/test_del.py || exit 9
printf 'def test_x():\n    pass\n' > "$W/ignored/test_ign.py"
printf -- '---\nstatus: review\n---\n# Story 2\n\n%s\n\n## Dev Agent Record\n\nLint: `test-results/bm-ph.txt`.\n' "$LABELS" > "$W/stories/story-2.md"
# story-3: no refusal and no other finding, one untracked `test`-row citation (cell qrc, the exit-neutral claim).
{ printf -- '---\nstatus: review\n---\n# Story 3\n\n%s\n\n## Dev Agent Record\n\n- k1: `test-results/bm-k1.txt`\n' "$LABELS"
  printf '\n## Strategy Test IDs\n\n| Strategy id | Case | Kind | Resolves to |\n|---|---|---|---|\n'
  printf '%s\n' '| Q-qrc | - | test | `tests/test_qrc.py::test_x` |'
} > "$W/stories/story-3.md"
g add -A && g commit -qm frozen || exit 9
T="$(g rev-parse HEAD)"
# The worktree cells' two registered worktrees, nested in the toplevel as Claude Code nests them.
g worktree add -q --detach "$WP/.claude/worktrees/wtf" "$T" && g worktree add -q --detach "$WP/.claude/worktrees/wtb" "$B" || exit 9
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
qcell() { # <name> <want q|-> [<reason the q line must carry>]
  local l got=-
  # Level-agnostic: a REFUSED line names the row too, so only qlvl owns the tier.
  l="$(grep -F "ac-citation-unresolved stories/story-1.md: Q-$1 case " <<<"$o")"
  [ -z "$l" ] || got=q
  [ "$got" = q ] && [ -n "${3:-}" ] && ! grep -qF -- "$3" <<<"$l" && got="q-without-[$3]"
  [ "$got" = "$2" ] || { echo "FAIL $1: want [$2] got [$got]"; fails=$((fails + 1)); }
}
qcell qoff q 'cites tests/test_qoff.py, and tests/test_qoff.py is not tracked at'
qcell qtrk -
qcell qkind -
qcell qbare -
qcell qbareoff q 'cites bm-gone.evidence.md, and no path tracked at'
qcell qext -
qcell qcap -
grep -q '^WARN capture-unresolved test-results/bm-qcap.txt: not tracked at ' <<<"$o" \
  || { echo "FAIL qcap: want WARN capture-unresolved for test-results/bm-qcap.txt"; fails=$((fails + 1)); }
qcell qabs -
qcell qel -
qcell qtel -
qcell qglob -
qcell qdot q 'cites ../outside/test_dot.py, and resolves outside the repository'
qcell qdel q 'tests/test_del.py is not tracked at'
qcell qign q 'ignored/test_ign.py is not tracked at'
qcell qnl -
qcell qln q 'cites tests/test_qln.py, and tests/test_qln.py is not tracked at'
qcell qabsin q '/tests/test_qabsin.py, and tests/test_qabsin.py is not tracked at'
qcell qwt -
qcell qwtf q '/.claude/worktrees/wtf/tests/test_qwtf.py, and tests/test_qwtf.py is not tracked at'
qcell qwtb -
qcell qwtun q '/.claude/worktrees/zz/tests/test_t.py, and .claude/worktrees/zz/tests/test_t.py is not tracked at'
qcell qemp q 'case - (test) cites tests/test_qemp.py, and tests/test_qemp.py is not tracked at'
qcell qac -
qcell qsec -
{ grep -q '^WARN ac-citation-unresolved stories/story-1.md: Q-qoff case - (test) cites ' <<<"$o" \
  && ! grep -q '^REFUSED ac-citation-unresolved' <<<"$o"; } \
  || { echo "FAIL qlvl: want the qoff ac-citation-unresolved line as a WARN and no REFUSED one"; fails=$((fails + 1)); }
if want rc; then
ran rc
o2="$(he_run "$HE" -C "$W" stories/story-2.md "$B" "$T" 2>/dev/null)"; rc=$?
{ [ "$rc" -eq 0 ] && grep -q '^WARN placeholder test-results/bm-ph.txt: ' <<<"$o2"; } \
  || { echo "FAIL rc: want exit 0 with the placeholder WARN, got exit $rc"; fails=$((fails + 1)); }
fi
if want qrc; then
ran qrc
o3="$(he_run "$HE" -C "$W" stories/story-3.md "$B" "$T" 2>/dev/null)"; rc3=$?
{ [ "$rc3" -eq 0 ] && grep -q '^WARN ac-citation-unresolved stories/story-3.md: Q-qrc case - (test) cites tests/test_qrc.py, and tests/test_qrc.py is not tracked at ' <<<"$o3"; } \
  || { echo "FAIL qrc: want exit 0 with the (q) WARN on story-3, got exit $rc3"; fails=$((fails + 1)); }
fi
[ "$fails" -eq 0 ] || exit 1
exit 0
