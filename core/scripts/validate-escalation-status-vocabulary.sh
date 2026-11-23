#!/usr/bin/env bash
# validate-escalation-status-vocabulary.sh — an escalation's Status token must be in the
# closed set escalations.md publishes. Anything else fails closed.
#
# WHY THIS EXISTS
# gate-validation.md Check 2 is three branches with no else. It blocks on HARD_BLOCK,
# passes over DECIDED_AUTONOMOUSLY as informational, and scopes DEFERRAL_REQUEST to the
# deferred item. An entry whose status is none of those satisfies no branch: Check 2 does
# not block on it, does not surface it, and does not record it. It is silently skipped.
#
# The failure is not a wrong verdict — it is an entry no verdict was ever computed for, and
# the gate reports Check 2 as passing either way. That is the check-that-cannot-fire class:
# a PASS byte-identical to never having examined anything.
#
# Measured on the reference consumer: docs/escalations/pending.md carried 8 entries on
# tokens core never defined (FILED x5, OPEN x3), accumulated across the sprints they were
# written in, and every gate in that window reported Check 2 passing.
#
# WHY IT DERIVES THE SET INSTEAD OF LISTING IT
# A hand-listed copy of a published set is the defect this repo keeps finding (the
# Invariant-3 `uni` array, apply.sh's private consumer_path table). So the vocabulary is
# read from escalations.md itself, from the two lines that publish it:
#
#   1. the `**Status:**` line inside the entry-format code block  — authorship tokens
#   2. the `**Terminal statuses**` line beneath it                — resolution tokens
#
# Every token lives in exactly one of them. Adding a token to the pipeline means editing
# escalations.md, which is the correct place for it to be a visible decision.
#
# If escalations.md cannot be found or neither line parses, this script REFUSES (exit 2)
# rather than falling back to a built-in set. A validator that guesses its own vocabulary
# when it cannot read the source has reintroduced the hand-listed copy, silently.
#
# SCOPE. Every `**Status:**` entry in the file, regardless of sprint. Deliberately wider
# than validate-escalation-resolution.sh, which scopes to the current sprint because it
# verifies citations against THIS session's transcript. A malformed token is malformed
# whenever it was written, and the drift this catches accumulates precisely in the entries
# old enough that nobody re-reads them.
#
# ORTHOGONAL TO Check 2a. validate-escalation-resolution.sh asserts that a
# RESOLVED/OVERRIDDEN HARD_BLOCK cites a verified operator message. It parses the status
# token only to SELECT entries and never validates it against the published set. This is
# the second, cheaper arm beside it.
#
# USAGE
#   validate-escalation-status-vocabulary.sh [--open] <pending.md> [escalations.md]
#
#   --open  also reports every entry whose winning Status is not terminal (the
#           `**Terminal statuses**` line). Entries on a status Check 2 acts on (HARD_BLOCK, then
#           DEFERRAL_REQUEST; see ACTED_ON below) print `L<first>-<last> <header>` plus the body.
#           Any other open status prints one `OPEN-UNACTED <STATUS> <n>` line; a statusless entry
#           prints `L<first>-<last> <header>` under `STATUSLESS-OPEN:`. Then `OPEN <k> of <m>`.
#           Bodies stop at ~12000 bytes in total; an acted-on header is never dropped, and each
#           body over budget gets its own `TRUNCATED read lines X-Y` line.
#           The vocabulary FAIL is unchanged. gate-validation.md Check 2 reads this instead
#           of Reading pending.md whole.
#
# EXIT
#   0  every Status token is in the derived vocabulary (or the escalations file is absent or holds nothing)
#   1  at least one entry carries an out-of-vocabulary Status token
#   2  bad arguments, or the vocabulary source could not be read — see above, this is a
#      refusal, not a pass; or the escalations path exists but is not a regular file, or
#      could not be read (`REFUSED:` on stderr)
#
# The whole program is esv_main, so a fixture can SOURCE this file and call it in process; nothing above
# the guard at the end runs in the sourcing shell except that definition. The script's own directory is
# read through BASH_SOURCE[0], never $0, which in a sourcing shell names the caller.
esv_main() {
set -u

ESV_OPEN=0
if [ "${1:-}" = "--open" ]; then ESV_OPEN=1; shift; fi
ESCALATIONS="${1:-}"
if [ -z "$ESCALATIONS" ]; then
  echo "FAIL: usage: validate-escalation-status-vocabulary.sh [--open] <pending.md> [escalations.md]" >&2
  exit 2
fi

# ---- 1. Locate the vocabulary source ---------------------------------------
ES_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

ES_ROOT="$AI_DLC_ROOT"
SPEC="${2:-${AI_DLC_ESCALATIONS_MD:-}}"
if [ -z "$SPEC" ]; then
  for cand in \
      "$ES_ROOT/core/skills/ai-dlc/escalations.md" \
      "$ES_ROOT/.claude/skills/ai-dlc/escalations.md" \
      "$ES_SCRIPT_DIR/../skills/ai-dlc/escalations.md"; do
    [ -f "$cand" ] && { SPEC="$cand"; break; }
  done
fi
if [ -z "$SPEC" ] || [ ! -f "$SPEC" ]; then
  echo "FAIL: escalations.md not found. The status vocabulary is DERIVED from it; this" >&2
  echo "      validator has no built-in set and will not guess. Reinstall ai-dlc." >&2
  exit 2
fi

# ---- 2. Derive the closed set ----------------------------------------------
# Both source lines carry their tokens as a `|`-separated run of ALL-CAPS words. Take the
# text after the label, strip backticks, and keep every [A-Z_] word.
VOCAB="$(awk '
  /^\*\*Status:\*\*/ || /^\*\*Terminal statuses\*\*/ {
    s = $0
    sub(/^[^:]*:[[:space:]]*/, "", s)
    gsub(/`/, "", s)
    n = split(s, parts, /[|]/)
    for (i = 1; i <= n; i++) {
      t = parts[i]
      gsub(/[^A-Z_]/, "", t)
      if (t != "") print t
    }
  }
' "$SPEC" | sort -u)"

# Two lines, so fewer than two distinct tokens means a parse failure, not a small
# vocabulary. Refuse rather than validate against a set that lost most of itself.
if [ "$(printf '%s\n' "$VOCAB" | grep -c .)" -lt 2 ]; then
  echo "FAIL: could not derive the status vocabulary from $SPEC." >&2
  echo "      Expected a '**Status:**' line and a '**Terminal statuses**' line; got:" >&2
  printf '        %s\n' ${VOCAB:-"(nothing)"} >&2
  echo "      Refusing to validate against a set this script did not read." >&2
  exit 2
fi

# A path that EXISTS but is not a regular file is not the absent state. A directory, a
# fifo, or a symlink whose target is gone all fail `-f` and would otherwise take the
# no-file branch below and print a line Check 2 reads as a pass. `-L` is tested beside
# `-e` because a dangling symlink fails `-e` too.
if { [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; } && [ ! -f "$ESCALATIONS" ]; then
  echo "REFUSED: escalations path $ESCALATIONS exists but is not a regular file; nothing was examined." >&2
  exit 2
fi
# No escalations file is a legitimate clean state — nothing to adjudicate.
[ -f "$ESCALATIONS" ] || {
  echo "OK: EXAMINED NOTHING — no escalations file ($ESCALATIONS); nothing to check."
  exit 0
}
# A file holding no non-whitespace byte is the same state as no file, and says so. Keyed on
# the BYTES, not on zero parsed records: a populated file whose entries this parser cannot
# read (no `**Status:**` field at all) is a grammar failure, not an empty corpus, and must
# keep its `n=[]` line. `grep` exits 1 only when it read the file and matched nothing.
# Status 2 REFUSES: the file could not be read, and every later read of it would fail the
# same way and be swallowed, so the run would print an ordinary `n=[]` line over entries it
# never saw. Unreadable is decided by the mode bit AND the status together, so a caller that
# CAN read a mode-000 file (root) is not refused on the bit alone.
grep -q '[^[:space:]]' "$ESCALATIONS" 2>/dev/null
ESC_BLANK_RC=$?
if [ "$ESC_BLANK_RC" -eq 1 ]; then
  echo "OK: EXAMINED NOTHING — escalations file present but empty ($ESCALATIONS); nothing to check."
  exit 0
fi
if [ "$ESC_BLANK_RC" -gt 1 ]; then
  if [ ! -r "$ESCALATIONS" ]; then
    echo "REFUSED: escalations file $ESCALATIONS could not be read; nothing was examined." >&2
  else
    echo "REFUSED: reading escalations file $ESCALATIONS failed (grep exited $ESC_BLANK_RC); nothing was examined." >&2
  fi
  exit 2
fi

# ---- 3. Extract one <header>\t<STATUS> record per entry ---------------------
# Same flush-on-header / first-ALL-CAPS-word-after-label idiom as the awk Status block in
# validate-escalation-resolution.sh:272. The Status field is matched anywhere in the entry,
# not only at line start: a token in a non-canonical position is exactly the one a naive
# line-anchored regex misses, and it is no less invisible to Check 2 for being there.
#
# WHICH OCCURRENCE WINS: THE LAST CANONICAL ONE IF THE ENTRY HAS ANY, ELSE THE LAST ANYWHERE.
# A canonical occurrence is one that OPENS its line — that is what a field is. This rule is
# not the obvious one, and three simpler readings each fail a property the others satisfy:
#
#   (a) An APPENDED resolution status must be the token adjudicated. escalations.md:18
#       prescribes "**Escalation entry format (append, do not overwrite):**", so the
#       entry's live status is its LAST field, never its first. A first-wins tie-break
#       adjudicates the token the resolution replaced, which is how the validator whose
#       whole job is rejecting an out-of-vocabulary status came to report PASS on one.
#   (b) A `**Status:**` inside PROSE ABOVE the real field must not outrank the field.
#       First-wins plus a match-anywhere pattern makes prose SHIELD the field it precedes:
#       the widening at the top of this comment was written to catch a case it instead
#       created.
#   (d) A `**Status:**` inside PROSE BELOW the real field must not outrank it either.
#       This is (b) mirrored and it is the one a bare last-wins reading gets wrong. Not
#       hypothetical: the reference consumer's pending.md carries an entry whose field
#       reads DECIDED_AUTONOMOUSLY and whose body four lines down reads "carried NO
#       `**Status:**` line from filing until 2026-07-20. It therefore matched no branch".
#       Last-match-anywhere extracts the token `I` from "It therefore" and emits a FALSE
#       FINDING on the file the gate actually reads.
#   (M) A `**Status:**` NOT at line start must STILL be adjudicated when it is all the
#       entry has. Ten entries in the reference consumer's archive carry their only status
#       that way, including three HARD_BLOCKs and one token this script already reports.
#       Anchoring the match to line start goes silent on every one of them, which is a
#       coverage REGRESSION dressed as a fix, and it reds
#       core/fixtures/escalation-status-vocabulary/run.sh's mid-entry assertion.
#
# The canon flag is what lets one pass satisfy all four: once a field-shaped occurrence has
# been seen, prose can no longer displace it in EITHER direction, and an entry that never
# had one still gets adjudicated on what it does have.
#
# FALSE POSITIVES, measured before this shipped, on the reference consumer's live corpus
# read-only: pending.md 0 findings before and 0 after (control: 134 `**Status:**` fields in
# that file, an impossible token 0). pending-archive.md 35 findings before and 48 after,
# and the 35 are a strict SUBSET of the 48 — this reading loses no finding the previous one
# made. Last-anywhere scores 1 on pending.md, and that one is the `I` above.
# ENTRY DEFINITION (fail-closed): an ENTRY is a `## ` header whose text carries a YYYY-MM-DD date; an undated
# `## ` header is a SECTION header and is exempt; `### ` headers belong to the entry above them. An entry with
# no Status field in its header-to-next-`## ` span (any `### ` block under it included) is STATUSLESS, which is
# out of vocabulary. The awk prints `R<TAB>header<TAB>status` per status and `S<TAB>line<TAB>header` per
# statusless entry.
RECORDS="$(awk '
  function flush() {
    if (header != "" && status != "") printf "R\t%s\t%s\n", header, status
  }
  function endentry(last) {
    if (ehdr != "" && !ehas) printf "S\t%d\t%s\n", eline, ehdr
    if (open && ehdr != "") printf "E\t%d\t%d\t%s\t%s\n", eline, last, (estat == "" ? "-" : estat), ehdr
  }
  /^#{2,3} / {
    flush(); header = $0; status = ""; canon = 0
    if ($0 ~ /^## /) {
      endentry(NR - 1); ehdr = ""; ehas = 0; estat = ""; ecanon = 0
      if ($0 ~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { ehdr = $0; eline = NR }
    }
    next
  }
  /\*\*[Ss]tatus:\*\*/ {
    # A prose mention cannot displace a field, in either direction.
    if (canon && $0 !~ /^\*\*[Ss]tatus:\*\*/) next
    s = $0
    sub(/^.*\*\*[Ss]tatus:\*\*[[:space:]]*/, "", s)
    if (match(s, /[A-Z_]+/)) {
      status = substr(s, RSTART, RLENGTH)
      ehas = 1
      if (!(ecanon && $0 !~ /^\*\*[Ss]tatus:\*\*/)) estat = status
      if ($0 ~ /^\*\*[Ss]tatus:\*\*/) ecanon = 1
      if ($0 ~ /^\*\*[Ss]tatus:\*\*/) canon = 1
    }
    next
  }
  END { flush(); endentry(NR) }
' open="$ESV_OPEN" "$ESCALATIONS")"

if [ -z "$RECORDS" ]; then
  echo "OK: n=[] no **Status:** entries found in $ESCALATIONS."
  exit 0
fi

# ---- 4. Compare ------------------------------------------------------------
bad=0
n=0
nostatus=0
while IFS="$(printf '\t')" read -r kind a b; do
  if [ "$kind" = "E" ]; then continue; fi
  if [ "$kind" = "S" ]; then
    nostatus=$((nostatus + 1))
    echo "FAIL: STATUSLESS $ESCALATIONS:$a $b"
    continue
  fi
  header="$a"; status="$b"
  [ -n "${status:-}" ] || continue
  n=$((n + 1))
  if ! grep -qx "$status" <<<"$VOCAB"; then
    bad=$((bad + 1))
    echo "FAIL: out-of-vocabulary status '$status'" >&2
    echo "      entry: $header" >&2
    echo "      Check 2 branches on the published set and has no else, so this entry is" >&2
    echo "      neither blocked, surfaced nor recorded — no verdict is computed for it." >&2
  fi
done <<EOF
$RECORDS
EOF

if [ "$ESV_OPEN" -eq 1 ]; then
  TERMINAL="$(awk '/^\*\*Terminal statuses\*\*/ { s = $0; sub(/^[^:]*:[[:space:]]*/, "", s); gsub(/`/, "", s)
    k = split(s, p, /[|]/); for (i = 1; i <= k; i++) { t = p[i]; gsub(/[^A-Z_]/, "", t); if (t != "") print t } }' "$SPEC")"
  # ACTED_ON: the statuses whose entry BODIES gate-validation.md Check 2 branches on -- HARD_BLOCK (the blocking
  # clause) and DEFERRAL_REQUEST (the reopen-signal and deferred-item branches). escalations.md does not mark the
  # set, so it is stated here once; DECIDED_AUTONOMOUSLY and OPERATOR_DECISION are informational there and
  # SUPPRESSED is adjudicated by validate-suppression-lifetime.sh and is terminal, so --open skips it. The two informational statuses are counted, not printed.
  ACTED_ON="HARD_BLOCK DEFERRAL_REQUEST"
  open_n=0; all_n=0; budget=12000; trunc_n=0; trunc_list=""; unacted=""; statusless_list=""
  for want in $ACTED_ON; do
    while IFS="$(printf '\t')" read -r kind a b c d; do
      [ "$kind" = "E" ] || continue
      [ "$c" = "$want" ] || continue
      if grep -qx "$c" <<<"$TERMINAL"; then continue; fi
      printf 'L%s-%s %s\n' "$a" "$b" "$d"
      body="$(sed -n "$((a + 1)),${b}p" "$ESCALATIONS")"
      len=${#body}
      if [ "$len" -le "$budget" ]; then
        budget=$((budget - len)); printf '%s\n' "$body"
      else
        trunc_n=$((trunc_n + 1)); trunc_list="${trunc_list}TRUNCATED read lines $a-$b
"
      fi
    done <<EOF
$RECORDS
EOF
  done
  while IFS="$(printf '\t')" read -r kind a b c d; do
    [ "$kind" = "E" ] || continue
    all_n=$((all_n + 1))
    if grep -qx "$c" <<<"$TERMINAL"; then continue; fi
    open_n=$((open_n + 1))
    case " $ACTED_ON " in *" $c "*) continue ;; esac
    if [ "$c" = "-" ]; then
      statusless_list="${statusless_list}L$a-$b $d
"
    else
      unacted="${unacted}${c}
"
    fi
  done <<EOF
$RECORDS
EOF
  [ -z "$statusless_list" ] || printf 'STATUSLESS-OPEN:\n%s' "$statusless_list"
  if [ -n "$unacted" ]; then
    awk 'NF { if (!($0 in c)) o[++n] = $0; c[$0]++ } END { for (i = 1; i <= n; i++) print "OPEN-UNACTED " o[i] " " c[o[i]] }' <<<"$unacted"
  fi
  [ "$trunc_n" -eq 0 ] || { echo "TRUNCATED $trunc_n body(ies); each range below is one entry:"; printf '%s' "$trunc_list"; }
  echo "OPEN $open_n of $all_n"
fi

if [ "$nostatus" -gt 0 ]; then
  echo "FAIL: $nostatus dated escalation entries carry no **Status:** field (STATUSLESS-ENTRY, fail-closed): no status is outside the closed set." >&2
  echo "FAIL: remedy: add the field, or drop the date from a header that is a section and not an entry." >&2
  exit 1
fi

if [ "$bad" -gt 0 ]; then
  echo "FAIL: $bad of $n escalation entries carry a status outside the closed set." >&2
  echo "      Vocabulary derived from $SPEC: $(printf '%s ' $VOCAB)" >&2
  echo "      Either correct the entry, or add the token to escalations.md and teach" >&2
  echo "      Check 2 how to branch on it. A token Check 2 cannot branch on is a silent skip." >&2
  exit 1
fi

echo "OK: n=$n all escalation status tokens are in the derived set ($(printf '%s ' $VOCAB))."
exit 0
}
# Executed, it runs; sourced, it has defined esv_main and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
esv_main "$@"
