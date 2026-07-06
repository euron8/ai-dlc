#!/usr/bin/env bash
# ai-dlc-update — mechanical pre-classification (the cheap, deterministic pass).
#
# Buckets every upstream-changed core/ file by hashing base vs theirs vs ours,
# so the expensive semantic classifier only runs on genuinely BOTH-CHANGED
# files. Self-contained: shells to git only; reads no pipeline rulebook.
#
# Usage: preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> [--untangle]
#   dist-repo      path to the distribution git checkout (source of core/)
#   base-sha       the sha in the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref (e.g. HEAD or a tag)
#   consumer-root  the consumer project root (contains .claude/ and scripts/)
#   --untangle     optional. Phase-2 one-time migration mode for a consumer
#                  whose stamp already equals theirs (base == theirs — no
#                  upstream delta exists). A plain base->theirs diff is empty
#                  in that case (git diff <sha> <sha> is always empty), so
#                  this mode enumerates the core-manifest file list from
#                  reconcile/setup-sites.md instead and buckets purely by
#                  ours vs base (there is no theirs-side status to branch on).
#
# Output: TSV to stdout — STATUS<TAB>CORE_PATH<TAB>CONSUMER_PATH<TAB>BUCKET
set -u
DIST="${1:?dist-repo}"; BASE="${2:?base-sha}"; THEIRS="${3:?theirs-ref}"; CONS="${4:?consumer-root}"
MODE="${5:-}"

map_consumer() { # core/... -> consumer-relative path
  case "$1" in
    core/scripts/*) echo "scripts/${1#core/scripts/}" ;;
    core/*)         echo ".claude/${1#core/}" ;;
    *)              echo "$1" ;;
  esac
}
blob_hash() { git -C "$DIST" rev-parse "$1:$2" 2>/dev/null || echo MISSING; }
file_hash() { local f="$CONS/$1"; [ -f "$f" ] && git -C "$DIST" hash-object "$f" 2>/dev/null || echo MISSING; }

if [ "$MODE" = "--untangle" ]; then
  # Enumerate the core-manifest glob list from setup-sites.md (co-located
  # with this script) rather than diffing base->theirs, which is always
  # empty when base == theirs.
  MANIFEST="$(dirname "$0")/setup-sites.md"
  awk '/^core_manifest:/{f=1; next} f && /^  - /{sub(/^  - /,""); print; next} f{exit}' "$MANIFEST" |
  while IFS= read -r glob; do
    git -C "$DIST" ls-files "$glob"
  done | while IFS= read -r path; do
    cons="$(map_consumer "$path")"
    base_h="$(blob_hash "$BASE" "$path")"
    ours_h="$(file_hash "$cons")"

    if   [ "$ours_h" = MISSING ];   then bucket="UPSTREAM-ONLY-ADD"       # consumer lacks this manifest file
    elif [ "$ours_h" = "$base_h" ]; then bucket="ALREADY-AT-THEIRS"       # consumer never touched it -- nothing to untangle
    else                                 bucket="BOTH-CHANGED->CLASSIFY"; fi
    printf '%s\t%s\t%s\t%s\n' "U" "$path" "$cons" "$bucket"
  done
  exit 0
fi

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
