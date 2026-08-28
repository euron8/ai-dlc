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
