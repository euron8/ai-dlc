#!/usr/bin/env bash
# ai-dlc-update — mechanical pre-classification (the cheap, deterministic pass).
#
# Buckets every upstream-changed core/ file by hashing base vs theirs vs ours,
# so the expensive semantic classifier only runs on genuinely BOTH-CHANGED
# files. Self-contained: shells to git only; reads no pipeline rulebook.
#
# Usage: preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#   dist-repo      path to the distribution git checkout (source of core/)
#   base-sha       the sha in the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref (e.g. HEAD or a tag)
#   consumer-root  the consumer project root (contains .claude/ and scripts/)
#
# Output: TSV to stdout — STATUS<TAB>CORE_PATH<TAB>CONSUMER_PATH<TAB>BUCKET
set -u
DIST="${1:?dist-repo}"; BASE="${2:?base-sha}"; THEIRS="${3:?theirs-ref}"; CONS="${4:?consumer-root}"

map_consumer() { # core/... -> consumer-relative path
  case "$1" in
    core/scripts/*) echo "scripts/${1#core/scripts/}" ;;
    core/*)         echo ".claude/${1#core/}" ;;
    *)              echo "$1" ;;
  esac
}
blob_hash() { git -C "$DIST" rev-parse "$1:$2" 2>/dev/null || echo MISSING; }
file_hash() { local f="$CONS/$1"; [ -f "$f" ] && git -C "$DIST" hash-object "$f" 2>/dev/null || echo MISSING; }

git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/ | while IFS=$'\t' read -r status path; do
  cons="$(map_consumer "$path")"
  base_h="$(blob_hash "$BASE" "$path")"
  theirs_h="$(blob_hash "$THEIRS" "$path")"
  ours_h="$(file_hash "$cons")"

  case "$status" in
    A)
      if   [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-ONLY-ADD"        # pure apply
      elif [ "$ours_h" = "$theirs_h" ];    then bucket="ALREADY-PRESENT"          # noop
      else                                      bucket="BOTH-ADDED->CLASSIFY"; fi
      ;;
    D)  bucket="UPSTREAM-DELETED->CLASSIFY" ;;
    *)  # M and renames
      if   [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-MOD+consumer-deleted->CLASSIFY"
      elif [ "$ours_h" = "$base_h" ];      then bucket="UPSTREAM-ONLY"            # consumer untouched -> apply
      elif [ "$ours_h" = "$theirs_h" ];    then bucket="ALREADY-AT-THEIRS"        # noop
      else                                      bucket="BOTH-CHANGED->CLASSIFY"; fi
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "$bucket"
done
