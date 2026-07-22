#!/usr/bin/env bash
# check-17-counts — assert every known evaluation records its residue.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `findings_critical/major/minor` used to be owed only by a block carrying a
# `verdict` — which in practice meant only the Rule 8 convergence review. The four
# BMAD sub-skills emitted no residue at all, and nothing asked them to.
#
# Measured on the reference consumer across 30+ sprints: of the provenance blocks
# on disk, ai-dlc-adversary-review carried counts on 55 of 55. bmad-party-mode
# carried them on 2 of 276. bmad-advanced-elicitation, 3 of 129.
# bmad-review-adversarial-general, 9 of 356. bmad-validate-prd, 2 of 70.
#
# The consequence is not that those evaluations were worthless. It is that NOBODY
# COULD TELL. Because the convergence review recorded its residue, it is possible
# to say something sharp about it — pass 1 finds real defects (a deadlocked AC, four
# call-site line numbers that exceed the file length, a stale deploy_scope shipping a
# fix to the wrong service), while 12 of 13 second passes find no CRITICAL and no
# MAJOR. No comparable sentence can be written about party-mode at any price,
# because the data was never recorded. An evaluation that records nothing is
# indistinguishable from one that found nothing, and 30 sprints of it accumulate
# into a cost nobody can defend or cut on evidence.
#
# So the assertion here is NOT "the counts are correct" — no fixture can know that.
# It is: a known evaluation that reports no residue is REFUSED, and the example the
# docs teach an agent SATISFIES that refusal. The second half is the one that rots:
# a reader that demands a field the taught example omits fails every honest author,
# which is the exact drift schemas/provenance-block.json exists to make impossible.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping -- NOT guessed. install.sh
# maps `core/scripts/<x>` to `scripts/<x>` at the project root and maps everything
# else under `.claude/`, so on a consumer the validator and the schema land in
# DIFFERENT trees. The consumer branch below previously read `.claude/scripts/`,
# a path install.sh never writes, so it matched nothing and this fixture aborted
# with exit 2 on every consumer while passing in the distribution repo.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-provenance-block.sh" ]; then
  # Distribution repo: everything under core/.
  VALIDATOR="$ROOT/core/scripts/validate-provenance-block.sh"
  SCHEMA="$ROOT/core/schemas/provenance-block.json"
  RETRO_DOC="$ROOT/core/skills/ai-dlc/steps/retro.md"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-provenance-block.sh" ]; then
  # Consumer install: scripts/ at the project root, the rest under .claude/.
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-provenance-block.sh"
  SCHEMA="$ROOT/.claude/schemas/provenance-block.json"
  RETRO_DOC="$ROOT/.claude/skills/ai-dlc/steps/retro.md"
else
  echo "FIXTURE ERROR: validate-provenance-block.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ (consumer)" >&2
  exit 2
fi
[ -f "$SCHEMA" ] || { echo "FIXTURE ERROR: schema not found at $SCHEMA" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

TS="2026-07-19T10:00:00Z"
TID="toolu_01ABCDEFGHIJKLMNOP"

# emit <file> <skill> <extra-lines...>
emit() {
  local f="$1" skill="$2"; shift 2
  { printf '# artifact\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: %s\ninvoked_at: %s\ntool_use_id: %s\nmode: subagent\nlead_role: retro.md\n' \
           "$skill" "$TS" "$TID"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$WORK/$f"
}
verdict_of() { bash "$VALIDATOR" "$WORK/$1" >/dev/null 2>&1 && echo accept || echo refuse; }
expect() { # expect <file> <accept|refuse> <label>
  local got; got="$(verdict_of "$1")"
  [ "$got" = "$2" ] && ok "$3" || bad "$3 -- expected $2, got $got"
}

echo "check-17-counts"

# --- 1. THE RULE FIRES on every sub-skill that used to report nothing ---------
# Each of these is a real invocation shape from the reference consumer: well-formed
# in every other respect, and silent about what it found.
for sk in bmad-party-mode bmad-advanced-elicitation bmad-review-adversarial-general bmad-validate-prd; do
  emit "silent-$sk.md" "$sk"
  expect "silent-$sk.md" refuse "$sk with no residue is refused"
done

# --- 2. Recording the residue is all it takes ---------------------------------
emit counted.md bmad-party-mode 'findings_critical: 0' 'findings_major: 1' 'findings_minor: 3'
expect counted.md accept "the same block with its three counts is accepted"

# ZERO is a reading, not an omission. A party-mode pass that genuinely surfaced
# nothing must be able to SAY so — if reporting zero were refused, the only way to
# pass would be to inflate, and the measurement would be worse than none.
emit zeros.md bmad-party-mode 'findings_critical: 0' 'findings_major: 0' 'findings_minor: 0'
expect zeros.md accept "  a genuine zero residue is accepted, not read as an omission"

# --- 3. Partial residue is not residue ---------------------------------------
# findings_major is the field the stall rung reads. Two of three would let a block
# look answered while the arm that needs it stays blind.
emit partial.md bmad-advanced-elicitation 'findings_critical: 0'
expect partial.md refuse "one count of three is refused (partial is not answered)"
emit blank.md bmad-party-mode 'findings_critical:' 'findings_major: 0' 'findings_minor: 0'
expect blank.md refuse "  a present-but-EMPTY count is refused (rules.required_non_empty)"

# --- 4. MEASURED, NOT GATED — the boundary that keeps Check 24 out of this ----
# A verdict is a convergence-cycle exit signal; Check 24 orders a pass series on it.
# If requiring counts had also required a verdict, every party-mode invocation would
# have been enrolled in a cycle it is not part of. Counts without a verdict must pass.
emit noverdict.md bmad-party-mode 'findings_critical: 0' 'findings_major: 2' 'findings_minor: 0'
expect noverdict.md accept "counts WITHOUT a verdict pass (measured, not gated)"

# --- 5. No regression on the convergence review ------------------------------
emit native.md ai-dlc-adversary-review 'findings_critical: 0' 'findings_major: 0' \
     'findings_minor: 1' 'verdict: EXIT_CONDITION_MET'
expect native.md accept "the Rule 8 convergence pass still passes unchanged"
emit nativebad.md ai-dlc-adversary-review 'verdict: EXIT_CONDITION_MET'
expect nativebad.md refuse "  a verdict with no counts is still refused"

# --- 6. THE ONE THAT ROTS: taught example vs the reader that reads it ---------
# A reader demanding a field the doc omits fails every honest author. Take the
# rendered retro party-mode example straight out of the doc and run the real
# validator over it.
if [ -f "$RETRO_DOC" ]; then
  python3 - "$RETRO_DOC" "$WORK/taught.md" <<'PYEOF' || exit 2
import re, sys
doc, out = sys.argv[1], sys.argv[2]
c = open(doc, encoding="utf-8").read()
i = c.find("BEGIN GENERATED: provenance-block")
if i < 0:
    print("FIXTURE BROKEN: retro.md renders no provenance example", file=sys.stderr); sys.exit(2)
m = re.search(r"^```[^\n]*\n(.*?)^```", c[i:], re.S | re.M)
if not m:
    print("FIXTURE BROKEN: generated region carries no fenced example", file=sys.stderr); sys.exit(2)
taught = m.group(1)
subs = {"invoked_at": "2026-07-19T10:00:00Z", "tool_use_id": "toolu_01ABCDEFGHIJKLMNOP",
        "lead_role": "retro.md", "transcript_path": "_bmad-output/party-mode-transcripts/sprint-1.md@abc1234",
        "findings_critical": "0", "findings_major": "1", "findings_minor": "2"}
lines = []
for line in taught.splitlines():
    k = re.match(r"^([a-z_]+):", line)
    lines.append(f"{k.group(1)}: {subs[k.group(1)]}" if k and k.group(1) in subs else line)
open(out, "w", encoding="utf-8").write("# retro\n\n" + "\n".join(lines) + "\n")
PYEOF
  expect taught.md accept "the example retro.md TEACHES satisfies the reader that READS it"
else
  bad "FIXTURE BROKEN: retro.md not found at $RETRO_DOC"
fi

# --- 7. Non-vacuity: the rule must be reachable from the schema --------------
# If required_for_evaluation vanished from the schema, every assertion above would
# still pass by accepting everything. Assert the flag is actually present.
n="$(python3 -c "
import json,sys
S=json.load(open('$SCHEMA'))
print(sum(1 for f in S['fields'] if f.get('required_for_evaluation')))
" 2>/dev/null)"
if [ "${n:-0}" -eq 3 ]; then
  ok "schema marks exactly 3 fields required_for_evaluation (rule is reachable)"
else
  bad "schema marks ${n:-0} fields required_for_evaluation, expected 3 -- the rule above may be vacuous"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-17-counts: every known evaluation must record its residue;"
  echo "      zero is a reading, partial is not, and a verdict is still not owed."
  exit 0
fi
echo "check-17-counts: $fails assertion(s) FAILED"
exit 1
