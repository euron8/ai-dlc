#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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

set -uo pipefail

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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "preclassify-rename-row"
echo "  subject: ${RECON#$ROOT/}/preclassify.sh"

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

score() { # score <recon-dir> -> prints the failing arm letters, or empty
  local rows f="" n4 n
  rows="$(run_pc "$1")"
  # A. the new path is a plain upstream add
  [ "$(bucket_of "$rows" core/fixtures/probe/new-name.jsonl)" = UPSTREAM-ONLY-ADD ] || f="${f}A"
  # B. the old path is a gated upstream delete (consumer untouched)
  [ "$(bucket_of "$rows" core/fixtures/probe/old-name.jsonl)" = UPSTREAM-DELETED ] || f="${f}B"
  # C. the ordinary M row beside them still classifies (control)
  [ "$(bucket_of "$rows" core/fixtures/probe/run.sh)" = UPSTREAM-ONLY ] || f="${f}C"
  # D. every fixture row has exactly four fields, and there are rows to count
  n="$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')"
  n4="$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\// && NF==4' | wc -l | tr -d ' ')"
  { [ "$n" -ge 3 ] && [ "$n4" = "$n" ]; } || f="${f}D"
  printf '%s' "$f"
}

# --- 1. the shipping subject ---------------------------------------------------
got="$(score "$RECON")"
if [ -z "$got" ]; then
  ok "A the renamed file's NEW path is UPSTREAM-ONLY-ADD"
  ok "B the renamed file's OLD path is UPSTREAM-DELETED (gated), not a CLASSIFY row"
  ok "C the M row beside them (run.sh) still classifies as UPSTREAM-ONLY"
  ok "D every probe row carries exactly four fields, over a non-empty row set"
else
  bad "the shipping preclassify.sh fails arm(s) [$got] on a rename row. Rows:"
  run_pc "$RECON" | sed 's/^/          /' | sed 's/\t/<TAB>/g'
fi

# --- 2. the unmutated control ---------------------------------------------------
CTRL="$WORK/control"
cp -R "$RECON" "$CTRL" || exit 2
cmp -s "$RECON/preclassify.sh" "$CTRL/preclassify.sh" || { echo "FIXTURE ERROR: control copy differs from the subject" >&2; exit 2; }
if [ -z "$(score "$CTRL")" ]; then
  ok "unmutated control: a byte-identical copy of the reconcile dir scores clean, so the harness is not what a mutant verdict measures"
else
  echo "FIXTURE ERROR: the unmutated copy fails [$(score "$CTRL")] -- the harness, not the mutation, is what the arms report" >&2
  exit 2
fi

# --- 3. THE MUTANT: remove --no-renames, guarded by cmp -s ----------------------
# The pre-fix shape. Every arm must go red at once: A and B because neither path gets its
# own row, C stays green (the M row is untouched) and is what proves the mutant did not
# simply kill the whole pass, D because the joined row carries six fields.
#
# batch 121: `git diff --no-renames --name-status "$BASE" "$THEIRS" -- core/` moved out of
# preclassify.sh's own body and into lib.sh's shared `memo_diff_name_status()`, called with
# the SAME arguments through `memo_diff_name_status "$DIST" "$BASE" "$THEIRS" core/`. The
# mutation therefore now patches lib.sh, copied into the SAME mutant directory this fixture
# already builds -- preclassify.sh itself is untouched, exactly as its own header says only
# the flag moves, not the caller.
MUT="$WORK/mutant"
cp -R "$RECON" "$MUT" || exit 2
sed 's/diff --no-renames --name-status "\$_base" "\$_theirs" -- "\$@"/diff --name-status "$_base" "$_theirs" -- "$@"/g' \
  "$RECON/lib.sh" > "$MUT/lib.sh"
if cmp -s "$RECON/lib.sh" "$MUT/lib.sh"; then
  echo "FIXTURE ERROR: the mutation matched nothing -- the --no-renames line is not where this fixture expects it" >&2
  exit 2
fi
bash -n "$MUT/preclassify.sh" || { echo "FIXTURE ERROR: the mutant is not valid bash" >&2; exit 2; }
bash -n "$MUT/lib.sh" || { echo "FIXTURE ERROR: the mutated lib.sh is not valid bash" >&2; exit 2; }
mg="$(score "$MUT")"
case "$mg" in
  ABD) ok "MUTANT (--no-renames removed) fails exactly [A B D]: both rename paths lose their bucket and a six-field row appears, while the M control stays green" ;;
  "")  bad "MUTANT SURVIVED: with --no-renames removed every arm still passes, so nothing here can see a rename row" ;;
  *)   bad "MUTANT killed by [$mg], expected exactly [ABD] -- the arms are entangled or the control row is not independent" ;;
esac

# =============================================================================
# BL-230 — A GIT THAT FAILED IS NOT A GIT THAT ANSWERED
# =============================================================================
#
# THE DEFECT. Under a forced git failure preclassify.sh exited 0 in almost every case: a failed
# `diff --name-status` gave EMPTY output (the loop was the right side of a pipe, so git's status
# was lost), a failed `hash-object` read the consumer copy as MISSING, a failed `rev-parse` read
# the base or theirs blob as MISSING -- MISSING being a legitimate bucket input. And lib.sh's memo
# CACHED the failed status, so one transient failure was served to every later caller sharing
# that memo. This fixture's world is small and already classified above, so it hosts both arms.
#
#   c  a git shim fails ONE subcommand with 128 -> preclassify exits 2 and names
#      the call on stderr in the fixed grammar. Once per subcommand: diff, hash-object, rev-parse.
#      A render-only fix leaves preclassify exiting 0 here, so this is the arm that proves the
#      program itself refuses.
#   d  one shared memo, one forced 128 on the diff, then a healthy run IN THE SAME MEMO -> the
#      healthy run classifies. The first run must have refused, or d proves nothing about a
#      failure; the memo must be the same directory, or d proves nothing about a cache.
#
# THE SHIM IS A PATH ENTRY, so it reaches only the preclassify runs it wraps. A transparent run
# through it is the control: same rows as the unshimmed subject, and zero forced hits.
B230_RUN=1
case "$RECON" in */core/skills/ai-dlc-update/reconcile) B230_DIST=1 ;; *) B230_DIST=0 ;; esac
if ! grep -qF 'refusing to classify' "$RECON/preclassify.sh" || ! grep -qF '_ai_dlc_memo_serve' "$RECON/lib.sh"; then
  if [ "$B230_DIST" = 0 ]; then
    printf '  SKIP  BL-230 arms c d -- the installed preclassify.sh/lib.sh predate the fail-closed fix; it lands with the pull that carries this fixture\n'
    B230_RUN=0
  else
    printf '  --    (BL-230: this preclassify.sh/lib.sh predate the fail-closed fix; in the distribution the arms run anyway and must go red)\n'
  fi
fi

if [ "$B230_RUN" = 1 ]; then
  FX_REAL_GIT="$(command -v git)"; export FX_REAL_GIT
  SHIM="$WORK/shim"; mkdir -p "$SHIM" || exit 2
  # The subcommand is the first non-option word after `-C <dir>` / `-c <kv>`. FX_GIT_ONCE names a
  # file: when set, the shim fails only while that file is absent, and creates it on the failure.
  cat > "$SHIM/git" <<'SHIMEOF'
#!/usr/bin/env bash
sub=""; skip=0
for a in "$@"; do
  if [ "$skip" = 1 ]; then skip=0; continue; fi
  case "$a" in -C|-c) skip=1 ;; -*) ;; *) sub="$a"; break ;; esac
done
hit=""
case "${FX_GIT_FAIL:-}" in
  diff) if [ "$sub" = diff ]; then for a in "$@"; do [ "$a" = --name-status ] && hit=1; done; fi ;;
  hash-object|rev-parse|ls-files) [ "$sub" = "$FX_GIT_FAIL" ] && hit=1 ;;
esac
if [ -n "$hit" ] && [ -n "${FX_GIT_ONCE:-}" ] && [ -e "$FX_GIT_ONCE" ]; then hit=""; fi
if [ -n "$hit" ]; then
  [ -n "${FX_GIT_ONCE:-}" ] && : > "$FX_GIT_ONCE"
  [ -n "${FX_GIT_HITS:-}" ] && echo "$sub" >> "$FX_GIT_HITS"
  echo "fatal: forced by the preclassify-rename-row git shim ($FX_GIT_FAIL)" >&2
  exit 128
fi
exec "$FX_REAL_GIT" "$@"
SHIMEOF
  chmod +x "$SHIM/git" || exit 2

  # pc_shim <recon> <fail-subcommand|""> <out-prefix> [memo-dir] [once-file] -> rc; rows, stderr
  # and hits land in <out-prefix>.{rows,err,hits}
  pc_shim() {
    : > "$3.hits"
    PATH="$SHIM:$PATH" FX_GIT_FAIL="$2" FX_GIT_HITS="$3.hits" FX_GIT_ONCE="${5:-}" \
      AI_DLC_RECONCILE_MEMO="${4:-}" \
      bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$3.rows" 2> "$3.err"
  }
  # score_cd <recon-dir> <tag> -> the failing arm letters among c d, or FIXTURE-BROKEN text
  score_cd() {
    local _d="$1" _o="$WORK/b230-$2" _r="" _s _rc _m
    mkdir -p "$_o"
    # control: transparent shim, same classification as the subject run above, zero hits
    pc_shim "$_d" "" "$_o/ctl"; _rc=$?
    if [ "$_rc" -ne 0 ] || ! cmp -s "$_o/ctl.rows" "$WORK/b230-ref.rows" || [ -s "$_o/ctl.hits" ]; then
      printf 'BROKEN'; return
    fi
    for _s in diff hash-object rev-parse; do
      pc_shim "$_d" "$_s" "$_o/c-$_s"; _rc=$?
      # NOT "no rows": preclassify streams, so a failure late in the run follows rows already
      # printed (measured: the hash-object case prints one). Its contract is the exit and the
      # named call; both callers discard every row on a non-zero exit, and their fixtures own that.
      if [ "$_rc" -ne 2 ] || [ ! -s "$_o/c-$_s.hits" ] \
         || ! grep -qE '^preclassify: git failed, refusing to classify: .* exited 128$' "$_o/c-$_s.err"; then
        case "$_r" in *c*) ;; *) _r="${_r}c" ;; esac
        printf '%s: rc=%s rows=%s hits=%s stderr=%s\n' "$_s" "$_rc" "$(grep -c . "$_o/c-$_s.rows")" \
          "$(grep -c . "$_o/c-$_s.hits")" "$(head -1 "$_o/c-$_s.err")" >> "$_o/c.why"
      fi
    done
    _m="$_o/memo"; mkdir -p "$_m"
    pc_shim "$_d" diff "$_o/d1" "$_m" "$_o/d.once"; _rc=$?
    if [ "$_rc" -ne 2 ] || [ ! -e "$_o/d.once" ]; then
      _r="${_r}d"; printf 'the forced first run did not refuse (rc=%s, forced=%s)\n' "$_rc" "$([ -e "$_o/d.once" ] && echo yes || echo no)" >> "$_o/d.why"
    else
      pc_shim "$_d" diff "$_o/d2" "$_m" "$_o/d.once"; _rc=$?
      if [ "$_rc" -ne 0 ] || ! cmp -s "$_o/d2.rows" "$WORK/b230-ref.rows"; then
        _r="${_r}d"; printf 'the healthy run in the same memo rc=%s rows=%s (want 0 and the reference rows) -- the failure was served from the cache\n' \
          "$_rc" "$(grep -c . "$_o/d2.rows")" >> "$_o/d.why"
      fi
    fi
    printf '%s' "$_r"
  }

  run_pc "$RECON" > "$WORK/b230-ref.rows"
  if [ "$(grep -c . "$WORK/b230-ref.rows")" -lt 3 ]; then
    echo "FIXTURE ERROR: BL-230 reference classification has fewer than 3 rows, so c and d compare against nothing" >&2
    exit 2
  fi
  got="$(score_cd "$RECON" tip)"
  if [ "$got" = BROKEN ]; then
    echo "FIXTURE ERROR: BL-230 control -- preclassify through the TRANSPARENT shim did not reproduce the unshimmed rows with zero forced hits, so the shim is what c and d would measure" >&2
    exit 2
  fi
  ok "BL-230 control: preclassify through the transparent shim reproduces the unshimmed rows, zero forced hits"
  case "$got" in
    *c*) bad "BL-230 arm c: a forced git 128 did not make preclassify refuse -- $(tr '\n' ' ' < "$WORK/b230-tip/c.why")" ;;
    *)   ok "BL-230 arm c: a forced 128 on diff, hash-object or rev-parse makes preclassify exit 2, naming the call" ;;
  esac
  case "$got" in
    *d*) bad "BL-230 arm d: $(tr '\n' ' ' < "$WORK/b230-tip/d.why")" ;;
    *)   ok "BL-230 arm d: after a forced 128 the SAME memo answers the next run healthy -- the failure was not cached" ;;
  esac

  # THE MUTANT, owned by d: lib.sh caches every status, the pre-fix memo. Both status-filter lines
  # (memo_ls_tree and memo_diff_name_status carry the same one) are rewritten, counted as 2, so a
  # third copy of the filter cannot be left behind reading as a mutation. c must stay green: each
  # c run owns a fresh memo, so the cache is never re-read there.
  B230_M="$WORK/b230-mutant"
  cp -R "$RECON" "$B230_M" || exit 2
  # The filter is spelled across TWO lines since 0.656.0 (a failed serve returns 125 on each
  # branch), so the anchor is the `if` line and the mutation also drops the `else` line that
  # follows it -- both counted, both rewritten, the same "cache every status" observable.
  _anchor='    if [ "$_st" -eq 0 ]; then _ai_dlc_memo_commit "$_f" "$_t" "$_st" || return 125'
  _anchor2='    else _ai_dlc_memo_serve "$_t" || return 125; fi'
  _hits="$(grep -cxF "$_anchor" "$RECON/lib.sh")" || _hits=0
  _hits2="$(grep -cxF "$_anchor2" "$RECON/lib.sh")" || _hits2=0
  [ "$_hits2" -eq "$_hits" ] || _hits=0
  _ctl="$(grep -cxF 'ZZ-NO-SUCH-MEMO-ANCHOR-ZZ' "$RECON/lib.sh")" || _ctl=0
  B230_A="$_anchor" B230_B="$_anchor2" awk '
    $0 == ENVIRON["B230_A"] { print "    _ai_dlc_memo_commit \"$_f\" \"$_t\" \"$_st\" || return 125"; skip=1; next }
    skip && $0 == ENVIRON["B230_B"] { skip=0; next }
    { skip=0; print }' \
    "$RECON/lib.sh" > "$B230_M/lib.sh"
  if [ "$_hits" -ne 2 ] || [ "$_ctl" -ne 0 ]; then
    bad "FIXTURE STALE [BL-230 memo mutant]: the status-filter anchor matches $_hits lines of lib.sh (want 2; impossible-anchor control $_ctl, want 0). Re-anchor on the same observable"
  elif cmp -s "$RECON/lib.sh" "$B230_M/lib.sh" || ! bash -n "$B230_M/lib.sh"; then
    bad "FIXTURE STALE [BL-230 memo mutant]: the mutation did not apply or does not parse"
  else
    mg="$(score_cd "$B230_M" mutant)"
    case "$mg" in
      BROKEN) bad "MUTANT HARNESS BROKEN [BL-230 memo]: the copy's transparent control did not classify, so its verdict is a copy that did not run" ;;
      d)  ok "MUTANT (memo caches a failed status) fails exactly [d] -- the healthy run in the same memo is served the cached 128" ;;
      "") bad "MUTANT SURVIVED [BL-230 memo]: with every status cached, arm d still passed -- it cannot see the cache" ;;
      *)  bad "MUTANT [BL-230 memo] failed [$mg], expected exactly [d] -- the arms are entangled" ;;
    esac
  fi

  # ===========================================================================
  # BL-308 -- THE TWO OPTIONAL MODES REFUSE ON THEIR OWN
  # ===========================================================================
  # Arm c above drives the DEFAULT mode only. `--untangle` enumerates through its own
  # `ls-files` pipeline and `--templates` through its own `printf | while`, and each reaches
  # pc_fail() from a different subshell, so a mode can exit 0 over a failed git call while the
  # default mode refuses. One cell per forced call, each scored on the exit (2), a forced hit
  # (the shim really fired), and the fixed stderr grammar naming the call; the stdout row
  # count is recorded beside it, because rows printed before a refusal are partial by contract.
  #   U1 --untangle, ls-files fails     U2 --untangle, rev-parse fails
  #   U3 --untangle, hash-object fails  T1 --templates, rev-parse fails
  # OWN WORLD, so the rename world the arms above score is not changed: a dist carrying one
  # manifest-globbed file (core/rules/*.md) and one manifest template, edited at theirs, and a
  # consumer holding an edited copy of each -- so both modes classify a non-empty row set.
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

  # m_run <recon> <mode> <fail|""> <out-prefix> -- --untangle runs base == theirs, its contract
  m_run() {
    local _b="$M_B"; [ "$2" = --untangle ] && _b="$M_T"
    : > "$4.hits"
    PATH="$SHIM:$PATH" FX_GIT_FAIL="$3" FX_GIT_HITS="$4.hits" FX_GIT_ONCE="" AI_DLC_RECONCILE_MEMO="" \
      bash "$1/preclassify.sh" "$MD" "$_b" "$M_T" "$MC" "$2" > "$4.rows" 2> "$4.err"
  }
  # score_modes <recon> <tag> -> failing cells among U1 U2 U3 T1 (ending in `.`), or BROKEN.
  score_modes() {
    local _d="$1" _o="$WORK/b308-$2" _r="" _c _m _s _rc
    mkdir -p "$_o"
    # CONTROLS, one per mode: transparent shim, rc 0, zero hits, and the row the world seeds
    # must be THERE -- rc 0 with no rows is what a mode that classified nothing looks like.
    m_run "$_d" --untangle "" "$_o/ctl-u"; _rc=$?
    { [ "$_rc" -eq 0 ] && [ ! -s "$_o/ctl-u.hits" ] \
      && grep -q "^U	core/rules/probe.md	.claude/rules/probe.md	BOTH-CHANGED->CLASSIFY$" "$_o/ctl-u.rows"; } \
      || { printf 'BROKEN(untangle control rc=%s rows=%s)' "$_rc" "$(grep -c . "$_o/ctl-u.rows")"; return; }
    m_run "$_d" --templates "" "$_o/ctl-t"; _rc=$?
    { [ "$_rc" -eq 0 ] && [ ! -s "$_o/ctl-t.hits" ] \
      && grep -q "^T	templates/CLAUDE.md.template	CLAUDE.md	TEMPLATE-PROSE-MERGE$" "$_o/ctl-t.rows"; } \
      || { printf 'BROKEN(templates control rc=%s rows=%s)' "$_rc" "$(grep -c . "$_o/ctl-t.rows")"; return; }
    for _c in U1:--untangle:ls-files U2:--untangle:rev-parse U3:--untangle:hash-object T1:--templates:rev-parse; do
      _s="${_c#*:}"; _m="${_s%%:*}"; _s="${_s#*:}"; _c="${_c%%:*}"
      m_run "$_d" "$_m" "$_s" "$_o/$_c"; _rc=$?
      printf '%s %s %s: rc=%s rows=%s hits=%s stderr=%s\n' "$_c" "$_m" "$_s" "$_rc" "$(grep -c . "$_o/$_c.rows")" \
        "$(grep -c . "$_o/$_c.hits")" "$(head -1 "$_o/$_c.err")" >> "$_o/why"
      if [ "$_rc" -ne 2 ] || [ ! -s "$_o/$_c.hits" ] \
         || ! grep -qE "^preclassify: git failed, refusing to classify: ${_s} .* exited 128$" "$_o/$_c.err"; then
        _r="$_r$_c"
      fi
    done
    printf '%s.' "$_r"
  }
  b308_verdict() { # b308_verdict <recon> <tag> -> sets $got, or reports the harness broken
    got="$(score_modes "$1" "$2")"
    case "$got" in *.) got="${got%.}"; return 0 ;; esac
    return 1
  }
  if ! b308_verdict "$RECON" tip; then
    echo "FIXTURE ERROR: BL-308 $got -- a mode through the TRANSPARENT shim did not classify its seeded row, so every forced cell would measure the harness" >&2
    exit 2
  fi
  ok "BL-308 control: --untangle and --templates each classify their seeded row through the transparent shim, zero forced hits"
  if [ -z "$got" ]; then
    ok "BL-308 U1-U3 T1: a forced 128 on ls-files, rev-parse or hash-object under --untangle, and on rev-parse under --templates, exits 2 naming the call ($(awk '{printf "%s %s; ", $1, $5}' "$WORK/b308-tip/why"))"
  else
    bad "BL-308 cell(s) [$got]: a mode exited other than 2 over a forced git failure, or did not name the call -- $(tr '\n' ' ' < "$WORK/b308-tip/why")"
  fi
  # MUTANTS, each a copy of the whole reconcile dir, each owning one mode's route to pc_fail():
  #   untangle-nols  the `|| pc_fail` on --untangle's ls-files removed: its enumeration fails
  #                  into an empty stream and the mode exits 0            -> exactly [U1]
  #   templates-notrap  --templates disarms the USR1 trap before its loop, so pc_fail() in a
  #                  `$( )` ends only the subshell, both hashes read empty and equal, and the
  #                  row reads TEMPLATE-UNCHANGED-NOOP at rc 0              -> exactly [T1]
  b308_mut() { # b308_mut <name> <awk-program> <want>
    local _d="$WORK/b308-m-$1" _n _ctl
    cp -R "$RECON" "$_d" || exit 2
    awk "$2" "$RECON/preclassify.sh" > "$_d/preclassify.sh" 2>/dev/null
    if cmp -s "$RECON/preclassify.sh" "$_d/preclassify.sh" || ! bash -n "$_d/preclassify.sh" 2>/dev/null; then
      bad "FIXTURE STALE [BL-308 mutant $1]: the mutation did not apply or does not parse -- re-anchor it on the same observable"
      return
    fi
    if ! b308_verdict "$_d" "$1"; then bad "MUTANT HARNESS BROKEN [BL-308 $1]: $got"; return; fi
    case "$got" in
      "$3") ok "MUTANT (BL-308 $1) fails exactly [$3]" ;;
      "")   bad "MUTANT SURVIVED [BL-308 $1]: every mode cell still passed" ;;
      *)    bad "MUTANT [BL-308 $1] failed [$got], expected exactly [$3] -- the cells are entangled" ;;
    esac
  }
  _u_anchor='    git -C "$DIST" -c core.quotePath=false ls-files "$glob" || pc_fail "ls-files $glob exited $?"'
  # A consumer layout whose preclassify.sh predates the quotePath flag on this line carries the
  # unflagged spelling; the mutant below targets whichever one the subject carries.
  grep -qxF "$_u_anchor" "$RECON/preclassify.sh" \
    || _u_anchor='    git -C "$DIST" ls-files "$glob" || pc_fail "ls-files $glob exited $?"'
  _t_anchor='  printf '"'"'%s\n'"'"' "$TEMPLATE_ROWS" |'
  _uh="$(grep -cxF "$_u_anchor" "$RECON/preclassify.sh")" || _uh=0
  _th="$(grep -cxF "$_t_anchor" "$RECON/preclassify.sh")" || _th=0
  _xh="$(grep -cxF 'ZZ-NO-SUCH-PRECLASSIFY-ANCHOR-ZZ' "$RECON/preclassify.sh")" || _xh=0
  if [ "$_uh" -ne 1 ] || [ "$_th" -ne 1 ] || [ "$_xh" -ne 0 ]; then
    bad "FIXTURE STALE [BL-308 mutants]: anchors match untangle=$_uh templates=$_th (want 1 each; impossible-anchor control $_xh, want 0)"
  else
    B308_A="$_u_anchor" b308_mut untangle-nols \
      '$0 == ENVIRON["B308_A"] { sub(/ [|][|] pc_fail.*$/, ""); print; next } { print }' U1
    B308_A="$_t_anchor" b308_mut templates-notrap \
      '$0 == ENVIRON["B308_A"] { print "  trap : USR1" } { print }' T1
  fi
fi

# --- 4. A MEMO FILE THAT CANNOT BE CREATED MUST NOT CHANGE THE ANSWER ----------------
# Every lib.sh memo names its cache file after a key that embeds the percent-encoded dist path.
# When that file cannot be created -- a dist path past the 255-character filename limit, or a
# memo directory that cannot be written (read-only, or ENOSPC on a full disk) -- the unfixed fill
# reported its failed REDIRECT's status as git's and served nothing: preclassify.sh from a
# 309-character dist emitted 0 bytes with exit 0, and memo_has_path read a present path as absent.
#
#   E. preclassify.sh from a dist whose ABSOLUTE path exceeds 255 characters (two nested
#      150-character components, so the length does not depend on TMPDIR) emits exactly the
#      bytes the short dist emits. The length is asserted in the same run.
#   F. preclassify.sh from the short dist with AI_DLC_RECONCILE_MEMO set to a `chmod 555`
#      directory emits exactly the writable run's bytes. A LENGTH-BOUNDED fix passes E and
#      fails here, because a short key in an unwritable directory is just as wrong.
#   G. memo_has_path with that unwritable memo returns 0 on a present path and non-zero on an
#      absent one (the unfixed read-back of a `.s` it never wrote returned 255 on both).
#   H. memo_has_path on a present path whose `.s` name is OCCUPIED by a directory, so the fill
#      file is creatable but the status can never be read back: it must return 0. This is the
#      only world that separates "return the in-memory status" from "read `.s` back", because
#      in E-G the creation probe already routes the lookup direct.
#
# E and F are PRESENCE-shaped by their positive conjunct: the short run must emit the probe
# rows the arms above require, so two empty outputs cannot compare equal.
LONGD="$WORK/$(printf 'L%.0s' $(seq 1 150))/$(printf 'M%.0s' $(seq 1 150))/dist"
mkdir -p "${LONGD%/dist}" && cp -R "$DIST" "$LONGD" || { echo "FIXTURE ERROR: could not build the long dist" >&2; exit 2; }
[ "${#LONGD}" -gt 255 ] || { echo "FIXTURE ERROR: the long dist path is ${#LONGD} characters, not over 255" >&2; exit 2; }
RO="$WORK/ro-memo"
mkdir -p "$RO" && chmod 555 "$RO" || exit 2
if ( : > "$RO/probe" ) 2>/dev/null; then
  echo "FIXTURE ERROR: a chmod 555 directory is writable here (running as root?), so arms F-G cannot express the defect" >&2
  exit 2
fi
# The dist is passed RELATIVE (`dist`, from inside $WORK), so G and H's keys are short whatever
# TMPDIR is: they must isolate the unwritable directory and the occupied `.s`, never the length.
has_path_rc() { # has_path_rc <recon> <memo-dir> <ref> <path> -> memo_has_path's status; 97 = lib.sh did not load
  ( cd "$WORK" && AI_DLC_RECONCILE_MEMO="$2" bash -c '. "$1/lib.sh" 2>/dev/null; command -v memo_has_path >/dev/null || exit 97; memo_has_path dist "$2" "$3"' \
    _ "$1" "$3" "$4" 2>/dev/null )
}
score_memo() { # score_memo <recon-dir> -> prints the failing arm letters (E-H), or empty
  local f="" s l r n rc m occ
  s="$(env -u AI_DLC_RECONCILE_MEMO bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
  n="$(printf '%s\n' "$s" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')"
  if [ "$n" -lt 3 ]; then f="EF"; else
    l="$(env -u AI_DLC_RECONCILE_MEMO bash "$1/preclassify.sh" "$LONGD" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    [ "$s" = "$l" ] || f="${f}E"
    r="$(AI_DLC_RECONCILE_MEMO="$RO" bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    [ "$s" = "$r" ] || f="${f}F"
  fi
  has_path_rc "$1" "$RO" "$THEIRS" core/fixtures/probe/run.sh; rc=$?
  [ "$rc" -ne 97 ] || { echo "FIXTURE ERROR: $1/lib.sh did not define memo_has_path" >&2; exit 2; }
  has_path_rc "$1" "$RO" "$THEIRS" core/fixtures/probe/old-name.jsonl; r=$?
  { [ "$rc" -eq 0 ] && [ "$r" -ne 0 ]; } || f="${f}G"
  # H: derive the `.s` name from the producer in a writable memo, then occupy it with a directory.
  m="$(mktemp -d "$WORK/occ.XXXXXX")" || exit 2
  has_path_rc "$1" "$m" "$THEIRS" core/fixtures/probe/run.sh >/dev/null
  occ="$(cd "$m" && ls | LC_ALL=C grep '^e .*\.s$')"
  [ -n "$occ" ] && [ "$(printf '%s\n' "$occ" | wc -l | tr -d ' ')" = 1 ] \
    || { echo "FIXTURE ERROR: the writable memo holds no single memo_has_path status file to occupy" >&2; exit 2; }
  mv "$m/$occ" "$m/$occ.was" && mkdir "$m/$occ" || exit 2
  has_path_rc "$1" "$m" "$THEIRS" core/fixtures/probe/run.sh; rc=$?
  [ "$rc" -ne 97 ] || exit 2
  [ "$rc" -eq 0 ] || f="${f}H"
  printf '%s.' "$f"
}
# `score_memo` runs inside `$( )`, where its `exit 2` ends only the subshell and would hand back
# an EMPTY string -- a PASS. Every completed score therefore ends in `.`, and a score without
# one is a harness that died.
memo_verdict() { # memo_verdict <recon-dir> -> sets $got, or exits 2
  got="$(score_memo "$1")"
  case "$got" in
    *.) got="${got%.}" ;;
    *)  echo "FIXTURE ERROR: the memo arms did not complete against $1" >&2; exit 2 ;;
  esac
}

memo_verdict "$RECON"
if [ -z "$got" ]; then
  ok "E a dist path of ${#LONGD} characters classifies byte-identically to the short one"
  ok "F an unwritable memo directory classifies byte-identically to a writable one"
  ok "G memo_has_path with an unwritable memo answers 0 on a present path and non-zero on an absent one"
  ok "H memo_has_path returns its in-memory status when its .s name is occupied, never a read-back"
else
  bad "the shipping lib.sh fails memo arm(s) [$got]: a memo file that cannot be created changes the answer"
fi
subj_got="$got"
memo_verdict "$CTRL"
# The copy must score exactly as the subject does. A subject that fails is reported above as a
# FAIL (exit 1); only a copy that scores DIFFERENTLY is a harness fault.
[ "$got" = "$subj_got" ] || { echo "FIXTURE ERROR: the unmutated copy scores [$got] where the subject scores [$subj_got]" >&2; exit 2; }
ok "unmutated control scores exactly as the subject on E-H"

# THE MUTANTS, each a copy of the WHOLE reconcile dir. The fix has two layers and each gets its
# own mutant, plus the full revert: removing the fill-file creation probe (the direct fall-through
# never fires), and restoring the read-back of `.s` after a memo_has_path fill.
mut_memo() { # mut_memo <name> <mode> -> mutant dir on stdout
  local d="$WORK/memo-$1" before after
  cp -R "$RECON" "$d" || exit 2
  cp "$RECON/lib.sh" "$d/lib.sh.in"
  case "$2" in
    probe|both)
      sed 's/^  { : > "\$_t"; } 2>\/dev\/null$/  :/' "$d/lib.sh.in" > "$d/lib.sh.p" || { echo "FIXTURE ERROR: mutation $1 DID NOT APPLY (sed died)" >&2; exit 2; }
      cmp -s "$d/lib.sh.in" "$d/lib.sh.p" && { echo "FIXTURE ERROR: mutation $1 matched nothing -- the fill-file probe moved" >&2; exit 2; }
      mv "$d/lib.sh.p" "$d/lib.sh.in" ;;
  esac
  case "$2" in
    readback|both)
      # Delete the FILL's `return` inside memo_has_path only (four-space indent; the hit's is two),
      # so a fill falls through to `_st="$(<"$_f.s")"` as it did before the fix.
      LC_ALL=C awk '/^memo_has_path\(\) \{/{inf=1} inf && /^}/{inf=0} inf && !done && $0=="    return \"$_st\"" {done=1; next} {print}' \
        "$d/lib.sh.in" > "$d/lib.sh.r" || { echo "FIXTURE ERROR: mutation $1 DID NOT APPLY (awk died)" >&2; exit 2; }
      before="$(wc -l < "$d/lib.sh.in")"; after="$(wc -l < "$d/lib.sh.r")"
      [ "$((before - after))" -eq 1 ] || { echo "FIXTURE ERROR: mutation $1 removed $((before - after)) lines, expected 1" >&2; exit 2; }
      mv "$d/lib.sh.r" "$d/lib.sh.in" ;;
  esac
  mv "$d/lib.sh.in" "$d/lib.sh"
  cmp -s "$RECON/lib.sh" "$d/lib.sh" && { echo "FIXTURE ERROR: mutant $1 is byte-identical to the subject" >&2; exit 2; }
  bash -n "$d/lib.sh" || { echo "FIXTURE ERROR: mutant $1 does not parse" >&2; exit 2; }
  printf '%s' "$d"
}
# A subject that already fails E-H has no fix to revert, so its mutants cannot be built: the
# FAIL above is the verdict, and the battery is scored only over a subject that passed.
[ -n "$subj_got" ] && echo "  (memo mutants not scored: the subject itself fails [$subj_got])"
[ -n "$subj_got" ] || for spec in "probe:probe:EF" "readback:readback:H" "unfixed:both:EFGH"; do
  name="${spec%%:*}"; rest="${spec#*:}"; mode="${rest%%:*}"; want="${rest#*:}"
  md="$(mut_memo "$name" "$mode")"
  [ -n "$md" ] && [ -d "$md" ] || { echo "FIXTURE ERROR: mutant $name was not built" >&2; exit 2; }
  memo_verdict "$md"; mg="$got"
  case "$mg" in
    "$want") ok "MUTANT $name fails exactly [$want]" ;;
    "")      bad "MUTANT $name SURVIVED: every memo arm still passes" ;;
    *)       bad "MUTANT $name killed by [$mg], expected exactly [$want]" ;;
  esac
done
chmod 755 "$RO"

# =============================================================================
# BL-374 / BL-310 -- A READ FAILURE IS NEVER CACHED, OR ANSWERED, AS AN ABSENCE
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
#   a memo_has_path, a/b tree missing, writable memo   -> 125     b  the same, chmod-555 memo -> 125
#   c memo_rev_parse, a/b tree missing, writable memo  -> 125     d  the same, chmod-555 memo -> 125
#   e the writable memo queried while missing, after restore -> memo_has_path 0 AND memo_rev_parse 0
#   f memo_has_path, top.txt's BLOB missing, writable  -> 125     g  the same, chmod-555 memo -> 125
#   h a NON-CANONICAL spelling (a/./b/f.txt) on a healthy tree -> memo_has_path 128, memo_rev_parse 1;
#     an absolute path INTO the repository (<dist>/top.txt) -> memo_has_path 128
#   i a `..` spelling that climbs out (../x) on a healthy tree -> memo_has_path 128
#   m an absolute path OUTSIDE the repository (/etc/passwd) -> memo_has_path 128, memo_rev_parse 1
#   n a pathspec-magic spelling (:(glob)a/**) -> memo_has_path 128, memo_rev_parse 1
#   j preclassify --untangle AND --templates, each with its subject's tree missing -> exit 2, named
#   k preclassify --untangle with an unresolvable rev -> exit 2 (it bucketed every row before)
#   l preclassify's dist_only(), the .dist-only marker read as cat-file 128 / rev-parse 1 / ls-tree 1
#     (the missing-subtree signature, forced by a shim) -> exit 2, not "not dist-only"
# h, i, m and n are the NEAR-MISSES: all are absences the naive rule ("ls-tree rc 0 with a line, or any
# non-zero, is a failure") reads as failures, and a ledger path spelled that way would then refuse.
N_RUN=1
case "$RECON" in */core/skills/ai-dlc-update/reconcile) N_DIST=1 ;; *) N_DIST=0 ;; esac
if ! grep -qF '_ai_dlc_rev_absent' "$RECON/lib.sh"; then
  if [ "$N_DIST" = 0 ]; then
    printf '  SKIP  BL-374/BL-310 arms a-l -- the installed lib.sh predates the ls-tree discriminator; it lands with the pull that carries this fixture\n'
    N_RUN=0
  else
    printf '  --    (BL-374/BL-310: this lib.sh carries no ls-tree discriminator; in the distribution the arms run anyway and must go red)\n'
  fi
fi
if [ "$N_RUN" = 1 ]; then
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
  # lq <recon> <memo> <fn> <args...> -> the function's status; 97 = lib.sh did not load
  lq() {
    local _r="$1" _m="$2"; shift 2
    ( cd "$NW" && AI_DLC_RECONCILE_MEMO="$_m" bash -c '. "$1/lib.sh" 2>/dev/null; command -v memo_has_path >/dev/null || exit 97; shift; "$@" >/dev/null 2>&1' _ "$_r" "$@" 2>/dev/null )
  }
  aside() { mv "$1" "$1.aside" || { echo "FIXTURE ERROR: could not move $1 aside" >&2; exit 2; }; }
  back()  { mv "$1.aside" "$1" || { echo "FIXTURE ERROR: could not restore $1" >&2; exit 2; }; }
  # SEED CONTROL: with a/b moved aside ls-tree must FAIL on the path, or no cell expresses the defect.
  aside "$O_AB"
  git -C "$ND" ls-tree --full-tree HEAD -- a/b/f.txt >/dev/null 2>&1 && { back "$O_AB"; echo "FIXTURE ERROR: BL-374 seed did not take -- ls-tree reads a/b/f.txt with its tree moved aside" >&2; exit 2; }
  back "$O_AB"
  # The l shim: the .dist-only marker of core/fixtures/probe reads as a missing subtree would.
  NSHIM="$NW/shim"; mkdir -p "$NSHIM" || exit 2
  FX_N_REAL_GIT="$(command -v git)"; export FX_N_REAL_GIT
  cat > "$NSHIM/git" <<'NSHIMEOF'
#!/usr/bin/env bash
if [ -n "${FX_N_FORCE:-}" ]; then
  case "$*" in
    *core/fixtures/probe/.dist-only*)
      [ -n "${FX_N_HITS:-}" ] && echo hit >> "$FX_N_HITS"
      case "$*" in *cat-file*) exit 128 ;; *rev-parse*) exit 1 ;; *ls-tree*) exit 1 ;; esac ;;
  esac
fi
exec "$FX_N_REAL_GIT" "$@"
NSHIMEOF
  chmod +x "$NSHIM/git" || exit 2
  # n_pc <recon> <out-prefix> <base> <theirs> <mode> -> rc
  n_pc() { AI_DLC_RECONCILE_MEMO="" bash "$1/preclassify.sh" "$ND" "$3" "$4" "$NC" "$5" > "$2.rows" 2> "$2.err"; }
  score_n() { # score_n <recon> <tag> -> failing cells a-n then `.`, or BROKEN(...)
    local _d="$1" _o="$NW/s-$2" _r="" _m _x _y _rc
    mkdir -p "$_o"
    # CONTROLS on the healthy tree, every one PRESENCE-shaped
    [ "$(lq "$_d" "$_o" true; echo $?)" = 0 ] || { printf 'BROKEN(lib.sh did not load)'; return; }
    _m="$_o/m"; mkdir -p "$_m"
    lq "$_d" "$_m" memo_has_path dist HEAD top.txt || { printf 'BROKEN(has top.txt != 0)'; return; }
    [ -n "$(ls -A "$_m")" ] || { printf 'BROKEN(the memo was never written)'; return; }
    lq "$_d" "$_o" memo_has_path dist HEAD nope.txt; [ "$?" = 128 ] || { printf 'BROKEN(has nope.txt != 128)'; return; }
    lq "$_d" "$_o" memo_rev_parse dist HEAD:nope.txt; [ "$?" = 1 ] || { printf 'BROKEN(rev_parse nope.txt != 1)'; return; }
    n_pc "$_d" "$_o/cu" "$NH" "$NH" --untangle; _rc=$?
    { [ "$_rc" = 0 ] && grep -q "^U	core/rules/probe.md	.claude/rules/probe.md	ALREADY-AT-THEIRS$" "$_o/cu.rows"; } \
      || { printf 'BROKEN(untangle control rc=%s)' "$_rc"; return; }
    n_pc "$_d" "$_o/ct" "$NH" "$NH" --templates; _rc=$?
    { [ "$_rc" = 0 ] && grep -q "^T	templates/CLAUDE.md.template	CLAUDE.md	TEMPLATE-UNCHANGED-NOOP$" "$_o/ct.rows"; } \
      || { printf 'BROKEN(templates control rc=%s)' "$_rc"; return; }
    : > "$_o/l0.hits"
    PATH="$NSHIM:$PATH" FX_N_FORCE="" FX_N_HITS="$_o/l0.hits" AI_DLC_RECONCILE_MEMO="" \
      bash "$_d/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$_o/l0.rows" 2>/dev/null; _rc=$?
    { [ "$_rc" = 0 ] && cmp -s "$_o/l0.rows" "$WORK/n-ref.rows" && [ ! -s "$_o/l0.hits" ]; } \
      || { printf 'BROKEN(transparent shim rc=%s)' "$_rc"; return; }
    # --- a b c d e: the a/b tree moved aside
    aside "$O_AB"
    lq "$_d" "$_m" memo_has_path dist HEAD a/b/f.txt;    _x=$?; [ "$_x" = 125 ] || _r="${_r}a"
    lq "$_d" "$NRO" memo_has_path dist HEAD a/b/f.txt;   _x=$?; [ "$_x" = 125 ] || _r="${_r}b"
    lq "$_d" "$_m" memo_rev_parse dist HEAD:a/b/f.txt;   _x=$?; [ "$_x" = 125 ] || _r="${_r}c"
    lq "$_d" "$NRO" memo_rev_parse dist HEAD:a/b/f.txt;  _x=$?; [ "$_x" = 125 ] || _r="${_r}d"
    back "$O_AB"
    lq "$_d" "$_m" memo_has_path dist HEAD a/b/f.txt;    _x=$?
    lq "$_d" "$_m" memo_rev_parse dist HEAD:a/b/f.txt;   _y=$?
    { [ "$_x" = 0 ] && [ "$_y" = 0 ]; } || _r="${_r}e"
    # --- f g: top.txt's blob moved aside (a fresh memo, so f reads the fill, not e's cache)
    mkdir -p "$_o/mf"; aside "$O_TOP"
    lq "$_d" "$_o/mf" memo_has_path dist HEAD top.txt;   _x=$?; [ "$_x" = 125 ] || _r="${_r}f"
    lq "$_d" "$NRO" memo_has_path dist HEAD top.txt;     _x=$?; [ "$_x" = 125 ] || _r="${_r}g"
    back "$O_TOP"
    # --- h i: healthy tree, spellings that are absences
    mkdir -p "$_o/mh"
    lq "$_d" "$_o/mh" memo_has_path dist HEAD a/./b/f.txt;  _x=$?
    lq "$_d" "$_o/mh" memo_rev_parse dist HEAD:a//b/f.txt; _y=$?
    # and an absolute path INTO the repository: ls-tree lists the RELATIVE name, a different path
    lq "$_d" "$_o/mh" memo_has_path dist HEAD "$ND/top.txt"; _z=$?
    { [ "$_x" = 128 ] && [ "$_y" = 1 ] && [ "$_z" = 128 ]; } || _r="${_r}h"
    lq "$_d" "$_o/mh" memo_has_path dist HEAD ../x;         _x=$?; [ "$_x" = 128 ] || _r="${_r}i"
    # --- m: an absolute path OUTSIDE the repository is refused before any object is read, like `..`
    mkdir -p "$_o/mm"
    lq "$_d" "$_o/mm" memo_has_path dist HEAD /etc/passwd;  _x=$?
    lq "$_d" "$_o/mm" memo_rev_parse dist HEAD:/etc/passwd; _y=$?
    { [ "$_x" = 128 ] && [ "$_y" = 1 ]; } || _r="${_r}m"
    # --- n: a pathspec-magic spelling names no tree entry; ls-tree reads it literally, as cat-file does
    mkdir -p "$_o/mn"
    lq "$_d" "$_o/mn" memo_has_path dist HEAD ':(glob)a/**';  _x=$?
    lq "$_d" "$_o/mn" memo_rev_parse dist 'HEAD::(glob)a/**'; _y=$?
    { [ "$_x" = 128 ] && [ "$_y" = 1 ]; } || _r="${_r}n"
    # --- j: each mode with its subject's tree missing
    aside "$O_RULES"; n_pc "$_d" "$_o/ju" "$NH" "$NH" --untangle; _x=$?; back "$O_RULES"
    aside "$O_TPL";   n_pc "$_d" "$_o/jt" "$NH" "$NH" --templates; _y=$?; back "$O_TPL"
    { [ "$_x" = 2 ] && [ "$_y" = 2 ] && grep -q 'ls-tree could not confirm it' "$_o/ju.err" \
      && grep -q 'ls-tree could not confirm it' "$_o/jt.err"; } || _r="${_r}j"
    # --- k: an unresolvable rev under --untangle
    n_pc "$_d" "$_o/k" 1111111111111111111111111111111111111111 1111111111111111111111111111111111111111 --untangle; _x=$?
    { [ "$_x" = 2 ] && grep -q 'ls-tree could not confirm it' "$_o/k.err"; } || _r="${_r}k"
    # --- l: dist_only() under the forced missing-subtree signature
    : > "$_o/l.hits"
    PATH="$NSHIM:$PATH" FX_N_FORCE=1 FX_N_HITS="$_o/l.hits" AI_DLC_RECONCILE_MEMO="" \
      bash "$_d/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$_o/l.rows" 2> "$_o/l.err"; _x=$?
    { [ "$_x" = 2 ] && [ -s "$_o/l.hits" ] && grep -q 'dist-only exited 125' "$_o/l.err"; } || _r="${_r}l"
    printf '%s.' "$_r"
  }
  n_verdict() { got="$(score_n "$1" "$2")"; case "$got" in *.) got="${got%.}"; return 0 ;; esac; return 1; }
  AI_DLC_RECONCILE_MEMO="" bash "$RECON/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$WORK/n-ref.rows" 2>/dev/null \
    || { echo "FIXTURE ERROR: BL-374 reference classification failed" >&2; exit 2; }
  if ! n_verdict "$RECON" tip; then
    echo "FIXTURE ERROR: BL-374/BL-310 $got -- a healthy-tree control did not hold, so every cell would measure the harness" >&2
    exit 2
  fi
  ok "BL-374/BL-310 controls: present 0, absent 128/1, the memo written, both modes and the transparent shim classify"
  n_subj="$got"
  if [ -z "$got" ]; then
    ok "BL-374/BL-310 a-g: a missing subtree or blob reads 125 from memo_has_path and memo_rev_parse, writable or chmod-555 memo, and is never cached"
    ok "BL-374/BL-310 h-i: a non-canonical spelling, an absolute path into the repository and a climbing \`..\` are still ABSENT (128 / 1), never a refusal"
    ok "BL-310 m-n: an absolute path outside the repository and a pathspec-magic spelling are ABSENT (128 / 1), never a refusal"
    ok "BL-374 j-l: preclassify refuses (exit 2) on a missing subtree in --untangle and --templates, an unresolvable rev, and an unconfirmable .dist-only marker"
  else
    bad "BL-374/BL-310 cell(s) [$got] failed -- a read failure is still answered or cached as an absence (see the cell table above)"
  fi
  # THE MUTANTS, each a copy of the whole reconcile dir, each one wrong fix with its exact signature.
  n_mut() { # n_mut <name> <want> <file> <find> <replace> [<find> <replace>...]
    local _n="$1" _w="$2" _f="$3" _d="$NW/mut-$1"; shift 3
    cp -R "$RECON" "$_d" || exit 2
    if ! python3 - "$RECON/$_f" "$_d/$_f" "$@" <<'PY'
import sys
src, dst, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
s = open(src, encoding="utf-8").read()
for i in range(0, len(pairs), 2):
    if s.count(pairs[i]) != 1:
        sys.exit(1)
    s = s.replace(pairs[i], pairs[i + 1])
open(dst, "w", encoding="utf-8").write(s)
PY
    then bad "FIXTURE STALE [BL-374 mutant $_n]: an anchor did not match exactly once in $_f -- re-anchor on the same observable"; return; fi
    if cmp -s "$RECON/$_f" "$_d/$_f" || ! bash -n "$_d/$_f" 2>/dev/null; then
      bad "FIXTURE STALE [BL-374 mutant $_n]: the mutation did not apply or does not parse"; return; fi
    if ! n_verdict "$_d" "$_n"; then bad "MUTANT HARNESS BROKEN [BL-374 $_n]: $got"; return; fi
    case "$got" in
      "$_w") ok "MUTANT (BL-374 $_n) fails exactly [$_w]" ;;
      "")    bad "MUTANT SURVIVED [BL-374 $_n]: every cell still passed" ;;
      *)     bad "MUTANT [BL-374 $_n] failed [$got], expected exactly [$_w]" ;;
    esac
  }
  if [ -n "$n_subj" ]; then
    echo "  (BL-374 mutants not scored: the subject itself fails [$n_subj])"
  else
    N_ABS_BODY='  local _e _lr=0
  { _e="$(git -C "$1" --literal-pathspecs ls-tree -z --full-tree "$2" -- "$3" 2>/dev/null)"; } 2>/dev/null || _lr=$?
  if [ "$_lr" -eq 0 ]; then
    [ -n "$_e" ] || return 0
    [ "${_e#*$'"'"'\t'"'"'}" = "$3" ] && return 1
    return 0
  fi
  case "/$3/" in */../*) return 0 ;; esac
  case "$3" in /*) return 0 ;; esac
  return 1'
    # the pre-fix oracle: rev-parse -q --verify answering 1
    n_mut revparse-oracle abcdeijkl lib.sh "$N_ABS_BODY" '  git -C "$1" rev-parse -q --verify "$2:$3" >/dev/null 2>&1
  [ "$?" -eq 1 ]'
    # the naive rule: a line at rc 0 is a failure whatever path it names
    n_mut naive-line h lib.sh '    [ "${_e#*$'"'"'\t'"'"'}" = "$3" ] && return 1
    return 0' '    return 1'
    # no `..` clause: every non-zero ls-tree is a failure
    n_mut no-dotdot i lib.sh '  case "/$3/" in */../*) return 0 ;; esac
  case "$3" in /*) return 0 ;; esac' '  case "$3" in /*) return 0 ;; esac'
    # no absolute-path clause: git's "outside repository" 128 on /etc/passwd reads as a failure
    n_mut no-abs m lib.sh '  case "$3" in /*) return 0 ;; esac
  return 1
}' '  return 1
}'
    # pathspecs read as magic again: ls-tree refuses `:(glob)…` at 128, read as a failure
    n_mut no-literal n lib.sh 'git -C "$1" --literal-pathspecs ls-tree -z' 'git -C "$1" ls-tree -z'
    # the direct lines keep git's raw status (an unwritable memo answers differently)
    n_mut raw-direct bdg lib.sh \
      '    [ "$_st" -eq 0 ] || _ai_dlc_memo_absent "$_dist" "$_ref" "$_path" || return 125; return "$_st"; }' '    return "$_st"; }' \
      '    [ "$_st" -ne 1 ] || _ai_dlc_rev_absent "$_dist" "$_spec" || return 125; return "$_st"; }' '    return "$_st"; }'
    # the lib-only half-fix: memo_rev_parse caches its 1 unconditionally, as before
    n_mut rev-parse-caches-1 cejk lib.sh \
      '      1) if _ai_dlc_rev_absent "$_dist" "$_spec"; then _ai_dlc_memo_commit "$_f" "$_t" "$_st" || return 125
         else _ai_dlc_memo_serve "$_t"; return 125; fi ;;' '      1) _ai_dlc_memo_commit "$_f" "$_t" "$_st" || return 125 ;;'
    # the BL-310 half-fix keyed on 128: a missing blob (cat-file 1) is still answered as absent
    n_mut keyed-on-128 fg lib.sh \
      '    [ "$_st" -eq 0 ] || _ai_dlc_memo_absent "$_dist" "$_ref" "$_path" || return 125; return "$_st"; }' '    [ "$_st" -ne 128 ] || _ai_dlc_memo_absent "$_dist" "$_ref" "$_path" || return 125; return "$_st"; }' \
      '      _ai_dlc_memo_absent "$_dist" "$_ref" "$_path" || _st=125' '      [ "$_st" -ne 128 ] || _ai_dlc_memo_absent "$_dist" "$_ref" "$_path" || _st=125'
    # dist_only keeps its own rev-parse second opinion
    n_mut dist-only-revparse l preclassify.sh \
      '      _do_rc=0
      memo_has_path "$DIST" "$THEIRS" "core/fixtures/${_f}/.dist-only" || _do_rc=$?' \
      '      _do_rc=0
      git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${_f}/.dist-only" 2>/dev/null || _do_rc=$?
      if [ "$_do_rc" -eq 128 ]; then git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${_f}/.dist-only" >/dev/null 2>&1; [ "$?" -eq 1 ] || _do_rc=125; fi'
  fi
  chmod 755 "$NRO"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "preclassify-rename-row: PASS"
  exit 0
fi
echo "preclassify-rename-row: FAIL ($fails assertion(s))"
exit 1
