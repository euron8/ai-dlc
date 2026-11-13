set -uo pipefail
# usage: check-gate-terminator.sh <extract.py> <fixture-root>; exit 0 = a gate the lead never closes ends at a whole
# read of another step, and a gate the lead is still in (done resume, whole read of M, sliced read) keeps its label.
# A gate-checkpoint.sh record after leaving returns to the gate, and a gate opened before any step was entered
# (pre-step) is never left.
# Fixture root: fixture-gate-terminator/ (one lead transcript per world, so scan state never carries between worlds).
# Prints one line per world; exit 1 if any world reads FAIL.
X="$1"; R="$2"
[ -f "$X" ] && [ -f "$R/w1leave.jsonl" ] || exit 9
O=$(mktemp -d) || exit 9
trap 'rm -rf "$O"' EXIT
EXTRACT_ROOT="$R" python3 "$X" "$O" >/dev/null 2>"$O/err" || exit 1
python3 - "$O" <<'PY'
import json, sys
o = json.load(open(sys.argv[1] + "/owner.json"))
err = open(sys.argv[1] + "/err").read()
M = "gate-validation[carry-over-evaluation]"
want = [
 ("w1 in-gate spawn before leaving",   "w1_in_gate", M),
 ("w1 LEFT: whole read of requirements", "w1_leave", "requirements"),
 ("w2 twin: done resume keeps the gate", "w2_twin", M),
 ("w2 twin: second done keeps the gate", "w2_twin2", M),
 ("w3 LEFT then spawn",                 "w3_mid", "requirements"),
 ("w3 return: slice of gate-validation", "w3_ret", M),
 ("w3 second LEFT after return",        "w3_leave2", "implementation"),
 ("w4 whole read of M stays",           "w4_wholeM", M),
 ("w4 sliced read of another step stays", "w4_slice_other", M),
 ("w4 whole M after slice stays",       "w4_wholeM_after_slice", M),
 ("w4 underscore read is not a step",   "w4_subproc", M),
 ("w5 post-close spawn",                "w5_post_close", "requirements"),
 ("w5 LEFT before replacing open",      "w5_leave_b", "implementation"),
 ("w5 replacing open relabels",         "w5_second_open", "gate-validation[implementation]"),
 ("w6 LEFT before the record",          "w6_mid", "requirements"),
 ("w6 a record after leaving returns",  "w6_rec", M),
 ("w7 a gate opened at pre-step is never left", "w7_pre", "gate-validation[pre-step]"),
]
bad = 0
for label, tid, exp in want:
    got = o.get(tid, [None, None])[1]
    ok = got == exp
    bad += not ok
    print("%s  %s: %s (want %s)" % ("ok  " if ok else "FAIL", label, got, exp))
line = "gate-terminator sprint=320 opens=9 closed=1 unclosed=8 left=5"
ok = line in err
bad += not ok
print("%s  per-sprint counts line" % ("ok  " if ok else "FAIL"))
sys.exit(1 if bad else 0)
PY
rc=$?
rm -rf "$O"
exit $rc
