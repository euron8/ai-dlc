#!/usr/bin/env bash
# fold-architect-ledger-join — Check 17's fold architecture gate, driven through the shipped
# program over the reference consumer's REAL spawn-ledger rows.
#
# WHAT THIS EXISTS TO CATCH. A fix story folded into a sprint after its architecture step never
# reached an architect: the only disposition a folded capital-path edit got was a lead-written
# No-AD citing the sprint's stale assessment. bug-investigation.md section 4 now dispatches ONE
# architect after the one-shot, and `validate-spawn-ledger.sh --fold-architect` proves it from a
# record the lead does not write — the spawn ledger the dispatch guard appends. This fixture
# drives that mode, the manifest row that makes Check 17 load at an implementation gate, and the
# writer-reader bind between the step that writes the residue and the gate that reads it.
#
# EVERY SEED ASSERTS THE EXIT *AND* THE FIRST LINE. PASS, NOT-OWED and SKIP-PRE-ADOPTION all exit
# 0, so an exit-code arm cannot tell a join that held from one that never ran. The first line is
# the only thing that separates them, and a SKIP or NOT-OWED arm also requires that NO line of
# the output starts with `PASS:`.
#
# THE LEDGER IS NOT HAND-WRITTEN. `graph-ledger.jsonl` beside this file is the reference
# consumer's own `_bmad-output/spawn-ledger.jsonl` rows for S313 (every row carries a
# tool_use_id), S311 (the sprint the guard began writing ids MID-sprint) and twelve S310 rows (no
# ids at all), copied byte-for-byte. `graph-oneshot-s313.block` is that sprint's real one-shot
# provenance block. The discriminating cases are REAL dispatches: the S313 architect at 21:58:16Z
# is the measured impostor — an architect row in the same sprint, three minutes after the fold
# report and one hour BEFORE the one-shot ran — and the adversary at 23:53:57Z is an in-sprint,
# after-the-one-shot dispatch of the wrong role. A seeded world written by hand alone found none
# of batch 145's discriminating cases; the epoch row here is not the subject (S313 has 106 rows).
#
# THE MUTATION BATTERY IS `fold-architect-ledger-join-mutants`, distribution-only. It edits
# copies of core's sources and requires each edit to redden exactly the arms named for it here.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# ROOT BY WALKING UP FOR A MARKER, both layouts named, never a hop count (I33). The distribution
# carries core/scripts/<x>; a consumer carries scripts/ai-dlc/<x> and .claude/skills/.
ROOT="$HERE"; LAYOUT=""
while [ "$ROOT" != "/" ]; do
  if   [ -f "$ROOT/core/scripts/validate-spawn-ledger.sh" ];   then LAYOUT=dist;     break
  elif [ -f "$ROOT/scripts/ai-dlc/validate-spawn-ledger.sh" ]; then LAYOUT=consumer; break
  fi
  ROOT="$(dirname "$ROOT")"
done
case "$LAYOUT" in
  dist)     SD="$ROOT/core/scripts";    STEPS="$ROOT/core/skills/ai-dlc/steps" ;;
  consumer) SD="$ROOT/scripts/ai-dlc";  STEPS="$ROOT/.claude/skills/ai-dlc/steps" ;;
  *) echo "FIXTURE ERROR: validate-spawn-ledger.sh not found above $HERE in either layout" >&2; exit 2 ;;
esac
VSL="$SD/validate-spawn-ledger.sh"; GS="$SD/gate-slice.sh"; VPB="$SD/validate-provenance-block.sh"
SS="$SD/stamp-story-provenance.sh"
GV="$STEPS/gate-validation.md"; BI="$STEPS/bug-investigation.md"; ROUTE="$STEPS/route.md"
LEDGER_SRC="$HERE/graph-ledger.jsonl"; BLOCK_SRC="$HERE/graph-oneshot-s313.block"
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq not on PATH" >&2; exit 2; }
for f in "$VSL" "$GS" "$VPB" "$SS" "$GV" "$BI" "$ROUTE" "$LEDGER_SRC" "$BLOCK_SRC"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: missing $f" >&2; exit 2; }
done

echo "fold-architect-ledger-join:"
printf '  subject: %s\n' "$VSL"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer whose installed validator predates the
# mode has nothing here to drive; that is reported by name and is not a pass. In the
# DISTRIBUTION the mode must exist — there, its absence is the regression.
if ! grep -q -- '--fold-architect)' "$VSL"; then
  if [ "$LAYOUT" = consumer ]; then
    echo "  SUBJECT ABSENT: the installed validate-spawn-ledger.sh has no --fold-architect mode;"
    echo "  nothing was driven. Not a pass: pull the release that ships it."
    exit 0
  fi
  echo "FIXTURE BROKEN: core/scripts/validate-spawn-ledger.sh has no --fold-architect mode" >&2
  exit 1
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
case "$WORK" in /tmp/*|/private/*|/var/folders/*) trap 'rm -rf "$WORK"' EXIT ;; esac

fails=0; asserted=0; stood=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }
sd()  { printf '  --    %s\n' "$1"; stood=$((stood+1)); }

# --- the real inputs, and the controls that they can express the defect --------------------
STORY="$(awk '/^artifact:/ { sub(/^artifact:[ \t]*/, ""); print; exit }' "$BLOCK_SRC")"
INV="$(awk '/^invoked_at:/ { sub(/^invoked_at:[ \t]*/, ""); print; exit }' "$BLOCK_SRC")"
SLUG=rebalancer-burn-block-fix
ARCH_AFTER=toolu_1790231838987_1     # S313 architect 2026-09-24T06:37:19Z  (after the one-shot)
ARCH_AFTER2=toolu_1790233090204_0    # S313 architect 2026-09-24T06:58:10Z  (after the one-shot)
ARCH_BEFORE=toolu_1790200696856_1    # S313 architect 2026-09-23T21:58:16Z  (the measured impostor)
ADV_AFTER=toolu_1790207637745_0      # S313 adversary 2026-09-23T23:53:57Z  (wrong role, after)
ARCH_S311=toolu_01Uy75pGGuMLJJN3ekiJC3TT  # S311 architect 2026-09-12T17:39:24Z
ADV_S311=toolu_01PUKFVS9uDcGEhxYit8GdSx   # S311 adversary 2026-09-12T18:40:01Z  (an S311 one-shot's own row)
ARCH_S311B=toolu_01HqLHNrebeY3Ko8NLaKZiGS # S311 architect 2026-09-12T22:44:29Z  (after that one-shot)
ABSENT_ID=toolu_fold_fixture_absent_0     # carried by no ledger row (asserted below)
ONE_ID=toolu_1790204383263_0              # S313 adversary 2026-09-23T22:59:43Z  (the one-shot's OWN row)
BACKDATE=2026-09-20T00:00:00Z             # before S313's first ledger row, 2026-09-21T21:13:06Z

role_of() { jq -r --arg t "$1" 'select(.tool_use_id == $t) | "\(.role) \(.sprint) \(.ts)"' "$LEDGER_SRC" 2>/dev/null; }
sane=1
[ "$STORY" = "_bmad-output/planning-artifacts/s313/stories/story-3-1-rebalancer-burn-block-fix.md" ] || sane=0
[ "$INV" = "2026-09-23T23:03:36Z" ] || sane=0
[ "$(role_of "$ARCH_AFTER")"  = "architect 313 2026-09-24T06:37:19Z" ] || sane=0
[ "$(role_of "$ARCH_AFTER2")" = "architect 313 2026-09-24T06:58:10Z" ] || sane=0
[ "$(role_of "$ARCH_BEFORE")" = "architect 313 2026-09-23T21:58:16Z" ] || sane=0
[ "$(role_of "$ADV_AFTER")"   = "adversary 313 2026-09-23T23:53:57Z" ] || sane=0
[ "$(role_of "$ARCH_S311")"   = "architect 311 2026-09-12T17:39:24Z" ] || sane=0
[ "$(role_of "$ADV_S311")"    = "adversary 311 2026-09-12T18:40:01Z" ] || sane=0
[ "$(role_of "$ARCH_S311B")"  = "architect 311 2026-09-12T22:44:29Z" ] || sane=0
[ -z "$(role_of "$ABSENT_ID")" ] || sane=0
[ "$(role_of "$ONE_ID")"      = "adversary 313 2026-09-23T22:59:43Z" ] || sane=0
[ "$(awk '/^tool_use_id:/ { print $2; exit }' "$BLOCK_SRC")" = "$ONE_ID" ] || sane=0
# S313 is FULLY adopted (every row carries an id) and BACKDATE precedes all of it; S311 is not.
[ "$(jq -rs '[.[] | select(.sprint == 313) | .ts] | min' "$LEDGER_SRC" 2>/dev/null)" = "2026-09-21T21:13:06Z" ] || sane=0
[ "$(jq -rs '[.[] | select(.sprint == 313 and ((.tool_use_id // "") == ""))] | length' "$LEDGER_SRC" 2>/dev/null)" = 0 ] || sane=0
[ "$(jq -rs '[.[] | select(.sprint == 311 and ((.tool_use_id // "") == ""))] | length' "$LEDGER_SRC" 2>/dev/null)" -gt 0 ] 2>/dev/null || sane=0
n310="$(grep -cE '"sprint":310[,}]' "$LEDGER_SRC")" || n310=0
n310id="$(grep -E '"sprint":310[,}]' "$LEDGER_SRC" | grep -c '"tool_use_id":"toolu_')" || n310id=0
[ "$n310" -gt 0 ] && [ "$n310id" -eq 0 ] || sane=0
[ "$sane" -eq 1 ] || { echo "FIXTURE BROKEN: the copied ledger or one-shot block no longer carries the rows these seeds name" >&2; exit 1; }

# --- world builders ----------------------------------------------------------------------------
# One fresh world per seed: a residue left behind by one seed must never be read by the next,
# because the uniqueness clause scans every fold-architecture-*.md in the slot.
WN=0
mkworld() {  # <sprint> -> sets W and SLOT
  WN=$((WN+1)); W="$WORK/w$WN"; SLOT="$W/_bmad-output/planning-artifacts/s$1"
  mkdir -p "$SLOT/stories"; cp "$LEDGER_SRC" "$W/_bmad-output/spawn-ledger.jsonl"
}
oneshot() {  # <file> [invoked_at artifact [tool_use_id]] -- the real block, fields overridden only when given
  { printf '# Bug-fix one-shot adversarial review\n\nFindings elided.\n\n'
    if [ $# -ge 3 ]; then
      awk -v i="$2" -v a="$3" -v t="${4:-}" '/^invoked_at:/ { print "invoked_at: " i; next }
                               /^artifact:/   { print "artifact: " a; next }
                               /^tool_use_id:/ && t != "" { print "tool_use_id: " t; next } { print }' "$BLOCK_SRC"
    else cat "$BLOCK_SRC"; fi; } > "$1"
}
residue() {  # <file> <tool_use_id> <artifact> -- the shape bug-investigation.md section 4 prescribes
  printf '%s\n' '# Fold architecture disposition' '' \
    '- **No-AD:** CAP-7 — REASON: the fix narrows an existing burn guard; no new boundary.' '' \
    '<!-- SKILL_INVOCATION_PROVENANCE v1' 'skill: bmad-review-adversarial-general' \
    'invoked_at: 2026-09-24T06:40:02Z' "tool_use_id: $2" 'mode: subagent' \
    'lead_role: bug-investigation.md' "artifact: $3" \
    'findings_critical: 0' 'findings_major: 0' 'findings_minor: 1' \
    'SKILL_INVOCATION_PROVENANCE_END -->' > "$1"
}
snapshot() {  # <world root> <variant> -- the reference consumer's own line shape, verbatim
  mkdir -p "$1/_bmad-output"
  printf '%s\n' '# Pipeline Snapshot' '' '## Pipeline Position' "- pipeline_variant: $2" \
    '- current_step_file: retro.md — SPRINT 313 CLOSED. Retro §3/§4/§4a/§4b/§5 complete;' \
    > "$1/_bmad-output/pipeline-snapshot.md"
}
# sstatus <world root> <variant> <sprint>: the reference consumer's own sprint-status.yaml, line for
# line (graph's _bmad-output/implementation-artifacts/sprint-status.yaml), with only the sprint
# number and the top-level `variant:` bound. It carries an INDENTED comment block under `stories:`,
# so a reader that took any `variant:` line rather than the column-0 one has something to misread.
sstatus() {
  mkdir -p "$1/_bmad-output/implementation-artifacts"
  printf '%s\n' "sprint: $3" 'name: "telv3-upgrade"' "variant: $2" 'status: in_progress' \
    'validation_intensity: full' 'stories:' '  # populated at stories-test-strategy. A MAPPING keyed by story id' \
    '  # (story-314-<M>:), never a list — a list form matches no reader.' \
    > "$1/_bmad-output/implementation-artifacts/sprint-status.yaml"
}
# stamp <story rel> <one-shot rel>: write the story and stamp it with the SHIPPED writer, run from
# the world root exactly as bug-investigation.md section 4 runs it. The subject now refuses a fold
# whose story carries no stamp, so every PASS world needs one, and a hand-written block would be a
# seed taken from the reader's accept-set. The stamp's tool_use_id must be the one-shot's: that
# equality is what the subject's re-point clause reads, so a stamp that did not copy it would make
# every PASS seed here a re-point FAIL for a reason no seed names.
stamp() {
  mkdir -p "$(dirname "$W/$1")"
  printf '%s\n' '# Story 3.1: Rebalancer burn block fix' '' 'Status: ready-for-dev' '' \
    '## Acceptance Criteria' '' '1. The burn guard blocks a rebalance whose burn exceeds the cap.' > "$W/$1"
  ( cd "$W" && bash "$SS" --terminal "$2" --profile bug-story-provenance "$1" ) > "$WORK/stamp.$WN.out" 2>&1 \
    || { echo "FIXTURE BROKEN: the shipped stamp-story-provenance.sh refused $2 over $1" >&2; cat "$WORK/stamp.$WN.out" >&2; exit 1; }
  local st ot
  st="$(awk '/^tool_use_id:/ { print $2; exit }' "$W/$1")"; ot="$(awk '/^tool_use_id:/ { print $2; exit }' "$W/$2")"
  [ -n "$st" ] && [ "$st" = "$ot" ] \
    || { echo "FIXTURE BROKEN: the stamp on $1 carries tool_use_id '$st', the one-shot '$ot'" >&2; exit 1; }
}
rel() { printf '%s\n' "${1#"$W"/}"; }  # <absolute path inside the current world> -> world-relative
# EVERY DRIVE RUNS FROM THE WORLD ROOT. The subject reads `_bmad-output/pipeline-snapshot.md`
# relative to the cwd, so a drive from the caller's cwd would read a consumer's OWN snapshot when
# this fixture runs there, and every no-snapshot arm would then assert about that sprint.
drive() {  # args to the subject; sets RC, FIRST, NPASS, OUTF
  OUTF="$WORK/out.$WN.$RANDOM"
  ( cd "$W" && bash "$VSL" "$@" ) > "$OUTF" 2>&1; RC=$?
  FIRST="$(sed -n 1p "$OUTF")"
  NPASS="$(grep -c '^PASS:' "$OUTF")" || NPASS=0
}
has() { grep -qF -- "$1" "$OUTF"; }
# expect <id> <rc> <first-line prefix> <substring or ""> <nopass 0|1> <description>
expect() {
  local good=1
  [ "$RC" = "$2" ] || good=0
  case "$FIRST" in "$3"*) : ;; *) good=0 ;; esac
  [ -z "$4" ] || has "$4" || good=0
  [ "$5" = 0 ] || [ "$NPASS" -eq 0 ] || good=0
  if [ "$good" -eq 1 ]; then ok "[$1] $6"; else bad "[$1] $6 -- rc=$RC first='$FIRST'"; fi
}
ONE="bug-fix-oneshot-$SLUG.md"; RES="fold-architecture-$SLUG.md"
VARF="--variant feature --route $ROUTE"

# --- SELF-PROBE of this fixture's own bind extractor, BEFORE the corpus, both directions ------
# writer_path <file>: the residue path(s) named in section 4's **Fold architecture dispatch.**
# paragraph ONLY. reader_path <file>: those named in Check 17's own fold bullet ONLY. Both are
# section-scoped so that a stray mention elsewhere in either file can neither satisfy nor break
# the bind; the near-miss below carries exactly such a decoy.
writer_path() {
  awk '/^### 4\./ { s = 1; next } s && /^### / { s = 0 }
       s && index($0, "**Fold architecture dispatch.**") == 1 { p = 1 }
       p && /^[ \t]*$/ { p = 0 } p { printf "%s ", $0 } END { print "" }' "$1" \
    | grep -oE '`[^`]*fold-architecture-[^`]*`' | tr -d '`' | sort -u
}
reader_path() {
  awk '/<!-- CHECK_LOADED: 17 -->/ { s = 1 } /<!-- CHECK_LOADED: 18 -->/ { s = 0 }
       s && /^\*\*PASS:/ { s = 0 }
       s && /^- \*\*/ { b = (index($0, "- **Fold architecture gate (bug-investigation):**") == 1) }
       s && b { printf "%s ", $0 } END { print "" }' "$1" \
    | grep -oE '`[^`]*fold-architecture-[^`]*`' | tr -d '`' | sort -u
}
bind_holds() {  # <writer file> <reader file> -> 0 when each names exactly one path and they agree
  local w r
  w="$(writer_path "$1")"; r="$(reader_path "$2")"
  [ -n "$w" ] && [ -n "$r" ] || return 1
  [ "$(printf '%s\n' "$w" | grep -c .)" -eq 1 ] && [ "$(printf '%s\n' "$r" | grep -c .)" -eq 1 ] || return 1
  [ "$w" = "$r" ]
}
PW="$WORK/probe-writer.md"; PR="$WORK/probe-reader.md"; PRX="$WORK/probe-reader-drift.md"
printf '%s\n' '# decoy above: `x/s<N>/fold-architecture-DECOY.md`' '' '### 4. Validation' '' \
  '**Fold architecture dispatch.** writes the residue' '`a/s<N>/fold-architecture-<slug>.md` (same slug)' '' \
  'Later prose: `b/s<N>/fold-architecture-OTHER.md`.' '' '### 5. Next' > "$PW"
printf '%s\n' '<!-- CHECK_LOADED: 17 -->' '- **Bug-fix story readiness gate (bug-investigation):** see' \
  '  `c/s<N>/fold-architecture-ELSEWHERE.md` here.' '' \
  '- **Fold architecture gate (bug-investigation):** the architect writes' \
  '  `a/s<N>/fold-architecture-<slug>.md`, the same slug.' '' \
  '**PASS:** all exit 0.' '<!-- CHECK_LOADED: 18 -->' > "$PR"
sed 's|`a/s<N>/fold-architecture-<slug>.md`, the same|`a/s<N>/fold-architecture-<slug>-v2.md`, the same|' "$PR" > "$PRX"
if cmp -s "$PR" "$PRX"; then echo "FIXTURE BROKEN: the drift probe's sed did not apply" >&2; exit 1; fi
if bind_holds "$PW" "$PRX"; then bad "[P1] bind extractor fires on a seeded path drift"
else ok "[P1] bind extractor fires on a seeded path drift"; fi
if bind_holds "$PW" "$PR"; then ok "[P2] bind extractor stays quiet on agreeing paths beside out-of-section decoys"
else bad "[P2] bind extractor stays quiet on agreeing paths beside out-of-section decoys"; fi

# --- DEFECT 2: section 4's direct-fold paragraph types no gate command of its own ---------------
# A regression restoring "first `validate-provenance-block.sh <residue>` ..., then
# `--fold-architect`" in that paragraph passed the fixture and both receipts, because nothing read
# the paragraph. It must CITE Check 17's bullets by name. directfold_verdict <file> prints
# "<paragraphs> <backticked commands> <offending commands> <bullet names cited>": the paragraph is
# the one opening `**Direct fold:` inside `### 4.`, its lines joined so a backtick span that wraps
# is still one span; a command is a backticked span naming a `.sh`; an OFFENDING one invokes
# validate-spawn-ledger.sh, or validate-provenance-block.sh on a residue.
directfold_verdict() {
  local para n cmds nc nbad ncite
  para="$(awk '/^### 4\./ { s = 1; next } s && /^### / { s = 0 }
       s && index($0, "**Direct fold:") == 1 { p = 1; n++ }
       p && /^[ \t]*$/ { p = 0 } p { printf "%s ", $0 } END { print ""; print n + 0 > "/dev/stderr" }' "$1" 2>"$WORK/dfn")"
  n="$(cat "$WORK/dfn")"
  cmds="$(grep -oE '`[^`]*\.sh[^`]*`' <<<"$para")"
  nc="$(printf '%s\n' "$cmds" | grep -c .)" || nc=0
  nbad="$(printf '%s\n' "$cmds" | grep -E 'validate-spawn-ledger\.sh|validate-provenance-block\.sh[^`]*(<residue>|fold-architecture)' | grep -c .)" || nbad=0
  ncite=0
  case "$para" in *'"Bug-fix story readiness gate (bug-investigation)"'*) ncite=$((ncite+1)) ;; esac
  case "$para" in *'"Fold architecture gate (bug-investigation)"'*) ncite=$((ncite+1)) ;; esac
  echo "$n $nc $nbad $ncite"
}
PDF="$WORK/probe-df-bad.md"; PDQ="$WORK/probe-df-good.md"
printf '%s\n' '### 4. Validation' '' '**Direct fold: run the gate arms now.** Run Check 17'"'"'s' \
  '"Bug-fix story readiness gate (bug-investigation)" bullet and its "Fold architecture gate' \
  '(bug-investigation)" bullet: first `scripts/ai-dlc/validate-provenance-block.sh <residue>' \
  '--require-skill bmad-review-adversarial-general`, then the fold command.' '' '### 5. Next' > "$PDF"
printf '%s\n' '`scripts/ai-dlc/validate-spawn-ledger.sh --fold-architect <residue> <one-shot>` (decoy above)' '' \
  '### 4. Validation' '' '**Direct fold: run the gate arms now.** Run Check 17'"'"'s' \
  '"Bug-fix story readiness gate (bug-investigation)" bullet and its' \
  '"Fold architecture gate (bug-investigation)" bullet, as each spells its commands.' '' \
  'Later: `scripts/ai-dlc/validate-spawn-ledger.sh --fold-architect <residue> <one-shot>`.' '' '### 5. Next' > "$PDQ"
case "$(directfold_verdict "$PDF")" in
  "1 1 1 "*) ok "[P3] direct-fold extractor fires on a residue command that wraps a line inside the paragraph" ;;
  *) bad "[P3] direct-fold extractor fires on a residue command inside the paragraph -- got '$(directfold_verdict "$PDF")'" ;;
esac
case "$(directfold_verdict "$PDQ")" in
  "1 0 0 2") ok "[P4] direct-fold extractor stays quiet on a paragraph citing both bullets beside out-of-paragraph commands" ;;
  *) bad "[P4] direct-fold extractor stays quiet on a citing paragraph -- got '$(directfold_verdict "$PDQ")'" ;;
esac

# --- the eight contract seeds, plus the arms that pin each clause's neighbour ------------------
# (i) folded story, architecture variant, no residue
mkworld 313; oneshot "$SLOT/$ONE"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-i 1 "FAIL: no residue" "" 1 "(i) architecture variant, no residue -> FAIL"

# The no-flags DEFAULT: without --variant/--route every fold is OWED. Pinned, not accidental.
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl"
expect A-default 1 "FAIL: no residue" "" 1 "no --variant/--route: the fold is owed by default -> FAIL on no residue"

# (ii) residue citing a real architect row after the one-shot
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-ii 0 "PASS: $ONE -> $RES" "architect dispatch $ARCH_AFTER in S313" 0 "(ii) architect row after the one-shot -> PASS"
# The residue shape section 4 prescribes is the one the gate's OTHER half accepts.
bash "$VPB" "$SLOT/$RES" --require-skill bmad-review-adversarial-general >/dev/null 2>&1; pbrc=$?
if [ "$pbrc" -eq 0 ]; then ok "[A-ii-pb] validate-provenance-block.sh --require-skill accepts the prescribed residue"
else bad "[A-ii-pb] validate-provenance-block.sh --require-skill accepts the prescribed residue -- rc=$pbrc"; fi
# Default ledger path resolves against the CWD the gate runs in, so drive it from the world root.
( cd "$W" && bash "$VSL" --fold-architect "$SLOT/$RES" "$SLOT/$ONE" $VARF ) > "$WORK/dl.out" 2>&1; RC=$?
OUTF="$WORK/dl.out"; FIRST="$(sed -n 1p "$OUTF")"; NPASS=0
expect A-ledger-default 0 "PASS: $ONE" "" 0 "no --ledger: _bmad-output/spawn-ledger.jsonl under the cwd is read"

# (iii) residue artifact names a different story
mkworld 313; oneshot "$SLOT/$ONE"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
residue "$SLOT/$RES" "$ARCH_AFTER" "_bmad-output/planning-artifacts/s313/stories/story-3-2-some-other-story.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-iii 1 "FAIL: residue artifact:" "" 1 "(iii) residue artifact: names a different story -> FAIL"

# (iv) bug variant, no residue: not owed — and the variant set is read off the REAL route.md
mkworld 313; oneshot "$SLOT/$ONE"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --variant bug --route "$ROUTE"
expect A-iv 0 "NOT-OWED: variant 'bug' runs no architecture step" "" 1 "(iv) bug variant, no residue -> NOT-OWED, never PASS"
# The legacy one-shot name in an ARCHITECTURE variant is a finding, never an opt-out (contract
# v3.2 D4). The reference consumer's own S313 file is this shape, byte for byte.
cp "$SLOT/$ONE" "$SLOT/bug-fix-oneshot.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/bug-fix-oneshot.md" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-legacy 1 "FAIL: legacy one-shot name in an architecture variant" "rename to bug-fix-oneshot-<slug>.md" 1 "legacy one-shot name, architecture variant -> FAIL with a rename remedy"

# (v) residue tool_use_id resolves to an ADVERSARY row, in-sprint, after the one-shot
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ADV_AFTER" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-v 1 "FAIL: residue tool_use_id $ADV_AFTER joins no architect dispatch" "role 'adversary' is not architect" 1 "(v) id resolves to an adversary row -> FAIL"

# (vi) the real impostor: an S313 architect row BEFORE the one-shot's invoked_at
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_BEFORE" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-vi 1 "FAIL: residue tool_use_id $ARCH_BEFORE joins no architect dispatch" "before the one-shot ran" 1 "(vi) architect row before the one-shot -> FAIL"

# The sprint clause: a real architect id from S311, cited by an S313 fold.
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_S311" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-sprint 1 "FAIL: residue tool_use_id $ARCH_S311 joins no architect dispatch" "sprint 311 is not S313" 1 "architect id from another sprint -> FAIL"

# An id no ledger row carries.
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ABSENT_ID" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-unknown 1 "FAIL: residue tool_use_id $ABSENT_ID resolves to NO spawn-ledger row" "" 1 "id carried by no ledger row -> FAIL"

# (vii) two residues citing one architect id — the discriminating residue is NOT first in glob order
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
residue "$SLOT/fold-architecture-aaa-other-fix.md" "$ARCH_AFTER" "_bmad-output/planning-artifacts/s313/stories/story-3-3-other.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-vii 1 "FAIL: fold-architecture-aaa-other-fix.md cites the same architect dispatch $ARCH_AFTER" "" 1 "(vii) two residues cite one architect id -> FAIL"
# Near-miss: the same two residues, two DIFFERENT after-the-one-shot architect ids.
residue "$SLOT/fold-architecture-aaa-other-fix.md" "$ARCH_AFTER2" "_bmad-output/planning-artifacts/s313/stories/story-3-3-other.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-vii-near 0 "PASS: $ONE -> $RES" "" 0 "two residues citing two different architect ids -> PASS"

# (viii) a sprint whose ledger rows carry no tool_use_id at all (real S310 rows)
mkworld 310; oneshot "$SLOT/$ONE" "2026-09-10T02:00:00Z" "_bmad-output/planning-artifacts/s310/stories/story-1-1-fix.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-viii 0 "SKIP-PRE-ADOPTION: the ledger carries no tool_use_id on any S310 row" "" 1 "(viii) no tool_use_id for the sprint -> SKIP-PRE-ADOPTION, never PASS"
# The mid-sprint adoption: real S311 carries ids on some rows and not others. A one-shot whose own
# tool_use_id joins no S311 adversary row may have been one of the id-less dispatches: SKIP...
mkworld 311; oneshot "$SLOT/$ONE" "2026-09-12T08:00:00Z" "_bmad-output/planning-artifacts/s311/stories/story-2-1-fix.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-viii-b 0 "SKIP-PRE-ADOPTION: $ONE cites tool_use_id" "PARTIALLY adopted" 1 "one-shot id not in a partially adopted sprint -> SKIP, never PASS"
# ...and one whose id joins the real S311 adversary at 18:40:01Z is JUDGED, against the real S311
# architect at 22:44:29Z. Ordering reads that ledger row, never invoked_at.
mkworld 311; oneshot "$SLOT/$ONE" "2026-09-12T17:30:00Z" "_bmad-output/planning-artifacts/s311/stories/story-2-1-fix.md" "$ADV_S311"
residue "$SLOT/$RES" "$ARCH_S311B" "_bmad-output/planning-artifacts/s311/stories/story-2-1-fix.md"
stamp "_bmad-output/planning-artifacts/s311/stories/story-2-1-fix.md" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-viii-near 0 "PASS: $ONE -> $RES" "in S311" 0 "one-shot id joins an S311 adversary row, architect after it -> judged, PASS"

# An EMPTY ledger is SKIP, never PASS; an ABSENT one is a refusal, never SKIP.
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; : > "$W/_bmad-output/spawn-ledger.jsonl"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect A-empty 0 "SKIP-PRE-ADOPTION: the ledger carries no tool_use_id on any S313 row" "" 1 "empty ledger -> SKIP-PRE-ADOPTION, never PASS"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/no-such-ledger.jsonl" $VARF
expect A-absent 2 "FAIL: no spawn ledger at" "" 1 "absent ledger -> exit 2 refusal, never SKIP"

# --- D1: ordering is anchored on the one-shot's OWN ledger row, never on invoked_at -------------
# BACKDATE precedes every S313 row. Under the old invoked_at ordering the stale architect at
# 21:58:16Z read as "after the one-shot"; its real own row is the adversary at 22:59:43Z.
mkworld 313; oneshot "$SLOT/$ONE" "$BACKDATE" "$STORY"; residue "$SLOT/$RES" "$ARCH_BEFORE" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect D1-1 1 "FAIL: residue tool_use_id $ARCH_BEFORE joins no architect dispatch" "its own ledger row, 2026-09-23T22:59:43Z" 1 "backdated invoked_at citing the architect BEFORE the one-shot's ledger row -> FAIL"
mkworld 313; oneshot "$SLOT/$ONE" "$BACKDATE" "$STORY"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect D1-2 0 "PASS: $ONE -> $RES" "own dispatch (2026-09-23T22:59:43Z)" 0 "backdated invoked_at, architect AFTER the one-shot's ledger row -> PASS, never SKIP"
mkworld 313; oneshot "$SLOT/$ONE" "$INV" "$STORY" "$ABSENT_ID"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect D1-3 1 "FAIL: one-shot id not in the ledger" "every S313 row carries an id" 1 "fully adopted sprint, one-shot id not in the ledger -> exit 1"
S311_STORY="_bmad-output/planning-artifacts/s311/stories/story-2-1-fix.md"
mkworld 311; oneshot "$SLOT/$ONE" "$INV" "$S311_STORY" "$ABSENT_ID"; residue "$SLOT/$RES" "$ARCH_S311B" "$S311_STORY"; stamp "$S311_STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect D1-4 0 "SKIP-PRE-ADOPTION: $ONE cites tool_use_id '$ABSENT_ID'" "PARTIALLY adopted" 1 "partially adopted sprint, one-shot id not in the ledger -> SKIP, no PASS line"

# --- D4: the legacy name is judged by the variant the SNAPSHOT names ---------------------------
mkworld 313; oneshot "$SLOT/bug-fix-oneshot.md"; snapshot "$W" carry-over
drive --fold-architect "$SLOT/$RES" "$SLOT/bug-fix-oneshot.md" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect D4-arch 1 "FAIL: legacy one-shot name in an architecture variant" "rename to bug-fix-oneshot-<slug>.md" 1 "legacy name, carry-over snapshot -> exit 1 with the rename remedy"
snapshot "$W" bug
drive --fold-architect "$SLOT/$RES" "$SLOT/bug-fix-oneshot.md" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect D4-bug 0 "NOT-OWED: variant 'bug' runs no architecture step" "" 1 "legacy name, bug snapshot -> NOT-OWED, never PASS"

# --- the variant is READ from the snapshot, never typed ---------------------------------------
mkworld 313; oneshot "$SLOT/$ONE"; snapshot "$W" carry-over
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect V-carry 1 "FAIL: no residue" "" 1 "carry-over snapshot, no --variant, no residue -> owed, FAIL"
snapshot "$W" bug
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect V-bug 0 "NOT-OWED: variant 'bug' runs no architecture step" "variant from _bmad-output/pipeline-snapshot.md" 1 "bug snapshot, no --variant -> NOT-OWED read from the snapshot"
snapshot "$W" brownfield-z
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect V-unknown 2 "FAIL: variant 'brownfield-z'" "never NOT-OWED" 1 "unknown variant in the snapshot -> exit 2, never NOT-OWED"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE" --variant brownfield-z
expect V-unknown-flag 2 "FAIL: variant 'brownfield-z'" "never NOT-OWED" 1 "unknown --variant -> exit 2, never NOT-OWED"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE" --snapshot "$W/_bmad-output/no-such-snapshot.md"
expect V-nosnap 2 "FAIL: no pipeline snapshot at" "" 1 "--snapshot naming no file -> exit 2"
# --- DEFECT 3: a snapshot carrying no parseable pipeline_variant line falls through -------------
# The reference consumer's snapshot history spells the variant `- **Variant:** bug` in revisions
# that carry no `pipeline_variant:` line at all. Such a snapshot used to exit 2 before NOT-OWED was
# decided. It now falls through to sprint-status.yaml's top-level `variant:`, and with neither it
# is OWED -- never NOT-OWED by default.
mkworld 313; oneshot "$SLOT/$ONE"; mkdir -p "$W/_bmad-output"
printf '%s\n' '# Pipeline Snapshot' '' '## Pipeline Position' '- **Variant:** bug' \
  '- **Current step:** implementation.md' > "$W/_bmad-output/pipeline-snapshot.md"
grep -q 'pipeline_variant' "$W/_bmad-output/pipeline-snapshot.md" \
  && { echo "FIXTURE BROKEN: the DEFECT 3 snapshot carries a pipeline_variant line" >&2; exit 1; }
sstatus "$W" bug 313
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect V-legacy-bug 0 "NOT-OWED: variant 'bug' runs no architecture step" "variant from _bmad-output/implementation-artifacts/sprint-status.yaml" 1 \
  "snapshot spelling only '- **Variant:** bug', sprint-status bug -> NOT-OWED read from sprint-status, never exit 2"
rm -f "$W/_bmad-output/implementation-artifacts/sprint-status.yaml"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect V-legacy-none 1 "FAIL: no residue" "" 1 "the same snapshot and no sprint-status -> the fold is OWED, FAIL on no residue"

# (No snapshot and no --variant holds the fold OWED: A-default, driven from a world with none.)
[ ! -e "$WORK/w2/_bmad-output/pipeline-snapshot.md" ] && [ -f "$WORK/w2/_bmad-output/spawn-ledger.jsonl" ] \
  || { echo "FIXTURE BROKEN: A-default's world is not the snapshot-less world it claims" >&2; exit 1; }

# --- D5: artifact compared by FULL path --------------------------------------------------------
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "other-dir/$(basename "$STORY")"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect D5-otherdir 1 "FAIL: residue artifact: 'other-dir/" "" 1 "residue artifact: other-dir/<same basename> -> FAIL"
residue "$SLOT/$RES" "$ARCH_AFTER" "./$STORY"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect D5-dot 0 "PASS: $ONE -> $RES" "" 0 "residue artifact: with a leading ./ -> PASS"

# --- D6: a value-taking flag given last with no value exits 2, under a watchdog -----------------
# A background run plus a sentinel the run writes on exit; never a process-table grep. A timeout
# reaps the tree (the subshell's children, then the subshell) and is a hang FAIL, never a SKIP.
for flag in --ledger --sprint --settings --probe --variant --route --snapshot; do
  o="$WORK/d6${flag}.out"; s="$WORK/d6${flag}.rc"
  ( bash "$VSL" --fold-architect "$WORK/x/fold-architecture-z.md" "$WORK/x/bug-fix-oneshot-z.md" "$flag" \
      > "$o" 2>&1; echo $? > "$s" ) &
  wpid=$!; n=0
  while [ ! -s "$s" ] && [ "$n" -lt 150 ]; do sleep 0.1; n=$((n+1)); done
  if [ ! -s "$s" ]; then
    pkill -P "$wpid" 2>/dev/null; kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
    bad "[D6$flag] HANG: $flag with no value did not exit within 15s"
    continue
  fi
  wait "$wpid" 2>/dev/null
  frc="$(cat "$s")"
  if [ "$frc" = 2 ] && grep -qF -- "FAIL: $flag takes" "$o"; then ok "[D6$flag] $flag given last with no value -> exit 2"
  else bad "[D6$flag] $flag given last with no value -> exit 2 -- rc=$frc"; fi
done

# --- D3: the retired-pin remedy on a fold residue says the RESIDUE is wrong --------------------
mkworld 313; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"
sed 's/^skill: bmad-review-adversarial-general$/skill: ai-dlc-adversary-review/' "$SLOT/$RES" > "$WORK/d3.tmp" && mv "$WORK/d3.tmp" "$SLOT/$RES"
cp "$SLOT/$RES" "$SLOT/story-review-$SLUG.md"
grep -qx 'skill: ai-dlc-adversary-review' "$SLOT/$RES" || { echo "FIXTURE BROKEN: the D3 seed's skill rewrite did not apply" >&2; exit 1; }
bash "$VPB" "$SLOT/$RES" --require-skill bmad-review-adversarial-general > "$WORK/d3f.out" 2>&1; d3f=$?
bash "$VPB" "$SLOT/story-review-$SLUG.md" --require-skill bmad-review-adversarial-general > "$WORK/d3o.out" 2>&1; d3o=$?
if [ "$d3f" = 1 ] && grep -qF 'the RESIDUE is wrong' "$WORK/d3f.out" && ! grep -qF 'Repoint' "$WORK/d3f.out"; then
  ok "[D3-fold] fold residue citing ai-dlc-adversary-review -> the residue is wrong, never Repoint"
else bad "[D3-fold] fold residue citing ai-dlc-adversary-review -> the residue is wrong, never Repoint -- rc=$d3f"; fi
if [ "$d3o" = 1 ] && grep -qF 'Repoint' "$WORK/d3o.out" && ! grep -qF 'the RESIDUE is wrong' "$WORK/d3o.out"; then
  ok "[D3-other] the same block outside a fold path -> Repoint"
else bad "[D3-other] the same block outside a fold path -> Repoint -- rc=$d3o"; fi


# --- the manifest: an implementation gate loads Check 17 -----------------------------------------
gs_planned() {  # <type> -> sets GSRC, GSSRC and GSIDS (planned ids, one per line). Not in $( ):
  # an assignment made inside a command substitution is lost to the subshell.
  bash "$GS" --type "$1" --file "$GV" --format json > "$WORK/gs.$1.json" 2>/dev/null; GSRC=$?
  GSSRC="$(jq -r '.manifest_source // ""' "$WORK/gs.$1.json" 2>/dev/null)"
  GSIDS="$(jq -r '.planned[]? | tostring' "$WORK/gs.$1.json" 2>/dev/null)"
}
gs_planned implementation; impl="$GSIDS"; irc=$GSRC; isrc=$GSSRC
if [ "$isrc" != "core" ] && [ -n "$isrc" ]; then
  sd "[G1] stands down: this tree's GATE_MANIFEST is shadowed by $isrc, which is the consumer's own"
else
  if [ "$irc" -eq 0 ] && grep -qx 22 <<<"$impl" && grep -qx 17 <<<"$impl"; then
    ok "[G1] gate-slice.sh --type implementation plans Check 17 (control: plans 22)"
  else bad "[G1] gate-slice.sh --type implementation plans Check 17 (control: plans 22) -- rc=$irc"; fi
fi
gs_planned sprint-review; srv="$GSIDS"; src=$GSRC
if [ "$src" -eq 0 ] && grep -qx 18 <<<"$srv" && ! grep -qx 17 <<<"$srv"; then
  ok "[G2] near-miss: --type sprint-review plans 18 and NOT 17, so G1's reader can say absent"
else bad "[G2] near-miss: --type sprint-review plans 18 and NOT 17 -- rc=$src"; fi

# --- Check 17's fold bullet is its OWN arm, and the writer and reader name one path -----------
# Its own parenthetical is what keeps I32's greedy `.*--require-skill` parsing the bug-fix
# bullet's pin: folded into that bullet, the arm would carry two pins and I32 would read the
# LAST — and since both pins name the same skill, I32 could not notice. This arm can.
c17_bullet() {  # <header prefix> -> the bullet's joined text, Check 17 span only
  awk -v h="$1" '/<!-- CHECK_LOADED: 17 -->/ { s = 1 } /<!-- CHECK_LOADED: 18 -->/ { s = 0 }
       s && /^\*\*PASS:/ { s = 0 }
       s && /^- \*\*/ { b = (index($0, h) == 1); if (b) n++ }
       s && b { printf "%s ", $0 } END { print ""; print n + 0 > "/dev/stderr" }' "$GV"
}
fold_txt="$(c17_bullet '- **Fold architecture gate (bug-investigation):**' 2>"$WORK/nf")"; nfold="$(cat "$WORK/nf")"
bug_txt="$(c17_bullet '- **Bug-fix story readiness gate (bug-investigation):**' 2>"$WORK/nb")"; nbug="$(cat "$WORK/nb")"
b1=1
[ "$nfold" = 1 ] && [ "$nbug" = 1 ] || b1=0
case "$fold_txt" in *"--require-skill"*"bmad-review-adversarial-general"*) : ;; *) b1=0 ;; esac
case "$fold_txt" in *"--fold-architect"*) : ;; *) b1=0 ;; esac
case "$bug_txt"  in *"--require-skill"*) : ;; *) b1=0 ;; esac
case "$bug_txt"  in *"--fold-architect"*|*"fold-architecture-"*) b1=0 ;; esac
if [ "$b1" -eq 1 ]; then ok "[B1] Check 17 carries the fold architecture gate as its own bullet, apart from the bug-fix bullet"
else bad "[B1] Check 17 carries the fold architecture gate as its own bullet -- fold bullets=$nfold bug-fix bullets=$nbug"; fi

if [ "$nfold" != 1 ]; then
  sd "[B2] stands down: B1 owns a missing or duplicated fold bullet"
elif bind_holds "$BI" "$GV"; then
  ok "[B2] bug-investigation section 4 and Check 17's fold bullet name one residue path: $(writer_path "$BI")"
else
  bad "[B2] writer-reader bind -- writer='$(writer_path "$BI" | tr '\n' ' ')' reader='$(reader_path "$GV" | tr '\n' ' ')'"
fi

dfv="$(directfold_verdict "$BI")"
set -- $dfv
if [ "$1" = 1 ] && [ "$3" = 0 ] && [ "$4" = 2 ]; then
  ok "[DF] bug-investigation section 4's direct-fold paragraph cites both Check 17 bullets and types no fold or residue command ($2 backticked commands)"
else bad "[DF] direct-fold paragraph -- paragraphs=$1 commands=$2 offending=$3 bullets cited=$4"; fi

# --- B1 and D5: Check 17's documented commands, EXTRACTED by section and EXECUTED ---------------
# c17_cmds <header prefix>: the backticked `scripts/ai-dlc/...` commands of one Check 17 bullet,
# one per line, the bullet's lines joined with their indentation collapsed.
c17_cmds() {
  awk -v h="$1" '/<!-- CHECK_LOADED: 17 -->/ { s = 1 } /<!-- CHECK_LOADED: 18 -->/ { s = 0 }
       s && /^\*\*PASS:/ { s = 0 }
       s && /^- \*\*/ { b = (index($0, h) == 1) }
       s && b { l = $0; sub(/^[ \t]+/, "", l); printf "%s ", l } END { print "" }' "$GV" \
    | grep -oE '`scripts/ai-dlc/[^`]*`' | tr -d '`'
}
c17_text() {
  awk -v h="$1" '/<!-- CHECK_LOADED: 17 -->/ { s = 1 } /<!-- CHECK_LOADED: 18 -->/ { s = 0 }
       s && /^\*\*PASS:/ { s = 0 }
       s && /^- \*\*/ { b = (index($0, h) == 1) }
       s && b { l = $0; sub(/^[ \t]+/, "", l); printf "%s ", l } END { print "" }' "$GV"
}
H_BUG='- **Bug-fix story readiness gate (bug-investigation):**'
H_IMPL='- **Implementation gate, declared folded bug-fix stories (implementation):**'
H_FOLD='- **Fold architecture gate (bug-investigation):**'
# The implementation-gate command set, resolved from the bullet itself: its own backticked
# commands, plus the fold bullet's commands because it names "the fold architecture gate below".
impl_cmds() {
  local t; t="$(c17_text "$H_IMPL")"
  c17_cmds "$H_IMPL"
  case "$t" in *"fold architecture gate below"*) c17_cmds "$H_FOLD" ;; esac
}
# run_cmds <file of commands>: each executed from the world root $XW with its placeholders bound
# to the X* globals (xbind sets them; the defaults are the S313 carry-over world); sets CRC (the
# worst exit), CN (commands run), and writes each output to $WORK/cmd.<i>.out.
xbind() {  # <world> <sprint> <story> <one-shot rel> <residue rel>
  XW="$1"; XN="$2"; XSTORY="$3"; XONE="$4"; XRES="$5"
}
run_cmds() {
  local line i=0 w
  CRC=0; CN=0
  rm -f "$WORK"/cmd.*.out
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    i=$((i+1))
    line="$(printf '%s\n' "$line" | sed -e "s|^scripts/ai-dlc/|$SD/|" -e "s|<story-file>|$XSTORY|g" \
      -e "s|<residue>|$XRES|g" -e "s|<one-shot>|$XONE|g" -e "s|s<N>|s$XN|g" -e "s|<slug>|$SLUG|g")"
    set -f; set -- $line; set +f
    ( cd "$XW" && bash "$@" ) > "$WORK/cmd.$i.out" 2>&1; w=$?
    [ "$w" -gt "$CRC" ] && CRC=$w
  done < "$1"
  CN=$i
}
# cmds_first <prefix>: 0 when some command's output OPENS with <prefix>. cmds_has <text>: 0 when
# some command's output carries <text>. cmds_npass: how many outputs carry a `PASS:` line.
cmds_first() { local f; for f in "$WORK"/cmd.*.out; do [ -f "$f" ] || continue; case "$(sed -n 1p "$f")" in "$1"*) return 0 ;; esac; done; return 1; }
cmds_has()   { local f; for f in "$WORK"/cmd.*.out; do [ -f "$f" ] && grep -qF -- "$1" "$f" && return 0; done; return 1; }
cmds_npass() { local f n=0; for f in "$WORK"/cmd.*.out; do [ -f "$f" ] && grep -q '^PASS:' "$f" && n=$((n+1)); done; echo "$n"; }
# dev_evidence <story rel>: what implementation.md makes the dev write into the story before gate1.
dev_evidence() {
  printf '%s\n' '' '## Scope Verification' '' '- core/rebalancer/burn.go: in scope (AC1).' '' \
    '## Dev Agent Record' '' '### Completion Notes' '- Narrowed the burn guard; AC1 test added.' >> "$W/$1"
  sed 's/^Status: ready-for-dev$/Status: review/' "$W/$1" > "$WORK/st.tmp" && mv "$WORK/st.tmp" "$W/$1"
  grep -qx 'Status: review' "$W/$1" || { echo "FIXTURE BROKEN: the Status: rewrite did not apply" >&2; exit 1; }
}
route_in_world() { mkdir -p "$W/.claude/skills/ai-dlc/steps"; cp "$ROUTE" "$W/.claude/skills/ai-dlc/steps/route.md"; }
# The B1 world: the reference consumer's one-shot, a story STAMPED by the shipped writer, the
# architect residue, a carry-over snapshot AND a carry-over sprint-status (the cross-check's
# agreeing near-miss), both in graph's grammar, and route.md at the consumer path the fold command
# names verbatim.
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; snapshot "$W" carry-over
sstatus "$W" carry-over 313; route_in_world; stamp "$STORY" "$(rel "$SLOT/$ONE")"
BWORLD="$W"
xbind "$W" 313 "$STORY" "_bmad-output/planning-artifacts/s313/$ONE" "_bmad-output/planning-artifacts/s313/$RES"
c17_cmds "$H_BUG" | grep -F 'stamp-story-provenance.sh' > "$WORK/xcheck.cmds"
impl_cmds > "$WORK/impl.cmds"
c17_cmds "$H_FOLD" > "$WORK/fold.cmds"
nx="$(grep -c . "$WORK/xcheck.cmds")" || nx=0
[ "$nx" = 1 ] && grep -qF -- '--profile bug-story-provenance --check' "$WORK/xcheck.cmds" \
  || { echo "FIXTURE BROKEN: Check 17's bug-fix bullet yields $nx cross-check commands, 1 expected" >&2; exit 1; }
# B1-pre, the control: straight after the stamp the cross-check holds.
run_cmds "$WORK/xcheck.cmds"
if [ "$CRC" = 0 ] && grep -qF 'OK (1 story file(s) current)' "$WORK/cmd.1.out"; then
  ok "[B1-pre] before any dev evidence, the extracted cross-check PASSES on the stamped story"
else bad "[B1-pre] before any dev evidence, the extracted cross-check PASSES -- rc=$CRC"; fi
dev_evidence "$STORY"
# The implementation bullet includes the fold bullet by reference, so a missing fold bullet is
# B1's finding and this arm stands down for it. The set is the story's shape check plus the ONE
# fold command: two, and neither is the cross-check.
if [ "$nfold" != 1 ]; then
  sd "[B1-impl] stands down: B1 owns a missing or duplicated fold bullet"
else
run_cmds "$WORK/impl.cmds"; icrc=$CRC; icn=$CN
if [ "$icrc" = 0 ] && [ "$icn" = 2 ] && cmds_first "PASS: $ONE -> $RES" && ! grep -qF 'stamp-story-provenance.sh' "$WORK/impl.cmds"; then
  ok "[B1-impl] after dev evidence, Check 17's implementation-gate command set (2, extracted) PASSES"
else bad "[B1-impl] after dev evidence, the implementation-gate command set PASSES -- worst rc=$icrc commands=$icn"; fi
fi
run_cmds "$WORK/xcheck.cmds"
if [ "$CRC" = 1 ] && grep -qF 'DRIFT' "$WORK/cmd.1.out"; then
  ok "[B1-drift] after dev evidence, the cross-check DRIFTS: the implementation gate must not run it"
else bad "[B1-drift] after dev evidence, the cross-check DRIFTS -- rc=$CRC"; fi
# D5: the fold bullet's documented command, verbatim, on the correct world and a no-residue one.
# A missing or duplicated fold bullet is B1's finding; these stand down for it, as B2 does.
nf="$(grep -c . "$WORK/fold.cmds")" || nf=0
if [ "$nfold" != 1 ]; then
  sd "[D5-cmd-pass] stands down: B1 owns a missing or duplicated fold bullet"
  sd "[D5-cmd-fail] stands down: B1 owns a missing or duplicated fold bullet"
  sd "[D5-cmd-skill] stands down: B1 owns a missing or duplicated fold bullet"
else
run_cmds "$WORK/fold.cmds"
if [ "$CRC" = 0 ] && cmds_first "PASS: $ONE -> $RES" && cmds_has "the residue's block passes validate-provenance-block.sh"; then
  ok "[D5-cmd-pass] the fold bullet's documented command, executed, PASSES on the correct world"
else bad "[D5-cmd-pass] the fold bullet's documented command PASSES on the correct world -- commands=$nf worst rc=$CRC"; fi
rm -f "$BWORLD/_bmad-output/planning-artifacts/s313/$RES"
run_cmds "$WORK/fold.cmds"
if [ "$CRC" = 1 ] && cmds_first 'FAIL: no residue' && [ "$(cmds_npass)" = 0 ]; then
  ok "[D5-cmd-fail] the same command FAILS on the no-residue world"
else bad "[D5-cmd-fail] the same command FAILS on the no-residue world -- commands=$nf worst rc=$CRC"; fi
# B-1's residue shape: a residue whose ledger half joins but whose block cites the wrong skill. The
# fold bullet documents ONE command, so the refusal can only come from the script's INTERNAL call
# to validate-provenance-block.sh with its pin -- a dropped pin, or a pin on the wrong file, reads
# PASS here.
residue "$BWORLD/_bmad-output/planning-artifacts/s313/$RES" "$ARCH_AFTER" "$STORY"
sed 's/^skill: bmad-review-adversarial-general$/skill: ai-dlc-adversary-review/' "$BWORLD/_bmad-output/planning-artifacts/s313/$RES" > "$WORK/d5s.tmp" \
  && mv "$WORK/d5s.tmp" "$BWORLD/_bmad-output/planning-artifacts/s313/$RES"
grep -qx 'skill: ai-dlc-adversary-review' "$BWORLD/_bmad-output/planning-artifacts/s313/$RES" \
  || { echo "FIXTURE BROKEN: the D5-cmd-skill seed's skill rewrite did not apply" >&2; exit 1; }
run_cmds "$WORK/fold.cmds"
if [ "$nf" = 1 ] && [ "$CRC" = 1 ] && cmds_first "FAIL: residue $RES fails its shape check" \
   && cmds_has 'bmad-review-adversarial-general was specified, but no block cites it' && [ "$(cmds_npass)" = 0 ]; then
  ok "[D5-cmd-skill] the ONE fold command FAILS a residue citing the wrong skill, through its internal shape check"
else bad "[D5-cmd-skill] the ONE fold command FAILS a residue citing the wrong skill -- commands=$nf worst rc=$CRC"; fi
fi

# --- B-1: the EXTRACTED commands in a world that owes NO fold ---------------------------------
# The blocker this round closes: every variant writes the per-bug one-shot, so a plain bug-variant
# fix story is a DECLARED folded story, and the gate's command set used to read a residue the bug
# variant never writes. So the commands run here are the ones Check 17 documents, extracted, in a
# `bug` world and in an id-less sprint -- never only in the carry-over world above -- with dev
# evidence written, as it is at every implementation gate, and NO residue on disk.
b1_world_arm() {  # <id> <first-line prefix> <description>
  local irc icn frc
  if [ "$nfold" != 1 ]; then sd "[$1] stands down: B1 owns a missing or duplicated fold bullet"; return; fi
  [ ! -e "$XW/$XRES" ] || { echo "FIXTURE BROKEN: the $1 world carries a residue" >&2; exit 1; }
  run_cmds "$WORK/impl.cmds"; irc=$CRC; icn=$CN
  local ifirst=0 inpass; cmds_first "$2" && ifirst=1; inpass="$(cmds_npass)"
  run_cmds "$WORK/fold.cmds"; frc=$CRC
  local ffirst=0 fnpass; cmds_first "$2" && ffirst=1; fnpass="$(cmds_npass)"
  if [ "$irc" = 0 ] && [ "$icn" = 2 ] && [ "$ifirst" = 1 ] && [ "$inpass" = 0 ] \
     && [ "$frc" = 0 ] && [ "$ffirst" = 1 ] && [ "$fnpass" = 0 ]; then
    ok "[$1] $3"
  else bad "[$1] $3 -- impl worst rc=$irc commands=$icn first=$ifirst; fold rc=$frc first=$ffirst"; fi
}
mkworld 313; oneshot "$SLOT/$ONE"; snapshot "$W" bug; sstatus "$W" bug 313; route_in_world
stamp "$STORY" "$(rel "$SLOT/$ONE")"; dev_evidence "$STORY"
xbind "$W" 313 "$STORY" "_bmad-output/planning-artifacts/s313/$ONE" "_bmad-output/planning-artifacts/s313/$RES"
b1_world_arm B1-bug "NOT-OWED: variant 'bug' runs no architecture step" \
  "bug world, stamped story, no residue: the extracted implementation-gate set and fold command -> worst rc 0, NOT-OWED"
S310_STORY="_bmad-output/planning-artifacts/s310/stories/story-1-1-fix.md"
mkworld 310; oneshot "$SLOT/$ONE" "2026-09-10T02:00:00Z" "$S310_STORY"; snapshot "$W" carry-over
sstatus "$W" carry-over 310; route_in_world; stamp "$S310_STORY" "$(rel "$SLOT/$ONE")"; dev_evidence "$S310_STORY"
xbind "$W" 310 "$S310_STORY" "_bmad-output/planning-artifacts/s310/$ONE" "_bmad-output/planning-artifacts/s310/$RES"
b1_world_arm B1-idless "SKIP-PRE-ADOPTION: the ledger carries no tool_use_id on any S310 row" \
  "id-less sprint, stamped story, no residue: the extracted implementation-gate set and fold command -> worst rc 0, SKIP"

# --- D-d: the legacy one-shot, reached through the EXTRACTED fold command -----------------------
# The fold bullet says a legacy s<N>/bug-fix-oneshot.md in the slot is run through that same
# command with the legacy residue path it names. That path is read off the bullet, not typed here.
LEG_RES="$(c17_text "$H_FOLD" | grep -oE '`_bmad-output/planning-artifacts/s<N>/fold-architecture\.md`' | tr -d '`' | sort -u)"
nleg="$(printf '%s\n' "$LEG_RES" | grep -c .)" || nleg=0
mkworld 313; oneshot "$SLOT/bug-fix-oneshot.md"; snapshot "$W" carry-over; route_in_world
xbind "$W" 313 "$STORY" "_bmad-output/planning-artifacts/s313/bug-fix-oneshot.md" "$LEG_RES"
if [ "$nfold" != 1 ]; then
  sd "[Dd-carry] stands down: B1 owns a missing or duplicated fold bullet"
  sd "[Dd-bug] stands down: B1 owns a missing or duplicated fold bullet"
else
run_cmds "$WORK/fold.cmds"
if [ "$nleg" = 1 ] && [ "$CRC" = 1 ] && cmds_first 'FAIL: legacy one-shot name in an architecture variant' && [ "$(cmds_npass)" = 0 ]; then
  ok "[Dd-carry] legacy one-shot in a carry-over slot, through the extracted fold command -> FAIL (legacy)"
else bad "[Dd-carry] legacy one-shot in a carry-over slot, through the extracted fold command -> FAIL -- legacy residues named=$nleg rc=$CRC"; fi
snapshot "$W" bug
run_cmds "$WORK/fold.cmds"
if [ "$nleg" = 1 ] && [ "$CRC" = 0 ] && cmds_first "NOT-OWED: variant 'bug' runs no architecture step" && [ "$(cmds_npass)" = 0 ]; then
  ok "[Dd-bug] the same legacy one-shot in a bug slot, through the extracted fold command -> NOT-OWED"
else bad "[Dd-bug] the same legacy one-shot in a bug slot -> NOT-OWED -- legacy residues named=$nleg rc=$CRC"; fi
fi

# --- D-a: the story's stamp carries the one-shot's own id --------------------------------------
# Re-pointed AFTER the stamp: the one-shot's tool_use_id moved to the real S313 adversary at
# 23:53:57Z, a later in-sprint adversary row, while the stamp still carries the original id.
# Without the equality the join reads the later row as the one-shot's own and PASSES.
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"; stamp "$STORY" "$(rel "$SLOT/$ONE")"
oneshot "$SLOT/$ONE" "$INV" "$STORY" "$ADV_AFTER"
[ "$(awk '/^tool_use_id:/ { print $2; exit }' "$SLOT/$ONE")" = "$ADV_AFTER" ] \
  || { echo "FIXTURE BROKEN: the D-a re-point did not apply" >&2; exit 1; }
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect Da-repoint 1 "FAIL: one-shot re-pointed after the story was stamped" "$ONE_ID" 1 "one-shot re-pointed to a later adversary row after the stamp -> FAIL"
# Unstamped: the story exists and carries no block at all.
mkworld 313; oneshot "$SLOT/$ONE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"
printf '%s\n' '# Story 3.1: Rebalancer burn block fix' '' 'Status: ready-for-dev' > "$W/$STORY"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect Da-unstamped 1 "FAIL: story not stamped" "carries no provenance block" 1 "story present but never stamped -> FAIL"

# --- D-b: the one-shot's id resolves to an in-sprint ARCHITECT row ------------------------------
# Fully adopted: the one-shot cites the real S313 architect at 21:58:16Z, the stamp copies it, and
# the residue cites an architect after it. Read as the one-shot's own row it would PASS.
mkworld 313; oneshot "$SLOT/$ONE" "$INV" "$STORY" "$ARCH_BEFORE"; residue "$SLOT/$RES" "$ARCH_AFTER" "$STORY"
stamp "$STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect Db-full 1 "FAIL: one-shot id not in the ledger as an adversary dispatch" "role architect (S313)" 1 "fully adopted: one-shot id on an architect row -> FAIL naming the role"
# Partially adopted: the real S311 architect at 17:39:24Z; the residue cites the one at 22:44:29Z.
mkworld 311; oneshot "$SLOT/$ONE" "2026-09-12T17:40:00Z" "$S311_STORY" "$ARCH_S311"; residue "$SLOT/$RES" "$ARCH_S311B" "$S311_STORY"
stamp "$S311_STORY" "$(rel "$SLOT/$ONE")"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" $VARF
expect Db-part 1 "FAIL: one-shot id not in the ledger as an adversary dispatch" "role architect (S311)" 1 "partially adopted: one-shot id on an architect row -> FAIL naming the role, never SKIP"

# --- D-c: the variant is cross-checked, and the snapshot reader skips fences and comments -------
# A false `bug` in the snapshot is the NOT-OWED opt-out; sprint-status disagrees, so it is refused.
mkworld 313; oneshot "$SLOT/$ONE"; snapshot "$W" bug; sstatus "$W" carry-over 313
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect Dc-disagree 2 "FAIL: variant disagreement: snapshot says bug, sprint-status says carry-over" "" 1 "snapshot bug vs sprint-status carry-over -> exit 2, never NOT-OWED"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE" \
  --sprint-status "$W/_bmad-output/implementation-artifacts/no-such-sprint-status.yaml"
expect Dc-nossfile 2 "FAIL: no sprint-status file at" "" 1 "--sprint-status naming an absent file -> exit 2"
# Decoys ABOVE the real `carry-over` line, one fenced and one in an HTML comment. No sprint-status,
# so the snapshot reader alone decides; either decoy winning reads NOT-OWED.
mkworld 313; oneshot "$SLOT/$ONE"; mkdir -p "$W/_bmad-output"
printf '%s\n' '# Pipeline Snapshot' '' 'Example of the line this file carries:' '```' '- pipeline_variant: bug' '```' '' \
  '## Pipeline Position' '- pipeline_variant: carry-over' '- current_step_file: retro.md' > "$W/_bmad-output/pipeline-snapshot.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect Dc-fence 1 "FAIL: no residue" "" 1 "fenced 'pipeline_variant: bug' above the real carry-over line -> owed, FAIL"
printf '%s\n' '# Pipeline Snapshot' '' '<!-- template:' '- pipeline_variant: bug' '-->' '' \
  '## Pipeline Position' '- pipeline_variant: carry-over' '- current_step_file: retro.md' > "$W/_bmad-output/pipeline-snapshot.md"
drive --fold-architect "$SLOT/$RES" "$SLOT/$ONE" --ledger "$W/_bmad-output/spawn-ledger.jsonl" --route "$ROUTE"
expect Dc-comment 1 "FAIL: no residue" "" 1 "HTML-commented 'pipeline_variant: bug' above the real carry-over line -> owed, FAIL"

# --- verdict ---------------------------------------------------------------------------------
EXPECTED_ARMS=70
if [ $((asserted + stood)) -ne "$EXPECTED_ARMS" ]; then
  echo "FIXTURE BROKEN: $((asserted + stood)) arms reported, $EXPECTED_ARMS expected" >&2; exit 1
fi
echo "fold-architect-ledger-join: $((asserted - fails)) ok, $fails FAIL, $stood stood down"
[ "$fails" -eq 0 ]
