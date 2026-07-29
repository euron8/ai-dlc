#!/usr/bin/env bash
# stray-party-mode-provenance/seed.sh — a whole seeded PROJECT, not one artifact.
#
# --strays takes no artifact: its subject is a tree, and every question the fixture asks is about
# where a file SITS, so the fixture has to build somewhere for files to sit. The tree carries one
# party-mode block in each home the schema declares, one in a file with no pipeline-validation
# purpose (the only true finding), one inside a generated region, and one informational block that
# must never be confused for either.
#
# Copies of the shipping schema and the shipping script go in, and the mutants below are made from
# those copies — never from the originals in the tree. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-provenance-block.sh" ]; then
  VALIDATOR_SRC="$D_ROOT/core/scripts/validate-provenance-block.sh"
  SCHEMA_SRC="$D_ROOT/core/schemas/provenance-block.json"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-provenance-block.sh" ]; then
  VALIDATOR_SRC="$C_ROOT/scripts/ai-dlc/validate-provenance-block.sh"
  SCHEMA_SRC="$C_ROOT/.claude/schemas/provenance-block.json"
else
  echo "FIXTURE ERROR: validate-provenance-block.sh not found in either layout" >&2
  exit 2
fi
[ -f "$SCHEMA_SRC" ] || { echo "FIXTURE ERROR: provenance-block.json not found beside the validator" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stray-party.XXXXXX")" || exit 2
P="$WORK/proj"

mkdir -p "$P/.claude/schemas" "$P/.claude/skills/ai-dlc/extensions" "$P/scripts/ai-dlc" \
         "$P/docs/retro" "$P/docs/reviews" "$P/_bmad-output/party-mode-transcripts" \
         "$P/tests/fixtures/forgery-corpus" "$P/server" "$P/scripts/tests"

cp "$SCHEMA_SRC" "$P/.claude/schemas/provenance-block.json"
cp "$VALIDATOR_SRC" "$P/scripts/ai-dlc/validate-provenance-block.sh"

# The block body is assembled from parts rather than written whole, for the reason v0.194.0
# recorded: a fixture that spells out the tokens a live scan looks for becomes a subject of that
# scan the moment anything points it at core/fixtures/. Every writer below composes the envelope
# from $OPEN/$CLOSE, so this file carries no complete block of its own.
OPEN="<!-- SKILL_INVOCATION_PROVENANCE v1"
CLOSE="SKILL_INVOCATION_PROVENANCE_END -->"
PARTY="bmad-party-mode"
INFORMATIONAL="bmad-prd"

# block <file> <skill-value> [<heading>]
block() {
  { [ -n "${3:-}" ] && printf '%s\n\n' "$3"
    printf '%s\n' "$OPEN"
    printf 'skill: %s\n' "$2"
    printf 'invoked_at: 2026-07-28T09:00:00Z\n'
    printf 'mode: subagent\n'
    printf '%s\n' "$CLOSE"
  } > "$1"
}

# --- the homes the schema declares: each holds a real party-mode block ---------
block "$P/docs/retro/sprint-1.md"                          "$PARTY" "# Retro — sprint 1"
block "$P/_bmad-output/party-mode-transcripts/s1-retro.md" "$PARTY" "# Transcript"
block "$P/docs/reviews/adversarial-1.md"                   "$PARTY" "# Review"
block "$P/tests/fixtures/forgery-corpus/forged.md"         "$PARTY" "# Forged, on purpose"

# --- the one true finding: a service file with no pipeline-validation purpose --
block "$P/server/handler.py" "$PARTY" "# handler"

# --- a party-mode block carrying the inline teaching a taught example carries --
# Under the shipping parser this IS a stray; it is here so the trailing-comment rule has a
# subject, because a forger copies the example they were shown, comments and all.
{ printf '# notes\n\n%s\n' "$OPEN"
  printf 'skill: %s                      # the evaluation that ACTUALLY RAN\n' "$PARTY"
  printf 'mode: subagent\n%s\n' "$CLOSE"
} > "$P/server/commented.py"

# --- an INFORMATIONAL block outside every home: must never be reported ---------
# The scan's whole justification is that it does NOT re-litigate the current-scope carve-out.
block "$P/server/informational.py" "$INFORMATIONAL" "# aggregate"

# --- a party-mode block INSIDE a generated region -----------------------------
# What sync-taught-schema.sh renders. Built from the schema's own region_slug, so a fixture that
# still passed after the slug changed would be asserting against a region nobody writes.
SLUG="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["region_slug"])' "$SCHEMA_SRC")"
[ -n "$SLUG" ] || { echo "FIXTURE ERROR: schema declares no region_slug" >&2; exit 2; }
{ printf '# taught\n\n'
  printf '<!-- BEGIN GENERATED: %s/retro-party-mode — source: .claude/schemas/provenance-block.json; do not edit by hand -->\n' "$SLUG"
  printf '```\n%s\n' "$OPEN"
  printf 'skill: %s                      # the evaluation that ACTUALLY RAN\n' "$PARTY"
  printf '%s\n```\n' "$CLOSE"
  printf '<!-- END GENERATED: %s -->\n' "$SLUG"
} > "$P/docs/taught.md"

# --- consumer extension variants ----------------------------------------------
printf '{ "party_mode_homes": ["server/**"] }\n'   > "$WORK/ext-adds-server.json"
printf '{ "party_mode_homes": "server/**" }\n'     > "$WORK/ext-malformed-type.json"
printf '{ "party_mode_homes": ["ser*ver/x"] }\n'   > "$WORK/ext-bad-glob.json"

# --- mutants: COPIES, each one edit, each guarded by cmp -s -------------------
V="$P/scripts/ai-dlc/validate-provenance-block.sh"
S="$P/.claude/schemas/provenance-block.json"

# The unmutated control. A lone copy of a script that dies on its own preamble emits nothing, and
# "no output" scores as a kill for every mutant at once — v0.196.0's fixture learned that the
# hard way. This copy is run first and must behave exactly like the tree's.
cp "$V" "$WORK/validator-control.sh"
cp "$S" "$WORK/schema-control.json"

mutate_py() { # <src> <dst> <old-literal> <new-literal> <label>
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
text = open(src, encoding="utf-8").read()
if text.count(old) != 1:
    sys.stderr.write(f"FIXTURE ERROR: mutation anchor appears {text.count(old)} times, want 1\n")
    sys.exit(2)
open(dst, "w", encoding="utf-8").write(text.replace(old, new))
PY
  [ $? -eq 0 ] || { echo "FIXTURE ERROR: mutation $5 failed" >&2; exit 2; }
  cmp -s "$1" "$2" && { echo "FIXTURE ERROR: mutation $5 changed nothing" >&2; exit 2; }
}

# MUT-C: the generated-region marker drifts to a second spelling — the exact failure the schema's
# region_slug key exists to make impossible. The carve-out stops matching; the taught example
# reads as a forgery.
mutate_py "$V" "$WORK/mut-region.sh" \
  'GEN_OPEN = "BEGIN GENERATED: " + S["region_slug"] + "/"' \
  'GEN_OPEN = "BEGIN GENERATEDX: " + S["region_slug"] + "/"' "region"

# MUT-D: the trailing-comment rule is dropped, so a block copied from a taught example — comments
# and all — stops being recognised as party-mode at all.
mutate_py "$V" "$WORK/mut-comment.sh" \
  'value = re.sub(r"\s+#.*$", "", stripped.split(":", 1)[1]).strip()' \
  'value = stripped.split(":", 1)[1].strip()' "comment"

# MUT-A: a declared home is removed from the schema. The retro document becomes a finding.
python3 - "$S" "$WORK/schema-no-retro.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
before = list(d["stray_scan"]["homes"])
d["stray_scan"]["homes"] = [h for h in before if h != "docs/retro/**"]
if len(d["stray_scan"]["homes"]) == len(before):
    sys.stderr.write("FIXTURE ERROR: docs/retro/** was not in homes\n"); sys.exit(2)
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), indent=2)
PY
[ $? -eq 0 ] || exit 2
cmp -s "$S" "$WORK/schema-no-retro.json" && { echo "FIXTURE ERROR: home mutation changed nothing" >&2; exit 2; }

# MUT-B: the subject vocabulary is emptied. A scan with nothing to look for reports PASS on every
# tree there is, which is this repo's named defect class in its purest form.
python3 - "$S" "$WORK/schema-no-skills.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if not d["stray_scan"]["party_mode_skills"]:
    sys.stderr.write("FIXTURE ERROR: party_mode_skills already empty\n"); sys.exit(2)
d["stray_scan"]["party_mode_skills"] = []
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), indent=2)
PY
[ $? -eq 0 ] || exit 2
cmp -s "$S" "$WORK/schema-no-skills.json" && { echo "FIXTURE ERROR: skills mutation changed nothing" >&2; exit 2; }

cat > "$WORK/env.sh" <<ENV
WORK="$WORK"
PROJ="$P"
VALIDATOR="$V"
SCHEMA="$S"
CONTROL_VALIDATOR="$WORK/validator-control.sh"
CONTROL_SCHEMA="$WORK/schema-control.json"
MUT_REGION="$WORK/mut-region.sh"
MUT_COMMENT="$WORK/mut-comment.sh"
SCHEMA_NO_RETRO="$WORK/schema-no-retro.json"
SCHEMA_NO_SKILLS="$WORK/schema-no-skills.json"
EXT_ADDS_SERVER="$WORK/ext-adds-server.json"
EXT_MALFORMED_TYPE="$WORK/ext-malformed-type.json"
EXT_BAD_GLOB="$WORK/ext-bad-glob.json"
ENV

printf '%s\n' "$WORK"
