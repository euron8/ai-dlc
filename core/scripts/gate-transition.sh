#!/usr/bin/env bash
# gate-transition.sh -- run, in the step files' order, every check one implementation gate
# prescribes for one story, and write the gate PLAN only once all of them have passed.
#
# usage:
#   gate-transition.sh <story-index> 1|2|3|close [--pass M] -C <worktree> --base <sha>
#                      --sprint <N> --story-file <path> [--transcript-dir <dir>]
#   gate-transition.sh -h|--help
#
#   <story-index>   the index every shard brief names (`shard: 1/1 <story-index>`), byte for byte.
#   1, 2, 3, close  the gate. `close` is the closing writer's transition (below).
#   --pass M        the review or validation pass, default 1. Pass M >= 2 is a re-review.
#   -C <worktree>   the frozen dev worktree. The frozen sha is its HEAD, resolved in full.
#   --base <sha>    the two-dot base gate 1 used (the gate-1 manifest's `base`).
#   --sprint <N>    the sprint, for docs/reviews/s<N>/ and the gate-3 arms. Passed, never read
#                   out of the snapshot: the snapshot sprint_id reader is one expression held in
#                   three copies by invariant I104, and this script does not grow a fourth.
#   --story-file    the story file, relative to the worktree top. The same path under the
#                   project root is the canonical sprint-branch copy the DAR-fold preflight reads.
#   --transcript-dir  gate 3 only: the directory this session's transcript sits in (Check 2a).
#
# WHAT IT RUNS, PER GATE, IN THE STEP FILES' ORDER (steps/implementation.md, gate-validation.md):
#   gate 1   commit presence (base..sha has a non-merge commit); validate-handoff-evidence.sh
#            handoff mode, then --strategy; --list-captures (exit 2: partition without
#            --exclude-captures, the line recorded); pass M >= 2: --route, then --narrow and the
#            narrowed map with its two fallbacks; partition-review-diff.sh --map;
#            pass M >= 2: validate-carried-findings.sh --list.
#   gate 2   --list-captures at the go-signal sha; pass M >= 2: --gate1-rerun from the prior QA
#            pass's reviewed-sha (GATE1-RERUN or any refusal stops here and writes a `gate: rerun`
#            plan with no shard lines, which authorizes no seat -- the lead runs the plan's `next:` gate-1 command); the DAR-fold preflight,
#            VERIFIED and never performed; handoff --gate2; --smoke; pass M >= 2: --route;
#            --map; merge-review-shards.sh --record-partition, AFTER --map and only when --map
#            wrote a manifest; pass M >= 2: the carried-findings list.
#   gate 3   the script arms of gate-validation.md "Script arms before the adjudicator": Check 2
#            (vocabulary, suppression lifetimes), 2a, 5 (check-stories, derive-stories --check),
#            16, 17's implementation fold arm, 22, 25 (--count, recorded for the lead, who compares
#            it) and H2 --verify; then the nonce is minted and gate-checkpoint.sh open runs. `open`
#            runs at gate 3 ONLY: it writes the one global OPEN marker, and a gate 1 or 2 that
#            opened would overwrite a live gate 3. Check 26 needs the adjudicator's verdict and
#            is not run here.
#   close    verifies that the story's last gate-3 ledger carries a `26 PASS` row, read through
#            gate-checkpoint.sh list, and writes a close plan. It never calls open. The nonce is the
#            newest g3 plan's, else the newest gate-adjudication verdict whose gate_series_id
#            carries this story's slug and sprint (gate-validation.md, the series id), else the
#            newest whose gate_series_id is the storyless `implementation-s<N>-<TS>` (a multi-story
#            gate 3); that plan carries a `gate3-scope:` line, since no verdict field names a story.
#
# THE PLAN. `_bmad-output/implementation-artifacts/s<N>/gate-transition/<idx>-g<gate>-p<M>.plan`
# under the project root, `gclose` for close. It lives in a declared area with the sprint in the
# directory only, never in the basename (artifact-path-grammar.md, held by I82 and I82b). Any plan already at that path is removed BEFORE the first
# check, and the new one is written only after every check has passed, through a temporary file
# and mv. So a plan on disk is a completion record. Lines, in order:
#   story: <idx> / gate: <1|2|3|rerun|close> / pass: <M> / sha: <frozen sha> / worktree: <abs> /
#   manifest: <shard-dir>/.manifest, or none / route: <kind> <answer line> / nonce: <gate_nonce>
#   (gate 3 and close only) / the --map stdout lines, byte-equal / the brief inputs, each
#   `<key>: <value>`.
#
# exit:
#   0  every check passed; the plan is written and its path printed on stdout
#   1  a REFUSAL: each refused check is printed on stderr with its remedy, and no plan exists
#   2  it could not run: bad usage, a missing sibling script, an unresolvable root or worktree

set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
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
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

ROOT="$AI_DLC_ROOT"
SELF="$AI_DLC_SELF_DIR"
USAGE='usage: gate-transition.sh <story-index> 1|2|3|close [--pass M] -C <worktree> --base <sha> --sprint <N> --story-file <path> [--transcript-dir <dir>]'
die() { printf 'gate-transition: %s\n' "$1" >&2; exit 2; }

IDX=""; GATE=""; PASS=1; WT=""; BASE=""; SPRINT=""; STORY=""; TDIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,/^set -uo/p' "$0" | sed '$d'; exit 0 ;;
    --pass) [ "$#" -ge 2 ] || die "$USAGE"; PASS="$2"; shift 2 ;;
    -C) [ "$#" -ge 2 ] || die "$USAGE"; WT="$2"; shift 2 ;;
    --base) [ "$#" -ge 2 ] || die "$USAGE"; BASE="$2"; shift 2 ;;
    --sprint) [ "$#" -ge 2 ] || die "$USAGE"; SPRINT="$2"; shift 2 ;;
    --story-file) [ "$#" -ge 2 ] || die "$USAGE"; STORY="$2"; shift 2 ;;
    --transcript-dir) [ "$#" -ge 2 ] || die "$USAGE"; TDIR="$2"; shift 2 ;;
    -*) die "unknown flag $1. $USAGE" ;;
    *) if [ -z "$IDX" ]; then IDX="$1"; elif [ -z "$GATE" ]; then GATE="$1"; else die "unexpected argument $1. $USAGE"; fi; shift ;;
  esac
done
case "$GATE" in 1|2|3|close) ;; *) die "the gate must be 1, 2, 3 or close. $USAGE" ;; esac
case "$IDX" in '' | -* | *[!A-Za-z0-9_.-]*) die "story index '$IDX' is not one path component of letters, digits, '.', '_' and '-'. $USAGE" ;; esac
case "$PASS" in '' | *[!0-9]* | 0) die "--pass takes a positive integer. $USAGE" ;; esac
case "$SPRINT" in '' | *[!0-9]*) die "--sprint takes the sprint number. $USAGE" ;; esac

STATE_DIR="${ROOT}/${AI_DLC_STATE_DIR:-_bmad-output}"
PDIR="${ROOT}/_bmad-output/implementation-artifacts/s${SPRINT}/gate-transition"
GKEY="$GATE"; [ "$GATE" = close ] && GKEY=close
PLAN="${PDIR}/${IDX}-g${GKEY}-p${PASS}.plan"
# A stale plan is removed BEFORE any check, so a refusal below can never leave one standing. That
# includes the exit-2 refusals that follow: the plan's path needs only the story, gate, pass and
# sprint, all validated above, so no later exit, refusal or could-not-run, can leave an older plan.
rm -f "$PLAN"
[ -n "$WT" ] && [ -n "$BASE" ] && [ -n "$STORY" ] || die "$USAGE (no plan stands at $PLAN)"
WT_ARG="$WT"
WT="$(cd "$WT" 2> /dev/null && pwd)" || die "worktree $WT_ARG is not a directory; no plan stands at $PLAN"
SHA="$(git -C "$WT" rev-parse -q --verify 'HEAD^{commit}' 2> /dev/null)" || die "git names no HEAD commit in $WT; no plan stands at $PLAN"
[ "$GATE" != 3 ] || [ -n "$TDIR" ] || die "gate 3 needs --transcript-dir: Check 2a verifies operator citations against that corpus; no plan stands at $PLAN. $USAGE"
for s in validate-handoff-evidence.sh partition-review-diff.sh merge-review-shards.sh validate-carried-findings.sh gate-checkpoint.sh verdict.sh validate-escalation-resolution.sh sprint-status.sh validate-stub-audit.sh validate-spawn-ledger.sh validate-provenance-block.sh validate-steering-budget.sh validate-h2-attestation.sh; do
  [ -f "$SELF/$s" ] || die "$s is not beside this script at $SELF; reinstall the engine (no plan stands at $PLAN)"
done

mkdir -p "$PDIR" || die "cannot create $PDIR"
W="${PLAN}.work.$$"
CAP="${PDIR}/${IDX}-g${GKEY}-p${PASS}.captures"
cleanup() { rm -f "$W.out" "$W.err" "$W.map" "$W.carried" "$W.inputs" "$W.dar1" "$W.dar2" "$W.story" "$W.plan"; }
trap cleanup EXIT

NREF=0
refuse() { # <check> <detail> <remedy>
  NREF=$((NREF + 1))
  printf 'gate-transition: REFUSED %s: %s\n  remedy: %s\n' "$1" "$2" "$3" >&2
}
stop_if_refused() {
  [ "$NREF" -eq 0 ] && return 0
  printf 'gate-transition: %d refusal(s); no plan written (%s)\n' "$NREF" "$PLAN" >&2
  exit 1
}
: > "$W.inputs"
input() { printf '%s: %s\n' "$1" "$2" >> "$W.inputs"; }
# run <sibling> <args...>: the sibling under bash, stdout to $W.out, stderr to $W.err, status in RC.
run() { local s="$1"; shift; bash "$SELF/$s" "$@" > "$W.out" 2> "$W.err" < /dev/null; RC=$?; }
first_line() { local l=""; IFS= read -r l < "$1" || true; printf '%s' "$l"; }
tail_of() { cat "$W.out" "$W.err" 2> /dev/null | sed -n '1,12p'; }

SHA12="$(printf '%s' "$SHA" | cut -c1-12)"
SFX=""; [ "$PASS" -ge 2 ] && SFX="-p${PASS}"
PSFX=""; [ "$PASS" -ge 3 ] && PSFX="-p$((PASS - 1))"
input base "$BASE"
input story-file "$STORY"

# prior_file <gate suffix: code-review|qa-validation> -> the pass M-1 review file, in the worktree first, else the root.
prior_file() {
  local rel="docs/reviews/s${SPRINT}/${IDX}-$1${PSFX}.md"
  if [ -f "$WT/$rel" ]; then printf '%s' "$WT/$rel"; elif [ -f "$ROOT/$rel" ]; then printf '%s' "$ROOT/$rel"; else return 1; fi
}
# reviewed_sha <file> -> the prior's reviewed sha, read as partition-review-diff.sh's prior_delta reads the same
# file for --route and --narrow (the same extraction, except that a bare `reviewed-sha:` line with an empty value counts here): every column-0 `reviewed-sha:` line OUTSIDE a ``` / ~~~ fence, each value with
# the label, backticks, CR and blanks stripped. A merged (sharded) review carries one such line per shard, so the
# file answers when its lines name exactly ONE distinct value and that value is hex. Otherwise exit 1, the cause
# on stdout: no line, N distinct values, or a non-hex value (a value carrying prose).
reviewed_sha() {
  awk '
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { f = 0; next }
    !f && /^[ \t]*(```|~~~)/ { f = 1; next }
    f { next }
    /^reviewed-sha:/ { v = $0; sub(/^reviewed-sha:[ \t]*/, "", v)
      gsub(/[`\r \t]/, "", v)
      if (!(v in S)) { S[v] = 1; n++; s = v } }
    END {
      if (n == 0) { print "no column-0 reviewed-sha line outside a fence"; exit 1 }
      if (n > 1) { print n " distinct column-0 reviewed-sha values outside a fence, where every line must name the one reviewed sha"; exit 1 }
      if (s !~ /^[0-9a-f]+$/) { print "a column-0 reviewed-sha value that is not a hex object name (" s ")"; exit 1 }
      print s
    }' "$1"
}

# captures <sha>: --list-captures into $CAP. Sets XCAP to the --exclude-captures pair, or empty on exit 2.
XCAP_ON=1
captures() {
  run validate-handoff-evidence.sh -C "$WT" --list-captures "$STORY" "$1"
  case "$RC" in
    0) cp "$W.out" "$CAP" || die "cannot write $CAP"; XCAP_ON=1; input captures "$CAP" ;;
    2) XCAP_ON=0; rm -f "$CAP"; input gate-log "list-captures exit 2, partitioned without --exclude-captures: $(first_line "$W.err")" ;;
    *) refuse list-captures "validate-handoff-evidence.sh --list-captures exited $RC: $(first_line "$W.err")" "fix the story's capture citations at $SHA12, then re-run gate-transition.sh"; stop_if_refused ;;
  esac
}
xcap() { [ "$XCAP_ON" = 1 ] && printf '%s\n%s\n' --exclude-captures "$CAP"; }

# handoff <check name> <args...>: a validate-handoff-evidence.sh arm. 1 refuses; 2 is recorded, never refuses.
handoff() {
  local name="$1"; shift
  run validate-handoff-evidence.sh -C "$WT" "$@"
  case "$RC" in
    0) ;;
    2) input gate-log "$name exit 2 (nothing checked): $(first_line "$W.err")" ;;
    *) refuse "$name" "validate-handoff-evidence.sh $* exited $RC:
$(grep -E '^(REFUSED|FAIL)' "$W.out" "$W.err" 2> /dev/null | sed -n '1,20p')" "send the dev these REFUSED lines verbatim; once the dev re-hands off, re-run gate-transition.sh" ;;
  esac
  awk '/^(SKIP|WARN|SMOKE NO-SURFACE)/ { print "gate-log: " $0 }' "$W.out" 2> /dev/null >> "$W.inputs"
}

MANIFEST=none; ROUTE=""; NONCE=""; : > "$W.map"
# map <shard dir> <base> [extra args...]: one --map run. MAPRC is its exit; on 0 the map is in $W.map.
map() {
  local sd="$1" b="$2"; shift 2
  set -f
  # shellcheck disable=SC2046
  bash "$SELF/partition-review-diff.sh" --map "$WT" "$b" "$SHA" $(xcap) "$@" --shard-dir "$sd" > "$W.out" 2> "$W.err" < /dev/null
  MAPRC=$?
  set +f
  MAPLINE="$(first_line "$W.out")"; [ -n "$MAPLINE" ] || MAPLINE="$(first_line "$W.err")"
  [ "$MAPRC" = 0 ] && cp "$W.out" "$W.map"
  return 0
}
map_answer() { # <shard dir> -> sets MANIFEST and ROUTE from the last map run
  case "$MAPRC" in
    0) MANIFEST="$1/.manifest"; ROUTE="${ROUTE:-partitioned}"; input shard-dir "$1" ;;
    3) MANIFEST=none; ROUTE="serial $MAPLINE"; : > "$W.map" ;;
    *) MANIFEST=none; ROUTE="refused $MAPLINE"; : > "$W.map"; input gate-log "$MAPLINE" ;;
  esac
}
carried() { # <prior file>
  run validate-carried-findings.sh --list "$1"
  [ "$RC" = 0 ] || { refuse carried-findings "validate-carried-findings.sh --list $1 exited $RC: $(first_line "$W.err")" "repair the pass $((PASS - 1)) review file's findings, then re-run gate-transition.sh"; return; }
  while IFS= read -r l; do [ -n "$l" ] && input carried "$l"; done < "$W.out"
}

# dar_section <file> -> the `## Dev Agent Record` section, to the next level-1 or level-2 heading.
dar_section() { awk '/^## Dev Agent Record([[:space:]]|$)/ { on = 1; next } on && /^##?[[:space:]]/ { exit } on { sub(/\r$/, ""); print }' "$1"; }

write_plan() {
  {
    printf 'story: %s\ngate: %s\npass: %s\nsha: %s\nworktree: %s\nmanifest: %s\nroute: %s\n' \
      "$IDX" "$1" "$PASS" "$SHA" "$WT" "$MANIFEST" "$ROUTE"
    [ -z "$NONCE" ] || printf 'nonce: %s\n' "$NONCE"
    cat "$W.map" "$W.inputs"
  } > "$W.plan" && mv "$W.plan" "$PLAN" || die "cannot write $PLAN"
  printf '%s\n' "$PLAN"
  exit 0
}

case "$GATE" in
1)
  n="$(git -C "$WT" rev-list --no-merges --count "${BASE}..${SHA}" 2> /dev/null)" || n=""
  case "$n" in
    '') refuse commit-presence "git cannot read ${BASE}..${SHA12} in $WT" "pass the gate-1 manifest's base as --base" ;;
    0) refuse commit-presence "${BASE}..${SHA12} has no non-merge commit: the dev produced no deliverable" "resume or re-dispatch the dev before gating" ;;
  esac
  stop_if_refused
  handoff handoff-evidence "$STORY" "$BASE" "$SHA"
  handoff handoff-strategy --strategy "$SHA" "$STORY"
  stop_if_refused
  captures "$SHA"
  SD="$WT/docs/reviews/s${SPRINT}/shards/${IDX}-code-review-${SHA12}${SFX}"
  if [ "$PASS" -ge 2 ]; then
    PRIOR="$(prior_file code-review)" || { refuse prior-review "no pass $((PASS - 1)) review file docs/reviews/s${SPRINT}/${IDX}-code-review${PSFX}.md in $WT or $ROOT" "merge pass $((PASS - 1)) before re-reviewing"; stop_if_refused; }
    PSHA="$(reviewed_sha "$PRIOR")" || { refuse prior-review "$PRIOR carries $PSHA" "every column-0 reviewed-sha line of the pass $((PASS - 1)) review (one per shard in a merged review) must name the one full sha it reviewed"; stop_if_refused; }
    input prior "$PRIOR"
    set -f
    # shellcheck disable=SC2046
    bash "$SELF/partition-review-diff.sh" --route "$WT" "$PRIOR" "$SHA" $(xcap) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
    set +f
    if [ "$RC" = 0 ]; then
      MANIFEST=none; ROUTE="record-only $(first_line "$W.out")"
      handoff handoff-evidence "$STORY" "$BASE" "$SHA"
      carried "$PRIOR"; stop_if_refused; write_plan 1
    fi
    set -f
    # shellcheck disable=SC2046
    bash "$SELF/partition-review-diff.sh" --narrow "$WT" "$PRIOR" "$SHA" $(xcap) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
    set +f
    if [ "$RC" = 0 ]; then
      while IFS= read -r l; do input narrow "$l"; done < "$W.out"
      ROUTE=narrowed
      map "$SD" "$PSHA" --narrow-from "$PRIOR"
      if [ "$MAPRC" = 2 ]; then input gate-log "$MAPLINE"; ROUTE=""; map "$SD" "$PSHA"; fi
    else
      map "$SD" "$PSHA"
    fi
    if [ "$MAPRC" = 2 ]; then input gate-log "$MAPLINE"; map "$SD" "$BASE"; fi
    map_answer "$SD"
    handoff handoff-evidence "$STORY" "$BASE" "$SHA"
    carried "$PRIOR"
  else
    map "$SD" "$BASE"
    map_answer "$SD"
  fi
  stop_if_refused
  write_plan 1
  ;;
2)
  captures "$SHA"
  if [ "$PASS" -ge 2 ]; then
    PRIOR="$(prior_file qa-validation)" || { refuse prior-validation "no QA pass $((PASS - 1)) file docs/reviews/s${SPRINT}/${IDX}-qa-validation${PSFX}.md in $WT or $ROOT" "merge QA pass $((PASS - 1)) first"; stop_if_refused; }
    GO="$(reviewed_sha "$PRIOR")" || { refuse prior-validation "$PRIOR carries $GO" "every column-0 reviewed-sha line of the QA pass $((PASS - 1)) file (one per shard in a merged validation) must name the one full go-signal sha it validated"; stop_if_refused; }
    input prior "$PRIOR"
    set -f
    # shellcheck disable=SC2046
    bash "$SELF/partition-review-diff.sh" --gate1-rerun "$WT" "$GO" "$SHA" $(xcap) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
    set +f
    l="$(first_line "$W.out")"; [ -n "$l" ] || l="$(first_line "$W.err")"
    case "$RC:$l" in
      0:GATE1-SKIP*) input gate-log "$l" ;;
      *) MANIFEST=none; ROUTE="rerun $l"
         input next "gate-transition.sh $IDX 1 --pass <next gate-1 pass> -C $WT --base $BASE --sprint $SPRINT --story-file $STORY"
         printf 'gate-transition: Rule A answered %s; gate 1 re-runs as a re-review pass first. This plan authorizes no seat; the lead runs the next: gate-1 command.\n' "$l" >&2
         write_plan rerun ;;
    esac
  fi
  # The DAR-fold preflight, verified: the canonical sprint-branch story's Dev Agent Record is
  # non-empty and equal to the story branch's at the go-signal sha. Nothing is copied here.
  if [ ! -f "$ROOT/$STORY" ]; then
    refuse dar-fold "the canonical story $ROOT/$STORY does not exist" "copy the story branch's Dev Agent Record into the canonical sprint-branch story file, then re-run gate-transition.sh"
  elif ! git -C "$WT" show "${SHA}:${STORY}" > "$W.story" 2> /dev/null; then
    refuse dar-fold "$STORY is not committed at $SHA12 in $WT" "commit the story file on the story branch"
  else
    dar_section "$ROOT/$STORY" > "$W.dar1"; dar_section "$W.story" > "$W.dar2"
    if ! grep -q '[^[:space:]]' "$W.dar1"; then
      refuse dar-fold "the canonical $STORY has an empty or absent Dev Agent Record" "copy the story branch's Dev Agent Record into the canonical sprint-branch story file, then re-run gate-transition.sh"
    elif ! cmp -s "$W.dar1" "$W.dar2"; then
      refuse dar-fold "the canonical $STORY Dev Agent Record differs from the story branch's at $SHA12 (stale)" "copy the story branch's Dev Agent Record into the canonical sprint-branch story file, then re-run gate-transition.sh"
    fi
  fi
  handoff handoff-gate2 --gate2 "$STORY" "$BASE" "$SHA"
  handoff handoff-smoke --smoke "$STORY" "$BASE" "$SHA"
  stop_if_refused
  if [ "$PASS" -ge 2 ]; then
    set -f
    # shellcheck disable=SC2046
    bash "$SELF/partition-review-diff.sh" --route "$WT" "$PRIOR" "$SHA" $(xcap) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
    set +f
    if [ "$RC" = 0 ]; then
      MANIFEST=none; ROUTE="record-only $(first_line "$W.out")"
      carried "$PRIOR"; stop_if_refused; write_plan 2
    fi
  fi
  SD="$WT/docs/reviews/s${SPRINT}/shards/${IDX}-qa-validation-${SHA12}${SFX}"
  map "$SD" "$BASE"
  map_answer "$SD"
  if [ "$MAPRC" = 0 ]; then
    # After --map and before any QA seat: it trusts the manifest only while no seat has touched it.
    ( cd "$ROOT" && bash "$SELF/merge-review-shards.sh" --record-partition "$SD" ) > "$W.out" 2> "$W.err" < /dev/null \
      || refuse record-partition "merge-review-shards.sh --record-partition $SD failed: $(grep -m1 -E 'REFUSED|refuse' "$W.err" "$W.out" 2> /dev/null)" "run gate-transition.sh from the lead checkout, with the worktree added from it"
  fi
  [ "$PASS" -lt 2 ] || carried "$PRIOR"
  stop_if_refused
  write_plan 2
  ;;
3)
  # Each arm runs from the project root, as the lead runs it there.
  arm() { # <check id> <sibling> <args...>
    local id="$1" s="$2"; shift 2
    ( cd "$ROOT" && bash "$SELF/$s" "$@" ) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
    [ "$RC" = 0 ] || refuse "check-$id" "$s $* exited $RC:
$(tail_of)" "take Check $id through gate-validation.md Gate Failure now, while no adjudicator runs; then re-run gate-transition.sh $IDX 3"
  }
  arm 2 verdict.sh validate-escalation-status-vocabulary docs/escalations/pending.md
  arm 2 verdict.sh validate-suppression-lifetime --escalations docs/escalations/pending.md
  arm 2a validate-escalation-resolution.sh --escalations docs/escalations/pending.md --sprint "$SPRINT" --transcript-dir "$TDIR"
  arm 5 sprint-status.sh check-stories
  arm 5 sprint-status.sh derive-stories --check
  ( bash "$SELF/validate-stub-audit.sh" --root "$WT" --changed-from "$BASE" "$SHA" ) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
  case "$RC" in
    0) ;;
    4) input gate-log "Check 16 audited nothing (exit 4): no in-scope hot-path file in ${BASE}..${SHA12}" ;;
    *) refuse check-16 "validate-stub-audit.sh --changed-from $BASE $SHA exited $RC:
$(tail_of)" "take Check 16 through Gate Failure; then re-run gate-transition.sh $IDX 3" ;;
  esac
  SLOT="_bmad-output/planning-artifacts/s${SPRINT}"
  for os in "$ROOT/$SLOT"/bug-fix-oneshot-*.md; do
    [ -f "$os" ] || continue
    slug="${os##*/bug-fix-oneshot-}"; slug="${slug%.md}"
    arm 17 validate-spawn-ledger.sh --fold-architect "$SLOT/fold-architecture-${slug}.md" "$SLOT/bug-fix-oneshot-${slug}.md" --ledger _bmad-output/spawn-ledger.jsonl --route .claude/skills/ai-dlc/steps/route.md
    if grep -qE "^[[:space:]]*artifact:[[:space:]]*['\"]?([^[:space:]'\"]*/)?${STORY##*/}['\"]?[[:space:]]*$" "$os"; then
      arm 17 validate-provenance-block.sh "$STORY" --require-skill bmad-review
    fi
  done
  if [ -f "$ROOT/$SLOT/bug-fix-oneshot.md" ]; then
    arm 17 validate-spawn-ledger.sh --fold-architect "$SLOT/fold-architecture.md" "$SLOT/bug-fix-oneshot.md" --ledger _bmad-output/spawn-ledger.jsonl --route .claude/skills/ai-dlc/steps/route.md
  fi
  # Check 22 exit codes (validate-spawn-ledger.sh header "3  NOTHING WAS COMPARED"; gate-validation.md "Exit 3, PRE-LEDGER"):
  # 3 is NOT a FAIL -- nothing was compared, and the lead falls back to the gate log's spawn table. Two causes, each
  # with its own first output line: `PRE-LEDGER: ...` (no row of this sprint) and `NO ROLE-BOUND ROWS: EXAMINED
  # NOTHING ...` (rows exist, none judged). The script's own first line is recorded, plus its COUNTS: line if any.
  # Recorded as an input, never a clean pass and never a refusal; any other non-zero exit refuses, as Check 16's does.
  ( cd "$ROOT" && bash "$SELF/validate-spawn-ledger.sh" --ledger _bmad-output/spawn-ledger.jsonl --sprint "$SPRINT" --probe _bmad-output/subagent-context.jsonl --settings .claude/settings.json ) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
  CL="$(grep -m1 '^COUNTS:' "$W.out")" || CL=""
  case "$RC" in
    0) ;;
    3) input gate-log "Check 22 exit 3: $(first_line "$W.out")"; [ -z "$CL" ] || input gate-log "Check 22 $CL" ;;
    *) refuse check-22 "validate-spawn-ledger.sh --sprint $SPRINT exited $RC:
$(tail_of)" "take Check 22 through gate-validation.md Gate Failure now, while no adjudicator runs; then re-run gate-transition.sh $IDX 3" ;;
  esac
  ( cd "$ROOT" && bash "$SELF/validate-steering-budget.sh" --count ) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
  if [ "$RC" = 0 ]; then input steering-count "$(first_line "$W.out")"; else input gate-log "Check 25 SKIP: no transcript ($(first_line "$W.err"))"; fi
  ( cd "$ROOT" && bash "$SELF/validate-h2-attestation.sh" --verify --sprint "$SPRINT" ) > "$W.out" 2> "$W.err" < /dev/null; RC=$?
  if [ "$RC" = 0 ]; then
    input h2 "$(grep -m1 'H2_ATTESTED' "$W.out" "$W.err" 2> /dev/null | sed 's/^[^:]*://')"
  else
    refuse check-H2 "validate-h2-attestation.sh --verify --sprint $SPRINT exited $RC" "drive H2 in full (gate-validation.md H2), run validate-h2-attestation.sh --attest --sprint $SPRINT, append its line to the gate log, then re-run gate-transition.sh $IDX 3"
  fi
  stop_if_refused
  NONCE="implementation-$(date -u +%Y%m%dT%H%M%SZ)"
  ( bash "$SELF/gate-checkpoint.sh" --nonce "$NONCE" open ) > "$W.out" 2> "$W.err" < /dev/null \
    || { refuse open "gate-checkpoint.sh --nonce $NONCE open failed: $(first_line "$W.err")" "re-run gate-transition.sh $IDX 3"; stop_if_refused; }
  MANIFEST=none; ROUTE="gate3 adjudicator"
  write_plan 3
  ;;
close)
  for p in "$PDIR/${IDX}-g3-p"*.plan; do
    [ -f "$p" ] || continue
    while IFS= read -r l; do case "$l" in 'nonce: '*) NONCE="${l#nonce: }" ;; esac; done < "$p"
  done
  if [ -z "$NONCE" ]; then
    slug="$(printf '%s' "$IDX" | sed -e 's/[[:punct:]]*$//' | tr 'A-Z.-' 'a-zxx')"
    for v in "$STATE_DIR"/gate-adjudication/implementation-*.verdict.json; do
      [ -f "$v" ] || continue
      grep -qE "\"gate_series_id\"[[:space:]]*:[[:space:]]*\"implementation-story${slug}-s${SPRINT}-" "$v" || continue
      n="${v##*/}"; NONCE="${n%.verdict.json}"
    done
  fi
  # The sprint-scoped fallback: a multi-story or storyless gate 3 carries the series id
  # `implementation-s<N>-<TS>`, no slug, and writes no g3 plan. Matched exactly, so a slugged or
  # other-sprint id is never taken. RESIDUAL: the verdict schema names no story (its fields are the
  # envelope and per-check rows), so this cannot bind the gate to THIS story; the 26 PASS row below
  # still binds it to a gate 3 that passed, and the plan records that it rests on a sprint gate.
  if [ -z "$NONCE" ]; then
    for v in "$STATE_DIR"/gate-adjudication/implementation-*.verdict.json; do
      [ -f "$v" ] || continue
      grep -qE "\"gate_series_id\"[[:space:]]*:[[:space:]]*\"implementation-s${SPRINT}-[0-9]{8}T[0-9]{6}Z\"" "$v" || continue
      n="${v##*/}"; NONCE="${n%.verdict.json}"
    done
    [ -z "$NONCE" ] || input gate3-scope "sprint-scoped gate 3 (implementation-s${SPRINT}-<TS>, no story slug): its verdict names no story, so this close cannot bind to story $IDX"
  fi
  if [ -z "$NONCE" ]; then
    refuse close "no gate-3 plan and no gate-adjudication verdict for story $IDX in sprint $SPRINT names a nonce" "run gate-transition.sh $IDX 3 and pass gate 3"; stop_if_refused
  fi
  bash "$SELF/gate-checkpoint.sh" --nonce "$NONCE" list > "$W.out" 2> "$W.err" < /dev/null; RC=$?
  if [ "$RC" != 0 ] || ! grep -q '[^[:space:]]' "$W.out"; then
    refuse close "no gate-3 ledger for nonce $NONCE in this checkout (ledgers are checkout-local)" "close from the checkout that ran gate 3, or re-run gate 3"
  elif ! awk -F'\t' '$1 == "26" && $2 == "PASS" { f = 1 } END { exit !f }' "$W.out"; then
    refuse close "the gate-3 ledger for nonce $NONCE has no '26 PASS' row" "gate 3 has not passed; finish it through Check 26"
  fi
  stop_if_refused
  MANIFEST=none; ROUTE="close 26 PASS"
  write_plan close
  ;;
esac
