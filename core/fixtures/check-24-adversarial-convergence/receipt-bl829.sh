#!/usr/bin/env bash
# check-24-adversarial-convergence/receipt-bl829.sh [<validator>] -- the backlog receipt for BL-829: arm
# K3's branch (b), the terminal pass that reviews the subject manifest, dates a WIDENED series against
# K3B_RELEASE and a `requirements-` series against K3_RELEASE. It drives the given validator (siblings
# beside it) in mktemp worlds and reads no fixture file.
#
#   exit 0   the fix is present        exit 1   it is not        exit 9   the receipt cannot measure
#
# The subject is resolved from this file's tree (core/scripts/ in the distribution, scripts/ai-dlc/
# installed); an argument names another copy, which is how the base and a mutant are scored.
#
# Two worlds, each its own git repository stamped at the release strictly between K3_RELEASE and
# K3B_RELEASE (read from the validator), both carrying a terminal pass whose artifact is the subject
# manifest, four notarized stems with matching shas, and a key set that is the map's ordinals and
# cross keys with `1` replaced by `99` (not the lone-cross shape, so K3C and K3D never rebind):
#   wide   the pass is `prd-adversarial-p1` (the widened candidate)   PENDING, not owed yet at K3B
#   req    the pass is `requirements-adversarial-p1`                   FAIL (K3), dated at K3_RELEASE
# Each verdict must be reached through branch (b): its text names the subject map's ordinals.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${1:-}"
if [ -z "$SUBJ" ]; then
  for c in "$HERE/../../scripts/validate-adversarial-convergence.sh" \
           "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh"; do
    [ -f "$c" ] && { SUBJ="$c"; break; }
  done
fi
[ -n "$SUBJ" ] && [ -f "$SUBJ" ] || { echo "receipt: no validate-adversarial-convergence.sh to score" >&2; exit 9; }
SD="$(cd "$(dirname "$SUBJ")" && pwd)"
for s in partition-subject.sh partition-document.sh; do
  [ -f "$SD/$s" ] || { echo "receipt: $s is not beside $SUBJ" >&2; exit 9; }
done
command -v git >/dev/null 2>&1 || { echo "receipt: git is not on PATH" >&2; exit 9; }
LO="$(sed -n 's/^K3_RELEASE="\([0-9.]*\)"$/\1/p' "$SUBJ")"
HI="$(sed -n 's/^K3B_RELEASE="\([0-9.]*\)"$/\1/p' "$SUBJ")"
IFS=. read -r lo_ma lo_mi lo_pa <<EOF
$LO
EOF
IFS=. read -r hi_ma hi_mi hi_pa <<EOF
$HI
EOF
[ -n "$lo_mi" ] && [ -n "$hi_mi" ] && [ "$lo_ma" = "$hi_ma" ] && [ $((lo_mi + 1)) -lt "$hi_mi" ] \
  || { echo "receipt: no release lies strictly between K3_RELEASE '$LO' and K3B_RELEASE '$HI'" >&2; exit 9; }
MID="${lo_ma}.$((lo_mi + 1)).${lo_pa}"

B="$(mktemp -d "${TMPDIR:-/tmp}/bl829-receipt-XXXXXX")" || exit 9
B="$(cd "$B" && pwd -P)"
PA=_bmad-output/planning-artifacts
lg() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid \
       -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
world() { # <name> <pass stem> -> a stamped repo with the subject manifest and its terminal pass
  local w="$B/$1" k g keys o x
  mkdir -p "$w/$PA/s9" "$w/_bmad-output/specs/s9/kernel" "$w/.claude" || return 1
  ( lg "$w" init -q . && lg "$w" checkout -q -b main
    { printf '# Brief\n\n## Vision\n\n'; lorem vision 10; } > "$w/$PA/product-brief.md"
    { printf '# PRD\n\n## Current state\n\n'; lorem current 20; printf '\n## Sprint 8\n\n'; lorem s8 20; printf '\n'; } > "$w/$PA/prd.md"
    printf -- '- FR-S8-1: architecture_impact: none\n' > "$w/$PA/s9/architecture-impact.md"
    printf 'version: %s\n' "$MID" > "$w/.claude/.ai-dlc-version"
    lg "$w" add -A && GIT_COMMITTER_DATE=2026-01-01T00:00:00Z GIT_AUTHOR_DATE=2026-01-01T00:00:00Z lg "$w" commit -q -m stamp \
      && lg "$w" checkout -q -b sprint-9 ) >/dev/null 2>&1 || return 1
  printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  printf 'A new brief line.\n' >> "$w/$PA/product-brief.md"
  { printf '## Sprint 9\n\n### Goals\n\n'; lorem s9g 30; printf '\n### Requirements\n\n'; lorem s9r 30; } >> "$w/$PA/prd.md"
  printf -- '- FR-S9-1: architecture_impact: none\n' >> "$w/$PA/s9/architecture-impact.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$SD/partition-subject.sh" --map 9 > "$w/subject.map" 2>/dev/null || return 1
  [ "$(grep -c '^file: ' "$w/$PA/s9/requirements-subject.md")" -eq 4 ] || return 1
  k="$(grep -c . "$w/subject.map")"; [ "$k" -ge 2 ] || return 1
  g="$(bash "$SD/partition-document.sh" --cross-groups "$k" | grep -c .)" || g=0
  [ "$g" -ge 2 ] || return 1   # grouped cross keys: the wrong set can never be the lone-cross shape
  keys=""; for o in $(cut -f1 "$w/subject.map"); do keys="$keys $((10#$o))=toolu_rcpt$o"; done
  for x in $(seq 1 "$g"); do keys="$keys cross-$x=toolu_rcptx$x"; done
  keys="$(printf '%s' "$keys" | sed 's/ 1=/ 99=/')"
  case "$keys" in *" 99="*) ;; *) return 1 ;; esac
  { printf '# requirements -- adversarial pass 1 (merged from shards)\n\n## Findings\n\nnone\n'
    printf '\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: 2026-10-01T10:00:00Z\n'
    printf 'tool_use_id: toolu_rcpt_%s\nmode: subagent\nlead_role: requirements\n' "$2"
    printf 'artifact: %s/s9/requirements-subject.md\n' "$PA"
    printf 'artifact_sha: product-brief=%s SPEC=%s prd=%s architecture-impact=%s\n' "$(sha "$w/$PA/product-brief.md")" \
      "$(sha "$w/_bmad-output/specs/s9/kernel/SPEC.md")" "$(sha "$w/$PA/prd.md")" "$(sha "$w/$PA/s9/architecture-impact.md")"
    printf 'shard_tool_use_ids:%s\n' "$keys"
    printf 'findings_critical: 0\nfindings_major: 0\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$w/$PA/s9/$2-adversarial-p1.md"
}
verdict() { # <world> <stem> -> FAIL | PENDING | OTHER, read only off branch (b)'s key-set line
  local o="$B/$1.out"
  bash "$SUBJ" --series "$B/$1/$PA/s9/$2-adversarial-p" > "$o" 2>&1
  grep -qF "is not the subject map's ordinals plus cross groups" "$o" || { printf 'OTHER'; return; }
  if grep -qF 'FAIL (K3 -- SUBJECT)' "$o"; then printf 'FAIL'
  elif grep -qF 'PENDING (K3 -- SUBJECT)' "$o" && grep -qF "at ${HI} or later -- not owed yet." "$o"; then printf 'PENDING'
  else printf 'OTHER'; fi
}
world wide prd && world req requirements || { echo "receipt: a world did not build (under $B)" >&2; exit 9; }
vw="$(verdict wide prd)"; vr="$(verdict req requirements)"
echo "receipt-bl829: wide=$vw (want PENDING) req=$vr (want FAIL), stamped $MID between $LO and $HI"
[ "$vw" = OTHER ] || [ "$vr" = OTHER ] && { echo "receipt: a world did not reach branch (b)'s key-set verdict (outputs under $B)" >&2; exit 9; }
[ "$vw" = PENDING ] && [ "$vr" = FAIL ] && exit 0
exit 1
