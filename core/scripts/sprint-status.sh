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
#   4  — check-stories only: NOTHING WAS COMPARED (no canonical on disk, or no `stories:` key in
#        the sprint that is live). Its own code, never folded into 0, because "compared nothing"
#        and "compared and found no drift" are the two states every consumer implementation of
#        this check conflated. Check 5's prose decides which is acceptable: at an implementation
#        gate a 4 FAILS (a sprint in flight with no story entries), at a planning-phase gate it is
#        the exemption that check already states.
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
  "")         echo "usage: sprint-status.sh --render | --check <file> | sprint-id | roll --sprint <N> | close --evidence <text> | check-stories [--sprint <N>]" >&2; exit 2 ;;
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
STORIES_RE = re.compile(KEYS["stories_re"])
STORY_KEY_RE   = re.compile(KEYS["story_key_re"])
STORY_FIELD_RE = re.compile(KEYS["story_field_re"])

SFILE       = schema["story_file"]
STORIES_DIR = SFILE["stories_dir"]
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


def resolve_story_file(view_path, key, declared):
    """First candidate that exists, never a single guessed path. The two canonicals sit in
    DIFFERENT directories and both name the story corpus with the same relative `file:` value, so
    resolving relative to the canonical alone finds the corpus from one view and nothing from the
    other."""
    stories = root / STORIES_DIR
    cands = []
    if declared:
        d = Path(declared)
        if d.is_absolute():
            cands.append(d)
        else:
            cands.append(view_path.parent / declared)
            cands.append(root / Path(STORIES_DIR).parent / declared)
            cands.append(root / declared)
            cands.append(stories / d.name)
    # The entry key IS the story id. Exact file first, then `<id>-<slug>.md` — never `<id>*` , which
    # matches story-289-10 for story-289-1.
    cands.append(stories / (key + ".md"))
    for c in cands:
        if c.is_file():
            return c
    hits = sorted(stories.glob(key + "-*.md")) if stories.is_dir() else []
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
            resolved = resolve_story_file(p, key, fields.get("file"))
            if resolved is None:
                findings.append("[%s/%s] names no readable story file (declared `file: %s`; also "
                                "looked for %s/%s.md and %s/%s-*.md)."
                                % (view, key, fields.get("file", "<absent>"),
                                   STORIES_DIR, key, STORIES_DIR, key))
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
else:
    fail("unknown mode '%s'" % mode, code=2)
PY
