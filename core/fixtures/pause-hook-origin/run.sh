#!/usr/bin/env bash
# pause-hook-origin/run.sh — prove ai-dlc-pause.sh pauses on operator prose and ONLY on
# operator prose.
#
# THE DEFECT. The hook touched the pause flag on every UserPromptSubmit with no inspection of
# the prompt at all; it read `.prompt` only for a 120-char log preview. The harness raises
# UserPromptSubmit identically when a backgrounded task completes as when a human types, so
# the hook created a pause flag for events carrying no operator prose, and the lead then
# blocked on a pause no human initiated. Five occurrences across two sprints on the reference
# consumer went undiagnosed, because a flag looks the same whoever created it.
#
# THE DIRECTION THAT MATTERS. A false NON-pause means the lead executes straight through a
# real operator steer — the failure Rule 29 exists to prevent. Assertion 3 is therefore the
# load-bearing one: it is the assertion that would catch a predicate scoped too widely.
#
# THE SECOND SUBJECT. Assertions 8 and 9 are about the FLOW LOG this hook opens, not about
# the origin predicate, and they read all three hooks that can open it rather than this one.
# They live here because assertion 6 is the arm they correct: it asserts the legend from the
# log THIS hook produced, which is a per-hook reading of a cross-hook property, and it cannot
# see the hooks disagreeing. Their own reasoning is at assertion 8.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a hook while inheriting them tests the CONFIG, not the code — and
# then blocks the consumer's every push against a hook behaving exactly as specified.
# Scrub first (validate-enforcement-map.sh I10 asserts this rather than trusting it).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the hook exactly as the harness does: JSON on stdin, CLAUDE_PROJECT_DIR set.
fire() { # <prompt-json-string>
  rm -f "$FLAG"
  printf '{"session_id":"fixture","prompt":%s}' "$1" \
    | CLAUDE_PROJECT_DIR="$PROJECT" bash "$HOOK" >/dev/null 2>&1
}

echo "pause-hook-origin:"

# --- Assertion 0: SANITY — the hook reaches the predicate at all --------------
# Without an active pipeline the hook exits before the predicate, and every assertion below
# would pass for the wrong reason.
if [ -f "$SNAPSHOT" ]; then
  ok "seed: a pipeline snapshot exists, so the hook runs past its no-snapshot early exit"
else
  bad "FIXTURE BROKEN — no snapshot; the hook exits before the predicate"
  echo; echo "pause-hook-origin: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: an EMPTY prompt does not pause ------------------------------
fire '""'
if [ ! -f "$FLAG" ]; then
  ok "empty prompt: no pause flag created"
else
  bad "an empty prompt still created the pause flag — the lead blocks on a pause no human initiated"
fi

# --- Assertion 2: whitespace + a system-reminder does not pause ---------------
# This is the shape a harness-synthetic event actually arrives in: no operator prose, but not
# a bare empty string either.
fire '"  \n<system-reminder>background task finished</system-reminder>\n  "'
if [ ! -f "$FLAG" ]; then
  ok "whitespace + system-reminder only: no pause flag created"
else
  bad "a prompt with no operator prose still created the pause flag"
fi

# --- Assertion 3: REAL OPERATOR PROSE STILL PAUSES ---------------------------
# The load-bearing assertion. Everything above narrows the hook; this is what stops the
# narrowing from swallowing a genuine steer.
fire '"Stop and re-check the gate before you continue."'
if [ -f "$FLAG" ]; then
  ok "operator prose: pause flag created (the narrowing cannot swallow a real steer)"
else
  bad "A REAL OPERATOR STEER DID NOT PAUSE THE PIPELINE. The predicate is scoped too widely; this is the failure direction Rule 29 exists to prevent."
fi

# --- Assertion 4: operator prose ALONGSIDE a system-reminder still pauses ------
# Every real operator turn in this harness carries system-reminder blocks. If stripping them
# ever consumed the prose too, assertion 3 would still pass while every real steer was lost.
fire '"<system-reminder>ctx</system-reminder>Actually, hold on — revert that."'
if [ -f "$FLAG" ]; then
  ok "prose + system-reminder: pause flag created (stripping does not consume the prose)"
else
  bad "a real steer arriving with a system-reminder was discarded — the strip is eating operator text"
fi

# --- Assertion 5: the skip is RECORDED, not silent ----------------------------
# A pause that never happened reads exactly like a pause the lead already cleared. If nothing
# records which, the retro cannot tell an over-firing hook from a well-behaved one.
fire '""'
if grep -q 'PAUSE_SKIPPED' "$LOG" 2>/dev/null; then
  ok "the skip is logged PAUSE_SKIPPED — not silent"
else
  bad "the hook skipped without recording it; a skip indistinguishable from a cleared pause is the same defect one layer down"
fi

# --- Assertion 6: the log legend explains the event it emits -------------------
# The skip path seeds the header too. A first-write that is a SKIP must not produce a log
# whose legend omits the only event type in it.
if grep -q '`PAUSE_SKIPPED`' "$LOG" 2>/dev/null; then
  ok "the log's event-type legend documents PAUSE_SKIPPED"
else
  bad "PAUSE_SKIPPED entries are written into a log whose legend never mentions them"
fi

# --- Assertion 7: MUTANT — remove the predicate and assertion 1 must fail ------
MUT="$WORK/pause-mutant.sh"
sed 's|^if \[ -z "\$PROMPT_STRIPPED" \]; then|if [ -n "$PROMPT_STRIPPED" ] \&\& false; then|' \
  "$HOOK" > "$MUT"
if ! grep -q 'PROMPT_STRIPPED" \] && false' "$MUT"; then
  bad "FIXTURE STALE: could not build the no-predicate mutant — the guard's condition was reworded"
else
  rm -f "$FLAG"
  printf '{"session_id":"fixture","prompt":""}' \
    | CLAUDE_PROJECT_DIR="$PROJECT" bash "$MUT" >/dev/null 2>&1
  if [ -f "$FLAG" ]; then
    ok "mutant: with the predicate disabled an empty prompt pauses again — the fixture can fail"
  else
    bad "MUTANT DID NOT FAIL — an empty prompt creates no flag even with the guard disabled, so assertion 1 proves nothing"
  fi
fi

# --- Assertion 8: the THREE hooks seed the SAME legend -------------------------
# WHY THIS LIVES HERE, AND WHY ASSERTION 6 IS NOT ENOUGH. Assertion 6 reads the log this
# fixture's own run produced, so it sees whichever legend `ai-dlc-pause.sh` happens to carry.
# `_bmad-output/pipeline-continuation-log.md` is opened by whichever of THREE hooks fires
# first — `ai-dlc-continue.sh`, `ai-dlc-acknowledge.sh` and this one — each seeding its own
# heredoc into an absent-or-empty file. A per-hook assertion is therefore structurally unable
# to see a disagreement BETWEEN them: assertion 6 stayed green across the entire life of one,
# in which `BACKOFF` carried two different stated causes, `PAUSE_SKIPPED` was documented in
# one legend of three, and the retro-guidance block was missing from a third. `retro.md` §4b
# counts events out of this log and the legend is the reader's ONLY statement of what a count
# means, so which legend a sprint got was decided by hook firing order.
#
# ANTI-VACUITY. Three EMPTY strings compare equal. Extraction breaking silently would close
# this arm on a dead instrument, which is the exact shape assertion 6 already failed in. The
# verdict function refuses to compare until each hook has exactly ONE legend opener and a
# NON-EMPTY body, and the byte counts are printed so a human can see the arm had a subject.
# Canonicalised, because the mutation battery below is required to print the path it edits
# and a path carrying `../..` is not one a human can compare against the file they changed.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] \
  && { printf '%s/%s' "$(cd "$(dirname "$c")" && pwd)" "$(basename "$c")"; return; }; done; }
CONT_HOOK="$(pick "$HERE/../../hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../.claude/hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
ACK_HOOK="$(pick "$HERE/../../hooks/ai-dlc-acknowledge.sh" \
                 "$HERE/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
                 "$HERE/../../../core/hooks/ai-dlc-acknowledge.sh")"
PAUSE_HOOK="$(pick "$HERE/../../hooks/ai-dlc-pause.sh" \
                   "$HERE/../../../.claude/hooks/ai-dlc-pause.sh" \
                   "$HERE/../../../core/hooks/ai-dlc-pause.sh")"
ESC_HOOK="$(pick "$HERE/../../hooks/ai-dlc-escalation-delivery.sh" \
                 "$HERE/../../../.claude/hooks/ai-dlc-escalation-delivery.sh" \
                 "$HERE/../../../core/hooks/ai-dlc-escalation-delivery.sh")"

# The heredoc body between `cat > "$LOG_FILE" <<'EOF'` and its terminator. Keyed on the
# EMITTING line, not on a mention of the log elsewhere in the file. LC_ALL=C because the
# legend carries a multibyte em-dash and awk aborts mid-file on it under a UTF-8 locale.
legend_body() { # <hook-path> -> body on stdout
  LC_ALL=C awk '
    /^[[:space:]]*cat > "\$LOG_FILE" <<.EOF.$/ { inb=1; next }
    inb && /^EOF$/                             { inb=0; next }
    inb                                        { print }
  ' "$1"
}
legend_openers() { # <hook-path> -> count of legend-emitting lines
  LC_ALL=C grep -c '^[[:space:]]*cat > "\$LOG_FILE" <<.EOF.$' "$1"
}
# One word on stdout: SAME, DIFFER, or a guard verdict naming which hook tripped it. The
# guards run over EVERY hook passed before any comparison, so an empty extraction can never
# reach the `cmp` and pass as agreement.
#
# VARIADIC IN THE COMPARISON TOO, not just in the guards. The guard loop always walked `$@`
# while the comparison hard-coded `legend.1..3`, so a FOURTH seeding hook would have been
# guarded and then silently left out of the only assertion that matters — the arm would have
# gone on reporting agreement among three while a fourth drifted. `ai-dlc-escalation-delivery.sh`
# is that fourth hook.
legend_verdict() { # <scratch-dir> <hook>... -> verdict
  local d="$1"; shift
  local n=0 h opens i
  for h in "$@"; do
    n=$((n+1))
    [ -f "$h" ] || { printf 'MISSING:%s\n' "$n"; return; }
    opens="$(legend_openers "$h")"
    [ "$opens" = "1" ] || { printf 'NO-SINGLE-OPENER:%s:%s\n' "$n" "$opens"; return; }
    legend_body "$h" > "$d/legend.$n"
    [ -s "$d/legend.$n" ] || { printf 'EMPTY-LEGEND:%s\n' "$n"; return; }
  done
  # Fewer than two bodies cannot disagree, so a shrunken caller must not read as SAME.
  [ "$n" -ge 2 ] || { printf 'TOO-FEW:%s\n' "$n"; return; }
  i=2
  while [ "$i" -le "$n" ]; do
    cmp -s "$d/legend.1" "$d/legend.$i" || { printf 'DIFFER\n'; return; }
    i=$((i+1))
  done
  printf 'SAME\n'
}

V8="UNRESOLVED"
if [ -z "$CONT_HOOK" ] || [ -z "$ACK_HOOK" ] || [ -z "$PAUSE_HOOK" ] || [ -z "$ESC_HOOK" ]; then
  bad "FIXTURE BROKEN — cannot locate all four log-seeding hooks in either layout"
else
  LEG="$WORK/legend"; mkdir -p "$LEG"
  printf '        legend sources: %s | %s | %s | %s\n' "$CONT_HOOK" "$ACK_HOOK" "$PAUSE_HOOK" "$ESC_HOOK"
  V8="$(legend_verdict "$LEG" "$CONT_HOOK" "$ACK_HOOK" "$PAUSE_HOOK" "$ESC_HOOK")"
  printf '        legend bytes:   continue=%s acknowledge=%s pause=%s escalation-delivery=%s\n' \
    "$(wc -c < "$LEG/legend.1" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.2" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.3" 2>/dev/null | tr -d ' ')" \
    "$(wc -c < "$LEG/legend.4" 2>/dev/null | tr -d ' ')"
  if [ "$V8" = "SAME" ]; then
    ok "all four hooks seed a byte-identical log legend"
  elif [ "$V8" = "DIFFER" ]; then
    bad "THE SEEDED LEGENDS DISAGREE ($V8). Which legend a sprint gets is decided by hook firing order, and retro.md §4b reads it as the definition of every count it reports."
  else
    bad "FIXTURE BROKEN — legend extraction returned no subject ($V8); this arm was about to compare empty strings and pass"
  fi
fi

# --- Assertion 9: MUTANTS — prove assertion 8 and its anti-vacuity guard can fire
# Every mutant is a COPY under $WORK; the real hooks are never edited. Each `sed`/`awk`
# rewrite is guarded with `cmp -s` so a rewrite that matched nothing reports FIXTURE STALE
# instead of scoring a kill, and the resolved path of every mutated file is printed. The
# battery opens with an UNMUTATED control from the same directory: if the copies themselves
# were what broke, the control says so rather than the kills reading as clean.
#
# IT STANDS DOWN WHEN ASSERTION 8 ALREADY FAILED, and that is an ownership decision, not a
# convenience. Every mutant here is built from the same three hooks assertion 8 read, so a
# genuinely divergent subject makes the battery's own baseline divergent: measured against
# the real pre-fix tree the battery added three more FAILs — a broken control, a stale
# anchor, and a short kill count — on top of the one true finding. Assertion 8 OWNS a
# divergent subject; the battery only ever answers "can assertion 8 fire", which is a
# question with no meaning while it IS firing. The stand-down cannot hide anything: it is
# reachable only on a path that has already failed the fixture, and it says so out loud.
if [ "$V8" != "SAME" ]; then
  printf '        legend battery: STOOD DOWN — assertion 8 owns this case and already failed (%s)\n' "$V8"
elif [ -n "${CONT_HOOK:-}" ] && [ -n "${ACK_HOOK:-}" ] && [ -n "${PAUSE_HOOK:-}" ] && [ -n "${ESC_HOOK:-}" ]; then
  MUT="$WORK/legend-mutants"; mkdir -p "$MUT"
  cp "$CONT_HOOK" "$MUT/continue.sh"
  cp "$ACK_HOOK"  "$MUT/acknowledge.sh"
  cp "$PAUSE_HOOK" "$MUT/pause.sh"
  cp "$ESC_HOOK"  "$MUT/escalation.sh"
  kills=0

  # 9a. CONTROL — unmutated copies in the mutant directory still read SAME.
  VC="$(legend_verdict "$MUT" "$MUT/continue.sh" "$MUT/acknowledge.sh" "$MUT/pause.sh" "$MUT/escalation.sh")"
  if [ "$VC" = "SAME" ]; then
    ok "mutant control: unmutated copies under $MUT read SAME — the battery's harness is alive"
  else
    bad "MUTANT HARNESS BROKEN — unmutated copies read $VC, so every kill below is unreadable"
  fi

  # 9b. ONE BYTE in ONE hook's legend — `:` -> `;` inside the BACKOFF entry — and it runs
  # ONCE PER HOOK. The verdict is one comparison per position against legend.1, so mutating a
  # single hook exercises only one of them and leaves the rest unproven; a divergence in hook 2
  # is caught by an expression a pause.sh-only mutant never reaches. One pass per position is
  # what makes every comparison load-bearing — including the FOURTH, which is the one the
  # hard-coded `legend.1..3` comparison used to skip while still guarding it.
  for pos in 1 2 3 4; do
    case "$pos" in 1) src=continue ;; 2) src=acknowledge ;; 3) src=pause ;; 4) src=escalation ;; esac
    sed 's/^- `BACKOFF`: rapid-fire/- `BACKOFF`; rapid-fire/' "$MUT/$src.sh" > "$MUT/$src.1byte.sh"
    if cmp -s "$MUT/$src.sh" "$MUT/$src.1byte.sh"; then
      bad "FIXTURE STALE: the one-byte legend mutation matched nothing in $src.sh — the BACKOFF entry was reworded"
      continue
    fi
    c="$MUT/continue.sh"; a="$MUT/acknowledge.sh"; p="$MUT/pause.sh"; e="$MUT/escalation.sh"
    case "$pos" in
      1) c="$MUT/continue.1byte.sh" ;;
      2) a="$MUT/acknowledge.1byte.sh" ;;
      3) p="$MUT/pause.1byte.sh" ;;
      4) e="$MUT/escalation.1byte.sh" ;;
    esac
    printf '        mutant 9b/%s edits: %s\n' "$src" "$MUT/$src.1byte.sh"
    V9B="$(legend_verdict "$MUT" "$c" "$a" "$p" "$e")"
    if [ "$V9B" = "DIFFER" ]; then
      kills=$((kills+1)); ok "mutant 9b/$src: one byte changed in $src's legend -> DIFFER (assertion 8 can fire on this hook)"
    else
      bad "MUTANT 9b/$src DID NOT FAIL — a one-byte divergence in $src read as $V9B, so assertion 8 is blind to that hook"
    fi
  done

  # 9c. The extractor loses its anchor in ALL THREE. Renaming the heredoc delimiter is the
  # realistic shape of a broken extractor: nothing matches, three empty bodies, and a naive
  # arm compares them equal and prints ok. The opener guard must catch it FIRST.
  for m in continue acknowledge pause; do
    sed "s/^\\( *cat > \"\\\$LOG_FILE\" <<\\)'EOF'\$/\\1'HDR'/" "$MUT/$m.sh" > "$MUT/$m.noanchor.sh"
  done
  if cmp -s "$MUT/pause.sh" "$MUT/pause.noanchor.sh"; then
    bad "FIXTURE STALE: the anchor-removal mutation matched nothing — the heredoc opener changed shape"
  else
    printf '        mutant 9c edits: %s %s %s\n' \
      "$MUT/continue.noanchor.sh" "$MUT/acknowledge.noanchor.sh" "$MUT/pause.noanchor.sh"
    V9C="$(legend_verdict "$MUT" "$MUT/continue.noanchor.sh" "$MUT/acknowledge.noanchor.sh" "$MUT/pause.noanchor.sh")"
    case "$V9C" in
      NO-SINGLE-OPENER:*)
        kills=$((kills+1)); ok "mutant 9c: extractor anchor gone in all three -> $V9C (the guard fires, not the comparison)" ;;
      SAME)
        bad "MUTANT 9c DID NOT FAIL — three unextractable legends compared EQUAL and assertion 8 would have printed ok" ;;
      *)
        bad "MUTANT 9c: expected the opener guard, got $V9C" ;;
    esac
  fi

  # 9d. The opener SURVIVES but the body is emptied in all three. This is the branch 9c
  # cannot reach: one opener each, extraction succeeds, and three empty bodies are equal.
  for m in continue acknowledge pause; do
    LC_ALL=C awk '
      /^[[:space:]]*cat > "\$LOG_FILE" <<.EOF.$/ { print; ins=1; next }
      ins && /^EOF$/                             { print; ins=0; next }
      ins                                        { next }
                                                 { print }
    ' "$MUT/$m.sh" > "$MUT/$m.emptybody.sh"
  done
  if cmp -s "$MUT/pause.sh" "$MUT/pause.emptybody.sh"; then
    bad "FIXTURE STALE: the empty-body mutation matched nothing — the legend heredoc moved"
  else
    printf '        mutant 9d edits: %s %s %s\n' \
      "$MUT/continue.emptybody.sh" "$MUT/acknowledge.emptybody.sh" "$MUT/pause.emptybody.sh"
    V9D="$(legend_verdict "$MUT" "$MUT/continue.emptybody.sh" "$MUT/acknowledge.emptybody.sh" "$MUT/pause.emptybody.sh")"
    case "$V9D" in
      EMPTY-LEGEND:*)
        kills=$((kills+1)); ok "mutant 9d: three EMPTY legend bodies -> $V9D (the anti-vacuity guard fires)" ;;
      SAME)
        bad "MUTANT 9d DID NOT FAIL — three empty legends compared EQUAL, which is assertion 8 closing on a dead instrument" ;;
      *)
        bad "MUTANT 9d: expected the empty-body guard, got $V9D" ;;
    esac
  fi

  # A mutation applied to a copy the verdict never loads leaves every arm green and reads
  # exactly like an arm that cannot fire. Assert the kill count directly.
  #
  # DERIVED FROM THE HOOK COUNT, NOT HAND-WRITTEN. This total was the literal `5` and a
  # FOURTH seeding hook made it 6, so adding a hook failed this arm with a number rather than
  # a reason — the count is one per hook plus the two whole-battery mutants (anchor-loss,
  # empty-body). Deriving it means the next hook to seed a legend extends the battery instead
  # of tripping it, and a SHRUNKEN battery still fails: expected moves down with `LEGEND_HOOKS`
  # only because the loop above walks the same set.
  LEGEND_HOOKS=4
  EXPECT_KILLS=$(( LEGEND_HOOKS + 2 ))
  if [ "$kills" -eq "$EXPECT_KILLS" ]; then
    ok "legend battery: $kills of $EXPECT_KILLS mutants killed ($LEGEND_HOOKS one-byte, 1 anchor-loss, 1 empty-body)"
  else
    bad "LEGEND BATTERY KILLED $kills OF $EXPECT_KILLS — a mutant that killed nothing is indistinguishable from an arm that cannot fire"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "pause-hook-origin: PASS"; exit 0; fi
echo "pause-hook-origin: $fails assertion(s) FAILED" >&2
exit 1
