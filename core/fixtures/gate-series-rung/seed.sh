#!/usr/bin/env bash
# Seed the gate-series-rung differentials and print the root.
#
# Every case is a full PRESCRIBED layout — <case>/_bmad-output/gate-adjudication/ — because
# the validator derives the repair-record location from the verdict path by walking UP out of
# gate-adjudication/. A flat directory of verdicts would exercise a path the pipeline never
# produces, and the repair-record arm shipped a defect that a flat seed could not have caught.
#
# Each PAIR differs in exactly ONE variable, and run.sh asserts that before asserting anything
# else. A pair that differs in two places proves nothing about which one the validator read.
set -uo pipefail

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gate-series-rung.XXXXXX")" || exit 2

python3 - "$ROOT" <<'PY'
import json, os, sys

root = sys.argv[1]


def verdict(case, nonce, sid, checks, gate_type="story"):
    d = os.path.join(root, case, "_bmad-output", "gate-adjudication")
    os.makedirs(d, exist_ok=True)
    doc = {
        "schema_id": "GATE_ADJUDICATION_VERDICT v1",
        "gate_type": gate_type,
        "gate_series_id": sid,
        "gate_nonce": nonce,
        "generated_at": "2026-08-11T18:30:00Z",
        "adjudicator_agent_id": "gate-adjudicator-fixture",
        "catalog": "core",
        "verdicts": [
            {"check_id": c, "verdict": v, "evidence": "fixture: check %s" % c}
            for c, v in sorted(checks.items())
        ],
    }
    with open(os.path.join(d, nonce + ".verdict.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(doc, indent=2) + "\n")


def N(i):
    return "story-20260811T18%02d00Z" % i


S = "story-gate-20260811T1830Z"

# --- PAIR 1: the stall rung. Same four passes; ONE verdict value differs. -----------------
# stall-fires   check 7 FAILs passes 2,3,4 -> a run of 3, exactly K.
# stall-silent  pass 3 PASSes -> runs of 1 and 1. Deliberately NOT a run of 2: a silent case
#               sitting one short of K would go red the moment K changed, and the reader
#               would blame the change under test instead of the threshold.
for i, v in enumerate(["PASS", "FAIL", "FAIL", "FAIL"], start=1):
    verdict("stall-fires", N(i), S, {"7": v, "22": "PASS"})
for i, v in enumerate(["PASS", "FAIL", "PASS", "FAIL"], start=1):
    verdict("stall-silent", N(i), S, {"7": v, "22": "PASS"})

# --- PAIR 2: the split-series defeat. Verdicts BYTE-IDENTICAL; only the series id moves. --
# split-joined  four FAILs under one id            -> the stall rung catches it.
# split-defeat  the same four, id changes midway   -> neither half reaches K; the boundary
#                                                     arm is the only thing that can see it.
for i in range(1, 5):
    verdict("split-joined", N(i), S, {"7": "FAIL"})
for i in range(1, 5):
    verdict("split-defeat", N(i), S if i <= 2 else S + "-reset", {"7": "FAIL"})
# honest-reset  the same boundary, but the reset actually CLEARED the stall. Must stay
#               silent, or the arm degenerates into "series boundaries are illegal" and
#               contradicts the reset semantics it is supposed to preserve.
for i, v in enumerate(["FAIL", "FAIL", "PASS", "PASS"], start=1):
    verdict("split-honest-reset", N(i), S if i <= 2 else S + "-reset", {"7": v})

# --- PAIR 3: the nonce is the SORT KEY. Same five verdicts; one nonce renamed. -----------
# nonce-sortable    PASS first, then four FAILs -> a run of 4.
# nonce-unsortable  the same five, with the PASS re-nonced to "<ts>-arch" (the shape of the
#                   one non-conforming file in the reference corpus). It sorts into the
#                   MIDDLE and splits the run 2+2 — the rung goes silent with no verdict
#                   value changed.
for i, v in enumerate(["PASS", "FAIL", "FAIL", "FAIL", "FAIL"], start=1):
    verdict("nonce-sortable", N(i), S, {"7": v})
verdict("nonce-unsortable", "story-20260811T182000Z-arch", S, {"7": "PASS"})
for i, v in enumerate(["FAIL", "FAIL", "FAIL", "FAIL"], start=2):
    verdict("nonce-unsortable", N(i), S, {"7": v})

# --- PAIR 4: the legacy posture, which is the mode's ONLY fail-open. ----------------------
# legacy-retained     a prior series retained on disk after a reset: no series id, and every
#                     nonce sorts strictly BEFORE the live series. Counted, named, exit 0.
# legacy-interleaved  the same file moved INSIDE the live series' span. That is not a
#                     retained series, it is a live pass with its id deleted — the one-field
#                     edit that would shorten a run — and it must block.
for i in range(3, 6):
    verdict("legacy-retained", N(i), S, {"7": "PASS"})
    verdict("legacy-interleaved", N(i), S, {"7": "PASS"})
for case, nonce in (("legacy-retained", N(1)),
                    ("legacy-interleaved", "story-20260811T180430Z")):  # noqa: E501 (paired above)
    d = os.path.join(root, case, "_bmad-output", "gate-adjudication")
    doc = {
        "schema_id": "GATE_ADJUDICATION_VERDICT v1",
        "gate_type": "story",
        "gate_nonce": nonce,
        "generated_at": "2026-08-11T18:00:00Z",
        "adjudicator_agent_id": "gate-adjudicator-fixture",
        "catalog": "core",
        "verdicts": [{"check_id": "7", "verdict": "PASS", "evidence": "fixture"}],
    }
    with open(os.path.join(d, nonce + ".legacy.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(doc, indent=2) + "\n")

# --- a COMPLIANT repair trail in every case, so each case isolates the arm under test -----
# The arms of --series interact: wherever a pass's FAILs fall, the repair-record arm owes a
# record, and without one every "must stay silent" case here would exit 1 for a reason this
# fixture is not about. Records are written for EVERY pass index rather than only the ones
# that fall — over-provisioning is safe here precisely because this fixture makes no claim
# about the repair arm. That arm's own differential is `gate-repair-record`, which seeds the
# records deliberately and asserts on their presence; if you want to know whether a missing
# record is caught, that is the fixture to read, not this one.
STRUCTURED = ("- disposition: repaired\n"
              "- **edit:** docs/architecture.md:1483\n"
              "- derivation: `grep -c reconcileHandler tests/` -> 3\n")
for case in sorted(os.listdir(root)):
    gdir = os.path.join(root, case, "_bmad-output", "gate-adjudication")
    if not os.path.isdir(gdir):
        continue
    sdir = os.path.join(root, case, "_bmad-output", "planning-artifacts", "s302")
    os.makedirs(sdir, exist_ok=True)
    for M in range(1, len(os.listdir(gdir)) + 1):
        with open(os.path.join(sdir, "gate-story-repair-p%d.md" % M), "w",
                  encoding="utf-8") as fh:
            fh.write(STRUCTURED)
PY

printf '%s\n' "$ROOT"
