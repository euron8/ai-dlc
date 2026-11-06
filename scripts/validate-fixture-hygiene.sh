#!/usr/bin/env bash
# validate-fixture-hygiene.sh -- static hygiene of the fixture corpus: no false SKIP on a condition true in normal use,
# no `sh` start the invocation counter cannot see, and a mutant battery declares its mutant x arm matrix.
#
# usage:  validate-fixture-hygiene.sh            check the tree (exit 0 clean, 1 FAIL, 2 self-probe red or broken)
#         validate-fixture-hygiene.sh --derive   print the derived H5 allowlist rows, `<fixture>\t<reason>`
#
# Standalone pre-suite step in .githooks/pre-push (the validate-mutant-kills.sh precedent), deliberately NOT an arm of
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
# THE ARMS. Each runs a self-probe FIRST, under mktemp, in both directions; the probe's verdict per arm is printed.
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
#     and a bare `sh` (control: 116 `env -u` lines in the same corpus). `env -u NAME sh` is not parsed as a start. Final hits: 6, all OFFENDERS: readset-skip:1331
#     (`exec sh -c`), readset-skip:1827 and :2177 and readset-stage1-verdict:900 (`sh -c 'exit 0' &`),
#     self-update-gate:3401 (`sh scripts/…`), self-update-gate:5025 (`git show … | sh;`).
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
# H5  the mutant matrix. Population is the UNION, mapped through shard stubs to their IMPL by the ONE resolver,
#     `validate-fixture-invocations.sh --impl-of` (`[exec ]bash "$IMPL" --group`):
#       S1   a function whose name contains `mut` (any case) is defined in the fixture's files;
#       S2   a fixture file carries `cmp -s` in code and the word `mutant` (any case) anywhere;
#       MKA  a row of scripts/mutant-kills-allowlist.txt, which validate-mutant-kills.sh's M1/M2 hold equal to its
#            --derive set on every green push (read as data, so the probe can seed it);
#       MKC  any tracked fixture .sh, not only run.sh, calling `mutant_killed` in code (core/fixtures/lib excluded).
#     A FLOOR OF UNKNOWN DEPTH: being a mutant is semantic, not lexical; a battery that matches none of the four is
#     not seen. A member with no block FAILs unless it is a row of scripts/fixture-matrix-allowlist.txt.
#     THE BLOCK lives in the fixture's run.sh (the IMPL's, for a shard family; a block in a stub FAILs), as comment
#     lines, one of:
#       # MUTANT-MATRIX <m> decides=<arm>[,<arm>…] twins=<arm>[,<arm>…]
#       # MUTANT-MATRIX <m> decides=<arm>[,<arm>…] twins=- why=<clause>
#       # MUTANT-MATRIX-FULL <m> worlds=<w>[,<w>…] why=<clause>
#       # MUTANT-MATRIX-CONTROL <name> why=<clause>
#       # MUTANT-MATRIX-DYNAMIC <label> why=<clause>
#       # MUTANT-MATRIX-REMEASURE bash core/fixtures/<this fixture>/run.sh --matrix      (exactly one)
#     An arm token (decides, twins) is one opaque id matching ^[A-Za-z0-9_+-]+(\.[A-Za-z0-9_+-]+)*$ (`+` admitted
#     because matrix cell labels are built as `<dir>+<tag>`), no escaping, a dot only between two other characters
#     (a leading, trailing or doubled dot refused); a mutant name or label additionally admits `:`
#     (^[A-Za-z0-9_:+-]+(\.[A-Za-z0-9_:+-]+)*$), and the same class reads a literal mutant_killed name; whitespace
#     and `=` are never in either, being the field delimiters. `<label>.<cell>` is the form where one ok label scores several cells (H5
#     does not split it). Worlds match ^[A-Za-z0-9_.-]+$. decides and twins non-empty, no duplicates, no twin
#     inside its decides. `twins=-` only with a non-blank why=; `-` mixed into a list refused; why= on a row with real
#     twins refused; any other field (`log=`) refused. Each name carries exactly one MATRIX / FULL / CONTROL line. At
#     least one MATRIX or FULL line. H5 does NOT check that the REMEASURE mode is implemented: no static test
#     separates a real `--matrix` handler from an echo or a usage string; the integrator's run is the proof.
#     THE JOIN is keyed on the EMISSION SITE, `mutant_killed <flag> <name> <message>`, and on nothing else: every
#     literal name in its 2nd argument carries a MATRIX or FULL line; a mutant_killed name on a CONTROL line FAILs;
#     a non-literal mutant_killed name FAILs unless the block carries a MUTANT-MATRIX-DYNAMIC line (a declaration,
#     never the proof: the runtime join is validate-fixture-invocations.sh's J5). No argument of a mutation helper
#     is read as a name: helpers put other things first (readset-skip's `ck_mut` and `vs_hmut` take a WORLD letter
#     there), so a helper call needs neither a row nor a DYNAMIC line.
#     THE LIMIT, a property of joining at the emission site: a name that never reaches `mutant_killed` statically is
#     covered only by J5, which reads the names mutant_killed actually reports at runtime. A battery still on
#     scripts/mutant-kills-allowlist.txt (MKA) does not route through mutant_killed yet, so for it H5 checks block
#     PRESENCE and row SHAPE only, and no name of it is joined; BL-828's migration to mutant_killed closes that.
#     FP SET. The union over the b245-p1 tree is 214 fixtures after shard stubs map to their IMPL (rule 7's estimate
#     was 210; the gap is this branch's two new batteries plus the census counting every fixture .sh, not run.sh
#     only): S1 158, S2 212, MKA 124, MKC 4 at base. `_kill`/`kill_by` are NOT S1 tokens (they match process
#     reapers). The block and unblocked-member counts are PRINTED by every run (the `H5 N block(s), M unblocked
#     member(s)` line) and are not fixed in this comment; the unblocked members are the derived allowlist. Being a
#     member is a floor claim, not a defect claim, so the allowlist IS
#     the false-positive set, enumerated by --derive.
# THE ALLOWLIST scripts/fixture-matrix-allowlist.txt, rows `<fixture>\t<reason>`, DOWN-ONLY:
#     a member without a block and without a row FAILs; a row whose fixture is not such a member (it gained a block,
#     left the floor, or is gone) is STALE and FAILs; a duplicate row, and a row with no reason, FAIL; and a row whose
#     fixture is not a row of the list at origin/main FAILs (keyed on field 1, so rewording a reason is not an added
#     row). Two states have no base and SKIP with the reason printed: origin/main does not resolve, and origin/main
#     carries no list (the release that first ships it).
# E1  an INERT receipt: a tracked `core/fixtures/*/receipt*.sh` or `scripts/receipt*.sh` that nothing reads, so no gate
#     ever runs it. THE PREDICATE is `inert()` between the `# INERT_BEGIN` / `# INERT_END` markers below, the ONE copy:
#     core/fixtures/fixture-hygiene/receipt-bl868.sh extracts and sources it for its class W skip, in its `ledger`
#     mode; E1 calls its `runners` mode. For E1 a READER is a RUNNER only: a non-comment line of a tracked
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
#     the allowlist. receipt-bl868 keeps the ledger clause on purpose: a receipt reached through a
#     live verify: line IS executed, by the backlog-receipts pre-push step, so its class W scan must still read it.
#     KNOWN ACQUITTALS, asserted by the self-probe: a name inside a message string (zz9, `echo "receipt-x.sh …"`)
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
#     FP SET, how it reached its value. The predicate was lifted unchanged from receipt-bl868.sh, where it decided
#     which receipts that receipt skips; on bb9284bcc its old and its lifted copy give byte-identical output over
#     receipt-bl868's own list (86 inert, 367 reader files). Widening the population to scripts/receipt*.sh added
#     scripts/*.sh as readers for those receipts only, with self-reference excluded (a receipt naming itself, e.g. in a
#     usage line, is not a reader). The corpus does not exercise that exclusion today (0 of the 4 names itself on a
#     non-comment line; measured both ways, 4 inert either way); the self-probe's zz12 is its subject. On
#     bb9284bcc E1 flags 90: the 72 the BL-915 census classed uninvoked (68 fixture receipts plus the 4 scripts/
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
# H7  a twin that names no arm (BL-921). POPULATION: the `<fixture>:<twin>` pairs of the MUTANT-MATRIX rows H5
#     ACCEPTED with real twins (a malformed row is H5's, never reported twice), mapped to the IMPL like every H5 fact.
#     FILE SET: every tracked .sh of the fixture's directory, plus every shard stub `--impl-of` maps to it
#     (unit-parts.sh, unit-arms.sh, matrix.sh, lib.sh are in it). A twin T RESOLVES when T, or its label before the
#     first `.` (`<label>.<cell>`), is a label the file set EMITS. THE JOIN is keyed on enumerated EMISSION FORMS, each
#     read off its argument position on the UNMASKED line (a `\`-continued statement joined), CODE lines only: a
#     comment and a heredoc body are never read. A word carrying `$` or a backtick is never a label.
#     NO FORM YIELDS A BARE NUMBER (a count, an rc, a cell index is never a label).
#       1   the first word of the message argument of `ok`, `bad`, `pass` or `fail` in command position. This is the
#           label the program PRINTS for that arm -- the emission site the verdict line is read from, not prose
#           about the program -- which is why a message string counts here and nowhere else. A message opening
#           with an article and ONE blank (`ok "a dispatch wrote …"`) is prose and yields nothing; `eq "a: …"`
#           and `bad "a  the …"` (a column) keep `a`.
#       1b  the first word of the FIRST quoted message (one carrying a blank) passed to a function the file set or
#           core/fixtures/lib defines: the fixture's own `ok`-like printer (`element1-item-ref "V15 …"`, `rc_is "B7a …"`).
#           A later quoted argument is data (a program text, a replacement), and the article rule of 1 applies.
#       2   `matrix_row`'s 2nd argument.          3  the <T> of an `arm_<T>()` definition.
#       4   a `case` pattern opening a line, or after `;;` on it, `T)`, `A|B)`, `*" T "*)`: each `|` alternative that
#           is a bare word or one quoted word -- the arm dispatch of a verdict switch.
#       5   a literal argument of a call, in command position, to a function the file set or lib defines (`want T`,
#           `arm2 T`, `mcell X T`). NEVER an external tool's: `grep -q T`, `printf T`, `awk -v T=` hand a program
#           data, and the self-probe seeds exactly those beside a dangling twin.
#       6   a quoted literal list with a blank, assigned in command position or by local/export, of roster
#           characters only (`ARMS="a b"`, `CC_WANT="a=allow:1 b=deny:0"`): a pure word list gives every word, any
#           other gives each item's key and every part of two or more characters. A list carrying an option, a
#           path or an English function word (`m="the label is absent"`) is a command or a sentence, never a roster.
#       7   a word of a `for <v> in <words>` list.  9  `B_<T>=`, the arm's baseline flag the mutant scoring reads.
#       8   a function name defined on a code line (the cell IS the function), joined in the judge and dropped for
#           any function that forms 1, 1b or 5 read as the PRINTER or callee (`ok`, `bad`, `want`, `tell`).
#     BUILT LABELS: scripts/twin-built-allowlist.txt, rows `<fixture>:<mutant>:<token>\t<reason>`, per KEY and
#     DOWN-ONLY (arm H7-M4, the shared m4, keyed on the full `<fixture>:<mutant>:<token>`, with M4's two SKIPs).
#     <mutant> is the MUTANT-MATRIX row's NAME, stable under line moves: a listed key acquits that one row's twin, so
#     a new row, or a new mutant reusing a listed built token, is an unlisted key and FAILs. An unresolved unlisted
#     key FAILs (H7, naming the key); a listed key whose twin now resolves, or that no accepted row of that fixture
#     and mutant carries, is H7STALE; a duplicate or a reasonless row FAILs. It is not a MUTANT-MATRIX-DYNAMIC
#     extension: nothing proves twins at runtime, and DYNAMIC is fixture-wide where this is per key.
#     STATED LIMITS: a listed `<fixture>:<mutant>:<token>` stays acquitted while its built label is unresolvable, so
#     it can go stale invisibly. Where the label before `.` is emitted (ledger-reverify's `row_is "Entry A"`
#     reaching any `Entry.<x>`), only the label half is checked, never the cell. A label emitted only through a variable, a data table (`echo "ph|red"`), an
#     arm_name()-style join, or a non-first word of a multi-word message is not seen -- those are the allowlist's
#     rows. An emission form still ACQUITS a twin that shares a real label word of its fixture's grammar: `a` in
#     dispatch-model-guard is a real cell (`CC_WANT`, `a)`), so a twin `a` there resolves whether or not that row
#     meant it.
#     NARROWING STORY, measured on f9c1196c0's tree plus this change's fixture-hygiene edits (432 fixture .sh before
#     receipt-bl921.sh was added, 433 after; the counts below are identical on both): 3093 twin occurrences in accepted rows, 1606
#     distinct `<fixture>:<twin>` pairs. Forms 1-3 only: 408 resolved, 1198 unresolved over 103 fixtures. A census
#     of what preceded each unresolved token showed case dispatch, roster lists, helper arguments and for-lists, so
#     forms 4-7 were added; a first form 5 taking EVERY literal word of a code line resolved all but 231 and was
#     REJECTED (it is a token grep: `awk -v c=`, a `grep -q` pattern and a printf format acquitted twins), replaced
#     by form 5 as above: 260 left. `\`-continuation joining, 1b, 8 and 9 took it to 222. Pairs resolved, by the FIRST
#     form in order 1,2,3,4,6,7,5,1b,8,9 that yields them: 1 203, 2 3, 3 219, 4 374, 6 293, 7 22, 5 237, 1b 17, 8 6,
#     9 10 (1384); resolved by that form ALONE: 5 232, 3 49, 6 46, 4 22, 1b 16, 7 16, 9 10, 8 6. 222 pairs were left.
#     SECOND NARROWING (BL-921 fold, a tip adversary's D2): the weak forms acquitted common non-label words. Measured
#     by seeding one row `twins=1,0,2,a,x,y,ok,bad,want,label,alpha,c7,Entry.bogus` into each of ledger-reverify,
#     dispatch-model-guard and layer-reference-resolution (39 seeded keys) and running the SHIPPED arm in a detached
#     worktree: 21 of 39 acquitted on 0adc3cf9f, 4 of 39 after. The four left: dispatch-model-guard `a` and
#     layer-reference-resolution `alpha`, `c7` are REAL labels of those fixtures (a cell roster, a case dispatch),
#     and ledger-reverify `Entry.bogus` resolves through its label half `Entry` (`row_is "Entry A"`, run.sh:600) --
#     the label-half limit above. The narrowings: no bare number from any form; form 8 dropped for a printer or
#     callee; form 1/1b skip an article-led prose message; 1b reads only the first quoted argument; form 4 reads
#     whole `|` alternatives, not every token-class fragment of a glob; form 6 refuses a list carrying an option,
#     a path, an English function word or a non-roster character, and drops one-character parts of a non-pure
#     list. One WIDENING: form 4 also reads a pattern after `;;` on the same line, which resolved 9 pairs the old
#     list carried (dispatch-model-guard exl, nodot, red, sameline-deny, zpad; story-provenance CR, DC, NR, S3).
#     Each of these 12 narrowings and the widening has a self-probe seed that its revert turns red (form 8's callee
#     join, the bare number, the article rule at both 1 and 1b, 1b's first-argument rule, form 4's whole
#     alternatives, form 6's option/path, function-word and character refusals and its one-character drop, the
#     `;;` widening, and the D1 key); a guard that stopped a word walk at an unclosed `$(` moved neither the probe
#     nor the corpus and was deleted. Over the corpus: 3093 keys
#     (`<fixture>:<mutant>:<token>`), 2692 resolved, 401 listed; 1383 of 1606 `<fixture>:<token>` pairs resolved,
#     223 listed. Pairs resolved by FIRST form in the order above: 1 201, 2 3, 3 219, 4 411, 6 244, 7 23, 5 251,
#     1b 16, 8 5, 9 10; by that form ALONE: 5 249, 3 49, 4 29, 6 26, 1b 15, 7 14, 9 10, 8 5; 883 pairs resolve only
#     through forms 4, 5, 6, 7, 1b or 8. Newly unresolved by the narrowing, 10 pairs, every one a built label, none a
#     true positive: spec-join-integrity 9 (arm_name() joins) and self-update-gate `ok` (an mx_row cell string).
#     The 401 keys are the allowlist, each reason citing the site that builds or prints the label, read in its
#     fixture: check-24 97, readset-skip 94, spec-join-integrity 66, ledger-reverify 48 (multi-word `row_is`
#     messages, of which H7 reads one word), self-update-gate 24, self-update-fixture-log 11, enforcement-map-sites
#     10, gate-remediation-deny 9, requirements-step 8, retired-layer-passage 6, and 28 over 12 more fixtures.
#     TRUE POSITIVES (a twin no code path emits): 0.
#
# ON THE BRANCH THAT SHIPS THIS, H2 AND H3 ARE RED BY DESIGN: their offenders sit in fixtures other units are
# rewriting, and H1-H3 carry NO allowlist (H1's one offender is fixed on that branch). The owner fixes them on the
# integrated tip, where this list is also re-derived.
#
# COST: a constant number of forks -- one git ls-files, one resolver call, one awk scan (two passes over the corpus),
# one judge awk, sorts -- the same again for the probe tree, and the M4 probe repos. E1 adds one probe repository
# (one commit), two e1_run passes (one over the probe, one over the tree), each a git ls-files, the inert() awk and
# the judge awk, and one ledger-mode inert() over the probe: measured with PATH shims in clean worktrees inside the
# repo, 213 execs on bb9284bcc and 322 with E1; with the archive clause removed, 306 against 325 on the same tree.
set -uo pipefail

MODE=check
case "${1:-}" in
  "") ;;
  --derive) MODE=derive ;;
  *) echo "usage: validate-fixture-hygiene.sh [--derive]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-fixture-hygiene: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2; exit 2
fi
RESOLVER="$HERE/validate-fixture-invocations.sh"
[ -f "$RESOLVER" ] || { echo "validate-fixture-hygiene: FAIL -- the shard-stub resolver $RESOLVER is absent" >&2; exit 2; }
ALLOW_REL="scripts/fixture-matrix-allowlist.txt"
E1_ALLOW_REL="scripts/inert-receipt-allowlist.txt"
H7_ALLOW_REL="scripts/twin-built-allowlist.txt"
MKA_REL="scripts/mutant-kills-allowlist.txt"

WORK="$(mktemp -d)" || { echo "validate-fixture-hygiene: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# --- the scan ------------------------------------------------------------------------------------------------------
read -r -d '' SCAN_AWK <<'AWK'
BEGIN { XS = "XXXXXXXXXXXXXXXX"; SQ = sprintf("%c", 39); EXITRE = "(^|[^A-Za-z0-9_$.-])exit([[:space:]]+0)?[[:space:]]*($|[;})&|\n])" }
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
function literal(w) { if (w ~ /[$`]/) return ""; gsub(/["\047]/, "", w); return (w ~ /^[A-Za-z0-9_:+-]+(\.[A-Za-z0-9_:+-]+)*$/ && w !~ /^-/) ? w : "" }
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
# --- H7: the labels a fixture EMITS, read off their argument positions on the unmasked line ----------------------
# `L <fx> <form> <label>`: form 1 the first word of the message argument of `ok`/`bad`/`pass`/`fail` in command
# position, 2 `matrix_row`'s 2nd argument, 3 the <T> of an `arm_<T>()` definition. A non-literal word is no label.
function lab7(w, f) {  # emit w as a form-f label when it is one token-class word and not a bare number (a count, an rc)
  if (w ~ /^[A-Za-z0-9_+-]+(\.[A-Za-z0-9_+-]+)*$/ && w !~ /^[0-9]+$/) print "L\t" FX "\t" f "\t" w
}
function case7(w,   n, a, k, x) {  # form 4: each `|` alternative that is a bare word or one quoted word (`*" T "*`)
  n = split(w, a, "|")
  for (k = 1; k <= n; k++) {
    x = a[k]
    if (x ~ /^\*["\047][[:space:]]*[^[:space:]"\047*]+[[:space:]]*["\047]\*$/ || x ~ /^["\047][^[:space:]"\047*]+["\047]$/) { gsub(/[*"\047[:space:]]/, "", x); lab7(x, 4) }
    else if (x !~ /[*?["\047[:space:]]/) lab7(x, 4)
  }
}
function list7(w,   n, a, k, x, m, b, j, pure) {  # form 6: the labels of a quoted literal roster list
  gsub(/^["\047]|["\047]$/, "", w)
  if (w ~ /[^A-Za-z0-9_.+:=|\/,()*;[:space:]-]/) return  # a program text or a sentence, never a roster
  n = split(w, a, /[[:space:]]+/)
  # an option or a path is a command string, and an English function word is prose (`m="the label is absent"`):
  # neither is a roster
  for (k = 1; k <= n; k++) if (a[k] ~ /^[-\/]/ || a[k] ~ /^(the|is|are|was|of|to|and|or|not|with|from|that|this|by|as|an)$/) return
  pure = 1; for (k = 1; k <= n; k++) if (a[k] !~ /^[A-Za-z0-9_.+-]+$/) pure = 0
  for (k = 1; k <= n; k++) {
    # a pure roster (`ARMS="A B C"`) gives every word; in any other list an item `K=V` or `K:V` (`a=allow:1`,
    # `R:gate-whole`) gives its key, and every part only when it is a word of two or more characters -- never the
    # `x` of `ord=3/7 x|null`
    m = split(a[k], b, /[*|:=]/)
    for (j = 1; j <= m; j++) if (pure || length(b[j]) > 1 || (j == 1 && a[k] ~ /^[A-Za-z0-9_.+-]+[=:]/)) lab7(b[j], 6)
  }
}
# a message opening with an English article and ONE blank (`ok "a dispatch wrote …"`, `ok "a PLAIN …"`,
# `"a ~~~ fence …"`) is prose; `eq "a: …"` and `bad "a  the …"` (two blanks: a column) keep `a` as the label
function article7(w) { return (w ~ /^["\047](a|an|the|A|An|The) [^[:space:]]/) }
function callee7(c) { if (!((FX, c) in CAL7)) { CAL7[FX, c] = 1; print "C\t" FX "\t" c } }  # a 1b/5 callee: never a form-8 label
function h7(i,   s, o, off, st, q, w, nm, cw, c, p, e, atc, fn, fs, dcl, rd, j) {
  # a `\`-continued statement is read once, joined, from its first line: a continuation line is never command position
  if (i > 1 && !HDL[i - 1] && M[i - 1] ~ /\\$/) return
  s = M[i]; o = O[i]; j = i
  while (s ~ /\\$/ && j < NL && !HDL[j + 1]) { j++; s = substr(s, 1, length(s) - 1) " " M[j]; o = substr(o, 1, length(o) - 1) " " O[j] }
  # a multibyte character tested alone against a bracket class aborts this awk (towc), so the word walk reads an
  # ASCII copy: each non-ASCII character becomes one `?`, keeping every position equal to the masked line's
  gsub(/[^\t -~]/, "?", o)
  # the code part of the unmasked line: cut at the masked comment (a `#` whose masked run of X reaches the end)
  if (match(s, /(^|[[:space:]])X+$/)) { c = RSTART + (substr(s, RSTART, 1) ~ /[[:space:]]/); if (substr(o, c, 1) == "#") o = substr(o, 1, c - 1) }
  # form 4: a `case` pattern opening the line, `T)`, `A|B)`, `*" T "*)`, the arm dispatch of a verdict switch
  if (match(s, /^[[:space:]]*(case[[:space:]].*[[:space:]]in[[:space:]]+)?\(?[^[:space:]()]+\)/)) {
    w = substr(o, 1, RSTART + RLENGTH - 2); sub(/^[[:space:]]*(case[[:space:]].*[[:space:]]in[[:space:]]+)?\(?/, "", w)
    if (w !~ /[$`]/ && w !~ /^[A-Za-z_][A-Za-z0-9_]*=/) case7(w)
  }
  # form 4, continued: a pattern after `;;` on the same line (`gap) … ;; full) …`)
  off = 0
  while (match(substr(s, off + 1), /;;[[:space:]]+\(?[^[:space:]()]+\)/)) {
    st = off + RSTART; q = st + RLENGTH; off = q - 1
    w = substr(o, st + 2, q - st - 3); sub(/^[[:space:]]+\(?/, "", w)
    if (w !~ /[$`]/) case7(w)
  }
  # forms 5-7, one walk over the shell words of the code part, tracking command position (line start, after
  # `;`, `&`, `|`, `(`, `)`, or a keyword). Form 5: a literal argument of a call to a FUNCTION the fixture's own
  # files or core/fixtures/lib define (`want T`, `arm2 T`, `mcell X T`) -- never of an external tool (`grep -q T`,
  # `printf T`, `awk -v T=`), whose arguments are data the fixture hands a program, not a label it prints. Form 6: a
  # quoted literal LIST with a blank in it, assigned in command position or by `local`/`export`/`readonly`
  # (`ARMS="a b c"`), the arm roster a dispatch loop walks. Form 7: a literal word of a `for <v> in <words>` list.
  p = 1; e = length(o); atc = 1; fn = 0; fs = 0; dcl = 0; rd = 0
  while (p <= e) {
    c = substr(o, p, 1)
    if (c ~ /[;&|()]/) { atc = 1; fn = 0; fs = 0; dcl = 0; rd = 0; p++; continue }
    if (c ~ /[<>]/) { rd = 1; p++; continue }
    if (c ~ /[[:space:]]/) { p++; continue }
    w = wordat(o, p); if (WEND <= p) { p++; continue }; p = WEND
    if (rd) { rd = 0; continue }
    if (atc && w ~ /^(then|do|else|elif|if|while|until|!|\{|\}|time|command|exec|nohup)$/) continue
    if ((atc || dcl) && match(w, /^[A-Za-z_][A-Za-z0-9_]*=/)) {
      # form 9: `B_<T>=…`, the arm's own baseline flag, which the mutant scoring reads as that arm's verdict
      if (w ~ /^B_[A-Za-z0-9_]+=/) { nm = w; sub(/^B_/, "", nm); sub(/=.*$/, "", nm); print "L\t" FX "\t9\t" nm }
      w = substr(w, RLENGTH + 1)
      if (w ~ /^["\047]/ && w !~ /[$`]/ && w ~ /[[:space:]]/) list7(w)
      continue
    }
    if (atc) {
      atc = 0; fn = ((FX, w) in FN7) || (w in LFN7); fs = (w == "for"); dcl = (w ~ /^(local|export|readonly|declare|typeset)$/)
      cw7 = w; nq7 = 0; continue
    }
    if (fs == 1) { fs = 2; continue }
    if (fs == 2) { fs = (w == "in") ? 3 : 0; continue }
    # any argument makes the defined function a CALLEE (`want "$1"`), which form 8 then never reads as a label
    if (fn) callee7(cw7)
    # form 1b: the first word of a quoted MESSAGE argument (one carrying a blank) of a fixture-defined function --
    # the label the fixture's own `ok`-like printer prints (`element1-item-ref "V15 bare …"`, `rc_is "B7a …"`).
    # Only the FIRST such argument is the message: a later one is data (`rl_mutant … 'label ~ /…/'`, a replacement
    # program text). A message opening with an article is prose, and its first word is no label.
    if (fn && w ~ /^["\047][^[:space:]"\047]+[[:space:]]/) {
      if (nq7++ > 0 || article7(w)) continue
      nm = substr(w, 2); sub(/[[:space:]].*$/, "", nm); sub(/^[(\[]/, "", nm); sub(/[]:,;)]+$/, "", nm)
      if (nm !~ /[$`\\]/) { lab7(nm, "1b"); callee7(cw7) }
      continue
    }
    if (w ~ /[$`\\]/) continue
    gsub(/["\047]/, "", w)
    if (w !~ /^[A-Za-z0-9_+-]+(\.[A-Za-z0-9_+-]+)*$/ || w ~ /^-/) continue
    if (fs == 3) lab7(w, 7)
    else if (fn) { lab7(w, 5); callee7(cw7) }
  }
  # form 8: the name of a function DEFINED on a code line, where the cell IS the function (`C11_progress_extends() {`)
  if (match(s, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_+-]*[[:space:]]*\(\)/)) {
    nm = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*(function[[:space:]]+)?/, "", nm); sub(/[[:space:]]*\(\)$/, "", nm)
    print "L\t" FX "\t8\t" nm
  }
  if (s !~ /(ok|bad|pass|fail|matrix_row)[[:space:]]/ && index(s, "arm_") == 0) return
  if (match(s, /^[[:space:]]*(function[[:space:]]+)?arm_[A-Za-z0-9_+-]+[[:space:]]*\(\)/)) {
    nm = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*(function[[:space:]]+)?arm_/, "", nm); sub(/[[:space:]]*\(\)$/, "", nm)
    print "L\t" FX "\t3\t" nm
  }
  off = 0
  while (match(substr(s, off + 1), /(ok|bad|pass|fail|matrix_row)[[:space:]]+/)) {
    st = off + RSTART; q = off + RSTART + RLENGTH; off = q - 1
    if (st > 1 && substr(s, st - 1, 1) ~ /[A-Za-z0-9_.\/$-]/) continue
    if (!cmdpos(substr(s, 1, st - 1))) continue
    cw = substr(s, st, q - st); sub(/[[:space:]]+$/, "", cw)
    w = wordat(o, q)
    if (cw == "matrix_row") {
      q = WEND; while (substr(o, q, 1) ~ /[[:space:]]/) q++
      w = literal(wordat(o, q)); if (w != "") print "L\t" FX "\t2\t" w
      continue
    }
    if (w !~ /^["\047]?[^"\047[:space:]]/) continue
    callee7(cw); if (article7(w)) continue
    sub(/^["\047]/, "", w); sub(/[[:space:]].*$/, "", w); sub(/["\047]$/, "", w); sub(/^\(/, "", w); sub(/[:,;)]+$/, "", w)
    if (w ~ /[$`\\"\047]/ || w == "") continue
    lab7(w, 1)
  }
}
function analyze(   i, s, off, st, q, w, ww, pre, pre0, neg, e, qe, nw, ts, a, h, k, re, w2, pe) {
  if (FX != "" && FX != "lib") prep6()
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
    if (!HDL[i]) { h6(i); h7(i) }
    # H5 facts
    if (s ~ /(^|[^A-Za-z0-9_])cmp[[:space:]]+-s([[:space:]]|$)/) CMP[FX] = 1
    if (O[i] ~ /[Mm][Uu][Tt][Aa][Nn][Tt]/) MUTW[FX] = 1
    if (match(s, /(^|[[:space:];&|(])mutant_killed[[:space:]]+/)) {
      MKC[FX] = 1
      q = RSTART + RLENGTH; w = wordat(O[i], q); q = WEND; while (substr(O[i], q, 1) ~ /[[:space:]]/) q++
      w2 = wordat(O[i], q); k = literal(w2)
      print "K\t" FX "\t" REL ":" i "\t" (k == "" ? "$" : k)
    }
    if (ISRUN && !HDL[i] && O[i] ~ /^[[:space:]]*#[[:space:]]*MUTANT-MATRIX/) print "B\t" FX "\t" i "\t" O[i]
  }
  stubjoin()
  if (STK != "c" || HDN > 0) print "Q\t" REL "\t" (HDN > 0 ? "inside a heredoc body" : "inside a quoted string (" STK ")")
}
pass == 1 {
  if (FNR == 1) FX = fxof(relof(FILENAME))
  # H7 form 5's callee set: every function a fixture's own files (or core/fixtures/lib) define, by name
  if (FX != "" && match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\(\)/)) {
    fnm = $0; sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fnm); sub(/[[:space:]]*\(\).*/, "", fnm)
    if (FX == "lib") LFN7[fnm] = 1; else FN7[FX, fnm] = 1
  }
  if (FX != "" && FX != "lib" && match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z0-9_]*[mM][uU][tT][A-Za-z0-9_]*[[:space:]]*\(\)/)) {
    nm = $0; sub(/^[[:space:]]*(function[[:space:]]+)?/, "", nm); sub(/[[:space:]]*\(\).*/, "", nm)
    if (!(FX in S1)) S1[FX] = nm
  }
  next
}
pass == 2 && FNR == 1 {
  if (CUR != "") analyze()
  CUR = FILENAME; NL = 0; STK = "c"; HDN = 0; HDI = 0; split("", DP)
  REL = relof(FILENAME); FX = fxof(REL); ISRUN = (REL == "core/fixtures/" FX "/run.sh"); loadtools(FX)
  print "F\t" REL
}
pass == 2 { NL++; O[NL] = $0; M[NL] = maskl($0); HDL[NL] = INHD }
END {
  if (CUR != "") analyze()
  for (f in S1) print "P\t" f "\tS1 " S1[f] "()"
  for (f in CMP) if (f in MUTW) print "P\t" f "\tS2 cmp -s + mutant"
  for (f in MKC) print "P\t" f "\tMKC mutant_killed caller"
  print "T\tH1\t" (T1 + 0); print "T\tH2\t" (T2 + 0); print "T\tH6\t" (T6 + 0)
}
AWK

# --- the judge -----------------------------------------------------------------------------------------------------
read -r -d '' JUDGE_AWK <<'AWK'
function map(fx) { if (fx in IMPL) { if (IMPL[fx] == "!") { print "STUB\t" fx "\tshard stub whose IMPL= line does not resolve"; return fx } return IMPL[fx] } return fx }
function addtag(f, t) { MEM[f] = 1; if (index("," TAG[f] ",", "," t ",") == 0) TAG[f] = TAG[f] (TAG[f] == "" ? "" : ",") t }
function toks(list, re, what, where,   a, n, k, seen) {
  if (list == "") { print "ROW\t" where "\t" what " is empty"; return 0 }
  n = split(list, a, ","); split("", seen)
  for (k = 1; k <= n; k++) {
    if (a[k] !~ re) { print "ROW\t" where "\t" what " token \"" a[k] "\" is malformed"; return 0 }
    if (a[k] in seen) { print "ROW\t" where "\t" what " token \"" a[k] "\" is duplicated"; return 0 }
    seen[a[k]] = 1
  }
  return n
}
function clause(raw, k) { k = index(raw, " why="); if (!k) return ""; raw = substr(raw, k + 5); gsub(/[[:space:]]/, "", raw); return raw }
function claim(f, name, form, where) {
  if ((f, name) in FORM) { print "ROW\t" where "\tname " name " already carries a " FORM[f, name] " line; each name carries exactly one of MUTANT-MATRIX, -FULL, -CONTROL"; return }
  FORM[f, name] = form
}
FILENAME == ARGV[1] { IMPL[$1] = $2; next }
FILENAME == ARGV[2] { if ($0 !~ /^[[:space:]]*(#|$)/) { x = $1; gsub(/[[:space:]]/, "", x); MKA[x] = 1 } next }
FILENAME == ARGV[3] {
  if ($1 == "H1" || $1 == "H2" || $1 == "H3" || $1 == "H6") { print; next }
  if ($1 == "P") { addtag(map($2), $3); next }
  if ($1 == "B") { if ($2 in IMPL) { print "ROW\t" $2 ":" $3 "\ta MUTANT-MATRIX block line in a shard stub; the block lives in its IMPL"; next }
                   NB[$2]++; BL[$2, NB[$2]] = $3; BR[$2, NB[$2]] = $4; next }
  if ($1 == "K") { f = map($2); NK[f]++; KL[f, NK[f]] = $3; KN[f, NK[f]] = $4; next }
  if ($1 == "C") { CAL7[map($2), $3] = 1; next }
  if ($1 == "L" && $3 == "8") { F8[map($2), $4] = 1; next }
  if ($1 == "L") { f = map($2); if (!((f, $4) in LAB)) LAB[f, $4] = $3; else if (index(" " LAB[f, $4] " ", " " $3 " ") == 0) LAB[f, $4] = LAB[f, $4] " " $3; next }
  next
}
FILENAME == ARGV[5] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in TLISTED) print "H7DUP\t" x
  TLISTED[x] = 1
  if (r == "") print "H7NOREASON\t" x
  next
}
FILENAME == ARGV[4] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in LISTED) print "DUP\t" x
  LISTED[x] = 1
  if (r == "") print "NOREASON\t" x
  next
}
END {
  for (x in MKA) addtag(map(x), "MKA mutant-kills allowlist row")
  TOK = "^[A-Za-z0-9_+-]+(\\.[A-Za-z0-9_+-]+)*$"; NAMERE = "^[A-Za-z0-9_:+-]+(\\.[A-Za-z0-9_:+-]+)*$"; WORLDRE = "^[A-Za-z0-9_.-]+$"
  for (f in NB) {
    nrem = 0; nmut = 0; dyn = 0
    for (k = 1; k <= NB[f]; k++) {
      raw = BR[f, k]; where = f ":" BL[f, k]; n = split(raw, a, /[[:space:]]+/)
      if (a[1] == "") { for (m = 1; m < n; m++) a[m] = a[m + 1]; n-- }
      if (a[1] != "#") { print "ROW\t" where "\tmalformed: write `# MUTANT-MATRIX...`, the `#` and the form separated by one blank"; continue }
      form = a[2]
      if (form == "MUTANT-MATRIX-REMEASURE") {
        nrem++; cmd = raw; sub(/^[[:space:]]*#[[:space:]]*MUTANT-MATRIX-REMEASURE[[:space:]]+/, "", cmd); sub(/[[:space:]]+$/, "", cmd)
        if (cmd != "bash core/fixtures/" f "/run.sh --matrix") print "ROW\t" where "\tREMEASURE must read exactly `bash core/fixtures/" f "/run.sh --matrix` (got `" cmd "`)"
        continue
      }
      if (form != "MUTANT-MATRIX" && form != "MUTANT-MATRIX-FULL" && form != "MUTANT-MATRIX-CONTROL" && form != "MUTANT-MATRIX-DYNAMIC") { print "ROW\t" where "\tunknown form " form; continue }
      if (n < 3 || a[3] !~ NAMERE) { print "ROW\t" where "\tmissing or malformed name"; continue }
      if (form == "MUTANT-MATRIX") {
        if (n < 5 || a[4] !~ /^decides=/ || a[5] !~ /^twins=/) { print "ROW\t" where "\twant `# MUTANT-MATRIX <m> decides=<arms> twins=<arms>`"; continue }
        dec = substr(a[4], 9); tw = substr(a[5], 7)
        if (!toks(dec, TOK, "decides", where)) continue
        if (tw == "-") {
          if (n < 6 || a[6] !~ /^why=/ || clause(raw) == "") { print "ROW\t" where "\ttwins=- needs a non-empty why=<clause>"; continue }
        } else {
          if (("," tw ",") ~ /,-,/) { print "ROW\t" where "\ttwins=- cannot be mixed into a list"; continue }
          if (!toks(tw, TOK, "twins", where)) continue
          if (n >= 6) { print "ROW\t" where "\t" (a[6] ~ /^why=/ ? "why= is refused on a row with real twins" : "unknown field " a[6]); continue }
          split(dec, d, ","); nt = split(tw, t, ","); bad = ""
          for (u in t) for (v in d) if (t[u] == d[v]) bad = t[u]
          if (bad != "") { print "ROW\t" where "\ttwin " bad " is inside its decides"; continue }
          # keyed on `<fixture>:<mutant>:<token>`: the mutant name is the row's, stable under line moves, so a listed
          # built token acquits that one row's twin and never a new row, or a new mutant, reusing the token
          for (u = 1; u <= nt; u++) { y = f ":" a[3] ":" t[u]; if (!(y in TW7)) NTW7++; TW7[y] = 1; TWW7[y] = where; TWT7[y] = t[u] }
        }
        nmut++; claim(f, a[3], form, where)
      } else if (form == "MUTANT-MATRIX-FULL") {
        if (n < 5 || a[4] !~ /^worlds=/ || a[5] !~ /^why=/ || clause(raw) == "") { print "ROW\t" where "\twant `# MUTANT-MATRIX-FULL <m> worlds=<w,...> why=<clause>`"; continue }
        if (!toks(substr(a[4], 8), WORLDRE, "worlds", where)) continue
        nmut++; claim(f, a[3], form, where)
      } else {
        if (n < 4 || a[4] !~ /^why=/ || clause(raw) == "") { print "ROW\t" where "\twant `# " form " <name> why=<clause>`"; continue }
        if (form == "MUTANT-MATRIX-DYNAMIC") { if ((f, "dyn:" a[3]) in FORM) print "ROW\t" where "\tDYNAMIC label " a[3] " is duplicated"; FORM[f, "dyn:" a[3]] = "DYNAMIC"; dyn = 1 }
        else claim(f, a[3], form, where)
      }
    }
    if (nrem != 1) print "ROW\t" f ":0\tthe block carries " nrem " MUTANT-MATRIX-REMEASURE lines; exactly one is required"
    if (nmut == 0) print "ROW\t" f ":0\tthe block declares no MUTANT-MATRIX or MUTANT-MATRIX-FULL row"
    for (k = 1; k <= NK[f]; k++) {
      nm = KN[f, k]
      if (nm == "$") { if (!dyn) print "JOIN\t" KL[f, k] "\ta non-literal mutant_killed name, and the block declares no MUTANT-MATRIX-DYNAMIC line" }
      else if (!((f, nm) in FORM)) print "JOIN\t" KL[f, k] "\tmutant_killed name " nm " carries no MUTANT-MATRIX or MUTANT-MATRIX-FULL line"
      else if (FORM[f, nm] == "MUTANT-MATRIX-CONTROL") print "JOIN\t" KL[f, k] "\tmutant_killed name " nm " carries a MUTANT-MATRIX-CONTROL line; a control never routes through mutant_killed"
    }
  }
  for (f in MEM) if (!(f in NB)) { DER[f] = 1; print "DERIVE\t" f "\tno MUTANT-MATRIX block; floor: " TAG[f]; if (!(f in LISTED)) print "FLOOR\t" f "\t" TAG[f] }
  for (x in LISTED) if (!(x in DER)) print "STALE\t" x
  # H7: every twin of an ACCEPTED MUTANT-MATRIX row resolves to a label its fixture emits, or is a listed built token.
  # Form 8 is joined here, once every C row is in: a defined function that forms 1, 1b or 5 read as the PRINTER or
  # callee (`ok`, `bad`, `want`) is the emitter, never a label.
  for (y in F8) { if (!(y in CAL7)) { if (!(y in LAB)) LAB[y] = "8"; else LAB[y] = LAB[y] " 8" } }
  for (x in TW7) {
    k = index(x, ":"); f = substr(x, 1, k - 1); tk = TWT7[x]; lb = tk; sub(/\..*$/, "", lb)
    fm = ((f, tk) in LAB) ? LAB[f, tk] : (((f, lb) in LAB) ? LAB[f, lb] : "")
    if (fm != "") { RES7[x] = 1; print "R7\t" x "\t" fm }
    else if (x in TLISTED) print "B7\t" x
    else print "H7\t" TWW7[x] ":" tk "\ttwin " tk " names no label the fixture emits (no emission form of H7 yields " (tk == lb ? tk : tk " or " lb) " on a code line of its files); unlisted key " x
  }
  for (x in TLISTED) { if (!(x in TW7)) print "H7STALE\t" x "\tno accepted MUTANT-MATRIX row of that fixture and mutant carries the twin"; else if (x in RES7) print "H7STALE\t" x "\tthe twin now resolves to an emitted label" }
  print "N7\t" (NTW7 + 0)
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
  awk -v ROOTP="$r/" "$SCAN_AWK" pass=1 "$@" pass=2 "$@" > "$o.scan" || { echo "BROKEN: the scan awk failed"; return 2; }
  scanned="$(grep -c '^F	' "$o.scan")" || scanned=0
  [ "$scanned" -eq "$listed" ] || { echo "BROKEN: listed $listed files, scanned $scanned"; return 2; }
  if grep -q '^Q	' "$o.scan"; then
    echo "BROKEN: the masker lost its quote state -- these files end inside a string or heredoc, so their arms are unattributable:"
    awk -F'\t' '$1 == "Q" { print "    " $2 ": " $3 }' "$o.scan"; return 2
  fi
  [ -f "$r/$MKA_REL" ] && cp "$r/$MKA_REL" "$o.mka" || : > "$o.mka"
  [ -f "$r/$ALLOW_REL" ] && cp "$r/$ALLOW_REL" "$o.allow" || : > "$o.allow"
  [ -f "$r/$H7_ALLOW_REL" ] && cp "$r/$H7_ALLOW_REL" "$o.tallow" || : > "$o.tallow"
  awk -F'\t' "$JUDGE_AWK" "$o.stubs" "$o.mka" "$o.scan" "$o.allow" "$o.tallow" | LC_ALL=C sort -u > "$o.verdict" \
    || { echo "BROKEN: the judge awk failed, so its verdict is empty rather than clean"; return 2; }
  return 0
}

# m4 <repo> <current list> <scratch> [<rel> <arm> <remedy> <noun>]: the down-only arm, keyed on field 1. With no 4th-7th
# argument it judges this file's H5 list ($ALLOW_REL, arm M4, its remedy); <noun> names field 1 in the FAIL line
# (default `fixture`; H7-M4 passes its `<fixture>:<mutant>:<token>` key). THE ONE SHARED COPY:
# scripts/validate-fixture-inprocess.sh extracts this function by its own boundaries (awk, every line strictly between
# the `# M4_BEGIN` and `# M4_END` marker lines below, refusing unless exactly one `m4() {` sits between them) and passes
# all three, so the two down-only fixture lists run one function.
# validate-mutant-kills.sh's m4 is NOT this copy and is not bound to it: it keys on the WHOLE trimmed row, so a
# reworded reason is an added row there and would flip this file's `reworded` probe case here.
# M4_BEGIN
m4() {
  local repo="$1" cur="$2" base="$3" rel="${4:-$ALLOW_REL}" arm="${5:-M4}" sha added
  local remedy="${6:-do not list the fixture; give it its MUTANT-MATRIX block (fixture-mutants.md) and delete the row.}"
  local noun="${7:-fixture}"
  sha="$(git -C "$repo" rev-parse -q --verify 'origin/main^{commit}' 2>/dev/null)" || sha=""
  if [ -z "$sha" ]; then echo "SKIP $arm: origin/main does not resolve here, so there is no base allowlist to compare against"; return 0; fi
  if ! git -C "$repo" cat-file -e "${sha}:${rel}" 2>/dev/null; then
    echo "SKIP $arm: origin/main carries no $rel -- this is the release that first ships it"; return 0; fi
  git -C "$repo" show "${sha}:${rel}" > "$base" 2>/dev/null || { echo "FAIL $arm: origin/main carries $rel but it could not be read"; return 1; }
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

# inert <root> <list> <out> <ledger|runners>: E1's predicate, THE ONE SHARED COPY. The INERT receipts, one
# repo-relative path per line. core/fixtures/fixture-hygiene/receipt-bl868.sh extracts this function (awk, every line
# strictly between the `# INERT_BEGIN` and `# INERT_END` marker lines, refusing with exit 9 unless exactly one
# `inert() {` sits between them) and calls it in `ledger` mode; this file's E1 calls it in `runners` mode. Only a file
# named `receipt*.sh` in <list> can be inert (a sourced helper never is). It is inert when nothing reads it: no
# non-comment line of a tracked core/fixtures/*/run.sh, seed.sh, lib.sh or .githooks/* file names it -- nor, for a
# scripts/ receipt, of a tracked scripts/*.sh other than itself -- and, in `ledger` mode only, no `verify:` line of
# docs/backlog.md names it. The 4th argument is REQUIRED, and any other value returns 1. The two modes answer
# different questions: E1 asks whether a RUNNER executes the receipt; receipt-bl868 asks whether ANY pre-push step
# executes it, and the backlog-receipts step runs a live `verify:` line, so bl868 must still scan such a receipt.
# "Names it" is `<dir>/<basename>` anywhere on the line (`scripts/<basename>` for a scripts/ receipt), or the bare
# basename from a file in the receipt's OWN directory (`bash "$HERE/receipt.sh"`), so one fixture's call never makes
# another fixture's same-named receipt live. A scripts/*.sh reader is consulted only for scripts/ receipts, and is
# listed only when <list> carries one, so a caller listing no scripts/ receipt reads exactly the files it always read.
# Returns 1 when the ledger (ledger mode) or a referencing file cannot be read (awk reads an unopenable file as empty,
# so reads are counted).
# INERT_BEGIN
inert() {
  local r="$1" n v="${4:-}"
  case "$v" in ledger) [ -f "$r/docs/backlog.md" ] || return 1 ;; runners) ;; *) return 1 ;; esac
  if grep -q '^scripts/receipt[^/]*\.sh$' "$2"; then
    git -C "$r" ls-files -- 'core/fixtures/*/run.sh' 'core/fixtures/*/seed.sh' 'core/fixtures/*/lib.sh' '.githooks/*' 'scripts/*.sh' > "$3.refs" 2>/dev/null || return 1
  else
    git -C "$r" ls-files -- 'core/fixtures/*/run.sh' 'core/fixtures/*/seed.sh' 'core/fixtures/*/lib.sh' '.githooks/*' > "$3.refs" 2>/dev/null || return 1
  fi
  n="$(awk 'END { print NR }' "$3.refs")"
  awk -v R="$r" -v RL="$3.refs" -v NREF="$n" -v LEDGER="$v" '
    function named(l, s,   i, t) {  # s in l, with no name character before it (so `dir/receipt.sh` is not `r/receipt.sh`)
      t = l
      while ((i = index(t, s)) > 0) { if (i == 1 || substr(t, i - 1, 1) !~ /[A-Za-z0-9_.-]/) return 1; t = substr(t, i + 1) }
      return 0 }
    { b = $0; sub(/^.*\//, "", b); if (b !~ /^receipt[^\/]*\.sh$/) next
      d = $0; sub(/\/[^\/]*$/, "", d); C[$0] = 1; BASE[$0] = b; DIR[$0] = d; t = d; sub(/^.*\//, "", t); SUF[$0] = t "/" b }
    END {
      if (LEDGER == "ledger") {
        if ((getline l < (R "/docs/backlog.md")) < 0) exit 3
        do { if (l ~ /^verify:/) for (c in C) if (named(l, SUF[c])) LIVE[c] = 1 } while ((getline l < (R "/docs/backlog.md")) > 0)
      }
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
# INERT_END

# e1_run <repo> <out-prefix>: E1 over <repo>. Writes <out>.verdict (`INERT|STALE|DUP|NOREASON\t<path>`, sorted) and
# <out>.e1list (the population, counted: zero is BROKEN); prints the BROKEN reason and returns 2 when it could not
# measure. It reads only the tree's runner files and the allowlist, nothing another branch's ledger edit can change.
e1_run() {
  local repo="$1" o="$2"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
    git -C "$repo" ls-files -- 'core/fixtures/*/receipt*.sh' 'scripts/receipt*.sh' ) > "$o.e1list" 2>/dev/null \
    || { echo "BROKEN: git ls-files failed under $repo"; return 2; }
  [ -s "$o.e1list" ] || { echo "BROKEN: E1 listed 0 tracked receipt*.sh under $repo; an empty population has no inert receipt by construction"; return 2; }
  inert "$repo" "$o.e1list" "$o.inert" runners || { echo "BROKEN: a reader file could not be read under $repo"; return 2; }
  [ -f "$repo/$E1_ALLOW_REL" ] && cp "$repo/$E1_ALLOW_REL" "$o.allow" || : > "$o.allow"
  awk -F'\t' 'FILENAME == ARGV[1] { if ($0 != "") I[$0] = 1; next }
    /^[[:space:]]*(#|$)/ { next }
    { x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
      if (x in L) print "DUP\t" x; L[x] = 1; if (r == "") print "NOREASON\t" x }
    END { for (x in I) if (!(x in L)) print "INERT\t" x; for (x in L) if (!(x in I)) print "STALE\t" x }' "$o.inert" "$o.allow" \
    | LC_ALL=C sort -u > "$o.verdict" || { echo "BROKEN: the E1 judge awk failed"; return 2; }
}

# --- self-probe, before the corpus ---------------------------------------------------------------------------------
pgit() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  git -c user.name=probe -c user.email=probe@invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null \
  -c init.defaultBranch=main "$@"; }
P="$WORK/probe"
seed() { mkdir -p "$(dirname "$P/$1")" && cat > "$P/$1"; }
mkdir -p "$P/scripts" && : > "$P/VERSION"
seed core/fixtures/s1/run.sh <<'EOF'
#!/usr/bin/env bash
D_ROOT=x; GATE=y
if [ ! -f "$GATE" ] || [ ! -d "$D_ROOT/.git" ]; then
  echo "SKIP"
  exit 0
fi
[ -d "$D_ROOT/.git" ] || { echo skip; exit 0; }
[ -d "$R/.git" ] || exit 0 # no history
if [ ! -d "$R/.git" ]; then
  exit 0   # no repo, so nothing to check
fi
EOF
seed core/fixtures/s1n/run.sh <<'EOF'
#!/usr/bin/env bash
# [ -d "$R/.git" ] || exit 0
[ -d "$R/.git" ] || { echo "FIXTURE BROKEN: no repo, exit 0 would lie"; exit 2; }
if [ ! -d "$v/.git" ]; then
  note 'victim has no .git; exit 0'
  rc=1
fi
[ -d "$R/.git" ] && git -C "$R" worktree prune
[ -d "$R/.git" ] || bad "no repo"
exit 0
[ -d "$R/.git/modules/x" ] || exit 0
if [ -d "$R/.git" ]; then
  exit 0
fi
[ -d "$R/.git" ] || exit 2 # no repo; exit 0 would lie
[ -d "$R/.git" ] || echo "exit 0 X" # a string, not an exit
EOF
seed core/fixtures/s2/tools.decl <<'EOF'
# tools
jq
?node
EOF
seed core/fixtures/s2/run.sh <<'EOF'
#!/usr/bin/env bash
command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }
if ! command -v node >/dev/null 2>&1; then
  echo "skip"
  exit 0
fi
command -v jq >/dev/null 2>&1 || exit 0 # no jq
EOF
seed core/fixtures/s2n/tools.decl <<'EOF'
jq
EOF
seed core/fixtures/s2n/run.sh <<'EOF'
#!/usr/bin/env bash
command -v perl >/dev/null 2>&1 || { echo "SKIP no perl"; exit 0; }
MG='command -v jq >/dev/null 2>&1 || exit 0'
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: jq"; exit 2; }
if ! command -v jq >/dev/null 2>&1; then
  ok "SKIP arms: jq absent"
elif true; then
  exit 0
fi
command -v jq >/dev/null 2>&1 || exit 2 # no jq; exit 0 would lie
EOF
seed core/fixtures/s3/run.sh <<'EOF'
#!/usr/bin/env bash
( cd "$X" && sh scripts/a.sh )
P="$(exec sh -c 'printf %s "$PPID"')"
sh -c 'exit 0' & p=$!
/bin/sh "$X/b.sh"
printf 'echo hi\n' | sh;
env FOO=1 sh -c x
cat "$X/s" | sh
command sh "$X/c.sh"
env sh -c x
EOF
seed core/fixtures/s6/run.sh <<'EOF'
#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
. "$HERE/../lib/mutant.sh"
MUT_LIB="$HERE/../lib/mutant.sh"
. "$MUT_LIB"
[ -f "$HERE/../lib/matrix.sh" ] || echo "matrix.sh missing"
. "$HERE/../lib/matrix.sh"
[ -f "$HERE/lib.sh" ] || exit 2
. "$HERE/../lib/settled-net.sh"
. "$HERE/../lib/inproc.sh" || true
. "$HERE/../lib/mutant.sh" && run_it
. "$HERE/../lib/mutant.sh" || broken "no broken() is defined in this file"
. "$HERE/../lib/mutant.sh" || { echo "skip"; exit 0; }
broken() { echo "FIXTURE BROKEN: $1" >&2; exit 2; }
EOF
seed core/fixtures/s6n/run.sh <<'EOF'
#!/usr/bin/env bash
broken() { echo "FIXTURE BROKEN: $1" >&2; exit 2; }
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || broken "no lib/mutant.sh"
. "$MUT_LIB"
[ -f "$HERE/../lib/matrix.sh" ] || { echo "FIXTURE ERROR: matrix.sh" >&2; exit 2; }
. "$HERE/../lib/matrix.sh"
for p in scripts/x.sh core/fixtures/lib/settled-net.sh; do [ -f "$ROOT/$p" ] || { echo "absent: $p" >&2; exit 2; }; done
. "$ROOT/core/fixtures/lib/settled-net.sh"
. "$HERE/lib.sh"
# . "$HERE/../lib/mutant.sh"
echo '. "$HERE/../lib/mutant.sh"'
. "$HERE/../lib/inproc.sh" 2>/dev/null || { echo "FIXTURE BROKEN: inproc.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || broken "cannot source lib/mutant.sh"
cat > "$W/x.sh" <<'E'
. "$HERE/../lib/mutant.sh"
E
[ -f "$D/../lib/a.sh" ] && [ -f "$D/../lib/settled-net.sh" ] || {
  echo "FIXTURE ERROR: lib absent" >&2; exit 2; }
. "$D/../lib/settled-net.sh"
EOF
seed core/fixtures/s3n/run.sh <<'EOF'
#!/usr/bin/env bash
awk '{ if (sh != "") print sh }' f
x=1; [ "$sh" = 1 ] && bash scripts/a.sh
zsh -c 'true'
cat <<'END' > receipt.md
verify: sh scripts/x.sh
END
echo "run sh scripts/a.sh"
k=$(( sh == 1 ))
printf x | bash run.sh;
echo x | ./b.sh
awk -v sh=1 'BEGIN { print sh }' </dev/null | cat
echo verify: sh scripts/x.sh
myenv sh -c x
x | sh=1
command -v sh >/dev/null
EOF
seed core/fixtures/s3s/run.sh <<'EOF'
#!/usr/bin/env bash
printf '#!/bin/sh\necho hi\n' > "$W/stub" && chmod +x "$W/stub"
"$W/stub" arg
cat > "$W/bin/tool" <<'END'
#!/bin/sh
exit 0
END
chmod +x "$W/bin/tool"
PATH="$W/bin:$PATH" bash "$X"
echo '#!/bin/sh' > "$W/e"
exec "$W/e"
printf '#!/usr/bin/env sh\nexit 0\n' > "$W/v" && chmod +x "$W/v"
"$W/v"
EOF
seed core/fixtures/s3sn/run.sh <<'EOF'
#!/usr/bin/env bash
printf '#!/bin/sh\necho hi\n' > "$W/stub" && chmod +x "$W/stub"
cmp -s "$W/stub" "$W/other"
X="$W/stub"
printf '#!/bin/sh\nexit 0\n' > "$W/b" && chmod +x "$W/b"
bash "$W/b" arg
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/c" && chmod +x "$W/c"
"$W/c"
printf '#!/bin/bash\nexit 0\n' > "$W/d" && chmod +x "$W/d"
exec "$W/d"
cat > "$W/h" <<'END'
#!/bin/bash
END
"$W/h"
cat > "$W/q/tool" <<'END'
#!/bin/sh
exit 0
END
chmod +x "$W/q/tool"
printf '#!/bin/sh\nexit 0\n' > "$W/bin/sub/tool" && chmod +x "$W/bin/sub/tool"
PATH="$W/bin:$PATH" bash "$X"
EOF
seed core/fixtures/m5a/run.sh <<'EOF'
mkmut() { :; }
EOF
seed core/fixtures/m5b/run.sh <<'EOF'
mut_copy() { :; }
EOF
seed core/fixtures/m5c/run.sh <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MA decides=R1.cellA twins=R2
# MUTANT-MATRIX MB decides=R1,R3 twins=- why=it deletes the subject check
# MUTANT-MATRIX-FULL MC worlds=w1,w2.x why=no single world decides
# MUTANT-MATRIX-CONTROL KC why=proves which layer carries the kill
# MUTANT-MATRIX-DYNAMIC loop why=names come from the list below
# MUTANT-MATRIX sprint-status:DEL decides=R1.a.b,a+b twins=R2
# MUTANT-MATRIX dir-empty+silent.jsonl decides=R1 twins=R2.x.y
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5c/run.sh --matrix
mkmut() { :; }
mkmut MA x
mkmut KC x
mutant_killed 1 MB "m"
for m in MC; do mutant_killed 1 "$m" "m"; done
EOF
seed core/fixtures/m5d/run.sh <<'EOF'
# MUTANT-MATRIX D1 decides=R1:cellA twins=R2
# MUTANT-MATRIX D2 decides=R1=x twins=R2
# MUTANT-MATRIX D3 decides=R1 x twins=R2
# MUTANT-MATRIX D4 decides=a=b twins=R2
# MUTANT-MATRIX D5 decides=R1 twins=-
# MUTANT-MATRIX D6 decides=R1 twins=- why=
# MUTANT-MATRIX D7 decides=R1 twins=-,R2
# MUTANT-MATRIX D8 decides=R1 twins=R2 why=x
# MUTANT-MATRIX D9 decides=R1 twins=R2 log=/tmp/x
# MUTANT-MATRIX D10 decides=R1 twins=R1
# MUTANT-MATRIX D11 decides=R1,R1 twins=R2
# MUTANT-MATRIX D12 decides=R1 twins=R2
# MUTANT-MATRIX-CONTROL D12 why=x
# MUTANT-MATRIX-REMEASURE bash core/scripts/hermetic-run.sh m5d
# MUTANT-MATRIX-BOGUS D13 x
# MUTANT-MATRIX-CONTROL KX why=x
mutant_killed 1 NOROW "m"
mutant_killed 1 "$m" "m"
mutant_killed 1 KX "m"
# MUTANT-MATRIX a=b decides=R1 twins=R2
# MUTANT-MATRIX D21 decides=.x twins=R2
# MUTANT-MATRIX D22 decides=R1 twins=a..b
# MUTANT-MATRIX D23 decides=x. twins=R2
# MUTANT-MATRIX .x decides=R1 twins=R2
# MUTANT-MATRIX a..b decides=R1 twins=R2
# MUTANT-MATRIX x. decides=R1 twins=R2
EOF
seed core/fixtures/m5e/run.sh <<'EOF'
# MUTANT-MATRIX E1 decides=R1 twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5e/run.sh --matrix
mkmut() { :; }
EOF
seed core/fixtures/m5f/run.sh <<'EOF'
mut() { :; }
EOF
seed core/fixtures/m5f-b/run.sh <<'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../m5f/run.sh"
cmp -s "$a" "$b" || echo "mutant differs"
bash "$IMPL" --group b > "$HERE/out"
EOF
seed core/fixtures/m5g/run.sh <<'EOF'
. "$HERE/world.sh"
EOF
seed core/fixtures/m5g/world.sh <<'EOF'
mutant_killed "$B" w "m"
EOF
seed core/fixtures/m5h/run.sh <<'EOF'
echo h
EOF
seed core/fixtures/m5i/run.sh <<'EOF'
cmp -s "$a" "$b" && bad "the mutant did not apply"
EOF
seed core/fixtures/m5j/run.sh <<'EOF'
# MUTANT-MATRIX-CONTROL CJ why=x
# MUTANT-MATRIX-DYNAMIC L why=x
# MUTANT-MATRIX-DYNAMIC L why=y
# MUTANT-MATRIX-FULL FJ worlds= why=x
# MUTANT-MATRIX-FULL FK worlds=w1
# MUTANT-MATRIX-CONTROL CK why=
mkmut() { :; }
mkmut NOROWJ x
mkmut CJ x
EOF
seed core/fixtures/m5k/run.sh <<'EOF'
# MUTANT-MATRIX K1 decides=R1 twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5k/run.sh --matrix
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5k/run.sh --matrix
EOF
seed core/fixtures/m5f-c/run.sh <<'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../m5f/run.sh"
# MUTANT-MATRIX X decides=R1 twins=R2
exec bash "$IMPL" --group c
EOF
seed core/fixtures/m5l/run.sh <<'EOF'
#!/usr/bin/env bash
IMPL="$X/run.sh"
cmp -s "$a" "$b" || echo "mutant differs"
exec bash "$IMPL" --group b
EOF
seed core/fixtures/m5m/run.sh <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX m-rowed decides=R1 twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5m/run.sh --matrix
ck_mut() { :; }
ck_mut A mutant-x
mutant_killed "$B" m-unrowed "m"
mutant_killed "$B" m-rowed "m"
# MUTANT-MATRIX a:b decides=R1 twins=R2
mutant_killed "$B" a:b "m"
EOF
seed core/fixtures/m5n/run.sh <<'EOF'
# the copy differs; a comment only
cmp -s "$a" "$b" && bad "the copy did not apply"
reap_kill() { :; }
EOF
# H7's emitters for the H5 seeds above whose accepted rows carry the twin R2 (m5c, m5d's D12, m5e, m5k, m5m),
# appended so no H5 row's line number moves.
for x in m5c m5d m5e m5k m5m; do printf 'ok "R2 the twin cell"\n' >> "$P/core/fixtures/$x/run.sh"; done
# H7 FIRE: Z9 sits on code lines only in NON-emission positions (an external tool's argument, an unquoted
# assignment, a printf format, an echo string, an awk -v, a quoted ok, a comment, a heredoc body) -- the input that
# separates the arm from a bare token grep; Q8.cell's label Q8 dangles beside the near-miss `ok "Q8x …"`; Z8 is a
# listed built token with no reason (NOREASON, and B7 rather than H7). The D2 seeds, each a non-label word in a
# weak form's position: `tell` is a defined function that is also the PRINTER (`tell "A1 …"`), so form 8 must not
# acquit it (the uncalled `T8()` of m7q stays QUIET); `3` a bare number (`want2 3`, `for … in 3 4`, `3)`); `a` the
# article opening a prose message (`tell "a prose message"`); `program` a later quoted argument (`tell "A1 …"
# "program text"`); `absent` a word of a prose list (`m="the label is absent"`); `x` a one-character part of a
# non-roster list item (`SV="ord=3/7 q|null"`); `a` again through form 1 (`ok "a prose line …"`); `fragw` a
# fragment of a glob case pattern (`*fragw*)`), not a whole alternative; `optw` a word of a list carrying an
# option (`CMD="run -v optw"`); `chw` a word of a list carrying a non-roster character (`PROG="chw { print }"`).
seed core/fixtures/m7f/run.sh <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MF decides=A1 twins=Z9,Q8.cell,Z8,tell,3,a,program,absent,q,fragw,optw,chw
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m7f/run.sh --matrix
tell() { :; }
want2() { :; }
ok "A1 holds"
ok "Q8x is not Q8"
grep -q Z9 "$f"
x=Z9
printf 'Z9 %s\n' y
echo "Z9 done"
awk -v Z9=1 'BEGIN { }'
echo 'ok "Z9 inside a string"'
# ok "Z9 in a comment"
cat <<'E'
ok "Z9 in a heredoc"
E
tell x
tell "A1 the printed label" "program text the helper is handed"
tell "a prose message, not a label"
want2 3
for n in 3 4; do :; done
case "$n" in
  3) : ;;
esac
m="the label is absent"
SV="ord=3/7 q|null"
ok "a prose line through ok"
case "$n" in
  *fragw*) : ;;
esac
CMD="run -v optw"
PROG="chw { print }"
EOF
# H7 QUIET: one twin per emission form -- T1 ok message (form 1), T2 matrix_row (2), T3 arm_T3() (3), T4 a case
# pattern (4), T5 a defined function's argument (5), T6 a quoted list assignment (6), T7 a for-in word (7), T1b a
# defined function's quoted message, on a `\`-continued line (1b), T8 a defined function's name (8), B_T9= (9),
# T10.cellA a <label>.<cell> twin whose label is emitted, TB a listed built token (its key `m7q:MQ:TB`), T4b a
# case pattern after `;;` on the same line (4), and T11/T12 the keys of a `K=V` list (6). D1: MQ2 reuses TB on
# another mutant row of the same fixture, which its key does not acquit, so it FIREs while MQ's TB stays B7.
seed core/fixtures/m7q/run.sh <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MQ decides=A1 twins=T1,T2,T3,T4,T5,T6,T7,T1b,T8,T9,T10.cellA,TB,T4b,T11
# MUTANT-MATRIX MQ2 decides=A1 twins=TB,T12
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m7q/run.sh --matrix
want() { :; }
say() { :; }
arm_T3() { :; }
T8() { :; }
ok "A1 holds"
ok "T1 holds"
matrix_row MQ T2 0 GREEN yes
case "$c" in
  T4) echo x ;; T4b) echo y ;;
esac
want T5
WANT="T11=allow:1 T12=deny:0"
ARMS="T6 other"
for a in T7 z; do :; done
say \
  "T1b the continued message"
B_T9=1
bad "T10 the label of a label.cell twin"
EOF
# The H7 list, keyed `<fixture>:<mutant>:<token>`: m7q:MQ:TB quiet and DUP; m7q:MQ:T1 STALE (resolves);
# m7q:MQ:NOPE STALE (no such twin); m7q:GONE:TB STALE (TB is a twin of MQ and MQ2, never of a mutant GONE -- the
# mutant part of the key is read); m7f:MF:Z8 NOREASON. No m7q:MQ2:TB row, so MQ2's TB fires.
printf '# probe\nm7q:MQ:TB\tbuilt at runtime\nm7q:MQ:TB\tagain\nm7q:MQ:T1\tresolves now\nm7q:MQ:NOPE\tnot a twin\nm7q:GONE:TB\twrong mutant\nm7f:MF:Z8\n' > "$P/$H7_ALLOW_REL"
printf '%s\n' '# probe' m5h > "$P/$MKA_REL"
printf '# probe allowlist\nm5b\tS1\nm5f\tS1\nm5e\tS1\ngone\tS1\nm5b\tdup\nm5x\n' > "$P/$ALLOW_REL"
{ pgit init -q "$P" && pgit -C "$P" add -A && pgit -C "$P" commit -q -m probe; } >/dev/null 2>&1 \
  || { echo "validate-fixture-hygiene: REFUSED -- could not build the probe repository under $WORK" >&2; exit 2; }

SP_RED=0
sp_line() { printf 'self-probe %s: %s\n' "$1" "$2" >&2; }
pout="$(run_all "$P" "$WORK/p")"; prc=$?
if [ "$prc" -ne 0 ]; then
  sp_line CORPUS "FAIL -- $pout"; SP_RED=1
  : > "$WORK/p.verdict"; : > "$WORK/p.scan"
else
  sp_line CORPUS "ok (listed and scanned $(awk 'END { print NR }' "$WORK/p.list") probe files)"
fi
cut -f1,2 "$WORK/p.verdict" | grep -v '^DERIVE' > "$WORK/p.got"
want_rows() { case "$1" in
  H1) printf 'H1\tcore/fixtures/s1/run.sh:%s\n' 3 7 8 9 ;;
  H2) printf 'H2\tcore/fixtures/s2/run.sh:%s\n' 2 3 7 ;;
  H3) printf 'H3\tcore/fixtures/s3/run.sh:%s\n' 2 3 4 5 6 7 8 9 10
      printf 'H3\tcore/fixtures/s3s/run.sh:%s\n' 2 4 10 12 ;;
  H6) printf 'H6\tcore/fixtures/s6/run.sh:%s\n' 2 3 5 7 9 10 11 12 13 ;;
  H5) printf 'FLOOR\t%s\n' m5a m5g m5h m5i m5l
      printf 'ROW\tm5d:%s\n' 1 2 3 4 5 6 7 8 9 10 11 13 14 15 20 21 22 23 24 25 26
      printf 'ROW\tm5j:%s\n' 0 0 3 4 5 6
      printf 'ROW\tm5k:0\nROW\tm5f-c:4\nSTUB\tm5l\n'
      printf "JOIN\tcore/fixtures/m5d/run.sh:%s\n" 17 18 19
      printf "JOIN\tcore/fixtures/m5m/run.sh:6\n"
      printf 'STALE\t%s\n' gone m5e m5x
      printf 'DUP\tm5b\nNOREASON\tm5x\n' ;;
  H7) printf 'H7\tm7f:2:%s\n' Z9 Q8.cell tell 3 a program absent q fragw optw chw
      printf 'H7\tm7q:3:TB\n'
      printf 'B7\t%s\n' m7f:MF:Z8 m7q:MQ:TB
      printf 'H7STALE\t%s\n' m7q:MQ:T1 m7q:MQ:NOPE m7q:GONE:TB
      printf 'H7DUP\tm7q:MQ:TB\nH7NOREASON\tm7f:MF:Z8\n' ;;
  esac; }
for arm in H1 H2 H3 H5 H6 H7; do
  case "$arm" in H5) pat='^(FLOOR|ROW|JOIN|STALE|DUP|NOREASON|STUB)	' ;; H7) pat='^(H7|H7STALE|H7DUP|H7NOREASON|B7)	' ;; *) pat="^$arm	" ;; esac
  grep -E "$pat" "$WORK/p.got" | LC_ALL=C sort > "$WORK/got.$arm" || :
  want_rows "$arm" | LC_ALL=C sort > "$WORK/want.$arm"
  if cmp -s "$WORK/got.$arm" "$WORK/want.$arm"; then sp_line "$arm" "ok ($(awk 'END { print NR }' "$WORK/want.$arm") seeded offender row(s) exact; the near-misses stayed quiet)"
  else
    SP_RED=1; sp_line "$arm" "FAIL -- verdict rows differ from the seeded set:"
    diff "$WORK/want.$arm" "$WORK/got.$arm" | sed -n 's/^</    want-only/p; s/^>/    got-only /p' >&2
  fi
done
der="$(awk -F'\t' '$1 == "DERIVE" { print $2 }' "$WORK/p.verdict" | LC_ALL=C sort | tr '\n' ' ')"
if [ "$der" = "m5a m5b m5f m5g m5h m5i m5l " ]; then sp_line DERIVE "ok (derived rows m5a m5b m5f m5g m5h m5i m5l; the stubs m5f-b and m5f-c mapped to their IMPL)"
else SP_RED=1; sp_line DERIVE "FAIL -- derived '$der', want 'm5a m5b m5f m5g m5h m5i m5l '"; fi

m4_case() {  # <label> <repo> <want-rc> <want-first-line> <rows...>
  local lab="$1" repo="$2" wrc="$3" want="$4" got rc
  shift 4; printf '# probe list\n' > "$WORK/m4-cur.txt"; printf '%s\n' "$@" >> "$WORK/m4-cur.txt"
  got="$(unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY; m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-base.txt")"; rc=$?
  [ "$rc" = "$wrc" ] && [ "$(printf '%s\n' "$got" | head -1)" = "$want" ] && return 0
  sp_line M4 "FAIL -- case $lab got rc $rc, want $wrc: $(printf '%s' "$got" | head -2 | tr '\n' ' ')"; SP_RED=1; return 1
}
R="$WORK/m4-base"; RN="$WORK/m4-nofile"; RX="$WORK/m4-noorigin"
mkdir -p "$R/scripts" "$RN" "$RX"
{ pgit init -q "$R" && printf '# base\na\tr1\nb\tr2\n' > "$R/$ALLOW_REL" && pgit -C "$R" add "$ALLOW_REL" \
  && pgit -C "$R" commit -q -m base && pgit -C "$R" update-ref refs/remotes/origin/main HEAD \
  && pgit init -q "$RN" && printf 'x\n' > "$RN/other" && pgit -C "$RN" add other && pgit -C "$RN" commit -q -m n \
  && pgit -C "$RN" update-ref refs/remotes/origin/main HEAD && pgit init -q "$RX"; } >/dev/null 2>&1 \
  || { echo "validate-fixture-hygiene: REFUSED -- could not build the M4 probe repos" >&2; exit 2; }
M4F="FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
m4ok=0
m4_case added "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'b\tr2')" "$(printf 'c\tr3')" || m4ok=1
m4_case swap "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'c\tr3')" || m4ok=1
m4_case shrink "$R" 0 "OK M4: no allowlist row added against origin/main" "$(printf 'a\tr1')" || m4ok=1
m4_case reworded "$R" 0 "OK M4: no allowlist row added against origin/main" "$(printf 'a\tother words')" "$(printf 'b\tr2')" || m4ok=1
m4_case nofile "$RN" 0 "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it" "$(printf 'c\tr')" || m4ok=1
m4_case noorigin "$RX" 0 "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against" "$(printf 'c\tr')" || m4ok=1
[ "$m4ok" = 0 ] && sp_line M4 "ok (added and swapped rows refused; shrink and a reworded reason pass; both no-base states SKIP)"

# E1's probe: one repository, one commit (E1 lists tracked files). Fires: zz1 (named by nothing), zz5 (named only by
# a live `verify:` line of docs/backlog.md -- NOT a reader for E1), zz8's twin zza (named only in a comment),
# zd/receipt.sh (its bare name called from ANOTHER fixture), scripts/receipt-zz10 (named by nothing) and
# scripts/receipt-zz12 (named only by itself). Quiet: zz2 (`bash "$HERE/receipt-zz2.sh"`), zz3 (`R="$HERE/…"` then
# `bash "$R"`), zz4 (called from another fixture's lib.sh), zz9 (inside an echo message) and zz13 (in a trailing
# comment after code) -- THE TWO KNOWN ACQUITTALS, asserted -- and scripts/receipt-zz11 (called from
# scripts/zz-other.sh). The allowlist: zz8 listed (quiet) and listed twice (DUP), zz2 listed while read and `gone`
# listed while absent (STALE), zz12 listed with no reason (NOREASON). Then inert() runs once more in receipt-bl868's
# `ledger` mode over the same list: its set must be E1's INERT set minus exactly zz5, so the verify:-only seed fires
# in one mode and stays quiet in the other, and every other unread receipt still fires in both.
E="$WORK/e1probe"; ef() { mkdir -p "$(dirname "$E/$1")" && cat > "$E/$1"; }
mkdir -p "$E/scripts" "$E/docs" && : > "$E/VERSION"
for x in za/receipt-zz1 za/receipt-zz2 za/receipt-zz3 za/receipt-zz13 zb/receipt-zz4 zb/receipt-zz5 \
         zb/receipt-zz8 zb/receipt-zza zb/receipt-zz9 zd/receipt; do ef "core/fixtures/$x.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
ef core/fixtures/za/run.sh <<'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/receipt-zz2.sh" || exit 1
R="$HERE/receipt-zz3.sh"
bash "$R" || exit 1
bash "$HERE/receipt.sh"
true # bash "$HERE/receipt-zz13.sh"
EOF
ef core/fixtures/zc/lib.sh <<'EOF'
zc_check() { bash "$HERE/../zb/receipt-zz4.sh"; }
EOF
ef core/fixtures/zb/run.sh <<'EOF'
#!/usr/bin/env bash
# bash "$HERE/receipt-zza.sh" -- a comment, never a reader
echo "the receipt-zz9.sh receipt is run by hand"
EOF
ef scripts/receipt-zz10.sh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
ef scripts/receipt-zz11.sh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
ef scripts/receipt-zz12.sh <<'EOF'
#!/usr/bin/env bash
bash scripts/receipt-zz12.sh --self
EOF
ef scripts/zz-other.sh <<'EOF'
#!/usr/bin/env bash
bash scripts/receipt-zz11.sh
EOF
printf '%s\n' '# ledger' '' '## BL-1 -- live' '' 'verify: sh bash core/fixtures/zb/receipt-zz5.sh' > "$E/docs/backlog.md"
printf '%s\n' '# probe' "core/fixtures/zb/receipt-zz8.sh	held" "core/fixtures/zb/receipt-zz8.sh	again" \
  "core/fixtures/za/receipt-zz2.sh	read" "core/fixtures/gone/receipt.sh	absent" "scripts/receipt-zz12.sh" > "$E/scripts/inert-receipt-allowlist.txt"
{ pgit init -q "$E" && pgit -C "$E" add -A && pgit -C "$E" commit -q -m base; } >/dev/null 2>&1 \
  || { echo "validate-fixture-hygiene: REFUSED -- could not build the E1 probe repository" >&2; exit 2; }
printf '%s\n' 'DUP	core/fixtures/zb/receipt-zz8.sh' 'INERT	core/fixtures/za/receipt-zz1.sh' \
  'INERT	core/fixtures/zb/receipt-zz5.sh' 'INERT	core/fixtures/zb/receipt-zza.sh' 'INERT	core/fixtures/zd/receipt.sh' \
  'INERT	scripts/receipt-zz10.sh' 'NOREASON	scripts/receipt-zz12.sh' 'STALE	core/fixtures/gone/receipt.sh' \
  'STALE	core/fixtures/za/receipt-zz2.sh' | LC_ALL=C sort > "$WORK/e1p.want"
e1ok=0
eo="$(unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY; e1_run "$E" "$WORK/e1p")" || { sp_line E1 "FAIL -- $eo"; e1ok=1; }
if [ "$e1ok" = 0 ] && ! cmp -s "$WORK/e1p.want" "$WORK/e1p.verdict"; then
  e1ok=1; sp_line E1 "FAIL -- runners mode: verdict rows differ from the seeded set:"
  diff "$WORK/e1p.want" "$WORK/e1p.verdict" | sed -n 's/^</    want-only/p; s/^>/    got-only /p' >&2
fi
if [ "$e1ok" = 0 ]; then
  grep -vxF 'core/fixtures/zb/receipt-zz5.sh' "$WORK/e1p.inert" | LC_ALL=C sort > "$WORK/e1p-ledger.want"
  if ! ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY; inert "$E" "$WORK/e1p.e1list" "$WORK/e1p-ledger" ledger ); then
    e1ok=1; sp_line E1 "FAIL -- ledger mode: inert() returned non-zero over the probe"
  elif LC_ALL=C sort "$WORK/e1p-ledger" | cmp -s "$WORK/e1p-ledger.want" - && [ -s "$WORK/e1p-ledger.want" ] \
    && grep -qxF 'core/fixtures/zb/receipt-zz5.sh' "$WORK/e1p.inert"; then :
  else
    e1ok=1; sp_line E1 "FAIL -- ledger mode: inert() is not E1's INERT set minus exactly the verify:-only receipt zz5"
  fi
fi
if [ "$e1ok" = 0 ]; then sp_line E1 "ok (6 unread receipts fire, among them a verify:-only one, a comment-only one, another fixture's same-named one and a self-named scripts/ one; invocation by path, by variable, from a lib.sh, from scripts/, a message string and a trailing comment after code stay quiet; DUP, NOREASON and both STALE shapes fire; receipt-bl868's ledger mode reads the verify:-only one as read and every other unread one as inert)"
else SP_RED=1; fi

# --- the corpus ----------------------------------------------------------------------------------------------------
out="$(run_all "$ROOT" "$WORK/c")"; crc=$?
if [ "$crc" -ne 0 ]; then echo "validate-fixture-hygiene: REFUSED -- $out" >&2; exit 2; fi
t1="$(awk -F'\t' '$1 == "T" && $2 == "H1" { print $3 }' "$WORK/c.scan")"; t2="$(awk -F'\t' '$1 == "T" && $2 == "H2" { print $3 }' "$WORK/c.scan")"
t6="$(awk -F'\t' '$1 == "T" && $2 == "H6" { print $3 }' "$WORK/c.scan")"
nmem="$(grep -c '^DERIVE	' "$WORK/c.verdict")" || nmem=0
nblk="$(awk -F'\t' '$1 == "B" { print $2 }' "$WORK/c.scan" | LC_ALL=C sort -u | awk 'END { print NR }')"
if [ "${t1:-0}" -lt 1 ] || [ "${t2:-0}" -lt 1 ] || [ "${t6:-0}" -lt 1 ] || [ $((nmem + nblk)) -lt 1 ]; then
  echo "validate-fixture-hygiene: REFUSED -- a grammar stopped matching on the corpus (H1 candidates ${t1:-0}, H2 candidates ${t2:-0}, H6 lib sources ${t6:-0}, H5 members $((nmem + nblk))); this is not a clean tree." >&2
  exit 2
fi

if [ "$MODE" = derive ]; then
  [ "$SP_RED" = 0 ] || { echo "validate-fixture-hygiene: REFUSED -- the self-probe is red, so the derived set is unattributable" >&2; exit 2; }
  awk -F'\t' '$1 == "DERIVE" { print $2 "\t" $3 }' "$WORK/c.verdict"
  exit 0
fi

rc=0
echo "validate-fixture-hygiene: $(awk 'END { print NR }' "$WORK/c.list") fixture .sh scanned; judged $t1 H1 \`-d …/.git\` test(s) and $t2 H2 declared-tool \`command -v\` site(s); H5 $nblk block(s), $nmem unblocked member(s)"
for arm in H1 H2 H3 H6; do
  if grep -q "^$arm	" "$WORK/c.verdict"; then
    rc=1; echo "FAIL $arm:"
    awk -F'\t' -v A="$arm" '$1 == A { print "    " $2 ": " substr($3, 1, 160) }' "$WORK/c.verdict"
    case "$arm" in
      H1) echo "  A \`-d …/.git\` whose absent branch exits 0 SKIPs green in every linked worktree, where .git is a file. Use \`git -C <root> rev-parse --git-dir\`, or exit 2 FIXTURE BROKEN." ;;
      H2) echo "  A declared tool (tools.decl) whose absence exits 0 is a green skip on a direct run. Exit 2, FIXTURE BROKEN." ;;
      H3) echo "  /bin/sh reads no BASH_ENV, so the invocation counter cannot see this start. Start it with bash." ;;
      H6) echo "  A source of core/fixtures/lib/<x>.sh with no failure guard runs on when the file is absent, and the fixture reads green with fewer arms. End the line with: || { echo \"FIXTURE BROKEN: cannot source lib/<x>.sh\" >&2; exit 2; }" ;;
    esac
  fi
done
if grep -qE '^(FLOOR|ROW|JOIN|STALE|DUP|NOREASON|STUB)	' "$WORK/c.verdict"; then
  rc=1; echo "FAIL H5:"
  awk -F'\t' '$1 ~ /^(FLOOR|ROW|JOIN|STALE|DUP|NOREASON|STUB)$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.verdict"
  echo "  FLOOR: a mutant battery with no MUTANT-MATRIX block (fixture-mutants.md 'One run per distinct state'). STALE/DUP/NOREASON: fix $ALLOW_REL. ROW/JOIN: fix the block."
fi
n7="$(awk -F'\t' '$1 == "N7" { print $2 }' "$WORK/c.verdict")"; r7="$(grep -c '^R7	' "$WORK/c.verdict")" || r7=0
b7="$(grep -c '^B7	' "$WORK/c.verdict")" || b7=0
echo "validate-fixture-hygiene: H7 ${n7:-0} twin(s) of accepted MUTANT-MATRIX rows: $r7 resolved to an emitted label, $b7 listed built"
if grep -qE '^(H7|H7STALE|H7DUP|H7NOREASON)	' "$WORK/c.verdict"; then
  rc=1; echo "FAIL H7:"
  awk -F'\t' '$1 ~ /^H7(STALE|DUP|NOREASON)?$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.verdict"
  echo "  H7: a twins= token that none of H7's emission forms (its header: an ok/bad/pass/fail message word, matrix_row, arm_<T>(), a case pattern, a fixture function's argument or first message, a roster list, a for-list, a defined function that is not a printer, B_<T>=) reads off its fixture's code records a world the push never runs. Correct the row by re-measuring it with the block's REMEASURE command; a label BUILT at runtime is a row of $H7_ALLOW_REL keyed <fixture>:<mutant>:<token>. H7STALE/H7DUP/H7NOREASON: fix $H7_ALLOW_REL."
fi
h7m4_out="$(m4 "$ROOT" "$ROOT/$H7_ALLOW_REL" "$WORK/h7m4-root-base.txt" "$H7_ALLOW_REL" H7-M4 \
  "do not list the token; make the twin a label the fixture emits, or correct the MUTANT-MATRIX row by re-measuring it." \
  "<fixture>:<mutant>:<token> key")" || rc=1
echo "$h7m4_out"
m4_out="$(m4 "$ROOT" "$ROOT/$ALLOW_REL" "$WORK/m4-root-base.txt")" || rc=1
echo "$m4_out"
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
if [ "$SP_RED" != 0 ]; then
  echo "validate-fixture-hygiene: REFUSED -- the self-probe is red (above), so the verdict over the tree is unattributable." >&2
  exit 2
fi
nlist="$(awk 'END { print NR }' "$WORK/c.list")"
if [ "$rc" = 0 ]; then
  echo "OK: validate-fixture-hygiene -- self-probe fired both ways; $nlist fixture .sh scanned; H1 $t1 / H2 $t2 candidate test(s), no offender; H6 $t6 lib source(s), all guarded; H5 $nblk block(s), $nmem allowlisted member(s), no stale or added row; H7 ${n7:-0} twin(s), $r7 emitted, $b7 listed built; E1 $ne1 receipt(s), $ni1 inert and allowlisted."
fi
exit "$rc"
