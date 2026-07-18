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
#
# ROTATION HAPPENS AT PIPELINE START, NOT AT CLOSE. `roll` freezes the closed sprint to
# sprint-status/sprint-<N>.yaml and writes the new envelope in ONE step. The reference consumer
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
#
# Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — hence JSON for the schema, and a line
# parser for the flat YAML envelope, matching validate-audit-anchors.sh).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DEFAULT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve the schema in both layouts (distribution core/schemas, consumer .claude/schemas), with an
# env override for tests. No built-in copy: if it cannot be found we fail closed, never guess.
if [ -n "${AI_DLC_SPRINT_STATUS_SCHEMA:-}" ] && [ -f "${AI_DLC_SPRINT_STATUS_SCHEMA}" ]; then
  SCHEMA="$AI_DLC_SPRINT_STATUS_SCHEMA"
elif [ -f "$SCRIPT_DIR/../schemas/sprint-status.json" ]; then
  SCHEMA="$(cd "$SCRIPT_DIR/../schemas" && pwd)/sprint-status.json"
elif [ -f "$ROOT_DEFAULT/.claude/schemas/sprint-status.json" ]; then
  SCHEMA="$ROOT_DEFAULT/.claude/schemas/sprint-status.json"
else
  echo "sprint-status: FAIL — cannot find schemas/sprint-status.json (the source of truth; this" >&2
  echo "  script has no built-in copy and will not guess). Looked in $SCRIPT_DIR/../schemas/ and" >&2
  echo "  $ROOT_DEFAULT/.claude/schemas/." >&2
  exit 1
fi

MODE=""; FILE=""; PROJECT_ROOT=""; SPRINT=""; NAME=""; VARIANT=""; INTENSITY=""; EVIDENCE=""; CLOSED_AT=""; RETRO_DOC=""

case "${1:-}" in
  --render)   MODE="render"; shift ;;
  --check)    MODE="check"; FILE="${2:-}"; shift 2 2>/dev/null || shift ;;
  sprint-id)  MODE="sprint-id"; shift ;;
  roll)       MODE="roll"; shift ;;
  close)      MODE="close"; shift ;;
  "")         echo "usage: sprint-status.sh --render | --check <file> | sprint-id | roll --sprint <N> | close --evidence <text>" >&2; exit 2 ;;
  *)          echo "sprint-status: unknown command '$1'" >&2; exit 2 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
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

MODE="$MODE" FILE="$FILE" SCHEMA="$SCHEMA" PROJECT_ROOT="$PROJECT_ROOT" \
SPRINT="$SPRINT" NAME="$NAME" VARIANT="$VARIANT" INTENSITY="$INTENSITY" \
EVIDENCE="$EVIDENCE" CLOSED_AT="$CLOSED_AT" RETRO_DOC="$RETRO_DOC" python3 - <<'PY'
import json, os, re, sys
from pathlib import Path

mode   = os.environ["MODE"]
schema = json.loads(Path(os.environ["SCHEMA"]).read_text())
root   = Path(os.environ["PROJECT_ROOT"])

KEYS       = schema["keys"]
SPRINT_RE  = re.compile(KEYS["sprint_re"],       re.M)
STATUS_RE  = re.compile(KEYS["status_re"],       re.M)
HOUSE_RE   = re.compile(KEYS["housekeeping_re"], re.M)

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

def archive_dir(view):
    return VIEWS[view].parent / "sprint-status"

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
    d = archive_dir(view)
    if not d.is_dir():
        return None
    ns = []
    for f in d.glob("sprint-*.yaml"):
        m = re.match(r"^sprint-([0-9]+)\.yaml$", f.name)
        if m:
            ns.append(int(m.group(1)))
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

        frozen = archive_dir(view) / ("sprint-%d.yaml" % sprint)
        if frozen.is_file():
            if frozen.read_text() != text:
                fail("%s: %s already exists and DIFFERS from the canonical it would freeze. A "
                     "partial close was completed by hand, or the archive was edited. Refusing to "
                     "overwrite — reconcile by hand." % (view, frozen), code=3)
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
else:
    fail("unknown mode '%s'" % mode, code=2)
PY
