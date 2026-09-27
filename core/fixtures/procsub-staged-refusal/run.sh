#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# procsub-staged-refusal — a producer that FAILED must refuse, never read as an empty input.
#
# THE DEFECT. `done < <(producer)` and `comm <(a) <(b)` discard the producer's exit status, so a
# failed `find`, `git`, `grep` or `awk` reads as an EMPTY stream and the script reports the verdict
# an empty input earns. Measured at the pinned base below, each by forcing the failure: a retro
# walk that failed read "0 gates declared" (exit 0), a surface walk that failed reported a wired gate
# DORMANT (exit 1), a layer walk that failed read "no match" or "0 error(s)" (exit 0), a failed
# `git ls-files` read "nothing to migrate" (exit 3), an awk that could not segment a story read PASS.
# The fix stages every such producer to a file and reads its status; this fixture forces each failure
# and asserts the REFUSAL.
#
# EVERY FAILURE IS FORCED WITH A PATH STUB, NEVER SAMPLED. A stub claims only the calls its case
# pattern names, fails the Nth of them (0 = every one), logs each claimed call, and hands everything
# else to the real binary. EVERY FORCED ARM ASSERTS ITS STUB FIRED: an arm whose stub nobody called
# asserts nothing about the site, and reads exactly like one that passed. That is not hypothetical --
# the first stub written against retired-tokens.sh never fired.
#
# EVERY FORCED ARM HAS A HEALTHY TWIN: the same seed, no stub, the ordinary verdict. Without it a
# script that refuses EVERYTHING passes every forced arm.
#
# THE ARMS ARE FUNCTIONS OF THE SCRIPT PATH, so each mutant below drives the identical arm against a
# copy that restores the base `<( )` spelling at one site (or drops the status read the fix added),
# and must FAIL the arms it declares while its script's healthy arm still PASSES -- the positive
# conjunct that proves the mutant copy ran at all. Mutants are copies beside their siblings, guarded
# by an exact-once anchor match, `cmp -s` and `bash -n`; one that does not apply is a FAIL, never a
# survivor.
#
# THE SPELLING ARM reads lines ADDED to shipped `core/*.sh` since the pinned base and refuses the
# four respellings that would reintroduce a discarded status. It needs this repository's history;
# where the pin cannot be resolved it prints SKIP, never ok.
#
# FOUR STAGED SCRIPTS CARRY NO FORCED ARM, each for its own reason:
#   validate-spec-join.sh        its staged sites sit on a path that already exits 2, so no verdict moves.
#   sync-transient-ignore.sh     its staged diff is diagnostic output printed after the verdict is decided.
#   ai-dlc-continue.sh           its producers are `printf`, and a failed stage fails OPEN by design.
#   derive-fixture-readsets.sh   it needs root to trace, which a fixture run does not have.
#
# Usage: run.sh [<tree-root>]  -- drive the scripts of another tree (for example an extracted base
#                                 commit). The spelling arm and the mutants run only on this tree.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
OWN="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
TREE="${1:-$OWN}"
TREE="$(cd "$TREE" 2>/dev/null && pwd || true)"
[ -n "$TREE" ] && [ -f "$TREE/core/scripts/validate-ci-gates.sh" ] \
  || { echo "FIXTURE ERROR: no core/scripts/validate-ci-gates.sh under '${1:-$OWN}'" >&2; exit 2; }
SELF_TREE=0; [ "$TREE" = "$OWN" ] && SELF_TREE=1
SC="$TREE/core/scripts"
RC_="$TREE/core/skills/ai-dlc-update/reconcile"
LEX="$TREE/core/skills/ai-dlc/steps/stories-test-strategy.md"
GRAMMAR="$TREE/core/skills/ai-dlc/artifact-path-grammar.md"
LCON="$TREE/core/skills/ai-dlc/layer-contract.yaml"
for _f in "$LEX" "$GRAMMAR" "$LCON" "$RC_/retired-tokens.sh" "$RC_/unregistered-drift.sh"; do
  [ -f "$_f" ] || { echo "FIXTURE ERROR: $_f is missing" >&2; exit 2; }
done
echo "procsub-staged-refusal: subject tree = $TREE"

W="$(mktemp -d "${TMPDIR:-/tmp}/procsub-staged-refusal.XXXXXX")" || { echo "FIXTURE ERROR: mktemp" >&2; exit 2; }
W="$(cd "$W" && pwd)"
trap 'chmod -R u+rwX "$W" 2>/dev/null; rm -rf "$W"' EXIT

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
skip() { printf '  SKIP  %s\n' "$1"; }

gitq() { git -c user.email=f@x -c user.name=fixture -c commit.gpgsign=false "$@"; }

# ------------------------------------------------------------------------------------------------
# THE STUB. mkstub <tool> <case-pattern> <fail-index, 0 = every claimed call> <exit status>
# Sets STUB to a fresh directory holding the stub; claimed calls are logged, one per line, to
# "$STUB/LOG". A fresh directory per call is what makes the index mean "the Nth call of THIS run".
# ------------------------------------------------------------------------------------------------
STUB_N=0
mkstub() {
  local tool="$1" pat="$2" idx="$3" rc="$4" real
  real="$(command -v "$tool")" || { echo "FIXTURE ERROR: $tool is not on PATH" >&2; exit 2; }
  STUB_N=$((STUB_N+1)); STUB="$W/stub.$STUB_N"; mkdir -p "$STUB"; : > "$STUB/LOG"
  {
    printf '#!/bin/sh\n'
    printf 'case "$*" in\n  %s)\n' "$pat"
    printf '    n=$(( $(wc -l < "%s/LOG") + 1 ))\n' "$STUB"
    # ONE LOG LINE PER CALL, whatever the arguments hold: norm_lines' `sed` script spans six
    # lines, and logging it raw made one call count as six.
    printf '    printf "%%s %%s\\n" "$n" "$(printf "%%s" "$*" | tr "\\n" " ")" >> "%s/LOG"\n' "$STUB"
    printf '    if [ %s -eq 0 ] || [ %s -eq "$n" ]; then echo "%s: forced failure" >&2; exit %s; fi ;;\n' \
      "$idx" "$idx" "$tool" "$rc"
    printf 'esac\nexec "%s" "$@"\n' "$real"
  } > "$STUB/$tool"
  chmod +x "$STUB/$tool"
}
fired() { local n; n="$(grep -c . "$STUB/LOG")" || n=0; printf '%s' "$n"; }
# failed_call -- did the stub reach the call it was told to fail?
failed_call() { local idx="$1" n; n="$(fired)"; if [ "$idx" -eq 0 ]; then [ "$n" -gt 0 ]; else [ "$n" -ge "$idx" ]; fi; }

# ================================================================================================
# SEEDS. Every seed is read-only to the arms below, so one seed serves every arm and every mutant.
# ================================================================================================
# --- CI: a retro declaring one gate, a surface that wires it ------------------------------------
CI="$W/ci"; mkdir -p "$CI/docs/retro" "$CI/ci-surface"
printf 'Retro.\n\nAdded CI gate `build` this sprint.\n' > "$CI/docs/retro/s1.md"
printf 'jobs:\n  build:\n    run: make build\n' > "$CI/ci-surface/wf.yml"

# --- RX: an unlabelled extension colliding with installed core's `### 26.` ----------------------
RX="$W/rx"; mkdir -p "$RX/.claude/skills/ai-dlc/steps" "$RX/.claude/skills/ai-dlc/extensions/checks"
printf '# Gate validation (fixture)\n### 26. Core check.\n' > "$RX/.claude/skills/ai-dlc/steps/gate-validation.md"
printf -- '---\nkind: check\nid: mydomain\nhooks: steps/gate-validation.md\n---\n### 26. Ext check.\n' \
  > "$RX/.claude/skills/ai-dlc/extensions/checks/mydomain.md"

# --- RW: a release retiring a rulebook line AND a contract shape; a consumer still carrying both --
RW="$W/rw"; RWD="$RW/dist"; RWC="$RW/consumer"
mkdir -p "$RWD/core/skills/ai-dlc/steps" "$RWD/core/team-roles"
printf '# Demo\n\n## Failure handling\n\n1. Diagnose the failure before doing anything else.\n2. Apply all improvements. Append changelog to the story.\n' \
  > "$RWD/core/skills/ai-dlc/steps/demo.md"
printf '# Role: Architect\n\n**Model.**\n- Personal: `/model claude-fixture-x`\n- `/effort high`\n' > "$RWD/core/team-roles/architect.md"
gitq -C "$RWD" init -q; gitq -C "$RWD" add -A; gitq -C "$RWD" commit -qm base
RW_BASE="$(git -C "$RWD" rev-parse HEAD)"
printf '# Demo\n\n## Failure handling\n\n1. Diagnose the failure before doing anything else.\n2. Dispatch a remediator; the lead owns the disposition.\n' \
  > "$RWD/core/skills/ai-dlc/steps/demo.md"
printf '# Role: Architect\n\n**Model.**\n- Model: `opus`, a key.\n- `/effort high`\n' > "$RWD/core/team-roles/architect.md"
gitq -C "$RWD" add -A; gitq -C "$RWD" commit -qm theirs
RW_THEIRS="$(git -C "$RWD" rev-parse HEAD)"
mkdir -p "$RWC/.claude/skills/ai-dlc/extensions" "$RWC/.claude/skills/ai-dlc/overrides"
printf '# Ext\n\n7. **Apply all improvements. Append changelog to the story.**\n' > "$RWC/.claude/skills/ai-dlc/extensions/restates.md"
printf -- '---\nshadows: team-roles/tea.md#Identity\n---\n- Personal: `/model claude-fixture-x`\n' > "$RWC/.claude/skills/ai-dlc/overrides/roles.md"

# --- TW: one CLASSIFY file whose `$VAR/path` token upstream retired and the consumer still speaks --
TW="$W/tw"; TWD="$TW/dist"; TWC="$TW/consumer"; mkdir -p "$TWD/core/scripts" "$TWC/scripts/ai-dlc"
printf 'CHAN="$ROOT/.chan"\nprintf x >> "$ROOT/.chan"\n' > "$TWD/core/scripts/validate-artifact-budget.sh"
gitq -C "$TWD" init -q; gitq -C "$TWD" add -A; gitq -C "$TWD" commit -qm base
TW_BASE="$(git -C "$TWD" rev-parse HEAD)"
printf 'TMPROOT="$(mktemp -d)"\nCHAN="$TMPROOT/chan"\n' > "$TWD/core/scripts/validate-artifact-budget.sh"
gitq -C "$TWD" add -A; gitq -C "$TWD" commit -qm theirs
TW_THEIRS="$(git -C "$TWD" rev-parse HEAD)"
printf 'CHAN="$ROOT/.chan"\nprintf x >> "$ROOT/.chan"\npool() { :; }\n' > "$TWC/scripts/ai-dlc/validate-artifact-budget.sh"

# --- OW: an override copying a clause upstream rewrote, and one shadowing a file absent at both refs
OW="$W/ow"; OWD="$OW/dist"; OWC="$OW/consumer"; mkdir -p "$OWD/core/skills/ai-dlc/steps"
L_OLD="This is the original clause of the section, which upstream rewrites."
L_KEEP="An unchanged clause that survives across the whole range intact."
L_NEW="This is the rewritten clause that upstream adopted in its place now."
printf '# X\n\n## Sec\n\n%s\n%s\n' "$L_OLD" "$L_KEEP" > "$OWD/core/skills/ai-dlc/steps/x.md"
gitq -C "$OWD" init -q; gitq -C "$OWD" add -A; gitq -C "$OWD" commit -qm base
OW_BASE="$(git -C "$OWD" rev-parse HEAD)"
printf '# X\n\n## Sec\n\n%s\n%s\n' "$L_NEW" "$L_KEEP" > "$OWD/core/skills/ai-dlc/steps/x.md"
gitq -C "$OWD" add -A; gitq -C "$OWD" commit -qm theirs
OW_THEIRS="$(git -C "$OWD" rev-parse HEAD)"
mkdir -p "$OWC/.claude/skills/ai-dlc/overrides"
OW_OVR="$OWC/.claude/skills/ai-dlc/overrides/steps__x.md"
printf -- '---\nshadows: steps/x.md#Sec\nbase_sha: %s\nreason: fixture\n---\n\n## Sec\n\n%s\n%s\n' \
  "$OW_BASE" "$L_OLD" "$L_KEEP" > "$OW_OVR"
OW_ABS="$OWC/.claude/skills/ai-dlc/overrides/steps__absent.md"
printf -- '---\nshadows: steps/absent.md#Sec\nbase_sha: %s\nreason: fixture\n---\n\n## Sec\n\n%s\n' \
  "$OW_BASE" "$L_OLD" > "$OW_ABS"

# --- UW: a consumer's in-place hook hardening that upstream ABSORBED at theirs ------------------
UW="$W/uw"; UWD="$UW/dist"; UWC="$UW/consumer"; mkdir -p "$UWD/core/hooks" "$UWC/.claude/hooks"
UW_HEAD='#!/usr/bin/env bash
# A core hook the consumer hardens in place.
echo "core baseline behaviour, unchanged across the range"'
UW_ADD='GUARD_ANCHOR_ONE="a substantive line the consumer added first"
GUARD_ANCHOR_TWO="a second substantive line the consumer added"
GUARD_ANCHOR_THREE="a third substantive line the consumer added"
GUARD_ANCHOR_FOUR="a fourth substantive line the consumer added"'
printf '%s\n' "$UW_HEAD" > "$UWD/core/hooks/guard.sh"
gitq -C "$UWD" init -q; gitq -C "$UWD" add -A; gitq -C "$UWD" commit -qm base
UW_BASE="$(git -C "$UWD" rev-parse HEAD)"
printf '%s\n# ---- upstreamed ----\n%s\n' "$UW_HEAD" "$UW_ADD" > "$UWD/core/hooks/guard.sh"
gitq -C "$UWD" add -A; gitq -C "$UWD" commit -qm theirs
UW_THEIRS="$(git -C "$UWD" rev-parse HEAD)"
printf '%s\n%s\n' "$UW_HEAD" "$UW_ADD" > "$UWC/.claude/hooks/guard.sh"
gitq -C "$UWC" init -q; gitq -C "$UWC" add -A; gitq -C "$UWC" commit -qm installed

# --- MG: a tracked artifact carrying a sprint token outside the slot -----------------------------
MG="$W/mg"; mkdir -p "$MG/docs/retro"; printf 'retro\n' > "$MG/docs/retro/sprint-301.md"
gitq -C "$MG" init -q; gitq -C "$MG" add -A; gitq -C "$MG" commit -qm seed

# --- AC: a story whose one AC is bounded, and which carries no Acceptance-Criteria label ---------
AC="$W/ac"; mkdir -p "$AC"
printf '# Story\n\n- **AC1 (unit).** returns 3 for input 2.\n' > "$AC/story.md"

# --- LE: a consumer layer with one entry missing its contract receipt (a real E17) ---------------
LE="$W/le"; LES="$LE/.claude/skills/ai-dlc"; mkdir -p "$LES/extensions" "$LES/overrides" "$LES/steps"
cp "$LCON" "$LES/layer-contract.yaml"
cp "$GRAMMAR" "$LES/artifact-path-grammar.md"
LE_CV="$(awk '/^contract_version:/{print $2; exit}' "$LCON")"
printf -- '---\nname: gate-validation\ndescription: fixture\n---\n\n# Catalog\n\n### 12. Core check.\n<!-- CHECK_LOADED: 12 -->\nCore.\n' \
  > "$LES/steps/gate-validation.md"
printf -- '---\nkind: check\nhooks: steps/gate-validation.md\nid: current-a\npush_candidate: false\nconforms_to: %s\n---\n\n### 901. [ext:current-a] Consumer check.\n<!-- CHECK_LOADED: 901 -->\nBody.\n' \
  "$LE_CV" > "$LES/extensions/current-a.md"
printf -- '---\nkind: check\nhooks: steps/gate-validation.md\nid: no-receipt\npush_candidate: false\n---\n\n### 902. [ext:no-receipt] Consumer check.\n<!-- CHECK_LOADED: 902 -->\nBody.\n' \
  > "$LES/extensions/no-receipt.md"
printf -- "---\nshadows: steps/gate-validation.md#12. Core check.\nbase_sha: 0123456789abcdef0123456789abcdef01234567\nreason: fixture\nconforms_to: %s\n---\n\n### 12. Core check.\n\nShadowed.\n" \
  "$LE_CV" > "$LES/overrides/gate-validation__12.md"
gitq -C "$LE" init -q; gitq -C "$LE" add -A; gitq -C "$LE" commit -qm seed

# --- LD: an override whose anchor core declares superseded, carrying 3 lines core never had ------
LD="$W/ld"; LDD="$LD/dist"; LDC="$LD/consumer"
mkdir -p "$LDD/core/skills/ai-dlc/steps" "$LDC/.claude/skills/ai-dlc/overrides"
printf '# Widget\n\n### 3. Widget schema.\n\nCore line one.\nCore line two.\nCore line three.\n\n### 4. Other section.\n\nUntouched.\n' \
  > "$LDD/core/skills/ai-dlc/steps/widget.md"
gitq -C "$LDD" init -q; gitq -C "$LDD" add -A; gitq -C "$LDD" commit -qm base
LD_BASE="$(git -C "$LDD" rev-parse HEAD)"
printf 'contract_version: 13\noverride_supersessions:\n  - shadows: steps/widget.md#3. Widget schema.\n    since_core_version: "9.9.9"\n    reason: core took this paragraph verbatim.\n' \
  > "$LDD/core/skills/ai-dlc/layer-contract.yaml"
gitq -C "$LDD" add -A; gitq -C "$LDD" commit -qm theirs
LD_THEIRS="$(git -C "$LDD" rev-parse HEAD)"
printf -- '---\nshadows: steps/widget.md#3. Widget schema.\nbase_sha: %s\nreason: fixture\nconforms_to: 13\n---\n\n### 3. Widget schema.\n\nCore line one.\nCore line two.\nCore line three.\nConsumer surplus A.\nConsumer surplus B.\nConsumer surplus C.\n' \
  "$LD_BASE" > "$LDC/.claude/skills/ai-dlc/overrides/SUP__surplus.md"
gitq -C "$LDC" init -q; gitq -C "$LDC" add -A; gitq -C "$LDC" commit -qm installed

# --- PB: a project whose service file carries a party-mode provenance block (a real stray) -------
PB="$W/pb"; mkdir -p "$PB/.claude/schemas" "$PB/server" "$PB/docs"
cp "$TREE/core/schemas/provenance-block.json" "$PB/.claude/schemas/provenance-block.json" \
  || { echo "FIXTURE ERROR: no core/schemas/provenance-block.json under $TREE" >&2; exit 2; }
printf '# handler\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-party-mode\ninvoked_at: 2026-07-28T09:00:00Z\nmode: subagent\nSKILL_INVOCATION_PROVENANCE_END -->\n' \
  > "$PB/server/handler.py"
# The near-miss world: the same project plus ONE unreadable file, so a REAL `grep -r` completes its
# walk, lists handler.py, and exits 2. That status must be accepted, not refused.
PBU="$W/pbu"; cp -R "$PB" "$PBU"; printf 'locked\n' > "$PBU/docs/locked.md"; chmod 000 "$PBU/docs/locked.md"
# The designed edge: an unreadable file in a tree where NO file carries the marker. grep exits 2
# with nothing listed -- indistinguishable from a walk that failed -- and the scan refuses.
# THE SCHEMA ITSELF CARRIES THE MARKER, so a project holding `.claude/schemas/provenance-block.json`
# has at least one carrier by construction. This world drops it; the script then resolves its schema
# beside itself (`<scripts>/../schemas/`), which the mutant copies below also provide.
PBZ="$W/pbz"; cp -R "$PB" "$PBZ"; rm -f "$PBZ/server/handler.py" "$PBZ/.claude/schemas/provenance-block.json"
printf 'plain\n' > "$PBZ/server/plain.py"
printf 'locked\n' > "$PBZ/docs/locked.md"; chmod 000 "$PBZ/docs/locked.md"

# --- CV: a three-pass adversarial series that converges ----------------------------------------
CV="$W/cv"; mkdir -p "$CV"
cv_pass() { # cv_pass <n> <crit> <major> <minor> <verdict>
  { printf '# Adversarial review, pass %s\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\n' "$1"
    printf 'skill: ai-dlc-adversary-review\nmode: subagent\nlead_role: research-requirements\n'
    printf 'invoked_at: 2026-07-12T%02d:00:00Z\ntool_use_id: toolu_fixture_pass%s\n' "$1" "$1"
    printf 'findings: %s CRITICAL, %s MAJOR, %s MINOR\nfindings_critical: %s\nfindings_major: %s\nfindings_minor: %s\n' "$2" "$3" "$4" "$2" "$3" "$4"
    printf 'verdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' "$5"
  } > "$CV/s1-adversarial-pass$1.md"
}
cv_pass 1 3 4 2 EXIT_CONDITION_NOT_MET
cv_pass 2 1 2 3 EXIT_CONDITION_NOT_MET
cv_pass 3 0 0 1 EXIT_CONDITION_MET
# Each falling pass had a delegated repair; arm H requires its record.
for _r in 1 2; do
  printf '# Repair record\n\n### F1 — CRITICAL\n- disposition: repaired\n- edit: product-brief.md:42\n- derivation:\n    $ grep -c "load-bearing site" product-brief.md\n    3\n- claim now asserted: all three sites are enumerated\n' \
    > "$CV/s1-brief-repair-p$_r.md"
done

# --- RWL: the RW world whose consumer file carries ONE Latin-1 byte (invalid UTF-8) on line 1 ----
# BSD `sed` under a UTF-8 locale answers such a file with "illegal byte sequence" and exit 1 -- a
# producer failure that needs NO stub, and the one a real consumer reaches by holding one file
# saved in a legacy encoding.
RWL="$W/rwl"; mkdir -p "$RWL/.claude/skills/ai-dlc/extensions"
printf '# Ext caf\351\n\n7. **Apply all improvements. Append changelog to the story.**\n' \
  > "$RWL/.claude/skills/ai-dlc/extensions/restates.md"

# --- LR: a consumer layer whose one extension allocates a Rule AND a section id from core's range --
# Both are E15 findings, and each is harvested by its own function (`defined_rules`,
# `defined_anchors`) whose FIRST stage is the grep the forced arms below fail.
LR="$W/lr"; LRS="$LR/.claude/skills/ai-dlc"; mkdir -p "$LRS/extensions" "$LRS/overrides" "$LRS/steps"
cp "$LCON" "$LRS/layer-contract.yaml"; cp "$GRAMMAR" "$LRS/artifact-path-grammar.md"
printf -- '---\nname: gate-validation\ndescription: fixture\n---\n\n# Catalog\n\n### 12. Core check.\n<!-- CHECK_LOADED: 12 -->\nCore.\n' \
  > "$LRS/steps/gate-validation.md"
printf -- '---\nkind: check\nhooks: steps/gate-validation.md\nid: band-a\npush_candidate: false\nconforms_to: %s\n---\n\n## Rule 30 [ext:band-a] -- Consumer rule.\n\nBody.\n' \
  "$LE_CV" > "$LRS/extensions/band-a.md"
LA="$W/la"; cp -R "$LR" "$LA"; rm -f "$LA/.claude/skills/ai-dlc/extensions/band-a.md"
printf -- '---\nkind: check\nhooks: steps/gate-validation.md\nid: band-b\npush_candidate: false\nconforms_to: %s\n---\n\n### 31. [ext:band-b] Consumer check.\n<!-- CHECK_LOADED: 31 -->\nBody.\n' \
  "$LE_CV" > "$LA/.claude/skills/ai-dlc/extensions/band-b.md"
gitq -C "$LR" init -q; gitq -C "$LR" add -A; gitq -C "$LR" commit -qm seed
gitq -C "$LA" init -q; gitq -C "$LA" add -A; gitq -C "$LA" commit -qm seed

# --- WT: a W12 finding decided by the TAG signal ----------------------------------------------------
# This project's `### 912.` heading carries a provenance token (FX-4417) in a parenthesis; another
# entry's bare `Check 12` sits on a line carrying the same token and no adjacent title. Only the
# tag-join (prov_tokens on the heading, line_tokens on the citing line) can decide it.
WT="$W/wt"; WTS="$WT/.claude/skills/ai-dlc"; mkdir -p "$WTS/extensions" "$WTS/overrides" "$WTS/steps"
cp "$LCON" "$WTS/layer-contract.yaml"; cp "$GRAMMAR" "$WTS/artifact-path-grammar.md"
printf -- '---\nname: gate-validation\ndescription: fixture\n---\n\n# Catalog\n\n### 12. Core check.\n<!-- CHECK_LOADED: 12 -->\nCore.\n' \
  > "$WTS/steps/gate-validation.md"
printf -- '---\nkind: check\nhooks: steps/gate-validation.md\nid: band-t\npush_candidate: false\nconforms_to: %s\n---\n\n### 912. [ext:band-t] Ledger reconciliation (FX-4417).\n<!-- CHECK_LOADED: 912 -->\nBody.\n' \
  "$LE_CV" > "$WTS/extensions/band-t.md"
printf -- '---\nkind: check\nhooks: steps/gate-validation.md\nid: cite-t\npush_candidate: false\nconforms_to: %s\n---\n\n### 913. [ext:cite-t] Another check.\n<!-- CHECK_LOADED: 913 -->\nRun Check 12 before closing FX-4417.\n' \
  "$LE_CV" > "$WTS/extensions/cite-t.md"
gitq -C "$WT" init -q; gitq -C "$WT" add -A; gitq -C "$WT" commit -qm seed

# --- LT: a status token DEFERRED leaves the rulebook AND the one program that emitted it ---------
LT="$W/lt"; LTD="$LT/dist"; LTC="$LT/consumer"
mkdir -p "$LTD/core/skills/ai-dlc/steps" "$LTD/core/scripts" "$LTC/.claude/skills/ai-dlc/extensions"
printf '# Step\n\nMark the story DEFERRED when blocked.\nKeep going.\n' > "$LTD/core/skills/ai-dlc/steps/s.md"
printf '#!/bin/bash\nstatus=DEFERRED\necho "$status"\n' > "$LTD/core/scripts/st.sh"
gitq -C "$LTD" init -q; gitq -C "$LTD" add -A; gitq -C "$LTD" commit -qm base
LT_BASE="$(git -C "$LTD" rev-parse HEAD)"
printf '# Step\n\nMark the story PARKED when blocked.\nKeep going.\n' > "$LTD/core/skills/ai-dlc/steps/s.md"
printf '#!/bin/bash\nstatus=PARKED\necho "$status"\n' > "$LTD/core/scripts/st.sh"
gitq -C "$LTD" add -A; gitq -C "$LTD" commit -qm theirs
LT_THEIRS="$(git -C "$LTD" rev-parse HEAD)"
printf '# Ext\n\nWhen blocked, set DEFERRED and move on.\n' > "$LTC/.claude/skills/ai-dlc/extensions/e.md"

# ================================================================================================
# ARMS. Each takes a script path, returns 0 when the arm's assertion holds, and leaves ARM_WHY.
# ================================================================================================
OUT="$W/out"; ERR="$W/err"

# --- validate-ci-gates ---------------------------------------------------------------------------
ci_run() { # ci_run <script> [stub-dir]
  local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" AI_DLC_PROJECT_ROOT="$CI" AI_DLC_RETRO_DIR="$CI/docs/retro" AI_DLC_CI_SURFACE="$CI/ci-surface" \
    AI_DLC_CI_ALIAS_TABLE="" bash "$1" > "$OUT" 2> "$ERR"
}
arm_ci_healthy() { local rc=0; ci_run "$1" || rc=$?
  ARM_WHY="rc=$rc: $(head -1 "$OUT")"
  [ "$rc" -eq 0 ] && grep -q 'Scanned 1 retros, 1 gates declared, 0 dormant' "$OUT"; }
arm_ci_retro() { local rc=0; mkstub find '*"/docs/retro"*' 0 1; ci_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'retro walk' "$ERR"; }
arm_ci_surface() { local rc=0; mkstub find '*"/ci-surface"*' 0 1; ci_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'enforcement-surface walk' "$ERR" && ! grep -q DORMANT "$ERR"; }

# --- relabel-extension-checks --------------------------------------------------------------------
rx_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"; PATH="$p" bash "$1" "$RX" > "$OUT" 2> "$ERR"; }
arm_rx_healthy() { local rc=0; rx_run "$1" || rc=$?; ARM_WHY="rc=$rc"
  [ "$rc" -eq 1 ] && grep -q '\[ext:mydomain\]' "$OUT"; }
arm_rx_walk() { local rc=0; mkstub find '*"/extensions"*' 0 1; rx_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$OUT")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'did not run' "$ERR"; }

# --- retired-layer-passage / retired-layer-contract ----------------------------------------------
rw_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$RWD" "$RW_BASE" "$RW_THEIRS" "$RWC" > "$OUT" 2> "$ERR"; }
arm_rlp_healthy() { local rc=0; rw_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(tail -1 "$ERR")"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-PASSAGE.*extensions/restates\.md' "$OUT"; }
arm_rlc_healthy() { local rc=0; rw_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(tail -1 "$ERR")"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-CONTRACT.*overrides/roles\.md' "$OUT"; }
arm_rw_walk() { local rc=0; mkstub find '*"/.claude/skills/ai-dlc/"*' 0 1; rw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'layer walk' "$ERR" && [ ! -s "$OUT" ]; }

# --- retired-tokens: the token scan is a grep whose pattern no other program here carries ---------
TOKPAT='*"[A-Za-z0-9._/-]+"*'
tw_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$TWD" "$TW_BASE" "$TW_THEIRS" "$TWC" > "$OUT" 2> "$ERR"; }
arm_rt_healthy() { local rc=0; tw_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(tail -1 "$ERR")"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-CONTRACT-TOKEN.*\$ROOT/\.chan' "$OUT"; }
# rt_arm <index> -- the scans run base, theirs, ours; index picks which one fails (0 = all).
rt_arm() { local rc=0; mkstub grep "$TOKPAT" "$2" 2; tw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR")"
  failed_call "$2" && [ "$rc" -eq 2 ] && grep -q 'token scan' "$ERR" && [ ! -s "$OUT" ]; }
arm_rt_all()   { rt_arm "$1" 0; }
arm_rt_base()  { rt_arm "$1" 1; }
arm_rt_ours()  { rt_arm "$1" 3; }

# --- readopt-override ----------------------------------------------------------------------------
ro_run() { # ro_run <script> <override> [stub-dir]
  local p="$PATH"; [ -n "${3:-}" ] && p="$3:$PATH"
  PATH="$p" bash "$1" "$OWD" "$OW_THEIRS" "$OWC" "$2" --check > "$OUT" 2> "$ERR"; }
arm_ro_healthy() { local rc=0; ro_run "$1" "$OW_OVR" || rc=$?; ARM_WHY="rc=$rc: $(head -1 "$OUT")"
  [ "$rc" -eq 1 ] && grep -q '^STALE-CORE-TEXT' "$OUT" && grep -qF "$L_OLD" "$OUT"; }
# The near-miss for the git arm: a file absent at the ref is git's 128, and stays UNDECIDABLE.
arm_ro_absent() { local rc=0; ro_run "$1" "$OW_ABS" || rc=$?; ARM_WHY="rc=$rc: $(head -1 "$OUT")"
  [ "$rc" -eq 1 ] && grep -q '^UNDECIDABLE' "$OUT"; }
# `sort -u` calls, in order: the stale scan's TO lines (1), then its FROM lines (2). Failing the
# FROM side empties the set whose members could be stale, which is the false-clear direction.
arm_ro_sort() { local rc=0; mkstub sort '"-u"' 2 2; ro_run "$1" "$OW_OVR" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT")"
  failed_call 2 && [ "$rc" -eq 2 ] && grep -q 'did not run to completion' "$ERR" && ! grep -q '^OK' "$OUT"; }
# `git … show` calls, in order: the TO section (1), the TO flat line (2), the FROM section (3).
# 127 is a git that could not be run -- not an absent path, which is 128.
arm_ro_git() { local rc=0; mkstub git '*" show "*' 3 127; ro_run "$1" "$OW_OVR" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT")"
  failed_call 3 && [ "$rc" -eq 2 ] && grep -q 'did not run to completion' "$ERR" && ! grep -q '^OK' "$OUT"; }

# --- unregistered-drift: absorbed_pct's floor filter is the one grep carrying `.{0,24}` ------------
ud_status() { awk -F'\t' '$2=="hooks/guard.sh"{print $1; exit}' "$OUT"; }
ud_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$UWD" "$UW_BASE" "$UWC" "$UW_THEIRS" > "$OUT" 2> "$ERR"; }
arm_ud_healthy() { local rc=0; ud_run "$1" || rc=$?; ARM_WHY="rc=$rc status=$(ud_status)"
  [ "$rc" -eq 0 ] && [ "$(ud_status)" = HARD-CORE-DRIFT-ABSORBED ]; }
arm_ud_absorbed() { local rc=0; mkstub grep '*".{0,24}"*' 0 2; ud_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired) status=$(ud_status)"
  failed_call 0 && [ "$(ud_status)" = HARD-UNREGISTERED-CORE-DRIFT ] \
    && grep -q 'ABSORBED the consumer.s delta could not be measured' "$OUT"; }

# --- migrate-artifact-paths ----------------------------------------------------------------------
mg_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" --root "$MG" --grammar "$GRAMMAR" > "$OUT" 2> "$ERR"; }
arm_mg_healthy() { local rc=0; mg_run "$1" || rc=$?; ARM_WHY="rc=$rc"
  [ "$rc" -eq 0 ] && grep -q 'sprint-301' "$OUT"; }
arm_mg_ls() { local rc=0; mkstub git '"ls-files"*' 0 128; mg_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'ls-files over the scan roots did not run' "$ERR"; }

# --- validate-ac-falsifiability ------------------------------------------------------------------
ac_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" --lexicon-from "$LEX" "$AC/story.md" > "$OUT" 2> "$ERR"; }
arm_ac_healthy() { local rc=0; ac_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(head -1 "$OUT")"
  [ "$rc" -eq 0 ] && grep -q '1 AC block(s)' "$OUT"; }
arm_ac_segment() { local rc=0; mkstub awk '*"AC[0-9]+[a-z]?"*' 0 2; ac_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'segmenting' "$ERR" && ! grep -q PASS "$OUT"; }

# --- validate-layer-entries: `layer_files` is the one find carrying `! -name README.md` -----------
# Its calls, in order: census ext (1) ovr (2); overrides (3); live extensions (4); extensions (5);
# the unchecked all_files pair (6, 7); W9 ext (8) ovr (9); W11 ext (10) ovr (11).
LFPAT='*"README.md"*'
le_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"; PATH="$p" bash "$1" "$LE" > "$OUT" 2> "$ERR"; }
arm_le_healthy() { local rc=0; le_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(grep 'error(s)' "$OUT" | tail -1)"
  [ "$rc" -eq 1 ] && grep -q 'E17' "$OUT" && grep -q 'no-receipt' "$OUT"; }
le_arm() { local rc=0; mkstub find "$LFPAT" "$2" 1; le_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR")"
  failed_call "$2" && [ "$rc" -eq 2 ] && grep -q 'layer walk of .* did not run' "$ERR"; }
arm_le_all()       { le_arm "$1" 0; }
arm_le_census()    { le_arm "$1" 1; }
arm_le_overrides() { le_arm "$1" 3; }
arm_le_live()      { le_arm "$1" 4; }
arm_le_ext()       { le_arm "$1" 5; }
arm_le_w9()        { le_arm "$1" 8; }
arm_le_w11()       { le_arm "$1" 10; }

# --- layer-drift: `layer_files` is its one find carrying `! -name README.md` ----------------------
# Its calls, in order: the overrides walk (1), then the extensions walk (2).
ld_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$LDD" "$LD_BASE" "$LD_THEIRS" "$LDC" > "$OUT" 2> "$ERR"; }
arm_ld_healthy() { local rc=0; ld_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(grep -o 'MEASURED: [^,]*' "$OUT" | head -1)"
  [ "$rc" -eq 0 ] && grep -q '^OVERRIDE-SUPERSEDED.*SUP__surplus\.md' "$OUT" \
    && grep -q '3 of yours appear nowhere in core' "$OUT"; }
arm_ld_walk() { local rc=0; mkstub find "$LFPAT" 1 1; ld_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 1 && [ "$rc" -eq 1 ] && grep -q 'the walk of .*overrides did not run' "$ERR" && [ ! -s "$OUT" ]; }
# sup_measure's pattern file is the `printf … > "$LD_T/sup-core-span"` write inside `$( )`. A PATH
# stub cannot fail a builtin `printf`, so the write is failed by making its target a DIRECTORY: a
# `mktemp` stub creates layer-drift's staging directory with the real mktemp, plants
# `sup-core-span` inside it as a directory, and logs the plant. Only that one call is claimed.
arm_ld_sup() { local rc=0 real
  mkstub mktemp '*"/layer-drift.XXXXXX"*' -1 1
  real="$(command -v mktemp)"
  { printf '#!/bin/sh\ncase "$*" in\n  *"/layer-drift.XXXXXX"*)\n'
    printf '    d="$("%s" "$@")" || exit $?\n' "$real"
    printf '    mkdir "$d/sup-core-span" && echo "planted $d" >> "%s/LOG"\n' "$STUB"
    printf '    printf "%%s\\n" "$d"; exit 0 ;;\n'
    printf 'esac\nexec "%s" "$@"\n' "$real"
  } > "$STUB/mktemp"; chmod +x "$STUB/mktemp"
  ld_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 0 && [ "$rc" -eq 1 ] && grep -q 'surplus measure' "$ERR" && ! grep -q 'appear nowhere in core' "$OUT"; }

# --- validate-provenance-block --strays: the candidate walk is its one `grep -rlI` -----------------
pb_run() { # pb_run <script> <project> [stub-dir]
  local p="$PATH"; [ -n "${3:-}" ] && p="$3:$PATH"
  PATH="$p" AI_DLC_PROJECT_ROOT="$2" AI_DLC_KNOWN_SKILLS_EXT="" bash "$1" --strays > "$OUT" 2> "$ERR"; }
arm_pb_healthy() { local rc=0; pb_run "$1" "$PB" || rc=$?; ARM_WHY="rc=$rc: $(head -1 "$ERR")"
  [ "$rc" -eq 1 ] && grep -q 'STRAY PARTY-MODE PROVENANCE: server/handler.py' "$ERR"; }
# The A3 near-miss: a REAL grep over a tree holding one unreadable file exits 2 WITH the candidate
# listed. Accepted: the stray is still reported, exit 1, never a refusal. The precondition is
# asserted, because as root or on a filesystem with no permission bits the file stays readable and
# this arm would test the healthy path under another name.
arm_pb_unreadable() { local rc=0 g=0
  if cat "$PBU/docs/locked.md" >/dev/null 2>&1; then ARM_WHY="docs/locked.md is still readable after chmod 000, so grep cannot exit 2 here"; return 1; fi
  grep -rlI -- SKILL_INVOCATION_PROVENANCE "$PBU" >/dev/null 2>&1 || g=$?
  pb_run "$1" "$PBU" || rc=$?; ARM_WHY="real grep rc=$g, script rc=$rc: $(head -1 "$ERR")"
  [ "$g" -eq 2 ] && [ "$rc" -eq 1 ] && grep -q 'STRAY PARTY-MODE PROVENANCE: server/handler.py' "$ERR"; }
pb_arm() { local rc=0; mkstub grep '*"-rlI"*' 0 "$2"; pb_run "$1" "$PB" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT")$(head -1 "$ERR")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'candidate walk' "$ERR" && ! grep -q PASS "$OUT"; }
arm_pb_zero() { local rc=0 g=0
  if cat "$PBZ/docs/locked.md" >/dev/null 2>&1; then ARM_WHY="docs/locked.md is still readable after chmod 000"; return 1; fi
  grep -rlI -- SKILL_INVOCATION_PROVENANCE "$PBZ" >/dev/null 2>&1 || g=$?
  pb_run "$1" "$PBZ" || rc=$?; ARM_WHY="real grep rc=$g, script rc=$rc: $(head -1 "$OUT")$(head -1 "$ERR")"
  [ "$g" -eq 2 ] && [ "$rc" -eq 2 ] && grep -q 'candidate walk' "$ERR" && ! grep -q PASS "$OUT"; }
arm_pb_walk2()   { pb_arm "$1" 2; }
arm_pb_walk127() { pb_arm "$1" 127; }

# --- validate-adversarial-convergence: the pass ordering is its one `sort -k1,1n` ------------------
cv_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" --series "$CV/s1-adversarial-pass" > "$OUT" 2> "$ERR"; }
arm_cv_healthy() { local rc=0; cv_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(grep -m1 -E 'FAIL|PASS' "$OUT")"
  [ "$rc" -eq 0 ] && grep -q '3 pass artifact' "$OUT"; }
arm_cv_sort() { local rc=0; mkstub sort '*"-k1,1n"*' 0 2; cv_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT")$(head -1 "$ERR")"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'ordering the passes by number did not run' "$ERR"; }

# ================================================================================================
# A STAGED FUNCTION WHOSE BODY IS A PIPELINE. Staging a producer reads ITS status, and when the
# producer is a function whose body pipes a fallible first stage into a later `grep`, that status
# is not the first stage's: without `pipefail` it is the LAST stage's, and with it a failed first
# stage leaves the later `grep` an EMPTY stream, whose exit 1 is then accepted as "no match". Each
# arm below fails the FIRST stage of one such function and asserts the refusal; each has a healthy
# twin on the same seed.
# ================================================================================================
# --- retired-layer-passage: norm_lines (lib.sh) is `sed … | tr`; this file sets no pipefail ------
# `sed` calls carrying norm_lines' list-marker expression, in order: the retired set (1), then one
# per layer file, overrides/ before extensions/ -- roles.md (2), restates.md (3). Failing 2 is one
# layer read alone; the retired set and the other file still read.
NLPAT="*'s/^[-*+][[:space:]]+//'*"
rwl_run() { # rwl_run <script> <locale> -- the Latin-1 consumer, under LC_ALL=<locale>
  env -u LANG LC_ALL="$2" bash "$1" "$RWD" "$RW_BASE" "$RW_THEIRS" "$RWL" > "$OUT" 2> "$ERR"; }
arm_rlp_norm() { local rc=0; mkstub sed "$NLPAT" 2 1; rw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 2 && [ "$rc" -eq 2 ] && grep -q 'normalising .*roles\.md did not run' "$ERR" && [ ! -s "$OUT" ]; }
# The DELETED-LINE side (call 1). At base it was one pipeline ending in `sort -u`, so a dead
# normalisation read as "this release deleted no comparable line": exit 0, NO layer file opened.
arm_rlp_removed() { local rc=0; mkstub sed "$NLPAT" 1 1; rw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 1 && [ "$rc" -eq 2 ] && grep -q 'normalising the deleted rulebook lines did not run' "$ERR" \
    && [ ! -s "$OUT" ]; }
# The NO-STUB arm. Its precondition is measured outside the subject, in the same invocation: the
# real `sed` must refuse the file under UTF-8 ("illegal byte sequence") and accept it under C. A
# host where that does not hold cannot express the failure, and the arm FAILS rather than passing.
# The caller's locale is UTF-8 and the file still yields its row: the detector compares bytes
# (it exports LC_ALL=C), so the Latin-1 file is READ, not refused. At base it read as "no match".
latin1_pre() { local u=0 c=0
  sed -E 's/[[:space:]]+$//' < "$RWL/.claude/skills/ai-dlc/extensions/restates.md" > /dev/null 2> "$W/l1err" || u=$?
  env -u LANG LC_ALL=C sed -E 's/[[:space:]]+$//' <"$RWL/.claude/skills/ai-dlc/extensions/restates.md" > /dev/null 2>&1 || c=$?
  L1_PRE="utf8-sed rc=$u c-sed rc=$c"
  [ "$u" -ne 0 ] && [ "$c" -eq 0 ] && grep -q 'illegal byte sequence' "$W/l1err"; }
arm_rlp_latin1_c() { local rc=0; rwl_run "$1" C || rc=$?; ARM_WHY="rc=$rc: $(tail -1 "$ERR" | cut -c1-120)"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-PASSAGE.*extensions/restates\.md' "$OUT"; }
arm_rlp_latin1() { local rc=0
  if ! LC_ALL=en_US.UTF-8 latin1_pre; then ARM_WHY="precondition not met on this host ($L1_PRE), so the arm cannot express the failure"; return 1; fi
  rwl_run "$1" en_US.UTF-8 || rc=$?
  ARM_WHY="$L1_PRE; rc=$rc: $(tail -1 "$ERR" | cut -c1-120)"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-PASSAGE.*extensions/restates\.md' "$OUT"; }

# --- readopt-override: section_of (lib.sh) returned `rm`'s status, never span_of's -------------
# `awk` calls carrying span_of's `want=`, in order: the anchor-resolution pair (1, 2), then the
# stale scan's TO section (3)... measured by logging every call. Failing 3 -- the FROM section of
# the superseded-line scan -- emptied the set whose members could be stale: at base the STALE row
# vanished and the run read UNADOPTED only, exit 0.
arm_ro_span() { local rc=0; mkstub awk '*"want="*' 3 2; ro_run "$1" "$OW_OVR" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(head -1 "$OUT" | cut -c1-80)$(tail -1 "$ERR" | cut -c1-80)"
  failed_call 3 && [ "$rc" -eq 2 ] && grep -q 'did not run to completion' "$ERR" \
    && ! grep -qE '^(OK|STALE-CORE-TEXT|UNADOPTED-CORE-TEXT)' "$OUT"; }

# --- validate-layer-entries: defined_rules / defined_anchors open with a `grep -Eho` --------------
lr_run() { # lr_run <script> <world> [stub-dir]
  local p="$PATH"; [ -n "${3:-}" ] && p="$3:$PATH"; PATH="$p" bash "$1" "$2" > "$OUT" 2> "$ERR"; }
arm_lr_healthy() { local rc=0; lr_run "$1" "$LR" || rc=$?; ARM_WHY="rc=$rc: $(grep 'error(s)' "$OUT" | tail -1)"
  [ "$rc" -eq 1 ] && grep -q "E15.*RULE OUT OF BAND.*'Rule 30'" "$OUT"; }
arm_la_healthy() { local rc=0; lr_run "$1" "$LA" || rc=$?; ARM_WHY="rc=$rc: $(grep 'error(s)' "$OUT" | tail -1)"
  [ "$rc" -eq 1 ] && grep -q "E15.*SECTION ID OUT OF BAND.*'31\.'" "$OUT"; }
arm_lr_rules() { local rc=0; mkstub grep '*"-Eho ^#{2,4}[[:space:]]+Rule"*' 0 2; lr_run "$1" "$LR" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(grep 'error(s)' "$OUT" | tail -1)$(tail -1 "$ERR" | cut -c1-100)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'did not run' "$ERR" && ! grep -q ' 0 error(s)' "$OUT"; }
# At base this failure read rc=1 with E16 (an EMPTY resolvability set) -- a finding, not a refusal.
# The arm demands the REFUSAL itself, naming the harvest that died: exit 2, never the E16's exit 1.
# E16's own set is built from an unstaged harvest, so E16 may print before the refusal; the exit
# and the refusal line are the verdict, and the arm reads those.
arm_la_anchors() { local rc=0; mkstub grep '*"-Eho ^#{2,4}[[:space:]]+(Check"*' 0 2; lr_run "$1" "$LA" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(grep 'error(s)' "$OUT" | tail -1)$(tail -1 "$ERR" | cut -c1-100)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q '(defined_anchors) did not run' "$ERR" \
    && ! grep -q ' 0 error(s)' "$OUT"; }

# --- retired-tokens / retired-layer-token: toks / code_toks open with `grep -vE '^[[:space:]]*#'` --
CMTPAT='"-vE ^[[:space:]]*#"'
# rt_cmt <index> -- the comment strip runs base (1), theirs (2), ours (3); 0 = all.
rt_cmt() { local rc=0; mkstub grep "$CMTPAT" "$2" 2; tw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call "$2" && [ "$rc" -eq 2 ] && grep -q 'did not run' "$ERR" && [ ! -s "$OUT" ]; }
arm_rt_cmt_all()  { rt_cmt "$1" 0; }
arm_rt_cmt_ours() { rt_cmt "$1" 3; }
# --- validate-layer-entries W12: prov_tokens / line_tokens were grep pipelines ---------------------
# Measured call order on WT: the bracket harvest `-oE \[…\]|\(…\)` runs once (the 912 heading);
# the token harvest `-oE [A-Za-z0-9]+…` runs twice -- prov_tokens' second stage (1), then
# line_tokens over the citing line (2).
PROVPAT='*"-oE \[[^]]*\]|\([^)]*\)"*'
TOKPAT2='*"-oE [A-Za-z0-9]+(-[A-Za-z0-9]+)*"*'
arm_wt_healthy() { local rc=0; lr_run "$1" "$WT" || rc=$?; ARM_WHY="rc=$rc: $(grep -c W12 "$OUT") W12 row(s)"
  [ "$rc" -eq 0 ] && grep -q 'W12.*cite-t\.md:11: cites "Check 12" on a line carrying FX-4417' "$OUT"; }
arm_wt_prov() { local rc=0; mkstub grep "$PROVPAT" 0 2; lr_run "$1" "$WT" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-110)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'provenance-token read of "912" did not run' "$ERR"; }
arm_wt_line() { local rc=0; mkstub grep "$TOKPAT2" 2 2; lr_run "$1" "$WT" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-110)"
  failed_call 2 && [ "$rc" -eq 2 ] && grep -q 'citing-line token read of .*cite-t\.md:11 did not run' "$ERR"; }

# --- retired-layer-contract: shapes_of / tokens_of were `{ grep … || true; }` pipelines -----------
# Each harvest runs over the rulebook at base (1, 2), at theirs (3, 4), then over the layer files,
# overrides/ first: roles.md (5), restates.md (6). Failing 5 is the consumer side alone.
SHPAT='*"-oE -- - [A-Z][A-Za-z-]*: "*'
TKPAT='*"-oE \{[a-z][a-z_]*\}"*'
arm_rlc_shapes() { local rc=0; mkstub grep "$SHPAT" 5 2; rw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-110)"
  failed_call 5 && [ "$rc" -eq 2 ] && grep -q 'shape scan of .*roles\.md did not run' "$ERR" && [ ! -s "$OUT" ]; }
arm_rlc_tokens() { local rc=0; mkstub grep "$TKPAT" 5 2; rw_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-110)"
  failed_call 5 && [ "$rc" -eq 2 ] && grep -q 'token scan of .*roles\.md did not run' "$ERR" && [ ! -s "$OUT" ]; }

# --- layer-drift: sup_measure's count was `… | grep -Fxv -f … | grep -c .` ------------------------
# A `grep -Fxv` that died left `grep -c` reading nothing: "0 of yours appear nowhere in core", the
# measurement telling the operator the action drops nothing. layer-drift's refusal is exit 1.
arm_ld_fxv() { local rc=0; mkstub grep '*"-Fxv -f"*' 0 2; ld_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(grep -o 'and [0-9]* of yours appear nowhere' "$OUT")$(tail -1 "$ERR" | cut -c1-90)"
  failed_call 0 && [ "$rc" -eq 1 ] && grep -q 'surplus measure' "$ERR" && ! grep -q 'appear nowhere in core' "$OUT"; }

lt_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$LTD" "$LT_BASE" "$LT_THEIRS" "$LTC" > "$OUT" 2> "$ERR"; }
arm_rlt_healthy() { local rc=0; lt_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(tail -1 "$ERR" | cut -c1-120)"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-TOKEN.*extensions/e\.md.*DEFERRED' "$OUT"; }
arm_rlt_cmt() { local rc=0; mkstub grep "$CMTPAT" 0 2; lt_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'did not run' "$ERR" && [ ! -s "$OUT" ]; }

# ================================================================================================
# THE ARM TABLE: <arm> <script-path> <description>
# ================================================================================================
S_CI="$SC/validate-ci-gates.sh"; S_RX="$RC_/relabel-extension-checks.sh"
S_RLP="$RC_/retired-layer-passage.sh"; S_RLC="$RC_/retired-layer-contract.sh"
S_RT="$RC_/retired-tokens.sh"; S_RO="$RC_/readopt-override.sh"; S_UD="$RC_/unregistered-drift.sh"
S_MG="$SC/migrate-artifact-paths.sh"; S_AC="$SC/validate-ac-falsifiability.sh"; S_LE="$SC/validate-layer-entries.sh"
S_LD="$RC_/layer-drift.sh"; S_RLT="$RC_/retired-layer-token.sh"; S_PB="$SC/validate-provenance-block.sh"; S_CV="$SC/validate-adversarial-convergence.sh"

run_arm() { # run_arm <fn> <script> <text>
  if "$1" "$2"; then ok "$1: $3"; else bad "$1: $3 -- $ARM_WHY"; fi
}
echo "== healthy twins (same seed, no stub, the ordinary verdict) =="
run_arm arm_ci_healthy  "$S_CI"  "validate-ci-gates reads 1 declared gate, 0 dormant, exit 0"
run_arm arm_rx_healthy  "$S_RX"  "relabel previews the core-number collision, exit 1"
run_arm arm_rlp_healthy "$S_RLP" "retired-layer-passage flags the reproduced deleted line"
run_arm arm_rlc_healthy "$S_RLC" "retired-layer-contract flags the retired contract shape"
run_arm arm_rt_healthy  "$S_RT"  "retired-tokens reports the retired token the consumer speaks"
run_arm arm_ro_healthy  "$S_RO"  "readopt-override --check reads STALE-CORE-TEXT, exit 1"
run_arm arm_ro_absent   "$S_RO"  "readopt-override: an anchor file absent at the ref stays UNDECIDABLE, exit 1"
run_arm arm_ud_healthy  "$S_UD"  "unregistered-drift reads HARD-CORE-DRIFT-ABSORBED"
run_arm arm_mg_healthy  "$S_MG"  "migrate-artifact-paths plans the move, exit 0"
run_arm arm_ac_healthy  "$S_AC"  "validate-ac-falsifiability reads 1 AC block, PASS"
run_arm arm_le_healthy  "$S_LE"  "validate-layer-entries reports the missing receipt (E17), exit 1"
run_arm arm_ld_healthy  "$S_LD"  "layer-drift reports OVERRIDE-SUPERSEDED with a MEASURED surplus of 3, exit 0"
run_arm arm_pb_healthy  "$S_PB"  "validate-provenance-block --strays reports the stray, exit 1"
run_arm arm_pb_unreadable "$S_PB" "--strays: a real grep exiting 2 WITH the stray listed (one unreadable file) is accepted, exit 1"
run_arm arm_pb_zero     "$S_PB"  "--strays: an unreadable file in a tree with ZERO carriers refuses, exit 2 (designed)"
run_arm arm_cv_healthy  "$S_CV"  "validate-adversarial-convergence reads a converged 3-pass series, exit 0"
run_arm arm_rlp_latin1_c "$S_RLP" "retired-layer-passage: the Latin-1 layer file under LC_ALL=C still flags the reproduced line"
run_arm arm_lr_healthy  "$S_LE"  "validate-layer-entries: an extension's 'Rule 30' is E15 RULE OUT OF BAND, exit 1"
run_arm arm_la_healthy  "$S_LE"  "validate-layer-entries: an extension's '### 31.' is E15 SECTION ID OUT OF BAND, exit 1"
run_arm arm_rlt_healthy "$S_RLT" "retired-layer-token reports DEFERRED, retired from the rulebook and its program"
run_arm arm_wt_healthy  "$S_LE"  "validate-layer-entries: a bare 'Check 12' on a line carrying the 912 heading's FX-4417 is W12 by tag"

echo "== forced producer failures (each stub must FIRE, each script must REFUSE) =="
run_arm arm_ci_retro     "$S_CI"  "failed retro walk (find) -> exit 2, not '0 gates declared'"
run_arm arm_ci_surface   "$S_CI"  "failed surface walk (find, inside code_hits' \$( )) -> exit 2, not DORMANT"
run_arm arm_rx_walk      "$S_RX"  "failed extension walk (find) -> exit 2, not 'no collisions'"
run_arm arm_rw_walk      "$S_RLP" "retired-layer-passage: failed layer walk (find) -> exit 2, no rows"
run_arm arm_rw_walk      "$S_RLC" "retired-layer-contract: failed layer walk (find) -> exit 2, no rows"
run_arm arm_rt_all       "$S_RT"  "retired-tokens: every token scan (grep) fails -> exit 2"
run_arm arm_rt_base      "$S_RT"  "retired-tokens: the BASE token scan alone fails -> exit 2 (here-string, not a pipe)"
run_arm arm_rt_ours      "$S_RT"  "retired-tokens: the CONSUMER token scan alone fails -> exit 2, not a lost row"
run_arm arm_ro_sort      "$S_RO"  "readopt-override: the stale scan's FROM set (sort, inside \$( )) fails -> exit 2, not OK"
run_arm arm_ro_git       "$S_RO"  "readopt-override: git show exits 127 in ro_section -> exit 2, not OK"
run_arm arm_ud_absorbed  "$S_UD"  "unregistered-drift: absorbed_pct's line set (grep, inside \$( )) fails -> CLASSIFIER DID NOT RUN"
run_arm arm_mg_ls        "$S_MG"  "migrate-artifact-paths: failed git ls-files -> exit 2, not 'nothing to migrate' (3)"
run_arm arm_ac_segment   "$S_AC"  "validate-ac-falsifiability: failed AC segmentation (awk) -> exit 2, not PASS"
run_arm arm_le_all       "$S_LE"  "validate-layer-entries: every layer walk fails -> exit 2, not '0 error(s)'"
run_arm arm_le_census    "$S_LE"  "validate-layer-entries: the census walk alone fails -> exit 2"
run_arm arm_le_overrides "$S_LE"  "validate-layer-entries: the overrides walk alone fails -> exit 2"
run_arm arm_le_live      "$S_LE"  "validate-layer-entries: the live-extensions walk alone fails -> exit 2"
run_arm arm_le_ext       "$S_LE"  "validate-layer-entries: the extensions walk alone fails -> exit 2"
run_arm arm_le_w9        "$S_LE"  "validate-layer-entries: the W9 walk alone fails -> exit 2"
run_arm arm_le_w11       "$S_LE"  "validate-layer-entries: the W11 walk alone fails -> exit 2"
run_arm arm_ld_walk      "$S_LD"  "layer-drift: the overrides walk (find) fails -> exit 1 refusal, no rows"
run_arm arm_ld_sup       "$S_LD"  "layer-drift: sup_measure's staging write fails inside \$( ) -> exit 1 refusal, no MEASURED row"
run_arm arm_pb_walk2     "$S_PB"  "--strays: the candidate walk (grep -rlI) exits 2 with NO output -> exit 2, not PASS"
run_arm arm_pb_walk127   "$S_PB"  "--strays: the candidate walk (grep -rlI) exits 127 -> exit 2, not PASS"
run_arm arm_cv_sort      "$S_CV"  "validate-adversarial-convergence: the pass ordering (sort) fails -> exit 2, not a judged empty series"

echo "== a staged FUNCTION whose body is a pipeline: its FIRST stage fails =="
run_arm arm_rlp_norm     "$S_RLP" "retired-layer-passage: norm_lines' sed fails on one layer file -> exit 2, not 'no match'"
run_arm arm_rlp_removed  "$S_RLP" "retired-layer-passage: norm_lines' sed fails on the deleted-line set -> exit 2, not 'deleted no line'"
run_arm arm_rlp_latin1   "$S_RLP" "retired-layer-passage: NO STUB, a Latin-1 layer file under a UTF-8 caller is READ and flagged, not 'no match'"
run_arm arm_ro_span      "$S_RO"  "readopt-override: span_of's awk fails inside section_of (FROM section) -> exit 2, not UNADOPTED-only"
run_arm arm_lr_rules     "$S_LE"  "validate-layer-entries: defined_rules' grep exits 2 -> exit 2, not '0 error(s)'"
run_arm arm_la_anchors   "$S_LE"  "validate-layer-entries: defined_anchors' grep exits 2 -> exit 2, not '0 error(s)'"
run_arm arm_rt_cmt_all   "$S_RT"  "retired-tokens: toks' comment strip (grep) exits 2 everywhere -> exit 2, not '0 carrying a token'"
run_arm arm_rt_cmt_ours  "$S_RT"  "retired-tokens: the CONSUMER side's comment strip alone exits 2 -> exit 2, not a lost row"
run_arm arm_rlt_cmt      "$S_RLT" "retired-layer-token: code_toks' comment strip (grep) exits 2 -> exit 2, not 'retired NO status token'"
run_arm arm_wt_prov      "$S_LE"  "validate-layer-entries W12: prov_tokens' bracket harvest (grep) exits 2 -> exit 2, not a withdrawn tag"
run_arm arm_wt_line      "$S_LE"  "validate-layer-entries W12: line_tokens' harvest (grep) exits 2 -> exit 2, not a withdrawn tag"
run_arm arm_rlc_shapes   "$S_RLC" "retired-layer-contract: shapes_of's grep exits 2 on a layer file -> exit 2, not a lost row"
run_arm arm_rlc_tokens   "$S_RLC" "retired-layer-contract: tokens_of's grep exits 2 on a layer file -> exit 2, not a lost row"
run_arm arm_ld_fxv       "$S_LD"  "layer-drift: sup_measure's grep -Fxv exits 2 -> exit 1 refusal, not '0 of yours appear nowhere'"

if [ "$SELF_TREE" -ne 1 ]; then
  skip "spelling arm and mutants -- they run only against this fixture's own tree, not $TREE"
  echo
  if [ "$fails" -eq 0 ]; then echo "procsub-staged-refusal: PASS"; exit 0; fi
  echo "procsub-staged-refusal: $fails assertion(s) FAILED" >&2; exit 1
fi

# ================================================================================================
# THE DIFF-SCOPED SPELLING ARM. Lines ADDED to shipped core/*.sh since the pin must not carry:
#   r1  `done <<< "$(`                 a here-string of a substitution: the producer's status is lost
#   r2  `| while `                     a loop in a pipeline: its refusals end a subshell
#   r3  `> file … || true` / `|| :`    a staging redirect whose failure is folded into success
#   r4  a heredoc whose body line opens with `$(`   the same loss as r1, spelled as a heredoc
# Comment lines are skipped. `2>/dev/null` and `>&N` are removed before r3 is tested, so a
# silenced stderr is not a staging redirect. A QUOTED heredoc delimiter expands nothing and is not r4.
# NO EXEMPTION LIST: a correct site that matches is respelled, never listed.
# ================================================================================================
PIN=e4934e6571b6819c4762d7b9eae56d0d16ca5c55
SPELL_AWK='
  /^\+\+\+ / { next }
  /^@@/ { prev = ""; next }
  /^\+/ {
    l = substr($0, 2)
    if (l ~ /^[[:blank:]]*#/) { prev = ""; next }
    hit = ""
    if (l ~ /done[[:blank:]]*<<<[[:blank:]]*"?\$\(/) hit = "r1"
    else if (l ~ /(^|[^|])\|[[:blank:]]*while[[:blank:]]/) hit = "r2"
    else {
      s = l
      gsub(/[0-9]*>[[:blank:]]*\/dev\/null/, "", s)
      gsub(/>&[0-9]/, "", s)
      if (s ~ />[^|]*\|\|[[:blank:]]*(true|:)([[:blank:]]|;|\)|$)/) hit = "r3"
      else if (l ~ /^\$\(/ && prev ~ /<<-?[A-Za-z_]+[[:blank:]]*$/) hit = "r4"
    }
    if (hit != "") print hit ": " l
    prev = l
    next
  }
  { prev = "" }'
# SELF-PROBE FIRST, both directions, on seeded diff text.
PROBE="$W/spell-probe.diff"
cat > "$PROBE" <<'PROBE_EOF'
+++ b/core/scripts/x.sh
@@ -1,0 +1,12 @@
+  done <<< "$(find . -type f)"
+  printf '%s\n' "$list" | while IFS= read -r f; do
+  find "$d" -type f > "$T/walk" || true
+  cat <<EOF
+$(git ls-files)
+  done < "$T/walk"
+  find "$d" -type f > "$T/walk" || rc=$?
+  hits="$(grep -c . "$T/hits" || true)"
+  sed -n 1p "$f" 2>/dev/null || true
+  # was: done < <(find ...) > f || true
+  cat <<'EOF'
+$(literal)
PROBE_EOF
PROBE_GOT="$(awk "$SPELL_AWK" "$PROBE" | cut -d: -f1 | tr '\n' ' ')"
if [ "$PROBE_GOT" = "r1 r2 r3 r4 " ]; then
  ok "spelling arm self-probe: r1-r4 each flagged once, the six correct spellings not flagged"
else
  bad "spelling arm self-probe read '$PROBE_GOT', expected 'r1 r2 r3 r4 ' -- the grammar cannot be trusted on the real diff"
fi
if ! git -C "$OWN" rev-parse --git-dir >/dev/null 2>&1; then
  skip "spelling arm -- $OWN is not a git work tree, so no pinned base can be diffed (this is not a pass)"
elif ! git -C "$OWN" cat-file -e "${PIN}^{commit}" 2>/dev/null; then
  skip "spelling arm -- the pin ${PIN} is not in this clone's history (shallow or foreign), so nothing was diffed (this is not a pass)"
else
  DIFF="$W/spell.diff"
  if git -C "$OWN" diff -U0 "$PIN" -- 'core/*.sh' ':(exclude)core/fixtures/**' > "$DIFF" 2>"$ERR"; then
    n_added="$(grep -c '^+[^+]' "$DIFF")" || n_added=0
    hits="$(awk "$SPELL_AWK" "$DIFF")"
    if [ "$n_added" -eq 0 ]; then
      bad "spelling arm: the diff against the pin added ZERO lines to core/*.sh -- the scan read nothing, so its zero is not a result"
    elif [ -z "$hits" ]; then
      ok "spelling arm: ${n_added} line(s) added since the pin, none reintroduces a discarded status (r1-r4)"
    else
      bad "spelling arm: added line(s) discard a producer's status -- $(printf '%s' "$hits" | head -3 | tr '\n' '|')"
    fi
  else
    bad "spelling arm: git diff against the pin failed: $(head -1 "$ERR")"
  fi
fi

# ================================================================================================
# MUTANTS. One copy of each subject directory; each mutant is a sibling file in that copy, so the
# script finds lib.sh, setup-sites.md, preclassify.sh and artifact-path-config.sh beside it.
# ================================================================================================
MT="$W/mt"; mkdir -p "$MT"
cp -R "$SC" "$MT/scripts" && cp -R "$RC_" "$MT/reconcile" && cp -R "$TREE/core/schemas" "$MT/schemas" \
  || { echo "FIXTURE BROKEN: could not copy the subject directories" >&2; exit 2; }

# mkmut <src> <dst> <find> <replace> [<find> <replace>]... -- every find must match EXACTLY once.
mkmut() {
  python3 - "$@" <<'PY'
import sys
src, dst, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
s = open(src, encoding="utf-8").read()
for i in range(0, len(pairs), 2):
    f, r = pairs[i], pairs[i + 1]
    n = s.count(f)
    if n != 1:
        print("anchor %d matched %d time(s)" % (i // 2 + 1, n)); sys.exit(1)
    s = s.replace(f, r)
open(dst, "w", encoding="utf-8").write(s)
PY
}
# mutant <id> <dir> <src-basename> <healthy-arm> "<arms it must FAIL>" <find> <replace> ...
mutant() {
  local id="$1" dir="$2" src="$3" healthy="$4" arms="$5" m why a survived=""
  shift 5
  m="$MT/$dir/_m_$id.sh"
  if ! why="$(mkmut "$MT/$dir/$src" "$m" "$@")"; then bad "mutant $id DID NOT APPLY ($why)"; return; fi
  if cmp -s "$MT/$dir/$src" "$m"; then bad "mutant $id DID NOT APPLY (the copy is byte-identical)"; return; fi
  bash -n "$m" 2>/dev/null || { bad "mutant $id DID NOT APPLY (the mutated copy does not parse)"; return; }
  if ! "$healthy" "$m"; then bad "mutant $id: its healthy twin $healthy failed on the mutant, so no kill can be read -- $ARM_WHY"; return; fi
  for a in $arms; do "$a" "$m" && survived="$survived $a"; done
  if [ -z "$survived" ]; then ok "mutant $id killed by:$(printf ' %s' $arms)"
  else bad "mutant $id SURVIVED$survived -- that arm cannot see its own site"; fi
}
# libmutant <id> <script> <healthy-arm> "<arms>" <find> <replace>... -- mutate reconcile/lib.sh.
# Every reconcile script sources "$SELF/lib.sh", so a lib.sh mutant is a WHOLE copy of the directory
# whose lib.sh is mutated, and <script> is driven from inside that copy. The copy is asserted to
# carry the mutation before any arm is read; `libcontrol` runs the same copy mechanics unmutated.
libmutant() {
  local id="$1" scr="$2" healthy="$3" arms="$4" d why a survived=""
  shift 4
  d="$MT/lib_$id"
  cp -R "$MT/reconcile" "$d" || { bad "mutant $id DID NOT APPLY (could not copy reconcile/)"; return; }
  if ! why="$(mkmut "$MT/reconcile/lib.sh" "$d/lib.sh" "$@")"; then bad "mutant $id DID NOT APPLY ($why)"; return; fi
  if cmp -s "$MT/reconcile/lib.sh" "$d/lib.sh"; then bad "mutant $id DID NOT APPLY (lib.sh is byte-identical)"; return; fi
  bash -n "$d/lib.sh" 2>/dev/null || { bad "mutant $id DID NOT APPLY (the mutated lib.sh does not parse)"; return; }
  if ! "$healthy" "$d/$scr"; then bad "mutant $id: its healthy twin $healthy failed on the mutant, so no kill can be read -- $ARM_WHY"; return; fi
  for a in $arms; do "$a" "$d/$scr" && survived="$survived $a"; done
  if [ -z "$survived" ]; then ok "mutant $id (lib.sh) killed by:$(printf ' %s' $arms)"
  else bad "mutant $id SURVIVED$survived -- that arm cannot see its own site"; fi
}
libcontrol() { # libcontrol <script> <arms...>
  local scr="$1" d="$MT/lib_ctl" a failed=""; shift
  [ -d "$d" ] || cp -R "$MT/reconcile" "$d" || { bad "control lib_ctl: could not copy reconcile/"; return; }
  cmp -s "$MT/reconcile/lib.sh" "$d/lib.sh" || { bad "control lib_ctl: the copied lib.sh differs"; return; }
  for a in "$@"; do "$a" "$d/$scr" || failed="$failed $a"; done
  if [ -z "$failed" ]; then ok "control lib_ctl/$scr: an unmutated directory copy passes$(printf ' %s' "$@")"
  else bad "control lib_ctl/$scr: an UNMUTATED directory copy failed$failed -- the lib mutant harness is broken"; fi
}
# The unmutated controls: the same copy mechanics, no edit, and every arm must still PASS.
control() { # control <dir> <src> <arms...>
  local dir="$1" src="$2" a failed=""; shift 2
  cp "$MT/$dir/$src" "$MT/$dir/_m_ctl.sh"
  for a in "$@"; do "$a" "$MT/$dir/_m_ctl.sh" || failed="$failed $a"; done
  if [ -z "$failed" ]; then ok "control $src: an unmutated copy passes$(printf ' %s' "$@")"
  else bad "control $src: an UNMUTATED copy failed$failed -- the mutant harness itself is broken"; fi
}
echo "== unmutated controls =="
control scripts   validate-ci-gates.sh          arm_ci_healthy arm_ci_retro arm_ci_surface
control reconcile relabel-extension-checks.sh   arm_rx_healthy arm_rx_walk
control reconcile retired-layer-passage.sh      arm_rlp_healthy arm_rw_walk arm_rlp_norm arm_rlp_removed arm_rlp_latin1 arm_rlp_latin1_c
control reconcile retired-layer-contract.sh     arm_rlc_healthy arm_rw_walk arm_rlc_shapes arm_rlc_tokens
control reconcile retired-tokens.sh             arm_rt_healthy arm_rt_base arm_rt_ours arm_rt_cmt_all arm_rt_cmt_ours
control reconcile retired-layer-token.sh        arm_rlt_healthy arm_rlt_cmt
control reconcile readopt-override.sh           arm_ro_healthy arm_ro_sort arm_ro_git arm_ro_span
libcontrol retired-layer-passage.sh arm_rlp_healthy arm_rlp_norm arm_rlp_removed arm_rlp_latin1
libcontrol readopt-override.sh      arm_ro_healthy arm_ro_span
control reconcile unregistered-drift.sh         arm_ud_healthy arm_ud_absorbed
control scripts   migrate-artifact-paths.sh     arm_mg_healthy arm_mg_ls
control scripts   validate-ac-falsifiability.sh arm_ac_healthy arm_ac_segment
control scripts   validate-layer-entries.sh     arm_le_healthy arm_le_census arm_lr_healthy arm_la_healthy arm_wt_healthy arm_lr_rules arm_la_anchors arm_wt_prov arm_wt_line
control reconcile layer-drift.sh                arm_ld_healthy arm_ld_walk arm_ld_sup arm_ld_fxv
control scripts   validate-provenance-block.sh  arm_pb_healthy arm_pb_unreadable arm_pb_zero arm_pb_walk2 arm_pb_walk127
control scripts   validate-adversarial-convergence.sh arm_cv_healthy arm_cv_sort

echo "== mutants (each restores a discarded status at one site) =="
mutant CI-RETRO scripts validate-ci-gates.sh arm_ci_healthy "arm_ci_retro" \
  'find "${RETRO_DIR}" -type f -name '"'"'*.md'"'"' 2>/dev/null > "$CI_T/retro-walk" || walk_rc=$?' ':' \
  'done < "$CI_T/retro-walk"' 'done < <(find "${RETRO_DIR}" -type f -name '"'"'*.md'"'"' 2>/dev/null)'
mutant CI-SURFACE scripts validate-ci-gates.sh arm_ci_healthy "arm_ci_surface" \
  'find "$target" -type f 2>/dev/null > "$CI_T/surface-walk" || walk_rc=$?' ':' \
  'done < "$CI_T/surface-walk"' 'done < <(find "$target" -type f 2>/dev/null)'
mutant CI-SUBSHELL scripts validate-ci-gates.sh arm_ci_healthy "arm_ci_surface" \
  'surface_hits="$(code_hits "${WORKFLOW_DIR}" "$gate")" || exit 2' \
  'surface_hits="$(code_hits "${WORKFLOW_DIR}" "$gate")" || surface_hits=0'
mutant RX-WALK reconcile relabel-extension-checks.sh arm_rx_healthy "arm_rx_walk" \
  'find "$EXT_DIR" -name '"'"'*.md'"'"' -type f | sort > "$RX_T/ext-walk" || ext_walk_rc=$?' ':' \
  'done < "$RX_T/ext-walk"' 'done < <(find "$EXT_DIR" -name '"'"'*.md'"'"' -type f | sort)'
mutant RLP-WALK reconcile retired-layer-passage.sh arm_rlp_healthy "arm_rw_walk" \
  'find "$LAYERS/$dir" -type f -name '"'"'*.md'"'"' 2>/dev/null > "$RLP_T/walk-$dir" || _rlp_rc=$?' ':' \
  'sort "$RLP_T/walk-$dir" > "$RLP_T/walk-$dir.sorted" || rlp_refuse "sorting the layer walk of $LAYERS/$dir" "$?"' ':' \
  'done < "$RLP_T/walk-$dir.sorted"' 'done < <(find "$LAYERS/$dir" -type f -name '"'"'*.md'"'"' 2>/dev/null | sort)'
mutant RLC-WALK reconcile retired-layer-contract.sh arm_rlc_healthy "arm_rw_walk" \
  'find "$LAYERS/$dir" -type f \( -name '"'"'*.md'"'"' -o -name '"'"'*.json'"'"' \) 2>/dev/null > "$RLC_T/walk-$dir" || _rlc_rc=$?' ':' \
  'sort "$RLC_T/walk-$dir" > "$RLC_T/walk-$dir.sorted" || rlc_refuse "sorting the layer walk of $LAYERS/$dir" "$?"' ':' \
  'done < "$RLC_T/walk-$dir.sorted"' 'done < <(find "$LAYERS/$dir" -type f \( -name '"'"'*.md'"'"' -o -name '"'"'*.json'"'"' \) 2>/dev/null | sort)'
mutant RT-SUBTRACT reconcile retired-tokens.sh arm_rt_healthy "arm_rt_all arm_rt_base" \
  $'  rt_toks "${cp}@${BASE}" "$RT_T/toks-base" <<<"$b"\n  rt_toks "${cp}@${THEIRS}" "$RT_T/toks-theirs" <<<"$t"\n  retired="$(comm -23 "$RT_T/toks-base" "$RT_T/toks-theirs")" || rt_refuse "the retired-token subtraction for $cp" "$?"' \
  $'  retired="$(comm -23 <(printf \'%s\\n\' "$b" | toks) <(printf \'%s\\n\' "$t" | toks))"'
mutant RT-PIPE reconcile retired-tokens.sh arm_rt_healthy "arm_rt_base" \
  'rt_toks "${cp}@${BASE}" "$RT_T/toks-base" <<<"$b"' 'printf '"'"'%s\n'"'"' "$b" | rt_toks "${cp}@${BASE}" "$RT_T/toks-base"'
mutant RT-OURS reconcile retired-tokens.sh arm_rt_healthy "arm_rt_ours" \
  $'  rt_toks "$cons" "$RT_T/toks-ours" < "$ours"\n  comm -12 "$RT_T/retired" "$RT_T/toks-ours" > "$RT_T/spoken" || rt_refuse "the consumer-token intersection for $cp" "$?"\n' '' \
  '  done < "$RT_T/spoken"' $'  done < <(comm -12 <(printf \'%s\\n\' "$retired") <(toks < "$ours"))'
mutant RO-FROM reconcile readopt-override.sh arm_ro_healthy "arm_ro_sort arm_ro_git" \
  $'  section_lines "$1" "$3" "$4-from" > "$RO_T/$4-from-lines" || return 3\n' '' \
  '  done < "$RO_T/$4-from-lines"' '  done < <(section_lines "$1" "$3" "$4-from")'
mutant RO-SUBSHELL reconcile readopt-override.sh arm_ro_healthy "arm_ro_sort arm_ro_git" \
  '[ "$_ro_rc" -ne 3 ] || ro_refuse "the superseded-line scan' 'true || ro_refuse "the superseded-line scan'
mutant RO-SECTION reconcile readopt-override.sh arm_ro_healthy "arm_ro_git" \
  $'    128) : > "$RO_T/$3.raw" ;;\n    *) return 3 ;;' $'    *) : > "$RO_T/$3.raw" ;;'
mutant UD-SITE reconcile unregistered-drift.sh arm_ud_healthy "arm_ud_absorbed" \
  $'  ud_trim_floor "$cons" "$t/ap-cons" || return 3\n  git_show "${BASE}" "${cp}" > "$t/ap-base-blob" || return 3\n  ud_trim_floor "$t/ap-base-blob" "$t/ap-base" || return 3\n  comm -23 "$t/ap-cons" "$t/ap-base" > "$t/ap-only" || return 3\n  only="$(cat "$t/ap-only")"' \
  $'  only="$(comm -23 \\\n    <(sed \'s/^[[:space:]]*//; s/[[:space:]]*$//\' "$cons" | grep -vE \'^.{0,24}$\' | sort -u) \\\n    <(git_show "${BASE}" "${cp}" | sed \'s/^[[:space:]]*//; s/[[:space:]]*$//\' | grep -vE \'^.{0,24}$\' | sort -u))"'
mutant UD-SUBSHELL reconcile unregistered-drift.sh arm_ud_healthy "arm_ud_absorbed" \
  'if ! ap_out="$(absorbed_pct "$cp" "$cons")"; then' 'if ! ap_out="$(absorbed_pct "$cp" "$cons")" && false; then'
mutant MG-LS scripts migrate-artifact-paths.sh arm_mg_healthy "arm_mg_ls" \
  'git ls-files -- $(printf '"'"'%s '"'"' $SCAN_ROOTS) 2>/dev/null > "$TMP/tracked" || LS_RC=$?' ':' \
  'done < "$TMP/tracked"' 'done < <(git ls-files -- $(printf '"'"'%s '"'"' $SCAN_ROOTS) 2>/dev/null)'
mutant AC-SEGMENT scripts validate-ac-falsifiability.sh arm_ac_healthy "arm_ac_segment" \
  $'  _acf_rc=0\n  awk \'' \
  $'  while IFS=\'|\' read -r ac_id start end; do\n    [ -n "$ac_id" ] && block_ids+=("$ac_id|$start|$end")\n  done < <(awk \'' \
  $'  \' "$story" > "$ACF_T/ac-blocks" || _acf_rc=$?\n  [ "$_acf_rc" -eq 0 ] || acf_refuse "segmenting $story into AC blocks" "$_acf_rc"\n  while IFS=\'|\' read -r ac_id start end; do\n    [ -n "$ac_id" ] && block_ids+=("$ac_id|$start|$end")\n  done < "$ACF_T/ac-blocks"' \
  $'  \' "$story")'
mutant LD-WALK reconcile layer-drift.sh arm_ld_healthy "arm_ld_walk" \
  $'layer_files "$OVR_DIR" > "$LD_T/overrides" || _lw_rc=$?\n' '' \
  'done < "$LD_T/overrides"' 'done < <(layer_files "$OVR_DIR")'
mutant LD-SUP reconcile layer-drift.sh arm_ld_healthy "arm_ld_sup" \
  $'        printf \'%s\\n\' "$cs" > "$LD_T/sup-core-span" || return 3\n' '' \
  'grep -Fxv -f "$LD_T/sup-core-span"' 'grep -Fxv -f <(printf '"'"'%s\n'"'"' "$cs")'
mutant LD-SUBSHELL reconcile layer-drift.sh arm_ld_healthy "arm_ld_sup" \
  'sup_surplus="$(sup_measure "$sup_raw")" || ld_refuse' 'sup_surplus="$(sup_measure "$sup_raw")" || true || ld_refuse'
mutant PB-WALK scripts validate-provenance-block.sh arm_pb_healthy "arm_pb_walk2 arm_pb_walk127" \
  $'    _pb_rc=0\n    grep -rlI "${GREP_ARGS[@]}" -- "$STRAY_MARKER" "${STRAY_SCAN_PATHS[@]}" 2>/dev/null \\\n        > "$PB_T/candidates" || _pb_rc=$?' \
  '    _pb_rc=0' \
  '    done < "$PB_T/candidates"' \
  '    done < <(grep -rlI "${GREP_ARGS[@]}" -- "$STRAY_MARKER" "${STRAY_SCAN_PATHS[@]}" 2>/dev/null)'
mutant PB-EMPTY2 scripts validate-provenance-block.sh arm_pb_healthy "arm_pb_walk2 arm_pb_zero" \
  'if [ "$_pb_rc" -gt 2 ] || { [ "$_pb_rc" -eq 2 ] && [ ! -s "$PB_T/candidates" ]; }; then' \
  'if [ "$_pb_rc" -gt 2 ]; then'
mutant CV-SORT scripts validate-adversarial-convergence.sh arm_cv_healthy "arm_cv_sort" \
  $'sort -k1,1n "$AC_T/keyed" > "$AC_T/sorted" || _ac_rc=$?\n' '' \
  'done < "$AC_T/sorted"' $'done < <(printf \'%s\\n\' "${KEYED[@]:-}" | sort -k1,1n)'
le_mut() { # le_mut <id> <arm> <site> <base producer>
  mutant "$1" scripts validate-layer-entries.sh arm_le_healthy "$2" \
    "vle_layer_list $3 " ": $3 " \
    "done < \"\$VLE_T/$3\"" "done < <($4)"
}
le_mut LE-CENSUS    arm_le_census    census-layers   'layer_files "$EXT_DIR"; layer_files "$OVR_DIR"'
le_mut LE-OVERRIDES arm_le_overrides overrides       'layer_files "$OVR_DIR"'
le_mut LE-LIVE      arm_le_live      live-extensions 'layer_files "$EXT_DIR"'
le_mut LE-EXT       arm_le_ext       extensions      'layer_files "$EXT_DIR"'
le_mut LE-W9        arm_le_w9        w9-layers       '{ layer_files "$EXT_DIR"; layer_files "$OVR_DIR"; }'
le_mut LE-W11       arm_le_w11       w11-layers      '{ layer_files "$EXT_DIR"; layer_files "$OVR_DIR"; }'

echo "== mutants: a staged FUNCTION whose body is a pipeline (each restores the v0.650.0 status) =="
# norm_lines returns `tr`'s status again: a dead sed reads as a normalised EMPTY file.
libmutant RLP-NORMLINES retired-layer-passage.sh arm_rlp_healthy "arm_rlp_norm arm_rlp_removed" \
  $'norm_lines() {\n  local _ps\n' $'norm_lines() {\n' \
  $'  _ps="${PIPESTATUS[*]}"\n  case "$_ps" in \'0 0\') return 0 ;; \'0 \'*) return "${_ps#0 }" ;; *) return "${_ps%% *}" ;; esac\n' ''
# The deleted-line side read through a pipeline again, so its status is the LAST stage's.
mutant RLP-REMOVED reconcile retired-layer-passage.sh arm_rlp_healthy "arm_rlp_removed" \
  'norm_lines < "$RLP_T/removed-raw" > "$RLP_T/removed-norm" || _rlp_rc=$?' \
  'norm_lines < "$RLP_T/removed-raw" | cat > "$RLP_T/removed-norm" || _rlp_rc=$?'
# The caller's locale reaches norm_lines' BSD sed again: a Latin-1 layer file is refused instead
# of read. The C locale is scoped onto that sed in lib.sh, not exported by the passage script, so
# the mutant is built there.
libmutant RLP-LOCALE retired-layer-passage.sh arm_rlp_healthy "arm_rlp_latin1" \
  $'  LC_ALL=C sed -E \'s/^[[:space:]]+//; s/[[:space:]]+$//\n' $'  sed -E \'s/^[[:space:]]+//; s/[[:space:]]+$//\n'
# defined_rules is one pipeline ending in `grep -E '.'` again: a dead harvest presents as its 1.
mutant LE-DEFRULES scripts validate-layer-entries.sh arm_lr_healthy "arm_lr_rules" \
  $'  local _raw _rc=0\n  _raw="$(grep -Eho "$RULE_RE" "$1" 2>/dev/null)" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_raw" ] || return 0\n  printf \'%s\\n\' "$_raw" \\\n' \
  $'  grep -Eho "$RULE_RE" "$1" 2>/dev/null \\\n' \
  $'    | sed \'/^$/d\' | sort -u\n}\n\nrule_title' $'    | grep -E \'.\' | sort -u\n}\n\nrule_title'
# defined_anchors is one brace-group pipeline again: its status is bold_anchors_of_file's.
mutant LE-DEFANCHORS scripts validate-layer-entries.sh arm_la_healthy "arm_la_anchors" \
  $'  local _raw _ids="" _bold _rc=0\n  _raw="$(grep -Eho "$CHECK_HEAD_RE" "$1" 2>/dev/null)" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  if [ -n "$_raw" ]; then\n    _ids="$(printf \'%s\\n\' "$_raw" \\\n      | sed' \
  $'  { grep -Eho "$CHECK_HEAD_RE" "$1" 2>/dev/null \\\n      | sed' \
  $')$//\')" || return\n  fi\n  _bold="$(bold_anchors_of_file "$1")" || return\n  printf \'%s\\n%s\\n\' "$_ids" "$_bold" | sed \'/^$/d\' | sort -u\n' \
  $')$//\'\n    bold_anchors_of_file "$1"\n  } | sort -u\n'
# prov_tokens / line_tokens are grep pipelines again: a dead first grep presents as a later grep's 1.
mutant LE-PROV scripts validate-layer-entries.sh arm_wt_healthy "arm_wt_prov" \
  $'  _t="$(tok_chain "$1" -oE \'\\[[^]]*\\]|\\([^)]*\\)\')" || return\n  [ -n "$_t" ] || return 0\n  _t="$(tok_chain "$_t" -oE \'[A-Za-z0-9]+(-[A-Za-z0-9]+)*\')" || return\n  [ -n "$_t" ] || return 0\n  tok_tail "$_t"\n' \
  $'  printf \'%s\\n\' "$1" | grep -oE \'\\[[^]]*\\]|\\([^)]*\\)\' 2>/dev/null \\\n    | grep -oE \'[A-Za-z0-9]+(-[A-Za-z0-9]+)*\' 2>/dev/null \\\n    | grep -E \'[A-Z]\' | grep -E \'[0-9]\' | awk \'length($0) >= 3\' | sort -u\n'
mutant LE-LINE scripts validate-layer-entries.sh arm_wt_healthy "arm_wt_line" \
  $'line_tokens() {\n  local _t\n  _t="$(tok_chain "$1" -oE \'[A-Za-z0-9]+(-[A-Za-z0-9]+)*\')" || return\n  [ -n "$_t" ] || return 0\n  tok_tail "$_t"\n}' \
  $'line_tokens() {\n  printf \'%s\\n\' "$1" | grep -oE \'[A-Za-z0-9]+(-[A-Za-z0-9]+)*\' 2>/dev/null \\\n    | grep -E \'[A-Z]\' | grep -E \'[0-9]\' | awk \'length($0) >= 3\' | sort -u\n}'
# retired-tokens' toks is one pipeline again.
mutant RT-TOKS reconcile retired-tokens.sh arm_rt_healthy "arm_rt_cmt_all arm_rt_cmt_ours" \
  $'  local _code _t _rc=0\n  _code="$(grep -vE \'^[[:space:]]*#\')" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_code" ] || return 0\n  _t="$(printf \'%s\\n\' "$_code" | grep -oE \'\\$[A-Za-z_][A-Za-z0-9_]*/[A-Za-z0-9._/-]+\')" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_t" ] || return 0\n  printf \'%s\\n\' "$_t" | sort -u\n' \
  $'  grep -vE \'^[[:space:]]*#\' \\\n  | grep -oE \'\\$[A-Za-z_][A-Za-z0-9_]*/[A-Za-z0-9._/-]+\' \\\n  | sort -u\n'
# retired-layer-token: BOTH layers -- code_toks pipes into toks, and toks ends in a grep. Reverting
# code_toks alone leaves toks returning 0 on empty input, and pipefail then reports the strip's 2.
mutant RLT-CODETOKS reconcile retired-layer-token.sh arm_rlt_healthy "arm_rlt_cmt" \
  $'  local _w _t _rc=0\n  _w="$(tr -c \'A-Za-z0-9_-\' \'\\n\')" || return\n  _t="$(printf \'%s\\n\' "$_w" | grep -E \'^[A-Z][A-Z0-9_]{3,}(-[A-Z0-9_]+)*$\')" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_t" ] || return 0\n  printf \'%s\\n\' "$_t" | sort -u\n' \
  $'  tr -c \'A-Za-z0-9_-\' \'\\n\' \\\n  | grep -E \'^[A-Z][A-Z0-9_]{3,}(-[A-Z0-9_]+)*$\' \\\n  | sort -u\n' \
  $'  local _code _rc=0\n  _code="$(grep -vE \'^[[:space:]]*#\')" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_code" ] || return 0\n  printf \'%s\\n\' "$_code" | toks\n' \
  $'  grep -vE \'^[[:space:]]*#\' | toks\n'
# retired-layer-contract: each harvest's status is discarded again (v0.650.0's `|| true`).
mutant RLC-SHAPES reconcile retired-layer-contract.sh arm_rlc_healthy "arm_rlc_shapes" \
  $'  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_h" ] || return 0\n  printf \'%s\\n\' "$_h" | sed -E' \
  $'  [ -n "$_h" ] || return 0\n  printf \'%s\\n\' "$_h" | sed -E'
mutant RLC-TOKENS reconcile retired-layer-contract.sh arm_rlc_healthy "arm_rlc_tokens" \
  $'  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_h" ] || return 0\n  printf \'%s\\n\' "$_h" | sort -u' \
  $'  [ -n "$_h" ] || return 0\n  printf \'%s\\n\' "$_h" | sort -u'
# layer-drift: sup_measure's count reads no stage's status again.
mutant LD-FXV reconcile layer-drift.sh arm_ld_healthy "arm_ld_fxv" \
  $' | grep -c .\n              for _ps in "${PIPESTATUS[@]}"; do [ "$_ps" -le 1 ] || exit 3; done)" || return 3\n' \
  $' | grep -c .)"\n'
# section_of returns `rm`'s status again: a span_of that died reads as "no such section".
libmutant RO-SECTIONOF readopt-override.sh arm_ro_healthy "arm_ro_span" \
  $'  local _t _s="" _rc=0\n  _t="$(mktemp)" || return 1\n  cat > "$_t" || _rc=$?\n  if [ "$_rc" -eq 0 ]; then _s="$(span_of "$1" < "$_t")" || _rc=$?; fi\n  if [ "$_rc" -eq 0 ] && [ -n "$_s" ]; then LC_ALL=C sed -n "${_s%% *},${_s##* }p" "$_t" || _rc=$?; fi\n  rm -f "$_t"\n  return "$_rc"\n' \
  $'  local _t _s\n  _t="$(mktemp)" || return 1\n  cat > "$_t"\n  _s="$(span_of "$1" < "$_t")"\n  [ -n "$_s" ] && LC_ALL=C sed -n "${_s%% *},${_s##* }p" "$_t"\n  rm -f "$_t"\n'

echo
if [ "$fails" -eq 0 ]; then echo "procsub-staged-refusal: PASS"; exit 0; fi
echo "procsub-staged-refusal: $fails assertion(s) FAILED" >&2
exit 1
