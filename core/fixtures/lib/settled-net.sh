# The settled-tree net, shared by fold-architect-ledger-join and spec-join-integrity. Each fixture sources this
# file and also mutates a COPY of it inside its own run, so the net is mutated where it is read.
# The shape is readset-skip's aw_group_settled, with one difference: a member whose state `ps` will
# not give is NOT settled (the net keeps waiting), so a refused `ps` can never make the net fire.
st_alive() { kill -0 "$1" 2>/dev/null; }
st_members() { # <pid>: "<pid> <stat> <pending> <cpu time>" for <pid> and every descendant
  local p
  st_alive "$1" || return 0
  printf '%s %s\n' "$1" "$(ps -o stat=,pending=,time= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ //')"
  for p in $(pgrep -P "$1" 2>/dev/null); do st_members "$p"; done
}
st_settled() { # <members text>: 0 when there is a member and EVERY member is blocked with nothing pending
  awk 'NF < 4 { bad = 1; next } { n++; if ($2 !~ /^[SIT]/ || $3 != "0") bad = 1 } END { exit (n > 0 && !bad) ? 0 : 1 }' <<<"$1"
}
st_net() { # <root pid> <progress file>: 0 when the root exits; 2 when the tree is settled on two consecutive identical polls
  local cur prev="" sz
  while st_alive "$1"; do
    cur="$(st_members "$1")"; sz="$(wc -c < "$2" 2>/dev/null | tr -d ' ')"
    if st_settled "$cur"; then
      [ "$prev" = "$sz|$cur" ] && return 2
      prev="$sz|$cur"
    else prev=""; fi
    sleep 0.1
  done
  return 0
}
st_reap() { # <pid>: SIGKILL the tree, leaves first (a stopped process takes SIGKILL)
  local p
  for p in $(pgrep -P "$1" 2>/dev/null); do st_reap "$p"; done
  kill -9 "$1" 2>/dev/null
}
