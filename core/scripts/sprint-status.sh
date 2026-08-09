#!/usr/bin/env bash
# sprint-status.sh — the PRODUCER + READER of the sprint-status envelope.
#
# THE SCHEMA IS NOT IN THIS FILE. It is in schemas/sprint-status.json, which this script LOADS:
# the key grammar, the field list, and the header text all come from there.
#
# Why this exists (v0.75.0): sprint-status.yaml was the only major pipeline artifact with no
# mechanical producer in core/ — no creator, no template, no schema, no rotation. `sprint_id`, the
# pipeline's sprint identity, was derived by ~25 lines of PROSE in route.md Step 6 that the model
# executed by hand ("mechanically derived" there meant "by rule", not "by code"). Getting it wrong
# stamps every draft of the sprint one number off, permanently, in the filename.
#
# Usage:
#   sprint-status.sh --render                  # print the canonical BEGIN/END GENERATED header
#   sprint-status.sh --check <file>            # fail if <file>'s envelope is missing/malformed
#   sprint-status.sh sprint-id [--root <dir>]  # print the resolved sprint_id (route.md Step 6)
#   sprint-status.sh roll --sprint <N> [--name <s>] [--variant <s>] [--intensity <s>] [--root <dir>]
#                                              # atomic freeze-of-closed-sprint + roll-forward
#   sprint-status.sh check-stories [--sprint <N>] [--root <dir>]
#                                              # gate-validation.md Check 5: every story entry's
#                                              # `status:` equals the status in the story file it
#                                              # names, in every canonical copy
#   sprint-status.sh derive-stories [--check] [--sprint <N>] [--root <dir>]
#                                              # the WRITE half of that same join: rewrite each
#                                              # derivable field's value from the story file
#
# DERIVE-STORIES, AND WHY THE FIELD SET IS DECLARED RATHER THAN CONSTANT. `check-stories` reads
# the entry-to-story-file join and reports drift; nothing in core could write the derived value
# back, so a consumer that wanted that kept its own tool. The one that exists derives NINE fields
# while schemas/sprint-status.json declares TWO story-entry fields, exactly ONE of which is among
# the nine. Hand-listing the other eight in core would be a second home for a schema — I28 and I48
# both bite — so the CONSUMER declares them, in the file the contract names as
# `consumer_story_fields_file:`, and core owns everything else: the parse, both canonical views,
# the story-file resolution, the frontmatter read and the byte-verbatim write.
#
# `status` IS NOT DECLARABLE. It comes from the schema's own `story_entry_fields`, because it is
# the field Check 5 depends on and a consumer must not be able to declare its way out of it. The
# declaration ADDS to that floor and cannot subtract from it.
#
# THE WRITE IS BYTE-VERBATIM EXCEPT FOR THE VALUE TOKEN, and that is a requirement rather than a
# courtesy: this envelope is hand-edited by six actors across a sprint, so a tool that re-emits it
# loses their inline comments, their field order and their block scalars on every run.
#
# CHECK 5 HAD NO ENFORCER. Its own text says "Run: Read both files, compare status values
# programmatically" and core shipped no program — enforcement-map.yaml carried `enforcer: []` for it
# while dev.md, qa.md, code-reviewer.md, implementation.md and retro.md all restate the duty. The
# reference consumer wrote the executable core described, three times, and each one went vacuously
# green at least once: one globbed `story-<N>-*` at a corpus named `story-S<N>-*` and printed
# "checked 0 story files" beside its success line; one compared zero derivable fields for a whole
# sprint and reported clean; one read a `**Status:**` block that its own story files no longer
# carried. `check-stories` is core's version, and the count is part of its contract: it prints how
# many entries it parsed and how many comparisons it made, and it never exits 0 on zero.
#
# BOTH MODES COUNT DISTINCT STORIES AND PRINT THE PER-VIEW WORK SEPARATELY. The two canonical
# views carry the same sprint's `stories:` mapping, so a per-view sum reports one story as two.
# `derive-stories` did exactly that for four releases, on the summary line whose count is the
# contract, and its `--check` — the mode a gate runs — printed no entry count at all. That number
# is the only half of the envelope-vs-corpus comparison core can supply: the derive resolves files
# FROM the entries, so it can never see a story file the envelope omits, and the consumer's own
# membership rule is what supplies the other side. Core owns the denominator; it does not own,
# and must not infer, which files on disk are stories.
#
# ROTATION HAPPENS AT PIPELINE START, NOT AT CLOSE. `roll` freezes the closed sprint to
# s<N>/sprint-status.yaml and writes the new envelope in ONE step. The reference consumer
# rotates at retro-close instead, which prunes the `status: done` block that sprint-id must read and
# leaves a preamble-only file no rule covers — a window its lead fills BY HAND. Rotating at start
# keeps the predecessor's terminal state readable exactly until its successor exists.
#
# Exit codes:
#   0  — success
#   1  — fail-closed (schema unreadable, canonical malformed, byte-verify failed)
#   2  — usage error
#   3  — HARD_BLOCK: the two canonical copies disagree on `sprint:`. Never guess which is
#        authoritative (route.md Step 6 rule 5). Surface both and wait for the operator.
#        derive-stories also: MATCHED NO STORY FILES. Compared nothing because there was nothing
#        to compare against, which is not the same answer as compared-and-clean.
#   4  — check-stories only: NOTHING WAS COMPARED (no canonical on disk, or no `stories:` key in
#        the sprint that is live). Its own code, never folded into 0, because "compared nothing"
#        and "compared and found no drift" are the two states every consumer implementation of
#        this check conflated. Check 5's prose decides which is acceptable: at an implementation
#        gate a 4 FAILS (a sprint in flight with no story entries), at a planning-phase gate it is
#        the exemption that check already states.
#        derive-stories also: it MATCHED story files and some story got ZERO comparisons — every
#        declared field, `status` included, was unreadable for it. Same distinction, one grain
#        down, and it is separate from 3 because "found nothing to read" and "read nothing from
#        what it found" have different remedies.
#
# Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — hence JSON for the schema, and a line
# parser for the flat YAML envelope, matching validate-audit-anchors.sh).

set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts —
# here that put .claude/schemas/ out of reach and every invocation failed closed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
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

SCRIPT_DIR="$AI_DLC_SELF_DIR"

# Resolve the schema in both layouts (distribution core/schemas, consumer .claude/schemas), with an
# env override for tests. No built-in copy: if it cannot be found we fail closed, never guess.
# Script-relative first — that is the package this copy shipped in — then the resolved root.
if [ -n "${AI_DLC_SPRINT_STATUS_SCHEMA:-}" ] && [ -f "${AI_DLC_SPRINT_STATUS_SCHEMA}" ]; then
  SCHEMA="$AI_DLC_SPRINT_STATUS_SCHEMA"
elif [ -f "$SCRIPT_DIR/../schemas/sprint-status.json" ]; then
  SCHEMA="$(cd "$SCRIPT_DIR/../schemas" && pwd)/sprint-status.json"
elif [ -n "$AI_DLC_ROOT" ] && [ -f "$AI_DLC_ROOT/core/schemas/sprint-status.json" ]; then
  SCHEMA="$AI_DLC_ROOT/core/schemas/sprint-status.json"
elif [ -n "$AI_DLC_ROOT" ] && [ -f "$AI_DLC_ROOT/.claude/schemas/sprint-status.json" ]; then
  SCHEMA="$AI_DLC_ROOT/.claude/schemas/sprint-status.json"
else
  echo "sprint-status: FAIL — cannot find schemas/sprint-status.json (the source of truth; this" >&2
  echo "  script has no built-in copy and will not guess). Looked in $SCRIPT_DIR/../schemas/ and" >&2
  echo "  ${AI_DLC_ROOT:-<unresolved project root>}/{core,.claude}/schemas/." >&2
  exit 1
fi

MODE=""; FILE=""; PROJECT_ROOT=""; SPRINT=""; NAME=""; VARIANT=""; INTENSITY=""; EVIDENCE=""; CLOSED_AT=""; RETRO_DOC=""

case "${1:-}" in
  --render)   MODE="render"; shift ;;
  --check)    MODE="check"; FILE="${2:-}"; shift 2 2>/dev/null || shift ;;
  sprint-id)  MODE="sprint-id"; shift ;;
  roll)       MODE="roll"; shift ;;
  close)      MODE="close"; shift ;;
  check-stories) MODE="check-stories"; shift ;;
  derive-stories) MODE="derive-stories"; shift ;;
  "")         echo "usage: sprint-status.sh --render | --check <file> | sprint-id | roll --sprint <N> | close --evidence <text> | check-stories [--sprint <N>] | derive-stories [--check] [--sprint <N>]" >&2; exit 2 ;;
  *)          echo "sprint-status: unknown command '$1'" >&2; exit 2 ;;
esac

DRY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check)     [ "$MODE" = "derive-stories" ] || { echo "sprint-status: --check is a mode of its own, or a flag of derive-stories" >&2; exit 2; }
                 DRY="1"; shift ;;
    --root)      PROJECT_ROOT="${2:-}"; shift 2 ;;
    --sprint)    SPRINT="${2:-}"; shift 2 ;;
    --name)      NAME="${2:-}"; shift 2 ;;
    --variant)   VARIANT="${2:-}"; shift 2 ;;
    --intensity) INTENSITY="${2:-}"; shift 2 ;;
    --evidence)  EVIDENCE="${2:-}"; shift 2 ;;
    --closed-at) CLOSED_AT="${2:-}"; shift 2 ;;
    --retro-doc) RETRO_DOC="${2:-}"; shift 2 ;;
    *)           echo "sprint-status: unknown option '$1'" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = "check" ] && [ -z "$FILE" ]; then
  echo "usage: sprint-status.sh --check <file>" >&2; exit 2
fi
if [ "$MODE" = "check" ] && [ ! -r "$FILE" ]; then
  echo "sprint-status: FAIL — cannot read '$FILE'" >&2; exit 1
fi
if [ "$MODE" = "roll" ] && [ -z "$SPRINT" ]; then
  echo "usage: sprint-status.sh roll --sprint <N>" >&2; exit 2
fi
if [ "$MODE" = "close" ] && [ -z "$EVIDENCE" ]; then
  echo "usage: sprint-status.sh close --evidence <text> [--sprint <N>] [--closed-at <date>] [--retro-doc <path>]" >&2; exit 2
fi

[ -n "$PROJECT_ROOT" ] || PROJECT_ROOT="$(pwd)"

command -v python3 >/dev/null 2>&1 || { echo "sprint-status: FAIL — python3 required" >&2; exit 1; }

# The derivable-field list's LOCATION comes from the contract's declaration, never from a literal
# here — a reader that restates the path passes every agreement check while the declaration moves
# out from under it. Both layouts, because this script runs in both. An UNREADABLE contract is not
# an error here: the derive's own arm reports it as a worklist and exits 0, exactly as the trunk
# audit does, so a consumer that predates the declaration is not wedged by it.
STORY_FIELDS_FILE=""
for _lc in "$PROJECT_ROOT/.claude/skills/ai-dlc/layer-contract.yaml" \
           "$PROJECT_ROOT/core/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$_lc" ] || continue
  _rel="$(sed -n 's/^consumer_story_fields_file:[[:space:]]*//p' "$_lc" | head -1 | sed 's/[[:space:]]*$//')"
  [ -n "$_rel" ] && STORY_FIELDS_FILE="$PROJECT_ROOT/$_rel"
  STORY_FIELDS_REL="$_rel"
  break
done

MODE="$MODE" FILE="$FILE" SCHEMA="$SCHEMA" PROJECT_ROOT="$PROJECT_ROOT" \
SPRINT="$SPRINT" NAME="$NAME" VARIANT="$VARIANT" INTENSITY="$INTENSITY" \
EVIDENCE="$EVIDENCE" CLOSED_AT="$CLOSED_AT" RETRO_DOC="$RETRO_DOC" \
DRY="$DRY" STORY_FIELDS_FILE="${STORY_FIELDS_FILE:-}" \
STORY_FIELDS_REL="${STORY_FIELDS_REL:-}" python3 - <<'PY'
import json, os, re, sys
from pathlib import Path

mode   = os.environ["MODE"]
schema = json.loads(Path(os.environ["SCHEMA"]).read_text())
root   = Path(os.environ["PROJECT_ROOT"])

KEYS       = schema["keys"]
SPRINT_RE  = re.compile(KEYS["sprint_re"],       re.M)
STATUS_RE  = re.compile(KEYS["status_re"],       re.M)
HOUSE_RE   = re.compile(KEYS["housekeeping_re"], re.M)
STORIES_RE = re.compile(KEYS["stories_re"])
STORY_KEY_RE   = re.compile(KEYS["story_key_re"])
STORY_FIELD_RE = re.compile(KEYS["story_field_re"])

SFILE         = schema["story_file"]
# A TEMPLATE, NOT A PATH. The sprint slot moved out of the story FILENAME and into the DIRECTORY
# (artifact-path-grammar.md rule 2), so the corpus location is a function of the sprint rather than
# a constant. Read from the schema, never restated here: I84 binds the single home.
STORIES_DIR_T = SFILE["stories_dir"]
SPRINT_SLOT   = SFILE["stories_dir_sprint_placeholder"]
FM_STATUS_RE  = re.compile(SFILE["frontmatter_status_re"], re.M)
HDR_STATUS_RE = re.compile(SFILE["header_status_re"],      re.M)
HDR_CUT_RE    = re.compile(SFILE["header_value_cut"])

def fail(msg, code=1):
    sys.stderr.write("sprint-status: FAIL — %s\n" % msg)
    sys.exit(code)

# The two canonical copies. The collapse to a single path is a later release; until then sprint-id
# must honour route.md Step 6 rule 5 (copies disagree -> HARD_BLOCK), so it reads BOTH.
VIEWS = {
    "implementation": root / "_bmad-output/implementation-artifacts/sprint-status.yaml",
    "planning":       root / "_bmad-output/planning-artifacts/sprint-status.yaml",
}
# implementation is the primary: it is where every writer already writes (dev, code-reviewer, the
# lead at three steps) and where the one unattended runtime reader (ai-dlc-precompact.sh) points.
PRIMARY = "implementation"

# THE FREEZE DESTINATION IS THE PATH GRAMMAR'S, AND THE OLD SPELLING IS STILL READABLE.
# `roll` composed `<area>/sprint-status/sprint-<N>.yaml` until v0.341.0 — the PRE-MIGRATION form.
# `migrate-artifact-paths.sh` maps exactly that path onto `<area>/s<N>/sprint-status.yaml`, and
# `validate-artifact-paths.sh` BLOCKS on it, so on a migrated consumer the next genuine roll wrote
# a path that failed their own pre-push. Measured with a control in one tree: the old form was the
# single BLOCKING row and the migrated sibling was not reported at all.
#
# THE WRITER MOVES; THE READER MUST NOT. Every consumer that has not run the migration still holds
# its history under the old spelling, so `max_frozen` reads BOTH — and that reader is the one whose
# empty answer falls back to sprint 1, "which would silently re-stamp a live project as greenfield".
# A writer-only fix would leave a migrated tree's archive invisible to the fallback it guards.
def frozen_path(view, n):
    """The grammar form: the sprint slot is the DIRECTORY, never the basename."""
    return VIEWS[view].parent / ("s%d" % n) / "sprint-status.yaml"

def legacy_frozen_path(view, n):
    """The pre-migration form. Read, never written."""
    return VIEWS[view].parent / "sprint-status" / ("sprint-%d.yaml" % n)

def frozen_sprints(view):
    """Every frozen sprint number this view carries, in EITHER spelling."""
    parent = VIEWS[view].parent
    ns = set()
    if parent.is_dir():
        for d in parent.glob("s*"):
            m = re.match(r"^s([0-9]+)$", d.name)
            if m and (d / "sprint-status.yaml").is_file():
                ns.add(int(m.group(1)))
    legacy = parent / "sprint-status"
    if legacy.is_dir():
        for f in legacy.glob("sprint-*.yaml"):
            m = re.match(r"^sprint-([0-9]+)\.yaml$", f.name)
            if m:
                ns.add(int(m.group(1)))
    return ns

def parse(text):
    """Return (sprint:int|None, status:str|None). None means the key is absent — which is a REAL
    state, not an error: a rotated-at-close canonical is preamble-only and carries neither."""
    m = SPRINT_RE.search(text)
    s = STATUS_RE.search(text)
    return (int(m.group(1)) if m else None,
            s.group(1) if s else None)

def read_view(view):
    p = VIEWS[view]
    if not p.is_file():
        return None
    return parse(p.read_text())

def max_frozen(view):
    ns = frozen_sprints(view)
    return max(ns) if ns else None

def render_header():
    return "\n".join(schema["header_lines"])

def resolve_sprint_id():
    """The mechanical replacement for route.md Step 6's prose. Every branch below is a state that
    actually occurs in a real tree — including the preamble-only one the prose has no case for."""
    seen = {}
    for v in VIEWS:
        r = read_view(v)
        if r is not None:
            seen[v] = r

    # Rule 5: the copies disagree on `sprint:` -> HARD_BLOCK. Never guess.
    sprints = {v: r[0] for v, r in seen.items() if r[0] is not None}
    if len(set(sprints.values())) > 1:
        detail = ", ".join("%s=%s" % (v, n) for v, n in sorted(sprints.items()))
        fail("the two sprint-status.yaml copies disagree on `sprint:` (%s). Never guess which is "
             "authoritative — surface both and wait (route.md Step 6 rule 5, Rule 11 HARD_BLOCK)."
             % detail, code=3)

    order = [PRIMARY] + [v for v in VIEWS if v != PRIMARY]
    rec = next((seen[v] for v in order if v in seen), None)

    # Rule 2: no copy on disk at all -> greenfield.
    if rec is None:
        return 1

    sprint, status = rec

    # The state route.md Step 6 has NO CASE for: the file EXISTS but carries no `sprint:` key.
    # A rotate-at-close canonical is pruned to its preamble, so rule 2 ("file does not exist") does
    # not match and rules 3/4 branch on a `status:` that is absent. Derive from the durable record
    # instead of guessing — and never fall back to 1, which would silently re-stamp a live project
    # as greenfield and destroy the prior sprint's drafts.
    if sprint is None:
        frozen = max((n for n in (max_frozen(v) for v in VIEWS) if n is not None), default=None)
        if frozen is not None:
            return frozen + 1
        return 1

    # Rule 3: the prior sprint is closed and a new pipeline is starting.
    if status == "done":
        return sprint + 1
    # Rule 4: still in flight — this is a re-plan, not a new sprint.
    return sprint

def check_file(path):
    text = Path(path).read_text()
    sprint, status = parse(text)
    problems = []
    if sprint is None:
        problems.append("missing required top-level `sprint: <N>` (integer)")
    if status is None:
        problems.append("missing required top-level `status: <value>`")
    for m in HOUSE_RE.finditer(text):
        n = int(m.group(1))
        if sprint is not None and n != sprint:
            problems.append("`sprint_%d_housekeeping:` does not match `sprint: %d`" % (n, sprint))
    if problems:
        for p in problems:
            sys.stderr.write("sprint-status: %s: %s\n" % (path, p))
        return 1
    return 0

def write_verified(path, text, what):
    """Write, then read back and byte-compare. A write that is not read back is a claim, not a
    fact — the reference consumer shipped a rotation that reported success while writing nothing."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    on_disk = path.read_text()
    if on_disk != text:
        fail("%s: post-write read-back DIVERGED at %s. Wrote %d bytes, read %d."
             % (what, path, len(text), len(on_disk)))

def roll():
    target = int(os.environ["SPRINT"])
    moved = []

    # CREATION. This artifact has never had a creator: no step file, no template, no installer seed
    # — it simply appeared, hand-written, on whichever sprint someone first needed it. If no view
    # exists, seed the PRIMARY one only. Seeding both would mint the second copy that the whole
    # two-view drift problem is made of.
    if not any(v.is_file() for v in VIEWS.values()):
        write_verified(VIEWS[PRIMARY], new_envelope(target), "create")
        print("sprint-status: created %s at sprint %d" % (VIEWS[PRIMARY], target))
        return 0

    for view, canonical in VIEWS.items():
        if not canonical.is_file():
            continue
        text = canonical.read_text()
        sprint, status = parse(text)

        if sprint == target:
            continue                      # idempotent: already rolled
        if sprint is None:
            continue                      # preamble-only: nothing to freeze
        if status != "done":
            fail("%s canonical holds sprint %s with status '%s' — refusing to roll forward to %d "
                 "over a sprint that is not closed. Close it first (retro), or fix the envelope."
                 % (view, sprint, status, target), code=3)

        # An existing freeze in EITHER spelling is a freeze. Writing the grammar form beside a
        # legacy copy of the same sprint would mint the second archive that idempotency exists to
        # prevent — and on an unmigrated consumer the legacy copy is the only one there is.
        frozen = frozen_path(view, sprint)
        existing = next((p for p in (frozen, legacy_frozen_path(view, sprint)) if p.is_file()), None)
        if existing is not None:
            if existing.read_text() != text:
                fail("%s: %s already exists and DIFFERS from the canonical it would freeze. A "
                     "partial close was completed by hand, or the archive was edited. Refusing to "
                     "overwrite — reconcile by hand." % (view, existing), code=3)
        else:
            write_verified(frozen, text, "%s freeze" % view)
            moved.append(str(frozen))

        write_verified(canonical, new_envelope(target), "%s roll-forward" % view)
        moved.append(str(canonical))

    if moved:
        print("sprint-status: rolled forward to sprint %d" % target)
        for m in moved:
            print("  %s" % m)
    else:
        print("sprint-status: already at sprint %d (no-op)" % target)
    return 0

def new_envelope(n):
    name      = os.environ.get("NAME") or ""
    variant   = os.environ.get("VARIANT") or ""
    intensity = os.environ.get("INTENSITY") or ""
    lines = ["sprint: %d" % n]
    if name:
        lines.append('name: "%s"' % name.replace('"', '\\"'))
    if variant:
        lines.append("variant: %s" % variant)
    lines.append("status: in_progress")
    if intensity:
        lines.append("validation_intensity: %s" % intensity)
    lines.append("stories:")
    lines.append("  # populated at stories-test-strategy. A MAPPING keyed by story id")
    lines.append("  # (story-%d-<M>:), never a list — a list form matches no reader." % n)
    return "\n".join(lines) + "\n"

def set_status_done(text):
    """Flip the top-level `status:` to done. First match only — the housekeeping block's indented
    `envelope_status` never matches STATUS_RE's `^status:` anchor, so this cannot touch it."""
    new, count = STATUS_RE.subn("status: done", text, count=1)
    if count == 0:
        fail("canonical has no top-level `status:` line to flip to done (schema-required field "
             "missing) — refusing to guess where the envelope begins.", code=1)
    return new

def upsert_housekeeping(text, n, evidence, closed_at, retro_doc):
    """Insert or replace THIS sprint's `sprint_<n>_housekeeping:` block. Idempotent: a second close
    with identical inputs rebuilds a byte-identical block, so close() then writes nothing."""
    body = ["  envelope_status: done",
            '  closure_evidence: "%s"' % evidence.replace("\\", "\\\\").replace('"', '\\"')]
    if closed_at:
        body.append("  closed_at: %s" % closed_at)
    if retro_doc:
        body.append("  retro_doc: %s" % retro_doc)
    block = ["sprint_%d_housekeeping:" % n] + body

    keypat = re.compile(r"^sprint_%d_housekeeping:[ \t]*(?:#.*)?$" % n)
    lines = text.split("\n")
    out, i, replaced = [], 0, False
    while i < len(lines):
        if keypat.match(lines[i]):
            # drop the existing block: the key line plus its indented/blank continuation lines
            i += 1
            while i < len(lines) and (lines[i] == "" or lines[i][:1] in (" ", "\t")):
                i += 1
            out.extend(block)
            replaced = True
        else:
            out.append(lines[i]); i += 1
    if not replaced:
        while out and out[-1] == "":
            out.pop()
        out.extend(block)
    result = "\n".join(out)
    return result if result.endswith("\n") else result + "\n"

def close():
    """Retro-close: flip status -> done and stamp the housekeeping block Check 3 reads. This is the
    producer the schema names ('written ONLY by sprint-status.sh close') and that never existed."""
    want = os.environ.get("SPRINT")
    want = int(want) if want else None
    evidence   = os.environ["EVIDENCE"]
    closed_at  = os.environ.get("CLOSED_AT") or ""
    retro_doc  = os.environ.get("RETRO_DOC") or ""

    existing = [(v, VIEWS[v]) for v in VIEWS if VIEWS[v].is_file()]
    if not existing:
        fail("no sprint-status.yaml canonical exists to close. A sprint must be rolled before it can "
             "be closed (sprint-status.sh roll).", code=1)

    written = []
    for view, canonical in existing:
        text = canonical.read_text()
        sprint, status = parse(text)
        if sprint is None:
            fail("%s canonical carries no `sprint:` key — cannot close a preamble-only envelope."
                 % view, code=1)
        if want is not None and sprint != want:
            fail("%s canonical holds sprint %d, but close was asked for sprint %d. Never guess which "
                 "is authoritative (route.md Step 6 rule 5)." % (view, sprint, want), code=3)
        new_text = upsert_housekeeping(set_status_done(text), sprint, evidence, closed_at, retro_doc)
        if new_text != text:
            write_verified(canonical, new_text, "%s close" % view)
            written.append(str(canonical))

    if written:
        print("sprint-status: closed sprint envelope (status: done + housekeeping)")
        for w in written:
            print("  %s" % w)
    else:
        print("sprint-status: already closed (no-op)")
    return 0

# --- check-stories: the mechanical half of gate-validation.md Check 5 -------------------------
# Everything below reports rather than skips. A story this cannot resolve, cannot read, or cannot
# find a status in is a FINDING; the only silence is a state where there is genuinely nothing to
# compare, and that state has its own exit code (4) so no caller can read it as clean.

def strip_value(v):
    """One YAML scalar, as this file's line parser sees it: quotes off, or inline comment off.
    The quoted branch is first because real `note:` values run to several hundred characters of
    prose containing every delimiter this function would otherwise cut on."""
    v = v.strip()
    if v[:1] in ("'", '"'):
        q = v[0]
        end = v.find(q, 1)
        return v[1:end] if end != -1 else v[1:]
    i = v.find(" #")
    if i != -1:
        v = v[:i]
    return v.strip()


def parse_story_entries(text):
    """Parse the `stories:` mapping into [(key, {field: value}, lineno)].

    Returns (state, entries). state is one of:
      no-block    — the document carries no `stories:` key. A real state (a sprint before its
                    stories exist), reported, never a finding on its own.
      empty       — a `stories:` key whose block carries nothing but comments. This is exactly
                    what `sprint-status.sh roll` writes, so it is a legitimate freshly-rolled
                    sprint and NOT a finding — it counts toward "compared nothing" instead.
      ok          — a mapping with at least one entry.
      no-entries  — a `stories:` key whose block HAS content and still yields no entry key. THIS
                    IS A FINDING, not an empty result: it is what the LIST form (`- id: x`) and a
                    mis-indented block both look like, and reporting it as zero-stories-so-clean
                    is the vacuous green this check exists to end. The distinction from `empty` is
                    load-bearing and was measured: without it this fires on the output of core's
                    own `roll`.

    Indent is read RELATIVELY: entry keys sit at the indent of the first bare key under
    `stories:`, fields sit at the first deeper indent inside that entry, and anything deeper
    still (block scalars, wrapped prose) is neither."""
    lines = text.split("\n")
    start = None
    for i, ln in enumerate(lines):
        if STORIES_RE.match(ln):
            start = i + 1
            break
    if start is None:
        return ("no-block", [])

    entries = []
    entry_indent = None
    field_indent = None
    cur = None
    content = False
    for off, ln in enumerate(lines[start:]):
        if ln.strip() == "" or ln.lstrip().startswith("#"):
            continue
        indent = len(ln) - len(ln.lstrip())
        if indent == 0:
            break                                  # the `stories:` block ended
        content = True
        km = STORY_KEY_RE.match(ln)
        if entry_indent is None:
            if km is None:
                continue                           # not a bare key — keep looking for one
            entry_indent = indent
        if indent == entry_indent:
            if km is None:
                continue
            cur = {}
            field_indent = None
            entries.append((km.group(2).strip(), cur, start + off + 1))
        elif cur is not None and indent > entry_indent:
            fm = STORY_FIELD_RE.match(ln)
            if fm is None:
                continue
            if field_indent is None:
                field_indent = indent
            if indent == field_indent:
                cur[fm.group(2)] = strip_value(fm.group(3))
    if entries:
        return ("ok", entries)
    return ("no-entries" if content else "empty", [])


def story_file_status(path):
    """(status, grammar) or (None, why). Frontmatter first; the `**Status:**` body header only for
    a file that carries no frontmatter block at all — both spellings are live in a real corpus and
    a reader that knows only one silently skips most of it."""
    try:
        text = Path(path).read_text(errors="replace")
    except OSError:
        return (None, "cannot read the file")
    fm_text = None
    if text.startswith("---\n") or text.startswith("---\r\n"):
        end = text.find("\n---", 3)
        if end != -1:
            fm_text = text[4:end]
    if fm_text is not None:
        m = FM_STATUS_RE.search(fm_text)
        if m:
            return (strip_value(m.group(1)), "frontmatter")
        return (None, "frontmatter block carries no `status:`")
    m = HDR_STATUS_RE.search(text)
    if m:
        v = m.group(1).strip()
        cut = HDR_CUT_RE.search(v)
        if cut:
            v = v[:cut.start()]
        return (v.strip().strip("`*").strip(), "`**Status:**` header")
    return (None, "no `status:` frontmatter and no `**Status:**` header")


def stories_dir(sprint):
    """The corpus location for ONE sprint, or for every sprint when `sprint` is `*`. The template
    is the schema's; substituting into it is the only way this file names the corpus."""
    return STORIES_DIR_T.replace(SPRINT_SLOT, str(sprint))


def story_key_stem(key, sprint):
    """The entry KEY still spells the sprint (`story-302-1`, and historically `story-S299-1`); the
    FILE no longer does. Strip the DECLARED sprint — never a searched or guessed one — from the
    key's `-` components, and what is left is the story index the filename carries.

    A key that does not name the declared sprint comes back UNCHANGED, so a corpus already keyed
    `story-<M>` resolves without a second rule, and a key naming some OTHER sprint keeps that
    number and simply fails to resolve — which is a FINDING here, and is meant to be. Guessing
    which number in a key was the sprint is exactly the ambiguity this release removed from the
    filename; it must not be reintroduced in the key."""
    parts = key.split("-")
    pat = re.compile(r"[sS]?0*%d" % int(sprint)) if str(sprint).isdigit() else None
    if pat is None:
        return key
    out = [p for p in parts if not pat.fullmatch(p)]
    return "-".join(out) if out else key


def resolve_story_file(view_path, key, declared, sprint):
    """First candidate that exists, never a single guessed path. The two canonicals sit in
    DIFFERENT directories and both name the story corpus with the same relative `file:` value, so
    resolving relative to the canonical alone finds the corpus from one view and nothing from the
    other.

    THE SPRINT COMES FROM THE DECLARATION, NOT FROM THE KEY OR THE FILESYSTEM. That is the join
    this release re-derived: the old form globbed the whole key against one flat directory shared
    by 56 sprints, which is why `story-S299-1` and `story-297-1` needed two spellings to be
    findable at all."""
    stories = root / stories_dir(sprint)
    cands = []
    if declared:
        d = Path(declared)
        if d.is_absolute():
            cands.append(d)
        else:
            cands.append(view_path.parent / declared)
            cands.append(root / Path(stories_dir(sprint)).parent / declared)
            cands.append(root / declared)
            cands.append(stories / d.name)
    # The key's sprint-stripped stem IS the story id within the sprint. Exact file first, then
    # `<stem>-<slug>.md` — never `<stem>*`, which matches story-10 for story-1.
    stem = story_key_stem(key, sprint)
    cands.append(stories / (stem + ".md"))
    for c in cands:
        if c.is_file():
            return c
    hits = sorted(stories.glob(stem + "-*.md")) if stories.is_dir() else []
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        return hits            # ambiguity is a finding, not a pick
    return None


def declared_sprint():
    """The sprint the canonicals SAY they hold. Deliberately not `sprint-id`, which applies route.md
    Step 6 rule 3 (done -> N+1) and so names the sprint about to start, not the one whose stories
    are on disk — running Check 5 against N+1 makes every closed sprint report zero entries. Rule 5
    still applies: copies that disagree are a HARD_BLOCK, never a guess."""
    sprints = {}
    for v in VIEWS:
        r = read_view(v)
        if r is not None and r[0] is not None:
            sprints[v] = r[0]
    if len(set(sprints.values())) > 1:
        detail = ", ".join("%s=%s" % (v, n) for v, n in sorted(sprints.items()))
        fail("the two sprint-status.yaml copies disagree on `sprint:` (%s). Never guess which is "
             "authoritative — surface both and wait (route.md Step 6 rule 5, Rule 11 HARD_BLOCK)."
             % detail, code=3)
    return next(iter(sprints.values())) if sprints else None


def check_stories():
    want = os.environ.get("SPRINT")
    target = int(want) if want else declared_sprint()     # exits 3 if the copies disagree
    if target is None:
        print("sprint-status: check-stories COMPARED NOTHING (exit 4) — no canonical on disk "
              "carries a `sprint:` key, so there is no sprint whose stories could be compared.")
        return 4

    findings = []
    compared = 0
    entries_total = 0
    views_present = 0
    per_view = {}

    print("sprint-status check-stories: sprint %d" % target)

    for view in VIEWS:
        p = VIEWS[view]
        if not p.is_file():
            print("  %-15s no canonical on disk" % (view + ":"))
            continue
        views_present += 1
        text = p.read_text()
        vsprint, _ = parse(text)
        if vsprint is not None and vsprint != target:
            print("  %-15s holds sprint %s, not %d — not compared" % (view + ":", vsprint, target))
            continue

        state, entries = parse_story_entries(text)
        if state == "no-block":
            print("  %-15s no `stories:` key — nothing to compare" % (view + ":"))
            continue
        if state == "empty":
            print("  %-15s `stories:` present but empty (a freshly rolled sprint) — nothing to "
                  "compare" % (view + ":"))
            continue
        if state == "no-entries":
            findings.append("[%s] a `stories:` key whose block yields NO entry: the mapping is "
                            "empty, mis-indented, or written in the `- id:` LIST form. A list "
                            "matches no reader and reports vacuous-green all sprint (schema "
                            "header: a MAPPING keyed by story id, NOT a list)." % view)
            print("  %-15s `stories:` present, 0 entries parsed — FINDING" % (view + ":"))
            continue

        entries_total += len(entries)
        seen = {}
        view_compared = 0
        for key, fields, lineno in entries:
            if key in seen:
                findings.append("[%s/%s] duplicate story key (lines %d and %d). Two entries under "
                                "one id: whichever a reader takes, the other one is unenforced."
                                % (view, key, seen[key], lineno))
                continue
            seen[key] = lineno
            ystatus = fields.get("status")
            if ystatus is None:
                findings.append("[%s/%s] entry carries no `status:` field (line %d)."
                                % (view, key, lineno))
                continue
            resolved = resolve_story_file(p, key, fields.get("file"), target)
            if resolved is None:
                _sd = stories_dir(target)
                _stem = story_key_stem(key, target)
                findings.append("[%s/%s] names no readable story file (declared `file: %s`; also "
                                "looked for %s/%s.md and %s/%s-*.md). The story corpus now lives "
                                "under the sprint's OWN directory; a tree still holding it in one "
                                "flat directory shared across sprints has not been migrated — run "
                                "`scripts/ai-dlc/migrate-artifact-paths.sh` (dry run), then "
                                "`--apply`."
                                % (view, key, fields.get("file", "<absent>"),
                                   _sd, _stem, _sd, _stem))
                continue
            if isinstance(resolved, list):
                findings.append("[%s/%s] resolves to %d story files (%s) — ambiguous id."
                                % (view, key, len(resolved),
                                   ", ".join(f.name for f in resolved)))
                continue
            fstatus, how = story_file_status(resolved)
            if fstatus is None:
                findings.append("[%s/%s] %s: %s" % (view, key, resolved.name, how))
                continue
            compared += 1
            view_compared += 1
            per_view.setdefault(key, {})[view] = ystatus
            if fstatus != ystatus:
                findings.append("[%s/%s] STATUS MISMATCH — %s says `%s` (%s), %s says `%s` "
                                "(line %d)." % (view, key, resolved.name, fstatus, how,
                                                p.name, ystatus, lineno))
        print("  %-15s %d entr%s, %d comparison(s)"
              % (view + ":", len(entries), "y" if len(entries) == 1 else "ies", view_compared))

    # The two canonicals are both authoritative for a story entry. Disagreement between them is the
    # same class route.md Step 6 rule 5 HARD_BLOCKs on for `sprint:`, one grain down — reported, not
    # blocked, because unlike `sprint:` the story file resolves it.
    for key in sorted(per_view):
        vals = per_view[key]
        if len(vals) > 1 and len(set(vals.values())) > 1:
            findings.append("[%s] the two canonical copies disagree: %s"
                            % (key, ", ".join("%s=`%s`" % (v, s) for v, s in sorted(vals.items()))))

    print("")
    if findings:
        for f in findings:
            sys.stderr.write("sprint-status: FINDING %s\n" % f)
        print("sprint-status: check-stories FAIL — %d finding(s), %d comparison(s) over %d entr%s"
              % (len(findings), compared, entries_total, "y" if entries_total == 1 else "ies"))
        return 1
    if compared == 0:
        print("sprint-status: check-stories COMPARED NOTHING (exit 4) — %d canonical cop%s on "
              "disk, %d story entr%s for sprint %d. This is not a pass. Check 5 fails a gate on "
              "it from Phase 4 on; before stories exist it is that check's planning exemption."
              % (views_present, "y" if views_present == 1 else "ies",
                 entries_total, "y" if entries_total == 1 else "ies", target))
        return 4
    print("sprint-status: check-stories PASS — %d comparison(s) over %d entr%s, 0 finding(s)"
          % (compared, entries_total, "y" if entries_total == 1 else "ies"))
    return 0


# --- derive-stories: the WRITE half of the duty check-stories already reads ---------------------
# check-stories JOINS the entry's `status:` to the story file's and reports drift. Nothing in core
# could write the derived value back, so every consumer that wanted that kept its own tool -- and
# the tool that exists derives NINE fields against a schema declaring ONE of them. Hence the split:
# core owns the parse, the two views, the resolution, the frontmatter read and the byte-verbatim
# write; the CONSUMER declares which of its story fields are derivable, because core cannot know
# that this project's stories carry `capital_path`.

FIELD_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

def declared_story_fields():
    """(state, [names]). state is one of:
         no-declaration  the contract carries no `consumer_story_fields_file:`, or the file it
                         names is not on disk. A consumer predating this, reported and exit 0.
         none            the literal `none` -- a complete answer, and NOT the same as silence.
         ok              at least one field.
         malformed       a block with content that yields no field. Reported, never treated as
                         empty: that collapse is what every vacuous-green in this file's history
                         is made of.
       `status` is NOT in this set and is never read from it -- see STATUS_FLOOR."""
    p = os.environ.get("STORY_FIELDS_FILE") or ""
    if not p or not Path(p).is_file():
        return ("no-declaration", [])
    try:
        text = Path(p).read_text(errors="replace")
    except OSError:
        return ("no-declaration", [])
    inside = False
    body = []
    for ln in text.split("\n"):
        if ln.startswith("```"):
            inside = not inside
            continue
        if not inside:
            continue
        s = ln.strip()
        if s == "" or s.startswith("#"):
            continue
        body.append(s)
    if not body:
        return ("no-declaration", [])
    if len(body) == 1 and body[0] == "none":
        return ("none", [])
    names, bad = [], []
    for s in body:
        if not s.startswith("field:"):
            bad.append(s)
            continue
        v = s.split(":", 1)[1].strip()
        if not FIELD_NAME_RE.match(v):
            bad.append(s)
            continue
        if v not in names:
            names.append(v)
    if bad or not names:
        return ("malformed", bad)
    return ("ok", names)


# THE FLOOR, AND IT COMES FROM THE SCHEMA RATHER THAN FROM THE DECLARATION. `status` is the one
# field Check 5 reads, core's schema declares it as a story-entry field, and a consumer must not
# be able to declare its way out of it. The declaration ADDS; it cannot subtract.
STATUS_FLOOR = [k for k, v in schema.get("story_entry_fields", {}).items() if v.get("required")]


def story_file_field(path, field):
    """(value, why-not). `status` keeps check-stories' two-grammar read verbatim -- frontmatter
    first, `**Status:**` header only for a file with no frontmatter block -- because both
    spellings are live in a real corpus and the two readers must not disagree about one file.
    Every other field is frontmatter only: there is no second spelling to honour and inventing
    one would be core guessing at the consumer's document shape."""
    if field == "status":
        return story_file_status(path)
    try:
        text = Path(path).read_text(errors="replace")
    except OSError:
        return (None, "cannot read the file")
    if not (text.startswith("---\n") or text.startswith("---\r\n")):
        return (None, "carries no frontmatter block")
    end = text.find("\n---", 3)
    if end == -1:
        return (None, "frontmatter block is unterminated")
    m = re.search(r"^%s:[ \t]*(.*?)[ \t]*$" % re.escape(field), text[4:end], re.M)
    if not m:
        return (None, "frontmatter carries no `%s:`" % field)
    return (strip_value(m.group(1)), "frontmatter")


# YAML INDICATORS. A plain scalar may not START with any of these, and may not CONTAIN `: ` or
# ` #` anywhere -- both re-open the mapping or the comment. This list is the YAML 1.2 c-indicator
# set minus the ones that are only special inside a flow collection, which this envelope never uses.
YAML_LEAD = "-?:,[]{}#&*!|>'\"%@`"


def yaml_scalar(v):
    """The value as a scalar the envelope can be re-read from. Bare when that is safe, otherwise
    double-quoted with the two characters that matter inside double quotes escaped.

    THIS EXISTS BECAUSE v0.237.0 SHIPPED WITHOUT IT AND CORRUPTED THE ARTIFACT IT WRITES. The
    derived value arrives already unquoted -- `strip_value` takes the quotes off on the way in --
    and re-emitting it bare turns a story title like `Fix: the direction-flip guard` into
    `title: Fix: the direction-flip guard`, which is not YAML. Measured on the reference consumer's
    corpus: 29 of 262 titles produce an unparseable line and 1 more is silently mangled, against a
    control of ZERO for all eight other declared fields -- so it is prose-valued fields, not a
    broken writer.

    The empty string is quoted too: a bare empty value is a YAML null, which is a different value
    from the empty string the story file actually carried."""
    if v == "" or v[:1] in YAML_LEAD or ": " in v or " #" in v or v.endswith(":") \
       or v != v.strip():
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return v


def rewrite_field_value(line, new):
    """Replace ONLY the value token of `<indent><key>:<sep><value><comment>`, verbatim otherwise.

    The byte-verbatim requirement is not stylistic. This envelope is hand-edited by six actors
    across a sprint; a tool that re-emits it loses their inline comments, their field order and
    their block scalars, and it would be doing that on every derive. Returns the line unchanged
    if it cannot see a value to replace -- there is no branch here that guesses at a shape."""
    m = re.match(r"^([ \t]*[A-Za-z_][A-Za-z0-9_]*:)([ \t]*)(.*)$", line)
    if not m:
        return line
    head, sep, rest = m.group(1), m.group(2), m.group(3)
    # An inline comment is kept WITH THE WHITESPACE RUN THAT PRECEDES IT, not merely kept. A
    # first cut normalised that run to one space and turned `draft          # hand note` into
    # `in_review # hand note` -- the comment survived and the hand-aligned column did not,
    # across every commented line in the file, on every run. Whitespace between the value and
    # the `#` is not part of the value, so it is not this function's to touch.
    tail = ""
    if rest[:1] not in ("'", '"'):
        cm = re.match(r"^(.*?)([ \t]+#.*)$", rest)
        if cm:
            tail = cm.group(2)
    if sep == "":
        sep = " "
    return head + sep + yaml_scalar(new) + tail


def derive_stories():
    dry = bool(os.environ.get("DRY"))
    state, fields = declared_story_fields()
    rel = os.environ.get("STORY_FIELDS_REL") or "<undeclared>"

    if state == "malformed":
        sys.stderr.write(
            "sprint-status: FAIL — %s carries a block this parser cannot read as a field list: "
            "%s. The grammar is one `field: <name>` line per derivable field, or the literal "
            "`none`. A malformed list is not an empty one, and deriving against a partial read "
            "would write some fields and silently skip others.\n" % (rel, "; ".join(fields[:4])))
        return 1
    if state in ("no-declaration", "none"):
        why = ("declares no `consumer_story_fields_file:`, or the file it names is not on disk, "
               "so this project predates the declaration" if state == "no-declaration"
               else "declares the literal `none`, so this project derives nothing beyond the "
                    "schema's own floor")
        print("sprint-status: derive-stories WORKLIST — %s %s. Nothing beyond %s was derived and "
              "nothing is wrong; declare the fields to widen it."
              % (rel, why, ", ".join("`%s`" % f for f in STATUS_FLOOR) or "the floor"))
        # The floor still runs: `status` is the schema's, not the declaration's.
    want = list(STATUS_FLOOR) + [f for f in fields if f not in STATUS_FLOOR]

    target = int(os.environ["SPRINT"]) if os.environ.get("SPRINT") else declared_sprint()
    if target is None:
        print("sprint-status: derive-stories MATCHED NO STORY FILES (exit 3) — no canonical on "
              "disk carries a `sprint:` key, so there is no sprint whose stories could be read.")
        return 3

    print("sprint-status derive-stories: sprint %d, fields %s%s"
          % (target, ", ".join(want), " (--check: nothing will be written)" if dry else ""))

    drifted = []
    roundtrip = []
    files_matched = 0
    zero_comparison = []
    wrote = 0
    entries_total = 0
    # THE COUNTS ARE PER-STORY, AND THE PER-VIEW WORK IS PRINTED SEPARATELY. Both canonical views
    # carry the same sprint's `stories:` mapping, so summing per view reports one story as two --
    # measured on the reference consumer, whose sprint 299 declares `story-S299-1` once in each
    # view and read `over 2 stories` from a run that saw one. That number is not cosmetic: the
    # count is this mode's contract, and the one thing a consumer cannot get from core is the
    # denominator for its own corpus scan. `derive-stories` resolves files FROM the entries, so it
    # can never see a story file the envelope omits -- but the ENVELOPE side of that comparison is
    # core's and core already computes it. A consumer comparing its corpus against a per-view sum
    # reads a false mismatch, which is why the number has to name distinct stories.
    seen_entries = set()
    seen_resolved = set()
    per_view = []

    for view in VIEWS:
        p = VIEWS[view]
        if not p.is_file():
            per_view.append((view, "no canonical on disk"))
            continue
        text = p.read_text()
        n, _ = parse(text)
        if n is not None and n != target:
            # a canonical holding a different sprint is not ours
            per_view.append((view, "holds sprint %s, not %d — not derived" % (n, target)))
            continue
        st, entries = parse_story_entries(text)
        if st != "ok":
            per_view.append((view, "no entry to derive (`stories:` %s)" % st))
            continue
        lines = text.split("\n")
        changed = False
        view_entries = 0
        view_resolved = 0
        for key, flds, lineno in entries:
            entries_total += 1
            view_entries += 1
            seen_entries.add(key)
            sf = resolve_story_file(p, key, flds.get("file"), target)
            if sf is None or isinstance(sf, list):
                # Unresolvable, or ambiguous. check-stories already reports this as a FINDING on
                # the status join; the derive does not double-report it and does not guess.
                continue
            files_matched += 1
            view_resolved += 1
            seen_resolved.add(key)
            comparisons = 0
            for field in want:
                have = flds.get(field)
                if have is None:
                    continue              # the entry does not carry this field: nothing to rewrite
                val, why = story_file_field(sf, field)
                if val is None:
                    continue              # the story file does not carry it: not invented
                comparisons += 1
                if val == have:
                    continue
                drifted.append("[%s] %s.%s: envelope `%s` -> story file `%s` (%s)"
                               % (view, key, field, have, val, sf.name))
                if dry:
                    continue
                # Find the field's own line inside this entry. The entry starts at `lineno`
                # (1-based) and ends at the next line no deeper than the entry's own indent.
                base = lineno - 1
                ei = len(lines[base]) - len(lines[base].lstrip())
                for j in range(base + 1, len(lines)):
                    lj = lines[j]
                    if lj.strip() == "":
                        continue
                    if len(lj) - len(lj.lstrip()) <= ei:
                        break
                    fm = STORY_FIELD_RE.match(lj)
                    if fm and fm.group(2) == field:
                        new = rewrite_field_value(lj, val)
                        # THE ROUND-TRIP GUARD, and it is here because the ABSENCE of it is what
                        # made v0.237.0's corruption silent rather than loud. This reader is a
                        # regex and it is MORE PERMISSIVE THAN YAML: handed the line
                        # `title: Fix: the thing` it returns `Fix: the thing` and compares equal,
                        # so `--check` reported PASS over a file the same tool had just made
                        # unparseable. The value is therefore read back through the envelope's own
                        # grammar before the line is accepted, and a mismatch is a FINDING that
                        # writes nothing rather than a write nobody can see.
                        rb = STORY_FIELD_RE.match(new)
                        if rb is None or strip_value(rb.group(3)) != val:
                            roundtrip.append(
                                "[%s] %s.%s: the value could not be written in a form this "
                                "envelope reads back as itself (wanted `%s`, the line would read "
                                "as `%s`). Nothing was written for this key."
                                % (view, key, field, val,
                                   strip_value(rb.group(3)) if rb else "<unparseable>"))
                            break
                        if new != lj:
                            lines[j] = new
                            changed = True
                            wrote += 1
                        break
            if comparisons == 0:
                zero_comparison.append("[%s] %s (%s)" % (view, key, sf.name))
        per_view.append((view, "%d entr%s, %d resolved"
                               % (view_entries, "y" if view_entries == 1 else "ies",
                                  view_resolved)))
        if changed and not dry:
            p.write_text("\n".join(lines))

    # The breakdown is printed for EVERY view, including the ones that contributed nothing.
    # `check-stories` already does this and `derive-stories` did not: a view skipped in silence
    # reads exactly like a view that agreed, which is this repository's named defect and the
    # reason the summed count above went four releases without anyone noticing it double-counted.
    for view, note in per_view:
        print("  %-15s %s" % (view + ":", note))

    stories_n = len(seen_resolved)
    entries_n = len(seen_entries)

    print("")
    if files_matched == 0:
        print("sprint-status: derive-stories MATCHED NO STORY FILES (exit 3) — %d entr%s parsed "
              "for sprint %d and not one resolved to a story file on disk. This is not a clean "
              "run: it compared nothing."
              % (entries_n, "y" if entries_n == 1 else "ies", target))
        return 3
    if roundtrip:
        for r in roundtrip:
            sys.stderr.write("sprint-status: UNWRITABLE %s\n" % r)
        print("sprint-status: derive-stories FAIL — %d value(s) could not be written in a form "
              "this envelope reads back as itself. NOTHING was written for those keys. This is the "
              "guard v0.237.0 shipped without, and its absence is why a corrupting write reported "
              "PASS." % len(roundtrip))
        return 1
    if zero_comparison:
        print("sprint-status: derive-stories COMPARED NOTHING for %d stor%s (exit 4) — %s. Every "
              "declared field, `status` included, was unreadable for %s. 'Matched files but "
              "verified nothing' is the same failure as 'matched no files' and must not print a "
              "clean line."
              % (len(zero_comparison), "y" if len(zero_comparison) == 1 else "ies",
                 "; ".join(zero_comparison[:5]),
                 "it" if len(zero_comparison) == 1 else "them"))
        return 4
    if dry:
        if drifted:
            for d in drifted:
                sys.stderr.write("sprint-status: DRIFT %s\n" % d)
            print("sprint-status: derive-stories --check FAIL — %d drifted key(s) over %d stor%s, "
                  "%d entr%s declared; NOTHING was written."
                  % (len(drifted), stories_n, "y" if stories_n == 1 else "ies",
                     entries_n, "y" if entries_n == 1 else "ies"))
            return 1
        # THE ENTRY COUNT IS ON THIS LINE BECAUSE `--check` IS THE MODE A CONSUMER'S GATE RUNS,
        # and it was the one summary that printed no entry count at all -- so the number core
        # holds and the consumer needs was emitted only by the write, which a gate must not call.
        print("sprint-status: derive-stories --check PASS — 0 drifted key(s) over %d stor%s, "
              "%d entr%s declared"
              % (stories_n, "y" if stories_n == 1 else "ies",
                 entries_n, "y" if entries_n == 1 else "ies"))
        return 0
    # `wrote` stays a per-view total and is correct as one: the write touches every view that
    # carries the entry, so two writes over one story is what happened. The two NOUNS are what
    # had to become distinct.
    print("sprint-status: derive-stories PASS — %d value(s) written over %d stor%s, %d entr%s "
          "declared"
          % (wrote, stories_n, "y" if stories_n == 1 else "ies",
             entries_n, "y" if entries_n == 1 else "ies"))
    return 0


if mode == "render":
    print(render_header())
    sys.exit(0)
elif mode == "check":
    sys.exit(check_file(os.environ["FILE"]))
elif mode == "sprint-id":
    print(resolve_sprint_id())
    sys.exit(0)
elif mode == "roll":
    sys.exit(roll())
elif mode == "close":
    sys.exit(close())
elif mode == "check-stories":
    sys.exit(check_stories())
elif mode == "derive-stories":
    sys.exit(derive_stories())
else:
    fail("unknown mode '%s'" % mode, code=2)
PY
