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

locate() { # <core-relative path under core/> -> the first layout that has it
  local rel="$1" cand
  for cand in "$DIR/../../$rel" "$DIR/../../../.claude/$rel"; do
    [ -f "$cand" ] && { printf '%s\n' "$cand"; return 0; }
  done
  return 1
}
STS="$(locate skills/ai-dlc/steps/stories-test-strategy.md)" || STS=""
GV="$(locate skills/ai-dlc/steps/gate-validation.md)" || GV=""
DEV="$(locate team-roles/dev.md)" || DEV=""
QA="$(locate team-roles/qa.md)" || QA=""
CR="$(locate team-roles/code-reviewer.md)" || CR=""
IMP="$(locate skills/ai-dlc/steps/implementation.md)" || IMP=""
SR="$(locate skills/ai-dlc/steps/sprint-review.md)" || SR=""
HE=""
for cand in "$DIR/../../scripts/validate-handoff-evidence.sh" "$DIR/../../../scripts/ai-dlc/validate-handoff-evidence.sh"; do
  [ -f "$cand" ] && { HE="$cand"; break; }
done
# The bookkeeping arms call sprint-status.sh beside the validator, which loads its schema. Both
# are subjects: a mutant tree without them reads every status arm as a SKIP.
SCHEMA="$(locate schemas/sprint-status.json)" || SCHEMA=""
SSH=""
[ -n "$HE" ] && [ -f "$(dirname "$HE")/sprint-status.sh" ] && SSH="$(dirname "$HE")/sprint-status.sh"
for v in STS GV DEV QA CR IMP SR HE SCHEMA SSH; do
  eval "p=\${$v}"
  if [ -z "$p" ]; then
    echo "story-evidence-scaffold: FIXTURE BROKEN -- could not locate subject $v in either layout (core/ or .claude/). An absent subject is not a passing one." >&2
    exit 2
  fi
done

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
# Seeded git worlds. CLEAN carries every near-miss: a gitignored full-suite capture cited
# without RED words (not refused by (b)), a `test-results/local/**` subtree, a `/api/x/{id}`
# route and a `test-results/red-*.txt` glob whose every match is committed (not refused by
# (c)), a `sha=<sha> cmd=<cmd>` capture header (accepted by (a)), a modified
# `tools/requirements.txt` cited by path with no command line (not a capture), a capture
# whose `head:` is the base sha (a WARN, exit 0), a bare `test_new` test row and an
# off-vocabulary `manual` row (not refused by (d)/(e)). The nocmd offender carries `cmd=`
# mid-line, which is not a command header. The glob offender cites `seed{1,2}.txt` with only
# seed1 committed.
# Each offender world is CLEAN plus one commit carrying exactly one defect.
gitw() { local d="$1"; shift; GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  git -C "$d" -c user.name=fx -c user.email=fx@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
STORY=stories/story-1.md
IMPLY_DIR=_bmad-output/implementation-artifacts
PLANY_DIR=_bmad-output/planning-artifacts
ymlw() { # <yaml path> <status> -> one sprint, one story row naming $STORY
  printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1:\n    status: %s\n    file: %s\n' "$2" "$STORY" > "$1"
}
story_awk() { # <world> <awk program> -> rewrite the story in place; 1 when it changed nothing
  awk "$2" "$1/$STORY" > "$1/.s" || return 1
  if cmp -s "$1/.s" "$1/$STORY"; then rm -f "$1/.s"; return 1; fi
  mv "$1/.s" "$1/$STORY"
}
build_world() { # <dir> <variant>
  local w="$1" v="$2" b
  mkdir -p "$w/tests" "$w/test-results" "$w/stories" "$w/tools" || return 2
  gitw "$w" init -q || return 2
  printf 'test-results/\n' > "$w/.gitignore"
  printf 'class TestA:\n    def test_new(self):\n        assert True\n' > "$w/tests/test_x.py"
  printf 'pytest\n' > "$w/tools/requirements.txt"
  # The base commit's story already carries a status, so a range cell whose frozen sha IS the
  # base reads a story the status arms can decide, and the cell stays about its range warning.
  printf -- '---\nstatus: review\n---\n# Story 1\n' > "$w/$STORY"
  gitw "$w" add -A && gitw "$w" commit -qm base || return 2
  b="$(gitw "$w" rev-parse HEAD)"
  printf 'class TestA:\n    def test_new(self):\n        assert 1 == 1\n' > "$w/tests/test_x.py"
  printf 'pytest\npytest-xdist\n' > "$w/tools/requirements.txt"
  printf '$ pytest -q\n# cwd: /w  head: %s\n1 passed\n' "$b" > "$w/test-results/full.txt"
  printf 'mutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\nPROVEN: x\n' "$b" > "$w/test-results/red-guard.txt"
  printf '1 passed\n' > "$w/test-results/full-suite.txt"
  printf 'sha=%s cmd=pytest -q -n auto cwd=/w\n1 passed\n' "$b" > "$w/test-results/p4.txt"
  # The bookkeeping half: the story at `review` in its frontmatter, and its row agreeing in BOTH
  # canonical views, so that a mutant reading the planning view moves only `planlag`.
  if [ "$v" != noyaml ]; then
    mkdir -p "$w/$IMPLY_DIR" "$w/$PLANY_DIR" || return 2
    ymlw "$w/$IMPLY_DIR/sprint-status.yaml" review; ymlw "$w/$PLANY_DIR/sprint-status.yaml" review
  fi
  printf -- '---\nstatus: review\n---\n' > "$w/$STORY"
  cat >> "$w/$STORY" <<'EOS'
# Story 1

## Dev Agent Record

Full-collection run: `test-results/full.txt` (1 passed).
Mutation self-check: PROVEN, capture `test-results/red-guard.txt`.
Parallel run: `test-results/p4.txt`.
A local re-run sits in `test-results/full-suite.txt` (gitignored, not committed).
A scratch re-run sits in `test-results/local/rerun.txt` (gitignored).
Dependencies pinned in `tools/requirements.txt`.
Every capture lives under `test-results/local/**`; the route under test is `/api/x/{id}`.
All committed captures: `test-results/red-*.txt`.

## Production Integrity Tests

None: no production path changed.

## Smoke Test Updates

None.

## Rename Verification

not a rename

## Strategy Test IDs

| Strategy id | Case | Kind | Resolves to |
|---|---|---|---|
| TS-1-01 | a | test | `tests/test_x.py::TestA::test_new` |
| TS-1-01 | b | test | test_new |
| TS-1-02 | - | manual | operator reads the dashboard |
EOS
  gitw "$w" add -A && gitw "$w" add -f test-results/full.txt test-results/red-guard.txt test-results/p4.txt \
    && gitw "$w" commit -qm work || return 2
  case "$v" in
    clean) ;;
    nocmd) printf '1 passed (xdist cmd=auto)\n' > "$w/test-results/nocmd.txt"
           printf 'Smoke run: `test-results/nocmd.txt`.\n' >> "$w/$STORY"
           gitw "$w" add -f test-results/nocmd.txt ;;
    redun) printf 'mutation-red replay\n' > "$w/test-results/red-extra.txt"
           printf 'Mutation-RED capture: `test-results/red-extra.txt`.\n' >> "$w/$STORY" ;;
    glob)  printf '$ pytest --seed 1\nhead: %s\n1 passed\n' "$b" > "$w/test-results/seed1.txt"
           gitw "$w" add -f test-results/seed1.txt || return 2
           printf 'Seeded runs: `test-results/seed{1,2}.txt`.\n' >> "$w/$STORY" ;;
    headeq) w0="$(gitw "$w" rev-parse HEAD)"
           printf '$ pytest -q\nhead: %s\n1 passed\n' "$w0" > "$w/test-results/full.txt"
           printf 'mutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\nPROVEN: x\n' "$w0" > "$w/test-results/red-guard.txt"
           gitw "$w" add -f test-results/full.txt test-results/red-guard.txt || return 2 ;;
    empty) printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    second) printf '| TS-1-05 | c | test | `tests/test_x.py::TestA::test_new`, `tests/test_x.py::TestA::test_gone` |\n' >> "$w/$STORY" ;;
    short) printf '| TS-1-04 | - | test |\n' >> "$w/$STORY" ;;
    shortnores)
           sed 's/^| Strategy id | Case | Kind | Resolves to |$/| Strategy id | Case | Kind | Node |/' "$w/$STORY" > "$w/.s" && mv "$w/.s" "$w/$STORY"
           printf '| TS-1-04 | - | test |\n' >> "$w/$STORY" ;;
    rename|rebind)
           printf 'class TestA:\n    def test_renamed(self):\n        assert 1 == 1\n' > "$w/tests/test_x.py"
           [ "$v" = rebind ] && sed 's/TestA::test_new`/TestA::test_renamed`/' "$w/$STORY" > "$w/.s" && mv "$w/.s" "$w/$STORY" ;;
    movefile) gitw "$w" mv tests/test_x.py tests/test_y.py || return 2 ;;
    noyaml|dirtyyaml) ;;
    notreview) story_awk "$w" '{ sub(/^status: review$/, "status: in-progress"); print }' || return 2
           ymlw "$w/$IMPLY_DIR/sprint-status.yaml" in-progress; ymlw "$w/$PLANY_DIR/sprint-status.yaml" in-progress ;;
    yamlmis) ymlw "$w/$IMPLY_DIR/sprint-status.yaml" ready-for-dev; ymlw "$w/$PLANY_DIR/sprint-status.yaml" ready-for-dev ;;
    planlag) ymlw "$w/$PLANY_DIR/sprint-status.yaml" ready ;;
    demoted) story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "### Smoke Test Updates"); print }' || return 2 ;;
    level1)  story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "# Smoke Test Updates"); print }' || return 2 ;;
    trail)   story_awk "$w" '/^## Rename Verification$/ { print "## Rename Verification (dev)"; print ""; print "### Rename Verification"; next } {print}' || return 2 ;;
    fence)   story_awk "$w" '/^## Production Integrity Tests$/ { print "```"; print "### Production Integrity Tests"; print "```"; next } {print}' || return 2 ;;
    stratrail) story_awk "$w" '{ sub(/^## Strategy Test IDs$/, "## Strategy Test IDs (rev 2)"); print }' || return 2
           printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    crlfstrat) printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY"
           story_awk "$w" '{ print $0 "\r" }' || return 2 ;;
    crlfdemoted) story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "### Smoke Test Updates"); print $0 "\r" }' || return 2 ;;
    latin1yaml) story_awk "$w" '{ sub(/^status: review$/, "status: in-progress"); print }' || return 2
           ymlw "$w/$IMPLY_DIR/sprint-status.yaml" in-progress; ymlw "$w/$PLANY_DIR/sprint-status.yaml" in-progress
           printf '# caf\351 note\n' >> "$w/$IMPLY_DIR/sprint-status.yaml" ;;
    latin1story) printf '\nNotes: caf\351 au lait.\n' >> "$w/$STORY" ;;
    dirtystory) story_awk "$w" '{ sub(/^status: review$/, "status: in-progress"); print }' || return 2
           ymlw "$w/$IMPLY_DIR/sprint-status.yaml" in-progress; ymlw "$w/$PLANY_DIR/sprint-status.yaml" in-progress ;;
    dirtyhead) story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "### Smoke Test Updates"); print }' || return 2 ;;
    nostatus) story_awk "$w" '{ sub(/^status: review$/, "title: story 1"); print }' || return 2 ;;
    mixfence) story_awk "$w" '/^## Smoke Test Updates$/ { print "~~~"; print "```"; print "~~~"; print ""; print "### Smoke Test Updates"; next } {print}' || return 2 ;;
    untracked) gitw "$w" rm -q --cached "$STORY" || return 2
           mkdir -p "$w/.git/info" && printf '%s\n' "$STORY" >> "$w/.git/info/exclude" || return 2 ;;
    latin1strat) printf '| TS-1-06 | - | manual | caf\351 au lait |\n| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    *) return 2 ;;
  esac
  gitw "$w" add -A && gitw "$w" commit -qm "$v" --allow-empty || return 2
  printf '%s\n' "$b" > "$w/.B"; gitw "$w" rev-parse HEAD > "$w/.T"
  [ "$v" = latin1strat ] && [ -n "$UTF8_LOCALE" ] && printf '%s\n' "$UTF8_LOCALE" > "$w/.LC"
  # After the commit: the working tree disagrees, the frozen sha agrees. Read at <frozen>, quiet.
  [ "$v" = dirtyyaml ] && ymlw "$w/$IMPLY_DIR/sprint-status.yaml" done
  # After the commit: the working tree is FIXED and the frozen sha is not. Read at <frozen>, refused.
  if [ "$v" = dirtystory ]; then
    story_awk "$w" '{ sub(/^status: in-progress$/, "status: review"); print }' || return 2
    ymlw "$w/$IMPLY_DIR/sprint-status.yaml" review; ymlw "$w/$PLANY_DIR/sprint-status.yaml" review
  fi
  if [ "$v" = dirtyhead ]; then
    story_awk "$w" '{ sub(/^### Smoke Test Updates$/, "## Smoke Test Updates"); print }' || return 2
  fi
  if [ "$v" = untracked ]; then
    gitw "$w" cat-file -e "HEAD:$STORY" 2>/dev/null && return 2
    [ -f "$w/$STORY" ] || return 2
  fi
  return 0
}
# verdict <script> <world> <mode> -> "<rc>:<sorted refusal kinds>[:W][:E]"
# :W is the head-tree WARN on full.txt; :E is any stderr line other than the script's own
# verdict line (an `awk: newline in string` abort is how the multi-line `-v` defect showed).
verdict() {
  local s="$1" w="$2" m="$3" o rc k e="$WORK/.stderr" lc=""
  # A world carrying `.LC` is driven under that locale: with no locale set (`env -i`, or an
  # inherited C locale) BSD awk never aborts, so a world about the abort must force one itself.
  [ -f "$w/.LC" ] && lc="$(cat "$w/.LC")"
  if [ "$m" = s ]; then o="$(env ${lc:+LC_ALL="$lc"} bash "$s" -C "$w" --strategy "$(cat "$w/.T")" "$STORY" 2>"$e")"; rc=$?
  else o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>"$e")"; rc=$?; fi
  k="$(awk '/^REFUSED /{print $2}' <<<"$o" | sort | tr '\n' ',')"
  case "$o" in *"WARN head-tree test-results/full.txt"*) k="$k:W" ;; esac
  case "$o" in *"SKIP STATUS ("*) k="$k:S" ;; esac
  grep -qv '^validate-handoff-evidence: ' "$e" && k="$k:E"
  printf '%s:%s' "$rc" "$k"
}
# Cases 10-13 are appended so the 1-9 indices every mutant below names stay put, and 14-23 after
# them for the same reason.
# headeq: the captures' head: is the commit that frozen only adds them to, with FOUR captures
# cited, so the head-tree arm must be quiet and stderr empty. second: the first `.py::` token
# of a cell resolves and the second does not. short: a three-cell row under a header that has
# `Resolves to`; shortnores: the same row under a header that does not (not refused).
# The bookkeeping cases, each CLEAN plus one property. Offenders: notreview (story and both rows
# in-progress, so only (g) can fire), yamlmis (story review, rows ready-for-dev), demoted
# (`### Smoke Test Updates` only), level1 (`# Smoke Test Updates` only). Near-misses: noyaml (no
# sprint-status yaml: exit 0 with a SKIP STATUS line, the :S marker), dirtyyaml (the yaml edited
# to `done` in the working tree AFTER the commit; the frozen sha agrees), planlag (the planning
# view at `ready`, the implementation view agreeing), trail (`## Rename Verification (dev)` beside
# a `### Rename Verification`, so the heading is present at level 2 only under the trailing-text
# grammar), fence (`### Production Integrity Tests` only inside a code fence, absent outside), and
# stratrail: strategy mode under `## Strategy Test IDs (rev 2)` with an empty cell, refused only
# when the shared grammar reads a heading with trailing text as the table's heading.
# Cases 24-31, appended for the same reason. crlfstrat: the clean story with CRLF line ends and an
# empty cell, so strategy mode reads the table only if the heading grammar strips the CR.
# crlfdemoted: CRLF with `### Smoke Test Updates`. latin1yaml: a story and rows at in-progress and
# one non-UTF-8 byte in a yaml comment, so status-not-review must not ride on the row half.
# latin1story: a non-UTF-8 byte in the story body, quiet, no SKIP (a Traceback is a SKIP).
# dirtystory and dirtyhead: the defect committed, the working tree fixed after the commit, so only
# a reader of the disk passes them. nostatus: a committed story with no status (status-missing).
# untracked: the story is not tracked at <frozen> and sits on disk (story-untracked).
# mixfence (32): `~~~`, a "```" inside it, `~~~` closing it, then `### Smoke Test Updates`
# OUTSIDE every fence. A toggle on any marker reads the closing `~~~` as an opening and hides it.
# Mode `k` is handoff mode over the bookkeeping worlds. It is its own mode for cost only: an
# evidence-arm mutant runs the evidence worlds, and the bookkeeping worlds report their WANT.
# latin1strat (33): strategy mode over a row carrying one non-UTF-8 byte ABOVE an empty cell, driven
# under a UTF-8 locale (the world's `.LC`), so BSD awk without LC_ALL=C aborts at that row and the
# empty cell below it is never read.
CASES='clean:h clean:s nocmd:h redun:h glob:h empty:s rename:s rebind:s movefile:s headeq:h second:s short:s shortnores:s noyaml:k dirtyyaml:k notreview:k yamlmis:k planlag:k demoted:k level1:k trail:k fence:k stratrail:s crlfstrat:s crlfdemoted:k latin1yaml:k latin1story:k dirtystory:k dirtyhead:k nostatus:k untracked:k mixfence:k latin1strat:s'
WANT='0::W 0: 1:no-command,:W 1:red-untracked,:W 1:glob-cited,:W 1:empty-cell, 1:node-missing, 0: 1:node-missing, 0: 1:node-missing, 1:short-row, 0: 0::W:S 0::W 1:status-not-review,:W 1:status-yaml-mismatch,:W 0::W 1:heading-demoted,:W 1:heading-demoted,:W 0::W 0::W 1:empty-cell, 1:empty-cell, 1:heading-demoted,:W 1:status-not-review,:W 0::W 1:status-not-review,:W 1:heading-demoted,:W 1:status-missing,:W 1:story-untracked,:W 1:heading-demoted,:W 1:empty-cell,'
# Every evidence-handoff case and every strategy case, for the near-miss mutants that move a
# whole mode.
HCASES='1 3 4 5 10'
SCASES='2 6 7 8 9 11 12 13 23 24 33'
KCASES='14 15 16 17 18 19 20 21 22 25 26 27 28 29 30 31 32'
# The UTF-8 locale latin1strat is driven under: the first one in which THIS awk aborts on a
# non-UTF-8 byte. Empty where none does (gawk, mawk, or no UTF-8 locale installed): the abort the
# world is about cannot happen on this host, and its mutant below says so instead of scoring.
UTF8_LOCALE=""
for l in en_US.UTF-8 C.UTF-8; do
  # A regex match, because that is what aborts: a bare record count reads the byte fine.
  if ! LC_ALL="$l" awk '{gsub(/a/, "")} END{print 1}' <<<"$(printf 'caf\351')" >/dev/null 2>&1; then UTF8_LOCALE="$l"; break; fi
done
WORLDS_OK=1
for v in clean nocmd redun glob empty rename rebind movefile headeq second short shortnores noyaml dirtyyaml notreview yamlmis planlag demoted level1 trail fence stratrail crlfstrat crlfdemoted latin1yaml latin1story dirtystory dirtyhead nostatus untracked mixfence latin1strat; do
  build_world "$WORK/world-$v" "$v" || { WORLDS_OK=0; bad "FIXTURE BROKEN: could not seed git world '$v'"; }
done
# A mutant TREE: the whole scripts directory and the schema, laid out so sprint-status.sh finds
# its schema script-relative and its root by its own walk. A lone validator copy finds no
# sibling and turns every status arm into a SKIP, which reads as a kill or a survival for the
# wrong reason. mk_tree <name> -> path of the validator in that tree, sibling asserted present.
mk_tree() {
  local t="$WORK/tree-$1"
  mkdir -p "$t/core/scripts" "$t/core/schemas" "$t/core/skills/ai-dlc" || return 1
  cp -R "$(dirname "$HE")/." "$t/core/scripts/" && cp "$SCHEMA" "$t/core/schemas/sprint-status.json" || return 1
  [ -f "$t/core/scripts/sprint-status.sh" ] && [ -f "$t/core/scripts/validate-handoff-evidence.sh" ] || return 1
  printf '%s\n' "$t/core/scripts/validate-handoff-evidence.sh"
}
vector() { # <script> [h|s] -> space-separated verdicts in CASES order
  # With a mode, only that mode's cases run and every other case is reported as its WANT
  # value, so it can never move: a mutant inside one mode's code path cannot reach the
  # other mode's worlds, and running them anyway made this fixture 201s against 16s.
  # Serial on purpose: running the cases concurrently lost reads from the sandbox read-set
  # tracer's stream (73 paths) and the map then OMITTED this fixture.
  local s="$1" only="${2:-}" c out="" i=0
  for c in $CASES; do
    i=$((i+1))
    if [ -n "$only" ] && case "$only" in *"${c#*:}"*) false ;; *) true ;; esac; then
      out="$out $(awk -v n="$i" '{print $n}' <<<"$WANT")"
    else
      out="$out $(verdict "$s" "$WORK/world-${c%%:*}" "${c#*:}")"
    fi
  done
  printf '%s' "${out# }"
}
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
  # mkmut <name> <he|ss> <from-literal> <to-literal> -> path of the validator to drive, or
  # nothing when the mutation matched nothing. A validator mutant is written INTO the control
  # tree's scripts dir under its own name, so it finds the real sprint-status.sh beside it; a
  # sprint-status.sh mutant gets a tree of its own (mk_tree asserts the sibling is there).
  mkmut() {
    local name="$1" tgt="$2" src m t
    if [ "$tgt" = ss ]; then
      t="$(mk_tree "$name")" || return 1
      src="$SSH"; m="$(dirname "$t")/sprint-status.sh"
    else
      src="$HE"; m="$(dirname "$HECTL")/he-mut-$name.sh"; t="$m"
    fi
    FROM="$3" TO="$4" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$src" > "$m.tmp"
    if cmp -s "$src" "$m.tmp"; then rm -f "$m.tmp"; return 1; fi
    mv "$m.tmp" "$m"
    printf '%s\n' "$t"
  }
  # he_mutant <name> <from-literal> <to-literal> <case indices (1-based) that must move> <label> [ss]
  # An ARM mutant must move only its own offender's case. A NEAR-MISS mutant moves every
  # case of its mode ($HCASES handoff, $SCASES strategy), because every offender world is CLEAN
  # plus one defect and so carries the clean world's near-misses too; one that keys on the
  # head-tree WARN skips 10, whose captures name the tree they ran on. The modes a mutant runs
  # are read off its expected cases (h evidence handoff, k bookkeeping handoff, s strategy; the
  # shared heading grammar moves one k and one s case), so a kill landing in a mode it did not
  # run reads SURVIVED, never a false kill. A sixth argument `ss` mutates sprint-status.sh
  # instead of the validator.
  he_mutant() {
    local name="$1" from="$2" to="$3" want="$4" label="$5" m mv i=0 diffs="" wv wi mode="" x
    for x in $want; do
      case " $SCASES " in *" $x "*) mode="${mode}s" ;; esac
      case " $KCASES " in *" $x "*) mode="${mode}k" ;; esac
      case " $HCASES " in *" $x "*) mode="${mode}h" ;; esac
    done
    if ! m="$(mkmut "$name" "${6:-he}" "$from" "$to")" || [ -z "$m" ]; then
      bad "FIXTURE ERROR: handoff mutation '$name' matched nothing"; return
    fi
    mv="$(vector "$m" "$mode")"
    for wv in $mv; do
      i=$((i+1))
      wi="$(awk -v n="$i" '{print $n}' <<<"$WANT")"
      [ "$wv" = "$wi" ] || diffs="$diffs $i"
    done
    if [ "${diffs# }" = "$want" ]; then ok "MUTATION '$name' killed, moving cases [$want] only: $label"
    elif [ -z "$diffs" ]; then bad "MUTATION '$name' SURVIVED -- $label"
    else bad "MUTATION '$name' moved cases [${diffs# }], want [$want] -- the arms are entangled"; fi
  }
  set -f
  he_mutant no-arm-a "if ! grep -qE '^(\\\$ |" "if false && ! grep -qE '^(\\\$ |" 3 "(a) no-command arm removed"
  he_mutant no-arm-b 'if [ "$isred" -eq 1 ] && ! tracked' 'if false && ! tracked' 4 "(b) red-untracked arm removed"
  he_mutant no-arm-c '[ "$hit" -eq 1 ] && ! glob_resolves' '[ "$hit" -eq 9 ] && ! glob_resolves' 5 "(c) glob-cited arm removed"
  he_mutant nm-glob-all-tracked '    [ "$any" -eq 1 ] || return 1' '    return 1' "$HCASES" "near-miss: a glob whose every match is tracked (test-results/red-*.txt) is refused"
  he_mutant awk-v-caps 'others="$(HE_CAPS="$CAPS" HE_STORY="$STORY" awk '"'"'BEGIN { caps=ENVIRON["HE_CAPS"]; story=ENVIRON["HE_STORY"];' 'others="$(awk -v story="$STORY" -v caps="$CAPS" '"'"'BEGIN {' "$HCASES" "multi-line CAPS passed through awk -v (BSD awk: newline in string) -- stderr is no longer empty"
  he_mutant cmd-unanchored '|^sha=[0-9a-f]{7,40}[[:space:]]+cmd=[^[:space:]]'"'" '|(^|[[:space:]])cmd=[^[:space:]]'"'" 3 "(a) cmd= accepted mid-line with no sha= partner"
  he_mutant cmd-no-sha-form '|^sha=[0-9a-f]{7,40}[[:space:]]+cmd=' '|^NEVERMATCH=' "$HCASES" "near-miss: a sha=<sha> cmd=<cmd> capture header is refused"
  he_mutant no-arm-d 'if [ -z "$kind" ] || [ -z "$res" ]; then' 'if false; then' '6 23 24 33' "(d) empty-cell arm removed"
  he_mutant no-arm-e 'if ! grep -qE "^[[:space:]]*((async' 'if false && ! grep -qE "^[[:space:]]*((async' '7 11' "(e) node-missing def lookup removed"
  he_mutant first-token-only '    done <<<"$toks"' '    done <<<"$(head -n 1 <<<"$toks")"' 11 "(e) only the first .py:: token of a cell read"
  he_mutant no-short-row '      if (n < 4) { if (hasres)' '      if (n < 4) { if (0)' 12 "short-row arm removed"
  he_mutant nm-short-any-header '      if (n < 4) { if (hasres)' '      if (n < 4) { if (1)' 13 "near-miss: a short row under a header without Resolves to is refused"
  # The path half of (e): with the tracked-path check gone, a moved test file reads as an
  # empty source, so the def lookup must not be what catches it -- the mutant makes the
  # untracked path fall through to `continue`, and only the movefile case may move.
  he_mutant no-arm-e-path 'if ! tracked "$ref" "$path"; then' 'if ! tracked "$ref" "$path"; then continue; fi; if false; then' 9 "(e) untracked test-file path check removed"
  he_mutant nm-b-any-untracked 'if [ "$isred" -eq 1 ] && ! tracked' 'if ! tracked' "$HCASES" "near-miss: an untracked full-suite capture not cited as RED is refused"
  he_mutant nm-no-node '[ -n "$toks" ] || continue' '[ -n "$toks" ] || { refuse "node-missing $story: $id"; continue; }' "$SCASES" "near-miss: a bare test_* row is refused"
  he_mutant nm-kind-vocab '[ "$kind" = "test" ] || continue' 'case "$kind" in test|predicate|deploy-time) ;; *) refuse "kind $id"; continue ;; esac; [ "$kind" = "test" ] || continue' "$SCASES" "near-miss: an off-vocabulary Kind is refused"
  he_mutant nm-warn-refuses 'warn "head-tree' 'refuse "head-tree' '1 3 4 5' "near-miss: a head sha that differs from frozen refuses instead of warning"
  he_mutant nm-subtree-glob 'case "$last" in *[!*{},]*) case' 'case "$last" in *) case' "$HCASES" "near-miss: a test-results/local/** subtree is refused as a glob capture"
  he_mutant nm-any-brace '    hit=0' '    hit=0; case "$g" in *"{"*"}"*) hit=1 ;; esac' "$HCASES" "near-miss: an /api/x/{id} route is refused as a brace capture"
  he_mutant nm-build-input 'if (b ~ /^(requirements|constraints)' 'if (0 && b ~ /^(requirements|constraints)' "$HCASES" "near-miss: a modified requirements.txt is read as a capture"
  # The bookkeeping arms, one mutant each, and one per near-miss. An arm mutant moves every world
  # whose only refusal is that arm's: (g) also owns latin1yaml and dirtystory, (i)-deep also owns
  # crlfdemoted, dirtyhead and mixfence. nm-worktree-yaml also moves latin1yaml (a strict read of
  # the disk yaml raises, so the row is a SKIP) and dirtystory (the disk row says review).
  he_mutant no-arm-g '[ "$st_val" = "review" ] || refuse' 'true || refuse' '16 26 28' "(g) status-not-review arm removed"
  he_mutant no-arm-h 'elif [ "$row_val" != "$st_val" ]; then' 'elif false; then' 17 "(h) status-yaml-mismatch arm removed"
  he_mutant no-arm-i-deep 'if (!two[i] && deep[i]) print' 'if (0) print' '19 25 29 32' "(i) heading-demoted arm removed for a deeper heading"
  he_mutant no-arm-i-level1 'if (!two[i] && one[i]) print' 'if (0) print' 20 "(i) heading-demoted arm removed for a level-1 heading"
  he_mutant nm-skip-silent "skip_status() { printf 'SKIP STATUS (%s)\\n' \"\$1\"; }" 'skip_status() { :; }' 14 "near-miss: a world with no yaml passes silently instead of printing SKIP STATUS"
  he_mutant nm-exact-heading 'if (after == "" || after ~ /^[ \t]/) return lvl' 'if (after == "") return lvl' '21 23' "near-miss: a heading with trailing text read as absent, in BOTH the heading arm and strategy mode (one grammar)"
  he_mutant nm-fence-read 'if (fence == "" && m != "") { fence = m; next }' 'if (0) { fence = m; next }' 22 "near-miss: a demoted heading inside a code fence is read"
  he_mutant fence-any-closes 'if (fence != "") { if (m == fence) fence = ""; next }' 'if (fence != "") { if (m != "") fence = ""; next }' 32 "a fence closed by the other marker (a toggle), which hides a demoted heading after a mixed fence"
  he_mutant nm-planning-view 'PRIMARY = "implementation"' 'PRIMARY = "planning"' 18 "near-miss: the lagging planning view is compared instead of the implementation view" ss
  he_mutant nm-worktree-yaml 'text = git("show", "%s:%s" % (full, view_rel)) or ""' 'text = (root / view_rel).read_text()' '15 26 28' "near-miss: the row is read from the working tree, not the frozen sha" ss
  he_mutant nm-worktree-story 'sv, how = story_text_status(git("show", "%s:%s" % (full, story_rel)) or "")' 'sv, how = story_file_status(root / story_rel)' 28 "the story status is read from the working tree, not the frozen sha" ss
  he_mutant nm-worktree-heading 'demoted="$(G show "$FROZEN:$STORY" | LC_ALL=C awk' 'demoted="$(cat "$REPO/$STORY" | LC_ALL=C awk' 29 "the evidence headings are read from the working tree, not the frozen sha"
  he_mutant no-crlf-strip 'sub(/\r$/, "", line)' '' '24 25' "a CRLF heading read with its CR, in BOTH strategy mode and the heading arm (one grammar)"
  he_mutant nm-strict-decode 'return r.stdout.decode("utf-8", errors="replace")' 'return r.stdout.decode("utf-8")' '26 27' "a non-UTF-8 byte in the yaml or the story read strictly (a Traceback, a SKIP)" ss
  if [ -n "$UTF8_LOCALE" ]; then
    he_mutant strat-no-lc-c 'rows="$(LC_ALL=C awk "$HEADING_AWK"' 'rows="$(awk "$HEADING_AWK"' 33 "strategy mode's awk run in the caller's UTF-8 locale ($UTF8_LOCALE): one non-UTF-8 byte aborts it and the empty cell below is never read"
  else
    ok "SKIP strat-no-lc-c: no UTF-8 locale in which this host's awk aborts on a non-UTF-8 byte, so the abort latin1strat guards cannot happen here"
  fi
  he_mutant no-status-missing '*) refuse "status-missing $STORY' '*) skip_status "status-missing $STORY' 30 "a committed story with no status is a SKIP, not a refusal"
  he_mutant no-story-untracked '"not tracked at "*) refuse "story-untracked' '"not tracked at "*) skip_status "story-untracked' 31 "a story not tracked at the frozen sha is a SKIP, not a refusal"
  set +f

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
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "story-evidence-scaffold: PASS"
else
  echo "story-evidence-scaffold: FAILED" >&2
fi
exit $rc
