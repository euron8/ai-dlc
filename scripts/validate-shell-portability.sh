#!/usr/bin/env bash
# validate-shell-portability.sh -- every shipped shell file must run on THIS machine's floor:
# bash 3.2 and the BSD userland, where the GNU idioms fail SILENTLY rather than erroring.
#
# S8 EXTENDS THAT FLOOR FROM THE SHELL FILES TO THE TEXT THAT TELLS A HUMAN WHAT TO TYPE, and
# the two belong in one program because the failure is the same one: an idiom that returns a
# wrong answer on this machine instead of an error. Its corpus is `core/`, not `*.sh`, so the
# arm table below carries a per-arm CORPUS column rather than one global file list.
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
# them `awk`, where the class IS a tab. Cite the invariant; do not restate it. The bracket-class
# MULTIBYTE rule IS here, as S10: `I71` never covered it, and an earlier revision of this
# paragraph read as though it did.
#
# THE WHOLE SCAN RUNS UNDER `LC_ALL=C`, for S10's sake: its pattern is a raw byte range that a
# UTF-8 grep rejects as an illegal byte sequence. The other nine arms are pure ASCII and answer
# identically under either locale.
#
# Because the finding set is empty, `core/fixtures/shell-portability/` is the ONLY evidence
# any of these arms works. Every arm self-probes before it touches the corpus.
#
# Usage: validate-shell-portability.sh [--quiet]
# Exit:  0 = clean, 1 = at least one finding, 2 = usage/environment.
set -uo pipefail
export LC_ALL=C

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
# S8 KEYS ON THE PLACEHOLDER, NOT ON `git`, AND THE TWO ARE INDISTINGUISHABLE ON TODAY'S
# CORPUS. Measured on the pre-fix tree: over `core/` this pattern finds 13 renderings and a
# variant additionally requiring the word `git` on the same line finds the same 13. The
# difference set is empty. The narrowing is rejected on a STRUCTURAL argument rather than a
# measured miss: a rendering can wrap and leave `git -C <dist>` on the line above while the
# bracketed `<ref>:` token stays whole, because that token is never itself split -- so the
# placeholder is the half a line-oriented scan can always reach. Requiring a second token on
# the same line is strictly narrower for no gain currently visible.
#
# Do not "confirm" this by counting tree-wide. Over the whole tree the two patterns DO differ,
# 37 to 29 -- and all 8 of those are `docs/` prose and receipts quoting the bare fragment
# without the word `git`. That number is about this repo's writing about the defect, not about
# the corpus this arm scans, and reading it as the latter is how the first cut of this comment
# shipped a false justification.
# S9 KEYS ON `git grep`, NOT ON `grep`, AND MEASURING THE DIFFERENCE IS THE WHOLE ARM.
# `git grep -E` and this machine's `/usr/bin/grep -E` are DIFFERENT ENGINES and they disagree
# about `\b` and `\s`. Measured, both directions, on a token known present:
#   /usr/bin/grep -cE 'a\sb'         -> 1   (matches; control `a[[:space:]]b` also 1)
#   /usr/bin/grep -cE '\b200000\b'   -> 1   (matches; control without \b is 2)
#   git grep -cE '\bMODEL_MAX\b'     -> 0   against a control of 11 without the \b
#   git grep -cE '^\s*local'         -> 0   against a control of 2 with [[:space:]]
#   git grep -cP '\bMODEL_MAX\b'     -> 7   (PCRE has it; ERE does not)
# So a `\b` in a plain `grep -E` is CORRECT here and a `\b` in a `git grep -E` silently
# returns a clean zero. An arm keyed on `grep` would report 16 legal sites in this repo's own
# validators, which is what the first cut did before the two engines were measured separately.
#
# FALSE-POSITIVE SET: EMPTY, measured over the 392-file shell corpus. The narrowing that got
# it there is the `git[[:space:]]+` prefix and nothing else; `[^|;]*` keeps the match inside
# one command so a `git grep` upstream of a pipe cannot claim a `\b` belonging to the reader.
#
# This arm cannot reach the case that motivated it -- three false zeros inside ad-hoc Bash
# tool calls, which no tracked file records. `.claude/rules/tool-hazards.md` carries that half.
S9_PAT="git[[:space:]]+grep[^|;]*\\\\(b|s)"
S9_WHY="\`\\b\` or \`\\s\` in a \`git grep -E\` expression. git's ERE is not this machine's grep: it implements neither escape and returns a CLEAN ZERO rather than an error, so the search reads as a proven absence. Measured: \`git grep -cE '\\bMODEL_MAX\\b'\` answers 0 where the control without the escape answers 11. Use \`[[:space:]]\`/\`[[:alnum:]]\` boundaries, or \`git grep -P\`."
# S10 IS THE ARM THIS FILE'S HEADER SAID `I71` OWNED, AND `I71` DOES NOT: it binds `\t` inside
# a bracket class and nothing else. A MULTIBYTE character inside a bracket class is the other
# half of the same hazard and it is the worse half, because it is correct under the locale
# every interactive session runs and wrong under the one every CI runner and every `env -i`
# gets. Under `LC_ALL=C` a bracket class holds BYTES: `[—–-]` is seven members, a match lands
# on the em-dash's LAST byte, and `sub()`/`s///` strips one byte and leaves two behind in the
# extracted value, which then joins against nothing. Measured on the shipped tree before this
# arm: `validate-suppression-lifetime.sh` read every well-formed `**Suppresses:** [core] 32 —`
# as `32` followed by two stray bytes under `env -i PATH=/usr/bin:/bin`, so every suppression
# was "not a check in the catalog" and the remediation guard's SUPPRESSED carve-out vanished;
# the check-heading grammar's `[.—]$` strip left the same two bytes on every em-dash heading in
# four scripts bound byte-identical by I47/I15. The fix is an ALTERNATION, `(—|–|-)` /
# `(\.|—)`, which is a byte SEQUENCE under both locales and behaves identically in `awk`,
# `sed -E` and `grep -E` -- probed in all three on the em-dash, the en-dash, the hyphen and a
# no-separator near-miss before this shipped.
#
# THE PATTERN IS A RAW BYTE RANGE AND ONLY PARSES UNDER THE C LOCALE. `[\200-\377]` is
# `grep: illegal byte sequence` under a UTF-8 locale, which is why this script pins `LC_ALL=C`
# at the top rather than per arm: every other arm is pure ASCII and reads identically either
# way, and one locale for the whole scan is the form a reader can verify.
#
# FALSE-POSITIVE SET: EMPTY over the tracked shell corpus, after two narrowings and one
# subtraction, each measured on the census that found the 23 offending lines in 9 files:
#   1. a REGEX CONTEXT must precede the class on the line -- `grep`, `sed`, `awk`, `sub(`,
#      `match(`, `~`, or a quoted assignment (`NAME="…"`), which is where every non-inline
#      grammar in this corpus lives. Without it the arm reports `ok "… […] …"` message
#      prose in two fixture lines, where the bracket is a literal string and harmless.
#   2. the class may hold NO WHITESPACE. A bracketed prose aside (`[resolved by basename …]`)
#      is not a class, and every real class in the census was whitespace-free.
#   3. PYTHON is subtracted by language, the S7 precedent, and the subtraction is SMALLER than
#      the first cut claimed. Python's `re` is unicode-aware regardless of locale, and the four
#      python sites in the corpus answer identically under both -- but measured over the real
#      corpus, narrowing 1 already acquits all four (`NAME = re.compile(` carries spaces around
#      its `=`, and a raw-string continuation line carries no context token at all), so a
#      `r"…"` alternative here was structurally unreachable and is not kept. What the SKIP
#      reaches is one shape: a SHELL regex tool editing or quoting a python line, which this
#      corpus's own fixtures do (`check-3b-locked-anchor/run.sh:292`). It keys on any `re.<fn>(`
#      call rather than `re.compile(` alone, because a `re.sub(r"…[—]…")` on such a line is the
#      same program and would otherwise be reported. The fixture's x6 empties it and proves it
#      load-bearing on exactly that shape.
# A comment line is skipped, as in S1-S7: the prose that explains this arm names the class.
S10_HB="$(printf '\200-\377')"
# `.*` and not `[^#]*` between the context and the class: the heading grammar this arm was
# written against carries `#{2,4}` BEFORE its terminator class, and the first cut's `[^#]*`
# could not cross it -- it reported 12 of the 23 lines the census found and read as a pass on
# the other eleven. A regex that cannot spell its own subject scores it as a non-instance.
# The leading `^[[:space:]]*/` alternative is the bare awk pattern-action rule -- `/re/ { … }`
# on a continuation line of a multi-line program, which carries no other context token and is
# the most common awk shape in this corpus (48 files). The adversarial hand seeded it and the
# first cut acquitted it. What stays acquitted, stated rather than hidden: a class assembled
# from a variable (`[.${SEP}]`), a `$'…'` string, a `${v//[…]/}` expansion and a `case` pattern
# -- none carries a multibyte class today, and each would need its own probe before it is added.
S10_PAT="(^[[:space:]]*/|grep|sed|awk|sub\\(|match\\(|~|[A-Za-z_][A-Za-z0-9_]*=[\"']).*\\[[^][:space:]]*[${S10_HB}][^][:space:]]*\\]"
S10_SKIP="re\\.[a-z]+\\("
S10_WHY="a MULTIBYTE character inside a bracket class in a shell, awk, sed or grep expression. Under the C locale -- every CI runner with LANG unset, every \`env -i\` -- the class holds the character's BYTES, not the character: a match lands on its last byte, a strip leaves the other two behind in the extracted value, and the value joins against nothing. Measured: \`[—–-]\` split every \`**Suppresses:**\` id in the suppression-lifetime validator so no SUPPRESSED carve-out existed under \`env -i\`. Spell it as an ALTERNATION -- \`(—|–|-)\`, \`(\\\\.|—)\` -- which is a byte sequence under both locales. The alternation CARRIES a \`|\`: if the expression is later interpolated into a \`sed s|…|…|\`, pick another delimiter (measured: relabel-extension-checks.sh's \`s|(\${anchor_at})|…|\` refused the pattern and wrote nothing)."
S8_PAT="(show|cat-file -p|ls-tree|archive|diff)[[:space:]]+<[^>]+>:"
S8_WHY="an UNQUOTED git rev-path in shipped instruction text. A reader who binds the ref to a variable and pastes this into zsh loses the character after the colon: \`:c\` and \`:t\` are history modifiers that consume it, so \`git show \$THEIRS:templates/x\` reports \`fatal: ambiguous argument 'ca1fb6eemplates/x'\` -- and any \`>\` redirect in the same line still creates the target as a 0-byte file that the next command reads and reports on. Render it quoted: \`git show \"<theirs>:<path>\"\`."

# Only S1 subtracts. Declared explicitly rather than defaulted in a loop, because `set -u`
# turns a missing one into an abort mid-scan, and an aborted scan prints fewer findings than
# a clean one rather than more.
S2_SKIP=""; S3_SKIP=""; S4_SKIP=""; S5_SKIP=""; S6_SKIP=""; S8_SKIP=""; S9_SKIP=""
# S7's one measured false positive is PYTHON, not awk. Several shell files here embed a
# heredoc'd python program, and `re.sub(r"...", r"\1...")` is correct there -- python has
# backreferences and awk does not. The subtraction is on the LANGUAGE (`re.` qualifies the
# call) rather than on a file path, so a new embedded python program is covered the day it
# lands and an awk backreference in the same file is still caught.
S7_SKIP="re\\.g?sub\\("

ARMS="S1 S2 S3 S4 S5 S6 S7 S8 S9 S10"

# Two more per-arm columns, declared for EVERY arm for the reason the SKIP block above gives:
# under `set -u` a missing one aborts the scan mid-way, and an aborted scan prints FEWER
# findings than a clean one rather than more.
#
# CORPUS. `shell` is `git ls-files '*.sh'`; `instr` is `git ls-files 'core/*'` -- every shipped
# file regardless of extension, because the instruction that gets pasted lives in a `SKILL.md`
# or a step file as often as in a script.
#
# COMMENTS. `skip` drops `#` comment lines, which is right for S1-S7: a comment naming
# `mapfile` is prose, and that subtraction is the reason this file has no exemption list. It is
# WRONG for S8, whose whole subject is text a human copies -- a rev-path rendered inside a
# comment is pasted exactly as readily as one rendered in a heredoc, and two of the sites that
# motivated this arm were comments. `keep` scans them.
S1_CORPUS=shell; S2_CORPUS=shell; S3_CORPUS=shell; S4_CORPUS=shell
S5_CORPUS=shell; S6_CORPUS=shell; S7_CORPUS=shell; S8_CORPUS=instr
S9_CORPUS=shell; S10_CORPUS=shell
S1_COMMENTS=skip; S2_COMMENTS=skip; S3_COMMENTS=skip; S4_COMMENTS=skip
S5_COMMENTS=skip; S6_COMMENTS=skip; S7_COMMENTS=skip; S8_COMMENTS=keep
S9_COMMENTS=skip; S10_COMMENTS=skip

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
# The battery exclusion is why `instr` is derived the same way rather than being a bare
# `git ls-files 'core/*'`: the battery lives UNDER `core/`, so an S8 offender seeded there
# would pin this arm non-zero for as long as the fixture exists.
SELF_BATTERY="core/fixtures/$(basename "$SELF" .sh | sed 's/^validate-//')/"
corpus() { # corpus shell|instr
  case "$1" in
    shell) git ls-files '*.sh' ;;
    instr) git ls-files 'core/*' ;;
    *) return 1 ;;
  esac | grep -vxF "$SELF" | grep -v "^${SELF_BATTERY}"
}

# A comment line is not code. `validate-ci-gates.sh` carries the word `mapfile` in a comment
# explaining why it avoids mapfile, which is the single measured false positive across all
# seven arms and the reason this filter exists rather than an exemption list.
# `grep -H` is load-bearing, not decoration: without it grep omits the filename when handed a
# SINGLE file, the comment filter's `file:line:` anchor stops matching, and three arms report
# their own probe's comment line as a violation. The probes caught that; a corpus-only test
# would not have, because the corpus is always more than one file.
scan() { # scan <pattern> <skip-pattern-or-empty> <skip|keep comments> <file...>
  local pat="$1" skip="$2" comments="$3"; shift 3
  local out
  out="$(grep -HnE "$pat" "$@" 2>/dev/null)"
  [ "$comments" = "skip" ] && out="$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<<"$out")"
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
git -C <dist> show <theirs>:templates/settings.json.template > "$t"
git grep -nE '\bMODEL_MAX\b' -- core/
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  /^#{2,4}[ \t]+[0-9]+[ \t]*[.—]/ { print }
BADEOF
cat > "$probe/good.sh" <<'GOODEOF'
sed -i.bak 's/a/b/' f && rm -f f.bak
sed -i '' 's/a/b/' f
while IFS= read -r l; do :; done < f
grep -E 'a[[:space:]]b' f
sed -E 's/a[[:blank:]]b/c/' f
awk '{ if (match($0, /(a)b/)) print substr($0, RSTART, RLENGTH) }' f
git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"
git show HEAD:templates/settings.json.template > "$t"
git grep -nE '[[:space:]]MODEL_MAX' -- core/
grep -oE '\bLR-[0-9]+\b' f
awk '{ sub(/[[:space:]]*(—|–|-)[[:space:]].*$/, "", s) }' f
HEAD_RE='^#{2,4}[[:space:]]+[0-9]+[[:space:]]*(\.|—)'
  /^#{2,4}[ \t]+[0-9]+[ \t]*(\.|—)/ { print }
/usr/bin/grep -E '[[:space:]]' f
ok "prose naming a class in a message ([…]) is a string, not a class"
    r"^#{2,4}[ \t]+(?:Check[ \t]+)?([0-9]+)[ \t]*[.—]")
SECTION_RE = re.compile(r'^## Sprint (\d+) [—\-]+ (.+)')
# mapfile and declare -A and setsid named in a comment are prose, not code
GOODEOF

for a in $ARMS; do
  eval "p=\$${a}_PAT"
  eval "sk=\$${a}_SKIP"
  eval "cm=\$${a}_COMMENTS"
  hit_bad="$(scan "$p" "$sk" "$cm" "$probe/bad.sh")"
  hit_good="$(scan "$p" "$sk" "$cm" "$probe/good.sh")"
  if [ -z "$hit_bad" ]; then
    err "$a's own probe did not fire: the seeded offender was not reported. Its zero over the corpus below would be a scan that cannot find anything, which reads exactly like a clean tree."
  elif [ -n "$hit_good" ]; then
    err "$a's own probe misfired: it reported the CORRECT form as a violation. An arm that flags the fix is worse than no arm. Got: $(printf '%s' "$hit_good" | head -1)"
  fi
done

# --- the corpus ----------------------------------------------------------------------------
FILES_shell="$(corpus shell)"
FILES_instr="$(corpus instr)"
n_shell="$(grep -c . <<<"$FILES_shell" || true)"
n_instr="$(grep -c . <<<"$FILES_instr" || true)"
n_files="$n_shell"
# ZERO is the failure, not "few". A threshold tuned to this repo's 325 files would make the
# guard fire on any legitimately small tree -- including the fixture's own seed, which is how
# the first cut was caught.
#
# BOTH corpora are guarded, separately. One combined count would let a dead `core/*` listing
# hide behind a live `*.sh` one, and S8's zero over nothing reads exactly like S8's zero over
# 510 files -- which is the failure this whole script exists to refuse.
if [ "${n_shell:-0}" -lt 1 ] || [ "${n_instr:-0}" -lt 1 ]; then
  err "the corpora are $n_shell shell file(s) and $n_instr core file(s). \`git ls-files\` found nothing to scan on at least one of them, and an empty corpus passes every arm it never ran. Failing closed."
else
  for a in $ARMS; do
    eval "p=\$${a}_PAT"; eval "w=\$${a}_WHY"; eval "sk=\$${a}_SKIP"
    eval "cm=\$${a}_COMMENTS"; eval "cp_kind=\$${a}_CORPUS"
    eval "files=\$FILES_${cp_kind}"
    hits="$(scan "$p" "$sk" "$cm" $files)"
    if [ -n "$hits" ]; then
      err "$a: $w"
      printf '%s\n' "$hits" | sed 's/^/    /' >&2
    fi
  done
fi

if [ "$fail" -eq 0 ]; then
  say "validate-shell-portability: PASS -- $n_shell shell file(s) + $n_instr core file(s), 10 arms (S1 sed -i, S2 mapfile, S3 declare -A, S4 setsid, S5/S6 backslash-s, S7 awk backreference, S8 unquoted rev-path, S9 git-grep ERE escape, S10 multibyte bracket class), every arm probed in both directions."
fi
exit "$fail"
