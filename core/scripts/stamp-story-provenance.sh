#!/usr/bin/env bash
# stamp-story-provenance.sh — the MECHANICAL WRITER of the terminal-pass residue on story files.
#
# Usage: ./scripts/ai-dlc/stamp-story-provenance.sh --terminal <terminal-adversarial-pass-file> \
#          <story-file> [<story-file> ...]
#        ./scripts/ai-dlc/stamp-story-provenance.sh --terminal <pass> --check <story-file> ...
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
# reader) loads, and the same file this script's own `--check` mode (the cross-check) re-reads.
# Add a field to the profile there and it appears in the writer, the reader, and the cross-check
# at once.
#
# SAFETY: refuses to stamp unless the terminal pass is EXIT_CONDITION_MET. Stamping a story with
# an unconverged verdict would notarize a cycle that has not closed — the opposite of the
# gate's intent. Exit codes: 0 wrote (or --check: all current); 1 error / --check drift; 2 usage.

set -u

# --profile selects which schema profile governs the stamp. Two ship:
#
#   story-provenance      (default) the CONVERGENCE cycle's terminal-pass residue. Pinned to
#                         ai-dlc-adversary-review, and `verdict` is batch-invariant, so the
#                         EXIT_CONDITION_MET guard below applies exactly as it always has.
#   bug-story-provenance  the ONE-SHOT residue for a bug-fix story. Pinned to
#                         bmad-review-adversarial-general, and carries NO `verdict` — a one-shot
#                         stamps none (team-roles/adversary.md; Check 24 self-skips
#                         bug-investigation for the same reason), so requiring EXIT_CONDITION_MET
#                         would demand a field the producer is forbidden to write.
#
# The guard is DERIVED from the profile, never from a flag: a profile whose batch_invariant
# carries `verdict` demands EXIT_CONDITION_MET, and one that does not REFUSES a terminal pass
# carrying a verdict at all. So neither door can be used to enter the other, and adding a third
# profile cannot silently inherit the wrong rule.
TERMINAL=""
SERIES=""
TOOL_USE_ID=""
CHECK_ONLY="no"
PROFILE_NAME="story-provenance"
PRINT_SCHEMA="no"
STORIES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --terminal) TERMINAL="${2:-}"; shift 2 ;;
        --series)   SERIES="${2:-}"; shift 2 ;;
        --profile)  PROFILE_NAME="${2:-}"; shift 2 ;;
        --tool-use-id) TOOL_USE_ID="${2:-}"; shift 2 ;;
        --check)    CHECK_ONLY="yes"; shift ;;
        # Print the schema this writer WOULD load, then exit. Diagnostic, and the reason it
        # exists: the install mapping splits the writer from the schema — core/scripts/<x> lands
        # at <root>/scripts/ai-dlc/<x> while core/schemas/ lands at <root>/.claude/schemas/ — so
        # "walk up from the writer" is right in the distribution and wrong on every consumer.
        # A caller that needs the schema path must not re-derive it; the chain below is the one
        # home for that answer, and a second copy is a resolver fork waiting to happen.
        --print-schema) PRINT_SCHEMA="yes"; shift ;;
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

if [[ "$PRINT_SCHEMA" != "yes" ]]; then
    if [[ -z "$TERMINAL" || ${#STORIES[@]} -eq 0 ]]; then
        echo "usage: ./scripts/ai-dlc/stamp-story-provenance.sh (--terminal <pass-file> | --series <prefix>) [--profile <name>] [--check] <story-file>... | --print-schema" >&2
        exit 2
    fi
    [[ -f "$TERMINAL" ]] || { echo "ERROR: terminal pass file not found: $TERMINAL" >&2; exit 1; }
fi

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
SP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SP_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$SP_ROOT" ] || SP_ROOT="$(ai_dlc_resolve_root "$SP_SCRIPT_DIR" || true)"
[ -n "$SP_ROOT" ] || SP_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$SP_ROOT" ] || SP_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$SP_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${SP_SCRIPT_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

SCHEMA=""
for cand in \
    "$SP_SCRIPT_DIR/../schemas/provenance-block.json" \
    "${SP_ROOT:-/nonexistent}/core/schemas/provenance-block.json" \
    "${SP_ROOT:-/nonexistent}/.claude/schemas/provenance-block.json"; do
    [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done
if [ -z "$SCHEMA" ]; then
    echo "FAIL: schemas/provenance-block.json not found. The schema is the source of truth;" >&2
    echo "      this writer has no built-in copy and will not guess. Reinstall ai-dlc." >&2
    exit 1
fi

if [[ "$PRINT_SCHEMA" == "yes" ]]; then
    printf '%s\n' "$SCHEMA"
    exit 0
fi

python3 - "$SCHEMA" "$TERMINAL" "$CHECK_ONLY" "$TOOL_USE_ID" "$PROFILE_NAME" "${STORIES[@]}" <<'PYEOF'
import hashlib
import json
import re
import sys

schema_path = sys.argv[1]
terminal_path = sys.argv[2]
check_only = sys.argv[3] == "yes"
tool_use_id_override = sys.argv[4] or None
profile_name = sys.argv[5]
story_paths = sys.argv[6:]

with open(schema_path, "r", encoding="utf-8") as fh:
    S = json.load(fh)

ENV = S["envelope"]
OPEN, CLOSE, MARKER = ENV["open"], ENV["close"], ENV["marker"]
if profile_name not in S["profiles"] or profile_name.startswith("$"):
    known = ", ".join(k for k in S["profiles"] if not k.startswith("$"))
    print(f"FAIL: --profile '{profile_name}' is not a profile in the schema. Known: {known}.", file=sys.stderr)
    sys.exit(2)
PROFILE = S["profiles"][profile_name]
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
# The verdict rule is DERIVED from the profile, not from a flag — see the --profile comment
# above. A profile carrying `verdict` in batch_invariant is a CONVERGENCE profile and demands
# EXIT_CONDITION_MET. A profile without it is a ONE-SHOT profile, where a verdict is a field the
# producer is forbidden to write, so a terminal pass carrying one is the WRONG pass: refuse it
# rather than drop the field, or a convergence pass could be laundered onto a story through the
# one-shot door with its verdict silently discarded.
if "verdict" in PROFILE.get("batch_invariant", []):
    if tfields.get("verdict") != "EXIT_CONDITION_MET":
        print(
            f"FAIL: terminal pass verdict is '{tfields.get('verdict')}', not EXIT_CONDITION_MET. "
            f"Refusing to stamp: a story residue must notarize a CONVERGED cycle. Run more passes "
            f"(or resolve the hard block) until the terminal pass is EXIT_CONDITION_MET, then re-stamp.",
            file=sys.stderr,
        )
        sys.exit(1)
elif tfields.get("verdict"):
    print(
        f"FAIL: profile '{profile_name}' is a ONE-SHOT profile and its terminal pass must carry no "
        f"verdict, but this one stamps '{tfields.get('verdict')}'. A verdict means a CONVERGENCE "
        f"pass was passed to the one-shot door; stamp it with the convergence profile instead.",
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
# if neither the pass file nor the override yields a WELL-FORMED toolu_ id, REFUSE rather than
# propagate a placebo. The cure belongs in the SoR: backfill the terminal pass's tool_use_id, then
# re-stamp.
#
# WHAT THIS DOES NOT DO. The test below is the schema's charset pattern and nothing more, so it
# catches the placeholder SHAPES the pattern already excludes (empty, `toolu_`, `toolu_...`, and
# every marker shorter than six chars) and does NOT catch a well-formed invention such as
# `toolu_PLACEHOLDER` or `toolu_aaaaaaaa`. Nothing here — or in the reader — checks the id against
# a transcript, so neither side can tell a recovered id from a plausible one. Say "well-formed",
# never "real": this comment previously claimed the latter, which is how a shape check comes to be
# trusted as proof. Binding the id to a cited transcript — the way transcript_path is bound by
# validate-retro-evidence.sh — is the only thing that would make it evidence.
TID_RE = S["patterns"]["tool_use_id"]
tid = tool_use_id_override or invariant.get("tool_use_id", "")
if not re.match(TID_RE, tid):
    src = "the --tool-use-id override" if tool_use_id_override else f"terminal pass {terminal_path}"
    print(
        f"FAIL: tool_use_id from {src} is not a valid toolu_ id ({tid!r}). The terminal pass could "
        f"not self-report its Agent-dispatch id (the tool_use_id self-introspection defect), so the "
        f"SoR still holds a placeholder. Recover the terminal Agent-dispatch tool_use_id from the "
        f"session transcript and either backfill it into {terminal_path} or pass it as "
        f"--tool-use-id <toolu_...>. Refusing to stamp a malformed id onto the stories.",
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
    # A one-shot profile has no verdict, and printing Python's `None` there reads as a field
    # that failed to parse rather than one that correctly does not exist.
    f"from {terminal_path} "
    f"({'verdict ' + tfields['verdict'] if tfields.get('verdict') else 'one-shot, no verdict'}); "
    f"{len(story_paths) - len(wrote)} already current."
)
for w in wrote:
    print(f"  wrote {w}")
sys.exit(0)
PYEOF
