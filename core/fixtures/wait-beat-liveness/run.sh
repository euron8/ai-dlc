#!/usr/bin/env bash
# wait-beat-liveness — the bounded join must be able to tell a SLOW teammate from
# one that already went idle, and its WAITING line must not repeat verbatim.
#
# THE DEFECT THIS ADDRESSES. `wait-for-deliverable.sh` had exactly two things to say
# about a path: `WAITING ... not yet delivered` and `DELIVERED`. Neither carries any
# information about whether the dispatched teammate is still working. A teammate that
# finished its real work, went idle, and wrote its answer to a path the join was not
# watching therefore produced BYTE-IDENTICAL output, beat after beat, to a teammate
# genuinely still in progress. Reproduced S306: two teammates had both gone idle, the
# lead re-armed the same beat twice against an unchanging false negative, and it
# stopped only because the operator asked whether the wait was still appropriate. The
# manual liveness check that question prompted showed both idle immediately.
#
# THE GENERAL SHAPE. Any cause of a teammate finishing without satisfying the watched
# path — a crash after partial delivery, a role that returns text instead of a file, a
# path typo in either direction — produces that same silent-forever symptom. So this
# fixture is not about idleness; it is about the beat having a THIRD thing to say.
#
# WHAT MAKES THE FIX POSSIBLE AT ALL. The subject is a shell script and cannot call
# the lead's agent-listing tool. It does not need to: the harness exports
# CLAUDE_CODE_SESSION_ID into every Bash subprocess and appends one transcript per
# teammate under $HOME/.claude/projects/<slug>/<session>/subagents/*.jsonl. Those
# mtimes ARE the liveness signal. Every arm below is about the three answers that
# sensor can give — UNAVAILABLE, a live turn, and quiet past the threshold — and about
# the one hazard that spans them: two of those three must never collapse into one.
#
# THIS FIXTURE'S PROBE TREES ARE SYNTHETIC AND THAT IS DELIBERATE. It never reads the
# operator's real ~/.claude. Every teammate directory below is built under mktemp and
# reached through AI_DLC_TEAMMATE_DIR, except section 9, whose whole subject is the
# auto-resolution path — and that one builds a synthetic HOME rather than using the
# real one, because an arm that passes only on the machine that wrote it is an arm
# that cannot fail anywhere else.
set -uo pipefail

# HERMETIC — scrub the operator's tuning BEFORE this fixture sets its own (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "$HERE/../../scripts/wait-for-deliverable.sh" \
             "$HERE/../../../scripts/ai-dlc/wait-for-deliverable.sh" \
             "$HERE/../../../core/scripts/wait-for-deliverable.sh")"
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate wait-for-deliverable.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf 'wait-beat-liveness: FIXTURE BROKEN — %s\n' "$1" >&2; exit 2; }

TMPROOT="$(mktemp -d)" || broken "mktemp failed"
trap 'rm -rf "$TMPROOT"' EXIT
BEATOUT="$TMPROOT/beat.out"

# ---------------------------------------------------------------------------
# THE OUTPUT VOCABULARY, NAMED ONCE. Section 0 proves these three strings
# discriminate before any of them is used against the subject. A detector that
# cannot spell what it hunts scores its own subject as a non-instance and returns
# clean, which is the failure mode this whole repo scars over.
# ---------------------------------------------------------------------------
IDLE_BANNER='TEAMMATE IDLE, DELIVERABLE ABSENT'
LIVE_LINE='LIVENESS  a teammate in this session took a turn'
UNAVAIL_LINE='LIVENESS  unavailable (no teammate transcripts for this session)'

# Pure shell pattern match, no pipe and no grep. `grep -q` fed from a pipe reports
# NOT-FOUND on input that contains the pattern once the writer fills the pipe buffer
# (EPIPE under pipefail), and this fixture's inputs are multi-line beat output that
# grows as the subject's prose grows — exactly the shape that crosses that threshold
# silently.
has() { case "$OUT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# The fixture's OWN mtime reader. Deliberately not borrowed from the subject: a
# fixture that reused `mtime_of` would report an age of zero whenever that function
# broke, and the idle arms would then be measuring the code they are testing.
fx_mtime() {
  if stat -f "%m" . >/dev/null 2>&1; then stat -f "%m" "$1" 2>/dev/null || echo 0
  else stat -c "%Y" "$1" 2>/dev/null || echo 0; fi
}

# Backdate a file by N seconds. BSD `date -v` and GNU `date -d` split here, and a
# silent failure is the dangerous direction: an un-aged transcript makes every idle
# arm read "not idle" while printing nothing wrong. So this returns nonzero and the
# caller declares the fixture BROKEN rather than letting the arm score clean.
fx_backdate() {  # $1 = file, $2 = seconds into the past
  bd_st="$(date -v-"$2"S +%Y%m%d%H%M.%S 2>/dev/null || true)"
  [ -n "$bd_st" ] || bd_st="$(date -d "-$2 seconds" +%Y%m%d%H%M.%S 2>/dev/null || true)"
  [ -n "$bd_st" ] || return 1
  touch -t "$bd_st" "$1" 2>/dev/null || return 1
  return 0
}

# A teammate transcript, aged. `$2` seconds of quiet, verified by the fixture's own
# reader before the subject ever sees it.
mk_transcript() {  # $1 = dir, $2 = age seconds, $3 = basename
  mkdir -p "$1" || broken "cannot create $1"
  printf '{"t":1}\n' > "$1/$3" || broken "cannot write $1/$3"
  if [ "$2" -gt 0 ]; then
    fx_backdate "$1/$3" "$2" || broken "neither BSD nor GNU date can backdate a file here"
    age=$(( $(date +%s) - $(fx_mtime "$1/$3") ))
    [ "$age" -ge $(( $2 - 5 )) ] || broken "backdate did not take: asked $2s, measured ${age}s"
  fi
}

mk_work() {  # a fresh join tree; prints its path
  w="$(mktemp -d)" || broken "mktemp failed"
  mkdir -p "$w/_bmad-output" || broken "cannot create state dir"
  printf '%s' "$w"
}

# ---------------------------------------------------------------------------
# ONE BEAT. The quantum is 2s with a 1s poll and a 1s margin: RESERVE is max(MARGIN,
# POLL) = 1, so the deadline lands one second out and a waiting beat costs ~1-2s. The
# margin is load-bearing and easy to miss — at its default of 10 the deadline would
# land in the PAST, the poll loop would break immediately, and every arm below would
# pass or fail by luck rather than by the code path it names.
#
# CLAUDE_CODE_SESSION_ID IS SCRUBBED ON EVERY CALL BUT ONE. Left set, the subject
# would resolve the OPERATOR'S real teammate directory, every arm would score against
# whatever that machine happened to be doing, and the suite would be green or red by
# time of day. Section 9 is the single exception and it supplies its own HOME.
#
# Output goes to a FILE, not to command substitution: `OUT="$(beat ...)"` runs the
# function in a subshell, so the RC it sets never reaches the caller and every
# exit-code assertion reads a stale value.
# ---------------------------------------------------------------------------
beat() {  # $1=subject $2=workdir $3=idle_secs $4=teammate_dir ; rest = extra argv
  b_subj="$1" b_w="$2" b_idle="$3" b_td="$4"; shift 4
  ( cd "$b_w" && env -u CLAUDE_CODE_SESSION_ID \
        AI_DLC_WAIT_BEAT_SECS=2 \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${MAXB:-6}" \
        AI_DLC_TEAMMATE_IDLE_SECS="$b_idle" \
        AI_DLC_TEAMMATE_DIR="$b_td" \
        bash "$b_subj" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

# A chained sibling: the marker is keyed on the PID of the shell that INVOKES the
# subject, so it must be written by that very shell. The trailing `exit $?` is the
# whole mechanism — bash EXECs the last command of a `-c` string when it is a simple
# command, which would make the subject's parent the wrapper's own parent and leave
# the marker naming a PID the subject never looks up. Section 7b asserts it landed.
chained_beat() {  # $1=subject $2=workdir $3=idle_secs $4=teammate_dir
  c_subj="$1" c_w="$2" c_idle="$3" c_td="$4"
  ( cd "$c_w" && env -u CLAUDE_CODE_SESSION_ID \
        AI_DLC_WAIT_BEAT_SECS=60 \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${MAXB:-6}" \
        AI_DLC_TEAMMATE_IDLE_SECS="$c_idle" \
        AI_DLC_TEAMMATE_DIR="$c_td" \
    bash -c 'printf "%s" "$(date +%s)" > "_bmad-output/.wait-beats/.shell-$$" || exit 3
             s="$1"; shift
             bash "$s" "$@"
             exit $?' _ "$c_subj" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

# ===========================================================================
# 0. SELF-PROBE — runs BEFORE the corpus, and in BOTH directions.
#    An arm reporting a clean corpus without first proving it can produce a finding
#    has established that it ran, not that the corpus is clean. Every string this
#    fixture searches for is seeded here as an offender and as a NEAR-MISS: a
#    detector that flags everything and a detector that discriminates are the same
#    output on a corpus that happens to be clean.
# ===========================================================================
probe() {
  echo "  -- self-probe (must run before any subject invocation) --"

  OUT="head
${IDLE_BANNER} -- no teammate in this session has taken a
tail"
  if has "$IDLE_BANNER"; then ok "probe: the idle detector reports a seeded offender"
  else bad "probe: the idle detector cannot spell its own subject — every idle arm below is a false clean"; fi

  # NEAR-MISS. The banner's discriminating half is the second clause: an ABSENT
  # deliverable. `TEAMMATE IDLE, DELIVERABLE PRESENT` is not this finding, and a
  # detector keyed on `TEAMMATE IDLE` alone would score it as one.
  OUT="head
TEAMMATE IDLE, DELIVERABLE PRESENT -- something else entirely
tail"
  if has "$IDLE_BANNER"; then bad "probe: the idle detector fires on a near-miss, so its greens mean nothing"
  else ok "probe: the idle detector stays quiet on a seeded near-miss"; fi

  OUT="x ${LIVE_LINE} 4m ago. y"
  if has "$LIVE_LINE"; then ok "probe: the live-turn detector reports a seeded offender"
  else bad "probe: the live-turn detector cannot spell its own subject"; fi
  OUT="x LIVENESS a teammate in this session took a turn 4m ago. y"   # one space, not two
  if has "$LIVE_LINE"; then bad "probe: the live-turn detector fires on a near-miss"
  else ok "probe: the live-turn detector stays quiet on a seeded near-miss"; fi

  OUT="x ${UNAVAIL_LINE} -- this beat y"
  if has "$UNAVAIL_LINE"; then ok "probe: the unavailable detector reports a seeded offender"
  else bad "probe: the unavailable detector cannot spell its own subject"; fi
  OUT="x LIVENESS  unavailable (no teammate transcripts for this project) y"
  if has "$UNAVAIL_LINE"; then bad "probe: the unavailable detector fires on a near-miss"
  else ok "probe: the unavailable detector stays quiet on a seeded near-miss"; fi

  OUT=""
}

# ===========================================================================
# 1. THE SENSOR'S THREE ANSWERS ARE THREE, NOT TWO.
#    `unavailable` and `quiet for zero seconds` are different facts. Collapsing them
#    reports a DEAD SENSOR as a LIVE TEAMMATE — silent, and in the direction that
#    keeps the lead beating. Both spellings of "no signal" are covered: an override
#    naming a directory that does not exist, and no override and no session id at all.
# ===========================================================================
S1_unavailable() {
  W="$(mk_work)"

  beat "$SUBJ" "$W" 60 "$TMPROOT/does-not-exist"
  if has "$UNAVAIL_LINE"; then ok "unavailable: a teammate dir that does not exist reports NO SIGNAL"
  else bad "unavailable: a nonexistent teammate dir printed no unavailable line — the beat is silently blind: $OUT"; fi
  if has "$LIVE_LINE"; then bad "unavailable: no signal was reported as a LIVE TEAMMATE — the two answers collapsed"
  else ok "unavailable: no signal is NOT reported as a live teammate"; fi
  if has "$IDLE_BANNER"; then bad "unavailable: no signal was reported as IDLE — an absent sensor must never accuse"
  else ok "unavailable: no signal is NOT reported as idle"; fi

  # THE CONTROL, IN THE SAME INVOCATION SET. Three absences above establish only that
  # the run happened. This is the same subject and the same work tree with a REAL
  # stale transcript, and it must come back non-zero on the banner.
  TD="$TMPROOT/s1-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "unavailable: CONTROL — the same subject and tree DO report the banner when a real stale transcript is present"
  else bad "unavailable: CONTROL FAILED — the banner never fires at all, so the three absences above prove nothing: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 2. A LIVE TEAMMATE IS NOT IDLE — the near-miss direction of the threshold.
# ===========================================================================
S2_live() {
  W="$(mk_work)"
  TD="$TMPROOT/s2-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 3600 "$TD"
  if has "$LIVE_LINE"; then ok "live: a teammate that just took a turn is reported as live"
  else bad "live: a fresh transcript produced no live-turn line: $OUT"; fi
  if has "$IDLE_BANNER"; then bad "live: a teammate that took a turn seconds ago was accused of being idle — the threshold is not read"
  else ok "live: a fresh teammate does NOT trip the idle banner"; fi
  if has "$UNAVAIL_LINE"; then bad "live: a present transcript was reported as no signal"
  else ok "live: a present transcript is not reported as no signal"; fi

  rm -rf "$W"
}

# ===========================================================================
# 3. QUIET PAST THE THRESHOLD IS THE BANNER — and it changes NO DECISION.
#    This is the arm that would let the fix become the failure it replaces: an mtime
#    heuristic wired into the exit code would re-dispatch live teammates on a guess.
#    So the banner and rc=0 are asserted together, and the counter is asserted not to
#    have moved differently either.
# ===========================================================================
S3_idle_reports_but_decides_nothing() {
  W="$(mk_work)"
  TD="$TMPROOT/s3-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "idle: a session whose teammates have all been quiet past the threshold trips the banner"
  else bad "idle: a 2h-quiet teammate did not trip the banner: $OUT"; fi
  if [ "$RC" -eq 0 ]; then ok "idle: a still-waiting join still exits ZERO — the banner is a report, not a verdict"
  else bad "idle: rc $RC — the liveness report changed the exit code, which turns every quiet stretch into a harness failure line"; fi
  if has "WAITING   deliv.md"; then ok "idle: the ordinary WAITING line is still printed alongside the banner"
  else bad "idle: the banner REPLACED the waiting line — the lead loses the per-path status: $OUT"; fi

  # The banner must not suppress or duplicate the beat accounting either.
  beat "$SUBJ" "$W" 60 "$TD"
  if has "beat 2/6"; then ok "idle: the beat counter advances normally under the banner"
  else bad "idle: the counter did not reach beat 2 with the banner firing — the report is interfering with the sequence bound: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 4. THE MINIMUM ACROSS TEAMMATES — the error direction, asserted as a property.
#    One live teammate suppresses the banner for the whole wave. That UNDER-reports
#    idleness and never over-reports it, which is what makes the sensor safe to ship
#    with no per-path binding: nothing on disk joins a teammate name to a deliverable,
#    so an arm that accused a specific teammate would be inventing the join.
# ===========================================================================
S4_min_across_teammates() {
  W="$(mk_work)"
  TD="$TMPROOT/s4-td"
  mk_transcript "$TD" 7200 agent-astale-1.jsonl
  mk_transcript "$TD" 0    agent-afresh-2.jsonl

  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then bad "min: one live teammate did not suppress the banner — the sensor takes the OLDEST turn, so it over-accuses whenever a wave is uneven"
  else ok "min: one live teammate suppresses the banner for the whole session"; fi
  if has "$LIVE_LINE"; then ok "min: the live teammate is what gets reported"
  else bad "min: neither line was printed with a mixed directory: $OUT"; fi

  # THE CONTROL. Removing the one fresh transcript must flip it. Without this the arm
  # above passes against a sensor that never fires at all.
  rm -f "$TD/agent-afresh-2.jsonl"
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "min: CONTROL — with the fresh transcript removed the same directory DOES trip the banner"
  else bad "min: CONTROL FAILED — the banner cannot fire on this tree, so the suppression above proves nothing: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 5. A CLOSED JOIN GETS NO LIVENESS REPORT.
#    Printing one on a beat where everything landed trains the lead to skip the line,
#    which is how the S306 output became wallpaper in the first place.
# ===========================================================================
S5_delivered_is_silent() {
  W="$(mk_work)"
  TD="$TMPROOT/s5-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl

  # ARM FROM AN EPOCH THAT PRECEDES THE WRITE, and this is the subject's own escape hatch
  # rather than a workaround. The join accepts a deliverable only if it was written SINCE the
  # join armed, and a single-shot beat arms at invocation — so a file created on the line above
  # can only ever be as new as the arming instant, never newer. It passed for as long as the two
  # landed inside one second of each other and FAILED the moment they did not, which under the
  # pre-push pool is a red unit on a green tree: measured green 3 of 3 solo on two trees, and red
  # as the single failing unit of 174 at pool width 12. `--since` is clamped so it can only pull
  # the threshold EARLIER, so this widens nothing the subject would otherwise enforce.
  S5_SINCE=$(( $(date +%s) - 5 ))
  printf 'answer\n' > "$W/deliv.md"
  beat "$SUBJ" "$W" 60 "$TD" --since "$S5_SINCE"
  if has "DELIVERED deliv.md"; then ok "delivered: the join closes"
  else bad "delivered: a non-empty fresh file was not accepted: $OUT"; fi
  if has "$IDLE_BANNER" || has "$LIVE_LINE" || has "$UNAVAIL_LINE"; then
    bad "delivered: a closed join still printed a liveness line: $OUT"
  else ok "delivered: a closed join prints NO liveness line"; fi

  # THE CONTROL. Same tree, same teammate dir, deliverable removed — the line must
  # appear. An absence with no control is a statement that the run happened.
  rm -f "$W/deliv.md"
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "delivered: CONTROL — remove the deliverable and the same tree DOES report liveness"
  else bad "delivered: CONTROL FAILED — no liveness line on this tree either way: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 6. NON-DELIVERY CARRIES THE REPORT, AND STILL EXITS 1.
#    This is the highest-value moment for it: Rule 20 turns non-delivery into a
#    re-dispatch, and "no teammate has taken a turn in two hours" is the fact that
#    says the deliverable DIVERGED rather than the teammate being slow. Re-dispatching
#    against a path typo repeats the typo.
# ===========================================================================
S6_non_delivery() {
  W="$(mk_work)"
  TD="$TMPROOT/s6-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl

  MAXB=1
  beat "$SUBJ" "$W" 60 "$TD"          # charges the only beat
  beat "$SUBJ" "$W" 60 "$TD"          # sequence spent
  unset MAXB
  if has "NON-DELIVERY deliv.md"; then ok "non-delivery: the sequence bound still fires"
  else bad "non-delivery: the bound did not fire — the rest of this section is testing nothing: $OUT"; fi
  if [ "$RC" -eq 1 ]; then ok "non-delivery: exit 1 is unchanged by the liveness report"
  else bad "non-delivery: rc $RC, expected 1 — the report moved the exit code"; fi
  if has "$IDLE_BANNER"; then ok "non-delivery: the banner reaches the lead at the moment it decides to re-dispatch"
  else bad "non-delivery: the exhaustion path exits without reporting liveness, which is the one place it matters most: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 7. THE WAITING LINE MUST NOT REPEAT VERBATIM.
#    This is the half of the defect that needs no sensor at all. The lead re-armed the
#    same beat twice because two beats produced identical text. Two emitters exist and
#    only one of them carried a beat number; the chained-sibling line carried nothing.
# ===========================================================================
S7a_waiting_varies() {
  W="$(mk_work)"
  TD="$TMPROOT/s7-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 3600 "$TD"; L1="$OUT"
  beat "$SUBJ" "$W" 3600 "$TD"; L2="$OUT"

  # THE CONTROL COMES FIRST. "L1 differs from L2" is also true of two empty strings
  # and of a subject that crashed differently twice, so assert both are real WAITING
  # lines before reading the comparison.
  OUT="$L1"; g1=0; has "WAITING   deliv.md -- beat 1/6" && g1=1
  OUT="$L2"; g2=0; has "WAITING   deliv.md -- beat 2/6" && g2=1
  if [ "$g1" -eq 1 ] && [ "$g2" -eq 1 ]; then
    ok "vary: CONTROL — both beats emitted a real WAITING line, carrying beats 1 and 2"
  else bad "vary: CONTROL FAILED — beat lines not found (g1=$g1 g2=$g2); a difference between these two strings would mean nothing: $L1 || $L2"; fi

  if [ "$L1" != "$L2" ]; then ok "vary: two successive beats do NOT produce identical output"
  else bad "vary: two successive beats produced byte-identical output — this is the S306 defect verbatim"; fi

  OUT="$L2"
  if has "since this join armed"; then ok "vary: the WAITING line carries elapsed time since arming, which a --reset visibly restarts"
  else bad "vary: the WAITING line carries no clock, so a re-armed join is indistinguishable from a fresh one: $L2"; fi

  rm -rf "$W"
}

S7b_chained_waiting_varies() {
  W="$(mk_work)"
  TD="$TMPROOT/s7b-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl

  # PRIME FIRST, AND THIS IS NOT SETUP TIDINESS. The subject WIPES its whole counter
  # directory on the first beat of a new bound (the .bound self-heal), which takes the
  # sibling marker with it -- so a chained beat written as the FIRST invocation runs
  # with MAY_SLEEP=1, sleeps its quantum, and silently scores the other emitter. That
  # is section 7a a second time wearing this section's name, and it passes.
  beat "$SUBJ" "$W" 3600 "$TD"
  chained_beat "$SUBJ" "$W" 3600 "$TD"

  # THE ARM CANNOT FIRE UNLESS THE SIBLING MARKER LANDED. Without it the subject
  # sleeps its quantum and takes the OTHER emitter, and this whole section would be
  # scoring section 7a a second time.
  if has "a sibling beat already ran in this same Bash call"; then
    ok "chained: CONTROL — the sibling marker landed, so this is the MAY_SLEEP=0 emitter"
  else bad "chained: the chained-sibling path was not taken; this section is testing the wrong emitter: $OUT"; fi

  if has "WAITING   deliv.md -- beat 1/6 (no beat charged)"; then
    ok "chained: the non-sleeping WAITING line names the beat count and says no beat was charged"
  else bad "chained: the non-sleeping WAITING line carries no beat count — it was byte-identical on every invocation, which is what let the lead re-arm blind: $OUT"; fi
  if has "since"; then ok "chained: the non-sleeping WAITING line carries the elapsed clock"
  else bad "chained: the non-sleeping WAITING line carries no clock: $OUT"; fi
  if has "$LIVE_LINE"; then ok "chained: the liveness report reaches the chained emitter too"
  else bad "chained: a chained sibling returns without any liveness line, so a lead that chains beats stays blind: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 8. THE THRESHOLD IS READ, IN BOTH DIRECTIONS, ON INPUTS THAT DISCRIMINATE.
#    A control passing on an input ADJACENT to the one that matters reads exactly like
#    one that works, so these two runs differ ONLY in the threshold — same tree, same
#    transcript, same age.
# ===========================================================================
S8_threshold() {
  W="$(mk_work)"
  TD="$TMPROOT/s8-td"; mk_transcript "$TD" 3600 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 3000 "$TD"
  a=0; has "$IDLE_BANNER" && a=1
  beat "$SUBJ" "$W" 7200 "$TD"
  b=0; has "$IDLE_BANNER" && b=1

  if [ "$a" -eq 1 ] && [ "$b" -eq 0 ]; then
    ok "threshold: the SAME 1h-quiet transcript trips the banner at 3000s and not at 7200s"
  else bad "threshold: the threshold does not discriminate (below=$a above=$b) — one of the two sides is not being read"; fi

  rm -rf "$W"
}

# ===========================================================================
# 9. AUTO-RESOLUTION — the path that actually ships.
#    Every section above reaches the sensor through AI_DLC_TEAMMATE_DIR, which exists
#    so the sensor can be probed at all. NONE of them exercises the resolution a real
#    beat performs, and a fixture that only ever drives the override would be green
#    against a subject whose shipped resolver never worked. So this builds a synthetic
#    HOME with TWO project directories, the session living only in the second, and
#    drives the subject with nothing but CLAUDE_CODE_SESSION_ID.
# ===========================================================================
S9_auto_resolve() {
  W="$(mk_work)"
  H="$TMPROOT/home"
  SID="11111111-2222-3333-4444-555555555555"
  # THE DECOY CARRIES A FRESH TRANSCRIPT, and that is what makes this section able to
  # fail. An empty decoy directory scores "unavailable" too, so a resolver that
  # ignored the session id entirely would satisfy both arms below. A LIVE decoy makes
  # the two answers different: the right session says IDLE, the wrong one says live.
  mk_transcript "$H/.claude/projects/aaa-first-project/other-session/subagents" 0 agent-adecoy-9.jsonl
  mk_transcript "$H/.claude/projects/zzz-second-project/$SID/subagents" 7200 agent-aone-1.jsonl

  ( cd "$W" && env HOME="$H" CLAUDE_CODE_SESSION_ID="$SID" \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_IDLE_SECS=60 \
    bash "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if has "$IDLE_BANNER"; then ok "auto-resolve: the sensor finds THIS session's subagents dir from CLAUDE_CODE_SESSION_ID alone, past a project holding a live decoy session"
  else bad "auto-resolve: no banner with only the session id set — the shipped resolution path does not work, and every other section here drives an override that hides that: $OUT"; fi

  # THE CONTROL. Same HOME, same tree, a session id that names nothing. It must fall
  # to NO SIGNAL, not to the first directory it can reach.
  ( cd "$W" && env HOME="$H" CLAUDE_CODE_SESSION_ID="99999999-0000-0000-0000-000000000000" \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_IDLE_SECS=60 \
    bash "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1
  OUT="$(cat "$BEATOUT")"
  if has "$UNAVAIL_LINE"; then ok "auto-resolve: CONTROL — an unknown session id resolves to NO SIGNAL, not to whatever directory sorts first"
  else bad "auto-resolve: CONTROL FAILED — an unknown session id did not report no signal, so the resolver is matching something it should not: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 10. ONLY TRANSCRIPTS COUNT AS A TEAMMATE TURN.
#     The directory also accumulates `*.meta.json` sidecars, which are written ONCE at
#     spawn and never again. Counting those would make a session look live for as long
#     as it existed — the sensor's own version of "evidence of work that stays true
#     forever", which is the exact bug the progress mark was reshaped to avoid.
# ===========================================================================
S10_only_transcripts() {
  W="$(mk_work)"
  TD="$TMPROOT/s10-td"
  mk_transcript "$TD" 7200 agent-aone-1.jsonl
  printf '{"name":"one"}\n' > "$TD/agent-aone-1.meta.json"   # fresh, and NOT a turn

  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "transcripts: a freshly written non-transcript file in the directory is not counted as a teammate turn"
  else bad "transcripts: a fresh .meta.json suppressed the banner — the sensor counts spawn-time sidecars as activity and can never report idle: $OUT"; fi

  # THE CONTROL. The same file made into a transcript MUST suppress it, or the arm
  # above is passing because nothing in that directory is ever read.
  cp "$TD/agent-aone-1.meta.json" "$TD/agent-atwo-2.jsonl"
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then bad "transcripts: CONTROL FAILED — a fresh .jsonl did not suppress the banner either, so the directory is not being read at all: $OUT"
  else ok "transcripts: CONTROL — the same fresh bytes named .jsonl DO suppress the banner"; fi

  rm -rf "$W"
}

# ===========================================================================
# 11. MUTANTS.
#     Sections 1, 2, 4, 5, 9 and 10 all assert an ABSENCE somewhere, and an
#     absence-shaped arm passes against a subject that emits nothing. A seeded
#     near-miss establishes that an arm DISCRIMINATES; only a mutant establishes that
#     it discriminates AT ALL. Each mutant is a COPY — the subject is never edited —
#     and `cmp -s` fails the fixture on a sed that matched nothing, because a mutation
#     that did not apply reads exactly like an arm that cannot fire.
# ===========================================================================
MUTDIR=""
mutant() {  # $1 = name; rest = sed args. Prints nothing; sets $MUT
  m_name="$1"; shift
  [ -n "$MUTDIR" ] || { MUTDIR="$TMPROOT/mutants"; mkdir -p "$MUTDIR"; }
  MUT="$MUTDIR/$m_name.sh"
  sed "$@" "$SUBJ" > "$MUT" || broken "sed failed building mutant $m_name"
  if cmp -s "$MUT" "$SUBJ"; then
    bad "MUTANT $m_name: the mutation matched NOTHING — the anchor moved, and a mutant that changes nothing scores every kill it is asked for"
    return 1
  fi
  bash -n "$MUT" 2>/dev/null || { bad "MUTANT $m_name: the mutant does not parse, so its 'kill' would be a syntax error"; return 1; }
  return 0
}

M1_collapse_unavailable() {
  mutant collapse-unavailable \
    -e 's@\[ -n "$TEAMMATE_DIR" \] \&\& \[ -d "$TEAMMATE_DIR" \] || return 1@[ -n "$TEAMMATE_DIR" ] \&\& [ -d "$TEAMMATE_DIR" ] || { printf 0; return 0; }@' || return
  W="$(mk_work)"
  beat "$MUT" "$W" 60 "$TMPROOT/does-not-exist"
  if has "$LIVE_LINE" && ! has "$UNAVAIL_LINE"; then
    ok "MUTANT collapse-unavailable: folding NO SIGNAL into 'quiet for 0s' reports a dead sensor as a live teammate — section 1 catches it"
  else bad "MUTANT collapse-unavailable: section 1 survives the two answers being collapsed, so it is not asserting the distinction: $OUT"; fi
  rm -rf "$W"
}

M2_threshold_always() {
  mutant threshold-always \
    -e 's|if \[ "$sl_q_" -ge "$IDLE_SECS" \]; then|if [ "$sl_q_" -ge 0 ]; then|' || return
  W="$(mk_work)"
  TD="$TMPROOT/m2-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl
  beat "$MUT" "$W" 3600 "$TD"
  if has "$IDLE_BANNER"; then
    ok "MUTANT threshold-always: dropping the threshold accuses a teammate that just took a turn — section 2's near-miss catches it"
  else bad "MUTANT threshold-always: the banner did not fire with the threshold removed, so section 2's near-miss arm is not load-bearing: $OUT"; fi
  rm -rf "$W"
}

M3_max_not_min() {
  mutant max-not-min \
    -e 's|\[ "$tq_a_" -lt "$tq_best_" \]|[ "$tq_a_" -gt "$tq_best_" ]|' || return
  W="$(mk_work)"
  TD="$TMPROOT/m3-td"
  mk_transcript "$TD" 7200 agent-astale-1.jsonl
  mk_transcript "$TD" 0    agent-afresh-2.jsonl
  beat "$MUT" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then
    ok "MUTANT max-not-min: taking the OLDEST turn accuses a session that has a live teammate — section 4 catches the over-report"
  else bad "MUTANT max-not-min: section 4 survives the aggregation being inverted, so it is not asserting the error direction: $OUT"; fi
  rm -rf "$W"
}

M4_waiting_no_clock() {
  mutant waiting-no-clock \
    -e 's|.*human_age.*since this join armed, not yet delivered. Beat again.*|    say "WAITING   $t -- beat $b/$MAX_BEATS, not yet delivered. Beat again."|' || return
  W="$(mk_work)"
  TD="$TMPROOT/m4-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl
  beat "$MUT" "$W" 3600 "$TD"
  if has "WAITING   deliv.md" && ! has "since this join armed"; then
    ok "MUTANT waiting-no-clock: removing the elapsed clock from the sleeping emitter — section 7a catches it"
  else bad "MUTANT waiting-no-clock: section 7a survives the clock being removed: $OUT"; fi
  rm -rf "$W"
}

M5_chained_no_beat() {
  mutant chained-no-beat \
    -e 's|.*(no beat charged).*|    echo "WAITING   $t -- not yet delivered."|' \
    -e '/this join armed, not yet delivered\."$/d' || return
  W="$(mk_work)"
  TD="$TMPROOT/m5-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl
  beat "$MUT" "$W" 3600 "$TD"          # prime the bound; see section 7b
  chained_beat "$MUT" "$W" 3600 "$TD"
  if has "WAITING   deliv.md -- not yet delivered." && ! has "(no beat charged)"; then
    ok "MUTANT chained-no-beat: restoring the byte-identical chained line — section 7b catches it"
  else bad "MUTANT chained-no-beat: section 7b survives the chained line losing its beat count: $OUT"; fi
  rm -rf "$W"
}

M6_glob_widened() {
  mutant glob-widened \
    -e 's|for tq_f_ in "$TEAMMATE_DIR"/\*.jsonl; do|for tq_f_ in "$TEAMMATE_DIR"/*; do|' || return
  W="$(mk_work)"
  TD="$TMPROOT/m6-td"
  mk_transcript "$TD" 7200 agent-aone-1.jsonl
  printf '{"name":"one"}\n' > "$TD/agent-aone-1.meta.json"
  beat "$MUT" "$W" 60 "$TD"
  if ! has "$IDLE_BANNER"; then
    ok "MUTANT glob-widened: counting every file makes a spawn-time sidecar look like a turn, so the banner can never fire — section 10 catches it"
  else bad "MUTANT glob-widened: section 10 survives the glob being widened past .jsonl: $OUT"; fi
  rm -rf "$W"
}

# THE MUTANT THIS REPLACED IS WORTH RECORDING. The resolver first carried a second
# `[ -d "$td_" ]` existence test, and the mutant that dropped it came back GREEN --
# because the session id sits INSIDE the glob, so the pattern expands to at most one
# existing path and the test could never change an outcome. That is a vacuous guard,
# and the mutant is what proved it: the guard was deleted rather than the mutant
# weakened. What the resolver actually decides is WHICH SESSION, so that is the
# subject here.
M7_session_id_ignored() {
  mutant session-id-ignored \
    -e 's@/"${CLAUDE_CODE_SESSION_ID}"/subagents; do@/*/subagents; do@' || return
  W="$(mk_work)"
  H="$TMPROOT/m7home"
  SID="11111111-2222-3333-4444-555555555555"
  mk_transcript "$H/.claude/projects/aaa-first-project/other-session/subagents" 0 agent-adecoy-9.jsonl
  mk_transcript "$H/.claude/projects/zzz-second-project/$SID/subagents" 7200 agent-aone-1.jsonl
  ( cd "$W" && env HOME="$H" CLAUDE_CODE_SESSION_ID="$SID" \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_IDLE_SECS=60 \
    bash "$MUT" deliv.md ) > "$BEATOUT" 2>&1
  OUT="$(cat "$BEATOUT")"
  if has "$LIVE_LINE" && ! has "$IDLE_BANNER"; then
    ok "MUTANT session-id-ignored: a resolver that wildcards the session lands on another session's live decoy and reports it as this join's teammate — section 9 catches it"
  else bad "MUTANT session-id-ignored: section 9 survives the session id being dropped from the glob, so it is not asserting WHICH session was resolved: $OUT"; fi
  rm -rf "$W"
}

# THE UNMUTATED CONTROL, WITH A POSITIVE CONJUNCT. `rc=0 and nothing went wrong` is
# also exactly what a subject replaced by `exit 0` produces, so this asserts that a
# baseline banner IS present, not merely that no failure appeared.
M8_control() {
  MUT="$TMPROOT/mutants/control.sh"
  mkdir -p "$TMPROOT/mutants"
  cp "$SUBJ" "$MUT" || broken "cannot copy the subject"
  W="$(mk_work)"
  TD="$TMPROOT/m8-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl
  beat "$MUT" "$W" 60 "$TD"
  if has "$IDLE_BANNER" && has "WAITING   deliv.md" && [ "$RC" -eq 0 ]; then
    ok "MUTANT CONTROL: an unmutated copy reports the banner AND the waiting line at rc=0, so the kills above are the mutations and not the harness"
  else bad "MUTANT CONTROL: the unmutated copy does not reach a verdict (rc=$RC) — every kill above is unattributable: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 12. CWD INVARIANCE. The suite runs this from the repo root, so every arm above has
#     been observed at exactly one cwd. That cuts both ways here: a fixture can be
#     green only from the root, and it can be green only because decoy files happen to
#     exist there. Everything resolves through HERE (absolute, from $0) and through
#     mktemp trees, so cwd cannot reach any of it — asserted, not assumed.
# ===========================================================================
S12_cwd_invariance() {
  SELF_ABS="$HERE/$(basename "$0")"
  out="$( cd / && bash "$SELF_ABS" --run-one S2_live 2>&1 )"
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "cwd-invariance: a case reaches the same verdict launched from /"
  else bad "cwd-invariance: rc $rc from cwd=/ — some arm is reading a path relative to the repo root: $out"; fi
  # THE CONTROL. `-eq 0` is also what an empty run scores, and a case that printed
  # nothing is the exact shape of a resolution failure that exited quietly.
  n=0
  while IFS= read -r ln; do case "$ln" in '  ok'*) n=$((n+1)) ;; esac; done <<EOF
$out
EOF
  if [ "$n" -eq 3 ]; then ok "cwd-invariance: CONTROL — all three of that case's assertions ran from /, not zero of them"
  else bad "cwd-invariance: $n assertions from cwd=/ , expected 3 — the case exited without running, which scores as clean"; fi
}

# ===========================================================================
# 13. --complete: AN EARLY-WRITING SHARD IS DELIVERED ONLY BY ITS MARKER, AND ITS
#     OWN WRITES ARE ITS EVIDENCE OF WORK.
#     A seat that writes its header first and appends findings as it verifies them is
#     non-empty for its whole run, so the plain predicate would consume it half-written.
#     Every arm here drives TWO shapes one property apart: the same skeleton with and
#     without the flag, the marker last and the marker followed by a finding, and two
#     targets in one beat of which only one grows. The no-flag pins in sections 1-12 are
#     untouched and still pass, which is the byte-identical claim for callers without it.
# ===========================================================================
CBEAT_SINCE=""
# THE SETTLE WINDOW IS PINNED TO 1s here (its default is 180s, measured -- see the subject's
# --complete header). CB_BEAT is the quantum, 2s by default: enough wherever a beat only has
# to SEE a state. A call that must DELIVER a marked file passes CB_BEAT=3, the floor where it
# can settle (the strict `> 1` needs two whole seconds; a 2s beat polls one second past
# arming). Measured: at 2s everywhere, those six calls fail and nothing else does.
CB_BEAT=2
cbeat() {  # $1=subject $2=workdir ; rest = argv (targets relative to the workdir)
  cb_subj="$1" cb_w="$2"; shift 2
  ( cd "$cb_w" && env -u CLAUDE_CODE_SESSION_ID \
        AI_DLC_WAIT_BEAT_SECS="$CB_BEAT" \
        AI_DLC_WAIT_SETTLE_SECS="${CB_SETTLE:-1}" \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_WAIT_MARGIN_SECS=0 \
        AI_DLC_MAX_WAIT_BEATS="${CB_MAXB:-1}" \
        AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
        bash "$cb_subj" --since "$CBEAT_SINCE" "$@" ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
SKELETON='# requirements pm cross-1

- a finding verified so far'
MARKER='seat-complete: requirements pm cross-1'

S13a_complete_requires_marker() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/a.md"; printf '%s\n' "$SKELETON" > "$W/b.md"
  cbeat "$SUBJ" "$W" a.md
  if has "DELIVERED a.md"; then ok "complete: CONTROL — without the flag a non-empty skeleton is DELIVERED"
  else bad "complete: CONTROL FAILED — the no-flag skeleton was not delivered, so the WAITING below means nothing: $OUT"; fi
  cbeat "$SUBJ" "$W" --complete b.md
  if has "WAITING   b.md" && ! has "DELIVERED b.md" && [ "$RC" -eq 0 ]; then
    ok "complete: the same skeleton under --complete is WAITING, not DELIVERED"
  else bad "complete: a skeleton with no seat-complete line was accepted under --complete (rc=$RC): $OUT"; fi

  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/c.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete c.md
  if has "DELIVERED c.md"; then ok "complete: the marker as the last line DELIVERS"
  else bad "complete: a file ending in its seat-complete line was not delivered: $OUT"; fi

  printf '%s\n%s\n- a finding appended after the marker\n' "$SKELETON" "$MARKER" > "$W/d.md"
  cbeat "$SUBJ" "$W" --complete d.md
  if has "WAITING   d.md" && ! has "DELIVERED d.md"; then ok "complete: a marker that is NOT the last non-blank line does not deliver"
  else bad "complete: a marker followed by a finding was taken as completion: $OUT"; fi

  printf '%s\n%s\n\n   \n\n' "$SKELETON" "$MARKER" > "$W/e.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete e.md
  if has "DELIVERED e.md"; then ok "complete: trailing blank and whitespace-only lines do not hide the marker"
  else bad "complete: blank lines after the marker hid it: $OUT"; fi

  cbeat "$SUBJ" "$W" --complete --progress-path "$W" b.md
  if [ "$RC" -eq 64 ]; then ok "complete: --complete with --progress-path is refused (exit 64)"
  else bad "complete: --complete with --progress-path was accepted (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

S13b_complete_progress_per_target() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/grow.md"; printf '%s\n' "$SKELETON" > "$W/static.md"
  cbeat "$SUBJ" "$W" --complete grow.md static.md     # charges the only beat, stamps each mark
  sleep 1
  printf -- '- a second finding, verified\n' >> "$W/grow.md"
  cbeat "$SUBJ" "$W" --complete grow.md static.md     # sequence spent
  if has "PROGRESS  grow.md" && ! has "NON-DELIVERY grow.md"; then
    ok "complete: the target that grew since its own mark is granted PROGRESS"
  else bad "complete: a growing early-writing shard got no progress grant: $OUT"; fi
  if has "NON-DELIVERY static.md" && ! has "PROGRESS  static.md" && [ "$RC" -eq 1 ]; then
    ok "complete: the static target beside it reaches NON-DELIVERY (rc 1) — no cross-grant"
  else bad "complete: the static target was not declared non-delivered (rc=$RC): $OUT"; fi
  if has "re-arm with --reset --progress-path"; then bad "complete: the --progress-path advice printed under --complete: $OUT"
  else ok "complete: the --progress-path advice is suppressed under --complete"; fi

  # THE CONTROL for the suppression: the same exhaustion WITHOUT the flag prints it.
  # An ABSENT target: a file written in the same whole second as the arming instant
  # would be DELIVERED, which is the mtime race section 5 records.
  W2="$(mk_work)"
  cbeat "$SUBJ" "$W2" x.md
  cbeat "$SUBJ" "$W2" x.md
  if has "NON-DELIVERY x.md" && has "re-arm with --reset --progress-path"; then
    ok "complete: CONTROL — a no-flag exhaustion still prints the --progress-path advice"
  else bad "complete: CONTROL FAILED — the no-flag advice is gone, so its absence above proves nothing: $OUT"; fi
  rm -rf "$W" "$W2"
}

# A writer that rewrites a marked file ABOVE its marker every 0.3s until its SENTINEL exists:
# the consumer's cross seat that wrote once and then made seven in-place Edits. A counter makes
# every rewrite distinct bytes. Stopped by `churn_stop`, which touches the sentinel and waits --
# never killed. A hard cap of 60s keeps a lost sentinel from spinning forever.
churn() {  # $1 = file
  CHURN_STOP="$1.stop"; rm -f "$CHURN_STOP"
  ( i=0; end=$(( $(date +%s) + 60 ))
    while [ ! -e "$CHURN_STOP" ] && [ "$(date +%s)" -lt "$end" ]; do
      i=$((i + 1)); printf '%s\n- an in-place edit, revision %d\n%s\n' "$SKELETON" "$i" "$MARKER" > "$1"
      sleep 0.3
    done ) &
  CHURN_PID=$!
}
churn_stop() { : > "$CHURN_STOP"; wait "$CHURN_PID" 2>/dev/null; }

S13c_complete_marker_must_settle() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  # CONTROL: the identical marked file, static, delivers inside one beat -- so the WAITING
  # below is the churn and not a settle window the beat can never close.
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/still.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete still.md
  if has "DELIVERED still.md"; then ok "complete: CONTROL — a static marked file settles and DELIVERS inside one beat"
  else bad "complete: CONTROL FAILED — a static marked file did not deliver, so the churn arm means nothing: $OUT"; fi

  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/churn.md"
  churn "$W/churn.md"
  cbeat "$SUBJ" "$W" --complete churn.md       # charges the only beat
  o1="$OUT"
  cbeat "$SUBJ" "$W" --complete churn.md       # sequence spent: its own edits buy the one grant
  o3="$OUT"
  cbeat "$SUBJ" "$W" --complete churn.md       # grant spent, still churning
  o2="$OUT"; r2=$RC
  churn_stop
  OUT="$o1"
  if has "WAITING   churn.md" && ! has "DELIVERED churn.md"; then
    ok "complete: a marked file still being edited above its marker is WAITING, not DELIVERED"
  else bad "complete: a marked file edited in place mid-beat was delivered: $OUT"; fi
  OUT="$o3"
  if has "PROGRESS  churn.md" && ! has "DELIVERED churn.md"; then
    ok "complete: its in-place edits are its evidence of work (PROGRESS), still not DELIVERED"
  else bad "complete: a churning marked file got no PROGRESS grant, or delivered: $OUT"; fi
  OUT="$o2"
  if has "UNSETTLED churn.md" && ! has "absent after" && [ "$r2" -eq 1 ]; then
    ok "complete: on exhaustion a still-changing marked file is UNSETTLED, never 'absent' (rc 1)"
  else bad "complete: an exhausted still-changing marked file was not reported UNSETTLED (rc=$r2): $OUT"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete --reset churn.md
  if has "DELIVERED churn.md"; then ok "complete: once the edits stop, the same file settles and DELIVERS"
  else bad "complete: the churned file did not deliver after its edits stopped: $OUT"; fi

  # A marked file that PREDATES the join (a previous sprint's file at a reused path) is not
  # UNSETTLED: nothing changed. On exhaustion it is 'absent', the reading the arming NOTE gave.
  W3="$(mk_work)"; CBEAT_SINCE=""
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W3/old.md"
  fx_backdate "$W3/old.md" 3600 || broken "cannot backdate old.md"
  cb2() { ( cd "$W3" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      bash "$SUBJ" --complete old.md ) > "$BEATOUT" 2>&1; RC=$?; OUT="$(cat "$BEATOUT")"; }
  cb2; cb2
  if has "NON-DELIVERY old.md -- absent after" && ! has "UNSETTLED old.md" && [ "$RC" -eq 1 ]; then
    ok "complete: a marked file older than the join is 'absent' on exhaustion, never UNSETTLED"
  else bad "complete: a pre-join marked file was reported UNSETTLED or not absent (rc=$RC): $OUT"; fi
  rm -rf "$W" "$W3"
}

S13d_complete_unfinished_is_not_absent() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/u.md"
  cbeat "$SUBJ" "$W" --complete u.md gone.md   # charges the only beat
  if has "WAITING   u.md" && has "UNFINISHED u.md -- present, last non-blank line is not seat-complete:" \
     && ! has "UNFINISHED gone.md"; then
    ok "complete: a present unmarked file is WAITING and UNFINISHED; an absent one is not UNFINISHED"
  else bad "complete: the WAITING beat did not name the present unmarked file UNFINISHED: $OUT"; fi
  cbeat "$SUBJ" "$W" --complete u.md gone.md   # sequence spent
  if has "UNFINISHED u.md -- present, last non-blank line is not seat-complete:" \
     && ! has "NON-DELIVERY u.md -- absent" && [ "$RC" -eq 1 ]; then
    ok "complete: on exhaustion a present unmarked file is UNFINISHED, never 'absent' (rc 1)"
  else bad "complete: an exhausted present unmarked file was reported absent or not UNFINISHED (rc=$RC): $OUT"; fi
  # The near-miss in the SAME beat: a target that really is absent still says so.
  if has "NON-DELIVERY gone.md -- absent after"; then
    ok "complete: NEAR-MISS — an absent target beside it is still 'absent'"
  else bad "complete: NEAR-MISS FAILED — the absent target lost its 'absent' line: $OUT"; fi
  # Without the flag nothing is ever UNFINISHED.
  W2="$(mk_work)"; printf '%s\n' "$SKELETON" > "$W2/n.md"
  cbeat "$SUBJ" "$W2" n.md
  if has "DELIVERED n.md" && ! has "UNFINISHED"; then ok "complete: CONTROL — no UNFINISHED line without --complete"
  else bad "complete: CONTROL FAILED — a no-flag beat printed UNFINISHED or did not deliver: $OUT"; fi
  rm -rf "$W" "$W2"
}

S13e_complete_marker_not_fenced_not_crlf() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n```text\n%s\n' "$SKELETON" "$MARKER" > "$W/fenced.md"
  printf '%s\n```text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$W/closed.md"
  printf '%s\r\n%s\r\n' "$SKELETON" "$MARKER" > "$W/crlf.md"
  # A four-backtick fence is not closed by three, nor a backtick fence by tildes.
  printf '%s\n````text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$W/short.md"
  printf '%s\n```text\nquoted\n~~~\n%s\n' "$SKELETON" "$MARKER" > "$W/mixed.md"
  printf '%s\n````text\nquoted\n`````\n%s\n' "$SKELETON" "$MARKER" > "$W/long.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete fenced.md closed.md crlf.md short.md mixed.md long.md
  if has "WAITING   fenced.md" && ! has "DELIVERED fenced.md"; then
    ok "complete: a marker inside an unclosed fence does not deliver"
  else bad "complete: a marker inside an unclosed fence was taken as completion: $OUT"; fi
  if has "DELIVERED closed.md"; then ok "complete: NEAR-MISS — a marker after a CLOSED fence delivers"
  else bad "complete: NEAR-MISS FAILED — a marker after a closed fence did not deliver: $OUT"; fi
  if has "WAITING   short.md" && ! has "DELIVERED short.md" && has "WAITING   mixed.md" && ! has "DELIVERED mixed.md"; then
    ok "complete: a fence is not closed by a shorter run or by the other fence character"
  else bad "complete: a \`\`\`\` fence closed by \`\`\`, or a \`\`\` fence closed by ~~~, delivered: $OUT"; fi
  if has "DELIVERED long.md"; then ok "complete: NEAR-MISS — a fence closed by a LONGER run of its character delivers"
  else bad "complete: NEAR-MISS FAILED — a fence closed by a longer run did not deliver: $OUT"; fi
  if has "WAITING   crlf.md" && ! has "DELIVERED crlf.md"; then
    ok "complete: a marker on a CRLF line does not deliver"
  else bad "complete: a CRLF marker line was taken as completion: $OUT"; fi
  rm -rf "$W"
}

M13_settle_dropped() {
  mutant settle-dropped -e 's@^  settled "\$1" "\$id_st_"$@  return 0@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/churn.md"
  churn "$W/churn.md"
  cbeat "$MUT" "$W" --complete churn.md
  churn_stop
  if has "DELIVERED churn.md"; then ok "MUTANT settle-dropped: a file still being edited delivers — section 13c catches it"
  else bad "MUTANT settle-dropped: section 13c survives the settle check being dropped: $OUT"; fi
  rm -rf "$W"
}

M14_unfinished_reads_absent() {
  mutant unfinished-reads-absent \
    -e 's@^  \[ "\$COMPLETE" -eq 1 \] && \[ -s "\$1" \] && \[ "\$(mtime_of "\$1")" -ge "\$2" \] && ! has_marker "\$1"$@  false@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/u.md"
  cbeat "$MUT" "$W" --complete u.md
  cbeat "$MUT" "$W" --complete u.md
  if has "NON-DELIVERY u.md -- absent after" && ! has "UNFINISHED u.md"; then
    ok "MUTANT unfinished-reads-absent: a present seat file is called absent — section 13d catches it"
  else bad "MUTANT unfinished-reads-absent: section 13d survives UNFINISHED being folded into absent: $OUT"; fi
  rm -rf "$W"
}

M15_fence_ignored() {
  mutant fence-ignored -e 's@(fc == "" && l !~@(l !~@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n```text\n%s\n' "$SKELETON" "$MARKER" > "$W/fenced.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete fenced.md
  if has "DELIVERED fenced.md"; then ok "MUTANT fence-ignored: a fenced marker delivers — section 13e catches it"
  else bad "MUTANT fence-ignored: section 13e survives the fence test being dropped: $OUT"; fi
  rm -rf "$W"
}

M16_crlf_ignored() {
  mutant crlf-ignored -e 's@ && l !~ /\\r/ && @ \&\& @' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\r\n%s\r\n' "$SKELETON" "$MARKER" > "$W/crlf.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete crlf.md
  if has "DELIVERED crlf.md"; then ok "MUTANT crlf-ignored: a CRLF marker delivers — section 13e catches it"
  else bad "MUTANT crlf-ignored: section 13e survives the CRLF test being dropped: $OUT"; fi
  rm -rf "$W"
}

M17_fence_closes_on_any_run() {
  mutant fence-closes-on-any-run \
    -e 's@else if (substr(r, 1, 1) == fc && length(r) >= fl && substr($0, RSTART + RLENGTH) ~ /^\[ \\t\\r\]\*\$/) { fc = ""; fl = 0 }@else { fc = ""; fl = 0 }@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n````text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$W/short.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete short.md
  if has "DELIVERED short.md"; then ok "MUTANT fence-closes-on-any-run: a \`\`\`\` fence closed by \`\`\` delivers — section 13e catches it"
  else bad "MUTANT fence-closes-on-any-run: section 13e survives any fence run closing a fence: $OUT"; fi
  rm -rf "$W"
}

M18_settle_is_poll() {
  # D1's defect restored: the window read from POLL, not SETTLE. With POLL=1 and SETTLE=10 a file
  # changing every 4s settles under POLL and never under SETTLE. The settle test is STRICTLY greater
  # over whole-second stamps, so a POLL window needs at least 2 quiet seconds between two polls:
  # edits 2-2.5s apart left the mutant that by a hair, and it missed both unloaded and under a gate.
  # 4s gaps give it 3 polls per gap; 10s keeps the subject 6s clear of any gap load can stretch; the
  # edits outlast the 12s beat, so the subject never sees a quiet window at all.
  mutant settle-is-poll -e 's@-gt "\$SETTLE" \] && return 0@-gt "$POLL" ] \&\& return 0@' || return
  W="$(mk_work)"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/slow.md"
  ( for i in 1 2 3 4 5; do sleep 4; printf '%s\n- slow edit %d\n%s\n' "$SKELETON" "$i" "$MARKER" > "$W/slow.md"; done ) &
  sp_=$!
  for s in "$SUBJ" "$MUT"; do
    ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=12 AI_DLC_WAIT_SETTLE_SECS=10 \
        AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=3 \
        AI_DLC_STATE_DIR="_bmad-output/$(basename "$s")" AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
        bash "$s" --since "$(( $(date +%s) - 30 ))" --complete slow.md ) > "$BEATOUT.$(basename "$s")" 2>&1 &
  done
  wait
  OUT="$(cat "$BEATOUT.$(basename "$SUBJ")")"; o_s="$OUT"
  OUT="$(cat "$BEATOUT.$(basename "$MUT")")"
  if has "DELIVERED slow.md" && case "$o_s" in *"DELIVERED slow.md"*) false ;; *) true ;; esac; then
    ok "MUTANT settle-is-poll: edits 4s apart deliver under a POLL window and not under SETTLE=10 — the window is SETTLE's"
  else bad "MUTANT settle-is-poll: the settle window does not separate SETTLE from POLL (subject: $o_s) (mutant: $OUT)"; fi
  wait "$sp_" 2>/dev/null
  rm -rf "$W"
}

S13f_arming_note_only_for_pre_arm_files() {
  # D2: under --complete a POST-arm undelivered file did not "already have content".
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/post.md"
  CB_BEAT=2 cbeat "$SUBJ" "$W" --complete post.md
  if has "UNFINISHED post.md" && ! has "already had content when this join armed"; then
    ok "complete: a post-arm unmarked file gets no 'already had content' NOTE"
  else bad "complete: a post-arm file under --complete got the arming NOTE: $OUT"; fi
  # A PRE-arm file under --complete still gets it.
  W2="$(mk_work)"; printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W2/old.md"
  fx_backdate "$W2/old.md" 3600 || broken "cannot backdate old.md"
  CBEAT_SINCE=$(date +%s); CB_BEAT=2 cbeat "$SUBJ" "$W2" --complete old.md
  if has "NOTE      old.md already had content when this join armed"; then
    ok "complete: NEAR-MISS — a pre-arm file under --complete still gets the NOTE"
  else bad "complete: NEAR-MISS FAILED — a pre-arm file lost the arming NOTE: $OUT"; fi
  rm -rf "$W" "$W2"
}

S13g_no_flag_output_byte_identical() {
  # D2's clause must not move a byte of no-flag output: the same pre-arm world beaten by HEAD's
  # subject and by a copy with the clause removed, timing words masked, compared whole.
  W="$(mktemp -d)" || broken "mktemp failed"
  OLD="$W/old-subject.sh"
  sed 's@ && \[ "\$(mtime_of "\$t")" -lt "\$j" \] && PREEXISTING=@ \&\& PREEXISTING=@' "$SUBJ" > "$OLD"
  if cmp -s "$OLD" "$SUBJ"; then bad "no-flag byte identity: FIXTURE STALE — the D2 clause was not found to remove"; rm -rf "$W"; return; fi
  for s in "$SUBJ" "$OLD"; do
    d="$W/$(basename "$s" .sh)"; mkdir -p "$d/_bmad-output"
    printf 'stale\n' > "$d/x.md"; fx_backdate "$d/x.md" 3600 || broken "cannot backdate"
    # BOTH beats carry the short quantum: an env prefix binds one command, and a bare second
    # `bash` would sleep the 600s default.
    ( cd "$d" && export AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
        AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" && unset CLAUDE_CODE_SESSION_ID \
        && { bash "$s" x.md y.md; bash "$s" x.md y.md; } ) > "$d.raw" 2>&1
    sed -E 's/[0-9]+[smhd] (old|since|ago)/N \1/g' "$d.raw" > "$d.out"
  done
  a="$(cat "$W/$(basename "$SUBJ" .sh).out")"; b="$(cat "$W/old-subject.out")"
  case "$a" in *"already had content"*) : ;; *) bad "no-flag byte identity: CONTROL FAILED — the world never printed the arming NOTE: $a"; rm -rf "$W"; return ;; esac
  if [ "$a" = "$b" ]; then ok "no-flag byte identity: a pre-arm and an absent target print byte-identical output with and without the D2 clause"
  else bad "no-flag byte identity: the D2 clause changed no-flag output: [$a] vs [$b]"; fi
  rm -rf "$W"
}

M19_arming_note_ungated() {
  mutant arming-note-ungated -e 's@ && \[ "\$(mtime_of "\$t")" -lt "\$j" \] && PREEXISTING=@ \&\& PREEXISTING=@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/post.md"
  CB_BEAT=2 cbeat "$MUT" "$W" --complete post.md
  if has "already had content when this join armed"; then ok "MUTANT arming-note-ungated: a post-arm file gets the false NOTE — section 13f catches it"
  else bad "MUTANT arming-note-ungated: section 13f survives the D2 clause being removed: $OUT"; fi
  rm -rf "$W"
}

M9_marker_not_required() {
  mutant marker-not-required -e 's@^  \[ "\$COMPLETE" -eq 1 \] || return 0$@  return 0@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/b.md"
  cbeat "$MUT" "$W" --complete b.md
  if has "DELIVERED b.md"; then ok "MUTANT marker-not-required: a skeleton is delivered under --complete — section 13a catches it"
  else bad "MUTANT marker-not-required: section 13a survives the marker test being dropped: $OUT"; fi
  rm -rf "$W"
}

M10_global_progress_grant() {
  mutant global-progress-grant \
    -e 's@^    target_progressed "\$t" "\$pg" && PROGRESSED=1$@    for t2_ in $TARGETS; do target_progressed "$t2_" "$pg" \&\& PROGRESSED=1; done@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/grow.md"; printf '%s\n' "$SKELETON" > "$W/static.md"
  cbeat "$MUT" "$W" --complete grow.md static.md
  sleep 1; printf -- '- a second finding\n' >> "$W/grow.md"
  cbeat "$MUT" "$W" --complete grow.md static.md
  if has "PROGRESS  static.md" && ! has "NON-DELIVERY static.md"; then
    ok "MUTANT global-progress-grant: one target's writes extend the other's wait — section 13b catches it"
  else bad "MUTANT global-progress-grant: section 13b survives a cross-grant: $OUT"; fi
  rm -rf "$W"
}

M11_marker_anywhere() {
  mutant marker-anywhere -e 's@NF { l = \$0 }@/^seat-complete: / { l = $0 }@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n- a finding appended after the marker\n' "$SKELETON" "$MARKER" > "$W/d.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete d.md
  if has "DELIVERED d.md"; then ok "MUTANT marker-anywhere: a marker followed by a finding delivers — section 13a catches it"
  else bad "MUTANT marker-anywhere: section 13a survives the marker being matched anywhere: $OUT"; fi
  rm -rf "$W"
}

M12_trailing_blank_hides_marker() {
  mutant trailing-blank-hides -e 's@NF { l = \$0 }@{ l = $0 }@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n\n   \n\n' "$SKELETON" "$MARKER" > "$W/e.md"
  cbeat "$MUT" "$W" --complete e.md
  if has "WAITING   e.md" && ! has "DELIVERED e.md"; then
    ok "MUTANT trailing-blank-hides: blank lines after the marker block delivery — section 13a catches it"
  else bad "MUTANT trailing-blank-hides: section 13a survives blank lines being read as the last line: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 14. --complete-repair: THE SERIAL REMEDIATOR'S RECORD IS KEYED ON `repair-complete: serial `,
#     AND ONLY THAT, PER CALL.
#     A joined repair record concatenates PART remediators' records, so it can end in a part's
#     own `seat-complete:` marker before the serial pass has started. A beat that accepted either
#     token would consume it. Every arm pairs the token with a near-miss one property away: the
#     part marker, the bare prefix with no `serial `, the same line as a list item, and the repair
#     token offered to a plain --complete call.
# ===========================================================================
REPAIR_MARKER='repair-complete: serial requirements'
S14a_complete_repair_token() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$REPAIR_MARKER" > "$W/r1.md"
  printf '%s\nseat-complete: part 3\n' "$SKELETON" > "$W/r2.md"
  printf '%s\nrepair-complete: done\n' "$SKELETON" > "$W/r3.md"
  printf '%s\n- %s\n' "$SKELETON" "$REPAIR_MARKER" > "$W/r4.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete-repair r1.md r2.md r3.md r4.md
  if has "DELIVERED r1.md"; then ok "repair: a record ending 'repair-complete: serial requirements' DELIVERS under --complete-repair"
  else bad "repair: a record ending in the serial repair marker was not delivered: $OUT"; fi
  if has "WAITING   r2.md" && ! has "DELIVERED r2.md"; then
    ok "repair: a record ending in a PART remediator's 'seat-complete: part 3' does not deliver under --complete-repair"
  else bad "repair: a part remediator's seat-complete marker was taken as the serial repair marker: $OUT"; fi
  if has "WAITING   r3.md" && ! has "DELIVERED r3.md"; then ok "repair: NEAR-MISS — bare 'repair-complete: done' does not deliver"
  else bad "repair: 'repair-complete: done' (no 'serial ') delivered: $OUT"; fi
  if has "WAITING   r4.md" && ! has "DELIVERED r4.md"; then ok "repair: NEAR-MISS — the marker as a list item ('- repair-complete: serial ...') does not deliver"
  else bad "repair: a list-item repair marker delivered — the token is not keyed at column 0: $OUT"; fi
  if grep -qxF 'UNFINISHED r2.md -- present, last non-blank line is not repair-complete: serial' "$BEATOUT"; then
    ok "repair: the UNFINISHED line under --complete-repair names 'repair-complete: serial'"
  else bad "repair: the UNFINISHED line under --complete-repair does not read '... is not repair-complete: serial': $OUT"; fi

  # The token is keyed per CALL: the repair line offered to a plain --complete beat is not a
  # marker. The seat file beside it is the same-beat control that --complete still delivers.
  printf '%s\nrepair-complete: serial x\n' "$SKELETON" > "$W/s1.md"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/s2.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete s1.md s2.md
  if has "DELIVERED s2.md"; then ok "repair: CONTROL — the same --complete beat delivers a seat file ending seat-complete:"
  else bad "repair: CONTROL FAILED — the --complete beat delivered nothing, so the WAITING below means nothing: $OUT"; fi
  if has "WAITING   s1.md" && ! has "DELIVERED s1.md"; then ok "repair: a seat file ending 'repair-complete: serial x' does NOT deliver under plain --complete"
  else bad "repair: the repair token delivered a plain --complete call — the token is not keyed per call: $OUT"; fi
  if grep -qxF 'UNFINISHED s1.md -- present, last non-blank line is not seat-complete:' "$BEATOUT"; then
    ok "repair: under --complete the UNFINISHED line is byte-identical '... is not seat-complete:'"
  else bad "repair: the --complete UNFINISHED line moved: $OUT"; fi

  cbeat "$SUBJ" "$W" --complete --complete-repair r1.md
  r1=$RC
  cbeat "$SUBJ" "$W" --complete-repair --complete r1.md
  if [ "$r1" -eq 64 ] && [ "$RC" -eq 64 ]; then ok "repair: --complete with --complete-repair is refused (exit 64), in either order"
  else bad "repair: --complete with --complete-repair was accepted (rc=$r1 / $RC): $OUT"; fi
  rm -rf "$W"
}

M20_repair_token_is_seat() {
  mutant repair-token-is-seat -e 's@MARK_TOKEN="repair-complete: serial "@MARK_TOKEN="seat-complete: "@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\nseat-complete: part 3\n' "$SKELETON" > "$W/r2.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete-repair r2.md
  if has "DELIVERED r2.md"; then ok "MUTANT repair-token-is-seat: --complete-repair keyed on seat-complete: consumes a part's record — section 14a catches it"
  else bad "MUTANT repair-token-is-seat: section 14a survives --complete-repair accepting the part marker: $OUT"; fi
  rm -rf "$W"
}

M21_repair_either_token() {
  mutant repair-either-token \
    -e 's@index(l, ENVIRON\["MT_"\]) == 1)@(index(l, ENVIRON["MT_"]) == 1 || index(l, "seat-complete: ") == 1 || index(l, "repair-complete: serial ") == 1))@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\nseat-complete: part 3\n' "$SKELETON" > "$W/r2.md"
  printf '%s\nrepair-complete: serial x\n' "$SKELETON" > "$W/s1.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete-repair r2.md; o1="$OUT"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete s1.md
  if has "DELIVERED s1.md" && case "$o1" in *"DELIVERED r2.md"*) true ;; *) false ;; esac; then
    ok "MUTANT repair-either-token: a marker test accepting either token delivers the part record AND the repair line under --complete — section 14a catches both"
  else bad "MUTANT repair-either-token: section 14a survives an either-token marker test (repair beat: $o1) (complete beat: $OUT)"; fi
  rm -rf "$W"
}

M22_repair_token_no_space() {
  mutant repair-token-no-serial -e 's@MARK_TOKEN="repair-complete: serial "@MARK_TOKEN="repair-complete: "@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\nrepair-complete: done\n' "$SKELETON" > "$W/r3.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete-repair r3.md
  if has "DELIVERED r3.md"; then ok "MUTANT repair-token-no-serial: the token without 'serial ' delivers 'repair-complete: done' — section 14a's near-miss catches it"
  else bad "MUTANT repair-token-no-serial: section 14a's bare-prefix near-miss survives: $OUT"; fi
  rm -rf "$W"
}

M23_repair_marker_not_col0() {
  mutant marker-not-col0 -e 's@index(l, ENVIRON\["MT_"\]) == 1@index(l, ENVIRON["MT_"]) > 0@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n- %s\n' "$SKELETON" "$REPAIR_MARKER" > "$W/r4.md"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete-repair r4.md
  if has "DELIVERED r4.md"; then ok "MUTANT marker-not-col0: a marker matched anywhere in the line delivers a list item — section 14a's near-miss catches it"
  else bad "MUTANT marker-not-col0: section 14a's list-item near-miss survives: $OUT"; fi
  rm -rf "$W"
}

M24_repair_both_flags_accepted() {
  mutant repair-both-flags -e 's@^if \[ "\$SEAT_FLAG" -eq 1 \] && \[ "\$COMPLETE_REPAIR" -eq 1 \]; then$@if false; then@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  cbeat "$MUT" "$W" --complete --complete-repair r1.md
  if [ "$RC" -ne 64 ] && has "WAITING   r1.md"; then ok "MUTANT repair-both-flags: the refusal removed, both flags run a beat — section 14a's exit-64 arm catches it"
  else bad "MUTANT repair-both-flags: section 14a's exit-64 arm survives the refusal being removed (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

M25_mark_name_fixed() {
  mutant mark-name-fixed -e 's@^MARK_NAME="\${MARK_TOKEN% }"$@MARK_NAME="seat-complete:"@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\nseat-complete: part 3\n' "$SKELETON" > "$W/r2.md"
  cbeat "$MUT" "$W" --complete-repair r2.md
  if has "UNFINISHED r2.md -- present, last non-blank line is not seat-complete:" \
     && ! grep -qxF 'UNFINISHED r2.md -- present, last non-blank line is not repair-complete: serial' "$BEATOUT"; then
    ok "MUTANT mark-name-fixed: the UNFINISHED line naming seat-complete: under --complete-repair — section 14a catches it"
  else bad "MUTANT mark-name-fixed: section 14a survives the repair UNFINISHED line naming the wrong token: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 15. --status: THE BEAT'S OWN VERDICT, WITHOUT THE BEAT, AND IT WRITES NOTHING.
#     A progress check that disagrees with the beat that later consumes the file is worse than
#     none, and the inputs that separate a shipped predicate from a hand-rolled `tail -1` test
#     are exactly the ones a seat produces: a fenced marker, a CRLF line, a finding after the
#     marker, trailing blank lines, a closed fence before the marker.
# ===========================================================================
scall() {  # $1=subject $2=workdir ; rest = argv after --status. CB_SETTLE honoured.
  sc_subj="$1" sc_w="$2"; shift 2
  ( cd "$sc_w" && env -u CLAUDE_CODE_SESSION_ID \
        AI_DLC_WAIT_SETTLE_SECS="${CB_SETTLE:-1}" \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${CB_MAXB:-1}" \
        AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
        bash "$sc_subj" --status "$@" ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
# A beat in its OWN parent shell, so a second beat in one case sleeps instead of returning as a
# chained sibling. The trailing `exit $?` stops bash exec-ing the subject in place of the wrapper.
obeat() {  # $1=subject $2=workdir $3=outfile $4=beat secs $5=settle secs $6=since ; rest = argv
  ob_subj="$1" ob_w="$2" ob_o="$3" ob_b="$4" ob_st="$5" ob_si="$6"; shift 6
  ( cd "$ob_w" && env -u CLAUDE_CODE_SESSION_ID \
        AI_DLC_WAIT_BEAT_SECS="$ob_b" AI_DLC_WAIT_SETTLE_SECS="$ob_st" \
        AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=6 \
        AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
    bash -c '"$@"; exit $?' _ bash "$ob_subj" --since "$ob_si" "$@" ) > "$ob_o" 2>&1
}
SIBLING_NOTE='a sibling beat already ran in this same Bash call'
PARITY_FILES="p-fenced.md p-crlf.md p-notlast.md p-trail.md p-closed.md"
mk_parity_world() {  # $1 = workdir
  printf '%s\n```text\n%s\n' "$SKELETON" "$MARKER" > "$1/p-fenced.md"
  printf '%s\r\n%s\r\n' "$SKELETON" "$MARKER" > "$1/p-crlf.md"
  printf '%s\n%s\n- a finding after the marker\n' "$SKELETON" "$MARKER" > "$1/p-notlast.md"
  printf '%s\n%s\n\n   \n\n' "$SKELETON" "$MARKER" > "$1/p-trail.md"
  printf '%s\n```text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$1/p-closed.md"
}
# The beat's verdict for one file, in --status's vocabulary. A beat names no UNSETTLED state
# before exhaustion: a present, post-arm file it reports WAITING with no UNFINISHED line beneath
# is one whose marker it accepted and whose settle window has not closed -- UNSETTLED. Every
# parity file is written after the join's --since, so "present" is "post-arm" here.
beat_class() {  # $1 = name, $2 = workdir; reads OUT; sets PC
  if has "DELIVERED $1"; then PC=DELIVERED
  elif has "UNFINISHED $1 --"; then PC=UNFINISHED
  elif has "WAITING   $1"; then if [ -s "$2/$1" ]; then PC=UNSETTLED; else PC=WAITING; fi
  else PC=NONE; fi
}
status_class() {  # $1 = name; reads OUT; sets PC
  if has "DELIVERED $1"; then PC=DELIVERED
  elif has "UNFINISHED $1 --"; then PC=UNFINISHED
  elif has "UNSETTLED $1 --"; then PC=UNSETTLED
  elif has "WAITING   $1 --"; then PC=WAITING
  else PC=NONE; fi
}
parity() {  # $1 = beat output, $2 = status output, $3 = workdir; sets MISMATCH and CLASSES
  MISMATCH=""; CLASSES=""
  for pf in $PARITY_FILES; do
    OUT="$1"; beat_class "$pf" "$3"; pb="$PC"
    OUT="$2"; status_class "$pf"; ps="$PC"
    CLASSES="$CLASSES $pf=$pb"
    [ "$pb" = "$ps" ] && [ "$pb" != NONE ] || MISMATCH="$MISMATCH $pf:beat=$pb,status=$ps"
  done
}

S15a_status_matches_beat() {
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  mk_parity_world "$W"
  # INSTANT 0 -- no beat has recorded a settle. The beat that follows runs SETTLE=60, so it
  # records each marked file's hash and cannot close the window: its verdict is the UNSETTLED
  # case. --status before it must say UNSETTLED, never DELIVERED.
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --since "$SI" $PARITY_FILES; st0="$OUT"
  obeat "$SUBJ" "$W" "$BEATOUT" 2 60 "$SI" --complete $PARITY_FILES; bt1="$(cat "$BEATOUT")"
  sleep 2
  # INSTANT 1 -- under SETTLE=1 those recorded hashes are now past the window. --status must say
  # DELIVERED for exactly the files the next beat delivers, UNFINISHED where it says UNFINISHED.
  CB_SETTLE=1 scall "$SUBJ" "$W" --complete --since "$SI" $PARITY_FILES; st1="$OUT"
  obeat "$SUBJ" "$W" "$BEATOUT" 2 1 "$SI" --complete $PARITY_FILES; bt2="$(cat "$BEATOUT")"

  OUT="$bt1$bt2"
  if has "$SIBLING_NOTE"; then bad "status parity: a beat ran as a chained sibling, so its verdict is not the sleeping beat's: $OUT"
  else ok "status parity: CONTROL — both beats slept in their own shell (no sibling NOTE)"; fi
  # The control that the five inputs DISCRIMINATE: the beat must deliver some and refuse others.
  OUT="$bt2"
  if has "DELIVERED p-trail.md" && has "DELIVERED p-closed.md" && has "UNFINISHED p-fenced.md --" \
     && has "UNFINISHED p-crlf.md --" && has "UNFINISHED p-notlast.md --"; then
    ok "status parity: CONTROL — the beat delivers trailing-blank and closed-fence, and calls fenced, CRLF and marker-not-last UNFINISHED"
  else bad "status parity: CONTROL FAILED — the beat's verdicts are not the expected split, so parity would mean nothing: $OUT"; fi
  parity "$bt1" "$st0" "$W"
  if [ -z "$MISMATCH" ]; then ok "status parity: before any settle --status equals the beat on all five inputs (marked files UNSETTLED, never DELIVERED)"
  else bad "status parity: --status disagrees with the beat before settle:$MISMATCH (beat:$CLASSES) -- status: $st0"; fi
  OUT="$st0"
  if has "UNSETTLED p-trail.md --" && ! has "DELIVERED p-trail.md"; then ok "status parity: a marked file with no beat-recorded settle reads UNSETTLED"
  else bad "status parity: a marked file with no recorded settle did not read UNSETTLED: $st0"; fi
  parity "$bt2" "$st1" "$W"
  if [ -z "$MISMATCH" ]; then ok "status parity: after the settle window --status equals the consuming beat on all five inputs (DELIVERED where it delivers)"
  else bad "status parity: --status disagrees with the consuming beat:$MISMATCH (beat:$CLASSES) -- status: $st1"; fi
  rm -rf "$W"
}

M26_status_last_line_tail() {
  mutant status-last-line-tail \
    -e 's@^status_marked() { has_marker "\$1"; }$@status_marked() { tail -1 "$1" | grep -q '\''^seat-complete'\''; }@' || return
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  mk_parity_world "$W"
  obeat "$SUBJ" "$W" "$BEATOUT" 2 60 "$SI" --complete $PARITY_FILES; bt="$(cat "$BEATOUT")"
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --since "$SI" $PARITY_FILES; parity "$bt" "$OUT" "$W"; m_ctl="$MISMATCH"
  CB_SETTLE=60 scall "$MUT" "$W" --complete --since "$SI" $PARITY_FILES; parity "$bt" "$OUT" "$W"; m_mut="$MISMATCH"
  case "$m_mut" in *p-trail.md:*p-crlf.md:*|*p-crlf.md:*p-trail.md:*) km=1 ;; *) km=0 ;; esac
  if [ -z "$m_ctl" ] && [ "$km" -eq 1 ]; then
    ok "MUTANT status-last-line-tail: a hand-rolled tail -1 marker test disagrees with the beat on trailing-blank and CRLF — section 15a catches it"
  else bad "MUTANT status-last-line-tail: section 15a survives (control mismatches:${m_ctl:- none}) (mutant mismatches:${m_mut:- none})"; fi
  rm -rf "$W"
}

S15b_status_absent_and_unsettled() {
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf 'answer\n' > "$W/present.md"
  scall "$SUBJ" "$W" --since "$SI" present.md gone.md
  if has "DELIVERED present.md" && has "WAITING   gone.md -- absent or empty" && has "STATUS -- 1 delivered, 1 not."; then
    ok "status: an ABSENT path reads WAITING and the summary counts it as not delivered"
  else bad "status: an absent path was not WAITING, or was counted as delivered: $OUT"; fi
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/sealed.md"
  scall "$SUBJ" "$W" --complete --since "$SI" sealed.md
  if has "UNSETTLED sealed.md --" && ! has "DELIVERED sealed.md"; then
    ok "status: one --status call on a marked file with no beat-recorded settle prints UNSETTLED, never DELIVERED"
  else bad "status: a marked file with no recorded settle was not UNSETTLED: $OUT"; fi
  scall "$SUBJ" "$W" --reset --since "$SI" present.md
  if [ "$RC" -eq 64 ]; then ok "status: --status with --reset is refused (exit 64)"
  else bad "status: --status --reset was accepted (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

M27_status_absent_delivered() {
  mutant status-absent-delivered \
    -e 's@^      echo "WAITING   \$t -- absent or empty"$@      S_V="DELIVERED"; echo "DELIVERED $t"@' || return
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf 'answer\n' > "$W/present.md"
  scall "$MUT" "$W" --since "$SI" present.md gone.md
  if has "DELIVERED gone.md" && has "STATUS -- 2 delivered, 0 not."; then
    ok "MUTANT status-absent-delivered: an absent seat counted as closed (graph s319) — section 15b catches it"
  else bad "MUTANT status-absent-delivered: section 15b survives the absent branch printing DELIVERED: $OUT"; fi
  rm -rf "$W"
}

M28_status_missing_record_ancient() {
  mutant status-missing-record-ancient \
    -e 's@\.settle" 2>/dev/null || echo '\'''\'')"$@.settle" 2>/dev/null || echo "$(content_hash "$t") 0")"@' || return
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/sealed.md"
  scall "$MUT" "$W" --complete --since "$SI" sealed.md
  if has "DELIVERED sealed.md"; then ok "MUTANT status-missing-record-ancient: a missing settle record read as an ancient one says DELIVERED — section 15b catches it"
  else bad "MUTANT status-missing-record-ancient: section 15b survives a missing record reading as settled: $OUT"; fi
  rm -rf "$W"
}

M29_status_reset_accepted() {
  mutant status-reset-accepted -e 's@^if \[ "\$STATUS" -eq 1 \] && \[ "\$RESET" -eq 1 \]; then$@if false; then@' || return
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf 'answer\n' > "$W/present.md"
  scall "$MUT" "$W" --reset --since "$SI" present.md
  if [ "$RC" -ne 64 ] && has "STATUS --"; then ok "MUTANT status-reset-accepted: --status --reset runs — section 15b's exit-64 arm catches it"
  else bad "MUTANT status-reset-accepted: section 15b's exit-64 arm survives (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

fx_snap() {  # $1 = tree, $2 = out file: the listing and every file's hash, in find order
  { find "$1" -print; find "$1" -type f -exec shasum {} +; } > "$2" 2>&1
}
fx_key() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }

S15c_status_read_only() {
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 )); CBEAT_SINCE="$SI"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/a.md"
  printf '%s\n' "$SKELETON" > "$W/u.md"
  printf 'x\n' > "$W/nojoin.md"
  CB_SETTLE=60 cbeat "$SUBJ" "$W" --complete a.md u.md     # arms a.md and u.md: .since, .settle, .progress, .bound
  CD="$W/_bmad-output/.wait-beats"
  # A STALE BOUND: the beat wipes every counter when .bound disagrees with its own bound.
  printf '99' > "$CD/.bound"
  rm -f "$CD"/.shell-*
  [ -f "$CD/$(fx_key a.md).since" ] && [ -f "$CD/$(fx_key a.md).settle" ] \
    || broken "the arming beat left no .since/.settle for a.md — the read-only world is not the one this arm names"
  fx_snap "$W" "$TMPROOT/snap1"
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete a.md u.md nojoin.md gone.md; o_a="$OUT"
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --since "$SI" a.md u.md nojoin.md gone.md; o_b="$OUT"
  fx_snap "$W" "$TMPROOT/snap2"
  if grep -q '/\.bound$' "$TMPROOT/snap1" && cmp -s "$TMPROOT/snap1" "$TMPROOT/snap2"; then
    ok "status: read-only — two --status calls over joined, unjoined and absent paths leave every file and listing byte-identical, stale .bound included"
  else bad "status: --status changed the state tree (or the snapshot is empty)"; fi
  n_shell=0; for f in "$CD"/.shell-*; do [ -e "$f" ] && n_shell=$((n_shell+1)); done
  if [ "$n_shell" -eq 0 ] && [ ! -e "$W/_bmad-output/.beat-inflight" ] && [ ! -e "$CD/$(fx_key nojoin.md).since" ] \
     && [ "$(cat "$CD/.bound")" = 99 ]; then
    ok "status: no .shell-* marker, no .beat-inflight, no .since for the unjoined path, and the stale .bound is untouched"
  else bad "status: --status wrote a marker (shell=$n_shell inflight=$([ -e "$W/_bmad-output/.beat-inflight" ] && echo y) nojoin.since=$([ -e "$CD/$(fx_key nojoin.md).since" ] && echo y) bound=$(cat "$CD/.bound"))"; fi
  OUT="$o_a"
  if has "WAITING   nojoin.md -- no join armed" && has "WAITING   gone.md -- no join armed" \
     && has "UNSETTLED a.md --" && has "UNFINISHED u.md --"; then
    ok "status: with no join armed and no --since a path reads WAITING 'no join armed'; joined paths read their stored epoch"
  else bad "status: the no-join / stored-epoch reading is wrong: $OUT"; fi
  OUT="$o_b"
  if has "UNFINISHED nojoin.md --" && has "WAITING   gone.md -- absent or empty"; then
    ok "status: CONTROL — with --since the same unjoined path is read, so 'no join armed' above was the missing epoch"
  else bad "status: CONTROL FAILED — --since did not give the unjoined path an epoch: $OUT"; fi
  # THE CONTROL that the stale bound was a live hazard: a real beat over the same tree wipes it.
  cbeat "$SUBJ" "$W" nojoin.md
  if [ "$(cat "$CD/.bound" 2>/dev/null)" = 1 ] && [ ! -e "$CD/$(fx_key u.md).since" ]; then
    ok "status: CONTROL — a real beat over the same tree rewrites the stale .bound and wipes the counters --status left alone"
  else bad "status: CONTROL FAILED — a beat did not wipe on the stale bound, so its survival above proves nothing: $OUT"; fi

  # NO STATE DIR: --status in a tree with none must not create it.
  W2="$(mktemp -d)" || broken "mktemp failed"
  printf 'x\n' > "$W2/f.md"
  scall "$SUBJ" "$W2" --since "$SI" f.md
  if has "DELIVERED f.md" && [ ! -e "$W2/_bmad-output" ]; then ok "status: in a tree with no _bmad-output, --status answers and does not create it"
  else bad "status: --status created _bmad-output or did not answer: $OUT"; fi
  # `--progress-path .` names an ancestor of the state dir, so the subject refuses it (exit 64)
  # AFTER its mkdir and before any sleep: the control costs no beat.
  ( cd "$W2" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      bash "$SUBJ" --progress-path . f.md ) > "$BEATOUT" 2>&1
  if [ -d "$W2/_bmad-output" ]; then ok "status: CONTROL — the same tree without --status DOES get _bmad-output created"
  else bad "status: CONTROL FAILED — the subject never creates the state dir here, so its absence above proves nothing: $(cat "$BEATOUT")"; fi
  rm -rf "$W" "$W2"
}

M30_status_creates_state_dir() {
  mutant status-creates-state-dir -e 's@^if \[ "\$STATUS" -eq 0 \]; then   # --status creates nothing@if :; then   # --status creates nothing@' || return
  W2="$(mktemp -d)" || broken "mktemp failed"
  printf 'x\n' > "$W2/f.md"
  scall "$MUT" "$W2" --since "$(( $(date +%s) - 30 ))" f.md
  if [ -d "$W2/_bmad-output" ]; then ok "MUTANT status-creates-state-dir: the guard disabled, --status creates _bmad-output — section 15c catches it"
  else bad "MUTANT status-creates-state-dir: section 15c survives the mkdir guard being disabled: $OUT"; fi
  rm -rf "$W2"
}

M31_status_arms_join() {
  mutant status-arms-join \
    -e 's@^  \[ -n "\$sj_s_" \] || return 1$@  [ -n "$sj_s_" ] || return 1; printf "%s" "$sj_s_" > "$sj_f_" 2>/dev/null@' || return
  W="$(mk_work)"; mkdir -p "$W/_bmad-output/.wait-beats"
  printf 'x\n' > "$W/nojoin.md"
  fx_snap "$W" "$TMPROOT/snap-m1"
  scall "$MUT" "$W" --since "$(( $(date +%s) - 30 ))" nojoin.md
  fx_snap "$W" "$TMPROOT/snap-m2"
  if ! cmp -s "$TMPROOT/snap-m1" "$TMPROOT/snap-m2"; then ok "MUTANT status-arms-join: --status writing a .since changes the tree — section 15c's snapshot catches it"
  else bad "MUTANT status-arms-join: section 15c's snapshot survives --status arming a join"; fi
  rm -rf "$W"
}

M32_status_nojoin_epoch_zero() {
  mutant status-nojoin-epoch-zero -e 's@^  \[ -n "\$sj_s_" \] || return 1$@  [ -n "$sj_s_" ] || sj_s_=0@' || return
  W="$(mk_work)"
  printf 'x\n' > "$W/nojoin.md"
  scall "$MUT" "$W" nojoin.md
  if has "DELIVERED nojoin.md" && ! has "no join armed"; then ok "MUTANT status-nojoin-epoch-zero: an unjoined path given epoch 0 reads DELIVERED — section 15c's 'no join armed' arm catches it"
  else bad "MUTANT status-nojoin-epoch-zero: section 15c survives an unjoined path getting an epoch: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 16. REVISED-AFTER-MARKER: A SEAT THAT EDITS A FILE IT DECLARED FINAL IS NAMED, AT BOTH PLACES
#     A PATH IS DELIVERED.
#     One world, four files, five beats, each beat in its own shell so it sleeps:
#       f1    (i)   seen marked, edited above the marker, delivered at the POST-POLL site
#       f2    (ii)  seen marked, marker withdrawn, restored byte-identical, delivered post-poll
#       still (iii) seen marked, never touched -- no REVISED line
#       f4    (iv)  revised during a beat that times out (.revised left on disk), delivered at
#                   the PRE-SWEEP site of the next beat (a pre-sweep delivery prints no BEAT
#                   COMPLETE line; a post-poll one does -- that is the site discriminator)
#     The world writes its outputs to files so the mutant battery can run four copies at once.
# ===========================================================================
revised_world() {  # $1 = subject, $2 = fresh workdir
  rw_s="$1" rw_w="$2"; rw_si=$(( $(date +%s) - 30 ))
  mkdir -p "$rw_w/_bmad-output"
  for rw_f in f1 f2 f4 still; do printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/$rw_f.md"; done
  obeat "$rw_s" "$rw_w" "$rw_w/o.a1" 2 60 "$rw_si" --complete f1.md f2.md f4.md still.md
  printf '%s\n- an edit above the marker\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/f1.md"
  printf '%s\n- an edit above the marker\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/f4.md"
  printf '%s\n- the marker withdrawn\n' "$SKELETON" > "$rw_w/f2.md"
  obeat "$rw_s" "$rw_w" "$rw_w/o.b2" 3 1  "$rw_si" --complete f1.md still.md
  obeat "$rw_s" "$rw_w" "$rw_w/o.b3" 2 60 "$rw_si" --complete f4.md f2.md
  cat "$rw_w/_bmad-output/.wait-beats/$(fx_key f4.md).revised" > "$rw_w/o.rv4" 2>/dev/null
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/f2.md"
  sleep 2   # f4's settle record must be more than SETTLE=1 whole seconds old at b4's pre-sweep
  obeat "$rw_s" "$rw_w" "$rw_w/o.b4" 3 1  "$rw_si" --complete f4.md
  obeat "$rw_s" "$rw_w" "$rw_w/o.b5" 3 1  "$rw_si" --complete f2.md
}
rw_out() { OUT="$(cat "$1/o.$2" 2>/dev/null)"; }

S16_revised_after_marker() {
  W="$(mktemp -d)" || broken "mktemp failed"
  revised_world "$SUBJ" "$W"
  OUT="$(cat "$W"/o.*)"
  if has "$SIBLING_NOTE"; then bad "revised: a beat ran as a chained sibling — the world is not the one this section names: $OUT"
  else ok "revised: CONTROL — every beat slept in its own shell (no sibling NOTE)"; fi
  rw_out "$W" a1
  if has "WAITING   f1.md" && has "0 delivered, 4 still out" && ! has "DELIVERED f"; then ok "revised: CONTROL — the first beat saw every marked file and delivered none"
  else bad "revised: CONTROL FAILED — the first beat delivered, so no file was seen before its edit: $OUT"; fi
  rw_out "$W" b2
  if has "DELIVERED f1.md" && has "REVISED-AFTER-MARKER 1 f1.md" && has "BEAT COMPLETE"; then
    ok "revised (i): a marked file edited before it settled is DELIVERED then REVISED-AFTER-MARKER 1, at the post-poll site"
  else bad "revised (i): no REVISED-AFTER-MARKER 1 beneath the post-poll DELIVERED: $OUT"; fi
  if has "DELIVERED still.md" && ! has " still.md -- its content changed"; then
    ok "revised (iii): CONTROL — an unrevised sealed file delivers with NO REVISED line"
  else bad "revised (iii): the untouched file was not delivered, or was named revised: $OUT"; fi
  rw_out "$W" b3
  if has "WAITING   f4.md" && has "UNFINISHED f2.md --" && [ "$(cat "$W/o.rv4" 2>/dev/null)" = 1 ]; then
    ok "revised (iv): the beat that saw f4 revised timed out with .revised=1 left on disk; f2's withdrawn marker reads UNFINISHED"
  else bad "revised (iv): the timing-out beat did not leave .revised=1 (got '$(cat "$W/o.rv4" 2>/dev/null)'): $OUT"; fi
  rw_out "$W" b4
  if has "DELIVERED f4.md" && has "REVISED-AFTER-MARKER 1 f4.md" && ! has "BEAT COMPLETE"; then
    ok "revised (iv): the next beat delivers f4 at the PRE-SWEEP site and prints REVISED-AFTER-MARKER 1 there too"
  else bad "revised (iv): no REVISED line at the pre-sweep delivery, or it was not a pre-sweep delivery: $OUT"; fi
  rw_out "$W" b5
  if has "DELIVERED f2.md" && has " f2.md -- its content changed" && ! has "REVISED-AFTER-MARKER 0"; then
    ok "revised (ii): a marker removed then restored byte-identical still prints REVISED-AFTER-MARKER n>=1"
  else bad "revised (ii): a withdrawn-and-restored marker printed no REVISED line: $OUT"; fi
  rm -rf "$W"
}

# FOUR MUTANTS, ONE WORLD EACH, RUN CONCURRENTLY. Each must kill its own arm and leave the arm
# it does not touch standing -- the marker-loss mutant in particular must kill (ii) and NOT (i),
# or the two counting sites are not separately observed.
M33_revised_mutants() {
  rv_lines="$(grep -n '^    say_revised "\$t" "\$c"$' "$SUBJ" | cut -d: -f1)"
  rv_pre="$(printf '%s\n' "$rv_lines" | sed -n 1p)"; rv_post="$(printf '%s\n' "$rv_lines" | sed -n 2p)"
  [ -n "$rv_pre" ] && [ -n "$rv_post" ] && [ -z "$(printf '%s\n' "$rv_lines" | sed -n 3p)" ] \
    || { bad "MUTANT revised-*: expected exactly two say_revised delivery sites, found: $rv_lines"; return; }
  mutant revised-bump-dropped -e 's@^  rb_f_="\${1%\.settle}\.revised"$@  return 0@' || return; M_BUMP="$MUT"
  mutant revised-loss-uncounted -e 's@^    if settle_record "\$id_st_" >/dev/null; then revised_bump "\$id_st_"; fi$@    :@' || return; M_LOSS="$MUT"
  mutant revised-presweep-silent -e "${rv_pre}s@.*@    :@" || return; M_PRE="$MUT"
  mutant revised-postpoll-silent -e "${rv_post}s@.*@    :@" || return; M_POST="$MUT"
  for mn in BUMP LOSS PRE POST; do
    eval "ms=\$M_$mn"
    mkdir -p "$TMPROOT/rv-$mn"; revised_world "$ms" "$TMPROOT/rv-$mn" &
  done
  wait
  r_has() { rw_out "$TMPROOT/rv-$1" "$2"; has "$3"; }
  if ! r_has BUMP b2 "REVISED-AFTER-MARKER 1 f1.md" && ! r_has BUMP b5 " f2.md -- its content changed" && r_has BUMP b2 "DELIVERED f1.md"; then
    ok "MUTANT revised-bump-dropped: no counter, no REVISED line for (i) or (ii) — section 16 catches it"
  else bad "MUTANT revised-bump-dropped: section 16 (i)/(ii) survive the counter being dropped"; fi
  if ! r_has LOSS b5 " f2.md -- its content changed" && r_has LOSS b5 "DELIVERED f2.md" && r_has LOSS b2 "REVISED-AFTER-MARKER 1 f1.md"; then
    ok "MUTANT revised-loss-uncounted: a marker loss not counted kills (ii) and leaves (i) standing — the two counting sites are separately observed"
  else bad "MUTANT revised-loss-uncounted: expected (ii) killed and (i) standing — b2: $(cat "$TMPROOT/rv-LOSS/o.b2") b5: $(cat "$TMPROOT/rv-LOSS/o.b5")"; fi
  if ! r_has PRE b4 "REVISED-AFTER-MARKER 1 f4.md" && r_has PRE b4 "DELIVERED f4.md" && r_has PRE b2 "REVISED-AFTER-MARKER 1 f1.md"; then
    ok "MUTANT revised-presweep-silent: the pre-sweep site printing no REVISED line kills (iv) and leaves (i) — section 16 catches it"
  else bad "MUTANT revised-presweep-silent: expected (iv) killed and (i) standing — b2: $(cat "$TMPROOT/rv-PRE/o.b2") b4: $(cat "$TMPROOT/rv-PRE/o.b4")"; fi
  if ! r_has POST b2 "REVISED-AFTER-MARKER 1 f1.md" && r_has POST b2 "DELIVERED f1.md" && r_has POST b4 "REVISED-AFTER-MARKER 1 f4.md"; then
    ok "MUTANT revised-postpoll-silent: the post-poll site printing no REVISED line kills (i) and leaves (iv) — section 16 catches it"
  else bad "MUTANT revised-postpoll-silent: expected (i) killed and (iv) standing — b2: $(cat "$TMPROOT/rv-POST/o.b2") b4: $(cat "$TMPROOT/rv-POST/o.b4")"; fi
  rm -rf "$TMPROOT"/rv-*
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs a case function name; '$FN' is not one" >&2; exit 2; }
  "$FN"
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

echo "wait-beat-liveness:"

probe

# THE CASE LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order, with a
# zero guard. A hand-written list is the defect the subject itself is about: a case
# dropped from it runs nothing, prints nothing, and N-1 greens read exactly like N.
NAMES="$(grep -oE '^(S[0-9]+[a-z]?|M[0-9]+)_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 15 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED case(s) from this file — the naming grammar moved" >&2
  exit 2
fi

for n in $NAMES; do "$n"; done

if [ "$fails" -eq 0 ]; then
  echo "wait-beat-liveness: PASS"
  exit 0
fi
echo "wait-beat-liveness: ${fails} assertion(s) FAILED" >&2
exit 1
