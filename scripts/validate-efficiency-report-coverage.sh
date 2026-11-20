#!/usr/bin/env bash
# validate-efficiency-report-coverage.sh -- arm PE1: a pipeline-efficiency report written under
# docs/plans/pipeline-efficiency-analysis.md carries one DECLARED section per step file.
#
# Population: docs/analysis/pipeline-efficiency-*.md (top level); none at all prints SKIP and
# exits 0 (pre-migration tree). A report DECLARES itself when the
# literal `(../plans/pipeline-efficiency-analysis.md)` appears in its first 5 lines. Five older
# reports predate the runbook and are hard-listed below (SKIP). Any other report that does not
# declare FAILS: a new report must declare. Zero declaring reports FAILS (cannot go green on nothing).
#
# Expected list per declaring report: every *.md in core/skills/ai-dlc/steps/ (underscore files
# included) as of the report's first-add commit (the working tree's directory when the report is
# untracked), plus the fixed entry ai-dlc-update/SKILL.md. A later step file does not fail a
# committed report; a new report must cover it.
#
# Declaration grammar: inside a `### ` section, outside ``` fences, a line starting `Step files: `
# followed by backticked tokens. Each token is a bare step basename (x.md) or ai-dlc-update/SKILL.md;
# anything else on such a line (a full path, no token, stray words) is MALFORMED and FAILS with its
# line number. A declared name COUNTS only if it also appears (word-bounded) on another,
# non-declaration line of the same section.
#
# Proves COVERAGE only, not the quality of the analysis. Honours AI_DLC_PROJECT_ROOT.
# Exit: 0 = pass, 1 = finding, 2 = refusal (git failure, empty expected list, unusable root).
pe1_main() {
set -uo pipefail

if [ -n "${AI_DLC_PROJECT_ROOT:-}" ]; then
  ROOT="$AI_DLC_PROJECT_ROOT"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
cd "$ROOT" || { echo "PE1: cannot enter root $ROOT" >&2; exit 2; }

STEPS_DIR="core/skills/ai-dlc/steps"
UPDATE_ENTRY="ai-dlc-update/SKILL.md"
DECL_LINK='(../plans/pipeline-efficiency-analysis.md)'
LEGACY="pipeline-efficiency-s317-s318.md pipeline-efficiency-s317-s322.md pipeline-efficiency-s317-s322-b259.md pipeline-efficiency-s323-provisional-b259.md pipeline-efficiency-s323-complete-b261.md"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pe1.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT

REPORTS="$(find docs/analysis -maxdepth 1 -type f -name 'pipeline-efficiency-*.md' 2>/dev/null | sort)"
if [ -z "$REPORTS" ]; then
  echo "SKIP: no pipeline-efficiency reports in $ROOT"
  exit 0
fi

rc=0
declaring=0
while IFS= read -r rpt; do
  [ -n "$rpt" ] || continue
  base="${rpt##*/}"
  skip=0
  for l in $LEGACY; do [ "$l" = "$base" ] && skip=1; done
  if [ "$skip" = 1 ]; then
    echo "SKIP $rpt (legacy, predates the runbook)"
    continue
  fi
  head5="$(head -n 5 "$rpt")"
  if ! grep -qF -- "$DECL_LINK" <<<"$head5"; then
    echo "PE1: $rpt does not declare itself under docs/plans/pipeline-efficiency-analysis.md (no ${DECL_LINK} in its first 5 lines) and is not one of the five legacy reports; a new report must declare." >&2
    rc=1
    continue
  fi
  declaring=$((declaring + 1))

  # Expected list.
  C=""
  if git ls-files --error-unmatch -- "$rpt" >/dev/null 2>&1; then
    if ! C="$(git log --no-renames --diff-filter=A --format=%H -- "$rpt" | tail -n 1)"; then
      echo "PE1: git log failed for $rpt" >&2; exit 2
    fi
  fi
  : >"$TMP/expected"
  if [ -n "$C" ]; then
    where="$(git rev-parse --short "$C" 2>/dev/null)" || where="$C"
    if ! git ls-tree --name-only "${C}:${STEPS_DIR}/" >"$TMP/lsout" 2>"$TMP/lserr"; then
      echo "PE1: git ls-tree of ${STEPS_DIR}/ at $C failed: $(cat "$TMP/lserr")" >&2; exit 2
    fi
    grep -E '\.md$' "$TMP/lsout" >"$TMP/expected" || true
  else
    where="working tree"
    if [ -d "$STEPS_DIR" ]; then
      ( cd "$STEPS_DIR" && /bin/ls -1 ) | grep -E '\.md$' >"$TMP/expected" || true
    fi
  fi
  nexp="$(grep -c . "$TMP/expected")" || nexp=0
  if [ "$nexp" -eq 0 ]; then
    echo "PE1: expected step list for $rpt is empty (${STEPS_DIR}/ at ${where}); refusing" >&2
    exit 2
  fi
  echo "$UPDATE_ENTRY" >>"$TMP/expected"

  # One awk pass: MALFORMED lines and the names that COUNT.
  awk '
    function bounded(line, name,   s, p, off, prev) {
      off = 0; s = line
      while ((p = index(s, name)) > 0) {
        prev = (off + p > 1) ? substr(line, off + p - 1, 1) : ""
        if (prev == "" || prev !~ /[A-Za-z0-9_-]/) return 1
        off += p; s = substr(s, p + 1)
      }
      return 0
    }
    function flush(   i, j) {
      for (i = 1; i <= nd; i++)
        for (j = 1; j <= nl; j++)
          if (bounded(lines[j], dn[i])) { print "OK " dn[i]; break }
      nd = 0; nl = 0
    }
    BEGIN { insec = 0; fence = 0; nd = 0; nl = 0 }
    /^[[:space:]]*```/ { fence = !fence; if (insec) lines[++nl] = $0; next }
    !fence && /^##+ / {
      flush()
      insec = ($0 ~ /^### /) ? 1 : 0
      next
    }
    !fence && /^Step files: / {
      rest = $0; sub(/^Step files: /, "", rest)
      if (!insec) { print "BAD " NR " Step files: line outside any ### section"; next }
      ntok = 0; bad = 0; tmp = rest
      while (match(tmp, /`[^`]*`/)) {
        tok = substr(tmp, RSTART + 1, RLENGTH - 2)
        tmp = substr(tmp, 1, RSTART - 1) " " substr(tmp, RSTART + RLENGTH)
        ntok++
        if (tok == "ai-dlc-update/SKILL.md" || tok ~ /^[A-Za-z0-9_-]+\.md$/) dn[++nd] = tok
        else { print "BAD " NR " token `" tok "` is not a bare step basename"; bad = 1 }
      }
      gsub(/(^| )and( |$)/, " ", tmp); gsub(/[ ,]/, "", tmp)
      if (ntok == 0) print "BAD " NR " no backticked token"
      else if (tmp != "" && !bad) print "BAD " NR " stray text beside the tokens"
      next
    }
    { if (insec) lines[++nl] = $0 }
    END { flush() }
  ' "$rpt" >"$TMP/awkout"

  miss=0
  while IFS= read -r bad; do
    [ -n "$bad" ] || continue
    echo "PE1: $rpt line ${bad#BAD }: MALFORMED declaration" >&2
    miss=1
  done < <(grep '^BAD ' "$TMP/awkout" | sed -e 's/^BAD \([0-9]*\) /BAD \1: /')
  n=0; total=0
  awkout="$(cat "$TMP/awkout")"
  while IFS= read -r want; do
    [ -n "$want" ] || continue
    total=$((total + 1))
    if grep -qxF -- "OK $want" <<<"$awkout"; then
      n=$((n + 1))
    else
      echo "PE1: $rpt declares itself under docs/plans/pipeline-efficiency-analysis.md but has no counted \`Step files:\` declaration for $want (expected list: core/skills/ai-dlc/steps/ at $where plus ai-dlc-update/SKILL.md). This proves COVERAGE only (each step has a declared section that discusses it), not the quality of the analysis in it. Runbook action 2's per-engine-version union (a) and the consumer's extensions (d) are not checked." >&2
      miss=1
    fi
  done <"$TMP/expected"
  if [ "$miss" = 0 ]; then
    echo "PASS $rpt ($n of $total)"
  else
    rc=1
  fi
done <<<"$REPORTS"

if [ "$declaring" -eq 0 ]; then
  echo "PE1: no pipeline-efficiency report declares itself under the runbook; the check cannot pass on nothing" >&2
  exit 1
fi
exit "$rc"
}
pe1_main "$@"
