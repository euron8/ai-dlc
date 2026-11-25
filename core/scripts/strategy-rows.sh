#!/usr/bin/env bash
# strategy-rows.sh -- derive the test-strategy ids and lettered case rows from the stories' acceptance criteria.
#
# Usage: strategy-rows.sh --sprint <N> --stories-dir <dir> [--rows | --bind | --check | --check-strategy <test-strategy.md>]
#
# Stories-test-strategy §5. The strategy id of an acceptance criterion and the letters of its cases are
# mechanical, so a script writes them and a seat does not:
#   - stories are taken in story order, the numeric order of the frontmatter `id:` (`S323-1.1`, `S323-1.2`, ... `S323-5.5`);
#   - every `- **AC<n>` line in a story opens one acceptance criterion, which gets the next id `ST<N>-<k>`, `k` running
#     over the whole sprint from 1;
#   - an AC gets lettered cases exactly when its own text enumerates its own sub-items as parenthesized lowercase letters
#     in sequence from `(a)`, at least `(a)` and `(b)`. A `(x)` directly after a letter, digit, `_` or `)` (`AC3(c)`,
#     `f(a)`), after the word Rule, option, story, FR, AD, step, item, section or arm (any case of the first letter) alone
#     or as an id with hyphenated segments (`FR-S324-2 (a)`, `AD-12 (b)`), or after the word answer, is a citation and is
#     not counted. Every other AC is one row with Case `-`.
#
#   --letters <story id>:AC<n>=<k>   (repeatable) force k lettered cases on one AC whose text names a case it does not
#                       letter (`S323-5.4:AC2=3`: "(a), (b) and the security-critical case"); the strategy says so where it uses it.
#
# MODES (exactly one; default --rows)
#   --rows              print `| Strategy id | Case | Story id |` rows, one per bindable case, in story order.
#   --bind              write each story's `## Strategy Test IDs` table: header, separator, one row per case with Kind and
#                       Resolves-to EMPTY (the dev fills them). Refuses (exit 3) a table that already has a filled Kind or
#                       Resolves-to cell; rewrites an empty or id-only table in place.
#   --check             compare each story's table (ids and cases, not Kind or Resolves-to) with the derived rows; exit 1 on
#                       any difference, naming it.
#   --check-strategy F  compare the mapping rows in the strategy document F (lines of the form `| ST<N>-<k> | <case> | <story id> |`)
#                       with the derived rows; exit 1 on any difference, naming it.
# --check and --check-strategy read PENDING (exit 0) when a story table already has a filled Kind or Resolves-to cell, and
# --check-strategy when the strategy carries no mapping row of the grammar: such a series is past authoring or older than this
# grammar and is never a difference.
# Exit: 0 ok or PENDING, 1 difference, 2 usage or an unreadable input, 3 --bind refused.
sr_main() {
set -u
LC_ALL=C; export LC_ALL
# The era token (core/scripts/era-token.sh, the one definition): --bind writes it as its own whole line ahead of every table it
# writes, and strategy-self-check.sh judges the Kind vocabulary only in a story whose Strategy Test IDs section carries that line.
# shellcheck source=era-token.sh
. "$(dirname "${BASH_SOURCE[0]:-$0}")/era-token.sh" || { echo "strategy-rows: cannot source era-token.sh beside this script" >&2; exit 2; }
ERA_TOKEN="$AI_DLC_ERA_TOKEN"

MODE=rows; SPRINT=""; DIR=""; STRAT=""; OVR=" "
while [ $# -gt 0 ]; do
  case "$1" in
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --stories-dir) DIR="${2:-}"; shift 2 ;;
    --rows) MODE=rows; shift ;;
    --bind) MODE=bind; shift ;;
    --check) MODE=check; shift ;;
    --check-strategy) MODE=strategy; STRAT="${2:-}"; shift 2 ;;
    --letters) OVR="$OVR${2:-} "; shift 2 ;;
    *) echo "strategy-rows: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
case "$SPRINT" in ''|*[!0-9]*) echo "strategy-rows: --sprint <N> is required and numeric" >&2; exit 2 ;; esac
[ -d "$DIR" ] || { echo "strategy-rows: --stories-dir '$DIR' is not a directory" >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/strategy-rows.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT

# Story files in story order: a sort key from the frontmatter id.
: > "$TMP/order"
n=0
for f in "$DIR"/*.md; do
  [ -f "$f" ] || continue
  id="$(awk 'NR==1 && $0!="---"{exit} /^id:/{print $2; exit}' "$f")"
  [ -n "$id" ] || continue
  key="${id#*-}"
  ep="${key%%.*}"; st="${key#*.}"
  case "$ep$st" in ''|*[!0-9]*) echo "strategy-rows: $f: id '$id' is not S<N>-<epic>.<story>" >&2; exit 2 ;; esac
  printf '%05d%05d\t%s\t%s\n' "$ep" "$st" "$id" "$f" >> "$TMP/order"
  n=$((n + 1))
done
[ "$n" -gt 0 ] || { echo "strategy-rows: no story file with a frontmatter id under $DIR" >&2; exit 2; }
sort "$TMP/order" > "$TMP/order.s"

# Derive: story-id <TAB> ST id <TAB> case, from the ACs.
: > "$TMP/derived"
k=0
while IFS="$(printf '\t')" read -r _ id f; do
  awk -v sp="$SPRINT" -v sid="$id" -v k0="$k" -v ovr="$OVR" '
    function flush(   s, tok, pre, nl, cnt) {
      if (!inac) return
      k++
      s = blk; nl = 1; cnt = 0; delete seen
      while (match(s, /\([a-z]\)/)) {
        tok = substr(s, RSTART + 1, 1); pre = substr(s, 1, RSTART - 1)
        s = substr(s, RSTART + RLENGTH)
        if (pre ~ /[A-Za-z0-9_)]$/) continue
        if (pre ~ /([Rr]ule|[Oo]ption|[Ss]tory|FR|AD|[Ss]tep|[Ii]tem|[Ss]ection|[Aa]rm)(-[A-Za-z0-9.]+)* $/) continue
        if (pre ~ /[Aa]nswer $/) continue
        if (tok == "a" && !(1 in seen) && pre ~ /(of|to|in|for|by|from|at|on|with|per|see|under|than|against) $/) continue
        seen[index("abcdefghijklmnopqrstuvwxyz", tok)] = 1
      }
      while (nl in seen) { nl++; cnt++ }
      if (match(blk, /AC[0-9]+/)) {
        lab = sid ":" substr(blk, RSTART, RLENGTH) "="
        if (i = index(ovr, " " lab)) { cnt = substr(ovr, i + 1 + length(lab)) + 0 }
      }
      if (cnt >= 2) { for (i = 1; i <= cnt; i++) printf "%s\tST%s-%d\t%s\n", sid, sp, k, substr("abcdefghijklmnopqrstuvwxyz", i, 1) }
      else printf "%s\tST%s-%d\t-\n", sid, sp, k
      inac = 0; blk = ""
    }
    BEGIN { k = k0 }
    /^- \*\*AC[0-9]+/ { flush(); inac = 1; blk = $0; next }
    /^#/ { flush(); next }
    { if (inac) blk = blk "\n" $0 }
    END { flush(); print k > "/dev/stderr" }
  ' "$f" >> "$TMP/derived" 2> "$TMP/k" || exit 2
  k="$(tail -1 "$TMP/k")"
done < "$TMP/order.s"
[ -s "$TMP/derived" ] || { echo "strategy-rows: no '- **AC<n>' line in any story under $DIR" >&2; exit 2; }

# A table with a filled Kind or Resolves-to cell is past authoring (the dev's work, ACs amended since): the two --check
# modes read PENDING there, never a difference.
FILLED_ANY=0
while IFS="$(printf '\t')" read -r _ _ f; do
  r="$(awk -F'|' '
    function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
    /^## Strategy Test IDs[ \t]*$/ { sec = 1; next }
    /^## / { sec = 0 }
    sec && /^\|/ { c1 = trim($2); if (c1 == "Strategy id" || c1 ~ /^-+$/) next; if (trim($4) != "" || trim($5) != "") { print "F"; exit } }
  ' "$f")"
  [ -z "$r" ] || { FILLED_ANY=1; break; }
done < "$TMP/order.s"
pending() { echo "strategy-rows: PENDING -- $1"; exit 0; }
case "$MODE:$FILLED_ANY" in
  check:1|strategy:1) pending "a Strategy Test IDs table already carries a filled Kind or Resolves-to cell; the story is past authoring and this mode judges authoring-time tables only" ;;
esac

case "$MODE" in
  rows)
    awk -F'\t' '{ printf "| %s | %s | %s |\n", $2, $3, $1 }' "$TMP/derived"
    ;;
  strategy)
    [ -f "$STRAT" ] || { echo "strategy-rows: --check-strategy '$STRAT' is not a file" >&2; exit 2; }
    awk -F'\t' '{ printf "| %s | %s | %s |\n", $2, $3, $1 }' "$TMP/derived" | sort > "$TMP/want"
    grep -E "^\| ST${SPRINT}-[0-9]+ \| ([a-z]|-) \| S${SPRINT}-[0-9]+\.[0-9]+ \|\$" "$STRAT" | sort > "$TMP/have"
    [ -s "$TMP/have" ] || pending "$STRAT carries no mapping row of the \`| ST${SPRINT}-<k> | <case> | <story id> |\` grammar (a strategy written before this grammar)"
    if cmp -s "$TMP/want" "$TMP/have"; then
      echo "strategy-rows: ok -- $(wc -l < "$TMP/want" | tr -d ' ') mapping row(s) in $STRAT equal the derived rows"; exit 0
    fi
    echo "strategy-rows: DIFFERENT -- '<' derived from the ACs only, '>' in $STRAT only:" >&2
    diff "$TMP/want" "$TMP/have" >&2 || true
    exit 1
    ;;
  check|bind)
    rc=0
    while IFS="$(printf '\t')" read -r _ id f; do
      awk -F'\t' -v sid="$id" '$1 == sid { printf "| %s | %s |\n", $2, $3 }' "$TMP/derived" > "$TMP/want.$$"
      awk '
        /^## Strategy Test IDs[[:space:]]*$/ { sec = 1; next }
        /^## / { sec = 0 }
        sec && /^\|/ { print }
      ' "$f" > "$TMP/have.raw.$$"
      # data rows only: drop the header and the separator
      awk -F'|' '
        function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
        { c1 = trim($2); if (c1 == "Strategy id" || c1 ~ /^-+$/) next
          printf "| %s | %s |\n", c1, trim($3)
          if (trim($4) != "" || trim($5) != "") filled = 1 }
        END { if (filled) print "FILLED" > "/dev/stderr" }
      ' "$TMP/have.raw.$$" > "$TMP/have.$$" 2> "$TMP/filled.$$"
      if [ "$MODE" = check ]; then
        if ! cmp -s "$TMP/want.$$" "$TMP/have.$$"; then
          echo "strategy-rows: DIFFERENT $f (id $id): '<' derived, '>' in the table:" >&2
          diff "$TMP/want.$$" "$TMP/have.$$" >&2 || true
          rc=1
        fi
      else
        if [ -s "$TMP/filled.$$" ]; then
          echo "strategy-rows: REFUSED $f: the table has a filled Kind or Resolves-to cell; --bind never overwrites the dev's work" >&2
          rc=3; continue
        fi
        awk -v want="$TMP/want.$$" -v tok="$ERA_TOKEN" '
          function emit(   l) {
            print tok; print ""
            print "| Strategy id | Case | Kind | Resolves to |"; print "|---|---|---|---|"
            while ((getline l < want) > 0) print substr(l, 1, length(l) - 2) " |  |  |"
            close(want); done = 1
          }
          /^## Strategy Test IDs[[:space:]]*$/ { print; sec = 1; print ""; next }
          sec && /^## / { if (!done) emit(); print ""; sec = 0 }
          sec && $0 == tok { next }
          sec && /^\|/ { if (!done) emit(); next }
          sec && /^[[:space:]]*$/ { next }
          { print }
          END { if (sec && !done) emit() }
        ' "$f" > "$TMP/new.$$" && cat "$TMP/new.$$" > "$f"
      fi
      rm -f "$TMP/want.$$" "$TMP/have.raw.$$" "$TMP/have.$$" "$TMP/filled.$$" "$TMP/new.$$"
    done < "$TMP/order.s"
    if [ "$MODE" = check ] && [ "$rc" -eq 0 ]; then
      echo "strategy-rows: ok -- every story's Strategy Test IDs ids and cases equal the derived rows"
    fi
    exit "$rc"
    ;;
esac
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
sr_main "$@"
