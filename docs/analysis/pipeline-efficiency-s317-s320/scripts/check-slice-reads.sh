set -uo pipefail
# usage: check-slice-reads.sh <extract.py> <fixture-root>; exit 0 = a sliced re-read does not enter a step
X="$1"; R="$2"
[ -f "$X" ] && [ -f "$R/lead.jsonl" ] || exit 9
O=$(mktemp -d) || exit 9
EXTRACT_ROOT="$R" python3 "$X" "$O" >/dev/null 2>&1 || exit 1
python3 -c "import json,sys;o=json.load(open(sys.argv[1]+'/owner.json'));sys.exit(0 if o['toolu_a_slice'][1]=='carry-over-evaluation' and o['toolu_a_gate'][1]=='gate-validation[carry-over-evaluation]' else 1)" "$O"
