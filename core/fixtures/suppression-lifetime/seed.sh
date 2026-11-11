#!/usr/bin/env bash
# suppression-lifetime/seed.sh — cases for the suppression lifetime arm.
#
# THE METRICS FILE IS SEEDED IN BOTH JSON SPACINGS ON PURPOSE. The reference
# consumer's real gate-metrics.jsonl carries 337 rows written `"check":"1"` and 386
# written `"check": "1"` — the two spellings track which lead session wrote them. A
# validator anchored to one spacing reads 47% of the corpus and reports clean over the
# rest. Every case file here mixes both so an assertion cannot pass by reading only the
# convenient half.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-suppression-lifetime.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-suppression-lifetime.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-suppression-lifetime.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-suppression-lifetime.sh"
else
  echo "FIXTURE ERROR: validate-suppression-lifetime.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/supp-lifetime.XXXXXX")" || exit 2
mkdir -p "$WORK/cases"

# ---- the catalog -----------------------------------------------------------
MAP="$WORK/enforcement-map.yaml"
cat > "$MAP" <<'YAML'
checks:
  - id: 2
    title: no-unresolved-hard-blocks
    enforcer: []
    adjudication: llm
  - id: 16
    title: gate-dormancy
    enforcer: []
    adjudication: script
  - id: 32
    title: bmad-invocation-resolves
    enforcer: []
    adjudication: script
  - id: 33
    title: single-catalog-control
    enforcer: []
    adjudication: script
  - id: H1
    title: harness-meta-check
    enforcer: []
    adjudication: lead
YAML

# ---- gate metrics ----------------------------------------------------------
# G1 < G2 < G3, all after the authorization timestamp A0 used by the entries below.
# Rows alternate spacing deliberately: odd rows unspaced, even rows spaced.
G1="2026-05-01T01:00:00Z"
G2="2026-05-02T01:00:00Z"
G3="2026-05-03T01:00:00Z"

emit_unspaced() { # <ts> <check> <verdict>
  printf '{"v":1,"sprint":400,"gate":"planning","phase":"a→b","ts":"%s","sha":"deadbeef","catalog":"core","check":"%s","title":"t","verdict":"%s","defect_class":null,"evidence":"e","tok_slice":1}\n' "$1" "$2" "$3"
}
emit_spaced() {   # <ts> <check> <verdict>  — the majority form in the real corpus
  printf '{"v": 1, "sprint": 400, "gate": "planning", "phase": "a→b", "ts": "%s", "sha": "deadbeef", "catalog": "core", "check": "%s", "title": "t", "verdict": "%s", "defect_class": null, "evidence": "e", "tok_slice": 1}\n' "$1" "$2" "$3"
}

# still-failing: check 32 FAILs at every gate. Check 32's rows use the SPACED form only,
# so an extractor that reads just the unspaced half cannot see this check at all.
GM_FAILING="$WORK/gm-failing.jsonl"
{
  emit_unspaced "$G1" "16" "PASS"; emit_spaced "$G1" "32" "FAIL"
  emit_unspaced "$G2" "16" "PASS"; emit_spaced "$G2" "32" "FAIL"
  emit_unspaced "$G3" "16" "PASS"; emit_spaced "$G3" "32" "FAIL"
  emit_spaced   "$G1" "H1" "PASS"; emit_unspaced "$G2" "H1" "PASS"
} > "$GM_FAILING"

# fixed: check 32 FAILs at G1/G2 then PASSes at G3 — the "cause was fixed" case.
GM_FIXED="$WORK/gm-fixed.jsonl"
{
  emit_unspaced "$G1" "16" "PASS"; emit_spaced "$G1" "32" "FAIL"
  emit_unspaced "$G2" "16" "PASS"; emit_spaced "$G2" "32" "FAIL"
  emit_unspaced "$G3" "16" "PASS"; emit_spaced "$G3" "32" "PASS"
} > "$GM_FIXED"

# unparseable — exists but carries no readable ts/check/verdict at all.
GM_BROKEN="$WORK/gm-broken.jsonl"
printf 'not json at all\n{oops\n' > "$GM_BROKEN"

# ---- THE CATALOG-COLLISION TIMELINE ----------------------------------------
# One check NUMBER carrying rows under two catalogs, which is the shape the real corpus
# has: 34 of 71 ids on the reference consumer carry more than one catalog, and 11 of the
# ids in THIS catalog are among them. The core row is OLDER and FAILING; the extension row
# is NEWER and PASSING, so a reader keyed on the number alone answers PASS for `[core] 32`
# and acquits a suppression whose check is still red — the fail-open direction.
#
# Check 33 is the DISCRIMINATION CONTROL and carries exactly one catalog. Every arm below
# runs against it too: if a "fix" moves 33 as well, it is not joining, it is just refusing.
emit_cat() {   # <ts> <catalog> <check> <verdict>
  printf '{"v": 1, "sprint": 400, "gate": "planning", "phase": "a→b", "ts": "%s", "sha": "deadbeef", "catalog": "%s", "check": "%s", "title": "t", "verdict": "%s", "defect_class": null, "evidence": "e", "tok_slice": 1}\n' "$1" "$2" "$3" "$4"
}
GM_COLLIDE="$WORK/gm-collide.jsonl"
{
  emit_cat "$G1" "core"             "32" "FAIL"
  emit_cat "$G2" "core"             "32" "FAIL"
  emit_cat "$G3" "extension:probe"  "32" "PASS"
  emit_cat "$G1" "core"             "33" "FAIL"
  emit_cat "$G2" "core"             "33" "FAIL"
  emit_cat "$G3" "core"             "33" "FAIL"
} > "$GM_COLLIDE"

# The mirror: the SUPPRESSED entry names the EXTENSION check, which is the one still
# failing, while core's newest row PASSES. A fix that hard-codes `core` instead of reading
# the entry's own bracket passes every arm drawn from the corpus above and fails here —
# and it is the only input that separates the two, because on the reference consumer all
# 18 live suppressions are `[core]`.
GM_COLLIDE_EXT="$WORK/gm-collide-ext.jsonl"
{
  emit_cat "$G1" "extension:probe"  "32" "FAIL"
  emit_cat "$G2" "extension:probe"  "32" "FAIL"
  emit_cat "$G3" "core"             "32" "PASS"
  emit_cat "$G1" "core"             "33" "FAIL"
  emit_cat "$G2" "core"             "33" "FAIL"
  emit_cat "$G3" "core"             "33" "FAIL"
} > "$GM_COLLIDE_EXT"

A0="2026-04-30T00:00:00Z"   # authorization, before every gate above

mkcase() { mkdir -p "$WORK/cases/$1"; printf '%s' "$WORK/cases/$1/pending.md"; }

# --- 1. well-formed SUPPRESSED, still inside its lifetime -------------------
f="$(mkcase in-force)"
cat > "$f" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 3 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

Body text mentioning Check 32 in prose.
EOF

# --- 2. well-formed SUPPRESSED, PAST its lifetime, check still failing ------
f="$(mkcase expired-still-failing)"
cat > "$f" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 3. PAST its lifetime, but the cause was FIXED --------------------------
f="$(mkcase expired-but-fixed)"
cat > "$f" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 4. malformed: no **Suppresses:** --------------------------------------
# THE DELIMITER REGRESSION. This entry's Suppresses field is EMPTY while later fields
# are populated. If the record delimiter is IFS whitespace, `read` collapses the empty
# field, every later field shifts left, and this reads as a well-formed entry naming
# nothing — malformed input scoring as clean.
f="$(mkcase malformed-no-target)"
cat > "$f" <<EOF
## [S400 gate — no target named] [lead] - ${A0}
**Status:** SUPPRESSED
**Expires after:** 2 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 5. malformed: expiry out of the permitted 1..3 -------------------------
f="$(mkcase expiry-out-of-range)"
cat > "$f" <<EOF
## [S400 gate — forever] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 99 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 6. suppresses an id that is not in the catalog (the "Check 924" class) --
f="$(mkcase unknown-check-id)"
cat > "$f" <<EOF
## [S400 gate — third leg] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 924 — a token that is not a check
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 7. RESOLVED closing an entry that names a still-failing check ----------
f="$(mkcase terminal-names-failing)"
cat > "$f" <<EOF
## [S400] [Lead] - ${A0} — gate BLOCKED
**Status:** RESOLVED
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

The gate blocked on Check 32 and the operator waved it through.
EOF

# --- 8. RESOLVED naming only a PASSING check — must not fire ---------------
f="$(mkcase terminal-names-passing)"
cat > "$f" <<EOF
## [S400] [Lead] - ${A0} — gate note
**Status:** RESOLVED
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

Check 16 was discussed and is green.
EOF

# --- 9. nothing in scope at all --------------------------------------------
f="$(mkcase empty)"
cat > "$f" <<EOF
## [S400] [Lead] - ${A0} — informational
**Status:** DECIDED_AUTONOMOUSLY

No check named here.
EOF

# --- 9b. EMPTY, BLANK, HEADING-ONLY and a LEVEL-4 entry ---------------------
# The first two hold no non-whitespace byte and are the ABSENT state. The other two are
# POPULATED and parse to zero records (entries_scanned=0): the parser flushes only on a
# level-2/3 heading, so a `#### ` entry carrying `**Suppresses:**` is invisible to it. That is
# a grammar gap, not an empty file, and must never be reported as one.
f="$(mkcase empty-file)"; : > "$f"
f="$(mkcase blank-file)"; printf '\n \n' > "$f"
f="$(mkcase heading-only)"; printf '# Pending Escalations\nNo escalation has been filed this sprint.\n' > "$f"
f="$(mkcase level4-entry)"
cat > "$f" <<EOF
# Pending Escalations

#### [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 10. a suppression declared by its FIELDS but classified as something else ---
# The reproduced defect. `**Status:**` is read as the first [A-Z_] run after the label,
# so this line classifies as DECIDED_AUTONOMOUSLY, the `case` has no branch for it, and
# the three fields below are never read. The tool's `suppressed=` figure is identical
# whether this entry exists or not.
f="$(mkcase attempt-first-token)"
cat > "$f" <<EOF
## [S400 gate — dispatch guard] [lead] - ${A0}
**Status:** DECIDED_AUTONOMOUSLY (root cause), with a SUPPRESSED marker on Check 32 below.
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 2 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 11. NEAR-MISS: the word SUPPRESSED on the status line, no suppression fields ---
# Separates the arm from the rule that was measured and rejected. Flagging a second
# vocabulary token anywhere on the status line scores 5 of 108 lines on the reference
# consumer and all five are negations of this exact shape. This entry must stay SILENT.
f="$(mkcase attempt-word-only)"
cat > "$f" <<EOF
## [S400 gate — a finding, not a disposition] [lead] - ${A0}
**Status:** DECIDED_AUTONOMOUSLY (Rule 12 Tier 2) — not a HARD_BLOCK and not a SUPPRESSED entry.

Body text mentioning Check 16 in prose.
EOF

# --- 12. NEAR-MISS: the same fields under a status that DOES classify SUPPRESSED ---
# The corrected form of case 10. Same fields, same target, same citation; only the
# status token differs. If this fires, the arm is keyed on the fields alone and every
# legitimate suppression in the corpus trips it.
f="$(mkcase attempt-corrected)"
cat > "$f" <<EOF
## [S400 gate — dispatch guard] [lead] - ${A0}
**Status:** SUPPRESSED (operator, ${A0})
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 3 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 13. the same discard reached through a TERMINAL branch ----------------------
# RESOLVED has its own `case` branch, so an arm written as the case's `else` would never
# see this entry. Its suppression fields are discarded exactly as case 10's are.
# --- catalog collision: the entry names [core], expired, core still FAILING ---
f="$(mkcase collide-core)"
cat > "$f" <<EOF
## [S400 gate — catalog collision] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- the same entry with NO bracket. A bare id resolves as core, matching the sibling's
#     `cat or "core"`, so this must behave EXACTLY like collide-core above.
f="$(mkcase collide-bare)"
cat > "$f" <<EOF
## [S400 gate — catalog collision, bare id] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- the mirror: the entry names the EXTENSION catalog ---------------------
f="$(mkcase collide-ext)"
cat > "$f" <<EOF
## [S400 gate — catalog collision, extension] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [extension:probe] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- the discrimination control: a single-catalog check, expired, still FAILING.
#     Fires in EVERY world. An arm that stops firing here is refusing, not joining.
f="$(mkcase collide-control)"
cat > "$f" <<EOF
## [S400 gate — single-catalog control] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 33 — single-catalog-control
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

f="$(mkcase attempt-under-terminal)"
cat > "$f" <<EOF
## [S400 gate — closed out] [lead] - ${A0}
**Status:** RESOLVED (the SUPPRESSED marker below carries the authorization)
**Suppresses:** [core] 16 — gate-dormancy
**Expires after:** 2 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# ---- THE WAIVED VERDICT: FAIL_WAIVED rows carrying a waiver_id ---------------
# The shape the producer writes: Check 12 copies `verdict` and `waiver_id` from the adopted
# adjudication verdict into each GATE_METRIC row. The id is the waiving entry's header after
# `## ` (rules.waiver_id), so it carries the em dash and brackets real headers carry. Every
# timeline is three gates after A0 with check 32 FAIL_WAIVED at each, in alternating spacings,
# and the LATEST row's spacing differs between the two timelines most arms read, so neither
# spacing alone can carry the suite.
emit_w_unspaced() { # <ts> <check> <waiver_id>
  printf '{"v":1,"sprint":400,"gate":"planning","phase":"a→b","ts":"%s","sha":"deadbeef","catalog":"core","check":"%s","title":"t","verdict":"FAIL_WAIVED","waiver_id":"%s","defect_class":null,"evidence":"e","tok_slice":1}\n' "$1" "$2" "$3"
}
emit_w_spaced() {   # <ts> <check> <waiver_id>
  printf '{"v": 1, "sprint": 400, "gate": "planning", "phase": "a→b", "ts": "%s", "sha": "deadbeef", "catalog": "core", "check": "%s", "title": "t", "verdict": "FAIL_WAIVED", "waiver_id": "%s", "defect_class": null, "evidence": "e", "tok_slice": 1}\n' "$1" "$2" "$3"
}
gm_waived() { # <file> <waiver_id> <latest-spacing: spaced|unspaced>
  {
    emit_unspaced "$G1" "16" "PASS"; emit_w_spaced "$G1" "32" "$2"
    emit_spaced   "$G2" "16" "PASS"; emit_w_unspaced "$G2" "32" "$2"
    emit_unspaced "$G3" "16" "PASS"
    if [ "$3" = "spaced" ]; then emit_w_spaced "$G3" "32" "$2"; else emit_w_unspaced "$G3" "32" "$2"; fi
  } > "$1"
}
W_OVR="[S400 gate — the operator waived Check 32] [lead] - ${A0}"
W_SUP1="[S400 gate — a one-gate waiver of Check 32] [lead] - ${A0}"
W_SUP3="[S400 gate — a three-gate waiver of Check 32] [lead] - ${A0}"
W_OTHER="[S400 gate — a different entry] [lead] - ${A0}"
W_DEC="[S400 gate — decided by the lead] [lead] - ${A0}"
W_ARCH="[S399 gate — archived at retro] [lead] - 2026-04-01T00:00:00Z"
GM_W_OVR="$WORK/gm-waived-ovr.jsonl";     gm_waived "$GM_W_OVR" "$W_OVR" spaced
GM_W_OTHER="$WORK/gm-waived-other.jsonl"; gm_waived "$GM_W_OTHER" "$W_OTHER" unspaced
GM_W_SUP1="$WORK/gm-waived-sup1.jsonl";   gm_waived "$GM_W_SUP1" "$W_SUP1" unspaced
GM_W_SUP3="$WORK/gm-waived-sup3.jsonl";   gm_waived "$GM_W_SUP3" "$W_SUP3" spaced
GM_W_NONE="$WORK/gm-waived-none.jsonl";   gm_waived "$GM_W_NONE" "[S400 gate — no such entry] [lead] - ${A0}" spaced
GM_W_DEC="$WORK/gm-waived-dec.jsonl";     gm_waived "$GM_W_DEC" "$W_DEC" unspaced
GM_W_ARCH="$WORK/gm-waived-arch.jsonl";   gm_waived "$GM_W_ARCH" "$W_ARCH" spaced
GM_W_EMPTY="$WORK/gm-waived-emptyid.jsonl"; gm_waived "$GM_W_EMPTY" "" unspaced

# W-match: the OVERRIDDEN entry IS the waiver the rows name, trailing whitespace on its header.
f="$(mkcase waiver-match)"
printf '## %s  \n**Status:** OVERRIDDEN\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\nThe gate failed Check 32 and the operator waived it.\n' "$W_OVR" "$A0" > "$f"
# W-other: a RESOLVED entry naming Check 32, while the rows name a DIFFERENT, OVERRIDDEN entry.
f="$(mkcase waiver-other-entry)"
cat > "$f" <<EOF
## ${W_OTHER}
**Status:** OVERRIDDEN
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

An unrelated disposition.

## [S400] [Lead] - ${A0} — gate BLOCKED
**Status:** RESOLVED
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

The gate blocked on Check 32 and the operator waved it through.
EOF
# W-sup1 / W-sup3: SUPPRESSED waivers of 32, one gate and three gates, over three gates.
f="$(mkcase waiver-suppressed-expired)"
printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** [core] 32 — bmad-invocation-resolves\n**Expires after:** 1 gates\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n' "$W_SUP1" "$A0" > "$f"
f="$(mkcase waiver-suppressed-inforce)"
printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** [core] 32 — bmad-invocation-resolves\n**Expires after:** 3 gates\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n' "$W_SUP3" "$A0" > "$f"
# W-dec: the id resolves, to an entry that is neither OVERRIDDEN nor SUPPRESSED.
f="$(mkcase waiver-wrong-status)"
printf '## %s\n**Status:** DECIDED_AUTONOMOUSLY\n\nNo operator was asked.\n' "$W_DEC" > "$f"
# W-arch: the id is absent from pending.md and present in the archive beside it.
f="$(mkcase waiver-archived)"
printf '## %s\n**Status:** DECIDED_AUTONOMOUSLY\n\nUnrelated.\n' "$W_DEC" > "$f"
printf '# Escalation archive\n\n## %s\n**Status:** OVERRIDDEN\n**Operator authorization:** 2026-04-01T00:00:00Z | "Override, proceed, file backlog item"\n' "$W_ARCH" \
  > "$WORK/cases/waiver-archived/pending-archive.md"

# ---- WHOSE WAIVER IS IT (C1, C2) --------------------------------------------
# Every timeline below names ONE waiver id, W_C2W, whose header names no check, so the only entry
# a terminal message can be about is the one the case names Check 32 in. The cases give that id a
# different entry, status or home each time.
W_C2W="[S400 gate — the operator waiver for the spawn rows] [lead] - ${A0}"
GM_W_C2="$WORK/gm-waived-c2.jsonl"; gm_waived "$GM_W_C2" "$W_C2W" unspaced
# The own-entry stand-down subject: a RESOLVED entry whose own header is the row id, written with
# a TRAILING BLANK in the row, so only a stripped compare joins them. RESOLVED, so no OVERRIDDEN
# resolution can stand it down instead.
W_SD="[S400 gate — closed by its own waiver] [lead] - ${A0}"
GM_W_SD="$WORK/gm-waived-sd.jsonl"; gm_waived "$GM_W_SD" "$W_SD " spaced
c2_ovr()  { printf '## %s\n**Status:** OVERRIDDEN\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\nThe spawn rows were waived; output verified.\n\n' "$W_C2W" "$A0"; }
c2_res()  { printf '## %s\n**Status:** RESOLVED\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\nClosed as answered.\n\n' "$W_C2W" "$A0"; }
c2_sup()  { printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** [core] %s — target\n**Expires after:** %s gates\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\n' "$W_C2W" "$1" "${2:-3}" "$A0"; }
c2_name() { printf '## [S400 gate — a second override] [lead] - %s\n**Status:** OVERRIDDEN\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\nCheck 32 failed again on another spawn row; output verified.\n\n' "$A0" "$A0"; }
c1_exp()  { printf '## [S305 gate — an old suppression] [lead] - %s\n**Status:** SUPPRESSED\n**Suppresses:** [core] 32 — bmad-invocation-resolves\n**Expires after:** 1 gates\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\n' "$A0" "$A0"; }
# C1: an expired suppression of 32 while 32 is FAIL_WAIVED under ANOTHER entry (resolving, or not).
f="$(mkcase c1-other-waiver)";  { c1_exp; c2_ovr; } > "$f"
f="$(mkcase c1-unresolvable)";  c1_exp > "$f"
printf 'EXPIRED:32\n' > "$WORK/baseline-expired32.txt"
# C2: a second OVERRIDDEN entry naming 32, its waiver above and below it, archived, a SUPPRESSED
# waiver of 32; then the waivers that must NOT stand it down.
f="$(mkcase c2-waiver-above)";  { c2_ovr; c2_name; } > "$f"
f="$(mkcase c2-waiver-below)";  { c2_name; c2_ovr; } > "$f"
f="$(mkcase c2-archived)";      c2_name > "$f"
{ printf '# Escalation archive\n\n'; c2_ovr; } > "$WORK/cases/c2-archived/pending-archive.md"
f="$(mkcase c2-suppressed-32)"; { c2_name; c2_sup 32; } > "$f"
f="$(mkcase c2-unresolvable)";  c2_name > "$f"
# N5: the row's waiver is an ARCHIVED SUPPRESSED entry targeting [core] 32 whose own one-gate lifetime
# has run out (three gates recorded since its authorization). An expired suppression acquits nothing.
f="$(mkcase c2-archived-expired)"; c2_name > "$f"
{ printf '# Escalation archive\n\n'; c2_sup 32 1; } > "$WORK/cases/c2-archived-expired/pending-archive.md"
# The archived SUPPRESSED waiver of 32 STILL INSIDE its three-gate lifetime (three gates recorded,
# not past three): the case the ruling says acquits. Separates the lifetime clause from a source
# test (live file only), which every other C2 world agrees with.
f="$(mkcase c2-archived-inforce)"; c2_name > "$f"
{ printf '# Escalation archive\n\n'; c2_sup 32 3; } > "$WORK/cases/c2-archived-inforce/pending-archive.md"
# The archived SUPPRESSED waiver of 32 whose lifetime CANNOT BE READ: no **Expires after:** line in
# one, no authorization timestamp in the other. Unreadable is expired, so both fire; without the
# fail-closed guard the lifetime test errors and the waiver acquits.
f="$(mkcase c2-archived-noexpiry)"; c2_name > "$f"
{ printf '# Escalation archive\n\n'; c2_sup 32 3 | grep -v '^\*\*Expires after:\*\*'; } > "$WORK/cases/c2-archived-noexpiry/pending-archive.md"
f="$(mkcase c2-archived-nots)"; c2_name > "$f"
{ printf '# Escalation archive\n\n'; c2_sup 32 3 | sed 's/^\*\*Operator authorization:\*\* [^ ]* |/**Operator authorization:** at the gate |/'; } > "$WORK/cases/c2-archived-nots/pending-archive.md"
f="$(mkcase c2-resolved)";      { c2_name; c2_res; } > "$f"
f="$(mkcase c2-mistargeted)";   { c2_name; c2_sup 16; } > "$f"
f="$(mkcase own-standdown)"
printf '## %s\n**Status:** RESOLVED\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\nThe gate failed Check 32 and this entry waived it.\n' "$W_SD" "$A0" > "$f"

# ---- SUPERSESSION (BL-959): a fresh in-force authorization stands an expired one down ----------
# THE SHORT TIMELINE. Two gates (G1, G2) after both authorizations: OLD (`**Expires after:** 1`,
# authorized A0) is past its lifetime at 2 elapsed, NEW (`**Expires after:** 3`, authorized A1) is in
# force at 2. So every near-miss below is excluded by the condition it names, never by NEW's own
# lifetime, and --in-force LISTS NEW in each world where that condition is not the lifetime (arm
# inf). NEW's authorization timestamp is A1, never the shared A0: condition f (the timestamps
# differ) would otherwise silently exclude NEW from every world.
A1="2026-04-30T12:00:00Z"
SL_OLD="[S401 gate — an expired bmad suppression] [lead] - ${A0}"
SL_NEW="[S401 gate — a fresh bmad suppression] [lead] - ${A1}"
SL_OVR="[S401 gate — spawn rows overridden] [lead] - ${A1}"
SL_Q_OLD='"Override, proceed, file backlog item"'
SL_Q_NEW='"Re-suppress 32 for three gates"'
# The latest row is the PREVIOUS gate's and is waived by OLD (the consumer's shape), or plain FAIL.
GM_SL_W="$WORK/gm-sl-waived-old.jsonl"
{
  emit_unspaced "$G1" "16" "PASS"; emit_spaced "$G1" "32" "FAIL"
  emit_spaced   "$G2" "16" "PASS"; emit_w_unspaced "$G2" "32" "$SL_OLD"
} > "$GM_SL_W"
GM_SL_F="$WORK/gm-sl-fail.jsonl"
{
  emit_unspaced "$G1" "16" "PASS"; emit_w_spaced "$G1" "32" "$SL_OLD"
  emit_spaced   "$G2" "16" "PASS"; emit_unspaced "$G2" "32" "FAIL"
} > "$GM_SL_F"
sl_old() { # [<suppresses> [<expires>]]
  printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** %s — bmad-invocation-resolves\n**Expires after:** %s gates\n**Operator authorization:** %s | %s\n\n' \
    "$SL_OLD" "${1:-[core] 32}" "${2:-1}" "$A0" "$SL_Q_OLD"
}
sl_new() { # [<suppresses> [<expires> [<auth ts> [<quote> [<header>]]]]]
  printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** %s — bmad-invocation-resolves\n**Expires after:** %s gates\n**Operator authorization:** %s | %s\n\n' \
    "${5:-$SL_NEW}" "${1:-[core] 32}" "${2:-3}" "${3:-$A1}" "${4:-$SL_Q_NEW}"
}
sl_ovr() { printf '## %s\n**Status:** OVERRIDDEN\n**Operator authorization:** %s | %s\n\nCheck 32 failed on a spawn row; output verified.\n\n' "$SL_OVR" "$A1" "$SL_Q_NEW"; }
sl_res() { printf '## %s\n**Status:** RESOLVED\n**Operator authorization:** %s | %s\n\nCheck 32 failed on a spawn row; closed as answered.\n\n' "$SL_OVR" "$A1" "$SL_Q_NEW"; }
f="$(mkcase sl-t1)";   { sl_old; sl_new; } > "$f"
f="$(mkcase sl-t9)";   sl_old > "$f"
# T2 (a): NEW only in the archive beside pending.md.
f="$(mkcase sl-t2)";   sl_old > "$f"
{ printf '# Escalation archive\n\n'; sl_new; } > "$WORK/cases/sl-t2/pending-archive.md"
# T3 (b): NEW is OVERRIDDEN and carries no suppression fields, under NEW's own header.
f="$(mkcase sl-t3)";   { sl_old; printf '## %s\n**Status:** OVERRIDDEN\n**Operator authorization:** %s | %s\n\nRe-authorized.\n\n' "$SL_NEW" "$A1" "$SL_Q_NEW"; } > "$f"
# T3b (b): NEW carries every suppression field, in force by them, under OVERRIDDEN. T3's NEW has no
# lifetime, so (d) alone already excludes it; only this world separates the status test.
f="$(mkcase sl-t3b)";  { sl_old; sl_new | sed 's/^\*\*Status:\*\* SUPPRESSED$/**Status:** OVERRIDDEN/'; } > "$f"
# T4 (c1): NEW suppresses a different check. T5 (c2): NEW names the extension catalog.
f="$(mkcase sl-t4)";   { sl_old; sl_new '[core] 16'; } > "$f"
f="$(mkcase sl-t5)";   { sl_old; sl_new '[extension:probe] 32'; } > "$f"
# T5's converse twins: an EMPTY bracket reads as core on either side, so both MUST stand down.
f="$(mkcase sl-t5e)";  { sl_old '32'; sl_new; } > "$f"
f="$(mkcase sl-t5s)";  { sl_old; sl_new '32'; } > "$f"
# T6 (d): NEW's lifetime is unreadable -- out of range, no ISO timestamp, no **Expires after:**.
f="$(mkcase sl-t6)";   { sl_old; sl_new '[core] 32' 5; } > "$f"
f="$(mkcase sl-t6b)";  { sl_old; sl_new '[core] 32' 3 'at the gate'; } > "$f"
f="$(mkcase sl-t6c)";  { sl_old; sl_new | grep -v '^\*\*Expires after:\*\*'; } > "$f"
# T7 (e): NEW itself past its lifetime (1 gate, 2 elapsed).
f="$(mkcase sl-t7)";   { sl_old; sl_new '[core] 32' 1; } > "$f"
# T8 (f): the TIMESTAMP is the operator turn. T8a: OLD's timestamp, a new quote. T8b: a new
# timestamp, OLD's quote.
f="$(mkcase sl-t8a)";  { sl_old; sl_new '[core] 32' 3 "$A0"; } > "$f"
f="$(mkcase sl-t8b)";  { sl_old; sl_new '[core] 32' 3 "$A1" "$SL_Q_OLD"; } > "$f"
# F3: a second entry under OLD's OWN header (OLD's waiver key), fresh timestamp, 3 gates. An entry
# sharing E's key IS E, so it supersedes nothing.
f="$(mkcase sl-f3)";   { sl_old; sl_new '[core] 32' 3 "$A1" "$SL_Q_NEW" "$SL_OLD"; } > "$f"
# T11 (the terminal twin): an OVERRIDDEN entry naming Check 32 while 32's latest row is waived by the
# expired OLD. b: OLD archived. c: no NEW. d: RESOLVED, not OVERRIDDEN (exact match only).
f="$(mkcase sl-t11)";  { sl_old; sl_new; sl_ovr; } > "$f"
f="$(mkcase sl-t11b)"; { sl_new; sl_ovr; } > "$f"
{ printf '# Escalation archive\n\n'; sl_old; } > "$WORK/cases/sl-t11b/pending-archive.md"
f="$(mkcase sl-t11c)"; { sl_old; sl_ovr; } > "$f"
f="$(mkcase sl-t11d)"; { sl_old; sl_new; sl_res; } > "$f"
# TQ (the terminal twin's waiver must be the expired suppression of (core, 32)): T11b's tree with the
# archived waiver OLD retargeted. q1: [core] 16, expired. q2: [extension:x] 32, in force. q3: [core] 16,
# in force. q4: [core] 32 with no **Expires after:** -- an unreadable lifetime, which reads as expired,
# so the twin stands down exactly as in T11b.
for q in 'q1|[core] 16|1' 'q2|[extension:x] 32|3' 'q3|[core] 16|3' 'q4|[core] 32|1'; do
  n="${q%%|*}"; r="${q#*|}"
  f="$(mkcase "sl-t$n")"; { sl_new; sl_ovr; } > "$f"
  { printf '# Escalation archive\n\n'
    if [ "$n" = q4 ]; then sl_old | grep -v '^\*\*Expires after:\*\*'; else sl_old "${r%|*}" "${r##*|}"; fi
  } > "$WORK/cases/sl-t$n/pending-archive.md"
done

# ---- THE CWD WORLDS --------------------------------------------------------
# The metrics file is the ONE input this script locates for itself, and it is located while
# the process cwd is whatever the caller happened to be in. `ai-dlc-gate-remediation-guard.sh`
# arm 7b and `validate-gate-adjudication.sh` both invoke it with the project root in the
# environment and no `--gate-metrics`, from a cwd that is a different project as often as not.
# So each world below is a PAIR: a root that carries the timeline the answer must come from,
# and a decoy cwd carrying a DIFFERENT timeline that must not be read. Every case above passes
# `--gate-metrics` explicitly and therefore cannot express this at all.
#
# The catalog is seeded INSIDE each root, at the root-anchored candidate, so a run that never
# received the root refuses instead of falling back to a catalog it found some other way.
sl_gm_series() { # <file> <n-gates> — n distinct gate events after A0, check 32 FAILing
  local f="$1" n="$2" i=1
  mkdir -p "$(dirname "$f")"
  : > "$f"
  while [ "$i" -le "$n" ]; do
    if [ "$((i % 2))" -eq 1 ]; then
      emit_unspaced "2026-05-0${i}T01:00:00Z" "32" "FAIL" >> "$f"
    else
      emit_spaced   "2026-05-0${i}T01:00:00Z" "32" "FAIL" >> "$f"
    fi
    i=$((i + 1))
  done
}

sl_world_root() { # <dir> — a project root: catalog at the root-anchored candidate + pending.md
  mkdir -p "$1/core/skills/ai-dlc"
  cp "$MAP" "$1/core/skills/ai-dlc/enforcement-map.yaml"
  cat > "$1/pending.md" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 3 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF
}

# WORLD A — the root HAS a timeline (2 gates, inside the entry's 3-gate lifetime) and the decoy
# cwd has a longer one (9 gates, past it). The two answers are in force / not in force, so an
# arm reading `in_force` alone discriminates.
SL_CWD_A_ROOT="$WORK/cwd-a/root"
SL_CWD_A_DECOY="$WORK/cwd-a/decoy"
mkdir -p "$SL_CWD_A_ROOT" "$SL_CWD_A_DECOY"
sl_world_root "$SL_CWD_A_ROOT"
sl_gm_series "$SL_CWD_A_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl" 2
sl_gm_series "$SL_CWD_A_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl" 9

# WORLD B — the root has NO timeline at any candidate and the decoy cwd has a SHORT one, which
# would leave the entry in force if the resolver ever fell back to the cwd. This is the world
# that separates the fix from "look at the root first, then the cwd": that wrong fix is
# invisible in world A, where the root answers on the first candidate.
SL_CWD_B_ROOT="$WORK/cwd-b/root"
SL_CWD_B_DECOY="$WORK/cwd-b/decoy"
mkdir -p "$SL_CWD_B_ROOT" "$SL_CWD_B_DECOY"
sl_world_root "$SL_CWD_B_ROOT"
sl_gm_series "$SL_CWD_B_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl" 1

# ---- baseline files --------------------------------------------------------
printf 'TERMINAL:##[S400][Lead]-%s—gateBLOCKED\n' "$A0" > "$WORK/baseline-good.txt"
printf 'TERMINAL:##[S400][Lead]-%s—gateBLOCKED\nEXPIRED:16\n' "$A0" > "$WORK/baseline-stale.txt"

cat > "$WORK/env.sh" <<EOF
VALIDATOR="$VALIDATOR"
WORK="$WORK"
MAP="$MAP"
GM_FAILING="$GM_FAILING"
GM_FIXED="$GM_FIXED"
GM_BROKEN="$GM_BROKEN"
GM_COLLIDE="$GM_COLLIDE"
GM_COLLIDE_EXT="$GM_COLLIDE_EXT"
GM_W_OVR="$GM_W_OVR"
GM_W_OTHER="$GM_W_OTHER"
GM_W_SUP1="$GM_W_SUP1"
GM_W_SUP3="$GM_W_SUP3"
GM_W_NONE="$GM_W_NONE"
GM_W_DEC="$GM_W_DEC"
GM_W_ARCH="$GM_W_ARCH"
GM_W_EMPTY="$GM_W_EMPTY"
GM_W_C2="$GM_W_C2"
GM_W_SD="$GM_W_SD"
BASELINE_EXP32="$WORK/baseline-expired32.txt"
GM_SL_W="$GM_SL_W"
GM_SL_F="$GM_SL_F"
A0="$A0"
A1="$A1"
SL_OLD="$SL_OLD"
SL_NEW="$SL_NEW"
SL_OVR="$SL_OVR"
SL_Q_OLD='$SL_Q_OLD'
SL_Q_NEW='$SL_Q_NEW'
G1="$G1"
G2="$G2"
G3="$G3"
CASES="$WORK/cases"
BASELINE_GOOD="$WORK/baseline-good.txt"
BASELINE_STALE="$WORK/baseline-stale.txt"
SL_CWD_A_ROOT="$SL_CWD_A_ROOT"
SL_CWD_A_DECOY="$SL_CWD_A_DECOY"
SL_CWD_B_ROOT="$SL_CWD_B_ROOT"
SL_CWD_B_DECOY="$SL_CWD_B_DECOY"
EOF

printf '%s\n' "$WORK"
