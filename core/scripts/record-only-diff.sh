#!/usr/bin/env bash
# record-only-diff.sh — THE record-only partition and the `none, <reason>` grammar, defined once.
# validate-handoff-evidence.sh (the dev's full-collection line) and merge-review-shards.sh (QA's
# canonical-run line, serial and merged) both call this file; neither restates either rule.
#
#   record-only-diff.sh paths [-C <repo>] <story-file> <base> <frozen>
#   record-only-diff.sh none-reason <value>
#   record-only-diff.sh label <label>          (the document on stdin)
#   record-only-diff.sh run-shape <value> [<conventions file>]
#   record-only-diff.sh setup-shape <value>
#   record-only-diff.sh run-filter <value> [<conventions file>]
#   record-only-diff.sh run-span <value>       (the invocation span RUN-FILTER reads with no conventions file, on stdout)
#   record-only-diff.sh story-base [-C <repo>] <story-file> <base> [<frozen>]
#   record-only-diff.sh waiver [-C <root>] <story> <ref> <value>
#   record-only-diff.sh no-test-run <value> [<conventions file>]
#   record-only-diff.sh run-gate <value> [<conventions file>]
#
# RUN-GATE. RUN-SHAPE, NO-TEST-RUN and RUN-FILTER (below) asked of one value in ONE start, for the dev gate's
# full-collection arm; each answer is that rule's own, with the conventions file applied to all three. Exit 0: a run,
# unfiltered. 3: a run RUN-FILTER refuses (its reason on stdout). 2: a run whose filter cannot be evaluated (exit and
# output on stdout). Not a run: 1 when NO-TEST-RUN holds, else 4 (filter passes), 5 (filter refuses, reason on
# stdout) or 6 (filter unevaluable); the caller decides whether that value's filter verdict applies. 64: usage.
# A RUN-SHAPE exit other than 0 or 1 is 2.
#
# RUN-FILTER. Exit 0 when the invocation in <value> is the unfiltered canonical collection, 1 with
# the reason on stdout when it narrows it. TOKENS are blank-separated words, a quoted stretch (`"a; b.xml"`,
# `-o "addopts=-q; x"`) one token (rf_toks). A span RUNS PYTEST when a command of its CHAIN (below) has pytest as its
# COMMAND WORD: the first word after env assignments and `env`/`exec`/`time`, through an interpreter (`python* -m
# pytest`) or a launcher's `run`/`exec` (`uv run pytest`) (rf_cmdpy). BARE PYTEST: a command that is none of those
# but carries a bare `pytest`/`py.test` word behind a program the reader does not know (`direnv exec . pytest`, `nix
# develop -c pytest`, `./run pytest`) also runs pytest, read from that word (rf_cmdbare), unless the pipeline segment
# holding the word opens with a NOT-A-RUN program: `pip`, `pip3`, `pipx`, `uv pip`, `grep`, `egrep`, `fgrep`, `echo`,
# `printf`, or the text `version ok:` (`uv pip install pytest`, `grep pytest out.txt`, `version ok: pytest 9.1.1`). The invocation is the first backticked span
# that runs pytest; else, with a readable <conventions file>, a DECLARED WRAPPER run (below) in a span BEFORE that
# first pytest span (in any span when none runs pytest) is it, while an earlier pytest span still wins over a later
# wrapper span; else, when spans exist, PROSE: the value's `$ ` command (to its next backtick), or else its text before
# the first backtick, when it runs pytest, read to its first `, ` or ` (` (`pytest -q -k foo, working directory `backend/``
# reads `-q -k foo`; `pytest -q, working directory `backend/`` reads `-q`); else the first backticked span, else the
# text after a `$ ` prompt, else the value. The PROSE, `$ ` and whole-value readings end before the first COUNT PAIR:
# an integer token (`,` allowed, `9,234`) followed by `passed`,
# `failed`, `error(s)`, `skipped`, `deselected`, `xfailed`, `xpassed`, `warning(s)`, `collected` or `selected`
# (`$ pytest -q 1 passed, 0 failed` reads `-q`). The invocation is a CHAIN of commands cut at every `;`, `&&` and `||`
# token (and after a token ending in `;`); every command running `pytest` or a declared wrapper is read on its own
# and the value is refused when ANY of them narrows; a chain with neither is read whole, as one command. A command
# is read up to the first pipe or chain operator after the runner; a REDIRECTION there (`>`, `2>`, `>>`, `<`, `&>`
# with the next token as target, or one token carrying its target, `1>out.txt`, `2>&1`, `><capture>`) is skipped
# and the read goes on (`pytest -q 1>out.txt -k foo` reads `-k`). A token opening with a
# quote is never an operator, and one wholly quoted token is read as its unquoted text: rr_quote writes
# `'--junitxml=x>y'`; nor is a PLACEHOLDER: a token whose `>` all close `<...>` groups, `<repo>`,
# `<worktree>/.venv/bin/python`); the arguments are the tokens after the `pytest` token (`python -m pytest`
# included), the PAYLOAD of a declared wrapper run (DECLARED WRAPPER below), or every token when neither is present.
# VALUE OPTIONS take the next token as their value, never as a path: the options `pytest --help` shows with a
# metavar (pytest 8: `-p`, `-c`/`--config-file`, `-o`/`--override-ini`, `-W`, `-r`, `--rootdir`, `--tb`,
# `--maxfail`, `--junitxml`, `--log-*`, `--capture`, `--import-mode`, `--color`, ...), and those of pytest-xdist
# (`-n`, `--dist`, `--maxprocesses`, `--tx`), pytest-cov, pytest-timeout, pytest-rerunfailures (`--reruns`),
# pytest-randomly (`--randomly-seed`), pytest-asyncio and pytest-django, listed in rf_scan. An option outside that
# list takes no value: the token after it is read as an argument (`--foo bar` names the path `bar`), and
# `--opt=value` is always one token. ADDOPTS: the value of `-o`/`--override-ini` (`-o "addopts=-k foo"`,
# `-oaddopts=...`, `--override-ini=addopts=...`) is read, to its first `;` or ` #`, as arguments. A quote still open at
# the end of the text joins nothing (`-v' -k foo` reads `-k`). QUOTED COMMAND: when no command of the CHAIN runs pytest,
# a quoted token whose text does (`bash -lc "cd backend && pytest -k x"`, `ssh host "..."`, `sh -c '...'`) is read as
# its own span through the same chain reading; an escaped quote (`\"`, `\'`) is text when quotes are counted, the inner
# text is unescaped before it is read, and a quoted token inside it is scanned again (`bash -c "ssh h 'pytest -k x'"`,
# three levels). UNDECLARED WRAPPER: a command running no pytest and no declared
# wrapper whose PROGRAM (its first word after env assignments, interpreter words and options) names `pytest` and
# which hands arguments after a bare `--` (`python3 scripts/pytest-footprint-watchdog.py ... -- -n 8`) is refused by
# name: it runs a wrapper the conventions do not declare. A runner whose program names no pytest (`npm test -- -n 8`)
# is read as before, its flags and test-file arguments only.
# Refused in every spelling: `-k` (`-k x`, `-kx`, `-k"x"`, `--keyword`, `--keyword=x`), `--deselect`,
# `-t`, `--testNamePattern`, `-run`, `--ignore`/`--ignore-glob`, `--lf`/`--last-failed`, and `-x`
# (`--exitfirst`) with `--ff` (`--failed-first`); `--ff` alone reorders and still runs every test,
# and is accepted, as is `-x` alone. An explicit file
# (`*.py`) or node id (`::`) argument; and, for ANY runner, a path argument ending in a test-file
# suffix (`*.test.*`, `*.spec.*`, `*_test.go`, `test_*.py`, `*_test.py`) or any argument after a
# bare `--` (`npm test -- <path>`), unless the run is a declared wrapper's (DECLARED WRAPPER). A `-m <marker>` (or `-m<marker>`)
# and a path argument are accepted only when the consumer's own conventions declare them canonical:
# <conventions file> (the project's `docs/coding-conventions.md`, read by the caller) names a
# backticked `pytest` invocation carrying the same marker expression, or the same path (compared
# after `./` and a trailing `/` are dropped; an absolute argument matches by its trailing
# components), or a path that CONTAINS a declared one (`rebalancer` against a declared
# `rebalancer/tests` collects a superset, which is not narrowing). With <conventions file> absent or unreadable, `-m <marker>` is accepted and every
# path argument other than `.` is refused. Reference consumer: its conventions declare
# `pytest rebalancer/tests` and `<venv>/bin/python -m pytest -m unit`, and its QA records run both.
#
# DECLARED WRAPPER. Read only with a readable <conventions file>; without one, or with no declaration in it, every
# wrapper is read as above (refused in both RUN-FILTER and RUN-SHAPE, the reason unchanged). A DECLARATION is a
# backticked span of the conventions file that holds a bare `--`, names no `pytest`/`py.test` token by RUN-FILTER's
# token rule, names a PROGRAM, and carries after its `--` only placeholders (`<...>`, blanks inside one kept), at least
# one naming `pytest` (`<pytest args>`); a span such as `git checkout -- <file>` or `npm test -- --watch` declares
# nothing. The PROGRAM is the first token that is not an interpreter word (basename `python*`, `bash`, `sh`, `env`,
# `node`), an option (`-*`) or a placeholder-led token (`<...`), `./` dropped. Its OPTION SET is every `-*` token
# between the program and `--`; an option followed there by a value or placeholder (or spelled `--opt=value`) takes one
# value, an option followed by another option or by `--` takes none. The declarations are parsed apart from RUN-FILTER's
# argument reader, which would read the `>` of a placeholder as a shell operator. Reference consumer: its line
# `python3 scripts/pytest-footprint-watchdog.py --cwd <repo-root> --python <venv>/bin/python --artifact
# test-results/<name>.txt -- <pytest args>` declares that program with `--cwd`, `--python` and `--artifact`, one value each.
# A RUN of the span RUN-FILTER reads (rf_span) is a WRAPPER RUN when its program, by the same rule (interpreter options
# such as `-u` skipped; a shell operator before the program restarts the reading, and a `pytest` token anywhere before
# the payload leaves the span to the reading above, so `pytest -k x ; <wrapper> ...` stays refused), equals a declared one: a relative
# token by equality after `./` is dropped, an absolute token also by its trailing components (`/w/s/scripts/x.py`
# matches `scripts/x.py`, `evil/scripts/x.py` does not). Every token between the program and the run's first bare `--`
# must be a declared option matched exactly (never by prefix: `--adm` is not `--admit-only`; `--opt=value` only for an
# option taking a value) or the one value after a declared option that takes one; any other token (an undeclared
# option such as `--admit-only`, or a positional, which would narrow what the wrapper runs) is refused naming it, and
# so is a run carrying no bare `--`. The PAYLOAD is the tokens after that `--` up to the first shell operator (the
# quote rule above), every bare `--` dropped as the wrapper drops it, read EXACTLY as the arguments after a `pytest`
# token: a wrapper run passes RUN-FILTER iff `python -m pytest <payload>` does. RUN-SHAPE only WIDENS: a wrapper run
# within a declaration is a run, after NO-TEST-RUN (`-- --co ...` is no run); any other value, a declared wrapper run
# outside its declaration included (`--prelude`, `--admit-only`), gets exactly the reading it had without this arm, so
# RUN-SHAPE's answer can move from 1 to 0 and never from 0 to 1. The refusal of an undeclared option or a positional
# is RUN-FILTER's. Callers widened: validate-handoff-evidence.sh's full-collection arm (the dev's line: RUN-GATE,
# RUN-SHAPE and RUN-FILTER in one start, the filter applied to every value accepted as a run, its header (k)); merge-review-shards.sh's canon_gate (RUN-SHAPE on `Canonical run:`, and
# RUN-FILTER on it), run_bind (RUN-FILTER on the recorded invocation) and rr_record (RUN-FILTER only, before the run executes, the rule run_bind applies);
# run_bind's run-span is unchanged. Interpreter options that take a value
# (`python -W ignore x.py`, `env VAR=x x.py`) are read as the program and refused; that over-refusal is accepted.
# THE RELOCATION RESIDUAL. The wrapper's `--cwd` and `--python` can point the run at another checkout or interpreter;
# that is the wrapper analogue of a plain run naming an absolute path into another checkout
# (`python -m pytest /other/checkout/rebalancer/tests`, accepted today by its trailing components), not a new opening.
# The same residual covers SUBDIRECTORY narrowing: `--cwd <repo>/rebalancer/tests/unit` with a payload naming no path
# collects only that subdirectory, as does merge-review-shards.sh `--record-run --dir <subdir>` (pre-existing), whose
# recorded `.dir` run_bind never checks. Neither is read here.
#
# STORY-BASE. The serial seat supplies its own --range, so the exemption's base is held to the
# shape a gate-1 base has. With the optional third operand <frozen> (the exemption caller passes it),
# a <story-file> that is not a blob at <base> is decided first: a tree or commit there is exit 2, and
# a path absent at <base> is exit 0 only when it is a blob at <frozen> (a story created after the
# base), else exit 2 (a typo, a directory, a path inside .git/). The two-operand form keeps the old
# reading below, where absent at <base> is exit 0. In BOTH forms a story absent at <base> is exit 1 when the
# path was ever in the history of <base> (`rev-list --full-history`: deleted, then re-added; BL-904), and exit 2
# in a shallow repository. Exit 0 when <story-file> at <base> is absent, or carries no column-0
# `Full-collection run:` label and a frontmatter `status:` other than `review` and `done` (the dev
# has not handed off yet). <story-file> is read as PATHS reads it: repo-relative or absolute inside
# the repository; any other spelling is exit 2. Exit 1 with the reason on stdout otherwise: <base> is a later sha (a
# rework pass's previous frozen sha, or the frozen sha itself), which narrows the range the
# exemption is decided over. Exit 2 UNEVALUABLE. Measured on the reference consumer's 73 shard
# manifests: all 35 gate-1 bases answer 0 (status `ready`/`ready-for-dev`, no label); 24 of the 38
# pass-M bases answer 1 (20 `status: review`, 4 already carrying the label) and 14 answer 0.
#
# LABEL. The value of the first LABEL LINE of the document on stdin: a line outside ``` / ~~~
# fences that begins, at column 0 or after one `- ` or `* ` bullet, with <label> exactly (a trailing
# CR dropped); the value is the rest of the line with leading blanks dropped. An EMPTY rest is
# continued (dev.md: "on that line or the next"): the value is then the next non-blank line
# outside a fence (the invocation written under the label); when that next block is a fence, the
# fence's non-blank lines joined by one blank, plus the first non-blank line after the fence (the
# counts written below it). A continuation line that is a `#` heading or itself opens with a label
# (`Dependency setup: ...`, `- Dependency setup: ...`, `**Dependency setup:**`, `**Label**:`, any
# `Word Word:`) is not taken; an empty fence followed by such a line is an empty value. One
# label is a continuation: `Invocation: <cmd>` (bulleted or not) gives the text after its colon.
# Exit 0 with the value on stdout, 1 when no line carries the label. `**Label:**`, a `### Label`
# heading and `Label, working directory ...` are not the label.
#
# RUN-SHAPE. The no-run reading is decided FIRST: a value that NONE-REASON reads as a none form
# (exit 0 or 1), or that opens with a pointer or deferral word (`see`, `refer`, `N/A`, `NA`, `TBD`,
# `TODO`, `deferred`, `pending`), is never a run. Otherwise exit 0 when <value> records a run: a
# backticked span, a `$ ` command, or the value's own opening command naming a RUNNER (`pytest`,
# `python -m pytest`, `vitest`, `jest`, `npx`, `npm test`, `go test`, `cargo test`, `make test`,
# `bun test`, a `bash <...test...>.sh` script, or the first word of a backticked command on a
# <conventions file> line naming `canonical`), a DECLARED WRAPPER run within its declaration (below; this arm only
# widens: any other value, a declared wrapper outside its declaration included, is read by the other arms exactly as
# without it), or a count `<n> passed|failed` (dev.md: "the
# invocation and counts"). Exit 1 otherwise: a two-word span naming no runner (`make docs`) and a
# `0 tests collected` are not runs. Before the runner and count arms, a NO-TEST invocation is exit 1
# (NO-TEST-RUN below), whatever runner or count the value also carries.
#
# NO-TEST-RUN. Exit 0 when a text one of RUN-SHAPE's run arms reads carries a whole token
# `--collect-only`, `--collectonly` or `--co` (pytest registers the one option under all three
# spellings), bounded on each side by the end of the text or by any character NOT in
# `[A-Za-z0-9_-]` (a blank, a backtick, `,`, `;`, `|`, `=`): pytest collects and runs no test.
# `--collect-onlyx`, `--co2` and `---co` are not that token. The texts are the invocation span (rf_span), each
# `$ ` command up to its next backtick, and each line of the value (leading markup skipped on the
# first) up to its first backtick, so a
# bare collect-only invocation whose only backticked span is its working directory is no run either. `--cov`, `--color` and
# `--config` are not that token. Exit 1 otherwise. RUN-SHAPE applies it, and the dev gate's
# full-collection arm asks it before its capture-heads count route, so a collect-only value cannot
# borrow another capture's count. WHICH SPAN: RUN-SHAPE, RUN-FILTER and `no-test-run <value> <conventions file>`
# choose the span WITH that file (a declared wrapper run before the first `pytest` span wins, header: RUN-FILTER);
# the dev gate asks RUN-GATE with its conventions file, so its capture-heads route decides the
# no-test token on the span RUN-FILTER reads (`ran `<wrapper> -- --co -q`` followed by a later bare-`pytest` span is
# no run there). `run-span` and `no-test-run <value>` with no file choose it WITHOUT one: the first `pytest` span wins.
#
# WAIVER. Exit 0, printing `WAIVED: <AC-id>`, when <value>, read after NONE-REASON's leading-markup
# skip (blanks, `*`, backticks), is exactly `none, <AC-id> waives it` (case-sensitive; <AC-id> is
# `[A-Za-z][A-Za-z0-9._-]*`; an optional `; <free text>` may follow and carries no meaning), AND
# <story> as committed at <ref> carries, outside ``` / ~~~ fences and with CRs dropped, exactly one
# `## Canonical-run waivers` heading (`^##[ \t]+Canonical-run waivers[ \t]*$`) under which, before the
# next `^## ` line, a line begins exactly `- **<AC-id>** waives the canonical run` (a fixed-string
# compare, never a pattern). <ref> is the caller's BASE, never the frozen sha: the story is a record
# path inside base..frozen, so an entry added in the range is written by the party being judged.
# Exit 1 with `NOT-WAIVED: <why>` on stdout when the value is not a waiver spelling, the story is
# absent at <ref>, or the section or entry is missing or the heading is not unique. Exit 2 UNEVALUABLE
# (stderr) when <ref> does not resolve, <story> cannot be normalised (PATHS' rule), or the path at
# <ref> is a tree or a commit. Usage errors exit 64. Each caller maps 0 to accept, 1 to the unchanged
# PATHS exemption, and any other exit to a refusal naming the waiver error.
#
# SETUP-SHAPE. The same no-run reading first; then exit 0 when <value> is one backticked command
# with an argument (`pip install -r requirements.txt`), a `$ ` command, or names an interpreter or
# venv path (a backticked span holding `/bin/python` or `venv`) together with the packages it
# provides (`web3 7.16.0`, `... installed`, `(pytest-xdist)`, `with pytest-xdist`). The path is
# read as text; whether it exists is not checked here. Exit 1 otherwise.
#
# A value that is not a run is a NO-RUN CLAIM, whatever it says (`none, <reason>`, `N/A`, `TBD`,
# `deferred to QA`, `see dev report`, an empty value): each caller holds every no-run claim to the
# record-only partition below, and refuses a bare `none` (NONE-REASON exit 1) outright.
#
# PATHS. Exit 0 when every path `git diff --name-only --no-renames <base> <frozen>` lists is a
# RECORD path; stdout then carries `RECORD-ONLY: <n> changed path(s)`. Exit 1 when one is not;
# stdout carries `NOT-RECORD-ONLY: <n> changed path(s), first non-record path <p>`. Exit 2
# UNEVALUABLE (not a repository, a ref that does not resolve), with the reason on stderr.
# <story-file> is repo-relative (a leading `./` is dropped) or absolute inside the repository; an
# absolute path is resolved physically, and a spelling that cannot be normalised (empty, or an empty,
# `.` or `..` component) or a path outside the repository is exit 2 UNEVALUABLE.
# An empty diff (base == frozen) is record-only: nothing the canonical collection reads moved.
#
# THE PARTITION. A path is a record path when it is exactly one of:
#   - the <story-file> argument itself (identity, after the story is made repo-relative: see PATHS);
#   - `_bmad-output/implementation-artifacts/sprint-status.yaml` or
#     `_bmad-output/planning-artifacts/sprint-status.yaml` (sprint-status.sh's two VIEWS);
#   - anything under `docs/reviews/`, `test-results/` or `docs/escalations/`, EXCEPT a file a
#     collection or a runner can load: a `*.py`, `*.sh`, `*.toml` or `*.cfg`, a `conftest.py` or a
#     `pytest.ini` under those directories is NOT a record path (`test-results/test_evil.py` is
#     collected by a bare `pytest` from the root). The reference consumer tracks 15 such files there.
#     Nor is an entry there whose new mode is a symlink (120000) or a gitlink (160000): a committed
#     `docs/reviews/s1` link to `s2` would choose where the merge's shards physically land.
# Every other path is one the canonical collection may read, so a diff touching it owes a run.
# `docs/coding-conventions.md` and `docs/architecture.md` are NOT record paths: a docs-only story
# that edits them owes the full collection (a test can read either), and is refused a `none`.
# NOT the single source: core/schemas/pipeline-state-paths.json classifies the top-level entries
# under `_bmad-output/` as transient or durable. Its durable half holds `planning-artifacts` and
# `implementation-artifacts` WHOLE (PRDs, architecture, every story), so it answers "is this
# committed", not "can a test read this", and is not read here.
# THE RESIDUAL. A record path can still change a canonical test's outcome: the reference
# consumer's `test_s319_4_2_merkl_claim.py:617` reads a committed record. The partition accepts
# that risk for the five classes above; it is the reason the class list is short.
#
# NONE-REASON. Exit 0 when <value> is `none` (or `not run` / `not executed`, the same claim
# spelled in words), any run of non-alphanumeric separators, then a reason carrying at least one
# letter or digit: `none, no code changed`, `none (system python3)`, `none - see below`. Leading
# blanks, `*` and backticks are skipped. Exit 1 when the claim carries no reason (`none`,
# `none.`, `` `none` ``). Exit 2 when <value> is not a none form at all (an invocation, a pointer
# such as `see dev report`, `nonexistent`).
ro_label() {
    [ $# -eq 2 ] && [ -n "$2" ] || { echo "usage: $ME label <label> < <document>" >&2; exit 64; }
    RO_L="$2" awk '
      function islabel(t) { return t ~ /^[A-Za-z][A-Za-z0-9 _-]*:([ \t]|$)/ || t ~ /^\*\*[A-Za-z][A-Za-z0-9 _-]*(:\*\*|\*\*:)/ }
      BEGIN { L = ENVIRON["RO_L"] }
      { sub(/\r$/, "") }
      /^[ \t]*(```|~~~)/ { f = !f; if (cont && f && !post) inf = 1; if (inf && !f) { inf = 0; post = 1 } next }
      inf && /^[ \t]*$/ { next }
      inf { v = $0; sub(/^[ \t]+/, "", v); fb = (fb == "" ? v : fb " " v); next }
      f { next }
      { s = $0; sub(/^[-*] /, "", s) }
      cont && /^[ \t]*$/ { next }
      post { if (fb != "" && $0 !~ /^#/ && !islabel(s)) { v = $0; sub(/^[ \t]+/, "", v); fb = fb " " v } print fb; done = 1; exit }
      cont { if ($0 ~ /^#/) v = ""
             else if (s ~ /^Invocation:[ \t]/) { v = s; sub(/^Invocation:[ \t]+/, "", v) }
             else if (!islabel(s)) { v = $0; sub(/^[ \t]+/, "", v) }
             print v; done = 1; exit }
      substr(s, 1, length(L)) == L { v = substr(s, length(L) + 1); sub(/^[ \t]+/, "", v); hit = 1
        if (v != "") { print v; done = 1; exit }
        cont = 1; next }
      END { if (hit && !done) print ((post || inf) ? fb : ""); exit !hit }'
    exit $?
}
# rf_span <text> [<conventions file>] -> the invocation span RUN-FILTER reads (header: RUN-FILTER), the one definition:
# run-filter reads it, and `run-span` prints it (no conventions file) for merge-review-shards.sh's run binding, which
# compares it with the recorded invocation. A repeat of the value ro_shape last spanned (RF_SPAN_V) is answered from
# RF_SPAN_S, its captured span (with ro_shape's conventions file), with no process.
rf_span() {
  if [ "${RF_SPAN_V+set}" = set ] && [ "$1" = "$RF_SPAN_V" ]; then printf '%s' "$RF_SPAN_S"; return 0; fi
  local t="$1" s c
  local sp=""
  sp="$(grep -oE '`[^`]*`' <<<"$t")" || sp=""
  # The first span whose CHAIN runs pytest as a command word (rf_spanpy), never one merely holding the word.
  s=""
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    rf_spanpy "${c:1:${#c}-2}" && { s="$c"; break; }
  done <<<"$sp"
  # A declared wrapper run before the first pytest span (every span when none names pytest) is the invocation
  # (header: RUN-FILTER): a later span's bare `pytest` word (`version ok: pytest 9.1.1`) is not read over it.
  if [ -n "$sp" ] && [ $# -ge 2 ] && [ -n "$2" ] && [ -r "$2" ] && rw_any "$2"; then
    while IFS= read -r c; do
      [ -n "$s" ] && [ "$c" = "$s" ] && break
      c="${c#\`}"; c="${c%\`}"
      rw_wrap "$c" "$2"
      [ "$RW" = none ] || { printf '%s' "$c"; return 0; }
    done <<<"$sp"
  fi
  local re='(^|[[:space:]])[0-9][0-9,]*[[:space:]]+(passed|failed|errors?|skipped|deselected|xfailed|xpassed|warnings?|collected|selected)([^A-Za-z]|$)'
  # PROSE (header: RUN-FILTER): no span names pytest or a declared wrapper, and the value's `$ ` command (to its next
  # backtick), else its text before the first backtick, runs pytest (rf_spanpy): that text, to its first `, ` or count
  # pair, is the invocation. `pytest -q, working directory `backend/`` reads `-q`, never `working directory`.
  if [ -z "$s" ] && [ -n "$sp" ]; then
    case "$t" in *'$ '*) c="${t#*\$ }" ;; *) c="$t" ;; esac
    c="${c%%\`*}"; c="${c%%,[[:space:]]*}"; c="${c%,}"; c="${c%%[[:space:]](*}"
    if [[ $c =~ $re ]]; then c="${c%%"${BASH_REMATCH[0]}"*}"; fi
    rf_spanpy "$c" && s="$c"
  fi
  [ -n "$s" ] || s="$(awk 'NF { print; exit }' <<<"$sp")"
  if [ -z "$s" ]; then
    case "$t" in *'$ '*) s="${t#*\$ }" ;; *) s="$t" ;; esac
    # The `$ ` reading and the whole-value fallback end before the first COUNT PAIR (header: RUN-FILTER).
    if [[ $s =~ $re ]]; then s="${s%%"${BASH_REMATCH[0]}"*}"; fi
  fi
  s="${s#\`}"; printf '%s' "${s%\`}"
}
# rf_ph <token>: 0 when <token> is a PLACEHOLDER (header: RUN-FILTER), never a shell operator: it carries a `>` and
# dropping every `<...>` group leaves no `<` or `>` (`<repo>`, `<worktree>/.venv/bin/python`); `>`, `2>&1`,
# `>out.txt` and `<` are not. rw_wrap's awk oper() applies the same rule through opx().
rf_ph() {
  case "$1" in *'>'*) ;; *) return 1 ;; esac
  local x="$1" re='<[^<>]+>'
  while [[ $x =~ $re ]]; do x="${x/"${BASH_REMATCH[0]}"/}"; done
  case "$x" in *[\<\>]*) return 1 ;; esac
  return 0
}
# rf_toks <text> -> RF_T, one TOKEN per line (header: RUN-FILTER): blank-separated words, a word opening an unbalanced
# `"` (or, holding no `"`, an unbalanced `'`) joined with the following words up to the one closing it, so a quoted
# `;`, `|` or `>` stays inside its token (`--junitxml "a; b.xml"`). No process.
rf_toks() {
  local w q="" cur="" n e
  RF_T=""
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f
  for w in "$@"; do
    # An escaped quote (`\"`, `\'`) is text, never a quote: it is dropped before the quotes are counted.
    e="${w//\\\"/}"; e="${e//\\\'/}"
    if [ -n "$q" ]; then
      cur="$cur $w"
      if [ "$q" = '"' ]; then n="${e//[!\"]/}"; else n="${e//[!\']/}"; fi
      [ $(( ${#n} % 2 )) = 0 ] || { RF_T="$RF_T$cur"$'\n'; cur=""; q=""; }
      continue
    fi
    n="${e//[!\"]/}"
    if [ $(( ${#n} % 2 )) = 1 ]; then q='"'; cur="$w"; continue; fi
    if [ -z "$n" ]; then n="${e//[!\']/}"; [ $(( ${#n} % 2 )) = 0 ] || { q="'"; cur="$w"; continue; }; fi
    RF_T="$RF_T$w"$'\n'
  done
  # A quote still open at the end joins nothing: its words are tokens again (`-v' -k foo` reads -k).
  if [ -n "$q" ]; then
    set -f
    # shellcheck disable=SC2086
    set -- $cur
    set +f
    for w in "$@"; do RF_T="$RF_T$w"$'\n'; done
  fi
}
# rf_cmdv <span> -> RF_C, one command per line: the span's tokens cut at every unquoted `;`, `&&` and `||` token, and
# after an unquoted token ending in `;` (`out.txt; pytest -k x`), a CHAIN. rf_cmds prints it.
rf_cmdv() {
  local w c=""
  RF_C=""
  rf_toks "$1"
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    case "$w" in
      ';'|'&&'|'||') RF_C="$RF_C$c"$'\n'; c=""; continue ;;
      \'*|\"*) ;;
      *';') c="${c:+$c }${w%;}"; RF_C="$RF_C$c"$'\n'; c=""; continue ;;
    esac
    c="${c:+$c }$w"
  done <<<"$RF_T"
  RF_C="$RF_C$c"$'\n'
}
rf_cmds() { rf_cmdv "$1"; printf '%s' "$RF_C"; }
# rf_cmdpy <command> -> 0 when pytest is the command's COMMAND WORD (header: RUN-FILTER): its first word after env
# assignments (`VAR=x`) and numeric arguments, after a PREFIX command (`env`, `exec`, `time`, `timeout`, `nice`,
# `nohup`, `sudo`, `xvfb-run`, `npx`, `uvx`, `stdbuf`, `command`, `docker`, `kubectl`) the first later pytest word
# before an operator, whatever options and values the prefix takes (`timeout -s KILL 600 pytest`, `docker compose run
# --rm -e X=1 app pytest`, `kubectl exec pod -- pytest`), an interpreter (`python* [-opts] -m pytest`, `-X`/`-W` taking a value) or a launcher's `run`/`exec`
# subcommand (`uv run pytest`, `poetry run python -m pytest`, `pipx run pytest`). A pytest word anywhere else (`uv pip
# install pytest`, `grep pytest out.txt`, `version ok: pytest 9.1.1`) is not the invocation.
rf_cmdpy() {
  local w b st=0
  rf_toks "$1"
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    b="${w##*/}"
    case "$st" in
      0) case "$w" in [A-Za-z_]*=*|-*|[0-9]|[0-9]*[0-9smhd]) continue ;; esac
         case "$b" in env|exec|time|timeout|nice|nohup|sudo|xvfb-run|npx|uvx|stdbuf|command|docker|kubectl) st=8; continue ;; pytest|py.test) return 0 ;; python*) st=2; continue ;; esac
         st=1 ;;
      # After a PREFIX word, whatever options and values it takes: the first later pytest word before an operator.
      8) case "$w" in \'*|\"*) continue ;; '|'|'<'|*'>'*) return 1 ;; esac
         case "$b" in pytest|py.test) return 0 ;; esac ;;
      1) case "$w" in run|exec) st=3; continue ;; esac; return 1 ;;
      2) case "$w" in -m) st=4; continue ;; -X|-W) st=7; continue ;; -*) continue ;; esac; return 1 ;;
      7) st=2 ;;
      3) case "$w" in -*) continue ;; esac
         case "$b" in pytest|py.test) return 0 ;; python*) st=2; continue ;; esac; return 1 ;;
      4) case "$w" in pytest|py.test) return 0 ;; esac; return 1 ;;
    esac
  done <<<"$RF_T"
  return 1
}
# rf_redir <operator token> -> 1 for a pipe or chain operator, which ends a runner's read; 0 for a REDIRECTION, with
# sk=1 (the caller's) when its target is the next token (`>`, `2>`, `>>`, `<`, `&>`), not part of it (`>out`, `2>&1`).
rf_redir() {
  case "$1" in '|'|'||'|'&&'|';') return 1 ;; '>'|'>>'|'<'|[0-9]'>'|[0-9]'>>'|[0-9]'<'|'&>'|'&>>') sk=1 ;; esac
  return 0
}
# rf_cmdbare <command> -> 0 when the command is no command-word run (rf_cmdpy) but carries a BARE `pytest`/`py.test`
# word behind a program the reader does not know (`direnv exec . pytest`, `nix develop -c pytest`, `./run pytest`):
# base's last-resort reading, rf_args from that word (header: RUN-FILTER, BARE PYTEST). Skipped when the pipeline
# segment holding the word opens with a NOT-A-RUN program: `pip`, `pip3`, `pipx`, `uv pip`, `grep`, `echo`,
# `printf`, or the text `version ok:`.
rf_cmdbare() {
  local w p="" p2="" hit=0
  rf_toks "$1"
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    case "$w" in '|'|'||') p=""; p2=""; continue ;; esac
    if [ -z "$p" ]; then case "$w" in [A-Za-z_]*=*) continue ;; esac; p="${w##*/}"
    elif [ -z "$p2" ]; then p2="$w"; fi
    case "${w##*/}" in
      pytest|py.test)
        case "$p" in pip|pip3|pipx|grep|egrep|fgrep|echo|printf) continue ;; uv) [ "$p2" = pip ] && continue ;; version) [ "$p2" = ok: ] && continue ;; esac
        hit=1; break ;;
    esac
  done <<<"$RF_T"
  [ "$hit" = 1 ]
}
# rf_spanpy <span> -> 0 when a command of the span's CHAIN runs pytest (rf_cmdpy), or carries a bare one (rf_cmdbare).
rf_spanpy() {
  local c cs
  rf_cmdv "$1"; cs="$RF_C"
  while IFS= read -r c; do [ -n "$c" ] && { rf_cmdpy "$c" || rf_cmdbare "$c"; } && return 0; done <<<"$cs"
  return 1
}
# rw_wrap <span> <conventions file> -> RW (header: DECLARED WRAPPER): `none` when <span> runs no wrapper the file
# declares; `ok`, then the payload one argument per line, when it runs one within a declaration; `x<TAB><reason>`
# when it runs one outside every declaration of that program. The declarations are parsed here and never through
# rf_args, which would read the `>` of a `<placeholder>` as a shell operator. One awk; the caller checks -r.
# rw_any <conventions file>: 0 when the file holds a bare `--` token, which every declaration holds, else 1. Read by
# the builtin (no process), so a conventions file declaring nothing costs no awk and no rf_span. Not keyed on the
# RUN span: a declared wrapper run with no `--` must still reach the awk, which refuses it (`--admit-only` with no
# `--` would otherwise read as base did, and pass).
rw_any() {
  local rw_c=""
  IFS= read -r -d '' rw_c < "$1" || :
  case "$rw_c" in *[[:space:]\`]--[[:space:]\`]*) return 0 ;; esac
  return 1
}
rw_wrap() {
  rw_any "$2" || { RW=none; return 0; }
  RW="$(RW_SPAN="$1" awk '
    function base(t) { sub(/.*\//, "", t); return t }
    function interp(t,  b) { b = base(t); return b ~ /^python/ || b == "bash" || b == "sh" || b == "env" || b == "node" }
    function quoted(t,  c) { c = substr(t, 1, 1); return c == "\"" || c == q }
    function oper(t) { if (quoted(t)) return 0; return opx(t) }
    # rf_ph (record-only-diff.sh) in awk: a token carrying `>` is an operator unless dropping its <...> placeholders leaves no < or >.
    function opx(t,  x) { if (t == "|" || t == "||" || t == "&&" || t == ";" || t == "<") return 1
      if (!index(t, ">")) return 0; x = t; gsub(/<[^<>]+>/, "", x); return index(x, "<") > 0 || index(x, ">") > 0 }
    # TERMINATION: every loop below consumes at least one character or token per pass, as each one states. No call
    # inside a match() loop may run before that loop has advanced its subject: RSTART and RLENGTH are global, and a
    # nested match() resets them (to 0 and -1 on a miss, which re-reads the whole subject).
    # Loop: each pass drops two characters ("./").
    function nprog(t) { while (substr(t, 1, 2) == "./") t = substr(t, 3); return t }
    function ph(t) { return t ~ /^<[^<>]*>$/ }
    function pm(r, d) { return r == d || (substr(r, 1, 1) == "/" && length(r) > length(d) + 1 && substr(r, length(r) - length(d)) == "/" d) }
    # One backticked span: a declaration when it holds a bare --, names no pytest token, names a program, and every
    # token after its -- is a placeholder, one of them naming pytest.
    function decl(sp,   s, r, h, T, n, i, k, t, p, o, ar, os, dd, nt, py) {
      if ((" " sp " ") ~ /[[:space:]\/](pytest|py\.test)[[:space:]]/) return
      s = sp; r = ""
      # Loop: each pass drops the matched placeholder, at least two characters, from s.
      while (match(s, /<[^<>]*>/)) { h = substr(s, RSTART, RLENGTH); gsub(/[[:space:]]/, sep, h); r = r substr(s, 1, RSTART - 1) h; s = substr(s, RSTART + RLENGTH) }
      n = split(r s, T, /[[:space:]]+/); p = ""
      # Loops over T (here and below): each pass advances i by at least one token, bounded by n.
      for (i = 1; i <= n; i++) { t = T[i]; if (t == "") continue; if (t == "--") return
        if (interp(t) || t ~ /^-/ || t ~ /^</) continue
        p = nprog(t); break }
      if (p == "") return
      os = "|"; dd = 0
      for (i++; i <= n; i++) { t = T[i]; if (t == "") continue
        if (t == "--") { dd = i; break }
        if (t !~ /^-/) continue
        o = t; ar = 0
        if (index(o, "=")) { o = substr(o, 1, index(o, "=") - 1); ar = 1 }
        else { for (k = i + 1; k <= n && T[k] == ""; k++) ; if (k <= n && T[k] != "--" && T[k] !~ /^-/) { ar = 1; i = k } }
        os = os o "=" ar "|" }
      if (!dd) return
      nt = 0; py = 0
      for (i = dd + 1; i <= n; i++) { t = T[i]; if (t == "") continue; nt++; if (!ph(t)) return; if (index(t, "pytest")) py = 1 }
      if (!nt || !py) return
      nd++; DP[nd] = p; DO[nd] = os
    }
    # The run against one declaration: every token before the first bare -- is a declared option, its value when the
    # declaration gives it one, or a refusal naming it.
    function w3(os, dp,   i, t, o) {
      # Loop: each pass advances i by one or two tokens, bounded by nw.
      for (i = 1; i <= nw; i++) { t = W[i]
        if (t !~ /^-/) return "hands the declared wrapper " dp " an argument before its bare -- (" t "), which narrows what it runs"
        o = t
        if (index(o, "=")) { o = substr(o, 1, index(o, "=") - 1)
          if (index(os, "|" o "=1|")) continue
          if (index(os, "|" o "=0|")) return "hands the declared wrapper " dp " a value for an option its conventions declaration gives none (" t ")"
          return "hands the declared wrapper " dp " an option its conventions declaration does not carry (" t ")" }
        if (index(os, "|" o "=1|")) { if (i < nw && W[i + 1] !~ /^-/) i++; continue }
        if (index(os, "|" o "=0|")) continue
        return "hands the declared wrapper " dp " an option its conventions declaration does not carry (" t ")" }
      if (st != 2) return "runs the declared wrapper " dp " with no bare -- before its pytest arguments"
      return ""
    }
    BEGIN { q = sprintf("%c", 39); sep = sprintf("%c", 1); nd = 0 }
    # Loop: each pass drops the matched span, at least two characters, from line BEFORE decl() runs its own match().
    { line = $0; while (match(line, /`[^`]*`/)) { sp = substr(line, RSTART + 1, RLENGTH - 2); line = substr(line, RSTART + RLENGTH); decl(sp) } }
    END {
      if (!nd) { print "none"; exit 0 }
      n = split(ENVIRON["RW_SPAN"], T, /[[:space:]]+/); p = ""; st = 0; nw = 0; pay = ""
      # Loop: each pass advances i by one token, bounded by n; the declaration loop after it advances d, bounded by nd.
      for (i = 1; i <= n; i++) { t = T[i]; if (t == "") continue
        # A pytest token before the payload: rf_args reads that run (and stops at its operator), as without a wrapper.
        # Read only where a program is sought (st 0): a declared option VALUE (`--python /v/bin/pytest`) is not a run.
        if (st == 0 && t ~ /^(.*\/)?(pytest|py\.test)$/) { print "none"; exit 0 }
        # In the payload a redirection is skipped with its one target (rf_redir); a pipe or chain operator ends it.
        if (oper(t)) { if (st == 2) { if (t == "|" || t == "||" || t == "&&" || t == ";") break; if (t ~ /^[0-9&]?(>|>>|<)$/) i++; continue }
          p = ""; st = 0; nw = 0; continue }
        if (st == 0) { if (interp(t) || t ~ /^-/) continue; p = nprog(t); st = 1; continue }
        if (st == 1) { if (t == "--") st = 2; else W[++nw] = t; continue }
        if (t != "--") pay = pay t "\n" }
      if (p == "") { print "none"; exit 0 }
      m = 0; y1 = ""
      for (d = 1; d <= nd; d++) { if (!pm(p, DP[d])) continue
        m = 1; y = w3(DO[d], DP[d])
        if (y == "") { printf "ok\n%s", pay; exit 0 }
        if (y1 == "") y1 = y }
      if (!m) { print "none"; exit 0 }
      printf "x\t%s\n", y1
    }' "$2")" || RW=none
}
# ro_no_test <value>: 0 when a text a RUN-SHAPE run arm reads carries a whole no-test token (header: NO-TEST-RUN),
# 1 otherwise. One line per text: rf_span's span (the span arm), each `$ ` command up to its next backtick (the
# `$ ` arm), and each line of the value, leading markup skipped, up to its first backtick (the opening-command arm).
ro_no_test() {
    local nt_s nt_v="${1#"${1%%[![:space:]*\`]*}"}"
    nt_s="$(rf_span "$1")"
    nt_s="$nt_s"$'\n'"$(grep -oE '(^|[[:space:]])\$ [^`]*' <<<"$1")"
    nt_s="$nt_s"$'\n'"$(awk '{ sub(/`.*/, ""); print }' <<<"$nt_v")"
    # The token boundary: every byte outside [A-Za-z0-9_-] becomes a blank, so the token ends at punctuation too.
    nt_s="$(LC_ALL=C tr -c 'A-Za-z0-9_-' ' ' <<<"$nt_s")"
    case " $nt_s " in *" --collect-only "*|*" --collectonly "*|*" --co "*) return 0 ;; esac
    return 1
}
ro_run_filter() {
    [ $# -eq 2 ] || [ $# -eq 3 ] || { echo "usage: $ME run-filter <value> [<conventions file>]" >&2; exit 64; }
    rf_args() { # <span> -> one argument per line: the tokens after the pytest token, to the first operator
      local w seen=0 all="" aft="" dd=0 sk=0
      rf_toks "$1"
      while IFS= read -r w; do
        [ -n "$w" ] || continue
        # REDIRECTION (header: RUN-FILTER): after the runner, a redirection is skipped with its one target and the read
        # goes on (`pytest -q 1>out.txt -k foo` reads -k); a pipe ends it.
        if [ "$sk" = 1 ]; then sk=0; continue; fi
        # A quoted token (rr_quote writes `'--junitxml=x>y'`) is an argument, never a shell operator; so is a placeholder.
        case "$w" in \'*|\"*) ;; '|'|'||'|'&&'|';'|'>'|'>>'|'2>&1'|'<'|*'>'*) rf_ph "$w" || { [ "$seen" = 1 ] && { rf_redir "$w" || break; continue; }; aft=""; all=""; dd=0; continue; } ;; esac
        if [ "$seen" = 0 ]; then
          case "$w" in pytest|*/pytest|py.test|*/py.test) seen=1; aft=""; continue ;; esac
          # After a bare `--` (`npm test -- <args>`) every non-flag token is an argument handed to the runner.
          if [ "$dd" = 1 ]; then case "$w" in -*) ;; *) w="--passed-path=$w" ;; esac; fi
          [ "$w" = -- ] && dd=1
          all="$all$w"$'\n'
        else aft="$aft$w"$'\n'; fi
      done <<<"$RF_T"
      # No pytest token (`go test ./...`, `npx graph test -r`): only the flag tokens and the
      # test-file arguments are read, so a runner's own package path is never taken for a narrowing
      # argument while a test file named to any runner is.
      if [ "$seen" = 1 ]; then printf '%s' "$aft"
      else printf '%s' "$all" | awk '/^-/ && $0 != "-m" && $0 != "-c" { print; next } { n = $0; sub(/.*\//, "", n) } n ~ /\.(test|spec)\.[A-Za-z0-9]+$|_test\.go$|^test_.*\.py$|_test\.py$/ { print }'; fi
    }
    rf_norm() { local p="${1#./}"; p="${p%/}"; printf '%s' "${p:-.}"; }
    # rf_addopts <-o value> (header: RUN-FILTER, ADDOPTS): `addopts=<args>`, unquoted and read to its first `;` or ` #`
    # (an ini comment), is scanned as arguments; any other ini override is a value and nothing more.
    rf_addopts() {
      local v="$1"
      v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
      case "$v" in addopts=*) ;; *) return 0 ;; esac
      v="${v#addopts=}"; v="${v%%;*}"; v="${v%%[[:space:]]#*}"
      rf_toks "$v"; rf_scan "$RF_T"
    }
    # rf_scan <args> -> "m<TAB><expr>" and "p<TAB><path>" lines, and "x<TAB><reason>" for a refusal
    rf_scan() {
      local a pend="" mq="" mv=""
      while IFS= read -r a; do
        [ -n "$a" ] || continue
        if [ -n "$mq" ]; then mv="$mv $a"; case "$a" in *"$mq") mq=""; mv="${mv#\"}"; mv="${mv#\'}"; mv="${mv%\"}"; mv="${mv%\'}"; printf 'm\t%s\n' "$mv" ;; esac; continue; fi
        if [ -n "$pend" ]; then
          if [ "$pend" = m ]; then
            case "$a" in \"*\"|\'*\') mv="${a:1:${#a}-2}"; printf 'm\t%s\n' "$mv" ;;
                         \"*) mq='"'; mv="${a#\"}" ;; \'*) mq="'"; mv="${a#\'}" ;;
                         *) printf 'm\t%s\n' "$a" ;; esac
          fi
          # ADDOPTS (header: RUN-FILTER): `-o addopts=<args>` is read as those arguments.
          [ "$pend" = o ] && rf_addopts "$a"
          pend=""; continue
        fi
        # One quoted token is read as its unquoted text (`'--junitxml=x>y'` is that option, `'t/x.py'` that file).
        case "$a" in \'?*\'|\"?*\") a="${a:1:${#a}-2}" ;; esac
        case "$a" in
          -k|-k*|--keyword|--keyword=*) printf 'x\t%s\n' "selects tests by name ($a)" ;;
          --deselect|--deselect=*) printf 'x\t%s\n' "deselects tests ($a)" ;;
          -t|--testNamePattern|--testNamePattern=*|-run|-run=*) printf 'x\t%s\n' "selects tests by name ($a)" ;;
          --ignore|--ignore=*|--ignore-glob|--ignore-glob=*) printf 'x\t%s\n' "ignores part of the collection ($a)" ;;
          --lf|--last-failed) printf 'x\t%s\n' "re-runs only the last failures ($a)" ;;
          --passed-path=*) printf 'x\t%s\n' "hands the runner a path after -- (${a#--passed-path=})" ;;
          -x|--exitfirst) printf 'f\tx\n' ;;
          --ff|--failed-first) printf 'f\tff\n' ;;
          -m) pend=m ;;
          -m*) mv="${a#-m}"; mv="${mv#\"}"; mv="${mv#\'}"; mv="${mv%\"}"; mv="${mv%\'}"; printf 'm\t%s\n' "$mv" ;;
          -o|--override-ini) pend=o ;;
          -o*|--override-ini=*) rf_addopts "${a#-o}"; rf_addopts "${a#--override-ini=}" ;;
          -p|-n|-c|-W|-r|--rootdir|--tb|--maxfail|--basetemp|--timeout|--junitxml|--durations|--log-level|--cov|--cov-report|--dist|--numprocesses|--confcutdir) pend=v ;;
          # VALUE OPTIONS (header: RUN-FILTER), continued: the rest of pytest's own and its common plugins'.
          --config-file|--override-ini|--pythonwarnings|--durations-min|--junit-xml|--junit-prefix|--log-format|--log-date-format|--log-cli-level|--log-cli-format|--log-cli-date-format|--log-file|--log-file-level|--log-file-format|--log-file-date-format|--log-auto-indent|--capture|--import-mode|--doctest-glob|--doctest-report|--show-capture|--color|--code-highlight|--assert|--verbosity|--last-failed-no-failures|--lfnf|--pdbcls|--maxprocesses|--tx|--rsyncdir|--cov-config|--cov-fail-under|--cov-context|--timeout-method|--timeout_method|--reruns|--reruns-delay|--only-rerun|--randomly-seed|--asyncio-mode|--ds|--dc) pend=v ;;
          -*) ;;
          *::*|*.py|*.test.*|*.spec.*|*_test.go) printf 'x\t%s\n' "names a file or test node ($a)" ;;
          *) printf 'p\t%s\n' "$(rf_norm "$a")" ;;
        esac
      done <<<"$1"
    }
    rf_conv=""; [ $# -eq 3 ] && [ -r "$3" ] && rf_conv="$3"
    rf_sp="$(rf_span "$2" "$rf_conv")"
    # CHAIN (header: RUN-FILTER): every pytest or DECLARED WRAPPER command of the span is read, each on its own; an
    # "n" line closes one command's scan. A span with neither is read whole, as rf_args reads it.
    RF_RUN=""; rf_n=0
    # rf_wrapper <command> -> the command's PROGRAM (header: RUN-FILTER, UNDECLARED WRAPPER) when it hands arguments
    # after a bare `--` and its program names pytest (`scripts/pytest-footprint-watchdog.py`); else nothing, status 1.
    rf_wrapper() {
      local w p="" dd=0
      rf_toks "$1"
      while IFS= read -r w; do
        [ -n "$w" ] || continue
        if [ -z "$p" ]; then
          case "$w" in [A-Za-z_]*=*|-*) continue ;; esac
          case "${w##*/}" in python*|bash|sh|env|node) continue ;; esac
          p="${w#./}"; continue
        fi
        [ "$w" = -- ] && dd=1
      done <<<"$RF_T"
      [ "$dd" = 1 ] || return 1
      case "${p##*/}" in *pytest*|*py.test*) printf '%s' "$p"; return 0 ;; esac
      return 1
    }
    # rf_loop <span>: every command of its CHAIN that runs pytest or a declared wrapper, scanned into RF_RUN.
    rf_loop() {
      local rf_c rf_rd rf_a rf_w rf_cl
      # Staged, never fed from $( ) straight into the loop: a chain that cannot be split is UNEVALUABLE (exit 2,
      # which run-gate reports as an unevaluable filter), never an empty chain that reads as no narrowing.
      rf_cl="$(rf_cmds "$1")" || { echo "$ME: UNEVALUABLE — the invocation's chain could not be split: $1" >&2; exit 2; }
      while IFS= read -r rf_c; do
        [ -n "$rf_c" ] || continue
        rf_rd=0
        if [ -n "$rf_conv" ]; then
          # DECLARED WRAPPER (header): a declared wrapper's payload is read as the arguments after a `pytest` token.
          rw_wrap "$rf_c" "$rf_conv"; rf_rd=1
          case "$RW" in
            x*) printf '%s\n' "${RW#x$'\t'}"; exit 1 ;;
            ok) rf_a="" ;;
            ok$'\n'*) rf_a="${RW#ok$'\n'}" ;;
            *) rf_rd=0 ;;
          esac
        fi
        if [ "$rf_rd" = 0 ] && rf_cmdpy "$rf_c"; then rf_a="$(rf_args "$rf_c")"; rf_rd=1; fi
        if [ "$rf_rd" = 0 ] && rf_cmdbare "$rf_c"; then rf_a="$(rf_args "$rf_c")"; rf_rd=1; fi
        if [ "$rf_rd" = 0 ] && rf_w="$(rf_wrapper "$rf_c")"; then
          printf 'runs %s, a wrapper the conventions do not declare, handing pytest the arguments after its --; declare it in docs/coding-conventions.md as `<program> <options> -- <pytest args>`\n' "$rf_w"; exit 1
        fi
        [ "$rf_rd" = 1 ] || continue
        rf_n=$((rf_n + 1))
        RF_RUN="$RF_RUN$(rf_scan "$rf_a")"$'\n''n'$'\n'
      done <<<"$rf_cl"
    }
    rf_loop "$rf_sp"
    # QUOTED COMMAND (header: RUN-FILTER): no command runs pytest, and a quoted token whose unquoted text does
    # (`bash -lc "cd backend && pytest -k x"`, `ssh host "..."`) is read as its own span, through the same loop.
    # The inner text is unescaped (`\"` -> `"`) before it is read, and a quoted token inside it that runs no pytest
    # itself is scanned again (`bash -c "ssh h 'pytest -k x'"`), to a depth of three.
    rf_qscan() { # <span> <depth>
      local rf_q rf_t
      rf_toks "$1"; rf_q="$RF_T"
      while IFS= read -r rf_t; do
        case "$rf_t" in
          \"*\"|\'*\')
            rf_t="${rf_t:1:${#rf_t}-2}"; rf_t="${rf_t//\\\"/\"}"; rf_t="${rf_t//\\\'/\'}"
            if rf_spanpy "$rf_t"; then rf_loop "$rf_t"; elif [ "$2" -lt 3 ]; then rf_qscan "$rf_t" $(($2 + 1)); fi ;;
        esac
      done <<<"$rf_q"
    }
    [ "$rf_n" != 0 ] || rf_qscan "$rf_sp" 1
    [ "$rf_n" -gt 0 ] || RF_RUN="$(rf_scan "$(rf_args "$rf_sp")")"$'\n''n'$'\n'
    # `--ff` alone runs every test (failures first); with `-x` it stops at the first failure. Decided per command.
    RF_RUN="$(printf '%s\n' "$RF_RUN" | awk -F'\t' '$1 == "f" { g[$2] = 1; next } $1 == "n" { if (g["x"] && g["ff"]) print "x\tstops at the first of the previous failures (-x with --ff)"; split("", g); next } { print }')"
    RF_X="$(printf '%s\n' "$RF_RUN" | awk -F'\t' '$1 == "x" { print $2; exit }')"
    [ -z "$RF_X" ] || { printf '%s\n' "$RF_X"; exit 1; }
    RF_CONV=0; RF_DECL=""
    if [ $# -eq 3 ] && [ -r "$3" ]; then
      RF_CONV=1
      # Staged, never piped: a pipeline in $( ) answers with its last stage and would hide a failed read.
      rf_spans="$(grep -oE '`[^`]*`' "$3")" || rf_spans=""
      rf_spans="$(grep -E '(^|[[:space:]/`])(pytest|py\.test)([[:space:]`]|$)' <<<"$rf_spans")" || rf_spans=""
      while IFS= read -r sp; do
        sp="${sp#\`}"; sp="${sp%\`}"
        [ -n "$sp" ] || continue
        RF_DECL="$RF_DECL$(rf_scan "$(rf_args "$sp")")"$'\n'
      done <<<"$rf_spans"
    fi
    while IFS="$(printf '\t')" read -r k v; do
      case "$k" in
        m) [ "$RF_CONV" = 0 ] && continue
           printf '%s\n' "$RF_DECL" | awk -F'\t' -v v="$v" '$1 == "m" && $2 == v { f = 1 } END { exit !f }' \
             || { printf 'selects by marker (-m %s), which the conventions do not declare canonical\n' "$v"; exit 1; } ;;
        p) [ "$v" = . ] && continue
           [ "$RF_CONV" = 1 ] && printf '%s\n' "$RF_DECL" | awk -F'\t' -v v="$v" '$1 == "p" && $2 != "." && (v == $2 || substr(v, length(v) - length($2)) == "/" $2 || substr($2, 1, length(v) + 1) == v "/") { f = 1 } END { exit !f }' && continue
           if [ "$RF_CONV" = 1 ]; then printf 'narrows the collection to the path %s, which the conventions do not declare canonical\n' "$v"
           else printf 'narrows the collection to the path %s (no conventions file declares it canonical)\n' "$v"; fi
           exit 1 ;;
      esac
    done <<<"$RF_RUN"
    exit 0
}
# ro_story_rel <repo> <story> prints the story as a path relative to the repository top. A relative
# spelling is only normalised (a leading `./` plus any run of `/`, repeatedly) and refused when it
# is empty or has an empty, `.` or `..` component; an absolute spelling is resolved physically
# (`cd -P`) against the physical top and refused when it lies outside the repository.
ro_story_rel() {
    local rs_repo="$1" rs_p="$2" rs_top rs_dir rs_base
    while :; do
      case "$rs_p" in ./*) rs_p="${rs_p#./}"; rs_p="${rs_p#"${rs_p%%[!/]*}"}" ;; *) break ;; esac
    done
    case "$rs_p" in
      /*)
        rs_base="${rs_p##*/}"
        case "$rs_base" in ''|.|..) echo "$ME: UNEVALUABLE — story path has no file name: $2" >&2; return 2 ;; esac
        rs_top="$(cd -P "$(git -C "$rs_repo" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null && pwd -P)" \
          || { echo "$ME: UNEVALUABLE — repository top does not resolve: $rs_repo" >&2; return 2; }
        rs_dir="$(cd -P "$(dirname "$rs_p")" 2>/dev/null && pwd -P)" \
          || { echo "$ME: UNEVALUABLE — story directory does not resolve: $2" >&2; return 2; }
        case "$rs_dir" in
          "$rs_top") printf '%s\n' "$rs_base" ;;
          "$rs_top"/*) printf '%s\n' "${rs_dir#"$rs_top"/}/$rs_base" ;;
          *) echo "$ME: UNEVALUABLE — story path is outside the repository: $2" >&2; return 2 ;;
        esac ;;
      *)
        case "/$rs_p/" in
          //|*//*|*/./*|*/../*) echo "$ME: UNEVALUABLE — story path is not a plain relative path: $2" >&2; return 2 ;;
        esac
        printf '%s\n' "$rs_p" ;;
    esac
}
# ro_story_never <base>: a story absent at <base> is a gate-1 base only when $sb_rel was never a path at <base> or
# any ancestor of it (BL-904: a story `git rm`'d after its review and re-added later would otherwise read as created
# after the base). --full-history, because default history simplification follows a TREESAME merge parent and
# prunes the side that deleted the story (a merge of a branch that never held it hides the deletion). A shallow
# repository cannot prove an absence (its boundary reads as a root), and a failed walk is UNEVALUABLE, never 0.
# The pathspec is top-anchored and literal (BL-904): $sb_rel is relative to the repository top, and a bare pathspec
# after `--` resolves against the -C directory, so a -C <subdirectory> would walk a path that never existed.
ro_story_never() {
    local sn_sh sn_h
    sn_sh="$(git -C "$REPO" rev-parse --is-shallow-repository 2>/dev/null)" \
      || { echo "$ME: UNEVALUABLE — cannot tell whether $REPO is a shallow repository" >&2; exit 2; }
    [ "$sn_sh" = false ] || { echo "$ME: UNEVALUABLE — $REPO is a shallow repository, so the story's history before $1 is not all present" >&2; exit 2; }
    sn_h="$(git -C "$REPO" rev-list -1 --full-history "$1" -- ":(top,literal)$sb_rel" 2>/dev/null)" \
      || { echo "$ME: UNEVALUABLE — git rev-list over $sb_rel's history before $1 failed in $REPO" >&2; exit 2; }
    [ -z "$sn_h" ] || { printf 'the story %s existed before %s and is absent at it (deleted, then re-added)\n' "$sb_rel" "$1"; exit 1; }
}
ro_story_base() {
    shift
    REPO=.
    if [ "${1:-}" = "-C" ]; then
      [ $# -ge 2 ] || { echo "$ME: UNEVALUABLE — -C needs a directory" >&2; exit 2; }
      REPO="$2"; shift 2
    fi
    { [ $# -eq 2 ] || [ $# -eq 3 ]; } || { echo "usage: $ME story-base [-C <repo>] <story-file> <base> [<frozen>]" >&2; exit 2; }
    git -C "$REPO" rev-parse --verify --quiet "$2^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — base does not resolve: $2" >&2; exit 2; }
    sb_rel="$(ro_story_rel "$REPO" "$1")" || exit 2
    if [ $# -eq 3 ]; then
      sb_ty="$(git -C "$REPO" cat-file -t "$2:$sb_rel" 2>/dev/null)" || sb_ty=""
      case "$sb_ty" in
        blob) ;;
        "") # absent at <base>: a story created after it is a blob at <frozen>; anything else is no story
            [ "$(git -C "$REPO" cat-file -t "$3:$sb_rel" 2>/dev/null)" = blob ] \
              || { echo "$ME: UNEVALUABLE — story is not a file at $2 or $3: $1" >&2; exit 2; }
            ro_story_never "$2"; exit 0 ;;
        *) echo "$ME: UNEVALUABLE — story is not a file at $2: $1" >&2; exit 2 ;;
      esac
    else
      git -C "$REPO" cat-file -e "$2:$sb_rel" 2>/dev/null || { ro_story_never "$2"; exit 0; }
    fi
    sb_t="$(git -C "$REPO" show "$2:$sb_rel" 2>/dev/null)"
    if (ro_label label 'Full-collection run:') <<<"$sb_t" >/dev/null; then
      printf 'the story at %s already carries a Full-collection run: line\n' "$2"; exit 1
    fi
    sb_s="$(printf '%s\n' "$sb_t" | awk 'NR == 1 && /^---/ { fm = 1; next } fm && /^---/ { exit } fm && /^status:/ { sub(/^status:[[:space:]]*/, ""); print $1; exit }')"
    case "$sb_s" in review|done) printf 'the story at %s is already status: %s\n' "$2" "$sb_s"; exit 1 ;; esac
    exit 0
}
# ro_waiver (header: WAIVER). The object type at <ref> is decided as story-base decides it at <base>.
ro_waiver() {
    local wv_rel wv_v wv_rest wv_id wv_tail wv_ty wv_t wv_r
    shift
    REPO=.
    if [ "${1:-}" = "-C" ]; then
      [ $# -ge 2 ] || { echo "usage: $ME waiver [-C <root>] <story> <ref> <value>" >&2; exit 64; }
      REPO="$2"; shift 2
    fi
    [ $# -eq 3 ] || { echo "usage: $ME waiver [-C <root>] <story> <ref> <value>" >&2; exit 64; }
    wv_rel="$(ro_story_rel "$REPO" "$1")" || exit 2
    wv_v="$3"; wv_v="${wv_v#"${wv_v%%[!	 *\`]*}"}"
    case "$wv_v" in "none, "*) ;; *) echo "NOT-WAIVED: not a waiver spelling"; exit 1 ;; esac
    wv_rest="${wv_v#none, }"; wv_id="${wv_rest%% *}"; wv_tail="${wv_rest#"$wv_id"}"
    case "$wv_id" in [A-Za-z]*) ;; *) echo "NOT-WAIVED: not a waiver spelling"; exit 1 ;; esac
    case "$wv_id" in *[!A-Za-z0-9._-]*) echo "NOT-WAIVED: not a waiver spelling"; exit 1 ;; esac
    case "$wv_tail" in " waives it"|" waives it; "*) ;; *) echo "NOT-WAIVED: not a waiver spelling"; exit 1 ;; esac
    git -C "$REPO" rev-parse --verify --quiet "$2^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — ref does not resolve: $2" >&2; exit 2; }
    wv_ty="$(git -C "$REPO" cat-file -t "$2:$wv_rel" 2>/dev/null)" || wv_ty=""
    case "$wv_ty" in
      blob) ;;
      "") echo "NOT-WAIVED: story absent at $2"; exit 1 ;;
      *) echo "$ME: UNEVALUABLE — story is not a file at $2: $1 ($wv_ty)" >&2; exit 2 ;;
    esac
    wv_t="$(git -C "$REPO" cat-file blob "$2:$wv_rel" 2>/dev/null)" \
      || { echo "$ME: UNEVALUABLE — git cat-file of $wv_rel at $2 failed in $REPO" >&2; exit 2; }
    # Prints h=<heading count> e=<1 when the entry sits under the one heading>.
    wv_r="$(RO_P="- **$wv_id** waives the canonical run" awk '
      BEGIN { P = ENVIRON["RO_P"] }
      { sub(/\r$/, "") }
      /^[ \t]*(```|~~~)/ { f = !f; next }
      f { next }
      /^##[ \t]+Canonical-run waivers[ \t]*$/ { h++; ins = 1; next }
      /^## / { ins = 0; next }
      ins && index($0, P) == 1 { e = 1 }
      END { printf "h=%d e=%d", h, e }' <<<"$wv_t")" \
      || { echo "$ME: UNEVALUABLE — the story at $2 could not be read" >&2; exit 2; }
    case "$wv_r" in
      h=0\ *) echo "NOT-WAIVED: no ## Canonical-run waivers section in $wv_rel at $2"; exit 1 ;;
      h=1\ e=1) printf 'WAIVED: %s\n' "$wv_id"; exit 0 ;;
      h=1\ *) echo "NOT-WAIVED: no '- **$wv_id** waives the canonical run' entry under ## Canonical-run waivers in $wv_rel at $2"; exit 1 ;;
      *) wv_r="${wv_r#h=}"; echo "NOT-WAIVED: ${wv_r%% *} ## Canonical-run waivers headings in $wv_rel at $2, want exactly one"; exit 1 ;;
    esac
}
ro_shape() {
    [ $# -eq 2 ] || { [ "$1" = run-shape ] && [ $# -eq 3 ]; } || { echo "usage: $ME run-shape <value> [<conventions file>] | $ME setup-shape <value>" >&2; exit 64; }
    # The no-run reading is decided FIRST: a value opening with a none form or a pointer word is
    # never a run, whatever spans or counts follow it.
    (ro_none_reason none-reason "$2") >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
    rs_v="$2"; rs_v="${rs_v#"${rs_v%%[!	 *\`]*}"}"
    rs_lc="$(printf '%s' "$rs_v" | tr '[:upper:]' '[:lower:]')"
    grep -qE '^(see|refer|n/a|na|tbd|todo|deferred|pending)([^a-z0-9]|$)' <<<"$rs_lc" && exit 1
    rs_sp="$(grep -oE '`[^`]*`' <<<"$2")" || rs_sp=""
    if [ "$1" = setup-shape ]; then
      grep -qE '^`[^`]*[^`[:space:]][[:space:]]+[^`[:space:]][^`]*`$' <<<"$rs_sp" && exit 0
      grep -qE '(^|[[:space:]])\$ [^[:space:]]' <<<"$2" && exit 0
      grep -qE '/bin/python|venv' <<<"$rs_sp" \
        && grep -qE '[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]+[0-9]+\.[0-9]|[[:space:]]installed([^A-Za-z]|$)|\([A-Za-z][A-Za-z0-9_.-]*\)|[[:space:]]with[[:space:]]+[A-Za-z][A-Za-z0-9_.-]*' <<<"$2" && exit 0
      exit 1
    fi
    rs_rn='pytest|py\.test|vitest|jest|npx|go test|cargo test|make test|bun test|npm (run )?test|(bash|sh) [^[:space:]`]*test[^[:space:]`/]*\.sh'
    if [ $# -eq 3 ] && [ -r "$3" ]; then
      rs_cv="$(grep -iE 'canonical' "$3")" || rs_cv=""
      rs_cv="$(grep -oE '`[^`[:space:]]+[[:space:]][^`]*`' <<<"$rs_cv")" || rs_cv=""
      while IFS= read -r rs_c; do
        rs_c="${rs_c#\`}"; rs_c="${rs_c%% *}"; rs_c="${rs_c##*/}"
        # A runner is a named program: not a flag, and not an interpreter or shell that runs anything.
        case "$rs_c" in ''|[!A-Za-z]*|*[!A-Za-z0-9._-]*|python*|bash|sh|zsh|env|cd|node|git) continue ;; esac
        rs_rn="$rs_rn|$(printf '%s' "$rs_c" | sed 's/\./\\./g')"
      done <<<"$rs_cv"
    fi
    # NO-TEST-RUN (header): a collect-only invocation is no run, whatever runner or count the value carries.
    # The span is read once, for NO-TEST-RUN and the wrapper arm alike: rf_span answers a repeat of this value from
    # RF_SPAN_S without starting a process.
    unset RF_SPAN_V; RF_SPAN_S="$(rf_span "$2" "${3:-}")"; RF_SPAN_V="$2"
    ro_no_test "$2" && exit 1
    # DECLARED WRAPPER (header): widen only. A declared wrapper run within its declaration is a run; any other value,
    # a declared wrapper outside its declaration included, falls through to the arms below unchanged.
    if [ $# -eq 3 ] && [ -r "$3" ] && rw_any "$3"; then
      rw_wrap "$RF_SPAN_S" "$3"
      case "$RW" in ok|ok$'\n'*) exit 0 ;; esac
    fi
    grep -qE "(^|[[:space:]/\`])($rs_rn)([[:space:]\`]|\$)" <<<"$rs_sp" && exit 0
    grep -qE "(^|[[:space:]])\\$ ([^[:space:]]*/)?($rs_rn|python[0-9.]* -m pytest)([[:space:]]|\$)" <<<"$2" && exit 0
    grep -qE "^([^[:space:]]*/)?($rs_rn|python[0-9.]* -m pytest)([[:space:]]|\$)" <<<"$rs_v" && exit 0
    grep -qE '[0-9]+[[:space:]]+(passed|failed)([^A-Za-z]|$)' <<<"$2"
    exit $?
}
ro_none_reason() {
    [ $# -eq 2 ] || { echo "usage: $ME none-reason <value>" >&2; exit 64; }
    v="$2"
    v="${v#"${v%%[!	 *\`]*}"}"
    lc="$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')"
    rest=""
    for w in "not executed" "not run" "none"; do
      case "$lc" in
        "$w") rest=""; exit 1 ;;
        "$w"[!A-Za-z0-9]*) rest="${v:${#w}}"; break ;;
      esac
    done
    [ -n "$rest" ] || exit 2
    case "$rest" in *[A-Za-z0-9]*) exit 0 ;; esac
    exit 1
}
ro_paths() {
    shift
    REPO=.
    if [ "${1:-}" = "-C" ]; then
      [ $# -ge 2 ] || { echo "$ME: UNEVALUABLE — -C needs a directory" >&2; exit 2; }
      REPO="$2"; shift 2
    fi
    [ $# -eq 3 ] || { echo "usage: $ME paths [-C <repo>] <story-file> <base> <frozen>" >&2; exit 2; }
    story="$(ro_story_rel "$REPO" "$1")" || exit 2
    git -C "$REPO" rev-parse --verify --quiet "$2^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — base does not resolve: $2" >&2; exit 2; }
    git -C "$REPO" rev-parse --verify --quiet "$3^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — frozen does not resolve: $3" >&2; exit 2; }
    # --raw, one row per path: `:<old mode> <new mode> <old> <new> <status>` TAB <path>. The new mode is read so a
    # record-class entry committed as a symlink (120000) or a gitlink (160000) is not a record: a `docs/reviews/s1`
    # link to `s2` moves where the merge's partition lands, and nothing under it is a file the partition can class.
    changed="$(git -C "$REPO" diff --raw --no-renames "$2" "$3" 2>/dev/null)" \
      || { echo "$ME: UNEVALUABLE — git diff $2 $3 failed in $REPO" >&2; exit 2; }
    n=0; first=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      rp_m="${p%%$'\t'*}"; p="${p#*$'\t'}"; rp_m="${rp_m#:* }"; rp_m="${rp_m%% *}"
      n=$((n + 1))
      [ -z "$first" ] || continue
      case "$p" in
        "$story") ;;
        _bmad-output/implementation-artifacts/sprint-status.yaml|_bmad-output/planning-artifacts/sprint-status.yaml) ;;
        docs/reviews/*|test-results/*|docs/escalations/*)
          case "$rp_m" in 120000|160000) first="$p (mode $rp_m, a symlink or gitlink, not a record file)"; continue ;; esac
          case "${p##*/}" in
            *.py|*.sh|*.toml|*.cfg|conftest.py|pytest.ini) first="$p" ;;
          esac ;;
        *) first="$p" ;;
      esac
    done <<<"$changed"
    if [ -n "$first" ]; then
      printf 'NOT-RECORD-ONLY: %s changed path(s), first non-record path %s\n' "$n" "$first"
      exit 1
    fi
    printf 'RECORD-ONLY: %s changed path(s)\n' "$n"
    exit 0
}
# ro_run_gate <value> [<conventions file>] (header: RUN-GATE): each rule runs in a subshell of this one start,
# because each ends in `exit`.
ro_run_gate() {
    [ $# -eq 1 ] || [ $# -eq 2 ] || { echo "usage: $ME run-gate <value> [<conventions file>]" >&2; exit 64; }
    local rg_s rg_o rg_f rg_n=0
    ( ro_shape run-shape "$@" ) >/dev/null 2>&1; rg_s=$?
    case "$rg_s" in
      0) ;;
      1) rg_n=4
         # NO-TEST-RUN on the span RUN-FILTER reads: the span memo set to the choice made with the conventions file.
         unset RF_SPAN_V
         if [ $# -eq 2 ]; then RF_SPAN_S="$(rf_span "$1" "$2")"; RF_SPAN_V="$1"; fi
         ro_no_test "$1" && exit 1 ;;
      *) echo "run-shape exit $rg_s"; exit 2 ;;
    esac
    rg_o="$(ro_run_filter run-filter "$@" 2>&1)"; rg_f=$?
    case "$rg_f" in
      0) exit "$rg_n" ;;
      1) printf '%s\n' "$rg_o"; [ "$rg_n" = 0 ] && exit 3; exit 5 ;;
      *) printf 'run-filter exit %s: %s\n' "$rg_f" "$rg_o"; [ "$rg_n" = 0 ] && exit 2; exit 6 ;;
    esac
}
ro_main() {
set -u
# The span memo is this process's own (ro_shape writes it), never an inherited value.
unset RF_SPAN_V RF_SPAN_S
export LC_ALL=C
# Every git call below reads the history as committed: a replace ref or a graft rewrites what a base holds.
local -x GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts
ME=record-only-diff

case "${1:-}" in
  label)
    ro_label "$@"
    ;;
  run-filter)
    ro_run_filter "$@"
    ;;
  run-span)
    [ $# -eq 2 ] || { echo "usage: $ME run-span <value>" >&2; exit 64; }
    rf_span "$2"; echo
    ;;
  story-base)
    ro_story_base "$@"
    ;;
  waiver)
    ro_waiver "$@"
    ;;
  run-gate)
    shift; ro_run_gate "$@"
    ;;
  no-test-run)
    [ $# -eq 2 ] || [ $# -eq 3 ] || { echo "usage: $ME no-test-run <value> [<conventions file>]" >&2; exit 64; }
    # With a conventions file the span is chosen as run-shape and run-filter choose it (header: NO-TEST-RUN): the span
    # memo rf_span answers ro_no_test from is set to that choice. Without one, ro_no_test chooses it unaided.
    [ $# -ne 3 ] || { RF_SPAN_S="$(rf_span "$2" "$3")"; RF_SPAN_V="$2"; }
    ro_no_test "$2"
    ;;
  run-shape|setup-shape)
    ro_shape "$@"
    ;;
  none-reason)
    ro_none_reason "$@"
    ;;
  paths)
    ro_paths "$@"
    ;;
  *)
    echo "usage: $ME paths [-C <repo>] <story-file> <base> <frozen> | $ME none-reason <value>" >&2
    exit 64
    ;;
esac
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
ro_main "$@"
