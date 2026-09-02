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
  echo "audit-layer-debt: DISARMED — EXAMINED NOTHING — no register at $REGISTER. This is not 'zero open debts'; nothing was read." >&2
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


# ONE PREDICATE, ONE READER. `closes_owed` is now read by two arms — the debt join below and
# the migration arm at the foot — and a restated coercion is how those two come to disagree
# about whether a row discharges anything. A row that closes a debt for the join and does not
# for the migration arm is the worst of both: the debt goes closed AND the row is filed as
# undeclared. Single-sourced here so the two arms cannot drift apart.
#
# MISTYPED IS STILL A CLOSE. A bare-string `closes_owed` is a schema violation and is counted
# as one, but the row plainly MEANS to discharge, and the join already honours it — so the
# migration arm must honour it too or the two readers answer differently on the same row.
def closes_ids(r):
    """(ids, mistyped) — the ids this row discharges, coerced exactly as the join coerces."""
    co = r.get("closes_owed")
    if isinstance(co, str):
        return [co], 1
    if co is None:
        return [], 0
    if not isinstance(co, list):
        return [], 1
    return co, 0


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
    co, bad = closes_ids(r)
    mistyped += bad
    for cid in co:
        closed.add(cid)

open_items = [v for k, v in declared.items() if k not in closed]
open_items.sort(key=lambda d: (d["opened"], d["id"]))

# A `contradicts-core` verdict is the ONE judgement in this system that no detector can
# re-derive. SKILL.md says so where the verdict is defined: `layer-drift.sh` emits
# EXTENSION-RESTATES-CORE when an extension COPIES core, but an extension asserting the
# OPPOSITE of core in its own words restates nothing and matches nothing, and core forbids
# building a textual contradiction detector instead. So the register row IS the finding.
#
# AND THE ROW EXPIRES. The adjudication key is (clause, entry, subject_digest), and the
# digest covers the entry and the core file it hooks — deliberately, because a verdict is "a
# record of a reading, not an exemption for a path". That is right for `still-additive`,
# where the reading is the whole claim. It is wrong for `contradicts-core`, where the reading
# expires and the CONFLICT does not: the moment either file moves, the ruling is keyed to a
# digest nothing will ever look up again. It is not overwritten, it becomes unaddressable,
# and no later row contradicts it because later rows carry different digests.
#
# Measured on the reference consumer: a contradicts-core ruling recorded 2026-08-05 sat
# unactioned for nine days while ten later rows on the same entry recorded `still-additive`
# against their own subjects, none of them wrong and none of them about it. Filed as
# PC-S330-A-CONTRADICTS-CORE-VERDICT-EXPIRES-LIKE-A-READING-AND-STOPS-BEING-SURFACED.
#
# `owed` IS THE ONLY DIGEST-INDEPENDENT HANDLE IN THE SYSTEM — the debt join above is
# (owed.id -> closes_owed) and never touches subject_digest — so an obligation declared here
# survives every future move of the entry. That is what this arm asks for.
#
# SCOPED TO THE ENTRY, NOT THE ROW, AND THAT IS A SATISFIABILITY PROPERTY RATHER THAN A
# NOISE ONE. This register is append-only: a historical row can never acquire an `owed`, so
# "this row declares no owed" is unsatisfiable by construction the instant the row is
# written, and would name the same rows on every run forever with no act available to clear
# them. The entry is the satisfiable unit, because a LATER row can still speak for it — which
# is how both real debts on the reference consumer were in fact declared.
#
# FALSE-POSITIVE SET, MEASURED ON THE ONLY REGISTER THAT EXISTS, BOTH WAYS: 1 of 7
# contradicts-core entries at the revision before the operator declared the debt, 0 of 7
# after. One known FP PATH remains and is why this reports rather than blocks: an operator
# who records the conflict and FIXES the file immediately owes nothing, declares nothing, and
# the append-only row stands forever. Blocking would wedge them for having acted fast.
owed_entries = {(r.get("clause"), r.get("entry")) for r in rows
                if isinstance(r.get("owed"), dict) and r.get("owed", {}).get("id")}
unowned = sorted({(r.get("clause") or "", r.get("entry") or "") for r in rows
                  if r.get("verdict") == "contradicts-core"} - owed_entries)

# THE MIGRATION ARM. Prose that reads like an obligation, on a row declaring none. A
# suspicion, not a commitment, so it is reported apart and never folded into the count.
# A cue EMBEDDED IN A LONGER IDENTIFIER is not prose about an obligation: `debt` inside
# `test-check18-debt-audit` is a filename, and it was 1 of the 2 false positives measured
# on the reference register. Require the cue to stand alone, not to sit between hyphens.
PROSE = re.compile(r"(?<![\w-])(owed|still owed|deferred|remediation|follow-?up|debt|TODO)(?![\w-])", re.I)
#
# A THIRD FALSE-POSITIVE CLASS, AND IT IS THE ONE THAT PUNISHES THE CORRECT ANSWER. The two
# above are lexical (a cue inside an identifier) and structural (a discharge row). This one is
# GRAMMATICAL: the cue sits inside a clause that DENIES an obligation. `no owed is declared
# because the fixture is consumer-side test coverage`, `No owed: nothing is left outstanding on
# this entry`, `no re-grain is owed`, `GAP CLOSED IN THIS COMMIT rather than deferred`. Every one
# of those is an adjudicator stating, explicitly and correctly, that this row owes nothing — and
# the arm charged them for writing it down.
#
# IT IS SELF-DEFEATING, WHICH IS WHY IT IS WORTH A FIX RATHER THAN A GLANCE. The remedy this
# report prints is "re-record each with an `owed` object". An adjudicator who instead does the
# right thing — says in the reason that no obligation exists — trips the cue by saying so, and
# the register is APPEND-ONLY, so that row can never be cleared by any act. One row on the
# reference register records `audit-layer-debt.sh lists this entry under UNDECLARED on cue
# 'deferred'` and is itself flagged for that sentence: the tool scores its own output as an
# instance of its own subject.
#
# MEASURED ON THE ONLY REGISTER THAT EXISTS — 318 rows, 29 flagged before, 18 after. All 11
# acquitted rows were read in full: 9 deny an obligation in as many words (`no owed`/`No owed:`/
# `no new owed`/`no re-grain is owed`), 2 draw an explicit contrast (`rather than deferred`,
# `rather than declared as consumer debt`). The false-acquittal set is EMPTY and enumerated.
#
# PER OCCURRENCE, NEVER PER ROW, and that is what keeps recall. A row is still reported when ANY
# cue survives, so a reason that denies one obligation and states another is still caught. The
# two genuine debts on the reference register — both opening `OWED REMEDIATION, deferred by
# operator decision` and both saying `Nothing but this reason field is tracking that debt` —
# survive this narrowing, asserted as an arm rather than assumed.
#
# `nothing` IS DELIBERATELY NOT A NEGATOR. It reads like one and it is the exact word the
# strongest TRUE positive in the corpus uses: *"Nothing but this reason field is tracking that
# debt."* Admitting it would acquit the sentence this whole file exists to surface. `not` and
# `never` are excluded for a weaker version of the same reason — measured, they acquitted two
# rows on a `not` governing an unrelated clause, reaching the right verdict for the wrong reason.
#
# THE FILED REMEDY WAS REFUTED BY BUILDING IT, and the refutation is the reusable part.
# `PC-S340-UNDECLARED-CUE-CANNOT-TELL-A-REFERENCE-FROM-A-DECLARATION` asked to skip a row whose
# cue occurrences all sit inside a resolvable `OWED-<id>` token. That removes 0 of 29, because a
# cue occurrence INSIDE such a token is unconstructible: the `(?![\w-])` lookahead above already
# refuses it. Control: `OWED-DEBT` and `OWED-DEFERRED-X` — ids built entirely out of cue words —
# yield zero cue matches, while `debt deferred` standing alone yields two. The citation shape is
# real, but the cue is always a SEPARATE word elsewhere in the reason, so the filing named a
# mechanism that cannot fire.
NEGATED = re.compile(r"\bno\b|\brather than\b|\binstead of\b", re.I)
# A clause ends at `.`, `;` or `:`. Bounding on those and searching only the text BEFORE the cue
# is what stops a negator in a neighbouring sentence from acquitting an obligation two sentences
# later — the failure a whole-reason search has.
CLAUSE_END = re.compile(r"[.;:]")


def cue_denied(reason, m):
    """True when the cue's own clause denies an obligation before reaching the cue."""
    start = 0
    for b in CLAUSE_END.finditer(reason, 0, m.start()):
        start = b.end()
    return bool(NEGATED.search(reason, start, m.start()))


#
# A SECOND FALSE-POSITIVE CLASS, AND IT IS STRUCTURAL WHERE THE ONE ABOVE IS LEXICAL. The
# cue narrowing cannot reach it: the prose on a DISCHARGE row is genuinely about a debt, and
# the row genuinely declares no new one. The correct way to close a debt is to carry
# `closes_owed` and to say so in `reason` — and every discharge row on the reference register
# opens its reason `Debt discharged.`, which trips the `debt` cue. So the arm charged the
# operator for doing the right thing, and its noise GREW BY ONE EVERY TIME A DEBT WAS
# CORRECTLY CLOSED: the consumer discharged six and watched the count rise by exactly six.
# Measured on the reference register at the time of this change: 33 flagged, 9 of them
# carrying `closes_owed`, i.e. 27% noise against a genuine remainder of 24.
#
# THE EXEMPTION DOES NOT COVER THIS ARM'S OWN SUBJECT, and that is asserted rather than
# assumed. Its subject is an obligation nobody declared. A discharge row that ALSO incurs a
# NEW obligation is still reachable: the schema permits `owed` and `closes_owed` on one row,
# so such a row declares the new debt explicitly and lands in the register proper. Requiring
# that explicit `owed` keeps the case in scope instead of exempting it — which is why the
# skip below reads `closes_ids`, not "mentions a debt".
undeclared = []
for r in rows:
    if isinstance(r.get("owed"), dict):
        continue
    if closes_ids(r)[0]:
        continue
    reason = r.get("reason", "") or ""
    # The surviving cues, not every cue. What is reported is what still reads as an obligation,
    # so the `cues:` column names the words that actually earned the row its place.
    hits = sorted({m.group(0).lower() for m in PROSE.finditer(reason)
                   if not cue_denied(reason, m)})
    if hits:
        undeclared.append({"entry": r.get("entry", ""), "recorded_utc": r.get("recorded_utc", ""),
                           "verdict": r.get("verdict", ""), "cues": hits})

if as_json:
    print(json.dumps({"open": open_items, "undeclared": undeclared,
                      "rows": len(rows), "malformed": malformed,
                      "mistyped_closes_owed": mistyped,
                      "contradicts_core_unowed": [{"clause": c, "entry": e}
                                                  for c, e in unowned]}, indent=1))
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
print()
if unowned:
    print("CONTRADICTS-CORE WITHOUT AN `owed` (%d) — a ruling nothing will surface again:" % len(unowned))
    for c, e in unowned:
        print("  %-16s %s" % (c, e))
    print()
    print("  A `contradicts-core` verdict is the one judgement no detector can re-derive, and it is")
    print("  keyed on a subject_digest that expires the next time the entry or its hooked core file")
    print("  moves. After that the ruling is not overwritten — it is unaddressable, and no later row")
    print("  disagrees with it because later rows carry different digests. `owed` is the only handle")
    print("  in this register that survives a digest change, because the debt join never reads one.")
    print("  Declare an `owed` on the entry naming the migration, or — if the conflict was already")
    print("  resolved rather than deferred — record that resolution, so the ruling stops reading as")
    print("  live work nobody is doing.")
else:
    print("CONTRADICTS-CORE WITHOUT AN `owed` (0) — every contradicts-core entry declares its debt.")
PY
