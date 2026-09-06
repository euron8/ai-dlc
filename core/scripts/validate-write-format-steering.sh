#!/usr/bin/env bash
# validate-write-format-steering.sh — every SHARED APPEND-ONLY artifact has a DECLARED
# entry format, and every declaration resolves to a file that still carries it.
#
# THE POPULATION IS JOINED, NEVER HAND-LISTED. It is every entry of
# schemas/pipeline-state-paths.json carrying `transient: false` — the DURABLE half, the
# artifacts a consumer commits and later sessions append to. Invariant I95
# (scripts/validate-enforcement-map.sh) already binds that schema to the shipped machinery in
# BOTH directions and fails closed: a path the machinery constructs that is declared nowhere
# fails the push, and a declared path nothing constructs fails it too. So the population this
# reader joins on is maintained by an arm that already exists, and this file adds no second
# copy of it. The join key and its value are themselves DATA, declared in
# schemas/write-format-steering.json, so this reader cannot disagree with the declaration
# about which artifacts are in scope.
#
# THE DUTY IS THAT A FORMAT EXISTS AND IS DECLARED. IT IS NOT A DUTY TO LOOK FOR ONE, AND
# THAT DISTINCTION IS THE WHOLE REASON THIS IS A PROGRAM. The remedy filed for this defect
# was a rule telling a write site to LOCATE a format before writing. It was built and
# refuted on measurement: a locate-duty is DISCHARGED BY LOOKING. Across the bucket where no
# format exists, a competently written locate-duty fires on nothing, reports SATISFIED at
# every member, and a prose-keyed receipt scores it as a shipped fix. No rewording separates
# a vacuous locate-duty from a real one, because the two are spelled identically. Existence
# and declaration is the only version of the duty with a subject a checker can address.
#
# WHAT WENT WRONG WITHOUT IT. Format steering — a `READ AND FOLLOW <format-file>` sentence
# beside a write — was attached at 3 of 24 shared append-only artifacts and absent at 21.
# Whether a write got it depended on which core author happened to add that sentence at that
# call site, not on any property of the write. Three of the unsteered artifacts are declared
# durable with a named producer and appear in the skill corpus ZERO times: not unsteered
# writes but unmentioned ones, inside an enforcer's reach and outside a prose rule's.
#
# THE STATED BOUND, AND IT IS A SCHEMA WIDENING RATHER THAN A MISSING JOIN. The four Rule
# 25(a) planning histories — prd-history.md, product-brief-history.md, architecture-history.md
# and carry-over-backlog-archive.md — are NOT in this population and this arm cannot see them.
# They nest under `planning-artifacts`, which pipeline-state-paths.json declares only at TOP
# LEVEL, so each is declared there 0 times (control: pipeline-snapshot-history.md, a top-level
# entry, is declared once). Widening the population to reach them is a change to
# pipeline-state-paths.json and to the grammar I95 derives it with — not something this reader
# may do on its own, because a population this file widened unilaterally would no longer be
# the one I95 binds, and the two would then disagree silently. Stated here so the gap is a
# known boundary rather than a clean result.
#
# TIERED, AND THE TIER IS A MEASUREMENT. The false-positive set was measured over the real
# population before this shipped, and it is not empty: of the 20 durable artifacts, only a
# minority have a format any program could resolve. An ERROR tier would fail the push on
# first contact for every consumer and for this repo, which is a check the operator turns off
# — and then nothing is enforced at all. So:
#   * UNDECLARED (a durable artifact with no entry in the steering schema) is reported and
#     COUNTED, and does not fail. It is the backlog this arm exists to make visible.
#   * A BROKEN DECLARATION — an entry naming a file that does not exist, or a file that no
#     longer carries the declared anchor, or a name that is not in the population at all —
#     FAILS. There is no false-positive path there: someone declared a format, and the
#     declaration no longer resolves. That is the state that reads as covered and is not.
# The ratchet is in the count: `--max-undeclared N` fails when the undeclared set GROWS past
# N, so the backlog can only shrink. Both directions of the join are checked, because a
# declaration for an artifact nothing writes is as wrong as an artifact nothing declares.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO ON THE FAILING TIER. Three narrowings, each of
# which removed a class that would otherwise have fired on correct data:
#   1. The failing tier does not fire on ABSENCE. The first draft failed on any durable
#      artifact with no declared format, which is 15 of 20 on the live tree and would have
#      wedged the push immediately. Absence is the reportable backlog; a broken pointer is
#      the defect.
#   2. The anchor is a substring of the DECLARED file, not a tree-wide grep. Keyed tree-wide,
#      every anchor resolves somewhere — the CHANGELOG alone mentions most of them — and the
#      arm would have passed on a declaration pointing at a file that had lost its format
#      entirely. Bind to the file that CARRIES the format, never to a tree that mentions it.
#   3. A durable artifact whose declared file is absent from THIS layout is a SKIP, not a
#      failure, when the whole schemas directory is absent — a consumer that has not yet
#      pulled the schema half has nothing to check and must not be wedged before it does.
#      A missing file WITH the directory present is a real broken pointer and fails.
#
# Usage:
#   validate-write-format-steering.sh                    # report + verdict
#   validate-write-format-steering.sh --report           # ...with the per-artifact table
#   validate-write-format-steering.sh --max-undeclared N # also fail if undeclared > N
#   validate-write-format-steering.sh --render           # print the derived header table
#   validate-write-format-steering.sh --check FILE       # byte-compare FILE's region
#   validate-write-format-steering.sh --self-probe       # both directions, then exit
#
# Exit codes:
#   0  every declaration resolves (undeclared artifacts reported, not fatal)
#   1  a declaration is broken, the ratchet was breached, or a schema is unreadable
#   2  usage error, or the project root could not be resolved
#
# Compatible with bash 3.2 and Python 3 stdlib.

set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. A hop count answers differently from the
# repo root, from a subdirectory and from a fixture sandbox that copied the script,
# and the sandbox answer is the silent one: this arm would resolve a schemas
# directory that is not there, derive an empty population, and report every tree
# clean. Inline on purpose, in every script that needs it: a shared lib cannot fix
# this, because locating the lib is the same unsolved problem. Duplication is
# correct here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

MODE="validate"; REPORT=0; MAX_UNDECLARED=""; CHECK_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --report)         REPORT=1; shift ;;
    --render)         MODE="render"; shift ;;
    --check)          MODE="check"; CHECK_FILE="${2:-}"; shift 2 ;;
    --self-probe)     MODE="self-probe"; shift ;;
    --max-undeclared) MAX_UNDECLARED="${2:-}"; shift 2 ;;
    -h|--help)        sed -n '1,80p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "validate-write-format-steering: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [ -n "$MAX_UNDECLARED" ]; then
  case "$MAX_UNDECLARED" in
    ''|*[!0-9]*)
      echo "validate-write-format-steering: --max-undeclared needs a non-negative integer (got '${MAX_UNDECLARED}')" >&2
      exit 2 ;;
  esac
fi

if [ "$MODE" = "check" ] && [ -z "$CHECK_FILE" ]; then
  echo "validate-write-format-steering: --check needs a file" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || {
  echo "validate-write-format-steering: FAIL — python3 required" >&2; exit 1; }

# Resolve BOTH schemas in either layout. Script-relative first — that is the package this
# copy shipped in — then the resolved root, distribution before consumer. No built-in copy
# and no guess: a reader that falls back to a stale built-in reports about a declaration
# nobody can see.
resolve_schema() {
  _n="$1"
  for _c in "$AI_DLC_SELF_DIR/../schemas/$_n" \
            "$AI_DLC_ROOT/core/schemas/$_n" \
            "$AI_DLC_ROOT/.claude/schemas/$_n"; do
    [ -f "$_c" ] && { printf '%s\n' "$_c"; return 0; }
  done
  return 1
}

STEERING="$(resolve_schema write-format-steering.json || true)"
POP_DEFAULT="$(resolve_schema pipeline-state-paths.json || true)"

if [ -z "$STEERING" ]; then
  echo "validate-write-format-steering: FAIL — cannot find schemas/write-format-steering.json." >&2
  echo "  It is the declaration of which shared append-only artifacts have a defined entry" >&2
  echo "  format and where that format lives. This script has no built-in copy and will not" >&2
  echo "  guess: without the file there is no declaration to check, and a reader that said" >&2
  echo "  PASS here would report exactly what a fully declared tree reports." >&2
  exit 1
fi

# --- the reader ---------------------------------------------------------------
# One python3 for the corpus AND both probe directions. An arm's fork count is a change to
# the suite's wall clock, so the reader takes (tag, steering, population) triples and tags
# every line it prints; the live tree and the two seeded trees are one process, not three.
run_reader() {
  python3 - "$@" <<'PY'
import io, json, os, sys

def load(p):
    with io.open(p, encoding='utf-8') as f:
        return json.load(f)

args = sys.argv[1:]
for i in range(0, len(args), 4):
    tag, steer_p, pop_p, root = args[i], args[i+1], args[i+2], args[i+3]
    try:
        steer = load(steer_p)
    except Exception as exc:
        print('%s\tUNPARSED\t%s\t%s' % (tag, steer_p, exc))
        continue

    join = steer.get('join') or {}
    key = join.get('population_key')
    val = join.get('population_value')
    if not key or not isinstance(val, bool):
        print('%s\tJOINBROKEN\t%s\tthe steering schema declares no usable join '
              '(population_key=%r population_value=%r)' % (tag, steer_p, key, val))
        continue

    try:
        pop_doc = load(pop_p)
    except Exception as exc:
        print('%s\tUNPARSED\t%s\t%s' % (tag, pop_p, exc))
        continue

    population = []
    for e in (pop_doc.get('paths') or []):
        nm = (e.get('name') or '').strip()
        if nm and e.get(key) is val:
            population.append(nm)
    population = sorted(set(population))

    # AN EMPTY POPULATION IS A DISARMED ARM, NOT A CLEAN ONE. Every name would be
    # "declared for nothing" and every absence invisible; the set-compare below would
    # report perfect agreement over nothing at all.
    if not population:
        print('%s\tDISARMED\t%s\tthe join %s=%r selected ZERO entries'
              % (tag, pop_p, key, val))
        continue

    declared = {}
    for e in (steer.get('formats') or []):
        nm = (e.get('name') or '').strip()
        if not nm:
            print('%s\tFIELD\t<unnamed>\tan entry declares no name' % tag)
            continue
        if nm in declared:
            print('%s\tFIELD\t%s\tdeclared twice' % (tag, nm))
        declared[nm] = e

    for nm in sorted(declared):
        e = declared[nm]
        where = (e.get('declared_in') or '').strip()
        anchor = (e.get('anchor') or '').strip()
        if not where or not anchor:
            print('%s\tFIELD\t%s\tdeclares no %s'
                  % (tag, nm, 'declared_in' if not where else 'anchor'))
            continue
        # BOTH LAYOUTS. install.sh splits what shares a parent here:
        # core/scripts/<x> -> scripts/ai-dlc/<x> while core/schemas/ -> .claude/schemas/.
        # A declaration written as a distribution path resolves nowhere on a consumer, so
        # the consumer spelling is tried too before anything is called missing.
        cands = [os.path.join(root, where)]
        if where.startswith('core/schemas/'):
            cands.append(os.path.join(root, '.claude/schemas/', os.path.basename(where)))
        if where.startswith('core/scripts/'):
            cands.append(os.path.join(root, 'scripts/ai-dlc/', os.path.basename(where)))
        if where.startswith('core/skills/'):
            cands.append(os.path.join(root, '.claude/skills/',
                                      where[len('core/skills/'):]))
        hit = next((c for c in cands if os.path.isfile(c)), None)
        if hit is None:
            print('%s\tMISSING\t%s\t%s (looked in %d layout(s))'
                  % (tag, nm, where, len(cands)))
            continue
        try:
            body = io.open(hit, encoding='utf-8', errors='replace').read()
        except Exception as exc:
            print('%s\tUNREADABLE\t%s\t%s: %s' % (tag, nm, where, exc))
            continue
        if anchor not in body:
            print('%s\tSTALE\t%s\t%s no longer contains %r'
                  % (tag, nm, os.path.relpath(hit, root), anchor))
            continue
        print('%s\tOK\t%s\t%s :: %s' % (tag, nm, where, e.get('kind', '?')))

    for nm in sorted(set(declared) - set(population)):
        print('%s\tGHOST\t%s\tdeclared here but not in the joined population' % (tag, nm))
    for nm in sorted(set(population) - set(declared)):
        print('%s\tUNDECLARED\t%s\t-' % (tag, nm))
    print('%s\tPOP\t%d\t%d' % (tag, len(population), len(declared)))
PY
}

# --- SELF-PROBE FIRST, BEFORE THE CORPUS -------------------------------------
# An arm reporting zero findings without first proving it can produce one has established
# that it ran, not that the corpus is clean. Both directions, on mktemp trees rather than the
# real corpus: the OFFENDER declares a format in a file that does not carry the anchor, and
# the NEAR-MISS declares one in a file that does. An arm that flagged the near-miss would
# flag every correct declaration in the tree, and its finding set would be the whole
# population — which is a scan that discriminates nothing and reads exactly like one that
# discriminates perfectly.
PROBE_DIR=""; PROBE_POS=""; PROBE_NEG=""
build_probe() {
  PROBE_DIR="$(mktemp -d 2>/dev/null)" || return 1
  [ -n "$PROBE_DIR" ] || return 1
  for side in pos neg; do
    mkdir -p "$PROBE_DIR/$side/core/schemas" || return 1
    cat > "$PROBE_DIR/$side/pop.json" <<'JSON'
{ "paths": [
  { "name": "probe-artifact.md", "transient": false },
  { "name": "probe-transient",   "transient": true  }
] }
JSON
  done
  # OFFENDER: the declared file exists and has LOST the anchor.
  printf 'this file no longer carries the format\n' \
    > "$PROBE_DIR/pos/core/schemas/probe-format.json"
  cat > "$PROBE_DIR/pos/steer.json" <<'JSON'
{ "join": { "population_key": "transient", "population_value": false },
  "formats": [ { "name": "probe-artifact.md",
                 "declared_in": "core/schemas/probe-format.json",
                 "anchor": "PROBE-FORMAT-ANCHOR", "kind": "schema" } ] }
JSON
  # NEAR-MISS: same shape, same population, and the anchor IS present.
  printf 'PROBE-FORMAT-ANCHOR is right here\n' \
    > "$PROBE_DIR/neg/core/schemas/probe-format.json"
  cat > "$PROBE_DIR/neg/steer.json" <<'JSON'
{ "join": { "population_key": "transient", "population_value": false },
  "formats": [ { "name": "probe-artifact.md",
                 "declared_in": "core/schemas/probe-format.json",
                 "anchor": "PROBE-FORMAT-ANCHOR", "kind": "schema" } ] }
JSON
  PROBE_POS="$PROBE_DIR/pos"; PROBE_NEG="$PROBE_DIR/neg"
  return 0
}

PROBE_OUT=""; PROBE_BUILT=0
if build_probe; then
  PROBE_BUILT=1
  PROBE_OUT="$(run_reader \
      pos "$PROBE_POS/steer.json" "$PROBE_POS/pop.json" "$PROBE_POS" \
      neg "$PROBE_NEG/steer.json" "$PROBE_NEG/pop.json" "$PROBE_NEG" 2>&1)"
fi
[ -n "$PROBE_DIR" ] && rm -rf "$PROBE_DIR"

PROBE_FAIL=0
if [ "$PROBE_BUILT" -ne 1 ]; then
  echo "validate-write-format-steering: FAIL — could not build the probe trees, so NEITHER" >&2
  echo "  direction of the self-probe ran. A verdict on the corpus below would establish" >&2
  echo "  only that the reader executed." >&2
  PROBE_FAIL=1
else
  pos_fired=0; neg_fired=0
  case "$PROBE_OUT" in *"pos	STALE	probe-artifact.md"*) pos_fired=1 ;; esac
  case "$PROBE_OUT" in *"neg	STALE	probe-artifact.md"*) neg_fired=1 ;; esac
  if [ "$pos_fired" -ne 1 ]; then
    echo "validate-write-format-steering: FAIL — the POSITIVE probe was NOT reported. A seeded" >&2
    echo "  declaration pointing at a file that has lost its anchor went unseen by the same" >&2
    echo "  reader the corpus arm runs, so a clean corpus result means nothing. Fails closed." >&2
    PROBE_FAIL=1
  fi
  if [ "$neg_fired" -ne 0 ]; then
    echo "validate-write-format-steering: FAIL — the NEGATIVE probe WAS reported. A declaration" >&2
    echo "  whose file DOES carry its anchor was flagged as stale, so this arm flags every" >&2
    echo "  correct declaration in the tree and discriminates nothing." >&2
    PROBE_FAIL=1
  fi
fi

if [ "$MODE" = "self-probe" ]; then
  [ "$PROBE_FAIL" -eq 0 ] && echo "validate-write-format-steering: self-probe PASS — the offender was reported and the near-miss was not."
  exit "$PROBE_FAIL"
fi
[ "$PROBE_FAIL" -eq 0 ] || exit 1

# --- the corpus ---------------------------------------------------------------
# The population schema is resolved from the STEERING schema's own `join.population_schema`,
# so the declaration decides which file is joined and this reader cannot pick a different one.
POP_NAME="$(python3 -c 'import json,sys; print((json.load(open(sys.argv[1])).get("join") or {}).get("population_schema") or "")' "$STEERING" 2>/dev/null || true)"
POP=""
[ -n "$POP_NAME" ] && POP="$(resolve_schema "$POP_NAME" || true)"
[ -n "$POP" ] || POP="$POP_DEFAULT"

if [ -z "$POP" ]; then
  # A CONSUMER THAT HAS NOT PULLED THE POPULATION SCHEMA IS A SKIP, NOT A FAILURE. It has
  # nothing to check, and wedging its push before it can pull is the shape of check an
  # operator turns off. It says which question went unasked, in wording no passing run emits.
  echo "validate-write-format-steering: SKIP — the population schema (${POP_NAME:-pipeline-state-paths.json})"
  echo "  is not in this tree, so NO artifact was judged. This is not a pass: the join that"
  echo "  selects the shared append-only artifacts had no left-hand side."
  exit 0
fi

OUT="$(run_reader live "$STEERING" "$POP" "$AI_DLC_ROOT" 2>&1)"

if [ -z "$OUT" ]; then
  echo "validate-write-format-steering: FAIL — the reader produced NO output at all, not even" >&2
  echo "  its population count. It did not run, so neither the corpus verdict nor the probe" >&2
  echo "  that proves the corpus verdict means anything. Fails closed." >&2
  exit 1
fi

FAILURES=0; UNDECLARED=0; DECLARED_OK=0; POP_N=0; DECL_N=0
while IFS='	' read -r tag kind what where; do
  [ "$tag" = "live" ] || continue
  case "$kind" in
    OK)         DECLARED_OK=$((DECLARED_OK + 1))
                [ "$REPORT" -eq 1 ] && printf '  declared   %-34s %s\n' "$what" "$where" ;;
    UNDECLARED) UNDECLARED=$((UNDECLARED + 1))
                [ "$REPORT" -eq 1 ] && printf '  UNDECLARED %-34s no entry format is declared anywhere\n' "$what" ;;
    POP)        POP_N="$what"; DECL_N="$where" ;;
    MISSING)
      echo "validate-write-format-steering: FAIL — '$what' declares its entry format in ${where}," >&2
      echo "  and no file is there in any layout. A declaration that resolves to nothing reads as" >&2
      echo "  covered and is not: every reader sent to that path finds no format and writes" >&2
      echo "  whatever it was going to write anyway." >&2
      FAILURES=$((FAILURES + 1)) ;;
    STALE)
      echo "validate-write-format-steering: FAIL — '$what' declares its entry format in ${where}." >&2
      echo "  The file is there and the anchor is gone, so the format moved or was deleted while" >&2
      echo "  the declaration stayed behind. This is the state a whole-file grep cannot see." >&2
      FAILURES=$((FAILURES + 1)) ;;
    GHOST)
      echo "validate-write-format-steering: FAIL — '$what' has a declared format and is NOT in the" >&2
      echo "  joined population. Either it was renamed or removed from the population schema and" >&2
      echo "  this declaration was left behind, or the join key moved. A declaration about an" >&2
      echo "  artifact nothing writes is as wrong as an artifact nothing declares." >&2
      FAILURES=$((FAILURES + 1)) ;;
    FIELD|UNPARSED|UNREADABLE|JOINBROKEN)
      echo "validate-write-format-steering: FAIL — ${kind}: ${what} — ${where}" >&2
      FAILURES=$((FAILURES + 1)) ;;
    DISARMED)
      echo "validate-write-format-steering: FAIL — ${what}: ${where}. An empty population agrees" >&2
      echo "  with every requirement, so this fails closed rather than reporting an agreement it" >&2
      echo "  never computed." >&2
      FAILURES=$((FAILURES + 1)) ;;
  esac
done <<EOF
$OUT
EOF

# THE RATCHET. The undeclared set is the backlog and does not fail on its own — it is 15 of
# 20 on the tree this shipped against, and failing there would wedge first contact for every
# consumer. What must not happen is GROWTH: a new durable artifact added with no format is
# the same defect one instance larger, and it is invisible without a bound.
if [ -n "$MAX_UNDECLARED" ] && [ "$UNDECLARED" -gt "$MAX_UNDECLARED" ]; then
  echo "validate-write-format-steering: FAIL — ${UNDECLARED} shared append-only artifact(s) have" >&2
  echo "  no declared entry format, above the ceiling of ${MAX_UNDECLARED}. The ceiling only ever" >&2
  echo "  moves DOWN: declare the new artifact's format in schemas/write-format-steering.json," >&2
  echo "  or lower the ceiling in the same change that removes one." >&2
  FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "validate-write-format-steering: FAIL — ${FAILURES} finding(s) over ${POP_N} shared append-only artifact(s)." >&2
  exit 1
fi

# Say what was judged, with its counts. A pass that names no population is indistinguishable
# from a pass that compared nothing, and the DISARMED arm above is the only thing standing
# between the two.
echo "validate-write-format-steering: PASS — ${DECLARED_OK} of ${POP_N} shared append-only artifact(s)"
echo "  carry a declared entry format that resolves; ${UNDECLARED} carry none (reported, not fatal)."
echo "  The four Rule 25(a) planning histories are OUTSIDE this population — they nest under"
echo "  'planning-artifacts', which the population schema declares only at top level. Reaching"
echo "  them is a widening of that schema, not a gap in this join."
exit 0
