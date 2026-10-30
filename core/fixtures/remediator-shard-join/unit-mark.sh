#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-mark.sh -- MK0, the seam pin for the --mark cells EC37 and EC40-EC43.
# Those cells (lib.sh p_partmark, p_markderive, p_replay, p_claim, p_vcrash) call wfd_run and cs_run, which
# source wait-for-deliverable.sh / content-seal.sh in a subshell and call wfd_mark_main / seal_main, the
# functions each script calls itself when run. This file asserts that equivalence on one refusing and one
# passing --mark: stdout+stderr (merged, as the CLI cells merge them) and the exit status are byte-identical
# between the in-process call and `bash wait-for-deliverable.sh`, and the two worlds differ.
# Exit: 0 passed, 1 failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-mark"
UM_HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$UM_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $NAME: lib.sh is absent beside $0" >&2; exit 2; }
# shellcheck source=/dev/null
. "$UM_HERE/lib.sh" > /dev/null || { echo "FIXTURE BROKEN: $NAME: sourcing lib.sh failed" >&2; exit 2; }
WFD="$SRCDIR/wait-for-deliverable.sh"
[ -f "$WFD" ] || { echo "FIXTURE BROKEN: $NAME: $WFD absent" >&2; exit 2; }
sw="$(mktemp -d "$WORK/mk0.XXXXXX")" || { echo "FIXTURE BROKEN: $NAME: no scratch" >&2; exit 2; }
sd="$sw/_bmad-output/planning-artifacts/s9/shards/stories-repair-p1"
mkdir -p "$sd" || exit 2
printf '# part\n\nbody\n' > "$sd/01.md"
cp "$sd/01.md" "$sd/02.md"
seam_ok=1
# refuse: a --mark with no findings=<n> -> 64; pass: a well-formed --mark -> 0. Each world is its own copy,
# run once in process and once as the CLI, so the file the call writes is compared too.
for _k in refuse pass; do
  for _w in unit cli; do cp "$sd/01.md" "$sw/$_k.$_w.md"; done
  if [ "$_k" = refuse ]; then _args="stories remediator 01 nofindings"; else _args="stories remediator 01 findings=1"; fi
  # shellcheck disable=SC2086
  wfd_run "$WFD" --mark "$sw/$_k.unit.md" $_args > "$sw/$_k.unit" 2>&1; echo "$?" > "$sw/$_k.unit.rc"
  # shellcheck disable=SC2086
  bash "$WFD" --mark "$sw/$_k.cli.md" $_args > "$sw/$_k.cli" 2>&1; echo "$?" > "$sw/$_k.cli.rc"
  # the messages name the file, so compare with the world tag normalised
  sed "s#$sw/$_k\.unit#F#g" "$sw/$_k.unit" > "$sw/$_k.unit.n"; sed "s#$sw/$_k\.cli#F#g" "$sw/$_k.cli" > "$sw/$_k.cli.n"
  cmp -s "$sw/$_k.unit.n" "$sw/$_k.cli.n" && cmp -s "$sw/$_k.unit.rc" "$sw/$_k.cli.rc" || seam_ok=0
done
# the marker's sha= is over the body, which is identical across the two copies, so the written files agree too
cmp -s "$sw/pass.unit.md" "$sw/pass.cli.md" && cmp -s "$sw/refuse.unit.md" "$sw/refuse.cli.md" || seam_ok=0
if [ "$seam_ok" = 1 ] && ! cmp -s "$sw/refuse.unit.n" "$sw/pass.unit.n" && [ "$(cat "$sw/refuse.unit.rc")" = 64 ] && [ "$(cat "$sw/pass.unit.rc")" = 0 ]; then
  ok "MK0: the in-process wfd_mark_main answers byte-for-byte what wait-for-deliverable.sh --mark prints, writes and exits with, on a refusing call (rc 64) and a passing one (rc 0), and the two differ"
else
  bad "MK0: the in-process --mark seam differs from the CLI, or the two worlds do not differ (seam_ok=$seam_ok refuse=$(cat "$sw/refuse.unit.rc")/$(cat "$sw/refuse.cli.rc") pass=$(cat "$sw/pass.unit.rc")/$(cat "$sw/pass.cli.rc"))"
fi
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
