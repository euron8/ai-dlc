#!/usr/bin/env bash
# fork-profile.sh -- count the external commands one run of a shell script actually spawns,
# and attribute them to source lines and to invariant arms.
#
# WHY THIS EXISTS. scripts/validate-enforcement-map.sh states its own cost in a comment above
# `in_lines`: "One run of it forks 1582 external commands -- 643 of them `grep`". Nothing read
# that sentence. Re-measured with this instrument the number is an order of magnitude larger,
# and the suite runs that script well over a hundred times per full push, so its fork count is
# a large fraction of everything the fixture suite computes. A number a file states about
# itself and no program checks is a number that decays silently and reads identically to a
# fresh one. This is the reader; the budget it feeds lives beside the comment that decayed.
#
# WHY DYNAMIC AND NOT STATIC. The subject embeds awk programs and python heredocs carrying
# their own `for`/`while` keywords, so a shell-shaped static parser mis-nests it; and a static
# token count under-reports runtime invocations by an order of magnitude, because the
# multipliers are corpus-derived loop trip counts that only exist at run time.
#
# WHY `@N@` AND NOT `BASH_XTRACEFD`. BASH_XTRACEFD arrived in bash 4.1 and this box has 3.2
# (`/bin/bash --version`). So xtrace and the subject's own stderr share fd 2 and cannot be
# separated by fd. They are separated by SHAPE instead: `PS4='+@${LINENO}@ '` makes every
# trace line start with a run of `+` (bash repeats PS4's first character once per subshell
# depth), then `@`, the source line, `@`, a space. The subject's own `err()` output is
# `FAIL: ...` and cannot match that.
#
# THE KNOWN UNDERCOUNT, STATED SO NOBODY RE-DERIVES IT. Each `$( )` costs a subshell fork
# PLUS the traced inner command, and only the inner one is visible in the trace; a bare
# `( ... )` subshell is likewise invisible. It is a constant-shape bias -- it does not affect
# the RANKING of lines or arms, and it cancels in a like-for-like comparison, which is all the
# budget gate ever asks. Do not chase it.
#
# Usage: fork-profile.sh [--target <script>] [--section total|by-line|by-arm|all]
#                        [--stable] [--dump <dir>] [--probe-only]
#        --stable   re-profile until a total repeats and report the largest such reading.
#                   Use it for anything that GATES; see the corpus section for the measurement
#                   that makes a single reading occasionally one fork low.
# Exit:  0 = profiled, 1 = a self-probe failed, 2 = usage or environment,
#        3 = --stable could not get the instrument to repeat itself.
set -uo pipefail

TARGET=""
SECTION=all
DUMP=""
STABLE=0
USAGE="usage: $(basename "$0") [--target <script>] [--section total|by-line|by-arm|all] [--stable] [--dump <dir>] [--probe-only]"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)  TARGET="${2:-}"; shift 2 || exit 2 ;;
    --section) SECTION="${2:-}"; shift 2 || exit 2 ;;
    --dump)    DUMP="${2:-}"; shift 2 || exit 2 ;;
    --stable)  STABLE=1; shift ;;
    --probe-only) SECTION=probe-only; shift ;;
    *) echo "$USAGE" >&2; exit 2 ;;
  esac
done
case "$SECTION" in total|by-line|by-arm|all|probe-only) : ;; *)
  echo "fork-profile: unknown --section '$SECTION'" >&2; exit 2 ;;
esac

# ROOT BY WALKING UP FOR A MARKER, never by counting `..` hops, so this answers identically
# from the repo root, from a subdirectory, and from a sandbox that copied it.
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ ! -f "$ROOT/VERSION" ] && [ "$ROOT" != "/" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "fork-profile: no VERSION marker above $(dirname "$0") -- cannot locate the repo root." >&2
  exit 2
fi
[ -n "$TARGET" ] || TARGET="$ROOT/scripts/validate-enforcement-map.sh"
[ -f "$TARGET" ] || { echo "fork-profile: no such target: $TARGET" >&2; exit 2; }

RENDERER="$ROOT/scripts/render-invariant-index.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------------------
# THE CLASSIFIER. Token 1 after the marker, against three sets:
#   * bash builtins and keywords, derived with `compgen -b` / `compgen -k` -- never a hand
#     list, because a hand list of builtins is one more thing that goes stale;
#   * the target script's OWN function names, derived from the target;
#   * everything else = one fork.
# So `in_lines`, `in_body` and `i87_readable` -- the fork-free helpers the subject added for
# exactly this reason -- score zero, which is the whole point of measuring rather than
# counting call sites.
#
# AN ASSIGNMENT-SHAPED TOKEN 1 ENDS THE LINE AT ZERO, and that is a measurement rather than a
# convenience. On bash 3.2 an assignment NEVER shares a traced line with the command it
# prefixes: `a=1 b=2` traces as two lines, `LC_ALL=C /usr/bin/true` traces as `LC_ALL=C` then
# `/usr/bin/true`, and `x=$(cmd)` traces the inner command at depth+1 and then `x=<value>`.
# So there is nothing after an assignment to look at -- and looking anyway is WRONG, because
# `c="hello world"` traces as `c='hello world'` and whitespace-splitting makes `world'` the
# second field. Counting token 1 blindly instead would score every assignment as a fork.
#
# TOKEN 1 IS UNQUOTED FIRST. bash quotes any traced word containing a metacharacter, so the
# `[` builtin appears as `'['` and would otherwise be scored as an external command -- once
# per loop iteration. That single omission read as 81 forks on a probe built to produce 50.
#
# REDIRECTIONS NEED NO HANDLING: measured, they do not appear in the trace at all. `: > f`
# traces as `:` and `cmd > f` traces as `cmd`. A guard for them would have no subject.
# ---------------------------------------------------------------------------------------
CLASSIFY_AWK='
BEGIN { total = 0; ntrace = 0; maxline = 0 }
NR == FNR { known[$1] = 1; next }
{
  if ($1 !~ /^\++@[0-9]+@$/) next
  ln = $1
  sub(/^\++@/, "", ln)
  sub(/@$/, "", ln)
  ln = ln + 0
  ntrace++
  if (ln > maxline) maxline = ln
  if (NF < 2) next
  cmd = $2
  sub(/^\$?\047/, "", cmd)
  sub(/\047$/, "", cmd)
  if (cmd ~ /^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?=/) next
  if (cmd in known) next
  # KEYED ON (line, command), NOT ON LINE. A pipeline`s stages are separate processes and
  # bash emits their trace lines in whatever order they start, so `grep ... | sort` on one
  # source line writes `grep` and `sort` in a nondeterministic order. Recording one label per
  # line made the COUNTS stable and the LABELS flap -- which is precisely the shape that turns
  # a gate into the flaky thing people push past. One row per pair, and the sort key is total.
  forks[ln SUBSEP cmd]++
  total++
}
END {
  for (k in forks) { split(k, p, SUBSEP); printf "%d %d %s\n", forks[k], p[1], p[2] }
  printf "META %d %d %d\n", total, ntrace, maxline > metafile
}
'

# `compgen` is a bash builtin and is available non-interactively. Both lists are DERIVED, never
# hand-written, because a hand list of bash builtins is one more thing that silently goes stale.
# THE GUARD AGAINST AN EMPTY LIST IS THE NEGATIVE PROBE, not a count here: with no builtins the
# fork-free probe's `printf`, `case` and `[[` all score as forks and it reports more than 0,
# which is exactly the reading that probe exists to refuse.
known_set() { # <script> -> the names that are NOT a fork, one per line
  { compgen -b; compgen -k; } 2>/dev/null
  # BLANKS-TOLERANT, for the same reason the arm-header grammar is: an indented definition is
  # still a definition, and a reader anchored to column 0 silently scores its calls as forks.
  # `function name()` (awk) and `def name():` (python) inside the embedded programs cannot
  # match, because both put a keyword before the name.
  grep -oE '^[[:blank:]]*[A-Za-z_][A-Za-z0-9_-]*\(\)' "$1" | tr -d '[:blank:]()'
}

profile() { # <script> <outdir> -> outdir/{trace,by-line,meta}; echoes nothing
  local src="$1" out="$2"
  mkdir -p "$out"
  known_set "$src" | LC_ALL=C sort -u > "$out/known"
  # NO PIPE. The exit status of a pipeline's first stage is unavailable in the shell this is
  # driven from, and `grep -q` fed from a pipe answers with the writer's EPIPE. The trace goes
  # to a file and is read from the file.
  PS4='+@${LINENO}@ ' bash -x "$src" >/dev/null 2>"$out/trace"
  echo "$?" > "$out/rc"
  awk -v metafile="$out/meta" "$CLASSIFY_AWK" "$out/known" "$out/trace" \
    | LC_ALL=C sort -k1,1nr -k2,2n -k3,3 > "$out/by-line"
  # A trace file with no META line means awk never reached END -- fail closed rather than
  # letting a missing file read as zero.
  [ -s "$out/meta" ] || { echo "fork-profile: classifier produced no META for $src" >&2; return 2; }
  return 0
}

meta_field() { awk -v f="$2" '$1 == "META" { print $(f + 1) }' "$1/meta"; }

# ---------------------------------------------------------------------------------------
# SELF-PROBE, BEFORE THE CORPUS, IN BOTH DIRECTIONS. A profiler reporting "10,400 forks"
# without first proving it can report a number it was told in advance has established that it
# ran, not that it counts. Probe trees are mktemp'd; the target is never mutated.
# ---------------------------------------------------------------------------------------
probe_fail() { echo "fork-profile SELF-PROBE FAILED: $1" >&2; exit 1; }

mkdir -p "$WORK/probe"
# POSITIVE: exactly 50 forks, 30 of them from a loop, so a classifier that reads the source
# statically rather than the trace cannot get the number right. Everything else in the file --
# the `while`, the `[`, the arithmetic assignment, the function call, the here-string, the
# `printf` -- must score zero.
{
  echo 'set -u'
  echo 'helper() { /usr/bin/true; }'   # 1 fork per call, and `helper` itself must score 0
  echo 'i=0'
  echo 'while [ "$i" -lt 30 ]; do /usr/bin/true; i=$((i+1)); done'
  echo 'x="abc"'
  echo 'case "$x" in a*) printf "%s\n" "${x#a}" >/dev/null ;; esac'
  echo 'helper'
  n=0; while [ "$n" -lt 19 ]; do echo '/usr/bin/true'; n=$((n + 1)); done
} > "$WORK/probe/pos.sh"

profile "$WORK/probe/pos.sh" "$WORK/probe/pos" || probe_fail "the positive probe did not profile"
pos_n="$(meta_field "$WORK/probe/pos" 1)"
[ "$pos_n" = "50" ] || probe_fail "the positive probe must report exactly 50 forks (30 in a loop, 1 via a function, 19 straight-line), got '$pos_n'. Either the marker stopped matching or the builtin/function sets are wrong."

# NEGATIVE: a script that forks NOTHING must report exactly 0. Without this direction a
# classifier that matched no trace line at all would look identical to one that discriminates.
{
  echo 'set -u'
  echo 'x="abc-def"'
  echo 'y="${x%%-*}"'
  echo 'case "$y" in abc) z=1 ;; *) z=2 ;; esac'
  echo 'if [[ "$z" -eq 1 ]]; then printf "%s\n" "$y" >/dev/null; fi'
  echo 'for w in 1 2 3; do : ; done'
  echo 'in_lines() { case "$2" in *"$1"*) return 0 ;; esac; return 1; }'
  echo 'in_lines abc "$x" || true'
} > "$WORK/probe/neg.sh"

profile "$WORK/probe/neg.sh" "$WORK/probe/neg" || probe_fail "the negative probe did not profile"
neg_n="$(meta_field "$WORK/probe/neg" 1)"
[ "$neg_n" = "0" ] || probe_fail "the fork-free probe must report exactly 0 forks, got '$neg_n'. Something in the builtin/keyword/function sets is not being recognised: $(head -3 "$WORK/probe/neg/by-line" | tr '\n' ';')"
# The negative probe must still have TRACED. A trace of zero lines also reports 0 forks, and
# that is the reading this direction exists to rule out.
neg_t="$(meta_field "$WORK/probe/neg" 2)"
[ "${neg_t:-0}" -ge 8 ] || probe_fail "the fork-free probe traced only ${neg_t:-0} line(s); 0 forks out of no trace is not evidence of 0 forks."

# BOTH PROBE READINGS ARE REPORTED FROM THE SAME INVOCATION that reports TOTAL, so a caller
# cannot end up asserting a probe from one run against a corpus number from another.
printf 'PROBEPOS %s\n' "$pos_n"
printf 'PROBENEG %s\n' "$neg_n"
printf 'PROBENEGTRACE %s\n' "$neg_t"
if [ "$SECTION" = probe-only ]; then exit 0; fi

# ---------------------------------------------------------------------------------------
# THE CORPUS.
#
# XTRACE LOSES A LINE UNDER LOAD, AND THE LOSS IS SUBTRACTIVE. MEASURED, five profiles of one
# unchanged tree on a box at load ~55: three reported 6553 forks / 38266 trace lines and two
# reported 6552 / 38265. Diffed, the low reading's rows are a STRICT SUBSET of the high one's
# -- zero rows present only in the low reading, exactly one present only in the high, and that
# one was `sed`, a single stage of a FOUR-stage pipeline whose other three stages were all
# traced. The three writers of one pipeline share fd 2, and occasionally one of their lines
# does not reach the file.
#
# A lost line can only ever REMOVE a fork; nothing about it can invent one. So the true count
# is the LARGEST reading, and a lower one is instrument loss rather than a program that forked
# less. `--stable` profiles until some total has been seen TWICE and reports the largest such
# value, which makes a spuriously high answer unconstructible (loss cannot add) and a
# spuriously low one require the same line to be lost twice at the same site.
#
# THIS IS NOT A TOLERANCE, and the difference is the whole point. A tolerance would accept a
# real regression smaller than its width. This accepts nothing: it re-reads until the
# instrument repeats itself, and refuses to answer at all if it cannot.
REPS_MAX=1
[ "$STABLE" = 1 ] && REPS_MAX=4

# THE READINGS ARE TAKEN TWO AT A TIME, AND THAT CHANGES THE ORDER, NOT THE EVIDENCE. The
# claim is that a total was REPRODUCED -- two independent profiles of one unchanged target
# agreeing. Nothing in that claim is about when the second profile starts. The number of
# readings, the rule for picking the answer (the largest total seen twice), and the refusal to
# answer at all when nothing repeats are all untouched below.
#
# THE OBJECTION IS THAT CONCURRENCY IS WHAT LOSES TRACE LINES, and it was measured rather than
# argued. 48 profiles of one unchanged tree, 24 each way, interleaved -- 16 each on an idle box
# and 8 each against a herd of twelve concurrent validator runs holding the box at load 17-25,
# which is where the pre-push pool puts it. Every one of the 48 read the same total and every
# SPREAD was a single value: zero losses either way. Wall clock, same runs:
#
#     idle     serial 32-35s   two at a time 17-19s
#     loaded   serial 63-64s   two at a time 34-36s
#
# AND A LOSS CANNOT PRODUCE A WRONG ANSWER HERE, which is why the batch is safe even where the
# measurement above does not reach. A dropped line only ever subtracts, so the readings come
# from {n, n-1} and four of them always contain a repeat -- exit 3 is unconstructible for a
# single-line loss under either order. What a loss costs is one more batch, and two batches of
# two is strictly cheaper than four readings taken one after another.
BATCH=2
rep=0; best=""
: > "$WORK/totals"
while [ "$rep" -lt "$REPS_MAX" ]; do
  # THE FAILURE OF A BACKGROUNDED `profile` CANNOT BE READ FROM ITS EXIT STATUS -- a subshell's
  # status is lost -- so it is recorded as a file and asserted, never assumed.
  batch0=$rep; nb=0
  while [ "$nb" -lt "$BATCH" ] && [ "$rep" -lt "$REPS_MAX" ]; do
    rep=$(( rep + 1 )); nb=$(( nb + 1 ))
    ( profile "$TARGET" "$WORK/run$rep" || : > "$WORK/fail$rep" ) &
  done
  wait
  i=$batch0
  while [ "$i" -lt "$rep" ]; do
    i=$(( i + 1 ))
    [ -f "$WORK/fail$i" ] && exit 2
    printf '%s %s\n' "$(meta_field "$WORK/run$i" 1)" "$i" >> "$WORK/totals"
  done
  best="$(awk '{ c[$1]++; if (c[$1] >= 2 && $1 + 0 > m + 0) m = $1 } END { if (m != "") print m }' "$WORK/totals")"
  [ -n "$best" ] && break
done

if [ "$REPS_MAX" -eq 1 ]; then
  BESTREP=1; N_STABLE=1
else
  if [ -z "$best" ]; then
    echo "fork-profile: $REPS_MAX profiles of an unchanged tree produced no repeated total ($(awk '{printf "%s ", $1}' "$WORK/totals"))." >&2
    echo "  A single dropped xtrace line is expected under load and is subtractive; this is something else." >&2
    exit 3
  fi
  BESTREP="$(awk -v t="$best" '$1 == t { print $2; exit }' "$WORK/totals")"
  N_STABLE="$(awk -v t="$best" '$1 == t { n++ } END { print n + 0 }' "$WORK/totals")"
fi
RUN="$WORK/run$BESTREP"
SPREAD="$(awk '{ if (lo == "" || $1 + 0 < lo + 0) lo = $1; if ($1 + 0 > hi + 0) hi = $1 } END { print lo "-" hi }' "$WORK/totals")"

TOTAL="$(meta_field "$RUN" 1)"
NTRACE="$(meta_field "$RUN" 2)"
MAXLINE="$(meta_field "$RUN" 3)"
RC="$(cat "$RUN/rc")"
NFUNC="$(grep -c . "$RUN/known")"

# The arm join. THE GRAMMAR IS SERVED BY THE RENDERER, never re-grepped here: a column-0
# pattern finds 83 of the header-shaped lines in the subject and the shipped grammar finds 91,
# and the ones it drops are silently merged into the preceding arm's bucket. `--arm-lines`
# runs the renderer's own self-probe and totality assertions before it answers, so a grammar
# that stopped parsing fails closed instead of attributing every fork to the prologue.
LASTARM=0
ARMS="$WORK/arms"
: > "$ARMS"
if [ -x "$RENDERER" ] || [ -f "$RENDERER" ]; then
  if bash "$RENDERER" --arm-lines 2>"$WORK/arms.err" \
       | sed 's/[[:blank:]]*\/[[:blank:]]*/\//g' | tr '\t' ' ' > "$ARMS"; then :; fi
fi
if [ -s "$ARMS" ]; then
  LASTARM="$(awk 'END { print $1 }' "$ARMS")"
fi

emit_by_arm() {
  if [ ! -s "$ARMS" ]; then
    echo "fork-profile: no arm map available (${RENDERER} --arm-lines produced nothing); by-arm suppressed rather than reported as one bucket." >&2
    return 1
  fi
  awk '
    NR == FNR { n++; al[n] = $1 + 0; ids[n] = $2; next }
    {
      c = $1 + 0; ln = $2 + 0; k = 0
      for (i = 1; i <= n; i++) { if (al[i] <= ln) k = i; else break }
      if (k == 0) pro += c; else byarm[ids[k]] += c
    }
    END {
      if (pro > 0) printf "%d\t<prologue>\n", pro
      for (a in byarm) printf "%d\t%s\n", byarm[a], a
    }
  ' "$ARMS" "$RUN/by-line" | LC_ALL=C sort -k1,1nr
}

if [ -n "$DUMP" ]; then
  mkdir -p "$DUMP"
  cp "$RUN/by-line" "$DUMP/by-line"
  cp "$RUN/trace"   "$DUMP/trace"
  cp "$RUN/known"   "$DUMP/known"
fi

printf 'TOTAL %s\n' "$TOTAL"
printf 'EXIT %s\n' "$RC"
printf 'TRACELINES %s\n' "$NTRACE"
printf 'MAXLINE %s\n' "$MAXLINE"
printf 'LASTARM %s\n' "$LASTARM"
printf 'KNOWN %s\n' "$NFUNC"
printf 'REPS %s\n' "$rep"
printf 'STABLE %s\n' "$N_STABLE"
printf 'SPREAD %s\n' "$SPREAD"
printf 'TARGET %s\n' "$TARGET"

case "$SECTION" in
  by-line|all)
    printf -- '--- forks-by-line ---\n'
    head -60 "$RUN/by-line"
    ;;
esac
case "$SECTION" in
  by-arm|all)
    printf -- '--- forks-by-arm ---\n'
    emit_by_arm || true
    ;;
esac
exit 0
