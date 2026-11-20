#!/usr/bin/env bash
# standing-rulings.sh -- reader and checker for the operator standing-rulings record.
#
#   standing-rulings.sh lookup <header>      print the ACTIVE, SOURCED row whose `match:` equals <header>
#                                            exactly; exit 0 found, 1 none, 2 record malformed
#   standing-rulings.sh check [record [hist]]  every row conforms to the grammar, ids are unique, no
#                                            `match:` is a header a program reads back, and every
#                                            `source:` resolves to a hook-written answers-history entry
#                                            whose `- SHA256:` equals sha256(ruling); exit 0 ok, 1 findings
#   standing-rulings.sh grammar              the forbidden-header anchors still appear in the emitters
#                                            (distribution tree only; an absent emitter is SKIPPED)
#
# The grammar is DATA: operator-standing-rulings.json (core/schemas/ here, .claude/schemas/ installed),
# loaded with jq; nothing below restates a field, pattern or value list. An absent record, or a record
# with no rows, is zero rows and exit 0. A row's `ruling:` is the operator's answer verbatim: the first
# line follows `- ruling: `, further lines are indented two spaces (a blank line is two spaces).
# The hash matches ai-dlc-answer-capture.sh exactly: printf '%s' of the answer with trailing newlines
# stripped, sha256 hex.
set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never a fixed number of `..` hops (distribution, installed and legacy layouts).
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
SELF_DIR="$AI_DLC_SELF_DIR"
ROOT="$AI_DLC_ROOT"
INSTALL_ROOT="$(ai_dlc_resolve_root "$SELF_DIR" || true)"

SCHEMA=""
if [ -f "$SELF_DIR/../schemas/operator-standing-rulings.json" ]; then
  SCHEMA="$(cd "$SELF_DIR/../schemas" && pwd)/operator-standing-rulings.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/core/schemas/operator-standing-rulings.json" ]; then
  SCHEMA="$ROOT/core/schemas/operator-standing-rulings.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/schemas/operator-standing-rulings.json" ]; then
  SCHEMA="$ROOT/.claude/schemas/operator-standing-rulings.json"
elif [ -n "$INSTALL_ROOT" ] && [ -f "$INSTALL_ROOT/.claude/schemas/operator-standing-rulings.json" ]; then
  SCHEMA="$INSTALL_ROOT/.claude/schemas/operator-standing-rulings.json"
fi
command -v jq >/dev/null 2>&1 || { echo "standing-rulings: jq is required" >&2; exit 2; }
[ -n "$SCHEMA" ] || { echo "standing-rulings: cannot find operator-standing-rulings.json (looked beside this script, in <root>/core/schemas and <root>/.claude/schemas)" >&2; exit 2; }
jq -e . "$SCHEMA" >/dev/null 2>&1 || { echo "standing-rulings: $SCHEMA is not valid JSON" >&2; exit 2; }

G_RECORD="$(jq -r '.record_path' "$SCHEMA")"
G_HIST="$(jq -r '.answers_history_path' "$SCHEMA")"
G_REQ="$(jq -r '.requests_history_path' "$SCHEMA")"
G_DEC="$(jq -r '.decision_entry_paths[]' "$SCHEMA")"
G_MARK="$(jq -r '.proposal_marker.prefix' "$SCHEMA")"
G_CPFX="$(jq -r '.proposal_marker.class_prefix' "$SCHEMA")"
G_CLS="$(jq -r '.proposal_marker.classes[]' "$SCHEMA")"
G_CLS_OUT="$(jq -r '.proposal_marker.outside_classes[]' "$SCHEMA")"
G_HEADING="$(jq -r '.row_heading_pattern' "$SCHEMA")"
G_FIELDS="$(jq -r '.fields | keys_unsorted | join(" ")' "$SCHEMA")"
G_FORBID="$(jq -r '.forbidden_matches[] | "\(.name)\t\(.pattern)"' "$SCHEMA")"

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  else printf '%s' "$1" | sha256sum | cut -d' ' -f1; fi
}

# entry_sha <history> <line> -> prints the entry's SHA256; rc 3 not an entry heading, 4 no SHA line
entry_sha() {
  awk -v n="$2" '
    NR == n { if ($0 !~ /^## [^ ]+ -- AskUserQuestion$/) exit 3; f = 1; seen = 1; next }
    f && /^## / { f = 0 }
    f && /^- Question \(lead-authored, NOT covered by the hash\): / { q = $0; sub(/^- Question \(lead-authored, NOT covered by the hash\): /, "", q) }
    f && /^- SHA256: / { s = $0; sub(/^- SHA256: /, "", s); ok = 1 }
    END { if (!seen) exit 3; if (!ok) exit 4; print s; print q }' "$1"
}

# entry_req <requests-history> <heading line> -> prints the entry's SHA256; rc 3 no such entry,
# 4 no SHA line, 5 the entry carries no `- Pending decision: DP-<s>-<n>` line
entry_req() {
  awk -v h="$2" '
    !f && $0 == h { f = 1; next }
    f && /^## / { exit }
    f && /^- Pending decision: DP-[0-9]+-[0-9]+$/ { d = $0; sub(/^- Pending decision: /, "", d) }
    f && /^- SHA256: / { s = $0; sub(/^- SHA256: /, "", s); ok = 1 }
    END { if (!f) exit 3; if (!ok) exit 4; if (d == "") exit 5; print s; print d }' "$1"
}

# marker_in <text> <match> -> 0 when a line of the text carries the proposal marker, the match
# EXACTLY and the class prefix after it; sets MARK_CLASS to the class token that follows
MARK_CLASS=""
marker_in() {
  local line rest needle="${G_MARK}${2}${G_CPFX}"
  MARK_CLASS=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line == *"$needle"* ]]; then
      rest="${line#*"$needle"}"
      [[ $rest =~ ^[a-z0-9-]* ]]
      MARK_CLASS="${BASH_REMATCH[0]}"
      return 0
    fi
  done <<<"$1"
  return 1
}

# class_ok <id> -> adds a finding unless MARK_CLASS is a declared, non-Outside class
class_ok() {
  if [ -z "$MARK_CLASS" ]; then add_finding "$1" "unsourced: the proposal names no class"
  elif grep -qxF -- "$MARK_CLASS" <<<"$G_CLS_OUT"; then add_finding "$1" "class '$MARK_CLASS' is on the sort's Outside list; a row may not decide it"
  elif ! grep -qxF -- "$MARK_CLASS" <<<"$G_CLS"; then add_finding "$1" "unsourced: the proposal names an unknown class '$MARK_CLASS'"; fi
}

# decision_asks <token> <match> -> 0 when an escalation entry whose Veto window line names the token
# (open or closed) has a `**Decision/Question:**` line carrying the proposal marker for the match;
# prints the class token that follows
decision_asks() {
  local p out
  while IFS= read -r p; do
    [ -n "$p" ] && [ -f "$ROOT/$p" ] || continue
    out="$(DT="$1" DM="${G_MARK}${2}${G_CPFX}" awk '
      function flush() { if (hit && ask) { found = 1; cls = acls } hit = 0; ask = 0 }
      BEGIN { t = ENVIRON["DT"]; m = ENVIRON["DM"] }
      /^## / { flush(); next }
      index($0, "**Veto window:**") == 1 { i = index($0, t); if (i > 0 && substr($0, i + length(t), 1) !~ /[0-9]/) hit = 1 }
      index($0, "**Decision/Question:**") == 1 {
        i = index($0, m)
        if (i > 0) { ask = 1; r = substr($0, i + length(m)); acls = ""; if (match(r, /^[a-z0-9-]*/)) acls = substr(r, 1, RLENGTH) }
      }
      END { flush(); if (!found) exit 1; print cls }' "$ROOT/$p")" || continue
    MARK_CLASS="$out"; return 0
  done <<<"$G_DEC"
  return 1
}

FINDINGS=""
IDS=" "
ROWS=0
LOOKUP_OUT=""
LOOKUP_KEY=""
HIST_FILE=""
REQ_FILE=""

add_finding() { FINDINGS="${FINDINGS}${1}: ${2}"$'\n'; }

# value_ok <field> <value> -> 0 when it conforms to the grammar
value_ok() {
  local f="$1" v="$2" pat vals
  pat="$(jq -r --arg f "$f" '.fields[$f].pattern // empty' "$SCHEMA")"
  if [ -n "$pat" ]; then
    [[ $v =~ $pat ]] && return 0
    pat="$(jq -r --arg f "$f" '.fields[$f].alt_pattern // empty' "$SCHEMA")"
    [ -n "$pat" ] && [[ $v =~ $pat ]]; return $?
  fi
  vals="$(jq -r --arg f "$f" '.fields[$f].values // [] | .[]' "$SCHEMA")"
  [ -n "$vals" ] || return 1
  case $'\n'"$vals"$'\n' in *$'\n'"$v"$'\n'*) return 0 ;; esac
  return 1
}

finalize_row() {
  [ -n "${cur_id:-}" ] || return 0
  local before f v name pat sha got rc ln q
  before="$FINDINGS"
  ROWS=$((ROWS + 1))
  for f in $G_FIELDS; do
    eval "v=\${F_$f-}"
    eval "n=\${N_$f:-0}"
    if [ "$n" -eq 0 ]; then add_finding "$cur_id" "field '$f' is missing"; continue; fi
    if [ "$n" -gt 1 ]; then add_finding "$cur_id" "field '$f' appears $n times"; continue; fi
    value_ok "$f" "$v" || add_finding "$cur_id" "field '$f' does not conform to the grammar"
  done
  if [ -n "${F_match-}" ]; then
    while IFS=$'\t' read -r name pat; do
      [ -n "$name" ] || continue
      if [[ ${F_match} =~ $pat ]]; then
        add_finding "$cur_id" "match '${F_match}' is a header a program reads back ($name); a row may not decide it"
      fi
    done <<<"$G_FORBID"
  fi
  # source: resolve the entry and compare the hash
  if [ "${N_source:-0}" -eq 1 ] && [ "${N_ruling:-0}" -eq 1 ] && [ -n "${F_ruling-}" ] \
     && [[ ${F_source} == "${G_REQ}:"* ]]; then
    ln="${F_source#"${G_REQ}":}"
    if [ -z "$REQ_FILE" ] || [ ! -f "$REQ_FILE" ]; then
      add_finding "$cur_id" "unsourced: $G_REQ is absent"
    else
      got="$(entry_req "$REQ_FILE" "$ln")"; rc=$?
      if [ "$rc" -eq 3 ]; then add_finding "$cur_id" "unsourced: no entry headed '$ln' in $G_REQ"
      elif [ "$rc" -eq 5 ]; then add_finding "$cur_id" "unsourced: the entry '$ln' carries no '- Pending decision:' line (the reply answered no decision block)"
      elif [ "$rc" -ne 0 ]; then add_finding "$cur_id" "unsourced: the entry '$ln' carries no SHA256 line"
      else
        sha="$(sha256_of "$F_ruling")"
        q="${got#*$'\n'}"; got="${got%%$'\n'*}"
        [ "$sha" = "$got" ] || add_finding "$cur_id" "unsourced: sha256(ruling) does not equal the entry's SHA256 ('$ln')"
        if decision_asks "$q" "$F_match"; then class_ok "$cur_id"; else add_finding "$cur_id" "unsourced: no escalation entry for $q has a Decision/Question line carrying '${G_MARK}<match>' for the row's match (the reply answered a different decision)"; fi
      fi
    fi
  elif [ "${N_source:-0}" -eq 1 ] && [ "${N_ruling:-0}" -eq 1 ] && [ -n "${F_ruling-}" ]; then
    ln="${F_source##*:}"
    if [ -z "$HIST_FILE" ] || [ ! -f "$HIST_FILE" ]; then
      add_finding "$cur_id" "unsourced: $G_HIST is absent"
    elif ! [[ $ln =~ ^[0-9]+$ ]]; then
      add_finding "$cur_id" "unsourced: source line is not a number"
    else
      got="$(entry_sha "$HIST_FILE" "$ln")"; rc=$?
      if [ "$rc" -eq 3 ]; then add_finding "$cur_id" "unsourced: line $ln of $G_HIST is not an AskUserQuestion entry heading"
      elif [ "$rc" -ne 0 ]; then add_finding "$cur_id" "unsourced: the entry at line $ln carries no SHA256 line"
      else
        sha="$(sha256_of "$F_ruling")"
        q="${got#*$'\n'}"; got="${got%%$'\n'*}"
        [ "$sha" = "$got" ] || add_finding "$cur_id" "unsourced: sha256(ruling) does not equal the entry's SHA256 (line $ln)"
        if marker_in "$q" "$F_match"; then class_ok "$cur_id"; else add_finding "$cur_id" "unsourced: the question at line $ln does not carry '${G_MARK}<match>${G_CPFX}<class>' for the row's match (the answer is not to a standing-ruling proposal)"; fi
      fi
    fi
  fi
  if [ "$FINDINGS" = "$before" ] && [ -n "$LOOKUP_KEY" ] && [ -z "$LOOKUP_OUT" ] \
     && [ "${F_status-}" = active ] && [ "${F_match-}" = "$LOOKUP_KEY" ]; then
    LOOKUP_OUT="### ${cur_id}"$'\n'"- match: ${F_match}"$'\n'"- ruling: ${F_ruling}"$'\n'"- source: ${F_source}"$'\n'"- scope: ${F_scope}"$'\n'"- status: ${F_status}"
  fi
}

reset_row() {
  local f
  for f in $G_FIELDS; do eval "F_$f=''; N_$f=0"; done
  last_field=""
}

# scan <record> <history>
scan() {
  local rec="$1" line f v fre='^- ([a-z_]+): (.*)$' cre='^  (.*)$'
  HIST_FILE="$2"
  case "$2" in */*) REQ_FILE="${2%/*}/${G_REQ##*/}" ;; *) REQ_FILE="./${G_REQ##*/}" ;; esac
  cur_id=""; last_field=""
  [ -f "$rec" ] || return 0
  reset_row
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ $G_HEADING ]]; then
      finalize_row
      cur_id="${line#\#\#\# }"
      case "$IDS" in *" $cur_id "*) add_finding "$cur_id" "duplicate id" ;; esac
      IDS="${IDS}${cur_id} "
      reset_row
      continue
    fi
    if [[ $line == '### '* ]]; then add_finding "(heading)" "'$line' does not match the row heading pattern"; continue; fi
    [ -n "$cur_id" ] || continue
    if [[ $line =~ $fre ]]; then
      f="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
      case " $G_FIELDS " in
        *" $f "*) eval "F_$f=\$v; N_$f=\$((N_$f + 1))"; last_field="$f" ;;
        *) add_finding "$cur_id" "unknown field '$f'"; last_field="" ;;
      esac
    elif [ "$last_field" = ruling ] && [[ $line =~ $cre ]]; then
      F_ruling="${F_ruling}"$'\n'"${BASH_REMATCH[1]}"
    else
      last_field=""
    fi
  done <"$rec"
  finalize_row
}

cmd="${1:-}"
case "$cmd" in
  lookup)
    [ $# -eq 2 ] || { echo "usage: standing-rulings.sh lookup <header>" >&2; exit 2; }
    LOOKUP_KEY="$2"
    [ -n "$ROOT" ] || exit 1
    scan "$ROOT/$G_RECORD" "$ROOT/$G_HIST"
    if [ -n "$FINDINGS" ]; then printf '%s' "$FINDINGS" >&2; exit 2; fi
    [ -n "$LOOKUP_OUT" ] || exit 1
    printf '%s\n' "$LOOKUP_OUT"; exit 0 ;;
  check)
    rec="${2:-}"; hist="${3:-}"
    [ -n "$rec" ] || { [ -n "$ROOT" ] && rec="$ROOT/$G_RECORD"; }
    [ -n "$hist" ] || { [ -n "$ROOT" ] && hist="$ROOT/$G_HIST"; }
    scan "${rec:-/nonexistent}" "${hist:-/nonexistent}"
    if [ -n "$FINDINGS" ]; then printf '%s' "$FINDINGS" >&2; echo "standing-rulings: check FAIL" >&2; exit 1; fi
    echo "standing-rulings: ok ($ROWS row(s)) in ${rec:-<no record>}"; exit 0 ;;
  grammar)
    bad=0; n=0
    anchors="$(jq -r '.forbidden_matches[] | "\(.name)\t\(.emitter)\t\(.anchor)"' "$SCHEMA")" || { echo "FAIL: cannot read forbidden_matches" >&2; exit 2; }
    while IFS=$'\t' read -r name emitter anchor; do
      [ -n "$name" ] || continue
      n=$((n + 1))
      if [ -z "$ROOT" ] || [ ! -f "$ROOT/$emitter" ]; then echo "SKIP $name: $emitter absent in this tree"; continue; fi
      if grep -qF -- "$anchor" "$ROOT/$emitter"; then echo "ok   $name"; else echo "FAIL $name: anchor not found in $emitter" >&2; bad=1; fi
    done <<<"$anchors"
    [ "$n" -gt 0 ] || { echo "FAIL: no forbidden_matches declared" >&2; exit 1; }
    exit "$bad" ;;
  *)
    echo "usage: standing-rulings.sh lookup <header> | check [record [history]] | grammar" >&2; exit 2 ;;
esac
