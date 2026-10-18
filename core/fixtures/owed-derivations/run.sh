#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# owed-derivations — assert a derivation an operator LEAVES broken stays owed until it is re-pointed.
#
# Usage: run.sh [<check-owed-derivations.sh> [<derivation-differential.sh>]]
#   The arguments existed for a retired mutation battery, which drove this file against mutated copies.
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

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# THE READER RUNS FROM A COPY BESIDE A STUB sprint-status.sh. The reader resolves the current sprint only
# through a sibling `sprint-status.sh sprint-id`, so the copy (which is the MUTATED reader when the
# battery drives this file) sits in a directory that holds the stub. The stub answers from
# `<root>/.sprint-id` and exits 1 when that file is absent, which is the unresolvable-sprint world.
# The stub is generated here, so it is not an input to declare.
BIN="$WORK/bin"; mkdir -p "$BIN"
write_stub() { # <dir>
  printf '#!/usr/bin/env bash\n[ "${1:-}" = sprint-id ] || exit 2\nshift; r=""; [ "${1:-}" = --root ] && r="${2:-}"\n[ -f "$r/.sprint-id" ] || exit 1\ncat "$r/.sprint-id"\n' > "$1/sprint-status.sh"
}
write_stub "$BIN"
cp "$READER" "$BIN/check-owed-derivations.sh"

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
  ( cd / && AI_DLC_PROJECT_ROOT="$1" bash "$BIN/check-owed-derivations.sh" "$2" > "$o" 2> "$e" ); RC=$?
  OUT="$(cat "$o")"; ERR="$(cat "$e")"
}
# scope_in <root> <rel path> -> sets SC (stdout) and RC for the reader's --scope mode
scope_in() {
  SC="$( cd / && AI_DLC_PROJECT_ROOT="$1" bash "$BIN/check-owed-derivations.sh" --scope "$2" 2>"$WORK/sc.err" )"; RC=$?
}
# info_count -> how many INFO past-sprint lines OUT carries
info_count() { awk -F'\t' '$1 == "INFO" && $2 == "past-sprint" { n++ } END { print n + 0 }' <<<"$OUT"; }
open_count() { awk -F'\t' '$1 == "OPEN" { n++ } END { print n + 0 }' <<<"$OUT"; }
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
  printf '1\n' > "$1/.sprint-id"
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
{ printf '# Story\n\n'; fence 5; } > "$R/$STORY"
# the prose-looks-closed document is its OWN file, used by B2 only, so a mutant trusting status text
# moves B2 and nothing else
CLOSEDDOC="_bmad-output/planning-artifacts/s1/closed.md"
{ printf '# Closed\n\nThis row is CLOSED and re-pointed, the debt is closed.\n\n'; fence 5; } > "$R/$CLOSEDDOC"
LIVE2="_bmad-output/planning-artifacts/s1/story2.md"
{ printf '# Story two\n\n'; fence 5; } > "$R/$LIVE2"
# a path carrying ( ) + | : the old regex built from the path exited 2 on it, which read as no match
ODD="_bmad-output/planning-artifacts/s1/a(b)+c|d.md"
{ printf '# Odd path\n\n'; fence 5; } > "$R/$ODD"
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
K_CLOSED="$CLOSEDDOC:$(line_of "$R/$CLOSEDDOC" '$ grep')"
K_LIVE2="$LIVE2:$(line_of "$R/$LIVE2" '$ grep')"
K_ODD="$ODD:$(line_of "$R/$ODD" '$ grep')"
for k in "$K_CLOSED" "$K_LIVE2" "$K_ODD" "$K_PRD" "$K_STORY" "$K_REC1" "$K_REC2E" "$K_REC2L" "$K_REC3E" "$K_REC3L" "$K_PM"; do
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
row "$K_CLOSED" "$CMD" > "$WORK/b2.tsv"
rd "$R" "$WORK/b2.tsv"
rc_is "B2a the doc says CLOSED in prose, the derivation still fails -> exit 1" 1 "$RC"
rc_is "B2b and the row is OPEN with reason STALE" 0 "$([ "$(reason_of "$K_CLOSED")" = STALE ] && echo 0 || echo 1)"
row "$K_ODD" "$CMD" > "$WORK/b2o.tsv"
rd "$R" "$WORK/b2o.tsv"
rc_is "B2c a path carrying ( ) + | with a stale fence is OPEN (a regex built from it would have closed it)" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_ODD")" = STALE ] && echo 0 || echo 1)"

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
rc_is "B4e the exit is 2 AND the refusal names the record as unreadable" 0 "$([ "$RC" = 2 ] && grep -qF 'cannot be read' <<<"$ERR" && echo 0 || echo 1)"
ln -s "$WORK/no-such-target.tsv" "$WORK/dangling.tsv"
rd "$R" "$WORK/dangling.tsv"
rc_is "B4f a DANGLING symlink record (present, unreadable as a file, any uid) -> exit 2" 2 "$RC"
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
SHIFT='A paragraph added above, so the recorded line shifted.'
# B5a-d: the row is located by CONTENT, so a shifted line is judged where it now sits
{ printf '# PRD\n\n%s\n\nmore prose\n\n' "$SHIFT"; fence 5; } > "$R3/$LIVE2"
row "$K_LIVE2" "$CMD" > "$WORK/b5.tsv"
rd "$R3" "$WORK/b5.tsv"
rc_is "B5a a shifted line whose derivation is still stale -> exit 1, OPEN as STALE" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_LIVE2")" = STALE ] && echo 0 || echo 1)"
{ printf '# PRD\n\n%s\n\nmore prose\n\n' "$SHIFT"; fence 1; } > "$R3/$LIVE2"
rd "$R3" "$WORK/b5.tsv"
rc_is "B5b a shifted line whose derivation now reproduces -> closed, exit 0" 0 "$RC"
# B5c: the recorded command is no longer in the file at all (the line holds a DIFFERENT $ command)
{ printf '# PRD\n\n'; printf '```derived\n$ grep -c qqzzz t.txt\n0\n```\n'; } > "$R3/$LIVE2"
rd "$R3" "$WORK/b5.tsv"
rc_is "B5c the file exists and the line holds a different command -> MOVED, exit 1" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_LIVE2")" = MOVED ] && echo 0 || echo 1)"
row "nope/missing.md:3" "$CMD" > "$WORK/b5m.tsv"
rd "$R3" "$WORK/b5m.tsv"
rc_is "B5d a row whose FILE is gone is MOVED too -> exit 1" 1 "$RC"
# B5e: the command is present but its opener was changed to a text fence the validator never reads
{ printf '# PRD\n\n'; printf '```text\n$ %s\n5\n```\n' "$CMD"; } > "$R3/$LIVE2"
rd "$R3" "$WORK/b5.tsv"
rc_is "B5e an UNFENCED line (text opener) is MOVED, never closed on the validator's silence" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_LIVE2")" = MOVED ] && echo 0 || echo 1)"
# B5f: two derived-fence copies, neither at the recorded line, cannot be placed -> refusal
{ printf '# PRD\n\nprose\n\nmore\n\n'; fence 5; printf '\n'; fence 5; } > "$R3/$LIVE2"
rd "$R3" "$WORK/b5.tsv"
rc_is "B5f a duplicate command that the recorded line cannot break -> exit 2" 2 "$RC"
ck "B5g and the refusal says the row cannot be placed" "cannot be placed" "$ERR"

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
cp "$R/$LIVE2" "$R4/$LIVE2"
# a validator that REFUSES (exit 2) with no verdict line, as the real one does on UNRUN/REFUSED
printf '#!/usr/bin/env bash\necho "REFUSED: seeded" >&2\nexit 2\n' > "$R4/scripts/ai-dlc/validate-artifact-derivations.sh"
v8="$(cd "$R4" && bash scripts/ai-dlc/validate-artifact-derivations.sh "$R4/$LIVE2" >/dev/null 2>&1; echo $?)"
rc_is "B8a control: the seeded validator exits 2" 2 "$v8"
row "$K_LIVE2" "$CMD" > "$WORK/b8.tsv"
rd "$R4" "$WORK/b8.tsv"
rc_is "B8b an exit-2 validator leaves the row OPEN as UNASSESSED, exit 1" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_LIVE2")" = UNASSESSED ] && echo 0 || echo 1)"

# ---- S: SCOPE IS THE CURRENT SPRINT ONLY (operator ruling) ----------------------------------------
# The classifier is one mode of the reader, `--scope <rel path>`. The current sprint is 1 in R. Every
# near-miss below carries the property a feared regression would key on (a substring, a wrong area).
PASTDOC="_bmad-output/planning-artifacts/s0/past.md"
S19DOC="_bmad-output/planning-artifacts/s19/x.md"
mkdir -p "$R/_bmad-output/planning-artifacts/s0" "$R/_bmad-output/planning-artifacts/s19"
{ printf '# Past sprint\n\n'; fence 5; } > "$R/$PASTDOC"
{ printf '# Sprint nineteen\n\n'; fence 5; } > "$R/$S19DOC"
K_PAST="$PASTDOC:$(line_of "$R/$PASTDOC" '$ grep')"
K_S19="$S19DOC:$(line_of "$R/$S19DOC" '$ grep')"
sc_is() { # <arm> <expected> <path>
  scope_in "$R" "$3"
  rc_is "$1 --scope $3 (current sprint 1) -> $2" 0 "$([ "$RC" = 0 ] && [ "$SC" = "$2" ] && echo 0 || echo 1)"
}
sc_is Sc1 PAST    "_bmad-output/planning-artifacts/s19/x.md"
sc_is Sc2 PAST    "_bmad-output/specs/s317/x.md"
sc_is Sc3 CURRENT "_bmad-output/specs/s1/x.md"
sc_is Sc4 CURRENT "_bmad-output/party-mode/s1/seat.md"
sc_is Sc5 LIVING  "_bmad-output/planning-artifacts/s319.md"
sc_is Sc6 CURRENT "_bmad-output/planning-artifacts/s1/x.md"
sc_is Sc7 LIVING  "_bmad-output/planning-artifacts/prd.md"
sc_is Sc8 LIVING  "_bmad-output/planning-artifacts/s319x/y.md"
sc_is Sc9 PAST    "_bmad-output/planning-artifacts/s0/past.md"

# ---- H: the HISTORY class (checked first; INFO, never recorded, never OPEN) ------------------------
# Each shape is seeded as a real file with a stale fence, so the row would be OPEN if it were not history.
HSHAPES="_bmad-output/implementation-artifacts/s1/gate-adjudication/g.md
_bmad-output/implementation-artifacts/pre-series/gate-adjudication/g.md
_bmad-output/pipeline-history/pipeline-snapshot-archive.md
_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md
_bmad-output/planning-artifacts/prd-history.md
_bmad-output/planning-artifacts/product-brief-history.md
_bmad-output/planning-artifacts/archive/x.md
_bmad-output/planning-artifacts/s1/archive/cycle-1/x.md
_bmad-output/ai-dlc-update/reconcile-log-20261016T0725Z.md
_bmad-output/planning-artifacts/implementation-readiness-report-2026-10-16.md
_bmad-output/operator-answers-history.md
_bmad-output/operator-requests-history.md
_bmad-output/pipeline-snapshot-history.md"
LIVEGA="_bmad-output/gate-adjudication/g.md"
GA="_bmad-output/gate-adjudication"
GA_LIVE="planning-20260301T000000Z"; GA_OLD="planning-20260101T000000Z"
mkdir -p "$R/$GA"
: > "$R/$GA/$GA_LIVE.verdict.json"; : > "$R/$GA/$GA_OLD.verdict.json"
for gf in "$GA_LIVE.repair.md" "$GA_OLD.repair.md"; do { printf '# h\n\n'; fence 5; } > "$R/$GA/$gf"; done
NEARS="_bmad-output/planning-artifacts/prd-history-notes.md
_bmad-output/planning-artifacts/archived.md
_bmad-output/planning-artifacts/data-archive-policy.md
_bmad-output/planning-artifacts/s1/requirements-history.md
_bmad-output/planning-artifacts/s1/stories/story-3-archive-cleanup.md
_bmad-output/planning-artifacts/archived/x.md
_bmad-output/planning-artifacts/archive-notes/x.md
_bmad-output/planning-artifacts/carry-over-backlog.md
_bmad-output/planning-artifacts/architecture.md
_bmad-output/planning-artifacts/carry-over-backlog-archive-notes.md"
: > "$WORK/hrows.tsv"
for hp in $HSHAPES $LIVEGA $NEARS; do
  mkdir -p "$R/${hp%/*}"; { printf '# h\n\n'; fence 5; } > "$R/$hp"
done
for hp in $HSHAPES; do
  scope_in "$R" "$hp"; rc_is "Hs $hp --scope -> HISTORY" 0 "$([ "$RC" = 0 ] && [ "$SC" = HISTORY ] && echo 0 || echo 1)"
  row "$hp:3" "$CMD" > "$WORK/h1.tsv"
  rd "$R" "$WORK/h1.tsv"
  rc_is "Hr $hp stale row -> exit 0, one INFO history, no OPEN" 0 "$([ "$RC" = 0 ] && [ "$(awk -F'\t' '$1 == "INFO" && $2 == "history" { n++ } END { print n + 0 }' <<<"$OUT")" = 1 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
done
scope_in "$R" "$GA/$GA_LIVE.repair.md"; rc_is "Hl1 the LIVE-nonce sidecar in gate-adjudication/ (no slot component) --scope -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
scope_in "$R" "$GA/$GA_LIVE.verdict.json"; rc_is "Hl1b the live verdict file itself (basename equals the live stem plus .verdict.json) -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
row "$GA/$GA_LIVE.repair.md:3" "$CMD" > "$WORK/h2.tsv"; rd "$R" "$WORK/h2.tsv"
rc_is "Hl2 a stale fence in the live-nonce sidecar is OPEN and blocks (exit 1)" 0 "$([ "$RC" = 1 ] && [ "$(open_count)" = 1 ] && echo 0 || echo 1)"
scope_in "$R" "$GA/$GA_OLD.repair.md"; rc_is "Hl4 an OLDER stem in the live directory --scope -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
row "$GA/$GA_OLD.repair.md:3" "$CMD" > "$WORK/h2o.tsv"; rd "$R" "$WORK/h2o.tsv"
rc_is "Hl5 a stale fence in the older stem is INFO history, not OPEN (exit 0)" 0 "$([ "$RC" = 0 ] && [ "$(awk -F'\t' '$1 == "INFO" && $2 == "history" { n++ } END { print n + 0 }' <<<"$OUT")" = 1 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
scope_in "$R" "$GA/s303/x.md"; rc_is "Hl6 gate-adjudication/s303/x.md with current 1 -> PAST (its slot, not the live-dir rule)" 0 "$([ "$SC" = PAST ] && echo 0 || echo 1)"
scope_in "$R" "$GA/s1/x.md"; rc_is "Hl7 gate-adjudication/s<current>/x.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
R7="$WORK/rd7"; mkroot "$R7"; mkdir -p "$R7/$GA"; { printf '# h\n\n'; fence 5; } > "$R7/$GA/$GA_LIVE.repair.md"
scope_in "$R7" "$GA/$GA_LIVE.repair.md"; rc_is "Hl8 NO verdict files in the live directory -> there is no live stem, every file is HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
# the nonconforming-ts near-miss: a verdict whose ts is not [0-9]{8}T[0-9]{6}Z is not orderable and is never live
R8="$WORK/rd8"; mkroot "$R8"; mkdir -p "$R8/$GA"; : > "$R8/$GA/planning-arch.verdict.json"
scope_in "$R8" "$GA/planning-arch.repair.md"; rc_is "Hl9 only a non-conforming verdict stem -> no live stem -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
# slots in every area under _bmad-output (past 3, current 1), and the near-misses
for ar in analysis implementation-artifacts party-mode-transcripts retro-artifacts; do
  scope_in "$R" "_bmad-output/$ar/s3/x.md"; rc_is "Sl $ar/s3/x.md with current 1 -> PAST" 0 "$([ "$SC" = PAST ] && echo 0 || echo 1)"
  scope_in "$R" "_bmad-output/$ar/s1/x.md"; rc_is "Sl $ar/s1/x.md (current) -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
done
scope_in "$R" "_bmad-output/s5-notes/x.md"; rc_is "Sl1 _bmad-output/s5-notes/x.md (not a whole component) -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/x/s5.md"; rc_is "Sl2 _bmad-output/x/s5.md (the FILENAME is never a slot) -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/analysis/s3/s1/x.md"; rc_is "Sl3 two slot components: the FIRST (s3) decides -> PAST" 0 "$([ "$SC" = PAST ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/analysis/s1/archive/x.md"; rc_is "Sl4 s<current>/archive/** in a new area -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/implementation-artifacts/s1/gate-adjudication/g.md"
rc_is "Hl3 the same file rotated under s<N>/gate-adjudication/ is HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
for np in $NEARS; do
  case "$np" in
    */s1/*) want=CURRENT ;;
    *) want=LIVING ;;
  esac
  scope_in "$R" "$np"; rc_is "Hn $np (a name that only CONTAINS archive/history, no exact match) --scope -> $want" 0 "$([ "$SC" = "$want" ] && echo 0 || echo 1)"
done
scope_in "$R" "_bmad-output/planning-artifacts/s1/stories/story-3-archive-cleanup.md"; rc_is "Ha1 s<current>/stories/story-3-archive-cleanup.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/s1/requirements-history.md"; rc_is "Ha2 s<current>/requirements-history.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/data-archive-policy.md"; rc_is "Ha3 planning-artifacts/data-archive-policy.md -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/archived/x.md"; rc_is "Ha4 archived/x.md (contains archive, is not the component) -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/archive-notes/x.md"; rc_is "Ha5 archive-notes/x.md -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/s1/archive/x.md"; rc_is "Ha6 near-miss control: s<current>/archive/x.md -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/carry-over-backlog-archive.md"; rc_is "Ha7 carry-over-backlog-archive.md (a history companion the writer names) -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/architecture-history.md"; rc_is "Ha8 planning-artifacts/architecture-history.md -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/architecture-history.md"; rc_is "Ha9 _bmad-output/architecture-history.md (HISTORY anywhere under the root) -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/prd.md"; rc_is "Hc1 control: prd.md -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$R" "_bmad-output/planning-artifacts/s1/x.md"; rc_is "Hc2 control: s<current>/x.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
# the writer records nothing for a history path: the writer calls --scope per row, so HISTORY is dropped
# (the end-to-end writer world is Sp3 below, which uses a PAST path; the token is the shared definition)

# ---- Bt: --scope-batch is the SAME classification, resolved once -------------------------------------
BPATHS="$(printf '%s\n' $HSHAPES "$LIVEGA" $NEARS "$PASTDOC" "$S19DOC" "_bmad-output/specs/s317/x.md" "_bmad-output/specs/s1/x.md" "_bmad-output/party-mode/s1/seat.md" "_bmad-output/planning-artifacts/s319.md" "_bmad-output/planning-artifacts/s1/x.md" "_bmad-output/planning-artifacts/prd.md")"
batch_in() { # <root> <stdin text> -> BOUT, BRC, BERR
  BOUT="$( cd / && printf '%s' "$2" | AI_DLC_PROJECT_ROOT="$1" bash "$BIN/check-owed-derivations.sh" --scope-batch 2>"$WORK/b.err" )"; BRC=$?
  BERR="$(cat "$WORK/b.err")"
}
batch_in "$R" "$BPATHS
"
PER=""; while IFS= read -r bp; do scope_in "$R" "$bp"; PER="$PER$SC	$bp
"; done <<<"$BPATHS"
if [ "$BRC" = 0 ] && [ "$BOUT
" = "$PER" ]; then ok "Bt1 batch output over every --scope world's path equals the per-path --scope tokens (byte compare, input order)"; else bad "Bt1 batch output differs from per-path --scope"; printf '%s\n' "$BOUT" | head -5; fi
rc_is "Bt1b the batch carries all four tokens (the compare is not over one class)" 4 "$(printf '%s\n' "$BOUT" | cut -f1 | sort -u | awk 'END { print NR + 0 }')"
batch_in "$R" ""
rc_is "Bt2 empty stdin -> exit 0 and no output" 0 "$([ "$BRC" = 0 ] && [ -z "$BOUT" ] && echo 0 || echo 1)"
batch_in "$R" "$(printf '%s\n\n%s\n' "$PASTDOC" "$S19DOC")
"
rc_is "Bt3 a blank input line -> exit 2 and NO partial output" 0 "$([ "$BRC" = 2 ] && [ -z "$BOUT" ] && echo 0 || echo 1)"
R6="$WORK/rd6"; mkroot "$R6"; rm -f "$R6/.sprint-id"
batch_in "$R6" "$PASTDOC
"
rc_is "Bt4 sprint unresolvable -> exit 2 and NO partial output" 0 "$([ "$BRC" = 2 ] && [ -z "$BOUT" ] && echo 0 || echo 1)"

# Sp1/Sp2: a past-sprint break reads INFO and blocks nothing; the SAME break in the current sprint is OPEN.
row "$K_PAST" "$CMD" > "$WORK/sp1.tsv"
rd "$R" "$WORK/sp1.tsv"
rc_is "Sp1 a past-sprint (s0) stale row -> exit 0, one INFO past-sprint line, no OPEN line" 0 "$([ "$RC" = 0 ] && [ "$(info_count)" = 1 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
row "$K_STORY" "$CMD" > "$WORK/sp2.tsv"
rd "$R" "$WORK/sp2.tsv"
rc_is "Sp2 control: the same break in the current sprint (s1) -> exit 1, one OPEN, no INFO" 0 "$([ "$RC" = 1 ] && [ "$(open_count)" = 1 ] && [ "$(info_count)" = 0 ] && echo 0 || echo 1)"
# Sp4: a living document (prd.md) is OPEN
row "$K_PRD" "$CMD" > "$WORK/sp4.tsv"
rd "$R" "$WORK/sp4.tsv"
rc_is "Sp4 a living-document (prd.md) stale row -> exit 1, OPEN" 0 "$([ "$RC" = 1 ] && [ "$(open_keys)" = "$K_PRD" ] && echo 0 || echo 1)"
# Sp5: a row recorded while its sprint was current reads INFO after sprint-id moves to N+1
printf '2\n' > "$R/.sprint-id"
rd "$R" "$WORK/sp2.tsv"
rc_is "Sp5 the s1 row after the current sprint moves to 2 -> exit 0, INFO, no OPEN" 0 "$([ "$RC" = 0 ] && [ "$(info_count)" = 1 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
printf '1\n' > "$R/.sprint-id"
# Sp7: s19 is not s1 (a substring/prefix match would call it CURRENT)
row "$K_S19" "$CMD" > "$WORK/sp7.tsv"
rd "$R" "$WORK/sp7.tsv"
rc_is "Sp7 an s19 stale row with current sprint 1 -> exit 0, INFO, no OPEN" 0 "$([ "$RC" = 0 ] && [ "$(info_count)" = 1 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
# Sn: an unresolvable sprint is a refusal, never a guess and never PAST
R5="$WORK/rd5"; mkroot "$R5"; rm -f "$R5/.sprint-id"; mkdir -p "$R5/_bmad-output/planning-artifacts/s1"; cp "$R/$STORY" "$R5/$STORY"
rd "$R5" "$WORK/sp2.tsv"
rc_is "Sn1 sprint-id unresolvable with a row to judge -> exit 2" 2 "$RC"
scope_in "$R5" "_bmad-output/planning-artifacts/s1/x.md"
rc_is "Sn2 --scope with sprint-id unresolvable -> exit 2 and prints no scope" 0 "$([ "$RC" = 2 ] && [ -z "$SC" ] && echo 0 || echo 1)"

# ---- Rp: REPOINTED closure is re-derived on every read ----------------------------------------------
RPO="_bmad-output/planning-artifacts/s1/rp-old.md"
RPF="_bmad-output/planning-artifacts/s1/rp-fresh.md"
RPS="_bmad-output/planning-artifacts/s1/rp-stale.md"
RPM="_bmad-output/planning-artifacts/s1/rp-mid.md"
{ printf '# Old\n\n'; fence 5; } > "$R/$RPO"
{ printf '# Fresh\n\n'; fence 1; } > "$R/$RPF"
{ printf '# Stale\n\n'; fence 5; } > "$R/$RPS"
{ printf '# Mid\n\n'; fence 5; } > "$R/$RPM"
K_RPO="$RPO:$(line_of "$R/$RPO" '$ grep')"; K_RPF="$RPF:$(line_of "$R/$RPF" '$ grep')"
K_RPS="$RPS:$(line_of "$R/$RPS" '$ grep')"; K_RPM="$RPM:$(line_of "$R/$RPM" '$ grep')"
rp() { printf 'REPOINTED\t%s\t%s\t$ %s\n' "$1" "$2" "$3"; }
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "$K_RPF" "$CMD"; } > "$WORK/rp1.tsv"
rd "$R" "$WORK/rp1.tsv"
rc_is "Rp1 repointed to a derivation that reproduces -> closed, exit 0, nothing on stdout" 0 "$([ "$RC" = 0 ] && [ -z "$OUT" ] && echo 0 || echo 1)"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "$K_RPS" "$CMD"; } > "$WORK/rp2.tsv"
rd "$R" "$WORK/rp2.tsv"
rc_is "Rp2 repointed to a derivation that is still stale -> OPEN as REPOINTED-STALE under the OLD key" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_RPO")" = REPOINTED-STALE ] && echo 0 || echo 1)"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "_bmad-output/planning-artifacts/s1/no-such-file.md:4" "$CMD"; } > "$WORK/rp3.tsv"
rd "$R" "$WORK/rp3.tsv"
rc_is "Rp3 repointed at a file that does not exist -> OPEN as REPOINTED-MOVED" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_RPO")" = REPOINTED-MOVED ] && echo 0 || echo 1)"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "$K_RPF" "grep -c qqnone t.txt"; } > "$WORK/rp3b.tsv"
rd "$R" "$WORK/rp3b.tsv"
rc_is "Rp3b repointed at an existing file whose derived fence does not hold that command -> OPEN as REPOINTED-MOVED" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_RPO")" = REPOINTED-MOVED ] && echo 0 || echo 1)"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "$K_RPM" "$CMD"; rp "$K_RPM" "$K_RPF" "$CMD"; } > "$WORK/rp4a.tsv"
rd "$R" "$WORK/rp4a.tsv"
rc_is "Rp4a a chain OLD -> MID (stale) -> FRESH follows to the end and closes" 0 "$RC"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "$K_RPF" "$CMD"; rp "$K_RPO" "$K_RPS" "$CMD"; } > "$WORK/rp4b.tsv"
rd "$R" "$WORK/rp4b.tsv"
rc_is "Rp4b two REPOINTED for one key: the LATEST (stale) wins -> OPEN" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_RPO")" = REPOINTED-STALE ] && echo 0 || echo 1)"
# Rp6-Rp9: a REPOINTED whose target KEY equals the key being resolved (a command fixed in place) is judged
# ONCE, by content-location of the NEW command; cycles across DISTINCT keys judge the latest distinct target.
CMD2='grep -c qqzzzfixed t.txt'
SK="_bmad-output/planning-artifacts/s1/rp-same.md"
{ printf '# Same\n\n'; printf '```derived\n$ %s\n0\n```\n' "$CMD2"; } > "$R/$SK"
K_SK="$SK:$(line_of "$R/$SK" '$ grep')"
{ row "$K_SK" "$CMD"; rp "$K_SK" "$K_SK" "$CMD2"; } > "$WORK/rp6.tsv"
rd "$R" "$WORK/rp6.tsv"
rc_is "Rp6 same-key re-point, command fixed in place, fresh -> closed (exit 0)" 0 "$RC"
{ printf '# Same\n\n'; printf '```derived\n$ %s\n5\n```\n' "$CMD"; } > "$R/$SK"
{ row "$K_SK" "$CMD"; rp "$K_SK" "$K_SK" "$CMD"; } > "$WORK/rp7.tsv"
rd "$R" "$WORK/rp7.tsv"
rc_is "Rp7 same-key re-point, still stale -> OPEN as REPOINTED-STALE (never MOVED)" 0 "$([ "$RC" = 1 ] && [ "$(reason_of "$K_SK")" = REPOINTED-STALE ] && echo 0 || echo 1)"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "$K_RPM" "$CMD"; rp "$K_RPM" "$K_RPO" "$CMD"; } > "$WORK/rp8.tsv"
{ printf '# Old\n\n'; fence 1; } > "$R/$RPO"
rd "$R" "$WORK/rp8.tsv"
rc_is "Rp8 cycle A -> B -> A with the final A fresh -> closed (exit 0)" 0 "$RC"
{ printf '# Old\n\n'; fence 5; } > "$R/$RPO"
rd "$R" "$WORK/rp8.tsv"
rc_is "Rp9 cycle A -> B -> A with A stale -> OPEN" 0 "$([ "$RC" = 1 ] && [ "$(open_count)" = 1 ] && echo 0 || echo 1)"
{ row "$K_RPO" "$CMD"; rp "$K_RPO" "${K_RPO%:*}:999" "$CMD"; } > "$WORK/rp10.tsv"
{ printf '# Old\n\n'; fence 1; printf '\n'; } > "$R/$RPO"
rd "$R" "$WORK/rp10.tsv"
rc_is "Rp10 control: A:N -> A:999 (a different key) fresh by content still closes" 0 "$RC"
{ printf '# Old\n\n'; fence 5; } > "$R/$RPO"
printf 'REPOINTED\t%s\n' "$K_RPO" > "$WORK/rp5.tsv"
rd "$R" "$WORK/rp5.tsv"
rc_is "Rp5 a malformed REPOINTED row refuses the record -> exit 2" 2 "$RC"

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
# a PAST-sprint document (current sprint is 1) carrying the same break, and the scope classifier the
# writer calls: the reader copy beside a stub sprint-status.sh, installed where the consumer has it
mkdir -p "$C/_bmad-output/planning-artifacts/s0"
{ printf '# Old sprint\n\n```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n'; } > "$C/_bmad-output/planning-artifacts/s0/old.md"
cp "$BIN/check-owed-derivations.sh" "$C/scripts/ai-dlc/check-owed-derivations.sh"; write_stub "$C/scripts/ai-dlc"
printf '1\n' > "$C/.sprint-id"
K_WPAST="_bmad-output/planning-artifacts/s0/old.md:4"
# a HISTORY file INSIDE the current sprint (s1): HISTORY beats CURRENT, so the writer must drop it too
mkdir -p "$C/_bmad-output/planning-artifacts/s1/archive"
{ printf '# Archived\n\n```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n'; } > "$C/_bmad-output/planning-artifacts/s1/archive/old.md"
K_WHIST="_bmad-output/planning-artifacts/s1/archive/old.md:4"
g "$C" add -A; g "$C" commit -qm "pull to 1.0.0"
g "$DIST" show "${THEIRS}:core/scripts/toy.sh" > "$C/scripts/ai-dlc/toy.sh"
dd() { OUTD="$(cd / && TMPDIR="$WORK" bash "$DIFFER" "$DIST" "$BASE" "$C" "$THEIRS" "$@" 2>&1)"; RCD=$?; }
OWED="$WORK/owed.tsv"
dd; PRINTED_PLAIN="$OUTD"
rc_is "W0 control: the differential finds the broken derivation -> exit 1" 1 "$RCD"
rc_is "Wa without --record-owed NOTHING is written (no file named *owed* appears under the helper's TMPDIR)" 0 "$(find "$WORK" -maxdepth 1 -name '*owed*' | awk 'END { print NR + 0 }')"
dd --record-owed "$OWED" --log-name reconcile-log-t1.md
rc_is "Wb with --record-owed the exit is unchanged (1)" 1 "$RCD"
K_W="_bmad-output/story.md:4"
printed="$(awk -F'\t' '$1 == "NEWLY-FAILING" { print }' <<<"$OUTD")"
want_rec="$(awk -F'\t' -v rng="$BASE..$THEIRS" '$1 == "NEWLY-FAILING" {
  s = $3; i = index(s, "  $ "); j = index(s, "  recorded: "); k = index(s, "  actual: ")
  printf "OWED\t%s\t%s\t%s\t%s\t%s\treconcile-log-t1.md\n", $2, substr(s, i + 4, j - i - 4), substr(s, j + 12, k - j - 12), substr(s, k + 10), rng }' <<<"$OUTD")"
rc_is "Wc the record has exactly one row (the LIVING one; the past-sprint break is not recorded)" 1 "$(awk 'END { print NR + 0 }' "$OWED" 2>/dev/null)"
rc_is "Sp3a the record carries no row for the past-sprint key, and the helper never ran that file" 0 "$([ "$(awk -F'\t' -v k="$K_WPAST" '$2 == k { n++ } END { print n + 0 }' "$OWED" 2>/dev/null)" = 0 ] && [ -z "$(awk -F'\t' -v k="$K_WPAST" '$1 == "NEWLY-FAILING" && $2 == k' <<<"$OUTD")" ] && echo 0 || echo 1)"
rc_is "Hw1 the record carries no row for a history key (s1/archive/, HISTORY beats CURRENT), and the helper never ran that file" 0 "$([ "$(awk -F'\t' -v k="$K_WHIST" '$2 == k { n++ } END { print n + 0 }' "$OWED" 2>/dev/null)" = 0 ] && [ -z "$(awk -F'\t' -v k="$K_WHIST" '$1 == "NEWLY-FAILING" && $2 == k' <<<"$OUTD")" ] && echo 0 || echo 1)"
ck "Hw2 and the helper prints an INFO out-of-scope HISTORY row that names the file" "$(printf 'INFO\tout-of-scope\tHISTORY\t_bmad-output/planning-artifacts/s1/archive/old.md')" "$OUTD"
ck "Sp3b and the helper prints an INFO out-of-scope PAST row that names the file" "$(printf 'INFO\tout-of-scope\tPAST\t_bmad-output/planning-artifacts/s0/old.md')" "$OUTD"
nk "Sp3c the dropped PAST file was never RUN: the helper prints no NEWLY-FAILING row for its key" "$(printf 'NEWLY-FAILING\t%s\t' "$K_WPAST")" "$OUTD"
nk "Hw3 and the dropped HISTORY file was never RUN either" "$(printf 'NEWLY-FAILING\t%s\t' "$K_WHIST")" "$OUTD"
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
# The prose-presence arms for the three callers lived in a retired dist-only mutation battery: on a
# consumer at update step 2 the rulebook is still the old one, so a shipping arm grepping it would go red.
# GATE ARM, executed: the gate site passes iff the reader exits 0. Open row -> refuse; control -> pass.
gate_site() { rd "$1" "$2"; [ "$RC" = 0 ] && echo PASS || echo REFUSE; }
rc_is "Gd gate arm: an open row REFUSES the gate" REFUSE "$(gate_site "$R" "$WORK/b1.tsv")"
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
