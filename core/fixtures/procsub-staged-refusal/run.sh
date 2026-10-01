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
# LIB.SH'S AWK EMITTERS CANNOT FAIL, AND NON-ASCII PATHS REACH THE ROWS RAW. `nrm_awk`,
# `ledger_entry_awk` and `backlog_entry_label_awk` were `cat <<'AWK'` heredocs, which bash 3.2
# stages to a temp file: under a write limit the capture was EMPTY at rc 1, and every inline
# `awk "$(ledger_entry_awk)..."` caller discarded that. Each emitter is captured under
# `ulimit -f 0` and must equal its unforced bytes; a scan holds lib.sh to zero heredoc openers.
# `memo_diff_name_status` and preclassify's relocation listing read paths with
# `core.quotePath=false`, and two seeded worlds holding a non-ASCII `core/scripts/caf\303\251.sh` drive the shipping
# retired-tokens.sh and preclassify.sh to prove the row survives, beside an ASCII control row. A third
# world holds a non-ASCII MACHINERY file and drives self-update-gate.sh, whose arm C joins those raw
# rows against preclassify's `machinery_paths()` -- which must list with `core.quotePath=false` too.
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
for _f in "$LEX" "$GRAMMAR" "$LCON" "$RC_/retired-tokens.sh" "$RC_/unregistered-drift.sh" "$RC_/lib.sh" "$RC_/preclassify.sh"; do
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

# --- NW: blobs carrying a NUL byte. `toks` reads the staged `git show` file, where it used to read
# `<<<"$b"` from a `$( )` capture that had already dropped every NUL; BSD grep reads a NUL-bearing
# stdin as binary. Three shapes, each beside ctl.sh (no NUL, `old-c` retired, spoken), whose row
# proves the run reached the loop: nul.sh has a NUL at both refs (its `old-n` row must stand), q.sh
# gains a NUL at theirs only (no token of it is retired), h.sh has a NUL immediately before a
# comment `#` at base (the commented `cmt-h` must stay a comment -- a `grep -a` repair reads it live).
NW="$W/nw"; NWD="$NW/dist"; NWC="$NW/consumer"; mkdir -p "$NWD/core/scripts" "$NWC/scripts/ai-dlc"
printf 'x=$ROOT/old-n\n\000junk\ny=$ROOT/keep-n\n' > "$NWD/core/scripts/nul.sh"
printf 'x=$ROOT/keep-a\ny=$ROOT/keep-b\n' > "$NWD/core/scripts/q.sh"
printf 'x=$ROOT/old-h\n\000# $ROOT/cmt-h\n' > "$NWD/core/scripts/h.sh"
printf 'x=$ROOT/old-c\n' > "$NWD/core/scripts/ctl.sh"
gitq -C "$NWD" init -q; gitq -C "$NWD" add -A; gitq -C "$NWD" commit -qm base
NW_BASE="$(git -C "$NWD" rev-parse HEAD)"
printf 'x=$ROOT/new-n\n\000junk\ny=$ROOT/keep-n\n' > "$NWD/core/scripts/nul.sh"
printf 'x=$ROOT/keep-a\n\000\ny=$ROOT/keep-b\n' > "$NWD/core/scripts/q.sh"
printf 'x=$ROOT/new-h\n# $ROOT/cmt-h\n' > "$NWD/core/scripts/h.sh"
printf 'x=$ROOT/new-c\n' > "$NWD/core/scripts/ctl.sh"
gitq -C "$NWD" add -A; gitq -C "$NWD" commit -qm theirs
NW_THEIRS="$(git -C "$NWD" rev-parse HEAD)"
printf 'uses $ROOT/old-n and $ROOT/keep-n\n' > "$NWC/scripts/ai-dlc/nul.sh"
printf 'uses $ROOT/keep-a and $ROOT/keep-b\n' > "$NWC/scripts/ai-dlc/q.sh"
printf 'uses $ROOT/old-h and $ROOT/cmt-h\n' > "$NWC/scripts/ai-dlc/h.sh"
printf 'uses $ROOT/old-c\n' > "$NWC/scripts/ai-dlc/ctl.sh"
for _nw in nul q h; do
  printf 'X\tcore/scripts/%s.sh\tscripts/ai-dlc/%s.sh\tCLASSIFY\nX\tcore/scripts/ctl.sh\tscripts/ai-dlc/ctl.sh\tCLASSIFY\n' "$_nw" "$_nw" > "$NW/rows-$_nw"
done

# --- LW: a theirs blob carrying ONE Latin-1 byte (invalid UTF-8) in a comment between two kept
# tokens. BSD `tr` under a UTF-8 locale exits 1 on it ("Illegal byte sequence") after writing only
# the bytes before it, so an unpinned NUL strip refused the file, and one whose status was dropped
# read theirs as carrying `keep1` alone -- a FALSE `alat.sh -> keep2` row at rc 0. Nothing in alat.sh
# is retired; ctl.sh (`old-c` retired, spoken) is the row proving the run reached the loop. alat.sh
# is listed FIRST, so the NUL strips run base (1), theirs (2), ours (3) on it before ctl.sh.
LW="$W/lw"; LWD="$LW/dist"; LWC="$LW/consumer"; mkdir -p "$LWD/core/scripts" "$LWC/scripts/ai-dlc"
printf 'x=$ROOT/keep1\ny=$ROOT/keep2\n' > "$LWD/core/scripts/alat.sh"
printf 'x=$ROOT/old-c\n' > "$LWD/core/scripts/ctl.sh"
gitq -C "$LWD" init -q; gitq -C "$LWD" add -A; gitq -C "$LWD" commit -qm base
LW_BASE="$(git -C "$LWD" rev-parse HEAD)"
printf 'x=$ROOT/keep1\n# caf\351\ny=$ROOT/keep2\n' > "$LWD/core/scripts/alat.sh"
printf 'x=$ROOT/new-c\n' > "$LWD/core/scripts/ctl.sh"
gitq -C "$LWD" add -A; gitq -C "$LWD" commit -qm theirs
LW_THEIRS="$(git -C "$LWD" rev-parse HEAD)"
printf 'uses $ROOT/keep1 and $ROOT/keep2\n' > "$LWC/scripts/ai-dlc/alat.sh"
printf 'uses $ROOT/old-c\n' > "$LWC/scripts/ai-dlc/ctl.sh"
printf 'X\tcore/scripts/alat.sh\tscripts/ai-dlc/alat.sh\tCLASSIFY\nX\tcore/scripts/ctl.sh\tscripts/ai-dlc/ctl.sh\tCLASSIFY\n' > "$LW/rows"
# The UTF-8 arm needs the locale. Absent, it and the mutant it kills print SKIP, never ok.
LW_NL='
'
LW_LOCALES="$(locale -a 2>/dev/null)" || LW_LOCALES=""
LW_UTF8=0
case "$LW_NL$LW_LOCALES$LW_NL" in *"${LW_NL}en_US.UTF-8${LW_NL}"*) LW_UTF8=1 ;; esac

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

# --- TA: retired-tokens' two ABSENT-AT-A-REF CLASSIFY buckets, beside a retired token ------------
# `added.sh` is absent at base (BOTH-ADDED->CLASSIFY) and `deleted.sh` absent at theirs
# (UPSTREAM-DELETED+consumer-modified->CLASSIFY). Both are the LEGITIMATE absent skip the staged blob
# read must keep, and the reference consumer's recent ranges hold neither bucket, so a healthy run
# there cannot discriminate this path: the world is synthesized. `validate-artifact-budget.sh` gives
# the run a row, so a healthy twin is presence-shaped.
TA="$W/ta"; TAD="$TA/dist"; TAC="$TA/consumer"; mkdir -p "$TAD/core/scripts" "$TAC/scripts/ai-dlc"
printf 'CHAN="$ROOT/.chan"\nprintf x >> "$ROOT/.chan"\n' > "$TAD/core/scripts/validate-artifact-budget.sh"
printf 'X="$ROOT/.gone"\n' > "$TAD/core/scripts/deleted.sh"
gitq -C "$TAD" init -q; gitq -C "$TAD" add -A; gitq -C "$TAD" commit -qm base
TA_BASE="$(git -C "$TAD" rev-parse HEAD)"
printf 'TMPROOT="$(mktemp -d)"\nCHAN="$TMPROOT/chan"\n' > "$TAD/core/scripts/validate-artifact-budget.sh"
printf 'Y="$ROOT/.added"\n' > "$TAD/core/scripts/added.sh"
gitq -C "$TAD" rm -q core/scripts/deleted.sh
gitq -C "$TAD" add -A; gitq -C "$TAD" commit -qm theirs
TA_THEIRS="$(git -C "$TAD" rev-parse HEAD)"
printf 'CHAN="$ROOT/.chan"\nprintf x >> "$ROOT/.chan"\npool() { :; }\n' > "$TAC/scripts/ai-dlc/validate-artifact-budget.sh"
printf 'Y="$ROOT/.mine"\n' > "$TAC/scripts/ai-dlc/added.sh"
printf 'X="$ROOT/.gone"\nz=1\n' > "$TAC/scripts/ai-dlc/deleted.sh"

# --- RG: retired-layer-contract over a rulebook path BOTH refs ship, cited by a layer file -------
# Theirs retires one role-file shape (so the run opens layer files and the healthy twin has a row)
# and deletes NO rulebook file. `steps/gone.md` survives; `extensions/cites.md` cites it. A failed
# THEIRS listing read as an empty rulebook makes every base rulebook file look retired, and the
# pre-fix detector then printed a FALSE `path:` row for exactly this citation.
RG="$W/rg"; RGD="$RG/dist"; RGC="$RG/consumer"
mkdir -p "$RGD/core/skills/ai-dlc/steps" "$RGD/core/team-roles" \
  "$RGC/.claude/skills/ai-dlc/overrides" "$RGC/.claude/skills/ai-dlc/extensions"
printf '# Step: gone (fixture)\n\nA step both refs ship.\n' > "$RGD/core/skills/ai-dlc/steps/gone.md"
printf '# Role: Architect\n\n**Model.**\n- Personal: `/model claude-fixture-x`\n' > "$RGD/core/team-roles/architect.md"
gitq -C "$RGD" init -q; gitq -C "$RGD" add -A; gitq -C "$RGD" commit -qm base
RG_BASE="$(git -C "$RGD" rev-parse HEAD)"
printf '# Role: Architect\n\n**Model.**\n- Model: `opus`, a key.\n' > "$RGD/core/team-roles/architect.md"
gitq -C "$RGD" add -A; gitq -C "$RGD" commit -qm theirs
RG_THEIRS="$(git -C "$RGD" rev-parse HEAD)"
printf -- '---\nshadows: team-roles/tea.md#Identity\n---\n- Personal: `/model claude-fixture-x`\n' > "$RGC/.claude/skills/ai-dlc/overrides/roles.md"
printf -- '---\nhooks: steps/gone.md\n---\n# Ext\n\nAugments a step both refs ship.\n' > "$RGC/.claude/skills/ai-dlc/extensions/cites.md"

# --- QA / QB: a NON-ASCII core path. Under git's default `core.quotePath` a name carrying a byte
# above 0x7f is listed C-quoted (`"core/scripts/caf\303\251.sh"`), which matches no consumer path,
# so the row for it is lost while the ASCII twin `plain.sh` beside it stands. The name is built from
# octal escapes, never typed, so this file stays ASCII.
QU="$(printf 'caf\303\251')"
# QA: both files retire a token and a consumer holds edited copies at the installed path. retired-
# tokens.sh runs preclassify itself (no --bucket-rows), so the path reaches it through
# memo_diff_name_status.
QA="$W/qa"; QAD="$QA/dist"; QAC="$QA/consumer"; mkdir -p "$QAD/core/scripts" "$QAC/scripts/ai-dlc" "$QAC/.claude"
for _q in plain "$QU"; do printf 'x=$ROOT/old-%s\n' "$_q" > "$QAD/core/scripts/$_q.sh"; done
gitq -C "$QAD" init -q; gitq -C "$QAD" add -A; gitq -C "$QAD" commit -qm base
QA_BASE="$(git -C "$QAD" rev-parse HEAD)"
for _q in plain "$QU"; do printf 'x=$ROOT/new-%s\n' "$_q" > "$QAD/core/scripts/$_q.sh"; done
gitq -C "$QAD" add -A; gitq -C "$QAD" commit -qm theirs
QA_THEIRS="$(git -C "$QAD" rev-parse HEAD)"
for _q in plain "$QU"; do printf 'x=$ROOT/old-%s\necho edited\n' "$_q" > "$QAC/scripts/ai-dlc/$_q.sh"; done
# QB: a PRE-RELOCATION consumer holding edited copies at `scripts/<name>` while upstream modifies
# `core/scripts/<name>`. preclassify's relocation pass lists core/scripts/ at theirs, and the row it
# owes each file is the RELOCATE-MOVE+consumer-edited disclosure.
QB="$W/qb"; QBD="$QB/dist"; QBC="$QB/consumer"; mkdir -p "$QBD/core/scripts" "$QBC/scripts" "$QBC/.claude"
for _q in plain "$QU"; do printf 'old\n' > "$QBD/core/scripts/$_q.sh"; done
gitq -C "$QBD" init -q; gitq -C "$QBD" add -A; gitq -C "$QBD" commit -qm base
QB_BASE="$(git -C "$QBD" rev-parse HEAD)"
for _q in plain "$QU"; do printf 'new\n' > "$QBD/core/scripts/$_q.sh"; done
gitq -C "$QBD" add -A; gitq -C "$QBD" commit -qm theirs
QB_THEIRS="$(git -C "$QBD" rev-parse HEAD)"
for _q in plain "$QU"; do printf 'old\nlocal edit\n' > "$QBC/scripts/$_q.sh"; done
# QC: two MACHINERY files (`core/skills/ai-dlc-update/**` in setup-sites.md) move v1 -> v2 while the
# consumer holds local edits of both. self-update-gate.sh arm C joins preclassify's rows against
# `machinery_paths()` with `grep -xF`, so the non-ASCII row is carried only when BOTH sides spell the
# name raw. Every run gets a fresh copy of the consumer, because the gate writes its record into it.
QC="$W/qc"; QCD="$QC/dist"; QCC="$QC/consumer"
mkdir -p "$QCD/core/skills/ai-dlc-update" "$QCC/.claude/skills/ai-dlc-update"
for _q in plain "$QU"; do printf 'v1\n' > "$QCD/core/skills/ai-dlc-update/$_q.md"; done
gitq -C "$QCD" init -q; gitq -C "$QCD" add -A; gitq -C "$QCD" commit -qm base
QC_BASE="$(git -C "$QCD" rev-parse HEAD)"
for _q in plain "$QU"; do printf 'v2\n' > "$QCD/core/skills/ai-dlc-update/$_q.md"; done
gitq -C "$QCD" add -A; gitq -C "$QCD" commit -qm theirs
QC_THEIRS="$(git -C "$QCD" rev-parse HEAD)"
for _q in plain "$QU"; do printf 'v1\nmy local edit\n' > "$QCC/.claude/skills/ai-dlc-update/$_q.md"; done

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
# nw_arm <script> <world> <expected stdout, rows joined by |> -- the WHOLE stdout, rc 0. The ctl.sh
# row is in every expectation, so a copy that never reached the loop cannot pass; exact equality
# is what separates a lost true row from a FALSE one, and both from the correct set.
NT="$(printf '\t')"
nw_arm() { local rc=0 want got
  bash "$1" --bucket-rows "$NW/rows-$2" "$NWD" "$NW_BASE" "$NW_THEIRS" "$NWC" > "$OUT" 2> "$ERR" || rc=$?
  want="$(printf '%s' "$3" | tr '|' '\n')"; got="$(cat "$OUT")"
  ARM_WHY="rc=$rc stdout=[$(printf '%s' "$got" | tr '\n\t' '| ')] want=[$(printf '%s' "$want" | tr '\n\t' '| ')] $(grep -v '^$' "$ERR" | tail -1 | cut -c1-80)"
  [ "$rc" -eq 0 ] && [ "$got" = "$want" ]; }
NW_CTL="RETIRED-CONTRACT-TOKEN${NT}core/scripts/ctl.sh${NT}\$ROOT/old-c"
arm_nw_both()   { nw_arm "$1" nul "$NW_CTL|RETIRED-CONTRACT-TOKEN${NT}core/scripts/nul.sh${NT}\$ROOT/old-n"; }
arm_nw_theirs() { nw_arm "$1" q "$NW_CTL"; }
arm_nw_cmt()    { nw_arm "$1" h "$NW_CTL|RETIRED-CONTRACT-TOKEN${NT}core/scripts/h.sh${NT}\$ROOT/old-h"; }
# lw_run <script> <locale> [stub-dir] -- the Latin-1 theirs world, under LC_ALL=<locale>. The WHOLE
# stdout must be the ctl.sh row alone at rc 0: a refusal, a lost ctl row and a FALSE alat.sh row
# (keep1 or keep2, from a theirs read short) each fail it.
LW_WANT="RETIRED-CONTRACT-TOKEN${NT}core/scripts/ctl.sh${NT}\$ROOT/old-c"
lw_run() { local p="$PATH"; [ -n "${3:-}" ] && p="$3:$PATH"
  env -u LANG PATH="$p" LC_ALL="$2" bash "$1" --bucket-rows "$LW/rows" "$LWD" "$LW_BASE" "$LW_THEIRS" "$LWC" > "$OUT" 2> "$ERR"; }
lw_why() { ARM_WHY="rc=$1 stdout=[$(tr '\n\t' '| ' < "$OUT")] want=[$(printf '%s' "$LW_WANT" | tr '\t' ' ')] $(grep -v '^$' "$ERR" | tail -1 | cut -c1-80)"; }
arm_lw_c() { local rc=0; lw_run "$1" C || rc=$?; lw_why "$rc"; [ "$rc" -eq 0 ] && [ "$(cat "$OUT")" = "$LW_WANT" ]; }
# The NO-STUB arm. Its precondition is measured outside the subject, in the same invocation: the
# real `tr -d '\000'` must refuse the theirs blob under UTF-8 ("Illegal byte sequence") and accept
# it under C. A host where that does not hold cannot express the failure, and the arm FAILS.
lw_pre() { local u=0 c=0
  env -u LANG LC_ALL=en_US.UTF-8 tr -d '\000' < "$LWD/core/scripts/alat.sh" > /dev/null 2> "$W/lwerr" || u=$?
  env -u LANG LC_ALL=C tr -d '\000' < "$LWD/core/scripts/alat.sh" > /dev/null 2>&1 || c=$?
  LW_PRE="utf8-tr rc=$u c-tr rc=$c"
  [ "$u" -ne 0 ] && [ "$c" -eq 0 ] && grep -qi 'illegal byte sequence' "$W/lwerr"; }
arm_lw_utf8() { local rc=0
  if ! lw_pre; then ARM_WHY="precondition not met on this host ($LW_PRE), so the arm cannot express the failure"; return 1; fi
  lw_run "$1" en_US.UTF-8 || rc=$?; lw_why "$rc"; ARM_WHY="$LW_PRE; $ARM_WHY"
  [ "$rc" -eq 0 ] && [ "$(cat "$OUT")" = "$LW_WANT" ]; }
# The STATUS arm. Pinned to C, the real `tr` never fails on this blob, so a dropped status has
# nothing to drop there: the failure is FORCED on alat.sh's theirs strip (call 2), and a copy that
# drops the status reads theirs as tokenless -- FALSE keep1 and keep2 rows at rc 0.
arm_lw_trstatus() { local rc=0; mkstub tr '"-d "?000' 2 1; lw_run "$1" C "$STUB" || rc=$?
  lw_why "$rc"; ARM_WHY="fired=$(fired) $ARM_WHY"
  failed_call 2 && [ "$rc" -eq 2 ] && grep -q 'token scan of core/scripts/alat\.sh@' "$ERR" && [ ! -s "$OUT" ]; }

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

# --- retired-tokens: the BLOB READS. Three git calls only it makes, each stubbed by its own argv ---
# `rev-parse -q --verify <ref>^{commit}` (both refs, once), `ls-tree --name-only <ref> -- <path>` (per
# path and ref), `show "${ref}:${path}"` (per present path and ref). preclassify's own git calls carry
# none of these argv shapes, which each arm proves by its healthy half and by the stub FIRING.
ta_run() { # ta_run <script> <stub-dir or ""> [<only-path>]
  local p="$PATH"; [ -n "$2" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$TAD" "$TA_BASE" "$TA_THEIRS" "$TAC" ${3:+"$3"} > "$OUT" 2> "$ERR"; }
# The absent skip is a SKIP: the whole run emits the token row and nothing on stderr, and each absent
# path run alone is listed and opened NONE, exit 0 -- never a refusal.
arm_ta_healthy() { local rc=0 r1=0 r2=0
  ta_run "$1" "" || rc=$?
  ARM_WHY="rc=$rc: $(head -1 "$OUT")$(tail -1 "$ERR" | cut -c1-100)"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-CONTRACT-TOKEN.*validate-artifact-budget\.sh.*\$ROOT/\.chan' "$OUT" \
    && ! grep -qE 'added\.sh|deleted\.sh' "$OUT" && [ ! -s "$ERR" ] || return 1
  ta_run "$1" "" core/scripts/added.sh || r1=$?
  ARM_WHY="added.sh alone rc=$r1: $(tail -1 "$ERR" | cut -c1-110)"
  [ "$r1" -eq 0 ] && [ ! -s "$OUT" ] && grep -q 'listed 1 CLASSIFY file(s) at core/scripts/added\.sh and opened NONE' "$ERR" || return 1
  ta_run "$1" "" core/scripts/deleted.sh || r2=$?
  ARM_WHY="deleted.sh alone rc=$r2: $(tail -1 "$ERR" | cut -c1-110)"
  [ "$r2" -eq 0 ] && [ ! -s "$OUT" ] && grep -q 'listed 1 CLASSIFY file(s) at core/scripts/deleted\.sh and opened NONE' "$ERR"; }
arm_ta_verify() { local rc=0; mkstub git '*"rev-parse -q --verify "*"^{commit}"' 0 128; ta_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q "resolving ${TA_BASE} to a commit .* did not run (exit 128); no verdict" "$ERR" && [ ! -s "$OUT" ]; }
arm_ta_ls() { local rc=0; mkstub git '*"ls-tree --name-only "*" -- "*' 0 128; ta_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'listing core/scripts/.* did not run (exit 128); no verdict' "$ERR" && [ ! -s "$OUT" ]; }
# Show calls, in order: deleted.sh@base (1; its theirs side is absent and never shown), then the
# token file @base (2) and @theirs (3). Failing 3 is ONE side of the one file carrying the row -- the
# pre-fix read took that side as empty, skipped the file, and lost the row with exit 0.
arm_ta_show() { local rc=0; mkstub git '*" show "*' 3 128; ta_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 3 && [ "$rc" -eq 2 ] \
    && grep -q "reading core/scripts/validate-artifact-budget\.sh at ${TA_THEIRS} did not run (exit 128); no verdict" "$ERR" \
    && [ ! -s "$OUT" ]; }

# --- retired-layer-contract: the rulebook TREE LISTING and BLOB READS inside collect/rulebook_set ---
rg_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$RGD" "$RG_BASE" "$RG_THEIRS" "$RGC" > "$OUT" 2> "$ERR"; }
arm_rg_healthy() { local rc=0; rg_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(head -1 "$OUT")$(tail -1 "$ERR" | cut -c1-100)"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-CONTRACT.*overrides/roles\.md.*Personal:/model' "$OUT" && ! grep -q 'path:' "$OUT"; }
# The THEIRS listing fails. The pre-fix detector read it as a rulebook with no file, so every base
# rulebook file read as RETIRED and `extensions/cites.md` got a FALSE `path:` row, exit 0.
arm_rg_theirs_ls() { local rc=0; mkstub git "*\"ls-tree -r --name-only ${RG_THEIRS}\"*" 0 128; rg_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(grep -c 'path:' "$OUT") path row(s); $(tail -1 "$ERR" | cut -c1-110)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q "rulebook tree listing at ${RG_THEIRS} .*did not run (exit 128); no verdict" "$ERR" \
    && ! grep -q 'path:' "$OUT" && [ ! -s "$OUT" ]; }
# Every BASE blob read fails. The pre-fix read took each as an empty body, skipped it, and exited 0.
arm_rg_base_show() { local rc=0; mkstub git "*\" show ${RG_BASE}:\"*" 0 128; rg_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q "reading core/.* at ${RG_BASE} did not run (exit 128); no verdict" "$ERR" && [ ! -s "$OUT" ]; }

lt_run() { local p="$PATH"; [ -n "${2:-}" ] && p="$2:$PATH"
  PATH="$p" bash "$1" "$LTD" "$LT_BASE" "$LT_THEIRS" "$LTC" > "$OUT" 2> "$ERR"; }
arm_rlt_healthy() { local rc=0; lt_run "$1" || rc=$?; ARM_WHY="rc=$rc: $(tail -1 "$ERR" | cut -c1-120)"
  [ "$rc" -eq 0 ] && grep -q 'RETIRED-LAYER-TOKEN.*extensions/e\.md.*DEFERRED' "$OUT"; }
arm_rlt_cmt() { local rc=0; mkstub grep "$CMTPAT" 0 2; lt_run "$1" "$STUB" || rc=$?
  ARM_WHY="rc=$rc fired=$(fired): $(tail -1 "$ERR" | cut -c1-120)"
  failed_call 0 && [ "$rc" -eq 2 ] && grep -q 'did not run' "$ERR" && [ ! -s "$OUT" ]; }

# ================================================================================================
# A STAGING WRITE THAT FAILS. bash 3.2 stages every `<<<` here-string and `<<EOF` heredoc to a temp
# file, and when that write fails -- a full TMPDIR -- the command reads EMPTY input or does not run,
# and the script carries on. Each cell forces it under /bin/bash with `trap '' XFSZ; ulimit -f N`:
# RLIMIT_FSIZE fails the write with EFBIG and the ignored SIGXFSZ keeps the script alive, which is
# the full-disk shape. Under the default disposition the script is killed instead, a different and
# louder failure; a read-only TMPDIR does not force this at all on bash 3.2. Each world carries ONE
# payload larger than the limit and every other staged input smaller, so the subject can read its
# own staged copy whole or refuse, and nothing else.
#
# THE PRECONDITION IS A CALIBRATION THAT NEVER RUNS THE SUBJECT. The block is measured, not assumed;
# a here-string of each payload must FAIL with bash's own "cannot create temp file" line; a write of
# each other staged size must land whole. On a host where that does not hold -- a bash that feeds a
# small here-string through a pipe -- the defect cannot be expressed, and the cells report FIXTURE
# BROKEN rather than passing.
#
# A CELL ACCEPTS EXACTLY TWO OUTCOMES: the complete output, byte-identical to the same run without
# the limit, or the script's refusal (its refusal exit, its refusal line, and no row). rc 0 with a
# row missing or false is neither. The unforced run is part of the cell and must show its presence
# row, so a subject that emits nothing fails. STDOUT LEAVES THROUGH A PIPE: the limit binds every
# regular-file write the subject makes, its own stdout included, and a complete output larger than
# the limit would otherwise be cut and read as a defect.
# ================================================================================================
FBASH=/bin/bash
FW="$W/fx"; mkdir -p "$FW"
FX_READY=0; FX_BV=""; FX_BLK=0; FX_N=16; FX_CAL_FAILS=0; FXA_N=0
if [ -x "$FBASH" ]; then
  FX_BV="$("$FBASH" -c 'printf %s "$BASH_VERSION"')"
  # `ulimit -f` counts in BLOCKS; one block is what a limit of 1 lets through.
  "$FBASH" -c 'trap "" XFSZ; ulimit -f 1; printf "%08192d" 0 > "$1"' _ "$FW/blk" 2>/dev/null
  FX_BLK="$(wc -c < "$FW/blk" 2>/dev/null | tr -d ' ')"
  case "$FX_BLK" in ''|*[!0-9]*) FX_BLK=0 ;; esac
fi
FX_L=$((FX_N * FX_BLK))

# --- hard-blockers: 200 HARD rows supplied, and a report naming every one ------------------------
# BOTH rows flags with rc 0, always: without either, a refusal pre-empts the loops on both sides.
: > "$FW/hb-ld"
awk 'BEGIN { for (i = 0; i < 200; i++) printf "HARD-UNREGISTERED-CORE-DRIFT\tskills/ai-dlc/steps/file-number-%04d-padding-padding.md\tx\n", i }' > "$FW/hb-ud"
{ echo "# report naming every blocker"; cut -f2 "$FW/hb-ud"; } > "$FW/hb-report.md"
cut -f1,2 "$FW/hb-ud" > "$FW/hb-payload"
# --- relabel: 700 core check anchors, and separately 700 core rules; one colliding extension -----
# Its OWN, lower limit: relabel greps the extension once per anchor, so a world big enough to pass
# 16 blocks cost 14 s a run (measured, 4000 anchors) and this world is run by four cells, their
# controls, a mutant and the base copy. 700 anchors are 2.6 KB, above a 2-block limit.
FX_RX_N=2
RXF="$FW/rx"; mkdir -p "$RXF/.claude/skills/ai-dlc/extensions"
awk 'BEGIN { for (i = 1; i <= 700; i++) printf "### %d. Check title\nbody\n", i }' > "$RXF/.claude/skills/ai-dlc/gate-validation.md"
printf -- '---\nkind: check\nid: mine\nhooks: gate-validation.md\n---\n\n### 24. My check\ntext\n' > "$RXF/.claude/skills/ai-dlc/extensions/x.md"
RXR="$FW/rxr"; mkdir -p "$RXR/.claude/skills/ai-dlc/extensions"
awk 'BEGIN { for (i = 1; i <= 700; i++) printf "### Rule %d -- Title\nbody\n", i }' > "$RXR/.claude/skills/ai-dlc/SKILL.md"
printf -- '---\nkind: check\nid: mine\nhooks: SKILL.md\n---\n\n### Rule 24 -- Mine\ntext\n' > "$RXR/.claude/skills/ai-dlc/extensions/x.md"
awk 'BEGIN { for (i = 1; i <= 700; i++) print i }' | sort -u > "$FW/rx-payload"
# --- retired-layer-contract: a release retiring two rulebook paths; a 20 KB layer file citing one ---
RFD="$FW/rlcd"; RFC="$FW/rlcc"; mkdir -p "$RFD/core/skills/ai-dlc/steps"
printf -- '- Label: `/cmd\nuse {tok}\n' > "$RFD/core/skills/ai-dlc/steps/a.md"
printf 'small\n' > "$RFD/core/skills/ai-dlc/steps/b.md"; printf 'small\n' > "$RFD/core/skills/ai-dlc/steps/c.md"
gitq -C "$RFD" init -q; gitq -C "$RFD" add -A; gitq -C "$RFD" commit -qm base
RF_BASE="$(git -C "$RFD" rev-parse HEAD)"
gitq -C "$RFD" rm -q core/skills/ai-dlc/steps/b.md core/skills/ai-dlc/steps/c.md; gitq -C "$RFD" commit -qm theirs
RF_THEIRS="$(git -C "$RFD" rev-parse HEAD)"
mkdir -p "$RFC/.claude/skills/ai-dlc/extensions" "$RFC/.claude/skills/ai-dlc/overrides"
{ echo "see steps/b.md for the gate"; head -c 20000 /dev/zero | tr '\0' p; echo; } > "$RFC/.claude/skills/ai-dlc/extensions/e.md"
printf 'see .claude/skills/ai-dlc/steps/c.md and core/skills/ai-dlc/steps/b.md\n' > "$RFC/.claude/skills/ai-dlc/overrides/o.md"
printf 'nothing here\n' > "$RFC/.claude/skills/ai-dlc/extensions/n.md"
# --- warn-shadowed-local-validators: a closed entry naming 901 basenames; one naming a single one --
ws_world() { # ws_world <dir> <padding names> -- a closed ledger entry for validate-zz.sh, forks under the home
  mkdir -p "$1/_bmad-output/ai-dlc-update" "$1/scripts/ai-dlc" "$1/scripts/ai-dlc-local/sub" "$1/.claude"
  echo 'echo core' > "$1/scripts/ai-dlc/validate-zz.sh"; echo 'echo fork' > "$1/scripts/ai-dlc-local/validate-zz.sh"
  { printf '# ledger\n\n## FIXTURE-ENTRY — fork of validate-zz.sh\n\nADOPTED UPSTREAM in 0.1.0.\n\n'
    awk -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf "names aaaa-padding-name-%04d.sh\n", i }'
  } > "$1/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
}
WSF="$FW/ws"; ws_world "$WSF" 900; echo 'echo fork2' > "$WSF/scripts/ai-dlc-local/sub/validate-zz.sh"
grep -oE '[A-Za-z0-9._-]+\.sh' "$WSF/_bmad-output/ai-dlc-update/push-candidate-ledger.md" | sort -u > "$FW/ws-payload"
WS6="$FW/ws6"; ws_world "$WS6" 0
# The lib.sh emitter the script interpolates, read beside the subject without running the subject.
( . "$RC_/lib.sh" >/dev/null 2>&1; ledger_entry_awk ) > "$FW/ws6-payload" 2>/dev/null
# --- retired-tokens: TWO paths, b then z; z's blob is EXACTLY the limit, the one-byte window -------
# `git show` writes the L-byte blob whole, and a here-string of it needs L+1. At base the failed
# here-string ran no rt_toks, so z read b's token files: a FALSE row and the true one lost, rc 0.
fx_blob() { # fx_blob <first-line> <bytes> <out> -- <first-line>, a newline, then `p` to exactly <bytes>
  printf '%s\n' "$1" > "$3"; head -c "$(( $2 - ${#1} - 1 ))" /dev/zero | tr '\0' p >> "$3"; }
RTD="$FW/rtd"; RTC="$FW/rtc"; FXRT_B=""; FXRT_T=""
if [ "$FX_L" -gt 0 ]; then
  mkdir -p "$RTD/core/scripts" "$RTC/scripts/ai-dlc"
  fx_blob 'x=$ROOT/old-z' "$FX_L" "$RTD/core/scripts/z.sh"; printf 'x=$ROOT/old-b\nsmall\n' > "$RTD/core/scripts/b.sh"
  gitq -C "$RTD" init -q; gitq -C "$RTD" add -A; gitq -C "$RTD" commit -qm base
  FXRT_B="$(git -C "$RTD" rev-parse HEAD)"
  fx_blob 'x=$ROOT/new-z' "$FX_L" "$RTD/core/scripts/z.sh"; printf 'x=$ROOT/new-b\nsmall\n' > "$RTD/core/scripts/b.sh"
  gitq -C "$RTD" add -A; gitq -C "$RTD" commit -qm theirs
  FXRT_T="$(git -C "$RTD" rev-parse HEAD)"
  git -C "$RTD" show "${FXRT_B}:core/scripts/z.sh" > "$FW/rt-payload"
  git -C "$RTD" show "${FXRT_B}:core/scripts/b.sh" > "$RTC/scripts/ai-dlc/b.sh"
  { cat "$FW/rt-payload"; echo; echo 'uses $ROOT/old-b too'; } > "$RTC/scripts/ai-dlc/z.sh"
  printf 'X\tcore/scripts/b.sh\tscripts/ai-dlc/b.sh\tCLASSIFY\nX\tcore/scripts/z.sh\tscripts/ai-dlc/z.sh\tCLASSIFY\n' > "$FW/rt-rows"
fi
# --- retired-layer-contract, the path arm's OWN staging: ONE retired rulebook path whose name is 493
# bytes. Its spellings file (three spellings, 1537 B) is then the one staged write above a 1-block
# limit, while the retired-path set (513 B) and the tree listing it is a subset of stay below it. A
# retired-path SET above the limit is not constructible: the base tree listing, a superset of it, is
# written first, and the run refuses there on every copy. The file name exceeds NAME_MAX, so the
# path exists only in git, added by plumbing. The consumer cites the THIRD spelling alone, so a
# truncated spellings file (the first two, cut) cannot match it by a prefix.
FX_RLS_N=1
RLSD="$FW/rlsd"; RLSC="$FW/rlsc"; mkdir -p "$RLSD/core/skills/ai-dlc/steps" "$RLSC/.claude/skills/ai-dlc/extensions"
RLS_NAME="$(head -c 493 /dev/zero | tr '\0' r)"
RLS_P="core/team-roles/${RLS_NAME}.md"
printf -- '- Label: `/cmd\n' > "$RLSD/core/skills/ai-dlc/steps/a.md"
gitq -C "$RLSD" init -q; gitq -C "$RLSD" add -A
_rls_b="$(printf 'x\n' | git -C "$RLSD" hash-object -w --stdin)"
gitq -C "$RLSD" update-index --add --cacheinfo "100644,${_rls_b},${RLS_P}"; gitq -C "$RLSD" commit -qm base
RLS_BASE="$(git -C "$RLSD" rev-parse HEAD)"
gitq -C "$RLSD" update-index --force-remove -- "$RLS_P"; gitq -C "$RLSD" commit -qm theirs
RLS_THEIRS="$(git -C "$RLSD" rev-parse HEAD)"
printf 'see team-roles/%s.md\n' "$RLS_NAME" > "$RLSC/.claude/skills/ai-dlc/extensions/cites.md"
printf '%s\n.claude/team-roles/%s.md\nteam-roles/%s.md\n' "$RLS_P" "$RLS_NAME" "$RLS_NAME" > "$FW/rls-payload"
# --- retired-layer-contract: a LISTED layer file cat cannot open (mode 000; not expressible as root)
RLUC="$FW/rluc"; mkdir -p "$RLUC/.claude/skills/ai-dlc/extensions"
printf 'see steps/b.md for the gate\n' > "$RLUC/.claude/skills/ai-dlc/extensions/e.md"
printf 'see steps/c.md too\n' > "$RLUC/.claude/skills/ai-dlc/extensions/z.md"; chmod 000 "$RLUC/.claude/skills/ai-dlc/extensions/z.md"
# --- relabel --apply, ORDER: a check pass that WOULD relabel `### 24.`, then an oversize RULE set. The
# check-anchor set is 30 numbers (small); the rule set is 700 (above the 2-block limit). A refusal
# placed after the check pass moves the extension first.
RXO="$FW/rxo"; mkdir -p "$RXO/.claude/skills/ai-dlc/extensions"
awk 'BEGIN { for (i = 1; i <= 30; i++) printf "### %d. Check title\nbody\n", i; for (i = 1; i <= 700; i++) printf "### Rule %d -- Title\nbody\n", i }' > "$RXO/.claude/skills/ai-dlc/gate-validation.md"
printf -- '---\nkind: check\nid: mine\nhooks: gate-validation.md\n---\n\n### 24. My check\ntext\n' > "$RXO/.claude/skills/ai-dlc/extensions/x.md"
awk 'BEGIN { for (i = 1; i <= 30; i++) print i }' | sort -u > "$FW/rxo-nums"
# --- readopt-override: a `shadows:` list whose anchor ids are the ONE staged write above the limit.
# Six ids naming a 200-byte heading (1206 B), then `Two`, which a truncated id file loses. Every id
# resolves, so the unforced run is STALE-CORE-TEXT with seven lines. All three `shadow_ids` writes
# stage these same bytes, so the anchor-resolution check refuses too if the scans' status is
# dropped -- the refusal MESSAGE is what says which read refused.
FX_RO_N=1
ROD="$FW/rod"; ROC="$FW/roc"; mkdir -p "$ROD/core/skills/ai-dlc/steps" "$ROC/.claude/skills/ai-dlc/overrides"
RO_HEAD="Sec $(head -c 196 /dev/zero | tr '\0' q)"
RO_L2="The second section clause that upstream rewrites in this release too."
RO_L2N="The second section clause, rewritten upstream in this release instead."
printf '# X\n\n## %s\n\n%s\n%s\n\n## Two\n\n%s\n' "$RO_HEAD" "$L_OLD" "$L_KEEP" "$RO_L2" > "$ROD/core/skills/ai-dlc/steps/x.md"
gitq -C "$ROD" init -q; gitq -C "$ROD" add -A; gitq -C "$ROD" commit -qm base
RO_BASE="$(git -C "$ROD" rev-parse HEAD)"
printf '# X\n\n## %s\n\n%s\n%s\n\n## Two\n\n%s\n' "$RO_HEAD" "$L_NEW" "$L_KEEP" "$RO_L2N" > "$ROD/core/skills/ai-dlc/steps/x.md"
gitq -C "$ROD" add -A; gitq -C "$ROD" commit -qm theirs
RO_THEIRS="$(git -C "$ROD" rev-parse HEAD)"
ROF="$ROC/.claude/skills/ai-dlc/overrides/steps__x.md"
_ro_sh=""; for _i in 1 2 3 4 5 6; do _ro_sh="${_ro_sh}steps/x.md#${RO_HEAD}, "; done
printf -- '---\nshadows: %ssteps/x.md#Two\nbase_sha: %s\nreason: fixture\n---\n\n## %s\n\n%s\n%s\n\n## Two\n\n%s\n' \
  "$_ro_sh" "$RO_BASE" "$RO_HEAD" "$L_OLD" "$L_KEEP" "$RO_L2" > "$ROF"
{ for _i in 1 2 3 4 5 6; do printf '%s\n' "$RO_HEAD"; done; echo Two; } > "$FW/ro-payload"

# --- the calibration ---------------------------------------------------------------------------
fx_hs_fails() { # fx_hs_fails <limit-blocks> <payload-file> -> 0 when a here-string of it cannot be staged
  local r=0
  "$FBASH" -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; x="$(cat "$2")"; cat <<<"$x" > /dev/null' _ "$1" "$2" 2> "$FW/cal.err" || r=$?
  [ "$r" -ne 0 ] && [ "$r" -ne 97 ] && grep -q 'cannot create temp file for here document' "$FW/cal.err"; }
fx_writes() { # fx_writes <limit-blocks> <bytes> -> 0 when a write of exactly <bytes> lands whole
  local r=0 got
  "$FBASH" -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; head -c "$2" /dev/zero > "$3"' _ "$1" "$2" "$FW/cal.w" 2>/dev/null || r=$?
  got="$(wc -c < "$FW/cal.w" | tr -d ' ')"
  [ "$r" -eq 0 ] && [ "$got" -eq "$2" ]; }
fx_sz() { wc -c < "$1" | tr -d ' '; }
fx_cal() { # fx_cal <cell> <limit-blocks> <payload-file> [<other staged size>...]
  local c="$1" n="$2" p="$3" s miss=""
  shift 3
  if ! fx_hs_fails "$n" "$p"; then
    bad "FIXTURE BROKEN: calibration [$c]: a here-string of the $(fx_sz "$p")-byte payload did NOT fail under ulimit -f $n ($FBASH $FX_BV, block $FX_BLK B), so this host cannot express the defect: $(head -1 "$FW/cal.err")"
    FX_CAL_FAILS=$((FX_CAL_FAILS+1)); return; fi
  for s in "$@"; do fx_writes "$n" "$s" || miss="$miss $s"; done
  if [ -n "$miss" ]; then
    bad "FIXTURE BROKEN: calibration [$c]: a write of$miss byte(s) did not land whole under ulimit -f $n, so the fixed script's own staging would fail there too"
    FX_CAL_FAILS=$((FX_CAL_FAILS+1)); return; fi
  s="$*"; [ -n "$s" ] || s="none"
  ok "calibration [$c]: under ulimit -f $n ($(( n * FX_BLK )) B, $FBASH $FX_BV) a here-string of the $(fx_sz "$p")-byte payload fails; other staged size(s) land whole: $s"
}

# --- the cells ---------------------------------------------------------------------------------
fx_ready() { [ "$FX_READY" -eq 1 ] || { ARM_WHY="the staging-write calibration did not hold, so no forced cell can be read"; return 1; }; }
fx_run() { # fx_run <limit-blocks, 0 = none> <out> <err> <script> <args...> -> FX_RC
  local n="$1" o="$2" e="$3"
  shift 3
  FX_RC=0
  if [ "$n" -eq 0 ]; then "$FBASH" "$@" 2> "$e" | cat > "$o" || FX_RC=$?
  else "$FBASH" -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; shift; exec "$@"' _ "$n" "$FBASH" "$@" 2> "$e" | cat > "$o" || FX_RC=$?
  fi
}
fx_healthy() { # fx_healthy <script> <rc> <presence-ERE> <args...> -- the unforced run, into $FW/h.out
  local s="$1" hrc="$2" hpat="$3"
  shift 3
  fx_run 0 "$FW/h.out" "$FW/h.err" "$s" "$@"
  ARM_WHY="unforced rc=$FX_RC (want $hrc), presence row $(grep -cE -- "$hpat" "$FW/h.out")"
  [ "$FX_RC" -eq "$hrc" ] && grep -qE -- "$hpat" "$FW/h.out"; }
fx_cell() { # fx_cell <script> <limit> <rc> <presence-ERE> <refusal-rc> <refusal-ERE> <args...>
  local s="$1" n="$2" hrc="$3" hpat="$4" frc="$5" fpat="$6"
  shift 6
  fx_ready || return 1
  fx_healthy "$s" "$hrc" "$hpat" "$@" || { ARM_WHY="no healthy baseline: $ARM_WHY"; return 1; }
  fx_run "$n" "$OUT" "$ERR" "$s" "$@"
  if [ "$FX_RC" -eq "$hrc" ] && cmp -s "$OUT" "$FW/h.out"; then
    ARM_WHY="complete: rc=$FX_RC, stdout byte-identical to the unforced run ($(grep -c . "$OUT") line(s))"; return 0; fi
  if [ "$FX_RC" -eq "$frc" ] && [ ! -s "$OUT" ] && grep -qE -- "$fpat" "$ERR"; then
    ARM_WHY="refused: rc=$FX_RC, $(grep -E -- "$fpat" "$ERR" | head -1 | cut -c1-100)"; return 0; fi
  ARM_WHY="rc=$FX_RC, $(grep -c . "$OUT") stdout line(s) against $(grep -c . "$FW/h.out") unforced -- neither the complete output nor a refusal: $(grep -v '^$' "$ERR" | tail -1 | sed 's#.*/##' | cut -c1-110)"
  return 1; }
HB_REF='^hard-blockers: REFUSED — '
HB_PRINT_ROW='^HARD-UNREGISTERED-CORE-DRIFT +skills/ai-dlc/steps/file-number-0199-padding-padding\.md$'
arm_fx_hb_healthy() { fx_healthy "$1" 0 '\(200 total\)' --check "$FW/hb-report.md" \
  --ld-rows "$FW/hb-ld" --ld-rc 0 --ud-rows "$FW/hb-ud" --ud-rc 0 "$FW" base "$FW" theirs; }
arm_fx_hb_check() { fx_cell "$1" "$FX_N" 0 '\(200 total\)' 1 "$HB_REF" --check "$FW/hb-report.md" \
  --ld-rows "$FW/hb-ld" --ld-rc 0 --ud-rows "$FW/hb-ud" --ud-rc 0 "$FW" base "$FW" theirs; }
arm_fx_hb_print() { fx_cell "$1" "$FX_N" 0 "$HB_PRINT_ROW" 1 "$HB_REF" \
  --ld-rows "$FW/hb-ld" --ld-rc 0 --ud-rows "$FW/hb-ud" --ud-rc 0 "$FW" base "$FW" theirs; }
RX_ROW='^  \+  ### 24\. \[ext:mine\] My check$'; RXR_ROW='^  \+  ### Rule 24 \[ext:mine\] -- Mine$'
arm_fx_rx_healthy() { fx_healthy "$1" 1 "$RX_ROW" "$RXF"; }
arm_fx_rx()  { fx_cell "$1" "$FX_RX_N" 1 "$RX_ROW" 2 '^relabel: REFUSED — ' "$RXF"; }
arm_fx_rxr() { fx_cell "$1" "$FX_RX_N" 1 "$RXR_ROW" 2 '^relabel: REFUSED — ' "$RXR"; }
# `--apply` writes the extension, so every run gets a fresh copy of the world. The refusal must leave
# the extension byte-identical: it has to come BEFORE the first `mv` for that extension.
arm_fx_rx_apply() { local d x ck
  fx_ready || return 1
  FXA_N=$((FXA_N+1)); d="$FW/rxa.$FXA_N"; x="$d/.claude/skills/ai-dlc/extensions/x.md"
  cp -R "$RXF" "$d" || { ARM_WHY="could not copy the relabel world"; return 1; }
  ck="$(cksum < "$x")"
  fx_run "$FX_RX_N" "$OUT" "$ERR" "$1" "$d" --apply
  if [ "$FX_RC" -eq 0 ] && grep -qx '### 24\. \[ext:mine\] My check' "$x"; then
    ARM_WHY="complete: rc=0 and the heading was labelled"; return 0; fi
  if [ "$FX_RC" -eq 2 ] && grep -qE '^relabel: REFUSED — ' "$ERR" && [ "$(cksum < "$x")" = "$ck" ]; then
    ARM_WHY="refused: rc=2 and the extension is byte-identical"; return 0; fi
  ARM_WHY="rc=$FX_RC, extension $([ "$(cksum < "$x")" = "$ck" ] && echo unchanged || echo CHANGED) and unlabelled: $(grep -v '^$' "$OUT" | tail -1 | cut -c1-90)"
  return 1; }
# ORDER: the check pass WOULD relabel `### 24.`, and only the rule set is oversize. Refusing after
# the check pass leaves rc 2 over a MOVED extension, which neither accepted outcome allows. The
# unforced run must label the heading, so a copy that never reaches the pass cannot pass.
arm_fx_rxo_apply() { local d x ck
  fx_ready || return 1
  FXA_N=$((FXA_N+1)); d="$FW/rxo.$FXA_N"; x="$d/.claude/skills/ai-dlc/extensions/x.md"
  cp -R "$RXO" "$d" || { ARM_WHY="could not copy the relabel-order world"; return 1; }
  fx_run 0 "$OUT" "$ERR" "$1" "$d" --apply
  if ! { [ "$FX_RC" -eq 0 ] && grep -qx '### 24\. \[ext:mine\] My check' "$x"; }; then
    ARM_WHY="no healthy baseline: unforced --apply rc=$FX_RC did not label the heading"; return 1; fi
  rm -rf "$d"; cp -R "$RXO" "$d" || { ARM_WHY="could not re-copy the relabel-order world"; return 1; }
  ck="$(cksum < "$x")"
  fx_run "$FX_RX_N" "$OUT" "$ERR" "$1" "$d" --apply
  if [ "$FX_RC" -eq 0 ] && grep -qx '### 24\. \[ext:mine\] My check' "$x"; then
    ARM_WHY="complete: rc=0 and the heading was labelled"; return 0; fi
  if [ "$FX_RC" -eq 2 ] && grep -qE '^relabel: REFUSED — the core rule-number set' "$ERR" && [ "$(cksum < "$x")" = "$ck" ]; then
    ARM_WHY="refused: rc=2 on the rule set and the extension is byte-identical"; return 0; fi
  ARM_WHY="rc=$FX_RC, extension $([ "$(cksum < "$x")" = "$ck" ] && echo unchanged || echo CHANGED): $(grep -v '^$' "$ERR" | tail -1 | cut -c1-90)"
  return 1; }
# readopt-override --check: the anchor-id staging is the one oversize write. The refusal ERE is the
# SUPERSEDED-LINE scan's, the first reader of the ids; a copy whose scans ignore their staging status
# refuses later, in the anchor-resolution check, and does not match.
arm_fx_ro_healthy() { fx_healthy "$1" 1 '^STALE-CORE-TEXT ' "$ROD" "$RO_THEIRS" "$ROC" "$ROF" --check; }
arm_fx_ro() { fx_cell "$1" "$FX_RO_N" 1 '^STALE-CORE-TEXT ' 2 '^readopt-override: the superseded-line scan ' \
  "$ROD" "$RO_THEIRS" "$ROC" "$ROF" --check; }
RLC_ROW='extensions/e\.md.path:core/skills/ai-dlc/steps/b\.md$'
arm_fx_rlc_healthy() { fx_healthy "$1" 0 "$RLC_ROW" "$RFD" "$RF_BASE" "$RF_THEIRS" "$RFC"; }
arm_fx_rlc() { fx_cell "$1" "$FX_N" 0 "$RLC_ROW" 2 '^retired-layer-contract: .*no verdict' "$RFD" "$RF_BASE" "$RF_THEIRS" "$RFC"; }
# The path arm's own staging. The refusal ERE names the SPELLINGS write, so a copy that refuses
# somewhere else under the limit is not read as this refusal.
RLS_ROW='extensions/cites\.md.path:core/team-roles/r+\.md$'
arm_fx_rls_healthy() { fx_healthy "$1" 0 "$RLS_ROW" "$RLSD" "$RLS_BASE" "$RLS_THEIRS" "$RLSC"; }
arm_fx_rls() { fx_cell "$1" "$FX_RLS_N" 0 "$RLS_ROW" 2 '^retired-layer-contract: staging the spellings of core/team-roles/r+\.md did not run' \
  "$RLSD" "$RLS_BASE" "$RLS_THEIRS" "$RLSC"; }
# A listed layer file cat cannot open: exit 2 naming THAT file, no row. No limit; mode 000, so the
# call sites skip it as root, where the file reads.
arm_rlc_unread_layer() { local rc=0
  "$FBASH" "$1" "$RFD" "$RF_BASE" "$RF_THEIRS" "$RLUC" > "$OUT" 2> "$ERR" || rc=$?
  ARM_WHY="rc=$rc, $(grep -c . "$OUT") row(s): $(grep -v '^$' "$ERR" | tail -1 | cut -c1-110)"
  [ "$rc" -eq 2 ] && [ ! -s "$OUT" ] && grep -q '^retired-layer-contract: reading the layer file \.claude/skills/ai-dlc/extensions/z\.md did not run' "$ERR"; }
WS_REF='^warn-shadowed-local-validators: REFUSED — '
arm_fx_ws_healthy()  { fx_healthy "$1" 0 'RETIRE-CANDIDATE.scripts/ai-dlc-local/sub/validate-zz\.sh' --root "$WSF"; }
arm_fx_ws_closed()   { fx_cell "$1" "$FX_N" 0 'RETIRE-CANDIDATE.scripts/ai-dlc-local/sub/validate-zz\.sh' 2 "$WS_REF" --root "$WSF"; }
arm_fx_ws6_healthy() { fx_healthy "$1" 0 'RETIRE-CANDIDATE.scripts/ai-dlc-local/validate-zz\.sh' --root "$WS6"; }
arm_fx_ws_emitter()  { fx_cell "$1" 2 0 'RETIRE-CANDIDATE.scripts/ai-dlc-local/validate-zz\.sh' 2 "$WS_REF" --root "$WS6"; }
RT_ROW='core/scripts/z\.sh.\$ROOT/old-z$'
arm_fx_rt_healthy() { fx_healthy "$1" 0 "$RT_ROW" --bucket-rows "$FW/rt-rows" "$RTD" "$FXRT_B" "$FXRT_T" "$RTC" \
  && ! grep -q 'core/scripts/z\.sh.\$ROOT/old-b' "$FW/h.out"; }
arm_fx_rt() { fx_cell "$1" "$FX_N" 0 "$RT_ROW" 2 '^retired-tokens: .*no verdict' --bucket-rows "$FW/rt-rows" "$RTD" "$FXRT_B" "$FXRT_T" "$RTC"; }
# derivation-differential has no forced cell (its sites are held by r5 alone); this is the positive
# conjunct its spelling mutant needs -- the copy parses and RUNS as far as its argument check.
arm_dd_usage() { local rc=0; bash "$1" > "$OUT" 2> "$ERR" || rc=$?
  ARM_WHY="rc=$rc: $(head -1 "$OUT" | cut -c1-80)"
  [ "$rc" -eq 2 ] && grep -q 'usage.*expected four arguments' "$OUT"; }

# --- lib.sh's awk EMITTERS under a write limit. Each arm takes a lib.sh PATH. The capture runs in
# /bin/bash with `trap '' XFSZ; ulimit -f 0` set AFTER lib.sh is sourced, as `x="$(emitter)"`, and
# `$x` leaves through a PIPE: under the limit any regular-file write fails, and a printf redirected
# to a file there truncates and leaks its unwritten buffer into the next `$( )`. Stderr rides the
# same pipe, because a stderr file is a regular-file write too. The reference is the TREE's lib.sh,
# unforced, captured the same way; each cell first proves its own lib emits the reference unforced,
# so a copy that emits nothing, or other bytes, has no baseline and fails.
em_run() { # em_run <lib> <fn> <limit-blocks, - = none> <out> -> EM_RC
  EM_RC=0
  "$FBASH" -c 'trap "" XFSZ; . "$1" >/dev/null 2>&1 || exit 96
    if [ "$3" != - ]; then ulimit -f "$3" || exit 97; fi
    x="$("$2")"; r=$?; printf "%s\n" "$x"; exit "$r"' _ "$1" "$2" "$3" 2>&1 | cat > "$4" || EM_RC=$?; }
EM_READY=0
em_ref() { # em_ref <fn> <presence> -- the tree's unforced bytes, into $FW/em-ref.<fn>
  em_run "$RC_/lib.sh" "$1" - "$FW/em-ref.$1"
  [ "$EM_RC" -eq 0 ] && grep -qF -- "$2" "$FW/em-ref.$1"; }
em_cell() { # em_cell <lib> <fn>
  [ "$EM_READY" -eq 1 ] || { ARM_WHY="the emitter calibration did not hold, so no emitter cell can be read"; return 1; }
  em_run "$1" "$2" - "$FW/em-h.$2"
  if ! { [ "$EM_RC" -eq 0 ] && cmp -s "$FW/em-h.$2" "$FW/em-ref.$2"; }; then
    ARM_WHY="no healthy baseline: unforced rc=$EM_RC, $(wc -c < "$FW/em-h.$2" | tr -d ' ') B against the tree's $(wc -c < "$FW/em-ref.$2" | tr -d ' ') B"; return 1; fi
  em_run "$1" "$2" 0 "$FW/em-f.$2"
  ARM_WHY="forced rc=$EM_RC, $(wc -c < "$FW/em-f.$2" | tr -d ' ') B against $(wc -c < "$FW/em-ref.$2" | tr -d ' ') B unforced: $(head -1 "$FW/em-f.$2" | sed 's#.*/##' | cut -c1-90)"
  [ "$EM_RC" -eq 0 ] && cmp -s "$FW/em-f.$2" "$FW/em-ref.$2"; }
arm_em_nrm()    { em_cell "$1" nrm_awk; }
arm_em_ledger() { em_cell "$1" ledger_entry_awk; }
arm_em_label()  { em_cell "$1" backlog_entry_label_awk; }
# Each emitter mutant's healthy twin: the OTHER two cells still pass on it, so a mutant that kills
# its own cell and not its neighbours shows each cell sees its own emitter and no other.
arm_em_hx_nrm()    { arm_em_ledger "$1" && arm_em_label "$1"; }
arm_em_hx_ledger() { arm_em_nrm "$1" && arm_em_label "$1"; }
arm_em_hx_label()  { arm_em_nrm "$1" && arm_em_ledger "$1"; }

# --- the NON-ASCII path worlds. The ASCII row is the control, required in every run: a copy that
# never reached its loop has no plain.sh row either, and fails the healthy arm.
qa_run() { bash "$1" "$QAD" "$QA_BASE" "$QA_THEIRS" "$QAC" > "$OUT" 2> "$ERR"; }
qa_why() { ARM_WHY="rc=$1 rows=[$(LC_ALL=C cut -f2 "$OUT" | LC_ALL=C cat -v | tr '\n' '|')] $(grep -v '^$' "$ERR" | tail -1 | cut -c1-80)"; }
arm_qa_plain() { local rc=0; qa_run "$1" || rc=$?; qa_why "$rc"
  [ "$rc" -eq 0 ] && grep -qF "RETIRED-CONTRACT-TOKEN${NT}core/scripts/plain.sh${NT}\$ROOT/old-plain" "$OUT"; }
arm_qa_cafe() { local rc=0; qa_run "$1" || rc=$?; qa_why "$rc"
  [ "$rc" -eq 0 ] && grep -qF "RETIRED-CONTRACT-TOKEN${NT}core/scripts/plain.sh${NT}" "$OUT" \
    && grep -qF "RETIRED-CONTRACT-TOKEN${NT}core/scripts/${QU}.sh${NT}\$ROOT/old-caf" "$OUT"; }
qb_run() { bash "$1" "$QBD" "$QB_BASE" "$QB_THEIRS" "$QBC" > "$OUT" 2> "$ERR"; }
qb_why() { ARM_WHY="rc=$1 rows=[$(LC_ALL=C cut -f2,4 "$OUT" | LC_ALL=C cat -v | tr '\n\t' '| ')] $(grep -v '^$' "$ERR" | tail -1 | cut -c1-80)"; }
QB_ROW() { printf 'R\tcore/scripts/%s.sh\tscripts/%s.sh\tRELOCATE-MOVE+consumer-edited' "$1" "$1"; }
arm_qb_plain() { local rc=0; qb_run "$1" || rc=$?; qb_why "$rc"
  [ "$rc" -eq 0 ] && grep -qF "$(QB_ROW plain)" "$OUT"; }
arm_qb_cafe() { local rc=0; qb_run "$1" || rc=$?; qb_why "$rc"
  [ "$rc" -eq 0 ] && grep -qF "$(QB_ROW plain)" "$OUT" && grep -qF "$(QB_ROW "$QU")" "$OUT"; }
# QC drives self-update-gate.sh, which loads machinery_paths() out of the preclassify.sh BESIDE it and
# runs that same file for the rows, so a subject here is a gate inside a directory copy. The CARRY row
# must name the RAW core path AND the mapped consumer path: the base emitted a C-quoted row whose
# consumer column was the quoted core path, which no step-2 slice filter can match.
qc_run() { local c; c="$(mktemp -d "$W/qc-run.XXXXXX")" && cp -R "$QCC/." "$c/" \
  && bash "$1" "$QCD" "$QC_BASE" "$QC_THEIRS" "$c" > "$OUT" 2> "$ERR"; }
qc_why() { ARM_WHY="rc=$1 rows=[$(LC_ALL=C cut -f1,2 "$OUT" | LC_ALL=C cat -v | tr '\n\t' '| ')] $(grep -v '^$' "$ERR" | tail -1 | cut -c1-80)"; }
QC_ROW() { printf "SELF-UPDATE-CARRY${NT}core/skills/ai-dlc-update/%s.md${NT}the consumer's copy at .claude/skills/ai-dlc-update/%s.md " "$1" "$1"; }
arm_qc_plain() { local rc=0; qc_run "$1" || rc=$?; qc_why "$rc"
  grep -qF "$(QC_ROW plain)" "$OUT"; }
arm_qc_cafe() { local rc=0; qc_run "$1" || rc=$?; qc_why "$rc"
  grep -qF "$(QC_ROW plain)" "$OUT" && grep -qF "$(QC_ROW "$QU")" "$OUT"; }

# --- r5: NO NON-COMMENT HERE-STRING in a file this release converted ------------------------------
# The seven files 2f598a86 converted, and only those: the bootstrapping files (apply.sh, lib.sh,
# preclassify.sh, emit-report.sh, self-update-fixtures.sh, ...) keep their sites and are not scoped.
# A `<<<` with a non-`<` on both sides, on a line that is not a whole-line comment; the line is padded
# with a space each side so a here-string at either end still has its neighbour. FP set, measured
# over the seven at the tip: the one `<<<` substring left is readopt-override.sh's `<<<<<<<` inside
# an echo, which the grammar excludes -- the self-probe below seeds that exact line. `<<EOF` loops
# are not counted: readopt-override.sh keeps two in code this release did not touch.
R5_FILES="hard-blockers.sh relabel-extension-checks.sh retired-layer-contract.sh retired-tokens.sh warn-shadowed-local-validators.sh readopt-override.sh derivation-differential.sh"
r5_scan() { # r5_scan <file> -> "<non-comment lines> <here-string lines> [<line numbers>]"
  awk '/^[[:blank:]]*#/ { next } { n++; if ((" " $0 " ") ~ /[^<]<<<[^<]/) { h++; at = at " " FNR } } END { printf "%d %d%s\n", n, h, at }' "$1"; }
arm_r5() { local r n h
  r="$(r5_scan "$1")" || { ARM_WHY="awk could not scan $1"; return 1; }
  n="${r%% *}"; h="${r#* }"; h="${h%% *}"
  ARM_WHY="$n non-comment line(s) scanned, $h here-string line(s)$( [ "$h" -gt 0 ] && printf ' at%s' "${r#* * }" )"
  [ "$n" -gt 0 ] && [ "$h" -eq 0 ]; }

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
run_arm arm_ta_healthy  "$S_RT"  "retired-tokens: a path ABSENT at base and one ABSENT at theirs are skipped, not refused; the token row stands"
run_arm arm_rg_healthy  "$S_RLC" "retired-layer-contract: a rulebook path both refs ship yields NO path: row; the shape row stands"
run_arm arm_nw_both     "$S_RT"  "retired-tokens: a blob with a NUL at BOTH refs keeps its true row (nul.sh -> old-n) beside the ctl.sh row"
run_arm arm_nw_theirs   "$S_RT"  "retired-tokens: a NUL gained at theirs alone retires nothing (no FALSE q.sh row), the ctl.sh row stands"
run_arm arm_nw_cmt      "$S_RT"  "retired-tokens: a NUL before a comment '#' leaves the commented token a comment (no FALSE h.sh -> cmt-h row)"
run_arm arm_lw_c        "$S_RT"  "retired-tokens: a Latin-1 byte in a theirs blob under LC_ALL=C retires nothing, the ctl.sh row alone at rc 0"
if [ "$LW_UTF8" -eq 1 ]; then
  run_arm arm_lw_utf8   "$S_RT"  "retired-tokens: NO STUB, a Latin-1 theirs blob under a UTF-8 caller reads whole: the ctl.sh row alone at rc 0, no refusal, no FALSE alat.sh row"
else
  skip "arm_lw_utf8: locale en_US.UTF-8 is not installed (locale -a), so a UTF-8 tr cannot be driven here (this is not a pass)"
fi
run_arm arm_lw_trstatus "$S_RT"  "retired-tokens: the NUL strip (tr) of alat.sh's theirs blob fails -> exit 2 naming it, not FALSE keep rows at rc 0"

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
run_arm arm_ta_verify    "$S_RT"  "retired-tokens: git rev-parse of a ref exits 128 -> exit 2 'did not run ... no verdict', not an absent skip"
run_arm arm_ta_ls        "$S_RT"  "retired-tokens: git ls-tree of a path exits 128 -> exit 2, not an absent skip"
run_arm arm_ta_show      "$S_RT"  "retired-tokens: git show of ONE side of the row's file exits 128 -> exit 2, not a lost row"
run_arm arm_rg_theirs_ls "$S_RLC" "retired-layer-contract: the THEIRS rulebook listing exits 128 -> exit 2, no false path: row"
run_arm arm_rg_base_show "$S_RLC" "retired-layer-contract: every BASE rulebook blob read exits 128 -> exit 2, not a skipped body"

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

S_HB="$RC_/hard-blockers.sh"; S_WS="$RC_/warn-shadowed-local-validators.sh"; S_DD="$RC_/derivation-differential.sh"
echo "== a staging write that fails ($FBASH, trap '' XFSZ; ulimit -f): the calibration, which never runs a subject =="
if [ -z "$FX_BV" ] || [ "$FX_BLK" -le 0 ] || [ -z "$FXRT_B" ] || [ -z "$FXRT_T" ]; then
  bad "FIXTURE BROKEN: the staging-write cells need $FBASH (version '$FX_BV') and a measurable ulimit -f block (measured '$FX_BLK' B); every forced cell below is unreadable"
else
  _rtsz="$(fx_sz "$FW/rt-payload")"
  if [ "$_rtsz" -ne "$FX_L" ]; then
    bad "FIXTURE BROKEN: calibration [retired-tokens]: the z.sh blob is $_rtsz B, not exactly the $FX_L-byte limit, so the one-byte window (git show writes L, a here-string needs L+1) is not the one tested"
    FX_CAL_FAILS=$((FX_CAL_FAILS+1))
  else
    ok "calibration [retired-tokens]: the z.sh blob is exactly the limit, $_rtsz B (wc -c) = $FX_N x $FX_BLK"
  fi
  fx_cal hard-blockers "$FX_N" "$FW/hb-payload"
  fx_cal relabel "$FX_RX_N" "$FW/rx-payload" 2
  fx_cal retired-layer-contract "$FX_N" "$RFC/.claude/skills/ai-dlc/extensions/e.md" 64
  fx_cal warn-shadowed-closed "$FX_N" "$FW/ws-payload" "$(fx_sz "$FW/ws6-payload")"
  fx_cal warn-shadowed-emitter 2 "$FW/ws6-payload" 16
  fx_cal retired-tokens "$FX_N" "$FW/rt-payload" "$FX_L"
  # The spellings file is the payload; the retired-path set and the base tree listing (its superset)
  # must land whole, or the copy refuses before the site under test.
  fx_cal retired-layer-contract-spellings "$FX_RLS_N" "$FW/rls-payload" \
    "$(( ${#RLS_P} + 1 ))" "$(git -C "$RLSD" ls-tree -r --name-only "$RLS_BASE" | wc -c | tr -d ' ')"
  fx_cal relabel-order "$FX_RX_N" "$FW/rx-payload" "$(fx_sz "$FW/rxo-nums")"
  fx_cal readopt-override "$FX_RO_N" "$FW/ro-payload" "$(git -C "$ROD" show "${RO_BASE}:core/skills/ai-dlc/steps/x.md" | wc -c | tr -d ' ')"
  [ "$FX_CAL_FAILS" -eq 0 ] && FX_READY=1
fi
echo "== a staging write that fails: each cell prints the complete output or refuses, never rc 0 with a row missing or false =="
run_arm arm_fx_hb_check  "$S_HB"  "hard-blockers --check, 200 blockers: '(200 total)' or REFUSED exit 1, never '(0 total)'"
run_arm arm_fx_hb_print  "$S_HB"  "hard-blockers print, 200 blockers: every HARD row or REFUSED exit 1, never an empty region at rc 0"
run_arm arm_fx_rx        "$S_RX"  "relabel check pass, 700 anchors: the collision (exit 1) or REFUSED exit 2, never 'no collisions'"
run_arm arm_fx_rxr       "$S_RX"  "relabel rule pass, 700 rules: the collision (exit 1) or REFUSED exit 2, never 'no collisions'"
run_arm arm_fx_rx_apply  "$S_RX"  "relabel --apply: the heading labelled, or REFUSED exit 2 with the extension byte-identical"
run_arm arm_fx_rlc       "$S_RLC" "retired-layer-contract path arm, a 20 KB layer file: all 3 rows or refusal, never 2 rows at rc 0"
run_arm arm_fx_ws_closed "$S_WS"  "warn-shadowed-local-validators, 901 closed basenames: both forks or REFUSED exit 2, never 0 rows"
run_arm arm_fx_ws_emitter "$S_WS" "warn-shadowed-local-validators, lib.sh's entry emitter unstaged: the fork or REFUSED exit 2"
run_arm arm_fx_rt        "$S_RT"  "retired-tokens, z.sh blob at exactly the limit after b.sh: z -> old-z or refusal, never a FALSE z -> old-b"
run_arm arm_fx_rls       "$S_RLC" "retired-layer-contract path arm, a 1.5 KB spellings file: the path: row or the SPELLINGS refusal, never 0 rows at rc 0"
run_arm arm_fx_rxo_apply "$S_RX"  "relabel --apply, a relabel due in the check pass and an oversize rule set: labelled, or REFUSED exit 2 with the extension byte-identical"
run_arm arm_fx_ro        "$S_RO"  "readopt-override --check, an oversize anchor-id list: STALE-CORE-TEXT, or the superseded-line scan's refusal"
if [ "$(id -u)" -eq 0 ]; then
  skip "arm_rlc_unread_layer: running as root, which reads a mode-000 layer file, so the world is not expressible (this is not a pass)"
else
  run_arm arm_rlc_unread_layer "$S_RLC" "retired-layer-contract: a listed layer file cat cannot open refuses exit 2 naming it, no row"
fi

S_LIB="$RC_/lib.sh"; S_PC="$RC_/preclassify.sh"
echo "== lib.sh's awk emitters under ulimit -f 0: the calibration, which never sources lib.sh =="
# Both directions, in the capture shape the cells use: a heredoc captured under the limit FAILS with
# bash's own line, and a printf literal captured under the same limit lands whole.
_emc_h="$FW/em-cal-heredoc"; _emc_p="$FW/em-cal-printf"; _emc_hr=0; _emc_pr=0
if [ -z "$FX_BV" ]; then
  bad "FIXTURE BROKEN: the emitter cells need $FBASH, which did not run"
else
  "$FBASH" -c 'trap "" XFSZ; ulimit -f 0 || exit 97; x="$(cat <<EOF
calibration-heredoc-body
EOF
)"; r=$?; printf "%s\n" "$x"; exit "$r"' 2>&1 | cat > "$_emc_h" || _emc_hr=$?
  "$FBASH" -c 'trap "" XFSZ; ulimit -f 0 || exit 97; x="$(printf "%s\n" calibration-printf-body)"; r=$?; printf "%s\n" "$x"; exit "$r"' 2>&1 | cat > "$_emc_p" || _emc_pr=$?
  if [ "$_emc_hr" -ne 0 ] && [ "$_emc_hr" -ne 97 ] && grep -q 'cannot create temp file for here document' "$_emc_h" \
     && ! grep -q 'calibration-heredoc-body' "$_emc_h" \
     && [ "$_emc_pr" -eq 0 ] && [ "$(cat "$_emc_p")" = calibration-printf-body ]; then
    ok "calibration [lib emitters]: under ulimit -f 0 ($FBASH $FX_BV) a captured heredoc fails rc=$_emc_hr with no body, and a captured printf literal lands whole"
    if em_ref nrm_awk 'function nrm(s)' && em_ref ledger_entry_awk 'function ledger_entry_shape(' \
       && em_ref backlog_entry_label_awk 'function backlog_entry_label('; then
      EM_READY=1
      ok "calibration [lib emitters]: the tree's three emitters, unforced, emit $(wc -c < "$FW/em-ref.nrm_awk" | tr -d ' ') / $(wc -c < "$FW/em-ref.ledger_entry_awk" | tr -d ' ') / $(wc -c < "$FW/em-ref.backlog_entry_label_awk" | tr -d ' ') B, each carrying its function"
    else
      bad "FIXTURE BROKEN: an unforced emitter of the tree's lib.sh did not emit its function (rc=$EM_RC)"
    fi
  else
    bad "FIXTURE BROKEN: calibration [lib emitters]: heredoc rc=$_emc_hr [$(head -1 "$_emc_h" | cut -c1-80)], printf rc=$_emc_pr [$(head -1 "$_emc_p" | cut -c1-40)] -- this host cannot express the defect"
  fi
fi
echo "== lib.sh's awk emitters: each captured under ulimit -f 0 equals its unforced bytes, rc 0 =="
run_arm arm_em_nrm    "$S_LIB" "nrm_awk under ulimit -f 0: rc 0 and byte-identical to the unforced emission"
run_arm arm_em_ledger "$S_LIB" "ledger_entry_awk under ulimit -f 0: rc 0 and byte-identical, never an empty program"
run_arm arm_em_label  "$S_LIB" "backlog_entry_label_awk under ulimit -f 0: rc 0 and byte-identical"
echo "== non-ASCII core paths reach the rows raw (core.quotePath=false), beside an ASCII control row =="
run_arm arm_qa_plain "$S_RT" "retired-tokens end to end (no --bucket-rows): the ASCII plain.sh row stands"
run_arm arm_qa_cafe  "$S_RT" "retired-tokens end to end: the non-ASCII core/scripts/caf\\303\\251.sh row stands beside plain.sh's"
run_arm arm_qb_plain "$S_PC" "preclassify, pre-relocation consumer: plain.sh's RELOCATE-MOVE+consumer-edited row stands"
run_arm arm_qb_cafe  "$S_PC" "preclassify, pre-relocation consumer: caf\\303\\251.sh's RELOCATE-MOVE+consumer-edited disclosure stands beside plain.sh's"
S_SUG="$RC_/self-update-gate.sh"
run_arm arm_qc_plain "$S_SUG" "self-update-gate arm C: the consumer-edited ASCII machinery file plain.md is carried (SELF-UPDATE-CARRY, raw path)"
run_arm arm_qc_cafe  "$S_SUG" "self-update-gate arm C: the consumer-edited machinery file caf\\303\\251.md is carried under its RAW path beside plain.md"

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
# THE PRE-FIX DIFFERENTIAL for the two BL-354 producers. The forced arms above are PRESENCE-shaped
# (a refusal line must appear), and each is scored here against the pre-fix copy of its script,
# staged beside its siblings. The arm MUST FAIL there -- that is the proof it can fire at all -- and
# the healthy twins' stdout must be BYTE-IDENTICAL to it, with a `cmp -s` control that the two script
# files differ, so the comparison is between two programs and not one program read twice.
# `arm_rg_theirs_ls` carries the discriminator named in the contract: the pre-fix copy prints a FALSE
# `path:` row for steps/gone.md there, and the fixed copy refuses.
# ================================================================================================
PREFIX_PIN=d1c72fa904e5c8aecaaa67fa15340094d73780ab
if ! git -C "$OWN" cat-file -e "${PREFIX_PIN}^{commit}" 2>/dev/null; then
  skip "pre-fix differential -- the pin ${PREFIX_PIN} is not in this clone's history, so no base copy exists (this is not a pass)"
else
  PF="$W/prefix"; cp -R "$RC_" "$PF" || { echo "FIXTURE BROKEN: could not copy reconcile/ for the pre-fix differential" >&2; exit 2; }
  pf_ok=1
  for _pf in retired-tokens.sh retired-layer-contract.sh; do
    if ! git -C "$OWN" show "${PREFIX_PIN}:core/skills/ai-dlc-update/reconcile/${_pf}" > "$PF/$_pf" 2>/dev/null; then
      bad "pre-fix differential: could not stage ${_pf} at the pin"; pf_ok=0
    elif cmp -s "$RC_/$_pf" "$PF/$_pf"; then
      bad "pre-fix differential: ${_pf} at the pin is byte-identical to the tree's copy, so the differential compares one program to itself"; pf_ok=0
    elif [ ! -f "$PF/lib.sh" ] || [ ! -f "$PF/preclassify.sh" ]; then
      bad "pre-fix differential: the staged copy has no lib.sh / preclassify.sh beside it"; pf_ok=0
    fi
  done
  if [ "$pf_ok" -eq 1 ]; then
    ok "pre-fix differential: both scripts staged at the pin beside their siblings, and each DIFFERS from the tree's copy (cmp -s)"
    pf_expect_fail() { # pf_expect_fail <arm> <script-basename> <what the pre-fix copy did>
      if "$1" "$PF/$2"; then bad "pre-fix differential: $1 PASSED against the pre-fix $2, so it cannot tell the fix from its absence -- $ARM_WHY"
      else ok "pre-fix differential: $1 FAILS against the pre-fix $2 ($3) -- $ARM_WHY"; fi
    }
    pf_expect_fail arm_ta_verify    retired-tokens.sh         "an unresolvable ref read as absent paths"
    pf_expect_fail arm_ta_ls        retired-tokens.sh         "it never listed; the failure did not exist to it"
    pf_expect_fail arm_ta_show      retired-tokens.sh         "the failed side read as empty and the row was lost"
    pf_expect_fail arm_rg_theirs_ls retired-layer-contract.sh "a failed theirs listing read as every rulebook file retired"
    pf_expect_fail arm_rg_base_show retired-layer-contract.sh "a failed base read skipped the body"
    # The discriminator itself, as a positive row: the pre-fix copy EMITS the false path row.
    mkstub git "*\"ls-tree -r --name-only ${RG_THEIRS}\"*" 0 128; pf_rc=0; rg_run "$PF/retired-layer-contract.sh" "$STUB" || pf_rc=$?
    if failed_call 0 && [ "$pf_rc" -eq 0 ] && grep -q 'RETIRED-LAYER-CONTRACT.*extensions/cites\.md.*path:core/skills/ai-dlc/steps/gone\.md' "$OUT"; then
      ok "pre-fix differential: under the theirs-listing stub the pre-fix copy exits 0 with a FALSE path: row for steps/gone.md, which the fixed copy refuses"
    else
      bad "pre-fix differential: the pre-fix copy did not print the false path: row under the theirs-listing stub (rc=$pf_rc fired=$(fired)) -- the discriminator is not the one this arm claims"
    fi
    # The healthy twins, byte-identical stdout.
    pf_same() { # pf_same <run-fn> <script-basename> <label> [args...]
      local run="$1" s="$2" lab="$3" a b
      shift 3
      "$run" "$RC_/$s" "$@"; a="$(cat "$OUT")"
      "$run" "$PF/$s" "$@"; b="$(cat "$OUT")"
      if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "pre-fix differential: $lab -- stdout byte-identical to the pre-fix copy, and non-empty"
      else bad "pre-fix differential: $lab -- stdout differs from the pre-fix copy (or is empty): fixed=[$(printf '%s' "$a" | head -2 | tr '\n' '|')] prefix=[$(printf '%s' "$b" | head -2 | tr '\n' '|')]"; fi
    }
    pf_same ta_run retired-tokens.sh "retired-tokens over the two absent-at-a-ref buckets" ""
    pf_same tw_run retired-tokens.sh "retired-tokens over the TW world"
    pf_same rg_run retired-layer-contract.sh "retired-layer-contract over the RG world"
    pf_same rw_run retired-layer-contract.sh "retired-layer-contract over the RW world"
    # The absent-at-a-ref runs alone carry their answer on STDERR; that must match too.
    pf_err_a="$(ta_run "$RC_/retired-tokens.sh" "" core/scripts/added.sh; cat "$ERR")"
    pf_err_b="$(ta_run "$PF/retired-tokens.sh" "" core/scripts/added.sh; cat "$ERR")"
    if [ -n "$pf_err_a" ] && [ "$pf_err_a" = "$pf_err_b" ]; then ok "pre-fix differential: the absent-at-base path run alone -- stderr NOTE byte-identical to the pre-fix copy"
    else bad "pre-fix differential: the absent-at-base path run alone -- stderr differs from the pre-fix copy: [$pf_err_a] vs [$pf_err_b]"; fi
  fi
fi

# ================================================================================================
# r5 -- NO NON-COMMENT HERE-STRING IN A CONVERTED FILE. Self-probe first, both directions, on a
# seeded file: a live `<<<` at a line's start, middle and end must each count, and a comment line
# naming `<<<` and the literal `<<<<<<<` inside an echo -- readopt-override.sh's own line -- must not.
# ================================================================================================
R5P="$W/r5-probe.sh"
cat > "$R5P" <<'R5_EOF'
grep -qF -- "$x" <<< "$body" || continue
done <<<"$ids"
cat <<<x
  # a comment: grep -qxF -- "$line" <<<"$to_lines"
          echo "  Stamping now would ship <<<<<<< into the rulebook the lead reads." >&2
done <<EOF
R5_EOF
R5_GOT="$(r5_scan "$R5P")"
if [ "$R5_GOT" = "5 3 1 2 3" ]; then
  ok "r5 self-probe: a here-string at a line's start, middle and end counts (lines 1-3); a comment, an echoed <<<<<<< and a <<EOF heredoc do not"
else
  bad "r5 self-probe read '$R5_GOT', expected '5 3 1 2 3' -- the grammar cannot be trusted on the converted files"
fi
for _r5 in $R5_FILES; do run_arm arm_r5 "$RC_/$_r5" "r5: $_r5 carries no non-comment here-string"; done

# ================================================================================================
# LH -- NO HEREDOC OPENER IN lib.sh. The emitters are literals; a `<<WORD`, `<<-WORD`, `<<'WORD'`
# or `<< "WORD"` on a line that is not a whole-line comment reintroduces the staging write. Runs of
# three or more `<` are removed first, so a here-string (`<<<`) and an echoed `<<<<<<<` are not
# openers; an arithmetic `<<2` is not, because a delimiter opens with a letter or `_`. FP set,
# measured on lib.sh at the tip: it carries no `<<` of any kind, so the grammar is wider than the
# corpus needs and costs nothing there; at b0c310a3 it reads exactly the three `cat <<'AWK'` lines.
# ================================================================================================
LH_AWK='/^[[:blank:]]*#/ { next }
  { n++; l = $0; gsub(/<<<+/, "", l)
    if (l ~ /<<-?[[:blank:]]*[\047"]?[A-Za-z_]/) { h++; at = at " " FNR } }
  END { printf "%d %d%s\n", n, h, at }'
lh_scan() { awk "$LH_AWK" "$1"; }
arm_lh() { local r n h
  r="$(lh_scan "$1")" || { ARM_WHY="awk could not scan $1"; return 1; }
  n="${r%% *}"; h="${r#* }"; h="${h%% *}"
  ARM_WHY="$n non-comment line(s) scanned, $h heredoc opener(s)$( [ "$h" -gt 0 ] && printf ' at%s' "${r#* * }" )"
  [ "$n" -gt 0 ] && [ "$h" -eq 0 ]; }
LHP="$W/lh-probe.sh"
{ printf '%s\n' "  cat <<'AWK'" 'cat <<EOF' '  cat <<-EOF' 'cat << "X"'
  printf '%s\n' "  # cat <<'AWK'" 'x <<<"$y"' 'echo "<<<<<<< x"' 'y=$((1<<2))'; } > "$LHP"
LH_GOT="$(lh_scan "$LHP")"
if [ "$LH_GOT" = "7 4 1 2 3 4" ]; then
  ok "LH self-probe: <<'AWK', <<EOF, <<-EOF and << \"X\" each count (lines 1-4); a commented opener, a here-string, an echoed <<<<<<< and an arithmetic <<2 do not"
else
  bad "LH self-probe read '$LH_GOT', expected '7 4 1 2 3 4' -- the grammar cannot be trusted on lib.sh"
fi
run_arm arm_lh "$S_LIB" "LH: lib.sh carries no heredoc opener outside comments"

# ================================================================================================
# THE b0c310a3 DIFFERENTIAL. lib.sh and preclassify.sh at the base this release was cut from, staged
# into a copy of reconcile/ beside the tree's other scripts. Every emitter cell, LH and both
# non-ASCII cells MUST FAIL there; both ASCII controls MUST PASS there, so a failure is the
# non-ASCII row's and not a copy that never ran.
# ================================================================================================
BL_PIN=b0c310a361b6cebf69c8d33ca21a05f028dbac45
if ! git -C "$OWN" cat-file -e "${BL_PIN}^{commit}" 2>/dev/null; then
  skip "b0c310a3 differential -- the pin ${BL_PIN} is not in this clone's history, so no base copy exists (this is not a pass)"
else
  BLD="$W/bl"; cp -R "$RC_" "$BLD" || { echo "FIXTURE BROKEN: could not copy reconcile/ for the b0c310a3 differential" >&2; exit 2; }
  bl_ok=1
  for _bl in lib.sh preclassify.sh; do
    if ! git -C "$OWN" show "${BL_PIN}:core/skills/ai-dlc-update/reconcile/${_bl}" > "$BLD/$_bl" 2>/dev/null; then
      bad "b0c310a3 differential: could not stage ${_bl} at the pin"; bl_ok=0
    elif cmp -s "$RC_/$_bl" "$BLD/$_bl"; then
      bad "b0c310a3 differential: ${_bl} at the pin is byte-identical to the tree's copy"; bl_ok=0
    fi
  done
  if [ "$bl_ok" -eq 1 ]; then
    ok "b0c310a3 differential: lib.sh and preclassify.sh staged at the pin beside the tree's scripts, each DIFFERS from the tree's copy (cmp -s)"
    bl_fail() { # bl_fail <arm> <path> <what the base did>
      if "$1" "$2"; then bad "b0c310a3 differential: $1 PASSED against the base, so it cannot tell the fix from its absence -- $ARM_WHY"
      else ok "b0c310a3 differential: $1 FAILS against the base ($3) -- $ARM_WHY"; fi; }
    bl_pass() { # bl_pass <arm> <path> <what>
      if "$1" "$2"; then ok "b0c310a3 differential: $1 PASSES against the base ($3) -- $ARM_WHY"
      else bad "b0c310a3 differential: $1 FAILED against the base, so the copy did not run as far as its loop -- $ARM_WHY"; fi; }
    bl_fail arm_em_nrm    "$BLD/lib.sh" "the heredoc emitted nothing at rc 1"
    bl_fail arm_em_ledger "$BLD/lib.sh" "the heredoc emitted nothing at rc 1"
    bl_fail arm_em_label  "$BLD/lib.sh" "the heredoc emitted nothing at rc 1"
    bl_fail arm_lh        "$BLD/lib.sh" "three cat <<'AWK' openers"
    bl_pass arm_qa_plain  "$BLD/retired-tokens.sh" "the ASCII control row"
    bl_fail arm_qa_cafe   "$BLD/retired-tokens.sh" "the C-quoted name matched no consumer path and the row was lost"
    bl_pass arm_qb_plain  "$BLD/preclassify.sh" "the ASCII control row"
    bl_fail arm_qb_cafe   "$BLD/preclassify.sh" "no RELOCATE-MOVE+consumer-edited disclosure for the non-ASCII name"
    bl_pass arm_qc_plain  "$BLD/self-update-gate.sh" "the ASCII control row"
    bl_fail arm_qc_cafe   "$BLD/self-update-gate.sh" "the CARRY row named the C-quoted path, its consumer column the quoted core path"
  fi
fi

# ================================================================================================
# THE 322ef42c DIFFERENTIAL. Every staging-write cell and r5 is PRESENCE- or count-shaped, and each
# is scored here against the copy of its script at 322ef42c -- the base these cells were built
# against -- staged beside the tree's lib.sh. Each MUST FAIL there, which is the proof it can fire.
# hard-blockers.sh and warn-shadowed-local-validators.sh fed their loops from `<<EOF` heredocs, not
# `<<<`, so r5 does not score them; their forced cells do.
# ================================================================================================
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
# THE HEREDOC EMITTERS, restored one emitter at a time: the `printf` literal becomes `cat <<'AWK'`
# again, and ledger_entry_awk's body apostrophe loses its `'\''` spelling. Used by the EM-* mutants
# and, all three at once, to build HL -- a reconcile/ copy whose lib.sh can fail to emit, which is
# the only place warn-shadowed-local-validators.sh's emitter refusal still has a subject.
EM_NRM=( $'  printf \'%s\\n\' \'function nrm(s){' $'  cat <<\'AWK\'\nfunction nrm(s){'
         $'return s }\'\n}' $'return s }\nAWK\n}' )
EM_LEDGER=( $'  printf \'%s\\n\' \'function ledger_entry_id(label) {' $'  cat <<\'AWK\'\nfunction ledger_entry_id(label) {'
            $'consumer\'\\\'\'s' $'consumer\'s'
            $'  return sh\n}\'\n}' $'  return sh\n}\nAWK\n}' )
EM_LABEL=( $'  printf \'%s\\n\' \'function backlog_entry_label(l,' $'  cat <<\'AWK\'\nfunction backlog_entry_label(l,'
           $'  return ""\n}\'\n}' $'  return ""\n}\nAWK\n}' )
HL="$W/hl"; HL_OK=0
if cp -R "$RC_" "$HL" && _hl_why="$(mkmut "$RC_/lib.sh" "$HL/lib.sh" "${EM_NRM[@]}" "${EM_LEDGER[@]}" "${EM_LABEL[@]}")" \
   && bash -n "$HL/lib.sh" && [ "$(lh_scan "$HL/lib.sh" | cut -d' ' -f2)" -eq 3 ]; then
  HL_OK=1; ok "heredoc lib.sh (HL): all three emitters restored to cat <<'AWK', it parses, and LH reads exactly 3 openers in it"
else
  bad "heredoc lib.sh (HL) could not be built: ${_hl_why:-copy, parse or LH count failed}"
fi

B3_PIN=322ef42c43be0c11db74e937930e8810cf6b5492
if ! git -C "$OWN" cat-file -e "${B3_PIN}^{commit}" 2>/dev/null; then
  skip "322ef42c differential -- the pin ${B3_PIN} is not in this clone's history, so no base copy exists (this is not a pass)"
else
  B3="$W/b3"; cp -R "$RC_" "$B3" || { echo "FIXTURE BROKEN: could not copy reconcile/ for the 322ef42c differential" >&2; exit 2; }
  b3_ok=1
  for _b3 in $R5_FILES; do
    if ! git -C "$OWN" show "${B3_PIN}:core/skills/ai-dlc-update/reconcile/${_b3}" > "$B3/$_b3" 2>/dev/null; then
      bad "322ef42c differential: could not stage ${_b3} at the pin"; b3_ok=0
    elif cmp -s "$RC_/$_b3" "$B3/$_b3"; then
      bad "322ef42c differential: ${_b3} at the pin is byte-identical to the tree's copy"; b3_ok=0
    fi
  done
  if [ "$b3_ok" -eq 1 ]; then
    ok "322ef42c differential: the seven converted scripts staged at the pin beside lib.sh, each DIFFERS from the tree's copy (cmp -s)"
    b3_fail() { # b3_fail <arm> <script-basename> <what the base copy did>
      if "$1" "$B3/$2"; then bad "322ef42c differential: $1 PASSED against the base $2, so it cannot tell the fix from its absence -- $ARM_WHY"
      else ok "322ef42c differential: $1 FAILS against the base $2 ($3) -- $ARM_WHY"; fi
    }
    b3_fail arm_fx_hb_check   hard-blockers.sh          "the failed heredoc read as '(0 total)'"
    b3_fail arm_fx_hb_print   hard-blockers.sh          "an empty region with no '0 HARD blockers.' line"
    b3_fail arm_fx_rx         relabel-extension-checks.sh "'no unlabelled core-number collisions.'"
    b3_fail arm_fx_rxr        relabel-extension-checks.sh "'no unlabelled core-number collisions.' on the rule pass"
    b3_fail arm_fx_rx_apply   relabel-extension-checks.sh "rc 0 and the heading never labelled"
    b3_fail arm_fx_rlc        retired-layer-contract.sh "the 20 KB layer file's row lost at rc 0"
    b3_fail arm_fx_ws_closed  warn-shadowed-local-validators.sh "0 rows at rc 0"
    # The emitter cell needs an emitter that CAN fail, and the tree's lib.sh emits a literal: this
    # one base copy runs beside the HEREDOC lib.sh (HL, staged below), or the cell passes vacuously.
    if [ "$HL_OK" -eq 1 ] && git -C "$OWN" show "${B3_PIN}:core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" > "$HL/_b3_ws.sh"; then
      if arm_fx_ws_emitter "$HL/_b3_ws.sh"; then bad "322ef42c differential: arm_fx_ws_emitter PASSED against the base warn-shadowed-local-validators.sh beside the heredoc lib.sh -- $ARM_WHY"
      else ok "322ef42c differential: arm_fx_ws_emitter FAILS against the base warn-shadowed-local-validators.sh beside the heredoc lib.sh (awk died on an undefined function, 0 rows at rc 0) -- $ARM_WHY"; fi
    else
      bad "322ef42c differential: arm_fx_ws_emitter has no heredoc lib.sh to run beside"
    fi
    b3_fail arm_fx_rt         retired-tokens.sh         "a FALSE z -> old-b row and the true one lost"
    b3_fail arm_fx_rls        retired-layer-contract.sh "the spellings heredoc failed to stage, 0 rows at rc 0"
    b3_fail arm_fx_ro         readopt-override.sh       "the id here-string failed to stage, no scan ran"
    if [ "$(id -u)" -ne 0 ]; then
      b3_fail arm_rlc_unread_layer retired-layer-contract.sh "the unreadable layer file read as empty, rc 0"
    else
      skip "322ef42c differential: arm_rlc_unread_layer -- running as root, which reads a mode-000 layer file, so the world is not expressible (this is not a pass)"
    fi
    for _b3 in relabel-extension-checks.sh retired-layer-contract.sh retired-tokens.sh readopt-override.sh derivation-differential.sh; do
      b3_fail arm_r5 "$_b3" "it carried non-comment here-strings"
    done
    # The NUL worlds are the other direction: the base copy fed `toks` from `<<<"$b"`, whose `$( )`
    # had dropped every NUL, so it was CORRECT there and must pass. A conversion that is not
    # behaviour-preserving on them is a regression against this copy, not a fix.
    # The Latin-1 worlds join them: the base copy ran no `tr`, so a Latin-1 theirs blob read whole.
    # arm_lw_trstatus does not: the base has no `tr` for its stub to fail.
    _lwa="arm_lw_c"; [ "$LW_UTF8" -eq 1 ] && _lwa="$_lwa arm_lw_utf8"
    for _nwa in arm_nw_both arm_nw_theirs arm_nw_cmt $_lwa; do
      if "$_nwa" "$B3/retired-tokens.sh"; then ok "322ef42c differential: $_nwa PASSES against the base retired-tokens.sh, which read NUL-bearing blobs correctly -- $ARM_WHY"
      else bad "322ef42c differential: $_nwa FAILED against the base retired-tokens.sh, so the arm does not describe the base behaviour the fix must preserve -- $ARM_WHY"; fi
    done
  fi
fi

# ================================================================================================
# MUTANTS. One copy of each subject directory; each mutant is a sibling file in that copy, so the
# script finds lib.sh, setup-sites.md, preclassify.sh and artifact-path-config.sh beside it.
# ================================================================================================
MT="$W/mt"; mkdir -p "$MT"
cp -R "$SC" "$MT/scripts" && cp -R "$RC_" "$MT/reconcile" && cp -R "$TREE/core/schemas" "$MT/schemas" \
  || { echo "FIXTURE BROKEN: could not copy the subject directories" >&2; exit 2; }
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
control reconcile retired-tokens.sh             arm_ta_healthy arm_ta_verify arm_ta_ls arm_ta_show
control reconcile retired-layer-contract.sh     arm_rg_healthy arm_rg_theirs_ls arm_rg_base_show
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
control reconcile hard-blockers.sh              arm_fx_hb_healthy arm_fx_hb_check arm_fx_hb_print arm_r5
control reconcile relabel-extension-checks.sh   arm_fx_rx_healthy arm_fx_rx arm_fx_rxr arm_fx_rx_apply arm_fx_rxo_apply arm_r5
control reconcile retired-layer-contract.sh     arm_fx_rlc_healthy arm_fx_rlc arm_fx_rls_healthy arm_fx_rls arm_r5
control reconcile readopt-override.sh           arm_fx_ro_healthy arm_fx_ro
control reconcile warn-shadowed-local-validators.sh arm_fx_ws_healthy arm_fx_ws_closed arm_fx_ws6_healthy arm_fx_ws_emitter arm_r5
# The emitter refusal's control and mutant run beside the HEREDOC lib.sh: beside the tree's literal
# emitters that refusal has no subject, and the mutant dropping it survives by construction.
if [ "$HL_OK" -eq 1 ]; then cp -R "$HL" "$MT/hl"; control hl warn-shadowed-local-validators.sh arm_fx_ws6_healthy arm_fx_ws_emitter
else bad "control hl/warn-shadowed-local-validators.sh: the heredoc lib.sh (HL) was not built"; fi
control reconcile preclassify.sh                arm_qb_plain arm_qb_cafe
libcontrol retired-tokens.sh        arm_qa_plain arm_qa_cafe
libcontrol self-update-gate.sh      arm_qc_plain arm_qc_cafe
control reconcile retired-tokens.sh             arm_fx_rt_healthy arm_fx_rt arm_r5 arm_nw_both arm_nw_theirs arm_nw_cmt arm_lw_c arm_lw_trstatus
[ "$LW_UTF8" -eq 1 ] && control reconcile retired-tokens.sh arm_lw_utf8
control reconcile readopt-override.sh           arm_ro_healthy arm_r5
control reconcile derivation-differential.sh    arm_dd_usage arm_r5

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
# The three below anchor on the rt_toks feeds as the here-string conversion left them: each reads
# the blob rt_blob staged, and refuses on a failed read. The observable is unchanged.
RT_FEED_B='rt_toks "${cp}@${BASE}" "$RT_T/toks-base" < "$RT_T/blob-base" || rt_refuse "reading the staged base blob of $cp" "$?"'
RT_FEED_T='rt_toks "${cp}@${THEIRS}" "$RT_T/toks-theirs" < "$RT_T/blob-theirs" || rt_refuse "reading the staged theirs blob of $cp" "$?"'
mutant RT-SUBTRACT reconcile retired-tokens.sh arm_rt_healthy "arm_rt_all arm_rt_base" \
  "  $RT_FEED_B"$'\n'"  $RT_FEED_T"$'\n  retired="$(comm -23 "$RT_T/toks-base" "$RT_T/toks-theirs")" || rt_refuse "the retired-token subtraction for $cp" "$?"' \
  $'  retired="$(comm -23 <(printf \'%s\\n\' "$b" | toks) <(printf \'%s\\n\' "$t" | toks))"'
mutant RT-PIPE reconcile retired-tokens.sh arm_rt_healthy "arm_rt_base" \
  "$RT_FEED_B" 'printf '"'"'%s\n'"'"' "$b" | rt_toks "${cp}@${BASE}" "$RT_T/toks-base"'
mutant RT-OURS reconcile retired-tokens.sh arm_rt_healthy "arm_rt_ours" \
  $'  rt_toks "$cons" "$RT_T/toks-ours" < "$ours" || rt_refuse "reading $cons" "$?"\n  comm -12 "$RT_T/retired" "$RT_T/toks-ours" > "$RT_T/spoken" || rt_refuse "the consumer-token intersection for $cp" "$?"\n' '' \
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
# norm_lines returns `tr`'s status again: a dead sed reads as a normalised EMPTY file. Since sed's
# output is STAGED (the iconv-gated case fold reads it twice), the mutation drops the staged sed's
# own status read, which leaves `tr` folding an empty file at 0 -- the same observable.
libmutant RLP-NORMLINES retired-layer-passage.sh arm_rlp_healthy "arm_rlp_norm arm_rlp_removed" \
  $'          s/[.[:space:]]+$//\' > "$_nt" || _rc=$?\n' $'          s/[.[:space:]]+$//\' > "$_nt"\n'
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
  $'  _code="$(printf \'%s\\n\' "$_raw" | grep -vE \'^[[:space:]]*#\')" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_code" ] || return 0\n  _t="$(printf \'%s\\n\' "$_code" | grep -oE \'\\$[A-Za-z_][A-Za-z0-9_]*/[A-Za-z0-9._/-]+\')" || _rc=$?\n  [ "$_rc" -le 1 ] || return "$_rc"\n  [ -n "$_t" ] || return 0\n  printf \'%s\\n\' "$_t" | sort -u\n' \
  $'  printf \'%s\\n\' "$_raw" | grep -vE \'^[[:space:]]*#\' \\\n  | grep -oE \'\\$[A-Za-z_][A-Za-z0-9_]*/[A-Za-z0-9._/-]+\' \\\n  | sort -u\n'
# retired-tokens: the NUL strip removed, so the comment strip reads the staged blob raw again and BSD
# grep answers `Binary file (standard input) matches`: the true nul.sh row is lost, and q.sh's NUL
# at theirs alone reads its base tokens as retired.
# Not `_raw="$(cat)"`: a `$( )` drops the NUL itself, and that mutant is the fix spelled again.
RT_NUL_STRIP=$'  _raw="$(LC_ALL=C tr -d \'\\000\')" || return 2\n  [ -n "$_raw" ] || return 0\n'
mutant RT-NUL reconcile retired-tokens.sh arm_rt_healthy "arm_nw_both arm_nw_theirs" \
  "$RT_NUL_STRIP" '' \
  $'  _code="$(printf \'%s\\n\' "$_raw" | grep -vE' $'  _code="$(grep -vE'
# The `grep -a` repair the tip adversary proposed: it recovers both rows above, and reads a NUL
# before a comment `#` as a live line, so h.sh's commented token becomes a FALSE row.
mutant RT-NUL-GREPA reconcile retired-tokens.sh arm_rt_healthy "arm_nw_cmt" \
  "$RT_NUL_STRIP" '' \
  $'  _code="$(printf \'%s\\n\' "$_raw" | grep -vE' $'  _code="$(grep -avE'
# retired-tokens: the NUL strip's status dropped. Pinned to C the real `tr` never fails on the
# Latin-1 blob, so only the FORCED strip failure sees this: theirs reads tokenless, FALSE keep rows.
RT_TR_LINE=$'  _raw="$(LC_ALL=C tr -d \'\\000\')" || return 2\n'
mutant RT-TR-STATUS reconcile retired-tokens.sh arm_rt_healthy "arm_lw_trstatus" \
  "$RT_TR_LINE" $'  _raw="$(LC_ALL=C tr -d \'\\000\')" || true\n'
# retired-tokens: the NUL strip back in the caller's locale (b5e5b610's spelling). A UTF-8 caller's
# `tr` refuses the Latin-1 theirs blob, so the detector refuses a file 322ef42c read correctly.
if [ "$LW_UTF8" -eq 1 ]; then
  mutant RT-TR-LOCALE reconcile retired-tokens.sh arm_rt_healthy "arm_lw_utf8" \
    "$RT_TR_LINE" $'  _raw="$(tr -d \'\\000\')" || return 2\n'
else
  skip "mutant RT-TR-LOCALE: its killing cell needs locale en_US.UTF-8, which is not installed (this is not a pass)"
fi
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
# retired-tokens' blob reads, one mutant per layer of the fix, and one reverting EVERY layer to the
# base `$(git show … || true)` spelling. Each layer is killed by its own arm.
mutant RT-VERIFY reconcile retired-tokens.sh arm_ta_healthy "arm_ta_verify" \
  '[ "$_rt_rc" -eq 0 ] || rt_refuse "resolving' 'true || rt_refuse "resolving'
mutant RT-LS reconcile retired-tokens.sh arm_ta_healthy "arm_ta_ls" \
  '[ "$rc" -eq 0 ] || rt_refuse "listing $2 at $1" "$rc"' 'true || rt_refuse "listing $2 at $1" "$rc"'
mutant RT-SHOW reconcile retired-tokens.sh arm_ta_healthy "arm_ta_show" \
  '[ "$rc" -eq 0 ] || rt_refuse "reading $2 at $1" "$rc"' 'true || rt_refuse "reading $2 at $1" "$rc"'
mutant RT-BLOBS-ALL reconcile retired-tokens.sh arm_ta_healthy "arm_ta_verify arm_ta_ls arm_ta_show" \
  '[ "$_rt_rc" -eq 0 ] || rt_refuse "resolving' 'true || rt_refuse "resolving' \
  $'  rt_blob "$BASE" "$cp" "$RT_T/blob-base" || continue\n  rt_blob "$THEIRS" "$cp" "$RT_T/blob-theirs" || continue\n  b="$(cat "$RT_T/blob-base")" || rt_refuse "reading the staged base blob of $cp" "$?"\n  t="$(cat "$RT_T/blob-theirs")" || rt_refuse "reading the staged theirs blob of $cp" "$?"\n' \
  $'  b="$(git -C "$DIST" show "${BASE}:${cp}" 2>/dev/null || true)"\n  t="$(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null || true)"\n' \
  "$RT_FEED_B" 'rt_toks "${cp}@${BASE}" "$RT_T/toks-base" <<<"$b"' \
  "$RT_FEED_T" 'rt_toks "${cp}@${THEIRS}" "$RT_T/toks-theirs" <<<"$t"'
# retired-layer-contract: the tree listing's status and the blob read's status, each dropped, and both.
mutant RLC-TREE reconcile retired-layer-contract.sh arm_rg_healthy "arm_rg_theirs_ls" \
  '[ "$rc" -eq 0 ] || { RLC_WHY="the rulebook tree listing' 'true || { RLC_WHY="the rulebook tree listing'
mutant RLC-SHOW reconcile retired-layer-contract.sh arm_rg_healthy "arm_rg_base_show" \
  '[ "$rc" -eq 0 ] || { RLC_WHY="reading $f at $ref"' 'true || { RLC_WHY="reading $f at $ref"'
mutant RLC-READS-ALL reconcile retired-layer-contract.sh arm_rg_healthy "arm_rg_theirs_ls arm_rg_base_show" \
  '[ "$rc" -eq 0 ] || { RLC_WHY="the rulebook tree listing' 'true || { RLC_WHY="the rulebook tree listing' \
  '[ "$rc" -eq 0 ] || { RLC_WHY="reading $f at $ref"' 'true || { RLC_WHY="reading $f at $ref"'
# layer-drift: sup_measure's count reads no stage's status again.
mutant LD-FXV reconcile layer-drift.sh arm_ld_healthy "arm_ld_fxv" \
  $' | grep -c .\n              for _ps in "${PIPESTATUS[@]}"; do [ "$_ps" -le 1 ] || exit 3; done)" || return 3\n' \
  $' | grep -c .)"\n'
# section_of returns `rm`'s status again: a span_of that died reads as "no such section".
libmutant RO-SECTIONOF readopt-override.sh arm_ro_healthy "arm_ro_span" \
  $'  local _t _s="" _rc=0\n  _t="$(mktemp)" || return 1\n  cat > "$_t" || _rc=$?\n  if [ "$_rc" -eq 0 ]; then _s="$(span_of "$1" < "$_t")" || _rc=$?; fi\n  if [ "$_rc" -eq 0 ] && [ -n "$_s" ]; then LC_ALL=C sed -n "${_s%% *},${_s##* }p" "$_t" || _rc=$?; fi\n  rm -f "$_t"\n  return "$_rc"\n' \
  $'  local _t _s\n  _t="$(mktemp)" || return 1\n  cat > "$_t"\n  _s="$(span_of "$1" < "$_t")"\n  [ -n "$_s" ] && LC_ALL=C sed -n "${_s%% *},${_s##* }p" "$_t"\n  rm -f "$_t"\n'

echo "== mutants: one 322ef42c staging spelling per converted file (each restores a here-string or heredoc feed) =="
# hard-blockers: the staged list and its refusal removed, both loops fed from the `<<EOF` heredoc again.
mutant HB-HEREDOC reconcile hard-blockers.sh arm_fx_hb_healthy "arm_fx_hb_check arm_fx_hb_print" \
  $'  printf \'%s\\n\' "$BLOCKERS" > "$HB_T/blockers" || _hb_rc=$?\n  [ "$_hb_rc" -eq 0 ] || hb_refuse_staging "the blocking list" "$_hb_rc"\n' '' \
  $'      printf \'%-32s %s\\n\' "$st" "$path"\n    done < "$HB_T/blockers"' $'      printf \'%-32s %s\\n\' "$st" "$path"\n    done <<EOF\n$BLOCKERS\nEOF' \
  $'      missing=1\n    fi\n  done < "$HB_T/blockers"' $'      missing=1\n    fi\n  done <<EOF\n$BLOCKERS\nEOF'
# relabel: both anchor sets fed from `<<<` again, their staging and refusal removed.
mutant RX-HERESTRING reconcile relabel-extension-checks.sh arm_fx_rx_healthy "arm_fx_rx arm_fx_rxr arm_fx_rx_apply arm_r5" \
  $'  _rx_rc=0\n  printf \'%s\\n\' "$core_nums" > "$RX_T/core-nums" || _rx_rc=$?\n' '' \
  $'  printf \'%s\\n\' "$core_rules" > "$RX_T/core-rules" || _rx_rc=$?\n' '' \
  '[ "$_rx_rc" -eq 0 ] || { echo "relabel: REFUSED — the core check-anchor set' 'true || { echo "relabel: REFUSED — the core check-anchor set' \
  '[ "$_rx_rc" -eq 0 ] || { echo "relabel: REFUSED — the core rule-number set' 'true || { echo "relabel: REFUSED — the core rule-number set' \
  '  done < "$RX_T/core-nums"' '  done <<< "$core_nums"' \
  '  done < "$RX_T/core-rules"' '  done <<< "$core_rules"'
# retired-layer-contract: the path arm's substring test is the `grep -qF` here-string again.
mutant RLC-HERESTRING reconcile retired-layer-contract.sh arm_fx_rlc_healthy "arm_fx_rlc arm_r5" \
  '        case "$body" in *"$_sp"*) _hit=yes; break ;; esac' $'        grep -qF -- "$_sp" <<< "$body" || continue\n        _hit=yes; break'
# warn-shadowed: the closed-basename loop is the `<<EOF` heredoc again, its staging removed.
mutant WS-HEREDOC reconcile warn-shadowed-local-validators.sh arm_fx_ws_healthy "arm_fx_ws_closed" \
  $'printf \'%s\\n\' "$closed_basenames" > "$WS_T/closed" || _ws_rc=$?\n[ "$_ws_rc" -eq 0 ] || ws_refuse_staging "the closed-entry basename set" "$_ws_rc"\n' '' \
  'done < "$WS_T/closed"' $'done <<EOF\n$closed_basenames\nEOF'
# warn-shadowed: the lib emitter's capture and the closed-entry scan read no status again.
mutant WS-EMITTER hl warn-shadowed-local-validators.sh arm_fx_ws6_healthy "arm_fx_ws_emitter" \
  'LEA="$(ledger_entry_awk)" || { echo' 'LEA="$(ledger_entry_awk)"; true || { echo' \
  '[ -n "$LEA" ] || { echo' 'true || { echo' \
  '[ "$_ws_rc" -eq 0 ] || { echo "warn-shadowed-local-validators: REFUSED — the closed-entry scan' 'true || { echo "warn-shadowed-local-validators: REFUSED — the closed-entry scan'
# retired-tokens: the two rt_toks feeds are here-strings again, with no status read (322ef42c's spelling).
mutant RT-HERESTRING reconcile retired-tokens.sh arm_fx_rt_healthy "arm_fx_rt arm_r5" \
  "$RT_FEED_B" 'rt_toks "${cp}@${BASE}" "$RT_T/toks-base" <<<"$b"' \
  "$RT_FEED_T" 'rt_toks "${cp}@${THEIRS}" "$RT_T/toks-theirs" <<<"$t"'
# retired-layer-contract's path arm, its own staging. RLC-STATUS keeps both writes and drops both
# statuses; RLC-HEREDOC is the 322ef42c spelling in full -- the staging block removed and both loops
# fed from heredocs again, the spellings one with a `$(spellings_of …)` body; RLC-CAT reads a layer
# file `|| true` again.
RLC_STAGE_RP='printf '"'"'%s\n'"'"' "$RETIRED_PATHS" > "$RLC_T/retired-paths" || rlc_refuse "staging the retired rulebook path set" "$?"'
RLC_STAGE_SP='  printf '"'"'%s\n'"'"' "$_rlc_sps" > "$RLC_T/spellings-$_rlc_n" || rlc_refuse "staging the spellings of $_rp" "$?"'
mutant RLC-STATUS reconcile retired-layer-contract.sh arm_fx_rls_healthy "arm_fx_rls" \
  "$RLC_STAGE_RP" 'printf '"'"'%s\n'"'"' "$RETIRED_PATHS" > "$RLC_T/retired-paths" || true' \
  "$RLC_STAGE_SP" '  printf '"'"'%s\n'"'"' "$_rlc_sps" > "$RLC_T/spellings-$_rlc_n" || true'
# Not arm_fx_rlc: its oversize payload is the layer body, which is no longer staged, so under its
# limit both heredocs land whole and it passes this mutant (measured).
mutant RLC-HEREDOC reconcile retired-layer-contract.sh arm_fx_rls_healthy "arm_fx_rls" \
  "$RLC_STAGE_RP"$'\n_rlc_n=0\nwhile IFS= read -r _rp; do\n  [ -n "$_rp" ] || continue\n  _rlc_n=$((_rlc_n + 1))\n  _rlc_sps="$(spellings_of "$_rp")"\n'"$RLC_STAGE_SP"$'\ndone < "$RLC_T/retired-paths"\n' '' \
  $'    _rlc_i=0\n    while IFS= read -r _rp; do\n      [ -n "$_rp" ] || continue\n      _rlc_i=$((_rlc_i + 1))\n' \
  $'    while IFS= read -r _rp; do\n      [ -n "$_rp" ] || continue\n' \
  $'      done < "$RLC_T/spellings-$_rlc_i"\n' $'      done <<EOF\n$(spellings_of "$_rp")\nEOF\n' \
  $'    done < "$RLC_T/retired-paths"\n' $'    done <<EOF\n$RETIRED_PATHS\nEOF\n'
if [ "$(id -u)" -eq 0 ]; then
  skip "mutant RLC-CAT: its killing cell needs a mode-000 file root can read (this is not a pass)"
else
  mutant RLC-CAT reconcile retired-layer-contract.sh arm_fx_rlc_healthy "arm_rlc_unread_layer" \
    'body="$(cat "$f")" || _rlc_rc=$?' 'body="$(cat "$f" 2>/dev/null || true)"'
fi
# relabel: the rule-set staging and its refusal moved AFTER the check pass, which may already have
# moved the extension. The refusal line is unchanged, so only the extension's bytes can kill it.
RX_STAGE_RULES=$'  printf \'%s\\n\' "$core_rules" > "$RX_T/core-rules" || _rx_rc=$?\n  [ "$_rx_rc" -eq 0 ] || { echo "relabel: REFUSED — the core rule-number set for ${ext#$CONSUMER/} could not be staged (exit $_rx_rc); no verdict" >&2; exit 2; }\n'
mutant RX-ORDER reconcile relabel-extension-checks.sh arm_fx_rx_healthy "arm_fx_rxo_apply" \
  "$RX_STAGE_RULES" '' \
  $'  done < "$RX_T/core-nums"\n' $'  done < "$RX_T/core-nums"\n'"$RX_STAGE_RULES"
# readopt-override: the two scans' id staging keeps its write and loses its status.
mutant RO-STATUS reconcile readopt-override.sh arm_fx_ro_healthy "arm_fx_ro" \
  '  shadow_ids stale-ids || return 3' '  shadow_ids stale-ids || true' \
  '  shadow_ids unadopted-ids || return 3' '  shadow_ids unadopted-ids || true'
# readopt-override and derivation-differential: r5 holds their one converted here-string site each.
mutant RO-HERESTRING reconcile readopt-override.sh arm_ro_healthy "arm_r5" \
  'ro_has_line "$to_lines" "$line" && continue' 'grep -qxF -- "$line" <<<"$to_lines" && continue'
echo "== mutants: lib.sh's emitters and the non-ASCII path readers =="
# lmutant <id> <healthy-arm> "<arms>" <find> <replace>... -- mutate a COPY of reconcile/lib.sh and
# drive the lib-path arms against that file.
lmutant() {
  local id="$1" healthy="$2" arms="$3" d="$MT/lm_$1" why a survived=""
  shift 3
  mkdir -p "$d"
  if ! why="$(mkmut "$MT/reconcile/lib.sh" "$d/lib.sh" "$@")"; then bad "mutant $id DID NOT APPLY ($why)"; return; fi
  if cmp -s "$MT/reconcile/lib.sh" "$d/lib.sh"; then bad "mutant $id DID NOT APPLY (lib.sh is byte-identical)"; return; fi
  bash -n "$d/lib.sh" 2>/dev/null || { bad "mutant $id DID NOT APPLY (the mutated lib.sh does not parse)"; return; }
  if ! "$healthy" "$d/lib.sh"; then bad "mutant $id: its healthy twin $healthy failed on the mutant, so no kill can be read -- $ARM_WHY"; return; fi
  for a in $arms; do "$a" "$d/lib.sh" && survived="$survived $a"; done
  if [ -z "$survived" ]; then ok "mutant $id (lib.sh) killed by:$(printf ' %s' $arms)"
  else bad "mutant $id SURVIVED$survived -- that arm cannot see its own site"; fi
}
_lmc=""; for _a in arm_em_nrm arm_em_ledger arm_em_label arm_lh; do "$_a" "$MT/reconcile/lib.sh" || _lmc="$_lmc $_a"; done
if [ -z "$_lmc" ]; then ok "control lib.sh copy: an unmutated copy passes arm_em_nrm arm_em_ledger arm_em_label arm_lh"
else bad "control lib.sh copy: an UNMUTATED copy failed$_lmc -- the lib mutant harness is broken"; fi
lmutant EM-NRM    arm_em_hx_nrm    "arm_em_nrm arm_lh"    "${EM_NRM[@]}"
lmutant EM-LEDGER arm_em_hx_ledger "arm_em_ledger arm_lh" "${EM_LEDGER[@]}"
lmutant EM-LABEL  arm_em_hx_label  "arm_em_label arm_lh"  "${EM_LABEL[@]}"
# memo_diff_name_status reads names under the default core.quotePath again, on BOTH its git calls.
libmutant QP-DIFF retired-tokens.sh arm_qa_plain "arm_qa_cafe" \
  $'{ git -C "$_dist" -c core.quotePath=false diff' $'{ git -C "$_dist" diff' \
  $'    git -C "$_dist" -c core.quotePath=false diff' $'    git -C "$_dist" diff'
# preclassify's relocation listing reads names under the default core.quotePath again.
mutant QP-LSTREE reconcile preclassify.sh arm_qb_plain "arm_qb_cafe" \
  'git -C "$DIST" -c core.quotePath=false ls-tree --name-only "$THEIRS" core/scripts/' \
  'git -C "$DIST" ls-tree --name-only "$THEIRS" core/scripts/'
# pcmutant <id> <healthy-arm> "<arms>" <find> <replace>... -- mutate reconcile/preclassify.sh inside a
# WHOLE copy of the directory and drive self-update-gate.sh from it: the gate loads machinery_paths()
# out of "$(dirname "$0")/preclassify.sh", so a sibling `_m_` file would never be read.
pcmutant() {
  local id="$1" healthy="$2" arms="$3" d why a survived=""
  shift 3
  d="$MT/pc_$id"
  cp -R "$MT/reconcile" "$d" || { bad "mutant $id DID NOT APPLY (could not copy reconcile/)"; return; }
  if ! why="$(mkmut "$MT/reconcile/preclassify.sh" "$d/preclassify.sh" "$@")"; then bad "mutant $id DID NOT APPLY ($why)"; return; fi
  if cmp -s "$MT/reconcile/preclassify.sh" "$d/preclassify.sh"; then bad "mutant $id DID NOT APPLY (preclassify.sh is byte-identical)"; return; fi
  bash -n "$d/preclassify.sh" 2>/dev/null || { bad "mutant $id DID NOT APPLY (the mutated preclassify.sh does not parse)"; return; }
  if ! "$healthy" "$d/self-update-gate.sh"; then bad "mutant $id: its healthy twin $healthy failed on the mutant, so no kill can be read -- $ARM_WHY"; return; fi
  for a in $arms; do "$a" "$d/self-update-gate.sh" && survived="$survived $a"; done
  if [ -z "$survived" ]; then ok "mutant $id (preclassify.sh, driven through self-update-gate.sh) killed by:$(printf ' %s' $arms)"
  else bad "mutant $id SURVIVED$survived -- that arm cannot see its own site"; fi
}
# machinery_paths() lists the machinery set under the default core.quotePath again, on BOTH refs --
# the 9783bd6e state, where the rows were raw and the set they join against was C-quoted.
pcmutant QP-MACH arm_qc_plain "arm_qc_cafe" \
  '_mb="$(git -C "$DIST" -c core.quotePath=false ls-files --with-tree="$BASE"' '_mb="$(git -C "$DIST" ls-files --with-tree="$BASE"' \
  '_mt="$(git -C "$DIST" -c core.quotePath=false ls-files --with-tree="$THEIRS"' '_mt="$(git -C "$DIST" ls-files --with-tree="$THEIRS"'
mutant DD-HERESTRING reconcile derivation-differential.sh arm_dd_usage "arm_r5" \
  '  case "$NL$1" in *"${NL}skill_commit:"*) ;; *) return 0 ;; esac' $'  awk \'/^skill_commit:/ { f = 1 } END { exit !f }\' <<<"$1" || return 0'

echo
if [ "$fails" -eq 0 ]; then echo "procsub-staged-refusal: PASS"; exit 0; fi
echo "procsub-staged-refusal: $fails assertion(s) FAILED" >&2
exit 1
