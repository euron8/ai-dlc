#!/bin/bash
#
# AI/DLC Artifact-Size Budget Validator (Rule 25)
#
# WHY THIS EXISTS
# Living planning artifacts grow every sprint. Rule 25 has always said so, and
# Rule 25(d) has always had thresholds -- but they were WARN-ONLY and they fired
# at RETRO. That is a ratchet with no pawl: the only mechanism that notices an
# oversized artifact runs at the end of the sprint that already paid for it. Every
# sprint starts a little slower than the last, and nothing ever intervenes in time.
#
# Measured in the reference consumer at sprint 289, in a planning phase that ran
# 3h16m without finishing:
#
#   product-brief.md              480 KB  ~120k tok   2x its 60k threshold
#   pipeline-snapshot.md           50 KB   ~12k tok   2x its  6k threshold
#   pipeline-continuation-log.md  1.3 MB  ~330k tok  33x its 10k threshold
#   context-mode-protection-log   210 KB   ~53k tok   NO threshold existed at all
#
# The snapshot is the expensive one and the reason this runs at GATES too, not
# only at sprint start: the protocol whole-reads it at every gate (Checks 14/15),
# on every resume, and after every compaction (ai-dlc-recover.sh). At 50 KB and 8
# reads it was the single largest byte-injector in the session -- larger than any
# source file -- and the reads it forced are what drove 6 auto-compactions at
# ~33-minute intervals. Rule 23's exemption that lets the gate re-read it whole is
# explicitly "conditional on their staying small, which is not automatic." This
# script is what makes it automatic.
#
# WHAT IT MEASURES
# Bytes / AI_DLC_BYTES_PER_TOKEN for each known living artifact found under the
# project's _bmad-output/ and docs/. The divisor is the same NUMBER
# validate-reattach-budget.sh uses, but NOT the same measurement -- and the
# difference matters in the direction of the error.
#
# THE DIVISOR UNDER-COUNTS ON THIS POPULATION, BY 5-11%.
# validate-reattach-budget.sh calibrated bytes/4 against SKILL.md's recovery
# protocol (17,990 bytes ~= 4,439 tokens -> ~4.05 B/tok) and concluded the divisor
# is "slightly conservative, i.e. it over-counts." That is true OF THAT TEXT. This
# script inherited the sentence and applied it to a different population -- prose-
# heavy planning artifacts -- where the ratio, and therefore the DIRECTION of the
# error, reverses.
#
# Measured at sprint 290 in the reference consumer against a 147,176-byte planning
# artifact with four tokenizers (@anthropic-ai/tokenizer, and tiktoken cl100k_base
# / o200k_base / gpt2): 3.62-3.84 bytes/token, so bytes/4 reports ~5-11% FEWER
# tokens than exist. The same four run against SKILL.md returned 3.94-4.22, which
# brackets 4.05 -- so both statements are correct about their own file, and the
# copied one was never re-measured here.
#
# CAVEAT ON THAT MEASUREMENT: no ground-truth Claude tokenizer was reachable (no
# API key in that environment). All four numbers are proxies -- three OpenAI
# vocabularies, plus Anthropic's own local package, which bundles the older Claude
# 1/2 vocab and not the current family's BPE. They converge within a ~15% band,
# which is why the direction is trustworthy; the exact percentage is not. Anyone
# with `count_tokens` access should re-run it and replace this range.
#
# THE DIVISOR STANDS ANYWAY. 5-11% sits inside the 10% grace band below and changed
# no pass/fail verdict found when it was measured. But it errs toward PASSING, not
# toward tripping early, so do not reason about a near-budget artifact as though the
# estimate were conservative. It is not.
#
# History/archive files are NOT measured. Rule 25(a) makes them write-only -- never
# read in the hot path -- so their growth is free. That is the whole point of
# rotation: product-brief-history.md is 2.6 MB in the reference consumer and costs
# nothing, because nothing reads it.
#
# THE THRESHOLD TABLE LIVES HERE, AND ONLY HERE.
# It used to live in retro.md prose. Two copies of a number is one copy too many:
# retro.md and this script would drift, and the prose copy is the one nobody can
# execute. retro.md now calls this script instead of restating it.
#
# USAGE
#   core/scripts/validate-artifact-budget.sh [--root PATH] [--only NAME]
#                                            [--warn-only] [--quiet]
#
#   --only NAME    check a single artifact by basename (gates use
#                  `--only pipeline-snapshot.md`)
#   --warn-only    report breaches but exit 0 (retro's Rule 25(d) posture: the
#                  sprint is over, blocking it helps nobody)
#
# WARN AT 100%, BLOCK AT 100% + GRACE.
# The grace band is not softness, it is aim. This check exists to stop a RATCHET,
# and a ratchet announces itself in multiples, not percentages: in the reference
# consumer the real breaches were 161%, 215%, 526% and 3311% of budget. A gate that
# also FAILS at 104% buys nothing and costs a lot -- the lead trims 300 tokens, the
# snapshot grows back by the next gate, and it fails again. That treadmill turns a
# real signal into noise, and noisy gates get ignored. So: anything over budget is
# REPORTED (the number is the truth and you should see it), but only a breach past
# the grace band BLOCKS.
#
# ENV OVERRIDES
#   AI_DLC_BYTES_PER_TOKEN   bytes-per-token divisor          (default 4)
#   AI_DLC_BUDGET_GRACE_PCT  block above budget + this %      (default 10)
#   AI_DLC_BUDGET_<NAME>     per-artifact override in tokens, NAME upper-snaked
#                            from the basename: AI_DLC_BUDGET_PRD_MD=90000
#
# EXIT
#   0  nothing past the grace band (over-budget-but-within-grace is reported, not
#      fatal), or --warn-only
#   1  an artifact is past budget + grace, or input unreadable

set -u

BPT="${AI_DLC_BYTES_PER_TOKEN:-4}"
GRACE_PCT="${AI_DLC_BUDGET_GRACE_PCT:-10}"
ROOT="${CLAUDE_PROJECT_DIR:-.}"
ONLY=""
WARN_ONLY=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2:-}"; shift 2 ;;
    --only)      ONLY="${2:-}"; shift 2 ;;
    --warn-only) WARN_ONLY=1; shift ;;
    --quiet)     QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

[ -d "$ROOT" ] || { echo "FAIL: project root not readable: $ROOT" >&2; exit 1; }

# -----------------------------------------------------------------------------
# The canonical Rule 25(d) budgets. Format: basename|tokens|remedy
#
# remedy is the BOUNDING MECHANISM for that artifact's class, not a generic
# "make it smaller" -- the remedies are genuinely different and applying the
# wrong one destroys data:
#
#   consolidate  living planning artifact -> the one-shot, operator-invoked,
#                fidelity-critical rewrite (artifact-consolidation.md). Rule 25(a)
#                moves superseded content to *-history.md; nothing is dropped.
#   rotate       append-only log -> move the epoch to a dated archive (Rule 25(c)).
#                A live log over threshold means a rotation was MISSED, not that it
#                needs a rewrite. artifact-consolidation.md rejects logs as targets.
#   trim         pipeline-snapshot.md -> trim to its 7-section schema (Rule 25(a)).
#                Check 14 owns the schema. It is SEVEN sections since v0.50.0 --
#                In-Flight Teammates is one of them, and it is the ledger that
#                stops the lead re-dispatching live teammates. Do not delete it.
#                Never consolidation. A snapshot over threshold means the schema
#                stopped being enforced at gate passages, and the gates that let it
#                grow are the finding -- not the file.
# -----------------------------------------------------------------------------
BUDGETS="
prd.md|60000|consolidate
product-brief.md|60000|consolidate
carry-over-backlog.md|40000|consolidate
architecture.md|60000|consolidate
gate-log.md|25000|rotate
compaction-log.md|10000|rotate
pipeline-continuation-log.md|10000|rotate
context-mode-protection-log.md|10000|rotate
pipeline-snapshot.md|6000|trim
"

# Rule 25(a): history/archive files are write-only and their growth is free.
# Measuring them would flag a 2.6 MB product-brief-history.md that costs nothing
# and whose whole job is to BE big so the live file is not.
is_archive() {
  case "$1" in
    *-history.md|*-archive.md|*-archive-*.md|*.precompact.md) return 0 ;;
    *) return 1 ;;
  esac
}

# Not a live artifact, however it is named. `architecture.md` is the trap: the
# ai-dlc STEP FILE is also called architecture.md, so a bare basename search finds
# the skill's own source under .claude/skills/ and under every pre-ai-dlc snapshot
# the consumer has ever taken. Measuring a step file against an artifact budget is
# a category error -- it would pass, silently, and teach us nothing.
is_not_artifact() {
  case "$1" in
    */.claude/*|*/pre-ai-dlc/*|*/_divergence/*|*/node_modules/*|*/.git/*) return 0 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# THE SNAPSHOT'S SEVEN-SECTION SCHEMA (gate-validation.md Check 14 owns it).
#
# Check 14 enumerates seven sections to REFRESH. It never said "and no others,"
# and nothing counted them -- so the schema was a REQUIRED-set, not a CLOSED-set.
# An eighth section was invisible to every check until total BYTES breached, and
# by then the remedy text ("trim to its 7-section schema", below) was pointing at
# a schema nothing could evaluate.
#
# Measured in the reference consumer at sprint 296, mid-sprint: the snapshot held
# TEN `## ` sections at 141% of budget. Three were lead invention that no hook, no
# step and no script writes -- `Teammate Ledger (detail)` (5.7 KB), `Discovery
# phase -- CLOSED` (1.9 KB), `Post-compact recovery log` (1.4 KB): 9.0 KB of 34 KB,
# accumulated between gates, undetectable until the byte budget finally tripped.
#
# PREFIX match, not exact. `## In-Flight Teammates (none)` is that section wearing
# a decoration, and failing it would be noise -- and noisy gates get ignored (see
# "WARN AT 100%" above; same reasoning). `## Teammate Ledger (detail)` is not a
# decoration of anything, and fails.
#
# CLOSED-set ONLY -- this deliberately does NOT require all seven to be PRESENT.
# A snapshot is legitimately under-populated between route.md Step 0 and the first
# gate, and this script runs on the BLOCKING sub-step path (_gate-procedures.md
# "Sub-step snapshot update" step 5, "Exit 1 -> TRIM NOW"). A presence rule there
# would stall a pipeline over a snapshot that is merely young. ABSENCE is Check
# 14's to judge, against a snapshot it has just written. INVENTION is this
# script's: it is never legitimate, at any age.
# -----------------------------------------------------------------------------
is_canonical_section() {
  case "$1" in
    "Pipeline Position"*|\
    "Sprint Context"*|\
    "Recent Activity"*|\
    "Open Items"*|\
    "Locked Decisions"*|\
    "In-Flight Teammates"*|\
    "Context Reminders"*) return 0 ;;
    *) return 1 ;;
  esac
}

# $1 = file path, $2 = path relative to ROOT (for the message)
check_snapshot_sections() {
  grep '^## ' "$1" 2>/dev/null \
    | sed -e 's/^##[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | while IFS= read -r heading; do
        [ -n "$heading" ] || continue
        is_canonical_section "$heading" && continue
        printf 'SCHEMA  %-32s unknown section: ## %s\n' "$2" "$heading" >> "$SCHEMA_FILE"
      done
}

env_override() {
  # prd.md -> AI_DLC_BUDGET_PRD_MD
  local key
  key="AI_DLC_BUDGET_$(printf '%s' "$1" | tr '[:lower:].-' '[:upper:]__')"
  eval "printf '%s' \"\${$key:-}\""
}

BREACH=0
CHECKED=0

BREACH_FILE="$ROOT/.ai-dlc-budget-breach.tmp"
SCHEMA_FILE="$ROOT/.ai-dlc-snapshot-schema.tmp"

# Clear both channels BEFORE the scan. A run killed mid-flight leaves its temp
# file behind, and the next run would then report a breach nobody measured. That
# matters more for the schema channel than the byte one: this script blocks the
# sub-step path, so a stale file is a pipeline stall with no artifact behind it.
rm -f "$BREACH_FILE" "$SCHEMA_FILE"

say "bytes/token divisor : ${BPT} (calibrated with validate-reattach-budget.sh; under-counts 5-11% on this population)"
say "project root        : ${ROOT}"
say ""

printf '%s\n' "$BUDGETS" | while IFS='|' read -r name budget remedy; do
  [ -n "$name" ] || continue
  [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue

  ov="$(env_override "$name")"
  [ -z "$ov" ] || budget="$ov"

  # Find every live copy. sprint-status.yaml taught us the reference consumer can
  # hold the SAME artifact at two paths, so measure them all rather than assuming
  # one canonical location.
  find "$ROOT/_bmad-output" "$ROOT/docs" -type f -name "$name" 2>/dev/null | while read -r f; do
    is_archive "$f" && continue
    is_not_artifact "$f" && continue
    bytes="$(wc -c < "$f" | tr -d ' ')"
    tokens=$(( bytes / BPT ))
    rel="${f#"$ROOT"/}"
    ceiling=$(( budget + (budget * GRACE_PCT / 100) ))

    # Schema and budget are INDEPENDENT verdicts. An in-budget snapshot can still
    # carry an invented section (that is how the 296 one started), and the point
    # of checking here is to catch it while it is still cheap.
    [ "$name" = "pipeline-snapshot.md" ] && check_snapshot_sections "$f" "$rel"

    if [ "$tokens" -gt "$ceiling" ]; then
      over=$(( tokens * 100 / budget ))
      printf 'OVER  %-32s %7s tok  (budget %6s, %s%% of it)  -> %s\n' \
        "$rel" "$tokens" "$budget" "$over" "$remedy" >> "$ROOT/.ai-dlc-budget-breach.tmp"
    elif [ "$tokens" -gt "$budget" ]; then
      # Over budget but inside the grace band. Say so -- the number is the truth --
      # but do not block: see "WARN AT 100%, BLOCK AT 100% + GRACE" in the header.
      over=$(( tokens * 100 / budget ))
      printf 'warn  %-32s %7s tok  (budget %6s, %s%% — within %s%% grace)  -> %s soon\n' \
        "$rel" "$tokens" "$budget" "$over" "$GRACE_PCT" "$remedy"
    else
      [ "$QUIET" -eq 1 ] || printf '  ok  %-32s %7s tok  (budget %6s)\n' "$rel" "$tokens" "$budget"
    fi
  done
done

# The `while` above runs in a subshell (pipe), so BREACH cannot escape it. The
# temp file is the channel. Deliberate: rewriting this as a process-substitution
# loop is a bashism and install.sh targets /bin/bash but consumers have run this
# under sh before.
RC=0
if [ -s "$BREACH_FILE" ]; then
  BREACH=$(wc -l < "$BREACH_FILE" | tr -d ' ')
  say ""
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "WARN: ${BREACH} artifact(s) over the Rule 25(d) budget."
  else
    echo "FAIL: ${BREACH} artifact(s) over the Rule 25(d) budget." >&2
  fi
  cat "$BREACH_FILE" >&2
  cat >&2 <<'EOF'

      Every read of an over-budget artifact is context the pipeline does not get
      back, and the reads compound: the snapshot alone is whole-read at every gate,
      on every resume, and after every compaction.

      Remedies (they are NOT interchangeable):
        consolidate -> artifact-consolidation.md. Operator-invoked, fidelity-critical.
        rotate      -> a rotation was MISSED. Move the epoch to a dated archive
                       (Rule 25(c)); never rewrite a log.
        trim        -> trim pipeline-snapshot.md to its 7-section schema (gate-validation
                       Check 14 owns it). The gates that let it grow past 6k are the
                       finding, not the file. NOTE: In-Flight Teammates is one of the
                       seven -- it is the dispatch ledger, and deleting it is how a lead
                       re-dispatches a teammate that is still alive.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$BREACH_FILE"

# Reported SEPARATELY from the byte budget, and never folded into that count: an
# invented section is not "over the Rule 25(d) budget", and saying so would send
# the lead to the wrong remedy. Trimming bytes out of a section that should not
# exist is how 9 KB of invention survives a trim.
if [ -s "$SCHEMA_FILE" ]; then
  say ""
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "WARN: pipeline-snapshot.md carries section(s) outside its seven-section schema."
  else
    echo "FAIL: pipeline-snapshot.md carries section(s) outside its seven-section schema." >&2
  fi
  cat "$SCHEMA_FILE" >&2
  cat >&2 <<'EOF'

      The seven sections are Pipeline Position, Sprint Context, Recent Activity,
      Open Items, Locked Decisions, In-Flight Teammates, Context Reminders.
      gate-validation.md Check 14 defines them; nothing else may be added.

      Remedy: move each unknown section verbatim to pipeline-snapshot-history.md
      (write-only, Rule 25(a)) and delete it here. Do NOT fold its content into one
      of the seven -- that keeps the bytes and loses the finding.

      A section nothing in core writes is a section nothing in core reads. It is
      not recovered after compaction, not consumed at any gate, and not part of the
      handoff contract -- it is context the pipeline pays for on every whole-read
      and never spends.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$SCHEMA_FILE"

if [ "$RC" -eq 0 ]; then
  say ""
  say "PASS  every measured living artifact is within its Rule 25(d) budget."
fi
exit "$RC"
