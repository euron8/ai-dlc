#!/usr/bin/env bash
# BL-716 receipt (serial lanes). Usage: bash receipt-bl716.sh     Run from the repo root.
# A core-layout copy of the subject's own scripts and hooks is built under mktemp, and the join is
# driven through this fixture's own world builders (lib.sh) -- the REAL splitters, hook and worklist:
#   doc    one document split into three sections        -> one lane {prd.md}            (shared file)
#   cite   the subject, architecture-impact citing a prd line part 4's edit moves
#                                                         -> {prd.md, architecture-impact.md} {SPEC.md}
#   plain  the same subject with no cite                  -> {prd.md} {architecture-impact.md} {SPEC.md}
#   hit    a replaced prd line still standing in SPEC and architecture-impact
#                                                         -> three lanes and ONE `FANIN: HIT` line
#   party  the subject's party join                       -> `LANE-ARTIFACT: requirements-party-serial --pass 1`
# The lanes are read as a SET of file sets (each `LANE:` line's `files:` tokens, sorted), so the
# numbering and the order of files within a line are free; the partition is not.
# 0 = every world partitions as above.
# 1 = a world partitioned otherwise (one lane per part, a missed MOVED-CITE edge, a HIT that joined
#     lanes, no LANE line at all), or an edge read UNASSESSED.
# 9 = the receipt could not run: a missing file, a world that did not build, or a join exit other than 0.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
FJ=core/fixtures/remediator-shard-join
for f in core/scripts/join-remediator-shards.sh core/scripts/serial-remediation-worklist.sh \
         core/scripts/partition-document.sh core/scripts/partition-subject.sh "$FJ/lib.sh"; do
  [ -f "$f" ] || { echo "REFUSED: no $f (run from the distribution root)" >&2; exit 9; }
done
command -v jq >/dev/null 2>&1 || { echo "REFUSED: jq absent; the fixture worlds record nothing" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/r/core/fixtures" || exit 9
cp -R core/scripts core/hooks core/schemas core/team-roles "$T/r/core/" || exit 9
cp -R "$FJ" core/fixtures/lib "$T/r/core/fixtures/" || exit 9

( NAME=r716; . "$T/r/$FJ/lib.sh" >/dev/null 2>&1 || exit 9
  case "$JOIN" in "$T/r"/*) ;; *) exit 9 ;; esac
  lanes() { # <label> -> "<label> <sorted file set>" per LANE line, sorted; ERR on a bad exit
    [ "$RC" -eq 0 ] || { echo "ERR $1 rc=$RC"; return; }
    grep -q 'UNASSESSED' "$JO" && echo "$1 UNASSESSED"
    sed -n 's/^LANE: [0-9][0-9]* files: \(.*\) parts: .*$/\1/p' "$JO" \
      | while IFS= read -r l; do printf '%s %s\n' "$1" "$(printf '%s\n' $l | sort | tr '\n' ' ')"; done | sort
  }
  # lane_subj is INLINED, not read from lib.sh, so a tree whose lib.sh predates the lanes (the base)
  # still builds every world and reads NOT FIXED rather than could-not-run. Its body is lib.sh's.
  lane_subj() { # <join> <cite 0|1> <hit 0|1> -> RC, $JO
    local w ln f s3
    w="$(subj_world)" || return 1
    f="s9g line 3 of the section, carrying enough prose to weigh something real."
    if [ "$2" = 1 ]; then
      ln="$(grep -n '^s9r line 5 ' "$w/$SJPA/prd.md" | cut -d: -f1)"; [ -n "$ln" ] || return 1
      printf -- '- FR-S9-1 see `%s/prd.md:%s`\n' "$SJPA" "$ln" >> "$w/$SJPA/s9/architecture-impact.md"
    fi
    if [ "$3" = 1 ]; then
      s3="$(sj_part_rows "$w" | awk -F'\t' '$2 + 0 == 3 { print $7 }')"; [ -n "$s3" ] && grep -qxF "$f" "$w/$s3" || return 1
      printf '%s\n' "$f" >> "$w/$SPECREL"; printf '%s\n' "$f" >> "$w/$SJPA/s9/architecture-impact.md"
      awk -v f="$f" '$0 == f { print "The third goal line, rewritten by its part."; next } { print }' "$w/$s3" > "$w/s3.tmp" && mv "$w/s3.tmp" "$w/$s3" || return 1
    fi
    sj_all "$w"; run_sjoin "$1" "$w"
  }
  w="$(doc_world)" || exit 9
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  run_docjoin "$JOIN" "$w"; lanes doc
  lane_subj "$JOIN" 1 0 || exit 9; lanes cite
  lane_subj "$JOIN" 0 0 || exit 9; lanes plain
  lane_subj "$JOIN" 0 1 || exit 9; lanes hit
  n="$(grep -c '^FANIN: HIT ' "$JO")" || n=0
  echo "hit fanin-hit-lines $n"
  # The subject PARTY round's lane name, derived from its record, never inferred from `requirements`.
  sj_party "$JOIN" "architecture-dev-1.md#F-1" || exit 9
  [ "$RC" -eq 0 ] || { echo "ERR party rc=$RC"; exit 0; }
  echo "party $(grep -m1 '^LANE-ARTIFACT: ' "$JO" || echo 'no LANE-ARTIFACT line')"
) > "$T/got" || { echo "REFUSED: a world did not build or the copy did not resolve" >&2; exit 9; }
grep -q '^ERR ' "$T/got" && { cat "$T/got" >&2; exit 9; }

P=_bmad-output/planning-artifacts
{ echo "doc $P/prd.md "
  echo "cite $P/prd.md $P/s9/architecture-impact.md "
  echo "cite _bmad-output/specs/s9/kernel/SPEC.md "
  echo "plain $P/prd.md "
  echo "plain $P/s9/architecture-impact.md "
  echo "plain _bmad-output/specs/s9/kernel/SPEC.md "
  echo "hit $P/prd.md "
  echo "hit $P/s9/architecture-impact.md "
  echo "hit _bmad-output/specs/s9/kernel/SPEC.md "; } | sort > "$T/want"
{ grep -v '^hit fanin-hit-lines \|^party ' "$T/got" | sort; } > "$T/got.lanes"
if cmp -s "$T/want" "$T/got.lanes" && grep -qx 'hit fanin-hit-lines 1' "$T/got" \
   && grep -qx 'party LANE-ARTIFACT: requirements-party-serial --pass 1' "$T/got"; then
  echo "BL-716: every world partitions into its lanes of files; the cross-lane HIT is one fan-in item; the party round's lane name is derived"; exit 0
fi
echo "BL-716: the lane partition or the lane round's name differs from the one owed" >&2
diff "$T/want" "$T/got.lanes" >&2; grep '^hit fanin-hit-lines\|^party ' "$T/got" >&2
exit 1
