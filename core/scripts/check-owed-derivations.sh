#!/usr/bin/env bash
# check-owed-derivations.sh — which derivations did an earlier pull LEAVE broken, and are they still?
#
# Usage: check-owed-derivations.sh [<record>]
#   <record> defaults to `_bmad-output/ai-dlc-update/owed-derivations.tsv` under the project root,
#   which is the file `reconcile/derivation-differential.sh --record-owed` appends to.
# Output: one tab-separated line per OPEN row on STDOUT:
#   OPEN <key file:line> <reason> <$ recorded command> <base>..<theirs> <reconcile log name>
#   <reason> is STALE | UNRUN | SUPERSEDED-STALE | MOVED | UNASSESSED.
# Exit:   0 no open row, or no record at all (silent)
#         1 one or more open rows
#         2 the record is unreadable or malformed. A REFUSAL, distinct from an absent record: an
#           absent record owes nothing, an unreadable one has not been shown to owe nothing.
#
# OPENNESS IS DERIVED FROM THE TREE, NEVER FROM THE RECORD. The record has no status cell and this
# script reads none. A row is open iff the installed validator, re-run on that row's OWN file, still
# reports that row's line failing. A row closes by re-pointing the derivation. It is never closed by
# writing a word, so prose saying "done" beside a still-failing derivation changes nothing.
#
# EACH ROW'S OWN FILE, never a step's scan set. A row can name `prd.md` or a `party-mode/` record that
# no sprint-directory walk reaches; filtering to `s<N>/` would close those unread.
#
# THE VERDICT STREAM IS STDERR, AND A REPRODUCING DERIVATION PRINTS NOTHING ON IT. So "no line for
# this key" means closed only when the key names a real `$ ` command line. The guard below asserts that
# first: the row's file exists, and line N of it is a `$ ` command equal to the recorded one. Otherwise
# the file moved or the line shifted, the validator would print nothing about the recorded key, and
# silence would close a debt nobody repaired. That row is reported MOVED and counts as open.
#
# JOIN RULE for a key K, in order:
#   (a) the validator exited 2 over K's file: unassessed (UNASSESSED), open, never closed;
#   (b) K is named by `SUPERSEDED: <f>:<K> by <f>:<later>` on stderr: open iff a FAIL or UNRUN line
#       exists for <later>, the copy that actually ran;
#   (c) otherwise open iff a FAIL or UNRUN line exists for K.
set -uo pipefail

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
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$ROOT" ] || ROOT="$(ai_dlc_resolve_root "$SELF_DIR" || true)"
[ -n "$ROOT" ] || ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$ROOT" ] || ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$ROOT" ] || { echo "REFUSED: cannot resolve the project root; set AI_DLC_PROJECT_ROOT." >&2; exit 2; }

REC="${1:-$ROOT/_bmad-output/ai-dlc-update/owed-derivations.tsv}"

# ---- the record: absent is silent 0, unreadable or malformed is 2 --------------------------
# `-e` false is the ONLY absence. Anything that exists and cannot be read in full is a refusal.
[ -e "$REC" ] || [ -L "$REC" ] || exit 0
[ -f "$REC" ] && [ -r "$REC" ] \
  || { echo "REFUSED: the owed-derivations record $REC exists and cannot be read as a file, so what it owes is unknown." >&2; exit 2; }

VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh"
[ -f "$VALIDATOR" ] || VALIDATOR="$SELF_DIR/validate-artifact-derivations.sh"
[ -f "$VALIDATOR" ] || { echo "REFUSED: no validate-artifact-derivations.sh beside this script or under $ROOT/scripts/ai-dlc/, so no row can be re-run." >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-owed-derivations-XXXXXX")" \
  || { echo "REFUSED: could not create a scratch directory." >&2; exit 2; }
cleanup() { rm -f "$TMP"/* 2>/dev/null; rmdir "$TMP" 2>/dev/null; }
trap cleanup EXIT

# Copy first and compare sizes: awk's getline returns -1 on an unopenable file exactly as it returns 0
# on an empty one, so the record is read by cat, whose failure is a status.
cat "$REC" > "$TMP/rec" 2>/dev/null \
  || { echo "REFUSED: could not read $REC in full." >&2; exit 2; }
[ "$(wc -c < "$REC" 2>/dev/null | tr -d ' ')" = "$(wc -c < "$TMP/rec" | tr -d ' ')" ] \
  || { echo "REFUSED: $REC read short, so what it owes is unknown." >&2; exit 2; }

# Validate every line and emit it with \037 between fields (a tab IFS would collapse the empty
# recorded/actual cells). A line that is not exactly seven tab fields with a file:line key, a command
# and a range and log name is malformed, and ONE malformed line refuses the whole record.
awk -F'\t' '
  /^[[:space:]]*$/ { next }
  {
    if (NF != 7 || $1 != "OWED" || $2 !~ /^.+:[0-9]+$/ || $3 == "" || $6 == "" || $7 == "") { bad = NR; exit }
    printf "%s\037%s\037%s\037%s\037%s\037%s\n", $2, $3, $4, $5, $6, $7; n++
  }
  END { if (bad) { print "MALFORMED " bad > "/dev/stderr"; exit 2 } }
' "$TMP/rec" > "$TMP/rows" 2> "$TMP/awk.err"
arc=$?
if [ "$arc" -ne 0 ]; then
  echo "REFUSED: $REC is malformed ($(tr -d '\n' < "$TMP/awk.err")): a row is not seven tab-separated fields OWED, file:line, command, recorded, actual, range, log." >&2
  exit 2
fi

# ---- run the validator ONCE per distinct file ----------------------------------------------
SEP="$(printf '\037')"
: > "$TMP/files"
while IFS="$SEP" read -r _k _rest; do
  printf '%s\n' "${_k%:*}"
done < "$TMP/rows" | sort -u > "$TMP/files"

i=0
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  i=$((i + 1))
  printf '%s\n' "$_f" > "$TMP/f.$i.name"
  if [ -f "$ROOT/$_f" ]; then
    ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$VALIDATOR" "$ROOT/$_f" > /dev/null 2> "$TMP/f.$i.err" )
    printf '%s\n' "$?" > "$TMP/f.$i.rc"
  fi
done < "$TMP/files"
nfiles="$i"

idx_of() { # <rel file> -> index, empty when none
  local j=1
  while [ "$j" -le "$nfiles" ]; do
    [ "$(cat "$TMP/f.$j.name")" = "$1" ] && { printf '%s' "$j"; return; }
    j=$((j + 1))
  done
}

nopen=0
while IFS="$SEP" read -r key cmd _recd _act range logn; do
  [ -n "$key" ] || continue
  rel="${key%:*}"; ln="${key##*:}"
  reason=""
  line=""
  [ -f "$ROOT/$rel" ] && line="$(sed -n "${ln}p" "$ROOT/$rel" 2>/dev/null)"
  # FALSE-ZERO GUARD: the line must be a `$ ` command equal to the recorded one.
  stripped="${line#"${line%%[![:blank:]]*}"}"
  stripped="$(printf '%s' "$stripped" | tr '\t' ' ')"
  if [ ! -f "$ROOT/$rel" ] || [ "${stripped#\$ }" = "$stripped" ] || [ "${stripped#\$ }" != "$cmd" ]; then
    reason="MOVED"
  else
    j="$(idx_of "$rel")"
    err="$TMP/f.$j.err"; abs="$ROOT/$rel"
    rc="$(cat "$TMP/f.$j.rc" 2>/dev/null)"
    if [ "$rc" != 0 ] && [ "$rc" != 1 ]; then
      reason="UNASSESSED"
    else
      target="$ln"
      sup="$(sed -n "s|^SUPERSEDED: ${abs}:${ln} by ${abs}:\([0-9][0-9]*\)\$|\1|p" "$err" 2>/dev/null | head -1)"
      if [ -n "$sup" ]; then
        target="$sup"
        if grep -qE "^(FAIL \([A-Z-]+\)|UNRUN): $(printf '%s' "${abs}:${target} " | sed 's/[][\.*^$/]/\\&/g')" "$err"; then reason="SUPERSEDED-STALE"; fi
      else
        if grep -qE "^FAIL \([A-Z-]+\): $(printf '%s' "${abs}:${target} " | sed 's/[][\.*^$/]/\\&/g')" "$err"; then reason="STALE"
        elif grep -qE "^UNRUN: $(printf '%s' "${abs}:${target} " | sed 's/[][\.*^$/]/\\&/g')" "$err"; then reason="UNRUN"; fi
      fi
    fi
  fi
  if [ -n "$reason" ]; then
    nopen=$((nopen + 1))
    printf 'OPEN\t%s\t%s\t$ %s\t%s\t%s\n' "$key" "$reason" "$cmd" "$range" "$logn"
  fi
done < "$TMP/rows"

[ "$nopen" -eq 0 ] && exit 0
exit 1
