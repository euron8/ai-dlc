#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# preclassify-rename-row — a file upstream RENAMED between base and theirs must classify
# as a delete of the old path plus an add of the new one, never as one six-field row.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `git diff --name-status` pairs a delete and a byte-identical add into ONE row,
# `R100<TAB>old<TAB>new`. preclassify.sh reads that stream with `read -r status path`, so
# `path` receives "old<TAB>new" joined: map_consumer() maps only the leading path, the
# consumer hash of the joined string is MISSING, and the row lands in the M arm as
# UPSTREAM-MOD+consumer-deleted->CLASSIFY -- a semantic-merge task for a file nobody
# edited -- carrying six tab-separated fields where every reader expects four.
#
# Measured on the reference consumer's 0.489.0 -> 0.490.0 dry run, the first pull after
# the first rename ever committed under core/ (a fixture transcript). Ground truth there:
# the consumer's copy of the old path equalled the base blob and theirs' new path was that
# same blob, so the correct verdicts are UPSTREAM-DELETED (gated) for the old path and
# UPSTREAM-ONLY-ADD for the new one -- exactly what the D and A arms already emit once the
# row is split. The fix is `--no-renames` on that one diff.
#
# Every assertion is PRESENCE-shaped: a named bucket on a named path. A subject that emits
# nothing fails A, B and C by construction, and the four-field arm is paired with a row
# count so an empty stream cannot satisfy it.
#
# THE SHAPE OF THIS FIXTURE. Every question is a CELL, a function returning 0 (the arm held) or
# 1 (the arm tripped), and cells are grouped by the world they read:
#   R      A B C D        one preclassify.sh run over the rename world, every cell read from its rows
#   B230   b230c b230d    a git shim fails ONE subcommand: c refuses per subcommand, d is the shared memo
#   B308   U1 U2 U3 T1    the same shim under --untangle and --templates
#   MEMO   mE mF mG mH    a memo file that cannot be created (E long dist, F read-only memo, G has_path, H `.s` occupied)
#   D403   ES EP ER EL ED US UP UR UL UD   an empty or unreadable cached status, on each of the five memo functions
#   N      na nb nc nd ne nf ng nh ni nj nk nl nm nn   a read failure is never answered or cached as an absence
#
# THE GIT SHIM IS A FUNCTION, NOT A SCRIPT. It is exported (`export -f git`) in a subshell around the
# one preclassify.sh run it wraps, so it reaches that run's git calls and no other, and costs no
# process start per git call. A forced hit is still recorded in a hits file, and every shimmed cell
# asserts that file is non-empty, so a shim that never fired cannot read as a refusal.
#

set -uo pipefail
unset AI_DLC_RECONCILE_MEMO

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS, BOTH ROOTED AT THIS FILE, AND NO VERSION-MARKER WALK. This fixture SHIPS:
# install.sh lands core/fixtures/<x> at tests/fixtures/<x>, and an installed consumer has no
# VERSION file at its root (its stamp is .claude/.ai-dlc-version), so a walk up for one
# resolves to nothing there and the fixture exits 2 on every consumer push -- which is
# exactly how v0.491.0 shipped it, copied from a .dist-only sibling where the walk is fine.
# Three levels up from this file is the project root in BOTH layouts; the reconcile dir is
# then named at its distribution path and its consumer path. I106 fails the push on a
# shipping fixture that walks for VERSION.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
for cand in "$ROOT/core/skills/ai-dlc-update/reconcile" "$ROOT/.claude/skills/ai-dlc-update/reconcile"; do
  [ -f "$cand/preclassify.sh" ] && RECON="$cand" && break
done
[ -n "${RECON:-}" ] || { echo "FIXTURE ERROR: reconcile/preclassify.sh not found in either layout below $ROOT" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pc-rename.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

echo "preclassify-rename-row"
echo "  subject: ${RECON#$ROOT/}/preclassify.sh"
# The REQUIRED inputs of inputs.decl: the subject and the library it sources, both driven below.
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/preclassify.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/lib.sh"

# --- a synthetic distribution, two commits ------------------------------------
# base ships a fixture directory with a transcript and a runner. theirs renames the
# transcript byte-for-byte (the shape git detects as R100) and edits the runner (an M row
# in the same range, the control that ordinary rows still parse beside the split ones).
DIST="$WORK/dist"
mkdir -p "$DIST/core/fixtures/probe" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

printf '{"type":"assistant","usage":{"input_tokens":250000}}\n' > "$DIST/core/fixtures/probe/old-name.jsonl"
printf '#!/usr/bin/env bash\necho base\n' > "$DIST/core/fixtures/probe/run.sh"
printf '1.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

gitc mv core/fixtures/probe/old-name.jsonl core/fixtures/probe/new-name.jsonl
printf '#!/usr/bin/env bash\necho theirs\n' > "$DIST/core/fixtures/probe/run.sh"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# CAN THE SEED EXPRESS THE DEFECT? git must actually pair the two paths into a rename row
# when left to its defaults; otherwise the flag under test has nothing to split and every
# arm below passes against an unfixed subject.
_ns="$(git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/)"
if ! grep -q '^R100' <<<"$_ns"; then
  echo "FIXTURE ERROR: git did not detect the seeded move as R100, so the rename row this fixture exists for is unreachable" >&2
  exit 2
fi

# --- a consumer holding base ---------------------------------------------------
CONS="$WORK/consumer"
mkdir -p "$CONS/.claude" "$CONS/tests/fixtures/probe" || exit 2
git -C "$DIST" show "$BASE:core/fixtures/probe/old-name.jsonl" > "$CONS/tests/fixtures/probe/old-name.jsonl"
git -C "$DIST" show "$BASE:core/fixtures/probe/run.sh"        > "$CONS/tests/fixtures/probe/run.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONS/.claude/.ai-dlc-version"

run_pc() { bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
bucket_of() { # bucket_of <rows> <core-path> -> field 4 of that path's row, or empty
  printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v p="$2" '$2==p {print $4}'
}

# --- cell bookkeeping -----------------------------------------------------------
C_R="A B C D"
C_B230="b230c b230d"
C_B308="U1 U2 U3 T1"
C_MEMO="mE mF mG mH"
C_D403="ES EP ER EL ED US UP UR UL UD"
C_N="na nb nc nd ne nf ng nh ni nj nk nl nm nn"
RES=""; WANT=""; REF_ROWS=""
put()  { RES="$RES $1=$2"; }
res()  { local t; t="${RES#* $1=}"; [ "$t" != "$RES" ] || { printf X; return; }; printf '%s' "${t%% *}"; }
want() { case " $WANT " in *" $1 "*) return 0 ;; esac; return 1; }
tripped_in() { local c o=""; for c in $1; do [ "$(res "$c")" = 0 ] || o="$o $c"; done; printf '%s' "${o# }"; }

# --- the git shims: exported functions around one run, never a PATH entry ------------------------------
FX_REAL_GIT="$(command -v git)"; export FX_REAL_GIT
# fx_git fails ONE subcommand with 128. FX_GIT_ONCE names a file: when set, the shim fails only while
# that file is absent, and creates it on the failure.
fx_git() {
  local sub="" skip=0 a hit=""
  for a in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "$a" in -C|-c) skip=1 ;; -*) ;; *) sub="$a"; break ;; esac
  done
  case "${FX_GIT_FAIL:-}" in
    diff) if [ "$sub" = diff ]; then for a in "$@"; do [ "$a" = --name-status ] && hit=1; done; fi ;;
    hash-object|rev-parse|ls-files) [ "$sub" = "$FX_GIT_FAIL" ] && hit=1 ;;
  esac
  if [ -n "$hit" ] && [ -n "${FX_GIT_ONCE:-}" ] && [ -e "$FX_GIT_ONCE" ]; then hit=""; fi
  if [ -n "$hit" ]; then
    [ -n "${FX_GIT_ONCE:-}" ] && : > "$FX_GIT_ONCE"
    [ -n "${FX_GIT_HITS:-}" ] && echo "$sub" >> "$FX_GIT_HITS"
    echo "fatal: forced by the preclassify-rename-row git shim ($FX_GIT_FAIL)" >&2
    return 128
  fi
  "$FX_REAL_GIT" "$@"
}
# fx_ngit makes the .dist-only marker of core/fixtures/probe read as a missing subtree would.
fx_ngit() {
  if [ -n "${FX_N_FORCE:-}" ]; then
    case "$*" in
      *core/fixtures/probe/.dist-only*)
        [ -n "${FX_N_HITS:-}" ] && echo hit >> "$FX_N_HITS"
        case "$*" in *cat-file*) return 128 ;; *rev-parse*) return 1 ;; *ls-tree*) return 1 ;; esac ;;
    esac
  fi
  "$FX_REAL_GIT" "$@"
}

# --- which groups run in this layout --------------------------------------------
# BL-230 and BL-308 need the fail-closed engine, BL-374/BL-310 the literal ls-tree discriminator. An
# installed engine that predates either lands with the pull that carries this fixture.
RUN_B230=1; RUN_N=1
case "$RECON" in */core/skills/ai-dlc-update/reconcile) IN_DIST=1 ;; *) IN_DIST=0 ;; esac
if ! grep -qF 'refusing to classify' "$RECON/preclassify.sh" || ! grep -qF '_ai_dlc_memo_serve' "$RECON/lib.sh"; then
  if [ "$IN_DIST" = 0 ]; then
    printf '  SKIP  BL-230 arms c d -- the installed preclassify.sh/lib.sh predate the fail-closed fix; it lands with the pull that carries this fixture\n'
    RUN_B230=0
  else
    printf '  --    (BL-230: this preclassify.sh/lib.sh predate the fail-closed fix; in the distribution the arms run anyway and must go red)\n'
  fi
fi
# Keyed on the discriminator's NEWEST clause, the literal ls-tree read cells nm-nn
# need: an engine carrying `_ai_dlc_rev_absent` without it would run nm-nn red on a consumer.
if ! grep -qF 'git -C "$1" --literal-pathspecs ls-tree -z --full-tree' "$RECON/lib.sh"; then
  if [ "$IN_DIST" = 0 ]; then
    printf '  SKIP  BL-374/BL-310 arms a-n -- the installed lib.sh predates the literal ls-tree discriminator; it lands with the pull that carries this fixture\n'
    RUN_N=0
  else
    printf '  --    (BL-374/BL-310: this lib.sh carries no literal ls-tree discriminator; in the distribution the arms run anyway and must go red)\n'
  fi
fi

# =============================================================================
# GROUP R -- the rename row. One run, four cells read from its rows.
# =============================================================================
grp_R() { # grp_R <recon> <tag> <ctl> <cells>
  local _d="$1" _o="$WORK/r-$2" _ctl="$3" _rows n n4 v
  WANT="$4"; mkdir -p "$_o" || exit 2
  run_pc "$_d" > "$_o/rows"; _rows="$(<"$_o/rows")"
  [ "$_ctl" != 1 ] || REF_ROWS="$_o/rows"
  # A. the new path is a plain upstream add
  if want A; then v=0; [ "$(bucket_of "$_rows" core/fixtures/probe/new-name.jsonl)" = UPSTREAM-ONLY-ADD ] || v=1; put A "$v"; fi
  # B. the old path is a gated upstream delete (consumer untouched)
  if want B; then v=0; [ "$(bucket_of "$_rows" core/fixtures/probe/old-name.jsonl)" = UPSTREAM-DELETED ] || v=1; put B "$v"; fi
  # C. the ordinary M row beside them still classifies (control)
  if want C; then v=0; [ "$(bucket_of "$_rows" core/fixtures/probe/run.sh)" = UPSTREAM-ONLY ] || v=1; put C "$v"; fi
  # D. every fixture row has exactly four fields, and there are rows to count
  if want D; then
    n="$(printf '%s\n' "$_rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')"
    n4="$(printf '%s\n' "$_rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\// && NF==4' | wc -l | tr -d ' ')"
    v=0; { [ "$n" -ge 3 ] && [ "$n4" = "$n" ]; } || v=1; put D "$v"
  fi
}

# =============================================================================
# GROUP B230 -- A GIT THAT FAILED IS NOT A GIT THAT ANSWERED
# =============================================================================
# Under a forced git failure preclassify.sh exited 0 in almost every case: a failed `diff --name-status`
# gave EMPTY output, a failed `hash-object` read the consumer copy as MISSING, a failed `rev-parse` read
# the base or theirs blob as MISSING -- MISSING being a legitimate bucket input. And lib.sh's memo CACHED
# the failed status, so one transient failure was served to every later caller sharing that memo.
#   c  a git shim fails ONE subcommand with 128 -> preclassify exits 2 and names the call on stderr in the
#      fixed grammar. Once per subcommand: diff, hash-object, rev-parse.
#   d  one shared memo, one forced 128 on the diff, then a healthy run IN THE SAME MEMO -> the healthy run
#      classifies. The first run must have refused, or d proves nothing about a failure; the memo must be
#      the same directory, or d proves nothing about a cache.
# pc_shim <recon> <fail-subcommand|""> <out-prefix> [memo-dir] [once-file] -> rc; rows, stderr and hits
# land in <out-prefix>.{rows,err,hits}
pc_shim() {
  : > "$3.hits"
  ( git() { fx_git "$@"; }; export -f git fx_git
    FX_GIT_FAIL="$2" FX_GIT_HITS="$3.hits" FX_GIT_ONCE="${5:-}" AI_DLC_RECONCILE_MEMO="${4:-}" \
      bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$3.rows" 2> "$3.err" )
}
grp_B230() { # grp_B230 <recon> <tag> <ctl> <cells>
  local _d="$1" _o="$WORK/b230-$2" _ctl="$3" _s _rc _m v
  WANT="$4"; mkdir -p "$_o" || exit 2
  if [ "$_ctl" = 1 ]; then
    # control: transparent shim, same classification as the unshimmed subject run, zero hits
    pc_shim "$_d" "" "$_o/ctl"; _rc=$?
    if [ "$_rc" -ne 0 ] || ! cmp -s "$_o/ctl.rows" "$REF_ROWS" || [ -s "$_o/ctl.hits" ]; then
      echo "FIXTURE ERROR: BL-230 control -- preclassify through the TRANSPARENT shim did not reproduce the unshimmed rows with zero forced hits, so the shim is what c and d would measure" >&2
      exit 2
    fi
  fi
  if want b230c; then
    v=0
    for _s in diff hash-object rev-parse; do
      pc_shim "$_d" "$_s" "$_o/c-$_s"; _rc=$?
      # NOT "no rows": preclassify streams, so a failure late in the run follows rows already
      # printed (measured: the hash-object case prints one). Its contract is the exit and the
      # named call; both callers discard every row on a non-zero exit, and their fixtures own that.
      if [ "$_rc" -ne 2 ] || [ ! -s "$_o/c-$_s.hits" ] \
         || ! grep -qE '^preclassify: git failed, refusing to classify: .* exited 128$' "$_o/c-$_s.err"; then
        v=1
        printf '%s: rc=%s rows=%s hits=%s stderr=%s\n' "$_s" "$_rc" "$(grep -c . "$_o/c-$_s.rows")" \
          "$(grep -c . "$_o/c-$_s.hits")" "$(head -1 "$_o/c-$_s.err")" >> "$_o/c.why"
        break  # the cell is already 1; the remaining subcommands would only repeat the verdict
      fi
    done
    put b230c "$v"
  fi
  if want b230d; then
    v=0; _m="$_o/memo"; mkdir -p "$_m"
    pc_shim "$_d" diff "$_o/d1" "$_m" "$_o/d.once"; _rc=$?
    if [ "$_rc" -ne 2 ] || [ ! -e "$_o/d.once" ]; then
      v=1; printf 'the forced first run did not refuse (rc=%s, forced=%s)\n' "$_rc" "$([ -e "$_o/d.once" ] && echo yes || echo no)" >> "$_o/d.why"
    else
      pc_shim "$_d" diff "$_o/d2" "$_m" "$_o/d.once"; _rc=$?
      if [ "$_rc" -ne 0 ] || ! cmp -s "$_o/d2.rows" "$REF_ROWS"; then
        v=1; printf 'the healthy run in the same memo rc=%s rows=%s (want 0 and the reference rows) -- the failure was served from the cache\n' \
          "$_rc" "$(grep -c . "$_o/d2.rows")" >> "$_o/d.why"
      fi
    fi
    put b230d "$v"
  fi
}

# =============================================================================
# GROUP B308 -- THE TWO OPTIONAL MODES REFUSE ON THEIR OWN
# =============================================================================
# Arm c drives the DEFAULT mode only. `--untangle` enumerates through its own `ls-files` pipeline and
# `--templates` through its own `printf | while`, and each reaches pc_fail() from a different subshell, so
# a mode can exit 0 over a failed git call while the default mode refuses. One cell per forced call, each
# scored on the exit (2), a forced hit (the shim really fired), and the fixed stderr grammar naming the call.
#   U1 --untangle, ls-files fails     U2 --untangle, rev-parse fails
#   U3 --untangle, hash-object fails  T1 --templates, rev-parse fails
# OWN WORLD, so the rename world is not changed: a dist carrying one manifest-globbed file (core/rules/*.md)
# and one manifest template, edited at theirs, and a consumer holding an edited copy of each -- so both modes
# classify a non-empty row set.
if [ "$RUN_B230" = 1 ]; then
  MD="$WORK/modes-dist"; mkdir -p "$MD/core/rules" "$MD/templates" || exit 2
  git -C "$MD" init -q 2>/dev/null || exit 2
  printf 'rule base\n' > "$MD/core/rules/probe.md"
  printf 'template base\n' > "$MD/templates/CLAUDE.md.template"
  git -C "$MD" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$MD" -c user.email=f@f -c user.name=fixture commit -q -m base || exit 2
  M_B="$(git -C "$MD" rev-parse HEAD)"
  printf 'template theirs\n' > "$MD/templates/CLAUDE.md.template"
  git -C "$MD" -c user.email=f@f -c user.name=fixture commit -q -am theirs || exit 2
  M_T="$(git -C "$MD" rev-parse HEAD)"
  MC="$WORK/modes-consumer"; mkdir -p "$MC/.claude/rules" || exit 2
  printf 'rule consumer edit\n' > "$MC/.claude/rules/probe.md"
  printf 'consumer claude\n' > "$MC/CLAUDE.md"
  printf 'version: 1.0.0\ncommit: %s\n' "$M_T" > "$MC/.claude/.ai-dlc-version"
fi
# m_run <recon> <mode> <fail|""> <out-prefix> -- --untangle runs base == theirs, its contract
m_run() {
  local _b="$M_B"; [ "$2" = --untangle ] && _b="$M_T"
  : > "$4.hits"
  ( git() { fx_git "$@"; }; export -f git fx_git
    FX_GIT_FAIL="$3" FX_GIT_HITS="$4.hits" FX_GIT_ONCE="" AI_DLC_RECONCILE_MEMO="" \
      bash "$1/preclassify.sh" "$MD" "$_b" "$M_T" "$MC" "$2" > "$4.rows" 2> "$4.err" )
}
grp_B308() { # grp_B308 <recon> <tag> <ctl> <cells>
  local _d="$1" _o="$WORK/b308-$2" _ctl="$3" _c _s _m _rc v
  WANT="$4"; mkdir -p "$_o" || exit 2
  if [ "$_ctl" = 1 ]; then
    # CONTROLS, one per mode: transparent shim, rc 0, zero hits, and the row the world seeds
    # must be THERE -- rc 0 with no rows is what a mode that classified nothing looks like.
    m_run "$_d" --untangle "" "$_o/ctl-u"; _rc=$?
    { [ "$_rc" -eq 0 ] && [ ! -s "$_o/ctl-u.hits" ] \
      && grep -q "^U	core/rules/probe.md	.claude/rules/probe.md	BOTH-CHANGED->CLASSIFY$" "$_o/ctl-u.rows"; } \
      || { echo "FIXTURE ERROR: BL-308 untangle control rc=$_rc rows=$(grep -c . "$_o/ctl-u.rows") -- a mode through the TRANSPARENT shim did not classify its seeded row, so every forced cell would measure the harness" >&2; exit 2; }
    m_run "$_d" --templates "" "$_o/ctl-t"; _rc=$?
    { [ "$_rc" -eq 0 ] && [ ! -s "$_o/ctl-t.hits" ] \
      && grep -q "^T	templates/CLAUDE.md.template	CLAUDE.md	TEMPLATE-PROSE-MERGE$" "$_o/ctl-t.rows"; } \
      || { echo "FIXTURE ERROR: BL-308 templates control rc=$_rc rows=$(grep -c . "$_o/ctl-t.rows") -- a mode through the TRANSPARENT shim did not classify its seeded row, so every forced cell would measure the harness" >&2; exit 2; }
  fi
  for _c in U1:--untangle:ls-files U2:--untangle:rev-parse U3:--untangle:hash-object T1:--templates:rev-parse; do
    _s="${_c#*:}"; _m="${_s%%:*}"; _s="${_s#*:}"; _c="${_c%%:*}"
    want "$_c" || continue
    m_run "$_d" "$_m" "$_s" "$_o/$_c"; _rc=$?
    printf '%s %s %s: rc=%s rows=%s hits=%s stderr=%s\n' "$_c" "$_m" "$_s" "$_rc" "$(grep -c . "$_o/$_c.rows")" \
      "$(grep -c . "$_o/$_c.hits")" "$(head -1 "$_o/$_c.err")" >> "$_o/why"
    v=0
    if [ "$_rc" -ne 2 ] || [ ! -s "$_o/$_c.hits" ] \
       || ! grep -qE "^preclassify: git failed, refusing to classify: ${_s} .* exited 128$" "$_o/$_c.err"; then
      v=1
    fi
    put "$_c" "$v"
  done
}

# =============================================================================
# GROUP MEMO -- A MEMO FILE THAT CANNOT BE CREATED MUST NOT CHANGE THE ANSWER
# =============================================================================
# Every lib.sh memo names its cache file after a key that embeds the percent-encoded dist path.
# When that file cannot be created -- a dist path past the 255-character filename limit, or a
# memo directory that cannot be written (read-only, or ENOSPC on a full disk) -- the unfixed fill
# reported its failed REDIRECT's status as git's and served nothing: preclassify.sh from a
# 309-character dist emitted 0 bytes with exit 0, and memo_has_path read a present path as absent.
#
#   mE. preclassify.sh from a dist whose ABSOLUTE path exceeds 255 characters (two nested
#       150-character components, so the length does not depend on TMPDIR) emits exactly the
#       bytes the short dist emits. The length is asserted in the same run.
#   mF. preclassify.sh from the short dist with AI_DLC_RECONCILE_MEMO set to a `chmod 555`
#       directory emits exactly the writable run's bytes. A LENGTH-BOUNDED fix passes E and
#       fails here, because a short key in an unwritable directory is just as wrong.
#   mG. memo_has_path with that unwritable memo returns 0 on a present path and non-zero on an
#       absent one (the unfixed read-back of a `.s` it never wrote returned 255 on both).
#   mH. memo_has_path on a present path whose `.s` name is OCCUPIED by a directory, so the fill
#       file is creatable but the status can never be read back: it must return 0. This is the
#       only world that separates "return the in-memory status" from "read `.s` back", because
#       in mE-mG the creation probe already routes the lookup direct.
#
# mE and mF are PRESENCE-shaped by their positive conjunct: the tip's short run must emit the probe
# rows the arms above require (asserted once, below), so two empty outputs cannot compare equal.
LONGD="$WORK/$(printf 'L%.0s' $(seq 1 150))/$(printf 'M%.0s' $(seq 1 150))/dist"
mkdir -p "${LONGD%/dist}" && cp -R "$DIST" "$LONGD" || { echo "FIXTURE ERROR: could not build the long dist" >&2; exit 2; }
[ "${#LONGD}" -gt 255 ] || { echo "FIXTURE ERROR: the long dist path is ${#LONGD} characters, not over 255" >&2; exit 2; }
RO="$WORK/ro-memo"
mkdir -p "$RO" && chmod 555 "$RO" || exit 2
if ( : > "$RO/probe" ) 2>/dev/null; then
  echo "FIXTURE ERROR: a chmod 555 directory is writable here (running as root?), so arms mF-mG cannot express the defect" >&2
  exit 2
fi
# The dist is passed RELATIVE (`dist`, from inside $WORK), so G and H's keys are short whatever
# TMPDIR is: they must isolate the unwritable directory and the occupied `.s`, never the length.
# The query SOURCES lib.sh in a subshell: a clean function table and a fresh memo per query, as `bash -c` had.
has_path_rc() { # has_path_rc <recon> <memo-dir> <ref> <path> -> memo_has_path's status; 97 = lib.sh did not load
  ( cd "$WORK" && set +u +o pipefail
    AI_DLC_RECONCILE_MEMO="$2"; export AI_DLC_RECONCILE_MEMO
    . "$1/lib.sh" 2>/dev/null
    command -v memo_has_path >/dev/null || exit 97
    memo_has_path dist "$3" "$4" ) 2>/dev/null
}
S_REF=""
grp_MEMO() { # grp_MEMO <recon> <tag> <ctl> <cells>
  local _d="$1" _o="$WORK/memo-$2" _ctl="$3" _l _r _m _occ rc r v
  WANT="$4"; mkdir -p "$_o" || exit 2
  if [ "$_ctl" = 1 ]; then
    # the tip's short run is the reference for mE and mF, and must carry the probe rows
    S_REF="$(<"$REF_ROWS")"
    if [ "$(printf '%s\n' "$S_REF" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')" -lt 3 ]; then
      echo "FIXTURE ERROR: the tip's short run carries fewer than 3 probe rows, so mE and mF would compare two empty outputs" >&2; exit 2
    fi
  fi
  if want mE; then
    _l="$(env -u AI_DLC_RECONCILE_MEMO bash "$_d/preclassify.sh" "$LONGD" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    v=0; [ "$S_REF" = "$_l" ] || v=1; put mE "$v"
  fi
  if want mF; then
    _r="$(AI_DLC_RECONCILE_MEMO="$RO" bash "$_d/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    v=0; [ "$S_REF" = "$_r" ] || v=1; put mF "$v"
  fi
  if want mG; then
    has_path_rc "$_d" "$RO" "$THEIRS" core/fixtures/probe/run.sh; rc=$?
    has_path_rc "$_d" "$RO" "$THEIRS" core/fixtures/probe/old-name.jsonl; r=$?
    if [ "$_ctl" = 1 ] && { [ "$rc" -eq 97 ] || [ "$r" -eq 97 ]; }; then echo "FIXTURE ERROR: $_d/lib.sh did not define memo_has_path" >&2; exit 2; fi
    v=0; { [ "$rc" -eq 0 ] && [ "$r" -ne 0 ] && [ "$rc" -ne 97 ] && [ "$r" -ne 97 ]; } || v=1; put mG "$v"
  fi
  if want mH; then
    # H: derive the `.s` name from the producer in a writable memo, then occupy it with a directory.
    _m="$(mktemp -d "$WORK/occ.XXXXXX")" || exit 2
    has_path_rc "$_d" "$_m" "$THEIRS" core/fixtures/probe/run.sh >/dev/null
    _occ="$(cd "$_m" && ls | LC_ALL=C grep '^e .*\.s$')"
    if [ -z "$_occ" ] || [ "$(printf '%s\n' "$_occ" | wc -l | tr -d ' ')" != 1 ]; then
      if [ "$_ctl" = 1 ]; then echo "FIXTURE ERROR: the writable memo holds no single memo_has_path status file to occupy" >&2; exit 2; fi
      put mH 1
    else
      mv "$_m/$_occ" "$_m/$_occ.was" && mkdir "$_m/$_occ" || exit 2
      has_path_rc "$_d" "$_m" "$THEIRS" core/fixtures/probe/run.sh; rc=$?
      v=0; [ "$rc" -eq 0 ] || v=1; put mH "$v"
    fi
  fi
}

# =============================================================================
# GROUP D403 -- A CACHED STATUS THAT CANNOT BE READ IS 125, NEVER A STATUS
# =============================================================================
# Every memo's HIT path read its `.s` as `_st="$(<"$_f.s")"; return "$_st"`, unchecked. Two states
# reach that line, each owned by one guard in `_ai_dlc_memo_status`:
#   E<fn>  the `.s` is EMPTY (`_ai_dlc_memo_commit` writes it with its error discarded): the bare read
#          returned "" -> 255. The shape guard answers 125.
#   U<fn>  the `.s` is mode 000, read under the caller's `set -e`: the failed assignment ended the
#          script with 1 -- memo_rev_parse's ABSENT -- before any check. The read-status guard answers 125.
# <fn> is S show, P has_path, R rev_parse, L ls_tree, D diff_name_status. Each cell first fills a
# fresh memo with the real call (rc 0), then damages the one `.s` that call wrote.
D_PFX() { case "$1" in S) echo 's ' ;; P) echo 'e ' ;; R) echo 'r ' ;; L) echo 't ' ;; D) echo 'd%20' ;; esac; }
d_call() { # d_call <recon> <memo> <S|P|R|L|D> <errexit 0|1> -> prints rc=<n>, or REACHED/exit=<n>
  ( ( cd "$WORK" && set +u +o pipefail
      AI_DLC_RECONCILE_MEMO="$2"; export AI_DLC_RECONCILE_MEMO
      . "$1/lib.sh" 2>/dev/null; command -v memo_show >/dev/null || exit 97
      [ "$4" = 1 ] && set -e
      case "$3" in
        S) memo_show dist "$THEIRS" core/fixtures/probe/run.sh ;; P) memo_has_path dist "$THEIRS" core/fixtures/probe/run.sh ;;
        R) memo_rev_parse dist "$THEIRS:core/fixtures/probe/run.sh" ;; L) memo_ls_tree dist "$THEIRS" ;;
        D) memo_diff_name_status dist "$BASE" "$THEIRS" core/fixtures ;;
      esac > /dev/null 2>&1
      echo "rc=$?" ) 2>/dev/null; echo "exit=$?" )
}
d_cell() { # d_cell <recon> <fn> <E|U> -> 0 when the damaged `.s` answered 125, 1 otherwise
  local m f o
  m="$(mktemp -d "$WORK/d403.XXXXXX")" || exit 2
  o="$(d_call "$1" "$m" "$2" 0)"
  case "$o" in *rc=0*) ;; *) return 1 ;; esac
  f="$(cd "$m" && ls | LC_ALL=C grep -F "$(D_PFX "$2")" | LC_ALL=C grep '\.s$')"
  [ -n "$f" ] && [ "$(printf '%s\n' "$f" | grep -c .)" -eq 1 ] || return 1
  if [ "$3" = E ]; then
    : > "$m/$f"; o="$(d_call "$1" "$m" "$2" 0)"
    case "$o" in *rc=125*) return 0 ;; esac
  else
    chmod 000 "$m/$f"; o="$(d_call "$1" "$m" "$2" 1)"; chmod 644 "$m/$f"
    case "$o" in *exit=125*) return 0 ;; esac
  fi
  return 1
}
grp_D403() { # grp_D403 <recon> <tag> <ctl> <cells>
  local _c _rc
  WANT="$4"
  for _c in ES EP ER EL ED US UP UR UL UD; do
    want "$_c" || continue
    # NOT in an `if`: bash ignores errexit for everything run inside a condition, which would hide the U cells' set -e
    d_cell "$1" "${_c#?}" "${_c%?}"; _rc=$?
    put "$_c" "$_rc"
  done
}

# =============================================================================
# GROUP N (BL-374 / BL-310) -- A READ FAILURE IS NEVER CACHED, OR ANSWERED, AS AN ABSENCE
# =============================================================================
# lib.sh's memo cached `cat-file -e`'s 128 and `rev-parse -q --verify`'s 1 as "absent" whenever
# `rev-parse` agreed -- and `rev-parse` answers 1 for a path whose SUBTREE is the missing object,
# exactly as for an absent one. So a read failure was cached, served to every later process sharing
# the memo after the object was back, and turned into a MISSING bucket by preclassify. A missing
# BLOB was the second shape: `cat-file -e` 1, which matched neither caching branch and reached every
# caller as an absent path. The discriminator is layer-drift.sh's have() table (lib.sh's
# `_ai_dlc_memo_absent`); a "no" it cannot confirm is 125.
#
# One world: a dist holding a/b/f.txt, top.txt, core/rules/probe.md and templates/CLAUDE.md.template,
# a consumer holding the last two at base. Each cell moves ONE object aside and puts it back.
#   na memo_has_path, a/b tree missing, writable memo   -> 125     nb  the same, chmod-555 memo -> 125
#   nc memo_rev_parse, a/b tree missing, writable memo  -> 125     nd  the same, chmod-555 memo -> 125
#   ne the writable memo queried while missing, after restore -> memo_has_path 0 AND memo_rev_parse 0
#   nf memo_has_path, top.txt's BLOB missing, writable  -> 125     ng  the same, chmod-555 memo -> 125
#   nh a NON-CANONICAL spelling (a/./b/f.txt) on a healthy tree -> memo_has_path 128, memo_rev_parse 1;
#      an absolute path INTO the repository (<dist>/top.txt) -> memo_has_path 128
#   ni a `..` spelling that climbs out (../x) on a healthy tree -> memo_has_path 128
#   nm an absolute path OUTSIDE the repository (/etc/passwd) -> memo_has_path 128, memo_rev_parse 1
#   nn a pathspec-magic spelling (:(glob)a/**) -> memo_has_path 128, memo_rev_parse 1
#   nj preclassify --untangle AND --templates, each with its subject's tree missing -> exit 2, named
#   nk preclassify --untangle with an unresolvable rev -> exit 2 (it bucketed every row before)
#   nl preclassify's dist_only(), the .dist-only marker read as cat-file 128 / rev-parse 1 / ls-tree 1
#      (the missing-subtree signature, forced by a shim) -> exit 2, not "not dist-only"
# nh, ni, nm and nn are the NEAR-MISSES: all are absences the naive rule ("ls-tree rc 0 with a line, or any
# non-zero, is a failure") reads as failures, and a ledger path spelled that way would then refuse.
if [ "$RUN_N" = 1 ]; then
  NW="$WORK/nworld"; ND="$NW/dist"; NC="$NW/consumer"
  mkdir -p "$ND/a/b" "$ND/core/rules" "$ND/templates" "$NC/.claude/rules" || exit 2
  git -C "$ND" init -q 2>/dev/null || exit 2
  echo x > "$ND/a/b/f.txt"; echo y > "$ND/top.txt"
  printf 'rule\n' > "$ND/core/rules/probe.md"; printf 'template\n' > "$ND/templates/CLAUDE.md.template"
  git -C "$ND" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$ND" -c user.email=f@f -c user.name=fixture commit -q -m n || exit 2
  NH="$(git -C "$ND" rev-parse HEAD)" || exit 2
  cp "$ND/core/rules/probe.md" "$NC/.claude/rules/probe.md"; printf 'consumer claude\n' > "$NC/CLAUDE.md"
  n_obj() { local _s; _s="$(git -C "$ND" rev-parse "HEAD:$1")" || exit 2; printf '%s' "$ND/.git/objects/$(printf %s "$_s" | cut -c1-2)/$(printf %s "$_s" | cut -c3-)"; }
  O_AB="$(n_obj a/b)"; O_TOP="$(n_obj top.txt)"; O_RULES="$(n_obj core/rules)"; O_TPL="$(n_obj templates)"
  for _o in "$O_AB" "$O_TOP" "$O_RULES" "$O_TPL"; do
    [ -f "$_o" ] || { echo "FIXTURE ERROR: BL-374 seed -- object $_o is not a loose file, so it cannot be moved aside" >&2; exit 2; }
  done
  NRO="$NW/ro"; mkdir -p "$NRO" && chmod 555 "$NRO" || exit 2
fi
# lq <recon> <memo> <fn> <args...> -> the function's status; 97 = lib.sh did not load
lq() {
  local _r="$1" _m="$2"; shift 2
  ( cd "$NW" && set +u +o pipefail
    AI_DLC_RECONCILE_MEMO="$_m"; export AI_DLC_RECONCILE_MEMO
    . "$_r/lib.sh" >/dev/null 2>&1
    command -v memo_has_path >/dev/null || exit 97
    "$@" >/dev/null 2>&1 ) 2>/dev/null
}
aside() { mv "$1" "$1.aside" || { echo "FIXTURE ERROR: could not move $1 aside" >&2; exit 2; }; }
back()  { mv "$1.aside" "$1" || { echo "FIXTURE ERROR: could not restore $1" >&2; exit 2; }; }
# n_pc <recon> <out-prefix> <base> <theirs> <mode> -> rc
n_pc() { AI_DLC_RECONCILE_MEMO="" bash "$1/preclassify.sh" "$ND" "$3" "$4" "$NC" "$5" > "$2.rows" 2> "$2.err"; }
# nl_run <recon> <out-prefix> <force> -> rc: the rename world's preclassify with the .dist-only shim
nl_run() {
  : > "$2.hits"
  ( git() { fx_ngit "$@"; }; export -f git fx_ngit
    FX_N_FORCE="$3" FX_N_HITS="$2.hits" AI_DLC_RECONCILE_MEMO="" \
      bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$2.rows" 2> "$2.err" )
}
grp_N() { # grp_N <recon> <tag> <ctl> <cells>
  local _d="$1" _o="$NW/s-$2" _ctl="$3" _m _x _y _z _rc v
  WANT="$4"; mkdir -p "$_o" || exit 2
  if [ "$_ctl" = 1 ]; then
    # SEED CONTROL: with a/b moved aside ls-tree must FAIL on the path, or no cell expresses the defect.
    aside "$O_AB"
    git -C "$ND" ls-tree --full-tree HEAD -- a/b/f.txt >/dev/null 2>&1 && { back "$O_AB"; echo "FIXTURE ERROR: BL-374 seed did not take -- ls-tree reads a/b/f.txt with its tree moved aside" >&2; exit 2; }
    back "$O_AB"
    # CONTROLS on the healthy tree, every one PRESENCE-shaped
    lq "$_d" "$_o" true; [ "$?" = 0 ] || { echo "FIXTURE ERROR: BL-374 control -- lib.sh did not load" >&2; exit 2; }
    _m="$_o/m"; mkdir -p "$_m"
    lq "$_d" "$_m" memo_has_path dist HEAD top.txt || { echo "FIXTURE ERROR: BL-374 control -- has top.txt != 0" >&2; exit 2; }
    [ -n "$(ls -A "$_m")" ] || { echo "FIXTURE ERROR: BL-374 control -- the memo was never written" >&2; exit 2; }
    lq "$_d" "$_o" memo_has_path dist HEAD nope.txt; [ "$?" = 128 ] || { echo "FIXTURE ERROR: BL-374 control -- has nope.txt != 128" >&2; exit 2; }
    lq "$_d" "$_o" memo_rev_parse dist HEAD:nope.txt; [ "$?" = 1 ] || { echo "FIXTURE ERROR: BL-374 control -- rev_parse nope.txt != 1" >&2; exit 2; }
    n_pc "$_d" "$_o/cu" "$NH" "$NH" --untangle; _rc=$?
    { [ "$_rc" = 0 ] && grep -q "^U	core/rules/probe.md	.claude/rules/probe.md	ALREADY-AT-THEIRS$" "$_o/cu.rows"; } \
      || { echo "FIXTURE ERROR: BL-374 control -- untangle rc=$_rc" >&2; exit 2; }
    n_pc "$_d" "$_o/ct" "$NH" "$NH" --templates; _rc=$?
    { [ "$_rc" = 0 ] && grep -q "^T	templates/CLAUDE.md.template	CLAUDE.md	TEMPLATE-UNCHANGED-NOOP$" "$_o/ct.rows"; } \
      || { echo "FIXTURE ERROR: BL-374 control -- templates rc=$_rc" >&2; exit 2; }
    nl_run "$_d" "$_o/l0" ""; _rc=$?
    { [ "$_rc" = 0 ] && cmp -s "$_o/l0.rows" "$REF_ROWS" && [ ! -s "$_o/l0.hits" ]; } \
      || { echo "FIXTURE ERROR: BL-374 control -- the transparent shim rc=$_rc did not reproduce the unshimmed rows with zero hits" >&2; exit 2; }
  fi
  # --- na: the a/b tree moved aside, memo_has_path, writable memo
  if want na; then
    mkdir -p "$_o/ma"; aside "$O_AB"
    lq "$_d" "$_o/ma" memo_has_path dist HEAD a/b/f.txt; _x=$?; back "$O_AB"
    v=0; [ "$_x" = 125 ] || v=1; put na "$v"
  fi
  if want nb; then
    aside "$O_AB"; lq "$_d" "$NRO" memo_has_path dist HEAD a/b/f.txt; _x=$?; back "$O_AB"
    v=0; [ "$_x" = 125 ] || v=1; put nb "$v"
  fi
  if want nc; then
    mkdir -p "$_o/mc"; aside "$O_AB"
    lq "$_d" "$_o/mc" memo_rev_parse dist HEAD:a/b/f.txt; _x=$?; back "$O_AB"
    v=0; [ "$_x" = 125 ] || v=1; put nc "$v"
  fi
  if want nd; then
    aside "$O_AB"; lq "$_d" "$NRO" memo_rev_parse dist HEAD:a/b/f.txt; _x=$?; back "$O_AB"
    v=0; [ "$_x" = 125 ] || v=1; put nd "$v"
  fi
  # --- ne: the same writable memo queried while missing, then after restore
  if want ne; then
    mkdir -p "$_o/me"; aside "$O_AB"
    lq "$_d" "$_o/me" memo_has_path dist HEAD a/b/f.txt
    lq "$_d" "$_o/me" memo_rev_parse dist HEAD:a/b/f.txt
    back "$O_AB"
    lq "$_d" "$_o/me" memo_has_path dist HEAD a/b/f.txt;    _x=$?
    lq "$_d" "$_o/me" memo_rev_parse dist HEAD:a/b/f.txt;   _y=$?
    v=0; { [ "$_x" = 0 ] && [ "$_y" = 0 ]; } || v=1; put ne "$v"
  fi
  # --- nf ng: top.txt's blob moved aside (a fresh memo, so nf reads the fill, not ne's cache)
  if want nf; then
    mkdir -p "$_o/mf"; aside "$O_TOP"
    lq "$_d" "$_o/mf" memo_has_path dist HEAD top.txt;   _x=$?; back "$O_TOP"
    v=0; [ "$_x" = 125 ] || v=1; put nf "$v"
  fi
  if want ng; then
    aside "$O_TOP"; lq "$_d" "$NRO" memo_has_path dist HEAD top.txt;     _x=$?; back "$O_TOP"
    v=0; [ "$_x" = 125 ] || v=1; put ng "$v"
  fi
  # --- nh ni: healthy tree, spellings that are absences
  if want nh; then
    mkdir -p "$_o/mh"
    lq "$_d" "$_o/mh" memo_has_path dist HEAD a/./b/f.txt;  _x=$?
    lq "$_d" "$_o/mh" memo_rev_parse dist HEAD:a//b/f.txt; _y=$?
    # and an absolute path INTO the repository: ls-tree lists the RELATIVE name, a different path
    lq "$_d" "$_o/mh" memo_has_path dist HEAD "$ND/top.txt"; _z=$?
    v=0; { [ "$_x" = 128 ] && [ "$_y" = 1 ] && [ "$_z" = 128 ]; } || v=1; put nh "$v"
  fi
  if want ni; then
    mkdir -p "$_o/mi"; lq "$_d" "$_o/mi" memo_has_path dist HEAD ../x; _x=$?
    v=0; [ "$_x" = 128 ] || v=1; put ni "$v"
  fi
  # --- nm: an absolute path OUTSIDE the repository is refused before any object is read, like `..`
  if want nm; then
    mkdir -p "$_o/mm"
    lq "$_d" "$_o/mm" memo_has_path dist HEAD /etc/passwd;  _x=$?
    lq "$_d" "$_o/mm" memo_rev_parse dist HEAD:/etc/passwd; _y=$?
    v=0; { [ "$_x" = 128 ] && [ "$_y" = 1 ]; } || v=1; put nm "$v"
  fi
  # --- nn: a pathspec-magic spelling names no tree entry; ls-tree reads it literally, as cat-file does
  if want nn; then
    mkdir -p "$_o/mn"
    lq "$_d" "$_o/mn" memo_has_path dist HEAD ':(glob)a/**';  _x=$?
    lq "$_d" "$_o/mn" memo_rev_parse dist 'HEAD::(glob)a/**'; _y=$?
    v=0; { [ "$_x" = 128 ] && [ "$_y" = 1 ]; } || v=1; put nn "$v"
  fi
  # --- nj: each mode with its subject's tree missing
  if want nj; then
    aside "$O_RULES"; n_pc "$_d" "$_o/ju" "$NH" "$NH" --untangle; _x=$?; back "$O_RULES"
    aside "$O_TPL";   n_pc "$_d" "$_o/jt" "$NH" "$NH" --templates; _y=$?; back "$O_TPL"
    v=0
    { [ "$_x" = 2 ] && [ "$_y" = 2 ] && grep -q 'ls-tree could not confirm it' "$_o/ju.err" \
      && grep -q 'ls-tree could not confirm it' "$_o/jt.err"; } || v=1
    put nj "$v"
  fi
  # --- nk: an unresolvable rev under --untangle
  if want nk; then
    n_pc "$_d" "$_o/k" 1111111111111111111111111111111111111111 1111111111111111111111111111111111111111 --untangle; _x=$?
    v=0; { [ "$_x" = 2 ] && grep -q 'ls-tree could not confirm it' "$_o/k.err"; } || v=1
    put nk "$v"
  fi
  # --- nl: dist_only() under the forced missing-subtree signature
  if want nl; then
    nl_run "$_d" "$_o/l" 1; _x=$?
    v=0; { [ "$_x" = 2 ] && [ -s "$_o/l.hits" ] && grep -q 'dist-only exited 125' "$_o/l.err"; } || v=1
    put nl "$v"
  fi
}

# =============================================================================
# THE TIP -- every cell of every group, with each group's controls
# =============================================================================
ALL_CELLS="$C_R $C_MEMO $C_D403"
TIP_REST="$C_MEMO $C_D403"
[ "$RUN_B230" = 1 ] && ALL_CELLS="$ALL_CELLS $C_B230 $C_B308" && TIP_REST="$TIP_REST $C_B230 $C_B308"
[ "$RUN_N" = 1 ] && ALL_CELLS="$ALL_CELLS $C_N" && TIP_REST="$TIP_REST $C_N"

run_cells() { # run_cells <recon> <tag> <ctl 0|1> <cell>...
  local _d="$1" _t="$2" _c="$3" _w _g _l _x _gw
  shift 3; _w=" $* "
  for _g in R B230 B308 MEMO D403 N; do
    case "$_g" in R) _l="$C_R" ;; B230) _l="$C_B230" ;; B308) _l="$C_B308" ;; MEMO) _l="$C_MEMO" ;; D403) _l="$C_D403" ;; N) _l="$C_N" ;; esac
    _gw=""
    for _x in $_l; do case "$_w" in *" $_x "*) _gw="$_gw $_x" ;; esac; done
    [ -n "$_gw" ] || continue
    case "$_g" in
      R) grp_R "$_d" "$_t" "$_c" "$_gw" ;;
      B230) grp_B230 "$_d" "$_t" "$_c" "$_gw" ;;
      B308) grp_B308 "$_d" "$_t" "$_c" "$_gw" ;;
      MEMO) grp_MEMO "$_d" "$_t" "$_c" "$_gw" ;;
      D403) grp_D403 "$_d" "$_t" "$_c" "$_gw" ;;
      N) grp_N "$_d" "$_t" "$_c" "$_gw" ;;
    esac
  done
}

# R first: its tip rows are the reference every other group compares against.
run_cells "$RECON" tip 1 $C_R
if [ "$(grep -c . "$REF_ROWS")" -lt 3 ]; then
  echo "FIXTURE ERROR: the reference classification has fewer than 3 rows, so the shimmed arms compare against nothing" >&2
  exit 2
fi
run_cells "$RECON" tip 1 $TIP_REST


# R. the rename row
_t="$(tripped_in "$C_R")"
if [ -z "$_t" ]; then
  ok "A the renamed file's NEW path is UPSTREAM-ONLY-ADD"
  ok "B the renamed file's OLD path is UPSTREAM-DELETED (gated), not a CLASSIFY row"
  ok "C the M row beside them (run.sh) still classifies as UPSTREAM-ONLY"
  ok "D every probe row carries exactly four fields, over a non-empty row set"
else
  bad "the shipping preclassify.sh fails arm(s) [$_t] on a rename row. Rows:"
  sed 's/^/          /' "$REF_ROWS" | sed 's/\t/<TAB>/g'
fi

# B230 / B308
if [ "$RUN_B230" = 1 ]; then
  ok "BL-230 control: preclassify through the transparent shim reproduces the unshimmed rows, zero forced hits"
  if [ "$(res b230c)" = 0 ]; then
    ok "BL-230 arm c: a forced 128 on diff, hash-object or rev-parse makes preclassify exit 2, naming the call"
  else
    bad "BL-230 arm c: a forced git 128 did not make preclassify refuse -- $(tr '\n' ' ' < "$WORK/b230-tip/c.why")"
  fi
  if [ "$(res b230d)" = 0 ]; then
    ok "BL-230 arm d: after a forced 128 the SAME memo answers the next run healthy -- the failure was not cached"
  else
    bad "BL-230 arm d: $(tr '\n' ' ' < "$WORK/b230-tip/d.why")"
  fi
  ok "BL-308 control: --untangle and --templates each classify their seeded row through the transparent shim, zero forced hits"
  _t="$(tripped_in "$C_B308")"
  if [ -z "$_t" ]; then
    ok "BL-308 U1-U3 T1: a forced 128 on ls-files, rev-parse or hash-object under --untangle, and on rev-parse under --templates, exits 2 naming the call ($(awk '{printf "%s %s; ", $1, $5}' "$WORK/b308-tip/why"))"
  else
    bad "BL-308 cell(s) [$_t]: a mode exited other than 2 over a forced git failure, or did not name the call -- $(tr '\n' ' ' < "$WORK/b308-tip/why")"
  fi
fi

# MEMO
_t="$(tripped_in "$C_MEMO")"
if [ -z "$_t" ]; then
  ok "E a dist path of ${#LONGD} characters classifies byte-identically to the short one"
  ok "F an unwritable memo directory classifies byte-identically to a writable one"
  ok "G memo_has_path with an unwritable memo answers 0 on a present path and non-zero on an absent one"
  ok "H memo_has_path returns its in-memory status when its .s name is occupied, never a read-back"
else
  bad "the shipping lib.sh fails memo arm(s) [$_t]: a memo file that cannot be created changes the answer"
fi

# D403
_t="$(tripped_in "$C_D403")"
if [ -z "$_t" ]; then
  ok "BL-403(d) E/U x 5: an empty .s and an unreadable .s under set -e each answer 125 on every memo's hit path"
else
  bad "BL-403(d) cell(s) [$_t] failed: a cached status that could not be read was taken as a status"
fi

# N
if [ "$RUN_N" = 1 ]; then
  ok "BL-374/BL-310 controls: present 0, absent 128/1, the memo written, both modes and the transparent shim classify"
  _t="$(tripped_in "$C_N")"
  if [ -z "$_t" ]; then
    ok "BL-374/BL-310 a-g: a missing subtree or blob reads 125 from memo_has_path and memo_rev_parse, writable or chmod-555 memo, and is never cached"
    ok "BL-374/BL-310 h-i: a non-canonical spelling, an absolute path into the repository and a climbing \`..\` are still ABSENT (128 / 1), never a refusal"
    ok "BL-310 m-n: an absolute path outside the repository and a pathspec-magic spelling are ABSENT (128 / 1), never a refusal"
    ok "BL-374 j-l: preclassify refuses (exit 2) on a missing subtree in --untangle and --templates, an unresolvable rev, and an unconfirmable .dist-only marker"
  else
    bad "BL-374/BL-310 cell(s) [$_t] failed -- a read failure is still answered or cached as an absence"
  fi
fi

chmod 755 "$RO"
[ "$RUN_N" != 1 ] || chmod 755 "$NRO"

echo ""
report_end preclassify-rename-row
