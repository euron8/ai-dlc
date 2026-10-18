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
# --shard-header's checker is the subject's SIBLING in both layouts, so it is found beside the
# resolved subject -- the same directory, no walk (I33).
MERGE="$(dirname "$SUBJ")/merge-adversarial-shards.sh"
[ -f "$MERGE" ] || { echo "FIXTURE ERROR: merge-adversarial-shards.sh is not beside $SUBJ" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/merge-adversarial-shards.sh"
# --dispatch reads its id prefixes from this sibling's DISPATCH_ID_PREFIXES (sections 18-19).
GRAMMAR="$(dirname "$SUBJ")/validate-adversarial-convergence.sh"
[ -f "$GRAMMAR" ] || { echo "FIXTURE ERROR: validate-adversarial-convergence.sh is not beside $SUBJ" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh"

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
HDR_REFUSE='-- ends in seat-complete: but the merge would refuse it: '
NOMARK_LINE='-- present, last non-blank line is not seat-complete:'

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
#
# THE LINES ARE THE HARNESS'S OWN SHAPE, NOT `{"t":1}`. The sensor reads a turn from the newest
# timestamp on an assistant or user line, so a seed with no such line exercises only its mtime
# fallback. Each transcript carries a user line, an answered `{"type":"api-request"` line and an
# assistant line, every timestamp `$2` seconds old, and the file's mtime agrees. The fallback has
# its own seed (mk_transcript_bare) and its own arm in section 23.
mk_transcript() {  # $1 = dir, $2 = age seconds, $3 = basename
  mkdir -p "$1" || broken "cannot create $1"
  mt_ts_="$(fx_iso $(( $(date +%s) - $2 )))"; [ -n "$mt_ts_" ] || broken "neither BSD nor GNU date can format an epoch"
  { printf '{"parentUuid":null,"isSidechain":true,"agentId":"a1","type":"user","message":{"role":"user","content":[{"type":"text","text":"brief"}]},"timestamp":"%s.100Z"}\n' "$mt_ts_"
    printf '{"type":"api-request","sessionId":"s","agentId":"a1","id":"r1","timestamp":"%s.200Z","shapeHash":"7d7e1ada"}\n' "$mt_ts_"
    printf '{"parentUuid":"u1","isSidechain":true,"agentId":"a1","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]},"type":"assistant","timestamp":"%s.300Z"}\n' "$mt_ts_"
  } > "$1/$3" || broken "cannot write $1/$3"
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
        AI_DLC_PROJECT_ROOT="$PWD" bash "$b_subj" "$@" deliv.md ) > "$BEATOUT" 2>&1
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
             AI_DLC_PROJECT_ROOT="$PWD" bash "$s" "$@"
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

  # The --shard-header line and the marker-missing line are each other's near-miss: both open
  # `UNFINISHED <path> -- `, and a detector keyed on that prefix scores either as the other.
  OUT="x UNFINISHED s.md -- ends in seat-complete: but the merge would refuse it: why y"
  if has "$HDR_REFUSE" && ! has "$NOMARK_LINE"; then ok "probe: the header-refusal detector reports a seeded offender, and the marker-missing detector does not"
  else bad "probe: the header-refusal detector cannot spell its subject, or the marker-missing one fires on it"; fi
  OUT="x UNFINISHED s.md -- present, last non-blank line is not seat-complete: y"
  if has "$NOMARK_LINE" && ! has "$HDR_REFUSE"; then ok "probe: the header-refusal detector stays quiet on the marker-missing near-miss, which its own detector reports"
  else bad "probe: the header-refusal detector fires on the marker-missing line, or that line's detector is blind"; fi

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
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if has "$IDLE_BANNER"; then ok "auto-resolve: the sensor finds THIS session's subagents dir from CLAUDE_CODE_SESSION_ID alone, past a project holding a live decoy session"
  else bad "auto-resolve: no banner with only the session id set — the shipped resolution path does not work, and every other section here drives an override that hides that: $OUT"; fi

  # THE CONTROL. Same HOME, same tree, a session id that names nothing. It must fall
  # to NO SIGNAL, not to the first directory it can reach.
  ( cd "$W" && env HOME="$H" CLAUDE_CODE_SESSION_ID="99999999-0000-0000-0000-000000000000" \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_IDLE_SECS=60 \
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1
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
    AI_DLC_PROJECT_ROOT="$PWD" bash "$MUT" deliv.md ) > "$BEATOUT" 2>&1
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
        AI_DLC_PROJECT_ROOT="$PWD" bash "$cb_subj" --since "$CBEAT_SINCE" "$@" ) > "$BEATOUT" 2>&1
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
      AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --complete old.md ) > "$BEATOUT" 2>&1; RC=$?; OUT="$(cat "$BEATOUT")"; }
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
        AI_DLC_PROJECT_ROOT="$PWD" bash "$s" --since "$(( $(date +%s) - 30 ))" --complete slow.md ) > "$BEATOUT.$(basename "$s")" 2>&1 &
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
        && { AI_DLC_PROJECT_ROOT="$PWD" bash "$s" x.md y.md; AI_DLC_PROJECT_ROOT="$PWD" bash "$s" x.md y.md; } ) > "$d.raw" 2>&1
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
        AI_DLC_PROJECT_ROOT="$PWD" bash "$sc_subj" --status "$@" ) > "$BEATOUT" 2>&1
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
    AI_DLC_PROJECT_ROOT="$PWD" bash -c '"$@"; exit $?' _ bash "$ob_subj" --since "$ob_si" "$@" ) > "$ob_o" 2>&1
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
    -e 's@^status_marked() { has_marker "\$1"; }$@status_marked() { grep -q '\''^seat-complete'\'' <<<"$(tail -1 "$1")"; }@' || return
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

# A beat that DELIVERS drops the path's join state, so --status taken AFTER the consuming beat once
# read every consumed seat as unarmed (WAITING) or, given --since, UNSETTLED: the s319 undercount
# by another route. The beat now keeps the consumed hash; --status reads it while the file is
# unchanged, judges a changed file afresh, and a --reset clears it.
status_after_delivery() {  # $1 = subject -> sets SAD_* from one world
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/done.md"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/later.md"
  obeat "$1" "$W" "$BEATOUT" 3 1 "$SI" --complete done.md later.md; SAD_BEAT="$(cat "$BEATOUT")"
  CB_SETTLE=60 scall "$1" "$W" --complete done.md; SAD_PLAIN="$OUT"
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$SI" done.md; SAD_SINCE="$OUT"
  printf '%s\n- edited after consumption\n%s\n' "$SKELETON" "$MARKER" > "$W/later.md"
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$SI" later.md; SAD_CHANGED="$OUT"
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash -c '"$@"; exit $?' _ bash "$1" --reset --complete done.md ) >/dev/null 2>&1
  CB_SETTLE=60 scall "$1" "$W" --complete done.md; SAD_RESET="$OUT"
  rm -rf "$W"
}
S15d_status_after_delivery() {
  status_after_delivery "$SUBJ"
  case "$SAD_BEAT" in *"DELIVERED done.md"*"DELIVERED later.md"*|*"DELIVERED later.md"*"DELIVERED done.md"*)
    ok "status-after-delivery: CONTROL — the consuming beat delivered both seats" ;;
    *) bad "status-after-delivery: the consuming beat did not deliver both, so nothing below was consumed: $SAD_BEAT" ;; esac
  case "$SAD_PLAIN$SAD_SINCE" in *"DELIVERED done.md"*"DELIVERED done.md"*)
    ok "status-after-delivery: a seat a beat consumed reads DELIVERED, with and without --since" ;;
    *) bad "status-after-delivery: a consumed seat was not DELIVERED (plain: $SAD_PLAIN | since: $SAD_SINCE)" ;; esac
  case "$SAD_CHANGED" in *"DELIVERED later.md"*) bad "status-after-delivery: a seat edited after consumption still read DELIVERED: $SAD_CHANGED" ;;
    *"UNSETTLED later.md"*) ok "status-after-delivery: a seat edited after consumption is judged afresh (UNSETTLED), not DELIVERED" ;;
    *) bad "status-after-delivery: an edited consumed seat read neither: $SAD_CHANGED" ;; esac
  case "$SAD_RESET" in *"DELIVERED done.md"*) bad "status-after-delivery: --reset left the consumed record behind: $SAD_RESET" ;;
    *"WAITING   done.md"*) ok "status-after-delivery: --reset clears the consumed record" ;;
    *) bad "status-after-delivery: after --reset the seat read neither: $SAD_RESET" ;; esac
}
M34_status_no_delivered_record() {
  mutant status-no-delivered-record -e 's@^    record_delivered "\$t" "\$c"$@    :@' || return
  status_after_delivery "$MUT"
  case "$SAD_PLAIN$SAD_SINCE" in *"DELIVERED done.md"*) bad "MUTANT status-no-delivered-record: a consumed seat still read DELIVERED without the record — something else carries it" ;;
    *) ok "MUTANT status-no-delivered-record: without the record a consumed seat reads unarmed or UNSETTLED — section 15d catches it" ;; esac
}

# The REVISED-AFTER-MARKER count must outlive DELIVERED: a beat's printed line is read once and
# gone, so `<key>.revised` is the record a repair brief reads. Only --reset (or a new round) clears it.
revised_survives() {  # $1 = subject -> RS_BEAT, RS_AFTER, RS_RESET
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/rv.md"
  ( sleep 1.5; printf '%s\n- an edit above the marker\n%s\n' "$SKELETON" "$MARKER" > "$W/rv.md" ) & rs_w_=$!
  obeat "$1" "$W" "$BEATOUT" 8 2 "$SI" --quiet --complete rv.md; wait "$rs_w_"
  RS_BEAT="$(cat "$BEATOUT")"
  RS_AFTER="$(cat "$W/_bmad-output/.wait-beats/$(fx_key rv.md).revised" 2>/dev/null || echo ABSENT)"
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash -c '"$@"; exit $?' _ bash "$1" --reset --complete rv.md ) >/dev/null 2>&1
  RS_RESET="$( [ -e "$W/_bmad-output/.wait-beats/$(fx_key rv.md).revised" ] && echo PRESENT || echo ABSENT )"
  rm -rf "$W"
}
S16b_revised_survives_delivery() {
  revised_survives "$SUBJ"
  # The REVISED line is echoed, not `say`d, so --quiet cannot hide it -- and a beat's stdout is
  # still read once and gone, which is why the sidecar must outlive delivery as the record.
  case "$RS_BEAT" in *"REVISED-AFTER-MARKER 1 rv.md"*)
    ok "revised-survives: CONTROL — the beat saw rv.md revised and reported it, even under --quiet" ;;
    *) bad "revised-survives: CONTROL FAILED — the beat did not report rv.md revised, so there is no count to keep: '$RS_BEAT'" ;; esac
  case "$RS_AFTER" in ''|*[!0-9]*) bad "revised-survives: after DELIVERED .revised is '$RS_AFTER', not a count" ;;
    *) if [ "$RS_AFTER" -ge 1 ]; then ok "revised-survives: after DELIVERED .revised still holds $RS_AFTER"
       else bad "revised-survives: after DELIVERED .revised holds 0"; fi ;; esac
  if [ "$RS_RESET" = ABSENT ]; then ok "revised-survives: --reset clears .revised"
  else bad "revised-survives: .revised survived --reset"; fi
}
M35_revised_deleted_on_delivery() {
  mutant revised-deleted-on-delivery \
    -e 's@^    rm -f "\$c" "\$s" "\$pg" "\$gr" "\${c}\.settle" 2>/dev/null || true$@    rm -f "$c" "$s" "$pg" "$gr" "${c}.settle" "${c}.revised" 2>/dev/null || true@' \
    -e 's@^    rm -f "\$c" "\$s" "\${c}\.progress" "\${c}\.grants" "\${c}\.settle" 2>/dev/null || true$@    rm -f "$c" "$s" "${c}.progress" "${c}.grants" "${c}.settle" "${c}.revised" 2>/dev/null || true@' || return
  revised_survives "$MUT"
  if [ "$RS_AFTER" = ABSENT ]; then ok "MUTANT revised-deleted-on-delivery: DELIVERED takes the count with it — section 16b catches it"
  else bad "MUTANT revised-deleted-on-delivery: .revised ('$RS_AFTER') survived the restored rm — something else rewrites it"; fi
}

# --status SURFACES the persisted count, so a repair brief never computes a cksum key by hand; and
# the count is ROUND-SCOPED: a later round re-arms with `--since <round epoch>` (never --reset), so
# a reused seat path must not inherit the earlier round's revision -- not in --status, not on disk.
revised_rounds() {  # $1 = subject -> RR_* from one world
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/rv.md"
  ( sleep 1.5; printf '%s\n- an edit above the marker\n%s\n' "$SKELETON" "$MARKER" > "$W/rv.md" ) & rr_w_=$!
  obeat "$1" "$W" "$BEATOUT" 8 2 "$SI" --complete rv.md; wait "$rr_w_"
  RR_BEAT="$(cat "$BEATOUT")"
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$SI" rv.md; RR_STATUS1="$OUT"
  sleep 1; R2=$(( $(date +%s) + 1 )); sleep 1
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$R2" rv.md; RR_STATUS2="$OUT"
  obeat "$1" "$W" "$BEATOUT" 1 2 "$R2" --complete rv.md
  RR_DISK="$( [ -e "$W/_bmad-output/.wait-beats/$(fx_key rv.md).revised" ] && echo PRESENT || echo ABSENT )"
  rm -rf "$W"
}
S16c_revised_status_and_rounds() {
  revised_rounds "$SUBJ"
  case "$RR_BEAT" in *"REVISED-AFTER-MARKER 1 rv.md"*) ok "revised-rounds: CONTROL — round one delivered rv.md revised once" ;;
    *) bad "revised-rounds: round one did not report rv.md revised, so nothing below has a count to read: $RR_BEAT" ;; esac
  case "$RR_STATUS1" in *"REVISED-AFTER-MARKER 1 rv.md"*) ok "revised-rounds: --status in the same round prints the persisted count" ;;
    *) bad "revised-rounds: --status did not surface the count — a brief would hand-compute the sidecar key: $RR_STATUS1" ;; esac
  case "$RR_STATUS2" in *"REVISED-AFTER-MARKER"*) bad "revised-rounds: --status for a LATER round still printed round one's count: $RR_STATUS2" ;;
    *) ok "revised-rounds: --status for a later round withholds the earlier round's count" ;; esac
  if [ "$RR_DISK" = ABSENT ]; then ok "revised-rounds: a beat armed for the later round drops round one's .revised"
  else bad "revised-rounds: round one's .revised survived a beat armed with a later --since — it leaks into the next round"; fi
}
M36_revised_rounds_mutants() {
  mutant revised-status-silent -e 's@^      say_revised "\$t" "\$sd_c"$@      :@' || return; M_RS="$MUT"
  mutant revised-round-kept -e 's@^    \[ -f "\$rr_" \] && \[ "\$(mtime_of "\$rr_")" -lt "\$j" \] && rm -f "\$rr_" 2>/dev/null$@    :@' || return; M_RK="$MUT"
  revised_rounds "$M_RS"
  case "$RR_STATUS1" in *"REVISED-AFTER-MARKER"*) bad "MUTANT revised-status-silent: --status still printed the count — something else carries it" ;;
    *) ok "MUTANT revised-status-silent: --status no longer surfaces the count — section 16c catches it" ;; esac
  revised_rounds "$M_RK"
  if [ "$RR_DISK" = PRESENT ]; then ok "MUTANT revised-round-kept: round one's .revised leaks past a later --since — section 16c catches it"
  else bad "MUTANT revised-round-kept: .revised was dropped without the round clear — something else removes it"; fi
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
      AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --progress-path . f.md ) > "$BEATOUT" 2>&1
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

# ===========================================================================
# 17. --shard-header: A MARKED ADVERSARIAL SHARD IS DELIVERED ONLY IF THE MERGE WOULD TAKE ITS HEADER.
#     The motivating case is a shard that ends in `seat-complete:` and carries no `verdict:` -- it
#     read DELIVERED and surfaced only at the merge, after its adversary had exited. Every arm
#     reads the expected refusal FROM THE MERGE ITSELF (--check-header, run here from the same
#     cwd so the path in its text is the beat's), asserts the merge discriminates the pair first
#     (exit 1 for the failing shard, 0 for its control), then demands that exact text in the beat.
#     The shards are built here, minimally, not with adversarial-shard-merge/lib.sh: that lib
#     resolves the merge by walking up and requires the write-ledger hook and jq, none of which
#     --check-header reads. Each is the reference shard grammar (lib.sh `shard()`): a provenance
#     block, zero findings, and a `seat-complete: ... findings=0` marker, so the valid one passes
#     the marker-count check. Written via temp + mv, so a concurrent read never sees half a file.
# ===========================================================================
mk_shard() {  # $1 = file, $2 = skill, $3 = verdict ('' = no verdict line), $4 = field to drop, $5 = body line
  ms_t="$1.tmp"
  {
    printf '# requirements -- adversarial shard\n\n## Findings\n\n## Probed and found sound\n\n- %s\n\n' "${5:-nothing further}"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: %s\ninvoked_at: 2026-10-01T10:00:00Z\ntool_use_id: NOT_ACCESSIBLE\nmode: subagent\n' "$2"
    [ "$4" = lead_role ] || printf 'lead_role: .claude/skills/ai-dlc/steps/requirements.md\n'
    printf 'artifact: _bmad-output/planning-artifacts/s1/requirements.md\n'
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\n'
    if [ -n "$3" ]; then printf 'verdict: %s\n' "$3"; fi
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n\nseat-complete: requirements p1 1 findings=0\n'
  } > "$ms_t" && mv -f "$ms_t" "$1" || broken "cannot write shard $1"
}
hdr_msg() {  # $1 = workdir, $2 = shard (relative), $3 = axis -> HM (the merge's text, no `REFUSED: `), HRC
  HM="$( cd "$1" && bash "$MERGE" --check-header "$2" --axis "$3" 2>&1 )"; HRC=$?
  HM="${HM#REFUSED: }"
}
hdr_line() {  # $1 = shard, $2 = refusal text: is the beat's exact UNFINISHED line in BEATOUT?
  grep -qxF "UNFINISHED $1 ${HDR_REFUSE}$2" "$BEATOUT"
}
CV=ai-dlc-adversary-review
EL=bmad-advanced-elicitation

S17a_shard_header_convergence() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  mk_shard "$W/s-ok.md"   "$CV" EXIT_CONDITION_MET ""
  mk_shard "$W/s-nov.md"  "$CV" ""                 ""
  mk_shard "$W/s-pend.md" "$CV" PENDING-LEAD       ""
  mk_shard "$W/s-nolr.md" "$CV" EXIT_CONDITION_MET lead_role
  hdr_msg "$W" s-ok.md convergence;   c_ok=$HRC
  hdr_msg "$W" s-nov.md convergence;  c_nov=$HRC;  m_nov="$HM"
  hdr_msg "$W" s-pend.md convergence; c_pend=$HRC; m_pend="$HM"
  hdr_msg "$W" s-nolr.md convergence; c_nolr=$HRC; m_nolr="$HM"
  if [ "$c_ok" -eq 0 ] && [ "$c_nov" -eq 1 ] && [ "$c_pend" -eq 1 ] && [ "$c_nolr" -eq 1 ]; then
    ok "shard-header: CONTROL — the merge itself passes the MET shard and refuses no-verdict, PENDING-LEAD and no-lead_role"
  else bad "shard-header: CONTROL FAILED — the merge does not discriminate the seeds (ok=$c_ok nov=$c_nov pend=$c_pend nolr=$c_nolr), so the beat arms below mean nothing"; fi

  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete --shard-header convergence s-ok.md s-nov.md s-pend.md s-nolr.md
  if has "DELIVERED s-ok.md" && [ "$RC" -eq 0 ]; then ok "shard-header: CONTROL — the same shard WITH verdict: EXIT_CONDITION_MET is DELIVERED (rc 0)"
  else bad "shard-header: CONTROL FAILED — a valid marked shard was not delivered under --shard-header (rc=$RC): $OUT"; fi
  if hdr_line s-nov.md "$m_nov" && ! has "DELIVERED s-nov.md"; then
    ok "shard-header (1): a marked shard with no verdict: is UNFINISHED, carrying the merge's own refusal text"
  else bad "shard-header (1): a marked no-verdict shard was not UNFINISHED with the merge's text '$m_nov': $OUT"; fi
  if hdr_line s-pend.md "$m_pend" && ! has "DELIVERED s-pend.md"; then ok "shard-header (2): verdict: PENDING-LEAD is UNFINISHED"
  else bad "shard-header (2): a PENDING-LEAD shard was not UNFINISHED with '$m_pend': $OUT"; fi
  if hdr_line s-nolr.md "$m_nolr" && ! has "DELIVERED s-nolr.md"; then ok "shard-header (3): a marked shard missing lead_role is UNFINISHED"
  else bad "shard-header (3): a no-lead_role shard was not UNFINISHED with '$m_nolr': $OUT"; fi

  # --status is the beat's verdict without the beat, so it must say the same.
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --shard-header convergence --since "$CBEAT_SINCE" s-nov.md
  if hdr_line s-nov.md "$m_nov"; then ok "shard-header: --status reports the same UNFINISHED line as the beat"
  else bad "shard-header: --status disagrees with the beat on a header-failing shard: $OUT"; fi
  rm -rf "$W"
}

S17b_shard_header_elicitation() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  # One property apart: both declare the elicitation skill; only the verdict: line differs.
  mk_shard "$W/e-nov.md" "$EL" ""                 ""
  mk_shard "$W/e-v.md"   "$EL" EXIT_CONDITION_MET ""
  hdr_msg "$W" e-nov.md elicitation; c_nov=$HRC
  hdr_msg "$W" e-v.md elicitation;   c_v=$HRC; m_v="$HM"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete --shard-header elicitation e-nov.md e-v.md
  if [ "$c_nov" -eq 0 ] && [ "$c_v" -eq 1 ] && has "DELIVERED e-nov.md"; then
    ok "shard-header (4): on the elicitation axis a shard with NO verdict is DELIVERED"
  else bad "shard-header (4): an elicitation shard without verdict was not delivered (merge nov=$c_nov v=$c_v): $OUT"; fi
  if hdr_line e-v.md "$m_v" && ! has "DELIVERED e-v.md"; then ok "shard-header (4): on the elicitation axis a shard WITH a verdict is UNFINISHED"
  else bad "shard-header (4): an elicitation shard carrying a verdict was not UNFINISHED with '$m_v': $OUT"; fi
  rm -rf "$W"
}

S17c_shard_header_absent_changes_nothing() {
  # A headerless marked shard WITHOUT the flag delivers exactly as a valid one does: the two worlds
  # print the same output (timing words masked). WITH the flag the headerless one is UNFINISHED, so
  # the comparison is shown able to differ. Byte identity against the pre-flag script is the
  # build's probe; this arm holds the no-flag path blind to the header.
  WA="$(mk_work)"; WB="$(mk_work)"; WC="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '# requirements -- adversarial shard\n\n## Findings\n\nseat-complete: requirements p1 1 findings=0\n' > "$WA/h.md"
  cp "$WA/h.md" "$WC/h.md"
  mk_shard "$WB/h.md" "$CV" EXIT_CONDITION_MET ""
  hdr_msg "$WA" h.md convergence; c_h=$HRC; m_h="$HM"
  CB_BEAT=3 cbeat "$SUBJ" "$WA" --complete h.md; oa="$(sed -E 's/[0-9]+[smhd] (old|since|ago)/N \1/g' "$BEATOUT")"
  CB_BEAT=3 cbeat "$SUBJ" "$WB" --complete h.md; ob="$(sed -E 's/[0-9]+[smhd] (old|since|ago)/N \1/g' "$BEATOUT")"
  OUT="$oa"
  if [ "$c_h" -eq 1 ] && has "DELIVERED h.md" && [ "$oa" = "$ob" ]; then
    ok "shard-header (5): without the flag a headerless marked shard is DELIVERED, output identical to a valid shard's"
  else bad "shard-header (5): without the flag the header changed the outcome (merge rc=$c_h): [$oa] vs [$ob]"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$WC" --complete --shard-header convergence h.md
  if hdr_line h.md "$m_h" && ! has "DELIVERED h.md"; then ok "shard-header (5): CONTROL — the same headerless shard WITH the flag is UNFINISHED"
  else bad "shard-header (5): CONTROL FAILED — the flag did not change the headerless outcome, so the identity above proves nothing: $OUT"; fi
  rm -rf "$WA" "$WB" "$WC"
}

# Both shards rewritten together every 0.3s until the sentinel exists, each revision distinct
# bytes outside ## Findings; stopped by churn_stop (shared with section 13c), never killed.
shard_churn() {  # $1 = workdir
  CHURN_STOP="$1/churn.stop"; rm -f "$CHURN_STOP"
  ( i=0; end=$(( $(date +%s) + 60 ))
    while [ ! -e "$CHURN_STOP" ] && [ "$(date +%s)" -lt "$end" ]; do
      i=$((i + 1))
      mk_shard "$1/c-bad.md" "$CV" ""                 "" "revision $i"
      mk_shard "$1/c-ok.md"  "$CV" EXIT_CONDITION_MET "" "revision $i"
      sleep 0.3
    done ) &
  CHURN_PID=$!
}

S17d_shard_header_unfinished_not_unsettled() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  mk_shard "$W/c-bad.md" "$CV" ""                 ""
  mk_shard "$W/c-ok.md"  "$CV" EXIT_CONDITION_MET ""
  shard_churn "$W"
  cbeat "$SUBJ" "$W" --complete --shard-header convergence c-bad.md c-ok.md; o1="$OUT"   # charges the beat
  cbeat "$SUBJ" "$W" --complete --shard-header convergence c-bad.md c-ok.md               # own-progress grant
  cbeat "$SUBJ" "$W" --complete --shard-header convergence c-bad.md c-ok.md; o3="$OUT"; r3=$RC   # spent
  churn_stop
  OUT="$o1"
  if has "UNFINISHED c-bad.md $HDR_REFUSE"; then ok "shard-header (6): a changing header-failing shard is UNFINISHED beneath its WAITING line"
  else bad "shard-header (6): the WAITING beat did not name the changing header-failing shard UNFINISHED: $OUT"; fi
  OUT="$o3"
  if has "UNSETTLED c-ok.md" && [ "$r3" -eq 1 ]; then ok "shard-header (6): CONTROL — the valid shard churning beside it IS UNSETTLED on exhaustion (rc 1)"
  else bad "shard-header (6): CONTROL FAILED — the churning valid shard was not UNSETTLED (rc=$r3), so the exhaustion path was not reached: $OUT"; fi
  if has "NON-DELIVERY c-bad.md -- after" && has "UNFINISHED c-bad.md $HDR_REFUSE" && ! has "UNSETTLED c-bad.md" \
     && ! has "NON-DELIVERY c-bad.md -- absent"; then
    ok "shard-header (6): on exhaustion a changing header-failing shard is UNFINISHED, never UNSETTLED or absent"
  else bad "shard-header (6): an exhausted changing header-failing shard was not routed to UNFINISHED: $OUT"; fi
  rm -rf "$W"
}

S17e_shard_header_refusals() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  cbeat "$SUBJ" "$W" --shard-header convergence x.md
  if [ "$RC" -eq 64 ] && has "valid only with --complete"; then ok "shard-header (7): --shard-header without --complete is refused (exit 64)"
  else bad "shard-header (7): --shard-header without --complete was accepted (rc=$RC): $OUT"; fi
  cbeat "$SUBJ" "$W" --complete-repair --shard-header convergence x.md
  if [ "$RC" -eq 64 ] && has "valid only with --complete"; then ok "shard-header (7): --shard-header with --complete-repair is refused (exit 64)"
  else bad "shard-header (7): --shard-header with --complete-repair was accepted (rc=$RC): $OUT"; fi
  cbeat "$SUBJ" "$W" --complete --shard-header bogus x.md
  if [ "$RC" -eq 64 ] && has "takes convergence or elicitation"; then ok "shard-header (7): an axis other than convergence or elicitation is refused (exit 64)"
  else bad "shard-header (7): an unknown axis was accepted (rc=$RC): $OUT"; fi
  # THE MISSING SIBLING IS REFUSED AT ARMING, never an acquittal. Control: the same lone copy
  # without the flag runs a beat, so the refusal is the flag's and not a broken copy.
  LONE="$TMPROOT/lone"; mkdir -p "$LONE"; cp "$SUBJ" "$LONE/wait-for-deliverable.sh" || broken "cannot copy the subject"
  [ ! -e "$LONE/merge-adversarial-shards.sh" ] || broken "the lone copy has a merge beside it"
  cbeat "$LONE/wait-for-deliverable.sh" "$W" --complete --shard-header convergence x.md
  if [ "$RC" -eq 64 ] && has "needs merge-adversarial-shards.sh beside this script"; then
    ok "shard-header: a subject with no merge beside it refuses --shard-header at arming (exit 64)"
  else bad "shard-header: a missing sibling merge did not refuse at arming (rc=$RC): $OUT"; fi
  cbeat "$LONE/wait-for-deliverable.sh" "$W" --complete x.md
  if [ "$RC" -eq 0 ] && has "WAITING   x.md"; then ok "shard-header: CONTROL — the same lone copy without the flag runs a beat"
  else bad "shard-header: CONTROL FAILED — the lone copy does not run at all (rc=$RC): $OUT"; fi
  rm -rf "$W" "$LONE"
}

M37_shard_check_exit_ignored() {
  mutant shard-check-exit-ignored \
    -e 's@^  if \[ -n "\$SHARD_AXIS" \] && header_refused "\$1"; then return 1; fi$@  if [ -n "$SHARD_AXIS" ]; then header_refused "$1"; fi@' || return
  cp "$MERGE" "$MUTDIR/merge-adversarial-shards.sh" || broken "cannot copy the merge beside the mutant"
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  mk_shard "$W/s-nov.md" "$CV" ""                 ""
  mk_shard "$W/s-ok.md"  "$CV" EXIT_CONDITION_MET ""
  CB_BEAT=3 cbeat "$MUT" "$W" --complete --shard-header convergence s-nov.md s-ok.md
  if has "DELIVERED s-nov.md" && has "DELIVERED s-ok.md"; then
    ok "MUTANT shard-check-exit-ignored: a join ignoring the check's exit delivers the no-verdict shard — section 17a (1) catches it"
  else bad "MUTANT shard-check-exit-ignored: section 17a (1) survives the check's exit being ignored (or the mutant never ran): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 18. --dispatch MUST NOT SWITCH GLOBBING OFF FOR THE REST OF THE BEAT.
#     The id split runs under `set -f`. Left on, every later glob in the subject iterates once
#     over its own literal pattern: the teammate scan reads `unavailable` on a session with a
#     fresh transcript, and the EXIT trap's heir scan finds no heir, so a holder that exits
#     deletes the marker under a sibling still asleep. Measured on the reference consumer: a
#     lead whose every join was armed with --dispatch read `LIVENESS  unavailable` 7 times and
#     `took a turn` 0 times. Each arm below has its no-dispatch twin in this file (section 2;
#     the heir arm's control is B's own pre-exit marker), and section 18c deletes the restore.
# ===========================================================================
fx_iso() {  # $1 = epoch -> ISO8601 UTC, BSD then GNU
  date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}
mk_ledger_row() {  # $1 = workdir, $2 = tool_use_id, $3 = epoch -- appends one spawn-ledger row
  le_ts="$(fx_iso "$3")"; [ -n "$le_ts" ] || broken "neither BSD nor GNU date can format an epoch"
  printf '{"v":1,"ts":"%s","name":"wbl","role":"dev","tool_use_id":"%s"}\n' "$le_ts" "$2" \
    >> "$1/_bmad-output/spawn-ledger.jsonl" || broken "cannot write the spawn ledger"
}
# Every subject this section drives sits in a directory with its siblings, because --dispatch
# reads its id grammar from the one beside it; a lone copy would refuse for that, not for the
# behaviour under test.
sib_dir() {  # $1 = subject copy -> prints a fresh dir holding it as wait-for-deliverable.sh
  sd_="$(mktemp -d "$TMPROOT/sib.XXXXXX")" || broken "mktemp failed"
  cp "$1" "$sd_/wait-for-deliverable.sh" || broken "cannot copy the subject"
  cp "$MERGE" "$GRAMMAR" "$sd_/" || broken "cannot copy the subject's siblings beside it"
  printf '%s' "$sd_"
}

dispatch_live_world() {  # $1 = subject; sets OUT/RC -- a --dispatch beat over a fresh transcript
  W="$(mk_work)"; TD="$TMPROOT/s18-td.$$.$RANDOM"; mk_transcript "$TD" 0 agent-aone-1.jsonl
  mk_ledger_row "$W" toolu_wbl661 $(( $(date +%s) - 30 ))
  beat "$1" "$W" 3600 "$TD" --dispatch toolu_wbl661
}
S18a_dispatch_keeps_liveness() {
  dispatch_live_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if [ "$RC" -eq 0 ] && has "WAITING   deliv.md"; then ok "dispatch-glob: CONTROL — the --dispatch beat resolved its ledger row and ran a beat"
  else bad "dispatch-glob: CONTROL FAILED — the --dispatch beat did not run (rc=$RC), so the line below proves nothing: $OUT"; fi
  if has "$LIVE_LINE" && ! has "$UNAVAIL_LINE"; then ok "dispatch-glob: a --dispatch beat over a fresh transcript reports the teammate's turn"
  else bad "dispatch-glob: a --dispatch beat read a fresh transcript as no signal — noglob leaked past the id split: $OUT"; fi
  rm -rf "$W"
}

# Beat B (armed --dispatch) holds the marker; a live registered sibling A stands behind it; B's
# target lands and B exits. Its EXIT trap must hand the marker to A. A is a registration the
# fixture plants -- `.lease-<pid>` with an unexpired epoch, naming a `sleep` this fixture started
# -- rather than a second real beat, because a real A re-stamps the marker on its own next poll
# and would mask a holder that dropped it. Every wait below is bounded on PROGRESS and refuses as
# BROKEN (exit 2) on none; nothing FAILs on a clock.
HEIR_A_PID=""; HEIR_B_PID=""; HEIR_AFTER=""
until_ok() {  # $1 = tenths, rest = command -> 0 once it holds, 1 when the bound runs out
  uo_n_="$1"; shift
  while [ "$uo_n_" -gt 0 ]; do "$@" && return 0; sleep 0.1; uo_n_=$(( uo_n_ - 1 )); done
  return 1
}
marker_pid() { mp_=""; IFS= read -r mp_ 2>/dev/null < "$1/_bmad-output/.beat-inflight"; case "$mp_" in *' '*) printf '%s' "${mp_#* }" ;; esac; }
marker_present() { [ -n "$(marker_pid "$1")" ]; }
pid_gone() { ! kill -0 "$1" 2>/dev/null; }
heir_world() {  # $1 = subject (in a sibling dir); leaves W, sets HEIR_*
  W="$(mk_work)"; HEIR_A_PID=""; HEIR_B_PID=""; HEIR_AFTER=""
  mk_ledger_row "$W" toolu_wbl661heir $(( $(date +%s) - 30 ))
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=40 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" --dispatch toolu_wbl661heir b.md ) > "$BEATOUT.B" 2>&1 &
  hw_bg_=$!
  until_ok 300 marker_present "$W" || broken "heir: the --dispatch beat never wrote the marker"
  HEIR_B_PID="$(marker_pid "$W")"
  sleep 120 & HEIR_A_PID=$!
  printf '%s' "$(( $(date +%s) + 300 ))" > "$W/_bmad-output/.wait-beats/.lease-$HEIR_A_PID" || broken "heir: cannot plant A's registration"
  printf 'b\n' > "$W/b.md"
  until_ok 300 pid_gone "$HEIR_B_PID" || broken "heir: the --dispatch beat never exited after its target landed"
  HEIR_AFTER="$(marker_pid "$W")"
  kill "$HEIR_A_PID" 2>/dev/null; wait "$HEIR_A_PID" 2>/dev/null
  wait "$hw_bg_" 2>/dev/null
}
S18b_dispatch_holder_hands_off() {
  heir_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if [ -n "$HEIR_B_PID" ] && [ "$HEIR_B_PID" != "$HEIR_A_PID" ]; then ok "dispatch-heir: CONTROL — the --dispatch beat held the marker while its sibling registered"
  else bad "dispatch-heir: CONTROL FAILED — B ('$HEIR_B_PID') did not hold the marker apart from A ('$HEIR_A_PID')"; fi
  if [ -n "$HEIR_AFTER" ] && [ "$HEIR_AFTER" = "$HEIR_A_PID" ]; then ok "dispatch-heir: a --dispatch holder that exits hands the marker to the live sibling"
  else bad "dispatch-heir: after the --dispatch holder exited the marker names '$HEIR_AFTER', not the live sibling $HEIR_A_PID — its heir scan never globbed"; fi
  rm -rf "$W"
}
M38_dispatch_noglob_leaks() {
  mutant dispatch-noglob-leaks -e 's@^  \[ "\$dp_noglob_" = 1 \] || set +f$@  :@' || return
  SD="$(sib_dir "$MUT")"
  dispatch_live_world "$SD/wait-for-deliverable.sh"
  if [ "$RC" -eq 0 ] && has "$UNAVAIL_LINE" && ! has "$LIVE_LINE"; then
    ok "MUTANT dispatch-noglob-leaks: with the restore deleted a --dispatch beat reads a fresh transcript as no signal — section 18a catches it"
  else bad "MUTANT dispatch-noglob-leaks: section 18a survives noglob leaking (rc=$RC): $OUT"; fi
  rm -rf "$W"
  heir_world "$SD/wait-for-deliverable.sh"
  if [ -n "$HEIR_B_PID" ] && [ "$HEIR_AFTER" != "$HEIR_A_PID" ]; then
    ok "MUTANT dispatch-noglob-leaks: the leaked noglob makes the exiting holder drop the marker under its sibling — section 18b catches it"
  else bad "MUTANT dispatch-noglob-leaks: section 18b survives noglob leaking (marker after: '$HEIR_AFTER', sibling '$HEIR_A_PID')"; fi
  rm -rf "$W"
}

# ===========================================================================
# 19. --dispatch TAKES EVERY DECLARED ID PREFIX, READ FROM ITS ONE DECLARATION.
#     A local-model lead's dispatch id is `call_<32 hex>`. The subject once matched `toolu_*`
#     alone, so a `call_` id fell to the agentId arm and refused for a missing meta.json. The
#     prefixes are declared once, in the sibling validate-adversarial-convergence.sh; the arms
#     drive a `call_` id against a seeded ledger row, a bare-hex agentId through meta.json as the
#     control that the agentId arm still runs, and a subject with no sibling, which must refuse
#     64 rather than fall back to `toolu_` alone. The ledger seeds an EPOCH row first, so the
#     subject's row is not the ledger's only one.
# ===========================================================================
CALL_ID="call_45aba045bf78553ca703fc8694de7577"
call_world() {  # $1 = subject -> W, OUT, RC; a --status read of a path written after the dispatch
  W="$(mk_work)"; cw_e_=$(( $(date +%s) - 60 ))
  mk_ledger_row "$W" toolu_wbl649epoch $(( cw_e_ - 600 ))
  mk_ledger_row "$W" "$CALL_ID" "$cw_e_"
  printf 'x\n' > "$W/deliv.md"
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" --status --dispatch "$CALL_ID" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
}
S19a_dispatch_call_prefix() {
  call_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if [ "$RC" -eq 0 ] && has "DELIVERED deliv.md"; then ok "dispatch-call: a call_ dispatch id resolves its ledger row and joins from it"
  else bad "dispatch-call: a call_ dispatch id did not resolve (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # CONTROL: a bare-hex agentId still takes the meta.json arm and reaches the same row.
  W="$(mk_work)"; TD="$TMPROOT/s19-td.$$"; mkdir -p "$TD"
  mk_ledger_row "$W" "$CALL_ID" $(( $(date +%s) - 60 ))
  printf '{"agentType":"dev","toolUseId":"%s"}' "$CALL_ID" > "$TD/agent-a649beef.meta.json"
  printf 'x\n' > "$W/deliv.md"
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_TEAMMATE_DIR="$TD" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$(sib_dir "$SUBJ")/wait-for-deliverable.sh" --status --dispatch a649beef deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if [ "$RC" -eq 0 ] && has "DELIVERED deliv.md"; then ok "dispatch-call: CONTROL — a bare-hex agentId still resolves through its meta.json"
  else bad "dispatch-call: CONTROL FAILED — the agentId arm no longer resolves (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
S19b_dispatch_grammar_missing_refuses() {
  LONE649="$(mktemp -d "$TMPROOT/lone649.XXXXXX")"; cp "$SUBJ" "$LONE649/wait-for-deliverable.sh" || broken "cannot copy the subject"
  call_world "$LONE649/wait-for-deliverable.sh"
  if [ "$RC" -eq 64 ] && has "cannot read its id grammar"; then ok "dispatch-call: a subject with no sibling grammar refuses --dispatch (exit 64)"
  else bad "dispatch-call: a missing id grammar did not refuse (rc=$RC) — a silent fallback: $OUT"; fi
  rm -rf "$W"
  # CONTROL: the same lone copy without --dispatch still runs, so the refusal is the grammar's.
  W="$(mk_work)"
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$LONE649/wait-for-deliverable.sh" --status --since "$(( $(date +%s) - 60 ))" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if [ "$RC" -eq 0 ] && has "STATUS --"; then ok "dispatch-call: CONTROL — the same lone copy without --dispatch runs"
  else bad "dispatch-call: CONTROL FAILED — the lone copy does not run at all (rc=$RC): $OUT"; fi
  # A DUPLICATED declaration refuses too: two lines are two grammars, and picking one is a guess.
  SD="$(sib_dir "$SUBJ")"
  printf '\nDISPATCH_ID_PREFIXES="toolu_"\n' >> "$SD/validate-adversarial-convergence.sh"
  call_world "$SD/wait-for-deliverable.sh"
  if [ "$RC" -eq 64 ]; then ok "dispatch-call: a duplicated DISPATCH_ID_PREFIXES declaration refuses (exit 64)"
  else bad "dispatch-call: a duplicated declaration was accepted (rc=$RC): $OUT"; fi
  rm -rf "$W" "$LONE649"
}
M39_dispatch_toolu_only() {
  mutant dispatch-toolu-only -e 's@^  for dp_p_ in \$DP_PREFIXES; do@  for dp_p_ in toolu_; do@' || return
  call_world "$(sib_dir "$MUT")/wait-for-deliverable.sh"
  if [ "$RC" -eq 64 ] && ! has "DELIVERED deliv.md"; then
    ok "MUTANT dispatch-toolu-only: a prefix list hardwired to toolu_ refuses the call_ id — section 19a catches it"
  else bad "MUTANT dispatch-toolu-only: section 19a survives the prefix list being hardwired (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 20. THE LEASE IS HELD BEFORE ANY STEP THAT CAN BLOCK.
#     The stop hook allows the lead's yield only while `.beat-inflight` is live. A beat that
#     blocks before writing it reads to the hook as "no beat armed" while one is. Two blocking
#     steps are forced, each on a FIFO this fixture holds open: the --dispatch ledger read
#     (20a, which the lease once followed) and the sweep's --shard-header check (20b, which it
#     already preceded -- a pin). Each case first proves the beat REACHED the blocking read (the
#     FIFO's writer opens only once a reader has); no progress there is FIXTURE BROKEN, exit 2,
#     never a FAIL. Nothing here reads a clock.
# ===========================================================================
BLK_PID=""; BLK_MARK=""
fifo_hold() {  # $1 = fifo, $2 = reached file, $3 = release file: opens the writer, records it, holds until released
  ( exec 3> "$1"; : > "$2"; while [ ! -e "$3" ]; do sleep 0.1; done; printf '%s\n' "${4:-}" >&3 ) &
  FH_PID=$!
}
blocked_lease() {  # $1 = workdir, $2 = reached file, $3 = release file; reads BLK_PID; sets BLK_MARK
  until_ok 300 test -e "$2" || { kill "$BLK_PID" "$FH_PID" 2>/dev/null; broken "lease: the beat never reached its blocking read"; }
  BLK_MARK=0; [ -n "$(marker_pid "$1")" ] && [ "$(marker_pid "$1")" = "$BLK_PID" ] && BLK_MARK=1
  : > "$3"
  wait "$FH_PID" 2>/dev/null; wait "$BLK_PID" 2>/dev/null
}
ledger_fifo_world() {  # $1 = subject (in a sibling dir); leaves W, sets BLK_MARK
  W="$(mk_work)"; command -v mkfifo >/dev/null || broken "no mkfifo"
  mkfifo "$W/_bmad-output/spawn-ledger.jsonl" || broken "cannot make the ledger a FIFO"
  fifo_hold "$W/_bmad-output/spawn-ledger.jsonl" "$W/reached" "$W/release" \
    "{\"v\":1,\"ts\":\"$(fx_iso $(( $(date +%s) - 30 )))\",\"name\":\"wbl\",\"tool_use_id\":\"toolu_wbl541\"}"
  ( cd "$W" && exec env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" --dispatch toolu_wbl541 deliv.md ) > "$BEATOUT" 2>&1 &
  BLK_PID=$!
  blocked_lease "$W" "$W/reached" "$W/release"
  OUT="$(cat "$BEATOUT")"
}
S20a_lease_before_dispatch_read() {
  ledger_fifo_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if has "WAITING   deliv.md"; then ok "lease-early: CONTROL — the beat blocked on the ledger resumed and ran once the row arrived"
  else bad "lease-early: CONTROL FAILED — the beat over a FIFO ledger never ran a beat: $OUT"; fi
  if [ "$BLK_MARK" -eq 1 ]; then ok "lease-early: a --dispatch beat blocked reading the spawn ledger already holds .beat-inflight"
  else bad "lease-early: a --dispatch beat blocked on the ledger held no lease — the stop hook sees no beat while one is armed"; fi
  rm -rf "$W"
}
S20b_lease_before_shard_check() {
  SD="$(sib_dir "$SUBJ")"; W="$(mk_work)"; command -v mkfifo >/dev/null || broken "no mkfifo"
  mkfifo "$W/hdr.fifo" || broken "cannot make the header FIFO"
  # The stub merge: records that the sweep reached it, then blocks reading the FIFO; exits 0 (header passes).
  printf '#!/usr/bin/env bash\n: > "%s/reached"\nIFS= read -r _ < "%s/hdr.fifo"\nexit 0\n' "$W" "$W" > "$SD/merge-adversarial-shards.sh"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/s.md"
  fifo_hold "$W/hdr.fifo" "$W/held" "$W/release" go
  ( cd "$W" && exec env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$SD/wait-for-deliverable.sh" --since "$(( $(date +%s) - 30 ))" --complete --shard-header convergence s.md ) > "$BEATOUT" 2>&1 &
  BLK_PID=$!
  blocked_lease "$W" "$W/reached" "$W/release"
  OUT="$(cat "$BEATOUT")"
  if [ -e "$W/reached" ]; then ok "lease-early: CONTROL — the sweep reached the stub header check"
  else bad "lease-early: CONTROL FAILED — the sweep never ran the header check: $OUT"; fi
  if [ "$BLK_MARK" -eq 1 ]; then ok "lease-early: a beat blocked inside the sweep's header check already holds .beat-inflight"
  else bad "lease-early: a beat blocked in the sweep's header check held no lease"; fi
  rm -rf "$W"
}
M40_lease_after_dispatch() {
  mutant lease-not-first -e "/^trap 'lease_release' EXIT\$/{n;/^beat_alive\$/d;}" || return
  ledger_fifo_world "$(sib_dir "$MUT")/wait-for-deliverable.sh"
  if [ "$BLK_MARK" -eq 0 ] && has "WAITING   deliv.md"; then
    ok "MUTANT lease-not-first: without the lease at arming a beat blocked on the ledger holds none — section 20a catches it"
  else bad "MUTANT lease-not-first: section 20a survives the early lease being deleted (mark=$BLK_MARK): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 21. THE LEASE IS WHERE THE STOP HOOK LOOKS, WHATEVER AI_DLC_STATE_DIR SAYS.
#     The hook reads `<root>/_bmad-output/.beat-inflight` and never sees AI_DLC_STATE_DIR (lead
#     beats set it as a per-command prefix). So a beat armed with a custom state dir holds its
#     marker and its registration at the root's `_bmad-output`, while its counters stay in the
#     custom dir -- the control that the state dir was honoured at all.
# ===========================================================================
# Re-evaluated on every poll: passed to until_ok as a NAME, never as an expanded `$(...)`.
cs_counter_written() { for cw_ in "$1"/_bmad-output/seat-q/.wait-beats/*; do [ -f "$cw_" ] && return 0; done; return 1; }
custom_state_world() {  # $1 = subject; leaves W, sets CS_MARK (holder pid at root, or ''), CS_LEASE, CS_CTR
  W="$(mk_work)"; CS_MARK=""; CS_LEASE=0; CS_CTR=0
  ( cd "$W" && exec env -u CLAUDE_CODE_SESSION_ID AI_DLC_STATE_DIR=_bmad-output/seat-q AI_DLC_WAIT_BEAT_SECS=40 \
      AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" deliv.md ) > "$BEATOUT" 2>&1 &
  cs_p_=$!
  until_ok 300 cs_counter_written "$W" \
    || { kill "$cs_p_" 2>/dev/null; broken "custom-state: the beat never wrote a counter in its state dir"; }
  CS_CTR=1
  until_ok 50 marker_present "$W" && CS_MARK="$(marker_pid "$W")"
  [ -f "$W/_bmad-output/.wait-beats/.lease-$cs_p_" ] && CS_LEASE=1
  printf 'x\n' > "$W/deliv.md"
  wait "$cs_p_" 2>/dev/null
  CS_PID="$cs_p_"
}
S21_lease_at_root_under_custom_state_dir() {
  custom_state_world "$SUBJ"
  if [ "$CS_CTR" -eq 1 ]; then ok "custom-state: CONTROL — the beat's counters land in its custom state dir"
  else bad "custom-state: CONTROL FAILED — no counter in the custom state dir"; fi
  if [ "$CS_MARK" = "$CS_PID" ] && [ "$CS_LEASE" -eq 1 ]; then ok "custom-state: a beat armed with a custom AI_DLC_STATE_DIR holds its marker and registration at the root _bmad-output"
  else bad "custom-state: marker at the root names '$CS_MARK' (beat $CS_PID), registration=$CS_LEASE — the stop hook cannot see this beat"; fi
  rm -rf "$W"
}
# THE REGISTRATIONS MOVE WITH THE MARKER. Beat B (default state dir) holds the marker; beat A,
# armed with a custom state dir, registers behind it; B's target lands and B exits. B's heir scan
# must find A, so A's `.lease-<pid>` has to sit where B scans. A polls every 30s, so it cannot
# re-take a dropped marker inside the window read here -- a heir found is B's handoff, not A's poll.
cross_heir_world() {  # $1 = subject; leaves W, sets XH_A, XH_B, XH_AFTER
  W="$(mk_work)"; XH_A=""; XH_B=""; XH_AFTER=""
  ( cd "$W" && exec env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS=40 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" b.md ) > "$BEATOUT.B" 2>&1 &
  XH_B=$!
  until_ok 300 marker_present "$W" || { kill "$XH_B" 2>/dev/null; broken "cross-heir: beat B never wrote the marker"; }
  ( cd "$W" && exec env -u CLAUDE_CODE_SESSION_ID AI_DLC_STATE_DIR=_bmad-output/seat-q AI_DLC_WAIT_BEAT_SECS=80 \
      AI_DLC_WAIT_POLL_SECS=30 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" a.md ) > "$BEATOUT.A" 2>&1 &
  XH_A=$!
  until_ok 300 cs_counter_written "$W" || { kill "$XH_A" "$XH_B" 2>/dev/null; broken "cross-heir: beat A never reached its sweep"; }
  printf 'b\n' > "$W/b.md"
  until_ok 300 pid_gone "$XH_B" || { kill "$XH_A" "$XH_B" 2>/dev/null; broken "cross-heir: beat B never exited after its target landed"; }
  XH_AFTER="$(marker_pid "$W")"
  for xp_ in $(pgrep -P "$XH_A" 2>/dev/null); do kill "$xp_" 2>/dev/null; done
  kill "$XH_A" 2>/dev/null; wait "$XH_A" 2>/dev/null; wait "$XH_B" 2>/dev/null
}
S21b_heir_across_state_dirs() {
  cross_heir_world "$SUBJ"
  if [ "$XH_AFTER" = "$XH_A" ]; then ok "custom-state: a holder that exits hands the marker to a live beat armed with a different state dir"
  else bad "custom-state: after the holder exited the marker names '$XH_AFTER', not the live custom-state beat $XH_A — the heir scan cannot see its registration"; fi
  rm -rf "$W"
}
M42_registrations_left_in_state_dir() {
  mutant registrations-in-state-dir -e 's@^LEASE_DIR="\${LEASE_HOME}/.wait-beats"$@LEASE_DIR="${COUNTER_DIR}"@' || return
  cross_heir_world "$MUT"
  if [ "$XH_AFTER" != "$XH_A" ]; then
    ok "MUTANT registrations-in-state-dir: a marker moved without its registrations is dropped under a live custom-state beat — section 21b catches it"
  else bad "MUTANT registrations-in-state-dir: section 21b survives the registrations staying in the state dir"; fi
  rm -rf "$W"
}
M41_lease_in_state_dir() {
  mutant lease-in-state-dir -e 's@^LEASE_HOME="\${WD_ROOT}/_bmad-output"$@LEASE_HOME="${STATE_DIR}"@' || return
  custom_state_world "$MUT"
  if [ "$CS_CTR" -eq 1 ] && [ -z "$CS_MARK" ]; then
    ok "MUTANT lease-in-state-dir: a lease kept in the custom state dir is absent where the hook reads — section 21 catches it"
  else bad "MUTANT lease-in-state-dir: section 21 survives the lease following the state dir (root marker '$CS_MARK')"; fi
  rm -rf "$W"
}

# ===========================================================================
# 22. A CHAINED BEAT IS RECOGNISED BY ITS SHELL, NOT BY HOW RECENTLY ITS SIBLING RAN.
#     The guard once called a sibling "chained" only if its stamp was under BUDGET old, so a
#     loaded box that delayed the second call fails it open and serialises a second quantum.
#     The marker now carries the parent shell's start time. One wrapper shell runs a REAL first
#     beat (short quantum), which writes the marker in the subject's own format; the wrapper then
#     ages that marker 2 x BUDGET (its stamp and its mtime, past the prune age), and for the
#     control replaces the start time with one no live process has (a recycled pid). A second beat
#     from the same wrapper must then not sleep, and the control must. The trailing `exit $?`
#     keeps bash from exec-ing the subject, so both beats' $PPID is the wrapper.
# ===========================================================================
aged_shell_beat() {  # $1 = subject, $2 = workdir, $3 = same|other
  ( cd "$2" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AG_MODE="$3" AI_DLC_PROJECT_ROOT="$2" bash -c '
        s="$1"
        AI_DLC_WAIT_BEAT_SECS=2 bash "$s" first.md > /dev/null 2>&1
        m="_bmad-output/.wait-beats/.shell-$$"; [ -f "$m" ] || exit 3
        r="$(cat "$m")"; r="$(( $(date +%s) - 120 ))${r#"${r%% *}"}"
        [ "$AG_MODE" = other ] && r="${r%% *} Thu Jan 1 00:00:00 1970"
        printf "%s" "$r" > "$m" || exit 3
        touch -t "$(date -v-300S +%Y%m%d%H%M.%S 2>/dev/null || date -d "-300 seconds" +%Y%m%d%H%M.%S)" "$m" || exit 3
        AI_DLC_WAIT_BEAT_SECS=60 bash "$s" deliv.md
        exit $?' _ "$1" ) > "$BEATOUT" 2>&1 &
  AG_PID=$!
}
# A sleeping beat would run its whole 60s quantum; the non-sleeping one returns at once. The arm
# reads which return it TOOK -- the chained NOTE or a charged beat -- not how long it took: the
# sleeping control is released by delivering its target once it has registered its sleep.
ag_wait() {  # $1 = workdir -> OUT, RC
  ag_n_=0
  while kill -0 "$AG_PID" 2>/dev/null; do
    if ag_counter_charged "$1"; then printf 'x\n' > "$1/deliv.md"; fi
    ag_n_=$(( ag_n_ + 1 )); [ "$ag_n_" -lt 600 ] || { kill "$AG_PID" 2>/dev/null; broken "chained: the beat neither returned nor charged a beat"; }
    sleep 0.1
  done
  wait "$AG_PID"; RC=$?; OUT="$(cat "$BEATOUT")"
}
ag_counter_charged() { [ "$(cat "$1/_bmad-output/.wait-beats/$(printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16)" 2>/dev/null)" = 1 ]; }
S22_chained_by_shell_identity() {
  W="$(mk_work)"; aged_shell_beat "$SUBJ" "$W" same; ag_wait "$W"
  if [ "$RC" -eq 0 ] && has "a sibling beat already ran in this same Bash call"; then
    ok "chained: a same-shell sibling stamped 2 x BUDGET ago still reads as chained — the beat does not sleep"
  else bad "chained: a same-shell sibling older than BUDGET let the beat sleep a second quantum (rc=$RC): $OUT"; fi
  rm -rf "$W"
  W="$(mk_work)"; aged_shell_beat "$SUBJ" "$W" other; ag_wait "$W"
  if [ "$RC" -eq 0 ] && ! has "a sibling beat already ran in this same Bash call" && has "DELIVERED deliv.md"; then
    ok "chained: CONTROL — a marker naming another start time (a recycled pid) sleeps"
  else bad "chained: CONTROL FAILED — a different-shell marker was read as chained (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
M43_chained_by_clock() {
  mutant chained-by-clock -e 's@^  if \[ -n "\$LAST_START" \] && \[ -n "\$SHELL_START" \]; then$@  if false; then@' || return
  W="$(mk_work)"; aged_shell_beat "$MUT" "$W" same; ag_wait "$W"
  if ! has "a sibling beat already ran in this same Bash call"; then
    ok "MUTANT chained-by-clock: deciding by age alone sleeps a same-shell sibling stamped past BUDGET — section 22 catches it"
  else bad "MUTANT chained-by-clock: section 22 survives the identity test being removed: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 23. A TEAMMATE WHOSE MODEL IS NOT ANSWERING IS STALLED, NOT LIVE.
#     The harness appends a `{"type":"api-request"` line per request it sends, answered or not.
#     Keyed on mtime, seven unanswered retries read as seven fresh turns. Every seed below has a
#     FRESH mtime; only its lines differ. 3 trailing requests after the last assistant line is
#     STALLED; 2 is not (live runs of 2 occur); `api-request-blob` lines do not count; a recent
#     assistant line last is the control. A wedged transcript's last TURN is old even though the
#     file is new, so with a short idle threshold it also reads IDLE -- which the mtime sensor
#     could never say. Under --dispatch the dispatched agent's transcript is judged by name, so a
#     live sibling does not hide it.
# ===========================================================================
mk_wedged() {  # $1 = dir, $2 = basename, $3 = trailing request lines, $4 = line type (api-request|api-request-blob)
  mkdir -p "$1" || broken "cannot create $1"
  mw_old_="$(fx_iso $(( $(date +%s) - 3600 )))"; mw_now_="$(fx_iso "$(date +%s)")"
  { printf '{"parentUuid":"u1","isSidechain":true,"agentId":"a1","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill"}]},"type":"assistant","timestamp":"%s.300Z"}\n' "$mw_old_"
    mw_i_=0; while [ "$mw_i_" -lt "$3" ]; do
      printf '{"type":"%s","sessionId":"s","agentId":"a1","id":"r%s","timestamp":"%s.200Z","shapeHash":"7d7e1ada"}\n' "$4" "$mw_i_" "$mw_now_"
      mw_i_=$(( mw_i_ + 1 )); done
  } > "$1/$2" || broken "cannot write $1/$2"
}
mk_recovered() {  # $1 = dir, $2 = basename: 3 requests, then a fresh assistant line -- the run was answered
  mkdir -p "$1" || broken "cannot create $1"
  mr_old_="$(fx_iso $(( $(date +%s) - 3600 )))"; mr_now_="$(fx_iso "$(date +%s)")"
  { printf '{"isSidechain":true,"agentId":"a1","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.300Z"}\n' "$mr_old_"
    for mr_i_ in 0 1 2; do
      printf '{"type":"api-request","sessionId":"s","agentId":"a1","id":"r%s","timestamp":"%s.200Z"}\n' "$mr_i_" "$mr_now_"; done
    printf '{"isSidechain":true,"agentId":"a1","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.400Z"}\n' "$mr_now_"
  } > "$1/$2" || broken "cannot write $1/$2"
}
mk_transcript_bare() {  # $1 = dir, $2 = age seconds, $3 = basename: no timestamp on any line
  mkdir -p "$1" || broken "cannot create $1"
  printf '{"t":1}\n' > "$1/$3" || broken "cannot write $1/$3"
  [ "$2" -gt 0 ] && { fx_backdate "$1/$3" "$2" || broken "cannot backdate $1/$3"; }
  return 0
}
STALL_LINE='TEAMMATE STALLED '
S23a_stalled_after_three_requests() {
  W="$(mk_work)"; TD="$TMPROOT/s23a.$$"; mk_wedged "$TD" agent-awedge.jsonl 3 api-request
  beat "$SUBJ" "$W" 60 "$TD"
  if has "${STALL_LINE}agent-awedge.jsonl" && [ "$RC" -eq 0 ]; then ok "stalled: 3 unanswered api-request lines after the last assistant line report STALLED (rc 0)"
  else bad "stalled: a transcript ending in 3 unanswered requests was not reported STALLED (rc=$RC): $OUT"; fi
  if has "$IDLE_BANNER" && ! has "$LIVE_LINE"; then ok "stalled: its last TURN is an hour old though the file is fresh — not reported as a live turn"
  else bad "stalled: a fresh mtime over an hour-old last turn still read as live: $OUT"; fi
  rm -rf "$W" "$TD"
  W="$(mk_work)"; TD="$TMPROOT/s23b.$$"; mk_wedged "$TD" agent-atwo.jsonl 2 api-request
  beat "$SUBJ" "$W" 60 "$TD"
  if ! has "$STALL_LINE"; then ok "stalled: 2 trailing api-request lines do NOT report STALLED (live runs of 2 occur)"
  else bad "stalled: 2 trailing requests were called STALLED: $OUT"; fi
  rm -rf "$W" "$TD"
  W="$(mk_work)"; TD="$TMPROOT/s23c.$$"; mk_wedged "$TD" agent-ablob.jsonl 5 api-request-blob
  beat "$SUBJ" "$W" 60 "$TD"
  if ! has "$STALL_LINE"; then ok "stalled: api-request-blob lines are not requests and do NOT count"
  else bad "stalled: api-request-blob lines were counted as unanswered requests: $OUT"; fi
  rm -rf "$W" "$TD"
  # A run of 3 that an assistant line then ANSWERED is a recovered teammate: the run resets.
  W="$(mk_work)"; TD="$TMPROOT/s23r.$$"; mk_recovered "$TD" agent-arecov.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE" && ! has "$STALL_LINE"; then ok "stalled: 3 requests followed by an assistant line read live, NOT STALLED (the run resets)"
  else bad "stalled: a teammate that answered after 3 requests was called STALLED or not live: $OUT"; fi
  rm -rf "$W" "$TD"
  W="$(mk_work)"; TD="$TMPROOT/s23d.$$"; mk_transcript "$TD" 0 agent-alive.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE" && ! has "$STALL_LINE"; then ok "stalled: CONTROL — a recent assistant line last reads as a live turn, not STALLED"
  else bad "stalled: CONTROL FAILED — a live transcript did not read live: $OUT"; fi
  rm -rf "$W" "$TD"
}
S23b_quiet_fallback_without_timestamps() {
  W="$(mk_work)"; TD="$TMPROOT/s23e.$$"; mk_transcript_bare "$TD" 7200 agent-abare.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "stalled: a transcript carrying no timestamps falls back to its mtime (2h old reads IDLE)"
  else bad "stalled: a timestamp-less transcript gave no reading from its mtime: $OUT"; fi
  rm -rf "$W" "$TD"
  W="$(mk_work)"; TD="$TMPROOT/s23f.$$"; mk_transcript_bare "$TD" 0 agent-abare.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE"; then ok "stalled: CONTROL — the same seed with a fresh mtime reads live"
  else bad "stalled: CONTROL FAILED — a fresh timestamp-less transcript is not read live: $OUT"; fi
  rm -rf "$W" "$TD"
}
S23c_dispatch_judges_its_own_transcript() {
  W="$(mk_work)"; TD="$TMPROOT/s23g.$$"
  mk_wedged "$TD" agent-awedge.jsonl 3 api-request
  mk_transcript "$TD" 0 agent-alive.jsonl
  printf '{"agentType":"dev","toolUseId":"toolu_wbl578"}' > "$TD/agent-awedge.meta.json"
  mk_ledger_row "$W" toolu_wbl578 $(( $(date +%s) - 30 ))
  beat "$(sib_dir "$SUBJ")/wait-for-deliverable.sh" "$W" 60 "$TD" --dispatch toolu_wbl578
  if has "${STALL_LINE}agent-awedge.jsonl" && has "$IDLE_BANNER" && ! has "$LIVE_LINE"; then
    ok "stalled: under --dispatch the dispatched agent's own transcript is judged — a live sibling does not hide the wedge"
  else bad "stalled: a live sibling hid the dispatched agent's wedge under --dispatch: $OUT"; fi
  rm -rf "$W"
  # CONTROL: the same directory without --dispatch takes the newest turn across the session.
  W="$(mk_work)"; beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE" && has "${STALL_LINE}agent-awedge.jsonl"; then ok "stalled: CONTROL — without --dispatch the session reads live and still names the stalled transcript"
  else bad "stalled: CONTROL FAILED — the whole-session reading is not the live sibling's: $OUT"; fi
  rm -rf "$W" "$TD"
}
M44_quiet_from_mtime() {
  mutant quiet-from-mtime -e 's@^    tq_m_=""; \[ "\$tq_t_" = "-" \] || tq_m_=.*$@    tq_m_=""@' || return
  W="$(mk_work)"; TD="$TMPROOT/m44.$$"; mk_wedged "$TD" agent-awedge.jsonl 3 api-request
  beat "$MUT" "$W" 60 "$TD"
  if has "$LIVE_LINE" && ! has "$IDLE_BANNER"; then
    ok "MUTANT quiet-from-mtime: reading quiet from mtime reports a wedged teammate as a live turn — section 23a catches it"
  else bad "MUTANT quiet-from-mtime: section 23a survives quiet being read from mtime: $OUT"; fi
  rm -rf "$W" "$TD"
}
M45_stall_counts_blobs() {
  mutant stall-counts-blobs -e 's@index(\$0, "{\\"type\\":\\"api-request\\"") == 1@index($0, "{\\"type\\":\\"api-request") == 1@' || return
  W="$(mk_work)"; TD="$TMPROOT/m45.$$"; mk_wedged "$TD" agent-ablob.jsonl 5 api-request-blob
  beat "$MUT" "$W" 60 "$TD"
  if has "$STALL_LINE"; then ok "MUTANT stall-counts-blobs: matching without the closing quote counts blob lines as requests — section 23a catches it"
  else bad "MUTANT stall-counts-blobs: section 23a survives the closing quote being dropped: $OUT"; fi
  rm -rf "$W" "$TD"
}
# The reset dropped: every request in the file counts, so a recovered teammate reads STALLED and
# the lead is told to stop a healthy one.
M47_run_never_resets() {
  mutant run-never-resets -e 's@^    NF { run = 0 }$@    NF { }@' || return
  W="$(mk_work)"; TD="$TMPROOT/m47.$$"; mk_recovered "$TD" agent-arecov.jsonl
  beat "$MUT" "$W" 60 "$TD"
  if has "$STALL_LINE"; then ok "MUTANT run-never-resets: an answered run still counted reads a recovered teammate STALLED -- section 23a catches it"
  else bad "MUTANT run-never-resets: section 23a survives the run never resetting: $OUT"; fi
  rm -rf "$W" "$TD"
}

# ===========================================================================
# 24. --mark: THE SEAL DECIDES, WITH NO WINDOW, AND A LEGACY MARKER STILL SETTLES.
#     A seat closes with `--mark`, which appends `sha=<digest of everything above>` before
#     `findings=`. A sealed file DELIVERS in one beat under a settle window it could never close
#     (SETTLE=600); the same file edited above its marker is UNFINISHED under SETTLE=1 in a beat
#     long enough to settle anything, i.e. at any age; re-marked it DELIVERS again. The CONTROL is
#     a bare marker beside it in the same beat, which settles and DELIVERS -- so the broken file's
#     WAITING is the seal's verdict and not a beat too short to settle.
# ===========================================================================
SEAL_BROKEN='-- its seat-complete: line carries sha= but the file changed after it was marked'
seal_world() {  # $1 = subject, $2 = workdir -> s.md sealed, x.md sealed then edited, b.md bare
  printf '%s\n' "$SKELETON" > "$2/s.md"; printf '%s\n' "$SKELETON" > "$2/x.md"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$2/b.md"
  bash "$1" --mark "$2/s.md" requirements pm cross-1 findings=1 > "$BEATOUT" 2>&1 || broken "--mark refused s.md: $(cat "$BEATOUT")"
  bash "$1" --mark "$2/x.md" requirements pm cross-1 findings=1 > "$BEATOUT" 2>&1 || broken "--mark refused x.md: $(cat "$BEATOUT")"
  awk 'NR == 3 { print "- a finding rewritten after the marker"; next } { print }' "$2/x.md" > "$2/x.tmp" && mv "$2/x.tmp" "$2/x.md"
}

S24a_seal_decides() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  seal_world "$SUBJ" "$W"
  case "$(tail -1 "$W/s.md")" in
    "$MARKER sha="*" findings=1") ok "seal: --mark appends '<marker> sha=<hex> findings=<n>', sha= before findings=" ;;
    *) bad "seal: --mark wrote '$(tail -1 "$W/s.md")'" ;;
  esac
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete s.md
  if has "DELIVERED s.md"; then ok "seal: a sealed file DELIVERS in one 2s beat under SETTLE=600 -- no window"
  else bad "seal: a sealed file waited on the settle window: $OUT"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete x.md b.md
  if has "DELIVERED b.md"; then ok "seal: CONTROL -- a bare marker settles and DELIVERS in the same 3s beat under SETTLE=1"
  else bad "seal: CONTROL FAILED -- the bare marker did not settle, so the beat below proves nothing: $OUT"; fi
  if ! has "DELIVERED x.md" && has "UNFINISHED x.md $SEAL_BROKEN"; then
    ok "seal: a sealed file edited above its marker is UNFINISHED where a bare one settles -- at any age"
  else bad "seal: a broken seal was delivered or not named UNFINISHED: $OUT"; fi
  CB_SETTLE=600 scall "$SUBJ" "$W" --complete --since "$CBEAT_SINCE" s.md x.md
  if has "DELIVERED s.md" && has "UNFINISHED x.md $SEAL_BROKEN"; then ok "seal: --status reads sealed DELIVERED and broken UNFINISHED, with no beat run"
  else bad "seal: --status disagrees with the beat on a sealed or broken file: $OUT"; fi
  bash "$SUBJ" --mark "$W/x.md" requirements pm cross-1 findings=1 > "$BEATOUT" 2>&1 || broken "re-mark refused"
  n_mk="$(grep -c '^seat-complete: ' "$W/x.md")" || n_mk=0
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete x.md
  if has "DELIVERED x.md" && [ "$n_mk" = 1 ]; then ok "seal: re-marked, the edited file DELIVERS at once and carries one marker"
  else bad "seal: re-mark did not deliver (markers=$n_mk): $OUT"; fi
  rm -rf "$W"
}

S24b_mark_refusals() {
  W="$(mk_work)"
  printf '%s\n```text\nan open fence\n' "$SKELETON" > "$W/f.md"; cp "$W/f.md" "$W/f.orig"
  bash "$SUBJ" --mark "$W/f.md" requirements pm cross-1 findings=0 > "$BEATOUT" 2>&1; rc=$?
  if [ "$rc" -eq 64 ] && cmp -s "$W/f.md" "$W/f.orig"; then ok "seal: --mark on a body ending inside an open fence refuses (64) and writes nothing"
  else bad "seal: --mark into an open fence rc=$rc, file changed or accepted"; fi
  # Four fields on a clean file, so the refusal is the findings= check and not the arity or a fence.
  printf '%s\n' "$SKELETON" > "$W/c.md"
  bash "$SUBJ" --mark "$W/c.md" requirements pm cross-1 count=1 > "$BEATOUT" 2>&1; rc=$?
  if [ "$rc" -eq 64 ] && grep -qF 'the last field must be findings=<n>' "$BEATOUT"; then ok "seal: --mark whose last field is not findings=<n> refuses (64)"
  else bad "seal: --mark with a malformed findings field rc=$rc: $(cat "$BEATOUT")"; fi
  printf '### e\n- edit: x\n' > "$W/r.md"
  bash "$SUBJ" --mark-repair "$W/r.md" requirements > "$BEATOUT" 2>&1; rc=$?
  case "$rc $(tail -1 "$W/r.md")" in
    "0 repair-complete: serial requirements sha="*) ok "seal: --mark-repair appends 'repair-complete: serial <pass> sha=<hex>'" ;;
    *) bad "seal: --mark-repair rc=$rc wrote '$(tail -1 "$W/r.md")'" ;;
  esac
  rm -rf "$W"
}

# The digest ignored: every marker is judged as legacy. The sealed file then waits on SETTLE=600
# and the broken one settles and DELIVERS -- section 24a must catch it.
M46_seal_ignored() {
  mutant seal-ignored -e 's@^  seal_of "\$1"; id_sv_=\$?$@  seal_of "$1"; id_sv_=2@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  seal_world "$SUBJ" "$W"
  CB_BEAT=3 cbeat "$MUT" "$W" --complete x.md b.md
  if has "DELIVERED x.md"; then ok "MUTANT seal-ignored: a beat ignoring the digest DELIVERS the edited file -- section 24a catches it"
  else bad "MUTANT seal-ignored: section 24a survives the digest being ignored (or the mutant never ran): $OUT"; fi
  rm -rf "$W"
}

# --mark-repair seals the serial remediator's record the same way: a sealed record DELIVERS under
# --complete-repair at SETTLE=600, an edit above its marker is UNFINISHED, and the CONTROL is a
# bare `repair-complete: serial` record settling in that same beat under SETTLE=1.
repair_world() {  # $1 = subject, $2 = workdir -> rs.md sealed, rx.md sealed then edited, rb.md bare
  printf '### e\n- edit: x\n' > "$2/rs.md"; printf '### e\n- edit: x\n' > "$2/rx.md"
  printf '### e\n- edit: x\n%s\n' "$REPAIR_MARKER" > "$2/rb.md"
  bash "$1" --mark-repair "$2/rs.md" requirements > "$BEATOUT" 2>&1 || broken "--mark-repair refused rs.md: $(cat "$BEATOUT")"
  bash "$1" --mark-repair "$2/rx.md" requirements > "$BEATOUT" 2>&1 || broken "--mark-repair refused rx.md: $(cat "$BEATOUT")"
  awk 'NR == 1 { print "### a repair entry added after the marker" } { print }' "$2/rx.md" > "$2/rx.tmp" && mv "$2/rx.tmp" "$2/rx.md"
}
S24c_mark_repair_seals() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  repair_world "$SUBJ" "$W"
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete-repair rs.md
  if has "DELIVERED rs.md"; then ok "seal: a --mark-repair record DELIVERS under --complete-repair in one beat at SETTLE=600"
  else bad "seal: a sealed repair record waited on the settle window: $OUT"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete-repair rx.md rb.md
  if has "DELIVERED rb.md"; then ok "seal: CONTROL -- a bare repair-complete record settles and DELIVERS in the same 3s beat"
  else bad "seal: CONTROL FAILED -- the bare repair record did not settle, so the beat below proves nothing: $OUT"; fi
  if ! has "DELIVERED rx.md" && has "UNFINISHED rx.md" && has "changed after it was marked"; then
    ok "seal: a sealed repair record edited above its marker is UNFINISHED"
  else bad "seal: a broken repair seal was delivered or not named UNFINISHED: $OUT"; fi
  rm -rf "$W"
}
# --mark-repair writing the seat token: the record ends in `seat-complete:`, which --complete-repair
# must refuse -- section 24c's sealed record then never delivers.
M48_mark_repair_seat_token() {
  mutant mark-repair-seat-token -e 's@MARK_TOKEN="repair-complete: serial "; MK_F="\$1"; MK_TAIL=""@MARK_TOKEN="seat-complete: "; MK_F="$1"; MK_TAIL=""@' || return
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '### e\n- edit: x\n' > "$W/rs.md"
  bash "$MUT" --mark-repair "$W/rs.md" requirements > "$BEATOUT" 2>&1
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete-repair rs.md
  if ! has "DELIVERED rs.md"; then ok "MUTANT mark-repair-seat-token: a repair record sealed under the seat token is not delivered -- section 24c catches it"
  else bad "MUTANT mark-repair-seat-token: section 24c survives --mark-repair writing seat-complete: $OUT"; fi
  rm -rf "$W"
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
