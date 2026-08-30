#!/usr/bin/env bash
# seed.sh — build a throwaway DISTRIBUTION repo and a consumer tree for
# predicate-differential.sh to run against.
#
# THE OFFENDER AND ITS NEAR-MISS SIT IN ONE CORPUS, BY CONSTRUCTION. A near-miss standing in a
# SEPARATE run can only ask whether the arm fires at all, never whether it fires on the RIGHT
# series — in the run where it fires there is nothing present it should have stayed quiet
# about. So the consumer carries both a series that crosses the moved threshold and one that
# does not, and the fixture asserts the row names the first and NOT the second.
#
# Prints the path of the seeded root. `$ROOT/dist` is a git repo with the predicate at two
# refs; `$ROOT/consumer` holds the stored artifacts.
set -uo pipefail

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/predicate-reclass-XXXXXX")"
mkdir -p "$ROOT/dist/core/scripts" "$ROOT/dist/core/schemas" "$ROOT/consumer/_bmad-output/planning-artifacts"

# ---- the toy predicate ---------------------------------------------------------------------
# TWO SHAPES, BECAUSE THE DETECTOR MUST HANDLE BOTH AND ONE OF THEM IS THE HARD ONE.
# `toy-predicate.sh` carries its ceiling INLINE, like validate-adversarial-convergence.sh.
# `toy-schema-predicate.sh` RESOLVES its ceiling from a schema beside it, like
# validate-provenance-block.sh, whose header says "THE SCHEMA IS NOT IN THIS FILE". A
# script-only differential is vacuous for the second: measured at v0.382.0, where
# provenance-block.json changed and its script was byte-identical on both sides.
write_predicate() {  # $1 = ceiling
  cat > "$ROOT/dist/core/scripts/toy-predicate.sh" <<PRED
#!/usr/bin/env bash
# toy adjudication predicate — verdict on already-stored artifacts.
set -uo pipefail
CEILING=$1
SERIES=""
while [ \$# -gt 0 ]; do
  case "\$1" in --series) SERIES="\$2"; shift 2 ;; *) shift ;; esac
done
rc=0
for f in "\$SERIES"*; do
  [ -f "\$f" ] || continue
  v="\$(sed -n 's/^value:[[:space:]]*//p' "\$f" | head -1)"
  [ -n "\$v" ] || { echo "FAIL (A -- VOCABULARY): \$f declares no value:"; rc=1; continue; }
  if [ "\$v" -gt "\$CEILING" ]; then
    echo "FAIL (B -- CONSISTENCY): \$f declares \$v above ceiling \$CEILING"
    rc=1
  fi
done
exit \$rc
PRED
  chmod +x "$ROOT/dist/core/scripts/toy-predicate.sh"
}

# BYTE-IDENTICAL ACROSS EVERY REF, DELIBERATELY. Its verdict moves only because the schema
# beside it moves. Any differential comparing scripts scores this as unchanged, forever.
write_schema_predicate() {
  cat > "$ROOT/dist/core/scripts/toy-schema-predicate.sh" <<'PRED'
#!/usr/bin/env bash
# toy schema-backed predicate — the ceiling is NOT in this file.
set -uo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)"
CEILING="$(sed -n 's/^ceiling:[[:space:]]*//p' "$SELF/../schemas/toy-schema.yaml" 2>/dev/null | head -1)"
[ -n "$CEILING" ] || { echo "FAIL (S -- SCHEMA): schema not resolvable"; exit 2; }
SERIES=""
while [ $# -gt 0 ]; do
  case "$1" in --series) SERIES="$2"; shift 2 ;; *) shift ;; esac
done
rc=0
for f in "$SERIES"*; do
  [ -f "$f" ] || continue
  v="$(sed -n 's/^value:[[:space:]]*//p' "$f" | head -1)"
  [ -n "$v" ] || continue
  if [ "$v" -gt "$CEILING" ]; then
    echo "FAIL (B -- CONSISTENCY): $f declares $v above ceiling $CEILING"
    rc=1
  fi
done
exit $rc
PRED
  chmod +x "$ROOT/dist/core/scripts/toy-schema-predicate.sh"
}
write_schema() { printf 'ceiling: %s\n' "$1" > "$ROOT/dist/core/schemas/toy-schema.yaml"; }

# ---- the distribution, two refs ------------------------------------------------------------
git -C "$ROOT/dist" init -q 2>/dev/null
git -C "$ROOT/dist" config user.email fixture@example.invalid
git -C "$ROOT/dist" config user.name fixture

write_predicate 3
write_schema_predicate
write_schema 3
echo 0.0.1 > "$ROOT/dist/VERSION"
git -C "$ROOT/dist" add -A >/dev/null
git -C "$ROOT/dist" commit -qm "base: ceiling 3, in the script and in the schema" >/dev/null

# An UNRELATED commit, so a range exists in which the predicate did NOT move. Without it the
# byte-identical arm has no input and that assertion could not be made at all.
echo unrelated > "$ROOT/dist/README"
git -C "$ROOT/dist" add -A >/dev/null
git -C "$ROOT/dist" commit -qm "unrelated: predicate untouched" >/dev/null

# THE SCHEMA MOVES AND ITS SCRIPT DOES NOT. This is the v0.382.0 shape, and it is the commit a
# script-only differential is blind to. `write_schema_predicate` is not re-run, so the script
# stays byte-identical across this commit by construction rather than by luck.
write_schema 0
git -C "$ROOT/dist" add -A >/dev/null
git -C "$ROOT/dist" commit -qm "schema-only: ceiling 3 -> 0, script byte-identical" >/dev/null

write_predicate 0
git -C "$ROOT/dist" add -A >/dev/null
git -C "$ROOT/dist" commit -qm "theirs: ceiling 0 -- the reclassifying change" >/dev/null

# ---- the consumer's STORED artifacts --------------------------------------------------------
A="$ROOT/consumer/_bmad-output/planning-artifacts"

# CROSSES: value 2 is at or under the base ceiling of 3 and above theirs' ceiling of 0. Under
# base it is silent; under theirs it fails arm B. This is the reclassification.
printf 'value: 2\n' > "$A/crossing-adversarial-pass1.md"

# NEAR-MISS, IN THE SAME CORPUS: value 0 is under BOTH ceilings, so it never fails arm B and
# the row must not name it. This is what makes the assertion about WHICH series, not merely
# THAT one fired.
printf 'value: 0\n' > "$A/steady-adversarial-pass1.md"

printf '%s\n' "$ROOT"
