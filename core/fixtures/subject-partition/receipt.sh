#!/usr/bin/env bash
# subject-partition/receipt.sh <tree> -- BL-458's receipt: the requirements step's validation cycle
# is sharded over its whole SUBJECT, and the gate holds the series to it.
#
#   exit 0   the fix is present in <tree>
#   exit 1   it is not (the line naming the first missing property is printed)
#   exit 9   the receipt cannot measure: no <tree>, or its world could not be built
#
# <tree> is a distribution checkout (core/scripts/) or an installed one (scripts/ai-dlc/). Every
# program is taken from <tree>, never from beside this file, so one receipt scores any build.
#
# THE WORLD (a mktemp git repository, trunk `main`, the sprint on a branch):
#   base   product-brief.md (2 `##` sections, 20 lines each) and a 3-sprint prd.md: `## Current
#          state` (30 lines) and `## Sprint 6..8`, each two `###` subsections of 25 lines. No SPEC.
#          The base PRD ends in a blank line, so the new section's diff starts AT its heading.
#   tree   the brief gains a paragraph; line 7 of `## Current state` -- an EARLIER, cumulative
#          section -- is edited; `## Sprint 9` is appended with three `###` subsections of 40
#          lines each (~260 lines, about 76% of the PRD's in-scope bytes, so its `##` atom splits at
#          its `###` headings: >= 3 PRD parts); a SPEC and s9/architecture-impact.md are new.
# (a) partition-subject.sh --map 9 lists the brief, the SPEC and architecture-impact, >= 3 PRD
#     parts, one of them holding the edited earlier line, and NO part inside an unchanged `##`
#     atom (`## Sprint 6..8`).
# (b) merge-adversarial-shards.sh --subject 9 over seeded shards writes requirements-adversarial-p1
#     with `artifact:` = the subject manifest, the ordinal set + cross, and a RECOMPUTED verdict
#     (every shard stamps MET, the summed residue is over the ceiling -> NOT_MET).
# (c) stamped far above K3_RELEASE before the series opened: the validator exits 0 on a sharded
#     subject series that converges, and exits 1 naming `FAIL (K3` when the terminal pass is a
#     `--document prd.md` merge -- the shape the reference consumer's series actually has.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

TREE="${1:-}"
[ -n "$TREE" ] && [ -d "$TREE" ] || { echo "receipt: no tree named (usage: receipt.sh <tree>)" >&2; exit 9; }
TREE="$(cd "$TREE" && pwd -P)"
S=""
for c in "$TREE/core/scripts" "$TREE/scripts/ai-dlc"; do [ -f "$c/merge-adversarial-shards.sh" ] && { S="$c"; break; }; done
[ -n "$S" ] || { echo "receipt: $TREE carries no merge-adversarial-shards.sh in either layout" >&2; exit 9; }
miss() { echo "receipt: STILL LIVE -- $*"; exit 1; }
[ -f "$S/partition-subject.sh" ] || miss "no partition-subject.sh in $S"

W="$(mktemp -d "${TMPDIR:-/tmp}/subject-receipt.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
P="$W/p"; PA="$P/_bmad-output/planning-artifacts"
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$P" -c user.name=r -c user.email=r@example.invalid -c core.hooksPath=/dev/null "$@"; }
lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
{
  mkdir -p "$PA/s9" "$P/_bmad-output/specs/s9/kernel" "$P/.claude" || exit 9
  g init -q . && g checkout -q -b main || exit 9
  { printf '# Brief\n\n## Vision\n\n'; lorem vision 20; printf '\n## Users\n\n'; lorem users 20; } > "$PA/product-brief.md"
  { printf '# PRD\n\n## Current state\n\n'; lorem current 30
    for s in 6 7 8; do printf '\n## Sprint %s\n\n### Goals\n\n' "$s"; lorem "s$s-goal" 25; printf '\n### Functional requirements\n\n'; lorem "s$s-fr" 25; done
    printf '\n'; } > "$PA/prd.md"
  printf 'version: 9.0.0\n' > "$P/.claude/.ai-dlc-version"
  g add -A && GIT_COMMITTER_DATE=2026-01-01T00:00:00Z GIT_AUTHOR_DATE=2026-01-01T00:00:00Z g commit -q -m base
  g checkout -q -b sprint-9
} >/dev/null 2>&1 || { echo "receipt: could not build the world" >&2; exit 9; }
printf '\nA new brief paragraph for sprint 9.\n' >> "$PA/product-brief.md"
awk '{ if ($0 ~ /^current line 7 of the section/) print "current line 7 EDITED for sprint 9."; else print }' "$PA/prd.md" > "$PA/prd.n" && mv "$PA/prd.n" "$PA/prd.md"
{ printf '## Sprint 9\n\n### Goals\n\n'; lorem s9-goal 40; printf '\n### Functional requirements\n\n'; lorem s9-fr 40
  printf '\n### Non-functional requirements\n\n'; lorem s9-nfr 40; } >> "$PA/prd.md"
printf '# SPEC\n\ncap-1: THE system SHALL review its whole subject.\n' > "$P/_bmad-output/specs/s9/kernel/SPEC.md"
printf -- '- FR-S9-1: architecture_impact: none\n' > "$PA/s9/architecture-impact.md"
EDITED="$(grep -n '^current line 7 EDITED' "$PA/prd.md" | cut -d: -f1)"
[ -n "$EDITED" ] || exit 9
export AI_DLC_PROJECT_ROOT="$P"

# ---- (a) the map ------------------------------------------------------------------------
MAP="$(bash "$S/partition-subject.sh" --map 9 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || miss "(a) partition-subject.sh --map 9 exited $rc: $(printf '%s' "$MAP" | head -1)"
has_file() { printf '%s\n' "$MAP" | awk -F'\t' -v f="$1" '$2 == f { n++ } END { exit !(n > 0) }'; }
has_file _bmad-output/planning-artifacts/product-brief.md || miss "(a) the changed brief has no part"
has_file _bmad-output/specs/s9/kernel/SPEC.md || miss "(a) the SPEC has no part"
has_file _bmad-output/planning-artifacts/s9/architecture-impact.md || miss "(a) architecture-impact.md has no part"
NPRD="$(printf '%s\n' "$MAP" | awk -F'\t' '$2 == "_bmad-output/planning-artifacts/prd.md"' | grep -c .)" || NPRD=0
[ "$NPRD" -ge 3 ] || miss "(a) prd.md has $NPRD part(s), want >= 3"
printf '%s\n' "$MAP" | awk -F'\t' -v e="$EDITED" '$2 ~ /prd\.md$/ && $3 <= e && e <= $4 { h = 1 } END { exit !h }' \
  || miss "(a) no PRD part holds the edited earlier line $EDITED"
for s in 6 7 8; do
  a="$(grep -n "^## Sprint $s\$" "$PA/prd.md" | cut -d: -f1)"; z="$(grep -n "^## Sprint $((s + 1))\$" "$PA/prd.md" | cut -d: -f1)"
  printf '%s\n' "$MAP" | awk -F'\t' -v a="$a" -v z="$z" '$2 ~ /prd\.md$/ && $3 >= a && $4 < z { h = 1 } END { exit h }' \
    || miss "(a) a PRD part lies inside the unchanged atom ## Sprint $s"
done

# ---- (b) the subject merge ----------------------------------------------------------------
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
SL="product-brief=$(sha "$PA/product-brief.md") SPEC=$(sha "$P/_bmad-output/specs/s9/kernel/SPEC.md") prd=$(sha "$PA/prd.md") architecture-impact=$(sha "$PA/s9/architecture-impact.md")"
ORDS="$(printf '%s\n' "$MAP" | cut -f1)"
shard() { # <dir> <key> <n-major> <cite> <minute>
  local i=0
  { printf '# shard %s\n\n## Findings\n\n' "$2"
    while [ "$i" -lt "$3" ]; do i=$((i + 1)); printf '### M%s — MAJOR — finding %s\n\nsections: %s\n\n' "$i" "$i" "$4"; done
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: 2026-10-01T10:%02d:00Z\n' "$5"
    printf 'tool_use_id: toolu_r%s%s\nmode: subagent\nlead_role: requirements\n' "$6" "$2"
    printf 'artifact: _bmad-output/planning-artifacts/s9/requirements-subject.md\nartifact_sha: %s\n' "$SL"
    printf 'findings_critical: 0\nfindings_major: %s\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n' "$3"; } > "$1/$2.md"
}
D1="$PA/s9/shards/requirements-p1"; mkdir -p "$D1" || exit 9
m=0; for o in $ORDS; do m=$((m + 1)); shard "$D1" "$o" 1 "$o" "$m" a; done
shard "$D1" cross 0 "1, 2" 59 a
MO="$(bash "$S/merge-adversarial-shards.sh" --subject 9 "$D1" 2>&1)"; rc=$?
P1="$PA/s9/requirements-adversarial-p1.md"
[ "$rc" -eq 0 ] && [ -f "$P1" ] || miss "(b) merge --subject 9 exited $rc: $(printf '%s' "$MO" | head -1)"
grep -qx 'artifact: _bmad-output/planning-artifacts/s9/requirements-subject.md' "$P1" || miss "(b) the pass does not name the subject manifest"
want="$( { printf '%s\n' "$ORDS" | awk '{ print $1 + 0 }'; echo cross; } | sort | tr '\n' ' ')"
have="$(sed -n 's/^shard_tool_use_ids://p' "$P1" | tr ' ' '\n' | awk -F= 'NF == 2 { k = $1; if (k ~ /^[0-9]+$/) k += 0; print k }' | sort | tr '\n' ' ')"
[ "$want" = "$have" ] || miss "(b) shard ids {$have} are not the map's ordinals plus cross {$want}"
grep -qx 'verdict: EXIT_CONDITION_NOT_MET' "$P1" || miss "(b) the verdict was not recomputed from the summed residue (every shard said MET)"

# ---- (c) Check 24 arm K3, post-stamp --------------------------------------------------------
D2="$PA/s9/shards/requirements-p2"; mkdir -p "$D2" || exit 9
m=0; for o in $ORDS; do m=$((m + 1)); shard "$D2" "$o" 0 "$o" "$m" b; done
sed -i.bak 's/invoked_at: 2026-10-01T/invoked_at: 2026-10-02T/' "$D2"/*.md && rm -f "$D2"/*.bak
shard "$D2" cross 0 "1, 2" 59 b; sed -i.bak 's/invoked_at: 2026-10-01T/invoked_at: 2026-10-02T/' "$D2/cross.md" && rm -f "$D2"/*.bak
printf -- '- disposition: repaired\n- edit: prd.md:%s\n- derivation: the seeded repair\n' "$EDITED" > "$PA/s9/requirements-repair-p1.md"
MO="$(bash "$S/merge-adversarial-shards.sh" --subject 9 "$D2" 2>&1)" || miss "(c) merge of pass 2: $(printf '%s' "$MO" | head -1)"
VO="$(bash "$S/validate-adversarial-convergence.sh" --series "$PA/s9/requirements-adversarial-p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || miss "(c) the validator exited $rc on a converged sharded subject series: $(printf '%s\n' "$VO" | grep -m1 'FAIL')"
# The consumer's shape: the terminal pass is a --document merge of prd.md alone.
DD="$PA/s9/shards/prd-p3"; mkdir -p "$DD" || exit 9
DMAP="$(bash "$S/partition-document.sh" --map "$PA/prd.md")" || miss "(c) the PRD does not partition unscoped"
PSHA="$(sha "$PA/prd.md")"
for o in $(printf '%s\n' "$DMAP" | cut -f1) cross; do
  { printf '# d %s\n\n## Findings\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n' "$o"
    printf 'invoked_at: 2026-10-03T10:00:00Z\ntool_use_id: toolu_d%s\nmode: subagent\nlead_role: requirements\n' "$o"
    printf 'artifact: _bmad-output/planning-artifacts/prd.md\nartifact_sha: %s\nfindings_critical: 0\nfindings_major: 0\n' "$PSHA"
    printf 'verdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$DD/$o.md"
done
MO="$(bash "$S/merge-adversarial-shards.sh" --document "$PA/prd.md" "$DD" 2>&1)" || miss "(c) the --document merge refused: $(printf '%s' "$MO" | head -1)"
mv "$PA/s9/prd-adversarial-p3.md" "$PA/s9/requirements-adversarial-p3.md" || exit 9
VO="$(bash "$S/validate-adversarial-convergence.sh" --series "$PA/s9/requirements-adversarial-p" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && grep -qF 'FAIL (K3' <<<"$VO" \
  || miss "(c) a --document prd.md terminal pass in the requirements series exited $rc without FAIL (K3"
echo "receipt: the requirements subject is mapped, merged and held by K3"
exit 0
