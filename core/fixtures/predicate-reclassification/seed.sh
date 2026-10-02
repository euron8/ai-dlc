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
  case "\$v" in *[!0-9]*) echo "ERROR: \$f carries an unparseable value"; rc=2; continue ;; esac
  if [ "\$v" -gt "\$CEILING" ]; then
    echo "FAIL (B -- CONSISTENCY): \$f declares \$v above ceiling \$CEILING"
    rc=1
  fi
done
# A PASS LINE, like validate-adversarial-convergence.sh's: printed only when nothing failed or errored.
[ "\$rc" -eq 0 ] && echo "PASS: every value is within ceiling \$CEILING"
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

# THE THIRD SHAPE, AND THE ONE THE REAL SCHEMA-BACKED VALIDATORS HAVE. It finds its schema under
# its PROJECT ROOT, resolved the way validate-provenance-block.sh resolves it (AI_DLC_PROJECT_ROOT,
# a walk up from itself for a marker, CLAUDE_PROJECT_DIR, a walk up from the cwd), and it reads a
# known-skills extension the same way (AI_DLC_KNOWN_SKILLS_EXT set -> verbatim, else searched under
# the root). Run from a probe root with no marker, with the cwd at the consumer, it resolves the
# consumer's INSTALLED schema on both sides unless the caller pins the root -- which is the defect
# the script-relative toy above cannot express. Shares toy-schema.yaml, so the schema-only commit
# moves it too, and is byte-identical across every ref.
write_root_predicate() {
  cat > "$ROOT/dist/core/scripts/toy-root-predicate.sh" <<'PRED'
#!/usr/bin/env bash
# toy root-resolving predicate -- the ceiling lives under the PROJECT ROOT, not beside this file.
set -uo pipefail
resolve_root() {
  d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
SELF="$(cd "$(dirname "$0")" && pwd)"
PROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$PROOT" ] || PROOT="$(resolve_root "$SELF" || true)"
[ -n "$PROOT" ] || PROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$PROOT" ] || PROOT="$(resolve_root "$(pwd)" || true)"
CEILING=""
for cand in "$PROOT/core/schemas/toy-schema.yaml" "$PROOT/.claude/schemas/toy-schema.yaml"; do
  [ -f "$cand" ] && { CEILING="$(sed -n 's/^ceiling:[[:space:]]*//p' "$cand" | head -1)"; break; }
done
[ -n "$CEILING" ] || { echo "FAIL (S -- SCHEMA): no toy-schema.yaml under root $PROOT"; exit 2; }
if [ -n "${AI_DLC_KNOWN_SKILLS_EXT+x}" ]; then
  EXT="$AI_DLC_KNOWN_SKILLS_EXT"
else
  EXT=""
  [ -f "$PROOT/.claude/skills/ai-dlc/extensions/known-skills.json" ] && EXT="$PROOT/.claude/skills/ai-dlc/extensions/known-skills.json"
fi
SERIES=""
while [ $# -gt 0 ]; do
  case "$1" in --series) SERIES="$2"; shift 2 ;; *) shift ;; esac
done
rc=0
for f in "$SERIES"*; do
  [ -f "$f" ] || continue
  v="$(sed -n 's/^value:[[:space:]]*//p' "$f" | head -1)"
  [ -n "$v" ] || continue
  k="$(sed -n 's/^skill:[[:space:]]*//p' "$f" | head -1)"
  if [ -n "$k" ] && [ "$k" != core-skill ]; then
    if [ -z "$EXT" ] || [ ! -f "$EXT" ] || ! grep -qF "\"$k\"" "$EXT"; then
      echo "FAIL (U -- UNKNOWN): $f names skill $k, which is not known"
      rc=1
    fi
  fi
  if [ "$v" -gt "$CEILING" ]; then
    echo "FAIL (B -- CONSISTENCY): $f declares $v above ceiling $CEILING"
    rc=1
  fi
done
exit $rc
PRED
  chmod +x "$ROOT/dist/core/scripts/toy-root-predicate.sh"
}

# ---- the distribution, two refs ------------------------------------------------------------
git -C "$ROOT/dist" init -q 2>/dev/null
git -C "$ROOT/dist" config user.email fixture@example.invalid
git -C "$ROOT/dist" config user.name fixture

write_predicate 3
write_schema_predicate
write_root_predicate
write_schema 3
# A READ-SET MEMBER WITH A NON-ASCII NAME. Listed under the default core.quotePath it arrives as
# `"core/schemas/caf\303\251.yaml"`, names nothing, and its side reads as unmaterializable.
printf 'note: a non-ascii read-set member\n' > "$ROOT/dist/core/schemas/café.yaml"
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

# ABOVE BOTH CEILINGS: fails arm B on both sides, so every differential over this corpus yields
# at least one token even when nothing moves -- the series that makes a null STABLE rather than
# UNDECIDABLE, so a root-resolution defect reads as the false clean it is.
printf 'value: 9\n' > "$A/always-adversarial-pass1.md"

# UNPARSEABLE: the predicate prints neither a FAIL token nor its PASS line on either side. With a
# `pass:` grammar this is the one UNCLASSIFIED series, and the steady one the one PASSED; without
# it the two cannot be told apart, which is what `unclassified=n/a` says.
printf 'value: x\n' > "$A/garbled-adversarial-pass1.md"

# CROSSES, AND NAMES A SKILL ONLY THE CONSUMER'S EXTENSION KNOWS. Its delta must be [] -> [B]; if
# the extension is not reachable from the side it is [U] -> [B,U], on both sides.
printf 'value: 2\nskill: ext-skill\n' > "$A/ext-adversarial-pass1.md"

# THE CONSUMER'S INSTALLED COPIES, at the BASE ceiling. A side that resolves its root to the
# consumer reads ceiling 3 whatever ref it was materialized from.
mkdir -p "$ROOT/consumer/.claude/schemas" "$ROOT/consumer/.claude/skills/ai-dlc/extensions"
printf 'ceiling: 3\n' > "$ROOT/consumer/.claude/schemas/toy-schema.yaml"
printf '["ext-skill"]\n' > "$ROOT/consumer/.claude/skills/ai-dlc/extensions/known-skills.json"

# A STORED SUBJECT OUTSIDE _bmad-output/, where the suppression-lifetime site's pending.md lives.
mkdir -p "$ROOT/consumer/docs/escalations"
printf 'value: 2\n' > "$ROOT/consumer/docs/escalations/pending-pass1.md"

printf '%s\n' "$ROOT"
