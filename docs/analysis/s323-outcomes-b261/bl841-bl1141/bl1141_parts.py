# bl1141_parts.py -- BL-1141: spawn count, subagent dollars and agent-minutes of the five "no measured value"
# parts, on s322 (control: must reproduce the entry's figures) and s323.
# usage: python3 -I bl1141_parts.py <OUT dir holding spawns.jsonl from extract.py + spawns.py>
# A part is a subset of spawns.jsonl rows by (step, role, description regex), the way the entry partitions them.
# Agent-minutes SUM parallel spawns. Exits 1 when a control does not hold: each s322 row must equal the entry's
# recorded count and dollars, and the impossible-part row must be 0.
import json, re, sys
rows = [json.loads(l) for l in open(sys.argv[1] + "/spawns.jsonl")]
PARTS = [
    ("carry-over-evaluation p3 (part + cross)", "carry-over-evaluation", "adversary", r"\bp3\b"),
    ("carry-over-evaluation p3 follow-on (deferral record s322 / repair record s323)", "carry-over-evaluation", "remediator", r"deferral record|Repair p3"),
    ("gate-validation[implementation] gate QA seats", "gate-validation[implementation]", "qa", r"."),
    ("gate-validation[architecture] adjudicator shards", "gate-validation[architecture]", "gate-adjudicator", r"."),
    ("gate-validation[retro] adjudicator shards", "gate-validation[retro]", "gate-adjudicator", r"."),
    ("requirements PRD validate run (s322 spawn / s323 re-run spawn)", None, None, r"^(PRD validate run|Re-run PRD validate)"),
    ("s323 PRD rubric-walk subagents (re-run's walker; earlier 11-17 03:27 walker)", None, None, r"^PRD rubric walk"),
    ("NEVER-PART-ZZQ control (must be 0)", "carry-over-evaluation", "adversary", r"NEVER-PART-ZZQ"),
]
REC = {  # s322 figures recorded in docs/backlog.md BL-1141's table: (spawns, dollars)
    "carry-over-evaluation p3 (part + cross)": (7, 13.10),
    "carry-over-evaluation p3 follow-on (deferral record s322 / repair record s323)": (1, 0.29),
    "gate-validation[implementation] gate QA seats": (4, 10.45),
    "gate-validation[architecture] adjudicator shards": (10, 3.81),
    "gate-validation[retro] adjudicator shards": (9, 3.49),
    "requirements PRD validate run (s322 spawn / s323 re-run spawn)": (1, 1.28),
}
bad = 0
for sp in (322, 323):
    print("== s%d" % sp)
    for name, step, role, rx in PARTS:
        sel = [r for r in rows if r["sprint"] == sp and (step is None or r["step"] == step) and (role is None or r["role"] == role)
               and re.search(rx, r["description"], re.I)]
        usd = sum(r["usd"] for r in sel); mins = sum(r["minutes"] for r in sel)
        line = "  %-84s spawns %2d  $%7.2f  %6.1f agent-min" % (name, len(sel), usd, mins)
        if sp == 322:
            if name in REC:
                ok = len(sel) == REC[name][0] and abs(usd - REC[name][1]) <= 0.015  # entry sums rounded per-label figures
                line += "   control vs entry %s: %s" % (REC[name], "MATCH" if ok else "MISMATCH")
                bad += not ok
            elif name.startswith("NEVER"):
                ok = len(sel) == 0; line += "   control: %s" % ("MATCH" if ok else "MISMATCH"); bad += not ok
        elif name.startswith("NEVER"):
            ok = len(sel) == 0; line += "   control: %s" % ("MATCH" if ok else "MISMATCH"); bad += not ok
        print(line)
        if sp == 323 and not name.startswith("NEVER"):
            for r in sorted(sel, key=lambda r: r["start"]): print("      %s %s $%.3f %s" % (r["start"][:16], r["description"][:60], r["usd"], r["role"]))
print("CONTROLS FAILED:", bad)
sys.exit(1 if bad else 0)
