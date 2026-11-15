# gate-wait.sh -- sourced by scripts/seed-verdict-store.sh and scripts/census-consumer-layout.sh: wait, printing why,
# while a push gate runs in this repository, so a seed or census never loads the box under it.
#
#   . "$PWD/scripts/gate-wait.sh"; gate_wait <who>
#
# THE MARKER. .githooks/pre-push writes `<git common dir>/ai-dlc-gate-held.<pid>` ("<pid> <ps lstart>") for a push
# that delivers a tree, at depth 0, after the pregate gate; it removes it on exit where its EXIT trap survives. The
# common directory is shared by every worktree and clone-of-worktree, so a gate in any of them is seen. A marker never
# wedges a waiter: it counts only while its pid is alive AND that pid's start time still equals the recorded one (a
# reused pid reads dead), a dead marker is deleted, and the wait ends after AI_DLC_GATE_WAIT_MAX seconds (default
# 7200) with a line saying it proceeds anyway. AI_DLC_GATE_WAIT_POLL is the poll interval in seconds (default 5).
# Returns 0 always.
gate_held_live() { # <marker file>: 0 when its gate is alive
  local f="$1" p="" s="" now=""
  read -r p s < "$f" 2>/dev/null || return 1
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$p" 2>/dev/null || return 1
  now="$(ps -o lstart= -p "$p" 2>/dev/null)" || now=""
  now="${now#"${now%%[![:space:]]*}"}"; now="${now%"${now##*[![:space:]]}"}" # read -r trimmed the recorded one
  [ -z "$s" ] || [ "$now" = "$s" ]
}
gate_wait() { # <who>
  local who="${1:-this run}" gcd f live t0 t1 waited=0 max poll said=-1
  gcd="$(git rev-parse --git-common-dir 2>/dev/null)" || return 0
  case "$gcd" in /*) ;; *) gcd="$PWD/$gcd" ;; esac
  max="${AI_DLC_GATE_WAIT_MAX:-7200}"; poll="${AI_DLC_GATE_WAIT_POLL:-5}"
  case "$max" in ''|*[!0-9]*) max=7200 ;; esac
  case "$poll" in ''|*[!0-9]*|0) poll=5 ;; esac
  t0="$(date +%s)"
  while :; do
    live=""
    for f in "$gcd"/ai-dlc-gate-held.*; do
      [ -f "$f" ] || continue
      if gate_held_live "$f"; then live="$live ${f##*/ai-dlc-gate-held.}"; else rm -f -- "$f"; fi
    done
    [ -n "$live" ] || break
    t1="$(date +%s)"; waited=$((t1 - t0))
    if [ "$waited" -ge "$max" ]; then
      echo "$who: a push gate (pid${live}) has run for ${waited}s, past AI_DLC_GATE_WAIT_MAX=${max}; proceeding anyway"; return 0
    fi
    if [ "$said" -lt 0 ] || [ "$((waited - said))" -ge 60 ]; then
      echo "$who: waiting, a push gate (pid${live}) is running in this repository and $who would load the box under it (${waited}s so far)"; said="$waited"
    fi
    sleep "$poll"
  done
  [ "$said" -lt 0 ] || echo "$who: no push gate is running now; proceeding after ${waited}s"
  return 0
}
