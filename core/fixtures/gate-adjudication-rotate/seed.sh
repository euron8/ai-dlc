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
