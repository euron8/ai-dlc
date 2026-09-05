#!/usr/bin/env bash
# validate-suppression-lifetime.sh — an operator's permission to proceed past a failing
# check has a lifetime, and a terminal entry may not close a check that is still red.
#
# WHY THIS EXISTS, AND WHY IT IS NOT THE MECHANISM THAT WAS FIRST SPECIFIED
# `RESOLVED` and `OVERRIDDEN` close a QUESTION. Neither closes a CHECK, and neither names
# one. Measured on the reference consumer: a `hard_block: true` check failed at two
# consecutive planning gates and the pipeline proceeded past both of them on a SINGLE
# operator turn, each passage recorded in the gate log as "carried forward, none
# re-litigated".
#
# The obvious diagnosis — "the check went silent and nothing re-ran it" — was measured and
# is FALSE. Both affected checks were emitted at all three of that sprint's planning gates
# and read FAIL, FAIL, PASS. The check re-ran every time and re-reported its failure; the
# metrics carry all three verdicts. What was reused was the AUTHORIZATION.
#
# That is why this script bounds the licence and not the check. An expiry that "forces the
# check to re-run" would be a no-op against the only corpus available, because the check
# never stopped running. What expires here is the operator's permission to walk past a
# verdict that is still red.
#
# THE VERDICT IS RE-READ, NEVER ASSUMED
# A suppression past its expiry is only a failure if the named check is STILL failing. The
# check's own recorded verdict decides that, read from gate-metrics.jsonl at the most
# recent gate. A suppression whose cause was genuinely fixed costs nothing and reports
# nothing — in the measured sprint the third gate is exactly that case. This is what keeps
# the arm from becoming a bookkeeping lint on entries nobody needs to touch again.
#
# THE CHECK ID IS JOINED TO THE CATALOG, NOT MATCHED BY REGEX
# Measured on the reference consumer: `pending.md` carries the literal prose token
# "Check 924", which is not a check in any catalog. A bare /Check [0-9]+/ invents subjects
# and then reports findings about them. Every id this script acts on must appear in
# enforcement-map.yaml, and ids that do not are counted and named as UNKNOWN rather than
# silently dropped — a dropped id is a subject the operator never hears about.
#
# ZERO-CONTROL. Every verdict line carries the counts it was computed over
# (`entries_scanned`, `suppressed`, `terminal_naming_check`, `malformed_attempt`). A run
# that matched nothing prints zeros rather than the same clean line a fully-conforming
# file prints. Per CLAUDE.md: a regex matching nothing must not read like full coverage.
#
# A SUPPRESSION IS DECLARED BY ITS FIELDS, AND THE STATUS TOKEN IS NOT THE DECLARATION
# `**Status:**` is parsed by taking the first `[A-Z_]+` run after the label, so a line
# reading `DECIDED_AUTONOMOUSLY (root cause), with a SUPPRESSED marker on Check 22 below.`
# classifies as `DECIDED_AUTONOMOUSLY`. The `case` below has no else, so the entry is
# scanned, skipped, and counted only in `entries_scanned`: the `suppressed` figure is
# identical whether one suppression was attempted and dropped or none was attempted at all.
# Measured on the reference consumer, that is the failure mode that shipped — the author
# added `**Suppresses:**`, `**Expires after:**` and an operator citation directly below,
# and not one of them was read.
#
# BOTH FIXES THE CANDIDATE PROPOSED WERE MEASURED AND BOTH ARE UNSHIPPABLE. Requiring the
# `**Status:**` line to be EXACTLY one token rejects most of the corpus, because a
# suppression conventionally carries `SUPPRESSED (operator, <ts>)`. Flagging a second
# vocabulary token elsewhere on the line scores 5 of 108 status lines on the reference
# consumer and ALL FIVE ARE FALSE — four say "not a HARD_BLOCK" and one says "already
# RESOLVED BY FACT below", so the negation and the intent are the same shape, and the
# rule cannot separate the true positive from them.
#
# So the arm keys on the FIELDS, not on the line. `**Suppresses:**` and `**Expires
# after:**` exist for exactly one disposition; an entry carrying either while classifying
# as anything other than `SUPPRESSED` has had its authorization silently discarded.
# False-positive set on the reference consumer: 0 of 123 entries, against a control of 16
# entries that do classify `SUPPRESSED`.
#
# THE IN-FORCE QUERY IS THE SAME PREDICATE, ASKED BY THE GATE THAT ADOPTS A FAIL
# `--in-force` lists every suppression that is well-formed, names a catalog check, and is
# within its lifetime — one row per entry on stdout, tab-separated:
#   <catalog-or-empty> <check-id> <expires-after> <gates-elapsed> <operator-auth line> <entry header, 92 chars>
# The header is LAST because it is the only field that can itself contain a tab; every reader
# splits on a bounded field count so the header absorbs the remainder. The operator-auth line
# is carried verbatim and unparsed: WHETHER THAT CITATION IS GENUINE IS NOT DECIDED HERE, and
# a caller that can reach a transcript corpus is expected to verify it before treating the row
# as a licence. `ai-dlc-gate-remediation-guard.sh` does; see its arm 7b.
# `validate-gate-adjudication.sh` asks this before it blocks on a per-check FAIL, so the one
# place that defines "in force" is this file; the gate does not restate the grammar. In this
# mode the exit is 0 whenever the file was read (an empty list is a real answer and is printed
# as `in_force=0` on stderr), and 2 on a refusal exactly as below. Malformed and expired
# entries are simply not listed; the diagnostics for them stay on stderr, because a caller
# leaning on a suppression that is malformed should see why it did not count.
#
# USAGE
#   validate-suppression-lifetime.sh --escalations <pending.md>
#                                   [--gate-metrics <gate-metrics.jsonl>]
#                                   [--enforcement-map <enforcement-map.yaml>]
#                                   [--baseline <file>]
#   validate-suppression-lifetime.sh --in-force --escalations <pending.md>
#                                   [--gate-metrics <gate-metrics.jsonl>]
#                                   [--enforcement-map <enforcement-map.yaml>]
#
# EXIT
#   0  no suppression is past its expiry on a still-failing check, and no terminal entry
#      closes a still-failing check; or there is nothing in scope; or (--in-force) the
#      escalations file was read and the in-force rows, possibly none, were printed
#   1  a violation above, a malformed SUPPRESSED entry, or suppression fields on an
#      entry that does not classify as SUPPRESSED (never under --in-force)
#   2  bad arguments, or a required input could not be read — a refusal, not a pass
set -u

ESCALATIONS=""
GATE_METRICS=""
ENFORCEMENT_MAP=""
BASELINE=""
IN_FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
# MODE_DISPATCH_BEGIN
    --escalations)     ESCALATIONS="${2:-}"; shift 2 ;;
    --gate-metrics)    GATE_METRICS="${2:-}"; shift 2 ;;
    --enforcement-map) ENFORCEMENT_MAP="${2:-}"; shift 2 ;;
    --baseline)        BASELINE="${2:-}"; shift 2 ;;
    --in-force)        IN_FORCE=1; shift ;;
    -h|--help)
      sed -n '1,90p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
# MODE_DISPATCH_END
    *)
      echo "FAIL: unknown argument '$1'" >&2
      echo "      usage: validate-suppression-lifetime.sh --escalations <pending.md>" >&2
      exit 2 ;;
  esac
done

if [ -z "$ESCALATIONS" ]; then
  echo "FAIL: --escalations <pending.md> is required." >&2
  exit 2
fi

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. Inline on purpose, in every script that
# needs it: a shared lib cannot fix this, because locating the lib is the same
# unsolved problem. core/fixtures/validator-path-resolution asserts both layouts.
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

# No escalations file is a legitimate clean state — nothing to adjudicate.
if [ ! -f "$ESCALATIONS" ]; then
  if [ "$IN_FORCE" -eq 1 ]; then
    echo "IN-FORCE: entries_scanned=0 suppressed=0 in_force=0 -- no escalations file ($ESCALATIONS)." >&2
    exit 0
  fi
  echo "OK: EXAMINED NOTHING — entries_scanned=0 suppressed=0 terminal_naming_check=0 malformed_attempt=0 -- no escalations file ($ESCALATIONS)."
  exit 0
fi

# ---- 1. Locate the catalog -------------------------------------------------
if [ -z "$ENFORCEMENT_MAP" ]; then
  for cand in \
      "$AI_DLC_ROOT/core/skills/ai-dlc/enforcement-map.yaml" \
      "$AI_DLC_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml" \
      "$AI_DLC_SELF_DIR/../skills/ai-dlc/enforcement-map.yaml"; do
    [ -f "$cand" ] && { ENFORCEMENT_MAP="$cand"; break; }
  done
fi
if [ -z "$ENFORCEMENT_MAP" ] || [ ! -f "$ENFORCEMENT_MAP" ]; then
  echo "FAIL: enforcement-map.yaml not found. Check ids are JOINED to the catalog, not" >&2
  echo "      matched by regex; without it this script would act on prose tokens that are" >&2
  echo "      not checks. Refusing rather than guessing." >&2
  # Name the root and the candidates. A refusal that does not say WHERE it looked
  # cannot be acted on, and a resolved root that never reaches the output is a root
  # nothing can prove was consulted.
  echo "      Resolved project root: $AI_DLC_ROOT" >&2
  echo "      Looked for:" >&2
  echo "        $AI_DLC_ROOT/core/skills/ai-dlc/enforcement-map.yaml" >&2
  echo "        $AI_DLC_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml" >&2
  echo "        $AI_DLC_SELF_DIR/../skills/ai-dlc/enforcement-map.yaml" >&2
  exit 2
fi

CATALOG="$(sed -n 's/^  - id: *"\{0,1\}\([^"#]*\)"\{0,1\} *$/\1/p' "$ENFORCEMENT_MAP" \
           | sed 's/[[:space:]]*$//' | grep . || true)"
CATALOG_N="$(grep -c . <<<"$CATALOG" || true)"
if [ "$CATALOG_N" -lt 2 ]; then
  echo "FAIL: derived only $CATALOG_N check ids from $ENFORCEMENT_MAP." >&2
  echo "      That is a parse failure, not a small catalog. Refusing to validate against" >&2
  echo "      a catalog this script did not read." >&2
  exit 2
fi

# ---- 2. Locate gate-metrics (optional; the shape arm runs without it) -------
if [ -z "$GATE_METRICS" ]; then
  for cand in \
      "_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "_bmad-output/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl"; do
    [ -f "$cand" ] && { GATE_METRICS="$cand"; break; }
  done
fi

# ---- 3. Extract one record per entry ---------------------------------------
# Grammar-independent by construction. The reference consumer writes entry headers as
# `## [<title>] [<author>] - <ts> — <summary>`, NOT the `## S<N>-` form an earlier reading
# of this corpus recorded: a `^## S[0-9]+-` anchor matches 6 of ~22 real entries and fails
# OPEN on the rest. So entries are flushed on ANY level-2/3 heading and every field is
# matched ANYWHERE in the entry body, never at line start. Same idiom as
# validate-escalation-status-vocabulary.sh:153-166.
#
# Fields are emitted in an order no field name prefixes another's value, and each is
# delimited, so a `Suppresses:` cannot cross-match `Suppresses-something:`.
RECORDS="$(awk '
  function flush() {
    if (header != "")
      printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n", header, status, supp, expires, authts, named, suppcat, authline
  }
  /^#{2,3} / { flush(); header=$0; status=""; supp=""; expires=""; authts=""; named=""; suppcat=""; authline=""; next }
  /\*\*[Ss]tatus:\*\*/ {
    if (status == "") {
      s=$0; sub(/^.*\*\*[Ss]tatus:\*\*[[:space:]]*/,"",s)
      if (match(s,/[A-Z_]+/)) status=substr(s,RSTART,RLENGTH)
    }
    next
  }
  /\*\*Suppresses:\*\*/ {
    if (supp == "") {
      s=$0; sub(/^.*\*\*Suppresses:\*\*[[:space:]]*/,"",s)
      gsub(/`/,"",s)
      # optional [catalog] prefix, kept as its own field for the in-force join, then the id
      # up to the em/en dash or hyphen separator
      if (match(s,/^\[[^]]*\]/)) suppcat=substr(s,RSTART+1,RLENGTH-2)
      sub(/^\[[^]]*\][[:space:]]*/,"",s)
      sub(/[[:space:]]*[—–-][[:space:]].*$/,"",s)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
      supp=s
    }
    next
  }
  /\*\*Expires after:\*\*/ {
    if (expires == "") {
      s=$0; sub(/^.*\*\*Expires after:\*\*[[:space:]]*/,"",s)
      if (match(s,/[0-9]+/)) expires=substr(s,RSTART,RLENGTH)
    }
    next
  }
  /\*\*Operator authorization:\*\*/ {
    if (authts == "") {
      s=$0; sub(/^.*\*\*Operator authorization:\*\*[[:space:]]*/,"",s)
      # The line is carried VERBATIM as its own field, and no quote is extracted here. The
      # quoted-segment parser a verifying caller needs is held to exactly three copies by an
      # invariant whose site list is DERIVED, so this file forwards the line unparsed rather
      # than becoming a fourth.
      if (authline == "") authline=s
      if (match(s,/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}/))
        authts=substr(s,RSTART,RLENGTH)
    }
    next
  }
  {
    s=$0
    while (match(s,/[Cc]heck[[:space:]]+(H?[0-9]+[a-z]?|GM[0-9]+)/)) {
      tok=substr(s,RSTART,RLENGTH)
      sub(/^[Cc]heck[[:space:]]+/,"",tok)
      if (index("," named ",", "," tok ",") == 0) named = (named=="" ? tok : named "," tok)
      s=substr(s,RSTART+RLENGTH)
    }
  }
  END { flush() }
' "$ESCALATIONS")"

ENTRIES_N="$(grep -c . <<<"$RECORDS")"
[ -n "$RECORDS" ] || ENTRIES_N=0

# ---- 4. Gate timeline from the metrics -------------------------------------
# BOTH JSON SPACINGS, BECAUSE THE REAL FILE CARRIES BOTH. Measured on the reference
# consumer's gate-metrics.jsonl: 337 of 723 rows are written `"check":"1"` and 386 are
# written `"check": "1"`. The emitter is a lead writing a line per check per gate, and the
# two spellings track which session wrote them. A per-field regex anchored to one spacing
# reads 47% of the corpus and reports clean over the rest — the fail-open direction, and
# the same grammar-variance class that made an earlier check report "no routing record"
# against a live snapshot. Every field is read through jstr(), which tolerates whitespace
# on both sides of the colon; no offset arithmetic on RSTART, because the prefix length
# is exactly what varies.
JSTR_AWK='
  function jstr(line, key,   re, s) {
    re = "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\""
    if (!match(line, re)) return ""
    s = substr(line, RSTART, RLENGTH)
    sub(/^"[^"]*"[[:space:]]*:[[:space:]]*"/, "", s)
    sub(/"$/, "", s)
    return s
  }
'

# Distinct gate events, ascending. One gate emits many per-check rows sharing a `ts`.
GATE_TS=""
if [ -n "$GATE_METRICS" ] && [ -f "$GATE_METRICS" ]; then
  GATE_TS="$(awk "$JSTR_AWK"'
    { t = jstr($0, "ts"); if (t != "") print t }
  ' "$GATE_METRICS" | sort -u)"
fi
GATES_N="$(grep -c . <<<"${GATE_TS:-}" || true)"
[ -n "$GATE_TS" ] || GATES_N=0

# latest_verdict <check-id> -> verdict at the most recent gate that recorded it
latest_verdict() {
  local id="$1"
  [ -n "$GATE_METRICS" ] && [ -f "$GATE_METRICS" ] || { printf '%s\n' ""; return 0; }
  awk -v want="$id" "$JSTR_AWK"'
    {
      c = jstr($0, "check")
      if (c != want) next
      t = jstr($0, "ts")
      v = jstr($0, "verdict")
      if (t >= bestt) { bestt = t; bestv = v }
    }
    END { print bestv }
  ' "$GATE_METRICS"
}

# gates_since <iso-ts> -> count of distinct gate events recorded strictly after it
gates_since() {
  local since="$1"
  [ -n "$GATE_TS" ] || { printf '0\n'; return 0; }
  awk -v s="$since" '$0 > s {n++} END {print n+0}' <<<"$GATE_TS"
}

# ---- 5. Baseline -----------------------------------------------------------
# R5's rule, unchanged: a baseline must not outlive its cause. Every baselined key that
# STOPS reproducing is itself a failure, so the file cannot quietly accumulate entries
# that no longer describe anything.
BASELINE_KEYS=""
if [ -n "$BASELINE" ]; then
  if [ ! -f "$BASELINE" ]; then
    echo "FAIL: --baseline '$BASELINE' is not readable. A baseline that cannot be read" >&2
    echo "      would silently suppress nothing and read like a clean run." >&2
    exit 2
  fi
  BASELINE_KEYS="$(grep -v '^[[:space:]]*#' "$BASELINE" | grep -v '^[[:space:]]*$' || true)"
fi
baselined() { [ -n "$BASELINE_KEYS" ] && grep -qxF "$1" <<<"$BASELINE_KEYS"; }

# ---- 6. Adjudicate ---------------------------------------------------------
bad=0
suppressed_n=0
terminal_naming_n=0
malformed_attempt_n=0
unknown_n=0
matched_baseline=""

# Records are delimited by the ASCII UNIT SEPARATOR (0x1f), not a tab. Tab is IFS
# WHITESPACE, so `read` collapses a run of consecutive tabs into ONE delimiter and every
# empty field between them disappears — an entry with no `**Suppresses:**` silently shifts
# its later fields left and `named` arrives empty, which reads exactly like an entry that
# names no check. 0x1f is non-whitespace, so empty fields are preserved positionally, and
# it cannot occur in markdown prose the way `|` or `~` can.
in_force_n=0
unresolved_n=0
while IFS="$(printf '\037')" read -r header status supp expires authts named suppcat authline; do
  [ -n "${header:-}" ] || continue
  short="$(printf '%s' "$header" | cut -c1-92)"

  # --- a suppression declared by its fields but classified as something else ---
  # Sited ABOVE the case, not inside it as an else, because the case branches on the
  # status token and the status token is the thing that is wrong. An entry reaching a
  # RESOLVED/OVERRIDDEN branch with these fields is the same silent discard.
  if [ "${status:-}" != "SUPPRESSED" ] && { [ -n "$supp" ] || [ -n "$expires" ]; }; then
    malformed_attempt_n=$((malformed_attempt_n + 1))
    key="ATTEMPT:$(printf '%s' "$short" | tr -d ' ')"
    if baselined "$key"; then
      matched_baseline="$matched_baseline$key
"
    else
      bad=$((bad + 1))
      echo "FAIL: suppression fields on an entry that does not classify as SUPPRESSED." >&2
      echo "      entry: $short" >&2
      echo "      Parsed **Status:** as '${status:-(none)}'; the entry carries" \
           "${supp:+**Suppresses:** $supp}${supp:+ }${expires:+**Expires after:** $expires}." >&2
      echo "      The status token is read as the first [A-Z_] run after the label, so a" >&2
      echo "      trailing parenthetical naming another disposition does not change it." >&2
      echo "      Those fields are adjudicated for SUPPRESSED and for nothing else, so as" >&2
      echo "      written this entry's target, expiry and citation are never examined." >&2
      echo "      Set the status to SUPPRESSED, or remove the fields." >&2
      echo "      Baseline key: $key" >&2
    fi
  fi

  case "${status:-}" in
    SUPPRESSED)
      suppressed_n=$((suppressed_n + 1))
      # --- shape ---
      malformed=""
      [ -n "$supp" ]    || malformed="$malformed **Suppresses:**"
      [ -n "$expires" ] || malformed="$malformed **Expires after:**"
      [ -n "$authts" ]  || malformed="$malformed **Operator authorization:**"
      if [ -n "$malformed" ]; then
        bad=$((bad + 1))
        echo "FAIL: malformed SUPPRESSED entry -- missing:$malformed" >&2
        echo "      entry: $short" >&2
        echo "      A suppression without a target, a lifetime and an operator citation is" >&2
        echo "      an OVERRIDDEN with a new name. Those three fields are what make it" >&2
        echo "      expire, and what make the expiry checkable." >&2
        continue
      fi
      if [ "$expires" -lt 1 ] || [ "$expires" -gt 3 ]; then
        bad=$((bad + 1))
        echo "FAIL: **Expires after:** $expires gates is outside the permitted 1..3." >&2
        echo "      entry: $short" >&2
        continue
      fi
      if ! grep -qxF "$supp" <<<"$CATALOG"; then
        unknown_n=$((unknown_n + 1))
        bad=$((bad + 1))
        echo "FAIL: **Suppresses:** names '$supp', which is not a check in the catalog." >&2
        echo "      entry: $short" >&2
        echo "      Catalog: $ENFORCEMENT_MAP ($CATALOG_N ids). A suppression whose target" >&2
        echo "      does not exist suppresses nothing and expires never." >&2
        continue
      fi
      # --- the in-force query: within lifetime, whatever the check's latest verdict ---
      # A lifetime that cannot be COUNTED is not a licence. The lifetime arm below declines
      # to adjudicate when no metrics file was found and says so; the query must do the
      # same, because its rows become gate passage. Measured before this guard: an expired
      # entry read as in force at 0 elapsed from any cwd where the timeline did not
      # resolve, and again with --gate-metrics pointed at a missing file. A metrics file
      # that EXISTS and records no gate is the genuine fresh-consumer case and stays in
      # force at 0 elapsed.
      if [ "$IN_FORCE" -eq 1 ]; then
        if [ -z "$GATE_METRICS" ] || [ ! -f "$GATE_METRICS" ]; then
          unresolved_n=$((unresolved_n + 1))
          echo "NOTE: entry '$supp' -- NOT listed in force: no gate-metrics.jsonl was found, so" >&2
          echo "      its lifetime cannot be counted. Pass --gate-metrics <file> or run from the" >&2
          echo "      project root. A lifetime that cannot be counted is not a licence." >&2
          continue
        fi
        elapsed=0
        [ "$GATES_N" -eq 0 ] || elapsed="$(gates_since "$authts")"
        if [ "$elapsed" -le "$expires" ]; then
          in_force_n=$((in_force_n + 1))
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$suppcat" "$supp" "$expires" "$elapsed" "$authline" "$short"
        fi
        continue
      fi
      # --- lifetime ---
      if [ "$GATES_N" -eq 0 ]; then
        echo "NOTE: entry '$supp' -- expiry NOT-APPLICABLE, no gate-metrics.jsonl found," >&2
        echo "      so elapsed gates cannot be counted. Shape was checked; lifetime was not." >&2
        continue
      fi
      elapsed="$(gates_since "$authts")"
      verdict="$(latest_verdict "$supp")"
      if [ "$elapsed" -gt "$expires" ]; then
        if [ "$verdict" = "FAIL" ]; then
          key="EXPIRED:$supp"
          if baselined "$key"; then
            matched_baseline="$matched_baseline$key
"
          else
            bad=$((bad + 1))
            echo "FAIL: suppression of check '$supp' is past its lifetime and the check is" >&2
            echo "      STILL FAILING. Authorized $authts, **Expires after:** $expires gate(s)," >&2
            echo "      $elapsed gate(s) recorded since; latest recorded verdict is FAIL." >&2
            echo "      entry: $short" >&2
            echo "      The prior citation may not be re-cited. Obtain fresh operator" >&2
            echo "      authorization as a NEW entry, or fix the underlying failure." >&2
          fi
        fi
        # expired but no longer failing: the cause was fixed. Nothing to report.
      fi
      ;;
    RESOLVED|OVERRIDDEN)
      # --- the loophole: a terminal entry closing a check that is still red ---
      [ -n "$named" ] || continue
      hit=""
      IFS=',' read -ra ids <<<"$named"
      for id in "${ids[@]:-}"; do
        [ -n "${id:-}" ] || continue
        grep -qxF "$id" <<<"$CATALOG" || continue
        [ "$(latest_verdict "$id")" = "FAIL" ] || continue
        hit="$hit $id"
      done
      [ -n "$hit" ] || continue
      terminal_naming_n=$((terminal_naming_n + 1))
      key="TERMINAL:$(printf '%s' "$short" | tr -d ' ')"
      if baselined "$key"; then
        matched_baseline="$matched_baseline$key
"
        continue
      fi
      bad=$((bad + 1))
      echo "FAIL: a $status entry names check(s)$hit, which are recorded FAILING." >&2
      echo "      entry: $short" >&2
      echo "      $status closes a QUESTION and names no check, so nothing joins this" >&2
      echo "      entry to the failure it is standing in front of. Use SUPPRESSED with" >&2
      echo "      **Suppresses:**, **Expires after:** and an operator citation, or fix it." >&2
      echo "      Baseline key: $key" >&2
      ;;
  esac
done <<EOF
$RECORDS
EOF

# ---- 6b. The in-force query answers here, with its counts, and never with exit 1 ------
if [ "$IN_FORCE" -eq 1 ]; then
  if [ -n "$GATE_METRICS" ] && [ -f "$GATE_METRICS" ]; then
    echo "IN-FORCE: entries_scanned=$ENTRIES_N suppressed=$suppressed_n in_force=$in_force_n gates_recorded=$GATES_N catalog=$CATALOG_N metrics=$GATE_METRICS" >&2
  else
    echo "IN-FORCE: entries_scanned=$ENTRIES_N suppressed=$suppressed_n in_force=$in_force_n lifetime_unresolved=$unresolved_n gates_recorded=NONE catalog=$CATALOG_N metrics=(none found)" >&2
  fi
  exit 0
fi

# ---- 7. A baseline may not outlive its cause -------------------------------
if [ -n "$BASELINE_KEYS" ]; then
  while IFS= read -r key; do
    [ -n "${key:-}" ] || continue
    if ! grep -qxF "$key" <<<"$matched_baseline"; then
      bad=$((bad + 1))
      echo "FAIL: baselined key no longer reproduces: $key" >&2
      echo "      A baseline that outlives its cause silently suppresses a check that has" >&2
      echo "      started passing. Remove the line from $BASELINE." >&2
    fi
  done <<EOF
$BASELINE_KEYS
EOF
fi

SUMMARY="entries_scanned=$ENTRIES_N suppressed=$suppressed_n terminal_naming_check=$terminal_naming_n malformed_attempt=$malformed_attempt_n gates_recorded=$GATES_N catalog=$CATALOG_N"
if [ "$bad" -gt 0 ]; then
  echo "FAIL: $bad suppression-lifetime violation(s). $SUMMARY" >&2
  exit 1
fi

echo "OK: $SUMMARY -- no suppression is past its lifetime on a still-failing check."
echo "  escalations:   $ESCALATIONS"
echo "  catalog:       $ENFORCEMENT_MAP"
echo "  gate metrics:  ${GATE_METRICS:-(none given)}"
echo "  baseline:      ${BASELINE:-(none given)}"
exit 0
