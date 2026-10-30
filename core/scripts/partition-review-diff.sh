#!/usr/bin/env bash
# partition-review-diff.sh -- the ONE speller of the part set of a gate-1 code review and of a
# gate-2 QA validation.
#
# USAGE
#   partition-review-diff.sh --map <worktree> <base> <frozen-sha>
#                            [--min-files N] [--max-parts K] [--shard-dir <dir>]
#                            [--exclude-captures <file>]
#       stdout: one line per part, `<ordinal>\t<groups>\t<file>\t<file>...`, exit 0.
#       <groups> is the part's group keys joined by `,`; every file after it is one TAB-separated
#       column. A diff that does not partition prints ONE line `SERIAL: <reason>` on STDOUT and
#       exits 3. SERIAL is an answer, not an error: the lead dispatches one reviewer at gate 1,
#       or one QA at gate 2, `shard: 1/1 <story-index>`. Gate 2 runs its own partition on the
#       go-signal sha into its own shard directory (`<idx>-qa-validation-<sha12>[-p<M>]`); it
#       never reuses gate 1's manifest.
#       With --shard-dir, a partitioned run ALSO writes `<dir>/.manifest` (creating <dir>), the
#       record merge-review-shards.sh re-derives the map from. SERIAL writes nothing.
#       --exclude-captures <file> names the story's cited captures, one toplevel-relative path per
#       line (`validate-handoff-evidence.sh --list-captures` writes it). They leave the THRESHOLD
#       COUNT only (THRESHOLD below); the part set, the map and the manifest are byte-identical
#       with and without the flag. An unreadable <file> is REFUSED.
#
#   Every refusal is exit 2 with ONE stderr line `partition-review-diff: REFUSED — <reason>`,
#   and a refusal writes nothing.
#
#   partition-review-diff.sh --route <worktree> <pass M-1 review file> <frozen-sha>
#                            [--exclude-captures <file>]
#       THE RECORD-ONLY ROUTE of a gate-1 re-review (implementation.md, the re-review paragraph).
#       stdout ONE line. `ROUTE: <reason>`, exit 0, ONLY when BOTH hold:
#         (a) the prior's Critical/Important findings number at least one and every one's class,
#             read by the sibling `validate-carried-findings.sh --classes <pass M-1 file>`, is in
#             ROUTE_CLASSES (EVIDENCE, BOOKKEEPING: code-reviewer.md's template owns the set);
#         (b) the delta <prior reviewed-sha>..<frozen-sha> carries no CODE path (THE CODE CLASS).
#       Every other outcome is `FULL: <reason>`, exit 1, and the pass is a full re-review: zero
#       findings, a finding with no Class line (old-engine findings carry none), an unknown or
#       repeated Class, any finding outside ROUTE_CLASSES, a prior carrying a column-0
#       `handover-run:` line outside fences whose result is not `RED` (`GREEN-SURVIVED`,
#       `NO-BASELINE`, anything else: a failed hard-gate replay), a classes read that failed, a prior with
#       no single full `reviewed-sha:` value, a sha that names no commit or is not an ancestor of
#       <frozen-sha>, an empty or unreadable delta, an unreadable captures file, a bad argument.
#       This mode never exits 2: no refusal in it can read as anything but FULL. WHY (b) EXISTS:
#       classes alone route a pass whose rework edited a test (graph s317 2-6 p3: every prior
#       finding bookkeeping, its rework deleted an assertion, p4 caught two code findings). The
#       delta guard is the safety property; the classes are the saving.
#
#   partition-review-diff.sh --gate1-rerun <worktree> <base> <frozen-sha> [--exclude-captures <file>]
#       RULE A: whether gate 1 re-runs after a QA rework. <base>..<frozen-sha> is the rework range
#       (the go-signal sha QA validated, then the new frozen sha). stdout ONE line:
#       `GATE1-RERUN: <reason>` when the range ADDS a test file (THE TEST NAME, the part set's
#       step 3 grammar) or changes a CODE path on a line that is not blank, not a comment and
#       not a docstring (THE LINE FILTER), else `GATE1-SKIP: <reason>`; exit 0 for both. Any
#       other exit (2 on a refusal) means re-run: the step text keys on `GATE1-SKIP` alone.
#
#   THE CODE CLASS (both modes). A path in the range is CODE unless it is under a scan root (as
#   above), ends in `.md`, ends in `.txt`/`.log`/`.out` with no path component that is a test
#   directory (`test`, `tests`, `__tests__`, `spec`, `specs`, `e2e`, `fixtures`), or is a
#   `.txt`/`.log`/`.out` path --exclude-captures names. So captures and records never count, and a
#   golden `.txt` under a test directory does. A code-extension file stays CODE wherever it sits and
#   whether or not the story cites it: graph s318 2-3's story cites `test-results/red_splat_copy.py`,
#   and the route sends that pass to a full re-review (fail closed).
#   THE LINE FILTER (--gate1-rerun). Changed line numbers come from `git diff -U0`; each side's
#   blob is classified line by line, by extension: Python (`.py`) `#` lines, and a triple-quoted
#   string that OPENS a statement (a docstring; `x = """..."""` is code); C-family and JS/TS
#   (`.js .jsx .ts .tsx .mjs .cjs .sol .go .rs .java .kt .swift .c .h .cc .cpp .css .scss`)
#   `//` lines and `/* ... */` blocks; shell, YAML, TOML, Ruby (`.sh .bash .yml .yaml .toml .rb`)
#   `#` lines. Every other extension drops blank lines only. A binary row counts as a change.
#
# INPUTS. <worktree> is the frozen dev worktree (any directory git resolves a work tree from).
#   <base> is any commit-ish and is recorded resolved; it must be an ANCESTOR of <frozen-sha>
#   (`git merge-base --is-ancestor`), else REFUSED -- against a diverged base the two-dot range
#   reviews the base side's commits as the story's. <frozen-sha> must be a FULL hex object
#   name (40, or 64 under sha256) naming a commit: the freeze is pinned to an immutable name,
#   never to `HEAD` or an abbreviation that may stop being unique. The program only READS the
#   repository -- `git rev-parse` and `git diff`, nothing that moves a ref or the index.
#
# THRESHOLD, ON BY DEFAULT. `--min-files N` wins; otherwise `AI_DLC_REVIEW_SHARD_MIN_FILES`;
#   with neither set, N is the built-in default 8 (`REVIEW_SHARD_DEFAULT_MIN_FILES` below, the
#   one place the number lives), and a SERIAL line names it as the default. N = 0 turns review
#   sharding OFF: `AI_DLC_REVIEW_SHARD_MIN_FILES=0` or `--min-files 0` answers SERIAL saying so.
#   Any other value that is not a non-negative integer is REFUSED -- including a variable that
#   is SET BUT EMPTY, which is not "unset": the refusal routes the lead to one `shard: 1/1`
#   reviewer with the refusal line in the story's gate log, which is safe and visible there,
#   where reading empty as unset would silently shard. 8 sits at the median reviewable file
#   count of the reference consumer's gate-1 ranges, so about half of them shard; the figures
#   are in the CHANGELOG entry that made sharding the default. `--max-parts K` (default 4) must be an integer from
#   2 to 64. Either value longer than 9 digits is REFUSED before any arithmetic, which would
#   otherwise wrap it.
#   THE COUNTED FILES. The count held to N is the reviewable files (after PART SET step 2); under
#   --exclude-captures, minus those of them the list names -- the INTERSECTION, so a listed path
#   outside the diff or under a scan root subtracts nothing. The SERIAL line then carries
#   `, <c> cited capture(s) not counted`, and a counted file count of at most 1 is SERIAL whatever
#   N is (a one-file review is never sharded). Without the flag nothing here changes.
#
# THE PART SET -- nothing else in core may restate it; callers read `--map`.
#   1. FILES. `git -C <worktree> diff --numstat --no-renames <base>..<frozen-sha>` -- TWO dots,
#      the tree of <base> against the tree of the frozen sha, the range implementation.md's
#      pre-gate commit-presence check names. A rename is its delete plus its add. A path git
#      QUOTES (it carries a tab, newline, quote or backslash) is REFUSED, never parsed.
#      Weight = added + deleted lines; a binary row (`-`) and every file count at least 1.
#   2. EXCLUSION. Every path under a root `artifact-path-config.sh --scan-roots --root
#      <worktree>` prints is dropped: those are the pipeline's own artifacts (reviews, story
#      files, reports), not the code under review. That program failing is a refusal -- an
#      unexcluded diff is a different part set that would read exactly like this one.
#   3. TEST PAIRING, where derivable. A file is a TEST when its basename is `test_<stem>.<ext>`,
#      `<stem>_test.<ext>`, or `<stem>.test.<ext>` / `<stem>.spec.<ext>`. It joins the ONE
#      non-test file in the diff whose basename minus its last extension is <stem> and whose
#      first path component is the test's. Zero such files, or two, is not derivable: the test
#      stays an atom of its own.
#   4. GROUPS, ADAPTIVE DEPTH. Every atom starts in the group of its first path component
#      (`web/`); a file at the root is in `*`. While some group weighs over 1/K of the total
#      and can split, it splits: a directory group `d/` by its next component -- its
#      subdirectories become `d/<sub>/`, its own files `d/*` -- and a `d/*` group of two or
#      more atoms into one group per atom (the key is the file's path). An atom is a leaf.
#   5. PACKING. Groups in order of weight descending, key ascending, each into the lightest of K
#      bins (lowest ordinal on a tie). Empty bins are dropped. Within a part, keys and files are
#      sorted. Ordinals are 1-based, zero-padded to the width of the part count.
#   Cited captures (--exclude-captures) are NOT dropped from steps 3-5: they stay atoms, grouped
#   and packed like any other file; only the THRESHOLD count leaves them out.
#   SERIAL when: the threshold is 0 (sharding off); fewer counted files (THRESHOLD) than N; at most
#   one counted file under --exclude-captures; fewer than two groups.
#
# THE MANIFEST (`<dir>/.manifest` -- a dotfile, so no `*.md` glob over the shard dir sees it)
#   worktree\t<ABSOLUTE physical path>
#   base\t<full sha>
#   sha\t<full frozen sha>
#   min-files\t<effective N>
#   max-parts\t<effective K>
#   part\t<one --map line>                          one per part, in order
#   An existing manifest byte-identical to this run's is left alone; one that differs REFUSES.
#
# Portability: bash 3.2, BSD awk, LC_ALL=C so every sort and comparison is bytewise.
set -u

refuse() { printf 'partition-review-diff: REFUSED — %s\n' "$*" >&2; exit 2; }

lang_of() {
  case "$1" in
    *.py) echo py ;;
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.sol|*.go|*.rs|*.java|*.kt|*.swift|*.c|*.h|*.cc|*.cpp|*.css|*.scss) echo c ;;
    *.sh|*.bash|*.yml|*.yaml|*.toml|*.rb) echo hash ;;
    *) echo plain ;;
  esac
}

# mode_setup <worktree> -> WT_ABS, T, the roots file at $T/roots; returns 1 with MS_WHY on any failure.
mode_setup() {
  MS_WHY=""
  [ -d "$1" ] || { MS_WHY="no worktree directory at $1"; return 1; }
  WT_ABS="$(cd "$1" 2>/dev/null && pwd -P)" || { MS_WHY="cannot enter $1"; return 1; }
  git -C "$WT_ABS" rev-parse --git-dir >/dev/null 2>&1 || { MS_WHY="$WT_ABS is not inside a git repository"; return 1; }
  T="$(mktemp -d "${TMPDIR:-/tmp}/partition-review-diff.XXXXXX")" || { MS_WHY="mktemp failed"; return 1; }
  trap 'rm -rf "$T"' EXIT
  CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/artifact-path-config.sh"
  [ -f "$CFG" ] || { MS_WHY="$CFG is absent, so the scan roots cannot be read"; return 1; }
  bash "$CFG" --scan-roots --root "$WT_ABS" > "$T/roots" 2>/dev/null && grep -q . "$T/roots" \
    || { MS_WHY="artifact-path-config.sh --scan-roots --root $WT_ABS printed no scan root"; return 1; }
  return 0
}

full_sha_ok() { case "$1" in *[!0-9a-f]*|"") return 1 ;; esac; [ "${#1}" -eq 40 ] || [ "${#1}" -eq 64 ]; }

route_mode() {
  full() { printf 'FULL: %s\n' "$*"; exit 1; }
  [ "$#" -eq 3 ] || [ "$#" -eq 5 ] || full "usage: partition-review-diff.sh --route <worktree> <pass M-1 review file> <frozen-sha> [--exclude-captures <file>]"
  RW="$1"; RP="$2"; RS="$3"; RX=""
  if [ "$#" -eq 5 ]; then
    [ "$4" = --exclude-captures ] || full "unknown argument $4"
    RX="$5"; [ -f "$RX" ] && [ -r "$RX" ] || full "--exclude-captures file $RX is not a readable file"
  fi
  [ -f "$RP" ] && [ -r "$RP" ] || full "prior review $RP is not a readable file"
  mode_setup "$RW" || full "$MS_WHY"
  full_sha_ok "$RS" || full "frozen sha '$RS' is not a full lowercase hex object name"
  RS_FULL="$(git -C "$WT_ABS" rev-parse --verify --quiet "${RS}^{commit}")" || full "frozen sha $RS names no commit in $WT_ABS"
  # (a) the classes, through the sibling's own reader of the prior's findings.
  VCF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-carried-findings.sh"
  [ -f "$VCF" ] || full "$VCF is absent, so the prior's classes cannot be read"
  bash "$VCF" --classes "$RP" > "$T/classes" 2> "$T/classes.err" || full "validate-carried-findings.sh --classes $RP exited non-zero: $(head -1 "$T/classes.err")"
  nfind="$(grep -c . "$T/classes")" || nfind=0
  [ "$nfind" -ge 1 ] || full "$RP carries no Critical or Important finding; a re-review with nothing to route is a full review"
  TABC="$(printf '\t')"
  while IFS="$TABC" read -r rc_ rd_; do
    case " $ROUTE_CLASSES " in
      *" $rc_ "*) ;;
      *) case "$rc_" in
           -) full "the prior finding '$rd_' carries no Class line" ;;
           *) full "the prior finding '$rd_' is Class $rc_, not one of $ROUTE_CLASSES" ;;
         esac ;;
    esac
  done < "$T/classes"
  # A replay that did not go RED is a failed hard gate, whatever the findings' classes.
  hrun="$(awk '
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { f = 0; next }
    !f && /^[ \t]*(```|~~~)/ { f = 1; next }
    f { next }
    /^handover-run:/ { v = $0; sub(/[ \t\r]+$/, "", v); n = split(v, a, /[ \t]+/); if (n < 4 || a[4] != "RED") { print v; exit } }' "$RP")"
  [ -z "$hrun" ] || full "$RP carries '$hrun', a hand-over replay whose result is not RED; a failed replay is re-validated in full"
  # (b) the delta guard.
  shas="$(awk '
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { f = 0; next }
    !f && /^[ \t]*(```|~~~)/ { f = 1; next }
    f { next }
    /^reviewed-sha:/ { v = $0; sub(/^reviewed-sha:[ \t]*/, "", v); gsub(/[`\r \t]/, "", v); print v }' "$RP" | LC_ALL=C sort -u)"
  nsha="$(printf '%s\n' "$shas" | grep -c .)" || nsha=0
  [ "$nsha" -eq 1 ] || full "$RP carries $nsha distinct reviewed-sha value(s) outside a fence; the delta needs exactly one"
  case "$shas" in *[!0-9a-f]*) full "the prior reviewed-sha '$shas' is not a hex object name" ;; esac
  [ "${#shas}" -ge 7 ] || full "the prior reviewed-sha '$shas' is too short to resolve"
  PS_FULL="$(git -C "$WT_ABS" rev-parse --verify --quiet "${shas}^{commit}")" || full "the prior reviewed-sha $shas names no commit in $WT_ABS"
  git -C "$WT_ABS" merge-base --is-ancestor "$PS_FULL" "$RS_FULL" || full "the prior reviewed-sha $PS_FULL is not an ancestor of $RS_FULL (a rebase or force-push); the delta is not this rework"
  git -C "$WT_ABS" -c core.quotePath=false diff --name-status --no-renames --no-textconv --no-ext-diff \
    "${PS_FULL}..${RS_FULL}" > "$T/delta" 2>/dev/null || full "git diff ${PS_FULL}..${RS_FULL} failed in $WT_ABS"
  grep -q . "$T/delta" || full "the delta ${PS_FULL}..${RS_FULL} is empty; nothing reworked is nothing to route"
  : > "$T/xcap"; [ -z "$RX" ] || cp "$RX" "$T/xcap" || full "cannot read $RX"
  awk -F'\t' "$CODE_CLASS_AWK" "$T/roots" "$T/xcap" "$T/delta" > "$T/code" || full "classifying the delta failed"
  ncode="$(grep -c . "$T/code")" || ncode=0
  [ "$ncode" -eq 0 ] || full "the delta ${PS_FULL:0:12}..${RS_FULL:0:12} changes $ncode code path(s), first $(awk -F'\t' 'NR == 1 { print $2 }' "$T/code"); a rework that edits code or tests is re-reviewed in full whatever the findings' classes"
  printf 'ROUTE: %s Critical/Important finding(s), every one %s; the delta %s..%s (%s path(s)) carries no code path\n' \
    "$nfind" "$(printf '%s' "$ROUTE_CLASSES" | sed 's/ /|/g')" "${PS_FULL:0:12}" "${RS_FULL:0:12}" "$(grep -c . "$T/delta")"
  exit 0
}

# ---- --gate1-rerun (header: RULE A) -----------------------------------------------------------------
gate1_rerun_mode() {
  GW=""; GB=""; GS=""; GX=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --exclude-captures) [ "$#" -ge 2 ] || refuse "--exclude-captures needs a file"; GX="$2"; shift 2 ;;
      --*) refuse "unknown flag $1" ;;
      *) if [ -z "$GW" ]; then GW="$1"; elif [ -z "$GB" ]; then GB="$1"; elif [ -z "$GS" ]; then GS="$1"; else refuse "unexpected argument $1"; fi; shift ;;
    esac
  done
  [ -n "$GS" ] || refuse "usage: partition-review-diff.sh --gate1-rerun <worktree> <base> <frozen-sha> [--exclude-captures <file>]"
  [ -z "$GX" ] || { [ -f "$GX" ] && [ -r "$GX" ]; } || refuse "--exclude-captures file $GX is not a readable file"
  mode_setup "$GW" || refuse "$MS_WHY"
  full_sha_ok "$GS" || refuse "frozen sha '$GS' is not a full lowercase hex object name"
  GS_FULL="$(git -C "$WT_ABS" rev-parse --verify --quiet "${GS}^{commit}")" || refuse "frozen sha $GS names no commit in $WT_ABS"
  GB_FULL="$(git -C "$WT_ABS" rev-parse --verify --quiet "${GB}^{commit}")" || refuse "base '$GB' names no commit in $WT_ABS"
  git -C "$WT_ABS" merge-base --is-ancestor "$GB_FULL" "$GS_FULL" || refuse "base $GB_FULL is not an ancestor of $GS_FULL"
  git -C "$WT_ABS" -c core.quotePath=false diff --name-status --no-renames --no-textconv --no-ext-diff \
    "${GB_FULL}..${GS_FULL}" > "$T/delta" 2>/dev/null || refuse "git diff ${GB_FULL}..${GS_FULL} failed in $WT_ABS"
  : > "$T/xcap"; [ -z "$GX" ] || cp "$GX" "$T/xcap" || refuse "cannot read $GX"
  awk -F'\t' "$CODE_CLASS_AWK" "$T/roots" "$T/xcap" "$T/delta" > "$T/code" || refuse "classifying the range failed"
  added="$(awk -F'\t' "$TEST_NAME_AWK"' $1 == "A" && is_test_name($2) { print $2; exit }' "$T/code")"
  if [ -n "$added" ]; then
    printf 'GATE1-RERUN: the range %s..%s adds the test file %s\n' "${GB_FULL:0:12}" "${GS_FULL:0:12}" "$added"; exit 0
  fi
  exec_n=0; first=""
  while IFS="$(printf '\t')" read -r st p; do
    [ -n "$p" ] || continue
    git -C "$WT_ABS" diff -U0 --no-renames --no-textconv --no-ext-diff "${GB_FULL}..${GS_FULL}" -- "$p" > "$T/hunks" 2>/dev/null \
      || refuse "git diff -U0 of $p failed"
    if grep -q '^Binary files ' "$T/hunks"; then exec_n=$((exec_n + 1)); first="${first:-$p}"; continue; fi
    awk '/^@@ / { split($2, o, ","); split($3, n, ","); os = substr(o[1], 2) + 0; oc = (o[2] == "" ? 1 : o[2] + 0)
                  ns = substr(n[1], 2) + 0; nc = (n[2] == "" ? 1 : n[2] + 0)
                  for (i = 0; i < oc; i++) print "O\t" os + i; for (i = 0; i < nc; i++) print "N\t" ns + i }' "$T/hunks" > "$T/changed"
    lang="$(lang_of "$p")"
    : > "$T/codelines"
    if [ "$st" != A ]; then git -C "$WT_ABS" show "${GB_FULL}:$p" 2>/dev/null | PR_LANG="$lang" awk "$LINE_CODE_AWK" | awk '{ printf "O\t%s\n", $0 }' >> "$T/codelines"; fi
    if [ "$st" != D ]; then git -C "$WT_ABS" show "${GS_FULL}:$p" 2>/dev/null | PR_LANG="$lang" awk "$LINE_CODE_AWK" | awk '{ printf "N\t%s\n", $0 }' >> "$T/codelines"; fi
    k="$(awk 'FNR == NR { C[$0] = 1; next } ($0 in C) { n++ } END { print n + 0 }' "$T/codelines" "$T/changed")"
    if [ "$k" -gt 0 ]; then exec_n=$((exec_n + k)); first="${first:-$p}"; fi
  done < "$T/code"
  ncode="$(grep -c . "$T/code")" || ncode=0
  if [ "$exec_n" -gt 0 ]; then
    printf 'GATE1-RERUN: the range %s..%s changes %s non-blank, non-comment, non-docstring line(s) in code or test paths, first %s\n' \
      "${GB_FULL:0:12}" "${GS_FULL:0:12}" "$exec_n" "$first"; exit 0
  fi
  printf 'GATE1-SKIP: the range %s..%s adds no test file and changes no code or test line outside blanks, comments and docstrings (%s code path(s) read, %s path(s) in the range)\n' \
    "${GB_FULL:0:12}" "${GS_FULL:0:12}" "$ncode" "$(grep -c . "$T/delta")"
  exit 0
}

prd_main() {
export LC_ALL=C

USAGE="usage: partition-review-diff.sh --map <worktree> <base> <frozen-sha> [--min-files N] [--max-parts K] [--shard-dir <dir>] [--exclude-captures <file>] | --route <worktree> <prior-review-file> <frozen-sha> [--exclude-captures <file>] | --gate1-rerun <worktree> <base> <frozen-sha> [--exclude-captures <file>]"

# ---- shared by --route and --gate1-rerun (header: THE CODE CLASS, THE LINE FILTER) -----------------
# THE TEST NAME: the three basename expressions of THE PART SET step 3, the one test grammar here.
TEST_NAME_AWK='function is_test_name(p,   b) { b = p; sub(/.*\//, "", b); return (b ~ /^test_.+\.[^.]+$/ || b ~ /.+_test\.[^.]+$/ || b ~ /.+\.(test|spec)\.[^.]+$/) }'
# code_paths <roots file> <captures file or empty> < `<status>\t<path>` rows -> the CODE rows, unchanged.
CODE_CLASS_AWK='
  FILENAME == ARGV[1] { if ($0 != "") { sub(/\/+$/, ""); R[++nr] = $0 }; next }
  FILENAME == ARGV[2] { sub(/\r$/, ""); if ($0 != "") X[$0] = 1; next }
  {
    p = $2; if (p == "") next
    for (i = 1; i <= nr; i++) if (p == R[i] || index(p, R[i] "/") == 1) next
    if ((p in X) && p ~ /\.(txt|log|out)$/) next
    if (p ~ /\.md$/) next
    if (p ~ /\.(txt|log|out)$/) {
      n = split(p, c, "/"); td = 0
      for (i = 1; i < n; i++) if (c[i] ~ /^(test|tests|__tests__|spec|specs|e2e|fixtures)$/) td = 1
      if (!td) next
    }
    print
  }'
# The per-language classifier: prints the line numbers of a blob that are CODE (not blank, not a
# comment, not a docstring). LANG is py, c, hash or plain. No apostrophe anywhere in this program.
LINE_CODE_AWK='
  BEGIN { L = ENVIRON["PR_LANG"]; Q3D = sprintf("%c%c%c", 34, 34, 34); Q3S = sprintf("%c%c%c", 39, 39, 39) }
  function cnt(s, d,   n, i) { n = 0; while ((i = index(s, d)) > 0) { n++; s = substr(s, i + 3) }; return n }
  {
    t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t)
    if (L == "py") {
      if (ds != "") { if (index(t, ds) > 0) { if (dk == "code") { print NR; lc = substr(t, length(t)) }; ds = ""; dk = "" } else if (dk == "code") print NR; next }
      if (t == "" || substr(t, 1, 1) == "#") next
      u = t; sub(/^[rRuUbBfF]{1,2}/, "", u)
      # A DOCSTRING opens a statement: the previous code line does not leave an expression open.
      if ((substr(u, 1, 3) == Q3D || substr(u, 1, 3) == Q3S) && lc !~ /[([{,=+%*\\-]/) {
        d = substr(u, 1, 3); if (cnt(u, d) < 2) { ds = d; dk = "doc" }; next
      }
      print NR; lc = substr(t, length(t))
      if (cnt(t, Q3D) % 2 == 1) { ds = Q3D; dk = "code" } else if (cnt(t, Q3S) % 2 == 1) { ds = Q3S; dk = "code" }
      next
    }
    if (L == "c") {
      if (bc) { if (index(t, "*/") > 0) bc = 0; next }
      if (t == "" || substr(t, 1, 2) == "//") next
      if (substr(t, 1, 2) == "/*") { r = substr(t, 3); if (index(r, "*/") == 0) bc = 1; next }
      print NR; next
    }
    if (L == "hash") { if (t == "" || substr(t, 1, 1) == "#") next; print NR; next }
    if (t != "") print NR
  }'

# ---- --route (header: THE RECORD-ONLY ROUTE) --------------------------------------------------------
# The classes that route. A subset of code-reviewer.md's template set (I129 binds the two).
ROUTE_CLASSES="EVIDENCE BOOKKEEPING"


case "${1:-}" in
  -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
  --map) shift ;;
  --route) shift; route_mode "$@" ;;
  --gate1-rerun) shift; gate1_rerun_mode "$@" ;;
  *) refuse "$USAGE" ;;
esac

WT=""; BASE=""; SHA=""; MINF=""; MAXP=""; SDIR=""; MINF_SET=0; XCAP=""; XCAP_SET=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --min-files) [ "$#" -ge 2 ] || refuse "--min-files needs a value"; MINF="$2"; MINF_SET=1; shift 2 ;;
    --max-parts) [ "$#" -ge 2 ] || refuse "--max-parts needs a value"; MAXP="$2"; shift 2 ;;
    --shard-dir) [ "$#" -ge 2 ] || refuse "--shard-dir needs a value"; SDIR="$2"; shift 2 ;;
    --exclude-captures) [ "$#" -ge 2 ] || refuse "--exclude-captures needs a file"; XCAP="$2"; XCAP_SET=1; shift 2 ;;
    --*) refuse "unknown flag $1" ;;
    *) if [ -z "$WT" ]; then WT="$1"; elif [ -z "$BASE" ]; then BASE="$1"
       elif [ -z "$SHA" ]; then SHA="$1"; else refuse "unexpected argument $1"; fi; shift ;;
  esac
done
[ -n "$WT" ] && [ -n "$BASE" ] && [ -n "$SHA" ] || refuse "$USAGE"
if [ "$XCAP_SET" -eq 1 ]; then
  [ -f "$XCAP" ] && [ -r "$XCAP" ] || refuse "--exclude-captures file $XCAP is not a readable file; an unread list would exclude nothing and read exactly like one that matched nothing"
fi

REVIEW_SHARD_DEFAULT_MIN_FILES=8
if [ "$MINF_SET" -eq 1 ]; then
  MINF_SRC="--min-files"
elif [ -n "${AI_DLC_REVIEW_SHARD_MIN_FILES+set}" ]; then
  MINF="${AI_DLC_REVIEW_SHARD_MIN_FILES:-}"; MINF_SRC="AI_DLC_REVIEW_SHARD_MIN_FILES"
else
  MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"
  MINF_SRC="the built-in default; AI_DLC_REVIEW_SHARD_MIN_FILES overrides it, 0 turns sharding off"
fi
case "$MINF" in ""|*[!0-9]*) refuse "$MINF_SRC '$MINF' is not a non-negative integer (0 turns review sharding off)" ;; esac
case "$MINF" in ??????????*) refuse "$MINF_SRC '$MINF' is longer than 9 digits; shell arithmetic would wrap it" ;; esac
MINF=$((10#$MINF))
[ -n "$MAXP" ] || MAXP=4
case "$MAXP" in ""|*[!0-9]*) refuse "--max-parts '$MAXP' is not an integer" ;; esac
case "$MAXP" in ??????????*) refuse "--max-parts '$MAXP' is longer than 9 digits; shell arithmetic would wrap it" ;; esac
MAXP=$((10#$MAXP))
[ "$MAXP" -ge 2 ] || refuse "--max-parts $MAXP is below 2; a one-part review is SERIAL, not a partition"
# A CEILING, NOT ONLY A WRAP GUARD. The packer below loops to K, so a 9-digit K passes the cap
# above and then spins instead of refusing. 64 is far past any reviewer fan-out.
[ "$MAXP" -le 64 ] || refuse "--max-parts $MAXP is above 64; the packer loops to K"

[ -d "$WT" ] || refuse "no worktree directory at $WT"
WT_ABS="$(cd "$WT" 2>/dev/null && pwd -P)" || refuse "cannot enter $WT"
git -C "$WT_ABS" rev-parse --git-dir >/dev/null 2>&1 || refuse "$WT_ABS is not inside a git repository"

case "$SHA" in
  *[!0-9a-f]*) refuse "frozen sha '$SHA' is not a full lowercase hex object name" ;;
esac
[ "${#SHA}" -eq 40 ] || [ "${#SHA}" -eq 64 ] \
  || refuse "frozen sha '$SHA' is ${#SHA} characters; the freeze is pinned to a FULL object name (40 or 64)"
SHA_FULL="$(git -C "$WT_ABS" rev-parse --verify --quiet "${SHA}^{commit}")" \
  || refuse "frozen sha $SHA names no commit in $WT_ABS"
[ "$SHA_FULL" = "$SHA" ] || refuse "frozen sha $SHA resolves to $SHA_FULL; pass the commit object name itself"
BASE_FULL="$(git -C "$WT_ABS" rev-parse --verify --quiet "${BASE}^{commit}")" \
  || refuse "base '$BASE' names no commit in $WT_ABS"
git -C "$WT_ABS" merge-base --is-ancestor "$BASE_FULL" "$SHA_FULL" \
  || refuse "base $BASE_FULL is not an ancestor of the frozen sha $SHA_FULL; the two-dot range would charge the story with every commit on the base's side (pass the merge base)"

T="$(mktemp -d "${TMPDIR:-/tmp}/partition-review-diff.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT

# The exclusion roots. The sibling resolves the grammar inside <worktree>; its failure is ours.
CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/artifact-path-config.sh"
[ -f "$CFG" ] || refuse "cannot read the scan roots: $CFG is absent"
bash "$CFG" --scan-roots --root "$WT_ABS" > "$T/roots" 2> "$T/roots.err" \
  || refuse "artifact-path-config.sh --scan-roots --root $WT_ABS failed: $(head -1 "$T/roots.err")"
grep -q . "$T/roots" || refuse "artifact-path-config.sh printed no scan root for $WT_ABS"

git -C "$WT_ABS" -c core.quotePath=false diff --numstat --no-renames --no-textconv --no-ext-diff \
  "${BASE_FULL}..${SHA_FULL}" > "$T/numstat" 2> "$T/numstat.err" \
  || refuse "git diff --numstat ${BASE_FULL}..${SHA_FULL} failed in $WT_ABS: $(head -1 "$T/numstat.err")"
if awk -F'\t' '$3 ~ /^"/ { bad = 1 } END { exit !bad }' "$T/numstat"; then
  refuse "the diff names a path git had to quote ($(awk -F'\t' '$3 ~ /^"/ { print $3; exit }' "$T/numstat")); a quoted path is never parsed"
fi

# Reviewable files: `<weight>\t<path>`, scan roots excluded. awk reads the roots file first.
awk -F'\t' '
  FNR == NR { if ($0 != "") { sub(/\/+$/, ""); R[++nr] = $0 }; next }
  {
    p = $3; if (p == "") next
    for (i = 1; i <= nr; i++) if (p == R[i] || index(p, R[i] "/") == 1) next
    w = ($1 ~ /^[0-9]+$/ ? $1 : 0) + ($2 ~ /^[0-9]+$/ ? $2 : 0)
    if (w < 1) w = 1
    printf "%d\t%s\n", w, p
  }' "$T/roots" "$T/numstat" > "$T/files" || refuse "cannot stage the reviewable file list"
NF_REV="$(grep -c . "$T/files")" || NF_REV=0
NF_ALL="$(grep -c . "$T/numstat")" || NF_ALL=0

# --exclude-captures: cited captures leave the COUNT, never the file set. The excluded count is
# the INTERSECTION of the list with the reviewable files above (scan roots already dropped), never
# NF_REV minus the list's length: a listed path outside the diff or under a scan root excludes
# nothing. NEVER touch $T/files here: merge-review-shards.sh re-derives the map with a FLAGLESS
# re-run (its `bash "$PART"` call) and cmp's it against the manifest's part lines, so the map must
# be identical with and without this flag. The flag changes WHETHER a diff partitions, not WHAT.
XC=0
if [ "$XCAP_SET" -eq 1 ]; then
  XC="$(awk -F'\t' 'FNR == NR { sub(/\r$/, ""); if ($0 != "") L[$0] = 1; next } ($2 in L) { c++ } END { print c + 0 }' \
    "$XCAP" "$T/files")" || refuse "cannot read --exclude-captures file $XCAP"
  NF_REV=$((NF_REV - XC))
fi

if [ "$MINF" -eq 0 ]; then
  echo "SERIAL: review sharding is disabled -- $MINF_SRC is 0"; exit 3
fi
if [ "$XCAP_SET" -eq 1 ]; then
  # C8: a review whose counted (non-capture) files number at most one is never sharded, whatever N.
  if [ "$NF_REV" -le 1 ]; then
    echo "SERIAL: $NF_REV reviewable file(s) ($NF_ALL in the diff, scan roots excluded, $XC cited capture(s) not counted); a review of at most one counted file is never sharded, whatever the threshold"
    exit 3
  fi
  if [ "$NF_REV" -lt "$MINF" ]; then
    echo "SERIAL: $NF_REV reviewable file(s) ($NF_ALL in the diff, scan roots excluded, $XC cited capture(s) not counted), below the threshold of $MINF ($MINF_SRC)"
    exit 3
  fi
elif [ "$NF_REV" -lt "$MINF" ]; then
  echo "SERIAL: $NF_REV reviewable file(s) ($NF_ALL in the diff, scan roots excluded), below the threshold of $MINF ($MINF_SRC)"
  exit 3
fi

awk -F'\t' -v K="$MAXP" '
  function ncomp(p,   a) { return split(p, a, "/") }
  function prefix(p, d,   a, n, i, s) {
    n = split(p, a, "/"); s = a[1]
    for (i = 2; i <= d; i++) s = s "/" a[i]
    return s
  }
  function parent(p,   q) { q = p; if (sub(/\/[^\/]*$/, "", q)) return q; return "" }
  function base(p,   a, n) { n = split(p, a, "/"); return a[n] }
  function top(p,   a) { split(p, a, "/"); return a[1] }
  function keyof(i,   n) {
    if (LEAF[i]) return AP[i]
    n = ncomp(AP[i])
    if (n - 1 >= D[i]) return prefix(AP[i], D[i]) "/"
    return (parent(AP[i]) == "" ? "*" : parent(AP[i]) "/*")
  }
  { nf++; W[nf] = $1 + 0; P[nf] = $2; tot += $1 }
  END {
    # ---- test pairing ----
    for (i = 1; i <= nf; i++) {
      b = base(P[i]); s = ""
      if (b ~ /^test_.+\.[^.]+$/) { s = b; sub(/^test_/, "", s); sub(/\.[^.]+$/, "", s) }
      else if (b ~ /.+_test\.[^.]+$/) { s = b; sub(/\.[^.]+$/, "", s); sub(/_test$/, "", s) }
      else if (b ~ /.+\.(test|spec)\.[^.]+$/) { s = b; sub(/\.[^.]+$/, "", s); sub(/\.(test|spec)$/, "", s) }
      if (s != "") { IST[i] = 1; TS[i] = s }
      else { st = b; sub(/\.[^.]+$/, "", st); k = top(P[i]) SUBSEP st; SC[k]++; SF[k] = i }
    }
    na = 0
    for (i = 1; i <= nf; i++) if (!IST[i]) { na++; AP[na] = P[i]; AW[na] = W[i]; AM[na] = P[i]; AI[i] = na }
    for (i = 1; i <= nf; i++) if (IST[i]) {
      k = top(P[i]) SUBSEP TS[i]
      if (SC[k] == 1) { a = AI[SF[k]]; AW[a] += W[i]; AM[a] = AM[a] SUBSEP P[i] }
      else { na++; AP[na] = P[i]; AW[na] = W[i]; AM[na] = P[i] }
    }
    for (i = 1; i <= na; i++) { D[i] = 1; LEAF[i] = 0 }
    # ---- adaptive depth ----
    for (;;) {
      split("", GW); split("", GN)
      for (i = 1; i <= na; i++) { g = keyof(i); GW[g] += AW[i]; GN[g]++ }
      moved = 0
      for (g in GW) {
        if (GW[g] * K <= tot) continue
        if (g ~ /\/$/) { for (i = 1; i <= na; i++) if (keyof(i) == g) D[i]++; moved = 1 }
        else if ((g == "*" || g ~ /\/\*$/) && GN[g] >= 2) { for (i = 1; i <= na; i++) if (keyof(i) == g) LEAF[i] = 1; moved = 1 }
        if (moved) break
      }
      if (!moved) break
    }
    ng = 0
    for (g in GW) { ng++; GK[ng] = g }
    if (ng < 2) { printf "SERIAL: one group (%s); a review with one group has no independent parts\n", GK[1]; exit 3 }
    # ---- order groups: weight desc, key asc (insertion sort, bytewise) ----
    for (i = 2; i <= ng; i++) {
      x = GK[i]; j = i - 1
      while (j >= 1 && (GW[GK[j]] < GW[x] || (GW[GK[j]] == GW[x] && GK[j] > x))) { GK[j + 1] = GK[j]; j-- }
      GK[j + 1] = x
    }
    for (b = 1; b <= K; b++) BW[b] = 0
    for (i = 1; i <= ng; i++) {
      bi = 1; for (b = 2; b <= K; b++) if (BW[b] < BW[bi]) bi = b
      BW[bi] += GW[GK[i]]; BG[bi] = (BG[bi] == "" ? GK[i] : BG[bi] SUBSEP GK[i]); GB[GK[i]] = bi
    }
    np = 0
    for (b = 1; b <= K; b++) if (BW[b] > 0) { np++; PB[np] = b }
    if (np < 2) { print "SERIAL: one part after packing"; exit 3 }
    fmt = "%0" length(np "") "d"
    for (o = 1; o <= np; o++) {
      b = PB[o]
      n = split(BG[b], ks, SUBSEP)
      for (i = 2; i <= n; i++) { x = ks[i]; j = i - 1; while (j >= 1 && ks[j] > x) { ks[j + 1] = ks[j]; j-- }; ks[j + 1] = x }
      line = sprintf(fmt, o) "\t" ks[1]; for (i = 2; i <= n; i++) line = line "," ks[i]
      nfl = 0
      for (i = 1; i <= na; i++) if (GB[keyof(i)] == b) { m = split(AM[i], mm, SUBSEP); for (j = 1; j <= m; j++) FL[++nfl] = mm[j] }
      for (i = 2; i <= nfl; i++) { x = FL[i]; j = i - 1; while (j >= 1 && FL[j] > x) { FL[j + 1] = FL[j]; j-- }; FL[j + 1] = x }
      for (i = 1; i <= nfl; i++) line = line "\t" FL[i]
      print line
    }
  }' "$T/files" > "$T/map"
rc=$?
if [ "$rc" -eq 3 ]; then cat "$T/map"; exit 3; fi
[ "$rc" -eq 0 ] && grep -q . "$T/map" || refuse "the partition of ${BASE_FULL}..${SHA_FULL} failed (awk rc=$rc)"

if [ -n "$SDIR" ]; then
  {
    printf 'worktree\t%s\n' "$WT_ABS"
    printf 'base\t%s\n' "$BASE_FULL"
    printf 'sha\t%s\n' "$SHA_FULL"
    printf 'min-files\t%s\n' "$MINF"
    printf 'max-parts\t%s\n' "$MAXP"
    awk '{ print "part\t" $0 }' "$T/map"
  } > "$T/manifest" || refuse "cannot stage the manifest"
  if [ -e "$SDIR/.manifest" ]; then
    cmp -s "$T/manifest" "$SDIR/.manifest" \
      || refuse "$SDIR/.manifest already exists and differs from this partition; a manifest is never overwritten"
  else
    mkdir -p "$SDIR" || refuse "cannot create $SDIR"
    cp "$T/manifest" "$SDIR/.manifest.tmp.$$" && mv "$SDIR/.manifest.tmp.$$" "$SDIR/.manifest" \
      || { rm -f "$SDIR/.manifest.tmp.$$"; refuse "cannot write $SDIR/.manifest"; }
  fi
fi
cat "$T/map"
exit 0
}
# The program runs only when executed; sourced (a fixture asking a decision in process), it defines
# the functions above and prd_main, and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
prd_main "$@"
