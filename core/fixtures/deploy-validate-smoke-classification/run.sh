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
# disposition. After that block the template carries `### Decisions for You` (each item badged
# `(Recommended` and stating the consequence of each option) and then `### For Your Information`,
# both before `### Next Steps`; §5's **Decisions for the operator.** paragraph puts every item,
# whatever its source, under exactly one of the two blocks, presents no other list, gives each
# decision Rule 11(a)'s shape, keeps a no-ask item out of Decisions for You, keeps validation as the
# closing ask and does not put each item by AskUserQuestion; §6 waits for an answer to each
# Decisions item -- open HARD_BLOCK and DEFERRAL_REQUEST entries included, the whole of item 2 --
# offers an override of each DECIDED_AUTONOMOUSLY entry under For Your Information, and no longer
# carries the old "Approve or override autonomous decisions" item (an absence, so mutant
# both-wait-lists re-adds it beside the new list). §5's rule also makes every open DEFERRAL_REQUEST
# and HARD_BLOCK a decision built from its entry's fields, and every DECIDED_AUTONOMOUSLY entry one
# For Your Information line citing its id, never left out; each sentence has its own delete mutant.
# Arms DECISIONS-BLOCK (heading, order, badge, consequence), DECISIONS-FYI (stands
# down while BLOCK's order fails), DECISIONS-RULE (§5 prose only, flattened, since the paragraph
# wraps) and DECISIONS-WAIT (§6). No script reads `smoke_run_evidence`, the coverage block or the
# decisions blocks; the executing lead reads this prose, so the prose is the mechanism and this
# fixture pins it.
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
. "$(cd "$(dirname "$0")/../lib" && pwd)/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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
item2() { # <file> -> §3 item 2 (the diagnosis item) only: its first line up to, not including, item 3
  sec3 "$1" | awk '/^2\. Diagnose the failure/{on=1} on && /^3\. If code issue/{exit} on{print}'
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
LOCKED_PHRASES='each bullet deferred and then delivered|phased — <the story or stories that deliver it>|carried from an earlier checkpoint of this plan: one line per bullet it marked phased|none recorded'
# THE GATING SENTENCE: kept OUT of the template, so only §5 prose can satisfy it. "that needs one":
# delivered and phased bullets legitimately carry no disposition.
LOCKED_GATE='The checkpoint is not presented while any locked requirement that needs one lacks a recorded disposition.'
LOCKED_REPLY='An operator reply to the checkpoint does not stand in for a recorded disposition.'
# THE CHANNEL: the pause and the stop that happen BEFORE the checkpoint, so the disposition is not
# sought at the checkpoint being withheld.
# Through the citation: the LEAD records the operator's disposition with its `Operator authorization:`
# citation, the RESOLVED contract escalations.md states -- not "the operator records" it.
LOCKED_CHANNEL='marks the pause per Rule 3 (`touch _bmad-output/pipeline-paused.flag`) and STOPS, and the lead records the operator'"'"'s disposition — `approved-deferral` / `do-now` / `descope` — on that entry with its `Operator authorization:` citation.'
# `phased` is not an escape hatch. Keyed on the CHECKPOINT, not a sprint number: no disposition
# until the plan's FINAL checkpoint, an uncited line is deferred at any checkpoint, a slip defers.
# "final" is DEFINED in the sentence, by story status -- §7's "single sprint or final sprint" calls an
# in-sprint phase checkpoint final, which would defer every phased bullet at the first phase.
LOCKED_FINAL='A `phased` bullet owes no disposition until the plan'"'"'s final checkpoint — the one after which no story of the plan remains not `done` in `sprint-status.yaml` — where any bullet not delivered counts as deferred and owes its `HARD_BLOCK`.'
# A plan spanning sprint numbers: the block reads only this sprint's locked-requirements.md, so a
# bullet phased at an earlier sprint is carried forward or it never reaches the operator.
LOCKED_CARRY='At a later checkpoint of a Rule 14 plan the block also carries every bullet an earlier checkpoint of that plan marked `phased`, read from that earlier sprint'"'"'s `locked-requirements.md`.'
LOCKED_UNCITED='A `phased` line citing no story counts as deferred at any checkpoint.'
LOCKED_NOTPHASED='A `phased` line citing a story that is `done`, or one that does not carry the LR id, is not `phased` and counts as deferred.'
LOCKED_SLIP='A bullet that slips its planned phase becomes deferred the moment it slips.'
LOCKED_STORY='Each cited story carries the requirement'"'"'s LR id in its own LOCKED_REQUIREMENTS block, verbatim or in any form `steps/stories-test-strategy.md` §2a permits (`requires_context:` included), and its status in `sprint-status.yaml` is not `done`.'
LOCKED_SPLIT='A bullet split across phases cites every story that carries a part of it.'
# §6 and §7 CITE §5's rule rather than restating it at a narrower width.
LOCKED_WAIT='A generic validation reply is not a disposition: each locked requirement that needs one under §5'"'"'s locked-requirement coverage rule keeps its own recorded `HARD_BLOCK` disposition.'
LOCKED_ROUTE='Proceed to retro, once every locked requirement that needs a disposition under §5'"'"'s locked-requirement coverage rule carries its recorded `HARD_BLOCK` disposition'
sec6() { awk '/^### 6\. Wait for Human/{on=1; next} on && /^### /{exit} on{print}' "$1"; }
# §5's Decisions for You and For Your Information blocks, the any-source rule and §6's wait list.
DEC_HEAD='### Decisions for You'
FYI_HEAD='### For Your Information'
# The lead is matched on a raw P line: flat() drops the bold markers.
DEC_LEAD_RE='\*\*Decisions for the operator\.\*\*'
# Matched against §5 P prose FLATTENED: the paragraph wraps these phrases across lines.
# The last two are whole sentences: every open escalation entry IS a decision, built from its own
# fields, and every DECIDED_AUTONOMOUSLY entry is one FYI line, never left out. flat() strips the
# `**` inside `**Status:**` and `**Operator authorization:**` and leaves the backticks.
DEC_PHRASES='stays its closing ask|whatever its source|no other list of open items is presented|takes the shape `SKILL.md` Rule 11(a) gives every decision|never under `### Decisions for You`|are not each put by `AskUserQuestion`|Every open `DEFERRAL_REQUEST` and every open `HARD_BLOCK` -- one whose `Status:` is not terminal and that carries no recorded `Operator authorization:` -- is a decision, built from its entry'"'"'s `Decision/Question`, `Options` and `Impact if skipped` fields and citing its id; a locked requirement'"'"'s `HARD_BLOCK` is not, since it is resolved before the checkpoint is presented.|Every `DECIDED_AUTONOMOUSLY` entry is one line under `### For Your Information` citing its id, never left out, so the operator can override it.'
# The WHOLE of §6 item 2: its tail names the escalation entries the answer must cover.
DEC_WAIT_ANSWER='Answer each item under §5'"'"'s `### Decisions for You`, open `HARD_BLOCK` and `DEFERRAL_REQUEST` entries included'
# ABSENCE: the review-and-approve item §6's list replaced must not stand beside the new items.
DEC_WAIT_OLD='Approve or override autonomous decisions'
DEC_WAIT_OVERRIDE='Override any `DECIDED_AUTONOMOUSLY` entry listed under §5'"'"'s `### For Your Information`'
fpos() { # <heading> ; stdin: sec5 output -> line number of that F heading, 0 when absent
  awk -F'\t' -v h="$1" '$1=="F" && $2==h {print NR; found=1; exit} END{if (!found) print 0}'
}
decisions_block() { # stdin: sec5 output -> the Decisions for You block body, tags stripped
  awk -F'\t' -v h="$DEC_HEAD" '$1=="F" && $2==h{on=1; next}
              on && $1=="F" && ($2 ~ /^### / || $2 ~ /^```/){exit}
              on{print $2}'
}
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
  # STANDING-RULING: item 2 must send the diagnosis to the escalation archive and the retro records
  # for a recorded operator disposition on the failing test. Every STANDING-RULING arm reads ITEM 2
  # ONLY (item2(), flattened: the item wraps), never the rest of §3, so the ruling cannot be satisfied
  # from a later paragraph of §3. Each branch owns its own arm prefix, so a mutant fires one arm.
  fl="$(item2 "$f" | flat)"
  case "$fl" in *'docs/escalations/pending-archive.md'*) : ;; *) echo "STANDING-RULING: item 2 does not search the escalation archive for a standing ruling on the failing test" ;; esac
  case "$fl" in *'docs/retro/s*/retro.md'*) : ;; *) echo "STANDING-RULING: item 2 does not search the retro records for a standing ruling on the failing test" ;; esac
  # STANDING-RULING-ID: the id-match branch, the verbatim id the smoke output reports.
  case "$fl" in *'names the failing test id verbatim, the id the smoke output reports'*) : ;; *) echo "STANDING-RULING-ID: item 2 does not release only on a prior entry naming the failing test id verbatim" ;; esac
  # STANDING-RULING-AUTH: the prior entry must be terminal and carry its own Operator authorization line.
  case "$fl" in *'has a terminal status and an `Operator authorization:` line'*) : ;; *) echo "STANDING-RULING-AUTH: item 2 does not require a terminal prior entry carrying an Operator authorization line" ;; esac
  # STANDING-RULING-SEG / -WHOLE / -UNIQ / -SHARED / -SUBSTR: the final-segment branch and its bounds.
  case "$fl" in *'names exactly the final `::` segment of that pytest node id'*) : ;; *) echo "STANDING-RULING-SEG: item 2 does not limit the bare-name branch to exactly the final :: segment of the node id" ;; esac
  case "$fl" in *'as a whole token'*) : ;; *) echo "STANDING-RULING-WHOLE: item 2 does not require the final segment to match as a whole token" ;; esac
  case "$fl" in *"is the final segment of exactly one failing id in this run's smoke output"*) : ;; *) echo "STANDING-RULING-UNIQ: item 2 does not require the segment to be the final segment of exactly one failing id" ;; esac
  case "$fl" in *'Two failing ids that share a final segment do not match'*) : ;; *) echo "STANDING-RULING-SHARED: item 2 does not make two failing ids sharing a final segment a non-match" ;; esac
  case "$fl" in *'a prior name that is only a prefix or substring of a longer token does not match'*) : ;; *) echo "STANDING-RULING-SUBSTR: item 2 does not make a prefix or substring of a longer token a non-match" ;; esac
  # STANDING-RULING-RELEASE / -AUTHOR / -BOTHIDS: on a release the lead authors nothing terminal, cites the entry for information, quotes both ids.
  case "$fl" in *'On a release the lead authors nothing terminal and files no item-6 entry'*) : ;; *) echo "STANDING-RULING-AUTHOR: item 2 does not say the lead authors nothing terminal and files no item-6 entry on a release" ;; esac
  case "$fl" in *'it cites the prior entry under `### For Your Information` and in the gate log, by file:line, with that entry'"'"'s `Operator authorization:` line verbatim'*) : ;; *) echo "STANDING-RULING-RELEASE: item 2 does not cite the prior entry under For Your Information with its Operator authorization line verbatim" ;; esac
  case "$fl" in *'quoting both the failing id as the smoke output reports it and the id as the prior entry names it'*) : ;; *) echo "STANDING-RULING-BOTHIDS: item 2 does not quote both the reported id and the id the prior entry names" ;; esac
  # NOFILE: the old instruction to file item 6 already RESOLVED must not stand (the gate rejects a lead-authored RESOLVED entry).
  case "$fl" in *'already RESOLVED'*) echo "STANDING-RULING-NOFILE: item 2 tells the lead to file an already RESOLVED entry, which the escalation gate rejects" ;; *) : ;; esac
  # STANDING-RULING-FALLBACK and its three cells: each other disposition returns to item 6 with the prior ruling beside the Decision.
  case "$fl" in *'Any other disposition falls back to item 6 unchanged, with the prior ruling shown beside the Decision'*) : ;; *) echo "STANDING-RULING-FALLBACK: item 2 does not fall back to item 6 with the prior ruling beside the Decision on a non-matching disposition" ;; esac
  case "$fl" in *'an entry with no `Operator authorization:` line'*) : ;; *) echo "STANDING-RULING-FB-NOAUTH: item 2 does not fall back on an entry with no Operator authorization line" ;; esac
  case "$fl" in *'a disposition found only in a retro doc'*) : ;; *) echo "STANDING-RULING-FB-RETRO: item 2 does not fall back on a disposition found only in a retro doc" ;; esac
  case "$fl" in *'a different test id, the same test id failing a different assertion than the one the entry names, or an entry whose own words scope it to another sprint or condition'*) : ;; *) echo "STANDING-RULING-FB-ID: item 2 does not fall back on a different id, a different assertion or a scoped entry" ;; esac
  # STANDING-RULING-NORELEASE: nothing but such a prior entry releases the checkpoint; the verdict stays FAILED.
  case "$fl" in *'Nothing other than such a prior entry releases the checkpoint, and the smoke verdict stays FAILED either way'*) : ;; *) echo "STANDING-RULING-NORELEASE: item 2 does not state that only such a prior entry releases the checkpoint and the verdict stays FAILED" ;; esac
  # STANDING-RULING-PRIOR / -FILES: the release source is a PRIOR entry, in one of the two escalation files.
  case "$fl" in *'a prior escalation entry, from any sprint'*) : ;; *) echo "STANDING-RULING-PRIOR: item 2 does not make the release source a prior escalation entry from any sprint" ;; esac
  case "$fl" in *'in one of the two escalation files'*) : ;; *) echo "STANDING-RULING-FILES: item 2 does not limit the release source to one of the two escalation files" ;; esac
  # STANDING-RULING-TERMINAL / -FB-STATUS: terminal is the Status FIELD, not prose; a non-terminal field falls back.
  case "$fl" in *'Terminal means the entry'"'"'s `Status:` field carries one of the terminal statuses `escalations.md` lists, not a status word in prose elsewhere in the entry'*) : ;; *) echo "STANDING-RULING-TERMINAL: item 2 does not define terminal as the entry's Status field in escalations.md's vocabulary" ;; esac
  case "$fl" in *'An entry whose `Status:` field is not terminal, even if prose later in it says RESOLVED, falls back the same way'*) : ;; *) echo "STANDING-RULING-FB-STATUS: item 2 does not fall back on an entry whose Status field is not terminal despite prose saying RESOLVED" ;; esac
  # STANDING-RULING-PERID: each failing id is matched on its own; unmatched ids go to item 6.
  case "$fl" in *'Each failing id is matched on its own: a release covers only the id it matched, and every unmatched failing id goes to item 6 as written'*) : ;; *) echo "STANDING-RULING-PERID: item 2 does not match each failing id on its own and send every unmatched id to item 6" ;; esac
  # STANDING-RULING-QUAL: a qualified prior name must equal the reported id verbatim.
  case "$fl" in *'The final-segment branch applies only when the prior entry'"'"'s name carries no `::`; a qualified prior name'*'must equal the reported id verbatim, else the fallback below applies'*) : ;; *) echo "STANDING-RULING-QUAL: item 2 does not require a qualified prior name to equal the reported id verbatim" ;; esac
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
  case "$fl" in *"$LOCKED_FINAL"*) : ;; *) echo "LOCKED-FINAL: §5 prose does not defer an undelivered phased bullet at the plan's final checkpoint" ;; esac
  case "$fl" in *"$LOCKED_CARRY"*) : ;; *) echo "LOCKED-CARRY: §5 prose does not carry an earlier checkpoint's phased bullets forward" ;; esac
  case "$fl" in *"$LOCKED_UNCITED"*) : ;; *) echo "LOCKED-PHASED: §5 prose does not count a phased line citing no story as deferred" ;; esac
  case "$fl" in *"$LOCKED_NOTPHASED"*) : ;; *) echo "LOCKED-NOTPHASED: §5 prose does not count a phased line citing a done or non-carrying story as deferred" ;; esac
  case "$fl" in *"$LOCKED_SPLIT"*) : ;; *) echo "LOCKED-SPLIT: §5 prose does not make a split bullet cite every story carrying a part" ;; esac
  case "$fl" in *"$LOCKED_SLIP"*) : ;; *) echo "LOCKED-SLIP: §5 prose does not defer a bullet that slips its planned sprint" ;; esac
  case "$fl" in *"$LOCKED_STORY"*) : ;; *) echo "LOCKED-STORY: §5 prose does not require the cited story to carry the bullet and be not done" ;; esac
  case "$(sec6 "$f" | flat)" in *"$LOCKED_WAIT"*) : ;; *) echo "LOCKED-WAIT: §6 does not cite §5's rule that a generic validation reply is no disposition" ;; esac
  case "$(sec7 "$f" | flat)" in *"$LOCKED_ROUTE"*) : ;; *) echo "LOCKED-ROUTE: §7 does not hold the route to retro on §5's recorded dispositions" ;; esac
  # §5 DECISIONS FOR YOU / FOR YOUR INFORMATION. Four arms, one prefix each, so a mutant fires one:
  # DECISIONS-BLOCK owns the Decisions heading, its order (after the Locked block when that block
  # is there -- LOCKED owns its absence -- and before FYI and Next Steps) and its body's badge and
  # consequence; DECISIONS-FYI stands down while BLOCK's order fails and otherwise owns the FYI
  # heading before Next Steps; DECISIONS-RULE reads §5 PROSE only; DECISIONS-WAIT reads §6.
  local ln dn fn nn db border=0
  ln="$(fpos "$LOCKED_HEAD" <<<"$s5")"; dn="$(fpos "$DEC_HEAD" <<<"$s5")"
  fn="$(fpos "$FYI_HEAD" <<<"$s5")";    nn="$(fpos '### Next Steps' <<<"$s5")"
  if [ "$dn" -eq 0 ]; then
    echo "DECISIONS-BLOCK: no '$DEC_HEAD' heading inside §5's fenced checkpoint template"
  else
    if [ "$ln" -gt 0 ] && [ "$dn" -lt "$ln" ]; then border=1; fi
    if [ "$fn" -gt 0 ] && [ "$dn" -gt "$fn" ]; then border=1; fi
    if [ "$nn" -gt 0 ] && [ "$dn" -gt "$nn" ]; then border=1; fi
    [ "$border" -eq 0 ] || echo "DECISIONS-BLOCK: '$DEC_HEAD' is not after the Locked-Requirement Coverage block and before For Your Information and Next Steps"
    db="$(decisions_block <<<"$s5")"
    grep -qF -- '(Recommended' <<<"$db" || echo "DECISIONS-BLOCK: '(Recommended' absent from the Decisions for You block body"
    grep -qF -- 'consequence' <<<"$db" || echo "DECISIONS-BLOCK: 'consequence' absent from the Decisions for You block body"
  fi
  if [ "$dn" -gt 0 ] && [ "$border" -eq 0 ]; then
    if [ "$fn" -eq 0 ] || [ "$nn" -eq 0 ] || [ "$fn" -gt "$nn" ]; then
      echo "DECISIONS-FYI: no '$FYI_HEAD' heading before '### Next Steps' in §5's fenced checkpoint template"
    fi
  fi
  grep -qE "^P"$'\t'"$DEC_LEAD_RE" <<<"$s5" || echo "DECISIONS-RULE: no paragraph in §5 prose opens with **Decisions for the operator.**"
  fl="$(grep "^P"$'\t' <<<"$s5" | cut -f2- | flat)"
  local IFS='|' ph
  for ph in $DEC_PHRASES; do
    case "$fl" in *"$ph"*) : ;; *) echo "DECISIONS-RULE: '$ph' absent from §5 prose" ;; esac
  done
  unset IFS
  fl="$(sec6 "$f" | flat)"
  case "$fl" in *"$DEC_WAIT_ANSWER"*) : ;; *) echo "DECISIONS-WAIT: §6 does not wait for an answer to each item under §5's Decisions for You" ;; esac
  case "$fl" in *"$DEC_WAIT_OVERRIDE"*) : ;; *) echo "DECISIONS-WAIT: §6 does not offer an override of each DECIDED_AUTONOMOUSLY entry under §5's For Your Information" ;; esac
  case "$fl" in *"$DEC_WAIT_OLD"*) echo "DECISIONS-WAIT: §6 still carries the old '$DEC_WAIT_OLD' item beside the new wait list" ;; *) : ;; esac
}

# --- the subject -------------------------------------------------------------
out="$(check "$STEP")"
if [ -z "$out" ]; then
  ok "§3 defines all four fields, the transient definition, the in-run value, the loop routing, the dev dispatch in the fix loop and the one-live-mutation-per-run rule including operator-fired §2a operations; §4 names the Check 5 tokens; the checkpoint reports the split; §5's template carries the Locked-Requirement Coverage block with its status and disposition tokens and §5 prose withholds the checkpoint without a recorded disposition; §5's template carries Decisions for You (badged, with consequences) then For Your Information before Next Steps, §5 prose carries the any-source decisions rule and §6 waits on each decision and offers each override"
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
  ok "CONTROL: an unmutated copy passes and §3 is non-empty, so a mutant's finding below is the mutation"; B_CTL=1
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
# POSITIVE CONJUNCT for the Decisions arms: the block body is non-empty, the rule's lead sits on a
# §5 PROSE line, and §6 carries the answer item, so each arm below reads a baseline that is THERE.
if [ -n "$(sec5 "$CTL" | decisions_block)" ] && grep -qE "^P"$'\t'"$DEC_LEAD_RE" <<<"$(sec5 "$CTL")" \
   && grep -qF -- "$DEC_WAIT_ANSWER" <<<"$(sec6 "$CTL" | flat)"; then
  ok "CONTROL-DECISIONS: the Decisions for You body is non-empty, the Decisions for the operator lead is §5 prose and §6 carries the answer item"
else
  bad "CONTROL-DECISIONS: the Decisions for You body is empty, the rule lead is not §5 prose, or §6 lacks the answer item -- the Decisions mutant verdicts are uninterpretable"
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
    mutant_killed "${B_CTL:-0}" "$1" "MUTATION '$1' killed by its own arm only: $4"
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

# STANDING-RULING: one mutant per token or branch, each dropping only its own text from item 2.
mutant "no-ruling-archive" \
  '{ gsub(/`docs\/escalations\/pending-archive\.md` and /, ""); print }' \
  "STANDING-RULING:" "dropping the escalation archive from the standing-ruling search is caught"

mutant "no-ruling-retro" \
  '{ gsub(/ and `docs\/retro\/s\*\/retro\.md`/, ""); print }' \
  "STANDING-RULING:" "dropping the retro records from the standing-ruling search is caught"

# Each mutant below edits ONE source line of item 2, on a word that only one phrase pins, so it fires
# one arm. The item wraps, so a phrase is broken by editing the line that carries its distinctive words.

# DROP the id-match condition: the entry would no longer have to name the failing test id.
mutant "no-ruling-id-match" \
  '{ gsub(/and names the failing test id$/, "and names a failing test"); print }' \
  "STANDING-RULING-ID:" "dropping the names-the-failing-test-id-verbatim condition is caught"

# DROP the authorization requirement: a terminal entry with no Operator authorization line would release.
mutant "no-ruling-auth" \
  '{ gsub(/has a terminal status and an `Operator authorization:`$/, "has a terminal status and a note"); print }' \
  "STANDING-RULING-AUTH:" "dropping the Operator authorization requirement is caught"

# DROP the final-segment branch's anchor on the final :: segment.
mutant "no-ruling-segment" \
  '{ gsub(/^   final `::` segment of that pytest node id as a whole token, where$/, "   node id as a whole token, where"); print }' \
  "STANDING-RULING-SEG:" "dropping the exactly-the-final-:: -segment condition is caught"

# WHOLE token turned into substring matching.
mutant "no-ruling-whole-token" \
  '{ gsub(/as a whole token, where$/, "as a substring, where"); print }' \
  "STANDING-RULING-WHOLE:" "turning whole-token matching into substring matching is caught"

# DROP the uniqueness condition: a segment shared by several failing ids would release.
mutant "no-ruling-uniq" \
  '{ gsub(/that segment is the final segment of exactly one failing id in this$/, "that segment is a final segment of a failing id in this"); print }' \
  "STANDING-RULING-UNIQ:" "dropping the exactly-one-failing-id uniqueness condition is caught"

# DROP the shared-segment fallback sentence.
mutant "no-ruling-shared" \
  '{ gsub(/Two failing ids that share a final segment do not$/, "Two failing ids that share a final segment are fine"); print }' \
  "STANDING-RULING-SHARED:" "dropping the two-ids-sharing-a-final-segment non-match is caught"

# DROP the prefix-or-substring non-match.
mutant "no-ruling-substr" \
  '{ gsub(/ or substring of a longer$/, " of a longer"); print }' \
  "STANDING-RULING-SUBSTR:" "dropping the prefix-or-substring non-match is caught"

# DROP the nothing-terminal-authored sentence.
mutant "no-ruling-author" \
  '{ gsub(/the lead authors nothing terminal$/, "the lead records the terminal status"); print }' \
  "STANDING-RULING-AUTHOR:" "dropping the lead-authors-nothing-terminal sentence is caught"

# DROP the For Your Information citation with the authorization line verbatim.
mutant "no-ruling-release-cite" \
  '{ gsub(/ and in the gate log, by file:line, with$/, " and nowhere else, by file:line, with"); print }' \
  "STANDING-RULING-RELEASE:" "dropping the FYI citation with the authorization line verbatim is caught"

# DROP the quote-both-ids requirement.
mutant "no-ruling-bothids" \
  '{ gsub(/, quoting both$/, ", quoting"); print }' \
  "STANDING-RULING-BOTHIDS:" "dropping the quote-both-ids join is caught"

# RE-INTRODUCE the lead-authored RESOLVED filing the gate rejects: the phrase is ADDED to item 2.
mutant "readd-ruling-file-resolved" \
  '/^2\. Diagnose the failure/{i=1} /^3\. If code issue/{i=0} i && /stays FAILED either way\.$/{print; print "   On a match, file item 6'"'"'s `HARD_BLOCK` already RESOLVED."; next} {print}' \
  "STANDING-RULING-NOFILE:" "adding back the file-item-6-already-RESOLVED instruction is caught"

# DROP the fallback: a non-matching disposition would no longer return to item 6.
mutant "no-ruling-fallback" \
  '{ gsub(/Any other disposition falls back to item 6/, "Any other disposition is cited"); print }' \
  "STANDING-RULING-FALLBACK:" "dropping the fall-back-to-item-6 branch is caught"

# DROP each fallback cell on its own.
mutant "no-ruling-fb-noauth" \
  '{ gsub(/Decision: an entry with no$/, "Decision: a case with no"); print }' \
  "STANDING-RULING-FB-NOAUTH:" "dropping the no-authorization-line fallback cell is caught"

mutant "no-ruling-fb-retro" \
  '{ gsub(/found only in a retro$/, "found in a retro"); print }' \
  "STANDING-RULING-FB-RETRO:" "dropping the retro-doc-only fallback cell is caught"

mutant "no-ruling-fb-id" \
  '{ gsub(/the same test id failing a different$/, "the same test id passing a different"); print }' \
  "STANDING-RULING-FB-ID:" "dropping the id-mismatch / different-assertion / scoped-entry fallback cell is caught"

# DROP the no-release sentence.
mutant "no-ruling-norelease" \
  '{ gsub(/Nothing other than$/, "Anything other than"); print }' \
  "STANDING-RULING-NORELEASE:" "dropping the nothing-else-releases sentence is caught"

# PIN the release source: "prior" and "in one of the two escalation files".
mutant "no-ruling-prior" \
  '{ gsub(/is a prior$/, "is an"); print }' \
  "STANDING-RULING-PRIOR:" "dropping the prior-escalation-entry release source is caught"

mutant "no-ruling-files" \
  '{ gsub(/ in one of the two escalation$/, " in an escalation"); print }' \
  "STANDING-RULING-FILES:" "dropping in-one-of-the-two-escalation-files is caught"

# PIN terminal = the Status FIELD, and the non-terminal-field fallback cell.
mutant "no-ruling-terminal-field" \
  '{ gsub(/^   entry'"'"'s `\*\*Status:\*\*` field carries one of the terminal statuses$/, "   entry'"'"'s text carries one of the terminal statuses"); print }' \
  "STANDING-RULING-TERMINAL:" "defining terminal by any status word rather than the Status field is caught"

mutant "no-ruling-fb-status" \
  '{ gsub(/`\*\*Status:\*\*` field is not terminal, even if prose later in it says$/, "`**Status:**` field is terminal, even if prose later in it says"); print }' \
  "STANDING-RULING-FB-STATUS:" "dropping the non-terminal-Status-field fallback cell is caught"

# PIN per-id matching and the qualified-name clause.
mutant "no-ruling-perid" \
  '{ gsub(/covers only the id it matched/, "covers the whole run"); print }' \
  "STANDING-RULING-PERID:" "letting a release cover unmatched failing ids is caught"

mutant "no-ruling-qual" \
  '{ gsub(/ name carries no `::`; a qualified prior name$/, " name is anything; a prior name"); print }' \
  "STANDING-RULING-QUAL:" "dropping the qualified-prior-name verbatim clause is caught"

# MOVE: the whole ruling leaves item 2 and reappears verbatim at the end of §3, after the Minimum
# mechanism paragraph and before §3b's heading, still INSIDE §3. A §3-wide read still finds it; the
# item-2 span reader must not. Every STANDING-RULING arm fires, so the expected prefix is their stem.
mutant "move-ruling" \
  '/^### 3\. Smoke Tests/{s=1} s && /^### 3b/{s=0; printf "%s\n", held; print; next} s && /^   Before routing, search `docs\/escalations\/pending\.md`,$/{h=1} s && h{held=held $0 "\n"; if ($0 ~ /stays FAILED either way\.$/) h=0; next} {print}' \
  "STANDING-RULING" "moving the standing-ruling instruction out of item 2 (to the end of §3, past the Minimum mechanism paragraph) is caught"

# --- §5 Locked-Requirement Coverage --------------------------------------------
# DELETE: the block goes, the Red-gate line (which carries the same disposition tokens) stays.
# A token grep over §5's whole fence would still pass; the heading arm must not.
mutant "del-locked-block" \
  '/^### Locked-Requirement Coverage$/{s=1; next} s && /^### Decisions for You$/{s=0} s{next} {print}' \
  "LOCKED:" "deleting the Locked-Requirement Coverage block, Red-gate line kept, is caught"

# MOVE: the block leaves §5's template verbatim and reappears at the END of §6 (just before §7's
# heading, so §6's own sentence stays inside §6). A whole-file grep still finds the heading; the
# fence-aware §5 isolation must not.
mutant "move-locked-block" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Decisions for You$/{s=0} s{held=held $0 "\n"; next} /^### 7\. Post-Validation Routing$/{printf "%s", held; print; next} {print}' \
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

# REVERT-RECORDER: the channel reverted to "the operator records" the disposition, which collides
# with the RESOLVED contract (the lead writes it, citing the operator's message).
mutant "revert-locked-recorder" \
  '/^`HARD_BLOCK` in `docs\/escalations\/pending.md`, marks the pause per Rule 3$/{c=1} c && /^\(`touch _bmad-output\/pipeline-paused.flag`\) and STOPS, and the lead$/{print "(`touch _bmad-output/pipeline-paused.flag`) and STOPS, and the operator"; next} c && /^records the operator.s disposition — `approved-deferral` \/ `do-now` \/$/{print "records the disposition — `approved-deferral` / `do-now` /"; next} c && /^`descope` — on that entry with its `Operator authorization:` citation\.$/{print "`descope` — on that entry."; c=0; next} {print}' \
  "LOCKED-CHANNEL:" "reverting the channel to the operator recording the disposition is caught"

# FINAL: the final-checkpoint sentence deleted, so a phased bullet never owes a disposition.
mutant "del-locked-final" \
  '/^A `phased` bullet owes no disposition until the plan.s final checkpoint$/{skip=1} skip && /^and owes its `HARD_BLOCK`\.$/{skip=0; next} skip{next} {print}' \
  "LOCKED-FINAL:" "deleting the undelivered-at-the-final-checkpoint-is-deferred sentence is caught"

# FINAL-DEF: only the definition of "final" dropped, so the sprint-count reading of §7 decides it.
mutant "drop-locked-final-def" \
  '/^A `phased` bullet owes no disposition until the plan.s final checkpoint$/{print; getline; getline; sub(/^`sprint-status.yaml` — where/, "where"); print; next} {print}' \
  "LOCKED-FINAL:" "dropping the story-status definition of the final checkpoint is caught"

# CARRY: the carry-forward sentence deleted.
mutant "del-locked-carry" \
  '/^At a later checkpoint of a Rule 14 plan the block also carries every$/{skip=1} skip && /^earlier sprint.s `locked-requirements.md`\.$/{skip=0; next} skip{next} {print}' \
  "LOCKED-CARRY:" "deleting the carry-phased-bullets-forward sentence is caught"

# NOT-PHASED: the done-or-non-carrying-story sentence deleted.
mutant "del-locked-notphased" \
  '/^A `phased` line citing a story that is `done`, or one that does not carry$/{getline; next} {print}' \
  "LOCKED-NOTPHASED:" "deleting the done-or-non-carrying-story-is-deferred sentence is caught"

# CARRY TEMPLATE: the carried-forward line removed from the block.
mutant "del-locked-carry-line" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s && /^- \[carried from an earlier checkpoint of this plan:/{next} {print}' \
  "LOCKED:" "dropping the carried-from-an-earlier-checkpoint line from the block body is caught"

# UNCITED: the sentence that makes a phased line citing no story a deferral deleted.
mutant "del-locked-uncited" \
  '/^A `phased` line citing no story counts as deferred at any checkpoint\.$/{next} {print}' \
  "LOCKED-PHASED:" "deleting the uncited-phased-is-deferred sentence is caught"

# SPLIT: the split-bullet sentence deleted.
mutant "del-locked-split" \
  '/^A bullet split across phases cites every story that carries a part of it\.$/{next} {print}' \
  "LOCKED-SPLIT:" "deleting the split-bullet-cites-every-story sentence is caught"

# SLIP: the slip clause deleted.
mutant "del-locked-slip" \
  '/^A bullet that slips its planned phase becomes deferred the moment it$/{getline; next} {print}' \
  "LOCKED-SLIP:" "deleting the slip-is-a-deferral sentence is caught"

# STORY: the cited story loses its duty to carry the LR id and be not done in sprint-status.yaml.
mutant "del-locked-story" \
  '/^Each cited story carries the requirement.s LR id in its own$/{skip=1} skip && /^included\), and its status in `sprint-status.yaml` is not `done`\.$/{skip=0; next} skip{next} {print}' \
  "LOCKED-STORY:" "deleting the cited-story-carries-the-LR-id-and-is-not-done sentence is caught"

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
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s && /^  phased — <the story or stories that deliver it>$/{next} {print}' \
  "LOCKED:" "dropping the phased status from the block body is caught"

# NONE RECORDED: the value for a sprint with no locked-requirements.md removed from the block.
mutant "del-locked-none" \
  '/^### Locked-Requirement Coverage$/{s=1} s && /^### Next Steps$/{s=0} s && /none recorded\]$/{next} {print}' \
  "LOCKED:" "dropping the none-recorded value from the block body is caught"

# --- §5 Decisions for You / For Your Information, the any-source rule, §6's wait list ------
# DELETE: the template's Decisions block goes (heading up to For Your Information). The prose
# still names `### Decisions for You`, so only the fence-keyed heading arm sees the loss.
mutant "del-decisions-block" \
  '/^### Decisions for You$/{s=1; next} s && /^### For Your Information$/{s=0} s{next} {print}' \
  "DECISIONS-BLOCK:" "deleting the Decisions for You block from §5's template is caught"

# MOVE: the block leaves its place verbatim and reappears after `### Next Steps`, still inside the
# fence. Presence holds; only the order test sees it, and DECISIONS-FYI stands down.
mutant "move-decisions-after-next" \
  '/^### Decisions for You$/{s=1} s && /^### For Your Information$/{s=0} s{held=held $0 "\n"; next} /^\[If single sprint: "Sprint complete\. Retro will run next\."\]$/{print; printf "\n%s", held; next} {print}' \
  "DECISIONS-BLOCK:" "moving the Decisions for You block after Next Steps is caught"

# BADGE: `(Recommended` dropped from the block body only (the template is its one occurrence).
mutant "decisions-no-badge" \
  '/^### Decisions for You$/{s=1} s && /^### For Your Information$/{s=0} s{ gsub(/\(Recommended, unless unbadged under Rule 11\(a\)\)/, "(preferred)") } {print}' \
  "DECISIONS-BLOCK:" "dropping the (Recommended badge from the Decisions for You block is caught"

# FYI: the For Your Information heading deleted; its line folds into the Decisions block body.
mutant "del-fyi-heading" \
  '/^### For Your Information$/{next} {print}' \
  "DECISIONS-FYI:" "deleting the For Your Information heading from §5's template is caught"

# RULE: the whole **Decisions for the operator.** paragraph deleted from §5 prose.
mutant "del-decisions-rule" \
  '/^\*\*Decisions for the operator\.\*\*/{skip=1} skip && /^$/{skip=0; next} skip{next} {print}' \
  "DECISIONS-RULE:" "deleting the Decisions for the operator paragraph from §5 is caught"

# MOVE: the paragraph leaves §5 verbatim and reappears at the end of §6 (before §7's heading, so §6's
# own wait list and generic-reply sentence stay in §6). A whole-file grep still finds it.
mutant "move-decisions-rule" \
  '/^\*\*Decisions for the operator\.\*\*/{skip=1} skip{held=held $0 "\n"; if ($0 ~ /^$/) skip=0; next} /^### 7\. Post-Validation Routing$/{printf "%s", held; print; next} {print}' \
  "DECISIONS-RULE:" "moving the Decisions for the operator paragraph out of §5 (into §6) is caught"

# NARROW: "whatever its source -- an escalation entry, a carry-over, a baseline test failure, an
# open issue" narrowed to escalation entries alone, the defect the any-source clause closes.
mutant "narrow-decisions-source" \
  '/^operator, whatever its source -- an escalation entry, a carry-over, a$/{print "operator from an escalation entry"; getline; sub(/^baseline test failure, an open issue -- /, ""); print; next} {print}' \
  "DECISIONS-RULE:" "narrowing the any-source clause to escalation entries is caught"

# NEVER-UNDER: the clause keeping a no-ask item out of Decisions for You dropped.
mutant "drop-decisions-never-under" \
  '{ sub(/^out, never under `### Decisions for You`; with no decision owed that$/, "out; with no decision owed that"); print }' \
  "DECISIONS-RULE:" "dropping the never-under-Decisions-for-You clause is caught"

# WAIT: §6's list reverted to the items it replaced (review / approve-or-override / approve deferrals).
mutant "revert-decisions-wait" \
  '/^2\. Answer each item under /{print "2. Review any `DECIDED_AUTONOMOUSLY` entries"; print "3. Approve or override autonomous decisions"; print "4. Approve any `DEFERRAL_REQUEST` entries (or reject and require implementation)"; next} /^3\. Override any /{next} /^4\. Confirm validation or request fixes$/{print "5. Confirm validation or request fixes"; next} {print}' \
  "DECISIONS-WAIT:" "reverting §6's wait list to the review-and-approve items is caught"

# ESCALATION: the every-open-DEFERRAL_REQUEST-and-HARD_BLOCK-is-a-decision sentence deleted; the
# Rule 11(a) sentence before it and the DECIDED_AUTONOMOUSLY sentence after it stay whole.
mutant "del-decisions-escalation-sentence" \
  '/^decision put to the operator\. Every open `DEFERRAL_REQUEST` and every$/{print "decision put to the operator."; skip=1; next} skip && /^since it is resolved before the checkpoint is presented\. Every$/{print "Every"; skip=0; next} skip{next} {print}' \
  "DECISIONS-RULE:" "deleting the every-open-escalation-entry-is-a-decision sentence from §5 is caught"

# DECIDED_AUTONOMOUSLY: the one-FYI-line-never-left-out sentence deleted; its neighbours stay whole.
mutant "del-decisions-da-sentence" \
  '/^since it is resolved before the checkpoint is presented\. Every$/{print "since it is resolved before the checkpoint is presented."; skip=1; next} skip && /^override it\. An item that asks nothing of the operator/{sub(/^override it\. /, ""); skip=0; print; next} skip{next} {print}' \
  "DECISIONS-RULE:" "deleting the DECIDED_AUTONOMOUSLY-is-one-FYI-line sentence from §5 is caught"

# TRIM: §6 item 2 cut to its prefix, the escalation-entries tail gone.
mutant "trim-decisions-wait" \
  '/^2\. Answer each item under /{ sub(/, open `HARD_BLOCK` and `DEFERRAL_REQUEST` entries included$/, "") } {print}' \
  "DECISIONS-WAIT:" "cutting §6 item 2 to its prefix is caught"

# BOTH: the old approve-or-override item re-added beside the new list, every new item kept.
mutant "both-wait-lists" \
  '/^2\. Answer each item under /{print; print "3. Approve or override autonomous decisions"; next} {print}' \
  "DECISIONS-WAIT:" "the old approve-or-override item standing beside the new wait list is caught"

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
