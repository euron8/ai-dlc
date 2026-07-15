#!/usr/bin/env bash
# sync-taught-schema.sh — render every taught example from the ONE schema, and prove
# no hand-written copy of it survives anywhere.
#
# Usage:
#   ./scripts/sync-taught-schema.sh            # rewrite the generated regions in place
#   ./scripts/sync-taught-schema.sh --check    # fail if any region is stale or hand-written
#
# Exit: 0 = every taught example is rendered from the schema and current.
#       1 = a region drifted, or a provenance example exists that was not rendered from here.
#
# WHY THIS EXISTS.
#
# SKILL_INVOCATION_PROVENANCE v1 was described in three places at once: a regex in the
# reader, an example in the spec, an example in the role file the agent actually reads.
# Nothing compared them. They diverged. The role file taught a bare ``` fence with no
# terminator; the adversary emitted exactly what it was shown; the reader's regex matched
# nothing; the validator printed "no provenance block required or present" and exited 0.
# Two adversarial passes of the reference consumer's sprint 290 went unadjudicated and the
# gate called them clean, because an unparseable block scores exactly like a clean artifact.
#
# The fixtures could not catch it: check-17-bypass HAND-AUTHORS its own well-formed blocks,
# so the fixture and the reader agreed with each other and BOTH disagreed with the role file.
# The one artifact the LLM actually reads was the one artifact nothing validated.
#
# THE CURE IS NOT A DRIFT DETECTOR. It is having nothing to detect. There is one definition
# (core/schemas/provenance-block.json); the reader loads it; every example an agent is taught
# is RENDERED from it into a generated region. Drift is not caught here — it is made
# unrepresentable. This script's --check mode is what keeps it that way, and it enforces two
# invariants, the second of which is the one that actually matters:
#
#   1. Every generated region matches what the schema renders today.
#   2. NO provenance example exists in an agent-read file OUTSIDE a generated region.
#
# Invariant 2 is the load-bearing one. Without it, the next author hand-writes one more
# example beside the generated one and we are back to three copies with a fresh coat of paint.

set -uo pipefail

MODE="sync"
[ "${1:-}" = "--check" ] && MODE="check"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Two layouts, and the script must work in both:
#   distribution — core/scripts/  alongside core/schemas/,  core/skills/,  core/team-roles/
#   consumer     — scripts/       alongside .claude/schemas/, .claude/skills/, .claude/team-roles/
# In the distribution ROOT is core/; in a consumer ROOT is the repo root. Resolve relative to
# the SCRIPT's own directory, which is the one thing true in both.
if [ -f "$SCRIPT_DIR/../schemas/provenance-block.json" ]; then
    SCHEMA="$(cd "$SCRIPT_DIR/../schemas" && pwd)/provenance-block.json"
    DOC_DIRS=("$ROOT/skills" "$ROOT/team-roles")
elif [ -f "$ROOT/.claude/schemas/provenance-block.json" ]; then
    SCHEMA="$ROOT/.claude/schemas/provenance-block.json"
    DOC_DIRS=("$ROOT/.claude/skills" "$ROOT/.claude/team-roles")
else
    echo "sync-taught-schema: FAIL — cannot find schemas/provenance-block.json." >&2
    echo "  The schema is the source of truth; this script has no built-in copy and will not" >&2
    echo "  guess. Looked in: $SCRIPT_DIR/../schemas/ and $ROOT/.claude/schemas/" >&2
    exit 1
fi

EXISTING_DIRS=()
for d in "${DOC_DIRS[@]}"; do [ -d "$d" ] && EXISTING_DIRS+=("$d"); done
if [ ${#EXISTING_DIRS[@]} -eq 0 ]; then
    echo "sync-taught-schema: no agent-read directories; nothing to render." >&2
    exit 0
fi

# The verdict schema ships beside the provenance schema and is taught the same way (rendered,
# never hand-written). Resolve it from the same directory; fail closed if it is missing —
# they install as a set, and a reader that guesses one of them is the drift this design removed.
SCHEMA_DIR="$(cd "$(dirname "$SCHEMA")" && pwd)"
VERDICT_SCHEMA="$SCHEMA_DIR/gate-adjudication-verdict.json"
if [ ! -f "$VERDICT_SCHEMA" ]; then
    echo "sync-taught-schema: FAIL — gate-adjudication-verdict.json not found beside" >&2
    echo "  provenance-block.json in $SCHEMA_DIR. The two taught schemas ship as a set." >&2
    exit 1
fi

python3 - "$MODE" "$SCHEMA" "$VERDICT_SCHEMA" "$ROOT" "${EXISTING_DIRS[@]}" <<'PYEOF'
import json
import os
import re
import sys

mode, prov_path, verdict_path, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
doc_dirs = sys.argv[5:]

with open(prov_path, "r", encoding="utf-8") as fh:
    P = json.load(fh)
with open(verdict_path, "r", encoding="utf-8") as fh:
    G = json.load(fh)


def render_provenance(S, profile_name):
    """Render one provenance taught example from the schema. Byte-identical to the original
    renderer — the ONLY place a provenance example is made."""
    ENV = S["envelope"]
    FIELDS = {f["name"]: f for f in S["fields"]}
    ORDER = [f["name"] for f in S["fields"]]
    prof = S["profiles"][profile_name]
    names = ORDER if prof.get("fields") == "*" else prof["fields"]
    pin = prof.get("pin", {})

    lines = ["```", ENV["open"]]
    for name in names:
        f = FIELDS[name]
        value = pin.get(name, f.get("placeholder", ""))
        doc = f.get("doc", "")
        line = f"{name}: {value}"
        if doc:
            line = f"{line}{' ' * max(1, 44 - len(line))}# {doc}"
        lines.append(line)
    lines.append(ENV["close"])
    lines.append("```")
    return "\n".join(lines)


def render_verdict(S, profile_name):
    """Render the verdict taught example — the schema's taught_example, as pretty JSON in a
    fence. One profile only ('example'); the shape lives in the schema, not here."""
    body = json.dumps(S["taught_example"], indent=2)
    return "```json\n" + body + "\n```"


# Each taught-schema KIND: its region slug, source filename, marker, loaded schema, render fn,
# and the set of legal profile names. The two invariants below run over every kind.
KINDS = [
    {
        "slug": "provenance-block",
        "source": "provenance-block.json",
        "marker": P["envelope"]["marker"],
        "schema": P,
        "render": render_provenance,
        "profiles": set(P["profiles"]),
    },
    {
        "slug": "gate-adjudication-verdict",
        "source": "gate-adjudication-verdict.json",
        "marker": G["envelope"]["marker"],
        "schema": G,
        "render": render_verdict,
        "profiles": {"example"},
    },
]
for k in KINDS:
    k["begin_re"] = re.compile(
        r"<!-- BEGIN GENERATED: " + re.escape(k["slug"]) + r"/(?P<profile>[a-z0-9-]+) — source: schemas/"
        + re.escape(k["source"]) + r"; do not edit by hand -->"
    )
    k["end_mark"] = f"<!-- END GENERATED: {k['slug']} -->"

md_files = []
for d in doc_dirs:
    for dirpath, _, names in os.walk(d):
        for n in sorted(names):
            if n.endswith(".md"):
                md_files.append(os.path.join(dirpath, n))
md_files.sort()

stale, rendered, written = [], 0, 0

# ---------------------------------------------------------------- invariant 1: regions current
for path in md_files:
    with open(path, "r", encoding="utf-8") as fh:
        content = fh.read()
    if "BEGIN GENERATED: " not in content:
        continue

    changed = False
    for k in KINDS:
        if f"BEGIN GENERATED: {k['slug']}/" not in content:
            continue
        out, cursor = [], 0
        for m in k["begin_re"].finditer(content):
            profile = m.group("profile")
            if profile not in k["profiles"]:
                print(
                    f"FAIL  {os.path.relpath(path, root)}: unknown {k['slug']} profile "
                    f"'{profile}'. Known: {sorted(k['profiles'])}",
                    file=sys.stderr,
                )
                sys.exit(1)
            end = content.find(k["end_mark"], m.end())
            if end == -1:
                print(
                    f"FAIL  {os.path.relpath(path, root)}: a BEGIN GENERATED region for "
                    f"'{k['slug']}/{profile}' is never closed with '{k['end_mark']}'.",
                    file=sys.stderr,
                )
                sys.exit(1)

            current = content[m.end():end].strip("\n")
            want = k["render"](k["schema"], profile)
            rendered += 1
            if current != want:
                changed = True
                stale.append((os.path.relpath(path, root), f"{k['slug']}/{profile}", k["source"]))
            out.append(content[cursor:m.end()])
            out.append("\n" + want + "\n")
            cursor = end
        out.append(content[cursor:])
        content = "".join(out)

    if changed and mode == "sync":
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
        written += 1

# ------------------------------------------- invariant 2: no hand-written example survives
# The one that matters. A generated region beside a hand-written one is three copies again.
FENCE_RE = re.compile(r"^```[^\n]*\n(.*?)^```", re.DOTALL | re.MULTILINE)
handwritten = []

for path in md_files:
    with open(path, "r", encoding="utf-8") as fh:
        content = fh.read()

    # All generated-region spans, of every kind, are exempt: those ARE the schema.
    spans = []
    for k in KINDS:
        for m in k["begin_re"].finditer(content):
            end = content.find(k["end_mark"], m.end())
            if end != -1:
                spans.append((m.start(), end + len(k["end_mark"])))

    def inside_generated(pos):
        return any(a <= pos < b for a, b in spans)

    for k in KINDS:
        if k["marker"] not in content:
            continue
        for m in FENCE_RE.finditer(content):
            if k["marker"] not in m.group(1):
                continue
            if inside_generated(m.start()):
                continue
            line_no = content[: m.start()].count("\n") + 1
            handwritten.append((os.path.relpath(path, root), line_no, k["slug"], k["source"], sorted(k["profiles"])))

# ---------------------------------------------------------------------------- report
rc = 0

if mode == "check":
    for rel, profile, source in stale:
        print(
            f"FAIL  {rel}: the generated '{profile}' example is STALE — it does not match "
            f"what schemas/{source} renders today.\n"
            f"      FIX: run scripts/sync-taught-schema.sh (no arguments). Do not hand-edit "
            f"the region; the schema is the source.",
            file=sys.stderr,
        )
        rc = 1

for rel, line_no, slug, source, profiles in handwritten:
    print(
        f"FAIL  {rel}:{line_no}: a HAND-WRITTEN {slug} example.\n"
        f"      Every taught example must be RENDERED from schemas/{source} into "
        f"a generated region, because a hand-written copy is a copy that can drift — and when "
        f"this pattern first drifted, the reader silently parsed nothing and the gate called two "
        f"unadjudicated passes clean.\n"
        f"      FIX: replace it with\n"
        f"        <!-- BEGIN GENERATED: {slug}/<profile> — source: schemas/{source}; do not edit by hand -->\n"
        f"        <!-- END GENERATED: {slug} -->\n"
        f"      and run scripts/sync-taught-schema.sh. Profiles: {profiles}",
        file=sys.stderr,
    )
    rc = 1

if rc != 0:
    print("", file=sys.stderr)
    print("sync-taught-schema: FAIL — the taught schema and the read schema are not the same schema.", file=sys.stderr)
    sys.exit(1)

if mode == "sync":
    print(
        f"sync-taught-schema: rendered {rendered} example(s) from the taught schemas; "
        f"{written} file(s) updated."
    )
else:
    print(
        f"sync-taught-schema: PASS — {rendered} taught example(s), all rendered from "
        f"their schemas; 0 hand-written."
    )
PYEOF
