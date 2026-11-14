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
# mutant_killed name appended to `<log>.mutants` under the limit is lost (J5 sees fewer names, never a false FAIL); an fx_inproc row appended to `<log>.inproc` under the limit is lost
# too, and there the `inproc:` row reads LOW and FAILs J3 -- a false FAIL, never an acquittal.
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
#   <count> inproc:<path>  (BL-982, THE IN-PROCESS PASSES) <path> is a `!` line of inputs.decl, root-relative, no `..`, the
#                          count plain (no `c+kxglob`). It counts the rows core/fixtures/lib/mutant.sh's fx_inproc appended
#                          to <log>.inproc -- one per pass that SOURCES the subject and calls it, which starts no bash
#                          and so never reaches the start log -- matched as a path row matches a start (normalised, equal
#                          or ending in /<path>); a missing <log>.inproc counts 0. It is carried by fxc_decl_rows as its
#                          own row kind, so it never satisfies J6, J4's `!`-line check of a path row, or C2's path-row
#                          lookup, and a fixture whose subject is both started and sourced carries both rows.
#                          OPT-IN: a fixture with no `inproc:` row and no logged row is judged exactly as before -- no
#                          inproc arm runs or prints. hermetic-run.sh truncates <log>.inproc when armed, so the gate reads
#                          a NON-EMPTY log, never its existence.
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
#   J3 on an `inproc:` row  the count of <log>.inproc rows for its path != declared -> FAIL (the same J3 message).
#   J4 on an `inproc:` row  malformed (a glob count, an absolute or `..` path, an empty path), a path that is no `!`
#       file line, or one path on two `inproc:` rows -> FAIL.
#   J7  (BL-982, R1) every row fx_inproc logged must match an `inproc:` row's path, else FAIL naming the paths; and
#       rows logged by a fixture whose declaration carries NO `inproc:` row FAIL too, so a fixture cannot opt itself
#       out of counting by deleting its row while it still logs. Passing, an opted-in fixture prints `ok J7: ...`.
#       Its match reuses fxc_cells_judge's longest-target match (no cells declared: every matched row is a C1 row).
#   P2  (BL-982 (b); static, --static-join, so validate-fixture-inprocess.sh FAILs it as a join E row whether or not
#       the fixture is allowlisted, when its ratchet reads the row NEW against the push base; an owed row prints) in EVERY
#       declared fixture, opted in or not, every in-process drive of a declared
#       bash subject -- a call of a guarded subject's entry function, a source of an unguarded one -- is paired with an
#       fx_inproc call. P2 SUBSUMES P1, the opted-in-only arm it replaces, and keeps P1's pairing rule; the id P1 is
#       retired. Counting unit, population, operands, masking, blind routes and false-positive floor: ARM P2 above
#       fxc_p2_scan.
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
#   B6  a SOURCED subject is not a start; it is counted only where the drive calls fx_inproc and the fixture declares an
#       `inproc:` row (J3, J7), and P2 binds the drive to the call in every declared fixture. B7 a subshell, `( )` or `$( )` without a new bash, is not a start.
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
#
# THE JUDGE'S IDENTITY IS A FORMAT VERSION, NOT A HASH OF ITS BYTES. A counted verdict-store entry carries one
# `#judge f<FXC_FORMAT> <J5 key> <listed|unlisted>` row for its fixture (--key-rows, read by the hook's READSET_VS
# span), and the counted store is named for FXC_FORMAT alone, so a judge or allowlist edit re-runs only the fixtures
# whose row it moves. FXC_FORMAT changes only when what the judge DECIDES for a fixture changes. Every semantic sha of
# this file (comment and blank lines dropped, readset_span_sha's rule) is pinned on one row,
# `# FXC-IDENTITY <format> <sha> <reason>`; --identity-check, run by the hook's fxcount_arm, fails arming when the
# current sha has no row or its row names a format other than FXC_FORMAT. A code edit adds a row: under the CURRENT
# format when no fixture's judgement moves (counted entries stay valid), else under a bumped FXC_FORMAT (every
# counted entry re-runs).
# FXC-IDENTITY 1 cc011bb8430f348d037ed2a565be3f493f1074da7f072c919c65ef67776784ad the per-fixture judge row (BL-1057)
# FXC-IDENTITY 1 f4035938f576baa486a7c6acd4b69d429eb974eecac63c27277279fb6af02691 cost only: per-row forks cut, C5's guard table built once, the --b2-census self-probe memoised (BL-1065); every output byte-identical
set -u
FXC_FORMAT=1

FXC_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
FXC_REMEDY_TAIL="otherwise this is the regrowth fixture-mutants.md 'One run per distinct state' forbids"
# C5's two guard statements, ONE spelling read by fxc_guarded and by P2's scan (which stops collecting a subject's
# entry functions at the first of them).
FXC_GUARD_A='[ "${BASH_SOURCE[0]}" = "$0" ] || return 0'
FXC_GUARD_B='if [ "${BASH_SOURCE[0]}" = "$0" ]; then'

# THE HEREDOC TRACKER, one awk function string read by fxc_mutant_rows (J5) and by P2's scan; never copied. A heredoc
# body is data. A `<<` outside quotes on a non-comment line, not `<<<`, opens a body whose delimiter is the next word
# (quoted, backslashed or bare; `<<-` strips leading tabs); a word that cannot start a name opens nothing; several
# heredocs on one line close in order. NO BODY OPENS INSIDE `((` OR `$((` (hd_arith masks the arithmetic span first):
# `$((1<<n))` and `(( m = 1 << k ))` once opened a body delimited by `n`/`k`, which swallowed the rest of
# shell-portability/run.sh from its line 1387, MUTANT-MATRIX rows included. The caller passes -v SQ=<apostrophe>,
# calls hd_body(line) first (1: a body or delimiter line, consumed) and opens(line) on every other line -- or
# opens_m(line, mask) with its own same-length mask, as P2 does with its cross-line one (a `<<` inside a multi-line
# string opens nothing there). opens is opens_m over this file's line-local qmask.
FXC_HEREDOC_AWK='
function qmask(s,   o, i, n, c, q) {
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
function hd_arith(m,   o, i, j, n, d, c) {
  if (index(m, "((") == 0) return m
  o = ""; n = length(m)
  for (i = 1; i <= n; i++) {
    if (substr(m, i, 2) != "((") { o = o substr(m, i, 1); continue }
    o = o "(("; d = 2
    for (j = i + 2; j <= n && d > 0; j++) { c = substr(m, j, 1); if (c == "(") d++; else if (c == ")") d--; o = o ((c == ")" && d < 2) ? ")" : "X") }
    i = j - 1
  }
  return o
}
function opens(s) { if (index(s, "<<") > 0) opens_m(s, hd_arith(qmask(s))) }
function opens_m(s, m,   p, r, c, w, dash) {
  if (index(m, "<<") == 0) return
  p = 0
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
function hd_body(s,   l) {
  if (!(HN > 0 && HI > 0)) return 0
  l = s; if (HD[HI]) sub(/^\t+/, "", l); if (l == HW[HI]) { HI++; if (HI > HN) { HN = 0; HI = 0 } }
  return 1
}
'

fxc_gen_rc() { # <dir>: write <dir>/fxcount.rc, print its path
  mkdir -p "$1" || return 2
  cat > "$1/fxcount.rc" <<'RC' || return 2
{ trap '{ trap - DEBUG; trap "" XFSZ; __fxcp="${BASH_SOURCE[0]:-${BASH_EXECUTION_STRING:+-c}}"; case "$__fxcp" in /*|-c|"") ;; *) __fxcp="$PWD/$__fxcp" ;; esac; printf "%s\t%s\t%s\t%s\n" "$__fxcp" "$$" "${FXCELL:-}" "${FXCOUNT_PARENT:-}" >> "$FXCOUNT_LOG" || { echo > /dev/null; [ -w "$FXCOUNT_LOG" ] && /bin/ln -s "$__fxcp	$$	${FXCELL:-}	${FXCOUNT_PARENT:-}" "$(/usr/bin/mktemp -u "$FXCOUNT_LOG.lim.XXXXXXXX")"; }; unset __fxcp; trap - XFSZ; export FXCOUNT_PARENT=$$; unset FXCELL; } 2>/dev/null' DEBUG; } 2>/dev/null
RC
  printf '%s\n' "$1/fxcount.rc"
}

# fxc_count <log> <path>: rows whose first field, NORMALISED, equals <path> or /<path>, or ends in /<path> (a logged
# `//core/x`, a relative fx_inproc path taken with cwd `/`, normalises to exactly `/core/x`: it counts).
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
    f == p || f == s || (length(f) > ls && substr(f, length(f) - ls + 1) == s) { n++ } END { print n + 0 }' "$1"
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
  LC_ALL=C awk 'function flush() { if (cur != "" && stub) print cur "\t" (impl == "" ? "!" : impl) }
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

# fxc_key_rows <root> [<fixture>...]: one `<fixture>\t#judge f<FXC_FORMAT> <J5 key> <listed|unlisted>` row per fixture
# (every core/fixtures/*/run.sh under <root> when none is named): everything this judge decides for a fixture that the
# fixture's own content key does not hold. The J5 key is fxc_judge's (the shard stub's IMPL through fxc_impl_of, else
# the fixture), and its membership is fxc_allowlisted's. One awk resolves every stub, one awk reads the allowlist.
fxc_key_rows() {
  local root="$1" w f; shift
  w="$(mktemp -d "${TMPDIR:-/tmp}/fxc-keyrows.XXXXXX")" || return 2
  if [ $# -eq 0 ]; then
    for f in "$root"/core/fixtures/*/run.sh; do [ -f "$f" ] && printf '%s\n' "$f"; done > "$w/runs"
  else
    for f in "$@"; do [ -f "$root/core/fixtures/$f/run.sh" ] && printf '%s\n' "$root/core/fixtures/$f/run.sh"; done > "$w/runs"
  fi
  set --
  while IFS= read -r f; do set -- "$@" "$f"; done < "$w/runs"
  fxc_impl_of "$@" > "$w/impl" 2>/dev/null || :
  : > "$w/allow"
  [ -f "$FXC_ALLOW" ] && awk -F'\t' '$0 ~ /^[[:space:]]*(#|$)/ { next } { print $1 }' "$FXC_ALLOW" > "$w/allow"
  FMT="$FXC_FORMAT" awk -F'\t' 'FILENAME == ARGV[1] { A[$0] = 1; next } FILENAME == ARGV[2] { I[$1] = $2; next }
    { fx = $0; sub(/\/run\.sh$/, "", fx); sub(/.*\//, "", fx); k = ($0 in I && I[$0] != "") ? I[$0] : fx
      printf "%s\t#judge f%s %s %s\n", fx, ENVIRON["FMT"], k, ((k in A) ? "listed" : "unlisted") }' "$w/allow" "$w/impl" "$w/runs"
  rm -rf "$w"
}

# fxc_store_key: the counted store's directory name, `counted-<vk>`, vk the first 12 hex of the sha256 of FXC_FORMAT
# alone. The hook's fxcount_arm and scripts/collect-counted-stores.sh both read it here.
fxc_store_key() { printf 'counted-%s\n' "$(printf 'fxcount judge format f%s\n' "$FXC_FORMAT" | shasum -a 256 | cut -c1-12)"; }

# fxc_legacy_ok <old allowlist> <key rows> <format>: the fixtures whose --key-rows row carries <format> and whose J5 key
# has the same membership in <old allowlist> (an allowlist as fxc_allowlisted reads one) as the row records: the
# fixtures whose judgement a store written under <old allowlist> and <format> still holds.
fxc_legacy_ok() {
  [ -f "$1" ] && [ -f "$2" ] || return 2
  LF="$3" awk -F'\t' 'FILENAME == ARGV[1] { if ($0 !~ /^[[:space:]]*(#|$)/) A[$1] = 1; next }
    { split($2, j, " "); if (j[1] == "#judge" && j[2] == ENVIRON["LF"] && (((j[3] in A) ? "listed" : "unlisted") == j[4])) print $1 }' "$1" "$2"
}

# fxc_identity_check: 0 when this file's semantic sha is pinned on a `# FXC-IDENTITY <FXC_FORMAT> <sha> <reason>` row.
fxc_identity_sha() { grep -v -E '^[[:space:]]*(#|$)' "$FXC_SELF" | shasum -a 256 | cut -d' ' -f1; }
fxc_identity_check() {
  local s
  s="$(fxc_identity_sha)"
  S="$s" F="$FXC_FORMAT" awk '$1 == "#" && $2 == "FXC-IDENTITY" && NF >= 5 && $4 == ENVIRON["S"] { n++; if ($3 == ENVIRON["F"]) ok = 1 }
    END { exit (ok && n == 1) ? 0 : 1 }' "$FXC_SELF" && { printf 'judge identity f%s %s pinned\n' "$FXC_FORMAT" "$s"; return 0; }
  printf '   %s: semantic sha %s has no `# FXC-IDENTITY %s <sha> <reason>` row: add one under the current FXC_FORMAT if no fixture'"'"'s judgement moves, else under a bumped FXC_FORMAT\n' "$FXC_SELF" "$s" "$FXC_FORMAT"
  return 1
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
  # so this reads THE HEREDOC TRACKER (FXC_HEREDOC_AWK above), the one P2's scan reads too.
  LC_ALL=C awk -v SQ="'" "$FXC_HEREDOC_AWK"'
    { orig = $0 }
    hd_body(orig) { next }
    $1 == "#" && ($2 == "MUTANT-MATRIX" || $2 == "MUTANT-MATRIX-FULL") && NF >= 3 { print "M\t" $3 }
    $1 == "#" && $2 == "MUTANT-MATRIX-CONTROL" && NF >= 3 { print "C\t" $3 }
    { opens(orig) }' "$f"
}

# fxc_req <inputs.decl>: the `!` (REQUIRED) FILE lines, markers stripped, one per line. A directory line is never one.
# FXC_REQ_AWK is that parse, ONE program: with -v tag=0 it prints the `!` file lines of one file (fxc_req); with
# -v tag=1, over many files, `<!|+>\t<file>\t<path>` for every FILE line, `!` marking a REQUIRED one (P2's population).
FXC_REQ_AWK='{ sub(/\r$/, "") } $0 == "" || /^#/ { next }
      { r = 0; while ((ch = substr($0, 1, 1)) == "!" || ch == "+") { if (ch == "!") r = 1; $0 = substr($0, 2) }
        if ($0 ~ /\/$/) next
        if (!tag) { if (r) print; next }
        print (r ? "!" : "+") "\t" FILENAME "\t" $0 }'
fxc_req() {
  awk -v tag=0 "$FXC_REQ_AWK" "$1"
}

# fxc_decl_rows <invocations.decl>: J4's parse, one normalised row per line: `<c>\t<k>\t<glob or ->\t<target>\t<raw>`,
# `INPROC\t<count>\t<path>\t<raw>` for an `<N> inproc:<path>` row (its OWN first field, so no reader of field 4 -- J6's
# targets, J4's `!` check, the C arms, --static-join's path-row lookup -- ever sees it as a path row; each reader
# skips it by name), or `ERR\t<raw>`. The judge, --static-join and --b2-census read the same parse.
fxc_decl_rows() {
  awk '{ sub(/\r$/, "") } $0 ~ /^[[:blank:]]*$/ || $0 ~ /^[[:blank:]]*#/ { next }
      { raw = $0
        if (NF != 2) { print "ERR\t" raw; next }
        cnt = $1; t = $2
        # A count with a leading zero (`09`, `1+08x…`) is refused here: bash arithmetic reads it as octal and dies.
        lz = cnt; sub(/x.*/, "", lz)
        if (lz ~ /(^|\+)0[0-9]/) { print "ERR\t" raw; next }
        # An inproc: row is a plain count over a root-relative path with no `..`; the corpus form is not allowed on it.
        if (substr(t, 1, 7) == "inproc:") {
          p = substr(t, 8)
          if (cnt !~ /^[0-9]+$/ || p == "" || p ~ /^\// || p ~ /(^|\/)\.\.(\/|$)/) { print "ERR\t" raw; next }
          print "INPROC\t" cnt "\t" p "\t" raw; next }
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
  local root="$1" d fx listed=0 scanned=0 ex=0 und=0 gaps=0 gfx=0 nb=0 nd=0 ns=0 k p g w T=$'\t'
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
    [ -f "$d/invocations.decl" ] && fxc_decl_rows "$d/invocations.decl" | awk -F'\t' '$1 != "ERR" && $1 != "INPROC" { print $4 }' > "$w/tgts"
    fxc_b2 "$root" "$w/req" "$w/tgts" > "$w/b2"
    g=0
    while IFS="$T" read -r k p; do
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
  GA="$FXC_GUARD_A" GB="$FXC_GUARD_B" LC_ALL=C awk 'BEGIN { a = ENVIRON["GA"]; b = ENVIRON["GB"] }
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
        if ((f == p || f == "/" p || (length(f) > lp + 1 && substr(f, length(f) - lp) == "/" p)) && lp > best) { best = lp; s = p } }
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

# ARM P2 (BL-982 subject (b), THE TREE-WIDE IN-PROCESS DRIVE; it subsumes P1, whose pairing rule it keeps). Every
# fixture with an inputs.decl and no .undeclarable is scanned, opted in or not. fxc_p2_scan prints one row
# `E\t<fx>\t<file>:<line>\t<reason>` per unpaired DRIVE of one of the fixture's `!` bash subjects (fxc_subject_kind),
# and fxc_static_join joins it as an `E <fx> P2` row, which validate-fixture-inprocess.sh FAILs allowlisted or not
# when its P2 ratchet reads the row NEW against the push base, the merge-base of HEAD and origin/main, scanned with this same scan (p2_ratchet there); a row present at the base is OWED.
#   POPULATION, per fixture: its run.sh, every `.sh` in its own directory, and every `.sh` under core/fixtures/ its
#     inputs.decl names on any file line (`!`, `+` or bare: story-evidence-scaffold/he-inproc.sh for its declarers). A
#     shard stub (fxc_impl_of) adds its IMPL run.sh and the IMPL directory's `.sh`, judged under the STUB's subjects.
#   THE COUNTING UNIT, keyed on fxc_guarded (C5's predicate) over the union of every fixture's subjects:
#     a GUARDED subject counts per command-position CALL of a function it defines at column 0 (`name()`) above its
#       guard statement; sourcing it is not itself a drive. No callable function-definition parse existed (the two in
#       the tree, validate-shell-portability.sh's S15 and validate-mutant-kills.sh, sit inside their own awk strings
#       with no entry point), so this one is written once, here. The guard spelling is FXC_GUARD_A/B, shared.
#     an UNGUARDED subject with a shebang counts per SOURCE (`.`/`source` in command position), as P1 had it.
#     a LIBRARY (no shebang, not guarded: lib/mutant.sh) is no drive. A guarded subject with no shebang is guarded.
#     A declared subject absent from disk is read as unguarded with a shebang (fail-closed).
#   ACTIVATION: a call counts only in a fixture whose population SOURCES that guarded subject (its basename), or
#     sources an unresolvable operand (then every guarded subject of the fixture counts). A fixture that never sources
#     a subject calls no entry of it in-process.
#   OPERANDS: a literal operand, or one with a literal `/name` tail after its last `$`, is judged by basename. A bare
#     `$VAR` is judged by EVERY same-file assignment of VAR (an empty one ignored): a literal tail by its basename; a
#     value that is itself one `$OTHER` inherits OTHER's literal tails (one level). A POSITIONAL -- `$N`, `"$@"`,
#     `${@:N}`, a variable assigned from one, or a `"$@"` forwarded to another function -- is judged INDEX-FREE (OPTION
#     S, the lead ruling): by the UNION of EVERY argument of EVERY command-position call of the enclosing function in
#     ANY file of the fixture's scanned population (each read in its caller file; each population file is listed twice
#     to the one awk, the first read collecting every function definition). Which positional is read and any `shift`
#     before it are not read, so no shift shape (conditional, in a loop, in a pipeline or the background, `shift N`)
#     can move it. It FIRES if any argument is a guarded subject entry, is QUIET only when every argument resolves and
#     none is, and stays GATED when any cannot be resolved (or there is no caller). Its cost is the PHANTOM: an entry
#     passed at another index (`f() { shift; "$1"; }; f gmain x`) fires though the word never runs it. A `set --`
#     makes the positionals read after it unresolvable (gated). `for VAR in` and `read ... VAR` are opaque. Anything left opaque is UNRESOLVABLE: a SOURCE drive when the
#     fixture declares an unguarded subject, and an activation of every guarded subject.
#   COMMAND WORDS (`"$x" ...`, `eval X`) -- the lead ruling N-prime: a word whose value RESOLVES to a guarded subject
#     entry is a call drive, with no source gate; an UNRESOLVABLE word is a drive only after a source that resolves to a
#     GUARDED subject (kind from fxc_guarded, never listed), or to a file of the fixture's population that itself
#     sources one (one level deep), earlier in the same file, in a scope enclosing the word. An
#     unguarded subject keeps the source unit alone. `command X`/`builtin X` is a call of X.
#   PAIRING, P1's rule: one fx_inproc pairs ONE drive, earlier on the same line or as the first word of the nearest
#     preceding line that is neither blank nor a comment and carries no drive. A SOURCE of a guarded (or unresolvable)
#     operand takes a pairing too, and a paired one inside a function body or a `( )`/`$( )` subshell COVERS the first
#     entry call that follows it in that body (nested scopes included); every further call there needs its own
#     fx_inproc. A paired source at file level covers nothing: its calls may run any number of times.
#   THE fx_inproc UNIT (this header is its authority): for a GUARDED subject one in-process pass is one CALL of a
#     function the subject defines, so fx_inproc goes on the line before each such call (or earlier on the same line);
#     one fx_inproc on the line before the `.`/`source` of the subject covers the FIRST such call after it inside the
#     same function body or `( )`/`$( )` subshell, and every further call needs its own. For an UNGUARDED subject with
#     a shebang one pass is one SOURCE. P2 judges call SITES (static lines), while an `inproc:` row counts EXECUTIONS
#     (one fx_inproc row per run of a paired line, judged by J3). lib/mutant.sh's own comment ("Call it once per pass, on the line before the
#     `.`/`source` of the subject", citing P1) is SUPERSEDED by this text; the later remediation release updates it.
#   A UNIT CHANGE, stated: until this arm lib/mutant.sh documented one fx_inproc per SOURCE. Fixtures converted on that
#     documented unit -- ai-dlc-31's unit-change rows, its in-process conversions -- pair their sources exactly as it
#     said; under the per-CALL unit those calls are OWED, and the ratchet carries them as owed against the push base
#     they land on.
#   MASKING: one cross-line quote stack. Single-quoted text is data across lines (a jq filter `else . end`), except
#     the body of `bash -c '...'`/`sh -c "..."`, which is code run by a child bash and is scanned; a heredoc body is
#     skipped through THE HEREDOC TRACKER; comments are dropped. The scan runs under LC_ALL=C (a UTF-8 locale made the
#     awk die on a multibyte byte and lose every file after it), its exit status is read, and the files it opened must
#     equal the files listed, else the join is REFUSED (rc 2).
#   REMEDY TEXT names fx_inproc on the line before the drive. Inside a `bash -c` worker fx_inproc is not defined (a
#     child bash inherits no unexported function; FXCOUNT_LOG does cross): `export -f fx_inproc` in the parent, or
#     source lib/mutant.sh in the worker behind ok/bad stubs.
# BLIND ROUTES, stated, not prevented: a call through a name built at run time beyond the fail-closed expansion rule;
#   a subject function defined below its guard (never defined when sourced, so a same-named call is not counted);
#   a call of a name the SAME file defines as a function on an earlier line, with no source of one of the fixture's
#   subjects on a line between that definition and the call in a scope enclosing the call (file level, or the function
#   body or subshell the call sits in), is read as the local function (the text order, not the
#   run order: a definition inside dead code, or one the call reaches through another path, still shadows);
#   a function defined with the `function` keyword (not parsed); code EXTRACTED from a declared subject into a renamed
#   file (readset-skip's `$WORK/pool.sh`, `merge.sh` spans) is no pass of that subject, as BL-878 item 3's renamed
#   mutant copies are not; a `case`, `in` or `esac` spelled as a bare word outside a case statement can misread the next `)` (`local case=x` and `$case` are excluded); an operand whose
#   literal tail names a file other than its real target reads by that tail, fail-OPEN;
#   positional resolution follows a caller only when the function name is defined in the population (a same-named
#   function in two files of one fixture pools their callers);
#   an ALIAS of a subject entry (`alias gm=gmain; gm`) is read as the unknown word gm, not as gmain: aliases are not
#   expanded, so a drive spelled through one reads QUIET;
#   the helper gate is one level deep: a source of a file that sources a file that sources the subject gates nothing;
# ROUTES LEFT OPEN, measured with scratch variants of this scan. The scan itself flags, at this release's combined
#   tree, 348 rows over 116 sites in 25 fixtures after remediation (530 rows over 217 sites in 43 fixtures before it,
#   on main 62a88119c with this change). The route lists below were measured on that main 62a88119c tree.
#   THE B ROUTE, the LARGER open route (execution through an UNGUARDED subject's functions after its counted source
#   is not counted): 312 call sites in 350 rows over 4 fixtures, against the 116 sites the scan flags --
#   backlog-receipt-efficiency 221 (control: it sources the unguarded backlog-receipt-binding/run.sh, then
#   calls vin, seed, mut, record, ok, bad, note ...), story-evidence-receipts-mutants 75 and
#   story-evidence-smoke-mutants 36 (story-evidence-receipts/run.sh), smoke-surface-ignored-mutants 18
#   (smoke-surface-ignored/run.sh).
#   GATED unresolvable command words (a word that resolves to nothing literal, with no guarded source in scope),
#   126 sites in 212 (fixture, site) rows. By file:line --
#     adversarial-shard-merge/lib.sh:1045 apply-drift-after-write/run.sh:598,745 apply-restamp-theirs/run.sh:465
#     apply-restamp-worklist/run.sh:3399,3669,3944,4136 artifact-derivations/run.sh:429,733,802,816,1052
#     check-24-adversarial-convergence/run.sh:547,549,1627,1751,3441,3479 consumer-suite-pool/matrix.sh:31
#     consumer-suite-pool/run.sh:269 context-sensor/run.sh:120,128,275,645,706 derivation-differential/run.sh:539
#     dispatch-model-guard/matrix.sh:31,99,105 dispatch-model-guard/run.sh:2782
#     enforcement-map-derivations/run.sh:2241 enforcement-map-sites/run.sh:3569 file-mtime/run.sh:168
#     fold-architect-ledger-join/run.sh:517 gate-adjudication/seed.sh:80 gate-transition/run.sh:641,643
#     h2-attest-scripts-dir/run.sh:975,979,1031 handoff-record-carries-return/run.sh:410,418
#     implementation-join-yield/run.sh:531 layer-adjudication-tier/run.sh:216,781,2039
#     layer-catalog-collision/run.sh:134 layer-conforms-to/run.sh:217 layer-entry-unreadable/run.sh:285,559
#     ledger-reverify/run.sh:6600,6603,6763 ledger-rotate/run.sh:119 mutation-red-replay/run.sh:635,641,677,682
#     preclassify-rename-row/run.sh:593 presuite-present-key/run.sh:299 provenance-flagless-default/run.sh:542
#     readset-sandbox-root-clause/run.sh:155
#     readset-skip/run.sh:637,666,1196,1209,1585,1627,1676,1731,1777,2623,4655,5439
#     readset-stage1-verdict/run.sh:807,809,812,813,1189 reconcile-emit-report/run.sh:184,280,290,297,2153,2677
#     remediator-shard-join/run.sh:1079 remediator-shard-join/unit-reader-a.sh:129,135,143,661
#     remediator-shard-join/unit-reader-b.sh:202,208,216,398 retired-contract-token/run.sh:406
#     retired-layer-token/run.sh:148 retro-audit-scans/run.sh:1628 review-shard-merge/lib.sh:1865,4262
#     review-shard-merge/run.sh:463 self-update-gate/run.sh:638,641,3761,4451,5325,5414
#     settings-merge-unparseable-template/run.sh:285 snapshot-update-stamps/run.sh:447
#     sprint-status-lifecycle/run.sh:134 story-corpus-sprint-slot/run.sh:137
#     story-evidence-receipts-mutants/run.sh:145 story-evidence-scaffold/run.sh:137,142,173,176,492
#     story-evidence-smoke-mutants/run.sh:97 story-provenance/run.sh:109,1133
#     wait-beat-liveness/run.sh:2355,2356,4258,4301,4308 wait-stale-deliverable/run.sh:1138
#   THE A2 ROUTE (an unresolvable source followed, in an enclosing scope, by an unresolvable word; gated shut),
#   16 sites in 40 rows: readset-skip/run.sh:637,1209,1585,1676,1731,2623,4655,5439
#   remediator-shard-join/unit-reader-a.sh:129,135,143,661 remediator-shard-join/unit-reader-b.sh:202,208,216,398
# HOW THE FALSE-POSITIVE SET REACHED ITS FLOOR: see P2_NARROWING below the scan.
FXC_P2_AWK='
function base(p) { sub(/.*\//, "", p); return p }
function xs(r) { gsub(/./, "X", r); return r }
function dm(r) { gsub(/./, "X", r); return r }
function cpush(k, open, i) { CT++; CK[CT] = k
  if (open) { NSID++; SPAR[FI, NSID] = (CT > 1 ? CSID[CT - 1] : 0); CSID[CT] = NSID; SKND[FI, NSID] = k } else CSID[CT] = (CT > 1 ? CSID[CT - 1] : 0)
  NTR++; TRP[NTR] = i; TRS[NTR] = CSID[CT] }
function cpop(i) { if (CT > 0) CT--; NTR++; TRP[NTR] = i; TRS[NTR] = (CT > 0 ? CSID[CT] : 0) }
function scope_at(p,   k, s) { s = LSC; for (k = 1; k <= NTR; k++) { if (TRP[k] > p) break; s = TRS[k] } return s }
# casekw <code text>: track case ... in ... esac across lines. After `in` (of a case) and after `;;`, CASEPAT holds
# until the `)` that ends the pattern: that `)` closes no subshell and is marked in CTERM as a command position.
# A keyword is a whole word after a blank, an operator or the start of a chunk that does not follow a `$` (pc, the
# character before the chunk), and before a blank, `;` or the end: `local case=x` and `$case` are no keywords.
function casekw(ch, pc,   w) {
  while (match(ch, /(^|[[:blank:];&|(])(case|in|esac)([[:blank:];]|$)|;;/)) {
    w = substr(ch, RSTART, RLENGTH)
    if (RSTART == 1 && pc == "$" && w !~ /^;;/) { ch = substr(ch, RSTART + RLENGTH); pc = ""; continue }
    ch = substr(ch, RSTART + RLENGTH); pc = ""
    if (w ~ /;;/) { if (CASEN > 0) { CASEPAT = 1; CASEPD = CT } }
    else if (w ~ /esac/) { if (CASEN > 0) CASEN--; CASEPAT = 0; CASEPEND = 0 }
    else if (w ~ /case/) { CASEN++; CASEPEND = 1 }
    else if (CASEPEND) { CASEPEND = 0; CASEPAT = 1; CASEPD = CT } } }
function cmask(s,   o, n, i, t, r, c, j, d, wk, e) {
  o = ""; n = length(s); i = 1; NTR = 0; LSC = (CT > 0 ? CSID[CT] : 0); delete CTERM
  while (i <= n) {
    t = (CT > 0) ? CK[CT] : "C"; r = substr(s, i)
    if (t == "S") { j = index(r, SQ); if (j == 0) return o xs(r)
      o = o xs(substr(r, 1, j - 1)) SQ; i += j; cpop(i - 1); continue }
    if (t == "D") { if (!match(r, /["\\$`]/)) return o dm(r)
      o = o dm(substr(r, 1, RSTART - 1)); i += RSTART - 1; c = substr(s, i, 1)
      if (c == "\"") { o = o c; cpop(i); i++; continue }
      if (c == "\\") { o = o "XX"; i += 2; continue }
      if (c == "$" && substr(s, i + 1, 1) == "(") { o = o "$("; cpush("P", 1, i); i += 2; continue }
      o = o (c == "`" ? "X" : c); i++; continue }
    if (!match(r, CODE_RE)) { casekw(r, substr(s, i - 1, 1)); return o r }
    j = RSTART; casekw(substr(r, 1, j - 1), substr(s, i - 1, 1)); o = o substr(r, 1, j - 1); i += j - 1; c = substr(s, i, 1)
    if (c == "#") { if (i == 1 || substr(s, i - 1, 1) ~ /[[:blank:];&|(]/) return o; o = o c; i++; continue }
    if (c == "\\") { o = o "XX"; i += 2; continue }
    if (c == SQ) { if (t == "W") { o = o c; cpop(i); i++; continue }
      wk = (o ~ WORKER_RE); cpush(wk ? "W" : "S", wk, i); o = o c; i++; continue }
    if (c == "\"") { if (t == "V") { o = o c; cpop(i); i++; continue }
      wk = (o ~ WORKER_RE); cpush(wk ? "V" : "D", wk, i); o = o c; i++; continue }
    if (c == "$") { d = substr(s, i + 1, 1)
      if (d == "(") { o = o "$("; cpush("P", 1, i); i += 2; continue }
      if (d == SQ) { for (j = i + 2; j <= n; j++) { c = substr(s, j, 1); if (c == "\\") { j++; continue } if (c == SQ) break }
        if (j > n) { cpush("S", 0, i); return o "$" SQ xs(substr(s, i + 2)) }
        o = o "$" SQ xs(substr(s, i + 2, j - i - 2)) SQ; i = j + 1; continue }
      if (d == "{") { e = 1; for (j = i + 2; j <= n && e > 0; j++) { c = substr(s, j, 1); if (c == "{") e++; else if (c == "}") e-- }
        if (e == 0) { o = o "$" xs(substr(s, i + 1, j - i - 1)); i = j; continue } }
      o = o c; i++; continue }
    if (c == "(") { o = o c; if (!(CASEPAT && CT <= CASEPD)) cpush("Q", 1, i); i++; continue }
    if (c == ")") { o = o c; if (CASEPAT && CT <= CASEPD) { CASEPAT = 0; CTERM[i] = 1; i++; continue } if (t == "P" || t == "Q") cpop(i); i++; continue }
    if (c == "{") { o = o c; if ((i == 1 || substr(s, i - 1, 1) ~ /[[:blank:];&|(){]/) && (i == n || substr(s, i + 1, 1) ~ /[[:blank:]]/)) cpush("B", 1, i); i++; continue }
    if (c == "}") { o = o c; if (t == "B" && (i == 1 || substr(s, i - 1, 1) ~ /[[:blank:];]/)) cpop(i); i++; continue }
    o = o c; i++
  }
  return o
}
function cmdpos(m, i,   pre) { pre = substr(m, 1, i - 1)
  while (sub(/(^|[[:blank:]])[A-Za-z_][A-Za-z0-9_]*=[^[:blank:]()`;&|]*[[:blank:]]+$/, "", pre)) ;
  sub(/[[:blank:]]+$/, "", pre)
  if (pre ~ /=\($/) return 0
  # The `)` closing a case pattern (cmask marks it in CTERM) opens a command position: `a) gmain ;;`.
  if (pre ~ /\)$/ && (length(pre) in CTERM)) return 1
  # The first word of a worker body on the same line: `bash -c "gmain"`, `sh -c 'gmain'`.
  if ((substr(pre, length(pre)) == "\"" || substr(pre, length(pre)) == SQ) && substr(pre, 1, length(pre) - 1) ~ WORKER_RE) return 1
  return ((pre == "" && !CONT && LCODE) || pre ~ /[;&|({!`]$/ || pre ~ /(^|[[:blank:];&|(){}!`])(then|do|else|if|elif|while|until|time)$/) }
function opnd(s, i,   r, w, c, q, j, n, dp, lead) {
  r = substr(s, i); match(r, /^[[:blank:]]*/); lead = RLENGTH; r = substr(r, lead + 1); w = ""; q = ""; n = length(r); dp = 0
  for (j = 1; j <= n; j++) { c = substr(r, j, 1)
    if (c == "$" && substr(r, j + 1, 1) == "(") dp++
    else if (c == ")" && dp > 0) { dp--; w = w c; continue }
    if (q == "") { if (dp == 0 && c ~ /[[:blank:];&|)<>]/) break; if (c == SQ || c == "\"") { q = c; continue }; w = w c; continue }
    if (c == q) { q = ""; continue }; w = w c }
  OPEND = i + lead + j - 1
  return w }
function tailof(v,   t) { if (index(v, "$") == 0) return base(v); t = v; sub(/.*\$/, "", t); return (t ~ /\//) ? base(v) : "?" }
function casepat(q, e,   t, a, b) { if (substr(M, e) !~ /^(\|[^[:blank:];&()]*)*\)/) return 0
  t = substr(M, 1, q - 1); a = gsub(/\(/, "(", t); b = gsub(/\)/, ")", t); return a <= b }
function valclass(v,   t) { t = v; sub(/[[:blank:]].*/, "", t)
  if (t ~ /^[A-Za-z_][^=]*=/ || t ~ /\(\)$/) return "/"
  if (v ~ /^\$\((command[[:blank:]]+-[vV]|which|type[[:blank:]]+-[Pp])[[:blank:]]/) return "/"
  if (index(v, "$") == 0) { if (index(v, "/")) return "/"; sub(/[[:blank:]].*/, "", v); return v }
  t = v; sub(/.*\$/, "", t); return (t ~ /\//) ? "/" : "?" }
function vt(v) { return VMODE ? valclass(v) : tailof(v) }
function opres_e(w, f) {
  if (index(w, "$") == 0) return "R " valclass(w)
  if (valclass(w) == "/") return "R /"
  return "W" }
function func_of(sc) { while (sc > 0) { if ((FI SUBSEP sc) in FUNSC) return FUNSC[FI, sc]; sc = SPAR[FI, sc] } return "" }
function newfile() { CASEN = 0; CASEPAT = 0; CASEPEND = 0; CONT = 0; CT = 0; HN = 0; HI = 0; NSID = 0; LASTSIG = 0; }
# shadowed <file index> <site>: a call of a name the SAME file defines as a function earlier, with no un-shadowing
# source between that definition and the call, is the local function, not the subject entry. EVERY source un-shadows
# (a subject, an unresolvable operand, a fixture-local file that may source one: fail-closed) except one resolving only
# to declared LIBRARY subjects, and except one sitting inside a `( )`, `$( )` or worker body that does not also
# enclose the call: a closed subshell cannot redefine the name for it. A `{ }` group or a function body is NOT closed:
# `{ . g.sh; }` and `ld(){ . g.sh; }; ld` both redefine it in the calling shell.
function posbad(f) { return ((CFI SUBSEP f) in SETB) && (POSLINE > SETB[CFI, f] || (POSLINE == SETB[CFI, f] && POSCOL >= SETBC[CFI, f])) }
function isanc(fi, a, c) { while (c > 0 && c != a) c = SPAR[fi, c]; return c == a }
# egate <file index> <site>: a source RESOLVING to a guarded subject of the fixture (kind from fxc_guarded), or to a
# fixture-local population file that itself sources one (THE HELPER GATE, one level deep), earlier in the same file,
# in a scope enclosing the site. An unguarded subject keeps the source unit alone; an unresolvable source gates
# nothing here.
function egate(fi, k,   j) {
  for (j = 1; j < k; j++) if ((((fi SUBSEP j) in SSG) || ((fi SUBSEP j) in SSH2)) && isanc(fi, SC[fi, j], SC[fi, k])) return 1
  return 0 }
function shadowed(fi, k,   d, j, a, sub_) { d = SDEF[fi, k] + 0; if (d == 0) return 0
  for (j = 1; j <= NS[fi]; j++) {
    if (!((fi SUBSEP j) in SSRC) || SL[fi, j] <= d || SL[fi, j] > SL[fi, k]) continue
    sub_ = 0; a = SC[fi, j]
    while (a > 0 && !isanc(fi, a, SC[fi, k])) { if (SKND[fi, a] ~ /^[PQWV]$/) { sub_ = 1; break } a = SPAR[fi, a] }
    if (!sub_) return 0 }
  return 1 }
function nrmt(s) { gsub(/[[:blank:]]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
function addsite(ty, q, w, res, f, raw,   k, pfx) { NS[FI]++; k = NS[FI]; SX[FI, k] = nrmt(S0); SDEF[FI, k] = NEXTDEF
  ST[FI, k] = ty; SL[FI, k] = FNR; SW[FI, k] = w; SR[FI, k] = res; SC[FI, k] = scope_at(q); SFN[FI, k] = f; SRW[FI, k] = raw; SQC[FI, k] = q
  pfx = substr(M, 1, q - 1); SNF[FI, k] = gsub(/fx_inproc/, "&", pfx); PREV[FI, FNR] = LASTSIG
  if (WCT > 0) SWK[FI, k] = 1 }
function opres(o) { return (index(o, "$") == 0 || tailof(o) != "?") ? "R " base(o) : "W" }
function argn(s, i, n,   k, w) { for (k = 1; k <= n; k++) { if (i > length(s)) return "\001"; w = opnd(s, i); i = OPEND } return w }
# vres <value> <enclosing function> <levels left> <the name being assigned>: the resolution of one shell word, as a
# space-led list of tails (VMODE 0: basenames; VMODE 1: command classes, `/` a program path) with `?` for unresolvable.
function vres(v, f, lvl, self,   x, d, r, k) {
  if (v == "$@" || v == "$*" || v == "${@}" || v == "${*}" || v ~ /^\$\{[@*]:[0-9]+(:[0-9]+)?\}$/) v = "$1"
  if (match(v, /^\$\{[A-Za-z_0-9]+:?[-=][^}]*\}$/)) { x = substr(v, 3); d = x; sub(/:?[-=].*/, "", x); sub(/^[A-Za-z_0-9]+:?[-=]/, "", d); sub(/\}$/, "", d)
    r = (d != "") ? vres(d, f, 0, self) : ""
    if (x != self) r = r vres("$" x, f, lvl, self)
    return (r == "") ? " ?" : r }
  if (match(v, /^\$\{?[1-9]\}?$/)) { x = v; gsub(/[${}]/, "", x); if (!(lvl > 0 && f != "")) return " ?"
    if (posbad(f)) return " ?"
    return posall(f, lvl - 1) }
  if (match(v, /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/)) { x = v; gsub(/[${}]/, "", x)
    if (VMODE && x == "BASH") return " /"
    if (lvl <= 0) return " ?"
    r = ""; for (k = 1; k <= BUFNF[CFI]; k++) r = r asg_tails(k, x, lvl - 1)
    return (r == "") ? " ?" : r }
  return " " vt(v) }
# asg_tails/vres read the assignment buffers of file CFI (the context file); posall switches CFI to each caller file.
function asg_tails(k, nm, lvl,   m, p, q, v, r, svl, svc) { m = BM[CFI, k]; r = ""; p = 0
  while ((q = index(substr(m, p + 1), nm "=")) > 0) { q += p
    if (q == 1 || substr(m, q - 1, 1) !~ /[A-Za-z0-9_$]/) { v = opnd(BS[CFI, k], q + length(nm) + 1); if (v != "") { svl = POSLINE; svc = POSCOL; POSLINE = BLN[CFI, k]; POSCOL = q; r = r vres(v, BF[CFI, k], lvl, nm); POSLINE = svl; POSCOL = svc } }
    p = q + length(nm) }
  if (m ~ ("(^|[^A-Za-z0-9_])for[[:blank:]]+" nm "([^A-Za-z0-9_]|$)")) r = r " ?"
  if (m ~ /(^|[^A-Za-z0-9_])read[[:blank:]]/ && m ~ ("[[:blank:]]" nm "([^A-Za-z0-9_]|$)")) r = r " ?"
  return r }
# posall <function> <levels left>: OPTION S, index-free. EVERY argument of EVERY command-position call of the function
# in ANY file of the current fixture scanned population (PJSET), each resolved in the context of its caller file, as
# one union: which positional a word names, and any shift before it, are not read. An argument list ends at the first
# operator or at the end of the line; an empty quoted argument adds nothing. No caller, or callers passing no argument:
# unresolvable.
function posall(f, lvl,   k, r, a, sv, c, m, i, t, svl, svc) { r = ""; sv = CFI; c = 0
  for (k = 1; k <= GCN[f]; k++) { if (!(GC_FI[f, k] in PJSET)) continue; c++; CFI = GC_FI[f, k]; i = GC_P[f, k]; t = LTXT[CFI, GC_L[f, k]]
    for (m = 1; m <= 64; m++) { a = argn(t, i, 1); if (a == "\001") break
      if (a == "") { if (OPEND > length(t) || substr(t, OPEND, 1) ~ /[;&|)<>]/) break; i = OPEND; continue }
      i = OPEND; svl = POSLINE; svc = POSCOL; POSLINE = GC_L[f, k]; POSCOL = GC_P[f, k]; r = r vres(a, GC_F[f, k], lvl, ""); POSLINE = svl; POSCOL = svc } }
  CFI = sv
  return (c == 0 || r == "") ? " ?" : r }
# sres <file index> <site>: the site resolution for the CURRENT fixture (the population decides positional callers).
function sres(fi, k,   r) { if (SR[fi, k] != "W") return SR[fi, k]
  if ((fi SUBSEP k) in SRM) return SRM[fi, k]
  CFI = fi; VMODE = (ST[fi, k] == "E"); POSLINE = SL[fi, k]; POSCOL = SQC[fi, k]; r = "R" vres(SRW[fi, k], SFN[fi, k], 2, ""); SRM[fi, k] = r; return r }
function finalize() { }
function kindof(p) { return (p in GSUB) ? "G" : ((p in MISS) ? "U" : ((p in SHB && SHB[p]) ? "U" : "L")) }
function disp(p) { if (substr(p, 1, length(FXROOT)) == FXROOT) return substr(p, length(FXROOT) + 1); return p }
function rdisp(p) { if (substr(p, 1, length(RROOT)) == RROOT) return substr(p, length(RROOT) + 1); return p }
BEGIN { FS = "\t"; GA = ENVIRON["GA"]; GB = ENVIRON["GB"]; FXROOT = ""
  CODE_RE = "[#\"\\\\$(){}`" SQ "]"
  # A word boundary: an operator, a blank, or the quote that opens a `bash -c "..."`/`sh -c '...'` worker body (inside
  # a plain string every character is masked to X, so a quote there never precedes a word).
  BND = "[[:blank:];&|(){}!`\"" SQ "]"
  WORKER_RE = "(^|[^A-Za-z0-9_])([Bb][Aa])?[Ss][Hh]\"?[[:blank:]]+(-[A-Za-z]+[[:blank:]]+)*-[A-Za-z]*c[[:blank:]]+$"
  # OPENED counts the listed files this awk CAN open (an empty one included: it never reaches FNR == 1). getline
  # answers -1 for an unopenable file, which the shell then sees as opened != listed.
  # An unopenable file is DROPPED from ARGV (this awk would otherwise die on it), so opened != listed is what refuses.
  for (i = 2; i < ARGC; i++) { if ((getline tl < ARGV[i]) < 0) { UNREAD++; ARGV[i] = "" } else close(ARGV[i]) } }
FILENAME == ARGV[1] { if ($1 == "G") GSUB[$2] = 1; else if ($1 == "M") MISS[$2] = 1; else if ($1 == "Q") QSET[$2] = 1
  else if ($1 == "S") { if (!(($2 SUBSEP $3) in SSEEN)) { SSEEN[$2, $3] = 1; NSB[$2]++; SBP[$2, NSB[$2]] = $3; if (!($2 in FXSEEN)) { FXSEEN[$2] = 1; FXS[++FXN] = $2 } } }
  else if ($1 == "J") { if (!(($2 SUBSEP $3) in JSEEN)) { JSEEN[$2, $3] = 1; NJ[$2]++; JP[$2, NJ[$2]] = $3; if (!($2 in FXSEEN)) { FXSEEN[$2] = 1; FXS[++FXN] = $2 } } }
  else if ($1 == "ROOT") { FXROOT = $2 "/core/fixtures/"; RROOT = $2 "/" }
  next }
FNR == 1 { OCC[FILENAME]++; o = OCC[FILENAME] - ((FILENAME in QSET) ? 1 : 0); POPF = (o <= 0) ? 0 : ((o == 1) ? 1 : 2); PH_STOP = 0
  if (POPF == 0) SHB[FILENAME] = (substr($0, 1, 2) == "#!")
  else if (POPF == 2) { FI = ++NPF; PIDX[FILENAME] = FI; PNAME[FI] = FILENAME; newfile() } }
POPF == 0 { if (!(FILENAME in GSUB) || PH_STOP) next
  l = $0; sub(/\r$/, "", l); if (l == GA || l == GB) { PH_STOP = 1; next }
  if (l ~ /^[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*\(\)/) { nm = l; sub(/[[:blank:]]*\(.*/, "", nm); FN[FILENAME, nm] = 1; FNU[nm] = 1 }
  next }
# THE DEFINITIONS PASS: each population file is listed twice; its first read only collects every name the file
# defines as a function, so a call is recorded (for positional resolution) wherever in the population it appears.
POPF == 1 { if ($0 ~ /^[[:blank:]]*(function[[:blank:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*\(\)/) { nm = $0; sub(/^[[:blank:]]*(function[[:blank:]]+)?/, "", nm); sub(/[[:blank:]]*\(.*/, "", nm); DEFN[nm] = 1 } next }
{ s = $0; sub(/\r$/, "", s); S0 = s }
hd_body(s) { LASTSIG = FNR; next }
{ st = (CT > 0) ? CK[CT] : "C"; LCODE = (st != "S" && st != "D")
  M = hd_arith(cmask(s)); WCT = 0; for (k = 1; k <= CT; k++) if (CK[k] == "W" || CK[k] == "V") WCT = 1
  opens_m(s, M)
  if (M ~ /^[[:blank:]]*$/) next
  if (index(M, "=") || M ~ /(for|read)[[:blank:]]/) { BUFNF[FI]++; BM[FI, BUFNF[FI]] = M; BS[FI, BUFNF[FI]] = s; BF[FI, BUFNF[FI]] = func_of(LSC); BLN[FI, BUFNF[FI]] = FNR }
  # A function body opened on this line is the scope of that function before the `set --` below reads it (a one-line body).
  if (match(M, /^[[:blank:]]*[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*\(\)[[:blank:]]*[{(]/)) {
    nm = M; sub(/^[[:blank:]]*/, "", nm); sub(/[[:blank:]]*\(.*/, "", nm)
    for (k = 1; k <= NTR; k++) if (TRP[k] == RLENGTH) { FUNSC[FI, TRS[k]] = nm; break } }
  # A `set --` in a function makes every positional of that function read after it unresolvable (gated). A `shift` is
  # not read at all: OPTION S resolves a positional to the union of every caller argument, whatever its index.
  if (match(M, /(^|[;&|({[:blank:]])set[[:blank:]]+--/)) { sf = func_of(scope_at(RSTART + 1)); if (!((FI SUBSEP sf) in SETB)) { SETB[FI, sf] = FNR; SETBC[FI, sf] = RSTART } }
  if (M ~ /^[[:blank:]]*fx_inproc([[:blank:]]|$)/) FXL[FI, FNR] = 1
  if (M ~ /^[[:blank:]]*[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*\(\)/) { nm = M; sub(/^[[:blank:]]*/, "", nm); sub(/[[:blank:]]*\(.*/, "", nm); LDL[FI, nm] = FNR }
  # sources
  p = 0
  while (match(substr(M, p + 1), /(\.|source)[[:blank:]]/)) { q = p + RSTART; kw = (substr(M, q, 1) == ".") ? 1 : 6; p = q + kw - 1
    if (q > 1 && substr(M, q - 1, 1) ~ /[A-Za-z0-9_.\/-]/) continue
    if (!cmdpos(M, q)) continue
    o = opnd(s, q + kw); if (o == "") continue
    f = func_of(scope_at(q)); addsite("S", q, o, opres(o), f, o) }
  # command-position words: subject entries, local functions, eval, command/builtin, expansions
  hit = 0; nw = split(M, WW, /[^A-Za-z0-9_]+/)
  for (k = 1; k <= nw; k++) if ((WW[k] in FNU) || (WW[k] in DEFN) || WW[k] == "eval" || WW[k] == "command" || WW[k] == "builtin") { hit = 1; break }
  if (hit) { p = 0
    while (match(substr(M, p + 1), /[A-Za-z_][A-Za-z0-9_]*/)) { q = p + RSTART; w = substr(M, q, RLENGTH); p = q + RLENGTH - 1
      if (q > 1 && substr(M, q - 1, 1) !~ BND) continue
      nx = substr(M, p + 1, 1); if (nx == "=" || nx == "(" || nx == "." || nx == "/" || nx == "-") continue
      if (!((w in FNU) || (w in DEFN) || w == "eval" || w == "command" || w == "builtin")) continue
      if (!cmdpos(M, q) || casepat(q, p + 1)) continue
      if (w == "command" || w == "builtin") { if (match(substr(M, p + 1), /^[[:blank:]]+[A-Za-z_][A-Za-z0-9_]*/)) { w = substr(M, p + 1, RLENGTH); sub(/^[[:blank:]]+/, "", w); if (w in FNU) { NEXTDEF = LDL[FI, w] + 0; addsite("C", q, w, "", ""); NEXTDEF = 0 } } continue }
      if (w == "eval") { v = opnd(s, p + 1); sub(/^[[:blank:]]+/, "", v); sub(/[[:blank:]].*/, "", v)
        f = func_of(scope_at(q)); addsite("E", q, "eval " v, (v == "") ? "R ?" : opres_e(v, f), f, v); continue }
      if (w in DEFN) { GCN[w]++; gn = GCN[w]; GC_FI[w, gn] = FI; GC_L[w, gn] = FNR; GC_P[w, gn] = p + 1; GC_F[w, gn] = func_of(scope_at(q)); LTXT[FI, FNR] = s }
      if (w in FNU) { NEXTDEF = LDL[FI, w] + 0; addsite("C", q, w, "", ""); NEXTDEF = 0 } } }
  if (index(M, "$")) { p = 0
    while (match(substr(M, p + 1), /"?\$[{A-Za-z_]/)) { q = p + RSTART; p = q + RLENGTH - 1
      if (q > 1 && substr(M, q - 1, 1) !~ BND) continue
      if (!cmdpos(M, q)) continue
      w = opnd(s, q); if (casepat(q, OPEND)) continue
      f = func_of(scope_at(q)); addsite("E", q, w, opres_e(w, f), f, w) } }
  LASTSIG = FNR; CONT = (s ~ /\\$/) }
function entry(fx, w,   k, p) { for (k = 1; k <= NSB[fx]; k++) { p = SBP[fx, k]; if (KD[p] == "G" && (ACTALL || (p in ACT)) && ((p SUBSEP w) in FN)) return p } return "" }
END {
  for (x = 1; x <= FXN; x++) { fx = FXS[x]; HASU = 0; HASG = 0; delete BK
    for (k = 1; k <= NSB[fx]; k++) { p = SBP[fx, k]; KD[p] = kindof(p); if (KD[p] == "U") HASU = 1; if (KD[p] == "G") HASG = 1; BK[base(p)] = BK[base(p)] " " p }
    if (!HASU && !HASG) continue
    ACTALL = 0; delete ACT; delete FG; delete SSRC; delete SSG; delete SSU; delete PJSET; delete SRM
    for (j = 1; j <= NJ[fx]; j++) { fi = PIDX[JP[fx, j]]; if (fi != "") PJSET[fi] = 1 }
    for (j = 1; j <= NJ[fx]; j++) { fi = PIDX[JP[fx, j]]; if (fi == "") continue
      for (k = 1; k <= NS[fi]; k++) { if (ST[fi, k] != "S") continue
        n = split(substr(sres(fi, k), 2), RB, " ")
        for (r = 1; r <= n; r++) { if (RB[r] == "?") { if (HASG) ACTALL = 1; FG[fi] = 1; SSRC[fi, k] = 1; SSU[fi, k] = 1; continue }
          if (!(RB[r] in BK)) { SSRC[fi, k] = 1; continue }; m = split(BK[RB[r]], BP, " ")
          for (i = 1; i <= m; i++) { FG[fi] = 1; if (KD[BP[i]] != "L") SSRC[fi, k] = 1; if (KD[BP[i]] == "G") { ACT[BP[i]] = 1; SSG[fi, k] = 1 } } } } }
    # THE HELPER GATE, one level deep (fail-closed): a source whose operand resolves to another file of the
    # fixture population that itself sources a guarded subject (anywhere in it) gates as a guarded source (SSH2, read by egate).
    delete HSG; delete PBN; delete SSH2
    for (j = 1; j <= NJ[fx]; j++) { fi = PIDX[JP[fx, j]]; if (fi == "") continue; PBN[base(PNAME[fi])] = PBN[base(PNAME[fi])] " " fi
      for (k = 1; k <= NS[fi]; k++) if ((fi SUBSEP k) in SSG) { HSG[fi] = 1; break } }
    for (j = 1; j <= NJ[fx]; j++) { fi = PIDX[JP[fx, j]]; if (fi == "") continue
      for (k = 1; k <= NS[fi]; k++) { if (ST[fi, k] != "S" || ((fi SUBSEP k) in SSG)) continue
        n = split(substr(sres(fi, k), 2), RB, " ")
        for (r = 1; r <= n; r++) { if (!(RB[r] in PBN)) continue; m = split(PBN[RB[r]], BP, " ")
          for (i = 1; i <= m; i++) if ((BP[i] in HSG) && BP[i] != fi) SSH2[fi, k] = 1 } } }
    for (j = 1; j <= NJ[fx]; j++) { fi = PIDX[JP[fx, j]]; if (fi == "") continue
      delete DRV; delete USED; delete AVU; delete COV
      for (k = 1; k <= NS[fi]; k++) { L = SL[fi, k]; ty = ST[fi, k]; w = SW[fi, k]; drive = 0; cov = 0; why = ""
        if (ty == "S") { n = split(substr(sres(fi, k), 2), RB, " ")
          for (r = 1; r <= n; r++) { if (RB[r] == "?") { cov = cov || HASG; if (HASU && why == "") { drive = 1; why = "the source of " w ", an operand no literal path, same-file assignment or caller in the population resolves, in a fixture declaring an unguarded bash subject" } continue }
            if (!(RB[r] in BK)) continue; m = split(BK[RB[r]], BP, " ")
            for (i = 1; i <= m; i++) { if (KD[BP[i]] == "G") cov = 1; else if (KD[BP[i]] == "U") { drive = 1; why = "the source of unguarded bash subject " rdisp(BP[i]) " (" w ")" } } } }
        else if (ty == "C") { p = shadowed(fi, k) ? "" : entry(fx, w); if (p != "") { drive = 1; why = "the call of " w ", an entry function of guarded subject " rdisp(p) } }
        else { n = split(substr(sres(fi, k), 2), RB, " "); ent = ""; unr = 0
          for (r = 1; r <= n; r++) { if (RB[r] == "?") unr = 1; else if (entry(fx, RB[r]) != "") { ent = RB[r]; break } }
          # N-prime: a word resolving to a guarded subject entry is a call, ungated; an unresolvable word is a drive only
          # after a source resolving to a guarded subject in an enclosing scope (egate).
          if (ent != "") { drive = 1; why = "the command word " w ", which resolves to " ent ", an entry function of a guarded subject" }
          else if (unr && egate(fi, k)) { drive = 1; why = "the command word " w ", which resolves to nothing literal, after a source of a guarded subject in an enclosing scope (fail-closed)" } }
        if (!drive && !cov) continue
        paired = 0
        if (SNF[fi, k] > USED[L] + 0) { USED[L]++; paired = 1 }
        else { P = PREV[fi, L]; if (!(L in AVU) && P > 0 && ((fi SUBSEP P) in FXL) && !(P in DRV)) { AVU[L] = 1; paired = 1 } }
        DRV[L]++
        if (cov && paired && SC[fi, k] > 0 && !(SC[fi, k] in COV)) COV[SC[fi, k]] = 1
        if (drive && !paired && ty == "C") { a = SC[fi, k]
          while (a > 0) { if (a in COV) { if (COV[a] == 1) { COV[a] = 2; paired = 1 } break } a = SPAR[fi, a] } }
        if (!drive || paired) continue
        print "E\t" fx "\t" disp(PNAME[fi]) ":" L "\t" why " -- an unrouted in-process pass: call fx_inproc <subject> on the line before it and declare the pass as an inproc: row" ((fi SUBSEP k) in SWK ? "; this drive runs in a bash -c worker, where fx_inproc is undefined unless the parent runs export -f fx_inproc or the worker sources lib/mutant.sh behind ok/bad stubs" : "") "\t" SX[fi, k] } } }
  print "OPENED\t" (ARGC - 2 - UNREAD) }
'

# P2_NARROWING -- HOW THE FALSE-POSITIVE SET REACHED ITS FLOOR, measured with this scan over the whole tree at the
# change that shipped it (273 run.sh; rows are (fixture, site) pairs, a site shared by a shard stub or a declarer
# counted once per fixture):
#   4578  the contract grammar as first written. Two scanner errors carried it: the assignment-prefix strip in
#         cmdpos ate `o="$(f "$d"` whole, so every argument inside a `$( )` read as a command word; and a
#         backslash-continued line's first word read as a command.  -> 1133: the strip stops at `( ) \` ; & |`, and a
#         continuation line opens no command position.
#   1133  `"$X" args` program starts read as drives by the expansion rule. -> 774: arithmetic `$(( ))`/`(( ))` is
#         masked, and an expansion command word is resolved through its assignments: a value with a `/` (a path, so a
#         program start the counter already sees) or a non-entry word is no drive; only an entry name or an
#         unresolvable value is.
#   774   `eval NAME=...`, `eval "f() {...}"`, case patterns (`"$X"|y)`), `${X:-bash}`, `$(command -v date)`, `$BASH`.
#         -> 674: eval is judged by the first word it evaluates (an assignment or a definition is inert); a word
#         followed by `)` with no open `(` before it is a case pattern; `${X:-d}` reads d; `$(command -v X)`,
#         `$(which X)` and `$BASH` are program paths.
#   674   positional operands (`. "$1"`, `local v="$2"`) unresolvable. -> 595: P2-U, the leveled resolver (a variable,
#         one level of `$OTHER` inheritance or of same-file call-site arguments).
#   595   fixture-local functions sharing a subject function name (adversarial-shard-merge's sha_of, readset-stage1-
#         verdict's seed_run), array literals `t=("$1")`, and `--until` read as the keyword. -> 571: a name the
#         fixture's own files define is the local function; `=(` opens no command position; a keyword needs a blank
#         or an operator before it.
#   571   ANSI-C `$'...\'...'` read as a quote toggle, desynchronising the cross-line stack. -> 566.
#   The stack was then audited for files ending inside a quote (an unbalanced end means a desync): 5 files. Fixing the
#   three causes -- a `<<` inside a multi-line string opened a heredoc (opens_m now reads the cross-line mask), a nested
#   `${a[@]+"${a[@]}"}` closed at its inner brace, and `( export A=1; f )` stripped as one assignment -- left 0 files
#   unbalanced and UNCOVERED rows the desync had hidden (layer-contract-conformance:866/869/1035, the contract's
#   `( vem_entry` spelling), for a floor of 579 rows over 242 distinct sites in 43 fixtures: 140 entry calls and 4
#   unguarded sources (true unrouted passes, every one pre-existing), 62 unresolvable sources and 36 unresolvable
#   command words (the contract's FAIL-CLOSED rule firing where no literal resolves; each is enumerated in the
#   release's report, and none is a scanner misreading).
#   THEN, the tip adversary's B1 (a `{ }` group or function body is no closed scope) and B2 (case arms read) moved it to
#   582; the lead ruling N-prime (command words: an entry name fires ungated, an unresolvable word only after a guarded
#   source in scope; positionals through callers anywhere in the population, read by index) to 522 rows over 214 sites
#   in 42 fixtures: 357 TRUE (entry calls, entry-resolving words, unguarded sources) and 165 GATED (unresolvable sources
#   in a fixture with an unguarded subject, and unresolvable words after a guarded source).
#   THEN the one-level helper gate (13 sources on the corpus gate as helpers, the row set unchanged) and the lead
#   ruling OPTION S (a positional reads the union of every caller argument, index-free) moved it to 524 rows over 215
#   sites in 43 fixtures, 357 TRUE and 167 GATED, on this tree: 6 rows added, every one a PHANTOM -- readset-skip/run.sh:3242
#   in its 4 fixtures and spec-join-integrity/run.sh:1651 (a `. "$1"` whose other caller arguments are unresolvable),
#   remediator-shard-join/unit-reader-a.sh:113 (the `"$@"` after `shift` picks up the mutant path the shift drops) --
#   and 4 removed, readset-skip/run.sh:7856 in its 4 fixtures (a `. "$3"` behind `${3:-}`: a caller passing no third
#   argument read as unresolvable by index adds nothing to the union, and every third argument passed resolves).
# fxc_p2_scan <root> <work dir>: ARM P2's scan over <root>/core/fixtures, writing <work>/p2.raw (its `E` rows and one
# `OPENED\t<n>` row). Six execs whatever the fixture count, none per fixture: the inputs.decl parse (FXC_REQ_AWK over
# every file), fxc_impl_of over every run.sh, two `sort -u`, ONE fxc_guarded over the union of subjects, and ONE scan
# awk over the plan, the subjects and the population. Returns 2 (REFUSED) when the scan awk exits non-zero or opened a
# number of files other than the number listed: an awk that died on one file silently drops every file after it.
fxc_p2_scan() {
  local root="$1" w="$2" d fx f p mark impl T=$'\t' nq rc k v opened=""
  : > "$w/p2.plan"; : > "$w/p2.subj"; : > "$w/p2.pop"; : > "$w/p2.raw"
  set --
  for d in "$root"/core/fixtures/*/; do
    d="${d%/}"
    [ -f "$d/run.sh" ] && [ ! -e "$d/.undeclarable" ] && [ -f "$d/inputs.decl" ] || continue
    if [ $# -eq 0 ]; then set -- "$d/inputs.decl"; else set -- "$@" "$d/inputs.decl"; fi
  done
  [ $# -gt 0 ] || { printf 'OPENED\t0\n' > "$w/p2.raw"; return 0; }
  LC_ALL=C awk -v tag=1 "$FXC_REQ_AWK" "$@" > "$w/p2.req" || return 2
  for f in "$@"; do
    d="${f%/inputs.decl}"; fx="${d##*/}"
    for p in "$d"/*.sh; do [ -f "$p" ] && printf 'J\t%s\t%s\n' "$fx" "$p" >> "$w/p2.plan" && printf '%s\n' "$p" >> "$w/p2.pop"; done
  done
  while IFS="$T" read -r mark f p; do
    d="${f%/inputs.decl}"; fx="${d##*/}"
    case "$p" in core/fixtures/*.sh) [ -f "$root/$p" ] && printf 'J\t%s\t%s\n' "$fx" "$root/$p" >> "$w/p2.plan" && printf '%s\n' "$root/$p" >> "$w/p2.pop" ;; esac
    [ "$mark" = '!' ] || continue
    fxc_subject_kind "$root/$p"; [ "$FXC_KIND" = bash ] || continue
    printf 'S\t%s\t%s\n' "$fx" "$root/$p" >> "$w/p2.plan"
    if [ ! -f "$root/$p" ]; then printf 'M\t%s\n' "$root/$p" >> "$w/p2.plan"
    else printf '%s\n' "$root/$p" >> "$w/p2.subj"; fi
  done < "$w/p2.req"
  # Shard stubs: the IMPL's run.sh and its directory's .sh, judged under the stub's own subjects.
  set --
  for f in "$root"/core/fixtures/*/run.sh; do
    d="${f%/run.sh}"
    [ ! -e "$d/.undeclarable" ] && [ -f "$d/inputs.decl" ] || continue
    if [ $# -eq 0 ]; then set -- "$f"; else set -- "$@" "$f"; fi
  done
  [ $# -gt 0 ] && { fxc_impl_of "$@" > "$w/p2.impl" || return 2; }
  [ -f "$w/p2.impl" ] || : > "$w/p2.impl"
  while IFS="$T" read -r f impl; do
    [ "$impl" != '!' ] || continue
    d="${f%/run.sh}"; fx="${d##*/}"
    for p in "$root/core/fixtures/$impl"/*.sh; do [ -f "$p" ] && printf 'J\t%s\t%s\n' "$fx" "$p" >> "$w/p2.plan" && printf '%s\n' "$p" >> "$w/p2.pop"; done
  done < "$w/p2.impl"
  LC_ALL=C sort -u "$w/p2.subj" > "$w/p2.subjs" || return 2
  LC_ALL=C sort -u "$w/p2.pop" > "$w/p2.pops" || return 2
  set --
  while IFS= read -r p; do printf 'Q\t%s\n' "$p" >> "$w/p2.plan"; if [ $# -eq 0 ]; then set -- "$p"; else set -- "$@" "$p"; fi; done < "$w/p2.subjs"
  nq=$#
  if [ "$nq" -gt 0 ]; then fxc_guarded "$@" >> "$w/p2.plan"; fi
  # The population is listed TWICE: the first read collects function definitions, the second scans.
  while IFS= read -r p; do if [ $# -eq 0 ]; then set -- "$p"; else set -- "$@" "$p"; fi; done < "$w/p2.pops"
  while IFS= read -r p; do set -- "$@" "$p"; done < "$w/p2.pops"
  printf 'ROOT\t%s\n' "$root" >> "$w/p2.plan"
  GA="$FXC_GUARD_A" GB="$FXC_GUARD_B" LC_ALL=C awk -v SQ="'" "$FXC_HEREDOC_AWK$FXC_P2_AWK" "$w/p2.plan" "$@" > "$w/p2.raw"; rc=$?
  while IFS="$T" read -r k v; do [ "$k" = OPENED ] && opened="$v"; done < "$w/p2.raw"
  if [ "$rc" != 0 ] || [ "$opened" != "$#" ]; then
    printf 'P2: REFUSED -- the scan awk exited %s and opened %s of the %s file(s) listed, so files after a failure were never scanned\n' "$rc" "${opened:-0}" "$#" >&2
    return 2
  fi
  return 0
}

# fxc_static_join <root>: THE STATIC HALF OF C1-C5, over <root>/core/fixtures/*/run.sh, read through THIS file's own
# parses (fxc_decl_rows, fxc_cells_parse, fxc_guarded) so no grammar is restated. One row per fixture:
#   F\t<fx>                              scanned (every listed run.sh; .undeclarable and undeclared ones too)
#   X\t<fx>\t<reason>                    REFUSED: the dynamic arms cannot pass this tree
#   P\t<fx>                              predicted to pass (the counted run decides)
#   O\t<fx>\t<why>                       out of population (`.undeclarable`, or no inputs.decl)
#   E\t<fx>\t<arm>\t<line>\t<reason>     a static finding: C2 (grammar, a cell subject that is no path row), C4, C5,
#                                        and P2 (fxc_p2_scan, run once over the tree; <line> is `<file>:<line>`; a P2
#                                        row carries a sixth field, the drive line's text with blank runs collapsed)
#   BASEROOT\t<dir> and B\t<fx>\t<file:line>\t<text>   only under `--p2-base <dir>`: the SAME scan over <dir> (the
#                                        push base, materialised by validate-fixture-inprocess.sh), one B row per
#                                        unpaired drive there, for that script's P2 ratchet. No git runs here.
# THE PREDICATE, per subject S (a path row of invocations.decl declaring n starts, a `c+kxglob` row expanded under
# <root>): S passes when n equals its cli+e2e cell count, or when S is the child of a `nested` row and n is at least
# that count; n = 0 always passes. A fixture passes when every S does and it carries no static finding. A REFUSAL IS
# EXACT under J3: the counted run starts S n times, each cell tags exactly one start (C3), so n != cells with no
# nested cover leaves a start untagged (C1) or a cell over- or under-used (C3). A PASS IS A PREDICTION only: which
# start carries which tag is not visible without a run, which is the dynamic judge's job.
fxc_static_join() {
  local root="$1" pbase="${2:-}" d fx w p n c k g tgt raw cf nn guarded T=$'\t' e1 e2 e3 e4 e5 e6
  w="$(mktemp -d "${TMPDIR:-/tmp}/fxc-sj.XXXXXX")" || return 2
  # P2, once over the whole tree before the per-fixture loop; the join awk below reads its rows by fixture.
  fxc_p2_scan "$root" "$w" || { rm -rf "$w"; return 2; }
  if [ -n "$pbase" ]; then
    mkdir "$w/base" && fxc_p2_scan "$pbase" "$w/base" || { rm -rf "$w"; return 2; }
    printf 'BASEROOT\t%s\n' "$pbase"
    while IFS="$T" read -r e1 e2 e3 e4 e5; do [ "$e1" = E ] && printf 'B\t%s\t%s\t%s\n' "$e2" "$e3" "$e5"; done < "$w/base/p2.raw"
  fi
  # C5's guard table, once over the tree: `<subject>\t<G|U>` for every `cli` subject of any cells.decl, from ONE
  # fxc_cells_parse and ONE fxc_guarded over the subjects present as files this shell can OPEN (one awk dies on an
  # unopenable file and drops every file after it). Openability is tested by opening, never by a mode test, which the
  # pre-suite key does not carry (S15, BL-917). A subject absent, unopenable or empty takes no row, so the join awk
  # reads it as unguarded, as a per-subject call printing nothing did.
  set --
  for cf in "$root"/core/fixtures/*/cells.decl; do [ -f "$cf" ] && { : < "$cf"; } 2>/dev/null && set -- "$@" "$cf"; done
  : > "$w/gt"
  if [ $# -gt 0 ]; then
    fxc_cells_parse "$@" | awk -F'\t' '$1 == "R" && $3 == "cli" { print $4 }' | LC_ALL=C sort -u > "$w/cli"
    set --
    while IFS= read -r p; do [ -n "$p" ] && [ -f "$root/$p" ] && { : < "$root/$p"; } 2>/dev/null && set -- "$@" "$root/$p"; done < "$w/cli"
    [ $# -gt 0 ] && R="$root/" awk -F'\t' 'BEGIN { r = ENVIRON["R"]; n = length(r) }
      substr($2, 1, n) == r { print substr($2, n + 1) "\t" $1 }' <(fxc_guarded "$@") > "$w/gt"
  fi
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
    while IFS="$T" read -r c k g tgt raw; do
      [ "$c" = ERR ] && continue
      [ "$c" = INPROC ] && continue
      [ -n "$tgt" ] && [ "$tgt" != '*' ] || continue
      n="$c"
      if [ "$g" != - ]; then n=$((c + k * $(fxc_glob_n "$root" "$g"))); fi
      printf '%s\t%s\n' "$tgt" "$n" >> "$w/n"
    done < "$w/r"
    awk -F'\t' -v fx="$fx" '
      FILENAME == ARGV[1] { N[$1] = $2; next }
      FILENAME == ARGV[2] { G[$1] = $2; next }
      FILENAME == ARGV[3] { if ($1 == "E" && $2 == fx) { print "E\t" fx "\tP2\t" $3 "\t" $4 "\t" $5; bad = 1 } next }
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
            else print "P\t" fx }' "$w/n" "$w/gt" "$w/p2.raw" "$w/c"
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
  local fx="$1" decl="$2" log="$3" root="$4" jl fd inp w rc=0 tot kind c k g tgt raw dcl m n rows p nb nd ns T=$'\t'
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
    while IFS="$T" read -r kind raw; do
      [ "$kind" = ERR ] || continue
      printf '%s: FAIL (J4): malformed invocations.decl row: %s (want `<count> *`, `<count> <path>`, or `<c>+<k>x<glob> <target>`; every row is exact)\n' "$fx" "$raw"; rc=1
    done < "$w/rows"
    awk -F'\t' '$1 != "ERR" && $1 != "INPROC" { print $4 }' "$w/rows" > "$w/tgts"
    n="$(grep -cxF '*' "$w/tgts")" || n=0
    [ "$n" -eq 1 ] || { printf '%s: FAIL (J4): invocations.decl carries %s `*` rows; exactly one is required\n' "$fx" "$n"; rc=1; }
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      printf '%s: FAIL (J4): invocations.decl names %s on more than one row\n' "$fx" "$t"; rc=1
    done <<EOF
$(LC_ALL=C sort "$w/tgts" | uniq -d)
EOF
    while IFS="$T" read -r c k g tgt raw; do
      [ "$c" = ERR ] && continue
      [ -n "$c" ] || continue
      if [ "$c" = INPROC ]; then
        # An `inproc:` row (THE IN-PROCESS PASSES): measured over <log>.inproc, never the start log; a missing log is 0.
        raw="$tgt${raw:+	$raw}"; c="$k"; tgt="$g"; g=-
        if ! grep -qxF -- "$tgt" "$w/req"; then
          printf '%s: FAIL (J4): row "%s" names %s, which is not a `!` (REQUIRED) file line of %s -- an inproc: row binds to the declaration, never a second list\n' "$fx" "$raw" "$tgt" "${inp#"$root"/}"; rc=1; continue
        fi
        m=0; [ -f "$log.inproc" ] && m="$(fxc_count "$log.inproc" "$tgt")"
      elif [ "$tgt" != '*' ]; then
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
    while IFS="$T" read -r kind p; do
      case "$kind" in
        B) nb=$((nb + 1)) ;; D) nd=$((nd + 1)) ;; S) ns=$((ns + 1)) ;;
        G) printf '%s: FAIL (J6): %s is a `!` bash subject with no invocations.decl row -- row to add, measured on this run: %s %s\n' "$fx" "$p" "$(fxc_count "$jl" "$p")" "$p"; rc=1 ;;
      esac
    done < "$w/b2"
    printf 'J6: %s: %s bash subject(s) rowed; outside the population: %s data file(s), %s non-shell script(s)\n' "$fx" "$nb" "$nd" "$ns"
    # THE IN-PROCESS PASSES (J4's duplicate half and J7), judged only when the declaration carries an `inproc:` row or
    # fx_inproc logged a row: with neither, nothing here runs or prints, so the fixture is judged as before (opt-in).
    awk -F'\t' '$1 == "INPROC" { print $3 }' "$w/rows" > "$w/ipt"
    if [ -s "$w/ipt" ] || [ -s "$log.inproc" ]; then
      while IFS= read -r t; do
        [ -n "$t" ] || continue
        printf '%s: FAIL (J4): invocations.decl names inproc:%s on more than one row\n' "$fx" "$t"; rc=1
      done <<EOF
$(LC_ALL=C sort "$w/ipt" | uniq -d)
EOF
      n=0; [ -f "$log.inproc" ] && n="$(awk 'END { print NR }' "$log.inproc")"
      # J7: every logged pass names an `inproc:` row's path, matched as a path row matches a start (normalised, equal
      # or ending in /<path>), through fxc_cells_judge's longest-target match: with no cells declared, every matched
      # row is printed as one C1 row naming its logged path, and an unmatched row prints nothing.
      : > "$w/ipc"
      fxc_cells_judge "$w/ipt" "$w/ipc" "$log.inproc" > "$w/ipj" 2>/dev/null
      awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "C1") M[$3] = 1; next } !($1 in M) && !S[$1]++ { print }' "$w/ipj" "$log.inproc" 2>/dev/null > "$w/ipu"
      if [ ! -s "$w/ipt" ]; then
        printf '%s: FAIL (J7): fx_inproc logged %s in-process pass(es) (%s) and invocations.decl carries no `inproc:` row -- declare each subject as `<N> inproc:<path>`; a fixture never opts out of counting while it still logs\n' \
          "$fx" "$n" "$(head -3 "$w/ipu" | tr '\n' ' ' | sed 's/ $//')"; rc=1
      elif [ -s "$w/ipu" ]; then
        printf '%s: FAIL (J7): %s in-process pass(es) logged by fx_inproc name no `inproc:` row'"'"'s path (%s) -- add the row, or route the pass through a declared subject\n' \
          "$fx" "$(awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "C1") M[$3] = 1; next } !($1 in M) { u++ } END { print u + 0 }' "$w/ipj" "$log.inproc")" "$(head -3 "$w/ipu" | tr '\n' ' ' | sed 's/ $//')"; rc=1
      else
        printf 'ok J7: %s: %s in-process pass(es) over %s inproc: row(s)\n' "$fx" "$n" "$(awk 'END { print NR }' "$w/ipt")"
      fi
    fi
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
# sp_seed: sp_cell that adds no cell when it passes and one FAILING cell when it fails, so the cell count is unchanged
# while green (fixture-invocation-budget pins it) and the probe goes red, with the count off too, when it fails.
sp_seed() { local n0="$SP_N" f0="$SP_FAIL"; sp_cell "$@"; [ "$SP_FAIL" = "$f0" ] && SP_N="$n0"; return 0; }
# THE C-ARM CELLS, both directions, run by fxc_self_probe after the J cells. <S> its scratch dir, <rc> the generated
# counter rc, <bash>. Every world is a fixture dir under $SPR judged in-process by sp_cell with the C arms on; the
# synthetic logs carry the rc's four fields (path, pid, FXCELL, parent pid), and one leg drives the REAL rc.
FXC_SP_CELLS=118
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

# THE IN-PROCESS PASS CELLS (J3, J4 and J7 on `inproc:` rows, and the static P1), both directions, run by fxc_self_probe
# with the C arms off. <S> its scratch dir, <fd> its probe fixture (inputs.decl: !core/scripts/sub.sh, +core/scripts/two.sh),
# <rc> the generated counter rc, <bash>, <mutant.sh> the real core/fixtures/lib/mutant.sh. $SPR/log measures 6 starts,
# 2 of them of sub.sh; ipl is that log plus three passes of sub.sh in its .inproc: the declared path, a mutant copy ending
# in the suffix, and a `..`-spelled path.
fxc_inproc_self_probe() {
  local S="$1" fd="$2" rcf="$3" bash_bin="$4" mlib="$5" o1 o2 r1 r2 g PR
  cp "$SPR/log" "$SPR/ipl"
  printf '%s\n' "$SPR/core/scripts/sub.sh" "/elsewhere/m2/core/scripts/sub.sh" "$SPR/core/fixtures/x/../../scripts/sub.sh" > "$SPR/ipl.inproc"
  ipw() { mkdir -p "$SPR/$1"; cp "$fd/inputs.decl" "$SPR/$1/"; printf '%s\n' "$2" | tr '|' '\n' > "$SPR/$1/invocations.decl"; }
  ipw ipa '6 *|3 inproc:core/scripts/sub.sh'
  sp_cell "IP a decl with only an inproc: row for a started subject FAILs J6 (an inproc: row is no path row)" 1 ipa "$SPR/ipl" "p: FAIL (J6): core/scripts/sub.sh is a"
  ipw ipok '6 *|2 core/scripts/sub.sh|3 inproc:core/scripts/sub.sh'
  sp_cell "IP the correct declaration (path row and inproc: row) passes, all three passes counted" 0 ipok "$SPR/ipl" "ok J7: p: 3 in-process pass(es) over 1 inproc: row(s)"
  ipw ipoff '6 *|2 core/scripts/sub.sh|4 inproc:core/scripts/sub.sh'
  sp_cell "IP an inproc: count off by one FAILs J3" 1 ipoff "$SPR/ipl" 'p: FAIL (J3): row "4 inproc:core/scripts/sub.sh": measured 3, declared 4'
  ipw ipr1 '6 *|2 core/scripts/sub.sh'
  sp_cell "IP passes logged by a fixture with no inproc: row FAIL J7" 1 ipr1 "$SPR/ipl" "p: FAIL (J7): fx_inproc logged 3 in-process pass(es)"
  # The near-miss: no logged row and no inproc: row is quiet, prints nothing of this arm, and an EMPTY .inproc (what
  # hermetic-run.sh leaves on every armed run) judges byte-identically to an absent one.
  cp "$SPR/log" "$SPR/ipe"; : > "$SPR/ipe.inproc"
  o1="$(fxc_judge p "$SPR/ipr1/invocations.decl" "$SPR/log" "$SPR")"; r1=$?
  o2="$(fxc_judge p "$SPR/ipr1/invocations.decl" "$SPR/ipe" "$SPR")"; r2=$?
  if [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$o1" = "$o2" ] && ! grep -q 'J7\|inproc' <<<"$o1"; then
    sp_ok "IP no logged pass and no inproc: row stays QUIET, and an empty .inproc judges byte-identically to none"
  else sp_bad "IP the opt-out near-miss: rc $r1/$r2, identical $([ "$o1" = "$o2" ] && echo yes || echo no): $(printf '%s' "$o2" | tr '\n' ' ')"; fi
  cp "$SPR/log" "$SPR/ipu"; { cat "$SPR/ipl.inproc"; printf '%s\n' "$SPR/core/scripts/xsub.sh"; } > "$SPR/ipu.inproc"
  sp_cell "IP a logged pass of the near-miss xsub.sh names no inproc: row and FAILs J7" 1 ipok "$SPR/ipu" "p: FAIL (J7): 1 in-process pass(es) logged by fx_inproc name no"
  # A pass logged from cwd `/` (`//core/scripts/sub.sh`, normalised to exactly `/core/scripts/sub.sh`) and one logged as
  # `/core/scripts/sub.sh` each match the inproc: row and count; the near miss `/xcore/scripts/sub.sh` matches none.
  cp "$SPR/log" "$SPR/iprl"; printf '%s\n' "//core/scripts/sub.sh" "/core/scripts/sub.sh" > "$SPR/iprl.inproc"
  ipw iproot '6 *|2 core/scripts/sub.sh|2 inproc:core/scripts/sub.sh'
  sp_seed "IP passes logged as //core/scripts/sub.sh and /core/scripts/sub.sh both count for the inproc: row (J3 and J7)" 0 iproot "$SPR/iprl" "ok J7: p: 2 in-process pass(es) over 1 inproc: row(s)"
  cp "$SPR/log" "$SPR/iprlx"; { cat "$SPR/iprl.inproc"; printf '%s\n' "/xcore/scripts/sub.sh"; } > "$SPR/iprlx.inproc"
  sp_seed "IP the near miss /xcore/scripts/sub.sh names no inproc: row and FAILs J7" 1 iproot "$SPR/iprlx" "p: FAIL (J7): 1 in-process pass(es) logged by fx_inproc name no"
  ipw ipmiss '6 *|2 core/scripts/sub.sh|1 inproc:core/scripts/sub.sh'
  sp_cell "IP a declared pass with no .inproc log reads 0 and FAILs J3" 1 ipmiss "$SPR/log" 'row "1 inproc:core/scripts/sub.sh": measured 0, declared 1'
  ipw ipz '6 *|2 core/scripts/sub.sh|0 inproc:core/scripts/sub.sh'
  sp_cell "IP a 0 inproc: row with no .inproc log passes" 0 ipz "$SPR/log" "ok J7: p: 0 in-process pass(es) over 1 inproc: row(s)"
  ipw ipglob '6 *|2 core/scripts/sub.sh|1+1xcore/* inproc:core/scripts/sub.sh'
  sp_cell "IP J4 an inproc: row with a corpus count is malformed" 1 ipglob "$SPR/ipl" "(J4): malformed invocations.decl row: 1+1xcore/* inproc:core/scripts/sub.sh"
  ipw ipdd '6 *|2 core/scripts/sub.sh|3 inproc:core/../core/scripts/sub.sh'
  sp_cell "IP J4 an inproc: path carrying .. is malformed" 1 ipdd "$SPR/ipl" "(J4): malformed invocations.decl row: 3 inproc:core/../core/scripts/sub.sh"
  ipw ipnb '6 *|2 core/scripts/sub.sh|3 inproc:core/scripts/sub.sh|0 inproc:core/scripts/two.sh'
  sp_cell "IP J4 an inproc: row naming a + line, not a ! line, FAILs" 1 ipnb "$SPR/ipl" "names core/scripts/two.sh, which is not a \`!\` (REQUIRED) file line"
  ipw ipdup '6 *|2 core/scripts/sub.sh|3 inproc:core/scripts/sub.sh|3 inproc:core/scripts/sub.sh'
  sp_cell "IP J4 one path on two inproc: rows FAILs" 1 ipdup "$SPR/ipl" "p: FAIL (J4): invocations.decl names inproc:core/scripts/sub.sh on more than one row"
  # END TO END through the REAL mutant.sh fx_inproc under the real rc: a relative and an absolute pass both log the
  # absolute path; a pass with FXCOUNT_LOG unset logs nothing; an unwritable log fails nothing; the script exits 0.
  mkdir -p "$SPR/lpi"; cp "$fd/inputs.decl" "$SPR/lpi/"; printf '2 *\n0 core/scripts/sub.sh\n2 inproc:core/scripts/sub.sh\n' > "$SPR/lpi/invocations.decl"
  printf 'ok() { :; }\nbad() { :; }\n. %s\ncd %s || exit 8\nfx_inproc core/scripts/sub.sh\nfx_inproc %s\n( unset FXCOUNT_LOG; fx_inproc core/scripts/sub.sh ) || exit 9\nFXCOUNT_LOG=%s fx_inproc core/scripts/sub.sh || exit 7\nbash -c :\n' \
    "$mlib" "$SPR" "$SPR/core/scripts/sub.sh" "$S/absent-dir/l" > "$S/inp.sh"
  env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/inp.log" "$bash_bin" "$S/inp.sh" >/dev/null 2>&1; r1=$?
  g="$(awk -v p="$SPR/core/scripts/sub.sh" '$0 == p { n++ } END { print NR ":" n + 0 }' "$S/inp.log.inproc" 2>/dev/null)"
  if [ "$r1" = 0 ] && [ "$g" = "2:2" ] && [ ! -e "$S/absent-dir" ]; then
    sp_ok "E2E the real fx_inproc logs a relative and an absolute pass as one absolute path each, logs nothing unset, and fails nothing unwritable"
  else sp_bad "E2E the real fx_inproc: rc $r1, rows:matched $g, want 0 and 2:2"; fi
  sp_cell "E2E the real fx_inproc's two passes satisfy a 2 inproc: row" 0 lpi "$S/inp.log" "ok J7: p: 2 in-process pass(es) over 1 inproc: row(s)"
  # P2, THE TREE-WIDE IN-PROCESS DRIVE, through fxc_static_join on its own root, BEFORE any corpus: every shape of the
  # contract's list 1-14 but 12 (the unbuilt list), each with its quiet twin, and no fixture opted in by an inproc: row.
  # Subjects: g.sh guarded with a shebang (gmain, gaux above the guard; below() under it), u.sh unguarded with a
  # shebang, gns.sh guarded with NO shebang (gnmain), lib/mutant.sh a library (no shebang, unguarded), and
  # scripts/validate-enforcement-map.sh guarded (vem_entry). pw <fixture> <subjects |-joined> <file> <lines...>.
  PR="$S/proot"; mkdir -p "$PR/core/scripts" "$PR/core/fixtures/lib" "$PR/scripts"
  # g.sh carries invalid UTF-8 bytes, so fxc_guarded reading it unpinned dies under the UTF-8 locale below.
  printf '%s\n' '#!/usr/bin/env bash' $'# bytes \377 \303' 'gmain() { :; }' 'gaux() { :; }' 'gloc() { :; }' "$FXC_GUARD_A" 'below() { :; }' 'gmain' > "$PR/core/scripts/g.sh"
  printf '%s\n' '#!/usr/bin/env bash' ':' > "$PR/core/scripts/u.sh"
  printf '%s\n' 'gnmain() { :; }' "$FXC_GUARD_A" > "$PR/core/scripts/gns.sh"
  printf '%s\n' 'lmain() { :; }' > "$PR/core/fixtures/lib/mutant.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'vem_entry() { :; }' "$FXC_GUARD_A" > "$PR/scripts/validate-enforcement-map.sh"
  # Eight fixtures, the shapes as separate FILES so one static join reads them all: fG fires (each file one shape),
  # fGq holds the paired twins, f10 never sources its subject, fU/fUq the unguarded-subject shapes, fL the library,
  # no-shebang and resolved-variable shapes, and the shard stub sstub with its IMPL simpl. Built with builtins only.
  pw() { local fx="$1" sb="$2" f="$3" d; shift 3; d="$PR/core/fixtures/$fx"
    [ -d "$d" ] || mkdir "$d"
    printf '!%s\n' ${sb//|/ } > "$d/inputs.decl"; printf '1 *\n' > "$d/invocations.decl"
    [ -f "$d/run.sh" ] || printf ':\n' > "$d/run.sh"
    printf '%s\n' "$@" > "$d/$f"; }
  G=core/scripts/g.sh; U=core/scripts/u.sh
  pw fG "$G" run.sh 'f() { . "$1"; }' 'f "$d/core/scripts/g.sh"' 'gmain'
  pw fG "$G" s2.sh 'G="$d/core/scripts/g.sh"' 'f() {' '  fx_inproc "$G"' '  . "$G"' '  gmain' '  gmain' '  gaux' '}'
  pw fG "$G" s3.sh '. "$d/core/scripts/g.sh"' "cat > p <<'EOF'" 'gmain' 'EOF' 'gmain' 'cat <<-EOF' $'\tgmain' $'\tEOF' 'gmain' \
    'cat <<<"x"' 'gmain' 'x=$((1<<k))' 'gmain' '(( m = 1 << k ))' 'gmain' 'y=$((a+b)); cat <<EOF' 'gmain' 'EOF' \
    "jq -n '" '  if . then . else . end' "  gmain'" "printf '%s\\n' a | xargs -I{} bash -c '" '  gmain' "'" \
    $'echo "\303\251 \377 \303"; gmain' 'n="$(grep -c . "$x")"' 'echo ". gmain"'
  pw fG "$G" helper.sh '. "$d/core/scripts/g.sh"' 'gmain'
  pw fG "$G" s9.sh '. "$d/core/scripts/g.sh"' 'out="$(gmain x)"' '( export A=1; gmain )' '"$_m" "$@"' 'eval "$c"' 'command gaux' 'below' 'x="$_m"'
  pw fG "$G" svx.sh 'vin() {' '  local c="$1" v="$2"' '  ( cd "$c" || exit 2' '    . "$v" || exit 2' \
    '    declare -F gmain >/dev/null || exit 3' '    gmain "$@" ) 2>&1' '}' 'vin "$d" "$d/core/scripts/g.sh"'
  pw fG "$G" s3c.sh 'fx_inproc "$d/core/scripts/g.sh"' '. "$d/core/scripts/g.sh"' 'run1() { ( gmain --arms "$1" ) 2>&1; }' 'run2() { ( gmain ) 2>&1; }'
  pw fG "$G" sloc.sh '. "$d/core/scripts/g.sh"' 'gloc'
  pw fG "$G" sdef.sh 'gloc() { :; }' '. "$d/core/scripts/g.sh"' 'gloc'
  pw fGq "$G" sloc.sh '. "$d/core/scripts/g.sh"' 'gloc() { :; }' 'gloc'
  pw fGq "$G" sscope.sh 'gloc() { :; }' '( . "$d/core/scripts/g.sh"; : )' 'gloc'
  pw fGq "$G" sps.sh 'gmain() { :; }' 'x="$( . "$d/core/scripts/g.sh" )"' 'gmain'
  pw fG "$G" s6a.sh 'gmain() { :; }' '{ . "$d/core/scripts/g.sh"; }' 'gmain'
  pw fG "$G" s6b.sh 'gmain() { :; }' 'ld() { . "$d/core/scripts/g.sh"; }' 'ld' 'gmain'
  pw fG "$G" s6f.sh 'gmain() { :; }' '. "$d/helper6x.sh"' 'gmain'
  pw fG "$G" scase.sh '. "$d/core/scripts/g.sh"' 'case "$x" in' '  a) gmain ;;' '  b)' '    gmain ;;' 'esac'
  pw fG "$G" swv.sh "printf '%s\\n' a | xargs -I{} bash -c \"" '  gmain' '"' 'sh -c "gmain"'
  pw fU "$U" s1b.sh 'f() { . "$1"; }' 'f "$d/lib/two.sh"' 'f "$d/core/scripts/u.sh"'
  # N-prime, each FIRES in fG and its twin stays QUIET in fGq (fUq for M4): caller resolution over the population,
  # a word resolving to a subject entry (ungated), an unresolvable word gated by a guarded source in scope.
  pw fG "$G" scl.sh '. "$d/core/scripts/g.sh"' 'fcl() { "$1"; }' 'loc1() { :; }' 'fcl loc1' 'fcl gmain'
  pw fGq "$G" scl.sh '. "$d/core/scripts/g.sh"' 'fcl() { "$1"; }' 'loc1() { :; }' 'fcl loc1' 'fcl loc2'
  pw fG "$G" scu.sh '. "$d/core/scripts/g.sh"' 'fcu() { "$1"; }' 'fcu loc1' 'fcu "$X"'
  pw fGq "$G" scu.sh 'fcu() { "$1"; }' 'fcu loc1' 'fcu "$X"'
  pw fG "$G" sxa.sh 'xrun() { . "$1"; "$2"; }'
  pw fG "$G" sxb.sh 'xrun "$d/core/scripts/g.sh" gmain'
  pw fGq "$G" sxa.sh 'xrun() { . "$1"; "$2"; }'
  pw fGq "$G" sxb.sh 'xrun "$d/core/scripts/g.sh" loc1'
  pw fG "$G" s2a.sh 'a=gmain' 'b="$a"' '"$b"'
  pw fGq "$G" s2a.sh 'a=loc1' 'b="$a"' '"$b"'
  pw fG "$G" sex.sh '. "$X"' 'fn=gmain' '"$fn"'
  pw fGq "$G" sex.sh '. "$X"' '"$Y"'
  pw fG "$G" sm4g.sh '. "$d/core/scripts/g.sh"' '"$Z" "$@"'
  pw fUq "$U" sm4.sh 'fx_inproc u' '. "$d/core/scripts/u.sh"' 'fn=umain' '"$fn" "$@"' '"$Z" "$@"'
  # OPTION S: a positional reads the union of every caller argument, whatever its index and whatever shift precedes it.
  # FIRES: "$@" (sns), a loop whose read sits above its shift (srl), ${@:N} (ssl) and a "$@" forwarded to another
  # function (sfw), none of them behind a source in their file. QUIET: the same loop, and a shifted read, whose every
  # caller argument is a non-entry (fGq srl; squ after a guarded source, so it is resolved, not merely ungated). A `set --` reads unresolvable, gated open by a guarded source above it.
  pw fG "$G" sns.sh 'fns() { "$@"; }' 'fns gmain'
  pw fG "$G" srl.sh 'rl() {' '  while [ $# -gt 0 ]' '  do' '    "$1"' '    shift' '  done' '}' 'rl loc1 gmain'
  pw fGq "$G" srl.sh 'rl() {' '  while [ $# -gt 0 ]' '  do' '    "$1"' '    shift' '  done' '}' 'rl loc1 loc2'
  pw fG "$G" ssl.sh 'fa() { "${@:2}"; }' 'fa x gmain'
  pw fG "$G" sfw.sh 'fv() { "$1"; }' 'fw() { fv "$@"; }' 'fw gmain'
  pw fGq "$G" squ.sh '. "$d/core/scripts/g.sh"' 'fq2() {' '  shift' '  "$1"' '}' 'fq2 loc1 loc2' 'fq2 loc3'
  pw fG "$G" sst.sh '. "$d/core/scripts/g.sh"' 'fs() {' '  set -- a' '  "$@"' '}' 'fs gmain'
  pw fGq "$G" sst.sh 'fs() {' '  set -- a' '  "$@"' '}' 'fs gmain'
  # A positional with NO caller, after a guarded source, is unresolvable and gated open (fires).
  pw fG "$G" snc.sh '. "$d/core/scripts/g.sh"' 'fz() { "$1"; }'
  # THE HELPER GATE: a source of the fixture-local helper.sh (which sources g.sh) gates an unresolvable word open; a
  # source of a local file that sources nothing guarded does not. A guarded source inside a closed ( ) gates nothing
  # outside it, and one BELOW the word gates nothing above it.
  pw fG "$G" shh.sh '. "$d/helper.sh"' '"$X"'
  pw fGq "$G" hnone.sh 'hz=1'
  pw fGq "$G" shq.sh '. "$d/hnone.sh"' '"$X"'
  pw fGq "$G" sns2.sh '( . "$d/core/scripts/g.sh" )' '"$X"'
  pw fGq "$G" sord.sh '"$X"' '. "$d/core/scripts/g.sh"'
  pw fUq "$U" sinh.sh 'B="$d/lib/two.sh"' 'A="$B"' '. "$A"'
  pw fGq "$G" run.sh 'f() { fx_inproc "$1"; . "$1"; gmain; }' 'f "$d/core/scripts/g.sh"'
  pw fGq "$G" s2.sh 'G="$d/core/scripts/g.sh"' 'f() {' '  fx_inproc "$G"' '  . "$G"' '  gmain' '  fx_inproc "$G"' '  gmain' '  fx_inproc "$G"' '  gaux' '}'
  pw fGq "$G" helper.sh '. "$d/core/scripts/g.sh"' 'fx_inproc g' 'gmain'
  pw fGq "$G" svin.sh 'vin() {' '  local c="$1" v="$2"' '  ( cd "$c" || exit 2' '    fx_inproc "$v"' '    . "$v" || exit 2' \
    '    declare -F gmain >/dev/null || exit 3' '    gmain "$@" ) 2>&1' '}' 'vin "$d" "$d/core/scripts/g.sh"'
  pw fGq "$G" svr.sh 'vin() {' '  local c="$1" v="$2"' '  ( cd "$c" || exit 2' '    . "$v" || exit 2' \
    '    declare -F gmain >/dev/null || exit 3' '    fx_inproc "$v"' '    gmain "$@" ) 2>&1' '}' 'vin "$d" "$d/core/scripts/g.sh"'
  pw f10 "$G" run.sh 'gmain'
  pw fU "$U" run.sh 'W="$d/core/scripts/other.sh"' 'W="$X"' '. "$W"'
  pw fU "$U" s8.sh 'f="$d/core/scripts/u.sh"' '. "$f" "$@"'
  pw fU "$U" s1.sh 'f() { . "$1"; }' 'f "$d/core/scripts/u.sh"'
  pw fUq "$U" s1.sh 'f() { . "$1"; }' 'f "$d/lib/two.sh"'
  pw fUq "$U" run.sh 'W="$d/core/scripts/other.sh"' 'W="$d/lib/two.sh"' '. "$W"'
  pw fUq "$U" s8.sh 'f="$d/core/scripts/u.sh"' 'fx_inproc "$f"' '. "$f" "$@"'
  pw fL "core/fixtures/lib/mutant.sh|core/scripts/gns.sh|scripts/validate-enforcement-map.sh" run.sh '. "$d/../lib/mutant.sh"' 'lmain' '. "$d/core/scripts/gns.sh"' 'gnmain'
  pw fL "core/fixtures/lib/mutant.sh|core/scripts/gns.sh|scripts/validate-enforcement-map.sh" s6.sh 'V="$d/scripts/validate-enforcement-map.sh"' '. "$V"' 'vem_entry' \
    'MUT_LIB="$d/lib/mutant.sh"' '. "$MUT_LIB"'
  pw simpl "$G" run.sh '. "$d/core/scripts/u.sh"'
  pw sstub "$U" run.sh 'HERE="$(cd "$(dirname "$0")" && pwd)"' 'IMPL="$HERE/../simpl/run.sh"' 'exec bash "$IMPL" --group a'
  # Run under a UTF-8 locale, so the multibyte and invalid bytes of fG/s3.sh:25 kill any awk on the scan path that
  # is not pinned to LC_ALL=C (the scan then REFUSES and both cells go red). Where that locale is absent the awks fall
  # back to C and the cell cannot fail on the pin: a stated limit, not a pass.
  o1="$(LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fxc_static_join "$PR")"; r1=$?
  g="$(awk -F'\t' '$1 == "E" && $3 == "P2" { print $2 ":" $4 }' <<<"$o1" | LC_ALL=C sort | tr '\n' ' ')"
  local want="fG:fG/helper.sh:2 fG:fG/run.sh:3 fG:fG/s2.sh:6 fG:fG/s2.sh:7 fG:fG/s2a.sh:3 fG:fG/s3.sh:11 fG:fG/s3.sh:13 fG:fG/s3.sh:15 fG:fG/s3.sh:23 fG:fG/s3.sh:25 fG:fG/s3.sh:5 fG:fG/s3.sh:9 fG:fG/s3c.sh:3 fG:fG/s3c.sh:4 fG:fG/s6a.sh:3 fG:fG/s6b.sh:4 fG:fG/s6f.sh:3 fG:fG/s9.sh:2 fG:fG/s9.sh:3 fG:fG/s9.sh:4 fG:fG/s9.sh:5 fG:fG/s9.sh:6 fG:fG/scase.sh:3 fG:fG/scase.sh:5 fG:fG/scl.sh:2 fG:fG/scu.sh:2 fG:fG/sdef.sh:3 fG:fG/sex.sh:3 fG:fG/sfw.sh:1 fG:fG/shh.sh:2 fG:fG/sloc.sh:2 fG:fG/sm4g.sh:2 fG:fG/snc.sh:2 fG:fG/sns.sh:1 fG:fG/srl.sh:4 fG:fG/ssl.sh:1 fG:fG/sst.sh:4 fG:fG/svx.sh:6 fG:fG/swv.sh:2 fG:fG/swv.sh:4 fG:fG/sxa.sh:1 fL:fL/run.sh:4 fL:fL/s6.sh:3 fU:fU/run.sh:3 fU:fU/s1.sh:1 fU:fU/s1b.sh:1 fU:fU/s8.sh:2 sstub:simpl/run.sh:1 "
  [ "$r1" = 0 ] && [ "$g" = "$want" ] && grep -qF 'bash -c worker' <<<"$(awk -F'\t' '$2 == "fG" && $4 == "fG/s3.sh:23"' <<<"$o1")" \
    && sp_ok "P2 FIRES on every seeded drive and names arm P2: a call after f(){ . \"\$1\"; } (1), two of three calls after one paired source (2), a drive after a heredoc, a <<- heredoc, a here-string, \$((1<<k)) and (( << )), inside a bash -c worker and after a multibyte byte (3), a shard stub under its own subjects (4), a guarded no-shebang subject (5), a resolved \$V and an unresolvable two-assignment operand (6), a fixture-local helper (7), an unguarded source (8) and one reached through a positional its same-file caller resolves to that subject (P2-U), a call in \$( ) and in ( export; ), an expansion, an eval and command X (9), vin with no fx_inproc, a subject function another file of the fixture defines (sloc.sh beside sdef.sh), a local definition followed by a source of the subject before the call (sdef.sh), and a file-level paired source feeding two call sites" \
    || sp_bad "P2 the fired set (rc $r1) was [$g], want [$want]"
  g="$(awk -F'\t' '$1 == "P" { print $2 }' <<<"$o1" | LC_ALL=C sort | tr '\n' ' ')"
  # An UNREADABLE listed file refuses the join (rc 2): the scan drops it from its argv and opened != listed.
  chmod a-r "$PR/core/fixtures/fG/helper.sh"; fxc_static_join "$PR" > /dev/null 2>&1; r2=$?; chmod u+r "$PR/core/fixtures/fG/helper.sh"
  [ "$g" = "f10 fGq fUq simpl " ] && [ "$r2" = 2 ] \
    && sp_ok "P2 stays QUIET: the paired twins of 1, 2, 7 and 8 (14), a library source and call (5), MUT_LIB (6), two literal non-subject assignments (6), a positional whose caller passes a lib (P2-U), a heredoc and jq body, grep -c . (10), a call below the guard, a call of a name the fixture defines itself, a fixture that never sources its subject, vin paired at its source and vin paired at its call, and the stub's IMPL under its own subjects" \
    || sp_bad "P2 the quiet set was [$g], want [f10 fGq fUq simpl ]; an unreadable listed file gave rc $r2, want 2"
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
              "0:climbs-above-root:$SPR/core/../../scripts/sub.sh" "1:root-double-slash://core/scripts/sub.sh" \
              "1:root-absolute:/core/scripts/sub.sh" "0:root-near-miss:/xcore/scripts/sub.sh"; do
    w="${spec%%:*}"; r="${spec#*:}"; l="${r%%:*}"; r="${r#*:}"
    printf '%s\t1\n' "$SPR/f/run.sh" "$r" > "$SPR/lognrm-$l"
    case "$l" in root-*) sp_seed "NRM $l counts $w" 0 "nrm$w" "$SPR/lognrm-$l" "ok" ;; *) sp_cell "NRM $l counts $w" 0 "nrm$w" "$SPR/lognrm-$l" "ok" ;; esac
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
  # Its twin: the heredoc CLOSES, and `$((1<<3))`, `$((1<<k))`, `(( m = 1 << k ))` and `<<<` open nothing (the two
  # name-shifted forms once opened a body delimited by `k`), so Mb rowed after all of them counts.
  printf '#!/usr/bin/env bash\n# MUTANT-MATRIX Ma decides=A twins=B\ncat > p <<'"'"'EOF'"'"'\nseed\nEOF\nx=$((1<<3))\ny=$((1<<k))\n(( m = 1 << k ))\ncat <<<"x"\n# MUTANT-MATRIX Mb decides=A twins=B\n' > "$SPR/j5h/run.sh"
  sp_cell "J5 a name rowed after a closed heredoc, shifts in \$(( )) and (( )), and a here-string passes" 0 j5h "$SPR/logm" "ok"
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
  fxc_inproc_self_probe "$S" "$fd" "$rcf" "$bash_bin" "$mlib"
  fxc_cells_self_probe "$S" "$rcf" "$bash_bin"
  rm -rf "$S"
  # The cell count is fixed by construction above; fewer means a cell was skipped without a verdict.
  [ "$SP_N" -eq "$FXC_SP_CELLS" ] || { SP_FAIL=1; SP_OUT="$SP_OUT  FAIL  self-probe ran $SP_N cells, want $FXC_SP_CELLS
"; }
  [ "$SP_FAIL" = 0 ] && return 0
  return 2
}

# fxc_sp_memo: fxc_self_probe, run at most once per FXC_SP_MEMO directory for one content key. FXC_SP_MEMO is a
# directory the CALLER created for its own run (validate-fixture-inprocess.sh exports its private mktemp dir); unset,
# empty or not a directory, the probe runs every time. The key is the sha256 of this file's bytes, of
# core/fixtures/lib/mutant.sh beside it (the probe's E2E loop sources it) and of the bash running it. Only a GREEN
# probe writes `sp-<key>`; a red one writes nothing, so a red probe is never skipped, and a token under any other key
# (another judge, another mutant.sh, another bash) is never read.
fxc_sp_memo() {
  local k
  [ -n "${FXC_SP_MEMO:-}" ] && [ -d "$FXC_SP_MEMO" ] || { fxc_self_probe; return $?; }
  k="$({ cat "$FXC_SELF" "${FXC_SELF%/scripts/*}/core/fixtures/lib/mutant.sh" 2>/dev/null; printf '\n%s\n%s\n' "$BASH" "$BASH_VERSION"; } | shasum -a 256 | cut -c1-64)"
  [ -n "$k" ] && [ -f "$FXC_SP_MEMO/sp-$k" ] && return 0
  fxc_self_probe || return $?
  [ -n "$k" ] && : > "$FXC_SP_MEMO/sp-$k"
  return 0
}

# ---------------------------------------------------------------------------------------------------------------
FXC_FX=""; FXC_DECL=""; FXC_LOG=""; FXC_ROOT=""
case "${1:-}" in
  --impl-of) shift; fxc_impl_of "$@"; exit $? ;;
  --cells-parse) shift; fxc_cells_parse "$@"; exit $? ;;
  --guarded) shift; fxc_guarded "$@"; exit 0 ;;
  --static-join)
    [ -n "${2:-}" ] && [ -d "$2/core/fixtures" ] || { echo "usage: $0 --static-join <root> [--p2-base <dir>]" >&2; exit 2; }
    if [ "${3:-}" = --p2-base ]; then
      [ -n "${4:-}" ] && [ -d "$4/core/fixtures" ] || { echo "usage: $0 --static-join <root> [--p2-base <dir>]" >&2; exit 2; }
      fxc_static_join "$2" "$4"; exit $?
    fi
    fxc_static_join "$2"; exit $? ;;
  --gen-rc) [ $# -eq 2 ] || { echo "usage: $0 --gen-rc <dir>" >&2; exit 2; }; fxc_gen_rc "$2"; exit $? ;;
  --key-rows) [ $# -ge 2 ] && [ -d "$2" ] || { echo "usage: $0 --key-rows <root> [<fixture>...]" >&2; exit 2; }; shift; fxc_key_rows "$@"; exit $? ;;
  --identity-check) fxc_identity_check; exit $? ;;
  --store-key) fxc_store_key; exit $? ;;
  --legacy-ok) [ $# -eq 4 ] || { echo "usage: $0 --legacy-ok <old allowlist> <key rows> <format>" >&2; exit 2; }; fxc_legacy_ok "$2" "$3" "$4"; exit $? ;;
  --self-probe)
    SP_VERBOSE=1; fxc_self_probe; r=$?
    if [ "$r" = 0 ]; then printf 'self-probe: %s cells, all green\n' "$SP_N"; exit 0; fi
    printf 'self-probe: FIXTURE BROKEN\n'; exit 2 ;;
  --b2-census)
    FXC_ROOT="${FXC_SELF%/scripts/*}"
    [ "${2:-}" = --root ] && { [ -n "${3:-}" ] || { echo "usage: $0 --b2-census [--root R]" >&2; exit 2; }; FXC_ROOT="$3"; }
    [ -d "$FXC_ROOT/core/fixtures" ] || { echo "b2-census: REFUSED: no core/fixtures under $FXC_ROOT" >&2; exit 2; }
    fxc_sp_memo || { printf 'b2-census: REFUSED: the self-probe is red\n%s' "$SP_OUT"; exit 2; }
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
