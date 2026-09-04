#!/bin/bash
#
# AI/DLC Post-Compact Re-attach Budget Validator
#
# Claude Code re-attaches only the first ~5,000 tokens of an invoked SKILL.md
# after a compaction. The POST-COMPACT RECOVERY PROTOCOL — the section that
# tells a just-compacted lead what to do (read the snapshot, acknowledge, run
# the verification turn) — MUST fall entirely inside that window, or the very
# instructions for recovering from a compaction are the ones a compaction drops.
#
# This happened once (v0.35.0): the protocol began at ~4,834 tokens and ran ~566
# long, so ~400 tokens of it were themselves discarded. The fix moved the handoff
# triggers / thresholds / auto-compact prose BELOW the protocol; the protocol then
# ended at ~4,439 tokens with ~561 tokens of slack. `retro.md`'s self-check asserts
# this at retro time, but nothing caught it at commit time — a single edit ABOVE
# the protocol could silently push its tail past 5,000 between retros. This script
# is that commit-time guard.
#
# WHAT IT MEASURES. Bytes from the start of SKILL.md through the END of the
# `## POST-COMPACT RECOVERY PROTOCOL` section (the line before the next `## `
# heading, whatever it happens to be — the protocol now sits directly above
# `## AUTONOMY RULES`, near the top of the file, and the end boundary is
# derived rather than named so a later reorder cannot silently mis-measure).
# Bytes are converted to an estimated token count at a ratio
# calibrated against the v0.35.0 measurement (17,990 bytes ≈ 4,439 tokens by
# Claude's own tokenizer → ~4.05 bytes/token; the default divisor 4 is slightly
# conservative, i.e. it over-counts tokens). The check FAILS if the estimate
# exceeds the budget minus a safety margin, so it trips BEFORE the real 5,000
# cliff, leaving room for tokenizer variance.
#
# THAT RATIO IS A PROPERTY OF THIS TEXT, NOT OF THE DIVISOR. Do not carry the
# "slightly conservative" conclusion to another population without re-measuring it:
# the ratio is content-dependent and the DIRECTION of the error reverses. Prose-heavy
# planning artifacts measure 3.62-3.84 bytes/token, where bytes/4 UNDER-counts by
# 5-11% — the opposite of the sentence above. validate-artifact-budget.sh copied this
# conclusion to exactly that population and carried it backwards for four releases;
# its header now documents the reversal. Same divisor, same number, opposite error.
#
# USAGE
#   core/scripts/validate-reattach-budget.sh [--skill PATH] [--quiet]
#
# ENV OVERRIDES
#   AI_DLC_REATTACH_BUDGET   re-attach window in tokens          (default 5000)
#   AI_DLC_REATTACH_MARGIN   safety margin below the window      (default 250)
#   AI_DLC_BYTES_PER_TOKEN   bytes-per-token divisor             (default 4)
#
# EXIT
#   0  protocol end is within (budget - margin)
#   1  protocol end exceeds the ceiling, an anchor is missing, or input unreadable

set -u

BUDGET="${AI_DLC_REATTACH_BUDGET:-5000}"
MARGIN="${AI_DLC_REATTACH_MARGIN:-250}"
BPT="${AI_DLC_BYTES_PER_TOKEN:-4}"

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

PROJECT_DIR="$AI_DLC_ROOT"
SKILL_MD="${PROJECT_DIR}/.claude/skills/ai-dlc/SKILL.md"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL_MD="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ ! -f "$SKILL_MD" ]; then
  echo "FAIL: cannot read SKILL.md -- no such file: $SKILL_MD" >&2
  exit 1
fi

CEILING=$(( BUDGET - MARGIN ))

# -----------------------------------------------------------------------------
# Anchors. The critical section is `## POST-COMPACT RECOVERY PROTOCOL`; its end
# is the line before the next top-level `## ` heading. Both must be present and
# in order, or the structure moved and the measurement is undefined -> FAIL.
# -----------------------------------------------------------------------------
START_LINE="$(grep -n '^## POST-COMPACT RECOVERY PROTOCOL' "$SKILL_MD" | head -1 | cut -d: -f1)"
if [ -z "$START_LINE" ]; then
  echo "FAIL: '## POST-COMPACT RECOVERY PROTOCOL' heading not found in $SKILL_MD." >&2
  echo "      The critical section was renamed or removed; re-measure before shipping." >&2
  exit 1
fi

# First top-level heading strictly after the protocol heading = its end boundary.
END_LINE="$(awk -v s="$START_LINE" 'NR>s && /^## / { print NR; exit }' "$SKILL_MD")"
if [ -z "$END_LINE" ]; then
  echo "FAIL: no '## ' section found after the POST-COMPACT RECOVERY PROTOCOL." >&2
  echo "      Cannot bound the protocol; re-measure before shipping." >&2
  exit 1
fi

# Bytes from file start through the last line of the protocol (END_LINE - 1).
PROTO_END=$(( END_LINE - 1 ))
BYTES="$(head -n "$PROTO_END" "$SKILL_MD" | wc -c | tr -d ' ')"
EST_TOKENS=$(( BYTES / BPT ))
# Slack is measured against the ceiling that actually FAILS this script, not
# against the raw window. Reporting it against BUDGET overstates the headroom by
# exactly MARGIN, and a reader budgeting the next addition against the larger
# figure spends a margin that is not there: at 4747 tokens the honest headroom is
# 3, and the old message read "253 tokens of slack".
SLACK=$(( CEILING - EST_TOKENS ))

say "re-attach window    : ${BUDGET} tokens (Claude Code re-attaches the first ~${BUDGET})"
say "safety margin       : ${MARGIN} tokens  (ceiling ${CEILING})"
say "protocol section    : lines ${START_LINE}..${PROTO_END}"
say "protocol end offset : ${BYTES} bytes ~= ${EST_TOKENS} tokens (at ${BPT} bytes/token)"
say ""

if [ "$EST_TOKENS" -gt "$CEILING" ]; then
  echo "FAIL: POST-COMPACT RECOVERY PROTOCOL ends at ~${EST_TOKENS} tokens, past the" >&2
  echo "      ${CEILING}-token ceiling (${BUDGET} re-attach window - ${MARGIN} margin)." >&2
  echo "      Content ABOVE the protocol grew and is pushing its tail toward the 5K" >&2
  echo "      cliff, where a compaction would drop the recovery instructions." >&2
  echo "      Fix: move non-critical prose BELOW the protocol (into the HANDOFF" >&2
  echo "      TRIGGERS section) or relocate rationale out of the resident region." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# The protocol must carry the ESCAPE from the window it lives in.
# -----------------------------------------------------------------------------
# Keeping the protocol inside the re-attach window is half the guarantee. The
# other half is what the protocol SAYS once it arrives, and the arm above cannot
# see it: a protocol that fits perfectly and never tells the lead to recover the
# rest of the file passes this script with room to spare.
#
# Measured over the reference consumer's 379 transcripts: 69 hold a
# `compact_boundary`, and 261 post-boundary records carry a real skill re-attach.
# The cut sits at 20,121 bytes in every one of them -- identical at p10, p25,
# p50, p75 and p90, so the harness truncates deterministically, and the ~5,000
# figure this script has assumed since v0.35.0 is confirmed rather than drifted.
# What that means for the lead is the part nobody had measured: it keeps under a
# QUARTER of SKILL.md. Most of the numbered rules, the handoff triggers and the
# snapshot schema are simply absent, INCLUDING the rules that mandate re-reading
# -- so the instruction to recover them cannot come from a rule the lead still
# holds. It has to be in the protocol, which is why this arm exists.
#
# The old text made it worse than absent: it told the lead to ask the OPERATOR to
# re-invoke `/ai-dlc`, gated on the lead first NOTICING rules were missing. A lead
# cannot notice a rule it has never seen, and nothing marks where the cut fell.
#
# THE RECOVERY READ IS NOW THE DIGEST, AND THIS ARM MOVED WITH IT. `IN FULL` against
# SKILL.md was the mandate until the cost of obeying it was measured: SKILL.md is ~102 KB,
# `Read` results were 51.5% of all conversation content across the reference consumer's
# sprint 305, and SKILL.md alone was 15.3% over 27 compactions. A 102 KB re-read is what
# brings the NEXT compaction closer, so the instruction that recovered the rulebook was
# also the instruction that destroyed it again -- and it was skipped accordingly.
# `core/skills/ai-dlc/postcompact-digest.md` is a mechanical SELECTION of SKILL.md's own
# bytes past the cut, rendered by scripts/render-postcompact-digest.sh and byte-compared at
# pre-push, so it cannot say anything SKILL.md does not.
#
# BOTH PATHS ARE STILL REQUIRED, and that is the point of the pair rather than a leftover.
# The digest is an INDEX: it establishes that a rule exists and what it governs, which is
# the failure the full-read mandate existed to prevent. It is NOT enough to apply a rule, so
# the protocol must also name SKILL.md as where the full text lives. A protocol that named
# only the digest would hand the lead a list of rule titles and let it act on them, which is
# a worse failure than the one this arm started with -- the lead reads the title and believes
# it holds the rule. Either path alone is also satisfiable by prose that instructs nothing.
PROTO_TEXT="$(sed -n "${START_LINE},${PROTO_END}p" "$SKILL_MD")"
if ! grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$PROTO_TEXT" \
   || ! grep -q '\.claude/skills/ai-dlc/postcompact-digest\.md' <<<"$PROTO_TEXT"; then
  echo "FAIL: the POST-COMPACT RECOVERY PROTOCOL does not tell the lead how to recover" >&2
  echo "      its rulebook. Expected both '.claude/skills/ai-dlc/postcompact-digest.md'" >&2
  echo "      (the mandated recovery Read) and '.claude/skills/ai-dlc/SKILL.md' (where a" >&2
  echo "      rule's full text lives) inside lines ${START_LINE}..${PROTO_END}; found" >&2
  echo "      digest=$(grep -c '\.claude/skills/ai-dlc/postcompact-digest\.md' <<<"$PROTO_TEXT") skill=$(grep -c '\.claude/skills/ai-dlc/SKILL\.md' <<<"$PROTO_TEXT")." >&2
  echo "      A compaction keeps under a quarter of this file and marks nothing, so a" >&2
  echo "      lead that is not told to Read the rest runs the sprint on whatever" >&2
  echo "      survived and reports no problem -- a rule it never saw is" >&2
  echo "      indistinguishable from a rule that does not exist." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# The protocol must send an UN-ROUTED session to the router, not past it.
# -----------------------------------------------------------------------------
# The protocol sits at the top of the file and INITIALIZATION -- "READ AND FOLLOW
# steps/route.md", unconditional -- sits at the bottom. A session whose first input is
# `/ai-dlc resume` loads the whole file, reads this section as its resume procedure, obeys
# "proceed to the next pipeline action", never reads the router, and is denied its first
# write by ai-dlc-acknowledge.sh Check 2z -- whose remedy is exactly the Read this section
# did not name. Step 0a's six snapshot integrity checks are skipped on the same path.
#
# Measured on the reference consumer (PC-S308-POST-COMPACT-RECOVERY-PROTOCOL-SKIPS-ROUTE-MD):
# 10 of 41 `/ai-dlc resume` sessions over two days were denied before ever reading the
# router, every one of them having read the snapshot first; 0 of 51 sessions that actually
# COMPACTED were denied after the summary, because their transcript already carried the
# Read. The population is the fresh resume, not the compaction this protocol is named for.
#
# The arm requires the router's INSTALLED path inside the section -- the same key the deny's
# own remedy names -- outside an HTML comment. A protocol that mentions `route.md` bare, or
# only inside a comment, is one the lead can obey without reading anything.
#
# COMMENTS ARE STRIPPED BY A STATE MACHINE, NOT BY `sed 's/<!--.*-->//'`. That sed handles a
# comment that opens and closes on one line, and 18 of the 20 HTML comments in this very file
# span lines -- so a path parked inside the house-style comment would have passed. The greedy
# `.*` also ate a LIVE path bracketed by two comments on one line. The scanner below carries
# comment state across lines and removes exactly the commented spans.
strip_html_comments() {
  awk '{
    line = $0; out = ""
    while (1) {
      if (inc) {
        p = index(line, "-->")
        if (p == 0) { line = ""; break }
        line = substr(line, p + 3); inc = 0
      } else {
        p = index(line, "<!--")
        if (p == 0) { out = out line; break }
        out = out substr(line, 1, p - 1); line = substr(line, p + 4); inc = 1
      }
    }
    print out
  }'
}
PROTO_LIVE="$(strip_html_comments <<<"$PROTO_TEXT")"
if ! grep -q '\.claude/skills/ai-dlc/steps/route\.md' <<<"$PROTO_LIVE"; then
  echo "FAIL: the POST-COMPACT RECOVERY PROTOCOL does not send an un-routed session to the" >&2
  echo "      router. Expected '.claude/skills/ai-dlc/steps/route.md' inside lines" >&2
  echo "      ${START_LINE}..${PROTO_END}, outside any HTML comment; found $(grep -c '\.claude/skills/ai-dlc/steps/route\.md' <<<"$PROTO_LIVE")." >&2
  echo "      A session started with '/ai-dlc resume' reads this section as its resume" >&2
  echo "      procedure, and INITIALIZATION's unconditional router Read sits far below it." >&2
  echo "      Without the path here the lead proceeds un-routed, skips Step 0a, and" >&2
  echo "      ai-dlc-acknowledge.sh denies its first write." >&2
  exit 1
fi

say "PASS  protocol ends at ~${EST_TOKENS} tokens; ${SLACK} tokens of slack under the ${CEILING}-token ceiling (${BUDGET} window - ${MARGIN} margin)."
say "      protocol names the digest to recover from, SKILL.md for full rule text, and the router for an un-routed session."
exit 0
