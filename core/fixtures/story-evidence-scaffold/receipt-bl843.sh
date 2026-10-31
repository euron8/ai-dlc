#!/usr/bin/env bash
# BL-843 receipt: the capture-heads block (--render-dar, --check, and its fold into handoff mode). Usage:
#   bash receipt-bl843.sh <path to validate-handoff-evidence.sh> [<cells>]
# With <cells> (space-separated cell names), only those cells and the `ctl` control run: a mutant run
# names the one cell that decides it. Without it every cell runs.
# Drives the validator over two scratch repositories. W carries an ENGINE file at
# core/scripts/validate-handoff-evidence.sh whose history gives the legacy epoch (VADD): c0 adds a
# stub without the flag and the legacy story, c1 adds the flag (VADD, and <base>), X adds every other
# story and capture plus a test-file edit (so the range is not record-only), and T pastes the blocks
# rendered at X. W2 commits no engine at all (the undecidable epoch).
#   ctl     a story citing no capture: render is the two marker lines, --check 0
#   r1      the block rendered at X pasted verbatim: --check 0; handoff exit 0, no dar-heads line
#   r2      that block with ONE head retyped wrong (path and command kept): --check REFUSED dar-heads-stale, exit 1
#   r2h     the same story in handoff mode: REFUSED dar-heads-stale
#   r3      captures cited, no block, the DAR retypes a head, story added after VADD: REFUSED dar-heads-missing
#   r4      the legacy story (added before VADD), no block: WARN dar-heads-missing (legacy), exit 0, no REFUSED dar-heads
#   und     W2, no engine committed: WARN dar-heads-missing (undecidable), no REFUSED dar-heads
#   r5      two blocks: REFUSED dar-heads-duplicate
#   r6      a replay capture whose header carries a `head:` above the replay block and the block's own:
#           the render names the block's own head (the base), never the one above it
#   r7      a capture whose command names a second TRACKED `.log`: pasted, --check 0 (the block's own
#           backticked paths are not citations)
#   r8      a capture cited ONLY inside a block: --list-captures prints nothing for that story
#   r9      `head: <sha> (+dirty)` renders `head `<sha> (+dirty)``
#   esc     a command holding a backtick renders inside a double-backtick span
#   cmd     a capture whose first line is `mutation-red replay` and whose `$ ` line comes later renders
#           `mutation-red replay`, (a)'s reader, not the first `$ ` line
#   d3      the full-collection capture renders its LAST count line; the RED capture's `1 failed` renders none
#   cnt     `Full-collection run: <capture>, counts: capture-heads block` with a fresh block: no full-collection-none
#   cntnb   the same value with no block: REFUSED full-collection-none
#   cntpl   the capture path alone with a fresh block: REFUSED full-collection-none
#   rp      `Full-collection run: <replay capture>, counts: capture-heads block` with a fresh block, on a
#           range touching a test: the render gives the replay capture no count, REFUSED full-collection-none
#   trim    a capture whose `$ ` line carries trailing blanks: the rendered command is trimmed, and
#           --check on the render pasted with trailing blanks stripped (as an editor saves it) exits 0
# 0 = every cell answered as above. 1 = a cell did not (one `FAIL <cell>` line each). 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ -f "$1" ] \
  || { echo "REFUSED: usage: bash receipt-bl843.sh <path to validate-handoff-evidence.sh> [<cells>]" >&2; exit 9; }
HE="$1"; CELLS="${2:-}"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/he-inproc.sh" || { echo "REFUSED: he-inproc.sh is not beside this receipt" >&2; exit 9; }
want() { [ -z "$CELLS" ] || case " ctl $CELLS " in *" $1 "*) return 0 ;; esac; return 1; }
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
# With RCPT_WORLD set (run.sh's rcpt_run), the worlds are seeded ONCE into that directory and every later call
# reads them (no call writes into them: the validator reads its repository and writes only under its own mktemp).
if [ -n "${RCPT_WORLD:-}" ]; then
  R="$RCPT_WORLD"; mkdir -p "$R" || exit 9
else
  R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl843.XXXXXX")" || exit 9
  trap 'rm -rf "$R"' EXIT
fi
W="$R/w"; W2="$R/w2"
gw() { local d="$1"; shift; GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$d" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
LABELS='Dependency setup: none, system pytest.'
hdr() { printf -- '---\nstatus: review\n---\n# %s\n\n%s\n' "$1" "$LABELS"; }
blk() { he_run "$HE" -C "$W" --render-dar "stories/$1" "$X" 2>/dev/null; }
if [ -f "$R/.seeded" ]; then
  B="$(cat "$R/.B")"; P="$(cat "$R/.P")"; X="$(cat "$R/.X")"; T="$(cat "$R/.T")"; U="$(cat "$R/.U")"
else
mkdir -p "$W/stories" "$W/test-results" "$W/tests" "$W/core/scripts" || exit 9
gw "$W" init -q || exit 9
printf 'class TestA:\n    def test_a(self):\n        assert True\n' > "$W/tests/test_x.py"
printf '# engine stub, before the render mode\n' > "$W/core/scripts/validate-handoff-evidence.sh"
{ hdr "Legacy"; printf 'Full-collection run: `pytest -q` from the root, 1 passed.\n\n## Dev Agent Record\n\nRun: `test-results/leg.txt`.\n'; } > "$W/stories/legacy.md"
printf '$ pytest -q\nhead: 0000000\n1 passed\n' > "$W/test-results/leg.txt"
gw "$W" add -A && gw "$W" commit -qm c0 || exit 9
printf '# engine stub\n# --render-dar\n' > "$W/core/scripts/validate-handoff-evidence.sh"
gw "$W" add -A && gw "$W" commit -qm c1-vadd || exit 9
B="$(gw "$W" rev-parse HEAD)"
P="$(gw "$W" rev-parse HEAD~1)"
printf 'class TestA:\n    def test_a(self):\n        assert 1 == 1\n' > "$W/tests/test_x.py"
printf '$ pytest -q\nhead: %s\nwarmup: 1 passed\n3 passed, 1 skipped in 0.20s\n' "$B" > "$W/test-results/full.txt"
printf 'head: %s\n$ scripts/ai-dlc/validate-mutation-red.sh x.py 1 y pytest\nmutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\n1 failed\n' "$P" "$B" > "$W/test-results/red.txt"
printf '$ pytest -q tests\nhead: %s (+dirty)\n1 passed\n' "$B" > "$W/test-results/dirty.txt"
printf '$ echo `date` done\nhead: %s\n' "$B" > "$W/test-results/esc.txt"
printf 'mutation-red replay\n  head:       %s\n$ pytest -q\n' "$B" > "$W/test-results/cmdfirst.txt"
printf '$ pytest -q --log-file=test-results/other.log\nhead: %s\n1 passed\n' "$B" > "$W/test-results/r7.txt"
printf 'log\n' > "$W/test-results/other.log"
printf '$ pytest -q\nhead: %s\n1 passed\n' "$B" > "$W/test-results/only.txt"
printf '$ pytest -q tests   \nhead: %s\n' "$B" > "$W/test-results/trim.txt"
FCRUN='Full-collection run: `pytest -q` from the root, 3 passed, capture `test-results/full.txt`.'
OKDAR='## Dev Agent Record

Full run `test-results/full.txt`; Mutation-RED capture `test-results/red.txt`; dirty `test-results/dirty.txt`;
escape `test-results/esc.txt`; replay-first `test-results/cmdfirst.txt`.'
{ hdr "OK"; printf '%s\n\n%s\n' "$FCRUN" "$OKDAR"; } > "$W/stories/s-ok.md"
cp "$W/stories/s-ok.md" "$W/stories/s-stale.md"; cp "$W/stories/s-ok.md" "$W/stories/s-dup.md"
{ hdr "Miss"; printf '%s\n\n%s\nCaptured at head %s.\n' "$FCRUN" "$OKDAR" "$B"; } > "$W/stories/s-miss.md"
{ hdr "R7"; printf 'Full-collection run: `pytest -q` from the root, 1 passed.\n\nRun: `test-results/r7.txt`.\n'; } > "$W/stories/s-r7.md"
{ hdr "R8"; printf 'Full-collection run: `pytest -q` from the root, 1 passed.\n'; } > "$W/stories/s-r8.md"
{ hdr "None"; printf 'Full-collection run: `pytest -q` from the root, 1 passed.\n'; } > "$W/stories/s-none.md"
{ hdr "Cnt"; printf 'Full-collection run: `test-results/full.txt`, counts: capture-heads block\n'; } > "$W/stories/s-cnt.md"
cp "$W/stories/s-cnt.md" "$W/stories/s-cntnb.md"
{ hdr "CntPl"; printf 'Full-collection run: `test-results/full.txt`\n'; } > "$W/stories/s-cntpl.md"
{ hdr "Rp"; printf 'Full-collection run: `test-results/red.txt`, counts: capture-heads block\n'; } > "$W/stories/s-rp.md"
{ hdr "Trim"; printf 'Full-collection run: `pytest -q` from the root, 1 passed.\n\nRun: `test-results/trim.txt`.\n'; } > "$W/stories/s-trim.md"
gw "$W" add -A && gw "$W" add -f test-results && gw "$W" commit -qm x || exit 9
X="$(gw "$W" rev-parse HEAD)"
for s in s-ok s-r7 s-cnt s-cntpl s-rp s-trim; do
  b="$(blk "$s.md")" && [ -n "$b" ] || { echo "REFUSED: the render printed nothing for $s" >&2; exit 9; }
  # s-trim is pasted as an editor saves it, trailing blanks stripped.
  [ "$s" != s-trim ] || b="$(sed 's/[[:space:]]*$//' <<<"$b")"
  printf '\n%s\n' "$b" >> "$W/stories/$s.md"
done
b="$(blk s-ok.md)"
printf '\n%s\n' "$(HB="head \`$B\`" HP="head \`$P\`" awk 'index($0, "- `test-results/full.txt` ") == 1 && (p = index($0, ENVIRON["HB"])) { $0 = substr($0, 1, p - 1) ENVIRON["HP"] substr($0, p + length(ENVIRON["HB"])) } {print}' <<<"$b")" >> "$W/stories/s-stale.md"
printf '\n%s\n\n%s\n' "$b" "$b" >> "$W/stories/s-dup.md"
printf '\n<!-- capture-heads: generated by validate-handoff-evidence.sh --render-dar; do not edit -->\n- `test-results/only.txt` — head `%s` — `$ pytest -q`\n<!-- /capture-heads -->\n' "$B" >> "$W/stories/s-r8.md"
gw "$W" add -A && gw "$W" commit -qm t || exit 9
T="$(gw "$W" rev-parse HEAD)"
# The stale seed really changed exactly one line, and that line keeps its path.
# Staged: diff exits 1 on a difference, which pipefail would turn into a lost count.
dd="$(diff <(blk s-ok.md) <(sed -n '/^<!-- capture-heads/,/^<!-- \/capture-heads/p' "$W/stories/s-stale.md"))"
sd="$(grep -c '^>' <<<"$dd")" || sd=0
[ "$sd" = 1 ] || { echo "REFUSED: the stale seed changed $sd block lines, want 1" >&2; exit 9; }
mkdir -p "$W2/stories" "$W2/test-results" && gw "$W2" init -q || exit 9
printf '$ pytest -q\nhead: 0000000\n1 passed\n' > "$W2/test-results/c.txt"
{ hdr "Und"; printf 'Full-collection run: `pytest -q` from the root, 1 passed.\n\nRun: `test-results/c.txt`.\n'; } > "$W2/stories/u.md"
gw "$W2" add -A && gw "$W2" add -f test-results && gw "$W2" commit -qm u || exit 9
U="$(gw "$W2" rev-parse HEAD)"
for v in B P X T U; do eval "printf '%s\n' \"\$$v\"" > "$R/.$v" || exit 9; done
: > "$R/.seeded" || exit 9
fi

fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }
chk() { he_run "$HE" -C "$W" --render-dar "stories/$1" "$T" --check 2>/dev/null; }
hof() { he_run "$HE" -C "$W" "stories/$1" "$B" "$T" 2>/dev/null; }
dar() { awk '($1 == "REFUSED" || $1 == "WARN") && $2 ~ /^dar-heads-/ {print $1 " " $2}' | tr '\n' ',' ; }
# ctl
o="$(he_run "$HE" -C "$W" --render-dar stories/s-none.md "$T" 2>/dev/null)"; rc=$?
chk s-none.md > /dev/null; crc=$?
[ "$rc:$crc:$o" = '0:0:<!-- capture-heads: generated by validate-handoff-evidence.sh --render-dar; do not edit -->
<!-- /capture-heads -->' ] || fail ctl "want the two marker lines, render and --check 0; got $rc:$crc [$o]"
if want r1; then
# r1
chk s-ok.md > /dev/null; crc=$?
o="$(hof s-ok.md)"; rc=$?
[ "$crc:$rc:$(dar <<<"$o")" = '0:0:' ] || fail r1 "want --check 0, handoff 0 and no dar-heads line; got $crc:$rc:$(dar <<<"$o") $(grep '^REFUSED' <<<"$o" | tr '\n' ' ')"
fi
if want r2 || want r2h; then
# r2 / r2h
o="$(chk s-stale.md)"; crc=$?
{ [ "$crc" = 1 ] && grep -q '^REFUSED dar-heads-stale stories/s-stale.md: ' <<<"$o" && [ "$(grep -c '^REFUSED' <<<"$o")" = 1 ]; } \
  || fail r2 "want exit 1 and one REFUSED dar-heads-stale; got $crc [$o]"
o="$(hof s-stale.md)"
[ "$(dar <<<"$o")" = 'REFUSED dar-heads-stale,' ] || fail r2h "want REFUSED dar-heads-stale in handoff mode; got [$(dar <<<"$o")]"
fi
if want r3; then
# r3
o="$(hof s-miss.md)"
[ "$(dar <<<"$o")" = 'REFUSED dar-heads-missing,' ] || fail r3 "want REFUSED dar-heads-missing; got [$(dar <<<"$o")]"
fi
if want r4; then
# r4
o="$(hof legacy.md)"; rc=$?
{ [ "$rc" = 0 ] && [ "$(dar <<<"$o")" = 'WARN dar-heads-missing,' ] && grep -q '^WARN dar-heads-missing stories/legacy.md: .*(legacy: ' <<<"$o"; } \
  || fail r4 "want exit 0 and one legacy WARN dar-heads-missing; got $rc [$(dar <<<"$o")]"
fi
if want und; then
# und
o="$(he_run "$HE" -C "$W2" stories/u.md "$U" "$U" 2>/dev/null)"
{ [ "$(dar <<<"$o")" = 'WARN dar-heads-missing,' ] && grep -q '(undecidable: ' <<<"$o"; } \
  || fail und "want one undecidable WARN dar-heads-missing; got [$(dar <<<"$o")]"
fi
if want r5; then
# r5
o="$(chk s-dup.md)"; crc=$?
{ [ "$crc" = 1 ] && grep -q '^REFUSED dar-heads-duplicate stories/s-dup.md: 2 ' <<<"$o"; } || fail r5 "want REFUSED dar-heads-duplicate (2 blocks); got $crc [$o]"
fi
# the render of s-ok, read per line
RO_="$(blk s-ok.md)"
line() { grep -F -- "- \`test-results/$1\` — " <<<"$RO_"; }
! want r6 || [ "$(line red.txt)" = "- \`test-results/red.txt\` — head \`$B\` — \`\$ scripts/ai-dlc/validate-mutation-red.sh x.py 1 y pytest\`" ] \
  || fail r6 "want the replay block's own head $B and no count; got [$(line red.txt)]"
if want r7; then o="$(chk s-r7.md)"; crc=$?
{ [ "$crc" = 0 ] && grep -qF 'test-results/other.log' "$W/stories/s-r7.md"; } || fail r7 "want --check 0 on a pasted block naming other.log; got $crc [$o]"; fi
if want r8; then o="$(he_run "$HE" -C "$W" --list-captures stories/s-r8.md "$T" 2>/dev/null)"
o2="$(he_run "$HE" -C "$W" --list-captures stories/s-r7.md "$T" 2>/dev/null | tr '\n' ' ')"
{ [ -z "$o" ] && [ "$o2" = 'test-results/r7.txt ' ]; } || fail r8 "want nothing for s-r8 and only r7.txt for s-r7; got [$o] [$o2]"; fi
! want r9 || [ "$(line dirty.txt)" = "- \`test-results/dirty.txt\` — head \`$B (+dirty)\` — \`\$ pytest -q tests\`" ] || fail r9 "want head \`$B (+dirty)\`; got [$(line dirty.txt)]"
! want esc || [ "$(line esc.txt)" = "- \`test-results/esc.txt\` — head \`$B\` — \`\` \$ echo \`date\` done \`\`" ] || fail esc "want a double-backtick span; got [$(line esc.txt)]"
! want cmd || [ "$(line cmdfirst.txt)" = "- \`test-results/cmdfirst.txt\` — head \`$B\` — \`mutation-red replay\`" ] || fail cmd "want the (a)-arm command line; got [$(line cmdfirst.txt)]"
! want d3 || [ "$(line full.txt)" = "- \`test-results/full.txt\` — head \`$B\` — \`\$ pytest -q\` — \`3 passed, 1 skipped in 0.20s\`" ] || fail d3 "want the last count line on full.txt only; got [$(line full.txt)]"
fcn() { grep -c '^REFUSED full-collection-none ' <<<"$1"; }
if want cnt; then o="$(hof s-cnt.md)"; n="$(fcn "$o")" || n=0
{ [ "$n" = 0 ] && [ -z "$(dar <<<"$o")" ]; } || fail cnt "want no full-collection-none and no dar-heads line; got $n [$(dar <<<"$o")]"; fi
if want cntnb; then o="$(hof s-cntnb.md)"; n="$(fcn "$o")" || n=0
[ "$n" = 1 ] || fail cntnb "want REFUSED full-collection-none with no block; got $n"; fi
if want cntpl; then o="$(hof s-cntpl.md)"; n="$(fcn "$o")" || n=0
[ "$n" = 1 ] || fail cntpl "want REFUSED full-collection-none for a bare capture path; got $n"; fi
# rp: the block is fresh (no dar-heads line), so the refusal is the replay capture's missing count.
if want rp; then o="$(hof s-rp.md)"; n="$(fcn "$o")" || n=0
{ [ "$n" = 1 ] && [ -z "$(dar <<<"$o")" ]; } || fail rp "want REFUSED full-collection-none and no dar-heads line for a replay capture; got $n [$(dar <<<"$o")]"; fi
# trim: the seed really carries the blanks, the render drops them, the pasted render checks 0.
if want trim; then tl="$(grep -c '^\$ pytest -q tests   $' "$W/test-results/trim.txt")" || tl=0
rt="$(blk s-trim.md | grep -F -- '- `test-results/trim.txt` — ')"
o="$(chk s-trim.md)"; crc=$?
{ [ "$tl" = 1 ] && [ "$rt" = "- \`test-results/trim.txt\` — head \`$B\` — \`\$ pytest -q tests\`" ] && [ "$crc" = 0 ]; } \
  || fail trim "want a trimmed command and --check 0; got seed $tl, crc $crc [$rt] [$o]"; fi
[ "$fails" -eq 0 ] || exit 1
exit 0
