#!/usr/bin/env bash
# reconcile-region: exempt — the pull DRIVER (BL-1190). It calls emit-report.sh to render the region and apply.sh to act on it; it renders no finding of its own.
#
# reconcile/pull.sh — runs the deterministic part of an engine-update pull and hands the model only
# real decisions. The update skill (SKILL.md) calls it; the model keeps the auto-push preflight, the
# self-update branch, push, PR, merge and re-invoke, and the update PR's merge (`gh pr merge` is
# never run here). The driver pushes nothing and merges nothing.
#
# Usage:
#   pull.sh resolve <consumer> [<ref>]
#   pull.sh gate    <dist> <base> <consumer> <theirs>
#   pull.sh dry-run <dist> <base> <consumer> <theirs>
#   pull.sh apply   [--carried-machinery-slice] <dist> <base> <consumer> <theirs>
#   pull.sh finish  [--carried-machinery-slice] <dist> <base> <consumer> <theirs>
#   pull.sh merge   <dist> <base> <consumer> <theirs> <override>
#   pull.sh deliver [--whole <path>]... <dist> <base> <consumer> <theirs>
#   pull.sh record  <dist> <base> <consumer> <theirs> [-- <path>...]
#   pull.sh pr-body <consumer>
#   pull.sh cut-from <consumer> <branch>
#
# STDOUT, one item per line (every other line a subcommand prints is listed with it below):
#   RESOLVE dist=<path> base=<sha> theirs=<sha>        resolve, exit 0
#   GATE <OK|DEFER|UNDECIDED>                         gate, then its SAFE-STOP, CARRY, UNDECIDED and DEFER rows verbatim
#   PULL run=<dir> key=<12> renders=<n>               dry-run and apply, after the render; an empty key
#                                                     means no store was kept and every detector runs fresh
#   REFUSED <what> rc=<n>                             a step that refused (exit 2); for a detector named in
#                                                     the region's DETECTOR-REFUSED line it is a report only,
#                                                     and the union gate decides on that line as it always has
#   ASK <kind> <path> <digest> <one-line question>    an ASK family (reconcile/ask-families.tsv) only
#   DECIDE <kind> <path> <verdict>                    a MODEL or SCRIPT decision row
#   WORK classify <path>                              a CLASSIFY file the classify agent must take
#   HARD <row>                                        a HARD-* blocker row the model resolves (SKILL.md step 7)
#   apply also prints `WORKLIST pre-gate-repair <path>:<line> <header>` (report-only) or one
#   `SKIP pre-gate-repair <reason>` line; finish also writes `ASK-UNANSWERED<TAB>family<TAB>path<TAB>digest` on stderr.
#   finish prints `DECIDE <kind> <path> withheld` for a finish check that withholds the stamp (exit 3) and
#   `DECIDE <kind> <path> advisory` for a row apply.sh printed after the stamp, which never sets the exit.
#   apply's last line, when apply.sh deferred the stamp (it never stamps under the driver), is
#   `NEXT pull.sh finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>`: the step that
#   writes the stamp, with the same <base>; it is not a decision and nothing is pending on it.
#   apply, on a retry of the same theirs off an `ai-dlc-update/*` branch, and deliver: one
#   `NOTE pull-writes-moved <path> recorded <blob> now <blob>` per path the pull wrote whose content
#   moved since its last driver step, then `REFUSED apply-pull-writes-moved rc=2` or
#   `REFUSED deliver-pull-writes-moved rc=2`; with no record of the pull's writes for this theirs,
#   one `NOTE pull-writes-unrecorded ...` line and no refusal. record, on a finished pull (no in-flight
#   marker) whose record names this theirs: `NOTE pull-writes-recorded <n> <theirs>`, exit 0; otherwise
#   `REFUSED record-pull-unfinished rc=2` or `REFUSED record-no-record rc=2`. record re-records only the
#   paths after `--`: a recorded path whose content moved and that is not named prints
#   `NOTE pull-writes-moved <path> recorded <blob> now <blob>`, then `REFUSED record-path-unnamed rc=2`;
#   deliver discloses each re-recorded path as `NOTE pull-writes-rerecorded <path> ...` in the commit and the PR body. apply, about to snapshot a new theirs
#   while another theirs's pull, not yet delivered, still has uncommitted writes: one `NOTE pull-writes-unfinished <path>
#   theirs <sha>` per path, then `REFUSED apply-pull-unfinished rc=2`.
#   deliver also prints `DECIDE push-red <log>` (exit 3), `ASK base-confirm <branch> - <question>`
#   (exit 3), one `DECIDE <status> <block> drain` per push-drain.sh row, and `DECIDE pr <url> opened`;
#   with no dirty snapshot for this theirs, one `NOTE deliver-no-snapshot ...` line. A file dirty at
#   the snapshot whose pull change cannot be separated from the operator's edit: one
#   `NOTE deliver-dirty-overlap <path> overlap|unrecorded` per path, then
#   `REFUSED deliver-dirty-overlap rc=2`, before any write. Staging the file does not lift it; only
#   `--whole <path>` (one per path) commits such a path whole, as the worktree holds it, with
#   `NOTE deliver-dirty-whole <path> ...` in the commit message and the PR body.
#   Beside an ASK row whose answer cited a short digest: `NOTE ask-short-cite <path> ... <digest>`.
#   cut-from prints the branch <branch> was cut from (SKILL.md step 1's reflog derivation), or nothing
#   when no reflog line matches, exit 0; exit 2 on usage; git's own exit (128) when <consumer> is no repository.
# Exit: 0 done; 2 refused (usage too); 3 pending: an ASK row awaits an operator answer, or a HARD row
# must be resolved before anything is written, or (finish) a WORKLIST row withholds the stamp (an
# advisory row does not).
#
# THE RUN: `<consumer git-dir>/ai-dlc-pull/run-<utc>-<pid>/` holds `raw/` (emit-report.sh --keep-raw),
# `region`, `decisions.tsv` and the subjects' own logs. `<git-dir>/ai-dlc-pull/pull-writes` records
# the pull's own writes (pl_writes_record). `<git-dir>/ai-dlc-pull/asks.tsv` is the pull's
# ask ledger (conflict hunks, classify blocks tagged conflict or blend), read by apply.sh's CONFLICT
# GUARD. Decision rows are copied to the tracked `_bmad-output/ai-dlc-update/pull-decisions.tsv` only
# after the last detector-reuse site, so writing them never moves the fingerprint F.
#
# Detectors run ONCE per `apply`: one render with --keep-raw, then the union gate and apply.sh's three
# pre-write calls answer from that store while F (reconcile/pull-key.sh) is unchanged.
set -uo pipefail

case "${BASH_SOURCE[0]}" in */*) R="${BASH_SOURCE[0]%/*}" ;; *) R=. ;; esac
R="$(cd "$R" && pwd)"
. "$R/pull-key.sh" || { echo "REFUSED pull-key rc=2"; exit 2; }
ASKS="$R/ask-families.tsv"
TAB="$(printf '\t')"
REPORT_REL="_bmad-output/ai-dlc-update/reconcile-report.md"
DECISIONS_REL="_bmad-output/ai-dlc-update/pull-decisions.tsv"
HIST_REL="_bmad-output/operator-answers-history.md"
BMAD_DIGEST_REL="_bmad-output/ai-dlc-update/bmad-manifest-digest"

usage() { sed -n '/^# Usage:/,/^# STDOUT/p' "$R/pull.sh" | sed '$d' >&2; exit 2; }
refuse() { echo "REFUSED $1 rc=$2"; exit 2; }
# ra_recorded, the union gate's answer reader, is apply.sh's; it is loaded from there, never copied.
eval "$(awk '/^ra_recorded\(\) \{/,/^\}/' "$R/apply.sh" 2>/dev/null)"
command -v ra_recorded >/dev/null 2>&1 || refuse "ra_recorded-unloadable" 2
# ra_short_cited, the short-digest diagnostic beside it, is loaded the same way.
eval "$(awk '/^ra_short_cited\(\) \{/,/^\}/' "$R/apply.sh" 2>/dev/null)"
command -v ra_short_cited >/dev/null 2>&1 || refuse "ra_short_cited-unloadable" 2

question_of() { awk -F'\t' -v f="$1" '!/^#/ && $1 == f {print $4; exit}' "$ASKS" 2>/dev/null; }
gitdir_of() { git -C "$1" rev-parse --absolute-git-dir 2>/dev/null; }
# pl_short_note <path> <digest> -- beside a re-asked ASK row: the answer the history holds cites a
# short digest, so it did not count (ra_recorded is unchanged).
pl_short_note() {
  ra_short_cited "$CONSUMER/$HIST_REL" "$2" || return 0
  echo "NOTE ask-short-cite $1 the answer is recorded but its question cited a short digest; re-ask quoting the full 64-hex digest $2"
}
# pl_artifact_add <git-dir> <theirs sha> <consumer-relative path> -- the pull's artifacts record,
# `<git-dir>/ai-dlc-pull/pull-artifacts`: a header keyed on theirs (another theirs replaces the
# record), then one path per line that this pull wrote outside the dirty snapshot's reach. deliver
# always stages them. reconcile/self-update-push.sh appends its own record the same way.
pl_artifact_add() {
  local f="$1/ai-dlc-pull/pull-artifacts"
  mkdir -p "$1/ai-dlc-pull" || return 1
  if [ ! -f "$f" ] || [ "$(sed -n 1p "$f")" != "ai-dlc-pull-artifacts 1 $2" ]; then
    printf 'ai-dlc-pull-artifacts 1 %s\n' "$2" > "$f" || return 1
  fi
  grep -qxF -- "$3" "$f" || printf '%s\n' "$3" >> "$f"
}

# --- resolve ------------------------------------------------------------------------------------
pl_resolve() {
  local c="${1:-}" ref="${2:-}" st base up sk out dist theirs head
  [ -n "$c" ] && [ -d "$c" ] || usage
  st="$c/.claude/.ai-dlc-version"
  [ -f "$st" ] || refuse "resolve stamp-absent" 2
  base="$(sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$st" | head -1)"
  [ -n "$base" ] || base="$(head -1 "$st" | awk '{print $NF}')"
  up="$(sed -n 's/^upstream:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$st" | head -1)"
  sk="$(sed -n 's/^skill_commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$st" | head -1)"
  [ -n "$up" ] || { echo "ASK upstream-url .claude/.ai-dlc-version - The stamp records no upstream: which URL or local path should the distribution be cloned from?"; exit 3; }
  [ -n "$base" ] || refuse "resolve stamp-commit" 2
  if [ -n "$ref" ]; then
    out="$(bash "$R/dist-clone.sh" --theirs "$ref" "$c" "$up" "$base" ${sk:+"$sk"})" || refuse "resolve dist-clone" "$?"
  else
    out="$(bash "$R/dist-clone.sh" "$c" "$up" "$base" ${sk:+"$sk"})" || refuse "resolve dist-clone" "$?"
  fi
  dist="$(printf '%s\n' "$out" | sed -n 1p)"
  theirs="$(printf '%s\n' "$out" | sed -n 's/^theirs //p' | head -1)"
  [ -n "$dist" ] && [ -n "$theirs" ] || refuse "resolve dist-clone-output" 2
  # The four ref checks (SKILL.md step 1): resolves in the dist; base is an ancestor; reachable from
  # the dist's default branch; not equal to base.
  theirs="$(git -C "$dist" rev-parse -q --verify "${theirs}^{commit}" 2>/dev/null)" || refuse "resolve ref-resolves-in-dist" 2
  base="$(git -C "$dist" rev-parse -q --verify "${base}^{commit}" 2>/dev/null)" || refuse "resolve base-resolves-in-dist" 2
  git -C "$dist" merge-base --is-ancestor "$base" "$theirs" 2>/dev/null || refuse "resolve base-is-ancestor" 2
  head="$(git -C "$dist" rev-parse -q --verify HEAD 2>/dev/null)" || refuse "resolve default-branch" 2
  git -C "$dist" merge-base --is-ancestor "$theirs" "$head" 2>/dev/null || refuse "resolve reachable-from-default-branch" 2
  [ "$theirs" != "$base" ] || refuse "resolve not-equal-to-base" 2
  echo "RESOLVE dist=$dist base=$base theirs=$theirs"
  exit 0
}

# --- gate ---------------------------------------------------------------------------------------
# self-update-gate.sh takes <dist> <base> <theirs> <consumer> and exits 0 always; the verdict is its
# rows': any DEFER wins, else any UNDECIDED, else OK.
pl_gate() {
  local out v=OK gd th f before=" " rd="_bmad-output/ai-dlc-update"
  for f in "$3/$rd"/self-update-gate-*.md; do [ -e "$f" ] && before="$before${f##*/} "; done
  out="$(bash "$R/self-update-gate.sh" "$1" "$2" "$4" "$3")" || refuse "self-update-gate" "$?"
  # The gate record this run wrote joins the pull's artifacts record; an older one does not.
  gd="$(gitdir_of "$3")" || gd=""
  th="$(git -C "$1" rev-parse -q --verify "${4}^{commit}" 2>/dev/null)" || th="$4"
  if [ -n "$gd" ]; then
    for f in "$3/$rd"/self-update-gate-*.md; do
      [ -e "$f" ] || continue
      case "$before" in *" ${f##*/} "*) continue ;; esac
      pl_artifact_add "$gd" "$th" "$rd/${f##*/}" || echo "pull: the gate record $rd/${f##*/} could not join the pull's artifacts record; deliver stages it only if it was absent when apply began" >&2
    done
  fi
  case "$out" in *"SELF-UPDATE-UNDECIDED"*) v=UNDECIDED ;; esac
  case "$out" in *"SELF-UPDATE-DEFER"*) v=DEFER ;; esac
  case "$out" in *"SELF-UPDATE-OK"*|*"SELF-UPDATE-DEFER"*|*"SELF-UPDATE-UNDECIDED"*) ;; *) v=UNDECIDED ;; esac
  echo "GATE $v"
  printf '%s\n' "$out" | awk -F'\t' '$1 == "SELF-UPDATE-SAFE-STOP" || $1 == "SELF-UPDATE-CARRY" || $1 == "SELF-UPDATE-UNDECIDED" || $1 == "SELF-UPDATE-DEFER"'
  exit 0
}

# --- the render ---------------------------------------------------------------------------------
# pl_render: one emit-report.sh render with --keep-raw into the run dir; the region is written into
# the report; RENDERS counts it. A render that refused, or whose store was not kept, is never reused.
RENDERS=0
pl_render() {
  local kept rc
  bash "$R/emit-report.sh" --keep-raw "$RUN/raw" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$RUN/region" 2> "$RUN/render.err"
  rc=$?
  RENDERS=$((RENDERS + 1))
  [ "$rc" -eq 0 ] || refuse "emit-report" "$rc"
  pl_write_region || refuse "report-write" 2
  echo "PULL run=$RUN key=$(sed -n 's/^pull-key 1 \(............\).*/\1/p' "$RUN/raw/F" 2>/dev/null || true) renders=$RENDERS"
  # A detector that refused is reported, and the region carries its DETECTOR-REFUSED line exactly as
  # a plain render does (the gate decides on it as it always has). Its store is not kept, so the
  # PULL line's key is empty and every later detector call in this invocation runs fresh.
  sed -n 's/^DETECTOR-REFUSED  \([^ ]*\)\(.*exited \([^ ]*\)\)\{0,1\}.*/REFUSED \1 rc=\3/p' "$RUN/region"
  kept="$(grep -c '^emit-report: keep-raw: kept ' "$RUN/render.err")" || kept=0
  REUSED=0; [ "$kept" = 1 ] && REUSED=1
}
# pl_write_region: the region replaces the report's region in place, or starts the report.
pl_write_region() {
  local rep="$CONSUMER/$REPORT_REL" tmp
  mkdir -p "${rep%/*}" || return 1
  tmp="$rep.pull.$$"
  if [ -f "$rep" ] && grep -q 'BEGIN GENERATED: reconcile-mechanical' "$rep"; then
    awk -v rf="$RUN/region" '
      /BEGIN GENERATED: reconcile-mechanical/ { while ((getline l < rf) > 0) print l; skip = 1; next }
      skip && /END GENERATED: reconcile-mechanical/ { skip = 0; next }
      !skip { print }' "$rep" > "$tmp" || { rm -f "$tmp"; return 1; }
  else
    { printf '# reconcile report\n\n'; cat "$RUN/region"; } > "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  mv -f "$tmp" "$rep"
}

# --- asks ---------------------------------------------------------------------------------------
# pl_classify_ledger: classify blocks in the report (outside the region) tagged `bucket: conflict` or
# `confirmation_kind: blend` join the ask ledger, first-wins per digest, with the consumer file's blob
# as the state the CONFLICT GUARD compares; `confirmation_kind: judgment` blocks are DECIDE rows.
# The core-to-consumer map is preclassify.sh's map_consumer(), loaded from there as apply.sh loads it.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$R/preclassify.sh" 2>/dev/null)"
command -v map_consumer >/dev/null 2>&1 || refuse "map_consumer-unloadable" 2
pl_consumer_of() { map_consumer "$1"; }
pl_classify_ledger() {
  local rep="$CONSUMER/$REPORT_REL" file id kind cp d blob
  [ -f "$rep" ] || return 0
  awk '
    /BEGIN GENERATED: reconcile-mechanical/ { reg = 1 } /END GENERATED: reconcile-mechanical/ { reg = 0; next } reg { next }
    /^FILE: / { file = $2; id = ""; next }
    /^[[:space:]]*- id: / { id = $0; sub(/^[[:space:]]*- id: /, "", id); next }
    /^[[:space:]]*bucket: conflict/ && file != "" { print "classify-conflict\t" file "\t" id }
    /^[[:space:]]*confirmation_kind: blend/ && file != "" { print "blend\t" file "\t" id }
    /^[[:space:]]*confirmation_kind: judgment/ && file != "" { print "judgment\t" file "\t" id }' "$rep" \
    > "$RUN/classify-blocks" || refuse "classify-blocks" 2
  while IFS="$TAB" read -r kind file id; do
      [ -n "$file" ] || continue
      cp="$(pl_consumer_of "$file")"; [ -n "$cp" ] || cp="$file"
      if [ "$kind" = judgment ]; then
        echo "DECIDE judgment $cp model"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' judgment "$cp" "-" model decided "classify block ${id} (confirmation_kind: judgment)" >> "$RUN/decisions.tsv"
        continue
      fi
      # The state is the consumer's COMMITTED blob (pk_ask_ctx): pre-merge whenever this runs, since a
      # pull's writes stay uncommitted until deliver.
      d="$( { printf 'classify\t%s\t%s\t%s\n' "$file" "$id" "$kind"; pk_ask_ctx "$DIST" "$THEIRS" "$CONSUMER" "$cp"; } | pk_sha256)" || continue
      grep -q "${TAB}${d}${TAB}" "$LEDGER" 2>/dev/null && continue
      blob="$(git -C "$CONSUMER" rev-parse -q --verify "HEAD:$cp" 2>/dev/null)" || blob=MISSING
      printf '%s\t%s\t%s\t%s\n' "$kind" "$cp" "$d" "$blob" >> "$LEDGER"
  done < "$RUN/classify-blocks"
}
# pl_print_asks: every ASK row still unanswered -- region rows in ASK families, and ledger rows. Sets ASK_N.
ASK_N=0
pl_print_asks() {
  local f p d row st q hist="$CONSUMER/$HIST_REL" stg
  stg="$RUN/asks.region"
  pk_region_asks "$RUN/region" "$ASKS" "$DIST" "$THEIRS" "$CONSUMER" > "$stg" || refuse "ask-families" 2
  while IFS="$TAB" read -r f p d row; do
    [ -n "$d" ] || continue
    ra_recorded "$hist" "$d" "*" && continue
    echo "ASK $f $p $d $(question_of "$f")"; ASK_N=$((ASK_N + 1))
    pl_short_note "$p" "$d"
  done < "$stg"
  [ -f "$LEDGER" ] || return 0
  while IFS="$TAB" read -r f p d st; do
    [ -n "$d" ] || continue
    ra_recorded "$hist" "$d" "*" && continue
    echo "ASK $f $p $d $(question_of "$f")"; ASK_N=$((ASK_N + 1))
    pl_short_note "$p" "$d"
  done < "$LEDGER"
}

# --- setup --------------------------------------------------------------------------------------
pl_setup() {
  DIST="$1"; BASE="$2"; CONSUMER="$3"; THEIRS="$4"
  [ -d "$CONSUMER" ] || usage
  CONSUMER="$(cd "$CONSUMER" && pwd)"
  GD="$(gitdir_of "$CONSUMER")" || refuse "consumer-git-dir" 2
  [ -n "$GD" ] || refuse "consumer-git-dir" 2
  mkdir -p "$GD/ai-dlc-pull" || refuse "run-dir" 2
  LEDGER="$GD/ai-dlc-pull/asks.tsv"
  RUN="$GD/ai-dlc-pull/run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  mkdir "$RUN" || refuse "run-dir" 2
  : > "$RUN/decisions.tsv"
}
# pl_flush_decisions: the run's rows join the tracked decisions file. Called only after the last
# detector-reuse site of the invocation.
# A row already in the file is not appended again.
pl_flush_decisions() {
  local t="$CONSUMER/$DECISIONS_REL"
  [ -s "$RUN/decisions.tsv" ] || return 0
  mkdir -p "${t%/*}" || return 1
  [ -f "$t" ] || printf 'kind\tpath\tdigest\tdecider\tverdict\tevidence\n' > "$t"
  awk 'FNR == NR { have[$0] = 1; next } !($0 in have) { have[$0] = 1; print }' "$t" "$RUN/decisions.tsv" > "$RUN/decisions.new" || return 1
  cat "$RUN/decisions.new" >> "$t"
}
# pl_decisions_epoch: the decisions file holds ONE pull's rows. The first apply render for a theirs
# other than the one `<git-dir>/ai-dlc-pull/decisions-theirs` records cuts the file back to its header
# (the earlier pull's rows were delivered with its PR) and records this theirs.
pl_decisions_epoch() {
  local t="$CONSUMER/$DECISIONS_REL" rec="$GD/ai-dlc-pull/decisions-theirs" th
  th="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null)" || th="$THEIRS"
  [ -f "$rec" ] && [ "$(cat "$rec")" = "$th" ] && return 0
  if [ -f "$t" ]; then sed -n 1p "$t" > "$t.epoch.$$" && mv -f "$t.epoch.$$" "$t" || return 1; fi
  printf '%s\n' "$th" > "$rec"
}

# --- the dirty snapshot (what deliver may commit) -------------------------------------------------
# pl_status_rows <out-prefix> <hash-worktree 0|1> -- `<out-prefix>.rows`, one row per status entry:
# `<XY>\t<index blob or ->\t<worktree blob or ->\t<path>\t<pair>`; with 1, each non-untracked regular
# file's worktree blob is WRITTEN to the object store (deliver's dirty merge reads it back). <pair> is `-`, or for a rename or
# copy record `<n>` on the new path and `<n>o` on the original path (its own -z field, which follows).
pl_status_rows() {
  local o="$1" xy pth pair
  git -C "$CONSUMER" -c core.quotePath=false status --porcelain=v1 -z --untracked-files=all > "$o.z" 2>/dev/null || return 1
  tr '\0' '\n' < "$o.z" | awk -v T="$TAB" '
    want { print xy T $0 T n "o"; want = 0; next }
    length($0) > 3 { xy = substr($0, 1, 2); p = substr($0, 4)
      if (xy ~ /^[RC]/ || xy ~ /^.[RC]/) { n++; print xy T p T n; want = 1 } else print xy T p T "-" }' > "$o.st" || return 1
  git -C "$CONSUMER" ls-files -s -z 2>/dev/null | tr '\0' '\n' \
    | awk -v T="$TAB" '{ t = index($0, T); split(substr($0, 1, t - 1), m, " "); if (m[3] == "0") print substr($0, t + 1) T m[2] }' > "$o.idx" || return 1
  : > "$o.wt"
  if [ "$2" = 1 ]; then
    : > "$o.wtp"
    while IFS="$TAB" read -r xy pth pair; do
      [ "$xy" = "??" ] && continue
      [ -f "$CONSUMER/$pth" ] && [ ! -L "$CONSUMER/$pth" ] && printf '%s\n' "$pth" >> "$o.wtp"
    done < "$o.st"
    if [ -s "$o.wtp" ]; then
      ( cd "$CONSUMER" && git hash-object -w --no-filters --stdin-paths < "$o.wtp" ) > "$o.wth" || return 1
      paste "$o.wtp" "$o.wth" > "$o.wt" || return 1
    fi
  fi
  awk -F'\t' -v T="$TAB" -v fi="$o.idx" -v fw="$o.wt" '
    FILENAME == fi { ix[$1] = $2; next }
    FILENAME == fw { wt[$1] = $2; next }
    { print $1 T (($2 in ix) ? ix[$2] : "-") T (($2 in wt) ? wt[$2] : "-") T $2 T $3 }' "$o.idx" "$o.wt" "$o.st" > "$o.rows"
}
# pl_theirs_sha -- theirs as the commit the decisions epoch keys on.
pl_theirs_sha() { git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null || printf '%s\n' "$THEIRS"; }
# pl_dirty_snapshot -- `<git-dir>/ai-dlc-pull/dirty-snapshot`: the consumer's dirty set before the
# pull's first apply write, header `ai-dlc-dirty-snapshot 2 <theirs> <run>` (1: no worktree blobs
# written), then pl_status_rows' rows. The rules, per call:
#   on an `ai-dlc-update/*` branch: keep whatever is recorded; with no snapshot for this theirs, write
#     none (deliver then prints `NOTE deliver-no-snapshot`).
#   off such a branch, a different theirs or no snapshot: write one, unless another theirs's pull
#     still has uncommitted writes at their recorded content (pl_writes_unfinished refuses).
#   off such a branch, same theirs (a retry, e.g. after an ABANDON): keep it (the first attempt's
#     writes can still be in the worktree, so a rewrite would call them the operator's own clean
#     state), and refuse while a file the pull wrote moved since its last driver step
#     (pl_writes_check), since this retry would record that edit as the pull's own.
# The snapshot itself is never deleted.
pl_dirty_snapshot() {
  local rec="$GD/ai-dlc-pull/dirty-snapshot" th cur
  th="$(pl_theirs_sha)"
  cur="$(git -C "$CONSUMER" symbolic-ref -q --short HEAD 2>/dev/null)" || cur=""
  case "$cur" in
    ai-dlc-update/*) return 0 ;;
  esac
  if [ -f "$rec" ] && [ "$(sed -n 1p "$rec" | awk '{print $3}')" = "$th" ]; then
    pl_writes_check apply
    return 0
  fi
  pl_writes_unfinished
  pl_status_rows "$RUN/snapshot" 1 || return 1
  { printf 'ai-dlc-dirty-snapshot 2 %s %s\n' "$th" "${RUN##*/}"; cat "$RUN/snapshot.rows"; } > "$rec.$$" || return 1
  mv -f "$rec.$$" "$rec" || return 1
}

# --- the pull's own writes (what deliver compares) --------------------------------------------------
# `<git-dir>/ai-dlc-pull/pull-writes`: header `ai-dlc-pull-writes 1 <theirs>`, then `<path>\t<blob>`
# for each path deliver's selection (pl_deliver_select) takes at that moment, less the always-stage
# set and the pull-artifacts paths (pl_always_stage, and the selection's own strong set) and the
# in-flight marker (the finish removes it; deliver refuses while it stands). <blob> is
# the worktree content hashed raw (`--no-filters`; an identity, never a commit form), `-` for an
# absent path, `L:<target>` for a symlink. Rewritten whole by pl_writes_trap on EVERY exit of
# apply, finish and merge once apply.sh or readopt-override.sh has started, so it holds the content
# as the pull's last driver step left it.
PW_ON=0
pl_writes_file() { printf '%s\n' "$GD/ai-dlc-pull/pull-writes"; }
pl_writes_blob() { # <consumer-relative path> -> its raw content id, `-` absent, `L:<target>` symlink
  if [ -L "$CONSUMER/$1" ]; then printf 'L:%s\n' "$(readlink "$CONSUMER/$1")"
  elif [ -f "$CONSUMER/$1" ]; then git -C "$CONSUMER" hash-object --no-filters -- "$1" 2>/dev/null || printf '?\n'
  elif [ -e "$CONSUMER/$1" ]; then printf '?\n'
  else printf -- '-\n'; fi
}
pl_writes_record() {
  local f th p
  f="$(pl_writes_file)"; th="$(pl_theirs_sha)"
  RUN="$RUN/pull-writes.sel"
  mkdir -p "$RUN" || return 1
  pl_deliver_select > /dev/null 2>&1 || return 1
  { pl_always_stage "$th"; cat "$RUN/deliver.strong" 2>/dev/null; printf '%s\n' .claude/.ai-dlc-applying; } > "$RUN/pw.excl"
  awk -F'\t' -v fx="$RUN/pw.excl" 'FILENAME == fx { x[$0] = 1; next } !($4 in x) && !seen[$4]++ { print $4 }' \
    "$RUN/pw.excl" "$RUN/deliver.sel" > "$RUN/pw.paths" || return 1
  { printf 'ai-dlc-pull-writes 1 %s\n' "$th"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      printf '%s\t%s\n' "$p" "$(pl_writes_blob "$p")"
    done < "$RUN/pw.paths"; } > "$f.$$" || { rm -f "$f.$$"; return 1; }
  mv -f "$f.$$" "$f"
}
# pl_writes_trap -- the EXIT trap pl_apply, pl_finish and pl_merge set before their writer runs. The
# record is written in a subshell with no output, so a failure there never prints or exits for the
# subcommand; the subcommand's own exit status is kept.
pl_writes_trap() {
  local rc=$?
  if [ "$PW_ON" = 1 ]; then
    PW_ON=0
    ( pl_writes_record ) > /dev/null 2>&1 || echo "pull: the record of this pull's own writes ($(pl_writes_file)) could not be written; the next retry or deliver compares against the previous one" >&2
  fi
  exit "$rc"
}
pl_writes_arm() { PW_ON=1; trap pl_writes_trap EXIT; }
# pl_writes_ran -- 0 when a run since this theirs's snapshot started apply.sh (its run dir holds an apply.out).
pl_writes_ran() {
  local snap="$GD/ai-dlc-pull/dirty-snapshot" s="" r t
  s="$(sed -n 1p "$snap" 2>/dev/null | awk '{print $4}')"
  for r in "$GD"/ai-dlc-pull/run-*; do
    [ -f "$r/apply.out" ] || continue
    t="${r##*/}"; [ -z "$s" ] || [[ ! "${t%-*}" < "${s%-*}" ]] || continue
    return 0
  done
  return 1
}
# pl_writes_check <apply|deliver> -- refuses (`REFUSED <apply|deliver>-pull-writes-moved rc=2`) when a
# path the record names no longer holds its recorded content, naming each path. No record for this
# theirs (a pull begun under an earlier engine): one NOTE, no refusal.
pl_writes_check() {
  local f th h1 h2 h3 p b now n=0
  f="$(pl_writes_file)"; th="$(pl_theirs_sha)"
  h1=""; h2=""; h3=""
  [ ! -f "$f" ] || read -r h1 h2 h3 < "$f"
  if [ "$h1 $h2 $h3" != "ai-dlc-pull-writes 1 $th" ]; then
    # A retry whose earlier attempts never started apply.sh (an apply that stopped at its ASK rows)
    # wrote nothing to record: no NOTE.
    if [ "$1" = apply ] && ! pl_writes_ran; then return 0; fi
    echo "NOTE pull-writes-unrecorded no record of this pull's own writes for this theirs (a pull begun under an earlier engine), so an edit made since its last driver step is not checked"
    return 0
  fi
  sed -n '2,$p' "$f" > "$RUN/pw-check.rows" || refuse "$1-pull-writes-read" 2
  while IFS="$TAB" read -r p b; do
    [ -n "$p" ] || continue
    now="$(pl_writes_blob "$p")"
    [ "$now" = "$b" ] && continue
    echo "NOTE pull-writes-moved $p recorded $b now $now"; n=$((n + 1))
  done < "$RUN/pw-check.rows"
  [ "$n" -eq 0 ] && return 0
  # deliver runs only on a finished pull, where finish refuses (finish-base-unverified on the stamped tree):
  # its remedy is `record`, which only rewrites the record. apply's retry is before the finish.
  local step="\`pull.sh finish\` with the same arguments"
  [ "$1" = deliver ] && step="\`pull.sh record\` with the same arguments followed by \`-- <path>\` for each file above (the PR discloses each one)"
  echo "pull: $n file(s) this pull wrote changed after its last driver step (pull.sh apply, finish, merge or record): your own edit since the pull's last step, or a step-7 merge made after the last driver run. Nothing was written. Move your own edit out of each file named above (re-apply it after the PR merges), or, for a step-7 merge, run $step so the record takes the merge; then re-run $1." >&2
  refuse "$1-pull-writes-moved" 2
}
# pl_record -- `pull.sh record <dist> <base> <consumer> <theirs> [-- <path>...]`: rewrites this theirs's
# record of the pull's own writes from the work tree, and nothing else. Only on a finished pull (the
# in-flight marker gone) that already holds a record for this theirs; it stamps nothing and runs no
# apply.sh check. Every recorded path whose content moved must be named after `--` (else
# `REFUSED record-path-unnamed`, naming them); each named path that moved is appended to
# `<git-dir>/ai-dlc-pull/pull-writes.rerecorded` (header `ai-dlc-pull-rerecorded 1 <theirs>`), which
# deliver discloses as `NOTE pull-writes-rerecorded`.
pl_record() {
  local f th h1 h2 h3 p b now n=0 named rr nl
  nl="$(printf '\n_')"; nl="${nl%_}"
  named=""
  if [ $# -gt 4 ]; then
    for p in "${@:6}"; do named="$named$nl$p"; done
  fi
  named="$named$nl"
  pl_setup "$1" "$2" "$3" "$4"
  [ ! -e "$CONSUMER/.claude/.ai-dlc-applying" ] && [ ! -L "$CONSUMER/.claude/.ai-dlc-applying" ] || refuse "record-pull-unfinished" 2
  f="$(pl_writes_file)"; th="$(pl_theirs_sha)"; rr="$f.rerecorded"
  h1=""; h2=""; h3=""
  [ ! -f "$f" ] || read -r h1 h2 h3 < "$f"
  [ "$h1 $h2 $h3" = "ai-dlc-pull-writes 1 $th" ] || refuse "record-no-record" 2
  sed -n '2,$p' "$f" > "$RUN/pw-check.rows" || refuse "record-read" 2
  : > "$RUN/pw-rerecorded"
  while IFS="$TAB" read -r p b; do
    [ -n "$p" ] || continue
    now="$(pl_writes_blob "$p")"
    [ "$now" = "$b" ] && continue
    case "$named" in
      *"$nl$p$nl"*) printf '%s\n' "$p" >> "$RUN/pw-rerecorded" ;;
      *) echo "NOTE pull-writes-moved $p recorded $b now $now"; n=$((n + 1)) ;;
    esac
  done < "$RUN/pw-check.rows"
  if [ "$n" -gt 0 ]; then
    echo "pull: $n file(s) above changed since the pull's last driver step and were not named. record re-records only the files named after \`--\`, and deliver discloses each one in the PR. Nothing was written. Name each file whose new content belongs in the update (\`pull.sh record <dist> <base> <consumer> <theirs> -- <path>...\`), and move your own edit out of any other." >&2
    refuse "record-path-unnamed" 2
  fi
  ( pl_writes_record ) > /dev/null 2>&1 || refuse "record-write" 2
  if [ -s "$RUN/pw-rerecorded" ]; then
    # Another theirs's list is replaced; this theirs's grows, each path once.
    if [ -f "$rr" ] && [ "$(sed -n 1p "$rr")" = "ai-dlc-pull-rerecorded 1 $th" ]; then cp "$rr" "$rr.$$" || refuse "record-write" 2
    else printf 'ai-dlc-pull-rerecorded 1 %s\n' "$th" > "$rr.$$" || refuse "record-write" 2; fi
    awk 'NR == 1 || !seen[$0]++' "$rr.$$" "$RUN/pw-rerecorded" > "$rr.$$.u" && mv -f "$rr.$$.u" "$rr" || refuse "record-write" 2
    rm -f "$rr.$$"
  fi
  echo "NOTE pull-writes-recorded $(($(wc -l < "$f") - 1)) $th"
  exit 0
}
# pl_writes_unfinished -- before a NEW theirs's snapshot: a record for another theirs whose paths are
# still uncommitted (in the status) at their recorded content is an unfinished pull; refuse, naming them.
pl_writes_unfinished() {
  local f th h1 h2 h3 p b n=0
  f="$(pl_writes_file)"; th="$(pl_theirs_sha)"
  [ -f "$f" ] || return 0
  read -r h1 h2 h3 < "$f"
  [ "$h1 $h2" = "ai-dlc-pull-writes 1" ] && [ "$h3" != "$th" ] || return 0
  # A pull whose deliver committed is finished: what is still dirty in its files is the operator's.
  [ "$(cat "$(pl_writes_file).delivered" 2>/dev/null)" != "$h3" ] || return 0
  pl_status_rows "$RUN/pw-unfinished" 0 || refuse "dirty-snapshot" 2
  awk -F'\t' '{print $4}' "$RUN/pw-unfinished.rows" > "$RUN/pw-unfinished.dirty"
  sed -n '2,$p' "$f" > "$RUN/pw-unfinished.rec" || refuse "dirty-snapshot" 2
  while IFS="$TAB" read -r p b; do
    [ -n "$p" ] || continue
    grep -qxF -- "$p" "$RUN/pw-unfinished.dirty" || continue
    [ "$(pl_writes_blob "$p")" = "$b" ] || continue
    echo "NOTE pull-writes-unfinished $p theirs $h3"; n=$((n + 1))
  done < "$RUN/pw-unfinished.rec"
  [ "$n" -eq 0 ] && return 0
  echo "pull: $n file(s) above are still uncommitted at the content the pull to $h3 wrote: that pull is unfinished. Nothing was written. Finish and deliver it (pull.sh finish, then deliver, with its theirs), or discard its writes to those files yourself, then re-run apply." >&2
  refuse "apply-pull-unfinished" 2
}

# --- dry-run ------------------------------------------------------------------------------------
# A bare invocation's terminal dry run. Writes only the report (and the git-dir record a plain verify
# keeps); asks nothing.
pl_dry_run() {
  local vrc cc
  pl_setup "$@"
  pl_render
  bash "$R/emit-report.sh" --verify --reuse "$RUN/raw" "$CONSUMER/$REPORT_REL" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$RUN/verify.out" 2> "$RUN/verify.err"
  vrc=$?
  [ "$vrc" -eq 0 ] || refuse "emit-report-verify" "$vrc"
  awk '/^HARD-/ { r = $0; gsub(/[[:space:]]+/, " ", r); if (!(r in s)) { s[r] = 1; print "HARD " r } }' "$RUN/region"
  AI_DLC_PULL_RUN="$RUN" bash "$R/apply.sh" --classify-check "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$RUN/classify-check.out" 2> "$RUN/classify-check.err"
  cc=$?
  [ "$cc" -eq 0 ] || refuse "classify-check" "$cc"
  awk -F'\t' '$1 == "CLASSIFY-CHECK" && $3 == "FAIL" {print "WORK classify " $2}' "$RUN/classify-check.out"
  awk -F'\t' '$1 == "CLASSIFY-CHECK" && $3 == "PASS" {print "DECIDE setup-site-merge " $2 " script"}' "$RUN/classify-check.out"
  exit 0
}

# --- apply --------------------------------------------------------------------------------------
pl_apply() {
  local vrc arc hard br cur ver rows flag=""
  # apply.sh runs with --stamp-at-finish: it never stamps, so `finish` (which forwards
  # --carried-machinery-slice, the flag that advances the skill pair with the rulebook pair) writes
  # the stamp after its tree check against this same <base>. The flag is still passed here so the
  # apply's own withheld row names the finish command with it.
  if [ "${1:-}" = --carried-machinery-slice ]; then flag="$1"; shift; fi
  [ $# -eq 4 ] || usage
  pl_setup "$@"
  # Before the first write this apply makes (the decisions epoch, the render, the region record).
  pl_dirty_snapshot || refuse "dirty-snapshot" 2
  pl_decisions_epoch || refuse "decisions-epoch" 2
  pl_render
  # The driver's FIRST render of this apply replaces a bare-run or old-format approved-region record
  # (emit-report.sh --pull-record), before the union gate reads it; a record an earlier apply round
  # wrote stays first-wins.
  bash "$R/emit-report.sh" --pull-record --verify --reuse "$RUN/raw" "$CONSUMER/$REPORT_REL" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$RUN/verify.out" 2> "$RUN/verify.err"
  vrc=$?
  [ "$vrc" -eq 0 ] || refuse "emit-report-verify" "$vrc"
  pl_classify_ledger
  pl_print_asks
  hard="$(awk '/^HARD-/ { r = $0; gsub(/[[:space:]]+/, " ", r); if (!(r in s)) { s[r] = 1; print "HARD " r } }' "$RUN/region")"
  [ -z "$hard" ] || printf '%s\n' "$hard"
  if [ "$ASK_N" -gt 0 ] || [ -n "$hard" ]; then exit 3; fi
  # THE BRANCH (SKILL.md step 6): every write lands on an `ai-dlc-update/*` branch cut off the
  # current branch; a resolution round already on one stays there.
  cur="$(git -C "$CONSUMER" symbolic-ref -q --short HEAD 2>/dev/null)" || cur=""
  case "$cur" in
    ai-dlc-update/*) ;;
    *) ver="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null | tr -d '[:space:]')"
       br="ai-dlc-update/${ver:-$(git -C "$DIST" rev-parse --short "$THEIRS" 2>/dev/null)}-reconcile-$(date -u +%Y%m%dT%H%M%SZ)"
       git -C "$CONSUMER" checkout -q -b "$br" 2>"$RUN/branch.err" || refuse "branch" "$?" ;;
  esac
  pl_writes_arm
  AI_DLC_PULL_RUN="$RUN" bash "$R/apply.sh" --stamp-at-finish ${flag:+"$flag"} "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$RUN/apply.out" 2> "$RUN/apply.err"
  arc=$?
  if grep -q '^ASK-UNANSWERED' "$RUN/apply.err"; then
    awk -F'\t' '$1 == "ASK-UNANSWERED" {print $2 "\t" $3 "\t" $4}' "$RUN/apply.err" > "$RUN/apply.asks" || refuse "apply-asks" 2
    while IFS="$TAB" read -r f p d; do
      echo "ASK $f $p $d $(question_of "$f")"
      pl_short_note "$p" "$d"
    done < "$RUN/apply.asks"
    exit 3
  fi
  [ "$arc" -eq 0 ] || refuse "apply" "$arc"
  # THE LAST REUSE SITE HAS RUN: decision rows may now reach the tracked file.
  awk -F'\t' '$1 == "WORKLIST" && $2 == "semantic-merge" {print "WORK classify " $3}' "$RUN/apply.out"
  # A gated deletion is an ASK: its ledger row (first-wins, the committed blob as state) holds it open
  # for `finish`, and an unanswered one ends this apply at exit 3.
  # The family is delete-consumer-modified: an unprovably-pristine copy is that question.
  # The row names apply.sh's core-relative path; the committed blob is read at its consumer path.
  local del_n=0 p d blob cp
  awk -F'\t' '$1 == "DECISION" && $2 == "deletion" {print $3}' "$RUN/apply.out" > "$RUN/deletions"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    cp="$(pl_consumer_of "core/$p")"; [ -n "$cp" ] || cp="$p"
    d="$( { printf 'delete-consumer-modified\t%s\n' "$p"; pk_ask_ctx "$DIST" "$THEIRS" "$CONSUMER" "$cp"; } | pk_sha256)" || refuse "deletion-digest" 2
    blob="$(git -C "$CONSUMER" rev-parse -q --verify "HEAD:$cp" 2>/dev/null)" || blob=MISSING
    grep -q "${TAB}${d}${TAB}" "$LEDGER" 2>/dev/null || printf 'delete-consumer-modified\t%s\t%s\t%s\n' "$p" "$d" "$blob" >> "$LEDGER"
    ra_recorded "$CONSUMER/$HIST_REL" "$d" "*" && continue
    echo "ASK delete-consumer-modified $p $d $(question_of delete-consumer-modified)"
    pl_short_note "$p" "$d"
    del_n=$((del_n + 1))
  done < "$RUN/deletions"
  awk -F'\t' '($1 == "WORKLIST" && $2 != "semantic-merge") || ($1 == "DECISION" && $2 != "deletion") {print "DECIDE " $2 " " ($3 == "" ? "-" : $3) " pending"}' "$RUN/apply.out"
  awk -F'\t' '{print "DECIDE " $1 " " $2 " " $5}' "$RUN/decisions.tsv"
  # HOOK pre-gate-repair (H-X1), after apply and before deliver: report-only rows, then the flush.
  pl_hook_pre_gate_repair
  pl_flush_decisions || refuse "decisions-write" 2
  # apply.sh deferred the stamp (its stderr `STAMP-DEFERRED` line): the finish, with this <base>, writes it.
  if grep -q '^STAMP-DEFERRED' "$RUN/apply.err"; then
    echo "NEXT pull.sh finish${flag:+ $flag} $DIST $BASE $CONSUMER $THEIRS"
  fi
  [ "$del_n" -eq 0 ] || exit 3
  exit 0
}
# pl_hook_pre_gate_repair -- BL-819's pre-gate repair, REPORT-ONLY: it never blocks and never moves the
# exit code. It runs the consumer's installed escalation-status validator exactly as the planning gate
# does (core/scripts/gate-transition.sh, `arm 2 verdict.sh validate-escalation-status-vocabulary
# docs/escalations/pending.md`, from the project root) and turns each `STATUSLESS <path>:<line> <header>`
# line into one `WORKLIST pre-gate-repair <path>:<line> <header>` row and one decisions row, so the PR
# body carries it. Rows key on the STATUSLESS lines, never on the exit: 1 also means an out-of-vocabulary
# status. It SKIPs (one `SKIP pre-gate-repair <reason>` line, no row) when the validator is absent, lacks
# the `STATUSLESS-ENTRY` signature (an engine that predates it), or exits anything but 0 or 1.
pl_hook_pre_gate_repair() {
  local v="scripts/ai-dlc/validate-escalation-status-vocabulary.sh" pend="docs/escalations/pending.md" n rc vocab loc hdr seen=" "
  [ -f "$CONSUMER/$v" ] || { echo "SKIP pre-gate-repair the validator is not installed ($v)"; return 0; }
  n="$(grep -c 'STATUSLESS-ENTRY' "$CONSUMER/$v")" || n=0
  [ "$n" -gt 0 ] || { echo "SKIP pre-gate-repair the installed validator predates STATUSLESS-ENTRY"; return 0; }
  ( cd "$CONSUMER" && bash "$v" "$pend" ) > "$RUN/pgr.out" 2> "$RUN/pgr.err" < /dev/null
  rc=$?
  case "$rc" in 0|1) ;; *) echo "SKIP pre-gate-repair the validator exited $rc"; return 0 ;; esac
  # The tokens an entry is authored with: escalations.md's `**Status:**` line, the source the validator reads.
  vocab="$(awk '/^\*\*Status:\*\*/ { s = $0; sub(/^\*\*Status:\*\*[[:space:]]*/, "", s); gsub(/`/, "", s); print s; exit }' \
            "$CONSUMER/.claude/skills/ai-dlc/escalations.md" 2>/dev/null)"
  [ -n "$vocab" ] || vocab="a token from the \`**Status:**\` line of .claude/skills/ai-dlc/escalations.md"
  # The offender line is `STATUSLESS <path>:<line> <header>`, or the same behind a leading `FAIL: `
  # (the validator's newer form, on either stream); both parse.
  cat "$RUN/pgr.out" "$RUN/pgr.err" > "$RUN/pgr.lines" 2>/dev/null
  while read -r n loc hdr; do
    if [ "$n" = "FAIL:" ]; then n="${loc}"; loc="${hdr%% *}"; hdr="${hdr#* }"; fi
    [ "$n" = STATUSLESS ] && [ -n "$loc" ] || continue
    case "$seen" in *" $loc "*) continue ;; esac; seen="$seen $loc "
    echo "WORKLIST pre-gate-repair $loc $hdr"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' pre-gate-repair "$loc" "-" script worklist \
      "dated escalation entry ${hdr} has no **Status:** field and fails the planning gate; add a \`**Status:** <token>\` line under it, the token one of: ${vocab}" >> "$RUN/decisions.tsv"
  done < "$RUN/pgr.lines"
  return 0
}

# --- finish -------------------------------------------------------------------------------------
pl_finish() {
  local flag="" frc f p d
  if [ "${1:-}" = --carried-machinery-slice ]; then flag="$1"; shift; fi
  [ $# -eq 4 ] || usage
  pl_setup "$@"
  # Classify blocks written since the apply join the ledger. apply.sh --finish owns the ledger check
  # (every row pending or answered before the stamp, exit 3 otherwise), so a bare --finish runs it too.
  pl_classify_ledger
  pl_writes_arm
  bash "$R/apply.sh" --finish ${flag:+"$flag"} "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$RUN/finish.out" 2> "$RUN/finish.err"
  frc=$?
  if [ "$frc" -eq 3 ] && grep -q '^ASK-UNANSWERED' "$RUN/finish.err"; then
    awk -F'\t' '$1 == "ASK-UNANSWERED"' "$RUN/finish.err" >&2
    awk -F'\t' '$1 == "ASK-UNANSWERED" {print $2 "\t" $3 "\t" $4}' "$RUN/finish.err" > "$RUN/finish.asks" || refuse "finish-asks" 2
    while IFS="$TAB" read -r f p d; do
      echo "ASK $f $p $d $(question_of "$f")"
      pl_short_note "$p" "$d"
    done < "$RUN/finish.asks"
    exit 3
  fi
  [ "$frc" -eq 0 ] || refuse "apply-finish" "$frc"
  # A WORKLIST row before apply.sh's first `restamp*` row is a finish check that withholds the
  # stamp; one after it is an advisory row (hook registration, transient ignore, agent
  # definitions, taught schema), printed after the stamp and never holding it.
  awk -F'\t' 'index($2, "restamp") == 1 {s = 1} $1 == "WORKLIST" {print "DECIDE " $2 " " ($3 == "" ? "-" : $3) (s ? " advisory" : " withheld")}' "$RUN/finish.out"
  pl_flush_decisions || refuse "decisions-write" 2
  if awk -F'\t' 'index($2, "restamp") == 1 {s = 1} $1 == "WORKLIST" && !s {f = 1} END {exit !f}' "$RUN/finish.out"; then exit 3; fi
  exit 0
}

# --- merge (override drift) ---------------------------------------------------------------------
# readopt-override.sh --merge, recorded: a clean merge is a SCRIPT decision row; a conflict hunk joins
# the ask ledger and prints its ASK row. A pointer-stub refusal (OVERRIDE-SHADOWS-POINTER-STUB) prints
# readopt-override's row line on stdout and its remedy lines on stderr, verbatim, and exits 3: an
# operator edit is pending, nothing was written, and no decision row is recorded.
pl_merge() {
  local ovr="${5:-}" rel rc d
  [ -n "$ovr" ] || usage
  pl_setup "$1" "$2" "$3" "$4"
  case "$ovr" in /*) rel="${ovr#"$CONSUMER"/}" ;; *) rel="$ovr"; ovr="$CONSUMER/$ovr" ;; esac
  pl_writes_arm
  bash "$R/readopt-override.sh" "$DIST" "$THEIRS" "$CONSUMER" "$ovr" --merge > "$RUN/merge.out" 2> "$RUN/merge.err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "DECIDE override-drift $rel merged"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' override-drift "$rel" "$(git hash-object --no-filters -- "$ovr" 2>/dev/null)" script merged "readopt-override.sh --merge: clean 3-way merge" >> "$RUN/decisions.tsv"
    pl_flush_decisions || refuse "decisions-write" 2
    exit 0
  fi
  if [ "$rc" -eq 1 ] && grep -q '^REFUSED  [^ ]*: OVERRIDE-SHADOWS-POINTER-STUB ' "$RUN/merge.err"; then
    grep '^REFUSED  [^ ]*: OVERRIDE-SHADOWS-POINTER-STUB ' "$RUN/merge.err" || refuse "merge-relay" 2
    grep -v '^REFUSED  [^ ]*: OVERRIDE-SHADOWS-POINTER-STUB ' "$RUN/merge.err" >&2
    exit 3
  fi
  if [ "$rc" -eq 1 ] && grep -q 'CONFLICT' "$RUN/merge.err" && grep -q '^<<<<<<< ' "$ovr"; then
    # readopt-override.sh already appended the ledger row; the same writer, first-wins, names its digest.
    d="$(pk_conflict_ledger "$CONSUMER" "$ovr")" || refuse "merge-ledger" 2
    echo "ASK conflict-hunk $rel $d $(question_of conflict-hunk)"
    exit 3
  fi
  refuse "readopt-override" "$rc"
}

# --- deliver (SKILL.md step 8's mechanical part: commit, push, PR) --------------------------------
# On an `ai-dlc-update/*` branch only. Never `gh pr merge`, never the RETURN PROCEDURE: both stay with
# the model. Staging is by explicit pathspec, one path at a time, never `git add -A` or `git add .`.
SKILL_BRANCH_RE='^ai-dlc-update/([0-9]+\.[0-9]+\.[0-9]+-reconcile-|self-update-|untangle-)'
pl_cut_from() { # <consumer> <branch> -> the branch it was cut from, by HEAD's reflog (SKILL.md step 1)
  git -C "$1" reflog --format=%gs 2>/dev/null \
    | awk -v s=" to $2" 'index($0, "checkout: moving from ") == 1 && length($0) > length(s) && substr($0, length($0) - length(s) + 1) == s' \
    | tail -1 | awk -v s=" to $2" '{ x = substr($0, length("checkout: moving from ") + 1); print substr(x, 1, length(x) - length(s)) }'
}
# pl_deliver_select -- `$RUN/deliver.sel`, the status rows deliver commits. A changed path is taken
# when it is in the always-stage set (the report, the decisions file, the answers history, the
# push-candidate ledger and its archive, the stamp, the pull-artifacts record's paths, this pull's
# reconcile log), or this pull's own record names it, exactly (RESOLVED/DECISION/WORKLIST rows of its
# runs' apply.out and finish.out, column 2 of the decisions file and of the ask ledger), or it was
# dirty at the snapshot and its index blob moved since, or it was clean at the snapshot and is not
# under the pipeline-state tree (a schema name under the schema's root, less PL_STATE_EXEMPT). A
# state-tree path clean at the snapshot is a hook's write, not the pull's. Anything else is the
# operator's: a hook appending to a file that was already dirty, an untracked file, a staged entry. A
# rename pair is taken or left whole. No snapshot for this theirs (a pull begun under an older
# engine): every changed path, and one NOTE line. Without the schema or jq: the state filter is off,
# and one NOTE line.
# pl_deliver_merge commits a keep-selected path dirty at the snapshot as the pull's change only (base
# the snapshot's worktree blob, ours HEAD, theirs the worktree, all three in repository form); the
# operator's own edit comes back as an unstaged diff, a staged one unstaged with its content kept.
# Where that cannot be done (the merge overlaps, or the pre-pull content was not recorded) deliver
# REFUSES, naming the paths, unless the operator named the path with `--whole`: then it is committed
# whole, the operator's edit in it, and a deliver NOTE says so. Staging never stands in for `--whole`.
# Always-stage and pull-artifacts paths are committed whole. A settings-merge key the operator also
# set, where user wins, leaves the template's key out of the commit.
PL_STATE_EXEMPT="ai-dlc-update implementation-artifacts planning-artifacts"
# pl_always_stage <theirs sha> -- the always-stage set, then the pull-artifacts record's paths when
# it is this theirs's; one path per line. deliver commits them whole; the pull-writes record omits them.
pl_always_stage() {
  local pa="$GD/ai-dlc-pull/pull-artifacts"
  printf '%s\n' "$REPORT_REL" "$DECISIONS_REL" "_bmad-output/ai-dlc-update/push-candidate-ledger.md" ".claude/.ai-dlc-version" \
    "$HIST_REL" "_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md" "$BMAD_DIGEST_REL"
  [ -f "$pa" ] && [ "$(sed -n 1p "$pa")" = "ai-dlc-pull-artifacts 1 $1" ] && sed -n '2,$p' "$pa"
  return 0
}
# pl_dnote <line> -- a deliver NOTE: printed, and kept in $RUN/deliver.notes for the commit message and the PR body.
pl_dnote() { echo "$1"; echo "$1" >> "$RUN/deliver.notes"; }
pl_deliver_select() {
  : > "$RUN/deliver.notes"
  local snap="$GD/ai-dlc-pull/dirty-snapshot" th srun d k t h1 h2 h3 h4 sch why=""
  pl_status_rows "$RUN/deliver" 0 || return 1
  th="$(pl_theirs_sha)"
  h1=""; h2=""; h3=""; h4=""
  [ ! -f "$snap" ] || read -r h1 h2 h3 h4 < "$snap"
  case "$h1 $h2 $h3" in
    "ai-dlc-dirty-snapshot 1 $th"|"ai-dlc-dirty-snapshot 2 $th") ;;
    *)
    echo "NOTE deliver-no-snapshot no dirty snapshot is recorded for this theirs (an apply begun under an earlier engine); every changed path is committed"
    cp "$RUN/deliver.rows" "$RUN/deliver.sel"
    rm -f "$RUN/deliver.strong"
    return ;;
  esac
  srun="$h4"
  : > "$RUN/deliver.state"
  sch="$CONSUMER/.claude/schemas/pipeline-state-paths.json"
  if [ ! -f "$sch" ]; then why="no $sch"
  elif ! command -v jq >/dev/null 2>&1; then why="no jq"
  else
    jq -er --arg ex "$PL_STATE_EXEMPT" '($ex | split(" ")) as $e | .root as $r | select($r | type == "string")
      | .paths[].name | select(. as $n | ($e | map(. == $n) | any) | not) | $r + "/" + .' "$sch" > "$RUN/deliver.state" 2>>"$RUN/deliver.err" \
      && [ -s "$RUN/deliver.state" ] || { why="jq could not read the state names from $sch"; : > "$RUN/deliver.state"; }
  fi
  [ -z "$why" ] || pl_dnote "NOTE deliver-state-unfiltered $why -- pipeline state files changed since the first apply may be in this commit"
  : > "$RUN/deliver.strong.raw"; : > "$RUN/deliver.weak.raw"
  pl_always_stage "$th" >> "$RUN/deliver.strong.raw"
  for d in "$GD"/ai-dlc-pull/run-*; do
    [ -d "$d" ] || continue
    t="${d##*/}"; [ -z "$srun" ] || [[ ! "${t%-*}" < "${srun%-*}" ]] || continue
    cat "$d/apply.out" "$d/finish.out" 2>/dev/null \
      | awk -F'\t' -v sf="$RUN/deliver.strong.raw" -v wf="$RUN/deliver.weak.raw" '
          $1 == "NOTE" && $2 == "reconcile-log-name" { print $3 >> sf }
          $1 == "RESOLVED" || $1 == "DECISION" || $1 == "WORKLIST" { print $3 >> wf }'
  done
  { awk -F'\t' 'NR > 1 {print $2}' "$CONSUMER/$DECISIONS_REL" 2>/dev/null
    awk -F'\t' '{print $2}' "$LEDGER" 2>/dev/null; } >> "$RUN/deliver.weak.raw"
  # A row may name a core-relative path; its consumer path is taken too.
  : > "$RUN/deliver.keep"; : > "$RUN/deliver.strong"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    { printf '%s\n' "$k"; map_consumer "core/$k"; } | tee -a "$RUN/deliver.strong" >> "$RUN/deliver.keep"
  done < "$RUN/deliver.strong.raw"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    { printf '%s\n' "$k"; map_consumer "core/$k"; } >> "$RUN/deliver.keep"
  done < "$RUN/deliver.weak.raw"
  awk -F'\t' -v fs="$snap" -v fk="$RUN/deliver.keep" -v fst="$RUN/deliver.state" '
    function isstate(p,   i) { for (i = 0; i < ns; i++) if (p == st[i] || index(p, st[i] "/") == 1) return 1; return 0 }
    FILENAME == fs { if (FNR > 1) { insnap[$4] = 1; sidx[$4] = $2; sp = $5; sub(/o$/, "", sp); spair[$4] = sp } next }
    FILENAME == fk { keep[$0] = 1; next }
    FILENAME == fst { st[ns++] = $0; next }
    FNR == 1 { pass++ }
    pass == 1 {
      if (($4 in keep) || (($4 in insnap) && $2 != sidx[$4]) || (!($4 in insnap) && !isstate($4))) {
        sel[$4] = 1
        cp = $5; sub(/o$/, "", cp); if (cp != "-") gc[cp] = 1
        if (($4 in spair) && spair[$4] != "-") gs[spair[$4]] = 1
      }
      next
    }
    { cp = $5; sub(/o$/, "", cp)
      if (($4 in sel) || (cp != "-" && (cp in gc)) || (($4 in spair) && spair[$4] != "-" && (spair[$4] in gs))) print }' \
    "$snap" "$RUN/deliver.keep" "$RUN/deliver.state" "$RUN/deliver.rows" "$RUN/deliver.rows" > "$RUN/deliver.sel"
}
# pl_deliver_merge -- `$RUN/deliver.dm`: the selected paths staged by merge rather than whole (the
# keep-selected paths dirty at the snapshot, tracked in HEAD, not always-stage); `$RUN/deliver.merged`:
# their `<HEAD mode> <merged blob>\t<path>` lines for pl_deliver_commit's temporary index;
# `$RUN/deliver.overlap`: `<path>\t<overlap|unrecorded>` for each candidate it cannot merge (the
# caller refuses on it). Writes objects and files under $RUN only.
# ONE FORM FOR ALL THREE INPUTS, the repository's: ours is the HEAD blob; base is the snapshot's raw
# worktree blob and theirs the worktree file, each hashed WITH the path's attributes (eol, clean,
# LFS); the merged result is then repository form and is hashed `--no-filters`.
# pl_deliver_unmerged <path> <overlap|unrecorded> -- a candidate the merge cannot make: a `deliver.overlap`
# row (the caller refuses on it), or, for a path the operator named with `--whole`, nothing staged by
# merge (the whole worktree file is committed) and a deliver NOTE.
PL_WHOLE=""
pl_deliver_unmerged() {
  local nl
  nl="$(printf '\n_')"; nl="${nl%_}"
  case "$nl$PL_WHOLE$nl" in
    *"$nl$1$nl"*) pl_dnote "NOTE deliver-dirty-whole $1 delivered whole at the operator's request; your uncommitted edits in it are in this commit" ;;
    *) printf '%s\t%s\n' "$1" "$2" >> "$RUN/deliver.overlap" ;;
  esac
}
pl_deliver_merge() {
  local snap="$GD/ai-dlc-pull/dirty-snapshot" v p w0 mode b bb tb
  : > "$RUN/deliver.dm"; : > "$RUN/deliver.merged"; : > "$RUN/deliver.overlap"
  [ -f "$RUN/deliver.strong" ] || return 0
  v="$(sed -n 1p "$snap" | awk '{print $2}')"
  awk -F'\t' -v T="$TAB" -v fs="$snap" -v fk="$RUN/deliver.keep" -v fst="$RUN/deliver.strong" '
    FILENAME == fs { if (FNR > 1) { w0[$4] = $3; sx[$4] = $2 } next }
    FILENAME == fk { keep[$0] = 1; next }
    FILENAME == fst { strong[$0] = 1; next }
    ($4 in w0) && ($4 in keep) && !($4 in strong) && $5 == "-" && $1 !~ /[?D]/ { print $4 T w0[$4] T sx[$4] T $2 }' \
    "$snap" "$RUN/deliver.keep" "$RUN/deliver.strong" "$RUN/deliver.sel" > "$RUN/deliver.dmc"
  while IFS="$TAB" read -r p w0 sx ix; do
    [ -n "$p" ] || continue
    [ -f "$CONSUMER/$p" ] && [ ! -L "$CONSUMER/$p" ] || continue
    git -C "$CONSUMER" cat-file blob "HEAD:$p" > "$RUN/dm.ours" 2>/dev/null || continue
    tb="$(git -C "$CONSUMER" hash-object -w -- "$p")" && [ -n "$tb" ] \
      && git -C "$CONSUMER" cat-file blob "$tb" > "$RUN/dm.theirs" || refuse "deliver-dirty-merge" 2
    if [ "$v" != 2 ] || [ "$w0" = "-" ] || ! git -C "$CONSUMER" cat-file -e "${w0}^{blob}" 2>/dev/null; then
      pl_deliver_unmerged "$p" unrecorded
      continue
    fi
    bb="$(git -C "$CONSUMER" cat-file blob "$w0" | git -C "$CONSUMER" hash-object -w --stdin --path="$p")" && [ -n "$bb" ] \
      && git -C "$CONSUMER" cat-file blob "$bb" > "$RUN/dm.base" || refuse "deliver-dirty-merge" 2
    if ! git merge-file -p "$RUN/dm.ours" "$RUN/dm.base" "$RUN/dm.theirs" > "$RUN/dm.out" 2>>"$RUN/deliver.err"; then
      pl_deliver_unmerged "$p" overlap
      continue
    fi
    b="$(git -C "$CONSUMER" hash-object -w --no-filters "$RUN/dm.out")" || refuse "deliver-dirty-merge" 2
    mode="$(GIT_LITERAL_PATHSPECS=1 git -C "$CONSUMER" ls-tree HEAD -- "$p" | awk '{print $1; exit}')"
    [ -n "$mode" ] && [ -n "$b" ] || refuse "deliver-dirty-merge" 2
    printf '%s %s\t%s\n' "$mode" "$b" "$p" >> "$RUN/deliver.merged"
    printf '%s\n' "$p" >> "$RUN/deliver.dm"
  done < "$RUN/deliver.dmc"
}
# pl_deliver_commit -- the commit is built on a TEMPORARY index (HEAD plus each selected path's
# real-index entry, or its removal), so an entry the operator staged before the pull is not swept in;
# then the real index's selected paths are reset to the new HEAD, so nothing reads as a staged revert
# (a consumer pre-commit hook's own `git add` lands only in the temporary index). Never
# `git commit -- <paths>` / `--only`: that re-adds a `git rm --cached` path still in the worktree.
pl_deliver_commit() {
  local ti="$RUN/deliver.index"
  awk -F'\t' '{print $4}' "$RUN/deliver.sel" > "$RUN/deliver.selp"
  [ -s "$RUN/deliver.selp" ] || return 0
  git -C "$CONSUMER" ls-files -s -z 2>/dev/null | tr '\0' '\n' > "$RUN/deliver.lsf" || refuse "deliver-index" 2
  awk -v T="$TAB" -v fp="$RUN/deliver.selp" -v fr="$RUN/deliver.rm" '
    FILENAME == fp { want[$0] = 1; next }
    { p = substr($0, index($0, T) + 1); if (p in want) { print; have[p] = 1 } }
    END { printf "" > fr; for (p in want) if (!(p in have)) print p > fr }' "$RUN/deliver.selp" "$RUN/deliver.lsf" > "$RUN/deliver.info" \
    || refuse "deliver-index" 2
  rm -f "$ti"
  GIT_INDEX_FILE="$ti" git -C "$CONSUMER" read-tree HEAD 2>>"$RUN/deliver.err" || refuse "deliver-index" 2
  if [ -s "$RUN/deliver.info" ]; then
    tr '\n' '\0' < "$RUN/deliver.info" | GIT_INDEX_FILE="$ti" git -C "$CONSUMER" update-index -z --index-info 2>>"$RUN/deliver.err" || refuse "deliver-index" 2
  fi
  if [ -s "$RUN/deliver.rm" ]; then
    tr '\n' '\0' < "$RUN/deliver.rm" | GIT_INDEX_FILE="$ti" git -C "$CONSUMER" update-index -z --force-remove --stdin 2>>"$RUN/deliver.err" || refuse "deliver-index" 2
  fi
  if [ -s "$RUN/deliver.merged" ]; then
    tr '\n' '\0' < "$RUN/deliver.merged" | GIT_INDEX_FILE="$ti" git -C "$CONSUMER" update-index -z --index-info 2>>"$RUN/deliver.err" || refuse "deliver-index" 2
  fi
  GIT_INDEX_FILE="$ti" git -C "$CONSUMER" diff --cached --quiet && return 0
  GIT_INDEX_FILE="$ti" git -C "$CONSUMER" commit -q -F "$RUN/commit.msg" 2>>"$RUN/deliver.err" || refuse "deliver-commit" 2
  tr '\n' '\0' < "$RUN/deliver.selp" > "$RUN/deliver.selz"
  GIT_LITERAL_PATHSPECS=1 git -C "$CONSUMER" reset -q HEAD --pathspec-from-file="$RUN/deliver.selz" --pathspec-file-nul 2>>"$RUN/deliver.err" \
    || refuse "deliver-index-reset" 2
}
# pl_bmad_probe -- the upgrade-time BMAD probe. Runs the installed validator only when the manifest's blob
# differs from the one recorded at the last validated pull; exit 1 refuses, any other non-0 exit is a SKIP,
# a missing record degrades to a report. The record is written only on exit 0 or 1 of a run that did not refuse.
pl_bmad_probe() {
  local mf="_bmad/_config/manifest.yaml" cur rec rc
  [ -f "$CONSUMER/$mf" ] || { echo "NOTE bmad-probe no-manifest"; return 0; }
  cur="$(git -C "$CONSUMER" hash-object --no-filters -- "$mf" 2>/dev/null)" || cur=""
  [ -n "$cur" ] || { echo "NOTE bmad-probe SKIP rc=hash"; return 0; }
  rec="$(awk 'NR == 1 && $1 == "ai-dlc-bmad-manifest" && $2 == "1" {print $3}' "$CONSUMER/$BMAD_DIGEST_REL" 2>/dev/null)"
  if [ "$rec" = "$cur" ]; then echo "NOTE bmad-probe unchanged"; return 0; fi
  AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$CONSUMER/scripts/ai-dlc/validate-bmad-invocations.sh" > "$RUN/bmad-probe.out" 2> "$RUN/bmad-probe.err"
  rc=$?
  case "$rc" in
    0|1) ;;
    *) echo "NOTE bmad-probe SKIP rc=$rc $(cat "$RUN/bmad-probe.out" "$RUN/bmad-probe.err" 2>/dev/null | head -n 1 | tr '\t' ' ')"; return 0 ;;
  esac
  if [ -z "$rec" ]; then
    echo "NOTE bmad-probe no-baseline rc=$rc"
    if [ "$rc" -eq 1 ]; then
      { cat "$RUN/bmad-probe.out" "$RUN/bmad-probe.err"
        echo "pull: the BMAD manifest changed and an invocation the rulebook makes no longer resolves (see FAIL lines and the BMAD floor above). Run npx bmad-method install, or revert the BMAD change, then re-run deliver."; } >&2
    fi
  elif [ "$rc" -eq 1 ]; then
    { cat "$RUN/bmad-probe.out" "$RUN/bmad-probe.err"
      echo "pull: the BMAD manifest changed and an invocation the rulebook makes no longer resolves (see FAIL lines and the BMAD floor above). Run npx bmad-method install, or revert the BMAD change, then re-run deliver."; } >&2
    refuse "deliver-bmad-invocations" 2
  else
    echo "NOTE bmad-probe pass"
  fi
  mkdir -p "$CONSUMER/${BMAD_DIGEST_REL%/*}" && printf 'ai-dlc-bmad-manifest 1 %s\n' "$cur" > "$CONSUMER/$BMAD_DIGEST_REL"
}
# pl_deliver_prepare -- the selection, the unmerged-entry refusal and the dirty merge; refuses
# `deliver-dirty-overlap` (one NOTE per path first) when a candidate cannot be merged.
pl_deliver_prepare() {
  local xy ix wt p pair why
  pl_deliver_select || refuse "deliver-status" 2
  while IFS="$TAB" read -r xy ix wt p pair; do
    [ -n "$p" ] || continue
    case "$xy" in UU|AA|DD|AU|UD|UA|DU) refuse "deliver-unmerged $p" 2 ;; esac
  done < "$RUN/deliver.sel"
  pl_deliver_merge
  [ -s "$RUN/deliver.overlap" ] || return 0
  while IFS="$TAB" read -r p why; do
    [ -n "$p" ] || continue
    echo "NOTE deliver-dirty-overlap $p $why"
  done < "$RUN/deliver.overlap"
  echo "pull: each file above was already dirty when the pull began and the pull changed it too, and its change cannot be separated from your own edit (overlap: the edits touch the same lines; unrecorded: the pre-pull content was not recorded). Nothing was committed. Staging a file does not change this. For each file, re-run deliver with \`--whole <path>\` (one per file): deliver then commits the file whole as the worktree holds it, your uncommitted edit in it included, and says so in the commit message and the PR body. To keep your edit out of the commit, first save it aside and take it out of the file, re-run with \`--whole <path>\`, then restore your edit." >&2
  refuse "deliver-dirty-overlap" 2
}
pl_deliver() {
  local br cut bv tv subj body p n_notes rc url xy ix wt pair n dm nl
  nl="$(printf '\n_')"; nl="${nl%_}"
  pl_setup "$@"
  br="$(git -C "$CONSUMER" symbolic-ref -q --short HEAD 2>/dev/null)" || br=""
  case "$br" in ai-dlc-update/*) ;; *) refuse "deliver-not-on-update-branch" 2 ;; esac
  [ ! -e "$CONSUMER/.claude/.ai-dlc-applying" ] || refuse "deliver-pull-unfinished" 2
  # EVERY REFUSAL BEFORE ANY WRITE: the pull-writes record, then a dry pass of the selection and the
  # dirty merge (they write under $RUN only), before pl_bmad_probe writes its digest. The pass is
  # repeated for real after the probe, because the digest it writes is an always-stage path the
  # selection must see; the merge set excludes always-stage paths, so the second pass merges the same.
  pl_writes_check deliver
  ( pl_deliver_prepare ) > "$RUN/deliver.pre.out" 2> "$RUN/deliver.pre.err"
  rc=$?
  if [ "$rc" -ne 0 ]; then cat "$RUN/deliver.pre.out"; cat "$RUN/deliver.pre.err" >&2; exit "$rc"; fi
  pl_bmad_probe
  # Step 8's drain reader: its rows are DECIDE rows for the model, which drains PUSH-CANDIDATE rows.
  bash "$R/push-drain.sh" "$DIST" "$THEIRS" "$CONSUMER" > "$RUN/push-drain.out" 2> "$RUN/push-drain.err"
  rc=$?
  [ "$rc" -eq 0 ] || echo "REFUSED push-drain rc=$rc"
  [ "$rc" -ne 0 ] || awk -F'\t' 'NF >= 2 {print "DECIDE " $1 " " $2 " drain"}' "$RUN/push-drain.out"
  # Commit: only the pull's own writes (pl_deliver_select), each by its own pathspec.
  pl_deliver_prepare
  # Each path `pull.sh record -- <path>` re-recorded for this theirs is disclosed.
  if [ -f "$(pl_writes_file).rerecorded" ] && [ "$(sed -n 1p "$(pl_writes_file).rerecorded")" = "ai-dlc-pull-rerecorded 1 $(pl_theirs_sha)" ]; then
    sed -n '2,$p' "$(pl_writes_file).rerecorded" > "$RUN/deliver.rerecorded"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      pl_dnote "NOTE pull-writes-rerecorded $p re-recorded by pull.sh record at the operator's request; edits made in it after the pull's last step are in this commit"
    done < "$RUN/deliver.rerecorded"
  fi
  dm="$nl$(cat "$RUN/deliver.dm")$nl"
  while IFS="$TAB" read -r xy ix wt p pair; do
    [ -n "$p" ] || continue
    case "$dm" in *"$nl$p$nl"*) continue ;; esac
    # Index-current (worktree column blank, or a rename's original path): already staged as it must be.
    case "$pair" in *o) continue ;; esac
    case "$xy" in ?" ") continue ;; esac
    git -C "$CONSUMER" add -A -- ":(literal)$p" 2>>"$RUN/deliver.err" || refuse "deliver-stage" 2
  done < "$RUN/deliver.sel"
  bv="$(git -C "$DIST" show "${BASE}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  tv="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  subj="chore(ai-dlc-update): reconcile distribution ${bv:-$BASE} → ${tv:-$THEIRS}"
  n_notes="$(cat "$GD"/ai-dlc-pull/run-*/apply.out 2>/dev/null | awk -F'\t' '$1 == "NOTE"' | sort -u)"
  [ ! -s "$RUN/deliver.notes" ] || n_notes="$(printf '%s\n%s\n' "$n_notes" "$(cat "$RUN/deliver.notes")" | sed '/^$/d')"
  { printf '%s\n\n' "$subj"
    printf 'Buckets applied: %s. Conflicts adjudicated (hook-recorded answers): %s.\n' \
      "$(cat "$GD"/ai-dlc-pull/run-*/apply.out 2>/dev/null | awk -F'\t' '$1 == "RESOLVED"' | sort -u | wc -l | tr -d ' ')" \
      "$(awk -F'\t' 'NR > 1 && $4 == "operator"' "$CONSUMER/$DECISIONS_REL" 2>/dev/null | wc -l | tr -d ' ')"
    printf 'Log: %s\n' "$REPORT_REL"
    [ -z "$n_notes" ] || { printf '\nNOTE rows:\n'; printf '%s\n' "$n_notes" | tr '\t' ' '; }
  } > "$RUN/commit.msg"
  pl_deliver_commit
  # The pull's writes are committed: `<pull-writes>.delivered` names this theirs, so the next theirs's
  # unfinished check (pl_writes_unfinished) does not read an operator edit kept in those files as this pull.
  printf '%s\n' "$(pl_theirs_sha)" > "$(pl_writes_file).delivered" \
    || echo "pull: $(pl_writes_file).delivered could not be written; the next pull may read this delivered pull as unfinished" >&2
  # The PR body is rendered and bounded BEFORE the push: an oversize body never leaves a pushed branch with no PR.
  pl_pr_body "$CONSUMER" > "$RUN/pr-body.md" || refuse "deliver-pr-body" 2
  n="$(wc -c < "$RUN/pr-body.md" | tr -d ' ')"
  if [ "$n" -gt 60000 ]; then
    echo "pull: the PR body is $n bytes after bounding, over 60000; nothing was pushed. The commit is made, and a deliver re-run skips it: shorten the long rows of $DECISIONS_REL (or the report's region) and re-run deliver." >&2
    refuse "deliver-pr-body-oversize" 2
  fi
  # Push: the consumer's own pre-push runs. A red push is the model's to diagnose.
  git -C "$CONSUMER" remote get-url origin >/dev/null 2>&1 || refuse "deliver-no-remote" 2
  git -C "$CONSUMER" push -u origin "$br" > "$RUN/push.log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] || { echo "DECIDE push-red $RUN/push.log"; exit 3; }
  cut="$(pl_cut_from "$CONSUMER" "$br")"
  [ -n "$cut" ] || { echo "ASK base-confirm $br - No reflog line names the branch this one was cut from: which branch should the PR merge into?"; exit 3; }
  if [[ "$cut" =~ $SKILL_BRANCH_RE ]]; then refuse "deliver-cut-from-skill-branch" 2; fi
  url="$(gh pr create --base "$cut" --head "$br" --title "$subj" --body-file "$RUN/pr-body.md" 2>"$RUN/pr.err")" || refuse "deliver-gh-pr-create" "$?"
  echo "DECIDE pr $url opened"
  exit 0
}

# --- pr-body ------------------------------------------------------------------------------------
# pl_pr_table <decisions file> -- the decisions table's rows, BYTE-bounded: a cell over 400 bytes is
# cut (never inside a UTF-8 sequence) and ends `…`; rows stop once they would pass 30000 bytes, and
# one line counts the rest and points at the decisions file in the PR's diff.
pl_pr_table() {
  LC_ALL=C awk -F'\t' -v rel="$DECISIONS_REL" -v q="'" '
    function cell(s,   c) {
      if (length(s) <= 400) return s
      s = substr(s, 1, 400)
      while (s != "") { c = substr(s, length(s), 1); if (c < "\200" || c > "\277") break; s = substr(s, 1, length(s) - 1) }
      if (s != "" && substr(s, length(s), 1) >= "\300") s = substr(s, 1, length(s) - 1)
      return s "…"
    }
    NR > 1 && NF && !s[$0]++ {
      gsub(/\|/, "\\|")
      r = sprintf("| %s | `%s` | %s | %s | %s |", cell($1), cell($2), cell($4), cell($5), cell($6))
      if (over || acc + length(r) + 1 > 30000) { over = 1; n++; next }
      acc += length(r) + 1; print r
    }
    END { if (n) printf "… %d more decision rows omitted — see `%s` in this PR%ss diff\n", n, rel, q }' "$1"
}
# The decisions file holds this pull's rows only (pl_decisions_epoch); each renders once. The body
# stays under 60000 bytes where it can: when the whole is larger, each region section is one line
# pointing at the report in the PR's diff. deliver refuses, before its push, a body still over.
pl_pr_body() {
  local c="${1:-}" t tp="${TMPDIR:-/tmp}/pull-pr" n
  [ -n "$c" ] || usage
  t="$c/$DECISIONS_REL"
  {
    echo "### Decisions this pull took without asking"
    echo
    echo "Each row is a MODEL or SCRIPT decision; merging this PR approves them. Operator answers are recorded in \`${HIST_REL}\`."
    echo
    pl_pr_table "$t" > "$tp-d.$$" 2>/dev/null
    if [ ! -s "$tp-d.$$" ]; then echo "none"; else
      echo "| kind | path | decider | verdict | evidence |"
      echo "|---|---|---|---|---|"
      cat "$tp-d.$$"
    fi
    if [ -s "${RUN:-/nonexistent}/deliver.notes" ]; then
      echo
      echo "### Deliver notes"
      echo
      sed 's/^/- /' "$RUN/deliver.notes"
    fi
  } > "$tp-h.$$"
  rm -f "$tp-d.$$"
  # The report's region as the pull leaves it, and the region the first --verify of this pull
  # recorded (the dry-run view this PR's review replaces), when the two differ.
  local rep="$c/$REPORT_REL" gd rec
  : > "$tp-b.$$"; : > "$tp-r.$$"
  [ ! -f "$rep" ] || awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$rep" > "$tp-b.$$"
  gd="$(gitdir_of "$c")" || gd=""
  rec="$gd/ai-dlc-approved-region"
  if [ -n "$gd" ] && [ -f "$rec" ] && [ "$(sed -n 1p "$rec")" = "ai-dlc-approved-region 1" ]; then
    sed -n '3,$p' "$rec" > "$tp-r.$$"
    ! cmp -s "$tp-r.$$" "$tp-b.$$" || : > "$tp-r.$$"
  fi
  n="$(cat "$tp-h.$$" "$tp-b.$$" "$tp-r.$$" | wc -c | tr -d ' ')"
  cat "$tp-h.$$"
  echo
  echo "### Reconcile region"
  echo
  if [ ! -f "$rep" ]; then echo "none (no report at \`$REPORT_REL\`)"
  elif [ ! -s "$tp-b.$$" ]; then echo "none (the report carries no region)"
  elif [ "$n" -gt 59000 ]; then echo "omitted ($(wc -c < "$tp-b.$$" | tr -d ' ') bytes): see \`$REPORT_REL\` in this PR's diff"
  else cat "$tp-b.$$"
  fi
  if [ -s "$tp-r.$$" ]; then
    echo
    echo "### Dry-run region (first verified for this pull)"
    echo
    if [ "$n" -gt 59000 ]; then echo "omitted ($(wc -c < "$tp-r.$$" | tr -d ' ') bytes): see \`$REPORT_REL\` in this PR's diff"
    else cat "$tp-r.$$"
    fi
  fi
  rm -f "$tp-h.$$" "$tp-b.$$" "$tp-r.$$"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  resolve) [ $# -ge 1 ] && [ $# -le 2 ] || usage; pl_resolve "$@" ;;
  gate)    [ $# -eq 4 ] || usage; pl_gate "$@" ;;
  dry-run) [ $# -eq 4 ] || usage; pl_dry_run "$@" ;;
  apply)   pl_apply "$@" ;;
  finish)  pl_finish "$@" ;;
  merge)   [ $# -eq 5 ] || usage; pl_merge "$@" ;;
  deliver)
    while [ "${1:-}" = --whole ]; do
      [ -n "${2:-}" ] || usage
      PL_WHOLE="$PL_WHOLE${PL_WHOLE:+
}$2"; shift 2
    done
    [ $# -eq 4 ] || usage; pl_deliver "$@" ;;
  record)
    [ $# -eq 4 ] || { [ $# -ge 6 ] && [ "$5" = -- ]; } || usage
    pl_record "$@" ;;
  pr-body) [ $# -eq 1 ] || usage; pl_pr_body "$@" ;;
  cut-from) [ $# -eq 2 ] || usage; pl_cut_from "$@" ;;
  *) usage ;;
esac
