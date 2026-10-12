#!/usr/bin/env bash
# census-hermetic-coverage.sh -- run each declared fixture twice, once inside hermetic-run.sh's sandbox and
# once plainly against the real tree, and report every fixture whose sandboxed run asserted something
# different from its plain run.
#
# Usage: census-hermetic-coverage.sh [--root R] [--list "<names>"] [--jobs N] [--out PATH] [--work DIR]
#                                    [--scratch BASE] [--keep]
#   --root R     the project root (default: walk up from this script, then from the cwd, for a directory
#                holding `.git` and `core/fixtures/` or `tests/fixtures/`). AI_DLC_PROJECT_ROOT is NOT read:
#                hermetic-run.sh sets it to its own sandbox, so a census run inside a sandboxed fixture would
#                otherwise inherit the outer sandbox as its root.
#   --list "a b" restrict the census to these fixture names (default: every fixture dir with inputs.decl)
#   --jobs N     worker pool width (default 4)
#   --out PATH   write the per-fixture TSV to PATH instead of stdout
#   --work DIR   build the work tree (rows, the TSV, the pair links) under DIR (default: a fresh mktemp -d
#                under TMPDIR)
#   --scratch B  the base for each pair's short PHYSICAL scratch root `B/chc.XXXXXX`, which the pair dir in
#                the work tree links to (default /private/tmp). Refused when B or any ancestor carries `.git`,
#                `.claude` or `core/skills/ai-dlc`. A non-keep run removes every chc.* root it made.
#   --keep       keep the work tree and every pair's physical scratch root (raw output, kept sandbox); the
#                roots live under B, so a kept pair does not survive a reboot
# Exit:  0 = every fixture read EQUAL, EQUIVALENT or LOW-RES
#        1 = at least one row read MISMATCH, BOTH-FAIL, FLAKY, UNCOUNTABLE or REFUSED
#        2 = the census could not run: bad arguments, no root, a root with uncommitted changes, an empty
#            fixture list, a failed self-probe, a scratch base with a project marker above it (checked
#            before the run AND again after it), or a plain run that changed the root's git state (the
#            census stops at that fixture and the rest read NOT-RUN)
#
# WHAT IT IS FOR (BL-497, residue a). A fixture with a skip branch for a missing input passes under the
# sandbox with FEWER assertions, and the verdict is PASS. hermetic-run.sh:27-35 records the measured case
# (48 assertions down to 32) and why only a `!` REQUIRED input's sentinel catches it. Nothing else compares a
# sandboxed run's assertions against a plain run's. This does, once, as a census; it is not a gate.
#
# THE TWO RUNS, hermetic first and then plain, never concurrently for one fixture:
#   hermetic  `hermetic-run.sh --root R <fx>` with AI_DLC_HERMETIC_KEEP=1, a per-fixture TMPDIR, and
#             AI_DLC_VERDICT_STORE a fresh directory, so the real store is never written.
#   plain     from the root (never a cd into the fixture dir, which CLAUDE.md measures as five fabricated
#             failures): `env -i PATH=<READSET_TOOL_DIRS>:<kept sandbox>/bin HOME=<scratch> TMPDIR=<scratch>
#             AI_DLC_PROJECT_ROOT=<root> PREPUSH_POOL_DEPTH=<same> bash <fixtures>/<fx>/run.sh`. The env is
#             the sandbox's own invocation (hermetic-run.sh:536-538) with only the root moved. The TOOL FARM
#             is hermetic-run's own kept `bin/`, so a declared tool resolved off git's exec-path or a
#             READSET_TOOL_XP dir reaches both runs; there is no second tools.decl parser here to drift.
#             READSET_TOOL_DIRS comes from the hook's READSET_TOOLS span, the same span hermetic-run sources.
#
# THE COMPARISON. The primary observable is the MULTISET of `^[[:space:]]*(ok|PASS)([[:space:]:]|$)` lines in
# merged stdout+stderr, plus the fixture's exit code (the hermetic side's is read from the runner's own
# `hermetic-run: <fx>: rc=N` line, because the runner's exit folds a missing REQUIRED sentinel into 1 and a
# fixture's own 2 into its refusal code). Lines are normalised ONLY for paths: the kept sandbox root and the
# real root become `<ROOT>`, and any path token under the pair's scratch dir becomes `<TMP>` whole, because
# mktemp suffixes differ between the runs. A path token under the SYSTEM temp dirs (`/var/folders/`, `/tmp/`,
# either with `/private`) becomes `<TMP>` too: macOS `mktemp` with no template answers under the per-user
# `/var/folders/.../T/` whatever TMPDIR says, measured on the seeded fixture's first run, where it split two
# otherwise identical runs. Digits are never normalised: a count that differs IS the finding.
# Both the physical `/private/...` spelling and its `/tmp` or `/var` alias are matched.
#
# VERDICTS, decided in this order:
#   BOTH-FAIL    the fixture exited the SAME non-zero code in both runs (the hermetic rc from the runner's rc
#                line). Never EQUAL: two failing runs agreeing proves nothing about coverage. Exit 1.
#   REFUSED      hermetic-run exited 2 (note `runner-refused: <its message>`, or `fixture-rc-2` when the
#                runner's rc line says the fixture itself exited 2 and the plain run did not; the summary
#                counts `fixture-rc-2` apart from REFUSED), or the plain run changed the root's git
#                state (note `gitstate:<which>`, and the census STOPS: every fixture not yet started reads
#                NOT-RUN). The git state is `git status --porcelain`, `git stash list`, `git worktree list`
#                and the cksum of `<git-common-dir>/ai-dlc-fixture-durations`, taken before and after each
#                plain run. Under --jobs > 1 a change made by one fixture can land inside a NEIGHBOUR's
#                window, and stash and worktree lists are shared with every other checkout of the repo, so
#                a gitstate REFUSED names a fixture to re-run alone with --jobs 1, not a proven offender.
#   UNCOUNTABLE  the plain run printed no ok line. Never `0 = 0` EQUAL: a fixture that reports nothing in
#                this grammar cannot lose an assertion visibly, so it is listed rather than acquitted.
#   EQUAL        same fixture rc, same multiset.            LOW-RES: the same, at 1 or 2 ok lines.
#   MISMATCH     anything else, with a direction: PLAIN-MORE (the plain run asserted more -- the defect this
#                exists for), HERMETIC-MORE, DIFFER (same count, different lines) or RC (lines agree, rc not).
#                Every MISMATCH is re-paired once; a re-pair that does not mismatch turns it into FLAKY.
#   EQUIVALENT   a DIFFER mismatch, confirmed by the re-pair, that reaches the equivalence check (DIFFER at
#                equal rc in both pairs) and is then run a THIRD time: the third pair must also read MISMATCH
#                DIFFER at equal rc, and every differing TOKEN must pass the token rule over all three reps --
#                a sha or mktemp suffix must move, a count's two sides must overlap. Decided by
#                census_equivalent, whose header states the token rule and what it acquits. Exit 0. A third
#                pair that does not mismatch reads FLAKY; one that mismatches another way stays MISMATCH.
#   p_skip/h_skip    informational columns: lines matching `^[[:space:]]*(skip|skipped|SKIP:)`, any case, on
#                each side of the first pair. They decide no verdict.
#   tag NO-GIT-DECL  on a MISMATCH fixture that has no git.decl and whose own *.sh call git: the sandbox is
#                not a repository for it, and `git.decl: seed` is a valid remedy beside declaring an input.
#
# WHAT IT DOES NOT SEE (BL-497, residue b). The sandbox is a copy, not a jail: a fixture that reaches the
# real tree by an absolute path still reads it inside the sandbox, and both runs then agree. A jail was
# drafted and dropped; this census measures (a) only.
#
# It writes nothing to `.git/ai-dlc-fixture-durations` or to the real verdict store, and nothing under the
# root: every scratch path is under the work dir.
set -u
# An inherited GIT_DIR (a hook run from a linked worktree exports it) would redirect every git call below,
# including the git-state snapshot, onto the caller's repository.
for _v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

CENSUS_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"

say() { printf 'census-hermetic-coverage: %s\n' "$*" >&2; }

# census_oklines <raw output> <out> <root> <sandbox root or -> <scratch dir>: the sorted, path-normalised
# multiset of ok/PASS lines. The scratch dir is the pair's PHYSICAL short root (`<base>/chc.XXXXXX`), the
# spelling hermetic-run's `pwd -P` hands the fixture; its `/tmp` alias is matched too.
# ENVIRON carries the prefixes, because `awk -v` strips a level of escaping.
census_oklines() {
  CN_ROOT="$3" CN_SB="$4" CN_TMP="$5" LC_ALL=C awk '
    function alt(p) { return (index(p, "/private/") == 1) ? substr(p, 9) : "" }
    function swap(s, p, rep, whole,    out, i) {
      if (p == "") return s
      out = ""
      while ((i = index(s, p)) > 0) {
        out = out substr(s, 1, i - 1) rep
        s = substr(s, i + length(p))
        if (whole && match(s, TOK)) s = substr(s, RLENGTH + 1)
      }
      return out s
    }
    BEGIN { r = ENVIRON["CN_ROOT"]; b = ENVIRON["CN_SB"]; t = ENVIRON["CN_TMP"]
            if (b == "-") b = ""
            TOK = "^[^[:space:]\"" sprintf("%c", 39) "():,;]*"
            SYSTMP = "(/private)?/(var/folders|tmp)/[^[:space:]\"" sprintf("%c", 39) "():,;]*" }
    /^[[:space:]]*(ok|PASS)([[:space:]:]|$)/ {
      s = $0
      s = swap(s, b, "<ROOT>", 0); s = swap(s, alt(b), "<ROOT>", 0)
      s = swap(s, t, "<TMP>", 1);  s = swap(s, alt(t), "<TMP>", 1)
      s = swap(s, r, "<ROOT>", 0); s = swap(s, alt(r), "<ROOT>", 0)
      gsub(SYSTMP, "<TMP>", s)
      print s
    }' "$1" | LC_ALL=C sort > "$2"
}

# census_classify <hermetic exit> <hermetic fixture rc or -> <plain rc> <plain ok file> <hermetic ok file>
# -> verdict TAB direction TAB plain count TAB hermetic count TAB plain-only TAB hermetic-only
census_classify() {
  local pn hn po ho v d=-
  pn="$(wc -l < "$4" | tr -d ' ')"; hn="$(wc -l < "$5" | tr -d ' ')"
  po="$(LC_ALL=C comm -23 "$4" "$5" | wc -l | tr -d ' ')"
  ho="$(LC_ALL=C comm -13 "$4" "$5" | wc -l | tr -d ' ')"
  if [ "$2" = "$3" ] && [ "$3" != 0 ]; then v=BOTH-FAIL
  elif [ "$1" = 2 ]; then v=REFUSED
  elif [ "$pn" -eq 0 ]; then v=UNCOUNTABLE
  elif [ "$2" = "$3" ] && [ "$po" -eq 0 ] && [ "$ho" -eq 0 ]; then
    v=EQUAL; [ "$pn" -le 2 ] && v=LOW-RES
  else
    v=MISMATCH
    if [ "$pn" -gt "$hn" ]; then d=PLAIN-MORE
    elif [ "$hn" -gt "$pn" ]; then d=HERMETIC-MORE
    elif [ "$po" -gt 0 ]; then d=DIFFER
    else d=RC; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$v" "$d" "$pn" "$hn" "$po" "$ho"
}

# census_equivalent <p1.ok> <h1.ok> <p2.ok> <h2.ok> <p3.ok> <h3.ok>: the TOKEN-LEVEL volatile-token rule over
# a DIFFER row and its two further pairs, all six files census_oklines output. Prints
# `EQUIVALENT <n volatile tokens>` or `MISMATCH <reason>`. A line is cut into its alphanumeric runs; its
# masked KEY replaces each run that is a hex run 7-40 long holding a digit with <SHA>, a 6-long run right
# after a dot with <MKT>, and an all-digit run with <N>; a mixed run (`run1`, `2x`) stays verbatim, so `run1`
# and `run2` are two keys, not one key twice. EQUIVALENT needs all of:
#   - p1 and h1 hold the same multiset of keys;
#   - every key whose raw lines differ between p1 and h1 occurs EXACTLY ONCE in each of the six files, so
#     the p1 line pairs with one h1 line and with one line in each later rep (a repeated key could pair a
#     stable loss with a volatile neighbour);
#   - every run that differs between the paired p1 and h1 lines passes its token rule over the three reps.
#     Judged run by run, never line by line: a line whose sha moves every run and whose count differs stably
#     between the sides is MISMATCH, because the count did not move.
# THE TOKEN RULE has two readings, by what the run IS:
#   NUMERIC  -- the run is all digits in all six lines, whatever its mask (a count of 7+ digits masks as
#               <SHA> and is still a count). EQUIVALENT only when the two sides' observed RANGES overlap:
#               [min, max] of p1/p2/p3 meets [min, max] of h1/h2/h3. Compared as integers by length then
#               bytes, never as floats. validator-fork-budget's live shape -- plain 3335, 3337, 3335 against
#               hermetic 3336 three times -- overlaps and reads EQUIVALENT. A stable 13 against 12, 11, 12, or
#               48 against 32, 31, 32, is disjoint and reads MISMATCH: those are a lost assertion count that
#               happens to flicker on one side, which the earlier "moves on at least one side" reading
#               acquitted over two reps.
#   ANY OTHER (<SHA>, <MKT>) -- EQUIVALENT when the run takes more than one value across the three reps on
#               at least one side. A sha or a mktemp suffix carries no order, so there is no range to meet.
# What it still acquits: a count whose flicker on one side happens to reach the other side's value in one of
# three reps, and a non-numeric token that moves on one side only. Three reps narrow the first; they cannot
# separate the second from noise.
census_equivalent() {
  LC_ALL=C awk '
    function nz(s) { s = s ""; sub(/^0+/, "", s); return (s == "") ? "0" : s }
    function lt(x, y) { x = nz(x); y = nz(y); return (length(x) != length(y)) ? (length(x) < length(y)) : ((x "") < (y "")) }
    function mn3(x, y, z) { if (lt(y, x)) x = y; if (lt(z, x)) x = z; return x }
    function mx3(x, y, z) { if (lt(x, y)) x = y; if (lt(x, z)) x = z; return x }
    function mrun(run, before) {
      if (length(run) >= 7 && length(run) <= 40 && run ~ /^[0-9A-Fa-f]+$/ && run ~ /[0-9]/) return "<SHA>"
      if (before == "." && length(run) == 6) return "<MKT>"
      if (run ~ /^[0-9]+$/) return "<N>"
      return run
    }
    function scan(l,    rest, sep, run, n, before) {
      n = 0; MK = ""; RS1 = ""; rest = l
      while (match(rest, /[0-9A-Za-z]+/)) {
        sep = substr(rest, 1, RSTART - 1); run = substr(rest, RSTART, RLENGTH)
        before = (sep == "") ? "" : substr(sep, length(sep), 1)
        n++; MK = MK sep mrun(run, before); RS1 = RS1 ((n > 1) ? SUBSEP : "") run
        rest = substr(rest, RSTART + RLENGTH)
      }
      MK = MK rest
      return n
    }
    { n = scan($0); cnt[f, MK]++; keys[MK] = 1; tk[f, MK] = RS1; raw[f, $0]++; key[$0] = MK; rl[$0] = 1; tot[f]++ }
    END {
      if (tot[1] != tot[2]) { print "MISMATCH line counts differ"; exit }
      for (k in keys) if (cnt[1, k] != cnt[2, k]) { print "MISMATCH masked lines differ: " k; exit }
      for (l in rl) if (raw[1, l] != raw[2, l]) dk[key[l]] = 1
      nd = 0; nv = 0
      for (k in dk) {
        nd++
        if (cnt[1, k] != 1 || cnt[2, k] != 1 || cnt[3, k] != 1 || cnt[4, k] != 1 || cnt[5, k] != 1 || cnt[6, k] != 1) { print "MISMATCH differing key repeats or is absent in a rep: " k; exit }
        na = split(tk[1, k], a, SUBSEP); nb = split(tk[2, k], b, SUBSEP); nc = split(tk[3, k], c, SUBSEP); ne = split(tk[4, k], e, SUBSEP)
        ng = split(tk[5, k], g, SUBSEP); nh = split(tk[6, k], h, SUBSEP)
        if (na != nb || na != nc || na != ne || na != ng || na != nh) { print "MISMATCH run counts differ under one key: " k; exit }
        for (i = 1; i <= na; i++) if (a[i] != b[i]) {
          if ((a[i] c[i] g[i] b[i] e[i] h[i]) ~ /^[0-9]+$/) {
            if (lt(mx3(a[i], c[i], g[i]), mn3(b[i], e[i], h[i])) || lt(mx3(b[i], e[i], h[i]), mn3(a[i], c[i], g[i]))) {
              print "MISMATCH disjoint count " a[i] "," c[i] "," g[i] "/" b[i] "," e[i] "," h[i] " in: " k; exit
            }
          } else if (a[i] == c[i] && a[i] == g[i] && b[i] == e[i] && b[i] == h[i]) { print "MISMATCH stable token " a[i] "/" b[i] " in: " k; exit }
          nv++
        }
      }
      if (nd == 0) { print "MISMATCH no line differs"; exit }
      print "EQUIVALENT " nv
    }' f=1 "$1" f=2 "$2" f=3 "$3" f=4 "$4" f=5 "$5" f=6 "$6"
}

# THE SELF-PROBE runs the normaliser and the classifier over synthetic outputs before any fixture runs, and
# refuses the census unless every case reads its known verdict. Each case is the input that separates one
# wrong classifier from the right one: P2 an rc-only compare, P3 a `0 = 0` EQUAL, P4 an exit 2 scored as a
# mismatch, P5 a digit-normalised multiset; P1 and P6 are the path normalisation it must do, P9 the line
# grammar's near-miss (`okay` is not `ok`), P11 two failing runs scored EQUAL, P12 the BOTH-FAIL test
# swallowing a sandbox-only exit 2. E1-E7 and FA1-FA2 are census_equivalent: E2 a line-level rule, E3 a rule
# that accepts any masked match, E4 a missing multiplicity guard, E5 that guard refusing everything, FA1 and
# FA2 the "moves on at least one side" reading for a count, E1 a range rule that refuses an overlap, E7 a
# non-numeric token that holds still on both sides.
PROBE_FAILS=0
probe_case() { # <id> <h exit> <h rc> <p rc> <plain text> <hermetic text> <want "verdict direction">
  local got
  printf '%b' "$5" > "$PROBE_DIR/$1.p"; printf '%b' "$6" > "$PROBE_DIR/$1.h"
  census_oklines "$PROBE_DIR/$1.p" "$PROBE_DIR/$1.po" "$PROBE_R" "$PROBE_SB" "$PROBE_X"
  census_oklines "$PROBE_DIR/$1.h" "$PROBE_DIR/$1.ho" "$PROBE_R" "$PROBE_SB" "$PROBE_X"
  got="$(census_classify "$2" "$3" "$4" "$PROBE_DIR/$1.po" "$PROBE_DIR/$1.ho" | cut -f1,2 | tr '\t' ' ')"
  [ "$got" = "$7" ] || { say "self-probe FAILED: case $1 read '$got', want '$7'"; PROBE_FAILS=$((PROBE_FAILS + 1)); }
}
eq_case() { # <id> <p1 text> <h1 text> <p2 text> <h2 text> <p3 text> <h3 text> <want first word>
  local got
  printf '%b' "$2" | LC_ALL=C sort > "$PROBE_DIR/$1.p1"; printf '%b' "$3" | LC_ALL=C sort > "$PROBE_DIR/$1.h1"
  printf '%b' "$4" | LC_ALL=C sort > "$PROBE_DIR/$1.p2"; printf '%b' "$5" | LC_ALL=C sort > "$PROBE_DIR/$1.h2"
  printf '%b' "$6" | LC_ALL=C sort > "$PROBE_DIR/$1.p3"; printf '%b' "$7" | LC_ALL=C sort > "$PROBE_DIR/$1.h3"
  got="$(census_equivalent "$PROBE_DIR/$1.p1" "$PROBE_DIR/$1.h1" "$PROBE_DIR/$1.p2" "$PROBE_DIR/$1.h2" "$PROBE_DIR/$1.p3" "$PROBE_DIR/$1.h3")"
  [ "${got%% *}" = "$8" ] || { say "self-probe FAILED: case $1 read '$got', want '$8'"; PROBE_FAILS=$((PROBE_FAILS + 1)); }
  PROBE_N=$((PROBE_N + 1))
}
# probe_px_rm: the self-probe's physical chc.* root and its link go on EVERY exit path, failure included.
probe_px_rm() { case "${PROBE_PX:-}" in "$CENSUS_SCRATCH"/chc.??????) rm -f "$PROBE_DIR/pair"; rm -rf "$PROBE_PX" ;; esac; }
census_selfprobe() {
  PROBE_DIR="$CENSUS_WORK/probe"; mkdir -p "$PROBE_DIR" || return 2
  # P6 runs on a REAL pair shape: a symlink in the work dir naming a physical chc.* root under the scratch
  # base, resolved the way census_pair_once resolves it, with the hermetic side spelled through the alias.
  local pl="$PROBE_DIR/pair" px
  px="$(mktemp -d "$CENSUS_SCRATCH/chc.XXXXXX")" || return 2
  PROBE_PX="$px"
  printf '%s\n' "$px" >> "$CENSUS_WORK/scratch.list"
  ln -s "$px" "$pl" || { probe_px_rm; return 2; }
  PROBE_X="$(cd "$pl" && pwd -P)" || { probe_px_rm; return 2; }
  case "$PROBE_X" in "$CENSUS_SCRATCH"/chc.??????) ;; *) say "self-probe FAILED: the pair link resolved to $PROBE_X, not a chc.* root under $CENSUS_SCRATCH"; probe_px_rm; return 2 ;; esac
  PROBE_R=/probe/root; PROBE_SB="$PROBE_X/htmp/hermetic-run.Q1/sb"; PROBE_N=0
  local r="$PROBE_R" sb="$PROBE_SB" x="$PROBE_X" xa
  xa="$x"; case "$x" in /private/tmp/*|/private/var/*) xa="${x#/private}" ;; esac
  probe_case P1 0 0 0 "ok a\nok b $r/core/x.sh\n  PASS: c\n" "ok a\nok b $sb/core/x.sh\n  PASS: c\n" "EQUAL -"
  probe_case P2 0 0 0 "ok a\nok b\nok c\nok d\n" "ok a\nok b\nok c\n" "MISMATCH PLAIN-MORE"
  probe_case P3 0 0 0 "checked\n" "checked\n" "UNCOUNTABLE -"
  probe_case P4 2 - 0 "ok a\nok b\nok c\n" "hermetic-run: p: declared file absent: data/x\n" "REFUSED -"
  probe_case P5 0 0 0 "ok n=3\nok b\nok c\n" "ok n=2\nok b\nok c\n" "MISMATCH DIFFER"
  probe_case P6 0 0 0 "ok t $x/ptmp/tmp.AAAA/f\nok b\nok c\n" "ok t $xa/htmp/hermetic-run.Q1/tmp/tmp.BB/f\nok b\nok c\n" "EQUAL -"
  probe_case P7 0 0 0 "ok only\n" "ok only\n" "LOW-RES -"
  probe_case P8 0 0 1 "ok a\nok b\nok c\n" "ok a\nok b\nok c\n" "MISMATCH RC"
  probe_case P9 0 0 0 "ok a\nok b\nok c\nokay extra\n" "ok a\nok b\nok c\n" "EQUAL -"
  probe_case P10 0 0 0 "ok m /var/folders/qr/x1/T/tmp.AAAA\nok b\nok c\n" "ok m /var/folders/qr/x1/T/tmp.BB22\nok b\nok c\n" "EQUAL -"
  # P11: both runs exit the same non-zero code over identical lines -- BOTH-FAIL, never EQUAL.
  probe_case P11 1 1 1 "ok a\nok b\nok c\n" "ok a\nok b\nok c\n" "BOTH-FAIL -"
  # P12: the fixture exited 2 in the sandbox only -- REFUSED (the fixture-rc-2 note), not BOTH-FAIL.
  probe_case P12 2 2 0 "ok a\nok b\nok c\n" "ok a\nok b\nok c\n" "REFUSED -"
  PROBE_N=12
  # E1-E6, FA1-FA2: census_equivalent, reps 1-3 of each side. E1 is validator-fork-budget's live line shape:
  # plain 3335, 3337, 3335 against hermetic 3336 three times -- the ranges overlap.
  local fp='PASS  validator-fork-budget -- %s fork(s) of FORK_BUDGET=3339 across 284 fixture dirs; 6 arms green, 13/13 mutants killed\nok    A1 floor       -- %s forks is above the broken-subject floor of 1\nok    A3 ceiling     -- %s <= FORK_BUDGET=3339\nok    tail\n'
  eq_case E1 "$(printf "$fp" 3335 3335 3335)" "$(printf "$fp" 3336 3336 3336)" "$(printf "$fp" 3337 3337 3337)" "$(printf "$fp" 3336 3336 3336)" \
    "$(printf "$fp" 3335 3335 3335)" "$(printf "$fp" 3336 3336 3336)" EQUIVALENT
  # E2: one line, a sha that moves every run AND a count that differs stably between the sides.
  eq_case E2 "ok at abc1234 counted 13 of 13\nok b\n" "ok at def5678 counted 12 of 12\nok b\n" \
    "ok at 0123fed counted 13 of 13\nok b\n" "ok at 9876aaa counted 12 of 12\nok b\n" \
    "ok at 4567bcd counted 13 of 13\nok b\n" "ok at 7654dcb counted 12 of 12\nok b\n" MISMATCH
  eq_case E3 "ok 13 of 13 killed\nok b\n" "ok 12 of 12 killed\nok b\n" "ok 13 of 13 killed\nok b\n" "ok 12 of 12 killed\nok b\n" \
    "ok 13 of 13 killed\nok b\n" "ok 12 of 12 killed\nok b\n" MISMATCH
  # E4: the differing key occurs twice on each side: n=1 against n=2 is stable in every rep, its neighbour
  # moves. Without the multiplicity guard only one line per key is compared, and it is the volatile one.
  eq_case E4 "ok n=1\nok n=7\nok b\n" "ok n=2\nok n=8\nok b\n" "ok n=1\nok n=9\nok b\n" "ok n=2\nok n=6\nok b\n" \
    "ok n=1\nok n=5\nok b\n" "ok n=2\nok n=4\nok b\n" MISMATCH
  # E5: a key repeated with AGREEING lines beside a volatile single key -- EQUIVALENT (the E4 near-miss).
  eq_case E5 "ok r 1\nok r 2\nok at abc1234\n" "ok r 1\nok r 2\nok at def5678\n" "ok r 1\nok r 2\nok at 0123fed\n" "ok r 1\nok r 2\nok at 9876aaa\n" \
    "ok r 1\nok r 2\nok at 4567bcd\n" "ok r 1\nok r 2\nok at 7654dcb\n" EQUIVALENT
  eq_case E6 "ok at abc1234\nok b\n" "ok at def5678\nok b\n" "ok at 0123fed\nok b\n" "ok at 9876aaa\nok b\n" \
    "ok at 4567bcd\nok b\n" "ok at 7654dcb\nok b\n" EQUIVALENT
  # E7: a sha that differs between the sides and holds still on BOTH across three reps -- the non-numeric
  # stable test's own subject, since every count above is now judged by its range instead.
  eq_case E7 "ok at abc1234\nok b\n" "ok at def5678\nok b\n" "ok at abc1234\nok b\n" "ok at def5678\nok b\n" \
    "ok at abc1234\nok b\n" "ok at def5678\nok b\n" MISMATCH
  # FA1, FA2: a count STABLE on the plain side and flickering on the hermetic side, never reaching it. The
  # "moves on at least one side" reading acquitted both; the range rule keeps them.
  eq_case FA1 "ok 13 mutants killed\nok b\n" "ok 12 mutants killed\nok b\n" "ok 13 mutants killed\nok b\n" "ok 11 mutants killed\nok b\n" \
    "ok 13 mutants killed\nok b\n" "ok 12 mutants killed\nok b\n" MISMATCH
  eq_case FA2 "ok 48 assertions\nok b\n" "ok 32 assertions\nok b\n" "ok 48 assertions\nok b\n" "ok 31 assertions\nok b\n" \
    "ok 48 assertions\nok b\n" "ok 32 assertions\nok b\n" MISMATCH
  probe_px_rm
  [ "$PROBE_FAILS" -eq 0 ] || return 2
  say "self-probe: ok ($PROBE_N cases)"
}

# census_gitstate -> one line per component of the root's git state; a plain run must leave all four alone.
census_gitstate() {
  ( cd "$CENSUS_ROOT" || exit 2
    printf 'status %s\n' "$(git status --porcelain 2>&1 | cksum | tr -s ' ' '.')"
    printf 'stash %s\n' "$(git stash list 2>&1 | cksum | tr -s ' ' '.')"
    printf 'worktree %s\n' "$(git worktree list --porcelain 2>&1 | cksum | tr -s ' ' '.')"
    c="$(git rev-parse --git-common-dir 2>/dev/null)" || c=.git
    if [ -f "$c/ai-dlc-fixture-durations" ]; then
      printf 'durations %s\n' "$(cksum < "$c/ai-dlc-fixture-durations" | tr -s ' ' '.')"
    else printf 'durations absent\n'; fi )
}

# census_pair_once <fx> <dir>: one hermetic run, then one plain run; writes <dir>/res as
# h_exit TAB h_rc TAB p_rc TAB gitstate-change TAB <census_classify fields>, and <dir>/diff.
# <dir> is a SYMLINK to the pair's short physical scratch root `$CENSUS_SCRATCH/chc.XXXXXX`, so every path a
# fixture sees (its TMPDIR, HOME, the kept sandbox) is short and outside the work dir. Measured: under a long
# scratch path a fixture printing a path length or a here-document temp size reads one figure per side.
census_pair_once() {
  local fx="$1" T K B SB hx hrc prc s0 s1 gd n k PLAIN_ROOT
  if [ ! -e "$2" ]; then
    mkdir -p "$(dirname "$2")" || return 2
    T="$(mktemp -d "$CENSUS_SCRATCH/chc.XXXXXX")" || return 2
    printf '%s\n' "$T" >> "$CENSUS_WORK/scratch.list"
    ln -s "$T" "$2" || return 2
  fi
  T="$(cd "$2" && pwd -P)" || return 2
  mkdir -p "$T/htmp" "$T/vs" "$T/phome" "$T/ptmp" || return 2
  ( cd "$CENSUS_ROOT" && AI_DLC_HERMETIC_KEEP=1 TMPDIR="$T/htmp" AI_DLC_VERDICT_STORE="$T/vs" \
      PREPUSH_POOL_DEPTH="$CENSUS_PD" bash "$CENSUS_RUNNER" --root "$CENSUS_ROOT" "$fx" ) > "$T/h.raw" 2>&1 < /dev/null; hx=$?
  hrc="$(CN_FX="$fx" awk 'BEGIN { p = "hermetic-run: " ENVIRON["CN_FX"] ": rc=" }
    index($0, p) == 1 { s = substr($0, length(p) + 1); sub(/[^0-9].*$/, "", s); if (s != "") r = s }
    END { print (r == "") ? "-" : r }' "$T/h.raw")"
  # The kept sandbox: exactly one hermetic-run.* under this pair's TMPDIR, or no farm at all.
  K=""; n=0
  for k in "$T"/htmp/hermetic-run.*; do [ -d "$k" ] && { n=$((n + 1)); K="$k"; }; done
  [ "$n" = 1 ] || K=""
  if [ -n "$K" ]; then K="$(cd "$K" && pwd -P)"; B="$K/bin"; SB="$K/sb"; else B="$T/no-farm"; SB="-"; fi
  s0="$(census_gitstate)"
  PLAIN_ROOT="$CENSUS_ROOT"
  ( cd "$PLAIN_ROOT" && exec env -i PATH="$CENSUS_TOOLDIRS:$B" HOME="$T/phome" TMPDIR="$T/ptmp" AI_DLC_PROJECT_ROOT="$PLAIN_ROOT" PREPUSH_POOL_DEPTH="$CENSUS_PD" bash "$CENSUS_FXREL/$fx/run.sh" ) > "$T/p.raw" 2>&1 < /dev/null; prc=$?
  s1="$(census_gitstate)"
  printf '%s\n' "$s0" > "$T/git.before"; printf '%s\n' "$s1" > "$T/git.after"
  gd="$(awk 'NR == FNR { a[$1] = $0; next } a[$1] != $0 { printf "%s%s", sep, $1; sep = "+" }' "$T/git.before" "$T/git.after")"
  [ -n "$gd" ] || gd=-
  census_oklines "$T/p.raw" "$T/p.ok" "$CENSUS_ROOT" "$SB" "$T"
  census_oklines "$T/h.raw" "$T/h.ok" "$CENSUS_ROOT" "$SB" "$T"
  { LC_ALL=C comm -23 "$T/p.ok" "$T/h.ok" | head -3 | sed 's/^/P: /'
    LC_ALL=C comm -13 "$T/p.ok" "$T/h.ok" | head -3 | sed 's/^/H: /'
  } | tr '\t' ' ' | awk '{ printf "%s%s", sep, $0; sep = " | " }' > "$T/diff"
  printf '%s\t%s\t%s\t%s\t%s\n' "$hx" "$hrc" "$prc" "$gd" "$(census_classify "$hx" "$hrc" "$prc" "$T/p.ok" "$T/h.ok")" > "$T/res"
}

# census_calls_git <fixture dir>: 0 when a non-comment line of the fixture's own *.sh invokes git.
census_calls_git() {
  local f
  for f in "$1"/*.sh; do
    [ -f "$f" ] || continue
    LC_ALL=C awk '{ s = $0; sub(/^[[:space:]]+/, "", s); if (substr(s, 1, 1) == "#") next
           if (s ~ /(^|[^A-Za-z0-9_.\/-])git[[:space:]]+[-a-z]/) { f = 1; exit } }
         END { exit f ? 0 : 1 }' "$f" && return 0
  done
  return 1
}

# census_worker <index> <fx>: one row in $CENSUS_WORK/rows/<index>.
census_worker() {
  local i="$1" fx="$2" T row hx hrc prc gd v d pn hn po ho note=- tags=- diff v2 gd2 hrc2 prc2 d2 v3 gd3 hrc3 prc3 d3 eqv ps hs k ph
  row="$CENSUS_WORK/rows/$i"
  if [ -f "$CENSUS_WORK/STOP" ]; then
    printf '%s\tNOT-RUN\t-\t-\t-\t-\t-\t-\t-\t-\t-\tcensus stopped at %s\t-\t-\t-\n' "$fx" "$(head -1 "$CENSUS_WORK/STOP")" > "$row"
    return 0
  fi
  T="$CENSUS_WORK/p.$i"
  census_pair_once "$fx" "$T/1"
  IFS="$(printf '\t')" read -r hx hrc prc gd v d pn hn po ho < "$T/1/res"
  diff="$(cat "$T/1/diff")"
  if [ "$gd" != - ]; then
    v=REFUSED; d=-; note="gitstate:$gd"; printf '%s\n' "$fx" >> "$CENSUS_WORK/STOP"
  elif [ "$v" = REFUSED ]; then
    if [ "$hrc" = - ]; then note="runner-refused: $(grep -m1 '^hermetic-run: ' "$T/1/h.raw" | tr '\t' ' ' | cut -c1-200)"
    else note="fixture-rc-$hrc"; fi
  elif [ "$v" = BOTH-FAIL ]; then
    note="both runs exited $prc"
  elif [ "$v" = MISMATCH ]; then
    census_pair_once "$fx" "$T/2"
    IFS="$(printf '\t')" read -r _ hrc2 prc2 gd2 v2 d2 _ < "$T/2/res"
    if [ "$gd2" != - ]; then
      v=REFUSED; d=-; note="gitstate:$gd2 (re-pair)"; printf '%s\n' "$fx" >> "$CENSUS_WORK/STOP"
    elif [ "$v2" = MISMATCH ]; then
      note="re-pair confirmed"
      if [ "$d" = DIFFER ] && [ "$d2" = DIFFER ] && [ "$hrc" = "$prc" ] && [ "$hrc2" = "$prc2" ]; then
        # The THIRD pair: two reps cannot tell a count that flickers on one side from one that overlaps the
        # other side, so a row reaching the equivalence check is run once more and judged over three reps.
        census_pair_once "$fx" "$T/3"
        IFS="$(printf '\t')" read -r _ hrc3 prc3 gd3 v3 d3 _ < "$T/3/res"
        if [ "$gd3" != - ]; then
          v=REFUSED; d=-; note="gitstate:$gd3 (third pair)"; printf '%s\n' "$fx" >> "$CENSUS_WORK/STOP"
        elif [ "$v3" != MISMATCH ]; then
          v=FLAKY; note="third pair read $v3"
        elif [ "$d3" != DIFFER ] || [ "$hrc3" != "$prc3" ]; then
          note="re-pair confirmed; third pair read MISMATCH $d3 at rc $prc3/$hrc3"
        else
          eqv="$(census_equivalent "$T/1/p.ok" "$T/1/h.ok" "$T/2/p.ok" "$T/2/h.ok" "$T/3/p.ok" "$T/3/h.ok" | tr '\t' ' ' | cut -c1-200)"
          case "$eqv" in
            'EQUIVALENT '*) v=EQUIVALENT; note="volatile token(s) ${eqv#EQUIVALENT }, each passing its rule over three reps" ;;
            *) note="re-pair confirmed; ${eqv:-MISMATCH equivalence check printed nothing}" ;;
          esac
        fi
      fi
    else v=FLAKY; note="re-pair read $v2"; fi
  fi
  if [ "$v" = MISMATCH ] && [ ! -f "$CENSUS_ROOT/$CENSUS_FXREL/$fx/git.decl" ] && census_calls_git "$CENSUS_ROOT/$CENSUS_FXREL/$fx"; then
    tags=NO-GIT-DECL
  fi
  [ -n "$diff" ] || diff=-
  # Skip-line counts are INFORMATIONAL and decide no verdict: a skip branch that replaces an ok line already
  # moves the multiset, and one that adds a SKIP line beside unchanged ok lines shows up here instead.
  ps="$(grep -ciE '^[[:space:]]*(skip|skipped|SKIP:)' "$T/1/p.raw")" || ps=0
  hs="$(grep -ciE '^[[:space:]]*(skip|skipped|SKIP:)' "$T/1/h.raw")" || hs=0
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$fx" "$v" "$d" "$tags" "$hx" "$hrc" "$prc" "$pn" "$hn" "$po" "$ho" "$note" "$diff" "$ps" "$hs" > "$row"
  if [ "$CENSUS_KEEP" != 1 ]; then
    # The pair dirs are symlinks: removing $T removes the links and leaks the physical roots, so each physical
    # root is removed on its own, and only when it is one of this census's chc.* dirs under the scratch base.
    for k in "$T/1" "$T/2" "$T/3"; do
      [ -L "$k" ] || continue
      ph="$(cd "$k" 2>/dev/null && pwd -P)" || continue
      case "$ph" in "$CENSUS_SCRATCH"/chc.??????) rm -rf "$ph" ;; esac
    done
    case "$T" in "$CENSUS_WORK"/p.[0-9]*) rm -rf "$T" ;; esac
  fi
  return 0
}

if [ "${1:-}" = --pair ]; then
  [ $# -eq 3 ] && [ -n "${CENSUS_WORK:-}" ] || { say "--pair is internal: --pair <index> <fixture>"; exit 2; }
  census_worker "$2" "$3"; exit 0
fi

ROOT_OPT=""; LIST=""; LIST_SET=0; JOBS=4; OUT=""; WORK_OPT=""; CENSUS_KEEP=0; SCRATCH_OPT=/private/tmp
[ -d /private/tmp ] || SCRATCH_OPT=/tmp
while [ $# -gt 0 ]; do
  case "$1" in
    --scratch) [ $# -ge 2 ] || { say "--scratch needs a value"; exit 2; }; SCRATCH_OPT="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || { say "--root needs a value"; exit 2; }; ROOT_OPT="$2"; shift 2 ;;
    --list) [ $# -ge 2 ] || { say "--list needs a value"; exit 2; }; LIST="$2"; LIST_SET=1; shift 2 ;;
    --jobs) [ $# -ge 2 ] || { say "--jobs needs a value"; exit 2; }; JOBS="$2"; shift 2 ;;
    --out) [ $# -ge 2 ] || { say "--out needs a value"; exit 2; }; OUT="$2"; shift 2 ;;
    --work) [ $# -ge 2 ] || { say "--work needs a value"; exit 2; }; WORK_OPT="$2"; shift 2 ;;
    --keep) CENSUS_KEEP=1; shift ;;
    -h|--help) sed -n '2,/^# WHAT IT IS FOR/p' "$CENSUS_SELF" | sed '$d'; exit 0 ;;
    *) say "unknown argument: $1"; exit 2 ;;
  esac
done
case "$JOBS" in ''|*[!0-9]*|0) say "--jobs wants a positive integer, got '$JOBS'"; exit 2 ;; esac

census_find_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != / ] && [ "$d" != . ]; do
    if [ -e "$d/.git" ] && { [ -d "$d/core/fixtures" ] || [ -d "$d/tests/fixtures" ]; }; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
CENSUS_ROOT="$ROOT_OPT"
[ -n "$CENSUS_ROOT" ] || CENSUS_ROOT="$(census_find_root "$(dirname "$CENSUS_SELF")")" || CENSUS_ROOT=""
[ -n "$CENSUS_ROOT" ] || CENSUS_ROOT="$(census_find_root "$(pwd -P)")" || CENSUS_ROOT=""
[ -n "$CENSUS_ROOT" ] || { say "no project root: pass --root, or run from inside a tree holding .git and core/fixtures/"; exit 2; }
CENSUS_ROOT="$(cd "$CENSUS_ROOT" 2>/dev/null && pwd -P)" || { say "--root is not a directory"; exit 2; }

CENSUS_FXREL=""
for c in core/fixtures tests/fixtures; do [ -d "$CENSUS_ROOT/$c" ] && { CENSUS_FXREL="$c"; break; }; done
CENSUS_RUNNER=""
for c in core/scripts/hermetic-run.sh scripts/ai-dlc/hermetic-run.sh; do [ -f "$CENSUS_ROOT/$c" ] && { CENSUS_RUNNER="$CENSUS_ROOT/$c"; break; }; done
HOOK=""
for c in .githooks/pre-push core/git-hooks/pre-push; do [ -f "$CENSUS_ROOT/$c" ] && { HOOK="$CENSUS_ROOT/$c"; break; }; done
[ -n "$CENSUS_FXREL" ] || { say "no core/fixtures/ or tests/fixtures/ under $CENSUS_ROOT"; exit 2; }
[ -n "$CENSUS_RUNNER" ] || { say "no hermetic-run.sh under $CENSUS_ROOT"; exit 2; }
[ -n "$HOOK" ] || { say "no pre-push hook under $CENSUS_ROOT to take READSET_TOOL_DIRS from"; exit 2; }

if [ -n "$(cd "$CENSUS_ROOT" && git status --porcelain 2>&1)" ]; then
  say "$CENSUS_ROOT has uncommitted or untracked changes; the plain runs need a clean root, and a dirty one would hide a fixture that writes into it"
  exit 2
fi

if [ -n "$WORK_OPT" ]; then
  mkdir -p "$WORK_OPT" || exit 2
  CENSUS_WORK="$(mktemp -d "$WORK_OPT/census.XXXXXX")" || exit 2
else
  CENSUS_WORK="$(mktemp -d "${TMPDIR:-/tmp}/census-hermetic.XXXXXX")" || exit 2
fi
CENSUS_WORK="$(cd "$CENSUS_WORK" && pwd -P)" || exit 2
case "$CENSUS_WORK/" in "$CENSUS_ROOT"/*) say "the work dir $CENSUS_WORK is inside the root"; exit 2 ;; esac
mkdir -p "$CENSUS_WORK/rows" || exit 2

# THE SCRATCH BASE. Each pair runs in its own `<base>/chc.XXXXXX`. A project marker in any ancestor of the
# base would be found by a fixture whose validator walks up for its root from the sandbox, and the census would
# then score that stray marker rather than the fixture, so the base is refused unless the walk is clean.
census_marker_walk() { # <dir>: prints the first `<dir or ancestor>/<marker>` that exists; 1 when none does
  local d="$1" m
  while :; do
    for m in .git .claude core/skills/ai-dlc; do
      [ -e "${d%/}/$m" ] && { printf '%s\n' "${d%/}/$m"; return 0; }
    done
    [ -n "$d" ] && [ "$d" != / ] || return 1
    d="$(dirname "$d")"
  done
}
[ -d "$SCRATCH_OPT" ] || { say "--scratch $SCRATCH_OPT is not a directory"; exit 2; }
CENSUS_SCRATCH="$(cd "$SCRATCH_OPT" && pwd -P)" || exit 2
case "$CENSUS_SCRATCH/" in "$CENSUS_ROOT"/*) say "the scratch base $CENSUS_SCRATCH is inside the root"; exit 2 ;; esac
if hit="$(census_marker_walk "$CENSUS_SCRATCH")"; then
  say "the scratch base $CENSUS_SCRATCH has a project marker above it ($hit); a fixture walking up for its root would find it -- pass --scratch with a clean base"
  exit 2
fi
: > "$CENSUS_WORK/scratch.list"

sed -n '/^# READSET_TOOLS_BEGIN$/,/^# READSET_TOOLS_END$/p' "$HOOK" > "$CENSUS_WORK/tools.sh"
READSET_TOOL_DIRS=""
grep -q '^READSET_TOOL_DIRS=' "$CENSUS_WORK/tools.sh" && . "$CENSUS_WORK/tools.sh"
[ -n "$READSET_TOOL_DIRS" ] || { say "$HOOK carries no READSET_TOOLS span with READSET_TOOL_DIRS"; exit 2; }
CENSUS_TOOLDIRS="$READSET_TOOL_DIRS"
CENSUS_PD="${PREPUSH_POOL_DEPTH:-}"

census_selfprobe || exit 2

: > "$CENSUS_WORK/list"
if [ "$LIST_SET" = 1 ]; then
  i=0
  for fx in $LIST; do i=$((i + 1)); printf '%04d %s\n' "$i" "$fx" >> "$CENSUS_WORK/list"; done
else
  i=0
  for d in "$CENSUS_ROOT/$CENSUS_FXREL"/*/; do
    [ -f "${d}inputs.decl" ] || continue
    i=$((i + 1)); printf '%04d %s\n' "$i" "$(basename "$d")" >> "$CENSUS_WORK/list"
  done
fi
N="$(grep -c . "$CENSUS_WORK/list")" || N=0
[ "$N" -gt 0 ] || { say "the fixture list is empty"; exit 2; }
say "root $CENSUS_ROOT, $N fixture(s), $JOBS job(s), work dir $CENSUS_WORK"

export CENSUS_ROOT CENSUS_WORK CENSUS_RUNNER CENSUS_TOOLDIRS CENSUS_FXREL CENSUS_PD CENSUS_KEEP CENSUS_SCRATCH
xargs -P "$JOBS" -n 2 bash "$CENSUS_SELF" --pair < "$CENSUS_WORK/list"

TSV="$CENSUS_WORK/census.tsv"
printf '#fixture\tverdict\tdirection\ttags\th_exit\th_rc\tp_rc\tp_ok\th_ok\tplain_only\therm_only\tnote\tdiff\tp_skip\th_skip\n' > "$TSV"
while read -r i fx; do
  if [ -s "$CENSUS_WORK/rows/$i" ]; then cat "$CENSUS_WORK/rows/$i" >> "$TSV"
  else printf '%s\tREFUSED\t-\t-\t-\t-\t-\t-\t-\t-\t-\tthe worker left no row\t-\t-\t-\n' "$fx" >> "$TSV"; fi
done < "$CENSUS_WORK/list"

# REFUSED splits in two: `fixture-rc-2` is the fixture itself exiting 2 in the sandbox (a result about the
# fixture); the rest are the runner or the census refusing (a result about the harness).
SUMMARY="$(awk -F'\t' 'NR > 1 { n++; c[$2]++; if ($2 == "MISMATCH" && $3 == "PLAIN-MORE") pm++; if ($4 ~ /NO-GIT-DECL/) ng++
                               if ($2 == "REFUSED" && $12 ~ /^fixture-rc-/) frc++ }
  END { printf "fixtures=%d EQUAL=%d EQUIVALENT=%d LOW-RES=%d MISMATCH=%d BOTH-FAIL=%d FLAKY=%d UNCOUNTABLE=%d REFUSED=%d fixture-rc-2=%d NOT-RUN=%d plain-more=%d no-git-decl=%d",
        n, c["EQUAL"], c["EQUIVALENT"], c["LOW-RES"], c["MISMATCH"], c["BOTH-FAIL"], c["FLAKY"], c["UNCOUNTABLE"], c["REFUSED"] - frc, frc, c["NOT-RUN"], pm, ng }' "$TSV")"
if [ -n "$OUT" ]; then cp "$TSV" "$OUT" || exit 2; else cat "$TSV"; fi
say "$SUMMARY"

RC=0
awk -F'\t' 'NR > 1 && $2 != "EQUAL" && $2 != "LOW-RES" && $2 != "EQUIVALENT" { f = 1 } END { exit f ? 0 : 1 }' "$TSV" && RC=1
[ -f "$CENSUS_WORK/STOP" ] && { say "stopped: a plain run changed the root's git state ($(head -1 "$CENSUS_WORK/STOP")); re-run that fixture alone with --jobs 1"; RC=2; }
# The walk again: a marker that appeared above the scratch base DURING the run (a fixture wrote one) may have
# been found by every fixture that ran after it, so no row of this run can be trusted.
if end_hit="$(census_marker_walk "$CENSUS_SCRATCH")"; then
  hit="$end_hit"
  say "a project marker appeared above the scratch base during the run ($hit); every row after it may have resolved that marker as its root -- remove it and re-run"
  RC=2
fi
# A run that did not give every listed fixture a row (stopped, killed, a worker lost) keeps its work dir: the rows
# already written are the only record of the pairs that finished, and a resume takes the missing names with --list.
# The pair dirs are symlinks into the scratch base, which a reboot clears: a kept pair survives only until then.
MISSING="$(while read -r i fx; do [ -s "$CENSUS_WORK/rows/$i" ] || printf '%s ' "$fx"; done < "$CENSUS_WORK/list")"
if [ "$CENSUS_KEEP" = 1 ]; then
  say "work dir kept: $CENSUS_WORK; its pair dirs link to physical scratch roots under $CENSUS_SCRATCH, listed in $CENSUS_WORK/scratch.list, which do not survive a reboot"
  while read -r k; do [ -d "$k" ] && say "  kept scratch root: $k"; done < "$CENSUS_WORK/scratch.list"
elif [ -n "$MISSING" ]; then say "work dir kept, the run is incomplete: $CENSUS_WORK; no row for: $MISSING (kept pairs live under $CENSUS_SCRATCH and do not survive a reboot)"
  # A stopped or killed worker never reached its own cleanup, so every physical root it made is still there.
  # They are named here, from the work dir's record, so the operator can clear each by its literal path.
  LEFT=0
  while read -r k; do
    [ -d "$k" ] || continue
    case "$k" in "$CENSUS_SCRATCH"/chc.??????) LEFT=$((LEFT + 1)); say "  left scratch root: $k" ;; esac
  done < "$CENSUS_WORK/scratch.list"
  say "$LEFT physical scratch root(s) left under $CENSUS_SCRATCH (recorded in $CENSUS_WORK/scratch.list); clear each by the path above"
else case "$CENSUS_WORK" in */census.*|*/census-hermetic.*) rm -rf "$CENSUS_WORK" ;; esac; fi
exit "$RC"
