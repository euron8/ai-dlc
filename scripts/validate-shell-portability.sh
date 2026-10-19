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
# The backslash-digit must sit INSIDE the replacement: the first double-quoted string after the
# first comma following `sub(`/`gsub(`, scanned to its unescaped closing quote. The body units are
# a non-quote non-backslash char, an escaped backslash, an escaped quote, or a backslash before any
# other non-digit; the tail is one or more backslashes then a digit. A later `"\037"` in a `print`
# on the same line is past the closing quote and is not reached.
# The first argument is walked unit by unit so a comma INSIDE a regex literal or a string
# literal (`/a,(b)/`, `","`) does not end it early: a unit is a char other than comma, quote or
# slash, a `/…/` regex literal, or a `"…"` string. Measured over an 8-line matrix (hits A1 A4 A5
# A7 A9, spares A2 A8 B1): this form 8/8, the earlier `[^,]*` form 6/8 (missed A4, A5), the
# adversary's `(/…/|[^,/])*` form 7/8 (missed A5). KNOWN MISSES: a first argument holding a
# dynamic-regex string with an escaped quote, a division or a bare `/` outside a literal, and
# a call whose arguments wrap onto the next line; none is in the tracked corpus.
S7_PAT='g?sub\(([^,"/]|/([^/\\]|\\.)*/|"([^"\\]|\\.)*")*,[[:space:]]*"([^"\\]|\\\\|\\"|\\[^0-9"\\])*\\+[0-9]'
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

# S13 -- A MULTI-LINE OR NESTED `$( ... )` THAT /bin/bash 3.2 CLOSES EARLY, WHICH `bash -n` ACCEPTS.
# bash 3.2 finds the end of a command substitution with a quote-and-paren scan of its own, BEFORE
# it parses the body. Four forms, (a) to (d) below, defeat that scan; `bash -n` exits 0 on every one.
# In (a) to (c) the assignment or argument never happens, and the hazard surfaces as an unbound
# variable or a missing verdict far from the cause; in (d) the script runs rc 0 with a WRONG value.
# Every fact below is from the ORACLE -- /bin/bash 3.2.57 RUNNING the
# seed with its commands stubbed -- and not from the backlog prose. `set -n` is NOT the oracle in
# any placement: as the file's first statement it hides every form (nothing runs), and placed
# inside the OUTER `$(` it hides every NESTED form.
#   (a) a comment, inside a DOUBLE-QUOTED substitution (`"$( ... )"`, `$(echo "$( ... )")`), carrying
#       a lone `'` or a lone `)`, followed later in the same substitution by a double-quoted string
#       holding a SPACE. Without that string a lone `)` parses and a lone `'` is a `bash -n` error;
#       a lone `"`, backtick or `(` is a `bash -n` error either way. Those parse errors are outside
#       this hazard (a parse sees them) and the grammar flags them anyway. Not in an unquoted `x=$(`.
#   (b) a bare `case` pattern -- `''|*[!0-9]*) ... ;;` with no leading paren -- in a multi-line
#       `$( )`, or in a single-line DOUBLE-QUOTED one; in a single-line unquoted `x=$( ... )` it is a
#       `bash -n` error instead. The POSIX form `(''|*[!0-9]*)` is fine.
#   (c) a BRACE-EXPANSION artifact (`set +B` makes the entry's line parse). bash 3.2 re-scans the
#       raw text of every brace-expanded word holding a `{`, toggling quotes without nesting, so a
#       `$(` opened inside double quotes inside a single-quoted body, in a double-quoted `$( )`, is
#       extracted from the wrong place and is "bad substitution". The `{` may sit ANYWHERE in the same
#       word, and no later `)` is needed. Brace-expanded words: a command argument; an argument of
#       `local`/`export`/`declare`/`readonly`; an array element; a `for` list; a redirect target; a
#       command after a prefix assignment; a backtick outer. NOT expanded, so they parse: a plain
#       `v=` assignment, a `case` word, a `[[ ]]` operand and a here-string. A single-quoted body
#       ending in `\'` parses.
#   (d) a HEREDOC BODY inside any `$( )` (quoted or not, nested or not, any delimiter quoting)
#       carrying a `)` that closes nothing: `v="$(cat <<'X'` / `a ) here` / `X` / `)"`. `bash -n`
#       exits 0 and the script runs rc 0, but the value is WRONG -- bash 3.2's scan takes the body's
#       `)` as the substitution's end, so `v` reads `a  here`, `X`, `)`. Measured under 3.2.57 by
#       comparing the captured value against the literal body: a `(` before it on the same or an
#       earlier body line balances it (`a ( b ) here`, `a ( b` / `c ) d` both correct); quotes,
#       a backslash and a `#` comment (after a blank or at line start) hide it (`it's ) ok's`,
#       `a ")" here`, `a \) here`, `x # a ) b`); `a#) b`, `(x)# a ) b`, `case x in a) ;; esac` and
#       `$((1+2)) ) x` break. A heredoc in a backtick substitution, at top level, in a process
#       substitution's sibling or in a function the substitution calls is correct. The other
#       unbalanced body shapes (a lone quote or `(`) are `bash -n` errors, which S14 refuses.
#       This is BL-689's silent half; the rule reads the body with its own quote-and-paren
#       counter (`hbscan`), carried across every heredoc opened on one line.
# THE GRAMMAR (S13_JOIN) is one awk over the whole file list, one fork like S12, no bash per hit. It
# tracks quote, substitution and `case` state across lines, so it reads the multi-line shapes a
# line grep cannot. The oracle is NOT run here: it runs in core/fixtures/shell-portability, which
# holds grammar and bash to one verdict per seed.
# NARROWING STORY (how the false-positive set got to its measured size):
#   1. The first lexer scored 1081 corpus hits, all one bug: `$"` inside a double-quoted string
#      opened a locale-string state. Fixed in `dollar`; the corpus then read 2.
#   2. The 2 were correct code. One was a comment holding a `$( )` inside `mwr="$( ... )"`: a
#      balanced `$(` in comment text is fine, so "any `$(` in a comment" was dropped from (a).
#      The other was `score_a M-A3 "$(mut_line a3 'LR_DIST_ONLY="$(git ...' ...)"`, a
#      single-quoted body with a `$(` and no `{`: (c) needs a `{` in the word.
#   3. Form (c) is modelled as bash does it, not as a context list: `wtok`/`wend` split words and
#      decide which are brace-expanded, and `gob` mirrors brace_gobbler over each one (`xds`, `sdq`,
#      `sxe`, `dbr` mirror the extractors it calls). `kscan` re-splits a backtick body. The earlier
#      context rule (argument of a double-quoted parent, `)` after the `$(`) missed nine bash-breaking
#      seeds: `local`/`for`/backtick contexts, a `{` outside the quoted body, and no later `)`.
#   4. A lone `)` in a comment breaks only when a later double-quoted string in the same substitution
#      holds a space (probed: `echo "a"` parses, `echo "1 0"` breaks). It is held as pending and
#      reported when such a string closes, instead of being reported where it stands.
#   5. Form (d), scored on 71 in-class oracle probes (bash -n 0 on each; BREAK = stderr, a missing
#      trailing line, or a captured value differing from the literal body): missed 0, over 0. One
#      run over the tracked shell corpus (601 files at the build), a seeded offender appended: 0 corpus hits, the
#      offender reported.
# MEASURED, 191 probe files under /bin/bash 3.2 (33 break, bash -n accepts all of them): flagged
# 49, MISSED 0, OVER 1. The OVER is enumerated, not exempted: a comment `# (a lone open` inside
# `"$( ... )"` closed by an extra `) )` on the final line parses under 3.2 because the stray
# paren balances; the grammar counts the open paren and flags. Where the grammar cannot spell a
# fact it errs toward flagging. The adversary's 115 seeds: MISSED 1, OVER 3, all enumerated. The
# miss is `e/bad.sh`, which is not form (c). The 3 overs (`n1o`, `nbo`, `nco`) break only without
# their `set -n;`, which is the placement artifact that hides nested forms. Corpus: 0 hits over the
# tracked shell files, a seeded control reported in the same run.
S13_PAT=""
S13_WHY="a construct bash 3.2 closes a command substitution on early, which \`bash -n\` accepts: (d) a heredoc body inside a \`\$( )\` carrying a \`)\` that closes nothing, which runs rc 0 with a WRONG value (\`a ) here\` reads back as \`a  here\`); (a) inside a double-quoted \`\$( )\`, a comment with a lone apostrophe or \`)\` before a double-quoted string holding a space (a comment with any other unbalanced quote or paren is flagged too); (b) a bare \`case\` pattern such as \`''|*[!0-9]*) ... ;;\` in a \`\$( )\`; (c) in a brace-expanded word (a command argument, a \`local\`/\`export\` argument, a \`for\` list, an array element, a backtick outer) inside a double-quoted \`\$( )\`, a \`{\` anywhere in the word plus a single-quoted body holding an unclosed double-quoted \`\$(\`. The assignment or argument never happens and nothing reports it. Move the comment out of the substitution or balance it, write the case pattern as \`(''|*[!0-9]*)\`, and bind the single-quoted program to a variable first. For (d), balance the body's paren, or build the heredoc in a function the substitution calls (\`v=\"\$(f)\"\`)."
S13_JOIN='
function reset() {
  n = 1; ft[1] = "T"; fdq[1] = 0; fcs[1] = 0; cst[1] = ""; fcp[1] = 1; fpd[1] = 0
  hd = 0; nhp = 0; split("", seen); split("", lines); hbsub = 0; selp = 0
  ws[1] = 0; cp[1] = 1; dbk[1] = 0; hs[1] = 0; rdp[1] = 0; cmw[1] = ""; nob = 0; narr = 0
}
function hbscan(t,   j, L, c, pv) {
  L = length(t); pv = " "
  for (j = 1; j <= L; j++) {
    c = substr(t, j, 1)
    if (hbq == SQ) { if (c == SQ) hbq = ""; pv = c; continue }
    if (hbq == "\"") { if (c == BS) { j++; continue }; if (c == "\"") hbq = ""; pv = c; continue }
    if (hbq == "`") { if (c == "`") hbq = ""; pv = c; continue }
    if (c == SQ || c == "\"" || c == "`") { hbq = c; pv = c; continue }
    if (c == BS) { j++; pv = "x"; continue }
    if (c == "#" && (pv == " " || pv == "\t")) return
    if (c == "(") hbd++
    else if (c == ")") { hbd--; if (hbd < 0) { report(FNR); hbd = 0 } }
    pv = c
  }
}
function push(t) {
  n++; ft[n] = t
  fdq[n] = (t == "D") ? 1 : fdq[n - 1]
  fcs[n] = fcs[n - 1] + (t == "C"); cst[n] = ""; fcp[n] = 1; fpd[n] = 0; dsp[n] = 0; pend[n] = 0
  ws[n] = 0; cp[n] = (t == "P" && narr) ? -1 : 1; narr = 0; dbk[n] = 0; hs[n] = 0; rdp[n] = 0; cmw[n] = ""; pl[n] = FNR
}
function pop() { if (n > 1) n-- }
function report(l) {
  if (SEL || (l in seen)) return
  seen[l] = 1; print FILENAME ":" l ":" lines[l]
}
function cs() { return substr(cst[n], length(cst[n]), 1) }
function setcs(x) { cst[n] = substr(cst[n], 1, length(cst[n]) - 1) x }
function fast(s,   t, a, b) {
  if (index(s, "$(") || index(s, "`") || index(s, "<<") || index(s, BS)) return 0
  t = s; a = gsub(SQ, "", t); t = s; b = gsub(/"/, "", t)
  if (a == 0 && b % 2 == 0) return 1
  if (b == 0 && a % 2 == 0) return 1
  return 0
}
function forma(t,   j, L, c, q, d, rp) {
  q = ""; d = 0; rp = 0; L = length(t)
  for (j = 1; j <= L; j++) {
    c = substr(t, j, 1)
    if (q == SQ) { if (c == SQ) q = ""; continue }
    if (q == "\"") { if (c == BS) { j++; continue }; if (c == "\"") q = ""; continue }
    if (q == "`") { if (c == "`") q = ""; continue }
    if (c == SQ || c == "\"" || c == "`") { q = c; continue }
    if (c == BS) { j++; continue }
    if (c == "(") d++
    else if (c == ")") { d--; if (d < 0) { d = 0; rp = 1 } }
  }
  if (q != "" || d != 0) return 1
  return rp ? 2 : 0
}
# Form (c): bash 3.2 brace expansion re-scans the raw text of every word holding a `{` (brace_gobbler).
# That scan toggles quotes WITHOUT nesting, so a `"` inside a double-quoted `$( )` holding a single-quoted body closes its quote early
# and the next `$(` is extracted from the wrong place; an unclosed extraction is "bad substitution".
# xds/sdq/sxe/dbr mirror extract_delimited_string, skip_double_quoted, string_extract and
# extract_dollar_brace_string; each returns the index of the closing character, or 0 when none.
function xds(t, i,   L, c, r, p) {
  L = length(t)
  for (; i <= L; i++) {
    c = substr(t, i, 1)
    if (c == "#" && substr(t, i - 1, 1) ~ /^[ \t\n]$/) { p = index(substr(t, i), "\n"); if (!p) return 0; i = i + p - 1; continue }
    if (c == BS) { i++; continue }
    if (c == "$" && substr(t, i + 1, 1) == "(") { r = xds(t, i + 2); if (!r) return 0; i = r; continue }
    if (c == "(") { r = xds(t, i + 1); if (!r) return 0; i = r; continue }
    if (c == ")") return i
    if (c == "`") { r = sxe(t, i + 1); if (!r) return 0; i = r; continue }
    if (c == SQ) { p = index(substr(t, i + 1), SQ); if (!p) return 0; i = i + p; continue }
    if (c == "\"") { r = sdq(t, i + 1); if (!r) return 0; i = r; continue }
  }
  return 0
}
function sdq(t, i,   L, c, r) {
  L = length(t)
  for (; i <= L; i++) {
    c = substr(t, i, 1)
    if (c == BS) { i++; continue }
    if (c == "`") { r = sxe(t, i + 1); if (!r) return 0; i = r; continue }
    if (c == "$" && substr(t, i + 1, 1) == "(") { r = xds(t, i + 2); if (!r) return 0; i = r; continue }
    if (c == "$" && substr(t, i + 1, 1) == "{") { r = dbr(t, i + 2); if (!r) return 0; i = r; continue }
    if (c == "\"") return i
  }
  return 0
}
function sxe(t, i,   L, c) {
  L = length(t)
  for (; i <= L; i++) { c = substr(t, i, 1); if (c == BS) { i++; continue }; if (c == "`") return i }
  return 0
}
function dbr(t, i,   L, c, r, p, d) {
  L = length(t); d = 1
  for (; i <= L; i++) {
    c = substr(t, i, 1)
    if (c == BS) { i++; continue }
    if (c == "$" && substr(t, i + 1, 1) == "{") { d++; i++; continue }
    if (c == "}") { d--; if (d == 0) return i; continue }
    if (c == "`") { r = sxe(t, i + 1); if (!r) return 0; i = r; continue }
    if (c == "$" && substr(t, i + 1, 1) == "(") { r = xds(t, i + 2); if (!r) return 0; i = r; continue }
    if (c == SQ) { p = index(substr(t, i + 1), SQ); if (!p) return 0; i = i + p; continue }
    if (c == "\"") { r = sdq(t, i + 1); if (!r) return 0; i = r; continue }
  }
  return 0
}
# gob: brace_gobbler over one word; the index of the `$(` whose extraction fails, or 0.
function gob(t,   L, i, c, q) {
  L = length(t); q = ""
  for (i = 1; i <= L; i++) {
    c = substr(t, i, 1)
    if (c == BS && q != SQ) { i++; continue }
    if (q != "") { if (c == q) q = ""; continue }
    if (c == "$" && substr(t, i + 1, 1) == SQ) { for (i += 2; i <= L && substr(t, i, 1) != SQ; i++) if (substr(t, i, 1) == BS) i++; continue }
    if (c == SQ || c == "\"" || c == "`") { q = c; continue }
    if (c == "$" && substr(t, i + 1, 1) == "(") { c = xds(t, i + 2); if (!c) return i; i = c }
  }
  return 0
}
function nlc(t) { return gsub(/\n/, "", t) }
function cform(t, l0,   k) {
  if (nob || !index(t, "{") || !index(t, "$(")) return
  k = gob(t); if (k) report(l0 + nlc(substr(t, 1, k)))
}
function wtext(a, b, c, d,   t, k) {
  if (a == c) return substr(lines[a], b, d - b)
  t = substr(lines[a], b)
  for (k = a + 1; k < c; k++) t = t "\n" lines[k]
  return t "\n" substr(lines[c], 1, d - 1)
}
# A word is brace-expanded unless it is an assignment in command position, a here-string, a case
# word or pattern, or a `[[ ]]` operand. An argument of local/export/declare/readonly IS expanded.
function wend(el, ec,   t, e) {
  ws[n] = 0; t = wtext(wl[n], wc[n], el, ec); e = 1
  if (hs[n]) { e = 0; hs[n] = 0; rdp[n] = 0 }
  else if (rdp[n]) rdp[n] = 0
  else if (cs() == "W" || cs() == "P" || cs() == "Q") e = 0
  else if (dbk[n]) { e = 0; if (t == "]]") dbk[n] = 0 }
  else if (cp[n] == 1) {
    if (t ~ /^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?=/) e = 0
    else if (t == "[[") { e = 0; dbk[n] = 1; cp[n] = 0 }
    else if (t !~ /^(if|then|else|elif|do|while|until|time|!|[{}])$/) { cmw[n] = t; cp[n] = 0 }
  } else if (cmw[n] == "set") { if (t ~ /^\+[A-Za-z]*B/) nob = 1; else if (t ~ /^-[A-Za-z]*B/) nob = 0 }
  if (e) cform(t, wl[n])
}
function wtok(s, i, c) {
  narr = 0
  if (c ~ /^[ \t;&|()<>]$/) {
    if (ws[n]) {
      if (c == "(" && cp[n] == 1 && wl[n] == FNR && substr(s, wc[n], i - wc[n]) ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=$/) narr = 1
      wend(FNR, i)
    }
    if (c == "<" || c == ">") { rdp[n] = 1; if (substr(s, i, 3) == "<<<") hs[n] = 1 }
    else if (c != " " && c != "\t" && cp[n] >= 0) cp[n] = 1
    return
  }
  if (!ws[n] && c != "#") { ws[n] = 1; wl[n] = FNR; wc[n] = i }
}
# A backtick body is re-parsed when it runs; split it into words and judge each one.
function kscan(b, l0,   L, i, s, c, p, r, w, c0) {
  L = length(b); i = 1; c0 = 1
  while (i <= L) {
    c = substr(b, i, 1)
    if (c ~ /^[ \t\n;&|()<>]$/) { if (c !~ /^[ \t]$/) c0 = 1; i++; continue }
    s = i
    for (; i <= L; i++) {
      c = substr(b, i, 1)
      if (c == BS) { i++; continue }
      if (c == SQ) { p = index(substr(b, i + 1), SQ); i = p ? i + p : L; continue }
      if (c == "\"") { r = sdq(b, i + 1); i = r ? r : L; continue }
      if (c == "$" && substr(b, i + 1, 1) == "(") { r = xds(b, i + 2); i = r ? r : L; continue }
      if (c ~ /^[ \t\n;&|()<>]$/) break
    }
    w = substr(b, s, i - s)
    if (c0 && w ~ /^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?=/) continue
    c0 = 0; cform(w, l0 + nlc(substr(b, 1, s)))
  }
}
function dqclose(   m) {
  if (!dsp[n]) return
  for (m = n - 1; m > 1; m--) if (pend[m]) { report(pend[m]); pend[m] = 0 }
}
function dollar(s, i,   d) {
  d = substr(s, i + 1, 1)
  if (d == "(") { if (substr(s, i + 2, 1) == "(") { push("A"); fpd[n] = 2; return i + 3 }; push("C"); return i + 2 }
  if (d == "{") { push("B"); fpd[n] = 1; return i + 2 }
  if (ft[n] == "D") return i + 1
  if (d == SQ) { push("E"); return i + 2 }
  if (d == "\"") { push("D"); return i + 2 }
  return i + 1
}
function heredoc(s, i,   j, w, st, q, e) {
  j = i + 2; st = 0
  if (substr(s, j, 1) == "-") { st = 1; j++ }
  while (substr(s, j, 1) == " " || substr(s, j, 1) == "\t") j++
  q = substr(s, j, 1)
  if (q == SQ || q == "\"") {
    e = index(substr(s, j + 1), q); if (e == 0) return length(s) + 1
    w = substr(s, j + 1, e - 1); j = j + e + 1
  } else if (match(substr(s, j), WRD)) {
    w = substr(s, j, RLENGTH); j = j + RLENGTH; gsub(/[\\"]/, "", w); gsub(SQ, "", w)
  } else return j
  if (w == "") return j
  if (nhp == 0) { hbsub = 0; hbd = 0; hbq = "" }
  if (fcs[n] > 0) { hbsub = 1; selp = 1 }
  nhp++; hpd[nhp] = w; hpt[nhp] = st
  return j
}
function word(w) {
  if (cs() == "W" && w == "in") { setcs("P"); fcp[n] = 0; return }
  if (fcp[n] && w == "case") { cst[n] = cst[n] "W"; fcp[n] = 0; return }
  if (fcp[n] && w == "esac" && (cs() == "B" || cs() == "P")) { setcs(""); fcp[n] = 0; return }
  fcp[n] = (w ~ /^(then|do|else|elif|if|while|until|time|!|[{}])$/) ? 1 : 0
}
function code(s, i, L,   c, x, pv) {
  c = substr(s, i, 1)
  wtok(s, i, c)
  x = cs()
  if (x == "P") {
    if (c == " " || c == "\t") return i + 1
    if (substr(s, i, 4) == "esac" && (i + 4 > L || substr(s, i + 4, 1) ~ /^[ \t;)&|]$/)) { setcs(""); fcp[n] = 0; return i + 4 }
    if (c == "(") { setcs("Q"); return i + 1 }
    if (c != "#") { if (fcs[n] > 0) report(FNR); setcs("Q") }
  }
  if (x == "Q" && c == ")") { setcs("B"); fcp[n] = 1; return i + 1 }
  if (c == BS) { fcp[n] = 0; return i + 2 }
  if (c == SQ) { push("S"); return i + 1 }
  if (c == "\"") { fcp[n] = 0; push("D"); return i + 1 }
  if (c == "`") { fcp[n] = 0; push("K"); pc[n] = i; return i + 1 }
  if (c == "$") { fcp[n] = 0; return dollar(s, i) }
  if (c == "#") {
    pv = (i == 1) ? " " : substr(s, i - 1, 1)
    if (pv ~ /^[ \t;&|()]$/) {
      if (fcs[n] > 0 && fdq[n]) { r = forma(substr(s, i + 1)); if (r == 1) report(FNR); else if (r == 2) pend[n] = FNR }
      return L + 1
    }
  }
  if (c == "(" && substr(s, i + 1, 1) == "(" && substr(s, i - 1, 1) !~ /^[<>]$/) { push("A"); fpd[n] = 2; return i + 2 }
  if (c == "(") { push("P"); return i + 1 }
  if (c == ")") { if (ft[n] == "P" || ft[n] == "C") pop(); fcp[n] = 0; return i + 1 }
  if (c == "<") {
    if (substr(s, i, 3) == "<<<") return i + 3
    if (substr(s, i, 2) == "<<") return heredoc(s, i)
    return i + 1
  }
  if (c == ";") {
    if (substr(s, i + 1, 1) == ";" || substr(s, i + 1, 1) == "&") {
      if (x == "B") setcs("P")
      fcp[n] = 1; return (substr(s, i + 2, 1) == "&") ? i + 3 : i + 2
    }
    fcp[n] = 1; return i + 1
  }
  if (c == "&" || c == "|") { fcp[n] = 1; return i + 1 }
  if (c == " " || c == "\t") return i + 1
  if (match(substr(s, i), WRD)) { word(substr(s, i, RLENGTH)); return i + RLENGTH }
  fcp[n] = 0; return i + 1
}
function scan(s,   i, L, t, c, p) {
  i = 1; L = length(s)
  while (i <= L) {
    t = ft[n]
    if (t == "T" || t == "C" || t == "P") { i = code(s, i, L); continue }
    if (t == "S") {
      p = index(substr(s, i), SQ)
      if (p == 0) { i = L + 1; continue }
      i = i + p; pop(); continue
    }
    if (t == "D") {
      if (!match(substr(s, i), DQS)) { i = L + 1; continue }
      if (RSTART > 1 && substr(s, i, RSTART - 1) ~ /[ \t]/) dsp[n] = 1
      i = i + RSTART - 1; c = substr(s, i, 1)
      if (c == BS) { i += 2; continue }
      if (c == "\"") { dqclose(); pop(); i++; continue }
      if (c == "`") { push("K"); pc[n] = i; i++; continue }
      i = dollar(s, i); continue
    }
    if (t == "K") {
      if (!match(substr(s, i), BTS)) { i = L + 1; continue }
      i = i + RSTART - 1; c = substr(s, i, 1)
      if (c == BS) { i += 2; continue }
      kscan(wtext(pl[n], pc[n] + 1, FNR, i), pl[n]); pop(); i++; continue
    }
    if (t == "E") {
      if (!match(substr(s, i), ANS)) { i = L + 1; continue }
      i = i + RSTART - 1; c = substr(s, i, 1)
      if (c == BS) { i += 2; continue }
      pop(); i++; continue
    }
    c = substr(s, i, 1)
    if (c == BS) { i += 2; continue }
    if (c == "\"") { push("D"); i++; continue }
    if (c == "$") { i = dollar(s, i); continue }
    if (c == SQ && t == "B" && ft[n - 1] != "D") { push("S"); i++; continue }
    if (t == "A") { if (c == "(") fpd[n]++; else if (c == ")") { fpd[n]--; if (fpd[n] == 0) pop() } }
    else if (t == "B") { if (c == "{") fpd[n]++; else if (c == "}") { fpd[n]--; if (fpd[n] == 0) pop() } }
    i++
  }
  if (ft[n] == "T" || ft[n] == "C" || ft[n] == "P") {
    fcp[n] = 1
    if (substr(s, L, 1) != BS || substr(s, L - 1, 1) == BS) { if (ws[n]) wend(FNR, L + 1); if (cp[n] >= 0) cp[n] = 1 }
  }
}
BEGIN {
  SQ = sprintf("%c", 39); BS = "\\"
  WRD = "^[^] \t;&|()<>\"`$\\\\" SQ "]+"
  DQS = "[\\\\\"$`]"; BTS = "[\\\\`]"; ANS = "[\\\\" SQ "]"
  SEL = (ENVIRON["S13_SELECT"] == "1")
  SELRE = "[$][(][^)]*[^<]<<-?[ \t]*[\\\\\"" SQ "A-Za-z_]"
}
FNR == 1 { reset() }
{
  lines[FNR] = $0
  if (SEL && $0 ~ SELRE) { print FILENAME; nextfile }
  if (hd) {
    l = $0; if (hpt[hi]) sub(/^\t+/, "", l)
    if (l == hpd[hi]) { hi++; if (hi > nhp) { hd = 0; nhp = 0 } }
    else if (hbsub) hbscan($0)
    next
  }
  if (n == 1 && fast($0)) next
  scan($0)
  if (SEL && selp) { print FILENAME; nextfile }
  if (nhp > 0) { hd = 1; hi = 1 }
}
'

# S14 IS THE ONE ARM HERE WITH NO GRAMMAR OF ITS OWN, AND THAT IS DELIBERATE: ITS ORACLE IS THE PARSER THAT
# EXECUTES THE FILE. Its subject is a quote or paren that bash 3.2 cannot balance inside a heredoc
# body nested in a command substitution -- `v="$(cat <<'X'` / `it's here` / `X` / `)"`. bash 3.2
# scans a `$( )` body for its closing paren with a quote-tracking scanner that does not know a
# heredoc body is literal, so the lone apostrophe opens a quote that never closes. Measured under
# `/bin/bash` 3.2.57: rc=2 at run time ("unexpected EOF while looking for matching"), and
# `bash -n` REJECTS it -- so unlike BL-647's three forms this one is visible to a parse, and the
# arm is that parse. The trigger is an UNBALANCED quote or `(` in the body: one or three
# apostrophes fail, two pass; a lone `"` fails; a lone `(` fails. The outer double quote is NOT
# required (`v=$(cat <<'X' ...)` fails too) and the delimiter's quoting does not matter (`<<X`,
# `<<'X'`, `<<"X"`, `<<-'X'` all fail). A backtick substitution and a heredoc outside any `$( )`
# (including one inside a function the substitution calls) parse and run.
#
# WHY AN ARM WHEN THE GATE ALREADY RUNS `bash -n`. `syntax_all` in `.githooks/pre-push` parses
# `scripts/`, `core/scripts/`, `core/hooks/`, the reconcile engine and the hooks -- 151 of the 603
# tracked `.sh` files when this arm was built. The other 452, 431 of them fixture scripts, were
# parsed by nothing: a fixture carrying the form fails at run time as a bare `FAIL <name>` with no
# cause, and a helper SOURCED by a fixture returns 1 to a caller that keeps going. 15 of the 16
# files then carrying a heredoc opener on a `$(` line were fixtures, outside that glob. This arm
# runs over the `shell` corpus, so every tracked `.sh` is parsed.
#
# S14_PAT IS THE BINARY, PINNED. `syntax_all` runs `bash` off PATH; bash 4 and later parse a `$( )`
# body recursively and ACCEPT this form, so a machine with a newer bash first on PATH would pass a
# file the 3.2 floor cannot run. `/bin/bash` is the floor this file exists to hold. NOT measured:
# a bash 5 parse of the form -- none is installed on the machine the arm was built on.
#
# COST, AND THE NARROWING THAT SET IT. The first cut forked one `/bin/bash -n` per corpus file,
# about 600 per validator call. The arm now parses only the files S13's lexer SELECTS: one awk over
# the whole list (`S13_SELECT=1` runs S13_JOIN in select mode, reporting nothing and printing each
# file once, at the first heredoc opener whose lexer state is inside a `$(`), then one `-n` per
# selected file. The selector is S13's lexer and not a regex because a regex keyed on the opener's
# LINE misses the multi-line spelling (`"$(` on one line, `cat <<X` on the next), and a looser
# "opener and `$(` anywhere in the file" regex selects 292 of 604 files. The selector self-probes
# below in both directions on its own seed set (`$(cat<<X`, `$( cat <<-'X'`, a nested
# `$(echo "$(cat <<X`, the opener on the line after a multi-line `"$(`; quiet on a heredoc outside
# any `$(`, a function-held one and a backtick one). The selector has TWO keys, and the second
# exists because the first alone failed its false-negative measurement: against the 16 files the
# BL-689 census found by the line regex `$(` ... `<<`, the lexer key selected 7. The other 9 carry
# that text in a `<<<` here-string, a comment or a quoted string -- not a heredoc in a `$(` -- but
# a prefilter that drops a file the census named is a parse that silently never happens, so the
# census regex is ALSO a selection key, read on every line (heredoc bodies and comments included),
# narrowed to a real opener (`[^<]<<-?` then a quote, backslash or word) so a `<<<` here-string is
# not one -- the unnarrowed form selected 130 files of 603. Measured with both keys: 15 of 603
# selected, 14 of the 16 census files. The other 2 (`check-24-adversarial-convergence/run.sh`,
# `suite-dispatch-order/run.sh`) hold no heredoc opener inside any `$( )`: their census lines are
# `<<<` here-strings the census regex mistook for openers, and both parse under `/bin/bash -n`.
# A file the selector cannot reach -- a parse error that is NOT a heredoc in a `$( )` -- is
# outside this arm by design; `syntax_all` in the gate parses scripts/, core/scripts/ and the hooks.
# FALSE-POSITIVE SET: EMPTY, measured over the tracked shell corpus at the build (0 rejected; the
# seeded offender rejected rc=2 in the same run). One fixture seed (`n4`) carried python lines
# bare in a `.sh`, which no real file does, and was rewritten to the heredoc'd embedding the
# corpus actually uses.
S14_PAT="/bin/bash"
S14_WHY="a shell file that \`/bin/bash\` 3.2 cannot PARSE. The usual cause here is an unbalanced apostrophe, double quote or \`(\` in a heredoc body nested inside a \`\$( )\` -- bash 3.2 scans the substitution for its closing paren with a quote tracker that does not know the heredoc body is literal, so \`v=\"\$(cat <<'X'\` / \`it's here\` / \`X\` / \`)\"\` dies with rc=2 (\"unexpected EOF while looking for matching\"). The gate's own \`bash -n\` covers only \`scripts/\`, \`core/scripts/\`, \`core/hooks/\` and the hooks, so a fixture carrying it fails at run time as a bare FAIL with no cause. Balance the body, write it with the Write tool into a file the script reads, or build it outside the substitution (a function holding the heredoc, called as \`v=\"\$(f)\"\`, parses). The message after each path is bash's own."

# Only S1 subtracts. Declared explicitly rather than defaulted in a loop, because `set -u`
# turns a missing one into an abort mid-scan, and an aborted scan prints fewer findings than
# a clean one rather than more.
S2_SKIP=""; S3_SKIP=""; S4_SKIP=""; S5_SKIP=""; S6_SKIP=""; S8_SKIP=""; S8b_SKIP=""; S9_SKIP=""; S12_SKIP=""; S13_SKIP=""; S14_SKIP=""
# S7's one measured false positive is PYTHON, not awk. Several shell files here embed a
# heredoc'd python program, and `re.sub(r"...", r"\1...")` is correct there -- python has
# backreferences and awk does not. The subtraction is on the LANGUAGE (`re.` qualifies the
# call) rather than on a file path, so a new embedded python program is covered the day it
# lands and an awk backreference in the same file is still caught.
S7_SKIP="re\\.g?sub\\("

ARMS="S1 S2 S3 S4 S5 S6 S7 S8 S8b S9 S10 S11 S12 S13 S14"

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
S12_CORPUS=shell; S13_CORPUS=shell; S14_CORPUS=shell
S1_COMMENTS=skip; S2_COMMENTS=skip; S3_COMMENTS=skip; S4_COMMENTS=skip
S5_COMMENTS=skip; S6_COMMENTS=skip; S7_COMMENTS=skip; S8_COMMENTS=keep; S8b_COMMENTS=keep
S9_COMMENTS=skip; S10_COMMENTS=skip; S11_COMMENTS=skip; S12_COMMENTS=skip; S13_COMMENTS=keep; S14_COMMENTS=keep
# KIND. `line` is one `grep -E` per line through `scan`; `join` is S12's two-pass program over
# whole files through `scan_join`, which the PATTERN still drives. `awk13` is S13's program, which
# takes NO pattern: S13_PAT is empty and inert, the one PAT cell here that no scan reads.
# `parse` is S14's: the PAT cell is the shell binary `scan_parse` runs `-n` under, and its probe
# pair is its own, because the shared `good.sh` carries awk and python lines no shell parses.
S1_KIND=line; S2_KIND=line; S3_KIND=line; S4_KIND=line; S5_KIND=line; S6_KIND=line
S7_KIND=line; S8_KIND=line; S8b_KIND=line; S9_KIND=line; S10_KIND=line; S11_KIND=line; S12_KIND=join; S13_KIND=awk13
S14_KIND=parse

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
# AN AWK ARM THAT CANNOT OPEN A LISTED FILE MUST REFUSE, NEVER PASS. BSD awk meets an unopenable
# file argument by printing "can't open file", exiting 2 and abandoning every file after it --
# END never runs. With its stderr sent to /dev/null and its status lost in a command
# substitution, the arm then reports PASS over the part of the corpus before that file, which
# reads exactly like a clean scan of all of it. `.claude/rules/tool-hazards.md` (awk's `getline`
# reads an unopenable file as an empty one; a batched rewrite loses the diagnostic channel the
# per-file loop had) and `.claude/rules/verification-discipline.md` ("A glob that matches nothing
# must not report success") are the two rules this applies: count what was SCANNED and compare it
# against the list. A prepended rule counts the files whose first record the program saw; a file
# that exists and is EMPTY has no first record and is subtracted from the expected count, so an
# empty file is not a refusal. A non-zero awk status or a count that differs is recorded in
# `$probe/refused` (a command substitution cannot set `fail`) and the run exits 2 before PASS.
# `ARM_NOW` names the arm in the message; the probe and corpus loops set it.
awk_counted() { # awk_counted <awk-program> <file...>   (stdout is the program's; the environment passes through)
  local prog="$1" want=0 got rc f bad="" opened; shift
  for f in "$@"; do { [ -f "$f" ] && [ ! -s "$f" ]; } || want=$((want + 1)); done
  : > "$probe/awkn"
  AWKN_OUT="$probe/awkn" awk 'FNR == 1 { AWKN_SEEN++ } END { print AWKN_SEEN + 0 > ENVIRON["AWKN_OUT"] }'"$prog" "$@" 2>"$probe/awke"
  rc=$?; got="$(cat "$probe/awkn")"
  if [ "$rc" -ne 0 ] || [ "${got:-none}" != "$want" ]; then
    for f in "$@"; do { [ -f "$f" ] && [ -r "$f" ]; } || { bad="$f"; break; }; done
    # An awk that aborted before its END block leaves no count: say so, never a zero it did not measure.
    if [ "$rc" -ne 0 ] || [ -z "$got" ]; then opened=", open count unknown (awk aborted), $want listed file(s)"
    else opened=", having opened $got of $want listed file(s)"; fi
    printf 'REFUSED: %s: awk exited %s%s; unopenable: %s (%s). An arm that could not read its whole corpus has not scanned it.\n' \
      "${ARM_NOW:-?}" "$rc" "$opened" "${bad:-unknown}" "$(head -1 "$probe/awke")" >&2
    printf '%s\n' "${ARM_NOW:-?}" >> "$probe/refused"
    return 2
  fi
}
# The same contract as `scan`, same `file:line:text` output, same comment and skip filters
# applied after -- so a `join` arm is read by the loops below exactly as a `line` arm is.
scan_join() { # scan_join <escape-pattern> <skip-pattern-or-empty> <skip|keep comments> <file...>
  local pat="$1" skip="$2" comments="$3"; shift 3
  local out
  out="$(S12_ESC="$pat" awk_counted "$S12_JOIN" "$@")"
  [ "$comments" = "skip" ] && out="$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<<"$out")"
  [ -n "$skip" ] && out="$(grep -vE "$skip" <<<"$out")"
  printf '%s' "$out"
}
# S13's program takes no pattern (the PAT cell is empty), but keeps the contract and the filters.
# COMMENTS is `keep`: S13 must SEE comments, because form (a)'s trigger is comment text.
scan_awk13() { # scan_awk13 <unused-pattern> <skip-pattern-or-empty> <skip|keep comments> <file...>
  local skip="$2" comments="$3"; shift 3
  local out
  out="$(awk_counted "$S13_JOIN" "$@")"
  [ "$comments" = "skip" ] && out="$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<<"$out")"
  [ -n "$skip" ] && out="$(grep -vE "$skip" <<<"$out")"
  printf '%s' "$out"
}
# The same contract again: one `file:line:text` row per file the binary refuses to parse, where
# `text` is the first line of the binary's own stderr with its `path: line N:` prefix removed.
# No pipe: the first line is cut with a parameter expansion, so pipefail cannot rewrite a status.
# Only the files S13's lexer SELECTS are parsed (see S14's header): one awk, then one `bin -n`
# per selected file.
scan_parse() { # scan_parse <shell-binary> <skip-pattern-or-empty> <skip|keep comments> <file...>
  local bin="$1" skip="$2" comments="$3" f e ln out="" sel; shift 3
  # Counted like S12 and S13 (see `awk_counted`): an EMPTY selection over a readable corpus is
  # "nothing to parse", while a failed open is a refusal -- the two must not share the return 0.
  # Select mode leaves each file at its first selecting line by `nextfile`, after FNR == 1 has
  # already been counted, so a selected file is counted once.
  sel="$(S13_SELECT=1 awk_counted "$S13_JOIN" "$@")" || return 2
  [ -n "$sel" ] || return 0
  while IFS= read -r f; do
    e="$("$bin" -n "$f" 2>&1 >/dev/null </dev/null)" && continue
    e="${e%%$'\n'*}"
    ln="$(sed -n 's/^.*: line \([0-9][0-9]*\): .*$/\1/p' <<<"$e")"
    out="$out$f:${ln:-0}:$(sed 's/^.*: line [0-9][0-9]*: //' <<<"$e")"$'\n'
  done <<<"$sel"
  [ "$comments" = "skip" ] && out="$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<<"$out")"
  [ -n "$skip" ] && out="$(grep -vE "$skip" <<<"$out")"
  printf '%s' "${out%$'\n'}"
}
run_arm() { # run_arm <kind> <pattern> <skip> <comments> <file...>
  local k="$1"; shift
  if [ "$k" = "join" ]; then scan_join "$@"
  elif [ "$k" = "awk13" ]; then scan_awk13 "$@"
  elif [ "$k" = "parse" ]; then scan_parse "$@"
  else scan "$@"; fi
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
# S14's pair, one property apart: the offender's heredoc body inside `"$( )"` carries ONE
# apostrophe, the near-miss's carries a balanced pair in the identical structure -- so an arm
# that flagged every heredoc in a substitution, or every apostrophe in one, misfires here.
cat > "$probe/bad-parse.sh" <<'BADPEOF'
v="$(cat <<'X'
it's here
X
)"
echo "$v"
BADPEOF
cat > "$probe/good-parse.sh" <<'GOODPEOF'
v="$(cat <<'X'
it's x's here
X
)"
echo "$v"
GOODPEOF

# S13 reads MULTI-LINE state, so its probe is its own pair of files: appended to the shared pair
# its state would be carried through every other arm's seeded lines. Bad: each failing form, with
# the entry's exact lines. Good: each paired passing form, one character or one context away.
cat > "$probe/s13bad.sh" <<'S13BADEOF'
x="$(
  # the scorer's own subshell (bash -c's PPID) is excluded
  echo ok
)"
y="$(
  case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac
  echo "$k"
)"
if true; then
  amutant_arm a "$(amut n 'x "$(p"){y} 1')" z
fi
v="$(cat <<'X'
a ) here
X
)"
S13BADEOF
cat > "$probe/s13good.sh" <<'S13GOODEOF'
x="$(
  # the scorer own subshell, 'quoted pair' ok
  echo ok
)"
u=$(
  # it's an unquoted substitution
  echo ok
)
y="$(
  case "$h" in (''|*[!0-9]*) k=x ;; (*) k=1 ;; esac
  echo "$k"
)"
if true; then
  amutant_arm a "$(amut n 'x $(p){y} 1')" z
  amutant_arm a "$(amut n 'a "$(printf" b')" z
  v="$(amut n 'x "$(p"){y} 1')"
  amutant_arm a "$(amut n 'x "$(p") 1')" z
fi
v="$(cat <<'X'
a ( b ) here, it's ) ok's, a \) b
X
)"
f() { cat <<'X'
a ) here
X
}
S13GOODEOF

# S14's SELECTOR, probed in both directions BEFORE the corpus: every spelling of a heredoc opened
# inside a `$(` must be SELECTED (a miss there is a file S14 never parses), and a heredoc outside
# any `$(` must not be, or the narrowing is not a narrowing.
mkdir -p "$probe/sel"
printf '%s\n' 'v="$(cat<<X' 'a' 'X' ')"' > "$probe/sel/y1.sh"
printf '%s\n' "v=\"\$( cat <<-'X'" '	a' '	X' ')"' > "$probe/sel/y2.sh"
printf '%s\n' 'v="$(echo "$(cat <<X' 'a' 'X' ')")"' > "$probe/sel/y3.sh"
printf '%s\n' 'v="$(' "  cat <<'X'" 'a' 'X' ')"' > "$probe/sel/y4.sh"
printf '%s\n' 'v=$(f <<"X"' 'a' 'X' ')' > "$probe/sel/y5.sh"
printf '%s\n' 'cat <<X' 'a $(b) c' 'X' > "$probe/sel/n1.sh"
printf '%s\n' 'f() { cat <<X' 'a' 'X' '}' 'v="$(f)"' > "$probe/sel/n2.sh"
printf '%s\n' 'v="`cat <<X' 'a' 'X' '`"' > "$probe/sel/n3.sh"
printf '%s\n' 'v="$(cat <<<"a")"' 'n=$((1 << 2))' > "$probe/sel/n4.sh"
sel_got="$(S13_SELECT=1 awk "$S13_JOIN" "$probe"/sel/y*.sh "$probe"/sel/n*.sh 2>/dev/null)"
for y in "$probe"/sel/y*.sh; do
  grep -qxF "$y" <<<"$sel_got" || err "S14's selector did not select $(basename "$y"), a heredoc opened inside a \`\$(\`. S14 would never parse such a file, and its clean run would read exactly like a parse that passed."
done
for nn in "$probe"/sel/n*.sh; do
  grep -qxF "$nn" <<<"$sel_got" && err "S14's selector selected $(basename "$nn"), a heredoc outside any \`\$(\`: the prefilter has stopped narrowing."
done

for a in $ARMS; do
  ARM_NOW="$a"
  eval "p=\$${a}_PAT"
  eval "sk=\$${a}_SKIP"
  eval "cm=\$${a}_COMMENTS"
  eval "kd=\$${a}_KIND"
  pb="$probe/bad.sh"; pg="$probe/good.sh"
  if [ "$a" = S13 ]; then pb="$probe/s13bad.sh"; pg="$probe/s13good.sh"; fi
  if [ "$kd" = "parse" ]; then pb="$probe/bad-parse.sh"; pg="$probe/good-parse.sh"; fi
  hit_bad="$(run_arm "$kd" "$p" "$sk" "$cm" "$pb")"
  hit_good="$(run_arm "$kd" "$p" "$sk" "$cm" "$pg")"
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
    ARM_NOW="$a"
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
if [ -s "$probe/refused" ]; then
  printf 'validate-shell-portability: REFUSED -- %s could not open every listed file (see REFUSED above). Exit 2: not a PASS and not a finding.\n' "$(sort -u "$probe/refused" | paste -sd ' ' -)" >&2
  exit 2
fi
if [ "$fail" -eq 0 ]; then
  say "validate-shell-portability: PASS -- $n_shell shell file(s) + $n_instr core file(s) ($n_doc non-shell) + $n_fixture fixture shell file(s), $n_arms arms (S1 sed -i, S2 mapfile, S3 declare -A, S4 setsid, S5/S6 backslash-s, S7 awk backreference, S8 unquoted rev-path, S8b unbraced \$VAR: rev-path in non-shell text, S9 git-grep ERE escape, S10 multibyte bracket class, S11 unguarded cd in a fixture script, S12 GNU escape reaching [[ =~ ]], S13 command substitution bash 3.2 closes early or misreads, S14 a heredoc-in-\$( ) file /bin/bash 3.2 cannot parse), every arm probed in both directions."
fi
exit "$fail"
