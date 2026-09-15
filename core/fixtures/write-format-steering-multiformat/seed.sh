#!/usr/bin/env bash
# write-format-steering-multiformat/seed.sh — resolve the REAL validate-write-format-steering.sh,
# the REAL write-format-steering.json, the REAL population schema and the REAL file the new
# declaration points at, then build the SEVEN independent trees run.sh scores. Prints the WORK
# dir. Idempotent.
#
# EVERY WORLD IS ITS OWN TREE. The five mutants differ by ONE property each, and a shared tree
# would let one arm's seed satisfy another arm — the failure `.claude/rules/fixture-mutants.md`
# names as "two guards that cover each other", whose symptom is ZERO failures rather than two.
# The dist worlds differ only in the bytes of write-format-steering.json; the consumer worlds
# differ only in which directories exist under the skills component.
#
# THE SEED IS BUILT FROM WHAT THE PRODUCER EMITS, NEVER FROM WHAT THE READER ACCEPTS: every
# steering document below is a python3 TRANSFORM of the shipped schema, not a hand-written
# stanza, so a world cannot pass by encoding this fixture's idea of the grammar.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — BOTH three dirs below root.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: cannot resolve the project root" >&2; exit 2; }

if   [ -f "$ROOT/core/scripts/validate-write-format-steering.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-write-format-steering.sh"
  SCHEMA_DIR="$ROOT/core/schemas"
  LIB_SRC="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
elif [ -f "$ROOT/scripts/ai-dlc/validate-write-format-steering.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-write-format-steering.sh"
  SCHEMA_DIR="$ROOT/.claude/schemas"
  LIB_SRC="$ROOT/.claude/skills/ai-dlc-update/reconcile/lib.sh"
else
  # A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. The validator arrives in one pull and this
  # fixture may arrive in the same one or an earlier one; a consumer between pulls has neither.
  # Exit 3 is this fixture's SKIP channel, and run.sh reports it as SKIPPED rather than PASS —
  # a fixture whose subject is absent must not print a verdict that reads as "I checked".
  echo "SUBJECT ABSENT" >&2
  exit 3
fi

STEERING="$SCHEMA_DIR/write-format-steering.json"
[ -f "$STEERING" ] || { echo "SUBJECT ABSENT" >&2; exit 3; }
[ -f "$LIB_SRC" ]  || { echo "SUBJECT ABSENT" >&2; exit 3; }

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 required" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wfs-multiformat.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd)"

# --- the DECLARATION under test, read OUT of the shipped schema, never restated ---------------
# The fixture must not carry its own copy of the declared_in path or the anchor: a hand-typed
# literal here is a second spelling that drifts from the schema silently, and every arm below
# would then assert about a declaration nobody ships. Both values are DERIVED, and the derivation
# refuses if it selects anything other than exactly one entry.
DERIVED="$(python3 - "$STEERING" <<'PY'
import io, json, sys
d = json.load(io.open(sys.argv[1], encoding='utf-8'))
rows = [e for e in (d.get('formats') or []) if (e.get('kind') or '') == 'code']
if len(rows) != 1:
    sys.stderr.write('expected exactly one kind=code entry, found %d\n' % len(rows))
    sys.exit(1)
e = rows[0]
for k in ('name', 'declared_in', 'anchor'):
    if not (e.get(k) or '').strip():
        sys.stderr.write('the kind=code entry declares no %s\n' % k)
        sys.exit(1)
print(e['name']); print(e['declared_in']); print(e['anchor'])
PY
)" || { echo "SUBJECT ABSENT" >&2; exit 3; }

CODE_NAME="$(printf '%s\n' "$DERIVED"   | sed -n '1p')"
CODE_DECL="$(printf '%s\n' "$DERIVED"   | sed -n '2p')"
CODE_ANCHOR="$(printf '%s\n' "$DERIVED" | sed -n '3p')"
[ -n "$CODE_NAME" ] && [ -n "$CODE_DECL" ] && [ -n "$CODE_ANCHOR" ] \
  || { echo "FIXTURE ERROR: the kind=code declaration did not resolve to three fields" >&2; exit 2; }

# The declared file must exist and must CARRY the anchor, or every mutant below is scored against
# a base that was already broken and a kill means nothing.
case "$CODE_DECL" in
  core/skills/*) REL="${CODE_DECL#core/skills/}" ;;
  *)             REL="" ;;
esac
[ -n "$REL" ] || { echo "FIXTURE ERROR: the kind=code declaration does not point into core/skills/ ($CODE_DECL)" >&2; exit 2; }
DECL_SRC=""
for c in "$ROOT/$CODE_DECL" "$ROOT/.claude/skills/$REL"; do
  [ -f "$c" ] && { DECL_SRC="$c"; break; }
done
[ -n "$DECL_SRC" ] || { echo "SUBJECT ABSENT" >&2; exit 3; }
grep -qF "$CODE_ANCHOR" "$DECL_SRC" \
  || { echo "FIXTURE ERROR: the declared file does not carry its own anchor — the base is broken" >&2; exit 2; }

# --- MUTANT 1's and MUTANT 2's anchors are DERIVED FROM THE FILE, not invented ------------------
# M1 needs a string that IS in the file and is NOT the boundary function: the first `<name>() {`
# definition that is not ledger_entry_shape. M2 needs a string from the file's own HEADER COMMENT,
# which is the shape a whole-file grep is satisfied by. Deriving both means a refactor that moves
# them re-derives rather than silently leaving the mutant matching nothing.
M1_ANCHOR="$(awk -v skip="$CODE_ANCHOR" '
  /^[a-z_]+\(\) \{/ { line=$0; sub(/ *$/, "", line); if (index(skip, line) == 0) { print line; exit } }
' "$DECL_SRC")"
M2_ANCHOR="$(awk 'NR<=3 && /^# / { s=$0; sub(/^# /, "", s); n=split(s, p, " "); if (p[1] ~ /\.sh$/ || p[1] ~ /\//) { print p[1]; exit } }' "$DECL_SRC")"
[ -n "$M1_ANCHOR" ] || { echo "FIXTURE ERROR: could not derive a non-boundary function anchor from $DECL_SRC" >&2; exit 2; }
[ -n "$M2_ANCHOR" ] || { echo "FIXTURE ERROR: could not derive a header-comment anchor from $DECL_SRC" >&2; exit 2; }
# Both must be PRESENT in the file (that is the whole point — the validator will pass on them) and
# must DIFFER from the real anchor (or the mutant is a no-op wearing a mutant's name).
grep -qF "$M1_ANCHOR" "$DECL_SRC" || { echo "FIXTURE ERROR: derived M1 anchor is not in the file" >&2; exit 2; }
grep -qF "$M2_ANCHOR" "$DECL_SRC" || { echo "FIXTURE ERROR: derived M2 anchor is not in the file" >&2; exit 2; }
[ "$M1_ANCHOR" != "$CODE_ANCHOR" ] || { echo "FIXTURE ERROR: derived M1 anchor equals the real anchor" >&2; exit 2; }
[ "$M2_ANCHOR" != "$CODE_ANCHOR" ] || { echo "FIXTURE ERROR: derived M2 anchor equals the real anchor" >&2; exit 2; }

# --- steering-document builders ----------------------------------------------------------------
# Each writes ONE transformed copy of the shipped schema. `--anchor` retargets the kind=code
# entry; `--dup` appends a byte-identical copy of it.
steer_variant() {   # <out-path> <mode> [value]
  python3 - "$STEERING" "$1" "$2" "${3:-}" <<'PY'
import copy, io, json, sys
src, out, mode, val = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
d = json.load(io.open(src, encoding='utf-8'))
rows = [e for e in d['formats'] if (e.get('kind') or '') == 'code']
if len(rows) != 1:
    sys.stderr.write('not exactly one kind=code entry\n'); sys.exit(1)
e = rows[0]
if mode == 'anchor':
    e['anchor'] = val
elif mode == 'dup':
    d['formats'].append(copy.deepcopy(e))
elif mode == 'base':
    pass
else:
    sys.stderr.write('unknown mode %s\n' % mode); sys.exit(1)
io.open(out, 'w', encoding='utf-8').write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
PY
}

# --- DIST-layout world builder -------------------------------------------------------------
# The whole schemas directory is copied, not just the steering file: the validator resolves its
# POPULATION schema beside itself, and a partial tree would make every world report an empty
# population — two inert runs comparing equal, which reads exactly like agreement.
build_dist() {   # <world-name> <steering-json-path>
  local w; w="$WORK/$1"
  local steer; steer="$2"
  mkdir -p "$w/core/scripts" "$w/core/schemas" "$w/core/skills/$(dirname "$REL")" || return 1
  cp "$VALIDATOR" "$w/core/scripts/validate-write-format-steering.sh" || return 1
  cp "$SCHEMA_DIR"/*.json "$w/core/schemas/" || return 1
  cp "$DECL_SRC" "$w/core/skills/$REL" || return 1
  cp "$steer" "$w/core/schemas/write-format-steering.json" || return 1
  return 0
}

# --- CONSUMER-layout world builder ----------------------------------------------------------
# install.sh splits what shares a parent upstream: core/scripts/<x> -> scripts/ai-dlc/<x>,
# core/schemas/ -> .claude/schemas/, core/skills/<x> -> .claude/skills/<x>. A world that only
# ever existed in the distribution layout cannot express the SKIP case at all, because the
# distribution always has core/skills/ present.
build_consumer() {   # <world-name>
  local w; w="$WORK/$1"
  mkdir -p "$w/scripts/ai-dlc" "$w/.claude/schemas" || return 1
  cp "$VALIDATOR" "$w/scripts/ai-dlc/validate-write-format-steering.sh" || return 1
  cp "$SCHEMA_DIR"/*.json "$w/.claude/schemas/" || return 1
  return 0
}

# ============================== the seven worlds ==============================
# W_BASE — the shipped declaration, untouched. Every arm's control.
steer_variant "$WORK/base.json"    base          || exit 2
build_dist    base "$WORK/base.json"             || exit 2

# W_M1 — the anchor is a REAL substring of the declared file and the WRONG function.
steer_variant "$WORK/m1.json"      anchor "$M1_ANCHOR" || exit 2
cmp -s "$WORK/base.json" "$WORK/m1.json" && { echo "FIXTURE ERROR: mutant 1 DID NOT APPLY" >&2; exit 2; }
build_dist    m1 "$WORK/m1.json"                 || exit 2

# W_M2 — the anchor is a substring of the declared file's own HEADER COMMENT.
steer_variant "$WORK/m2.json"      anchor "$M2_ANCHOR" || exit 2
cmp -s "$WORK/base.json" "$WORK/m2.json" && { echo "FIXTURE ERROR: mutant 2 DID NOT APPLY" >&2; exit 2; }
cmp -s "$WORK/m1.json"   "$WORK/m2.json" && { echo "FIXTURE ERROR: mutants 1 and 2 are the same tree" >&2; exit 2; }
build_dist    m2 "$WORK/m2.json"                 || exit 2

# W_M3 — a TRUE duplicate: same name AND same declared_in, twice.
steer_variant "$WORK/m3.json"      dup           || exit 2
cmp -s "$WORK/base.json" "$WORK/m3.json" && { echo "FIXTURE ERROR: mutant 3 DID NOT APPLY" >&2; exit 2; }
build_dist    m3 "$WORK/m3.json"                 || exit 2

# W_M4 — consumer layout, the skills component ENTIRELY absent. The SKIP case.
build_consumer m4                                || exit 2

# W_M5 — consumer layout, the skills component PRESENT and the declared file absent. MISSING.
# One property apart from W_M4, and that property is the one the SKIP narrowing keys on.
build_consumer m5                                || exit 2
mkdir -p "$WORK/m5/.claude/skills/$(dirname "$REL")" || exit 2
: > "$WORK/m5/.claude/skills/$(dirname "$REL")/other.sh" || exit 2

# W_M6 — consumer layout, the skills component present AND carrying the declared file.
# The near-miss for W_M5: same layout, same component present, and NOTHING is reported. Without
# it, an arm asserting "M5 fails" cannot tell a correctly-keyed MISSING from one that fires on
# every consumer tree that has the component at all.
build_consumer m6                                || exit 2
mkdir -p "$WORK/m6/.claude/skills/$(dirname "$REL")" || exit 2
cp "$DECL_SRC" "$WORK/m6/.claude/skills/$REL"    || exit 2

cat > "$WORK/env.sh" <<ENV
WORK="$WORK"
VALIDATOR="$VALIDATOR"
STEERING="$STEERING"
DECL_SRC="$DECL_SRC"
REL="$REL"
CODE_NAME="$CODE_NAME"
CODE_DECL="$CODE_DECL"
CODE_ANCHOR="$CODE_ANCHOR"
M1_ANCHOR="$M1_ANCHOR"
M2_ANCHOR="$M2_ANCHOR"
W_BASE="$WORK/base"
W_M1="$WORK/m1"
W_M2="$WORK/m2"
W_M3="$WORK/m3"
W_M4="$WORK/m4"
W_M5="$WORK/m5"
W_M6="$WORK/m6"
ENV

printf '%s\n' "$WORK"
