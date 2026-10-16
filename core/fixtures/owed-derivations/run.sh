#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# owed-derivations — assert a derivation an operator LEAVES broken stays owed until it is re-pointed.
#
# Usage: run.sh [<check-owed-derivations.sh> [<derivation-differential.sh>]]
#   The arguments exist for `owed-derivations-mutants`, which drives this file against mutated copies.
# Exit: 0 every assertion holds | 1 something regressed | 2 the harness could not run.
#
# TWO SUBJECTS. The WRITER is reconcile/derivation-differential.sh --record-owed; the READER is
# scripts/ai-dlc/check-owed-derivations.sh. The writer worlds drive the real differential over a
# hand-back-shaped consumer; the reader worlds seed the record BY HAND from the writer's documented
# row shape, then ALSO drive the reader over a record the real writer produced (W1), so the reader is
# never certified only against its own accept-set.
#
# THE VALIDATOR IS THE REAL ONE, copied from this tree into each root as the installer would.
#
# EVERY READER WORLD ASSERTS A VALUE: the exit status and the exact set of OPEN keys, never "some
# output". A reader that printed nothing fails every presence-shaped arm below by construction.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
READER="$(pick "${1:-}" "$HERE/../../scripts/check-owed-derivations.sh" \
  "$HERE/../../../scripts/ai-dlc/check-owed-derivations.sh" "$HERE/../../../core/scripts/check-owed-derivations.sh")"
DIFFER="$(pick "${2:-}" "$HERE/../../skills/ai-dlc-update/reconcile/derivation-differential.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/derivation-differential.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/derivation-differential.sh")"
VALIDATOR="$(pick "$HERE/../../scripts/validate-artifact-derivations.sh" \
  "$HERE/../../../scripts/ai-dlc/validate-artifact-derivations.sh" "$HERE/../../../core/scripts/validate-artifact-derivations.sh")"
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: an absent subject SKIPS LOUDLY, never passes.
if [ -z "$READER" ] || [ -z "$DIFFER" ]; then
  echo "SKIP: check-owed-derivations.sh or derivation-differential.sh is not present in this tree yet (a core fixture ships ahead of its subject). Nothing was asserted."
  exit 0
fi
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate validate-artifact-derivations.sh" >&2; exit 2; }
READER="$(cd "$(dirname "$READER")" && pwd)/$(basename "$READER")"
DIFFER="$(cd "$(dirname "$DIFFER")" && pwd)/$(basename "$DIFFER")"

# Candidate paths for the rulebook prose the callers live in (both layouts).
STEPS=""
for d in "$HERE/../../skills/ai-dlc/steps" "$HERE/../../../.claude/skills/ai-dlc/steps" "$HERE/../../../core/skills/ai-dlc/steps"; do
  [ -f "$d/route.md" ] && { STEPS="$(cd "$d" && pwd)"; break; }
done

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

echo "owed-derivations:"
printf '  reader: %s\n' "$READER"
printf '  writer: %s\n' "$DIFFER"
printf 'HERMETIC-CONSUMED core/scripts/check-owed-derivations.sh\n'
printf 'HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/derivation-differential.sh\n'
printf 'HERMETIC-CONSUMED core/scripts/validate-artifact-derivations.sh\n'

g() { local d="$1"; shift; git -C "$d" -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
ck() { if grep -qF -- "$2" <<<"$3"; then ok "$1"; else bad "$1 -- expected to find: $2"; printf '%s\n' "$3" | sed 's/^/        | /' | head -12; fi; }
nk() { if grep -qF -- "$2" <<<"$3"; then bad "$1 -- must NOT contain: $2"; else ok "$1"; fi; }
rc_is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 -- exit was $3, expected $2"; fi; }
TAB="$(printf '\t')"

# rd <root> <record> -> sets OUT (stdout), ERR (stderr), RC
rd() {
  local o="$WORK/rd.out" e="$WORK/rd.err"
  ( cd / && AI_DLC_PROJECT_ROOT="$1" bash "$READER" "$2" > "$o" 2> "$e" ); RC=$?
  OUT="$(cat "$o")"; ERR="$(cat "$e")"
}
# open_keys -> the key column of every OPEN line in OUT, comma-joined
open_keys() { awk -F'\t' '$1 == "OPEN" { printf "%s%s", (n++ ? "," : ""), $2 } END { print "" }' <<<"$OUT"; }
reason_of() { awk -F'\t' -v k="$1" '$1 == "OPEN" && $2 == k { print $3 }' <<<"$OUT"; }
line_of() { grep -n -F -- "$2" "$1" | sed -n "${3:-1}p" | cut -d: -f1; }
row() { printf 'OWED\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "${3:-5}" "${4:-1}" "base..theirs" "reconcile-log-x"; }

# ---- the reader's root: a toy tree plus the real validator -------------------------------------
mkroot() { # <dir>
  mkdir -p "$1/scripts/ai-dlc" "$1/.claude" "$1/_bmad-output/planning-artifacts/s1" "$1/_bmad-output/party-mode"
  cp "$VALIDATOR" "$1/scripts/ai-dlc/validate-artifact-derivations.sh"
  printf 'qqalpha\n' > "$1/t.txt"
}
CMD='grep -c qqalpha t.txt'
fence() { printf '```derived\n$ %s\n%s\n```\n' "$CMD" "$1"; }

R="$WORK/rd1"; mkroot "$R"
PRD="_bmad-output/planning-artifacts/prd.md"
STORY="_bmad-output/planning-artifacts/s1/story.md"
REC1="_bmad-output/planning-artifacts/s1/story-repair-p1.md"
REC2="_bmad-output/planning-artifacts/s1/story-adversarial-p1.md"
REC3="_bmad-output/planning-artifacts/s1/requirements-elicitation-repair.md"
PM="_bmad-output/party-mode/session.md"
{ printf '# PRD\n\n'; fence 5; } > "$R/$PRD"
{ printf '# Story\n\nThis row is CLOSED and re-pointed, the debt is closed.\n\n'; fence 5; } > "$R/$STORY"
{ printf '# Record, no later copy\n\n'; fence 5; } > "$R/$REC1"
# a record whose stale copy is re-derived LATER, once stale and once fresh
{ printf '# Record, later copy stale\n\n'; fence 5; printf '\nre-derived:\n\n'; fence 6; } > "$R/$REC2"
{ printf '# Record, later copy fresh\n\n'; fence 5; printf '\nre-derived:\n\n'; fence 1; } > "$R/$REC3"
{ printf '# Party mode\n\n'; fence 5; } > "$R/$PM"
K_PRD="$PRD:$(line_of "$R/$PRD" '$ grep')"
K_STORY="$STORY:$(line_of "$R/$STORY" '$ grep')"
K_REC1="$REC1:$(line_of "$R/$REC1" '$ grep')"
K_REC2E="$REC2:$(line_of "$R/$REC2" '$ grep' 1)"; K_REC2L="$REC2:$(line_of "$R/$REC2" '$ grep' 2)"
K_REC3E="$REC3:$(line_of "$R/$REC3" '$ grep' 1)"; K_REC3L="$REC3:$(line_of "$R/$REC3" '$ grep' 2)"
K_PM="$PM:$(line_of "$R/$PM" '$ grep')"
for k in "$K_PRD" "$K_STORY" "$K_REC1" "$K_REC2E" "$K_REC2L" "$K_REC3E" "$K_REC3L" "$K_PM"; do
  case "$k" in *:|*::*) echo "FIXTURE ERROR: a seeded derivation line was not found ($k)" >&2; exit 2 ;; esac
done

# ---- B0: the seed is what the world claims -------------------------------------------------------
# CONTROL: the real validator, run on the same files, must FAIL the stale ones and PASS the fresh one.
v_rc() { ( cd "$R" && AI_DLC_PROJECT_ROOT="$R" bash "$R/scripts/ai-dlc/validate-artifact-derivations.sh" "$R/$1" >/dev/null 2>"$WORK/v.err" ); echo $?; }
rc_is "B0a control: the validator FAILS the stale prd fence" 1 "$(v_rc "$PRD")"
rc_is "B0b control: the validator PASSES the fresh later copy's file once the stale one is gone" 0 "$(printf '# x\n\n'"$(fence 1)"'\n' > "$R/fresh.md"; v_rc fresh.md)"
ck "B0c the s<N> record with a later copy prints SUPERSEDED on the verdict stream" "SUPERSEDED: $R/$REC3:" "$(cd "$R" && AI_DLC_PROJECT_ROOT="$R" bash scripts/ai-dlc/validate-artifact-derivations.sh "$R/$REC3" 2>&1 >/dev/null)"

# ---- B1: two rows, both still failing -> exactly those two keys OPEN ------------------------------
{ row "$K_PRD" "$CMD"; row "$K_STORY" "$CMD"; } > "$WORK/b1.tsv"
rd "$R" "$WORK/b1.tsv"
rc_is "B1a two failing rows -> exit 1" 1 "$RC"
rc_is "B1b and the OPEN keys are exactly those two" 0 "$([ "$(open_keys)" = "$K_PRD,$K_STORY" ] && echo 0 || echo 1)"
# B1 near-miss: a second root where one is re-pointed so it reproduces
R2="$WORK/rd2"; mkroot "$R2"; mkdir -p "$R2/_bmad-output/planning-artifacts/s1"
{ printf '# PRD\n\n'; fence 1; } > "$R2/$PRD"
{ printf '# Story\n\n'; fence 5; } > "$R2/$STORY"
rd "$R2" "$WORK/b1.tsv"
rc_is "B1c one re-pointed (now reproduces) -> exit 1 with ONE open row" 1 "$RC"
rc_is "B1d the open key is the one still failing, not the re-pointed one" 0 "$([ "$(open_keys)" = "$K_STORY" ] && echo 0 || echo 1)"
row "$K_PRD" "$CMD" > "$WORK/b1e.tsv"
rd "$R2" "$WORK/b1e.tsv"
rc_is "B1e every row re-pointed -> exit 0" 0 "$RC"
rc_is "B1f and nothing is printed on stdout" 0 "$(printf '%s' "$OUT" | wc -c | tr -d ' ')"

# ---- B2: prose that LOOKS closed beside a still-failing derivation stays OPEN ----------------------
row "$K_STORY" "$CMD" > "$WORK/b2.tsv"
rd "$R" "$WORK/b2.tsv"
rc_is "B2a the doc says CLOSED in prose, the derivation still fails -> exit 1" 1 "$RC"
rc_is "B2b and the row is OPEN with reason STALE" 0 "$([ "$(reason_of "$K_STORY")" = STALE ] && echo 0 || echo 1)"

# ---- B3: rows OUTSIDE s<N>/ (prd.md, party-mode) are read from their own file ----------------------
{ row "$K_PRD" "$CMD"; row "$K_PM" "$CMD"; } > "$WORK/b3.tsv"
rd "$R" "$WORK/b3.tsv"
rc_is "B3a prd.md and party-mode rows both OPEN" 0 "$([ "$(open_keys)" = "$K_PRD,$K_PM" ] && echo 0 || echo 1)"

# ---- B4: absent, unreadable, malformed ------------------------------------------------------------
rd "$R" "$WORK/no-such-record.tsv"
rc_is "B4a no record -> exit 0" 0 "$RC"
rc_is "B4b and it is silent on both streams" 0 "$(printf '%s%s' "$OUT" "$ERR" | wc -c | tr -d ' ')"
: > "$WORK/empty.tsv"
rd "$R" "$WORK/empty.tsv"
rc_is "B4c control: an EMPTY record exists, owes nothing -> exit 0" 0 "$RC"
mkdir "$WORK/dir.tsv"
rd "$R" "$WORK/dir.tsv"
rc_is "B4d a record that exists as a DIRECTORY (unreadable as a file) -> exit 2" 2 "$RC"
ck "B4e and the refusal names the record as unreadable" "cannot be read" "$ERR"
row "$K_PRD" "$CMD" > "$WORK/unread.tsv"; chmod 000 "$WORK/unread.tsv"
if [ -r "$WORK/unread.tsv" ]; then
  ok "B4f (skipped: this account reads a mode-000 file, so that shape cannot be built; B4d carries the unreadable case)"
else
  rd "$R" "$WORK/unread.tsv"
  rc_is "B4f a mode-000 record -> exit 2" 2 "$RC"
fi
chmod 600 "$WORK/unread.tsv" 2>/dev/null
printf 'not a record\n' > "$WORK/mal1.tsv"
rd "$R" "$WORK/mal1.tsv"
rc_is "B4g a malformed row -> exit 2" 2 "$RC"
ck "B4h and the refusal says malformed" "is malformed" "$ERR"
{ row "$K_PRD" "$CMD"; printf 'OWED\t%s\t%s\n' "$K_STORY" "$CMD"; } > "$WORK/mal2.tsv"
rd "$R" "$WORK/mal2.tsv"
rc_is "B4i one malformed row among valid ones refuses the whole record -> exit 2" 2 "$RC"
nk "B4j and no OPEN line is printed for the valid row beside it" "OPEN" "$OUT"

# ---- B5: MOVED -- the recorded line no longer holds the recorded command -------------------------
R3="$WORK/rd3"; mkroot "$R3"
{ printf '# PRD\n\nA paragraph added above, so the recorded line shifted.\n\nmore prose\n\n'; fence 1; } > "$R3/$PRD"
row "$K_PRD" "$CMD" > "$WORK/b5.tsv"
rd "$R3" "$WORK/b5.tsv"
rc_is "B5a the recorded line now holds other text and the fence below reproduces -> exit 1" 1 "$RC"
rc_is "B5b the row is OPEN with reason MOVED, never closed on silence" 0 "$([ "$(reason_of "$K_PRD")" = MOVED ] && echo 0 || echo 1)"
row "nope/missing.md:3" "$CMD" > "$WORK/b5m.tsv"
rd "$R3" "$WORK/b5m.tsv"
rc_is "B5c a row whose FILE is gone is MOVED too -> exit 1" 1 "$RC"

# ---- B6: supersession -----------------------------------------------------------------------------
row "$K_REC2E" "$CMD" > "$WORK/b6a.tsv"
rd "$R" "$WORK/b6a.tsv"
rc_is "B6a superseded by a STALE later copy -> OPEN" 0 "$([ "$(open_keys)" = "$K_REC2E" ] && [ "$(reason_of "$K_REC2E")" = SUPERSEDED-STALE ] && echo 0 || echo 1)"
row "$K_REC3E" "$CMD" > "$WORK/b6b.tsv"
rd "$R" "$WORK/b6b.tsv"
rc_is "B6b superseded by a FRESH later copy -> closed, exit 0" 0 "$RC"
ck "B6c control: the same file's SUPERSEDED line names this key, so the closure is by the later copy" "SUPERSEDED: $R/$REC3:${K_REC3E##*:} by $R/$REC3:${K_REC3L##*:}" "$(cd "$R" && AI_DLC_PROJECT_ROOT="$R" bash scripts/ai-dlc/validate-artifact-derivations.sh "$R/$REC3" 2>&1 >/dev/null)"

# ---- B7: STAYS-OPEN seeds that do not depend on supersession ---------------------------------------
{ row "$K_REC1" "$CMD"; row "$K_STORY" "$CMD"; row "$K_PRD" "$CMD"; } > "$WORK/b7.tsv"
rd "$R" "$WORK/b7.tsv"
rc_is "B7a a record with NO later identical copy, a live s<N> doc and a file outside s<N>/ are all OPEN" 0 "$([ "$(open_keys)" = "$K_REC1,$K_STORY,$K_PRD" ] && echo 0 || echo 1)"

# ---- B8: validator exit 2 over a row's file -> unassessed, never closed ---------------------------
R4="$WORK/rd4"; mkroot "$R4"
cp "$R/$PRD" "$R4/$PRD"
# a validator that REFUSES (exit 2) with no verdict line, as the real one does on UNRUN/REFUSED
printf '#!/usr/bin/env bash\necho "REFUSED: seeded" >&2\nexit 2\n' > "$R4/scripts/ai-dlc/validate-artifact-derivations.sh"
v8="$(cd "$R4" && bash scripts/ai-dlc/validate-artifact-derivations.sh "$R4/$PRD" >/dev/null 2>&1; echo $?)"
rc_is "B8a control: the seeded validator exits 2" 2 "$v8"
row "$K_PRD" "$CMD" > "$WORK/b8.tsv"
rd "$R4" "$WORK/b8.tsv"
rc_is "B8b an exit-2 validator leaves the row OPEN as UNASSESSED, exit 1" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_PRD")" = UNASSESSED ] && echo 0 || echo 1)"

# ---- W: the WRITER over the real differential, then the reader over ITS record --------------------
DIST="$WORK/dist"; mkdir -p "$DIST/core/scripts"; g "$DIST" init -q
printf 'qqprev\n' > "$DIST/core/scripts/toy.sh"; g "$DIST" add -A; g "$DIST" commit -qm prev
printf 'qqalpha\nqqgamma\n' > "$DIST/core/scripts/toy.sh"; g "$DIST" add -A; g "$DIST" commit -qm base
BASE="$(g "$DIST" rev-parse HEAD)"
printf 'qqgamma\nqqdelta\n' > "$DIST/core/scripts/toy.sh"; g "$DIST" add -A; g "$DIST" commit -qm theirs
THEIRS="$(g "$DIST" rev-parse HEAD)"
[ -n "$BASE" ] && [ -n "$THEIRS" ] && [ "$BASE" != "$THEIRS" ] || { echo "FIXTURE ERROR: dist refs" >&2; exit 2; }
C="$WORK/consumer"; mkdir -p "$C/scripts/ai-dlc" "$C/.claude" "$C/_bmad-output"; g "$C" init -q
cp "$VALIDATOR" "$C/scripts/ai-dlc/validate-artifact-derivations.sh"
printf 'qqalpha\nqqgamma\n' > "$C/scripts/ai-dlc/toy.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$C/.claude/.ai-dlc-version"
{ printf '# Story\n\n```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n\n```derived\n$ grep -c qqgamma scripts/ai-dlc/toy.sh\n1\n```\n'; } > "$C/_bmad-output/story.md"
g "$C" add -A; g "$C" commit -qm "pull to 1.0.0"
g "$DIST" show "${THEIRS}:core/scripts/toy.sh" > "$C/scripts/ai-dlc/toy.sh"
dd() { OUTD="$(cd / && TMPDIR="$WORK" bash "$DIFFER" "$DIST" "$BASE" "$C" "$THEIRS" "$@" 2>&1)"; RCD=$?; }
OWED="$WORK/owed.tsv"
dd; PRINTED_PLAIN="$OUTD"
rc_is "W0 control: the differential finds the broken derivation -> exit 1" 1 "$RCD"
rc_is "Wa without --record-owed NOTHING is written" 0 "$([ -e "$OWED" ] && echo 1 || echo 0)"
dd --record-owed "$OWED" --log-name reconcile-log-t1.md
rc_is "Wb with --record-owed the exit is unchanged (1)" 1 "$RCD"
K_W="_bmad-output/story.md:4"
printed="$(awk -F'\t' '$1 == "NEWLY-FAILING" { print }' <<<"$OUTD")"
want_rec="$(awk -F'\t' -v rng="$BASE..$THEIRS" '$1 == "NEWLY-FAILING" {
  s = $3; i = index(s, "  $ "); j = index(s, "  recorded: "); k = index(s, "  actual: ")
  printf "OWED\t%s\t%s\t%s\t%s\t%s\treconcile-log-t1.md\n", $2, substr(s, i + 4, j - i - 4), substr(s, j + 12, k - j - 12), substr(s, k + 10), rng }' <<<"$OUTD")"
rc_is "Wc the record has exactly one row" 1 "$(awk 'END { print NR + 0 }' "$OWED" 2>/dev/null)"
if [ -n "$want_rec" ] && [ "$(cat "$OWED" 2>/dev/null)" = "$want_rec" ]; then
  ok "Wd the record row is byte-equal to the row the helper PRINTED (key, command, recorded, actual, range, log)"
else
  bad "Wd the record row differs from the printed row"; printf '        printed->%s\n        record ->%s\n' "$want_rec" "$(cat "$OWED" 2>/dev/null)"
fi
ck "We the recorded and actual outputs are both present in the record" "${TAB}1${TAB}0${TAB}$BASE..$THEIRS${TAB}reconcile-log-t1.md" "$(cat "$OWED" 2>/dev/null)"
dd --record-owed "$OWED" --log-name reconcile-log-t2.md
rc_is "Wf a second run APPENDS: the record has two rows" 2 "$(awk 'END { print NR + 0 }' "$OWED")"
rd "$C" "$OWED"
rc_is "Wg the reader over the WRITER'S record: exit 1 and the key is OPEN (duplicate rows report each)" 0 "$([ "$RC" = 1 ] && [ "$(open_keys)" = "$K_W,$K_W" ] && echo 0 || echo 1)"
printf 'qqalpha\nqqgamma\n' > "$C/scripts/ai-dlc/toy.sh"
rd "$C" "$OWED"
rc_is "Wh once the tree reproduces the derivation again the writer's rows read closed -> exit 0" 0 "$RC"

# ---- G: the callers (rulebook prose) --------------------------------------------------------------
if [ -z "$STEPS" ]; then
  echo "  note  the steps directory is not in this tree; the caller arms are skipped (a consumer without the rulebook)"
else
  ck "Ga route.md Step 0a runs the reader on resume" "check-owed-derivations.sh" "$(cat "$STEPS/route.md")"
  ck "Gb the gate site REFUSES the gate on an open row" "The gate is REFUSED while an owed derivation is open" "$(cat "$STEPS/_gate-procedures.md")"
  ck "Gc the sprint-close site carries open rows forward" "check-owed-derivations.sh" "$(cat "$STEPS/retro.md")"
fi
# GATE ARM, executed: the gate site passes iff the reader exits 0. Open row -> refuse; control -> pass.
gate_site() { rd "$1" "$2"; [ "$RC" = 0 ] && echo PASS || echo REFUSE; }
rc_is "Gd gate arm: an open row REFUSES the gate" REFUSE "$(gate_site "$R" "$WORK/b2.tsv")"
rc_is "Ge gate arm control: no open row PASSES the gate" PASS "$(gate_site "$R2" "$WORK/b1e.tsv")"
# SPRINT-CLOSE ARM, executed: every OPEN line becomes a carry-over item; the count must equal the open rows.
co="$(gate_site "$R" "$WORK/b7.tsv" >/dev/null; rd "$R" "$WORK/b7.tsv"; awk -F'\t' '$1 == "OPEN" { n++ } END { print n + 0 }' <<<"$OUT")"
rc_is "Gf sprint-close: three open rows are three carried-forward items, none dropped" 3 "$co"
rd "$R2" "$WORK/b1e.tsv"
rc_is "Gg sprint-close control: with the record's rows all closed nothing is carried" 0 "$(awk -F'\t' '$1 == "OPEN" { n++ } END { print n + 0 }' <<<"$OUT")"

if [ "$fails" -ne 0 ]; then
  printf '  %s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '  all assertions hold\n'
exit 0
