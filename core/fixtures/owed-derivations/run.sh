#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# owed-derivations — assert a derivation an operator LEAVES broken stays owed until it is re-pointed.
#
# Usage: run.sh [--matrix] [<check-owed-derivations.sh> [<derivation-differential.sh>]]
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
# CH1/CH2 a chain FAILing ALLOWLIST with a core operand (before `;`, in a second `&&` segment) blocks as
# LIVING-ALLOWLIST, CH1n its consumer twin stays silent, MV1 a validator mutant without its explain_chain
# call fails CH1 and CH2 only;
# S13 a validator exit 2 with no UNRUN line is a refusal (S13c its control); S14 a root-absolute core
# operand blocks. S6e-S6g a later ledger copy the validator never RUNS (unclosed fence, indented output
# line, CRLF opener) acquits nothing; PU an OWED row whose only copy is in an unclosed fence reads MOVED;
# LF a failing `--list` is a refusal, B8c also over a file whose own run gave no verdict.
# One world with a blocking core control GC: G1/G2 `git -C web` consumer words stay silent; RP1
# `git -C web show HEAD:scripts/ai-dlc/x.sh` blocks (a rev:path resolves from the root), RP2 `HEAD:./x.sh`
# stays silent; SL1/SL2 `tests/` and `scripts/` stay silent (lead ruling Q1); CD1 the `-C` directory is
# not asked (lead ruling Q2) and CD2 `git -C scripts/ai-dlc grep ... x.sh` still blocks; RP3 `-C ... show :0:./x.sh`, RP4 plain `show :0:<core path>`,
# RP5 `-C ... show HEAD:./x.sh` and PP a `git -C` segment followed by a core-operand segment all block;
# CDD1-CDD3 `web/../scripts/ai-dlc/x.sh` collapsed (a rev:path, a plain word, a second -C) block, CDD4
# `../server/y.txt` stays silent, CDD5 a symlinked segment before `..` over-asks and blocks; S15n exactly
# eleven OPEN.
# Mutants M1-M11, mA and mB each copy the reader, are guarded by cmp -s (no-apply is FIXTURE BROKEN), and
# must fail a named arm: M1 filter dropped, M2 filter inverted, M3 sweep removed, M4 sweep over PAST, M5
# refusal made silent, M6 absent-record early exit restored, M7 a core-paths.sh lookup ahead of the
# dispatch, M8 ledger supersession removed, M9 `-C` prefixing removed, M10 `-f` values not asked, M11 the
# directory prefix test removed, mA ls_accept_rc accepts every exit, mB the root-absolute strip and the
# trailing-slash variant removed, M12 the raw-scan locator restored in the ledger supersession, M12b the
# same in pass 2, M13 a `git -C` segment's WORD lines asked again, M14 a failing `--list` in pass 2 read
# UNASSESSED over a file whose own run gave no verdict, M20 a reproducing LIVING fence opened, M21 LIVING
# verdicts leaking into --scope-batch, M22 every validator exit refused.
# THE MUTANT x ARM MATRIX, re-measured whenever an arm or a mutant is added or changed. `--matrix` runs every
# mutant over every LIVING world and prints a `MATRIX<TAB><mutant><TAB><arm><TAB><FAIL|ok>` row per arm.
# Per push each mutant runs only its DECIDING arm (which must FAIL) and its TWINS (arms the matrix shows
# GREEN under it, which must HOLD), so only the worlds holding them. Whether a mutant kills its own arm alone
# is a property of the battery, settled here and not on every push.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/owed-derivations/run.sh --matrix
# MUTANT-MATRIX M1 decides=S1 twins=GC
# MUTANT-MATRIX M2 decides=S1 twins=S3
# MUTANT-MATRIX M3 decides=S1 twins=S2
# MUTANT-MATRIX M4 decides=S2 twins=S1
# MUTANT-MATRIX M5 decides=S5 twins=S1
# MUTANT-MATRIX M6 decides=S1 twins=S3
# MUTANT-MATRIX M7 decides=S10 twins=S9
# MUTANT-MATRIX M8 decides=S6b twins=S6c
# MUTANT-MATRIX M9 decides=S11a twins=S11n
# MUTANT-MATRIX M10 decides=S11c twins=S11n
# MUTANT-MATRIX M11 decides=S12a twins=S12n
# MUTANT-MATRIX M12 decides=S6e twins=S6b
# MUTANT-MATRIX M12b decides=PU twins=S7
# MUTANT-MATRIX M13 decides=G1 twins=GC
# MUTANT-MATRIX M14 decides=B8c twins=LF
# MUTANT-MATRIX M15 decides=RP3 twins=RP2
# MUTANT-MATRIX M16 decides=RP5 twins=RP2
# MUTANT-MATRIX M17 decides=PP twins=G1
# MUTANT-MATRIX M18 decides=CDD1 twins=CDD4
# MUTANT-MATRIX M19 decides=CDD5 twins=CDD4
# MUTANT-MATRIX M20 decides=S3 twins=S4b
# MUTANT-MATRIX M21 decides=S9 twins=S10
# MUTANT-MATRIX M22 decides=S13c twins=S13
# MUTANT-MATRIX mA decides=S13 twins=S13c
# MUTANT-MATRIX mB decides=S14 twins=S1
# MUTANT-MATRIX MV1 decides=CH1 twins=CH1n
# The full failing sets, as measured: M1 S1 S4b S7 S8 S6f G1 G2 RP2 SL1 SL2 CD1 CDD4 S15n S11n S12n CH1n CH3
# CH4 CH6; M2 every core-blocking arm plus S4b S7 RP2 SL1 SL2 CD1 CDD4 S11n S12n CH1n (48 arms); M3 and M6
# every blocking arm (39); M4 S2; M5 S5; M7 S10; M8 S6b; M9 RP1 CD2 RP3 RP5 CDD1-3 CDD5 S15n S11a S11b; M10
# S11c; M11 S12a-e; M12 S6e S6f S6g; M12b PU; M13 G1 G2 S15n; M14 B8c; M15 RP3 RP4 S15n; M16 RP3 RP5 S15n;
# M17 PP S15n; M18 CDD1-3 CDD5 S15n; M19 CDD5 S15n; M20 S1 S3 S4a S6 S8 S6b-g S15n CH1-6 S14; M21 S9; M22
# S13c plus every blocking arm (40); mA S13; mB S14; MV1 CH1-CH6.
# `lw_world` RESETS every shared world-level global (LW_RESET_VARS) on entry, in both modes, so a filtered mutant
# run starts each selected world from the same state the live pass does. RSET holds that list EQUAL to the set of
# variables the drivers and world bodies assign, derived from this file's own text; RSETf and RSETp seed a copy both
# ways, and RSETr drives a world pair through the real lw_world. CPY holds the copy lw_all runs byte-identical to the reader.
# MUTANT-MATRIX-DYNAMIC mut_score why=mut_case and MV1 pass their mutant id to mutant_killed as a variable; each id keeps its own MUTANT-MATRIX row above
# MUTANT-MATRIX BL706-M1 decides=B7b twins=B7a,B7c
# MUTANT-MATRIX BL706-M2 decides=B7e twins=B7a,B7b
# MUTANT-MATRIX BL706-M3 decides=B7g twins=B7b
# MUTANT-MATRIX BL706-M4 decides=B7d twins=B7b
# MUTANT-MATRIX BL706-M5 decides=B7c twins=B7a
# MUTANT-MATRIX BL706-M6 decides=B7h twins=B7a
# MUTANT-MATRIX BL706-M7 decides=B7h twins=B7a
# MUTANT-MATRIX BL706-M8 decides=B7a twins=B7h
# MUTANT-MATRIX BL706-M9 decides=B7j twins=B7b
# MUTANT-MATRIX BL706-M10 decides=B7k twins=B7e
# MUTANT-MATRIX BL706-M11 decides=B7i twins=B7f
# MUTANT-MATRIX BL706-M12 decides=B7l twins=B7b,B7d
# MUTANT-MATRIX BL706-M13 decides=B7e2 twins=B7e
# MUTANT-MATRIX-DYNAMIC b7_mut why=b7_mut passes its mutant id (BL706-M1, M2, M4 to M13) to mutant_killed as a variable; each id keeps its own MUTANT-MATRIX row above
# BL706 (B7 cells) measured by: bash core/fixtures/owed-derivations/receipt-bl706.sh, whose CELL lines the B7 arms read; mutants M1 to M8 each copy the whole reconcile/ directory.
# receipt-bl587.sh drives the real reader over S1's seed; receipt-bl801.sh drives the world filter.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
# `--matrix`, parsed FIRST and shifted off, is the MATRIX mode (see the MUTANT-MATRIX header lines): every
# mutant runs over every LIVING world. It is an argument because hermetic-run.sh runs a fixture under `env -i`.
OWED_MATRIX=0
if [ "${1:-}" = --matrix ]; then OWED_MATRIX=1; shift; fi
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
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# MATRIX mode (`--matrix`): every mutant runs over every LIVING world and prints one
# `MATRIX<TAB><mutant><TAB><arm><TAB><FAIL|ok>` row per recorded arm. Per-push (the default) runs each mutant's
# deciding arm and its named twins only.
[ "$OWED_MATRIX" = 1 ] && echo "MATRIX-MODE on"
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
# it answers `--list` with a valid listing for its file (the real validator's shape), so B8b isolates the
# no-verdict run from the listing
printf '#!/usr/bin/env bash\nif [ "${1:-}" = --list ]; then printf "  %%s:%%s  %%s\\n" "%s/%s" "%s" "%s"; exit 0; fi\necho "REFUSED: seeded" >&2\nexit 2\n' "$R4" "$LIVE2" "${K_LIVE2##*:}" "$CMD" > "$R4/scripts/ai-dlc/validate-artifact-derivations.sh"
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
# THE H SEEDS LIVE IN THEIR OWN ROOTS, never in $R: every record-mode reader call sweeps every LIVING
# fenced file of its root, so a seed in $R was re-validated by every later B/Sp/Rp/G call that never
# reads it. $RH holds the history shapes, the live gate-adjudication directory (its verdict files fix
# the live stem) and LIVEGA; it is the root of every Hr/Hl record call and of the --scope arms over
# those paths. $RN holds the NEARS near-misses, which classify LIVING and would be swept by a record
# call; only --scope reads them. Both carry mkroot's `.sprint-id` (1). --scope is path-only plus the
# sprint id and the live stem, so the Sl/Sl1-4/Ha/Hc arms, which name paths no root holds, read $RH.
RH="$WORK/rdh"; mkroot "$RH"
RN="$WORK/rdn"; mkroot "$RN"
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
mkdir -p "$RH/$GA"
: > "$RH/$GA/$GA_LIVE.verdict.json"; : > "$RH/$GA/$GA_OLD.verdict.json"
for gf in "$GA_LIVE.repair.md" "$GA_OLD.repair.md"; do { printf '# h\n\n'; fence 5; } > "$RH/$GA/$gf"; done
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
for hp in $HSHAPES $LIVEGA; do
  mkdir -p "$RH/${hp%/*}"; { printf '# h\n\n'; fence 5; } > "$RH/$hp"
done
for hp in $NEARS; do
  mkdir -p "$RN/${hp%/*}"; { printf '# h\n\n'; fence 5; } > "$RN/$hp"
done
# Hr: ONE record of thirteen stale rows, one per shape, and ONE reader call. Each shape's arm asserts its
# OWN key's INFO history line (the reader's text at check-owed-derivations.sh:799, `<key> is in a history
# file`) appears exactly once and no OPEN line carries that key, so a classifier that drops one shape fails
# that shape's arm and no other. Hr0 asserts the record as a whole: exit 0, no OPEN line, thirteen INFO.
: > "$WORK/h1.tsv"; nh=0
for hp in $HSHAPES; do
  scope_in "$RH" "$hp"; rc_is "Hs $hp --scope -> HISTORY" 0 "$([ "$RC" = 0 ] && [ "$SC" = HISTORY ] && echo 0 || echo 1)"
  row "$hp:3" "$CMD" >> "$WORK/h1.tsv"; nh=$((nh + 1))
done
rd "$RH" "$WORK/h1.tsv"
rc_is "Hr0 the $nh-row history record (one row per shape) -> exit 0, exactly $nh INFO history lines, no OPEN" 0 "$([ "$nh" = 13 ] && [ "$RC" = 0 ] && [ "$(awk -F'\t' '$1 == "INFO" && $2 == "history" { n++ } END { print n + 0 }' <<<"$OUT")" = 13 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
for hp in $HSHAPES; do
  rc_is "Hr $hp stale row -> exit 0, one INFO history, no OPEN" 0 "$([ "$(P="$hp:3 is in a history file" awk -F'\t' 'BEGIN { p = ENVIRON["P"] } $1 == "INFO" && $2 == "history" && index($3, p) == 1 { n++ } END { print n + 0 }' <<<"$OUT")" = 1 ] && [ "$(K="$hp:3" awk -F'\t' 'BEGIN { k = ENVIRON["K"] } $1 == "OPEN" && $2 == k { n++ } END { print n + 0 }' <<<"$OUT")" = 0 ] && echo 0 || echo 1)"
done
scope_in "$RH" "$GA/$GA_LIVE.repair.md"; rc_is "Hl1 the LIVE-nonce sidecar in gate-adjudication/ (no slot component) --scope -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
scope_in "$RH" "$GA/$GA_LIVE.verdict.json"; rc_is "Hl1b the live verdict file itself (basename equals the live stem plus .verdict.json) -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
row "$GA/$GA_LIVE.repair.md:3" "$CMD" > "$WORK/h2.tsv"; rd "$RH" "$WORK/h2.tsv"
rc_is "Hl2 a stale fence in the live-nonce sidecar is OPEN and blocks (exit 1)" 0 "$([ "$RC" = 1 ] && [ "$(open_count)" = 1 ] && echo 0 || echo 1)"
scope_in "$RH" "$GA/$GA_OLD.repair.md"; rc_is "Hl4 an OLDER stem in the live directory --scope -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
row "$GA/$GA_OLD.repair.md:3" "$CMD" > "$WORK/h2o.tsv"; rd "$RH" "$WORK/h2o.tsv"
rc_is "Hl5 a stale fence in the older stem is INFO history, not OPEN (exit 0)" 0 "$([ "$RC" = 0 ] && [ "$(awk -F'\t' '$1 == "INFO" && $2 == "history" { n++ } END { print n + 0 }' <<<"$OUT")" = 1 ] && [ "$(open_count)" = 0 ] && echo 0 || echo 1)"
scope_in "$RH" "$GA/s303/x.md"; rc_is "Hl6 gate-adjudication/s303/x.md with current 1 -> PAST (its slot, not the live-dir rule)" 0 "$([ "$SC" = PAST ] && echo 0 || echo 1)"
scope_in "$RH" "$GA/s1/x.md"; rc_is "Hl7 gate-adjudication/s<current>/x.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
R7="$WORK/rd7"; mkroot "$R7"; mkdir -p "$R7/$GA"; { printf '# h\n\n'; fence 5; } > "$R7/$GA/$GA_LIVE.repair.md"
scope_in "$R7" "$GA/$GA_LIVE.repair.md"; rc_is "Hl8 NO verdict files in the live directory -> there is no live stem, every file is HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
# the nonconforming-ts near-miss: a verdict whose ts is not [0-9]{8}T[0-9]{6}Z is not orderable and is never live
R8="$WORK/rd8"; mkroot "$R8"; mkdir -p "$R8/$GA"; : > "$R8/$GA/planning-arch.verdict.json"
scope_in "$R8" "$GA/planning-arch.repair.md"; rc_is "Hl9 only a non-conforming verdict stem -> no live stem -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
# slots in every area under _bmad-output (past 3, current 1), and the near-misses
for ar in analysis implementation-artifacts party-mode-transcripts retro-artifacts; do
  scope_in "$RH" "_bmad-output/$ar/s3/x.md"; rc_is "Sl $ar/s3/x.md with current 1 -> PAST" 0 "$([ "$SC" = PAST ] && echo 0 || echo 1)"
  scope_in "$RH" "_bmad-output/$ar/s1/x.md"; rc_is "Sl $ar/s1/x.md (current) -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
done
scope_in "$RH" "_bmad-output/s5-notes/x.md"; rc_is "Sl1 _bmad-output/s5-notes/x.md (not a whole component) -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/x/s5.md"; rc_is "Sl2 _bmad-output/x/s5.md (the FILENAME is never a slot) -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/analysis/s3/s1/x.md"; rc_is "Sl3 two slot components: the FIRST (s3) decides -> PAST" 0 "$([ "$SC" = PAST ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/analysis/s1/archive/x.md"; rc_is "Sl4 s<current>/archive/** in a new area -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/implementation-artifacts/s1/gate-adjudication/g.md"
rc_is "Hl3 the same file rotated under s<N>/gate-adjudication/ is HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
for np in $NEARS; do
  case "$np" in
    */s1/*) want=CURRENT ;;
    *) want=LIVING ;;
  esac
  scope_in "$RN" "$np"; rc_is "Hn $np (a name that only CONTAINS archive/history, no exact match) --scope -> $want" 0 "$([ "$SC" = "$want" ] && echo 0 || echo 1)"
done
scope_in "$RH" "_bmad-output/planning-artifacts/s1/stories/story-3-archive-cleanup.md"; rc_is "Ha1 s<current>/stories/story-3-archive-cleanup.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/s1/requirements-history.md"; rc_is "Ha2 s<current>/requirements-history.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/data-archive-policy.md"; rc_is "Ha3 planning-artifacts/data-archive-policy.md -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/archived/x.md"; rc_is "Ha4 archived/x.md (contains archive, is not the component) -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/archive-notes/x.md"; rc_is "Ha5 archive-notes/x.md -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/s1/archive/x.md"; rc_is "Ha6 near-miss control: s<current>/archive/x.md -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/carry-over-backlog-archive.md"; rc_is "Ha7 carry-over-backlog-archive.md (a history companion the writer names) -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/architecture-history.md"; rc_is "Ha8 planning-artifacts/architecture-history.md -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/architecture-history.md"; rc_is "Ha9 _bmad-output/architecture-history.md (HISTORY anywhere under the root) -> HISTORY" 0 "$([ "$SC" = HISTORY ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/prd.md"; rc_is "Hc1 control: prd.md -> LIVING" 0 "$([ "$SC" = LIVING ] && echo 0 || echo 1)"
scope_in "$RH" "_bmad-output/planning-artifacts/s1/x.md"; rc_is "Hc2 control: s<current>/x.md -> CURRENT" 0 "$([ "$SC" = CURRENT ] && echo 0 || echo 1)"
# the writer records nothing for a history path: the writer calls --scope per row, so HISTORY is dropped
# (the end-to-end writer world is Sp3 below, which uses a PAST path; the token is the shared definition)

# ---- Bt: --scope-batch is the SAME classification, resolved once -------------------------------------
BPATHS="$(printf '%s\n' $HSHAPES "$LIVEGA" $NEARS "$PASTDOC" "$S19DOC" "_bmad-output/specs/s317/x.md" "_bmad-output/specs/s1/x.md" "_bmad-output/party-mode/s1/seat.md" "_bmad-output/planning-artifacts/s319.md" "_bmad-output/planning-artifacts/s1/x.md" "_bmad-output/planning-artifacts/prd.md")"
batch_in() { # <root> <stdin text> -> BOUT, BRC, BERR
  BOUT="$( cd / && printf '%s' "$2" | AI_DLC_PROJECT_ROOT="$1" bash "$BIN/check-owed-derivations.sh" --scope-batch 2>"$WORK/b.err" )"; BRC=$?
  BERR="$(cat "$WORK/b.err")"
}
batch_in "$RH" "$BPATHS
"
PER=""; while IFS= read -r bp; do scope_in "$RH" "$bp"; PER="$PER$SC	$bp
"; done <<<"$BPATHS"
if [ "$BRC" = 0 ] && [ "$BOUT
" = "$PER" ]; then ok "Bt1 batch output over every --scope world's path equals the per-path --scope tokens (byte compare, input order)"; else bad "Bt1 batch output differs from per-path --scope"; printf '%s\n' "$BOUT" | head -5; fi
rc_is "Bt1b the batch carries all four tokens (the compare is not over one class)" 4 "$(printf '%s\n' "$BOUT" | cut -f1 | sort -u | awk 'END { print NR + 0 }')"
batch_in "$RH" ""
rc_is "Bt2 empty stdin -> exit 0 and no output" 0 "$([ "$BRC" = 0 ] && [ -z "$BOUT" ] && echo 0 || echo 1)"
batch_in "$RH" "$(printf '%s\n\n%s\n' "$PASTDOC" "$S19DOC")
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
LUNC="awk 'END { exit 137 }' scripts/ai-dlc/x.sh"  # ended by a signal: UNRUN, on a core operand
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
# CH1/CH1n/CH2: CHAINS the substring ban refuses, so each FAILs ALLOWLIST. The validator's --explain-cmd
# prints the ARGV/WORD lines of every safe segment (the `echo "exit:$?"` segment expands `$?` and prints
# none). CH1 a core operand before `;`, CH1n its consumer twin, CH2 a core operand in the SECOND `&&` segment.
C13A='grep -n x .claude/skills/ai-dlc/steps/retro.md; echo "exit:$?"'
C13N='grep -n x server/x.py; echo "exit:$?"'
C13B='grep -c qqalpha server/x.py && grep -c qqalpha .claude/skills/ai-dlc/steps/a.md'
# CH3: the CH1 operand behind a literal `cd web &&`. The validator carries the cd, so the operand is
# explained as web/.claude/..., which is not core: the row stays silent while CH1 still opens.
C13C='cd web && grep -n x .claude/skills/ai-dlc/steps/retro.md'
# CH4: grep's PATTERN behind a literal cd into a directory a core glob sits under. A prefixed pattern
# would read `.claude/skills/ai-dlc`, which the directory rule asks as core. grep is OFF the cd list
# (its option table does not know `--label`/`--context` on this machine's grep), so nothing of the
# grep segment is explained under the prefix and no word of it is asked.
C13D='cd .claude/skills && grep -n ai-dlc README.md'
# CH5: CH4's POSITIVE twin -- the carry reaches a core file, so a silently dead carry fails it.
# CH6: an off-list command under a prefix (echo's word is text) is never explained.
C13E='cd .claude/skills && cat ai-dlc/SKILL.md'
C13F='cd scripts && echo ai-dlc'
{ printf '# PRD\n\n'
  for c in "$C11A" "$C11B" "$C11C" "$C11N1" "$C11N2" "$C12A" "$C12B" "$C12C" "$C12D" "$C12E" "$C12N1" "$C12N2" "$C13A" "$C13N" "$C13B" "$C13C" "$C13D" "$C13E" "$C13F"; do lfence "$c" 999; printf '\n'; done
} > "$LS11/$LPRD"
g "$LS11" init -q; g "$LS11" add -A; g "$LS11" commit -qm seed
k11() { printf '%s:%s' "$LPRD" "$(line_of "$LS11/$LPRD" "\$ $1")"; }
K_11A="$(k11 "$C11A")"; K_11B="$(k11 "$C11B")"; K_11C="$(k11 "$C11C")"; K_11N1="$(k11 "$C11N1")"; K_11N2="$(k11 "$C11N2")"
K_12A="$(k11 "$C12A")"; K_12B="$(k11 "$C12B")"; K_12C="$(k11 "$C12C")"; K_12D="$(k11 "$C12D")"; K_12E="$(k11 "$C12E")"
K_12N1="$(k11 "$C12N1")"; K_12N2="$(k11 "$C12N2")"
K_13A="$(k11 "$C13A")"; K_13N="$(k11 "$C13N")"; K_13B="$(k11 "$C13B")"; K_13C="$(k11 "$C13C")"; K_13D="$(k11 "$C13D")"; K_13E="$(k11 "$C13E")"; K_13F="$(k11 "$C13F")"
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
# S6e-S6g: the ledger's stale core row plus a later copy of the same command that the VALIDATOR NEVER RUNS,
# so it acquits nothing: S6e in a derived fence that is never closed, S6f as an output line indented
# deeper than its fence, S6g behind a CRLF opener. A raw `$ ` scan reads each as a reproducing copy.
LS6E="$WORK/ls6e"; lroot "$LS6E"
{ printf '# Push-candidate ledger\n\n'; lfence "$LCMD" '9:qqalpha'; printf '\n```derived\n$ %s\n1:qqalpha\n' "$LCMD"; } > "$LS6E/$LLEDGER"
LS6F="$WORK/ls6f"; lroot "$LS6F"
{ printf '# Push-candidate ledger\n\n'; lfence "$LCMD" '9:qqalpha'; printf '\n```derived\n$ %s\n1\n    $ %s\n```\n' "$LCON" "$LCMD"; } > "$LS6F/$LLEDGER"
LS6G="$WORK/ls6g"; lroot "$LS6G"
{ printf '# Push-candidate ledger\n\n'; lfence "$LCMD" '9:qqalpha'; printf '\n```derived\r\n$ %s\n1:qqalpha\n```\n' "$LCMD"; } > "$LS6G/$LLEDGER"
K_LS6E="$LLEDGER:$(line_of "$LS6E/$LLEDGER" "\$ $LCMD" 1)"; K_LS6F="$LLEDGER:$(line_of "$LS6F/$LLEDGER" "\$ $LCMD" 1)"
K_LS6G="$LLEDGER:$(line_of "$LS6G/$LLEDGER" "\$ $LCMD" 1)"
# PU: pass 2. An OWED row whose ONLY same-command copy is in a derived fence that is never closed: the
# validator never runs it, so the row is not located there and reads MOVED (a raw scan located it, found
# no verdict line, and CLOSED it).
LSPU="$WORK/lspu"; lroot "$LSPU"
printf '# PRD\n\n```derived\n$ %s\n9:qqalpha\n' "$LCMD" > "$LSPU/$LPRD"
K_LSPU="$LPRD:$(line_of "$LSPU/$LPRD" "\$ $LCMD")"
row "$K_LSPU" "$LCMD" > "$WORK/lspu.tsv"
# G/RP/SL/CD: the `git -C` consumer words, `<rev>:<path>` under `-C`, single-component parents, and the
# `-C` directory itself, in ONE git-backed world with a blocking core control (GC), every fence stale.
# web/ holds a consumer copy of a core-looking tree, so a word asked UNprefixed reads core and blocks.
LS15="$WORK/ls15"; lroot "$LS15"
mkdir -p "$LS15/web/scripts/ai-dlc" "$LS15/web/tests/fixtures" "$LS15/tests/unit"
printf 'qqalpha\n' > "$LS15/web/scripts/ai-dlc/x.sh"; printf 'qqalpha\n' > "$LS15/web/tests/fixtures/f.json"
printf 'qqalpha\n' > "$LS15/web/x.sh"; printf 'qqalpha\n' > "$LS15/tests/unit/t.py"; printf 'qqalpha\n' > "$LS15/server/y.txt"
CG1='git -C web ls-files tests/fixtures'
CG2='git -C web grep -c qqalpha -- scripts/ai-dlc/x.sh'
CRP1='git -C web show HEAD:scripts/ai-dlc/x.sh'
CRP2='git -C web show HEAD:./x.sh'
CSL1='ls tests/'
CSL2='grep -rc qqalpha scripts/'
CCD1='git -C scripts/ai-dlc show HEAD:server/y.txt'
CCD2='git -C scripts/ai-dlc grep -c qqalpha x.sh'
CRP3='git -C scripts/ai-dlc show :0:./x.sh'
CRP4='git show :0:scripts/ai-dlc/x.sh'
CRP5='git -C scripts/ai-dlc show HEAD:./x.sh'
CPP='git -C web ls-files x.sh | grep -c qqalpha scripts/ai-dlc/x.sh'
CDD1='git -C web show HEAD:../scripts/ai-dlc/x.sh'
CDD2='git -C web grep -c qqalpha -- ../scripts/ai-dlc/x.sh'
CDD3='git -C web -C ../scripts/ai-dlc grep -c qqalpha x.sh'
CDD4='git -C web show HEAD:../server/y.txt'
CDD5='git -C lnk show HEAD:../x.sh'
mkdir -p "$LS15/scripts/ai-dlc/sub"; ln -s scripts/ai-dlc/sub "$LS15/lnk"
{ printf '# PRD\n\n'
  for c in "$LCMD" "$CG1" "$CG2" "$CRP1" "$CRP2" "$CSL1" "$CSL2" "$CCD1" "$CCD2" "$CRP3" "$CRP4" "$CRP5" "$CPP" "$CDD1" "$CDD2" "$CDD3" "$CDD4" "$CDD5"; do lfence "$c" 999; printf '\n'; done
} > "$LS15/$LPRD"
g "$LS15" init -q; g "$LS15" add -A; g "$LS15" commit -qm seed
k15() { printf '%s:%s' "$LPRD" "$(line_of "$LS15/$LPRD" "\$ $1")"; }
K_GC="$(k15 "$LCMD")"; K_G1="$(k15 "$CG1")"; K_G2="$(k15 "$CG2")"; K_RP1="$(k15 "$CRP1")"; K_RP2="$(k15 "$CRP2")"
K_SL1="$(k15 "$CSL1")"; K_SL2="$(k15 "$CSL2")"; K_CD1="$(k15 "$CCD1")"; K_CD2="$(k15 "$CCD2")"
K_RP3="$(k15 "$CRP3")"; K_RP4="$(k15 "$CRP4")"; K_RP5="$(k15 "$CRP5")"; K_PP="$(k15 "$CPP")"
K_DD1="$(k15 "$CDD1")"; K_DD2="$(k15 "$CDD2")"; K_DD3="$(k15 "$CDD3")"; K_DD4="$(k15 "$CDD4")"; K_DD5="$(k15 "$CDD5")"
# LF: the validator's `--list` fails (exit 3) while its verdict run works, over S1's stale core fence.
LSLF="$WORK/lslf"; lroot "$LSLF"; cp "$LS1/$LPRD" "$LSLF/$LPRD"
mv "$LSLF/scripts/ai-dlc/validate-artifact-derivations.sh" "$LSLF/scripts/ai-dlc/real-validator.sh"
printf '#!/usr/bin/env bash\n[ "${1:-}" = --list ] && exit 3\nexec bash "%s/scripts/ai-dlc/real-validator.sh" "$@"\n' "$LSLF" > "$LSLF/scripts/ai-dlc/validate-artifact-derivations.sh"
# B8c: a file whose own verdict run gives NO verdict AND whose `--list` fails (a stub exiting 2 on everything).
LSB8C="$WORK/lsb8c"; lroot "$LSB8C"
{ printf '# PRD\n\n'; lfence "$LCMD" '9:qqalpha'; } > "$LSB8C/$LPRD"
printf '#!/usr/bin/env bash\necho "REFUSED: seeded" >&2\nexit 2\n' > "$LSB8C/scripts/ai-dlc/validate-artifact-derivations.sh"
K_LSB8C="$LPRD:$(line_of "$LSB8C/$LPRD" "\$ $LCMD")"
row "$K_LSB8C" "$LCMD" > "$WORK/lsb8c.tsv"
for k in "$K_DD1" "$K_DD2" "$K_DD3" "$K_DD4" "$K_DD5" "$K_RP3" "$K_RP4" "$K_RP5" "$K_PP" "$K_LSB8C" "$K_LS6E" "$K_LS6F" "$K_LS6G" "$K_LSPU" "$K_GC" "$K_G1" "$K_G2" "$K_RP1" "$K_RP2" "$K_SL1" "$K_SL2" "$K_CD1" "$K_CD2"; do
  case "$k" in *:|*::*) echo "FIXTURE ERROR: a seeded LIVING derivation line was not found ($k)" >&2; exit 2 ;; esac
done
for k in "$K_LS6C1" "$K_LS6C2" "$K_LS6D" "$K_11A" "$K_11B" "$K_11C" "$K_11N1" "$K_11N2" "$K_12A" "$K_12B" "$K_12C" "$K_12D" "$K_12E" "$K_12N1" "$K_12N2" "$K_13A" "$K_13N" "$K_13B" "$K_LS14"; do
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
rc_is "S11c0 control: the validator gives a FAIL or UNRUN line for all nineteen S11/S12/CH fences" 19 "$(lv "$LS11" "$LPRD" | grep -cE '^(FAIL \(|UNRUN: )')"
rc_is "CHc control: the validator FAILs exactly the seven CH chain fences as ALLOWLIST (a chain is never run)" 7 "$(lv "$LS11" "$LPRD" | grep -c '^FAIL (ALLOWLIST): ')"
rc_is "S15c0 control: the validator gives a FAIL or UNRUN line for all eighteen G/RP/SL/CD fences" 18 "$(lv "$LS15" "$LPRD" | grep -cE '^(FAIL \(|UNRUN: )')"
s6ec=""
for d in "$LS6E" "$LS6F" "$LS6G"; do
  v6="$(lv "$d" "$LLEDGER")"; l6="$( cd "$d" && AI_DLC_PROJECT_ROOT="$d" bash scripts/ai-dlc/validate-artifact-derivations.sh --list "$d/$LLEDGER" 2>/dev/null )"
  n6="$(grep -c "^FAIL (STALE): $d/$LLEDGER:${K_LS6E##*:} " <<<"$v6")" || n6=0
  m6="$(grep -cF "  $LCMD" <<<"$l6")" || m6=0
  s6ec="$s6ec$n6$m6 "
done
rc_is "S6ec control: in S6e-S6g the validator FAILS the first ledger fence and lists no later copy of its command" "11 11 11 " "$s6ec"
rc_is "PUc control: the validator lists NO command in the PU file (its only copy is in an unclosed fence), and a raw scan sees one" "0 1 " "$( { ( cd "$LSPU" && AI_DLC_PROJECT_ROOT="$LSPU" bash scripts/ai-dlc/validate-artifact-derivations.sh --list "$LSPU/$LPRD" 2>/dev/null ) | grep -c '^  '; grep -cxF "\$ $LCMD" "$LSPU/$LPRD"; } | tr '\n' ' ')"
v13="$( ( cd "$LS13" && AI_DLC_PROJECT_ROOT="$LS13" bash scripts/ai-dlc/validate-artifact-derivations.sh "$LS13/$LPRD" "$LS13/_bmad-output/planning-artifacts/notes.md" > /dev/null 2> "$WORK/v13.err" ); echo $?)"
rc_is "S13c0 control: the wrapper's run exits 2 with NO UNRUN line, and the removed file is back afterwards" 0 "$([ "$v13" = 2 ] && ! grep -q '^UNRUN: ' "$WORK/v13.err" && [ -f "$LS13/_bmad-output/planning-artifacts/notes.md" ] && echo 0 || echo 1)"

# ---- lw-harness: begin (receipt-bl801.sh sources the lines between these two markers) ----------------
# THE WORLD FILTER. Every LIVING-sweep world is one gated block, `if lw_world <name>; then <its reader
# invocations> <its lw_arm lines>; lw_end; fi`. The REAL pass runs every world and records each arm's
# world in LW_MAP as it is asserted, so the map is derived from the lw_arm calls themselves and never
# hand-listed. In MUT mode a world runs only when one of its recorded arms is in LW_REQ, the mutant's
# required set: mut_case asserts only the required arms, so a world holding none of them changes no
# verdict. An lw_arm outside a gated block is FIXTURE BROKEN in either mode, because no filter could
# ever select it. A world whose arms read state another invocation set runs as ONE unit (S9 and S10:
# S10 compares against S9's batch output), and lw_world resets every shared global (LW_RESET_VARS) on entry, so no
# arm reads a value an earlier world left.
open_lines() { awk -F'\t' '$1 == "OPEN"' <<<"$OUT"; }
lopen() { printf 'OPEN\t%s\tLIVING-%s\t$ %s\t-\tliving-sweep' "$1" "$2" "$3"; }
lw_rd() { # <bin> <root> <record>
  local o="$WORK/lw.out" e="$WORK/lw.err"
  [ "$LW_MODE" = real ] || LW_NINV=$((LW_NINV + 1))
  ( cd / && AI_DLC_PROJECT_ROOT="$2" bash "$1/check-owed-derivations.sh" "$3" > "$o" 2> "$e" ); RC=$?
  OUT="$(cat "$o")"; ERR="$(cat "$e")"
}
lw_batch() { # <bin> <root> -> BOUT BRC
  [ "$LW_MODE" = real ] || LW_NINV=$((LW_NINV + 1))
  BOUT="$( cd / && printf '%s\n' "$LIN" | AI_DLC_PROJECT_ROOT="$2" bash "$1/check-owed-derivations.sh" --scope-batch 2>/dev/null )"; BRC=$?
}
# LW_MAP holds ` <world>:<arm> ` tokens from the real pass, LW_PASS the arms that HELD in it (the same-run
# base-pass record a kill's flag is read from); LW_SEEN the arms a mut pass evaluated;
# LW_NINV counts the mut-mode reader invocations and LW_NWORLD the mut-mode world runs, printed after the battery.
LW_MODE=real; LW_FAILED=""; LW_CUR=""; LW_MAP=" "; LW_REQ=""; LW_SEEN=" "; LW_NINV=0; LW_NWORLD=0; LW_PASS=" "
# LW_RESET_VARS: every shared world-level global the drivers (lw_rd, lw_batch) and the world bodies assign. `local`
# variables are scoped to lw_all and cannot leak between worlds, so they are not in it. Arm RSET derives the
# assigned set from this file's own text and holds the two equal.
LW_RESET_VARS="OUT ERR RC BOUT BRC"
lw_reset() { local v; for v in $LW_RESET_VARS; do printf -v "$v" '%s' ''; done; }
lw_world() { # <world> -> 0 run it, 1 skip it
  local a
  lw_reset
  LW_CUR=""
  if [ "$LW_MODE" = real ]; then LW_CUR="$1"; return 0; fi
  for a in $LW_REQ; do
    case "$LW_MAP" in *" $1:$a "*) LW_CUR="$1"; LW_NWORLD=$((LW_NWORLD + 1)); return 0 ;; esac
  done
  return 1
}
lw_end() { LW_CUR=""; }
lw_arm() { # <id> <description> <0 holds | 1 does not>
  if [ -z "$LW_CUR" ]; then
    bad "$1 FIXTURE BROKEN: lw_arm ran outside a gated world (if lw_world <name>; then ... lw_end; fi), so no mutant filter can select it"; return
  fi
  if [ "$LW_MODE" = real ]; then
    LW_MAP="$LW_MAP$LW_CUR:$1 "
    if [ "$3" = 0 ]; then ok "$1 $2"; LW_PASS="$LW_PASS$1 "; else bad "$1 $2 (exit $RC)"; printf '%s\n%s\n' "$OUT" "$ERR" | sed 's/^/        | /' | head -8; fi
  else
    LW_SEEN="$LW_SEEN$1 "
    if [ "$3" != 0 ]; then LW_FAILED="$LW_FAILED $1"; fi
  fi
}
lw_all() { # <reader> <tag>
  local b="$WORK/lw.$2/bin" b5="$WORK/lw.$2/bin5" lone="$WORK/lw.$2/lone" none="$WORK/lw.$2/no-record.tsv"
  mkdir -p "$b" "$b5" "$lone/scripts" "$lone/schemas"
  cp "$1" "$b/check-owed-derivations.sh"; cp "$COREPATHS" "$b/"; write_stub "$b"
  cp "$1" "$b5/check-owed-derivations.sh"; write_stub "$b5"
  # S10's caller shape (apply.sh's scope join): the reader ALONE beside the real sprint-status.sh and its
  # schema, with no core-paths.sh and no validator.
  cp "$1" "$lone/scripts/check-owed-derivations.sh"; cp "$SPRINTSTATUS" "$lone/scripts/sprint-status.sh"; cp "$SSSCHEMA" "$lone/schemas/sprint-status.json"
  if lw_world ls1; then
  lw_rd "$b" "$LS1" "$none"
  lw_arm S1 "acquittal probe: no record, one LIVING doc with a stale CORE fence and a stale CONSUMER fence -> exit 1 and exactly ONE OPEN line, the core one, LIVING-STALE living-sweep" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS1" STALE "$LCMD")" ] && grep -qF 'UNMEASURED: no owed-derivations record' <<<"$OUT"; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls2; then
  lw_rd "$b" "$LS2" "$none"
  lw_arm S2 "the same core fence in a PAST-sprint file (s0, current 1) -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls3; then
  lw_rd "$b" "$LS3" "$none"
  lw_arm S3 "every LIVING fence reproduces -> exit 0, no OPEN line, and the UNMEASURED line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ] && grep -qF 'UNMEASURED: no owed-derivations record' <<<"$OUT"; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls4c; then
  lw_rd "$b" "$LS4C" "$none"
  lw_arm S4a "a core-operand UNRUN in a LIVING doc -> exit 1, exactly one OPEN, LIVING-UNRUN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS4C" UNRUN "$LUNC")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls4s; then
  lw_rd "$b" "$LS4S" "$none"
  lw_arm S4b "a consumer-operand UNRUN in a LIVING doc -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls1-nocorepaths; then
  lw_rd "$b5" "$LS1" "$none"
  lw_arm S5 "core-paths.sh absent beside the reader, S1's seed -> exit 2 with a REFUSED line and no OPEN line" "$({ [ "$RC" = 2 ] && grep -qF 'REFUSED: no core-paths.sh beside' <<<"$ERR" && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6; then
  lw_rd "$b" "$LS6" "$none"
  lw_arm S6 "push-candidate-ledger.md stays LIVING (lead ruling): its stale core fence -> exit 1, its OPEN line printed" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls1-owed; then
  lw_rd "$b" "$LS1" "$WORK/ls7.tsv"
  lw_arm S7 "collision: an OWED row on prd.md:K whose fence is stale prints ONCE, as STALE, never again as LIVING-STALE" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(printf 'OPEN\t%s\tSTALE\t$ %s\tbase..theirs\treconcile-log-x' "$K_LS1" "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls8; then
  lw_rd "$b" "$LS8" "$none"
  lw_arm S8 "deleted core operands block (git show HEAD:scripts/ai-dlc/gone.sh, plain scripts/ai-dlc/deleted.sh); a deleted consumer one does not" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS8A" STALE 'git show HEAD:scripts/ai-dlc/gone.sh')
$(lopen "$K_LS8B" STALE 'grep -c qqalpha scripts/ai-dlc/deleted.sh')" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6b; then
  lw_rd "$b" "$LS6B" "$none"
  lw_arm S6b "the ledger's stale core fence plus a LATER copy of the same command that reproduces (a superseding row) -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ] && grep -qF 'UNMEASURED: no owed-derivations record' <<<"$OUT"; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6c; then
  lw_rd "$b" "$LS6C" "$none"
  lw_arm S6c "near-miss: the later ledger copy is stale too -> exit 1, BOTH lines OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6C1" STALE "$LCMD")
$(lopen "$K_LS6C2" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6d; then
  lw_rd "$b" "$LS6D" "$none"
  lw_arm S6d "near-miss: the same stale-then-fresh pair in prd.md (not the ledger) -> exit 1, the first line OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6D" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6e; then
  lw_rd "$b" "$LS6E" "$none"
  lw_arm S6e "a later ledger copy in a derived fence that is never CLOSED acquits nothing -> exit 1, the first line OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6E" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6f; then
  lw_rd "$b" "$LS6F" "$none"
  lw_arm S6f "a later ledger copy that is an INDENTED OUTPUT line acquits nothing -> exit 1, the first line OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6F" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls6g; then
  lw_rd "$b" "$LS6G" "$none"
  lw_arm S6g "a later ledger copy behind a CRLF opener acquits nothing -> exit 1, the first line OPEN" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS6G" STALE "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world lspu; then
  lw_rd "$b" "$LSPU" "$WORK/lspu.tsv"
  lw_arm PU "pass 2: an OWED row whose only same-command copy is in an unclosed fence is not located there -> exit 1, exactly one OPEN, MOVED" \
    "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(printf 'OPEN\t%s\tMOVED\t$ %s\tbase..theirs\treconcile-log-x' "$K_LSPU" "$LCMD")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world lslf; then
  lw_rd "$b" "$LSLF" "$none"
  lw_arm LF "the validator's --list fails over a LIVING file with a stale core fence -> exit 2 with the --list REFUSED line, no OPEN" "$({ [ "$RC" = 2 ] && grep -qF 'REFUSED: validate-artifact-derivations.sh --list exited 3 on' <<<"$ERR" && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world lsb8c; then
  lw_rd "$b" "$LSB8C" "$WORK/lsb8c.tsv"
  lw_arm B8c "an OWED row whose file gets NO verdict and whose --list fails -> exit 2 with the --list REFUSED line naming the file, never UNASSESSED" \
    "$({ [ "$RC" = 2 ] && grep -qF "REFUSED: validate-artifact-derivations.sh --list exited 2 on $LPRD" <<<"$ERR" && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls15; then
  lw_rd "$b" "$LS15" "$none"
  local o15="$OUT" r15="$RC"
  has15() { awk -F'\t' -v k="$1" '$1 == "OPEN" && $2 == k && $6 == "living-sweep" { f = 1 } END { exit f ? 0 : 1 }' <<<"$o15"; }
  lw_arm GC "control, same world as G/RP/SL/CD: the plain core fence blocks" "$({ [ "$r15" = 1 ] && has15 "$K_GC"; } && echo 0 || echo 1)"
  lw_arm G1 "git -C web ls-files tests/fixtures (web/'s tree, consumer) stays silent" "$(! has15 "$K_G1" && echo 0 || echo 1)"
  lw_arm G2 "git -C web grep -c qqalpha -- scripts/ai-dlc/x.sh (web/'s copy, consumer) stays silent" "$(! has15 "$K_G2" && echo 0 || echo 1)"
  lw_arm RP1 "git -C web show HEAD:scripts/ai-dlc/x.sh blocks (a rev:path resolves from the ROOT)" "$({ [ "$r15" = 1 ] && has15 "$K_RP1"; } && echo 0 || echo 1)"
  lw_arm RP2 "git -C web show HEAD:./x.sh (cwd-relative, no core file under web/) stays silent" "$(! has15 "$K_RP2" && echo 0 || echo 1)"
  lw_arm SL1 "ls tests/ (a single-component parent with a trailing slash) stays silent" "$(! has15 "$K_SL1" && echo 0 || echo 1)"
  lw_arm SL2 "grep -rc qqalpha scripts/ (a single-component parent with a trailing slash) stays silent" "$(! has15 "$K_SL2" && echo 0 || echo 1)"
  lw_arm CD1 "git -C scripts/ai-dlc show HEAD:server/y.txt (the -C directory is not asked; reads a consumer path) stays silent" "$(! has15 "$K_CD1" && echo 0 || echo 1)"
  lw_arm CD2 "git -C scripts/ai-dlc grep -c qqalpha x.sh still blocks" "$({ [ "$r15" = 1 ] && has15 "$K_CD2"; } && echo 0 || echo 1)"
  lw_arm RP3 "git -C scripts/ai-dlc show :0:./x.sh (index-stage prefix, then the cwd-relative rule) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_RP3"; } && echo 0 || echo 1)"
  lw_arm RP4 "git show :0:scripts/ai-dlc/x.sh (index-stage prefix on a plain core path) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_RP4"; } && echo 0 || echo 1)"
  lw_arm RP5 "git -C scripts/ai-dlc show HEAD:./x.sh (a ./ path joins the -C directory) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_RP5"; } && echo 0 || echo 1)"
  lw_arm PP "git -C web ls-files x.sh | grep -c qqalpha scripts/ai-dlc/x.sh (the -C flag is per segment, the grep segment is asked) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_PP"; } && echo 0 || echo 1)"
  lw_arm CDD1 "git -C web show HEAD:../scripts/ai-dlc/x.sh (web/.. collapsed to the root's core file) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_DD1"; } && echo 0 || echo 1)"
  lw_arm CDD2 "git -C web grep -c qqalpha -- ../scripts/ai-dlc/x.sh (a plain word, collapsed) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_DD2"; } && echo 0 || echo 1)"
  lw_arm CDD3 "git -C web -C ../scripts/ai-dlc grep -c qqalpha x.sh (a second -C joined onto the first) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_DD3"; } && echo 0 || echo 1)"
  lw_arm CDD4 "git -C web show HEAD:../server/y.txt (collapses to a consumer path) stays silent" "$(! has15 "$K_DD4" && echo 0 || echo 1)"
  lw_arm CDD5 "git -C lnk show HEAD:../x.sh (lnk is a symlink into core; the segment before .. over-asks) blocks" "$({ [ "$r15" = 1 ] && has15 "$K_DD5"; } && echo 0 || echo 1)"
  lw_arm S15n "and the G/RP/SL/CD world opens EXACTLY the eleven blocking lines" "$([ "$(awk -F'\t' '$1 == "OPEN" { n++ } END { print n + 0 }' <<<"$o15")" = 11 ] && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls11; then
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
  reason11() { awk -F'\t' -v k="$1" '$1 == "OPEN" && $2 == k && $6 == "living-sweep" { print $3 }' <<<"$o11"; }
  lw_arm CH1 "a chain FAILing ALLOWLIST, grep -n x <core retro.md>; echo \"exit:\$?\", blocks as LIVING-ALLOWLIST living-sweep (its safe segment is explained)" "$({ [ "$r11" = 1 ] && [ "$(reason11 "$K_13A")" = LIVING-ALLOWLIST ]; } && echo 0 || echo 1)"
  lw_arm CH1n "near-miss, same world: the same chain over a consumer operand (server/x.py) stays silent" "$(! has_open "$K_13N" && echo 0 || echo 1)"
  lw_arm CH2 "a && chain whose core operand is in its SECOND segment blocks as LIVING-ALLOWLIST living-sweep" "$({ [ "$r11" = 1 ] && [ "$(reason11 "$K_13B")" = LIVING-ALLOWLIST ]; } && echo 0 || echo 1)"
  lw_arm CH3 "a chain FAILing ALLOWLIST behind a literal cd web && opens NO row: its operand is web/.claude/..., not core (control: CH1 opens in this same run)" "$({ [ "$r11" = 1 ] && [ "$(reason11 "$K_13A")" = LIVING-ALLOWLIST ] && ! has_open "$K_13C"; } && echo 0 || echo 1)"
  lw_arm CH4 "cd .claude/skills && grep -n ai-dlc README.md opens NO row: grep is off the cd list, so the segment is not explained and its pattern never becomes .claude/skills/ai-dlc (control: CH1 opens in this same run)" "$({ [ "$r11" = 1 ] && [ "$(reason11 "$K_13A")" = LIVING-ALLOWLIST ] && ! has_open "$K_13D"; } && echo 0 || echo 1)"
  lw_arm CH5 "cd .claude/skills && cat ai-dlc/SKILL.md OPENS as LIVING-ALLOWLIST living-sweep: the carried cd reaches the core path (CH4's positive twin)" "$({ [ "$r11" = 1 ] && [ "$(reason11 "$K_13E")" = LIVING-ALLOWLIST ]; } && echo 0 || echo 1)"
  lw_arm CH6 "cd scripts && echo ai-dlc opens NO row: echo is off the cd list, so its word is never prefixed into scripts/ai-dlc (control: CH5 opens in this same run)" "$({ [ "$r11" = 1 ] && [ "$(reason11 "$K_13E")" = LIVING-ALLOWLIST ] && ! has_open "$K_13F"; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls13; then
  lw_rd "$b" "$LS13" "$none"
  lw_arm S13 "the validator exits 2 with no UNRUN line (a candidate vanished) -> exit 2 with the no-verdict REFUSED line, no OPEN" "$({ [ "$RC" = 2 ] && grep -qF 'with no verdict for every file it was given' <<<"$ERR" && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls13c; then
  lw_rd "$b" "$LS13C" "$none"
  lw_arm S13c "control: the same world with nothing removed -> exit 0, no OPEN line" "$({ [ "$RC" = 0 ] && [ "$(open_count)" = 0 ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world ls14; then
  lw_rd "$b" "$LS14" "$none"
  lw_arm S14 "a ROOT-ABSOLUTE core operand (\$ROOT/scripts/ai-dlc/x.sh) blocks" "$({ [ "$RC" = 1 ] && [ "$(open_lines)" = "$(lopen "$K_LS14" STALE "$C14")" ]; } && echo 0 || echo 1)"
  lw_end; fi
  if lw_world batch; then
  lw_batch "$b" "$LS1"; local s9a="$BOUT" s9r="$BRC"
  lw_batch "$b" "$LS3"
  lw_arm S9 "--scope-batch output and exit are byte-identical with (S1 root) and without (S3 root) a stale LIVING core fence" \
    "$({ [ "$s9r" = 0 ] && [ "$BRC" = 0 ] && [ "$s9a" = "$BOUT" ] && [ "$(printf '%s\n' "$BOUT" | cut -f1 | tr '\n' ' ')" = "LIVING PAST CURRENT LIVING " ]; } && echo 0 || echo 1)"
  local s10full="$s9a"
  [ "$LW_MODE" = real ] || LW_NINV=$((LW_NINV + 1))
  BOUT="$( cd / && printf '%s\n' "$LIN" | AI_DLC_PROJECT_ROOT="$LS1" bash "$lone/scripts/check-owed-derivations.sh" --scope-batch 2>/dev/null )"; BRC=$?
  lw_arm S10 "apply.sh's copy shape (reader + real sprint-status.sh + schema, NO core-paths.sh, no validator): --scope-batch over a root with a stale LIVING core fence -> exit 0, byte-identical to the full sibling set" \
    "$({ [ ! -e "$lone/scripts/core-paths.sh" ] && [ "$BRC" = 0 ] && [ -n "$s10full" ] && [ "$BOUT" = "$s10full" ]; } && echo 0 || echo 1)"
  lw_end; fi
}
# ---- lw-harness: end ---------------------------------------------------------------------------------
lw_all "$BIN/check-owed-derivations.sh" real

# ---- M1-M7: each mutant is a COPY of the reader, guarded by cmp -s; one that does not apply is BROKEN --
# mut_line <src> <dst> <occurrence> <exact old line> <new text>: replaces that occurrence of the whole line.
mut_line() {
  O="$4" N="$5" awk -v occ="$3" 'BEGIN { o = ENVIRON["O"]; nw = ENVIRON["N"] } $0 == o && ++c == occ { print nw; next } { print }' "$1" > "$2" || return 1
  ! cmp -s "$1" "$2"
}

# ---- RSET: the reset list EQUALS the set of globals the drivers and world bodies assign ---------------
# Derived from run.sh's own text: the lines of lw_rd, lw_batch and every `if lw_world <name>; then ... lw_end; fi`
# body, at statement position (line start or after `;`) as `NAME=`. `local NAME=` is excluded, because a local is
# scoped to lw_all and cannot leak between worlds. Pointed at its own subject: the set must hold OUT, RC and BOUT.
rset_derive() { awk '
  /^# ---- lw-harness: begin/ { h = 1 } /^# ---- lw-harness: end/ { h = 0 }
  h && /^lw_(rd|batch)\(\) \{/ { s = 1; next }
  h && s && /^\}/ { s = 0; next }
  h && /^  if lw_world / { s = 1; next }
  h && s && /lw_end; fi/ { s = 0; next }
  h && s && $0 !~ /^[ \t]*#/ {
    rest = $0
    while (match(rest, /(^|;)[ \t]*[A-Za-z_][A-Za-z0-9_]*=/)) {
      t = substr(rest, RSTART, RLENGTH); sub(/^;?[ \t]*/, "", t); sub(/=$/, "", t); print t
      rest = substr(rest, RSTART + RLENGTH)
    }
  }' "$1"; }
rset_check() { # <run.sh copy> -> 0 when the listed reset set equals the derived set; 2 when the derived set lacks OUT, RC or BOUT
  local d l
  d="$(rset_derive "$1" | LC_ALL=C sort -u | tr '\n' ' ')"
  l="$(sed -n 's/^LW_RESET_VARS="\(.*\)"$/\1/p' "$1" | head -1 | tr ' ' '\n' | LC_ALL=C sort -u | tr '\n' ' ')"
  RSET_D="$d"; RSET_L="$l"
  case " $d" in *" OUT "*) ;; *) return 2 ;; esac
  case " $d" in *" RC "*) ;; *) return 2 ;; esac
  case " $d" in *" BOUT "*) ;; *) return 2 ;; esac
  [ -n "$l" ] && [ "$d" = "$l" ]
}
SELF="$HERE/run.sh"
rset_check "$SELF"; _rr=$?
rc_is "RSET the globals reset at lw_world entry [$RSET_L] EQUAL the globals the drivers and world bodies assign [$RSET_D], and the derived set holds OUT, RC and BOUT" 0 "$_rr"
RS_F="$WORK/rset.fail.sh"; RS_P="$WORK/rset.pass.sh"
mut_line "$SELF" "$RS_F" 1 '  lw_rd "$b" "$LS14" "$none"' '  lw_rd "$b" "$LS14" "$none"
  ZZSEED=1'; _a1=$?
mut_line "$RS_F" "$RS_P" 1 'LW_RESET_VARS="OUT ERR RC BOUT BRC"' 'LW_RESET_VARS="OUT ERR RC BOUT BRC ZZSEED"'; _a2=$?
if [ "$_a1" != 0 ] || [ "$_a2" != 0 ]; then bad "RSET FIXTURE BROKEN: the probe copies did not apply"
else
  rset_check "$RS_F"; _pf=$?
  rc_is "RSETf probe: a copy with a world-level ZZSEED assigned in a world body and MISSING from the reset list is refused (derived set [$RSET_D])" 1 "$_pf"
  rset_check "$RS_P"; _pp=$?
  rc_is "RSETp probe: the same copy with ZZSEED PRESENT in the reset list passes" 0 "$_pp"
fi
# RSETr: the real lw_world/lw_arm/reset code over a seeded pair. World pa sets RC; world pb's arm reads it.
RS_H="$WORK/rset.harness.sh"; sed -n '/^# ---- lw-harness: begin/,/^# ---- lw-harness: end/p' "$SELF" > "$RS_H"
RS_VARS="$(sed -n 's/^LW_RESET_VARS="\(.*\)"$/\1/p' "$SELF" | head -1)"
rset_pair() { # <LW_RESET_VARS value> -> the verdict of arms PA and PB
  ( . "$RS_H"; LW_RESET_VARS="$1"; LW_MODE=real
    ok() { echo "ok $1"; }; bad() { echo "bad $1"; }
    if lw_world pa; then RC=7; lw_arm PA "pa sets RC" 0; lw_end; fi
    if lw_world pb; then lw_arm PB "pb reads RC set by pa" "$([ "$RC" = 7 ] && echo 0 || echo 1)"; lw_end; fi ) 2>&1 | awk '/^(ok|bad) P[AB] /{ print $1 " " $2 }' | tr '\n' ' '
}
rc_is "RSETr reset probe: with the reset, world pb's arm reading pa's RC FAILS, and without the reset it PASSES (same run, same worlds)" "ok PA bad PB ok PA ok PB " "$(rset_pair "$RS_VARS")$(rset_pair "")"

LW_MODE=mut
# req_ok <id> <required set>: a required set must be non-empty and every arm in it must be one the real
# pass recorded in a world. A misspelled arm would otherwise select no world and read as SURVIVED.
req_ok() {
  local a
  [ -n "$(printf '%s' "$2" | tr -d ' ')" ] || { bad "$1 FIXTURE BROKEN: the required set is empty, so nothing is scored"; return 1; }
  for a in $2; do
    case "$LW_MAP" in *":$a "*) ;; *) bad "$1 FIXTURE BROKEN: required arm $a is in no recorded world (misspelled, or asserted outside lw_all)"; return 1 ;; esac
  done
}
# req_seen <id> <required set>: every required arm was evaluated by this pass (its world ran).
req_seen() {
  local a
  for a in $2; do
    case "$LW_SEEN" in *" $a "*) ;; *) bad "$1 FIXTURE BROKEN: required arm $a was not evaluated, so its world never ran"; return 1 ;; esac
  done
}
LW_ALLARMS="$(for _t in $LW_MAP; do printf '%s ' "${_t#*:}"; done)"
# lw_base_passed <arms>: every named arm HELD in this run's real pass.
lw_base_passed() { local a; for a in $1; do case "$LW_PASS" in *" $a "*) ;; *) return 1 ;; esac; done; }
# mut_score <id> <deciding arm> <twins>: scores LW_FAILED from the pass just run. The kill is the deciding
# arm FAILING while every twin HOLDS; its flag is 1 only when the deciding arm and every twin held in the
# real pass of THIS run. MATRIX mode prints a row per recorded arm first, and scores the deciding arm alone
# (the twins are chosen FROM the matrix).
mut_score() {
  local a tbad="" dfail=0 tw="$3" base_rc
  if [ "$OWED_MATRIX" = 1 ]; then
    for a in $LW_ALLARMS; do
      case " $LW_FAILED " in *" $a "*) printf 'MATRIX\t%s\t%s\tFAIL\n' "$1" "$a" ;; *) printf 'MATRIX\t%s\t%s\tok\n' "$1" "$a" ;; esac
    done
    tw=""
  fi
  lw_base_passed "$2 $tw"; base_rc=$?
  for a in $tw; do case " $LW_FAILED " in *" $a "*) tbad="$tbad $a" ;; esac; done
  case " $LW_FAILED " in *" $2 "*) dfail=1 ;; esac
  if [ "$dfail" = 1 ] && [ -z "$tbad" ]; then
    mutant_killed "$([ "$base_rc" -eq 0 ] && echo 1 || echo 0)" "$1" "$1 killed: deciding arm $2 failed, twin(s) ${tw:-none} held (failed:$LW_FAILED)"
  elif [ "$dfail" = 0 ]; then
    bad "$1 SURVIVED: deciding arm $2 did not fail (failed:${LW_FAILED:- none})"
  else
    bad "$1 ENTANGLED: twin arm(s)$tbad failed beside deciding arm $2 (failed:$LW_FAILED)"
  fi
}
mut_case() { # <id> <deciding arm> <twin arms, space-separated> <occurrence> <old line> <new text> [<occ2> <old2> <new2>]
  local m="$WORK/mut.$1.sh" req="$2 $3"
  req_ok "$1" "$req" || return
  [ "$OWED_MATRIX" = 1 ] && req="$LW_ALLARMS"
  if ! mut_line "$BIN/check-owed-derivations.sh" "$m" "$4" "$5" "$6"; then
    bad "$1 FIXTURE BROKEN: the mutation did not apply (anchor not found), so it is not scored"; return
  fi
  if [ "$#" -ge 9 ]; then
    if ! mut_line "$m" "$m.2" "$7" "$8" "$9"; then
      bad "$1 FIXTURE BROKEN: the second mutation did not apply (anchor not found), so it is not scored"; return
    fi
    mv "$m.2" "$m"
  fi
  LW_REQ="$req"; LW_FAILED=""; LW_SEEN=" "; lw_all "$m" "$1"
  req_seen "$1" "$req" || return
  mut_score "$1" "$2" "$3"
}
mut_case M1 S1 "GC" 1 '    grep -qxF -- "$_id" "$TMP/ls.core" || continue' '    :'
mut_case M2 S1 "S3" 1 '    grep -qxF -- "$_id" "$TMP/ls.core" || continue' '    grep -qxF -- "$_id" "$TMP/ls.core" && continue'
mut_case M3 S1 "S2" 1 '  living_sweep' '  :'
mut_case M4 S2 "S1" 1 '    [ "$SCOPE_TOKEN" = LIVING ] || continue' '    [ "$SCOPE_TOKEN" = LIVING ] || [ "$SCOPE_TOKEN" = PAST ] || continue'
mut_case M5 S5 "S1" 1 '  [ -f "$SELF_DIR/core-paths.sh" ] \' '  [ -f "$SELF_DIR/core-paths.sh" ] || return 0; [ -f "$SELF_DIR/core-paths.sh" ] \'
mut_case M6 S1 "S3" 1 '  sweep_and_exit 0' '  exit 0'
mut_case M7 S10 "S9" 1 'if [ "${1:-}" = "--scope-batch" ]; then' '[ -f "$SELF_DIR/core-paths.sh" ] || { echo "REFUSED: no core-paths.sh beside $0" >&2; exit 2; }
if [ "${1:-}" = "--scope-batch" ]; then'
mut_case M8 S6b "S6c" 1 '    if [ "$_c" = "$LEDGER_REL" ] && ledger_superseded "$_i" "$_c" "$_ln" "$_cmd"; then continue; fi' '    :'
mut_case M9 S11a "S11n" 1 '    case "$_q" in git\ *) ;; *) continue ;; esac' '    continue'
# The anchors below carry single quotes, so they are read from quoted heredocs, byte for byte.
WORDS_LINE="$(cat <<'EOF'
  awk -F'\t' '$2 == "ARGV" { gc = (substr($3, 1, 7) == "git -C ") } $2 == "WORD" && !gc && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { print $1 "\t" $7 }' "$TMP/ls.explain" > "$TMP/ls.ops"
EOF
)"
WORDS_NOVAL="$(cat <<'EOF'
  awk -F'\t' '$2 == "ARGV" { gc = (substr($3, 1, 7) == "git -C ") } $2 == "WORD" && !gc && $5 == "operand" { print $1 "\t" $7 }' "$TMP/ls.explain" > "$TMP/ls.ops"
EOF
)"
# M13: the pre-fold line, which asked a `git -C` segment's WORD lines unprefixed.
WORDS_ALLGIT="$(cat <<'EOF'
  awk -F'\t' '$2 == "WORD" && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { print $1 "\t" $7 }' "$TMP/ls.explain" > "$TMP/ls.ops"
EOF
)"
# M12/M12b: the pre-fold RAW-SCAN locator (a second fence grammar), restored at one caller each.
RAWSCAN="$(cat <<'EOF'
derived_cmd_lines() {
  C="$2" awk 'BEGIN { st = 0; fc = sprintf("%c%c%c", 96, 96, 96); want = ENVIRON["C"] }
    { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t) }
    st == 0 && substr(t, 1, 3) == fc { st = (t == fc "derived") ? 2 : 1; next }
    st != 0 && substr(t, 1, 3) == fc { st = 0; next }
    st == 2 && substr(t, 1, 2) == "$ " && substr(t, 3) == want { print NR }' "$1"
}
LST=""; LST_N=0
EOF
)"
LEDGER_CALL='  _all="$(list_cmd_lines "$LST" "$2" "$4")" \'
PASS2_CALL='    found="$(list_cmd_lines "$LST" "$rel" "$tcmd")" \'
mut_case M10 S11c "S11n" 1 "$WORDS_LINE" "$WORDS_NOVAL"
mut_case M12 S6e "S6b" 1 'LST=""; LST_N=0' "$RAWSCAN" 1 "$LEDGER_CALL" '  _all="$(derived_cmd_lines "$ROOT/$2" "$4")" \'
mut_case M12b PU "S7" 1 'LST=""; LST_N=0' "$RAWSCAN" 1 "$PASS2_CALL" '    found="$(derived_cmd_lines "$ROOT/$rel" "$tcmd")" \'
SOFT_LINE='    list_of "$rel"'
SOFT_NEW="$(cat <<'EOF'
    j="$(idx_of "$rel")"; rc="$(cat "$TMP/f.$j.rc" 2>/dev/null)"
    if [ "$rc" != 0 ] && [ "$rc" != 1 ] && ! ( list_of "$rel" ) 2> /dev/null; then
      nopen=$((nopen + 1)); printf 'OPEN\t%s\t%s\t$ %s\t%s\t%s\n' "$key" "UNASSESSED" "$tcmd" "$range" "$logn"; continue
    fi
    list_of "$rel"
EOF
)"
mut_case M14 B8c "LF" 1 "$SOFT_LINE" "$SOFT_NEW"
mut_case M15 RP3 "RP2" 1 '        *:*) case "$_w" in :[0-3]:*) _p="${_w#:?:}" ;; :*) _p="${_w#:}" ;; *) _p="${_w#*:}" ;; esac' '        *:*) _p="${_w#*:}"' \
  1 '    for _t in "$_w" "$_rw"; do' '    for _t in "$_w" "${_w#*:}"; do'
mut_case M16 RP5 "RP2" 1 '             case "$_p" in ./*) _p="${_gd%/}/${_p#./}" ;; ../*) _p="${_gd%/}/$_p" ;; esac ;;' '             case "$_p" in ../*) _p="${_gd%/}/$_p" ;; esac ;;'
STICKY_OLD="$(cat <<'EOF'
  awk -F'\t' '$2 == "ARGV" { gc = (substr($3, 1, 7) == "git -C ") } $2 == "WORD" && !gc && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { print $1 "\t" $7 }' "$TMP/ls.explain" > "$TMP/ls.ops"
EOF
)"
STICKY_NEW="$(cat <<'EOF'
  awk -F'\t' '$2 == "ARGV" { if ($1 != pid) { gc = 0; pid = $1 } if (substr($3, 1, 7) == "git -C ") gc = 1 } $2 == "WORD" && !gc && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { print $1 "\t" $7 }' "$TMP/ls.explain" > "$TMP/ls.ops"
EOF
)"
mut_case M17 PP "G1" 1 "$STICKY_OLD" "$STICKY_NEW"
mut_case M18 CDD1 "CDD4" 1 '      collapse_dots "$_p"' '      CP="$_p"; CSYM=0'
mut_case M19 CDD5 "CDD4" 1 '      [ "$CSYM" = 0 ] || printf '"'"'%s\n'"'"' "$_id" >> "$TMP/ls.force"' '      :'
mut_case M13 G1 "GC" 1 "$WORDS_LINE" "$WORDS_ALLGIT"
mut_case M11 S12a "S12n" 1 '      case "$_globsnl" in *"$NL${_t%/}/"*) printf '"'"'%s\n'"'"' "$_id" >> "$TMP/ls.core"; break ;; esac' '      :'
mut_case mA S13 "S13c" 1 '  local nref' '  return 0'
mut_case mB S14 "S1" 1 '      _t="${_t#"$ROOT"/}"' '      :' 1 '      for _k in "$_t" "${_t%/}/"; do' '      for _k in "$_t"; do'
# M20: every command the validator LISTS in a kept file becomes a candidate, FAIL line or not, so a
# reproducing core fence is opened.
VERD_NEW="$(cat <<'EOF'
  : > "$TMP/ls.verd"
  _i=0; while IFS= read -r _c; do _i=$((_i + 1)); list_of "$_c"; awk -v i="$_i" 'match($0, /:[0-9]+  /) { print i "\t" substr($0, RSTART + 1, RLENGTH - 3) "\tSTALE" }' "$LST" >> "$TMP/ls.verd"; done < "$TMP/ls.rel"
EOF
)"
mut_case M20 S3 "S4b" 1 '  : > "$TMP/ls.verd"' "$VERD_NEW"
# M21: --scope-batch lets the LIVING documents' verdicts reach its stdout.
BATCH_LEAK="$(cat <<'EOF'
  find "$ROOT/_bmad-output" -name '*.md' -exec bash "$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh" {} + 2>&1 >/dev/null | grep '^FAIL ('; exit 0
EOF
)"
mut_case M21 S9 "S10" 1 '  exit 0' "$BATCH_LEAK"
# M22: the sweep refuses on EVERY validator exit, a verdict included (the always-refuse mirror of mA).
mut_case M22 S13c "S13" 1 '    0|1) return 0 ;;' '    0|1) ;;'
# CPY: the copy lw_all makes for every mutant starts as a `cp` of the reader, so the copies the real pass ran
# must be byte-identical to $BIN/check-owed-derivations.sh, and M1's mutated copy must differ (the control).
rc_is "CPY the copies lw_all ran in the real pass are byte-identical to the reader, and M1's mutated copy is not" "same differs" "$({ cmp -s "$BIN/check-owed-derivations.sh" "$WORK/lw.real/bin/check-owed-derivations.sh" && cmp -s "$BIN/check-owed-derivations.sh" "$WORK/lw.real/bin5/check-owed-derivations.sh" && printf same; } || printf DIFFERENT) $(cmp -s "$BIN/check-owed-derivations.sh" "$WORK/mut.M1.sh" && printf same || printf differs)"
# MV1: a VALIDATOR mutant. The reader runs the validator copied into the ROOT, so the mutant is a copy of
# the LS11 world whose validator has its `explain_chain` call removed (base: a refused chain explains no
# segment, so no core operand is asked). The real reader is driven over that copy through the same world
# filter; its deciding arm CH1 must fail and its twin CH1n must hold. Its control is the same copy with the
# validator unmutated, under which every arm it runs holds.
mv_world() { # <tag> <validator source> -> sets MVW
  MVW="$WORK/ls11.$1"; cp -R "$LS11" "$MVW"; cp "$2" "$MVW/scripts/ai-dlc/validate-artifact-derivations.sh"
}
mv_case() { # <tag> <validator source> -> LW_FAILED over the CH arms in the copied world
  local keep="$LS11"
  mv_world "$1" "$2"; LS11="$MVW"
  LW_REQ="CH1 CH1n"; [ "$OWED_MATRIX" = 1 ] && LW_REQ="$LW_ALLARMS"
  LW_FAILED=""; LW_SEEN=" "; lw_all "$BIN/check-owed-derivations.sh" "$1"
  LS11="$keep"
}
MVSRC="$WORK/mv1.validator.sh"
mut_line "$VALIDATOR" "$MVSRC" 1 '      [ "$EXPLAIN" = 1 ] && explain_chain "$c"' '      :'
mv_rc=$?
if [ "$mv_rc" != 0 ]; then
  bad "MV1 FIXTURE BROKEN: the explain_chain call line was not found in the validator, so the mutant is not scored"
elif ! bash -n "$MVSRC"; then
  bad "MV1 FIXTURE BROKEN: the mutated validator does not parse"
else
  mv_case mv1 "$MVSRC"
  req_seen MV1 "$LW_REQ" && mut_score MV1 CH1 "CH1n"
  mv_case mv1null "$VALIDATOR"
  req_seen "MV1 control" "$LW_REQ" && {
    if [ -z "$LW_FAILED" ]; then ok "MV1 control: the same copied world with the UNMUTATED validator holds every arm it runs"
    else bad "MV1 control: arm(s)$LW_FAILED failed under the unmutated validator in the copied world"; fi
  }
fi
printf '  mutant-phase reader invocations: %s\n' "$LW_NINV"
printf '  mutant-phase world runs: %s\n' "$LW_NWORLD"
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
rc_is "Wf a second run of the SAME range does not append: the record still has one row (producer-side dedup on key and range)" 1 "$(awk 'END { print NR + 0 }' "$OWED")"
rd "$C" "$OWED"
rc_is "Wg the reader over the WRITER'S record: exit 1 and the key is OPEN once" 0 "$([ "$RC" = 1 ] && [ "$(open_keys)" = "$K_W" ] && echo 0 || echo 1)"
printf 'qqalpha\nqqgamma\n' > "$C/scripts/ai-dlc/toy.sh"
rd "$C" "$OWED"
rc_is "Wh once the tree reproduces the derivation again the writer's rows read closed -> exit 0" 0 "$RC"

# ---- B7: BL-706 -- the shipping apply.sh runs the differential on EVERY ordinary pull ------------------------
# receipt-bl706.sh drives the shipping apply.sh and the helper beside it over seeded worlds (cells a a2 a3 b d l c e e2 f g h i i2 j k,
# its header names each) and prints one `CELL <id> ok|FAIL` line per cell. It runs once unmutated here. Each mutant is a
# COPY of the whole reconcile/ directory (the helper lifts vd_join out of the apply.sh beside it and apply.sh shells to
# its siblings, so a lone mutated file would find none), mutated by ONE exact-once replacement, and is scored on its
# deciding cell and its twins only. The twins' `ok` is also the control that the copy RAN: a copy that never ran prints
# no CELL line, which reads MISSING, never ok.
printf 'HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/apply.sh\n'
B7_RECON="$(dirname "$DIFFER")"
B7_RCPT="$HERE/receipt-bl706.sh"
[ -f "$B7_RCPT" ] && [ -f "$B7_RECON/apply.sh" ] || { echo "FIXTURE ERROR: receipt-bl706.sh or the reconcile/ directory is missing" >&2; exit 2; }
b7_state() { awk -v c="$2" '$1 == "CELL" && $2 == c { print $3; f = 1; exit } END { if (!f) print "MISSING" }' <<<"$1"; }
b7_text() { awk -v c="$2" '$1 == "CELL" && $2 == c { sub(/^CELL [^ ]+ [^ ]+ /, ""); print; exit }' <<<"$1"; }
B7_REAL="$(TMPDIR="$WORK" bash "$B7_RCPT" "$B7_RECON" "$READER" 2>&1)"; B7_RC=$?
for _c in a a2 a3 b d l c e e2 f g h i i2 j k; do
  if [ "$(b7_state "$B7_REAL" "$_c")" = ok ]; then
    case "$_c" in a) B_B7a=1 ;; b) B_B7b=1 ;; c) B_B7c=1 ;; d) B_B7d=1 ;; e) B_B7e=1 ;; e2) B_B7e2=1 ;; f) B_B7f=1 ;; g) B_B7g=1 ;; h) B_B7h=1 ;; i) B_B7i=1 ;; j) B_B7j=1 ;; k) B_B7k=1 ;; l) B_B7l=1 ;; esac
    ok "B7$_c $(b7_text "$B7_REAL" "$_c" | cut -c1-200)"
  else bad "B7$_c the shipping apply.sh/helper did not hold cell $_c: $(b7_text "$B7_REAL" "$_c" | cut -c1-300) (state $(b7_state "$B7_REAL" "$_c"))"; fi
done
rc_is "B7rc the receipt exits 0 over the unmutated reconcile/ directory" 0 "$B7_RC"

# b7_sub <file>: replace the text in B7_OLD with B7_NEW exactly once, or fail (a mutation that matches nothing is a lost subject).
b7_sub() {
  B7_F="$1" B7_OLD="$B7_OLD" B7_NEW="$B7_NEW" python3 -I -c 'import os, sys
f = os.environ["B7_F"]; s = open(f).read(); o = os.environ["B7_OLD"]; n = os.environ["B7_NEW"]
if s.count(o) != 1: sys.exit(1)
open(f, "w").write(s.replace(o, n))'
}
# b7_mut <id> <file in reconcile/> <deciding cells> <twin cells> <receipt groups> <base flag>   (B7_OLD / B7_NEW carry the replacement)
# <base flag> is the $(( )) conjunction of the B_B7<cell> flags the unmutated pass set for the deciding cell and its twins.
b7_mut() {
  local id="$1" f="$2" dec="$3" tw="$4" grp="$5" d="$WORK/b7/$1" c out ndead=0 note=""
  mkdir -p "$WORK/b7" && cp -R "$B7_RECON" "$d" || { bad "$id FIXTURE BROKEN: could not copy reconcile/"; return; }
  [ -f "$d/preclassify.sh" ] && [ -f "$d/derivation-differential.sh" ] || { bad "$id FIXTURE BROKEN: the copied reconcile/ lacks a sibling the subject resolves beside itself"; return; }
  if ! b7_sub "$d/$f" || cmp -s "$B7_RECON/$f" "$d/$f"; then bad "$id FIXTURE BROKEN: the mutation did not apply exactly once to $f, so it is not scored"; return; fi
  bash -n "$d/$f" || { bad "$id FIXTURE BROKEN: the mutated $f does not parse"; return; }
  out="$(TMPDIR="$WORK" bash "$B7_RCPT" "$d" "$READER" "$grp" 2>&1)"
  for c in $dec; do [ "$(b7_state "$out" "$c")" = FAIL ] || { ndead=1; note="$note deciding cell $c read $(b7_state "$out" "$c");"; }; done
  for c in $tw; do [ "$(b7_state "$out" "$c")" = ok ] || { ndead=1; note="$note twin cell $c read $(b7_state "$out" "$c");"; }; done
  if [ "$ndead" = 0 ]; then mutant_killed "$6" "$id" "$id killed: deciding cell(s) $dec failed, twin(s) $tw held"
  else bad "$id SURVIVED or ENTANGLED:$note"; fi
}
# M1 join-only: record mode stops widening the set, so a derivation reading a changed file it does not name is never run.
B7_OLD='[ "$OWED_SET" -eq 1 ] && VD_ALL=1' B7_NEW='[ "$OWED_SET" -eq 1 ] && VD_ALL=0'
b7_mut BL706-M1 derivation-differential.sh b "a c" "bd a c" "$(( ${B_B7b:-0} && ${B_B7a:-0} && ${B_B7c:-0} ))"
# M2 exit 2 swallowed: apply.sh reads a refusal as exit 0, so no DECISION row is drawn.
B7_OLD='case "$dd_rc" in' B7_NEW='case "$((dd_rc == 2 ? 0 : dd_rc))" in'
b7_mut BL706-M2 apply.sh e "a b" "a bd e" "$(( ${B_B7e:-0} && ${B_B7a:-0} && ${B_B7b:-0} ))"
# M3 call before the writes: the whole call block moves above the phases that write the tree.
B7_OLD='DD_HELPER="$SELF/derivation-differential.sh"' B7_NEW='DD_HELPER="$SELF/derivation-differential.sh"'
B7_F="$WORK/b7-m3.py"
printf '%s\n' 'import os, sys' 'f = os.environ["B7_F2"]; s = open(f).read()' \
  'a = s.index("DD_HELPER=\"$SELF/derivation-differential.sh\""); b = s.index("fi  # ---- end of the resolution phases")' \
  'blk = s[a:b]; s = s[:a] + s[b:]; m = "# THE DRIVER REPLACED ITSELF, AND THE OPERATOR IS TOLD SO"' \
  'if s.count(m) != 1: sys.exit(1)' 'i = s.index(m); s = s[:i] + blk + s[i:]; open(f, "w").write(s)' > "$B7_F"
mkdir -p "$WORK/b7" && cp -R "$B7_RECON" "$WORK/b7/BL706-M3" \
  && B7_F2="$WORK/b7/BL706-M3/apply.sh" python3 -I "$B7_F" && ! cmp -s "$B7_RECON/apply.sh" "$WORK/b7/BL706-M3/apply.sh" && bash -n "$WORK/b7/BL706-M3/apply.sh"; B7_M3=$?
if [ "$B7_M3" != 0 ]; then bad "BL706-M3 FIXTURE BROKEN: the call block did not move, so it is not scored"
else
  B7_M3OUT="$(TMPDIR="$WORK" bash "$B7_RCPT" "$WORK/b7/BL706-M3" "$READER" "g bd" 2>&1)"
  if [ "$(b7_state "$B7_M3OUT" g)" = FAIL ] && [ "$(b7_state "$B7_M3OUT" b)" = ok ]; then
    mutant_killed "$(( ${B_B7g:-0} && ${B_B7b:-0} ))" BL706-M3 "BL706-M3 killed: with the call above the writes the relocation's break is missed (cell g failed), while a derivation the earlier phases break is still found (cell b held)"
  else bad "BL706-M3 SURVIVED or ENTANGLED: cell g read $(b7_state "$B7_M3OUT" g), cell b read $(b7_state "$B7_M3OUT" b)"; fi
fi
# M4 dedup removed: a second run of the same range appends a duplicate OWED row.
B7_OLD="!((\$2 SUBSEP \$6) in S)'" B7_NEW="1'"
b7_mut BL706-M4 derivation-differential.sh d b "bd" "$(( ${B_B7d:-0} && ${B_B7b:-0} ))"
# M5 empty-join record skipped: a pull with no fence in scope leaves no record.
B7_OLD='    make_record
    print_dropped
    say_row INFO join' B7_NEW='    print_dropped
    say_row INFO join'
b7_mut BL706-M5 derivation-differential.sh c a "a c" "$(( ${B_B7c:-0} && ${B_B7a:-0} ))"
# M6 apply.sh no longer clears an inherited VD_ALL before its own WORKLIST join.
B7_OLD='  unset VD_ALL
  vd_join "$DIST" "$BASE" "$THEIRS" "$VD_ART"' B7_NEW='  vd_join "$DIST" "$BASE" "$THEIRS" "$VD_ART"'
b7_mut BL706-M6 apply.sh h a "a h" "$(( ${B_B7h:-0} && ${B_B7a:-0} ))"
# M7 the helper no longer clears an inherited VD_ALL before its non-record join.
B7_OLD='unset VD_ALL
[ "$OWED_SET" -eq 1 ] && VD_ALL=1' B7_NEW='[ "$OWED_SET" -eq 1 ] && VD_ALL=1'
b7_mut BL706-M7 derivation-differential.sh h a "a h" "$(( ${B_B7h:-0} && ${B_B7a:-0} ))"
# M8 the NEGATIVE: the call is deleted, which is what the apply was before this change. No record is left.
B7_OLD='if [ -d "$VD_ART" ] && [ -f "$VD_VALIDATOR" ]; then
  if [ ! -f "$DD_HELPER" ]; then' B7_NEW='if false; then
  if [ ! -f "$DD_HELPER" ]; then'
b7_mut BL706-M8 apply.sh a h "a h" "$(( ${B_B7a:-0} && ${B_B7h:-0} ))"
# M9 no fold: a moved-path hit that the differential finds newly failing draws BOTH the held WORKLIST artifact-derivations row and the -owed row.
B7_OLD='          if [ -n "$DD_OLD_ROW" ]; then
            # ONE ROW PER CAUSE: a fence named' B7_NEW='          if false; then
            # ONE ROW PER CAUSE: a fence named'
b7_mut BL706-M9 apply.sh j b "bd j" "$(( ${B_B7j:-0} && ${B_B7b:-0} ))"
# M10 duplicate scope refusal not suppressed: a scope-classifier failure draws -unscoped AND the -differential refusal.
B7_OLD='          if [ "$dd_dup" = 0 ]; then' B7_NEW='          if true; then'
b7_mut BL706-M10 apply.sh k e "k e" "$(( ${B_B7k:-0} && ${B_B7e:-0} ))"
# M11 the tree-moved test skips ignored files again: the short-circuit records 0 where the full differential finds a break.
B7_OLD='ls-files --others 2>/dev/null)" || _tm_u' B7_NEW='ls-files --others --exclude-standard 2>/dev/null)" || _tm_u'
b7_mut BL706-M11 derivation-differential.sh i f "i f" "$(( ${B_B7i:-0} && ${B_B7f:-0} ))"
# M12 the minted log name is not passed: the record carries the helper default, a name no log has.
B7_OLD=' --record-owed "$DD_RECORD" --log-name "$DD_LOG" 2>&1)"' B7_NEW=' --record-owed "$DD_RECORD" 2>&1)"'
b7_mut BL706-M12 apply.sh l "b d" "bd" "$(( ${B_B7l:-0} && ${B_B7b:-0} && ${B_B7d:-0} ))"
# M13 the base-root hand remedy drops --base-root.
B7_OLD='            base-root:*) dd_hand=' B7_NEW='            base-rootX:*) dd_hand='
b7_mut BL706-M13 apply.sh e2 e "e" "$(( ${B_B7e2:-0} && ${B_B7e:-0} ))"

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
