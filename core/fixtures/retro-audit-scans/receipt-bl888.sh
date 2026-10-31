#!/usr/bin/env bash
# Receipt: on a fresh consumer install, audit-rule-files.sh's NARRATIVE_DRIFT class reports only the
# rule text that is meant to carry its measurement or a present-tense `used to`, and the twenty-one
# rule sentences that told their own history state their rule in the present tense.
# Usage: receipt-bl888.sh [<root>]      (<root> = a distribution tree; default .)
# Builds a consumer install of <root> (git init a mktemp dir, one empty commit, `_bmad/`, then
# `scripts/install.sh <dir>`) and asserts four arms:
#   (a) `audit-rule-files.sh --fail-on=local` in the install gives exactly 11 NARRATIVE_DRIFT finding
#       rows, matched one-to-one to the KEEP list below (file + stable text substring, never a line
#       number); and each of the 21 rewritten sentences -- located by an anchor on text the rewrite left
#       unchanged, a window of lines around it, joined -- carries none of the history words in HIST.
#   (b) a seeded `docs/coding-conventions.md` line "The step used to stop here." (not core in an
#       install; core-paths.sh --is-core says so) is reported `[local]` and the audit exits 1; a seeded
#       `.claude/rules/zz.md` line (core in an install) is reported `[core]`.
#   (c) `Measured:` is still in installed remediator.md and adversary.md, and `ORPHANED-RELOCATED`
#       still co-occurs with `used to` in installed ai-dlc-update/SKILL.md.
#   (d) `scripts/render-postcompact-digest.sh --check` exits 0 in <root>.
# 0 = every arm holds. 1 = an arm failed (each failing arm prints a FAIL line naming it).
# 9 = no verdict: no install.sh (a consumer tree), the install or the audit could not run, or an
#     anchor matched other than exactly one line.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
[ -f "$ROOT/scripts/install.sh" ] || { echo "REFUSED: no scripts/install.sh under $ROOT" >&2; exit 9; }
T="$(mktemp -d "${TMPDIR:-/tmp}/bl888.XXXXXX")" || exit 9
[ -d "$T" ] || exit 9
trap 'rm -rf "$T"' EXIT
C="$T/c"
mkdir -p "$C/_bmad" || exit 9
git -C "$C" init -q || exit 9
git -C "$C" -c user.email=r@r -c user.name=r commit -q --allow-empty -m init || exit 9
bash "$ROOT/scripts/install.sh" "$C" > "$T/install.out" 2>&1 || { echo "REFUSED: install.sh failed" >&2; tail -5 "$T/install.out" >&2; exit 9; }
AUD="$C/scripts/ai-dlc/audit-rule-files.sh"
[ -f "$AUD" ] || { echo "REFUSED: no installed audit-rule-files.sh" >&2; exit 9; }
rc=0
fail() { echo "FAIL: $1"; rc=1; }

# ---- arm (a): exactly the KEEP list, one-to-one
( cd "$C" && bash scripts/ai-dlc/audit-rule-files.sh --fail-on=local ) > "$T/a.out" 2> "$T/a.err"
arc=$?
[ "$arc" -eq 0 ] || [ "$arc" -eq 1 ] || { echo "REFUSED: audit exit $arc" >&2; exit 9; }
KEEP="$T/keep"
cat > "$KEEP" <<'EOF'
.claude/skills/ai-dlc/steps/gate-validation.md	Measured: a sprint whose operator
.claude/skills/ai-dlc/steps/handoff.md	Measured: a handoff
.claude/team-roles/adversary.md	Measured: a cycle ran thirteen passes
.claude/team-roles/remediator.md	Measured: a repair removed the predicate
.claude/team-roles/remediator.md	Measured: 13 passes
.claude/skills/ai-dlc-update/SKILL.md	every fixture driving it goes red. Measured:
.claude/skills/ai-dlc-update/reconcile/predicate-sites.md	measured: that hook invokes ten
.claude/skills/ai-dlc-update/SKILL.md	**used to** write and no longer targets
.claude/skills/ai-dlc/steps/discovery.md	Where the blocks used to sit
.claude/skills/ai-dlc/steps/stories-test-strategy.md	that used to collide with it
.claude/skills/ai-dlc/steps/stories-test-strategy.md	used to append
EOF
awk -v kf="$KEEP" '
  BEGIN { FS = "\t"; while ((getline l < kf) > 0) { split(l, p, "\t"); n++; kp[n] = p[1]; ks[n] = p[2] } FS = " " }
  /^  \[(core|local)\] [^ ]+:[0-9]+  NARRATIVE_DRIFT  / {
    rows++
    path = $2; sub(/:[0-9]+$/, "", path)
    t = $0; sub(/^.*  NARRATIVE_DRIFT  /, "", t)
    hit = 0
    for (i = 1; i <= n; i++) if (kp[i] == path && index(t, ks[i]) > 0) { hit++; used[i]++ }
    if (hit != 1) printf "FAIL: arm (a) finding matches %d KEEP entries: %s %s\n", hit, $1, $2
  }
  END {
    for (i = 1; i <= n; i++) if (used[i] != 1) printf "FAIL: arm (a) KEEP entry matched %d findings: %s | %s\n", used[i] + 0, kp[i], ks[i]
    if (rows != 11) printf "FAIL: arm (a) NARRATIVE_DRIFT finding rows = %d, want 11\n", rows
    printf "arm (a) NARRATIVE_DRIFT finding rows: %d\n", rows
  }' "$T/a.out" > "$T/a.verdict"
cat "$T/a.verdict"
nf="$(grep -c '^FAIL' "$T/a.verdict")" || nf=0
[ "$nf" -eq 0 ] || rc=1

# Rewritten sentences: file <TAB> lines-before <TAB> lines-after <TAB> anchor (fixed string, unchanged
# by the rewrite). The window [anchor-before, anchor+after] holds the whole rewritten sentence.
HIST='previously|formerly|no longer|once (said|read)|used to|was (changed|moved)|before (it|this) (was|changed)'
cat > "$T/rw" <<'EOF'
.claude/skills/ai-dlc-update/SKILL.md	0	1	**BOTH exclusions bind BOTH terms
.claude/skills/ai-dlc-update/SKILL.md	0	1	That call already returns them;
.claude/skills/ai-dlc-update/SKILL.md	0	2	`at_self_update()` was present in the installed copy throughout
.claude/skills/ai-dlc-update/SKILL.md	0	1	arg-5 ledger path is not a readable file.
.claude/skills/ai-dlc-update/SKILL.md	0	3	THE TWO SCRIPTS TAKE DIFFERENT BASES ON THIS RE-RUN
.claude/skills/ai-dlc-update/SKILL.md	0	0	renders the `DRIFT-RANGE-DEGENERATE` row
.claude/skills/ai-dlc-update/SKILL.md	0	3	*Why this is its own bullet.*
.claude/skills/ai-dlc-update/SKILL.md	1	3	`NAMED-UPSTREAM-AMBIGUOUS` details
.claude/skills/ai-dlc/SKILL.md	0	3	It is a marker, and no gate
.claude/skills/ai-dlc/SKILL.md	0	0	**Carrier:** `.claude/rules/ai-dlc-resident-discipline.md`
.claude/skills/ai-dlc/postcompact-digest.md	0	0	**Carrier:** `.claude/rules/ai-dlc-resident-discipline.md`
.claude/skills/ai-dlc/artifact-path-grammar.md	0	1	And that validator closes MOST of the gap
.claude/skills/ai-dlc/steps/artifact-consolidation.md	0	1	**at these paths**
.claude/skills/ai-dlc/steps/artifact-consolidation.md	0	5	**DELETE both drafts. KEEP the manifest
.claude/skills/ai-dlc/steps/discovery.md	1	0	A durable artifact carries no sprint token
.claude/skills/ai-dlc/steps/discovery.md	0	0	0 block(s), 0 claim(s) verified
.claude/skills/ai-dlc/steps/gate-validation.md	0	0	the two roads to exit 0
.claude/skills/ai-dlc/steps/gate-validation.md	0	3	Autonomous Gate Protocol
.claude/skills/ai-dlc/steps/gate-validation.md	0	0	carries no `capabilities:` frontmatter field
.claude/skills/ai-dlc/steps/retro.md	0	0	a hole and a missing anchor are the
.claude/team-roles/adversary.md	0	0	What the ceiling exists to end is the plateau
EOF
nrw=0; nhit=0
while IFS="$(printf '\t')" read -r f b a anc; do
  nrw=$((nrw + 1))
  [ -f "$C/$f" ] || { echo "REFUSED: installed file absent: $f" >&2; exit 9; }
  w="$(ANC="$anc" awk -v b="$b" -v a="$a" '
    { L[NR] = $0; if (index($0, ENVIRON["ANC"]) > 0) { c++; at = NR } }
    END { if (c != 1) { print "ANCHOR-COUNT " c + 0; exit }
          s = ""; for (i = at - b; i <= at + a; i++) s = s " " L[i]
          gsub(/[[:space:]]+/, " ", s); print s }' "$C/$f")"
  case "$w" in "ANCHOR-COUNT "*) echo "REFUSED: anchor matched ${w#ANCHOR-COUNT } lines (want 1): $f | $anc" >&2; exit 9 ;; esac
  if grep -Eiq "$HIST" <<<"$w"; then
    nhit=$((nhit + 1))
    m="$(grep -Eio "$HIST" <<<"$w" | head -1)"
    fail "arm (a) rewritten sentence carries history word \"$m\": $f | $anc"
  fi
done < "$T/rw"
[ "$nrw" -eq 21 ] || { echo "REFUSED: $nrw rewritten-sentence rows, want 21" >&2; exit 9; }
echo "arm (a) rewritten sentences: $nrw checked, $nhit carry a history word"

# ---- arm (b): a not-core seed is [local] and fails --fail-on=local; a core seed is [core]
( cd "$C" && bash scripts/ai-dlc/core-paths.sh --is-core docs/coding-conventions.md ) > /dev/null 2>&1
nc=$?
( cd "$C" && bash scripts/ai-dlc/core-paths.sh --is-core .claude/rules/zz.md ) > /dev/null 2>&1
ic=$?
[ "$nc" -eq 1 ] && [ "$ic" -eq 0 ] || { echo "REFUSED: core-paths --is-core gave $nc (coding-conventions, want 1) and $ic (rules/zz.md, want 0)" >&2; exit 9; }
[ -f "$C/docs/coding-conventions.md" ] || { echo "REFUSED: installed docs/coding-conventions.md absent" >&2; exit 9; }
printf 'The step used to stop here.\n' >> "$C/docs/coding-conventions.md"
printf 'The step used to stop here.\n' > "$C/.claude/rules/zz.md"
( cd "$C" && bash scripts/ai-dlc/audit-rule-files.sh --fail-on=local ) > "$T/b.out" 2> "$T/b.err"
brc=$?
bo="$(cat "$T/b.out")"
[ "$brc" -eq 1 ] || fail "arm (b) seeded audit exit $brc, want 1"
grep -Eq '^  \[local\] docs/coding-conventions\.md:[0-9]+  NARRATIVE_DRIFT  The step used to stop here\.' <<<"$bo" \
  || fail "arm (b) seeded docs/coding-conventions.md line not reported [local] NARRATIVE_DRIFT"
grep -Eq '^  \[core\] \.claude/rules/zz\.md:[0-9]+  NARRATIVE_DRIFT  The step used to stop here\.' <<<"$bo" \
  || fail "arm (b) seeded .claude/rules/zz.md line not reported [core] NARRATIVE_DRIFT"

# ---- arm (c): the measurements and the present-tense `used to` survive
for f in .claude/team-roles/remediator.md .claude/team-roles/adversary.md; do
  n="$(grep -c 'Measured:' "$C/$f")" || n=0
  [ "$n" -ge 1 ] || fail "arm (c) no 'Measured:' in installed $f"
done
co="$(awk '/`ORPHANED-RELOCATED` \(status `O`\)/ { on = 3; s = "" } on > 0 { s = s " " $0; on--; if (!on && s ~ /used to/) print "yes" }' "$C/.claude/skills/ai-dlc-update/SKILL.md")"
[ -n "$co" ] || fail "arm (c) ORPHANED-RELOCATED no longer co-occurs with 'used to' in installed ai-dlc-update/SKILL.md"

# ---- arm (d): the rendered digest matches its source
( cd "$ROOT" && bash scripts/render-postcompact-digest.sh --check ) > "$T/d.out" 2>&1 || fail "arm (d) render-postcompact-digest.sh --check exit non-zero"

[ "$rc" -eq 0 ] && echo "PASS: 11 NARRATIVE_DRIFT rows, all KEEP; 21 rewritten sentences in the present tense; seeds flagged; digest current"
exit "$rc"
