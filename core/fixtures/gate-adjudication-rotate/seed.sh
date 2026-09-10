#!/usr/bin/env bash
# gate-adjudication-rotate/seed.sh <case> -> prints a throwaway workspace path
#
# One git repo per case, built fresh, because arm (e) DRIVES the gate-remediation
# guard against this same tree before and after rotation and a shared world would
# let one arm's mutation bleed into another's verdict.
#
# THE SCHEMA IS COPIED FROM THE REAL PRODUCER, never invented: the field shapes
# (`schema_id`, `gate_type`, `gate_nonce`, `generated_at`, `adjudicator_agent_id`,
# `catalog`, `verdicts[].check_id/verdict/evidence`) match
# `core/fixtures/gate-remediation-deny/seed.sh`'s `verdict()` helper, and
# `gate_series_id` matches the reference consumer's real shape
# (`planning-s308-20260902T034604Z`).
set -uo pipefail

CASE="${1:-base}"

W="$(mktemp -d "${TMPDIR:-/tmp}/gate-adjudication-rotate.XXXXXX" 2>/dev/null)" || W=""
[ -n "$W" ] && [ -d "$W" ] || { echo "seed.sh: mktemp -d failed" >&2; exit 2; }
PROJ="$W/proj"
mkdir -p "$PROJ/_bmad-output/gate-adjudication" \
         "$PROJ/_bmad-output/planning-artifacts/s309" || { echo "seed.sh: mkdir failed" >&2; exit 2; }

# The guard's "is this an ai-dlc session" gate, present in every case.
cat > "$PROJ/_bmad-output/pipeline-snapshot.md" <<'EOF'
# Pipeline Snapshot
sprint: 309
step: gate-validation [planning]
EOF
printf 'ARTIFACT: seeded lead-editable target under a guarded root.\n' \
  > "$PROJ/_bmad-output/planning-artifacts/s309/x.md"

GA="$PROJ/_bmad-output/gate-adjudication"

verdict() { # <path> <nonce> <series|""> <verdicts-json>
  local path="$1" nonce="$2" series="$3" body="$4" series_line=""
  [ -n "$series" ] && series_line="  \"gate_series_id\": \"${series}\","
  cat > "$path" <<EOF
{
  "schema_id": "GATE_ADJUDICATION_VERDICT v1",
  "gate_type": "${nonce%%-2*}",
  "gate_nonce": "${nonce}",
  "generated_at": "2026-09-07T00:00:00Z",
  "adjudicator_agent_id": "gate-adjudicator@session-seed",
${series_line}
  "catalog": "core",
  "verdicts": ${body}
}
EOF
}

S308_FAIL='[{"check_id":"2","verdict":"FAIL","evidence":"seeded"}]'
S309_ALLPASS='[{"check_id":"1","verdict":"PASS","evidence":"seeded"}]'
S309_FAIL='[{"check_id":"1","verdict":"FAIL","evidence":"seeded, current sprint"}]'
LEGACY_PASS='[{"check_id":"1","verdict":"PASS","evidence":"pre-migration"}]'
# A pre-migration verdict that CONVICTS. The rotator can never move a verdict with
# no gate_series_id, so if this one is left as the newest conforming stem it becomes
# the guard's live pass permanently. Its nonce sorts ABOVE the s308/s309 seeds so it
# survives their rotation and is genuinely newest -- a lower nonce would be shadowed
# and the arm would pass without the property it exists to test.
LEGACY_FAIL='[{"check_id":"7","verdict":"FAIL","evidence":"pre-migration, never repaired"}]'

seed_s308() {
  verdict "$GA/sprint-review-20260907T002257Z.verdict.json" \
          "sprint-review-20260907T002257Z" "sprint-review-s308-20260907T002257Z" "$S308_FAIL"
  printf 'Repair notes (deliberately no remediator_agent_id field).\n' \
    > "$GA/sprint-review-20260907T002257Z.repair.md"
  printf 'Authorization notes (deliberately no operator_authorization field).\n' \
    > "$GA/sprint-review-20260907T002257Z.authorization.md"
}

seed_s309_pass() {
  verdict "$GA/planning-20260907T160702Z.verdict.json" \
          "planning-20260907T160702Z" "planning-s309-20260907T160702Z" "$S309_ALLPASS"
}

seed_legacy() {
  verdict "$GA/implementation-20260720T011606Z.verdict.json" \
          "implementation-20260720T011606Z" "" "$LEGACY_PASS"
}

# The stranding subject: a FAILing legacy verdict. Its nonce sorts BELOW every
# series-bearing seed on purpose -- an earlier revision put it ABOVE, which made
# it newest before the move as well as after, so the rotation never PROMOTED it
# and the move-set exclusion was never exercised. A wrong fix that ignores which
# files are moving passed the whole receipt for exactly that reason.
# Deliberately carries no repair and no authorization sidecar -- with either one
# the guard's lift arms would clear the deny and the case would prove nothing.
seed_legacy_fail() {
  verdict "$GA/legacy-20260701T000000Z.verdict.json" \
          "legacy-20260701T000000Z" "" "$LEGACY_FAIL"
}

# A verdict that SHADOWS the legacy FAIL and does not move for --sprint s308.
# Without it, no world in this fixture holds a FAILing legacy verdict that is
# correctly IGNORED, and a predicate that refuses on any FAILing legacy anywhere
# -- which refuses every rotation on the reference consumer -- passes every arm.
seed_shadow() {
  verdict "$GA/planning-20260910T120000Z.verdict.json" \
          "planning-20260910T120000Z" "planning-s309-20260910T120000Z" "$S309_ALLPASS"
}

# THE SECOND UNMOVABLE SHAPE. `gate-adjudication-verdict.json` leaves
# `gate_series_id` "deliberately unpatterned: required and non-empty, nothing
# more", so a sprint-FIRST id is schema-legal and no `*-s<N>-*` selector can name
# it. Observed on the reference consumer as `s310-planning`, written by a live
# session. It is worse than a legacy verdict: --legacy-through skips it too,
# because it HAS a series id. Neither refusal nor escape reached it until the
# predicate was widened from "is legacy" to "no mode can move it".
seed_unselectable_fail() {
  verdict "$GA/planning-20260701T000000Z.verdict.json" \
          "planning-20260701T000000Z" "s310-planning" "$LEGACY_FAIL"
}

seed_noise() {
  printf '{"line":1}\n' > "$GA/.verdict-writes.jsonl"
  mkdir -p "$GA/s293"
  printf 'unrelated archived note, untouched by any rotation.\n' > "$GA/s293/f.md"
}

case "$CASE" in
  base)
    seed_s308; seed_s309_pass; seed_legacy; seed_noise
    ;;
  ignored)
    seed_s308; seed_s309_pass; seed_legacy; seed_noise
    printf '_bmad-output/implementation-artifacts/s308/\n' > "$PROJ/.gitignore"
    ;;
  guardworld)
    # Only the s308 FAIL verdict (plus its sidecars) and the legacy PASS. No s309
    # verdict yet -- this is the shape that reproduces DEFECT 1: the ONLY
    # conforming pass in the directory is a prior sprint's dispositioned FAIL, so
    # a fresh sprint's first lead edit is denied for a repair nobody owes.
    seed_s308; seed_legacy
    ;;
  legacyonly)
    seed_legacy
    ;;
  # THE STRANDING PAIR. Both cases hold the same s308 verdicts; they differ in ONE
  # property -- whether the legacy verdict left behind CONVICTS. `strand` must be
  # refused, `strand-nearmiss` must proceed. A single case here would leave a
  # refusal that fires on every legacy file indistinguishable from one keyed on the
  # FAIL, and that wrong version refuses 94 files on the reference consumer.
  strand)
    seed_s308; seed_legacy_fail
    ;;
  strand-nearmiss)
    seed_s308; seed_legacy
    ;;
  # The FAILing legacy verdict is SHADOWED by a newer verdict that does not move,
  # so rotating s308 does NOT promote it and the correct answer is PROCEED. This
  # is the world that separates a survivorship predicate from a directory-wide
  # sweep; the other two cases cannot, because in both of them the legacy verdict
  # either is or is not the survivor for reasons that do not involve shadowing.
  strand-shadowed)
    seed_s308; seed_legacy_fail; seed_shadow
    ;;
  # The survivor is UNSELECTABLE rather than legacy: it carries a series id, so
  # the legacy predicate scores it movable and the refusal misses it entirely.
  strand-unselectable)
    seed_s308; seed_unselectable_fail
    ;;
  badjson)
    seed_s308; seed_s309_pass; seed_legacy; seed_noise
    printf '{ "schema_id": "GATE_ADJUDICATION_VERDICT v1", "gate_nonce": "broken-20260101T000000Z", "verdicts": [ \n' \
      > "$GA/broken-20260101T000000Z.verdict.json"
    ;;
  *)
    echo "seed.sh: unknown case '$CASE'" >&2; rm -rf "$W"; exit 2 ;;
esac

( cd "$PROJ" \
  && git init -q . \
  && git add -A \
  && git -c user.email=fixture@ai-dlc -c user.name=fixture commit -qm "seed ${CASE}" ) >/dev/null 2>&1 \
  || { echo "seed.sh: git init/commit failed for case '${CASE}'" >&2; rm -rf "$W"; exit 2; }

# THE SEED CERTIFIES ITS OWN OUTPUT. Every case depends on the snapshot and the
# gate-adjudication directory existing; a seed that silently produced neither
# would make every later assertion read as the rotator holding.
[ -s "$PROJ/_bmad-output/pipeline-snapshot.md" ] \
  || { echo "seed.sh: no pipeline-snapshot.md for case '${CASE}'" >&2; rm -rf "$W"; exit 2; }
[ -d "$GA" ] || { echo "seed.sh: no gate-adjudication dir for case '${CASE}'" >&2; rm -rf "$W"; exit 2; }

cat > "$W/env.sh" <<EOF
PROJ="$PROJ"
GA="$GA"
DEST_S308="$PROJ/_bmad-output/implementation-artifacts/s308/gate-adjudication"
EOF

printf '%s' "$W"
