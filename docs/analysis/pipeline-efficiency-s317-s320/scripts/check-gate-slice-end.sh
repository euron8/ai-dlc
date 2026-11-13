set -uo pipefail
# usage: check-gate-slice-end.sh <extract.py> <fixture-root>; exit 0 = a gate whose terminal verdict record (Check 26) has
# been written ends there, so a later spawn after a SLICED read of another step file joins that step (BL-1035), while
# a resume `done` and a non-terminal record inside a live gate keep the gate label (the twin).
# Fixture root: fixture-gate-slice-end/ (one lead transcript per world, so scan state never carries between worlds).
#   w1terminal: carry-over-evaluation read whole, open, an in-gate spawn, done, record 26 PASS, a late record 12 PASS
#     (graph s322's order: 13:55:24Z then 13:59:05Z), two offset/limit slices of requirements.md, then a spawn.
#   w2twin: carry-over-evaluation read whole, open, an in-gate spawn, a resume done, a spawn, record 14 PASS, a spawn.
#   w3sliceother: carry-over-evaluation read whole, open, an in-gate spawn, an offset/limit slice of requirements.md
#     with no record 26 written, then a spawn (check-gate-terminator.sh's w4 "sliced read of another step stays").
#     It fails an UNCONDITIONED candidate 2, where any slice of another step file leaves the gate.
# Prints one line per spawn; exit 1 if any reads FAIL (the defect is live); exit 9 if an input is missing or the
# extractor itself fails (cannot measure).
X="$1"; R="$2"
[ -f "$X" ] && [ -f "$R/w1terminal.jsonl" ] && [ -f "$R/w2twin.jsonl" ] && [ -f "$R/w3sliceother.jsonl" ] || exit 9
O=$(mktemp -d) || exit 9
trap 'rm -rf "$O"' EXIT
EXTRACT_ROOT="$R" python3 -I "$X" "$O" >/dev/null 2>"$O/err" || exit 9
[ -f "$O/owner.json" ] || exit 9
python3 -I - "$O" <<'PY'
import json, sys
o = json.load(open(sys.argv[1] + "/owner.json"))
M = "gate-validation[carry-over-evaluation]"
want = [
 ("w1 in-gate spawn carries the gate label (the world entered the gate)", "w1_in_gate", M),
 ("w1 spawn after record 26 and a sliced read of requirements.md joins requirements", "w1_after_terminal", "requirements"),
 ("w2 in-gate spawn carries the gate label", "w2_in_gate", M),
 ("w2 twin: a resume done inside a live gate keeps the gate label", "w2_after_done", M),
 ("w2 twin: a non-terminal record inside a live gate keeps the gate label", "w2_after_record", M),
 ("w3 in-gate spawn carries the gate label", "w3_in_gate", M),
 ("w3 a slice of another step file before any record 26 keeps the gate label", "w3_after_slice", M),
]
miss = [t for _, t, _ in want if t not in o]
if miss:
    print("CANNOT MEASURE: spawn(s) absent from owner.json: " + " ".join(miss))
    sys.exit(9)
bad = 0
for label, tid, exp in want:
    got = o[tid][1]
    ok = got == exp
    bad += not ok
    print("%s  %s: %s (want %s)" % ("ok  " if ok else "FAIL", label, got, exp))
sys.exit(1 if bad else 0)
PY
rc=$?
rm -rf "$O"
exit $rc
