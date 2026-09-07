#!/usr/bin/env bash
# taught-schema — assert the schema an agent is TAUGHT and the schema the gate READS
# are the same schema, and that they cannot become different ones.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# SKILL_INVOCATION_PROVENANCE v1 was described in four places at once: a regex in
# validate-provenance-block.sh, a schema comment in that script's own header, an example in
# gate-validation.md Check 17, and an example in team-roles/adversary.md — the only one the
# adversary actually reads. Four hand-synchronised copies, in three languages, with nothing
# comparing them.
#
# They diverged. adversary.md taught a bare ``` fence with no SKILL_INVOCATION_PROVENANCE_END
# terminator. The adversary emitted exactly what it was shown. The reader's regex matched
# nothing, and the reader said "no provenance block required or present" and exited 0 —
# because MALFORMED and ABSENT shared an exit code. Everything Check 17 owns (the enum, the
# unconditional mode: solo rejection, the retired pin) sat downstream of a parse that never
# happened. Two full adversarial passes of the reference consumer's sprint 290 went
# unadjudicated, and the gate called them clean. An unparseable block scores exactly like a
# clean artifact.
#
# WHY THE EXISTING FIXTURES COULD NOT SEE IT — the part that generalises:
# check-17-bypass HAND-AUTHORS its own well-formed blocks. So the fixture and the reader
# agreed with each other, and BOTH disagreed with the role file. The one artifact the LLM
# actually reads was the one artifact nothing validated. A suite that tests a checker against
# its own idea of the format cannot see the format drift out from under the instruction it
# ships to the agent.
#
# So V1 below is the assertion that matters, and it is not "the parser works." It is:
# THE EXAMPLE THE DOC TEACHES, PARSED BY THE PARSER THE GATE RUNS.

set -uo pipefail

FIXTURE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Two layouts:
#   distribution — core/fixtures/taught-schema/  beside  core/scripts/, core/schemas/
#   consumer     — tests/fixtures/taught-schema/  beside  <root>/scripts/ai-dlc/, <root>/.claude/schemas/
UP2="$(cd "$FIXTURE_DIR/../.." && pwd)"           # core/  (dist)   |  tests/  (consumer)
UP3="$(cd "$FIXTURE_DIR/../../.." && pwd)"        # repo root in both

if [ -d "$UP2/scripts" ] && [ -d "$UP2/schemas" ]; then
    SCRIPTS="$UP2/scripts"
    SCHEMA="$UP2/schemas/provenance-block.json"
    ROLE="$UP2/team-roles/adversary.md"
else
    # v0.126.0 moved consumer validators to scripts/ai-dlc/; prefer it, keep bare
    # scripts/ as a pre-relocation fallback. Assigning bare scripts/ here made this
    # fixture fail in every installed tree while passing in the distribution.
    if [ -f "$UP3/scripts/ai-dlc/validate-provenance-block.sh" ]; then
        SCRIPTS="$UP3/scripts/ai-dlc"
    else
        SCRIPTS="$UP3/scripts"
    fi
    SCHEMA="$UP3/.claude/schemas/provenance-block.json"
    ROLE="$UP3/.claude/team-roles/adversary.md"
fi

VALIDATOR="$SCRIPTS/validate-provenance-block.sh"
SYNC="$SCRIPTS/sync-taught-schema.sh"

for f in "$VALIDATOR" "$SYNC" "$SCHEMA" "$ROLE"; do
    [ -e "$f" ] || { echo "FIXTURE BROKEN: missing $f" >&2; exit 2; }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------------------
# EVERYTHING BELOW RUNS AGAINST A COPY. THE FIXTURE DOES NOT WRITE INTO THE TREE IT TESTS.
#
# THE DEFECT THIS REPLACES, measured 2026-07-29. Three of this fixture's assertions mutate
# the package to prove a check fires: V4b strips the forbidden list out of the schema, V5
# drops a hand-written probe into team-roles/, V6 edits the schema again. Every one of those
# writes landed in the LIVE tree and was undone a few lines later. Under the 16-way suite
# that is a writer racing fifteen readers:
#
#   cp: core/team-roles/zz-taught-schema-fixture-probe.md: No such file or directory
#
# -- `enforcement-map-sites`' seed enumerating team-roles/ and then finding the probe gone,
# which under `set -e` kills the seed and reports FIXTURE BROKEN on whichever of its 31
# assertions happened to be seeding at that instant. Observed on three different assertions
# in three rounds, which is why it never looked like one reproducible defect.
#
# The schema window is the worse half and produced no error at all: for the length of two
# assertions the real provenance-block.json is missing its forbidden list, and any fixture
# reading it in that window adjudicates against a schema no release ever shipped.
#
# Copying is cheap here -- scripts/, schemas/, skills/ and team-roles/, not the fixtures
# tree -- and `sync-taught-schema.sh` resolves its root SCRIPT-RELATIVE first, so the copy's
# own validator sees the copy and nothing else. Verified: with this in place the branch runs
# 5 of 5 clean where it was 3 of 5 red.
PKG="$TMP/pkg"
if [ "$SCRIPTS" = "$UP2/scripts" ]; then
    # distribution: core/ is the package
    mkdir -p "$PKG/core"
    for d in scripts schemas skills team-roles; do
        [ -d "$UP2/$d" ] && cp -R "$UP2/$d" "$PKG/core/$d"
    done
    SCRIPTS="$PKG/core/scripts"
    SCHEMA="$PKG/core/schemas/provenance-block.json"
    ROLE="$PKG/core/team-roles/adversary.md"
else
    # consumer: scripts/ai-dlc/ beside .claude/{schemas,skills,team-roles}
    mkdir -p "$PKG/root/.claude" "$PKG/root/scripts"
    cp -R "$SCRIPTS" "$PKG/root/scripts/$(basename "$SCRIPTS")"
    for d in schemas skills team-roles; do
        [ -d "$UP3/.claude/$d" ] && cp -R "$UP3/.claude/$d" "$PKG/root/.claude/$d"
    done
    SCRIPTS="$PKG/root/scripts/$(basename "$SCRIPTS")"
    SCHEMA="$PKG/root/.claude/schemas/provenance-block.json"
    ROLE="$PKG/root/.claude/team-roles/adversary.md"
fi
VALIDATOR="$SCRIPTS/validate-provenance-block.sh"
SYNC="$SCRIPTS/sync-taught-schema.sh"

# The copy is re-checked rather than assumed. A partial copy would let every assertion below
# fail for a reason that has nothing to do with what it tests, and a MISSING schema makes
# `--check` exit non-zero -- which V5 scores as its own success.
for f in "$VALIDATOR" "$SYNC" "$SCHEMA" "$ROLE"; do
    [ -e "$f" ] || { echo "FIXTURE BROKEN: the sandbox copy is missing $f" >&2; exit 2; }
done

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1" >&2; }

# ---------------------------------------------------------------------------------------
# V1. THE ROUND TRIP. Lift the example adversary.md TEACHES, feed it to the parser the gate
#     RUNS, and require the parser to see exactly one block. This is the assertion whose
#     absence let sprint 290 happen: nothing ever ran the taught example through the reader.
# ---------------------------------------------------------------------------------------
python3 - "$ROLE" "$SCHEMA" "$TMP/taught.md" <<'PYEOF'
import json, re, sys
role, schema_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
S = json.load(open(schema_path))
env = S["envelope"]
content = open(role, encoding="utf-8").read()

# The block as the doc actually presents it to the agent, inside its fence.
m = re.search(r"^```[^\n]*\n(.*?)^```", content[content.find("BEGIN GENERATED: provenance-block"):], re.S | re.M)
if not m:
    print("FIXTURE BROKEN: adversary.md teaches no fenced provenance example", file=sys.stderr)
    sys.exit(2)
taught = m.group(1)

# Substitute the <placeholders> for schema-valid values. We are testing the ENVELOPE and the
# FIELD SET the doc teaches — not the author's ability to fill in a sha.
subs = {
    "invoked_at": "2026-07-14T18:20:00Z",
    "tool_use_id": "toolu_01ABCDEFGHIJKLMNOP",
    "lead_role": "carry-over-evaluation",
    "artifact": "_bmad-output/pipeline-snapshot.md",
    "artifact_sha": "0" * 64,
    "findings_critical": "0",
    "findings_critical_prior_scope": "0",
    "findings_major": "0",
    "findings_major_underived": "0",
    "findings_minor": "1",
    "verdict": "EXIT_CONDITION_MET",
}
lines = []
for line in taught.splitlines():
    key = re.match(r"^([a-z_]+):", line)
    if key and key.group(1) in subs:
        lines.append(f"{key.group(1)}: {subs[key.group(1)]}")
    elif key and key.group(1) == "resolves_divergence":
        continue          # optional, and only legal on a verification pass
    else:
        lines.append(line)
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PYEOF
[ $? -eq 0 ] || { echo "FIXTURE BROKEN: could not lift the taught example" >&2; exit 2; }

if bash "$VALIDATOR" "$TMP/taught.md" >"$TMP/v1" 2>&1; then
    ok "V1 the example adversary.md TEACHES parses in the validator the gate RUNS"
else
    bad "V1 the taught example does NOT parse in the reader — the teaching and the reading have diverged again"
    sed 's/^/        /' "$TMP/v1" >&2
fi

# ---------------------------------------------------------------------------------------
# V2. MALFORMED != ABSENT. The real sprint-290 defect: the block in a ``` fence, no
#     terminator. Must FAIL as malformed — not pass as "no block present".
# ---------------------------------------------------------------------------------------
cat >"$TMP/fenced.md" <<'EOF'
# Adversarial Review, Pass 1

```
SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
mode: subagent
verdict: EXIT_CONDITION_NOT_MET
```
EOF
if bash "$VALIDATOR" "$TMP/fenced.md" >"$TMP/v2" 2>&1; then
    bad "V2 a fenced block (no delimiters) PASSED — malformed is being read as absent again"
else
    if grep -q "MALFORMED, not absent" "$TMP/v2"; then
        ok "V2 a fenced block FAILS as MALFORMED (not silently as 'no block present')"
    else
        bad "V2 failed, but not as malformed — the diagnosis is wrong: $(head -1 "$TMP/v2")"
    fi
fi

# ---------------------------------------------------------------------------------------
# V3. No over-fire. A doc with genuinely no provenance block must still pass.
# ---------------------------------------------------------------------------------------
printf '# a doc\n\nNo provenance here.\n' >"$TMP/none.md"
if bash "$VALIDATOR" "$TMP/none.md" >/dev/null 2>&1; then
    ok "V3 an artifact with no block at all still passes (the malformed check does not over-fire)"
else
    bad "V3 an artifact with no block FAILED — the malformed check is over-firing"
fi

# ---------------------------------------------------------------------------------------
# V4. mode: solo is refused. v0.58.0's only teeth. Unreachable while the block did not parse.
# ---------------------------------------------------------------------------------------
sed 's/^mode: subagent/mode: solo/' "$TMP/taught.md" >"$TMP/solo.md"
if bash "$VALIDATOR" "$TMP/solo.md" >"$TMP/v4" 2>&1; then
    bad "V4 mode: solo PASSED — Rule 20's only enforcement is dark"
else
    ok "V4 mode: solo is refused (v0.58.0's rung is reachable again)"
fi

# ---------------------------------------------------------------------------------------
# V4b. A placeholder tool_use_id literal that CLEARS the toolu_ charset (toolu_PLACEHOLDER)
#      is refused as forbidden. tool_use_id is checked for SHAPE ONLY, so a value that
#      passes the pattern but was never emitted by a real Skill/Agent call is a forged
#      evidence cell — the same class as mode: solo. The schema carries the forbidden list;
#      check_value enforces it for every field that declares one.
# ---------------------------------------------------------------------------------------
sed 's/^tool_use_id: .*/tool_use_id: toolu_PLACEHOLDER/' "$TMP/taught.md" >"$TMP/placeholder.md"
if bash "$VALIDATOR" "$TMP/placeholder.md" >"$TMP/v4b" 2>&1; then
    bad "V4b a placeholder tool_use_id (toolu_PLACEHOLDER) PASSED — a forged evidence cell is unpoliced"
elif grep -q "is forbidden" "$TMP/v4b"; then
    ok "V4b a placeholder tool_use_id is refused as forbidden (clears the charset, not from the run)"
else
    bad "V4b failed, but not as forbidden — the diagnosis is wrong: $(head -1 "$TMP/v4b")"
fi

# ---------------------------------------------------------------------------------------
# V4c. A DECORATED placeholder is the same forged cell and must be refused too. V4b seeded
#      only the BARE literal, so for as long as it has existed it could not tell exact
#      matching from prefix matching — and under exact matching
#      `toolu_PLACEHOLDER_LEAD_TO_FILL` PASSED, on the reference consumer's live artifact.
#      The near-miss is seeded BESIDE the offender, in this same arm rather than in a
#      second clean run, because a separate run can only ask whether the check fires at
#      all and never whether it fires on the right values.
# ---------------------------------------------------------------------------------------
sed 's/^tool_use_id: .*/tool_use_id: toolu_PLACEHOLDER_LEAD_TO_FILL/' \
    "$TMP/taught.md" >"$TMP/decorated.md"
sed 's/^tool_use_id: .*/tool_use_id: toolu_01ABCdefGHIjklMNOpqrST/' \
    "$TMP/taught.md" >"$TMP/nearmiss.md"
if bash "$VALIDATOR" "$TMP/decorated.md" >"$TMP/v4c" 2>&1; then
    bad "V4c a DECORATED placeholder (toolu_PLACEHOLDER_LEAD_TO_FILL) PASSED — decoration defeats the forbidden list"
elif ! grep -q "is forbidden" "$TMP/v4c"; then
    bad "V4c failed, but not as forbidden — the diagnosis is wrong: $(head -1 "$TMP/v4c")"
elif ! bash "$VALIDATOR" "$TMP/nearmiss.md" >"$TMP/v4c.near" 2>&1; then
    bad "V4c NEAR-MISS a real-shaped tool_use_id was REJECTED — the match is too wide: $(head -2 "$TMP/v4c.near" | tail -1)"
else
    ok "V4c a decorated placeholder is refused and a real-shaped id is not (the match is by prefix, and it discriminates)"
fi

# MUTATION control for V4b: strip the tool_use_id `forbidden` list from the schema and
# require the SAME placeholder block to go green. The FAIL above is evidence for the
# forbidden list only if removing it removes the FAIL. Anti-vacuity is STRUCTURAL (not cmp,
# and no longer a whole-file grep): json.dump reformats the whole file, so a byte diff would
# report "changed" even for a no-op strip — and a whole-file grep for the token is satisfied
# by any PROSE that quotes it. That is not hypothetical: this arm failed the moment the
# schema's own `forbidden_match_reason` began naming `toolu_PLACEHOLDER_LEAD_TO_FILL` to
# explain why the match is by prefix, because the token survived a strip that had in fact
# removed the whole list. Ask the parsed schema whether the FIELD still carries the key.
field_has() {  # field_has <schema> <field> <key> -> 0 if that field carries that key
    python3 -c 'import json,sys
S=json.load(open(sys.argv[1]))
sys.exit(0 if any(f["name"]==sys.argv[2] and sys.argv[3] in f for f in S["fields"]) else 1)' "$@"
}
cp "$SCHEMA" "$TMP/schema.v4b.bak"
python3 - "$SCHEMA" <<'PYEOF'
import json, sys
p = sys.argv[1]
S = json.load(open(p))
for f in S["fields"]:
    if f["name"] == "tool_use_id":
        f.pop("forbidden", None)
        f.pop("forbidden_reason", None)
json.dump(S, open(p, "w"), indent=2, ensure_ascii=False)
PYEOF
if ! field_has "$TMP/schema.v4b.bak" tool_use_id forbidden; then
    bad "V4b MUTATION setup — the real schema has no tool_use_id forbidden list to strip"
elif field_has "$SCHEMA" tool_use_id forbidden; then
    bad "V4b MUTATION matched nothing — the tool_use_id forbidden list survived the strip"
elif bash "$VALIDATOR" "$TMP/placeholder.md" >/dev/null 2>&1; then
    ok "V4b MUTATION — removing the forbidden list lets the placeholder pass (the list is what fires)"
else
    bad "V4b MUTATION — placeholder still refused without the forbidden list; V4b proves nothing"
fi
cp "$TMP/schema.v4b.bak" "$SCHEMA"

# MUTATION control for V4c, and it is a DIFFERENT mutation from V4b's on purpose. Stripping
# the whole forbidden list kills V4b and V4c together, so it establishes that the list
# fires and says nothing about the MATCH MODE — which is the property V4c owns. This one
# reverts `forbidden_match` to exact, leaving the list intact, and requires the DECORATED
# block to go green while the BARE one stays refused. That pair is the whole finding: under
# exact matching the two inputs are scored differently, and only decoration separates them.
cp "$SCHEMA" "$TMP/schema.v4c.bak"
python3 - "$SCHEMA" <<'PYEOF'
import json, sys
p = sys.argv[1]
S = json.load(open(p))
for f in S["fields"]:
    if f["name"] == "tool_use_id":
        f.pop("forbidden_match", None)
json.dump(S, open(p, "w"), indent=2, ensure_ascii=False)
PYEOF
if ! field_has "$TMP/schema.v4c.bak" tool_use_id forbidden_match; then
    bad "V4c MUTATION setup — the real schema declares no forbidden_match on tool_use_id to revert"
elif field_has "$SCHEMA" tool_use_id forbidden_match; then
    bad "V4c MUTATION matched nothing — tool_use_id's forbidden_match survived the revert"
elif ! bash "$VALIDATOR" "$TMP/decorated.md" >/dev/null 2>&1; then
    bad "V4c MUTATION — the decorated placeholder is STILL refused under exact matching; V4c proves nothing about the match mode"
elif bash "$VALIDATOR" "$TMP/placeholder.md" >/dev/null 2>&1; then
    bad "V4c MUTATION — the BARE literal also passed, so the mutation removed the list rather than the match mode"
else
    ok "V4c MUTATION — reverting forbidden_match to exact lets the DECORATED placeholder pass while the bare one stays refused (prefix matching is what fires)"
fi
cp "$TMP/schema.v4c.bak" "$SCHEMA"

# ---------------------------------------------------------------------------------------
# V5. INVARIANT: no hand-written example may exist in an agent-read file. This is the one
#     that stops the regression from coming back — a generated region beside a hand-written
#     one is three copies with a fresh coat of paint.
# ---------------------------------------------------------------------------------------
SENTINEL="$(dirname "$ROLE")/zz-taught-schema-fixture-probe.md"
cat >"$SENTINEL" <<'EOF'
# probe

```
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
SKILL_INVOCATION_PROVENANCE_END -->
```
EOF
if bash "$SYNC" --check >"$TMP/v5" 2>&1; then
    bad "V5 a HAND-WRITTEN example in an agent-read file was NOT caught — the schema can fork again"
else
    if grep -q "HAND-WRITTEN" "$TMP/v5"; then
        ok "V5 a hand-written example in an agent-read file is refused (the schema cannot fork)"
    else
        bad "V5 --check failed for the wrong reason: $(head -1 "$TMP/v5")"
    fi
fi
rm -f "$SENTINEL"

# ---------------------------------------------------------------------------------------
# V6. INVARIANT: a schema edit must reach every taught example, or --check fails. Proves the
#     docs are DERIVED, not merely consistent-right-now.
# ---------------------------------------------------------------------------------------
cp "$SCHEMA" "$TMP/schema.bak"
python3 - "$SCHEMA" <<'PYEOF'
import json, sys
p = sys.argv[1]
S = json.load(open(p))
for f in S["fields"]:
    if f["name"] == "verdict":
        f["placeholder"] = "<MUTANT_PLACEHOLDER_THE_DOCS_HAVE_NOT_SEEN>"
json.dump(S, open(p, "w"), indent=2, ensure_ascii=False)
PYEOF
if bash "$SYNC" --check >"$TMP/v6" 2>&1; then
    bad "V6 the schema changed and every taught example still passed --check — the docs are NOT derived from it"
else
    if grep -q "STALE" "$TMP/v6"; then
        ok "V6 a schema edit makes the taught examples STALE until re-rendered (the docs derive from the schema)"
    else
        bad "V6 --check failed for the wrong reason: $(head -1 "$TMP/v6")"
    fi
fi
cp "$TMP/schema.bak" "$SCHEMA"

# Leave the tree exactly as we found it.
bash "$SYNC" >/dev/null 2>&1
if ! bash "$SYNC" --check >/dev/null 2>&1; then
    echo "FIXTURE BROKEN: could not restore the tree to a synced state" >&2
    exit 2
fi

echo ""
echo "taught-schema: ${PASS} passed, ${FAIL} failed."
[ "$FAIL" -eq 0 ] || exit 1
exit 0
