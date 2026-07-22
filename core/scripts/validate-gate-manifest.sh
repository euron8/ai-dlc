#!/usr/bin/env bash
set -euo pipefail

# validate-gate-manifest.sh — two-way resolve between the GATE_MANIFEST table and
# the `<!-- CHECK_LOADED: <id> -->` anchors in gate-validation.md.
#
# Gate-type slicing loads checks by gate type. A manifest ID with no matching
# anchor, or an anchor no manifest row claims, silently mis-slices a gate: the
# gate runs, reports PASS, and the missing check never fires.
#
# usage:
#   validate-gate-manifest.sh [<gate-validation.md>]
#
# exit 0 = both directions resolve
# exit 1 = MISSING or ORPHAN ids
# exit 2 = the scan could not be performed (usage, unreadable file, unparseable
#          manifest). Never degrades to a pass: a comparison of nothing reads
#          exactly like a clean resolve, which is the defect this file exists
#          to make impossible.
#
# Every id is DERIVED from the file. No check id is hard-coded here.

FILE="${1:-}"
if [ -z "$FILE" ]; then
  for c in ".claude/skills/ai-dlc/steps/gate-validation.md" \
           "core/skills/ai-dlc/steps/gate-validation.md"; do
    [ -f "$c" ] && { FILE="$c"; break; }
  done
fi
[ -n "$FILE" ] || {
  echo "usage: validate-gate-manifest.sh [<gate-validation.md>]" >&2
  echo "validate-gate-manifest: FAIL — no gate-validation.md found in either layout" >&2
  exit 2
}
[ -f "$FILE" ] || { echo "validate-gate-manifest: FAIL — cannot read '$FILE'" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "validate-gate-manifest: FAIL — python3 required" >&2; exit 2; }

python3 - "$FILE" <<'PY'
import re, sys

path = sys.argv[1]
src = open(path, encoding="utf-8", errors="replace").read()

anchors = re.findall(r"^<!-- CHECK_LOADED: (\S+) -->$", src, re.M)
if not anchors:
    sys.stderr.write(
        f"validate-gate-manifest: FAIL — no '<!-- CHECK_LOADED: <id> -->' anchors in {path}.\n"
        "  Every manifest id would report as MISSING and every anchor as absent; the\n"
        "  resolve would be a comparison against an empty set.\n")
    sys.exit(2)

start, end = src.find("GATE_MANIFEST v1"), src.find("GATE_MANIFEST_END")
if start < 0 or end < 0 or end <= start:
    sys.stderr.write(
        f"validate-gate-manifest: FAIL — no 'GATE_MANIFEST v1' … 'GATE_MANIFEST_END' region in {path}.\n")
    sys.exit(2)
block = src[start:end]

rows = re.findall(r"^\|[ ]*([a-z][a-z-]*)[ ]*\|([^|]*)\|", block, re.M)
if not rows:
    sys.stderr.write(
        "validate-gate-manifest: FAIL — GATE_MANIFEST parsed zero rows. The scan would\n"
        "  pass by comparing nothing.\n")
    sys.exit(2)
if not any(g == "universal" for g, _ in rows):
    sys.stderr.write(
        "validate-gate-manifest: FAIL — GATE_MANIFEST has no 'universal' row. The\n"
        "  always-loaded set would be unreadable and every universal check would\n"
        "  report as an orphan.\n")
    sys.exit(2)

ids = set()
for _, cell in rows:
    ids.update(t.strip() for t in cell.split(",") if t.strip())

missing = sorted(i for i in ids if i not in anchors)
orphan = sorted(a for a in set(anchors) if a not in ids)

print("rows:", " ".join(g for g, _ in rows))
print(f"manifest ids: {len(ids)}   anchors: {len(set(anchors))}")
print("MISSING (manifest id, no anchor):", " ".join(missing) or "none")
print("ORPHAN  (anchor, no manifest claim):", " ".join(orphan) or "none")

if missing or orphan:
    sys.stderr.write("validate-gate-manifest: FAIL — the manifest and the anchors disagree.\n")
    sys.exit(1)
print("validate-gate-manifest: PASS — both directions resolve.")
PY
