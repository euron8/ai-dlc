#!/usr/bin/env bash
# stamp-story-provenance.sh — the MECHANICAL WRITER of the terminal-pass residue on story files.
#
# Usage: ./scripts/stamp-story-provenance.sh --terminal <terminal-adversarial-pass-file> \
#          <story-file> [<story-file> ...]
#        ./scripts/stamp-story-provenance.sh --terminal <pass> --check <story-file> ...
#
# Check 17's story-readiness gate REQUIRES a SKILL_INVOCATION_PROVENANCE block on EVERY story
# file (validate-provenance-block.sh --require-skill ai-dlc-adversary-review, per story). That
# block used to be TRANSCRIBED ONTO the story BY HAND, "per the S290/S291 precedent" — and it
# drifted exactly as a hand-copied schema always does: sprint 291's stories dropped artifact_sha,
# sprint 292's kept it, and each carried a different free-text `#` comment the parser silently
# ignores. A mandated, machine-READ artifact with a precedent-AUTHORED write side.
#
# This is the write side, made mechanical. Every batch-invariant field
# (skill/invoked_at/tool_use_id/mode/lead_role/findings_*/verdict) is COPIED VERBATIM from the
# terminal pass — the single source of truth for what the convergence cycle concluded. The only
# per-story fields are `artifact` (the story path) and `artifact_sha` (computed here). Nothing is
# authored; the lead invents nothing. Re-running is idempotent: the sha is taken over the story
# BODY with any existing provenance block stripped, so a stamp never notarizes itself.
#
# THE SCHEMA IS NOT IN THIS FILE. Envelope, field order, and the `story-provenance` profile are
# loaded from schemas/provenance-block.json — the same file validate-provenance-block.sh (the
# reader) and validate-story-provenance.sh (the cross-check) load. Add a field to the profile
# there and it appears in the writer, the reader, and the cross-check at once.
#
# SAFETY: refuses to stamp unless the terminal pass is EXIT_CONDITION_MET. Stamping a story with
# an unconverged verdict would notarize a cycle that has not closed — the opposite of the
# gate's intent. Exit codes: 0 wrote (or --check: all current); 1 error / --check drift; 2 usage.

set -u

TERMINAL=""
SERIES=""
TOOL_USE_ID=""
CHECK_ONLY="no"
STORIES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --terminal) TERMINAL="${2:-}"; shift 2 ;;
        --series)   SERIES="${2:-}"; shift 2 ;;
        --tool-use-id) TOOL_USE_ID="${2:-}"; shift 2 ;;
        --check)    CHECK_ONLY="yes"; shift ;;
        --) shift; while [[ $# -gt 0 ]]; do STORIES+=("$1"); shift; done ;;
        -*) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
        *)  STORIES+=("$1"); shift ;;
    esac
done

# --series <prefix> resolves the TERMINAL pass itself — the highest p<N> in the series — so the
# gate names "the terminal pass" the ONE way Check 24 already does (--series <path-prefix>), and
# neither the gate nor the lead re-derives "which pass is last." Highest p-number wins; a series
# with a gap or a dead-cycle tail is Check 24's problem, not this writer's.
if [[ -n "$SERIES" && -z "$TERMINAL" ]]; then
    best_n=-1
    for f in "${SERIES}"*p[0-9]*.md; do
        [[ -e "$f" ]] || continue
        n="$(printf '%s' "$f" | sed -nE 's/.*p([0-9]+)\.md$/\1/p')"
        [[ -n "$n" ]] || continue
        if (( n > best_n )); then best_n="$n"; TERMINAL="$f"; fi
    done
    if [[ -z "$TERMINAL" ]]; then
        echo "ERROR: --series '$SERIES' matched no <prefix>...p<N>.md pass file." >&2
        exit 1
    fi
fi

if [[ -z "$TERMINAL" || ${#STORIES[@]} -eq 0 ]]; then
    echo "usage: ./scripts/stamp-story-provenance.sh (--terminal <pass-file> | --series <prefix>) [--check] <story-file>..." >&2
    exit 2
fi
[[ -f "$TERMINAL" ]] || { echo "ERROR: terminal pass file not found: $TERMINAL" >&2; exit 1; }

SP_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SP_ROOT="$(cd "$SP_SCRIPT_DIR/.." && pwd)"

SCHEMA=""
for cand in \
    "$SP_ROOT/core/schemas/provenance-block.json" \
    "$SP_ROOT/.claude/schemas/provenance-block.json" \
    "$SP_SCRIPT_DIR/../schemas/provenance-block.json"; do
    [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done
if [ -z "$SCHEMA" ]; then
    echo "FAIL: schemas/provenance-block.json not found. The schema is the source of truth;" >&2
    echo "      this writer has no built-in copy and will not guess. Reinstall ai-dlc." >&2
    exit 1
fi

python3 - "$SCHEMA" "$TERMINAL" "$CHECK_ONLY" "$TOOL_USE_ID" "${STORIES[@]}" <<'PYEOF'
import hashlib
import json
import re
import sys

schema_path = sys.argv[1]
terminal_path = sys.argv[2]
check_only = sys.argv[3] == "yes"
tool_use_id_override = sys.argv[4] or None
story_paths = sys.argv[5:]

with open(schema_path, "r", encoding="utf-8") as fh:
    S = json.load(fh)

ENV = S["envelope"]
OPEN, CLOSE, MARKER = ENV["open"], ENV["close"], ENV["marker"]
PROFILE = S["profiles"]["story-provenance"]
ORDER = PROFILE["fields"]
PIN = PROFILE.get("pin", {})
REQUIRE = set(PROFILE.get("require", []))
PER_STORY = set(PROFILE.get("per_story", []))

BLOCK_RE = re.compile(re.escape(OPEN) + r"\s*\n(.*?)\n\s*" + re.escape(CLOSE), re.DOTALL)
# A whole envelope (open..close), used to STRIP existing blocks before hashing/rewriting.
WHOLE_RE = re.compile(re.escape(OPEN) + r".*?" + re.escape(CLOSE), re.DOTALL)
MARKER_RE = re.compile(re.escape(MARKER))


def parse_block(text):
    """Mirror validate-provenance-block.sh's parser: flat key: value, indented continuation,
    whole-line and trailing ' #' comments stripped."""
    fields, last = {}, None
    for raw in text.splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        if re.match(r"^\s+", raw) and last is not None:
            fields[last] = f"{fields[last]} {s}".strip()
            continue
        m = re.match(r"^([a-z_]+):\s*(.*?)\s*$", raw)
        if not m:
            return None
        k, v = m.group(1), re.sub(r"\s+#.*$", "", m.group(2)).strip()
        fields[k] = v
        last = k
    return fields


def body_sha(text):
    """sha256 over the story BODY: every provenance block removed, trailing whitespace of the
    remainder normalized to a single final newline. Writer and cross-check MUST agree byte-for-byte,
    so the normalization lives in one function copied verbatim into both."""
    stripped = WHOLE_RE.sub("", text)
    stripped = stripped.rstrip() + "\n"
    return hashlib.sha256(stripped.encode("utf-8")).hexdigest()


# --- read the terminal pass (the single source of truth) ---
with open(terminal_path, "r", encoding="utf-8") as fh:
    tcontent = fh.read()
tblocks = BLOCK_RE.findall(tcontent)
if not tblocks:
    extra = " (a MARKER is present but unparseable — malformed envelope)" if MARKER_RE.search(tcontent) else ""
    print(f"FAIL: terminal pass {terminal_path} carries no parseable provenance block{extra}.", file=sys.stderr)
    sys.exit(1)
tfields = parse_block(tblocks[-1])
if tfields is None:
    print(f"FAIL: terminal pass {terminal_path}'s provenance block is malformed.", file=sys.stderr)
    sys.exit(1)

if tfields.get("skill") != PIN["skill"]:
    print(f"FAIL: terminal pass cites skill '{tfields.get('skill')}', expected '{PIN['skill']}'.", file=sys.stderr)
    sys.exit(1)
if tfields.get("verdict") != "EXIT_CONDITION_MET":
    print(
        f"FAIL: terminal pass verdict is '{tfields.get('verdict')}', not EXIT_CONDITION_MET. "
        f"Refusing to stamp: a story residue must notarize a CONVERGED cycle. Run more passes "
        f"(or resolve the hard block) until the terminal pass is EXIT_CONDITION_MET, then re-stamp.",
        file=sys.stderr,
    )
    sys.exit(1)

# The batch-invariant values, copied verbatim from the terminal pass.
invariant = {k: tfields[k] for k in PROFILE["batch_invariant"] if k in tfields and tfields[k] != ""}

# tool_use_id is the one batch-invariant field the terminal pass often CANNOT self-report: a
# subagent cannot observe the Agent tool_use_id that spawned it, so the pass file may carry a
# placeholder until it is recovered from the session transcript. Copying that placeholder onto
# every story would stamp a schema-INVALID block (and the reader would reject it downstream). So:
# validate the value against the schema's tool_use_id pattern; an explicit --tool-use-id override
# wins (a single verifiable token, recovered from the transcript — the sanctioned mitigation); and
# if neither the pass file nor the override yields a real toolu_ id, REFUSE rather than propagate a
# placebo. The cure belongs in the SoR: backfill the terminal pass's tool_use_id, then re-stamp.
TID_RE = S["patterns"]["tool_use_id"]
tid = tool_use_id_override or invariant.get("tool_use_id", "")
if not re.match(TID_RE, tid):
    src = "the --tool-use-id override" if tool_use_id_override else f"terminal pass {terminal_path}"
    print(
        f"FAIL: tool_use_id from {src} is not a valid toolu_ id ({tid!r}). The terminal pass could "
        f"not self-report its Agent-dispatch id (the tool_use_id self-introspection defect), so the "
        f"SoR still holds a placeholder. Recover the terminal Agent-dispatch tool_use_id from the "
        f"session transcript and either backfill it into {terminal_path} or pass it as "
        f"--tool-use-id <toolu_...>. Refusing to stamp a placeholder onto the stories.",
        file=sys.stderr,
    )
    sys.exit(1)
invariant["tool_use_id"] = tid

# If the SoR (terminal pass) still held a placeholder and we were handed the recovered id, correct
# the SoR ONCE — backfill the pass file's tool_use_id line inside its block. This mechanizes the
# hand-recovery the lead does today, and it is what lets the gate's --check run override-free: after
# a real stamp the pass file holds the real id, so --check re-derives it with nothing threaded in.
if not check_only and tfields.get("tool_use_id") != tid:
    def _backfill(m):
        return re.sub(r"(?m)^tool_use_id:.*$", f"tool_use_id: {tid}", m.group(0), count=1)
    new_tcontent = WHOLE_RE.sub(_backfill, tcontent, count=1)
    if new_tcontent != tcontent:
        with open(terminal_path, "w", encoding="utf-8") as fh:
            fh.write(new_tcontent)
        print(f"  backfilled tool_use_id in the terminal pass (SoR): {terminal_path}")


def render(story_path, sha):
    vals = dict(invariant)
    vals["artifact"] = story_path
    vals["artifact_sha"] = sha
    lines = [OPEN]
    for name in ORDER:
        if name in PER_STORY:
            lines.append(f"{name}: {vals[name]}")
        elif name in vals:
            lines.append(f"{name}: {vals[name]}")
    lines.append(CLOSE)
    return "\n".join(lines)


drift = []
wrote = []
for sp in story_paths:
    try:
        with open(sp, "r", encoding="utf-8") as fh:
            content = fh.read()
    except OSError as exc:
        print(f"FAIL: cannot read story file {sp}: {exc}", file=sys.stderr)
        sys.exit(1)

    sha = body_sha(content)
    block = render(sp, sha)
    body = WHOLE_RE.sub("", content).rstrip() + "\n"
    new_content = body + "\n" + block + "\n"

    if check_only:
        # Missing every required field, wrong value, or a stale sha all read as drift.
        if new_content != content:
            existing = BLOCK_RE.findall(content)
            cur = parse_block(existing[-1]) if existing else None
            why = "no provenance block" if not existing else (
                "block does not match the mechanically-derived one "
                "(fields differ from the terminal pass, or artifact_sha is stale)"
            )
            drift.append(f"  - {sp}: {why}")
        continue

    if new_content != content:
        with open(sp, "w", encoding="utf-8") as fh:
            fh.write(new_content)
        wrote.append(sp)

if check_only:
    if drift:
        print("STAMP-STORY-PROVENANCE --check: DRIFT", file=sys.stderr)
        for d in drift:
            print(d, file=sys.stderr)
        sys.exit(1)
    print(f"STAMP-STORY-PROVENANCE --check: OK ({len(story_paths)} story file(s) current)")
    sys.exit(0)

print(
    f"STAMP-STORY-PROVENANCE: stamped {len(wrote)} of {len(story_paths)} story file(s) "
    f"from {terminal_path} (verdict {tfields.get('verdict')}); "
    f"{len(story_paths) - len(wrote)} already current."
)
for w in wrote:
    print(f"  wrote {w}")
sys.exit(0)
PYEOF
