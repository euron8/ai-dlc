#!/usr/bin/env bash
# Pin deploy-validate.md §3's smoke-evidence classification text.
#
# SUBJECT. §3 (Smoke Tests) requires the `smoke_run_evidence` record to carry four
# fields -- `first_run_failures`, `transient_failures_cleared_on_retry`,
# `persistent_failures`, `per_action_attribution` -- requires one live mutation per
# smoke run (an operator-fired §2a operation included), and defines a transient failure as one a retry cleared with
# NO ACTION BY THE LEAD between the runs, and requires the smoke-failure loop's code-issue
# item to dispatch `dev` rather than leave the fix to the lead. The Production Validation Checkpoint's
# `Deployment` block reports the same split. §5's checkpoint template carries a
# `### Locked-Requirement Coverage` block -- one line per LOCKED_REQUIREMENTS bullet, delivered /
# deferred / descoped, with the HARD_BLOCK id and disposition token (approved-deferral / do-now /
# descope) -- and §5's prose withholds the checkpoint while a locked requirement lacks a recorded
# disposition. No script reads `smoke_run_evidence` or the coverage block; the
# executing lead reads this prose, so the prose is the mechanism and this fixture pins it.
#
# §5 IS ISOLATED FENCE-AWARE: its template fence holds `### ` lines, so only a `### ` outside the
# fence ends §5 (see sec5()). The block arms read the fence, the gating arm reads §5 prose only.
#
# KEYED ON THE SECTION, NOT THE FILE. Each field must be DEFINED as a `- \`<field>\` --`
# bullet inside §3's body (heading `### 3. Smoke Tests` up to the next `### ` heading).
# A whole-file grep is satisfied by a mention in any other section, and by the checkpoint
# block, which names the same concepts; the MOVE mutant below proves this arm is not.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when the subject file
# cannot be located or §3 cannot be isolated. An absent subject is never green: a
# consumer that pulled this fixture ahead of the step file must see the gap.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

STEP=""
for cand in \
  "$DIR/../../skills/ai-dlc/steps/deploy-validate.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/deploy-validate.md"; do
  [ -f "$cand" ] && STEP="$cand" && break
done
if [ -z "$STEP" ]; then
  echo "deploy-validate-smoke-classification: FIXTURE BROKEN -- could not locate deploy-validate.md in either layout (core/skills/ai-dlc/steps/ or .claude/skills/ai-dlc/steps/). An absent subject is not a passing one." >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dv-smoke-class.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

echo "deploy-validate-smoke-classification: subject $STEP"

FIELDS="first_run_failures transient_failures_cleared_on_retry persistent_failures per_action_attribution"
# ONE VARIABLE PER SMOKE RUN: without it a run that follows two live mutations cannot say which
# one cleared a failure. The §2a clause settles that an operator-fired operation is one of them.
ONEVAR='One live mutation per smoke run.'
OPFIRED='A §2a destructive one-time operation fired by the operator is a live mutation'
DEF='A failure is transient ONLY when a retry cleared it with NO ACTION BY THE LEAD between the runs'
INRUN='in-run retry, same output'
# THE FIX LOOP DISPATCHES. Item 3 once said "route back to the dev teammate", which names no
# delegation, and a lead executed a code fix inline under it.
DISPATCH='^3\. If code issue: dispatch `dev` to fix'
LEADSCOPE='a lead that edits product code here is applying a fix inline, which Rule 28 makes a lead-conduct finding'

sec3() { # <file> -> §3 body, heading line excluded
  awk '/^### 3\. Smoke Tests/{on=1; next} on && /^### /{exit} on{print}' "$1"
}
flat() { # stdin -> one line, runs of whitespace collapsed, bold markers dropped
  tr '\n' ' ' | sed -e 's/\*\*//g' -e 's/[[:space:]][[:space:]]*/ /g'
}
sec4() { # <file> -> §4 body, heading line excluded
  awk '/^### 4\. Visual Verification/{on=1; next} on && /^### /{exit} on{print}' "$1"
}
deploy_block() { # <file> -> the checkpoint's `### Deployment` block
  awk '/^### Deployment$/{on=1; next} on && /^### /{exit} on{print}' "$1"
}
# §5 IS FENCE-AWARE. Its checkpoint template is a ``` fence holding `### ` lines of its own, so
# sec3()'s `/^### /{exit}` would stop at the template's first `### What Was Built`. Only a `### `
# OUTSIDE a fence ends §5. Every body line is tagged `F<TAB>` (inside the template fence) or
# `P<TAB>` (§5 prose), so an arm can say which of the two must carry its text.
sec5() { # <file> -> §5 body, heading line excluded, each line tagged F or P
  awk '/^### 5\. Production Validation Checkpoint/{on=1; next}
       on && /^```/{f=!f; print "F\t" $0; next}
       on && !f && /^### /{exit}
       on{print (f ? "F\t" : "P\t") $0}' "$1"
}
# The template's Locked-Requirement Coverage block: its heading up to the next fenced `### `.
# Keyed on the BLOCK BODY, because the template's Red-gate line already carries the three
# disposition tokens and the What Was Built line carries `delivered`.
locked_block() { # stdin: sec5 output -> the block body, tags stripped
  awk -F'\t' '$1=="F" && $2=="### Locked-Requirement Coverage"{on=1; next}
              on && $1=="F" && ($2 ~ /^### / || $2 ~ /^```/){exit}
              on{print $2}'
}
LOCKED_HEAD='### Locked-Requirement Coverage'
LOCKED_TOKENS='LOCKED_REQUIREMENTS delivered deferred descoped HARD_BLOCK approved-deferral do-now descope'
# Phrases the block body must carry beyond its single-word tokens: the deferred-then-delivered
# clause (same-sprint delivery does not cleanse a slipped lock), the Rule 14 phased status, and
# the value reported when the sprint ships no locked-requirements.md.
LOCKED_PHRASES='each bullet deferred and then delivered|phased — sprint k of N, s<N>/stories/<story>.md|none recorded'
# THE GATING SENTENCE: kept OUT of the template, so only §5 prose can satisfy it. "that needs one":
# delivered and phased bullets legitimately carry no disposition.
LOCKED_GATE='The checkpoint is not presented while any locked requirement that needs one lacks a recorded disposition.'
LOCKED_REPLY='An operator reply to the checkpoint does not stand in for a recorded disposition.'
# THE CHANNEL: the pause and the stop that happen BEFORE the checkpoint, so the disposition is not
# sought at the checkpoint being withheld.
LOCKED_CHANNEL='marks the pause per Rule 3 (`touch _bmad-output/pipeline-paused.flag`) and STOPS'
# `phased` is not an escape hatch: uncited or final-sprint counts as deferred, and a slip defers.
LOCKED_UNCITED='A `phased` line with no story citation, and any `phased` line at the final sprint, counts as deferred and owes its `HARD_BLOCK`.'
LOCKED_SLIP='A bullet that slips its planned sprint becomes deferred the moment it slips.'
LOCKED_STORY='that story carries the bullet verbatim in its own LOCKED_REQUIREMENTS block and is not `done`.'
# §6 and §7 CITE §5's rule rather than restating it at a narrower width.
LOCKED_WAIT='A generic validation reply is not a disposition: each locked requirement that needs one under §5'"'"'s locked-requirement coverage rule keeps its own recorded `HARD_BLOCK` disposition.'
LOCKED_ROUTE='Proceed to retro, once every locked requirement that needs a disposition under §5'"'"'s locked-requirement coverage rule carries its recorded `HARD_BLOCK` disposition'
sec6() { awk '/^### 6\. Wait for Human/{on=1; next} on && /^### /{exit} on{print}' "$1"; }
sec7() { awk '/^### 7\. Post-Validation Routing/{on=1; next} on && /^### /{exit} on{print}' "$1"; }

# check <file> -> prints one line per failing arm; prints nothing when every arm holds.
# Presence-shaped throughout: every arm demands a string APPEAR, so an empty §3 fails
# every arm rather than passing any.
check() {
  local f="$1" body fl blk fld n
  body="$(sec3 "$f")"
  if [ -z "$body" ]; then echo "SECTION: §3 could not be isolated"; return; fi
  for fld in $FIELDS; do
    n="$(grep -cE "^- \`$fld\` " <<<"$body")" || n=0
    [ "$n" = "1" ] || echo "FIELD $fld: $n defining bullet(s) in §3, expected 1"
  done
  fl="$(flat <<<"$body")"
  case "$fl" in *"$DEF"*) : ;; *) echo "DEFINITION: the no-action-by-the-lead transient definition is absent from §3" ;; esac
  case "$fl" in *"$INRUN"*) : ;; *) echo "INRUN: the value '$INRUN' is absent from §3" ;; esac
  case "$fl" in *'Every other failure is persistent'*) : ;; *) echo "PERSISTENT: §3 does not route every non-transient failure to persistent" ;; esac
  case "$fl" in *'Every test in `persistent_failures` makes the smoke run red and enters the loop below'*) : ;; *) echo "LOOP: §3 does not send persistent failures into the fix loop" ;; esac
  case "$fl" in *"$ONEVAR"*) : ;; *) echo "ONEVAR: §3 does not require one live mutation per smoke run" ;; esac
  case "$fl" in *"$OPFIRED"*) : ;; *) echo "OPFIRED: §3 does not count an operator-fired §2a operation as a live mutation" ;; esac
  # DISPATCH: the fix loop's code-issue item must itself OPEN with the `dev` dispatch. Line-anchored
  # on the item, because §7 already carries `dispatch `dev`` and a comment or a later sentence
  # inside §3 would satisfy a substring match while the item still routes namelessly.
  grep -qE "$DISPATCH" <<<"$body" || echo "DISPATCH: §3's code-issue loop item does not open with a mandatory dev dispatch"
  case "$fl" in *"$LEADSCOPE"*) : ;; *) echo "DISPATCH: §3 does not name a lead's inline product-code edit in the fix loop as a Rule 28 finding" ;; esac
  # VISUAL: §4 must tell the writer to record the tokens Check 5 of validate-mandatory-rules.sh
  # reads in the gate-log section. Keyed on §4, so a mention elsewhere does not satisfy it.
  fl="$(sec4 "$f" | flat)"
  case "$fl" in *'write `USER-CONFIRMED` for a visual check the operator confirmed, and `playwright` with the trace path'*) : ;; *) echo "VISUAL: §4 does not name the USER-CONFIRMED and playwright tokens Check 5 reads" ;; esac
  blk="$(deploy_block "$f")"
  for n in 'First-run failures:' 'Transient, cleared on retry:' 'Persistent:'; do
    grep -qF -- "- Smoke tests:" <<<"$blk" || { echo "CHECKPOINT: no Smoke tests line in the Deployment block"; break; }
    grep -qF -- "$n" <<<"$blk" || echo "CHECKPOINT: '$n' absent from the Deployment block"
  done
  # §5 LOCKED-REQUIREMENT COVERAGE. Each arm owns one prefix so a mutant fires one arm only:
  # SECTION5 (§5 unisolatable), LOCKED (block heading in the fence, then its tokens -- the token
  # arm stands down when the heading is absent, which the heading arm already reports), and
  # LOCKED-GATE (the no-presentation sentence in §5 PROSE, never the template).
  local s5 lb tok
  s5="$(sec5 "$f")"
  if [ -z "$s5" ]; then echo "SECTION5: §5 could not be isolated"; return; fi
  if ! grep -qxF -- "F"$'\t'"$LOCKED_HEAD" <<<"$s5"; then
    echo "LOCKED: no '$LOCKED_HEAD' block inside §5's fenced checkpoint template"
  else
    lb="$(locked_block <<<"$s5")"
    for tok in $LOCKED_TOKENS; do
      # -w: `descope` is a substring of `descoped`, so a bare -F grep lets the status word stand
      # in for the disposition token.
      grep -qwF -- "$tok" <<<"$lb" || echo "LOCKED: '$tok' absent from the Locked-Requirement Coverage block body"
    done
    fl="$(flat <<<"$lb")"
    local IFS='|' ph
    for ph in $LOCKED_PHRASES; do
      case "$fl" in *"$ph"*) : ;; *) echo "LOCKED: '$ph' absent from the Locked-Requirement Coverage block body" ;; esac
    done
    unset IFS
  fi
  fl="$(grep "^P"$'\t' <<<"$s5" | cut -f2- | flat)"
  case "$fl" in *"$LOCKED_GATE"*) : ;; *) echo "LOCKED-GATE: §5 prose does not withhold the checkpoint while a locked requirement lacks a recorded disposition" ;; esac
  case "$fl" in *"$LOCKED_REPLY"*) : ;; *) echo "LOCKED-GATE: §5 prose does not say an operator reply to the checkpoint is no recorded disposition" ;; esac
  case "$fl" in *"$LOCKED_CHANNEL"*) : ;; *) echo "LOCKED-CHANNEL: §5 prose does not pause and stop for the disposition before the checkpoint" ;; esac
  case "$fl" in *"$LOCKED_UNCITED"*) : ;; *) echo "LOCKED-PHASED: §5 prose does not count an uncited or final-sprint phased line as deferred" ;; esac
  case "$fl" in *"$LOCKED_SLIP"*) : ;; *) echo "LOCKED-SLIP: §5 prose does not defer a bullet that slips its planned sprint" ;; esac
  case "$fl" in *"$LOCKED_STORY"*) : ;; *) echo "LOCKED-STORY: §5 prose does not require the cited story to carry the bullet and be not done" ;; esac
  case "$(sec6 "$f" | flat)" in *"$LOCKED_WAIT"*) : ;; *) echo "LOCKED-WAIT: §6 does not cite §5's rule that a generic validation reply is no disposition" ;; esac
  case "$(sec7 "$f" | flat)" in *"$LOCKED_ROUTE"*) : ;; *) echo "LOCKED-ROUTE: §7 does not hold the route to retro on §5's recorded dispositions" ;; esac
}

# --- the subject -------------------------------------------------------------
out="$(check "$STEP")"
if [ -z "$out" ]; then
  ok "§3 defines all four fields, the transient definition, the in-run value, the loop routing, the dev dispatch in the fix loop and the one-live-mutation-per-run rule including operator-fired §2a operations; §4 names the Check 5 tokens; the checkpoint reports the split; §5's template carries the Locked-Requirement Coverage block with its status and disposition tokens and §5 prose withholds the checkpoint without a recorded disposition"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi

# --- cwd invariance: the resolver keys on \$DIR, never on the process cwd ------
[ "${1:-}" = "--probe-only" ] && exit "$rc"
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subject from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subject"
fi

# --- mutants -----------------------------------------------------------------
# Each is a COPY of the resolved subject; `cmp -s` refuses a mutation that matched
# nothing, and each must produce ITS OWN finding and no other.
CTL="$WORK/control.md"; cp "$STEP" "$CTL"
if [ -z "$(check "$CTL")" ] && [ -n "$(sec3 "$CTL")" ]; then
  ok "CONTROL: an unmutated copy passes and §3 is non-empty, so a mutant's finding below is the mutation"
else
  bad "CONTROL: an unmutated copy fails -- every mutant verdict below is uninterpretable"
fi
# POSITIVE CONJUNCT for §5: the isolation must reach PAST the template fence (a `### ` inside it
# would otherwise end §5) and the block body must be non-empty.
if [ -n "$(sec5 "$CTL" | locked_block)" ] && grep -qF -- "$LOCKED_GATE" <<<"$(sec5 "$CTL" | grep "^P"$'\t' | cut -f2- | flat)"; then
  ok "CONTROL5: §5 isolates past its template fence, the coverage block body is non-empty and the gating sentence sits in §5 prose"
else
  bad "CONTROL5: §5 isolation stopped inside the template or the coverage block is empty -- the §5 mutant verdicts are uninterpretable"
fi

mutant() { # <name> <awk-program> <expected-finding-prefix> <label>
  local m="$WORK/$1.md" res others
  awk "$2" "$STEP" > "$m"
  if cmp -s "$STEP" "$m"; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  res="$(check "$m")"
  if ! grep -qF -- "$3" <<<"$res"; then
    bad "MUTATION '$1' SURVIVED -- $4"
    return
  fi
  others="$(grep -vF -- "$3" <<<"$res")"
  if [ -n "$others" ]; then
    bad "MUTATION '$1' fired other arms too ($others) -- the arms are entangled"
  else
    ok "MUTATION '$1' killed by its own arm only: $4"
  fi
}

for fld in $FIELDS; do
  mutant "del-$fld" \
    "/^### 3\\. Smoke Tests/{s=1} s && /^### 3b/{s=0} s && /^- \`$fld\` /{next} {print}" \
    "FIELD $fld:" "deleting the $fld bullet from §3 is caught"
  # MOVE: the bullet leaves §3 and reappears verbatim under §3b. A whole-file grep
  # still finds it; the section-keyed arm must not.
  mutant "move-$fld" \
    "/^### 3\\. Smoke Tests/{s=1} s && /^### 3b/{s=0; print; print held; next} s && /^- \`$fld\` /{held=\$0; next} {print}" \
    "FIELD $fld:" "moving the $fld bullet out of §3 (into §3b) is caught"
done

mutant "any-retry" \
  '/^\*\*A failure is transient ONLY when a retry cleared it with NO ACTION BY$/{print "**A failure is transient when any retry cleared it, whatever"; next} {print}' \
  "DEFINITION:" "redefining transient as any retry is caught"

mutant "no-inrun" \
  '{ gsub(/in-run retry, same output/, "in-run retry"); print }' \
  "INRUN:" "dropping the in-run retry value is caught"

mutant "no-persistent-routing" \
  '{ gsub(/Every other failure is persistent,/, "Other failures are judged case by case,"); print }' \
  "PERSISTENT:" "dropping the every-other-failure-is-persistent rule is caught"

mutant "no-loop-entry" \
  '{ sub(/^`persistent_failures` makes the smoke run red and enters the loop below;$/, "`persistent_failures` is noted in the gate log;"); print }' \
  "LOOP:" "cutting persistent failures loose from the fix loop is caught"

mutant "checkpoint-persistent" \
  '/^  - Persistent: \[persistent_failures/{next} {print}' \
  "CHECKPOINT:" "dropping the Persistent line from the checkpoint Deployment block is caught"

mutant "no-onevar" \
  '{ gsub(/One live mutation per smoke run\./, "Re-run the smoke when convenient."); print }' \
  "ONEVAR:" "dropping the one-live-mutation-per-smoke-run rule is caught"

# MOVE: the rule sentence leaves §3 for §3b verbatim. A whole-file grep still finds it.
mutant "move-onevar" \
  '/^### 3\. Smoke Tests/{s=1} s && /^### 3b/{s=0; print; print "**One live mutation per smoke run.**"; next} s{ gsub(/\*\*One live mutation per smoke run\.\*\*/, "") } {print}' \
  "ONEVAR:" "moving the one-live-mutation rule out of §3 (into §3b) is caught"

mutant "no-opfired" \
  '{ gsub(/fired by the operator is a live mutation/, "fired by the operator is exempt"); print }' \
  "OPFIRED:" "exempting an operator-fired §2a operation from the rule is caught"

mutant "no-visual-tokens" \
  '/^### 4\. Visual Verification/{s=1} s && /^### 4b/{s=0} s && /USER-CONFIRMED/{ gsub(/`USER-CONFIRMED`/, "the operator confirmation") } {print}' \
  "VISUAL:" "dropping the Check 5 token instruction from §4 is caught"

# MOVE: the whole §4 token bullet (it runs to the end of §4) relocated under §4b, verbatim.
mutant "move-visual" \
  '/^### 4\. Visual Verification/{s=1} s && /^### 4b/{s=0; print; printf "%s", held; next} s && /^- \*\*Name the evidence kind/{h=1} s && h{held=held $0 "\n"; next} {print}' \
  "VISUAL:" "moving the Check 5 token instruction out of §4 (into §4b) is caught"

# REVERT: item 3 restored to the nameless route the dispatch replaced.
mutant "revert-dispatch" \
  '/^3\. If code issue: dispatch `dev`/{print "3. If code issue: route back to the dev teammate to fix, re-deploy,"; print "   and re-run smoke tests."; skip=1; next} skip && /^4\. /{skip=0} skip{next} {print}' \
  "DISPATCH:" "reverting item 3 to an undelegated route is caught"

# WEAK: the nameless item kept, the dispatch phrase parked in a comment inside §3. A §3-scoped
# substring match is satisfied; the line-anchored item match must not be.
mutant "comment-dispatch" \
  '/^3\. If code issue: dispatch `dev` to fix/{print "<!-- dispatch `dev` to fix -->"; print "3. If code issue: route back to the dev teammate to fix the code and its tests; the"; next} {print}' \
  "DISPATCH:" "a dispatch phrase parked beside an undelegated item 3 is caught"

mutant "no-leadscope" \
  '{ gsub(/a lead that edits product code here is applying a$/, "a lead may edit product code here when applying a"); print }' \
  "DISPATCH:" "dropping the inline-edit-is-a-finding sentence from §3 is caught"

# --- §5 Locked-Requirement Coverage --------------------------------------------
# DELETE: the block goes, the Red-gate line (which carries the same disposition tokens) stays.
# A token grep over §5's whole fence would still pass; the heading arm must not.
mutant "del-locked-block" \
  '/^### Locked-Requirement Coverage$/{s=1; next} s && /^### Next Steps$/{s=0} s{next} {print}' \
  "LOCKED:" "deleting the Locked-Requirement Coverage block, Red-gate line kept, is caught"

# MOVE: the block leaves §5's template verbatim and reappears at the END of §6 (just before §7's
# heading, so §6's own sentence stays inside §6). A whole-file grep still finds the heading; the
# fence-aware §5 isolation must not.
mutant "move-locked-block" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s{held=held $0 "\n"; next} /^### 7\. Post-Validation Routing$/{printf "%s", held; print; next} {print}' \
  "LOCKED:" "moving the Locked-Requirement Coverage block out of §5 (into §6) is caught"

# TOKENS: the block keeps its heading but loses its disposition tokens. The Red-gate line in the
# same fence still carries them, so only an arm keyed on the BLOCK BODY sees the loss.
mutant "locked-no-tokens" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s{ gsub(/\(approved-deferral \/ do-now \/ descope\)/, "(as recorded)") } {print}' \
  "LOCKED:" "stripping the disposition tokens from the block body is caught though the Red-gate line keeps them"

# DESCOPE: only the disposition token `descope` dropped; the status word `descoped` stays in the
# block, so this dies only if the token arm matches whole words.
mutant "locked-no-descope-token" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s{ gsub(/ \/ do-now \/ descope\)/, " / do-now)") } {print}' \
  "LOCKED:" "dropping the descope disposition token while descoped stays is caught"

# GATE: the no-presentation sentence deleted from §5 prose.
mutant "del-locked-gate" \
  '/^\*\*The checkpoint is not presented while any locked requirement that$/{getline; next} {print}' \
  "LOCKED-GATE:" "deleting the checkpoint-withheld-without-disposition sentence from §5 is caught"

# REPLY: the sentence saying a checkpoint reply is no recorded disposition deleted from §5 prose.
mutant "del-locked-reply" \
  '/^An operator reply to the checkpoint does not stand in for a recorded$/{getline; next} {print}' \
  "LOCKED-GATE:" "deleting the checkpoint-reply-is-no-disposition sentence from §5 is caught"

# CHANNEL: the five-line channel sentence (pause flag and STOPS) deleted from §5 prose.
mutant "del-locked-channel" \
  '/^The channel is the one a red gate already uses: the lead files the Tier 1$/{skip=1} skip && /`Operator authorization:` citation\.$/{skip=0; next} skip{next} {print}' \
  "LOCKED-CHANNEL:" "deleting the pause-and-stop channel sentence from §5 is caught"

# UNCITED: the sentence that makes an uncited or final-sprint phased line a deferral deleted.
mutant "del-locked-uncited" \
  '/^A `phased` line with no story citation, and any `phased` line at the$/{getline; next} {print}' \
  "LOCKED-PHASED:" "deleting the uncited-or-final-sprint-phased-is-deferred sentence is caught"

# SLIP: the slip clause deleted.
mutant "del-locked-slip" \
  '/^A bullet that slips its planned sprint becomes deferred the moment it$/{getline; next} {print}' \
  "LOCKED-SLIP:" "deleting the slip-is-a-deferral sentence is caught"

# STORY: the cited story loses its duty to carry the bullet and not be done.
mutant "del-locked-story" \
  '{ sub(/: that story carries the bullet verbatim in its own LOCKED_REQUIREMENTS block and is not `done`\./, "."); sub(/^later-phase story created at initial planning: that story carries the$/, "later-phase story created at initial planning."); if ($0 ~ /^bullet verbatim in its own LOCKED_REQUIREMENTS block and is not `done`\.$/) next; print }' \
  "LOCKED-STORY:" "deleting the cited-story-carries-the-bullet-and-is-not-done clause is caught"

# WAIT: §6's citation of §5's rule deleted.
mutant "del-locked-wait" \
  '/^A generic validation reply is not a disposition: each locked$/{skip=1} skip && /^keeps its own recorded `HARD_BLOCK` disposition\.$/{skip=0; next} skip{next} {print}' \
  "LOCKED-WAIT:" "deleting §6's generic-reply-is-no-disposition sentence is caught"

# ROUTE: §7's retro route restored to the unconditional form it replaced.
mutant "del-locked-route" \
  '/^- If \*\*single sprint or final sprint:\*\* Proceed to retro, once every$/{print "- If **single sprint or final sprint:** Proceed to retro."; skip=1; next} skip && /^  disposition — the operator.s validation reply is not one\.$/{skip=0; next} skip{next} {print}' \
  "LOCKED-ROUTE:" "dropping §7's disposition condition on the route to retro is caught"

# DEFERRED-THEN-DELIVERED: the clause leaves the block, so a slipped-then-shipped lock reports no disposition.
mutant "del-locked-deferred-delivered" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s{ sub(/, and each bullet deferred and$/, ""); sub(/^    then delivered — /, "    — ") } {print}' \
  "LOCKED:" "dropping the deferred-then-delivered clause from the block body is caught"

# PHASED: the Rule 14 status removed from the block.
mutant "del-locked-phased" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s && / \/ phased — sprint k of N,$/{sub(/ \/ phased — sprint k of N,$/, ""); print; skip=1; next} skip && /^  s<N>\/stories\/<story>\.md$/{skip=0; next} {print}' \
  "LOCKED:" "dropping the phased status from the block body is caught"

# NONE RECORDED: the value for a sprint with no locked-requirements.md removed from the block.
mutant "del-locked-none" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s && /none recorded\]$/{next} {print}' \
  "LOCKED:" "dropping the none-recorded value from the block body is caught"

# SECTION5: §5's heading renamed -> nothing to isolate. Must be a finding, never clean.
mutant "no-section5" \
  '/^### 5\. Production Validation Checkpoint$/{print "### 5. Operator checkpoint"; next} {print}' \
  "SECTION5:" "an unisolatable §5 is a finding, not an empty pass"

# SECTION: §3's heading renamed -> nothing to isolate. Must be a finding, never clean.
mutant "no-section" \
  '/^### 3\. Smoke Tests/{print "### 3. Live checks"; next} {print}' \
  "SECTION:" "an unisolatable §3 is a finding, not an empty pass"

echo
if [ "$rc" -eq 0 ]; then
  echo "deploy-validate-smoke-classification: PASS"
else
  echo "deploy-validate-smoke-classification: FAILED" >&2
fi
exit $rc
