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
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

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
  ok "CONTROL: unmutated copies pass and the keyed sections are non-empty, so a mutant's finding below is the mutation"
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
    ok "MUTATION '$name' killed by its own arm only: $label"
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
  # The SHIPPED validator, in place, beside its real sibling: the control tree above is a copy.
  got="$(verdict "$HE" "$WORK/world-yamlmis" h) $(verdict "$HE" "$WORK/world-noyaml" h)"
  if [ "$got" = "1:status-yaml-mismatch,:W 0::W:S" ]; then
    ok "IN PLACE: the shipped validator reaches its own sprint-status.sh (a row mismatch refuses, a missing yaml prints SKIP STATUS)"
  else
    bad "IN PLACE: the shipped validator did not reach its sibling -- want [1:status-yaml-mismatch,:W 0::W:S] got [$got]"
  fi
  # The range warning: base == frozen and a base that is not an ancestor of frozen each WARN
  # (exit 0, never a refusal); the normal range carries neither. Each mutant silences one.
  range_vec() { # <script> -> "<eq rc>:<eq kinds> <rev rc>:<rev kinds> <normal kinds>"
    local s="$1" w="$WORK/world-clean" o rc a b n
    o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.T")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
    a="$rc:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.T")" "$(cat "$w/.B")" 2>/dev/null)"; rc=$?
    b="$rc:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"
    n="n:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    printf '%s %s %s' "$a" "$b" "$n"
  }
  RWANT='0:range-empty:, 0:range-base:, n:'
  got="$(range_vec "$HECTL")"
  if [ "$got" = "$RWANT" ]; then ok "RANGE: base == frozen and a non-ancestor base each WARN and exit 0; the story's own range warns nothing"
  else bad "RANGE: want [$RWANT] got [$got]"; fi
  range_mutant() { # <name> <from> <to> <want vector> <label>
    local m got
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: range mutation '$1' matched nothing"; return; fi
    got="$(range_vec "$m")"
    if [ "$got" = "$4" ]; then ok "MUTATION '$1' killed, moving its own range cell only: $5"
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
    o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"
    hh="$(awk '$1=="WARN" && $3=="test-results/rp-red-head.txt:"{print $2}' <<<"$o" | tr '\n' ',')"
    hf="$(awk '$1=="WARN" && $3=="test-results/rp-red-fallback.txt:"{print $2}' <<<"$o" | tr '\n' ',')"
    printf '%s %s %s %s head=%s fallback=%s u8=%s' "$(verdict "$s" "$WORK/world-rpfirst" h)" "$(verdict "$s" "$WORK/world-rps319" h)" \
      "$(verdict "$s" "$WORK/world-rpok" h)" "$(verdict "$s" "$WORK/world-rphead" h)" "${hh%,}" "${hf%,}" "$(verdict "$s" "$WORK/world-rpu8" h)"
  }
  RPWANT='1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=1:replay-preamble,:W'
  got="$(rp_vec "$HECTL")"
  if [ "$got" = "$RPWANT" ]; then ok "REPLAY-PREAMBLE: a hand '\$ ' above the script's own refuses (with and without a second '\$ '), a replay at line 1 and the script's '\$ ' right above the replay are accepted, and head: is read from the replay block, falling back to the first head: when the block has none"
  else bad "REPLAY-PREAMBLE: want [$RPWANT] got [$got]"; fi
  rp_mutant() { # <name> <from> <to> <want> <label>
    local m got
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: replay mutation '$1' matched nothing"; return; fi
    got="$(rp_vec "$m")"
    if [ "$got" = "$4" ]; then ok "MUTATION '$1' killed, moving its own cell only: $5"
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
        o="$(bash "$s" -C "${a%%|*}" "${a#*|}" "$(cat "$c/.B")" "$(cat "$c/.T")" 2>/dev/null)"; rc=$?
        out="$out $rc:$(awk '/^REFUSED /{print $2}' <<<"$o" | tr '\n' ',')"
      done
      bash "$s" -C "$c" "stories/../../x.md" "$(cat "$c/.B")" "$(cat "$c/.T")" >/dev/null 2>&1; out="$out climb=$?"
      bash "$s" -C "$ABSW" "$ABSW/lnk/../x.md" "$(cat "$ABSW/.B")" "$(cat "$ABSW/.T")" >/dev/null 2>&1; out="$out lnk=$?"
      bash "$s" -C "$ABSW" --strategy "$(cat "$ABSW/.T")" "$(cd -P "$ABSW" && pwd -P)/$STORY" >/dev/null 2>&1; out="$out sdirty=$?"
      bash "$s" -C "$WORK/world-empty" --strategy "$(cat "$WORK/world-empty/.T")" "$pe/$STORY" >/dev/null 2>&1; out="$out scommit=$?"
      printf '%s' "${out# }"
    }
    ABSWANT='0: 0: 0: 2: climb=2 lnk=2 sdirty=0 scommit=1'
    got="$(abs_vec "$HECTL")"
    if [ "$got" = "$ABSWANT" ]; then ok "ABSOLUTE STORY: an absolute story path, physical or through a symlinked alias, reads as the relative one; a relative climb and a lnk/.. hop out of the tree exit 2 (UNEVALUABLE, no read); strategy mode reads the ref, not the working tree"
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
      if [ "$got" = "$RAWWANT" ]; then ok "MUTATION 'raw-story' killed: the raw path refuses an absolute story as story-untracked, reads both escapes, and reads strategy mode's working tree"
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
        bash "$s" -C "$ABSW" --strategy HEAD stories/untrk.md >/dev/null 2>&1; out="$out out=$?"
        bash "$s" -C "$ABSW" --strategy HEAD "$pa/stories/untrk.md" >/dev/null 2>&1; out="$out outabs=$?"
        bash "$s" -C "$ABSW" --strategy HEAD stories/inlink.md >/dev/null 2>&1; out="$out in=$?"
        bash "$s" -C "$ABSW" --strategy HEAD stories/tlink.md >/dev/null 2>&1; out="$out tracked=$?"
        printf '%s' "${out# }"
      }
      SYMWANT='out=2 outabs=2 in=0 tracked=0'
      got="$(sym_vec "$HECTL")"
      if [ "$got" = "$SYMWANT" ]; then ok "STORY SYMLINK: an untracked story symlinked out of the tree exits 2 (relative and absolute), one symlinked to an in-tree file is read, and a tracked symlink blob reads as its link string"
      else bad "STORY SYMLINK: want [$SYMWANT] got [$got]"; fi
      if ! m="$(mkmut no-story-symlink he 'if [ -L "$TOP/$2" ]; then' 'if false; then')" || [ -z "$m" ]; then
        bad "FIXTURE ERROR: mutation 'no-story-symlink' matched nothing"
      else
        got="$(sym_vec "$m")"
        if [ "$got" = 'out=1 outabs=1 in=0 tracked=0' ]; then ok "MUTATION 'no-story-symlink' killed: without the -L check the outside file is read (empty-cell)"
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
  fc_vec() { # <script>
    local s="$1" o="" v
    for v in fcrec fccode fcbare fcgone dsgone dsbare devold devnew fcevil fcna fctbd fcempty fcnext dsna diskold disknew fcfence fcinvoc fcbold fcnonebt fcmake dsvenv; do o="$o $(verdict "$s" "$WORK/world-$v" h)"; done
    printf '%s' "${o# }"
  }
  got="$(fc_vec "$HECTL")"
  if [ "$got" = "$FCWANT" ]; then ok "RUN-RECORD: a reasoned none over a story+yamls+docs/reviews+test-results diff accepted, over a diff touching a test refused full-collection-none, a bare none refused, a missing line refused, a dependency-setup none with no reason refused, dev.md without the label prescription is LEGACY and with it refuses both missing lines; a .py under test-results/ and a conftest.py under docs/reviews/ make a record diff non-record; N/A, TBD and an empty value over a code diff each refused, an empty value continued by the invocation accepted, a dependency-setup N/A refused; dev.md untracked at <frozen> but on disk keys LEGACY both ways; an empty value over a fenced run and over `- Invocation:` accepted, over a bold label refused; a none carrying a runner span and a two-word span naming no runner refused; a venv interpreter with its packages accepted as a setup"
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
    got="$(fc_vec "$m")"
    if [ "$got" = "$5" ]; then ok "MUTATION '$1' killed, moving its own cells only: $6"
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
  fc_mutant ro-shape-none-last ro '    bash "$0" none-reason "$2" >/dev/null 2>&1; [ $? -eq 2 ] || exit 1' '    :' \
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
      ok "CONVENTIONS: a runner the conventions declare canonical (tox -e all) is accepted at the dev gate, and the same value with no conventions file is refused full-collection-none"
    else bad "CONVENTIONS: want [0:] and [1:full-collection-none,] got [$cv_c] and [$cv_n]"; fi
    if cv_m="$(mkmut fc-no-conv he 'run-shape "$fc" ${ev_conv:+"$ev_conv"}; then' 'run-shape "$fc"; then')" && [ -n "$cv_m" ]; then
      cv_mv="$(verdict "$cv_m" "$WORK/world-fcconv" h)"
      if [ "$cv_mv" = '1:full-collection-none,' ]; then ok "MUTATION 'fc-no-conv' killed: the dev gate dropping the conventions argument refuses fcconv"
      elif [ "$cv_mv" = "$cv_c" ]; then bad "MUTATION 'fc-no-conv' SURVIVED -- the dev gate drops the conventions argument"
      else bad "MUTATION 'fc-no-conv' moved [$cv_mv], want [1:full-collection-none,]"; fi
    else bad "FIXTURE ERROR: mutation 'fc-no-conv' matched nothing"; fi
  else bad "FIXTURE BROKEN: could not seed the conventions worlds"; fi

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
    printf '#!/usr/bin/env bash\nbash "$(dirname "$0")/sprint-status.real.sh" "$@"\necho "sprint-status: synthetic failure after the story line" >&2\nexit %s\n' "$2" > "$d/sprint-status.sh" || return 1
    printf '%s\n' "$v"
  }
  if RC3="$(rc_tree ssrc3 3)" && RC0="$(rc_tree ssrc0 0)"; then
    RCWANT='1:status-not-review,:W:S 1:status-not-review,:W'
    rc_vec() { printf '%s %s' "$(verdict "$1" "$WORK/world-notreview" k)" "$(verdict "$2" "$WORK/world-notreview" k)"; }
    got="$(rc_vec "$RC3" "$RC0")"
    skip_line="$(bash "$RC3" -C "$WORK/world-notreview" "$STORY" "$(cat "$WORK/world-notreview/.B")" "$(cat "$WORK/world-notreview/.T")" 2>/dev/null | grep -c '^SKIP STATUS (implementation-view row .*exited 3: sprint-status: synthetic failure')" || skip_line=0
    if [ "$got" = "$RCWANT" ] && [ "$skip_line" -eq 1 ]; then
      ok "SIBLING EXIT: a sprint-status.sh exiting 3 after its story line still lets (g) refuse status-not-review, and the row half prints one SKIP STATUS naming the exit; the same wrapper at exit 0 prints none"
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
      ok "MUTATION 'skip-on-exit' killed: arm (g) gated on the sibling's exit reads the story line as a SKIP at exit 3 (identity control at exit 0 still refuses)"
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
  cn_run() { bash "$DIR/receipt-bl815.sh" "$1" 2>&1; }
  cn_out="$(cn_run "$HECTL")"; cn_rc=$?
  if [ "$cn_rc" -eq 0 ]; then ok "CAPTURE NORMALISATION: inner ../, absolute and aliased spellings of a tracked capture are judged (no-command), a leading ../ is outside the repository (WARN, or red-untracked when RED), untracked and outside citations WARN capture-unresolved with their reasons, a frozen-.gitignore'd one prints nothing, the exit is unchanged, --list-captures lists the toplevel spellings, and both readers agree on one ./ token"
  else bad "CAPTURE NORMALISATION: receipt-bl815.sh exited $cn_rc on the shipped validator: $(tr '\n' ' ' <<<"$cn_out")"; fi
  cn_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
    local m o rc
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
    o="$(cn_run "$m")"; rc=$?
    if [ "$rc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
    elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the toplevel control cell -- $5"
    elif [ "$rc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then ok "MUTATION '$1' killed by cell $4: $5"
    else bad "MUTATION '$1' SURVIVED (rc=$rc, cell $4 did not fail) -- $5"; fi
  }
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
  b9_run() { bash "$DIR/receipt-bl809.sh" "$1" 2>&1; }
  b9_out="$(b9_run "$HECTL")"; b9_rc=$?
  if [ "$b9_rc" -eq 0 ]; then ok "BL-809 ARMS: an unquoted multi-word -k is REFUSED k-unquoted, quoted and single-word -k are quiet, a <tree> placeholder WARNs without moving the exit, <redacted> and <base-worktree> are quiet"
  else bad "BL-809 ARMS: receipt-bl809.sh exited $b9_rc on the shipped validator: $(tr '\n' ' ' <<<"$b9_out")"; fi
  b9_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
    local m o rc
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
    o="$(b9_run "$m")"; rc=$?
    if [ "$rc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
    elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the no-command control cell -- $5"
    elif [ "$rc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then ok "MUTATION '$1' killed by cell $4: $5"
    else bad "MUTATION '$1' SURVIVED (rc=$rc, cell $4 did not fail) -- $5"; fi
  }
  b9_mutant b9-m1-no-kunq 'if [ -n "$kl" ]; then' 'if false; then' kunq "M1: arm (m) removed, an unquoted multi-word -k passes"
  b9_mutant b9-m2-quoted $'[^[:space:]"\'"\'"\']+[[:space:]]+(or' '[^[:space:]]+[[:space:]]+(or' kq "M2: arm (m) accepts a quoted expression as unquoted"
  b9_mutant b9-m3-no-exempt 'if (p != "<redacted>" && p != "<base-worktree>") print' 'print' red "M3: arm (n)'s <redacted>/<base-worktree> exemptions removed"
  b9_mutant b9-m4-refusal 'warn "placeholder' 'refuse "placeholder' rc "M4: arm (n) made a refusal, so a placeholder moves the exit"
  # --- end BL-809 ARMS ------------------------------------------------------------------------------
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
      o="$(bash "$1" -C "$LC_W" --list-captures docs/stories/s.md "$2" 2>/dev/null)"; rc=$?
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
      ok "LIST-CAPTURES: the story read AT the ref prints cap1 once (RED and plain citations), cap2 from './', the bare cap3.txt from its capture dir; '../', an outside absolute, glob, elided, untracked and the bare y.txt outside a capture dir print nothing; x/y.txt prints once cited by full path; cap5 cited on disk only is not printed at L2 and is at L3"
    else
      bad "LIST-CAPTURES: want [$LCWANT] got [$got]"
    fi
    lc_mutant() { # <name> <from> <to> <want> <label>
      local m got
      if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: list-captures mutation '$1' matched nothing"; return; fi
      got="$(lc_vec "$m")"
      if [ "$got" = "$4" ]; then ok "MUTATION '$1' killed, moving its own lines only: $5"
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

echo
if [ "$rc" -eq 0 ]; then
  echo "story-evidence-scaffold: PASS"
else
  echo "story-evidence-scaffold: FAILED" >&2
fi
exit $rc
