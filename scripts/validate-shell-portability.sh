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
# identically under either locale. An arm added later inherits it: one that needs a UTF-8-aware
# match (a `.` meant to consume one CHARACTER, a class meant to hold one) answers differently
# here than in an interactive shell, and must be probed under this file's locale, not yours.
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
#
# THE `"?` IS LOAD-BEARING AND THIS ARM'S OWN REMEDY USED TO BE WRONG. The pattern once
# required the rev-path to be UNQUOTED and `S8_WHY` prescribed quoting as the fix. A reader
# who followed that prescription still lost the character, because zsh applies a history
# modifier INSIDE a double-quoted parameter expansion -- the quotes are the shell's, and the
# modifier fires before git ever sees the ref. Measured, one invocation, ref `ae0c6c6f`:
#
#   zsh  T=...; git show "$T:templates/settings.json.template"     -> fatal: 'ae0c6c6femplates/...'
#   zsh  T=...; git show "${T}:templates/settings.json.template"   -> 272 lines   (control)
#   bash T=...; git show "$T:templates/settings.json.template"     -> 272 lines   (control)
#   zsh          git show "ae0c6c6f:templates/settings.json..."    -> 272 lines   (control)
#
# The last control is why this survived: a LITERAL ref works in every shell, so the rendered
# form in a doc reads as correct to anyone who tests it without binding a variable first.
# Only the second control discriminates, and it is the braces that carry it.
#
# THE MODIFIER SET IS 17 OF 26 LETTERS, NOT THE TWO `:c`/`:t` THIS FILE USED TO NAME -- so the
# dangerous half of the corpus is far wider than the two paths that motivated it. Measured by
# enumerating `"$T:<letter>rest/x"` under zsh: a/A/c/e/f/F/g/h/l/q/Q/r/s/t/u/w MANGLE, `s`
# raising `bad substitution` rather than a wrong ref. `core/` (c), `templates/` (t) and `lib/`
# (l) all break; `docs/`, `VERSION` and `scripts/` -- the last only because `s` errors loudly
# rather than silently -- do not. A pattern keyed on the two known-bad prefixes would have
# scored the other fifteen as safe, which is the narrowing this note exists to refuse.
#
# FALSE-POSITIVE SET: EMPTY, measured over the 563-file `instr` corpus at the widening. The
# widened pattern found 20 renderings, 7 of them inside this arm's own battery (structurally
# exempt, and they are the seeds) and 13 real subjects in shipped text, every one of which
# renders a placeholder a reader substitutes a variable into. It does NOT flag `"${theirs}:`,
# `"$SHA:` or a literal `HEAD:` -- the three correct forms are asserted as negatives in `n3`.
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
S8_PAT="(show|cat-file -p|ls-tree|archive|diff)[[:space:]]+\\\\?\"?<[^>]+>:"
S8_WHY="a git rev-path in shipped instruction text whose ref placeholder is not BRACED. A reader who binds the ref to a variable and pastes this into zsh loses the character after the colon: \`:c\` and \`:t\` are history modifiers that consume it, so \`git show \"\$THEIRS:templates/x\"\` reports \`fatal: ambiguous argument 'ca1fb6eemplates/x'\` -- and any \`>\` redirect in the same line still creates the target as a 0-byte file that the next command reads and reports on. QUOTING DOES NOT FIX IT; only the braces do. Render it \`git show \"\${theirs}:<path>\"\`."
# S8b IS S8's SECOND SPELLING OF ONE DEFECT: the rev-path whose ref is ALREADY a variable. S8 keys
# on the `<ref>:` placeholder, so `git show "$THEIRS:core/x"` -- what a reader produces by dropping
# the braces from a correct site -- is outside its grammar by construction (measured: S8_PAT scores
# `show <theirs>:<core-path>` 1 and `show "$THEIRS:core/scripts/x.sh"` 0). A separate arm and not
# an alternation in S8_PAT, because the two need DIFFERENT CORPORA and the corpus is a per-arm
# column: a `$VAR:` rev-path in a `#!/usr/bin/env bash` script is CORRECT, because bash has no
# history modifiers.
#
# THE CORPUS IS `doc` -- `core/*` MINUS `*.sh` -- AND THAT SUBTRACTION IS THE WHOLE NARROWING.
# Measured over `git ls-files 'core/*'` minus this validator's own battery: 37 lines in `.sh`
# files carry this pattern (39 with the battery's two comment lines), every one of them in a
# bash script where the form works -- fixture seeds and `reconcile/emit-report.sh:536` -- and
# 0 lines in the non-`.sh` files. A `.sh` subject is run by bash; a `.md` subject is retyped by a
# model or an operator into whatever shell they hold, and on this machine that is zsh. The
# subtraction is a CORPUS rather than a SKIP because the self-probe below is `bad.sh`/`good.sh`:
# a skip keyed on `\.sh:` would subtract the probe's own offender and the arm could never fire.
#
# FALSE-POSITIVE SET: EMPTY over the `doc` corpus, after two narrowings measured on it:
#   1. THE CHARACTER AFTER THE COLON MUST BE A MODIFIER LETTER. A loose `\$NAME:` form finds 2
#      lines in shipped non-`.sh` core, both `reconcile/classify-block.md:15-16`
#      (`show "$BASE:$CORE_PATH"`), where the next character is `$` and zsh consumes nothing.
#      The class is the 17 letters `.claude/rules/tool-hazards.md` names, re-derived by
#      enumerating `"$T:<L>rest/x"` against `"${T}:<L>rest/x"` under `/bin/zsh -f` for all 52
#      letters: exactly `acefghlqrstuwAFPQ` differ. So `"$THEIRS:docs/x"` is SAFE (d) and is
#      asserted quiet; `core/` (c), `templates/` (t) and `lib/` (l) are not.
#   2. THE NAME IS `[A-Za-z_][A-Za-z0-9_]*`, NOT `[A-Za-z_]+`. The latter cannot spell a variable
#      carrying a digit, so `show $T1:templates/x` scored 0 under the first candidate. Widening,
#      not narrowing; it moves no corpus count (0 either way) and the battery's x-arm owns it.
# STATED HOLES, not claims of coverage: a `.sh` that PRINTS the remedy as text for an operator to
# paste (`say "run: git show \"\$T:core/x\""`) is outside this arm twice -- `.sh` is excluded, and
# the `\$` breaks the pattern. Measured 0 such sites in `core/*`. And an extensionless bash file
# under `core/` (a git hook) is IN the `doc` corpus and would over-report; 0 hits there today.
S8b_PAT="(show|cat-file -p|ls-tree|archive|diff)[[:space:]]+\\\\?\"?\\\$[A-Za-z_][A-Za-z0-9_]*:[acefghlqrstuwAFPQ]"
S8b_WHY="a git rev-path in shipped NON-shell text whose ref is an UNBRACED variable followed by a zsh history-modifier letter. S8's placeholder form, one step later: the reader has already bound the ref. Under zsh \`git show \"\$THEIRS:core/x\"\` loses the \`c\` -- \`:c\` is a modifier and it fires INSIDE the quotes -- and git answers about a different path or fails. A \`.sh\` file is exempt because bash runs it; a \`.md\` is retyped into whatever shell the reader holds. Brace it: \`git show \"\${THEIRS}:core/x\"\`."
# S11 IS THE ONE ARM HERE WHOSE FAILURE REACHES OUTSIDE THE PROCESS, and its corpus is
# FIXTURE shell rather than every `.sh`. A fixture seed's first act is to enter a sandbox it
# just built and then run repo-mutating git; if the `cd` fails, every one of those commands
# resolves against the PROCESS cwd instead. The Bash tool's working directory persists across
# calls and a linked worktree exports `GIT_DIR` absolute, so the process cwd at that moment is
# routinely the real repository. MEASURED on a throwaway sandbox, the shipped subshell shape
# with the `cd` target absent: unguarded, `git config user.email` landed in the SURROUNDING
# repo and the subshell exited 0, so nothing reported; guarded `|| exit 2`, the subshell exits
# 2, the caller reports, and neither key is written.
#
# IT DOES NOT ACQUIT ON `set -e`, AND THAT IS THE DESIGN DECISION. Four of the six sites this
# arm was written against sit in scripts carrying `set -e`, which does abort them today. But
# `-e` is DISABLED inside a `( … )` whose status is consumed by `||`, inside a condition, and
# in a function called from one -- so the acquittal would depend on where the line is invoked
# from, which a line-oriented scan cannot see. The two `check-17-bypass` sites are the proof:
# that script sets `set -uo pipefail` with NO `-e` and both `cd`s sit in subshells directly
# above `git init -q .`. Keying on `set -e` would have acquitted the file-level majority and
# missed the live pair. The guard is a one-token edit, so the arm asks for it unconditionally.
#
# FALSE-POSITIVE SET: EMPTY over the fixture corpus, after two narrowings measured on the
# census that found the six offending lines:
#   1. an optional leading `(` -- the corpus's dominant guarded idiom is `( cd "$x" && … )`,
#      and without the paren the anchored pattern cannot see those lines at all. Widening the
#      anchor took the arm's own matched set from 21 lines to 110, of which the SKIP acquits
#      104 -- so the paren is what makes the skip load-bearing rather than decorative.
#   2. THE SKIP STOPS AT THE FIRST `;`, AND THE UNANCHORED SPELLING WAS A REAL ACQUITTAL. The
#      first cut read `cd[[:space:]].*(\|\||&&|\\$)`, whose `.*` runs to end of line, so ANY
#      guard token anywhere past the `cd` acquitted it -- including one belonging to a
#      different command. Measured with the shipped grammar, four offenders acquitted and the
#      arm's own subject among them: `cd "$W"; git init . && git add -A`,
#      `cd "$W"; [ -d x ] || mkdir x`, `cd "$W"; git init . \` and `cd "$W"; echo "a && b"`,
#      where the last one's guard is inside a STRING. `[^;]*` reports all four. Corpus
#      incidence of the difference is 0 either way (control: the plain anchor matches 110
#      lines in 48 files), so this is a latent hole closed before it had an instance, not a
#      cleanup. The discriminating near-miss is `cd "$x" || exit 2; git init .` -- a `;` AFTER
#      the guard, which must stay acquitted, and does.
#   3. the SKIP takes a trailing BACKSLASH as a guard as well as `||`/`&&`. Two sites
#      (`gate-adjudication-rotate/seed.sh`, `snapshot-archive-rotate/seed.sh`) open
#      `( cd "$PROJ" \` and put the `&& git init` on the NEXT line. A line-oriented scan
#      cannot reach that continuation, and reporting the opener would be flagging the correct
#      form. That is a STATED HOLE, not a claim of coverage: an unguarded `cd "$x" \` followed
#      by an unrelated continuation is invisible to this arm. Zero such sites exist today
#      (both continuations are `&&` chains) and a multi-line grammar is its own piece of work.
# A comment line is skipped, as in S1-S7.
S11_PAT="^[[:space:]]*(\\([[:space:]]*)?cd[[:space:]]"
S11_SKIP="cd[[:space:]][^;]*(\\|\\||&&|\\\\$)"
S11_WHY="an UNGUARDED \`cd\` in a fixture script. If the target does not exist the \`cd\` fails, the script keeps going, and every command below it -- \`git init\`, \`git config\`, \`git commit\` -- resolves against the PROCESS working directory instead of the sandbox. Measured on a throwaway repo: with the target absent, the following \`git config user.email\` overwrote the SURROUNDING repository's value and the subshell still exited 0, so nothing reported it. Under a linked worktree, where git exports \`GIT_DIR\` absolute, that surrounding repository is the real one. Write \`cd \"\$x\" || exit 2\` (or \`( cd \"\$x\" && … )\`), and where the subshell's output is discarded, read its exit status at the closing paren."

# S12 IS THE FIRST ARM HERE THAT A LINE-ORIENTED `grep` CANNOT EXPRESS, AND THAT IS WHY IT CARRIES
# A `KIND` COLUMN. bash's `[[ =~ ]]` hands its right-hand side to the platform's regcomp, and on
# this machine that ERE knows none of the GNU escapes `grep -E` accepts. Measured, bash 3.2.57,
# one invocation, input `ab a b 1 a-b`: `\b \B \< \> \w \W \s \S \d` EACH match nothing under
# `[[ =~ ]]` while `/usr/bin/grep -cE` answers 1 for every one of them; `re='\bstub\b'` with
# `[[ "stub = 1" =~ $re ]]` misses, inline and via a variable alike, against a control without
# the boundary that matches. So a `\b` in a `grep -E` is CORRECT here and the same text in a
# `[[ =~ ]]` is a predicate that is never true -- a check that examines nothing and reports a
# clean tree. The motivating instance was a filed remedy, `STUB_MARKER='\b(...)\b'`, which built
# as a mutant examined 0 markers over 393 files.
#
# THE OFFENDER IS TWO LINES, NOT ONE. The pattern is ASSIGNED to a variable at one line and
# CONSUMED by `=~` at another -- 116 lines apart in the motivating case -- so a same-line grep for
# `=~` and `\b` scored it as a non-instance (0 over 390 files, and a seeded two-line probe did not
# fire it). S12 is a two-pass join per file: pass 1 collects every variable whose assigned value
# carries an escape, pass 2 reports every `[[ … =~ … ]]` whose right-hand side carries one inline
# or names a collected variable. Order-free: a consumer ABOVE its assignment is reported too.
#
# `S12_PAT` IS THE ESCAPE, and it is an ODD run of backslashes before the letter. `a\\bc` is a
# correct regex for a literal backslash followed by `bc` -- measured, it matches `a\bc` -- and an
# even run is therefore not the defect. A double-quoted value is shell-unescaped first (`"\\b"`
# stores `\b`, measured), an unquoted one likewise, a single-quoted one is taken raw.
#
# FALSE-POSITIVE SET: EMPTY over the tracked shell corpus, measured at the build against a
# positive control of 5 seeded offenders appended to the same run, every figure DERIVED by an
# instrumented copy of the join rather than read off a grep. The census: 48 raw lines carry `=~`;
# the join reads 32 of them (33 occurrences) as code inside `[[`, and the 16 it does not are 11
# comment lines and 5 lines where `=~` sits inside a quoted sed/awk mutation string
# (`check-15-bypass/run.sh`). None of the 33 is reported. Their right-hand sides name 19 distinct
# variables: 14 assigned an escape-free literal, 4 (`i82_tok_re`, `i82_slot_re`, `i99_conceal_re`,
# `i99_conceal_id_re`) assigned from `artifact-path-config.sh`, whose output carries no escape,
# and `item`, a digit loop variable. Pass 1 taints 0 variables in the files that carry a `=~`
# (4 elsewhere, in files with no `=~`, which the join skips whole). The narrowings:
#   1. THE JOIN KEY IS `=~`, SO THE GREP/SED CONSUMERS ARE STRUCTURALLY OUT. `\b` in a `grep -E`
#      is correct here (107 lines carry `\b`; the entry counted 17 load-bearing grep/sed sites) and
#      no name list exempts them: a tainted variable that only ever feeds `grep` is never reported.
#   2. A COMMAND SUBSTITUTION IS NOT A PATTERN. `id=$(grep -m1 -oE '\bID-[0-9]+\b' f)` stores
#      grep's OUTPUT, and `[[ $line =~ $id ]]` below it matches a token, not a `\b`; an assignment
#      whose value opens `$(` or a backtick taints nothing. Without this the arm convicts the grep
#      consumer it exempts. (A grep COUNT tested as `[[ $n =~ ^[0-9]+$ ]]` never needed this: only
#      the RIGHT-hand side of `=~` is read, so a variable on the left is not a pattern at all.)
#   3. QUOTED TEXT AND COMMENTS ARE NOT CODE. Each line is scanned through a view that blanks
#      quoted bodies and drops a `#` comment, so `echo "[[ \$x =~ \$g ]]"` and `# [[ $x =~ $g ]]`
#      are not sites. That is what acquits the two quoted mutation strings in the census.
# STATED HOLES, not claims of coverage: a variable assigned in one file and consumed in a file
# that sources it; `read`/`printf -v`/array assignment; a heredoc body is read as code (which can
# only over-report). Taint is flow-insensitive per file, so a variable later reassigned clean
# stays tainted -- also over-report only.
S12_PAT="(^|[^\\\\])(\\\\\\\\)*\\\\[bBwWsSdD<>]"
S12_WHY="a GNU regex escape (\`\\b \\B \\< \\> \\w \\W \\s \\S \\d\`) reaching bash's \`[[ =~ ]]\`, inline or through a variable assigned it -- possibly many lines away. \`grep -E\` on this machine honours these; bash 3.2's \`=~\` hands the pattern to the platform ERE, which does not, so the test is NEVER true and whatever it guards examines nothing while reading as a pass. Measured: \`re='\\bstub\\b'; [[ \"stub = 1\" =~ \$re ]]\` misses where the same test without the boundary matches. Spell the boundary out -- \`(^|[^[:alnum:]_])stub([^[:alnum:]_]|\$)\` -- and \`[[:space:]]\`/\`[[:alnum:]_]\`/\`[0-9]\` for the others."
# The join. Single-quoted, so it carries no apostrophe anywhere, comments included; the pattern
# reaches it through ENVIRON, never `awk -v`, which would strip one level of its backslashes.
# COST: a file carrying no `=~` is skipped whole, pass 1 reads only lines carrying a backslash
# and pass 2 only lines carrying `=~`. Neither prefilter names an escape letter, so widening
# S12_PAT cannot be silently narrowed by them. Measured in CPU-seconds, 2 interleaved reps against
# a clean worktree of the base: base 3.68/3.73, with S12 4.12/4.11; the join alone is ~0.44s.
# Wall clock was NOT usable -- on a loaded box the same base read 4.0s and 12.7s.
S12_JOIN='
function codeview(s,   i, n, c, st, out, prev) {
  out = ""; st = ""; n = length(s); prev = " "
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (st == "") {
      if (c == "\\") { out = out c substr(s, i + 1, 1); i++; prev = "x"; continue }
      if (c == "#" && (prev == " " || prev == "\t")) break
      if (c == SQ || c == "\"") st = c
      out = out c; prev = c; continue
    }
    if (st == "\"" && c == "\\") { out = out "__"; i++; continue }
    if (c == st) { st = ""; out = out c; prev = c; continue }
    out = out "_"
  }
  return out
}
function unesc(s, p, stop,   i, n, c, d, v) {
  v = ""; n = length(s)
  for (i = p; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\\") {
      d = substr(s, i + 1, 1); i++
      if (stop == "\"" && index("\\\"$`", d) == 0) v = v c
      v = v d; continue
    }
    if (stop == "\"" && c == "\"") break
    if (stop == " " && index(" \t;&|)", c)) break
    v = v c
  }
  return v
}
function flush(   i, s, cv, rest, off, tok, name, vpos, c1, e, val, at, pre, tail, q, rhs, hit, t, r) {
  split("", tainted)
  if (!hassite) { nbuf = 0; return }
  for (i = 1; i <= nbuf; i++) {
    s = buf[i]
    if (index(s, "\\") == 0) continue
    cv = codeview(s); rest = cv; off = 0
    while (match(rest, ASSIGN_RE)) {
      tok = substr(rest, RSTART, RLENGTH)
      vpos = off + RSTART + RLENGTH
      off = off + RSTART + RLENGTH - 1; rest = substr(cv, off + 1)
      if (tok ~ /^[^A-Za-z_]/) tok = substr(tok, 2)
      name = substr(tok, 1, length(tok) - 1)
      c1 = substr(s, vpos, 1)
      if (c1 == "=" || c1 == "~") continue
      if (c1 == SQ) { e = index(substr(s, vpos + 1), SQ); val = (e ? substr(s, vpos + 1, e - 1) : substr(s, vpos + 1)) }
      else if (c1 == "\"") val = unesc(s, vpos + 1, "\"")
      else if (substr(s, vpos, 2) == "$(" || c1 == "`") val = substr(s, vpos)
      else val = unesc(s, vpos, " ")
      if (index(val, "$(") || index(val, "`")) continue
      if (val ~ ESC) tainted[name] = 1
    }
  }
  for (i = 1; i <= nbuf; i++) {
    s = buf[i]
    if (index(s, "=~") == 0) continue
    cv = codeview(s); rest = cv; off = 0
    while ((at = index(rest, "=~")) > 0) {
      at = off + at
      pre = substr(cv, 1, at - 1)
      off = at + 1; rest = substr(cv, off + 1)
      if (index(pre, "[[") == 0) continue
      tail = substr(cv, at + 2); q = index(tail, "]]")
      rhs = (q ? substr(s, at + 2, q - 1) : substr(s, at + 2))
      hit = 0
      if (rhs ~ ESC) hit = 1
      t = rhs
      while (match(t, /[$][{]?[A-Za-z_][A-Za-z0-9_]*/)) {
        r = substr(t, RSTART, RLENGTH); gsub(/[${]/, "", r)
        if (r in tainted) hit = 1
        t = substr(t, RSTART + RLENGTH)
      }
      if (hit) { print fname ":" i ":" s; break }
    }
  }
  nbuf = 0; hassite = 0
}
BEGIN { SQ = sprintf("%c", 39); ESC = ENVIRON["S12_ESC"]
        ASSIGN_RE = "(^|[^-A-Za-z0-9_$.{/])[A-Za-z_][A-Za-z0-9_]*=" }
FNR == 1 && nbuf > 0 { flush() }
{ buf[FNR] = $0; nbuf = FNR; fname = FILENAME; if (index($0, "=~")) hassite = 1 }
END { if (nbuf > 0) flush() }
'

# Only S1 subtracts. Declared explicitly rather than defaulted in a loop, because `set -u`
# turns a missing one into an abort mid-scan, and an aborted scan prints fewer findings than
# a clean one rather than more.
S2_SKIP=""; S3_SKIP=""; S4_SKIP=""; S5_SKIP=""; S6_SKIP=""; S8_SKIP=""; S8b_SKIP=""; S9_SKIP=""; S12_SKIP=""
# S7's one measured false positive is PYTHON, not awk. Several shell files here embed a
# heredoc'd python program, and `re.sub(r"...", r"\1...")` is correct there -- python has
# backreferences and awk does not. The subtraction is on the LANGUAGE (`re.` qualifies the
# call) rather than on a file path, so a new embedded python program is covered the day it
# lands and an awk backreference in the same file is still caught.
S7_SKIP="re\\.g?sub\\("

ARMS="S1 S2 S3 S4 S5 S6 S7 S8 S8b S9 S10 S11 S12"

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
#
# `fixture` is `git ls-files 'core/fixtures/*/*.sh'` -- S11's subject is a fixture SEED's
# sandbox entry, and the `scripts/` validators it would otherwise scan resolve their own root
# by walking up for `VERSION` rather than by entering a directory they built.
#
# `doc` is `instr` minus every `*.sh` -- S8b's subject is text a reader RETYPES, and a `.sh` is
# run by bash, where the unbraced `$VAR:` form is correct. S8b's header carries the measurement.
# `keep` for S8b as for S8: a markdown `#` line is a HEADING, and `skip` would drop it.
S1_CORPUS=shell; S2_CORPUS=shell; S3_CORPUS=shell; S4_CORPUS=shell
S5_CORPUS=shell; S6_CORPUS=shell; S7_CORPUS=shell; S8_CORPUS=instr; S8b_CORPUS=doc
S9_CORPUS=shell; S10_CORPUS=shell; S11_CORPUS=fixture
S12_CORPUS=shell
S1_COMMENTS=skip; S2_COMMENTS=skip; S3_COMMENTS=skip; S4_COMMENTS=skip
S5_COMMENTS=skip; S6_COMMENTS=skip; S7_COMMENTS=skip; S8_COMMENTS=keep; S8b_COMMENTS=keep
S9_COMMENTS=skip; S10_COMMENTS=skip; S11_COMMENTS=skip; S12_COMMENTS=skip
# KIND. `line` is one `grep -E` per line through `scan`; `join` is S12's two-pass program over
# whole files through `scan_join`, which the PATTERN still drives, so every arm's PAT cell is live.
S1_KIND=line; S2_KIND=line; S3_KIND=line; S4_KIND=line; S5_KIND=line; S6_KIND=line
S7_KIND=line; S8_KIND=line; S8b_KIND=line; S9_KIND=line; S10_KIND=line; S11_KIND=line; S12_KIND=join

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
corpus() { # corpus shell|instr|doc|fixture
  case "$1" in
    shell) git ls-files '*.sh' ;;
    instr) git ls-files 'core/*' ;;
    doc) git ls-files 'core/*' | grep -v '\.sh$' ;;
    fixture) git ls-files 'core/fixtures/*/*.sh' ;;
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
# The same contract as `scan`, same `file:line:text` output, same comment and skip filters
# applied after -- so a `join` arm is read by the loops below exactly as a `line` arm is.
scan_join() { # scan_join <escape-pattern> <skip-pattern-or-empty> <skip|keep comments> <file...>
  local pat="$1" skip="$2" comments="$3"; shift 3
  local out
  out="$(S12_ESC="$pat" awk "$S12_JOIN" "$@" 2>/dev/null)"
  [ "$comments" = "skip" ] && out="$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<<"$out")"
  [ -n "$skip" ] && out="$(grep -vE "$skip" <<<"$out")"
  printf '%s' "$out"
}
run_arm() { # run_arm <kind> <pattern> <skip> <comments> <file...>
  local k="$1"; shift
  if [ "$k" = "join" ]; then scan_join "$@"; else scan "$@"; fi
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
git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"
git grep -nE '\bMODEL_MAX\b' -- core/
git -C "$DIST" show "$THEIRS:core/scripts/validate-thing.sh" > "$t"
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  /^#{2,4}[ \t]+[0-9]+[ \t]*[.—]/ { print }
  cd "$REPO"
if [[ $x =~ $early ]]; then :; fi
re="\b(foo)\b"
if [[ $x =~ $re ]]; then :; fi
if [[ $x =~ \bfoo\b ]]; then :; fi
  [[ "$line" =~ ${wre} ]] && echo y
  local wre=^\\<local
early='\<stub\>'
BADEOF
cat > "$probe/good.sh" <<'GOODEOF'
sed -i.bak 's/a/b/' f && rm -f f.bak
sed -i '' 's/a/b/' f
while IFS= read -r l; do :; done < f
grep -E 'a[[:space:]]b' f
sed -E 's/a[[:blank:]]b/c/' f
awk '{ if (match($0, /(a)b/)) print substr($0, RSTART, RLENGTH) }' f
git -C <dist> show "${theirs}:templates/settings.json.template" > "$t"
git show "${SHA}:templates/settings.json.template" > "$t"
git show HEAD:templates/settings.json.template > "$t"
git -C "$DIST" show "${THEIRS}:core/scripts/validate-thing.sh" > "$t"
git -C "$DIST" show "$THEIRS:$CORE_PATH" > "$t"
git -C "$DIST" show "$THEIRS:docs/x.md" > "$t"
git grep -nE '[[:space:]]MODEL_MAX' -- core/
grep -oE '\bLR-[0-9]+\b' f
awk '{ sub(/[[:space:]]*(—|–|-)[[:space:]].*$/, "", s) }' f
HEAD_RE='^#{2,4}[[:space:]]+[0-9]+[[:space:]]*(\.|—)'
  /^#{2,4}[ \t]+[0-9]+[ \t]*(\.|—)/ { print }
/usr/bin/grep -E '[[:space:]]' f
cd "$REPO" || exit 2
cd "$REPO" && git init -q .
( cd "$REPO" && git init -q . )
cd "$(dirname "$0")" || exit 2
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
( cd "$PROJ" \
  && git init -q . )
ok "prose naming a class in a message ([…]) is a string, not a class"
    r"^#{2,4}[ \t]+(?:Check[ \t]+)?([0-9]+)[ \t]*[.—]")
SECTION_RE = re.compile(r'^## Sprint (\d+) [—\-]+ (.+)')
# mapfile and declare -A and setsid named in a comment are prose, not code
#   cd "$REPO" named in a comment is prose, not an unguarded chdir
if [[ $x =~ ^a ]]; then :; fi
[[ "$x" =~ "a.b" ]] && echo lit
pat='^[0-9]+$'
[[ $n =~ $pat ]] || n=0
n=$(printf %s a | grep -cE "\bfoo\b")
[[ $n =~ ^[0-9]+$ ]] || n=0
id=$(grep -m1 -oE '\bID-[0-9]+\b' f)
[[ $line =~ $id ]] && echo seen
g='\bfoo\b'
grep -E "$g" f
# [[ $x =~ $g ]] named in a comment is prose
echo "[[ \$x =~ \$g ]] in a string is prose"
lb='a\\bc'
[[ $x =~ $lb ]] && echo literal-backslash
GOODEOF

for a in $ARMS; do
  eval "p=\$${a}_PAT"
  eval "sk=\$${a}_SKIP"
  eval "cm=\$${a}_COMMENTS"
  eval "kd=\$${a}_KIND"
  hit_bad="$(run_arm "$kd" "$p" "$sk" "$cm" "$probe/bad.sh")"
  hit_good="$(run_arm "$kd" "$p" "$sk" "$cm" "$probe/good.sh")"
  if [ -z "$hit_bad" ]; then
    err "$a's own probe did not fire: the seeded offender was not reported. Its zero over the corpus below would be a scan that cannot find anything, which reads exactly like a clean tree."
  elif [ -n "$hit_good" ]; then
    err "$a's own probe misfired: it reported the CORRECT form as a violation. An arm that flags the fix is worse than no arm. Got: $(printf '%s' "$hit_good" | head -1)"
  fi
done

# --- the corpus ----------------------------------------------------------------------------
FILES_shell="$(corpus shell)"
FILES_instr="$(corpus instr)"
FILES_doc="$(corpus doc)"
FILES_fixture="$(corpus fixture)"
n_shell="$(grep -c . <<<"$FILES_shell" || true)"
n_instr="$(grep -c . <<<"$FILES_instr" || true)"
n_doc="$(grep -c . <<<"$FILES_doc" || true)"
n_fixture="$(grep -c . <<<"$FILES_fixture" || true)"
n_files="$n_shell"
# ZERO is the failure, not "few". A threshold tuned to this repo's 325 files would make the
# guard fire on any legitimately small tree -- including the fixture's own seed, which is how
# the first cut was caught.
#
# BOTH corpora are guarded, separately. One combined count would let a dead `core/*` listing
# hide behind a live `*.sh` one, and S8's zero over nothing reads exactly like S8's zero over
# 510 files -- which is the failure this whole script exists to refuse.
#
# THE THIRD CORPUS IS GUARDED SEPARATELY TOO, for the reason the paragraph above gives one
# more time: `core/fixtures/*/*.sh` is a NARROWER glob than `*.sh`, so a typo in it collapses
# to nothing while both other counts stay healthy, and S11's zero over nothing is the exact
# shape of S11's zero over a clean tree.
#
# EACH CONDITION NAMES ITS OWN CORPUS, AND THAT IS FORCED BY THE CORPORA NESTING. Once a third
# corpus exists the three are no longer independent: `core/fixtures/*/*.sh` is a SUBSET of both
# `*.sh` and `core/*`, so no tree can have `instr` empty while `fixture` is populated. A single
# disjunction therefore cannot be proven cell-by-cell -- emptying `core/*` trips the `fixture`
# condition as well, and a mutant that disables the `instr` half still sees the guard refuse,
# which reads exactly like a load-bearing condition. Three separately-named refusals make the
# observable WHICH CORPUS IS NAMED rather than merely whether a refusal happened, and that is
# the only shape the battery can score. `fail=1` either way; the message is the discriminator.
#
# `dead_corpus` IS ITS OWN FLAG AND NOT `fail`. `fail` is already 1 when a SELF-PROBE failed,
# and gating the corpus scan on it would silently stop scanning on a probe failure -- a
# behaviour change that removes findings and reports the same exit.
dead_corpus=0
if [ "${n_shell:-0}" -lt 1 ]; then
  err "the SHELL corpus is empty. \`git ls-files '*.sh'\` found nothing to scan, and an empty corpus passes every arm it never ran. Failing closed."
  dead_corpus=1
fi
if [ "${n_instr:-0}" -lt 1 ]; then
  err "the CORE corpus is empty. \`git ls-files 'core/*'\` found nothing to scan, and an empty corpus passes every arm it never ran. Failing closed."
  dead_corpus=1
fi
# `doc` is a SUBSET of `instr`, so it nests like `fixture` does: the one world where only this
# condition fires is a `core/` holding shell files and nothing else.
if [ "${n_doc:-0}" -lt 1 ]; then
  err "the CORE TEXT corpus is empty. \`git ls-files 'core/*'\` minus \`*.sh\` found nothing to scan, and an empty corpus passes every arm it never ran. Failing closed."
  dead_corpus=1
fi
if [ "${n_fixture:-0}" -lt 1 ]; then
  err "the FIXTURE shell corpus is empty. \`git ls-files 'core/fixtures/*/*.sh'\` found nothing to scan, and an empty corpus passes every arm it never ran. Failing closed."
  dead_corpus=1
fi
if [ "$dead_corpus" -ne 0 ]; then
  : # a dead corpus is already reported above; scanning it would print a clean line beside the refusal
else
  for a in $ARMS; do
    eval "p=\$${a}_PAT"; eval "w=\$${a}_WHY"; eval "sk=\$${a}_SKIP"
    eval "cm=\$${a}_COMMENTS"; eval "cp_kind=\$${a}_CORPUS"; eval "kd=\$${a}_KIND"
    eval "files=\$FILES_${cp_kind}"
    hits="$(run_arm "$kd" "$p" "$sk" "$cm" $files)"
    if [ -n "$hits" ]; then
      err "$a: $w"
      printf '%s\n' "$hits" | sed 's/^/    /' >&2
    fi
  done
fi

# THE ARM COUNT IS DERIVED FROM `ARMS`, NOT WRITTEN. It was a literal sitting beside the
# eleven-member string with nothing joining them, so the twelfth arm would have shipped under a
# banner reading eleven -- a total that decays silently and reads exactly like a fresh one. The
# parenthetical roster stays hand-written: it carries a per-arm GLOSS, which no derivation can
# produce, and a wrong gloss is visible where a wrong count is not.
n_arms=0
for a in $ARMS; do n_arms=$((n_arms + 1)); done
if [ "$fail" -eq 0 ]; then
  say "validate-shell-portability: PASS -- $n_shell shell file(s) + $n_instr core file(s) ($n_doc non-shell) + $n_fixture fixture shell file(s), $n_arms arms (S1 sed -i, S2 mapfile, S3 declare -A, S4 setsid, S5/S6 backslash-s, S7 awk backreference, S8 unquoted rev-path, S8b unbraced \$VAR: rev-path in non-shell text, S9 git-grep ERE escape, S10 multibyte bracket class, S11 unguarded cd in a fixture script, S12 GNU escape reaching [[ =~ ]]), every arm probed in both directions."
fi
exit "$fail"
