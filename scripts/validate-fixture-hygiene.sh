#!/usr/bin/env bash
# validate-fixture-hygiene.sh -- static hygiene of the fixture corpus: no false SKIP on a condition true in normal use,
# no `sh` start the invocation counter cannot see, no bounded real-time wait (H9, BL-868), and no fixture that carries
# a mutation battery (H12).
#
# usage:  validate-fixture-hygiene.sh            check the tree (exit 0 clean, 1 FAIL, 2 broken)
#
# Standalone pre-suite step in .githooks/pre-push, deliberately NOT an arm of
# validate-enforcement-map.sh, which the suite pole invokes. Distribution-only: repo-root scripts/ is never installed.
#
# THE CORPUS: `git ls-files -- 'core/fixtures/**/*.sh'` under the resolved root, COUNTED. Zero listed is a FAIL, and
# every listed file must be opened by the scan (an `F` row per file, compared with the list) -- an awk `getline`-free
# scan, so a file the shell listed and awk never opened is a count mismatch, not a clean file.
#
# THE MASKER. Every arm reads a MASKED copy of each line: the bytes inside single quotes, `$'...'`, double quotes
# (except a `$( )` inside them, which stays code), comments, and heredoc bodies are replaced by X, with the quote state
# carried across lines and reset per file. A file that ends with the masker inside a string or a heredoc is reported
# BROKEN (exit 2), never scanned silently half-masked. So `sh` or `exit 0` inside an awk program, a printf seed or a
# heredoc is data, and an arm sees only code.
#
# THE ARMS. That each can fire was proved once, by hand, at authoring; the default run reads only the tree.
#
# H1  linked-worktree false skip. A `-d <expr>` test inside `[`, `[[` or `test` (negated by `!` inside or before the
#     bracket, or not) whose operand ends in `/.git` (or is `.git`), and whose ABSENT branch reaches `exit 0` (or a
#     bare `exit`): in an `if`/`elif` condition, the then-body for a negated test and the else-body otherwise, through
#     the matching `fi`; in a statement, the `||` branch (`&&` when negated), a `{ }` or `( )` group through its close.
#     In a linked worktree `.git` is a FILE, so such a fixture skips green in normal use. A trailing comment after the
#     exit (`|| exit 0 # why`) is stripped from the branch before the exit test, in H1 and H2 alike.
#     FP SET. Raw grammar, non-comment `-d …/.git` lines: 46 over the 450 tracked core/fixtures/**/*.sh (the
#     contract's 47 included readset-skip:3240, `-d "$dst/.git/modules/lib/sub"`, which does not end in `.git` and is
#     outside the population by construction). Narrowed by KEYING ON THE BRANCH, not the test: 45 of the 46 fail
#     with exit 2 / FIXTURE BROKEN / rc=1 / bad, or have no absent branch at all (`[ -d x/.git ] && git … prune`).
#     Final hits: 1, self-update-join-gate/run.sh:49 -- an OFFENDER (its SKIP fires in every linked worktree), fixed
#     on this branch. Measured false positives in the final set: 0.
# H2  missing-tool skip. A `command -v <t>` in command position (outside quotes) where <t> is a line of the SAME
#     fixture directory's tools.decl (a leading `?` stripped: hermetic-run.sh refuses an unresolved unkeyed tool too),
#     whose failing branch reaches `exit 0` by the H1 branch rules. hermetic-run never reaches these skips (it refuses
#     an undeclared-and-absent tool first); they mislead a DIRECT run, which is why they are fixed (exit 2, FIXTURE
#     BROKEN) rather than allowed.
#     FP SET. Raw: 215 non-comment `command -v` lines; 6 with `exit 0` on the same line, and 7 more with `exit 0`
#     within three lines. Narrowed by (a) masking -- foreground-budget-deny:543 (inside a sed expression),
#     postcompact-rulebook-recovery:1147 (a string), reconcile-emit-report:4547, hermetic-runner:731 and the two
#     wait-beat-liveness printf seeds are data; (b) the tool join -- only a tools.decl tool counts; (c) the branch --
#     apply-drift-after-write:172 skips through `ok "SKIP …"` with no exit and is not an offender. Final hits: 6,
#     all OFFENDERS: agent-definition-render:57, check-25-steering-conduct:35, architecture-index-cell-escaping:55
#     (fixed on this branch), layer-adjudication-tier:82, escalation-delivery:33, transient-ignore-block:62.
#     consumer-machinery-home, extension-check-adoption, derivation-capture and file-mtime carry no such site
#     (derivation-capture:34 exits 2).
# H3  a script started under `sh`: `sh`, `/bin/sh` or `/usr/bin/sh` in command position (line start, after `;`,
#     `&`, `|`, `(`, a backtick, `{`, `!`, `then`/`do`/`else`/`exec`/`time`/`nohup`/`xargs`/`command`, or `env`
#     with optional `-i` and `VAR=val` words), outside quotes, followed by an argument -- `-c`, a flag or an operand,
#     never `==`, `!=`, `=`, `)` or a redirection. AND a STDIN start: after a `|`, `sh` followed by the end of the
#     line or by `;`, `)`, `&`, `|`, `<` or `>` (`… | sh;`, `| sh`) -- never by `=`. `/bin/sh` reads no BASH_ENV, so
#     the invocation counter cannot see the start.
#     FP SET. Raw: 15 lines carrying `sh <word>` in a command-ish position. Narrowed by masking (the awk
#     `sh == ""` / `sh != ""` programs in backlog-rotate-fence-guard, check-24, ledger-reverify, ledger-rotate,
#     shadowed-local-validators; the `(sh false)` messages in backlog-ledger; ledger-reverify:5997's printf) and by
#     the next-word rule. Re-derived on the b245-p1-fold tree with a stricter raw grep (command position, a next
#     word that is not `=`, `!`, `)` or an operator), which already excludes the awk `sh ==` forms: 9 lines -- the 5
#     word-form offenders below, backlog-ledger:401 and :402 and ledger-reverify:5997 (strings), and
#     fixture-hygiene:77 (a heredoc seed). A `case` alternation `bash|sh)` would fire under the stdin rule's `)`;
#     0 such lines in code (the 3 in check-24 are inside awk strings). The stdin form, raw (non-comment lines with `|` then `sh` then end of line or one of
#     `;)&|<>`): 8 lines; masking removes 7, all inside quoted regexes or strings -- ledger-reverify:4268, :4364 and
#     :4528 (`'verify: (theirs_has|sh)'`) and procsub-staged-refusal-boot:291, :673, :1644 and :1670 (`(md|sh|json)`).
#     The `env … sh` and `command sh` forms: 0 raw lines, also under a wider grep taking ANY words between `env`
#     and a bare `sh` (control: 116 `env -u` lines in the same corpus). `env -u NAME sh` is not parsed as a start. Final hits on that tree: 6, all OFFENDERS, every one
#     since migrated to `bash`: three in readset-skip (`exec sh -c`, two `sh -c 'exit 0' &`), one in
#     readset-stage1-verdict (`sh -c 'exit 0' &`), two in self-update-gate (`sh scripts/…`, `git show … | sh;`).
#     THE STUB JOIN. A file the script VISIBLY writes with a `#!/bin/sh` (or `#!/usr/bin/env sh`) shebang -- `printf
#     '#!/bin/sh…' > P`, `echo '#!/bin/sh' > P` (a `\`-continued statement joined), or `cat > P <<W` whose first body
#     line is the shebang -- JOINED to a line of the same file that executes P honouring the shebang: P in command
#     position (bare, `exec`, `env`, `command`, `nohup`, after `VAR=val` words), or a `PATH=` word naming P's
#     directory as one of its `:` entries (`${x:-D}` read as D). The shebang is read off the UNMASKED line: the
#     masker Xes the printf string and the heredoc body. P is compared as written, `${v}` read as `$v`. A row names
#     the write line and the nearest execution line after it (wrapping to the top for a function defined below).
#     `bash P` and `cmp -s P …` are arguments, never command position; a line continuing a `\` is an argument list.
#     FP SET, measured on 47102ad20 with b248-mutants' 50ef548a5 applied: raw, 229 `#!/bin/sh` lines across 54 files
#     (control: 826 `#!/usr/bin/env bash` lines in the same corpus); most are dist/consumer DATA written for a subject
#     the fixture never executes itself. First join: 29 rows. Narrowed by (a) reading PATH= off the unmasked line
#     (`env "PATH=$D:$PATH"`, `he_run_env "PATH=…"`), which ADDED story-evidence-scaffold receipt-bl815:144 and
#     prepush-ssh-keepalive:111/:112; (b) `${3:-D}` read as D; (c) dropping a `\`-continued argument line, which
#     moved check5-anchor-base:75/:76 OUT of the joined set (P named only as a `cp` operand on :148 and :589) -- a
#     wrong JOIN removed, not a false positive: those stubs ARE executed, by the subject, and are a stated limit;
#     (d) a PATH= feeding only `command -v`/`type`/`which` ranks after every real run and is labelled a lookup:
#     3 rows (dispatch-model-guard:1475, wait-beat-liveness:2787/:2853) whose stubs the fixture then runs through a
#     variable PATH (`fo_cell … "$ML_SHIM:"`, `aged_shell_beat … "$sb_d_"`), the lookup proving the placement.
#     Final: 32 rows, each read by hand: an executed stub, or for the 3 lookups a stub placed for its execution.
#     STATED LIMITS: a variable-spelled interpreter (prepush-ssh-keepalive:46); an `sh` start INSIDE a `bash -c "…"`
#     (or `'…'`) string -- masked as data like every string, so `bash -c "sh -c true"` is not seen; and, for the stub
#     join, every execution the line grammar cannot join to the write: a PATH directory spelled through a variable
#     (`PATH="$2$PATH"`), a stub path or PATH entry injected by `sed` or another program, a stub copied (`cp`) before
#     it runs, a stub the SUBJECT executes by a path the fixture only seeds (check5-anchor-base:75/:76 run by
#     validate-mandatory-rules.sh:199), a P spelled differently at the two sites, and a stub written in a loop
#     whose name is the loop variable joined only when the execution spells P identically.
# H4  DROPPED, with its numbers. The contract's form -- a bare `sed … IN > OUT` statement whose OUT is later compared
#     with IN by `cmp -s` in the same file -- matched 857 raw sed-into-file lines, 400 bare statements, and 200 of
#     them joined to a `cmp -s` on the same IN/OUT pair, across 78 fixtures (the contract adversary's naive form had
#     matched 2 of 535). Whether one of the 200 is an offender depends on what the mutant's kill asserts downstream,
#     which no line grammar sees, so the false-positive set is not enumerable and the arm is not shipped.
# E1  an INERT receipt: a tracked `core/fixtures/*/receipt*.sh` or `scripts/receipt*.sh` that nothing reads, so no gate
#     ever runs it. THE PREDICATE is `inert()` below; E1 reports its set. A READER is a RUNNER only: a non-comment line of a tracked
#     core/fixtures/*/{run,seed,lib}.sh or .githooks/* naming `<fixture>/<file>`, or the bare basename from a file in
#     the receipt's own directory; for a scripts/ receipt, also any tracked scripts/*.sh other than itself. That is
#     BL-915's rule: a receipt file no `run.sh` invokes fails the push.
#     WHY A `verify:` LINE IS NOT A READER HERE. An earlier E1 counted a live `verify:` line of docs/backlog.md, plus a
#     `verify:` line added to docs/backlog.archive.md since the merge-base -- the latter only on the branch that
#     rotates the entry. So the release that rotates an entry like BL-538 (docs/backlog.md:128, `verify: sh bash
#     core/fixtures/process-rule-pins/receipt-bl538.sh`, named by no run.sh) passes, and every LATER unrelated
#     branch's push fails E1 on a receipt it never touched -- and cannot allowlist it, because E1-M4 refuses a row
#     absent from origin/main. Its push is wedged. With runners only, E1 reads nothing another branch's ledger edit can
#     change: a receipt named only by its verify: line is inert from the day it lands. After the first release that
#     ships scripts/inert-receipt-allowlist.txt, the down-only check refuses an added row, so a new receipt that only
#     a verify: line names cannot ship until a runner invokes it; the one exception is the release that first ships
#     the allowlist.
#     KNOWN ACQUITTALS: a name inside a message string (zz9, `echo "receipt-x.sh …"`)
#     counts as a reader, and so does a name in a TRAILING comment after code (zz13, `cmd # bash "$HERE/receipt-x.sh"`),
#     because only lines whose first non-blank character is `#` are skipped. A line grammar cannot acquit
#     `bash "$R736"` and convict `echo receipt.sh` without resolving variables, and the variable form (zz3,
#     `R="$HERE/receipt-zz3.sh"; bash "$R"`) is a real invocation; stripping a trailing comment needs a quote-aware
#     scan, since `#` inside a string or `${#x}` is not a comment.
#     STATED LIMITS: a receipt called only from a helper that run.sh sources (a matrix.sh, world.sh or *-arms.sh) is
#     not a reader file, so the arm reads it as INERT even though run.sh executes it. Measured: 0 such receipts today
#     (control: 30 run.sh files carry the token). The remedy is to make the call from run.sh, seed.sh or lib.sh. The
#     failure is fail-closed.
#     A receipt reached only through a computed name (`bash "$HERE/receipt-bl$N.sh"`) reads as inert;
#     a reader outside the listed files (a docs/ runbook, a plan) is not a reader, because no gate runs it.
#     THE ALLOWLIST scripts/inert-receipt-allowlist.txt, rows `<path>\t<reason>`, DOWN-ONLY by the shared m4 (arm
#     E1-M4): an unlisted inert receipt FAILs; a row whose file is gone or is now read is STALE and FAILs; a duplicate
#     row and a row with no reason FAIL; a row not on the list at origin/main FAILs.
#     FP SET, how it reached its value. The predicate was lifted unchanged from the BL-868 receipt (since deleted; its
#     class W scan is H9), where it decided which receipts that receipt skips; on the BL-915 filing tree 0.1004.0 was
#     built on, its old and its lifted copy give byte-identical output over that receipt's own list (86 inert, 367
#     reader files). Widening the population to scripts/receipt*.sh added
#     scripts/*.sh as readers for those receipts only, with self-reference excluded (a receipt naming itself, e.g. in a
#     usage line, is not a reader). The corpus does not exercise that exclusion today (0 of the 4 names itself on a
#     non-comment line; measured both ways, 4 inert either way). On
#     the BL-915 filing tree 0.1004.0 was built on, E1 flags 90: the 72 the BL-915 census classed uninvoked (68 fixture receipts plus the 4 scripts/
#     receipts, every one flagged, none missed) and 18 more, each read by hand -- 6 non-BL receipt.sh / receipt-*.sh
#     run by no gate (apply-restamp-worklist x2, check-24, layer-adjudication-tier, serial-remediation-worklist,
#     wait-stale-deliverable; the seventh non-BL receipt, subject-partition's, is invoked and stays quiet), 3
#     archived-entry receipts (adversarial-shard-merge bl718 and bl719, check-24 bl829), and 9 live-entry receipts
#     whose entries carry `verify: manual` or no verify line and name the receipt only in prose (bl868, bl716, bl804,
#     bl809 x3, bl844, bl808, bl811). Six of the nine are also named in backlog-real-ledger's ledger.snapshot, in prose
#     only (0 of the 18 on a snapshot `verify:` line, against 60 verify lines there), so that snapshot is no reader.
#     None is invoked by any gate, so the extra 18 are TRUE positives, not false ones; measured false positives: 0.
#     With the 72 deleted (the BL-915 tip), E1 flags exactly those 18, which are the allowlist's rows.
#     NARROWED TO RUNNERS (the verify: clause and the archive clause removed). Re-measured on a797fd022 with this
#     file and the previous one over the same detached tree: 91 against 90, the one new row
#     process-rule-pins/receipt-bl538.sh, the only receipt any `verify:` line of docs/backlog.md names (50 verify lines,
#     none indented; the archive clause added nothing at that base). It is run by no runner, so it is a true positive
#     under BL-915's rule and carries an allowlist row; measured false positives: still 0.
# H6  an UNGUARDED lib source (BL-925). A `.`/`source` in command position (masked: never inside a string, comment
#     or heredoc body) whose word names core/fixtures/lib/<x>.sh -- `…/lib/<f>`, `"$(cd …/lib" && pwd)/<f>"`, or a
#     variable this file assigned a value containing `/lib/` (`MUT_LIB=…; . "$MUT_LIB"`) -- in any fixture .sh outside
#     core/fixtures/lib/. It is GUARDED, and quiet, when (a) the same statement continues `|| exit N`, `|| { … exit N;
#     }` with N > 0, or `|| broken …` where this file defines, ABOVE that line, a broken() that exits non-zero; or
#     (b) an EARLIER line tests the IDENTICAL word with `[ -f W ]`/`[ -r W ]` whose `||` branch exits that way (a test
#     line ending in `{`, `\`, `||` or `&&` is joined to the next), or `[ ! -f W ]` followed by such an exit within two
#     lines; or (c) an earlier `for V in <words>; do [ -f "PFX$V" ] || … exit N` names it as PFX<word>. `&& …`,
#     `|| true`, `|| exit 0`, `|| { …; exit 0; }`, a `broken` undefined or defined only BELOW the source (an unset
#     function is rc 127 and the script runs on), a test of a DIFFERENT path, and a test whose failing branch only
#     echoes all FIRE. Why: a source of a missing file sets $? and runs on,
#     so the fixture loses every arm that lib supplied and still exits 0 -- measured, held-stories without
#     lib/mutant.sh read rc 0 with ok 24 -> 19.
#     FP SET, how it reached zero. Population: 303 lib sources in 199 fixture .sh on the BL-925 tip; an independent
#     derivation (python, not this awk) lists the same 303 plus 2 lines inside fixture-hygiene's heredoc seeds, which
#     the masker correctly reads as data. First cut, on-line guards only: 113 hits, every one a pre-tested source
#     (form b) -- read as guarded by its author, and a change to the form would be churn; (b) was added keyed on the
#     IDENTICAL word, which keeps a test of `$HERE/lib.sh` from acquitting `. "$HERE/../lib/mutant.sh"` beside it.
#     Then 3 hits: fixture-inprocess:78 and fixture-invocation-budget:94 (form c, added) and
#     prepush-worktree-env-scrub:109 (a broken() whose `exit 2` sits on its fourth line; the definition window
#     widened to five lines). Final hits: 0, measured false positives: 0. On base 540b76ecb the arm flags 146
#     sources, the derivation's unguarded set row for row. A drop-one control (each lib file absent from a copied
#     tree) refuted an earlier 148: enforcement-map-derivations:91/:92 were already guarded by a two-line
#     `[ -f A ] && [ -f B ] || {` / `… exit 2; }`, which both scans missed the same way until (b) joined a test line
#     ending in `{`. A drop-one is the check that does not share the scan's grammar. STATED LIMITS: a lib path spelled through
#     a variable assigned in ANOTHER file, or built by concatenation across lines, is not a candidate; a loop body
#     sourcing `…/lib/$_l` is a candidate and is acquitted only by a pre-test of the identical word.
# H8  an UNSCRUBBED fixture (BL-929). Population: every tracked core/fixtures/<f>/run.sh (core/fixtures/lib excluded),
#     a shard stub mapped to its IMPL by the ONE resolver, `validate-fixture-invocations.sh --impl-of`:
#     the stub takes its IMPL's verdict, and its row says `via its IMPL`. A fixture is SCRUBBED when run.sh, or an
#     own-directory file run.sh sources in command position before anything else H8 counts, carries the env-derived
#     loop `for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done` on a code line, AND
#     that loop precedes, in run.sh, every command-position `.`/`source` other than lib/preamble.sh and every start of
#     a word ending `.sh` (in command position or as `bash`'s operand). The loop is LOCATED on the masked line, so a
#     comment, a string or a heredoc body never counts; its sed program is then READ off the unmasked line at the same
#     columns (a column-aligned read) and must be that exact program, so a GIT_ loop of the identical shape is no
#     scrub; and every quoted word of its body must be the loop variable. The body may span up to three more lines and
#     may exempt one AI_DLC_ name by `[ "$_v" = AI_DLC_X ] || unset "$_v"` (dist-clone:37's one-line form,
#     whole-read-pool:55-57's three-line form). A `\`-continued statement is joined and read once from its first line
#     (a line join), so a continued operand list is never command position.
#     A not-SCRUBBED fixture FAILs (`H8 <f>: …`, naming the start that came first, or that no loop exists) unless it is
#     a row of scripts/env-scrub-allowlist.txt, rows `<fixture>\t<reason>`, DOWN-ONLY by the shared m4 (arm H8-M4): a
#     row whose fixture reads SCRUBBED, or names no tracked run.sh, is H8STALE; a duplicate is H8DUP; a reasonless row
#     H8NOREASON; a row not on the list at origin/main FAILs H8-M4, with M4's two SKIPs. `--derive-h8` prints the
#     not-SCRUBBED set as rows, keeping a committed row's reason (keyed on field 1). A listed fixture that DRIVES A
#     HOOK FAILs anyway: I10's hook-driver grammar (a run.sh line naming `hooks/ai-dlc` or `$HOOK`; a lib.sh
#     non-comment line naming one once the glob form `hooks/ai-dlc-*` is removed) is carried here, so the list never
#     acquits a hook driver. Every SCRUBBED fixture prints one `H8 SCRUBBED <f>` row, so a receipt asserts presence.
#     H8 AND I10. I10 (scripts/validate-enforcement-map.sh) held hook drivers and acquitted any `unset "$_v"` or
#     `env -u AI_DLC`, so a loop over GIT_* alone passed it: hermetic-runner:118 and census-hermetic-coverage:131.
#     H8 deliberately does not accept a per-variable `env -u AI_DLC_X` as a scrub, because it clears one name and
#     not the class.
#     Measured on 316fdfe2f with the env-scrub cluster's 19 run.sh edits applied in a scratch copy: I10's population
#     is 62 fixtures, every one of them SCRUBBED under H8 (I10-population AND H8-unscrubbed: 0). Control, one seeded
#     world judged by I10's own extracted function and by H8: an unscrubbed `$HOOK` driver that is a row of the H8
#     list is flagged by I10 and by H8 (the hook clause), and a GIT_-only driver is acquitted by I10 and flagged by
#     H8. H8 holds I10's whole population and more, so I10 is RETIRED (BL-930); receipt-bl930.sh holds the two shapes.
#     FP SET, how it reached its value. Over the 125 fixtures ai-dlc-8f's census at 19239ff87 read as clearing (an
#     AI_DLC_* unset anywhere in the directory), on 316fdfe2f: 123 read SCRUBBED; the two that do not are true
#     positives -- agent-definition-render (`. "$MATRIX_SH"` at :96 precedes its scrub at :100; the cluster moves the
#     scrub) and story-evidence-scaffold (its scrub is in receipt-bl815.sh:33, a file run.sh RUNS rather than
#     sources, so run.sh is unscrubbed; allowlisted with that reason). Narrowings that got there: (a) the masked
#     line: a first cut read the `.sh`-start grammar off raw text and fired on the comment `# Usage: run.sh` at the
#     head of 62 fixtures and on MUTANT-MATRIX lines naming `x.sh` arms; a word whose first byte is masked is a
#     comment or a string and is skipped. (b) a not-SCRUBBED fixture is judged NOSCRUB outright, never by the order
#     rule, so its message names the real defect, not the first start. (c) continued lines: gate-adjudication-rotate
#     :35-36 (`GUARD="$(pick "$HERE/…/x.sh" \` / `"$HERE/…/x.sh" \`) and provenance-flagless-default:102 (`for cand
#     in "$ROOT/…/x.sh" \`) read as invocations to a per-line command-position test, because cmdpos() strips the
#     `GUARD=…` word and calls `pick`'s operand command position; the statement is joined and keyed on the SEGMENT
#     after the last delimiter, which must be empty or `bash` with flags. (d) the stub mapping: 19 shard stubs
#     carry no loop of their own; judged by their IMPL they read SCRUBBED wherever the IMPL does. Measured false
#     positives: 0. STATED LIMITS: a start spelled through a variable with no `.sh` (`"$SUBJECT"`), a script run
#     by `exec`-less helper the line grammar cannot see, and a scrub reached only through a variable-named source.
# H9  a BOUNDED real-time wait (BL-868: no fixture verdict or invocation count may depend on load): elapsed time or an
#     iteration bound can decide a verdict. An UNBOUNDED condition wait (`until cond; do sleep 0.1; done`, `while ! [
#     -e f ]; do sleep 0.05; done`) is allowed and reads 0. The scan is the BL-868 receipt's class W, carried over
#     (H9_AWK) but for one subtraction and one widening named below (the inert skip, the loop stack); that receipt's H3 delegation is not carried (H3 is this file's), nor its `±` decl class
#     (scripts/check-no-provisional-invocations.sh and J4 hold it).
#     Corpus: run_all's list, every tracked core/fixtures/**/*.sh (core/fixtures/lib is in), receipts included; H9
#     skips nothing (see THE POPULATION below).
#     Each line is masked by H9_AWK's own masker, not by THE MASKER above: single- and double-quoted bytes become X,
#     with the quote state carried across lines, and a comment is dropped. So sed mutant text, a JSON transcript seed
#     and a message are data. Two kinds of string are EXECUTED and are scanned as code: the body of a `-c '...'` (bash
#     -c, sh -c) and a printf string that writes a stub (`printf '#!...\n...'`, split on `\n`). A heredoc body is
#     scanned as code, line by line with its own quote state, when the heredoc WRITES A FILE (`cat > f <<'EOF'`, `tee
#     f`) or feeds a shell, because the fixtures write their executed stubs that way; a heredoc read into a variable
#     (`read -r -d '' X <<'E'`) or fed to another program is data.
#     The rows:
#       W-SLEEP   `sleep N` (or /bin/sleep, /usr/bin/sleep; N a literal above zero or a `$` value) OUTSIDE every loop:
#                 a fixed pause, a race delay or a hang target. `sleep "$@"` / `sleep "$*"` (a pass-through shim) is not.
#       W-CLOCK   `$SECONDS`, `${SECONDS}` or `SECONDS` inside `(( ))` on a line that COMPARES (-lt -le -gt -ge, or
#                 `<`/`>` in the arithmetic); or `date +%s` on a line that compares or opens a while/until loop. A start
#                 record (`s=$SECONDS`), a bare `SECONDS|` in a variable-name list, and `$(( $(date +%s) - 30 ))`
#                 assigned as a seeded timestamp compare nothing.
#       W-BOUND   a while/until loop that both increments a counter (`v=$((v + 1))`, `((v++))`, `((v+=1))`, `let v++`)
#                 and compares it (`$v -lt|-le|-gt|-ge|-eq`), in its header OR its body -- a header cap and an in-body
#                 watchdog (`[ "$idle" -ge 50 ] && break`) alike -- when a sleep runs directly inside it; and a `for`
#                 over a COUNTED list (`$(seq ...)`, `{1..N}`, literal numbers) with a sleep directly inside it. A `for`
#                 over a data list (`for s in $SCEN`) is iteration, not a bound. One row, at the loop header.
#       W-TIMEOUT `timeout N` (a literal or `$` value) in code, and `read -t` outside every loop, or inside one when its
#                 status or variable can decide anything: conditioned (if/while/until/elif, `!`, && or ||, `$( )`),
#                 its `$?` read on the next line, or its variable read anywhere in the file.
#       W-ALLOW-STALE  a row of the allowlist whose `# bl868-allow: <id>` marker is on no line of its path, or on
#                 several; and a `# bl868-allow: <id>` marker whose id no row names, or whose row names another file.
#     A sleep INSIDE a loop is that loop's poll quantum and is judged only through the loop header (W-BOUND, W-CLOCK);
#     so is an unchecked `read -t` whose variable nothing reads (a pause on a held fifo). A counter reset to an integer
#     at the START of the loop body (`ul=0; ...`) is a per-pass count, never an iteration bound.
#     THE ALLOWLIST scripts/bl868-wait-allowlist.txt, rows `<path>\t<id>\t<reason>`, one row per site, each keyed on a
#     trailing `# bl868-allow: <id>` comment on the allowed line, read from the resolved root (absent: empty, so a
#     probe root carries none of the tree's rows). A row suppresses the W rows of the ONE line carrying its id, never a
#     second copy; a marker whose id has no row, or whose row names another file, suppresses nothing and is itself
#     W-ALLOW-STALE, so stale fires in both directions (a row whose marker is gone, a marker whose row is gone or
#     misplaced); a marked line the scan no longer flags is a NOTE on stderr.
#     A malformed or duplicate row REFUSES (exit 2). WHY A FILE, NOT ROWS COMPILED IN: the receipt carried these rows
#     inline, and inline every probe root the fixture-hygiene fixture builds (its dirty and clean worlds, and the worlds
#     of receipt-bl929/930) read all 8 as W-ALLOW-STALE -- measured, 13 FAILs, `want exactly one FAIL section ...
#     got 2`. Read from the resolved root, a probe root carries none of the tree's rows. An ABSENT
#     file allows nothing: every marked site then FIRES as its W row and its marker as W-ALLOW-STALE, never acquitted;
#     the fixture's dirty world holds that (DW). The list has NO down-only M4 arm, as the receipt's inline list had
#     none: an added row needs a marker on the one line it names, which the stale join already demands.
#     STATED LIMITS: a sleep paced inside an unbounded while-loop body (`while read l; do x; sleep 1; done`) is not
#     seen; nor a counter compared only through arithmetic (`(( n > 50 ))`, `"$((n % 10))" -eq 0`); nor a bound held
#     in a helper function the loop calls; nor a stub written by a printf whose string does not start with `#!`, by
#     `echo`, or assembled in a variable; nor a wait in a file outside core/fixtures; nor a timeout reached through a
#     variable command name (`TO=timeout; $TO 30 cmd`), `gtimeout`, or an alarm in another language (`perl -e 'alarm
#     5'`). A file that ends inside a string is scanned as it stands (H9_AWK reports no lost quote state; THE MASKER's
#     BROKEN check covers the same corpus). A `sleep` whose argument is neither a literal nor a plain `$` reference
#     (`sleep $((RANDOM % 3 + 1))`) is not read as a sleep at all, and a C-style `for ((i = 0; i < 5; i++))` is never a
#     counted bound (W-BOUND reads `for v in <counted list>` and the counter forms above). ONE MARKER CLEARS ITS WHOLE
#     LINE: every W row on the marked line is dropped, whatever wait the reason was written for; and a marked line
#     that stops waiting only prints a NOTE, it never fails. A loop keyword or `done` that opens a LINE is always read
#     as code, so prose in a code-scanned heredoc that starts a line with `for`/`while`/`until`/`done` still opens or
#     closes a frame (a heredoc body keeps its own loop stack, so it never reaches a loop around the heredoc); a
#     `done` after a `)` is read as code; a `time` flag is read only in the `-x` form (`time --format=...` is not);
#     and a loop opened inside an executed `-c '...'` string lives on that string's own stack. `find -newer` and `-nt` are NOT rows: they compare mtimes and wait for
#     nothing, and the elapsed wait that once ordered those mtimes is a sleep, which W-SLEEP sees.
#     FP SET, how it reached its value. The receipt's narrowing, each step measured on its own tree and carried here
#     unchanged: masking (jq/JSON transcript seeds in foreground-budget-deny and check-25, sed mutant text in
#     readset-skip and advisor-gate-deny, the SECONDS variable-name lists in five shims: 0 rows); a sleep inside a loop
#     counted only through its header (the poll quanta of unbounded condition waits: 0 rows); the heredoc start read
#     off the masked line (a `<<` inside a quoted sed program had swallowed 2000 lines of gate-remediation-deny); a
#     `for` counted only over a numeric list; the per-pass reset and the unchecked-`read -t` pause (consumer-suite-pool).
#     ONE WIDENING, H9's own: the loop stack. As carried, a `done)` (`x="$(for a in b; do ...; done)"`) closed no
#     frame, and an unquoted `for`/`while`/`until` in prose (`echo waiting for the server`) opened one; either left a
#     frame open for the rest of the file, so every later top-level sleep and `read -t` read as a loop's poll and
#     raised no row. Measured over the 457 files: 15 ended with a frame open (dispatch-model-guard run.sh from :3232,
#     readset-skip from :7756, and 13 more). Now a `done` glued to `)`, `|`, `<`, `>` or `&` closes a frame (what
#     follows `done` on a masked code line in the corpus: end of line 2797, a blank 344, `;` 228, `)` 22, and after the
#     blank `<` 253, `|` 24, `>` 21; no glued `|<>&` today, admitted anyway), and a loop keyword opens one only in
#     command position: line start, or after `;`, `&`, `&&`, `|`, `||`, `(`, `$(`, `{`, a case arm's `)`, `!`, `do`,
#     `then`, `else` or `time`. After it: 0 files end with a frame open, and the rows are the same 8. ITS OWN FP SET:
#     3497 frame opens before, 3392 after, 0 new; the 105 lines that no longer open a frame were read, and every one is
#     prose in a code-scanned heredoc (seed ledgers, rule text), Python inside a `python3 -c '...'` body (a `for` in a
#     comprehension), sed program text, or a `grep -c` pattern -- none is a shell loop.
#     SECOND STEP, the same rule for `done`: a `done` in any position closed the
#     innermost frame, so once a skipped opener left its `done` behind (a backtick loop, `time -p for`) or prose said
#     `done` (`echo not done; true`, `echo $(echo done)`, `echo all done|cat`), the ENCLOSING bounded loop was popped
#     early and lost its W-BOUND. Now `done` closes only at line start or after `;`, `&`, `&&`, `|`, `||`, `{`, `)`,
#     `then` or `else`, a backtick glued to a loop keyword opens a frame, and `time` may carry `-x` flags. Measured
#     against the previous step's awk over the same 457 files: frame opens 3414 and 3414, closes 3357 and 3357, the
#     same 8 rows, 0 files ending open. Two closes MOVED, both correct: snapshot-update-stamps :710 and :750 read as
#     `for st in "..." done; do`, whose list word `done` had closed the frame it just opened; they now close at the real
#     `done` (:716, :755). A backtick admitted with blanks after it opened 3 prose lines of markdown in code-scanned
#     heredocs ("`x` for"), so only a GLUED backtick opens. Six seeds hold the step: bounded loops whose body carries a
#     backtick loop, a `time -p` loop, or a prose `done`, each of which must still raise W-BOUND.
#     The receipt's own measurement: 53 raw rows, 6 allowlisted, the rest open sites since fixed; two rows added later
#     (csp-barrier-cap, ppk-l1-control-child), 8 in all. THE POPULATION: the receipt skipped the receipts inert() read
#     as inert. H9 skips nothing, because that skip has no subject on a green tree: E1 fails every inert receipt not on
#     scripts/inert-receipt-allowlist.txt, and that list is header-only and down-only, so a passing tree holds no inert
#     receipt to skip (fixed by subtraction). At ee9376900 the one inert file was the BL-868 receipt itself, and it
#     carried 0 W rows when scanned (its 32 sleep lines are all data), so the skip never changed a row. Measured by
#     H9 on that tree: 458 listed and opened, 8 raw rows, every one on one of the 8 marked lines, 0 NOTEs, 0 stale
#     rows; the raw rows are byte-identical to the receipt's own. With the receipt deleted: 457 scanned, the same 8
#     rows. FALSE POSITIVES: 0; the 8 allowlisted sites are enumerated in scripts/bl868-wait-allowlist.txt, each with
#     its reason.
# H10 a run.sh code line (masked: never a comment, a string or a heredoc body) DEFINING `ok` or `bad`, in a fixture that
#     is not a `<fixture>:report` row of fixture-contract-allowlist.txt -> FAIL, naming the first such line.
#     The contract (.claude/rules/fixture-contract.md) reports through core/fixtures/lib/report.sh.
# H11 a run.sh code line whose command-position `bash` (the word unmasked at the column the raw line carries it) runs a
#     path ending `.githooks/pre-push` or `git-hooks/pre-push`, in a fixture that is not a `<fixture>:hook-drive` row
#     -> FAIL. A hook is run through hook_drive (core/fixtures/lib/hook-drive.sh); core/fixtures/lib is not scanned.
#     The list's own findings, both arms: a listed key that no longer offends, names no tracked run.sh, or names a
#     clause other than report/hook-drive is H10STALE; a duplicate is H10DUP; a reasonless row H10NOREASON; a row not
#     on the list at origin/main FAILs H10-M4 (the shared m4, M4's two SKIPs). `--derive-h10` prints the rows.
#     FP SET, how it reached its value: over the 275 run.sh at e00a0b111, H10 reads 235 fixtures and H11 5; every H11
#     line was read by hand and is a real hook run (agent-definition-render, consumer-suite-pool, prepush-worktree-
#     env-scrub, self-update-gate, suite-dispatch-order, the last migrated onto hook_drive in the change that adds the
#     arm). A raw-text grep also hits printf lines that WRITE a stub hook; the unmasked-`bash` column test drops them.
# H12 a fixture that carries a mutation battery. Population: every tracked core/fixtures/<f>/run.sh and
#     core/fixtures/<f>/lib.sh (core/fixtures/lib excluded). A file is an offender when it has, on a code line (masked:
#     never a comment, a string or a heredoc body), (a) any of the words mutant_killed, need_base, matrix_row, mkmut,
#     mut_copy, mutate_file (a call or a definition); (b) a line OPENING `# MUTANT-MATRIX` (also -FULL, -CONTROL,
#     -DYNAMIC, -REMEASURE), outside a heredoc body and a multi-line string; or (c) a command-position `.`/`source` of
#     a word naming lib/matrix.sh, spelled literally or through a variable this file assigned a value containing it.
#     (d) widens the population to every tracked core/fixtures/<f>/**.sh (core/fixtures/lib excluded): a code line
#     DEFINING a function whose name contains `mut` in any case (`name()` or `function name`), the builder every old
#     battery named (mut_new, mutate, *_mut, *_mutant, mk_mutant). No exemption: a seeded-input helper carries no `mut`
#     in its name. A battery with no named builder (an inline copy and sed) is outside every clause, and no clause
#     can take it: copying a shipped program and rewriting the copy is also how a fixture seeds an older engine, a
#     drifted copy the product must refuse, a removed seam or a stub. What separates a battery is what READS the
#     rewritten copy (the fixture's own predicate, or the product subject), not its shape.
#     One row per offending FILE, `H12 <file>: <reason>[, <reason>]`, each reason the first line of its kind; no
#     allowlist. A fixture proves a product feature with its own arms; none scores a battery of mutants per push.
# H13 a hand extraction of a hook span that binds the record homes (BL-1130). Population: every tracked
#     core/fixtures/<f>/**/*.sh (core/fixtures/lib excluded). The EMISSION site is a line whose command-position `sed`
#     or `awk` carries, inside a quoted word after it, `FIXTURE_POOL_BEGIN` or `RECORD_HOME_BEGIN` (FIXTURE_POOL holds
#     the RECORD_HOME span). A code line is read on its mask, where a string keeps its quotes and a comment is X to its
#     end; a heredoc body line (all X in the mask) is read raw, a `#` line excepted, so a driver script a fixture
#     writes is read too. A fixture with such a line that is not a row of scripts/pool-span-allowlist.txt -> FAIL,
#     naming its first line; the list's own findings are H13STALE (a listed fixture with no such line, or no tracked
#     run.sh), H13DUP and H13NOREASON, and a row not on the list at origin/main FAILs H13-M4 (the shared m4). The
#     remedy is pool_span (core/fixtures/lib/pool-span.sh), whose first line defaults the store to the sourcing
#     world's: a span sourced with no store of its own resolves its record homes in the real verdict store, so a
#     plain `bash core/fixtures/<f>/run.sh` files the world's records there under the world's root commit. A pool run
#     of a declared fixture never does: hermetic-run.sh runs it under `env -i ... HOME="$HR_WORK/home"`.
#     WHY THE EXTRACTION AND NOT THE SOURCE: a source reaches the extracted file through a reassigned variable, a
#     function parameter or a written driver, which no line grammar resolves. At 27fded102 a join of each `.`/`eval`
#     to a word the same file extracted into resolved 9 sources and none of the 8 prepush-pool-depth sites that gained
#     a store at that commit; the extraction is literal at every one of them.
#     FP SET, how it reached its value: at 27fded102 a raw grep of the two BEGIN markers over the population reads 24
#     lines; the one dropped is seed-verdict-store-red-print run.sh:332, `# FIXTURE_POOL_BEGIN` as a line of a stub
#     hook that a heredoc writes (a `#` line, and no sed or awk). The 23 left (20 code, 3 heredoc: fixture-invocation-
#     budget run.sh:204, suite-content-key run.sh:325 and :445) sit in 11 files of 10 fixtures, every one read by hand
#     and a real extraction. FALSE POSITIVES: 0. Proved by hand at authoring: a marker in a `#` comment, in an echo
#     string and in a trailing comment after a real sed stays quiet.
# H14 a hand `git init` (BL-1153): a fixture builds its git world through core/fixtures/lib/world.sh (`world_repo
#     <dir>` or `world_git init -q <dir>`). Population: every tracked core/fixtures/<f>/**/*.sh (core/fixtures/lib
#     excluded), H13's, so moving a line from run.sh into lib.sh does not escape the arm. The EMISSION site is a CODE
#     line read on the scan's mask (never a comment, a string or a heredoc body) matching the INIT_RE of the sibling
#     scripts/validate-fixture-git-env.sh: `git` with no name character or `-` before it, then only `-c`/`-C <word>`,
#     `--git-dir=`, `--work-tree=`, `--no-pager`, `-P` or `--bare`, then the whole word `init`. `world_git init` never
#     matches (the `_` before `git`). The scan emits one GI row per line; a fixture with one that is not a row of
#     world-adoption-allowlist.txt (repo root) -> FAIL, naming its first line as `<file>:<line>: <text>`. The list's
#     own findings are H14STALE (a listed fixture with no such line, or no tracked run.sh), H14DUP and H14NOREASON, and
#     a row not on the list at origin/main FAILs H14-M4 (the shared m4). `--derive-h14` prints the rows.
#     THE REMAINDER the grammar does not read, each re-derived at 619bfde94 by an uncommitted instrumented copy of this
#     scan (its controls: hits on the known `gitq -C … init` and `G init` lines): wrapper-function inits, a command-
#     position word other than git/world_git followed by `init`, 129 code lines in 29 fixtures, 19 of them with no
#     arm row (now READ by the wrapper clause below, BL-1162); variable-held git, 2 lines at 619bfde94 (`"$REAL_GIT" init`), now READ by the variable-held clause below and migrated; heredoc-body inits, 11 lines in fixture-invocation-budget,
#     prepush-worktree-env-scrub and shell-portability, each also an arm row through a code line, so no fixture is
#     heredoc-only (gate-remediation-deny seed.sh:212 and ledger-reverify-dist-only-reach run.sh:82 are CODE lines and
#     arm rows); script-string inits, 5 lines (fixture-git-env-seam run.sh:272/295/325, review-shard-merge
#     receipt-bl980.sh:114, shell-portability run.sh:433); `git clone` worlds, 27 code lines in 13 fixtures; `cp -R`/
#     `-r`/`-a` in command position, 311 lines in 82 fixtures, an upper bound (not each copies a git world). The
#     wrapper-rewrite escape: a hand init rewritten through a local wrapper (`g() { git "$@"; }; g init`) cleared H14.
#     COST, execs counted by a PATH-front logging shim over one check run of the real tree: 88 at 619bfde94, 97 with
#     H14 (its list cp, judge awk, sort, N14 grep, count awk, grep -c, grep -qE, and H14-M4's git rev-parse and cat-file
#     on the SKIP path); once origin/main carries the list, m4's git show, awk and sort make it 100. No new corpus pass.
#     FP SET, how it reached its value: at 619bfde94 the arm reads 259 lines in 100 fixtures. Its fixture set against
#     the sibling's INIT_RE population (git grep over core/fixtures/*/*.sh, raw, run.sh-bearing dirs: 102): arm-only 0
#     (no deeper or long-option-only hit outside it); INIT_RE-only 2, both string-only -- carried-findings (run.sh:310,
#     an echo "git init failed"; its init is the wrapper G) and review-shard-merge (receipt-bl980.sh:114, a script
#     string; its inits are G). Per line, the 29 raw INIT_RE lines of the population the arm does not read are 6
#     comments, 12 strings (7 messages, the 5 script strings above) and the 11 heredoc lines above. The text before
#     `git` on every arm line was classified, and each is a command-position git init (line start, after `&&`, `||`, `;`, `{`, `(`, `!`, `then`, or an
#     `env -u …`/NAME=value prefix). FALSE POSITIVES: 0. Proved by hand at authoring: `world_git init`, `world_repo`,
#     a `#` comment, an echo string, a heredoc body, `git log --grep=init`, `git commit -m init` and a wrapper defined
#     as `git -c init.defaultBranch=main "$@"` stay quiet; `git -C "$d" -c init.defaultBranch=main init -q` in a lib.sh
#     FAILs.
#     THE WRAPPER CLAUSE (BL-1162; `wr14` in the scan, the WD/WU join in the judge): a WRAPPER is a function defined in
#     the fixture's own .sh population (`name() {` or `function name`, any indentation, one-line, multi-line or nested
#     body, tracked by brace depth) whose body has a command-position `git` (line start, after `;` `&` `|` `(` `{` `!`
#     `then`/`do`/`else`, past `command`/`exec`/`env`/`-u X`/NAME=value prefixes); `world_git` never counts (the `_`
#     before `git`). A HIT is a code line (masked: no comment, string or heredoc body) whose command-position word
#     (after an `if`/`elif`/`while`/`until`/`then`/`do`/`else`/`!` run) is a wrapper DEFINED IN THE SAME FIXTURE
#     (any of its files), followed by an option run (`-C <w>`, `-c <k=v>`, `--git-dir=`, `--work-tree=`, `--no-pager`,
#     `-P`, `--bare`, `-q`) and/or up to two dir-first words, then the whole word `init`; one count per line, the
#     fixture's first such line is its H14 row. Keywords, builtins and undefined words are excluded by requiring the
#     definition; core/fixtures/lib is out of the population, so a wrapper defined only there is read by no fixture.
#     NAMED BLIND ROUTES (the entry stays open): variable-held git INSIDE A WRAPPER BODY (a body of only `"$REAL_GIT"` is
#     no wrapper), a wrapper body that is a subshell (`g() ( git "$@" )`), a wrapper whose body reaches git only after `if`/`elif`/`while`/`until`/`time` (`g() { if git "$@"; then :; fi; }`), a wrapper that
#     reaches git only through another wrapper, an alias, `eval`, and a wrapper call whose option run is longer than
#     the grammar. At 747f89054 the clause reads 133 code lines in 30 fixtures (the census hand's figure; the entry's
#     129/29 was taken at 619bfde94), 19 fixtures with no allowlist row, 11 listed; controls: 31 `gitq ... init` in
#     procsub-staged-refusal, 20 `G init` (review-shard-merge 16, carried-findings 4). FP SET: 0. Every one of the 133
#     lines was read: 11 listed fixtures by hand, 19 as the migration targets. How it reached 0 (the misses, not
#     false hits, were the error): a first definition closure on `}` read 124 lines in 27 fixtures (an indented
#     definition lost its name, and a definition nested in an open function was never read); the brace-depth stack
#     reads all 133. Proved by hand at authoring: `g(){ git "$@"; }; g -C "$d" init`, a nested
#     `f() { if ...; then g -c a=b --no-pager init -q "$1" "$2"; fi; }`, a `function g {` multi-line, a cross-file
#     definition (lib.sh) and a `g` after a `#` line carrying `<<EOT` (no phantom heredoc) FIRE; `g(){ world_git "$@"; }`,
#     `echo "g init"`, `echo init`, `# g init`, a heredoc body, an undefined `ok init`, a `"$REAL_GIT"` body and a wrapper
#     defined only in core/fixtures/lib stay quiet. COST: no exec added (the scan awk and the judge awk already run).
#     THE VARIABLE-HELD CLAUSE (BL-1162; `vg14`, read inside gi14): a COMMAND-POSITION word (after `;` `&` `|` `(` `{` `!`,
#     `then`/`do`/`else`, an `if`/`while`/... run, and `command`/`exec`/`env`/`-u X`/NAME=value prefixes) that is `"$VAR"`,
#     `$VAR`, `${VAR}`, `"git"` or ends in `/git`, then the gi14 option run, then `init`. THE MASK TRAP: maskcode turns
#     `"$REAL_GIT"` into `"XXXXXXXXX"`, so command position is found on M[i] and the word is read from O[i] at the same
#     offset (the mask is length-preserving). FP SET, how it reached 0: the command-position anchor; a loose `$VAR" init`
#     form hits about 77 files through `git -C "$d" init`. Measured with the shipping validator at 5026369ed: H14 lines
#     285 -> 287, the two added are exactly fanout-payload-channel run.sh:182 and fanout-untracked-corpus run.sh:121
#     (control: the literal-git grammar reads 278 in the same population). Mutant: reading the word from M[i] instead of
#     O[i] drops both rows. Both fixtures adopted world_git in the same commit (H14-M4 refuses an added row).
#
# ON THE BRANCH THAT SHIPS THIS, H2 AND H3 ARE RED BY DESIGN: their offenders sit in fixtures other units are
# rewriting, and H1-H3 carry NO allowlist (H1's one offender is fixed on that branch). The owner fixes them on the
# integrated tip, where this list is also re-derived.
#
# COST: a constant number of forks -- one git ls-files, one resolver call, one awk scan (two passes over the corpus),
# one judge awk, sorts. E1 adds one e1_run pass over the tree: a git ls-files, the inert() awk and the judge awk.
# H9 adds one H9_AWK pass over the corpus, its join awk and sorts, and reuses run_all's list. H13 reads inside the
# scan awk's existing pass and adds its judge awk, one sort and one grep; its H13-M4 is the shared m4. H14 likewise
# (its own COST line above).
set -uo pipefail

MODE=check
case "${1:-}" in
  "") ;;
  --derive-h8) MODE=derive8 ;;
  --derive-h10) MODE=derive10 ;;
  --derive-h14) MODE=derive14 ;;
  *) echo "usage: validate-fixture-hygiene.sh [--derive-h8 | --derive-h10 | --derive-h14]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-fixture-hygiene: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2; exit 2
fi
RESOLVER="$HERE/validate-fixture-invocations.sh"
[ -f "$RESOLVER" ] || { echo "validate-fixture-hygiene: FAIL -- the shard-stub resolver $RESOLVER is absent" >&2; exit 2; }
E1_ALLOW_REL="scripts/inert-receipt-allowlist.txt"
H8_ALLOW_REL="scripts/env-scrub-allowlist.txt"
H10_ALLOW_REL="fixture-contract-allowlist.txt"
H9_ALLOW_REL="scripts/bl868-wait-allowlist.txt"
H13_ALLOW_REL="scripts/pool-span-allowlist.txt"
H14_ALLOW_REL="world-adoption-allowlist.txt"

WORK="$(mktemp -d)" || { echo "validate-fixture-hygiene: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# --- the scan ------------------------------------------------------------------------------------------------------
read -r -d '' SCAN_AWK <<'AWK'
BEGIN { XS = "XXXXXXXXXXXXXXXX"; SQ = sprintf("%c", 39); PROG8 = "s/^\\(AI_DLC_[A-Za-z0-9_]*\\)=.*/\\1/p"; EXITRE = "(^|[^A-Za-z0-9_$.-])exit([[:space:]]+0)?[[:space:]]*($|[;})&|\n])" }
function relof(p) { return substr(p, 1, length(ROOTP)) == ROOTP ? substr(p, length(ROOTP) + 1) : p }
function fxof(r,   a, n) { n = split(r, a, "/"); return (n >= 4 && a[1] == "core" && a[2] == "fixtures") ? a[3] : "" }
function pop() { STK = substr(STK, 1, length(STK) - 1) }
function maskcode(s,   out, i, n, c, top, r, re) {
  # Fast path: in code, a line with no quote, backtick, comment or escape character is its own mask.
  if (STK == "c" && s !~ /["`#\\]/ && index(s, SQ) == 0) return s
  out = ""; n = length(s)
  if (XS == "") XS = "XXXXXXXXXXXXXXXX"
  while (length(XS) < n) XS = XS XS
  for (i = 1; i <= n; i++) {
    top = substr(STK, length(STK), 1)
    # Copy (code) or mask (string) the run up to the next character this state treats specially, in one step.
    r = substr(s, i)
    if (top == "s") re = SQ; else if (top == "a") re = "[\\\\" SQ "]"; else if (top == "d") re = "[\\\\\"$]"; else re = "[\\\\#\"`()" SQ "]"
    if (!match(r, re)) { out = out ((top == "s" || top == "a" || top == "d") ? substr(XS, 1, length(r)) : r); break }
    if (RSTART > 1) { out = out ((top == "s" || top == "a" || top == "d") ? substr(XS, 1, RSTART - 1) : substr(r, 1, RSTART - 1)); i += RSTART - 1 }
    c = substr(s, i, 1)
    if (top == "s") { if (c == SQ) { pop(); out = out c } else out = out "X"; continue }
    if (top == "a") {
      if (c == "\\") { out = out "X"; if (i < n) { out = out "X"; i++ } continue }
      if (c == SQ) { pop(); out = out c } else out = out "X"; continue
    }
    if (top == "d") {
      if (c == "\\") { out = out "X"; if (i < n) { out = out "X"; i++ } continue }
      if (c == "\"") { pop(); out = out c; continue }
      if (c == "$" && substr(s, i + 1, 1) == "(") { STK = STK "p"; DP[length(STK)] = 0; out = out "$("; i++; continue }
      out = out "X"; continue
    }
    if (c == "\\") { out = out c; if (i < n) { out = out substr(s, i + 1, 1); i++ } continue }
    if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[[:space:];&|]/)) { out = out substr(XS, 1, n - i + 1); break }
    if (c == SQ) { STK = STK (i > 1 && substr(s, i - 1, 1) == "$" ? "a" : "s"); out = out c; continue }
    if (c == "\"") { STK = STK "d"; out = out c; continue }
    if (top == "p") {
      if (c == "(") DP[length(STK)]++
      else if (c == ")") { if (DP[length(STK)] == 0) { pop(); out = out c; continue } DP[length(STK)]-- }
    }
    if (c == "`") { if (top == "b") pop(); else STK = STK "b"; out = out c; continue }
    out = out c
  }
  return out
}
function maskl(s,   m, t, p, n, dash, q, c, w, e) {
  INHD = 0
  if (HDN > 0) {
    INHD = 1; t = s; if (HDD[HDI]) sub(/^\t+/, "", t)
    if (t == HDW[HDI]) { HDI++; if (HDI > HDN) { HDN = 0; HDI = 0 } }
    while (length(XS) < length(s)) XS = XS XS
    return substr(XS, 1, length(s))
  }
  m = maskcode(s); n = length(m)
  if (index(m, "<<") == 0) return m
  for (p = 1; p < n; p++) {
    e = index(substr(m, p), "<<"); if (!e) break
    p += e - 1
    if (substr(m, p + 2, 1) == "<") { p += 2; continue }
    dash = (substr(m, p + 2, 1) == "-"); q = p + 2 + dash
    while (substr(s, q, 1) ~ /[[:space:]]/) q++
    c = substr(s, q, 1); w = ""
    if (c == SQ || c == "\"") { e = index(substr(s, q + 1), c); if (e) w = substr(s, q + 1, e - 1) }
    else { if (c == "\\") q++; if (match(substr(s, q), /^[A-Za-z_][A-Za-z0-9_]*/)) w = substr(s, q, RLENGTH) }
    if (w != "") { HDN++; HDW[HDN] = w; HDD[HDN] = dash; HDI = 1 }
    p = q
  }
  return m
}
function wordat(str, p,   w, c, q) {
  w = ""
  while (p <= length(str)) {
    c = substr(str, p, 1)
    if (c ~ /[[:space:];&|<>()]/) break
    if (c == "\"" || c == SQ) {
      q = index(substr(str, p + 1), c)
      if (!q) { w = w substr(str, p); p = length(str) + 1; break }
      w = w substr(str, p, q + 1); p += q + 1; continue
    }
    if (c == "\\") { w = w substr(str, p, 2); p += 2; continue }
    w = w c; p++
  }
  WEND = p; return w
}
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
function ifctx(pre,   r, lastif, lastthen) {
  r = pre; lastif = 0; lastthen = 0
  while (match(r, /(^|[;&|[:space:]])(el)?if[[:space:]]/)) { lastif += RSTART + RLENGTH - 1; r = substr(r, RSTART + RLENGTH) }
  r = pre
  while (match(r, /(^|[;&|[:space:]])then([;&|[:space:]]|$)/)) { lastthen += RSTART + RLENGTH - 1; r = substr(r, RSTART + RLENGTH) }
  return lastif > 0 && lastif > lastthen
}
function grab(rest, j, open,   cl, d, k, c, body) {
  cl = (open == "{") ? "}" : ")"; d = 0; k = 0; body = ""
  while (1) {
    k++
    if (k > length(rest)) { if (j >= NL || j - GI > 400) return body; j++; rest = rest "\n" M[j]; k--; continue }
    c = substr(rest, k, 1)
    if (c == open) d++
    else if (c == cl) { d--; if (d == 0) return body }
    body = body c
  }
}
# stripc: drop a trailing MASKED comment from every line of a branch body. The masker turns `# ...` into X through
# the end of its line, so `exit 0 # why` reads `exit 0 XXXXX`, which EXITRE cannot match. A run of X after a blank
# (or filling the line) to its end is a comment: a masked string keeps its quote characters, so it never ends in X.
function stripc(b,   a, n, k, r) {
  n = split(b, a, "\n"); r = ""
  for (k = 1; k <= n; k++) { sub(/(^|[[:space:]])X+$/, "", a[k]); r = r (k > 1 ? "\n" : "") a[k] }
  return r
}
function branch_stmt(i, q, neg,   s, j, op, k, pre, rest, c, body) {
  s = substr(M[i], q); j = i; GI = i
  while (s ~ /(\\|\|\||&&)[[:space:]]*$/ && j < NL) { j++; s = s "\n" M[j] }
  op = neg ? "&&" : "||"
  k = index(s, op); if (!k) return 0
  pre = substr(s, 1, k - 1); if (pre ~ /;/) return 0
  rest = substr(s, k + 2); sub(/^[[:space:]\\]+/, "", rest)
  c = substr(rest, 1, 1)
  if (c == "{" || c == "(") body = grab(rest, j, c)
  else { body = rest; sub(/(;|&&|\|\||\||\n).*/, "", body) }
  return stripc(body) ~ EXITRE
}
function branch_if(i, p, neg,   s, j, pos, depth, phase, bstart, kw, ks, ke, r, tb, eb) {
  s = substr(M[i], p); j = i; pos = 1; depth = 0; phase = "cond"; tb = ""; eb = ""
  while (1) {
    r = substr(s, pos)
    if (!match(r, /(^|[;&|[:space:](])(if|then|elif|else|fi)([;&|[:space:])]|$)/)) {
      if (j >= NL || j - i > 400) break
      j++; s = s "\n" M[j]; continue
    }
    ks = pos + RSTART - 1; kw = substr(r, RSTART, RLENGTH)
    if (kw ~ /^[;&|[:space:](]/) { ks++; kw = substr(kw, 2) }
    sub(/[;&|[:space:])]$/, "", kw); ke = ks + length(kw)
    if (kw == "if") depth++
    else if (kw == "fi") {
      if (depth == 0) { if (phase == "then") tb = substr(s, bstart, ks - bstart); else if (phase == "else") eb = substr(s, bstart, ks - bstart); break }
      depth--
    } else if (depth == 0) {
      if (kw == "then" && phase == "cond") { phase = "then"; bstart = ke }
      else if ((kw == "else" || kw == "elif") && phase == "then") { tb = substr(s, bstart, ks - bstart); phase = "else"; bstart = ke }
    }
    pos = ke
  }
  return stripc(neg ? tb : eb) ~ EXITRE
}
function fails_to_exit0(i, st, qe, neg, pre0) {
  return ifctx(pre0) ? branch_if(i, st, neg) : branch_stmt(i, qe, neg)
}
function loadtools(fx,   f, l) {
  split("", TOOLS); if (fx == "") return
  f = ROOTP "core/fixtures/" fx "/tools.decl"
  while ((getline l < f) > 0) { sub(/\r$/, "", l); if (l ~ /^[[:space:]]*(#|$)/) continue; l = trim(l); sub(/^\?/, "", l); TOOLS[l] = 1 }
  close(f)
}
# --- H3's stub join: a visible write of a `#!/bin/sh` file joined to an execution that honours the shebang ---------
function shebang_sh(t) { return t ~ /#!(\/bin\/sh|\/usr\/bin\/env[[:space:]]+sh)([^A-Za-z0-9_.\/-]|$)/ }
# cmdpos: is a word starting right after <pre> (a MASKED prefix) in command position? Glued to the previous byte it
# is only after an operator (`X="$P"` is an assignment); after a blank, `VAR=val` / `-i` words are stripped first.
function cmdpos(pre,   pe) {
  if (pre != "" && pre !~ /[[:space:]]$/) return pre ~ /[;&|(`{!]$/
  sub(/[[:space:]]+$/, "", pre); pe = pre
  while (sub(/(^|[[:space:]]+)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|-i)$/, "", pe)) ;
  return pe == "" || pe ~ /[;&|(`{!]$/ || pe ~ /(^|[^A-Za-z0-9_])(then|do|else|if|elif|while|until|exec|time|nohup|command|env)$/
}
# redir: the target word of the first code `>`/`>>` redirection that names a file (never `N>`, `>&N`, `&>`, /dev/*).
function redir(m, o,   p, k, q, w) {
  p = 0
  while ((k = index(substr(m, p + 1), ">")) > 0) {
    p += k; q = p + 1
    if (p > 1 && substr(m, p - 1, 1) ~ /[0-9&>]/) continue
    if (substr(m, q, 1) == ">") q++
    if (substr(m, q, 1) == "&") continue
    while (substr(o, q, 1) ~ /[[:space:]]/) q++
    w = wordat(o, q); gsub(/["\047]/, "", w)
    if (w == "" || w ~ /^\/dev\// || w ~ /\$\(/) continue
    return w
  }
  return ""
}
# stubexec <P> <dir> <write line>: the first line executing P by path (direct or exec) or putting <dir> on PATH.
# The search runs FORWARD from the write first, then from the top, so the execution reported is the nearest later one.
function stubexec(pn, dir, wl,   x) {
  LOOK = 0; x = stubexec1(pn, dir, wl, 0); if (x) return x
  x = stubexec1(pn, dir, wl, 1); if (x) LOOK = 1; return x
}
# lookup: a line whose PATH= feeds only a name lookup (`command -v`, `type`, `which`) -- the stub is placed on PATH
# but not run there; it is reported (the placement is the intent) only when no line runs it, and labelled a lookup.
function lookup(o) { return o ~ /(command[[:space:]]+-v|(^|[^A-Za-z0-9_-])(type|which))[[:space:]]/ }
function stubexec1(pn, dir, wl, look,   j, jj, off, k, st, a, n, x, v, pv, r) {
  for (jj = 1; jj <= NL; jj++) {
    j = wl + jj; if (j > NL) j -= NL
    if (j == wl || HDL[j]) continue
    off = 0
    while ((k = index(substr(O[j], off + 1), pn)) > 0) {
      st = off + k; off = st
      a = substr(O[j], st + length(pn), 1)
      if (a != "" && a !~ /[[:space:]"\047;)&|<>`]/) continue
      if (substr(O[j], st - 1, 1) == "\"") st--
      if (substr(M[j], st, 1) == "X") continue
      # a `\`-continued previous line makes this one an argument list, never a command position
      if (substr(M[j], 1, st - 1) ~ /^[[:space:]]*$/ && j > 1 && !HDL[j - 1] && M[j - 1] ~ /\\$/) continue
      if (cmdpos(substr(M[j], 1, st - 1))) return j
    }
    # PATH= read off the UNMASKED line: `env "PATH=$D:$PATH"` and `he_run_env "PATH=…"` carry it inside quotes.
    if (dir != "" && lookup(O[j]) == look) { r = O[j]; while (match(r, /(^|[^A-Za-z0-9_])PATH=/)) {
      v = wordat(r, RSTART + RLENGTH); r = substr(r, RSTART + RLENGTH)
      gsub(/["\047]/, "", v); gsub(/\$\{[A-Za-z0-9_]+:-/, "", v); gsub(/\$\{/, "$", v); gsub(/\}/, "", v)
      n = split(v, pv, ":"); for (x = 1; x <= n; x++) if (pv[x] == dir) return j
    } }
  }
  return 0
}
function stubjoin(   i, m, o, j, pn, dir, x) {
  for (i = 1; i <= NL; i++) {
    if (HDL[i]) continue
    pn = ""
    if (i < NL && HDL[i + 1] && index(M[i], "<<") && O[i + 1] ~ /^[[:space:]]*#!/ && shebang_sh(O[i + 1])) pn = redir(M[i], O[i])
    else if (shebang_sh(O[i]) && M[i] ~ /(^|[^A-Za-z0-9_])(printf|echo)([[:space:]]|$)/) {
      m = M[i]; o = O[i]; j = i
      while (m ~ /\\$/ && j < NL && !HDL[j + 1]) { j++; m = m " " M[j]; o = o " " O[j] }
      pn = redir(m, o)
    }
    if (pn == "") continue
    gsub(/\$\{/, "$", pn); gsub(/\}/, "", pn)
    dir = pn; if (sub(/\/[^\/]*$/, "", dir) == 0) dir = ""
    x = stubexec(pn, dir, i)
    if (x) print "H3\t" REL ":" i "\ta #!/bin/sh stub " pn " written here is " (LOOK ? "placed on PATH for a lookup" : "executed") " at :" x ": " trim(O[x])
  }
}
# --- H6: a source of core/fixtures/lib/<x>.sh with no failure guard ---------------------------------------------
# wend6 <masked line> <start>: the end (exclusive) of the shell word starting at <start>, across `$( )` and quotes.
function wend6(s, p,   d, dq, c) {
  d = 0; dq = 0
  for (; p <= length(s); p++) {
    c = substr(s, p, 1)
    if (c == "\\") { p++; continue }
    if (c == "\"") { dq = !dq; continue }
    if (c == "(") { d++; continue }
    if (c == ")") { if (d > 0) d--; continue }
    if (!dq && d == 0 && c ~ /[[:space:];&|<>]/) break
  }
  return p
}
# a word naming the shared lib: `…/lib/<f>`, `…/lib" && pwd)/<f>`, or a variable this file assigned a lib path.
function libref6(w,   n) {
  if (w ~ /(\/|^"?)lib(\/|"[^"]*\)\/)/) return 1
  if (match(w, /^"?\$\{?[A-Za-z_][A-Za-z0-9_]*/)) { n = substr(w, RSTART, RLENGTH); sub(/^"?\$\{?/, "", n); return (n in LV6) }
  return 0
}
# exits6 <text after `||`>: the branch exits non-zero (`exit N`, a `{ … exit N; }` group, or a defined broken()).
function exits6(t) {
  if (t ~ /^[[:space:]]*(\{[^}]*[^A-Za-z0-9_])?exit[[:space:]]+[1-9]/) return 1
  return HB6 && HB6 < AT6 && t ~ /^[[:space:]]*(\{[^}]*[^A-Za-z0-9_])?broken([[:space:]]|$)/
}
function prep6(   i, s, m, nm, v, q, w, t, neg, n, k, x, a6) {
  split("", LV6); split("", FT6); HB6 = 0
  for (i = 1; i <= NL; i++) {
    if (HDL[i]) continue
    s = M[i]
    if (!HB6 && s ~ /(^|[[:space:];&|({])broken[[:space:]]*\(\)/ && (s " " M[i + 1] " " M[i + 2] " " M[i + 3] " " M[i + 4]) ~ /exit[[:space:]]+[1-9]/) HB6 = i
    if (match(s, /^[[:space:]]*(export[[:space:]]+|local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
      nm = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*(export[[:space:]]+|local[[:space:]]+)?/, "", nm); sub(/=$/, "", nm)
      v = substr(O[i], RSTART + RLENGTH); if (v ~ /(\/|^"?)lib(\/|"|$)/) LV6[nm] = 1
    }
  }
  # a preceding `[ -f W ]` / `[ ! -f W ]` whose failing branch exits non-zero guards a later source of W
  for (i = 1; i <= NL; i++) {
    if (HDL[i]) continue
    s = M[i]; m = 0
    # `for V in <words>; do [ -f "PFX$V" ] || … exit N` within three lines: every listed word is tested as PFX<word>
    if (match(O[i], /^[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+/)) {
      nm = O[i]; sub(/^[[:space:]]*for[[:space:]]+/, "", nm); sub(/[[:space:]].*/, "", nm)
      v = substr(O[i], RSTART + RLENGTH); t = v; sub(/;[[:space:]]*do([[:space:]].*)?$/, "", v)
      t = O[i] " " O[i + 1] " " O[i + 2]
      if (match(t, "\\[[[:space:]]+-f[[:space:]]+\"[^\"]*\\$\\{?" nm "\\}?\"[[:space:]]*\\][[:space:]]*\\|\\|")) {
        w = substr(t, RSTART, RLENGTH); q = substr(t, RSTART + RLENGTH)
        if (exits6(q)) {
          sub(/^\[[[:space:]]+-f[[:space:]]+"/, "", w); sub(/\$\{?[A-Za-z_][A-Za-z0-9_]*\}?".*$/, "", w)
          n = split(v, a6, /[[:space:]]+/)
          for (k = 1; k <= n; k++) { x = a6[k]; gsub(/["\047]/, "", x); if (x != "" && !((w x) in FT6)) FT6[w x] = i }
        }
      }
    }
    while (match(substr(s, m + 1), /(^|[[:space:]])-[fr][[:space:]]+/)) {
      q = m + RSTART + RLENGTH; m = q - 1
      w = wordat(O[i], q); gsub(/["\047]/, "", w); if (w == "") continue
      neg = (substr(s, 1, q - 1) ~ /![[:space:]]+-[fr][[:space:]]+$/)
      t = substr(s, WEND); if (t ~ /(\\|&&|\|\||\{)[[:space:]]*$/ && i < NL) t = t " " M[i + 1]
      AT6 = i
      if ((match(t, /\|\|/) && substr(t, 1, RSTART - 1) !~ /;/ && exits6(substr(t, RSTART + 2))) \
          || (neg && (s " " M[i + 1] " " M[i + 2]) ~ /(^|[^A-Za-z0-9_])exit[[:space:]]+[1-9]/)) { if (!(w in FT6)) FT6[w] = i }
    }
  }
}
function h6(i,   s, off, st, q, e, w, wn, t) {
  s = M[i]; off = 0
  while (match(substr(s, off + 1), /(^[[:space:]]*|[;&|({!][[:space:]]*|(^|[[:space:]])(then|do|else)[[:space:]]+)(\.|source)[[:space:]]+/)) {
    q = off + RSTART + RLENGTH; e = wend6(s, q); off = e - 1
    w = substr(O[i], q, e - q); if (!libref6(w)) continue
    T6++; AT6 = i
    t = substr(s, e); if (t ~ /(\\|\{)[[:space:]]*$/ && i < NL) t = t " " M[i + 1]
    if (match(t, /\|\|/) && substr(t, 1, RSTART - 1) !~ /;|&&/ && exits6(substr(t, RSTART + 2))) continue
    wn = w; gsub(/["\047]/, "", wn); if ((wn in FT6) && FT6[wn] < i) continue
    print "H6\t" REL ":" i "\t" trim(O[i])
  }
}
# --- H8: the env-derived AI_DLC_* unset loop, and what a run.sh starts before it ---------------------------------
# scrub8 <line>: `S8 <fx> <rel> <line>` when the line opens the loop. LOCATED on the masked line, where a comment, a
# string and a heredoc body are X, so none of them can match; the sed program and the body's quoted words are then
# READ off the unmasked line at the same columns (a column-aligned read). The program must be exactly PROG8, so a
# GIT_ loop of the identical shape is no scrub, and every quoted word of the body must be the loop variable. The
# body may be one line (`do unset "$_v"; done`) or span up to three more (`do` / `[ "$_v" = AI_DLC_X ] || unset
# "$_v"` / `done`), and may exempt one AI_DLC_ name by that `[ … ] ||` test.
function scrub8(i,   s, o, j, v, q, e, cq, prog, rm, ro, re, rb) {
  o = O[i]; s = M[i]
  if (!match(s, /(^|[;&|({[:space:]])for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+\$\([[:space:]]*env[[:space:]]*\|[[:space:]]*sed[[:space:]]+-n[[:space:]]+["\047][^"\047]*["\047][[:space:]]*\)[[:space:]]*;?[[:space:]]*do([[:space:]]|$)/)) return
  e = RSTART + RLENGTH; q = RSTART
  v = substr(s, RSTART, RLENGTH); sub(/^[;&|({[:space:]]*for[[:space:]]+/, "", v); sub(/[[:space:]].*$/, "", v)
  match(substr(s, q), /sed[[:space:]]+-n[[:space:]]+["\047]/); q += RSTART + RLENGTH - 1
  cq = substr(s, q - 1, 1); prog = substr(o, q, index(substr(s, q), cq) - 1)
  if (prog != PROG8) return
  rm = substr(s, e); ro = substr(o, e); j = i
  while (rm !~ /(^|[;[:space:]])done([;&|)[:space:]]|$)/ && j < NL && j < i + 3) { j++; rm = rm " ; " M[j]; ro = ro " ; " O[j] }
  re = "^[[:space:];]*(\\[[[:space:]]+\"[^\"]*\"[[:space:]]+=[[:space:]]+AI_DLC_[A-Za-z0-9_]+[[:space:]]+\\][[:space:]]*\\|\\|[[:space:]]*)?unset[[:space:]]+\"[^\"]*\"[[:space:]]*;[[:space:]]*done([;&|)[:space:]]|$)"
  if (!match(rm, re)) return
  rb = substr(ro, 1, RLENGTH); gsub("\"\\$\\{?" v "\\}?\"", "\"\"", rb)
  if (rb !~ "^[[:space:];]*(\\[[[:space:]]+\"\"[[:space:]]+=[[:space:]]+AI_DLC_[A-Za-z0-9_]+[[:space:]]+\\][[:space:]]*\\|\\|[[:space:]]*)?unset[[:space:]]+\"\"[[:space:]]*;[[:space:]]*done") return
  print "S8\t" FX "\t" REL "\t" i; if (ISRUN) SEEN8 = 1
}
# ev8 <line>, run.sh only: every command-position `.`/`source` other than lib/preamble.sh (`E8 <fx> <line> src
# <basename when it names a file of this fixture's own directory>`), and every start of a word ending `.sh`, in
# command position or as `bash`'s operand (`E8 <fx> <line> run`). A `\`-continued statement is read ONCE, joined from
# its first line (a line join), so a continued operand list (`pick a \` / `  b/x.sh`, `for c in a.sh \` / `b.sh`) is
# never command position. The word is found by walking back from `.sh` over non-delimiters of the MASKED line (a
# string is one run of X), so `echo "x.sh"` and `[ -f "$H/x.sh" ]` put it in argument position, never command.
function ev8(i,   s, o, j, off, q, e, w, b, k, p, pre, pb) {
  if (i > 1 && !HDL[i - 1] && M[i - 1] ~ /\\$/) return
  s = M[i]; o = O[i]; j = i
  while (s ~ /\\$/ && j < NL && !HDL[j + 1]) { j++; s = substr(s, 1, length(s) - 1) " " M[j]; o = substr(o, 1, length(o) - 1) " " O[j] }
  off = 0
  while (match(substr(s, off + 1), /(^[[:space:]]*|[;&|({!][[:space:]]*|(^|[[:space:]])(then|do|else)[[:space:]]+)(\.|source)[[:space:]]+/)) {
    q = off + RSTART + RLENGTH; e = wend6(s, q); off = e - 1
    w = substr(o, q, e - q); gsub(/["\047]/, "", w)
    if (w ~ /preamble\.sh$/ && w ~ /lib/) continue
    b = ""; if (w !~ /\.\./ && match(w, /\/[^\/]+$/)) b = substr(w, RSTART + 1)
    print "E8\t" FX "\t" i "\tsrc\t" b "\t" trim(O[i])
  }
  k = 0
  while ((p = index(substr(o, k + 1), ".sh")) > 0) {
    k += p
    if (substr(o, k + 3, 1) ~ /[A-Za-z0-9_]/) continue
    p = k; while (p > 1 && substr(s, p - 1, 1) !~ /[[:space:];&|()<>`]/) p--
    # a word whose first byte is masked is a comment, or the middle of a string: a quoted word keeps its quote
    if (substr(s, p, 1) == "X") continue
    e = wend6(s, p); if (e <= k + 2) continue
    w = substr(o, p, e - p); gsub(/["\047]/, "", w)
    if (w !~ /\.sh$/ || w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    pre = substr(s, 1, p - 1)
    if (pre != "" && pre !~ /[[:space:]]$/ && pre !~ /[;&|(`{!]$/) continue
    if (cmdseg8(pre)) print "E8\t" FX "\t" i "\trun\t\t" trim(O[i])
  }
}
# cmdseg8 <masked prefix>: the word after it is started -- the text after the last command delimiter, with its
# leading `VAR=val` words and keywords stripped, is empty (command position) or `bash` with only flags (its operand).
# Keyed on the SEGMENT, not on cmdpos()'s trailing-word strip: `G="$(pick "a.sh" \` puts `a.sh` after `pick`, which
# cmdpos() strips as part of the `G=…` word and would call command position.
function cmdseg8(pre,   g) {
  g = pre; sub(/^.*[;&|(`{!]/, "", g); sub(/^[[:space:]]+/, "", g); sub(/[[:space:]]+$/, "", g)
  while (sub(/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|then|do|else|if|elif|while|until|exec|time|nohup|command)([[:space:]]+|$)/, "", g)) ;
  return g == "" || g ~ /^bash([[:space:]]+-[A-Za-z-]+)*$/
}
# --- H12: a mutation battery in a fixture's run.sh or lib.sh ------------------------------------------------------
# r12 <reason> <line>: record the FIRST line of each reason kind for this file (rows are per FILE, one reason list).
function r12(key, i) { if (!(key in S12)) { S12[key] = 1; R12 = R12 (R12 == "" ? "" : ", ") key ":" i } }
# h12 <line>: (a) a battery word on the MASKED line (a comment, a string and a heredoc body are X, so only code counts);
# (b) a line opening `# MUTANT-MATRIX` read off the UNMASKED line, only where the masker was in code at the line start
# (ST0), so a line inside a multi-line string is no header; (c) a command-position `.`/`source` of a word naming
# lib/matrix.sh, literally or through a variable this file assigned such a value.
function h12(i,   s, k, n, off, q, e, w, nm, W) {
  s = M[i]
  if (match(s, /^[[:space:]]*(function[[:space:]]+[A-Za-z0-9_]*[Mm][Uu][Tt][A-Za-z0-9_]*([[:space:]]|\(|$)|[A-Za-z0-9_]*[Mm][Uu][Tt][A-Za-z0-9_]*[[:space:]]*\(\))/)) {
    nm = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*(function[[:space:]]+)?/, "", nm); sub(/[^A-Za-z0-9_].*$/, "", nm)
    r12("def " nm, i)
  }
  if (!ISRUN && !ISL12) return
  if (s ~ /mutant_killed|need_base|matrix_row|mkmut|mut_copy|mutate_file/) {
    n = split("mutant_killed need_base matrix_row mkmut mut_copy mutate_file", W, " ")
    for (k = 1; k <= n; k++) if (s ~ ("(^|[^A-Za-z0-9_])" W[k] "([^A-Za-z0-9_]|$)")) r12(W[k], i)
  }
  if (ST0[i] == "c" && O[i] ~ /^[[:space:]]*#[[:space:]]*MUTANT-MATRIX/) r12("# MUTANT-MATRIX", i)
  if (match(s, /^[[:space:]]*(export[[:space:]]+|local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
    nm = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*(export[[:space:]]+|local[[:space:]]+)?/, "", nm); sub(/=$/, "", nm)
    if (index(substr(O[i], RSTART + RLENGTH), "lib/matrix.sh")) MV12[nm] = 1
  }
  off = 0
  while (match(substr(s, off + 1), /(^[[:space:]]*|[;&|({!][[:space:]]*|(^|[[:space:]])(then|do|else)[[:space:]]+)(\.|source)[[:space:]]+/)) {
    q = off + RSTART + RLENGTH; e = wend6(s, q); off = e - 1
    w = substr(O[i], q, e - q)
    if (index(w, "lib/matrix.sh")) r12("lib/matrix.sh", i)
    else if (match(w, /^"?\$\{?[A-Za-z_][A-Za-z0-9_]*/)) { nm = substr(w, RSTART, RLENGTH); sub(/^"?\$\{?/, "", nm); if (nm in MV12) r12("lib/matrix.sh", i) }
  }
}
# --- H13: a hand extraction of a hook span that binds the record homes --------------------------------------------
# ps13 <line>: `PS <fx> <rel>:<line>` when the line EMITS such a span: a command-position `sed` or `awk` and, after
# it, `FIXTURE_POOL_BEGIN` or `RECORD_HOME_BEGIN` inside a quoted word (on a code line the X run under the marker opens
# on a quote character; a comment opens on the blank before its `#`). A heredoc body line is read raw.
function ps13(i,   o, s, st, p, k, t) {
  o = O[i]
  if (!index(o, "FIXTURE_POOL_BEGIN") && !index(o, "RECORD_HOME_BEGIN")) return
  if (HDL[i]) { if (o ~ /^[[:space:]]*#/) return; s = o } else s = M[i]
  if (!match(s, /(^|[;&|({!`]|(^|[[:space:]])(then|do|else))[[:space:]]*(sed|awk)[[:space:]]/)) return
  st = RSTART + RLENGTH
  p = index(substr(o, st), "FIXTURE_POOL_BEGIN"); k = index(substr(o, st), "RECORD_HOME_BEGIN")
  if (!p || (k && k < p)) p = k
  if (!p) return
  p += st - 1
  if (!HDL[i]) { t = p; while (t > 1 && substr(M[i], t - 1, 1) == "X") t--; if (t <= 1 || substr(M[i], t - 1, 1) !~ /["\047]/) return }
  print "PS\t" FX "\t" REL ":" i
}
# --- H14: a hand `git init` (world adoption) ----------------------------------------------------------------------
# gi14 <line>: `GI <fx> <rel>:<line>: <text>` when the MASKED code line runs `git init`: scripts/validate-fixture-git-env.sh
# INIT_RE (a `git` with no name character or `-` before it, then only global options, then the whole word `init`),
# its option run widened by the long options a world builder spells. A heredoc body line is never read.
function vg14(i,   s, o, off, p, w, re, ore) {
  s = "; " M[i]; o = "; " O[i]
  re = "(;|&|[|]|[(]|[{]|!|[[:space:]]then|[[:space:]]do|[[:space:]]else)[[:space:]]*((if|elif|while|until|then|do|else|!)[[:space:]]+)*(((command|exec|env)|-u[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)[[:space:]]+)*"
  ore = "^([[:space:]]+(-[cC][[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]*|--work-tree=[^[:space:]]*|--no-pager|-P|--bare))*[[:space:]]+init([[:space:]]|$)"
  off = 0
  while (match(substr(s, off + 1), re)) {
    p = off + RSTART + RLENGTH; off += RSTART
    # the mask hides the quoted name (`"$REAL_GIT"` reads `"XXXXXXXXX"`): the word is read in O at the same offset
    w = wordat(o, p); gsub(/["\047]/, "", w)
    if ((w ~ /^[$][{]?[A-Za-z_][A-Za-z0-9_]*[}]?$/ || w == "git" || w ~ /\/git$/) && substr(s, WEND) ~ ore) return 1
  }
  return 0
}
function gi14(i,   s, t) {
  s = M[i]
  if (!index(s, "init")) return
  if (!(index(s, "git") && s ~ /(^|[^[:alnum:]_-])git([[:space:]]+(-[cC][[:space:]]*[^[:space:]]+|--git-dir=[^[:space:]]*|--work-tree=[^[:space:]]*|--no-pager|-P|--bare))*[[:space:]]+init([[:space:]]|$)/) && !vg14(i)) return
  t = trim(O[i]); gsub(/\t/, " ", t)
  print "GI\t" FX "\t" REL ":" i ": " substr(t, 1, 160)
}
# wr14 <line>: the wrapper-rewrite escape. A function DEFINED in this fixture's own .sh population (`name() {` or
# `function name`, a one-line or a multi-line body) whose body has a command-position `git` is a git wrapper: it emits
# `WD <fx> <name>`. A code line whose command-position word is followed by an option run and/or up to two dir-first
# words and then the whole word `init` emits `WU <fx> <word> <file>:<line>: <text>`; the judge counts a WU row only
# when its fixture holds a WD row of that word (so a keyword, a builtin and any undefined word stay quiet). `git` and
# `world_git` are never a WU word. A `"$REAL_GIT"` body is not a command-position `git`: variable-held git is out.
function brc(t,   n, off, o, c) {
  n = 0; off = 0; o = 0; c = 0
  while (match(substr(t, off + 1), /(^|[[:space:];&|(])\{([[:space:]]|$)/)) { o++; off += RSTART + RLENGTH - 1 }
  off = 0
  while (match(substr(t, off + 1), /(^|[[:space:];&|)])\}([[:space:];&|)]|$)/)) { c++; off += RSTART + RLENGTH - 1 }
  W14O = o; W14C = c
}
function wr14(i,   s, t, nm, off, m, w, gre, ure, k, isdef) {
  s = M[i]; t = s; isdef = 0
  gre = "(^|[;&|({!]|[[:space:]]then|[[:space:]]do|[[:space:]]else)[[:space:]]*(((command|exec|env)|-u[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)[[:space:]]+)*git([[:space:]]|$)"
  if (s ~ /^[[:space:]]*function[[:space:]]+[A-Za-z_][A-Za-z0-9_.:-]*/ || s ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_.:-]*[[:space:]]*\(\)/) {
    t = s; sub(/^[[:space:]]*function[[:space:]]+/, "", t); sub(/^[[:space:]]+/, "", t)
    nm = t; sub(/[^A-Za-z0-9_.:-].*$/, "", nm)
    sub(/^[A-Za-z_][A-Za-z0-9_.:-]*[[:space:]]*(\(\))?/, "", t)
    ND++; DNM[ND] = nm; DST[ND] = BD; DGT[ND] = 0; DOP[ND] = 0; DLN[ND] = 0; isdef = 1
  }
  if (t ~ gre) for (k = 1; k <= ND; k++) DGT[k] = 1
  brc(t); BD += W14O - W14C
  for (k = 1; k <= ND; k++) { DLN[k]++; if (BD > DST[k] || (isdef && k == ND && W14O > 0)) DOP[k] = 1 }
  while (ND > 0 && ((DOP[ND] && BD <= DST[ND]) || (!DOP[ND] && DLN[ND] > 1))) {
    if (DOP[ND] && DGT[ND]) print "WD\t" FX "\t" DNM[ND]
    ND--
  }
  if (!index(s, "init")) return
  ure = "(^|[;&|({])[[:space:]]*((if|elif|while|until|then|do|else|!)[[:space:]]+)*[A-Za-z_][A-Za-z0-9_.:-]*([[:space:]]+(-[cC][[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]*|--work-tree=[^[:space:]]*|--no-pager|-P|--bare|-q))*([[:space:]]+[^-[:space:];&|()<>][^[:space:];&|()<>]*)?([[:space:]]+[^-[:space:];&|()<>][^[:space:];&|()<>]*)?[[:space:]]+init([[:space:]]|$)"
  off = 0
  while (match(substr(s, off + 1), ure)) {
    m = substr(s, off + RSTART, RLENGTH); off += RSTART + RLENGTH - 2
    sub(/^[;&|({]*[[:space:]]*/, "", m)
    while (sub(/^(if|elif|while|until|then|do|else|!)[[:space:]]+/, "", m)) ;
    w = m; sub(/[[:space:]].*$/, "", w)
    if (w == "git" || w == "world_git" || w == "init") continue
    t = trim(O[i]); gsub(/\t/, " ", t)
    print "WU\t" FX "\t" w "\t" REL ":" i ": " substr(t, 1, 160)
  }
}
function analyze(   i, s, off, st, q, w, ww, pre, pre0, neg, e, qe, nw, ts, a, h, k, re, w2, pe) {
  if (FX != "" && FX != "lib") prep6()
  R12 = ""; split("", S12); split("", MV12); ND = 0; BD = 0
  for (i = 1; i <= NL; i++) {
    s = M[i]
    # H1
    off = 0
    while (match(substr(s, off + 1), /(^|[[:space:]])-d[[:space:]]+/)) {
      st = off + RSTART; if (substr(s, st, 1) != "-") st++
      off = st + 1
      q = st + 2; while (substr(O[i], q, 1) ~ /[[:space:]]/) q++
      w = wordat(O[i], q); ww = w; gsub(/["\047]/, "", ww)
      if (ww !~ /(^|\/)\.git$/) continue
      pre0 = substr(s, 1, st - 1); pre = pre0; neg = 0
      sub(/[[:space:]]+$/, "", pre)
      if (pre ~ /!$/) { neg = 1; pre = substr(pre, 1, length(pre) - 1); sub(/[[:space:]]+$/, "", pre) }
      if (pre !~ /(^|[^A-Za-z0-9_])(\[|\[\[|test)$/) continue
      sub(/(\[\[|\[|test)$/, "", pre); sub(/[[:space:]]+$/, "", pre)
      if (pre ~ /(^|[^!=])!$/) neg = !neg
      T1++
      e = index(substr(s, WEND), "]"); qe = e ? WEND + e : WEND
      while (substr(s, qe, 1) == "]") qe++
      if (fails_to_exit0(i, st, qe, neg, pre0)) print "H1\t" REL ":" i "\t" trim(O[i])
    }
    # H2
    off = 0
    while (match(substr(s, off + 1), /(^|[[:space:];&|(!{])command[[:space:]]+-v[[:space:]]+/)) {
      st = off + RSTART; if (substr(s, st, 7) != "command") st++
      q = off + RSTART + RLENGTH; off = q - 1
      w = wordat(O[i], q); gsub(/["\047]/, "", w)
      if (!(w in TOOLS)) continue
      T2++
      pre0 = substr(s, 1, st - 1); pre = pre0; sub(/[[:space:]]+$/, "", pre); neg = (pre ~ /(^|[^!=])!$/)
      if (fails_to_exit0(i, st, WEND, neg, pre0)) print "H2\t" REL ":" i "\t" trim(O[i])
    }
    # H3
    off = 0
    while (match(substr(s, off + 1), /(^|[^A-Za-z0-9_.\/-])(\/usr\/bin\/|\/bin\/)?sh([[:space:]]+|$|[;)&|<>])/)) {
      st = off + RSTART; ts = substr(s, st, 1); if (ts != "/" && ts != "s") st++
      q = off + RSTART + RLENGTH
      # A match closed by `;`, `)`, `&`, `|`, `<` or `>` (not by blanks or the end of the line) gives that byte back.
      if (substr(s, q - 1, 1) ~ /[;)&|<>]/) q--
      off = q - 1
      pre = substr(s, 1, st - 1); sub(/[[:space:]]+$/, "", pre)
      pe = pre; while (sub(/[[:space:]]+(-i|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)$/, "", pe)) ;
      if (!(pre == "" || pre ~ /[;&|(`{!]$/ || pre ~ /(^|[^A-Za-z0-9_])(then|do|else|exec|time|nohup|xargs|command)$/ || pe ~ /(^|[[:space:];&|(`{!])env$/)) continue
      nw = substr(s, q)
      if (nw == "" || nw ~ /^(==|!=|=|\)|;|&|\||>|<)/) { if (!(pre ~ /\|$/ && nw !~ /^(==|!=|=)/)) continue }
      print "H3\t" REL ":" i "\t" trim(O[i])
    }
    if (FX == "" || FX == "lib") continue
    scrub8(i)
    if (ISRUN && !SEEN8 && !HDL[i]) ev8(i)
    # I10's hook-driver grammar, carried so an ALLOWLISTED fixture that starts driving a hook still FAILs H8: any
    # run.sh line naming `hooks/ai-dlc` or `$HOOK`, or a lib.sh non-comment line naming one once the glob form
    # `hooks/ai-dlc-*` is removed (I10's own two clauses, verbatim in effect)
    if (!(FX in HK8)) {
      t8 = O[i]
      if (REL ~ /\/lib\.sh$/) { if (t8 ~ /^[[:blank:]]*#/) t8 = ""; gsub(/hooks\/ai-dlc-\*/, "", t8) }
      else if (!ISRUN) t8 = ""
      if (t8 ~ /hooks\/ai-dlc|\$HOOK/) { HK8[FX] = 1; print "HK8\t" FX "\t" REL ":" i }
    }
    if (ISF12) ps13(i)
    if (ISF12 && !HDL[i]) { gi14(i); wr14(i) }
    if (!HDL[i]) { h6(i); if (ISRUN || ISL12 || ISF12) h12(i) }
    # H10/H11 facts (the fixture contract's skeleton): a run.sh code line DEFINING ok or bad, and a run.sh code line
    # whose command-position `bash` runs a pre-push hook. Both read the masked line, so a comment, a string (a
    # printf writing a stub hook) and a heredoc body are never a fact.
    if (ISRUN && !HDL[i]) {
      if (s ~ /^[[:space:]]*(function[[:space:]]+)?(ok|bad)[[:space:]]*\(\)/) print "OB\t" FX "\t" REL ":" i
      if (match(O[i], /(^|[[:space:];&|(])bash[[:space:]]+[^[:space:];&|]*(\.githooks|git-hooks)\/pre-push/)) {
        st = RSTART; while (substr(O[i], st, 4) != "bash") st++
        if (substr(s, st, 4) == "bash") print "HD\t" FX "\t" REL ":" i
      }
    }
  }
  stubjoin()
  if (R12 != "") print "H12\t" REL "\t" R12
  if (STK != "c" || HDN > 0) print "Q\t" REL "\t" (HDN > 0 ? "inside a heredoc body" : "inside a quoted string (" STK ")")
}
pass == 2 && FNR == 1 {
  if (CUR != "") analyze()
  CUR = FILENAME; NL = 0; STK = "c"; HDN = 0; HDI = 0; SEEN8 = 0; split("", DP)
  REL = relof(FILENAME); FX = fxof(REL); ISRUN = (REL == "core/fixtures/" FX "/run.sh"); ISL12 = (REL == "core/fixtures/" FX "/lib.sh"); ISF12 = (FX != "" && FX != "lib" && REL ~ /\.sh$/); loadtools(FX)
  print "F\t" REL
}
pass == 2 { NL++; O[NL] = $0; ST0[NL] = STK; M[NL] = maskl($0); HDL[NL] = INHD }
END {
  if (CUR != "") analyze()
  print "T\tH1\t" (T1 + 0); print "T\tH2\t" (T2 + 0); print "T\tH6\t" (T6 + 0)
}
AWK

# --- the H8 judge: SCRUBBED, ORDER, NOSCRUB per fixture directory; a shard stub takes its IMPL's verdict --------
# Rows: H8SCRUB <fx> <where>; H8 <fx> <reason> (unlisted, not scrubbed); H8LISTED <fx>; H8STALE <fx> <why>;
# H8DUP <fx>; H8NOREASON <fx>; H8DER <fx> <kind> (every not-scrubbed fixture, for --derive-h8).
read -r -d '' H8_JUDGE_AWK <<'AWK'
FILENAME == ARGV[1] { IMPL[$1] = $2; next }
FILENAME == ARGV[2] { n = split($0, a, "/"); if (n == 4 && a[1] == "core" && a[2] == "fixtures" && a[4] == "run.sh" && a[3] != "lib") FXS[a[3]] = 1; next }
FILENAME == ARGV[3] {
  if ($1 == "S8") { if (!(($3) in S8)) S8[$3] = $4 + 0; next }
  if ($1 == "HK8") { HK[$2] = $3; next }
  if ($1 == "E8") { NE[$2]++; EL[$2, NE[$2]] = $3 + 0; EK[$2, NE[$2]] = $4; EB[$2, NE[$2]] = $5; ET[$2, NE[$2]] = $6; next }
  next
}
FILENAME == ARGV[4] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in LISTED) print "H8DUP\t" x
  LISTED[x] = 1
  if (r == "") print "H8NOREASON\t" x
  next
}
# judge <fx>: "S<where>" scrubbed, "O<line>: <text>" a start before the scrub, "N" no scrub at all
function judge(f,   rr, L, k, b) {
  rr = "core/fixtures/" f "/run.sh"; L = (rr in S8) ? S8[rr] : 0
  # no scrub on run.sh and none in an own-directory file run.sh sources: NOSCRUB, whatever it starts
  if (!L) { b = 0; for (k = 1; k <= NE[f]; k++) if (EK[f, k] == "src" && EB[f, k] != "" && (("core/fixtures/" f "/" EB[f, k]) in S8)) b = 1; if (!b) return "N" }
  for (k = 1; k <= NE[f]; k++) {
    if (L && EL[f, k] >= L) break
    b = EB[f, k]
    if (EK[f, k] == "src" && b != "" && (("core/fixtures/" f "/" b) in S8)) return "S" "core/fixtures/" f "/" b ":" S8["core/fixtures/" f "/" b] " (sourced at run.sh:" EL[f, k] ")"
    return "O" EL[f, k] ": " ET[f, k]
  }
  if (L) return "S" rr ":" L
  return "N"
}
END {
  for (f in FXS) {
    t = (f in IMPL && IMPL[f] != "!") ? IMPL[f] : f
    v = judge(t); via = (t == f) ? "" : " via its IMPL " t
    if (substr(v, 1, 1) == "S") {
      print "H8SCRUB\t" f "\t" substr(v, 2) via
      if (f in LISTED) print "H8STALE\t" f "\tthe fixture is SCRUBBED (" substr(v, 2) via ")"
      continue
    }
    kind = (substr(v, 1, 1) == "O") ? "order" : "none"
    print "H8DER\t" f "\t" kind
    if ((f in LISTED) && (f in HK)) { print "H8\t" f "\tallowlisted, but it drives a hook (" HK[f] "), and a hook-driving fixture is never acquitted by the list"; continue }
    if (f in LISTED) { print "H8LISTED\t" f; continue }
    if (kind == "order") print "H8\t" f "\trun.sh" via " starts a script or sources a file at :" substr(v, 2) " before its AI_DLC_* scrub"
    else print "H8\t" f "\trun.sh" via " carries no env-derived AI_DLC_* unset loop on a code line"
  }
  for (x in LISTED) if (!(x in FXS)) print "H8STALE\t" x "\tno core/fixtures/" x "/run.sh is tracked"
}
AWK

# --- the H10/H11 judge: the fixture contract's skeleton (.claude/rules/fixture-contract.md) ----------------------
# ARGV[1] the allowlist, rows `<fixture>:<clause>\t<reason>`, clause `report` (H10) or `hook-drive` (H11); ARGV[2] the
# scan. Rows: H10 <fx> <where> / H11 <fx> <where> (an unlisted offender's FIRST line); H10LISTED <key>; H10STALE <key>
# <why>; H10DUP <key>; H10NOREASON <key>.
read -r -d '' H10_JUDGE_AWK <<'AWK'
FILENAME == ARGV[1] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in LISTED) print "H10DUP\t" x
  LISTED[x] = 1
  if (r == "") print "H10NOREASON\t" x
  next
}
$1 == "F" { n = split($2, a, "/"); if (n == 4 && a[4] == "run.sh" && a[3] != "lib") FXS[a[3]] = 1; next }
$1 == "OB" { if (!(($2 ":report") in HIT)) HIT[$2 ":report"] = $3; next }
$1 == "HD" { if (!(($2 ":hook-drive") in HIT)) HIT[$2 ":hook-drive"] = $3; next }
END {
  for (k in HIT) {
    if (k in LISTED) { print "H10LISTED\t" k; continue }
    f = k; sub(/:[^:]*$/, "", f)
    print ((k ~ /:report$/) ? "H10" : "H11") "\t" f "\t" HIT[k]
  }
  for (x in LISTED) {
    if (x !~ /:(report|hook-drive)$/) { print "H10STALE\t" x "\tthe clause after `:` is neither report nor hook-drive"; continue }
    f = x; sub(/:[^:]*$/, "", f)
    if (!(f in FXS)) { print "H10STALE\t" x "\tno core/fixtures/" f "/run.sh is tracked"; continue }
    if (!(x in HIT)) print "H10STALE\t" x "\tthe fixture no longer offends; drop the row"
  }
}
AWK

# --- the H13 judge: hand extractions per fixture, against scripts/pool-span-allowlist.txt -------------------------
# ARGV[1] the allowlist, rows `<fixture>\t<reason>`; ARGV[2] the scan. Rows: H13 <fx> <where> (an unlisted fixture's
# FIRST extraction line); H13LISTED <fx>; H13STALE <fx> <why>; H13DUP <fx>; H13NOREASON <fx>; N13 <extraction lines>.
read -r -d '' H13_JUDGE_AWK <<'AWK'
FILENAME == ARGV[1] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in LISTED) print "H13DUP\t" x
  LISTED[x] = 1
  if (r == "") print "H13NOREASON\t" x
  next
}
$1 == "F" { n = split($2, a, "/"); if (n == 4 && a[4] == "run.sh" && a[3] != "lib") FXS[a[3]] = 1; next }
$1 == "PS" { N13++; if (!(($2) in HIT)) HIT[$2] = $3; next }
END {
  for (f in HIT) print ((f in LISTED) ? "H13LISTED\t" f : "H13\t" f "\t" HIT[f])
  for (x in LISTED) {
    if (!(x in FXS)) { print "H13STALE\t" x "\tno core/fixtures/" x "/run.sh is tracked"; continue }
    if (!(x in HIT)) print "H13STALE\t" x "\tthe fixture no longer extracts a span by hand; drop the row"
  }
  print "N13\t" (N13 + 0)
}
AWK

# --- the H14 judge: hand `git init` lines per fixture, against world-adoption-allowlist.txt ------------------------
# ARGV[1] the allowlist, rows `<fixture>\t<reason>`; ARGV[2] the scan. Rows: H14 <fx> <where> (an unlisted fixture's
# FIRST hand init line, `<file>:<line>: <text>`); H14LISTED <fx>; H14STALE <fx> <why>; H14DUP <fx>; H14NOREASON <fx>;
# N14 <hand init lines>.
read -r -d '' H14_JUDGE_AWK <<'AWK'
FILENAME == ARGV[1] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in LISTED) print "H14DUP\t" x
  LISTED[x] = 1
  if (r == "") print "H14NOREASON\t" x
  next
}
$1 == "F" { n = split($2, a, "/"); if (n == 4 && a[4] == "run.sh" && a[3] != "lib") FXS[a[3]] = 1; next }
$1 == "GI" { N14++; if (!(($2) in HIT)) HIT[$2] = $3; next }
$1 == "WD" { DEF[$2, $3] = 1; next }
$1 == "WU" { WN++; WFX[WN] = $2; WNM[WN] = $3; WWH[WN] = $4; next }
END {
  for (k = 1; k <= WN; k++) if ((WFX[k], WNM[k]) in DEF && !(WWH[k] in WSEEN)) { WSEEN[WWH[k]] = 1; N14++; if (!(WFX[k] in HIT)) HIT[WFX[k]] = WWH[k] }
  for (f in HIT) print ((f in LISTED) ? "H14LISTED\t" f : "H14\t" f "\t" HIT[f])
  for (x in LISTED) {
    if (!(x in FXS)) { print "H14STALE\t" x "\tno core/fixtures/" x "/run.sh is tracked"; continue }
    if (!(x in HIT)) print "H14STALE\t" x "\tthe fixture no longer runs git init by hand; drop the row"
  }
  print "N14\t" (N14 + 0)
}
AWK

# run_all <root> <out-prefix>: list, resolve, scan, judge. Writes <out>.scan and <out>.verdict; returns 2 on a broken
# corpus with the reason on stdout.
run_all() {
  local r="$1" o="$2" listed scanned
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
    git -C "$r" ls-files -- 'core/fixtures/**/*.sh' ) > "$o.list" 2>/dev/null \
    || { echo "BROKEN: git ls-files failed under $r"; return 2; }
  listed="$(awk 'END { print NR }' "$o.list")"
  [ "$listed" -gt 0 ] || { echo "BROKEN: core/fixtures/**/*.sh listed 0 tracked files under $r; an empty corpus has no offenders by construction"; return 2; }
  awk -v R="$r" '{ print R "/" $0 }' "$o.list" > "$o.abs"
  # shellcheck disable=SC2046
  set -f; IFS='
'
  set -- $(cat "$o.abs"); unset IFS; set +f
  bash "$RESOLVER" --impl-of "$@" | awk -F'\t' '{ n = split($1, a, "/"); print a[n - 1] "\t" $2 }' > "$o.stubs" \
    || { echo "BROKEN: the shard-stub resolver failed"; return 2; }
  awk -v ROOTP="$r/" "$SCAN_AWK" pass=2 "$@" > "$o.scan" || { echo "BROKEN: the scan awk failed"; return 2; }
  scanned="$(grep -c '^F	' "$o.scan")" || scanned=0
  [ "$scanned" -eq "$listed" ] || { echo "BROKEN: listed $listed files, scanned $scanned"; return 2; }
  if grep -q '^Q	' "$o.scan"; then
    echo "BROKEN: the masker lost its quote state -- these files end inside a string or heredoc, so their arms are unattributable:"
    awk -F'\t' '$1 == "Q" { print "    " $2 ": " $3 }' "$o.scan"; return 2
  fi
  # H1, H2, H3, H6 and H12 carry no list: the scan's rows ARE the verdict
  awk -F'\t' '$1 == "H1" || $1 == "H2" || $1 == "H3" || $1 == "H6" || $1 == "H12" { print }' "$o.scan" | LC_ALL=C sort -u > "$o.verdict" \
    || { echo "BROKEN: the verdict filter failed, so its verdict is empty rather than clean"; return 2; }
  [ -f "$r/$H8_ALLOW_REL" ] && cp "$r/$H8_ALLOW_REL" "$o.h8allow" || : > "$o.h8allow"
  awk -F'\t' "$H8_JUDGE_AWK" "$o.stubs" "$o.list" "$o.scan" "$o.h8allow" | LC_ALL=C sort -u > "$o.h8" \
    || { echo "BROKEN: the H8 judge awk failed, so its verdict is empty rather than clean"; return 2; }
  [ -f "$r/$H10_ALLOW_REL" ] && cp "$r/$H10_ALLOW_REL" "$o.h10allow" || : > "$o.h10allow"
  awk -F'\t' "$H10_JUDGE_AWK" "$o.h10allow" "$o.scan" | LC_ALL=C sort -u > "$o.h10" \
    || { echo "BROKEN: the H10/H11 judge awk failed, so its verdict is empty rather than clean"; return 2; }
  [ -f "$r/$H13_ALLOW_REL" ] && cp "$r/$H13_ALLOW_REL" "$o.h13allow" || : > "$o.h13allow"
  awk -F'\t' "$H13_JUDGE_AWK" "$o.h13allow" "$o.scan" | LC_ALL=C sort -u > "$o.h13" \
    || { echo "BROKEN: the H13 judge awk failed, so its verdict is empty rather than clean"; return 2; }
  grep -q '^N13	' "$o.h13" || { echo "BROKEN: the H13 judge printed no extraction count"; return 2; }
  [ -f "$r/$H14_ALLOW_REL" ] && cp "$r/$H14_ALLOW_REL" "$o.h14allow" || : > "$o.h14allow"
  awk -F'\t' "$H14_JUDGE_AWK" "$o.h14allow" "$o.scan" | LC_ALL=C sort -u > "$o.h14" \
    || { echo "BROKEN: the H14 judge awk failed, so its verdict is empty rather than clean"; return 2; }
  grep -q '^N14	' "$o.h14" || { echo "BROKEN: the H14 judge printed no hand-init count"; return 2; }
  return 0
}

# m4 <repo> <current list> <scratch> <rel> <arm> <remedy> [<noun>]: the down-only arm, keyed on field 1; <noun> names
# field 1 in the FAIL line (default `fixture`; H10-M4 passes its `<fixture>:<clause>` key). THE ONE SHARED COPY:
# scripts/validate-fixture-inprocess.sh extracts this function by its own boundaries (awk, every line strictly between
# the `# M4_BEGIN` and `# M4_END` marker lines below, refusing unless exactly one `m4() {` sits between them) and passes
# all three, so the two down-only fixture lists run one function.
# m4 is m4base (the git half: origin/main's <rel> written to <scratch>, rc 3, else the SKIP or FAIL text) then m4cmp
# (the compare half over that base).
# M4_BEGIN
m4() {
  local rel="$4" arm="$5" rc
  local remedy="$6"
  local noun="${7:-fixture}"
  m4base "$1" "$3" "$rel" "$arm"; rc=$?
  [ "$rc" -eq 3 ] || return "$rc"
  m4cmp "$2" "$3" "$rel" "$arm" "$remedy" "$noun"
}
# m4base <repo> <scratch> <rel> <arm>
m4base() {
  local repo="$1" base="$2" rel="$3" arm="$4" sha
  sha="$(git -C "$repo" rev-parse -q --verify 'origin/main^{commit}' 2>/dev/null)" || sha=""
  if [ -z "$sha" ]; then echo "SKIP $arm: origin/main does not resolve here, so there is no base allowlist to compare against"; return 0; fi
  if ! git -C "$repo" cat-file -e "${sha}:${rel}" 2>/dev/null; then
    echo "SKIP $arm: origin/main carries no $rel -- this is the release that first ships it"; return 0; fi
  git -C "$repo" show "${sha}:${rel}" > "$base" 2>/dev/null || { echo "FAIL $arm: origin/main carries $rel but it could not be read"; return 1; }
  return 3
}
# m4cmp <current list> <base> <rel> <arm> <remedy> <noun> -> the OK or FAIL text; rc 0 or 1
m4cmp() {
  local cur="$1" base="$2" rel="$3" arm="$4" remedy="$5" noun="$6" added
  added="$(awk -F'\t' '/^[[:space:]]*(#|$)/ { next } { x = $1; gsub(/[[:space:]]/, "", x) }
    FNR == NR { b[x] = 1; next } !(x in b) && !(x in seen) { seen[x] = 1; print x }' "$base" "$cur" | LC_ALL=C sort)"
  if [ -n "$added" ]; then
    echo "FAIL $arm: allowlist row(s) whose $noun is not on $rel at origin/main -- the list is DOWN-ONLY:"
    printf '%s\n' "$added" | sed 's/^/    /'
    echo "  Remedy: $remedy"
    return 1
  fi
  echo "OK $arm: no allowlist row added against origin/main"; return 0
}
# M4_END

# inert <root> <list> <out>: E1's predicate. The INERT receipts, one repo-relative path per line; E1 reports them (no
# gate runs one). Only a file named `receipt*.sh` in <list> can be inert (a sourced helper never
# is). It is inert when nothing reads it: no non-comment line of a tracked core/fixtures/*/run.sh, seed.sh, lib.sh or
# .githooks/* file names it -- nor, for a scripts/ receipt, of a tracked scripts/*.sh other than itself. A `verify:`
# line is not a reader: E1 asks whether a RUNNER executes the receipt.
# "Names it" is `<dir>/<basename>` anywhere on the line (`scripts/<basename>` for a scripts/ receipt), or the bare
# basename from a file in the receipt's OWN directory (`bash "$HERE/receipt.sh"`), so one fixture's call never makes
# another fixture's same-named receipt live. A scripts/*.sh reader is consulted only for scripts/ receipts, and is
# listed only when <list> carries one, so a caller listing no scripts/ receipt reads exactly the files it always read.
# Returns 1 when a referencing file cannot be read (awk reads an unopenable file as empty, so reads are counted).
inert() {
  local r="$1" n
  if grep -q '^scripts/receipt[^/]*\.sh$' "$2"; then
    git -C "$r" ls-files -- 'core/fixtures/*/run.sh' 'core/fixtures/*/seed.sh' 'core/fixtures/*/lib.sh' '.githooks/*' 'scripts/*.sh' > "$3.refs" 2>/dev/null || return 1
  else
    git -C "$r" ls-files -- 'core/fixtures/*/run.sh' 'core/fixtures/*/seed.sh' 'core/fixtures/*/lib.sh' '.githooks/*' > "$3.refs" 2>/dev/null || return 1
  fi
  n="$(awk 'END { print NR }' "$3.refs")"
  awk -v R="$r" -v RL="$3.refs" -v NREF="$n" '
    function named(l, s,   i, t) {  # s in l, with no name character before it (so `dir/receipt.sh` is not `r/receipt.sh`)
      t = l
      while ((i = index(t, s)) > 0) { if (i == 1 || substr(t, i - 1, 1) !~ /[A-Za-z0-9_.-]/) return 1; t = substr(t, i + 1) }
      return 0 }
    { b = $0; sub(/^.*\//, "", b); if (b !~ /^receipt[^\/]*\.sh$/) next
      d = $0; sub(/\/[^\/]*$/, "", d); C[$0] = 1; BASE[$0] = b; DIR[$0] = d; t = d; sub(/^.*\//, "", t); SUF[$0] = t "/" b }
    END {
      got = 0
      while ((getline f < RL) > 0) {
        fd = f; sub(/\/[^\/]*$/, "", fd); p = R "/" f
        if ((getline l < p) < 0) exit 3
        got++
        do { if (!index(l, "receipt") || l ~ /^[[:space:]]*#/) continue
             for (c in C) { if (c == f || (fd == "scripts" && DIR[c] != "scripts")) continue
               if (named(l, SUF[c])) { LIVE[c] = 1; continue }
               if (fd == DIR[c] && named(l, BASE[c])) LIVE[c] = 1 }
        } while ((getline l < p) > 0)
        close(p)
      }
      if (got != NREF) exit 3
      for (c in C) if (!(c in LIVE)) print c
    }' "$2" > "$3" || return 1
  return 0
}

# e1_run <repo> <out-prefix>: E1 over <repo>. Writes <out>.verdict (`INERT|STALE|DUP|NOREASON\t<path>`, sorted) and
# <out>.e1list (the population, counted: zero is BROKEN); prints the BROKEN reason and returns 2 when it could not
# measure. It reads only the tree's runner files and the allowlist, nothing another branch's ledger edit can change.
e1_run() {
  local repo="$1" o="$2"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
    git -C "$repo" ls-files -- 'core/fixtures/*/receipt*.sh' 'scripts/receipt*.sh' ) > "$o.e1list" 2>/dev/null \
    || { echo "BROKEN: git ls-files failed under $repo"; return 2; }
  [ -s "$o.e1list" ] || { echo "BROKEN: E1 listed 0 tracked receipt*.sh under $repo; an empty population has no inert receipt by construction"; return 2; }
  inert "$repo" "$o.e1list" "$o.inert" ||{ echo "BROKEN: a reader file could not be read under $repo"; return 2; }
  [ -f "$repo/$E1_ALLOW_REL" ] && cp "$repo/$E1_ALLOW_REL" "$o.allow" || : > "$o.allow"
  awk -F'\t' 'FILENAME == ARGV[1] { if ($0 != "") I[$0] = 1; next }
    /^[[:space:]]*(#|$)/ { next }
    { x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
      if (x in L) print "DUP\t" x; L[x] = 1; if (r == "") print "NOREASON\t" x }
    END { for (x in I) if (!(x in L)) print "INERT\t" x; for (x in L) if (!(x in I)) print "STALE\t" x }' "$o.inert" "$o.allow" \
    | LC_ALL=C sort -u > "$o.verdict" || { echo "BROKEN: the E1 judge awk failed"; return 2; }
}

# --- H9: a bounded real-time wait (BL-868 class W) ------------------------------------------------------------------
# H9_AWK is the class W scan, lifted from the BL-868 receipt it replaces, unchanged but for its inert skip (removed) and
# its loop stack (`done)` closes a frame; a loop keyword opens one only in command position). It carries its OWN masker, not
# SCAN_AWK's: it scans a `-c '...'` body, a printf stub and a file-writing heredoc body as CODE, where SCAN_AWK reads
# every string and heredoc as data. It prints `F\t<rel>` per file opened, `M\t<rel>\t<line>\t<id>` per allow marker,
# and one `W-<class>\t<rel>:<line>\t<text>` row per site.
read -r -d '' H9_AWK <<'AWK'
BEGIN { SQ = sprintf("%c", 39) }
function pop() { STK = substr(STK, 1, length(STK) - 1) }
function mask(s,   out, i, n, c, top) {
  # STK, carried across lines: c code, p a $( ) inside double quotes (code, with a paren depth DP), s single, a $'...',
  # d double. Quoted bytes become X, except a parameter reference inside double quotes, which stays code so a quoted
  # loop counter (`"$i" -lt 50`) is still read. A comment is dropped. Executed strings are recorded in EX[].
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1); top = substr(STK, length(STK), 1)
    if (top == "s") { if (c == SQ) { pop(); out = out c; if (CAP) { EX[++NEX] = CBUF; CAP = 0 } } else { out = out "X"; if (CAP) CBUF = CBUF c } i++; continue }
    if (top == "a") { if (c == "\\") { out = out "XX"; i += 2; continue } if (c == SQ) { pop(); out = out c } else out = out "X"; i++; continue }
    if (top == "d") {
      if (c == "\\") { out = out "XX"; i += 2; continue }
      if (c == "\"") { pop(); out = out c; i++; continue }
      if (c == "$" && substr(s, i + 1, 1) == "(") { STK = STK "p"; DP[length(STK)] = 0; out = out "$("; i += 2; continue }
      if (c == "$" && match(substr(s, i), /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/)) { out = out substr(s, i, RLENGTH); i += RLENGTH; continue }
      out = out "X"; i++; continue
    }
    # code: c or p
    if (c == "\\") { out = out substr(s, i, 2); i += 2; continue }
    if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[[:space:];&|(]/)) break
    if (c == SQ) {
      if (i > 1 && substr(s, i - 1, 1) == "$") { STK = STK "a"; out = out c; i++; continue }
      STK = STK "s"; out = out c
      # an executed string: the body of `-c '...'`, or a printf that writes a stub
      if (out ~ /(^|[[:space:]])-c[[:space:]]+'$/ || (out ~ /printf[[:space:]]+'$/ && substr(s, i + 1, 2) == "#!")) { CAP = 1; CBUF = "" }
      i++; continue
    }
    if (c == "\"") { STK = STK "d"; out = out c; i++; continue }
    if (top == "p") {
      if (c == "(") DP[length(STK)]++
      else if (c == ")") { if (DP[length(STK)] == 0) { pop(); out = out c; i++; continue } DP[length(STK)]-- }
    }
    out = out c; i++
  }
  if (substr(STK, length(STK), 1) == "s" && CAP) CBUF = CBUF "\n"
  return out
}
function incs(m,   r, o, a, b) {  # " v " for each `v=$((v + 1))` / `v=$(($v+1))` / `((v++))` / `((v+=1))`
  o = " "; r = m
  while (match(r, /[A-Za-z_][A-Za-z0-9_]*=\$\(\([[:space:]]*\$?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\+[[:space:]]*1[[:space:]]*\)\)/)) {
    a = substr(r, RSTART, RLENGTH); b = a; sub(/=.*$/, "", a); sub(/^[^(]*\(\([[:space:]]*\$?/, "", b); sub(/[^A-Za-z0-9_].*$/, "", b)
    if (a == b) o = o a " "
    r = substr(r, RSTART + RLENGTH)
  }
  r = m
  while (match(r, /(\(\(|(^|[;&|[:space:]])let[[:space:]]+"?)[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\+\+|\+=[[:space:]]*1)/)) {
    a = substr(r, RSTART, RLENGTH); sub(/^(\(\(|[;&|[:space:]]*let[[:space:]]+"?)[[:space:]]*/, "", a); sub(/[^A-Za-z0-9_].*$/, "", a); o = o a " "
    r = substr(r, RSTART + RLENGTH)
  }
  return o
}
function cmps(m,   r, o, a) {  # " v " for each `$v -lt|-le|-gt|-ge|-eq X` (the counter on the left, quoted or not)
  o = " "; r = m
  while (match(r, /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"?[[:space:]]+-(lt|le|gt|ge|eq)[[:space:]]/)) {
    a = substr(r, RSTART, RLENGTH); sub(/^\$\{?/, "", a); sub(/[^A-Za-z0-9_].*$/, "", a); o = o a " "
    r = substr(r, RSTART + RLENGTH)
  }
  return o
}
function both(i, c, z,   n, a, k) { n = split(i, a, " "); for (k = 1; k <= n; k++) if (index(c, " " a[k] " ") && !index(z, " " a[k] " ")) return 1; return 0 }
function resets(s,   o, a) {  # " v " for each `v=<integer>` LEADING the loop body: a per-pass count, not an iteration bound
  o = " "
  while (match(s, /^[[:space:];]*[A-Za-z_][A-Za-z0-9_]*=[0-9]+([[:space:]]*;|[[:space:]]+|$)/)) {
    a = substr(s, RSTART, RLENGTH); sub(/^[[:space:];]*/, "", a); sub(/=.*$/, "", a); o = o a " "; s = substr(s, RSTART + RLENGTH)
  }
  return o
}
function used(m,   r, a) {  # record every `$v` / `${v` read on this masked line
  r = m
  while (match(r, /\$\{?[A-Za-z_][A-Za-z0-9_]*/)) { a = substr(r, RSTART, RLENGTH); sub(/^\$\{?/, "", a); USED[a] = 1; r = substr(r, RSTART + RLENGTH) }
}
function flush(   k) {  # an unchecked `read -t` whose variable the file never reads is a pause; one it reads is a row
  for (k = 1; k <= NPR; k++) if (PRV[k] in USED) print "W-TIMEOUT\t" PRF[k] ":" PRL[k] "\t" PRT[k]
  NPR = 0; split("", USED)
}
function row(cls, ln, txt) { print cls "\t" REL ":" ln "\t" substr(txt, 1, 160) }
function scan(m, ln, orig,   r, t, a, v, nm, k) {
  # left-to-right over loop keywords, done, and sleep; plus the per-line clock/timeout rules
  # an elapsed-time read is a row where it is COMPARED (`s=$SECONDS` alone only records a start)
  if (m ~ /\$SECONDS|\$\{SECONDS|\(\([^)]*SECONDS/ && m ~ /(-lt|-le|-gt|-ge)[[:space:]]|\(\([^)]*SECONDS[^)]*[<>]/) row("W-CLOCK", ln, orig)
  else if (m ~ /date[[:space:]]+(-u[[:space:]]+)?\+%s/ && m ~ /(-lt|-le|-gt|-ge)[[:space:]]|(^|[;&|[:space:]])(while|until)[[:space:]]/) row("W-CLOCK", ln, orig)
  if (m ~ /(^|[;&|({!`[:space:]])timeout[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*"?(\$|[0-9])/) row("W-TIMEOUT", ln, orig)
  used(m)
  if (PQ) { if (m ~ /\$\?/) row("W-TIMEOUT", PQL, PQT); PQ = 0 }
  if (SP > 0 && RSP[SP]) { Z[SP] = resets(m); RSP[SP] = 0 }
  # the counters this line INCREMENTS and the names it COMPARES; a loop is bounded when one name is both, anywhere in
  # its header or body (a header cap `[ "$n" -lt 300 ]`, or an in-body watchdog `[ "$idle" -ge 50 ] && break`)
  linc = incs(m); lcmp = cmps(m)
  for (k = 1; k <= SP; k++) { INC[k] = INC[k] linc; CMP[k] = CMP[k] lcmp }
  r = m
  while (match(r, /(^|[;&|({!`[:space:]])(while|until|for|done|read|(\/usr)?(\/bin\/)?sleep)([[:space:];)|<>&`]|$)/)) {
    t = substr(r, RSTART, RLENGTH); gsub(/^[;&|({!`[:space:]]+|[[:space:];)|<>&`]+$/, "", t)
    pre = substr(m, 1, length(m) - length(r) + RSTART); rest = substr(r, RSTART + RLENGTH)
    # the keyword's own column, and the code before it. A `)`, `|`, `<`, `>`, `&` or backtick glued to the keyword
    # closes only a `done` (`$(... done)`, `done|`, `done>f`, `done<f`, `done&`); after any other keyword it is skipped
    tc = substr(r, RSTART + RLENGTH - 1, 1)
    kc = length(m) - length(r) + RSTART + RLENGTH - length(t) - (tc ~ /[[:space:];)|<>&`]/ ? 1 : 0)
    bk = substr(m, 1, kc - 1)
    if (t != "done" && tc ~ /[)|<>&`]/) { r = rest; continue }
    # a loop keyword opens a frame only in COMMAND position: line start after indentation, or after `;`, `&`, `&&`,
    # `|`, `||`, `(`, `$(`, `{`, `)` (a case arm), `!`, `do`, `then`, `else` or `time` (with its flags, `time -p`), or
    # glued to an opening backtick (`y=`for ...`) -- never a word of prose (`echo waiting for the server`, nor the
    # markdown "`x` for" a code-scanned heredoc carries)
    if ((t == "while" || t == "until" || t == "for") && bk !~ /((^|[;&|({)!]|(^|[;&|({)!`[:space:]])(do|then|else|time([[:space:]]+-[A-Za-z]+)*))[[:space:]]*|`)$/) { r = rest; continue }
    # and `done` closes one only in the same kind of position: line start, or after `;`, `&`, `&&`, `|`, `||`, `{`,
    # `)`, `then` or `else` -- so a prose `done` (`echo not done; true`, `echo $(echo done)`) never pops the loop
    # around it, which would end a bounded loop early and lose its W-BOUND row
    if (t == "done" && bk !~ /(^|[;&|{)]|(^|[;&|({)!`[:space:]])(then|else))[[:space:]]*$/) { r = rest; continue }
    if (t == "read") {
      # a `read -t` is a timeout row when its status or its variable can decide anything: it is conditioned (if,
      # while, until, elif, `!`, && or ||, or inside `$( )`), its `$?` is read on the next line, or its variable is
      # read anywhere in the file. Otherwise, INSIDE a loop, it is that loop's pause, judged like a sleep through the
      # loop header (W-BOUND, W-CLOCK); outside every loop it stays a row.
      if (rest ~ /^(-[a-zA-Z]+[[:space:]]+[0-9]*[[:space:]]*)*-[a-zA-Z]*t/) {
        v = rest; sub(/[;&|)].*$/, "", v); gsub(/-[a-zA-Z]+[[:space:]]+[0-9$][^[:space:]]*|-[a-zA-Z]+|<[^[:space:]]*/, "", v)
        n_ = split(v, vv, /[[:space:]]+/); rv = "REPLY"; for (k = n_; k >= 1; k--) if (vv[k] ~ /^[A-Za-z_][A-Za-z0-9_]*$/) { rv = vv[k]; break }
        if (SP == 0 || pre ~ /(^|[;&|({`[:space:]])(if|while|until|elif)[[:space:]]+$/ || pre ~ /(!|&&|\|\||\$\(|`)[[:space:]]*$/ || rest ~ /^[^;]*(&&|\|\|)/) row("W-TIMEOUT", ln, orig)
        else { LS[SP] = 1; PQ = 1; PQL = ln; PQT = orig; NPR++; PRV[NPR] = rv; PRF[NPR] = REL; PRL[NPR] = ln; PRT[NPR] = substr(orig, 1, 160) }
      }
    } else if (t == "while" || t == "until" || t == "for") {
      # a `for` is a bound only over a COUNTED list: `$(seq ...)`, `{1..N}`, or literal numbers
      SP++; LH[SP] = ln; LT[SP] = orig; LS[SP] = 0; INC[SP] = linc; CMP[SP] = lcmp; Z[SP] = " "; RSP[SP] = 1
      # the body's leading `v=<integer>` resets, read after `do` on this line or from the body's first line
      if (match(rest, /(^|[;[:space:]])do([[:space:]]+|$)/)) { bd = substr(rest, RSTART + RLENGTH); if (bd ~ /[^[:space:]]/) { Z[SP] = resets(bd); RSP[SP] = 0 } }
      LF[SP] = (t == "for" && rest ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+(\$\(seq[[:space:]]|\{[0-9]+\.\.|[0-9]+([[:space:]]+[0-9]+)*[[:space:]]*(;|$|[[:space:]]do))/)
    } else if (t == "done") {
      if (SP > 0) {
        if (LS[SP] && (LF[SP] || both(INC[SP], CMP[SP], Z[SP]))) row("W-BOUND", LH[SP], LT[SP])
        SP--
      }
    } else {
      # a sleep: its argument
      if (match(rest, /^[[:space:]]*"?(\$\{?[A-Za-z0-9_@*][A-Za-z0-9_:-]*\}?|[0-9]*\.?[0-9]+)/)) {
        a = substr(rest, RSTART, RLENGTH); gsub(/[[:space:]"]/, "", a)
        if (a ~ /^\$\{?[@*]/) { }
        else if (a ~ /^[0-9.]+$/ && a + 0 == 0) { }
        else if (SP > 0) LS[SP] = 1
        else row("W-SLEEP", ln, orig)
      }
    }
    r = rest
  }
}
function code(s, ln, orig,   m, k, j, nl, L) {
  NEX = 0; m = mask(s); LASTM = m; scan(m, ln, orig)
  for (k = 1; k <= NEX; k++) {
    # an executed string: scanned with its own quote state and loop stack
    sQ = STK; sSP = SP; STK = "c"; SP = 0
    gsub(/\\n/, "\n", EX[k]); nl = split(EX[k], L, "\n")
    for (j = 1; j <= nl; j++) scan(mask(L[j]), ln, orig)
    STK = sQ; SP = sSP
  }
}
END { flush() }
FNR == 1 {
  flush(); PQ = 0
  REL = substr(FILENAME, length(ROOTP) + 1); STK = "c"; split("", DP); SP = 0; HD = ""; CAP = 0
  print "F\t" REL
}
# an allowlist anchor: a TRAILING comment `# bl868-allow: <id>` closing the line
match($0, /#[[:space:]]*bl868-allow:[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*$/) {
  mk = substr($0, RSTART); sub(/^#[[:space:]]*bl868-allow:[[:space:]]*/, "", mk); sub(/[[:space:]]+$/, "", mk)
  print "M\t" REL "\t" FNR "\t" mk
}
HD != "" {
  t = $0; if (HDT) sub(/^\t+/, "", t)
  if (t == HD) { HD = ""; STK = OQ; SP = OSP; next }
  if (HDX) code($0, FNR, $0)
  next
}
{
  code($0, FNR, $0)
  # a heredoc opened in CODE (read off the masked line, so `<<` inside a string is data); its word from the raw line
  if (match(LASTM, /<<-?[[:space:]]*['"]?[A-Za-z_\\][A-Za-z0-9_]*/) && substr(LASTM, RSTART, 3) != "<<<" && substr(LASTM, RSTART - 1, 1) != "<") {
    h = substr($0, RSTART); match(h, /^<<-?[[:space:]]*['"]?\\?[A-Za-z_][A-Za-z0-9_]*['"]?/); h = substr(h, 1, RLENGTH); sub(/\\/, "", h); HDT = (h ~ /^<<-/); sub(/^<<-?[[:space:]]*['"]?/, "", h); sub(/['"]$/, "", h); HD = h
    # the body has its own quote state and loop stack, stacked above the enclosing code's
    OQ = STK; OSP = SP; STK = "c"; SP = 0
    # the body is EXECUTED only when the heredoc writes a file (`cat > f`, `tee f`) or feeds a shell; a heredoc
    # read into a variable (`read -r -d '' X <<'E'`) or fed to any other program is data
    HDX = (LASTM ~ /(^|[;&|({[:space:]])(cat|tee)[[:space:]][^|]*>|(^|[;&|({[:space:]])tee[[:space:]]|(^|[;&|({[:space:]])(bash|sh)([[:space:]]+-s)?[[:space:]]*(<<|$)/)
  }
}
AWK

# h9_scan <root> <abs-list> <out>: H9's rows over every file of <abs-list> (absolute paths under <root>). Writes <out>.raw, <out>.rows (W rows, sorted) and <out>.marks; prints the BROKEN
# reason and returns 2 when it could not measure (an empty list, an unreadable inert list, a file listed and not opened).
h9_scan() {
  local r="$1" o="$3" n s
  n="$(awk 'END { print NR }' "$2")"
  [ "$n" -gt 0 ] || { echo "BROKEN: H9 listed 0 files under $r"; return 2; }
  set -f; IFS='
'
  # shellcheck disable=SC2046
  set -- $(cat "$2"); unset IFS; set +f
  awk -v ROOTP="$r/" "$H9_AWK" "$@" > "$o.raw" || { echo "BROKEN: the H9 wait scan failed"; return 2; }
  s="$(grep -c '^F	' "$o.raw")" || s=0
  [ "$s" -eq "$n" ] || { echo "BROKEN: H9 listed $n files, scanned $s"; return 2; }
  grep '^W-' "$o.raw" | LC_ALL=C sort -u > "$o.rows" || :
  grep '^M	' "$o.raw" > "$o.marks" || :
  return 0
}

# h9_join <allow> <rows> <marks> <keep> <notes>: the W rows NOT suppressed go to <keep>; a W-ALLOW-STALE row per
# allowlist row whose id is on no marked line or on more than one goes to stdout; a NOTE per marked line the scan
# did not flag goes to <notes>. A row suppresses every W row on the ONE line carrying its id in its path, and
# nothing when the id is on zero or several lines, so a copied marker never absorbs a second site. A marker whose
# id has no row suppresses nothing and is itself a W-ALLOW-STALE row (stale in both directions). Returns 2 on a malformed or duplicate row (this file's own text is wrong).
h9_join() {
  awk -F'\t' -v KEEP="$4" -v NOTES="$5" '
    FILENAME == ARGV[1] { if ($0 ~ /^#/ || $0 == "") next
      if (NF != 3 || $1 == "" || $2 == "" || $3 == "" || $2 !~ /^[A-Za-z0-9_.-]+$/) { print "validate-fixture-hygiene: H9 malformed allowlist row: " $0 > "/dev/stderr"; bad = 1; next }
      if ($2 in AP) { print "validate-fixture-hygiene: H9 duplicate allowlist id " $2 > "/dev/stderr"; bad = 1; next }
      AP[$2] = $1; ids[++n] = $2; next }
    FILENAME == ARGV[3] { if (!($4 in AP)) ORPH[++no] = $2 "\t" $4 "\t" $3 "\tno allowlist row names that id"
      else if (AP[$4] == $2) { C[$4]++; L[$4] = $2 ":" $3 }
      else ORPH[++no] = $2 "\t" $4 "\t" $3 "\tits allowlist row names " AP[$4] ", not this file"
      next }
    { R[++nr] = $0; p = $2; key[nr] = p }
    END {
      if (bad) exit 2
      for (k = 1; k <= n; k++) { id = ids[k]
        if (C[id] + 0 == 1) { SUP[L[id]] = id; continue }
        print "W-ALLOW-STALE\t" AP[id] "\t" id "\t" (C[id] + 0 == 0 ? "no line carries # bl868-allow: " id : "the marker is on " C[id] " lines, want exactly 1") }
      for (k = 1; k <= no; k++) { split(ORPH[k], o, "\t"); print "W-ALLOW-STALE\t" o[1] "\t" o[2] "\tline " o[3] " carries # bl868-allow: " o[2] " and " o[4] }
      for (j = 1; j <= nr; j++) if (key[j] in SUP) HIT[key[j]] = 1; else print R[j] > KEEP
      for (s in SUP) if (!(s in HIT)) print "validate-fixture-hygiene: H9 NOTE -- " s " carries # bl868-allow: " SUP[s] " and the scan flags nothing there (the wait was fixed; drop the row and the marker)" > NOTES
      close(KEEP); close(NOTES) }' "$1" "$2" "$3" || return 2
  [ -f "$4" ] || : > "$4"; [ -f "$5" ] || : > "$5"
  return 0
}

# --- the corpus ----------------------------------------------------------------------------------------------------
out="$(run_all "$ROOT" "$WORK/c")"; crc=$?
if [ "$crc" -ne 0 ]; then echo "validate-fixture-hygiene: REFUSED -- $out" >&2; exit 2; fi
t1="$(awk -F'\t' '$1 == "T" && $2 == "H1" { print $3 }' "$WORK/c.scan")"; t2="$(awk -F'\t' '$1 == "T" && $2 == "H2" { print $3 }' "$WORK/c.scan")"
t6="$(awk -F'\t' '$1 == "T" && $2 == "H6" { print $3 }' "$WORK/c.scan")"
if [ "${t1:-0}" -lt 1 ] || [ "${t2:-0}" -lt 1 ] || [ "${t6:-0}" -lt 1 ]; then
  echo "validate-fixture-hygiene: REFUSED -- a grammar stopped matching on the corpus (H1 candidates ${t1:-0}, H2 candidates ${t2:-0}, H6 lib sources ${t6:-0}); this is not a clean tree." >&2
  exit 2
fi

if [ "$MODE" = derive10 ]; then
  # Every H10/H11 offender and every listed one still offending, one `<fixture>:<clause>\t<reason>` row; a committed
  # row keeps its reason (keyed on field 1).
  awk -F'\t' 'FILENAME == ARGV[1] { if ($0 !~ /^[[:space:]]*(#|$)/ && NF >= 2) { x = $1; gsub(/[[:space:]]/, "", x); R[x] = $2 } next }
    $1 == "H10LISTED" { k = $2 } $1 == "H10" { k = $2 ":report" } $1 == "H11" { k = $2 ":hook-drive" }
    $1 ~ /^H1[01](LISTED)?$/ { print k "\t" ((k in R) ? R[k] : (k ~ /:report$/ ? "defines its own ok/bad; predates lib/report.sh" : "runs a pre-push hook by hand; predates lib/hook-drive.sh")) }' \
    "$WORK/c.h10allow" "$WORK/c.h10" | LC_ALL=C sort
  exit 0
fi
if [ "$MODE" = derive14 ]; then
  # Every fixture with a hand `git init` line, listed or not, one `<fixture>\t<reason>` row; a committed row keeps its
  # reason (keyed on field 1).
  awk -F'\t' 'FILENAME == ARGV[1] { if ($0 !~ /^[[:space:]]*(#|$)/ && NF >= 2) { x = $1; gsub(/[[:space:]]/, "", x); R[x] = $2 } next }
    $1 == "H14" || $1 == "H14LISTED" { print $2 "\t" (($2 in R) ? R[$2] : "predates H14: runs git init by hand") }' \
    "$WORK/c.h14allow" "$WORK/c.h14" | LC_ALL=C sort
  exit 0
fi
if [ "$MODE" = derive8 ]; then
  # Every not-SCRUBBED fixture, one `<fixture>\t<reason>` row. A fixture already a row of the committed list keeps
  # its reason (keyed on field 1, so a re-derive on a later tip never rewrites a hand-written reason); a new row gets
  # its kind's reason. The two fixtures whose mutant battery selects its subject through an AI_DLC_* variable get
  # the reason that the channel must move first: a scrub would erase their mutant selection.
  awk -F'\t' 'FILENAME == ARGV[1] { if ($0 !~ /^[[:space:]]*(#|$)/ && NF >= 2) { x = $1; gsub(/[[:space:]]/, "", x); R[x] = $2 } next }
    $1 == "H8DER" { f = $2
      if (f in R) r = R[f]
      else if (f == "retired-fixture-orphan") r = "its mutant battery selects the subject through AI_DLC_RFO_DETECT; that channel must move to argv before run.sh can be scrubbed"
      else if (f == "consumer-machinery-inventory") r = "its mutant battery selects the subject through AI_DLC_CMI_VALIDATOR; that channel must move to argv before run.sh can be scrubbed"
      else if ($3 == "order") r = "run.sh starts a script or sources a file before its AI_DLC_* scrub; unexposed at the env-scrub census"
      else r = "run.sh carries no AI_DLC_* scrub; unexposed at the env-scrub census, so it changed no verdict under a hostile environment"
      print f "\t" r }' "$WORK/c.h8allow" "$WORK/c.h8" | LC_ALL=C sort
  exit 0
fi

rc=0
echo "validate-fixture-hygiene: $(awk 'END { print NR }' "$WORK/c.list") fixture .sh scanned; judged $t1 H1 \`-d …/.git\` test(s) and $t2 H2 declared-tool \`command -v\` site(s)"
for arm in H1 H2 H3 H6 H12; do
  if grep -q "^$arm	" "$WORK/c.verdict"; then
    rc=1; echo "FAIL $arm:"
    awk -F'\t' -v A="$arm" '$1 == A { print "    " $2 ": " substr($3, 1, 160) }' "$WORK/c.verdict"
    case "$arm" in
      H1) echo "  A \`-d …/.git\` whose absent branch exits 0 SKIPs green in every linked worktree, where .git is a file. Use \`git -C <root> rev-parse --git-dir\`, or exit 2 FIXTURE BROKEN." ;;
      H2) echo "  A declared tool (tools.decl) whose absence exits 0 is a green skip on a direct run. Exit 2, FIXTURE BROKEN." ;;
      H3) echo "  /bin/sh reads no BASH_ENV, so the invocation counter cannot see this start. Start it with bash." ;;
      H6) echo "  A source of core/fixtures/lib/<x>.sh with no failure guard runs on when the file is absent, and the fixture reads green with fewer arms. End the line with: || { echo \"FIXTURE BROKEN: cannot source lib/<x>.sh\" >&2; exit 2; }" ;;
      H12) echo "  H12: a fixture proves a product feature with its own arms and carries no mutation battery. Delete the mutant_killed / need_base / matrix_row / mkmut / mut_copy / mutate_file calls and definitions, the # MUTANT-MATRIX header lines and the lib/matrix.sh source from the named file." ;;
    esac
  fi
done
awk -F'\t' '$1 == "H8SCRUB" { print "H8 SCRUBBED " $2 }' "$WORK/c.h8"
n8s="$(grep -c '^H8SCRUB	' "$WORK/c.h8")" || n8s=0; n8l="$(grep -c '^H8LISTED	' "$WORK/c.h8")" || n8l=0
echo "validate-fixture-hygiene: H8 $n8s fixture(s) SCRUBBED, $n8l allowlisted unscrubbed"
if grep -qE '^(H8|H8STALE|H8DUP|H8NOREASON)	' "$WORK/c.h8"; then
  rc=1; echo "FAIL H8:"
  awk -F'\t' '$1 ~ /^H8(STALE|DUP|NOREASON)?$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.h8"
  echo "  H8: put the env-derived scrub, \`for _v in \$(env | sed -n 's/^\\(AI_DLC_[A-Za-z0-9_]*\\)=.*/\\1/p'); do unset \"\$_v\"; done\`, as the first statement after \`set -u\` in run.sh, above every script it starts and every file it sources (lib/preamble.sh excepted). A bare run inherits the operator's AI_DLC_* tunables, which hermetic-run.sh never passes, so an unscrubbed fixture can change verdict outside the gate. H8STALE/H8DUP/H8NOREASON: fix $H8_ALLOW_REL."
fi
h8m4_out="$(m4 "$ROOT" "$ROOT/$H8_ALLOW_REL" "$WORK/h8m4-root-base.txt" "$H8_ALLOW_REL" H8-M4 \
  "do not list the fixture; give its run.sh the env-derived AI_DLC_* scrub above every start, and drop the row.")" || rc=1
echo "$h8m4_out"
n10l="$(grep -c '^H10LISTED	' "$WORK/c.h10")" || n10l=0
echo "validate-fixture-hygiene: H10/H11 $n10l allowlisted skeleton deviation(s)"
if grep -qE '^(H10|H11|H10STALE|H10DUP|H10NOREASON)	' "$WORK/c.h10"; then
  rc=1; echo "FAIL H10/H11:"
  awk -F'\t' '$1 ~ /^H1[01](STALE|DUP|NOREASON)?$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.h10"
  echo "  H10: report through core/fixtures/lib/report.sh (ok, bad, report_end); a run.sh defines no ok() or bad() of its own. H11: run a pre-push hook through hook_drive (core/fixtures/lib/hook-drive.sh), never \`bash <hook>\` by hand. The contract is .claude/rules/fixture-contract.md. H10STALE/H10DUP/H10NOREASON: fix $H10_ALLOW_REL."
fi
h10m4_out="$(m4 "$ROOT" "$ROOT/$H10_ALLOW_REL" "$WORK/h10m4-root-base.txt" "$H10_ALLOW_REL" H10-M4 \
  "do not list the fixture; move it onto core/fixtures/lib/report.sh or hook_drive, and drop the row." \
  "<fixture>:<clause> key")" || rc=1
echo "$h10m4_out"
n13="$(awk -F'\t' '$1 == "N13" { print $2 }' "$WORK/c.h13")"; n13l="$(grep -c '^H13LISTED	' "$WORK/c.h13")" || n13l=0
echo "validate-fixture-hygiene: H13 ${n13:-0} hand extraction line(s) of a record-binding hook span; $n13l allowlisted fixture(s) carry them"
if grep -qE '^(H13|H13STALE|H13DUP|H13NOREASON)	' "$WORK/c.h13"; then
  rc=1; echo "FAIL H13:"
  awk -F'\t' '$1 ~ /^H13(STALE|DUP|NOREASON)?$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.h13"
  echo "  H13 (BL-1130): extract a FIXTURE_POOL or RECORD_HOME span through pool_span (core/fixtures/lib/pool-span.sh), never by a sed or awk of its BEGIN marker. A span sourced with no store of its own resolves its record homes in the real verdict store, so a plain \`bash core/fixtures/<f>/run.sh\` files the world's records there; pool_span's first line defaults the store to the sourcing world's. H13STALE/H13DUP/H13NOREASON: fix $H13_ALLOW_REL."
fi
h13m4_out="$(m4 "$ROOT" "$ROOT/$H13_ALLOW_REL" "$WORK/h13m4-root-base.txt" "$H13_ALLOW_REL" H13-M4 \
  "do not list the fixture; extract the span through pool_span (core/fixtures/lib/pool-span.sh), and drop the row.")" || rc=1
echo "$h13m4_out"
n14="$(awk -F'\t' '$1 == "N14" { print $2 }' "$WORK/c.h14")"; n14l="$(grep -c '^H14LISTED	' "$WORK/c.h14")" || n14l=0
echo "validate-fixture-hygiene: H14 ${n14:-0} hand git init line(s); $n14l allowlisted fixture(s) carry them"
if grep -qE '^(H14|H14STALE|H14DUP|H14NOREASON)	' "$WORK/c.h14"; then
  rc=1; echo "FAIL H14:"
  awk -F'\t' '$1 ~ /^H14(STALE|DUP|NOREASON)?$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.h14"
  echo "  H14 (BL-1153): build a fixture's git world through core/fixtures/lib/world.sh -- \`world_repo <dir>\` (a repository with one root commit) or \`world_git init -q <dir>\` -- never a hand \`git init\`. world_git unsets every leaked GIT_* location and fixes the identity, the branch, hooks and signing; a hand init under an armed GIT_DIR writes into the caller's repository. H14STALE/H14DUP/H14NOREASON: fix $H14_ALLOW_REL."
fi
h14m4_out="$(m4 "$ROOT" "$ROOT/$H14_ALLOW_REL" "$WORK/h14m4-root-base.txt" "$H14_ALLOW_REL" H14-M4 \
  "do not list the fixture; build its world through world_repo or world_git init (core/fixtures/lib/world.sh), and drop the row.")" || rc=1
echo "$h14m4_out"
e1_out="$(e1_run "$ROOT" "$WORK/e1c")"; e1rc=$?
if [ "$e1rc" -ne 0 ]; then echo "validate-fixture-hygiene: REFUSED -- E1: $e1_out" >&2; exit 2; fi
ne1="$(awk 'END { print NR }' "$WORK/e1c.e1list")"; ni1="$(awk 'END { print NR }' "$WORK/e1c.inert")"
if [ -s "$WORK/e1c.verdict" ]; then
  rc=1; echo "FAIL E1:"
  awk -F'\t' '{ print "    " $1 " " $2 }' "$WORK/e1c.verdict"
  echo "  INERT: a tracked receipt*.sh that no run/seed/lib.sh, hook or scripts/*.sh runs -- no fixture executes it (a verify: line is not a runner). Wire it into its fixture's run.sh, or delete it. STALE/DUP/NOREASON: fix $E1_ALLOW_REL."
fi
e1m4_out="$(m4 "$ROOT" "$ROOT/$E1_ALLOW_REL" "$WORK/e1m4-root-base.txt" "$E1_ALLOW_REL" E1-M4 \
  "do not list the receipt; wire it into its fixture's run.sh, or delete it, and drop the row.")" || rc=1
echo "$e1m4_out"
# H9 over the tree: every file of the run_all corpus
h9_out="$(h9_scan "$ROOT" "$WORK/c.abs" "$WORK/h9c")"; h9rc=$?
if [ "$h9rc" -ne 0 ]; then echo "validate-fixture-hygiene: REFUSED -- H9: $h9_out" >&2; exit 2; fi
h9a="$ROOT/$H9_ALLOW_REL"; [ -f "$h9a" ] || { h9a="$WORK/h9c.allow"; : > "$h9a"; }
h9_join "$h9a" "$WORK/h9c.rows" "$WORK/h9c.marks" "$WORK/h9c.keep" "$WORK/h9c.notes" > "$WORK/h9c.stale" \
  || { echo "validate-fixture-hygiene: REFUSED -- H9's allowlist join failed (a malformed or duplicate row of $H9_ALLOW_REL)" >&2; exit 2; }
cat "$WORK/h9c.notes" >&2
# the three counts in one read: every W row, the rows the allowlist kept, the stale allowlist rows
h9n="$(awk -v A="$WORK/h9c.rows" -v B="$WORK/h9c.keep" '{ n[FILENAME == A ? 1 : FILENAME == B ? 2 : 3]++ }
  END { print (n[1] + 0) " " (n[2] + 0) " " (n[3] + 0) }' "$WORK/h9c.rows" "$WORK/h9c.keep" "$WORK/h9c.stale")"
nh9r="${h9n%% *}"; nh9s="${h9n##* }"; nh9k="${h9n#* }"; nh9k="${nh9k%% *}"
echo "validate-fixture-hygiene: H9 $nh9r bounded-wait row(s), $((nh9r - nh9k)) on an allowlisted bl868-allow line"
if [ "$nh9k" -gt 0 ] || [ "$nh9s" -gt 0 ]; then
  rc=1; echo "FAIL H9:"
  awk -F'\t' '{ print "    " $1 " " $2 ": " substr($3, 1, 160) }' "$WORK/h9c.keep"
  awk -F'\t' '{ print "    " $1 " " $2 " " $3 ": " $4 }' "$WORK/h9c.stale"
  echo "  H9 (BL-868): a fixture verdict that elapsed time or an iteration bound can decide moves with load. Wait on the CONDITION, unbounded (\`until [ -e \"\$f\" ]; do sleep 0.1; done\`), or on a pid; never a fixed sleep, a SECONDS/date deadline, a counted poll or a timeout. A site where no elapsed time can decide a verdict ends in \`# bl868-allow: <id>\` and gets a row of $H9_ALLOW_REL with its reason. W-ALLOW-STALE: fix that row or its marker."
fi
nlist="$(awk 'END { print NR }' "$WORK/c.list")"
if [ "$rc" = 0 ]; then
  echo "OK: validate-fixture-hygiene -- $nlist fixture .sh scanned; H1 $t1 / H2 $t2 candidate test(s), no offender; H6 $t6 lib source(s), all guarded; H12 no mutation battery in a run.sh or lib.sh; E1 $ne1 receipt(s), $ni1 inert and allowlisted; H9 $nh9r bounded-wait row(s), every one allowlisted; H13 ${n13:-0} hand span extraction(s), every one allowlisted; H14 ${n14:-0} hand git init line(s), every one allowlisted."
fi
exit "$rc"
