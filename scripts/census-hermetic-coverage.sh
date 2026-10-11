#!/usr/bin/env bash
# census-hermetic-coverage.sh -- run each declared fixture twice, once inside hermetic-run.sh's sandbox and
# once plainly against the real tree, and report every fixture whose sandboxed run asserted something
# different from its plain run.
#
# Usage: census-hermetic-coverage.sh [--root R] [--list "<names>"] [--jobs N] [--out PATH] [--work DIR] [--keep]
#   --root R     the project root (default: walk up from this script, then from the cwd, for a directory
#                holding `.git` and `core/fixtures/` or `tests/fixtures/`). AI_DLC_PROJECT_ROOT is NOT read:
#                hermetic-run.sh sets it to its own sandbox, so a census run inside a sandboxed fixture would
#                otherwise inherit the outer sandbox as its root.
#   --list "a b" restrict the census to these fixture names (default: every fixture dir with inputs.decl)
#   --jobs N     worker pool width (default 4)
#   --out PATH   write the per-fixture TSV to PATH instead of stdout
#   --work DIR   build the scratch tree under DIR (default: a fresh mktemp -d under TMPDIR)
#   --keep       keep the scratch tree (every pair's raw output and the kept hermetic sandbox)
# Exit:  0 = every fixture read EQUAL or LOW-RES
#        1 = at least one row read MISMATCH, FLAKY, UNCOUNTABLE or REFUSED
#        2 = the census could not run: bad arguments, no root, a root with uncommitted changes, an empty
#            fixture list, a failed self-probe, or a plain run that changed the root's git state (the
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
#             the sandbox's own invocation (hermetic-run.sh:510-512) with only the root moved. The TOOL FARM
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
#   REFUSED      hermetic-run exited 2 (note `runner-refused: <its message>`, or `fixture-rc-2` when the
#                runner's rc line says the fixture itself exited 2), or the plain run changed the root's git
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
# multiset of ok/PASS lines. ENVIRON carries the prefixes, because `awk -v` strips a level of escaping.
census_oklines() {
  CN_ROOT="$3" CN_SB="$4" CN_TMP="$5" awk '
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
  if [ "$1" = 2 ]; then v=REFUSED
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

# THE SELF-PROBE runs the normaliser and the classifier over synthetic outputs before any fixture runs, and
# refuses the census unless every case reads its known verdict. Each case is the input that separates one
# wrong classifier from the right one: P2 an rc-only compare, P3 a `0 = 0` EQUAL, P4 an exit 2 scored as a
# mismatch, P5 a digit-normalised multiset; P1 and P6 are the path normalisation it must do, P9 the line
# grammar's near-miss (`okay` is not `ok`).
PROBE_FAILS=0
probe_case() { # <id> <h exit> <h rc> <p rc> <plain text> <hermetic text> <want "verdict direction">
  local got
  printf '%b' "$5" > "$PROBE_DIR/$1.p"; printf '%b' "$6" > "$PROBE_DIR/$1.h"
  census_oklines "$PROBE_DIR/$1.p" "$PROBE_DIR/$1.po" "$PROBE_R" "$PROBE_SB" "$PROBE_X"
  census_oklines "$PROBE_DIR/$1.h" "$PROBE_DIR/$1.ho" "$PROBE_R" "$PROBE_SB" "$PROBE_X"
  got="$(census_classify "$2" "$3" "$4" "$PROBE_DIR/$1.po" "$PROBE_DIR/$1.ho" | cut -f1,2 | tr '\t' ' ')"
  [ "$got" = "$7" ] || { say "self-probe FAILED: case $1 read '$got', want '$7'"; PROBE_FAILS=$((PROBE_FAILS + 1)); }
}
census_selfprobe() {
  PROBE_DIR="$CENSUS_WORK/probe"; mkdir -p "$PROBE_DIR" || return 2
  PROBE_R=/probe/root; PROBE_X=/private/tmp/census-probe-scratch; PROBE_SB="$PROBE_X/htmp/hermetic-run.Q1/sb"
  local r="$PROBE_R" sb="$PROBE_SB" x="$PROBE_X"
  probe_case P1 0 0 0 "ok a\nok b $r/core/x.sh\n  PASS: c\n" "ok a\nok b $sb/core/x.sh\n  PASS: c\n" "EQUAL -"
  probe_case P2 0 0 0 "ok a\nok b\nok c\nok d\n" "ok a\nok b\nok c\n" "MISMATCH PLAIN-MORE"
  probe_case P3 0 0 0 "checked\n" "checked\n" "UNCOUNTABLE -"
  probe_case P4 2 - 0 "ok a\nok b\nok c\n" "hermetic-run: p: declared file absent: data/x\n" "REFUSED -"
  probe_case P5 0 0 0 "ok n=3\nok b\nok c\n" "ok n=2\nok b\nok c\n" "MISMATCH DIFFER"
  probe_case P6 0 0 0 "ok t $x/ptmp/tmp.AAAA/f\nok b\nok c\n" "ok t /tmp/census-probe-scratch/htmp/hermetic-run.Q1/tmp/tmp.BB/f\nok b\nok c\n" "EQUAL -"
  probe_case P7 0 0 0 "ok only\n" "ok only\n" "LOW-RES -"
  probe_case P8 0 0 1 "ok a\nok b\nok c\n" "ok a\nok b\nok c\n" "MISMATCH RC"
  probe_case P9 0 0 0 "ok a\nok b\nok c\nokay extra\n" "ok a\nok b\nok c\n" "EQUAL -"
  probe_case P10 0 0 0 "ok m /var/folders/qr/x1/T/tmp.AAAA\nok b\nok c\n" "ok m /var/folders/qr/x1/T/tmp.BB22\nok b\nok c\n" "EQUAL -"
  [ "$PROBE_FAILS" -eq 0 ] || return 2
  say "self-probe: ok (10 cases)"
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
census_pair_once() {
  local fx="$1" T K B SB hx hrc prc s0 s1 gd n k PLAIN_ROOT
  mkdir -p "$2/htmp" "$2/vs" "$2/phome" "$2/ptmp" || return 2
  T="$(cd "$2" && pwd -P)" || return 2
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
    awk '{ s = $0; sub(/^[[:space:]]+/, "", s); if (substr(s, 1, 1) == "#") next
           if (s ~ /(^|[^A-Za-z0-9_.\/-])git[[:space:]]+[-a-z]/) { f = 1; exit } }
         END { exit f ? 0 : 1 }' "$f" && return 0
  done
  return 1
}

# census_worker <index> <fx>: one row in $CENSUS_WORK/rows/<index>.
census_worker() {
  local i="$1" fx="$2" T row hx hrc prc gd v d pn hn po ho note=- tags=- diff v2 gd2 ps hs
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
  elif [ "$v" = MISMATCH ]; then
    census_pair_once "$fx" "$T/2"
    IFS="$(printf '\t')" read -r _ _ _ gd2 v2 _ < "$T/2/res"
    if [ "$gd2" != - ]; then
      v=REFUSED; d=-; note="gitstate:$gd2 (re-pair)"; printf '%s\n' "$fx" >> "$CENSUS_WORK/STOP"
    elif [ "$v2" = MISMATCH ]; then note="re-pair confirmed"
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
  if [ "$CENSUS_KEEP" != 1 ]; then case "$T" in "$CENSUS_WORK"/p.[0-9]*) rm -rf "$T" ;; esac; fi
  return 0
}

if [ "${1:-}" = --pair ]; then
  [ $# -eq 3 ] && [ -n "${CENSUS_WORK:-}" ] || { say "--pair is internal: --pair <index> <fixture>"; exit 2; }
  census_worker "$2" "$3"; exit 0
fi

ROOT_OPT=""; LIST=""; LIST_SET=0; JOBS=4; OUT=""; WORK_OPT=""; CENSUS_KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || { say "--root needs a value"; exit 2; }; ROOT_OPT="$2"; shift 2 ;;
    --list) [ $# -ge 2 ] || { say "--list needs a value"; exit 2; }; LIST="$2"; LIST_SET=1; shift 2 ;;
    --jobs) [ $# -ge 2 ] || { say "--jobs needs a value"; exit 2; }; JOBS="$2"; shift 2 ;;
    --out) [ $# -ge 2 ] || { say "--out needs a value"; exit 2; }; OUT="$2"; shift 2 ;;
    --work) [ $# -ge 2 ] || { say "--work needs a value"; exit 2; }; WORK_OPT="$2"; shift 2 ;;
    --keep) CENSUS_KEEP=1; shift ;;
    -h|--help) sed -n '2,22p' "$CENSUS_SELF"; exit 0 ;;
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

export CENSUS_ROOT CENSUS_WORK CENSUS_RUNNER CENSUS_TOOLDIRS CENSUS_FXREL CENSUS_PD CENSUS_KEEP
xargs -P "$JOBS" -n 2 bash "$CENSUS_SELF" --pair < "$CENSUS_WORK/list"

TSV="$CENSUS_WORK/census.tsv"
printf '#fixture\tverdict\tdirection\ttags\th_exit\th_rc\tp_rc\tp_ok\th_ok\tplain_only\therm_only\tnote\tdiff\tp_skip\th_skip\n' > "$TSV"
while read -r i fx; do
  if [ -s "$CENSUS_WORK/rows/$i" ]; then cat "$CENSUS_WORK/rows/$i" >> "$TSV"
  else printf '%s\tREFUSED\t-\t-\t-\t-\t-\t-\t-\t-\t-\tthe worker left no row\t-\t-\t-\n' "$fx" >> "$TSV"; fi
done < "$CENSUS_WORK/list"

SUMMARY="$(awk -F'\t' 'NR > 1 { n++; c[$2]++; if ($2 == "MISMATCH" && $3 == "PLAIN-MORE") pm++; if ($4 ~ /NO-GIT-DECL/) ng++ }
  END { printf "fixtures=%d EQUAL=%d LOW-RES=%d MISMATCH=%d FLAKY=%d UNCOUNTABLE=%d REFUSED=%d NOT-RUN=%d plain-more=%d no-git-decl=%d",
        n, c["EQUAL"], c["LOW-RES"], c["MISMATCH"], c["FLAKY"], c["UNCOUNTABLE"], c["REFUSED"], c["NOT-RUN"], pm, ng }' "$TSV")"
if [ -n "$OUT" ]; then cp "$TSV" "$OUT" || exit 2; else cat "$TSV"; fi
say "$SUMMARY"

RC=0
awk -F'\t' 'NR > 1 && $2 != "EQUAL" && $2 != "LOW-RES" { f = 1 } END { exit f ? 0 : 1 }' "$TSV" && RC=1
[ -f "$CENSUS_WORK/STOP" ] && { say "stopped: a plain run changed the root's git state ($(head -1 "$CENSUS_WORK/STOP")); re-run that fixture alone with --jobs 1"; RC=2; }
if [ "$CENSUS_KEEP" = 1 ]; then say "work dir kept: $CENSUS_WORK"
else case "$CENSUS_WORK" in */census.*|*/census-hermetic.*) rm -rf "$CENSUS_WORK" ;; esac; fi
exit "$RC"
