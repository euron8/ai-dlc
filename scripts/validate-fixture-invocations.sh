#!/usr/bin/env bash
# validate-fixture-invocations.sh -- the invocation budget: a fixture runs its subject exactly as
# often as its own invocations.decl says, counted from the bash starts of one real run.
#
# usage:  validate-fixture-invocations.sh --fixture <name> --decl <invocations.decl> --log <start log> --root <sandbox root>
#           judge one fixture's counted run (exit 0 pass, 1 FAIL, 2 BROKEN). Called by core/scripts/hermetic-run.sh
#           inside its sandbox span when FXCOUNT_RC, FXCOUNT_DIR and FXCOUNT_JUDGE are all set.
#         validate-fixture-invocations.sh --self-probe
#           the self-probe alone, printing every cell (exit 0 / 2).
#         validate-fixture-invocations.sh --gen-rc <dir>
#           write the counter rc file into <dir> and print its path. The .githooks/pre-push hook calls this into its
#           private run dir; the rc is never tracked.
#
# THE SELF-PROBE RUNS ONCE PER PUSH, as part of arming in .githooks/pre-push: a red self-probe FAILs arming, and so
# the push, before the suite starts, so no fixture is judged by a judge that cannot fire. Per-fixture judging calls do
# not repeat it (about 0.8 CPU-s each, across every declared fixture, would be the very regrowth this budget refuses).
# It also runs standalone, and core/fixtures/fixture-invocation-budget drives it. Every arm is probed in both directions, and three end-to-end legs drive the
# REAL rc this script generates: a known script under `env -i` with the BASH_ENV/FXCOUNT_LOG passthrough logs its
# known number of starts, and without the passthrough (both variables exported in the invoker) logs none; under
# xtrace the script's stderr is byte-identical with the counter on and off, while the counter-on run logged rows;
# and a seeded loop sourcing the real core/fixtures/lib/mutant.sh reports its names for J5. Every child bash the
# self-probe starts runs under `env -i`, so a self-probe running inside a counted fixture writes nothing into that
# fixture's log and answers the same counted or not.
#
# THE COUNTER. BASH_ENV names an rc whose self-removing DEBUG trap appends one row
# `<BASH_SOURCE[0] or -c>\t<pid>\t<FXCELL>\t<FXCOUNT_PARENT>` to $FXCOUNT_LOG at the first command of every bash start
# (the `.lim.*` marker's target carries the same four fields). A RELATIVE BASH_SOURCE is logged as `$PWD/<path>`, the
# start's own working directory prefixed by string work alone (an assignment and a `case`, no fork), so a start
# spelled relative to a directory a fixture `cd`'d into -- `( cd core && bash scripts/S.sh )`, `( cd core/scripts &&
# bash ./S.sh )` -- reaches fxc_count's `.`/`..` normalisation as an absolute path and suffix-matches its declared row;
# logged as spelled it matched nothing (C1 and J3 blind). `-c` and an empty path (`bash -s`, `bash < f`) are kept as
# they are. KNOWN ROUTE: a slash-less name bash finds on PATH rather than in the cwd is logged under the cwd, which is
# not where it lives. The trap then exports FXCOUNT_PARENT=$$ and unsets FXCELL, so a
# child logs this start's pid as its parent and an empty tag unless its own command line sets one: nested, inside `$( )`, and `bash -c` included. The
# whole trap is wrapped in `{ } 2>/dev/null`, so xtrace output is unchanged and an unwritable log writes nothing.
# A START UNDER A FILE-SIZE LIMIT (`ulimit -f 0`) MUST BEHAVE AS IT WOULD UNCOUNTED, and it is still counted. The plain
# append there raises SIGXFSZ, which under the default disposition KILLED the bash before its first command (rc 153,
# the subject never ran), and under `trap '' XFSZ` failed and left the row in the printf buffer, flushed onto the
# subject's own stdout by its next builtin print. Measured on postcompact-rulebook-recovery's s_killed arm: the killed
# gate write never happened, so its M9-inplace and M-unlink flips vanished armed only. So the trap ignores XFSZ for the
# append, drops the stale buffer with an `echo` to /dev/null, and on a refused append to a WRITABLE log (the size-limit
# case; an empty, missing or read-only log still writes nothing) records the start as a SYMLINK `<log>.lim.<random>`
# whose target is the row: a symlink is not a regular-file write and no file-size limit binds it. KNOWN ROUTE, unreached
# on every declared fixture measured: under `ulimit -f N`, N > 0, an append straddling the limit lands partially, then
# fails, so the start leaves a partial row AND a marker -- one start counted twice if no later append follows, or the
# next row's path garbled if one does. Measured 0 markers on all 9 declared fixtures that set `ulimit -f`.
# It then restores the default XFSZ action (a disposition ignored on entry stays ignored; bash cannot reset it). The
# judge reads the log plus one row per marker. The markers are not truncated by hermetic-run.sh with the log, so a
# start log is judged once per FXCOUNT_DIR: the hook makes a fresh `mktemp -d` run dir per push. Still unseen there: a
# mutant_killed name appended to `<log>.mutants` under the limit is lost (J5 sees fewer names, never a false FAIL).
#
# THE DECLARATION: core/fixtures/<f>/invocations.decl. `#` comments and blank lines ignored. Rows:
#   <count> *              every bash start of the run, run.sh included. REQUIRED, exactly one.
#   <count> <path>         <path> is a `!` (REQUIRED) line of the fixture's inputs.decl naming a file; a start counts
#                          when its logged path EQUALS <path> or ENDS in `/<path>` -- so a mutant copy ending in the
#                          same suffix counts too, by design, and `core/xsub.sh` never counts for `sub.sh`.
#                          The logged path is NORMALISED first (fxc_count): `.` and empty segments dropped, `..` removing
#                          the segment before it, so `<sb>/core/fixtures/X/../../scripts/S.sh` counts for `core/scripts/S.sh`,
#                          `a/./b` and `a//b` count as `a/b`, and a name containing `..` (`x..`, `..b`) is never a `..`.
#                          TEXTUAL RESOLUTION IS THE PHYSICAL ONE INSIDE THE SANDBOX, so no filesystem call is made: the
#                          root hermetic-run.sh hands the fixture is `pwd -P` (HR_SB), symlink-free, and the fixture's
#                          own directory is a real `cp -Rp` copy, never a link, while hr_no_symlinks refuses any declared
#                          path carrying one -- so no `..` in a sandbox path climbs out of a symlink. KNOWN ROUTE: a
#                          path OUTSIDE the sandbox root, or a link a fixture makes at run time, can differ (`/var/..` is
#                          `/` textually, `/private` physically); a declared subject is started from the sandbox. `//` COLLAPSES
#                          because the kernel resolves `a//b` as `a/b`: the same file, so an uncollapsed `//` would be one
#                          start of the subject left uncounted. Measured, collapsing moved no declared row
#                          beyond what `..` alone moved: on 3007 `//` rows in 101 leftover push start-log dirs of earlier
#                          trees (e.g. `core/fixtures/beta//run.sh`, a probe path a fixture seeds), and on two counted runs
#                          of 29 fixtures at this change, whose 3256 rows carry no `//` at all.
#   <c>+<k>x<glob> *       measured must equal c + k * (number of paths matching <glob> under the sandbox root), for a
#                          fixture whose start count is a function of a corpus. Allowed on a <path> row too. <glob> is
#                          root-relative, has no `..` and no blank, and is expanded by bash 3.2 pathname expansion:
#                          `*` never crosses a `/` (there is no globstar), so a nested corpus spells one glob per level.
#                          Every row is exact. There is no tolerance form: a count carrying `±`, with or without a `why=`
#                          clause, is a malformed row and FAILs J4. A count that follows load is a fixture defect (BL-868).
# THE ARMS.
#   J1  the start log absent or empty -> BROKEN. run.sh is itself a start, so a counted run logs at least one row; an
#       empty log means the counter never loaded and nothing below would be a measurement.
#   J2  no invocations.decl -> FAIL, printing the measured rows as the declaration to write.
#   J3  measured != declared on any row -> FAIL, naming fixture, row, measured, declared and the remedy.
#   J4  grammar: a malformed row (a `±` count included), a duplicate path, no `*` row or two, a path row naming no `!` line -> FAIL.
#   J5  every mutant name core/fixtures/lib/mutant.sh's mutant_killed appended to <log>.mutants must carry a
#       `# MUTANT-MATRIX <name> ...` or `# MUTANT-MATRIX-FULL <name> ...` row in the fixture's run.sh (a shard stub
#       `exec bash "$IMPL" --group ...` is joined against its IMPL's run.sh). A name with no row, or with a
#       `# MUTANT-MATRIX-CONTROL <name>` row, FAILs. The join sees only kills scored through mutant_killed: a battery
#       on scripts/mutant-kills-allowlist.txt emits its kills its own way and is covered by the static join alone.
#       EXEMPT: a fixture (a shard stub resolved to its IMPL) that is a row of scripts/fixture-matrix-allowlist.txt,
#       validate-fixture-hygiene.sh's derived down-only H5 allowlist of batteries with no block yet, is not joined;
#       J5 prints `J5 EXEMPT, not judged` for it, never the ok line alone. An absent allowlist exempts nothing.
#   J6  a `!` (REQUIRED) file line of inputs.decl naming a BASH SUBJECT with no invocations.decl row -> FAIL, printing
#       the row to add with this run's measured count; `0 <path>` satisfies it. The population is decided from the file
#       (fxc_subject_kind): a `.sh` name, or a first line that is a `sh`/`bash` shebang, direct or through `env`. Data
#       files and non-shell scripts are outside it, counted and printed on the `J6:` line of every judged fixture,
#       never dropped silently. J2's printed declaration carries a `0` row for each unstarted bash subject.
#       `.undeclarable` fixtures never reach the judge; --b2-census walks the tree statically, printing
#       `EXEMPT (undeclarable) <fixture>` for each and `B2 GAP <fixture> <path>` for each J6 finding.
#
#   C1  (BL-879, THE IN-PROCESS CELLS; grammar above fxc_cells_parse) every start of a subject -- a path row of
#       invocations.decl, matched under its DECLARED path with the fxc_count normalisation -- carries an FXCELL tag or
#       is covered by a `nested` row naming its logged parent's subject -> else FAIL. A missing cells.decl is an empty
#       one, and the message says so. NOT this arm's subject, listed: renamed or relocated mutant copies, which do not
#       suffix-match the declared path -- ledger-reverify's mut-memo-*/ledger-reverify.sh (verbatim subject beside a
#       mutated lib.sh), artifact-derivations' s-m-* renamed mutants, and the sib.* stubs. They are BL-878 item 3's
#       uncounted route. A mutant copy that DOES end in the declared suffix (wait-beat-liveness'
#       mutants/merge-adversarial-shards.sh) is a start of the subject and is judged.
#   C2  every tag names a declared cli/e2e cell OF THAT SUBJECT (a tag on a start that is no subject, a `bash -c`
#       wrapper, FAILs too). The grammar half of C2 and C4 is fxc_cells_parse, run statically by
#       scripts/validate-fixture-inprocess.sh; the judge reads the same parse.
#   C3  each declared cli/e2e cell tags exactly one start of its subject.
#   C stale  a fixture listed in scripts/fixture-inprocess-allowlist.txt that passes C1-C3, has a clean parse and
#       whose every cli subject is guarded (C5) FAILs as stale; one still failing prints `C EXEMPT, not judged`.
#   THE EMISSION FIELDS ARE READ ONLY HERE: every other reader of the start log -- fxc_count, the `*` row's `NR`, the
#   J2 printout, the `.lim.*` merge -- reads field 1 or the row count, so the two extra fields move no J verdict.
#   A start spelled relative to a directory the fixture `cd`'d into is judged like any other: the rc logs it under
#   its own `$PWD` (THE COUNTER), so it is no blind route.
#   C BLIND ROUTES (stated, not prevented): `env -i` drops FXCELL with the counter itself (B3); a fixture's own
#   BASH_ENV (B4) replaces the trap that unsets FXCELL; a subject that sets FXCELL itself tags its own children; a
#   `bash -c` wrapper takes the tag, which leaves the subject under it untagged, so C1 fires on it; a pid reused
#   within one run resolves to the LATEST row with that pid, so a child logged after a reuse but parented by the
#   earlier start is misattributed (no fixture measured reaches it); a parent that logged nothing (under its own
#   `env -i`) leaves its child parentless.
#
# usage, also:  validate-fixture-invocations.sh --b2-census [--root R]
#           the static J6 walk over R/core/fixtures/*/ (default: this script's tree), after the self-probe:
#           exit 0 no gap, 1 a gap, 2 refused (red self-probe, or no run.sh).
#
# usage, also:  validate-fixture-invocations.sh --impl-of <run.sh>...   the one shard-stub resolver (see fxc_impl_of).
#
# BLIND ROUTES -- starts this counter does not see, each stated with how it is bounded:
#   B1  `sh` starts (`/bin/sh` reads no BASH_ENV): refused statically by validate-fixture-hygiene.sh's H3.
#   B2  fixtures with no inputs.decl (the `.undeclarable` ones) never run through hermetic-run.sh: out of population,
#       derived by listing `core/fixtures/*/.undeclarable`.
#   B3  fixtures running a child under their own `env -i`: starts beneath it are uncounted, deterministically, so
#       the declared count still binds what the fixture runs outside it. B3 BLINDS J5 TOO: mutant_killed under an
#       inner `env -i` has no FXCOUNT_LOG, so the names it reports there are never appended to <log>.mutants.
#   B4  a fixture setting its own BASH_ENV (snapshot-archive-rotate) replaces the counter for its children.
#   B5  a nested hermetic-run.sh is inert: only FXCOUNT_LOG (with BASH_ENV) crosses its `env -i`, never the three
#       arming variables. An UNDECLARED fixture's direct run is not under that `env -i`, so FXCOUNT_RC, FXCOUNT_DIR and
#       FXCOUNT_JUDGE all reach it from the hook's environment; a hermetic-run.sh it starts would then be armed. A
#       nested copy of the distribution hook is inert by its PREPUSH_POOL_DEPTH gate.
#   B6  a SOURCED subject is not a start. B7 a subshell, `( )` or `$( )` without a new bash, is not a start.
#   B8  a start killed before its first command records nothing. A fixture that backgrounds `bash ... &` and kills
#       it, or runs one under `timeout`, can therefore count fewer starts on a slow run; it makes the kill wait for the
#       child's first command or is listed with its reason. The two-pass counting slot catches only rates high
#       enough to show in two passes. Enumerated statically over the 263 tracked core/fixtures/*/run.sh, non-comment
#       lines only: a backgrounded start `bash <args> &` in a run.sh that also carries a `kill`/`pkill`, or any
#       `timeout`/`gtimeout` use (a seeded `bash x &` plus `kill` is flagged, `bash x && echo` is not). 9 flagged:
#       consumer-suite-pool, readset-skip, readset-stage1-verdict, reconcile-emit-report, spec-join-integrity,
#       wait-beat-liveness, wait-stale-deliverable (background and kill); foreground-budget-deny, retro-audit-scans
#       (timeout); readset-skip carries both. Their per-fixture reasons are not yet read: the counting slot's two passes
#       decide which of them move, and each one that moves is fixed or listed here with its reason.
#   J5 ATTRIBUTION. FXCOUNT_LOG crosses into every child that is not under its own `env -i`, so a fixture that runs
#   another fixture's run.sh directly has the inner fixture's mutant_killed names joined against the OUTER header.
#   Today no other run.sh names one of the four mutant_killed users by path; a driver looping over a glob is not seen
#   by that check.
#   Also unseen: `bash --posix`, `bash -p` and `bash -n` (no BASH_ENV), a script whose first command is a bare
#   subshell, and an empty script. `bash -s` and `bash < f` log an empty path, process substitution `/dev/fd/<n>`;
#   both still count toward `*`.
#
# THE FALSE-POSITIVE SET is measured in the lead's counting slot, never here: two counting passes on the integrated
# tip seed every declaration by script and diff each other (any difference is the nondeterminism set), and a third
# leg adds a throwaway core/scripts/*.sh and a throwaway fixture directory in a scratch copy and re-counts the
# fixtures declaring those directories; every count that moves takes the `c+kxglob` form. A row that moves between
# passes on the same tree is a fixture defect to fix or list, never a tolerance.
#
# EDITING core/scripts/hermetic-run.sh BETWEEN HR_SANDBOX_BEGIN AND HR_SANDBOX_END CHANGES ITS `#runner` DIGEST,
# which voids every recorded pass in the verdict store: the next push runs the whole suite once. The arming lives
# inside that span, so this mechanism's own landing is such an edit.
#
# Distribution-only: repo-root scripts/ is never installed, and nothing on a consumer sets the three variables.
set -u

FXC_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
FXC_REMEDY_TAIL="otherwise this is the regrowth fixture-mutants.md 'One run per distinct state' forbids"

fxc_gen_rc() { # <dir>: write <dir>/fxcount.rc, print its path
  mkdir -p "$1" || return 2
  cat > "$1/fxcount.rc" <<'RC' || return 2
{ trap '{ trap - DEBUG; trap "" XFSZ; __fxcp="${BASH_SOURCE[0]:-${BASH_EXECUTION_STRING:+-c}}"; case "$__fxcp" in /*|-c|"") ;; *) __fxcp="$PWD/$__fxcp" ;; esac; printf "%s\t%s\t%s\t%s\n" "$__fxcp" "$$" "${FXCELL:-}" "${FXCOUNT_PARENT:-}" >> "$FXCOUNT_LOG" || { echo > /dev/null; [ -w "$FXCOUNT_LOG" ] && /bin/ln -s "$__fxcp	$$	${FXCELL:-}	${FXCOUNT_PARENT:-}" "$(/usr/bin/mktemp -u "$FXCOUNT_LOG.lim.XXXXXXXX")"; }; unset __fxcp; trap - XFSZ; export FXCOUNT_PARENT=$$; unset FXCELL; } 2>/dev/null' DEBUG; } 2>/dev/null
RC
  printf '%s\n' "$1/fxcount.rc"
}

# fxc_count <log> <path>: rows whose first field, NORMALISED, equals <path> or ends in /<path>.
# NORMALISATION is pure string work on field 1, no filesystem call: empty and `.` segments are dropped (so `//` collapses),
# and `..` removes the segment before it; a `..` with nothing before it is dropped on an absolute path (`/..` is `/`) and
# kept on a relative one. A segment merely CONTAINING `..` (`x..`, `..b`) is a name, never a `..`. A field with no `.`/`..`
# segment and no `//` is compared untouched. Why textual resolution is the physical one here: see THE DECLARATION.
fxc_count() {
  P="$2" awk -F'\t' 'function nrm(s,   lead, n, a, i, k, o, r) {
      lead = (substr(s, 1, 1) == "/"); n = split(s, a, "/"); k = 0
      for (i = 1; i <= n; i++) {
        if (a[i] == "" || a[i] == ".") continue
        if (a[i] == "..") { if (k > 0 && o[k] != "..") { k--; continue }; if (lead) continue }
        o[++k] = a[i]
      }
      r = ""; for (i = 1; i <= k; i++) r = r (i > 1 ? "/" : "") o[i]
      return (lead ? "/" : "") r
    }
    BEGIN { p = ENVIRON["P"]; s = "/" p; ls = length(s) }
    { f = ($1 ~ /(^|\/)\.\.?(\/|$)/ || index($1, "//") > 0) ? nrm($1) : $1 }
    f == p || (length(f) > ls && substr(f, length(f) - ls + 1) == s) { n++ } END { print n + 0 }' "$1"
}

# fxc_glob_n <root> <glob>: number of paths the glob matches under root
fxc_glob_n() {
  ( cd "$1" 2>/dev/null || exit 1; set +f; n=0
    for p in $2; do { [ -e "$p" ] || [ -L "$p" ]; } && n=$((n + 1)); done
    printf '%s\n' "$n" )
}

# fxc_impl_of <run.sh>...: THE ONE SHARD-STUB RESOLVER (validate-fixture-hygiene.sh's H5 calls it through
# --impl-of rather than carrying a second grammar). One awk over every file named; for each file that is a shard stub
# -- a line `[exec ]bash "$IMPL" --group ...` -- prints `<file>\t<IMPL fixture>` from its `IMPL="$HERE/../<f>/run.sh"`
# line, or `<file>\t!` when that line is absent. A file that is not a stub prints nothing. Both spellings are live:
# 22 stubs `exec` the IMPL, and ledger-reverify-b/c/d and reconcile-emit-report-b/c/d run it without `exec`.
fxc_impl_of() {
  [ $# -gt 0 ] || return 0
  awk 'function flush() { if (cur != "" && stub) print cur "\t" (impl == "" ? "!" : impl) }
    FNR == 1 { flush(); cur = FILENAME; stub = 0; impl = "" }
    /^[[:space:]]*(exec[[:space:]]+)?bash "\$IMPL" --group/ { stub = 1 }
    impl == "" && /^IMPL="\$HERE\/\.\.\/[A-Za-z0-9_.-]+\/run\.sh"$/ { s = $0; sub(/^IMPL="\$HERE\/\.\.\//, "", s); sub(/\/run\.sh"$/, "", s); impl = s }
    END { flush() }' "$@"
}

# fxc_allowlisted <fixture>: 0 when <fixture> is a row of scripts/fixture-matrix-allowlist.txt beside this script
# (field 1, exact). An absent allowlist exempts nothing -- the fail-closed direction.
# FXC_ALLOW is assigned here, never read from the environment; only the self-probe repoints it, at its own seed.
FXC_ALLOW="${FXC_SELF%/*}/fixture-matrix-allowlist.txt"
fxc_allowlisted() {
  [ -f "$FXC_ALLOW" ] || return 1
  F="$1" awk -F'\t' '$0 ~ /^[[:space:]]*(#|$)/ { next } $1 == ENVIRON["F"] { f = 1 } END { exit f ? 0 : 1 }' "$FXC_ALLOW"
}

# fxc_mutant_rows <run.sh> <root>: print `M <name>` and `C <name>` rows, following a shard stub to its IMPL.
fxc_mutant_rows() {
  local f="$1" impl
  impl="$(fxc_impl_of "$f")"
  if [ -n "$impl" ]; then
    impl="${impl##*$'\t'}"
    [ "$impl" != '!' ] || return 3
    f="$(dirname "$(dirname "$f")")/$impl/run.sh"
    [ -f "$f" ] || return 3
  fi
  # A heredoc body is data, never the header: a MUTANT-MATRIX line a battery SEEDS into a probe file (fixture-hygiene
  # does) is not this fixture's row. validate-fixture-hygiene.sh's H5 skips heredoc bodies through its masker, which
  # lives inside that script's `read -d ''` awk string behind a top-level self-probe and has no callable entry point,
  # so this is a second, smaller tracker: a `<<` outside quotes on a non-comment line, not `<<<`, opens a body whose
  # delimiter is the next word (quoted, backslashed or bare; `<<-` strips leading tabs); a word that cannot start a
  # name (`$((1<<3))`) opens nothing. Several heredocs on one line are closed in order.
  awk -v SQ="'" 'function qmask(s,   o, i, n, c, q) {
      o = ""; q = ""; n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q == "") { if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[[:space:];&|]/)) break
                       if (c == SQ || c == "\"") q = c; o = o c; continue }
        if (q == "\"" && c == "\\") { o = o "XX"; i++; continue }
        if (c == q) { q = ""; o = o c } else o = o "X"
      }
      return o
    }
    function opens(s,   m, p, r, c, w, dash) {
      m = qmask(s); p = 0
      while ((r = index(substr(m, p + 1), "<<")) > 0) {
        p += r + 1
        if (substr(m, p + 1, 1) == "<") { while (substr(m, p + 1, 1) == "<") p++; continue }
        dash = (substr(s, p + 1, 1) == "-"); r = s; r = substr(r, p + 1 + dash)
        sub(/^[[:space:]]+/, "", r); c = substr(r, 1, 1); w = ""
        if (c == SQ || c == "\"") { r = substr(r, 2); if (index(r, c)) w = substr(r, 1, index(r, c) - 1) }
        else { if (c == "\\") r = substr(r, 2); if (match(r, /^[A-Za-z_][A-Za-z0-9_]*/)) w = substr(r, 1, RLENGTH) }
        if (w != "") { HN++; HW[HN] = w; HD[HN] = dash }
      }
      if (HN > 0) HI = 1
    }
    { orig = $0 }
    HN > 0 && HI > 0 { l = $0; if (HD[HI]) sub(/^\t+/, "", l); if (l == HW[HI]) { HI++; if (HI > HN) { HN = 0; HI = 0 } } next }
    $1 == "#" && ($2 == "MUTANT-MATRIX" || $2 == "MUTANT-MATRIX-FULL") && NF >= 3 { print "M\t" $3 }
    $1 == "#" && $2 == "MUTANT-MATRIX-CONTROL" && NF >= 3 { print "C\t" $3 }
    { opens(orig) }' "$f"
}

# fxc_req <inputs.decl>: the `!` (REQUIRED) FILE lines, markers stripped, one per line. A directory line is never one.
fxc_req() {
  awk '{ sub(/\r$/, "") } $0 == "" || /^#/ { next }
      { r = 0; while ((ch = substr($0, 1, 1)) == "!" || ch == "+") { if (ch == "!") r = 1; $0 = substr($0, 2) }
        if (r && $0 !~ /\/$/) print }' "$1"
}

# fxc_decl_rows <invocations.decl>: J4's parse, one normalised row per line: `<c>\t<k>\t<glob or ->\t<target>\t<raw>`,
# or `ERR\t<raw>`. The judge and --b2-census read the same parse.
fxc_decl_rows() {
  awk '{ sub(/\r$/, "") } $0 ~ /^[[:blank:]]*$/ || $0 ~ /^[[:blank:]]*#/ { next }
      { raw = $0
        if (NF != 2) { print "ERR\t" raw; next }
        cnt = $1; t = $2
        # A count with a leading zero (`09`, `1+08x…`) is refused here: bash arithmetic reads it as octal and dies.
        lz = cnt; sub(/x.*/, "", lz)
        if (lz ~ /(^|\+)0[0-9]/) { print "ERR\t" raw; next }
        if (cnt ~ /^[0-9]+$/) { print cnt "\t0\t-\t" t "\t" raw; next }
        if (cnt ~ /^[0-9]+\+[0-9]+x[^[:blank:]]+$/) {
          p = index(cnt, "+"); x = index(cnt, "x"); g = substr(cnt, x + 1)
          if (g ~ /^\// || g ~ /(^|\/)\.\.(\/|$)/) { print "ERR\t" raw; next }
          print substr(cnt, 1, p - 1) "\t" substr(cnt, p + 1, x - p - 1) "\t" g "\t" t "\t" raw; next }
        print "ERR\t" raw }' "$1"
}

# J6's POPULATION. fxc_subject_kind <file>: sets FXC_KIND to bash, script or data, fork-free. A name ending `.sh` is
# bash whatever its first line says (a `.sh` with no shebang is a sourced library, and `0 <path>` rows it); any other
# name is bash when its FIRST LINE is a shebang whose interpreter is `sh` or `bash`, directly (`#!/bin/sh`) or through
# `env` with its options and assignments skipped (`#!/usr/bin/env -S bash -e`). A shebang naming any other interpreter
# is a non-shell script, as is a shebang-less `.py`/`.js`/`.mjs`/`.cjs`/`.ts`/`.awk`/`.pl`/`.rb`; everything else is
# a data file. An absent file is decided by its name alone. Measured at this change over the 179 distinct `!` file
# subjects of core/fixtures/*/inputs.decl: 143 `.sh` (137 with a bash shebang, 6 without one), 2 shebang-bash files
# with no extension, 1 node-shebang `.js`, 1 `.py` and 1 `.awk` with no shebang, and 31 data files
# (`.md`, `.json`, `.yaml`, `.txt`, `.diff`). No `.sh` carries a non-shell shebang, so name and first line never disagree.
fxc_subject_kind() {
  local f="$1" l="" i=0
  local -a w
  FXC_KIND=data
  case "$f" in *.sh) FXC_KIND=bash; return 0 ;; esac
  [ -f "$f" ] && { IFS= read -r l < "$f" || :; }
  case "$l" in
    '#!'*) ;;
    *) case "${f##*/}" in *.py|*.js|*.mjs|*.cjs|*.ts|*.awk|*.pl|*.rb) FXC_KIND=script ;; esac; return 0 ;;
  esac
  FXC_KIND=script
  l="${l#??}"; l="${l%$'\r'}"
  case "$l" in *[![:space:]]*) ;; *) return 0 ;; esac
  read -r -a w <<< "$l"
  if [ "${w[0]##*/}" = env ]; then
    i=1
    while [ "$i" -lt "${#w[@]}" ]; do case "${w[$i]}" in -*|*=*) i=$((i + 1)) ;; *) break ;; esac; done
  fi
  [ "$i" -lt "${#w[@]}" ] || return 0
  case "${w[$i]##*/}" in sh|bash) FXC_KIND=bash ;; esac
  return 0
}

# fxc_b2 <root> <req file> <targets file>: one row per `!` file subject: `B\t<path>` a bash subject with a row,
# `G\t<path>` a bash subject with none (J6's finding), `D\t<path>` a data file, `S\t<path>` a non-shell script.
# Classified at <root>/<path>. Fork-free: the targets are matched as one newline-delimited string.
fxc_b2() {
  local p t tg="" NL=$'\n'
  while IFS= read -r t; do tg="$tg$NL$t"; done < "$3"
  tg="$tg$NL"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    fxc_subject_kind "$1/$p"
    case "$FXC_KIND" in
      data) printf 'D\t%s\n' "$p" ;;
      script) printf 'S\t%s\n' "$p" ;;
      *) case "$tg" in
           *"$NL$p$NL"*) printf 'B\t%s\n' "$p" ;;
           *) printf 'G\t%s\n' "$p" ;;
         esac ;;
    esac
  done < "$2"
}

# fxc_census <root>: THE STATIC B2 WALK (--b2-census), over <root>/core/fixtures/*/run.sh. A `.undeclarable` fixture
# never reaches the judge (hermetic-run.sh refuses a fixture with no inputs.decl), so its line `EXEMPT (undeclarable)`
# is printed here and nowhere else. Every other fixture's `!` bash subjects are joined against the targets of its
# invocations.decl through the judge's own parse and classifier: each gap prints `B2 GAP <fixture> <path>`. A fixture
# with neither inputs.decl nor .undeclarable prints `UNDECLARED <fixture>` (no subject to judge). Counts are over
# (fixture, subject) PAIRS. Returns 0 no gap, 1 a gap, 2 a refusal: no run.sh listed. (The scanned == listed refusal
# is U3's validate-fixture-inprocess.sh's; here both would be counted by one predicate over one glob and could not differ.)
fxc_census() {
  local root="$1" d fx listed=0 scanned=0 ex=0 und=0 gaps=0 gfx=0 nb=0 nd=0 ns=0 k p g w
  w="$(mktemp -d "${TMPDIR:-/tmp}/fxc-census.XXXXXX")" || return 2
  for d in "$root"/core/fixtures/*/; do [ -f "$d/run.sh" ] && listed=$((listed + 1)); done
  [ "$listed" -gt 0 ] || { printf 'b2-census: REFUSED: no core/fixtures/*/run.sh under %s\n' "$root"; rm -rf "$w"; return 2; }
  for d in "$root"/core/fixtures/*/; do
    d="${d%/}"; fx="${d##*/}"
    [ -f "$d/run.sh" ] || continue
    scanned=$((scanned + 1))
    if [ -e "$d/.undeclarable" ]; then printf 'EXEMPT (undeclarable) %s\n' "$fx"; ex=$((ex + 1)); continue; fi
    if [ ! -f "$d/inputs.decl" ]; then printf 'UNDECLARED %s\n' "$fx"; und=$((und + 1)); continue; fi
    fxc_req "$d/inputs.decl" > "$w/req"
    : > "$w/tgts"
    [ -f "$d/invocations.decl" ] && fxc_decl_rows "$d/invocations.decl" | awk -F'\t' '$1 != "ERR" { print $4 }' > "$w/tgts"
    fxc_b2 "$root" "$w/req" "$w/tgts" > "$w/b2"
    g=0
    while IFS="$(printf '\t')" read -r k p; do
      case "$k" in
        B) nb=$((nb + 1)) ;; D) nd=$((nd + 1)) ;; S) ns=$((ns + 1)) ;;
        G) printf 'B2 GAP %s %s\n' "$fx" "$p"; g=$((g + 1)) ;;
      esac
    done < "$w/b2"
    [ "$g" -gt 0 ] && { gaps=$((gaps + g)); gfx=$((gfx + 1)); }
  done
  rm -rf "$w"
  printf 'b2-census: %s fixture(s) scanned; %s EXEMPT (undeclarable), %s UNDECLARED; %s gap(s) over %s fixture(s); %s bash subject(s) rowed; outside the population: %s data file(s), %s non-shell script(s) (counts are fixture-subject pairs)\n' \
    "$scanned" "$ex" "$und" "$gaps" "$gfx" "$nb" "$nd" "$ns"
  [ "$gaps" -eq 0 ]
}

# ---------------------------------------------------------------------------------------------------------------
# THE IN-PROCESS CELLS (BL-879). core/fixtures/<f>/cells.decl declares every start of a subject the fixture makes:
#   cli <subject> <cell-id>                      an equivalence cell: the subject run as a program for one distinct outcome
#   e2e <subject> <cell-id> why=<reason>         a cell that stays end to end, the reason non-empty
#   nested <parent-subject> <child-subject> why=<reason>   every start of <child> whose logged parent is a start of
#                                                <parent> is covered (a subject that starts another counted script)
# `#` comments and blank lines ignored. A cell id matches [A-Za-z0-9_.-]+ and is unique within the file. A missing
# cells.decl reads as an EMPTY one (lead ruling): a fixture that starts no subject passes with nothing to tag.
# THE EMISSION SITE: the fixture starts a subject as `FXCELL=<id> bash <subject>`. The counter rc logs `${FXCELL:-}`
# as field 3 and FXCOUNT_PARENT, an EXPORTED carrier of the nearest logging start's `$$` (never `$PPID`, which is a
# subshell's parent), as field 4, and unsets FXCELL inside the trap, so a grandchild logs an empty tag.
# fxc_cells_parse <cells.decl>...: one awk over every file named. Rows:
#   F\t<file>                                    one per file opened (the scanned-count control)
#   R\t<file>\t<kind>\t<subject>\t<id or child>\t<why>\t<line>
#   E\t<file>\t<line>\t<arm>\t<reason>\t<raw>   C2 (grammar, id shape, duplicate id) or C4 (an empty why=)
# A file that cannot be opened prints no F row; the caller compares F rows with the list it handed over.
fxc_cells_parse() {
  [ $# -gt 0 ] || return 0
  awk 'FNR == 1 { print "F\t" FILENAME; delete ID }
    { sub(/\r$/, "") } $0 ~ /^[[:blank:]]*$/ || $0 ~ /^[[:blank:]]*#/ { next }
    { raw = $0; k = $1
      if (k != "cli" && k != "e2e" && k != "nested") { print "E\t" FILENAME "\t" FNR "\tC2\tunknown row kind " k " (want cli, e2e or nested)\t" raw; next }
      if (k == "cli") { if (NF != 3) { print "E\t" FILENAME "\t" FNR "\tC2\ta cli row is exactly `cli <subject> <cell-id>`\t" raw; next } why = "" }
      else {
        if (NF < 4 || substr($4, 1, 4) != "why=") { print "E\t" FILENAME "\t" FNR "\tC2\tan " k " row ends in why=<reason>\t" raw; next }
        why = raw; sub(/^[[:blank:]]*[^[:blank:]]+[[:blank:]]+[^[:blank:]]+[[:blank:]]+[^[:blank:]]+[[:blank:]]+why=/, "", why)
        g = why; gsub(/[[:blank:]]/, "", g)
        if (g == "") { print "E\t" FILENAME "\t" FNR "\tC4\tan empty why= on an " k " row\t" raw; next }
      }
      if (k != "nested") {
        if ($3 !~ /^[A-Za-z0-9_.-]+$/) { print "E\t" FILENAME "\t" FNR "\tC2\tcell id " $3 " is not [A-Za-z0-9_.-]+\t" raw; next }
        if ($3 in ID) { print "E\t" FILENAME "\t" FNR "\tC2\tcell id " $3 " is declared twice (first at line " ID[$3] ")\t" raw; next }
        ID[$3] = FNR
      }
      print "R\t" FILENAME "\t" k "\t" $2 "\t" $3 "\t" why "\t" FNR }' "$@"
}

# fxc_guarded <file>...: C5's predicate, one awk. Prints `G\t<file>` for a file carrying the BASH_SOURCE source guard
# as one of exactly two WHOLE-LINE statements at column 0, `[ "${BASH_SOURCE[0]}" = "$0" ] || return 0` or
# `if [ "${BASH_SOURCE[0]}" = "$0" ]; then`, and `U\t<file>` otherwise. A line merely CONTAINING the token (a data
# string, a comment, an indented copy) is not the statement. KNOWN ROUTE: a heredoc body line spelled exactly as the
# statement satisfies it. A file absent or empty prints nothing; the caller reads that as unguarded.
fxc_guarded() {
  [ $# -gt 0 ] || return 0
  awk -v SQ="'" 'BEGIN { a = "[ \"${BASH_SOURCE[0]}\" = \"$0\" ] || return 0"; b = "if [ \"${BASH_SOURCE[0]}\" = \"$0\" ]; then" }
    FNR == 1 { if (cur != "") print (g ? "G" : "U") "\t" cur; cur = FILENAME; g = 0 }
    { l = $0; sub(/\r$/, "", l) } l == a || l == b { g = 1 }
    END { if (cur != "") print (g ? "G" : "U") "\t" cur }' "$@" 2>/dev/null
}

# fxc_cells_judge <targets> <cells parse rows> <log>: THE DYNAMIC ARMS over one counted run's start log. A start is
# a start of subject S when its logged path, NORMALISED as fxc_count normalises it, equals S or ends in `/S`, S being
# a path row of invocations.decl -- the declared path only: a renamed or relocated mutant copy is BL-878 item 3's
# uncounted route, not this arm's subject. The longest matching target wins. Rows:
#   C1\t<subject>\t<logged path>\t<parent subject or ->   an untagged start covered by no nested row
#   C2\t<subject or ->\t<tag>\t<logged path>               a tag naming no declared cell of that subject (`-`: a tag
#                                                           on a start that is no subject, e.g. a `bash -c` wrapper)
#   C3\t<subject>\t<cell>\t<n>                             a declared cli/e2e cell that tagged n != 1 starts
#   SUM\t<subject starts>\t<tagged>\t<nested-covered>
# The parent is looked up as the LATEST preceding row with that pid, so a pid reused later in a long run resolves to
# the start that was live when the child logged. KNOWN ROUTE: a parent that is itself unlogged (a start under its own
# `env -i`) is absent, so its child reads as having no parent.
fxc_cells_judge() {
  awk -F'\t' 'function nrm(s,   lead, n, a, i, k, o, r) {
      lead = (substr(s, 1, 1) == "/"); n = split(s, a, "/"); k = 0
      for (i = 1; i <= n; i++) {
        if (a[i] == "" || a[i] == ".") continue
        if (a[i] == "..") { if (k > 0 && o[k] != "..") { k--; continue }; if (lead) continue }
        o[++k] = a[i]
      }
      r = ""; for (i = 1; i <= k; i++) r = r (i > 1 ? "/" : "") o[i]
      return (lead ? "/" : "") r
    }
    FILENAME == ARGV[1] { if ($0 != "" && $0 != "*") T[++nt] = $0; next }
    FILENAME == ARGV[2] { if ($1 == "R") { if ($3 == "nested") N[$4 SUBSEP $5] = 1; else C[$4 SUBSEP $5] = 0 } next }
    { f = ($1 ~ /(^|\/)\.\.?(\/|$)/ || index($1, "//") > 0) ? nrm($1) : $1; s = ""; best = 0
      for (i = 1; i <= nt; i++) { p = T[i]; lp = length(p)
        if ((f == p || (length(f) > lp + 1 && substr(f, length(f) - lp) == "/" p)) && lp > best) { best = lp; s = p } }
      par = ($4 != "" && ($4 in LP)) ? LP[$4] : ""
      LP[$2] = s
      if (s == "") { if ($3 != "") print "C2\t-\t" $3 "\t" $1; next }
      ns++
      if ($3 != "") { if ((s SUBSEP $3) in C) { C[s SUBSEP $3]++; nt2++ } else print "C2\t" s "\t" $3 "\t" $1; next }
      if (par != "" && ((par SUBSEP s) in N)) { nn++; next }
      print "C1\t" s "\t" $1 "\t" (par == "" ? "-" : par) }
    END { for (k in C) if (C[k] != 1) { split(k, a, SUBSEP); print "C3\t" a[1] "\t" a[2] "\t" C[k] }
          print "SUM\t" ns + 0 "\t" nt2 + 0 "\t" nn + 0 }' "$1" "$2" "$3"
}

# fxc_static_join <root>: THE STATIC HALF OF C1-C5, over <root>/core/fixtures/*/run.sh, read through THIS file's own
# parses (fxc_decl_rows, fxc_cells_parse, fxc_guarded) so no grammar is restated. One row per fixture:
#   F\t<fx>                              scanned (every listed run.sh; .undeclarable and undeclared ones too)
#   X\t<fx>\t<reason>                    REFUSED: the dynamic arms cannot pass this tree
#   P\t<fx>                              predicted to pass (the counted run decides)
#   O\t<fx>\t<why>                       out of population (`.undeclarable`, or no inputs.decl)
#   E\t<fx>\t<arm>\t<line>\t<reason>     a static finding: C2 (grammar, a cell subject that is no path row), C4, C5
# THE PREDICATE, per subject S (a path row of invocations.decl declaring n starts, a `c+kxglob` row expanded under
# <root>): S passes when n equals its cli+e2e cell count, or when S is the child of a `nested` row and n is at least
# that count; n = 0 always passes. A fixture passes when every S does and it carries no static finding. A REFUSAL IS
# EXACT under J3: the counted run starts S n times, each cell tags exactly one start (C3), so n != cells with no
# nested cover leaves a start untagged (C1) or a cell over- or under-used (C3). A PASS IS A PREDICTION only: which
# start carries which tag is not visible without a run, which is the dynamic judge's job.
fxc_static_join() {
  local root="$1" d fx w p n c k g tgt raw cf nn guarded
  w="$(mktemp -d "${TMPDIR:-/tmp}/fxc-sj.XXXXXX")" || return 2
  for d in "$root"/core/fixtures/*/; do
    d="${d%/}"; fx="${d##*/}"
    [ -f "$d/run.sh" ] || continue
    printf 'F\t%s\n' "$fx"
    if [ -e "$d/.undeclarable" ]; then printf 'O\t%s\tundeclarable\n' "$fx"; continue; fi
    if [ ! -f "$d/inputs.decl" ]; then printf 'O\t%s\tno inputs.decl\n' "$fx"; continue; fi
    cf="$d/cells.decl"
    if [ -f "$cf" ]; then fxc_cells_parse "$cf" > "$w/c"; else : > "$w/c"; fi
    : > "$w/r"; [ -f "$d/invocations.decl" ] && fxc_decl_rows "$d/invocations.decl" > "$w/r"
    : > "$w/n"
    while IFS="$(printf '\t')" read -r c k g tgt raw; do
      [ "$c" = ERR ] && continue
      [ -n "$tgt" ] && [ "$tgt" != '*' ] || continue
      n="$c"
      if [ "$g" != - ]; then n=$((c + k * $(fxc_glob_n "$root" "$g"))); fi
      printf '%s\t%s\n' "$tgt" "$n" >> "$w/n"
    done < "$w/r"
    awk -F'\t' '$1 == "R" && $3 == "cli" { print $4 }' "$w/c" | LC_ALL=C sort -u > "$w/cli"
    : > "$w/g"
    while IFS= read -r p; do [ -n "$p" ] && printf '%s\t%s\n' "$p" "$(fxc_guarded "$root/$p" | cut -f1)" >> "$w/g"; done < "$w/cli"
    awk -F'\t' -v fx="$fx" '
      FILENAME == ARGV[1] { N[$1] = $2; next }
      FILENAME == ARGV[2] { G[$1] = $2; next }
      $1 == "E" { print "E\t" fx "\t" $4 "\t" $3 "\t" $5; bad = 1; next }
      $1 == "R" { if (!($4 in N)) { print "E\t" fx "\tC2\t" $7 "\t" $3 " row names " $4 ", which is no path row of invocations.decl"; bad = 1 }
                  if ($3 == "nested") { if (!($5 in N)) { print "E\t" fx "\tC2\t" $7 "\tnested row names child " $5 ", which is no path row of invocations.decl"; bad = 1 } else NEST[$5] = 1 }
                  else CC[$4]++
                  if ($3 == "cli" && G[$4] != "G") { print "E\t" fx "\tC5\t" $7 "\tcli subject " $4 " carries no column-0 BASH_SOURCE source guard statement"; G[$4] = "R"; bad = 1 } }
      END { for (s in N) { n = N[s] + 0; c = CC[s] + 0
              if (n == 0 && c == 0) continue
              if (n == c || ((s in NEST) && n >= c)) continue
              r = r (r == "" ? "" : "; ") s " declares " n " start(s) against " c " cell(s)" ((s in NEST) ? " and a nested row" : "") }
            if (r != "") print "X\t" fx "\t" r
            else if (bad) print "X\t" fx "\tstatic finding(s) above"
            else print "P\t" fx }' "$w/n" "$w/g" "$w/c"
  done
  rm -rf "$w"
}

# fxc_inproc_listed <fixture>: 0 when <fixture> is a row of scripts/fixture-inprocess-allowlist.txt beside this script.
# FXC_INPROC_ALLOW is assigned here, never read from the environment; only the self-probe repoints it.
FXC_INPROC_ALLOW="${FXC_SELF%/*}/fixture-inprocess-allowlist.txt"
# FXC_CELLS gates the C arms in fxc_judge. Assigned here, never read from the environment; the self-probe sets it 0
# only for the J-arm cells, whose synthetic logs carry no tags, and asserts it read 1 on entry.
FXC_CELLS=1
fxc_inproc_listed() {
  [ -f "$FXC_INPROC_ALLOW" ] || return 1
  F="$1" awk -F'\t' '$0 ~ /^[[:space:]]*(#|$)/ { next } $1 == ENVIRON["F"] { f = 1 } END { exit f ? 0 : 1 }' "$FXC_INPROC_ALLOW"
}
FXC_CELLS_REMEDY="build the fixture in-process (.claude/rules/fixture-mutants.md 'One run per distinct state'; the reference fixtures BL-878 names: push-drain-refusals, ledger-reverify-unfalsifiable, readset-stage1-verdict, story-evidence-scaffold), and declare each remaining start in cells.decl -- \`cli <subject> <cell-id>\`, \`e2e <subject> <cell-id> why=<reason>\`, \`nested <parent> <child> why=<reason>\` -- started as \`FXCELL=<cell-id> bash <subject>\`"

# fxc_judge <fixture> <decl> <log> <root>: messages on stdout; returns 0 pass, 1 FAIL, 2 BROKEN.
fxc_judge() {
  local fx="$1" decl="$2" log="$3" root="$4" jl fd inp w rc=0 tot kind c k g tgt raw dcl m n rows p nb nd ns
  fd="$(dirname "$decl")"; inp="$fd/inputs.decl"
  w="$(mktemp -d "${TMPDIR:-/tmp}/fxc-judge.XXXXXX")" || return 2
  # The start log the judge reads is the appended rows plus one row per `<log>.lim.*` marker, the symlink a start under
  # a file-size limit leaves when its append is refused (see THE COUNTER). Every row below is read from this merge.
  { cat "$log" 2>/dev/null; for m in "$log".lim.*; do [ -L "$m" ] && printf '%s\n' "$(readlink "$m")"; done; } > "$w/log"
  if [ ! -s "$w/log" ]; then
    printf '%s: FIXTURE BROKEN (J1): the invocation log %s is %s -- run.sh is itself a bash start, so a counted run logs at least one row; the counter never loaded\n' \
      "$fx" "$log" "$([ -e "$log" ] && echo empty || echo absent)"
    rm -rf "$w"; return 2
  fi
  jl="$w/log"
  : > "$w/req"
  [ -f "$inp" ] && fxc_req "$inp" > "$w/req"
  tot="$(awk 'END { print NR }' "$jl")"
  if [ ! -f "$decl" ]; then
    printf '%s: FAIL (J2): no invocations.decl in the fixture directory. Measured on this run -- write this as %s/invocations.decl:\n' "$fx" "${fd#"$root"/}"
    printf '  %s *\n' "$tot"
    # A bash subject this run never started is printed with its 0, so the printed declaration, written, passes J6.
    while IFS= read -r p; do
      n="$(fxc_count "$jl" "$p")"; fxc_subject_kind "$root/$p"
      { [ "$n" -gt 0 ] || [ "$FXC_KIND" = bash ]; } && printf '  %s %s\n' "$n" "$p"
    done < "$w/req"
    rc=1
  else
    # J4: one normalised row per line (fxc_decl_rows).
    fxc_decl_rows "$decl" > "$w/rows"
    while IFS="$(printf '\t')" read -r kind raw; do
      [ "$kind" = ERR ] || continue
      printf '%s: FAIL (J4): malformed invocations.decl row: %s (want `<count> *`, `<count> <path>`, or `<c>+<k>x<glob> <target>`; every row is exact)\n' "$fx" "$raw"; rc=1
    done < "$w/rows"
    awk -F'\t' '$1 != "ERR" { print $4 }' "$w/rows" > "$w/tgts"
    n="$(grep -cxF '*' "$w/tgts")" || n=0
    [ "$n" -eq 1 ] || { printf '%s: FAIL (J4): invocations.decl carries %s `*` rows; exactly one is required\n' "$fx" "$n"; rc=1; }
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      printf '%s: FAIL (J4): invocations.decl names %s on more than one row\n' "$fx" "$t"; rc=1
    done <<EOF
$(LC_ALL=C sort "$w/tgts" | uniq -d)
EOF
    while IFS="$(printf '\t')" read -r c k g tgt raw; do
      [ "$c" = ERR ] && continue
      [ -n "$c" ] || continue
      if [ "$tgt" != '*' ]; then
        if ! grep -qxF -- "$tgt" "$w/req"; then
          printf '%s: FAIL (J4): row "%s" names %s, which is not a `!` (REQUIRED) file line of %s -- a path row binds to the declaration, never a second list\n' "$fx" "$raw" "$tgt" "${inp#"$root"/}"; rc=1; continue
        fi
        m="$(fxc_count "$jl" "$tgt")"
      else
        m="$tot"
      fi
      dcl="$c"
      if [ "$g" != - ]; then
        n="$(fxc_glob_n "$root" "$g")" || { printf '%s: FIXTURE BROKEN (J4): cannot expand %s under %s\n' "$fx" "$g" "$root"; rm -rf "$w"; return 2; }
        dcl=$((c + k * n))
      fi
      # J3
      if [ "$m" != "$dcl" ]; then
        printf '%s: FAIL (J3): row "%s": measured %s, declared %s -- if this change was meant to alter how often the fixture runs its subject, set the row to %s; %s\n' \
          "$fx" "$raw" "$m" "$dcl" "$m" "$FXC_REMEDY_TAIL"
        rc=1
      fi
    done < "$w/rows"
    # J6: every `!` bash subject carries a row; `0 <path>` satisfies it. The row to add is this run's measured count.
    fxc_b2 "$root" "$w/req" "$w/tgts" > "$w/b2"
    nb=0; nd=0; ns=0
    while IFS="$(printf '\t')" read -r kind p; do
      case "$kind" in
        B) nb=$((nb + 1)) ;; D) nd=$((nd + 1)) ;; S) ns=$((ns + 1)) ;;
        G) printf '%s: FAIL (J6): %s is a `!` bash subject with no invocations.decl row -- row to add, measured on this run: %s %s\n' "$fx" "$p" "$(fxc_count "$jl" "$p")" "$p"; rc=1 ;;
      esac
    done < "$w/b2"
    printf 'J6: %s: %s bash subject(s) rowed; outside the population: %s data file(s), %s non-shell script(s)\n' "$fx" "$nb" "$nd" "$ns"
  fi
  # J5
  local key="${fd##*/}"
  if [ -s "$log.mutants" ]; then
    key="$(fxc_impl_of "$fd/run.sh" 2>/dev/null)"; key="${key##*$'\t'}"; [ -n "$key" ] || key="${fd##*/}"
  fi
  if [ -s "$log.mutants" ] && fxc_allowlisted "$key"; then
    printf '%s: J5 EXEMPT, not judged: %s is a row of scripts/fixture-matrix-allowlist.txt (no MUTANT-MATRIX block yet); its %s reported mutant name(s) were not joined\n' \
      "$fx" "$key" "$(LC_ALL=C sort -u "$log.mutants" | awk 'END { print NR }')"
  elif [ -s "$log.mutants" ]; then
    if ! fxc_mutant_rows "$fd/run.sh" "$root" > "$w/mrows"; then
      printf '%s: FIXTURE BROKEN (J5): %s is a shard stub whose IMPL run.sh cannot be resolved\n' "$fx" "${fd#"$root"/}/run.sh"; rm -rf "$w"; return 2
    fi
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      if grep -qxF "C$(printf '\t')$m" "$w/mrows"; then
        printf '%s: FAIL (J5): mutant_killed reported %s, which carries a MUTANT-MATRIX-CONTROL row -- a control is not a mutant and never routes through mutant_killed\n' "$fx" "$m"; rc=1
      elif ! grep -qxF "M$(printf '\t')$m" "$w/mrows"; then
        printf '%s: FAIL (J5): mutant_killed reported %s, which has no `# MUTANT-MATRIX %s ...` or `# MUTANT-MATRIX-FULL %s ...` row in the fixture header\n' "$fx" "$m" "$m" "$m"; rc=1
      fi
    done <<EOF
$(LC_ALL=C sort -u "$log.mutants")
EOF
    [ "$rc" = 0 ] && printf 'ok J5: %s: %s name(s) joined\n' "$fx" "$(LC_ALL=C sort -u "$log.mutants" | awk 'END { print NR }')"
  else
    printf 'ok J5: %s: 0 name(s) (no mutant_killed emission)\n' "$fx"
  fi
  # C1-C3 and the stale allowlist row, over this run's start log (THE IN-PROCESS CELLS above). Judged only beside a
  # declaration: with none, J2 has already FAILed and there is no subject to attribute a start to.
  if [ "$FXC_CELLS" = 1 ] && [ -f "$decl" ]; then
    local cf="$fd/cells.decl" ck="${fd##*/}" nf ne n5 sum
    if [ -f "$cf" ]; then fxc_cells_parse "$cf" > "$w/cells"; else : > "$w/cells"; fi
    fxc_cells_judge "$w/tgts" "$w/cells" "$jl" > "$w/cj"
    nf="$(grep -cE '^C[123]	' "$w/cj")" || nf=0
    ne="$(grep -c '^E	' "$w/cells")" || ne=0
    awk -F'\t' '$1 == "R" && $3 == "cli" { print $4 }' "$w/cells" | LC_ALL=C sort -u > "$w/cli"
    n5=0
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ "$(fxc_guarded "$root/$p")" = "G	$root/$p" ] || n5=$((n5 + 1))
    done < "$w/cli"
    sum="$(awk -F'\t' '$1 == "SUM" { print $2 " subject start(s), " $3 " tagged, " $4 " covered by a nested row" }' "$w/cj")"
    if fxc_inproc_listed "$ck"; then
      if [ "$nf" -eq 0 ] && [ "$ne" -eq 0 ] && [ "$n5" -eq 0 ]; then
        printf '%s: FAIL (C stale): %s is a row of scripts/fixture-inprocess-allowlist.txt but now passes C1-C5 (%s) -- delete its row in this change\n' "$fx" "$ck" "$sum"; rc=1
      else
        printf '%s: C EXEMPT, not judged: %s is a row of scripts/fixture-inprocess-allowlist.txt (%s finding(s) held; %s)\n' "$fx" "$ck" "$((nf + ne + n5))" "$sum"
      fi
    elif [ "$nf" -gt 0 ]; then
      rc=1
      awk -F'\t' -v fx="$fx" -v nocf="$([ -f "$cf" ] && echo 0 || echo 1)" '
        $1 == "C1" { print fx ": FAIL (C1): " $2 " started as a separate program with no FXCELL tag (" $3 (($4 != "-") ? ", parent " $4 ", no nested row covering it" : "") ")" (nocf ? " -- the fixture carries no cells.decl" : "") }
        $1 == "C2" { print fx ": FAIL (C2): FXCELL=" $3 " names no declared cell" (($2 != "-") ? " of " $2 : " (the tagged start, " $4 ", is no subject of invocations.decl)") }
        $1 == "C3" { print fx ": FAIL (C3): cell " $3 " of " $2 " tagged " $4 " start(s); each declared cell tags exactly one" }' "$w/cj" | LC_ALL=C sort
      printf '  Remedy: %s.\n' "$FXC_CELLS_REMEDY"
    else
      printf 'ok C: %s: %s\n' "$fx" "$sum"
    fi
  fi
  rm -rf "$w"
  [ "$rc" = 0 ] && printf '%s: invocation budget ok: %s start(s)\n' "$fx" "$tot"
  return "$rc"
}

# ---------------------------------------------------------------------------------------------------------------
# THE SELF-PROBE.
SP_FAIL=0; SP_N=0; SP_VERBOSE=0; SP_OUT=""
sp_ok()  { SP_N=$((SP_N + 1)); [ "$SP_VERBOSE" = 1 ] && printf '  ok    self-probe %s\n' "$1"; return 0; }
sp_bad() { SP_N=$((SP_N + 1)); SP_FAIL=1; SP_OUT="$SP_OUT  FAIL  self-probe $1
"; [ "$SP_VERBOSE" = 1 ] && printf '  FAIL  self-probe %s\n' "$1"; return 0; }
# sp_cell <label> <want rc> <want substring, or -> <fixture dir under SPR> [log]: judge in-process, assert both.
sp_cell() {
  local out got
  out="$(fxc_judge p "$SPR/$3/invocations.decl" "${4:-$SPR/log}" "$SPR")"; got=$?
  if [ "$got" != "$2" ]; then sp_bad "$1 (rc $got, want $2): $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; return; fi
  if [ "$5" != - ] && ! grep -qF -- "$5" <<<"$out"; then sp_bad "$1 (output lacks: $5)"; return; fi
  sp_ok "$1"
}
# THE C-ARM CELLS, both directions, run by fxc_self_probe after the J cells. <S> its scratch dir, <rc> the generated
# counter rc, <bash>. Every world is a fixture dir under $SPR judged in-process by sp_cell with the C arms on; the
# synthetic logs carry the rc's four fields (path, pid, FXCELL, parent pid), and one leg drives the REAL rc.
FXC_SP_CELLS=102
fxc_cells_self_probe() {
  local S="$1" rcf="$2" bash_bin="$3" T=$'\t' g out n
  FXC_CELLS=1
  mkdir -p "$SPR/core/scripts" || return 2
  printf '#!/usr/bin/env bash\nm() { :; }\n[ "${BASH_SOURCE[0]}" = "$0" ] || return 0\nm\n' > "$SPR/core/scripts/gsub.sh"
  printf '#!/usr/bin/env bash\necho "[ \\"${BASH_SOURCE[0]}\\" = \\"$0\\" ] || return 0"\n  [ "${BASH_SOURCE[0]}" = "$0" ] || return 0\n' > "$SPR/core/scripts/usub.sh"
  printf ':\n' > "$SPR/core/scripts/kid.sh"
  # cw <dir> <star> <gsub count> <kid count> <cells.decl body, or -> : one world; inputs require gsub, usub and kid.
  cw() { mkdir -p "$SPR/$1"; printf '!core/scripts/gsub.sh\n!core/scripts/usub.sh\n!core/scripts/kid.sh\n' > "$SPR/$1/inputs.decl"
    printf '%s *\n%s core/scripts/gsub.sh\n0 core/scripts/usub.sh\n%s core/scripts/kid.sh\n' "$2" "$3" "$4" > "$SPR/$1/invocations.decl"
    rm -f "$SPR/$1/cells.decl"; [ "$5" = - ] || printf '%s\n' "$5" | tr '|' '\n' > "$SPR/$1/cells.decl"; }
  cl() { printf '%s\n' "$@" > "$SPR/$CL"; }   # cl <rows...> into $SPR/$CL
  G="$SPR/core/scripts/gsub.sh"; K="$SPR/core/scripts/kid.sh"; R0="$SPR/x/run.sh${T}100${T}${T}"
  # C1: an untagged start in a fixture with NO cells.decl FIRES and names the missing file (a new fixture);
  # its quiet twin: no cells.decl and every subject row 0.
  cw cnew 2 1 0 -; CL=lc1; cl "$R0" "$G${T}101${T}${T}100"
  sp_cell "C1 an untagged subject start with no cells.decl FIRES and names the missing cells.decl" 1 cnew "$SPR/lc1" "p: FAIL (C1): core/scripts/gsub.sh started as a separate program with no FXCELL tag ($G) -- the fixture carries no cells.decl"
  cw czero 1 0 0 -; CL=lz; cl "$R0"
  sp_cell "C1 no cells.decl and no subject start stays QUIET" 0 czero "$SPR/lz" "ok C: p: 0 subject start(s), 0 tagged, 0 covered by a nested row"
  # C1 with cells.decl: the tagged twin passes, a mutant copy under the same suffix and a `..`-spelled start count,
  # the near-miss xgsub.sh does not.
  cw cok 2 1 0 'cli core/scripts/gsub.sh a'; CL=lok; cl "$R0" "$G${T}101${T}a${T}100"
  sp_cell "C1 a start tagged with its declared cli cell passes" 0 cok "$SPR/lok" "ok C: p: 1 subject start(s), 1 tagged, 0 covered by a nested row"
  cw cmut 3 2 0 'cli core/scripts/gsub.sh a'; CL=lmut; cl "$R0" "$G${T}101${T}a${T}100" "/elsewhere/m1/core/scripts/gsub.sh${T}102${T}${T}100"
  sp_cell "C1 an untagged mutant copy ending in the declared suffix FIRES" 1 cmut "$SPR/lmut" "p: FAIL (C1): core/scripts/gsub.sh started as a separate program with no FXCELL tag (/elsewhere/m1/core/scripts/gsub.sh)"
  cw cdd 3 2 0 'cli core/scripts/gsub.sh a'; CL=ldd; cl "$R0" "$G${T}101${T}a${T}100" "$SPR/core/fixtures/x/../../scripts/gsub.sh${T}102${T}${T}100"
  sp_cell "C1 an untagged ..-spelled start of the subject FIRES" 1 cdd "$SPR/ldd" "(C1): core/scripts/gsub.sh started"
  cw cnm 3 1 0 'cli core/scripts/gsub.sh a'; CL=lnm; cl "$R0" "$G${T}101${T}a${T}100" "$SPR/core/scripts/xgsub.sh${T}102${T}${T}100"
  sp_cell "C1 an untagged start of the near-miss xgsub.sh stays QUIET" 0 cnm "$SPR/lnm" "ok C: p: 1 subject start(s), 1 tagged"
  # C1 through a `bash -c` wrapper: the wrapper carries the tag (C2, no subject), the subject under it none (C1).
  cw cwr 3 1 0 'cli core/scripts/gsub.sh a'; CL=lwr; cl "$R0" "-c${T}101${T}a${T}100" "$G${T}102${T}${T}101"
  sp_cell "C1 a bash -c wrapper's tag leaves the subject untagged, which FIRES" 1 cwr "$SPR/lwr" "p: FAIL (C1): core/scripts/gsub.sh started as a separate program with no FXCELL tag ($G)"
  sp_cell "C2 the wrapper's tag names no subject start" 1 cwr "$SPR/lwr" "p: FAIL (C2): FXCELL=a names no declared cell (the tagged start, -c, is no subject of invocations.decl)"
  # nested: kid.sh started by a gsub.sh start, covered by a nested row; its twin without the row FIRES with the parent.
  cw cnest 3 1 1 'cli core/scripts/gsub.sh a|nested core/scripts/gsub.sh core/scripts/kid.sh why=gsub runs kid once per call'
  CL=lnest; cl "$R0" "$G${T}101${T}a${T}100" "$K${T}102${T}${T}101"
  sp_cell "C1 a child start covered by a nested row passes" 0 cnest "$SPR/lnest" "ok C: p: 2 subject start(s), 1 tagged, 1 covered by a nested row"
  cw cnest0 3 1 1 'cli core/scripts/gsub.sh a'
  sp_cell "C1 the same child start with no nested row FIRES naming its parent" 1 cnest0 "$SPR/lnest" "(C1): core/scripts/kid.sh started as a separate program with no FXCELL tag ($K, parent core/scripts/gsub.sh, no nested row covering it)"
  # A nested row whose parent is not the logged parent covers nothing: kid.sh started by run.sh directly.
  CL=lnestx; cl "$R0" "$G${T}101${T}a${T}100" "$K${T}102${T}${T}100"
  sp_cell "C1 a nested row does not cover a child whose parent is another start" 1 cnest "$SPR/lnestx" "(C1): core/scripts/kid.sh started"
  # The parent is the LATEST row with that pid: pid 101 is reused by a run.sh-level start after gsub.sh's exit.
  cw cnestr 4 1 1 'cli core/scripts/gsub.sh a|nested core/scripts/gsub.sh core/scripts/kid.sh why=gsub runs kid once per call'
  CL=lreuse; cl "$R0" "$G${T}101${T}a${T}100" "$SPR/x/other.sh${T}101${T}${T}100" "$K${T}102${T}${T}101"
  sp_cell "C1 a reused parent pid resolves to the start live at the child's log row" 1 cnestr "$SPR/lreuse" "(C1): core/scripts/kid.sh started"
  # C2: a tag naming no declared cell of that subject, and its declared twin.
  cw cc2 2 1 0 'cli core/scripts/gsub.sh a'; CL=lc2; cl "$R0" "$G${T}101${T}b${T}100"
  sp_cell "C2 an undeclared tag FIRES" 1 cc2 "$SPR/lc2" "p: FAIL (C2): FXCELL=b names no declared cell of core/scripts/gsub.sh"
  cw cc2k 2 1 0 'cli core/scripts/kid.sh b|cli core/scripts/gsub.sh a'; CL=lc2k; cl "$R0" "$G${T}101${T}b${T}100"
  sp_cell "C2 a tag declared for ANOTHER subject FIRES" 1 cc2k "$SPR/lc2k" "p: FAIL (C2): FXCELL=b names no declared cell of core/scripts/gsub.sh"
  # C3: one cell tagging two starts, a declared cell tagging none, and an e2e cell tagging one passes.
  cw cc3 3 2 0 'cli core/scripts/gsub.sh a'; CL=lc3; cl "$R0" "$G${T}101${T}a${T}100" "$G${T}102${T}a${T}100"
  sp_cell "C3 a cell tagging two starts FIRES" 1 cc3 "$SPR/lc3" "p: FAIL (C3): cell a of core/scripts/gsub.sh tagged 2 start(s); each declared cell tags exactly one"
  cw cc30 2 1 0 'cli core/scripts/gsub.sh a|e2e core/scripts/gsub.sh b why=the wiring'; CL=lc30; cl "$R0" "$G${T}101${T}a${T}100"
  sp_cell "C3 a declared cell tagging no start FIRES" 1 cc30 "$SPR/lc30" "p: FAIL (C3): cell b of core/scripts/gsub.sh tagged 0 start(s)"
  cw ce2e 3 2 0 'cli core/scripts/gsub.sh a|e2e core/scripts/gsub.sh b why=the wiring'; CL=le2e; cl "$R0" "$G${T}101${T}a${T}100" "$G${T}102${T}b${T}100"
  sp_cell "C3 a cli cell and an e2e cell each tagging one start pass" 0 ce2e "$SPR/le2e" "ok C: p: 2 subject start(s), 2 tagged"
  # THE STALE ALLOWLIST ROW, both directions: a listed fixture passing C1-C5 FAILs; listed and still failing C1 is
  # EXEMPT; listed and passing C1-C3 but its cli subject unguarded (C5) is EXEMPT too, never stale.
  local real="$FXC_INPROC_ALLOW"
  FXC_INPROC_ALLOW="$S/inproc-allow.txt"; printf '# probe\ncok\tseed\ncnew\tseed\ncu5\tseed\n' > "$FXC_INPROC_ALLOW"
  sp_cell "C stale a listed fixture that passes FAILs as stale" 1 cok "$SPR/lok" "p: FAIL (C stale): cok is a row of scripts/fixture-inprocess-allowlist.txt but now passes C1-C5"
  sp_cell "C stale a listed fixture still failing C1 is EXEMPT" 0 cnew "$SPR/lc1" "p: C EXEMPT, not judged: cnew is a row of scripts/fixture-inprocess-allowlist.txt (1 finding(s) held"
  cw cu5 2 0 0 'cli core/scripts/usub.sh a'; printf '2 *\n0 core/scripts/gsub.sh\n1 core/scripts/usub.sh\n0 core/scripts/kid.sh\n' > "$SPR/cu5/invocations.decl"
  CL=lu5; cl "$R0" "$SPR/core/scripts/usub.sh${T}101${T}a${T}100"
  sp_cell "C stale a listed fixture whose cli subject is unguarded (C5) is EXEMPT, not stale" 0 cu5 "$SPR/lu5" "p: C EXEMPT, not judged: cu5 is a row of scripts/fixture-inprocess-allowlist.txt (1 finding(s) held"
  FXC_INPROC_ALLOW="$real"
  # THE GRAMMAR (C2, C4), the parse the static validator calls through --cells-parse, both directions.
  printf '# c\n\ncli core/scripts/gsub.sh a\ne2e core/scripts/gsub.sh b why=the wiring\nnested core/scripts/gsub.sh core/scripts/kid.sh why=x y\n' > "$S/cg-ok"
  printf 'cli core/scripts/gsub.sh a\ne2e core/scripts/gsub.sh b why=\ne2e core/scripts/gsub.sh c why=   \nnested p k why=\ncli core/scripts/gsub.sh a\ncli core/scripts/gsub.sh bad/id\ncli s\nrun core/scripts/gsub.sh d\ne2e core/scripts/gsub.sh e because=x\n' > "$S/cg-bad"
  out="$(fxc_cells_parse "$S/cg-ok" "$S/cg-bad" "$S/cg-absent" 2>/dev/null)"
  n="$(grep -c '^F	' <<<"$out")" || n=0
  [ "$n" = 2 ] && sp_ok "C2 the parse opens each readable file once (2 of 3 named; the absent one prints no F row)" || sp_bad "C2 the parse printed $n F rows, want 2"
  g="$(awk -F'\t' '$1 == "R" && $2 ~ /cg-ok$/ { printf "%s:%s:%s:%s;", $3, $4, $5, $6 }' <<<"$out")"
  [ "$g" = "cli:core/scripts/gsub.sh:a:;e2e:core/scripts/gsub.sh:b:the wiring;nested:core/scripts/gsub.sh:core/scripts/kid.sh:x y;" ] \
    && sp_ok "C2 every valid row kind parses, comments and blanks skipped, the why= text kept" || sp_bad "C2 the valid rows parsed as [$g]"
  g="$(awk -F'\t' '$1 == "E" { printf "%s:%s;", $3, $4 }' <<<"$out")"
  [ "$g" = "2:C4;3:C4;4:C4;5:C2;6:C2;7:C2;8:C2;9:C2;" ] && sp_ok "C4 an empty or blank why= FIRES on e2e and nested rows; C2 a duplicate id, a bad id, a short row, an unknown kind and a missing why= FIRE" \
    || sp_bad "C2/C4 the malformed file reported [$g], want [2:C4;3:C4;4:C4;5:C2;6:C2;7:C2;8:C2;9:C2;]"
  grep -q '^R	[^	]*cg-bad	cli	core/scripts/gsub.sh	a	' <<<"$out" && sp_ok "C2 the first of a duplicated id is kept as a row" || sp_bad "C2 the first row of cg-bad was not kept"
  # C5's predicate, through --guarded's function: both statement forms count; a data string, an indented copy and a
  # comment do not.
  printf '#!/usr/bin/env bash\nif [ "${BASH_SOURCE[0]}" = "$0" ]; then\n  main\nfi\n' > "$S/g-if.sh"
  printf '# [ "${BASH_SOURCE[0]}" = "$0" ] || return 0\n' > "$S/g-cmt.sh"
  out="$(fxc_guarded "$SPR/core/scripts/gsub.sh" "$S/g-if.sh" "$SPR/core/scripts/usub.sh" "$S/g-cmt.sh")"
  g="$(awk -F'\t' '{ n = split($2, a, "/"); printf "%s:%s;", $1, a[n] }' <<<"$out")"
  [ "$g" = "G:gsub.sh;G:g-if.sh;U:usub.sh;U:g-cmt.sh;" ] && sp_ok "C5 both guard statements at column 0 count; a data string, an indented copy and a comment do not" \
    || sp_bad "C5 the guard predicate read [$g]"
  # A START SPELLED RELATIVE TO A cd'd DIRECTORY, through the REAL rc, run from $SPR: `( cd core && bash
  # scripts/gsub.sh )` and `( cd core/scripts && bash ./gsub.sh )`, beside the near-miss `./xgsub.sh`. FIRES: both
  # untagged relative starts are C1, and J3 counts all three gsub.sh starts; QUIET: the same starts tagged and declared.
  printf ':\n' > "$SPR/core/scripts/xgsub.sh"
  printf 'FXCELL=a bash core/scripts/gsub.sh\n( cd core && %sbash scripts/gsub.sh )\n( cd core/scripts && %sbash ./gsub.sh )\n( cd core/scripts && bash ./xgsub.sh )\n' '' '' > "$S/rel0.sh"
  printf 'FXCELL=a bash core/scripts/gsub.sh\n( cd core && %sbash scripts/gsub.sh )\n( cd core/scripts && %sbash ./gsub.sh )\n( cd core/scripts && bash ./xgsub.sh )\n' 'FXCELL=b ' 'FXCELL=c ' > "$S/rel1.sh"
  ( cd "$SPR" && env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/rel0.log" "$bash_bin" "$S/rel0.sh" ) >/dev/null 2>&1
  ( cd "$SPR" && env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/rel1.log" "$bash_bin" "$S/rel1.sh" ) >/dev/null 2>&1
  cw crel0 5 3 0 'cli core/scripts/gsub.sh a'
  sp_cell "C1 an untagged start spelled relative to a cd'd directory FIRES, and J3 counts it" 1 crel0 "$S/rel0.log" "(C1): core/scripts/gsub.sh started as a separate program with no FXCELL tag ($SPR/core/scripts/gsub.sh)"
  cw crel1 5 3 0 'cli core/scripts/gsub.sh a|cli core/scripts/gsub.sh b|cli core/scripts/gsub.sh c'
  sp_cell "C1 the same relative starts tagged and declared pass, and the near-miss ./xgsub.sh is no start of gsub.sh" 0 crel1 "$S/rel1.log" "ok C: p: 3 subject start(s), 3 tagged, 0 covered by a nested row"
  cw crelj 5 1 0 'cli core/scripts/gsub.sh a|cli core/scripts/gsub.sh b|cli core/scripts/gsub.sh c'
  sp_cell "J3 a row declaring only the root-relative start FAILs: the two cd-relative starts are counted" 1 crelj "$S/rel1.log" 'row "1 core/scripts/gsub.sh": measured 3, declared 1'
  # END TO END through the REAL rc: a tagged child logs its tag and its parent's pid; the grandchild it starts logs
  # an EMPTY tag (the trap unset FXCELL) and the child's pid; a bash -c wrapper logs `-c` with the tag.
  printf ':\n' > "$S/gc.sh"
  printf 'bash %s\n' "$S/gc.sh" > "$S/ch.sh"
  printf 'echo "$$" > %s\nFXCELL=a bash %s\nFXCELL=w bash -c ":"\n' "$S/top.pid" "$S/ch.sh" > "$S/top.sh"
  env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/cel.log" "$bash_bin" "$S/top.sh" >/dev/null 2>&1
  g="$(awk -F'\t' -v t="$S/top.sh" -v c="$S/ch.sh" -v gc="$S/gc.sh" -v tp="$(cat "$S/top.pid" 2>/dev/null)" '
    $1 == t { p[t] = $2; ok += (NF == 4 && $3 == "" && $4 == "" && $2 == tp) }
    $1 == c { p[c] = $2; ok += (NF == 4 && $3 == "a" && $4 == p[t]) }
    $1 == gc { ok += (NF == 4 && $3 == "" && $4 == p[c]) }
    $1 == "-c" { ok += (NF == 4 && $3 == "w" && $4 == p[t]) }
    END { print NR ":" ok + 0 }' "$S/cel.log" 2>/dev/null)"
  [ "$g" = "4:4" ] && sp_ok "E2E the real rc logs the tag and the parent pid, and a grandchild of a tagged start logs an empty tag" \
    || sp_bad "E2E the real rc's cell fields: rows:matched = $g, want 4:4"
  FXC_CELLS=1
}

fxc_self_probe() {
  local S fd bash_bin rcf
  S="$(mktemp -d "${TMPDIR:-/tmp}/fxc-sp.XXXXXX")" || { echo "FIXTURE BROKEN: self-probe cannot mktemp"; return 2; }
  S="$(cd "$S" && pwd -P)"
  # The J-arm cells below judge synthetic logs carrying no FXCELL tag; the C arms are judged only by the C cells.
  [ "$FXC_CELLS" = 1 ] && sp_ok "C the cells arms are on at entry (FXC_CELLS=1)" || sp_bad "C the cells arms were off at entry"
  FXC_CELLS=0
  SPR="$S/root"; fd="$SPR/f"
  mkdir -p "$fd" "$SPR/core/scripts" "$SPR/core/sub" || return 2
  printf ':\n' > "$SPR/core/scripts/sub.sh"; printf ':\n' > "$SPR/core/scripts/two.sh"
  printf '# probe\n!core/scripts/sub.sh\n+core/scripts/two.sh\n!core/sub/\n' > "$fd/inputs.decl"
  # Two starts of sub.sh (the declared path, and a mutant copy ending in the same suffix) and two near-misses a
  # suffix match without its `/` boundary, or a basename match, would count: xcore/scripts/sub.sh, core/scripts/xsub.sh.
  printf '%s\t1\n' "$SPR/f/run.sh" "$SPR/core/scripts/sub.sh" "/elsewhere/m1/core/scripts/sub.sh" "$SPR/xcore/scripts/sub.sh" "$SPR/core/scripts/xsub.sh" "-c" > "$SPR/log"
  : > "$SPR/empty"
  # J1 both directions
  SPN=j1; mkdir -p "$SPR/$SPN"; cp "$fd/inputs.decl" "$SPR/$SPN/"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/$SPN/invocations.decl"
  sp_cell "J1 absent log is BROKEN" 2 "$SPN" "$SPR/nolog" "(J1)"
  sp_cell "J1 empty log is BROKEN" 2 "$SPN" "$SPR/empty" "(J1)"
  sp_cell "J1 a 6-row log passes" 0 "$SPN" "$SPR/log" "6 start(s)"
  # J2 both directions
  mkdir -p "$SPR/j2"; cp "$fd/inputs.decl" "$SPR/j2/"
  sp_cell "J2 no declaration FAILs and prints the declaration" 1 j2 "$SPR/log" "  6 *"
  sp_cell "J2 the printed declaration carries the path row (suffix match, near-miss excluded)" 1 j2 "$SPR/log" "  2 core/scripts/sub.sh"
  printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j2/invocations.decl"
  sp_cell "J2 the printed declaration, written, passes" 0 j2 "$SPR/log" "ok"
  # NORMALISATION both directions, one start per log so each spelling is pinned alone (a sum could hide a swap).
  # Counted: `..` climbing out of the fixture dir, `.` and `//`, and a relative path whose `..` pops one segment and
  # climbs above its start, and an absolute `/../..` above the root (dropped, as the kernel does). Not counted: names CONTAINING `..` (`..b`, `x..`) that a loose rule would pop on, and a
  # real `..` that pops `scripts`, which a rule dropping `..` like `.` would count, and a `..` climbing above the
  # sandbox root onto a `scripts/sub.sh` that is not `core/scripts/sub.sh`.
  mkdir -p "$SPR/nrm1" "$SPR/nrm0"; cp "$fd/inputs.decl" "$SPR/nrm1/"; cp "$fd/inputs.decl" "$SPR/nrm0/"
  printf '2 *\n1 core/scripts/sub.sh\n' > "$SPR/nrm1/invocations.decl"; printf '2 *\n0 core/scripts/sub.sh\n' > "$SPR/nrm0/invocations.decl"
  for spec in "1:dotdot:$SPR/core/fixtures/f/../../scripts/sub.sh" "1:dot-and-slashes:$SPR/core/./scripts//sub.sh" \
              "1:relative-above-start:../../core/x/../scripts/sub.sh" "1:absolute-above-root:/../..$SPR/core/scripts/sub.sh" "0:name-dotdot-b:$SPR/core/scripts/q/..b/sub.sh" \
              "0:name-x-dotdot:$SPR/core/scripts/q/x../sub.sh" "0:dotdot-pops-scripts:$SPR/core/scripts/../sub.sh" \
              "0:climbs-above-root:$SPR/core/../../scripts/sub.sh"; do
    w="${spec%%:*}"; r="${spec#*:}"; l="${r%%:*}"; r="${r#*:}"
    printf '%s\t1\n' "$SPR/f/run.sh" "$r" > "$SPR/lognrm-$l"
    sp_cell "NRM $l counts $w" 0 "nrm$w" "$SPR/lognrm-$l" "ok"
  done
  # J6 both directions. The probe's sub.sh is a `.sh` with no shebang (in the population by its name). Seeded beside
  # it: shb (`#!/bin/sh`, no extension) and envb (`#!/usr/bin/env -S bash -e`, no extension), both bash by their
  # first line; pyx (`#!/usr/bin/env python3`, no extension), the near-miss a rule counting ANY shebang would take;
  # tool.py (no shebang) and data.md. The QUIET cells assert the printed out-of-population counts.
  printf '#!/bin/sh\n:\n' > "$SPR/core/scripts/shb"; printf '#!/usr/bin/env -S bash -e\n:\n' > "$SPR/core/scripts/envb"
  printf '#!/usr/bin/env python3\npass\n' > "$SPR/core/scripts/pyx"; printf 'pass\n' > "$SPR/core/tool.py"; printf '# d\n' > "$SPR/core/data.md"
  mkdir -p "$SPR/j6g" "$SPR/j6z" "$SPR/j6d" "$SPR/j6s" "$SPR/j6e" "$SPR/j6p"
  cp "$fd/inputs.decl" "$SPR/j6g/"; printf '6 *\n' > "$SPR/j6g/invocations.decl"
  sp_cell "J6 an unrowed .sh bash subject FIRES with its measured row" 1 j6g "$SPR/log" "p: FAIL (J6): core/scripts/sub.sh is a \`!\` bash subject with no invocations.decl row -- row to add, measured on this run: 2 core/scripts/sub.sh"
  { cat "$fd/inputs.decl"; printf '!core/scripts/shb\n'; } > "$SPR/j6z/inputs.decl"; printf '6 *\n2 core/scripts/sub.sh\n0 core/scripts/shb\n' > "$SPR/j6z/invocations.decl"
  sp_cell "J6 a 0 <path> row on an unstarted bash subject stays QUIET" 0 j6z "$SPR/log" "J6: p: 2 bash subject(s) rowed; outside the population: 0 data file(s), 0 non-shell script(s)"
  { cat "$fd/inputs.decl"; printf '!core/data.md\n!core/tool.py\n!core/scripts/pyx\n'; } > "$SPR/j6d/inputs.decl"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j6d/invocations.decl"
  sp_cell "J6 unrowed data files and non-shell scripts (a python shebang included) stay QUIET and are counted" 0 j6d "$SPR/log" "J6: p: 1 bash subject(s) rowed; outside the population: 1 data file(s), 2 non-shell script(s)"
  { cat "$fd/inputs.decl"; printf '!core/scripts/shb\n'; } > "$SPR/j6s/inputs.decl"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j6s/invocations.decl"
  sp_cell "J6 an unrowed sh-shebang file with no .sh FIRES" 1 j6s "$SPR/log" "p: FAIL (J6): core/scripts/shb is a"
  { cat "$fd/inputs.decl"; printf '!core/scripts/envb\n'; } > "$SPR/j6e/inputs.decl"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j6e/invocations.decl"
  sp_cell "J6 an unrowed env-bash-shebang file with no .sh FIRES" 1 j6e "$SPR/log" "p: FAIL (J6): core/scripts/envb is a"
  { cat "$fd/inputs.decl"; printf '!core/scripts/shb\n'; } > "$SPR/j6p/inputs.decl"
  sp_cell "J2 prints an unstarted bash subject's 0 row, so the printed declaration passes J6" 1 j6p "$SPR/log" "  0 core/scripts/shb"
  # THE STATIC CENSUS both directions, on its own root: fixture a lacks its sub.sh row, b carries it, u is undeclarable.
  local CR="$S/croot" cout crc
  mkdir -p "$CR/core/fixtures/a" "$CR/core/fixtures/b" "$CR/core/fixtures/u" "$CR/core/scripts" "$S/cempty/core/fixtures/x"
  printf ':\n' > "$CR/core/scripts/sub.sh"
  for d in a b u; do printf ':\n' > "$CR/core/fixtures/$d/run.sh"; done
  printf '!core/scripts/sub.sh\n' > "$CR/core/fixtures/a/inputs.decl"; cp "$CR/core/fixtures/a/inputs.decl" "$CR/core/fixtures/b/"
  printf '1 *\n' > "$CR/core/fixtures/a/invocations.decl"; printf '1 *\n0 core/scripts/sub.sh\n' > "$CR/core/fixtures/b/invocations.decl"
  : > "$CR/core/fixtures/u/.undeclarable"
  cout="$(fxc_census "$CR")"; crc=$?
  [ "$crc" = 1 ] && grep -qxF 'B2 GAP a core/scripts/sub.sh' <<<"$cout" && sp_ok "B2-CENSUS an unrowed bash subject is a GAP (rc 1)" || sp_bad "B2-CENSUS the unrowed subject of a: rc $crc, out: $(printf '%s' "$cout" | tr '\n' ' ')"
  grep -q '^B2 GAP b ' <<<"$cout" && sp_bad "B2-CENSUS fixture b's 0 row was reported a GAP" || sp_ok "B2-CENSUS a 0 <path> row is no GAP"
  grep -qxF 'EXEMPT (undeclarable) u' <<<"$cout" && grep -qF '3 fixture(s) scanned; 1 EXEMPT (undeclarable), 0 UNDECLARED; 1 gap(s) over 1 fixture(s); 1 bash subject(s) rowed' <<<"$cout" \
    && sp_ok "B2-CENSUS an undeclarable fixture prints EXEMPT (undeclarable) and the counts" || sp_bad "B2-CENSUS the EXEMPT line or the count line: $(printf '%s' "$cout" | tr '\n' ' ')"
  cout="$(fxc_census "$S/cempty")"; crc=$?
  [ "$crc" = 2 ] && grep -qF 'REFUSED: no core/fixtures/*/run.sh' <<<"$cout" && sp_ok "B2-CENSUS a root with no run.sh is REFUSED (rc 2)" || sp_bad "B2-CENSUS an empty corpus: rc $crc"
  # J3 both directions, `*`, path and corpus rows
  mkdir -p "$SPR/j3a" "$SPR/j3b" "$SPR/j3c" "$SPR/j3d"; for d in j3a j3b j3c j3d; do cp "$fd/inputs.decl" "$SPR/$d/"; done
  printf '4 *\n2 core/scripts/sub.sh\n' > "$SPR/j3a/invocations.decl"
  sp_cell "J3 a * row off by one FAILs with measured, declared and the remedy" 1 j3a "$SPR/log" "measured 6, declared 4 -- if this change was meant to alter how often the fixture runs its subject, set the row to 6; $FXC_REMEDY_TAIL"
  printf '6 *\n3 core/scripts/sub.sh\n' > "$SPR/j3b/invocations.decl"
  sp_cell "J3 a path row counting the near-miss xsub.sh FAILs" 1 j3b "$SPR/log" "measured 2, declared 3"
  printf '2+2xcore/scripts/*.sh *\n2 core/scripts/sub.sh\n' > "$SPR/j3c/invocations.decl"
  sp_cell "J3 a corpus row 2+2x(2 files) = 6 passes" 0 j3c "$SPR/log" "ok"
  printf '3+2xcore/scripts/*.sh *\n2 core/scripts/sub.sh\n' > "$SPR/j3d/invocations.decl"
  sp_cell "J3 a corpus row 3+2x(2 files) = 7 FAILs" 1 j3d "$SPR/log" "measured 6, declared 7"
  printf '6+0xcore/nomatch/*.sh *\n2 core/scripts/sub.sh\n' > "$SPR/j3d/invocations.decl"
  sp_cell "J3 a corpus glob matching nothing counts 0, not 1 (the literal pattern)" 0 j3d "$SPR/log" "ok"
  # J4 both directions
  for spec in "bad:five *" "nostar:2 core/scripts/sub.sh" "twostar:6 *|6 *" "dup:6 *|2 core/scripts/sub.sh|2 core/scripts/sub.sh" \
              "notbang:6 *|0 core/scripts/two.sh" "dirbang:6 *|0 core/sub" "threecol:6 * extra" "absglob:1+1x/etc/* *" \
              "lz:06 *" "lzc:2+02xcore/scripts/*.sh *"; do
    SPN="j4${spec%%:*}"; mkdir -p "$SPR/$SPN"; cp "$fd/inputs.decl" "$SPR/$SPN/"
    printf '%s\n' "${spec#*:}" | tr '|' '\n' > "$SPR/$SPN/invocations.decl"
    sp_cell "J4 ${spec%%:*} FAILs" 1 "$SPN" "$SPR/log" "(J4)"
  done
  mkdir -p "$SPR/j4ok"; cp "$fd/inputs.decl" "$SPR/j4ok/"; printf '# c\n\n6 *\n2 core/scripts/sub.sh\n' > "$SPR/j4ok/invocations.decl"
  sp_cell "J4 comments, blanks, one * and one ! path row pass" 0 j4ok "$SPR/log" "ok"
  # The leading-zero near-miss: a bare 0 count, a 0+ base and a glob carrying `+0`/`05` digits stay legal.
  mkdir -p "$SPR/core/x+05" && printf ':\n' > "$SPR/core/x+05/a.sh"
  mkdir -p "$SPR/j4z"; cp "$fd/inputs.decl" "$SPR/j4z/"; printf '0+6xcore/x+05/*.sh *\n2 core/scripts/sub.sh\n' > "$SPR/j4z/invocations.decl"
  sp_cell "J4 a 0+k base, and a glob carrying +05, pass (a leading zero is refused only in a count)" 0 j4z "$SPR/log" "ok"
  # There is no tolerance row: every `±` spelling is a malformed row (J4), the retired full form included, and a
  # row the old form would have passed (in: 5±2 against a measured 6) is refused. The log measures 6 starts and 2 of
  # sub.sh. The `exact` seed is the near-miss: a plain count off by one is J3, never J4.
  for spec in "in:5±2 * why=poll provisional|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 5±2 * why=poll provisional" \
              "edge:8±2 * why=poll provisional|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 8±2 * why=poll provisional" \
              "out:9±2 * why=poll provisional|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 9±2 * why=poll provisional" \
              "path:6 *|4±2 core/scripts/sub.sh why=retry provisional:1:(J4): malformed invocations.decl row: 4±2 core/scripts/sub.sh why=retry provisional" \
              "nowhy:6±2 * because=poll provisional|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 6±2 * because=poll provisional" \
              "noprov:6±2 * why=poll|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 6±2 * why=poll" \
              "k1:6±1 * why=poll provisional|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 6±1 * why=poll provisional" \
              "badn:6x±2 * why=poll provisional|2 core/scripts/sub.sh:1:(J4): malformed invocations.decl row: 6x±2 * why=poll provisional" \
              "exact:5 *|2 core/scripts/sub.sh:1:measured 6, declared 5"; do
    SPN="tol${spec%%:*}"; r="${spec#*:}"; want="${r#*:}"; want="${want#*:}"; wrc="${r#*:}"; wrc="${wrc%%:*}"; r="${r%%:*}"
    mkdir -p "$SPR/$SPN"; cp "$fd/inputs.decl" "$SPR/$SPN/"
    printf '%s\n' "$r" | tr '|' '\n' > "$SPR/$SPN/invocations.decl"
    sp_cell "J4 ± seed ${spec%%:*}" "$wrc" "$SPN" "$SPR/log" "$want"
  done
  # J5 both directions, a header, a shard stub, a control
  mkdir -p "$SPR/j5" "$SPR/j5s" "$SPR/j5c"
  for d in j5 j5s j5c; do cp "$fd/inputs.decl" "$SPR/$d/"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/$d/invocations.decl"; done
  cp "$SPR/log" "$SPR/logm"; printf 'Ma\nMb\nMa\n' > "$SPR/logm.mutants"
  printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\n# MUTANT-MATRIX-REMEASURE x\n' > "$SPR/j5/run.sh"
  sp_cell "J5 an unrowed reported name FAILs" 1 j5 "$SPR/logm" "reported Mb, which has no"
  printf '# MUTANT-MATRIX-FULL Mb worlds=w1,w2 why=x\n' >> "$SPR/j5/run.sh"
  sp_cell "J5 every reported name rowed passes" 0 j5 "$SPR/logm" "ok"
  printf '#!/usr/bin/env bash\nHERE="$(cd "$(dirname "$0")" && pwd)"\nIMPL="$HERE/../j5/run.sh"\nexec bash "$IMPL" --group b\n' > "$SPR/j5s/run.sh"
  sp_cell "J5 a shard stub joins its IMPL's rows" 0 j5s "$SPR/logm" "ok"
  printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\n# MUTANT-MATRIX-CONTROL Mb why=x\n' > "$SPR/j5c/run.sh"
  sp_cell "J5 a reported name with a CONTROL row FAILs" 1 j5c "$SPR/logm" "MUTANT-MATRIX-CONTROL row"
  # J5 on a pass prints its count of distinct names (logm reports Ma, Mb, Ma); no emission prints 0.
  mkdir -p "$SPR/j5ok"; cp "$fd/inputs.decl" "$SPR/j5ok/"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j5ok/invocations.decl"
  printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\n# MUTANT-MATRIX Mb decides=A twins=B\n' > "$SPR/j5ok/run.sh"
  sp_cell "J5 a pass with 2 rowed names prints its ok line with the count" 0 j5ok "$SPR/logm" "ok J5: p: 2 name(s) joined"
  sp_cell "J5 a run with no mutant_killed emission prints the 0 line" 0 j5ok "$SPR/log" "ok J5: p: 0 name(s) (no mutant_killed emission)"
  # A row inside a heredoc body is a seed, not the header: Mb rowed only there FAILs (its twin, rowed in code, passed above).
  mkdir -p "$SPR/j5h"; cp "$fd/inputs.decl" "$SPR/j5h/"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j5h/invocations.decl"
  printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\ncat > p <<'"'"'EOF'"'"'\n# MUTANT-MATRIX Mb decides=A twins=B\nEOF\n' > "$SPR/j5h/run.sh"
  sp_cell "J5 a name rowed only inside a heredoc body FAILs" 1 j5h "$SPR/logm" "reported Mb, which has no"
  # Its twin: the heredoc CLOSES, and `$((1<<3))` and `<<<` open nothing, so Mb rowed after all three counts.
  printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\ncat > p <<'"'"'EOF'"'"'\nseed\nEOF\nx=$((1<<3))\ncat <<<"x"\n# MUTANT-MATRIX Mb decides=A twins=B\n' > "$SPR/j5h/run.sh"
  sp_cell "J5 a name rowed after a closed heredoc, a shift and a here-string passes" 0 j5h "$SPR/logm" "ok"
  # A non-exec shard stub (`bash "$IMPL" --group x > out`, the ledger-reverify-b form) resolves to its IMPL too.
  mkdir -p "$SPR/j5n"; cp "$fd/inputs.decl" "$SPR/j5n/"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j5n/invocations.decl"
  printf '#!/usr/bin/env bash\nHERE="$(cd "$(dirname "$0")" && pwd)"\nIMPL="$HERE/../j5/run.sh"\nbash "$IMPL" --group b > "$HERE/o"\n' > "$SPR/j5n/run.sh"
  sp_cell "J5 a non-exec shard stub joins its IMPL's rows" 0 j5n "$SPR/logm" "ok"
  # The allowlist exemption, both ways. Each world reports Mb with no row for it, so only the exemption passes it.
  mkdir -p "$SPR/heldfx" "$SPR/heldfx2" "$SPR/heldst"
  for d in heldfx heldfx2 heldst; do cp "$fd/inputs.decl" "$SPR/$d/"; printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/$d/invocations.decl"
    printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\n' > "$SPR/$d/run.sh"; done
  printf '#!/usr/bin/env bash\nHERE="$(cd "$(dirname "$0")" && pwd)"\nIMPL="$HERE/../heldfx/run.sh"\nexec bash "$IMPL" --group b\n' > "$SPR/heldst/run.sh"
  local fxc_allow_real="$FXC_ALLOW"
  FXC_ALLOW="$S/allow.txt"; printf '# probe allowlist\nheldfx\tS1 a mutation helper\n' > "$FXC_ALLOW"
  sp_cell "J5 a fixture on the allowlist is EXEMPT, with a printed line" 0 heldfx "$SPR/logm" "heldfx is a row of scripts/fixture-matrix-allowlist.txt"
  sp_cell "J5 a stub of an allowlisted IMPL is EXEMPT" 0 heldst "$SPR/logm" "J5 EXEMPT, not judged: heldfx"
  sp_cell "J5 a fixture whose name only shares a prefix with a row (heldfx2) FAILs" 1 heldfx2 "$SPR/logm" "reported Mb, which has no"
  FXC_ALLOW="$S/absent-allow.txt"
  sp_cell "J5 an absent allowlist exempts nothing" 1 heldfx "$SPR/logm" "reported Mb, which has no"
  FXC_ALLOW="$fxc_allow_real"
  # END TO END through the generated rc. Every child bash is under env -i; the invoker exports BASH_ENV and
  # FXCOUNT_LOG naming the probe's own files, so the no-passthrough leg's zero is a statement about env -i.
  bash_bin="${BASH:-/bin/bash}"
  rcf="$(fxc_gen_rc "$S/rc")" || { sp_bad "E2E the rc file could not be generated"; rcf=/nonexistent; }
  printf ':\n' > "$S/inner.sh"
  printf 'bash -c :\nx="$(bash %s)"\nbash %s\necho done\n' "$S/inner.sh" "$S/inner.sh" > "$S/known.sh"
  env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/e1.log" "$bash_bin" "$S/known.sh" >/dev/null 2>&1
  n="$(awk 'END { print NR }' "$S/e1.log" 2>/dev/null)" || n=0
  [ "$n" = 4 ] && sp_ok "E2E with the passthrough a known script logs its 4 starts" || sp_bad "E2E with the passthrough logged ${n:-0} starts, want 4"
  ( export BASH_ENV="$rcf" FXCOUNT_LOG="$S/e2.log"; env -i PATH="/usr/bin:/bin" "$bash_bin" "$S/known.sh" >/dev/null 2>&1 )
  if [ -e "$S/e2.log" ]; then sp_bad "E2E without the passthrough the counter still logged ($(awk 'END { print NR }' "$S/e2.log") rows)"
  else sp_ok "E2E without the passthrough (both variables exported in the invoker) env -i logs nothing"; fi
  env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/e3.log" "$bash_bin" -x "$S/known.sh" > /dev/null 2> "$S/on.err"
  env -i PATH="/usr/bin:/bin" "$bash_bin" -x "$S/known.sh" > /dev/null 2> "$S/off.err"
  if [ -s "$S/e3.log" ] && [ -s "$S/off.err" ] && cmp -s "$S/on.err" "$S/off.err"; then sp_ok "E2E xtrace stderr is byte-identical with the counter on and off, and the counter-on run logged"
  else sp_bad "E2E xtrace: stderr differs with the counter on, or the counter-on run logged nothing"; fi
  # A start under `ulimit -f 0` that writes a file: the same stdout and exit with the counter on and off, under both XFSZ
  # dispositions (default: the write kills it, rc 153; ignored: the write fails rc 1), and the counter-on start counted.
  # Stdout goes to a pipe, which no file-size limit binds, so the comparison sees a row the old trap flushed onto it.
  printf 'echo first\nprintf "x\\n" > "$1"\necho "write rc=$?"\n' > "$S/lim.sh"
  local lim_ok=1 lim_n=0 dsp tag
  for dsp in dfl ign; do
    for tag in off on; do
      if [ "$tag" = on ]; then set -- BASH_ENV="$rcf" FXCOUNT_LOG="$S/lim-$dsp.log"; else set --; fi
      ( [ "$dsp" = ign ] && trap '' XFSZ; ulimit -f 0
        env -i PATH="/usr/bin:/bin" "$@" "$bash_bin" "$S/lim.sh" "$S/lim-$dsp-$tag.t" 2>/dev/null; echo "exit=$?" ) 2>/dev/null | cat > "$S/lim-$dsp-$tag.out"
    done
    grep -qx first "$S/lim-$dsp-off.out" || lim_ok=0
    cmp -s "$S/lim-$dsp-off.out" "$S/lim-$dsp-on.out" || lim_ok=0
  done
  grep -qx 'exit=153' "$S/lim-dfl-off.out" && grep -qx 'write rc=1' "$S/lim-ign-off.out" || lim_ok=0
  [ "$lim_ok" = 1 ] && sp_ok "E2E a start under ulimit -f 0 writing a file is killed (default XFSZ) or refused (ignored) identically with the counter on and off" \
    || sp_bad "E2E under ulimit -f 0 the counter changed what the start observes: off [$(tr '\n' ' ' < "$S/lim-dfl-off.out")| $(tr '\n' ' ' < "$S/lim-ign-off.out")] on [$(tr '\n' ' ' < "$S/lim-dfl-on.out")| $(tr '\n' ' ' < "$S/lim-ign-on.out")]"
  mkdir -p "$SPR/lim"; cp "$fd/inputs.decl" "$SPR/lim/"; printf '1 *\n0 core/scripts/sub.sh\n' > "$SPR/lim/invocations.decl"
  sp_cell "E2E a start under ulimit -f 0, default XFSZ, is counted (1 start)" 0 lim "$S/lim-dfl.log" "1 start(s)"
  sp_cell "E2E a start under ulimit -f 0, XFSZ ignored, is counted (1 start)" 0 lim "$S/lim-ign.log" "1 start(s)"
  # Near-miss: under the same limit a READ-ONLY log, and an EMPTY FXCOUNT_LOG, leave no marker anywhere.
  mkdir -p "$S/ro" "$S/cwd"; : > "$S/ro/log"; chmod a-w "$S/ro/log"
  ( trap '' XFSZ; ulimit -f 0; cd "$S/cwd" && env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/ro/log" "$bash_bin" "$S/lim.sh" "$S/ro.t" ) >/dev/null 2>&1 | cat
  ( trap '' XFSZ; ulimit -f 0; cd "$S/cwd" && env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="" "$bash_bin" "$S/lim.sh" "$S/em.t" ) >/dev/null 2>&1 | cat
  chmod u+w "$S/ro/log"
  if [ -z "$(ls -A "$S/cwd")" ] && [ "$(ls "$S/ro" | grep -c '\.lim\.')" = 0 ]; then
    sp_ok "E2E under ulimit -f 0 a read-only log and an empty FXCOUNT_LOG leave no marker beside the log or in the cwd"
  else sp_bad "E2E a read-only or empty log left a marker: cwd [$(ls -A "$S/cwd" | tr '\n' ' ')] ro [$(ls "$S/ro" | tr '\n' ' ')]"; fi
  # The seeded loop through the REAL mutant.sh: an unrowed name FAILs J5, the same loop rowed passes.
  local mlib="${FXC_SELF%/scripts/*}/core/fixtures/lib/mutant.sh"
  if [ ! -f "$mlib" ]; then sp_bad "E2E the real core/fixtures/lib/mutant.sh is absent beside this script ($mlib)"
  else
    mkdir -p "$SPR/lp"; cp "$fd/inputs.decl" "$SPR/lp/"; printf '2 *\n0 core/scripts/sub.sh\n' > "$SPR/lp/invocations.decl"
    printf 'ok() { :; }\nbad() { :; }\n. %s\nfor m in La Lb; do mutant_killed 1 "$m" x; done\nbash -c :\n' "$mlib" > "$SPR/lp/loop.sh"
    env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/lp.log" "$bash_bin" "$SPR/lp/loop.sh" >/dev/null 2>&1
    printf '#!/usr/bin/env bash\n# MUTANT-MATRIX La decides=A twins=B\n' > "$SPR/lp/run.sh"
    sp_cell "E2E a loop reporting an unrowed name through mutant_killed FAILs J5" 1 lp "$S/lp.log" "reported Lb, which has no"
    printf '# MUTANT-MATRIX Lb decides=A twins=B\n' >> "$SPR/lp/run.sh"
    sp_cell "E2E the same loop with its row passes" 0 lp "$S/lp.log" "ok"
  fi
  fxc_cells_self_probe "$S" "$rcf" "$bash_bin"
  rm -rf "$S"
  # The cell count is fixed by construction above; fewer means a cell was skipped without a verdict.
  [ "$SP_N" -eq "$FXC_SP_CELLS" ] || { SP_FAIL=1; SP_OUT="$SP_OUT  FAIL  self-probe ran $SP_N cells, want $FXC_SP_CELLS
"; }
  [ "$SP_FAIL" = 0 ] && return 0
  return 2
}

# ---------------------------------------------------------------------------------------------------------------
FXC_FX=""; FXC_DECL=""; FXC_LOG=""; FXC_ROOT=""
case "${1:-}" in
  --impl-of) shift; fxc_impl_of "$@"; exit $? ;;
  --cells-parse) shift; fxc_cells_parse "$@"; exit $? ;;
  --guarded) shift; fxc_guarded "$@"; exit 0 ;;
  --static-join)
    [ -n "${2:-}" ] && [ -d "$2/core/fixtures" ] || { echo "usage: $0 --static-join <root>" >&2; exit 2; }
    fxc_static_join "$2"; exit $? ;;
  --gen-rc) [ $# -eq 2 ] || { echo "usage: $0 --gen-rc <dir>" >&2; exit 2; }; fxc_gen_rc "$2"; exit $? ;;
  --self-probe)
    SP_VERBOSE=1; fxc_self_probe; r=$?
    if [ "$r" = 0 ]; then printf 'self-probe: %s cells, all green\n' "$SP_N"; exit 0; fi
    printf 'self-probe: FIXTURE BROKEN\n'; exit 2 ;;
  --b2-census)
    FXC_ROOT="${FXC_SELF%/scripts/*}"
    [ "${2:-}" = --root ] && { [ -n "${3:-}" ] || { echo "usage: $0 --b2-census [--root R]" >&2; exit 2; }; FXC_ROOT="$3"; }
    [ -d "$FXC_ROOT/core/fixtures" ] || { echo "b2-census: REFUSED: no core/fixtures under $FXC_ROOT" >&2; exit 2; }
    fxc_self_probe || { printf 'b2-census: REFUSED: the self-probe is red\n%s' "$SP_OUT"; exit 2; }
    fxc_census "$FXC_ROOT"; exit $? ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --fixture) FXC_FX="${2:-}"; shift 2 ;;
    --decl) FXC_DECL="${2:-}"; shift 2 ;;
    --log) FXC_LOG="${2:-}"; shift 2 ;;
    --root) FXC_ROOT="${2:-}"; shift 2 ;;
    *) echo "validate-fixture-invocations: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$FXC_FX" ] && [ -n "$FXC_DECL" ] && [ -n "$FXC_LOG" ] && [ -n "$FXC_ROOT" ] \
  || { echo "usage: $0 --fixture F --decl D --log L --root R | --self-probe | --gen-rc DIR" >&2; exit 2; }
fxc_judge "$FXC_FX" "$FXC_DECL" "$FXC_LOG" "$FXC_ROOT"
exit $?
