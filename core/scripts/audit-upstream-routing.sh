#!/usr/bin/env bash
# audit-upstream-routing — a finding about AI/DLC's OWN machinery belongs in the push-candidate
# ledger, not in the consumer's carry-over backlog. This reports carry-over entries that look
# misrouted.
#
# THE DEFECT THIS EXISTS TO SURFACE, and it is silent in the direction that matters. A consumer
# session that finds a defect has two destinations and core historically instructed only one:
# `carry-over-backlog.md` is where sprint steps send findings, while
# `ai-dlc-update/push-candidate-ledger.md` is an UPDATER artifact a mid-sprint session has no
# route into. So a defect in a shipped core program gets filed as work the consumer owes itself,
# where nothing upstream will ever read it and the next pull overwrites the subject.
#
# Measured on the reference consumer when this was written: 13 of 82 carry-over entries named
# AI/DLC machinery paths. The worst was a P1 repo-corruption defect in the shipped pre-push hook
# — it corrupted that repository twice — filed as a carry-over item with ZERO mentions in the
# push-candidate ledger. Routed as consumer work, it was discharged by editing the distribution
# checkout directly, which is the boundary violation this tool exists to make visible.
#
# REPORT-ONLY, exit 0 on findings. A misrouted entry is a routing judgement, not a broken build,
# and the predicate below is deliberately loose in one direction (see FALSE POSITIVES). Gating a
# sprint on it would wedge correct work, which `mechanism-design.md` forbids: never ship a check
# that errors on correct data. Exit is 0 with findings, 2 only when NOTHING WAS EXAMINED.
#
# THE PREDICATE IS DECLARED, NEVER INFERRED, and that is the whole design.
# `core/fixtures/consumer-machinery-inventory/run.sh` records that eight predicates asking core to
# INFER which consumer executables are ai-dlc were measured and ALL EIGHT REFUTED. A path-shape
# guess here would be the ninth. Instead this asks the shipping authority — `core-paths.sh`, whose
# `--list` mode emits the same consumer-relative glob set its `--is-core` mode matches against.
#
# WHY `--list` ONCE RATHER THAN `--is-core` PER PATH. Measured on the reference consumer's 99
# distinct path tokens: 32s via per-path `--is-core`, roughly 0.32s of process spawn each. The
# suite is pole-bound, so that cost lands on the wall clock. One `--list` call plus in-process
# matching is equivalent AND ASSERTED TO BE: both were run over those same 99 paths and agreed on
# all 12, with zero disagreements in either direction. The fixture carries that agreement as an
# arm so the two cannot drift apart silently.
#
# FALSE POSITIVES: MEASURED, ENUMERATED, AND NOT ZERO. Naming a machinery path is not on its own
# evidence of misrouting — an entry may be consumer work that merely USES a core tool. Run against
# the reference consumer's 80 entries this reports 10, of which 6 are genuine upstream defects and
# 4 are false. Every false one is named here, because an unenumerated false-positive set is a
# check the operator turns off:
#
#   - the product bug whose text cites a validator in passing (a pool's balance reading $0.00);
#   - the entry about the consumer's OWN archived data, using a core tool to audit it;
#   - the entry about the consumer's OWN extension declarations, not core's resolution of them;
#   - the entry reporting a core tool's findings against the CONSUMER's prose.
#
# The shape they share: the machinery path is the INSTRUMENT, and the subject is the consumer's.
# The six true ones are the mirror — the machinery IS the subject, including one where two core
# files disagree with each other (a gate check's scope clause against the validator that enforces
# it), which no consumer edit can fix.
#
# THE CORPUS IS A LIVE REPOSITORY AND IT MOVED DURING THIS MEASUREMENT. A first pass read 79
# entries and 9 findings; the consumer committed a new entry minutes later and the same command
# read 80 and 10. Re-derive these figures rather than quoting them, and pin the blob when the
# number has to hold still — `git show HEAD:<path>` — because a corpus that moves under a
# measurement produces two true numbers that contradict each other.
#
# The entry that arrived in that gap is the case for this whole tool: a shipped AI/DLC hook whose
# rollback DELETES THE ENTIRE TARGET FILE on a rejected write, filed the same day as a carry-over
# item with no push candidate, its own text noting the fix "needs the hook's rollback logic
# inspected — dev work, not retro scope." The consumer cannot durably fix it; the next pull
# restores the defect.
#
# THE PAIRING DISCRIMINATOR DID NOT DO THE WORK EXPECTED OF IT, and that is recorded rather than
# smoothed over. An entry citing a `PC-` id is skipped as already routed, but only ONE entry on
# the reference corpus does, so the rate landed at roughly 44% — essentially the bare
# path-mention baseline. It is kept because it costs nothing and becomes load-bearing exactly as
# this tool starts working, when paired entries become common.
#
# A NARROWER PREDICATE WAS BUILT AND REJECTED ON MEASUREMENT. Restricting to entries whose TITLE
# names a machinery file cuts 9 findings to 3 — but it drops two genuine misroutes (a shipped
# fixture's flake, a core script enhancement) while KEEPING a false one, so it trades recall for
# no precision. For a report-only nudge a missed misroute is the expensive error: the operator
# reads a short list either way, and the entry this tool exists for is the one nobody noticed.
#
# Usage: audit-upstream-routing.sh [--backlog <path>] [--json]
# Exit:  0 = ran (with or without findings), 2 = examined nothing.
set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by counting `..` hops — a validator
# that counts hops answers differently from the root, from a subdirectory, and from a fixture
# sandbox that copied it, and the sandbox answer is the silent one. This tool runs from the
# distribution at core/scripts/X and from a consumer at scripts/ai-dlc/X, and no fixed hop count
# fits both. Inline on purpose: locating a shared lib is the same unsolved problem.
# The order is load-bearing — the script's own install path is consulted BEFORE
# CLAUDE_PROJECT_DIR, which the harness sets to whatever repository the session started in, not
# necessarily the tree this copy belongs to. I75 binds the chain and its terminal guard.
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
# FAIL CLOSED. With no terminal guard an unresolved root leaves this EMPTY, every derived path
# becomes absolute from `/`, and the tool reports about a tree that does not exist rather than
# saying it cannot find one — a clean report over nothing.
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

BACKLOG=""
EMIT_JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --backlog) BACKLOG="${2:-}"; shift 2 ;;
    --json)    EMIT_JSON=1; shift ;;
    -h|--help) echo "usage: audit-upstream-routing.sh [--backlog <path>] [--json]" >&2; exit 2 ;;
    *)         echo "audit-upstream-routing: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$BACKLOG" ] || BACKLOG="$AI_DLC_ROOT/_bmad-output/planning-artifacts/carry-over-backlog.md"

# A SIBLING ABSENT IS A REFUSAL, NOT A FINDING. `core-paths.sh` owns the glob set; without it this
# tool has no predicate at all, and printing "no misroutes" would be a lie about an unread corpus.
CORE_PATHS="$AI_DLC_SELF_DIR/core-paths.sh"
if [ ! -f "$CORE_PATHS" ]; then
  echo "audit-upstream-routing: DISARMED — EXAMINED NOTHING — no core-paths.sh beside $AI_DLC_SELF_DIR." >&2
  exit 2
fi

if [ ! -f "$BACKLOG" ]; then
  echo "audit-upstream-routing: DISARMED — EXAMINED NOTHING — no carry-over backlog at $BACKLOG. This is not 'no misrouted entries'; nothing was read." >&2
  exit 2
fi

# PASS THE MANIFEST EXPLICITLY. `core-paths.sh --list` falls back to two RELATIVE candidate
# paths, so bare it answers about the process working directory: run from a consumer root it
# yields the full glob set, run one directory down it yields NONE — measured on a tree built by
# `install.sh`. The contrast is the whole point and it does not decay; the COUNT does, so derive
# it rather than read one here: `core-paths.sh --list | wc -l` from each directory. An earlier
# revision of this comment quoted the total and it was stale within one release, because adding
# this tool's own fixture to `core-manifest.md` moved it.
#
# Resolving the manifest against the root marker instead makes this cwd-invariant, which is
# asserted in the fixture rather than assumed. Both layouts are tried because the distribution
# and an installed consumer differ, and invariant I33 forbids locating one core file by walking
# up from another.
MANIFEST=""
for _m in "$AI_DLC_ROOT/.claude/skills/ai-dlc/core-manifest.md" \
          "$AI_DLC_ROOT/core/skills/ai-dlc/core-manifest.md"; do
  [ -f "$_m" ] && { MANIFEST="$_m"; break; }
done
if [ -z "$MANIFEST" ]; then
  echo "audit-upstream-routing: DISARMED — EXAMINED NOTHING — no core-manifest.md under $AI_DLC_ROOT in either layout." >&2
  exit 2
fi

# An empty glob set silently classifies EVERY path as consumer-owned, so every entry reads as
# correctly routed and the report is a clean-looking zero over a dead predicate.
GLOBS="$(bash "$CORE_PATHS" --list "$MANIFEST" 2>/dev/null || true)"
if [ -z "$GLOBS" ]; then
  echo "audit-upstream-routing: DISARMED — EXAMINED NOTHING — core-paths.sh --list produced no globs from $MANIFEST, so nothing could ever classify as machinery." >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || {
  echo "audit-upstream-routing: DISARMED — EXAMINED NOTHING — python3 absent." >&2; exit 2; }

BACKLOG="$BACKLOG" EMIT_JSON="$EMIT_JSON" GLOBS="$GLOBS" python3 <<'PY'
import fnmatch, json, os, re, sys

backlog = os.environ["BACKLOG"]
globs = [g.strip() for g in os.environ["GLOBS"].splitlines() if g.strip()]
lines = open(backlog, encoding="utf-8", errors="replace").read().split("\n")

# BOTH HEADING SHAPES THE PRODUCER ACTUALLY EMITS. The reference backlog carries `### CO-S...`
# and `## [CO-S...]`; a grammar that knows only one silently drops every entry of the other kind
# and reports a smaller, cleaner-looking corpus.
HEAD = re.compile(r"^#{2,4}\s+\[?(CO-[A-Z0-9][A-Z0-9.-]*)\]?")
PATH = re.compile(r"[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.*-]+)+\.(?:sh|md|py|json|yaml|yml)")
PC   = re.compile(r"(?<![\w-])PC-[A-Z0-9][A-Z0-9.-]*(?![\w-])")

heads = [(i, m.group(1)) for i, l in enumerate(lines) for m in [HEAD.match(l)] if m]
entries = []
for n, (i, cid) in enumerate(heads):
    end = heads[n + 1][0] if n + 1 < len(heads) else len(lines)
    entries.append((cid, i + 1, "\n".join(lines[i:end])))

# A GLOB THAT MATCHES NOTHING MUST NOT REPORT SUCCESS. An empty corpus exits 0 and reads exactly
# like "every entry is routed correctly", so it is reported as EXAMINED NOTHING instead.
if not entries:
    sys.stderr.write(
        "audit-upstream-routing: DISARMED — EXAMINED NOTHING — %s parsed to 0 entries. "
        "Either the backlog is empty or the heading grammar no longer matches the producer.\n" % backlog)
    raise SystemExit(2)

def core_paths_in(body):
    hits = []
    for p in dict.fromkeys(PATH.findall(body)):
        if any(fnmatch.fnmatch(p, g) for g in globs):
            hits.append(p)
    return hits

findings, paired = [], 0
for cid, ln, body in entries:
    mach = core_paths_in(body)
    if not mach:
        continue
    if PC.search(body):
        paired += 1          # already routed upstream; the pairing is the discriminator
        continue
    findings.append({"id": cid, "line": ln, "paths": mach[:6]})

if os.environ["EMIT_JSON"] == "1":
    print(json.dumps({"backlog": backlog, "entries": len(entries), "globs": len(globs),
                      "paired": paired, "findings": findings}, indent=2))
    raise SystemExit(0)

print("AI/DLC UPSTREAM ROUTING  —  %s" % backlog)
print("  entries examined: %d    machinery globs: %d" % (len(entries), len(globs)))
print("  already paired with a PC- id: %d" % paired)
print()
if not findings:
    print("MISROUTED (0) — every entry naming AI/DLC machinery already cites a push candidate.")
    raise SystemExit(0)

print("MISROUTED (%d) — these name AI/DLC's own machinery and cite no push candidate." % len(findings))
print("A defect in machinery belongs in _bmad-output/ai-dlc-update/push-candidate-ledger.md as a")
print("PC- entry. Keep a CO- item too ONLY if local work remains — a workaround to remove later.")
print()
for f in findings:
    print("  %s  [line %d]" % (f["id"], f["line"]))
    for p in f["paths"]:
        print("      names: %s" % p)
print()
print("REPORT-ONLY: this exits 0. Routing is a judgement and some of these may be consumer work")
print("that merely USES a core tool — read each before refiling.")
PY
rc=$?
[ "$rc" = 2 ] && exit 2
exit 0
