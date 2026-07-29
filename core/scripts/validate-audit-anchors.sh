#!/usr/bin/env bash
# validate-audit-anchors.sh — the READER + RENDERER of the audit-anchors housekeeping schema.
#
# THE SCHEMA IS NOT IN THIS FILE. It is in schemas/audit-anchors.json, which this script LOADS:
# the entry field list, their patterns, and the header text all come from there. Adding a field
# there reaches the rendered header and this entry validator at once.
#
# It used to be otherwise: the schema was described in templates/audit-anchors.md.template (a
# canonical the installer never shipped) AND in each project's live _bmad-output/audit-anchors.md
# header (a hand-carried copy the retro reads). Nothing compared them; they diverged (the live
# header grew `audit_window` + a YAML list, the template stayed on `---` docs + `notes`). The
# de-facto schema survived only in whichever file was carried forward. This removes the second
# copy: the header is RENDERED from the schema and byte-checked; entries are validated against it.
#
# Usage:
#   validate-audit-anchors.sh --render            # print the canonical BEGIN/END GENERATED header
#   validate-audit-anchors.sh --check <file>      # fail if <file>'s header region is missing/stale
#   validate-audit-anchors.sh --entries <file>    # validate ONLY the entries (skip the header)
#   validate-audit-anchors.sh <file>              # validate entries AND the header region
#   validate-audit-anchors.sh --trunk-push        # pre-push: bound the Step 5b backfill commit
#
# `--trunk-push` reads git's pre-push protocol on stdin and is the ONLY reader of the commit
# `retro.md` Step 5b licenses. Step 5b cannot route that commit through a PR — the retro-PR merge
# SHA is not knowable until the retro PR has merged — so it tells the lead to push straight to the
# trunk. Core wrote that licence and, until now, defined nothing about what it licenses. The bound
# is declared in the schema's `backfill_commit` block; this mode is what reads it. Trunk name from
# AI_DLC_TRUNK (default `main`), the same tunable validate-cycle-commits.sh takes.
#
# It bounds the licensed commit; it does not police the trunk. A commit that claims the Step 5b
# subject may touch only the declared path; a commit that rewrites that path alone must claim the
# subject. Everything else on a trunk push is core's business to leave alone — core states no
# branch policy, and the schema's own $fields_comment records what a linter that errors on real
# data on first contact costs.
#
# `--entries` is the CONSUMER-side check (gate-validation Check 18): it enforces the entry shape a
# reader depends on without requiring the header region, so a consumer whose file predates this
# schema is not wedged before its next retro re-seeds the header. `<file>` (full) is the
# PRODUCER-side check (retro Step 5c), run right after the header is re-seeded.
#
# Exit codes:
#   0  — the requested checks pass
#   1  — header drifted/missing, an entry is malformed, or the schema is unreadable (fail-closed)
#   2  — usage error
#
# Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — hence JSON, and a line parser for
# the flat YAML entry list).

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$SCRIPT_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
# --- end AI_DLC_ROOT --------------------------------------------------------

# Resolve the schema in both layouts (distribution core/schemas, consumer .claude/schemas), with
# an env override for tests. No built-in copy: if it cannot be found we fail closed, never guess.
# Script-relative first — that is the package THIS copy shipped in — then the resolved root.
if [ -n "${AI_DLC_AUDIT_ANCHORS_SCHEMA:-}" ] && [ -f "${AI_DLC_AUDIT_ANCHORS_SCHEMA}" ]; then
  SCHEMA="$AI_DLC_AUDIT_ANCHORS_SCHEMA"
elif [ -f "$SCRIPT_DIR/../schemas/audit-anchors.json" ]; then
  SCHEMA="$(cd "$SCRIPT_DIR/../schemas" && pwd)/audit-anchors.json"
elif [ -n "$AI_DLC_ROOT" ] && [ -f "$AI_DLC_ROOT/core/schemas/audit-anchors.json" ]; then
  SCHEMA="$AI_DLC_ROOT/core/schemas/audit-anchors.json"
elif [ -n "$AI_DLC_ROOT" ] && [ -f "$AI_DLC_ROOT/.claude/schemas/audit-anchors.json" ]; then
  SCHEMA="$AI_DLC_ROOT/.claude/schemas/audit-anchors.json"
else
  echo "validate-audit-anchors: FAIL — cannot find schemas/audit-anchors.json (the source of truth;" >&2
  echo "  this script has no built-in copy and will not guess). Looked in $SCRIPT_DIR/../schemas/" >&2
  echo "  and ${AI_DLC_ROOT:-<unresolved project root>}/{core,.claude}/schemas/." >&2
  exit 1
fi

MODE="validate"; FILE=""
case "${1:-}" in
  --render)     MODE="render" ;;
  --check)      MODE="check";   FILE="${2:-}" ;;
  --entries)    MODE="entries"; FILE="${2:-}" ;;
  --trunk-push) MODE="trunk-push" ;;
  "" )       echo "usage: validate-audit-anchors.sh --render | --check <file> | --entries <file> | --trunk-push | <file>" >&2; exit 2 ;;
  --*)       echo "validate-audit-anchors: unknown option '$1'" >&2; exit 2 ;;
  *)         MODE="validate"; FILE="$1" ;;
esac
case "$MODE" in render|trunk-push) ;; *)
  if [ -z "$FILE" ]; then
    echo "usage: validate-audit-anchors.sh --render | --check <file> | <file>" >&2; exit 2
  fi
  if [ ! -r "$FILE" ]; then
    echo "validate-audit-anchors: FAIL — cannot read '$FILE'" >&2; exit 1
  fi ;;
esac

command -v python3 >/dev/null 2>&1 || { echo "validate-audit-anchors: FAIL — python3 required" >&2; exit 1; }

# The analysis below is fed to python3 ON STDIN (`python3 - <<PY`), so the ref protocol has to be
# drained HERE or the mode reads the heredoc's leftovers — which is to say nothing at all, every
# time, on every push. Carried in an accumulating variable rather than a temp file: installing an
# EXIT trap in a reconcile-adjacent script once turned silent SIGPIPEs into 90 lines of
# `printf: write error: Broken pipe` from pipelines the change never touched.
REFS=""
[ "$MODE" = "trunk-push" ] && REFS="$(cat)"

MODE="$MODE" FILE="$FILE" SCHEMA="$SCHEMA" TRUNK="${AI_DLC_TRUNK:-main}" REFS="$REFS" python3 - <<'PY'
import json, os, re, subprocess, sys

mode   = os.environ["MODE"]
schema_path = os.environ["SCHEMA"]
file_path   = os.environ.get("FILE", "")

# --- load the schema, fail closed on anything malformed (never degrade to no-schema) ----------
try:
    with open(schema_path) as f:
        schema = json.load(f)
    fields   = schema["fields"]
    header   = schema["header_lines"]
    label    = schema["region_label"]
    assert isinstance(fields, dict) and isinstance(header, list) and isinstance(label, str)
except Exception as e:
    sys.stderr.write(f"validate-audit-anchors: FAIL — schema {schema_path} is unreadable/malformed: {e}\n")
    sys.exit(1)

BEGIN = (f"<!-- BEGIN GENERATED: {label} — source: schemas/audit-anchors.json; "
         f"rendered by scripts/ai-dlc/validate-audit-anchors.sh --render; do not edit by hand -->")
END   = f"<!-- END GENERATED: {label} -->"

def render():
    return "\n".join([BEGIN, *header, END]) + "\n"

if mode == "render":
    sys.stdout.write(render())
    sys.exit(0)

# --- trunk-push: bound the one direct-to-trunk commit Step 5b licenses -----------------------
# Reads git's pre-push protocol on stdin ("<local ref> <local sha> <remote ref> <remote sha>").
# EVERY outcome states what it decided. A run that judged nothing says so in its own words and
# never borrows the passing wording — a mode wired somewhere stdin does not reach would otherwise
# report exactly what a clean push reports, which is this repo's named defect class.
if mode == "trunk-push":
    ZERO = "0" * 40
    trunk = os.environ.get("TRUNK", "main")
    trunk_ref = f"refs/heads/{trunk}"
    try:
        bc = schema["backfill_commit"]
        subject_pat = bc["subject_pattern"]
        allowed = set(bc["paths"])
        example = bc.get("subject_example", "")
        assert isinstance(subject_pat, str) and allowed
        re.compile(subject_pat)
    except Exception as e:
        sys.stderr.write(f"validate-audit-anchors: FAIL — schema {schema_path} has no usable "
                         f"'backfill_commit' block: {e}\n")
        sys.exit(1)

    def git(*args):
        r = subprocess.run(["git", *args], capture_output=True, text=True)
        return r.returncode, r.stdout

    refs = [ln.split() for ln in os.environ.get("REFS", "").splitlines() if ln.strip()]
    if not refs:
        # Not a pass. Say which question went unasked, in wording no passing run emits.
        print(f"--trunk-push: NO REF LINES ON STDIN — nothing was judged. This mode reads git's "
              f"pre-push protocol; reaching it with empty stdin means the caller is not a pre-push "
              f"hook (or the hook consumed stdin before this arm).")
        sys.exit(0)

    judged, findings, notes = 0, [], []
    for parts in refs:
        if len(parts) < 4:
            continue
        _local_ref, local_sha, remote_ref, remote_sha = parts[0], parts[1], parts[2], parts[3]
        if remote_ref != trunk_ref:
            continue
        if local_sha == ZERO:
            notes.append(f"{trunk}: branch deletion — no commits to judge")
            continue
        if remote_sha == ZERO:
            # graph's own guard takes the whole history here and blocks a first push of the
            # trunk outright. Core will not: with no remote tip there is no delta, and judging
            # every ancestor makes a fresh consumer's first push unlandable.
            notes.append(f"{trunk}: creating the remote ref — no prior tip, so there is no "
                         f"delta to judge (core does not judge the whole history here)")
            continue
        rc, _ = git("cat-file", "-e", f"{remote_sha}^{{commit}}")
        if rc != 0:
            notes.append(f"{trunk}: remote tip {remote_sha[:9]} is not present locally — "
                         f"range unjudgeable; fetch and re-push")
            continue
        rc, out = git("log", "--format=%H", f"{remote_sha}..{local_sha}")
        if rc != 0:
            notes.append(f"{trunk}: cannot walk {remote_sha[:9]}..{local_sha[:9]}")
            continue
        for sha in out.split():
            judged += 1
            _, subj = git("log", "-1", "--format=%s", sha)
            subj = subj.strip()
            _, names = git("diff-tree", "--no-commit-id", "--name-only", "-r", sha)
            paths = {p for p in names.split("\n") if p.strip()}
            claims = re.match(subject_pat, subj) is not None
            only_licensed = paths == allowed
            if claims and not only_licensed:
                extra = sorted(paths - allowed)
                findings.append(
                    f"  {sha[:9]} claims the Step 5b backfill subject while touching "
                    f"{len(extra)} path(s) outside it: {', '.join(extra[:4])}"
                    f"{' …' if len(extra) > 4 else ''}")
            elif only_licensed and not claims:
                findings.append(
                    f"  {sha[:9]} rewrites {', '.join(sorted(allowed))} alone on a direct push "
                    f"to {trunk}, under a subject Step 5b does not license: \"{subj}\"")

    for n in notes:
        print(f"--trunk-push: {n}")
    if findings:
        sys.stderr.write(
            f"validate-audit-anchors: FAIL — {len(findings)} commit(s) on the push to '{trunk}' "
            f"fall outside the one direct-to-trunk commit retro.md Step 5b licenses:\n")
        for f_ in findings:
            sys.stderr.write(f_ + "\n")
        sys.stderr.write(
            f"  The licensed commit edits {', '.join(sorted(allowed))} and nothing else, under:\n"
            f"    {example}\n"
            f"  Everything else reaches '{trunk}' through a PR (retro.md Step 6d).\n")
        sys.exit(1)
    if not judged and not notes:
        print(f"--trunk-push: PASS — this push does not target '{trunk}'")
    else:
        print(f"--trunk-push: PASS — {judged} commit(s) judged on the push to '{trunk}'")
    sys.exit(0)

# --- locate the generated region -------------------------------------------------------------
text = open(file_path).read()
end_idx = None
try:
    b = text.index(BEGIN)
    e = text.index(END, b) + len(END)
    end_idx = e
except ValueError:
    b = e = None

# `--check` and full `<file>` enforce the header region; `--entries` skips it (migration-safe:
# a consumer file predating this schema has no region yet and is not wedged before its retro).
if mode in ("check", "validate"):
    if end_idx is None:
        sys.stderr.write(
            f"validate-audit-anchors: FAIL — {file_path} has no '{label}' GENERATED header region.\n"
            f"  Re-seed it with: scripts/ai-dlc/validate-audit-anchors.sh --render\n")
        sys.exit(1)
    if text[b:e] + "\n" != render():
        sys.stderr.write(
            f"validate-audit-anchors: FAIL — {file_path}'s header region has drifted from the schema.\n"
            f"  It was hand-edited or the schema changed. Re-render: scripts/ai-dlc/validate-audit-anchors.sh --render\n")
        sys.exit(1)
    if mode == "check":
        sys.exit(0)

# --- validate / entries mode: check every entry against `fields` ------------------------------
# Parse the flat YAML entry list without PyYAML. An entry begins at a top-level "- key: value"
# line; subsequent indented "key: value" lines belong to it. When a region is present we parse
# only below it; otherwise the whole file (the header's "- `sprint:` ..." prose bullets start with
# a backtick, so they never match the entry regex either way).
def clean(v):
    # strip a trailing unquoted YAML "# comment" (whitespace + hash onward), then surrounding space
    return re.sub(r"\s+#.*$", "", v).strip()

body = text[end_idx:] if end_idx is not None else text
entries, cur = [], None
for raw in body.splitlines():
    line = raw.rstrip("\n")
    m = re.match(r"^-\s+([A-Za-z_]\w*):\s*(.*)$", line)          # start of a new entry
    if m:
        if cur is not None:
            entries.append(cur)
        cur = {}
        cur[m.group(1)] = clean(m.group(2))
        continue
    if cur is not None:
        m2 = re.match(r"^\s+([A-Za-z_]\w*):\s*(.*)$", line)      # a field of the current entry
        if m2:
            cur[m2.group(1)] = clean(m2.group(2))
        elif line.strip() == "" or line.strip() == "```":
            continue                                             # blanks / fence lines are fine
        else:
            entries.append(cur); cur = None                     # any other line ends the entry
if cur is not None:
    entries.append(cur)

errors = []
if not entries:
    errors.append("no entries found below the header (expected at least the bootstrap entry)")

for i, ent in enumerate(entries):
    tag = ent.get("sprint", f"#{i}")
    for name, spec in fields.items():
        val = ent.get(name)
        if val is None or val == "":
            if spec.get("required"):
                errors.append(f"entry sprint={tag}: missing required field '{name}' ({spec.get('desc','')})")
            continue
        pat = spec.get("pattern")
        if pat and not re.match(pat, val):
            errors.append(f"entry sprint={tag}: field '{name}'='{val}' does not match {pat}")

if errors:
    sys.stderr.write(f"validate-audit-anchors: FAIL — {file_path}:\n")
    for msg in errors:
        sys.stderr.write(f"  - {msg}\n")
    sys.exit(1)

sys.exit(0)
PY
