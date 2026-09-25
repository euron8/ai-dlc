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
  hash-object|rev-parse) [ "$sub" = "$FX_GIT_FAIL" ] && hit=1 ;;
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
  _anchor='    if [ "$_st" -eq 0 ]; then _ai_dlc_memo_commit "$_f" "$_t" "$_st"; else _ai_dlc_memo_serve "$_t"; fi'
  _hits="$(grep -cxF "$_anchor" "$RECON/lib.sh")" || _hits=0
  _ctl="$(grep -cxF 'ZZ-NO-SUCH-MEMO-ANCHOR-ZZ' "$RECON/lib.sh")" || _ctl=0
  B230_A="$_anchor" awk '$0 == ENVIRON["B230_A"] { print "    _ai_dlc_memo_commit \"$_f\" \"$_t\" \"$_st\""; next } { print }' \
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
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "preclassify-rename-row: PASS"
  exit 0
fi
echo "preclassify-rename-row: FAIL ($fails assertion(s))"
exit 1
