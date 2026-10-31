#!/usr/bin/env bash
# Pin the story evidence scaffold, the Strategy Test IDs table, and Check 21's reading of it.
#
# SUBJECT. Five shipped files, one contract:
#   - stories-test-strategy.md, Story-Authoring Pre-Flight Checklist item (c): every story
#     file carries four evidence headings, one of them the `## Strategy Test IDs` table with
#     a closed `Kind` vocabulary; Step 5 item 3 writes one row per lettered strategy case.
#   - gate-validation.md Check 21: the citation set IS that table; a case letter with no row
#     fails; a strategy with no id table is a SKIP that says so, never a PASS.
#   - dev.md `## QA Handoff Evidence`: the full-collection run WITH its counts before the
#     handoff message, the dependency setup that makes that run reproducible from a fresh
#     detached worktree recorded beside it, the four sections filled, every table row resolved.
#   - qa.md `## Handoff Evidence Precondition`: QA rejects before validating when that
#     evidence, the dependency setup included, is absent.
#   - code-reviewer.md Field Verification: the baseline-fixture sweep when a diff changes a
#     handler's result shape.
#   - implementation.md's pre-gate commit-presence paragraph and sprint-review.md §4: both
#     run validate-handoff-evidence.sh (handoff mode before gate 1, --strategy before the
#     sprint-review gate's Seam B).
# Most of this is prose the executing agents read, so the prose is the mechanism and this
# fixture pins it on the section that carries it. The mechanical part —
# validate-handoff-evidence.sh, which refuses a capture with no command line, an
# uncommitted mutation-RED capture, a glob cited as a capture, an empty Strategy Test IDs
# cell and a `test` cell whose node does not resolve — is driven below against seeded git
# worlds, each offender one property away from a clean world that carries the near-misses,
# with a mutant per arm and per near-miss.
#
# WHY THE DEV AND QA ARMS SHADOW BEFORE THEY READ. The reference consumer shadows
# `team-roles/dev.md#Workflow Per Task` and `team-roles/qa.md#Validation Checklist` with
# override bodies of its own, so text placed in either section never reaches that consumer's
# dev or QA. Each arm therefore replaces those two sections with a stub first, the way the
# loader does, and only then looks. The mutants that MOVE the text into a shadowed section
# still leave it in the file, which a whole-file grep would accept; these arms must not.
#
# IN PROCESS. validate-handoff-evidence.sh, record-only-diff.sh and sprint-status.sh are loadable (each ends in a
# BASH_SOURCE guard before its one main call), and every cell asks them through he-inproc.sh's he_run: the
# validator's he_main in a subshell, its record-only-diff.sh and sprint-status.sh calls answered by THOSE FILES'
# own ro_main / ss_main in further subshells, so no bash is started per verdict. A mutant is a copy of the
# subject sourced the same way. The receipts are sourced too (rcpt_run), and each seeds its git world ONCE into
# $WORK/rw-<receipt>; a mutant call reads that world and runs only the cells it names. EQUIV is the one
# end-to-end run per distinct CLI outcome (fixture-mutants.md clauses 5-6) and holds the in-process answer
# byte-identical to `bash <subject>`; INPROC asserts no subject call fell back to a process.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when a subject file cannot
# be located. An absent subject is never green.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/world.sh"

STS="$(locate skills/ai-dlc/steps/stories-test-strategy.md)" || STS=""
GV="$(locate skills/ai-dlc/steps/gate-validation.md)" || GV=""
DEV="$(locate team-roles/dev.md)" || DEV=""
QA="$(locate team-roles/qa.md)" || QA=""
CR="$(locate team-roles/code-reviewer.md)" || CR=""
IMP="$(locate skills/ai-dlc/steps/implementation.md)" || IMP=""
SR="$(locate skills/ai-dlc/steps/sprint-review.md)" || SR=""
# HE, SCHEMA and SSH are located by world.sh, which the mutation battery shares.
for v in STS GV DEV QA CR IMP SR HE SCHEMA SSH; do
  eval "p=\${$v}"
  if [ -z "$p" ]; then
    echo "story-evidence-scaffold: FIXTURE BROKEN -- could not locate subject $v in either layout (core/ or .claude/). An absent subject is not a passing one." >&2
    exit 2
  fi
done

for p in skills/ai-dlc/steps/stories-test-strategy.md skills/ai-dlc/steps/gate-validation.md team-roles/dev.md team-roles/qa.md team-roles/code-reviewer.md skills/ai-dlc/steps/implementation.md skills/ai-dlc/steps/sprint-review.md schemas/sprint-status.json scripts/validate-handoff-evidence.sh scripts/sprint-status.sh; do
  echo "HERMETIC-CONSUMED core/$p"
done
# BL-768: the validator's run-record arms read record-only-diff.sh beside it (absent: exit 2, UNEVALUABLE),
# and the run-record mutants copy and edit it, so it is a subject the fixture cannot pass without.
if [ -f "$(dirname "$HE")/record-only-diff.sh" ]; then echo "HERMETIC-CONSUMED core/scripts/record-only-diff.sh"
else echo "story-evidence-scaffold: FIXTURE BROKEN -- record-only-diff.sh is not beside $HE" >&2; exit 2; fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/story-evidence.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# he-inproc.sh appends every subject call it could NOT answer in process here; the INPROC arm reads it.
export UT_FALLBACK_LOG="$WORK/.fallback"; : > "$UT_FALLBACK_LOG"
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
MUT_LIB="$(cd "$DIR/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

echo "story-evidence-scaffold: subjects $STS $GV $DEV $QA $CR $IMP $SR"

h3() { # <file> <heading regex> -> body of that ### section, heading excluded
  awk -v h="$2" '$0 ~ h {on=1; next} on && /^### /{exit} on{print}' "$1"
}
h2() { # <file> <exact ## heading text> -> body of that ## section, heading excluded
  awk -v h="$2" '$0 == h {on=1; next} on && /^## /{exit} on{print}' "$1"
}
shadow() { # <file> <exact ## heading text> -> the file with that section body replaced
  awk -v h="$2" '$0 == h {print; print "(shadowed by a consumer override)"; on=1; next}
                 on && /^## /{on=0} !on{print}' "$1"
}
flat() { tr '\n' ' ' | sed -e 's/\*\*//g' -e 's/[[:space:]][[:space:]]*/ /g'; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

COUNTS='collected / passed / failed / deselected / skipped / xfailed counts'
# The dependency-setup row: the dev records it, the QA precondition REJECTs without it. A part
# QA's own worktree runs "the setup the dev's QA Handoff Evidence records" (qa.md `## As a
# Shard`, implementation.md Gate-2 dispatch), so a dev list without this row leaves that reader
# with nothing to run. Each phrase is the row's own wording in its own section.
SETUP_DEV='the canonical dependency setup that makes that run reproducible from a fresh detached worktree: the exact invocation and its working directory, or `none` with the reason'
SETUP_QA='the canonical dependency setup that makes it reproducible from a fresh detached worktree, as the exact invocation and its working directory, or `none` with the reason'

REBIND='re-binds every `## Strategy Test IDs` cell naming the old node, across all story files'
EVS="$(sed -n "s/^EV_SENTINEL='\(.*\)'\$/\1/p" "$HE")"
CAPHDR='opens with `$ <the exact command>` on its first line and a line carrying `head: <full sha>`'

# check <sts> <gv> <dev> <qa> <cr> <imp> <sr> -> one line per failing arm; nothing when every
# arm holds. Presence-shaped throughout: every arm demands a string APPEAR in its own section.
check() {
  local sts="$1" gv="$2" dev="$3" qa="$4" cr="$5" imp="$6" sr="$7" b fl hd
  b="$(h3 "$sts" '^### Story-Authoring Pre-Flight Checklist$')"
  if [ -z "$b" ]; then echo "SECTION pre-flight: could not be isolated"; else
    fl="$(flat <<<"$b")"
    for hd in 'Production Integrity Tests' 'Smoke Test Updates' 'Rename Verification' 'Strategy Test IDs'; do
      grep -qF -- "- \`## $hd\`" <<<"$b" || echo "SCAFFOLD: '## $hd' is not a required heading in the Pre-Flight Checklist"
    done
    has "$fl" '`Kind` is exactly one of `test`, `predicate`, `deploy-time`' \
      || echo "SCAFFOLD: the closed Kind vocabulary is absent from the Pre-Flight Checklist"
    has "$fl" "$REBIND" \
      || echo "REBIND-STS: the Pre-Flight Rename Verification item does not re-bind every cell naming a renamed node"
  fi
  b="$(h3 "$sts" '^### 5\. Test Strategy$')"
  if [ -z "$b" ]; then echo "SECTION step 5: could not be isolated"; else
    fl="$(flat <<<"$b")"
    has "$fl" 'one row per lettered case' || echo "BIND: Step 5 does not write one table row per lettered strategy case"
  fi
  b="$(h3 "$gv" '^### 21\. ')"
  if [ -z "$b" ]; then echo "SECTION check 21: could not be isolated"; else
    fl="$(flat <<<"$b")"
    { has "$fl" 'The citation set is each story file'"'"'s `## Strategy Test IDs` table' \
      && has "$fl" "A Dev Agent Record's prose mention of a test is not a citation"; } \
      || echo "C21SET: Check 21 does not name the Strategy Test IDs table as its citation set"
    has "$fl" 'A case letter with no row' || echo "C21LETTER: Check 21 does not fail a case letter with no row"
    { has "$fl" 'SKIP, saying so:' && has "$fl" 'it is never a PASS'; } \
      || echo "C21SKIP: Check 21 lets a strategy with no id table read as other than a stated SKIP"
  fi
  shadow "$dev" '## Workflow Per Task' > "$WORK/.dev.shadowed"
  b="$(h2 "$WORK/.dev.shadowed" '## QA Handoff Evidence')"
  fl="$(flat <<<"$b")"
  { has "$fl" "$COUNTS" && has "$fl" 'before the handoff message' && has "$fl" '`## Strategy Test IDs`'; } \
    || echo "DEV: after the consumer's Workflow Per Task shadow, dev.md carries no full-collection-with-counts handoff requirement"
  has "$fl" "$SETUP_DEV" \
    || echo "DEV: setup -- after the consumer's Workflow Per Task shadow, dev.md's handoff evidence records no dependency setup beside the full-collection run"
  has "$fl" "$REBIND" \
    || echo "DEV: rebind -- dev.md's handoff evidence does not re-bind every Strategy Test IDs cell a rename touches"
  { has "$fl" "$CAPHDR" && has "$fl" 'Every mutation-RED capture you cite is committed'; } \
    || echo "DEV: capture -- dev.md's handoff evidence prescribes no capture header or no committed RED capture"
  # BL-768: the validator's LEGACY gate keys on this phrase in the INSTALLED dev.md, so a dev.md that
  # loses it switches the run-record arms off on every consumer. The phrase is read off the validator.
  { [ -n "$EVS" ] && has "$fl" "$EVS" && has "$fl" '`Full-collection run: none, <reason>` is allowed ONLY when every path'; } \
    || echo "DEV: label -- dev.md's handoff evidence does not prescribe the column-0 run-record labels the validator keys on"
  b="$(awk '/^\*\*Pre-gate commit-presence check\.\*\*/{on=1} on && /^$/{exit} on{print}' "$imp")"
  fl="$(flat <<<"$b")"
  { has "$fl" 'validate-handoff-evidence.sh -C <worktree> <story-file> <base> <frozen-sha>' \
    && has "$fl" 'validate-handoff-evidence.sh -C <worktree> --strategy <frozen-sha> <story-file>'; } \
    || echo "WIRE-IMP: implementation.md's pre-gate check does not run validate-handoff-evidence.sh in both modes"
  { has "$fl" '`status-not-review`' && has "$fl" '`status-yaml-mismatch`' && has "$fl" '`heading-demoted`' \
    && has "$fl" 'A `SKIP STATUS (<reason>)` line'; } \
    || echo "WIRE-BK: implementation.md's pre-gate paragraph does not name the status, row and heading refusals and the SKIP STATUS line"
  # BL-845: the smoke surface is defined once, in Check 11's bold paragraph, and the gate-2 go-signal
  # runs --smoke before QA is dispatched.
  b="$(h3 "$gv" '^### 11\. ')"
  fl="$(flat <<<"$b")"
  { grep -q '^\*\*Smoke surface\.\*\* ' <<<"$b" && has "$fl" 'tracked `docs/smoke-surface.txt`, one git pathspec per line' \
    && has "$fl" 'a lone `none` declaring' && has "$fl" "It is read at the story's base"; } \
    || echo "C11SURF: Check 11 does not define the smoke surface in its **Smoke surface.** paragraph"
  has "$fl" 'are enforced by `validate-handoff-evidence.sh` at every gate-1 handoff and at the gate-2 go-signal (`--smoke`)' \
    || echo "C11MECH: Check 11 does not say its two mechanical sub-clauses are enforced by validate-handoff-evidence.sh"
  b="$(awk '/^\*\*Gate-2 dispatch: the validation partitions/{on=1} on && /^$/{exit} on{print}' "$imp")"
  fl="$(flat <<<"$b")"
  { has "$fl" 'before any QA is dispatched, run `validate-handoff-evidence.sh -C <worktree> --smoke <story-file> <base> <go-signal-sha>`' \
    && has "$fl" 'Exit 1 refuses the go-signal'; } \
    || echo "WIRE-SMOKE: implementation.md's gate-2 dispatch does not run --smoke before QA is dispatched"
  b="$(h3 "$sr" '^### 4\. Gate Validation and Proceed$')"
  fl="$(flat <<<"$b")"
  has "$fl" 'validate-handoff-evidence.sh --strategy HEAD <every story file of this sprint>' \
    || echo "WIRE-SR: sprint-review §4 does not run validate-handoff-evidence.sh --strategy before the gate"
  shadow "$qa" '## Validation Checklist' > "$WORK/.qa.shadowed"
  b="$(h2 "$WORK/.qa.shadowed" '## Handoff Evidence Precondition')"
  fl="$(flat <<<"$b")"
  { has "$fl" "$COUNTS" && has "$fl" 'REJECT without validating further'; } \
    || echo "QA: after the consumer's Validation Checklist shadow, qa.md carries no handoff-evidence precondition"
  has "$fl" "$SETUP_QA" \
    || echo "QA: setup -- after the consumer's Validation Checklist shadow, qa.md does not REJECT a handoff missing the dev's dependency setup"
  b="$(h2 "$cr" '## Field Verification (API-Consuming Stories)')"
  fl="$(flat <<<"$b")"
  has "$fl" "Baseline-fixture sweep when a diff changes a handler's result shape" \
    || echo "CR: code-reviewer Field Verification has no baseline-fixture sweep"
}

# --- the subject -------------------------------------------------------------
out="$(check "$STS" "$GV" "$DEV" "$QA" "$CR" "$IMP" "$SR")"
if [ -z "$out" ]; then
  ok "scaffold, table vocabulary, Step 5 binding, Check 21 citation set / letter / SKIP, dev and qa handoff evidence past the consumer shadows, code-reviewer sweep, rename re-bind, capture header, pre-gate and sprint-review wiring"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi

[ "${1:-}" = "--probe-only" ] && exit "$rc"
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subjects from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subjects"
fi

# --- mutants -----------------------------------------------------------------
for v in STS GV DEV QA CR IMP SR; do eval "cp \"\${$v}\" \"$WORK/ctl-$v.md\""; done
cout="$(check "$WORK/ctl-STS.md" "$WORK/ctl-GV.md" "$WORK/ctl-DEV.md" "$WORK/ctl-QA.md" "$WORK/ctl-CR.md" "$WORK/ctl-IMP.md" "$WORK/ctl-SR.md")"
if [ -z "$cout" ] && [ -n "$(h2 "$WORK/ctl-DEV.md" '## QA Handoff Evidence')" ] \
   && [ -n "$(h3 "$WORK/ctl-GV.md" '^### 21\. ')" ]; then
  ok "CONTROL: unmutated copies pass and the keyed sections are non-empty, so a mutant's finding below is the mutation"; B_ctl=1
else
  bad "CONTROL: unmutated copies fail -- every mutant verdict below is uninterpretable ($cout)"
fi

mutant() { # <name> <subject var> <awk-program> <expected-finding-prefix> <label> [<text still in file>]
  local name="$1" var="$2" prog="$3" want="$4" label="$5" still="${6:-}" src m res others
  eval "src=\${$var}"
  m="$WORK/$name.md"
  awk "$prog" "$src" > "$m"
  if cmp -s "$src" "$m"; then bad "FIXTURE ERROR: mutation '$name' matched nothing"; return; fi
  if [ -n "$still" ] && ! has "$(flat < "$m")" "$still"; then
    bad "FIXTURE ERROR: mutation '$name' should leave '$still' in the file (it is a MOVE) and did not"
    return
  fi
  local a="$STS" b="$GV" c="$DEV" d="$QA" e="$CR" f="$IMP" g="$SR"
  case "$var" in STS) a="$m" ;; GV) b="$m" ;; DEV) c="$m" ;; QA) d="$m" ;; CR) e="$m" ;; IMP) f="$m" ;; SR) g="$m" ;; esac
  res="$(check "$a" "$b" "$c" "$d" "$e" "$f" "$g")"
  if ! grep -qF -- "$want" <<<"$res"; then bad "MUTATION '$name' SURVIVED -- $label"; return; fi
  others="$(grep -vF -- "$want" <<<"$res")"
  if [ -n "$others" ]; then
    bad "MUTATION '$name' fired other arms too ($others) -- the arms are entangled"
  else
    mutant_killed "${B_ctl:-0}" "$name" "MUTATION '$name' killed by its own arm only: $label"
  fi
}

mutant drop-strategy-heading STS '/^- `## Strategy Test IDs` /{next} {print}' \
  "SCAFFOLD:" "dropping the Strategy Test IDs heading from the scaffold is caught"
mutant move-strategy-heading STS \
  '/^- `## Strategy Test IDs` /{held=$0; next} /^### 2\. Epics and Stories$/{print; print held; next} {print}' \
  "SCAFFOLD:" "moving the Strategy Test IDs heading out of the Pre-Flight Checklist is caught" \
  '`## Strategy Test IDs` — the table below'
mutant open-kind STS '{ gsub(/`Kind` is exactly one of/, "`Kind` is usually one of"); print }' \
  "SCAFFOLD:" "opening the Kind vocabulary is caught"
mutant no-letter-binding STS '{ gsub(/one row per lettered case/, "rows as needed"); print }' \
  "BIND:" "Step 5 no longer writing a row per case letter is caught"
mutant dar-prose-citation GV \
  '{ gsub(/A Dev Agent Record.s prose mention of a test is not a citation\./, "A Dev Agent Record naming a test is a citation."); print }' \
  "C21SET:" "Check 21 accepting a DAR prose mention as a citation is caught"
mutant letter-unchecked GV '/^### 21\. /{s=1} s && /^### 22\. /{s=0} s{ gsub(/A case letter with no row,/, "A test id with no row,") } {print}' \
  "C21LETTER:" "Check 21 no longer failing an unrowed case letter is caught"
mutant skip-as-pass GV '/^### 21\. /{s=1} s && /^### 22\. /{s=0} s{ gsub(/it is$/, "it counts as"); gsub(/^never a PASS\.$/, "a PASS.") } {print}' \
  "C21SKIP:" "Check 21 scoring a table-less strategy as PASS is caught"
mutant dev-into-workflow DEV '/^## QA Handoff Evidence$/{next} {print}' \
  "DEV:" "dev handoff text folded into the shadowed Workflow Per Task section is caught" \
  'before the handoff message'
mutant dev-no-counts DEV '{ gsub(/deselected \//, "/"); print }' \
  "DEV:" "dropping the deselected count from the dev handoff run is caught"
mutant qa-into-checklist QA \
  '/^## Handoff Evidence Precondition$/{h=1; next} h && /^## Validation Checklist$/{h=0; print; printf "%s", buf; next} h{buf=buf $0 "\n"; next} {print}' \
  "QA:" "qa precondition moved into the shadowed Validation Checklist section is caught" \
  'REJECT without validating further'
# The dependency-setup row. Its section precedes neither shadowed section in the same way:
# dev.md's Workflow Per Task sits ABOVE QA Handoff Evidence, so that move buffers the file and
# re-emits the bullet before the heading; qa.md's Validation Checklist sits BELOW the
# precondition, so that move streams. Each MOVE leaves the row in the file (asserted), which a
# whole-file grep would accept. The drops remove one side only, so the dev list and the QA
# list each hold the row on their own.
mutant dev-setup-into-workflow DEV \
  '{a[NR]=$0} END{for(i=1;i<=NR;i++) if(a[i] ~ /^- \*\*The dependency setup that run needs/){s=i; for(e=i+1; e<=NR && a[e] !~ /^- /; e++); break}
    for(i=1;i<=NR;i++){ if(s && i>=s && i<e) continue; if(s && a[i]=="## QA Handoff Evidence"){for(j=s;j<e;j++) print a[j]; print ""} print a[i] }}' \
  "DEV: setup --" "the dev setup row moved into the shadowed Workflow Per Task section is caught" \
  "$SETUP_DEV"
mutant qa-setup-into-checklist QA \
  '/^- the dev.s dependency setup for that run/{h=1; buf=$0 "\n"; next} h && /^- /{h=0} h{buf=buf $0 "\n"; next} /^## Validation Checklist$/{print; printf "%s", buf; next} {print}' \
  "QA: setup --" "the qa setup row moved into the shadowed Validation Checklist section is caught" \
  "$SETUP_QA"
mutant dev-no-setup DEV '/^- \*\*The dependency setup that run needs/{s=1; next} s && /^- /{s=0} !s{print}' \
  "DEV: setup --" "dropping the setup row from dev.md alone is caught"
mutant qa-no-setup QA '/^- the dev.s dependency setup for that run/{s=1; next} s && /^- /{s=0} !s{print}' \
  "QA: setup --" "dropping the setup row from qa.md alone is caught"
mutant cr-no-sweep CR '/Baseline-fixture sweep when a diff changes a handler/{next} {print}' \
  "CR:" "dropping the code-reviewer baseline-fixture sweep is caught"
mutant no-check-21 GV '/^### 21\. /{print "### Test-strategy deliverable presence"; next} {print}' \
  "SECTION check 21" "an unisolatable Check 21 is a finding, not an empty pass"
mutant sts-no-rebind STS '{ gsub(/re-binds every `## Strategy Test IDs` cell naming the old node,/, "updates its own cell,"); print }' \
  "REBIND-STS:" "dropping the cross-story re-bind from Rename Verification is caught"
mutant dev-no-rebind DEV '/^## QA Handoff Evidence$/{s=1} s && /^## Communication$/{s=0} s{ gsub(/re-binds every `## Strategy Test IDs` cell naming the old node,/, "updates the cell,") } {print}' \
  "DEV: rebind --" "dropping the re-bind from dev.md's handoff evidence is caught"
mutant dev-no-label DEV '{ gsub(/a column-0 `Full-collection run:` line/, "a full-collection line"); print }' \
  "DEV: label --" "dropping the column-0 label the validator's LEGACY gate keys on is caught"
mutant dev-no-capture-header DEV '{ gsub(/opens with `\$ <the exact command>` on its first line/, "opens with the output"); print }' \
  "DEV: capture --" "dropping the capture header from dev.md's handoff evidence is caught"
mutant imp-unwired IMP '/^\*\*Pre-gate commit-presence check\.\*\*/{s=1} s && /^$/{s=0} s{ gsub(/validate-handoff-evidence\.sh -C <worktree> --strategy/, "validate-story.sh --strategy") } {print}' \
  "WIRE-IMP:" "the pre-gate check not running the strategy mode is caught"
# A MOVE: the bookkeeping kinds pushed past the paragraph's first blank line, which every reader of
# that block (this check, the shipped probes) stops at. They stay in the file.
mutant imp-bk-moved IMP '/^Test IDs cell, `status-not-review`/{print ""} {print}' \
  "WIRE-BK:" "the bookkeeping kinds moved out of the pre-gate paragraph's first block is caught" \
  '`status-yaml-mismatch`'
mutant c11-no-surface GV '{ gsub(/^\*\*Smoke surface\.\*\* /, "Smoke surface. "); print }' \
  "C11SURF:" "the smoke-surface definition losing its bold opening is caught"
mutant c11-no-mech GV '{ gsub(/are enforced by$/, "are read by"); print }' \
  "C11MECH:" "Check 11 no longer naming the mechanical enforcement is caught"
mutant imp-no-smoke IMP '{ gsub(/ --smoke <story-file>/, " <story-file>"); print }' \
  "WIRE-SMOKE:" "the gate-2 dispatch not running --smoke is caught"
mutant sr-unwired SR '{ gsub(/validate-handoff-evidence\.sh --strategy HEAD/, "a re-read of"); print }' \
  "WIRE-SR:" "sprint-review §4 not running the strategy mode is caught"

# --- validate-handoff-evidence.sh, driven ---------------------------------------
# The worlds, the case table, the verdict function and the vector live in world.sh. The MUTATION
# BATTERY over this validator has been retired; this fixture keeps the control vector, the IN PLACE arm, the range and sibling-exit arms.
WORLDS_OK=1
se_build_worlds "hks" || WORLDS_OK=0
if [ "$WORLDS_OK" -eq 1 ] && ! HECTL="$(mk_tree control)"; then
  WORLDS_OK=0; bad "FIXTURE BROKEN: could not build the control tree (scripts dir + schema), or sprint-status.sh is not beside the validator in it"
fi
if [ "$WORLDS_OK" -eq 1 ]; then
  got="$(vector "$HECTL")"
  if [ "$got" = "$WANT" ]; then
    ok "HANDOFF/STRATEGY: each offender refused by its own arm only (no-command, red-untracked, glob-cited, empty-cell, node-missing, status-not-review, status-yaml-mismatch, heading-demoted twice); the rename fails then passes after the re-bind; every near-miss quiet, the no-yaml world prints SKIP STATUS; the head WARN exits 0"
  else
    bad "HANDOFF/STRATEGY: verdict vector differs -- want [$WANT] got [$got] for [$CASES]"
  fi
  # EQUIV: every cell below asks the subjects IN PROCESS (he-inproc.sh). This arm is the seam's proof and the
  # fixture's one END-TO-END run per distinct CLI outcome (fixture-mutants.md clauses 5-6): each row runs
  # `bash <subject> <args>` and he_run/ro_run/ss_run on the SAME input, and stdout+stderr and the exit code
  # must be byte-identical. Rows: the validator's handoff refusal (1), pass (0) and UNEVALUABLE (2), strategy
  # 1/0, --gate2, --list-captures, --render-dar and its --check refusal, --smoke; record-only-diff.sh's paths
  # 1/0 and none-reason 0/1/2; sprint-status.sh's story-status over a mismatching and an untracked story.
  # Each refusing row's output must differ from its passing twin's, so the comparison cannot pass on two
  # identical answers.
  RO_SH="$(dirname "$HECTL")/record-only-diff.sh"; SS_SH="$(dirname "$HECTL")/sprint-status.sh"
  eq_row() { # <label> <fn> <subject> <args...>  -> appends "<label> <rc>" or "<label> DIFF" to $WORK/eq.rows
    local l="$1" fn="$2" urc crc
    shift 2
    "$fn" "$@" > "$WORK/eq.$l.u" 2>&1; urc=$?
    bash "$@" > "$WORK/eq.$l.c" 2>&1; crc=$?
    if cmp -s "$WORK/eq.$l.u" "$WORK/eq.$l.c" && [ "$urc" = "$crc" ]; then echo "$l $urc" >> "$WORK/eq.rows"
    else echo "$l DIFF($urc/$crc)" >> "$WORK/eq.rows"; fi
  }
  : > "$WORK/eq.rows"
  wc_="$WORK/world-clean"; wn_="$WORK/world-nocmd"; wy_="$WORK/world-yamlmis"; we_="$WORK/world-empty"; wf_="$WORK/world-fccode"
  eq_row h-refuse he_run "$HECTL" -C "$wn_" "$STORY" "$(cat "$wn_/.B")" "$(cat "$wn_/.T")"
  eq_row h-pass he_run "$HECTL" -C "$wc_" "$STORY" "$(cat "$wc_/.B")" "$(cat "$wc_/.T")"
  eq_row h-uneval he_run "$HECTL" -C "$wc_" "$STORY" "$(cat "$wc_/.B")" no-such-ref
  eq_row s-refuse he_run "$HECTL" -C "$we_" --strategy "$(cat "$we_/.T")" "$STORY"
  eq_row s-pass he_run "$HECTL" -C "$wc_" --strategy "$(cat "$wc_/.T")" "$STORY"
  eq_row g2 he_run "$HECTL" -C "$wy_" --gate2 "$STORY" "$(cat "$wy_/.B")" "$(cat "$wy_/.T")"
  eq_row lc he_run "$HECTL" -C "$wc_" --list-captures "$STORY" "$(cat "$wc_/.T")"
  eq_row rd he_run "$HECTL" -C "$wc_" --render-dar "$STORY" "$(cat "$wc_/.T")"
  eq_row rdc-refuse he_run "$HECTL" -C "$wc_" --render-dar "$STORY" "$(cat "$wc_/.T")" --check
  eq_row sm he_run "$HECTL" -C "$wc_" --smoke "$STORY" "$(cat "$wc_/.B")" "$(cat "$wc_/.T")"
  eq_row ro-paths-refuse ro_run "$RO_SH" paths -C "$wf_" "$STORY" "$(cat "$wf_/.B")" "$(cat "$wf_/.T")"
  eq_row ro-paths-pass ro_run "$RO_SH" paths -C "$wf_" "$STORY" "$(cat "$wf_/.T")" "$(cat "$wf_/.T")"
  eq_row ro-none-reason ro_run "$RO_SH" none-reason 'none, a record-only rework'
  eq_row ro-none-bare ro_run "$RO_SH" none-reason 'none'
  eq_row ro-none-not ro_run "$RO_SH" none-reason 'see dev report'
  eq_row ss-mismatch ss_run "$SS_SH" story-status --ref "$(cat "$wy_/.T")" --root "$wy_" "$STORY"
  eq_row ss-untracked ss_run "$SS_SH" story-status --ref "$(cat "$WORK/world-untracked/.T")" --root "$WORK/world-untracked" "$STORY"
  EQWANT='h-refuse 1 h-pass 0 h-uneval 2 s-refuse 1 s-pass 0 g2 0 lc 0 rd 0 rdc-refuse 1 sm 0 ro-paths-refuse 1 ro-paths-pass 0 ro-none-reason 0 ro-none-bare 1 ro-none-not 2 ss-mismatch 0 ss-untracked 0'
  got="$(tr '\n' ' ' < "$WORK/eq.rows")"; got="${got% }"
  if [ "$got" = "$EQWANT" ] && ! cmp -s "$WORK/eq.h-refuse.c" "$WORK/eq.h-pass.c" && ! cmp -s "$WORK/eq.s-refuse.c" "$WORK/eq.s-pass.c" \
     && ! cmp -s "$WORK/eq.ro-paths-refuse.c" "$WORK/eq.ro-paths-pass.c" && ! cmp -s "$WORK/eq.ss-mismatch.c" "$WORK/eq.ss-untracked.c" \
     && grep -q '^REFUSED no-command ' "$WORK/eq.h-refuse.c" && grep -q '^row	ready-for-dev	' "$WORK/eq.ss-mismatch.c"; then
    ok "EQUIV: in process and by CLI, byte-identical output and exit on every row, each refusal differing from its pass (handoff 1/0/2, strategy 1/0, --gate2, --list-captures, --render-dar and its --check refusal, --smoke; record-only-diff.sh paths 1/0 and none-reason 0/1/2; sprint-status.sh story-status twice)"; B_eq=1
  else
    bad "EQUIV: want [$EQWANT] with each refusal differing from its pass, got [$got]"
  fi
  # The SHIPPED validator, in place, beside its real sibling: the control tree above is a copy.
  got="$(verdict "$HE" "$WORK/world-yamlmis" h) $(verdict "$HE" "$WORK/world-noyaml" h)"
  if [ "$got" = "1:status-yaml-mismatch,:W 0::W:S" ]; then
    ok "IN PLACE: the shipped validator reaches its own sprint-status.sh (a row mismatch refuses, a missing yaml prints SKIP STATUS)"
  else
    bad "IN PLACE: the shipped validator did not reach its sibling -- want [1:status-yaml-mismatch,:W 0::W:S] got [$got]"
  fi
  # --gate2 (arm h skipped at a gate-2 go-signal sha). The seeded offender is world-yamlmis, which arm (h)
  # refuses. g2_vec prints, for a script: the flagged run's "<rc>:<refusals>:<SKIP STATUS (--gate2 line seen y/n)>"
  # then the unflagged control's. A mutant that ignores the flag leaves the flagged run refused.
  g2_vec() { # <script> [unflagged] -> the flagged run's "<rc>:<refusals>:<SKIP STATUS (--gate2 line seen y/n)>"; with a 2nd arg, the unflagged control's
    local s="$1" w="$WORK/world-yamlmis" o rc
    if [ -n "${2:-}" ]; then o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
    else o="$(he_run "$s" -C "$w" --gate2 "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?; fi
    printf '%s:%s:%s' "$rc" "$(awk '/^REFUSED /{print $2}' <<<"$o" | tr '\n' ',')" "$(grep -qF 'SKIP STATUS (--gate2' <<<"$o" && echo y || echo n)"
  }
  # The unflagged control is read once, on the control validator: the gate2-ignored mutant edits only the flagged branch.
  G2WANT='0::y'; G2CTL='1:status-yaml-mismatch,:n'
  got="$(g2_vec "$HECTL") $(g2_vec "$HECTL" unflagged)"
  if [ "$got" = "$G2WANT $G2CTL" ]; then ok "GATE2: with --gate2 the row-mismatch story prints SKIP STATUS (--gate2 ...) and is not refused for (h); without it the same story is still refused status-yaml-mismatch"; B_g2=1
  else bad "GATE2: want [$G2WANT $G2CTL] got [$got]"; fi
  if m="$(mkmut gate2-ignored he 'if [ "$GATE2" -eq 1 ]; then' 'if [ "$GATE2" -eq 99 ]; then')" && [ -n "$m" ]; then
    got="$(g2_vec "$m")"
    if [ "$got" = "$G2WANT" ]; then bad "MUTATION 'gate2-ignored' SURVIVED -- a validator ignoring --gate2 still skips arm (h)"
    else mutant_killed "${B_g2:-0}" gate2-ignored "MUTATION 'gate2-ignored' killed: a validator ignoring --gate2 refuses the story for (h) with the flag set [$got]"; fi
  else bad "FIXTURE ERROR: gate2 mutation 'gate2-ignored' matched nothing"; fi
  # The range warning: base == frozen and a base that is not an ancestor of frozen each WARN
  # (exit 0, never a refusal); the normal range carries neither. Each mutant silences one.
  range_vec() { # <script> -> "<eq rc>:<eq kinds> <rev rc>:<rev kinds> <normal kinds>"
    local s="$1" w="$WORK/world-clean" o rc a b n
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.T")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
    a="$rc:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.T")" "$(cat "$w/.B")" 2>/dev/null)"; rc=$?
    b="$rc:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"
    n="n:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    printf '%s %s %s' "$a" "$b" "$n"
  }
  RWANT='0:range-empty:, 0:range-base:, n:'
  got="$(range_vec "$HECTL")"
  if [ "$got" = "$RWANT" ]; then ok "RANGE: base == frozen and a non-ancestor base each WARN and exit 0; the story's own range warns nothing"; B_range=1
  else bad "RANGE: want [$RWANT] got [$got]"; fi
  range_mutant() { # <name> <from> <to> <want vector> <label>
    local m got
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: range mutation '$1' matched nothing"; return; fi
    got="$(range_vec "$m")"
    if [ "$got" = "$4" ]; then mutant_killed "${B_range:-0}" "$1" "MUTATION '$1' killed, moving its own range cell only: $5"
    elif [ "$got" = "$RWANT" ]; then bad "MUTATION '$1' SURVIVED -- $5"
    else bad "MUTATION '$1' moved [$got], want [$4] -- the cells are entangled"; fi
  }
  range_mutant no-range-empty 'warn "range-empty' ': "range-empty' '0: 0:range-base:, n:' "base == frozen no longer warns"
  range_mutant no-range-base 'warn "range-base' ': "range-base' '0:range-empty:, 0: n:' "a non-ancestor base no longer warns"

  # (j) replay-preamble and the replay block's head:. rp_vec reads the four (j) worlds and, from
  # rphead, which head WARN each capture gets: rp-red-head's first `head:` (above the block) is the
  # commit frozen only adds captures to, so a reader of THAT sha warns nothing, and the block's own
  # `head:` is the base, which warns head-tree. rp-red-fallback's block carries no `head:`, so the
  # one above it is read (head-tree), never head-missing.
  rp_vec() { # <script>
    local s="$1" o w="$WORK/world-rphead" hh hf
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"
    hh="$(awk '$1=="WARN" && $3=="test-results/rp-red-head.txt:"{print $2}' <<<"$o" | tr '\n' ',')"
    hf="$(awk '$1=="WARN" && $3=="test-results/rp-red-fallback.txt:"{print $2}' <<<"$o" | tr '\n' ',')"
    printf '%s %s %s %s head=%s fallback=%s u8=%s' "$(verdict "$s" "$WORK/world-rpfirst" h)" "$(verdict "$s" "$WORK/world-rps319" h)" \
      "$(verdict "$s" "$WORK/world-rpok" h)" "$(verdict "$s" "$WORK/world-rphead" h)" "${hh%,}" "${hf%,}" "$(verdict "$s" "$WORK/world-rpu8" h)"
  }
  RPWANT='1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=1:replay-preamble,:W'
  got="$(rp_vec "$HECTL")"
  if [ "$got" = "$RPWANT" ]; then ok "REPLAY-PREAMBLE: a hand '\$ ' above the script's own refuses (with and without a second '\$ '), a replay at line 1 and the script's '\$ ' right above the replay are accepted, and head: is read from the replay block, falling back to the first head: when the block has none"; B_rp=1
  else bad "REPLAY-PREAMBLE: want [$RPWANT] got [$got]"; fi
  rp_mutant() { # <name> <from> <to> <want> <label>
    local m got
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: replay mutation '$1' matched nothing"; return; fi
    got="$(rp_vec "$m")"
    if [ "$got" = "$4" ]; then mutant_killed "${B_rp:-0}" "$1" "MUTATION '$1' killed, moving its own cell only: $5"
    elif [ "$got" = "$RPWANT" ]; then bad "MUTATION '$1' SURVIVED -- $5"
    else bad "MUTATION '$1' moved [$got], want [$4] -- the cells are entangled"; fi
  }
  # ANY `$ ` right above the replay, not the FIRST: the last `$ ` before the replay is read.
  rp_mutant rp-any-dollar '!fd && /^\$ /{fd=NR}' '/^\$ /{fd=NR}' \
    '0::W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=1:replay-preamble,:W' "a hand '\$ ' above the script's own '\$ ' line is accepted"
  rp_mutant rp-first-head 'tail -n +"$rl" <<<"$hdr"' 'tail -n +1 <<<"$hdr"' \
    '1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head= fallback=head-tree u8=1:replay-preamble,:W' "the first head: in the capture is read, not the replay block's"
  # U8: the pre-fix capture shape (rpu8) under a UTF-8 locale. Reverting `LC_ALL=C awk` makes the awk
  # abort on the non-UTF-8 line, `rp` empty, and the refusal stand down (0 here instead of 1).
  if [ -n "$UTF8_LOCALE" ]; then
    rp_mutant rp-no-lcc 'rp="$(LC_ALL=C awk' 'rp="$(awk' \
      '1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=0::W:E' "the replay-preamble awk in the caller's locale (no LC_ALL=C): a non-UTF-8 capture stands the refusal down"
  else
    printf '  SKIP  no UTF-8 locale aborts this awk — rp-no-lcc did NOT run\n'
  fi

  # ABSOLUTE STORY PATH (BL-770). norm_story turns every story argument into one toplevel-relative
  # path in both modes. Cells, in order: handoff on the clean world with the story absolute and
  # physical; the same through a symlinked alias of the world (a second spelling of one directory,
  # which a textual `${STORY#$REPO/}` strip leaves absolute); a linked worktree of that world given
  # its own absolute story path (0); the same worktree given the MAIN world's absolute path, which
  # is outside its toplevel (2, where a textual strip reads it); a relative path climbing out of the
  # tree; `<world>/lnk/../x.md` with `lnk` an untracked symlink out of the tree, whose PHYSICAL
  # parent holds a readable x.md (0.909.0's escape: it must exit 2, never read that file); strategy
  # mode, absolute, with an empty cell only in the WORKING TREE (the committed story is clean, so
  # 0); strategy mode, absolute, with the empty cell committed (world-empty, 1). Before the fix the
  # first two refused story-untracked, the two escapes ran, and the working-tree cell read 1.
  ABSW="$WORK/world-absdirty"
  if build_world "$ABSW" clean && mkdir -p "$WORK/abs-out" && ln -s "$WORK/abs-out" "$ABSW/lnk" \
     && ln -s "$WORK/world-clean" "$WORK/alias-clean" && cp "$WORK/world-clean/$STORY" "$WORK/x.md" \
     && printf '| TX | z | test |  |\n' >> "$ABSW/$STORY" \
     && gitw "$WORK/world-clean" worktree add -q --detach "$WORK/wt-clean" "$(cat "$WORK/world-clean/.T")"; then
    abs_vec() { # <script>
      local s="$1" c="$WORK/world-clean" pc pe pw a o rc out=""
      pc="$(cd -P "$c" && pwd -P)"; pe="$(cd -P "$WORK/world-empty" && pwd -P)"
      pw="$(cd -P "$WORK/wt-clean" && pwd -P)"
      # <repo> <story>: the main world physical and aliased, the linked worktree's own absolute path,
      # and the main world's absolute path handed to the linked worktree (outside its toplevel).
      for a in "$c|$pc/$STORY" "$c|$WORK/alias-clean/$STORY" "$WORK/wt-clean|$pw/$STORY" "$WORK/wt-clean|$pc/$STORY"; do
        o="$(he_run "$s" -C "${a%%|*}" "${a#*|}" "$(cat "$c/.B")" "$(cat "$c/.T")" 2>/dev/null)"; rc=$?
        out="$out $rc:$(awk '/^REFUSED /{print $2}' <<<"$o" | tr '\n' ',')"
      done
      he_run "$s" -C "$c" "stories/../../x.md" "$(cat "$c/.B")" "$(cat "$c/.T")" >/dev/null 2>&1; out="$out climb=$?"
      he_run "$s" -C "$ABSW" "$ABSW/lnk/../x.md" "$(cat "$ABSW/.B")" "$(cat "$ABSW/.T")" >/dev/null 2>&1; out="$out lnk=$?"
      he_run "$s" -C "$ABSW" --strategy "$(cat "$ABSW/.T")" "$(cd -P "$ABSW" && pwd -P)/$STORY" >/dev/null 2>&1; out="$out sdirty=$?"
      he_run "$s" -C "$WORK/world-empty" --strategy "$(cat "$WORK/world-empty/.T")" "$pe/$STORY" >/dev/null 2>&1; out="$out scommit=$?"
      printf '%s' "${out# }"
    }
    ABSWANT='0: 0: 0: 2: climb=2 lnk=2 sdirty=0 scommit=1'
    got="$(abs_vec "$HECTL")"
    if [ "$got" = "$ABSWANT" ]; then ok "ABSOLUTE STORY: an absolute story path, physical or through a symlinked alias, reads as the relative one; a relative climb and a lnk/.. hop out of the tree exit 2 (UNEVALUABLE, no read); strategy mode reads the ref, not the working tree"; B_abs=1
    else bad "ABSOLUTE STORY: want [$ABSWANT] got [$got]"; fi
    # Mutant: the raw path in both modes. Every layer is reverted: both norm_story calls go, and the
    # disk fallback reads an absolute story as given and a relative one under -C, as 0.910.0 did.
    m="$(dirname "$HECTL")/he-mut-raw-story.sh"
    FROM1='STORY="$(norm_story "$1")" || exit 2' TO1='STORY="$1"' FROM2='s="$(norm_story "$s")" || exit 2' TO2=':' \
      FROM3='[ -f "$TOP/$2" ] && { cat "$TOP/$2"; return 0; }' \
      TO3='case "$2" in /*) [ -f "$2" ] && { cat "$2"; return 0; } ;; *) [ -f "$REPO/$2" ] && { cat "$REPO/$2"; return 0; } ;; esac' \
      awk 'BEGIN{for (i=1; i<=3; i++) {f[i]=ENVIRON["FROM" i]; t[i]=ENVIRON["TO" i]}}
        {for (i=1; i<=3; i++) if (p=index($0,f[i])) {$0=substr($0,1,p-1) t[i] substr($0,p+length(f[i])); n++}}
        {print} END{exit (n==3) ? 0 : 1}' "$HE" > "$m"
    if [ $? -ne 0 ] || cmp -s "$HE" "$m"; then bad "FIXTURE ERROR: mutation 'raw-story' did not apply at all three sites"
    else
      RAWWANT='1:story-untracked, 1:story-untracked, 1:story-untracked, 1:story-untracked, climb=1 lnk=1 sdirty=1 scommit=1'
      got="$(abs_vec "$m")"
      if [ "$got" = "$RAWWANT" ]; then mutant_killed "${B_abs:-0}" raw-story "MUTATION 'raw-story' killed: the raw path refuses an absolute story as story-untracked, reads both escapes, and reads strategy mode's working tree"
      elif [ "$got" = "$ABSWANT" ]; then bad "MUTATION 'raw-story' SURVIVED -- the story path used raw in both modes"
      else bad "MUTATION 'raw-story' moved [$got], want [$RAWWANT]"; fi
    fi
    # STORY SYMLINK (BL-770). norm_story contains the story's DIRECTORY and keeps the link name, so
    # an untracked story that is itself a symlink is held to the same containment by story_text.
    # Cells, strategy mode at HEAD: an untracked symlink to a file OUTSIDE the tree whose bytes
    # carry an empty cell (2, never read; the read would give 1); an untracked symlink to an
    # in-tree clean copy (0, still readable); a TRACKED symlink blob to that same outside file (0:
    # `git show` emits the link string, nothing outside is read). Mutant 'no-story-symlink' drops
    # the -L check and moves the outside cell only, to 1 (the outside file was read).
    if cp "$ABSW/$STORY" "$WORK/abs-out/evil.md" && cp "$WORK/world-clean/$STORY" "$ABSW/stories/clean-copy.md" \
       && ln -s "$WORK/abs-out/evil.md" "$ABSW/stories/untrk.md" && ln -s clean-copy.md "$ABSW/stories/inlink.md" \
       && ln -s "$WORK/abs-out/evil.md" "$ABSW/stories/tlink.md" && gitw "$ABSW" add stories/tlink.md \
       && gitw "$ABSW" commit -qm tlink; then
      sym_vec() { # <script>
        local s="$1" pa out=""
        pa="$(cd -P "$ABSW" && pwd -P)"
        he_run "$s" -C "$ABSW" --strategy HEAD stories/untrk.md >/dev/null 2>&1; out="$out out=$?"
        he_run "$s" -C "$ABSW" --strategy HEAD "$pa/stories/untrk.md" >/dev/null 2>&1; out="$out outabs=$?"
        he_run "$s" -C "$ABSW" --strategy HEAD stories/inlink.md >/dev/null 2>&1; out="$out in=$?"
        he_run "$s" -C "$ABSW" --strategy HEAD stories/tlink.md >/dev/null 2>&1; out="$out tracked=$?"
        printf '%s' "${out# }"
      }
      SYMWANT='out=2 outabs=2 in=0 tracked=0'
      got="$(sym_vec "$HECTL")"
      if [ "$got" = "$SYMWANT" ]; then ok "STORY SYMLINK: an untracked story symlinked out of the tree exits 2 (relative and absolute), one symlinked to an in-tree file is read, and a tracked symlink blob reads as its link string"; B_sym=1
      else bad "STORY SYMLINK: want [$SYMWANT] got [$got]"; fi
      if ! m="$(mkmut no-story-symlink he 'if [ -L "$TOP/$2" ]; then' 'if false; then')" || [ -z "$m" ]; then
        bad "FIXTURE ERROR: mutation 'no-story-symlink' matched nothing"
      else
        got="$(sym_vec "$m")"
        if [ "$got" = 'out=1 outabs=1 in=0 tracked=0' ]; then mutant_killed "${B_sym:-0}" no-story-symlink "MUTATION 'no-story-symlink' killed: without the -L check the outside file is read (empty-cell)"
        elif [ "$got" = "$SYMWANT" ]; then bad "MUTATION 'no-story-symlink' SURVIVED -- an untracked story symlink out of the tree is read"
        else bad "MUTATION 'no-story-symlink' moved [$got], want [out=1 outabs=1 in=0 tracked=0]"; fi
      fi
    else
      bad "FIXTURE BROKEN: could not seed the story-symlink cells"
    fi
  else
    bad "FIXTURE BROKEN: could not seed the absolute-story world"
  fi
  # (k)/(l) BL-768, the run-record arms. fc_vec reads the sixteen run-record worlds; each mutant is
  # written into the control tree (so record-only-diff.sh is its sibling) and must move only its own
  # cells. The partition and grammar mutants edit the HELPER copy, in a tree of their own.
  FCWANT='0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W'
  # fc_vec <script> [<want>]: with a <want> vector (a mutant's), only the worlds whose cell it MOVES are run, and
  # every other cell is reported as FCWANT's value -- a mutant runs the worlds its arm decides (fixture-mutants.md
  # clause 2). Without one, every world runs (the control). "Only its own cells" is established at authoring by
  # the full run the MUTANT-MATRIX-REMEASURE line names (FC_FULL=1).
  FC_WORLDS='fcrec fccode fcbare fcgone dsgone dsbare devold devnew fcevil fcna fctbd fcempty fcnext dsna diskold disknew fcfence fcinvoc fcbold fcnonebt fcmake dsvenv'
  fc_vec() { # <script> [<want>]
    local s="$1" w="${2:-}" o="" v i=0 a b
    for v in $FC_WORLDS; do
      i=$((i + 1))
      if [ -n "$w" ] && [ -z "${FC_FULL:-}" ]; then
        a="$(awk -v n="$i" '{print $n}' <<<"$FCWANT")"; b="$(awk -v n="$i" '{print $n}' <<<"$w")"
        if [ "$a" = "$b" ]; then o="$o $a"; continue; fi
      fi
      o="$o $(verdict "$s" "$WORK/world-$v" h)"
    done
    printf '%s' "${o# }"
  }
  got="$(fc_vec "$HECTL")"
  if [ "$got" = "$FCWANT" ]; then ok "RUN-RECORD: a reasoned none over a story+yamls+docs/reviews+test-results diff accepted, over a diff touching a test refused full-collection-none, a bare none refused, a missing line refused, a dependency-setup none with no reason refused, dev.md without the label prescription is LEGACY and with it refuses both missing lines; a .py under test-results/ and a conftest.py under docs/reviews/ make a record diff non-record; N/A, TBD and an empty value over a code diff each refused, an empty value continued by the invocation accepted, a dependency-setup N/A refused; dev.md untracked at <frozen> but on disk keys LEGACY both ways; an empty value over a fenced run and over \`- Invocation:\` accepted, over a bold label refused; a none carrying a runner span and a two-word span naming no runner refused; a venv interpreter with its packages accepted as a setup"; B_fc=1
  else bad "RUN-RECORD: want [$FCWANT] got [$got]"; fi
  fc_mutant() { # <name> <he|ro> <from> <to> <want> <label>
    local m got t
    if [ "$2" = ro ]; then
      t="$(mk_tree "$1")" || { bad "FIXTURE ERROR: run-record mutation '$1' could not build its tree"; return; }
      FROM="$3" TO="$4" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' \
        "$(dirname "$HE")/record-only-diff.sh" > "$(dirname "$t")/record-only-diff.sh.tmp"
      if cmp -s "$(dirname "$HE")/record-only-diff.sh" "$(dirname "$t")/record-only-diff.sh.tmp"; then bad "FIXTURE ERROR: run-record mutation '$1' matched nothing"; return; fi
      mv "$(dirname "$t")/record-only-diff.sh.tmp" "$(dirname "$t")/record-only-diff.sh"; m="$t"
    elif ! m="$(mkmut "$1" he "$3" "$4")" || [ -z "$m" ]; then bad "FIXTURE ERROR: run-record mutation '$1' matched nothing"; return; fi
    got="$(fc_vec "$m" "$5")"
    if [ "$got" = "$5" ]; then mutant_killed "${B_fc:-0}" "$1" "MUTATION '$1' killed, moving its own cells only: $6"
    elif [ "$got" = "$FCWANT" ]; then bad "MUTATION '$1' SURVIVED -- $6"
    else bad "MUTATION '$1' moved [$got], want [$5] -- the cells are entangled"; fi
  }
  # The partition's record directories dropped: the record world (docs/reviews, test-results) refuses.
  fc_mutant ro-no-record-dirs ro '        docs/reviews/*|test-results/*|docs/escalations/*)' '        NEVER-A-RECORD-PATH)' \
    '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "the record directories dropped from the record-only partition"
  # The code-suffix exclusion inside the record directories dropped: fcevil's test module is a record.
  fc_mutant ro-no-suffix ro '            *.py|*.sh|*.toml|*.cfg|conftest.py|pytest.ini) first="$p" ;;' '            NEVER-A-SUFFIX) first="$p" ;;' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "a collectable .py / conftest.py under a record directory classed record-only"
  # The exemption check dropped: any reasoned none passes, so the code-touching none is accepted.
  fc_mutant fc-no-diff he "    || refuse \"\$3 \$STORY: '\$1 \${2:-<empty>}' records no run" "    || : \"\$3 \$STORY: '\$1 \${2:-<empty>}' records no run" \
    '0: 0: 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 0: 0: 0::W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 0: 0: 0::W' \
    "a reasoned none accepted whatever the diff"
  # The none grammar's reason requirement dropped: a bare `none` reads as reasoned.
  fc_mutant ro-bare-none ro '        "$w") rest=""; exit 1 ;;' '        "$w") exit 0 ;;' \
    '0: 1:full-collection-none, 0: 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "a none with no reason accepted"
  fc_mutant ds-no-missing he '    refuse "dependency-setup-missing' '    : "dependency-setup-missing' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 0::W 1:dependency-setup-none,:W 0: 1:full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "a missing dependency-setup line accepted"
  # The LEGACY gate dropped: dev.md at <frozen> is never read, so the old installed dev.md refuses.
  fc_mutant fc-no-legacy he 'if [ "$ev_rd" = 1 ] && ! grep' 'if false && ! grep' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 1:dependency-setup-missing,full-collection-missing, 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 1:dependency-setup-missing,full-collection-missing, 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "the installed-dev.md LEGACY gate dropped"
  # The on-disk fallback dropped: a dev.md untracked at <frozen> is unreadable, so diskold is held.
  fc_mutant fc-no-disk he 'if [ "$ev_rd" = 0 ]; then' 'if false; then' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 1:dependency-setup-missing,full-collection-missing, 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "the on-disk dev.md is not read when none is tracked at <frozen>"
  # The inversion reverted: only a none form is a no-run claim, so N/A, TBD and an empty value pass.
  fc_mutant fc-no-invert he '  elif ! bash "$RO" run-shape "$fc" ${ev_conv:+"$ev_conv"}; then' '  elif bash "$RO" none-reason "$fc" 2>/dev/null; [ $? -ne 2 ]; then' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 0: 0: 0: 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 1:full-collection-none, 0: 0::W' \
    "a no-run claim spelled other than none accepted over a code diff"
  # The label's next-line continuation dropped: an empty value followed by the invocation refuses.
  fc_mutant ro-no-continue ro '        cont = 1; next }' '        print v; done = 1; exit }' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "an empty label value continued by the invocation on the next line refused"
  # The fenced continuation dropped: an empty label over a fenced run reads as empty (fcfence refuses).
  fc_mutant ro-no-fence ro '{ f = !f; if (cont && f && !post) inf = 1;' '{ f = !f; if (0) inf = 1;' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' "an empty label value over a fenced run refused"
  # The bold label refusal dropped: a bold label line under an empty value is taken as the value.
  fc_mutant ro-no-bold ro ' || t ~ /^\*\*[A-Za-z][A-Za-z0-9 _-]*(:\*\*|\*\*:)/ }' ' }' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 0::W' "a bold label line taken as the continued value"
  # The Invocation continuation dropped: `- Invocation: <cmd>` under an empty value reads as a new label.
  fc_mutant ro-no-invocation ro '             else if (s ~ /^Invocation:[ \t]/)' '             else if (0)' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' "an Invocation: line under an empty value read as a new label"
  # The no-run reading not decided first: a none whose reason holds a runner span reads as a run.
  fc_mutant ro-shape-none-last ro '    (ro_none_reason none-reason "$2") >/dev/null 2>&1; [ $? -eq 2 ] || exit 1' '    :' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 0: 1:full-collection-none, 0::W' "a none form carrying a runner span read as a run"
  # The runner requirement dropped: any backticked span is a run, so `make docs` acquits.
  fc_mutant ro-shape-any-span ro '    grep -qE "(^|[[:space:]/\`])($rs_rn)([[:space:]\`]|\$)" <<<"$rs_sp" && exit 0' '    [ -n "$rs_sp" ] && exit 0' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 0::W' "a backticked span naming no runner read as a run"
  # The interpreter-path setup dropped: a venv interpreter with its packages reads as no setup.
  fc_mutant ro-setup-no-venv ro "      grep -qE '/bin/python|venv' <<<\"\$rs_sp\" \\" '      false \' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:dependency-setup-none,:W' "a dependency setup naming a venv interpreter and its packages refused"

  # BL-768: the dev gate passes the project's conventions file to run-shape as the QA side does.
  # fcconv (tox -e all declared canonical) is accepted, fcconv-none (same value, no file) is refused,
  # and a validator that drops the conventions argument refuses fcconv.
  if build_world "$WORK/world-fcconv" fcconv && build_world "$WORK/world-fcconv-none" fcconv-none; then
    cv_c="$(verdict "$HECTL" "$WORK/world-fcconv" h)"; cv_n="$(verdict "$HECTL" "$WORK/world-fcconv-none" h)"
    if [ "$cv_c" = '0:' ] && [ "$cv_n" = '1:full-collection-none,' ]; then
      ok "CONVENTIONS: a runner the conventions declare canonical (tox -e all) is accepted at the dev gate, and the same value with no conventions file is refused full-collection-none"; B_conv=1
    else bad "CONVENTIONS: want [0:] and [1:full-collection-none,] got [$cv_c] and [$cv_n]"; fi
    if cv_m="$(mkmut fc-no-conv he 'run-shape "$fc" ${ev_conv:+"$ev_conv"}; then' 'run-shape "$fc"; then')" && [ -n "$cv_m" ]; then
      cv_mv="$(verdict "$cv_m" "$WORK/world-fcconv" h)"
      if [ "$cv_mv" = '1:full-collection-none,' ]; then mutant_killed "${B_conv:-0}" fc-no-conv "MUTATION 'fc-no-conv' killed: the dev gate dropping the conventions argument refuses fcconv"
      elif [ "$cv_mv" = "$cv_c" ]; then bad "MUTATION 'fc-no-conv' SURVIVED -- the dev gate drops the conventions argument"
      else bad "MUTATION 'fc-no-conv' moved [$cv_mv], want [1:full-collection-none,]"; fi
    else bad "FIXTURE ERROR: mutation 'fc-no-conv' matched nothing"; fi
  else bad "FIXTURE BROKEN: could not seed the conventions worlds"; fi

  # POINTER: run-shape's pointer-word refusal, in a world only it decides (fcsee: `see` opens a value that carries a
  # runner span and a count and is no none form), with its near-miss (fcseenm: the same span and count, `see` not
  # opening). Mutant ro-no-pointer drops the pointer rule from record-only-diff.sh in a tree of its own and moves
  # fcsee only, to accepted.
  if build_world "$WORK/world-fcsee" fcsee && build_world "$WORK/world-fcseenm" fcseenm; then
    pt_vec() { printf '%s %s' "$(verdict "$1" "$WORK/world-fcsee" h)" "$(verdict "$1" "$WORK/world-fcseenm" h)"; }
    PTWANT='1:full-collection-none, 0:'
    got="$(pt_vec "$HECTL")"
    if [ "$got" = "$PTWANT" ]; then ok "POINTER: a value opening with see, carrying a runner span and a count, is refused full-collection-none over a code diff; the same span and count with see later in the value is a run"; B_pt=1
    else bad "POINTER: want [$PTWANT] got [$got]"; fi
    if pt_t="$(mk_tree ro-no-pointer)"; then
      FROM="    grep -qE '^(see|refer|n/a|na|tbd|todo|deferred|pending)([^a-z0-9]|\$)' <<<\"\$rs_lc\" && exit 1" TO='    :' \
        awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' \
        "$(dirname "$HE")/record-only-diff.sh" > "$(dirname "$pt_t")/record-only-diff.sh.tmp"
      if cmp -s "$(dirname "$HE")/record-only-diff.sh" "$(dirname "$pt_t")/record-only-diff.sh.tmp"; then bad "FIXTURE ERROR: mutation 'ro-no-pointer' matched nothing"
      else
        mv "$(dirname "$pt_t")/record-only-diff.sh.tmp" "$(dirname "$pt_t")/record-only-diff.sh"
        got="$(verdict "$pt_t" "$WORK/world-fcsee" h)"
        if [ "$got" = '0:' ]; then mutant_killed "${B_pt:-0}" ro-no-pointer "MUTATION 'ro-no-pointer' killed by cell fcsee: without the pointer rule a see-opened value is read as a run"
        elif [ "$got" = '1:full-collection-none,' ]; then bad "MUTATION 'ro-no-pointer' SURVIVED -- the pointer-word rule dropped"
        else bad "MUTATION 'ro-no-pointer' moved fcsee to [$got], want [0:]"; fi
      fi
    else bad "FIXTURE ERROR: run-record mutation 'ro-no-pointer' could not build its tree"; fi
  else bad "FIXTURE BROKEN: could not seed the pointer worlds"; fi

  # The story line is parsed WHATEVER sprint-status.sh exits. No yaml makes the shipped
  # story-status exit non-zero portably after its story line, so the sibling's exit is
  # synthesised: two trees whose sprint-status.sh is a wrapper that runs the real one, writes one
  # stderr line, and exits 3 in one tree and 0 in the other. Only the exit differs, so a SKIP in
  # the rc-3 tree is the exit's and not the wrapper's. Driven over notreview (story and row
  # in-progress): (g) must refuse in both, and the rc-3 tree adds a SKIP STATUS for the row.
  rc_tree() { # <name> <exit> -> path of the validator in a tree whose sibling exits <exit>
    local v d
    v="$(mk_tree "$1")" || return 1
    d="$(dirname "$v")"
    mv "$d/sprint-status.sh" "$d/sprint-status.real.sh" || return 1
    # The wrapper is LOADABLE as the real one is (an ss_main, then the source guard), so the validator's
    # `bash <dir>/sprint-status.sh` reaches it in process (he-inproc.sh); run by bash it answers the same.
    printf '#!/usr/bin/env bash\nss_main() {\n  ( . "${BASH_SOURCE[0]%%/*}/sprint-status.real.sh" || exit 2; ss_main "$@" )\n  echo "sprint-status: synthetic failure after the story line" >&2\n  exit %s\n}\n%s\nss_main "$@"\n' \
      "$2" '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' > "$d/sprint-status.sh" || return 1
    printf '%s\n' "$v"
  }
  if RC3="$(rc_tree ssrc3 3)" && RC0="$(rc_tree ssrc0 0)"; then
    RCWANT='1:status-not-review,:W:S 1:status-not-review,:W'
    rc_vec() { printf '%s %s' "$(verdict "$1" "$WORK/world-notreview" k)" "$(verdict "$2" "$WORK/world-notreview" k)"; }
    got="$(rc_vec "$RC3" "$RC0")"
    skip_line="$(he_run "$RC3" -C "$WORK/world-notreview" "$STORY" "$(cat "$WORK/world-notreview/.B")" "$(cat "$WORK/world-notreview/.T")" 2>/dev/null | grep -c '^SKIP STATUS (implementation-view row .*exited 3: sprint-status: synthetic failure')" || skip_line=0
    if [ "$got" = "$RCWANT" ] && [ "$skip_line" -eq 1 ]; then
      ok "SIBLING EXIT: a sprint-status.sh exiting 3 after its story line still lets (g) refuse status-not-review, and the row half prints one SKIP STATUS naming the exit; the same wrapper at exit 0 prints none"; B_rc3=1
    else
      bad "SIBLING EXIT: want [$RCWANT] and one SKIP STATUS naming exit 3, got [$got] and $skip_line"
    fi
    # M1: arm (g) gated on the sibling's exit. Written beside each wrapper so it calls that one.
    m1_kill="" m1_ctl=""
    for t in "$RC3" "$RC0"; do
      m="$(dirname "$t")/he-mut-skip-on-exit.sh"
      FROM='if [ -z "$st_line" ]; then' TO='if [ -z "$st_line" ] || [ "$ss_rc" -ne 0 ]; then' \
        awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$HE" > "$m"
      if cmp -s "$HE" "$m"; then bad "FIXTURE ERROR: mutation 'skip-on-exit' matched nothing"; m1_kill=x; break; fi
      if [ "$t" = "$RC3" ]; then m1_kill="$(verdict "$m" "$WORK/world-notreview" k)"; else m1_ctl="$(verdict "$m" "$WORK/world-notreview" k)"; fi
    done
    if [ "$m1_kill" = x ]; then :
    elif [ "$m1_kill" = '0::W:S' ] && [ "$m1_ctl" = '1:status-not-review,:W' ]; then
      mutant_killed "${B_rc3:-0}" skip-on-exit "MUTATION 'skip-on-exit' killed: arm (g) gated on the sibling's exit reads the story line as a SKIP at exit 3 (identity control at exit 0 still refuses)"
    elif [ "$m1_kill" = '1:status-not-review,:W:S' ]; then
      bad "MUTATION 'skip-on-exit' SURVIVED -- arm (g) gated on the sibling's exit"
    else
      bad "MUTATION 'skip-on-exit' moved [$m1_kill / $m1_ctl], want [0::W:S / 1:status-not-review,:W]"
    fi
  else
    bad "FIXTURE BROKEN: could not build the wrapped sprint-status.sh trees"
  fi

  # --- BL-815 CAPTURE NORMALISATION (cn_*) ------------------------------------------------------
  # A separately named block: the --list-captures arms land beside it, not inside it. receipt-bl815.sh
  # owns the world and the cells (its header lists them). Every relative token resolves from the
  # TOPLEVEL: an inner `a/../b`, physical-absolute and symlinked-alias spellings of a tracked capture
  # with no command line must each be REFUSED no-command (judged, not merely warned); the toplevel
  # spelling is the unchanged control; a leading `../` climbs out and WARNs capture-unresolved
  # (outside) although the story-directory reading names a tracked file, and a RED one is REFUSED
  # red-untracked; an untracked non-ignored citation and an other-worktree / climbing one WARN with
  # their reasons; one the frozen .gitignore ignores prints nothing; the WARN never moves the exit;
  # --list-captures lists the toplevel spellings; and cell xr holds BOTH readers to one answer on one
  # `./` token. Every mutant is written beside record-only-diff.sh in the control tree and must FAIL
  # its own named cell and leave the ctl cell standing.
  # Every receipt below is SOURCED in a fresh subshell (rcpt_run), and its world is seeded ONCE into
  # $WORK/rw-<receipt> by the control call and read by every mutant call (no call writes into it).
  cn_run() { rcpt_run "$WORK/rw-bl815" "$DIR/receipt-bl815.sh" "$1" ${2:+"$2"} 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell
  cn_out="$(cn_run "$HECTL")"; cn_rc=$?
  if [ "$cn_rc" -eq 0 ]; then ok "CAPTURE NORMALISATION: inner ../, absolute and aliased spellings of a tracked capture are judged (no-command), a leading ../ is outside the repository (WARN, or red-untracked when RED), untracked and outside citations WARN capture-unresolved with their reasons, a frozen-.gitignore'd one prints nothing, the exit is unchanged, --list-captures lists the toplevel spellings, and both readers agree on one ./ token"; B_cn=1
  else bad "CAPTURE NORMALISATION: receipt-bl815.sh exited $cn_rc on the shipped validator: $(tr '\n' ' ' <<<"$cn_out")"; fi
  cn_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
    local m o mrc
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
    o="$(cn_run "$m" "$4")"; mrc=$?
    if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
    elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the toplevel control cell -- $5"
    elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then mutant_killed "${B_cn:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
    else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
  }
  # BL-849: the helper records its failures with bad(), which writes the fixture-level rc. A local of the
  # same name shadowed it and lost every failure on return. This arm drives the real helper with an anchor
  # that matches nothing and asserts the exit counter moved by exactly one; it dies if the local returns.
  _r849=$rc; rc=0
  cn_mutant b849-never-applies ZZQX_NEVER_ANCHOR_849 x inner "BL-849 probe" 2>/dev/null
  if [ "$rc" -eq 1 ]; then rc=$_r849; ok "BL-849: a cn_mutant mutant that does not apply reaches the exit counter"
  else rc=1; bad "BL-849: a DID-NOT-APPLY cn_mutant mutant did not reach the exit counter"; fi
  cn_mutant cn-n1-no-normaliser '    cap_norm "$t" || CN=""' '    CN="$t"' inner "N1: the normaliser removed, an a/../b capture is not judged"
  cn_mutant cn-n2-no-warn '[ -z "$ureason" ] || warn "capture-unresolved' '[ -z "$ureason" ] || : "capture-unresolved' un "N2: the capture-unresolved WARN removed, an untracked citation is silent"
  cn_mutant cn-n3-dotdot-from-story '    *) p="$t" ;;' '    ./*|../*) p="${STORY%/*}/$t" ;; *) p="$t" ;;' dd "N3: ./ and ../ resolved against the story's directory, not the toplevel"
  cn_mutant cn-n5-split-readers 'cap_tokens 0 <<<"$TEXT" | cap_resolve' 'cap_tokens 0 <<<"$TEXT" | while IFS="$TAB" read -r r x; do [ "${x#./}" = "$x" ] || x="${STORY%/*}/$x"; printf "%s\t%s\n" "$r" "$x"; done | cap_resolve' xr "N5: the handoff arms read ./ from the story's directory while --list-captures reads it from the toplevel"
  cn_mutant cn-n4-no-ignore-exempt 'elif ignored_at_frozen "$cap"; then' 'elif false; then' ign "N4: the frozen-.gitignore exemption removed, a gitignored full-suite capture WARNs"
  cn_mutant cn-n6-silent-unreadable 'warn "gitignore-unreadable' ': "gitignore-unreadable' gu "N6: an unreadable frozen .gitignore set is not named, the WARNs lose their cause"
  # --- end BL-815 CAPTURE NORMALISATION -----------------------------------------------------------

  # --- BL-809 ARMS (b9_*) ---------------------------------------------------------------------------
  # Arms (m) K-UNQUOTED (a refusal) and (n) PLACEHOLDER (a WARN). receipt-bl809.sh owns the world and
  # the cells (its header lists them): `-k alpha or beta` unquoted is REFUSED k-unquoted; `-k "a or b"`,
  # `-k 'a and b'` and single-word `-k alpha` are quiet; `<tree>` on a `$ ` line WARNs placeholder;
  # `<redacted>` and `<base-worktree>` are quiet; the placeholder WARN never moves the exit; a capture
  # with no command line is the unchanged no-command control (cell ctl). Every mutant is written beside
  # record-only-diff.sh in the control tree and must FAIL its own named cell and leave ctl standing.
  b9_run() { rcpt_run "$WORK/rw-bl809" "$DIR/receipt-bl809.sh" "$1" ${2:+"$2"} 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell
  b9_out="$(b9_run "$HECTL")"; b9_rc=$?
  if [ "$b9_rc" -eq 0 ]; then ok "BL-809 ARMS: an unquoted multi-word -k is REFUSED k-unquoted, quoted and single-word -k are quiet, a <tree> placeholder WARNs without moving the exit, <redacted> and <base-worktree> are quiet"; B_b9=1
  else bad "BL-809 ARMS: receipt-bl809.sh exited $b9_rc on the shipped validator: $(tr '\n' ' ' <<<"$b9_out")"; fi
  b9_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
    local m o mrc
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
    o="$(b9_run "$m" "$4")"; mrc=$?
    if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
    elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the no-command control cell -- $5"
    elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then mutant_killed "${B_b9:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
    else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
  }
  # BL-849: the helper records its failures with bad(), which writes the fixture-level rc. A local of the
  # same name shadowed it and lost every failure on return. This arm drives the real helper with an anchor
  # that matches nothing and asserts the exit counter moved by exactly one; it dies if the local returns.
  _r849=$rc; rc=0
  b9_mutant b849-never-applies ZZQX_NEVER_ANCHOR_849 x inner "BL-849 probe" 2>/dev/null
  if [ "$rc" -eq 1 ]; then rc=$_r849; ok "BL-849: a b9_mutant mutant that does not apply reaches the exit counter"
  else rc=1; bad "BL-849: a DID-NOT-APPLY b9_mutant mutant did not reach the exit counter"; fi
  b9_mutant b9-m1-no-kunq 'if [ -n "$kl" ]; then' 'if false; then' kunq "M1: arm (m) removed, an unquoted multi-word -k passes"
  b9_mutant b9-m2-quoted $'[^[:space:]"\'"\'"\']+[[:space:]]+(or' '[^[:space:]]+[[:space:]]+(or' kq "M2: arm (m) accepts a quoted expression as unquoted"
  b9_mutant b9-m3-no-exempt 'if (p != "<redacted>" && p != "<base-worktree>") print' 'print' red "M3: arm (n)'s <redacted>/<base-worktree> exemptions removed"
  b9_mutant b9-m4-refusal 'warn "placeholder' 'refuse "placeholder' rc "M4: arm (n) made a refusal, so a placeholder moves the exit"
  # --- end BL-809 ARMS ------------------------------------------------------------------------------

  # --- BL-845 SMOKE ARMS (sm_*) -----------------------------------------------------------------------
  # The mechanical half of Check 11: smoke_arms, run by --smoke and by handoff mode. receipt-bl845.sh owns
  # the worlds and the cells (its header lists them): m1 smoke-listed-absent (an untracked listed path, a
  # directory), the removal clause, each rejected token form (`/api/...`, `KEY=http://...`, a glob) and
  # each stripped suffix (`:352`, `::Class::test`), m2 smoke-not-updated on the LITERAL s320 4.2 body and
  # its empty-body non-surface near-miss, the four surface states (absent: SKIP undeclared and NO
  # `SMOKE OK`; `none`; empty; globs), smoke-surface-edited with the surface read at <base>, the heading,
  # fence and CRLF grammar, and the handoff-mode call. Every mutant is written beside record-only-diff.sh
  # in the control tree and must FAIL its own named cell and leave the clean cell standing.
  # The worlds are seeded ONCE, into $SMW, by the first call; every mutant call reuses them (a mutant edits
  # the validator, never a world). A copy taken right after seeding is compared with `diff -r` after the
  # last mutant, so a call that wrote into a world fails the arm instead of skewing the later cells.
  SMW="$WORK/sm-worlds"
  sm_run() { rcpt_run - "$DIR/receipt-bl845.sh" "$1" "$SMW" "${2:-}" 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell (plus clean)
  sm_out="$(sm_run "$HECTL")"; sm_rc=$?
  [ -f "$SMW/.seeded" ] && cp -R "$SMW" "$WORK/sm-worlds.snap" || { sm_rc=9; sm_out="$sm_out (the worlds were not seeded once into $SMW)"; }
  if [ "$sm_rc" -eq 0 ]; then ok "BL-845 SMOKE ARMS: an untracked listed test file is REFUSED smoke-listed-absent and a removed one is not; directory, trailing-slash and extensionless tokens are ignored by m1; /api, KEY=URL and glob tokens are not paths, :line and ::node suffixes are stripped; the s320 4.2 body over a UI diff is REFUSED smoke-not-updated, an empty body over a non-UI diff is quiet, and an :(exclude) or :! surface line removes a generated file from the surface; an absent surface prints SKIP undeclared and no SMOKE OK, none prints NO-SURFACE, an empty one SKIP empty, a capitalised None NO-SURFACE, a surface line git rejects and a surface matching nothing at base (none., a backticked none, a typo) REFUSED smoke-surface-unevaluable with exit 1 while a matching glob the range misses is quiet and a surface directory the story creates is not refused, a corrupt base tree under the surface is UNEVALUABLE (exit 2) and not a rejected pathspec, an unevaluable range diff with nothing refused exits 2, a refusal outranks a later unevaluable diff (exit 1, never 2) in both modes, an :(exclude,glob) line drops a top-level test file that :(exclude) keeps, and -C <subdirectory> refuses as -C <toplevel> does; an edited surface is REFUSED and read at base; fences, CRLF and the next heading bound the section; handoff mode runs the same arms"; B_sm=1
  else bad "BL-845 SMOKE ARMS: receipt-bl845.sh exited $sm_rc on the shipped validator: $(tr '\n' ' ' <<<"$sm_out")"; fi
  sm_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
    local m o mrc
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
    o="$(sm_run "$m" "$4")"; mrc=$?
    if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
    elif grep -q '^FAIL clean:' <<<"$o"; then bad "MUTATION '$1' moved the clean control cell -- $5"
    elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then mutant_killed "${B_sm:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
    else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
  }
  sm_mutant sm-m1-off 'refuse "smoke-listed-absent $st: \`$tok\` in ## Smoke Test Updates is not tracked' ': "smoke-listed-absent $st: \`$tok\` in ## Smoke Test Updates is not tracked' m1 "m1 removed, an untracked listed smoke test passes"
  # The candidate rule has two guards, each with a subject the other cannot reach: `web/tests`, `web/`,
  # `test-results/` and `tests/e2e` carry no `.` in their last segment (only the extension rule acquits
  # them), and `web/tests/e2e.d` is a dotted TREE (only the tree rule acquits it).
  sm_mutant sm-m1-no-ext 'case "${tok##*/}" in *.*) ;; *) continue ;; esac' ':' e2e "an extensionless or directory prose token refused as a listed test"
  sm_mutant sm-m1-tree '[ "$ty" = tree ] && continue' ':' dotdir "a dotted directory token refused as a listed test"
  sm_mutant sm-m1-no-removal '[ "$rmv" = 1 ] && continue' ':' rm "the removal clause dropped, a removed listed test is refused"
  sm_mutant sm-tok-slash ' || t ~ /^\// || ' ' || ' api "a token starting with / read as a path"
  sm_mutant sm-tok-chars ' || t ~ /=|:\/\/|[*?[]/) continue' ') continue' kv "KEY=URL and glob tokens read as paths"
  sm_mutant sm-tok-line 'sub(/:[0-9]+$/, "", t)' 'sub(/^NEVER$/, "", t)' line "the :<line> suffix not stripped"
  sm_mutant sm-tok-node 'sub(/::.*$/, "", t);' 'sub(/^NEVER$/, "", t);' node "the ::node suffix not stripped"
  sm_mutant sm-fence 'if (sfc == "" && m != "") { sfc = m; next }' 'if (0) { sfc = m; next }' grammar "fenced lines read as section text"
  sm_mutant sm-section-end '    /^##?[ \t]/ { on = 0 }' '    /^NEVER/ { on = 0 }' grammar "the section runs on past the next heading"
  sm_mutant sm-m2-off 'refuse "smoke-not-updated' ': "smoke-not-updated' s320 "m2 removed, the s320 4.2 body over a UI diff passes"
  sm_mutant sm-m2-any-token 'if grep -qxF -- "$tok" <<<"$chg"; then hit="$tok"' 'if true; then hit="$tok"' s320 "any backticked path acquits m2 (the S1 predicate), so s320 4.2 passes"
  sm_mutant sm-surface-inverted 'if [ -z "$hits" ]; then' 'if [ -n "$hits" ]; then' s320 "the surface match inverted"
  # Every surface line must reach git as its own pathspec: passing only the first drops the exclude.
  sm_mutant sm-surface-first-line '"$sb" "$sf" -- $globs 2>/dev/null)"' '"$sb" "$sf" -- $(head -n 1 <<<"$globs") 2>/dev/null)"' excl "only the first surface line reaches git, so an exclude pathspec is lost"
  sm_mutant sm-surface-at-frozen 'local srev="$sb"' 'local srev="$sf"' edited "the surface read at <frozen>, so the story moves its own gate"
  sm_mutant sm-no-edited 'refuse "smoke-surface-edited' ': "smoke-surface-edited' edited "an edited surface file not refused"
  sm_mutant sm-l1-ok-not-skip "printf 'SKIP SMOKE-SURFACE (undeclared: no %s at %s)" "printf 'SMOKE OK (undeclared: no %s at %s)" absent "L1: an absent surface prints SMOKE OK instead of SKIP"
  sm_mutant sm-no-none 'if [ "$lglobs" = none ]; then' 'if false; then' none "a declared none read as a pathspec"
  sm_mutant sm-none-case 'lglobs="$(tr '"'"'[:upper:]'"'"' '"'"'[:lower:]'"'"' <<<"$globs")"' 'lglobs="$globs"' cnone "a capitalised None left uncased reaches the matches-nothing guard and refuses smoke-surface-unevaluable"
  # The two unevaluable guards each have a subject the other cannot reach: a rejected line still lists
  # nothing, so with the rc guard off magic refuses through the matches-nothing guard WITHOUT the R flag;
  # `none.` passes git and lists nothing, so only the matches-nothing guard refuses it.
  sm_mutant sm-pathspec-rc 'if [ "$lrc" -ne 0 ]; then' 'if false; then' magic "a surface line git rejects not refused as a rejected pathspec"
  sm_mutant sm-surface-matches-nothing 'if [ -z "$lst$flst" ]; then' 'if false; then' nonedot "a surface matching no path at base or frozen (none.) read as no surface change, so SMOKE OK"
  # The matches-nothing guard lists <frozen> too: without that listing a surface naming a directory the story
  # creates (green: web/app/**) refuses. typo (matches nothing at either sha) is the near-miss that still refuses.
  sm_mutant sm-surface-base-only ''"'"'; SD "$et" "$sf" -- $globs 2>/dev/null)"; frc=$?' ''"'"'; :)"; frc=$?' green "the matches-nothing guard lists only <base>, so a greenfield surface the story creates refuses"
  # A listing failure whose pathspecs parse over <empty tree>..<empty tree> failed on an object: UNEVALUABLE, not a rejected pathspec.
  sm_mutant sm-listing-any-fail-rejected ''"'"'; SD "$et" "$et" -- $globs >/dev/null 2>&1); then' ''"'"'; false); then' corrupt "a corrupt base tree reported as a rejected surface pathspec"
  # Nothing refused and the range diff fails: --smoke exits 2 (brk0 is the broken world without the m1 token).
  sm_mutant sm-smoke-uneval-swallowed '|| exit 2 # smoke mode' '|| : # smoke mode' brk0 "--smoke: an unevaluable range diff with nothing refused falls through to smoke OK"
  sm_mutant sm-uneval-exit2 '(exit $lrc); correct the line outside the story'"'"'s range"; return 0' '(exit $lrc); correct the line outside the story'"'"'s range"; refused=0; return 2' magic "a rejected surface line exits 2 unrefused, which every caller reads as nothing checked"
  sm_mutant sm-smoke-uneval-outranks 'smoke_arms "$BASE" "$FROZEN" "$STORY" || [ "$refused" -eq 1 ] || exit 2 # smoke mode' 'smoke_arms "$BASE" "$FROZEN" "$STORY" || exit 2 # smoke mode' broken "--smoke: an unevaluable range diff after an m1 refusal exits 2, so the refusal does not block"
  sm_mutant sm-hand-uneval-outranks 'smoke_arms "$BASE" "$FROZEN" "$STORY" || [ "$refused" -eq 1 ] || exit 2 # handoff mode' 'smoke_arms "$BASE" "$FROZEN" "$STORY" || exit 2 # handoff mode' handbrk "handoff: an unevaluable smoke arm after a refusal exits 2, so the refusal does not block dispatch"
  sm_mutant sm-diff-cwd 'SD() { git -C "$TOP" diff' 'SD() { git -C "$REPO" diff' sub "-C <subdirectory> re-roots the smoke pathspecs, so the range is acquitted"
  sm_mutant sm-no-empty "if [ -z \"\$globs\" ]; then printf 'SKIP SMOKE-SURFACE (empty" "if false; then printf 'SKIP SMOKE-SURFACE (empty" empty "an empty surface read as the whole diff"
  sm_mutant sm-handoff-unwired 'smoke_arms "$BASE" "$FROZEN" "$STORY" || [ "$refused" -eq 1 ] || exit 2 # handoff mode' ': # handoff mode' hand "handoff mode does not run the smoke arms"
  sm_mutant sm-exclglob-lost '"$sb" "$sf" -- $globs 2>/dev/null)"' '"$sb" "$sf" -- $(grep -v '"'"'^:(exclude,glob)'"'"' <<<"$globs") 2>/dev/null)"' exclglob "a glob-magic exclude line dropped from the (m2) diff, so a top-level test-only change refuses"
  if [ -d "$WORK/sm-worlds.snap/cnone/.git" ] && [ -d "$WORK/sm-worlds.snap/magic/.git" ] && [ -d "$WORK/sm-worlds.snap/edited/web" ] \
    && [ -d "$WORK/sm-worlds.snap/broken/.git" ] && [ -d "$WORK/sm-worlds.snap/nonedot/.git" ] \
    && [ -d "$WORK/sm-worlds.snap/brk0/.git" ] && [ -d "$WORK/sm-worlds.snap/green/web/app" ] && [ -d "$WORK/sm-worlds.snap/corrupt/.git" ] \
    && diff -r "$WORK/sm-worlds.snap" "$SMW" >/dev/null 2>&1; then
    ok "BL-845 SMOKE WORLDS: seeded once (the cnone, magic, edited/web, broken, nonedot, brk0, green/web/app and corrupt worlds among them) and byte-identical after every mutant call (diff -r against the post-seed copy)"
  else
    bad "BL-845 SMOKE WORLDS: the worlds changed across the mutant calls or were never snapshotted -- the reuse is unsafe and every cell above is suspect"
  fi
  # --- end BL-845 SMOKE ARMS --------------------------------------------------------------------------

  # --- BL-833 RED LINE (rv_*) -----------------------------------------------------------------------
  # One world, one validator call per program, read per cell by token: rv_block in world.sh, whose header
  # carries the cells, the mutants and the BL-834 invocation count.
  rv_block
  # --- end BL-833 RED LINE --------------------------------------------------------------------------

  # --- BL-843 CAPTURE-HEADS BLOCK (b43_*) -----------------------------------------------------------
  # --render-dar, --check and the (o) fold. receipt-bl843.sh owns the worlds and the cells (its header
  # lists them: ctl r1-r9, esc, cmd, d3, cnt and its near-misses cntnb/cntpl, rp, trim, und). Every mutant is
  # written beside record-only-diff.sh in the control tree and must FAIL its own named cell and leave
  # the ctl cell (a story citing nothing renders the two markers, --check 0) standing.
  b43_run() { rcpt_run "$WORK/rw-bl843" "$DIR/receipt-bl843.sh" "$1" "${2:-}" 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell (plus ctl)
  b43_out="$(b43_run "$HECTL")"; b43_rc=$?
  if [ "$b43_rc" -eq 0 ]; then ok "CAPTURE-HEADS: --render-dar renders each capture's head (+dirty kept, the replay block's own), its (a)-arm command (a backtick in a double-backtick span) and the full-collection capture's last count only; --check accepts the pasted block, refuses one retyped head stale, a missing block (post-epoch) and two blocks; a pre-epoch or undecidable story WARNs; the block's own paths are never citations; counts: capture-heads block is a run only with a fresh counted block"; B_b43=1
  else bad "CAPTURE-HEADS: receipt-bl843.sh exited $b43_rc on the shipped validator: $(tr '\n' ' ' <<<"$b43_out")"; fi
  b43_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
    local m o mrc
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
    o="$(b43_run "$m" "$4")"; mrc=$?
    if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
    elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the no-capture control cell -- $5"
    elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then mutant_killed "${B_b43:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
    else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
  }
  b43_mutant b43-path-only 'if (a != r) {' 'if (substr(a, 1, index(a, " — ")) != substr(r, 1, index(r, " — "))) {' r2 "--check compares only the path column, so a retyped head passes"
  b43_mutant b43-legacy-any '    if [ "$DL" = bind ]; then refuse "$DAR_MSG"' '    if false; then refuse "$DAR_MSG"' r3 "the legacy exemption accepts any story with no block"
  b43_mutant b43-und-binds '  DL=undecidable; DL_WHY=""' '  DL=bind; DL_WHY=""' und "an undecidable epoch refuses instead of warning"
  b43_mutant b43-never-ok '  DAR_STATE=ok' '  DAR_STATE=stale; DAR_MSG="dar-heads-stale $STORY: forced"' r1 "a byte-identical block refused stale"
  b43_mutant b43-dup-3 'if [ "${nb:-0}" -ge 2 ]; then' 'if [ "${nb:-0}" -ge 3 ]; then' r5 "two blocks are not a duplicate"
  b43_mutant b43-no-strip 'dar_strip() { LC_ALL=C awk "$DAR_STRIP_AWK"; }' 'dar_strip() { cat; }' r8 "the block region is not stripped before cap_tokens, so its own paths are citations"
  b43_mutant b43-no-dirty '  case "$h" in *"(+dirty)") CH_DIRTY=1 ;; esac' '  case "$h" in NEVER-DIRTY) CH_DIRTY=1 ;; esac' r9 "a (+dirty) head renders as clean"
  b43_mutant b43-no-escape "  case \"\$1\" in *'\`'*) printf" '  case "$1" in NEVER-A-BACKTICK) printf' esc "a command holding a backtick renders in a single-backtick span"
  b43_mutant b43-first-dollar 'cmd="$(LC_ALL=C grep -E "$CMD_RE"' "cmd=\"\$(LC_ALL=C grep -E '^\\\$ '" cmd "the rendered command is the first \$ line, not the (a)-arm reader's"
  b43_mutant b43-count-all '      if [ -n "$fcp" ] && grep -qxF -- "$p" <<<"$fcp"; then' '      if true; then' r9 "every capture renders a count, so the uncited dirty capture's 1 passed renders"
  b43_mutant b43-first-count "(passed|failed)([^A-Za-z]|\$)' | tail -n 1)\"" "(passed|failed)([^A-Za-z]|\$)' | head -n 1)\"" d3 "the first count line renders, not the last"
  b43_mutant b43-no-counts '    dar_counts_ok "$fc" || ev_none' '    false || ev_none' cnt "counts: capture-heads block with a fresh counted block is refused full-collection-none"
  b43_mutant b43-counts-stale '  [ "$DAR_STATE" = ok ] && [ "$DAR_NCOUNT" -gt 0 ]' '  true' cntnb "counts: capture-heads block is accepted with no block"
  b43_mutant b43-replay-count '        [ -z "$rl" ] || cnt=""' '        :' rp "a replay capture cited on Full-collection run: renders its count, so its 1 failed is accepted as the run"
  b43_mutant b43-no-cmd-trim '      cmd="${cmd%"${cmd##*[![:space:]]}"}"' '      :' trim "the rendered command keeps its trailing blanks"
  b43_mutant b43-counts-nophrase '  case "$1" in *"counts: capture-heads block"*) ;; *) return 1 ;; esac' '  :' cntpl "a bare capture path is accepted as a run whenever a fresh block exists"
  # --- end BL-843 CAPTURE-HEADS BLOCK -----------------------------------------------------------------
fi

# --- B3: the gate-2 handoff preflight is wired -----------------------------------------------------
# implementation.md must carry, on some line, the EXACT go-signal invocation of handoff mode, which
# Rule A's GATE1-SKIP sentence and the preflight before every gate-2 dispatch run. Substring match on
# the line (the prose backticks it). The gate-1 line `... <base> <frozen-sha>` is a near-miss that must
# NOT satisfy it: asserted present and distinct. Absent, this arm FAILS (never green on absence).
B3_LINE='scripts/ai-dlc/validate-handoff-evidence.sh -C <worktree> --gate2 <story-file> <base> <go-signal-sha>'
B3_NEAR='scripts/ai-dlc/validate-handoff-evidence.sh -C <worktree> <story-file> <base> <frozen-sha>'
b3_has() { grep -qF -- "$B3_LINE" "$1"; }
if ! grep -qF -- "$B3_NEAR" "$IMP"; then
  bad "B3: FIXTURE BROKEN -- the gate-1 near-miss line is absent from implementation.md, so the arm cannot show it discriminates"
elif b3_has "$IMP"; then
  ok "B3: implementation.md runs handoff mode at the go-signal sha before gate 2 ($B3_LINE); the gate-1 <frozen-sha> line alone does not satisfy it"; B_b3=1
else
  bad "B3: implementation.md carries no line naming '$B3_LINE' (the GATE1-SKIP and gate-2 preflight handoff call); the gate-1 <frozen-sha> line does not count"
fi
if [ "${B_b3:-0}" = 1 ]; then
  awk -v s="$B3_LINE" '{ while ((p = index($0, s))) $0 = substr($0, 1, p - 1) "validate-handoff-evidence.sh <story-file>" substr($0, p + length(s)); print }' "$IMP" > "$WORK/imp-no-b3.md"
  if cmp -s "$IMP" "$WORK/imp-no-b3.md"; then bad "FIXTURE ERROR: mutation 'b3-unwired' matched nothing"
  elif b3_has "$WORK/imp-no-b3.md"; then bad "MUTATION 'b3-unwired' SURVIVED -- implementation.md without the go-signal handoff line"
  else mutant_killed "${B_b3:-0}" b3-unwired "MUTATION 'b3-unwired' killed: implementation.md without the go-signal handoff line fails B3"; fi
fi

# --- BL-808: --list-captures ------------------------------------------------------
# One world, three commits. L1's story cites: cap1 on a RED line AND on a plain line (one row),
# cap2 as `./`, the bare basename cap3.txt (a capture dir's file), and -- each of which must print
# NOTHING although its target is TRACKED -- `../x/y.txt` (a leading `../` climbs above the toplevel), an
# absolute x/y.txt under a directory OUTSIDE the world (an absolute path under the toplevel is BL-815's
# and lists its toplevel spelling, receipt-bl815.sh cell lc), a glob over
# cap4, an elided path to cap6, the bare y.txt (tracked, but x/ is not a capture dir at L1), and the
# untracked evidence/s1/untracked.txt (on disk only). L2 adds a full-path x/y.txt citation (the
# control that x/y.txt is printable at all); the working tree then cites cap5 on disk only, so the
# read at L2 must not print it, and L3 commits that line (the control that cap5 is printable).
# The vector is every cell's exact output; each mutant must move exactly its own lines.
if [ "$WORLDS_OK" -eq 1 ]; then
  LC_W="$WORK/world-listcaps"
  lc_ok=1
  mkdir -p "$LC_W/evidence/s1" "$LC_W/x" "$LC_W/docs/stories" && gitw "$LC_W" init -q || lc_ok=0
  if [ "$lc_ok" -eq 1 ]; then
    for i in 1 2 3 4 5 6; do printf '$ pytest\nline %s\n' "$i" > "$LC_W/evidence/s1/cap$i.txt"; done
    printf 'y\n' > "$LC_W/x/y.txt"
    {
      printf '# Story\n'
      printf 'Evidence: `evidence/s1/cap1.txt` is the RED capture, and ./evidence/s1/cap2.txt the green one.\n'
      printf 'Again, for the record: evidence/s1/cap1.txt\n'
      printf 'Relative: ../x/y.txt\n'
      printf 'Absolute: %s/x/y.txt and /etc/hosts.txt\n' "$WORK/world-listcaps-outside"
      printf 'Bare: cap3.txt and y.txt and nosuch.txt\n'
      printf 'Glob: evidence/s1/cap*.txt\n'
      printf 'Elided: evidence/.../cap6.txt\n'
      printf 'Untracked: evidence/s1/untracked.txt\n'
    } > "$LC_W/docs/stories/s.md"
    gitw "$LC_W" add -A && gitw "$LC_W" commit -qm l1 || lc_ok=0
    printf 'untracked\n' > "$LC_W/evidence/s1/untracked.txt"
    printf 'Tracked: x/y.txt\n' >> "$LC_W/docs/stories/s.md"
    gitw "$LC_W" add docs/stories/s.md && gitw "$LC_W" commit -qm l2 || lc_ok=0
    printf 'Later: evidence/s1/cap5.txt\n' >> "$LC_W/docs/stories/s.md"
    LC1="$(gitw "$LC_W" rev-parse HEAD~1)"; LC2="$(gitw "$LC_W" rev-parse HEAD)"
  fi
  # Seed controls: every must-not-print target is tracked at L1, and untracked.txt is not.
  lc_seed=""
  for p in x/y.txt evidence/s1/cap4.txt evidence/s1/cap5.txt evidence/s1/cap6.txt; do
    gitw "$LC_W" cat-file -e "${LC1:-x}:$p" 2>/dev/null || lc_seed="$lc_seed $p"
  done
  gitw "$LC_W" cat-file -e "${LC1:-x}:evidence/s1/untracked.txt" 2>/dev/null && lc_seed="$lc_seed untracked-is-tracked"
  [ -f "$LC_W/evidence/s1/untracked.txt" ] || lc_seed="$lc_seed untracked-absent"
  if [ "$lc_ok" -ne 1 ] || [ -n "$lc_seed" ]; then
    bad "LIST-CAPTURES: FIXTURE BROKEN -- the world could not be built or cannot express its cases [${lc_seed# }]"
  else
    lc_cell() { # <script> <frozen> -> "rc:<line>,<line>,..."
      local o rc
      o="$(he_run "$1" -C "$LC_W" --list-captures docs/stories/s.md "$2" 2>/dev/null)"; rc=$?
      printf '%s:%s' "$rc" "$(printf '%s\n' "$o" | grep . | tr '\n' ',')"
    }
    lc_vec() { # <script> -> L1 | L2 (disk carries cap5) | L3 (cap5 committed)
      local a b c
      a="$(lc_cell "$1" "$LC1")"; b="$(lc_cell "$1" "$LC2")"
      c="$(lc_cell "$1" "$LC3")"
      printf '%s | %s | %s' "$a" "$b" "$c"
    }
    gitw "$LC_W" add docs/stories/s.md && gitw "$LC_W" commit -qm l3 && LC3="$(gitw "$LC_W" rev-parse HEAD)"
    # After L3 the on-disk story still cites cap5, so the L2 cell reads a disk that names it: only a
    # read AT the ref keeps cap5 out of that cell.
    E='evidence/s1/'
    LCWANT="0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,x/y.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,${E}cap5.txt,x/y.txt,"
    got="$(lc_vec "$HE")"
    if [ "$got" = "$LCWANT" ]; then
      ok "LIST-CAPTURES: the story read AT the ref prints cap1 once (RED and plain citations), cap2 from './', the bare cap3.txt from its capture dir; '../', an outside absolute, glob, elided, untracked and the bare y.txt outside a capture dir print nothing; x/y.txt prints once cited by full path; cap5 cited on disk only is not printed at L2 and is at L3"; B_lc=1
    else
      bad "LIST-CAPTURES: want [$LCWANT] got [$got]"
    fi
    lc_mutant() { # <name> <from> <to> <want> <label>
      local m got
      if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: list-captures mutation '$1' matched nothing"; return; fi
      got="$(lc_vec "$m")"
      if [ "$got" = "$4" ]; then mutant_killed "${B_lc:-0}" "$1" "MUTATION '$1' killed, moving its own lines only: $5"
      elif [ "$got" = "$LCWANT" ]; then bad "MUTATION '$1' SURVIVED -- $5"
      else bad "MUTATION '$1' moved [$got], want [$4] -- the cells are entangled"; fi
    }
    U="${E}untracked.txt,"
    lc_mutant lc-no-tracked 'tracked "$FROZEN" "$p" && printf' 'printf' \
      "0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,$U | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,${U}x/y.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,${E}cap5.txt,${U}x/y.txt," \
      "--list-captures skips the cat-file -e filter, so the untracked citation prints"
    lc_mutant lc-no-bare 'if [ -n "$lc_bare" ] && [ -n "$lc_full" ]; then' 'if false; then' \
      "0:${E}cap1.txt,${E}cap2.txt, | 0:${E}cap1.txt,${E}cap2.txt,x/y.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap5.txt,x/y.txt," \
      "--list-captures drops the bare-basename resolution, so cap3.txt is lost"
  fi
fi

# INPROC: every subject call the cells above made through he-inproc.sh was answered in process. A subject file the
# runner had to hand to the real bash (no source guard) is logged; only the EQUIV arm's CLI rows run bash by design,
# and they do not pass through the runner. Positive conjunct: the log exists, so an unset variable cannot pass.
if [ -f "$UT_FALLBACK_LOG" ] && [ ! -s "$UT_FALLBACK_LOG" ]; then
  ok "INPROC: every validator, record-only-diff.sh and sprint-status.sh call the cells made was answered in process"
else
  bad "INPROC: subject calls ran as processes: $(sort "$UT_FALLBACK_LOG" 2>/dev/null | uniq -c | tr '\n' ' ')"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "story-evidence-scaffold: PASS"
else
  echo "story-evidence-scaffold: FAILED" >&2
fi
exit $rc
