#!/usr/bin/env bash
# deploy-validate-run.sh -- the scripted spine of steps/deploy-validate.md. Each subcommand does the
# mechanical part of one step and prints one verdict or record line per fact; the lead keeps the four
# judgments (red-smoke triage and fix dispatch, post-activation reads, 4b predicate discharge or
# re-deferral, "What Was Built" and "Decisions for You").
#
# usage: deploy-validate-run.sh <subcommand> [args]
#   enter                       the step-entry boundary write: current_step_file deploy-validate.md
#   record-merge <N> <pr-number> <pr-head> <squash>
#                               step 2: commit the sprint-PR merge record (HARD_BLOCK lines exit 1)
#   precheck <N>              step 1 (sprint-status check-stories --require-done) and step 1b (pre-staging
#                               audit: carry-over artifacts of s<N> committed before the tip commit)
#   freshness <unit> <built-digest> <running-digest> <rollout-epoch> <merge-epoch>
#                               step 2b: PASS only when the digests are equal and the rollout is after the merge
#   smoke <N> <first.xml> [<retry.xml>] [--no-action] [--attribution <text>]
#                               step 3: writes the four smoke_run_evidence fields from junit XML to
#                               <state>/implementation-artifacts/s<N>/smoke-record.txt and prints them.
#                               A first-run failure is transient only with <retry.xml> passing it AND
#                               --no-action (no action by the lead between the runs); else persistent.
#   quiet <attempts> <event-id|none>   step 3b: a zero-activity window never PASSes; PASS needs a controlled event
#   literals <deployed-sha> <literal>...   step 4b: PASS|FAIL per literal, git grep -F at that sha
#   cluster <N>                 step 5: the fix-forward enumeration after the sprint-PR squash, by subject, and its count
#   escalations                 step 5: counts of docs/escalations/pending.md entries by status token
#   coverage <N>                step 5: Locked-Requirement Coverage skeleton, one line per LOCKED_REQUIREMENTS bullet
#   pvc <N>                     step 5: the checkpoint skeleton from records; the lead writes the two marked blocks
#   route retro|next            step 7: the routing boundary writes
#
# BOUNDARY RECORDS THIS PROGRAM WRITES (the prose wrote them before it), all through snapshot-update.sh:
#   enter        --set current_step_file deploy-validate.md 'Pipeline Position'
#   route retro  --set current_step_file retro.md 'Pipeline Position'
#                --set last_completed_step_file deploy-validate.md 'Pipeline Position'
#   route next   --set current_step_file implementation.md 'Pipeline Position'
#                --set last_completed_step_file deploy-validate.md 'Pipeline Position'
#   smoke        <state>/implementation-artifacts/s<N>/smoke-record.txt
#   record-merge <state>/implementation-artifacts/s<N>/sprint-pr-merge.txt, committed on the current branch
# It writes no gate-log entry and no GATE_METRIC row; the gate-log entry stays Check 12's write.
#
# Exit: 0 every printed verdict is PASS or a record; 1 a FAIL verdict; 2 usage or an unreadable input.
set -u

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
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "deploy-validate-run: cannot resolve the project root from ${AI_DLC_SELF_DIR}; set AI_DLC_PROJECT_ROOT" >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
SELF_DIR="$AI_DLC_SELF_DIR"
cd "$AI_DLC_ROOT" || exit 2
STATE="${AI_DLC_STATE_DIR:-_bmad-output}"
SNAP="$SELF_DIR/snapshot-update.sh"
SSTATUS="$SELF_DIR/sprint-status.sh"

die() { echo "deploy-validate-run: $*" >&2; exit 2; }
num() { case "${1:-}" in ''|*[!0-9]*) die "'${1:-}' is not a sprint number" ;; esac; }

snap_set() {
  [ -f "$SNAP" ] || die "snapshot-update.sh is not beside this script"
  bash "$SNAP" --set "$1" "$2" 'Pipeline Position' || die "snapshot write failed: $1 $2"
  echo "RECORD: $1: $2"
}

# junit_fail_ids <file>: ids (classname::name, or name) of testcases carrying a failure or error child.
junit_fail_ids() {
  awk '
    function attr(tag, key,   m, re) {
      re = "[ \t]" key "=\"[^\"]*\""
      if (match(tag, re)) { m = substr(tag, RSTART + length(key) + 3, RLENGTH - length(key) - 4); return m }
      return ""
    }
    { buf = buf $0 "\n" }
    END {
      n = split(buf, parts, "<testcase")
      if (parts[1] ~ /<(failure|error)[ >\/]/) print "suite-level::error"
      for (i = 2; i <= n; i++) {
        seg = parts[i]
        e = index(seg, ">"); if (e == 0) continue
        tag = substr(seg, 1, e)
        if (substr(tag, length(tag) - 1, 1) == "/") { if (substr(seg, e + 1) ~ /<(failure|error)[ >\/]/) print "suite-level::error"; continue }
        close_at = index(seg, "</testcase>")
        if (close_at && substr(seg, close_at + 11) ~ /<(failure|error)[ >\/]/) print "suite-level::error"
        body = (close_at ? substr(seg, e + 1, close_at - e - 1) : substr(seg, e + 1))
        if (body ~ /<failure|<error/) {
          id = attr(tag, "name"); cn = attr(tag, "classname")
          if (cn != "") id = cn "::" id
          print id
        }
      }
    }' "$1" | sort -u
}

cmd_record_merge() {
  [ "$#" = 4 ] || die "record-merge <N> <pr-number> <pr-head> <squash>"
  num "$1"
  local rec="$STATE/implementation-artifacts/s$1/sprint-pr-merge.txt" row r_n r_h r_m
  row="$2 $3 $4"; r_n="$2"; r_h="$3"; r_m="$4"
  git fetch -q origin main
  if ! grep -qxE '[0-9]+ [0-9a-f]{40} [0-9a-f]{40}' <<<"$row"; then
    echo "RECORD: HARD_BLOCK malformed — want one line: PR number, 40-hex PR head, 40-hex squash commit"; exit 1
  elif ! git merge-base --is-ancestor "$r_m" origin/main 2>/dev/null; then
    echo "RECORD: HARD_BLOCK squash — $r_m is not on origin/main"; exit 1
  elif ! git cat-file -e "${r_h}^{commit}" 2>/dev/null; then
    echo "RECORD: HARD_BLOCK head — PR head $r_h is not a local commit"; exit 1
  elif [ "$(git show "HEAD:$rec" 2>/dev/null)" = "$row" ]; then
    echo "RECORD: PR #$r_n head $r_h squash $r_m already committed at $rec"
  elif mkdir -p "$(dirname "$rec")" && printf '%s\n' "$row" > "$rec" && git add -f -- "$rec" \
      && git commit -q -m "deploy-validate: sprint-merge record, PR #$r_n squash $r_m" -- "$rec"; then
    echo "RECORD: PR #$r_n head $r_h squash $r_m committed at $rec"
  else
    echo "RECORD: HARD_BLOCK write — $rec was not committed"; exit 1
  fi
}

cmd_enter() { snap_set current_step_file deploy-validate.md; }

cmd_route() {
  case "${1:-}" in
    retro) snap_set current_step_file retro.md ;;
    next)  snap_set current_step_file implementation.md ;;
    *) die "route takes retro or next" ;;
  esac
  snap_set last_completed_step_file deploy-validate.md
}

cmd_precheck() {
  num "${1:-}"; local n="$1" rc=0 base total touch tip_only
  if [ -f "$SSTATUS" ]; then
    bash "$SSTATUS" check-stories --require-done; rc=$?
    echo "CHECK-STORIES: exit $rc"
  else
    die "sprint-status.sh is not beside this script"
  fi
  base="$(git merge-base HEAD origin/main 2>/dev/null)" || base=""
  [ -n "$base" ] || { echo "PRESTAGING: NOT_EVALUATED no merge-base with origin/main"; [ "$rc" = 0 ] || exit 1; return 0; }
  total="$(git rev-list --count "$base..HEAD")"
  touch="$(git rev-list --count "$base..HEAD" -- "$STATE/implementation-artifacts/s$n")"
  tip_only=0
  if [ "$touch" = 1 ] && [ "$total" -gt 1 ] \
     && [ -n "$(git diff-tree --no-commit-id --name-only -r HEAD -- "$STATE/implementation-artifacts/s$n")" ]; then tip_only=1; fi
  if [ "$touch" -ge 1 ] && [ "$tip_only" = 0 ]; then
    echo "PASS prestaging: $touch of $total sprint commits touch $STATE/implementation-artifacts/s$n"
  else
    echo "FAIL prestaging: $touch of $total sprint commits touch $STATE/implementation-artifacts/s$n (none, or only the tip commit)"
    rc=1
  fi
  [ "$rc" = 0 ] || exit 1
}

cmd_freshness() {
  [ "$#" = 5 ] || die "freshness <unit> <built-digest> <running-digest> <rollout-epoch> <merge-epoch>"
  local unit="$1" built="$2" run="$3" roll="$4" merge="$5"
  case "$roll$merge" in *[!0-9]*|'') die "epochs must be integers" ;; esac
  [ -n "$built" ] && [ -n "$run" ] || die "an empty digest is not a freshness reading"
  if [ "$built" = "$run" ] && [ "$roll" -gt "$merge" ]; then
    echo "PASS freshness $unit: running digest equals built digest, rollout $roll after merge $merge"
  else
    echo "FAIL freshness $unit: built=$built running=$run rollout=$roll merge=$merge (smoke MUST NOT run; return to deploy)"
    exit 1
  fi
}

cmd_smoke() {
  num "${1:-}"; local n="$1" first="${2:-}" retry="" noact=0 attr=none a
  shift 2 2>/dev/null || die "smoke <N> <first.xml> [<retry.xml>] [--no-action] [--attribution <text>]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-action) noact=1 ;;
      --attribution) shift; attr="${1:-none}" ;;
      *) [ -z "$retry" ] && retry="$1" || die "unexpected argument '$1'" ;;
    esac
    shift
  done
  [ -r "$first" ] || die "first-run junit '$first' is not readable"
  [ -z "$retry" ] || [ -r "$retry" ] || die "retry junit '$retry' is not readable"
  local ff rf="" transient="" persistent="" id nf nt np out ntc
  ntc="$(grep -o '<testcase' "$first" | grep -c .)" || ntc=0
  [ "$ntc" -gt 0 ] || die "first-run junit '$first' holds 0 <testcase> elements: an empty or wrong file is not a smoke run (examined 0)"
  ff="$(junit_fail_ids "$first")"
  [ -z "$retry" ] || rf="$(junit_fail_ids "$retry")"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ "$noact" = 1 ] && [ -n "$retry" ] && ! grep -qxF -- "$id" <<<"$rf"; then
      transient="$transient$id
"
    else
      persistent="$persistent$id
"
    fi
  done <<<"$ff"
  nf="$(printf '%s' "$ff" | grep -c .)" || nf=0
  nt="$(printf '%s' "$transient" | grep -c .)" || nt=0
  np="$(printf '%s' "$persistent" | grep -c .)" || np=0
  [ "$nf" = $((nt + np)) ] || die "first_run_failures $nf != transient $nt + persistent $np"
  out="$STATE/implementation-artifacts/s$n/smoke-record.txt"
  mkdir -p "$(dirname "$out")" || die "cannot create $(dirname "$out")"
  {
    echo "first_run_failures: $nf"
    if [ "$nt" = 0 ]; then echo "transient_failures_cleared_on_retry: 0 none ${retry:-none}"
    else echo "transient_failures_cleared_on_retry: $nt $(printf '%s' "$transient" | paste -sd, -) cleared in ${retry}"; fi
    if [ "$np" = 0 ]; then echo "persistent_failures: none"
    else echo "persistent_failures: $(printf '%s' "$persistent" | paste -sd, -)"; fi
    echo "per_action_attribution: $attr"
  } > "$out" || die "cannot write $out"
  cat "$out"
  echo "RECORD: $out"
  echo "SMOKE: examined $ntc testcase(s) in $first"
  [ "$np" = 0 ] || { echo "RED smoke: $np persistent failure(s) enter the fix loop"; exit 1; }
}

cmd_quiet() {
  [ "$#" = 2 ] || die "quiet <attempts> <event-id|none>"
  case "$1" in ''|*[!0-9]*) die "attempts is a count" ;; esac
  if [ "$2" = none ] || [ -z "$2" ]; then
    echo "FAIL function-verification: no controlled or injected event; a zero-activity window is NOT_EVALUATED, never PASS"
    exit 1
  fi
  echo "PASS function-verification: controlled event $2 observed ($1 attempts in window)"
}

cmd_literals() {
  [ "$#" -ge 2 ] || die "literals <deployed-sha> <literal>..."
  local sha="$1" rc=0 lit; shift
  git cat-file -e "${sha}^{commit}" 2>/dev/null || die "deployed sha '$sha' is not a local commit"
  echo "deployed_sha: $sha"
  for lit in "$@"; do
    if git grep -qF -e "$lit" "$sha" -- 2>/dev/null; then echo "PASS literal: $lit"
    else echo "FAIL literal: $lit (correct the predicate old -> new, or re-defer)"; rc=1; fi
  done
  exit "$rc"
}

merge_squash() {
  local f="$STATE/implementation-artifacts/s$1/sprint-pr-merge.txt" row
  [ -r "$f" ] || die "$AI_DLC_ROOT/$f is absent: run the Step 2 merge record block first"
  row="$(head -n 1 "$f")"
  set -- $row
  [ "$#" = 3 ] || die "$f is not one line of three fields"
  printf '%s\n' "$3"
}

cmd_cluster() {
  num "${1:-}"; local sq cnt
  sq="$(merge_squash "$1")" || exit 2
  git fetch -q origin main 2>/dev/null
  git cat-file -e "${sq}^{commit}" 2>/dev/null || die "squash $sq is not a local commit"
  echo "Cluster members (commit subjects after $sq on origin/main, merges excluded):"
  git log --no-merges --format='- %h %s' "$sq..origin/main"
  cnt="$(git log --no-merges --format='%h' "$sq..origin/main" | grep -c .)" || cnt=0
  echo "Cluster count: $cnt (before the exclusions the lead records with PR and rationale)"
}

cmd_escalations() {
  local f="docs/escalations/pending.md" t c
  [ -r "$f" ] || { echo "ESCALATIONS: $f absent: all counts 0"; return 0; }
  for t in DECIDED_AUTONOMOUSLY DEFERRAL_REQUEST OPERATOR_DECISION HARD_BLOCK; do
    c="$(grep -cE "^\*\*Status:\*\* $t([^A-Z_]|$)" "$f")" || c=0
    echo "$t entries: $c"
  done
}

cmd_coverage() {
  num "${1:-}"; local f="$STATE/planning-artifacts/s$1/locked-requirements.md"
  if [ ! -r "$f" ]; then echo "- no locked-requirements.md for this sprint: none recorded"; return 0; fi
  local anchor="$SELF_DIR/validate-locked-anchor.sh" blocks
  [ -f "$anchor" ] || die "validate-locked-anchor.sh is not beside this script"
  blocks="$(bash "$anchor" "$f" --emit-blocks)" || die "$f: LOCKED_REQUIREMENTS blocks could not be read"
  grep '^- ' <<<"$blocks" | awk '{print "- " substr($0,3) ": <kind>: <delivered|deferred|descoped|phased|partial> - <evidence>"}'
}

cmd_pvc() {
  num "${1:-}"; local n="$1" rec="$STATE/implementation-artifacts/s$1/smoke-record.txt"
  echo "## Production Validation Checkpoint"
  echo
  echo "### What Was Built"
  echo "<<LEAD WRITES>>"
  echo
  echo "### Deployment"
  if [ -r "$rec" ]; then sed 's/^/- /' "$rec"; else echo "- smoke record absent: run the smoke subcommand"; fi
  echo
  echo "### Fix-Forward Cluster"
  cmd_cluster "$n"
  echo
  echo "### Escalation Log"
  cmd_escalations
  echo
  echo "### Locked-Requirement Coverage"
  cmd_coverage "$n"
  echo
  echo "### Decisions for You"
  echo "<<LEAD WRITES>>"
}

sub="${1:-}"; [ $# -gt 0 ] && shift
case "$sub" in
  enter) cmd_enter ;;
  record-merge) cmd_record_merge "$@" ;;
  route) cmd_route "$@" ;;
  precheck) cmd_precheck "$@" ;;
  freshness) cmd_freshness "$@" ;;
  smoke) cmd_smoke "$@" ;;
  quiet) cmd_quiet "$@" ;;
  literals) cmd_literals "$@" ;;
  cluster) cmd_cluster "$@" ;;
  escalations) cmd_escalations ;;
  coverage) cmd_coverage "$@" ;;
  pvc) cmd_pvc "$@" ;;
  *) sed -n '2,24p' "$0" >&2; exit 2 ;;
esac
