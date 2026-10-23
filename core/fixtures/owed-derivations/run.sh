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
#
# THE LIVING SWEEP (S1-S10). The reader also sweeps every LIVING `_bmad-output/**/*.md` carrying a derived
# fence, with or without a record, and blocks only on a fence whose command has an ai-dlc CORE operand,
# asked of core-paths.sh --is-core. So core-paths.sh sits beside the reader copy in $BIN, and every root
# carries the core manifest at `.claude/skills/ai-dlc/core-manifest.md`, where core-paths.sh reads it.
# S1 is the acquittal probe (one core and one consumer stale fence in ONE world, exactly one OPEN line);
# S2 PAST is silent; S3 all-reproduce; S4a/S4b UNRUN core blocks, consumer silent; S5 no core-paths.sh is a
# refusal; S6 push-candidate-ledger.md stays LIVING (lead ruling); S7 an OWED row's line prints once;
# S8 deleted core operands block; S9 --scope-batch is unchanged by a stale LIVING fence; S10 --scope-batch
# from apply.sh's copy shape (reader beside the REAL sprint-status.sh and its schema, no core-paths.sh).
# S6b a superseding ledger row closes the stale one, S6c a stale superseding row does not, S6d the same
# pair outside the ledger does not; S11a-c `git -C` operands and a `-f` value block, S11n their consumer
# twins stay silent; S12a-e core DIRECTORIES block (lead ruling A), S12n consumer directories stay silent;
# S13 a validator exit 2 with no UNRUN line is a refusal (S13c its control); S14 a root-absolute core
# operand blocks.
# Mutants M1-M11, mA and mB each copy the reader, are guarded by cmp -s (no-apply is FIXTURE BROKEN), and
# must fail a named arm: M1 filter dropped, M2 filter inverted, M3 sweep removed, M4 sweep over PAST, M5
# refusal made silent, M6 absent-record early exit restored, M7 a core-paths.sh lookup ahead of the
# dispatch, M8 ledger supersession removed, M9 `-C` prefixing removed, M10 `-f` values not asked, M11 the
# directory prefix test removed, mA ls_accept_rc accepts every exit, mB the root-absolute strip and the
# trailing-slash variant removed.
# receipt-bl587.sh drives the real reader over S1's seed.
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
# The LIVING sweep asks core-paths.sh --is-core, a SIBLING of the reader, which reads the core manifest
# from the root it is run in. Both are copied beside the reader and into each root, as the installer would.
COREPATHS="$(pick "$HERE/../../scripts/core-paths.sh" \
  "$HERE/../../../scripts/ai-dlc/core-paths.sh" "$HERE/../../../core/scripts/core-paths.sh")"
MANIFEST="$(pick "$HERE/../../skills/ai-dlc/core-manifest.md" \
  "$HERE/../../../.claude/skills/ai-dlc/core-manifest.md" "$HERE/../../../core/skills/ai-dlc/core-manifest.md")"
[ -n "$COREPATHS" ] || { echo "FIXTURE ERROR: cannot locate core-paths.sh" >&2; exit 2; }
[ -n "$MANIFEST" ] || { echo "FIXTURE ERROR: cannot locate core-manifest.md" >&2; exit 2; }
SPRINTSTATUS="$(pick "$HERE/../../scripts/sprint-status.sh" \
  "$HERE/../../../scripts/ai-dlc/sprint-status.sh" "$HERE/../../../core/scripts/sprint-status.sh")"
SSSCHEMA="$(pick "$HERE/../../schemas/sprint-status.json" \
  "$HERE/../../../.claude/schemas/sprint-status.json" "$HERE/../../../core/schemas/sprint-status.json")"
[ -n "$SPRINTSTATUS" ] && [ -n "$SSSCHEMA" ] || { echo "FIXTURE ERROR: cannot locate sprint-status.sh or its schema" >&2; exit 2; }
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
cp "$COREPATHS" "$BIN/"

echo "owed-derivations:"
printf '  reader: %s\n' "$READER"
printf '  writer: %s\n' "$DIFFER"
printf 'HERMETIC-CONSUMED core/scripts/check-owed-derivations.sh\n'
printf 'HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/derivation-differential.sh\n'
printf 'HERMETIC-CONSUMED core/scripts/validate-artifact-derivations.sh\n'
printf 'HERMETIC-CONSUMED core/scripts/core-paths.sh\n'
printf 'HERMETIC-CONSUMED core/skills/ai-dlc/core-manifest.md\n'
printf 'HERMETIC-CONSUMED core/scripts/sprint-status.sh\n'
printf 'HERMETIC-CONSUMED core/schemas/sprint-status.json\n'

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
  mkdir -p "$1/scripts/ai-dlc" "$1/.claude/skills/ai-dlc" "$1/_bmad-output/planning-artifacts/s1" "$1/_bmad-output/party-mode"
  cp "$VALIDATOR" "$1/scripts/ai-dlc/validate-artifact-derivations.sh"
  cp "$MANIFEST" "$1/.claude/skills/ai-dlc/core-manifest.md"
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
# SCOPE PROBE (B4n): the B4 arms only read. Every B4 reader call goes through b4_rd, which lists $WORK
# (every path, plus the byte size of every regular file, sorted) immediately before and after that ONE
# call. Only the reader runs between the two listings, so the fixture's own seeding (empty.tsv,
# repointed-only.tsv, closed-row.tsv, dir.tsv, dangling.tsv, mal1.tsv, mal2.tsv, each written BEFORE its
# call) is in both and cancels. rd.out and rd.err are pruned: rd's own redirects rewrite them on every
# call, so they are the harness's writes, not the reader's. The reader's scratch goes to ${TMPDIR:-/tmp}
# via mktemp, a sibling of $WORK and never under it. A name, a type or a size the reader changes anywhere
# under $WORK (the record's directory, or a root it judges) is recorded in B4_WROTE.
b4_tree() {
  { find "$WORK" \( -path "$WORK/rd.out" -o -path "$WORK/rd.err" \) -prune -o -print
    find "$WORK" \( -path "$WORK/rd.out" -o -path "$WORK/rd.err" \) -prune -o -type f -exec wc -c {} +
  } 2>/dev/null | LC_ALL=C sort
}
B4_WROTE=""
b4_rd() { # <root> <record> -> rd, then notes the record if the listing of $WORK moved across the call
  local t0; t0="$(b4_tree)"
  rd "$1" "$2"
  [ "$(b4_tree)" = "$t0" ] || B4_WROTE="$B4_WROTE ${2##*/}"
}
b4_rd "$R" "$WORK/no-such-record.tsv"
rc_is "B4a no record -> exit 0" 0 "$RC"
ck "B4b and it says UNMEASURED on stdout, naming the absence" "UNMEASURED: no owed-derivations record at $WORK/no-such-record.tsv" "$OUT"
B4_ABSENT_OUT="$OUT"
: > "$WORK/empty.tsv"
b4_rd "$R" "$WORK/empty.tsv"
rc_is "B4c control: an EMPTY record exists, owes nothing -> exit 0" 0 "$RC"
ck "B4k and it says UNMEASURED with 0 OWED rows, a text the absent record does not print" "is present with 0 OWED rows" "$OUT"
nk "B4k2 and it is not the absent text" "no owed-derivations record at" "$OUT"
nk "B4k3 and the absent record's text is not the empty text" "present with 0 OWED rows" "$B4_ABSENT_OUT"
printf 'REPOINTED\t%s\t%s\t$ %s\n' "$K_PRD" "$K_STORY" "$CMD" > "$WORK/repointed-only.tsv"
b4_rd "$R" "$WORK/repointed-only.tsv"
rc_is "B4l a record holding only a REPOINTED row -> exit 0" 0 "$RC"
ck "B4l2 and it says 0 OWED rows" "is present with 0 OWED rows" "$OUT"
# Named without "owed": arm Wa counts every depth-1 *owed* name under $WORK and requires none.
row "$K_PRD" "$CMD" > "$WORK/closed-row.tsv"
b4_rd "$R2" "$WORK/closed-row.tsv"
rc_is "B4m control: an OWED row whose derivation reproduces -> exit 0" 0 "$RC"
# An arm asserting EMPTY output fails on any change that makes the subject print anything on its seed,
# so such an arm must stay specific to this seed: a scope or verdict change that reaches the seed
# is meant to turn it red.
rc_is "B4m2 and it prints nothing, so no UNMEASURED line (the record WAS measured)" 0 "$(printf '%s%s' "$OUT" "$ERR" | wc -c | tr -d ' ')"
mkdir "$WORK/dir.tsv"
b4_rd "$R" "$WORK/dir.tsv"
rc_is "B4d a record that exists as a DIRECTORY (unreadable as a file) -> exit 2" 2 "$RC"
rc_is "B4e the exit is 2 AND the refusal names the record as unreadable" 0 "$([ "$RC" = 2 ] && grep -qF 'cannot be read' <<<"$ERR" && echo 0 || echo 1)"
ln -s "$WORK/no-such-target.tsv" "$WORK/dangling.tsv"
b4_rd "$R" "$WORK/dangling.tsv"
rc_is "B4f a DANGLING symlink record (present, unreadable as a file, any uid) -> exit 2" 2 "$RC"
printf 'not a record\n' > "$WORK/mal1.tsv"
b4_rd "$R" "$WORK/mal1.tsv"
rc_is "B4g a malformed row -> exit 2" 2 "$RC"
ck "B4h and the refusal says malformed" "is malformed" "$ERR"
{ row "$K_PRD" "$CMD"; printf 'OWED\t%s\t%s\n' "$K_STORY" "$CMD"; } > "$WORK/mal2.tsv"
b4_rd "$R" "$WORK/mal2.tsv"
rc_is "B4i one malformed row among valid ones refuses the whole record -> exit 2" 2 "$RC"
nk "B4j and no OPEN line is printed for the valid row beside it" "OPEN" "$OUT"
# POSITIVE CONJUNCT: a listing that died (find erroring into 2>/dev/null) is empty on both sides and compares
# equal, which is the defect this probe replaced. mal1.tsv must appear twice, once per find pass.
B4_LIST="$(b4_tree)"
rc_is "B4n scope probe: no B4 reader call changed the listing of \$WORK (wrote under:${B4_WROTE:- none}), the listing saw mal1.tsv in both passes, and the seeded empty record is still empty" 0 "$([ -z "$B4_WROTE" ] && [ "$(grep -cF "$WORK/mal1.tsv" <<<"$B4_LIST")" = 2 ] && [ ! -s "$WORK/empty.tsv" ] && echo 0 || echo 1)"

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

# ---- S1-S10: THE LIVING SWEEP and its core-operand predicate (operator ruling (A)) ------------------
# The reader sweeps every LIVING `_bmad-output/**/*.md` carrying a derived fence, whether or not a record
# exists, and BLOCKS only on a FAIL/UNRUN whose command has an ai-dlc CORE operand (core-paths.sh --is-core).
# Consumer-code drift is silent, and THAT SILENCE IS A PREDICATE: S1 puts a core-operand FAIL and a
# consumer-operand FAIL in ONE world, so a reader that acquits everything and one that blocks everything
# both fail it. Every arm asserts the exit AND the exact set of OPEN lines.
# The roots are built ONCE and never edited, so the mutants M1-M7 below re-drive the same seeds against
# a mutated copy of the reader. lw_all <reader> <mode>: mode `real` reports each arm; mode `mut` collects
# the names of the arms that failed into LW_FAILED.
LCMD='grep -n -F qqalpha scripts/ai-dlc/x.sh'      # a CORE operand (scripts/ai-dlc/ is manifest-owned)
LCON='grep -n -F qqalpha server/x.py'              # a CONSUMER operand
LUNC="awk 'END { exit 137 }' scripts/ai-dlc/x.sh"  # killed by a signal: UNRUN, on a core operand
LUNS="awk 'END { exit 137 }' server/x.py"          # the same on a consumer operand
lfence() { printf '```derived\n$ %s\n%s\n```\n' "$1" "$2"; }
lroot() { # <dir>: mkroot plus a core file and a consumer file, each holding qqalpha on line 1
  mkroot "$1"; mkdir -p "$1/server" "$1/_bmad-output/planning-artifacts/s0" "$1/_bmad-output/ai-dlc-update"
  printf 'qqalpha\n' > "$1/scripts/ai-dlc/x.sh"; printf 'qqalpha\n' > "$1/server/x.py"
}
LPRD="_bmad-output/planning-artifacts/prd.md"
LS1="$WORK/ls1"; lroot "$LS1"
{ printf '# PRD\n\n'; lfence "$LCMD" '9:qqalpha'; printf '\n'; lfence "$LCON" '9:qqalpha'; } > "$LS1/$LPRD"
K_LS1="$LPRD:$(line_of "$LS1/$LPRD" "\$ $LCMD")"; K_LS1C="$LPRD:$(line_of "$LS1/$LPRD" "\$ $LCON")"
LS2="$WORK/ls2"; lroot "$LS2"; LPAST="_bmad-output/planning-artifacts/s0/past.md"
{ printf '# Past\n\n'; lfence "$LCMD" '9:qqalpha'; } > "$LS2/$LPAST"
LS3="$WORK/ls3"; lroot "$LS3"
{ printf '# PRD\n\n'; lfence "$LCMD" '1:qqalpha'; printf '\n'; lfence "$LCON" '1:qqalpha'; } > "$LS3/$LPRD"
LS4C="$WORK/ls4c"; lroot "$LS4C"; { printf '# PRD\n\n'; lfence "$LUNC" 1; } > "$LS4C/$LPRD"
K_LS4C="$LPRD:$(line_of "$LS4C/$LPRD" '$ awk')"
LS4S="$WORK/ls4s"; lroot "$LS4S"; { printf '# PRD\n\n'; lfence "$LUNS" 1; } > "$LS4S/$LPRD"
LS6="$WORK/ls6"; lroot "$LS6"; LLEDGER="_bmad-output/ai-dlc-update/push-candidate-ledger.md"
{ printf '# Push-candidate ledger\n\n'; lfence "$LCMD" '9:qqalpha'; } > "$LS6/$LLEDGER"
K_LS6="$LLEDGER:$(line_of "$LS6/$LLEDGER" "\$ $LCMD")"
row "$K_LS1" "$LCMD" > "$WORK/ls7.tsv"
LS8="$WORK/ls8"; lroot "$LS8"
{ printf '# PRD\n\n'; lfence 'git show HEAD:scripts/ai-dlc/gone.sh' 5; printf '\n'
  lfence 'grep -c qqalpha scripts/ai-dlc/deleted.sh' 1; printf '\n'; lfence 'grep -c qqalpha server/gone.py' 1; } > "$LS8/$LPRD"
K_LS8A="$LPRD:$(line_of "$LS8/$LPRD" '$ git show')"; K_LS8B="$LPRD:$(line_of "$LS8/$LPRD" 'deleted.sh')"
# S6b-S6d: the ledger's SUPERSESSION. S6b: S6's stale core fence plus a LATER copy of the same command that
# reproduces -> closed. S6c near-miss: the later copy is stale too -> both lines OPEN. S6d near-miss: the
# same stale-then-fresh pair in prd.md, which is not the ledger -> the first line stays OPEN.
LS6B="$WORK/ls6b"; lroot "$LS6B"
{ printf '# Push-candidate ledger\n\n## row 1\n'; lfence "$LCMD" '9:qqalpha'; printf '\n## row 2 (supersedes row 1)\n'; lfence "$LCMD" '1:qqalpha'; } > "$LS6B/$LLEDGER"
LS6C="$WORK/ls6c"; lroot "$LS6C"
{ printf '# Push-candidate ledger\n\n## row 1\n'; lfence "$LCMD" '9:qqalpha'; printf '\n## row 2\n'; lfence "$LCMD" '8:qqalpha'; } > "$LS6C/$LLEDGER"
K_LS6C1="$LLEDGER:$(line_of "$LS6C/$LLEDGER" "\$ $LCMD" 1)"; K_LS6C2="$LLEDGER:$(line_of "$LS6C/$LLEDGER" "\$ $LCMD" 2)"
LS6D="$WORK/ls6d"; lroot "$LS6D"
{ printf '# PRD\n\n'; lfence "$LCMD" '9:qqalpha'; printf '\nre-derived:\n\n'; lfence "$LCMD" '1:qqalpha'; } > "$LS6D/$LPRD"
K_LS6D="$LPRD:$(line_of "$LS6D/$LPRD" "\$ $LCMD" 1)"
# S11/S12: the asked-word set. One git-backed world (git operands need history), every fence stale.
# S11a/S11b `git -C <dir>` operands, S11c a `-f` value, S12a-e core DIRECTORIES (lead ruling A), and the
# consumer near-misses S11n/S12n in the SAME world: a `-C server` git segment, a consumer `-f` file and two
# consumer directories, each of which must stay silent.
LS11="$WORK/ls11"; lroot "$LS11"; mkdir -p "$LS11/.claude/skills/ai-dlc/steps" "$LS11/.claude/hooks" "$LS11/web/src"
printf 'qqalpha\n' > "$LS11/.claude/skills/ai-dlc/steps/a.md"; printf 'qqalpha\n' > "$LS11/.claude/hooks/ai-dlc-x.sh"
printf 'qqalpha\n' > "$LS11/web/src/a.js"
C11A='git -C scripts/ai-dlc grep -c qqalpha x.sh'
C11B='git -C .claude/skills/ai-dlc grep -c qqalpha steps/a.md'
C11C='grep -c -f scripts/ai-dlc/x.sh server/x.py'
C11N1='git -C server grep -c qqalpha x.py'
C11N2='grep -c -f server/x.py web/src/a.js'
C12A='ls .claude/skills/ai-dlc/steps'
C12B='grep -rc qqalpha .claude/hooks'
C12C='git log --format=%H -- .claude/hooks'
C12D='find .claude/skills/ai-dlc -name a.md'
C12E='git ls-files .claude/skills/ai-dlc/steps'
C12N1='ls server/'
C12N2='grep -rc qqalpha web/src'
{ printf '# PRD\n\n'
  for c in "$C11A" "$C11B" "$C11C" "$C11N1" "$C11N2" "$C12A" "$C12B" "$C12C" "$C12D" "$C12E" "$C12N1" "$C12N2"; do lfence "$c" 999; printf '\n'; done
} > "$LS11/$LPRD"
g "$LS11" init -q; g "$LS11" add -A; g "$LS11" commit -qm seed
k11() { printf '%s:%s' "$LPRD" "$(line_of "$LS11/$LPRD" "\$ $1")"; }
K_11A="$(k11 "$C11A")"; K_11B="$(k11 "$C11B")"; K_11C="$(k11 "$C11C")"; K_11N1="$(k11 "$C11N1")"; K_11N2="$(k11 "$C11N2")"
K_12A="$(k11 "$C12A")"; K_12B="$(k11 "$C12B")"; K_12C="$(k11 "$C12C")"; K_12D="$(k11 "$C12D")"; K_12E="$(k11 "$C12E")"
K_12N1="$(k11 "$C12N1")"; K_12N2="$(k11 "$C12N2")"
# S13: the validator exits 2 with NO UNRUN line. A wrapper removes a second fenced (consumer-only,
# reproducing) file, runs the real validator, then puts the file back, so the world is unchanged for the
# next reader. The reader must refuse with its "no verdict" line. S13c control: the same world, nothing removed.
LS13="$WORK/ls13"; lroot "$LS13"; LS13C="$WORK/ls13c"; lroot "$LS13C"
for d in "$LS13" "$LS13C"; do
  mv "$d/scripts/ai-dlc/validate-artifact-derivations.sh" "$d/scripts/ai-dlc/real-validator.sh"
  { printf '# PRD\n\n'; lfence "$LCON" '1:qqalpha'; } > "$d/$LPRD"
  { printf '# Notes\n\n'; lfence "$LCON" '1:qqalpha'; } > "$d/_bmad-output/planning-artifacts/notes.md"
  cp "$d/_bmad-output/planning-artifacts/notes.md" "$d/notes.keep"
done
printf '#!/usr/bin/env bash\nrm -f "%s/_bmad-output/planning-artifacts/notes.md"\nbash "%s/scripts/ai-dlc/real-validator.sh" "$@"; r=$?\ncp "%s/notes.keep" "%s/_bmad-output/planning-artifacts/notes.md"\nexit $r\n' \
  "$LS13" "$LS13" "$LS13" "$LS13" > "$LS13/scripts/ai-dlc/validate-artifact-derivations.sh"
printf '#!/usr/bin/env bash\nexec bash "%s/scripts/ai-dlc/real-validator.sh" "$@"\n' "$LS13C" > "$LS13C/scripts/ai-dlc/validate-artifact-derivations.sh"
# S14: a ROOT-ABSOLUTE core operand blocks.
LS14="$WORK/ls14"; lroot "$LS14"; C14="grep -c qqalpha $LS14/scripts/ai-dlc/x.sh"
{ printf '# PRD\n\n'; lfence "$C14" 9; } > "$LS14/$LPRD"
K_LS14="$LPRD:$(line_of "$LS14/$LPRD" "\$ $C14")"
for k in "$K_LS6C1" "$K_LS6C2" "$K_LS6D" "$K_11A" "$K_11B" "$K_11C" "$K_11N1" "$K_11N2" "$K_12A" "$K_12B" "$K_12C" "$K_12D" "$K_12E" "$K_12N1" "$K_12N2" "$K_LS14"; do
  case "$k" in *:|*::*) echo "FIXTURE ERROR: a seeded LIVING derivation line was not found ($k)" >&2; exit 2 ;; esac
done
LIN="$LPRD
$LPAST
_bmad-output/planning-artifacts/s1/x.md
$LLEDGER"
for k in "$K_LS1" "$K_LS1C" "$K_LS4C" "$K_LS6" "$K_LS8A" "$K_LS8B"; do
  case "$k" in *:|*::*) echo "FIXTURE ERROR: a seeded LIVING derivation line was not found ($k)" >&2; exit 2 ;; esac
done
# CONTROLS, reader-independent: each seed is what its world claims, by the real validator.
lv() { ( cd "$1" && AI_DLC_PROJECT_ROOT="$1" bash "$1/scripts/ai-dlc/validate-artifact-derivations.sh" "$1/$2" 2>&1 >/dev/null ); }
rc_is "S1c control: the validator FAILS both the core and the consumer fence in the S1 world" 2 "$(lv "$LS1" "$LPRD" | grep -c '^FAIL (STALE): ')"
rc_is "S2c control: the validator FAILS the past-sprint core fence" 1 "$(lv "$LS2" "$LPAST" | grep -c '^FAIL (STALE): ')"
rc_is "S4c control: the validator prints an UNRUN line for each awk-137 fence (core, consumer)" 11 "$(lv "$LS4C" "$LPRD" | grep -c '^UNRUN: ')$(lv "$LS4S" "$LPRD" | grep -c '^UNRUN: ')"
rc_is "S8c control: neither deleted core file exists, and the validator FAILS all three fences" 3 "$([ ! -e "$LS8/scripts/ai-dlc/gone.sh" ] && [ ! -e "$LS8/scripts/ai-dlc/deleted.sh" ] && lv "$LS8" "$LPRD" | grep -c '^FAIL (STALE): ')"
rc_is "S6bc control: the validator FAILS only the first ledger fence in S6b (the later copy reproduces)" 1 "$(lv "$LS6B" "$LLEDGER" | grep -c '^FAIL (')"
rc_is "S11c0 control: the validator gives a FAIL or UNRUN line for all twelve S11/S12 fences" 12 "$(lv "$LS11" "$LPRD" | grep -cE '^(FAIL \(|UNRUN: )')"
v13="$( ( cd "$LS13" && AI_DLC_PROJECT_ROOT="$LS13" bash scripts/ai-dlc/validate-artifact-derivations.sh "$LS13/$LPRD" "$LS13/_bmad-output/planning-artifacts/notes.md" > /dev/null 2> "$WORK/v13.err" ); echo $?)"
rc_is "S13c0 control: the wrapper's run exits 2 with NO UNRUN line, and the removed file is back afterwards" 0 "$([ "$v13" = 2 ] && ! grep -q '^UNRUN: ' "$WORK/v13.err" && [ -f "$LS13/_bmad-output/planning-artifacts/notes.md" ] && echo 0 || echo 1)"

open_lines() { awk -F'\t' '$1 == "OPEN"' <<<"$OUT"; }
lopen() { printf 'OPEN\t%s\tLIVING-%s\t$ %s\t-\tliving-sweep' "$1" "$2" "$3"; }
lw_rd() { # <bin> <root> <record>
  local o="$WORK/lw.out" e="$WORK/lw.err"
  ( cd / && AI_DLC_PROJECT_ROOT="$2" bash "$1/check-owed-derivations.sh" "$3" > "$o" 2> "$e" ); RC=$?
  OUT="$(cat "$o")"; ERR="$(cat "$e")"
}
lw_batch() { # <bin> <root> -> BOUT BRC
  BOUT="$( cd / && printf '%s\n' "$LIN" | AI_DLC_PROJECT_ROOT="$2" bash "$1/check-owed-derivations.sh" --scope-batch 2>/dev/null )"; BRC=$?
}
LW_MODE=real; LW_FAILED=""
lw_arm() { # <id> <description> <0 holds | 1 does not>
  if [ "$LW_MODE" = real ]; then
    if [ "$3" = 0 ]; then ok "$1 $2"; else bad "$1 $2 (exit $RC)"; printf '%s\n%s\n' "$OUT" "$ERR" | sed 's/^/        | /' | head -8; fi
  elif [ "$3" != 0 ]; then LW_FAILED="$LW_FAILED $1"; fi
}
lw_all() { # <reader> <tag>
  local b="$WORK/lw.$2/bin" b5="$WORK/lw.$2/bin5" lone="$WORK/lw.$2/lone" none="$WORK/lw.$2/no-record.tsv"
  mkdir -p "$b" "$b5" "$lone/scripts" "$lone/schemas"
  cp "$1" "$b/check-owed-derivations.sh"; cp "$COREPATHS" "$b/"; write_stub "$b"
  cp "$1" "$b5/check-owed-derivations.sh"; write_stub "$b5"
  # S10's caller shape (apply.sh's scope join): the reader ALONE beside the real sprint-status.sh and its
  # schema, with no core-paths.sh and no validator.
  cp "$1" "$lone/scripts/check-owed-derivations.sh"; cp "$SPRINTSTATUS" "$lone/scripts/sprint-status.sh"; cp "$SSSCHEMA" "$lone/schemas/sprint-status.json"
  lw_rd "$b" "$LS1" "$none"
  lw_arm S1 "acquittal probe: no record, one LIVING doc with a stale CORE fence and a stale CONSUMER fence -> exit 1 and exactly ONE OPEN line, the core one, LIVING-STALE living-sweep" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS1" STALE "$LCMD")" ] && grep -qF 'UNMEASURED: no owed-derivations record' <<<"$OUT"; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS2" "$none"
  lw_arm S2 "the same core fence in a PAST-sprint file (s0, current 1) -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS3" "$none"
  lw_arm S3 "every LIVING fence reproduces -> exit 0, no OPEN line, and the UNMEASURED line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ] && grep -qF 'UNMEASURED: no owed-derivations record' <<<"$OUT"; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS4C" "$none"
  lw_arm S4a "a core-operand UNRUN in a LIVING doc -> exit 1, exactly one OPEN, LIVING-UNRUN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS4C" UNRUN "$LUNC")" ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS4S" "$none"
  lw_arm S4b "a consumer-operand UNRUN in a LIVING doc -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_rd "$b5" "$LS1" "$none"
  lw_arm S5 "core-paths.sh absent beside the reader, S1's seed -> exit 2 with a REFUSED line and no OPEN line" "$({ [ "$RC" = 2 ] && grep -qF 'REFUSED: no core-paths.sh beside' <<<"$ERR" && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS6" "$none"
  lw_arm S6 "push-candidate-ledger.md stays LIVING (lead ruling): its stale core fence -> exit 1, its OPEN line printed" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS1" "$WORK/ls7.tsv"
  lw_arm S7 "collision: an OWED row on prd.md:K whose fence is stale prints ONCE, as STALE, never again as LIVING-STALE" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(printf 'OPEN\t%s\tSTALE\t$ %s\tbase..theirs\treconcile-log-x' "$K_LS1" "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS8" "$none"
  lw_arm S8 "deleted core operands block (git show HEAD:scripts/ai-dlc/gone.sh, plain scripts/ai-dlc/deleted.sh); a deleted consumer one does not" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS8A" STALE 'git show HEAD:scripts/ai-dlc/gone.sh')
$(lopen "$K_LS8B" STALE 'grep -c qqalpha scripts/ai-dlc/deleted.sh')" ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS6B" "$none"
  lw_arm S6b "the ledger's stale core fence plus a LATER copy of the same command that reproduces (a superseding row) -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ] && grep -qF 'UNMEASURED: no owed-derivations record' <<<"$OUT"; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS6C" "$none"
  lw_arm S6c "near-miss: the later ledger copy is stale too -> exit 1, BOTH lines OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6C1" STALE "$LCMD")
$(lopen "$K_LS6C2" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS6D" "$none"
  lw_arm S6d "near-miss: the same stale-then-fresh pair in prd.md (not the ledger) -> exit 1, the first line OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6D" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS11" "$none"
  local o11="$OUT" r11="$RC"
  has_open() { awk -F'\t' -v k="$1" '$1 == "OPEN" && $2 == k && $6 == "living-sweep" { f = 1 } END { exit f ? 0 : 1 }' <<<"$o11"; }
  lw_arm S11a "git -C scripts/ai-dlc grep ... x.sh blocks (the -C directory is prefixed onto the operand)" "$({ [ "$r11" = 1 ] && has_open "$K_11A"; } && echo 0 || echo 1)"
  lw_arm S11b "git -C .claude/skills/ai-dlc grep ... steps/a.md blocks" "$({ [ "$r11" = 1 ] && has_open "$K_11B"; } && echo 0 || echo 1)"
  lw_arm S11c "grep -c -f scripts/ai-dlc/x.sh server/x.py blocks (the -f value is asked)" "$({ [ "$r11" = 1 ] && has_open "$K_11C"; } && echo 0 || echo 1)"
  lw_arm S11n "near-miss, same world: git -C server and a consumer -f file stay silent" "$({ ! has_open "$K_11N1" && ! has_open "$K_11N2"; } && echo 0 || echo 1)"
  lw_arm S12a "ls .claude/skills/ai-dlc/steps (a core DIRECTORY) blocks" "$({ [ "$r11" = 1 ] && has_open "$K_12A"; } && echo 0 || echo 1)"
  lw_arm S12b "grep -rc qqalpha .claude/hooks blocks" "$({ [ "$r11" = 1 ] && has_open "$K_12B"; } && echo 0 || echo 1)"
  lw_arm S12c "git log --format=%H -- .claude/hooks blocks" "$({ [ "$r11" = 1 ] && has_open "$K_12C"; } && echo 0 || echo 1)"
  lw_arm S12d "find .claude/skills/ai-dlc -name a.md blocks" "$({ [ "$r11" = 1 ] && has_open "$K_12D"; } && echo 0 || echo 1)"
  lw_arm S12e "git ls-files .claude/skills/ai-dlc/steps blocks" "$({ [ "$r11" = 1 ] && has_open "$K_12E"; } && echo 0 || echo 1)"
  lw_arm S12n "near-miss, same world: consumer directories server/ and web/src stay silent" "$({ ! has_open "$K_12N1" && ! has_open "$K_12N2"; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS13" "$none"
  lw_arm S13 "the validator exits 2 with no UNRUN line (a candidate vanished) -> exit 2 with the no-verdict REFUSED line, no OPEN" "$({ [ "$RC" = 2 ] && grep -qF 'with no verdict for every file it was given' <<<"$ERR" && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS13C" "$none"
  lw_arm S13c "control: the same world with nothing removed -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_rd "$b" "$LS14" "$none"
  lw_arm S14 "a ROOT-ABSOLUTE core operand (\$ROOT/scripts/ai-dlc/x.sh) blocks" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS14" STALE "$C14")" ]; } && echo 0 || echo 1)"
  lw_batch "$b" "$LS1"; local s9a="$BOUT" s9r="$BRC"
  lw_batch "$b" "$LS3"
  lw_arm S9 "--scope-batch output and exit are byte-identical with (S1 root) and without (S3 root) a stale LIVING core fence" \
    "$({ [ "$s9r" = 0 ] && [ "$BRC" = 0 ] && [ "$s9a" = "$BOUT" ] && [ "$(printf '%s\n' "$BOUT" | cut -f1 | tr '\n' ' ')" = "LIVING PAST CURRENT LIVING " ]; } && echo 0 || echo 1)"
  local s10full="$s9a"
  BOUT="$( cd / && printf '%s\n' "$LIN" | AI_DLC_PROJECT_ROOT="$LS1" bash "$lone/scripts/check-owed-derivations.sh" --scope-batch 2>/dev/null )"; BRC=$?
  lw_arm S10 "apply.sh's copy shape (reader + real sprint-status.sh + schema, NO core-paths.sh, no validator): --scope-batch over a root with a stale LIVING core fence -> exit 0, byte-identical to the full sibling set" \
    "$({ [ ! -e "$lone/scripts/core-paths.sh" ] && [ "$BRC" = 0 ] && [ -n "$s10full" ] && [ "$BOUT" = "$s10full" ]; } && echo 0 || echo 1)"
}
lw_all "$BIN/check-owed-derivations.sh" real

# ---- M1-M7: each mutant is a COPY of the reader, guarded by cmp -s; one that does not apply is BROKEN --
# mut_line <src> <dst> <occurrence> <exact old line> <new text>: replaces that occurrence of the whole line.
mut_line() {
  O="$4" N="$5" awk -v occ="$3" 'BEGIN { o = ENVIRON["O"]; nw = ENVIRON["N"] } $0 == o && ++c == occ { print nw; next } { print }' "$1" > "$2" || return 1
  ! cmp -s "$1" "$2"
}
LW_MODE=mut
mut_case() { # <id> <must-fail arms, space-separated> <occurrence> <old line> <new text> [<occ2> <old2> <new2>]
  local m="$WORK/mut.$1.sh" a miss=""
  if ! mut_line "$BIN/check-owed-derivations.sh" "$m" "$3" "$4" "$5"; then
    bad "$1 FIXTURE BROKEN: the mutation did not apply (anchor not found), so it is not scored"; return
  fi
  if [ "$#" -ge 8 ]; then
    if ! mut_line "$m" "$m.2" "$6" "$7" "$8"; then
      bad "$1 FIXTURE BROKEN: the second mutation did not apply (anchor not found), so it is not scored"; return
    fi
    mv "$m.2" "$m"
  fi
  LW_FAILED=""; lw_all "$m" "$1"
  for a in $2; do case " $LW_FAILED " in *" $a "*) ;; *) miss="$miss $a" ;; esac; done
  if [ -z "$miss" ]; then ok "$1 killed: arm(s)$LW_FAILED failed (required: $2)"; else bad "$1 SURVIVED: arm(s)$miss did not fail (failed:${LW_FAILED:- none})"; fi
}
mut_case M1 "S1" 1 '    grep -qxF -- "$_id" "$TMP/ls.core" || continue' '    :'
mut_case M2 "S1" 1 '    grep -qxF -- "$_id" "$TMP/ls.core" || continue' '    grep -qxF -- "$_id" "$TMP/ls.core" && continue'
mut_case M3 "S1 S6" 1 '  living_sweep' '  :'
mut_case M4 "S2" 1 '    [ "$SCOPE_TOKEN" = LIVING ] || continue' '    [ "$SCOPE_TOKEN" = LIVING ] || [ "$SCOPE_TOKEN" = PAST ] || continue'
mut_case M5 "S5" 1 '  [ -f "$SELF_DIR/core-paths.sh" ] \' '  [ -f "$SELF_DIR/core-paths.sh" ] || return 0; [ -f "$SELF_DIR/core-paths.sh" ] \'
mut_case M6 "S1" 1 '  sweep_and_exit 0' '  exit 0'
mut_case M7 "S10" 1 'if [ "${1:-}" = "--scope-batch" ]; then' '[ -f "$SELF_DIR/core-paths.sh" ] || { echo "REFUSED: no core-paths.sh beside $0" >&2; exit 2; }
if [ "${1:-}" = "--scope-batch" ]; then'
mut_case M8 "S6b" 1 '    if [ "$_c" = "$LEDGER_REL" ] && ledger_superseded "$_i" "$_c" "$_ln" "$_cmd"; then continue; fi' '    :'
mut_case M9 "S11a S11b" 1 '    case "$_q" in git\ *) ;; *) continue ;; esac' '    continue'
mut_case M10 "S11c" 1 '  awk -F'"'"'\t'"'"' '"'"'$2 == "WORD" && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { print $1 "\t" $7 }'"'"' "$TMP/ls.explain" > "$TMP/ls.ops"' \
  '  awk -F'"'"'\t'"'"' '"'"'$2 == "WORD" && $5 == "operand" { print $1 "\t" $7 }'"'"' "$TMP/ls.explain" > "$TMP/ls.ops"'
mut_case M11 "S12a S12b S12c S12d S12e" 1 '      case "$_globsnl" in *"$NL${_t%/}/"*) printf '"'"'%s\n'"'"' "$_id" >> "$TMP/ls.core"; break ;; esac' '      :'
mut_case mA "S13" 1 '  local nref' '  return 0'
mut_case mB "S14" 1 '      _t="${_t#"$ROOT"/}"' '      :' 1 '      for _k in "$_t" "${_t%/}/"; do' '      for _k in "$_t"; do'
LW_MODE=real

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
