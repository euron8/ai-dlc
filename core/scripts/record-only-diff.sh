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
#   record-only-diff.sh story-base [-C <repo>] <story-file> <base>
#
# RUN-FILTER. Exit 0 when the invocation in <value> is the unfiltered canonical collection, 1 with
# the reason on stdout when it narrows it. The invocation is the first backticked span naming
# `pytest` (else the first backticked span, else the text after a `$ ` prompt, else the value),
# read up to the first shell operator after the runner; the arguments are the tokens after the
# `pytest` token (`python -m pytest` included), or every token when no `pytest` token is present.
# Refused in every spelling: `-k` (`-k x`, `-kx`, `-k"x"`, `--keyword`, `--keyword=x`), `--deselect`,
# `-t`, `--testNamePattern`, `-run`, `--ignore`/`--ignore-glob`, `--lf`/`--last-failed`, and `-x`
# (`--exitfirst`) with `--ff` (`--failed-first`); `--ff` alone reorders and still runs every test,
# and is accepted, as is `-x` alone. An explicit file
# (`*.py`) or node id (`::`) argument; and, for ANY runner, a path argument ending in a test-file
# suffix (`*.test.*`, `*.spec.*`, `*_test.go`, `test_*.py`, `*_test.py`) or any argument after a
# bare `--` (`npm test -- <path>`). A `-m <marker>` (or `-m<marker>`)
# and a path argument are accepted only when the consumer's own conventions declare them canonical:
# <conventions file> (the project's `docs/coding-conventions.md`, read by the caller) names a
# backticked `pytest` invocation carrying the same marker expression, or the same path (compared
# after `./` and a trailing `/` are dropped; an absolute argument matches by its trailing
# components), or a path that CONTAINS a declared one (`rebalancer` against a declared
# `rebalancer/tests` collects a superset, which is not narrowing). With <conventions file> absent or unreadable, `-m <marker>` is accepted and every
# path argument other than `.` is refused. Reference consumer: its conventions declare
# `pytest rebalancer/tests` and `<venv>/bin/python -m pytest -m unit`, and its QA records run both.
#
# STORY-BASE. The serial seat supplies its own --range, so the exemption's base is held to the
# shape a gate-1 base has: exit 0 when <story-file> at <base> is absent, or carries no column-0
# `Full-collection run:` label and a frontmatter `status:` other than `review` and `done` (the dev
# has not handed off yet). Exit 1 with the reason on stdout otherwise: <base> is a later sha (a
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
# <conventions file> line naming `canonical`), or a count `<n> passed|failed` (dev.md: "the
# invocation and counts"). Exit 1 otherwise: a two-word span naming no runner (`make docs`) and a
# `0 tests collected` are not runs.
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
# An empty diff (base == frozen) is record-only: nothing the canonical collection reads moved.
#
# THE PARTITION. A path is a record path when it is exactly one of:
#   - the <story-file> argument itself (identity, after a leading `./` is dropped);
#   - `_bmad-output/implementation-artifacts/sprint-status.yaml` or
#     `_bmad-output/planning-artifacts/sprint-status.yaml` (sprint-status.sh's two VIEWS);
#   - anything under `docs/reviews/`, `test-results/` or `docs/escalations/`, EXCEPT a file a
#     collection or a runner can load: a `*.py`, `*.sh`, `*.toml` or `*.cfg`, a `conftest.py` or a
#     `pytest.ini` under those directories is NOT a record path (`test-results/test_evil.py` is
#     collected by a bare `pytest` from the root). The reference consumer tracks 15 such files there.
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
set -u
export LC_ALL=C
ME=record-only-diff

case "${1:-}" in
  label)
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
    ;;
  run-filter)
    [ $# -eq 2 ] || [ $# -eq 3 ] || { echo "usage: $ME run-filter <value> [<conventions file>]" >&2; exit 64; }
    rf_span() { # <text> -> the invocation span
      local t="$1" s
      local sp=""
      sp="$(grep -oE '`[^`]*`' <<<"$t")" || sp=""
      s="$(awk '/(^|[[:space:]\/`])(pytest|py\.test)([[:space:]`]|$)/ { print; exit }' <<<"$sp")"
      [ -n "$s" ] || s="$(awk 'NF { print; exit }' <<<"$sp")"
      if [ -z "$s" ]; then
        case "$t" in *'$ '*) s="${t#*\$ }" ;; *) s="$t" ;; esac
      fi
      s="${s#\`}"; printf '%s' "${s%\`}"
    }
    rf_args() { # <span> -> one argument per line: the tokens after the pytest token, to the first operator
      local w seen=0 all="" aft="" dd=0
      set -f
      # shellcheck disable=SC2086
      set -- $1
      set +f
      for w in "$@"; do
        case "$w" in '|'|'||'|'&&'|';'|'>'|'>>'|'2>&1'|'<'|*'>'*) [ "$seen" = 1 ] && break; aft=""; all=""; dd=0; continue ;; esac
        if [ "$seen" = 0 ]; then
          case "$w" in pytest|*/pytest|py.test|*/py.test) seen=1; aft=""; continue ;; esac
          # After a bare `--` (`npm test -- <args>`) every non-flag token is an argument handed to the runner.
          if [ "$dd" = 1 ]; then case "$w" in -*) ;; *) w="--passed-path=$w" ;; esac; fi
          [ "$w" = -- ] && dd=1
          all="$all$w"$'\n'
        else aft="$aft$w"$'\n'; fi
      done
      # No pytest token (`go test ./...`, `npx graph test -r`): only the flag tokens and the
      # test-file arguments are read, so a runner's own package path is never taken for a narrowing
      # argument while a test file named to any runner is.
      if [ "$seen" = 1 ]; then printf '%s' "$aft"
      else printf '%s' "$all" | awk '/^-/ && $0 != "-m" && $0 != "-c" { print; next } { n = $0; sub(/.*\//, "", n) } n ~ /\.(test|spec)\.[A-Za-z0-9]+$|_test\.go$|^test_.*\.py$|_test\.py$/ { print }'; fi
    }
    rf_norm() { local p="${1#./}"; p="${p%/}"; printf '%s' "${p:-.}"; }
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
          pend=""; continue
        fi
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
          -p|-n|-c|-o|-W|-r|--rootdir|--tb|--maxfail|--basetemp|--timeout|--junitxml|--durations|--log-level|--cov|--cov-report|--dist|--numprocesses|--confcutdir) pend=v ;;
          -*) ;;
          *::*|*.py|*.test.*|*.spec.*|*_test.go) printf 'x\t%s\n' "names a file or test node ($a)" ;;
          *) printf 'p\t%s\n' "$(rf_norm "$a")" ;;
        esac
      done <<<"$1"
    }
    RF_RUN="$(rf_scan "$(rf_args "$(rf_span "$2")")")"
    # `--ff` alone runs every test (failures first); with `-x` it stops at the first failure.
    RF_RUN="$(printf '%s\n' "$RF_RUN" | awk -F'\t' '$1 == "f" { g[$2] = 1; next } { print } END { if (g["x"] && g["ff"]) print "x\tstops at the first of the previous failures (-x with --ff)" }')"
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
    ;;
  story-base)
    shift
    REPO=.
    if [ "${1:-}" = "-C" ]; then
      [ $# -ge 2 ] || { echo "$ME: UNEVALUABLE — -C needs a directory" >&2; exit 2; }
      REPO="$2"; shift 2
    fi
    [ $# -eq 2 ] || { echo "usage: $ME story-base [-C <repo>] <story-file> <base>" >&2; exit 2; }
    git -C "$REPO" rev-parse --verify --quiet "$2^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — base does not resolve: $2" >&2; exit 2; }
    git -C "$REPO" cat-file -e "$2:${1#./}" 2>/dev/null || exit 0
    sb_t="$(git -C "$REPO" show "$2:${1#./}" 2>/dev/null)"
    if bash "$0" label 'Full-collection run:' <<<"$sb_t" >/dev/null; then
      printf 'the story at %s already carries a Full-collection run: line\n' "$2"; exit 1
    fi
    sb_s="$(printf '%s\n' "$sb_t" | awk 'NR == 1 && /^---/ { fm = 1; next } fm && /^---/ { exit } fm && /^status:/ { sub(/^status:[[:space:]]*/, ""); print $1; exit }')"
    case "$sb_s" in review|done) printf 'the story at %s is already status: %s\n' "$2" "$sb_s"; exit 1 ;; esac
    exit 0
    ;;
  run-shape|setup-shape)
    [ $# -eq 2 ] || { [ "$1" = run-shape ] && [ $# -eq 3 ]; } || { echo "usage: $ME run-shape <value> [<conventions file>] | $ME setup-shape <value>" >&2; exit 64; }
    # The no-run reading is decided FIRST: a value opening with a none form or a pointer word is
    # never a run, whatever spans or counts follow it.
    bash "$0" none-reason "$2" >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
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
    grep -qE "(^|[[:space:]/\`])($rs_rn)([[:space:]\`]|\$)" <<<"$rs_sp" && exit 0
    grep -qE "(^|[[:space:]])\\$ ([^[:space:]]*/)?($rs_rn|python[0-9.]* -m pytest)([[:space:]]|\$)" <<<"$2" && exit 0
    grep -qE "^([^[:space:]]*/)?($rs_rn|python[0-9.]* -m pytest)([[:space:]]|\$)" <<<"$rs_v" && exit 0
    grep -qE '[0-9]+[[:space:]]+(passed|failed)([^A-Za-z]|$)' <<<"$2"
    exit $?
    ;;
  none-reason)
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
    ;;
  paths)
    shift
    REPO=.
    if [ "${1:-}" = "-C" ]; then
      [ $# -ge 2 ] || { echo "$ME: UNEVALUABLE — -C needs a directory" >&2; exit 2; }
      REPO="$2"; shift 2
    fi
    [ $# -eq 3 ] || { echo "usage: $ME paths [-C <repo>] <story-file> <base> <frozen>" >&2; exit 2; }
    story="${1#./}"
    git -C "$REPO" rev-parse --verify --quiet "$2^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — base does not resolve: $2" >&2; exit 2; }
    git -C "$REPO" rev-parse --verify --quiet "$3^{commit}" >/dev/null 2>&1 \
      || { echo "$ME: UNEVALUABLE — frozen does not resolve: $3" >&2; exit 2; }
    changed="$(git -C "$REPO" diff --name-only --no-renames "$2" "$3" 2>/dev/null)" \
      || { echo "$ME: UNEVALUABLE — git diff $2 $3 failed in $REPO" >&2; exit 2; }
    n=0; first=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      n=$((n + 1))
      [ -z "$first" ] || continue
      case "$p" in
        "$story") ;;
        _bmad-output/implementation-artifacts/sprint-status.yaml|_bmad-output/planning-artifacts/sprint-status.yaml) ;;
        docs/reviews/*|test-results/*|docs/escalations/*)
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
    ;;
  *)
    echo "usage: $ME paths [-C <repo>] <story-file> <base> <frozen> | $ME none-reason <value>" >&2
    exit 64
    ;;
esac
