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
#
# MUTANT MATRIX (measured once, in a granted run slot, with every one of the 14 arms driven against
# every mutant). Per push each mutant now runs its DECIDING arm plus ONE named TWIN. The matrix
# recorded here REPLACES the exact-vector assertion that the other 12 arms stayed green: every
# mutant tripped its deciding arm and NO other arm (a 12 x 14 matrix of one 1 per row), so the
# twin is the arm nearest the mutant in subject, and mut() asserts the deciding arm FAILS and the
# twin PASSES. A change in co-tripping on the twin is still caught; co-tripping on the other
# twelve arms is no longer scored per push.
#   mutant                          | deciding arm                          | twin                                  | arms that tripped
#   renders-model-less-roles        | no_file_for_model_less_role           | renders_model_bearing_roles           | deciding only
#   accepts-any-effort-level        | invalid_effort_omitted_and_reported   | effort_line_tracks_the_declaration    | deciding only
#   check-is-presence-only          | check_joins_declaration_to_projection | check_never_writes                    | deciding only
#   no-stale-sweep                  | stale_projection_is_caught_and_cleared| foreign_definition_untouched          | deciding only
#   sweeps-foreign-definitions      | foreign_definition_untouched          | stale_projection_is_caught_and_cleared| deciding only
#   not-applicable-reads-as-pass    | three_states_are_distinct             | check_joins_declaration_to_projection | deciding only
#   check-creates-the-missing-file  | check_never_writes                    | check_joins_declaration_to_projection | deciding only
#   drops-omit-line                 | omit_claude_md_tracks_the_declaration | marker_sits_below_the_frontmatter     | deciding only
#   emits-omit-line-unconditionally | omit_claude_md_tracks_the_declaration | effort_line_tracks_the_declaration    | deciding only
#   accepts-any-omit-value          | omit_claude_md_tracks_the_declaration | invalid_effort_omitted_and_reported   | deciding only
#   skips-persona-names             | persona_with_model_is_defined         | renders_model_bearing_roles           | deciding only
#   drops-protected-read-line       | body_carries_protected_read_line      | marker_sits_below_the_frontmatter     | deciding only
# The unmutated CONTROL still drives all 14 arms.
#
# MUTANT-MATRIX renders-model-less-roles decides=no_file_for_model_less_role twins=renders_model_bearing_roles
# MUTANT-MATRIX accepts-any-effort-level decides=invalid_effort_omitted_and_reported twins=effort_line_tracks_the_declaration
# MUTANT-MATRIX check-is-presence-only decides=check_joins_declaration_to_projection twins=check_never_writes
# MUTANT-MATRIX no-stale-sweep decides=stale_projection_is_caught_and_cleared twins=foreign_definition_untouched
# MUTANT-MATRIX sweeps-foreign-definitions decides=foreign_definition_untouched twins=stale_projection_is_caught_and_cleared
# MUTANT-MATRIX not-applicable-reads-as-pass decides=three_states_are_distinct twins=check_joins_declaration_to_projection
# MUTANT-MATRIX check-creates-the-missing-file decides=check_never_writes twins=check_joins_declaration_to_projection
# MUTANT-MATRIX drops-omit-line decides=omit_claude_md_tracks_the_declaration twins=marker_sits_below_the_frontmatter
# MUTANT-MATRIX emits-omit-line-unconditionally decides=omit_claude_md_tracks_the_declaration twins=effort_line_tracks_the_declaration
# MUTANT-MATRIX accepts-any-omit-value decides=omit_claude_md_tracks_the_declaration twins=invalid_effort_omitted_and_reported
# MUTANT-MATRIX skips-persona-names decides=persona_with_model_is_defined twins=renders_model_bearing_roles
# MUTANT-MATRIX drops-protected-read-line decides=body_carries_protected_read_line twins=marker_sits_below_the_frontmatter
# MUTANT-MATRIX never-render decides=hook-world-A twins=hook-world-D
# MUTANT-MATRIX render-unconditionally decides=hook-world-D twins=hook-world-U
# MUTANT-MATRIX mkdir-before-render decides=hook-world-U twins=hook-world-A
# MUTANT-MATRIX-FULL skip-the-arm worlds=hook-world-A,hook-world-D,hook-world-C,hook-world-U why=measured: a skipped arm moves all four worlds (A unrendered, D unrefused, C no OK line, U exits 0), so no world is left green to serve as a twin
# MUTANT-MATRIX-DYNAMIC mut-hmut-label why=mut() and hmut() pass their first argument "$label" to mutant_killed; every caller (mut renders-model-less-roles ..., hmut never-render ...) names a literal mutant that carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/agent-definition-render/run.sh --matrix
# The matrix is re-measured whenever an arm or a mutant is added or changed. Under --matrix every
# mutant runs ALL 14 arms (or all four hook worlds) and prints one "MATRIX <mutant> ..." row per
# mutant, one cell per arm or world written <name>:<value>(killed=yes|no); the names in decides= and
# twins= are exactly those cell names (arms by their function suffix, worlds as hook-world-A, -D, -C
# and -U), and killed=yes means the arm FAILS, or the world's outcome DIFFERS from the shipped
# hook's. Every name above carries exactly one form. mut and hmut pass their first argument to
# mutant_killed as a variable, and every caller names it literally; hence the DYNAMIC line above. The exact-vector assertion (no other arm trips) is REPLACED by this recorded
# matrix plus the per-push twin.
#
# Exit: 0 = every assertion holds (or the subject is not installed yet), 1 = a regression,
#       2 = fixture broken.
set -uo pipefail

# --matrix (argv, never an env var) re-measures the mutant x arm matrix recorded in the header.
# A plain run executes NO matrix-only cell; MATRIX_CELLS counts the ones that ran and an arm at the
# foot asserts it is 0 on a plain run (and non-zero under --matrix, so the counter can fire).
MATRIX=0
for _a in "$@"; do [ "$_a" = "--matrix" ] && MATRIX=1; done
MATRIX_CELLS=0
# The --matrix row printers live in matrix.sh, beside this file: they spell the per-cell polarity,
# and a kill-token on a run.sh line must be routed through mutant_killed, which a printer is not.
MATRIX_SH="$(cd "$(dirname "$0")" && pwd)/matrix.sh"
[ -f "$MATRIX_SH" ] || { echo "FIXTURE BROKEN: matrix.sh not found beside run.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/agent-definition-render/matrix.sh"
# shellcheck source=/dev/null
. "$MATRIX_SH"

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
  echo "  FIXTURE BROKEN: jq is absent, so the expected role set cannot be derived from the declaration"
  echo "  0 failed, 1 broken"
  exit 2
fi
# PRINT THE RESOLVED PATH. A mutant applied to the copy the run never loads leaves every arm
# green, which reads exactly like an arm that cannot fire.
echo "  subject: ${SUBJECT#"$ROOT"/}"
echo "HERMETIC-CONSUMED ${SUBJECT#"$ROOT"/}"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
MUT_LIB="$ROOT/core/fixtures/lib/mutant.sh"
[ -f "$MUT_LIB" ] || MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# shellcheck source=/dev/null
. "$MUT_LIB"

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

# clone <project> <tag> -> a copy of a small project tree inside this subject's world, for an arm
# that MUTATES. The expensive part (seed.sh + a render) is paid once per subject; a mutating arm
# copies the result instead of rebuilding it.
clone() {
  local c="$WLD/$2/project"
  mkdir -p "$WLD/$2" && cp -R "$1" "$c" && printf '%s\n' "$c"
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
# THE PERSONA WITH A MODEL IS OWNED BY ITS OWN ARM, so arm 1's set excludes the four persona names:
# a mutant that skips personas would otherwise fail arm 1 too, which is entanglement, not two findings.
PERSONA_WITH_MODEL="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model) | select(.key | test("^(cis|sm|tea|ux)$")) | .key' "$S0" | sed -n 1p)"
WITH_MODEL="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model) | select(.key | test("^(cis|sm|tea|ux)$") | not) | .key' "$S0")"
NO_MODEL="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model | not) | .key' "$S0")"
WITH_EFFORT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and (.value.effort // "" | test("^(low|medium|high|xhigh|max)$"))) | .key' "$S0" | sed -n 1p)"
NO_EFFORT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and (.value.effort == null)) | .key' "$S0" | sed -n 1p)"
BAD_EFFORT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and .value.effort and (.value.effort | test("^(low|medium|high|xhigh|max)$") | not)) | .key' "$S0" | sed -n 1p)"
# The omitClaudeMd token sets, derived the same way -- `== true` for the offender because a
# declared `false` is a VALID value that renders nothing (so it belongs to no arm's world), and
# `== null` for the near-miss for exactly that reason. The invalid set carries an explicit
# `!= null` conjunct BECAUSE jq's `tostring` prints null as the STRING "null", which fails the
# true/false test -- without it the key-ABSENT role is scored as the key-INVALID one, and the
# measured first cut did exactly that: the arm failed its role-name conjunct on every mutant,
# every run, because no stderr line could ever name a role nothing had rejected. That is the
# same `//`-eats-`false` family as the loader's null-safe load, approached from the other side.
WITH_OMIT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.omitClaudeMd == true) | .key' "$S0" | sed -n 1p)"
NO_OMIT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and (.value.omitClaudeMd == null)) | .key' "$S0" | sed -n 1p)"
BAD_OMIT="$(jq -r '.aiDlcRoles | to_entries[] | select(.value.model and (.value.omitClaudeMd != null) and (.value.omitClaudeMd | tostring | test("^(true|false)$") | not)) | .key' "$S0" | sed -n 1p)"
N_WITH_MODEL="$(printf '%s\n' "$WITH_MODEL" | grep -c .)"
if [ -z "$WITH_EFFORT" ] || [ -z "$NO_EFFORT" ] || [ -z "$BAD_EFFORT" ] \
   || [ -z "$WITH_OMIT" ] || [ -z "$NO_OMIT" ] || [ -z "$BAD_OMIT" ] \
   || [ -z "${NO_MODEL// /}" ] || [ "$N_WITH_MODEL" -lt 2 ] || [ -z "$PERSONA_WITH_MODEL" ]; then
  echo "FIXTURE BROKEN: the seeded declaration yields with-effort='$WITH_EFFORT' no-effort='$NO_EFFORT' bad-effort='$BAD_EFFORT' with-omit='$WITH_OMIT' no-omit='$NO_OMIT' bad-omit='$BAD_OMIT' no-model='$NO_MODEL' with-model=$N_WITH_MODEL persona-with-model='$PERSONA_WITH_MODEL' — the arms below cannot discriminate" >&2
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
  [ "$SH_RC" -eq 0 ] || return 1                     # the ONE shared render of this subject
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

# Arm 1c: a PARTY PERSONA that sets a model is defined like any role -- its model key and its
# effort both rendered. The renderer keys on the model key alone, so this holds by construction
# today; the arm and its mutant (M11) exist so a fix that special-cases persona names fails here.
arm_persona_with_model_is_defined() {
  local p="$1" subj="$2" f m e
  [ "$SH_RC" -eq 0 ] || return 1                     # the ONE shared render of this subject
  f="$p/.claude/agents/$PERSONA_WITH_MODEL.md"
  [ -f "$f" ] || return 1
  m="$(jq -r --arg r "$PERSONA_WITH_MODEL" '.aiDlcRoles[$r].model' "$p/.claude/settings.json")"
  e="$(jq -r --arg r "$PERSONA_WITH_MODEL" '.aiDlcRoles[$r].effort' "$p/.claude/settings.json")"
  grep -qxF -- "model: $m" "$f" || return 1
  grep -qxF -- "effort: $e" "$f" || return 1
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
  [ "$SH_RC" -eq 0 ] || return 1                     # the ONE shared render of this subject
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
  [ "$SH_RC" -eq 0 ] || return 1                     # the ONE shared render of this subject
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
  [ "$SH_RC" -eq 0 ] || return 1                     # the ONE shared render of this subject
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
  err="$SH_ERR"
  [ -f "$p/.claude/agents/$BAD_EFFORT.md" ] || return 1
  grep -q '^effort:' "$p/.claude/agents/$BAD_EFFORT.md" && return 1
  grep -q 'invalid effort' <<<"$err" || return 1
  grep -qF -- "$BAD_EFFORT" <<<"$err" || return 1
  return 0
}

# Arm 4b: an `omitClaudeMd: true` declaration renders a frontmatter line INSIDE the fences; a
# role without the key gets NO such line; a non-boolean value is OMITTED from the file and
# REPORTED on stderr. Three worlds, both directions, one arm -- the mirror of arms 3 and 4.
# The property itself (a spawn that stops RECEIVING the consumer's CLAUDE.md) is unobservable
# from this tree, exactly like the effort property this fixture's header names: what is asserted
# is the projection the renderer wrote, and the harness consumes that. The line-POSITION check
# is not arm 1b restated -- arm 1b reads the alpha lines' positions, and if alpha grew its
# `omitClaudeMd:` line BELOW the closing fence no arm but this one would notice, while the
# harness would read the definition as though the flag were never declared.
arm_omit_claude_md_tracks_the_declaration() {
  local p="$1" subj="$2" f out n_open n_close n_omit
  [ "$SH_RC" -eq 0 ] || return 1
  out="$SH_OUT$SH_ERR"
  # The offender world: the line APPEARS, between the fences. This is the arm's presence
  # conjunct -- a subject replaced by `exit 0` cannot satisfy it, per the harness rule.
  f="$p/.claude/agents/$WITH_OMIT.md"
  [ -f "$f" ] || return 1
  grep -qxF -- 'omitClaudeMd: true' "$f" || return 1
  n_open="$(grep -nxF -- '---' "$f" | sed -n 1p | cut -d: -f1)"
  n_close="$(grep -nxF -- '---' "$f" | sed -n 2p | cut -d: -f1)"
  n_omit="$(grep -n '^omitClaudeMd:' "$f" | sed -n 1p | cut -d: -f1)"
  [ -n "$n_open" ] && [ -n "$n_close" ] && [ -n "$n_omit" ] || return 1
  [ "$n_omit" -gt "$n_open" ] && [ "$n_omit" -lt "$n_close" ] || return 1
  # The near-miss world: a definition IS written, and carries no omitClaudeMd line.
  f="$p/.claude/agents/$NO_OMIT.md"
  [ -f "$f" ] || return 1
  grep -q '^omitClaudeMd:' "$f" && return 1
  # The invalid world: no line, but the value is named on the report -- a harness-unaccepted
  # value written silently would read as a bound property, the invalid-effort class again.
  f="$p/.claude/agents/$BAD_OMIT.md"
  [ -f "$f" ] || return 1
  grep -q '^omitClaudeMd:' "$f" && return 1
  grep -qi 'omitclaudemd' <<<"$out" || return 1
  grep -qF -- "$BAD_OMIT" <<<"$out" || return 1
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
  local p f rc_fresh rc_settings rc_handedit rc_moved rc_after
  local subj="$2"
  [ "$SH_RC" -eq 0 ] || return 1
  p="$(clone "$1" a5)" || return 1
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
  before="$PRE/.claude/agents/my-own-helper.md"       # the seed's copy, snapshotted BEFORE the shared render
  [ -f "$before" ] || return 1
  [ "$SH_RC" -eq 0 ] || return 1
  cmp -s "$before" "$p/.claude/agents/my-own-helper.md" || return 1
  grep -q 'my-own-helper' <<<"$SH_OUT$SH_ERR" && return 1
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
  local p subj="$2" out rc
  [ "$SH_RC" -eq 0 ] || return 1
  p="$(clone "$1" a8)" || return 1
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
  local p subj="$2" before after
  [ "$SH_RC" -eq 0 ] || return 1
  p="$(clone "$1" a9)" || return 1
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
  local p subj="$2" rc_na rc_fail rc_pass
  p="$(clone "$PRE" a10)" || return 1                 # the pre-render snapshot: the drifted state needs no definitions
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
  local p subj="$2" h1 h2 p0="$1"
  [ "$SH_RC" -eq 0 ] || return 1
  h1="$( cd "$p0/.claude/agents" && shasum -a 256 -- *.md )" || return 1   # digest of the shared render
  p="$(clone "$p0" a11)" || return 1
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

# Arm 14: the rendered body carries the protected-path line, in a role that has a definition. Presence-shaped:
# a subject that renders nothing has no body to carry it. Keyed on the whole line, -x -F.
arm_body_carries_protected_read_line() {
  local p="$1" subj="$2" f
  [ "$SH_RC" -eq 0 ] || return 1                     # the ONE shared render of this subject
  f="$p/.claude/agents/$WITH_EFFORT.md"
  [ -f "$f" ] || return 1
  grep -qxF -- 'A path `.claude/hooks/ai-dlc-protect.sh` protects (its PROTECTED_PATTERNS) is read with the native Read tool, never with a context-mode tool (ctx_*): the hook denies those calls.' "$f"
}

ARMS="renders_model_bearing_roles persona_with_model_is_defined marker_sits_below_the_frontmatter no_file_for_model_less_role effort_line_tracks_the_declaration
invalid_effort_omitted_and_reported omit_claude_md_tracks_the_declaration check_joins_declaration_to_projection
foreign_definition_untouched stale_projection_is_caught_and_cleared check_never_writes
three_states_are_distinct idempotent body_carries_protected_read_line"

run_arms() { # <subject> [arms...] -> "<name>:<0|1>" per arm. ONE seed and ONE render per subject.
  local subj="$1" name rc SP ARMS="$ARMS"
  [ $# -lt 2 ] || ARMS="${*:2}"
  WLD="$(bash "$HERE/seed.sh")" || { for name in $ARMS; do printf '%s:1\n' "$name"; done; return; }
  SP="$WLD/project"
  PRE="$WLD/pre/project"                     # snapshot of the seed BEFORE any render
  mkdir -p "$WLD/pre" && cp -R "$SP" "$PRE" || { for name in $ARMS; do printf '%s:1\n' "$name"; done; return; }
  bash "$subj" --root "$SP" >"$WLD/render.out" 2>"$WLD/render.err"; SH_RC=$?
  SH_OUT="$(cat "$WLD/render.out")"; SH_ERR="$(cat "$WLD/render.err")"
  for name in $ARMS; do
    "arm_$name" "$SP" "$subj" >/dev/null 2>&1 && rc=0 || rc=1
    printf '%s:%s\n' "$name" "$rc"
  done
  drop "$SP"
}

LIVE="$(run_arms "$SUBJECT")"
while IFS=: read -r name rc; do
  [ -n "$name" ] || continue
  case "$name" in
    renders_model_bearing_roles)         msg="every role with a resolvable model gets a definition naming that model KEY ($N_WITH_MODEL role(s))" ;;
    persona_with_model_is_defined)       msg="a party persona ($PERSONA_WITH_MODEL) that SETS a model gets a definition carrying its model key and effort, like any role" ;;
    marker_sits_below_the_frontmatter)   msg="the model:/effort: lines sit INSIDE the frontmatter fences and the generated marker sits below them (asserted as line numbers)" ;;
    no_file_for_model_less_role)         msg="a role with NO model gets NO definition, while one with a model does (the party-persona partition)" ;;
    effort_line_tracks_the_declaration)  msg="a declared effort is rendered and an undeclared one produces no effort line" ;;
    invalid_effort_omitted_and_reported) msg="an invalid effort level is OMITTED from the file and named on stderr" ;;
    omit_claude_md_tracks_the_declaration) msg="omitClaudeMd: true renders inside the fences, an absent key renders no line, a non-boolean value is omitted and named on stderr" ;;
    check_joins_declaration_to_projection) msg="--check joins the declaration to its projection: green fresh, red when the SETTINGS entry moves, red when the DEFINITION is hand-edited, red when its MARKER is hoisted above the fence with every key intact, green after a re-render" ;;
    foreign_definition_untouched)        msg="an unmarked consumer-written definition is neither reported nor deleted, in either mode" ;;
    stale_projection_is_caught_and_cleared) msg="a generated definition for a role that left aiDlcRoles is reported and removed" ;;
    check_never_writes)                  msg="--check over a DRIFTED tree writes nothing" ;;
    three_states_are_distinct)           msg="NOT APPLICABLE(3), drifted(1) and current(0) are three distinct exit codes" ;;
    body_carries_protected_read_line)    msg="the rendered body carries the line telling a teammate to read a protected path with native Read, never a context-mode tool" ;;
    idempotent)                          msg="four renders are byte-identical and leave no duplicate" ;;
    *)                                   msg="$name" ;;
  esac
  if [ "$rc" -eq 0 ]; then
    ok "$msg"
    case "$name" in
      renders_model_bearing_roles) B_renders_model_bearing_roles=1 ;;
      persona_with_model_is_defined) B_persona_with_model_is_defined=1 ;;
      marker_sits_below_the_frontmatter) B_marker_sits_below_the_frontmatter=1 ;;
      no_file_for_model_less_role) B_no_file_for_model_less_role=1 ;;
      effort_line_tracks_the_declaration) B_effort_line_tracks_the_declaration=1 ;;
      invalid_effort_omitted_and_reported) B_invalid_effort_omitted_and_reported=1 ;;
      omit_claude_md_tracks_the_declaration) B_omit_claude_md_tracks_the_declaration=1 ;;
      check_joins_declaration_to_projection) B_check_joins_declaration_to_projection=1 ;;
      foreign_definition_untouched) B_foreign_definition_untouched=1 ;;
      stale_projection_is_caught_and_cleared) B_stale_projection_is_caught_and_cleared=1 ;;
      check_never_writes) B_check_never_writes=1 ;;
      three_states_are_distinct) B_three_states_are_distinct=1 ;;
      idempotent) B_idempotent=1 ;;
      body_carries_protected_read_line) B_body_carries_protected_read_line=1 ;;
    esac
  else
    bad "$msg"
  fi
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

mut() { # <label> <sed-expr> <deciding-arm> <twin-arm> <base-pass-flag>
  local label="$1" expr="$2" want="$3" twin="$4" base="$5"
  local dir="$MUTROOT/$label"
  local copy out rc rc_twin
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
  # A MUTATION MUST NOT PUT A NON-READING COMMAND ON THE RIGHT OF A PIPE. The subject runs
  # `set -uo pipefail`; a sink such as `true`, `:` or `false` exits without reading, the writer on
  # the left can then take EPIPE, and pipefail turns that into a failed pipeline -- whether it does
  # is a race between the two processes, so the mutant's behaviour changes with machine load.
  # Measured on M3: `printf ... | true` scored the role DRIFTED and made --check return 1 whenever
  # the writer lost the race, which killed arms that never own the comparison (the entanglement
  # verdict) and sometimes let arm 5's red cells pass (the SURVIVED verdict), at ~90% of runs under
  # the pool and 0 of 9 solo. Keyed on the lines the mutation INTRODUCED into the copy, so a pipe
  # the subject itself already carries is never scored against the mutant. A single `|` only: the
  # `[^|]` before it keeps `cmd || true`, which is not a pipe, out of the set.
  local introduced
  introduced="$(grep -Fvx -f "$SUBJECT" "$copy")" || introduced=""
  if [ -n "$introduced" ] && grep -Eq '(^|[^|])\|[[:blank:]]*(true|false|:)([[:blank:];)&|]|$)' <<<"$introduced"; then
    bad "MUTANT $label DID NOT APPLY CLEANLY: it pipes into a command that never reads its input, so under pipefail the writer's EPIPE decides the verdict and no kill it scores is about the mutated property. Use a draining sink such as cat >/dev/null. Introduced line(s): $(tr '\n' ' ' <<<"$introduced")"
    return
  fi
  chmod +x "$copy"
  if [ "$MATRIX" = 1 ]; then out="$(run_arms "$copy")"; else out="$(run_arms "$copy" "$want" "$twin")"; fi
  # THE OBSERVED arm:rc SET, carried by every verdict below. A verdict naming only which arms
  # fired cannot say which world moved, and a load-dependent kill is diagnosed from the rcs.
  local observed
  observed="$(printf '%s\n' "$out" | tr '\n' ' ')"
  [ "$MATRIX" != 1 ] || matrix_row "$label" "$(arm_cells "$out")"
  rc="$(printf '%s\n' "$out" | sed -n "s/^${want}://p")"
  rc_twin="$(printf '%s\n' "$out" | sed -n "s/^${twin}://p")"
  if [ "$rc" != "1" ]; then
    bad "MUTANT $label SURVIVED: $want still passes against a subject that no longer does the thing that arm asserts. observed arm:rc = $observed"
  elif [ "$rc_twin" != "0" ]; then
    bad "MUTANT $label tripped its twin $twin too (rc=$rc_twin): the confinement recorded in the header matrix no longer holds. observed arm:rc = $observed"
  else
    mutant_killed "$base" "$label" "MUTANT $label killed by $want, while its twin $twin stays green" && kills=$((kills+1))
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
  no_file_for_model_less_role renders_model_bearing_roles "${B_no_file_for_model_less_role:-0}"

# M2: accept any effort level, so a typo is written into the frontmatter as though it bound
# something. Keyed on the vocabulary case itself.
mut accepts-any-effort-level \
  's/^    low|medium|high|xhigh|max) return 0 ;;$/    *) return 0 ;;/' \
  invalid_effort_omitted_and_reported effort_line_tracks_the_declaration "${B_invalid_effort_omitted_and_reported:-0}"

# M3: --check compares nothing -- it reports current whenever the file EXISTS. A presence-only
# check is what a reader writes first, and it passes a definition whose settings entry moved.
#
# ANCHORED ON `cmp -s - "$target"`, NOT ON THE WHOLE LINE. The first spelling wrote the line out
# in full and matched NOTHING: a `|` inside a BRE is a literal pipe, not an alternation, but the
# `printf '%s\n'` in it carries quotes and a backslash that have to survive two levels of shell
# quoting, and they did not. The fixture caught it -- `cmp -s` reported the subject unmutated --
# rather than scoring a kill against a copy nothing had edited. A short unique anchor is both
# safer to quote and immune to reflowing the line around it.
#
# THE REPLACEMENT DRAINS ITS INPUT, AND `true` WAS WRONG. The comparison sits on the right of a
# pipe from `printf`, in a subject running under `set -uo pipefail`. `true` exits without reading,
# so the printf can take EPIPE, pipefail fails the pipeline, and the role is scored DRIFTED -- the
# mutant then compared nothing only when the writer happened to win the race. Measured by delaying
# the writer 20ms: arm 10 read `3 1 1` with `true` and `3 1 0` with the real `cmp`, which is the
# pool-only entanglement this battery kept reporting. `cat >/dev/null` means the same thing --
# compare nothing, succeed -- and reads to EOF, so the writer cannot lose. The pipe guard in
# `mut()` refuses a non-reading sink from any future mutation.
mut check-is-presence-only \
  's#cmp -s - "$target"#cat >/dev/null#' \
  check_joins_declaration_to_projection check_never_writes "${B_check_joins_declaration_to_projection:-0}"

# M4: drop the stale-projection sweep, so a role that left `aiDlcRoles` keeps its definition and
# keeps binding a model and an effort nobody configured. Anchored on the marker grep, which is
# the line that makes the sweep discriminate generated files from a consumer's own.
mut no-stale-sweep \
  's#^    grep -qF -- "\$GEN_PREFIX" "\$f" || continue$#    continue#' \
  stale_projection_is_caught_and_cleared foreign_definition_untouched "${B_stale_projection_is_caught_and_cleared:-0}"

# M5: sweep EVERY .md in the agents directory rather than only the generated ones, so a
# consumer's hand-written definition is reported as stale and deleted. The mirror of M4, and
# the direction that destroys someone else's file. This is why the marker grep is load-bearing
# in both directions and why one mutation of it cannot stand for both.
mut sweeps-foreign-definitions \
  's#^    grep -qF -- "\$GEN_PREFIX" "\$f" || continue$#    :#' \
  foreign_definition_untouched stale_projection_is_caught_and_cleared "${B_foreign_definition_untouched:-0}"

# M6: collapse NOT APPLICABLE into a pass. The single most likely "simplification", and it makes
# the gate print the same line for a project that pins no roles and one whose definitions are
# verified current.
mut not-applicable-reads-as-pass \
  's/^  echo "NOT APPLICABLE: \$SETTINGS declares no aiDlcRoles, so no roles are pinned here."$/  echo "OK: agent definitions current"; exit 0/' \
  three_states_are_distinct check_joins_declaration_to_projection "${B_three_states_are_distinct:-0}"

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
  check_never_writes check_joins_declaration_to_projection "${B_check_never_writes:-0}"

# M8: render_one stops emitting the omitClaudeMd line at all. The arm's PRESENCE conjunct is
# what this dies on -- an arm that only asserted the near-miss absence would score this a kill
# it never earned (the harness rule: absence arms require the offender direction too).
mut drops-omit-line \
  '/omitClaudeMd: true/d' \
  omit_claude_md_tracks_the_declaration marker_sits_below_the_frontmatter "${B_omit_claude_md_tracks_the_declaration:-0}"

# M9: emit the line UNCONDITIONALLY, ignoring the declaration -- the wrong fix that flags every
# role for a consumer who flagged three. The anchor is the guard, not the printf: the same printf
# text stays in the line, so the mutant is exactly `[ "${4:-}" = "true" ] &&` deleted. It must
# fail the near-miss world (and the invalid world), which only arm 4b reads.
mut emits-omit-line-unconditionally \
  's/^  \[ "${4:-}" = "true" \] && /  /' \
  omit_claude_md_tracks_the_declaration effort_line_tracks_the_declaration "${B_omit_claude_md_tracks_the_declaration:-0}"

# M10: accept any omitClaudeMd value. Mirrors M2 one vocabulary over, and its observable is the
# REPORT vanishing, not a line appearing: a harness-unaccepted value passes validation, is still
# not `true` so renders nothing, and the silently-accepted typo reads as a settled declaration.
mut accepts-any-omit-value \
  's/^    true|false) return 0 ;;$/    *) return 0 ;;/' \
  omit_claude_md_tracks_the_declaration invalid_effort_omitted_and_reported "${B_omit_claude_md_tracks_the_declaration:-0}"

# M11: the persona-name special case -- the old reading ("personas carry no model, skip them")
# written as code. A persona that SETS a model then gets no definition. Arm 1c alone moves:
# arm 1's set excludes the persona names, and arm 2 asserts only the model-less roles.
mut skips-persona-names \
  's/^  mkey="\$(jq -r --arg r "\$role" '"'"'.aiDlcRoles\[\$r\].model \/\/ empty'"'"' "\$SETTINGS" 2>\/dev\/null)"$/&; case "$role" in cis|sm|tea|ux) mkey="" ;; esac/' \
  persona_with_model_is_defined renders_model_bearing_roles "${B_persona_with_model_is_defined:-0}"

# M12: delete the protected-path printf, so a rendered body never tells a teammate that context-mode reads of a protected path are denied.
mut drops-protected-read-line \
  '/^  printf .A path `.claude\/hooks\/ai-dlc-protect.sh` protects/d' \
  body_carries_protected_read_line marker_sits_below_the_frontmatter "${B_body_carries_protected_read_line:-0}"

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
[ "$kills" -eq 0 ] && bad "NO MUTANT SCORED A KILL. Either the mutations landed in a copy nothing executes, or none of these arms is load-bearing."

# ---------------------------------------------------------------------------------------
# THE CONSUMER HOOK. `.claude/agents/` is gitignored and derived, so a fresh `git worktree add`
# or clone has none, and the hook's `--check` failed every pinned role on the first push from
# such a tree. The hook now RENDERS when the directory is ABSENT and stays check-only when it is
# PRESENT. These worlds drive the REAL consumer hook in a scratch consumer -- a git repo holding
# the renderer at `scripts/ai-dlc/` and the hook at `.githooks/pre-push`, with no tests/fixtures
# so the suite step is not reached.
#
# FOUR WORLDS, one token each, and each is the one a named wrong fix moves:
#   A  absent directory       -> exit 0, the definitions EXIST, and `--check` agrees afterwards
#   D  drifted definition     -> exit 1, the drifted file's digest UNCHANGED (kills "always render")
#   C  current definitions    -> exit 0, the OK line PRESENT, digest unchanged, no write-mode line
#   U  unparseable settings   -> non-zero, and `.claude/agents` still does NOT exist (kills
#      "create the directory, then render": a renderer refusing leaves a dir the next push reads
#      as present, so the fresh-worktree case turns into a permanent check-only FAIL)
# ---------------------------------------------------------------------------------------
HOOK=""
if [ -f "$ROOT/core/git-hooks/pre-push" ]; then
  HOOK="$ROOT/core/git-hooks/pre-push"
elif [ "$SUBJECT" = "$ROOT/scripts/ai-dlc/render-agent-definitions.sh" ] && [ -f "$ROOT/.githooks/pre-push" ]; then
  # In the distribution `.githooks/pre-push` is the distribution's OWN runner, not the subject;
  # it is the consumer hook only in the installed layout.
  HOOK="$ROOT/.githooks/pre-push"
fi

# The scratch consumer (seed + git init + renderer) is built ONCE into HT and copied per world;
# only the hook differs per battery, and it is copied over the template's after the clone.
HT=""
hook_template() {
  local p
  p="$(fresh)" || return 1
  git -c init.defaultBranch=main init -q "$p" >/dev/null 2>&1 || return 1
  mkdir -p "$p/scripts/ai-dlc" "$p/.githooks" || return 1
  cp "$SUBJECT" "$p/scripts/ai-dlc/render-agent-definitions.sh" || return 1
  HT="$p"
}
hook_world() { # <hook> -> a scratch consumer project with the renderer and the hook installed
  local h="$1" w p
  [ -n "$HT" ] || hook_template || return 1
  w="$(mktemp -d)" || return 1
  mkdir -p "$w" && cp -R "$HT" "$w/project" || return 1
  p="$w/project"
  cp "$h" "$p/.githooks/pre-push" || return 1
  printf '%s\n' "$p"
}
drive_hook() { # <project> -> the hook's combined output; exit = the hook's
  ( cd "$1" && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null 2>&1 )
}
agents_digest() { ( cd "$1/.claude/agents" 2>/dev/null && shasum -a 256 -- *.md 2>/dev/null ) }

hook_battery() { # <hook> [worlds...] -> "A:<> D:<> C:<> U:<>" (only the named worlds; default all four)
  local h="$1" p out rc t="" b a w
  local worlds="A D C U"
  [ $# -lt 2 ] || worlds="${*:2}"
  for w in $worlds; do
    p="$(hook_world "$h")" || { t="$t $w:broken"; continue; }
    case "$w" in
    A) # absent. The seed's foreign definition is removed so the directory can go with it.
      rm -f "$p/.claude/agents/my-own-helper.md"; rmdir "$p/.claude/agents"
      out="$(drive_hook "$p")"; rc=$?
      if [ "$rc" -eq 0 ] && [ -f "$p/.claude/agents/$WITH_EFFORT.md" ] \
         && render "$SUBJECT" "$p" --check >/dev/null 2>&1 && grep -q 'definition(s) written' <<<"$out"; then
        t="$t A:rendered"
      elif [ "$rc" -eq 0 ]; then t="$t A:green-unrendered"
      else t="$t A:blocked"; fi ;;
    D) # drifted. Rendered, then hand-edited; the hook must refuse and leave the edit in place.
      render "$SUBJECT" "$p" >/dev/null
      printf 'effort: max\n' >> "$p/.claude/agents/$WITH_EFFORT.md"
      b="$(agents_digest "$p")"
      out="$(drive_hook "$p")"; rc=$?
      a="$(agents_digest "$p")"
      if [ "$rc" -eq 1 ] && [ -n "$b" ] && [ "$b" = "$a" ]; then t="$t D:refused-untouched"
      elif [ "$b" != "$a" ]; then t="$t D:overwritten"
      else t="$t D:rc$rc"; fi ;;
    C) # current. Presence-shaped: the check's own OK line must be THERE.
      render "$SUBJECT" "$p" >/dev/null
      b="$(agents_digest "$p")"
      out="$(drive_hook "$p")"; rc=$?
      a="$(agents_digest "$p")"
      if [ "$rc" -eq 0 ] && grep -q 'OK: agent definitions current' <<<"$out" && [ "$b" = "$a" ] \
         && ! grep -q 'definition(s) written' <<<"$out"; then t="$t C:checked"
      elif grep -q 'definition(s) written' <<<"$out"; then t="$t C:rewritten"
      else t="$t C:rc$rc"; fi ;;
    U) # unparseable settings over an absent directory.
      rm -f "$p/.claude/agents/my-own-helper.md"; rmdir "$p/.claude/agents"
      printf '{ "aiDlcRoles": \n' > "$p/.claude/settings.json"
      out="$(drive_hook "$p")"; rc=$?
      if [ "$rc" -ne 0 ] && [ ! -e "$p/.claude/agents" ]; then t="$t U:refused-nothing-written"
      elif [ -e "$p/.claude/agents" ]; then t="$t U:dir-created"
      else t="$t U:rc$rc"; fi ;;
    esac
    drop "$p"
  done
  printf '%s' "${t# }"
}
hook_cell() { # <battery vector> <world> -> that world's token
  local tok
  for tok in $1; do case "$tok" in "$2":*) printf '%s' "$tok"; return ;; esac; done
}
HOOK_EXPECTED="A:rendered D:refused-untouched C:checked U:refused-nothing-written"

if [ -z "$HOOK" ]; then
  echo "  skip  consumer pre-push hook not found (looked for core/git-hooks/pre-push, and .githooks/pre-push in the installed layout)"
else
  echo "  hook:    ${HOOK#"$ROOT"/}"
  # THE HOOK RAN AT ALL, in a scratch consumer: an unmutated drive over a current world must
  # exit 0 and print the renderer's own OK line. A hook that died before this arm would
  # otherwise make every mutant below read as killed.
  echo "HERMETIC-CONSUMED ${HOOK#"$ROOT"/}"
  HP="$(hook_world "$HOOK")" || { echo "FIXTURE BROKEN: could not build a scratch consumer for the hook" >&2; exit 2; }
  render "$SUBJECT" "$HP" >/dev/null
  HOUT="$(drive_hook "$HP")"; HRC=$?
  drop "$HP"
  if [ "$HRC" -ne 0 ] || ! grep -q 'OK: agent definitions current' <<<"$HOUT"; then
    echo "FIXTURE BROKEN: the unmutated consumer hook did not pass a current scratch consumer (rc=$HRC) -- nothing below would be about the agent-definitions arm" >&2
    printf '%s\n' "$HOUT" | tail -20 >&2
    exit 2
  fi

  HGOT="$(hook_battery "$HOOK")"
  B_hook=0
  if [ "$HGOT" = "$HOOK_EXPECTED" ]; then
    ok "consumer pre-push: an ABSENT .claude/agents/ is rendered and the push passes; a DRIFTED definition blocks the push and is left byte-identical; a CURRENT tree is checked and not written; UNPARSEABLE settings block with no directory created"; B_hook=1
  else
    bad "consumer pre-push battery: expected [$HOOK_EXPECTED], got [$HGOT]"
  fi


  # hmut <label> <sed-expr> <deciding world> <twin world> <deciding world's mutated token> <claim>
  # Per push the mutant runs its DECIDING world and one TWIN world, asserting the deciding world
  # reads the mutated token and the twin stays at its unmutated value. Under --matrix all four
  # worlds run and a MATRIX row carries the whole vector.
  hmut() {
    local label="$1" expr="$2" dw="$3" tw="$4" want="$5" claim="$6" d="$MUTROOT/hook-$1" got gd gt
    mkdir -p "$d"
    if ! sed -e "$expr" "$HOOK" > "$d/pre-push" 2>/dev/null; then
      bad "HOOK MUTANT $label DID NOT APPLY: the sed died"; return
    fi
    if cmp -s "$HOOK" "$d/pre-push"; then
      bad "HOOK MUTANT $label: the sed matched NOTHING, so no mutant existed"; return
    fi
    if [ "$tw" = FULL ]; then
      # No single world decides this mutant: the whole four-world vector is asserted exactly.
      got="$(hook_battery "$d/pre-push")"
      [ "$MATRIX" != 1 ] || matrix_row "$label" "$(hook_cells "$got")"
      if [ "$got" = "$want" ]; then
        mutant_killed "$B_hook" "$label" "HOOK MUTANT $label killed, full vector [$want]: $claim" && kills=$((kills+1))
      elif [ "$got" = "$HOOK_EXPECTED" ]; then bad "HOOK MUTANT $label SURVIVED: $claim"
      else bad "HOOK MUTANT $label ($claim): expected [$want], got [$got]"; fi
      return
    fi
    if [ "$MATRIX" = 1 ]; then got="$(hook_battery "$d/pre-push")"; matrix_row "$label" "$(hook_cells "$got")"
    else got="$(hook_battery "$d/pre-push" "$dw" "$tw")"; fi
    gd="$(hook_cell "$got" "$dw")"; gt="$(hook_cell "$got" "$tw")"
    if [ "$gd" = "$(hook_cell "$HOOK_EXPECTED" "$dw")" ]; then
      bad "HOOK MUTANT $label SURVIVED: $claim"
    elif [ "$gd" != "$want" ]; then
      bad "HOOK MUTANT $label ($claim): world $dw expected [$want], got [$gd]"
    elif [ "$gt" != "$(hook_cell "$HOOK_EXPECTED" "$tw")" ]; then
      bad "HOOK MUTANT $label tripped its twin world $tw too (got [$gt]): the confinement recorded in the header matrix no longer holds"
    else
      mutant_killed "$B_hook" "$label" "HOOK MUTANT $label killed by world $dw, while twin world $tw stays green: $claim" && kills=$((kills+1))
    fi
  }

  # The tip's behaviour: never render. Only the absent world moves.
  hmut never-render \
    's/^    if \[ ! -d \.claude\/agents \]; then$/    if false; then/' \
    A D "A:blocked" \
    "without the absent-directory render a fresh worktree's first push is blocked on every pinned role, and only the absent world sees it"

  # WRONG FIX: render on every push. It clears the absent world AND erases a drifted definition,
  # so the push goes green over a hand edit nobody reviewed. The D world reads the write that
  # destroys evidence and decides it alone; C (a write on a tree that needed none) moves with it
  # and is recorded in the matrix, not scored per push.
  hmut render-unconditionally \
    's/^    if \[ ! -d \.claude\/agents \]; then$/    if true; then/' \
    D U "D:overwritten" \
    "rendering on every push overwrites a drifted definition and passes"

  # WRONG FIX: "make sure the directory exists" before rendering. A renderer that then refuses
  # leaves an EMPTY directory, which every later push reads as present and check-only.
  hmut mkdir-before-render \
    '/^      out="\$(bash scripts\/ai-dlc\/render-agent-definitions.sh --root \. 2>&1)"$/i\
      mkdir -p .claude/agents
' \
    U A "U:dir-created" \
    "creating the directory before the renderer decides leaves an empty .claude/agents/ behind a refused render, and only the unparseable world sees it"

  # WRONG FIX: skip the arm. MEASURED: all four worlds move (a skipped arm renders nothing, refuses
  # nothing, prints no OK line, and exits 0 on unparseable settings), so no world is left green to
  # be a twin and the full vector is asserted. C is the world that proves the arm RAN.
  hmut skip-the-arm \
    's/^    agent_definitions$/    true/' \
    - FULL "A:green-unrendered D:rc0 C:rc0 U:rc0" \
    "a hook that stops running the arm passes all four worlds' exit codes wrongly or not at all; C is the world that proves the arm RAN"
fi

[ -z "${HT:-}" ] || drop "$HT"

# A PLAIN RUN EXECUTES NO MATRIX-ONLY CELL. The counter is bumped by the one function that prints a
# MATRIX row, so a cell enabled outside --matrix moves it. Under --matrix the same counter must be
# non-zero, which proves the counter can fire.
if [ "$MATRIX" = 1 ]; then
  if [ "$MATRIX_CELLS" -gt 0 ]; then ok "--matrix executed $MATRIX_CELLS matrix cell(s) (the counter fires)"; else bad "--matrix executed no matrix cell: the counter cannot fire"; fi
else
  if [ "$MATRIX_CELLS" -eq 0 ]; then ok "a plain run executes no matrix-only cell"; else bad "a plain run executed $MATRIX_CELLS matrix-only cell(s)"; fi
fi
echo "  $fails failed, $kills mutant kill(s)"
[ "$fails" -eq 0 ] || exit 1
exit 0
