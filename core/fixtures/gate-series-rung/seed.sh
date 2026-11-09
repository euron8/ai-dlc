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

GSR_DIR="$(cd "$(dirname "$0")" && pwd)" python3 - "$ROOT" <<'PY'
import json, os, sys

root = sys.argv[1]


WAIVER_ID = "[S302 gate — check 7 waived] [lead] - 2026-08-11T18:00:00Z"
# A waiver_id naming NO entry: same shape, same sprint token, no header carries it.
UNRESOLVED_ID = "[S302 gate — no such entry] [lead] - 2026-08-11T18:00:00Z"
WID = {}   # case -> the waiver_id its FAIL_WAIVED rows carry


def entry(c, v, case=None):
    e = {"check_id": c, "verdict": v, "evidence": "fixture: check %s" % c}
    if v == "FAIL_WAIVED":
        # rules.waiver_id: required and non-empty on FAIL_WAIVED, forbidden otherwise.
        e["waiver_id"] = WID.get(case, WAIVER_ID)
    return e


def escalations(case):
    # The OVERRIDDEN entry WAIVER_ID names, in the shape escalations.md prescribes. The rung asks
    # validate-suppression-lifetime.sh --waivers for it; it does not cite-verify.
    d = os.path.join(root, case, "docs", "escalations")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "pending.md"), "w", encoding="utf-8") as fh:
        fh.write("# Pending\n\n## %s\n\n**Status:** OVERRIDDEN\n\n"
                 "**Operator authorization:** 2026-08-11T18:00:00Z | \"waive check 7 for this gate\"\n\n"
                 "The gate failed Check 7; the operator waived it.\n" % WAIVER_ID)


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
        "verdicts": [entry(c, v, case) for c, v in sorted(checks.items())],
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

# --- PAIR 1b: a FAIL_WAIVED pass BREAKS the run only under a waiver that RESOLVES. --------
# The series id carries `-s302-`, the sprint the waiving entry's header names as S302, and each
# case writes its own docs/escalations/pending.md with that OVERRIDDEN entry.
# waived-x3           check 7 FAIL_WAIVED on passes 2,3,4 under the RESOLVING waiver -> no run;
#                     the operator took the check out of the loop. stall-fires with FAIL replaced
#                     by FAIL_WAIVED, so the two differ by that value alone.
# unresolved-x3       the same three FAIL_WAIVED rows under a waiver_id that names NO entry, the
#                     escalations file identical -> each counts as FAIL and the check STALLS.
# waived-then-fail    FAIL_WAIVED (resolving) on pass 1, then FAIL on 2,3,4 -> a NEW run of 3
#                     starting at pass 2. A rung that kept the waiver in the run reports pass 1.
SW = "story-s302-20260811T1830Z"
WID["unresolved-x3"] = UNRESOLVED_ID
for case in ("waived-x3", "unresolved-x3"):
    for i, v in enumerate(["PASS", "FAIL_WAIVED", "FAIL_WAIVED", "FAIL_WAIVED"], start=1):
        verdict(case, N(i), SW, {"7": v, "22": "PASS"})
    escalations(case)
for i, v in enumerate(["FAIL_WAIVED", "FAIL", "FAIL", "FAIL"], start=1):
    verdict("waived-then-fail", N(i), SW, {"7": v, "22": "PASS"})
escalations("waived-then-fail")

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

# --- THE SPRINT-SCOPED WORLDS (--series --sprint <N>). Written AFTER the repair trail above, so
# none of them gets a record: the graph world's MISSING REPAIR RECORD findings are its own. ---------
# graph   the reference consumer's live corpus, rebuilt from graph-corpus.tsv (real stems, nonces,
#         series ids, generated_at and FAIL sets; s302-s307 and 94 legacy files, one of them the
#         unplaceable `planning-20260719T0300-arch`). Every other world below is passed BESIDE it,
#         as a second --series path, so the out-of-scope population is always the real one.
here = os.environ["GSR_DIR"]
gw = os.path.join(root, "graph", "_bmad-output", "gate-adjudication")
os.makedirs(gw)
for line in open(os.path.join(here, "graph-corpus.tsv"), encoding="utf-8"):
    if line.startswith("#") or not line.strip():
        continue
    stem, gt, nonce, sid, gen, fails = line.rstrip("\n").split("\t")
    doc = {"schema_id": "GATE_ADJUDICATION_VERDICT v1", "gate_type": gt}
    if sid != "-":
        doc["gate_series_id"] = sid
    doc["gate_nonce"] = nonce
    if gen != "-":
        doc["generated_at"] = gen
    doc["adjudicator_agent_id"] = "gate-adjudicator-fixture"
    doc["catalog"] = "core"
    doc["verdicts"] = [{"check_id": c, "verdict": "FAIL", "evidence": "fixture"}
                       for c in fails.split(",") if fails != "-"]
    with open(os.path.join(gw, stem + ".json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(doc, indent=2) + "\n")
    # graph-legacy  the same corpus's placeable legacy verdicts alone: the unscoped EXAMINED NOTHING path.
    if sid == "-" and stem != "planning-20260719T0300-arch.verdict":
        lw = os.path.join(root, "graph-legacy", "_bmad-output", "gate-adjudication")
        os.makedirs(lw, exist_ok=True)
        with open(os.path.join(lw, stem + ".json"), "w", encoding="utf-8") as fh:
            fh.write(json.dumps(doc, indent=2) + "\n")


def sv(case, ts, sid, check7="PASS", gen=None, drop_gen=False):
    # One implementation verdict at nonce implementation-<ts>; sid None writes no gate_series_id.
    d = os.path.join(root, case, "_bmad-output", "gate-adjudication")
    os.makedirs(d, exist_ok=True)
    nonce = "implementation-" + ts
    doc = {"schema_id": "GATE_ADJUDICATION_VERDICT v1", "gate_type": "implementation"}
    if sid:
        doc["gate_series_id"] = sid
    doc["gate_nonce"] = nonce
    if not drop_gen:
        doc["generated_at"] = gen or "%s-%s-%sT%s:%s:%sZ" % (ts[0:4], ts[4:6], ts[6:8], ts[9:11], ts[11:13], ts[13:15])
    doc["adjudicator_agent_id"] = "gate-adjudicator-fixture"
    doc["catalog"] = "core"
    doc["verdicts"] = [{"check_id": "7", "verdict": check7, "evidence": "fixture"}]
    with open(os.path.join(d, nonce + ".verdict.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(doc, indent=2) + "\n")


def unplaceable(case, nonce, gen):
    # A legacy planning verdict whose nonce fails the pattern, in the shape of the real -arch file.
    d = os.path.join(root, case, "_bmad-output", "gate-adjudication")
    os.makedirs(d, exist_ok=True)
    doc = {"schema_id": "GATE_ADJUDICATION_VERDICT v1", "gate_type": "planning", "gate_nonce": nonce}
    if gen is not None:
        doc["generated_at"] = gen
    doc.update({"adjudicator_agent_id": "gate-adjudicator-fixture", "catalog": "core",
                "verdicts": [{"check_id": "7", "verdict": "PASS", "evidence": "fixture"}]})
    with open(os.path.join(d, nonce + ".verdict.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(doc, indent=2) + "\n")


S322 = "implementation-s322-20261109T010000Z"
# s322-one          ONE conforming s322 pass.
sv("s322-one", "20261109T010000Z", S322)
# s322-legacy-after the same pass, plus a legacy verdict (no id) one hour LATER: a stripped live pass.
sv("s322-legacy-after", "20261109T010000Z", S322)
sv("s322-legacy-after", "20261109T020000Z", None)
# s322-stripped     a 3-pass FAIL series of check 7 whose FIRST pass lost its id. Its nonce sorts before
#                   the series' own remaining passes but after every earlier sprint's series.
for i, ts in enumerate(("20261109T010000Z", "20261109T020000Z", "20261109T030000Z")):
    sv("s322-stripped", ts, None if i == 0 else S322, "FAIL")
# s322-nosprint     3 FAIL passes under an id carrying no -s<N>- at all.
for ts in ("20261109T010000Z", "20261109T020000Z", "20261109T030000Z"):
    sv("s322-nosprint", ts, "implementation-20261109T010000Z", "FAIL")
# s322-reset        a reset INSIDE sprint 322: two -s322- ids, two FAILs each, neither reaching K.
for i, ts in enumerate(("20261109T010000Z", "20261109T020000Z", "20261109T030000Z", "20261109T040000Z")):
    sv("s322-reset", ts, S322 if i < 2 else "implementation-s322-reset-20261109T030000Z", "FAIL")
# unplaceable-recent  an -arch-shaped legacy nonce written AFTER every series began.
unplaceable("unplaceable-recent", "planning-20261109T0100-arch", "2026-11-09T01:00:00Z")
# unplaceable-undated the same shape with generated_at missing, and with it unparseable.
unplaceable("unplaceable-undated", "planning-20261109T0100-arch", None)
unplaceable("unplaceable-undated", "planning-20261109T0200-arch", "yesterday")
PY

printf '%s\n' "$ROOT"
