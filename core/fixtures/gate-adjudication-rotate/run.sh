#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# gate-adjudication-rotate/run.sh — prove the gate-adjudication rotator moves a closed
# sprint's verdicts and sidecars out of the live directory, loses nothing, refuses rather
# than half-writes, and actually removes the affordance DEFECT 1 names: a prior sprint's
# dispositioned FAIL staying the gate-remediation guard's "live pass" into the next sprint.
#
# THE RECEIPT IS ARM (e). Every other arm proves the mover is correct; arm (e) proves the
# reason it exists — it DRIVES `ai-dlc-gate-remediation-guard.sh` against the same tree
# before and after rotation and asserts DENY -> ALLOW -> DENY (the third leg is the control:
# rotation must not blind the guard to a live FAIL in the CURRENT sprint).
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Locate the rotator by walking UP for a marker, so this resolves from the distribution
# (core/scripts) and from a consumer where install.sh relocates it (scripts/ai-dlc).
ROT=""
d="$HERE"
while [ "$d" != "/" ]; do
  for base in "$d/core/scripts" "$d/scripts/ai-dlc"; do
    if [ -f "$base/rotate-gate-adjudication.sh" ]; then ROT="$base/rotate-gate-adjudication.sh"; break 2; fi
  done
  d="$(dirname "$d")"
done
[ -n "$ROT" ] || { echo "FIXTURE ERROR: rotate-gate-adjudication.sh not found in either layout" >&2; exit 2; }

# Locate the guard hook the same way gate-remediation-deny/run.sh does: three candidates
# spanning the distribution layout and a consumer's installed layout.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
GUARD="$(pick "$HERE/../../hooks/ai-dlc-gate-remediation-guard.sh" \
              "$HERE/../../../.claude/hooks/ai-dlc-gate-remediation-guard.sh" \
              "$HERE/../../../core/hooks/ai-dlc-gate-remediation-guard.sh")"
[ -n "$GUARD" ] || { echo "FIXTURE ERROR: ai-dlc-gate-remediation-guard.sh not found in either layout" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq absent; arm (e) cannot run" >&2; exit 2; }

# HERMETIC — scrub the operator's tuning before invoking the guard (I10 / I87).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# A candidate list resolves the FIRST existing file, so the file this run actually drives is
# not necessarily the one an author just edited. Print both: a mutant applied to the other
# copy leaves every arm green and reads exactly like an arm that cannot fire.
echo "gate-adjudication-rotate: resolved rotator = ${ROT}"
echo "gate-adjudication-rotate: resolved guard   = ${GUARD}"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

seed() { # <case> -> sets W/PROJ/GA/DEST_S308, or aborts the whole run
  W="$(bash "$HERE/seed.sh" "$1")" || { echo "FIXTURE ERROR: seed.sh '$1' exited non-zero" >&2; exit 2; }
  [ -n "$W" ] && [ -d "$W" ] && [ -f "$W/env.sh" ] \
    || { echo "FIXTURE ERROR: seed '$1' produced no usable workspace ('${W}')" >&2; exit 2; }
  # shellcheck source=/dev/null
  . "$W/env.sh"
}

# A recursive, order-independent digest of a directory's CONTENT — relative path plus
# shasum per file, sorted. Two calls comparing equal is the same evidence `cmp -s` gives a
# single file, extended to a whole tree, so a rotator that touched anything unexpected
# (renamed the wrong file, edited bytes in passing, left a stray temp file) is caught even
# though this fixture never names every path up front.
treehash() { ( cd "$1" 2>/dev/null && find . -type f | sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(shasum "$f" | cut -d' ' -f1)" "$f"; done ) }

drive() { # <projdir> <tool> <file_path> -> the guard's stdout JSON
  local w="$1" tool="$2" fp="$3"
  jq -nc --arg t "$tool" --arg f "$fp" \
    '{session_id:"t", tool_name:$t, tool_input:{file_path:$f}}' \
    | CLAUDE_PROJECT_DIR="$w" AI_DLC_GATE_METRICS="" bash "$GUARD" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }

# The rotator resolves its repo root by walking UP from the CURRENT WORKING DIRECTORY
# (CLAUDE.md: "resolve the repo root by walking up for a marker"), and the seeded project
# IS its own git repo (seed.sh runs `git init` inside it). So every invocation in this
# fixture runs from INSIDE the seeded $PROJ, never from this fixture's own directory --
# running from here would walk up to the ai-dlc repo itself and silently operate on ITS
# `_bmad-output`, which is exactly the false-zero shape CLAUDE.md warns about (a command
# that "ran" and answered about the wrong tree).
rotate() { ( cd "$PROJ" && bash "$ROT" "$@" ); }

echo "gate-adjudication-rotate:"

# =============================================================================
# ARM 0 — SANITY: the base seed holds the shape every later arm depends on.
# =============================================================================
seed base
N_VERDICTS="$(find "$GA" -maxdepth 1 -name '*.verdict.json' | wc -l | tr -d ' ')"
N_SIDECARS="$(find "$GA" -maxdepth 1 \( -name '*.repair.md' -o -name '*.authorization.md' \) | wc -l | tr -d ' ')"
N_LEGACY="$(grep -L 'gate_series_id' "$GA"/*.verdict.json 2>/dev/null | wc -l | tr -d ' ')"
N_SUBDIR="$(find "$GA" -mindepth 2 -type f | wc -l | tr -d ' ')"
if [ "$N_VERDICTS" -eq 3 ] && [ "$N_SIDECARS" -eq 2 ] && [ "$N_LEGACY" -eq 1 ] && [ "$N_SUBDIR" -eq 1 ] \
   && [ -f "$GA/.verdict-writes.jsonl" ]; then
  ok "(0) seed: 3 verdicts (s308 FAIL, s309 PASS, 1 legacy), 2 sidecars, 1 subdir file, 1 write-ledger"
else
  bad "FIXTURE BROKEN — seed shape wrong (verdicts=${N_VERDICTS} sidecars=${N_SIDECARS} legacy=${N_LEGACY} subdir=${N_SUBDIR})"
  echo; echo "gate-adjudication-rotate: FIXTURE BROKEN" >&2; exit 2
fi

# =============================================================================
# ARM (a) — report mode writes nothing.
# =============================================================================
BEFORE_A="$(treehash "$PROJ")"
out="$(rotate --sprint s308 2>&1)"; rc=$?
AFTER_A="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_A" = "$AFTER_A" ] && [ ! -d "$DEST_S308" ] \
   && grep -q '3 file(s) total\|1 verdict(s) and 2 sidecar(s)' <<<"$out"; then
  ok "(a) report mode (--sprint s308, no --apply): tree byte-identical, no destination created"
else
  bad "(a) report mode changed the tree or misreported (rc=$rc): $(head -1 <<<"$out")"
fi

# =============================================================================
# ARM (b) — apply moves exactly the s308 set, byte-equal, source absent.
# =============================================================================
SNAP="$W/snap"; mkdir -p "$SNAP"
S308_VERDICT="sprint-review-20260907T002257Z.verdict.json"
S308_REPAIR="sprint-review-20260907T002257Z.repair.md"
S308_AUTH="sprint-review-20260907T002257Z.authorization.md"
for f in "$S308_VERDICT" "$S308_REPAIR" "$S308_AUTH"; do cp "$GA/$f" "$SNAP/$f"; done

out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
ALL_BYTE_EQUAL=1
for f in "$S308_VERDICT" "$S308_REPAIR" "$S308_AUTH"; do
  cmp -s "$SNAP/$f" "$DEST_S308/$f" || ALL_BYTE_EQUAL=0
  [ -e "$GA/$f" ] && ALL_BYTE_EQUAL=0   # must be absent from the source now
done
if [ "$rc" -eq 0 ] && [ "$ALL_BYTE_EQUAL" -eq 1 ]; then
  ok "(b) apply --sprint s308: moved the verdict + 2 sidecars, byte-equal at the destination, gone from the source"
else
  bad "(b) apply did not move the s308 set cleanly (rc=$rc): $out"
fi

# =============================================================================
# ARM (c) — everything else stays, byte-identical.
# =============================================================================
REMAIN_OK=1
[ -f "$GA/planning-20260907T160702Z.verdict.json" ] || REMAIN_OK=0
[ -f "$GA/implementation-20260720T011606Z.verdict.json" ] || REMAIN_OK=0
[ -f "$GA/.verdict-writes.jsonl" ] || REMAIN_OK=0
[ -f "$GA/s293/f.md" ] || REMAIN_OK=0
[ ! -e "$DEST_S308/planning-20260907T160702Z.verdict.json" ] || REMAIN_OK=0
if [ "$REMAIN_OK" -eq 1 ]; then
  ok "(c) the s309 verdict, the legacy verdict, the write-ledger and s293/ all stayed in place"
else
  bad "(c) something that should not have moved is gone or wrongly relocated"
fi

# =============================================================================
# ARM (d) — REFUSAL: a git-ignored destination. Fresh seed, nothing written.
# =============================================================================
seed ignored
BEFORE_D="$(treehash "$GA")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_D="$(treehash "$GA")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_D" = "$AFTER_D" ] && [ ! -d "$DEST_S308" ] && grep -q 'git-ignored' <<<"$out"; then
  ok "(d) REFUSAL: a git-ignored destination is refused (exit 1), source tree byte-identical, nothing written"
else
  bad "(d) an ignored destination was not refused cleanly (rc=$rc, tree changed: $([ "$BEFORE_D" = "$AFTER_D" ] && echo no || echo yes))"
fi

# =============================================================================
# ARM (d2) — idempotence: a second --apply for an already-rotated sprint moves nothing.
# =============================================================================
seed base
rotate --sprint s308 --apply >/dev/null 2>&1
BEFORE_D2="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_D2="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_D2" = "$AFTER_D2" ] && grep -q 'nothing to move' <<<"$out"; then
  ok "(d2) a second --apply for s308 reports zero moves and exits 0, tree unchanged"
else
  bad "(d2) a second --apply was not a clean no-op (rc=$rc): $out"
fi

# =============================================================================
# ARM (e) — THE GUARD CONTROL. Fresh world with ONLY the s308 FAIL verdict live.
# =============================================================================
seed guardworld
TARGET="$PROJ/_bmad-output/planning-artifacts/s309/x.md"

OUT1="$(drive "$PROJ" Edit "$TARGET")"
if denied "$OUT1"; then
  ok "(e.1) BEFORE rotation: the s308 FAIL verdict is the only live pass and the lead's edit is DENIED (reproduces DEFECT 1)"
else
  bad "(e.1) FIXTURE COULD NOT REPRODUCE THE DEFECT — the pre-rotation edit was not denied, so this arm cannot fire: $OUT1"
fi

rotate --sprint s308 --apply >/dev/null 2>&1

OUT2="$(drive "$PROJ" Edit "$TARGET")"
if ! denied "$OUT2"; then
  ok "(e.2) AFTER rotation: the same edit is ALLOWED — the closed sprint's FAIL is no longer the live pass"
else
  bad "(e.2) rotation did not clear the deny: $OUT2"
fi

cat > "$GA/planning-20260907T160702Z.verdict.json" <<'EOF'
{
  "schema_id": "GATE_ADJUDICATION_VERDICT v1",
  "gate_type": "planning",
  "gate_nonce": "planning-20260907T160702Z",
  "generated_at": "2026-09-07T16:07:02Z",
  "adjudicator_agent_id": "gate-adjudicator@session-seed",
  "gate_series_id": "planning-s309-20260907T160702Z",
  "catalog": "core",
  "verdicts": [{"check_id":"1","verdict":"FAIL","evidence":"seeded, current sprint"}]
}
EOF

OUT3="$(drive "$PROJ" Edit "$TARGET")"
if denied "$OUT3"; then
  ok "(e.3) CONTROL: a live CURRENT-sprint FAIL still DENIES after rotation — rotation did not blind the guard"
else
  bad "(e.3) CONTROL FAILED: a live current-sprint FAIL was allowed after rotation: $OUT3"
fi

# =============================================================================
# ARM (f) — a legacy-only directory: apply moves nothing, exit 0.
# =============================================================================
seed legacyonly
BEFORE_F="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_F="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_F" = "$AFTER_F" ] && grep -q 'nothing to move' <<<"$out"; then
  ok "(f) a directory holding only a legacy (no gate_series_id) verdict: apply moves nothing, exits 0"
else
  bad "(f) a legacy-only directory was not left alone (rc=$rc): $out"
fi

# =============================================================================
# ARM (g) — REFUSAL: an unparseable *.verdict.json. Nothing moved, nothing written.
# =============================================================================
seed badjson
BEFORE_G="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_G="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_G" = "$AFTER_G" ] && grep -q 'do not parse as JSON' <<<"$out"; then
  ok "(g) REFUSAL: an unparseable *.verdict.json refuses the whole run (exit 1), tree byte-identical"
else
  bad "(g) an unparseable verdict was not refused cleanly (rc=$rc): $out"
fi

# =============================================================================
# ARM (h) — REFUSAL: the rotation would STRAND a FAILing legacy verdict.
#
# The two cases differ in exactly ONE property: whether the legacy verdict left
# behind records a FAIL. Both must be here, because a refusal keyed on legacy-ness
# ALONE passes (h.1) and is a wrong fix -- it would refuse 94 files on the
# reference consumer and break every legitimate close. (h.2) is what convicts it.
# =============================================================================
seed strand
BEFORE_H="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_H="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_H" = "$AFTER_H" ] \
   && grep -q 'no mode can move' <<<"$out" \
   && grep -q 'carries no gate_series_id' <<<"$out" \
   && grep -q 'legacy-20260701T000000Z' <<<"$out"; then
  ok "(h.1) REFUSAL: rotating s308 PROMOTES a FAILing legacy verdict to newest — refused (exit 1), tree byte-identical, offender named"
else
  bad "(h.1) a rotation that strands a FAILing legacy verdict was not refused (rc=$rc): $out"
fi

# The offender's remedy must name an action THIS tool honours. An earlier revision
# printed "write a repair or authorization record", which the refusal never reads —
# a remedy the consumer follows to no effect. Assert the executable one is offered.
if grep -q -- '--legacy-through' <<<"$out"; then
  ok "(h.1b) the refusal offers a remedy this tool can execute (--legacy-through), not a sidecar it never reads"
else
  bad "(h.1b) the refusal named no executable remedy: $out"
fi

seed strand-nearmiss
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'would strand' <<<"$out" \
   && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ]; then
  ok "(h.2) NEAR-MISS: a CLEAN legacy verdict rotates normally AND the move landed — the refusal is keyed on the FAIL, not on legacy-ness"
else
  bad "(h.2) a clean legacy verdict was wrongly refused, or the move did not land (rc=$rc): $out"
fi

# =============================================================================
# ARM (h.3) — a FAILing legacy verdict that the rotation does NOT promote.
#
# THE ARM THAT CONVICTS A SURVIVORSHIP-BLIND PREDICATE. (h.1) and (h.2) both pass
# against "refuse if any legacy verdict anywhere records a FAIL" — a fix that
# refuses EVERY rotation on the reference consumer. Here the FAILing legacy
# verdict is shadowed by a newer verdict that does not move, so the correct
# answer is PROCEED, and the destination assertion stops "exit 0 having moved
# nothing" from passing as a rotation.
# =============================================================================
seed strand-shadowed
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'would strand' <<<"$out" \
   && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ]; then
  ok "(h.3) a FAILing legacy verdict SHADOWED by a newer non-moving verdict does not block the rotation, and the move landed"
else
  bad "(h.3) a shadowed FAILing legacy verdict wrongly blocked the rotation, or the move did not land (rc=$rc): $out"
fi

# =============================================================================
# ARM (h.4) — the SECOND unmovable shape: a survivor with a series id that no
# `*-s<N>-*` selector can name. The schema leaves `gate_series_id` deliberately
# unpatterned, so this is legal input, and it is worse than a legacy verdict
# because `--legacy-through` skips it too. A predicate keyed on legacy-ness
# scores it movable and lets the rotation strand it — no refusal, no escape.
# =============================================================================
seed strand-unselectable
BEFORE_H4="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_H4="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_H4" = "$AFTER_H4" ] \
   && grep -q 'no mode can move' <<<"$out" \
   && grep -q 'matches no --sprint selector' <<<"$out"; then
  ok "(h.4) REFUSAL: a survivor whose gate_series_id no selector can name is refused too, and the row says WHY it is unmovable"
else
  bad "(h.4) an unselectable FAILing survivor was not refused (rc=$rc): $out"
fi

# Its remedy must NOT be the legacy one — --legacy-through cannot move a verdict
# that has a series id, so printing it here would be a second inert remedy.
# Keyed on the PRESCRIBED COMMAND LINE, not on the token: the prose explains why
# --legacy-through does not apply here, so a bare token grep matches that
# explanation and reads as the wrong remedy being offered.
if ! grep -qE '^ +rotate-gate-adjudication\.sh --legacy-through' <<<"$out" \
   && grep -q 'Re-stamp that' <<<"$out"; then
  ok "(h.4b) the unselectable case prescribes a re-stamp and does NOT offer the legacy escape, which cannot move it"
else
  bad "(h.4b) the unselectable case printed the wrong remedy: $out"
fi

# =============================================================================
# ARM (i) — the legacy escape the refusal prescribes actually works.
#
# A refusal whose remedy cannot be executed is the defect the remedy text exists
# to avoid, so the remedy is asserted here rather than trusted: rotating the
# pre-series verdicts out must let the previously-refused rotation proceed.
# =============================================================================
#
# THE BOUND IS PARSED OUT OF THE REFUSAL'S OWN OUTPUT AND EXECUTED VERBATIM. An
# earlier revision hardcoded a bound, which is why it could not see a strict-`<`
# off-by-one: the printed command moved everything EXCEPT the verdict it named,
# so the next close re-printed the identical bound and a consumer following the
# message looped forever. A hardcoded bound made that converge and proved nothing.
# It also let a one-line wrong fix — print an impossible bound like
# `00000000T000000Z`, which selects nothing — pass every arm.
seed strand
refusal="$(rotate --sprint s308 --apply 2>&1)"
PRINTED_BOUND="$(grep -oE -- '--legacy-through [0-9]{8}T[0-9]{6}Z' <<<"$refusal" | head -1 | awk '{print $2}')"
if [ -z "$PRINTED_BOUND" ]; then
  bad "(i) the refusal printed no executable bound to run: $refusal"
else
  out="$(rotate --legacy-through "$PRINTED_BOUND" --apply 2>&1)"; rc_i=$?
  # The verdict the refusal NAMED must be the one the printed command removes.
  legacy_gone=1; [ -e "$GA/legacy-20260701T000000Z.verdict.json" ] && legacy_gone=0
  out2="$(rotate --sprint s308 --apply 2>&1)"; rc_i2=$?
  if [ "$rc_i" -eq 0 ] && [ "$rc_i2" -eq 0 ] && [ "$legacy_gone" -eq 1 ] \
     && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ]; then
    ok "(i) running the refusal's OWN printed bound (${PRINTED_BOUND}) removes the verdict it named and unblocks the rotation in ONE run — the remedy converges"
  else
    bad "(i) the printed remedy did not converge (legacy rc=$rc_i, named-verdict-removed=$legacy_gone, sprint rc=$rc_i2): $out / $out2"
  fi
fi

# The bound is not decorative: a legacy verdict at or after it must NOT move.
seed strand
out="$(rotate --legacy-through 20260101T000000Z --apply 2>&1)"; rc_i3=$?
if [ "$rc_i3" -eq 0 ] && grep -q 'nothing to move' <<<"$out"; then
  ok "(i.2) --legacy-through honours its bound: a legacy verdict NEWER than the bound is left alone"
else
  bad "(i.2) the --legacy-through bound was not honoured (rc=$rc_i3): $out"
fi

# =============================================================================
# MUTATION 4 — strip the stranding refusal; arm (h.1) must go red.
#
# Keyed on the refusal's own emission, so a mutant that matched nothing cannot
# pass as a mutation. (h.2) must stay green under it: the mutation removes the
# refusal, and a world that was never refused is unaffected by removing it.
# =============================================================================
MUT4="$W/mut-strand.sh"
# Re-anchored when the predicate widened from "is legacy" to "no mode can move
# it": the old anchor named `SURVIVOR_LEGACY`, which no longer exists. The
# `cmp -s` guard below caught the dead anchor rather than letting a no-op
# mutation score a kill, which is the whole reason it is there.
sed 's/^if \[ "\$SURVIVOR_UNMOVABLE" -eq 1 \] && \[ -n "\$SURVIVOR_FAILS" \]; then/if false; then/' "$ROT" > "$MUT4"
if cmp -s "$ROT" "$MUT4"; then
  bad "MUTATION 4: the sed matched nothing, so the stranding refusal in arm (h.1) is UNPROVEN"
else
  chmod +x "$MUT4"
  seed strand
  BEFORE_M4="$(treehash "$PROJ")"
  out4="$( ( cd "$PROJ" && bash "$MUT4" --sprint s308 --apply ) 2>&1 )"; rc4=$?
  AFTER_M4="$(treehash "$PROJ")"
  if [ "$rc4" -eq 0 ] && [ "$BEFORE_M4" != "$AFTER_M4" ]; then
    ok "MUTATION 4: with the stranding refusal stripped, the rotation proceeds and strands the FAILing legacy verdict (rc=$rc4) — arm (h.1) is live, not vacuous"
  else
    bad "MUTATION 4: stripping the refusal did not change the outcome (rc=$rc4); arm (h.1) may be passing for another reason"
  fi
fi

# =============================================================================
# MUTATION 1 — key selection on the wrong JSON field (`gate_type` instead of
# `gate_series_id`), and the base world's s308 set must fail to be found.
# =============================================================================
MUT1="$W/mut-selection.sh"
sed 's/jq -r '"'"'\.gate_series_id \/\/ empty'"'"'/jq -r ".gate_type \/\/ empty"/' "$ROT" > "$MUT1"
if cmp -s "$ROT" "$MUT1"; then
  bad "MUTATION 1: the sed matched nothing, so the field-selection assertion is UNPROVEN"
else
  chmod +x "$MUT1"
  # A selection keyed on the wrong field selects nothing where the real field selects one --
  # that gap IS the discriminating behaviour change, asserted in the base world where the
  # real field selects the s308 set.
  seed base
  out2="$( ( cd "$PROJ" && bash "$MUT1" --sprint s308 ) 2>&1 )"
  if grep -q 'nothing to move' <<<"$out2"; then
    ok "MUTATION 1: selection keyed on the wrong JSON field (gate_type instead of gate_series_id) finds nothing to move in the base world where the real field selects one -- arm (b)/(a) would FAIL against this subject"
  else
    bad "MUTATION 1: selection keyed on the wrong field still found the s308 set; the field-selection is UNPROVEN by this mutant"
  fi
fi

# =============================================================================
# MUTATION 2 — strip the unparseable-verdict refusal; arm (g) must go red.
# =============================================================================
MUT2="$W/mut-parsecheck.sh"
sed 's/if \[ "\$rc" -ne 0 \]; then/if false; then/' "$ROT" > "$MUT2"
if cmp -s "$ROT" "$MUT2"; then
  bad "MUTATION 2: the sed matched nothing; REFUSAL (g) is UNPROVEN"
else
  chmod +x "$MUT2"
  seed badjson
  out="$( ( cd "$PROJ" && bash "$MUT2" --sprint s308 --apply ) 2>&1 )"; rc=$?
  if [ "$rc" -ne 1 ] || ! grep -q 'do not parse as JSON' <<<"$out"; then
    ok "MUTATION 2: with the parse-failure refusal stripped, an unparseable verdict no longer refuses (rc=$rc) -- arm (g) is live, not vacuous"
  else
    bad "MUTATION 2: stripping the refusal did not change the outcome; arm (g) may be passing for another reason"
  fi
fi

# =============================================================================
# MUTATION 3 — strip the git-ignored-destination refusal; arm (d) must go red.
# =============================================================================
MUT3="$W/mut-ignorecheck.sh"
sed 's/git -C "\$GITROOT" check-ignore -q "\$DEST" 2>\/dev\/null; then/false; then/' "$ROT" > "$MUT3"
if cmp -s "$ROT" "$MUT3"; then
  bad "MUTATION 3: the sed matched nothing; REFUSAL (d) is UNPROVEN"
else
  chmod +x "$MUT3"
  seed ignored
  out="$( ( cd "$PROJ" && bash "$MUT3" --sprint s308 --apply ) 2>&1 )"; rc=$?
  if [ "$rc" -eq 0 ] && [ -d "$DEST_S308" ]; then
    ok "MUTATION 3: with the ignore-check disabled, apply writes into the ignored path instead of refusing -- arm (d) is live, not vacuous"
  else
    bad "MUTATION 3: disabling the ignore check did not change the outcome (rc=$rc, dest exists: $([ -d "$DEST_S308" ] && echo yes || echo no))"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "gate-adjudication-rotate: PASS"
else
  echo "gate-adjudication-rotate: FAIL ($fails)" >&2; exit 1
fi
