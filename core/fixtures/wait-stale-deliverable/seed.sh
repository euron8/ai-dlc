#!/usr/bin/env bash
# seed.sh <case> -- build a throwaway consumer-shaped tree for one case and print
# its path on stdout. The caller owns it and must `rm -rf` it.
#
# Every case gets its OWN tree. The beat counter and the join sidecar are keyed by
# `cksum` of the TARGET PATH STRING alone (wait-for-deliverable.sh, key_of), so two
# cases sharing a state dir would share state through the identical relative path
# `deliv.md`. Never reuse a work dir across cases.
set -uo pipefail

CASE="${1:-}"
[ -n "$CASE" ] || { echo "usage: seed.sh <case>" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t wait-stale)"
mkdir -p "$WORK/_bmad-output"

TARGET="$WORK/deliv.md"

# BSD `date -r <epoch>` renders an epoch; GNU `date -r` wants a FILE and fails on
# an integer, which is the probe.
stamp_of() {
  if date -r "$1" +%Y%m%d%H%M.%S >/dev/null 2>&1; then date -r "$1" +%Y%m%d%H%M.%S
  else date -d "@$1" +%Y%m%d%H%M.%S; fi
}
age_file() {  # $1 = file, $2 = seconds old
  touch -t "$(stamp_of "$(( $(date +%s) - $2 ))")" "$1"
}

# The counter key, computed exactly as the subject computes it.
key_of() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }

case "$CASE" in
  # A previous sprint's artifact sitting at the path this join is about to use.
  # 25 days matches the live incident (an S268 analysis met an S294 join).
  stale|stale-marker|arrives-mid-beat|since-clamp)
    printf 'root cause: something from a sprint three cycles ago\n' > "$TARGET"
    age_file "$TARGET" 2160000
    ;;

  # Delivered 30s before this join armed -- indistinguishable from `stale` on the
  # filesystem alone, which is the whole reason --since exists.
  since-earlier)
    printf 'the teammate answered before the lead got around to joining\n' > "$TARGET"
    age_file "$TARGET" 30
    ;;

  # Nothing on disk: the case that already worked, kept as a regression guard.
  absent)
    ;;

  # Sequence bound already spent. Non-empty and stale, so it cannot deliver its
  # way out; must report non-delivery without sleeping.
  exhausted)
    printf 'stale\n' > "$TARGET"
    age_file "$TARGET" 2160000
    mkdir -p "$WORK/_bmad-output/.wait-beats"
    printf '10' > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md)"
    ;;

  *)
    echo "FIXTURE ERROR: unknown case '$CASE'" >&2
    rm -rf "$WORK"
    exit 2
    ;;
esac

printf '%s' "$WORK"
