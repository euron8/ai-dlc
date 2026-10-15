#!/usr/bin/env bash
# updater-session-signals-mutants — the mutation battery behind `updater-session-signals`.
# DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every mutant moves exactly its own assertions, 1 = one did not, 2 = fixture broken.
#
# WHY IT EXISTS. The shipped fixture has six arms across three disjoint signals, and the
# thing that makes them worth having is that each one covers an invocation path the other
# two cannot see. That claim is only worth as much as a demonstration that removing an arm
# turns exactly its own path red -- otherwise a fixture with three redundant arms and a
# fixture with three load-bearing ones read identically, both green.
#
# WHY IT IS SPLIT OUT (v0.230.0's rule): the battery re-runs the subject fixture once per
# mutant, so held together the pair costs several times the assertions alone, and what a
# unit COSTS is a property of the suite it runs in. It also mutates `ai-dlc-acknowledge.sh`,
# which is CORE's -- `ai-dlc-core-guard.sh` denies a consumer the in-place edit, so the
# surface these mutants perturb cannot change in a consumer tree. The consumer keeps every
# correctness arm and pays for none of this.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

SUBJ="$HERE/../updater-session-signals/run.sh"
[ -f "$SUBJ" ] || { echo "FIXTURE ERROR: sibling updater-session-signals/run.sh not found" >&2; exit 2; }
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-acknowledge.sh" ]; then
  HOOK="$ROOT/core/hooks/ai-dlc-acknowledge.sh"
else
  echo "FIXTURE ERROR: core/hooks/ai-dlc-acknowledge.sh not found — this fixture is distribution-only" >&2
  exit 2
fi
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-acknowledge.sh"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Build the mutant as a COPY, never an in-place edit, and refuse a sed that matched nothing:
# an unmutated copy runs the subject GREEN and scores as a kill.
mut_reds() { # <label> <sed program, empty for the control> -> the subject's FAIL lines
  local label="$1" prog="$2" copy="$WORK/$1.sh"
  if [ -z "$prog" ]; then
    cp "$HOOK" "$copy"
  else
    sed "$prog" "$HOOK" > "$copy" 2>/dev/null
    if cmp -s "$HOOK" "$copy"; then printf 'UNMUTATED\n'; return 0; fi
  fi
  AI_DLC_USS_HOOK="$copy" bash "$SUBJ" > "$WORK/$label.out" 2>/dev/null
  sed -n 's/^  FAIL  //p' "$WORK/$label.out"
}

expect_set() { # <label> <expected count> <ERE every red must match> <sed>
  local label="$1" want="$2" re="$3" prog="$4" reds n unmatched
  reds="$(mut_reds "$label" "$prog")"
  if [ "$reds" = "UNMUTATED" ]; then
    bad "MUTANT $label: the sed matched nothing — no mutation was applied, so nothing was proven"
    return
  fi
  n="$(printf '%s' "$reds" | grep -c . || true)"
  unmatched="$(printf '%s' "$reds" | grep -vE "$re" | grep -c . || true)"
  if [ "$n" -eq "$want" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $label moves exactly the $want assertion(s) it should, and no others"
  else
    bad "MUTANT $label: expected $want red(s) matching '$re', got ${n} (${unmatched} unexpected): $(printf '%s' "$reds" | tr '\n' ';')"
  fi
}

echo "updater-session-signals-mutants:"

# THE UNMUTATED CONTROL, first. A mutant copy that dies on its own — a bad edit, a missing
# interpreter, a path the copy cannot resolve — emits no FAIL lines at all, and "no output"
# otherwise scores as a kill for every mutant below it.
CTRL="$(mut_reds control '')"
if [ -z "$CTRL" ]; then
  ok "CONTROL: an unmutated copy of the hook runs the subject fixture GREEN"
else
  bad "CONTROL: an unmutated copy already reds — the harness, not the mutants, is what these arms measure: $(printf '%s' "$CTRL" | tr '\n' ';')"
fi
# THE DISPATCH GUARD IS AN INPUT TOO, read UNMUTATED by the subject's ERE byte-compare arm. The
# subject resolves it from ITS OWN directory, never beside the hook copy, so the guard reaches
# that arm only through this battery's declaration -- and the sandbox's proof the arm reached it is
# the subject's own sentinel, forwarded from the control run rather than echoed here.
grep '^HERMETIC-CONSUMED .*/ai-dlc-dispatch-guard\.sh$' "$WORK/control.out"

# 1. THE PAYLOAD ARM, removed whole. It is the only signal that exists at the dispatch
#    itself, and it is also what lets a resume override a stale transcript. The other-order
#    dispatch reds with it: its transcript's last skill is the typed `/ai-dlc`.
expect_set payload-arm-deleted 3 'PC-S331 is back|stays exempt forever|DISPATCH \(other order\)' \
  "/jq -r '\.tool_input\.skill/,/^esac\$/d"

# 1b. THE PAYLOAD DEFERRING TO THE TRANSCRIPT (BL-404). The updater payload grants only where the
#    transcript named no `/ai-dlc`, so the current call no longer outranks the transcript's last
#    skill. Only the other-order DISPATCH can see it: every other Skill(ai-dlc-update) drive has a
#    transcript that names no pipeline skill, and every later call reads the flushed tool_use line.
expect_set payload-defers-to-transcript 1 'DISPATCH \(other order\)' \
  's/^  ai-dlc-update) UPDATER_SESSION=1 ;;$/  ai-dlc-update) [ "$AIDLC_SESSION" -eq 1 ] || UPDATER_SESSION=1 ;;/'

# 2. THE TOOL_USE CASE ARM. Covers everything AFTER the dispatch — the updater's own
#    per-file fan-out, which no payload carries a skill field for, and every Write it makes
#    after the dispatch (an Edit carries no skill field either). It also reds both cells of
#    the pipeline-then-updater session, whose only updater signal is that tool_use line.
expect_set tooluse-case-deleted 4 'per-file Agent dispatch was DENIED|WRITE \(ii\)|WRITE \(iii-b\)|RECENCY \(other order\)' \
  '/"skill":"ai-dlc-update".)/d'

# 3. THE TYPED ALTERNATIVE. The pre-existing arm, and the ONLY signal a typed invocation
#    produces — a fix that replaced it rather than adding to it would come out green on
#    everything the consumer reported and break the operator's own path. Deleted WHOLE,
#    anchor and marker together: keyed on the bare marker alone this `sed` now lands inside
#    the anchored alternative and leaves a mangled regex rather than no typed arm. It reds the
#    typed session's dispatch, its write, and its teammate's write (which then reads as a
#    no-skill session's teammate and is logged).
expect_set marker-alternative-deleted 3 'typed by the operator was DENIED|WRITE \(i\)|WRITE \(vi\)' \
  '/^  LAST_SKILL=/s#"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\\\n<command-name>/ai-dlc(-update)?</command-name>|##'

# 6. THE WRITE ARM's UPDATER CONJUNCT, made unreachable. The defect as filed: an updater
#    session's Edit under planning-artifacts/ is denied again, typed or Skill-invoked, and a
#    teammate in one is logged as a pipeline teammate. The pipeline-then-updater session's
#    Edit is an updater write too, so WRITE (iii-b) reds with them.
expect_set write-updater-conjunct-dropped 4 'WRITE \(i\)|WRITE \(ii\)|WRITE \(iii-b\)|WRITE \(vi\)' \
  's/if \[ "\$UPDATER_SESSION" -eq 1 \]; then :$/if false; then :/'

# 7. ...and made UNCONDITIONAL — the leak. Every paused write under _bmad-output/ passes
#    silently: the section's own control, the resumed pipeline, the missing transcript, the
#    pipeline teammate (no longer logged), and all three mention arms' Edit halves. Their Agent
#    halves stay DENY, because the dispatch arm is a different line.
expect_set write-updater-unconditional 7 'FIXTURE BROKEN: a pipeline lead|WRITE \(iii\)|WRITE \(iv\)|WRITE \(v\)|MENTION (read|text|head) Edit' \
  's/if \[ "\$UPDATER_SESSION" -eq 1 \]; then :$/if true; then :/'

# 8. THE TYPED ANCHOR REVERTED TO THE BARE MARKER — B1's leak. A pipeline session that reads,
#    quotes or prints the updater's marker becomes "the updater" and its pause is off, for
#    writes and dispatches alike: all six mention cells.
expect_set typed-anchor-reverted-to-bare 6 'MENTION (read|text|head) (Edit|Agent): LEAK' \
  '/^  LAST_SKILL=/s#"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\\\n##'

# 9. THE ANCHOR's `"role":"user",` PREFIX DROPPED. A tool_result's string follows `"content":"`
#    exactly as a typed record's does, so only the seed whose output STARTS with the pair can
#    tell the two anchors apart — and it must be the only thing that moves.
expect_set typed-anchor-role-dropped 2 'MENTION head (Edit|Agent): LEAK' \
  '/^  LAST_SKILL=/s#"role":"user","content":"<command-message>#"content":"<command-message>#'

# 10. THE LAST-SKILL RULE REVERSED to the FIRST skill (BL-404). Both orders are seeded, so a
#    first-match scan reds both: updater-then-/ai-dlc reads as the updater (the two resumed
#    LEAK arms), and /ai-dlc-then-updater reads as the pipeline (the two other-order arms).
#    Before the other order was seeded this mutant moved only the first pair.
expect_set last-skill-reversed-to-first 4 'order-blind|WRITE \(iii\): LEAK|WRITE \(iii-b\)|RECENCY \(other order\)' \
  '/^  LAST_SKILL=/s/| tail -1)$/| head -1)/'

# 4. THE PAYLOAD ARM WIDENED to any ai-dlc* skill — the leak that turns the Rule 29 pause
#    off for the pipeline skill it exists to stop.
expect_set payload-arm-widened 2 'exempts ANY Skill call|stays exempt forever' \
  's/ai-dlc-update) UPDATER_SESSION=1/ai-dlc*) UPDATER_SESSION=1/'

# 5. THE PAYLOAD'S NEGATIVE HALF. Granting on `ai-dlc-update` without revoking on `ai-dlc`
#    leaves a session that ever ran the updater exempt for the rest of its life.
expect_set payload-revoke-deleted 1 'stays exempt forever' \
  '/ai-dlc)        UPDATER_SESSION=0/d'

# E. THE EXPLORE CARVE-OUT, one conjunct at a time. Each mutant reds exactly the DENY cell whose
#    near-miss only that conjunct separates from the ALLOW cell.
#
# E1. WIDENED to any subagent_type: jq -e on the bare field is true for every non-null, non-false
#    value. Every named near-miss passes; null and the absent field (the section's CONTROL) do not.
expect_set explore-any-subagent-type 6 'EXPLORE MALFORMED (\["Explore"\]|"Explore\\n"|"Explore "|"explore")|EXPLORE OPS|EXPLORE AGENT_TYPE' \
  's/jq -e '"'"'\.tool_input\.subagent_type == "Explore"'"'"'/jq -e '"'"'.tool_input.subagent_type'"'"'/'

# E2. THE ROLE-CITATION CLAUSE DROPPED: the dispatch guard rewrites a cited role's subagent_type,
#    so an Explore that cites team-roles/remediator.md runs as the remediator.
#    Neutralised in place rather than deleted, so the ERE stays on the line and the byte-compare arm
#    does not red with it.
expect_set explore-role-clause-dropped 1 'EXPLORE ROLE CITATION' \
  's/^          elif grep -qE /          elif false \&\& grep -qE /'

# E3. THE LEAD-ONLY CLAUSE DROPPED: a dispatched teammate spawns Explore while paused.
expect_set explore-lead-clause-dropped 1 'EXPLORE TEAMMATE' \
  's/^        if \[ -z "\$AGENT_ID" \] \\$/        if true \\/'

# E4. THE COMPARISON MOVED OUTSIDE jq: `$( )` strips the trailing newline of "Explore\n", so that
#    near-miss alone passes. Every other one still differs after `jq -r`.
expect_set explore-compare-outside-jq 1 'EXPLORE MALFORMED "Explore\\n"' \
  's/\&\& jq -e '"'"'\.tool_input\.subagent_type == "Explore"'"'"' <<< "\$INPUT" >\/dev\/null 2>&1; then$/\&\& [ "$(jq -r '"'"'.tool_input.subagent_type'"'"' <<< "$INPUT")" = Explore ]; then/'

# E5. THE CARVE-OUT SITED BEFORE THE STOP EXIT: Check 2a skips an Explore dispatch, so a pending
#    Rule 8 STOP no longer denies it and Check 3's carve-out lets it through.
expect_set explore-before-stop 1 'EXPLORE STOP' \
  's/^if \[ "\$ADVANCING_TOOL" -eq 1 \] \&\& \[ "\$UPDATER_SESSION" -eq 0 \]; then$/if [ "$ADVANCING_TOOL" -eq 1 ] \&\& [ "$UPDATER_SESSION" -eq 0 ] \&\& ! jq -e '"'"'.tool_input.subagent_type == "Explore"'"'"' <<< "$INPUT" >\/dev\/null 2>\&1; then/'

# E6. THE SHADOW CHECK REVERTED TO THE FILENAME: the harness selects a definition by its frontmatter
#    `name:`, so a search.md named Explore, and a user-level one, pass. Explore.md itself still denies.
expect_set explore-shadow-filename-only 2 'EXPLORE NAMED OTHER|EXPLORE HOME NAMED' \
  's/^          elif explore_shadowed; then$/          elif [ -e "${PROJECT_DIR}\/.claude\/agents\/Explore.md" ]; then/'

# E7. THE SHADOW CHECK DROPPED WHOLE: every world carrying a definition named Explore passes.
expect_set explore-shadow-clause-dropped 3 'EXPLORE SHADOWED|EXPLORE NAMED OTHER|EXPLORE HOME NAMED' \
  's/^          elif explore_shadowed; then$/          elif false; then/'

# E8. THE $HOME SCAN DROPPED: a user-level definition named Explore shadows the built-in unseen.
expect_set explore-shadow-home-dropped 1 'EXPLORE HOME NAMED' \
  's/ "\${HOME:+\${HOME}\/\.claude\/agents}"//'

# E9. THE FRONTMATTER BOUND DROPPED: a `name: Explore` line in a definition's BODY reads as its name.
expect_set explore-shadow-unbounded 1 'EXPLORE NAMED IN BODY' \
  '/^       !fm { next }$/d'

# E10. THE NAME MATCH LOOSENED to a substring: `Explorer` reads as Explore, in both scopes.
expect_set explore-shadow-substring 2 'EXPLORE NAMED EXPLORER|EXPLORE HOME EXPLORER' \
  's/if (tolower(v) == "explore") found = 1/if (tolower(v) ~ "explore") found = 1/'

# E11. THE NAME MATCH MADE CASE-SENSITIVE: the user-level `"explore"` no longer matches.
expect_set explore-shadow-case-sensitive 1 'EXPLORE HOME NAMED' \
  's/if (tolower(v) == "explore") found = 1/if (v == "Explore") found = 1/'

# E12. THE name / team_name CLAUSE DROPPED: an Explore routed to the in-process teammate runner passes.
expect_set explore-teammate-runner-dropped 2 'EXPLORE TOOL_INPUT (NAME|TEAM_NAME)' \
  's/^          if ! jq -e .\.tool_input | (has("name")/          if false \&\& jq -e '"'"'.tool_input | (has("name")/'

# E13. THE HOOK's ROLE ERE WIDENED ALONE: every seeded citation is lower case, so no verdict moves --
#    only the byte-compare against the dispatch guard's copy can see the two drift apart.
expect_set explore-ere-drift 1 'EXPLORE ERE DRIFT' \
  's#grep -qE '"'"'team-roles/\[a-z\]#grep -qE '"'"'team-roles/[A-Za-z]#'

# E14. THE DENY TEXT NEVER NAMES THE FAILED CONDITION: every lead Explore dispatch the carve-out
#    refuses is denied without saying why, beside a paragraph that reads as offering it.
expect_set explore-why-dropped 6 "cell .UNEXPLAINED" \
  's/^\[ -z "\$EXPLORE_WHY" \] || EXPLORE_TEXT=/: || EXPLORE_TEXT=/'

echo
if [ "$fails" -eq 0 ]; then echo "updater-session-signals-mutants: PASS"; exit 0; fi
echo "updater-session-signals-mutants: $fails assertion(s) FAILED" >&2
exit 1
