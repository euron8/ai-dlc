#!/usr/bin/env bash
# check-owed-derivations.sh — which derivations did an earlier pull LEAVE broken, and are they still?
#
# Usage: check-owed-derivations.sh [<record>]
#        check-owed-derivations.sh --scope <rel-path>
#   <record> defaults to `_bmad-output/ai-dlc-update/owed-derivations.tsv` under the project root,
#   which is the file `reconcile/derivation-differential.sh --record-owed` appends to.
#
# Output on STDOUT, one tab-separated line per row:
#   OPEN <key file:line> <reason> <$ command> <base>..<theirs> <reconcile log name>
#       <reason> is STALE | UNRUN | SUPERSEDED-STALE | MOVED | UNASSESSED, prefixed REPOINTED- when
#       the row was re-pointed and the NEW derivation is the one judged (its command is shown).
#   INFO past-sprint <key> <detail>
#       a row whose file is in a sprint that has since finished. Unrepaired debt that is no longer
#       enforced. It is NOT closed, and it never counts toward exit 1.
# Exit:   0 no open row, or no record at all (silent)
#         1 one or more OPEN rows
#         2 the record is unreadable or malformed, or the current sprint cannot be resolved. A
#           REFUSAL, distinct from an absent record: an absent record owes nothing, an unreadable one
#           has not been shown to owe nothing.
#
# RECORD GRAMMAR (append-only, no status cell, tab-separated):
#   OWED        <key file:line> <command> <recorded> <actual> <base>..<theirs> <log>   (the writer)
#   REPOINTED   <old key> <new file:line> $ <new command>                                (the re-pointer)
# A REPOINTED row names where a derivation went. It closes nothing by itself: the reader follows the
# LATEST REPOINTED for a key (and the latest for that target, and so on) and JUDGES THE NEW DERIVATION
# with the same content-location and fenced check, on every read.
#
# SCOPE IS CURRENT SPRINT ONLY (operator ruling). `--scope <rel-path>` prints CURRENT | LIVING | PAST and
# is the ONE definition: the writer (reconcile/derivation-differential.sh --record-owed) calls it for each
# NEWLY-FAILING row, and this script calls it for each row on read, so a row recorded while its sprint was
# current reads INFO once the sprint rolls. Only OPEN rows block anything.
#
# OPENNESS IS DERIVED FROM THE TREE, NEVER FROM THE RECORD. A row is open iff the installed validator,
# re-run on that row's OWN file, still reports that derivation failing. It closes by re-pointing the
# derivation, never by writing a word, so prose saying "done" beside a still-failing derivation changes
# nothing.
#
# THE VERDICT STREAM IS STDERR, AND A REPRODUCING DERIVATION PRINTS NOTHING ON IT. So "no line for this
# key" means closed only when the key names a real `$ ` command line inside a derived fence. The row is
# therefore LOCATED BY CONTENT: the `$ ` lines inside a derived fence whose text equals the command.
# Zero matches: MOVED (open). One: that line is judged, so a shifted line is tolerated. Several: the
# recorded line number breaks the tie when it is one of them; otherwise the row cannot be placed and the
# run refuses with exit 2. A command in a text fence is no match, because the validator never reads it.
#
# JOIN RULE for the located line K, in order:
#   (a) the validator exited 2 over K's file: unassessed (UNASSESSED), open, never closed. An UNRUN
#       derivation anywhere in that file makes the validator exit 2, so it unassesses EVERY owed row in
#       the file; run or remove that derivation;
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

# ---- the scope classifier: ONE place ------------------------------------------------------------
# A path is in a sprint ONLY through an anchored `s<digits>` directory segment directly under one of
# these sprint areas. The precedent is core/scripts/join-remediator-shards.sh: line 182 says a subject
# "spans `planning-artifacts/`, `planning-artifacts/s<N>/` and `specs/s<N>/`", and its party-mode seats
# live at `<state>/party-mode/s<N>/` (lines 201 and 386). The whole segment is matched, never a
# substring: `s19` is not `s1`, a file named `s319.md` and a directory `s319x/` are no segment, and a
# path with no such segment (prd.md) is LIVING.
SPRINT_AREAS="_bmad-output/planning-artifacts _bmad-output/party-mode _bmad-output/specs"

# The current sprint comes ONLY from sprint-status.sh sprint-id, a sibling of this script (installed at
# scripts/ai-dlc/ beside it, in the distribution at core/scripts/). Unresolved is a refusal: a scope is
# never guessed and never defaulted to PAST.
CUR=""
resolve_sprint() {
  local ss="$SELF_DIR/sprint-status.sh" out
  [ -f "$ss" ] || { echo "REFUSED: no sprint-status.sh beside $0, so the current sprint cannot be resolved. A scope is never guessed." >&2; exit 2; }
  out="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$ss" sprint-id --root "$ROOT" 2>/dev/null)" \
    || { echo "REFUSED: sprint-status.sh sprint-id failed, so the current sprint cannot be resolved. A scope is never guessed." >&2; exit 2; }
  out="$(printf '%s' "$out" | tr -d '[:space:]')"
  case "$out" in
    ''|*[!0-9]*) echo "REFUSED: sprint-status.sh sprint-id printed '${out}', not a sprint number, so the current sprint cannot be resolved." >&2; exit 2 ;;
  esac
  CUR="$out"
}

scope_of() { # <root-relative path> -> CURRENT | PAST | LIVING
  local p="$1" a seg n
  for a in $SPRINT_AREAS; do
    case "$p" in
      "$a"/s*/*)
        seg="${p#"$a"/}"; seg="${seg%%/*}"
        n="${seg#s}"
        case "$n" in ''|*[!0-9]*) continue ;; esac
        if [ "$((10#$n))" -eq "$CUR" ]; then echo CURRENT; else echo PAST; fi
        return 0 ;;
    esac
  done
  echo LIVING
}

if [ "${1:-}" = "--scope" ]; then
  [ "$#" -eq 2 ] && [ -n "$2" ] || { echo "usage: check-owed-derivations.sh --scope <rel-path>" >&2; exit 2; }
  resolve_sprint
  scope_of "$2"
  exit 0
fi

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
# recorded/actual cells). ONE malformed line refuses the whole record.
: > "$TMP/rows"; : > "$TMP/repoints"
awk -F'\t' -v rf="$TMP/rows" -v pf="$TMP/repoints" '
  /^[[:space:]]*$/ { next }
  {
    ok = 0; kind = 0
    if ($1 == "OWED") {
      kind = 1
      ok = (NF == 7 && $2 ~ /^.+:[0-9]+$/ && $3 != "" && $6 != "" && $7 != "")
    } else if ($1 == "REPOINTED") {
      kind = 2
      ok = (NF == 4 && $2 ~ /^.+:[0-9]+$/ && $3 ~ /^.+:[0-9]+$/ && substr($4, 1, 2) == "$ " && length($4) > 2)
    }
    if (!ok) { bad = NR; exit }
    if (kind == 1) printf "%s\037%s\037%s\037%s\037%s\037%s\n", $2, $3, $4, $5, $6, $7 > rf
    else if (kind == 2) printf "%s\037%s\037%s\n", $2, $3, substr($4, 3) > pf
  }
  END { if (bad) { print "MALFORMED " bad > "/dev/stderr"; exit 2 } }
' "$TMP/rec" 2> "$TMP/awk.err"
arc=$?
if [ "$arc" -ne 0 ]; then
  echo "REFUSED: $REC is malformed ($(tr -d '\n' < "$TMP/awk.err")): a row is not OWED with seven tab-separated fields (file:line, command, recorded, actual, range, log) or REPOINTED with four (old key, new file:line, \$ command)." >&2
  exit 2
fi

# Nothing owed: no scope to resolve and no validator to run.
[ -s "$TMP/rows" ] || exit 0
resolve_sprint

SEP="$(printf '\037')"

# ---- pass 1: scope each row and follow its REPOINTED chain to the derivation that will be judged ----
repoint_of() { # <key> -> "<new key><SEP><new command>" for the LATEST REPOINTED naming <key>, else empty
  K="$1" awk -F "$SEP" 'BEGIN { k = ENVIRON["K"] } $1 == k { n = $2; c = $3 } END { if (n != "") printf "%s\037%s", n, c }' "$TMP/repoints"
}
: > "$TMP/targets"; : > "$TMP/files.raw"
while IFS="$SEP" read -r key cmd _recd _act range logn; do
  [ -n "$key" ] || continue
  sc="$(scope_of "${key%:*}")"
  tkey="$key"; tcmd="$cmd"; hops=0; cyc=0
  while :; do
    nx="$(repoint_of "$tkey")"
    [ -n "$nx" ] || break
    hops=$((hops + 1))
    [ "$hops" -le 20 ] || { cyc=1; break; }
    tkey="${nx%%"$SEP"*}"; tcmd="${nx#*"$SEP"}"
  done
  printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n' "$key" "$cmd" "$range" "$logn" "$sc" "$tkey" "$tcmd" "$hops" "$cyc" >> "$TMP/targets"
  if [ "$sc" != PAST ] && [ "$cyc" = 0 ]; then printf '%s\n' "${tkey%:*}" >> "$TMP/files.raw"; fi
done < "$TMP/rows"
sort -u "$TMP/files.raw" > "$TMP/files"

# ---- run the validator ONCE per distinct file that will be judged ----------------------------
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

# FIXED-STRING MATCHING, NEVER A REGEX BUILT FROM A PATH. A path carrying ( ) + ? { } | made a grep -E
# exit 2, which reads as "no match" and CLOSED the row. awk index() compares bytes, and the prefix
# travels by ENVIRON because awk -v strips one level of backslash escaping.
verdict_has() { # <stderr file> <fail|unrun|any> <prefix after the head>
  P="$3" awk -v kind="$2" 'BEGIN { p = ENVIRON["P"] }
    kind != "unrun" && match($0, /^FAIL \([A-Z-]+\): /) && index(substr($0, RLENGTH + 1), p) == 1 { f = 1 }
    kind != "fail" && substr($0, 1, 7) == "UNRUN: " && index(substr($0, 8), p) == 1 { f = 1 }
    END { exit f ? 0 : 1 }' "$1"
}
superseded_by() { # <stderr file> <abs:ln> -> the later line number, empty when not superseded
  P="SUPERSEDED: $2 by ${2%:*}:" awk 'BEGIN { p = ENVIRON["P"] }
    index($0, p) == 1 { r = substr($0, length(p) + 1); if (r ~ /^[0-9]+$/) { print r; exit } }' "$1"
}
# derived_cmd_lines <file> <command> -> the line number of every `$ ` line that sits inside a derived
# fence and whose text equals <command>. A command in any other fence (a text fence) is one the
# validator never reads, so it has no verdict at all and is not a match. The command travels by
# ENVIRON (awk -v strips a level of backslash escaping) and is compared with ==, never as a regex.
derived_cmd_lines() {
  C="$2" awk 'BEGIN { st = 0; fc = sprintf("%c%c%c", 96, 96, 96); want = ENVIRON["C"] }
    { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t) }
    st == 0 && substr(t, 1, 3) == fc { st = (t == fc "derived") ? 2 : 1; next }
    st != 0 && substr(t, 1, 3) == fc { st = 0; next }
    st == 2 && substr(t, 1, 2) == "$ " && substr(t, 3) == want { print NR }' "$1"
}

# ---- pass 2: judge ----------------------------------------------------------------------------
nopen=0
while IFS="$SEP" read -r key cmd range logn sc tkey tcmd hops cyc; do
  [ -n "$key" ] || continue
  if [ "$sc" = PAST ]; then
    printf 'INFO\tpast-sprint\t%s recorded in a sprint that has since finished: unrepaired debt that is no longer enforced, NOT closed ($ %s; %s; %s)\n' "$key" "$cmd" "$range" "$logn"
    continue
  fi
  rel="${tkey%:*}"; ln="${tkey##*:}"
  pre=""; [ "$hops" -gt 0 ] && pre="REPOINTED-"
  reason=""
  # THE DERIVATION IS LOCATED BY CONTENT, NOT BY LINE NUMBER (see the header). A re-pointed row is judged
  # as the NEW derivation: its own file, its own command, the same checks.
  found=""; nfound=0
  if [ "$cyc" != 1 ] && [ -f "$ROOT/$rel" ]; then
    found="$(derived_cmd_lines "$ROOT/$rel" "$tcmd")" \
      || { echo "REFUSED: could not scan $rel for the recorded command, so the row $key cannot be placed." >&2; exit 2; }
    [ -n "$found" ] && nfound="$(printf '%s\n' "$found" | awk 'END { print NR + 0 }')"
  fi
  if [ "$nfound" -gt 1 ]; then
    if printf '%s\n' "$found" | grep -qxF -- "$ln"; then nfound=1; found="$ln"
    else echo "REFUSED: $rel carries $nfound derived-fence copies of the recorded command for $key and none is at the recorded line, so the row cannot be placed." >&2; exit 2; fi
  fi
  if [ "$nfound" -eq 0 ]; then
    reason="MOVED"
  else
    ln="$found"
    j="$(idx_of "$rel")"
    err="$TMP/f.$j.err"; abs="$ROOT/$rel"
    rc="$(cat "$TMP/f.$j.rc" 2>/dev/null)"
    if [ "$rc" != 0 ] && [ "$rc" != 1 ]; then
      reason="UNASSESSED"
    else
      target="$ln"
      sup="$(superseded_by "$err" "${abs}:${ln}")"
      if [ -n "$sup" ]; then
        target="$sup"
        verdict_has "$err" any "${abs}:${target} " && reason="SUPERSEDED-STALE"
      else
        if verdict_has "$err" fail "${abs}:${target} "; then reason="STALE"
        elif verdict_has "$err" unrun "${abs}:${target} "; then reason="UNRUN"; fi
      fi
    fi
  fi
  if [ -n "$reason" ]; then
    nopen=$((nopen + 1))
    printf 'OPEN\t%s\t%s%s\t$ %s\t%s\t%s\n' "$key" "$pre" "$reason" "$tcmd" "$range" "$logn"
  fi
done < "$TMP/targets"

[ "$nopen" -eq 0 ] && exit 0
exit 1
