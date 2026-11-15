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
# prints `A<n> PASS|FAIL`. The shipping tools run every arm.
#
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking anything (I10). The tools under test
# take AI_DLC_PROJECT_ROOT ahead of their own walk (sprint-status.sh), and every arm below drives
# a copy INSTALLED INTO a seeded tree; an inherited override points them at some other tree and
# A10, which moves the declaration inside the seed, then fails.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# No distribution-root walk here: this file needs none. The seed names its sources in both layouts;
# this file resolves nothing but itself.
HERE="$(cd "$(dirname "$0")" && pwd)"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }


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
# nothing.
WN=0
fresh() { # <dir holding the two tools>  -> a new world dir, never reused
  WN=$((WN+1))
  local d="$WORK/w$WN"
  cp -R "$PRISTINE" "$d"
  basename "$1" > "$d/.tools-tag"   # which tools directory this world serves
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
ALL_IDS=""
for _k in $ALL_KEYS; do for _i in $(ids_of "$_k"); do ALL_IDS="$ALL_IDS $_i"; done; done
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


echo
report_end story-corpus-sprint-slot
