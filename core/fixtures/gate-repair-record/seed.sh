#!/usr/bin/env bash
# Seed the gate-repair-record differential.
#
# THE ONE PROPERTY THIS FILE EXISTS TO GUARANTEE: the three cases carry a
# BYTE-IDENTICAL verdict series and differ ONLY in what is on disk under
# planning-artifacts/. That is not asserted here by hope and re-typing — the series is
# written ONCE into a single source directory and COPIED verbatim into each case, so
# the cases cannot drift even if someone edits one of them later. run.sh's first
# assertion `cmp`s them anyway, because a differential whose two arms differ in a
# second variable proves nothing about the first.
#
# Why that matters: a lead that repairs a failed gate check inline produces a verdict
# series indistinguishable from a delegated one. The findings fall either way. Pass 2
# reports fewer FAILs than pass 1 in both cases, at the same nonces, with the same
# evidence strings. The ONLY signal on disk that the repair went to a `remediator`
# rather than to the lead's own Edit tool is the repair record. A validator that reads
# the series instead of the record therefore CANNOT tell these apart, and this seed is
# built so that such a validator fails the fixture instead of passing it.
#
# Prints the temp root on the last line. The caller removes it.
set -u
umask 022

ROOT="$(mktemp -d)"
SPRINT="s302"
GATE="story"
SERIES="story-gate-20260811T1830Z"

# ---------------------------------------------------------------- the one series
# Three passes of ONE gate: constant gate_series_id, per-pass gate_nonce, nonces
# ordered by their timestamps. FAIL counts fall 2 -> 1 -> 0, so a repair is PROVABLE
# between p1/p2 and between p2/p3 and a repair record is owed for p1 and for p2.
#
# The fall is what arms the repair-record arm. A plateau is the stall rung's business
# (K=3 consecutive FAILs on one check_id) and a rise is a regression; neither is proof
# that an edit landed. Check `7` here holds FAIL for exactly TWO consecutive passes —
# one short of the K=3 rung — so this fixture measures the repair record and not the
# rung, and a rung change cannot silently turn these cases red.
SRC="$ROOT/.series-source"
mkdir -p "$SRC"

emit_verdict() {   # $1 nonce  $2..  check:verdict triples
  local nonce="$1"; shift
  local out="$SRC/$nonce.verdict.json" first=1 cid v stamp ts
  ts="${nonce#$GATE-}"                       # 20260811T183000Z
  stamp="${ts:0:4}-${ts:4:2}-${ts:6:2}T${ts:9:2}:${ts:11:2}:${ts:13:2}Z"
  {
    printf '{\n'
    printf '  "schema_id": "GATE_ADJUDICATION_VERDICT v1",\n'
    printf '  "gate_type": "%s",\n' "$GATE"
    printf '  "gate_series_id": "%s",\n' "$SERIES"
    printf '  "gate_nonce": "%s",\n' "$nonce"
    printf '  "generated_at": "%s",\n' "$stamp"
    printf '  "adjudicator_agent_id": "agent-%s",\n' "$nonce"
    printf '  "catalog": "core",\n'
    printf '  "verdicts": [\n'
    for spec in "$@"; do
      cid="${spec%%:*}"; v="${spec##*:}"
      [ "$first" -eq 1 ] || printf ',\n'
      first=0
      printf '    {"check_id": "%s", "verdict": "%s", "evidence": "artifact.md:%s"}' \
        "$cid" "$v" "$cid"
    done
    printf '\n  ]\n}\n'
  } > "$out"
}

emit_verdict "$GATE-20260811T183000Z" 7:FAIL 22:FAIL 24:PASS
emit_verdict "$GATE-20260811T184500Z" 7:FAIL 22:PASS 24:PASS
emit_verdict "$GATE-20260811T190000Z" 7:PASS 22:PASS 24:PASS

# ---------------------------------------------------------------- the three cases
for case_dir in gate-repaired-delegated gate-repaired-inline-no-record gate-repaired-record-off-label \
                gate-repaired-adversarial-record-only gate-repaired-record-beside-verdicts \
                gate-repaired-lead-resolution gate-repaired-adversarial-resolution-only \
                gate-repaired-resolution-off-label; do
  mkdir -p "$ROOT/$case_dir/_bmad-output/gate-adjudication" \
           "$ROOT/$case_dir/_bmad-output/planning-artifacts/$SPRINT"
  cp "$SRC"/*.verdict.json "$ROOT/$case_dir/_bmad-output/gate-adjudication/"
done

# From here the cases diverge, and this is the ONLY place they do.
#
# The record's field labels are read LITERALLY by arm H's `repair_field()`
# (validate-adversarial-convergence.sh) — one label, optionally wrapped in emphasis,
# anchored to the start of the line, colon immediately after. `edit sites:` is a
# RENAMED field, not a wrapped one, and it is the boundary the off-label case holds.
write_record() {   # $1 case  $2 pass-number  $3 edit-label  [$4 explicit destination path]
  cat > "${4:-$ROOT/$1/_bmad-output/planning-artifacts/$SPRINT/gate-$GATE-repair-p$2.md}" <<RECEOF
# Gate repair record — $GATE gate, pass $2

Dispatched \`remediator\`, one per pass, taking that pass's whole FAILED-check set.

## Check 7 — artifact consistency

- disposition: repaired
- $3: _bmad-output/planning-artifacts/$SPRINT/traceability-matrix.md:270
- derivation:
  \`\`\`
  \$ grep -c 'docs/architecture.md:' traceability-matrix.md
  4
  \`\`\`

## Check 22 — spawn ledger

- disposition: repaired
- $3: _bmad-output/planning-artifacts/$SPRINT/test-strategy.md:118
- derivation:
  \`\`\`
  \$ scripts/ai-dlc/validate-artifact-derivations.sh planning-artifacts/$SPRINT/
  OK
  \`\`\`
RECEOF
}

# (a) DELEGATED — a structured record for each repaired pass. Nothing is owed.
write_record gate-repaired-delegated 1 edit
write_record gate-repaired-delegated 2 edit

# (b) INLINE, NO RECORD — the s302 defect. The lead repaired both passes with its own
#     Edit tool and wrote nothing. planning-artifacts/ exists and is EMPTY on purpose:
#     an absent directory and an absent record must not be distinguishable, or the
#     check starts measuring the seed's tidiness instead of the pipeline's conduct.

# (c) OFF-LABEL — the record EXISTS for each repaired pass but renames the field
#     (`edit sites:` for `edit:`). This is the boundary that keeps the arm honest at
#     the other end: widen the field reader far enough to admit this and it also
#     matches ordinary prose, and an arm that matches prose cannot fire.
write_record gate-repaired-record-off-label 1 "edit sites"
write_record gate-repaired-record-off-label 2 "edit sites"

# (d) ADVERSARIAL RECORD ONLY — a WELL-FORMED record, in the right sprint directory, with
#     the matching pass number, and of the WRONG KIND. The adversarial caller of the same
#     procedure writes `s<N>-<artifact>-repair-p<M>.md` there (check-24's own seeds use
#     exactly this shape); the gate caller writes `gate-<type>-repair-p<M>.md`. They are
#     siblings in one directory and only the prefix separates them.
#
#     THIS CASE IS WHY THE GLOB IS PREFIXED RATHER THAN LOOSE. A `*-repair-p<M>.md` glob
#     adopts the adversarial record as the gate record and the arm passes with no gate
#     record written at all — the inline-repair hole reopened by the check meant to close
#     it. Measured on the reference consumer's real tree: 74 adversarial repair records
#     exist, 50 of them carry a matching pass number, and ZERO gate records exist. The
#     prefixed glob reports 18 missing there; the loose one reports 0. The restriction is
#     the difference between an arm that works and an arm that is vacuous on the exact
#     corpus it was written for.
write_record gate-repaired-adversarial-record-only 1 edit \
  "$ROOT/gate-repaired-adversarial-record-only/_bmad-output/planning-artifacts/$SPRINT/$SPRINT-story-repair-p1.md"
write_record gate-repaired-adversarial-record-only 2 edit \
  "$ROOT/gate-repaired-adversarial-record-only/_bmad-output/planning-artifacts/$SPRINT/$SPRINT-story-repair-p2.md"

# (e) RECORD BESIDE THE VERDICTS — correctly named, correctly structured, in the location
#     the arm ORIGINALLY looked in. `_gate-procedures.md` puts the verdict under
#     `gate-adjudication/` and the gate repair record under `planning-artifacts/s<N>/`;
#     the first cut of the arm derived the record directory as dirname(verdict) and so
#     demanded it here. That inherited arm H's derivation, which is CORRECT for the
#     adversarial caller — there the passes and the records genuinely co-locate — and the
#     gate is the one caller where it stops being true. Pinning it means the regression
#     cannot come back as a silent pass on a tree where nothing writes here.
write_record gate-repaired-record-beside-verdicts 1 edit \
  "$ROOT/gate-repaired-record-beside-verdicts/_bmad-output/gate-adjudication/gate-$GATE-repair-p1.md"
write_record gate-repaired-record-beside-verdicts 2 edit \
  "$ROOT/gate-repaired-record-beside-verdicts/_bmad-output/gate-adjudication/gate-$GATE-repair-p2.md"

# (f) LEAD RESOLUTION — no remediator repaired anything, and none could have. The FAILs
#     closed on an edit to a file the remediation guard leaves LEAD-editable
#     (ai-dlc-gate-remediation-guard.sh:336-337: `docs/escalations/**` and
#     `*-resolution-p*.md`), so a repair record would assert a dispatch that never
#     happened. The record is at `gate-<type>-resolution-p<M>.md` and carries the same
#     three fields. Nothing is owed.
#
#     WITHOUT THIS CASE the arm's only accepted name is the remediator's, and a lead is
#     left choosing between fabricating a dispatch and taking a MISSING finding for work
#     correctly done. It is also the case that makes the second suffix load-bearing:
#     delete the suffix from the validator's comprehension and only this case goes red.
write_record gate-repaired-lead-resolution 1 edit \
  "$ROOT/gate-repaired-lead-resolution/_bmad-output/planning-artifacts/$SPRINT/gate-$GATE-resolution-p1.md"
write_record gate-repaired-lead-resolution 2 edit \
  "$ROOT/gate-repaired-lead-resolution/_bmad-output/planning-artifacts/$SPRINT/gate-$GATE-resolution-p2.md"

# (g) ADVERSARIAL RESOLUTION ONLY — case (d) one suffix over, and it is what keeps the
#     `gate-` anchor load-bearing on the NEW name. `<artifact>-resolution-p<M>.md` is the
#     adversarial cycle's resolution record (_gate-procedures.md:324) and sits in the same
#     sprint directory with the same pass numbers. On the reference consumer's real tree,
#     depth 2 under planning-artifacts: 17 files match `*-resolution-p<M>.md`, 16 of them
#     adversarial and one a gate record — so an unanchored second suffix would pull in
#     sixteen foreign records.
#
#     IT IS SEEDED STRUCTURED ON PURPOSE, and that is deliberately harder than the real
#     corpus, where zero of those 16 carry all three fields under arm H's reader. A seed
#     that leans on their being unstructured would leave the anchor untested: drop it and
#     the arm would still say UNSTRUCTURED, the assertion regex would still match, and the
#     mutant would come back green. Structured, the anchor is the ONLY thing between this
#     file and a false PASS, which is exactly the property the case is here to pin.
write_record gate-repaired-adversarial-resolution-only 1 edit \
  "$ROOT/gate-repaired-adversarial-resolution-only/_bmad-output/planning-artifacts/$SPRINT/$GATE-resolution-p1.md"
write_record gate-repaired-adversarial-resolution-only 2 edit \
  "$ROOT/gate-repaired-adversarial-resolution-only/_bmad-output/planning-artifacts/$SPRINT/$GATE-resolution-p2.md"

# (h) RESOLUTION, OFF-LABEL — case (c) on the new name. The accepted NAME widened; the
#     STANDARD did not. A resolution record still has to carry `disposition:`, `edit:` and
#     `derivation:` read literally, or the second suffix becomes a way to close any FAIL by
#     filing a differently-named file. This is also the reference consumer's actual state:
#     its one `gate-implementation-resolution-p1.md` states its disposition, its edit site
#     and its derivation in PROSE and labels none of them, so it scores unstructured under
#     arm H's reader and this case is what says so out loud.
write_record gate-repaired-resolution-off-label 1 "edit sites" \
  "$ROOT/gate-repaired-resolution-off-label/_bmad-output/planning-artifacts/$SPRINT/gate-$GATE-resolution-p1.md"
write_record gate-repaired-resolution-off-label 2 "edit sites" \
  "$ROOT/gate-repaired-resolution-off-label/_bmad-output/planning-artifacts/$SPRINT/gate-$GATE-resolution-p2.md"

# ---------------------------------------------------------------- the Check 22 repair pair
# A SECOND differential, on the IMPLEMENTATION gate, kept apart from the story series above:
# run.sh compares every case of $CASES against the story series byte for byte, so these two
# cases have their own source and their own comparison. Check 22 FAILs at pass 1 and PASSes at
# pass 2. Between them the lead repaired the ledger the operator-free way (gate-validation.md
# Check 22, the remediable classes): a re-dispatch naming each violating row on a
# `remediates: <tool_use_id>` line, then validate-spawn-ledger.sh exiting 0. No remediator
# edited an artifact, so the record is the LEAD's resolution record,
# `gate-implementation-resolution-p1.md`, carrying `disposition:`, `edit:` and `derivation:`
# that name each R, its `remediates:` target and the validator's COUNTS line. The pair differs
# ONLY in whether that record exists, so the record is the one thing the arm can be reading.
SRC2="$ROOT/.series-source-c22"
mkdir -p "$SRC2"
emit_c22() {   # $1 nonce  $2 check-22 verdict
  local ts="${1#implementation-}"
  local stamp="${ts:0:4}-${ts:4:2}-${ts:6:2}T${ts:9:2}:${ts:11:2}:${ts:13:2}Z"
  cat > "$SRC2/$1.verdict.json" <<C22EOF
{
  "schema_id": "GATE_ADJUDICATION_VERDICT v1",
  "gate_type": "implementation",
  "gate_series_id": "implementation-gate-20261010T2300Z",
  "gate_nonce": "$1",
  "generated_at": "$stamp",
  "adjudicator_agent_id": "agent-$1",
  "catalog": "core",
  "verdicts": [
    {"check_id": "22", "verdict": "$2", "evidence": "scripts/ai-dlc/validate-spawn-ledger.sh --sprint 317"},
    {"check_id": "24", "verdict": "PASS", "evidence": "artifact.md:24"}
  ]
}
C22EOF
}
emit_c22 implementation-20261010T230257Z FAIL
emit_c22 implementation-20261010T234500Z PASS
for case_dir in gate-c22-remediated-resolution gate-c22-remediated-no-record; do
  mkdir -p "$ROOT/$case_dir/_bmad-output/gate-adjudication" \
           "$ROOT/$case_dir/_bmad-output/planning-artifacts/s317"
  cp "$SRC2"/*.verdict.json "$ROOT/$case_dir/_bmad-output/gate-adjudication/"
done
cat > "$ROOT/gate-c22-remediated-resolution/_bmad-output/planning-artifacts/s317/gate-implementation-resolution-p1.md" <<'RESEOF'
# Gate resolution record — implementation gate, pass 1

Check 22 FAILed at pass 1 on remediable-class rows only. Each was repaired by a re-dispatch of
its role naming it on a `remediates:` line; no escalation entry and no operator line.

## Check 22 — spawn ledger

- disposition: remediated (classes cite, shard, cover); recorded PASS at pass 2
- edit: _bmad-output/spawn-ledger.jsonl — R toolu_01REMR00000000000000001 remediates: toolu_01REMINV000000000000001 (shard); R toolu_01CITR000000000000000001 remediates: toolu_01CITV000000000000000001 (cite); R toolu_01COVR000000000000000001 remediates: toolu_01COVV000000000000000001 (cover)
- derivation:
  ```
  $ scripts/ai-dlc/validate-spawn-ledger.sh --sprint 317
  REMEDIATED: toolu_01REMINV000000000000001 by toolu_01REMR00000000000000001 (shard)
  REMEDIATED: toolu_01CITV000000000000000001 by toolu_01CITR000000000000000001 (cite)
  REMEDIATED: toolu_01COVV000000000000000001 by toolu_01COVR000000000000000001 (cover)
  COUNTS: examined 7 S317 spawn row(s) of 7 in _bmad-output/spawn-ledger.jsonl;
    remediation (classes: cite shard cover): remediated=3 pending-remedy=0
  exit 0
  ```
RESEOF
# gate-c22-remediated-no-record: planning-artifacts/s317/ exists and is EMPTY on purpose.

rm -rf "$SRC" "$SRC2"
echo "$ROOT"
