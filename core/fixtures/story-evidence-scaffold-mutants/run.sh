#!/usr/bin/env bash
# story-evidence-scaffold-mutants -- the MUTATION BATTERY behind the shipped story-evidence-scaffold
# fixture. It edits copies of validate-handoff-evidence.sh and sprint-status.sh and scores each
# mutant against the seeded git worlds, so every verdict is a question about whether THIS
# repository's validator still discriminates. It is distribution-only for that reason (.dist-only).
#
# WHERE THE SHARED CODE LIVES. The worlds (build_world), the case table (CASES / WANT), verdict,
# vector, mk_tree and mkmut live in ../story-evidence-scaffold/world.sh, which BOTH this battery and
# the shipped fixture source. The alternative -- the battery exec-ing the shipped run.sh with a flag
# -- would keep the battery's mutants in the file consumers receive, which is the defect this split
# removes. A shared file is therefore the only shape that leaves the shipped directory holding the
# worlds, the control vector and the IN PLACE arm, and this directory holding only the battery.
#
# SHARDED BY MODE. Every mutant mutates one mode's code path, and a mode's worlds are independent of
# the others'. The three modes are h (evidence handoff, 5 worlds), s (strategy, 11) and k
# (bookkeeping handoff, 17). A bookkeeping verdict costs about 0.4s, so a k mutant over its 17 worlds
# is about 6-7s while an s mutant is sub-second. Shards a, b, c carry the 16 k mutants; shard d carries
# the h and s mutants. A shard builds ONLY the worlds of the modes in its MODES_<s> list and runs only
# that slice of the control vector; a mutant still runs EVERY case of its own mode, so the entanglement
# check stays whole. Two mutants (nm-exact-heading, no-crlf-strip) move one k and one s case because
# the heading grammar is shared, so shard a is dealt modes "ks".
#
# The shard set, each shard's modes and the mutant partition are declared HERE and joined (J0) against
# this file's own `he_mutant <id>` calls -- one grammar, indented or not, so the conditional
# strat-no-lc-c is seen. A shard declared with no driver directory and a mutant dealt twice or to no
# shard each fail the build in J0. J0 does NOT check mode cover: he_mutant refuses, at run time, a
# mutant dealt to a shard whose modes do not cover its own, and refuses any call whose id is dealt to
# no shard whatever shape the call has. Every shard runs J0, so none can pass without it. The shard
# arrives as an ARGUMENT, never the environment.
#
# Usage: run.sh [--group <a|b|c|d>]      (default a; b, c, d are the sibling driver directories)
# Exit:  0 = every mutant dealt to this shard is killed by exactly its own cases, 1 = one is not,
#        2 = fixture broken.
SHARDS="a b c d"
MODES_a="ks"
MUTANTS_a="nm-exact-heading no-crlf-strip no-arm-g no-arm-h no-arm-i-level1"
MODES_b="k"
MUTANTS_b="no-arm-i-deep nm-skip-silent nm-fence-read fence-any-closes nm-planning-view"
MODES_c="k"
MUTANTS_c="nm-worktree-yaml nm-worktree-story nm-worktree-heading nm-strict-decode no-status-missing no-story-untracked"
MODES_d="hs"
MUTANTS_d="no-arm-a no-arm-b no-arm-c nm-glob-all-tracked awk-v-caps cmd-unanchored cmd-no-sha-form no-arm-d no-arm-e first-token-only no-short-row nm-short-any-header no-arm-e-path nm-b-any-untracked nm-no-node nm-kind-vocab nm-warn-refuses nm-subtree-glob nm-any-brace nm-build-input strat-no-lc-c"
set -u

GROUP=a
if [ "$#" -gt 0 ]; then
  if [ "$1" != "--group" ]; then
    echo "FIXTURE ERROR: unknown argument '$1' (usage: run.sh [--group <shard>])" >&2; exit 2
  fi
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${MUTANTS_$GROUP:-}\""
eval "SMODES=\"\${MODES_$GROUP:-}\""
[ -n "$MINE" ] || { echo "FIXTURE ERROR: shard '$GROUP' has no MUTANTS_$GROUP list; a shard dealt nothing passes everything it never checked" >&2; exit 2; }
[ -n "$SMODES" ] || { echo "FIXTURE ERROR: shard '$GROUP' has no MODES_$GROUP list; a shard with no modes builds no worlds" >&2; exit 2; }
NAME="story-evidence-scaffold-mutants"
[ "$GROUP" = a ] || NAME="$NAME-$GROUP"

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/run.sh"
[ -f "$SELF" ] || { echo "FIXTURE ERROR: cannot read $SELF for the coverage join" >&2; exit 2; }

# partition_ok <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared
# exactly; prints the offending ids otherwise.
partition_ok() {
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
# he_ids <file> -> the id of every `he_mutant <id> ...` CALL, indented or not. The definition line
# `he_mutant() {` has no space after the word and a comment starts with `#`, so neither matches.
he_ids() { sed -n 's/^[[:space:]]*he_mutant \([a-z0-9][a-z0-9-]*\) .*/\1/p' "$1"; }
# in_union <name> <space-separated ids> -> 0 when the name is one of the ids.
in_union() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
# driver_ok <driver run.sh> <shard> -> 0 when that file exists and drives that shard.
driver_ok() { [ -f "$1" ] && grep -qF -- "--group $2" "$1"; }
# modes_cover <a mutant's modes> <a shard's modes> -> 0 when every mode letter of the first is in the second.
modes_cover() {
  local i=0 m="$1"
  while [ "$i" -lt "${#m}" ]; do
    case "$2" in *"${m:$i:1}"*) ;; *) return 1 ;; esac
    i=$((i+1))
  done
  return 0
}
JW="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
# SELF-PROBES, before the corpus, each fired in both directions.
printf '%s\n' m1 m2 m3 > "$JW/pd"
printf '%s\n' m1 m2 m2 m3 > "$JW/pdup"
printf '%s\n' m1 m3 > "$JW/pmiss"
printf '%s\n' m3 m1 m2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2
  rm -rf "$JW"; exit 2
fi
# The id grammar must see an indented call and a hyphenated id, and must NOT see the definition line,
# a comment or a call that is not at the start of its line.
printf 'he_mutant() {\n# he_mutant fake-comment a b\nhe_mutant alpha a b 1 x\n    he_mutant beta a b 2 x\n  he_mutant gamma-2 a b 3 x\n  echo he_mutant fake-echo a b\n' > "$JW/ids.txt"
if [ "$(he_ids "$JW/ids.txt" | tr '\n' ' ')" != "alpha beta gamma-2 " ]; then
  echo "FIXTURE BROKEN: the he_mutant id grammar's self-probe did not discriminate (indented call kept, definition/comment/echo dropped)" >&2
  rm -rf "$JW"; exit 2
fi
printf 'exec bash "$IMPL" --group b\n' > "$JW/drv-b"
printf 'exec bash "$IMPL" --group c\n' > "$JW/drv-c"
if ! driver_ok "$JW/drv-b" b || driver_ok "$JW/drv-c" b || driver_ok "$JW/no-such-driver" b; then
  echo "FIXTURE BROKEN: the driver join's self-probe did not discriminate (drives it, drives another shard, absent)" >&2
  rm -rf "$JW"; exit 2
fi
if ! in_union beta "alpha beta" || in_union gamma "alpha beta" || in_union alp "alpha beta"; then
  echo "FIXTURE BROKEN: the undealt-id self-probe did not discriminate (dealt, undealt, prefix of a dealt id)" >&2
  rm -rf "$JW"; exit 2
fi
if ! modes_cover k ks || ! modes_cover sk ks || modes_cover ks k || modes_cover h ks; then
  echo "FIXTURE BROKEN: the mode-cover self-probe did not discriminate (covered, mixed covered, mixed uncovered, foreign mode)" >&2
  rm -rf "$JW"; exit 2
fi
he_ids "$SELF" > "$JW/declared"
for s in $SHARDS; do eval "printf '%s\n' \${MUTANTS_$s}"; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  echo "FIXTURE BROKEN: $ndecl he_mutant ids derived from $SELF ($ndupdecl declared twice)" >&2; rm -rf "$JW"; exit 2
fi
if ! why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  echo "FIXTURE BROKEN: the shard partition does not cover the declared mutants exactly -- $why" >&2; rm -rf "$JW"; exit 2
fi
for s in $SHARDS; do
  eval "_m=\"\${MODES_$s:-}\""
  case "$_m" in ""|*[!hks]*) echo "FIXTURE BROKEN: shard '$s' declares modes '{$_m}'; each must be a non-empty string over h, k, s" >&2; rm -rf "$JW"; exit 2 ;; esac
  [ "$s" = a ] && continue
  drv="$HERE/../story-evidence-scaffold-mutants-$s/run.sh"
  if ! driver_ok "$drv" "$s"; then
    echo "FIXTURE BROKEN: shard '$s' is declared but $drv does not drive it" >&2; rm -rf "$JW"; exit 2
  fi
done
rm -rf "$JW"
ALLDEALT=""
for s in $SHARDS; do eval "ALLDEALT=\"\$ALLDEALT \${MUTANTS_$s}\""; done
NMINE="$(printf '%s\n' $MINE | grep -c .)" || NMINE=0
echo "[J0] coverage join: $ndecl mutants derived from he_mutant calls, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE} over modes {$SMODES}"

DIR="$HERE/../story-evidence-scaffold"
[ -f "$DIR/world.sh" ] || { echo "FIXTURE ERROR: the shared world file $DIR/world.sh is absent; the battery has no worlds to drive" >&2; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/story-evidence-mut.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# shellcheck source=../story-evidence-scaffold/world.sh
. "$DIR/world.sh"
for v in HE SCHEMA SSH; do
  eval "p=\${$v}"
  if [ -z "$p" ]; then
    echo "$NAME: FIXTURE BROKEN -- could not locate subject $v in either layout (core/ or .claude/). An absent subject is not a passing one." >&2
    exit 2
  fi
done
echo "$NAME: shard $GROUP, subjects $HE $SSH"

WORLDS_OK=1
se_build_worlds "$SMODES" || WORLDS_OK=0
if [ "$WORLDS_OK" -eq 1 ] && ! HECTL="$(mk_tree control)"; then
  WORLDS_OK=0; bad "FIXTURE BROKEN: could not build the control tree (scripts dir + schema), or sprint-status.sh is not beside the validator in it"
fi
if [ "$WORLDS_OK" -ne 1 ]; then
  echo "$NAME: FAILED" >&2
  exit 1
fi
# The control: this shard's modes' slice of the vector, unmutated. Every other mode reports its WANT,
# so it can never move. NSLICE is a positive conjunct: a slice that ran no case proves nothing.
NSLICE=0
for c in $CASES; do case "$SMODES" in *"${c#*:}"*) NSLICE=$((NSLICE+1)) ;; esac; done
got="$(vector "$HECTL" "$SMODES")"
if [ "$got" = "$WANT" ] && [ "$NSLICE" -gt 0 ]; then
  ok "CONTROL: the unmutated validator reproduces every verdict of modes {$SMODES} ($NSLICE cases), so a mutant's movement below is the mutation"
else
  bad "CONTROL: modes {$SMODES} ($NSLICE cases) -- want [$WANT] got [$got]; every mutant verdict below is uninterpretable"
fi

# he_mutant <name> <from-literal> <to-literal> <case indices (1-based) that must move> <label> [ss]
# An ARM mutant must move only its own offender's case. A NEAR-MISS mutant moves every
# case of its mode ($HCASES handoff, $SCASES strategy), because every offender world is CLEAN
# plus one defect and so carries the clean world's near-misses too; one that keys on the
# head-tree WARN skips 10, whose captures name the tree they ran on. The modes a mutant runs
# are read off its expected cases (h evidence handoff, k bookkeeping handoff, s strategy; the
# shared heading grammar moves one k and one s case), so a kill landing in a mode it did not
# run reads SURVIVED, never a false kill. A sixth argument `ss` mutates sprint-status.sh
# instead of the validator. A mutant not dealt to this shard returns at once; one dealt to a
# shard whose modes do not cover its own is a fixture error, never a verdict.
SCORED=0
he_mutant() {
  local name="$1" from="$2" to="$3" want="$4" label="$5" m mv i=0 diffs="" wv wi mode="" x
  # Bound to the CALL SITE, whatever shape the call has: an id dealt to no shard is scored by none.
  if ! in_union "$name" "$ALLDEALT"; then
    bad "FIXTURE BROKEN: he_mutant '$name' is dealt to no shard"; return
  fi
  in_union "$name" "$MINE" || return 0
  SCORED=$((SCORED+1))
  for x in $want; do
    case " $SCASES " in *" $x "*) mode="${mode}s" ;; esac
    case " $KCASES " in *" $x "*) mode="${mode}k" ;; esac
    case " $HCASES " in *" $x "*) mode="${mode}h" ;; esac
  done
  if [ -z "$mode" ] || ! modes_cover "$mode" "$SMODES"; then
    bad "FIXTURE ERROR: mutant '$name' runs modes {$mode} but shard $GROUP builds only {$SMODES}"; return
  fi
  if ! m="$(mkmut "$name" "${6:-he}" "$from" "$to")" || [ -z "$m" ]; then
    bad "FIXTURE ERROR: handoff mutation '$name' matched nothing"; return
  fi
  mv="$(vector "$m" "$mode")"
  for wv in $mv; do
    i=$((i+1))
    wi="$(awk -v n="$i" '{print $n}' <<<"$WANT")"
    [ "$wv" = "$wi" ] || diffs="$diffs $i"
  done
  if [ "${diffs# }" = "$want" ]; then ok "MUTATION '$name' killed, moving cases [$want] only: $label"
  elif [ -z "$diffs" ]; then bad "MUTATION '$name' SURVIVED -- $label"
  else bad "MUTATION '$name' moved cases [${diffs# }], want [$want] -- the arms are entangled"; fi
}
set -f
  he_mutant no-arm-a "if ! grep -qE '^(\\\$ |" "if false && ! grep -qE '^(\\\$ |" 3 "(a) no-command arm removed"
  he_mutant no-arm-b 'if [ "$isred" -eq 1 ] && ! tracked' 'if false && ! tracked' 4 "(b) red-untracked arm removed"
  he_mutant no-arm-c '[ "$hit" -eq 1 ] && ! glob_resolves' '[ "$hit" -eq 9 ] && ! glob_resolves' 5 "(c) glob-cited arm removed"
  he_mutant nm-glob-all-tracked '    [ "$any" -eq 1 ] || return 1' '    return 1' "$HCASES" "near-miss: a glob whose every match is tracked (test-results/red-*.txt) is refused"
  he_mutant awk-v-caps 'others="$(HE_CAPS="$CAPS" HE_STORY="$STORY" awk '"'"'BEGIN { caps=ENVIRON["HE_CAPS"]; story=ENVIRON["HE_STORY"];' 'others="$(awk -v story="$STORY" -v caps="$CAPS" '"'"'BEGIN {' "$HCASES" "multi-line CAPS passed through awk -v (BSD awk: newline in string) -- stderr is no longer empty"
  he_mutant cmd-unanchored '|^sha=[0-9a-f]{7,40}[[:space:]]+cmd=[^[:space:]]'"'" '|(^|[[:space:]])cmd=[^[:space:]]'"'" 3 "(a) cmd= accepted mid-line with no sha= partner"
  he_mutant cmd-no-sha-form '|^sha=[0-9a-f]{7,40}[[:space:]]+cmd=' '|^NEVERMATCH=' "$HCASES" "near-miss: a sha=<sha> cmd=<cmd> capture header is refused"
  he_mutant no-arm-d 'if [ -z "$kind" ] || [ -z "$res" ]; then' 'if false; then' '6 23 24 33' "(d) empty-cell arm removed"
  he_mutant no-arm-e 'if ! grep -qE "^[[:space:]]*((async' 'if false && ! grep -qE "^[[:space:]]*((async' '7 11' "(e) node-missing def lookup removed"
  he_mutant first-token-only '    done <<<"$toks"' '    done <<<"$(head -n 1 <<<"$toks")"' 11 "(e) only the first .py:: token of a cell read"
  he_mutant no-short-row '      if (n < 4) { if (hasres)' '      if (n < 4) { if (0)' 12 "short-row arm removed"
  he_mutant nm-short-any-header '      if (n < 4) { if (hasres)' '      if (n < 4) { if (1)' 13 "near-miss: a short row under a header without Resolves to is refused"
  # The path half of (e): with the tracked-path check gone, a moved test file reads as an
  # empty source, so the def lookup must not be what catches it -- the mutant makes the
  # untracked path fall through to `continue`, and only the movefile case may move.
  he_mutant no-arm-e-path 'if ! tracked "$ref" "$path"; then' 'if ! tracked "$ref" "$path"; then continue; fi; if false; then' 9 "(e) untracked test-file path check removed"
  he_mutant nm-b-any-untracked 'if [ "$isred" -eq 1 ] && ! tracked' 'if ! tracked' "$HCASES" "near-miss: an untracked full-suite capture not cited as RED is refused"
  he_mutant nm-no-node '[ -n "$toks" ] || continue' '[ -n "$toks" ] || { refuse "node-missing $story: $id"; continue; }' "$SCASES" "near-miss: a bare test_* row is refused"
  he_mutant nm-kind-vocab '[ "$kind" = "test" ] || continue' 'case "$kind" in test|predicate|deploy-time) ;; *) refuse "kind $id"; continue ;; esac; [ "$kind" = "test" ] || continue' "$SCASES" "near-miss: an off-vocabulary Kind is refused"
  he_mutant nm-warn-refuses 'warn "head-tree' 'refuse "head-tree' '1 3 4 5' "near-miss: a head sha that differs from frozen refuses instead of warning"
  he_mutant nm-subtree-glob 'case "$last" in *[!*{},]*) case' 'case "$last" in *) case' "$HCASES" "near-miss: a test-results/local/** subtree is refused as a glob capture"
  he_mutant nm-any-brace '    hit=0' '    hit=0; case "$g" in *"{"*"}"*) hit=1 ;; esac' "$HCASES" "near-miss: an /api/x/{id} route is refused as a brace capture"
  he_mutant nm-build-input 'if (b ~ /^(requirements|constraints)' 'if (0 && b ~ /^(requirements|constraints)' "$HCASES" "near-miss: a modified requirements.txt is read as a capture"
  # The bookkeeping arms, one mutant each, and one per near-miss. An arm mutant moves every world
  # whose only refusal is that arm's: (g) also owns latin1yaml and dirtystory, (i)-deep also owns
  # crlfdemoted, dirtyhead and mixfence. nm-worktree-yaml also moves latin1yaml (a strict read of
  # the disk yaml raises, so the row is a SKIP) and dirtystory (the disk row says review).
  he_mutant no-arm-g '[ "$st_val" = "review" ] || refuse' 'true || refuse' '16 26 28' "(g) status-not-review arm removed"
  he_mutant no-arm-h 'elif [ "$row_val" != "$st_val" ]; then' 'elif false; then' 17 "(h) status-yaml-mismatch arm removed"
  he_mutant no-arm-i-deep 'if (!two[i] && deep[i]) print' 'if (0) print' '19 25 29 32' "(i) heading-demoted arm removed for a deeper heading"
  he_mutant no-arm-i-level1 'if (!two[i] && one[i]) print' 'if (0) print' 20 "(i) heading-demoted arm removed for a level-1 heading"
  he_mutant nm-skip-silent "skip_status() { printf 'SKIP STATUS (%s)\\n' \"\$1\"; }" 'skip_status() { :; }' 14 "near-miss: a world with no yaml passes silently instead of printing SKIP STATUS"
  he_mutant nm-exact-heading 'if (after == "" || after ~ /^[ \t]/) return lvl' 'if (after == "") return lvl' '21 23' "near-miss: a heading with trailing text read as absent, in BOTH the heading arm and strategy mode (one grammar)"
  he_mutant nm-fence-read 'if (fence == "" && m != "") { fence = m; next }' 'if (0) { fence = m; next }' 22 "near-miss: a demoted heading inside a code fence is read"
  he_mutant fence-any-closes 'if (fence != "") { if (m == fence) fence = ""; next }' 'if (fence != "") { if (m != "") fence = ""; next }' 32 "a fence closed by the other marker (a toggle), which hides a demoted heading after a mixed fence"
  he_mutant nm-planning-view 'PRIMARY = "implementation"' 'PRIMARY = "planning"' 18 "near-miss: the lagging planning view is compared instead of the implementation view" ss
  he_mutant nm-worktree-yaml 'text = git("show", "%s:%s" % (full, view_rel)) or ""' 'text = (root / view_rel).read_text()' '15 26 28' "near-miss: the row is read from the working tree, not the frozen sha" ss
  he_mutant nm-worktree-story 'sv, how = story_text_status(git("show", "%s:%s" % (full, story_rel)) or "")' 'sv, how = story_file_status(root / story_rel)' 28 "the story status is read from the working tree, not the frozen sha" ss
  he_mutant nm-worktree-heading 'demoted="$(G show "$FROZEN:$STORY" | LC_ALL=C awk' 'demoted="$(cat "$REPO/$STORY" | LC_ALL=C awk' 29 "the evidence headings are read from the working tree, not the frozen sha"
  he_mutant no-crlf-strip 'sub(/\r$/, "", line)' '' '24 25' "a CRLF heading read with its CR, in BOTH strategy mode and the heading arm (one grammar)"
  he_mutant nm-strict-decode 'return r.stdout.decode("utf-8", errors="replace")' 'return r.stdout.decode("utf-8")' '26 27' "a non-UTF-8 byte in the yaml or the story read strictly (a Traceback, a SKIP)" ss
  if [ -n "$UTF8_LOCALE" ]; then
    he_mutant strat-no-lc-c 'rows="$(LC_ALL=C awk "$HEADING_AWK"' 'rows="$(awk "$HEADING_AWK"' 33 "strategy mode's awk run in the caller's UTF-8 locale ($UTF8_LOCALE): one non-UTF-8 byte aborts it and the empty cell below is never read"
  else
    case " $MINE " in *" strat-no-lc-c "*)
      SCORED=$((SCORED+1))
      ok "SKIP strat-no-lc-c: no UTF-8 locale in which this host's awk aborts on a non-UTF-8 byte, so the abort latin1strat guards cannot happen here" ;;
    esac
  fi
  he_mutant no-status-missing '*) refuse "status-missing $STORY' '*) skip_status "status-missing $STORY' 30 "a committed story with no status is a SKIP, not a refusal"
  he_mutant no-story-untracked '"not tracked at "*) refuse "story-untracked' '"not tracked at "*) skip_status "story-untracked' 31 "a story not tracked at the frozen sha is a SKIP, not a refusal"
set +f

if [ "$SCORED" -ne "$NMINE" ]; then
  bad "COVERAGE: shard $GROUP was dealt $NMINE mutants but scored $SCORED -- a dealt id with no he_mutant call, or a call that returned early"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "$NAME: PASS"
else
  echo "$NAME: FAILED" >&2
fi
exit $rc
