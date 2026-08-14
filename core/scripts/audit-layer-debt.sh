#!/bin/bash
# audit-layer-debt.sh — the OPEN obligations the layer adjudications left behind.
#
# THE DEFECT THIS EXISTS TO END. `layer-adjudication-register.jsonl` records one of three
# verdicts per entry — `still-additive`, `contradicts-core`, `retire` — and none of them can
# say "keep it, AND something is owed". So an adjudicator who reaches `still-additive` only
# because somebody intends to fix something writes the obligation into the free-text `reason`
# and it stops existing the moment the row scrolls.
#
# Measured on the reference consumer at the pull this shipped for: 46 rows, verdict
# distribution 45 `still-additive` / 1 `contradicts-core` / 0 `retire`. Owed work appears in
# prose on 4 rows across 3 entries — reachable only by grepping reason fields for words like
# "deferred" and "follow-up". One says it in as many words: *"Nothing but this reason field is
# tracking that debt."* A debt nothing can enumerate is a debt nobody can act on, and a
# register that only ever says "keep it" is a ratchet wearing a verdict.
#
# FALSE-POSITIVE SET OF THE PROSE ARM, MEASURED BY READING EVERY MATCH: of the 4 flagged, 3
# are genuine obligations and 1 is prose describing CORE's behaviour ("gate-log rotation runs
# as a post-retro-merge follow-up commit") rather than work this entry owes. A 5th match was
# `debt` inside the filename `test-check18-debt-audit` and is excluded by the identifier rule
# below. 1-in-4 is accepted deliberately: this REPORTS, so a false positive costs a glance
# while a missed obligation costs the thing this file exists to prevent. Bias to recall.
#
# TWO ARMS, and the second is why this is useful on the day it ships rather than only for
# rows written after it:
#
#   OPEN     `owed` objects declared by some row and closed by none. Structured, exact.
#   UNDECLARED
#            rows whose `reason` PROSE reads like owed work while the row declares no `owed`
#            object. That is the migration backlog — the five above — and it is the only way
#            they ever become visible. Reported separately and never counted as OPEN, because
#            a prose match is a suspicion and an `owed` object is a commitment.
#
# REPORT-ONLY, exit 0 on findings. A debt is a normal state of a living consumer; gating a
# pull on having none would block every pull and get the reader switched off. What this owes
# the operator is a list they can act on, not a veto.
#
# Usage: audit-layer-debt.sh [--register <file>] [--json]
# Exit:  0 report produced (with or without findings) · 2 register unreadable / usage

set -u

REGISTER=""
AS_JSON=no
while [ $# -gt 0 ]; do
  case "$1" in
    --register) REGISTER="${2:-}"; shift 2 || exit 2 ;;
    --json)     AS_JSON=yes; shift ;;
    -h|--help)  echo "usage: audit-layer-debt.sh [--register <file>] [--json]" >&2; exit 2 ;;
    *) echo "audit-layer-debt: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops — the same block every sibling validator carries, inline on purpose:
# a shared lib cannot fix this because locating the lib is the same unsolved
# problem. core/fixtures/validator-path-resolution asserts the layouts agree.
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

[ -n "$REGISTER" ] || REGISTER="$AI_DLC_ROOT/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"

# FAIL LOUD ON AN ABSENT REGISTER rather than printing an empty report. "No open debts"
# and "I could not read the ledger" are different claims and must not share an exit code —
# this file's whole subject is obligations that went invisible.
if [ ! -f "$REGISTER" ]; then
  echo "audit-layer-debt: DISARMED — no register at $REGISTER. This is not 'zero open debts'; nothing was read." >&2
  exit 2
fi

AS_JSON="$AS_JSON" python3 - "$REGISTER" <<'PY'
import json, os, re, sys

path = sys.argv[1]
as_json = os.environ.get("AS_JSON") == "yes"

rows, malformed, mistyped = [], 0, 0
with open(path, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            malformed += 1

# A row that will not parse is not a row with no debt. Counted and reported, never dropped.
declared, closed = {}, set()
for r in rows:
    o = r.get("owed")
    if isinstance(o, dict) and o.get("id"):
        declared.setdefault(o["id"], {
            "id": o["id"], "what": o.get("what", ""), "closes_when": o.get("closes_when", ""),
            "entry": r.get("entry", ""), "opened": r.get("recorded_utc", ""),
        })
    # THE TWO HALVES OF THE CONTRACT ARE READ WITH THE SAME RIGOUR, and until this they were
    # not: `owed` above is isinstance-guarded, this was a bare `or []`. The schema says
    # `closes_owed` is an array, but a row carrying it as a bare STRING is still valid JSON and
    # still parses — and `for cid in "OWED-X"` iterates CHARACTERS. `closed` fills with single
    # letters, none of which can match an id (the schema's own `^OWED-` pattern guarantees it),
    # so the close silently no-ops and the debt is reported OPEN on every run thereafter.
    #
    # THE FAILURE DIRECTION IS WHY THIS IS WORTH A FIX RATHER THAN A CONVENTION. It can only
    # produce a false OPEN, never a false close — so nothing is wrongly discharged, and the
    # operator who honestly RECORDS the discharge is punished exactly as much as the one who
    # forgot. Measured on the reference consumer's register, where one such row had been
    # reporting its debt open on every pull since the day it was closed, and filed as
    # PC-S302-AUDIT-LAYER-DEBT-SILENTLY-IGNORES-A-STRING-CLOSES-OWED.
    #
    # COERCED AND COUNTED, NOT SILENTLY REPAIRED. A quiet fix here would make the register's
    # schema unenforceable by making its violation harmless, which is the same defect one level
    # up; the count is surfaced beside `malformed` so the row still gets corrected.
    co = r.get("closes_owed")
    if isinstance(co, str):
        co, mistyped = [co], mistyped + 1
    elif co is None:
        co = []
    elif not isinstance(co, list):
        co, mistyped = [], mistyped + 1
    for cid in co:
        closed.add(cid)

open_items = [v for k, v in declared.items() if k not in closed]
open_items.sort(key=lambda d: (d["opened"], d["id"]))

# THE MIGRATION ARM. Prose that reads like an obligation, on a row declaring none. A
# suspicion, not a commitment, so it is reported apart and never folded into the count.
# A cue EMBEDDED IN A LONGER IDENTIFIER is not prose about an obligation: `debt` inside
# `test-check18-debt-audit` is a filename, and it was 1 of the 2 false positives measured
# on the reference register. Require the cue to stand alone, not to sit between hyphens.
PROSE = re.compile(r"(?<![\w-])(owed|still owed|deferred|remediation|follow-?up|debt|TODO)(?![\w-])", re.I)
undeclared = []
for r in rows:
    if isinstance(r.get("owed"), dict):
        continue
    reason = r.get("reason", "") or ""
    hits = sorted({m.lower() for m in PROSE.findall(reason)})
    if hits:
        undeclared.append({"entry": r.get("entry", ""), "recorded_utc": r.get("recorded_utc", ""),
                           "verdict": r.get("verdict", ""), "cues": hits})

if as_json:
    print(json.dumps({"open": open_items, "undeclared": undeclared,
                      "rows": len(rows), "malformed": malformed,
                      "mistyped_closes_owed": mistyped}, indent=1))
    raise SystemExit(0)

print("LAYER DEBT  register=%s  rows=%d%s%s"
      % (path, len(rows), ("  MALFORMED=%d" % malformed) if malformed else "",
         ("  MISTYPED_CLOSES_OWED=%d (coerced to a list for this run; the schema says array — fix the row)"
          % mistyped) if mistyped else ""))
print()
if open_items:
    print("OPEN (%d) — declared by a row, closed by none:" % len(open_items))
    for d in open_items:
        print("  %s  [%s]" % (d["id"], d["entry"].split("/")[-1]))
        print("      what: %s" % d["what"])
        if d["closes_when"]:
            print("      closes when: %s" % d["closes_when"])
        print("      opened: %s" % d["opened"])
else:
    print("OPEN (0) — no row declares an undischarged `owed` object.")
print()
if undeclared:
    print("UNDECLARED (%d) — reason prose reads like an obligation, row declares no `owed`:" % len(undeclared))
    for u in undeclared:
        print("  %-44s %-16s cues: %s" % (u["entry"].split("/")[-1][:44], u["verdict"], ",".join(u["cues"])))
    print()
    print("  These are the migration backlog: re-record each with an `owed` object so it can be")
    print("  enumerated and closed. A prose obligation is invisible to every reader but a grep.")
else:
    print("UNDECLARED (0) — no row's prose reads like an undeclared obligation.")
PY
