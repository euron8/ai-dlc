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

verdict() { # <nonce> <json-verdicts-array> [catalog|"none"]
  # The third argument exists because arm 7b joins on the verdict's OWN catalog. `none` omits
  # the field entirely, which is the shape that must join against nothing at all.
  _cat="${3:-core}"
  _catline="  \"catalog\": \"${_cat}\","
  [ "$_cat" = "none" ] && _catline=""
  cat > "$W/_bmad-output/gate-adjudication/$1.verdict.json" <<EOF
{
  "schema_id": "GATE_ADJUDICATION_VERDICT v1",
  "gate_type": "story",
  "gate_nonce": "$1",
  "generated_at": "2026-08-11T19:30:44Z",
  "adjudicator_agent_id": "gate-adjudicator@session-seed",
${_catline}
  "verdicts": $2
}
EOF
}

# --- arm 7b's inputs ---------------------------------------------------------------------
# SEEDED FROM WHAT THE REAL PRODUCER EMITS, never from what the reader accepts: the sibling
# and the enforcement map are the SHIPPED files, copied in, and the entry is written in the
# `**Status:** / **Suppresses:** / **Expires after:** / **Operator authorization:**` shape
# `escalations.md` prescribes and the reference consumer's `pending.md` actually carries.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HERE="$(cd "$(dirname "$0")" && pwd)"

install_sibling() { # copy the real validate-suppression-lifetime.sh + catalog into $W
  local sib map
  sib="$(pick "$HERE/../../scripts/validate-suppression-lifetime.sh" \
              "$HERE/../../../scripts/ai-dlc/validate-suppression-lifetime.sh" \
              "$HERE/../../core/scripts/validate-suppression-lifetime.sh")"
  map="$(pick "$HERE/../../skills/ai-dlc/enforcement-map.yaml" \
              "$HERE/../../../.claude/skills/ai-dlc/enforcement-map.yaml" \
              "$HERE/../../core/skills/ai-dlc/enforcement-map.yaml")"
  [ -n "$sib" ] || { echo "seed.sh: cannot locate validate-suppression-lifetime.sh; every 7b arm would read as no-sibling" >&2; rm -rf "$W"; exit 2; }
  [ -n "$map" ] || { echo "seed.sh: cannot locate enforcement-map.yaml; the sibling would refuse and every 7b arm would read as refused" >&2; rm -rf "$W"; exit 2; }
  mkdir -p "$W/.claude/skills/ai-dlc"
  cp "$sib" "$W/scripts/ai-dlc/validate-suppression-lifetime.sh" || { echo "seed.sh: sibling copy failed" >&2; rm -rf "$W"; exit 2; }
  cp "$map" "$W/.claude/skills/ai-dlc/enforcement-map.yaml"      || { echo "seed.sh: catalog copy failed" >&2; rm -rf "$W"; exit 2; }
  # ...and the CITATION verifier arm 7b runs on every covering entry. Without it the guard
  # fails closed on every 7b case and the whole family would score DENY for the wrong reason.
  steer="$(pick "$HERE/../../scripts/validate-steering-budget.sh" \
                "$HERE/../../../scripts/ai-dlc/validate-steering-budget.sh" \
                "$HERE/../../core/scripts/validate-steering-budget.sh")"
  [ -n "$steer" ] || { echo "seed.sh: cannot locate validate-steering-budget.sh; arm 7b would fail closed on every case and the ALLOW arms would read as the guard holding" >&2; rm -rf "$W"; exit 2; }
  cp "$steer" "$W/scripts/ai-dlc/validate-steering-budget.sh" || { echo "seed.sh: verifier copy failed" >&2; rm -rf "$W"; exit 2; }
  transcripts
}

metrics() { # <file> <n-gate-events-after-the-authorization>
  local f="$1" n="$2" i=1
  mkdir -p "$(dirname "$f")"
  : > "$f"
  while [ "$i" -le "$n" ]; do
    printf '{"ts":"2026-08-%02dT00:00:00Z","check":"7","verdict":"FAIL"}\n' "$((4 + i))" >> "$f"
    i=$((i + 1))
  done
}

suppression() { # <suppresses-field-value> <expires> [operator-quote]
  # The default quote is the one the transcript corpus below carries, so a suppression is by
  # default GENUINE and a forgery is spelled out at the one call site that wants one.
  cat > "$W/docs/escalations/pending.md" <<EOF
# Pending

## [S302-GATE3-STORY-1] [lead] - 2026-08-01T00:00:00Z — seeded suppression

**Status:** SUPPRESSED (operator, 2026-08-01T00:00:00Z)

**Suppresses:** $1 — seeded target for the gate-remediation carve-out
**Expires after:** $2 gates
**Operator authorization:** 2026-08-01T00:00:00Z | "${3:-Operator-suppress this FAIL (Recommended)}"

Body prose, so the entry is not a bare field block.
EOF
}

# THE TRANSCRIPT CORPUS THE CITATION IS VERIFIED AGAINST. Written in the harness's own shape --
# a `*.jsonl` file of `{"type":"user", ...}` records -- because the reader is
# validate-steering-budget.sh --cite and seeding from what that reader accepts rather than from
# what the harness emits would prove only that it accepts its own grammar. The guard is driven
# with a `transcript_path` INSIDE this directory; the corpus is the directory.
transcripts() {
  mkdir -p "$W/sessions-jsonl"
  cat > "$W/sessions-jsonl/monday.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-08-01T00:00:00Z","message":{"content":"Operator-suppress this FAIL (Recommended)"}}
EOF
  : > "$W/sessions-jsonl/current.jsonl"
}

FAILING='[{"check_id":"7","verdict":"FAIL","evidence":"citation drift in test-strategy.md"},
          {"check_id":"3a","verdict":"FAIL","evidence":"story AC not traced"},
          {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'
CLEAN='[{"check_id":"7","verdict":"PASS","evidence":"citations resolve"},
        {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'
# ONE failing check, so "every live FAIL is covered" and "some remain" are separate seeds
# rather than the same seed read two ways.
FAILING1='[{"check_id":"7","verdict":"FAIL","evidence":"citation drift in test-strategy.md"},
           {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'

# The id-grain pair. `3` and `3a` are both real catalog ids, so neither seed can pass the
# sibling's catalog join by accident and the only thing separating them is the token grain.
FAILING_3='[{"check_id":"3","verdict":"FAIL","evidence":"story AC not traced"},
            {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'
FAILING_3A='[{"check_id":"3a","verdict":"FAIL","evidence":"story AC not traced"},
             {"check_id":"2","verdict":"PASS","evidence":"escalation census clean"}]'

METRICS="$W/_bmad-output/implementation-artifacts/gate-metrics.jsonl"

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

  # --- arm 7b, THE SUPPRESSED CARVE-OUT -----------------------------------------------
  # Every case below is `open-fail` plus one changed property, so each arm of the fixture
  # discriminates on that property alone.
  suppressed)
    # The whole FAIL set is covered, in force. This is the ALLOW.
    verdict "story-20260811T193044Z" "$FAILING1"
    install_sibling; suppression "[core] 7" 3; metrics "$METRICS" 2
    # ...and an ALTERNATE timeline that expires the same entry. Nothing reads it unless a
    # caller passes AI_DLC_GATE_METRICS, which is what gives that channel a subject.
    metrics "$W/alt-gate-metrics.jsonl" 5
    ;;
  suppressed-forged)
    # THE SELF-DISCHARGE. Arm 6 lets the lead write pending.md while denied, so this entry is
    # one the lead can author -- everything about it is well-formed and in force, and the only
    # thing wrong with it is that no operator ever said the words.
    verdict "story-20260811T193044Z" "$FAILING1"
    install_sibling; metrics "$METRICS" 2
    suppression "[core] 7" 3 "the operator never said this sentence"
    ;;
  suppressed-superset)
    # THE ID GRAIN. The suppression names `3a`; the only live FAIL is `3`. A substring join
    # acquits it, and `3` is a different check from `3a` in every catalog that has both.
    verdict "story-20260811T193044Z" "$FAILING_3"
    install_sibling; suppression "[core] 3a" 3; metrics "$METRICS" 2
    ;;
  suppressed-subset)
    # The mirror: the suppression names `3`, the live FAIL is `3a`.
    verdict "story-20260811T193044Z" "$FAILING_3A"
    install_sibling; suppression "[core] 3" 3; metrics "$METRICS" 2
    ;;
  suppressed-expired)
    # IDENTICAL to `suppressed` but for the number of gate events recorded after the
    # authorization. 5 > **Expires after:** 3, so the sibling does not list the entry.
    verdict "story-20260811T193044Z" "$FAILING1"
    install_sibling; suppression "[core] 7" 3; metrics "$METRICS" 5
    ;;
  suppressed-wrongcat)
    # The entry names a catalog this verdict is not in.
    verdict "story-20260811T193044Z" "$FAILING1"
    install_sibling; suppression "[ext-catalog] 7" 3; metrics "$METRICS" 2
    ;;
  suppressed-bare)
    # No bracket at all. The sibling resolves a bare id against the core catalog alone, so
    # it can only ever have meant `core` -- and this verdict is an extension's.
    verdict "story-20260811T193044Z" "$FAILING1" "some-extension"
    install_sibling; suppression "7" 3; metrics "$METRICS" 2
    ;;
  suppressed-nocat)
    # A verdict with NO catalog field joins against nothing, exactly as the gate validator's
    # `str(V.get("catalog",""))` does. Fail-closed, and measured at 0 of the reference
    # consumer's 195 verdict files.
    verdict "story-20260811T193044Z" "$FAILING1" "none"
    install_sibling; suppression "[core] 7" 3; metrics "$METRICS" 2
    ;;
  suppressed-partial)
    # Two FAILs, one covered. The deny must survive and must name both halves.
    verdict "story-20260811T193044Z" "$FAILING"
    install_sibling; suppression "[core] 7" 3; metrics "$METRICS" 2
    ;;
  suppressed-nosibling)
    # `suppressed`, with the one thing arm 7b cannot do without.
    verdict "story-20260811T193044Z" "$FAILING1"
    suppression "[core] 7" 3; metrics "$METRICS" 2
    ;;
  suppressed-noesc)
    # `suppressed`, with no escalations file to read.
    verdict "story-20260811T193044Z" "$FAILING1"
    install_sibling; metrics "$METRICS" 2
    rm -f "$W/docs/escalations/pending.md"
    ;;
  suppressed-oldsibling)
    # A CONSUMER RUNS ITS OWN INSTALLED ENGINE, and this hook can arrive one pull ahead of a
    # sibling that dispatches the mode it asks for. Measured on the reference consumer while
    # this was written: its installed copy predated `--in-force` and exited 2 on the flag,
    # then a pull mid-session replaced it -- so the state was real, and the arm outlives it.
    # DERIVED from the shipped file by deleting the dispatch line, not hand-written: a stub
    # would prove only that this hook handles a stub.
    verdict "story-20260811T193044Z" "$FAILING1"
    install_sibling; suppression "[core] 7" 3; metrics "$METRICS" 2
    _old="$W/scripts/ai-dlc/validate-suppression-lifetime.sh"
    cp "$_old" "$_old.orig"
    sed -i.bak '/^    --in-force)/d' "$_old"; rm -f "$_old.bak"
    if cmp -s "$_old" "$_old.orig"; then
      echo "seed.sh: case '$CASE' removed no --in-force dispatch line; the sibling still accepts the flag and the case would measure 'ok'" >&2
      rm -rf "$W"; exit 2
    fi
    rm -f "$_old.orig"
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

# ARM 7b'S INPUTS ARE CERTIFIED SEPARATELY, IN BOTH DIRECTIONS. Every absence arm 7b knows
# about produces a DENY, which is also what a correct guard produces on a covered set it
# could not read -- so a seed that quietly failed to place the sibling scores an
# indistinguishable pass. The `nosibling` and `noesc` cases assert the ABSENCE for the same
# reason: if the base seed ever starts shipping those files, those two arms would be
# measuring `ok` and reporting the fail-closed path.
case "$CASE" in
  suppressed|suppressed-expired|suppressed-wrongcat|suppressed-bare|suppressed-nocat|suppressed-partial|suppressed-oldsibling|suppressed-forged|suppressed-superset|suppressed-subset)
    for _need in "$W/scripts/ai-dlc/validate-suppression-lifetime.sh" \
                 "$W/.claude/skills/ai-dlc/enforcement-map.yaml" \
                 "$W/docs/escalations/pending.md" \
                 "$METRICS"; do
      [ -s "$_need" ] || { echo "seed.sh: case '$CASE' did not produce ${_need#$W/}; arm 7b would report no-sibling and its DENY would read as the guard holding" >&2; rm -rf "$W"; exit 2; }
    done
    grep -q '^\*\*Suppresses:\*\*' "$W/docs/escalations/pending.md" \
      || { echo "seed.sh: case '$CASE' wrote no **Suppresses:** field, so no entry can ever be in force" >&2; rm -rf "$W"; exit 2; }
    # THE VERIFIER AND ITS CORPUS, both directions. Arm 7b fails CLOSED without either, so a
    # seed that dropped one would make every ALLOW case DENY and read as the guard holding.
    [ -s "$W/scripts/ai-dlc/validate-steering-budget.sh" ] \
      || { echo "seed.sh: case '$CASE' has no citation verifier; arm 7b would fail closed on every entry" >&2; rm -rf "$W"; exit 2; }
    ls "$W"/sessions-jsonl/*.jsonl >/dev/null 2>&1 \
      || { echo "seed.sh: case '$CASE' seeded no transcript corpus; no citation could ever verify" >&2; rm -rf "$W"; exit 2; }
    ;;
  suppressed-nosibling)
    [ ! -f "$W/scripts/ai-dlc/validate-suppression-lifetime.sh" ] \
      || { echo "seed.sh: case '$CASE' HAS a sibling, so it cannot exercise no-sibling" >&2; rm -rf "$W"; exit 2; }
    [ -s "$W/docs/escalations/pending.md" ] \
      || { echo "seed.sh: case '$CASE' has no escalations file either, so the status would be no-escalations-file" >&2; rm -rf "$W"; exit 2; }
    ;;
  suppressed-noesc)
    [ -s "$W/scripts/ai-dlc/validate-suppression-lifetime.sh" ] \
      || { echo "seed.sh: case '$CASE' has no sibling either, so the status would be no-sibling" >&2; rm -rf "$W"; exit 2; }
    [ ! -f "$W/docs/escalations/pending.md" ] \
      || { echo "seed.sh: case '$CASE' HAS an escalations file, so it cannot exercise no-escalations-file" >&2; rm -rf "$W"; exit 2; }
    ;;
esac

printf '%s' "$W"
