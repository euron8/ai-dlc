# review-shard-merge/lib.sh -- the resolution, seeded repositories, worlds and predicates of
# review-shard-merge, sourced by that fixture's run.sh (the behavioural arms, shipped) (the retired mutation battery sourced it too).
# ONE copy, so the predicates the shipped arms run are never restated.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# scrubs AI_DLC_*, owns WORK and the ONE EXIT trap that removes it -- no caller sets a second.
#
# The threshold key is named ONCE, in the unset below (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset AI_DLC_REVIEW_SHARD_MIN_FILES
# THE WORLD TEMPLATES (tpl_* below). Plain shell variables, unset HERE so no exported value can point
# them at another run's templates; this file sets RSM_TPL itself once WORK exists.
unset RSM_TPL RSM_TPL_FILL RSM_TPL_HITS
[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: lib.sh sourced without NAME set" >&2; exit 2; }

# Resolution walks up from THIS file's directory, so both callers resolve identically.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The subjects and the files the merge derives from, found by walking UP in either layout --
# never by counting `..`. Distribution: core/scripts, core/skills, core/team-roles. Consumer:
# scripts/ai-dlc, .claude/skills, .claude/team-roles.
find_up() { # <rel-dist> <rel-consumer> -> first existing path walking up from $LIB_DIR
  local d="$LIB_DIR" c
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in "$d/$1" "$d/$2"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done
    d="$(dirname "$d")"
  done
  return 1
}
PART="$(find_up core/scripts/partition-review-diff.sh scripts/ai-dlc/partition-review-diff.sh)" || PART=""
MERGE="$(find_up core/scripts/merge-review-shards.sh scripts/ai-dlc/merge-review-shards.sh)" || MERGE=""
GATE_MD="$(find_up core/skills/ai-dlc/steps/gate-validation.md .claude/skills/ai-dlc/steps/gate-validation.md)" || GATE_MD=""
ROLE_MD="$(find_up core/team-roles/code-reviewer.md .claude/team-roles/code-reviewer.md)" || ROLE_MD=""
GRAMMAR="$(find_up core/skills/ai-dlc/artifact-path-grammar.md .claude/skills/ai-dlc/artifact-path-grammar.md)" || GRAMMAR=""
STEP_MD="$(find_up core/skills/ai-dlc/steps/implementation.md .claude/skills/ai-dlc/steps/implementation.md)" || STEP_MD=""
QA_MD="$(find_up core/team-roles/qa.md .claude/team-roles/qa.md)" || QA_MD=""
SS_SCHEMA="$(find_up core/schemas/sprint-status.json .claude/schemas/sprint-status.json)" || SS_SCHEMA=""
for _p in PART MERGE GATE_MD ROLE_MD GRAMMAR STEP_MD QA_MD SS_SCHEMA; do
  eval "_x=\${$_p}"
  [ -n "$_x" ] || { echo "FIXTURE ERROR: $_p not found above $LIB_DIR in either layout; nothing was asserted" >&2; exit 2; }
done
SRCDIR="$(cd "$(dirname "$MERGE")" && pwd)"
[ "$(cd "$(dirname "$PART")" && pwd)" = "$SRCDIR" ] || { echo "FIXTURE ERROR: the partition is not beside the merge" >&2; exit 2; }
[ -f "$SRCDIR/artifact-path-config.sh" ] || { echo "FIXTURE ERROR: artifact-path-config.sh is not beside the partition; it reads the scan roots there" >&2; exit 2; }
[ -f "$SRCDIR/partition-document.sh" ] || { echo "FIXTURE ERROR: partition-document.sh is not beside the merge; it reads the cross groups there" >&2; exit 2; }
# BL-737: the seal reader and the seal writer the merge and --mark resolve beside themselves, and the
# recorder hook that writes the rows they read (distribution core/hooks, consumer .claude/hooks).
SEAL_SRC="$SRCDIR/content-seal.sh"; WFD_SRC="$SRCDIR/wait-for-deliverable.sh"
HOOK="$(find_up core/hooks/ai-dlc-content-seal.sh .claude/hooks/ai-dlc-content-seal.sh)" || HOOK=""
for _p in SEAL_SRC WFD_SRC HOOK; do
  eval "_x=\${$_p}"
  [ -n "$_x" ] && [ -f "$_x" ] || { echo "FIXTURE ERROR: $_p ($_x) not found beside the merge or above $LIB_DIR; nothing was asserted" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is not on PATH; content-seal.sh reads its ledger with it" >&2; exit 2; }
echo "$NAME: resolved subjects = $PART , $MERGE , $SEAL_SRC , $WFD_SRC , $HOOK"

# THE SUBJECTS ARE ASKED IN PROCESS. Each subject is loadable: merge-review-shards.sh (mrs_main),
# partition-review-diff.sh (prd_main) and partition-document.sh (pdoc_main) hold their program in a
# function behind a BASH_SOURCE guard; content-seal.sh (seal_main) and wait-for-deliverable.sh
# (wfd_mark_main, its --mark / --mark-repair dispatch) already did; the recorder hook has no guard and
# its whole body is the run. ip_run asks one of them what its CLI line would answer, in a SUBSHELL, so the
# subject's `exit` ends the subshell and its globals die with it:
#   ip_run [-e NAME=VALUE]... <script> <entry function | -> <args...>
# Inside the subshell, in order: the shell options a fresh `bash <script>` has (no -u, no pipefail); every
# fixture function and every non-exported fixture variable removed (a fresh bash's own variables kept), so
# a defaulted read in the subject (`${v:-}`, `${nf:-}`, ...) sees what it sees as a process; the -e
# assignments exported (what the CLI line prefixed: AI_DLC_PROJECT_ROOT, CLAUDE_PROJECT_DIR, PATH, the
# threshold key); the positionals cleared; the script SOURCED from the path given, so a mutant drive loads its
# mutant copy; the entry function asserted and called with the CLI's arguments. Stdin, stdout and stderr are
# the caller's redirections. EQ1-EQ6 (run.sh) hold the in-process answer byte-equal to the CLI's, one
# refusing and one passing input per subject, and those are the end-to-end runs kept.
IP_FRESH=" $(env -i "$BASH" -c 'compgen -v' | tr '\n' ' ') "
[ "$IP_FRESH" != "  " ] || { echo "FIXTURE ERROR: a fresh bash listed no variable; the in-process scrub has no baseline" >&2; exit 2; }
ip_run() {
  (
    _ip_x=""
    # -C <dir>: the subject's working directory (the lead checkout for --lead-range, --record-partition and the qa merge,
    # which refuse a review or shard repository whose git common dir is not the cwd's); a builtin cd, no fork.
    while [ "${1:-}" = -e ] || [ "${1:-}" = -C ]; do
      if [ "$1" = -C ]; then cd "$2" || exit 96; else _ip_x="$_ip_x$2"$'\n'; fi; shift 2; done
    _ip_s="$1"; _ip_m="$2"; shift 2
    _ip_a=("$@"); _ip_l="${IP_LOADED:-}"; _ip_f="${IP_FNS:- }"
    # The scrub forks nothing: each list is a builtin written to a scratch file beside $MO (rebound per scorer by
    # bind_scratch) and read back with `read`, never through a command substitution.
    _ip_t="$(dirname "$MO")/.ip-scrub"
    set +u +o pipefail
    _ip_keep="$IP_FRESH"
    compgen -e > "$_ip_t"; while IFS= read -r _ip_v; do _ip_keep="$_ip_keep$_ip_v "; done < "$_ip_t"
    compgen -A function > "$_ip_t"
    while IFS= read -r _ip_v; do
      case "$_ip_v" in ip_run) continue ;; esac
      [ "$_ip_s" = "$_ip_l" ] && case "$_ip_f" in *" $_ip_v "*) continue ;; esac
      unset -f "$_ip_v"
    done < "$_ip_t"
    compgen -v > "$_ip_t"
    while IFS= read -r _ip_v; do
      case "$_ip_v" in _ip_*) continue ;; esac
      case "$_ip_keep" in *" $_ip_v "*) continue ;; esac
      unset "$_ip_v" 2> /dev/null
    done < "$_ip_t"
    while IFS= read -r _ip_v; do [ -z "$_ip_v" ] || export "$_ip_v"; done <<< "$_ip_x"
    set --
    # shellcheck source=/dev/null
    [ "$_ip_s" = "$_ip_l" ] || . "$_ip_s"
    [ "$_ip_m" = - ] && exit 0
    declare -F "$_ip_m" > /dev/null || { echo "FIXTURE BROKEN: $_ip_s defined no $_ip_m when sourced" >&2; exit 97; }
    "$_ip_m" ${_ip_a[@]+"${_ip_a[@]}"}
  )
}
# SOURCED ONCE: the merge, the subject most cells ask, is loaded into THIS shell once per script directory
# (ip_load), so each ip_run of it forks a subshell that already holds its functions and parses nothing. IP_FNS
# names exactly the functions that file defines (the scrub keeps those and no fixture function); any other
# script, or a merge copy not loaded, is sourced inside the subshell as before. A mutant drive loads its own
# copy (run.sh mut_run) and SRCDIR's is loaded back before the next arm. The merge defines no name lib.sh,
# run.sh or mutant.sh defines (ip_load refuses one that does), and sourcing it runs `set -u`, which lib.sh already set.
IP_LOADED=""; IP_FNS=" "
ip_load() { # <merge-review-shards.sh path>
  local b a f
  [ "$1" = "$IP_LOADED" ] && return 0
  b=" $(compgen -A function | tr '\n' ' ') "
  local _p="$1"; set --
  # shellcheck source=/dev/null
  . "$_p" || return 1
  declare -F mrs_main > /dev/null || return 1
  IP_FNS=" $(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)() *{.*/\1/p' "$_p" | tr '\n' ' ') "
  for f in $IP_FNS; do case "$b" in *" $f "*) case "$IP_FNS_OWN" in *" $f "*) ;; *) echo "FIXTURE BROKEN: $_p defines $f, which the fixture also defines" >&2; return 1 ;; esac ;; esac; done
  IP_LOADED="$_p"; IP_FNS_OWN="$IP_FNS"
}
IP_FNS_OWN=" "
ip_load "$SRCDIR/merge-review-shards.sh" || { echo "FIXTURE ERROR: $MERGE could not be loaded in process" >&2; exit 2; }
# eq_pair <name> [-e NAME=VALUE]... <script> <entry> <args...> -> 0 when the subject asked in process and the
# same CLI line run as a process (`env NAME=VALUE... bash <script> <args...>`) answer byte-identically: stdout,
# stderr, exit code, and every file named in EQ_FILES as it stands after the run (a row's one-second "ts"
# stamp masked). Each EQ_FILES file is put back to its pre-run bytes (or absence) before each side, and stdin
# is EQ_IN (default /dev/null). EQ_RC holds the shared exit code; EQ_WHY what differed.
eq_pair() {
  local n="$1" d f i rc1 rc2; shift
  local -a ev=() ipe=()
  while [ "${1:-}" = -e ]; do ev+=("$2"); ipe+=(-e "$2"); shift 2; done
  local s="$1" m="$2"; shift 2
  d="$(mktemp -d "$WORK/eq.XXXXXX")" || return 1
  i=0; for f in ${EQ_FILES:-}; do i=$((i + 1)); if [ -e "$f" ]; then cp "$f" "$d/snap.$i"; else : > "$d/none.$i"; fi; done
  eq_restore() { local j=0 g; for g in ${EQ_FILES:-}; do j=$((j + 1)); if [ -f "$d/none.$j" ]; then rm -f "$g"; else cp "$d/snap.$j" "$g"; fi; done; }
  eq_side() { local j=0 g; for g in ${EQ_FILES:-}; do j=$((j + 1)); if [ -e "$g" ]; then sed 's/"ts":"[^"]*"/"ts":"-"/g' "$g" > "$d/$1.f$j"; else echo ABSENT > "$d/$1.f$j"; fi; done; }
  ip_run ${ipe[@]+"${ipe[@]}"} "$s" "$m" "$@" > "$d/ip.out" 2> "$d/ip.err" < "${EQ_IN:-/dev/null}"; rc1=$?
  eq_side ip; eq_restore
  env ${ev[@]+"${ev[@]}"} bash "$s" "$@" ${EQ_CLI_TAIL:+"$EQ_CLI_TAIL"} > "$d/cli.out" 2> "$d/cli.err" < "${EQ_IN:-/dev/null}"; rc2=$?
  eq_side cli
  EQ_RC="$rc1"; EQ_WHY=""; EQ_OUT="$d/ip.out"
  [ "$rc1" = "$rc2" ] || EQ_WHY="$EQ_WHY rc $rc1/$rc2"
  cmp -s "$d/ip.out" "$d/cli.out" || EQ_WHY="$EQ_WHY stdout[$(head -1 "$d/ip.out") | $(head -1 "$d/cli.out")]"
  cmp -s "$d/ip.err" "$d/cli.err" || EQ_WHY="$EQ_WHY stderr[$(head -1 "$d/ip.err") | $(head -1 "$d/cli.err")]"
  i=0; for f in ${EQ_FILES:-}; do i=$((i + 1)); cmp -s "$d/ip.f$i" "$d/cli.f$i" || EQ_WHY="$EQ_WHY file[$f]"; done
  cat "$d/ip.out" "$d/ip.err" > "$WORK/eq-$n.ans"; echo "rc=$rc1" >> "$WORK/eq-$n.ans"
  [ -z "$EQ_WHY" ]
}

# THE KEY, derived from the partition's dereference site. Absent, the SERIAL and env arms below
# would assert about a name the program no longer reads.
KEY="$(sed -n 's/.*"\${\(AI_DLC_[A-Z0-9_]*\):-}".*/\1/p' "$PART" | head -1)"
[ -n "$KEY" ] || { echo "FIXTURE STALE: no \"\${AI_DLC_...:-}\" dereference in $PART" >&2; exit 2; }
# THE BUILT-IN DEFAULT, derived from its one assignment. The boundary seeds below are built at
# exactly DFLT-1 and DFLT reviewable files: a seed far from the boundary cannot tell `<` from
# `<=`, and a seed derived from a restated number goes stale silently when the default moves.
DFLT_N="$(grep -c '^REVIEW_SHARD_DEFAULT_MIN_FILES=' "$PART")" || DFLT_N=0
DFLT="$(sed -n 's/^REVIEW_SHARD_DEFAULT_MIN_FILES=\([0-9][0-9]*\)$/\1/p' "$PART")"
[ "$DFLT_N" = "1" ] && [ -n "$DFLT" ] && [ "$DFLT" -ge 2 ] \
  || { echo "FIXTURE STALE: $PART carries $DFLT_N 'REVIEW_SHARD_DEFAULT_MIN_FILES=<n>' line(s) (want 1, n >= 2)" >&2; exit 2; }

# CHECK 1'S PATTERN, lifted exactly as core/fixtures/gate-verdict-grep-shape lifts it.
PAT="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE_MD" | head -1)"
[ -n "$PAT" ] || { echo "FIXTURE STALE: no grep -inE '<pattern>' <review-file> directive in $GATE_MD" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
RSM_TPL="$WORK/tpl"; mkdir "$RSM_TPL" || exit 2
# BL-905, THE RUN RECORD's era. Every world seeded before BL-905 reads QA_MD, a copy of the installed qa.md WITHOUT the
# run sentinel, so its canonical-run cells keep their meaning and its run claims read LEGACY for the run record;
# p_run_rec's worlds read the installed file itself (QA_MD_RUN), which carries it exactly once.
RR_SENT='column-0 `Canonical result:` copied from `--record-run`'
QA_MD_RUN="$QA_MD"; QA_MD="$WORK/qa-norun.md"
grep -vF -- "$RR_SENT" "$QA_MD_RUN" > "$QA_MD"
_rrs="$(grep -cF -- "$RR_SENT" "$QA_MD_RUN")" || _rrs=0; _rrn="$(grep -cF -- "$RR_SENT" "$QA_MD")" || _rrn=0
[ "$_rrs" = 1 ] && [ "$_rrn" = 0 ] || { echo "FIXTURE STALE: qa.md carries the run sentinel $_rrs time(s), its stripped copy $_rrn" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
has() { local n; n="$(grep -cF -- "$2" "$1")" || n=0; [ "$n" -gt 0 ]; }

# The project root the merge reads gate-validation.md and code-reviewer.md from: a copy of the
# resolved bytes in the distribution layout, so an untracked .claude/ copy beside the dev
# checkout can never be what the merge reads.
PROJ="$WORK/proj"
mkdir -p "$PROJ/core/skills/ai-dlc/steps" "$PROJ/core/team-roles" "$PROJ/core/schemas"
cp "$GATE_MD" "$PROJ/core/skills/ai-dlc/steps/gate-validation.md"
cp "$ROLE_MD" "$PROJ/core/team-roles/code-reviewer.md"
cp "$QA_MD" "$PROJ/core/team-roles/qa.md"
# sprint-status.sh fails closed without its schema; the CR world's view is read against this copy.
cp "$SS_SCHEMA" "$PROJ/core/schemas/sprint-status.json"
# STORY-BIND calls sprint-status.sh with AI_DLC_PROJECT_ROOT unset (merge-review-shards.sh ss_bound), so a flat script
# copy under $WORK (every mutant's and the control's) finds its schema the way an install does, by walking up from its
# own directory to a root marker: $WORK/.claude, holding the subject's schema. PROJ_Q is PROJ with the schema's
# stories_dir rewritten to q{sprint}, the root a seat would point AI_DLC_PROJECT_ROOT at to move the stories directory.
PROJ_Q="$WORK/proj-q"
mkdir -p "$WORK/.claude/schemas" && cp "$SS_SCHEMA" "$WORK/.claude/schemas/sprint-status.json" && cp -R "$PROJ" "$PROJ_Q" \
  && sed 's#planning-artifacts/s{sprint}/stories#planning-artifacts/q{sprint}/stories#' "$SS_SCHEMA" > "$PROJ_Q/core/schemas/sprint-status.json" \
  && grep -qF 'q{sprint}' "$PROJ_Q/core/schemas/sprint-status.json" \
  || { echo "FIXTURE ERROR: the install-root schema or the redirected project root was not built" >&2; exit 2; }

# ------------------------------------------------------------------------- seeded repositories
G() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false \
          -c core.hooksPath=/dev/null "$@"; }
lines() { # <file> <n> <tag> -> n distinct lines
  local i=0; mkdir -p "$(dirname "$1")"
  : > "$1"; while [ "$i" -lt "$2" ]; do i=$((i + 1)); printf '%s line %d\n' "$3" "$i" >> "$1"; done
}
# THE ENGINE AT THE FROZEN SHA (the merge's LEGACY rule reads it from the manifest's worktree). It
# sits in the BASE commit, never the frozen one: a file in the base..sha diff would move every map.
# `old` is the subject's own wait-for-deliverable.sh with its one sentinel line removed (the engine
# that predates key=), in the consumer layout; `new` is the subject itself, in the distribution layout.
OLD_ENGINE="$WORK/old-engine.sh"
grep -vF '# MARK-KEY-WRITER v1' "$WFD_SRC" > "$OLD_ENGINE"
new_repo() { # <dir> [old|new] -> base commit holding the artifact-path grammar, and the engine named
  mkdir -p "$1/core/skills/ai-dlc" || return 1
  G init -q "$1" || return 1
  cp "$GRAMMAR" "$1/core/skills/ai-dlc/artifact-path-grammar.md"
  printf 'seed\n' > "$1/README"
  case "${2:-}" in
    old) mkdir -p "$1/scripts/ai-dlc" && cp "$OLD_ENGINE" "$1/scripts/ai-dlc/wait-for-deliverable.sh" || return 1 ;;
    new) mkdir -p "$1/core/scripts" && cp "$WFD_SRC" "$1/core/scripts/wait-for-deliverable.sh" || return 1 ;;
  esac
  G -C "$1" add -A && G -C "$1" commit -q -m base || return 1
}
REPO_A="$WORK/repo-a"; REPO_B="$WORK/repo-b"
new_repo "$REPO_A" && new_repo "$REPO_B" old || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
# A: every reviewable file under app/, one pipeline artifact under a scan root.
for f in app/api/a.py app/api/b.py app/web/c.js app/web/d.js app/core/e.py app/core/f.py; do
  lines "$REPO_A/$f" 10 "$f"
done
lines "$REPO_A/docs/reviews/s1/0-old-code-review.md" 10 review
G -C "$REPO_A" add -A && G -C "$REPO_A" commit -q -m frozen
# B: three top directories, two files each, every file 5 lines: identical weight per directory.
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do
  lines "$REPO_B/$f" 5 "$f"
done
G -C "$REPO_B" add -A && G -C "$REPO_B" commit -q -m frozen
for r in "$REPO_A" "$REPO_B"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository (inherited GIT_DIR?)" >&2; exit 2; }
done
A_BASE="$(G -C "$REPO_A" rev-parse HEAD~1)"; A_SHA="$(G -C "$REPO_A" rev-parse HEAD)"
B_BASE="$(G -C "$REPO_B" rev-parse HEAD~1)"; B_SHA="$(G -C "$REPO_B" rev-parse HEAD)"
B_SHA12="$(printf '%s' "$B_SHA" | cut -c1-12)"
# A DIVERGED base: a sibling of the frozen sha minted on B_BASE's tree, so its two-dot diff to
# B_SHA is the same six files and a build without the ancestor check answers a FULL map (rc 0).
B_SIB="$(G -C "$REPO_B" commit-tree "${B_BASE}^{tree}" -p "$B_BASE" -m sibling < /dev/null)" \
  || { echo "FIXTURE ERROR: commit-tree for the diverged base failed" >&2; exit 2; }
# C: four top directories of identical weight and NO --max-parts, so the default K alone decides
# the part count (4 under K=4; 2 under K=2).
REPO_C="$WORK/repo-c"
new_repo "$REPO_C" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
for f in w1/a.txt w1/b.txt w2/a.txt w2/b.txt w3/a.txt w3/b.txt w4/a.txt w4/b.txt; do
  lines "$REPO_C/$f" 5 "$f"
done
G -C "$REPO_C" add -A && G -C "$REPO_C" commit -q -m frozen
[ -d "$REPO_C/.git" ] || { echo "FIXTURE ERROR: $REPO_C is not a repository" >&2; exit 2; }
C_BASE="$(G -C "$REPO_C" rev-parse HEAD~1)"; C_SHA="$(G -C "$REPO_C" rev-parse HEAD)"
# LO / HI: the default's boundary, DFLT-1 and DFLT reviewable files, one top directory each so the
# map has independent groups. LO ALSO carries one pipeline artifact under a scan root, so its diff
# holds DFLT files and only the exclusion keeps it below the threshold.
REPO_LO="$WORK/repo-lo"; REPO_HI="$WORK/repo-hi"
new_repo "$REPO_LO" && new_repo "$REPO_HI" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
_i=0; while [ "$_i" -lt "$DFLT" ]; do
  _i=$((_i + 1))
  [ "$_i" -lt "$DFLT" ] && lines "$REPO_LO/t$_i/f.txt" 5 "lo-$_i"
  lines "$REPO_HI/t$_i/f.txt" 5 "hi-$_i"
done
lines "$REPO_LO/docs/reviews/s1/0-old-code-review.md" 5 review
G -C "$REPO_LO" add -A && G -C "$REPO_LO" commit -q -m frozen
G -C "$REPO_HI" add -A && G -C "$REPO_HI" commit -q -m frozen
for r in "$REPO_LO" "$REPO_HI"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
LO_BASE="$(G -C "$REPO_LO" rev-parse HEAD~1)"; LO_SHA="$(G -C "$REPO_LO" rev-parse HEAD)"
HI_BASE="$(G -C "$REPO_HI" rev-parse HEAD~1)"; HI_SHA="$(G -C "$REPO_HI" rev-parse HEAD)"
# D: DFLT+2 reviewable files, the default-built MERGE world. Off the boundary on purpose, so the
# `<`/`<=` mutant is owned by the HI arm alone and this world owns what the manifest records.
REPO_D="$WORK/repo-d"
new_repo "$REPO_D" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
_i=0; while [ "$_i" -lt "$((DFLT + 2))" ]; do _i=$((_i + 1)); lines "$REPO_D/u$_i/f.txt" 5 "d-$_i"; done
G -C "$REPO_D" add -A && G -C "$REPO_D" commit -q -m frozen
[ -d "$REPO_D/.git" ] || { echo "FIXTURE ERROR: $REPO_D is not a repository" >&2; exit 2; }
D_BASE="$(G -C "$REPO_D" rev-parse HEAD~1)"; D_SHA="$(G -C "$REPO_D" rev-parse HEAD)"
D_SHA12="$(printf '%s' "$D_SHA" | cut -c1-12)"
# E / F: eight and two top directories of identical weight, merged with --max-parts 8 and 2, so
# the map has K=8 (six cross groups, the largest G) and K=2 (one cross group, `cross.md`).
REPO_E="$WORK/repo-e"; REPO_F="$WORK/repo-f"
new_repo "$REPO_E" old && new_repo "$REPO_F" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
for _i in 1 2 3 4 5 6 7 8; do lines "$REPO_E/e$_i/a.txt" 5 "e$_i-a"; lines "$REPO_E/e$_i/b.txt" 5 "e$_i-b"; done
# Six files, off the --min-files 4 boundary, so the `<`/`<=` mutant is owned by P2b alone.
for _i in 1 2; do for _f in a b c; do lines "$REPO_F/f$_i/$_f.txt" 5 "f$_i-$_f"; done; done
G -C "$REPO_E" add -A && G -C "$REPO_E" commit -q -m frozen
G -C "$REPO_F" add -A && G -C "$REPO_F" commit -q -m frozen
for r in "$REPO_E" "$REPO_F"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
E_BASE="$(G -C "$REPO_E" rev-parse HEAD~1)"; E_SHA="$(G -C "$REPO_E" rev-parse HEAD)"
F_BASE="$(G -C "$REPO_F" rev-parse HEAD~1)"; F_SHA="$(G -C "$REPO_F" rev-parse HEAD)"
# S / N: B's six files, so the map is B's (K=3), over a base whose engine is the key= engine itself
# (S, the sentinel present, distribution layout) or absent in both layouts (N).
REPO_S="$WORK/repo-s"; REPO_N="$WORK/repo-n"
new_repo "$REPO_S" new && new_repo "$REPO_N" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
for r in "$REPO_S" "$REPO_N"; do
  for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$r/$f" 5 "$f"; done
  G -C "$r" add -A && G -C "$r" commit -q -m frozen
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
S_BASE="$(G -C "$REPO_S" rev-parse HEAD~1)"; S_SHA="$(G -C "$REPO_S" rev-parse HEAD)"
N_BASE="$(G -C "$REPO_N" rev-parse HEAD~1)"; N_SHA="$(G -C "$REPO_N" rev-parse HEAD)"
# BL-808 (--exclude-captures). REPO_X: X1 adds DFLT+2 code files over four dirs and ten captures under
# evidence/s1/ (counted DFLT+2 after exclusion, so it STAYS sharded); X2 deletes three code files
# (DFLT-1 counted, so the flag flips it to SERIAL while the flagless run still partitions); X3 adds one
# scan-root file. REPO_Y: Y1 is ONE code file plus five captures (C8), Y2 a second code file.
REPO_X="$WORK/repo-x"; REPO_Y="$WORK/repo-y"
new_repo "$REPO_X" && new_repo "$REPO_Y" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
_i=0; while [ "$_i" -lt "$((DFLT + 2))" ]; do _i=$((_i + 1)); lines "$REPO_X/x$((_i % 4))/c$_i.py" "$((_i + 4))" "x-$_i"; done
_i=0; while [ "$_i" -lt 10 ]; do _i=$((_i + 1)); lines "$REPO_X/evidence/s1/cap$_i.txt" 3 "cap-$_i"; done
G -C "$REPO_X" add -A && G -C "$REPO_X" commit -q -m x1 \
  && G -C "$REPO_X" rm -q x1/c1.py x2/c2.py x3/c3.py && G -C "$REPO_X" commit -q -m x2 \
  || { echo "FIXTURE ERROR: repo X could not be built" >&2; exit 2; }
lines "$REPO_X/docs/reviews/s1/r.txt" 3 r
G -C "$REPO_X" add -A && G -C "$REPO_X" commit -q -m x3 || { echo "FIXTURE ERROR: repo X could not be built" >&2; exit 2; }
lines "$REPO_Y/src/only.py" 40 only
for _i in 1 2 3 4; do lines "$REPO_Y/evidence/s1/cap$_i.txt" 3 "y-cap-$_i"; done
lines "$REPO_Y/other/c.log" 2 clog
G -C "$REPO_Y" add -A && G -C "$REPO_Y" commit -q -m y1 || { echo "FIXTURE ERROR: repo Y could not be built" >&2; exit 2; }
lines "$REPO_Y/other/two.py" 30 two
G -C "$REPO_Y" add -A && G -C "$REPO_Y" commit -q -m y2 || { echo "FIXTURE ERROR: repo Y could not be built" >&2; exit 2; }
for r in "$REPO_X" "$REPO_Y"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
X_BASE="$(G -C "$REPO_X" rev-parse HEAD~3)"; X1_SHA="$(G -C "$REPO_X" rev-parse HEAD~2)"
X2_SHA="$(G -C "$REPO_X" rev-parse HEAD~1)"; X3_SHA="$(G -C "$REPO_X" rev-parse HEAD)"
X1_SHA12="$(printf '%s' "$X1_SHA" | cut -c1-12)"
Y_BASE="$(G -C "$REPO_Y" rev-parse HEAD~2)"; Y1_SHA="$(G -C "$REPO_Y" rev-parse HEAD~1)"; Y2_SHA="$(G -C "$REPO_Y" rev-parse HEAD)"
# The lists, in the spelling `git diff --numstat` prints (the spelling --list-captures emits).
# XC_ALL: the ten captures. XC_SEED: nine as LF lines, cap10 ONLY as a CRLF line, a path outside the
# diff, the scan-root path, and a duplicate -- its intersection with the counted files is 10, its
# length 13. XC_DOT: the ten in a `./` spelling, which names nothing in the diff (the spelling control).
# XC_Y: Y's four captures and its .log.
XC_ALL="$WORK/xc-all"; XC_SEED="$WORK/xc-seed"; XC_DOT="$WORK/xc-dot"; XC_Y="$WORK/xc-y"
: > "$XC_ALL"; : > "$XC_DOT"
_i=0; while [ "$_i" -lt 10 ]; do _i=$((_i + 1))
  printf 'evidence/s1/cap%d.txt\n' "$_i" >> "$XC_ALL"; printf './evidence/s1/cap%d.txt\n' "$_i" >> "$XC_DOT"; done
{ sed -n '1,9p' "$XC_ALL"; printf 'evidence/s1/cap10.txt\r\n'; printf 'nowhere/else/out.txt\ndocs/reviews/s1/r.txt\nevidence/s1/cap1.txt\n'; } > "$XC_SEED"
printf 'evidence/s1/cap1.txt\nevidence/s1/cap2.txt\nevidence/s1/cap3.txt\nevidence/s1/cap4.txt\nother/c.log\n' > "$XC_Y"

# THE REVIEW TREE (BL-737). content-seal.sh --review-shard places a shard with `git rev-parse
# --show-toplevel` and refuses one that is not at docs/reviews/s<N>/shards/<idx>-code-review-<sha12>/
# (or -qa-validation-), so every merge world lives in MAIN, a git repository, at that path, one
# numeric `s9<digits>` slot per world (wdir). MAIN is in the CONSUMER layout because the recorder hook sources
# ${CLAUDE_PROJECT_DIR}/scripts/ai-dlc/content-seal.sh; its ledger is MAIN's own state dir. LW is a
# linked worktree of MAIN, whose shards' rows go to MAIN's ledger, never to LW/_bmad-output.
MAIN="$WORK/main"; LW="$WORK/lw"
mkdir -p "$MAIN/scripts/ai-dlc" && G init -q "$MAIN" && cp "$SEAL_SRC" "$MAIN/scripts/ai-dlc/content-seal.sh" \
  && printf 'main\n' > "$MAIN/README" && G -C "$MAIN" add README scripts && G -C "$MAIN" commit -q -m main \
  && [ -d "$MAIN/.git" ] && G -C "$MAIN" worktree add -q --detach "$LW" HEAD 2>/dev/null \
  && mkdir -p "$MAIN/docs/reviews" "$LW/docs/reviews" \
  || { echo "FIXTURE ERROR: the review tree $MAIN (and its linked worktree) could not be built" >&2; exit 2; }
LEDGER="$MAIN/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
# DMAIN: the same shape in the DISTRIBUTION layout (core/scripts/), with its own linked worktree DLW.
DMAIN="$WORK/dmain"; DLW="$WORK/dlw"
mkdir -p "$DMAIN/core/scripts" && G init -q "$DMAIN" && cp "$SEAL_SRC" "$DMAIN/core/scripts/content-seal.sh" \
  && printf 'dmain\n' > "$DMAIN/README" && G -C "$DMAIN" add README core && G -C "$DMAIN" commit -q -m dmain \
  && [ -d "$DMAIN/.git" ] && G -C "$DMAIN" worktree add -q --detach "$DLW" HEAD 2>/dev/null \
  || { echo "FIXTURE ERROR: the distribution-layout tree $DMAIN could not be built" >&2; exit 2; }
# A symlinked ALIAS of MAIN's docs/: --check-shard is driven through it, so a refusal naming the
# physical path proves the target was resolved the way the merge's staging resolves it.
ALIAS="$WORK/alias-docs"
ln -s "$MAIN/docs" "$ALIAS" || { echo "FIXTURE ERROR: cannot create the alias $ALIAS" >&2; exit 2; }
# A slot is named exactly s<N> (merge-review-shards.sh review_sprint), so a world's own directory is a fresh NUMERIC
# slot s9<digits> (mkdir refuses an existing one, so a collision draws again). WSLOT=<N> instead builds the world in a
# fresh repository of its own at docs/reviews/s<N>/shards: the record-only merge worlds, whose sprint the merge reads
# off that slot and holds to the view's. WSLOT_IN=<repository> reuses that repository's slot instead of a fresh one, so
# two passes of one story share one git common dir, and so one lead record (lr-repass).
wdir() { # -> a fresh <tree>/docs/reviews/s9<digits>/shards, the tree $WROOT (default MAIN); or WSLOT's fresh repository
  local w r n=0
  if [ -n "${WSLOT:-}" ]; then
    if [ -n "${WSLOT_IN:-}" ]; then r="$WSLOT_IN"; else r="$(mktemp -d "$WORK/slot.XXXXXX")" && G init -q "$r" || return 1; fi
    w="$r/docs/reviews/s$WSLOT" && mkdir -p "$w/shards" || return 1
    printf '%s' "$w/shards"; return 0
  fi
  while :; do
    w="${WROOT:-$MAIN}/docs/reviews/s9$RANDOM$RANDOM"
    mkdir "$w" 2> /dev/null && break
    n=$((n + 1)); [ "$n" -lt 50 ] || return 1
  done
  mkdir "$w/shards" && printf '%s' "$w/shards"
}

# --------------------------------------------------------------------------------- worlds
# A merge world: its own directory, the shard dir `1-code-review-<sha12>/` inside it holding the
# manifest the REAL partition (the predicate's own sibling) wrote, and --out beside it.
# WORLD TEMPLATES. A world is the partition's output for one argument tuple, and nothing else: the
# builders below write the map, its stderr and the manifest, and no shard, before they return. So the
# FIRST build of each tuple runs the real partition and publishes the world it wrote, and every later
# build of the same tuple clones it into its own fresh directory instead of re-running the partition,
# which the arms and the battery otherwise re-ran for the same tuple many times over. Two guards:
#   - a builder runs the cache only when the scripts it would run (tpl_ok) are byte-identical to
#     SRCDIR's, so a mutant copy of the partition or its siblings always builds its own world;
#   - the key is the builder's whole argument tuple; every other input -- the seeded repos (no arm
#     edits one in place; p_moved partitions a COPY), the environment, the scripts -- is this run's.
#     No world records its own path: the manifest records the REPO, never the world directory.
# TPL0 (seed_controls) builds one world twice, cached and uncached, and requires the two byte-equal and
# the cache to have been read, so a cache that serves a wrong world, or none, is not silent.
# TPL_BUILD counts the real partition runs a builder made, TPL_HITS the clones.
tpl_key() { printf '%s\n' "$@" | shasum | cut -c1-16; }
tpl_ok() { # <script-dir> <script...> -> 0 when each named script is byte-identical to SRCDIR's, or absent from both
  local sd="$1" f; shift
  for f in "$@"; do
    if [ -e "$SRCDIR/$f" ]; then cmp -s "$sd/$f" "$SRCDIR/$f" || return 1; else [ ! -e "$sd/$f" ] || return 1; fi
  done
}
tpl_has() { [ -n "$1" ] && [ -n "${RSM_TPL:-}" ] && [ -d "$RSM_TPL/$1" ]; }
tpl_hit() { printf '%s\n' "$1" >> "$RSM_TPL.hits"; }
tpl_build() { [ -z "${RSM_TPL:-}" ] || printf '%s\n' "$1" >> "$RSM_TPL.builds"; }
tpl_n() { local n; n="$(grep -c . "$RSM_TPL.$1" 2>/dev/null)" || n=0; printf '%s' "$n"; } # <hits|builds>
tpl_put() { # <key> <world dir>: never over a published template
  [ -n "$1" ] && [ -n "${RSM_TPL:-}" ] || return 0
  [ -d "$RSM_TPL/$1" ] && return 0
  mkdir "$RSM_TPL/$1.part" && cp -R "$2/." "$RSM_TPL/$1.part/" && mv "$RSM_TPL/$1.part" "$RSM_TPL/$1"
}
# Every script a builder runs, and every sibling the partition resolves beside itself (sib_set's closure
# rule, applied to partition-review-diff.sh: artifact-path-config.sh, validate-carried-findings.sh).
WORLD_SCRIPTS="partition-review-diff.sh artifact-path-config.sh validate-carried-findings.sh partition-document.sh"
# new_world <script-dir> [repo] -> prints the shard dir
new_world() { # <script-dir> [repo] [dir-suffix] [pass-marker, e.g. -p2]
  local sd="$1" repo="${2:-$REPO_B}" sfx="${3:-code-review}" pm="${4:-}" w d tk=""
  w="$(wdir)" || return 1
  d="$w/1-$sfx-$B_SHA12$pm"
  [ -z "${RSM_TPL:-}" ] || ! tpl_ok "$sd" $WORLD_SCRIPTS || tk="$(tpl_key nw "$repo" "$B_BASE" "$B_SHA" 4 3 "$sfx" "$pm")"
  if tpl_has "$tk"; then
    cp -R "$RSM_TPL/$tk/." "$w/" || return 1; tpl_hit "$tk"
  else
    ip_run "$sd/partition-review-diff.sh" prd_main --map "$repo" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 \
      --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
    tpl_build nw; tpl_put "$tk" "$w" || return 1
  fi
  [ -f "$d/.manifest" ] || return 1
  printf '%s' "$d"
}
out_of() { printf '%s/1-code-review.md' "$(dirname "$1")"; }

# shard <dir> <key> <verdict> <parts-cite> [reviewed-sha] [extra trailing text]
# Shaped on code-reviewer.md's Review Document Template (Summary, Findings with the three
# severity containers), with the shard lines in place of `## Verdict`.
# THE ONE FINDING'S CONTAINER FOLLOWS THE VERDICT (BL-740, the merge's VERDICT BACKING): an APPROVED
# shard carries no finding under Critical, so its finding sits under Important (which APPROVED
# allows); NEEDS_REWORK, BLOCKED and any other verdict keep it under Critical, which backs them. The
# headings and the finding are byte-identical to the pre-BL-740 seed; only the APPROVED placement moved.
shard_find() { printf '#### F-%s-1 an unchecked return in shard %s\nparts: %s\n\nBody of the finding.\n\n' "$1" "$1" "$2"; }
# THE ADVISOR LINE (BL-790), written by every shard and serial emitter below beside shard-verdict:, as
# qa.md and code-reviewer.md tell each writer to. SHARD_ADV overrides it for one world: set to the
# text of the line, or to the empty string to write none.
adv_l() { [ -z "${SHARD_ADV-advisor: called}" ] || printf '%s\n' "${SHARD_ADV-advisor: called}"; }
shard() {
  local d="$1" k="$2" v="$3" cite="$4" sha="${5:-${SHARD_SHA:-$B_SHA}}" extra="${6:-}"
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "$sha" "$v"; adv_l
    # A part shard declares its hand-over count under both gates (code-reviewer.md "As a Shard").
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n' "$k" "$k"
    printf '## Findings\n\n### Critical (must fix before merge)\n\n'
    [ "$v" = APPROVED ] || shard_find "$k" "$cite"
    printf '### Important (should fix, can be follow-up)\n\n'
    [ "$v" != APPROVED ] || shard_find "$k" "$cite"
    printf '### Suggestions (optional improvements)\n\n'
    printf '## Architecture Alignment\nNothing further.\n'
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$d/$k.md"
}
# THE CROSS SHARDS of a world, one per row of the subject's own sibling
# `partition-document.sh --cross-groups <K>` (K = the manifest's part count), keyed `cross` when it
# prints one row and `cross-<g>` otherwise. Each carries one finding citing its row's FIRST and
# LAST ordinal: those lie in the row's two different quarters, and a pair of quarters has exactly
# one group, so the finding is that row's own by the construction -- derived from the quarter
# definition, never from asking --cross-owner what the merge will accept.
# xshards <script-dir> <shard-dir> <verdict> [code-review|qa]
xshards() {
  local sd="$1" d="$2" v="$3" gate="${4:-code-review}" k n g gl first last key tk=""
  k="$(awk -F'\t' '$1 == "part" { n++ } END { print n + 0 }' "$d/.manifest")"
  [ -z "${RSM_TPL:-}" ] || ! tpl_ok "$sd" partition-document.sh || tk="$(tpl_key xs "$k")"
  if tpl_has "$tk"; then
    cp "$RSM_TPL/$tk/groups" "$d.groups" || return 1; tpl_hit "$tk"
  else
    ip_run "$sd/partition-document.sh" pdoc_main --cross-groups "$k" > "$d.groups" 2> /dev/null < /dev/null || return 1
    tpl_build xs
    if [ -n "$tk" ] && [ ! -d "$RSM_TPL/$tk" ]; then
      mkdir "$RSM_TPL/$tk.part" && cp "$d.groups" "$RSM_TPL/$tk.part/groups" && mv "$RSM_TPL/$tk.part" "$RSM_TPL/$tk" || return 1
    fi
  fi
  n="$(grep -c . "$d.groups")" || n=0
  [ "$n" -ge 1 ] || return 1
  while IFS='	' read -r g gl; do
    first="${gl%%,*}"; last="${gl##*,}"
    if [ "$n" -eq 1 ]; then key=cross; else key="cross-$g"; fi
    if [ "$gate" = qa ]; then qshard "$d" "$key" "$v" "$first, $last"; else shard "$d" "$key" "$v" "$first, $last"; fi
    [ -f "$d/$key.md" ] || return 1
  done < "$d.groups"
  return 0
}
world4() { # <script-dir> <v1> <v2> <v3> <vcross> -> shard dir with the three parts and every cross shard
  local d; d="$(new_world "$1")" || return 1
  shard "$d" 1 "$2" 1; shard "$d" 2 "$3" 2; shard "$d" 3 "$4" 3; xshards "$1" "$d" "$5" || return 1
  printf '%s' "$d"
}
# A world over any repo and part ceiling, every part and cross shard written. SHARD_SHA is the
# frozen sha the shard writers stamp; each caller binds it `local` for its world.
# kworld <script-dir> <repo> <base> <sha> <max-parts> <dir-suffix> <verdict> [code-review|qa]
kworld() {
  local sd="$1" repo="$2" base="$3" sha="$4" mp="$5" sfx="$6" v="$7" gate="${8:-code-review}" w d k tk=""
  w="$(wdir)" || return 1
  d="$w/${KIDX:-1}-$sfx-$(printf '%s' "$sha" | cut -c1-12)"
  [ -z "${RSM_TPL:-}" ] || ! tpl_ok "$sd" $WORLD_SCRIPTS || tk="$(tpl_key kw "$repo" "$base" "$sha" 4 "$mp" "$sfx" ${KIDX:+"$KIDX"})"
  if tpl_has "$tk"; then
    cp -R "$RSM_TPL/$tk/." "$w/" || return 1; tpl_hit "$tk"
  else
    ip_run "$sd/partition-review-diff.sh" prd_main --map "$repo" "$base" "$sha" --min-files 4 --max-parts "$mp" \
      --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
    tpl_build kw; tpl_put "$tk" "$w" || return 1
  fi
  [ -f "$d/.manifest" ] || return 1
  for k in $(cut -f1 "$w/map"); do
    if [ "$gate" = qa ]; then qshard "$d" "$k" "$v" "$k"; else shard "$d" "$k" "$v" "$k"; fi
    [ -f "$d/$k.md" ] || return 1
  done
  xshards "$sd" "$d" "$v" "$gate" || return 1
  printf '%s' "$d"
}

# THE FIXED SCRATCH PATHS, all of them, bound in ONE place. Every predicate writes either under a
# fresh `mktemp -d "$WORK/..."` or to one of these four, so a caller that runs predicates
# CONCURRENTLY rebinds these by name (bind_scratch <own dir>) and shares nothing else that is
# written. A fifth fixed path added to a predicate must be added here, or two concurrent scorers
# write it at once.
bind_scratch() { # <dir> -> MO, PO, PE, RERUN_KEEP, CO, MKO under <dir>
  MO="$1/merge.out"; PO="$1/part.out"; PE="$1/part.err"; RERUN_KEEP="$1/rerun.keep"; CO="$1/check.out"; MKO="$1/mark.out"
}
bind_scratch "$WORK"
run_merge() { # <script-dir> <shard-dir> -> RC, $MO
  ip_run -e "AI_DLC_PROJECT_ROOT=$PROJ" "$1/merge-review-shards.sh" mrs_main "$2" --gate code-review --out "$(out_of "$2")" \
    > "$MO" 2>&1 < /dev/null; RC=$?
}
# NAMED HAND-OFFS (no key, no memo). Where two top-level arms merge the SAME state -- the same shard bytes, shard-directory
# name, files in the directory, --out name and project root -- the later arm reads the earlier arm's saved answer instead
# of merging again. SAME RUN ONLY: the answers live in $HAND, which is "$WORK/hand", and $WORK is this invocation's own
# mktemp -d tree (removed by the EXIT trap); nothing is read from a previous run and nothing outlives this one. Only the
# source script directory ($1 = SRCDIR) saves or reads; a mutant drive (any other script directory) always runs its own
# merge, because hand_use returns 1 for it. A source-directory hand_use whose answer was never saved FAILS LOUDLY (a `bad`
# line, RC=99, empty $MO): it never falls back to a merge. Under --matrix, reuse_proof runs the reading arm's OWN merge in
# its own world and cmps it with the answer it read, one `REUSE <arm> reads=<source>` row per reuse.
HAND="$WORK/hand"; mkdir -p "$HAND"
# hand_keep <script-dir> <name> <out file> <shard dir>: save the last merge's $MO, RC and --out file under <name>.
hand_keep() {
  [ "$1" = "$SRCDIR" ] || return 0
  cp "$MO" "$HAND/$2.mo" && printf '%s' "$RC" > "$HAND/$2.rc" && printf '%s' "$3" > "$HAND/$2.o" && printf '%s' "$4" > "$HAND/$2.d"
  if [ -f "$3" ]; then cp "$3" "$HAND/$2.out"; else rm -f "$HAND/$2.out"; fi
  return 0
}
# hand_use <script-dir> <name>: restore RC and $MO from <name> (0); 1 for a mutant drive, which merges for itself.
hand_use() {
  [ "$1" = "$SRCDIR" ] || return 1
  if [ ! -f "$HAND/$2.mo" ]; then
    bad "HAND $2: no earlier arm of THIS run saved it; the reading arm does not fall back to a merge"
    : > "$MO"; RC=99; : > "$HAND/$2.o"; : > "$HAND/$2.d"; return 0
  fi
  cp "$HAND/$2.mo" "$MO" && RC="$(cat "$HAND/$2.rc")"
  return 0
}
hand_o() { cat "$HAND/$1.o"; }
hand_d() { cat "$HAND/$1.d"; }
refused_clean() { # <token> <shard-dir>: exit 2, REFUSED:, the token, no file at --out, no temp
  local o; o="$(out_of "$2")"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$o" ] \
    && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*' 2>/dev/null)" ]
}
# Check 1's read of the FIRST match, by the value rule gate-validation.md Check 1 states. The merge
# writes a bare member on the line under `## Verdict`, so the strip below is that rule on every
# input this fixture produces.
check1_value() { # <file>
  local m ln txt v
  m="$(grep -inE -- "$PAT" "$1" | sed -n 1p)"; [ -n "$m" ] || return 1
  ln="${m%%:*}"; txt="${m#*:}"
  case "$txt" in *:*) v="${txt#*:}" ;; *) v="$(awk -v s="$ln" 'NR > s && /[^ \t]/ { print; exit }' "$1")" ;; esac
  printf '%s' "$v" | sed -e 's/^[ *]*//' -e 's/[ *]*$//'
}
check1_count() { local n; n="$(grep -ciE -- "$PAT" "$1")" || n=0; printf '%s' "$n"; }

# ------------------------------------------------------------------------------- predicates
# Each takes the SCRIPT DIRECTORY to drive, so the mutant battery scores the arm's own body.
p_part() { # repo A partitions to >= 2 parts, and the dominant app/ was split, never one key
  local sd="$1" out n spread
  out="$(ip_run "$sd/partition-review-diff.sh" prd_main --map "$REPO_A" "$A_BASE" "$A_SHA" --min-files 4 < /dev/null 2>&1)" || return 1
  n="$(grep -cE '^[0-9]+	' <<<"$out")" || n=0
  [ "$n" -ge 2 ] || return 1
  spread="$(grep -c 'app/' <<<"$out")" || spread=0
  [ "$spread" -ge 2 ] || return 1
  awk -F'\t' '{ split($2, k, ","); for (i in k) if (k[i] == "app/") bad = 1 } END { exit bad }' <<<"$out" || return 1
  ! grep -q 'docs/reviews/' <<<"$out"
}
p_dflt_lo() { # key unset, no flag, DFLT-1 reviewable (DFLT in the diff) -> SERIAL naming the default
  local sd="$1" d
  d="$(mktemp -d "$WORK/lo.XXXXXX")/sd"
  run_part "$sd" "$REPO_LO" "$LO_BASE" "$LO_SHA" --shard-dir "$d"
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL: $((DFLT - 1)) reviewable file(s) ($DFLT in the diff" \
    && has "$PO" "below the threshold of $DFLT (the built-in default" && has "$PO" "$KEY" && [ ! -e "$d/.manifest" ]
}
p_dflt_hi() { # key unset, no flag, exactly DFLT reviewable -> partitions
  local sd="$1" n
  run_part "$sd" "$REPO_HI" "$HI_BASE" "$HI_SHA"
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ]
}
p_off() { # the key at 0, and --min-files 0, each -> SERIAL saying sharding is disabled, no manifest
  local sd="$1" d
  d="$(mktemp -d "$WORK/off.XXXXXX")/sd"
  PRC=0; ip_run -e "$KEY=0" "$sd/partition-review-diff.sh" prd_main --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
    --shard-dir "$d" > "$PO" 2> "$PE" < /dev/null || PRC=$?
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL: review sharding is disabled" && has "$PO" "$KEY is 0" \
    && [ ! -e "$d/.manifest" ] || return 1
  run_part "$sd" "$REPO_HI" "$HI_BASE" "$HI_SHA" --min-files 0 --shard-dir "$d"
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL: review sharding is disabled -- --min-files is 0" && [ ! -e "$d/.manifest" ]
}
p_refuse_val() { # the key set but EMPTY, WHITESPACE-only, or abc -> each REFUSED (exit 2), no manifest
  local sd="$1" d v
  d="$(mktemp -d "$WORK/rv.XXXXXX")/sd"
  for v in "" " " abc; do
    PRC=0; ip_run -e "$KEY=$v" "$sd/partition-review-diff.sh" prd_main --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
      --shard-dir "$d" > "$PO" 2> "$PE" < /dev/null || PRC=$?
    part_refused "$KEY '$v' is not a non-negative integer" "$d" || return 1
  done
}
p_prec() { # flag and key both set, disagreeing across DFLT files: the FLAG wins, in both directions
  local sd="$1" n
  PRC=0; ip_run -e "$KEY=4" "$sd/partition-review-diff.sh" prd_main --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
    --min-files "$((DFLT + 1))" > "$PO" 2> "$PE" < /dev/null || PRC=$?
  [ "$PRC" -eq 3 ] && has "$PO" "below the threshold of $((DFLT + 1)) (--min-files)" || return 1
  PRC=0; ip_run -e "$KEY=$((DFLT + 1))" "$sd/partition-review-diff.sh" prd_main --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
    --min-files 4 > "$PO" 2> "$PE" < /dev/null || PRC=$?
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ]
}
p_dmerge() { # a merge world partitioned with the threshold UNSET, merged end to end
  local sd="$1" w d o k n mn
  w="$(wdir)" || return 1
  d="$w/1-code-review-$D_SHA12"
  ip_run "$sd/partition-review-diff.sh" prd_main --map "$REPO_D" "$D_BASE" "$D_SHA" --shard-dir "$d" \
    > "$w/map" 2> "$w/map.err" < /dev/null || return 1
  [ -f "$d/.manifest" ] || return 1
  # The NUMERIC threshold applied, never a source string: the merge hands it back as --min-files.
  mn="$(awk -F'\t' '$1 == "min-files" { print $2 }' "$d/.manifest")"
  case "$mn" in ""|*[!0-9]*) return 1 ;; esac
  n=0
  for k in $(cut -f1 "$w/map"); do n=$((n + 1)); shard "$d" "$k" APPROVED "$k" "$D_SHA"; done
  [ "$n" -ge 2 ] || return 1
  ( SHARD_SHA="$D_SHA"; xshards "$sd" "$d" APPROVED ) || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  # A second world with the flag AND the key set, disagreeing: the manifest records the FLAG's
  # number, the threshold actually applied, because that is what the merge hands back.
  w="$(wdir)" || return 1
  d="$w/1-code-review-$D_SHA12"
  ip_run -e "$KEY=4" "$sd/partition-review-diff.sh" prd_main --map "$REPO_D" "$D_BASE" "$D_SHA" \
    --min-files "$((DFLT + 1))" --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
  mn="$(awk -F'\t' '$1 == "min-files" { print $2 }' "$d/.manifest")"
  [ "$mn" = "$((DFLT + 1))" ]
}
p_env_key() { # the key set to 4 in the environment, no flag -> partitions (named apart from EV1's p_env,
  # which a second definition of the same name replaced, so arm P3 ran EV1 and this body never ran)
  local sd="$1" out n
  out="$(ip_run -e "$KEY=4" "$sd/partition-review-diff.sh" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA" < /dev/null 2>&1)" || return 1
  n="$(grep -cE '^[0-9]+	' <<<"$out")" || n=0
  [ "$n" -ge 2 ]
}
p_worst() { # three worlds where count/cross/last disagree with worst-of, and the all-APPROVED control
  local sd="$1" d o w want
  for w in "BLOCKED APPROVED APPROVED APPROVED BLOCKED" \
           "NEEDS_REWORK BLOCKED NEEDS_REWORK APPROVED BLOCKED" \
           "APPROVED APPROVED APPROVED APPROVED APPROVED"; do
    set -- $w; want="$5"
    d="$(world4 "$sd" "$1" "$2" "$3" "$4")" || return 1
    o="$(out_of "$d")"; run_merge "$sd" "$d"
    [ "$w" != "APPROVED APPROVED APPROVED APPROVED APPROVED" ] || hand_keep "$sd" worst3 "$o" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=$want " && [ -f "$o" ] && [ "$(check1_value "$o")" = "$want" ] || return 1
  done
}
p_c1() { # Check 1's pattern matches the merged file EXACTLY once, and reads NEEDS_REWORK
  local sd="$1" d o
  d="$(world4 "$sd" NEEDS_REWORK APPROVED NEEDS_REWORK NEEDS_REWORK)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"; hand_keep "$sd" c1 "$o" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && [ "$(check1_count "$o")" = "1" ] && [ "$(check1_value "$o")" = "NEEDS_REWORK" ]
}
p_fence_nested() { # a ```` fence holding a ``` block, then a '#### ' finding citing part 2, then the ```` closer,
  # under shard 2's ## Findings: the finding is inside the fence, so the merge counts exactly the base
  # world's findings. A closer without the length rule ends the fence at the inner bare ``` and counts it.
  local sd="$1" d n0
  if ! hand_use "$sd" worst3; then   # V1's all-APPROVED merge is the base world's findings count
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    run_merge "$sd" "$d"
  fi
  [ "$RC" -eq 0 ] || return 1
  n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"; [ -n "$n0" ] || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  awk '{ print } /^### Important/ && !x { x = 1; print ""; print "````md"; print "```text"; print "quoted"; print "```"
         print "#### F-2-9 a finding quoted inside the outer fence"; print "parts: 2"; print "````"; print "" }' \
    "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md" && grep -q '^#### F-2-9 ' "$d/2.md" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "findings=$n0 "
}
p_conserve() { # a unique token from every part and from cross appears in the output
  local sd="$1" d o k
  if hand_use "$sd" c1; then o="$(hand_o c1)"   # C1 merged this exact state
  else
    d="$(world4 "$sd" NEEDS_REWORK APPROVED NEEDS_REWORK NEEDS_REWORK)" || return 1
    o="$(out_of "$d")"; run_merge "$sd" "$d"
  fi
  [ "$RC" -eq 0 ] && [ -f "$o" ] || return 1
  for k in 1 2 3 cross-1 cross-2 cross-3; do has "$o" "CONSERVE-$k-7f3a" && has "$o" "#### F-$k-1 " || return 1; done
}
p_miss_ord() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  rm -f "$d/2.md"; run_merge "$1" "$d"; hand_keep "$1" own_miss "$(out_of "$d")" "$d"; refused_clean "shard 2 is missing from" "$d"; }
p_miss_cross() { # a cross shard that is not the first one missing
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  [ -f "$d/cross-2.md" ] || return 1
  rm -f "$d/cross-2.md"; run_merge "$1" "$d"; refused_clean "shard cross-2 is missing from" "$d"; }
p_dup() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  cp "$d/1.md" "$d/01.md"; run_merge "$1" "$d"; hand_keep "$1" own_dup "$(out_of "$d")" "$d"; refused_clean "was delivered more than once" "$d"; }
p_part_cite() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 3; run_check "$1" "$d" code-review "$d/2.md"
  chk_refused "a part shard reports only findings citing its own part alone"; }
p_cross_one() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross-1 APPROVED 2; run_check "$1" "$d" code-review "$d/cross-1.md"
  chk_refused "a cross finding cites two or more parts"; }
p_sha_dir() { # the manifest's sha is not the one the directory name carries
  local d n; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  n="$(dirname "$d")/1-code-review-000000000000"; mv "$d" "$n"
  run_merge "$1" "$n"; refused_clean "is not <idx>-code-review-<sha12>" "$n"; }
p_sha_rev() { # one shard reviewed another tree
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 2 "$B_BASE"; run_check "$1" "$d" code-review "$d/2.md"
  chk_refused "not the frozen sha"; }
p_moved() { # the manifest was written, then the worktree's scan roots moved under it
  local sd="$1" w c d g
  w="$(mktemp -d "$WORK/mv.XXXXXX")" || return 1
  c="$w/repo"; cp -R "$REPO_B" "$c" || return 1
  d="$(new_world "$sd" "$c")" || return 1
  shard "$d" 1 APPROVED 1; shard "$d" 2 APPROVED 2; shard "$d" 3 APPROVED 3; xshards "$sd" "$d" APPROVED || return 1
  g="$c/core/skills/ai-dlc/artifact-path-grammar.md"
  awk '{ print } /^```scan-roots$/ { print "alpha/a1.txt" }' "$g" > "$g.new" && mv "$g.new" "$g"
  # The re-run must still PARTITION (5 reviewable >= 4), or the refusal is the wrong one.
  ip_run "$sd/partition-review-diff.sh" prd_main --map "$c" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 > "$w/remap" 2>&1 < /dev/null || return 1
  ! cmp -s "$w/remap" "$(dirname "$d")/map" || return 1
  run_merge "$sd" "$d"
  refused_clean "differs from the map it records" "$d"
}
p_a3() { # a shard body carrying `## Verdict` -> two Check-1 matches -> refused
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 2 "" "$(printf '## Verdict\nAPPROVED')"; run_merge "$1" "$d"; hand_keep "$1" own_a3 "$(out_of "$d")" "$d"
  refused_clean "matches Check 1's verdict pattern 2 time(s)" "$d"
}
# A partition refusal: exit 2, ONE stderr line `partition-review-diff: REFUSED — ...` carrying the
# token, nothing on stdout, and no manifest (nor its temp) in <dir>.
run_part() { # <script-dir> <args...> -> PRC, $PO, $PE
  local sd="$1"; shift
  ip_run "$sd/partition-review-diff.sh" prd_main --map "$@" > "$PO" 2> "$PE" < /dev/null; PRC=$?
}
part_refused() { # <token> <shard-dir>
  [ "$PRC" -eq 2 ] && has "$PE" "partition-review-diff: REFUSED" && has "$PE" "$1" && ! grep -q . "$PO" \
    && [ ! -e "$2/.manifest" ] && [ -z "$(find "$2" -maxdepth 1 -name '.manifest.tmp.*' 2>/dev/null)" ]
}
# A shard written by hand, for the bodies shard() cannot express.
raw_shard() { # <dir> <key> <body...>: the two shard lines, then the body lines verbatim
  local d="$1" k="$2"; shift 2
  { printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\n' "$k" "$B_SHA"; adv_l
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n'; printf '%s\n' "$@"; } > "$d/$k.md"
}
p_rerun() { # MC: an identical re-merge is UNCHANGED; after a shard changed, refused, file untouched
  local sd="$1" d o
  if hand_use "$sd" worst3; then d="$(hand_d worst3)"; o="$(hand_o worst3)"   # V1's all-APPROVED merge is this first merge
  else
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    o="$(out_of "$d")"; run_merge "$sd" "$d"
  fi
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  cp "$o" "$RERUN_KEEP" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED:" && cmp -s "$o" "$RERUN_KEEP" || return 1
  shard "$d" 1 BLOCKED 1; run_merge "$sd" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "a review file is never overwritten" \
    && cmp -s "$o" "$RERUN_KEEP" && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*')" ]
}
p_anc() { # E1: a base that is not an ancestor of the frozen sha is refused, nothing written
  local sd="$1" d
  d="$(mktemp -d "$WORK/anc.XXXXXX")/sd"
  run_part "$sd" "$REPO_B" "$B_SIB" "$B_SHA" --min-files 4 --max-parts 3 --shard-dir "$d"
  part_refused "is not an ancestor of the frozen sha" "$d"
}
p_cross_sha() { # MF: a CROSS shard (not the first) carrying the base sha as reviewed-sha
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross-2 APPROVED "1, 3" "$B_BASE"; run_check "$1" "$d" code-review "$d/cross-2.md"
  chk_refused "not the frozen sha"; }
p_bad_verdict() { # MG: `shard-verdict: PASS` is outside the three ranked values
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 PASS 2; run_check "$1" "$d" code-review "$d/2.md"
  chk_refused "shard-verdict 'PASS' is not one of APPROVED NEEDS_REWORK BLOCKED"; }
p_noparts() { # MH: a `#### ` finding inside ## Findings with no parts: line
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 2 '## Findings' '' '### Critical (must fix before merge)' '' \
    '#### F-2-1 cited' 'parts: 2' '' '#### F-2-2 uncited' '' 'Body of the finding.'
  run_check "$1" "$d" code-review "$d/2.md"; chk_refused "finding carries 0 'parts:' lines"; }
p_manifest() { # MI: an identical re-run leaves the manifest; a --max-parts 2 re-run is refused
  local sd="$1" d keep
  d="$(new_world "$sd")" || return 1
  keep="$(dirname "$d")/manifest.keep"; cp "$d/.manifest" "$keep" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 --shard-dir "$d"
  [ "$PRC" -eq 0 ] && cmp -s "$d/.manifest" "$keep" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 2
  [ "$PRC" -eq 0 ] && ! cmp -s "$PO" "$(dirname "$d")/map" || return 1   # the two maps differ
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 2 --shard-dir "$d"
  [ "$PRC" -eq 2 ] && has "$PE" "a manifest is never overwritten" && cmp -s "$d/.manifest" "$keep" \
    && [ -z "$(find "$d" -maxdepth 1 -name '.manifest.tmp.*')" ]
}
p_two_sha() { # MK: a second reviewed-sha: line (the base) after the right one
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 2 "" "reviewed-sha: $B_BASE"; run_check "$1" "$d" code-review "$d/2.md"
  chk_refused "carries 2 'reviewed-sha:' line(s)"; }
p_default_k() { # MM: four equal groups, no --max-parts -> exactly four parts
  local sd="$1" n
  run_part "$sd" "$REPO_C" "$C_BASE" "$C_SHA" --min-files 4
  [ "$PRC" -eq 0 ] || return 1
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$n" = "4" ]
}
p_stray() { # E3a: parts: outside a #### finding under ## Findings, in a shard that HAS ## Findings
  local sd="$1" d
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 1 '## Findings' '' '### Critical (must fix before merge)' '' \
    '- **C-1** SQL injection in part 3 code' '  parts: 3'
  run_check "$sd" "$d" code-review "$d/1.md"
  chk_refused "carries a 'parts:' line outside a '#### ' finding under '## Findings'" || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 1 '## Critical Issues' '' '#### C-1 boom' 'parts: 3' '' \
    '## Findings' '' '### Critical (must fix before merge)' '' '#### F-1-1 cited' 'parts: 1'
  run_check "$sd" "$d" code-review "$d/1.md"
  chk_refused "carries a 'parts:' line outside a '#### ' finding under '## Findings'"
}
p_nofind() { # E3b: a shard with no ## Findings section (and no parts: line anywhere)
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 1 '## Summary' 'Nothing to report.'
  run_check "$1" "$d" code-review "$d/1.md"; chk_refused "carries no '## Findings' section"; }
p_knob() { # E2: a value over 9 digits refuses before arithmetic; a 9-digit threshold is SERIAL
  local sd="$1" d
  d="$(mktemp -d "$WORK/knob.XXXXXX")/sd"
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 18446744073709551617 --shard-dir "$d"
  part_refused "'18446744073709551617' is longer than 9 digits" "$d" || return 1
  PRC=0; ip_run -e "$KEY=18446744073709551617" "$sd/partition-review-diff.sh" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA" \
    --shard-dir "$d" > "$PO" 2> "$PE" < /dev/null || PRC=$?
  part_refused "$KEY '18446744073709551617' is longer than 9 digits" "$d" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 18446744073709551617 --shard-dir "$d"
  part_refused "--max-parts '18446744073709551617' is longer than 9 digits" "$d" || return 1
  # 65, not a 9-digit K: with the ceiling mutated away a 9-digit K spins the packer, and the
  # arm must die by a map appearing, not by the fixture hanging.
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 65 --shard-dir "$d"
  part_refused "--max-parts 65 is above 64" "$d" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 999999999 --shard-dir "$d"
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL:" && [ ! -e "$d/.manifest" ]
}
# ------------------------------------------------------------------------- gate 2: --gate qa
# QA shards are the gate-1 grammar with qa.md's verdict set {PASS, NEEDS_REWORK}, the shard dir
# `<idx>-qa-validation-<sha12>[-p<M>]`, and two sections only the cross shard carries: the per-AC
# table under `## Acceptance Criteria` (exactly one) and `## Deferred ACs` (at most one). Shaped on
# qa.md's own output: a per-AC result is a PIPE-LED table row, which Check 1's pattern cannot match.
# THE REFUSAL TOKENS are the merge's own message fragments; each arm demands one, so an arm whose
# subject refused for another reason does not pass.
QT_PART_AC="(part shard 2) carries a '## Acceptance Criteria' section"
QT_PART_DEF="(part shard 3) carries a '## Deferred ACs' section"
QT_AC_0="carries 0 '## Acceptance Criteria' section(s) outside a fence; the cross shard carries exactly one"
QT_AC_2="carries 2 '## Acceptance Criteria' section(s) outside a fence; the cross shard carries exactly one"
QT_DEF_COUNT="carries 2 '## Deferred ACs' sections outside a fence; the cross shard carries at most one"
QT_VSET="qa.md's ## Verdict template declares"
QT_VSET_CR="code-reviewer.md's ## Verdict template declares"
QT_PASS="pass marker mismatch"
QT_SUFFIX="is not <idx>-qa-validation-<sha12>"
QT_SUFFIX_CR="is not <idx>-code-review-<sha12>"
QT_GATE="is not code-review or qa"
QT_RANK="shard-verdict 'APPROVED' is not one of PASS NEEDS_REWORK"
QA_SFX="qa-validation"
qout() { printf '%s/%s-%s%s.md' "$(dirname "$1")" "${KIDX:-1}" "${2:-$QA_SFX}" "${3:-}"; } # <dir> [sfx] [pass marker]; KIDX the index (1)
# qcwd <shard dir> -> the lead checkout a qa merge runs from: the repository holding the shard directory's docs/reviews/
# (a string operation, no fork); a path with no docs/reviews/ component is its own directory. QCWD overrides it.
qcwd() { if [ -n "${QCWD:-}" ]; then printf '%s' "$QCWD"; else case "$1" in */docs/reviews/*) printf '%s' "${1%%/docs/reviews/*}" ;; *) printf '%s' "$1" ;; esac; fi; }
run_mg() { # <script-dir> <shard-dir> <gate> <out> [project-root] -> RC, $MO
  ip_run -C "${QCWD:-${2%%/docs/reviews/*}}" -e "AI_DLC_PROJECT_ROOT=${5:-${VB_PROJ:-$PROJ}}" "$1/merge-review-shards.sh" mrs_main "$2" --gate "$3" --out "$4" \
    > "$MO" 2>&1 < /dev/null; RC=$?
}
refused_at() { # <token> <out>
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$2" ] \
    && [ -z "$(find "$(dirname "$2")" -maxdepth 1 -name '*.merge-tmp.*' 2>/dev/null)" ]
}
# qshard <dir> <key> <verdict> <cite> [extra trailing text] [handovers count]. The cross shard
# carries the per-AC table and the deferred-AC record; a part shard carries neither, and carries
# the declared `handovers: <n>` header line instead -- 0 unless the caller names the count its
# extra text hands over. The count is written by each caller, never computed from the text here:
# a helper that counted the text would be a second copy of the merge's parser.
# CANON_BLK (BL-769): the execution owner's canonical run, as qa.md tells it to write one -- the
# invocation line and the summary line with counts. Every first-cross QA shard and every serial QA
# file carries it, so a PASS merges; the canonical-run cells below remove or rewrite it.
CANON_BLK="$(printf 'Canonical run: `python3 -m pytest -q` from the frozen worktree root\nCanonical result: 812 passed, 3 skipped, 0 failed, 0 deselected')"
qshard() {
  local d="$1" k="$2" v="$3" cite="$4" extra="${5:-}" hc="${6:-0}"
  {
    printf '# QA Validation shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$k" in cross*) ;; *) [ "$hc" = OMIT ] || printf 'handovers: %s\n' "$hc" ;; esac
    printf '\n'
    printf '## Summary\nShard %s validated its part. QCONSERVE-%s-91c2\n\n' "$k" "$k"
    { [ "$k" = cross ] || [ "$k" = cross-1 ]; } && printf '%s\n\n' "$CANON_BLK"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-%s-1 a missing caller in shard %s\nparts: %s\n\nBody.\n\n' "$k" "$k" "$cite"
    # The per-AC table and the deferred record: the FIRST cross shard's alone (the execution owner).
    if [ "$k" = cross ] || [ "$k" = cross-1 ]; then
      printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n| AC2 | %s | replay |\n\n' "$v"
      printf '## Deferred ACs\n\nNone.\n'
    fi
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$d/$k.md"
}
qworld() { # <script-dir> <v1> <v2> <v3> <vcross> [pass marker] -> a qa shard dir with all four shards
  local d; d="$(new_world "$1" "$REPO_B" "$QA_SFX" "${6:-}")" || return 1
  qshard "$d" 1 "$2" 1; qshard "$d" 2 "$3" 2; qshard "$d" 3 "$4" 3; xshards "$1" "$d" "$5" qa || return 1
  printf '%s' "$d"
}
q_merge() { local o; o="$(qout "$2")"; run_mg "$1" "$2" qa "$o"; }
p_q_worst() { # Q1: worst-of over {PASS, NEEDS_REWORK}; the one-part-NR world is where an inverted rank answers PASS
  local sd="$1" d o w want
  for w in "PASS PASS PASS PASS PASS" "NEEDS_REWORK PASS PASS PASS NEEDS_REWORK" \
           "PASS PASS PASS NEEDS_REWORK NEEDS_REWORK"; do
    set -- $w; want="$5"
    d="$(qworld "$sd" "$1" "$2" "$3" "$4")" || return 1
    o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$w" != "PASS PASS PASS PASS PASS" ] || hand_keep "$sd" qw1 "$o" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "verdict=$want " && [ -f "$o" ] \
      && [ "$(check1_value "$o")" = "$want" ] || return 1
  done
}
p_q_table() { # Q2 (A6): a cross shard carrying a '| AC | Verdict |' table merges, Check 1 matching ONCE
  local sd="$1" d o k
  if hand_use "$sd" qw1; then d="$(hand_d qw1)"; o="$(hand_o qw1)"   # Q1's all-PASS merge is this state
  else
    d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
    o="$(qout "$d")"; q_merge "$sd" "$d"
  fi
  [ "$RC" -eq 0 ] && [ -f "$o" ] && has "$o" "| AC | Verdict | Evidence |" && [ "$(check1_count "$o")" = "1" ] || return 1
  for k in 1 2 3 cross-1 cross-2 cross-3; do has "$o" "QCONSERVE-$k-91c2" && has "$o" "#### Q-$k-1 " || return 1; done
}
p_q_title() { # Q3: the merged title names the gate -- `# Code Review:` for gate 1, `# QA Validation:` for gate 2
  local sd="$1" d o
  if hand_use "$sd" worst3; then o="$(hand_o worst3)"   # V1's all-APPROVED merge
  else
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    o="$(out_of "$d")"; run_merge "$sd" "$d"
  fi
  [ "$RC" -eq 0 ] && [ "$(sed -n 1p "$o")" = "# Code Review: 1 (merged from 6 shards)" ] || return 1
  if hand_use "$sd" qw1; then o="$(hand_o qw1)"   # Q1's all-PASS merge
  else
    d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
    o="$(qout "$d")"; q_merge "$sd" "$d"
  fi
  [ "$RC" -eq 0 ] && [ "$(sed -n 1p "$o")" = "# QA Validation: 1 (merged from 6 shards)" ]
}
p_q_fenced() { # Q4 near-miss: a part shard quoting '## Acceptance Criteria' and '## Deferred ACs' inside a fence merges
  local sd="$1" d
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '```text\n## Acceptance Criteria\n## Deferred ACs\n```')"
  q_merge "$sd" "$d"; [ "$RC" -eq 0 ] && has "$MO" "MERGED:"
}
p_q_part_ac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC1 | PASS |')"
  q_chk "$1" "$d" 2; chk_refused "$QT_PART_AC"; }
p_q_part_def() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 3 PASS 3 "$(printf '## Deferred ACs\n\n- AC4: discharged by the deploy run')"
  q_chk "$1" "$d" 3; chk_refused "$QT_PART_DEF"; }
p_q_cross_noac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  awk '/^## Acceptance Criteria$/ { print "## Per-AC results"; next } { print }' "$d/cross-1.md" > "$d/cross.tmp" \
    && mv "$d/cross.tmp" "$d/cross-1.md" && ! grep -q '^## Acceptance Criteria' "$d/cross-1.md" || return 1
  q_chk "$1" "$d" cross-1; chk_refused "$QT_AC_0"; }
p_q_cross_twoac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross-1 PASS "1, 2" "$(printf '\n## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  q_chk "$1" "$d" cross-1; chk_refused "$QT_AC_2"; }
p_q_cross_twodef() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross-1 PASS "1, 2" "$(printf '\n## Deferred ACs\n\n- AC5: deferred')"
  q_chk "$1" "$d" cross-1; chk_refused "$QT_DEF_COUNT"; }
p_q_nodef() { # Q-allow: a cross shard with NO '## Deferred ACs' merges (at most one, not exactly one)
  local d; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  awk '/^## Deferred ACs$/ { skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$d/cross-1.md" > "$d/cross.tmp" \
    && mv "$d/cross.tmp" "$d/cross-1.md" && ! grep -q '^## Deferred ACs' "$d/cross-1.md" || return 1
  q_merge "$1" "$d"; [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; }
p_q_secvar() { # Q16: the section counts take any heading VARIANT a shard writer produces -- case,
  # a trailing colon or word, two spaces, a `### ` level. One world, its part shards rewritten per
  # cell: a refusal writes nothing, so the world stays mergeable for the next cell.
  local sd="$1" d o h
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for h in '## Acceptance Criteria:' '##  Acceptance Criteria' '## acceptance criteria' '### ACCEPTANCE CRITERIA'; do
    qshard "$d" 2 PASS 2 "$(printf '%s\n\n| AC | Verdict |\n|---|---|\n| AC1 | PASS |' "$h")"
    q_chk "$sd" "$d" 2; chk_refused "$QT_PART_AC" || return 1
  done
  qshard "$d" 2 PASS 2
  for h in '### Deferred ACs' '## Deferred / operator-owned' '## deferred acs'; do
    qshard "$d" 3 PASS 3 "$(printf '%s\n\n- AC4: discharged by the deploy run' "$h")"
    q_chk "$sd" "$d" 3; chk_refused "$QT_PART_DEF" || return 1
  done
  qshard "$d" 3 PASS 3
  qshard "$d" cross-1 PASS "1, 2" "$(printf '\n## Acceptance Criteria:\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  q_chk "$sd" "$d" cross-1; chk_refused "$QT_AC_2" || return 1
  # Near-misses, which MERGE: the variants inside a fence, and a `#### ` FINDING titled with a
  # section name -- that level is a finding, never a section.
  qshard "$d" cross-1 PASS "1, 2"
  qshard "$d" 2 PASS 2 "$(printf '```text\n## Acceptance Criteria:\n### deferred ACs\n```\n\n#### Acceptance criteria AC3 unmet\nparts: 2\n\nBody.\n\n#### Deferred AC4 has no predicate\nparts: 2\n\nBody.')"
  q_merge "$sd" "$d"; [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && has "$o" "Acceptance criteria AC3 unmet"
}
p_q_rank() { # a qa shard carrying a gate-1 verdict is refused (APPROVED is not a QA verdict)
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 APPROVED 2; q_chk "$1" "$d" 2; chk_refused "$QT_RANK"; }
p_q_pm() { # A4, both gates: dir and --out pass markers agree -> merge; either one alone -> refused.
  # The merging cells assert MERGED and the file, never the verdict, so the verdict mutants are
  # owned by V1/Q1 alone.
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS -p2)" || return 1
  o="$(qout "$d" "$QA_SFX" -p2)"; run_mg "$sd" "$d" qa "$o"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS -p2)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o"; refused_at "$QT_PASS" "$o" || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d" "$QA_SFX" -p2)"; run_mg "$sd" "$d" qa "$o"; refused_at "$QT_PASS" "$o" || return 1
  d="$(new_world "$sd" "$REPO_B" code-review -p3)" || return 1
  shard "$d" 1 APPROVED 1; shard "$d" 2 APPROVED 2; shard "$d" 3 APPROVED 3; xshards "$sd" "$d" APPROVED || return 1
  o="$(qout "$d" code-review -p3)"; run_mg "$sd" "$d" code-review "$o"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  o="$(qout "$d" code-review)"; run_mg "$sd" "$d" code-review "$o"; refused_at "$QT_PASS" "$o" || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(qout "$d" code-review -p2)"; run_mg "$sd" "$d" code-review "$o"; hand_keep "$sd" own_qpm_set "$o" "$d"; refused_at "$QT_PASS" "$o"
}
p_q_suffix() { # a gate-1 shard dir merged as --gate qa, and a qa shard dir merged as --gate code-review
  local sd="$1" d o
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o"; refused_at "$QT_SUFFIX" "$o" || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(out_of "$d")"; run_mg "$sd" "$d" code-review "$o"; refused_at "$QT_SUFFIX_CR" "$o"
}
p_q_gate() { # an unknown gate refuses, on a world either gate would merge
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" deploy "$o"; refused_at "$QT_GATE" "$o"
}
# Two project roots for the verdict-set lift. QBAD: qa.md declares a third value -> --gate qa
# refuses. CRBAD (the ALLOW twin, one property apart): code-reviewer.md's verdict line broken,
# qa.md intact -> --gate qa still merges and --gate code-review refuses. A merge that lifted QA's
# set from code-reviewer.md fails both halves.
PROJ_QBAD="$WORK/proj-qbad"; PROJ_CRBAD="$WORK/proj-crbad"
for _r in "$PROJ_QBAD" "$PROJ_CRBAD"; do
  mkdir -p "$_r/core/skills/ai-dlc/steps" "$_r/core/team-roles"
  cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$_r/core/skills/ai-dlc/steps/"
  cp "$PROJ/core/team-roles/code-reviewer.md" "$PROJ/core/team-roles/qa.md" "$_r/core/team-roles/"
done
sed -e 's/^PASS | NEEDS_REWORK$/PASS | NEEDS_REWORK | BLOCKED/' "$PROJ/core/team-roles/qa.md" > "$PROJ_QBAD/core/team-roles/qa.md"
sed -e 's/^APPROVED | NEEDS_REWORK | BLOCKED$/APPROVED | NEEDS_REWORK | BLOCKED | DEFERRED/' "$PROJ/core/team-roles/code-reviewer.md" > "$PROJ_CRBAD/core/team-roles/code-reviewer.md"
# BL-746: two more qa.md roots, derived from the subject's own qa.md. QLEG is the qa.md a consumer runs
# the engine against from pull step 3 until the reconcile merge: its `## Findings Template` section
# (to the next `## ` heading outside a fence) removed, so the template declares NO container. Q2 keeps
# the section and drops its Suggestions container, so it declares two. Each carries its own control:
# QLEG must lose the section and keep the verdict set, Q2 must differ from the subject by one line.
PROJ_QLEG="$WORK/proj-qleg"; PROJ_Q2="$WORK/proj-q2"
for _r in "$PROJ_QLEG" "$PROJ_Q2"; do
  mkdir -p "$_r/core/skills/ai-dlc/steps" "$_r/core/team-roles"
  cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$_r/core/skills/ai-dlc/steps/"
  cp "$PROJ/core/team-roles/code-reviewer.md" "$_r/core/team-roles/"
done
awk '/^```/ { f = !f } !f && /^## / { skip = ($0 ~ /^## Findings Template[ \t]*$/) } !skip' "$PROJ/core/team-roles/qa.md" > "$PROJ_QLEG/core/team-roles/qa.md"
grep -v '^### Suggestions ' "$PROJ/core/team-roles/qa.md" > "$PROJ_Q2/core/team-roles/qa.md"
_q_t="$(grep -c '^## Findings Template' "$PROJ/core/team-roles/qa.md")" || _q_t=0
_q_l="$(grep -c '^### \(Critical\|Important\|Suggestions\) ' "$PROJ_QLEG/core/team-roles/qa.md")" || _q_l=0
_q_v="$(grep -c '^PASS | NEEDS_REWORK$' "$PROJ_QLEG/core/team-roles/qa.md")" || _q_v=0
_q_2=$(( $(wc -l < "$PROJ/core/team-roles/qa.md") - $(wc -l < "$PROJ_Q2/core/team-roles/qa.md") ))
[ "$_q_t" = 1 ] && [ "$_q_l" = 0 ] && [ "$_q_v" = 1 ] && [ "$_q_2" = 1 ] \
  || { echo "FIXTURE STALE: the qa.md roots cannot express the container states (template $_q_t, legacy containers $_q_l, legacy verdict line $_q_v, two-container diff $_q_2)" >&2; exit 2; }
# BL-844: two qa.md Class states, each derived from the subject's qa.md with every column-0 `Class:` line
# removed first, so neither depends on whether the shipped qa.md carries the template yet. QCLS appends
# code-reviewer.md's own template line (the set I129 holds equal); QNOCLS is the stripped copy alone.
PROJ_QCLS="$WORK/proj-qcls"; PROJ_QNOCLS="$WORK/proj-qnocls"
for _r in "$PROJ_QCLS" "$PROJ_QNOCLS"; do
  mkdir -p "$_r/core/skills/ai-dlc/steps" "$_r/core/team-roles"
  cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$_r/core/skills/ai-dlc/steps/"
  cp "$PROJ/core/team-roles/code-reviewer.md" "$_r/core/team-roles/"
  grep -v '^Class:' "$PROJ/core/team-roles/qa.md" > "$_r/core/team-roles/qa.md"
done
_q_c="$(awk '/^Class: [A-Z_]+( \| [A-Z_]+)+$/ { print; exit }' "$PROJ/core/team-roles/code-reviewer.md")"
printf '\n## Finding Class\n\n%s\n' "$_q_c" >> "$PROJ_QCLS/core/team-roles/qa.md"
[ -n "$_q_c" ] && [ "$(grep -c '^Class: ' "$PROJ_QCLS/core/team-roles/qa.md")" = 1 ] && ! grep -q '^Class:' "$PROJ_QNOCLS/core/team-roles/qa.md" \
  || { echo "FIXTURE STALE: the qa.md Class roots cannot express the two states (code-reviewer.md template '$_q_c')" >&2; exit 2; }
# THE SEVERITY BOUNDARY's two frozen trees (BL-746). B's six files over a base that INSTALLS qa.md at the
# consumer path .claude/team-roles/qa.md -- QL the container-less one (PROJ_QLEG's, graph's installed
# shape), QS the subject's own. The installed copy sits in the BASE commit, so the map is B's (K=3).
# REPO_B itself installs no qa.md: the unreadable side.
REPO_QL="$WORK/repo-ql"; REPO_QS="$WORK/repo-qs"
for _r in "$REPO_QL" "$REPO_QS"; do
  new_repo "$_r" old || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
  mkdir -p "$_r/.claude/team-roles"
  if [ "$_r" = "$REPO_QL" ]; then cp "$PROJ_QLEG/core/team-roles/qa.md" "$_r/.claude/team-roles/qa.md"
  else cp "$PROJ/core/team-roles/qa.md" "$_r/.claude/team-roles/qa.md"; fi
  G -C "$_r" add -A && G -C "$_r" commit -q --amend -m base || { echo "FIXTURE ERROR: the installed qa.md was not committed" >&2; exit 2; }
  for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$_r/$f" 5 "$f"; done
  G -C "$_r" add -A && G -C "$_r" commit -q -m frozen || { echo "FIXTURE ERROR: git commit failed" >&2; exit 2; }
done
QL_BASE="$(G -C "$REPO_QL" rev-parse HEAD~1)"; QL_SHA="$(G -C "$REPO_QL" rev-parse HEAD)"
QS_BASE="$(G -C "$REPO_QS" rev-parse HEAD~1)"; QS_SHA="$(G -C "$REPO_QS" rev-parse HEAD)"
_ql="$(G -C "$REPO_QL" show "${QL_SHA}:.claude/team-roles/qa.md" | grep -c '^## Findings Template')" || _ql=0
_qs="$(G -C "$REPO_QS" show "${QS_SHA}:.claude/team-roles/qa.md" | grep -c '^## Findings Template')" || _qs=0
_qb=0; G -C "$REPO_B" cat-file -e "${B_SHA}:.claude/team-roles/qa.md" 2>/dev/null && _qb=1
[ "$_ql" = 0 ] && [ "$_qs" = 1 ] && [ "$_qb" = 0 ] \
  || { echo "FIXTURE STALE: the frozen trees cannot express the severity boundary (QL template $_ql, QS template $_qs, B carries qa.md $_qb)" >&2; exit 2; }
p_q_vset() {
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o" "$PROJ_QBAD"; refused_at "$QT_VSET" "$o" || return 1
  run_mg "$sd" "$d" qa "$o" "$PROJ_CRBAD"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ -f "$o" ] || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(out_of "$d")"; run_mg "$sd" "$d" code-review "$o" "$PROJ_CRBAD"; refused_at "$QT_VSET_CR" "$o"
}
# HAND-OVERS (--gate qa). A part shard whose replay cannot reach a GREEN baseline hands the AC to
# the cross shard as a `handover: <AC>` line in a `#### ` finding; the cross shard records the
# replay it ran as `handover-run: <ordinal> <AC> <result>`. Seeded the way qa.md tells each writer
# to emit them: the part's finding under `### Important`, the cross's inside its `## Findings`.
# The hand-over sits in part 2, never the first part read.
QT_HO_UNM="hand-over '2 AC7' (part shard 2) has no 'handover-run:' line in cross-1.md"
QT_HO_ORPH="cross-1.md carries 'handover-run: 2 AC7' but part shard 2 handed over no such AC"
QT_HO_CROSS="carries a 'handover:' line; only a part shard hands an AC over"
QT_HO_PRUN="(part shard 3) carries a 'handover-run:' line; only the cross shard runs a handed-over replay"
QT_HO_CITE="a hand-over replay finding cites exactly the parts it ran replays for"
QT_HO_STRAY="carries a 'handover:' or 'handover-run:' line outside a '#### ' finding"
HO_PART2="$(printf '### Important\n\n#### Q-2-H AC7 replay cannot reach a GREEN baseline in the part worktree\nparts: 2\nhandover: AC7\n\nThe documented setup fails in a fresh worktree.')"
qcross() { # <dir> <verdict> <text inserted inside cross-1.md's ## Findings> -- the execution owner
  {
    printf '# QA Validation shard cross-1\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$B_SHA" "$2"; adv_l; printf '\n'
    printf '## Summary\nShard cross-1 validated its part. QCONSERVE-cross-1-91c2\n\n%s\n\n' "$CANON_BLK"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-cross-1-1 a missing caller in shard cross-1\nparts: 1, 2\n\nBody.\n\n%s\n\n' "$3"
    printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n\n## Deferred ACs\n\nNone.\n'
  } > "$1/cross-1.md"
}
ho_run() { printf '#### Q-cross-H hand-over replays\nparts: %s\nhandover-run: %s\n\nRan in the frozen worktree after setup.' "$1" "$2"; }
p_q_ho_ok() { # a hand-over matched by `handover-run: ... RED` merges at the shard verdicts' worst-of
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1; qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ "$(check1_value "$o")" = "PASS" ] && has "$o" "| 2 | AC7 | RED |"
}
p_q_ho_unm() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1; o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_UNM" "$o"; }
p_q_ho_orph() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"; o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_ORPH" "$o"; }
p_q_ho_force() { # GREEN-SURVIVED and NO-BASELINE each force NEEDS_REWORK over four PASS shards
  local d o r
  for r in GREEN-SURVIVED NO-BASELINE; do
    d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
    qshard "$d" 2 PASS 2 "$HO_PART2" 1; qcross "$d" PASS "$(ho_run 2 "2 AC7 $r")"
    o="$(qout "$d")"; q_merge "$1" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK " && [ "$(check1_value "$o")" = "NEEDS_REWORK" ] || return 1
  done
}
p_q_ho_cross() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qcross "$d" PASS "$(printf '#### Q-cross-H AC8 cannot be replayed\nparts: 1, 3\nhandover: AC8\n\nBody.')"
  q_chk "$1" "$d" cross-1; chk_refused "$QT_HO_CROSS"; }
p_q_ho_prun() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 3 PASS 3 "$(printf '#### Q-3-H ran AC7 myself\nparts: 3\nhandover-run: 3 AC7 RED\n\nBody.')"
  q_chk "$1" "$d" 3; chk_refused "$QT_HO_PRUN"; }
p_q_ho_fenced() { # a hand-over and a forcing replay QUOTED inside fences, inside findings, count as neither
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '#### Q-2-F quoting the grammar\nparts: 2\n\n```text\nhandover: AC7\n```')"
  qcross "$d" PASS "$(printf '#### Q-cross-F quoting the grammar\nparts: 1, 2\n\n~~~\nhandover-run: 2 AC9 GREEN-SURVIVED\n~~~')"
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ "$(check1_value "$o")" = "PASS" ]
}
p_q_ho_shape() { # a replay finding citing a part it ran nothing for, and a bulleted hand-over, each refused
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1; qcross "$d" PASS "$(ho_run '1, 2' '2 AC7 RED')"
  q_chk "$1" "$d" cross-1; chk_refused "$QT_HO_CITE" || return 1
  qshard "$d" 2 PASS 2 "$(printf '#### Q-2-H AC7 replay cannot reach a GREEN baseline\nparts: 2\n- handover: AC7\n\nBody.')" 1
  qcross "$d" PASS ""
  q_chk "$1" "$d" 2; chk_refused "$QT_HO_STRAY"
}
# THREE REFUSALS, EACH KEYED ON ITS OWN MESSAGE, each world shaped so that WITHOUT the refusal it
# MERGES rather than failing elsewhere: a two-AC line whose first AC is run (the second AC's
# replay is then run by nobody and the merge said PASS -- measured); two `handover:` lines in one
# finding, both run; the same hand-over in two findings, run once.
QT_HO_MULTI="handover: 'AC7 AC8' names more than one AC; a hand-over line names exactly one <AC-id>"
QT_HO_TWOLINE="finding carries 2 'handover:' lines; a hand-over finding names exactly one AC"
QT_HO_DUP="hand-over '2 AC7' (<ordinal> <AC-id>) is handed over more than once"
QT_HO_BAD="is a malformed hand-over line (decorated, quoted, hyphenated or missing its colon)"
QT_HO_ACID="is not an <AC-id> (one token beginning with a letter or digit)"
p_q_ho_multi() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 and AC8 cannot reach GREEN\nparts: 2\nhandover: AC7 AC8\n\nBody.')" 1
  qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  q_chk "$1" "$d" 2; chk_refused "$QT_HO_MULTI"; }
p_q_ho_twoline() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 and AC8 cannot reach GREEN\nparts: 2\nhandover: AC7\nhandover: AC8\n\nBody.')" 2
  qcross "$d" PASS "$(printf '#### Q-cross-H hand-over replays\nparts: 2\nhandover-run: 2 AC7 RED\nhandover-run: 2 AC8 RED\n\nRan both.')"
  q_chk "$1" "$d" 2; chk_refused "$QT_HO_TWOLINE"; }
p_q_ho_dup() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '%s\n\n#### Q-2-H2 AC7 again\nparts: 2\nhandover: AC7\n\nBody.' "$HO_PART2")" 2
  qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_DUP" "$o"; }
# A MISSPELLED HAND-OVER DROPS SILENTLY unless something refuses it: it is neither a hand-over nor
# a stray, so a part's unreachable AC merged with no replay owed. Each form in its own cell, in a
# part-2 finding where a real `handover:` line would sit. The near-miss (q_ho_prose) is prose
# that NAMES the hand-over -- at column 0, with a colon later in the line, and `Handover step`,
# which the no-colon form would read as an AC-id without the digit it requires.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO. The widened pattern was run outside fences, as the
# merge reads, over every tracked `*qa-validation*.md` and `*code-review*.md` of the reference
# consumer (333 files) and this repo's `docs/reviews/` (47): 0 lines refused -- a floor, since
# neither corpus carries the token at all. So it was also run over every tracked `*.md` of both
# trees (8511 and 291 files opened): 0 consumer lines, and 1 here, `qa.md`'s own backtick-quoted
# `handover-run:` grammar line, which is role prose the merge never reads. The no-colon form
# first matched any one-word line (`handover AC7` and `handover step` alike); it now requires the
# token to carry a digit, as every AC-id in both corpora does, and `Handover step` merges.
# The SECOND widening (any non-alphanumeric run as the separator, a token boundary after the AC-id
# instead of end of line, a `1. ` list prefix) was re-run the same way over the same two corpora,
# the lines the parser consumes first excluded: 0 graph lines of 8511 files opened (control: 3
# unfenced lines naming a hand-over), and the same 1 `qa.md` line here (control: 18). The prose
# near-miss H14 still merges because every prose form's next token carries no digit.
p_q_ho_deco() { # the label decorated, quoted or hyphenated -- each REFUSED as malformed
  local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in '**handover:** AC7' '*handover*: AC7' '`handover: AC7`' '> handover: AC7' 'hand-over: AC7' \
           '**handover-run:** 2 AC7 RED' '`handover-run: 2 AC7 RED`' 'hand-over-run: 2 AC7 RED'; do
    qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 cannot reach GREEN\nparts: 2\n%s\n\nBody.' "$f")"
    q_chk "$1" "$d" 2; chk_refused "$QT_HO_BAD" || return 1
  done
}
p_q_ho_nocolon() { # the label at column 0 with its colon missing -- each REFUSED as malformed
  local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in 'handover - AC7' 'handover AC7' 'handover-run 2 AC7 RED' 'handover-run - 2 AC7 RED'; do
    qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 cannot reach GREEN\nparts: 2\n%s\n\nBody.' "$f")"
    q_chk "$1" "$d" 2; chk_refused "$QT_HO_BAD" || return 1
  done
}
p_q_ho_prose() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '#### Q-2-P the handover step\nparts: 2\n\nThe handover step runs after setup.\nHandover of AC7 is not needed here.\nHandover to the cross shard: none, every replay reached GREEN.\nHandover step\nhand-over is not owed\n\nBody.')"
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && has "$o" "Handover to the cross shard: none"; }
p_q_ho_acid() { # an empty hand-over (parsed as `-`) and `.` -- each joins its run unless refused
  local d o a; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for a in '' '.'; do
    qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H an AC cannot reach GREEN\nparts: 2\nhandover: %s\n\nBody.' "$a")" 1
    qcross "$d" PASS "$(ho_run 2 "2 ${a:--} RED")"
    q_chk "$1" "$d" 2; chk_refused "$QT_HO_ACID" || return 1
  done
}
# THE DECLARED COUNT. Every part shard carries `handovers: <n>`, and the merge refuses a count that
# disagrees with the `handover:` lines it parsed. This is the fail-closed half: four adversary
# rounds each found a spelling the malformed-line pattern missed, and a pattern of bad spellings
# cannot converge, but a hand-over the parser did not read is ALWAYS one short of the declaration.
# H17's forms (a pipe-table row, an HTML comment) are ones the malformed-line pattern does not
# match, so that arm is the one only the count check can refuse; H16's em dash is the brief's own
# example, and under a dropped equality check the malformed-line refusal answers it with ANOTHER
# message, which this arm's token does not accept.
QT_HC_MIS1="declares 'handovers: 1' but the merge parsed 0 'handover:' line(s)"
QT_HC_MIS0="declares 'handovers: 0' but the merge parsed 1 'handover:' line(s)"
QT_HC_MISSING="(part shard 2) carries 0 'handovers:' line(s) outside a fence"
QT_HC_TWO="(part shard 2) carries 2 'handovers:' line(s) outside a fence"
QT_HC_CROSS="carries a 'handovers:' line; only a part shard declares a hand-over count"
ho_find() { printf '### Important\n\n#### Q-2-H AC7 cannot reach GREEN\nparts: 2\n%s\n\nBody.' "$1"; }
p_q_hc_dash() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(ho_find 'handover — AC7')" 1
  q_chk "$1" "$d" 2; chk_refused "$QT_HC_MIS1"; }
p_q_hc_hidden() { # forms the malformed-line pattern does not match, each declared as one hand-over
  local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in '| handover | AC7 |' '<!-- handover: AC7 -->'; do
    qshard "$d" 2 PASS 2 "$(ho_find "$f")" 1
    q_chk "$1" "$d" 2; chk_refused "$QT_HC_MIS1" || return 1
  done
}
p_q_hc_zero() { # a correct, RUN hand-over under `handovers: 0` -- merges PASS unless the count is checked
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 0; qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  q_chk "$1" "$d" 2; chk_refused "$QT_HC_MIS0"; }
p_q_hc_missing() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "" OMIT; ! grep -q '^handovers:' "$d/2.md" || return 1
  q_chk "$1" "$d" 2; chk_refused "$QT_HC_MISSING"; }
p_q_hc_two() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "handovers: 0"
  q_chk "$1" "$d" 2; chk_refused "$QT_HC_TWO"; }
p_q_hc_nonint() { local d o v; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  # 18446744073709551616 is 2^64: bash 3.2 wraps it inside $((10#...)), so only the width guard
  # refuses it (round-5 adversary, measured: without the guard it merged PASS over a hidden hand-over).
  for v in x -1 18446744073709551616; do
    qshard "$d" 2 PASS 2 "" "$v"
    q_chk "$1" "$d" 2; chk_refused "(part shard 2) 'handovers: $v' is not a non-negative integer" || return 1
  done
  # A GLOB VALUE MUST BE REFUSED FROM ANY CWD. Run from a cwd holding files named `0` and `1`, where
  # a word-split read expands `?` and `[1]` into a valid count.
  local g; g="$(mktemp -d "$WORK/hcglob.XXXXXX")" || return 1
  : > "$g/0"; : > "$g/1"
  for v in '?' '[1]'; do
    qshard "$d" 2 PASS 2 "" "$v"
    ( cd "$g" && q_chk "$1" "$d" 2; chk_refused "(part shard 2) 'handovers: $v' is not a non-negative integer" ) || return 1
  done
}
p_q_hc_cross() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross-2 PASS "1, 3" "handovers: 0"
  q_chk "$1" "$d" cross-2; chk_refused "$QT_HC_CROSS"; }
p_q_hc_none() { # the ALLOW twin: every part `handovers: 0`, no hand-over anywhere, merges PASS
  local d o k
  if hand_use "$1" qw1; then d="$(hand_d qw1)"; o="$(hand_o qw1)"   # Q1's all-PASS merge is this state
  else d="$(qworld "$1" PASS PASS PASS PASS)" || return 1; o=""; fi
  for k in 1 2 3; do grep -qx 'handovers: 0' "$d/$k.md" || return 1; done
  for k in cross-1 cross-2 cross-3; do [ -f "$d/$k.md" ] && ! grep -q '^handovers:' "$d/$k.md" || return 1; done
  if [ -z "$o" ]; then o="$(qout "$d")"; q_merge "$1" "$d"; fi
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ "$(check1_value "$o")" = "PASS" ]; }
# THE WIDENED MALFORMED-LINE PATTERN, each form under `handovers: 0` so the count agrees and only
# the malformed-line refusal can refuse it: separators that are not ` - ` (em dash, en dash, `=`,
# `->`), a trailing reason after the AC-id, a numbered-list prefix, and the same for handover-run.
p_q_ho_widen() { local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in 'handover — AC7' 'handover – AC7' 'handover = AC7' 'handover -> AC7' \
           'handover - AC7 because the baseline fails' 'handover AC7 (no GREEN baseline)' \
           '1. handover AC7' '1. **handover:** AC7' 'handover-run — 2 AC7 RED'; do
    qshard "$d" 2 PASS 2 "$(ho_find "$f")" 0
    q_chk "$1" "$d" 2; chk_refused "$QT_HO_BAD" || return 1
  done
}
# ------------------------------------------------------------------- the sharded cross reviewer
# The cross reviewer is one shard per row of `partition-document.sh --cross-groups <K>`. Each arm
# below demands the merge's own refusal message, so a world refused for another reason fails it.
QT_X_MIX="mixes cross.md with cross-<g>.md"
QT_X_OWNER="a finding owned by cross-1 (partition-document.sh --cross-owner)"
QT_X_AC="(cross-2) carries a '## Acceptance Criteria' section; only cross-1, the execution owner"
QT_X_DEF="(cross-3) carries a '## Deferred ACs' section; only cross-1, the execution owner"
QT_X_HORUN="(cross-2) carries a 'handover-run:' line; only cross-1, the execution owner"
QT_X_SEAT="does not end in 'seat-complete: ' while another shard"
QT_X_COUNT="findings=3' but its ## Findings section heads 1 finding(s)"
# <shard-file> <heading-id> <cite>: a second finding, inside ## Findings, under ### Important (inserted
# before ### Suggestions). Under Important, not Critical: every shard it is used on is APPROVED, and an
# APPROVED shard carrying a Critical finding is refused by the merge's VERDICT BACKING (BL-740) at cross-1,
# which the merge checks before cross-3 -- pre-empting the owner-duplicate refusal X5 and OT1 assert.
xfinding() {
  awk -v h="$2" -v c="$3" '/^### Suggestions/ && !d { printf "#### %s an interaction\nparts: %s\n\nBody.\n\n", h, c; d = 1 } { print }' \
    "$1" > "$1.x" && mv "$1.x" "$1" && grep -q "^#### $2 " "$1"
}
nparts() { awk -F'\t' '$1 == "part" { n++ } END { print n + 0 }' "$1/.manifest"; }
p_x_k8() { # X1: K=8 -> eight parts and cross-1..6 merge; the title counts 14 shards; one body header per group
  local sd="$1" d o g SHARD_SHA="$E_SHA"
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  [ "$(nparts "$d")" = 8 ] || return 1
  for g in 1 2 3 4 5 6; do [ -f "$d/cross-$g.md" ] || return 1; done
  [ ! -e "$d/cross-7.md" ] && [ ! -e "$d/cross.md" ] || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"; hand_keep "$sd" xk8 "$o" "$d"
  # The shard COUNT only: the title's gate wording is Q3's.
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qF '(merged from 14 shards)' <<<"$(sed -n 1p "$o")" \
    && has "$o" "## Shard: cross-1 (1,2,3,4)" && has "$o" "## Shard: cross-6 (5,6,7,8)" && has "$o" "#### F-cross-6-1 "
}
p_x_lone() { # X2 (BL-811): ONE cross.md in place of the groups at K>2 is the DISPATCHED shape -> ACCEPTED.
  # x-lone-k8: K=8 (G=6), code-review: merges, titled 9 shards (K + the ONE delivered), the parts in
  #   order then `## Shard: cross` last with no group header, and a 1, 2 finding (cross-1's under the
  #   groups) owned by the lone cross, count +1.
  # x-lone-qa: K=3 (G=3), --gate qa: the lone cross.md carries the per-AC table and merges PASS (it is
  #   the execution owner), and --check-shard over it answers SHARD-OK (what --mark seals on).
  # x-partial: K=8 with cross-6.md removed from the complete set -> REFUSED naming cross-6.
  local sd="$1" d o n0 g pl cl SHARD_SHA="$E_SHA"
  WHY=""
  if cell x-lone-k8; then
    d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || { WHY="x-lone-k8{the K=8 world was not built}"; return 1; }
    [ "$(nparts "$d")" = 8 ] || { WHY="x-lone-k8{the world has $(nparts "$d") parts, not 8}"; return 1; }
    for g in 1 2 3 4 5 6; do rm -f "$d/cross-$g.md"; done
    shard "$d" cross APPROVED "1, 8"; o="$(out_of "$d")"; run_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || { WHY="x-lone-k8{want MERGED got rc=$RC $(head -1 "$MO")}"; return 1; }
    n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"
    pl="$(grep -n '^## Shard: part 8$' "$o" | cut -d: -f1)"; cl="$(grep -n '^## Shard: cross$' "$o" | cut -d: -f1)"
    grep -qF '(merged from 9 shards)' <<<"$(sed -n 1p "$o")" && has "$o" "8 part shards and one cross shard" \
      && [ -n "$pl" ] && [ -n "$cl" ] && [ "$pl" -lt "$cl" ] && ! has "$o" "## Shard: cross-" && has "$o" "#### F-cross-1 " \
      || { WHY="x-lone-k8{title [$(sed -n 1p "$o")], part 8 at ${pl:-none}, cross at ${cl:-none}}"; return 1; }
    rm -f "$o"; xfinding "$d/cross.md" F-own "1, 2" || { WHY="x-lone-k8{the owner seed did not apply}"; return 1; }
    run_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "findings=$((n0 + 1)) " && has "$o" "#### F-own " \
      || { WHY="x-lone-k8{a 1, 2 finding in the lone cross.md: rc=$RC $(head -1 "$MO")}"; return 1; }
  fi
  if cell x-lone-qa; then
    SHARD_SHA="$B_SHA"; d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="x-lone-qa{the qa world was not built}"; return 1; }
    [ -f "$d/cross-3.md" ] || { WHY="x-lone-qa{the seed is not grouped}"; return 1; }
    rm -f "$d"/cross-*.md; qshard "$d" cross PASS "1, 3"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && has "$o" "| AC | Verdict | Evidence |" && [ "$(check1_value "$o")" = PASS ] \
      || { WHY="x-lone-qa{want MERGED PASS got rc=$RC $(head -1 "$MO")}"; return 1; }
    run_check "$sd" "$d" qa "$d/cross.md"
    [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK:" || { WHY="x-lone-qa{--check-shard cross.md rc=$CRC $(head -1 "$CO")}"; return 1; }
  fi
  if cell x-partial; then
    SHARD_SHA="$E_SHA"; d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || { WHY="x-partial{the K=8 world was not built}"; return 1; }
    [ -f "$d/cross-6.md" ] && rm -f "$d/cross-6.md"; run_merge "$sd" "$d"
    refused_clean "shard cross-6 is missing from" "$d" || { WHY="x-partial{want REFUSED naming cross-6 got rc=$RC $(head -1 "$MO")}"; return 1; }
  fi
  [ -z "$WHY" ]
}
p_x_mix() { # X3: cross.md beside cross-1..3 -> REFUSED
  local d
  WHY=""; cell x-mix || return 0
  d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || { WHY="x-mix{the world was not built}"; return 1; }
  shard "$d" cross APPROVED "1, 3"; run_merge "$1" "$d"
  refused_clean "$QT_X_MIX" "$d" || { WHY="x-mix{want REFUSED as a mix got rc=$RC $(head -1 "$MO")}"; return 1; }
}
p_x_unknown() { # X4: cross-4 at K=3 (G=3), and cross-1.md in place of cross.md at K=2 (G=1) -> each REFUSED
  local sd="$1" d SHARD_SHA="$B_SHA"
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross-4 APPROVED "1, 3"; run_merge "$sd" "$d"
  refused_clean "is cross-4, which partition-document.sh --cross-groups 3 does not print" "$d" || return 1
  SHARD_SHA="$F_SHA"; d="$(kworld "$sd" "$REPO_F" "$F_BASE" "$F_SHA" 2 code-review APPROVED)" || return 1
  [ "$(nparts "$d")" = 2 ] && [ -f "$d/cross.md" ] || return 1
  mv "$d/cross.md" "$d/cross-1.md"; run_merge "$sd" "$d"
  refused_clean "is cross-1, which partition-document.sh --cross-groups 2 does not print" "$d"
}
p_x_owner() { # X5: K=8; a finding citing 1, 2 (inside groups 1, 2 and 3; owned by 1) reported by
  # cross-3 AND by its owner cross-1 -> REFUSED, the identical set. A finding citing 1, 2, 7 reported
  # by cross-3 alone (owned by 1, which holds no 7) merges: a cross reviewer reads the whole diff.
  # The ALLOW twin, same run: the 1, 2 finding reported by cross-1 alone merges and the conserved
  # finding count rises by exactly one.
  local sd="$1" d o n0 SHARD_SHA="$E_SHA"
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  grep -q '^parts: 1, 2$' "$d/cross-3.md" && return 1   # the seed must not already carry it
  xfinding "$d/cross-3.md" F-dup "1, 2" || return 1; xfinding "$d/cross-1.md" F-own "1, 2" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"; hand_keep "$sd" x_owner_dup "$o" "$d"; refused_clean "$QT_X_OWNER" "$d" || return 1
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  o="$(out_of "$d")"; hand_use "$sd" xk8 || run_merge "$sd" "$d"; [ "$RC" -eq 0 ] || return 1   # X1 merged this K=8 world
  n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"; rm -f "$o"
  xfinding "$d/cross-3.md" F-tri "1, 2, 7" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "findings=$((n0 + 1)) " && has "$o" "#### F-tri " || return 1
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  o="$(out_of "$d")"; hand_use "$sd" xk8 || run_merge "$sd" "$d"; [ "$RC" -eq 0 ] || return 1   # X1 merged this K=8 world
  n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"; rm -f "$o"
  xfinding "$d/cross-1.md" F-dup "1, 2" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "findings=$((n0 + 1)) " && has "$o" "#### F-dup "
}
p_x_actable() { # X6 (--gate qa): the per-AC table in cross-2, and the deferred record in cross-3 -> each REFUSED
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  qshard "$d" cross-2 PASS "1, 3" "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  q_chk "$sd" "$d" cross-2; chk_refused "$QT_X_AC" || return 1
  qshard "$d" cross-2 PASS "1, 3"
  qshard "$d" cross-3 PASS "2, 3" "$(printf '## Deferred ACs\n\n- AC5: deferred')"
  q_chk "$sd" "$d" cross-3; chk_refused "$QT_X_DEF"
}
p_x_horun() { # X7 (--gate qa): part 2's hand-over replayed by cross-2, not cross-1 -> REFUSED
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1
  qshard "$d" cross-2 PASS "1, 3" "$(ho_run 2 '2 AC7 RED')"
  ! grep -q '^handover-run:' "$d/cross-1.md" || return 1
  q_chk "$sd" "$d" cross-2; chk_refused "$QT_X_HORUN"
}
p_x_k2() { # X8: K=2 -> cross.md, both gates merge; the title counts 3 shards, the body header is `## Shard: cross`
  local sd="$1" d o SHARD_SHA="$F_SHA"
  d="$(kworld "$sd" "$REPO_F" "$F_BASE" "$F_SHA" 2 code-review APPROVED)" || return 1
  [ "$(nparts "$d")" = 2 ] && [ -f "$d/cross.md" ] && [ ! -e "$d/cross-1.md" ] || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qF '(merged from 3 shards)' <<<"$(sed -n 1p "$o")" \
    && has "$o" "## Shard: cross" && ! has "$o" "## Shard: cross-" || return 1
  d="$(kworld "$sd" "$REPO_F" "$F_BASE" "$F_SHA" 2 "$QA_SFX" PASS qa)" || return 1
  o="$(qout "$d")"; q_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$o" "| AC | Verdict | Evidence |"
}
p_x_seat() { # X9: seat-complete -- one shard without the marker beside shards with it, and a shard
  # whose marker is not its last non-blank line -> each REFUSED; every shard ending in it merges,
  # trailing blank lines skipped, and the marker is not in the merged file.
  local sd="$1" d o k
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  for k in 1 2 3 cross-1 cross-2 cross-3; do printf 'seat-complete: implementation code-reviewer %s findings=1\n\n' "$k" >> "$d/$k.md"; done
  shard "$d" 2 APPROVED 2
  o="$(out_of "$d")"; run_merge "$sd" "$d"; refused_clean "$QT_X_SEAT" "$d" || return 1
  printf 'seat-complete: implementation code-reviewer 2 findings=1\n#### F-2-late a finding after the marker\n' >> "$d/2.md"
  run_merge "$sd" "$d"; refused_clean "$QT_X_SEAT" "$d" || return 1
  # All marked, one partial: shard 2 declares findings=3 over the 1 it holds -> REFUSED as truncated.
  shard "$d" 2 APPROVED 2; printf 'seat-complete: implementation code-reviewer 2 findings=3\n' >> "$d/2.md"
  run_merge "$sd" "$d"; refused_clean "$QT_X_COUNT" "$d" || return 1
  shard "$d" 2 APPROVED 2; printf 'seat-complete: implementation code-reviewer 2 findings=1\n' >> "$d/2.md"
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && ! has "$o" "seat-complete:"
}
# X10 (BL-763): every owner-duplicate refusal in one run. K=3 world (groups 1:(1,2) 2:(1,3) 3:(2,3), each
# default cross shard citing its own group's set). Seven cases on one world, each reset from a clean copy;
# each row that answers wrongly writes its own WHY token, so M21 (only the first duplicate printed) and
# M22 (the --check-shard barrier dropped) are each scored on the one row they move.
xcrit() { # <shard-file>: a '#### ' finding under '### Critical' citing the shard's own set -- refused under APPROVED
  awk '/^### Critical/ && !d { print; printf "\n#### F-crit a critical interaction\nparts: 1, 3\n\nBody.\n"; d = 1; next } { print }' \
    "$1" > "$1.x" && mv "$1.x" "$1" && grep -q '^#### F-crit ' "$1"
}
xd_tails() { grep '^REFUSED:' "$MO" | sed -n 's/.*\[owner: \([^]]*\)\]$/\1/p' | tr '\n' ' '; }
xd_first() { local l; l="$(grep -m1 '^REFUSED:' "$MO")"; if grep -q 'identical set' <<<"$l"; then echo dup; else echo other; fi; }
xd_w() { if [ -e "$1" ]; then echo y; else echo n; fi; }
xd_row() { # <token> <want> <got>
  [ "$2" = "$3" ] || WHY="$WHY $1{want '$2' got '$3'}"
}
xd_zero_sha() { sed 's/^reviewed-sha: .*/reviewed-sha: 0000000000000000000000000000000000000000/' "$1" > "$1.x" && mv "$1.x" "$1"; }
p_x_dupall() {
  local sd="$1" d c o SHARD_SHA="$B_SHA"
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the K=3 world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || { WHY="the clean copy was not made"; return 1; }
  o="$(out_of "$d")"
  # two duplicates in two seats: cross-2 cites 1, 2 (owned by cross-1) and cross-3 cites 1, 3 (owned by cross-2)
  if cell two; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" && xfinding "$d/cross-3.md" F-dupB "1, 3" || { WHY="two: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row two "rc=2 n=2 tails=cross-2 cross-3  written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  if cell one; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" || { WHY="one: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row one "rc=2 n=1 tails=cross-2  written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # near-miss: cross-1 cites its own set 1, 2 a second time -> merges
  if cell near; then
    xfinding "$d/cross-1.md" F-ownB "1, 2" || { WHY="near: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row near "rc=0 merged=y" "rc=$RC merged=$(has "$MO" "MERGED:" && echo y || echo n)"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # --check-shard over the duplicating seat, its owner sealed: the exit code is what --mark seals on
  if cell check; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" || { WHY="check: the seed did not apply"; return 1; }
    lmark "$d/cross-1.md" - cross-1 key=cross-1
    run_check "$sd" "$d" code-review "$d/cross-2.md"
    xd_row check "rc=2 n=1 ok=n" "rc=$CRC n=$(nref "$CO") ok=$(has "$CO" "SHARD-OK" && echo y || echo n)"
    cs_reset "$d" "$c"
  fi
  # precedence (a): the duplicate in cross-2, then a per-shard structural refusal in cross-3
  if cell preca; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" || { WHY="preca: the seed did not apply"; return 1; }
    xd_zero_sha "$d/cross-3.md"
    run_merge "$sd" "$d"; xd_row preca "rc=2 n=2 tails=cross-2 cross-3  first=dup written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) first=$(xd_first) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # precedence (b): the structural refusal in cross-1, the duplicate after it in cross-3 -> the first alone
  if cell precb; then
    xd_zero_sha "$d/cross-1.md"
    xfinding "$d/cross-3.md" F-dupB "1, 3" || { WHY="precb: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row precb "rc=2 n=1 tails=cross-1  written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # one shard, two lines: cross-2's duplicate, then cross-2's own later verdict-backing refusal
  if cell same; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" && xcrit "$d/cross-2.md" || { WHY="same: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row same "rc=2 n=2 tails=cross-2 cross-2  first=dup written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) first=$(xd_first) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  [ -z "$WHY" ]
}
X_ALL="x_k8 x_lone x_mix x_unknown x_owner x_actable x_horun x_k2 x_seat x_dupall"
# ------------------------------------------------------- gate-1 hand-overs (--gate code-review)
# A code-review part shard replays its own part's mutation-REDs and hands over only what its own
# worktree cannot bring to GREEN; the execution owner (cross-1) runs the hand-overs. The grammar
# and the join are the QA ones, read under both gates. Seeded as code-reviewer.md tells each
# writer to emit them: the hand-over under `### Important` in a part shard, the replays inside
# cross-1's `## Findings`, the part's `handovers: <n>` beside `reviewed-sha:`.
# crs <dir> <key> <verdict> <cite> <handovers count | OMIT | -> [text inside ### Important]
crs() {
  local d="$1" k="$2" v="$3" cite="$4" hc="$5" body="${6:-}"
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$hc" in OMIT|-) ;; *) printf 'handovers: %s\n' "$hc" ;; esac
    printf '\n## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n' "$k" "$k"
    # The finding's container follows the verdict, as shard()'s does (BL-740).
    printf '## Findings\n\n### Critical (must fix before merge)\n\n'
    [ "$v" = APPROVED ] || shard_find "$k" "$cite"
    printf '### Important (should fix, can be follow-up)\n\n'
    [ "$v" != APPROVED ] || shard_find "$k" "$cite"
    printf '%s\n\n### Suggestions (optional improvements)\n' "$body"
  } > "$d/$k.md"
}
crho() { printf '#### F-%s-H %s replay cannot reach a GREEN baseline in the part worktree\nparts: %s\nhandover: %s\n\nThe documented setup fails in a fresh worktree.' "$1" "$2" "$1" "$2"; }
crrun() { printf '#### F-cross-H hand-over replays\nparts: %s\n' "$1"; shift; for _r in "$@"; do printf 'handover-run: %s\n' "$_r"; done; printf '\nRan in the frozen worktree after setup.'; }
QT_HO_RUN2="hand-over '2 AC7' has more than one 'handover-run:' line in cross-1.md"
p_cr_ho_ok() { # G1: parts 1 and 2 each hand over a DISJOINT replay; cross-1 runs both exactly once
  # -> merges APPROVED with both tabled; the same world with AC7 GREEN-SURVIVED merges NEEDS_REWORK.
  local sd="$1" d o r
  for r in RED GREEN-SURVIVED; do
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    crs "$d" 1 APPROVED 1 1 "$(crho 1 AC3)"; crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"
    crs "$d" cross-1 APPROVED "1, 2" - "$(crrun '1, 2' '1 AC3 RED' "2 AC7 $r")"
    o="$(out_of "$d")"; run_merge "$sd" "$d"
    if [ "$r" = RED ]; then
      [ "$RC" -eq 0 ] && has "$MO" "verdict=APPROVED " && [ "$(check1_value "$o")" = APPROVED ] \
        && has "$o" "| 1 | AC3 | RED |" && has "$o" "| 2 | AC7 | RED |" || return 1
    else
      [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK " && [ "$(check1_value "$o")" = NEEDS_REWORK ] || return 1
    fi
  done
}
p_cr_ho_block() { # G2: every shard BLOCKED (every wrong rule agrees), an unmet replay -> stays BLOCKED
  local sd="$1" d o
  d="$(world4 "$sd" BLOCKED BLOCKED BLOCKED BLOCKED)" || return 1
  crs "$d" 2 BLOCKED 2 1 "$(crho 2 AC7)"
  crs "$d" cross-1 BLOCKED "1, 2" - "$(crrun 2 '2 AC7 NO-BASELINE')"
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=BLOCKED " && [ "$(check1_value "$o")" = BLOCKED ]
}
p_cr_ho_unm() { # G3: part 2's hand-over run by no shard -> REFUSED, nothing written
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"; run_merge "$1" "$d"; hand_keep "$1" own_cr_ho_unm "$(out_of "$d")" "$d"; refused_clean "$QT_HO_UNM" "$d"; }
p_cr_ho_runtwice() { # G4: one hand-over replayed twice by cross-1, in two findings -> REFUSED
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"
  crs "$d" cross-1 APPROVED "1, 2" - "$(printf '%s\n\n%s' "$(crrun 2 '2 AC7 RED')" "$(crrun 2 '2 AC7 RED' | sed 's/F-cross-H/F-cross-H2/')")"
  [ "$(grep -c '^handover-run: 2 AC7 RED$' "$d/cross-1.md")" = 2 ] || return 1
  run_merge "$1" "$d"; hand_keep "$1" own_cr_ho_runtwice "$(out_of "$d")" "$d"; refused_clean "$QT_HO_RUN2" "$d"; }
p_cr_hc_missing() { # G5: a code-review part shard without its declared count -> REFUSED
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  crs "$d" 2 APPROVED 2 OMIT; ! grep -q '^handovers:' "$d/2.md" || return 1
  run_check "$1" "$d" code-review "$d/2.md"; chk_refused "$QT_HC_MISSING"; }
C_ALL="cr_ho_ok cr_ho_block cr_ho_unm cr_ho_runtwice cr_hc_missing"
Q_ALL="q_worst q_table q_title q_fenced q_part_ac q_part_def q_cross_noac q_cross_twoac q_cross_twodef q_nodef q_rank q_pm q_suffix q_gate q_vset q_secvar q_ho_ok q_ho_unm q_ho_orph q_ho_force q_ho_cross q_ho_prun q_ho_fenced q_ho_shape q_ho_multi q_ho_twoline q_ho_dup q_ho_deco q_ho_nocolon q_ho_prose q_ho_acid q_hc_dash q_hc_hidden q_hc_zero q_hc_missing q_hc_two q_hc_nonint q_hc_cross q_hc_none q_ho_widen"

# ===================================================================== BL-737: the shard pre-check,
# owner tails, the marker key, the content seal on review shards, and the legacy rule. Every predicate
# below sets WHY to what it saw when it fails; each takes the SCRIPT DIRECTORY so a mutant copy drives it.
#
# THE ROWS ARE THE RECORDER'S. fire() hands the SHIPPED PostToolUse hook a payload exactly as the harness
# would -- `agent_id` present for a dispatched seat, absent for the top-level session -- with
# CLAUDE_PROJECT_DIR the main checkout, and fails unless the hook APPENDED a row: a silent hook must never
# let a "no row" refusal pass for the wrong reason.
fire() { # <file> <agent|session> [tool] [project root] -> 0 when the recorder appended a row
  local f="$1" who="$2" tool="${3:-Write}" root="${4:-$MAIN}" l n0 n1 pl
  l="$root/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  n0="$(grep -c . "$l" 2>/dev/null)" || n0=0
  pl="$(jq -nc --arg t "$tool" --arg fp "$f" --arg who "$who" \
    '{tool_name: $t, tool_input: {file_path: $fp}, session_id: "fixture-session", tool_use_id: "toolu_fixture",
      transcript_path: "/dev/null"} + (if $who == "agent" then {agent_id: "a0123456789abcdef", agent_type: "code-reviewer"} else {} end)')" \
    || return 1
  ip_run -e "CLAUDE_PROJECT_DIR=$root" "$HOOK" - <<<"$pl" > /dev/null 2>&1
  n1="$(grep -c . "$l" 2>/dev/null)" || n1=0
  [ "$n1" -gt "$n0" ]
}
# The pre-key= --mark's marker, typed the way the old engine wrote it: `sha=` the body's hash (so
# seal_of reads it sealed), `findings=` the shard's '#### ' count unless given. <n> is `-` for that count.
lmark() { # <file> <n|-> <field words...>
  local f="$1" n="$2" h; shift 2
  h="$(shasum -a 256 < "$f" | cut -d' ' -f1)"
  [ "$n" != - ] || { n="$(grep -c '^#### ' "$f")" || n=0; }
  printf 'seat-complete: implementation code-reviewer %s sha=%s findings=%s\n' "$*" "$h" "$n" >> "$f"
}
lmark_all() { local f; for f in "$1"/*.md; do lmark "$f" - "$(basename "$f" .md)"; done; }
mark_args() { # <script-dir> <args to --mark...> -> MRC, $MKO
  local sd="$1"; shift
  ip_run -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/wait-for-deliverable.sh" wfd_mark_main --mark "$@" > "$MKO" 2>&1 < /dev/null; MRC=$?
}
seal_mark() { # <script-dir> <file> <seat>: the seat's own close, `<shard>` the file's key
  local k n; k="$(basename "$2" .md)"; n="$(grep -c '^#### ' "$2")" || n=0
  mark_args "$1" "$2" implementation "$3" "$k" "findings=$n"
}
# seal_world <script-dir> <code-review|qa> -> a shard dir whose every shard its seat wrote (one recorder
# row each) and closed with the real --mark. Run under WROOT to build it in another tree.
seal_world() {
  local sd="$1" g="$2" d f seat=code-reviewer tk="" t w0 w1 n0 n1
  # BUILT ONCE, COPIED AFTER (MAIN only, and only when every script the build reaches is SRCDIR's): the first
  # build fires the recorder and runs the real --mark per shard, and records the world directory and the ledger
  # rows it appended; a later build copies the directory into a fresh `wdir` and appends those rows with the
  # world's path prefix rewritten to the copy's. SW0 (seed_controls) holds the copy to a fresh build.
  [ -n "${WROOT:-}" ] || [ -z "${RSM_TPL:-}" ] \
    || ! tpl_ok "$sd" merge-review-shards.sh wait-for-deliverable.sh content-seal.sh $WORLD_SCRIPTS \
    || tk="$(tpl_key sw "$g")"
  if tpl_has "$tk"; then
    t="$RSM_TPL/$tk"; w1="$(wdir)" || return 1
    cp -R "$t/w/." "$w1/" || return 1
    w0="$(cat "$t/prefix")"; w1="${w1#"$MAIN"/}"; w1="${w1%/shards}"
    sed "s|\"path\":\"$w0/|\"path\":\"$w1/|" "$t/rows" >> "$LEDGER" || return 1
    tpl_hit "$tk"; printf '%s/%s' "$MAIN/$w1/shards" "$(cat "$t/name")"; return 0
  fi
  if [ "$g" = qa ]; then d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1; seat=qa
  else d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1; fi
  n0="$(grep -c . "$LEDGER" 2>/dev/null)" || n0=0
  for f in "$d"/*.md; do
    fire "$f" agent || { echo "the recorder wrote no row for $f" > "$MKO"; return 1; }
    seal_mark "$sd" "$f" "$seat"; [ "$MRC" -eq 0 ] || return 1
  done
  if [ -n "$tk" ] && [ ! -d "$RSM_TPL/$tk" ]; then
    t="$RSM_TPL/$tk.part"; n1="$(grep -c . "$LEDGER")" || n1=0
    w0="$(dirname "$(dirname "$d")")"; w0="${w0#"$MAIN"/}"
    mkdir -p "$t/w" && cp -R "$(dirname "$d")/." "$t/w/" && tail -n "$((n1 - n0))" "$LEDGER" > "$t/rows" \
      && printf '%s' "$w0" > "$t/prefix" && basename "$d" > "$t/name" && mv "$t" "$RSM_TPL/$tk" || return 1
    tpl_build sw
  fi
  printf '%s' "$d"
}
alias_of() { printf '%s' "$ALIAS${1#"$MAIN/docs"}"; }
reline() { grep '^REFUSED:' "$1"; }
nref() { local n; n="$(grep -c '^REFUSED:' "$1")" || n=0; printf '%s' "$n"; }
owner_in() { # <output file> <want>: exactly one REFUSED line, ending in [owner: <want>]
  local l; [ "$(nref "$1")" = 1 ] || return 1; l="$(reline "$1")"
  case "$l" in *" [owner: $2]") return 0 ;; esac; return 1
}
# chk_refused <token> [second token]: the last run_check REFUSED once (exit 2, one REFUSED line, no SHARD-OK) naming the
# token. A (B) arm asks one shard's gate and drives it here, through the function the merge itself calls (check_shard);
# the wiring of --check-shard to the merge is CS1's byte-equality over CS_CR/CS_QA, and each family keeps one end-to-end
# merge (named in a comment at the arm).
chk_refused() {
  [ "$CRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && ! has "$CO" "SHARD-OK:" && has "$CO" "$1" && { [ -z "${2:-}" ] || has "$CO" "$2"; }
}
q_chk() { run_check "$1" "$2" qa "$2/$3.md"; } # <script-dir> <dir> <target key>
run_check() { # <script-dir> <shard-dir> <gate> <target> [--findings n] -> CRC, $CO; driven through the alias
  local sd="$1" d="$2" g="$3" t="$4"; shift 4
  ip_run -e "AI_DLC_PROJECT_ROOT=${VB_PROJ:-$PROJ}" "$sd/merge-review-shards.sh" mrs_main "$(alias_of "$d")" --gate "$g" \
    --check-shard "$(alias_of "$t")" "$@" > "$CO" 2>&1 < /dev/null; CRC=$?
}
cs_reset() { rm -f "$1"/*.md "$1/notes.txt"; cp "$2"/*.md "$1"/; }

# ---- CS1: --check-shard IS the merge's per-shard code. One defect per world, in a shard that is not
# the first read; the full merge and --check-shard each print exactly one REFUSED line, and they are
# byte-equal. The check is driven through ALIAS, so the shared line naming the PHYSICAL path is the
# resolution's proof. Each csc_* seeds one class into $CSD and names its target in CS_T.
csc_two_sha() { CS_T=2; shard "$CSD" 2 APPROVED 2 "" "reviewed-sha: $B_BASE"; }
csc_sha_rev() { CS_T=2; shard "$CSD" 2 APPROVED 2 "$B_BASE"; }
csc_bad_verdict() { CS_T=2; shard "$CSD" 2 PASS 2; }
csc_nofind() { CS_T=2; raw_shard "$CSD" 2 '## Summary' 'Nothing to report.'; }
csc_stray() { CS_T=2; raw_shard "$CSD" 2 '## Findings' '' '### Critical (must fix before merge)' '' '- **C-1** an issue' '  parts: 2'; }
csc_partcite() { CS_T=2; shard "$CSD" 2 APPROVED 3; }
csc_crossone() { CS_T=cross-2; shard "$CSD" cross-2 APPROVED 2; }
csc_noparts() { CS_T=2; raw_shard "$CSD" 2 '## Findings' '' '### Critical (must fix before merge)' '' \
  '#### F-2-1 cited' 'parts: 2' '' '#### F-2-2 uncited' '' 'Body.'; }
csc_outrange() { CS_T=cross-2; shard "$CSD" cross-2 APPROVED "1, 9"; }
csc_hc_missing() { CS_T=2; crs "$CSD" 2 APPROVED 2 OMIT; }
csc_hc_nonint() { CS_T=2; crs "$CSD" 2 APPROVED 2 x; }
csc_hc_mismatch() { CS_T=2; crs "$CSD" 2 APPROVED 2 1; }
csc_hc_cross() { CS_T=cross-2; shard "$CSD" cross-2 APPROVED "1, 3" "handovers: 0"; }
csc_malformed() { CS_T=2; crs "$CSD" 2 APPROVED 2 0 "$(printf '#### F-2-H AC7 cannot reach GREEN\nparts: 2\n**handover:** AC7\n\nBody.')"; }
csc_ho_cross() { CS_T=cross-1; crs "$CSD" cross-1 APPROVED "1, 2" - "$(printf '#### F-c-H AC8 cannot be replayed\nparts: 1, 3\nhandover: AC8\n\nBody.')"; }
csc_ho_multi() { CS_T=2; crs "$CSD" 2 APPROVED 2 1 "$(printf '#### F-2-H AC7 and AC8\nparts: 2\nhandover: AC7 AC8\n\nBody.')"; }
csc_hr_part() { CS_T=3; crs "$CSD" 3 APPROVED 3 0 "$(printf '#### F-3-H ran AC7\nparts: 3\nhandover-run: 3 AC7 RED\n\nBody.')"; }
csc_hr_cross2() { CS_T=cross-2; crs "$CSD" cross-2 APPROVED "1, 3" - "$(crrun 2 '2 AC7 RED')"; }
# The marker classes: every other shard carries a legacy marker the old engine at B's frozen sha
# accepts, so the full merge prints LEGACY lines before it reaches the target; only REFUSED lines compare.
csc_mk_count() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" 3 2; }
csc_mk_key() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" - 2 key=3; }
csc_mk_field() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" - 1/3 key=2; }
csc_mk_twokey() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" - 2 key=2 key=2; }
# The content seal: a seat's Write (a recorder row), then a Bash rewrite.
csc_seal() { fire "$CSD/2.md" agent || return 1
  sed -i.bak -e 's/^## Summary$/## Overview/' "$CSD/2.md" && rm -f "$CSD/2.md.bak" && grep -q '^## Overview$' "$CSD/2.md" || return 1
  CS_T=2; CS_TOK="changed after its last sealed write"; }
# --gate qa. The second instance's own seed: a part seat's `## Deferred live check (not scored here)`.
csq_part_ac() { CS_T=2; qshard "$CSD" 2 PASS 2 "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC1 | PASS |')"; }
csq_graph_deferred() { CS_T=2; CS_TOK="(part shard 2) carries a '## Deferred ACs' section"
  qshard "$CSD" 2 PASS 2 "$(printf '## Deferred live check (not scored here)\n\nThe live check runs at deploy.')"; }
csq_cross_noac() { CS_T=cross-1; awk '/^## Acceptance Criteria$/ { print "## Per-AC results"; next } { print }' "$CSD/cross-1.md" > "$CSD/x.tmp" \
  && mv "$CSD/x.tmp" "$CSD/cross-1.md"; }
csq_cross_twodef() { CS_T=cross-1; qshard "$CSD" cross-1 PASS "1, 2" "$(printf '\n## Deferred ACs\n\n- AC5: deferred')"; }
csq_cross2_ac() { CS_T=cross-2; qshard "$CSD" cross-2 PASS "1, 3" "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"; }
csq_rank() { CS_T=2; qshard "$CSD" 2 APPROVED 2; }
# BL-790: a shard with no advisor: line, over REPO_B (no role file at the frozen sha, so held).
csc_adv_absent() { CS_T=2; CS_TOK="carries no column-0 'advisor:' line"; SHARD_ADV="" shard "$CSD" 2 APPROVED 2; }
csq_adv_absent() { CS_T=2; CS_TOK="carries no column-0 'advisor:' line"; SHARD_ADV="" qshard "$CSD" 2 PASS 2; }
CS_CR="two_sha sha_rev bad_verdict nofind stray partcite crossone noparts outrange hc_missing hc_nonint hc_mismatch hc_cross malformed ho_cross ho_multi hr_part hr_cross2 mk_count mk_key mk_field mk_twokey seal adv_absent"
CS_QA="part_ac graph_deferred cross_noac cross_twodef cross2_ac rank adv_absent"
CS_N="$(printf '%s\n' $CS_CR $CS_QA | grep -c .)"
cs_same() { # <script-dir> <shard-dir> <gate> <target>
  local sd="$1" d="$2" g="$3" t="$4" o
  if [ "$g" = qa ]; then o="$(qout "$d")"; else o="$(out_of "$d")"; fi
  run_mg "$sd" "$d" "$g" "$o"
  run_check "$sd" "$d" "$g" "$t"
  CS_LAST="merge rc=$RC [$(reline "$MO")] check rc=$CRC [$(reline "$CO")]"
  [ "$RC" -eq 2 ] && [ "$CRC" -eq 2 ] && [ "$(nref "$MO")" = 1 ] && [ "$(nref "$CO")" = 1 ] \
    && [ "$(reline "$MO")" = "$(reline "$CO")" ] && ! has "$CO" "SHARD-OK:" && [ ! -e "$o" ] && has "$CO" "$t" \
    && { [ -z "$CS_TOK" ] || has "$CO" "$CS_TOK"; }
}
cs_run() { # <script-dir> <gate> <seeder> <clean copy>
  # A seeder's exit is not its verdict (the shard writers end in a conditional printf); CS_T is: every
  # seeder names its target only once its seed is written, and the seal seeder only once it applied.
  CS_T=""; CS_TOK=""
  "$3"
  if [ -n "$CS_T" ] && [ -f "$CSD/$CS_T.md" ]; then
    cs_same "$1" "$CSD" "$2" "$CSD/$CS_T.md" || WHY="$WHY ${3}{$CS_LAST}"
    hand_keep "$1" "cs_$3" "$(if [ "$2" = qa ]; then qout "$CSD"; else out_of "$CSD"; fi)" "$CSD"
  else WHY="$WHY ${3}{the seed did not apply}"; fi
  cs_reset "$CSD" "$4"
}
# CS_LIST (run.sh --matrix only): every cell gate answers "selected" so each group's setup runs, and
# every `cell` appends its name to the file CS_LIST names and runs nothing -- the predicate's cell list.
cs_sel() { [ -n "${CS_LIST:-}" ] || [ -z "${CS_ONLY:-}" ] || [ "$1" = "$CS_ONLY" ]; }
# cell <name>: 0 when this cell runs (no CS_ONLY, or CS_ONLY names it), counting it in CS_RAN. Every
# predicate a mutant drives gates each of its cells on it (BL-755), so a mutant runs the one cell its
# kill token names and nothing else; run.sh's mut_run asserts exactly one cell ran.
cell() {
  if [ -n "${CS_LIST:-}" ]; then printf '%s\n' "$1" >> "$CS_LIST"; return 1; fi
  cs_sel "$1" || return 1; CS_RAN=$(( ${CS_RAN:-0} + 1 ))
}
p_cs() {
  local sd="$1" c n any=0
  WHY=""
  CSD="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the code-review world was not built"; return 1; }
  c="$(dirname "$CSD")/clean"; mkdir "$c" && cp "$CSD"/*.md "$c"/ || return 1
  run_check "$sd" "$CSD" code-review "$CSD/1.md"
  [ "$CRC" -eq 0 ] && [ "$(cat "$CO")" = "SHARD-OK: $CSD/1.md findings=1" ] \
    || { WHY="control: a clean shard answered rc=$CRC [$(head -1 "$CO")]"; return 1; }
  for n in $CS_CR; do cell "$n" || continue; any=1; cs_run "$sd" code-review "csc_$n" "$c"; done
  for n in $CS_QA; do cell "$n" || continue; any=1
    if [ -z "${CS_QD:-}" ]; then
      CSD="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
      CS_QD=1; c="$(dirname "$CSD")/clean"; mkdir "$c" && cp "$CSD"/*.md "$c"/ || return 1
    fi
    cs_run "$sd" qa "csq_$n" "$c"
  done
  CS_QD=""
  [ "$any" = 1 ] && [ -z "$WHY" ]
}

# ---- CP1: the seal reader the merge copies (it cannot source wait-for-deliverable.sh, which executes on
# load) is byte-identical to wait-for-deliverable.sh's, each function extracted by NAME from both.
fn_body() { awk -v n="$2" 'index($0, n "() {") == 1 { p = 1 } p { print } p && /^}$/ { exit }' "$1"; }
p_copies() {
  local m="$1/merge-review-shards.sh" w="$1/wait-for-deliverable.sh" fn a nl drift="$WORK/drift-merge.sh"
  WHY=""
  for fn in has_marker content_hash seal_body seal_of; do
    a="$(fn_body "$m" "$fn")"; nl="$(printf '%s\n' "$a" | grep -c .)" || nl=0
    [ "$nl" -ge 3 ] && [ "$a" = "$(fn_body "$w" "$fn")" ] || WHY="$WHY $fn($nl lines, differs)"
  done
  [ "$(grep -cxF 'MARK_TOKEN="seat-complete: "' "$m")" = 1 ] && [ "$(grep -cxF 'MARK_TOKEN="seat-complete: "' "$w")" = 1 ] \
    || WHY="$WHY MARK_TOKEN"
  # The control: one byte drifted inside the merge's seal_body is seen by the same extraction.
  sed -e 's/k == 1/k == 2/' "$m" > "$drift"
  if cmp -s "$m" "$drift"; then WHY="$WHY control(the drift did not apply)"
  elif [ "$(fn_body "$drift" seal_body)" = "$(fn_body "$w" seal_body)" ]; then WHY="$WHY control(a one-byte drift was not seen)"; fi
  # content-seal.sh's seal_review_body hashes the bytes --mark's seal_body binds: its BODY (the lines
  # after the name line, so the two names may differ) is byte-identical, with the same one-byte control.
  local c="$1/content-seal.sh" cdrift="$WORK/drift-seal.sh" cb
  cb="$(fn_body "$c" seal_review_body | sed 1d)"; nl="$(printf '%s\n' "$cb" | grep -c .)" || nl=0
  [ "$nl" -ge 2 ] && [ "$cb" = "$(fn_body "$w" seal_body | sed 1d)" ] || WHY="$WHY seal_review_body($nl lines, differs from seal_body)"
  sed -e 's/k == 1/k == 2/' "$c" > "$cdrift"
  if cmp -s "$c" "$cdrift"; then WHY="$WHY control-seal(the drift did not apply)"
  elif [ "$(fn_body "$cdrift" seal_review_body | sed 1d)" = "$(fn_body "$w" seal_body | sed 1d)" ]; then WHY="$WHY control-seal(a one-byte drift was not seen)"; fi
  [ -z "$WHY" ]
}

# ---- OT1: the owner tail of every refusal family names the shard whose FILE must change.
own_case() { owner_in "${3:-$MO}" "$2" || WHY="$WHY $1{want [owner: $2], got $(reline "${3:-$MO}")}"; }
p_owner() {
  local sd="$1" d c o SHARD_SHA
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  # per-shard, missing, dup-key, handover-unrun, run-twice, check1-multi, set-level and dup-merge each ask the owner tail of
  # a refusal an earlier top-level arm already drew from the identical state (CS1's partcite world, R1, R3, G3, G4, R9, Q12
  # and X5); they read that arm's saved output. bad-name has no earlier arm and keeps its own merge.
  if cell per-shard; then hand_use "$sd" cs_csc_partcite || { shard "$d" 2 APPROVED 3; run_merge "$sd" "$d"; }; own_case per-shard 2; cs_reset "$d" "$c"; fi
  if cell missing; then hand_use "$sd" own_miss || { rm -f "$d/2.md"; run_merge "$sd" "$d"; }; own_case missing 2; cs_reset "$d" "$c"; fi
  if cell unfinished; then lmark_all "$d"; shard "$d" 2 APPROVED 2; run_merge "$sd" "$d"; own_case unfinished 2; cs_reset "$d" "$c"; fi
  if cell dup-key; then cp "$d/1.md" "$d/01.md"; hand_use "$sd" own_dup || run_merge "$sd" "$d"; own_case dup-key "01.md 1.md"; cs_reset "$d" "$c"; fi
  if cell handover-unrun; then crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"; hand_use "$sd" own_cr_ho_unm || run_merge "$sd" "$d"; own_case handover-unrun "2 cross-1"; cs_reset "$d" "$c"; fi
  if cell run-orphan; then crs "$d" cross-1 APPROVED "1, 2" - "$(crrun 2 '2 AC7 RED')"; run_merge "$sd" "$d"; own_case run-orphan "2 cross-1"; cs_reset "$d" "$c"; fi
  if cell handover-twice; then
    crs "$d" 2 APPROVED 2 2 "$(printf '%s\n\n%s' "$(crho 2 AC7)" "$(crho 2 AC7 | sed 's/F-2-H/F-2-H2/')")"
    crs "$d" cross-1 APPROVED "1, 2" - "$(crrun 2 '2 AC7 RED')"; run_merge "$sd" "$d"; own_case handover-twice 2; cs_reset "$d" "$c"
  fi
  if cell run-twice; then
    crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"
    crs "$d" cross-1 APPROVED "1, 2" - "$(printf '%s\n\n%s' "$(crrun 2 '2 AC7 RED')" "$(crrun 2 '2 AC7 RED' | sed 's/F-cross-H/F-cross-H2/')")"
    hand_use "$sd" own_cr_ho_runtwice || run_merge "$sd" "$d"; own_case run-twice cross-1; cs_reset "$d" "$c"
  fi
  if cell check1-multi; then shard "$d" 2 APPROVED 2 "" "$(printf '## Verdict\nAPPROVED')"; hand_use "$sd" own_a3 || run_merge "$sd" "$d"; own_case check1-multi 2; cs_reset "$d" "$c"; fi
  if cell bad-name; then printf 'x\n' > "$d/notes.txt"; run_merge "$sd" "$d"; own_case bad-name lead; cs_reset "$d" "$c"; fi
  if cell set-level; then o="$(qout "$d" code-review -p2)"; hand_use "$sd" own_qpm_set || run_mg "$sd" "$d" code-review "$o"; own_case set-level lead; fi
  # The owner duplicate, K=8: cross-3 and its owner cross-1 report the identical set -> the NON-owner.
  # Under --check-shard the owner is read only once it is finished and sealed: unmarked, cross-3 passes.
  # The two --check-shard cells read the state the cell before them left, so selecting one runs its
  # prerequisite steps without counting them as cells.
  if cs_sel dup-merge || cs_sel dup-check-owner-unsealed || cs_sel dup-check-owner-sealed; then
    SHARD_SHA="$E_SHA"
    d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || { WHY="$WHY the K=8 world was not built"; return 1; }
    xfinding "$d/cross-3.md" F-dup "1, 2" && xfinding "$d/cross-1.md" F-own "1, 2" || return 1
    if cell dup-merge; then hand_use "$sd" x_owner_dup || run_merge "$sd" "$d"; own_case dup-merge cross-3; fi
    if cell dup-check-owner-unsealed; then
      run_check "$sd" "$d" code-review "$d/cross-3.md"
      [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $d/cross-3.md" || WHY="$WHY dup-check-owner-unsealed{rc=$CRC $(head -1 "$CO")}"
    fi
    if cell dup-check-owner-sealed; then
      lmark "$d/cross-1.md" - cross-1 key=cross-1
      run_check "$sd" "$d" code-review "$d/cross-3.md"; own_case dup-check-owner-sealed cross-3 "$CO"
    fi
  fi
  [ -z "$WHY" ]
}

# ---- KY1: the marker's key=. A set every seat wrote and --mark closed merges, each marker keyed by its
# own file name; the same set with one marker's key= (then its <shard> field) naming another key refuses.
p_key() {
  local sd="$1" d f k o
  WHY=""
  d="$(seal_world "$sd" code-review)" || { WHY="the sealed world was not built: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY:" || { WHY="the seat-sealed set did not merge: $(head -2 "$MO")"; return 1; }
  hand_keep "$sd" key_ctl "$o" "$d"
  for f in "$d"/*.md; do k="$(basename "$f" .md)"
    grep -qE "^seat-complete: implementation code-reviewer $k key=$k sha=[0-9a-f]{64} findings=1\$" "$f" \
      || { WHY="$f does not end in a marker keyed $k: $(tail -1 "$f")"; return 1; }
  done
  rm -f "$o"
  awk '{ sub(/ 2 key=2 sha=/, " 2 key=3 sha=") } { print }' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$sd" "$d"
  refused_clean "carries key=3, not this shard's key 2" "$d" && owner_in "$MO" 2 || WHY="$WHY key=3{$(head -1 "$MO")}"
  awk '{ sub(/ code-reviewer 2 key=3 /, " code-reviewer 1/3 key=2 ") } { print }' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$sd" "$d"
  refused_clean "names shard '1/3', not this shard's key 2" "$d" && owner_in "$MO" 2 || WHY="$WHY field-1/3{$(head -1 "$MO")}"
  [ -z "$WHY" ]
}

# ---- MK1: --mark on a review shard refuses a <shard> that is not the file's key, a caller key= or
# sha= word, and a findings count the merge's check refuses -- each exit 64, the file byte-unchanged --
# and the ALLOW twin, same file, same row, marks it keyed by its own name.
mark_refused() { [ "$MRC" -eq 64 ] && has "$MKO" "$1" && has "$MKO" "Nothing was written." && cmp -s "$2" "$3"; }
p_mark() {
  local sd="$1" d f s
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  fire "$f" agent || { WHY="the recorder wrote no row for $f"; return 1; }
  cp "$f" "$s" || return 1
  if cell shard-3; then mark_args "$sd" "$f" implementation code-reviewer 3 findings=1
    mark_refused "the <shard> field '3' is not this file's key, 2" "$s" "$f" || WHY="$WHY shard-3{rc=$MRC $(head -1 "$MKO")}"; fi
  if cell caller-key; then mark_args "$sd" "$f" implementation code-reviewer 2 key=2 findings=1
    mark_refused "carries key= or sha=" "$s" "$f" || WHY="$WHY caller-key{rc=$MRC $(head -1 "$MKO")}"; fi
  if cell caller-sha; then mark_args "$sd" "$f" implementation code-reviewer 2 sha=0123abcd findings=1
    mark_refused "carries key= or sha=" "$s" "$f" || WHY="$WHY caller-sha{rc=$MRC $(head -1 "$MKO")}"; fi
  if cell findings-3; then mark_args "$sd" "$f" implementation code-reviewer 2 findings=3
    mark_refused "findings=3' but its ## Findings section heads 1 finding(s)" "$s" "$f" || WHY="$WHY findings-3{rc=$MRC $(head -3 "$MKO")}"; fi
  if cell allow; then mark_args "$sd" "$f" implementation code-reviewer 2 findings=1
    [ "$MRC" -eq 0 ] && grep -qE '^seat-complete: implementation code-reviewer 2 key=2 sha=[0-9a-f]{64} findings=1$' "$f" \
      || WHY="$WHY allow{rc=$MRC $(head -2 "$MKO")}"; fi
  [ -z "$WHY" ]
}

# ---- SE1: the second instance's lead path. A part shard its seat wrote and marked reads SEAL-OK (the
# control); rewritten through Bash (`sed -i` on a heading) and re-marked, --mark refuses (64), naming
# the re-dispatch remedy, with the file byte-unchanged.
p_seal_rewrite() {
  local sd="$1" d f s
  WHY=""
  # One cell: every step below reads the state the step before it left.
  cell seal-rewrite || return 0
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  fire "$f" agent || { WHY="the recorder wrote no row for $f"; return 1; }
  mark_args "$sd" "$f" implementation qa 2 findings=1
  [ "$MRC" -eq 0 ] || { WHY="the seat's own --mark failed: $(head -2 "$MKO")"; return 1; }
  grep -qE '^seat-complete: implementation qa 2 key=2 sha=' "$f" \
    || { WHY="the seat's --mark did not take the review-shard branch (its marker carries no key=): $(tail -1 "$f")"; return 1; }
  ip_run "$sd/content-seal.sh" seal_main --review-shard "$f" > "$CO" 2>&1 < /dev/null; CRC=$?
  [ "$CRC" -eq 0 ] && has "$CO" "SEAL-OK:" || { WHY="control: the seat's own seal did not read SEAL-OK (rc=$CRC $(head -1 "$CO"))"; return 1; }
  sed -i.bak -e 's/^## Summary$/## Overview/' "$f" && rm -f "$f.bak" && grep -q '^## Overview$' "$f" \
    || { WHY="the in-place sed rewrite did not apply"; return 1; }
  cp "$f" "$s" || return 1
  mark_args "$sd" "$f" implementation qa 2 findings=1
  mark_refused "SEAL-REFUSED:" "$s" "$f" && has "$MKO" "re-dispatch the reviewer for that shard" \
    || { WHY="the Bash-rewritten shard was re-marked: rc=$MRC $(head -2 "$MKO")"; return 1; }
}

# ---- SE2: a shard whose last TOOL row is the top-level session's (a lead Edit) is refused at the merge.
# The control is the same set before that row; the ALLOW twin, one property apart, is an agent Edit after it.
p_session() {
  local sd="$1" d o
  WHY=""
  d="$(seal_world "$sd" code-review)" || { WHY="the sealed world was not built: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"
  if ! hand_use "$sd" key_ctl; then   # KY1 merged this exact sealed set; its answer is the control
    run_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || { WHY="control: the seat-sealed set did not merge: $(head -2 "$MO")"; return 1; }
  fi
  rm -f "$o"
  fire "$d/2.md" session Edit || { WHY="the recorder wrote no session row"; return 1; }
  run_merge "$sd" "$d"
  refused_clean "was last written by the top-level session" "$d" && owner_in "$MO" 2 || { WHY="a session-last shard: $(head -1 "$MO")"; return 1; }
  fire "$d/2.md" agent Edit || { WHY="the recorder wrote no agent row"; return 1; }
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || { WHY="allow: an agent Edit after the session's did not merge: $(head -1 "$MO")"; return 1; }
}

# ---- LG1: the legacy rule. Over B's frozen sha (the engine without the sentinel), a set of legacy
# markers merges and prints the exact LEGACY line naming the full sha -- one shard a seat's Write then the
# old Bash append, which body_sha accepts. The same Write then a sed rewrite is refused. The sentinel
# engine at the frozen sha refuses, and an engine in neither layout refuses.
p_legacy() {
  local sd="$1" d n SHARD_SHA
  WHY=""
  if cell old-engine; then
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the world was not built"; return 1; }
    fire "$d/2.md" agent || { WHY="the recorder wrote no row"; return 1; }
    lmark_all "$d"; run_merge "$sd" "$d"
    n="$(grep -c '^LEGACY: ' "$MO")" || n=0
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$n" = 6 ] \
      && grep -qxF "LEGACY: $d/1.md accepted without key= only because reviewed sha $B_SHA predates the key= engine" "$MO" \
      && grep -qxF "LEGACY: $d/2.md accepted without key= only because reviewed sha $B_SHA predates the key= engine" "$MO" \
      || { WHY="old engine: rc=$RC, $n LEGACY line(s): $(grep -v '^LEGACY: ' "$MO" | head -1)"; return 1; }
  fi
  if cell rewrite; then
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    fire "$d/2.md" agent || { WHY="the recorder wrote no row"; return 1; }
    sed -i.bak -e 's/^## Summary$/## Overview/' "$d/2.md" && rm -f "$d/2.md.bak" || return 1
    lmark_all "$d"; run_merge "$sd" "$d"
    refused_clean "changed after its last sealed write" "$d" && owner_in "$MO" 2 || WHY="$WHY rewrite{$(head -1 "$MO")}"
  fi
  if cell sentinel; then
    SHARD_SHA="$S_SHA"
    d="$(kworld "$sd" "$REPO_S" "$S_BASE" "$S_SHA" 3 code-review APPROVED)" || { WHY="$WHY the sentinel world was not built"; return 1; }
    lmark_all "$d"; run_merge "$sd" "$d"
    refused_clean "the frozen sha $S_SHA's core/scripts/wait-for-deliverable.sh is the key= engine" "$d" || WHY="$WHY sentinel{$(head -1 "$MO")}"
  fi
  if cell absent; then
    SHARD_SHA="$N_SHA"
    d="$(kworld "$sd" "$REPO_N" "$N_BASE" "$N_SHA" 3 code-review APPROVED)" || { WHY="$WHY the engine-absent world was not built"; return 1; }
    lmark_all "$d"; run_merge "$sd" "$d"
    refused_clean "cannot be read at the frozen sha $N_SHA" "$d" || WHY="$WHY absent{$(head -1 "$MO")}"
  fi
  [ -z "$WHY" ]
}

# ---- LY1: from a LINKED worktree the ledger is the MAIN checkout's, in both layouts: the reader in a
# consumer-layout tree (scripts/ai-dlc/) and in a distribution-layout tree (core/scripts/) each name
# <main>/_bmad-output/... for a shard in its linked worktree, never the worktree's own stale copy
# (seeded as a decoy holding a matching row). The recorder fired from the linked worktree writes into
# MAIN's ledger, both readers then read SEAL-OK, and a set sealed there merges.
lay_one() { # <main> <linked worktree> <reader>
  local d f rel
  mkdir -p "$2/docs/reviews" && d="$(mktemp -d "$2/docs/reviews/s9.XXXXXX")/shards/1-code-review-$B_SHA12" && mkdir -p "$d" || return 1
  f="$d/1.md"; printf '# shard\n\nreviewed-sha: %s\n' "$B_SHA" > "$f"; rel="${f#"$2"/}"
  mkdir -p "$2/_bmad-output/planning-artifacts" || return 1
  jq -nc --arg p "$rel" --arg r "$2" --arg s "$(shasum -a 256 < "$f" | cut -d' ' -f1)" \
    '{v: 1, kind: "content-seal", ts: "2000-01-01T00:00:00Z", path: $p, actor: "agent", agent_id: "a0123456789abcdef", root: $r, sha256: $s}' \
    >> "$2/_bmad-output/planning-artifacts/.artifact-writes.jsonl" || return 1
  ip_run "$3" seal_main --review-shard "$f" > "$CO" 2>&1 < /dev/null; CRC=$?
  LAY_F="$f"
  [ "$CRC" -eq 1 ] && has "$CO" "carries no content-seal row in $1/_bmad-output/planning-artifacts/.artifact-writes.jsonl" \
    && ! has "$CO" "$2/_bmad-output"
}
p_layouts() {
  local sd="$1" f n d o rd
  WHY=""
  lay_one "$DMAIN" "$DLW" "$DMAIN/core/scripts/content-seal.sh" || WHY="$WHY dist{rc=$CRC $(head -1 "$CO")}"
  lay_one "$MAIN" "$LW" "$MAIN/scripts/ai-dlc/content-seal.sh" || WHY="$WHY consumer{rc=$CRC $(head -1 "$CO")}"
  f="$LAY_F"
  fire "$f" agent || { WHY="$WHY the recorder wrote no row into $LEDGER for $f"; return 1; }
  n="$(jq -c --arg p "${f#"$LW"/}" --arg r "$LW" 'select(.path == $p and .root == $r and has("body_sha"))' "$LEDGER" | grep -c .)" || n=0
  [ "$n" = 1 ] || WHY="$WHY ledger-row{$n rows for the linked worktree's shard in $LEDGER}"
  [ "$(grep -c . "$LW/_bmad-output/planning-artifacts/.artifact-writes.jsonl")" = 1 ] || WHY="$WHY the recorder wrote into the linked worktree's own state dir"
  for rd in "$MAIN/scripts/ai-dlc/content-seal.sh" "$DMAIN/core/scripts/content-seal.sh"; do
    ip_run "$rd" seal_main --review-shard "$f" > "$CO" 2>&1 < /dev/null; CRC=$?
    [ "$CRC" -eq 0 ] && has "$CO" "SEAL-OK:" || WHY="$WHY read-from-$rd{rc=$CRC $(head -1 "$CO")}"
  done
  d="$(WROOT="$LW" seal_world "$sd" code-review)" || { WHY="$WHY the linked-worktree set was not sealed: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY:" || WHY="$WHY lw-merge{$(head -1 "$MO")}"
  [ -z "$WHY" ]
}

# ---- FT1: a review-shard row written BEFORE a gate part does not move --first-tool-ts (rows carrying
# body_sha are skipped); the control is the same ledger with that row's body_sha deleted, which does.
# Its own tree, so the gate part's row and the review row share one root.
p_first_ts() {
  local sd="$1" ft f p l t1 t2 r
  WHY=""
  ft="$(mktemp -d "$WORK/ft.XXXXXX")" || return 1
  mkdir -p "$ft/scripts/ai-dlc" && G init -q "$ft" && cp "$SEAL_SRC" "$ft/scripts/ai-dlc/content-seal.sh" && [ -d "$ft/.git" ] \
    || { WHY="FIXTURE ERROR: the tree $ft was not built"; return 1; }
  f="$ft/docs/reviews/s1/shards/1-code-review-$B_SHA12/1.md"; mkdir -p "$(dirname "$f")" && printf '# shard\n' > "$f"
  fire "$f" agent Write "$ft" || { WHY="the recorder wrote no review row"; return 1; }
  # The recorder stamps ts with date -u at one-second resolution, so the review row's ts is pinned to a
  # fixed earlier stamp (jq, selected by body_sha) rather than slept past: the real hook still wrote both rows.
  jq -c 'if has("body_sha") then .ts = "2000-01-01T00:00:00Z" else . end' "$ft/_bmad-output/planning-artifacts/.artifact-writes.jsonl" > "$ft/ts.tmp" \
    && mv "$ft/ts.tmp" "$ft/_bmad-output/planning-artifacts/.artifact-writes.jsonl" || { WHY="the review row ts was not pinned"; return 1; }
  p="$ft/_bmad-output/gate-adjudication/g1.part-1.jsonl"; mkdir -p "$(dirname "$p")" && printf '{}\n' > "$p"
  fire "$p" agent Write "$ft" || { WHY="the recorder wrote no gate-part row"; return 1; }
  l="$ft/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  t1="$(jq -r 'select(has("body_sha")) | .ts' "$l")"; t2="$(jq -r 'select(has("body_sha") | not) | .ts' "$l")"
  [ -n "$t1" ] && [ -n "$t2" ] && [ "$t1" \< "$t2" ] || { WHY="FIXTURE BROKEN: the review row ($t1) is not strictly before the part row ($t2)"; return 1; }
  r="$(ip_run "$sd/content-seal.sh" seal_main --first-tool-ts "$ft/_bmad-output" 2>&1)"
  [ "$r" = "$t2" ] || WHY="$WHY review-row-moved-it{$r, want $t2}"
  jq -c 'del(.body_sha)' "$l" > "$l.tmp" && mv "$l.tmp" "$l" || return 1
  r="$(ip_run "$sd/content-seal.sh" seal_main --first-tool-ts "$ft/_bmad-output" 2>&1)"
  [ "$r" = "$t1" ] || WHY="$WHY control{without body_sha the row read $r, want $t1}"
  [ -z "$WHY" ]
}

# ---- EV1: an ENVIRONMENT that cannot read the seal is the lead's, never a reviewer's. A seat-sealed set
# merged on a PATH built from this fixture's own tools.decl WITHOUT jq is REFUSED [owner: lead], naming
# SEAL-UNAVAILABLE and no re-dispatch; --mark on a fresh shard under it exits 64 relaying the same text.
# The control is the SAME set on the same PATH with jq added back, which merges -- so the built PATH lacks
# jq and nothing else the merge needs.
p_env() {
  local sd="$1" d o nb jb t f s
  WHY=""
  nb="$WORK/nojq-bin"; jb="$WORK/jq-bin"
  if [ ! -d "$nb" ]; then
    mkdir -p "$nb" "$jb" || return 1
    while IFS= read -r t; do
      case "$t" in ""|"#"*|jq) continue ;; esac
      f="$(command -v "$t")" && [ -x "$f" ] && ln -s "$f" "$nb/$t" || { WHY="FIXTURE ERROR: $t from tools.decl is not on PATH"; return 1; }
    done < "$LIB_DIR/tools.decl"
    ln -s "$(command -v jq)" "$jb/jq" || return 1
  fi
  # Resolved in a FRESH process: this shell's command hash table keeps /opt/homebrew/bin/jq from earlier arms
  # and answers `command -v jq` from it whatever PATH says.
  [ ! -e "$nb/jq" ] && env -i PATH="$nb" "$nb/bash" -c 'command -v git > /dev/null 2>&1 && ! command -v jq > /dev/null 2>&1' \
    || { WHY="FIXTURE BROKEN: the jq-less PATH $nb still resolves jq, or lacks git"; return 1; }
  d="$(seal_world "$sd" code-review)" || { WHY="the sealed world was not built: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"
  ip_run -e "PATH=$nb" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main "$d" --gate code-review --out "$o" \
    > "$MO" 2>&1 < /dev/null; RC=$?
  refused_clean "SEAL-UNAVAILABLE:" "$d" && has "$MO" "jq is not on PATH" && owner_in "$MO" lead \
    && ! has "$MO" "re-dispatch the reviewer" || WHY="$WHY nojq-merge{rc=$RC $(head -1 "$MO")}"
  ip_run -e "PATH=$nb:$jb" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main "$d" --gate code-review --out "$o" \
    > "$MO" 2>&1 < /dev/null; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || WHY="$WHY control-with-jq{rc=$RC $(head -1 "$MO")}"
  # --mark: a seat-written shard, its row recorded with jq present, marked on the jq-less PATH.
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="$WHY the mark world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  fire "$f" agent || { WHY="$WHY the recorder wrote no row for $f"; return 1; }
  cp "$f" "$s" || return 1
  ip_run -e "PATH=$nb" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/wait-for-deliverable.sh" wfd_mark_main --mark "$f" implementation code-reviewer 2 findings=1 \
    > "$MKO" 2>&1 < /dev/null; MRC=$?
  mark_refused "SEAL-UNAVAILABLE:" "$s" "$f" && has "$MKO" "repair the environment, then mark again." \
    || WHY="$WHY nojq-mark{rc=$MRC $(head -2 "$MKO")}"
  [ -z "$WHY" ]
}

# ---- UM1: an UNMARKED set over the key= engine takes the NON-legacy seal. Seeded exactly as the tip
# adversary's D2 repro (adv-strip.sh): a set of shards (here closed with markers), every `seat-complete:`
# line stripped with `awk '!/^seat-complete: /'`, one shard's verdict rewritten with sed, then merged over
# a frozen sha whose engine carries the sentinel and a ledger with no rows for them -> REFUSED, no seal
# row. The control is the same steps over B's frozen sha (the old engine), which merges with no LEGACY
# line (no marker is left to be legacy).
# THE REWRITE IS TO BLOCKED, NOT THE REPRO'S APPROVED (BL-740): the worlds are NEEDS_REWORK, so shard 2's
# one finding sits under Critical, and an APPROVED shard over a Critical finding is now refused by the
# merge's VERDICT BACKING -- a cause UM1 does not own, which would refuse the old-engine control. BLOCKED
# over a Critical finding is backed, so the control still merges, and the sentinel half still refuses at
# shard 1's seal before shard 2 is read. The property UM1 holds (no marker left, one verdict rewritten by
# sed, no seal row) is unchanged.
um_strip() { # <shard dir>: the repro's steps -- strip every marker, rewrite shard 2's verdict
  local f
  for f in "$1"/*.md; do awk '!/^seat-complete: /' "$f" > "$f.t" && mv "$f.t" "$f" || return 1; done
  sed -e 's/^shard-verdict: .*/shard-verdict: BLOCKED/' "$1/2.md" > "$1/2.t" && mv "$1/2.t" "$1/2.md" || return 1
  grep -q '^shard-verdict: BLOCKED$' "$1/2.md" && [ "$(cat "$1"/*.md | grep -c '^seat-complete: ')" = 0 ]
}
p_unmarked() {
  local sd="$1" d SHARD_SHA
  WHY=""
  if cell unmarked-sentinel; then
    SHARD_SHA="$S_SHA"
    d="$(kworld "$sd" "$REPO_S" "$S_BASE" "$S_SHA" 3 code-review NEEDS_REWORK)" || { WHY="the sentinel world was not built"; return 1; }
    lmark_all "$d"; um_strip "$d" || { WHY="FIXTURE BROKEN: the repro's strip and rewrite did not apply"; return 1; }
    run_merge "$sd" "$d"
    refused_clean "carries no content-seal row" "$d" || WHY="$WHY unmarked-sentinel{rc=$RC $(head -1 "$MO")}"
  fi
  if cell control-old-engine; then
    SHARD_SHA="$B_SHA"
    d="$(world4 "$sd" NEEDS_REWORK NEEDS_REWORK NEEDS_REWORK NEEDS_REWORK)" || { WHY="$WHY the old-engine world was not built"; return 1; }
    lmark_all "$d"; um_strip "$d" || { WHY="FIXTURE BROKEN: the repro's strip and rewrite did not apply (control)"; return 1; }
    run_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY:" || WHY="$WHY control-old-engine{rc=$RC $(head -1 "$MO")}"
  fi
  [ -z "$WHY" ]
}

# ===================================================================== BL-740: VERDICT BACKING.
# A shard's verdict is backed by its OWN findings, read off the merge's --gate. Each case overwrites shard
# 2 of a clean world (the first read is shard 1, so the refusal is the case's own), and is driven through
# the full merge AND --check-shard: a refusal must be one REFUSED line, byte-equal between the two
# (cs_same, CS1's comparison), carrying the case's own token; a pass must MERGE and answer SHARD-OK. Every
# case writes its own WHY token, `<case>{...}`, so a mutant's kill is read on the cell it moved.
# THE TOKENS are the merge's own message fragments. The code-review ones stop before the Important name
# on purpose: a container lift that loses that name changes the text after it, and the cell that owns
# that defect is cr-nr-imp, not the refusals beside it.
VB_STEM="a shard's verdict is backed by its own findings"
VB_CR_NR="carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding under '### Critical'"
VB_CR_BL="carries 'shard-verdict: BLOCKED' but no '#### ' finding under '### Critical'"
VB_CR_AP="carries 'shard-verdict: APPROVED' but 1 '#### ' finding(s) under '### Critical'; a Critical finding is not approvable"
VB_Q_NR="carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding in its '## Findings'"
# BL-746: the severity-mode tokens under --gate qa, the unclassed-finding refusal (both gates), the
# legacy line, and the wrong-count refusal.
VB_Q_SEV_NR="carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding under '### Critical' or '### Important'"
VB_Q_PASS_CRIT="carries 'shard-verdict: PASS' but 1 '#### ' finding(s) under '### Critical'; a Critical finding is not approvable"
VB_MOVE="or move the finding this shard already files under '### Suggestions' there"
VB_UNC="finding under '## Findings' with no '### ' container above it"
VB_LEG="declares no severity containers; QA verdict backing is count-only"
VB_Q2="qa.md's ## Findings template declares 2 severity container(s)"
# R3's three exact substrings: both satisfiable exits and the owner tail.
VB_R3_LEAD="If the finding belongs to another shard, set 'shard-verdict: PASS'"
VB_R3_FILE="otherwise file the finding that makes it NEEDS_REWORK here, as a '#### ' heading under '### Critical' or '### Important'"
VB_R3_SET="set 'shard-verdict: PASS' here and let that shard's verdict carry it"
VB_R3_OWN="[owner: cross-1]"
# The graph s319 story 3.1 cross-1 shard's own ## Findings body, verbatim: a qa NEEDS_REWORK whose gap
# it says is owned by another group's shard, and no '#### ' finding.
VB_R3_BODY="(none filed by cross-1. The AC4 gap below is owned by cross group g4, parts 2 and 3, under the brief's group table; filing it here would be refused as a duplicate of that owner.)"
# vb_c <dir> <key> <verdict> <cite> <crit|imp|sug|none>: code-reviewer.md's three containers, the one
# finding (shard_find) under the named one; `none` is the empty findings template.
vb_c() {
  local d="$1" k="$2" v="$3" cite="$4" at="$5" c
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n## Findings\n\n' "$k" "$k"
    for c in crit imp sug; do
      case "$c" in
        crit) printf '### Critical (must fix before merge)\n\n' ;;
        imp) printf '### Important (should fix, can be follow-up)\n\n' ;;
        sug) printf '### Suggestions (optional improvements)\n\n' ;;
      esac
      [ "$c" != "$at" ] || shard_find "$k" "$cite"
    done
    printf '## Architecture Alignment\nNothing further.\n'
  } > "$d/$k.md"
}
# vb_q <dir> <key> <verdict> <## Findings body, verbatim; empty for none>: a qa shard; the first cross
# shard carries the per-AC table and the deferred record, as qshard's does.
vb_q() {
  local d="$1" k="$2" v="$3" body="$4"
  {
    printf '# QA Validation shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nShard %s validated its part. QCONSERVE-%s-91c2\n\n## Findings\n\n' "$k" "$k"
    [ -z "$body" ] || printf '%s\n\n' "$body"
    if [ "$k" = cross ] || [ "$k" = cross-1 ]; then
      printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n| AC4 | %s | gap |\n\n' "$v"
      printf '## Deferred ACs\n\nNone.\n'
    fi
  } > "$d/$k.md"
}
# VB_O is the file the last vb_refuse/vb_pass read its answer from: $CO (the shard check alone) or $MO (the family's one
# end-to-end merge, VB_E2E=1, which runs the merge AND --check-shard and holds their REFUSED lines byte-equal).
VB_O=""
vb_refuse() { # <script-dir> <shard-dir> <gate> <target key> <case> <token> [second token]
  CS_TOK="$6"
  if [ "${VB_E2E:-0}" = 1 ] && [ "$1" = "$SRCDIR" ]; then
    VB_O="$MO"
    if cs_same "$1" "$2" "$3" "$2/$4.md" && { [ -z "${7:-}" ] || has "$CO" "$7"; }; then :
    else WHY="$WHY $5{$CS_LAST}"; fi
  else
    VB_O="$CO"
    run_check "$1" "$2" "$3" "$2/$4.md"
    if chk_refused "$6" "${7:-}" && has "$CO" "$2/$4.md"; then :
    else WHY="$WHY $5{check rc=$CRC [$(reline "$CO")]}"; fi
  fi
  CS_TOK=""
}
vb_pass() { # <script-dir> <shard-dir> <gate> <target key> <case>
  local o
  if [ "${VB_E2E:-0}" = 1 ] && [ "$1" = "$SRCDIR" ]; then
    VB_O="$MO"
    if [ "$3" = qa ]; then o="$(qout "$2")"; else o="$(out_of "$2")"; fi
    run_mg "$1" "$2" "$3" "$o"
    run_check "$1" "$2" "$3" "$2/$4.md"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $2/$4.md" \
      || WHY="$WHY $5{merge rc=$RC [$(head -1 "$MO")] check rc=$CRC [$(head -1 "$CO")]}"
    rm -f "$o"
  else
    VB_O="$CO"
    run_check "$1" "$2" "$3" "$2/$4.md"
    [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $2/$4.md" || WHY="$WHY $5{check rc=$CRC [$(head -1 "$CO")]}"
  fi
}
# ---- VB1 (code-review): NEEDS_REWORK and BLOCKED need a Critical or Important finding; APPROVED carries
# no Critical one. Each refusal has its ALLOW twin one container apart.
p_vb_cr() {
  local sd="$1" d c
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the code-review world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell cr-nr-empty; then vb_c "$d" 2 NEEDS_REWORK 2 none; VB_E2E=1 vb_refuse "$sd" "$d" code-review 2 cr-nr-empty "$VB_CR_NR" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell cr-nr-imp; then vb_c "$d" 2 NEEDS_REWORK 2 imp; vb_pass "$sd" "$d" code-review 2 cr-nr-imp; cs_reset "$d" "$c"; fi
  if cell cr-blocked-crit; then vb_c "$d" 2 BLOCKED 2 crit; vb_pass "$sd" "$d" code-review 2 cr-blocked-crit; cs_reset "$d" "$c"; fi
  if cell cr-blocked-sug; then vb_c "$d" 2 BLOCKED 2 sug; vb_refuse "$sd" "$d" code-review 2 cr-blocked-sug "$VB_CR_BL" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell cr-approved-crit; then vb_c "$d" 2 APPROVED 2 crit; vb_refuse "$sd" "$d" code-review 2 cr-approved-crit "$VB_CR_AP"; cs_reset "$d" "$c"; fi
  if cell cr-approved-imp; then vb_c "$d" 2 APPROVED 2 imp; vb_pass "$sd" "$d" code-review 2 cr-approved-imp; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# qf <container first word|none> -> one finding of shard 2, under that container (none: no `### `).
qf() { if [ "$1" = none ]; then printf '#### Q-2-9 a gap\nparts: 2\n\nBody.'; else printf '### %s (seeded)\n\n#### Q-2-9 a gap\nparts: 2\n\nBody.' "$1"; fi; }
# ---- VB2 (qa, BL-746): qa.md declares the three containers, so the SEVERITY rule is the code-review
# rule: NEEDS_REWORK needs a Critical or Important finding, PASS carries no Critical, and a finding with
# no container is refused as unclassed. Each refusal has its ALLOW twin one container apart. No LEGACY
# line under the three-container qa.md.
p_vb_qa() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell q-nr-empty; then vb_q "$d" 2 NEEDS_REWORK ""; VB_E2E=1 vb_refuse "$sd" "$d" qa 2 q-nr-empty "$VB_Q_SEV_NR" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell q-nr-sug; then vb_q "$d" 2 NEEDS_REWORK "$(qf Suggestions)"; vb_refuse "$sd" "$d" qa 2 q-nr-sug "$VB_Q_SEV_NR" "$VB_MOVE"; cs_reset "$d" "$c"; fi
  if cell q-nr-imp; then vb_q "$d" 2 NEEDS_REWORK "$(qf Important)"; vb_pass "$sd" "$d" qa 2 q-nr-imp
    ! has "$VB_O" "$VB_LEG" || WHY="$WHY q-sev-legacy-line{$(head -1 "$VB_O")}"; cs_reset "$d" "$c"; fi
  if cell q-pass-crit; then vb_q "$d" 2 PASS "$(qf Critical)"; vb_refuse "$sd" "$d" qa 2 q-pass-crit "$VB_Q_PASS_CRIT"; cs_reset "$d" "$c"; fi
  if cell q-pass-imp; then vb_q "$d" 2 PASS "$(qf Important)"; VB_E2E=1 vb_pass "$sd" "$d" qa 2 q-pass-imp; cs_reset "$d" "$c"; fi
  if cell q-unclassed; then vb_q "$d" 2 PASS "$(qf none)"; vb_refuse "$sd" "$d" qa 2 q-unclassed "$VB_UNC"; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# ---- VB2M (qa, BL-746): the MODE alone, in one cell, so a mutant that keeps QA count-only under a
# three-container qa.md moves exactly this assertion -- VB2's cells all move with the mode too, which is
# why M12 is scored here and not there. NEEDS_REWORK backed only by a Suggestions finding is REFUSED.
p_vb_qmode() {
  local sd="$1" d
  WHY=""
  cell q-mode-sug || return 0
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  vb_q "$d" 2 NEEDS_REWORK "$(qf Suggestions)"; vb_refuse "$sd" "$d" qa 2 q-mode-sug "$VB_Q_SEV_NR" "$VB_MOVE"
  [ -z "$WHY" ]
}
# ---- VB2L (qa, BL-746 delivery path): the qa.md a consumer has installed until the reconcile merge
# declares NO container, and the rule stays count-only -- an uncontained NEEDS_REWORK finding merges,
# and an empty NEEDS_REWORK is refused with the count-only text; stdout carries the LEGACY line. A
# qa.md declaring TWO containers is REFUSED, never read as either mode. The code-review gate is not
# affected by qa.md's state (a cr world under the legacy root still refuses an unclassed finding).
p_vb_qleg() {
  local sd="$1" d c o
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  VB_PROJ="$PROJ_QLEG"
  if cell q-leg-nr-one; then vb_q "$d" 2 NEEDS_REWORK "$(qf none)"; VB_E2E=1 vb_pass "$sd" "$d" qa 2 q-leg-nr-one
    has "$VB_O" "LEGACY: $PROJ_QLEG/core/team-roles/qa.md $VB_LEG" || WHY="$WHY q-leg-line{$(head -1 "$VB_O")}"; cs_reset "$d" "$c"; fi
  if cell q-leg-pass-crit; then vb_q "$d" 2 PASS "$(qf Critical)"; vb_pass "$sd" "$d" qa 2 q-leg-pass-crit; cs_reset "$d" "$c"; fi
  if cell q-leg-nr-empty; then vb_q "$d" 2 NEEDS_REWORK ""; vb_refuse "$sd" "$d" qa 2 q-leg-nr-empty "$VB_Q_NR" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell q-two-containers; then
    VB_PROJ="$PROJ_Q2"
    run_check "$sd" "$d" qa "$d/2.md"
    chk_refused "$VB_Q2" && owner_in "$CO" lead || WHY="$WHY q-two-containers{rc=$CRC $(reline "$CO")}"
    VB_PROJ="$PROJ_QLEG"
  fi
  if cell cr-unclassed; then
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { VB_PROJ=""; WHY="$WHY the code-review world was not built"; return 1; }
    raw_shard "$d" 2 '## Findings' '' '#### F-2-9 uncontained' 'parts: 2' '' 'Body.'
    vb_refuse "$sd" "$d" code-review 2 cr-unclassed "$VB_UNC"
  fi
  VB_PROJ=""
  [ -z "$WHY" ]
}
# ---- QC1 (qa, BL-844): THE CLASS LINE under --gate qa, the set lifted from qa.md. A part shard's
# Important finding carrying `Class: FOO` is REFUSED by the merge and --check-shard byte-equal, naming
# qa.md's set; `Class: EVIDENCE` merges and is SHARD-OK; over a qa.md declaring no template line the
# same FOO shard merges (no set, nothing checked) -- presence-shaped: MERGED: and SHARD-OK must appear.
QC_BAD="'Class: FOO' is not one of BOOKKEEPING CODE EVIDENCE TEST (qa.md's template)"
qc_body() { printf '### Important (seeded)\n\n#### Q-2-9 a stale capture block\nparts: 2\nClass: %s\n\nBody.' "$1"; }
p_qclass() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  VB_PROJ="$PROJ_QCLS"
  if cell qc-foo; then vb_q "$d" 2 NEEDS_REWORK "$(qc_body FOO)"; vb_refuse "$sd" "$d" qa 2 qc-foo "$QC_BAD"; cs_reset "$d" "$c"; fi
  if cell qc-evidence; then vb_q "$d" 2 NEEDS_REWORK "$(qc_body EVIDENCE)"; vb_pass "$sd" "$d" qa 2 qc-evidence; cs_reset "$d" "$c"; fi
  if cell qc-none; then VB_PROJ="$PROJ_QNOCLS"; vb_q "$d" 2 NEEDS_REWORK "$(qc_body FOO)"; vb_pass "$sd" "$d" qa 2 qc-none; cs_reset "$d" "$c"; fi
  VB_PROJ=""
  [ -z "$WHY" ]
}
# ---- FL1 (BL-809 item 2): THE FILES LINE. A part shard's Important finding carrying a `Files:` line is
# checked by --check-shard: the well-formed CODE finding naming two paths tracked at the frozen sha is
# SHARD-OK (fl-ok, the near-miss every refusal below is one property from); refused: Files: on an
# EVIDENCE finding, two Files: lines, an empty list, a backticked entry, a `:line` entry, a bare basename
# and a path tracked nowhere. Presence-shaped: SHARD-OK or the named refusal text must appear.
fl_body() { # <class> <files line(s), each an argument>
  local c="$1" l; shift
  printf '%s\n' '## Summary' 'Shard 2 read its part.' '' '## Findings' '' '### Critical (must fix before merge)' '' 'None.' '' \
    '### Important (should fix, can be follow-up)' '' '#### F-2-9 an unchecked return' 'parts: 2' "Class: $c"
  for l in "$@"; do printf '%s\n' "$l"; done
  printf '%s\n' '' 'Body.' '' '### Suggestions (optional improvements)' '' 'None.'
}
fl_shard() { local d="$1"; shift; local b; b="$(fl_body "$@")"; raw_shard "$d" 2 "$b"; }
fl_refuse() { # <script-dir> <shard-dir> <case> <token>
  run_check "$1" "$2" code-review "$2/2.md"
  chk_refused "$4" && has "$CO" "$2/2.md" || WHY="$WHY $3{check rc=$CRC [$(reline "$CO")]}"
}
p_files() {
  local sd="$1" d c
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the code-review world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell fl-ok; then fl_shard "$d" CODE 'Files: alpha/a1.txt, beta/b1.txt'; run_check "$sd" "$d" code-review "$d/2.md"
    [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $d/2.md" || WHY="$WHY fl-ok{check rc=$CRC [$(reline "$CO")]}"; cs_reset "$d" "$c"; fi
  if cell fl-nc; then fl_shard "$d" EVIDENCE 'Files: alpha/a1.txt'; fl_refuse "$sd" "$d" fl-nc "is a 'Files:' line on a Class EVIDENCE finding"; cs_reset "$d" "$c"; fi
  if cell fl-dup; then fl_shard "$d" CODE 'Files: alpha/a1.txt' 'Files: beta/b1.txt'; fl_refuse "$sd" "$d" fl-dup "is a second 'Files:' line in one finding"; cs_reset "$d" "$c"; fi
  if cell fl-empty; then fl_shard "$d" CODE 'Files:'; fl_refuse "$sd" "$d" fl-empty "'Files:' names no path"; cs_reset "$d" "$c"; fi
  if cell fl-tick; then fl_shard "$d" CODE 'Files: `alpha/a1.txt`'; fl_refuse "$sd" "$d" fl-tick "entry '\`alpha/a1.txt\`' is not a bare repo-relative path"; cs_reset "$d" "$c"; fi
  if cell fl-line; then fl_shard "$d" TEST 'Files: alpha/a1.txt:3'; fl_refuse "$sd" "$d" fl-line "entry 'alpha/a1.txt:3' is not a bare repo-relative path"; cs_reset "$d" "$c"; fi
  if cell fl-base; then fl_shard "$d" CODE 'Files: a1.txt'; fl_refuse "$sd" "$d" fl-base "entry 'a1.txt' is neither tracked at the frozen sha"; cs_reset "$d" "$c"; fi
  if cell fl-gone; then fl_shard "$d" CODE 'Files: alpha/a1.txt, alpha/zz.txt'; fl_refuse "$sd" "$d" fl-gone "entry 'alpha/zz.txt' is neither tracked at the frozen sha"; cs_reset "$d" "$c"; fi
  if cell fl-del; then fl_del "$sd"; fi
  [ -z "$WHY" ]
}
# fl-del: a Files: entry naming a file the range DELETED is accepted (it is not tracked at the frozen sha,
# but `diff --name-only <base>..<sha>` names it). Its own frozen commit, minted on B_SHA in a scratch clone of
# REPO_B so no other world's refs move: it deletes alpha/a1.txt and edits beta/b1.txt, two groups at
# --min-files 2. Part shard 1 (alpha/) carries `parts: 1`, `Class: CODE`, `Files: alpha/a1.txt`: SHARD-OK.
# Controls in the same world: a path tracked at the frozen sha (beta/b2.txt) is SHARD-OK, a path tracked
# nowhere (alpha/zz.txt) is REFUSED; neither moves under M57, which drops the diff-name-only allowance.
fl_del() {
  local sd="$1" r w d s m b
  r="$WORK/repo-fldel"
  if [ ! -d "$r/.git" ]; then
    G clone -q "$REPO_B" "$r" 2>/dev/null && G -C "$r" checkout -q --detach "$B_SHA" \
      && G -C "$r" rm -q alpha/a1.txt && printf 'beta edited\n' >> "$r/beta/b1.txt" \
      && G -C "$r" add -A && G -C "$r" commit -q -m fl-del || { WHY="$WHY fl-del{the deleting commit was not minted}"; return; }
  fi
  s="$(G -C "$r" rev-parse HEAD)" || { WHY="$WHY fl-del{no frozen sha}"; return; }
  w="$(wdir)" || { WHY="$WHY fl-del{no world dir}"; return; }
  d="$w/1-code-review-$(printf '%s' "$s" | cut -c1-12)"
  ip_run "$sd/partition-review-diff.sh" prd_main --map "$r" "$B_SHA" "$s" --min-files 2 --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null \
    && [ -f "$d/.manifest" ] && [ "$(cut -f2 "$w/map" | tr '\n' ' ')" = "alpha/* beta/ " ] \
    || { WHY="$WHY fl-del{the two-group map was not written: $(head -1 "$w/map.err") $(tr '\n' ' ' < "$w/map")}"; return; }
  for m in del:alpha/a1.txt tracked:beta/b2.txt gone:alpha/zz.txt; do
    { printf '# Code Review shard 1\n\nreviewed-sha: %s\nshard-verdict: APPROVED\n' "$s"; adv_l; printf 'handovers: 0\n\n'
      fl_body CODE "Files: ${m#*:}" | sed -e 's/^parts: 2$/parts: 1/' -e 's/^Shard 2 read/Shard 1 read/' -e 's/^#### F-2-9/#### F-1-9/'; } > "$d/1.md"
    grep -qx "reviewed-sha: $s" "$d/1.md" && grep -qx 'parts: 1' "$d/1.md" || { WHY="$WHY fl-del{the shard was not seeded}"; return; }
    run_check "$sd" "$d" code-review "$d/1.md"
    case "${m%%:*}" in
      del) [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $d/1.md" || WHY="$WHY fl-del{check rc=$CRC [$(reline "$CO")]}" ;;
      tracked) [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $d/1.md" || WHY="$WHY fl-del-tracked{check rc=$CRC [$(reline "$CO")]}" ;;
      gone) chk_refused "entry 'alpha/zz.txt' is neither tracked at the frozen sha" || WHY="$WHY fl-del-gone{check rc=$CRC [$(reline "$CO")]}" ;;
    esac
  done
}
# ---- VB3 (R3): the graph cross-1 shape. A qa cross-1 at NEEDS_REWORK whose ## Findings says the gap is
# another group's shard's: REFUSED, byte-equal under --check-shard, naming BOTH exits and its owner.
p_vb_r3() {
  local sd="$1" d
  WHY=""
  # One cell: every assertion below reads the one merge of the graph cross-1 shape.
  cell r3-graph-cross1 || return 0
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  [ -f "$d/cross-1.md" ] || { WHY="FIXTURE BROKEN: the qa world has no cross-1"; return 1; }
  vb_q "$d" cross-1 NEEDS_REWORK "$VB_R3_BODY"
  VB_E2E=1 vb_refuse "$sd" "$d" qa cross-1 r3-graph-cross1 "$VB_Q_SEV_NR" "$VB_STEM"
  has "$VB_O" "$VB_R3_FILE" || WHY="$WHY r3-file-exit{$(reline "$VB_O")}"
  has "$VB_O" "$VB_R3_SET" || WHY="$WHY r3-set-pass-exit{$(reline "$VB_O")}"
  has "$VB_O" "$VB_R3_LEAD" || WHY="$WHY r3-owner-first{$(reline "$VB_O")}"
  local mo_txt_
  mo_txt_="$(reline "$VB_O")"
  case "$mo_txt_" in *"$VB_R3_LEAD"*"$VB_R3_FILE"*) ;; *) WHY="$WHY r3-owner-first-order{${mo_txt_}}" ;; esac
  has "$VB_O" "$VB_R3_OWN" && owner_in "$VB_O" cross-1 || WHY="$WHY r3-owner{$(reline "$VB_O")}"
  [ -z "$WHY" ]
}
# ---- VB4 (--mark): findings=0 on an empty NEEDS_REWORK code-review shard exits 64 relaying the stem, the
# file byte-unchanged; the ALLOW twin, same file, one Important finding filed and re-written by the seat,
# marks it findings=1 keyed 2.
p_vb_mark() {
  local sd="$1" d f s
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the mark world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  vb_c "$d" 2 NEEDS_REWORK 2 none
  fire "$f" agent || { WHY="the recorder wrote no row for $f"; return 1; }
  cp "$f" "$s" || return 1
  mark_args "$sd" "$f" implementation code-reviewer 2 findings=0
  mark_refused "$VB_CR_NR" "$s" "$f" && has "$MKO" "$VB_STEM" || WHY="$WHY mark-nr-empty{rc=$MRC $(head -3 "$MKO")}"
  vb_c "$d" 2 NEEDS_REWORK 2 imp
  fire "$f" agent || { WHY="$WHY the recorder wrote no row for the re-written $f"; return 1; }
  mark_args "$sd" "$f" implementation code-reviewer 2 findings=1
  [ "$MRC" -eq 0 ] && grep -qE '^seat-complete: implementation code-reviewer 2 key=2 sha=[0-9a-f]{64} findings=1$' "$f" \
    || WHY="$WHY mark-allow{rc=$MRC $(head -2 "$MKO")}"
  [ -z "$WHY" ]
}

# ---- FR1-FR3 (BL-747): the first cross shard's per-AC table against the merged verdict and every
# shard's findings. The table is qa.md's own shape (`| AC | Result | Expected | Got |`) unless a case
# names another header; the FAIL row is AC4, never the first row. fr_x1 rewrites cross-1 only.
FR_TBL='| AC | Result | Expected | Got |'
FR_VERD="reads FAIL but the QA verdict is PASS"
FR_ORPH="reads FAIL but no '#### ' finding names"
FR_DUP="a finding owned by cross-2"
# fr_x1 <dir> <verdict> <extra findings text, may be empty> <header row> <AC4 row>
fr_x1() {
  local g1 f1 l1
  g1="$(awk -F'\t' '$1 == 1 { print $2; exit }' "$1.groups")"; f1="${g1%%,*}"; l1="${g1##*,}"
  {
    printf '# QA Validation shard cross-1\n\nreviewed-sha: %s\nshard-verdict: %s\n' "${SHARD_SHA:-$B_SHA}" "$2"; adv_l; printf '\n'
    printf '## Summary\nShard cross-1 validated its part. QCONSERVE-cross-1-91c2\n\n%s\n\n' "$CANON_BLK"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-cross-1-1 a missing caller in shard cross-1\nparts: %s, %s\n\nBody.\n\n' "$f1" "$l1"
    [ -z "$3" ] || printf '%s\n\n' "$3"
    printf '## Acceptance Criteria\n\n%s\n|---|---|---|---|\n| AC1 | PASS | suite green | green |\n%s\n| AC5 | PASS | x | y |\n\n' "$4" "$5"
    printf '## Deferred ACs\n\nNone.\n'
  } > "$1/cross-1.md"
}
fr_find2() { printf '### Important (seeded)\n\n#### Q-2-9 %s\nparts: 2\n\n%s' "$1" "$2"; } # <heading> <body>
fr_merged() { # <script-dir> <dir> <case> <want verdict>; FR_KEEP=<name> saves the answer, --out file included, before the rm
  local o; o="$(qout "$2")"; q_merge "$1" "$2"
  [ -z "${FR_KEEP:-}" ] || hand_keep "$1" "$FR_KEEP" "$o" "$2"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=$4 " || WHY="$WHY $3{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
  rm -f "$o"
}
fr_refused() { # <script-dir> <dir> <case> <token>
  local o; o="$(qout "$2")"; q_merge "$1" "$2"
  refused_at "$4" "$o" && owner_in "$MO" cross-1 || WHY="$WHY $3{rc=$RC $(reline "$MO")}"
  # A mutant that MERGES here writes --out; left on disk it makes the NEXT cell's merge refuse as
  # "already exists and differs", so the mutant would move a second cell for a reason it does not own.
  rm -f "$o"
}
# FR1: the verdict rule. PASS over a FAIL row is refused in three spellings and in a reordered table;
# a FAIL only in Expected, and FAILED-free rows, merge; NEEDS_REWORK carried by another shard merges.
p_fr_verdict() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell fr-plain; then fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'; fr_refused "$sd" "$d" fr-plain "$FR_VERD"; cs_reset "$d" "$c"; fi
  if cell fr-bold; then fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | **FAIL** | a RED | none |'; fr_refused "$sd" "$d" fr-bold "$FR_VERD"; cs_reset "$d" "$c"; fi
  if cell fr-paren; then fr_x1 "$d" PASS "" "$FR_TBL" '| `AC4` (committed RED) | FAIL (no RED) | a RED | none |'; fr_refused "$sd" "$d" fr-paren "$FR_VERD"; cs_reset "$d" "$c"; fi
  if cell fr-reorder; then fr_x1 "$d" PASS "" '| AC | Expected | Result | Got |' '| AC4 | green | FAIL | none |'; fr_refused "$sd" "$d" fr-reorder "$FR_VERD"; cs_reset "$d" "$c"; fi
  # The near-miss puts FAIL in Got, the column AFTER the named one, so a read-by-position mutant (M16,
  # rc = ac + 1, which lands on Expected) moves only fr-reorder, never this cell.
  if cell fr-expected-only; then fr_x1 "$d" PASS "" '| AC | Expected | Verdict | Got |' '| AC4 | green | PASS | FAIL then green |'; fr_merged "$sd" "$d" fr-expected-only PASS; cs_reset "$d" "$c"; fi
  if cell fr-all-pass; then fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | PASS | a RED | RED |'; fr_merged "$sd" "$d" fr-all-pass PASS; cs_reset "$d" "$c"; fi
  if cell fr-nr-elsewhere; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'AC4 has no committed RED' 'Body.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'; fr_merged "$sd" "$d" fr-nr-elsewhere NEEDS_REWORK; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# FR2: the orphan rule. A FAIL row under a NEEDS_REWORK merge whose AC no finding names is refused --
# the table's own mention of AC4 does not count -- and AC10 does not name AC1; the twins merge.
p_fr_orphan() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell fr-orphan; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap with no AC named' 'Body.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED for AC4 | none |'; fr_refused "$sd" "$d" fr-orphan "$FR_ORPH AC4"; cs_reset "$d" "$c"; fi
  if cell fr-ac10; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap' 'AC10 has no committed RED.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC1 | FAIL | a RED | none |'; fr_refused "$sd" "$d" fr-ac10 "$FR_ORPH AC1"; cs_reset "$d" "$c"; fi
  if cell fr-ac1; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap' 'AC1 has no committed RED; AC10 is fine.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC1 | FAIL | a RED | none |'; fr_merged "$sd" "$d" fr-ac1 NEEDS_REWORK; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# FR4: graph 811ad3d7d, story 3.1 qa p2 (read-only), as two states. There cross-1 carried `| AC4 | FAIL |`
# under `shard-verdict: PASS`, and cross-4 (NEEDS_REWORK; F1 about AC10, its findings under NO `### `
# container, `parts: 2, 3`) named no AC4; a hand-added `#### F2 — AC4 ...`, uncontained, same parts, let
# the merge through. That set ran against the consumer's installed qa.md, which declared no container,
# so the world runs under PROJ_QLEG. Here K=3, so the non-first cross shard is cross-2 standing in for
# cross-4, citing its own group's pair. Each state asserts the refusal it is refused ON (its message),
# and that it is not the other FAIL-row refusal.
fr_g_cross() { # <dir> <first> <last> <with F2: 0|1>
  {
    printf '# QA Validation shard cross-2\n\nreviewed-sha: %s\nshard-verdict: NEEDS_REWORK\n' "${SHARD_SHA:-$B_SHA}"; adv_l; printf '\n'
    printf '## Summary\nShard cross-2 validated its part. QCONSERVE-cross-2-91c2\n\n## Findings\n\n'
    printf '#### F1 — AC10 two-pair and unpriced-token totals are driven from hand-built rows, not the real parser\n\nparts: %s, %s\n\nBody.\n\n' "$2" "$3"
    [ "$4" = 0 ] || printf '#### F2 — AC4 has no committed mutation-RED reaching its discriminating fixture\n\nparts: %s, %s\n\nBody.\n\n' "$2" "$3"
    printf '## Items checked, no finding\n\nNone.\n'
  } > "$1/cross-2.md"
}
FR_BLEG="held to the count-only QA rule only because the frozen sha"
# fr_g_world <script-dir> <repo> <base> <sha> <with F2: 0|1> -> the graph-shaped qa set frozen over
# <repo>, every shard PASS but cross-1's AC4 FAIL row and cross-2's NEEDS_REWORK (graph's cross-4).
fr_g_world() {
  local sd="$1" d g2 f2 l2
  SHARD_SHA="$4"
  d="$(kworld "$sd" "$2" "$3" "$4" 3 qa-validation PASS qa)" || return 1
  [ -f "$d/cross-2.md" ] && [ -f "$d.groups" ] || return 1
  g2="$(awk -F'\t' '$1 == 2 { print $2; exit }' "$d.groups")"; f2="${g2%%,*}"; l2="${g2##*,}"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | Committed mutation-RED for each discriminating fixture in AC4. | No committed RED. |'
  fr_g_cross "$d" "$f2" "$l2" "$5"
  printf '%s' "$d"
}
# FR4: graph's two states, the set frozen over a tree whose INSTALLED qa.md declares no container
# (graph's, measured at 50eb567df), judged by today's three-container qa.md.
p_fr_graph() {
  local sd="$1" d SHARD_SHA
  WHY=""
  d="$(fr_g_world "$sd" "$REPO_QL" "$QL_BASE" "$QL_SHA" 0)" || { WHY="the frozen-QL world was not built"; return 1; }
  fr_refused "$sd" "$d" fr-graph-pre-f2 "$FR_ORPH AC4"
  ! has "$MO" "$FR_VERD" || WHY="$WHY fr-graph-pre-f2-wrong-rule{$(reline "$MO")}"
  d="$(fr_g_world "$sd" "$REPO_QL" "$QL_BASE" "$QL_SHA" 1)" || { WHY="$WHY the frozen-QL post-F2 world was not built"; return 1; }
  FR_KEEP=frg_post fr_merged "$sd" "$d" fr-graph-post-f2 NEEDS_REWORK
  has "$MO" "LEGACY: $d/cross-2.md $FR_BLEG $QL_SHA's .claude/team-roles/qa.md" || WHY="$WHY fr-graph-post-f2-legacy-line{$(head -2 "$MO" | tr '\n' ' ')}"
  [ -z "$WHY" ]
}
# FRB: THE SEVERITY BOUNDARY, one cell per side. The post-F2 set (cross-2's findings uncontained):
# frozen over the container-less installed qa.md -> merges NEEDS_REWORK with the LEGACY line; frozen
# over the three-container one -> REFUSED unclassed [owner: cross-2], no LEGACY line; frozen over a tree
# installing no qa.md (unreadable) -> REFUSED the same way, never acquitted.
p_fr_bound() {
  local sd="$1" d o SHARD_SHA
  WHY=""
  if cell frb-legacy; then
    if hand_use "$sd" frg_post; then   # FR4's post-F2 world is this world (REUSE-proved EQUAL under --matrix)
      [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK " || WHY="$WHY frb-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else
      d="$(fr_g_world "$sd" "$REPO_QL" "$QL_BASE" "$QL_SHA" 1)" || { WHY="the frozen-QL world was not built"; return 1; }
      fr_merged "$sd" "$d" frb-legacy NEEDS_REWORK
    fi
    has "$MO" "$FR_BLEG" || WHY="$WHY frb-legacy-line{$(head -1 "$MO")}"
  fi
  if cell frb-severity; then
    d="$(fr_g_world "$sd" "$REPO_QS" "$QS_BASE" "$QS_SHA" 1)" || { WHY="$WHY the frozen-QS world was not built"; return 1; }
    o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$VB_UNC" "$o" && owner_in "$MO" cross-2 && ! has "$MO" "$FR_BLEG" || WHY="$WHY frb-severity{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  if cell frb-unreadable; then
    d="$(fr_g_world "$sd" "$REPO_B" "$B_BASE" "$B_SHA" 1)" || { WHY="$WHY the unreadable world was not built"; return 1; }
    o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$VB_UNC" "$o" && owner_in "$MO" cross-2 && ! has "$MO" "$FR_BLEG" || WHY="$WHY frb-unreadable{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  [ -z "$WHY" ]
}
# FR3: the remedy is SATISFIABLE under the owner rule (graph s319 3-1 p2 cross-1: AC4 FAIL, the gap's
# set owned by another cross group). cross-1 filing the AC4 finding under cross-2's own set is the
# owner-duplicate refusal; filing it under a set cross-1 owns merges; so does the owning shard naming
# AC4 in the finding it already carries.
p_fr_remedy() {
  local sd="$1" d c g2 f2 l2 g1 f1 l1
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  [ -f "$d/cross-2.md" ] || { WHY="FIXTURE BROKEN: the qa world has no cross-2"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  g1="$(awk -F'\t' '$1 == 1 { print $2; exit }' "$d.groups")"; f1="${g1%%,*}"; l1="${g1##*,}"
  g2="$(awk -F'\t' '$1 == 2 { print $2; exit }' "$d.groups")"; f2="${g2%%,*}"; l2="${g2##*,}"
  fr_x1 "$d" NEEDS_REWORK "$(printf '#### Q-cross-1-4 AC4 has no committed RED\nparts: %s, %s\n\nBody.' "$f2" "$l2")" "$FR_TBL" '| AC4 | FAIL | a RED | none |'
  fr_refused "$sd" "$d" fr-dup-blocks "$FR_DUP"; cs_reset "$d" "$c"
  fr_x1 "$d" NEEDS_REWORK "$(printf '#### Q-cross-1-4 AC4 has no committed RED\nparts: %s, %s\n\nBody.' "$f1" "$l1")" "$FR_TBL" '| AC4 | FAIL | a RED | none |'
  fr_merged "$sd" "$d" fr-own-set NEEDS_REWORK; cs_reset "$d" "$c"
  qshard "$d" cross-2 NEEDS_REWORK "$f2, $l2"
  awk '/^#### Q-cross-2-1 / { print "#### Q-cross-2-1 AC4: a missing caller in shard cross-2"; next } { print }' "$d/cross-2.md" > "$d/x.tmp" && mv "$d/x.tmp" "$d/cross-2.md"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'
  fr_merged "$sd" "$d" fr-owner-names NEEDS_REWORK
  [ -z "$WHY" ]
}

# ---- SR1 (BL-742): --check-serial runs the merge's own Check 1 read-back and set membership over ONE
# serial file, and under --gate qa the FAIL ROWS rules. Each refusal has its ALLOW twin one line apart.
SR_COUNT="time(s) reading 2 different values"
SR_SET="which is not one of"
SR_OWN="[owner: serial]"
# sr_file <path> <verdict block, verbatim> [per-AC FAIL row] [findings body] [per-AC heading]
sr_file() {
  {
    printf '# QA Validation: 1\n\n'; adv_l
    printf '\n## Summary\nSerial.\n\n%s\n\n%s\n\n## Findings\n\n%s\n\n' "${SR_CANON-$CANON_BLK}" "$2" "${4:-### Critical (must fix before PASS)

None.}"
    printf '%s\n\n| AC | Result | Expected | Got |\n|---|---|---|---|\n| AC1 | PASS | x | y |\n' "${5:-## Acceptance Criteria}"
    [ -z "${3:-}" ] || printf '%s\n' "$3"
  } > "$1"
}
sr_run() { # <script-dir> <file> <gate> -> SRC, $CO
  ip_run -e "AI_DLC_PROJECT_ROOT=$PROJ" "$1/merge-review-shards.sh" mrs_main --check-serial "$2" --gate "$3" > "$CO" 2>&1 < /dev/null; SRC=$?
}
sr_ok() { # <script-dir> <file> <gate> <case> <verdict>
  sr_run "$1" "$2" "$3"
  [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: $2 verdict=$5" || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
sr_no() { # <script-dir> <file> <gate> <case> <token>
  sr_run "$1" "$2" "$3"
  [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$5" && has "$CO" "$SR_OWN" && ! has "$CO" "SERIAL-OK" \
    || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
p_serial() {
  local sd="$1" f="$WORK/serial-1-qa-validation.md" g="$WORK/serial-1-code-review.md"
  WHY=""
  if cell sr-q-heading; then sr_file "$f" "$(printf '## Verdict\nPASS')"; sr_ok "$sd" "$f" qa sr-q-heading PASS; fi
  if cell sr-q-line; then sr_file "$f" 'Verdict: NEEDS_REWORK' '' "$(printf '### Important (x)\n\n#### Q-1 a gap\n\nBody.')"; sr_ok "$sd" "$f" qa sr-q-line NEEDS_REWORK; fi
  if cell sr-q-union; then sr_file "$f" "$(printf '## Verdict\n\nVerdict: PASS')"; sr_no "$sd" "$f" qa sr-q-union "$SR_COUNT"; fi
  if cell sr-q-set; then sr_file "$f" "$(printf '## Verdict\nAPPROVED')"; sr_no "$sd" "$f" qa sr-q-set "$SR_SET"; fi
  if cell sr-cr-approved; then sr_file "$g" "$(printf '## Verdict\nAPPROVED')"; sr_ok "$sd" "$g" code-review sr-cr-approved APPROVED; fi
  if cell sr-cr-renamed; then sr_file "$g" "$(printf '## Result\nAPPROVED')"; sr_no "$sd" "$g" code-review sr-cr-renamed "matches Check 1's verdict pattern 0 time(s)"; fi
  if cell sr-q-fail; then sr_file "$f" "$(printf '## Verdict\nPASS')" '| AC4 | FAIL | a RED | none |'; sr_no "$sd" "$f" qa sr-q-fail "$FR_VERD"; fi
  if cell sr-q-fail-backed; then
    sr_file "$f" "$(printf '## Verdict\nNEEDS_REWORK')" '| AC4 | FAIL | a RED | none |' "$(printf '### Important (x)\n\n#### Q-1 AC4 has no committed RED\n\nBody.')"
    sr_ok "$sd" "$f" qa sr-q-fail-backed NEEDS_REWORK
  fi
  # D3: gate 3's own count and value rule, no stricter. A trailing parenthetical and a period read the
  # member; two matches reading ONE value are one verdict; a hyphen suffix is the whole token.
  if cell sr-q-paren; then sr_file "$f" 'Verdict: PASS (all ACs)'; sr_ok "$sd" "$f" qa sr-q-paren PASS; fi
  if cell sr-q-period; then sr_file "$f" "$(printf '## Verdict\n\nPASS.')"; sr_ok "$sd" "$f" qa sr-q-period PASS; fi
  if cell sr-q-twosame; then sr_file "$f" "$(printf '**Verdict:** PASS\n\nQA verdict: PASS')"; sr_ok "$sd" "$f" qa sr-q-twosame PASS; fi
  if cell sr-q-suffix; then sr_file "$f" 'Verdict: PASS-pending'; sr_no "$sd" "$f" qa sr-q-suffix "Check 1 reads 'PASS-pending'"; fi
  if cell sr-q-twodiff; then sr_file "$f" "$(printf '**Verdict:** PASS\n\nQA verdict: NEEDS_REWORK')"; sr_no "$sd" "$f" qa sr-q-twodiff "$SR_COUNT"; fi
  # N2 and N3 through the serial file's own table (one fail_gate for the merge and the serial check):
  # FAILED fires, under a `### Acceptance criteria` heading; AC-4.1 does not name AC-4; a `handover:`
  # line does not name its AC.
  if cell sr-q-failed; then sr_file "$f" "$(printf '## Verdict\nPASS')" '| AC4 | FAILED | a RED | none |' '' '### Acceptance criteria (per AC)'; sr_no "$sd" "$f" qa sr-q-failed "$FR_VERD"; fi
  if cell sr-q-dotted; then
    sr_file "$f" "$(printf '## Verdict\nNEEDS_REWORK')" '| AC-4 | FAIL | a RED | none |' "$(printf '### Important (x)\n\n#### Q-1 a gap\n\nAC-4.1 has no committed RED.')"
    sr_no "$sd" "$f" qa sr-q-dotted "$FR_ORPH AC-4"
  fi
  if cell sr-q-hoonly; then
    sr_file "$f" "$(printf '## Verdict\nNEEDS_REWORK')" '| AC4 | FAIL | a RED | none |' "$(printf '### Important (x)\n\n#### Q-1 a gap\nparts: 1\nhandover: AC4\n\nBody.')"
    sr_no "$sd" "$f" qa sr-q-hoonly "$FR_ORPH AC4"
  fi
  [ -z "$WHY" ]
}
# ---- CR1 (BL-769): a QA PASS waits for its canonical run. Serial cells, each refusal with its ALLOW twin
# one property apart. The record-only cells run --story/--range against CR_REPO, seeded below: a commit
# touching only records (CR_REC) and one touching a test file (CR_CODE), each over CR_BASE.
CR_NORUN="carries no 'Canonical run:' line"
CR_FILT="selects tests by name"
CR_FILE="names a file or test node"
CR_MARK="selects by marker"
CR_PATH="narrows the collection to the path"
CR_DESEL="deselects tests"
CR_GATE1="is not the story's gate-1 base"
CR_NOANC="is not an ancestor of"
CR_NORES="with no 'Canonical result:' line"
CR_UNFIN="says the run has not finished"
CR_NOCNT="carries no count"
CR_NOTRO="is not record-only for"
CR_NORNG="no --story and --range were given"
# BL-895's binding (merge-review-shards.sh STORY-BIND): any binding refusal, the row refusal, the index refusal.
CR_BIND="STORY-BIND: "
CR_BROW="is not a story the implementation view lists at"
CR_BIDX="is not story-1-2.md or story-1-2-*.md"
CR_BONE="is not the only story under that index"
CR_BDIG="is not story-2.md or story-2-*.md, or its slug opens with a digit"
CR_BNOANS="the implementation view gives no answer at"
CR_BNOIDX="its name carries no story index"
CR_BHIST="the implementation view named stories/story-1-1-x.md under that index between"
CR_BSHAL="is a shallow repository"
CR_BSDIR="is not in sprint 1's stories directory"
CR_BSPR="which is not the review's sprint"
CR_BNOSPR="its path carries no sprint"
# CR_REPO is consumer-shaped (BL-895): the stories sit in the schema's stories_dir for sprint 1, and the
# implementation view lists each story with a `status:` equal to the story's own at every commit. Each row
# names its `file:` because under `sprint: 1` the key's sprint-stripped stem (sprint-status.sh
# story_key_stem) drops BOTH `1` components of `story-1-1`, so a key-only row binds no file.
CR_REPO="$WORK/repo-cr"; CR_SDIR=_bmad-output/planning-artifacts/s1/stories; CR_STORY="$CR_SDIR/story-1-1-x.md"
CR_VIEW=_bmad-output/implementation-artifacts/sprint-status.yaml
cr_view() { # <story-1-1 status> [<story-1-2 status>] -> the implementation view; story-1-2's row only when given
  { printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: %s\n    file: stories/story-1-1-x.md\n' "$1"
    [ -z "${2:-}" ] || printf '  story-1-2:\n    status: %s\n    file: stories/story-1-2-y.md\n' "$2"; } > "$CR_REPO/$CR_VIEW"
}
mkdir -p "$CR_REPO/$CR_SDIR" "$CR_REPO/${CR_VIEW%/*}" "$CR_REPO/tests" "$CR_REPO/docs/reviews/s1" "$CR_REPO/test-results" \
  && G init -q "$CR_REPO" && printf -- '---\nstatus: ready-for-dev\n---\n# Story 1\n' > "$CR_REPO/$CR_STORY" && printf 'def test_a(): pass\n' > "$CR_REPO/tests/test_a.py" \
  && cr_view ready-for-dev && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m base || { echo "FIXTURE ERROR: the canonical-run repo was not seeded" >&2; exit 2; }
CR_BASE="$(G -C "$CR_REPO" rev-parse HEAD)"
printf -- '---\nstatus: review\n---\n# Story 1\nFull-collection run: none, record-only\n' > "$CR_REPO/$CR_STORY"; printf '# r\n' > "$CR_REPO/docs/reviews/s1/1-qa-validation.md"; printf '$ x\n' > "$CR_REPO/test-results/h.txt"; cr_view review
G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m rec || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CR_REC="$(G -C "$CR_REPO" rev-parse HEAD)"
printf 'def test_a(): assert 1\n' > "$CR_REPO/tests/test_a.py"
G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m code || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CR_CODE="$(G -C "$CR_REPO" rev-parse HEAD)"
# CR_P2: the rework after a NEEDS_REWORK with no run touches only the story. CR_CODE..CR_P2 is
# record-only; CR_BASE..CR_P2 is not. A seat passing the pass-1 frozen sha as base narrows the range.
printf -- '---\nstatus: review\n---\n# Story 1\nFull-collection run: `pytest -q`: 1 passed\n' > "$CR_REPO/$CR_STORY"
G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m rework || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CR_P2="$(G -C "$CR_REPO" rev-parse HEAD)"
# CR_EVIL: over CR_BASE, a record-only diff plus a collectable module under test-results/.
G -C "$CR_REPO" checkout -q -b evil "$CR_REC" && printf 'def test_evil():\n    assert False\n' > "$CR_REPO/test-results/test_evil.py" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m evil && CR_EVIL="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - || { echo "FIXTURE ERROR: the evil branch was not seeded" >&2; exit 2; }
# CR_LINK / CR_LINKF (BL-895 U1k, adversary 5a): over CR_REC, one commit adding docs/reviews/s9 as a SYMLINK to s1 (mode
# 120000), and its control one property apart, the same path as a regular file holding the same bytes (100644).
_crlh="$(G -C "$CR_REPO" symbolic-ref -q --short HEAD)" && G -C "$CR_REPO" checkout -q -b rlink "$CR_REC" && ln -s s1 "$CR_REPO/docs/reviews/s9" && G -C "$CR_REPO" add -A \
  && G -C "$CR_REPO" commit -q -m rlink && CR_LINK="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q -b rlinkf "$CR_REC" && printf 's1' > "$CR_REPO/docs/reviews/s9" && G -C "$CR_REPO" add -A \
  && G -C "$CR_REPO" commit -q -m rlinkf && CR_LINKF="$(G -C "$CR_REPO" rev-parse HEAD)" && G -C "$CR_REPO" checkout -q "$_crlh" \
  && [ "$(G -C "$CR_REPO" ls-tree "$CR_LINK" docs/reviews/s9 | cut -c1-6)" = 120000 ] \
  && [ "$(G -C "$CR_REPO" ls-tree "$CR_LINKF" docs/reviews/s9 | cut -c1-6)" = 100644 ] \
  || { echo "FIXTURE ERROR: the record-class symlink branches were not seeded" >&2; exit 2; }
# CR_NEWS: over CR_BASE, one commit adding a second story, story-1-2-y.md (status: review), and its view row
# story-1-2, so the story is absent at the base and a blob at the frozen sha: the created-after-base story
# story-base accepts. The row exists only on the `created` branch; the checked-out view never lists it.
CR_STORY2="$CR_SDIR/story-1-2-y.md"
G -C "$CR_REPO" checkout -q -b created "$CR_BASE" && printf -- '---\nstatus: review\n---\n# Story 2\nFull-collection run: none, record-only\n' > "$CR_REPO/$CR_STORY2" \
  && cr_view ready-for-dev review && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m created && CR_NEWS="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - || { echo "FIXTURE ERROR: the created-story branch was not seeded" >&2; exit 2; }
# CR_SEED (BL-895): over CR_REC (story-1-1 already `review`), one commit adding ONLY a review-like file whose name carries
# the index 1-4, story-1-4-notes.md, IN the sprint's stories directory (outside it the view's history refuses it first):
# CR_REC..CR_SEED is record-only, the file is absent at CR_REC and a blob at CR_SEED, and no other file under index 1-4
# exists, so only the sprint-status row tells it from a story (under index 1-1 the listed story-1-1-x.md would refuse it
# first). CR_BARE: over CR_BASE, a bare story-1-3.md and its view row (the resolver's exact-stem form), record-only for
# that story.
CR_SEEDF="$CR_SDIR/story-1-4-notes.md"; CR_STORY3="$CR_SDIR/story-1-3.md"
G -C "$CR_REPO" checkout -q -b seed "$CR_REC" && printf '# notes\n' > "$CR_REPO/$CR_SEEDF" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m seed && CR_SEED="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - || { echo "FIXTURE ERROR: the seed branch was not seeded" >&2; exit 2; }
G -C "$CR_REPO" checkout -q -b bare "$CR_BASE" && printf -- '---\nstatus: review\n---\n# Story 3\n' > "$CR_REPO/$CR_STORY3" \
  && cr_view ready-for-dev && printf '  story-1-3:\n    status: review\n    file: stories/story-1-3.md\n' >> "$CR_REPO/$CR_VIEW" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m bare && CR_BARE="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - || { echo "FIXTURE ERROR: the bare-story branch was not seeded" >&2; exit 2; }
# CR_RK, CR_RA (BL-895 B1): over CR_REC (story-1-1-x.md already `review`, story-base refuses it), a fresh story-1-1-z.md
# the view lists under another key, story-1-9 (K), or by repointing row story-1-1's file: to it (A). Both ranges change
# only z and the view, so only the one-story-per-index check refuses z: x is listed under index 1-1 at CR_REC.
# CR_TRUNC (BL-895 D1): over CR_BASE, story-2-1-y.md at review and its row, the ONLY file under index 2 or 2-1, so a review
# named 2-qa-validation.md is refused by the digit rule alone; 2-1-qa-validation.md is its ALLOW twin. CR_STORY4 is also
# cr-bind-sibling's story under the 1-2 review, an index under which nothing is listed.
CR_STORYZ="$CR_SDIR/story-1-1-z.md"; CR_STORY4="$CR_SDIR/story-2-1-y.md"
cr_z() { printf -- '---\nstatus: review\n---\n# Story Z\n' > "$CR_REPO/$CR_STORYZ"; }
G -C "$CR_REPO" checkout -q -b rk "$CR_REC" && cr_z && cr_view review \
  && printf '  story-1-9:\n    status: review\n    file: stories/story-1-1-z.md\n' >> "$CR_REPO/$CR_VIEW" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m rk && CR_RK="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - && G -C "$CR_REPO" checkout -q -b ra "$CR_REC" && cr_z \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-1-z.md\n' > "$CR_REPO/$CR_VIEW" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m ra && CR_RA="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - && G -C "$CR_REPO" checkout -q -b trunc "$CR_BASE" && printf -- '---\nstatus: review\n---\n# Story 2.1\n' > "$CR_REPO/$CR_STORY4" \
  && cr_view ready-for-dev && printf '  story-2-1:\n    status: review\n    file: stories/story-2-1-y.md\n' >> "$CR_REPO/$CR_VIEW" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m trunc && CR_TRUNC="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - || { echo "FIXTURE ERROR: the repoint or truncated-index branch was not seeded" >&2; exit 2; }
# BL-895 R1, THE LAUNDERED BASE. Over CR_REC (x listed at review), one record-only commit C hides x, and F adds z and repoints
# row story-1-1 to it: CR_LVD deletes the view, CR_LREN renames x out of the index (old-story-1-1-x.md, its row's file:
# unchanged), CR_LNS drops x's row's status:, CR_LDUP names x under a second key. Each C..F changes only z and the view, and
# the engine at 8473a476d accepted all four, reading each no-answer state as "nothing listed". CR_LET (R2): over CR_BASE,
# story-2-3a-q.md and its row, a letter-suffixed index the review-index grammar keeps. CR_LTR (A3b, graph s316's letter-led
# indices): over CR_BASE, story-B1-x.md and story-B2-y.md at review, each listed (story-1-5, story-1-6), and
# story-sprint-review-fix.md (graph s318's slug-named review), which no row lists.
# CR_XD, CR_XDN (BL-895 b1): over CR_REC, story-1-5-a.md at review and its row, plus a row story-1-6 whose declared file:
# names story-1-5-b.md in ANOTHER directory (../elsewhere/), with a status (XD) or without one (XDN). The one-story-per-index
# check refuses that entry; the view's history skips it as another sprint's, so these are the endpoint check's own subjects.
CR_STORY5="$CR_SDIR/story-1-5-a.md"
cr_home="$(G -C "$CR_REPO" symbolic-ref -q --short HEAD)" || { echo "FIXTURE ERROR: the canonical-run repo is on no branch" >&2; exit 2; }
cr_lc() { G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m "$1" && G -C "$CR_REPO" rev-parse HEAD; }
cr_zf() { mkdir -p "$CR_REPO/${CR_VIEW%/*}" && cr_z \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-1-z.md\n' > "$CR_REPO/$CR_VIEW" && cr_lc "$1"; }
G -C "$CR_REPO" checkout -q -b lvd "$CR_REC" && G -C "$CR_REPO" rm -q "$CR_VIEW" && CR_LVD="$(cr_lc lvd)" && CR_LVDF="$(cr_zf lvd-f)" \
  && G -C "$CR_REPO" checkout -q -b lren "$CR_REC" && G -C "$CR_REPO" mv "$CR_STORY" "$CR_SDIR/old-story-1-1-x.md" && CR_LREN="$(cr_lc lren)" && CR_LRENF="$(cr_zf lren-f)" \
  && G -C "$CR_REPO" checkout -q -b lns "$CR_REC" && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    file: stories/story-1-1-x.md\n' > "$CR_REPO/$CR_VIEW" \
  && CR_LNS="$(cr_lc lns)" && CR_LNSF="$(cr_zf lns-f)" \
  && G -C "$CR_REPO" checkout -q -b ldup "$CR_REC" && cr_view review && printf '  story-1-8:\n    status: review\n    file: stories/story-1-1-x.md\n' >> "$CR_REPO/$CR_VIEW" \
  && CR_LDUP="$(cr_lc ldup)" && CR_LDUPF="$(cr_zf ldup-f)" \
  && G -C "$CR_REPO" checkout -q -b lrd "$CR_REC" && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-2:\n    status: review\n    file: stories/story-1-2-y.md\n' > "$CR_REPO/$CR_VIEW" \
  && CR_LRD="$(cr_lc lrd)" && CR_LRDF="$(cr_zf lrd-f)" \
  && G -C "$CR_REPO" checkout -q -b lrdok "$CR_LRD" && printf -- '---\nstatus: review\n---\n# Story 2\n' > "$CR_REPO/$CR_STORY2" && CR_LRDOK="$(cr_lc lrdok)" \
  && G -C "$CR_REPO" checkout -q -b lrr "$CR_REC" && G -C "$CR_REPO" mv "$CR_STORY" "$CR_SDIR/old-story-1-1-x.md" \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/old-story-1-1-x.md\n' > "$CR_REPO/$CR_VIEW" \
  && CR_LRR="$(cr_lc lrr)" && CR_LRRF="$(cr_zf lrr-f)" \
  && G -C "$CR_REPO" checkout -q -b xd "$CR_REC" && printf -- '---\nstatus: review\n---\n# Story 1.5\n' > "$CR_REPO/$CR_STORY5" \
  && cr_view review && printf '  story-1-5:\n    status: review\n    file: stories/story-1-5-a.md\n  story-1-6:\n    status: review\n    file: ../elsewhere/story-1-5-b.md\n' >> "$CR_REPO/$CR_VIEW" \
  && CR_XD="$(cr_lc xd)" && G -C "$CR_REPO" checkout -q -b xdn "$CR_REC" && printf -- '---\nstatus: review\n---\n# Story 1.5\n' > "$CR_REPO/$CR_STORY5" \
  && cr_view review && printf '  story-1-5:\n    status: review\n    file: stories/story-1-5-a.md\n  story-1-6:\n    file: ../elsewhere/story-1-5-b.md\n' >> "$CR_REPO/$CR_VIEW" \
  && CR_XDN="$(cr_lc xdn)" \
  && G -C "$CR_REPO" checkout -q -b let "$CR_BASE" && printf -- '---\nstatus: review\n---\n# Story 2.3a\n' > "$CR_REPO/$CR_SDIR/story-2-3a-q.md" \
  && cr_view ready-for-dev && printf '  story-2-3a:\n    status: review\n    file: stories/story-2-3a-q.md\n' >> "$CR_REPO/$CR_VIEW" && CR_LET="$(cr_lc let)" \
  && G -C "$CR_REPO" checkout -q -b ltr "$CR_BASE" && printf -- '---\nstatus: review\n---\n# Story B1\n' > "$CR_REPO/$CR_SDIR/story-B1-x.md" \
  && printf -- '---\nstatus: review\n---\n# Story B2\n' > "$CR_REPO/$CR_SDIR/story-B2-y.md" && printf '# notes\n' > "$CR_REPO/$CR_SDIR/story-sprint-review-fix.md" \
  && cr_view ready-for-dev && printf '  story-1-5:\n    status: review\n    file: stories/story-B1-x.md\n  story-1-6:\n    status: review\n    file: stories/story-B2-y.md\n' >> "$CR_REPO/$CR_VIEW" \
  && CR_LTR="$(cr_lc ltr)" \
  && G -C "$CR_REPO" checkout -q "$cr_home" || { echo "FIXTURE ERROR: the laundered-base, letter-index or letter-led branch was not seeded" >&2; exit 2; }
_lrd="$(G -C "$CR_REPO" show "${CR_LRD}:$CR_VIEW")" || _lrd=""; _lrr="$(G -C "$CR_REPO" show "${CR_LRR}:$CR_VIEW")" || _lrr=""
[ "$(G -C "$CR_REPO" diff --name-only "$CR_LRD" "$CR_LRDOK")" = "$CR_STORY2" ] && [ -n "$_lrd" ] && ! grep -qF story-1-1 <<<"$_lrd" \
  && grep -qF 'file: stories/old-story-1-1-x.md' <<<"$_lrr" \
  || { echo "FIXTURE STALE: CR_LRD still names story-1-1, CR_LRD..CR_LRDOK changes more than story-1-2-y.md, or CR_LRR's row is not repointed" >&2; exit 2; }
for _l in "$CR_LVD:$CR_LVDF" "$CR_LREN:$CR_LRENF" "$CR_LNS:$CR_LNSF" "$CR_LDUP:$CR_LDUPF" "$CR_LRD:$CR_LRDF" "$CR_LRR:$CR_LRRF"; do
  [ "$(G -C "$CR_REPO" diff --name-only "${_l%%:*}" "${_l#*:}" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] \
    || { echo "FIXTURE STALE: a laundered range ${_l} does not change exactly the view and z" >&2; exit 2; }
done
_lns="$(G -C "$CR_REPO" show "${CR_LNS}:$CR_VIEW")" || _lns=""; _ldup="$(G -C "$CR_REPO" show "${CR_LDUP}:$CR_VIEW")" || _ldup=""
_ldn="$(grep -c 'story-1-1-x.md' <<<"$_ldup")" || _ldn=0
! G -C "$CR_REPO" cat-file -e "${CR_LVD}:$CR_VIEW" 2> /dev/null && ! G -C "$CR_REPO" cat-file -e "${CR_LREN}:$CR_STORY" 2> /dev/null \
  && [ -n "$_lns" ] && ! grep -q 'status: review' <<<"$_lns" && [ "$_ldn" = 2 ] \
  || { echo "FIXTURE STALE: a laundered base does not hide x the way its cell names" >&2; exit 2; }
[ "$(G -C "$CR_REPO" diff --name-only "$CR_REC" "$CR_RK" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_REC" "$CR_RA" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_BASE" "$CR_TRUNC" | tr '\n' ' ')" = "$CR_VIEW $CR_STORY4 " ] \
  || { echo "FIXTURE STALE: CR_REC..CR_RK, CR_REC..CR_RA or CR_BASE..CR_TRUNC does not change exactly the view and its story" >&2; exit 2; }
[ "$(G -C "$CR_REPO" diff --name-only "$CR_REC" "$CR_SEED")" = "$CR_SEEDF" ] && [ "$(G -C "$CR_REPO" cat-file -t "${CR_BARE}:$CR_STORY3")" = blob ] \
  || { echo "FIXTURE STALE: CR_REC..CR_SEED does not change only $CR_SEEDF, or $CR_STORY3 is no blob at CR_BARE" >&2; exit 2; }
! G -C "$CR_REPO" cat-file -e "${CR_BASE}:$CR_STORY2" 2> /dev/null && [ "$(G -C "$CR_REPO" cat-file -t "${CR_NEWS}:$CR_STORY2")" = blob ] \
  && [ "$(G -C "$CR_REPO" cat-file -t "${CR_CODE}:$CR_SDIR")" = tree ] && ! G -C "$CR_REPO" cat-file -e "${CR_CODE}:$CR_SDIR/typo.md" 2> /dev/null \
  && [ "$(G -C "$CR_REPO" cat-file -t "${CR_BASE}:$CR_VIEW")" = blob ] && ! grep -qF 'story-1-2' "$CR_REPO/$CR_VIEW" \
  || { echo "FIXTURE STALE: story-1-2 is not absent at CR_BASE and a blob at CR_NEWS, or the stories dir is no tree (or typo.md exists) at CR_CODE, or the view is untracked at CR_BASE or the checked-out view lists story-1-2" >&2; exit 2; }
# BL-895, THE HISTORY'S OWN TRUST. Each world sits over CR_LRD (x's row deleted by one record-only commit), so only the
# view's history names x, and each defeats a history read a different way:
#   CR_HM  (B1) HQ, over CR_LRD, adds z and repoints row story-1-1 to it, dated 2001; CR_HM merges it --no-ff into CR_LRD's
#               line, so a creation commit chosen by date is HQ and the walk starts past CR_LRD;
#   CR_HZ  (D1) over CR_LRD, z in zz/, a directory created in the range, its row repointed there;
#   CR_HS2      over CR_LRD, the view moved to sprint 2 and z in s2's stories directory, created in the range;
#   CR_HC, CR_HCOK (D2) over CR_LRD, the view rewritten CRLF (record-only), then story-1-2-y.md added: an ALLOW range;
#   CR_HR  (B3) over CR_REC, z under key story-1-9 and the view naming only it; in CR_REPL, a copy, a replace ref points
#               CR_BASE's and CR_REC's view blobs at CR_LRD's, which names no x;
#   CR_SHAL (B2) a copy whose .git/shallow names CR_LRD, so CR_LRD reads as a root.
#   CR_LRDZ, CR_LRDZF (B2, BL-904) over CR_LRD, z at ready-for-dev (no label, view unchanged), then z at review and row
#               story-1-1 repointed to it. z is a blob at the base, so story-base answers 0 and never reaches its own
#               shallow refusal: in CR_SHAL the view history's shallow refusal is the only guard (m-shallow-ok's subject).
#   CR_HS2OK    over CR_HS2, story-1-3-q.md in s2's stories directory and its row: sprint 2 at both ends, an ALLOW range;
CR_ZZ=zz/story-1-1-z.md; CR_S2Z="${CR_SDIR%/s1/stories}/s2/stories/story-1-1-z.md"; CR_S2Q="${CR_S2Z%/*}/story-1-3-q.md"
cr_v1() { printf 'sprint: %s\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: %s\n' "$1" "$2" > "$CR_REPO/$CR_VIEW"; }
G -C "$CR_REPO" checkout -q -b hq "$CR_LRD" && cr_z && cr_v1 1 stories/story-1-1-z.md \
  && CR_HQ="$(export GIT_COMMITTER_DATE=2001-01-01T00:00:00 GIT_AUTHOR_DATE=2001-01-01T00:00:00; cr_lc hq)" \
  && G -C "$CR_REPO" checkout -q -b hm "$CR_LRD" && G -C "$CR_REPO" merge -q --no-ff --no-edit hq && CR_HM="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q -b hz "$CR_LRD" && mkdir -p "$CR_REPO/zz" && printf -- '---\nstatus: review\n---\n# Story Z\n' > "$CR_REPO/$CR_ZZ" \
  && cr_v1 1 "../../$CR_ZZ" && CR_HZ="$(cr_lc hz)" \
  && G -C "$CR_REPO" checkout -q -b hs2 "$CR_LRD" && mkdir -p "$CR_REPO/${CR_S2Z%/*}" && printf -- '---\nstatus: review\n---\n# Story Z\n' > "$CR_REPO/$CR_S2Z" \
  && cr_v1 2 ../planning-artifacts/s2/stories/story-1-1-z.md && CR_HS2="$(cr_lc hs2)" \
  && printf -- '---\nstatus: review\n---\n# Story 1.3\n' > "$CR_REPO/$CR_S2Q" \
  && printf '  story-1-3:\n    status: review\n    file: ../planning-artifacts/s2/stories/story-1-3-q.md\n' >> "$CR_REPO/$CR_VIEW" && CR_HS2OK="$(cr_lc hs2ok)" \
  && G -C "$CR_REPO" checkout -q -b hc "$CR_LRD" && sed 's/$/\r/' "$CR_REPO/$CR_VIEW" > "$CR_REPO/$CR_VIEW.c" && mv "$CR_REPO/$CR_VIEW.c" "$CR_REPO/$CR_VIEW" \
  && CR_HC="$(cr_lc hc)" && printf -- '---\nstatus: review\n---\n# Story 2\n' > "$CR_REPO/$CR_STORY2" && CR_HCOK="$(cr_lc hcok)" \
  && G -C "$CR_REPO" checkout -q -b hr "$CR_REC" && cr_z \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-9:\n    status: review\n    file: stories/story-1-1-z.md\n' > "$CR_REPO/$CR_VIEW" && CR_HR="$(cr_lc hr)" \
  && G -C "$CR_REPO" checkout -q -b lrdz "$CR_LRD" && printf -- '---\nstatus: ready-for-dev\n---\n# Story Z\n' > "$CR_REPO/$CR_STORYZ" \
  && CR_LRDZ="$(cr_lc lrdz)" && CR_LRDZF="$(cr_zf lrdz-f)" \
  && G -C "$CR_REPO" checkout -q "$cr_home" || { echo "FIXTURE ERROR: the history-trust branches were not seeded" >&2; exit 2; }
CR_SHAL="$WORK/repo-cr-shallow"; CR_REPL="$WORK/repo-cr-replace"
cp -R "$CR_REPO" "$CR_SHAL" && printf '%s\n' "$CR_LRD" > "$CR_SHAL/.git/shallow" && cp -R "$CR_REPO" "$CR_REPL" \
  && _lrdv="$(G -C "$CR_REPL" rev-parse "${CR_LRD}:$CR_VIEW")" \
  && G -C "$CR_REPL" replace "$(G -C "$CR_REPL" rev-parse "${CR_BASE}:$CR_VIEW")" "$_lrdv" \
  && G -C "$CR_REPL" replace "$(G -C "$CR_REPL" rev-parse "${CR_REC}:$CR_VIEW")" "$_lrdv" \
  || { echo "FIXTURE ERROR: the shallow or replaced copy was not seeded" >&2; exit 2; }
_hcv="$(G -C "$CR_REPO" show "${CR_HC}:$CR_VIEW")" || _hcv=""; _hcr="$(grep -c $'\r$' <<<"$_hcv")" || _hcr=0
[ "$(G -C "$CR_REPO" log -1 --format=%cd --date=format:%Y "$CR_HQ")" = 2001 ] && [ "$(G -C "$CR_REPO" rev-parse "${CR_HM}^1")" = "$CR_LRD" ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_LRD" "$CR_HM" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_LRD" "$CR_HZ" | tr '\n' ' ')" = "$CR_VIEW $CR_ZZ " ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_LRD" "$CR_HS2" | tr '\n' ' ')" = "$CR_VIEW $CR_S2Z " ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_HS2" "$CR_HS2OK" | tr '\n' ' ')" = "$CR_VIEW $CR_S2Q " ] \
  && [ "$_hcr" -ge 3 ] && [ "$(G -C "$CR_REPO" diff --name-only "$CR_HC" "$CR_HCOK")" = "$CR_STORY2" ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_REC" "$CR_HR" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] \
  && _rpv="$(G -C "$CR_REPL" show "${CR_REC}:$CR_VIEW")" && _rpn="$(GIT_NO_REPLACE_OBJECTS=1 G -C "$CR_REPL" show "${CR_REC}:$CR_VIEW")" \
  && [ "$(G -C "$CR_SHAL" rev-parse --is-shallow-repository)" = true ] && ! grep -qF story-1-1-x.md <<<"$_rpv" \
  && _lzs="$(G -C "$CR_REPO" show "${CR_LRDZ}:$CR_STORYZ")" && grep -qx 'status: ready-for-dev' <<<"$_lzs" && ! grep -qF 'Full-collection run:' <<<"$_lzs" \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_LRD" "$CR_LRDZ")" = "$CR_STORYZ" ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_LRDZ" "$CR_LRDZF" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] \
  && grep -qF story-1-1-x.md <<<"$_rpn" \
  || { echo "FIXTURE STALE: a history-trust world (HQ/HM, HZ, HS2, HC/HCOK, HR, the shallow or replaced copy) does not have the shape its cell names" >&2; exit 2; }
# BL-895 U1h, THE REVIEW'S SPRINT. The sprint is <N> of the review's docs/reviews/s<N>/ path, never the view's.
#   CR_FR1/CR_FR1F (T1, one commit) over CR_REC: one record-only commit moves the view to sprint 2 AND drops x's row (a
#               faked roll), then z lands in s2's stories directory, created at CR_FR1F, so a walk keyed on the view's
#               sprint starts after the launder;
#   CR_FR2/CR_FR2F (T1, two commits) over CR_LRD (x's row already dropped in sprint 1), a second commit moves the sprint;
#   CR_FR3/CR_FR3F (T1c) as CR_FR1, with s2's stories directory created AT the base by a placeholder story-9-pad.md;
#   CR_SPF      over CR_BASE, story-1-3-q.md in sprint 1's directory and its row, with the view's `sprint:` moved to 2: only
#               the view-sprint check refuses it (the story is in stories_dir(1), and nothing else under 1-3 was named);
#   CR_SCF      over CR_LRD, z in q1/stories, the directory a schema override (CR_SCHQ, stories_dir q{sprint}) names;
#   CR_RL/CR_RLF (ALLOW) over CR_REC, a roll to sprint 6 creating s6/stories/story-1-1-n6.md and dropping sprint 1's
#               `stories/story-1-1-x.md` row (graph's older spelling); its review is docs/reviews/s6/1-1-*.md;
#   CR_RMD/CR_RMF (the intermediate-sprint launder) over CR_BASE: A lists bare story-1-1-m.md under sprint 4 before s4's
#               directory exists, B creates it, C moves the view to sprint 5 and plants s5/stories/story-1-1-m.md, D (the
#               base) is sprint 4 again with m's row gone, F adds z4: D's parent resolves m into s5's directory, so a
#               drop applied at every commit launders m; it is dropped only at the creation commit B;
#   CR_GWO      a SECOND repository, its history never naming x: its base lists story-1-2 only and its frozen adds z, for
#               a GIT_WORK_TREE leak from the seat's environment while the review file sits in CR_REPO.
CR_SPQ="$CR_SDIR/story-1-3-q.md"; CR_S2PAD="${CR_S2Z%/*}/story-9-pad.md"; CR_QZ="${CR_SDIR%/s1/stories}/q1/stories/story-1-1-z.md"
CR_S6N="${CR_SDIR%/s1/stories}/s6/stories/story-1-1-n6.md"; CR_S4="${CR_SDIR%/s1/stories}/s4/stories"; CR_S5="${CR_SDIR%/s1/stories}/s5/stories"
CR_S4Z="$CR_S4/story-1-1-z4.md"; CR_SCHQ="$WORK/schema-q.json"; CR_GWO="$WORK/repo-cr-gwt"
mkdir -p "$CR_REPO/docs/reviews/s2" "$CR_REPO/docs/reviews/s4" "$CR_REPO/docs/reviews/s6" \
  && sed 's#planning-artifacts/s{sprint}/stories#planning-artifacts/q{sprint}/stories#' "$SS_SCHEMA" > "$CR_SCHQ" \
  && cr_s2z() { mkdir -p "$CR_REPO/${CR_S2Z%/*}" && printf -- '---\nstatus: review\n---\n# Story Z\n' > "$CR_REPO/$CR_S2Z"; } \
  && cr_vs() { local s="$1"; shift; { printf 'sprint: %s\nstatus: in_progress\nstories:\n' "$s"; while [ "$#" -gt 1 ]; do printf '  %s:\n    status: review\n    file: %s\n' "$1" "$2"; shift 2; done; } > "$CR_REPO/$CR_VIEW"; } \
  && G -C "$CR_REPO" checkout -q -b fr1 "$CR_REC" && cr_vs 2 story-7 ../planning-artifacts/s1/stories/story-7-q.md && CR_FR1="$(cr_lc fr1)" \
  && cr_s2z && cr_vs 2 story-7 ../planning-artifacts/s1/stories/story-7-q.md story-1-1 ../planning-artifacts/s2/stories/story-1-1-z.md && CR_FR1F="$(cr_lc fr1-f)" \
  && G -C "$CR_REPO" checkout -q -b fr2 "$CR_LRD" && cr_vs 2 story-7 ../planning-artifacts/s1/stories/story-7-q.md && CR_FR2="$(cr_lc fr2)" \
  && cr_s2z && cr_vs 2 story-7 ../planning-artifacts/s1/stories/story-7-q.md story-1-1 ../planning-artifacts/s2/stories/story-1-1-z.md && CR_FR2F="$(cr_lc fr2-f)" \
  && G -C "$CR_REPO" checkout -q -b fr3 "$CR_REC" && cr_vs 1 story-1-1 ../planning-artifacts/s1/stories/story-1-1-x.md && cr_lc fr3-long > /dev/null \
  && mkdir -p "$CR_REPO/${CR_S2PAD%/*}" && printf -- '---\nstatus: ready-for-dev\n---\n# pad\n' > "$CR_REPO/$CR_S2PAD" \
  && cr_vs 2 story-7 ../planning-artifacts/s1/stories/story-7-q.md story-9 ../planning-artifacts/s2/stories/story-9-pad.md && CR_FR3="$(cr_lc fr3)" \
  && cr_s2z && cr_vs 2 story-7 ../planning-artifacts/s1/stories/story-7-q.md story-9 ../planning-artifacts/s2/stories/story-9-pad.md story-1-1 ../planning-artifacts/s2/stories/story-1-1-z.md \
  && CR_FR3F="$(cr_lc fr3-f)" \
  && G -C "$CR_REPO" checkout -q -b spf "$CR_BASE" && printf -- '---\nstatus: review\n---\n# Story 1.3\n' > "$CR_REPO/$CR_SPQ" \
  && cr_vs 2 story-1-1 ../planning-artifacts/s1/stories/story-1-1-x.md story-1-3 ../planning-artifacts/s1/stories/story-1-3-q.md && CR_SPF="$(cr_lc spf)" \
  && G -C "$CR_REPO" checkout -q -b scf "$CR_LRD" && mkdir -p "$CR_REPO/${CR_QZ%/*}" && printf -- '---\nstatus: review\n---\n# Story Z\n' > "$CR_REPO/$CR_QZ" \
  && cr_vs 1 story-1-2 stories/story-1-2-y.md story-1-1 ../planning-artifacts/q1/stories/story-1-1-z.md && CR_SCF="$(cr_lc scf)" \
  && G -C "$CR_REPO" checkout -q -b rl "$CR_REC" && mkdir -p "$CR_REPO/${CR_S6N%/*}" && printf -- '---\nstatus: ready-for-dev\n---\n# Story N6\n' > "$CR_REPO/$CR_S6N" \
  && cr_vs 6 story-1-1 ../planning-artifacts/s6/stories/story-1-1-n6.md && CR_RL="$(cr_lc rl)" \
  && printf -- '---\nstatus: review\n---\n# Story N6\n' > "$CR_REPO/$CR_S6N" && CR_RLF="$(cr_lc rl-f)" \
  && G -C "$CR_REPO" checkout -q -b rm "$CR_BASE" && cr_vs 4 story-1-1 story-1-1-m.md story-1-2 story-1-2-n.md && cr_lc rm-a > /dev/null \
  && mkdir -p "$CR_REPO/$CR_S4" "$CR_REPO/$CR_S5" && printf -- '---\nstatus: review\n---\n# M\n' > "$CR_REPO/$CR_S4/story-1-1-m.md" && CR_RMB="$(cr_lc rm-b)" \
  && printf -- '---\nstatus: review\n---\n# M\n' > "$CR_REPO/$CR_S5/story-1-1-m.md" && cr_vs 5 story-1-1 story-1-1-m.md story-1-2 story-1-2-n.md && cr_lc rm-c > /dev/null \
  && cr_vs 4 story-1-2 story-1-2-n.md && CR_RMD="$(cr_lc rm-d)" \
  && printf -- '---\nstatus: review\n---\n# Z4\n' > "$CR_REPO/$CR_S4Z" && cr_vs 4 story-1-2 story-1-2-n.md story-1-1 story-1-1-z4.md && CR_RMF="$(cr_lc rm-f)" \
  && G -C "$CR_REPO" checkout -q "$cr_home" \
  && mkdir -p "$CR_GWO/$CR_SDIR" "$CR_GWO/${CR_VIEW%/*}" && G init -q "$CR_GWO" \
  && printf -- '---\nstatus: review\n---\n# Story 2\n' > "$CR_GWO/$CR_STORY2" \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-2:\n    status: review\n    file: stories/story-1-2-y.md\n' > "$CR_GWO/$CR_VIEW" \
  && G -C "$CR_GWO" add -A && G -C "$CR_GWO" commit -q -m base && CR_GWB="$(G -C "$CR_GWO" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# Story Z\n' > "$CR_GWO/$CR_STORYZ" \
  && printf '  story-1-1:\n    status: review\n    file: stories/story-1-1-z.md\n' >> "$CR_GWO/$CR_VIEW" \
  && G -C "$CR_GWO" add -A && G -C "$CR_GWO" commit -q -m f && CR_GWF="$(G -C "$CR_GWO" rev-parse HEAD)" \
  || { echo "FIXTURE ERROR: the review-sprint, schema, roll or GIT_WORK_TREE worlds were not seeded" >&2; exit 2; }
_crsp() { G -C "$CR_REPO" show "$1:$CR_VIEW" | sed -n 's/^sprint:[[:space:]]*//p'; }
for _l in "$CR_FR1:$CR_FR1F" "$CR_FR2:$CR_FR2F" "$CR_FR3:$CR_FR3F"; do
  [ "$(_crsp "${_l%%:*}")" = 2 ] && [ "$(_crsp "${_l#*:}")" = 2 ] \
    && [ "$(G -C "$CR_REPO" diff --name-only "${_l%%:*}" "${_l#*:}" | tr '\n' ' ')" = "$CR_VIEW $CR_S2Z " ] \
    && _crv="$(G -C "$CR_REPO" show "${_l%%:*}:$CR_VIEW")" && ! grep -qF story-1-1-x.md <<<"$_crv" \
    || { echo "FIXTURE STALE: a faked-roll range ${_l} is not sprint 2 at both ends changing only the view and z, or its base still names x" >&2; exit 2; }
done
G -C "$CR_REPO" cat-file -e "${CR_FR3}:$CR_S2PAD" 2> /dev/null && ! G -C "$CR_REPO" cat-file -e "${CR_FR1}:${CR_S2Z%/*}" 2> /dev/null \
  && [ "$(_crsp "$CR_FR2^")" = 1 ] && [ "$(_crsp "$CR_SPF")" = 2 ] && [ "$(_crsp "$CR_RL^")" = 1 ] && [ "$(_crsp "$CR_RL")" = 6 ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_BASE" "$CR_SPF" | tr '\n' ' ')" = "$CR_VIEW $CR_SPQ " ] \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_LRD" "$CR_SCF" | tr '\n' ' ')" = "$CR_VIEW $CR_QZ " ] && grep -qF 'q{sprint}' "$CR_SCHQ" \
  && _crv="$(G -C "$CR_REPO" show "${CR_RL}^:$CR_VIEW")" && grep -qxF '    file: stories/story-1-1-x.md' <<<"$_crv" \
  && [ "$(G -C "$CR_REPO" diff --name-only "$CR_RL" "$CR_RLF")" = "$CR_S6N" ] \
  && [ "$(_crsp "$CR_RMD^")" = 5 ] && [ "$(_crsp "$CR_RMD")" = 4 ] && ! G -C "$CR_REPO" cat-file -e "${CR_RMB}^:$CR_S4" 2> /dev/null \
  && G -C "$CR_REPO" cat-file -e "${CR_RMD}^:$CR_S5/story-1-1-m.md" && [ "$(G -C "$CR_REPO" diff --name-only "$CR_RMD" "$CR_RMF" | tr '\n' ' ')" = "$CR_VIEW $CR_S4Z " ] \
  && [ "$(G -C "$CR_GWO" diff --name-only "$CR_GWB" "$CR_GWF" | tr '\n' ' ')" = "$CR_VIEW $CR_STORYZ " ] && ! G -C "$CR_REPO" cat-file -e "${CR_GWF}^{commit}" 2> /dev/null \
  || { echo "FIXTURE STALE: a review-sprint, schema, roll, intermediate-sprint or GIT_WORK_TREE world does not have the shape its cell names" >&2; exit 2; }
# PROJ_CRS: a serial root whose qa.md predates the label (the LEGACY branch of --check-serial), and a git repository of
# its own, so a review written inside it is checked against that same qa.md (cr-serial-legacy, the legitimate LEGACY).
PROJ_CRS="$WORK/proj-crs"
mkdir -p "$PROJ_CRS/core/skills/ai-dlc/steps" "$PROJ_CRS/core/team-roles" "$PROJ_CRS/docs/reviews/s1" && G init -q "$PROJ_CRS" \
  && cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$PROJ_CRS/core/skills/ai-dlc/steps/" \
  && grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$PROJ_CRS/core/team-roles/qa.md" || { echo "FIXTURE ERROR: the legacy serial root was not seeded" >&2; exit 2; }
_crs0="$(grep -cF 'column-0 `Canonical run:`' "$PROJ_CRS/core/team-roles/qa.md")" || _crs0=0
[ "$_crs0" = 0 ] || { echo "FIXTURE STALE: the legacy serial root still carries the label" >&2; exit 2; }
# ---- AD (BL-790): THE ADVISOR LINE's era. The sentinel is read from the subject's own files; each
# legacy role file is the subject's with every line carrying it removed, the sentinel-less world the
# reference consumer runs from pull step 3 until the reconcile merge.
AD_SENT='column-0 `advisor:`'
AD_QS="$(grep -cF "$AD_SENT" "$QA_MD")" || AD_QS=0
AD_CS="$(grep -cF "$AD_SENT" "$ROLE_MD")" || AD_CS=0
[ "$AD_QS" -ge 1 ] && [ "$AD_CS" -ge 1 ] \
  || { echo "FIXTURE STALE: qa.md ($AD_QS) or code-reviewer.md ($AD_CS) carries no '$AD_SENT' on one line; every advisor world would be LEGACY" >&2; exit 2; }
AD_LEGQ="$WORK/ad-legacy-qa.md"; AD_LEGC="$WORK/ad-legacy-code-reviewer.md"
grep -vF "$AD_SENT" "$QA_MD" > "$AD_LEGQ"; grep -vF "$AD_SENT" "$ROLE_MD" > "$AD_LEGC"
# PROJ_ADL: a serial root whose two role files lack the advisor sentinel (and keep the canonical one, so
# only the advisor era moves). PROJ_CRS lacks the canonical sentinel and keeps the advisor one.
PROJ_ADL="$WORK/proj-adl"
mkdir -p "$PROJ_ADL/core/skills/ai-dlc/steps" "$PROJ_ADL/core/team-roles" \
  && cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$PROJ_ADL/core/skills/ai-dlc/steps/" \
  && cp "$AD_LEGQ" "$PROJ_ADL/core/team-roles/qa.md" && cp "$AD_LEGC" "$PROJ_ADL/core/team-roles/code-reviewer.md" \
  || { echo "FIXTURE ERROR: the advisor-legacy serial root was not seeded" >&2; exit 2; }
_ad0="$(cat "$PROJ_ADL/core/team-roles/qa.md" "$PROJ_ADL/core/team-roles/code-reviewer.md" | grep -cF "$AD_SENT")" || _ad0=0
_ad1="$(grep -cF 'column-0 `Canonical run:`' "$PROJ_ADL/core/team-roles/qa.md")" || _ad1=0
[ "$_ad0" = 0 ] && [ "$_ad1" = 1 ] || { echo "FIXTURE STALE: the advisor-legacy root carries the sentinel ($_ad0) or lost the canonical one ($_ad1)" >&2; exit 2; }
# The frozen trees, B's six files over a base that commits both role files at the consumer path:
#   ADP  the sentinel at the frozen sha (the post-reconcile world)
#   ADL  no sentinel at the frozen sha
#   ADA  lead world (a): no sentinel at the frozen sha, the NEW role files written over them on disk after
#        the freeze (the reconcile merged mid-sprint), shards written without the line
#   ADB  lead world (b): the sentinel at the frozen sha, the OLD role files on disk
#   ADU  the untracked world: no role file committed, the NEW ones on disk only
#   ADUL the untracked world over OLD on-disk role files
ad_repo() { # <dir> <committed: new|old|none> <on disk after freeze: new|old|same>
  local r="$1" q c f
  new_repo "$r" old || return 1
  case "$2" in
    new) q="$QA_MD"; c="$ROLE_MD" ;;
    old) q="$AD_LEGQ"; c="$AD_LEGC" ;;
    none) q=""; c="" ;;
  esac
  if [ -n "$q" ]; then
    mkdir -p "$r/.claude/team-roles" && cp "$q" "$r/.claude/team-roles/qa.md" && cp "$c" "$r/.claude/team-roles/code-reviewer.md" \
      && G -C "$r" add -A && G -C "$r" commit -q --amend -m base || return 1
  fi
  for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$r/$f" 5 "$f"; done
  G -C "$r" add -A && G -C "$r" commit -q -m frozen || return 1
  case "$3" in
    new) mkdir -p "$r/.claude/team-roles" && cp "$QA_MD" "$r/.claude/team-roles/qa.md" && cp "$ROLE_MD" "$r/.claude/team-roles/code-reviewer.md" ;;
    old) mkdir -p "$r/.claude/team-roles" && cp "$AD_LEGQ" "$r/.claude/team-roles/qa.md" && cp "$AD_LEGC" "$r/.claude/team-roles/code-reviewer.md" ;;
  esac
}
REPO_ADP="$WORK/repo-adp"; REPO_ADL="$WORK/repo-adl"; REPO_ADA="$WORK/repo-ada"; REPO_ADB="$WORK/repo-adb"
REPO_ADU="$WORK/repo-adu"; REPO_ADUL="$WORK/repo-adul"
ad_repo "$REPO_ADP" new same && ad_repo "$REPO_ADL" old same && ad_repo "$REPO_ADA" old new \
  && ad_repo "$REPO_ADB" new old && ad_repo "$REPO_ADU" none new && ad_repo "$REPO_ADUL" none old \
  || { echo "FIXTURE ERROR: the advisor-era repositories were not seeded" >&2; exit 2; }
# Each world's refs, and its own control: the committed copy's sentinel count and the on-disk copy's.
ad_at() { # <repo> <role basename> -> "<count at HEAD, or u when untracked> <count on disk, or u>"
  local a b
  if G -C "$1" cat-file -e "HEAD:.claude/team-roles/$2" 2>/dev/null; then
    a="$(G -C "$1" show "HEAD:.claude/team-roles/$2" | grep -cF "$AD_SENT")" || a=0; else a=u; fi
  if [ -f "$1/.claude/team-roles/$2" ]; then b="$(grep -cF "$AD_SENT" "$1/.claude/team-roles/$2")" || b=0; else b=u; fi
  printf '%s %s' "$a" "$(echo "$b" | sed 's/^[1-9][0-9]*$/1/')"
}
for _p in "ADP:1 1" "ADL:0 0" "ADA:0 1" "ADB:1 0" "ADU:u 1" "ADUL:u 0"; do
  eval "_r=\$REPO_${_p%%:*}"
  for _f in qa.md code-reviewer.md; do
    _g="$(ad_at "$_r" "$_f" | sed 's/^[1-9][0-9]* /1 /')"
    [ "$_g" = "${_p#*:}" ] || { echo "FIXTURE STALE: advisor world ${_p%%:*} $_f reads '$_g', want '${_p#*:}' (frozen sha, on disk)" >&2; exit 2; }
  done
done
AD_ABS="carries no column-0 'advisor:' line"
AD_TWO="carries 2 'advisor:' lines outside a fence"
AD_VAL="'advisor: maybe' is not called or unavailable"
AD_MAL="is a malformed advisor line"
AD_NEAR="not the remediator's bulleted '- advisor: called'"
AD_UNR="cannot be read at the frozen sha"
AD_HELD="prescribes it"
ad_leg() { printf 'LEGACY: advisor: line not checked: %s prescribes no %s label' "$1" "$AD_SENT"; } # <path as named>
# D1/D2 seeds. AD_FENCE: a fenced block quoting a bad value above the bare line, which only the fence
# skip keeps from counting. AD_PROSE: graph s319's own prose form (4-3-code-review.md, read-only), which
# only the lower-case-only label keeps from reading as the line or as a malformed one.
AD_FENCE="$(printf '```text\nadvisor: maybe\n```\nadvisor: called')"
AD_PROSE='Advisor: I made one attempt before writing. It returned rate-limited.'
# ad_var <shard dir> <clean copy> <variant>: every shard back to the clean copy (each carries
# `advisor: called`), then that line rewritten: ABSENT deletes it, TWO doubles it, anything else
# replaces it with the variant's text verbatim (a CR rides in ENVIRON, never through awk -v).
ad_var() {
  local f
  cs_reset "$1" "$2"
  for f in "$1"/*.md; do
    AD_V="$3" awk '$0 == "advisor: called" { v = ENVIRON["AD_V"]
        if (v == "ABSENT") next; if (v == "TWO") { print; print; next }; print v; next } { print }' "$f" > "$f.x" \
      && mv "$f.x" "$f" || return 1
  done
}
# ad_world <script-dir> <gate> <repo tag> -> AD_D (shard dir), AD_C (its clean copy), AD_S (frozen sha),
# AD_R (the repo); every shard carries `advisor: called`.
ad_world() {
  local sd="$1" g="$2" b SHARD_SHA sfx v
  eval "AD_R=\$REPO_$3"
  b="$(G -C "$AD_R" rev-parse HEAD~1)"; AD_S="$(G -C "$AD_R" rev-parse HEAD)"; SHARD_SHA="$AD_S"
  if [ "$g" = qa ]; then sfx=qa-validation; v=PASS; else sfx=code-review; v=APPROVED; fi
  AD_D="$(kworld "$sd" "$AD_R" "$b" "$AD_S" 3 "$sfx" "$v" "$g")" && [ -d "$AD_D" ] || return 1
  AD_C="$(dirname "$AD_D")/clean"; mkdir "$AD_C" && cp "$AD_D"/*.md "$AD_C"/
}
ad_out() { if [ "$2" = qa ]; then qout "$1"; else out_of "$1"; fi; }
ad_ok() { # <script-dir> <gate> <case> <variant> [LEGACY line, by value]: merges, the LEGACY line exactly when named
  local o; o="$(ad_out "$AD_D" "$2")"
  ad_var "$AD_D" "$AD_C" "$4" || { WHY="$WHY $3{the variant did not apply}"; return; }
  if [ "${AD_E2E:-0}" != 1 ] || [ "$1" != "$SRCDIR" ]; then
    # (a mutant drive, script dir != SRCDIR, always takes this path: the mutants sit in check_shard/adv_gate, which --check-shard reaches)
    # one shard's gate (adv_gate, the function the merge calls per shard): --check-shard on shard 1, the first shard read
    run_check "$1" "$AD_D" "$2" "$AD_D/1.md"
    if [ -n "${5:-}" ]; then
      [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK:" && [ "$(grep -c '^LEGACY: advisor:' "$CO")" = 1 ] && grep -qxF -- "$5" "$CO" \
        || WHY="$WHY $3{rc=$CRC $(head -2 "$CO" | tr '\n' ' ')}"
    else
      [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK:" && ! has "$CO" "LEGACY: advisor:" || WHY="$WHY $3{rc=$CRC $(head -2 "$CO" | tr '\n' ' ')}"
    fi
    return
  fi
  run_mg "$1" "$AD_D" "$2" "$o"
  if [ -n "${5:-}" ]; then
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$(grep -c '^LEGACY: advisor:' "$MO")" = 1 ] && grep -qxF -- "$5" "$MO" \
      || WHY="$WHY $3{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
  else
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY: advisor:" || WHY="$WHY $3{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
  fi
  rm -f "$o"
}
ad_no() { # <script-dir> <gate> <case> <variant> <token> [second token]: REFUSED [owner: 1], the first shard read
  local o; o="$(ad_out "$AD_D" "$2")"
  ad_var "$AD_D" "$AD_C" "$4" || { WHY="$WHY $3{the variant did not apply}"; return; }
  if [ "${AD_E2E:-0}" != 1 ] || [ "$1" != "$SRCDIR" ]; then
    run_check "$1" "$AD_D" "$2" "$AD_D/1.md"
    chk_refused "$5" "${6:-}" && owner_in "$CO" 1 && ! has "$CO" "LEGACY: advisor:" || WHY="$WHY $3{rc=$CRC $(reline "$CO")}"
    return
  fi
  run_mg "$1" "$AD_D" "$2" "$o"
  refused_at "$5" "$o" && owner_in "$MO" 1 && { [ -z "${6:-}" ] || has "$MO" "$6"; } && ! has "$MO" "LEGACY: advisor:" \
    || WHY="$WHY $3{rc=$RC $(reline "$MO")}"
  rm -f "$o"
}
# AD1 (BL-790): THE ADVISOR LINE through the merge, one gate per call. Cells are named ad-<q|c>-<case>.
p_adv_gate() { # <script-dir> <gate>
  local sd="$1" g="$2" x CR; CR="$(printf '\r')"
  if [ "$g" = qa ]; then x=q; else x=c; fi
  WHY=""
  if cs_sel "ad-$x-present-absent" || cs_sel "ad-$x-called" || cs_sel "ad-$x-unavailable" || cs_sel "ad-$x-cr" \
     || cs_sel "ad-$x-maybe" || cs_sel "ad-$x-two" || cs_sel "ad-$x-bullet" || cs_sel "ad-$x-deco" \
     || cs_sel "ad-$x-fence" || cs_sel "ad-$x-prose"; then
    ad_world "$sd" "$g" ADP || { WHY="the sentinel world was not built"; return 1; }
    if cell "ad-$x-present-absent"; then AD_E2E=1 ad_no "$sd" "$g" "ad-$x-present-absent" ABSENT "$AD_ABS" "$AD_HELD"; fi
    if cell "ad-$x-called"; then AD_E2E=1 ad_ok "$sd" "$g" "ad-$x-called" 'advisor: called'; fi
    if cell "ad-$x-unavailable"; then ad_ok "$sd" "$g" "ad-$x-unavailable" 'advisor: unavailable'; fi
    if cell "ad-$x-cr"; then ad_ok "$sd" "$g" "ad-$x-cr" "advisor: unavailable  $CR"; fi
    if cell "ad-$x-maybe"; then ad_no "$sd" "$g" "ad-$x-maybe" 'advisor: maybe' "$AD_VAL"; fi
    if cell "ad-$x-two"; then ad_no "$sd" "$g" "ad-$x-two" TWO "$AD_TWO"; fi
    if cell "ad-$x-bullet"; then ad_no "$sd" "$g" "ad-$x-bullet" '- advisor: called' "$AD_MAL" "$AD_NEAR"; fi
    if cell "ad-$x-deco"; then ad_no "$sd" "$g" "ad-$x-deco" '**advisor:** called' "$AD_MAL"; fi
    if cell "ad-$x-fence"; then ad_ok "$sd" "$g" "ad-$x-fence" "$AD_FENCE"; fi
    if cell "ad-$x-prose"; then ad_ok "$sd" "$g" "ad-$x-prose" "$(printf '%s\nadvisor: called' "$AD_PROSE")"; fi
  fi
  # The era: the role file the shards were written under, read at the frozen sha.
  if cs_sel "ad-$x-legacy-absent" || cs_sel "ad-$x-legacy-prose"; then
    ad_world "$sd" "$g" ADL || { WHY="$WHY the legacy world was not built"; return 1; }
    if cell "ad-$x-legacy-absent"; then
      AD_E2E=1 ad_ok "$sd" "$g" "ad-$x-legacy-absent" ABSENT "$(ad_leg ".claude/team-roles/$(ad_role "$g") at $AD_S")"
      ad_no "$sd" "$g" "ad-$x-legacy-absent" 'advisor: maybe' "$AD_VAL"; fi
    if cell "ad-$x-legacy-prose"; then
      ad_ok "$sd" "$g" "ad-$x-legacy-prose" "$AD_PROSE" "$(ad_leg ".claude/team-roles/$(ad_role "$g") at $AD_S")"; fi
  fi
  if cell "ad-$x-unreadable-absent"; then ad_world "$sd" "$g" B || { WHY="$WHY the unreadable world was not built"; return 1; }
    ad_no "$sd" "$g" "ad-$x-unreadable-absent" ABSENT "$AD_ABS" "$AD_UNR"; fi
  # Lead world (a): frozen before the reconcile, the new role file on disk; world (b) the reverse.
  if cell "ad-$x-world-a"; then ad_world "$sd" "$g" ADA || { WHY="$WHY world (a) was not built"; return 1; }
    ad_ok "$sd" "$g" "ad-$x-world-a" ABSENT "$(ad_leg ".claude/team-roles/$(ad_role "$g") at $AD_S")"; fi
  if cell "ad-$x-world-b"; then ad_world "$sd" "$g" ADB || { WHY="$WHY world (b) was not built"; return 1; }
    ad_no "$sd" "$g" "ad-$x-world-b" ABSENT "$AD_ABS" ".claude/team-roles/$(ad_role "$g") at $AD_S prescribes it"; fi
  # Untracked at the frozen sha: the on-disk copy decides; with the sentinel the absence is REFUSED
  # naming the fallback and its remedy, without it LEGACY naming the on-disk path.
  if cell "ad-$x-untracked-new"; then ad_world "$sd" "$g" ADU || { WHY="$WHY the untracked world was not built"; return 1; }
    ad_no "$sd" "$g" "ad-$x-untracked-new" ABSENT "$AD_ABS" \
      "$(ad_role "$g") is untracked at $AD_S, read on disk at $AD_R/.claude/team-roles/$(ad_role "$g"), which prescribes it. The on-disk copy may postdate the shards: commit .claude/team-roles/ so the frozen sha decides, or write the line"; fi
  if cell "ad-$x-untracked-old"; then ad_world "$sd" "$g" ADUL || { WHY="$WHY the untracked-old world was not built"; return 1; }
    ad_ok "$sd" "$g" "ad-$x-untracked-old" ABSENT "$(ad_leg "$AD_R/.claude/team-roles/$(ad_role "$g") (on disk, untracked at $AD_S)")"; fi
  [ -z "$WHY" ]
}
ad_role() { if [ "$1" = qa ]; then printf 'qa.md'; else printf 'code-reviewer.md'; fi; }
p_adv_qa() { p_adv_gate "$1" qa; }
p_adv_cr() { p_adv_gate "$1" code-review; }
# AD2 (BL-790): --check-serial, both gates, keyed on the INSTALLED role file (PROJ: the sentinel;
# PROJ_ADL: none). Every cell writes the whole file it reads.
ad_srun() { # <script-dir> <file> <gate> <root> -> SRC, $CO
  ip_run -e "AI_DLC_PROJECT_ROOT=$4" "$1/merge-review-shards.sh" mrs_main --check-serial "$2" --gate "$3" > "$CO" 2>&1 < /dev/null; SRC=$?
}
ad_sok() { # <script-dir> <file> <gate> <case> <line text, empty for none>
  SHARD_ADV="$5" sr_file "$2" "$AD_VB"; ad_srun "$1" "$2" "$3" "$PROJ"
  [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: $2" && ! has "$CO" "LEGACY: advisor:" || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
ad_sno() { # <script-dir> <file> <gate> <case> <line text, empty for none> <token>
  SHARD_ADV="$5" sr_file "$2" "$AD_VB"; ad_srun "$1" "$2" "$3" "$PROJ"
  [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$6" && has "$CO" "$SR_OWN" && ! has "$CO" "SERIAL-OK" \
    || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
p_adv_serial() {
  local sd="$1" g x f CR; CR="$(printf '\r')"
  WHY=""
  for g in qa code-review; do
    if [ "$g" = qa ]; then x=q; AD_VB="$(printf '## Verdict\nPASS')"; f="$WORK/ads-1-qa-validation.md"
    else x=c; AD_VB="$(printf '## Verdict\nAPPROVED')"; f="$WORK/ads-1-code-review.md"; fi
    if cell "ad-s$x-absent"; then ad_sno "$sd" "$f" "$g" "ad-s$x-absent" '' "$AD_ABS"; fi
    if cell "ad-s$x-called"; then ad_sok "$sd" "$f" "$g" "ad-s$x-called" 'advisor: called'; fi
    if cell "ad-s$x-unavailable"; then ad_sok "$sd" "$f" "$g" "ad-s$x-unavailable" 'advisor: unavailable'; fi
    if cell "ad-s$x-cr"; then ad_sok "$sd" "$f" "$g" "ad-s$x-cr" "advisor: unavailable $CR"; fi
    if cell "ad-s$x-maybe"; then ad_sno "$sd" "$f" "$g" "ad-s$x-maybe" 'advisor: maybe' "$AD_VAL"; fi
    if cell "ad-s$x-two"; then ad_sno "$sd" "$f" "$g" "ad-s$x-two" "$(printf 'advisor: called\nadvisor: called')" "$AD_TWO"; fi
    if cell "ad-s$x-bullet"; then ad_sno "$sd" "$f" "$g" "ad-s$x-bullet" '- advisor: called' "$AD_NEAR"; fi
    if cell "ad-s$x-fence"; then ad_sok "$sd" "$f" "$g" "ad-s$x-fence" "$AD_FENCE"; fi
    if cell "ad-s$x-legacy-absent"; then
      SHARD_ADV='' sr_file "$f" "$AD_VB"; ad_srun "$sd" "$f" "$g" "$PROJ_ADL"
      [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: $f" && grep -qxF -- "$(ad_leg "$PROJ_ADL/core/team-roles/$(ad_role "$g")")" "$CO" \
        || WHY="$WHY ad-s$x-legacy-absent{rc=$SRC $(head -2 "$CO" | tr '\n' ' ')}"
    fi
  done
  [ -z "$WHY" ]
}
cr_run() { # <script-dir> <file> [extra args...] -> SRC, $CO (CR_ROOT overrides the project root)
  local sd="$1" f="$2"; shift 2
  ip_run -e "AI_DLC_PROJECT_ROOT=${CR_ROOT:-$PROJ}" ${CR_ENV:+-e "$CR_ENV"} "$sd/merge-review-shards.sh" mrs_main --check-serial "$f" --gate qa "$@" > "$CO" 2>&1 < /dev/null; SRC=$?
}
cr_ok() { local sd="$1" f="$2" c="$3"; shift 3; cr_run "$sd" "$f" "$@"
  [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:" || WHY="$WHY $c{rc=$SRC $(head -1 "$CO")}"; }
cr_no() { local sd="$1" f="$2" c="$3" t="$4"; shift 4; cr_run "$sd" "$f" "$@"
  [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$t" && has "$CO" "$SR_OWN" && ! has "$CO" "SERIAL-OK" \
    || WHY="$WHY $c{rc=$SRC $(head -1 "$CO")}"; }
p_canon() {
  local sd="$1" f="$CR_REPO/docs/reviews/s1/1-1-qa-validation.md" f2="$CR_REPO/docs/reviews/s1/1-2-qa-validation.md" f3="$CR_REPO/docs/reviews/s1/1-3-qa-validation.md" f2p="$CR_REPO/docs/reviews/s1/1-2-qa-validation-p2.md" f4="$CR_REPO/docs/reviews/s1/1-4-qa-validation.md" ft="$CR_REPO/docs/reviews/s1/2-qa-validation.md" ft2="$CR_REPO/docs/reviews/s1/2-1-qa-validation.md" fl="$CR_REPO/docs/reviews/s1/1-1-z-qa-validation.md" fa="$CR_REPO/docs/reviews/s1/2-3a-qa-validation.md" f5="$CR_REPO/docs/reviews/s1/1-5-qa-validation.md" fsh="$CR_SHAL/docs/reviews/s1/1-1-qa-validation.md" frp="$CR_REPL/docs/reviews/s1/1-1-qa-validation.md" fs2="$CR_REPO/docs/reviews/s2/1-3-qa-validation.md" fs4="$CR_REPO/docs/reviews/s4/1-1-qa-validation.md" fs6="$CR_REPO/docs/reviews/s6/1-1-qa-validation.md" fnp="$CR_REPO/docs/reviews/1-2-qa-validation.md" fb1="$CR_REPO/docs/reviews/s1/B1-qa-validation.md" fsl="$CR_REPO/docs/reviews/s1/sprint-review-fix-qa-validation.md" fgl="$CR_REPO/docs/reviews/s1/B?-qa-validation.md" pv nv; pv="$(printf '## Verdict\nPASS')"
  WHY=""
  # Every cell is gated by `cell` (BL-755), so a mutant runs only the cell its kill token names. Each
  # cell writes the whole file it reads, and the conventions-file cells write and remove their own copy.
  cr_f() { SR_CANON="$(printf 'Canonical run: `%s` from the root\nCanonical result: 9 passed' "$1")" sr_file "$f" "$pv"; }
  cr_conv() { printf -- '- canonical: `pytest suite/tests` and `<venv>/bin/python -m pytest -m unit`\n' > "$CR_REPO/docs/coding-conventions.md"; }
  cr_noconv() { rm -f "$CR_REPO/docs/coding-conventions.md"; }
  SR_NONE='Canonical run: none, the diff is record-only (story, reviews, test-results)'
  if cell cr-ok; then SR_CANON="$CANON_BLK" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-ok; fi
  if cell cr-norun; then SR_CANON='' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-norun "$CR_NORUN"; fi
  # graph s319 5.1 p1's shape: the only counts are on a RED replay line, and the run line says nothing.
  if cell cr-redonly; then SR_CANON="$(printf 'RED replay: 1 failed, 4 passed\nThe canonical run is still in progress.')" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-redonly "$CR_NORUN"; fi
  # The filter grammar (record-only-diff.sh RUN-FILTER). With no docs/coding-conventions.md, -m is
  # accepted and a path refused; cr_conv declares `pytest -m unit` and `pytest suite/tests`.
  if cell cr-filter-k; then cr_noconv; cr_f 'pytest -k test_new'; cr_no "$sd" "$f" cr-filter-k "$CR_FILT"; fi
  if cell cr-filter-kglued; then cr_noconv; cr_f 'pytest -ktest_new'; cr_no "$sd" "$f" cr-filter-kglued "$CR_FILT"; fi
  if cell cr-filter-kquoted; then cr_noconv; cr_f 'pytest -k"test_new"'; cr_no "$sd" "$f" cr-filter-kquoted "$CR_FILT"; fi
  if cell cr-filter-keyword; then cr_noconv; cr_f 'pytest --keyword=x'; cr_no "$sd" "$f" cr-filter-keyword "$CR_FILT"; fi
  if cell cr-deselect; then cr_noconv; cr_f 'pytest --deselect tests/test_a.py::t'; cr_no "$sd" "$f" cr-deselect "$CR_DESEL"; fi
  if cell cr-file; then cr_noconv; cr_f 'pytest tests/test_one.py'; cr_no "$sd" "$f" cr-file "$CR_FILE"; fi
  if cell cr-node; then cr_noconv; cr_f 'pytest tests/test_one.py::test_a'; cr_no "$sd" "$f" cr-node "$CR_FILE"; fi
  if cell cr-m-noconv; then cr_noconv; cr_f '.venv/bin/python -m pytest -m unit -q'; cr_ok "$sd" "$f" cr-m-noconv; fi
  if cell cr-path-noconv; then cr_noconv; cr_f 'pytest suite/tests -n auto'; cr_no "$sd" "$f" cr-path-noconv "$CR_PATH"; fi
  if cell cr-m-conv; then cr_conv; cr_f '.venv/bin/python -m pytest -m unit -q'; cr_ok "$sd" "$f" cr-m-conv; cr_noconv; fi
  if cell cr-m-glued-conv; then cr_conv; cr_f '.venv/bin/python -m pytest -munit'; cr_ok "$sd" "$f" cr-m-glued-conv; cr_noconv; fi
  if cell cr-m-other; then cr_conv; cr_f 'pytest -m "not slow"'; cr_no "$sd" "$f" cr-m-other "$CR_MARK"; cr_noconv; fi
  if cell cr-path-conv; then cr_conv; cr_f 'cd /w && pytest suite/tests -n auto > out.txt 2>&1'; cr_ok "$sd" "$f" cr-path-conv; cr_noconv; fi
  if cell cr-path-other; then cr_conv; cr_f 'pytest other/tests'; cr_no "$sd" "$f" cr-path-other "$CR_PATH"; cr_noconv; fi
  # Narrowing to any runner (BL-769 fold): a test-file argument, go's -run, --lf, -x with --ff, and an
  # argument after `--`; --ff alone runs everything. A path root CONTAINING the declared root is a
  # superset of it, accepted; one inside it is narrowing.
  if cell cr-filter-suffix; then cr_noconv; cr_f 'npx vitest run web/src/foo.test.jsx --root web'; cr_no "$sd" "$f" cr-filter-suffix "$CR_FILE"; fi
  if cell cr-filter-gorun; then cr_noconv; cr_f 'go test ./pkg/one -run TestX'; cr_no "$sd" "$f" cr-filter-gorun "$CR_FILT"; fi
  if cell cr-filter-lf; then cr_conv; cr_f 'pytest suite/tests -x --lf'; cr_no "$sd" "$f" cr-filter-lf "re-runs only the last failures"; cr_noconv; fi
  if cell cr-filter-xff; then cr_conv; cr_f 'pytest suite/tests -x --ff'; cr_no "$sd" "$f" cr-filter-xff "stops at the first of the previous failures"; cr_noconv; fi
  if cell cr-filter-ff; then cr_conv; cr_f 'pytest suite/tests --ff'; cr_ok "$sd" "$f" cr-filter-ff; cr_noconv; fi
  if cell cr-filter-dd; then cr_noconv; cr_f 'npm test -- src/pages'; cr_no "$sd" "$f" cr-filter-dd "hands the runner a path after --"; fi
  if cell cr-path-super; then cr_conv; cr_f 'python3 -m pytest -q suite -p no:cacheprovider -p no:randomly'; cr_ok "$sd" "$f" cr-path-super; cr_noconv; fi
  # A runner the built-in list does not name is a run only when the conventions declare it canonical.
  if cell cr-conv-runner; then printf -- '- canonical: `tox -e all` from the repository root\n' > "$CR_REPO/docs/coding-conventions.md"; cr_f 'tox -e all'; cr_ok "$sd" "$f" cr-conv-runner; cr_noconv; fi
  if cell cr-conv-runner-none; then cr_noconv; cr_f 'tox -e all'; cr_no "$sd" "$f" cr-conv-runner-none "$CR_NORNG"; fi
  if cell cr-path-sub; then cr_conv; cr_f 'pytest suite/tests/unit'; cr_no "$sd" "$f" cr-path-sub "$CR_PATH"; cr_noconv; fi
  if cell cr-nearfilter; then SR_CANON="$(printf 'Canonical run: `pytest -p no:cacheprovider` from the root, see tests/foo-k.py\nCanonical result: 9 passed')" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-nearfilter; fi
  if cell cr-nores; then SR_CANON='Canonical run: `pytest -q` from the root' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-nores "$CR_NORES"; fi
  if cell cr-unfin; then SR_CANON="$(printf 'Canonical run: `pytest -q`\nCanonical result: NOT FINISHED at 44%%, 3801 passed so far')" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-unfin "$CR_UNFIN"; fi
  if cell cr-nocnt; then SR_CANON="$(printf 'Canonical run: `pytest -q`\nCanonical result: green')" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-nocnt "$CR_NOCNT"; fi
  if cell cr-bullet; then SR_CANON="$(printf -- '- Canonical run: `pytest -q` from the root\n- Canonical result: 12 failed, 8799 passed, 0 deselected')" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-bullet; fi
  # NEEDS_REWORK with no run at all: an early REJECT is legitimate.
  if cell cr-nr-norun; then SR_CANON='' sr_file "$f" 'Verdict: NEEDS_REWORK' '' "$(printf '### Important (x)\n\n#### Q-1 the handoff lacks the run\n\nBody.')"; cr_ok "$sd" "$f" cr-nr-norun; fi
  # The exemption: record-only PASS accepted over CR_BASE..CR_REC, refused over CR_BASE..CR_CODE and with no range.
  if cell cr-exempt-rec; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-exempt-rec --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"; fi
  if cell cr-exempt-code; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-code "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"; fi
  if cell cr-exempt-norange; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-norange "$CR_NORNG"; fi
  # A collectable module under test-results/ is not a record.
  if cell cr-exempt-evil; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-evil "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_EVIL"; fi
  # The exemption's base is a gate-1 base. The pass-2 sequence (code at CR_CODE, a story-only rework at
  # CR_P2) is refused over the seat's narrowed CR_CODE..CR_P2 (the story at CR_CODE is already
  # `review`), and an empty CR_CODE..CR_CODE too; over the whole story the partition refuses it.
  if cell cr-exempt-narrow; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-narrow "$CR_GATE1" --story "$CR_STORY" --range "$CR_CODE" "$CR_P2"; fi
  if cell cr-exempt-empty; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-empty "$CR_GATE1" --story "$CR_STORY" --range "$CR_CODE" "$CR_CODE"; fi
  # BL-885: the same empty range with --story ABSOLUTE. A story path record-only-diff.sh cannot resolve at the base
  # read as "no story there yet", a gate-1 base, and the empty diff as record-only, so the exemption was ACCEPTED.
  if cell cr-exempt-abs; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-abs "$CR_GATE1" --story "$CR_REPO/$CR_STORY" --range "$CR_CODE" "$CR_CODE"; fi
  # BL-885: --story ABSOLUTE over the genuinely record-only CR_BASE..CR_REC (story-1 ready-for-dev at the base) is
  # accepted only when the path is normalised to the repo-relative story: unnormalised it is no file at the base or
  # at the frozen sha, and the diff's $CR_STORY is no story path.
  if cell cr-exempt-abs-rec; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-exempt-abs-rec --story "$CR_REPO/$CR_STORY" --range "$CR_BASE" "$CR_REC"; fi
  # A story that is no file at the base or at the frozen sha (a typo, a directory) is not a gate-1 base, even over the
  # empty range; its ALLOW twin is a story created after the base (absent there, a blob at the frozen sha).
  # BL-895: STORY-BIND now refuses both before story-base runs (neither is a story sprint-status lists); story-base's own
  # refusal of them is asked directly by receipt-bl885-frozen.sh (arm story_frozen, M51).
  if cell cr-exempt-typo; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-typo "$CR_BIND" --story "$CR_SDIR/typo.md" --range "$CR_CODE" "$CR_CODE"; fi
  if cell cr-exempt-dir; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-dir "$CR_BIND" --story "$CR_SDIR" --range "$CR_CODE" "$CR_CODE"; fi
  # Its own review file: the index a review name carries is the story's, so story-1-2 is reviewed in 1-2-*.
  if cell cr-exempt-created; then SR_CANON="$SR_NONE" sr_file "$f2" "$pv"; cr_ok "$sd" "$f2" cr-exempt-created --story "$CR_STORY2" --range "$CR_BASE" "$CR_NEWS"; fi
  # BL-895, THE BINDING. cr-bind-seed: the filed shape -- a review-like file created in the range, named so its basename
  # carries the review's index, over the record-only CR_REC..CR_SEED; only the sprint-status row refuses it (story-status
  # exits 0 printing an empty row, so a binding keyed on the exit lets it through). cr-bind-sibling: a REAL listed story
  # checked against the wrong review (index 1-2, story-2-1-y); its ALLOW twin is cr-bind-trunc-ok, one property apart.
  # cr-bind-ok: the correct story at CR_NEWS, whose row the checked-out view lacks, reviewed in a pass-2 file (the index
  # parsed from <idx>-qa-validation-p<M>.md); cr-bind-abs: the same story spelled absolute, in the pass-1 file.
  # cr-bind-bare: the bare story-<idx>.md form, at CR_BARE.
  # The seed is reviewed under index 1-4 and the sibling under 1-2, indexes no other file is listed under, so the
  # one-story-per-index check cannot cover m-row-exit's or m-no-index's subject.
  if cell cr-bind-seed; then SR_CANON="$SR_NONE" sr_file "$f4" "$pv"; cr_no "$sd" "$f4" cr-bind-seed "$CR_BROW" --story "$CR_SEEDF" --range "$CR_REC" "$CR_SEED"; fi
  if cell cr-bind-sibling; then SR_CANON="$SR_NONE" sr_file "$f2" "$pv"; cr_no "$sd" "$f2" cr-bind-sibling "$CR_BIDX" --story "$CR_STORY4" --range "$CR_BASE" "$CR_TRUNC"; fi
  # BL-895 B1. cr-bind-repoint-k / -a: a fresh story-1-1-z.md the view lists under another key, or by repointing row
  # story-1-1's file:, over CR_REC where story-1-1-x.md is already `review` -- refused because x is listed under index 1-1
  # at the base (m-single-file's subject). D1. cr-bind-trunc: story-2-1-y.md, the only file under index 2, under a review
  # named 2-qa-validation.md -- refused by the digit rule alone (m-digit-slug's subject); cr-bind-trunc-ok, its ALLOW twin
  # one property apart, the same story under 2-1-qa-validation.md.
  if cell cr-bind-repoint-k; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-bind-repoint-k "$CR_BONE" --story "$CR_STORYZ" --range "$CR_REC" "$CR_RK"; fi
  if cell cr-bind-repoint-a; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-bind-repoint-a "$CR_BONE" --story "$CR_STORYZ" --range "$CR_REC" "$CR_RA"; fi
  if cell cr-bind-trunc; then SR_CANON="$SR_NONE" sr_file "$ft" "$pv"; cr_no "$sd" "$ft" cr-bind-trunc "$CR_BDIG" --story "$CR_STORY4" --range "$CR_BASE" "$CR_TRUNC"; fi
  if cell cr-bind-trunc-ok; then SR_CANON="$SR_NONE" sr_file "$ft2" "$pv"; cr_ok "$sd" "$ft2" cr-bind-trunc-ok --story "$CR_STORY4" --range "$CR_BASE" "$CR_TRUNC"; fi
  # BL-895 R1. The laundered base (CR_LVD, CR_LREN, CR_LNS, CR_LDUP): each C..F is record-only and z is absent at C, so
  # only the one-story-per-index check refuses it -- the view at C gives no answer (viewdel, which is also W2's state), or
  # an entry still names x by its declared file: (ren), carries no status: (nostat, m-status-skip's subject), or names it
  # twice (dup). R2: cr-bind-longidx, a review named for a slug (1-1-z-qa-validation.md) over CR_REC..CR_RK, refused by the
  # review-index grammar alone (m-index-grammar's subject); cr-bind-letter, its ALLOW twin, a letter-suffixed index 2-3a.
  if cell cr-launder-viewdel; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-launder-viewdel "$CR_BNOANS" --story "$CR_STORYZ" --range "$CR_LVD" "$CR_LVDF"; fi
  if cell cr-launder-ren; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-launder-ren "$CR_BONE" --story "$CR_STORYZ" --range "$CR_LREN" "$CR_LRENF"; fi
  if cell cr-launder-nostat; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-launder-nostat "$CR_BONE" --story "$CR_STORYZ" --range "$CR_LNS" "$CR_LNSF"; fi
  if cell cr-launder-dup; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-launder-dup "$CR_BONE" --story "$CR_STORYZ" --range "$CR_LDUP" "$CR_LDUPF"; fi
  # BL-895 b1, THE VIEW'S HISTORY. A base whose record-only commit deletes x's row (rowdel: the view stays ok through a
  # story-1-2 row) or renames x and repoints the row off the index (ren-repoint) names nothing under 1-1, so every endpoint
  # check passes and only the view's history since the stories directory was created still names x (m-endpoint-only's
  # subject). rowdel-ok, its ALLOW twin one property apart: over the same laundered base, story-1-2-y.md under its own
  # review 1-2, whose index no history entry but itself names.
  # The endpoint check's own subjects, which the view's history cannot see (another directory's file:): xdir and its
  # status-less twin xdir-nostat, each REFUSED under review 1-5 over CR_REC..CR_XD / CR_XDN (m-single-file's and
  # m-status-skip's deciding cells).
  if cell cr-bind-xdir; then SR_CANON="$SR_NONE" sr_file "$f5" "$pv"; cr_no "$sd" "$f5" cr-bind-xdir "$CR_BONE" --story "$CR_STORY5" --range "$CR_REC" "$CR_XD"; fi
  if cell cr-bind-xdir-nostat; then SR_CANON="$SR_NONE" sr_file "$f5" "$pv"; cr_no "$sd" "$f5" cr-bind-xdir-nostat "$CR_BONE" --story "$CR_STORY5" --range "$CR_REC" "$CR_XDN"; fi
  if cell cr-launder-rowdel; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-launder-rowdel "$CR_BHIST" --story "$CR_STORYZ" --range "$CR_LRD" "$CR_LRDF"; fi
  if cell cr-launder-renrp; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-launder-renrp "$CR_BHIST" --story "$CR_STORYZ" --range "$CR_LRR" "$CR_LRRF"; fi
  if cell cr-launder-rowdel-ok; then SR_CANON="$SR_NONE" sr_file "$f2" "$pv"; cr_ok "$sd" "$f2" cr-launder-rowdel-ok --story "$CR_STORY2" --range "$CR_LRD" "$CR_LRDOK"; fi
  # BL-895, THE HISTORY'S OWN TRUST (worlds where CR_HM is seeded). Each is over the rowdel base, so only the view's history
  # names x, and each defeats the history read one way: a backdated side commit merged --no-ff (hist-merge, B1), a shallow
  # boundary at the base (hist-shallow, B2), a replace ref on the base's view (hist-replace, B3), a story in a directory
  # created in the range (hist-dir, D1), the view moved to another sprint (hist-sprint). hist-sprint-ok and hist-crlf are
  # ALLOW twins: the same sprint at both ends, and a CRLF view at both ends (D2).
  if cell cr-hist-merge; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-hist-merge "$CR_BHIST" --story "$CR_STORYZ" --range "$CR_LRD" "$CR_HM"; fi
  if cell cr-hist-shallow; then SR_CANON="$SR_NONE" sr_file "$fsh" "$pv"; cr_no "$sd" "$fsh" cr-hist-shallow "$CR_BSHAL" --story "$CR_STORYZ" --range "$CR_LRD" "$CR_LRDF"; fi
  # hist-shallow-blob (BL-904): z a blob at the base, so story-base answers 0 and only the view history's shallow
  # refusal decides; hist-shallow above is refused by story-base's own shallow refusal as well.
  if cell cr-hist-shallow-blob; then SR_CANON="$SR_NONE" sr_file "$fsh" "$pv"; cr_no "$sd" "$fsh" cr-hist-shallow-blob "$CR_BSHAL" --story "$CR_STORYZ" --range "$CR_LRDZ" "$CR_LRDZF"; fi
  if cell cr-hist-replace; then SR_CANON="$SR_NONE" sr_file "$frp" "$pv"; cr_no "$sd" "$frp" cr-hist-replace "$CR_BONE" --story "$CR_STORYZ" --range "$CR_REC" "$CR_HR"; fi
  if cell cr-hist-dir; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-hist-dir "$CR_BSDIR" --story "$CR_ZZ" --range "$CR_LRD" "$CR_HZ"; fi
  if cell cr-hist-sprint; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-hist-sprint "$CR_BSPR" --story "$CR_S2Z" --range "$CR_LRD" "$CR_HS2"; fi
  if cell cr-hist-sprint-ok; then SR_CANON="$SR_NONE" sr_file "$fs2" "$pv"; cr_ok "$sd" "$fs2" cr-hist-sprint-ok --story "$CR_S2Q" --range "$CR_HS2" "$CR_HS2OK"; fi
  # BL-895 U1h, THE REVIEW'S SPRINT (worlds where CR_FR1 is seeded). The faked roll in one commit (roll1), in two (roll2)
  # and with s2's stories directory existing at the base (roll3), each reviewed under docs/reviews/s1/: REFUSED, the view
  # reading sprint 2 where the review is sprint 1 (m-view-sprint's subject: the sprint read from the view accepts all three).
  # sprint-view: a story in sprint 1's own directory with the view's `sprint:` moved to 2, refused only by the view-sprint
  # check (m-sprint's subject). nopath: a review outside any docs/reviews/s<N>/ slot. schema-env: the seat's
  # AI_DLC_SPRINT_STATUS_SCHEMA names q{sprint}, z in q1/stories over the rowdel base: REFUSED, the override ignored
  # (m-schema-env). gwt: GIT_WORK_TREE at a second checkout whose history never named x, the range its shas: REFUSED,
  # read in the review file's own repository (m-gwt). roll-ok (ALLOW): a real roll to sprint 6 that retires sprint 1's
  # `stories/story-1-1-x.md` row, reviewed under s6 (m-roll-drop-off). roll-mid: the intermediate-sprint launder, a value
  # resolved into sprint 5's directory at a commit after the creation: REFUSED (m-roll-drop-every).
  if cell cr-sprint-roll1; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-sprint-roll1 "$CR_BSPR" --story "$CR_S2Z" --range "$CR_FR1" "$CR_FR1F"; fi
  if cell cr-sprint-roll2; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-sprint-roll2 "$CR_BSPR" --story "$CR_S2Z" --range "$CR_FR2" "$CR_FR2F"; fi
  if cell cr-sprint-roll3; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-sprint-roll3 "$CR_BSPR" --story "$CR_S2Z" --range "$CR_FR3" "$CR_FR3F"; fi
  if cell cr-sprint-view; then SR_CANON="$SR_NONE" sr_file "$f3" "$pv"; cr_no "$sd" "$f3" cr-sprint-view "$CR_BSPR" --story "$CR_SPQ" --range "$CR_BASE" "$CR_SPF"; fi
  if cell cr-sprint-nopath; then SR_CANON="$SR_NONE" sr_file "$fnp" "$pv"; cr_no "$sd" "$fnp" cr-sprint-nopath "$CR_BNOSPR" --story "$CR_STORY2" --range "$CR_BASE" "$CR_NEWS"; fi
  if cell cr-schema-env; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; CR_ENV="AI_DLC_SPRINT_STATUS_SCHEMA=$CR_SCHQ" cr_no "$sd" "$f" cr-schema-env "$CR_BSDIR" --story "$CR_QZ" --range "$CR_LRD" "$CR_SCF"; fi
  if cell cr-gwt; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; CR_ENV="GIT_WORK_TREE=$CR_GWO" cr_no "$sd" "$f" cr-gwt "$CR_BROW" --story "$CR_STORYZ" --range "$CR_GWB" "$CR_GWF"; fi
  if cell cr-roll-ok; then SR_CANON="$SR_NONE" sr_file "$fs6" "$pv"; cr_ok "$sd" "$fs6" cr-roll-ok --story "$CR_S6N" --range "$CR_RL" "$CR_RLF"; fi
  # cr-root-env: the seat's AI_DLC_PROJECT_ROOT names PROJ_Q (stories_dir q{sprint}), z in q1/stories over the rowdel
  # base: REFUSED. In the distribution layout SRCDIR reads core/schemas script-relative, so only a flat copy (every
  # mutant's) consults the root; m-root-env, which lets the variable through to sprint-status.sh, dies here.
  # cr-sprint-relpath (ALLOW): cr-bind-ok's world, the review named relatively (./1-2-qa-validation.md) from inside
  # docs/reviews/s1/, the seat's own cwd: the sprint is parsed from the logical directory, not `.` (m-relpath).
  if cell cr-root-env; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; CR_ROOT="$PROJ_Q" cr_no "$sd" "$f" cr-root-env "$CR_BSDIR" --story "$CR_QZ" --range "$CR_LRD" "$CR_SCF"; fi
  if cell cr-sprint-relpath; then SR_CANON="$SR_NONE" sr_file "$f2" "$pv"; _crw="$PWD"; cd "${f2%/*}" || return 1
    cr_ok "$sd" ./1-2-qa-validation.md cr-sprint-relpath --story "$CR_STORY2" --range "$CR_BASE" "$CR_NEWS"; cd "$_crw" || return 1; fi
  if cell cr-roll-mid; then SR_CANON="$SR_NONE" sr_file "$fs4" "$pv"; cr_no "$sd" "$fs4" cr-roll-mid "the implementation view named story-1-1-m.md under that index between" --story "$CR_S4Z" --range "$CR_RMD" "$CR_RMF"; fi
  if cell cr-hist-crlf; then SR_CANON="$SR_NONE" sr_file "$f2" "$pv"; cr_ok "$sd" "$f2" cr-hist-crlf --story "$CR_STORY2" --range "$CR_HC" "$CR_HCOK"; fi
  if cell cr-bind-longidx; then SR_CANON="$SR_NONE" sr_file "$fl" "$pv"; cr_no "$sd" "$fl" cr-bind-longidx "$CR_BNOIDX" --story "$CR_STORYZ" --range "$CR_REC" "$CR_RK"; fi
  if cell cr-bind-letter; then SR_CANON="$SR_NONE" sr_file "$fa" "$pv"; cr_ok "$sd" "$fa" cr-bind-letter --story "$CR_SDIR/story-2-3a-q.md" --range "$CR_BASE" "$CR_LET"; fi
  # A3b, LETTER-LED INDICES (graph s316's B1, B-1, DASH; the lead's prescribed re-run with --story), each a run claim over
  # CR_BASE..CR_LTR, so only the index and view-row binding decide. cr-b1-right: B1 with the story the view lists under
  # it, SERIAL-OK (m-letter-idx's subject: the numeric-only grammar refuses B1). cr-b1-wrong: B1 with B2's listed story,
  # REFUSED by the index match. cr-slug-unlisted: a slug index whose story-<idx>.md exists but no row lists, REFUSED by
  # the row. cr-glob-literal: index `B?`, which as a pattern would match the listed story-B1-x.md, REFUSED by the literal
  # index match (m-idx-pattern's subject).
  _ltr() { sr_file "$1" "$pv"; shift; cr_no "$sd" "$@"; }
  if cell cr-b1-right; then sr_file "$fb1" "$pv"; cr_ok "$sd" "$fb1" cr-b1-right --story "$CR_SDIR/story-B1-x.md" --range "$CR_BASE" "$CR_LTR"; fi
  if cell cr-b1-wrong; then _ltr "$fb1" "$fb1" cr-b1-wrong "is not story-B1.md or story-B1-*.md" --story "$CR_SDIR/story-B2-y.md" --range "$CR_BASE" "$CR_LTR"; fi
  if cell cr-slug-unlisted; then _ltr "$fsl" "$fsl" cr-slug-unlisted "$CR_BROW" --story "$CR_SDIR/story-sprint-review-fix.md" --range "$CR_BASE" "$CR_LTR"; fi
  if cell cr-glob-literal; then _ltr "$fgl" "$fgl" cr-glob-literal "is not story-B?.md or story-B?-*.md" --story "$CR_SDIR/story-B1-x.md" --range "$CR_BASE" "$CR_LTR"; fi
  if cell cr-bind-ok; then SR_CANON="$SR_NONE" sr_file "$f2p" "$pv"; cr_ok "$sd" "$f2p" cr-bind-ok --story "$CR_STORY2" --range "$CR_BASE" "$CR_NEWS"; fi
  if cell cr-bind-abs; then SR_CANON="$SR_NONE" sr_file "$f2" "$pv"; cr_ok "$sd" "$f2" cr-bind-abs --story "$CR_REPO/$CR_STORY2" --range "$CR_BASE" "$CR_NEWS"; fi
  if cell cr-bind-bare; then SR_CANON="$SR_NONE" sr_file "$f3" "$pv"; cr_ok "$sd" "$f3" cr-bind-bare --story "$CR_STORY3" --range "$CR_BASE" "$CR_BARE"; fi
  if cell cr-exempt-whole; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-whole "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_P2"; fi
  if cell cr-exempt-nonanc; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-nonanc "$CR_NOANC" --story "$CR_STORY" --range "$CR_CODE" "$CR_REC"; fi
  if cell cr-bare; then SR_CANON='Canonical run: none' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-bare "gives no reason" --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"; fi
  # A no-run claim spelled other than none is held to the partition, accepted on a record range.
  if cell cr-norun-na; then SR_CANON='Canonical run: N/A, docs-only story' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-norun-na "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"; fi
  # The none is read before the run shape: a none whose reason names a runner span is a no-run claim.
  if cell cr-norun-nonebt; then SR_CANON='Canonical run: none, `pytest -q` is not needed for a docs-only story' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-norun-nonebt "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"; fi
  if cell cr-norun-other; then
    for nv in 'TBD' 'skipped, no code of note'; do
      SR_CANON="Canonical run: $nv" sr_file "$f" "$pv"
      cr_no "$sd" "$f" "cr-norun-other[$nv]" "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"
    done
  fi
  if cell cr-norun-rec; then
    for nv in 'N/A, docs-only story' 'TBD' 'skipped, no code of note'; do
      SR_CANON="Canonical run: $nv" sr_file "$f" "$pv"
      cr_ok "$sd" "$f" "cr-norun-rec[$nv]" --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"
    done
  fi
  # cr-serial-legacy (ALLOW): a review inside PROJ_CRS, the root and the review's repository one tree, whose qa.md lacks
  # the sentinel: LEGACY, and it accepts. cr-serial-redirect (KILL, one property apart): the same root and the same
  # run-less PASS, the review in CR_REPO, whose own installed qa.md carries the sentinel. The seat's
  # AI_DLC_PROJECT_ROOT cannot skip the rule for a repository that prescribes it (m-legacy-env reads ROLE_MD again).
  if cell cr-serial-legacy; then
    _crl_f="$PROJ_CRS/docs/reviews/s1/1-1-qa-validation.md"; SR_CANON='' sr_file "$_crl_f" "$pv"
    CR_ROOT="$PROJ_CRS" cr_run "$sd" "$_crl_f"
    [ "$SRC" -eq 0 ] && has "$CO" "LEGACY: canonical-run lines not checked: $PROJ_CRS/core/team-roles/qa.md" && has "$CO" "SERIAL-OK:" || WHY="$WHY cr-serial-legacy{rc=$SRC $(head -1 "$CO")}"
    rm -f "$_crl_f"
  fi
  if cell cr-serial-redirect; then
    SR_CANON='' sr_file "$f" "$pv"; mkdir -p "$CR_REPO/.claude/team-roles" && cp "$QA_MD" "$CR_REPO/.claude/team-roles/qa.md"
    CR_ROOT="$PROJ_CRS" cr_no "$sd" "$f" cr-serial-redirect "$CR_NORUN"
    has "$CO" "(held: $CR_REPO/.claude/team-roles/qa.md prescribes the" && ! has "$CO" "LEGACY: canonical-run" || WHY="$WHY cr-serial-redirect{held note: $(head -1 "$CO")}"
    rm -f "$CR_REPO/.claude/team-roles/qa.md"; rmdir "$CR_REPO/.claude/team-roles" "$CR_REPO/.claude"
  fi
  # BL-895 U1k F2, THE INTERPRETER'S IMPORT PATH. cr-launder-rowdel's world (only the view's history names x), with a
  # forged json.py that answers story-status and view-history itself: in the seat's cwd (py-cwd) and on PYTHONPATH
  # (py-path). REFUSED as the clean world is, sprint-status.sh's python being isolated (m-py-isolated's subject).
  if cell cr-py-cwd; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; _crw="$PWD"; cd "$(py_jack)" || return 1
    cr_no "$sd" "$f" cr-py-cwd "$CR_BHIST" --story "$CR_STORYZ" --range "$CR_LRD" "$CR_LRDF"; cd "$_crw" || return 1; fi
  if cell cr-py-path; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; CR_ENV="PYTHONPATH=$(py_jack)" cr_no "$sd" "$f" cr-py-path "$CR_BHIST" --story "$CR_STORYZ" --range "$CR_LRD" "$CR_LRDF"; fi
  # BL-895 U1k F3, ONE SPRINT PER PATH. cr-hist-sprint-ok's sprint-2 world (SERIAL-OK under docs/reviews/s2/), the review
  # written in docs/reviews/s1/ and named through a link `s2` to that directory: the logical directory reads sprint 2, the
  # physical one sprint 1, REFUSED naming both (m-one-sprint's subject; the logical sprint alone acquits it). Its ALLOW
  # twin one property apart: the same link shape onto docs/reviews/s2/, both spellings sprint 2.
  if cell cr-sprint-link; then SR_CANON="$SR_NONE" sr_file "$f3" "$pv"; _crl="$(mktemp -d "$WORK/crl.XXXXXX")" && ln -s "${f3%/*}" "$_crl/s2" || return 1
    cr_no "$sd" "$_crl/s2/${f3##*/}" cr-sprint-link "$CR_B2S" --story "$CR_S2Q" --range "$CR_HS2" "$CR_HS2OK"; fi
  if cell cr-sprint-link-ok; then mkdir -p "${fs2%/*}"; SR_CANON="$SR_NONE" sr_file "$fs2" "$pv"; _crl="$(mktemp -d "$WORK/crl.XXXXXX")" && ln -s "${fs2%/*}" "$_crl/s2" || return 1
    cr_ok "$sd" "$_crl/s2/${fs2##*/}" cr-sprint-link-ok --story "$CR_S2Q" --range "$CR_HS2" "$CR_HS2OK"; fi
  # BL-895 U1k (adversary 5a): a record-class entry committed as a symlink is not a record (cr-exempt-link, REFUSED;
  # m-ro-mode's subject), and the same path as a regular file is (cr-exempt-link-ok, its control, SERIAL-OK).
  if cell cr-exempt-link; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-link "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_LINK"
    has "$CO" "mode 120000" || WHY="$WHY cr-exempt-link{no mode 120000 in $(head -1 "$CO")}"; fi
  if cell cr-exempt-link-ok; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-exempt-link-ok --story "$CR_STORY" --range "$CR_BASE" "$CR_LINKF"; fi
  rm -f "$f" "$f2" "$f3" "$f2p" "$fs2" "$fs4" "$fs6" "$fnp"
  [ -z "$WHY" ]
}
# SP1 (BL-885): the story path record-only-diff.sh resolves, asked of its story-base and paths modes by
# receipt-bl885.sh (beside this file in both layouts) over <script-dir>'s copy. Presence-shaped: every one of the
# receipt's 14 cells must print its `ok` row; a failing cell's FAIL row is the reason a mutant's kill must carry.
SP_CELLS=14
p_story_path() { # <script-dir>
  local sd="$1" o rc n
  WHY=""
  if cell story-path; then
    o="$(bash "$LIB_DIR/receipt-bl885.sh" "$sd/record-only-diff.sh" 2>&1)"; rc=$?
    n="$(grep -c '^ok ' <<<"$o")" || n=0
    [ "$rc" = 0 ] && [ "$n" = "$SP_CELLS" ] \
      || WHY="$WHY story-path{rc=$rc ok=$n/$SP_CELLS $(grep -v '^ok ' <<<"$o" | tr '\n' ' ')}"
  fi
  [ -z "$WHY" ]
}
# SP2 (BL-885): story-base's third operand <frozen>, asked by receipt-bl885-frozen.sh over <script-dir>'s copy. The
# same presence shape: every one of the receipt's 8 cells must print its `ok` row.
SF_CELLS=8
p_story_frozen() { # <script-dir>
  local sd="$1" o rc n
  WHY=""
  if cell story-frozen; then
    o="$(bash "$LIB_DIR/receipt-bl885-frozen.sh" "$sd/record-only-diff.sh" 2>&1)"; rc=$?
    n="$(grep -c '^ok ' <<<"$o")" || n=0
    [ "$rc" = 0 ] && [ "$n" = "$SF_CELLS" ] \
      || WHY="$WHY story-frozen{rc=$rc ok=$n/$SF_CELLS $(grep -v '^ok ' <<<"$o" | tr '\n' ' ')}"
  fi
  [ -z "$WHY" ]
}
# SH1 (BL-904): story-base over a story deleted and re-added, asked by receipt-bl904.sh over <script-dir>'s copy. The
# same presence shape: every one of the receipt's 8 cells must print its `ok` row. The receipt's merge-hidden cell
# (sh-merge) is the one plain `rev-list` accepts; BL-895's view binding does not see the deletion, so the kill is
# asked of story-base directly, as SP2's is.
SH_CELLS=8
p_story_hist() { # <script-dir>
  local sd="$1" o rc n
  WHY=""
  if cell story-hist; then
    o="$(bash "$LIB_DIR/receipt-bl904.sh" "$sd/record-only-diff.sh" 2>&1)"; rc=$?
    n="$(grep -c '^ok ' <<<"$o")" || n=0
    [ "$rc" = 0 ] && [ "$n" = "$SH_CELLS" ] \
      || WHY="$WHY story-hist{rc=$rc ok=$n/$SH_CELLS $(grep -v '^ok ' <<<"$o" | tr '\n' ' ')}"
  fi
  [ -z "$WHY" ]
}
# CR2: the merge holds the execution owner's file (cross-1) to the rule, and a frozen tree whose
# INSTALLED qa.md carries no label is LEGACY. QS installs the subject's qa.md, QL a container-less copy
# that also predates the label (it is derived from the subject, so the label is stripped explicitly).
CR_LEG="LEGACY: canonical-run lines not checked:"
p_canon_merge() {
  local sd="$1" d o cf SHARD_SHA
  WHY=""
  crm_strip() { grep -v '^Canonical r' "$1/cross-1.md" > "$1/x.tmp" && mv "$1/x.tmp" "$1/cross-1.md"; }
  crm_bind() { # <--story> [<repo> <base> <sha>] -> d, o, cf (the execution owner's key), RC, $MO: REPO_CRB's world (or the
    # one named), its execution owner claiming none
    local cb_r="${2:-$REPO_CRB}" cb_b="${3:-$CRB_BASE}" cb_s="${4:-$CRB_SHA}"
    SHARD_SHA="$cb_s"
    d="$(WSLOT="${CRM_SLOT:-1}" CANON_BLK='Canonical run: none, the diff is record-only (test-results)' kworld "$sd" "$cb_r" "$cb_b" "$cb_s" 3 qa-validation PASS qa)" \
      || { WHY="$WHY the record-only merge world was not built"; return 1; }
    if [ -f "$d/cross.md" ]; then cf=cross; else cf=cross-1; fi
    grep -qxF 'Canonical run: none, the diff is record-only (test-results)' "$d/$cf.md" \
      || { WHY="$WHY FIXTURE STALE: $cf.md carries no none claim"; return 1; }
    o="$(qout "$d")"
    # The lead runs the merge from its checkout; CRM_JACK puts the forged json.py in a directory of that checkout and
    # runs from there (crm-py-cwd), so the cwd is hijacked and the git common dir is still the lead's.
    local cb_cwd="${d%%/docs/reviews/*}"
    if [ -n "${CRM_JACK:-}" ]; then mkdir -p "$cb_cwd/jack" && cp "$CRM_JACK/json.py" "$cb_cwd/jack/json.py" && cb_cwd="$cb_cwd/jack" || return 1; fi
    ip_run -C "${QCWD:-$cb_cwd}" -e "AI_DLC_PROJECT_ROOT=${CRM_ROOT:-$PROJ}" ${CRM_ENV:+-e "$CRM_ENV"} "$sd/merge-review-shards.sh" mrs_main "$d" --gate qa --out "$o" --story "$1" > "$MO" 2>&1 < /dev/null; RC=$?
  }
  if cell crm-ok; then
    crm_sh_=0
    if hand_use "$sd" qw1; then crm_sh_=1   # Q1's all-PASS merge, unmodified
    else
      d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
      o="$(qout "$d")"; q_merge "$sd" "$d"
    fi
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "$CR_LEG" || WHY="$WHY crm-ok{rc=$RC $(head -1 "$MO")}"
    [ "$crm_sh_" = 1 ] || rm -f "$o"
  fi
  if cell crm-norun; then
    d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$CR_NORUN" "$o" && owner_in "$MO" cross-1 || WHY="$WHY crm-norun{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  if cell crm-nr-norun; then
    d="$(qworld "$sd" PASS NEEDS_REWORK PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK" || WHY="$WHY crm-nr-norun{rc=$RC $(head -1 "$MO")}"
    rm -f "$o"
  fi
  if cell crm-legacy; then
    SHARD_SHA="$CRL_SHA"
    d="$(kworld "$sd" "$REPO_CRL" "$CRL_BASE" "$CRL_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the legacy world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "$CR_LEG" && has "$MO" "MERGED:" || WHY="$WHY crm-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    rm -f "$o"
  fi
  # qa.md NOT tracked at the frozen sha, installed on disk in the manifest's worktree: the on-disk copy
  # decides. Without the label: LEGACY and merges. With it: held, a run-less PASS refused. Neither: held,
  # naming both paths. Each cell writes (or removes) the on-disk copy itself and removes it after.
  if cell crm-disk-legacy; then
    SHARD_SHA="$CRU_SHA"; cp "$CRU_OLD" "$REPO_CRU/.claude/team-roles/qa.md"
    d="$(kworld "$sd" "$REPO_CRU" "$CRU_BASE" "$CRU_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the untracked world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "$CR_LEG" && has "$MO" "(on disk, untracked at" && has "$MO" "MERGED:" || WHY="$WHY crm-disk-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    rm -f "$o" "$REPO_CRU/.claude/team-roles/qa.md"
  fi
  if cell crm-disk-held; then
    SHARD_SHA="$CRU_SHA"; cp "$QA_MD" "$REPO_CRU/.claude/team-roles/qa.md"
    d="$(kworld "$sd" "$REPO_CRU" "$CRU_BASE" "$CRU_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the untracked world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$CR_NORUN" "$o" && ! has "$MO" "$CR_LEG" || WHY="$WHY crm-disk-held{rc=$RC $(reline "$MO")}"
    rm -f "$o" "$REPO_CRU/.claude/team-roles/qa.md"
  fi
  if cell crm-neither; then
    SHARD_SHA="$CRU_SHA"; rm -f "$REPO_CRU/.claude/team-roles/qa.md"
    d="$(kworld "$sd" "$REPO_CRU" "$CRU_BASE" "$CRU_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the untracked world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$CR_NORUN" "$o" && has "$MO" "nor on disk at $REPO_CRU/.claude/team-roles/qa.md" || WHY="$WHY crm-neither{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  # BL-895 in the MERGE (owner: the execution owner). REPO_CRB's base..sha is record-only and partitions into parts, so
  # the execution owner's 'Canonical run: none, <reason>' reaches canon_gate's record-only branch with the merge's own
  # owner. crm-bind: --story a review-like path, not story-1.md or story-1-*.md for the merged index 1, REFUSED naming
  # the execution owner. crm-bind-ok, its ALLOW twin one property apart: the story the view lists at the frozen sha, MERGED.
  if cell crm-bind; then
    crm_bind docs/reviews/s1/new.md || return 1
    refused_at "$CR_BIND" "$o" && has "$MO" "is not story-1.md or story-1-*.md" && owner_in "$MO" "$cf" \
      || WHY="$WHY crm-bind{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  if cell crm-bind-ok; then
    crm_bind "$CRB_STORY" || return 1
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "$CR_LEG" && [ -f "$o" ] || WHY="$WHY crm-bind-ok{rc=$RC $(head -1 "$MO")}"
    rm -f "$o"
  fi
  # A3b in the MERGE: REPO_CLB, shard directory B1-qa-validation-<sha12>. crm-b1-right: --story the B1 story the view
  # lists, MERGED. crm-b1-wrong: --story B2's listed story, REFUSED by the index match naming the execution owner.
  if cell crm-b1-right; then KIDX=B1 crm_bind "$CR_SDIR/story-B1-x.md" "$REPO_CLB" "$CLB_BASE" "$CLB_SHA" || return 1
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && [ "${o##*/}" = B1-qa-validation.md ] || WHY="$WHY crm-b1-right{rc=$RC $(head -1 "$MO")}"
    rm -f "$o"
  fi
  if cell crm-b1-wrong; then KIDX=B1 crm_bind "$CR_SDIR/story-B2-y.md" "$REPO_CLB" "$CLB_BASE" "$CLB_SHA" || return 1
    refused_at "$CR_BIND" "$o" && has "$MO" "is not story-B1.md or story-B1-*.md" && owner_in "$MO" "$cf" \
      || WHY="$WHY crm-b1-wrong{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  # BL-895 b1 in the MERGE: REPO_CRH is crm-bind-ok's world one property apart -- its root commit's view also named
  # story-1-y.md under index 1, and the base dropped that row, so only the view's history names it. REFUSED naming the
  # execution owner.
  if cell crm-bind-hist; then
    crm_bind "$CRB_STORY" "$REPO_CRH" "$CRH_BASE" "$CRH_SHA" || return 1
    refused_at "$CR_BIND" "$o" && has "$MO" "the implementation view named stories/story-1-y.md under that index between" && owner_in "$MO" "$cf" \
      || WHY="$WHY crm-bind-hist{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  # The history's own trust in the MERGE (REPO_CMH, REPO_CMSH, REPO_CMRP, REPO_CMZ, REPO_CMS): the serial hist-* cells'
  # refusals, each REFUSED naming the execution owner.
  crm_hist() { # <cell> <story> <repo> <base> <sha> <token>
    crm_bind "$2" "$3" "$4" "$5" || return 1
    refused_at "$CR_BIND" "$o" && has "$MO" "$6" && owner_in "$MO" "$cf" || WHY="$WHY $1{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  }
  if cell crm-hist-merge; then crm_hist crm-hist-merge "$CRB_STORY" "$REPO_CMH" "$CMH_BASE" "$CMH_SHA" "the implementation view named stories/story-1-y.md under that index between" || return 1; fi
  if cell crm-hist-shallow; then crm_hist crm-hist-shallow "$CRB_STORY" "$REPO_CMSH" "$CRH_BASE" "$CRH_SHA" "$CR_BSHAL" || return 1; fi
  if cell crm-hist-replace; then crm_hist crm-hist-replace "$CRB_STORY" "$REPO_CMRP" "$CRH_BASE" "$CRH_SHA" "the implementation view named stories/story-1-y.md under that index between" || return 1; fi
  if cell crm-hist-dir; then crm_hist crm-hist-dir "$CM_ZZ" "$REPO_CMZ" "$CMZ_BASE" "$CMZ_SHA" "$CR_BSDIR" || return 1; fi
  if cell crm-hist-sprint; then crm_hist crm-hist-sprint "$CM_S2" "$REPO_CMS" "$CMS_BASE" "$CMS_SHA" "$CR_BSPR" || return 1; fi
  # BL-895 U1h: T1 on the merge, the manifest's base taken after a faked roll (REPO_CMR), the shard directory under s1.
  if cell crm-sprint-roll; then crm_hist crm-sprint-roll "$CM_S2" "$REPO_CMR" "$CMR_BASE" "$CMR_SHA" "$CR_BSPR" || return 1; fi
  # The one-commit shape (REPO_CMR1) and T1c, s2's directory created at the base (REPO_CMR3): REFUSED the same way.
  if cell crm-sprint-roll1; then crm_hist crm-sprint-roll1 "$CM_S2" "$REPO_CMR1" "$CMR1_BASE" "$CMR1_SHA" "$CR_BSPR" || return 1; fi
  if cell crm-sprint-roll3; then crm_hist crm-sprint-roll3 "$CM_S2" "$REPO_CMR3" "$CMR3_BASE" "$CMR3_SHA" "$CR_BSPR" || return 1; fi
  # crm-sprint-view: REPO_CMV's story sits in sprint 1's own directory and only the frozen view reads sprint 2 (the
  # view-sprint check alone refuses it). crm-schema-env: REPO_CMQ's story sits in q1/stories, the directory the
  # lead's AI_DLC_SPRINT_STATUS_SCHEMA override (q{sprint}) would name; the override is ignored, so it is refused.
  if cell crm-sprint-view; then crm_hist crm-sprint-view "$CRB_STORY" "$REPO_CMV" "$CMV_BASE" "$CMV_SHA" "$CR_BSPR" || return 1; fi
  if cell crm-schema-env; then CRM_ENV="AI_DLC_SPRINT_STATUS_SCHEMA=$CR_SCHQ" crm_hist crm-schema-env "$CM_Q1" "$REPO_CMQ" "$CMQ_BASE" "$CMQ_SHA" "$CR_BSDIR" || return 1; fi
  # crm-root-env: the same world, the lead's AI_DLC_PROJECT_ROOT naming PROJ_Q (stories_dir q{sprint}): REFUSED.
  if cell crm-root-env; then CRM_ROOT="$PROJ_Q" crm_hist crm-root-env "$CM_Q1" "$REPO_CMQ" "$CMQ_BASE" "$CMQ_SHA" "$CR_BSDIR" || return 1; fi
  # The merge takes no --range (it would only narrow the manifest's whole-story range).
  if cell crm-range; then
    d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
    o="$(qout "$d")"
    ip_run -C "${QCWD:-${d%%/docs/reviews/*}}" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main "$d" --gate qa --out "$o" --story x.md --range "$B_SHA" "$B_SHA" > "$MO" 2>&1 < /dev/null; RC=$?
    refused_at "--range is read only by --check-serial" "$o" || WHY="$WHY crm-range{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  # BL-895 U1k F2 on the MERGE: crm-bind-hist's world, a forged json.py in the lead's cwd (py-cwd) and on PYTHONPATH
  # (py-path). REFUSED as the clean world is, naming the execution owner (m-py-isolated-merge's subject).
  if cell crm-py-cwd; then
    CRM_JACK="$(py_jack)" crm_hist crm-py-cwd "$CRB_STORY" "$REPO_CRH" "$CRH_BASE" "$CRH_SHA" "the implementation view named stories/story-1-y.md under that index between" || return 1; fi
  if cell crm-py-path; then CRM_ENV="PYTHONPATH=$(py_jack)" crm_hist crm-py-path "$CRB_STORY" "$REPO_CRH" "$CRH_BASE" "$CRH_SHA" "the implementation view named stories/story-1-y.md under that index between" || return 1; fi
  # BL-895 U1k F3 on the MERGE. The world's slot directory <B> (a name opening s1) holds shards/<dir>; crm_link moves or
  # links it, then merges through the logical path. link: crm-sprint-roll's world (REPO_CMR, refused under sprint 1), the
  # slot moved to its sibling s2<B without the s1> and named through a link <B> elsewhere: logical sprint 1, physical 2,
  # REFUSED naming both (m-one-sprint-merge's subject; the physical sprint alone merges it). link-rev: the reverse, the
  # slot left in place and named through a link s2<...>: logical 2, physical 1, REFUSED the same way -- neither spelling
  # is authoritative, and whoever lays out the path chooses both, so a disagreement is refused in either direction.
  # link-out: crm-bind-ok's world, named through a link of the same name <B> elsewhere: one sprint, but the shard
  # directory is reached through a symlink, so the record name could be moved: REFUSED [owner: lead] by shard_slot
  # (D1; a link onto the same sprint MERGED before 0.995.0). link-check: link's world, --check-shard through the
  # logical path: REFUSED naming both sprints. The record block (shard_slot) never runs under --check-shard, so
  # one_sprint is the only guard there (m-one-sprint-merge's subject).
  crm_link() { # <cell> <story> <repo> <base> <sha> <move|rev|same> -> RC, $MO, o, cf
    local cl_b cl_p cl_l cl_n
    SHARD_SHA="$5"
    d="$(WSLOT=1 CANON_BLK='Canonical run: none, the diff is record-only (test-results)' kworld "$sd" "$3" "$4" "$5" 3 qa-validation PASS qa)" \
      || { WHY="$WHY $1{the record-only merge world was not built}"; return 1; }
    if [ -f "$d/cross.md" ]; then cf=cross; else cf=cross-1; fi
    cl_p="$(dirname "$(dirname "$d")")"; cl_b="$(basename "$cl_p")"
    case "$cl_b" in s1*) ;; *) WHY="$WHY $1{FIXTURE STALE: the world's slot directory $cl_b does not open s1}"; return 1 ;; esac
    cl_l="$(mktemp -d "$WORK/cml.XXXXXX")" || return 1
    case "$6" in
      move) cl_n="$(dirname "$cl_p")/s2${cl_b#s1}"; mv "$cl_p" "$cl_n" && ln -s "$cl_n" "$cl_l/$cl_b" || return 1; d="$cl_l/$cl_b/shards/${d##*/}" ;;
      rev) ln -s "$cl_p" "$cl_l/s2${cl_b#s1}" || return 1; d="$cl_l/s2${cl_b#s1}/shards/${d##*/}" ;;
      same) ln -s "$cl_p" "$cl_l/$cl_b" || return 1; d="$cl_l/$cl_b/shards/${d##*/}" ;;
    esac
    o="$(qout "$d")"
    if [ -n "${CRM_CHECK:-}" ]; then
      ip_run -C "${QCWD:-${d%%/docs/reviews/*}}" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main "$d" --gate qa --check-shard "$d/$cf.md" > "$MO" 2>&1 < /dev/null; RC=$?
    else
      ip_run -C "${QCWD:-${d%%/docs/reviews/*}}" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main "$d" --gate qa --out "$o" --story "$2" > "$MO" 2>&1 < /dev/null; RC=$?
    fi
  }
  if cell crm-sprint-link; then crm_link crm-sprint-link "$CM_S2" "$REPO_CMR" "$CMR_BASE" "$CMR_SHA" move || return 1
    refused_at "$CR_B2S" "$o" && has "$MO" "reads sprint 1 and the physical directory" && owner_in "$MO" lead || WHY="$WHY crm-sprint-link{rc=$RC $(reline "$MO")}"; rm -f "$o"; fi
  if cell crm-sprint-link-rev; then crm_link crm-sprint-link-rev "$CM_S2" "$REPO_CMR" "$CMR_BASE" "$CMR_SHA" rev || return 1
    refused_at "$CR_B2S" "$o" && has "$MO" "reads sprint 2 and the physical directory" && owner_in "$MO" lead || WHY="$WHY crm-sprint-link-rev{rc=$RC $(reline "$MO")}"; rm -f "$o"; fi
  if cell crm-sprint-link-out; then crm_link crm-sprint-link-out "$CRB_STORY" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" same || return 1
    refused_at "$LR_D1LINK" "$o" && owner_in "$MO" lead && has "$MO" "$LR_D1FIX" && ! has "$MO" "MERGED:" \
      || WHY="$WHY crm-sprint-link-out{rc=$RC $(reline "$MO")}"; rm -f "$o"; fi
  if cell crm-sprint-link-check; then CRM_CHECK=1 crm_link crm-sprint-link-check "$CM_S2" "$REPO_CMR" "$CMR_BASE" "$CMR_SHA" move || return 1
    [ "$RC" -eq 2 ] && has "$MO" "$CR_B2S" && has "$MO" "reads sprint 1 and the physical directory" && ! has "$MO" "SHARD-OK:" \
      || WHY="$WHY crm-sprint-link-check{rc=$RC $(head -1 "$MO")}"; fi
  [ -z "$WHY" ]
}
# BL-895 U1k: py_jack -> a directory holding a forged json.py that answers sprint-status.sh's story-status and
# view-history itself (a listed row; a view history naming nothing) and exits, written once per run.
py_jack() {
  local p="$WORK/pyjack"
  [ -f "$p/json.py" ] || { mkdir -p "$p" && printf '%s\n' 'import os, sys' 'm = os.environ.get("MODE", "")' \
    'if m == "story-status": sys.stdout.write("story\treview\tfrontmatter\nrow\treview\tforged\n")' \
    'elif m == "view-history": sys.stdout.write("since\t0000000000000000000000000000000000000000\n")' \
    'sys.stdout.flush(); os._exit(0)' > "$p/json.py"; } || return 1
  printf '%s' "$p"
}
CR_B2S="path names two sprints: the logical directory"
# REPO_CRL: B's six files over a base installing a qa.md WITHOUT the canonical-run label (consumer layout).
REPO_CRL="$WORK/repo-crl"
new_repo "$REPO_CRL" old && mkdir -p "$REPO_CRL/.claude/team-roles" \
  && grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$REPO_CRL/.claude/team-roles/qa.md" \
  && G -C "$REPO_CRL" add -A && G -C "$REPO_CRL" commit -q --amend -m base || { echo "FIXTURE ERROR: the legacy qa.md repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CRL/$f" 5 "$f"; done
G -C "$REPO_CRL" add -A && G -C "$REPO_CRL" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CRL_BASE="$(G -C "$REPO_CRL" rev-parse HEAD~1)"; CRL_SHA="$(G -C "$REPO_CRL" rev-parse HEAD)"
_crl="$(G -C "$REPO_CRL" show "${CRL_SHA}:.claude/team-roles/qa.md" | grep -cF 'column-0 `Canonical run:`')" || _crl=0
_crs="$(grep -cF 'column-0 `Canonical run:`' "$QA_MD")" || _crs=0
[ "$_crl" = 0 ] && [ "$_crs" -ge 1 ] \
  || { echo "FIXTURE STALE: the legacy qa.md cannot express the canonical-run boundary (installed $_crl, subject $_crs)" >&2; exit 2; }
# REPO_CRU: B's six files with NO qa.md tracked at either sha; the cells write the on-disk copy.
REPO_CRU="$WORK/repo-cru"; CRU_OLD="$WORK/qa-nolabel.md"
grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$CRU_OLD"
new_repo "$REPO_CRU" old && mkdir -p "$REPO_CRU/.claude/team-roles" || { echo "FIXTURE ERROR: the untracked qa.md repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CRU/$f" 5 "$f"; done
G -C "$REPO_CRU" add -A && G -C "$REPO_CRU" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CRU_BASE="$(G -C "$REPO_CRU" rev-parse HEAD~1)"; CRU_SHA="$(G -C "$REPO_CRU" rev-parse HEAD)"
G -C "$REPO_CRU" cat-file -e "${CRU_SHA}:.claude/team-roles/qa.md" 2>/dev/null \
  && { echo "FIXTURE STALE: qa.md is tracked in the untracked-qa.md repo" >&2; exit 2; }
# REPO_CRB (BL-895): a RECORD-ONLY diff the merge shards. The partition drops its scan roots (_bmad-output, docs/reviews,
# docs/escalations), so the diff is six test-results/ text files under three subdirectories -- records to
# record-only-diff.sh (no *.py/*.sh/*.toml/*.cfg), reviewable to the partition. The base installs the subject's qa.md (the
# rule held), story-1-x.md at `review` and the implementation view listing it with its file:. The merged index is 1, so
# the story is story-1-x.md: story-1-1-x.md's slug opens with a digit and carries index 1-1, not 1.
REPO_CRB="$WORK/repo-crb"; CRB_STORY="$CR_SDIR/story-1-x.md"
new_repo "$REPO_CRB" old && mkdir -p "$REPO_CRB/.claude/team-roles" "$REPO_CRB/$CR_SDIR" "$REPO_CRB/${CR_VIEW%/*}" \
  && cp "$QA_MD" "$REPO_CRB/.claude/team-roles/qa.md" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CRB/$CRB_STORY" \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-x.md\n' > "$REPO_CRB/$CR_VIEW" \
  && G -C "$REPO_CRB" add -A && G -C "$REPO_CRB" commit -q --amend -m base || { echo "FIXTURE ERROR: the record-only merge repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CRB/test-results/$f" 5 "$f"; done
G -C "$REPO_CRB" add -A && G -C "$REPO_CRB" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CRB_BASE="$(G -C "$REPO_CRB" rev-parse HEAD~1)"; CRB_SHA="$(G -C "$REPO_CRB" rev-parse HEAD)"
_crb="$(G -C "$REPO_CRB" diff --name-only "$CRB_BASE" "$CRB_SHA" | grep -cvE '^test-results/[a-z]+/[a-z0-9]+\.txt$')" || _crb=0
[ "$_crb" = 0 ] && [ "$(G -C "$REPO_CRB" diff --name-only "$CRB_BASE" "$CRB_SHA" | grep -c .)" = 6 ] \
  || { echo "FIXTURE STALE: REPO_CRB's base..sha is not six test-results/ text files ($_crb other path(s))" >&2; exit 2; }
# REPO_CLB (A3b): REPO_CRB's record-only shape with letter-led stories, story-B1-x.md and story-B2-y.md, each listed
# (story-1-5, story-1-6). The merge's index is the shard directory's B1 (KIDX names it to kworld and qout).
REPO_CLB="$WORK/repo-clb"
new_repo "$REPO_CLB" old && mkdir -p "$REPO_CLB/.claude/team-roles" "$REPO_CLB/$CR_SDIR" "$REPO_CLB/${CR_VIEW%/*}" \
  && cp "$QA_MD" "$REPO_CLB/.claude/team-roles/qa.md" && printf -- '---\nstatus: review\n---\n# B1\n' > "$REPO_CLB/$CR_SDIR/story-B1-x.md" \
  && printf -- '---\nstatus: review\n---\n# B2\n' > "$REPO_CLB/$CR_SDIR/story-B2-y.md" \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-5:\n    status: review\n    file: stories/story-B1-x.md\n  story-1-6:\n    status: review\n    file: stories/story-B2-y.md\n' > "$REPO_CLB/$CR_VIEW" \
  && G -C "$REPO_CLB" add -A && G -C "$REPO_CLB" commit -q --amend -m base || { echo "FIXTURE ERROR: the letter-led merge repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CLB/test-results/$f" 5 "$f"; done
G -C "$REPO_CLB" add -A && G -C "$REPO_CLB" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CLB_BASE="$(G -C "$REPO_CLB" rev-parse HEAD~1)"; CLB_SHA="$(G -C "$REPO_CLB" rev-parse HEAD)"
# REPO_CRH (BL-895 b1): REPO_CRB with one more commit before the base -- the root's view also lists story-1-y.md under
# index 1, and the base commit drops that row, so the view at the base and at the sha names only story-1-x.md.
REPO_CRH="$WORK/repo-crh"
new_repo "$REPO_CRH" old && mkdir -p "$REPO_CRH/.claude/team-roles" "$REPO_CRH/$CR_SDIR" "$REPO_CRH/${CR_VIEW%/*}" \
  && cp "$QA_MD" "$REPO_CRH/.claude/team-roles/qa.md" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CRH/$CRB_STORY" \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-x.md\n  story-1-9:\n    status: review\n    file: stories/story-1-y.md\n' > "$REPO_CRH/$CR_VIEW" \
  && G -C "$REPO_CRH" add -A && G -C "$REPO_CRH" commit -q --amend -m root \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-x.md\n' > "$REPO_CRH/$CR_VIEW" \
  && G -C "$REPO_CRH" add -A && G -C "$REPO_CRH" commit -q -m base || { echo "FIXTURE ERROR: the view-history merge repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CRH/test-results/$f" 5 "$f"; done
G -C "$REPO_CRH" add -A && G -C "$REPO_CRH" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CRH_BASE="$(G -C "$REPO_CRH" rev-parse HEAD~1)"; CRH_SHA="$(G -C "$REPO_CRH" rev-parse HEAD)"
_crhd="$(G -C "$REPO_CRH" diff --name-only "$CRH_BASE" "$CRH_SHA")" || _crhd=""
_crhv="$(G -C "$REPO_CRH" show "${CRH_BASE}:$CR_VIEW")" || _crhv=""; _crbv="$(G -C "$REPO_CRB" show "${CRB_BASE}:$CR_VIEW")" || _crbv=""
_crhr="$(G -C "$REPO_CRH" show "${CRH_BASE}~1:$CR_VIEW")" || _crhr=""
[ "$_crhd" = "$(G -C "$REPO_CRB" diff --name-only "$CRB_BASE" "$CRB_SHA")" ] && [ -n "$_crhv" ] && [ "$_crhv" = "$_crbv" ] \
  && grep -qF 'stories/story-1-y.md' <<<"$_crhr" \
  || { echo "FIXTURE STALE: REPO_CRH's base..sha is not six test-results/ files, its base view differs from REPO_CRB's, or its root view does not name story-1-y.md" >&2; exit 2; }
# The history's own trust in the MERGE (BL-895), each a record-only world whose story is CRB_STORY's name under index 1:
#   REPO_CMH (B1) c1 creates the stories dir with story-1-y.md and its row, c2 drops that row (story-1-2-w.md listed instead),
#                 a side commit dated 2001 adds story-1-x.md and its row and merges --no-ff into c2's line: the base;
#   REPO_CMZ (D1) over c2, the frozen commit adds zz/story-1-x.md, a directory created in the range, and repoints row 1-1 there;
#   REPO_CMS      over c2, the frozen commit moves the view to sprint 2 and adds s2's stories/story-1-x.md, created in the range;
#   REPO_CMSH (B2) REPO_CRH copied, its .git/shallow naming CRH_BASE; REPO_CMRP (B3) REPO_CRH copied, a replace ref pointing
#                 its root's view blob (which names story-1-y.md) at its base's.
cm_seed() { # <repo> -> c1 and c2 committed over new_repo's base
  new_repo "$1" old && mkdir -p "$1/.claude/team-roles" "$1/$CR_SDIR" "$1/${CR_VIEW%/*}" && cp "$QA_MD" "$1/.claude/team-roles/qa.md" \
    && printf -- '---\nstatus: review\n---\n# Story Y\n' > "$1/$CR_SDIR/story-1-y.md" \
    && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-y.md\n' > "$1/$CR_VIEW" \
    && G -C "$1" add -A && G -C "$1" commit -q -m c1 && printf -- '---\nstatus: review\n---\n# Story W\n' > "$1/$CR_SDIR/story-1-2-w.md" \
    && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-2:\n    status: review\n    file: stories/story-1-2-w.md\n' > "$1/$CR_VIEW" \
    && G -C "$1" add -A && G -C "$1" commit -q -m c2
}
cm_six() { local f; for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$1/test-results/$f" 5 "$f"; done; }
CM_ZZ=zz/story-1-x.md; CM_S2="${CR_SDIR%/s1/stories}/s2/stories/story-1-x.md"
REPO_CMH="$WORK/repo-cmh"; REPO_CMZ="$WORK/repo-cmz"; REPO_CMS="$WORK/repo-cms"; REPO_CMSH="$WORK/repo-cmsh"; REPO_CMRP="$WORK/repo-cmrp"
cm_seed "$REPO_CMH" && cm_h="$(G -C "$REPO_CMH" symbolic-ref -q --short HEAD)" && G -C "$REPO_CMH" checkout -q -b side \
  && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CMH/$CRB_STORY" \
  && printf '  story-1-1:\n    status: review\n    file: stories/story-1-x.md\n' >> "$REPO_CMH/$CR_VIEW" && G -C "$REPO_CMH" add -A \
  && ( export GIT_COMMITTER_DATE=2001-01-01T00:00:00 GIT_AUTHOR_DATE=2001-01-01T00:00:00; G -C "$REPO_CMH" commit -q -m side ) \
  && G -C "$REPO_CMH" checkout -q "$cm_h" && G -C "$REPO_CMH" merge -q --no-ff --no-edit side && cm_six "$REPO_CMH" \
  && G -C "$REPO_CMH" add -A && G -C "$REPO_CMH" commit -q -m frozen \
  && cm_seed "$REPO_CMZ" && mkdir -p "$REPO_CMZ/zz" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CMZ/$CM_ZZ" \
  && printf '  story-1-1:\n    status: review\n    file: ../../zz/story-1-x.md\n' >> "$REPO_CMZ/$CR_VIEW" && cm_six "$REPO_CMZ" \
  && G -C "$REPO_CMZ" add -A && G -C "$REPO_CMZ" commit -q -m frozen \
  && cm_seed "$REPO_CMS" && mkdir -p "$REPO_CMS/${CM_S2%/*}" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CMS/$CM_S2" \
  && printf 'sprint: 2\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: ../planning-artifacts/s2/stories/story-1-x.md\n' > "$REPO_CMS/$CR_VIEW" \
  && cm_six "$REPO_CMS" && G -C "$REPO_CMS" add -A && G -C "$REPO_CMS" commit -q -m frozen \
  && cp -R "$REPO_CRH" "$REPO_CMSH" && printf '%s\n' "$CRH_BASE" > "$REPO_CMSH/.git/shallow" && cp -R "$REPO_CRH" "$REPO_CMRP" \
  && G -C "$REPO_CMRP" replace "$(G -C "$REPO_CMRP" rev-parse "${CRH_BASE}~1:$CR_VIEW")" "$(G -C "$REPO_CMRP" rev-parse "${CRH_BASE}:$CR_VIEW")" \
  || { echo "FIXTURE ERROR: the merge's history-trust repos were not seeded" >&2; exit 2; }
CMH_BASE="$(G -C "$REPO_CMH" rev-parse HEAD~1)"; CMH_SHA="$(G -C "$REPO_CMH" rev-parse HEAD)"
CMZ_BASE="$(G -C "$REPO_CMZ" rev-parse HEAD~1)"; CMZ_SHA="$(G -C "$REPO_CMZ" rev-parse HEAD)"
CMS_BASE="$(G -C "$REPO_CMS" rev-parse HEAD~1)"; CMS_SHA="$(G -C "$REPO_CMS" rev-parse HEAD)"
# REPO_CMR (BL-895 U1h, T1 on the MERGE): over c2, the BASE is a faked roll (the view moved to sprint 2 and listing only
# story-7, a key whose sprint-stripped stem cannot resolve into s2's directory, so the row binding cannot refuse first);
# the frozen commit adds s2's stories/story-1-x.md (the directory created there), its row and the six test-results files.
# The view reads sprint 2 at both ends and the shard directory sits under docs/reviews/s1/shards/ (WSLOT=1): REFUSED.
REPO_CMR="$WORK/repo-cmr"
cm_seed "$REPO_CMR" \
  && printf 'sprint: 2\nstatus: in_progress\nstories:\n  story-7:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-7-q.md\n' > "$REPO_CMR/$CR_VIEW" \
  && G -C "$REPO_CMR" add -A && G -C "$REPO_CMR" commit -q -m roll \
  && mkdir -p "$REPO_CMR/${CM_S2%/*}" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CMR/$CM_S2" \
  && printf '  story-1-1:\n    status: review\n    file: ../planning-artifacts/s2/stories/story-1-x.md\n' >> "$REPO_CMR/$CR_VIEW" \
  && cm_six "$REPO_CMR" && G -C "$REPO_CMR" add -A && G -C "$REPO_CMR" commit -q -m frozen \
  || { echo "FIXTURE ERROR: the merge's faked-roll repo was not seeded" >&2; exit 2; }
CMR_BASE="$(G -C "$REPO_CMR" rev-parse HEAD~1)"; CMR_SHA="$(G -C "$REPO_CMR" rev-parse HEAD)"
# REPO_CMR is the TWO-commit shape (c2 drops story-1-y.md's row in sprint 1, the base moves the sprint). REPO_CMR1, the
# ONE-commit shape: over c1 (y listed), one commit drops y's row AND moves the view to sprint 2: the base. REPO_CMR3, T1c:
# REPO_CMR's base also creates s2's stories directory with a placeholder story-9-pad.md and its row, so the directory
# exists at the base. Each frozen commit is REPO_CMR's: s2's story-1-x.md, its row and the six test-results files.
REPO_CMR1="$WORK/repo-cmr1"; REPO_CMR3="$WORK/repo-cmr3"; CM_S2PAD="${CM_S2%/*}/story-9-pad.md"
cmr_frozen() { mkdir -p "$1/${CM_S2%/*}" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$1/$CM_S2" \
  && printf '  story-1-1:\n    status: review\n    file: ../planning-artifacts/s2/stories/story-1-x.md\n' >> "$1/$CR_VIEW" \
  && cm_six "$1" && G -C "$1" add -A && G -C "$1" commit -q -m frozen; }
cm_seed "$REPO_CMR1" && G -C "$REPO_CMR1" reset -q --hard HEAD~1 \
  && printf 'sprint: 2\nstatus: in_progress\nstories:\n  story-7:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-7-q.md\n' > "$REPO_CMR1/$CR_VIEW" \
  && G -C "$REPO_CMR1" add -A && G -C "$REPO_CMR1" commit -q -m roll && cmr_frozen "$REPO_CMR1" \
  && cm_seed "$REPO_CMR3" && mkdir -p "$REPO_CMR3/${CM_S2PAD%/*}" && printf -- '---\nstatus: ready-for-dev\n---\n# pad\n' > "$REPO_CMR3/$CM_S2PAD" \
  && printf 'sprint: 2\nstatus: in_progress\nstories:\n  story-7:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-7-q.md\n  story-9:\n    status: ready-for-dev\n    file: ../planning-artifacts/s2/stories/story-9-pad.md\n' > "$REPO_CMR3/$CR_VIEW" \
  && G -C "$REPO_CMR3" add -A && G -C "$REPO_CMR3" commit -q -m roll && cmr_frozen "$REPO_CMR3" \
  || { echo "FIXTURE ERROR: the merge's one-commit or T1c faked-roll repo was not seeded" >&2; exit 2; }
CMR1_BASE="$(G -C "$REPO_CMR1" rev-parse HEAD~1)"; CMR1_SHA="$(G -C "$REPO_CMR1" rev-parse HEAD)"
CMR3_BASE="$(G -C "$REPO_CMR3" rev-parse HEAD~1)"; CMR3_SHA="$(G -C "$REPO_CMR3" rev-parse HEAD)"
_cmr1p="$(G -C "$REPO_CMR1" show "${CMR1_BASE}~1:$CR_VIEW")" || _cmr1p=""; _cmr1b="$(G -C "$REPO_CMR1" show "${CMR1_BASE}:$CR_VIEW")" || _cmr1b=""
grep -qF 'stories/story-1-y.md' <<<"$_cmr1p" && ! grep -qF 'story-1-y.md' <<<"$_cmr1b" && grep -qx 'sprint: 2' <<<"$_cmr1b" \
  && [ "$(G -C "$REPO_CMR1" diff --name-only "$CMR1_BASE" "$CMR1_SHA" | grep -c .)" = 8 ] \
  && G -C "$REPO_CMR3" cat-file -e "${CMR3_BASE}:$CM_S2PAD" && ! G -C "$REPO_CMR3" cat-file -e "${CMR3_BASE}~1:${CM_S2%/*}" 2> /dev/null \
  && [ "$(G -C "$REPO_CMR3" diff --name-only "$CMR3_BASE" "$CMR3_SHA" | grep -c .)" = 8 ] \
  || { echo "FIXTURE STALE: REPO_CMR1's base is not one commit dropping y and moving to sprint 2 over a view listing y, or REPO_CMR3's base does not create s2's stories directory, or a range is not eight paths" >&2; exit 2; }
[ "$(G -C "$REPO_CMR" show "${CMR_BASE}:$CR_VIEW" | sed -n 's/^sprint: //p')" = 2 ] && [ "$(G -C "$REPO_CMR" show "${CMR_BASE}~1:$CR_VIEW" | sed -n 's/^sprint: //p')" = 1 ] \
  && [ "$(G -C "$REPO_CMR" diff --name-only "$CMR_BASE" "$CMR_SHA" | grep -c .)" = 8 ] && ! G -C "$REPO_CMR" cat-file -e "${CMR_BASE}:${CM_S2%/*}" 2> /dev/null \
  || { echo "FIXTURE STALE: REPO_CMR's base is not a sprint-2 roll over sprint 1, or its range is not the eight paths with s2's directory created in it" >&2; exit 2; }
# REPO_CMV and REPO_CMQ (BL-895 U1h, the merge): a base installing qa.md, story-1-2-w.md and a sprint-1 view listing it
# (no history under index 1). CMV's frozen commit adds CRB_STORY in sprint 1's directory, its row, and moves the view's
# `sprint:` to 2; CMQ's adds q1/stories/story-1-x.md and its row under sprint 1. Each adds the six test-results files.
CM_Q1="${CR_SDIR%/s1/stories}/q1/stories/story-1-x.md"
cm_base() { new_repo "$1" old && mkdir -p "$1/.claude/team-roles" "$1/$CR_SDIR" "$1/${CR_VIEW%/*}" && cp "$QA_MD" "$1/.claude/team-roles/qa.md" \
  && printf -- '---\nstatus: review\n---\n# Story W\n' > "$1/$CR_SDIR/story-1-2-w.md" \
  && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-2:\n    status: review\n    file: stories/story-1-2-w.md\n' > "$1/$CR_VIEW" \
  && G -C "$1" add -A && G -C "$1" commit -q --amend -m base; }
REPO_CMV="$WORK/repo-cmv"; REPO_CMQ="$WORK/repo-cmq"
cm_base "$REPO_CMV" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CMV/$CRB_STORY" \
  && printf 'sprint: 2\nstatus: in_progress\nstories:\n  story-1-2:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-2-w.md\n  story-1-1:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-x.md\n' > "$REPO_CMV/$CR_VIEW" \
  && cm_six "$REPO_CMV" && G -C "$REPO_CMV" add -A && G -C "$REPO_CMV" commit -q -m frozen \
  && cm_base "$REPO_CMQ" && mkdir -p "$REPO_CMQ/${CM_Q1%/*}" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$REPO_CMQ/$CM_Q1" \
  && printf '  story-1-1:\n    status: review\n    file: ../planning-artifacts/q1/stories/story-1-x.md\n' >> "$REPO_CMQ/$CR_VIEW" \
  && cm_six "$REPO_CMQ" && G -C "$REPO_CMQ" add -A && G -C "$REPO_CMQ" commit -q -m frozen \
  || { echo "FIXTURE ERROR: the merge's view-sprint or schema-env repo was not seeded" >&2; exit 2; }
CMV_BASE="$(G -C "$REPO_CMV" rev-parse HEAD~1)"; CMV_SHA="$(G -C "$REPO_CMV" rev-parse HEAD)"
CMQ_BASE="$(G -C "$REPO_CMQ" rev-parse HEAD~1)"; CMQ_SHA="$(G -C "$REPO_CMQ" rev-parse HEAD)"
[ "$(G -C "$REPO_CMV" diff --name-only "$CMV_BASE" "$CMV_SHA" | grep -c .)" = 8 ] && [ "$(G -C "$REPO_CMQ" diff --name-only "$CMQ_BASE" "$CMQ_SHA" | grep -c .)" = 8 ] \
  && [ "$(G -C "$REPO_CMV" show "${CMV_SHA}:$CR_VIEW" | sed -n 's/^sprint: //p')" = 2 ] && [ "$(G -C "$REPO_CMV" show "${CMV_BASE}:$CR_VIEW" | sed -n 's/^sprint: //p')" = 1 ] \
  && [ "$(G -C "$REPO_CMQ" show "${CMQ_SHA}:$CR_VIEW" | sed -n 's/^sprint: //p')" = 1 ] \
  || { echo "FIXTURE STALE: REPO_CMV or REPO_CMQ is not eight paths over its base, or its views do not read the sprints its cell names" >&2; exit 2; }
_cmhs="$(G -C "$REPO_CMH" rev-parse "${CMH_BASE}^2")" || _cmhs=""
[ -n "$_cmhs" ] && [ "$(G -C "$REPO_CMH" log -1 --format=%cd --date=format:%Y "$_cmhs")" = 2001 ] \
  && [ "$(G -C "$REPO_CMH" diff --name-only "$CMH_BASE" "$CMH_SHA" | grep -c '^test-results/')" = 6 ] \
  && [ "$(G -C "$REPO_CMZ" diff --name-only "$CMZ_BASE" "$CMZ_SHA" | grep -c .)" = 8 ] && ! G -C "$REPO_CMZ" cat-file -e "${CMZ_BASE}:zz" 2> /dev/null \
  && [ "$(G -C "$REPO_CMS" diff --name-only "$CMS_BASE" "$CMS_SHA" | grep -c .)" = 8 ] \
  && _cmrv="$(G -C "$REPO_CMRP" show "${CRH_BASE}~1:$CR_VIEW")" && _cmrn="$(GIT_NO_REPLACE_OBJECTS=1 G -C "$REPO_CMRP" show "${CRH_BASE}~1:$CR_VIEW")" \
  && [ "$(G -C "$REPO_CMSH" rev-parse --is-shallow-repository)" = true ] && ! grep -qF story-1-y.md <<<"$_cmrv" \
  && grep -qF story-1-y.md <<<"$_cmrn" \
  || { echo "FIXTURE STALE: a merge history-trust repo (CMH, CMZ, CMS, the shallow or replaced copy of REPO_CRH) does not have the shape its cell names" >&2; exit 2; }
# Role text (BL-742): each serial seat is told to run --check-serial before returning. Keyed on the
# command spelling in each role file's serial passage.
SR_ROLE_CMD='merge-review-shards.sh --check-serial'
p_serial_role() { # <qa.md> <code-reviewer.md>
  local nq nc
  nq="$(grep -cF -- "$SR_ROLE_CMD <validation file> --gate qa" "$1")" || nq=0
  nc="$(grep -cF -- "$SR_ROLE_CMD <review file> --gate code-review" "$2")" || nc=0
  [ "$nq" -ge 1 ] && [ "$nc" -ge 1 ]
}

# ------------------------------------------------------------------------------------ BL-808
# --exclude-captures. One cell per predicate, so each mutant runs exactly its owner. Failures land in
# WHY as `xc-<cell>{want ... got ...}`; mut_run keys each kill on a token only that cell can print.
xc_serial() { # <file> -> the SERIAL line, or empty
  grep '^SERIAL: ' "$1" 2>/dev/null | head -1
}
p_xc_merge() { # (i) X_BASE..X1: DFLT+2 counted after ten captures leave the count -> partitions WITH
  # the flag into a shard dir, and the merge's FLAGLESS re-derivation accepts the set it recorded.
  local sd="$1" w d o k n
  WHY=""; cell xc-merge || return 0
  w="$(wdir)" || { WHY="xc-merge{the work dir was not made}"; return 1; }
  d="$w/1-code-review-$X1_SHA12"
  ip_run "$sd/partition-review-diff.sh" prd_main --map "$REPO_X" "$X_BASE" "$X1_SHA" --exclude-captures "$XC_ALL" \
    --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null; k=$?
  n="$(grep -cE '^[0-9]+	' "$w/map")" || n=0
  [ "$k" -eq 0 ] && [ "$n" -ge 2 ] && [ -f "$d/.manifest" ] \
    || { WHY="xc-merge{want a flagged partition of >= 2 parts got rc=$k parts=$n [$(head -1 "$w/map") $(head -1 "$w/map.err")]}"; return 1; }
  # F2: no manifest line records the exclusion (it would join the manifest cmp at re-run).
  n="$(grep -c 'exclude' "$d/.manifest")" || n=0
  [ "$n" -eq 0 ] || { WHY="xc-manifest{want no exclude key in the manifest got $n line(s)}"; return 1; }
  for k in $(cut -f1 "$w/map"); do shard "$d" "$k" APPROVED "$k" "$X1_SHA"; done
  ( SHARD_SHA="$X1_SHA"; xshards "$sd" "$d" APPROVED ) || { WHY="xc-merge{the cross shards were not written}"; return 1; }
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] \
    || { WHY="xc-merge{want MERGED got rc=$RC [$(grep -m1 'REFUSED' "$MO")]}"; return 1; }
}
p_xc_flip() { # (iii) X_BASE..X2: DFLT-1 code + 10 captures. Flagless partitions; flagged answers
  # SERIAL exit 3 naming the ten, and writes no shard dir.
  local sd="$1" d n want got
  WHY=""; cell xc-flip || return 0
  d="$(mktemp -d "$WORK/xflip.XXXXXX")/sd"
  run_part "$sd" "$REPO_X" "$X_BASE" "$X2_SHA"
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ] || { WHY="xc-flip-ctl{want the flagless run to partition got rc=$PRC parts=$n}"; return 1; }
  run_part "$sd" "$REPO_X" "$X_BASE" "$X2_SHA" --exclude-captures "$XC_ALL" --shard-dir "$d"
  want="rc=3 SERIAL: $((DFLT - 1)) reviewable file(s) ($((DFLT + 9)) in the diff, scan roots excluded, 10 cited capture(s) not counted), below the threshold of $DFLT dir=n"
  got="rc=$PRC $(xc_serial "$PO" | sed 's/ (the built-in default.*//') dir=$([ -e "$d" ] && echo y || echo n)"
  [ "$want" = "$got" ] || { WHY="xc-flip{want '$want' got '$got'}"; return 1; }
}
p_xc_count() { # (iv) X_BASE..X3 under --min-files 100 (SERIAL either way, so the count is printed):
  # the seeded list (nine LF lines, cap10 ONLY as CRLF, an out-of-diff path, the scan-root path, a
  # duplicate) excludes its INTERSECTION, 10, never its length 13; the `./` list in the same arm
  # excludes 0 -- the count moves 0 -> 10 on the spelling alone.
  local sd="$1" a b wa wb
  WHY=""; cell xc-count || return 0
  run_part "$sd" "$REPO_X" "$X_BASE" "$X3_SHA" --min-files 100 --exclude-captures "$XC_DOT"
  a="rc=$PRC $(xc_serial "$PO" | sed 's/, below the threshold.*//')"
  run_part "$sd" "$REPO_X" "$X_BASE" "$X3_SHA" --min-files 100 --exclude-captures "$XC_SEED"
  b="rc=$PRC $(xc_serial "$PO" | sed 's/, below the threshold.*//')"
  wa="rc=3 SERIAL: $((DFLT + 9)) reviewable file(s) ($((DFLT + 10)) in the diff, scan roots excluded, 0 cited capture(s) not counted)"
  wb="rc=3 SERIAL: $((DFLT - 1)) reviewable file(s) ($((DFLT + 10)) in the diff, scan roots excluded, 10 cited capture(s) not counted)"
  [ "$a" = "$wa" ] && [ "$b" = "$wb" ] || { WHY="xc-count{want '$wa' / '$wb' got '$a' / '$b'}"; return 1; }
}
p_xc_one() { # (C8) Y_BASE..Y1: one code file + five captures under --min-files 1. Flagless it
  # partitions; flagged it is SERIAL on the one-file rule. Y_BASE..Y2 (two code files) still shards.
  local sd="$1" n want got
  WHY=""; cell xc-one || return 0
  run_part "$sd" "$REPO_Y" "$Y_BASE" "$Y1_SHA" --min-files 1
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ] || { WHY="xc-one-ctl{want the flagless one-file run to partition got rc=$PRC parts=$n}"; return 1; }
  run_part "$sd" "$REPO_Y" "$Y_BASE" "$Y1_SHA" --min-files 1 --exclude-captures "$XC_Y"
  want="rc=3 SERIAL: 1 reviewable file(s) (6 in the diff, scan roots excluded, 5 cited capture(s) not counted); a review of at most one counted file is never sharded, whatever the threshold"
  got="rc=$PRC $(xc_serial "$PO")"
  [ "$want" = "$got" ] || { WHY="xc-one{want '$want' got '$got'}"; return 1; }
  run_part "$sd" "$REPO_Y" "$Y_BASE" "$Y2_SHA" --min-files 1 --exclude-captures "$XC_Y"
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ] || { WHY="xc-two{want two counted files to shard got rc=$PRC parts=$n}"; return 1; }
}
p_xc_missing() { # a list file that does not exist -> REFUSED exit 2, nothing on stdout, no manifest
  local sd="$1" d
  WHY=""; cell xc-missing || return 0
  d="$(mktemp -d "$WORK/xmiss.XXXXXX")/sd"
  run_part "$sd" "$REPO_X" "$X_BASE" "$X1_SHA" --exclude-captures "$WORK/xc-no-such-list" --shard-dir "$d"
  part_refused "--exclude-captures file $WORK/xc-no-such-list is not a readable file" "$d" \
    || { WHY="xc-missing{want REFUSED exit 2 got rc=$PRC [$(head -1 "$PE")]}"; return 1; }
}

# Seed controls: the worlds must be able to express what the arms are named for. Both callers run
# them before any arm or mutant verdict is read.
seed_controls() { # TPL0, W0, W1, W2, W3, W4, SW0
local A_NAMES A_REV na nn n1 c1 c0 nb ns nr0 nr1 pf tw1 tw2 tb0 th0 tb1 th1 tb2 th2 tp tpw
# TPL0: the world cache. One tuple built twice: the first a real partition run (builds +1, hits +0),
# the second a clone (builds +0, hits +1), byte-equal in map, map.err and manifest. And the bypass: a
# script dir whose partition differs from SRCDIR's by one byte builds its own world, never the cache's.
tb0="$(tpl_n builds)"; th0="$(tpl_n hits)"
tw1="$(kworld "$SRCDIR" "$REPO_B" "$B_BASE" "$B_SHA" 2 tplprobe APPROVED)"; tb1="$(tpl_n builds)"; th1="$(tpl_n hits)"
tw2="$(kworld "$SRCDIR" "$REPO_B" "$B_BASE" "$B_SHA" 2 tplprobe APPROVED)"; tb2="$(tpl_n builds)"; th2="$(tpl_n hits)"
# The bypass copy: the world scripts and every sibling the partition resolves that SRCDIR holds.
tp="$WORK/tpl-bypass"; mkdir "$tp" && for _f in $WORLD_SCRIPTS; do
  [ ! -f "$SRCDIR/$_f" ] || cp "$SRCDIR/$_f" "$tp/$_f"; done
printf '# one byte\n' >> "$tp/partition-review-diff.sh"
tpw="$(kworld "$tp" "$REPO_B" "$B_BASE" "$B_SHA" 2 tplprobe APPROVED)"
# The partition differs, so its world is rebuilt (builds +1); partition-document.sh does not, so the
# cross-group table is still a clone (hits +1).
if [ -n "$tw1" ] && [ -n "$tw2" ] && [ "$tw1" != "$tw2" ] && [ $((tb1 - tb0)) = 2 ] && [ $((th1 - th0)) = 0 ] \
   && [ $((tb2 - tb1)) = 0 ] && [ $((th2 - th1)) = 2 ] \
   && cmp -s "$tw1/.manifest" "$tw2/.manifest" && cmp -s "$(dirname "$tw1")/map" "$(dirname "$tw2")/map" \
   && cmp -s "$(dirname "$tw1")/map.err" "$(dirname "$tw2")/map.err" && grep -q '^part	' "$tw2/.manifest" \
   && [ -n "$tpw" ] && [ $(( $(tpl_n builds) - tb2 )) = 1 ] && [ $(( $(tpl_n hits) - th2 )) = 1 ] \
   && ! tpl_ok "$tp" $WORLD_SCRIPTS && tpl_ok "$SRCDIR" $WORLD_SCRIPTS; then
  ok "TPL0: the world cache serves a repeated world as a byte-equal clone (map, map.err, manifest), runs the partition for the first build only, and a script dir whose partition is one byte off SRCDIR's runs its own partition"
else
  bad "TPL0: FIXTURE BROKEN -- the world cache did not build once and clone after, or served a differing script dir (builds $tb0 $tb1 $tb2 $(tpl_n builds), hits $th0 $th1 $th2 $(tpl_n hits))"
fi
A_NAMES="$(G -C "$REPO_A" diff --name-only "$A_BASE..$A_SHA")"
A_REV="$(grep -v '^docs/reviews/' <<<"$A_NAMES")"
na="$(grep -c . <<<"$A_REV")" || na=0
nn="$(grep -vc '^app/' <<<"$A_REV")" || nn=0
if [ "$na" -eq 6 ] && [ "$nn" -eq 0 ]; then
  ok "W0: repo A's 6 reviewable files all sit under app/, so a first-path-component key has one group"
else
  bad "W0: FIXTURE BROKEN -- repo A has $na reviewable file(s), $nn outside app/; P1 cannot discriminate"
fi
if n1="$(printf '## Verdict\nAPPROVED\n' > "$WORK/ctl.md"; check1_count "$WORK/ctl.md")" && [ "$n1" = "1" ] \
   && [ "$(check1_value "$WORK/ctl.md")" = "APPROVED" ]; then
  ok "W1: the derived Check 1 pattern matches a bare '## Verdict' heading once and reads APPROVED off the next line"
else
  bad "W1: FIXTURE BROKEN -- the derived Check 1 pattern [$PAT] does not read a seeded '## Verdict / APPROVED'"
fi
# Gate 2: the seeded per-AC table row must not be what Check 1 counts, or Q2 is vacuous.
if printf '| AC | Verdict | Evidence |\n| AC2 | NEEDS_REWORK | replay |\n' > "$WORK/qctl.md" && [ "$(check1_count "$WORK/qctl.md")" = "0" ] \
   && printf '## Acceptance Criteria\n**Verdict:** PASS\n' > "$WORK/qctl2.md" && [ "$(check1_count "$WORK/qctl2.md")" = "1" ]; then
  ok "W2: Check 1's derived pattern matches 0 pipe-led per-AC table rows and 1 bold 'Verdict:' label, so Q2's single match is the merge's own"
else
  bad "W2: FIXTURE BROKEN -- Check 1's pattern [$PAT] counts a pipe-led AC row, or misses a bold label; Q2 cannot discriminate"
fi
# W3: the engines at the frozen shas. The subject carries the sentinel once, the derived old engine
# none; B's frozen sha holds the old one (consumer layout), S's the subject (distribution layout), N's
# neither -- and N's commit IS readable (its README), so "absent" is not "unreadable".
c1="$(grep -c '# MARK-KEY-WRITER v1' "$WFD_SRC")" || c1=0
c0="$(grep -c '# MARK-KEY-WRITER v1' "$OLD_ENGINE")" || c0=0
nb="$(G -C "$REPO_B" show "${B_SHA}:scripts/ai-dlc/wait-for-deliverable.sh" 2>/dev/null | grep -c '# MARK-KEY-WRITER v1')" || nb=0
ns="$(G -C "$REPO_S" show "${S_SHA}:core/scripts/wait-for-deliverable.sh" 2>/dev/null | grep -c '# MARK-KEY-WRITER v1')" || ns=0
if [ "$c1" = 1 ] && [ "$c0" = 0 ] && ! cmp -s "$WFD_SRC" "$OLD_ENGINE" && [ "$nb" = 0 ] && [ "$ns" = 1 ] \
   && G -C "$REPO_B" cat-file -e "${B_SHA}:scripts/ai-dlc/wait-for-deliverable.sh" 2>/dev/null \
   && ! G -C "$REPO_N" cat-file -e "${N_SHA}:scripts/ai-dlc/wait-for-deliverable.sh" 2>/dev/null \
   && ! G -C "$REPO_N" cat-file -e "${N_SHA}:core/scripts/wait-for-deliverable.sh" 2>/dev/null \
   && G -C "$REPO_N" cat-file -e "${N_SHA}:README" 2>/dev/null; then
  ok "W3: the subject's --mark carries the sentinel once and the derived old engine none; B's frozen sha holds the old engine, S's the sentinel engine, N's neither (N's README read as the control)"
else
  bad "W3: FIXTURE BROKEN -- the engine blobs cannot express the legacy rule (subject $c1, old $c0, at B $nb, at S $ns)"
fi
# W4: the recorder writes. MAIN's sourced copy is the subject's bytes; a fire on a review-shard path
# appends one row carrying path, physical root and body_sha; a fire on a path outside the sealed sets
# appends none (the control that the count can stay put).
pf="$MAIN/docs/reviews/s0.probe/shards/1-code-review-$B_SHA12/1.md"; mkdir -p "$(dirname "$pf")" && printf '# probe\n' > "$pf"
nr0="$(grep -c . "$LEDGER" 2>/dev/null)" || nr0=0
printf 'x\n' > "$MAIN/notes.md"; fire "$MAIN/notes.md" agent; nr1="$(grep -c . "$LEDGER" 2>/dev/null)" || nr1=0
if cmp -s "$SEAL_SRC" "$MAIN/scripts/ai-dlc/content-seal.sh" && cmp -s "$SEAL_SRC" "$DMAIN/core/scripts/content-seal.sh" \
   && [ "$nr1" = "$nr0" ] && fire "$pf" agent \
   && [ "$(jq -c --arg r "$MAIN" 'select(.path == "docs/reviews/s0.probe/shards/1-code-review-'"$B_SHA12"'/1.md" and .root == $r and has("body_sha"))' "$LEDGER" | grep -c .)" = 1 ]; then
  ok "W4: the recorder hook, fired with a seat's payload, appends one review-shard row (path, physical root, body_sha) to the main checkout's ledger, and none for a path outside the sealed sets"
else
  bad "W4: FIXTURE BROKEN -- the recorder hook did not write the review-shard row the seal arms read (rows $nr0 -> $nr1 on a non-shard path)"
fi
# SW0: the sealed-world cache. The first seal_world builds (builds +1) and the second copies (hits +1) with its
# rows relocated: the copy merges, as a fresh build does. The control is the same copy with its relocated rows
# removed from the ledger, which the merge refuses as carrying no content-seal row -- so the copy merges
# BECAUSE of the relocated rows, not because seal checking found nothing to check.
local sb0 sh0 sw1 sw2 swo swl
sb0="$(tpl_n builds)"; sh0="$(tpl_n hits)"
sw1="$(seal_world "$SRCDIR" code-review)"; sw2="$(seal_world "$SRCDIR" code-review)"
run_merge "$SRCDIR" "$sw2"; swo="rc=$RC $(head -1 "$MO")"
swl="${sw2#"$MAIN"/}"; grep -vF "\"path\":\"$swl/" "$LEDGER" > "$WORK/sw0.ledger"; cp "$LEDGER" "$WORK/sw0.keep"
cat "$WORK/sw0.ledger" > "$LEDGER"; rm -f "$(out_of "$sw2")"; run_merge "$SRCDIR" "$sw2"; cat "$WORK/sw0.keep" > "$LEDGER"
if [ -n "$sw1" ] && [ -n "$sw2" ] && [ "$sw1" != "$sw2" ] && [ $(( $(tpl_n builds) - sb0 )) -ge 1 ] && [ $(( $(tpl_n hits) - sh0 )) -ge 1 ] \
   && case "$swo" in "rc=0 MERGED:"*) true ;; *) false ;; esac \
   && refused_clean "carries no content-seal row" "$sw2"; then
  ok "SW0: a sealed world is built once and copied after: the copy, its ledger rows relocated, merges; without those rows the same copy is REFUSED for carrying no content-seal row"
else
  bad "SW0: FIXTURE BROKEN -- the sealed-world copy did not merge, or merged without its relocated rows (copy: $swo; rows removed: rc=$RC $(head -1 "$MO"))"
fi
rm -f "$(out_of "$sw2")"
}

# ---- REUSE PROOF (--matrix only; a plain run never executes it). Every top-level arm that reads another arm's saved
# answer (hand_use) is run here a second time as ITS OWN merge in ITS OWN world, and the two answers are cmp'd: rc, merge
# stdout+stderr and the written --out file, with only the mktemp paths normalised. A pair prints `REUSE <arm>
# reads=<source> EQUAL` or fails as DIFFER; a DIFFER row is restored to its own merge and classed (a) with the differing
# input named. The self-probe pairs a class-(a) state (a shard directory whose name carries another sha12 than the
# manifest) with the all-APPROVED answer it would otherwise read: it must score DIFFER, or the proof reports BROKEN.
ru_mk_ap4() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_nr3() { D="$(world4 "$SRCDIR" NEEDS_REWORK APPROVED NEEDS_REWORK NEEDS_REWORK)" || return 1; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_qp4() { D="$(qworld "$SRCDIR" PASS PASS PASS PASS)" || return 1; O="$(qout "$D")"; q_merge "$SRCDIR" "$D"; }
ru_mk_k8() { SHARD_SHA="$E_SHA"; D="$(kworld "$SRCDIR" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_xdup() { SHARD_SHA="$E_SHA"; D="$(kworld "$SRCDIR" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  xfinding "$D/cross-3.md" F-dup "1, 2" && xfinding "$D/cross-1.md" F-own "1, 2" || return 1; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_partcite() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; shard "$D" 2 APPROVED 3; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_miss() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; rm -f "$D/2.md"; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_dup() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; cp "$D/1.md" "$D/01.md"; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_a3() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; shard "$D" 2 APPROVED 2 "" "$(printf '## Verdict\nAPPROVED')"; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_g3() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; crs "$D" 2 APPROVED 2 1 "$(crho 2 AC7)"; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_g4() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; crs "$D" 2 APPROVED 2 1 "$(crho 2 AC7)"
  crs "$D" cross-1 APPROVED "1, 2" - "$(printf '%s\n\n%s' "$(crrun 2 '2 AC7 RED')" "$(crrun 2 '2 AC7 RED' | sed 's/F-cross-H/F-cross-H2/')")"; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_qpmset() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; O="$(qout "$D" code-review -p2)"; run_mg "$SRCDIR" "$D" code-review "$O"; }
ru_mk_seal() { D="$(seal_world "$SRCDIR" code-review)" || return 1; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
ru_mk_frg() { SHARD_SHA="$QL_SHA"; D="$(fr_g_world "$SRCDIR" "$REPO_QL" "$QL_BASE" "$QL_SHA" 1)" || return 1; O="$(qout "$D")"; q_merge "$SRCDIR" "$D"; }
ru_mk_shadir() { D="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || return 1; local n; n="$(dirname "$D")/1-code-review-000000000000"; mv "$D" "$n"; D="$n"; O="$(out_of "$D")"; run_merge "$SRCDIR" "$D"; }
# ru_saved <name> <file>: the saved answer, as the reading arm sees it; ru_own <builder> <file>: the arm's own merge.
# The LEGACY-UNRECORDED line names the record s<N>-<idx>, and a world's slot <N> is drawn per world (wdir), so it is
# normalised like the directory it comes from.
ru_norm() { sed -e "s|$1|DIR|g" -e "s|$WORK|WORK|g" -e 's/(s9[0-9]*-/(sSLOT-/g'; }
ru_saved() {
  local dd; dd="$(cat "$HAND/$1.d" 2>/dev/null)"; [ -f "$HAND/$1.mo" ] && [ -n "$dd" ] || return 1
  { echo "rc=$(cat "$HAND/$1.rc")"; ru_norm "$(dirname "$dd")" < "$HAND/$1.mo"
    if [ -f "$HAND/$1.out" ]; then ru_norm "$(dirname "$dd")" < "$HAND/$1.out"; else echo NO-OUT-FILE; fi; } > "$2"
}
ru_own() {
  ( D=""; O=""; "$1" || exit 1
    { echo "rc=$RC"; ru_norm "$(dirname "$D")" < "$MO"
      if [ -f "$O" ]; then ru_norm "$(dirname "$D")" < "$O"; else echo NO-OUT-FILE; fi; } > "$2" )
}
# ru_pair <arm> <source> <saved name> <builder> -> prints EQUAL, DIFFER or BROKEN
ru_pair() {
  local t="$WORK/ru.$1"; mkdir -p "$t"
  ru_saved "$3" "$t/saved" && ru_own "$4" "$t/own" && [ -s "$t/saved" ] && [ -s "$t/own" ] || { echo BROKEN; return; }
  if cmp -s "$t/saved" "$t/own"; then echo EQUAL; else echo DIFFER; fi
}
ru_row() { # <arm> <source> <saved name> <builder>
  local r; r="$(ru_pair "$1" "$2" "$3" "$4")"
  case "$r" in
    EQUAL) ok "REUSE $1 reads=$2 EQUAL" ;;
    *) bad "REUSE $1 reads=$2 $r (restore the arm's own merge and class it (a), naming the input that differs)" ;;
  esac
}
reuse_proof() {
  ru_row conserve c1 c1 ru_mk_nr3
  ru_row rerun worst3 worst3 ru_mk_ap4
  ru_row fence_nested worst3 worst3 ru_mk_ap4
  ru_row q_title-cr worst3 worst3 ru_mk_ap4
  ru_row q_title-qa q_worst1 qw1 ru_mk_qp4
  ru_row q_table q_worst1 qw1 ru_mk_qp4
  ru_row q_hc_none q_worst1 qw1 ru_mk_qp4
  ru_row canon_merge-crm-ok q_worst1 qw1 ru_mk_qp4
  ru_row x_owner-n0 x_k8 xk8 ru_mk_k8
  ru_row owner-per-shard cs_partcite cs_csc_partcite ru_mk_partcite
  ru_row owner-missing R1 own_miss ru_mk_miss
  ru_row owner-dup-key R3 own_dup ru_mk_dup
  ru_row owner-handover-unrun G3 own_cr_ho_unm ru_mk_g3
  ru_row owner-run-twice G4 own_cr_ho_runtwice ru_mk_g4
  ru_row owner-check1-multi R9 own_a3 ru_mk_a3
  ru_row owner-set-level q_pm own_qpm_set ru_mk_qpmset
  ru_row owner-dup-merge x_owner x_owner_dup ru_mk_xdup
  ru_row frb-legacy fr_graph frg_post ru_mk_frg
  ru_row session-control key key_ctl ru_mk_seal
  local p; p="$(ru_pair selfprobe-sha_dir worst3 worst3 ru_mk_shadir)"
  if [ "$p" = DIFFER ]; then ok "REUSE self-probe: a class-(a) sha_dir state against the all-APPROVED answer scores DIFFER"
  else bad "REUSE self-probe BROKEN: a class-(a) sha_dir state against the all-APPROVED answer scored $p, so every EQUAL above is unattributable"; fi
}

# ---- LR1 (BL-895 F1): THE LEAD'S RE-RUN, `--check-serial <file> --gate qa --story <f> --lead-range <seat base>
# <go-signal>`, its base the story's lead record written by `--record-dispatch` (merge-review-shards.sh header:
# CHECK-SERIAL, THE LEAD'S RE-RUN). REPO_LR, consumer-shaped, qa.md TRACKED, story-1-2-zz.md listed beside x:
#   LR_OLD     qa.md WITHOUT the serial reviewed-sha prescription and without the canonical-run label (an older install);
#   LR_D       the dispatch sha: qa.md is the subject's (both prescribed), story-1-1-x.md ready-for-dev and its row;
#   LR_F       the go-signal: x at review, six test-results files (record-only over LR_D..LR_F);
#   LR_RSTRIP  over LR_D, x at review AND qa.md with the reviewed-sha prescription stripped (qa.md inside the range);
#   LR_CSTRIP  over LR_D, x at review AND qa.md with the canonical-run label stripped (qa.md inside the range);
#   LR_OF      an orphan commit holding LR_F's tree over an orphan root holding LR_D's (a3: no history shared with LR_D).
# The review sits at <REPO_LR>/docs/reviews/s1/1-1-qa-validation.md, the path the lead assigned.
REPO_LR="$WORK/repo-lr"; LR_STORY="$CR_SDIR/story-1-1-x.md"; LR_RSENT='column-0 `reviewed-sha: <full go-signal sha>`'
LR_RV="$REPO_LR/docs/reviews/s1/1-1-qa-validation.md"
lr_c() { G -C "$REPO_LR" add -A && G -C "$REPO_LR" commit -q -m "$1" && G -C "$REPO_LR" rev-parse HEAD; }
lr_st() { printf -- '---\nstatus: %s\n---\n# Story 1\n' "$1" > "$REPO_LR/$LR_STORY"; }
lr_view() { printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: %s\n    file: stories/story-1-1-x.md\n  story-1-2:\n    status: ready-for-dev\n    file: stories/story-1-2-zz.md\n' "$1" > "$REPO_LR/$CR_VIEW"
  printf -- '---\nstatus: ready-for-dev\n---\n# Story 1.2\n' > "$REPO_LR/$CR_SDIR/story-1-2-zz.md"; }
lr_review() { lr_st review && lr_view review; }
mkdir -p "$REPO_LR/.claude/team-roles" "$REPO_LR/$CR_SDIR" "$REPO_LR/${CR_VIEW%/*}" "$REPO_LR/docs/reviews/s1" && G init -q "$REPO_LR" \
  && grep -vF -e "$LR_RSENT" -e 'column-0 `Canonical run:`' "$QA_MD" > "$REPO_LR/.claude/team-roles/qa.md" && lr_st ready-for-dev && lr_view ready-for-dev \
  && LR_OLD="$(lr_c old)" && cp "$QA_MD" "$REPO_LR/.claude/team-roles/qa.md" && LR_D="$(lr_c dispatch)" \
  && lr_review && lines "$REPO_LR/test-results/a1.txt" 5 a1 && lines "$REPO_LR/test-results/b1.txt" 5 b1 && LR_F="$(lr_c go)" \
  && G -C "$REPO_LR" checkout -q -b rstrip "$LR_D" && lr_review && grep -vF -- "$LR_RSENT" "$QA_MD" > "$REPO_LR/.claude/team-roles/qa.md" && LR_RSTRIP="$(lr_c rstrip)" \
  && G -C "$REPO_LR" checkout -q -b cstrip "$LR_D" && lr_review && grep -vF -- 'column-0 `Canonical run:`' "$QA_MD" > "$REPO_LR/.claude/team-roles/qa.md" && LR_CSTRIP="$(lr_c cstrip)" \
  && LR_OB="$(G -C "$REPO_LR" commit-tree -m ob "${LR_D}^{tree}")" && LR_OF="$(G -C "$REPO_LR" commit-tree -p "$LR_OB" -m of "${LR_F}^{tree}")" \
  && G -C "$REPO_LR" checkout -q --detach "$LR_F" \
  || { echo "FIXTURE ERROR: the lead re-run repo REPO_LR was not seeded" >&2; exit 2; }
lr_n() { local n; n="$(G -C "$REPO_LR" show "$1:.claude/team-roles/qa.md" | grep -cF -- "$2")" || n=0; printf '%s' "$n"; }
[ "$(lr_n "$LR_OLD" "$LR_RSENT")" = 0 ] && [ "$(lr_n "$LR_D" "$LR_RSENT")" = 1 ] && [ "$(lr_n "$LR_RSTRIP" "$LR_RSENT")" = 0 ] \
  && [ "$(lr_n "$LR_CSTRIP" 'column-0 `Canonical run:`')" = 0 ] && [ "$(lr_n "$LR_RSTRIP" 'column-0 `Canonical run:`')" -ge 1 ] \
  && G -C "$REPO_LR" merge-base --is-ancestor "$LR_OLD" "$LR_F" && ! G -C "$REPO_LR" merge-base --is-ancestor "$LR_D" "$LR_OF" \
  && [ "$(G -C "$REPO_LR" diff --name-only "$LR_D" "$LR_F" | grep -vc '^test-results/')" = 2 ] \
  || { echo "FIXTURE STALE: REPO_LR's qa.md eras, ancestry or range do not have the shape its cells name" >&2; exit 2; }
LR_REF="does not descend from the dispatch sha"; LR_RSHA="reviewed-sha:"; LR_UNREC="LEGACY-UNRECORDED: s1-1-1 has no dispatch record at"
# THE LEAD RECORD: REPO_LR's s1-1-1 record is written by the subject's own --record-dispatch (lr_rec, from the repo), and
# removed by lr_unrec for the LEGACY-UNRECORDED cells; LR_RECF is its path, derived from git, never hand-spelled twice.
LR_RECF="$(cd "$REPO_LR" && git rev-parse --git-common-dir)" && LR_RECF="$(cd "$REPO_LR" && cd "$LR_RECF" && pwd -P)/ai-dlc/stories/s1-1-1" \
  || { echo "FIXTURE ERROR: REPO_LR's git common dir did not resolve" >&2; exit 2; }
lr_rec() { # <script-dir> <sha> -> RRC, $CO: the dispatch record written by the subject, from REPO_LR
  rm -f "$LR_RECF"; ( cd "$REPO_LR" && ip_run "$1/merge-review-shards.sh" mrs_main --record-dispatch s1-1-1 "$2" ) > "$CO" 2>&1 < /dev/null; RRC=$?
}
lr_unrec() { rm -f "$LR_RECF"; }
LR_SLOT="is not at docs/reviews/s<N>/ in its own repository"; LR_LEG="LEGACY: reviewed-sha not checked:"
lr_file() { # <path> <canonical block> [reviewed-sha line, verbatim; `-` for none]
  mkdir -p "${1%/*}" || return 1
  { printf '# QA Validation: 1-1\n\n'; adv_l; [ "${3:--}" = - ] || printf '%s\n' "$3"
    printf '\n## Summary\nSerial.\n\n%s\n\n## Verdict\nPASS\n\n## Findings\n\n### Critical (must fix before PASS)\n\nNone.\n\n' "$2"
    printf '## Acceptance Criteria\n\n| AC | Result | Expected | Got |\n|---|---|---|---|\n| AC1 | PASS | x | y |\n'; } > "$1"
}
lr_run() { # <script-dir> <file> <seat base> <go-signal> -> SRC, $CO; LR_FLAG=--range is the seat's run; LR_ROOT the root
  ip_run -C "${LR_CWD:-$REPO_LR}" -e "AI_DLC_PROJECT_ROOT=${LR_ROOT:-$PROJ}" "$1/merge-review-shards.sh" mrs_main --check-serial "$2" --gate qa --story "$LR_STORY" "${LR_FLAG:---lead-range}" "$3" "$4" > "$CO" 2>&1 < /dev/null; SRC=$?
}
lr_no() { [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$2" && has "$CO" "$SR_OWN" && ! has "$CO" SERIAL-OK || WHY="$WHY $1{rc=$SRC $(head -2 "$CO" | tr '\n' ' ')}"; }
lr_ok() { [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: " || WHY="$WHY $1{rc=$SRC $(head -2 "$CO" | tr '\n' ' ')}"; }
# THE LEAD CHECKOUT (merge-review-shards.sh lead_checkout_only): the one remedy every such refusal names.
LR_LEADCO="run it again from the lead checkout (the repository the dev worktrees were added from); no re-dispatch is needed"
lr_lead() { [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$LR_LEADCO" && has "$CO" "--lead-range: the review's repository" \
  && has "$CO" "[owner: lead]" && ! has "$CO" SERIAL-OK && ! has "$CO" LEGACY-UNRECORDED || WHY="$WHY $1{rc=$SRC $(head -2 "$CO" | tr '\n' ' ')}"; }
lr_wt() { # LR_WT (a dev worktree added from REPO_LR at LR_F) and LR_CLONE (a --shared clone of REPO_LR), built once
  [ -z "${LR_WT:-}" ] || return 0
  LR_WT="$WORK/lr-wt"; LR_CLONE="$WORK/lr-clone"
  G -C "$REPO_LR" worktree add -q --detach "$LR_WT" "$LR_F" 2> /dev/null && G clone -q --shared "$REPO_LR" "$LR_CLONE" 2> /dev/null \
    && [ -f "$LR_WT/.git" ] || { WHY="$WHY FIXTURE ERROR: the a1 dev worktree or the seat's clone was not built"; LR_WT=""; return 1; }
}
p_lead() {
  local sd="$1" none='Canonical run: none, the diff is record-only (story, test-results)' o2
  WHY=""
  # Every lead cell first writes the dispatch record with the subject's own --record-dispatch (lr_rec) and passes `-` as
  # the seat base, so a record-present verdict cannot have read the seat base; lr-seatbase passes a WRONG seat base.
  # lr-record (ALLOW, the writer): --record-dispatch prints RECORDED naming the record path; a second call with another
  # sha prints RECORD-KEPT and leaves `dispatch:` unchanged; a --lead-range run then reads it back and passes.
  if cell lr-record; then lr_rec "$sd" "$LR_D"
    { [ "$RRC" = 0 ] && has "$CO" "RECORDED: $LR_RECF dispatch: $LR_D"; } || WHY="$WHY lr-record{write rc=$RRC $(head -1 "$CO")}"
    ( cd "$REPO_LR" && ip_run "$sd/merge-review-shards.sh" mrs_main --record-dispatch s1-1-1 "$LR_OLD" ) > "$CO" 2>&1 < /dev/null
    { has "$CO" "RECORD-KEPT: $LR_RECF dispatch: $LR_D" && [ "$(grep -c . "$LR_RECF" 2> /dev/null)" = 1 ] && grep -qxF "dispatch: $LR_D" "$LR_RECF"; } \
      || WHY="$WHY lr-record{rewrite $(head -1 "$CO")}"
    lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"; lr_run "$sd" "$LR_RV" - "$LR_F"; lr_ok lr-record
    ! has "$CO" LEGACY || WHY="$WHY lr-record{a LEGACY line}"; fi
  # lr-ok (ALLOW): the real world, the review naming the go-signal sha; no LEGACY line. lr-compacted (ALLOW): the same, the
  # lead holding nothing but the go-signal (seat base `-`): the record alone supplies the base.
  if cell lr-ok; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"; lr_run "$sd" "$LR_RV" "$LR_D" "$LR_F"; lr_ok lr-ok
    ! has "$CO" LEGACY || WHY="$WHY lr-ok{a LEGACY line}"; fi
  if cell lr-compacted; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"; lr_run "$sd" "$LR_RV" - "$LR_F"; lr_ok lr-compacted
    ! has "$CO" LEGACY || WHY="$WHY lr-compacted{a LEGACY line}"; fi
  # lr-seatbase: the record names LR_D and the seat passes LR_OLD (a pre-prescription base): the record wins, so the review
  # omitting reviewed-sha is REFUSED; a run that read the seat base would take LR_OLD's qa.md and acquit it.
  if cell lr-seatbase; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$CANON_BLK" -; lr_run "$sd" "$LR_RV" "$LR_OLD" "$LR_F"; lr_no lr-seatbase "$LR_RSHA"; fi
  # lr-orphan (a3): the go-signal does not descend from the recorded dispatch sha. A counted run: only the ancestry refuses.
  if cell lr-orphan; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$CANON_BLK" "reviewed-sha: $LR_OF"; lr_run "$sd" "$LR_RV" - "$LR_OF"; lr_no lr-orphan "$LR_REF"; fi
  # lr-rewind: the live sprint ref (refs/heads/sprint) moved BACK to LR_OLD while the record names LR_D: the record decides,
  # so the counted-run review omitting reviewed-sha is REFUSED; a run keyed on the live ref reads LR_OLD's qa.md.
  if cell lr-rewind; then lr_rec "$sd" "$LR_D"; G -C "$REPO_LR" update-ref refs/heads/sprint "$LR_OLD" || WHY="$WHY lr-rewind{ref}"
    lr_file "$LR_RV" "$CANON_BLK" -; lr_run "$sd" "$LR_RV" - "$LR_F"; lr_no lr-rewind "$LR_RSHA"; fi
  # lr-norecord (ALLOW, LEGACY-UNRECORDED): no record (a story dispatched before the record existed), the seat base LR_D,
  # the real world: SERIAL-OK and exactly one LEGACY-UNRECORDED line naming the story and the record path.
  # lr-norecord-wrong: the same with --story a listed story under another index: STORY-BIND still refuses.
  if cell lr-norecord; then lr_unrec; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"; lr_run "$sd" "$LR_RV" "$LR_D" "$LR_F"; lr_ok lr-norecord
    [ "$(grep -c '^LEGACY-UNRECORDED: ' "$CO")" = 1 ] && has "$CO" "$LR_UNREC $LR_RECF" || WHY="$WHY lr-norecord{LEGACY-UNRECORDED line: $(grep -c '^LEGACY-UNRECORDED' "$CO")}"; fi
  if cell lr-norecord-wrong; then lr_unrec; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"
    LR_STORY="$CR_SDIR/story-1-2-zz.md" lr_run "$sd" "$LR_RV" "$LR_D" "$LR_F"; lr_no lr-norecord-wrong "$CR_BIND"
    has "$CO" "$LR_UNREC" || WHY="$WHY lr-norecord-wrong{no LEGACY-UNRECORDED line}"; fi
  # lr-rsha-ne: the line names another sha. lr-rsha-trail: the go-signal sha followed by prose (graph's s317 3-2 shape):
  # the line carries the full sha alone.
  if cell lr-rsha-ne; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_D"; lr_run "$sd" "$LR_RV" - "$LR_F"; lr_no lr-rsha-ne "$LR_RSHA"; fi
  if cell lr-rsha-trail; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F (go-signal, base $LR_D)"; lr_run "$sd" "$LR_RV" - "$LR_F"; lr_no lr-rsha-trail "$LR_RSHA"; fi
  # lr-rsha-legacy (ALLOW, LEGACY): recorded at LR_OLD, whose qa.md prescribes neither line; a counted run, no reviewed-sha.
  if cell lr-rsha-legacy; then lr_rec "$sd" "$LR_OLD"; lr_file "$LR_RV" "$CANON_BLK" -; lr_run "$sd" "$LR_RV" - "$LR_F"; lr_ok lr-rsha-legacy
    has "$CO" "$LR_LEG .claude/team-roles/qa.md at $LR_OLD" || WHY="$WHY lr-rsha-legacy{no LEGACY line naming qa.md at the dispatch sha}"; fi
  # lr-rsha-strip: the reviewed-sha prescription stripped INSIDE the range, a counted run, no reviewed-sha: REFUSED by the
  # reviewed-sha gate (qa.md is read at the dispatch sha).
  if cell lr-rsha-strip; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$CANON_BLK" -; lr_run "$sd" "$LR_RV" - "$LR_RSTRIP"; lr_no lr-rsha-strip "$LR_RSHA"; fi
  # lr-canon-strip: the canonical-run label stripped INSIDE the range and a none claim, under a root (PROJ_CRS) whose own
  # qa.md lacks the label: held (qa.md at the dispatch sha carries it) and REFUSED as not record-only (qa.md is not a
  # record); never LEGACY.
  if cell lr-canon-strip; then lr_rec "$sd" "$LR_D"; lr_file "$LR_RV" "$none" "reviewed-sha: $LR_CSTRIP"; LR_ROOT="$PROJ_CRS" lr_run "$sd" "$LR_RV" - "$LR_CSTRIP"
    lr_no lr-canon-strip "$CR_NOTRO"; ! has "$CO" "LEGACY: canonical-run" || WHY="$WHY lr-canon-strip{reached LEGACY}"; fi
  # lr-disk-qa (U1i's NOTE): the review repository's WORKING-TREE qa.md edited to drop the canonical-run label while the
  # dispatch sha tracks it, the root's qa.md lacking it, and a PASS with no run line: held, REFUSED (no run line).
  if cell lr-disk-qa; then lr_rec "$sd" "$LR_D"; grep -vF -- 'column-0 `Canonical run:`' "$QA_MD" > "$REPO_LR/.claude/team-roles/qa.md"
    lr_file "$LR_RV" "" "reviewed-sha: $LR_F"; LR_ROOT="$PROJ_CRS" lr_run "$sd" "$LR_RV" - "$LR_F"; lr_no lr-disk-qa "$CR_NORUN"
    ! has "$CO" "LEGACY: canonical-run" || WHY="$WHY lr-disk-qa{reached LEGACY}"
    G -C "$REPO_LR" checkout -q -- .claude/team-roles/qa.md || WHY="$WHY lr-disk-qa{qa.md not restored}"; fi
  # cr-slot-suffix (the seat's own --range run, the strict s<N> parse): cr-bind-ok's world, the review under
  # docs/reviews/s1x/: REFUSED, its path carries no sprint (`s1x` is no slot).
  if cell cr-slot-suffix; then mkdir -p "$CR_REPO/docs/reviews/s1x" && SR_CANON='Canonical run: none, the diff is record-only (story, reviews, test-results)' sr_file "$CR_REPO/docs/reviews/s1x/1-2-qa-validation.md" "$(printf '## Verdict\nPASS')"
    cr_run "$sd" "$CR_REPO/docs/reviews/s1x/1-2-qa-validation.md" --story "$CR_STORY2" --range "$CR_BASE" "$CR_NEWS"; lr_no cr-slot-suffix "$CR_BNOSPR"
    rm -rf "$CR_REPO/docs/reviews/s1x"; fi
  # lr-slot (a1's spellings on the lead's run): s1x and s1.Ab12 carry no slot, foo/s1 is outside docs/reviews/ and a
  # relative path: each REFUSED by the physical-slot check. A symlink spelled s2 onto s1's slot is REFUSED earlier, by
  # STORY-BIND's one-sprint check (U1k), naming both sprints, so that spelling asserts U1k's token, not the slot's.
  if cell lr-slot; then lr_rec "$sd" "$LR_D"
    for o2 in docs/reviews/s1x docs/reviews/s1.Ab12 foo/s1; do
      lr_file "$REPO_LR/$o2/1-1-qa-validation.md" "$none" "reviewed-sha: $LR_F"
      lr_run "$sd" "$REPO_LR/$o2/1-1-qa-validation.md" - "$LR_F"; lr_no "lr-slot[$o2]" "$LR_SLOT"
    done
    lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"; mkdir -p "$WORK/lr-out" && ln -sfn "$REPO_LR/docs/reviews/s1" "$WORK/lr-out/s2"
    lr_run "$sd" "$WORK/lr-out/s2/1-1-qa-validation.md" - "$LR_F"; lr_no "lr-slot[symlink-s2]" "reads sprint 2 and the physical directory"
    LR_CWD="$REPO_LR/docs/reviews/s1" lr_run "$sd" ./1-1-qa-validation.md - "$LR_F"; lr_no "lr-slot[relative]" "$LR_SLOT"
  fi
  # A3 (BL-895 tip adversary 5): the lead record's name is any story index the lead dispatches under (graph s316's B1,
  # s315's 5-browser-smoke), never `/`, `..` or a leading `-`. a3-letter: --record-dispatch s1-B1 prints RECORDED, and the
  # lead's re-run of docs/reviews/s1/B1-qa-validation.md (a run claim, no --story) reads that record back: SERIAL-OK with
  # no LEGACY-UNRECORDED line. a3-slug: s1-5-browser-smoke RECORDED. a3-bad: s1-a/b, s1-.. and s1--x each REFUSED, no file.
  local a3d="${LR_RECF%/*}" a3n
  if cell a3-letter; then rm -f "$a3d/s1-B1"
    ( cd "$REPO_LR" && ip_run "$sd/merge-review-shards.sh" mrs_main --record-dispatch s1-B1 "$LR_D" ) > "$CO" 2>&1 < /dev/null; RRC=$?
    { [ "$RRC" = 0 ] && has "$CO" "RECORDED: $a3d/s1-B1 dispatch: $LR_D"; } || WHY="$WHY a3-letter{write rc=$RRC $(head -1 "$CO")}"
    lr_file "$REPO_LR/docs/reviews/s1/B1-qa-validation.md" "$CANON_BLK" "reviewed-sha: $LR_F"
    ip_run -C "$REPO_LR" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --check-serial "$REPO_LR/docs/reviews/s1/B1-qa-validation.md" --gate qa \
      --lead-range - "$LR_F" > "$CO" 2>&1 < /dev/null; SRC=$?
    lr_ok a3-letter; ! has "$CO" LEGACY-UNRECORDED || WHY="$WHY a3-letter{a LEGACY-UNRECORDED line}"
    rm -f "$REPO_LR/docs/reviews/s1/B1-qa-validation.md" "$a3d/s1-B1"; fi
  if cell a3-slug; then rm -f "$a3d/s1-5-browser-smoke"
    ( cd "$REPO_LR" && ip_run "$sd/merge-review-shards.sh" mrs_main --record-dispatch s1-5-browser-smoke "$LR_D" ) > "$CO" 2>&1 < /dev/null; RRC=$?
    { [ "$RRC" = 0 ] && has "$CO" "RECORDED: $a3d/s1-5-browser-smoke dispatch: $LR_D"; } || WHY="$WHY a3-slug{rc=$RRC $(head -1 "$CO")}"
    rm -f "$a3d/s1-5-browser-smoke"; fi
  if cell a3-bad; then
    for a3n in s1-a/b s1-.. s1--x; do
      ( cd "$REPO_LR" && ip_run "$sd/merge-review-shards.sh" mrs_main --record-dispatch "$a3n" "$LR_D" ) > "$CO" 2>&1 < /dev/null; RRC=$?
      { [ "$RRC" = 2 ] && has "$CO" "'$a3n' is not s<N>-<story-index>" && ! has "$CO" RECORDED && [ ! -e "$a3d/$a3n" ]; } \
        || WHY="$WHY a3-bad[$a3n]{rc=$RRC $(head -1 "$CO")}"
    done; fi
  # a1 (tip adversary 5, A1): THE LEAD CHECKOUT. LR_WT is a dev worktree `git worktree add`ed from REPO_LR (the lead
  # checkout) at LR_F, the review at its docs/reviews/s1/. The record names LR_D and the seat passes LR_D too, so a run
  # that reads no record checks LR_D..LR_F (record-only) and acquits. a1-redirect: the seat points LR_WT's gitfile at a
  # --shared clone of REPO_LR, so the review's repository keeps its common dir in the clone, where no record is: REFUSED
  # [owner: lead] naming the remedy, never LEGACY-UNRECORDED (m-lc-serial's subject). a1-alias (ALLOW twin): the lead
  # runs from a SYMLINKED alias of REPO_LR, gitfile intact: lr-canon-strip's non-record-only range is still REFUSED as
  # not record-only, and lr-compacted's record-only range reads SERIAL-OK.
  if cell a1-redirect; then lr_wt || return 1; lr_rec "$sd" "$LR_D"; lr_file "$LR_WT/docs/reviews/s1/1-1-qa-validation.md" "$none" "reviewed-sha: $LR_F"
    cp "$LR_WT/.git" "$WORK/lr-wt.gitfile" && printf 'gitdir: %s\n' "$LR_CLONE/.git" > "$LR_WT/.git" || { WHY="$WHY a1-redirect{gitfile not redirected}"; return 1; }
    if [ "$(G -C "$LR_WT" rev-parse --path-format=absolute --git-common-dir)" = "$LR_CLONE/.git" ]; then
      lr_run "$sd" "$LR_WT/docs/reviews/s1/1-1-qa-validation.md" "$LR_D" "$LR_F"; lr_lead a1-redirect
    else WHY="$WHY a1-redirect{FIXTURE ERROR: the redirected worktree does not name the clone's common dir}"; fi
    cp "$WORK/lr-wt.gitfile" "$LR_WT/.git"; fi
  if cell a1-alias; then lr_rec "$sd" "$LR_D"; ln -sfn "$REPO_LR" "$WORK/lr-alias"
    lr_file "$LR_RV" "$none" "reviewed-sha: $LR_CSTRIP"; LR_CWD="$WORK/lr-alias" LR_ROOT="$PROJ_CRS" lr_run "$sd" "$LR_RV" - "$LR_CSTRIP"; lr_no a1-alias "$CR_NOTRO"
    lr_file "$LR_RV" "$none" "reviewed-sha: $LR_F"; LR_CWD="$WORK/lr-alias" lr_run "$sd" "$LR_RV" - "$LR_F"; lr_ok a1-alias
    ! has "$CO" LEGACY || WHY="$WHY a1-alias{a LEGACY line}"; fi
  rm -f "$LR_RV"; lr_unrec; G -C "$REPO_LR" update-ref -d refs/heads/sprint 2> /dev/null || :
  [ -z "$WHY" ]
}

# ---- U1l (BL-895 tip adversary 5a, rows 5, 9 and 10(a)): THE PARTITION RECORD and STORY-BIND ON THE RUN BRANCH.
# Each world is REPO_CRB's shape (qa.md tracked with the sentinel at the base, story-1-x.md listed as story-1-1), built
# once per run on first use. A record cell writes the lead's record with the subject's own --record-partition, and
# removes the file it wrote (the RECORDED line names it) before it returns, so no other cell reads it.
LR_PUNREC="LEGACY-UNRECORDED: story 1"
LR_MIS="is not the partition the lead recorded"
LR_D1LINK="is reached through a symlink: its path below the worktree top reads differently as given and physically"
LR_D1NONAME="so it names no story record s<N>-<idx>"
LR_D1FIX="re-run from the lead checkout with the shard directory in place (no symlink); no re-dispatch is needed"
lr_seed() { # <dir> [qa.md to install]: REPO_CRB's base
  new_repo "$1" old && mkdir -p "$1/.claude/team-roles" "$1/$CR_SDIR" "$1/${CR_VIEW%/*}" \
    && cp "${2:-$QA_MD}" "$1/.claude/team-roles/qa.md" && printf -- '---\nstatus: review\n---\n# Story 1\n' > "$1/$CRB_STORY" \
    && printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1-1:\n    status: review\n    file: stories/story-1-x.md\n' > "$1/$CR_VIEW" \
    && G -C "$1" add -A && G -C "$1" commit -q --amend -m base
}
lr_code() { mkdir -p "$1/app" && printf 'def f():\n    return 1\n' > "$1/app/core.py" && printf 'x = 1\n' > "$1/app/util.py"; }
lr_nolabel() { mkdir -p "$1/.claude/team-roles" && grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$1/.claude/team-roles/qa.md"; }
lr_repos() { # builds REPO_LR9A, REPO_LR9B, REPO_LR9C and REPO_LR5 once
  [ -z "${LR_BUILT:-}" ] || return 0
  REPO_LR9A="$WORK/repo-lr9a"; REPO_LR9B="$WORK/repo-lr9b"; REPO_LR9C="$WORK/repo-lr9c"; REPO_LR5="$WORK/repo-lr5"
  # 9a: the range strips the sentinel from the TRACKED qa.md beside a code change; 9b deletes it; 9c never tracks it.
  lr_seed "$REPO_LR9A" && lr_code "$REPO_LR9A" && cm_six "$REPO_LR9A" && lr_nolabel "$REPO_LR9A" \
    && G -C "$REPO_LR9A" add -A && G -C "$REPO_LR9A" commit -q -m frozen \
  && lr_seed "$REPO_LR9B" && lr_code "$REPO_LR9B" && cm_six "$REPO_LR9B" && G -C "$REPO_LR9B" rm -q .claude/team-roles/qa.md \
    && G -C "$REPO_LR9B" add -A && G -C "$REPO_LR9B" commit -q -m frozen \
  && lr_seed "$REPO_LR9C" && G -C "$REPO_LR9C" rm -q --cached .claude/team-roles/qa.md && printf '.claude/\n' > "$REPO_LR9C/.gitignore" \
    && G -C "$REPO_LR9C" add -A && G -C "$REPO_LR9C" commit -q --amend -m base && lr_code "$REPO_LR9C" && cm_six "$REPO_LR9C" \
    && G -C "$REPO_LR9C" add -A && G -C "$REPO_LR9C" commit -q -m frozen \
  && lr_seed "$REPO_LR5" && lr_code "$REPO_LR5" && G -C "$REPO_LR5" add -A && G -C "$REPO_LR5" commit -q -m code \
    && cm_six "$REPO_LR5" && G -C "$REPO_LR5" add -A && G -C "$REPO_LR5" commit -q -m frozen \
  && REPO_LR2="$WORK/repo-lr2" && lr_seed "$REPO_LR2" && cm_six "$REPO_LR2" && G -C "$REPO_LR2" add -A && G -C "$REPO_LR2" commit -q -m pass1 \
    && lr_code "$REPO_LR2" && G -C "$REPO_LR2" add -A && G -C "$REPO_LR2" commit -q -m pass2 \
  || { WHY="$WHY FIXTURE ERROR: the U1l worlds were not seeded"; return 1; }
  # Each world must carry its property: 9a strips the sentinel in range, 9b and 9c hold no tracked qa.md at the sha, 9c
  # none at the base either, and R5's base..sha touches code while its last commit alone is record-only.
  local a b
  a="$(G -C "$REPO_LR9A" show HEAD~1:.claude/team-roles/qa.md | grep -cF 'column-0 `Canonical run:`')" || a=0
  b="$(G -C "$REPO_LR9A" show HEAD:.claude/team-roles/qa.md | grep -cF 'column-0 `Canonical run:`')" || b=0
  [ "$a" -ge 1 ] && [ "$b" = 0 ] && ! G -C "$REPO_LR9B" cat-file -e HEAD:.claude/team-roles/qa.md 2> /dev/null \
    && ! G -C "$REPO_LR9C" cat-file -e HEAD~1:.claude/team-roles/qa.md 2> /dev/null && [ -f "$REPO_LR9C/.claude/team-roles/qa.md" ] \
    && [ "$(G -C "$REPO_LR5" diff --name-only HEAD~2 HEAD -- app | grep -c .)" = 2 ] \
    && [ "$(G -C "$REPO_LR5" diff --name-only HEAD~1 HEAD -- app | grep -c .)" = 0 ] \
    || { WHY="$WHY FIXTURE STALE: a U1l world does not carry its property"; return 1; }
  LR_BUILT=1
}
lr_world() { # <script-dir> <repo> <base> <sha> [strip] -> d, o; the execution owner claims none unless LR_BLK is set
  SHARD_SHA="$4"
  d="$(WSLOT=1 CANON_BLK="${LR_BLK:-Canonical run: none, the diff is record-only (test-results)}" kworld "$1" "$2" "$3" "$4" 3 qa-validation PASS qa)" \
    || { WHY="$WHY the U1l world over $2 was not built"; return 1; }
  if [ -n "${5:-}" ]; then grep -v '^Canonical r' "$d/cross-1.md" > "$d/x.tmp" && mv "$d/x.tmp" "$d/cross-1.md"; fi
  o="$(qout "$d")"
}
lr_prec() { # <script-dir> <shard-dir> -> LR_PATH (the record --record-partition wrote); 1 when it wrote none
  LR_PATH=""
  ip_run -C "${QCWD:-${2%%/docs/reviews/*}}" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$1/merge-review-shards.sh" mrs_main --record-partition "$2" > "$MO" 2>&1 < /dev/null || return 1
  LR_PATH="$(sed -n 's/^RECORDED: \([^ ]*\) .*/\1/p' "$MO")"; [ -n "$LR_PATH" ] && [ -f "$LR_PATH" ]
}
lr_merge() { # <script-dir> <shard-dir> <--story> -> RC, $MO
  ip_run -C "${QCWD:-${2%%/docs/reviews/*}}" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$1/merge-review-shards.sh" mrs_main "$2" --gate qa --out "$(qout "$2")" --story "$3" > "$MO" 2>&1 < /dev/null; RC=$?
}
lr_done() { rm -f "$o"; [ -z "${LR_PATH:-}" ] || rm -f "$LR_PATH"; LR_PATH=""; }
lr_sw() { # LR_S (a lead checkout), LR_SW (a dev worktree added from it) and LR_SCLONE (a --shared clone of it), built once
  [ -z "${LR_SW:-}" ] || return 0
  LR_S="$WORK/lr-s"; LR_SW="$WORK/lr-sw"; LR_SCLONE="$WORK/lr-sclone"
  G init -q "$LR_S" && printf 's\n' > "$LR_S/README" && G -C "$LR_S" add README && G -C "$LR_S" commit -q -m s \
    && G -C "$LR_S" worktree add -q --detach "$LR_SW" HEAD 2> /dev/null && G clone -q --shared "$LR_S" "$LR_SCLONE" 2> /dev/null \
    && [ -f "$LR_SW/.git" ] || { WHY="$WHY FIXTURE ERROR: the a2 lead checkout, its dev worktree or the seat's clone was not built"; LR_SW=""; return 1; }
}
p_lead_rec() {
  local sd="$1" d o SHARD_SHA s5 x5 b5 f5 rt rp_
  WHY=""; LR_PATH=""
  # A partition with no record (made before 0.995.0): the 0.994.0 merge plus one LEGACY-UNRECORDED line; its wrong
  # --story is still refused by STORY-BIND.
  if cell lr-unrec; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; lr_merge "$sd" "$d" "$CRB_STORY"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "$LR_PUNREC" && [ -f "$o" ] || WHY="$WHY lr-unrec{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    lr_done
  fi
  if cell lr-unrec-bind; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; lr_merge "$sd" "$d" docs/reviews/s1/new.md
    refused_at "$CR_BIND" "$o" && has "$MO" "is not story-1.md or story-1-*.md" && has "$MO" "$LR_PUNREC" \
      || WHY="$WHY lr-unrec-bind{rc=$RC $(reline "$MO")}"
    lr_done
  fi
  # The record --record-partition writes, read back by the merge with nothing held anywhere else (a compacted lead).
  if cell lr-ok; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1
    if lr_prec "$sd" "$d" && grep -qxF "qa-era.${d##*/}: held" "$LR_PATH"; then
      lr_merge "$sd" "$d" "$CRB_STORY"
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY-UNRECORDED" && ! has "$MO" "$CR_LEG" && [ -f "$o" ] \
        || WHY="$WHY lr-ok{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY lr-ok{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # A record whose sha disagrees with .manifest: REFUSED [owner: lead].
  if cell lr-sha; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1
    if lr_prec "$sd" "$d"; then
      sed "s/^\(partition-sha\.[^:]*\): .*/\1: $CRB_BASE/" "$LR_PATH" > "$LR_PATH.x" && mv "$LR_PATH.x" "$LR_PATH"
      lr_merge "$sd" "$d" "$CRB_STORY"
      refused_at "$LR_MIS" "$o" && owner_in "$MO" lead && has "$MO" "names sha $CRB_BASE" || WHY="$WHY lr-sha{rc=$RC $(reline "$MO")}"
    else WHY="$WHY lr-sha{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # ROW 5: the lead partitions B..F and records it; a seat re-partitions X..F (X a later, code-free start) and copies
  # that .manifest over the lead's. X..F is record-only and B..F is not, so only the record refuses it.
  if cell lr-move; then
    lr_repos || return 1
    b5="$(G -C "$REPO_LR5" rev-parse HEAD~2)"; x5="$(G -C "$REPO_LR5" rev-parse HEAD~1)"; f5="$(G -C "$REPO_LR5" rev-parse HEAD)"
    lr_world "$sd" "$REPO_LR5" "$b5" "$f5" || return 1
    if lr_prec "$sd" "$d"; then
      s5="$(mktemp -d "$WORK/lr5.XXXXXX")/${d##*/}"
      ip_run "$sd/partition-review-diff.sh" prd_main --map "$REPO_LR5" "$x5" "$f5" --min-files 4 --max-parts 3 --shard-dir "$s5" > /dev/null 2>&1 < /dev/null
      if [ -f "$s5/.manifest" ] && ! cmp -s "$s5/.manifest" "$d/.manifest"; then
        cp "$s5/.manifest" "$d/.manifest"; lr_merge "$sd" "$d" "$CRB_STORY"
        refused_at "$LR_MIS" "$o" && owner_in "$MO" lead && has "$MO" "names base $b5" || WHY="$WHY lr-move{rc=$RC $(reline "$MO")}"
      else WHY="$WHY lr-move{FIXTURE ERROR: the seat's re-partition wrote no differing manifest}"; fi
    else WHY="$WHY lr-move{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # ROW 9: the era is the record's, taken at the base, so a range that strips (9a) or deletes (9b) the tracked qa.md, or
  # a seat that rewrites the untracked disk copy after the partition (9c), holds the rule: a none claim over a range
  # carrying code is refused as not record-only, with no LEGACY line.
  for rt in 9a 9b 9c; do
    cell "lr-$rt" || continue
    lr_repos || return 1
    case "$rt" in 9a) rp_="$REPO_LR9A" ;; 9b) rp_="$REPO_LR9B" ;; 9c) rp_="$REPO_LR9C" ;; esac
    lr_world "$sd" "$rp_" "$(G -C "$rp_" rev-parse HEAD~1)" "$(G -C "$rp_" rev-parse HEAD)" || return 1
    if lr_prec "$sd" "$d" && grep -qxF "qa-era.${d##*/}: held" "$LR_PATH"; then
      case "$rt" in 9b|9c) lr_nolabel "$rp_" ;; esac
      lr_merge "$sd" "$d" "$CRB_STORY"
      refused_at "$CR_NOTRO" "$o" && ! has "$MO" "$CR_LEG" || WHY="$WHY lr-$rt{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY lr-$rt{record not written or not held: $(head -1 "$MO")}"; fi
    case "$rt" in 9b) rm -f "$rp_/.claude/team-roles/qa.md" ;; 9c) cp "$QA_MD" "$rp_/.claude/team-roles/qa.md" ;; esac
    lr_done
  done
  # The allow twin of row 9: qa.md without the label at the base (REPO_CRL), recorded legacy, merges LEGACY.
  if cell lr-legacy; then
    lr_world "$sd" "$REPO_CRL" "$CRL_BASE" "$CRL_SHA" strip || return 1
    if lr_prec "$sd" "$d" && grep -qxF "qa-era.${d##*/}: legacy" "$LR_PATH"; then
      lr_merge "$sd" "$d" "$CRB_STORY"
      [ "$RC" -eq 0 ] && has "$MO" "$CR_LEG" && has "$MO" "MERGED:" && ! has "$MO" "LEGACY-UNRECORDED" || WHY="$WHY lr-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY lr-legacy{record not written or not legacy: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # A NORMAL RE-PARTITION: pass 1 over B..P1 (REPO_LR2, six record files, a run claim) is recorded; the re-map after
  # its NEEDS_REWORK partitions B..P2 (P2 adds code) into a new shard directory and is merged WITHOUT a second
  # --record-partition. Each shard directory has its own keys, so pass 1's values are never compared with pass 2's
  # manifest: MERGED, with LEGACY-UNRECORDED naming pass 2's directory. Then pass 2 recorded too: MERGED, no such line.
  if cell lr-repass; then
    lr_repos || return 1
    b5="$(G -C "$REPO_LR2" rev-parse HEAD~2)"; x5="$(G -C "$REPO_LR2" rev-parse HEAD~1)"; f5="$(G -C "$REPO_LR2" rev-parse HEAD)"
    LR_BLK="$CANON_BLK" lr_world "$sd" "$REPO_LR2" "$b5" "$x5" || return 1; s5="$d"
    if lr_prec "$sd" "$s5"; then
      rt="$LR_PATH"; rm -f "$o"
      WSLOT_IN="${s5%/docs/reviews/s1/shards/*}" LR_BLK="$CANON_BLK" lr_world "$sd" "$REPO_LR2" "$b5" "$f5" || return 1
      [ "${d%/shards/*}" = "${s5%/shards/*}" ] || { WHY="$WHY lr-repass{FIXTURE ERROR: pass 2's shard directory is not in pass 1's slot}"; lr_done; return 1; }
      lr_merge "$sd" "$d" "$CRB_STORY"
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "$LR_PUNREC" && has "$MO" "for ${d##*/}" && [ -f "$o" ] \
        || WHY="$WHY lr-repass{unrecorded pass 2: rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
      rm -f "$o"
      if lr_prec "$sd" "$d"; then
        lr_merge "$sd" "$d" "$CRB_STORY"
        [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY-UNRECORDED" || WHY="$WHY lr-repass{recorded pass 2: rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
      else WHY="$WHY lr-repass{pass 2 record not written: $(head -1 "$MO")}"; fi
      LR_PATH="$rt"
    else WHY="$WHY lr-repass{pass 1 record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # a2 (tip adversary 5, A2): THE LEAD CHECKOUT on the merge. LR_S is the lead checkout, LR_SW a dev worktree added from
  # it, and the shard directory sits in LR_SW's docs/reviews/s1/shards/ as a frozen worktree's does; the lead runs
  # --record-partition and the merge from LR_S. a2-redirect: recorded and merged with the gitfile intact (MERGED, the
  # control), then the seat points LR_SW's gitfile at a --shared clone of LR_S and copies a re-partition's .manifest
  # over the lead's (row 5): a merge reading no record would take it, LEGACY-UNRECORDED, so REFUSED [owner: lead] naming
  # the remedy (m-lc-merge's subject). a2-record: --record-partition after the same redirect is REFUSED and writes no
  # record (m-lc-record's subject). a2-cwd: the merge run with the frozen worktree's own repository (the manifest's
  # worktree) as the cwd: REFUSED with the remedy.
  local a2r=0 a2c=0; ! cell a2-redirect || a2r=1; ! cell a2-record || a2c=1
  if [ "$a2r$a2c" != 00 ]; then
    lr_repos || return 1; lr_sw || return 1
    b5="$(G -C "$REPO_LR5" rev-parse HEAD~2)"; x5="$(G -C "$REPO_LR5" rev-parse HEAD~1)"; f5="$(G -C "$REPO_LR5" rev-parse HEAD)"
    WSLOT_IN="$LR_SW" lr_world "$sd" "$REPO_LR5" "$b5" "$f5" || return 1
    if QCWD="$LR_S" lr_prec "$sd" "$d"; then
      s5="$(mktemp -d "$WORK/a2.XXXXXX")/${d##*/}"
      ip_run "$sd/partition-review-diff.sh" prd_main --map "$REPO_LR5" "$x5" "$f5" --min-files 4 --max-parts 3 --shard-dir "$s5" > /dev/null 2>&1 < /dev/null
      [ -f "$s5/.manifest" ] && ! cmp -s "$s5/.manifest" "$d/.manifest" && cp "$s5/.manifest" "$d/.manifest" \
        || { WHY="$WHY a2-redirect{FIXTURE ERROR: the seat's re-partition wrote no differing manifest}"; return 1; }
      # The control, gitfile intact: the record is read and the seat's manifest refused as lr-move refuses it.
      if [ "$a2r" = 1 ]; then QCWD="$LR_S" lr_merge "$sd" "$d" "$CRB_STORY"
        refused_at "$LR_MIS" "$o" && owner_in "$MO" lead && ! has "$MO" LEGACY-UNRECORDED || WHY="$WHY a2-redirect{intact gitfile: rc=$RC $(reline "$MO")}"
        rm -f "$o"; fi
      cp "$LR_SW/.git" "$WORK/lr-sw.gitfile" && printf 'gitdir: %s\n' "$LR_SCLONE/.git" > "$LR_SW/.git" \
        || { WHY="$WHY a2-redirect{gitfile not redirected}"; return 1; }
      if [ "$(G -C "$d" rev-parse --path-format=absolute --git-common-dir)" = "$LR_SCLONE/.git" ]; then
        if [ "$a2r" = 1 ]; then QCWD="$LR_S" lr_merge "$sd" "$d" "$CRB_STORY"
          refused_at "$LR_LEADCO" "$o" && owner_in "$MO" lead && has "$MO" "the qa merge: the shard directory" && ! has "$MO" LEGACY-UNRECORDED \
            || WHY="$WHY a2-redirect{rc=$RC $(reline "$MO")}"; fi
        if [ "$a2c" = 1 ]; then rt="$LR_PATH"
          # The clone is built once per run, so an earlier drive (m-lc-record's own) may have written this record into it.
          rm -f "$LR_SCLONE/.git/ai-dlc/stories/s1-1"
          ip_run -C "$LR_S" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --record-partition "$d" > "$MO" 2>&1 < /dev/null; RC=$?
          [ "$RC" -eq 2 ] && owner_in "$MO" lead && has "$MO" "$LR_LEADCO" && has "$MO" "--record-partition: the shard directory" && ! has "$MO" RECORDED: \
            && [ ! -e "$LR_SCLONE/.git/ai-dlc/stories/s1-1" ] || WHY="$WHY a2-record{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
          LR_PATH="$rt"; fi
      else WHY="$WHY a2-redirect{FIXTURE ERROR: the redirected shard directory does not name the clone's common dir}"; fi
      cp "$WORK/lr-sw.gitfile" "$LR_SW/.git"
    else WHY="$WHY a2-redirect{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  if cell a2-cwd; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1
    if lr_prec "$sd" "$d"; then
      QCWD="$REPO_CRB" lr_merge "$sd" "$d" "$CRB_STORY"
      refused_at "$LR_LEADCO" "$o" && owner_in "$MO" lead && has "$MO" "the qa merge: the shard directory" || WHY="$WHY a2-cwd{rc=$RC $(reline "$MO")}"
    else WHY="$WHY a2-cwd{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # D1 (delta adversary): THE SHARD DIRECTORY'S SLOT (merge-review-shards.sh shard_slot). REPO_CRB's world, recorded
  # in place; the record name is s<N>-<idx> read off the directory's path below its worktree top.
  # d1-ok (ALLOW): intact, recorded and merged: MERGED, no LEGACY-UNRECORDED (the twin of every D1 mutant).
  # d1-symlink-sprint: recorded, then the seat moves the directory under docs/reviews/s5/shards/ and leaves a symlink
  #   at the lead-assigned path; the merge through that path is REFUSED [owner: lead], never LEGACY-UNRECORDED
  #   (m-d1-merge's subject). d1-symlink-wrongstory: the same with another story's --story: the same refusal.
  # d1-record-link: the symlink laid before --record-partition: REFUSED, nothing RECORDED (m-d1-record's subject).
  # d1-outside: a real directory outside any shards/ (no symlink): the merge is REFUSED naming no story record, never
  #   `s?-<idx>` LEGACY-UNRECORDED (m-d1-name's subject).
  # d1-prefix-alias (ALLOW): the whole repository reached through a symlinked prefix, the shard directory intact:
  #   --record-partition RECORDED and the merge MERGED through the alias (m-d1-abs's subject: an absolute comparison).
  local d1l d1n d1a
  if cell d1-ok; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1
    if lr_prec "$sd" "$d"; then lr_merge "$sd" "$d" "$CRB_STORY"
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY-UNRECORDED" && [ -f "$o" ] || WHY="$WHY d1-ok{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY d1-ok{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  for d1n in d1-symlink-sprint d1-symlink-wrongstory; do
    cell "$d1n" || continue
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; d1l="${d%%/docs/reviews/*}"
    if lr_prec "$sd" "$d"; then
      mkdir -p "$d1l/docs/reviews/s5/shards" && mv "$d" "$d1l/docs/reviews/s5/shards/${d##*/}" && ln -s "$d1l/docs/reviews/s5/shards/${d##*/}" "$d" \
        || { WHY="$WHY $d1n{FIXTURE ERROR: the shard directory was not moved and linked}"; lr_done; return 1; }
      if [ "$d1n" = d1-symlink-sprint ]; then lr_merge "$sd" "$d" "$CRB_STORY"; else lr_merge "$sd" "$d" docs/reviews/s1/new.md; fi
      refused_at "$LR_D1LINK" "$o" && owner_in "$MO" lead && has "$MO" "$LR_D1FIX" && ! has "$MO" LEGACY-UNRECORDED \
        || WHY="$WHY $d1n{rc=$RC $(reline "$MO") $(grep -E '^(MERGED|LEGACY)' "$MO" | head -2 | tr '\n' ' ')}"
    else WHY="$WHY $d1n{record not written: $(head -1 "$MO")}"; fi
    lr_done
  done
  if cell d1-record-link; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; d1l="${d%%/docs/reviews/*}"
    mkdir -p "$d1l/docs/reviews/s5/shards" && mv "$d" "$d1l/docs/reviews/s5/shards/${d##*/}" && ln -s "$d1l/docs/reviews/s5/shards/${d##*/}" "$d" \
      || { WHY="$WHY d1-record-link{FIXTURE ERROR: the shard directory was not moved and linked}"; return 1; }
    ip_run -C "$d1l" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --record-partition "$d" > "$MO" 2>&1 < /dev/null; RC=$?
    [ "$RC" -eq 2 ] && owner_in "$MO" lead && has "$MO" "$LR_D1LINK" && has "$MO" "--record-partition: the shard directory" && ! has "$MO" RECORDED: \
      || WHY="$WHY d1-record-link{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    LR_PATH="$(sed -n 's/^RECORDED: \([^ ]*\) .*/\1/p' "$MO")"; lr_done
  fi
  if cell d1-outside; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; d1l="${d%%/docs/reviews/*}"
    mkdir -p "$d1l/elsewhere" && mv "$d" "$d1l/elsewhere/${d##*/}" || { WHY="$WHY d1-outside{FIXTURE ERROR: the shard directory was not moved}"; return 1; }
    d="$d1l/elsewhere/${d##*/}"; o="$(qout "$d")"
    [ ! -L "$d" ] || { WHY="$WHY d1-outside{FIXTURE ERROR: the moved directory is a symlink}"; return 1; }
    QCWD="$d1l" lr_merge "$sd" "$d" "$CRB_STORY"
    refused_at "$LR_D1NONAME" "$o" && owner_in "$MO" lead && ! has "$MO" LEGACY-UNRECORDED \
      || WHY="$WHY d1-outside{rc=$RC $(reline "$MO") $(grep -E '^(MERGED|LEGACY)' "$MO" | head -2 | tr '\n' ' ')}"
    lr_done
  fi
  if cell d1-prefix-alias; then
    lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; d1l="${d%%/docs/reviews/*}"
    d1a="$(mktemp -d "$WORK/pfx.XXXXXX")/repo" && ln -s "$d1l" "$d1a" && [ "$(cd "$d1a" && pwd -P)" = "$d1l" ] && [ "$(cd "$d1a" && pwd)" != "$d1l" ] \
      || { WHY="$WHY d1-prefix-alias{FIXTURE ERROR: the prefix alias does not read differently from the physical path}"; return 1; }
    d="$d1a/docs/reviews/s1/shards/${d##*/}"; o="$(qout "$d")"
    if QCWD="$d1a" lr_prec "$sd" "$d"; then QCWD="$d1a" lr_merge "$sd" "$d" "$CRB_STORY"
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY-UNRECORDED" && [ -f "$o" ] || WHY="$WHY d1-prefix-alias{merge rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY d1-prefix-alias{--record-partition through the alias: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # ROW 10(a), the merge: a run claim with another story's --story is refused by STORY-BIND; the right story merges.
  if cell lr-run-bind; then
    LR_BLK="$CANON_BLK" lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; lr_merge "$sd" "$d" docs/reviews/s1/new.md
    refused_at "$CR_BIND" "$o" && has "$MO" "is not story-1.md or story-1-*.md" || WHY="$WHY lr-run-bind{rc=$RC $(reline "$MO")}"
    lr_done
  fi
  if cell lr-run-ok; then
    LR_BLK="$CANON_BLK" lr_world "$sd" "$REPO_CRB" "$CRB_BASE" "$CRB_SHA" || return 1; lr_merge "$sd" "$d" "$CRB_STORY"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || WHY="$WHY lr-run-ok{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    lr_done
  fi
  # ROW 10(a), --check-serial: the same two, over CR_REPO's record-only range.
  local f="$CR_REPO/docs/reviews/s1/1-1-qa-validation.md" pv; pv="$(printf '## Verdict\nPASS')"
  if cell lr-run-bind-serial; then
    SR_CANON="$CANON_BLK" sr_file "$f" "$pv"
    cr_no "$sd" "$f" lr-run-bind-serial "is not story-1-1.md or story-1-1-*.md" --story "$CR_STORY4" --range "$CR_BASE" "$CR_REC"
    rm -f "$f"
  fi
  if cell lr-run-ok-serial; then
    SR_CANON="$CANON_BLK" sr_file "$f" "$pv"; cr_ok "$sd" "$f" lr-run-ok-serial --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"
    rm -f "$f"
  fi
  [ -z "$WHY" ]
}

# ---- BL-905, THE RUN RECORD (merge-review-shards.sh --record-run and run_bind). REPO_RR: lr_seed's base installing the
# qa.md that carries the run sentinel (QA_MD_RUN), a code commit X (app/), then F adding six test-results/ files, so
# B..F carries code and X..F is record-only. REPO_RRL is the same history over a qa.md without the sentinel (the LEGACY
# twin, one property apart). The stub runner is awk printing a pytest-shaped summary; no bash is started for it.
RR_RES="812 passed, 3 skipped in 1.0s"
# RR_INV is --record-run's RECORDED-RUN spelling of rr_good's argv, typed by hand: one shell line, each argument that is
# not a bare word single-quoted (rr_quote).
RR_INV="awk 'BEGIN { print \"===== $RR_RES =====\" }'"
RR_BLK="$(printf 'Canonical run: `%s` from the frozen worktree root\nCanonical result: %s' "$RR_INV" "$RR_RES")"
RR_NOREC="no canonical run is recorded"; RR_NE="is not the recorded run's result"; RR_NOREUSE="no earlier pass's run is reusable"
RR_LEG="LEGACY: canonical-run record not checked:"
rr_repo() { # <dir> <qa.md>
  lr_seed "$1" "$2" && lr_code "$1" && G -C "$1" add -A && G -C "$1" commit -q -m code \
    && cm_six "$1" && G -C "$1" add -A && G -C "$1" commit -q -m frozen
}
rr_repos() { # REPO_RR, REPO_RRL and their B, X, F, built once
  [ -z "${RR_BUILT:-}" ] || return 0
  REPO_RR="$WORK/repo-rr"; REPO_RRL="$WORK/repo-rrl"
  rr_repo "$REPO_RR" "$QA_MD_RUN" && rr_repo "$REPO_RRL" "$QA_MD" \
    && RR_B="$(G -C "$REPO_RR" rev-parse HEAD~2)" && RR_X="$(G -C "$REPO_RR" rev-parse HEAD~1)" && RR_F="$(G -C "$REPO_RR" rev-parse HEAD)" \
    && RRL_B="$(G -C "$REPO_RRL" rev-parse HEAD~2)" && RRL_F="$(G -C "$REPO_RRL" rev-parse HEAD)" \
    && RR_BR="$(G -C "$REPO_RR" symbolic-ref -q --short HEAD)" || { WHY="$WHY FIXTURE ERROR: the BL-905 worlds were not seeded"; return 1; }
  # Each world carries its property: the sentinel at REPO_RR's base and not at REPO_RRL's; B..F touches app/, X..F does not.
  [ "$(G -C "$REPO_RR" show "${RR_B}:.claude/team-roles/qa.md" | grep -cF -- "$RR_SENT")" = 1 ] \
    && [ "$(G -C "$REPO_RRL" show "${RRL_B}:.claude/team-roles/qa.md" | grep -cF -- "$RR_SENT")" = 0 ] \
    && [ "$(G -C "$REPO_RR" diff --name-only "$RR_B" "$RR_F" -- app | grep -c .)" = 2 ] \
    && [ "$(G -C "$REPO_RR" diff --name-only "$RR_X" "$RR_F" -- app | grep -c .)" = 0 ] \
    || { WHY="$WHY FIXTURE STALE: a BL-905 world does not carry its property"; return 1; }
  RR_BUILT=1
}
rr_world() { # <script-dir> <repo> <base> <sha> <canonical block> -> d, o, RR_SB
  SHARD_SHA="$4"
  d="$(WSLOT=1 CANON_BLK="$5" kworld "$1" "$2" "$3" "$4" 3 qa-validation PASS qa)" || { WHY="$WHY the BL-905 world over $2 was not built"; return 1; }
  o="$(qout "$d")"; RR_SB="${d##*/}"
}
rr_rec() { # <script-dir> <shard dir | review file> <cwd> <runner argv...> -> RRC, $MO; RR_FZ: the serial form's --frozen
  local sd="$1" t="$2" c="$3"; shift 3
  ip_run -C "$c" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --record-run "$t" ${RR_FZ:+--frozen "$RR_FZ"} -- "$@" > "$MO" 2>&1 < /dev/null; RRC=$?
}
rr_good() { rr_rec "$1" "$2" "${3:-${2%%/docs/reviews/*}}" awk "BEGIN { print \"===== $RR_RES =====\" }"; }
rr_rekey() { # <record> <shard-dir basename> <new key> <new sha>: move this pass's run.* lines to <new key> at <new sha>
  awk -v o="run.$2." -v n="run.$3." -v s="$4" 'index($0, o) == 1 { $0 = n substr($0, length(o) + 1); if ($0 ~ /\.sha: /) sub(/: .*/, ": " s) } { print }' "$1" > "$1.x" \
    && mv "$1.x" "$1"
}
rr_nostory() { # <script-dir> <shard-dir>: the qa merge with no --story -> RC, $MO
  ip_run -C "${2%%/docs/reviews/*}" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$1/merge-review-shards.sh" mrs_main "$2" --gate qa --out "$(qout "$2")" > "$MO" 2>&1 < /dev/null; RC=$?
}
p_run_rec() {
  local sd="$1" d o SHARD_SHA RR_SB f pv c blk n
  WHY=""; LR_PATH=""; pv="$(printf '## Verdict\nPASS')"
  rr_repos || return 1
  # rr-fab (the BL-905 defect): a typed run and result, no recorded run, in a held era -> REFUSED [owner: cross...].
  # rr-legacy (ALLOW, one property apart): the same pair over a qa.md without the sentinel -> MERGED, one LEGACY line.
  if cell rr-fab; then
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$CANON_BLK" || return 1
    if lr_prec "$sd" "$d" && grep -qxF "run-era.$RR_SB: held" "$LR_PATH"; then lr_merge "$sd" "$d" "$CRB_STORY"
      refused_at "$RR_NOREC" "$o" && has "$MO" "[owner: cross" && has "$MO" "--record-run" \
        || WHY="$WHY rr-fab{rc=$RC $(reline "$MO") $(grep -E '^(MERGED|LEGACY: canonical-run record)' "$MO" | head -2 | tr '\n' ' ')}"
    else WHY="$WHY rr-fab{record not written or not held: $(head -1 "$MO")}"; fi
    lr_done
  fi
  if cell rr-legacy; then
    rr_world "$sd" "$REPO_RRL" "$RRL_B" "$RRL_F" "$CANON_BLK" || return 1
    if lr_prec "$sd" "$d" && grep -qxF "run-era.$RR_SB: legacy" "$LR_PATH"; then lr_merge "$sd" "$d" "$CRB_STORY"
      n="$(grep -c "^$RR_LEG" "$MO")" || n=0
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$n" = 1 ] && [ "$(nref "$MO")" = 0 ] || WHY="$WHY rr-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY rr-legacy{record not written or not legacy: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # A recorded run, its RECORDED-RESULT copied verbatim (rr-ok) or inside backticks and `=` padding (rr-norm): MERGED.
  # A result whose counts differ from the record (rr-diff): REFUSED naming the recorded value.
  for c in rr-ok rr-norm rr-diff; do
    cell "$c" || continue
    case "$c" in
      rr-ok) blk="$RR_BLK" ;;
      rr-norm) blk="$(printf 'Canonical run: `%s`\nCanonical result: `= %s =`' "$RR_INV" "$RR_RES")" ;;
      *) blk="$(printf 'Canonical run: `%s`\nCanonical result: 813 passed, 3 skipped in 1.0s' "$RR_INV")" ;;
    esac
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$blk" || return 1
    if lr_prec "$sd" "$d"; then rr_good "$sd" "$d"
      if [ "$RRC" = 0 ] && grep -qxF "RECORDED-RESULT: $RR_RES" "$MO" && has "$MO" "RECORDED-RUN: $RR_INV (in $REPO_RR, sha $RR_F)" \
         && grep -qxF "run.$RR_SB.result: $RR_RES" "$LR_PATH"; then lr_merge "$sd" "$d" "$CRB_STORY"
        if [ "$c" = rr-diff ]; then refused_at "$RR_NE" "$o" && has "$MO" "'$RR_RES'" || WHY="$WHY $c{rc=$RC $(reline "$MO")}"
        else [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "$RR_LEG" || WHY="$WHY $c{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"; fi
      else WHY="$WHY $c{--record-run rc=$RRC $(head -2 "$MO" | tr '\n' ' ')}"; fi
    else WHY="$WHY $c{record not written: $(head -1 "$MO")}"; fi
    lr_done
  done
  # THE RECORDED INVOCATION (BL-905 fold). rr-replay: a run recorded through the awk runner, its RECORDED-RESULT copied,
  # and `Canonical run:` naming `python3 -m pytest -q` (a replayed capture standing behind the canonical command) ->
  # REFUSED naming both invocations; rr-ok is its ALLOW twin, one property apart. rr-rfilter: the recorded invocation
  # carries `--keyword=x` (RUN-FILTER refuses it) while `Canonical run:` carries `--keywordx`, which RUN-FILTER passes
  # and which normalises (`=` removed) to the recorded one, so only the recorded invocation's RUN-FILTER can refuse it.
  for c in rr-replay rr-rfilter; do
    cell "$c" || continue
    if [ "$c" = rr-replay ]; then blk="$(printf 'Canonical run: `python3 -m pytest -q` from the frozen worktree root\nCanonical result: %s' "$RR_RES")"
    else blk="$(printf "Canonical run: \`awk 'BEGIN { print \"===== %s =====\"; exit }' --keywordx\`\\nCanonical result: %s" "$RR_RES" "$RR_RES")"; fi
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$blk" || return 1
    if lr_prec "$sd" "$d"; then
      if [ "$c" = rr-replay ]; then rr_good "$sd" "$d"; else rr_rec "$sd" "$d" "${d%%/docs/reviews/*}" awk "BEGIN { print \"===== $RR_RES =====\"; exit }" --keyword=x; fi
      if [ "$RRC" = 0 ] && grep -qxF "RECORDED-RESULT: $RR_RES" "$MO"; then lr_merge "$sd" "$d" "$CRB_STORY"
        if [ "$c" = rr-replay ]; then
          refused_at "is not the recorded run's invocation" "$o" && has "$MO" "'Canonical run: \`python3 -m pytest -q\`'" && has "$MO" "\`$RR_INV\`" \
            || WHY="$WHY $c{rc=$RC $(reline "$MO")}"
        else refused_at "selects tests by name (--keyword=x)" "$o" || WHY="$WHY $c{rc=$RC $(reline "$MO")}"; fi
      else WHY="$WHY $c{--record-run rc=$RRC $(head -2 "$MO" | tr '\n' ' ')}"; fi
    else WHY="$WHY $c{record not written: $(head -1 "$MO")}"; fi
    lr_done
  done
  # THE QUOTED INVOCATION (BL-905 fold). rr-mq: a run whose argv carries a quoted multi-word marker (`awk -f <program>
  # pytest -m 'a and b'`, the operands a BEGIN-only program never reads), under a conventions file declaring
  # `-m "a and b"` canonical: RECORDED-RUN, the record's invocation line and the `Canonical run:` copy are the one
  # hand-typed line, and it MERGES (a `$*` record reads `-m a and b`, which RUN-FILTER reads as the marker `a`). rr-mu,
  # its twin one property apart: `-m unit`, every argument a bare word, so both spellings agree and it merges.
  for c in rr-mq rr-mu; do
    cell "$c" || continue
    case "$WORK" in *[!A-Za-z0-9_./-]*) WHY="$WHY $c{FIXTURE ERROR: $WORK is not a bare word}"; return 1 ;; esac
    printf 'BEGIN { print "===== %s ====="; exit }\n' "$RR_RES" > "$WORK/rr-mq.awk" || return 1
    if [ "$c" = rr-mq ]; then n="'a and b'"; set -- 'a and b'; else n=unit; set -- unit; fi
    blk="awk -f $WORK/rr-mq.awk pytest -m $n"
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$(printf 'Canonical run: `%s`\nCanonical result: %s' "$blk" "$RR_RES")" || return 1
    mkdir -p "$REPO_RR/docs" && printf -- '- canonical: `pytest -m "a and b"` and `pytest -m unit`\n' > "$REPO_RR/docs/coding-conventions.md" || return 1
    if lr_prec "$sd" "$d"; then rr_rec "$sd" "$d" "${d%%/docs/reviews/*}" awk -f "$WORK/rr-mq.awk" pytest -m "$1"
      if [ "$RRC" = 0 ] && grep -qxF "RECORDED-RESULT: $RR_RES" "$MO"; then
        grep -qxF "RECORDED-RUN: $blk (in $REPO_RR, sha $RR_F)" "$MO" && grep -qxF "run.$RR_SB.invocation: $blk" "$LR_PATH" \
          || WHY="$WHY $c{invocation not recorded as the Canonical run: copy: $(grep '^RECORDED-RUN' "$MO")}"
        lr_merge "$sd" "$d" "$CRB_STORY"
        [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "$RR_LEG" || WHY="$WHY $c{rc=$RC $(reline "$MO")}"
      else WHY="$WHY $c{--record-run rc=$RRC $(head -2 "$MO" | tr '\n' ' ')}"; fi
    else WHY="$WHY $c{record not written: $(head -1 "$MO")}"; fi
    rm -f "$REPO_RR/docs/coding-conventions.md"; lr_done
  done
  # THE EARLIER PASS. The run recorded, then its key and sha moved: rr-stale, this pass's own key at B (B..F touches
  # app/) -> REFUSED; rr-earlier-eq, another pass's key at F, merged with no --story -> MERGED (the equal-sha lookup
  # alone); rr-cross-ok, another key at X (X..F record-only) -> MERGED; rr-cross-code, another key at B -> REFUSED
  # naming B..F and the predicate's NOT-RECORD-ONLY line.
  for c in rr-stale rr-earlier-eq rr-cross-ok rr-cross-code; do
    cell "$c" || continue
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$RR_BLK" || return 1
    if lr_prec "$sd" "$d" && { rr_good "$sd" "$d"; [ "$RRC" = 0 ]; }; then
      case "$c" in
        rr-stale) rr_rekey "$LR_PATH" "$RR_SB" "$RR_SB" "$RR_B" ;;
        rr-earlier-eq) rr_rekey "$LR_PATH" "$RR_SB" 1-qa-validation-000000000000 "$RR_F" ;;
        rr-cross-ok) rr_rekey "$LR_PATH" "$RR_SB" 1-qa-validation-000000000000 "$RR_X" ;;
        rr-cross-code) rr_rekey "$LR_PATH" "$RR_SB" 1-qa-validation-000000000000 "$RR_B" ;;
      esac
      n="$(grep -c "^run\.$RR_SB\." "$LR_PATH")" || n=0
      [ "$n" = "$([ "$c" = rr-stale ] && echo 5 || echo 0)" ] || { WHY="$WHY $c{FIXTURE ERROR: the record was not re-keyed ($n)}"; lr_done; return 1; }
      if [ "$c" = rr-earlier-eq ]; then rr_nostory "$sd" "$d"; else lr_merge "$sd" "$d" "$CRB_STORY"; fi
      case "$c" in
        rr-stale|rr-cross-code) refused_at "$RR_NOREUSE" "$o" && has "$MO" "$RR_B..$RR_F: NOT-RECORD-ONLY" || WHY="$WHY $c{rc=$RC $(reline "$MO") $(grep '^MERGED' "$MO")}" ;;
        *) [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || WHY="$WHY $c{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}" ;;
      esac
    else WHY="$WHY $c{record not written: $(head -2 "$MO" | tr '\n' ' ')}"; fi
    lr_done
  done
  # --record-run's own answers. rr-head: the frozen worktree checked out at X -> REFUSED, nothing recorded. rr-exit1: a
  # runner exiting 1 after a summary -> recorded with exit 1. rr-nosum: no summary line -> REFUSED, nothing recorded.
  for c in rr-head rr-exit1 rr-nosum; do
    cell "$c" || continue
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$RR_BLK" || return 1
    if lr_prec "$sd" "$d"; then
      case "$c" in
        rr-head) G -C "$REPO_RR" checkout -q --detach "$RR_X" && rr_good "$sd" "$d"; G -C "$REPO_RR" checkout -q "$RR_BR"
          [ "$RRC" = 2 ] && has "$MO" "so the run would test other code" && ! has "$MO" RECORDED-RESULT && ! grep -q '^run\.' "$LR_PATH" || WHY="$WHY $c{rc=$RRC $(head -1 "$MO")}" ;;
        rr-exit1) rr_rec "$sd" "$d" "${d%%/docs/reviews/*}" awk 'BEGIN { print "===== 1 failed, 811 passed in 1.0s ====="; exit 1 }'
          [ "$RRC" = 0 ] && grep -qxF "RECORDED-RESULT: 1 failed, 811 passed in 1.0s" "$MO" && grep -qxF "run.$RR_SB.exit: 1" "$LR_PATH" || WHY="$WHY $c{rc=$RRC $(head -1 "$MO")}" ;;
        rr-nosum) rr_rec "$sd" "$d" "${d%%/docs/reviews/*}" awk 'BEGIN { print "collecting ..." }'
          [ "$RRC" = 2 ] && has "$MO" "carries no summary line with a count" && ! grep -q '^run\.' "$LR_PATH" || WHY="$WHY $c{rc=$RRC $(head -1 "$MO")}" ;;
      esac
    else WHY="$WHY $c{record not written: $(head -1 "$MO")}"; fi
    lr_done
  done
  # THE SUMMARY LINE (BL-905 fold). rr-sum-cut: a verbose run cut off mid-way, its last line a per-test progress line
  # whose test name ends in a digit (`test_case_3 PASSED [ 99%]` reads `3 passed`) -> --record-run REFUSED, nothing
  # recorded. rr-sum-log and rr-sum-q ask rr_summary itself (the function --record-run calls, loaded in process): a pytest
  # session line followed by a log line carrying a count is the session line; quiet `-q` output with no `=` is its own
  # line, through the generic fallback. The OSC title escape opening the session line must be stripped for `^=` to
  # match it, so rr-sum-log also holds the OSC strip (unstripped, the log line wins).
  if cell rr-sum-cut; then
    rr_world "$sd" "$REPO_RR" "$RR_B" "$RR_F" "$RR_BLK" || return 1
    if lr_prec "$sd" "$d"; then
      rr_rec "$sd" "$d" "${d%%/docs/reviews/*}" awk 'BEGIN { print "tests/a.py::test_case_2 PASSED [ 98%]"; print "tests/a.py::test_case_3 PASSED [ 99%]" }'
      [ "$RRC" = 2 ] && has "$MO" "carries no summary line with a count" && ! grep -q '^run\.' "$LR_PATH" || WHY="$WHY rr-sum-cut{rc=$RRC $(head -1 "$MO")}"
    else WHY="$WHY rr-sum-cut{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  for c in rr-sum-log rr-sum-q; do
    cell "$c" || continue
    if [ "$c" = rr-sum-log ]; then printf 'tests/a.py ....\n\033]0;pytest\007\033[32m===== 5 passed, 1 skipped in 1.20s =====\033[0m\nINFO cleaned 2 errors\n' > "$WORK/rr-sum.in"; n="5 passed, 1 skipped in 1.20s"
    else printf '....F...\n812 passed, 3 skipped in 1.0s\n' > "$WORK/rr-sum.in"; n="812 passed, 3 skipped in 1.0s"; fi
    blk="$(rr_summary "$WORK/rr-sum.in")" || blk="<none>"
    [ "$blk" = "$n" ] || WHY="$WHY $c{got '$blk'}"
  done
  # rr-none: a record-only pass (X..F) claiming `none, <reason>` in the held era needs no record -> MERGED.
  if cell rr-none; then
    rr_world "$sd" "$REPO_RR" "$RR_X" "$RR_F" "Canonical run: none, the diff is record-only (test-results)" || return 1
    if lr_prec "$sd" "$d"; then lr_merge "$sd" "$d" "$CRB_STORY"
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "$RR_NOREC" || WHY="$WHY rr-none{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    else WHY="$WHY rr-none{record not written: $(head -1 "$MO")}"; fi
    lr_done
  fi
  # --check-serial over a review in REPO_RR's own docs/reviews/s1/ (its on-disk qa.md carries the sentinel; the frozen
  # sha is its HEAD, F): a typed pair REFUSED [owner: serial]; recorded through --record-run on the review path, SERIAL-OK.
  f="$REPO_RR/docs/reviews/s1/1-qa-validation.md"; mkdir -p "${f%/*}"
  if cell rr-s-fab; then
    sr_file "$f" "$pv"; cr_no "$sd" "$f" rr-s-fab "$RR_NOREC"; rm -f "$f"
    # With no range the remedy names no sha: the review repository's HEAD as --frozen would compare HEAD with HEAD.
    has "$CO" "--frozen <the full go-signal sha>" || WHY="$WHY rr-s-fab{remedy --frozen: $(reline "$CO")}"
  fi
  if cell rr-s-ok; then
    SR_CANON="$RR_BLK" sr_file "$f" "$pv"; RR_FZ="$RR_F" rr_good "$sd" "$f" "$REPO_RR"
    if [ "$RRC" = 0 ] && has "$MO" "RECORDED-RESULT: $RR_RES"; then cr_ok "$sd" "$f" rr-s-ok
    else WHY="$WHY rr-s-ok{--record-run rc=$RRC $(head -1 "$MO")}"; fi
    rm -f "$f" "$REPO_RR/.git/ai-dlc/stories/s1-1"
  fi
  # rr-s-head (BL-905 fold): the serial form's frozen sha is --frozen, the go-signal sha, never the worktree's own HEAD.
  # REPO_RR checked out at X with --frozen F -> REFUSED, nothing recorded (a HEAD-read frozen sha compares X with X).
  if cell rr-s-head; then
    rm -f "$REPO_RR/.git/ai-dlc/stories/s1-1"
    G -C "$REPO_RR" checkout -q --detach "$RR_X" && RR_FZ="$RR_F" rr_good "$sd" "$f" "$REPO_RR"; G -C "$REPO_RR" checkout -q "$RR_BR"
    [ "$RRC" = 2 ] && has "$MO" "so the run would test other code" && has "$MO" "not the frozen sha $RR_F" && ! has "$MO" RECORDED-RESULT \
      && ! grep -q '^run\.' "$REPO_RR/.git/ai-dlc/stories/s1-1" 2> /dev/null || WHY="$WHY rr-s-head{rc=$RRC $(head -1 "$MO")}"
    rm -f "$REPO_RR/.git/ai-dlc/stories/s1-1"
  fi
  # THE LEAD'S RE-RUN in the held era: the frozen sha is the go-signal sha (F), never the review repository's HEAD.
  # rr-s-lrange: a run recorded at B (the worktree at B, --frozen B) and the lead's --lead-range at go-signal F with the
  # worktree still at B -> REFUSED, no run at the frozen sha F. rr-s-lrok (ALLOW, one property apart): the run recorded
  # at F -> SERIAL-OK.
  for c in rr-s-lrange rr-s-lrok; do
    cell "$c" || continue
    rm -f "$REPO_RR/.git/ai-dlc/stories/s1-1"
    SR_CANON="$RR_BLK" sr_file "$f" "$pv" "reviewed-sha: $RR_F"
    if [ "$c" = rr-s-lrange ]; then G -C "$REPO_RR" checkout -q --detach "$RR_B" && RR_FZ="$RR_B" rr_good "$sd" "$f" "$REPO_RR"
    else RR_FZ="$RR_F" rr_good "$sd" "$f" "$REPO_RR"; fi
    if [ "$RRC" = 0 ] && has "$MO" "RECORDED-RESULT: $RR_RES"; then
      ip_run -C "$REPO_RR" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --check-serial "$f" --gate qa --lead-range "$RR_B" "$RR_F" > "$CO" 2>&1 < /dev/null; SRC=$?
      if [ "$c" = rr-s-lrange ]; then
        [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "no canonical run is recorded at the frozen sha $RR_F" && has "$CO" "$SR_OWN" && ! has "$CO" SERIAL-OK \
          || WHY="$WHY $c{rc=$SRC $(reline "$CO")}"
      else [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:" || WHY="$WHY $c{rc=$SRC $(head -3 "$CO" | tr '\n' ' ')}"; fi
    else WHY="$WHY $c{--record-run rc=$RRC $(head -1 "$MO")}"; fi
    G -C "$REPO_RR" checkout -q "$RR_BR"
    rm -f "$f" "$REPO_RR/.git/ai-dlc/stories/s1-1"
  done
  # rr-s-lead: the review in REPO_RRL, whose on-disk qa.md lacks the sentinel (a seat that stripped it), checked under a
  # project root whose installed qa.md carries it (PROJ_RUN): ROLE_MD holds the era, so a typed pair is REFUSED.
  # rr-s-leg (ALLOW, one property apart): the same file under PROJ, whose qa.md lacks it: SERIAL-OK, one LEGACY line.
  f="$REPO_RRL/docs/reviews/s1/1-qa-validation.md"; mkdir -p "${f%/*}"
  if [ -z "${PROJ_RUN:-}" ]; then
    PROJ_RUN="$WORK/proj-run"; mkdir -p "$PROJ_RUN" && cp -R "$PROJ/." "$PROJ_RUN/" && cp "$QA_MD_RUN" "$PROJ_RUN/core/team-roles/qa.md" \
      || { WHY="$WHY FIXTURE ERROR: PROJ_RUN was not built"; return 1; }
  fi
  if cell rr-s-lead; then
    sr_file "$f" "$pv"; CR_ROOT="$PROJ_RUN" cr_no "$sd" "$f" rr-s-lead "$RR_NOREC"; rm -f "$f"
  fi
  if cell rr-s-leg; then
    sr_file "$f" "$pv"; cr_ok "$sd" "$f" rr-s-leg
    n="$(grep -c "^$RR_LEG" "$CO")" || n=0; [ "$n" = 1 ] || WHY="$WHY rr-s-leg{LEGACY lines: $n}"
    rm -f "$f"
  fi
  # rr-s-lrl (BL-905 fold, after a pull): the lead's --lead-range over REPO_RRL, whose qa.md AT THE BASE lacks the
  # sentinel, under PROJ_RUN, whose installed qa.md carries it, the story's dispatch recorded at that base ->
  # SERIAL-OK with one LEGACY line: the tracked base blob alone decides, as the merge decides from qa.md at its base.
  # rr-s-lru (DENY twin, one property apart): no dispatch record, so the base is the seat's own choice and never
  # decides the era -> REFUSED, held by the installed qa.md, naming --record-dispatch or a re-run at the current base.
  # rr-s-lead (no range: the seat's own form) keeps ROLE_MD's hold, and rr-s-lrange holds the tracked base blob's own.
  for c in rr-s-lrl rr-s-lru; do
    cell "$c" || continue
    rm -f "$REPO_RRL/.git/ai-dlc/stories/s1-1"
    if [ "$c" = rr-s-lrl ]; then
      ( cd "$REPO_RRL" && ip_run "$sd/merge-review-shards.sh" mrs_main --record-dispatch s1-1 "$RRL_B" ) > "$CO" 2>&1 < /dev/null \
        || { WHY="$WHY $c{--record-dispatch: $(head -1 "$CO")}"; continue; }
    fi
    sr_file "$f" "$pv" "reviewed-sha: $RRL_F"
    ip_run -C "$REPO_RRL" -e "AI_DLC_PROJECT_ROOT=$PROJ_RUN" "$sd/merge-review-shards.sh" mrs_main --check-serial "$f" --gate qa --lead-range "$RRL_B" "$RRL_F" > "$CO" 2>&1 < /dev/null; SRC=$?
    n="$(grep -c "^$RR_LEG" "$CO")" || n=0
    if [ "$c" = rr-s-lrl ]; then
      [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:" && [ "$n" = 1 ] && has "$CO" "at $RRL_B prescribes no" || WHY="$WHY rr-s-lrl{rc=$SRC LEGACY lines: $n $(reline "$CO")}"
    else
      [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && [ "$n" = 0 ] && has "$CO" "$RR_NOREC" && has "$CO" "$SR_OWN" && ! has "$CO" SERIAL-OK \
        && has "$CO" "--record-dispatch s1-1 <dispatch sha>' from the lead checkout" && has "$CO" "or re-run QA at the current base" \
        || WHY="$WHY rr-s-lru{rc=$SRC LEGACY lines: $n $(reline "$CO")}"
    fi
    rm -f "$f" "$REPO_RRL/.git/ai-dlc/stories/s1-1"
  done
  # rr-c-lrl (BL-905 fold, the same shape for the canonical lines): the lead's --lead-range over REPO_CRL, whose qa.md AT
  # THE BASE lacks the canonical-run label, under PROJ, whose installed qa.md carries it, the story's dispatch recorded
  # at that base, and a PASS with no `Canonical run:` line -> SERIAL-OK with one canonical LEGACY line naming the base
  # blob: that blob alone decides (sr_era). rr-c-seat (DENY twin, one property apart): the same file in the seat's own
  # form (no range), where the installed qa.md holds the lines -> REFUSED, no run line. rr-c-lru (DENY twin): the
  # rr-c-lrl world with no dispatch record, so the seat-supplied base never decides -> REFUSED, no run line, naming
  # --record-dispatch or a re-run at the current base.
  f="$REPO_CRL/docs/reviews/s1/1-qa-validation.md"; mkdir -p "${f%/*}"
  for c in rr-c-lrl rr-c-lru rr-c-seat; do
    cell "$c" || continue
    rm -f "$REPO_CRL/.git/ai-dlc/stories/s1-1"
    if [ "$c" = rr-c-lrl ]; then
      ( cd "$REPO_CRL" && ip_run "$sd/merge-review-shards.sh" mrs_main --record-dispatch s1-1 "$CRL_BASE" ) > "$CO" 2>&1 < /dev/null \
        || { WHY="$WHY $c{--record-dispatch: $(head -1 "$CO")}"; continue; }
    fi
    SR_CANON='' sr_file "$f" "$pv" "reviewed-sha: $CRL_SHA"
    if [ "$c" = rr-c-lrl ]; then
      ip_run -C "$REPO_CRL" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --check-serial "$f" --gate qa --lead-range "$CRL_BASE" "$CRL_SHA" > "$CO" 2>&1 < /dev/null; SRC=$?
      n="$(grep -c "^$CR_LEG" "$CO")" || n=0
      [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:" && [ "$n" = 1 ] && has "$CO" "$CR_LEG .claude/team-roles/qa.md at $CRL_BASE prescribes no" \
        || WHY="$WHY rr-c-lrl{rc=$SRC canonical LEGACY lines: $n $(reline "$CO")}"
    elif [ "$c" = rr-c-lru ]; then
      ip_run -C "$REPO_CRL" -e "AI_DLC_PROJECT_ROOT=$PROJ" "$sd/merge-review-shards.sh" mrs_main --check-serial "$f" --gate qa --lead-range "$CRL_BASE" "$CRL_SHA" > "$CO" 2>&1 < /dev/null; SRC=$?
      n="$(grep -c "^$CR_LEG" "$CO")" || n=0
      [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && [ "$n" = 0 ] && has "$CO" "$CR_NORUN" && has "$CO" "$SR_OWN" && ! has "$CO" SERIAL-OK \
        && has "$CO" "--record-dispatch s1-1 <dispatch sha>' from the lead checkout" && has "$CO" "or re-run QA at the current base" \
        || WHY="$WHY rr-c-lru{rc=$SRC canonical LEGACY lines: $n $(reline "$CO")}"
    else cr_no "$sd" "$f" rr-c-seat "$CR_NORUN"; fi
    rm -f "$f" "$REPO_CRL/.git/ai-dlc/stories/s1-1"
  done
  [ -z "$WHY" ]
}
