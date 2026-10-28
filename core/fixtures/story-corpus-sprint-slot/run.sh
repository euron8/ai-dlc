#!/usr/bin/env bash
# story-corpus-sprint-slot — the story corpus lives under the sprint's OWN directory, and every
# reader resolves it from one declaration rather than restating it.
#
# Exit: 0 = every assertion holds, 1 = an assertion regressed, 2 = fixture broken.
#
# THE DEFECT CLASS THIS EXISTS TO CATCH, and it is the one this repo keeps shipping: a reader that
# finds nothing and reports it as clean. Every arm below distinguishes THREE states that used to
# print the same line —
#
#   the corpus is empty                 -> SKIP     (a project before its first story)
#   the corpus exists, elsewhere        -> FAIL     (unmigrated, or written to the wrong sprint)
#   the corpus location did not resolve -> FAIL     (the schema is unreadable)
#
# — because collapsing any two of them is how sprints 298 and 299 had their Dev Agent Record
# compliance "verified" against zero files. The measured history is in validate-mandatory-rules.sh
# at Check 6.
#
# ARM 4 IS THE ONE THAT WAS ACTUALLY WRONG DURING DEVELOPMENT, and it is why the corpus control
# counts the flat layout and not only the declared slot. Written the obvious way — count stories
# under `s*/stories/` — the control is BLIND to a tree that has not migrated yet, so an unmigrated
# consumer holding 988 story files reported "the corpus is empty" and SKIPped. The fix's own
# blind spot had the same shape as the defect it was fixing.
#
# ARM 7 IS ITS OPPOSITE BOUND. The control counts the flat layout plus THIS sprint's slot and no
# other sprint's, because a verdict must be the same with all sprint history deleted: a past
# sprint's stories beside an empty current slot SKIP, byte-identically to the tree without them.
#
# SHAPE. Every arm is a function that builds the world it needs, drives the tools it is handed, and
# prints `A<n> PASS|FAIL`. The shipping tools run every arm. A mutant is a copy of the tools; per
# push it drives only its DECIDING arm(s) plus one named TWIN the measured matrix shows green.
#
# MUTANT MATRIX. "A mutant fails only its own assertion" (.claude/rules/fixture-mutants.md) is a
# test-quality property, measured ONCE for every mutant against EVERY arm and recorded below; per
# push each mutant runs its deciding arm(s) (must flip) and one twin (must stay green). The matrix
# is re-measured whenever an arm or a mutant is added or changed, with the REMEASURE command below.
# Outside its declared decides set, each mutant co-trips no other arm, measured at authoring.
# MUTANT-MATRIX a4-corpus-control-narrowed-to-slot decides=A4 twins=A3
# MUTANT-MATRIX a7-flat-count-counts-other-slots decides=A7 twins=A5
# MUTANT-MATRIX a6-unresolved-skips-instead-of-failing decides=A6 twins=A5
# MUTANT-MATRIX a8-capital-s-key-unrecognised decides=A8 twins=A1
# MUTANT-MATRIX a9-index-glob-prefix-widened decides=A9 twins=A1
# MUTANT-MATRIX a10-corpus-literal-restated decides=A10 twins=A1
# MUTANT-MATRIX a12-waiver-window-crosses-entry decides=A12 twins=A11
# MUTANT-MATRIX a13-a14-process-stays-in-invoking-dir decides=A13,A14 twins=A2
# MUTANT-MATRIX a14-escalations-read-from-invoking-dir decides=A14 twins=A11
# MUTANT-MATRIX-REMEASURE bash core/fixtures/story-corpus-sprint-slot/run.sh --matrix
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking anything (I10). The tools under test
# take AI_DLC_PROJECT_ROOT ahead of their own walk (sprint-status.sh), and every arm below drives
# a copy INSTALLED INTO a seeded tree; an inherited override points them at some other tree and
# A10, which moves the declaration inside the seed, then fails on the control and every mutant.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# No distribution-root walk here: this file needs none. The seed names its sources in both layouts;
# this file resolves nothing but itself.
HERE="$(cd "$(dirname "$0")" && pwd)"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# --matrix is an ARGV flag (never an env var, never via hermetic-run.sh): it replaces the per-push
# mutant stage with the full mutant x arm matrix. A plain run executes no matrix-only cell.
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
MX_FULL_RUNS=0     # incremented ONLY by matrix-only cells; a plain run must leave it at 0
if [ "$MATRIX" = 1 ]; then echo "MODE FULL (--matrix)"; else echo "MODE PUSH"; fi

PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
# The seed exits 2 above unless it found and copied the subject, so this line is reached only
# by a run whose verdict depends on it.
echo "HERMETIC-CONSUMED core/scripts/sprint-status.sh"
WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$PRISTINE" "$WORK"' EXIT

# A fresh COPY of the pristine seed, never an edit of it: a layout change applied in place leaks
# into every later arm, and the one that leaks reads as the one that fired.
#
# THE TOOLS ARE INSTALLED INTO THE TREE, not driven from beside it, and that is not tidiness. Both
# of them resolve the schema RELATIVE TO THE TREE THEY ARE IN; a copy run from outside resolves
# the pristine seed's schema instead, so A10 — which moves the declaration — silently tested
# nothing, and every mutant copy resolved no schema at all and failed four arms for a reason that
# had nothing to do with its mutation. The control caught it, which is what the control is for.
WN=0
fresh() { # <dir holding the two tools>  -> a new world dir, never reused
  WN=$((WN+1))
  local d="$WORK/w$WN"
  cp -R "$PRISTINE" "$d"
  cp "$1/sprint-status.sh" "$1/validate-mandatory-rules.sh" "$d/scripts/ai-dlc/"
  chmod +x "$d/scripts/ai-dlc"/*.sh
  FRESH_DIR="$d"
}

story() { # <dir> <basename> <status>
  mkdir -p "$1"
  printf -- '---\nstatus: %s\n---\n\n# story\n\n## Dev Agent Record\n\ndev (delegated) did it.\n' \
    "$3" > "$1/$2.md"
}

# The waiver path's two inputs: a story whose Dev Agent Record claims lead self-execution, and the
# escalations file that is supposed to authorize it.
selfexec_story() { # <dir> <basename>
  mkdir -p "$1"
  printf -- '---\nstatus: done\n---\n\n# story\n\n## Dev Agent Record\n\nModel: lead (self-executed) — see waiver\n' \
    > "$1/$2.md"
}
escalations() { # <root>  (body on stdin)
  mkdir -p "$1/docs/escalations"; cat > "$1/docs/escalations/pending.md"
}

# The two tools under test, driven exactly as a consumer drives them: validate-mandatory-rules.sh
# from the project root (every path in it is cwd-relative), sprint-status.sh with --root.
check6() { # <root> -> the Check 6 verdict line
  ( cd "$1" && bash "$1/scripts/ai-dlc/validate-mandatory-rules.sh" 302 2>&1 ) | grep -E '^  CHECK 6:'
}
check6_detail() { # <root> -> the Check6_DEV_AGENT_RECORD failure detail line
  ( cd "$1" && bash "$1/scripts/ai-dlc/validate-mandatory-rules.sh" 302 2>&1 ) | grep -E '^\[Check6_DEV_AGENT_RECORD\]'
}
stories_check() { # <root> -> stdout+stderr, sets SC_RC
  SC_OUT="$(bash "$1/scripts/ai-dlc/sprint-status.sh" check-stories --root "$1" 2>&1)"; SC_RC=$?
}

MIG="_bmad-output/planning-artifacts/s302/stories"
FLAT="_bmad-output/planning-artifacts/stories"

RES=""
res() { RES="$RES$1 $2"$'\n'; }
chk() { local id="$1"; shift; if "$@"; then res "$id" PASS; else res "$id" FAIL; fi; }

# =============================================================================
# THE ARMS. One function per world, so the same assertions can be re-run against a mutated copy of
# either tool. A world shared by two arms is built once for them, where the subject's output for
# that state is identical (A1/A2/A13 read one migrated tree; A3/A4 one flat tree; A11/A14 one waiver
# tree). Each arm function takes the directory holding the two tools under test.
# =============================================================================

arm_mig() { # A1 A2 A13 — a migrated tree resolves, Check 6 verifies the files, and a subdirectory run agrees
  local t
  fresh "$1"; t="$FRESH_DIR"
  story "$t/$MIG" story-1-alpha done
  story "$t/$MIG" story-2-beta  in_progress
  # --- A1: a migrated tree resolves, and says how many comparisons it made.
  stories_check "$t"
  if [ "$SC_RC" -eq 0 ] && grep -q 'PASS — 4 comparison(s)' <<<"$SC_OUT"; then res A1 PASS; else res A1 FAIL; fi
  # --- A2: and Check 6 verifies the files rather than a name-matching subset of them. The file
  # names carry NO sprint token, which is the whole point: the old glob keyed on one.
  if [[ "$(check6 "$t")" == *"PASS — 2 story file(s) verified"* ]]; then res A2 PASS; else res A2 FAIL; fi
  # --- A13 (BL-328): run from a SUBDIRECTORY of the consumer, the schema and the corpus are still
  # found. The schema lookup used bare `.claude/schemas/…` and `core/schemas/…`, which resolve
  # against the cwd: in this consumer-shaped tree the script-relative candidate is scripts/schemas/
  # (absent), so a run from below the root found no schema and Check 6 failed as unresolved. A2 is
  # the near-miss — the same tree driven from the root, which passed before and after.
  mkdir -p "$t/docs/sub"
  if [[ "$( ( cd "$t/docs/sub" && bash "$t/scripts/ai-dlc/validate-mandatory-rules.sh" 302 2>&1 ) | grep -E '^  CHECK 6:')" == *"PASS — 2 story file(s) verified"* ]]; then
    res A13 PASS; else res A13 FAIL; fi
}

arm_flat() { # A3 A4 — an UNMIGRATED tree: a FINDING on the story join, and Check 6 FAILS rather than SKIPping
  local t
  fresh "$1"; t="$FRESH_DIR"
  story "$t/$FLAT" story-302-1-alpha done
  story "$t/$FLAT" story-302-2-beta  in_progress
  # --- A3: the finding names the remedy. Silence here is the pull reporting success on a consumer
  # whose readers see nothing.
  stories_check "$t"
  if [ "$SC_RC" -eq 1 ] && grep -q 'names no readable story file' <<<"$SC_OUT" \
     && grep -q 'migrate-artifact-paths.sh' <<<"$SC_OUT"; then
    res A3 PASS; else res A3 FAIL; fi
  # --- A4: THE ARM THAT MATTERS. A corpus control counted only under the declared slot cannot see
  # these files at all and reports an empty corpus, which is a skip, which is a green gate over an
  # unverified sprint.
  if [[ "$(check6 "$t")" == *"FAIL — 0 of 2 story file(s)"* ]]; then res A4 PASS; else res A4 FAIL; fi
}

arm_A5() { # a corpus that is genuinely empty is a SKIP, not a failure
  # A greenfield consumer has no stories on its first sprint and a gate that fails it makes the
  # grammar unadoptable.
  local t
  fresh "$1"; t="$FRESH_DIR"
  if [[ "$(check6 "$t")" == *"SKIP — the story corpus is empty"* ]]; then res A5 PASS; else res A5 FAIL; fi
}

arm_A6() { # an UNRESOLVABLE corpus location fails closed
  # Asserted on the distinct verdict, not on the absence of a pass: "I could not find out" and
  # "there is nothing wrong" are different answers and this check used to spell them the same way.
  local t
  fresh "$1"; t="$FRESH_DIR"
  story "$t/$MIG" story-1-alpha done
  rm -f "$t/.claude/schemas/sprint-status.json"
  if [[ "$(check6 "$t")" == *"FAIL — the corpus location did not resolve"* ]]; then res A6 PASS; else res A6 FAIL; fi
}

arm_A7() { # ANOTHER sprint's stories are not this sprint's; the verdict is not a function of sprint HISTORY
  # A populated s301 beside an empty s302 SKIPs, exactly as the same tree with s301 deleted does: a
  # past sprint's slot holds that sprint's stories, never this one's, so it is no evidence this
  # sprint wrote its stories elsewhere. Asserted as byte-equality of the two verdict lines plus the
  # SKIP itself, so a history-counting control (which reads FAIL with s301 present and SKIP without
  # it) fails here. A4 is the near-miss that must still FAIL: the flat layout carries no sprint slot
  # and may hold this sprint's stories.
  local t a7_hist a7_del
  fresh "$1"; t="$FRESH_DIR"
  story "$t/_bmad-output/planning-artifacts/s301/stories" story-1-old done
  a7_hist="$(check6 "$t")"
  rm -rf "$t/_bmad-output/planning-artifacts/s301"
  a7_del="$(check6 "$t")"
  if [ "$a7_hist" = "$a7_del" ] && [[ "$a7_hist" == *"SKIP — the story corpus is empty"* ]]; then res A7 PASS; else res A7 FAIL; fi
}

arm_A8() { # the KEY still spells the sprint and the FILE does not: a capital-S legacy key resolves
  # The join strips the DECLARED sprint from the key to get the index, which is what makes the
  # 298/299 spelling split unable to come back.
  local t
  fresh "$1"; t="$FRESH_DIR"
  story "$t/$MIG" story-1-alpha done
  sed -i.bak 's/^  story-302-1:$/  story-S302-1:/; /^  story-302-2:$/,+1d' \
    "$t/_bmad-output/implementation-artifacts/sprint-status.yaml"
  sed -i.bak 's/^  story-302-1:$/  story-S302-1:/; /^  story-302-2:$/,+1d' \
    "$t/_bmad-output/planning-artifacts/sprint-status.yaml"
  rm -f "$t"/_bmad-output/*/sprint-status.yaml.bak
  stories_check "$t"
  if [ "$SC_RC" -eq 0 ] && grep -q 'PASS — 2 comparison(s)' <<<"$SC_OUT"; then res A8 PASS; else res A8 FAIL; fi
}

arm_A9() { # index-prefix collision: key `story-302-1` must never resolve to `story-10-…`
  # Asserted on the identity of the file read, not on the finding text A3 also carries — two
  # assertions reading one string is how one of them ends up proving nothing.
  local t
  fresh "$1"; t="$FRESH_DIR"
  story "$t/$MIG" story-10-late-arrival review
  stories_check "$t"
  if ! grep -q 'story-10-late-arrival' <<<"$SC_OUT"; then res A9 PASS; else res A9 FAIL; fi
}

arm_A10() { # the corpus location is the SCHEMA's: move the declaration and both tools follow it
  # A tool that had kept its own copy of the literal would go on reading the old place and report a
  # clean sheet over a tree it is not looking at.
  local t
  fresh "$1"; t="$FRESH_DIR"
  sed -i.bak 's|"_bmad-output/planning-artifacts/s{sprint}/stories"|"_bmad-output/elsewhere/s{sprint}/tales"|' \
    "$t/.claude/schemas/sprint-status.json"
  rm -f "$t/.claude/schemas/sprint-status.json.bak"
  story "$t/_bmad-output/elsewhere/s302/tales" story-1-alpha done
  story "$t/_bmad-output/elsewhere/s302/tales" story-2-beta  in_progress
  stories_check "$t"
  if [ "$SC_RC" -eq 0 ] && grep -q 'PASS — 4 comparison(s)' <<<"$SC_OUT"; then res A10 PASS; else res A10 FAIL; fi
}

arm_waiver() { # A11 A14 — the self-execution waiver lifts when the escalation entry that NAMES the story carries the token
  # A11 keeps A12 honest: a predicate that denied everything would satisfy A12 alone and look like
  # the fix. A14 (BL-328) is the same world driven from docs/sub/: re-rooting only the schema and
  # the corpus found the story but not docs/escalations/pending.md, so a VALID waiver failed with
  # "no waiver" -- a wrong reason, worse than the honest "unresolved" base printed. Asserted as
  # byte-equality of the Check 6 verdict AND every Check6_ detail line with the root run, plus the
  # PASS itself, so a wrong-reason FAIL and a differently-worded pass both fail it. A11 is the
  # root-run near-miss.
  local t a14_root a14_sub
  fresh "$1"; t="$FRESH_DIR"
  selfexec_story "$t/$MIG" story-1-alpha
  escalations "$t" <<'ESC'
## [Sprint-302 / Story 302-1 self-execution] Lead - 2026-08-11
**Status:** DECIDED_AUTONOMOUSLY
**Context:** covered.
ESC
  if [[ "$(check6 "$t")" == *"PASS — 1 story file(s) verified"* ]]; then res A11 PASS; else res A11 FAIL; fi
  mkdir -p "$t/docs/sub"
  a14_root="$( ( cd "$t" && bash "$t/scripts/ai-dlc/validate-mandatory-rules.sh" 302 2>&1 ) | grep -E '^  CHECK 6:|^\[Check6_')"
  a14_sub="$( ( cd "$t/docs/sub" && bash "$t/scripts/ai-dlc/validate-mandatory-rules.sh" 302 2>&1 ) | grep -E '^  CHECK 6:|^\[Check6_')"
  if [ "$a14_sub" = "$a14_root" ] && [[ "$a14_sub" == *"PASS — 1 story file(s) verified"* ]]; then res A14 PASS; else res A14 FAIL; fi
}

arm_A12() { # a NEIGHBOURING entry's token does not waive this story. THE ARM THAT MATTERS HERE.
  # The story is named in one entry whose status is `RESOLVED`; the `DECIDED_AUTONOMOUSLY` five
  # lines below belongs to the NEXT entry. That is the exact shape the reference consumer's
  # `pending-archive.md:641/:646` has, and under the old `grep -A 5` proximity match it passed.
  # Asserted on the failure detail naming this story, not on the absence of the pass line — two
  # different reasons to lose that line and only one of them is this arm's.
  local t
  fresh "$1"; t="$FRESH_DIR"
  selfexec_story "$t/$MIG" story-1-alpha
  escalations "$t" <<'ESC'
## [Sprint-302 / Model-strategy note] Lead - 2026-08-11
**Status:** RESOLVED
**Context:** Stories covered by this note: story-302-1.

---

## [Sprint-302 / A different finding] qa - 2026-08-11
**Status:** DECIDED_AUTONOMOUSLY
**Context:** unrelated to the entry above.
ESC
  if [[ "$(check6_detail "$t")" == *"no DECIDED_AUTONOMOUSLY or HARD_BLOCK waiver for 'Story 302-1'"* ]]; then res A12 PASS; else res A12 FAIL; fi
}

# arm key -> ids it prints; id -> arm key
ALL_KEYS="mig flat A5 A6 A7 A8 A9 A10 waiver A12"
ids_of() { case "$1" in mig) echo "A1 A2 A13" ;; flat) echo "A3 A4" ;; waiver) echo "A11 A14" ;; *) echo "$1" ;; esac; }
ALL_IDS=""; ID_KEY=" "
for _k in $ALL_KEYS; do for _i in $(ids_of "$_k"); do ALL_IDS="$ALL_IDS $_i"; ID_KEY="$ID_KEY$_i:$_k "; done; done
key_of() { local e; for e in $ID_KEY; do [ "${e%%:*}" = "$1" ] && { printf '%s' "${e#*:}"; return 0; }; done; return 1; }
arm() { "arm_$1" "$2"; } # <key> <tools dir>
sets_from() { # <RES text> -> PASS_OUT FAIL_OUT, space padded; no forks
  local i v
  PASS_OUT=" "; FAIL_OUT=" "
  while read -r i v; do
    [ -n "$i" ] || continue
    case "$v" in PASS) PASS_OUT="$PASS_OUT$i " ;; FAIL) FAIL_OUT="$FAIL_OUT$i " ;; esac
  done <<<"$1"
}
in_set() { case "$2" in *" $1 "*) return 0 ;; esac; return 1; }

echo "story-corpus-sprint-slot:"

TD_REAL="$PRISTINE/scripts/ai-dlc"

RES=""
for k in $ALL_KEYS; do arm "$k" "$TD_REAL"; done
sets_from "$RES"; SHIP_PASS="$PASS_OUT"; SHIP_FAIL="$FAIL_OUT"
ship_bad=""; for i in $ALL_IDS; do in_set "$i" "$SHIP_PASS" || ship_bad="$ship_bad $i"; done
if [ -z "$ship_bad" ]; then
  ok "all 14 assertions pass on the shipping tools"
else
  bad "battery failed on the SHIPPING tools:$ship_bad"
fi

# =============================================================================
# MUTANTS. Each is a COPY of the tools dir with one change, guarded by `cmp -s` so a sed that matched
# nothing cannot pass as a mutation. Name | decides arms | twin arm | target | sed expr.
# =============================================================================
MN=(); MD=(); MT=(); MW=(); ME=(); NM=0
defm() { MN[$NM]="$1"; MD[$NM]="$2"; MT[$NM]="$3"; MW[$NM]="$4"; ME[$NM]="$5"; NM=$((NM+1)); }

# A4: narrow Check 6's corpus control back to the declared slot — the blind spot the arm exists
# for. The unmigrated tree then reports an empty corpus and SKIPs.
defm a4-corpus-control-narrowed-to-slot A4 A3 vmr \
  's/^  CHECK6_AREA_CORPUS=\$((CHECK6_FLAT_CORPUS + CHECK6_MATCHED))$/  CHECK6_AREA_CORPUS=$((CHECK6_MATCHED))/'
# A7: drop the sprint-slot exclusion from the flat count, so every sprint's slot is counted again
# -- the history-dependent control this arm exists for. A past s301 then reads FAIL while the
# same tree with s301 deleted reads SKIP. A2 stays green (its s302 stories are both matched and
# counted), and A4 and A5 do not move, so the kill is A7's alone.
defm a7-flat-count-counts-other-slots A7 A5 vmr \
  '/if (is_slot(part\[i]))  *next$/d'
# A6: turn the unresolvable-location failure into a skip, which is what it used to be.
defm a6-unresolved-skips-instead-of-failing A6 A5 vmr \
  's/^if \[ "\$CHECK6_UNRESOLVED" -eq 1 \]; then$/if [ "$CHECK6_UNRESOLVED" -eq 2 ]; then/'
# A8: drop the optional sprint-token prefix from the key matcher, so only a BARE number is
# stripped. Deliberately narrower than "stop stripping at all", which was the first mutant here
# and was ENTANGLED: it also broke A1 and A10, both of which already assert the stripping. What
# A8 alone claims is that a capital-S legacy key resolves, so that is what this removes.
defm a8-capital-s-key-unrecognised A8 A1 ss \
  's/r"\[sS\]?0\*%d"/r"0*%d"/'
# A9: widen the index glob to a prefix match, the collision that compares story-1 against story-10.
defm a9-index-glob-prefix-widened A9 A1 ss \
  's/stories.glob(stem + "-\*.md")/stories.glob(stem + "*.md")/'
# A10: put the corpus literal back into sprint-status.sh instead of resolving the template, which
# is the restatement I84 bans. It then cannot follow the declaration when it moves.
defm a10-corpus-literal-restated A10 A1 ss \
  's|^    return STORIES_DIR_T.replace(SPRINT_SLOT, str(sprint))$|    return "_bmad-output/planning-artifacts/s%s/stories" % sprint|'
# A12: delete the one line that closes the match window at an entry boundary. What is left is the
# proximity match this release replaced -- same 5 lines, now free to run into the next entry. The
# mutation is exactly the layer under test, and A11 staying green is what says so.
defm a12-waiver-window-crosses-entry A12 A11 vmr \
  '/^          \/\^## \/ { win = 0 }/d'
# A13 + A14: the BL-328 fix reverted whole -- the process no longer moves to the walked-up root, so
# every read resolves against the invoking directory again. Both subdirectory arms fail and that is
# declared, not entangled: A14 reads everything A13 reads (schema, corpus) plus the escalations
# file, so no mutant can fail A13 without A14. A14's own subject is the mutant below.
defm a13-a14-process-stays-in-invoking-dir A13,A14 A2 vmr \
  's|^if \[ -n "\$VMR_ROOT" \] && \[ "\$VMR_ROOT" != "\$VMR_CALLER_CWD" \]; then$|if false; then|'
# A14: ONE read restored to the invoking directory -- the escalations file -- with the schema and
# corpus still rooted. That is the partial re-root this arm exists for: the story is found, its
# waiver is not, and Check 6 fails with a wrong reason. A11 (root run) must stay green.
defm a14-escalations-read-from-invoking-dir A14 A11 vmr \
  's|^ESCALATIONS_FILE="docs/escalations/pending.md"$|ESCALATIONS_FILE="${VMR_CALLER_CWD}/docs/escalations/pending.md"|'

MUT_OK=" "
mut_i=0
while [ "$mut_i" -lt "$NM" ]; do
  n="${MN[$mut_i]}"; mdir="$WORK/mut-$n"
  cp -R "$TD_REAL" "$mdir"
  case "${MW[$mut_i]}" in
    ss)  target="$mdir/sprint-status.sh" ;;
    vmr) target="$mdir/validate-mandatory-rules.sh" ;;
    *)   bad "FIXTURE BROKEN — unknown mutant target '${MW[$mut_i]}'"; mut_i=$((mut_i+1)); continue ;;
  esac
  sed "${ME[$mut_i]}" "$target" > "$target.mut"
  if cmp -s "$target" "$target.mut"; then
    bad "FIXTURE BROKEN — MUTANT $n changed nothing; the assertion below would test the original"
    rm -f "$target.mut"
  else
    mv "$target.mut" "$target"; chmod +x "$target"
    MUT_OK="$MUT_OK$n "
  fi
  mut_i=$((mut_i+1))
done

# --- Unmutated control -------------------------------------------------------
# A copy in the same directory shape as the mutants, mutated not at all. Without it, a harness
# that breaks every copy for a reason of its own — a schema a copy cannot resolve, a lost exec
# bit — scores every mutant above as a kill. Per push it drives exactly the arms the mutants drive
# (their decides and twins); under --matrix it drives all of them.
CTRL="$WORK/mutant-control"
cp -R "$TD_REAL" "$CTRL"
want_keys=" "
if [ "$MATRIX" = 1 ]; then want_keys=" $ALL_KEYS "; else
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    for _a in ${MD[$mut_i]//,/ } ${MT[$mut_i]//,/ }; do
      _k="$(key_of "$_a")" || { bad "FIXTURE BROKEN — mutant ${MN[$mut_i]} names unknown arm $_a"; continue; }
      case "$want_keys" in *" $_k "*) ;; *) want_keys="$want_keys$_k " ;; esac
    done
    mut_i=$((mut_i+1))
  done
fi
RES=""
for k in $ALL_KEYS; do case "$want_keys" in *" $k "*) arm "$k" "$CTRL" ;; esac; done
sets_from "$RES"; CTRL_PASS="$PASS_OUT"; CTRL_FAIL="$FAIL_OUT"
if [ "$CTRL_FAIL" = " " ] && [ "$CTRL_PASS" != " " ]; then
  ok "CONTROL: an unmutated copy beside the mutants passes every arm the mutants drive"
else
  bad "CONTROL: an unmutated copy failed [$CTRL_FAIL] — the harness itself is what breaks a copy, so every mutant verdict below is meaningless"
fi

base_ok() { in_set "$1" "$SHIP_PASS" && in_set "$1" "$CTRL_PASS"; }
join_set() { local o="" x; for x in "$@"; do o="$o,$x"; done; printf '%s' "${o#,}"; }

if [ "$MATRIX" = 1 ]; then
  # FULL MATRIX: every mutant driven against EVERY arm; every cell printed, 1 = the arm FAILS under the mutant.
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    n="${MN[$mut_i]}"
    case "$MUT_OK" in *" $n "*) ;; *) mut_i=$((mut_i+1)); continue ;; esac
    RES=""; MX_FULL_RUNS=$((MX_FULL_RUNS + 1))
    for k in $ALL_KEYS; do arm "$k" "$WORK/mut-$n"; done
    sets_from "$RES"
    cells=""; tripped=""
    for i in $ALL_IDS; do
      if in_set "$i" "$FAIL_OUT"; then cells="$cells,$i:1"; tripped="$tripped $i"; else cells="$cells,$i:0"; fi
    done
    decl="$(printf '%s' " ${MD[$mut_i]//,/ } " | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
    meas="$(printf '%s' "$tripped" | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
    st=match; [ "$decl" = "$meas" ] || st=DIFFERS
    tw=green; for _t in ${MT[$mut_i]//,/ }; do in_set "$_t" "$FAIL_OUT" && tw=TRIPPED; done
    printf 'MATRIX %s decides=%s cells=%s tripped=[%s] declared=%s twins=%s\n' "$n" "${MD[$mut_i]}" "${cells#,}" "$(join_set $tripped)" "$st" "$tw"
    mut_i=$((mut_i+1))
  done
else
  # PER PUSH: each mutant drives its DECIDING arm(s) and its measured-green TWIN only.
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    n="${MN[$mut_i]}"
    case "$MUT_OK" in *" $n "*) ;; *) mut_i=$((mut_i+1)); continue ;; esac
    dec=" ${MD[$mut_i]//,/ } "; twn=" ${MT[$mut_i]//,/ } "
    flag=1
    for a in $dec $twn; do base_ok "$a" || flag=0; done
    keys=" "
    for a in $dec $twn; do _k="$(key_of "$a")"; case "$keys" in *" $_k "*) ;; *) keys="$keys$_k " ;; esac; done
    RES=""
    for k in $keys; do arm "$k" "$WORK/mut-$n"; done
    sets_from "$RES"
    wrong=""
    for a in $dec; do in_set "$a" "$FAIL_OUT" || wrong="$wrong $a-did-not-flip"; done
    for i in $FAIL_OUT; do case "$dec" in *" $i "*) ;; *) wrong="$wrong $i-tripped-outside-decides" ;; esac; done
    for a in $twn; do in_set "$a" "$PASS_OUT" || wrong="$wrong $a-twin-not-green"; done
    if [ -n "$wrong" ]; then
      if [ "$flag" = 1 ]; then bad "MUTANT $n failed wrongly [$wrong ], expected decides=[${MD[$mut_i]}] with twin [${MT[$mut_i]}] green — entangled assertions, or the mutation is not reached"; else need_base "$flag" "$n" || true; fi
    else
      mutant_killed "$flag" "$n" "MUTANT $n dies on [${MD[$mut_i]}]; twin [${MT[$mut_i]}] stays green"
    fi
    mut_i=$((mut_i+1))
  done
  if [ "$MX_FULL_RUNS" -eq 0 ]; then ok "a plain run executed no matrix-only cell (MX_FULL_RUNS=0)"
  else bad "a plain run executed $MX_FULL_RUNS matrix-only cell(s)"; fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "story-corpus-sprint-slot: PASS"
  exit 0
fi
echo "story-corpus-sprint-slot: $fails assertion(s) FAILED" >&2
exit 1
