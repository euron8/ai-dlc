#!/usr/bin/env bash
# retro-close.sh <subcommand> ... -- the retro step's mutations and close, one program.
#
#   merge <pr>                       7a: merge the retro PR, then read its state from GitHub
#   land                             7a-post: land on the merged trunk
#   archive-backlog <ids-file>       4a: move the listed carry-over entries to the archive, byte-verified
#   archive-escalations <ids-file>   4a: move the listed escalation entries to the archive, byte-verified
#   sprint-close <N> <evidence>      4a: close the sprint-status envelope (sprint-status.sh close)
#   anchor <N>                       5b: re-seed the audit-anchors header, append the PENDING entry, prune to 3
#   commit <N>                       6a: one commit of every tracked change, every DURABLE pipeline path and the
#                                    retro, review and escalation documents
#   finish <N> <pr> [--commentary-file <f>]
#                                    after 7a merged and `land` succeeded: operator-commentary amendment, retro
#                                    scratch removal, gate-log / compaction-log / gate-adjudication rotation,
#                                    audit-anchor SHA backfill, terminal snapshot, then ONE push of main
#
# <ids-file>: one id per line; an entry moves when its heading line carries the id as a whole token.
#
# BOUNDARY RECORDS it writes (the ones the prose wrote before it):
#   finish: snapshot `## Pipeline Position` current_step_file=retro.md and last_completed_step_file=
#           'retro.md (sprint <N> closed — retro PR merged, records rotated)', routing-record keys dropped
#           (snapshot-update.sh); gate-log.md -> s<N>/gate-log-archive.md with a fresh `# Gate Log` header;
#           compaction-log.md -> s<N>/compaction-log-archive.md; gate-adjudication verdicts rotated
#           (rotate-gate-adjudication.sh --apply); audit-anchors.md sha backfilled.
#   sprint-close: the sprint-status envelope and `sprint_<N>_housekeeping:` block (sprint-status.sh close).
#   anchor: the audit-anchors.md entry and its archive.
# It writes NO gate-log entry and no GATE_METRIC row: Check 12 writes the gate entry.
#
# exit: 0 done; 2 a refusal that wrote nothing further (a HARD_BLOCK line names it); 3 a no-loss check or a
#       sibling program failed; 64 bad usage.
# Locates siblings beside itself; works from core/scripts/ and scripts/ai-dlc/. Resolves the repository root by walking
# up for a marker and runs there from any working directory; AI_DLC_STATE_DIR names the state directory; a relative
# file argument (ids file, commentary file) is read against the caller's directory.

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. Inline on purpose: a shared lib cannot fix this, because locating the lib is the
# same unsolved problem. core/fixtures/validator-path-resolution asserts the layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "retro-close: cannot resolve the project root from ${AI_DLC_SELF_DIR}; set AI_DLC_PROJECT_ROOT" >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
RC_HERE="${BASH_SOURCE[0]:-$0}"
RC_DIR="$AI_DLC_SELF_DIR"
RC_CALLER_PWD="$(pwd)"
cd "$AI_DLC_ROOT" || exit 2
SD="${AI_DLC_STATE_DIR:-_bmad-output}"
# rc_abs <path>: a relative path argument names a file under the caller's directory, not the repository root.
rc_abs() { case "$1" in ''|/*) printf '%s' "$1" ;; *) printf '%s/%s' "$RC_CALLER_PWD" "$1" ;; esac; }
IA="$SD/implementation-artifacts"

rc_die() { echo "retro-close: $*" >&2; exit "${RC_EXIT:-2}"; }

# retro 7a: merge the retro PR, then read its state from GitHub
cmd_merge() {
  local pr="$1" MERGE_RC PR_STATE
  gh pr merge "$pr" --squash --delete-branch; MERGE_RC=$?
  PR_STATE="$(gh pr view "$pr" --json state --jq .state)" || PR_STATE=""
  if [ "$PR_STATE" = MERGED ] && [ "$MERGE_RC" = 0 ]; then
    echo "MERGE: merged"
  elif [ "$PR_STATE" = MERGED ]; then
    echo "MERGE: merged — gh's local cleanup failed; 7a-post lands explicitly"
  else
    echo "MERGE: HARD_BLOCK failed — ${PR_STATE:-state unreadable}"
    return 1
  fi
}

# retro 7a-post step 1: land on the merged trunk
cmd_land() {
git fetch origin main
LAND_HOLD="$( cd "$(git rev-parse --show-toplevel)" || exit
  { git rev-parse -q --verify refs/heads/main >/dev/null && git diff -z --name-only --no-renames HEAD main
    git diff -z --name-only --no-renames HEAD origin/main; } | sort -zu |
  while IFS= read -r -d '' p; do
    if ! git cat-file -e "HEAD:$p" 2>/dev/null && { [ -e "$p" ] || [ -L "$p" ]; }; then echo "ON-DISK $p"; fi
  done )"
if [ -n "$LAND_HOLD" ]; then
  echo "LAND: HARD_BLOCK on-disk — main at origin/main tracks these paths, HEAD does not, and a file is on disk at each; move each aside and re-run the block"
  printf '%s\n' "$LAND_HOLD"
  return 1
elif git fetch origin main && git checkout main && git merge --ff-only origin/main \
    && [ "$(git symbolic-ref -q --short HEAD)" = main ]; then
  echo "LAND: main at origin/main"
else
  MAIN_WT="$(git worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} $0=="branch refs/heads/main"{print w}')"
  SELF_WT="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
  [ -n "$MAIN_WT" ] && [ "$(cd "$MAIN_WT" 2>/dev/null && pwd -P)" = "$SELF_WT" ] && MAIN_WT=""
  echo "LAND: HARD_BLOCK — not on main at origin/main; main is checked out in worktree: ${MAIN_WT:-none}"
  return 1
fi
}

# archive_entries <label> <live> <archive> <heading-level 2|3> <ids-file>: move whole entries, verbatim,
# and refuse unless live + moved reproduces the original line for line.
archive_entries() {
  local label="$1" live="$2" arch="$3" lvl="$4" ids="$5" tmp moved before after
  [ -f "$ids" ] || { echo "ARCHIVE: HARD_BLOCK $label — ids file $ids is absent"; return 2; }
  [ -s "$ids" ] || { echo "ARCHIVE: $label — empty id list, nothing moved"; return 0; }
  [ -f "$live" ] || { echo "ARCHIVE: $label — $live is absent, nothing moved"; return 0; }
  tmp="$RC_TMP"; [ -n "$tmp" ] || { echo "ARCHIVE: HARD_BLOCK $label — mktemp failed"; return 2; }
  awk -v lvl="$lvl" -v ids="$ids" -v keep="$tmp/keep" -v out="$tmp/moved" '
    BEGIN { while ((getline l < ids) > 0) if (l != "") want[l] = 1; mv = 0 }
    {
      if ($0 ~ /^#+ /) {
        h = $0; n = 0; while (substr(h, n + 1, 1) == "#") n++
        if (n <= lvl) {
          mv = 0
          if (n == lvl) {
            t = substr(h, n + 2); gsub(/[^A-Za-z0-9_.-]+/, " ", t); c = split(t, w, " ")
            for (i = 1; i <= c; i++) if (w[i] in want) { mv = 1; break }
          }
        }
      }
      if (mv) print > out; else print > keep
    }' "$live"
  [ -f "$tmp/keep" ] || : > "$tmp/keep"
  [ -f "$tmp/moved" ] || : > "$tmp/moved"
  moved="$(grep -c '' "$tmp/moved")"
  before="$(sort "$live" | cksum)"
  after="$(cat "$tmp/keep" "$tmp/moved" | sort | cksum)"
  if [ "$before" != "$after" ] || [ "$(( $(wc -c < "$tmp/keep") + $(wc -c < "$tmp/moved") ))" != "$(( $(wc -c < "$live") ))" ]; then
    echo "ARCHIVE: HARD_BLOCK $label — live plus moved does not reproduce $live; nothing written"
    return 3
  fi
  if [ "$moved" = 0 ]; then echo "ARCHIVE: $label — no listed id matched a heading, nothing moved"; return 0; fi
  [ -f "$arch" ] || { mkdir -p "${arch%/*}" && : > "$arch"; }
  cat "$tmp/moved" >> "$arch" && cat "$tmp/keep" > "$live" || { echo "ARCHIVE: HARD_BLOCK $label — write failed"; return 3; }
  echo "ARCHIVE: $label — moved $moved line(s) to $arch"
}

cmd_sprint_close() {
  local n="$1" ev="$2" ss="$RC_DIR/sprint-status.sh"
  [ -f "$ss" ] || rc_die "sprint-status.sh not found beside $RC_HERE"
  bash "$ss" close --evidence "$ev" --retro-doc "docs/retro/s${n}/retro.md" || { echo "SPRINT-CLOSE: HARD_BLOCK sprint-status.sh close refused"; return 3; }
  echo "SPRINT-CLOSE: sprint $n envelope closed"
}

cmd_anchor() {
  local n="$1" f="$SD/audit-anchors.md" va="$RC_DIR/validate-audit-anchors.sh" tmp hdr pre post
  [ -f "$va" ] || rc_die "validate-audit-anchors.sh not found beside $RC_HERE"
  tmp="$RC_TMP"; [ -n "$tmp" ] || rc_die "mktemp failed"
  hdr="$tmp/header"
  bash "$va" --render > "$hdr" || rc_die "validate-audit-anchors.sh --render failed"
  if [ ! -f "$f" ]; then
    { cat "$hdr"; printf '\n## Entries\n\n```yaml\n```\n'; } > "$f"
  elif ! grep -q '^<!-- BEGIN GENERATED: audit-anchors-schema' "$f"; then
    { cat "$hdr"; printf '\n'; cat "$f"; } > "$tmp/seeded" && cat "$tmp/seeded" > "$f"
  else
    awk -v h="$hdr" '
      /^<!-- BEGIN GENERATED: audit-anchors-schema/ { while ((getline l < h) > 0) print l; skip = 1; next }
      skip && /^<!-- END GENERATED: audit-anchors-schema/ { skip = 0; next }
      !skip { print }' "$f" > "$tmp/seeded" && cat "$tmp/seeded" > "$f"
  fi
  if grep -q "^- sprint: ${n}\$" "$f"; then echo "ANCHOR: sprint $n already has an entry"; else
    awk -v n="$n" '
      { lines[NR] = $0 }
      END {
        last = 0; for (i = 1; i <= NR; i++) if (lines[i] ~ /^```/) last = i
        if (!last) { for (i = 1; i <= NR; i++) print lines[i]; print "```yaml"; print "- sprint: " n; print "  sha: PENDING"; print "  closed_at: PENDING"; print "```"; exit }
        for (i = 1; i <= NR; i++) {
          if (i == last) { print "- sprint: " n; print "  sha: PENDING"; print "  closed_at: PENDING" }
          print lines[i]
        }
      }' "$f" > "$tmp/appended" && cat "$tmp/appended" > "$f"
    echo "ANCHOR: sprint $n entry appended"
  fi
  # prune: keep the 3 most recent entries, move older ones verbatim to the archive, no loss.
  pre="$(grep -c '^- sprint: ' "$f")"
  awk -v keepfile="$tmp/live-entries" -v movefile="$tmp/old-entries" '
    { lines[NR] = $0 }
    END {
      total = 0; for (i = 1; i <= NR; i++) if (lines[i] ~ /^- sprint: /) { total++; start[total] = i }
      cut = total - 3; if (cut < 0) cut = 0
      for (i = 1; i <= NR; i++) {
        if (cut > 0 && i >= start[1] && i < start[cut + 1]) print lines[i] > movefile
        else print lines[i] > keepfile
      }
    }' "$f"
  if [ -f "$tmp/old-entries" ]; then
    local arch="$SD/audit-anchors-archive.md"
    [ -f "$arch" ] || printf '# Audit Anchors — Archive\n' > "$arch"
    cat "$tmp/old-entries" >> "$arch"
    cat "$tmp/live-entries" > "$f"
    post="$(( $(grep -c '^- sprint: ' "$f") + $(grep -c '^- sprint: ' "$tmp/old-entries") ))"
    if [ "$post" != "$pre" ]; then echo "ANCHOR: HARD_BLOCK prune lost entries (live+moved $post, before $pre); restore from git"; return 3; fi
    echo "ANCHOR: pruned $(grep -c '^- sprint: ' "$tmp/old-entries") entr(ies) to $arch"
  fi
  bash "$va" "$f" || { echo "ANCHOR: HARD_BLOCK validate-audit-anchors.sh refused $f"; return 3; }
}

durable_paths() {
  local schema="" c root top names nm
  top="$(git rev-parse --show-toplevel)" || return 2
  for c in "$top/.claude/schemas/pipeline-state-paths.json" "$top/core/schemas/pipeline-state-paths.json"; do
    [ -f "$c" ] && { schema="$c"; break; }
  done
  [ -n "$schema" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2
  root="$(jq -r '.root // empty' "$schema")" || return 2
  [ -n "$root" ] || return 2
  [ "$root" = "_bmad-output" ] && root="$SD"
  names="$(jq -r '.paths[] | select(.transient == false) | .name' "$schema")" || return 2
  while IFS= read -r nm; do
    [ -n "$nm" ] && printf '%s/%s\n' "$root" "$nm"
  done <<<"$names"
  return 0
}

cmd_commit() {
  local n="$1" p dp
  dp="$(durable_paths)" || { echo "COMMIT: HARD_BLOCK under $AI_DLC_ROOT: pipeline-state-paths.json or jq unavailable — the durable set cannot be derived"; return 2; }
  [ -n "$dp" ] || { echo "COMMIT: HARD_BLOCK the durable path set is empty"; return 2; }
  git add -u
  while IFS= read -r p; do [ -e "$p" ] && git add -A -- "$p"; done <<<"$dp"
  for p in docs/retro docs/reviews docs/escalations docs/ai-dlc-feedback.md; do [ -e "$p" ] && git add -A -- "$p"; done
  if git diff --cached --quiet; then echo "COMMIT: none — nothing to commit"; return 0; fi
  git commit -q -m "docs(retro): sprint ${n} retrospective, reviews, and process improvements" || { echo "COMMIT: HARD_BLOCK git commit refused"; return 3; }
  echo "COMMIT: $(git rev-parse HEAD)"
}

rotate_one() { # <live> <archive> <header-or-empty> [<sprint N: prepend a span line when the log holds earlier sprints>] -> no-loss rotation, skipped when already rotated
  local live="$1" arch="$2" hdr="$3" span_n="${4:-}" before first line
  if [ ! -f "$live" ]; then echo "ROTATE: $live absent — nothing to rotate"; return 0; fi
  if [ -f "$arch" ] && [ "$(cat "$live")" = "$hdr" ]; then
    echo "ROTATE: $live already rotated to $arch"; return 0
  fi
  if [ -f "$arch" ]; then
    echo "ROTATE: HARD_BLOCK $arch already exists and $live is live — rotate by hand, never overwrite"; return 3
  fi
  before="$(( $(wc -c < "$live") ))"
  mkdir -p "${arch%/*}" || return 3
  git mv "$live" "$arch" 2>/dev/null || mv "$live" "$arch" || { echo "ROTATE: HARD_BLOCK move of $live failed"; return 3; }
  if [ -n "$span_n" ]; then
    first="$(grep -o 'Gate Log: Sprint [0-9][0-9]*' "$arch" | grep -o '[0-9][0-9]*$' | sort -n | head -1)"
    if [ -n "$first" ] && [ "$first" -lt "$span_n" ]; then
      line="<!-- covers s${first}..s${span_n} -->"
      { printf '%s\n' "$line"; cat "$arch"; } > "$arch.tmp" && cat "$arch.tmp" > "$arch" && rm -f "$arch.tmp" || { echo "ROTATE: HARD_BLOCK span line write failed"; return 3; }
      before=$((before + ${#line} + 1))
    fi
  fi
  if [ -n "$hdr" ]; then printf '%s\n' "$hdr" > "$live"; else : > "$live"; fi
  if [ "$(( $(wc -c < "$arch") ))" != "$before" ]; then echo "ROTATE: HARD_BLOCK $arch holds $(( $(wc -c < "$arch") )) bytes, $live held $before; restore from git"; return 3; fi
  if [ -n "$hdr" ] && [ "$(cat "$live")" != "$hdr" ]; then echo "ROTATE: HARD_BLOCK new $live is not only its header"; return 3; fi
  echo "ROTATE: $live -> $arch ($before bytes verified)"
}

cmd_finish() {
  local n="$1" pr="$2" cf="${3:-}" sha snap f routing
  [ "$(git symbolic-ref -q --short HEAD)" = main ] || { echo "FINISH: HARD_BLOCK not on main; run land first"; return 2; }
  git merge-base --is-ancestor origin/main HEAD 2>/dev/null || { echo "FINISH: HARD_BLOCK main lacks origin/main; run land first"; return 2; }
  sha="$(git rev-parse HEAD)"
  # operator-commentary amendment: its own commit
  if [ -n "$cf" ]; then
    [ -s "$cf" ] || { echo "FINISH: HARD_BLOCK commentary file $cf is absent or empty"; return 2; }
    if ! grep -q "retro-commentary-amendment s${n}" "docs/retro/s${n}/retro.md" 2>/dev/null; then
      { printf '\n<!-- retro-commentary-amendment s%s -->\n## Operator Commentary\n\n' "$n"; cat "$cf"; } >> "docs/retro/s${n}/retro.md"
      git add -- "docs/retro/s${n}/retro.md" && git commit -q -m "docs(retro): s${n} operator commentary" || { echo "FINISH: HARD_BLOCK commentary commit refused"; return 3; }
      echo "FINISH: operator commentary committed"
    fi
  fi
  # retro scratch: every reader has returned
  STATE_DIR="$SD"
  if [ -n "$STATE_DIR" ] && [ "$STATE_DIR" != "/" ] && [ -d "$STATE_DIR" ]; then rm -rf -- "${STATE_DIR}/retro-artifacts"; fi
  # rotation of the merge-sensitive records
  rotate_one "$IA/gate-log.md" "$IA/s${n}/gate-log-archive.md" "# Gate Log" "$n" || return $?
  rotate_one "$SD/compaction-log.md" "$IA/s${n}/compaction-log-archive.md" "" || return $?
  if [ -f "$RC_DIR/rotate-gate-adjudication.sh" ]; then
    bash "$RC_DIR/rotate-gate-adjudication.sh" --sprint "s${n}" --apply || { echo "FINISH: HARD_BLOCK rotate-gate-adjudication.sh refused; apply its printed remedy and re-run finish"; return 3; }
  else
    echo "FINISH: HARD_BLOCK rotate-gate-adjudication.sh not found beside $RC_HERE"; return 2
  fi
  for f in "$IA/gate-log.md" "$IA/s${n}/gate-log-archive.md" "$SD/compaction-log.md" "$IA/s${n}/compaction-log-archive.md" "$SD/gate-adjudication" "$IA/s${n}/gate-adjudication"; do
    [ -e "$f" ] && git add -A -- "$f"
  done
  if ! git diff --cached --quiet; then
    git commit -q -m "chore(s${n}): rotate gate-log, compaction-log and gate-adjudication post-retro-merge" || { echo "FINISH: HARD_BLOCK rotation commit refused"; return 3; }
    echo "FINISH: rotation committed"
  fi
  # audit-anchor backfill: its own commit, nothing else in it
  f="$SD/audit-anchors.md"
  if [ -f "$f" ] && grep -q "^- sprint: ${n}\$" "$f"; then
    awk -v n="$n" -v sha="$sha" -v when="$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
      $0 == "- sprint: " n { inb = 1; print; next }
      inb && /^- sprint: / { inb = 0 }
      inb && /^  sha: PENDING/ { print "  sha: " sha; next }
      inb && /^  closed_at: PENDING/ { print "  closed_at: " when; next }
      { print }' "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
    git add -- "$f"
    if ! git diff --cached --quiet; then
      git commit -q -m "chore(s${n}): backfill audit-anchor SHA after retro PR #${pr} merge" || { echo "FINISH: HARD_BLOCK anchor commit refused"; return 3; }
      echo "FINISH: audit-anchor backfilled with $sha"
    fi
  else
    echo "FINISH: no audit-anchors entry for sprint $n — the anchor step did not run"
  fi
  # terminal Pipeline Position
  snap="$RC_DIR/snapshot-update.sh"
  [ -f "$snap" ] || { echo "FINISH: HARD_BLOCK snapshot-update.sh not found beside $RC_HERE"; return 2; }
  bash "$snap" --set current_step_file retro.md 'Pipeline Position' \
    --set last_completed_step_file "retro.md (sprint ${n} closed — retro PR merged, records rotated)" 'Pipeline Position' \
    || { echo "FINISH: HARD_BLOCK terminal snapshot write refused"; return 3; }
  for routing in user_request_verbatim user_request_cite bug_signal_present carryover_or_sprint_signal_present clarification_asked scope_confirmed scope_confirmed_cite; do
    if grep -q "^- ${routing}:" "$SD/pipeline-snapshot.md" 2>/dev/null; then
      bash "$snap" --key-delete 'Pipeline Position' "$routing" || { echo "FINISH: HARD_BLOCK dropping $routing refused"; return 3; }
    fi
  done
  git add -- "$SD/pipeline-snapshot.md" "$SD/pipeline-snapshot-history.md" 2>/dev/null
  if ! git diff --cached --quiet; then
    git commit -q -m "chore(s${n}): finalize snapshot — sprint ${n} closed" || { echo "FINISH: HARD_BLOCK snapshot commit refused"; return 3; }
    echo "FINISH: terminal snapshot committed"
  fi
  git push origin main || { echo "FINISH: HARD_BLOCK push refused — read the hook output; never --no-verify"; return 3; }
  echo "FINISH: sprint ${n} closed and pushed"
}

sub="${1:-}"
RC_TMP=""
case "$sub" in
  archive-backlog|archive-escalations|anchor)
    RC_TMP="$(mktemp -d)" && trap 'rm -rf "$RC_TMP"' EXIT ;;
esac
case "$sub" in
  merge)               [ -n "${2:-}" ] || rc_die "usage: merge <pr>"; RC_EXIT=64; cmd_merge "$2"; exit $? ;;
  land)                cmd_land; exit $? ;;
  archive-backlog)     archive_entries backlog "$SD/planning-artifacts/carry-over-backlog.md" "$SD/planning-artifacts/carry-over-backlog-archive.md" 3 "$(rc_abs "${2:-/nonexistent}")"; exit $? ;;
  archive-escalations) archive_entries escalations docs/escalations/pending.md docs/escalations/pending-archive.md 2 "$(rc_abs "${2:-/nonexistent}")"; exit $? ;;
  sprint-close)        [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "usage: sprint-close <N> <evidence>" >&2; exit 64; }; cmd_sprint_close "$2" "$3"; exit $? ;;
  anchor)              [ -n "${2:-}" ] || { echo "usage: anchor <N>" >&2; exit 64; }; cmd_anchor "$2"; exit $? ;;
  commit)              [ -n "${2:-}" ] || { echo "usage: commit <N>" >&2; exit 64; }; cmd_commit "$2"; exit $? ;;
  finish)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "usage: finish <N> <pr> [--commentary-file <f>]" >&2; exit 64; }
    if [ "${4:-}" = "--commentary-file" ]; then cmd_finish "$2" "$3" "$(rc_abs "${5:-}")"; else cmd_finish "$2" "$3"; fi
    exit $? ;;
  *) echo "usage: retro-close.sh merge|land|archive-backlog|archive-escalations|sprint-close|anchor|commit|finish ..." >&2; exit 64 ;;
esac
