#!/usr/bin/env bash
# BL-718 receipt (the emitters). Usage: bash receipt-bl718.sh
# Run from the repo root. Two core-layout trees are built from the subject's own scripts: one
# CURRENT, and one whose core/schemas/provenance-block.json is the pre-0.888.0 schema
# (8df9b8ae6~1). In each, three emitters are driven through the fixtures' own world builders:
# the merge in files mode, the merge in subject mode, and the join in subject mode. The old
# reader is the SCHEMA, not the convergence validator: an emitter keyed on that one sibling alone
# writes `@` beside an old schema, and this tree is where it shows.
# 0 = every list all three write is `<stem>@<sha>` pairs in the current tree, and `<stem>=<sha>`
#     pairs in the old-schema tree.
# 1 = an emitter wrote the other separator (an emitter left on `=`, or a join and a merge that
#     disagree, fails here).
# 9 = the receipt could not run: no subject, no old reader in history, an old-schema tree identical
#     to the current one, a world that did not build, or an emitter exit other than 0 or 1.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
OLDREF=8df9b8ae6~1
FM=core/fixtures/adversarial-shard-merge; FJ=core/fixtures/remediator-shard-join
for f in core/scripts/merge-adversarial-shards.sh core/scripts/join-remediator-shards.sh \
         core/scripts/validate-adversarial-convergence.sh core/schemas/provenance-block.json \
         "$FM/lib.sh" "$FJ/lib.sh"; do
  [ -f "$f" ] || { echo "REFUSED: no $f (run from the distribution root)" >&2; exit 9; }
done
[ -d core/hooks ] || { echo "REFUSED: no core/hooks" >&2; exit 9; }
command -v jq >/dev/null 2>&1 || { echo "REFUSED: jq absent; the fixture worlds record nothing" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
trap 'rm -rf "$T"' EXIT
git show "${OLDREF}:core/schemas/provenance-block.json" > "$T/old-schema" 2>/dev/null || { echo "REFUSED: no old schema at $OLDREF" >&2; exit 9; }

tree() { # <name> -> a core-layout copy at $T/<name>
  local w="$T/$1"
  mkdir -p "$w/core/fixtures" "$w/core/skills/ai-dlc" || exit 9
  cp -R core/scripts core/hooks core/schemas "$w/core/" || exit 9
  cp -R "$FM" "$FJ" "$w/core/fixtures/" || exit 9
}
tree cur; tree old
cp "$T/old-schema" "$T/old/core/schemas/provenance-block.json" || exit 9
cmp -s "$T/cur/core/schemas/provenance-block.json" "$T/old/core/schemas/provenance-block.json" \
  && { echo "REFUSED: the old-schema tree is identical to the current one" >&2; exit 9; }

# drive <tree> -> writes <tree>/lists: one line per emitter, "<label> <rc> <list>"
drive() {
  local w="$T/$1"
  ( NAME=r718m; . "$w/$FM/lib.sh" >/dev/null 2>&1 || exit 9
    case "$MERGE" in "$w"/*) ;; *) exit 9 ;; esac
    d="$(clean_world)" || exit 9; run_merge "$MERGE" "$d"
    printf 'merge-files %s %s\n' "$RC" "$(sed -n 's/^artifact_sha://p' "$(out_of "$d")" 2>/dev/null | head -1)"
    d="$(new_subj_world)" || exit 9
    for k in $(cut -f1 "$(subj_root "$d")/subject.map"); do sshard "$d" "$k" 0 "$k"; done
    for k in $(subj_xkeys "$d"); do sshard "$d" "$k" 0 "1, 2"; done
    run_subj_merge "$MERGE" "$d"
    printf 'merge-subject %s %s\n' "$RC" "$(sed -n 's/^artifact_sha://p' "$(subj_out_of "$d")" 2>/dev/null | head -1)"
  ) > "$w/lists" || exit 9
  ( NAME=r718j; . "$w/$FJ/lib.sh" >/dev/null 2>&1 || exit 9
    case "$JOIN" in "$w"/*) ;; *) exit 9 ;; esac
    s="$(subj_world)" || exit 9; sj_all "$s"; run_sjoin "$JOIN" "$s"
    o="$(sj_out "$s")"
    printf 'join-before %s %s\n' "$RC" "$(sed -n 's/^- artifact_sha_before://p' "$o" 2>/dev/null | head -1)"
    printf 'join-after %s %s\n' "$RC" "$(sed -n 's/^- artifact_sha_after://p' "$o" 2>/dev/null | head -1)"
  ) >> "$w/lists" || exit 9
}
# judge <tree> <sep> -> counts failures into fails
fails=0
judge() {
  local lab rc list tok n bad
  [ "$(grep -c . "$T/$1/lists")" = 4 ] || { echo "REFUSED: $1 produced $(grep -c . "$T/$1/lists") of 4 lists" >&2; exit 9; }
  while read -r lab rc list; do
    case "$rc" in 0) ;; 1) echo "FAIL $1 $lab exited 1"; fails=$((fails + 1)); continue ;; *) echo "REFUSED: $1 $lab exited $rc" >&2; exit 9 ;; esac
    n=0; bad=0
    for tok in $list; do
      n=$((n + 1))
      grep -Eq "^[^=@ ]+[$2][0-9a-f]{64}\$" <<<"$tok" || bad=$((bad + 1))
    done
    [ "$n" -ge 2 ] || { echo "REFUSED: $1 $lab wrote no pair list" >&2; exit 9; }
    [ "$bad" -eq 0 ] || { echo "FAIL $1 $lab: $bad of $n pairs not '$2'"; fails=$((fails + 1)); }
  done < "$T/$1/lists"
}
drive cur; drive old
judge cur @; judge old =
[ "$fails" -eq 0 ] || exit 1
exit 0
