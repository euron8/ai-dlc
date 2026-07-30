#!/usr/bin/env bash
set -euo pipefail

# validate-gate-manifest.sh — two-way resolve between the GATE_MANIFEST table and
# the `<!-- CHECK_LOADED: <id> -->` anchors in gate-validation.md.
#
# Gate-type slicing loads checks by gate type. A manifest ID with no matching
# anchor, or an anchor no manifest row claims, silently mis-slices a gate: the
# gate runs, reports PASS, and the missing check never fires.
#
# THE TABLE THIS RESOLVES IS THE ONE THE LEAD LOADS, NOT NECESSARILY CORE'S.
# Under Rule 27 an `overrides/` entry shadowing the manifest section REPLACES it
# at load time, and `extensions/checks/` entries add checks with anchors of their
# own. Through v0.176.0 this script read core and nothing else, so on a layered
# consumer it validated a table nobody reads and reported PASS on it. That is not
# a weaker version of the guarantee in the paragraph above — it is the exact
# failure that paragraph describes, produced by the guard against it. Measured on
# the reference consumer at 0.176.0: an override added `34` to the `implementation`
# row, `34` was defined in `extensions/checks/` with no anchor, and every gate that
# should have loaded that consumer's protected-core-path guard passed without it
# while this script printed PASS.
#
# So the resolve runs against the RENDERED manifest:
#   manifest = the overrides/ entry that shadows the manifest section, else core's
#   anchors  = core ∪ extensions/ hooking this file ∪ overrides/ shadowing it
#   claimed  = every manifest row's ids ∪ the anchors of every extension that
#              declares `gate_types:`
#
# CODES (claimed by layer-contract.yaml; I36 joins this vocabulary both ways):
#   GM1 a check DEFINED as a heading in an extensions/ entry hooking this file that
#       carries no CHECK_LOADED anchor and is named by no manifest row. It is neither
#       MISSING (that needs a row) nor an ORPHAN (that needs an anchor), so it fell
#       through both directions of the resolve and this script printed PASS while the
#       check had never run. Measured on the reference consumer at 0.196.0: THREE
#       (`19b`, `35`, and the retired tombstone `33`) — and the consumer had already
#       hand-remediated this same state twice, for Check 25 and Check 2a, each time
#       by adding an integer to a row rather than by anything that would catch the
#       next one.
#   GM2 a `gate_types:` declaration no loader can act on — declared on an entry
#       hooking another file, on an entry with no anchor to file, or naming a gate
#       type the rendered manifest has no row for.
#
# WHY `gate_types:` EXISTS AT ALL. Before it, the only way to make an extension's
# check loadable was an overrides/ entry SHADOWING this whole manifest section, since
# the row is the only place an id can be claimed. That is a 130-line shadow carrying
# the whole section's base_sha drift in order to add one integer to one row, and on
# the reference consumer that shadow also silently dropped two paragraphs of core
# prose — including the canonical gate-type enum — while its own first line claimed
# it was "identical to core, with one change". The key removes the reason to write it.
#
# MINIMUM MECHANISM (Rule 26(c)). Failure caught: a consumer's effective manifest
# and effective anchor set disagree, so a claimed check never loads. NOT caught:
# the anchor set is a UNION, so an override that shadows a CHECK section and drops
# that check's anchor stays invisible — core's copy of the anchor survives in the
# pool. Closing that needs section-level rendering through precedence, which is a
# document renderer, not a resolver; the union is the cheapest thing that catches
# the observed failure. False-positive cost: measured on the reference consumer,
# the layered resolve reports MISSING none / ORPHAN none — 42 ids, 42 anchors — so
# the set is empty, not merely small. Remove this note when the manifest is
# resolved by rendering sections through precedence rather than unioning anchors.
#
# usage:
#   validate-gate-manifest.sh [<gate-validation.md>]
#
# exit 0 = both directions resolve
# exit 1 = MISSING or ORPHAN ids
# exit 2 = the scan could not be performed (usage, unreadable file, unparseable
#          manifest, or an undecidable layer state). Never degrades to a pass: a
#          comparison of nothing reads exactly like a clean resolve, which is the
#          defect this file exists to make impossible.
#
# Every id is DERIVED from the file. No check id is hard-coded here, and neither
# is the manifest section's heading: it is read back out of the core file so the
# override anchors join against what core actually spells.

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

# Locate the layer dirs WITHOUT walking up a fixed number of `..` from a resolved
# script path (invariant I33). `install.sh` copies `core/skills/ai-dlc/` to
# `.claude/skills/ai-dlc/` as ONE subtree, so `overrides/` and `extensions/` are
# siblings of `steps/` in both layouts and the skill dir is a suffix strip, not a
# traversal. A `$1` pointing anywhere else gets a core-only resolve that SAYS so:
# a layered pass and an unlayered one must not print the same thing.
SKILL_DIR=""
LAYER_NOTE=""
case "$FILE" in
  */skills/ai-dlc/steps/gate-validation.md|skills/ai-dlc/steps/gate-validation.md)
    SKILL_DIR="${FILE%/steps/gate-validation.md}" ;;
  *)
    LAYER_NOTE="'$FILE' is not <…>/skills/ai-dlc/steps/gate-validation.md, so the sibling overrides/ and extensions/ cannot be located" ;;
esac

# The check-HEADING grammar. This assignment is byte-identical to the one in
# `core/scripts/validate-layer-entries.sh` and I47 asserts it — and, since the widening
# below, to `ANCHOR_RE` in `reconcile/relabel-extension-checks.sh` too, which I47 also
# asserts. It lives here in BASH rather than in the python below because python's `re` has
# no `[[:space:]]`, so a python spelling could not be the same string — and a second
# spelling of an anchor grammar is the defect I40's header records five times over.
CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'

# Every check id a layer entry DEFINES as a heading, as `<file>\t<id>` lines. The
# python filters these to the entries that hook this file; collecting them here keeps
# the grammar single-spelled. A heading is how a check enters the rendered document,
# so a check that has one and never became an anchor is invisible to BOTH directions
# of the resolve below — see the UNLOADABLE arm.
EXT_HEADINGS=""
if [ -n "$SKILL_DIR" ] && [ -d "$SKILL_DIR/extensions" ]; then
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      cid="$(printf '%s' "$h" | sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//' | sed -E 's/[[:space:]]*[.—]$//')"
      EXT_HEADINGS="${EXT_HEADINGS}${entry}	${cid}
"
    done <<EOH
$(grep -Eho "$CHECK_HEAD_RE" "$entry" 2>/dev/null || true)
EOH
  done <<EOF
$(find "$SKILL_DIR/extensions" -name '*.md' ! -name 'README.md' 2>/dev/null | sort)
EOF
fi

python3 - "$FILE" "$SKILL_DIR" "$LAYER_NOTE" "$EXT_HEADINGS" <<'PY'
import os, re, sys

path, skill_dir, layer_note = sys.argv[1], sys.argv[2], sys.argv[3]
ext_headings_raw = sys.argv[4] if len(sys.argv) > 4 else ""
src = open(path, encoding="utf-8", errors="replace").read()

ANCHOR_RE   = r"^<!-- CHECK_LOADED: (\S+) -->$"
MANIFEST_RE = ("GATE_MANIFEST v1", "GATE_MANIFEST_END")
HEADING_RE  = re.compile(r"^#{1,6}[ \t]+(.*?)[ \t]*$", re.M)


def read(p):
    return open(p, encoding="utf-8", errors="replace").read()


def anchors_in(text):
    return set(re.findall(ANCHOR_RE, text, re.M))


def manifest_block(text):
    """The GATE_MANIFEST region, or None. Same substring find the loader's own
    delimiters imply — the markers are HTML comments inside a fenced block, so a
    line-anchored regex would have to know the fence."""
    a, b = text.find(MANIFEST_RE[0]), text.find(MANIFEST_RE[1])
    return text[a:b] if (a >= 0 and b > a) else None


def heading_above(text, offset):
    """The nearest heading before `offset` — the section a shadow anchor has to
    name to replace this block. Derived, never spelled here. None is legitimate
    (a manifest under no heading at all): it means no ANCHORED shadow can claim
    the section, so only a whole-file shadow replaces it."""
    last = None
    for m in HEADING_RE.finditer(text, 0, offset):
        last = m.group(1)
    return last


def norm(s):
    return re.sub(r"\s+", " ", s.strip().lstrip("#").strip()).casefold()


def frontmatter(text, key):
    m = re.search(r"^%s:[ \t]*(.*)$" % re.escape(key), text, re.M)
    return m.group(1).strip() if m else ""


def target_file(value):
    """The core-relative FILE part of a `hooks:`/`shadows:` value. Same reduction
    validate-layer-entries.sh applies: everything before the first '#', spaces
    stripped, anything after a comma dropped (multi-anchor shadows)."""
    return value.split("#", 1)[0].replace(" ", "").split(",")[0]


def target_anchor(value):
    return value.split("#", 1)[1].strip() if "#" in value else ""


def layer_entries(d):
    out = []
    for root, _, files in os.walk(d):
        for n in sorted(files):
            if n.endswith(".md") and n != "README.md":
                out.append(os.path.join(root, n))
    return sorted(out)


def rel(p):
    return os.path.relpath(p, skill_dir) if skill_dir else p


def die(msg):
    sys.stderr.write(msg if msg.endswith("\n") else msg + "\n")
    sys.exit(2)


# --- core, first. A layered resolve still needs core to parse. ---------------
core_anchors = anchors_in(src)
if not core_anchors:
    die(f"validate-gate-manifest: FAIL — no '<!-- CHECK_LOADED: <id> -->' anchors in {path}.\n"
        "  Every manifest id would report as MISSING and every anchor as absent; the\n"
        "  resolve would be a comparison against an empty set.")

core_block = manifest_block(src)
if core_block is None:
    die(f"validate-gate-manifest: FAIL — no 'GATE_MANIFEST v1' … 'GATE_MANIFEST_END' region in {path}.")

section_heading = heading_above(src, src.find(MANIFEST_RE[0]))

# --- the layers -------------------------------------------------------------
ovr_dir = os.path.join(skill_dir, "overrides") if skill_dir else ""
ext_dir = os.path.join(skill_dir, "extensions") if skill_dir else ""
this_file = "steps/" + os.path.basename(path)

ext_anchors, ovr_anchors = set(), set()
bearing = []        # overrides that carry a manifest region
empty_shadow = []   # overrides that claim the section but carry no region

ext_hooking = set()   # entries whose `hooks:` names this file
ext_gt = {}           # those entries' declared gate types, by file
gt_wrong_hook = []    # entries declaring gate_types: that hook something else


def unquote(v):
    """`gate_types:` is read back exactly as validate-layer-entries.sh reads it —
    a bare `#` opens a YAML comment, so an anchor-bearing value has to be quotable,
    and fm() returns the quotes literally. v0.196.0 shipped that defect on
    `extends:` and it parsed as a file named `'`."""
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1].strip()
    return v


def gate_types_of(text):
    """A comma-separated list, or a YAML flow list — the spelling
    `enforcement-map.yaml` already uses for this same key per check
    (`gate_types: [universal]`). Accepting both means the one thing an author
    already knows how to write cannot be the thing that silently declares nothing."""
    v = unquote(frontmatter(text, "gate_types"))
    if v.startswith("[") and v.endswith("]"):
        v = v[1:-1]
    return [t.strip() for t in v.split(",") if t.strip()]


if skill_dir and os.path.isdir(ext_dir):
    for f in layer_entries(ext_dir):
        body = read(f)
        gts = gate_types_of(body)
        if target_file(frontmatter(body, "hooks")) == this_file:
            ext_hooking.add(f)
            ext_anchors |= anchors_in(body)
            if gts:
                ext_gt[f] = gts
        elif gts:
            gt_wrong_hook.append(f)

if skill_dir and os.path.isdir(ovr_dir):
    for f in layer_entries(ovr_dir):
        body = read(f)
        shadows = frontmatter(body, "shadows")
        if target_file(shadows) != this_file:
            continue
        ovr_anchors |= anchors_in(body)
        anchor = target_anchor(shadows)
        claims_section = (anchor == "") or (
            section_heading is not None and norm(anchor) == norm(section_heading))
        if manifest_block(body) is not None:
            bearing.append(f)
        elif claims_section:
            empty_shadow.append(f)

if empty_shadow:
    die("validate-gate-manifest: FAIL — an overrides/ entry replaces the manifest section\n"
        "  and carries no 'GATE_MANIFEST v1' … 'GATE_MANIFEST_END' region:\n"
        + "".join(f"    {rel(f)}\n" for f in empty_shadow) +
        "  The rendered document has NO manifest, so the lead loads no row at all.\n"
        "  Resolving core's table instead would validate a table nobody reads.")

if len(bearing) > 1:
    die("validate-gate-manifest: FAIL — two or more overrides/ entries each carry a\n"
        "  GATE_MANIFEST region:\n"
        + "".join(f"    {rel(f)}\n" for f in bearing) +
        "  Precedence between two shadows of one section is undefined, so the effective\n"
        "  table is undecidable. Picking one would make this scan's PASS unattributable.")

if bearing:
    manifest_src = rel(bearing[0])
    block = manifest_block(read(bearing[0]))
else:
    manifest_src = "core"
    block = core_block

anchors = core_anchors | ext_anchors | ovr_anchors

# --- resolve ----------------------------------------------------------------
rows = re.findall(r"^\|[ ]*([a-z][a-z-]*)[ ]*\|([^|]*)\|", block, re.M)
if not rows:
    die("validate-gate-manifest: FAIL — GATE_MANIFEST parsed zero rows. The scan would\n"
        "  pass by comparing nothing.")
if not any(g == "universal" for g, _ in rows):
    die("validate-gate-manifest: FAIL — GATE_MANIFEST has no 'universal' row. The\n"
        "  always-loaded set would be unreadable and every universal check would\n"
        "  report as an orphan.")

ids = set()
for _, cell in rows:
    ids.update(t.strip() for t in cell.split(",") if t.strip())

# --- GM2: a `gate_types:` declaration that no loader can act on ------------------
# Three ways to declare a loading rule that never happens, each reported in its own
# words. Checked BEFORE the merge below, because a declaration that cannot resolve
# must not be allowed to claim an id and silence the resolve on it.
row_types = {g for g, _ in rows}
gm2 = []
for f in gt_wrong_hook:
    gm2.append(f"    {rel(f)}: declares gate_types: but hooks '{target_file(frontmatter(read(f), 'hooks'))}', "
               f"not '{this_file}'. The manifest lives in {this_file}; nothing merges a row for a check "
               f"defined against another file.")
for f in sorted(ext_gt):
    a = anchors_in(read(f))
    if not a:
        gm2.append(f"    {rel(f)}: declares gate_types: {','.join(ext_gt[f])} and carries no "
                   f"'<!-- CHECK_LOADED: <id> -->' anchor. There is no check id to put in a row, so the "
                   f"declaration claims loading for nothing.")
        continue
    unknown = [t for t in ext_gt[f] if t not in row_types]
    if unknown:
        gm2.append(f"    {rel(f)}: declares gate type(s) {', '.join(sorted(unknown))}, which the rendered "
                   f"manifest has no row for (rows: {' '.join(g for g, _ in rows)}). A gate declares one of "
                   f"those types, so a check filed under any other never loads at any gate.")
if gm2:
    die("validate-gate-manifest: FAIL — a gate_types: declaration cannot load:\n"
        + "\n".join(gm2) + "\n"
        "  The key states which gate types load an extension's checks. Declared against a\n"
        "  type, a file or an anchor set that does not exist, it reads as a registration and\n"
        "  performs none — the unloadable-check state this resolve exists to make impossible.")

# --- the merge: a declared entry's anchors are claimed ---------------------------
# This is what lets a consumer register a check WITHOUT shadowing the whole manifest
# section in an overrides/ entry. That shadow is the only route there was, and it
# carries the whole section's base_sha drift to add one integer to one row.
declared = {}
for f in sorted(ext_gt):
    for i in sorted(anchors_in(read(f))):
        declared[i] = ext_gt[f]
ids |= set(declared)

missing = sorted(i for i in ids if i not in anchors)
orphan = sorted(a for a in anchors if a not in ids)

# --- GM1: a check heading that is neither anchored nor claimed -------------------
# THE STATE BOTH DIRECTIONS OF THE RESOLVE MISS. `missing` needs a manifest row and
# `orphan` needs an anchor; a check defined only as a HEADING has neither, so it falls
# between them and this script prints PASS while the check has never run once.
#
# The subject set is derived by subtraction and needs no core-vs-consumer test: a
# heading whose id core anchors is already in `anchors`, so an extension AUGMENTING a
# core check drops out on its own rather than by a rule that could rot.
#
# WHAT IT CAN NOW SEE, AND WHAT THE PREVIOUS NOTE HERE GOT WRONG. This block used to say
# that an alphabetic check id was outside the subject set and that widening was blocked
# because `reconcile/relabel-extension-checks.sh` could not rewrite one. Both halves were
# false. The rewriter's ANCHOR_RE has carried `[A-Z]{1,3}[0-9]*` and the `—` terminator
# since the release that widened it for `### H1.`, so it could already rewrite exactly the
# headings this could not report; and the invariant named there (I34) binds RULE_RE, a
# different namespace, not this grammar at all. The two check grammars had simply forked,
# and the note read as a reason rather than as the defect it was.
#
# Unloadability's remedy was never the relabeller in any case: the relabeller adds an
# `[ext:<id>]` label to resolve a NUMBER COLLISION. What clears an UNLOADABLE is an anchor
# plus a `gate_types:` declaration, or deletion — stated in the FAIL message below, and
# available to a consumer with an alphabetic id exactly as to one with a numeric id.
head_ids = {}
for line in ext_headings_raw.splitlines():
    if "\t" not in line:
        continue
    hf, cid = line.split("\t", 1)
    if hf in ext_hooking:
        head_ids.setdefault(cid.strip(), hf)
unloadable = sorted(i for i in head_ids if i not in anchors and i not in ids)

# Only the NOT-RESOLVED case gets a line of its own. "layered but empty" and
# "no layer dirs at all" are the same answer and must print the same thing — the
# `anchor sources:` counts already say which layers contributed, and a line that
# varies with a directory's mere existence makes two identical resolves compare
# unequal.
if layer_note:
    print("layers: NOT RESOLVED —", layer_note)
print("manifest source:", manifest_src)
print(f"anchor sources: core({len(core_anchors)}) + extensions({len(ext_anchors)})"
      f" + overrides({len(ovr_anchors)}) = {len(anchors)} unique")
print("rows:", " ".join(g for g, _ in rows))
print(f"manifest ids: {len(ids)}   anchors: {len(anchors)}")
print("extension gate_types:",
      " ".join(f"{i}->{'|'.join(declared[i])}" for i in sorted(declared)) or "none")
print("MISSING (manifest id, no anchor):", " ".join(missing) or "none")
print("ORPHAN  (anchor, no manifest claim):", " ".join(orphan) or "none")
print("UNLOADABLE (check heading, no anchor and no row):", " ".join(unloadable) or "none")

if missing or orphan or unloadable:
    if unloadable:
        sys.stderr.write(
            "validate-gate-manifest: FAIL — check(s) defined as a heading that no gate can load: "
            + " ".join(unloadable) + "\n"
            "  Each is defined in an extensions/ entry that hooks this file, carries no\n"
            "  CHECK_LOADED anchor, and is named by no manifest row — so it is neither MISSING\n"
            "  nor an ORPHAN, and every gate passes without ever running it. Give it an anchor\n"
            "  and declare `gate_types:` on its entry, or delete it if it is retired.\n")
    if missing or orphan:
        sys.stderr.write("validate-gate-manifest: FAIL — the manifest and the anchors disagree.\n")
    sys.exit(1)
print("validate-gate-manifest: PASS — both directions resolve.")
PY
