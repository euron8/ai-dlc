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
for v in STS GV DEV QA CR IMP SR HE; do
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
mutant sr-unwired SR '{ gsub(/validate-handoff-evidence\.sh --strategy HEAD/, "a re-read of"); print }' \
  "WIRE-SR:" "sprint-review §4 not running the strategy mode is caught"

# --- validate-handoff-evidence.sh, driven ---------------------------------------
# Seeded git worlds. CLEAN carries every near-miss: a gitignored full-suite capture cited
# without RED words (not refused by (b)), a `test-results/**` subtree and a `/api/x/{id}`
# route (not refused by (c)), a modified `tools/requirements.txt` cited by path with no
# command line (not a capture), a capture whose `head:` is the base sha (a WARN, exit 0),
# a bare `test_new` test row and an off-vocabulary `manual` row (not refused by (d)/(e)).
# Each offender world is CLEAN plus one commit carrying exactly one defect.
gitw() { local d="$1"; shift; GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  git -C "$d" -c user.name=fx -c user.email=fx@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
STORY=stories/story-1.md
build_world() { # <dir> <variant>
  local w="$1" v="$2" b
  mkdir -p "$w/tests" "$w/test-results" "$w/stories" "$w/tools" || return 2
  gitw "$w" init -q || return 2
  printf 'test-results/\n' > "$w/.gitignore"
  printf 'class TestA:\n    def test_new(self):\n        assert True\n' > "$w/tests/test_x.py"
  printf 'pytest\n' > "$w/tools/requirements.txt"
  printf '# Story 1\n' > "$w/$STORY"
  gitw "$w" add -A && gitw "$w" commit -qm base || return 2
  b="$(gitw "$w" rev-parse HEAD)"
  printf 'class TestA:\n    def test_new(self):\n        assert 1 == 1\n' > "$w/tests/test_x.py"
  printf 'pytest\npytest-xdist\n' > "$w/tools/requirements.txt"
  printf '$ pytest -q\n# cwd: /w  head: %s\n1 passed\n' "$b" > "$w/test-results/full.txt"
  printf 'mutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\nPROVEN: x\n' "$b" > "$w/test-results/red-guard.txt"
  printf '1 passed\n' > "$w/test-results/full-suite.txt"
  cat > "$w/$STORY" <<'EOS'
# Story 1

## Dev Agent Record

Full-collection run: `test-results/full.txt` (1 passed).
Mutation self-check: PROVEN, capture `test-results/red-guard.txt`.
A local re-run sits in `test-results/full-suite.txt` (gitignored, not committed).
Dependencies pinned in `tools/requirements.txt`.
Every capture lives under `test-results/**`; the route under test is `/api/x/{id}`.

## Strategy Test IDs

| Strategy id | Case | Kind | Resolves to |
|---|---|---|---|
| TS-1-01 | a | test | `tests/test_x.py::TestA::test_new` |
| TS-1-01 | b | test | test_new |
| TS-1-02 | - | manual | operator reads the dashboard |
EOS
  gitw "$w" add -A && gitw "$w" add -f test-results/full.txt test-results/red-guard.txt \
    && gitw "$w" commit -qm work || return 2
  case "$v" in
    clean) ;;
    nocmd) printf '1 passed\n' > "$w/test-results/nocmd.txt"
           printf 'Smoke run: `test-results/nocmd.txt`.\n' >> "$w/$STORY"
           gitw "$w" add -f test-results/nocmd.txt ;;
    redun) printf 'mutation-red replay\n' > "$w/test-results/red-extra.txt"
           printf 'Mutation-RED capture: `test-results/red-extra.txt`.\n' >> "$w/$STORY" ;;
    glob)  printf 'Mutation REDs: `test-results/red-*.txt`.\n' >> "$w/$STORY" ;;
    empty) printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    rename|rebind)
           printf 'class TestA:\n    def test_renamed(self):\n        assert 1 == 1\n' > "$w/tests/test_x.py"
           [ "$v" = rebind ] && sed 's/TestA::test_new`/TestA::test_renamed`/' "$w/$STORY" > "$w/.s" && mv "$w/.s" "$w/$STORY" ;;
    movefile) gitw "$w" mv tests/test_x.py tests/test_y.py || return 2 ;;
    *) return 2 ;;
  esac
  gitw "$w" add -A && gitw "$w" commit -qm "$v" --allow-empty || return 2
  printf '%s\n' "$b" > "$w/.B"; gitw "$w" rev-parse HEAD > "$w/.T"
}
# verdict <script> <world> <mode> -> "<rc>:<sorted refusal kinds>[:W]"
verdict() {
  local s="$1" w="$2" m="$3" o rc k
  if [ "$m" = s ]; then o="$(bash "$s" -C "$w" --strategy "$(cat "$w/.T")" "$STORY" 2>&1)"; rc=$?
  else o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>&1)"; rc=$?; fi
  k="$(awk '/^REFUSED /{print $2}' <<<"$o" | sort | tr '\n' ',')"
  case "$o" in *"WARN head-tree test-results/full.txt"*) k="$k:W" ;; esac
  printf '%s:%s' "$rc" "$k"
}
CASES='clean:h clean:s nocmd:h redun:h glob:h empty:s rename:s rebind:s movefile:s'
WANT='0::W 0: 1:no-command,:W 1:red-untracked,:W 1:glob-cited,:W 1:empty-cell, 1:node-missing, 0: 1:node-missing,'
WORLDS_OK=1
for v in clean nocmd redun glob empty rename rebind movefile; do
  build_world "$WORK/world-$v" "$v" || { WORLDS_OK=0; bad "FIXTURE BROKEN: could not seed git world '$v'"; }
done
vector() { # <script> [h|s] -> space-separated verdicts in CASES order
  # With a mode, only that mode's cases run and every other case is reported as its WANT
  # value, so it can never move: a mutant inside one mode's code path cannot reach the
  # other mode's worlds, and running them anyway made this fixture 201s against 16s.
  # Serial on purpose: running the cases concurrently lost reads from the sandbox read-set
  # tracer's stream (73 paths) and the map then OMITTED this fixture.
  local s="$1" only="${2:-}" c out="" i=0
  for c in $CASES; do
    i=$((i+1))
    if [ -n "$only" ] && [ "${c#*:}" != "$only" ]; then
      out="$out $(awk -v n="$i" '{print $n}' <<<"$WANT")"
    else
      out="$out $(verdict "$s" "$WORK/world-${c%%:*}" "${c#*:}")"
    fi
  done
  printf '%s' "${out# }"
}
if [ "$WORLDS_OK" -eq 1 ]; then
  cp "$HE" "$WORK/he-control.sh"
  got="$(vector "$WORK/he-control.sh")"
  if [ "$got" = "$WANT" ]; then
    ok "HANDOFF/STRATEGY: each offender refused by its own arm only (no-command, red-untracked, glob-cited, empty-cell, node-missing); the rename fails then passes after the re-bind; every near-miss quiet; the head WARN exits 0"
  else
    bad "HANDOFF/STRATEGY: verdict vector differs -- want [$WANT] got [$got] for [$CASES]"
  fi
  # he_mutant <name> <from-literal> <to-literal> <case indices (1-based) that must move> <label>
  # An ARM mutant must move only its own offender's case. A NEAR-MISS mutant moves every
  # case of its mode (cases 1 3 4 5 handoff, 2 6 7 8 9 strategy), because every offender world
  # is CLEAN plus one defect and so carries the clean world's near-misses too.
  # The mode a mutant runs is read off its expected cases (2 6 7 8 9 are strategy, 1 3 4 5
  # handoff), so a mutant whose kill lands in the other mode would read SURVIVED, never a
  # false kill.
  he_mutant() {
    local name="$1" from="$2" to="$3" want="$4" label="$5" m="$WORK/he-$1.sh" mv i=0 diffs="" wv wi mode=h
    case " $want " in *" 2 "*|*" 6 "*|*" 7 "*|*" 8 "*|*" 9 "*) mode=s ;; esac
    FROM="$from" TO="$to" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$HE" > "$m"
    if cmp -s "$HE" "$m"; then bad "FIXTURE ERROR: handoff mutation '$name' matched nothing"; return; fi
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
  he_mutant no-arm-c '[ "$hit" -eq 1 ] && refuse "glob-cited' '[ "$hit" -eq 9 ] && refuse "glob-cited' 5 "(c) glob-cited arm removed"
  he_mutant no-arm-d 'if [ -z "$kind" ] || [ -z "$res" ]; then' 'if false; then' 6 "(d) empty-cell arm removed"
  he_mutant no-arm-e 'if ! grep -qE "^[[:space:]]*((async' 'if false && ! grep -qE "^[[:space:]]*((async' 7 "(e) node-missing def lookup removed"
  # The path half of (e): with the tracked-path check gone, a moved test file reads as an
  # empty source, so the def lookup must not be what catches it -- the mutant makes the
  # untracked path fall through to `continue`, and only the movefile case may move.
  he_mutant no-arm-e-path 'if ! tracked "$ref" "$path"; then' 'if ! tracked "$ref" "$path"; then continue; fi; if false; then' 9 "(e) untracked test-file path check removed"
  he_mutant nm-b-any-untracked 'if [ "$isred" -eq 1 ] && ! tracked' 'if ! tracked' '1 3 4 5' "near-miss: an untracked full-suite capture not cited as RED is refused"
  he_mutant nm-no-node '[ -n "$tok" ] || continue' '[ -n "$tok" ] || { refuse "node-missing $story: $id"; continue; }' '2 6 7 8 9' "near-miss: a bare test_* row is refused"
  he_mutant nm-kind-vocab '[ "$kind" = "test" ] || continue' 'case "$kind" in test|predicate|deploy-time) ;; *) refuse "kind $id"; continue ;; esac; [ "$kind" = "test" ] || continue' '2 6 7 8 9' "near-miss: an off-vocabulary Kind is refused"
  he_mutant nm-warn-refuses 'warn "head-tree' 'refuse "head-tree' '1 3 4 5' "near-miss: a head sha that differs from frozen refuses instead of warning"
  he_mutant nm-subtree-glob 'case "$last" in *[!*{},]*) case' 'case "$last" in *) case' '1 3 4 5' "near-miss: a test-results/** subtree is refused as a glob capture"
  he_mutant nm-any-brace '    hit=0' '    hit=0; case "$g" in *"{"*"}"*) hit=1 ;; esac' '1 3 4 5' "near-miss: an /api/x/{id} route is refused as a brace capture"
  he_mutant nm-build-input 'if (b ~ /^(requirements|constraints)' 'if (0 && b ~ /^(requirements|constraints)' '1 3 4 5' "near-miss: a modified requirements.txt is read as a capture"
  set +f
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "story-evidence-scaffold: PASS"
else
  echo "story-evidence-scaffold: FAILED" >&2
fi
exit $rc
