#!/usr/bin/env bash
# validate-shell-portability.sh -- every shipped shell file must run on THIS machine's floor:
# bash 3.2 and the BSD userland, where the GNU idioms fail SILENTLY rather than erroring.
#
# WHY A STANDALONE SCRIPT AND NOT AN ARM IN THE ENFORCEMENT MAP. That validator is invoked by
# five of the six slowest fixtures, and the repo's own measurement is 13.0s -> 18.1s inside it
# taking the suite pole 442s -> 595s: roughly 30 seconds of gate wall clock per second of
# script. This runs once, over `git ls-files '*.sh'`, in about a second.
#
# EVERY ARM HERE HAS AN EMPTY FINDING SET TODAY, AND THAT IS THE POINT. These are regression
# guards, not a cleanup. The corpus was measured before any of them shipped -- 325 tracked
# `.sh` files -- and each arm reported zero, with a control in the same invocation proving the
# scan ran. Two candidate arms were DROPPED on that measurement rather than tuned:
#
#   `sed -i` bare              -- 4 hits, 4 of them the correct `sed -i.bak ... || sed -i ''`
#                                 pair. The arm below is the narrowed form, which reports 0
#                                 while 19 files carry the correct idiom.
#   `awk -v` with a backslash  -- 1 hit, and it DOUBLES its backslashes precisely because
#                                 `-v` strips a level. Correct and incorrect use are the same
#                                 shape to a regex; the difference is intent. Not shippable.
#
# THE BRACKET-CLASS `\t` RULE IS NOT HERE. `I71` in the enforcement map already owns it, with
# a narrowing this scan does not reproduce -- a crude version reports 26 hits, nearly all of
# them `awk`, where the class IS a tab. Cite the invariant; do not restate it.
#
# Because the finding set is empty, `core/fixtures/shell-portability/` is the ONLY evidence
# any of these arms works. Every arm self-probes before it touches the corpus.
#
# Usage: validate-shell-portability.sh [--quiet]
# Exit:  0 = clean, 1 = at least one finding, 2 = usage/environment.
set -uo pipefail

QUIET=0
case "${1:-}" in
  "") : ;;
  --quiet) QUIET=1 ;;
  *) echo "usage: $(basename "$0") [--quiet]" >&2; exit 2 ;;
esac

# Walk UP for the marker, never count `..` hops, so this answers identically from the repo
# root, from a subdirectory, and from a fixture sandbox that copied it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/VERSION" ] || { echo "validate-shell-portability: no VERSION marker above $0" >&2; exit 2; }
cd "$ROOT" || exit 2

fail=0
say() { [ "$QUIET" = "1" ] || printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

SELF="scripts/validate-shell-portability.sh"
SQ="'"

# --- the arms -----------------------------------------------------------------------------
# id | pattern | what it binds. The pattern is an ERE handed to `grep -E`.
# S1 needs a SUBTRACTION, not a cleverer pattern. The violation is `sed -i` followed by a
# script, and the correct BSD form is `sed -i ''` followed by a script -- the two differ by
# what comes after `-i`, and ERE has no negative lookahead. So the arm matches every
# space-separated `-i` and then removes the lines carrying the empty argument. Attempting it
# in one expression is what made the first cut miss the quoted GNU form entirely, which is
# the only form anyone actually writes.
S1_PAT="sed[[:space:]]+-i[[:space:]]"
S1_SKIP="sed[[:space:]]+-i[[:space:]]+${SQ}${SQ}"
S1_WHY="\`sed -i\` with neither a suffix nor an explicit empty argument. GNU takes the next word as the script; BSD takes it as the BACKUP SUFFIX and silently writes a differently-named file. Write \`sed -i.bak ...\` and remove the backup, or \`sed -i '' ...\`."
S2_PAT="(^|[^[:alnum:]_])(mapfile|readarray)[[:space:]]"
S2_WHY="\`mapfile\`/\`readarray\` is bash 4. The floor here is bash 3.2, where it is not a builtin and the loop silently reads nothing. Use a \`while IFS= read -r\` loop."
S3_PAT="declare[[:space:]]+-A[[:space:]]"
S3_WHY="\`declare -A\` is bash 4. On bash 3.2 it is an error at parse time in some builds and a plain scalar in others. Use two parallel arrays or a delimited string."
S4_PAT="(^|[^[:alnum:]_])setsid[[:space:]]"
S4_WHY="\`setsid\` does not exist on darwin. A backgrounding path built on it never detaches, and the caller waits forever."
S5_PAT="grep[^|;]*\\\\s"
S5_WHY="\`\\s\` in a grep expression. BSD grep has no \`\\s\` shorthand: it matches a literal \`s\` in a BRE and is undefined in an ERE, so the expression quietly matches the wrong thing. Use \`[[:space:]]\`."
S6_PAT="sed[^|;]*\\\\s"
S6_WHY="\`\\s\` in a sed expression. Same as grep: BSD sed has no \`\\s\`, and the substitution silently applies to a different set of lines. Use \`[[:blank:]]\` or \`[[:space:]]\`."
# `[^)]*` cannot cross the `)` inside a regex literal like `/(a)b/`, which is exactly where
# the capture being back-referenced comes from -- the first cut could not see its own probe.
S7_PAT="g?sub\\(.*,.*\\\\[0-9]"
S7_WHY="a backreference in an \`awk\` \`sub()\`/\`gsub()\` replacement. awk has no \`\\1\`; it emits the literal text and the capture is lost. Use \`match()\` with \`substr()\`."

# Only S1 subtracts. Declared explicitly rather than defaulted in a loop, because `set -u`
# turns a missing one into an abort mid-scan, and an aborted scan prints fewer findings than
# a clean one rather than more.
S2_SKIP=""; S3_SKIP=""; S4_SKIP=""; S5_SKIP=""; S6_SKIP=""
# S7's one measured false positive is PYTHON, not awk. Several shell files here embed a
# heredoc'd python program, and `re.sub(r"...", r"\1...")` is correct there -- python has
# backreferences and awk does not. The subtraction is on the LANGUAGE (`re.` qualifies the
# call) rather than on a file path, so a new embedded python program is covered the day it
# lands and an awk backreference in the same file is still caught.
S7_SKIP="re\\.g?sub\\("

ARMS="S1 S2 S3 S4 S5 S6 S7"

# Corpus: every tracked shell file except this one and its own mutation battery.
#
# A BATTERY NECESSARILY CONTAINS EVERY PATTERN ITS VALIDATOR FORBIDS -- that is what it is
# for -- so the two exclusions are structural rather than convenient. Both are DERIVED from
# this script's own name, so renaming the validator moves its exemption with it and neither
# can rot into a stale hand-list.
#
# THE NARROWEST EXEMPTION THAT WORKS, and deliberately not `.dist-only`. Exempting every
# distribution-only fixture would be one rule and would cover this case, but it would also
# stop checking sixteen other directories of real shell for bash-4 builtins. A shipped
# fixture's shell runs on a consumer's machine and must hold the floor.
#
# THIS WAS FOUND AT PUSH, NOT LOCALLY, AND THE REASON IS WORTH KEEPING: the corpus is
# `git ls-files`, so a NEW file is invisible to this scan until it is committed. The local
# run before the commit and the gate's run after it are over different corpora.
SELF_BATTERY="core/fixtures/$(basename "$SELF" .sh | sed 's/^validate-//')/"
corpus() { git ls-files '*.sh' | grep -vxF "$SELF" | grep -v "^${SELF_BATTERY}"; }

# A comment line is not code. `validate-ci-gates.sh` carries the word `mapfile` in a comment
# explaining why it avoids mapfile, which is the single measured false positive across all
# seven arms and the reason this filter exists rather than an exemption list.
# `grep -H` is load-bearing, not decoration: without it grep omits the filename when handed a
# SINGLE file, the comment filter's `file:line:` anchor stops matching, and three arms report
# their own probe's comment line as a violation. The probes caught that; a corpus-only test
# would not have, because the corpus is always more than one file.
scan() { # scan <pattern> <skip-pattern-or-empty> <file...>
  local pat="$1" skip="$2"; shift 2
  local out
  out="$(grep -HnE "$pat" "$@" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')"
  [ -n "$skip" ] && out="$(grep -vE "$skip" <<<"$out")"
  printf '%s' "$out"
}

# --- self-probes, before the corpus --------------------------------------------------------
probe="$(mktemp -d)"; trap 'rm -rf "$probe"' EXIT

# One offender per arm, and one CORRECT form per arm that must NOT be reported. An arm proven
# only to fire has been proven to be a scanner that flags everything.
cat > "$probe/bad.sh" <<'BADEOF'
sed -i 's/a/b/' f
mapfile -t arr < f
declare -A map
setsid sleep 1
grep -E 'a\sb' f
sed -E 's/a\sb/c/' f
awk '{ gsub(/(a)b/, "\1x") }' f
BADEOF
cat > "$probe/good.sh" <<'GOODEOF'
sed -i.bak 's/a/b/' f && rm -f f.bak
sed -i '' 's/a/b/' f
while IFS= read -r l; do :; done < f
grep -E 'a[[:space:]]b' f
sed -E 's/a[[:blank:]]b/c/' f
awk '{ if (match($0, /(a)b/)) print substr($0, RSTART, RLENGTH) }' f
# mapfile and declare -A and setsid named in a comment are prose, not code
GOODEOF

for a in $ARMS; do
  eval "p=\$${a}_PAT"
  eval "sk=\$${a}_SKIP"
  hit_bad="$(scan "$p" "$sk" "$probe/bad.sh")"
  hit_good="$(scan "$p" "$sk" "$probe/good.sh")"
  if [ -z "$hit_bad" ]; then
    err "$a's own probe did not fire: the seeded offender was not reported. Its zero over the corpus below would be a scan that cannot find anything, which reads exactly like a clean tree."
  elif [ -n "$hit_good" ]; then
    err "$a's own probe misfired: it reported the CORRECT form as a violation. An arm that flags the fix is worse than no arm. Got: $(printf '%s' "$hit_good" | head -1)"
  fi
done

# --- the corpus ----------------------------------------------------------------------------
FILES="$(corpus)"
n_files="$(grep -c . <<<"$FILES" || true)"
# ZERO is the failure, not "few". A threshold tuned to this repo's 325 files would make the
# guard fire on any legitimately small tree -- including the fixture's own seed, which is how
# the first cut was caught.
if [ "${n_files:-0}" -lt 1 ]; then
  err "the corpus is $n_files file(s). \`git ls-files '*.sh'\` found nothing to scan, and an empty corpus passes every arm it never ran. Failing closed."
else
  for a in $ARMS; do
    eval "p=\$${a}_PAT"; eval "w=\$${a}_WHY"; eval "sk=\$${a}_SKIP"
    hits="$(scan "$p" "$sk" $FILES)"
    if [ -n "$hits" ]; then
      err "$a: $w"
      printf '%s\n' "$hits" | sed 's/^/    /' >&2
    fi
  done
fi

if [ "$fail" -eq 0 ]; then
  say "validate-shell-portability: PASS -- $n_files shell file(s), 7 arms (S1 sed -i, S2 mapfile, S3 declare -A, S4 setsid, S5/S6 backslash-s, S7 awk backreference), every arm probed in both directions."
fi
exit "$fail"
