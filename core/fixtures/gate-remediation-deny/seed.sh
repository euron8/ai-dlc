#!/usr/bin/env bash
# seed.sh <case> -> prints the path of a throwaway workspace
#
# One workspace shape, five gate states. Everything the guard reads is here and
# nothing it reads is anywhere else, so an arm that passes because the state was
# absent rather than because the guard held is not representable.
set -uo pipefail

CASE="${1:-open-fail}"

# A SEED THAT FAILS SILENTLY SCORES EXACTLY LIKE A HOOK THAT DENIES NOTHING, AND THIS
# IS NOT HYPOTHETICAL. Observed once on a scratch volume under load: `mktemp -d`/the
# writes below did not produce a usable workspace, the guard exited at its
# no-pipeline-snapshot arm for every call, and the fixture reported 20 assertion
# failures -- the same count and nearly the same set as deleting the deny outright.
# Measured: a workspace missing only the snapshot yields exactly 20 failures. So every
# step that can fail is checked here, and the caller re-checks what it received.
W="$(mktemp -d "${TMPDIR:-/tmp}/gate-remediation-deny.XXXXXX" 2>/dev/null)" || W=""
[ -n "$W" ] && [ -d "$W" ] || { echo "seed.sh: mktemp -d failed; no workspace" >&2; exit 2; }

mkdir -p "$W/_bmad-output/gate-adjudication" \
         "$W/_bmad-output/planning-artifacts/s302" \
         "$W/_bmad-output/implementation-artifacts" \
         "$W/docs/escalations" \
         "$W/scripts/ai-dlc" \
         "$W/src"

# The pipeline snapshot is the "this is an ai-dlc session" gate every hook shares.
cat > "$W/_bmad-output/pipeline-snapshot.md" <<'EOF'
# Pipeline Snapshot
sprint: 302
step: gate-validation [story]
EOF
: > "$W/_bmad-output/pipeline-snapshot-history.md"

printf 'sprint: 302\n' > "$W/_bmad-output/planning-artifacts/sprint-status.yaml"
printf 'sprint: 302\n' > "$W/_bmad-output/implementation-artifacts/sprint-status.yaml"

# The artifacts the reference consumer's lead actually edited during the cascade.
printf '# Test Strategy\n' > "$W/_bmad-output/planning-artifacts/s302/test-strategy.md"
printf '# Traceability\n'   > "$W/_bmad-output/planning-artifacts/s302/traceability-matrix.md"
printf '# Architecture\n'   > "$W/docs/architecture.md"
printf '# Pending\n'        > "$W/docs/escalations/pending.md"
printf 'int main(){}\n'     > "$W/src/main.c"

verdict() { # <nonce> <json-verdicts-array>
  cat > "$W/_bmad-output/gate-adjudication/$1.verdict.json" <<EOF
{
  "schema_id": "GATE_ADJUDICATION_VERDICT v1",
  "gate_type": "story",
  "gate_nonce": "$1",
  "generated_at": "2026-08-11T19:30:44Z",
  "adjudicator_agent_id": "gate-adjudicator@session-seed",
  "catalog": "core",
  "verdicts": $2
}
EOF
}

FAILING='[{"check_id":"7","verdict":"FAIL","evidence":"citation drift in test-strategy.md"},
          {"check_id":"3a","verdict":"FAIL","evidence":"story AC not traced"},
          {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'
CLEAN='[{"check_id":"7","verdict":"PASS","evidence":"citations resolve"},
        {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'

case "$CASE" in
  open-fail)
    verdict "story-20260811T193044Z" "$FAILING"
    ;;
  pass)
    verdict "story-20260811T193044Z" "$CLEAN"
    ;;
  stale-then-clean)
    # An OLDER pass failed; a NEWER pass came back clean. Ordering is by nonce, so
    # the live pass is the clean one and the gate is out of remediation.
    verdict "story-20260811T193044Z" "$FAILING"
    verdict "story-20260811T204512Z" "$CLEAN"
    ;;
  unparseable)
    printf '{ "schema_id": "GATE_ADJUDICATION_VERDICT v1", "verdicts": [ \n' \
      > "$W/_bmad-output/gate-adjudication/story-20260811T193044Z.verdict.json"
    ;;
  no-gate)
    rmdir "$W/_bmad-output/gate-adjudication"
    ;;
  *)
    echo "seed.sh: unknown case '$CASE'" >&2; rm -rf "$W"; exit 2 ;;
esac

# THE SEED CERTIFIES ITS OWN OUTPUT. Every arm of every case depends on the snapshot
# (the guard's "is this an ai-dlc session" gate) and on the artifact under test
# existing; `no-gate` is the one case that deliberately has no gate directory.
for _need in "$W/_bmad-output/pipeline-snapshot.md" \
             "$W/_bmad-output/planning-artifacts/s302/test-strategy.md" \
             "$W/_bmad-output/planning-artifacts/sprint-status.yaml" \
             "$W/docs/architecture.md"; do
  [ -s "$_need" ] || { echo "seed.sh: FAILED to write ${_need#$W/} for case '$CASE'" >&2; rm -rf "$W"; exit 2; }
done
if [ "$CASE" != "no-gate" ]; then
  ls "$W"/_bmad-output/gate-adjudication/*.verdict.json >/dev/null 2>&1 \
    || { echo "seed.sh: case '$CASE' wrote no verdict file" >&2; rm -rf "$W"; exit 2; }
fi

printf '%s' "$W"
