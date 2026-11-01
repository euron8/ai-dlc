#!/usr/bin/env bash
# validate-mutant-kills.sh -- a mutant kill is emitted only through the shared helper, which
# refuses unless the same run asserted that the unmutated arm passed.
#
# usage:  validate-mutant-kills.sh            check the tree against the allowlist (exit 0/1/2)
#         validate-mutant-kills.sh --derive   print the derived offender set, one fixture per line
#
# THE DEFECT. A mutant arm's kill condition is usually a value the UNMUTATED arm would also
# print if it were failing, so a mutant that breaks the arm's SETUP rather than its subject
# scores as killed. Measured on check-22-spawn-ledger: 41 of 43 mutant arms scored a kill
# without asserting, in the same run, that the arm they guard had passed.
#
# WHY THE EMISSION SITE AND NOT THE DATA FLOW. "No same-run base pass" is data flow and cannot
# be grepped. The emission site can: `mutant_killed <flag> <name> <message>` in
# core/fixtures/lib/mutant.sh is the one sanctioned way to print a kill, and it refuses
# (FIXTURE BROKEN, return 2, no ok) unless the flag is 1. Whether the flag is a value the
# unmutated run actually set is the fixture's to bind -- check-22's NB BINDING arm does it.
#
# THE ARMS.
#   M1  a non-comment line of core/fixtures/<fx>/run.sh carrying KILLED or killed (outside the
#       enumerated non-kill senses, THE GRAMMAR below) that is not routed through mutant_killed,
#       in a fixture NOT on the allowlist -> FAIL.
#   M2  a fixture on the allowlist with no unrouted emission left (a STALE row), or a listed
#       fixture whose run.sh is gone -> FAIL. Migrate a fixture and its row must go in the same
#       change.
#   M3  a duplicate allowlist row -> FAIL.
#   M4  an allowlist row whose fixture is NOT a row of the allowlist at origin/main -> FAIL.
#       This is what makes the list DOWN-ONLY: M2 alone refuses a stale row but accepts an
#       ADDED row for a fixture that still has unrouted kills, and a row-count ceiling would
#       accept a swap that keeps the count. The base is `git show origin/main:<allowlist>`,
#       read per row, so a swap is an added row. Two states have no base and SKIP, printing
#       why, with exit 0: origin/main does not resolve (a sandbox, a fresh clone, a non-git
#       copy) -- the policy of validate-release-version.sh's branch-base arm, which prints
#       "not evaluated -- origin/main ... is absent" and passes -- and origin/main carries no
#       allowlist (the release that first ships it).
#   M5  a need_base/mutant_killed call site in any core/fixtures/<fx>/run.sh, allowlisted or
#       not, whose flag argument is not BOUND -> FAIL. M1 proves a kill goes through the
#       helper; M5 proves the flag the helper gates on is not a constant.
#
# M5 GRAMMAR. One awk over the corpus. Heredoc bodies are data and are skipped (the marking is
# lifted from check-22-spawn-ledger/run.sh, its NB BINDING awk). Comments and string text are
# blanked by a quote tracker that carries ' " $' and $( ) state across lines; a line SPELLED
# like a call that the tracker reads as string text is itself refused, so quote drift cannot
# hide a site. The first word after the helper name is the flag. ACCEPTED:
#   "${X:-0}" or "$X", where X is a flag: every `X=` assignment M5 sees is the literal =0 or
#     =1, there is at least one =1, and each =1 sits in a PASSING BRANCH, judged by CONTENT, not
#     position. A body is a then/elif/else branch (to the next elif/else/fi at its depth), a case
#     arm, or an `&& { }` / `|| { }` group; ok and bad/fail/note_fail are charged to the innermost
#     body that holds them. A body PASSES when it calls ok and not bad. A body that calls neither
#     passes only when a sibling branch of the same if calls bad and not ok (the failing side
#     reports, so this side is the pass -- gate-series-rung:182); a silent case arm inherits the
#     body around the case; a word in a case PATTERN (`else)`, `fi|then)`, `ok)`) is pattern text, never
#     a keyword or a reporter call (self-update-gate:5158). `[ "${B_a:-0}${B_b:-0}" = 11 ] && X=1` passes when every operand is a
#     bound flag (check-22:1457). So the else after a test for failure and the then-branch of an
#     `if !` whose body calls ok both pass, with no special case. Any name, B_ or not; a name
#     declared `local` is keyed to its function. REFUSED: =1 in a body calling bad, or both ok and
#     bad, or neither -- including `if <arm>; then B_x=1; fi` and `<test> && B_x=1`, whose content
#     cannot say which side passed (`if [ "$rc" -ne 0 ]; then B_x=1; fi` reads the same); =1
#     outside any body, including after || and `t && ok "x"; X=1`; X never set to 1; X ever
#     assigned anything but 0 or 1. Unbalanced if/case/group nesting is itself a refusal.
#   "$(( a && b ))" whose every operand is ${X:-0} or $X over flags as above, or a helper
#     positional bound as below.
#   "$([ "$V" <op> <rhs> ] && ... && echo 1)", optionally ending `|| echo 0`, op one of = != -eq
#     -ne, where every left operand is a quoted variable, assigned outside a heredoc, and EVERY
#     assignment to it is a command substitution or a $? capture, and at least one is not a
#     CONSTANT command substitution: $(( )) over digits and operators only, or $( ) whose body,
#     quoted literals blanked, holds no $, backtick, < or parenthesis and runs only printf, echo,
#     true, false or : (V="$(printf 0)", V="$(echo 'PASS' all)"). REFUSED: a literal left operand
#     ([ 1 = 1 ]), a variable compared with itself, a variable never assigned or ever assigned a
#     bare literal, a variable whose every assignment is a constant command substitution.
#   "$n" / "${n:-0}" -- a positional of the enclosing function, or a `local v="$n"` ALIAS of one
#     passed as "$v", where EVERY caller of that function at command position passes one of the
#     forms above as word n (continuation lines joined). A caller passing its own positional is
#     resolved through its callers the same way, at most 3 functions deep. REFUSED: no caller, a
#     cycle, deeper than 3, an alias assigned again in its function, any caller passing anything
#     unbound -- unresolvable is never accepted.
# Everything else is REFUSED: a constant, an unquoted argument, any other variable or form.
#
# M5 RESIDUAL, stated: the same-run test form proves the value was COMPUTED, not that the
# command substitution ran the UNMUTATED subject. That half stays the fixture's to bind;
# check-22's NB BINDING arm is the stricter per-fixture form of it. M5 sees only `NAME=`
# assignment tokens: `${X:=1}`, `printf -v X`, `read X`, `eval "X=1"`, `(( X = 1 ))` and
# `declare X=1` after a word are not seen, so a flag set that way reads as never set (refused)
# or, beside a passing =1, as bound. No fixture on origin/main uses those forms on a flag.
# The drift refusal rejects any non-comment line on which a helper name followed by a quote,
# `$` or a digit sits inside string text -- a reworded bad/ok message must not spell one. The
# one narrowing: a line that starts in code and spells the call only inside a single-quoted span
# it opens and closes itself is seed data (printf ' mutant_killed 1 ...' > f), never code.
# Heredoc bodies: any opener on a non-comment line, a tag carrying digits, <<- with tab
# stripping, and a redirect after the tag (<<'PY' 2>/dev/null).
#
# M5 NARROWING BY SHAPE: a call inside an assignment's command substitution
# (o="$(mutant_killed 1 ...)") prints nothing to the fixture's output and cannot score a kill,
# so it is a probe of the helper and is counted as captured, not scored. That shape is also the
# BL-849 hazard; refusing it where it does score is BL-849's job, not M5's.
#
# M5 FALSE-POSITIVE SET: ZERO grammar misses; the refused set is ENUMERATED, every row a flag
# form outside the grammar above, none in the four origin/main precedents (check-22-spawn-ledger,
# story-evidence-scaffold, handoff-resume-guard, gate-series-rung: 0 refused). Measured on b245-fx2
# 4b593af56 and again on 1a408b46e, identical (257 run.sh, 79 calling a helper by
# `grep -lE 'need_base|mutant_killed'`): 483 scored, 4 captured, 208 refused in 51 fixtures. The
# current figure is the row count of scripts/mutant-sites-allowlist.txt, derived by --derive-m5:
# 252 rows when this paragraph was written, 60 on 370d9df80. It left 208 for 206 because the two `$(mx_flag "$t")` sites
# (layer-conforms-to, self-update-join-gate) were BOUND in the fixtures, as one literal
# mutant_killed per arm inside a `case "$t"`; M5 was not taught to accept them. It rose to 253
# on the b245-fx2 base: 47 sites written in ten fx2 fixtures after M5 was ruled, listed on the
# lead's ruling and filed to BL-828 as owed by those fixtures, never accepted by M5. One of the
# 47 was not a site but M5 failing to parse self-update-gate (a case pattern spelled `else)`),
# fixed in M5 and probed by a-casekw/r-casekw/r-stray, so 252. By
# shape, at 208: 141 a flag set in a SILENT body or by a bare `<test> && X=1` (if <arm>; then B_x=1; fi,
# [ c ] && B_x=1 beside a separate ok/bad) -- outside the contract's "## The flag", which sets it
# as `ok ...; B_x=1` in the passing branch; 25 a flag set by eval/printf -v/indirection or
# returned by a function ($(bflag A2), $(mx_flag t), ${!bv}), so never seen set; 12 a default-pass
# flag set =1 then cleared on failure, or a top-level =1 after an exit guard; 7 a flag copied from
# another variable or expression (B_D07=$KC_OK, M2_FLAG=$((..))); 6 =1 in a body calling both ok
# and bad (readset-skip's `[ c ] && B_x=1` before its own `[ c ] && ok || bad`); 1 in a body
# calling bad; 5 a test form over a literal copy or a non-variable left side; 1 a constant
# (dist-clone). None is a positional, alias, nesting or heredoc miss.
# WIDENING MEASURED AND NOT TAKEN: accepting a silent then-branch of a non-negated if, and any
# non-negated `<test> && X=1`, reaches 56 refused -- and accepts `if [ "$rc" -ne 0 ]; then
# B_x=1; fi` and `grep -q FAIL o && B_x=1`, which are the defect M5 exists to refuse; r-silent
# carries both as offenders. No precedent needs it.
# How it reached that size: the position rule of the first M5 (fb18675a4) refused 120 here,
# including 8 correct sites in the pilot fixtures -- an else after a test for failure
# (apply-drift-refile:1258,1333, layer-conforms-to:382), an `if !` then-branch
# (self-update-join-gate:347), a helper taking the flag as a parameter (apply-drift-refile:217,
# escalation-delivery:252, file-mtime:172, invariant-index:215). The content rule alone (a
# passing body calls ok and not bad) refused 218; the grammar misses it carried were then fixed
# in M5, never in a fixture: heredoc openers with a digit in the tag or a redirect after it
# (upstream-routing:742, layer-adjudication-tier:550) read a body as code and unbalanced the
# nesting; function-local names were keyed globally and continuation-line callers read one
# line; single-quoted seed data tripped the drift rule (fixture-invocation-budget:185);
# positionals stopped at one level (invariant-index kill_check -> mx_cell,
# layer-adjudication-tier); `|| echo 0` on the test form and a positional conjunction operand
# (remediator-shard-join:1074) were unparsed. 218 -> 208, each step a removed row checked by
# hand. Measured by `bash scripts/validate-mutant-kills.sh` (its FAIL M5 rows); control: the
# precedents score 0 refused, and fb18675a4 120, on the same tree.
# The constant-substitution refusal narrows NOTHING on the tree: --derive-m5 byte-identical
# before and after on 370d9df80 (60 rows). Its population, dumped from testv itself in a copy:
# 120 judgements of a test variable in 36 fixtures. Four carry a constant assignment, all
# story-provenance RC_c/RC_d/RC_e/RC_r = "$(printf 1)" (:532), each later set by a $? capture
# (:552/:560/:571/:592), so a skipped arm leaves the failing 1 -- accepted, correctly. The six
# `$(printf '%s' ...)` bodies (fixture-git-env-seam _sd, SV_U; gate-resume _m4real_off;
# shell-portability x26_v; transient-ignore-block live_rc; wait-stale-deliverable mx0) expand a
# variable, so none is constant. Accepting a mixed variable is deliberate: refusing any constant
# assignment would refuse story-provenance's four (mutant m2 below). RESIDUAL it acquits: a
# constant default beside a $? capture that runs only under a condition reaches the test as the
# constant when the condition is false; story-provenance is safe because its default 1 is the
# FAILING value for -eq 0, which this rule does not check.
# The quote tracker honours $'...': without it story-evidence-scaffold/run.sh:744 was lost to a
# string opened at :661; the drift refusal above exists because that zero was false.
#
# THE GRAMMAR. Case-sensitive `KILLED|killed`, on a line not opening with `#`, after a DENY
# mask. The deny list enumerates non-kill senses of the word; it is never an allow-list of kill
# markers (most real kills carry no fixed marker: `$1: KILLED by FW[$3]`, `killed exactly its
# cells`). A lowercase `killed` IMMEDIATELY followed (blanks only) by one of these words, ending
# at a boundary that is not a letter, digit, `_` or `-` (so `killed worker-cap`, a cell name,
# stays a kill), names a killed process or run and is masked to `XXXXXX`, same length:
#   run / runs, group / groups, process group(s), pid(s), and `by|with|on SIG<NAME>`.
# That is the contract's enumerated set (a killed run, a process group, a pid, SIGKILL-style
# signal wording) and nothing more: no corpus line or BL entry needs worker, child, process,
# subshell or a bare `signal`, so none is a deny sense. The mask is NOT applied when the text
# BEFORE that `killed` names a mutant: a `mut` word opening at a non-letter (mutant, MUTANT,
# mutation, Mutant) or a mutant id `[mM]<digit>` opening at a non-alphanumeric. The id grammar
# is read off the corpus: every id before a lowercase `killed` on a code line is `m<digits>` or
# `M<digits>` after a blank, `"`, `/` or `-` (derivation-capture `ok "M1 killed: ..."` carries no
# mut word at all). So `mutant m4 killed runs past the cap` and `m8 killed pid arm P1` refuse.
# The BL-903 instance names neither before its `killed` (`ok "INTERRUPTED GROUP: each `), so it
# stays quiet; `commuted` and `dim3` are near-misses that name no mutant.
# The BL-903 instance (`ok "INTERRUPTED GROUP: each killed run's recorded process group ..."`,
# readset-skip/run.sh:5339 at 1a973b957) is the `killed run` sense. Bound to the NEXT word, so a
# deny word later on the line acquits nothing (`mutant g killed by C1: the group arm` refuses; a
# greedy `killed .* group` would acquit it), and only the matched word is masked, so a real kill
# on the same line still refuses. `KILLED` is never masked. A line is
# ROUTED when it calls `mutant_killed` (preceded by start-of-line, blank, `;`, `&`, `|` or `(`,
# and outside a double-quoted string by quote parity) and no KILLED/killed token sits BEFORE
# that call -- the helper name itself contains `killed`, so it is masked first;
# `ok "x killed"; mutant_killed ...` and `ok "mutant_killed ...: x killed"` are unrouted.
# Accepted imprecision: an escaped `\"` or a `'..."...'` before a real call misreads parity.
# The tightened grammar's --derive output was byte-identical to the looser one's, so the
# imprecision is not live.
# Heredoc bodies are NOT exempt: a seed that spells a kill line is reworded instead, which is
# stricter and needs no heredoc parser.
#
# FALSE-POSITIVE SET AND HOW IT REACHED ITS SIZE, measured on origin/main 7c8a88fd7 (262
# run.sh). Case-insensitive `killed` on non-comment lines: 882 lines in 127 fixtures.
# Case-sensitive KILLED|killed: 875 lines in the same 127 -- the 7 dropped are `SIGKILLed`
# (consumer-suite-pool 5, readset-skip 1, readset-stage1-verdict 1), none a mutant verdict.
# Comment lines excluded: 234. Of the 875, 360 carry no `mut`/`MUT` word at all (`$lab: killed
# by $w`, `killed exactly its cells`, `m3 also killed C1`): many are bad() lines or entanglement
# checks, not kills. They are NOT narrowed by a description of what a kill looks like: that
# would be a second grammar of kills, which this arm refuses to guess, and a kill it failed to
# describe would pass. So the false-positive set was the whole allowlist: 127 fixtures, derived
# by `--derive`, never typed; check-22-spawn-ledger left it in the change that shipped this arm,
# so the committed list was 126.
# The one narrowing taken is the DENY mask above, keyed on what is NOT a kill (BL-903: a prose
# `ok` text about a killed run red the pre-suite on 1a973b957). Measured on origin/main
# 47102ad20 (260 run.sh, the `scan()` U-row set dumped through M1_FN before and after): 149 U
# rows in 30 fixtures and T 844 both times, the two U sets identical (comm: 0 dropped, 0 added),
# `--derive` equal to the 30-row allowlist both times. The mask fires on ZERO corpus lines (the
# shipped regex, extracted from M1_FN, run over the corpus with the extracted 5339 line appended
# to the same file list as the control: 0 corpus lines, 1 control line), so today it narrows
# nothing on the tree; the 5339 instance and one near-miss per deny sense are carried by the
# self-probe. The 7 non-comment corpus lines near a process sense (a pid, SIGKILL, a group later
# on the line) were each read: none is matched by the word-bound mask, and the one among the U
# rows (postcompact-rulebook-recovery:2713, a killed write's `.<pid>` temp) stays refused, as
# does :2652 (a killed stage write), checked separately. The mutant stop and the narrowing to the
# contract's senses re-measured on 370d9df80 (M1_FN extracted from each version, run over every
# run.sh): 69 U rows in 8 fixtures and T 835 both times, comm 0 dropped 0 added, `--derive` equal
# to the 8-row allowlist; the mask fires on 0 corpus lines and on the 5339 control line.
#
# OUT OF POPULATION, by statement: the word in fixture files other than run.sh --
# content-seal/merge-arms.sh (3 lines) and layer-reference-resolution/seed.sh (1).
# layer-reference-resolution is on the allowlist through its run.sh; content-seal's run.sh
# carries no kill line, so merge-arms.sh's three are outside this arm entirely. The same holds
# for a kill emitted in a helper a run.sh SOURCES: the scan reads run.sh only, so a sourced
# file's emission sites are outside it. The known instance is story-evidence-scaffold/world.sh
# :512, which is already routed through mutant_killed.
#
# M5 SELF-PROBE, before the corpus, 39 probe files under mktemp, scored by exact equality of
# every R row plus the T count and the rendered verdict's rc: refused -- a constant, an
# unquoted flag, =1 after ||, =1 in a body calling bad, in one calling both ok and bad, in a
# silent else, in a silent `if !` then-branch, in `if [ "$rc" -ne 0 ]; then B_w=1; fi`, after
# `grep -q FAIL o &&`, at top level, after `t && ok "x";`, a flag
# assigned from a variable, a helper positional one caller fills with a constant, an alias
# whose function one caller passes an unbound flag, an alias assigned again, a flag never set,
# [ 1 = 1 ], a test variable assigned a literal, a test variable assigned only $(printf 0),
# $(echo 1) or a multi-word quoted literal body, a constant conjunction operand, a non-flag
# variable, a bare constant beside the same constant captured, a call spelled inside a string;
# accepted -- the plain then form in both spellings, an else after a test for failure, an `if !`
# then-branch calling ok, a `local fl="$3"` alias every caller binds (one across a continuation
# line, one through a second helper), `[ "${B_p:-0}${B_r:-0}" = 11 ] && B_pr=1`, a case arm and
# an `&& { ok; B_x=1; }` group under a passing body, a conjunction, a heredoc spelling a bad
# call, a same-run test over $( ) and $? (also `|| echo 0`), a test variable from
# $(some_cmd "$x"), from a $? capture, and from $(printf 1) later set by a $? capture, a
# positional conjunction operand, W_BASE, a $'...' string, and single-quoted seed data. A mutant
# making M5 accept everything exits 2 here; so do three of the constant refusal, each in a copy
# of scripts/: the refusal removed (m1), any constant assignment refusing (m2), the classifier
# always answering non-constant (m3).
#
# SELF-PROBE FIRST, both directions, under mktemp, scored by exact equality of the verdict
# rows: an unlisted unrouted kill, a kill BEFORE a routed call and a helper name inside a
# string are refused; a routed call, a
# comment KILLED and a SIGKILLed line are accepted. DENY mask (BL-903), 24 probe files in all:
# the 5339 instance text byte for byte, and one near-miss per deny sense (each a lowercase
# `killed` inside an ok string on a code line, plus a `commuted` and a `dim3` line that name no
# mutant, and one naming a mutant only AFTER its `killed run`), are QUIET; refused, one per kept deny sense on a line naming a mutant before `killed`
# (`mutant m4 killed runs ...`, `m4 killed run arm`, `MUTANT g killed group ...`, `M6 killed
# process group ...`, `m8 killed pid arm P1`, `mutant m9 killed by SIGTERM ...`) and the dropped
# senses (`m2 killed by signal`, `m5 killed child`, `mutant m7 killed worker`); refused, one per distinct kill shape
# among the 149 corpus U rows -- `ok "mutant m3 killed by C1"`, `ok "MUTANT y KILLED: ..."`,
# `ok "m3 (desc): killed by C2"`, a KILLED-only no-`mut` line (`$1: KILLED by FW[$3]`), a
# deny word LATER on a kill line (`mutant g killed by C1: the group arm`), and a deny sense and
# a real kill on one line, and a hyphenated kill target opening with a deny word
# (`m3 also killed worker-cap`). Measured mutants, each in a copy of the whole scripts/ dir, all exit 2
# with "self-probe failed": the deny mask removed (old grammar; the near-misses refuse), M1
# accepting every line, a regression dropping every ok-string line, and a greedy
# `killed.*group` deny (o5 goes quiet), and a boundary admitting `-` (o7 goes quiet).
# The probe adds no fork: its dirs ride the one mkdir, its seeds are printf builtins, and the
# mask runs inside the existing awk (fork-profile --target this script: 105 before and after).
# A listed fixture with no offender, a listed
# fixture with no directory, and a duplicate row are each refused. M4 is probed against
# scratch git repos whose refs/remotes/origin/main carries a base list: an added row and a
# count-keeping swap are refused (rc 1, the rendered FAIL text compared whole), a shrink and an
# identical list pass, an origin/main without the file and a repo with no origin/main each
# SKIP with their reason (rc 0). Each assertion is the exact verdict text plus rc, so a mutant
# that makes M4 always SKIP fails the probe rather than passing the tree.
#
# COST. A constant number of forks: ONE awk reads the corpus for M1 and M5 together (m5scan
# with an M1 output file), two sorts, one comm-style awk join; the probe trees add one awk each.
# Inside that awk the quote pass copies runs of plain characters whole and the token pass skips
# a line carrying none of its tokens, both proven byte-neutral on the corpus by cmp. Nothing forks per fixture or per line. It is a
# standalone step in .githooks/pre-push, not an arm inside validate-enforcement-map.sh, which
# the suite pole invokes.
set -uo pipefail

MODE=check
case "${1:-}" in
  "") ;;
  --derive) MODE=derive ;;
  --derive-m5) MODE=derive5 ;;
  *) echo "usage: validate-mutant-kills.sh [--derive|--derive-m5]" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-mutant-kills: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2
  exit 2
fi
ALLOW_REL="scripts/mutant-kills-allowlist.txt"
M5_ALLOW_REL="scripts/mutant-sites-allowlist.txt"

# scan <root> -> per scanned file "F<TAB>fx", per unrouted line "U<TAB>fx<TAB>line<TAB>text",
# and "T<TAB>n" = lines carrying the word or a mutant_killed call (the positive control).
# M1_FN is the M1 grammar, one awk function over the current line, held once and read by both
# scan() and the corpus read in m5scan, so the two cannot drift.
M1_FN='
    function m1line(   s, pm, q, m, pk) {
      if ($0 ~ /^[[:space:]]*#/) return
      s = $0
      pm = 0
      if (match(s, /(^|[[:space:];&|(])mutant_killed[[:space:]]/)) {
        pm = RSTART; if (substr(s, pm, 1) != "m") pm++
        # A call is code, not text: an odd count of double quotes before it puts the match
        # INSIDE a string (ok "mutant_killed refused: MUTANT x killed"), which routes nothing.
        q = substr(s, 1, pm - 1); gsub(/[^"]/, "", q)
        if (length(q) % 2 == 1) pm = 0
      }
      m = s; gsub(/mutant_killed/, "mutant_XXXXXX", m)
      # DENY senses: a lowercase `killed` that names a killed PROCESS or RUN, never a mutant, is
      # masked to the same length (pk is compared against pm, a position in s). Each sense is
      # bound to the word right after `killed`, so `mutant g killed by C1: the group arm` keeps
      # its kill; only the matched word is masked, so a real kill on the same line still refuses.
      # A line naming a MUTANT before the `killed` (a mut word, or an id m<digits>/M<digits>) is a
      # kill whatever follows, so the mask stops there: `mutant m4 killed runs past the cap` refuses.
      while (match(m, /killed[[:space:]]+(runs?|(process[[:space:]]+)?groups?|pids?|(by|with|on)[[:space:]]+SIG[A-Z]+)([^[:alnum:]_-]|$)/)) {
        if (substr(m, 1, RSTART - 1) ~ /(^|[^[:alpha:]])(mut|Mut|MUT)|(^|[^[:alnum:]])[mM][0-9]/) break
        m = substr(m, 1, RSTART - 1) "XXXXXX" substr(m, RSTART + 6)
      }
      pk = 0
      if (match(m, /KILLED|killed/)) pk = RSTART
      if (pm > 0 || pk > 0) t1++
      if (pk > 0 && (pm == 0 || pk < pm)) m1p("U\t" fx "\t" FNR "\t" substr(s, 1, 160))
    }
    # m1p(x) -> an M1 row, to stdout or, inside m5scan, to the file M1O names
    function m1p(x) { if (M1O == "") print x; else print x > M1O }
'
scan() {
  local r="$1" f n=0
  set -- "$r"/core/fixtures/*/run.sh
  [ -f "$1" ] || { printf 'T\t0\n'; return 0; }
  awk "$M1_FN"'
    FNR == 1 { fx = FILENAME; sub(/\/run\.sh$/, "", fx); sub(/.*\//, "", fx); print "F\t" fx }
    { m1line() }
    END { print "T\t" (t1 + 0) }
  ' "$@"
}

# judge <scan-output-file> <allowlist-file> -> sorted verdict rows:
#   "REFUSE<TAB>fx<TAB>line: text" (M1), "STALE<TAB>fx" (M2), "DUP<TAB>fx" (M3)
judge() {
  awk -F '\t' '
    FNR == NR {
      if ($1 == "U") { u[$2]++; if (!($2 in first)) first[$2] = $3 ": " $4 }
      next
    }
    /^[[:space:]]*(#|$)/ { next }
    {
      x = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x)
      if (x in listed) print "DUP\t" x
      listed[x] = 1
    }
    END {
      for (x in u) if (!(x in listed)) print "REFUSE\t" x "\t" first[x] " (" u[x] " unrouted line(s))"
      for (x in listed) if (!(x in u)) print "STALE\t" x
    }
  ' "$1" "$2" | LC_ALL=C sort
}

# m4 <repo-dir> <current-allowlist-file> <scratch-file> -> prints the M4 verdict text; rc 0 on
# OK or SKIP, 1 on an added row. The base is read from origin/main of <repo-dir>, braced.
# With <rel> and <arm> it judges another down-only list the same way (M7 over $M5_ALLOW_REL).
m4() {
  local repo="$1" cur="$2" base="$3" rel="${4:-$ALLOW_REL}" arm="${5:-M4}" sha added
  sha="$(git -C "$repo" rev-parse -q --verify 'origin/main^{commit}' 2>/dev/null)" || sha=""
  if [ -z "$sha" ]; then
    echo "SKIP $arm: origin/main does not resolve here, so there is no base allowlist to compare against"
    return 0
  fi
  if ! git -C "$repo" cat-file -e "${sha}:${rel}" 2>/dev/null; then
    echo "SKIP $arm: origin/main carries no $rel -- this is the release that first ships it"
    return 0
  fi
  if ! git -C "$repo" show "${sha}:${rel}" > "$base" 2>/dev/null; then
    echo "FAIL $arm: origin/main carries $rel but it could not be read"
    return 1
  fi
  added="$(awk '
    /^[[:space:]]*(#|$)/ { next }
    { x = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x) }
    FNR == NR { b[x] = 1; next }
    !(x in b) && !(x in seen) { seen[x] = 1; print x }
  ' "$base" "$cur" | LC_ALL=C sort)"
  if [ -n "$added" ] && [ "$arm" = M4 ]; then
    echo "FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
    printf '%s\n' "$added" | sed 's/^/    /'
    echo "  Remedy: do not list the fixture. Route its kills through mutant_killed <flag> <name> \"<message>\""
    echo "  (core/fixtures/lib/mutant.sh) and delete the row."
    return 1
  fi
  if [ -n "$added" ]; then
    echo "FAIL $arm: allowlist row(s) not on $rel at origin/main -- the list is DOWN-ONLY:"
    printf '%s\n' "$added" | sed 's/^/    /'
    echo "  Remedy: do not list the site. Bind its flag (see FAIL M5's remedy) and delete the row."
    return 1
  fi
  echo "OK $arm: no allowlist row added against origin/main"
  return 0
}

# m5judge <m5scan-output-file> <site-allowlist-file> -> the R rows whose key is NOT listed (M5,
# a new site), "STALE<TAB>key" for a row no refused site carries (M6: the site is bound now, or
# gone), "DUP<TAB>key" for a row listed twice (M6). A key is fields 5-8 of an R row.
m5judge() {
  awk -F '\t' '
    FNR == NR {
      if ($1 == "R") { k = $5 "\t" $6 "\t" $7 "\t" $8; r[++nr] = $1 "\t" $2 "\t" $3 "\t" $4; rk[nr] = k; have[k] = 1 }
      next
    }
    /^[[:space:]]*(#|$)/ { next }
    { if ($0 in listed) print "DUP\t" $0; listed[$0] = 1 }
    END {
      for (i = 1; i <= nr; i++) if (!(rk[i] in listed)) print r[i]
      for (x in listed) if (!(x in have)) print "STALE\t" x
    }
  ' "$1" "$2" | LC_ALL=C sort
}

# m5scan <root> [1] -> per scanned file "F<TAB>fx", per refused call site "R<TAB>fx<TAB>line<TAB>why",
# and "T<TAB>scored-sites<TAB>captured-sites" (the positive control). One awk over every run.sh.
# With 1, it also prints "K<TAB>word" per bare word the token pass reacts to and
# "P<TAB>fx<TAB>line" per line the token-pass prefilter skipped, for the prefilter self-probe.
# With a third argument <file>, the same read also writes scan()'s M1 output to <file>, byte for
# byte what scan <root> prints, so the corpus is read once for M1 and M5.
m5scan() {
  local pf="${2:-0}" m1o="${3:-}"
  set -- "$1"/core/fixtures/*/run.sh
  if [ ! -f "$1" ]; then
    [ -n "$m1o" ] && printf 'T\t0\n' > "$m1o"
    printf 'T\t0\t0\n'; return 0
  fi
  awk -v pf="$pf" -v M1O="$m1o" "$M1_FN"'
    BEGIN {
      # the token pass: TOKRE is every token it reads; TOKP the operator, group and assignment
      # tokens, KW the only bare words it reacts to. The prefilter is built from these three.
      TOKP = "\\|\\||&&|;;&?|;&|[{}()]|[A-Za-z_][A-Za-z0-9_]*="
      TOKRE = TOKP "|[A-Za-z_][A-Za-z0-9_]*"
      nk = split("local declare typeset if case then else elif fi esac ok bad fail note_fail", KWA, " ")
      KWRE = ""; for (i = 1; i <= nk; i++) { KW[KWA[i]] = 1; KWRE = KWRE (i > 1 ? "|" : "") KWA[i] }
      # a word token starts after any non-letter (a digit too: 9if yields the token if)
      KWRE = "(^|[^A-Za-z_])(" KWRE ")([^A-Za-z0-9_]|$)"
      if (pf) for (i = 1; i <= nk; i++) print "K\t" KWA[i]
    }
    BEGIN { sq = sprintf("%c", 39); SPECIAL = "[\\\\\"" sq "$()#]"; hre="(^|[^<])<<-?[ \t]*[" sq "\"]?[A-Za-z_][A-Za-z0-9_]*[" sq "\"]?([ \t;|&)>]|$)" }
    FNR == 1 {
      if (NR > 1) dofile()
      fx = FILENAME; sub(/\/run\.sh$/, "", fx); sub(/.*\//, "", fx)
      n = 0; hit = 0; print "F\t" fx
      if (M1O != "") m1p("F\t" fx)
    }
    { L[++n] = $0; if (!hit && (index($0, "mutant_killed") || index($0, "need_base"))) hit = 1
      if (M1O != "") m1line() }
    END {
      if (NR > 0) dofile(); print "T\t" (sites + 0) "\t" (capt + 0)
      if (M1O != "") { m1p("T\t" (t1 + 0)); close(M1O) }
    }
    
    function pop(x) { return substr(x, 1, length(x) - 1) }

    # skey(i, tag) -> the allowlist key of a site on line i: "fx<TAB>function<TAB>occurrence<TAB>text",
    # text being the line with its blank runs collapsed and its ends trimmed, function "-" at top
    # level, occurrence counting the sites with that function and text from the top of the file.
    # No line number, so an edit elsewhere in the fixture leaves the key alone.
    function skey(i, tag,   x, f) {
      x = L[i]; gsub(/[ \t]+/, " ", x); sub(/^ /, "", x); sub(/ $/, "", x)
      f = (CUR[i] == "") ? "-" : CUR[i]
      return fx "\t" f "\t" (++OCC[f SUBSEP tag x]) "\t" tag x
    }
    
    # nextword(s, p) -> the shell word starting at or after p; WEND is set past it.
    function nextword(s, p,   len, st, ch, top, start) {
      len = length(s)
      while (p <= len && substr(s, p, 1) ~ /[ \t]/) p++
      start = p; st = ""
      while (p <= len) {
        ch = substr(s, p, 1); top = substr(st, length(st), 1)
        if (top == "S") { if (ch == sq) st = pop(st); p++; continue }
        if (top == "A") { if (ch == "\\") p++; else if (ch == sq) st = pop(st); p++; continue }
        if (ch == "\\") { p += 2; continue }
        if (top == "D") {
          if (ch == "\"") st = pop(st)
          else if (ch == "$" && substr(s, p + 1, 1) == "(") { st = st "P"; p++ }
          p++; continue
        }
        if (top == "" && ch ~ /[ \t;&|)<>]/) break
        if (ch == "\"") st = st "D"
        else if (ch == "$" && substr(s, p + 1, 1) == sq) { st = st "A"; p++ }
        else if (ch == sq) st = st "S"
        else if (ch == "$" && substr(s, p + 1, 1) == "(") { st = st "P"; p++ }
        else if (top == "P" && ch == "(") st = st "P"
        else if (top == "P" && ch == ")") st = pop(st)
        p++
      }
      WEND = p
      return substr(s, start, p - start)
    }
    
    # sk(f, nm) -> the key a name is recorded under: a name declared `local` in function f is
    # owned by that function, so a same-named local of another function cannot bind or refuse it
    function sk(f, nm) { return (f != "" && ((f SUBSEP nm) in LOC)) ? f "::" nm : nm }

    function flagv(nm,   key) {
      key = sk(AFN, nm)
      if (key in NONLIT) return "flag " nm " is assigned a non-literal value at line " NONLIT[key]
      if (!(key in N1)) return "flag " nm " is never set to 1"
      if (key in BAD1) return "flag " nm " is set to 1 " BAD1[key]
      return ""
    }
    
    # cmdpos(s, p) -> 1 when the word at p sits at COMMAND position: after start, an operator or
    # a group character, or after a reserved word that takes a command
    function cmdpos(s, p,   q, w) {
      q = p - 1
      while (q > 0 && substr(s, q, 1) ~ /[ \t]/) q--
      if (q == 0 || substr(s, q, 1) ~ /[;&|(){}!]/) return 1
      w = substr(s, 1, q); sub(/.*[^A-Za-z]/, "", w)
      return (w ~ /^(then|else|elif|if|do|while|until|time)$/ && length(w) > 0 \
              && (q - length(w) == 0 || substr(s, q - length(w), 1) ~ /[ \t;&|(){}]/))
    }
    function newseg(d) { segc++; SF[segc] = FI[d]; SK[segc] = FT[d]; SPAR[segc] = encl(d - 1); return segc }
    function encl(d) { while (d > 0 && FB[d] == 0) d--; return (d > 0) ? FB[d] : 0 }
    # segv(s) -> "" when body s is a PASSING branch, else why not. Passing: it calls ok and not
    # bad; or it calls neither and a sibling branch of the same if calls bad and not ok (the
    # failing side reports, so this side is the pass); a case arm calling neither inherits the
    # body that encloses the case.
    function segv(s) {
      if (s == 0) return "outside any passing branch"
      if (SOK[s] && SBAD[s]) return "in a branch that calls both ok and bad"
      if (SBAD[s]) return "in a branch that calls bad"
      if (SOK[s]) return ""
      if (SK[s] == "I" && (SF[s] in FBO)) return ""
      if (SK[s] == "C") return segv(SPAR[s])
      return "in a branch that calls neither ok nor bad"
    }
    # testok(x) -> 1 when x is `[ "<flag refs>" = 11.. ]`, one 1 per ref, every ref a bound flag
    function testok(x,   r, nm, c) {
      if (!match(x, /^[ \t]*\[ "(\$\{[A-Za-z_][A-Za-z0-9_]*(:-0)?\})+" = 1+ \][ \t]*$/)) return 0
      r = x; sub(/^[ \t]*\[ "/, "", r); sub(/" = 1+ \][ \t]*$/, "", r)
      c = x; sub(/^.*" = /, "", c); sub(/ \].*$/, "", c)
      if (gsub(/\$\{/, "&", r) != length(c)) return 0
      while (match(r, /\$\{[A-Za-z_][A-Za-z0-9_]*/)) {
        nm = substr(r, RSTART + 2, RLENGTH - 2); r = substr(r, RSTART + RLENGTH)
        if (flagv(nm) != "") return 0
      }
      return 1
    }

    # posv(fn, "POS<n>", d) -> "" when EVERY caller of fn at command position passes a bound flag
    # as word n. A caller that passes its own positional (or an alias of one) is resolved through
    # ITS callers the same way, at most 3 functions deep; deeper, a cycle, or no caller at all is
    # refused -- unresolvable is never accepted
    function posv(fn, ps, d,   pn, nc, j, t, off, pos, q, s, a, rr, cw, why, saf) {
      pn = substr(ps, 4) + 0
      if (fn == "") return "positional $" pn " outside any function"
      # the verdict depends on fn and n alone, so it is computed once per file
      if (d == 1 && ((fn SUBSEP pn) in PMEMO)) return PMEMO[fn SUBSEP pn]
      if (d > 3) return "positional $" pn " of " fn ": passed through more than 3 functions"
      if ((fn SUBSEP pn) in PVIS) return "positional $" pn " of " fn ": the callers pass it around a cycle"
      PVIS[fn SUBSEP pn] = 1; saf = AFN; nc = 0; why = ""
      for (j = 1; j <= n && why == ""; j++) {
        if (j in H) continue
        t = C[j]; off = 0
        # a caller sits at COMMAND position, so the helper body naming itself as an argument
        # word is not a caller
        while (why == "" && match(t, "(^[ \t]*|[;&|({!][ \t]*|(then|do|else|elif|if)[ \t]+)" fn "([ \t]|$)")) {
          pos = off + RSTART + RLENGTH; off = pos - 1; t = substr(t, RSTART + RLENGTH)
          if (substr(C[j], pos - 1, 1) !~ /[ \t]/) pos--
          nc++; q = pos; s = joined(j)
          for (cw = 1; cw <= pn; cw++) { a = nextword(s, q); q = WEND }
          AFN = CUR[j]; rr = argv_(a)
          if (rr ~ /^POS/) rr = posv(CUR[j], rr, d + 1)
          AFN = saf
          if (rr != "") why = "positional $" pn " of " fn ": the caller at line " j " passes " (a == "" ? "nothing" : a) " -- " rr
        }
      }
      delete PVIS[fn SUBSEP pn]
      if (why == "" && nc == 0) why = "positional $" pn " of " fn ", which has no caller"
      if (d == 1) PMEMO[fn SUBSEP pn] = why
      return why
    }

    # aliasv(nm) -> a `local nm="$N"` of the function AFN is positional N; any other name is a flag
    function aliasv(nm,   k) {
      k = AFN SUBSEP nm
      if (AFN != "" && (k in ALIAS)) {
        if (k in ALIASX) return "alias " nm " of $" ALIAS[k] " in " AFN " is assigned again at line " ALIASX[k]
        return "POS" ALIAS[k]
      }
      return flagv(nm)
    }

    # joined(j) -> line j with its continuation lines appended -- a trailing backslash, or a
    # quoted word left open at the end of the line -- so a call spread over several lines yields
    # all of its words (positions on line j are unchanged)
    function joined(j,   s) {
      s = L[j]
      while (j < n && !((j + 1) in H) && (OPEN[j] || s ~ /\\$/)) {
        if (OPEN[j]) s = s "\n" L[++j]
        else s = substr(s, 1, length(s) - 1) " " L[++j]
      }
      return s
    }

    # cconst(w) -> 1 when assignment value word w is a command substitution that computes a
    # constant: $(( )) over digits and operators only, or $( ) whose body, quoted literals blanked,
    # holds no $, backtick, < or parenthesis and whose every command is printf, echo, true, false
    # or : -- nothing it runs reads state. Anything else, a $? capture included, is not constant.
    function cconst(w,   b, k, m, i, c) {
      if (w ~ /^".*"$/) w = substr(w, 2, length(w) - 2)
      if (w ~ /^\$\(\(.*\)\)$/) return (substr(w, 4, length(w) - 5) ~ /^[0-9 \t+*\/%<>=!&|-]*$/)
      if (w !~ /^\$\(.*\)$/) return 0
      b = substr(w, 3, length(w) - 3)
      if (b ~ /[$`]/) return 0
      gsub(sq "[^" sq "]*" sq, "X", b); gsub(/"[^"]*"/, "X", b)
      if (b ~ /[<()"]/ || index(b, sq)) return 0
      m = split(b, k, /[;&|]+/)
      for (i = 1; i <= m; i++) {
        c = k[i]; sub(/^[ \t]+/, "", c); sub(/[ \t].*$/, "", c)
        if (c != "" && c !~ /^(printf|echo|true|false|:)$/) return 0
      }
      return 1
    }

    function testv(a,   e, v, r, p, rest, why) {
      e = substr(a, 4, length(a) - 4 - length(" && echo 1)"))
      while (1) {
        if (!match(e, /^\[ "\$[A-Za-z_][A-Za-z0-9_]*" (=|!=|-eq|-ne) /)) return "a same-run test whose left operand is not a quoted variable: " a
        v = substr(e, 5, RLENGTH); sub(/".*/, "", v)
        rest = substr(e, RLENGTH + 1)
        p = index(rest, " ]"); if (p < 2) return "a same-run test that does not parse: " a
        r = substr(rest, 1, p - 1)
        if (r == "\"$" v "\"") return "a same-run test comparing " v " with itself: " a
        if (!(sk(AFN, v) in NASSIGN)) return "test variable " v " is never assigned"
        if (sk(AFN, v) in NLITV) return "test variable " v " is assigned a literal at line " NLITV[sk(AFN, v)] ", not a command substitution or a $? capture"
        if ((sk(AFN, v) in CCS) && !(sk(AFN, v) in NCC)) return "test variable " v " is only ever assigned a constant command substitution (line " CCS[sk(AFN, v)] "), so its value does not depend on the run"
        rest = substr(rest, p + 2)
        if (rest == "") return ""
        if (substr(rest, 1, 4) != " && ") return "a same-run test that does not parse: " a
        e = substr(rest, 5)
      }
    }
    
    # argv_(a) -> "" when bound, "POS<n>" for a positional, else the refusal reason.
    function argv_(a,   nm, e, k, m, i, op, why) {
      if (a == "") return "no flag argument"
      if (a ~ /^"?[0-9]+"?$/ || substr(a, 1, 1) == sq) return "constant argument " a
      if (substr(a, 1, 1) != "\"") return "unquoted argument " a
      if (a ~ /^"\$[1-9]"$/) return "POS" substr(a, 3, 1)
      if (a ~ /^"\$\{[1-9]:-0\}"$/) return "POS" substr(a, 4, 1)
      if (a ~ /^"\$\{[A-Za-z_][A-Za-z0-9_]*:-0\}"$/) { nm = substr(a, 4); sub(/:-0\}"$/, "", nm); return aliasv(nm) }
      if (a ~ /^"\$[A-Za-z_][A-Za-z0-9_]*"$/) { nm = substr(a, 3, length(a) - 3); return aliasv(nm) }
      if (a ~ /^"\$\(\(.*\)\)"$/) {
        e = substr(a, 5, length(a) - 7)
        m = split(e, k, /&&/)
        for (i = 1; i <= m; i++) {
          op = k[i]; gsub(/^[ \t]+|[ \t]+$/, "", op)
          if (op ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*:-0\}$/) { nm = substr(op, 3); sub(/:-0\}$/, "", nm) }
          else if (op ~ /^\$[A-Za-z_][A-Za-z0-9_]*$/) nm = substr(op, 2)
          else if (op ~ /^\$([1-9]|\{[1-9](:-0)?\})$/) {
            # a helper positional as an operand binds the way a positional argument does
            why = posv(AFN, "POS" substr(op, match(op, /[1-9]/), 1), 1); if (why != "") return why
            continue
          }
          else return "a conjunction operand that is not a flag: " a
          why = flagv(nm); if (why != "") return why
        }
        return ""
      }
      # `|| echo 0` after the echo 1 changes an empty refusal into 0 and nothing else
      if (a ~ /^"\$\(\[ .* && echo 1 \|\| echo 0\)"$/) { sub(/ \|\| echo 0\)"$/, ")\"", a); return testv(a) }
      if (a ~ /^"\$\(\[ .* && echo 1\)"$/) return testv(a)
      return "unrecognised argument " a
    }
    
    function dofile(   i, j, s, len, ch, top, st, incode, atop, w, seg, c1, m1, tag, \
                       fst, fin, nmf, ind, t, off, tk, pos, pre, nm, val, fr, orf, andf, badf, \
                       ns, k, a, why, pn, fn, nc, cw, q, rr) {
      if (!hit) return
      split("", H); split("", C); split("", M); split("", CUR)
      split("", N1); split("", NONLIT); split("", BAD1); split("", NASSIGN); split("", NLITV)
      split("", CCS); split("", NCC)
      split("", SL); split("", SP); split("", SN)
      split("", ALIAS); split("", ALIASX); split("", SOK); split("", SBAD); split("", SF); split("", SK)
      split("", SPAR); split("", FBO); split("", AN); split("", AL); split("", AS); split("", AT)
      split("", FT); split("", FI); split("", FB); split("", CM)
      split("", LOC); split("", OPEN); split("", SST); split("", PMEMO)
      na = 0; segc = 0; dep = 0; fid = 0; MIS = 0; ns = 0
      # heredoc bodies are data, never code (marking lifted from check-22-spawn-ledger/run.sh)
      tag = ""
      for (i = 1; i <= n; i++) {
        if (tag != "") { s = L[i]; if (tdash) sub(/^\t+/, "", s); if (s == tag) tag = ""; else H[i] = 1; continue }
        # any heredoc opener on a non-comment line: a tag may carry digits, and a redirect or
        # pipe may follow it (<<'PY' 2>/dev/null) -- a narrower opener let a body be read as code
        if (L[i] !~ /^[ \t]*#/ && match(L[i], hre)) {
          tag = substr(L[i], RSTART, RLENGTH); sub(/^[^<]*<</, "", tag); tdash = (substr(tag, 1, 1) == "-")
          gsub("[-" sq "\" \t]", "", tag); sub(/[;|&)>]$/, "", tag)
        }
      }
      # C = code view (string text blanked), M = top-level view (everything nested blanked);
      # quote state carries across lines, so a multi-line string stays a string.
      st = ""
      for (i = 1; i <= n; i++) {
        if (i in H) { C[i] = ""; M[i] = ""; continue }
        s = L[i]; len = length(s); c1 = ""; m1 = ""; j = 1; SST[i] = st
        # SPOS = the positions of the SPECIAL characters, found by one split of the line, so a
        # plain run is located without copying the rest of the line at every step
        nsp = split(s, SPP, SPECIAL); q = 0
        for (k = 1; k < nsp; k++) { q += length(SPP[k]) + 1; SPOS[k] = q }
        SPOS[nsp] = len + 1; kk = 1
        while (j <= len) {
          top = substr(st, length(st), 1)
          incode = (top == "" || top == "P"); atop = (st == "")
          # a run of characters outside SPECIAL changes no quote state in any state, so it is copied in
          # one step; # is excluded because its comment break reads the character before it
          while (SPOS[kk] < j) kk++
          if (SPOS[kk] > j) {
            rl = SPOS[kk] - j; seg = substr(s, j, rl); j += rl
            c1 = c1 (incode ? seg : sprintf("%" rl "s", ""))
            m1 = m1 (atop ? seg : sprintf("%" rl "s", ""))
            continue
          }
          ch = substr(s, j, 1); w = 1
          if (top == "S") { if (ch == sq) st = pop(st) }
          else if (top == "A") { if (ch == "\\") w = 2; else if (ch == sq) st = pop(st) }
          else if (ch == "\\") w = 2
          else if (top == "D") {
            if (ch == "\"") st = pop(st)
            else if (ch == "$" && substr(s, j + 1, 1) == "(") { st = st "P"; w = 2 }
          } else {
            if (ch == "#" && (j == 1 || substr(s, j - 1, 1) ~ /[ \t;&|(]/)) break
            if (ch == "\"") st = st "D"
            else if (ch == "$" && substr(s, j + 1, 1) == sq) { st = st "A"; w = 2 }
            else if (ch == sq) st = st "S"
            else if (ch == "$" && substr(s, j + 1, 1) == "(") { st = st "P"; w = 2 }
            else if (top == "P" && ch == "(") st = st "P"
            else if (top == "P" && ch == ")") st = pop(st)
          }
          seg = substr(s, j, w); j += w
          c1 = c1 (incode ? seg : substr("  ", 1, length(seg)))
          m1 = m1 (atop ? seg : substr("  ", 1, length(seg)))
        }
        C[i] = c1; M[i] = m1; OPEN[i] = (st != "")
      }
      # functions, if-frames, assignments, call sites
      fst = 0; fr = ""
      for (i = 1; i <= n; i++) {
        if (i in H) continue
        t = M[i]
        fin = ""
        if (match(t, /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*\(\)/)) {
          nmf = substr(t, 1, RLENGTH); sub(/[ \t]*\(\)$/, "", nmf); sub(/^[ \t]*(function[ \t]+)?/, "", nmf)
          ind = t; sub(/[^ \t].*$/, "", ind)
          rr = t; sub(/[ \t]+$/, "", rr)
          if (rr ~ /\}$/) fin = nmf
          else { fst++; FS_N[fst] = nmf; FS_I[fst] = ind }
        }
        CUR[i] = (fin != "") ? fin : (fst > 0 ? FS_N[fst] : "")
        if (fin == "" && fst > 0 && t ~ ("^" FS_I[fst] "\\}")) fst--
        # ${...} expansions are blanked first, so their braces are never read as a group
        while (match(t, /\$\{[^}]*\}/)) t = substr(t, 1, RSTART - 1) sprintf("%" RLENGTH "s", "") substr(t, RSTART + RLENGTH)
        mt = t; off = 0; prevtk = ""; andp = 0; inloc = 0
        # prefilter: a line carrying no TOKP token and no KW word changes nothing the loop
        # below keeps across lines, so the loop is skipped; both are the sources the loop itself reads
        if (!match(t, TOKP) && !match(t, KWRE)) { if (pf) print "P\t" fx "\t" i; t = "" }
        while (match(t, TOKRE)) {
          tk = substr(t, RSTART, RLENGTH); pos = off + RSTART
          pre = (pos > 1) ? substr(mt, pos - 1, 1) : ""
          nx = substr(mt, pos + RLENGTH, 1)
          off += RSTART + RLENGTH - 1; t = substr(t, RSTART + RLENGTH)
          ptk = prevtk; prevtk = tk
          if (tk == "&&") { andp = pos; inloc = 0; continue }
          if (tk == "||") { inloc = 0; continue }
          if (pre == "$" || pre == "-") continue
          # a bare word outside KW reaches no branch below: KW is the one list of words this
          # loop reacts to, and the prefilter reads the same list, so a word added to a branch
          # without adding it to KW never fires -- it cannot fire here and be skipped there
          if (!inloc && !(tk in KW) && tk ~ /^[A-Za-z_][A-Za-z0-9_]*$/) continue
          # `local a b=1` makes every named word local to the enclosing function
          if ((tk == "local" || tk == "declare" || tk == "typeset") && CUR[i] != "" && cmdpos(mt, pos)) { inloc = 1; continue }
          if (inloc && tk ~ /^[A-Za-z_][A-Za-z0-9_]*=?$/ && (pre == "" || pre ~ /[ \t]/)) { x = tk; sub(/=$/, "", x); LOC[CUR[i] SUBSEP x] = 1 }
          if (tk ~ /=$/) {
            if (pre != "" && pre !~ /[ \t;&|({]/) continue
            nm = substr(tk, 1, length(tk) - 1); rk = sk(CUR[i], nm); NASSIGN[rk]++
            val = substr(L[i], pos + length(tk))
            # v="$N" inside a function aliases positional N; the caller rule then applies to v
            if (CUR[i] != "" && match(val, /^"?\$(\{[1-9](:-0)?\}|[1-9]("|[^0-9A-Za-z_]|$))/)) {
              ALIAS[CUR[i] SUBSEP nm] = substr(val, match(val, /[1-9]/), 1); continue
            }
            if (CUR[i] != "" && ((CUR[i] SUBSEP nm) in ALIAS) && !((CUR[i] SUBSEP nm) in ALIASX)) ALIASX[CUR[i] SUBSEP nm] = i
            if (val !~ /^"?\$[(?]/ && !(rk in NLITV)) NLITV[rk] = i
            # a constant command substitution ($(printf 0)) is a literal laundered through $( );
            # any other assignment, $? included, marks the name as able to carry a run-time value
            if (cconst(nextword(L[i], pos + length(tk)))) { if (!(rk in CCS)) CCS[rk] = i } else NCC[rk] = 1
            if (val ~ /^1([^A-Za-z0-9_.]|$)/) {
              N1[rk]++; na++
              AN[na] = rk; AL[na] = i; AS[na] = encl(dep); AT[na] = ""
              # [ <test over flags> ] && X=1 -- the && immediately left of the assignment
              if (ptk == "&&") {
                k = 1; for (j = 1; j < andp; j++) if (substr(M[i], j, 1) == ";") k = j + 1
                AT[na] = substr(L[i], k, andp - k)
              }
            } else if (val !~ /^0([^A-Za-z0-9_.]|$)/ && !(rk in NONLIT)) NONLIT[rk] = i
            continue
          }
          # a word in a case PATTERN (after `in` or `;;`, before its `)`) is pattern text: `else)`
          # or `ok)` is a pattern, never the keyword or the reporter call. Only esac ends the list
          if (dep > 0 && FT[dep] == "C" && CM[dep] == "pat" && tk ~ /^[A-Za-z_]/ && tk != "esac") continue
          # branch bodies: then/else, a case arm and an && / || { } group each open a body. ok and
          # bad/fail calls are charged to the innermost open body (its OWN calls, not those of
          # nested bodies), and a flag is judged by what its body DOES, not where it sits
          if (tk == "{") {
            if (!cmdpos(mt, pos) || (nx != "" && nx !~ /[ \t]/)) continue
            dep++; FT[dep] = (ptk == "&&" || ptk == "||") ? "G" : "X"; FI[dep] = ++fid; FB[dep] = 0
            if (FT[dep] == "G") FB[dep] = newseg(dep)
          } else if (tk == "}") {
            if (!(pre == "" || pre ~ /[ \t;]/) || (nx != "" && nx !~ /[ \t;)|&>]/)) continue
            if (dep > 0 && (FT[dep] == "G" || FT[dep] == "X")) dep--; else MIS++
          } else if (tk == ")") {
            if (dep > 0 && FT[dep] == "C" && CM[dep] == "pat") { CM[dep] = "body"; FB[dep] = newseg(dep) }
          } else if (tk ~ /^;/) {
            if (dep > 0 && FT[dep] == "C") { CM[dep] = "pat"; FB[dep] = 0 }
          } else if (!cmdpos(mt, pos)) {
            continue
          } else if (tk == "if") { dep++; FT[dep] = "I"; FI[dep] = ++fid; FB[dep] = 0 }
          else if (tk == "case") { dep++; FT[dep] = "C"; FI[dep] = ++fid; FB[dep] = 0; CM[dep] = "pat" }
          else if (tk == "then" || tk == "else") {
            if (dep > 0 && FT[dep] == "I") FB[dep] = newseg(dep); else MIS++
          }
          else if (tk == "elif") { if (dep > 0 && FT[dep] == "I") FB[dep] = 0; else MIS++ }
          else if (tk == "fi") { if (dep > 0 && FT[dep] == "I") dep--; else MIS++ }
          else if (tk == "esac") { if (dep > 0 && FT[dep] == "C") dep--; else MIS++ }
          else if (tk == "ok") SOK[encl(dep)] = 1
          else if (tk == "bad" || tk == "fail" || tk == "note_fail") SBAD[encl(dep)] = 1
        }
        t = C[i]; off = 0
        while (match(t, /(^|[ \t;&|({!])(mutant_killed|need_base)([ \t]|$)/)) {
          pos = off + RSTART; tk = substr(t, RSTART, RLENGTH)
          off += RSTART + RLENGTH - 1; t = substr(t, RSTART + RLENGTH)
          if (substr(tk, 1, 1) != "m" && substr(tk, 1, 1) != "n") { pos++; tk = substr(tk, 2) }
          sub(/[ \t]$/, "", tk)
          # captured output: a probe of the helper, not a scoring site (the BL-849 shape)
          SEEN[i] = 1
          if (substr(L[i], 1, pos - 1) ~ /[A-Za-z_][A-Za-z0-9_]*="?\$\([ \t]*$/) { capt++; continue }
          ns++; SL[ns] = i; SP[ns] = pos + length(tk); SN[ns] = tk
        }
      }
      # an if whose branch reports failure (bad, not ok) makes a silent sibling branch its pass
      for (k = 1; k <= segc; k++) if (SK[k] == "I" && SBAD[k] && !SOK[k]) FBO[SF[k]] = 1
      # judge every =1 by its body. `<test> && X=1` is its own silent then-branch whose condition
      # is <test>, exactly as `if <test>; then X=1; fi` nested in the same body would be: passing
      # unless <test> is negated, carries ||, or is a reporter call rather than a test
      for (k = 1; k <= na; k++) {
        why = segv(AS[k])
        if (why != "" && AT[k] != "") { DEFER[k] = why; continue }
        if (why != "" && !(AN[k] in BAD1)) BAD1[AN[k]] = why " at line " AL[k]
      }
      # `[ "<flags>" = 1.. ] && X=1` over bound flags only, judged once those flags are judged
      for (k = 1; k <= na; k++) if (k in DEFER) {
        if (!testok(AT[k]) && !(AN[k] in BAD1)) BAD1[AN[k]] = DEFER[k] " at line " AL[k]
      }
      split("", DEFER)
      split("", OCC)
      if (dep != 0 || MIS != 0) print "R\t" fx "\t" n "\tif/case/group nesting does not balance at end of file (depth " dep ", " MIS " unmatched closer(s)), so no branch can be judged\t" fx "\t-\t1\t(nesting)"
      # coverage: a raw line SPELLED like a call that the quote tracker did not read as code is a
      # site lost to quote drift, which would otherwise read exactly like a bound one
      # site lost to quote drift. A line that STARTS in code and spells the call only inside a
      # single-quoted span it opens and closes itself is data (a seed written by printf), since
      # nothing inside single quotes is ever code; drift carried in from an earlier line, or a
      # spelling in double quotes, is still refused
      for (i = 1; i <= n; i++) {
        if ((i in H) || (i in SEEN) || L[i] ~ /^[ \t]*#/) continue
        if (L[i] !~ /(^|[ \t;&|({!])(mutant_killed|need_base)[ \t]+["$0-9]/) continue
        s = L[i]; gsub(sq "[^" sq "]*" sq, sq sq, s)
        if (SST[i] == "" && s !~ /(^|[ \t;&|({!])(mutant_killed|need_base)[ \t]+["$0-9]/) continue
        print "R\t" fx "\t" i "\ta call spelled where the quote tracker reads a string: " substr(L[i], 1, 120) "\t" skey(i, "(drift) ")
      }
      split("", SEEN)
      for (k = 1; k <= ns; k++) {
        sites++; i = SL[k]; AFN = CUR[i]
        a = nextword(L[i], SP[k]); why = argv_(a)
        if (why ~ /^POS/) why = posv(CUR[i], why, 1)
        # the key is taken for EVERY site, so a fix to an earlier site cannot renumber a later one
        key = skey(i, "")
        if (why != "") print "R\t" fx "\t" i "\t" SN[k] ": " why "\t" key
      }
    }
  ' "$@"
}

# m5_verdict <m5scan-output-file> -> the M5 verdict text; rc 1 on any refused site, else 0.
m5_verdict() {
  if grep -q '^R' "$1"; then
    echo "FAIL M5: a need_base/mutant_killed call site whose flag is not bound to a passing unmutated arm:"
    awk -F '\t' '$1 == "R" { print "    " $2 "/run.sh:" $3 ": " $4 }' "$1"
    echo "  Pass \"\${B_<arm>:-0}\", \"\$B_<arm>\", a \$(( )) conjunction of those, a same-run test"
    echo "  \"\$([ \"\$VAR\" = <literal> ] && echo 1)\" over a captured value, or a helper positional every caller"
    echo "  fills with one of those; set the flag =1 only in the passing branch of the unmutated arm."
    return 1
  fi
  echo "OK M5: every scored call site passes a bound flag"
  return 0
}

WORK="$(mktemp -d)" || { echo "validate-mutant-kills: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# --- self-probe, before the corpus --------------------------------------------------------
P="$WORK/probe"
mkdir -p "$P/core/fixtures/unl" "$P/core/fixtures/bef" "$P/core/fixtures/rou" \
         "$P/core/fixtures/lst" "$P/core/fixtures/stl" "$P/core/fixtures/str" \
         "$P/core/fixtures/prs" "$P/core/fixtures/nm" "$P/core/fixtures/o1" "$P/core/fixtures/o2" \
         "$P/core/fixtures/o3" "$P/core/fixtures/o4" "$P/core/fixtures/o5" "$P/core/fixtures/o6" \
         "$P/core/fixtures/o7" "$P/core/fixtures/d1" "$P/core/fixtures/d2" "$P/core/fixtures/d3" \
         "$P/core/fixtures/d4" "$P/core/fixtures/d5" "$P/core/fixtures/d6" "$P/core/fixtures/d7" \
         "$P/core/fixtures/d8" "$P/core/fixtures/d9"
# BL-903: the instance text, byte for byte (readset-skip/run.sh:5339 at 1a973b957), must be quiet.
BL903_TXT='      ok "INTERRUPTED GROUP: each killed run'\''s recorded process group was alive before the kill and empty after the reap ('\''1|0 1|0'\'', before|after for the run and the endonly run), so no orphan reaches IU'\''s trace root"'
printf '%s\n' "$BL903_TXT" > "$P/core/fixtures/prs/run.sh"
# one near-miss per deny sense, each a lowercase `killed` inside an ok string on a code line
# (a `mut` inside a word and an `m<digit>` inside a token name no mutant, and a mutant named only
# AFTER the `killed` does not stop the mask, so each stays quiet)
printf '%s\n' 'ok "each killed runs record is swept"' 'ok "a killed group leaves no member"' \
  'ok "the killed process group is empty"' 'ok "the killed pid is gone"' \
  'ok "a worker killed by SIGTERM is reaped"' 'ok "a sleep killed with SIGKILL is reaped"' \
  'ok "a commuted job: each killed run is swept"' 'ok "the dim3 grid: a killed run is swept"' \
  'ok "each killed run is reaped before mutant m2 starts"' \
  > "$P/core/fixtures/nm/run.sh"
# a mutant named BEFORE `killed` keeps the kill whatever sense follows: one per kept deny sense,
# and the five lines the narrower-than-contract mask used to acquit
printf '%s\n' 'ok "mutant m4 killed runs past the cap"' > "$P/core/fixtures/d1/run.sh"
printf '%s\n' 'ok "m2 killed by signal arm S3"' > "$P/core/fixtures/d2/run.sh"
printf '%s\n' 'ok "m5 killed child arm C2"' > "$P/core/fixtures/d3/run.sh"
printf '%s\n' 'ok "mutant m7 killed worker arm W2"' > "$P/core/fixtures/d4/run.sh"
printf '%s\n' 'ok "m8 killed pid arm P1 (twin P2 holds)"' > "$P/core/fixtures/d5/run.sh"
printf '%s\n' 'ok "MUTANT g killed group arm G1"' > "$P/core/fixtures/d6/run.sh"
printf '%s\n' 'ok "M6 killed process group arm"' > "$P/core/fixtures/d7/run.sh"
printf '%s\n' 'ok "mutant m9 killed by SIGTERM arm"' > "$P/core/fixtures/d8/run.sh"
printf '%s\n' 'ok "m4 killed run arm R1"' > "$P/core/fixtures/d9/run.sh"
# offenders, one per DISTINCT kill shape in the corpus's 149 unrouted lines
printf '%s\n' 'ok "mutant m3 killed by C1"' > "$P/core/fixtures/o1/run.sh"
printf '%s\n' 'ok "MUTANT y KILLED: the arm moves"' > "$P/core/fixtures/o2/run.sh"
printf '%s\n' 'ok "m3 (drop the guard): killed by C2"' > "$P/core/fixtures/o3/run.sh"
printf '%s\n' 'ok "$1: KILLED by FW[$3] and nothing else"' > "$P/core/fixtures/o4/run.sh"
# a deny word later on the line must not acquit the kill before it (no greedy `killed .* group`)
printf '%s\n' 'ok "mutant g killed by C1: the group arm moves"' > "$P/core/fixtures/o5/run.sh"
# a deny sense and a real kill on one line: only the deny word is masked, the kill still refuses
printf '%s\n' 'ok "each killed run is reaped; mutant r killed by C4"' > "$P/core/fixtures/o6/run.sh"
# a hyphenated cell name that starts with a deny word is a kill target, not a deny sense
printf '%s\n' 'ok "m3 also killed worker-cap"' > "$P/core/fixtures/o7/run.sh"
printf '%s\n' 'ok "MUTANT x killed: the arm moves"' > "$P/core/fixtures/unl/run.sh"
printf '%s\n' 'ok "mutant_killed refused: MUTANT x killed"' > "$P/core/fixtures/str/run.sh"
printf '%s\n' 'ok "x killed"; mutant_killed "$B_x" x "msg"' > "$P/core/fixtures/bef/run.sh"
printf '%s\n' '# a comment naming KILLED and killed' \
  '[ "$m" = 1 ] && mutant_killed "${B_r:-0}" r "MUTANT r killed: moves only r"' \
  'ok "a SIGKILLed worker leaves nothing"' > "$P/core/fixtures/rou/run.sh"
printf '%s\n' 'ok "MUTANT l KILLED"' > "$P/core/fixtures/lst/run.sh"
printf '%s\n' 'mutant_killed "$B_s" s "MUTANT s killed"' > "$P/core/fixtures/stl/run.sh"
printf '%s\n' '# probe allowlist' lst stl gone lst > "$WORK/probe-allow.txt"
scan "$P" > "$WORK/probe-scan.txt"
# the corpus reads M1 through m5scan; over the probe tree that path must equal scan() byte for byte
m5scan "$P" 0 "$WORK/probe-scan-m5.txt" > /dev/null
if ! cmp -s "$WORK/probe-scan.txt" "$WORK/probe-scan-m5.txt"; then
  echo "validate-mutant-kills: REFUSED -- M1 read through m5scan differs from scan() on the probe tree." >&2
  exit 2
fi
judge "$WORK/probe-scan.txt" "$WORK/probe-allow.txt" | cut -f1,2 > "$WORK/probe-got.txt"
printf 'DUP\tlst\nREFUSE\tbef\nREFUSE\td1\nREFUSE\td2\nREFUSE\td3\nREFUSE\td4\nREFUSE\td5\nREFUSE\td6\nREFUSE\td7\nREFUSE\td8\nREFUSE\td9\nREFUSE\to1\nREFUSE\to2\nREFUSE\to3\nREFUSE\to4\nREFUSE\to5\nREFUSE\to6\nREFUSE\to7\nREFUSE\tstr\nREFUSE\tunl\nSTALE\tgone\nSTALE\tstl\n' > "$WORK/probe-want.txt"
probe_f="$(grep -c '^F' "$WORK/probe-scan.txt")" || probe_f=0
if ! cmp -s "$WORK/probe-got.txt" "$WORK/probe-want.txt" || [ "$probe_f" -ne 24 ]; then
  echo "validate-mutant-kills: REFUSED -- self-probe failed (scanned $probe_f of 24 probe files). Verdict rows:" >&2
  sed 's/^/    got  /' "$WORK/probe-got.txt" >&2
  sed 's/^/    want /' "$WORK/probe-want.txt" >&2
  echo "  The arm cannot be shown to fire, so its verdict over the tree would be unattributable." >&2
  exit 2
fi

# --- M4 self-probe: scratch repos whose origin/main carries (or lacks) a base list ----------
# A hook run from a linked worktree exports GIT_DIR, which would override every `git -C` here
# and point the probe at the real repo; the probe drops it, the corpus call below keeps it.
m4_probe_git() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  git -c user.name=probe -c user.email=probe@invalid -c commit.gpgsign=false \
  -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }
m4_case() {  # <label> <repo> <want-rc> <want-text> <cur rows...>
  local lab="$1" repo="$2" wrc="$3" want="$4" got rc
  shift 4
  printf '%s\n' '# probe list' "$@" > "$WORK/m4-cur.txt"
  got="$(unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
         if [ "${lab#m7}" != "$lab" ]; then m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-base.txt" "$ALLOW_REL" M7
         else m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-base.txt"; fi)"; rc=$?
  if [ "$rc" != "$wrc" ] || [ "$got" != "$want" ]; then
    echo "validate-mutant-kills: REFUSED -- M4 self-probe case '$lab' got rc $rc, want rc $wrc." >&2
    printf '%s\n' "$got" | sed 's/^/    got  /' >&2
    printf '%s\n' "$want" | sed 's/^/    want /' >&2
    echo "  M4 cannot be shown to both SKIP and fire, so its verdict over the tree would be unattributable." >&2
    exit 2
  fi
}
R="$WORK/m4-base"; RN="$WORK/m4-nofile"; RX="$WORK/m4-noorigin"
mkdir -p "$R/scripts" "$RN" "$RX"
{ m4_probe_git init -q "$R" && printf '%s\n' '# base' a b > "$R/$ALLOW_REL" \
  && m4_probe_git -C "$R" add "$ALLOW_REL" && m4_probe_git -C "$R" commit -q -m base \
  && m4_probe_git -C "$R" update-ref refs/remotes/origin/main HEAD \
  && m4_probe_git init -q "$RN" && printf 'x\n' > "$RN/other" \
  && m4_probe_git -C "$RN" add other && m4_probe_git -C "$RN" commit -q -m nofile \
  && m4_probe_git -C "$RN" update-ref refs/remotes/origin/main HEAD \
  && m4_probe_git init -q "$RX"; } >/dev/null 2>&1 || {
  echo "validate-mutant-kills: REFUSED -- could not build the M4 probe repos under $WORK" >&2; exit 2; }
M4_REMEDY="  Remedy: do not list the fixture. Route its kills through mutant_killed <flag> <name> \"<message>\"
  (core/fixtures/lib/mutant.sh) and delete the row."
M4_FAILHEAD="FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
m4_case added    "$R"  1 "$M4_FAILHEAD
    c
$M4_REMEDY" a b c
m4_case swap     "$R"  1 "$M4_FAILHEAD
    c
$M4_REMEDY" a c
m4_case shrink   "$R"  0 "OK M4: no allowlist row added against origin/main" a
m4_case same     "$R"  0 "OK M4: no allowlist row added against origin/main" a b
m4_case nofile   "$RN" 0 "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it" a b c
m4_case noorigin "$RX" 0 "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against" a b c

# --- M5 prefilter self-probe: every token the token pass reacts to survives the prefilter ----
# The word set is derived from this file: every `tk == "<word>"` branch test of the token pass.
# It must equal KW (the K rows), and a probe line carrying each word, and each operator, group
# and assignment token, must not be skipped (no P row); the two plain lines must be skipped.
# A KW missing a branch word, or a TOKP missing an operator, fails here.
PF="$WORK/m5pf"; mkdir -p "$PF/core/fixtures/pf"
pf_words="$(grep -o 'tk == "[A-Za-z_][A-Za-z0-9_]*"' "${BASH_SOURCE[0]}" | sed 's/^tk == "//; s/"$//' | LC_ALL=C sort -u)"
{ echo 'need_base x'
  printf '  %s\n' $pf_words
  printf '%s\n' 'a && b' 'a || b' ';;' ';&' ';;&' '{' '}' '(' ')' 'x=1' 'echo plain words 9 here'
} > "$PF/core/fixtures/pf/run.sh"
m5scan "$PF" 1 > "$WORK/m5-pf.txt"
pf_k="$(awk -F '\t' '$1 == "K" { print $2 }' "$WORK/m5-pf.txt" | LC_ALL=C sort -u)"
pf_p="$(awk -F '\t' '$1 == "P" { printf "%s ", $3 }' "$WORK/m5-pf.txt")"
pf_last="$(awk 'END { print NR }' "$PF/core/fixtures/pf/run.sh")"
pf_nw="$(printf '%s\n' "$pf_words" | grep -c .)" || pf_nw=0
if [ "$pf_nw" -lt 14 ] || [ "$pf_k" != "$pf_words" ] || [ "$pf_p" != "1 $pf_last " ]; then
  echo "validate-mutant-kills: REFUSED -- M5 token-pass prefilter self-probe failed: $pf_nw branch word(s) in this file," >&2
  echo "  KW [$(printf '%s ' $pf_k)] against branch words [$(printf '%s ' $pf_words)]; skipped lines [$pf_p], want [1 $pf_last ]." >&2
  echo "  A token the pass reacts to that the prefilter does not carry is a line silently dropped from M5." >&2
  exit 2
fi

# --- M5 self-probe: refused sites and accepted near-misses, scored as exact verdict rows -----
Q="$WORK/m5probe"
mkdir -p "$Q"/core/fixtures/r-const "$Q"/core/fixtures/r-unquoted "$Q"/core/fixtures/r-or \
  "$Q"/core/fixtures/r-bad "$Q"/core/fixtures/r-else "$Q"/core/fixtures/r-negated "$Q"/core/fixtures/r-helper \
  "$Q"/core/fixtures/r-unset "$Q"/core/fixtures/r-tconst "$Q"/core/fixtures/r-tlit "$Q"/core/fixtures/r-other \
  "$Q"/core/fixtures/r-capbare "$Q"/core/fixtures/r-drift "$Q"/core/fixtures/a-drift "$Q"/core/fixtures/a-then \
  "$Q"/core/fixtures/a-conj "$Q"/core/fixtures/a-helper "$Q"/core/fixtures/a-heredoc "$Q"/core/fixtures/a-test \
  "$Q"/core/fixtures/a-wbase "$Q"/core/fixtures/a-string "$Q"/core/fixtures/r-both "$Q"/core/fixtures/r-var \
  "$Q"/core/fixtures/r-alias "$Q"/core/fixtures/r-top "$Q"/core/fixtures/r-andline "$Q"/core/fixtures/r-realias \
  "$Q"/core/fixtures/r-silent "$Q"/core/fixtures/a-else "$Q"/core/fixtures/a-negated "$Q"/core/fixtures/a-alias \
  "$Q"/core/fixtures/a-andtest "$Q"/core/fixtures/a-case "$Q"/core/fixtures/a-group \
  "$Q"/core/fixtures/a-casekw "$Q"/core/fixtures/r-casekw "$Q"/core/fixtures/r-stray \
  "$Q"/core/fixtures/r-tccs "$Q"/core/fixtures/a-tccs
m5f() { local d="$Q/core/fixtures/$1"; shift; printf '%s\n' "$@" > "$d/run.sh"; }
m5f r-const    'mutant_killed 1 x "MUTANT x"'
m5f r-unquoted 'if t; then ok "a"; B_u=1; fi' 'mutant_killed $B_u u "MUTANT u"'
m5f r-or       't || B_o=1' 'mutant_killed "${B_o:-0}" o "MUTANT o"'
m5f r-bad      'if t; then bad "a"; B_b=1; fi' 'mutant_killed "${B_b:-0}" b "MUTANT b"'
m5f r-else     'if t; then ok "a"; else B_e=1; fi' 'mutant_killed "${B_e:-0}" e "MUTANT e"'
m5f r-negated  'if ! t; then B_g=1; fi' 'mutant_killed "${B_g:-0}" g "MUTANT g"'
m5f r-helper   'h() { mutant_killed "$1" h "MUTANT h"; }' 'if t; then ok "a"; B_h=1; fi' 'h "${B_h:-0}"' 'h 1'
m5f r-unset    'mutant_killed "${B_n:-0}" n "MUTANT n"'
m5f r-tconst   'need_base "$([ 1 = 1 ] && echo 1)" tc'
m5f r-tlit     'V=PASS' 'need_base "$([ "$V" = PASS ] && echo 1)" tl' \
               'if t; then ok "a"; B_q=1; fi' 'sc() { mutant_killed "$(( $1 && 1 ))" sc "MUTANT sc"; }' 'sc "${B_q:-0}"'
m5f r-other    'X="$(run)"' 'mutant_killed "$X" x "MUTANT x"'
m5f r-capbare  'o="$(need_base 1 p 2>&1)"; r=$?' 'need_base 1 p'
m5f r-drift    'ok "a need_base 1 x"'
m5f a-drift    'ok "need_base_probe ran"' 'ok "the need_base gate"' "printf '%s\\n' ' mutant_killed 1 Mx probe' > f"
m5f a-then     'if t; then ok "a"; B_x=1; else bad "a"; fi' 'mutant_killed "${B_x:-0}" x "MUTANT x"' \
               'mutant_killed "$B_x" x2 "MUTANT x2"'
m5f a-conj     'if t; then' '  ok "a"; B_a=1' 'fi' 'if u; then ok "b"; B_b=1; fi' \
               'mutant_killed "$(( ${B_a:-0} && ${B_b:-0} ))" ab "MUTANT ab"'
m5f a-helper   'h() {' '  mutant_killed "$1" h "MUTANT h"' '}' 'if t; then ok "a"; B_h=1; fi' 'h "${B_h:-0}"' 'h "$B_h"'
m5f a-heredoc  'cat > f <<EOF' 'mutant_killed 1 x "MUTANT x"' 'EOF'
m5f a-test     'V="$(run)"' 'W=$?' 'need_base "$([ "$V" = PASS ] && [ "$W" -eq 0 ] && echo 1)" t' \
               'mutant_killed "$([ "$V" = PASS ] && echo 1 || echo 0)" t2 "MUTANT t2"' \
               'if t; then ok "a"; B_n=1; fi' 'sc() { mutant_killed "$(( $1 && ${B_n:-0} ))" sc "MUTANT sc"; }' 'sc "${B_n:-0}"'
m5f a-wbase    'W_BASE=0' 'if p1; then W_BASE=1; else' '  note_fail "p1"' 'fi' 'if ! p2; then W_BASE=0' '  note_fail "p2"; fi' \
               'mutant_killed "$W_BASE" w "MUTANT w"'
m5f a-string   "ok \"a \$'it\\'s' word\"" "f \$'x\\'y'" "if t; then ok \"it's\"; B_s=1; fi" 'mutant_killed "${B_s:-0}" s "MUTANT s"'
m5f r-both     'if t; then ok "a"; bad "b"; B_y=1; fi' 'mutant_killed "${B_y:-0}" y "MUTANT y"'
m5f r-var      'if t; then ok "a"; B_v="$Y"; fi' 'mutant_killed "${B_v:-0}" v "MUTANT v"'
m5f r-alias    'h() {' '  local fl="$2"' '  mutant_killed "$fl" h "MUTANT h"' '}' 'if t; then ok "a"; B_h=1; fi' \
               'h x "${B_h:-0}"' 'h x "${B_z:-0}"' 'k2() { h x "$1"; }' 'k2 "${B_h:-0}"'
m5f r-top      'B_t=1' 'mutant_killed "${B_t:-0}" t "MUTANT t"'
m5f r-andline  't && ok "a"; B_l=1' 'mutant_killed "${B_l:-0}" l "MUTANT l"'
m5f r-realias  'h() {' '  local fl="$1"; fl=1' '  mutant_killed "$fl" h "MUTANT h"' '}' 'if t; then ok "a"; B_h=1; fi' 'h "$B_h"'
m5f r-silent   'if t; then :; else B_q=1; fi' 'mutant_killed "${B_q:-0}" q "MUTANT q"' \
               'if [ "$rc" -ne 0 ]; then B_w=1; fi' 'mutant_killed "${B_w:-0}" w "MUTANT w"' \
               'grep -q FAIL o && B_f=1' 'mutant_killed "${B_f:-0}" f "MUTANT f"'
m5f a-else     'if [ "$rc" -ne 0 ]; then' '  bad "a"' 'else' '  ok "a"; B_e=1' 'fi' 'mutant_killed "${B_e:-0}" e "MUTANT e"'
m5f a-negated  'if ! grep -q x f; then' '  ok "a"; B_g=1' 'else' '  bad "a"' 'fi' 'mutant_killed "$B_g" g "MUTANT g"'
m5f a-alias    'mx() {' '  local m="$1" t="$2" fl="$3"' '  if run "$m"; then ok "g"; else mutant_killed "$fl" "$m" "MUTANT $m"; fi' '}' \
               'kc() { for a in x y; do mx "$1" "$a" "$2"; done; }' \
               'if t; then ok "a"; B_c=1; fi' 'mx m1 a "${B_c:-0}"' 'mx m2 b \' '  "$B_c"' 'kc m3 "${B_c:-0}"'
m5f a-andtest  'if t; then ok "a"; B_p=1; fi' 'if u; then ok "b"; B_r=1; fi' \
               'B_pr=0; [ "${B_p:-0}${B_r:-0}" = 11 ] && B_pr=1' 'mutant_killed "$B_pr" pr "MUTANT pr"'
m5f a-case     'if t; then' '  ok "a"' '  case "$i" in 1) B_k_1=1 ;; 2) B_k_2=1 ;; esac' 'fi' 'mutant_killed "${B_k_1:-0}" k "MUTANT k"'
m5f a-group    'if t; then' '  for x in a b; do' '    [ -n "$x" ] && { ok "x ${x}"; B_d=1; }' '  done' 'fi' 'mutant_killed "${B_d:-0}" d "MUTANT d"'
m5f a-casekw   'if t; then' '  case "$v" in' '    else) s=1 ;;' '    fi|then) s=2 ;;' '  esac' '  ok "a"; B_w=1' 'fi' 'mutant_killed "${B_w:-0}" w "MUTANT w"'
m5f r-casekw   'if t; then' '  case "$v" in' '    ok) B_c=1 ;;' '  esac' 'fi' 'mutant_killed "${B_c:-0}" c "MUTANT c"'
m5f r-stray    'if t; then ok "a"; B_s=1; fi' 'fi' 'mutant_killed "${B_s:-0}" s "MUTANT s"'
m5f r-tccs     'V="$(printf 0)"' 'need_base "$([ "$V" -eq 0 ] && echo 1 || echo 0)" v' \
               'W="$(echo 1)"' 'need_base "$([ "$W" = 1 ] && echo 1)" w' \
               "X=\"\$(echo 'PASS' all \"ok here\")\"" 'need_base "$([ "$X" != FAIL ] && echo 1)" x'
m5f a-tccs     'V="$(some_cmd "$x")"' 'need_base "$([ "$V" -eq 0 ] && echo 1 || echo 0)" v' \
               'run_it; W=$?' 'need_base "$([ "$W" -eq 0 ] && echo 1 || echo 0)" w' \
               'R="$(printf 1)"' 'if t; then run_it; R=$?; fi' 'need_base "$([ "$R" -eq 0 ] && echo 1 || echo 0)" r'
m5scan "$Q" > "$WORK/m5-probe-scan.txt"; m5p_rc=$?
cat > "$WORK/m5-probe-want.txt" <<'WANT'
R	r-alias	3	mutant_killed: positional $2 of h: the caller at line 7 passes "${B_z:-0}" -- flag B_z is never set to 1
R	r-andline	2	mutant_killed: flag B_l is set to 1 outside any passing branch at line 1
R	r-bad	2	mutant_killed: flag B_b is set to 1 in a branch that calls bad at line 1
R	r-both	2	mutant_killed: flag B_y is set to 1 in a branch that calls both ok and bad at line 1
R	r-capbare	2	need_base: constant argument 1
R	r-casekw	6	mutant_killed: flag B_c is set to 1 in a branch that calls neither ok nor bad at line 3
R	r-const	1	mutant_killed: constant argument 1
R	r-drift	1	a call spelled where the quote tracker reads a string: ok "a need_base 1 x"
R	r-else	2	mutant_killed: flag B_e is set to 1 in a branch that calls neither ok nor bad at line 1
R	r-helper	1	mutant_killed: positional $1 of h: the caller at line 4 passes 1 -- constant argument 1
R	r-negated	2	mutant_killed: flag B_g is set to 1 in a branch that calls neither ok nor bad at line 1
R	r-or	2	mutant_killed: flag B_o is set to 1 outside any passing branch at line 1
R	r-other	2	mutant_killed: flag X is assigned a non-literal value at line 1
R	r-realias	3	mutant_killed: alias fl of $1 in h is assigned again at line 2
R	r-silent	2	mutant_killed: flag B_q is set to 1 in a branch that calls neither ok nor bad at line 1
R	r-silent	4	mutant_killed: flag B_w is set to 1 in a branch that calls neither ok nor bad at line 3
R	r-silent	6	mutant_killed: flag B_f is set to 1 outside any passing branch at line 5
R	r-stray	3	if/case/group nesting does not balance at end of file (depth 0, 1 unmatched closer(s)), so no branch can be judged
R	r-tccs	2	need_base: test variable V is only ever assigned a constant command substitution (line 1), so its value does not depend on the run
R	r-tccs	4	need_base: test variable W is only ever assigned a constant command substitution (line 3), so its value does not depend on the run
R	r-tccs	6	need_base: test variable X is only ever assigned a constant command substitution (line 5), so its value does not depend on the run
R	r-tconst	1	need_base: a same-run test whose left operand is not a quoted variable: "$([ 1 = 1 ] && echo 1)"
R	r-tlit	2	need_base: test variable V is assigned a literal at line 1, not a command substitution or a $? capture
R	r-tlit	4	mutant_killed: a conjunction operand that is not a flag: "$(( $1 && 1 ))"
R	r-top	2	mutant_killed: flag B_t is set to 1 outside any passing branch at line 1
R	r-unquoted	2	mutant_killed: unquoted argument $B_u
R	r-unset	1	mutant_killed: flag B_n is never set to 1
R	r-var	2	mutant_killed: flag B_v is assigned a non-literal value at line 1
T	46	1
WANT
grep -v '^F' "$WORK/m5-probe-scan.txt" | cut -f1-4 > "$WORK/m5-probe-got.txt"
m5p_f="$(grep -c '^F' "$WORK/m5-probe-scan.txt")" || m5p_f=0
m5_out="$(m5_verdict "$WORK/m5-probe-scan.txt")"; m5_rc=$?
grep -v '^R' "$WORK/m5-probe-scan.txt" > "$WORK/m5-probe-clean.txt"
m5c_out="$(m5_verdict "$WORK/m5-probe-clean.txt")"; m5c_rc=$?
if [ "$m5p_rc" -ne 0 ] || [ "$m5p_f" -ne 39 ] || ! cmp -s "$WORK/m5-probe-got.txt" "$WORK/m5-probe-want.txt" \
   || [ "$m5_rc" -ne 1 ] || [ "${m5_out%%:*}" != "FAIL M5" ] \
   || [ "$m5c_rc" -ne 0 ] || [ "$m5c_out" != "OK M5: every scored call site passes a bound flag" ]; then
  echo "validate-mutant-kills: REFUSED -- M5 self-probe failed (awk rc $m5p_rc, scanned $m5p_f of 39, verdict rc $m5_rc/$m5c_rc). Rows:" >&2
  sed 's/^/    got  /' "$WORK/m5-probe-got.txt" >&2
  sed 's/^/    want /' "$WORK/m5-probe-want.txt" >&2
  echo "  M5 cannot be shown to both refuse and accept, so its verdict over the tree would be unattributable." >&2
  exit 2
fi

# --- M5 site-allowlist self-probe (M5 new site, M6 stale/dup, M7 down-only) ----------------
# Over the probe scan above: a listed site is accepted, an unlisted one refused, a row whose site
# is not refused is STALE, a row twice is DUP -- scored as the exact verdict rows. Then the key:
# an unrelated line inserted ABOVE a refused site leaves its key unchanged (no line number in it),
# and two identical sites in one function carry occurrences 1 and 2.
awk -F '\t' '$1 == "R" && $2 != "r-tlit" { print $5 "\t" $6 "\t" $7 "\t" $8 }' "$WORK/m5-probe-scan.txt" > "$WORK/m5a.txt"
printf 'r-gone\t-\t1\tmutant_killed "$B_g" g "MUTANT g"\n' >> "$WORK/m5a.txt"
awk -F '\t' '$1 == "R" && $2 == "r-const" { print $5 "\t" $6 "\t" $7 "\t" $8 }' "$WORK/m5-probe-scan.txt" >> "$WORK/m5a.txt"
m5judge "$WORK/m5-probe-scan.txt" "$WORK/m5a.txt" | cut -f1-3 > "$WORK/m5a-got.txt"
printf 'DUP\tr-const\t-\nR\tr-tlit\t2\nR\tr-tlit\t4\nSTALE\tr-gone\t-\n' > "$WORK/m5a-want.txt"
QK="$WORK/m5key"; mkdir -p "$QK/a/core/fixtures/k" "$QK/b/core/fixtures/k"
printf '%s\n' 'h() {' '  mutant_killed 1 x "M"' '  mutant_killed 1 x "M"' '}' 'h' > "$QK/a/core/fixtures/k/run.sh"
printf '%s\n' '# an unrelated edit' 'f=0' 'h() {' '  mutant_killed  1 x "M"' '  mutant_killed 1 x "M"' '}' 'h' > "$QK/b/core/fixtures/k/run.sh"
m5scan "$QK/a" | awk -F '\t' '$1 == "R" { print $5 "\t" $6 "\t" $7 "\t" $8 }' > "$WORK/m5k-a.txt"
m5scan "$QK/b" | awk -F '\t' '$1 == "R" { print $5 "\t" $6 "\t" $7 "\t" $8 }' > "$WORK/m5k-b.txt"
printf 'k\th\t1\tmutant_killed 1 x "M"\nk\th\t2\tmutant_killed 1 x "M"\n' > "$WORK/m5k-want.txt"
if ! cmp -s "$WORK/m5a-got.txt" "$WORK/m5a-want.txt" || ! cmp -s "$WORK/m5k-a.txt" "$WORK/m5k-want.txt" \
   || ! cmp -s "$WORK/m5k-b.txt" "$WORK/m5k-want.txt"; then
  echo "validate-mutant-kills: REFUSED -- M5 site-allowlist self-probe failed. Verdict rows, then keys:" >&2
  sed 's/^/    got  /' "$WORK/m5a-got.txt" >&2; sed 's/^/    want /' "$WORK/m5a-want.txt" >&2
  sed 's/^/    key a /' "$WORK/m5k-a.txt" >&2; sed 's/^/    key b /' "$WORK/m5k-b.txt" >&2
  echo "  The site allowlist cannot be shown to accept, refuse, go stale and refuse a duplicate." >&2
  exit 2
fi
m4_case m7added "$R" 1 "FAIL M7: allowlist row(s) not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:
    c
  Remedy: do not list the site. Bind its flag (see FAIL M5's remedy) and delete the row." a b c

# --- the corpus ---------------------------------------------------------------------------
set -- "$ROOT"/core/fixtures/*/run.sh
listed_n=0
[ -f "$1" ] && listed_n=$#
if [ "$listed_n" -lt 100 ]; then
  echo "validate-mutant-kills: REFUSED -- core/fixtures/*/run.sh matched $listed_n file(s), below the floor of 100. The glob stopped matching or the tree moved; an empty corpus has no offenders by construction." >&2
  exit 2
fi
# one read of the corpus: M5 to m5-scan.txt, and M1 (scan's output, byte for byte) to scan.txt
m5scan "$ROOT" 0 "$WORK/scan.txt" > "$WORK/m5-scan.txt"; m5s_rc=$?; scan_rc=$m5s_rc
scanned_n="$(grep -c '^F' "$WORK/scan.txt")" || scanned_n=0
if [ "$scan_rc" -ne 0 ] || [ "$scanned_n" -ne "$listed_n" ]; then
  echo "validate-mutant-kills: REFUSED -- listed $listed_n run.sh, scanned $scanned_n (awk rc $scan_rc). A file listed and never opened reads exactly like a clean one." >&2
  exit 2
fi
tot="$(sed -n 's/^T	//p' "$WORK/scan.txt")"
if [ "${tot:-0}" -lt 1 ]; then
  echo "validate-mutant-kills: REFUSED -- zero kill lines (routed or not) across $scanned_n run.sh. The grammar stopped matching; this is not a clean tree." >&2
  exit 2
fi

if [ "$MODE" = derive ]; then
  awk -F '\t' '$1 == "U" { print $2 }' "$WORK/scan.txt" | LC_ALL=C sort -u
  exit 0
fi
if [ "$MODE" = derive5 ]; then
  awk -F '\t' '$1 == "R" { print $5 "\t" $6 "\t" $7 "\t" $8 }' "$WORK/m5-scan.txt" | LC_ALL=C sort
  exit 0
fi

if [ ! -f "$ROOT/$ALLOW_REL" ]; then
  echo "validate-mutant-kills: FAIL -- $ALLOW_REL is missing. Regenerate its rows with --derive." >&2
  exit 1
fi
judge "$WORK/scan.txt" "$ROOT/$ALLOW_REL" > "$WORK/verdict.txt"
m5s_f="$(grep -c '^F' "$WORK/m5-scan.txt")" || m5s_f=0
m5_sites="$(awk -F '\t' '$1 == "T" { print $2 }' "$WORK/m5-scan.txt")"
m5_capt="$(awk -F '\t' '$1 == "T" { print $3 }' "$WORK/m5-scan.txt")"
if [ "$m5s_rc" -ne 0 ] || [ "$m5s_f" -ne "$listed_n" ] || [ "${m5_sites:-0}" -lt 1 ]; then
  echo "validate-mutant-kills: REFUSED -- M5 listed $listed_n run.sh, scanned $m5s_f (awk rc $m5s_rc), and scored ${m5_sites:-0} call site(s). Zero sites is a grammar that stopped matching, not a bound tree." >&2
  exit 2
fi
if [ ! -f "$ROOT/$M5_ALLOW_REL" ]; then
  echo "validate-mutant-kills: FAIL -- $M5_ALLOW_REL is missing. Regenerate its rows with --derive-m5." >&2
  exit 1
fi
m5judge "$WORK/m5-scan.txt" "$ROOT/$M5_ALLOW_REL" > "$WORK/m5-verdict.txt"
grep '^R' "$WORK/m5-verdict.txt" > "$WORK/m5-new.txt"
m5_out="$(m5_verdict "$WORK/m5-new.txt")"; m5_rc=$?
m5_listed="$(grep -c '^R' "$WORK/m5-scan.txt")" || m5_listed=0
m5_stale="$(grep -cE '^(STALE|DUP)' "$WORK/m5-verdict.txt")" || m5_stale=0
m7_out="$(m4 "$ROOT" "$ROOT/$M5_ALLOW_REL" "$WORK/m7-root-base.txt" "$M5_ALLOW_REL" M7)"; m7_rc=$?
allow_n="$(grep -cvE '^[[:space:]]*(#|$)' "$ROOT/$ALLOW_REL")" || allow_n=0
unrouted_n="$(grep -c '^U' "$WORK/scan.txt")" || unrouted_n=0
m4_out="$(m4 "$ROOT" "$ROOT/$ALLOW_REL" "$WORK/m4-root-base.txt")"; m4_rc=$?

if [ -s "$WORK/verdict.txt" ] || [ "$m4_rc" -ne 0 ] || [ "$m5_rc" -ne 0 ] || [ "$m5_stale" -ne 0 ] || [ "$m7_rc" -ne 0 ]; then
  [ "$m4_rc" -ne 0 ] && printf '%s\n' "$m4_out" >&2
  [ "$m5_rc" -ne 0 ] && printf '%s\n' "$m5_out" >&2
  [ "$m7_rc" -ne 0 ] && printf '%s\n' "$m7_out" >&2
  if grep -q '^STALE' "$WORK/m5-verdict.txt"; then
    echo "FAIL M6: $M5_ALLOW_REL row(s) whose site is no longer refused (bound now, or gone) -- delete them:" >&2
    awk -F '\t' '$1 == "STALE" { print "    " $2 " " $3 " #" $4 ": " $5 }' "$WORK/m5-verdict.txt" >&2
  fi
  if grep -q '^DUP' "$WORK/m5-verdict.txt"; then
    echo "FAIL M6: duplicate row(s) in $M5_ALLOW_REL:" >&2
    awk -F '\t' '$1 == "DUP" { print "    " $2 " " $3 " #" $4 ": " $5 }' "$WORK/m5-verdict.txt" >&2
  fi
  if grep -q '^REFUSE' "$WORK/verdict.txt"; then
    echo "FAIL M1: a mutant kill emitted outside mutant_killed, in a fixture not on $ALLOW_REL:" >&2
    awk -F '\t' '$1 == "REFUSE" { print "    " $2 "/run.sh:" $3 }' "$WORK/verdict.txt" >&2
    echo "  Emit the kill as: mutant_killed <flag> <name> \"<message>\", sourcing core/fixtures/lib/mutant.sh," >&2
    echo "  where <flag> is 1 only when the unmutated arm this mutant guards PASSED in this run. Do not add" >&2
    echo "  the fixture to the allowlist: it only shrinks." >&2
  fi
  if grep -q '^STALE' "$WORK/verdict.txt"; then
    echo "FAIL M2: allowlist row(s) with no unrouted kill left (or no such fixture) -- remove them from $ALLOW_REL:" >&2
    awk -F '\t' '$1 == "STALE" { print "    " $2 }' "$WORK/verdict.txt" >&2
  fi
  if grep -q '^DUP' "$WORK/verdict.txt"; then
    echo "FAIL M3: duplicate allowlist row(s) in $ALLOW_REL:" >&2
    awk -F '\t' '$1 == "DUP" { print "    " $2 }' "$WORK/verdict.txt" >&2
    echo "  Remedy: delete the duplicate row(s), keeping one row per fixture." >&2
  fi
  exit 1
fi
echo "$m4_out"
echo "$m7_out"
echo "$m5_out ($m5_sites scored, $m5_capt captured and not scored; $m5_listed refused site(s), every one a row of $M5_ALLOW_REL, no stale or duplicate row)"
echo "OK: validate-mutant-kills -- self-probe fired both ways; $scanned_n run.sh scanned, $tot kill line(s), $unrouted_n unrouted, all in the $allow_n allowlisted fixture(s); no stale or duplicate row."
exit 0
