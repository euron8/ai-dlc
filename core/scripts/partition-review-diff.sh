#!/usr/bin/env bash
# partition-review-diff.sh -- the ONE speller of the part set of a gate-1 code review and of a
# gate-2 QA validation.
#
# USAGE
#   partition-review-diff.sh --map <worktree> <base> <frozen-sha>
#                            [--min-files N] [--max-parts K] [--shard-dir <dir>]
#       stdout: one line per part, `<ordinal>\t<groups>\t<file>\t<file>...`, exit 0.
#       <groups> is the part's group keys joined by `,`; every file after it is one TAB-separated
#       column. A diff that does not partition prints ONE line `SERIAL: <reason>` on STDOUT and
#       exits 3. SERIAL is an answer, not an error: the lead dispatches one reviewer at gate 1,
#       or one QA at gate 2, `shard: 1/1 <story-index>`. Gate 2 runs its own partition on the
#       go-signal sha into its own shard directory (`<idx>-qa-validation-<sha12>[-p<M>]`); it
#       never reuses gate 1's manifest.
#       With --shard-dir, a partitioned run ALSO writes `<dir>/.manifest` (creating <dir>), the
#       record merge-review-shards.sh re-derives the map from. SERIAL writes nothing.
#
#   Every refusal is exit 2 with ONE stderr line `partition-review-diff: REFUSED — <reason>`,
#   and a refusal writes nothing.
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
#   SERIAL when: the threshold is 0 (sharding off); fewer reviewable files (after 2) than N; fewer than two groups.
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
export LC_ALL=C

refuse() { printf 'partition-review-diff: REFUSED — %s\n' "$*" >&2; exit 2; }
USAGE="usage: partition-review-diff.sh --map <worktree> <base> <frozen-sha> [--min-files N] [--max-parts K] [--shard-dir <dir>]"

case "${1:-}" in
  -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
  --map) shift ;;
  *) refuse "$USAGE" ;;
esac

WT=""; BASE=""; SHA=""; MINF=""; MAXP=""; SDIR=""; MINF_SET=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --min-files) [ "$#" -ge 2 ] || refuse "--min-files needs a value"; MINF="$2"; MINF_SET=1; shift 2 ;;
    --max-parts) [ "$#" -ge 2 ] || refuse "--max-parts needs a value"; MAXP="$2"; shift 2 ;;
    --shard-dir) [ "$#" -ge 2 ] || refuse "--shard-dir needs a value"; SDIR="$2"; shift 2 ;;
    --*) refuse "unknown flag $1" ;;
    *) if [ -z "$WT" ]; then WT="$1"; elif [ -z "$BASE" ]; then BASE="$1"
       elif [ -z "$SHA" ]; then SHA="$1"; else refuse "unexpected argument $1"; fi; shift ;;
  esac
done
[ -n "$WT" ] && [ -n "$BASE" ] && [ -n "$SHA" ] || refuse "$USAGE"

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
CFG="$(cd "$(dirname "$0")" && pwd)/artifact-path-config.sh"
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

if [ "$MINF" -eq 0 ]; then
  echo "SERIAL: review sharding is disabled -- $MINF_SRC is 0"; exit 3
fi
if [ "$NF_REV" -lt "$MINF" ]; then
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
