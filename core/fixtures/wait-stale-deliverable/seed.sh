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
  # way out; must report non-delivery without sleeping. `.bound` MATCHES the bound
  # the run uses, so the counter is in scope and survives to be spent.
  exhausted)
    printf 'stale\n' > "$TARGET"
    age_file "$TARGET" 2160000
    mkdir -p "$WORK/_bmad-output/.wait-beats"
    printf '6' > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md)"
    printf '6' > "$WORK/_bmad-output/.wait-beats/.bound"
    ;;

  # The exact mirror of `exhausted`, differing ONLY in `.bound`: a spent counter
  # left over from a DIFFERENT bound. This is the shape a consumer carries across
  # a pull that retunes max_wait_beats, and it must NOT exhaust -- a count of 6
  # against an old ceiling of 10 says nothing about a new ceiling of 6, and
  # honouring it would declare non-delivery on a live teammate's first beat.
  counter-bound-reset)
    printf 'stale\n' > "$TARGET"
    age_file "$TARGET" 2160000
    mkdir -p "$WORK/_bmad-output/.wait-beats"
    printf '6' > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md)"
    printf '10' > "$WORK/_bmad-output/.wait-beats/.bound"
    ;;

  # Nothing on disk; the beat will sleep out its quantum. Used by the quantum and
  # marker-lease cases, which care about timing rather than file content.
  knob-split-forward|knob-split-reverse|marker-goes-stale)
    ;;

  # ---- progress-evidence cases -------------------------------------------------
  # All four seed a SPENT counter, because the grant only ever matters at the beat
  # that would otherwise declare non-delivery. They also seed the `.progress` mark
  # ALREADY AGED: the mark is created on a join's first beat and a spent counter
  # means five beats have been and gone, so a mark that predates this beat is the
  # honest state at exhaustion -- not a convenience. Without it `progressed_since`
  # returns false on its first call for want of anything to compare against, and
  # every one of these cases would pass for the wrong reason.
  #
  # The deliverable is ABSENT rather than stale-and-present: a missing file cannot
  # deliver its way out either, and it keeps the pre-existing-content NOTE out of
  # the output these cases assert on.
  # ---- the chained-sibling cases ----------------------------------------------
  # Same family, and deliberately seeded through the same block: what they vary is
  # NOT the tree but whether a sibling beat already ran in the calling shell. The
  # tree therefore has to be identical to `progress-extends`, or a difference in
  # outcome could be attributed to the seed instead of to MAY_SLEEP.
  #
  # THE SIBLING MARKER IS NOT SEEDED HERE, AND THAT IS NOT AN OMISSION. It is keyed
  # `.shell-$PPID` on the PID of the shell that INVOKES the subject, which this
  # process is not. run.sh writes it from inside that shell -- see `chained_beat`.
  #
  # `chained-window` and `sleeping-restamp` seed the counter BELOW the bound. They
  # are about the mark's re-stamp, not about the grant, and at the bound the grant
  # path rewrites the counter as well -- two writes in one observation.
  progress-extends|progress-bounded|progress-ignores-own-state|\
  chained-progress|chained-noprogress|chained-window|sleeping-restamp)
    mkdir -p "$WORK/_bmad-output/.wait-beats"
    case "$CASE" in
      chained-window|sleeping-restamp) printf '1' > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md)" ;;
      *)                               printf '6' > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md)" ;;
    esac
    printf '6' > "$WORK/_bmad-output/.wait-beats/.bound"
    : > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md).progress"
    age_file "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md).progress" 300

    # The teammate's worktree. `settled.txt` is older than the mark so the tree is
    # never empty -- an empty tree would make "no progress" true for the wrong
    # reason and `progress-ignores-own-state` vacuous.
    mkdir -p "$WORK/wt"
    printf 'work from an earlier beat\n' > "$WORK/wt/settled.txt"
    age_file "$WORK/wt/settled.txt" 600

    case "$CASE" in
      # A file written since the last beat: the teammate is demonstrably working.
      progress-extends|chained-progress|chained-window|sleeping-restamp)
        printf 'a partial result written during the last beat\n' > "$WORK/wt/wip.txt"
        ;;
      # THE NEAR-MISS, and it is the arm that stops "grants unconditionally" from
      # passing. Everything about `chained-progress` holds except the one fact the
      # grant is supposed to turn on: nothing under the worktree is newer than the
      # mark. `settled.txt` above is 600s old against a 300s mark, so the tree is
      # non-empty and the absence of a hit is a real answer rather than an empty
      # traversal.
      chained-noprogress)
        ;;
      # Same evidence, but every grant is already spent. The wait must still end --
      # a teammate that writes forever without delivering is the hang Rule 29's
      # Check C exists to stop, and an uncapped grant would be exactly that.
      progress-bounded)
        printf 'a partial result written during the last beat\n' > "$WORK/wt/wip.txt"
        printf '6' > "$WORK/_bmad-output/.wait-beats/$(key_of deliv.md).grants"
        ;;
      # The ONLY fresh writes in the watched tree are wait-beat machinery. A
      # teammate worktree carries its own `_bmad-output/`, so if that teammate ran
      # beats of its own this is what the tree looks like while it is dead: a
      # heartbeat, not work. Nothing here is the caller's state dir, so the
      # state-dir guard cannot see it -- only the prune can.
      progress-ignores-own-state)
        mkdir -p "$WORK/wt/_bmad-output/.wait-beats"
        printf '3' > "$WORK/wt/_bmad-output/.wait-beats/$(key_of some-other-deliv.md)"
        printf '%s' "$(date +%s)" > "$WORK/wt/_bmad-output/.beat-inflight"
        ;;
    esac
    ;;

  # Argument-guard cases need no state beyond one legitimate progress path, which
  # is the CONTROL: without it, a subject that rejected every --progress-path
  # would satisfy all three rejection assertions.
  progress-guards)
    mkdir -p "$WORK/wt"
    printf 'the teammate works here\n' > "$WORK/wt/settled.txt"
    ;;

  *)
    echo "FIXTURE ERROR: unknown case '$CASE'" >&2
    rm -rf "$WORK"
    exit 2
    ;;
esac

printf '%s' "$WORK"
