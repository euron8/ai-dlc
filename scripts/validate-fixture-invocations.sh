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
# THE COUNTER. BASH_ENV names an rc whose self-removing DEBUG trap appends one row `<BASH_SOURCE[0] or -c>\t<pid>`
# to $FXCOUNT_LOG at the first command of every bash start: nested, inside `$( )`, and `bash -c` included. The
# whole trap is wrapped in `{ } 2>/dev/null`, so xtrace output is unchanged and an unwritable log writes nothing.
# A START UNDER A FILE-SIZE LIMIT (`ulimit -f 0`) MUST BEHAVE AS IT WOULD UNCOUNTED, and it is still counted. The plain
# append there raises SIGXFSZ, which under the default disposition KILLED the bash before its first command (rc 153,
# the subject never ran), and under `trap '' XFSZ` failed and left the row in the printf buffer, flushed onto the
# subject's own stdout by its next builtin print. Measured on postcompact-rulebook-recovery's s_killed arm: the killed
# gate write never happened, so its M9-inplace and M-unlink flips vanished armed only. So the trap ignores XFSZ for the
# append, drops the stale buffer with an `echo` to /dev/null, and on a refused append records the start as a SYMLINK
# `<log>.lim.<random>` whose target is the row: a symlink is not a regular-file write and no file-size limit binds it.
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
#   <c>+<k>x<glob> *       measured must equal c + k * (number of paths matching <glob> under the sandbox root), for a
#                          fixture whose start count is a function of a corpus. Allowed on a <path> row too. <glob> is
#                          root-relative, has no `..` and no blank, and is expanded by bash 3.2 pathname expansion:
#                          `*` never crosses a `/` (there is no globstar), so a nested corpus spells one glob per level.
#   <n>±<k> <path> why=<the loop that retries or polls> provisional
#                          THE TOLERANCE ROW, `*` allowed as the path: passes iff |measured - n| <= k. Its reason: count
#                          drift from a timing-dependent loop (a retry or a poll whose iteration count follows load),
#                          MEASURED as two counting sweeps disagreeing on the same tree, and PROVISIONAL until that loop
#                          is made deterministic, when the row returns to exact. No `why=`, no trailing `provisional`,
#                          k < 2, or a malformed n or k is a J4 FAIL. Every accepted measurement prints
#                          `provisional: <fx> <path> n=<n> k=<k> measured=<m>`, so the population of tolerance rows shows
#                          on every run; nothing here lists the fixtures that carry one. Every other row stays exact.
# THE ARMS.
#   J1  the start log absent or empty -> BROKEN. run.sh is itself a start, so a counted run logs at least one row; an
#       empty log means the counter never loaded and nothing below would be a measurement.
#   J2  no invocations.decl -> FAIL, printing the measured rows as the declaration to write.
#   J3  measured != declared on any row -> FAIL, naming fixture, row, measured, declared and the remedy.
#   J4  grammar: a malformed row, a duplicate path, no `*` row or two, a path row naming no `!` line -> FAIL.
#   J5  every mutant name core/fixtures/lib/mutant.sh's mutant_killed appended to <log>.mutants must carry a
#       `# MUTANT-MATRIX <name> ...` or `# MUTANT-MATRIX-FULL <name> ...` row in the fixture's run.sh (a shard stub
#       `exec bash "$IMPL" --group ...` is joined against its IMPL's run.sh). A name with no row, or with a
#       `# MUTANT-MATRIX-CONTROL <name>` row, FAILs. The join sees only kills scored through mutant_killed: a battery
#       on scripts/mutant-kills-allowlist.txt emits its kills its own way and is covered by the static join alone.
#       EXEMPT: a fixture (a shard stub resolved to its IMPL) that is a row of scripts/fixture-matrix-allowlist.txt,
#       validate-fixture-hygiene.sh's derived down-only H5 allowlist of batteries with no block yet, is not joined;
#       J5 prints `J5 EXEMPT, not judged` for it, never the ok line alone. An absent allowlist exempts nothing.
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
{ trap '{ trap - DEBUG; trap "" XFSZ; printf "%s\t%s\n" "${BASH_SOURCE[0]:-${BASH_EXECUTION_STRING:+-c}}" "$$" >> "$FXCOUNT_LOG" || { echo > /dev/null; /bin/ln -s "${BASH_SOURCE[0]:-${BASH_EXECUTION_STRING:+-c}}	$$" "$(/usr/bin/mktemp -u "$FXCOUNT_LOG.lim.XXXXXXXX")"; }; trap - XFSZ; } 2>/dev/null' DEBUG; } 2>/dev/null
RC
  printf '%s\n' "$1/fxcount.rc"
}

# fxc_count <log> <path>: rows whose first field equals <path> or ends in /<path>
fxc_count() {
  P="$2" awk -F'\t' 'BEGIN { p = ENVIRON["P"]; s = "/" p; ls = length(s) }
    $1 == p || (length($1) > ls && substr($1, length($1) - ls + 1) == s) { n++ } END { print n + 0 }' "$1"
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

# fxc_judge <fixture> <decl> <log> <root>: messages on stdout; returns 0 pass, 1 FAIL, 2 BROKEN.
fxc_judge() {
  local fx="$1" decl="$2" log="$3" root="$4" jl fd inp w rc=0 tot kind c k g tgt raw dcl m n rows
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
  [ -f "$inp" ] && awk '{ sub(/\r$/, "") } $0 == "" || /^#/ { next }
      { r = 0; while ((ch = substr($0, 1, 1)) == "!" || ch == "+") { if (ch == "!") r = 1; $0 = substr($0, 2) }
        if (r && $0 !~ /\/$/) print }' "$inp" > "$w/req"
  tot="$(awk 'END { print NR }' "$jl")"
  if [ ! -f "$decl" ]; then
    printf '%s: FAIL (J2): no invocations.decl in the fixture directory. Measured on this run -- write this as %s/invocations.decl:\n' "$fx" "${fd#"$root"/}"
    printf '  %s *\n' "$tot"
    while IFS= read -r p; do
      n="$(fxc_count "$jl" "$p")"; [ "$n" -gt 0 ] && printf '  %s %s\n' "$n" "$p"
    done < "$w/req"
    rc=1
  else
    # J4: one normalised row per line: `<c>\t<k>\t<glob or ->\t<target>\t<raw>`, or `ERR\t<raw>`.
    awk '{ sub(/\r$/, "") } $0 ~ /^[[:blank:]]*$/ || $0 ~ /^[[:blank:]]*#/ { next }
      { raw = $0
        if ($1 ~ /±/) {
          # The tolerance row: `<n>±<k> <target> why=<the loop> provisional`. Every clause is required.
          if (NF < 4 || $3 !~ /^why=./ || $NF != "provisional") { print "ERR\t" raw; next }
          p = index($1, "±"); n = substr($1, 1, p - 1); kk = substr($1, p + length("±"))
          if (n !~ /^(0|[1-9][0-9]*)$/ || kk !~ /^[1-9][0-9]*$/ || kk + 0 < 2) { print "ERR\t" raw; next }
          print n "\t" kk "\t±\t" $2 "\t" raw; next }
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
        print "ERR\t" raw }' "$decl" > "$w/rows"
    while IFS="$(printf '\t')" read -r kind raw; do
      [ "$kind" = ERR ] || continue
      printf '%s: FAIL (J4): malformed invocations.decl row: %s (want `<count> *`, `<count> <path>`, `<c>+<k>x<glob> <target>` or `<n>±<k> <target> why=<loop> provisional` with k >= 2)\n' "$fx" "$raw"; rc=1
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
      if [ "$g" = "±" ]; then
        if [ "$m" -ge $((c - k)) ] && [ "$m" -le $((c + k)) ]; then
          printf 'provisional: %s %s n=%s k=%s measured=%s\n' "$fx" "$tgt" "$c" "$k" "$m"
        else
          printf '%s: FAIL (J3): row "%s": measured %s, outside the provisional bound %s±%s -- %s\n' "$fx" "$raw" "$m" "$c" "$k" "$FXC_REMEDY_TAIL"
          rc=1
        fi
        continue
      fi
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
fxc_self_probe() {
  local S fd bash_bin rcf
  S="$(mktemp -d "${TMPDIR:-/tmp}/fxc-sp.XXXXXX")" || { echo "FIXTURE BROKEN: self-probe cannot mktemp"; return 2; }
  S="$(cd "$S" && pwd -P)"
  SPR="$S/root"; fd="$SPR/f"
  mkdir -p "$fd" "$SPR/core/scripts" "$SPR/core/sub" || return 2
  printf ':\n' > "$SPR/core/scripts/sub.sh"; printf ':\n' > "$SPR/core/scripts/two.sh"
  printf '# probe\n!core/scripts/sub.sh\n+core/scripts/two.sh\n!core/sub/\n' > "$fd/inputs.decl"
  # Two starts of sub.sh (the declared path, and a mutant copy ending in the same suffix) and two near-misses a
  # suffix match without its `/` boundary, or a basename match, would count: xcore/scripts/sub.sh, core/scripts/xsub.sh.
  printf '%s\t1\n' "$SPR/f/run.sh" "$SPR/core/scripts/sub.sh" "/elsewhere/m1/core/scripts/sub.sh" "$SPR/xcore/scripts/sub.sh" "$SPR/core/scripts/xsub.sh" "-c" > "$SPR/log"
  : > "$SPR/empty"
  # J1 both directions
  SPN=j1; mkdir -p "$SPR/$SPN"; cp "$fd/inputs.decl" "$SPR/$SPN/"; printf '6 *\n' > "$SPR/$SPN/invocations.decl"
  sp_cell "J1 absent log is BROKEN" 2 "$SPN" "$SPR/nolog" "(J1)"
  sp_cell "J1 empty log is BROKEN" 2 "$SPN" "$SPR/empty" "(J1)"
  sp_cell "J1 a 6-row log passes" 0 "$SPN" "$SPR/log" "6 start(s)"
  # J2 both directions
  mkdir -p "$SPR/j2"; cp "$fd/inputs.decl" "$SPR/j2/"
  sp_cell "J2 no declaration FAILs and prints the declaration" 1 j2 "$SPR/log" "  6 *"
  sp_cell "J2 the printed declaration carries the path row (suffix match, near-miss excluded)" 1 j2 "$SPR/log" "  2 core/scripts/sub.sh"
  printf '6 *\n2 core/scripts/sub.sh\n' > "$SPR/j2/invocations.decl"
  sp_cell "J2 the printed declaration, written, passes" 0 j2 "$SPR/log" "ok"
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
  # The tolerance row, both directions. The log measures 6 starts and 2 of sub.sh.
  for spec in "in:5±2 * why=poll provisional|2 core/scripts/sub.sh:0:provisional: p * n=5 k=2 measured=6" \
              "edge:8±2 * why=poll provisional|2 core/scripts/sub.sh:0:provisional: p * n=8 k=2 measured=6" \
              "out:9±2 * why=poll provisional|2 core/scripts/sub.sh:1:outside the provisional bound 9±2" \
              "path:6 *|4±2 core/scripts/sub.sh why=retry provisional:0:provisional: p core/scripts/sub.sh n=4 k=2 measured=2" \
              "nowhy:6±2 * because=poll provisional|2 core/scripts/sub.sh:1:(J4)" \
              "noprov:6±2 * why=poll|2 core/scripts/sub.sh:1:(J4)" \
              "k1:6±1 * why=poll provisional|2 core/scripts/sub.sh:1:(J4)" \
              "badn:6x±2 * why=poll provisional|2 core/scripts/sub.sh:1:(J4)" \
              "exact:5 *|2 core/scripts/sub.sh:1:measured 6, declared 5"; do
    SPN="tol${spec%%:*}"; r="${spec#*:}"; want="${r#*:}"; want="${want#*:}"; wrc="${r#*:}"; wrc="${wrc%%:*}"; r="${r%%:*}"
    mkdir -p "$SPR/$SPN"; cp "$fd/inputs.decl" "$SPR/$SPN/"
    printf '%s\n' "$r" | tr '|' '\n' > "$SPR/$SPN/invocations.decl"
    sp_cell "J3/J4 tolerance ${spec%%:*}" "$wrc" "$SPN" "$SPR/log" "$want"
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
  mkdir -p "$SPR/lim"; cp "$fd/inputs.decl" "$SPR/lim/"; printf '1 *\n' > "$SPR/lim/invocations.decl"
  sp_cell "E2E a start under ulimit -f 0, default XFSZ, is counted (1 start)" 0 lim "$S/lim-dfl.log" "1 start(s)"
  sp_cell "E2E a start under ulimit -f 0, XFSZ ignored, is counted (1 start)" 0 lim "$S/lim-ign.log" "1 start(s)"
  # The seeded loop through the REAL mutant.sh: an unrowed name FAILs J5, the same loop rowed passes.
  local mlib="${FXC_SELF%/scripts/*}/core/fixtures/lib/mutant.sh"
  if [ ! -f "$mlib" ]; then sp_bad "E2E the real core/fixtures/lib/mutant.sh is absent beside this script ($mlib)"
  else
    mkdir -p "$SPR/lp"; cp "$fd/inputs.decl" "$SPR/lp/"; printf '2 *\n' > "$SPR/lp/invocations.decl"
    printf 'ok() { :; }\nbad() { :; }\n. %s\nfor m in La Lb; do mutant_killed 1 "$m" x; done\nbash -c :\n' "$mlib" > "$SPR/lp/loop.sh"
    env -i PATH="/usr/bin:/bin" BASH_ENV="$rcf" FXCOUNT_LOG="$S/lp.log" "$bash_bin" "$SPR/lp/loop.sh" >/dev/null 2>&1
    printf '#!/usr/bin/env bash\n# MUTANT-MATRIX La decides=A twins=B\n' > "$SPR/lp/run.sh"
    sp_cell "E2E a loop reporting an unrowed name through mutant_killed FAILs J5" 1 lp "$S/lp.log" "reported Lb, which has no"
    printf '# MUTANT-MATRIX Lb decides=A twins=B\n' >> "$SPR/lp/run.sh"
    sp_cell "E2E the same loop with its row passes" 0 lp "$S/lp.log" "ok"
  fi
  rm -rf "$S"
  # The cell count is fixed by construction above; fewer means a cell was skipped without a verdict.
  [ "$SP_N" -eq 53 ] || { SP_FAIL=1; SP_OUT="$SP_OUT  FAIL  self-probe ran $SP_N cells, want 53
"; }
  [ "$SP_FAIL" = 0 ] && return 0
  return 2
}

# ---------------------------------------------------------------------------------------------------------------
FXC_FX=""; FXC_DECL=""; FXC_LOG=""; FXC_ROOT=""
case "${1:-}" in
  --impl-of) shift; fxc_impl_of "$@"; exit $? ;;
  --gen-rc) [ $# -eq 2 ] || { echo "usage: $0 --gen-rc <dir>" >&2; exit 2; }; fxc_gen_rc "$2"; exit $? ;;
  --self-probe)
    SP_VERBOSE=1; fxc_self_probe; r=$?
    if [ "$r" = 0 ]; then printf 'self-probe: %s cells, all green\n' "$SP_N"; exit 0; fi
    printf 'self-probe: FIXTURE BROKEN\n'; exit 2 ;;
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
