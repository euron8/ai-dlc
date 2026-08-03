#!/usr/bin/env bash
# adopt-extension-checks.sh — give a consumer's extension checks the anchor and the
# `gate_types:` declaration that make them LOADABLE.
#
# WHAT THIS EXISTS TO FIX, AND WHY A REPORT IS NOT ENOUGH.
#
# `validate-gate-manifest.sh`'s GM1 arm reports a check DEFINED as a heading in an
# extensions/ entry that carries no `<!-- CHECK_LOADED: <id> -->` anchor and is named
# by no manifest row. It is neither MISSING nor an ORPHAN, so both directions of the
# resolve miss it and every gate passes without ever running it.
#
# The arm is right and it shipped with no way to adopt what it names. The reference
# consumer met it as 23 checks across 4 entries on the pull that delivered it, filed a
# disclosed structural override, and re-filed that override at every subsequent gate —
# because the remedy was 23 hand edits, and a hand edit here has a specific failure:
#
#   THE TWO WRITES MUST BE ATOMIC. An anchor with no `gate_types:` becomes an ORPHAN
#   (exit 1). A `gate_types:` with no anchor trips GM2 (exit 2). Doing one half trades
#   one FAIL for a different FAIL, so a careful operator working down the list is red
#   the whole way and cannot tell progress from regression.
#
# That is the mechanism argument for a tool rather than a convenience argument.
#
# HALF-MECHANICAL, DELIBERATELY. The ANCHOR is 100% derivable from the heading id, so
# this writes it. The `gate_types:` is a SEMANTIC choice with no derivable answer, and
# the only inferable default — `universal` — would silently promote every adopted check
# to run at every gate, a behaviour change the operator never authorised and one that is
# invisible afterwards because an over-broad slice just passes vacuously. Inferring it
# would convert a loud FAIL into a quiet wrong answer, which is strictly worse. So the
# operator answers ONE question PER ENTRY (`gate_types:` is entry frontmatter, not
# per-check) — 4 questions for the reference consumer's 23 checks — and this refuses to
# write without it.
#
# LEVEL-TRIGGERED. It reads the tree's STATE, never a diff, so re-running after a
# partial adoption is safe and idempotent.
#
# Usage: adopt-extension-checks.sh <consumer-root> [--apply --gate-types <list>]
#          <list> is comma- or space-separated, e.g. "planning" or "planning,story"
#        (default: dry-run — print what it WOULD write, and the question it needs)
# Exit:  0 = nothing to adopt, or --apply succeeded
#        1 = adoptable checks found and NOT applied (dry-run with work outstanding)
#        2 = usage error, unresolvable tree, or a gate type outside the derived enum
set -uo pipefail

CONSUMER=""; APPLY=""; GTS=""; ENTRY_GTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)      APPLY=1; shift ;;
    --gate-types) GTS="${2:?--gate-types needs a list}"; shift 2 ;;
    --entry)      _e="${2:?--entry needs a path}"; shift 2
                  case "${1:-}" in
                    --gate-types) ENTRY_GTS="${ENTRY_GTS}${_e}=${2:?--entry PATH --gate-types needs a list}"'
'; shift 2 ;;
                    *) echo "adopt-extension-checks: --entry PATH must be followed by --gate-types LIST" >&2; exit 2 ;;
                  esac ;;
    -*)           echo "adopt-extension-checks: unknown arg: $1" >&2; exit 2 ;;
    *)            if [ -z "$CONSUMER" ]; then CONSUMER="$1"; shift
                  else echo "adopt-extension-checks: unexpected arg: $1" >&2; exit 2; fi ;;
  esac
done
[ -n "$CONSUMER" ] || {
  echo "usage: adopt-extension-checks.sh <consumer-root> [--apply --gate-types <list>]" >&2; exit 2; }

SKILL_DIR="$CONSUMER/.claude/skills/ai-dlc"
EXT_DIR="$SKILL_DIR/extensions"
[ -d "$EXT_DIR" ] || { echo "adopt-extension-checks: no extensions/ under $SKILL_DIR — nothing to adopt"; exit 0; }

# `--apply` without `--gate-types` is REFUSED rather than defaulted. A default here is
# the inference this tool exists not to make, and a half-write is the atomicity failure
# described above.
if [ -n "$APPLY" ] && [ -z "$GTS" ] && [ -z "$ENTRY_GTS" ]; then
  echo "adopt-extension-checks: --apply requires --gate-types. There is no safe default:" >&2
  echo "  the only inferable one is 'universal', which would promote every adopted check to" >&2
  echo "  run at every gate — a behaviour change nobody authorised, and an invisible one," >&2
  echo "  because an over-broad slice passes vacuously. Run the dry-run, answer the" >&2
  echo "  per-entry question it prints, then pass the answer." >&2
  exit 2
fi

CONSUMER="$CONSUMER" SKILL_DIR="$SKILL_DIR" EXT_DIR="$EXT_DIR" APPLY="${APPLY:-}" GTS="$GTS" \
  ENTRY_GTS="$ENTRY_GTS" python3 - <<'PY'
import os, re, sys, glob

SKILL = os.environ["SKILL_DIR"]; EXT = os.environ["EXT_DIR"]
CONSUMER = os.environ["CONSUMER"]
# --entry PATH --gate-types LIST, repeatable. `gate_types:` is ENTRY frontmatter and the
# right answer differs per entry -- the reference consumer needed four different values
# across four entries. A single global flag could not express the per-entry question this
# tool's own header documents, and applied one answer to every entry in one pass: a silent
# wrong-value write on entries the operator never considered.
ENTRY_GTS = {}
for _line in os.environ.get("ENTRY_GTS", "").splitlines():
    if "=" in _line:
        _k, _v = _line.split("=", 1)
        ENTRY_GTS[os.path.normpath(_k)] = _v
APPLY = bool(os.environ.get("APPLY")); GTS_RAW = os.environ.get("GTS", "")

def read(p):
    try:
        with open(p, encoding="utf-8") as fh: return fh.read()
    except OSError: return ""

def frontmatter(text, key):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m: return ""
    m2 = re.search(rf"^{re.escape(key)}:\s*(.*?)\s*$", m.group(1), re.M)
    return m2.group(1) if m2 else ""

# The check-heading grammar. BYTE-IDENTICAL to ANCHOR_RE in relabel-extension-checks.sh
# and to CHECK_HEAD_RE in validate-gate-manifest.sh / validate-layer-entries.sh, bound
# across all four by I47. A narrower grammar here means GM1 names a heading this tool
# cannot adopt, and the operator is handed a remedy that does not run — which is the
# defect this file was written for, one level up.
ANCHOR_RE = re.compile(
    r"^#{2,4}[ \t]+(?:Check[ \t]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[ \t]*[.—]")
LOADED_RE = re.compile(r"^<!--\s*CHECK_LOADED:\s*(\S+)\s*-->$", re.M)

# --- the manifest file the entries hook, and the enum it declares -----------------
# Resolved, not assumed: an overrides/ entry shadowing the step file is the copy the
# lead actually reads, so it is the copy whose anchors and rows count.
def resolve_manifest(rel):
    """A `hooks:` value is CORE-RELATIVE, not skill-relative, and joining it under the
    skill dir is wrong for one subtree.

    `team-roles/<role>.md` maps to `.claude/team-roles/<role>.md` -- OUTSIDE the skill
    dir -- while `steps/<x>.md` and bare `SKILL.md` live inside it. This is the case
    split `validate-layer-entries.sh`'s `resolve_target()` already implements and that
    `ai-dlc-update/SKILL.md` §7v criterion 2 already documents, warning in as many words
    that "a naive skill-relative join would falsely report every role extension's target
    MISSING". This tool shipped that naive join anyway, and it did worse than misreport:
    an unresolvable hook was FATAL, so on any consumer carrying a `team-roles/*` hook the
    tool exited 2 having scanned NOTHING -- and an empty run of a tool whose whole job is
    to surface GM1 findings reads exactly like a clean one."""
    if rel.startswith("team-roles/"):
        cand = os.path.join(CONSUMER, ".claude", rel)
        return cand if os.path.isfile(cand) else None
    ovr = os.path.join(SKILL, "overrides", rel.replace("/", "__"))
    for cand in (ovr, os.path.join(SKILL, rel)):
        if os.path.isfile(cand): return cand
    return None

# THE SUBJECT SET IS GM1'S, NOT A NARROWER ONE OF THIS TOOL'S OWN.
# `validate-gate-manifest.sh` never reads `kind:` — its UNLOADABLE set is every
# extensions/ entry whose `hooks:` names the manifest, whatever kind it declares. A
# `kind: check` filter here would therefore make this tool unable to adopt something
# GM1 names, which is a remedy that does not run: the defect class this file exists to
# close, reproduced one level over. So the filter is `hooks:` alone, and a kind
# mismatch becomes a REPORTED DECISION below rather than a silent exclusion.
entries = []
for f in sorted(glob.glob(os.path.join(EXT, "**", "*.md"), recursive=True)):
    t = read(f)
    hooks = frontmatter(t, "hooks")
    if not hooks: continue
    entries.append((f, t, hooks))

if not entries:
    print("adopt-extension-checks: no `kind: check` extension entries under", EXT, "— nothing to adopt")
    sys.exit(0)

# All entries in one run must hook the same manifest; group by hook target.
by_hook = {}
for f, t, h in entries: by_hook.setdefault(h, []).append((f, t))

rc = 0
total_adoptable = 0
for hook, group in sorted(by_hook.items()):
    mpath = resolve_manifest(hook)
    if mpath is None:
        # NOT fatal. This tool's subject is the gate manifest; an entry hooking something
        # else -- or something this consumer does not carry -- is out of scope, not a
        # reason to abandon every other entry. Exiting here made the tool scan nothing on
        # any consumer with a `team-roles/*` hook, and print nothing while doing it.
        print(f"  note: entries hook '{hook}', which resolves to no file here — skipped "
              f"(not the gate manifest, or not installed)")
        continue
    mtext = read(mpath)

    # The legal gate types, DERIVED from the rendered manifest's own first column
    # rather than from a literal here. A literal would be a fifth copy of an enum the
    # step file already declares, and the one that rots first.
    mrows = re.search(r"<!--\s*GATE_MANIFEST\b.*?-->(.*?)<!--\s*GATE_MANIFEST_END\s*-->", mtext, re.S)
    enum = []
    if mrows:
        for line in mrows.group(1).splitlines():
            if not line.strip().startswith("|"): continue
            cell = line.split("|")[1].strip()
            if not cell or cell.startswith("-") or cell.lower() == "gate type": continue
            enum.append(cell)
    # No GATE_MANIFEST region means this hook target is not the gate manifest, so its
    # entries are not gate-manifest entries and GM1 never counts them. Skipping is
    # correct and is NOT the silent-exclusion the subject-set note above rejects: that
    # note is about entries hooking the manifest, and these do not.
    if not mrows:
        continue
    if not enum:
        print(f"adopt-extension-checks: {mpath} carries a GATE_MANIFEST region and no readable\n"
              f"  gate-type column. Without the enum any --gate-types value would be accepted, and\n"
              f"  an unrecognised one just moves the failure to GM2. Failing closed rather than guessing.",
              file=sys.stderr)
        sys.exit(2)

    core_anchors = set(LOADED_RE.findall(mtext))
    for f in sorted(glob.glob(os.path.join(SKILL, "overrides", "*.md"))):
        core_anchors |= set(LOADED_RE.findall(read(f)))

    print(f"manifest source: {os.path.relpath(mpath, SKILL)}")
    print(f"gate-type enum : {' '.join(enum)}")

    # PHASE 1 -- what would be WRITTEN. The refusal below has to count the entries this
    # tool would actually touch, not every entry lacking `gate_types:`: an entry whose
    # headings core already anchors, or which hooks another file, has nothing adoptable and
    # counting it produced a refusal on a run that would have written to one entry.
    plan = []
    for f, t in sorted(group):
        own = set(LOADED_RE.findall(t))
        declared = frontmatter(t, "gate_types")
        heads = [(m.group(1), ln) for ln in t.splitlines()
                 for m in [ANCHOR_RE.match(ln)] if m]
        todo = [(i, ln) for i, ln in heads if i not in core_anchors and i not in own]
        plan.append((f, t, own, declared, todo))

    # A GLOBAL answer spread across SEVERAL entries this tool would write to is the silent
    # wrong-value write. One entry is unambiguous; the reference consumer had four, each
    # needing a different value, and one flag wrote one value into all of them.
    if APPLY and GTS_RAW.strip() and not ENTRY_GTS:
        multi = [f for f, t, own, declared, todo in plan
                 if todo and not declared and frontmatter(t, "kind") == "check"]
        if len(multi) > 1:
            print("adopt-extension-checks: --gate-types is GLOBAL and "
                  f"{len(multi)} entries would be written:", file=sys.stderr)
            for _f in multi:
                print(f"    {os.path.relpath(_f, SKILL)}", file=sys.stderr)
            print("  `gate_types:` is ENTRY frontmatter and the right answer differs per entry —\n"
                  "  one flag would write the same value into all of them, silently, including\n"
                  "  entries you never considered. Answer them individually:\n"
                  "    --entry <path> --gate-types <list>   (repeatable)\n"
                  "  A single entry is unambiguous and the global flag still works there.",
                  file=sys.stderr)
            sys.exit(2)

    for f, t, own, declared, todo in plan:
        rel = os.path.relpath(f, SKILL)
        # Subtraction, exactly as GM1 derives its own subject set: an extension that
        # AUGMENTS a core check has its id in core_anchors and drops out on its own.
        if not todo:
            # Nothing adoptable. Two structurally different reasons, and only one of
            # them is a finding:
            #   - the entry carries its OWN anchors but no `gate_types:` — that is
            #     GM2's state, the missing half of this tool's own write. Report it.
            #   - the entry carries no anchors either, because every heading id is one
            #     CORE already anchors: it AUGMENTS a core check and inherits core's
            #     row. Nothing to adopt, nothing to declare. Silent.
            if own and not declared:
                print(f"  {rel}: anchors present, `gate_types:` MISSING — declare it or the anchors are ORPHANs")
                rc = 1
            continue

        # A NON-`check` entry carrying adoptable check headings is a DECISION, never a
        # write. GM1 names it, so this tool must not be silent about it — but the two
        # honest fixes are opposite (the entry really is a check and `kind:` is wrong,
        # or the heading is not a check and should not match the grammar) and writing
        # `gate_types:` into a `step-domain` entry would pick one by accident.
        if frontmatter(t, "kind") != "check":
            print(f"  {rel}: NEEDS DECISION — hooks the manifest and defines check heading(s) "
                  f"{' '.join(i for i, _ in todo)}, but declares `kind: {frontmatter(t, 'kind') or '(none)'}`. "
                  f"GM1 counts these and this tool will not write a `gate_types:` into a non-check "
                  f"entry. Either correct `kind:` to `check` and re-run, or rename the heading so it "
                  f"is not read as a check id.")
            rc = 1
            continue

        total_adoptable += len(todo)
        rc = 1 if not APPLY else rc
        print(f"  {rel}")
        print(f"    adoptable check id(s): {' '.join(i for i, _ in todo)}")
        print(f"    gate_types: {declared or 'NOT DECLARED — this is the question only you can answer'}")

        if not APPLY:
            continue

        # Per-entry answer wins; the global flag is the fallback.
        raw = None
        for _k, _v in ENTRY_GTS.items():
            if os.path.normpath(f) == _k or os.path.basename(f) == os.path.basename(_k) \
               or os.path.normpath(rel) == _k:
                raw = _v; break
        if raw is None: raw = GTS_RAW
        if not raw.strip():
            print(f"adopt-extension-checks: no gate types given for {rel}. Pass "
                  f"--entry {rel} --gate-types <list>, or a global --gate-types.", file=sys.stderr)
            sys.exit(2)
        gts = [g.strip() for g in re.split(r"[,\s]+", raw) if g.strip()]
        bad = [g for g in gts if g not in enum]
        if bad:
            print(f"adopt-extension-checks: gate type(s) not in the manifest's own enum: {' '.join(bad)}\n"
                  f"  Legal: {' '.join(enum)}. Writing an unrecognised one does not adopt the check,\n"
                  f"  it moves the failure to GM2.", file=sys.stderr)
            sys.exit(2)

        out = t
        # (1) anchor directly under each heading, matching core's own placement.
        for i, ln in todo:
            out = out.replace(ln + "\n", ln + "\n" + f"<!-- CHECK_LOADED: {i} -->\n", 1)
        # (2) gate_types into the entry frontmatter, if absent.
        if not declared:
            out = re.sub(r"^(hooks:.*)$", r"\1\ngate_types: [" + ", ".join(gts) + "]",
                         out, count=1, flags=re.M)
        # ATOMIC: one write, both halves, or neither. Either half alone is a different
        # FAIL, so a partial write would trade one red for another and read as churn.
        if out == t:
            print(f"adopt-extension-checks: rewrite of {rel} produced no change — refusing to "
                  f"report an adoption that did not happen", file=sys.stderr)
            sys.exit(2)
        with open(f, "w", encoding="utf-8") as fh: fh.write(out)
        print(f"    APPLIED: {len(todo)} anchor(s)" + ("" if declared else f" + gate_types: [{', '.join(gts)}]"))

if total_adoptable == 0 and rc == 0:
    print("adopt-extension-checks: every extension check is already loadable — nothing to adopt")
    sys.exit(0)
if APPLY:
    print(f"adopt-extension-checks: adopted {total_adoptable} check(s). "
          f"Re-run scripts/ai-dlc/validate-gate-manifest.sh to confirm GM1 is clear.")
    sys.exit(0)
print(f"adopt-extension-checks: {total_adoptable} check(s) adoptable. Re-run with "
      f"--apply --gate-types <list> per the enum above.")
sys.exit(1)
PY
