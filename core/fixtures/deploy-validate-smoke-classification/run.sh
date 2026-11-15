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
# disposition. §5's prose also makes each coverage line name its bullet's kind, makes an `operation`
# bullet's `delivered` cite this deploy's record row showing the action succeed on each target (health-only,
# zero-activity, NOT_EVALUATED and test-double records excluded), and adds `partial` with its three clause
# forms, the undelivered clause owing a HARD_BLOCK (arms LOCKED-KIND .. LOCKED-PARTIAL-CARRY, one arm
# per sentence). After that block the template carries `### Decisions for You` (each item badged
# `(Recommended` and stating the consequence of each option) and then `### For Your Information`,
# both before `### Next Steps`; §5's **Decisions for the operator.** paragraph puts every item,
# whatever its source, under exactly one of the two blocks, presents no other list, gives each
# decision Rule 11(a)'s shape, keeps a no-ask item out of Decisions for You, keeps validation as the
# closing ask and does not put each item by AskUserQuestion; §6 waits for an answer to each
# Decisions item -- open HARD_BLOCK and DEFERRAL_REQUEST entries included, the whole of item 2 --
# offers an override of each DECIDED_AUTONOMOUSLY entry under For Your Information, and no longer
# carries the old "Approve or override autonomous decisions" item (an absence). §5's rule also makes every open DEFERRAL_REQUEST
# and HARD_BLOCK a decision built from its entry's fields, and every DECIDED_AUTONOMOUSLY entry one
# For Your Information line citing its id, never left out.
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
# block, which names the same concepts.
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
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

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
LOCKED_TOKENS='LOCKED_REQUIREMENTS delivered deferred descoped HARD_BLOCK approved-deferral do-now descope partial operator-owned'
# THE KIND AND THE CAPTURED ROW. An `operation` bullet was once marked `delivered` on a health-only
# smoke run and a function check whose rows named only the OTHER target, while the deployed system
# had never performed the action on the target the bullet names. Each sentence below is one arm, so a
# dropping one clause fires that arm alone. Matched against §5 P prose FLATTENED.
LOCKED_KIND='Every line names its bullet'"'"'s kind before its mark: `operation`'
LOCKED_ROW='An `operation` bullet is `delivered` only on the gate-log `file:line` of a §3, §3b, §4 or §4b record from this deploy together with the id of the row in that record that shows the bullet'"'"'s action succeeding'
LOCKED_TARGET='That row names the bullet'"'"'s target, and a bullet naming several targets cites one such row for each of them.'
# WHICH DEPLOY: any roll of this sprint, and beside each cited row the deployed sha of the service that
# WROTE it -- visibility only. Re-verification after a roll is §3's smoke re-run and §7's, not a §5 rule.
# A RENDERED FIELD: LOCKED-SHA asserts the template slot beside the row id and the prose sentence, and
# no arm anywhere treats the sha as a pass/fail condition on a row.
LOCKED_SHA='"This deploy" is any deploy made under this sprint'"'"'s deploy-validate, each later roll included, never a prior sprint'"'"'s; the line names, beside each cited row, the deployed sha of the service that wrote the row, so the operator can see a stale row, and no rule reads that sha as a verdict.'
LOCKED_SHA_SLOT='with <the writing service'"'"'s deployed sha> beside that row id'
LOCKED_INADMISSIBLE='Not admissible for an `operation` bullet: a unit, integration or test-double result; a health-only or availability-only record; a record none of whose rows names the bullet'"'"'s target; a §3b zero-expected-activity PASS; a `NOT_EVALUATED` record.'
# `partial`: a bullet only some of whose clauses shipped. Its three clause forms each own an arm, and
# the owed-HARD_BLOCK sentence owns its own, so `partial` cannot become a disposition-free mark.
LOCKED_PARTIAL='A bullet some of whose clauses are delivered and some not is `partial`, never `delivered`'
LOCKED_PARTIAL_PHASED='each other clause as `phased — <story>`, `operator-owned — <LR id>` or undelivered.'
LOCKED_PHASED_CLAUSE='A `phased —` clause is one a later phase of the same Rule 14 plan delivers: it owes nothing until the plan'"'"'s final checkpoint'
LOCKED_OPOWNED='An `operator-owned —` clause is one that the operator'"'"'s own locked text, a bullet carrying no `(lead interpretation)` label, assigns to the operator or excludes; it owes no disposition.'
LOCKED_PARTIAL_OWED='Every undelivered clause of a `partial` bullet owes the Tier 1 `HARD_BLOCK` with a recorded disposition that a deferred bullet owes, and the checkpoint is withheld for it as for a deferred bullet.'
LOCKED_EVIDENCE='An `artifact` bullet'"'"'s evidence is the trunk merge sha and the `file:line`, or a verification command'"'"'s output, at the deployed sha; a `constraint` bullet'"'"'s evidence is `honoured —` and a read showing the forbidden event absent, beside its control; a `decision` bullet'"'"'s evidence is the captured operator answer'"'"'s `file:line`.'
LOCKED_PARTIAL_CARRY='It carries every `phased —` clause of a line an earlier checkpoint of that plan marked `partial` the same way.'
# Phrases the block body must carry beyond its single-word tokens: the deferred-then-delivered
# clause (same-sprint delivery does not cleanse a slipped lock), the Rule 14 phased status, and
# the value reported when the sprint ships no locked-requirements.md.
LOCKED_PHRASES='<kind>: delivered — <evidence>|<kind> is operation / artifact / constraint / decision|each undelivered clause of a partial bullet|each bullet deferred and then delivered|phased — <the story or stories that deliver it>|carried from an earlier checkpoint of this plan: one line per bullet it marked phased|none recorded|operator-owned — <LR id>, or undelivered>'
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
  # from a later paragraph of §3. Each branch owns its own arm prefix, so a defect fires one arm.
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
  # §5 LOCKED-REQUIREMENT COVERAGE. Each arm owns one prefix so a defect fires one arm only:
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
  case "$fl" in *"$LOCKED_KIND"*) : ;; *) echo "LOCKED-KIND: §5 prose does not make every coverage line name its bullet's kind" ;; esac
  case "$fl" in *"$LOCKED_ROW"*) : ;; *) echo "LOCKED-ROW: §5 prose does not make an operation bullet's delivered cite this deploy's record and the row showing the action succeed" ;; esac
  case "$fl" in *"$LOCKED_TARGET"*) : ;; *) echo "LOCKED-TARGET: §5 prose does not make the cited row name the bullet's target, one row per target" ;; esac
  case "$fl" in *"$LOCKED_SHA"*) : ;; *) echo "LOCKED-SHA: §5 prose does not define this deploy as any roll of this sprint with the writing service's deployed sha named beside each cited row" ;; esac
  # The slot half stands down when the block heading is absent, which the LOCKED heading arm owns.
  if grep -qxF -- "F"$'\t'"$LOCKED_HEAD" <<<"$s5"; then
    case "$(locked_block <<<"$s5" | flat)" in *"$LOCKED_SHA_SLOT"*) : ;; *) echo "LOCKED-SHA: the Locked-Requirement Coverage block body carries no writing-service sha slot beside the row id" ;; esac
  fi
  case "$fl" in *"$LOCKED_INADMISSIBLE"*) : ;; *) echo "LOCKED-INADMISSIBLE: §5 prose does not exclude test-double, health-only, wrong-target, zero-activity and NOT_EVALUATED records" ;; esac
  case "$fl" in *"$LOCKED_EVIDENCE"*) : ;; *) echo "LOCKED-EVIDENCE: §5 prose does not name the artifact, constraint and decision kinds' evidence" ;; esac
  case "$fl" in *"$LOCKED_PARTIAL"*) : ;; *) echo "LOCKED-PARTIAL: §5 prose does not mark a part-delivered bullet partial, never delivered" ;; esac
  case "$fl" in *"$LOCKED_PARTIAL_PHASED"*) : ;; *) echo "LOCKED-PARTIAL-FORMS: §5 prose does not name the phased, operator-owned and undelivered clause forms of a partial line" ;; esac
  case "$fl" in *"$LOCKED_PHASED_CLAUSE"*) : ;; *) echo "LOCKED-PHASED-CLAUSE: §5 prose does not hold a partial line's phased clause to the plan's final checkpoint" ;; esac
  case "$fl" in *"$LOCKED_OPOWNED"*) : ;; *) echo "LOCKED-OPOWNED: §5 prose does not limit operator-owned to the operator's own unlabelled locked text" ;; esac
  case "$fl" in *"$LOCKED_PARTIAL_OWED"*) : ;; *) echo "LOCKED-PARTIAL-OWED: §5 prose does not make a partial bullet's undelivered clause owe its HARD_BLOCK" ;; esac
  case "$fl" in *"$LOCKED_PARTIAL_CARRY"*) : ;; *) echo "LOCKED-PARTIAL-CARRY: §5 prose does not carry a partial line's phased clauses forward" ;; esac
  case "$(sec6 "$f" | flat)" in *"$LOCKED_WAIT"*) : ;; *) echo "LOCKED-WAIT: §6 does not cite §5's rule that a generic validation reply is no disposition" ;; esac
  case "$(sec7 "$f" | flat)" in *"$LOCKED_ROUTE"*) : ;; *) echo "LOCKED-ROUTE: §7 does not hold the route to retro on §5's recorded dispositions" ;; esac
  # §5 DECISIONS FOR YOU / FOR YOUR INFORMATION. Four arms, one prefix each, so a defect fires one:
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
[ "${1:-}" = "--probe-only" ] && { [ "$fails" -eq 0 ] && exit 0; exit 1; }
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subject from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subject"
fi

echo
report_end deploy-validate-smoke-classification
