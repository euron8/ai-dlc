#!/usr/bin/env bash
set -euo pipefail

# gate-slice.sh -- emit the READ PLAN for a gate type's required check set.
#
# WHAT THIS EXISTS FOR. Rule 21 carves out `steps/gate-validation.md` alone as
# sliced-loading: "loaded" means the GATE_MANIFEST universal row plus the declared
# gate type's row, not the whole file. That carve-out shipped with NO MECHANISM --
# the slicing design recorded it in as many words ("no behavior flag; the manifest
# + H1 are the mechanism"). The manifest is a table the
# lead must first read the file to see, and H1 checks only the RESULT. So the one
# tool that satisfies the contract without a derivation the lead performs by hand is
# an unbounded Read of 178 KB, and the reference consumer's transcripts show leads
# hand-bounding it 541 times of 558 -- working around the contract, not following it.
# This script derives the spans so a bounded read is the COMPLIANT read.
#
# IT EMITS A PLAN, NEVER THE TEXT, AND THAT IS NOT A STYLE CHOICE. Rule 23(c) and
# `ai-dlc-protect.sh` hard-block routing a verbatim-load file through Bash or any
# `ctx_*` tool, because consolidation drops directives. Printing the slice here would
# be that same defect wearing a different hat: the bytes would arrive as a Bash
# result, which a compressor rewrites before the lead reads it -- measured in this
# repo on a shipped hook, where `[ -n "${A_ESC:-}" ] || continue` came back without
# its closing bracket and no error was raised. So the output is OFFSETS. The lead
# still issues native `Read` calls with `offset`/`limit`, which is also what keeps
# Rule 21's attention interrupt intact: the span narrows, the Read remains.
#
# THE GRAMMAR IS NOT A SECOND IMPLEMENTATION. Anchor and manifest parsing is the
# same shape `core/scripts/validate-gate-manifest.sh` already resolves -- core
# anchors union extension anchors union override anchors, with a bearing override
# replacing core's table. A second parser for one grammar is an opinion; where this
# script and that validator disagree about the required set, that disagreement is a
# defect in one of them; core/fixtures/gate-resume compares the two required sets on
# the real file so the drift is a red fixture rather than a silent divergence.
#
# usage:
#   gate-slice.sh --type <planning|story|implementation|sprint-review|retro>
#                 [--root PATH]        project root (default: resolved by walking up)
#                 [--file PATH]        the gate file (default: the installed step file)
#                 [--done ID[,ID...]]  checks with a recorded verdict at this nonce;
#                                      omitted from the plan, listed on stderr
#                 [--format plan|json]
#                 [--self-probe]       run the two-direction probe and exit
#
# exit:
#   0  a plan was emitted (always at least the preamble span)
#   2  the slice could not be derived -- unknown type, unreadable file, zero anchors,
#      zero manifest rows, or a required id with no anchor. A REFUSAL, never a plan.
#      Exit 2 and not 1: a gate that cannot resolve its own required set must not
#      receive a partial plan it would read as complete.
#
# WHY A MISSING ANCHOR IS EXIT 2 AND NOT A SHORTER PLAN. That is H1's FAIL condition
# already. Emitting a plan that silently omits a required check would hand the lead a
# slice H1 must then reject -- the failure arriving one step later, attributed to the
# loader instead of the manifest. Refuse at derivation.

# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
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

TYPE=""; ROOT=""; FILE=""; DONE=""; FORMAT="plan"; PROBE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --type)   TYPE="${2:-}"; shift 2 ;;
    --root)   ROOT="${2:-}"; shift 2 ;;
    --file)   FILE="${2:-}"; shift 2 ;;
    --done)   DONE="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --self-probe) PROBE=1; shift ;;
    -h|--help)
      sed -n '36,48p' "$0" >&2; exit 2 ;;
    *) echo "gate-slice: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$ROOT" ] || ROOT="$AI_DLC_ROOT"

# The gate file, in either layout. `install.sh` splits what shares a parent in this
# tree, so a path that resolves here can resolve nowhere in an installed consumer --
# invariant I33 fails the build on locating one core file by walking up from another.
# Both candidates are named; neither is derived from the other.
if [ -z "$FILE" ]; then
  for _c in "${ROOT}/.claude/skills/ai-dlc/steps/gate-validation.md" \
            "${ROOT}/core/skills/ai-dlc/steps/gate-validation.md"; do
    [ -r "$_c" ] && { FILE="$_c"; break; }
  done
fi

if [ -z "$FILE" ] || [ ! -r "$FILE" ]; then
  echo "gate-slice: FAIL -- gate-validation.md is not readable in either layout under ${ROOT}." >&2
  echo "  Looked for .claude/skills/ai-dlc/steps/ and core/skills/ai-dlc/steps/." >&2
  exit 2
fi

SKILL_DIR="$(dirname "$(dirname "$FILE")")"

if [ "$PROBE" = "1" ]; then
  # THE PROBE RUNS BEFORE THE CORPUS AND FIRES IN BOTH DIRECTIONS. An arm reporting a
  # clean derivation without first proving it can refuse has established that it ran,
  # not that it discriminates. Probe trees are built under `mktemp`, never the real
  # corpus.
  _pt="$(mktemp -d)"
  mkdir -p "${_pt}/skills/ai-dlc/steps"
  _pf="${_pt}/skills/ai-dlc/steps/gate-validation.md"
  {
    printf '# Gate\n\nPreamble prose.\n\n'
    printf '```\n<!-- GATE_MANIFEST v1 -->\n'
    printf '| Gate type | Required checks |\n|---|---|\n'
    printf '| universal | 1, 2 |\n'
    printf '| planning  | 7 |\n'
    printf '<!-- GATE_MANIFEST_END -->\n```\n\n'
    printf '### 1. First.\n<!-- CHECK_LOADED: 1 -->\n\nbody one\n\n'
    printf '### 2. Second.\n<!-- CHECK_LOADED: 2 -->\n\nbody two\n\n'
    printf '### 7. Seventh.\n<!-- CHECK_LOADED: 7 -->\n\nbody seven\n\n'
    printf '### 9. Ninth.\n<!-- CHECK_LOADED: 9 -->\n\nbody nine\n'
  } > "$_pf"

  _fail=0
  _out="$("$0" --type planning --file "$_pf" --format plan 2>/dev/null)" || _fail=1
  if [ "$_fail" != "0" ]; then
    echo "gate-slice SELF-PROBE FAIL: a well-formed seed did not produce a plan." >&2; exit 2
  fi
  # Direction 1: the plan covers every required id and NOT the unrequired one.
  #
  # THE ID SET IS EXTRACTED AS A SET, NOT MATCHED AS A SUBSTRING. The first form of this
  # probe grepped `[[:space:]]<id>` against the plan and scored check 2 as ABSENT, because
  # in the emitted `1<TAB>5<TAB>1,2` that id follows a COMMA. The probe could not spell
  # its own subject and reported a failure the corpus run contradicted -- a grammar aimed
  # at its own output and returning a false negative. Field 3, split on commas, is the
  # emitted set exactly as a consumer of this plan would read it.
  _ids="$(printf '%s\n' "$_out" | awk -F'\t' 'NF==3 {print $3}' | tr ',' '\n' | sed '/^-\{0,1\}$/d' | sort -u)"
  for _need in 1 2 7; do
    grep -qx "$_need" <<<"$_ids" \
      || { echo "gate-slice SELF-PROBE FAIL: required check ${_need} absent from the plan (got: $(printf '%s' "$_ids" | tr '\n' ' '))." >&2; exit 2; }
  done
  if grep -qx '9' <<<"$_ids"; then
    echo "gate-slice SELF-PROBE FAIL: check 9 is in no required row and was planned anyway." >&2; exit 2
  fi
  # Direction 2: a required id whose anchor is deleted must REFUSE, not shorten.
  _bad="${_pt}/bad.md"
  grep -v '^<!-- CHECK_LOADED: 7 -->$' "$_pf" > "$_bad"
  if "$0" --type planning --file "$_bad" --format plan >/dev/null 2>&1; then
    echo "gate-slice SELF-PROBE FAIL: a required id with no anchor produced a plan instead of exit 2." >&2
    exit 2
  fi
  # Direction 3: the preamble is in every plan. The manifest and the loader contract live
  # there and H1 re-reads the manifest to resolve the required set; a plan whose first row
  # does not start at line 1 describes a slice H1 cannot verify. An adversary mutated the
  # preamble interval out and this probe, in its first form, still passed.
  _first="$(printf '%s\n' "$_out" | head -1 | awk -F'\t' '{print $1}')"
  [ "$_first" = "1" ] || { echo "gate-slice SELF-PROBE FAIL: the plan's first row starts at ${_first}, not 1 -- the preamble is not planned." >&2; exit 2; }
  # Direction 4: an unknown gate type must REFUSE. A slicer that accepts an unknown
  # type emits the universal row alone and reads as a working narrow slice.
  if "$0" --type qqq-absent --file "$_pf" --format plan >/dev/null 2>&1; then
    echo "gate-slice SELF-PROBE FAIL: an unknown gate type produced a plan instead of exit 2." >&2
    exit 2
  fi
  echo "gate-slice SELF-PROBE PASS: plans a well-formed seed with the preamble, refuses a missing anchor, refuses an unknown type."
  exit 0
fi

if [ -z "$TYPE" ]; then
  echo "gate-slice: FAIL -- --type is required. The declared gate type is the step's" >&2
  echo "  already-known phase, never a computation this script may guess at: guessing it" >&2
  echo "  would emit a plausible plan for the wrong gate." >&2
  exit 2
fi

AI_DLC_GATE_SLICE_FILE="$FILE" \
AI_DLC_GATE_SLICE_SKILL_DIR="$SKILL_DIR" \
AI_DLC_GATE_SLICE_TYPE="$TYPE" \
AI_DLC_GATE_SLICE_DONE="$DONE" \
AI_DLC_GATE_SLICE_FORMAT="$FORMAT" \
python3 - <<'PYEOF'
import json, os, re, sys

path      = os.environ["AI_DLC_GATE_SLICE_FILE"]
skill_dir = os.environ["AI_DLC_GATE_SLICE_SKILL_DIR"]
gtype     = os.environ["AI_DLC_GATE_SLICE_TYPE"]
done_raw  = os.environ.get("AI_DLC_GATE_SLICE_DONE", "")
fmt       = os.environ.get("AI_DLC_GATE_SLICE_FORMAT", "plan")

if fmt not in ("plan", "json"):
    sys.stderr.write("gate-slice: FAIL -- --format must be plan or json.\n")
    sys.exit(2)


def die(msg):
    sys.stderr.write(msg if msg.endswith("\n") else msg + "\n")
    sys.exit(2)


def read(p):
    return open(p, encoding="utf-8", errors="replace").read()


# The anchor grammar is a STANDALONE-LINE comment. Anchored to the whole line for the
# reason validate-gate-manifest.sh states: the manifest prose and H1's own remedy text
# carry `<!-- CHECK_LOADED: <id> -->` inline as a format example, and a substring match
# scores those as checks -- text about a program counted as the program.
ANCHOR_LINE = re.compile(r"^<!-- CHECK_LOADED: (\S+) -->[ \t]*$")
HEADING     = re.compile(r"^#{1,6}[ \t]+")
MANIFEST    = ("GATE_MANIFEST v1", "GATE_MANIFEST_END")

src   = read(path)
lines = src.split("\n")


def manifest_block(text):
    a, b = text.find(MANIFEST[0]), text.find(MANIFEST[1])
    return text[a:b] if (a >= 0 and b > a) else None


def frontmatter(text, key):
    m = re.search(r"^%s:[ \t]*(.*)$" % re.escape(key), text, re.M)
    return m.group(1).strip() if m else ""


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1].strip()
    return v


def target_file(value):
    return value.split("#", 1)[0].replace(" ", "").split(",")[0]


def gate_types_of(text):
    v = unquote(frontmatter(text, "gate_types"))
    if v.startswith("[") and v.endswith("]"):
        v = v[1:-1]
    return [t.strip() for t in v.split(",") if t.strip()]


def layer_entries(d):
    out = []
    for root, _, files in os.walk(d):
        for n in sorted(files):
            if n.endswith(".md") and n != "README.md":
                out.append(os.path.join(root, n))
    return sorted(out)


# --- the anchored spans in THIS file ----------------------------------------
# A check's span runs from its own heading to the heading that opens the next
# anchored check. Keyed on the heading and not on the anchor line, because the
# heading carries the check's title and scope clause -- a slice starting at the
# anchor drops the sentence that says when the check self-skips.
anchored = [(i, m.group(1)) for i, l in enumerate(lines) if (m := ANCHOR_LINE.match(l))]
if not anchored:
    die("gate-slice: FAIL -- no standalone '<!-- CHECK_LOADED: <id> -->' anchor lines in\n"
        "  %s.\n"
        "  Every required id would resolve to no span and the plan would be the preamble\n"
        "  alone, which reads as a working narrow slice." % path)

spans = {}
for k, (idx, cid) in enumerate(anchored):
    start = idx
    for j in range(idx, -1, -1):
        if HEADING.match(lines[j]):
            start = j
            break
    if k + 1 < len(anchored):
        nxt = anchored[k + 1][0]
        end = nxt
        for j in range(nxt, -1, -1):
            if HEADING.match(lines[j]):
                end = j
                break
    else:
        end = len(lines)
    # 1-based inclusive start, exclusive end -- the Read tool's own offset convention.
    spans[cid] = (start + 1, end)

preamble_end = anchored[0][0]
for j in range(anchored[0][0], -1, -1):
    if HEADING.match(lines[j]):
        preamble_end = j
        break

# --- the rendered manifest, resolved through the layers ---------------------
core_block = manifest_block(src)
if core_block is None:
    die("gate-slice: FAIL -- no 'GATE_MANIFEST v1' ... 'GATE_MANIFEST_END' region in %s.\n"
        "  The required set is unresolvable; a plan built without it would be a guess." % path)

this_file = "steps/" + os.path.basename(path)
ovr_dir = os.path.join(skill_dir, "overrides")
ext_dir = os.path.join(skill_dir, "extensions")

bearing, ext_gt, ext_anchor_ids = [], {}, {}

if os.path.isdir(ext_dir):
    for f in layer_entries(ext_dir):
        body = read(f)
        if target_file(frontmatter(body, "hooks")) != this_file:
            continue
        gts = gate_types_of(body)
        ids = set(re.findall(r"^<!-- CHECK_LOADED: (\S+) -->[ \t]*$", body, re.M))
        if gts and ids:
            ext_gt[f] = gts
            ext_anchor_ids[f] = ids

if os.path.isdir(ovr_dir):
    for f in layer_entries(ovr_dir):
        body = read(f)
        if target_file(frontmatter(body, "shadows")) != this_file:
            continue
        if manifest_block(body) is not None:
            bearing.append(f)

if len(bearing) > 1:
    die("gate-slice: FAIL -- two or more overrides/ entries each carry a GATE_MANIFEST\n"
        "  region:\n" + "".join("    %s\n" % f for f in bearing) +
        "  Precedence between two shadows of one section is undefined, so the effective\n"
        "  required set is undecidable. Picking one would make this plan unattributable.")

block = manifest_block(read(bearing[0])) if bearing else core_block
manifest_src = bearing[0] if bearing else "core"

rows = re.findall(r"^\|[ ]*([a-z][a-z-]*)[ ]*\|([^|]*)\|", block, re.M)
if not rows:
    die("gate-slice: FAIL -- GATE_MANIFEST parsed zero rows from %s. The required set\n"
        "  would be empty and the plan would cover the preamble alone." % manifest_src)

table = {}
for gt, cell in rows:
    table[gt] = [c.strip() for c in cell.split(",") if c.strip()]

if "universal" not in table:
    die("gate-slice: FAIL -- GATE_MANIFEST has no 'universal' row. The always-loaded set\n"
        "  would be unreadable and every universal check would be omitted from the plan.")

# `universal` is NOT a declarable type. The enum is the other rows -- derived from the
# table rather than restated, so a manifest that gains a type does not need this file
# edited. Restating it here is the drift validate-gate-manifest.sh was written to catch.
declarable = sorted(k for k in table if k != "universal")
if gtype == "universal" or gtype not in table:
    die("gate-slice: FAIL -- unknown gate type %r.\n"
        "  The rendered manifest at %s declares: %s\n"
        "  ('universal' is the always-loaded row, never a declarable type.)"
        % (gtype, manifest_src, ", ".join(declarable)))

required = list(dict.fromkeys(table["universal"] + table[gtype]))

# An extension declaring `gate_types:` adds its checks at those types exactly as if its
# ids sat in those rows. Its anchors live in the ENTRY, not in this file, so they are
# reported as a separate load and never planned as a span here -- a span offset into
# this file cannot address another file, and emitting one would be a citation that
# resolves nowhere.
ext_loads = []
for f, gts in sorted(ext_gt.items()):
    if gtype in gts or "universal" in gts:
        ext_loads.append((os.path.relpath(f, skill_dir), sorted(ext_anchor_ids[f])))

done = [d.strip() for d in done_raw.split(",") if d.strip()]
unknown_done = [d for d in done if d not in required]
missing = [c for c in required if c not in spans]

if missing:
    die("gate-slice: FAIL -- %d required check(s) for gate type %r have no\n"
        "  '<!-- CHECK_LOADED: <id> -->' anchor in %s: %s\n"
        "  This is H1's FAIL condition at derivation time. A plan omitting them would be\n"
        "  rejected by H1 one step later and the failure would be attributed to the\n"
        "  loader instead of to the manifest."
        % (len(missing), gtype, path, ", ".join(missing)))

plan_ids = [c for c in required if c not in done]

# --- merge the spans into contiguous Read calls ----------------------------
# The preamble carries the manifest and the loader contract and is ALWAYS planned: H1
# re-reads the manifest to resolve the required set, so a plan omitting it describes a
# slice H1 cannot verify.
intervals = [(1, preamble_end)] + sorted(spans[c] for c in plan_ids)
merged = []
for a, b in intervals:
    if merged and a <= merged[-1][1] + 1:
        merged[-1] = (merged[-1][0], max(merged[-1][1], b))
    else:
        merged.append((a, b))


def ids_in(a, b):
    return [c for c in plan_ids if a <= spans[c][0] < b]


total = sum(len(x) + 1 for x in lines)
planned = sum(sum(len(x) + 1 for x in lines[a - 1:b]) for a, b in merged)

if fmt == "json":
    out = {
        "file": path,
        "gate_type": gtype,
        "manifest_source": manifest_src,
        "required": required,
        "already_verdicted": done,
        "planned": plan_ids,
        "reads": [{"offset": a, "limit": b - a + 1, "checks": ids_in(a, b)} for a, b in merged],
        "file_bytes": total,
        "planned_bytes": planned,
        "extension_loads": [{"entry": e, "checks": ids} for e, ids in ext_loads],
    }
    print(json.dumps(out, indent=2))
else:
    for a, b in merged:
        print("%d\t%d\t%s" % (a, b - a + 1, ",".join(ids_in(a, b)) or "-"))

sys.stderr.write(
    "gate-slice: %s gate, manifest from %s -- %d required, %d planned in %d Read call(s), "
    "%d of %d bytes (%.0f%%)\n"
    % (gtype, manifest_src, len(required), len(plan_ids), len(merged), planned, total,
       100.0 * planned / total if total else 0.0))
if done:
    sys.stderr.write("gate-slice: omitted as already verdicted at this nonce: %s\n" % ", ".join(done))
if unknown_done:
    # Reported, never fatal: a --done id outside the required set is a checkpoint from a
    # DIFFERENT gate type, which is exactly what a mid-gate type change looks like. Dying
    # here would wedge a resume; silence would let a wrong checkpoint narrow the plan.
    sys.stderr.write(
        "gate-slice: WARNING -- %d --done id(s) are not required at this gate type and were "
        "ignored: %s. A checkpoint from another gate type cannot narrow this plan.\n"
        % (len(unknown_done), ", ".join(unknown_done)))
for e, ids in ext_loads:
    sys.stderr.write(
        "gate-slice: ALSO LOAD (extension, separate file): %s -- checks %s\n" % (e, ",".join(ids)))
PYEOF
