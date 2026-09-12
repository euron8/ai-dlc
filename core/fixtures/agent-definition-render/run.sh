#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# agent-definition-render/run.sh — prove render-agent-definitions.sh projects `aiDlcRoles` into
# `.claude/agents/<role>.md`, that `--check` discriminates a current projection from a drifted
# one, and that it neither defines a model-less role nor touches a definition it did not write.
#
# WHY THIS EXISTS. `.claude/agents/<role>.md` frontmatter is the ONLY channel that binds a
# subagent's reasoning effort, and it OUTRANKS the session's own resolution rather than filling
# a gap in it. Measured on the reference consumer, every spawn ran at the effort the SESSION
# resolved -- from its launch flag, or from the user's `effortLevel`/`modelSettings` -- and
# never at the role's. The dispatch guard's prompt sentence was read and had no effect, because
# effort is not something a prompt can set.
#
# WHAT THIS FIXTURE CANNOT SEE, STATED SO NOTHING READS IT AS COVERAGE. It cannot observe the
# delivered property -- that a spawn ran at the definition's effort -- because that needs a real
# subagent and a transcript. Every arm here checks a PROJECTION: the file the renderer wrote,
# and what `--check` says about it. The observation of the property itself is the subagent probe
# joined to the spawn ledger at Check 22, on a real consumer run.
#
# EVERY EXPECTATION IS DERIVED FROM THE SEEDED DECLARATION, never restated. An arm that listed
# the role names would pass while the renderer and the declaration drifted together away from
# it -- the hand-written list this whole mechanism replaces, reintroduced one layer down.
#
# Ships to consumers: the subject lands at `scripts/ai-dlc/render-agent-definitions.sh` via
# install.sh's copy loop over core/scripts/, so it is present there. TWO LAYOUTS, BOTH ROOTED
# THREE LEVELS UP FROM THIS FILE, AND NO VERSION-MARKER WALK (I106): an installed consumer has
# no VERSION at its root, so a walk for one resolves to nothing there and this would exit 2 on
# every consumer push.
#
# Exit: 0 = every assertion holds (or the subject is not installed yet), 1 = a regression,
#       2 = fixture broken.
set -uo pipefail

# The gate inherits every AI_DLC_* tunable a consumer set in settings.json. A fixture that drives
# a script while inheriting them tests the CONFIG, not the code (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: could not resolve project root three levels above $HERE" >&2; exit 2; }

SUBJECT=""
for cand in "$ROOT/core/scripts/render-agent-definitions.sh" \
            "$ROOT/scripts/ai-dlc/render-agent-definitions.sh"; do
  [ -f "$cand" ] && { SUBJECT="$cand"; break; }
done

echo "agent-definition-render"
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: it reaches a consumer on one pull and the code it
# guards may land on the next, so an absent subject reports SKIP rather than the green line that
# would read as "checked, and fine".
if [ -z "$SUBJECT" ]; then
  echo "  skip  render-agent-definitions.sh is not in this tree yet"
  echo "  0 failed, 1 skipped"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "  skip  jq is absent, so the expected role set cannot be derived from the declaration"
  echo "  0 failed, 1 skipped"
  exit 0
fi
# PRINT THE RESOLVED PATH. A mutant applied to the copy the run never loads leaves every arm
# green, which reads exactly like an arm that cannot fire.
echo "  subject: ${SUBJECT#"$ROOT"/}"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# fresh -> the PROJECT root of a new scratch world. seed.sh prints the `mktemp` directory it
# created; the project lives one level inside it, and `drop` removes exactly what the seed
# printed. Deriving the thing to delete from the project path instead is how the first cut of
# this fixture came to aim `rm -rf` at the system TMPDIR.
SEED_WORLDS=""
fresh() {
  local w
  w="$(bash "$HERE/seed.sh")" || return 1
  [ -d "$w/project" ] || return 1
  SEED_WORLDS="$SEED_WORLDS$w
"
  printf '%s\n' "$w/project"
}
drop() { # <project-root>
  local p="$1" w="${1%/project}"
  [ "$w" != "$p" ] || return 0            # not the shape the seed produces: refuse to delete
  case "$w" in */tmp|/tmp|/var/folders/*/T|'') return 0 ;; esac
  rm -rf "$w"
}

render() { # <subject> <project> [args...]
  local subj="$1" p="$2"; shift 2
  bash "$subj" --root "$p" "$@" 2>&1
}

# THE SEED MUST BE ABLE TO EXPRESS EVERY DEFECT. Derived from the seeded declaration rather
# than assumed, so a future edit to seed.sh that flattens a distinction fails HERE, loudly,
# instead of quietly making four arms vacuous.
P0="$(fresh)" || { echo "FIXTURE BROKEN: seed.sh failed" >&2; exit 2; }
S0="$P0/.claude/settings.json"
WITH_MODEL="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model) | .key' "$S0")"
NO_MODEL="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model | not) | .key' "$S0")"
WITH_EFFORT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and (.value.effort // "" | test("^(low|medium|high|xhigh|max)$"))) | .key' "$S0" | sed -n 1p)"
NO_EFFORT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and (.value.effort == null)) | .key' "$S0" | sed -n 1p)"
BAD_EFFORT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and .value.effort and (.value.effort | test("^(low|medium|high|xhigh|max)$") | not)) | .key' "$S0" | sed -n 1p)"
N_WITH_MODEL="$(printf '%s\n' "$WITH_MODEL" | grep -c .)"
if [ -z "$WITH_EFFORT" ] || [ -z "$NO_EFFORT" ] || [ -z "$BAD_EFFORT" ] \
   || [ -z "${NO_MODEL// /}" ] || [ "$N_WITH_MODEL" -lt 2 ]; then
  echo "FIXTURE BROKEN: the seeded declaration yields with-effort='$WITH_EFFORT' no-effort='$NO_EFFORT' bad-effort='$BAD_EFFORT' no-model='$NO_MODEL' with-model=$N_WITH_MODEL — the arms below cannot discriminate" >&2
  drop "$P0"
  exit 2
fi
drop "$P0"

# ---------------------------------------------------------------------------------------
# The arms, as functions returning 0 when the property HOLDS. Each is PRESENCE-shaped -- it
# demands a specific file or line APPEAR -- so a subject replaced by `exit 0` fails it by
# construction rather than passing as a clean run. The two ABSENCE-shaped properties
# (`no file for a model-less role`, `no effort line for an invalid level`) each sit in an arm
# whose OTHER conjunct is a presence, so neither can be satisfied by a program that did nothing.
# ---------------------------------------------------------------------------------------

# Arm 1: every role WITH a resolvable model gets a definition naming that model KEY.
arm_renders_model_bearing_roles() {
  local p="$1" subj="$2" r want
  render "$subj" "$p" >/dev/null || return 1
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ -f "$p/.claude/agents/$r.md" ] || return 1
    want="$(jq -r --arg r "$r" '.aiDlcRoles[$r].model' "$p/.claude/settings.json")"
    grep -qxF -- "model: $want" "$p/.claude/agents/$r.md" || return 1
    grep -qxF -- "name: $r" "$p/.claude/agents/$r.md" || return 1
  done <<EOF
$WITH_MODEL
EOF
  return 0
}

# Arm 1b: THE FRONTMATTER IS STILL FRONTMATTER. The harness parses `---` … `---` at the very
# top of the file, and the generated marker is a BODY line: it has to sit AFTER the closing
# fence, or the `model:`/`effort:` lines stop being frontmatter and the definition silently
# binds nothing -- which is this whole mechanism failing while every other arm stays green,
# because they all read the lines and not their POSITION.
#
# ASSERTED AS LINE NUMBERS, NOT AS PRESENCE. `grep -q 'model:'` holds just as well over a file
# whose fences moved, and that is exactly the state this arm exists to refuse.
arm_marker_sits_below_the_frontmatter() {
  local p="$1" subj="$2" f n_open n_close n_model n_effort n_marker
  render "$subj" "$p" >/dev/null || return 1
  f="$p/.claude/agents/$WITH_EFFORT.md"
  [ -f "$f" ] || return 1
  n_open="$(grep -nxF -- '---' "$f" | sed -n 1p | cut -d: -f1)"
  n_close="$(grep -nxF -- '---' "$f" | sed -n 2p | cut -d: -f1)"
  n_model="$(grep -n '^model:' "$f" | sed -n 1p | cut -d: -f1)"
  n_effort="$(grep -n '^effort:' "$f" | sed -n 1p | cut -d: -f1)"
  n_marker="$(grep -n 'AI/DLC GENERATED' "$f" | sed -n 1p | cut -d: -f1)"
  [ -n "$n_open" ] && [ -n "$n_close" ] && [ -n "$n_model" ] && [ -n "$n_effort" ] && [ -n "$n_marker" ] || return 1
  [ "$n_open" -eq 1 ] || return 1                       # the fence opens the FILE
  [ "$n_model" -gt "$n_open" ] && [ "$n_model" -lt "$n_close" ] || return 1
  [ "$n_effort" -gt "$n_open" ] && [ "$n_effort" -lt "$n_close" ] || return 1
  [ "$n_marker" -gt "$n_close" ] || return 1            # the marker is a BODY line
  return 0
}

# Arm 2: a role with NO model gets NO file, and a role WITH one does. The partition's two
# halves in one arm, so the absence half cannot be satisfied by a subject that wrote nothing.
arm_no_file_for_model_less_role() {
  local p="$1" subj="$2" r
  render "$subj" "$p" >/dev/null || return 1
  [ -f "$p/.claude/agents/$WITH_EFFORT.md" ] || return 1
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ -e "$p/.claude/agents/$r.md" ] && return 1
  done <<EOF
$NO_MODEL
EOF
  return 0
}

# Arm 3: a VALID effort is rendered; a role with NO effort key gets NO effort line. Both
# directions, one property apart, in the same run.
arm_effort_line_tracks_the_declaration() {
  local p="$1" subj="$2" want
  render "$subj" "$p" >/dev/null || return 1
  want="$(jq -r --arg r "$WITH_EFFORT" '.aiDlcRoles[$r].effort' "$p/.claude/settings.json")"
  grep -qxF -- "effort: $want" "$p/.claude/agents/$WITH_EFFORT.md" || return 1
  [ -f "$p/.claude/agents/$NO_EFFORT.md" ] || return 1
  grep -q '^effort:' "$p/.claude/agents/$NO_EFFORT.md" && return 1
  return 0
}

# Arm 4: an INVALID effort is OMITTED from the file and REPORTED on stderr, while the rest of
# that role's definition is still written. A level the harness does not accept is worse than
# none: the harness's own fallback is silent and the file reads as though it bound something.
arm_invalid_effort_omitted_and_reported() {
  local p="$1" subj="$2" err
  err="$(bash "$subj" --root "$p" 2>&1 >/dev/null)"
  [ -f "$p/.claude/agents/$BAD_EFFORT.md" ] || return 1
  grep -q '^effort:' "$p/.claude/agents/$BAD_EFFORT.md" && return 1
  grep -q 'invalid effort' <<<"$err" || return 1
  grep -qF -- "$BAD_EFFORT" <<<"$err" || return 1
  return 0
}

# Arm 5: the declaration and its projection are BYTE-JOINED, and `--check` is what holds them
# together. Four worlds in one arm: fresh (green), the SETTINGS entry moved (red), the
# DEFINITION hand-edited (red), and a re-render (green again).
#
# ONE ARM AND NOT TWO, WHICH IS A CORRECTION THIS FIXTURE MADE AGAINST ITSELF. The two drift
# directions were written as separate arms, and the mutant that deletes the comparison killed
# both -- correctly, because there is only one comparison. Two arms failing together cannot say
# which is load-bearing, and `fixture-mutants.md` is explicit that where both findings are true
# the ARMS overlap rather than the mutant being wrong: one of them owns the case and the other
# stands down. Here neither could stand down without dropping a seed, so they are one arm with
# both seeds instead.
#
# THE FINAL WORLD IS NOT DECORATION. An arm that only ever drives `--check` to RED establishes
# that the standard is violable and never that it is SATISFIABLE, and an unsatisfiable gate is
# one an operator switches off.
arm_check_joins_declaration_to_projection() {
  local p="$1" subj="$2" f rc_fresh rc_settings rc_handedit rc_moved rc_after
  render "$subj" "$p" >/dev/null || return 1
  render "$subj" "$p" --check >/dev/null 2>&1; rc_fresh=$?

  jq --arg r "$WITH_EFFORT" '.aiDlcRoles[$r].effort = "low"' "$p/.claude/settings.json" > "$p/.s.new" || return 1
  mv "$p/.s.new" "$p/.claude/settings.json"
  render "$subj" "$p" --check >/dev/null 2>&1; rc_settings=$?

  render "$subj" "$p" >/dev/null || return 1
  printf 'effort: max\n' >> "$p/.claude/agents/$WITH_EFFORT.md"
  render "$subj" "$p" --check >/dev/null 2>&1; rc_handedit=$?

  # FOURTH WORLD: the MARKER LINE hoisted above the opening fence, every frontmatter key left
  # byte-identical. This is the one edit that keeps `model:` and `effort:` present while the
  # harness stops reading them as frontmatter at all -- the definition then binds NOTHING and
  # looks entirely correct to any checker that greps for keys. It is a world and not its own
  # arm because the thing that CATCHES it is the byte comparison this arm already owns: given
  # its own arm, the mutant that deletes that comparison killed both, which is entanglement
  # rather than two findings.
  render "$subj" "$p" >/dev/null || return 1
  f="$p/.claude/agents/$WITH_EFFORT.md"
  { grep -F 'AI/DLC GENERATED' "$f"; grep -vF 'AI/DLC GENERATED' "$f"; } > "$f.moved" || return 1
  mv "$f.moved" "$f"
  grep -q '^model:' "$f" && grep -q '^effort:' "$f" || return 1   # control: the keys are all still there
  render "$subj" "$p" --check >/dev/null 2>&1; rc_moved=$?

  render "$subj" "$p" >/dev/null || return 1
  render "$subj" "$p" --check >/dev/null 2>&1; rc_after=$?

  [ "$rc_fresh" -eq 0 ] && [ "$rc_settings" -eq 1 ] && [ "$rc_handedit" -eq 1 ] \
    && [ "$rc_moved" -eq 1 ] && [ "$rc_after" -eq 0 ]
}

# Arm 7: an UNMARKED foreign definition is neither reported nor deleted, in either mode.
# A consumer may have agents of its own and they are none of this renderer's business.
arm_foreign_definition_untouched() {
  local p="$1" subj="$2" out before
  before="$p/.own.before"
  cp "$p/.claude/agents/my-own-helper.md" "$before" || return 1
  out="$(render "$subj" "$p")" || return 1
  cmp -s "$before" "$p/.claude/agents/my-own-helper.md" || return 1
  grep -q 'my-own-helper' <<<"$out" && return 1
  out="$(render "$subj" "$p" --check)" || return 1
  cmp -s "$before" "$p/.claude/agents/my-own-helper.md" || return 1
  grep -q 'my-own-helper' <<<"$out" && return 1
  # The presence conjunct: a definition the renderer DOES own was written in the same run, so
  # this arm cannot be satisfied by a subject that touched nothing at all.
  [ -f "$p/.claude/agents/$WITH_EFFORT.md" ] || return 1
  return 0
}

# Arm 8: a STALE generated projection -- a role that left aiDlcRoles -- is RED under --check and
# REMOVED by a write. The file keeps binding a model and an effort for a role the configuration
# no longer describes, because the harness reads the directory and not the settings.
arm_stale_projection_is_caught_and_cleared() {
  local p="$1" subj="$2" out rc
  render "$subj" "$p" >/dev/null || return 1
  jq --arg r "$NO_EFFORT" 'del(.aiDlcRoles[$r])' "$p/.claude/settings.json" > "$p/.s.new" || return 1
  mv "$p/.s.new" "$p/.claude/settings.json"
  out="$(render "$subj" "$p" --check)"; rc=$?
  [ "$rc" -eq 1 ] || return 1
  grep -q 'no longer in aiDlcRoles' <<<"$out" || return 1
  grep -qF -- "$NO_EFFORT" <<<"$out" || return 1
  render "$subj" "$p" >/dev/null || return 1
  [ -e "$p/.claude/agents/$NO_EFFORT.md" ] && return 1
  # THIS ARM STANDS DOWN ON THE FOREIGN FILE, DELIBERATELY. Asserting here that a hand-written
  # definition survived the sweep entangles this arm with arm 7, which OWNS that property: a
  # mutant widening the sweep past the generated marker then fails both, and two arms failing
  # together cannot say which one is load-bearing. Measured on the first cut of this fixture.
  # The presence conjunct that keeps this arm non-vacuous is the report text above, which a
  # subject emitting nothing cannot produce.
  return 0
}

# Arm 9: --check WRITES NOTHING, over a tree holding BOTH states it could be tempted to repair:
# one definition DRIFTED, and one MISSING ALTOGETHER.
#
# THE MISSING ONE IS WHY THIS ARM IS SEPARABLE FROM THE DRIFT ARMS. A `--check` that repairs a
# DRIFTED file is indistinguishable from one that cannot detect drift -- the same mutant kills
# arms 5, 6 and 10 as well, and four arms failing together cannot say which is load-bearing
# (measured on the first cut of this fixture). A `--check` that writes only the MISSING file
# while still REPORTING it is the wrong fix that changes no verdict anywhere else, and it is
# also the likelier one: "create it if it is not there" reads as helpfulness rather than as a
# gate mutating the tree it is reading. This arm owns that case and nothing else does.
arm_check_never_writes() {
  local p="$1" subj="$2" before after
  render "$subj" "$p" >/dev/null || return 1
  rm -f "$p/.claude/agents/$NO_EFFORT.md"
  jq --arg r "$WITH_EFFORT" '.aiDlcRoles[$r].effort = "low"' "$p/.claude/settings.json" > "$p/.s.new" || return 1
  mv "$p/.s.new" "$p/.claude/settings.json"
  before="$p/.digest.before"
  ( cd "$p/.claude/agents" && shasum -a 256 -- *.md ) > "$before" || return 1
  # PRESENCE CONJUNCT, ASSERTED BEFORE THE COMPARISON, AND KEYED ON A FILE THE RENDERER OWNS.
  # `[ -s "$before" ]` alone was NOT enough and the inert-subject probe proved it: the seed
  # plants a hand-written definition, so the digest is non-empty over a tree where the renderer
  # never wrote anything, and this arm passed against a subject replaced by `exit 0`. The
  # discriminating fact is that a definition the renderer PRODUCED is in the set being compared.
  grep -q " $WITH_EFFORT.md\$" "$before" || return 1
  render "$subj" "$p" --check >/dev/null 2>&1
  after="$p/.digest.after"
  ( cd "$p/.claude/agents" && shasum -a 256 -- *.md ) > "$after" || return 1
  cmp -s "$before" "$after" || return 1
  [ -e "$p/.claude/agents/$NO_EFFORT.md" ] && return 1
  return 0
}

# Arm 10: the three states are DISTINCT exit codes. A project with no aiDlcRoles is NOT
# APPLICABLE (3), a rendered one PASSes (0), a drifted one FAILs (1). Collapsing the first into
# a pass is what makes a gate print the same line for "nothing to look at" and "looked, clean".
arm_three_states_are_distinct() {
  local p="$1" subj="$2" rc_na rc_fail rc_pass
  jq 'del(.aiDlcRoles)' "$p/.claude/settings.json" > "$p/.s.new" || return 1
  cp "$p/.claude/settings.json" "$p/.s.orig" || return 1
  mv "$p/.s.new" "$p/.claude/settings.json"
  render "$subj" "$p" --check >/dev/null 2>&1; rc_na=$?
  cp "$p/.s.orig" "$p/.claude/settings.json" || return 1
  render "$subj" "$p" --check >/dev/null 2>&1; rc_fail=$?
  render "$subj" "$p" >/dev/null || return 1
  render "$subj" "$p" --check >/dev/null 2>&1; rc_pass=$?
  [ "$rc_na" -eq 3 ] && [ "$rc_fail" -eq 1 ] && [ "$rc_pass" -eq 0 ]
}

# Arm 11: idempotent. Four renders leave the SAME SET of files with the SAME BYTES.
#
# ASSERTED AS A SET AND A DIGEST, NEVER AS A COUNT. A count is a property of WHICH roles the
# renderer decided to define, which is arms 1 and 2's subject -- keying idempotence on it makes
# every mutation of the role decision fail this arm too, and the harness reports entanglement it
# is right to report. Measured on the first cut of this fixture: two mutants each moved three
# cells for exactly that reason. What idempotence owns is that running the program again changes
# nothing, and that is expressible without knowing what the first run produced.
arm_idempotent() {
  local p="$1" subj="$2" h1 h2
  render "$subj" "$p" >/dev/null || return 1
  h1="$( cd "$p/.claude/agents" && shasum -a 256 -- *.md )" || return 1
  # PRESENCE CONJUNCT, KEYED ON A FILE THE RENDERER OWNS. `[ -n "$h1" ]` was NOT enough and the
  # inert-subject probe proved it: the seed plants a hand-written definition, so two runs of a
  # subject replaced by `exit 0` produce identical non-empty digests and this arm passed. A
  # generated file must be IN the set whose stability is being asserted.
  grep -q " $WITH_EFFORT.md\$" <<<"$h1" || return 1
  for _ in 1 2 3; do render "$subj" "$p" >/dev/null || return 1; done
  h2="$( cd "$p/.claude/agents" && shasum -a 256 -- *.md )" || return 1
  [ "$h1" = "$h2" ] || return 1
  return 0
}

ARMS="renders_model_bearing_roles marker_sits_below_the_frontmatter no_file_for_model_less_role effort_line_tracks_the_declaration
invalid_effort_omitted_and_reported check_joins_declaration_to_projection
foreign_definition_untouched stale_projection_is_caught_and_cleared check_never_writes
three_states_are_distinct idempotent"

run_arms() { # <subject> -> "<name>:<0|1>" per arm, each on its own fresh project
  local subj="$1" name p rc
  for name in $ARMS; do
    p="$(fresh)" || { printf '%s:1\n' "$name"; continue; }
    "arm_$name" "$p" "$subj" >/dev/null 2>&1 && rc=0 || rc=1
    drop "$p"
    printf '%s:%s\n' "$name" "$rc"
  done
}

LIVE="$(run_arms "$SUBJECT")"
while IFS=: read -r name rc; do
  [ -n "$name" ] || continue
  case "$name" in
    renders_model_bearing_roles)         msg="every role with a resolvable model gets a definition naming that model KEY ($N_WITH_MODEL role(s))" ;;
    marker_sits_below_the_frontmatter)   msg="the model:/effort: lines sit INSIDE the frontmatter fences and the generated marker sits below them (asserted as line numbers)" ;;
    no_file_for_model_less_role)         msg="a role with NO model gets NO definition, while one with a model does (the party-persona partition)" ;;
    effort_line_tracks_the_declaration)  msg="a declared effort is rendered and an undeclared one produces no effort line" ;;
    invalid_effort_omitted_and_reported) msg="an invalid effort level is OMITTED from the file and named on stderr" ;;
    check_joins_declaration_to_projection) msg="--check joins the declaration to its projection: green fresh, red when the SETTINGS entry moves, red when the DEFINITION is hand-edited, red when its MARKER is hoisted above the fence with every key intact, green after a re-render" ;;
    foreign_definition_untouched)        msg="an unmarked consumer-written definition is neither reported nor deleted, in either mode" ;;
    stale_projection_is_caught_and_cleared) msg="a generated definition for a role that left aiDlcRoles is reported and removed" ;;
    check_never_writes)                  msg="--check over a DRIFTED tree writes nothing" ;;
    three_states_are_distinct)           msg="NOT APPLICABLE(3), drifted(1) and current(0) are three distinct exit codes" ;;
    idempotent)                          msg="four renders are byte-identical and leave no duplicate" ;;
    *)                                   msg="$name" ;;
  esac
  [ "$rc" -eq 0 ] && ok "$msg" || bad "$msg"
done <<EOF
$LIVE
EOF

# ---------------------------------------------------------------------------------------
# MUTANTS. Each is a COPY of the WHOLE core/scripts directory -- the subject resolves no
# siblings today, but a copy of one file is how a battery scores silence as a kill the day it
# does. Each mutation is guarded with `cmp -s` so a sed that matched nothing cannot pass as a
# mutation, and each names the ONE arm it must move.
# ---------------------------------------------------------------------------------------
MUTROOT="$(mktemp -d)"
trap 'rm -rf "$MUTROOT"' EXIT
SUBJ_DIR="$(dirname "$SUBJECT")"
SUBJ_BASE="$(basename "$SUBJECT")"
kills=0

mut() { # <label> <sed-expr> <arm-that-must-fail>
  local label="$1" expr="$2" want="$3"
  local dir="$MUTROOT/$label"
  local copy out rc others
  mkdir -p "$dir"
  cp "$SUBJ_DIR"/* "$dir/" 2>/dev/null
  copy="$dir/$SUBJ_BASE"
  [ -f "$copy" ] || { bad "MUTANT $label: the directory copy did not carry the subject"; return; }
  if ! sed -e "$expr" "$SUBJECT" > "$copy.new" 2>/dev/null; then
    # NO BACKTICKS IN THIS STRING. It is double-quoted, so a backticked word runs as a COMMAND
    # and the message becomes the text either side of a hole. This branch fires only when a sed
    # DIES, so it is never exercised on a green run and the defect would have shipped invisible.
    bad "MUTANT $label DID NOT APPLY: the sed died, so no mutant ever existed and the caller would have skipped its arms with no verdict"
    return
  fi
  mv "$copy.new" "$copy"
  if cmp -s "$SUBJECT" "$copy"; then
    bad "MUTANT $label: the sed matched NOTHING, so the subject was never mutated and this kill would have been fictional"
    return
  fi
  chmod +x "$copy"
  out="$(run_arms "$copy")"
  rc="$(printf '%s\n' "$out" | sed -n "s/^${want}://p")"
  if [ "$rc" = "1" ]; then
    kills=$((kills+1))
    others="$(printf '%s\n' "$out" | grep ':1$' | grep -v "^${want}:" | cut -d: -f1 | tr '\n' ' ')"
    if [ -n "${others// /}" ]; then
      bad "MUTANT $label killed by $want AND by: $others — those arms are entangled and at least one is not independently load-bearing"
    else
      ok "MUTANT $label killed by $want, and by that arm alone"
    fi
  else
    bad "MUTANT $label SURVIVED: $want still passes against a subject that no longer does the thing that arm asserts"
  fi
}

# M1: render a definition for EVERY declared role, model or not. This is the wrong fix a reader
# reaches for on seeing four roles in the config and fourteen files on disk -- and it binds an
# effort onto the party personas, whose spawns the dispatch guard is told to leave alone.
#
# TWO LINES, AND THE FIRST SPELLING MUTATED ONLY ONE OF THEM AND SURVIVED. Replacing the counter
# left the `continue` beneath it in place, so the branch still skipped and the mutant did nothing
# -- `cmp -s` saw a changed file and reported the mutation applied, correctly. The branch is
# `skipped_nomodel=...` FOLLOWED BY `continue`, and removing the property means removing both;
# the address is the counter, which is unique, and `n` carries the edit onto the `continue`,
# which is not (the unresolvable-key branch below carries one too).
mut renders-model-less-roles \
  '/^    skipped_nomodel=\$((skipped_nomodel+1))$/{s/.*/    mkey=opus/
n
s/^    continue$/    mstr=synthesised/
}' \
  no_file_for_model_less_role

# M2: accept any effort level, so a typo is written into the frontmatter as though it bound
# something. Keyed on the vocabulary case itself.
mut accepts-any-effort-level \
  's/^    low|medium|high|xhigh|max) return 0 ;;$/    *) return 0 ;;/' \
  invalid_effort_omitted_and_reported

# M3: --check compares nothing -- it reports current whenever the file EXISTS. A presence-only
# check is what a reader writes first, and it passes a definition whose settings entry moved.
#
# ANCHORED ON `cmp -s - "$target"`, NOT ON THE WHOLE LINE. The first spelling wrote the line out
# in full and matched NOTHING: a `|` inside a BRE is a literal pipe, not an alternation, but the
# `printf '%s\n'` in it carries quotes and a backslash that have to survive two levels of shell
# quoting, and they did not. The fixture caught it -- `cmp -s` reported the subject unmutated --
# rather than scoring a kill against a copy nothing had edited. A short unique anchor is both
# safer to quote and immune to reflowing the line around it.
mut check-is-presence-only \
  's#cmp -s - "$target"#true#' \
  check_joins_declaration_to_projection

# M4: drop the stale-projection sweep, so a role that left `aiDlcRoles` keeps its definition and
# keeps binding a model and an effort nobody configured. Anchored on the marker grep, which is
# the line that makes the sweep discriminate generated files from a consumer's own.
mut no-stale-sweep \
  's#^    grep -qF -- "\$GEN_PREFIX" "\$f" || continue$#    continue#' \
  stale_projection_is_caught_and_cleared

# M5: sweep EVERY .md in the agents directory rather than only the generated ones, so a
# consumer's hand-written definition is reported as stale and deleted. The mirror of M4, and
# the direction that destroys someone else's file. This is why the marker grep is load-bearing
# in both directions and why one mutation of it cannot stand for both.
mut sweeps-foreign-definitions \
  's#^    grep -qF -- "\$GEN_PREFIX" "\$f" || continue$#    :#' \
  foreign_definition_untouched

# M6: collapse NOT APPLICABLE into a pass. The single most likely "simplification", and it makes
# the gate print the same line for a project that pins no roles and one whose definitions are
# verified current.
mut not-applicable-reads-as-pass \
  's/^  echo "NOT APPLICABLE: \$SETTINGS declares no aiDlcRoles, so no roles are pinned here."$/  echo "OK: agent definitions current"; exit 0/' \
  three_states_are_distinct

# M7: make --check CREATE a missing definition while still reporting it missing. "Write it if it
# is not there" reads as helpfulness and is a gate mutating the tree it was called to read.
#
# SCOPED TO THE MISSING CASE ON PURPOSE. A mutant that re-rendered every file would also repair
# the DRIFTED ones and kill arms 5, 6 and 10 -- four cells for one mutation, which is
# entanglement rather than a kill. This one writes only where the file is absent, so the drift
# arms see an unchanged subject and arm 9 is the only cell that moves.
mut check-creates-the-missing-file \
  '/^      missing="\$missing \$role"$/i\
      printf '"'"'%s\\n'"'"' "$want" > "$target"
' \
  check_never_writes

# UNMUTATED CONTROL, with a POSITIVE conjunct. A control asserting only "nothing went wrong"
# passes against a subject replaced by `exit 0`, because rc=0 with nothing reported is exactly
# what a clean copy looks like. This one requires a named arm to be THERE and passing, and it is
# built the same way the mutants are -- a whole-directory copy -- so a partial tree that made
# every mutant survive would make this fail rather than agree with them.
mkdir -p "$MUTROOT/control"
cp "$SUBJ_DIR"/* "$MUTROOT/control/" 2>/dev/null
chmod +x "$MUTROOT/control/$SUBJ_BASE"
CTL="$(run_arms "$MUTROOT/control/$SUBJ_BASE")"
CTL_FAILS="$(printf '%s\n' "$CTL" | grep -c ':1$')"
CTL_FIRST="$(printf '%s\n' "$CTL" | sed -n 's/^renders_model_bearing_roles://p')"
if [ "$CTL_FAILS" -eq 0 ] && [ "$CTL_FIRST" = "0" ]; then
  ok "CONTROL: an unmutated whole-directory copy passes every arm, and renders_model_bearing_roles is affirmatively green"
else
  bad "CONTROL: an unmutated copy failed $CTL_FAILS arm(s) (renders_model_bearing_roles=$CTL_FIRST) — the harness is what is broken, not the subject, and every kill above is suspect"
fi

# ASSERT THE KILL COUNT IS NON-ZERO. A battery whose mutants all applied to a file the run never
# loaded reports the same silence as one whose arms cannot fire.
[ "$kills" -eq 0 ] && bad "NO MUTANT WAS KILLED. Either the mutations landed in a copy nothing executes, or none of these arms is load-bearing."

echo "  $fails failed, $kills mutant(s) killed"
[ "$fails" -eq 0 ] || exit 1
exit 0
