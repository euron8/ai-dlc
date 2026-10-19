#!/usr/bin/env bash
# layer-adjudication-tier/receipt.sh <tree> -- a register verdict clears a keyed layer row only
# with evidence the entry was READ against that clause's core change.
#
#   exit 0   the fix is present in <tree>
#   exit 1   it is not (the line naming the first missing property is printed)
#   exit 9   the receipt cannot measure: no <tree>, no layer-drift.sh in it, no jq, or no world
#
# <tree> is a distribution checkout (core/skills/...) or an installed one (.claude/skills/...).
# layer-drift.sh is taken from <tree>, never from beside this file, so one receipt scores any build.
#
# THE WORLD (two mktemp git repositories):
#   dist     steps/demo.md: `## Alpha gate` unchanged, `## Gamma review` rewritten BASE..THEIRS;
#            steps/stable.md UNCHANGED across the range, with `## Stable Section` superseded at
#            THEIRS through override_supersessions. LC-E4 and LC-O15 at ADJUDICATED, LC-E19 at WARN.
#   consumer an LC-E4 extension hooking demo.md; an override shadowing stable.md#Stable Section;
#            an extension whose heading title-matches it (LC-E19). Each is the only row of its kind.
# (a) an LC-E4 verdict with no `read` still blocks;
# (b) one whose entry_line and core_line are verbatim lines of their sides clears (the control);
# (c) an entry_line that is a CORE line, not an entry line, blocks;
# (d) a core_line that is in demo.md at THEIRS but NOT in the range diff blocks -- the quote is
#     absent from the side it names;
# (e) LC-O15 and LC-E19 rows on the UNCHANGED stable.md clear with correct records, which a source
#     keyed on the range diff (empty there) cannot do.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

TREE="${1:-}"
[ -n "$TREE" ] && [ -d "$TREE" ] || { echo "receipt: no tree named (usage: receipt.sh <tree>)" >&2; exit 9; }
TREE="$(cd "$TREE" && pwd -P)"
LD=""
for c in "$TREE/core/skills/ai-dlc-update/reconcile" "$TREE/.claude/skills/ai-dlc-update/reconcile"; do
  [ -f "$c/layer-drift.sh" ] && [ -f "$c/lib.sh" ] && { LD="$c/layer-drift.sh"; break; }
done
[ -n "$LD" ] || { echo "receipt: $TREE carries no layer-drift.sh beside its lib.sh in either layout" >&2; exit 9; }
command -v jq >/dev/null 2>&1 || { echo "receipt: jq is not on PATH, so no register can be read" >&2; exit 9; }
miss() { echo "receipt: STILL LIVE -- $*"; exit 1; }

W="$(mktemp -d "${TMPDIR:-/tmp}/adj-read-receipt.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
D="$W/dist"; C="$W/cons"; S=core/skills/ai-dlc
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid -c core.hooksPath=/dev/null -c maintenance.auto=false "${@:2}"; }
mkdir -p "$D/$S/steps" "$D/core/schemas" || exit 9
g "$D" init -q || exit 9
cat > "$D/core/schemas/layer-adjudication-register.json" <<'EOF'
{
  "type": "object",
  "properties": {
    "verdict": {
      "type": "string",
      "enum": [
        "still-additive",
        "contradicts-core",
        "retire"
      ]
    }
  }
}
EOF
contract() {
  printf 'contract_version: 7\nclauses:\n'
  printf '  - id: LC-E4\n    subject: extension\n    level: ADJUDICATED\n    code: EXTENSION-HOOK-DRIFT\n'
  printf '  - id: LC-O15\n    subject: override\n    level: ADJUDICATED\n    code: OVERRIDE-SUPERSEDED\n'
  printf '  - id: LC-E19\n    subject: extension\n    level: WARN\n    code: EXTENSION-TITLE-MATCHES-CORE\n'
  [ "$1" = 1 ] && printf 'override_supersessions:\n  - shadows: steps/stable.md#Stable Section\n    since_core_version: "9.9.9"\n    reason: core took it.\n'
  return 0
}
contract 0 > "$D/$S/layer-contract.yaml"
printf '# Demo\n\n## Alpha gate\n\nAlpha body line that stays the same across the whole range.\n\n## Gamma review\n\nGamma body line as it reads at the base of the range.\n' > "$D/$S/steps/demo.md"
printf '# Stable\n\n## Stable Section\n\nThe stable core body line that never moves across the range.\n\n## Other Part\n\nAnother core line that is not in the shadowed section at all.\n' > "$D/$S/steps/stable.md"
g "$D" add -A && g "$D" commit -qm base || exit 9
B="$(g "$D" rev-parse HEAD)" || exit 9
contract 1 > "$D/$S/layer-contract.yaml"
printf '# Demo\n\n## Alpha gate\n\nAlpha body line that stays the same across the whole range.\n\n## Gamma review\n\nGamma body line rewritten at theirs, which the re-read fires on.\n' > "$D/$S/steps/demo.md"
g "$D" add -A && g "$D" commit -qm theirs || exit 9
T="$(g "$D" rev-parse HEAD)" || exit 9
g "$D" diff --quiet "$B" "$T" -- "$S/steps/stable.md" || { echo "receipt: the world is wrong: stable.md moved in the range" >&2; exit 9; }

X=.claude/skills/ai-dlc/extensions/hooked.md
O=.claude/skills/ai-dlc/overrides/stable-ov.md
E=.claude/skills/ai-dlc/extensions/stable-ext.md
mkdir -p "$C/.claude/skills/ai-dlc/extensions" "$C/.claude/skills/ai-dlc/overrides" "$C/_bmad-output/ai-dlc-update" || exit 9
printf -- '---\nkind: check\nhooks: steps/demo.md\nreason: receipt entry\n---\n\nThe consumer line this hooked extension adds to the demo step.\n' > "$C/$X"
printf -- '---\nshadows: steps/stable.md#Stable Section\nbase_sha: %s\nreason: receipt override\nconforms_to: 7\n---\n\n## Stable Section\n\nThe consumer replacement body for the stable section, long enough.\n' "$B" > "$C/$O"
printf -- '---\nkind: check\nhooks: steps/stable.md\nreason: receipt title-match entry\n---\n\n## Stable Section\n\nThe consumer augmenting body that sits under the stable title.\n' > "$C/$E"
g "$C" init -q && g "$C" add -A && g "$C" commit -qm c || exit 9
REG="$C/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"

run() { bash "$LD" "$D" "$B" "$T" "$C" 2>/dev/null; }
blocking() { run | awk -F'\t' -v e="$1" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e' | grep -c .; }
rec() { # $1 clause $2 entry $3 digest $4 entry_line|- $5 core_line
  if [ "$4" = - ]; then
    jq -cn --arg c "$1" --arg e "$2" --arg d "$3" '{clause:$c,entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"receipt"}'
  else
    jq -cn --arg c "$1" --arg e "$2" --arg d "$3" --arg el "$4" --arg cl "$5" '{clause:$c,entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"receipt",read:{entry_line:$el,core_line:$cl}}'
  fi
}

rm -f "$REG"
OUT="$(run)"
dig() { printf '%s\n' "$OUT" | awk -F'\t' -v s="$1" -v e="$2" '$1==s && $2==e' | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1; }
DX="$(dig HARD-LAYER-ADJUDICATION-MISSING "$X")"
DO="$(dig HARD-LAYER-ADJUDICATION-MISSING "$O")"
DE="$(dig EXTENSION-TITLE-MATCHES-CORE "$E")"
[ ${#DX} -eq 40 ] && [ ${#DO} -eq 40 ] && [ ${#DE} -eq 40 ] \
  || { echo "receipt: the world produced no keyed row for one of its three entries (LC-E4 '$DX', LC-O15 '$DO', LC-E19 '$DE')" >&2; exit 9; }

XL="The consumer line this hooked extension adds to the demo step."
CL="Gamma body line rewritten at theirs, which the re-read fires on."
OFF="Alpha body line that stays the same across the whole range."

rec LC-E4 "$X" "$DX" - > "$REG"
[ "$(blocking "$X")" -eq 1 ] || miss "(a) an LC-E4 verdict with NO read evidence clears the blocking row"
rec LC-E4 "$X" "$DX" "$XL" "$CL" > "$REG"
[ "$(blocking "$X")" -eq 0 ] || miss "(b) an LC-E4 verdict whose entry_line and core_line are verbatim lines of their sides does not clear (the control)"
rec LC-E4 "$X" "$DX" "$CL" "$CL" > "$REG"
[ "$(blocking "$X")" -eq 1 ] || miss "(c) an entry_line that is a core line, not a line of the entry, clears the row"
rec LC-E4 "$X" "$DX" "$XL" "$OFF" > "$REG"
[ "$(blocking "$X")" -eq 1 ] || miss "(d) a core_line in demo.md at theirs but NOT in the range diff clears the LC-E4 row"
{ rec LC-O15 "$O" "$DO" "The consumer replacement body for the stable section, long enough." "The stable core body line that never moves across the range."
  rec LC-E19 "$E" "$DE" "The consumer augmenting body that sits under the stable title." "The stable core body line that never moves across the range."; } > "$REG"
OUT2="$(run)"
[ "$(printf '%s\n' "$OUT2" | awk -F'\t' -v e="$O" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e' | grep -c .)" -eq 0 ] \
  || miss "(e) a correct LC-O15 record on an UNCHANGED target does not clear its row"
[ "$(printf '%s\n' "$OUT2" | awk -F'\t' -v e="$E" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e' | grep -c .)" -eq 0 ] \
  || miss "(e) a correct LC-E19 record on an UNCHANGED target does not clear its row"
echo "receipt: fix present -- (a)-(e) hold in $LD"
exit 0
