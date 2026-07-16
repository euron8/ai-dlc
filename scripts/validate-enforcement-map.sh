#!/usr/bin/env bash
#
# validate-enforcement-map.sh
#
# Distribution-only integrity check for core/skills/ai-dlc/enforcement-map.yaml
# — the derived machine index of the gate-validation check catalog and its
# enforcement bindings. Runs upstream (repo-root scripts/, alongside
# audit-machinery-efficacy.js); NOT shipped to consumers via install.sh.
#
# The enforcement-map has no independent authority: it is only ever a VALIDATED
# view of steps/gate-validation.md. This script is what keeps it honest. It
# asserts:
#
#   I1  catalog ⊆ map   — every real CHECK_LOADED anchor in gate-validation.md
#                         has an entry under `checks:` in the map.
#   I2  map ⊆ catalog   — every `checks:` entry corresponds to a real anchor
#                         (catches a stale entry left after a check is removed).
#   I3  gate-type sync  — for every (gate_type, check) pair in the GATE_MANIFEST
#                         block, the map entry's gate_types list contains that
#                         type (the id/gate_type columns cannot drift from the
#                         authoritative manifest).
#   I4  no dormant binding — every enforcer/ci_workflow path the map references
#                         exists on disk; every named fixture exists under
#                         core/fixtures/. (This is the check the v0.27.0
#                         machinery-efficacy audit found missing.)
#   I5  core_manifest sync — core-manifest.md and reconcile/setup-sites.md list
#                         the same logical core file set (prefix-normalized).
#                         Both files flag this hand-synced duplication as a
#                         hazard; this asserts they never silently diverge.
#   I6  heading ⇔ anchor — every check heading is `### <id>.` (never
#                         `### Check <id>.`) and its id set equals the anchor set.
#                         Nothing tied the two together, so v0.48.0's
#                         `### Check 24.` passed I1-I5 while going invisible to
#                         every anchor extractor in the distribution and in the
#                         consumer-shipped layer linter at once.
#   I7  fixture ⇔ manifest — check-manifest-bypass/seed.sh seeds exactly the
#                         universal core + PLANNING row and none of the
#                         IMPLEMENTATION row. Its anchor list is hand-maintained and
#                         had already rotted (the manifest gained check 24, the
#                         fixture did not), so H1's self-test was seeding a slice
#                         that no longer existed.
#   I9  enforcer ⇒ call site — every `adjudication: script` entry declares
#                         `call_sites:` with a posture (W1), and no declared site
#                         is fictional — the file it names must at least know the
#                         enforcer exists (W2). W2 canNOT tell an invocation from a
#                         prose mention; see its inline note. The teeth are W1 plus
#                         the reviewable `posture:`. The map recorded WHO enforces each
#                         rule (38/38) and WHERE it runs (1/38), so "Enforced by
#                         validate-X.sh" was a claim nothing could falsify. That
#                         is how validate-steering-budget.sh came to sit on 11
#                         real starvation violations while invoked from zero
#                         gates, and why implementation.md could say it "fails
#                         the gate" when it ran at no gate at all.
#   I8  fixture packaging — core/fixtures/, install.sh's fixture loop, and
#                         uninstall.sh's fixture loop name the same set. All three
#                         are hardcoded and had drifted (9 on disk, 9 installed, 5
#                         uninstalled). A fixture missing from install.sh reaches no
#                         consumer at all — an adversarial self-test that silently
#                         does not exist, while the catalog claims coverage. Dist-only
#                         fixtures are DERIVED from a `.dist-only` marker beside the
#                         fixture, not a hand-maintained exemption string.
#   I10 fixture hermeticity — a fixture that drives a hook must scrub ambient AI_DLC_*
#                         first, or a consumer's sanctioned tunable makes it fail against
#                         a hook behaving correctly, and the pre-push gate blocks every push.
#   I11 convergence-cycle scope — the three sets that must be one set (steps that dispatch
#                         an adversarial REVIEW, steps that reference the REPAIR dispatch,
#                         and Check 24's Scope sentence) are DERIVED and asserted equal. A
#                         step in the first but not the third runs a convergence loop no
#                         gate reads — which reads exactly like a loop that converged. The
#                         list was hand-maintained and rotted twice (v0.58.0 caught two of
#                         three; carry-over-evaluation was the third).
#   I12 drift-scan coverage bound — reconcile/unregistered-drift.sh's hand-listed scan set is
#                         bound to a reviewed per-subtree policy: every core/skills/<skill>/ and
#                         core/<dir>/ is classified scan|exempt:<reason>, and the scan-marked set
#                         must EQUAL the tool's ls-tree. The list rotted twice (ai-dlc-setup/ in
#                         v0.63.0, schemas/ this release) — a new core dir escaping the scan reads
#                         exactly like a dir with no drift. Now a new subtree fails the build until
#                         it is classified.
#
# Tool dependencies: bash ≥3.2, grep, sed, awk, sort, comm. No hard dep on
# jq/yq/rg — the map is authored line-oriented so the portable subset parses it
# (same posture as validate-ci-gates.sh).
#
# Exit codes:
#   0 — all invariants hold
#   1 — one or more invariants violated (drift / dormant binding)
#   2 — tool-availability or missing-input failure

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GV="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
MAP="$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml"
CORE_MANIFEST="$REPO_ROOT/core/skills/ai-dlc/core-manifest.md"
SETUP_SITES="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md"

for f in "$GV" "$MAP" "$CORE_MANIFEST" "$SETUP_SITES"; do
  if [ ! -f "$f" ]; then
    echo "tool-fail: required input not found: $f" >&2
    exit 2
  fi
done

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

# --- Catalog anchor set -------------------------------------------------------
# Real anchors sit at column 0 directly under a check heading. Inline format
# EXAMPLES in the manifest/H1 prose are mid-line (backtick-prefixed) and carry
# the literal placeholder "<id>" — both are excluded.
anchors="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' "$GV" \
           | sed -E 's/^<!-- CHECK_LOADED: (.+) -->$/\1/' \
           | grep -vF '<id>' | sort -u)"

# --- Map check-id set (under `checks:` only, not `non_catalog_units:`) ---------
map_ids="$(awk '
  /^checks:/ {inck=1; next}
  /^non_catalog_units:/ {inck=0}
  inck && /^  - id:/ { v=$0; sub(/^  - id:[ ]*/,"",v); gsub(/"/,"",v); print v }
' "$MAP" | sort -u)"

# I1 / I2: set equality between anchors and map ids
missing_in_map="$(comm -23 <(printf '%s\n' "$anchors") <(printf '%s\n' "$map_ids"))"
stale_in_map="$(comm -13 <(printf '%s\n' "$anchors") <(printf '%s\n' "$map_ids"))"
[ -n "$missing_in_map" ] && err "catalog check(s) with no enforcement-map entry: $(echo $missing_in_map)"
[ -n "$stale_in_map" ]   && err "enforcement-map entr(y/ies) with no CHECK_LOADED anchor: $(echo $stale_in_map)"

# --- I6: heading form <-> anchor set ------------------------------------------
# NOTHING tied a check's HEADING to its CHECK_LOADED anchor, so the heading could
# drift from the catalog with CI green. Not hypothetical: v0.48.0 shipped
# `### Check 24.` while every other check is `### 24.`, with a correct
# `<!-- CHECK_LOADED: 24 -->` under it. I1-I5 all passed. But every anchor
# extractor — here, in reconcile/layer-drift.sh, in the consumer-shipped
# validate-layer-entries.sh, and in audit-machinery-efficacy.js — keys on
# `^### <n>.`, so check 24 went invisible to all of them at once. That included
# the one check that would have caught the number collision v0.48.0 itself created,
# and the efficacy auditor, which silently folded check 24's token cost into 23.
# A one-character heading deviation disabled four tools. This is the invariant that
# was missing.
#
# Two word-titled checks (Core-layer immutability, the gate-failure protocol) carry
# anchors but are prose-headed by design. They are NAMED, not pattern-matched, so a
# third one has to be added here deliberately rather than slipping in.
WORD_ANCHORS='core-layer-immutability|failure'

bad_form="$(grep -nE '^#{2,4}[[:space:]]+Check[[:space:]]+[0-9]' "$GV")"
[ -n "$bad_form" ] && err "check heading(s) written '### Check <n>.' — the catalog form is '### <n>.'. Every anchor extractor keys on the latter, so this form hides the check from all of them: $(echo $bad_form)"

head_ids="$(grep -oE '^### ([0-9]+[a-z]?|H[0-9]+)\.' "$GV" | sed -E 's/^### //; s/\.$//' | sort -u)"
anchor_ids="$(printf '%s\n' "$anchors" | grep -vE "^($WORD_ANCHORS)$" | sort -u)"
no_anchor="$(comm -23 <(printf '%s\n' "$head_ids") <(printf '%s\n' "$anchor_ids"))"
no_head="$(comm -13 <(printf '%s\n' "$head_ids") <(printf '%s\n' "$anchor_ids"))"
[ -n "$no_anchor" ] && err "check heading(s) with no CHECK_LOADED anchor: $(echo $no_anchor)"
[ -n "$no_head" ]   && err "CHECK_LOADED anchor(s) with no '### <id>.' heading: $(echo $no_head)"

# --- I3: GATE_MANIFEST (gate_type, check) pairs vs map gate_types -------------
# Per-id gate_types csv from the map.
gt_lookup="$(awk '
  /^checks:/ {inck=1; next}
  /^non_catalog_units:/ {inck=0}
  inck && /^  - id:/ {
    if (id != "") print id"\t"gt;
    id=$0; sub(/^  - id:[ ]*/,"",id); gsub(/"/,"",id); gt=""
  }
  inck && /^    gate_types:/ {
    gt=$0; sub(/^    gate_types:[ ]*\[/,"",gt); sub(/\][ ]*$/,"",gt); gsub(/ /,"",gt)
  }
  END { if (id != "") print id"\t"gt }
' "$MAP")"

# Each manifest row: | <type> | <id, id, ...> |. Skip header + separator rows.
while IFS= read -r row; do
  case "$row" in
    *"Gate type"*|*"---"*) continue ;;
  esac
  gtype="$(printf '%s' "$row" | awk -F'|' '{gsub(/ /,"",$2); print $2}')"
  ids="$(printf '%s' "$row" | awk -F'|' '{print $3}')"
  [ -z "$gtype" ] && continue
  # split ids on comma
  oldIFS="$IFS"; IFS=','
  for cid in $ids; do
    cid="$(printf '%s' "$cid" | tr -d ' ')"
    [ -z "$cid" ] && continue
    entry="$(printf '%s\n' "$gt_lookup" | grep -E "^${cid}"$'\t' || true)"
    if [ -z "$entry" ]; then
      err "GATE_MANIFEST names check $cid ($gtype) but the map has no such entry"
    else
      csv="$(printf '%s' "$entry" | cut -f2)"
      case ",$csv," in
        *",$gtype,"*) : ;;
        *) err "map entry $cid omits gate_type '$gtype' that GATE_MANIFEST requires (has: $csv)" ;;
      esac
    fi
  done
  IFS="$oldIFS"
done <<EOF
$(awk '/<!-- GATE_MANIFEST v1 -->/{f=1;next} /<!-- GATE_MANIFEST_END -->/{f=0} f && /^\|/{print}' "$GV")
EOF

# --- I7: check-manifest-bypass fixture vs the manifest it exists to test -------
# The fixture seeds "universal core + the PLANNING row" and then declares gate type
# `implementation`, so H1 must fail on the implementation row's absent anchors.
# Both halves of that sentence are a hand-maintained anchor list inside seed.sh, and
# the planning half had already rotted: the manifest gained check 24 and the fixture
# did not, so the seed no longer seeded what its own prose claimed. A fixture that
# has drifted from the manifest is not a self-test, it is a decoration. Assert both
# directions against the live manifest instead of trusting the copy.
SEED="$REPO_ROOT/core/fixtures/check-manifest-bypass/seed.sh"
if [ -f "$SEED" ]; then
  manifest_row() { # manifest_row <gate-type> -> ids, one per line
    awk -v want="$1" '
      /<!-- GATE_MANIFEST v1 -->/{f=1;next} /<!-- GATE_MANIFEST_END -->/{f=0}
      f && /^\|/ {
        gt=$0; sub(/^\|[ ]*/,"",gt); sub(/[ ]*\|.*$/,"",gt)
        if (gt != want) next
        n=split($0, c, "|"); ids=c[3]; gsub(/ /,"",ids)
        n=split(ids, a, ","); for (i=1;i<=n;i++) if (a[i] != "") print a[i]
      }' "$GV"
  }
  seed_has() { grep -qF "<!-- CHECK_LOADED: $1 -->" "$SEED"; }

  for cid in $(manifest_row planning); do
    seed_has "$cid" || err "check-manifest-bypass/seed.sh seeds the PLANNING slice but omits check $cid, which the GATE_MANIFEST planning row requires — the fixture no longer seeds what it claims, and H1's self-test is testing a slice that does not exist"
  done
  for cid in $(manifest_row implementation); do
    seed_has "$cid" && err "check-manifest-bypass/seed.sh contains check $cid from the IMPLEMENTATION row — the fixture's whole purpose is that those anchors are ABSENT so H1 fails; including one makes the self-test vacuous"
  done
fi

# --- I8: fixture packaging (core/fixtures == install loop == uninstall loop) ---
# The fixture dirs are shipped by a HARDCODED, enumerated loop in install.sh and
# removed by a second hardcoded loop in uninstall.sh. Nothing kept the three in sync,
# and they had already drifted: nine fixtures on disk, nine in install, FIVE in
# uninstall. A fixture missing from install never reaches a consumer at all — it is an
# adversarial self-test that silently does not exist, which is strictly worse than no
# fixture, because the catalog claims it is covered. Glob the truth and compare.
fixture_list() { # fixture_list <script> -> dir names, one per line
  awk '/^for fixture_dir in /{ sub(/^for fixture_dir in /,""); sub(/; do.*$/,""); print }' "$1" \
    | tr ' ' '\n' | grep -E '.' | sort -u
}
on_disk="$(find "$REPO_ROOT/core/fixtures" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -u)"
in_install="$(fixture_list "$REPO_ROOT/scripts/install.sh")"
in_uninstall="$(fixture_list "$REPO_ROOT/scripts/uninstall.sh")"

# DIST-ONLY fixtures. A fixture is shipped so it can RUN on the consumer. One whose
# subject is not shipped cannot run there, and shipping it anyway plants a fixture that
# is permanently dormant on every consumer — the same "the catalog claims it is covered
# and it is not" failure this block exists to prevent, just pointed the other way. Such a
# fixture is named here and is NOT expected in install.sh's loop.
#
# The exemption is not self-certifying: each name below must ALSO be absent from
# install.sh's loop (a stale exemption for a now-shipped fixture would silently excuse it
# from the sync check above).
# DERIVED, not listed. A fixture is dist-only iff it carries a `.dist-only` marker file.
# It was a hand-maintained string here, and three readers had to agree about it: install.sh
# (which omitted it, correctly), map_consumer() (which shipped every core/fixtures/* on every
# pull, and therefore shipped it anyway), and this check. They did not agree, and the
# reference consumer ended up with tests/fixtures/enforcement-map-sites/ and no subject script
# beside it. A list two writers must remember to update is the bug. The marker sits next to
# the fixture it exempts, and every reader derives the same answer from the same file.
DIST_ONLY="$(cd "$REPO_ROOT/core/fixtures" 2>/dev/null && for d in */; do
  [ -f "${d}.dist-only" ] && printf '%s\n' "${d%/}"
done | sort -u)"
for f in $DIST_ONLY; do
  printf '%s\n' "$in_install" | grep -qx "$f" && err "fixture '$f' is listed DIST-ONLY in validate-enforcement-map.sh but install.sh ships it. Either drop the exemption or stop shipping it — as written, it is excused from the install/uninstall sync check for no reason."
  [ -d "$REPO_ROOT/core/fixtures/$f" ] || err "fixture '$f' is listed DIST-ONLY but does not exist in core/fixtures/ — stale exemption."
done

shippable="$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$DIST_ONLY"))"
miss_install="$(comm -23 <(printf '%s\n' "$shippable") <(printf '%s\n' "$in_install"))"
[ -n "$miss_install" ] && err "fixture(s) in core/fixtures/ that install.sh never ships (so no consumer has them): $(echo $miss_install)"
ghost_install="$(comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_install"))"
[ -n "$ghost_install" ] && err "install.sh ships fixture(s) that do not exist in core/fixtures/: $(echo $ghost_install)"
drift_uninstall="$(comm -3 <(printf '%s\n' "$in_install") <(printf '%s\n' "$in_uninstall") | tr -d '\t')"
[ -n "$drift_uninstall" ] && err "install.sh and uninstall.sh fixture loops disagree (uninstall would orphan or over-remove): $(echo $drift_uninstall)"

# --- I10: fixture hermeticity -------------------------------------------------
# A fixture that invokes a hook and INHERITS the operator's ambient config tests the
# CONFIG, not the code. The hooks honour thirteen AI_DLC_* tunables; a consumer that sets
# any one of them in settings.json exports it into every session, `git push` inherits it,
# and the pre-push gate then runs the fixture against a hook configured differently from
# what its assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M — the documented way to declare the
# model row — and SEVEN context-sensor assertions failed against a sensor behaving exactly
# as specified. The gate blocked every push on that repo. The distribution never caught it
# because the distribution sets none of these: THE CHECK COULD NOT FIRE WHERE IT WAS
# AUTHORED, which is the same defect this file has now shipped three fixes for.
#
# So: any fixture that drives a hook must scrub AI_DLC_* first. Asserted, not trusted.
for d in "$REPO_ROOT"/core/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  grep -qE 'hooks/ai-dlc|\$HOOK' "$d/run.sh" || continue          # not a hook fixture
  grep -qE 'unset "\$_v"|env -u AI_DLC' "$d/run.sh" \
    || err "fixture '$(basename "$d")' invokes a hook but never scrubs ambient AI_DLC_* env. A consumer that tunes any of the hooks' AI_DLC_* variables in settings.json will fail this fixture — and its pre-push gate will then block every push — against a hook that is behaving correctly. Scrub the env at the top of run.sh."
done

# --- Fixture root-resolution depth: a seed that hand-resolves the repo root must use the
# SAME `$HERE/../../..` depth for BOTH layouts. A fixture lives at `core/fixtures/<name>/`
# upstream and `tests/fixtures/<name>/` in a consumer (install.sh's map) — BOTH exactly three
# dirs below root. A seed that resolves its consumer branch with `$HERE/../..` (two dirs) lands
# at `tests/` in a consumer, never finds its script/schema, and every seed dies with "not found
# in either layout" → the consumer's pre-push fixture suite FAILS against tooling that is
# correct in the distribution. This bit eight fixtures at once (the distribution takes the
# other branch, so it never exercised the buggy one — the distribution is not a consumer).
# Assert both cd-depths are three, so the next copy-paste cannot re-introduce it.
for d in "$REPO_ROOT"/core/fixtures/*/; do
  s="$d/seed.sh"; [ -f "$s" ] || continue
  while IFS= read -r depth; do
    [ "$depth" = "../../.." ] || err "fixture '$(basename "$d")' seed resolves a repo-root var with depth '\$HERE/$depth' — must be '\$HERE/../../..' (three dirs below root, matching BOTH core/fixtures/<name>/ and tests/fixtures/<name>/). A shallower depth passes in the distribution and fails in every consumer's pre-push."
  done < <(grep -oE '[DC]_ROOT="\$\(cd "\$HERE/(\.\./)*\.\.' "$s" | sed -E 's#.*\$HERE/##')
done

# --- Audit-anchors template is BOUND to its canonical schema. The housekeeping schema used to
# live in two places (this template + each project's live header) with nothing comparing them;
# they drifted (the template went stale, missing `audit_window`). Now the schema is canonical in
# core/schemas/audit-anchors.json, the template's header is RENDERED from it, and the entry
# validator loads it. Assert the shipped template still passes its own validator, so the template
# cannot silently re-stale from the schema.
AA_VALIDATOR="$REPO_ROOT/core/scripts/validate-audit-anchors.sh"
AA_TEMPLATE="$REPO_ROOT/templates/audit-anchors.md.template"
if [ -f "$AA_VALIDATOR" ] && [ -f "$AA_TEMPLATE" ]; then
  bash "$AA_VALIDATOR" "$AA_TEMPLATE" >/dev/null 2>&1 \
    || err "templates/audit-anchors.md.template no longer matches core/schemas/audit-anchors.json (header drift or a malformed bootstrap entry). Re-render its header with 'core/scripts/validate-audit-anchors.sh --render' and fix the entry — the template must never drift from the canonical schema again."
fi

# --- I11: the convergence-cycle scope list is DERIVED, not remembered ---------
# THREE SETS MUST BE ONE SET:
#   (a) steps whose file dispatches an adversarial REVIEW  (they run a convergence cycle)
#   (b) steps whose file references the adversarial REPAIR dispatch (a remediator repairs;
#       the LEAD must not — it is the most context-saturated agent in the pipeline, which is
#       the whole reason the remediator role exists)
#   (c) steps named in Check 24's Scope sentence            (a gate reads the verdict)
#
# A step in (a) but not (c) runs an unbounded convergence loop that NO GATE ADJUDICATES —
# and a loop nobody adjudicates reads exactly like a loop that converged. A step in (a) but
# not (b) has its own author repairing its own artifact, which is the failure the remediator
# was created to end.
#
# This list was hand-maintained and it rotted TWICE. v0.58.0 caught doc-repair-backfill and
# sprint-review-next running unadjudicated cycles and added them to Check 24's scope. The
# same sweep walked straight past carry-over-evaluation, which was running one too — Rule 8
# binds it ("per planning artifact"), its step file never said so, and the reference consumer
# ran a 2-pass cycle there with the lead repairing and no gate reading the verdict. The sweep
# missed it for exactly the reason I8's site table missed core/git-hooks/: the list was
# hand-maintained, so the check had no row for it, and a check that cannot fire reads exactly
# like a check that passed. Derive the list. Never hand-maintain it.
STEPS_DIR="$REPO_ROOT/core/skills/ai-dlc/steps"
if [ -d "$STEPS_DIR" ]; then
  # The python goes to a temp FILE, not a heredoc inside $( ). On bash 3.2 (macOS, the
  # floor this repo targets) a heredoc nested in a command substitution has its body
  # scanned for shell quotes BEFORE the heredoc is processed -- so a lone apostrophe in a
  # python comment ("Check 24's scope") is read as an opening quote and the whole script
  # fails to parse. Top-level heredocs are fine; nested ones are not.
  I11_PY="$(mktemp)"
  cat > "$I11_PY" <<'I11EOF'
import os, re, sys
steps_dir, gv = sys.argv[1], sys.argv[2]

def collapse(p):
    # The procedure names WRAP across lines in the step files (Adversarial review /
    # dispatch). A line-oriented grep misses them, and a check that cannot see the thing
    # it checks reads exactly like a check that passed. Collapse whitespace first.
    return re.sub(r"\s+", " ", open(p, encoding="utf-8").read())

steps = {}
for fn in sorted(os.listdir(steps_dir)):
    if not fn.endswith(".md") or fn.startswith("_"):
        continue
    steps[fn[:-3]] = collapse(os.path.join(steps_dir, fn))

review = set(n for n, t in steps.items() if "Adversarial review dispatch" in t)
repair = set(n for n, t in steps.items() if "Adversarial repair dispatch" in t)

# Check 24 Scope sentence. Only names that are REAL step files count -- the sentence also
# backticks `lightweight`, which is an intensity, not a step.
gvt = open(gv, encoding="utf-8").read()
m = re.search(r"^### 24\.(.*?)^### ", gvt, re.S | re.M)
scope = set()
if m:
    sm = re.search(r"Those steps are:(.*?)\n\n", m.group(1), re.S)
    if sm:
        scope = set(t for t in re.findall(r"`([a-z-]+)`", sm.group(1)) if t in steps)

def emit(names, msg):
    if names:
        sys.stdout.write("ERR\t" + " ".join(sorted(names)) + "\t" + msg + "\n")

emit(review - scope,
     "step(s) run an adversarial convergence cycle but are ABSENT from Check 24 scope -- the loop is adjudicated by nobody, which reads exactly like a loop that converged")
emit(scope - review,
     "Check 24 scope names step(s) that dispatch no adversarial review -- a stale scope entry makes the check self-skip on a gate it claims to cover")
emit(review - repair,
     "step(s) dispatch an adversarial REVIEW but never reference the adversarial REPAIR dispatch -- the lead will repair its own artifact, which is the failure the remediator role exists to end")
I11EOF
  I11_OUT="$(python3 "$I11_PY" "$STEPS_DIR" "$GV")"
  rm -f "$I11_PY"
  while IFS="$(printf '\t')" read -r tag names msg; do
    [ "$tag" = "ERR" ] || continue
    err "$msg: $names"
  done <<EOF
$I11_OUT
EOF
fi

# The THIRD writer. install.sh is not the only thing that puts core/ files into a
# consumer — `reconcile/preclassify.sh`'s map_consumer() does too, on every pull, and
# the two must agree on the destination or the consumer gets two copies at two paths
# and the live one goes stale. They HAD diverged: map_consumer had no `core/fixtures/`
# case, so the `core/*` catch-all filed fixtures under `.claude/fixtures/` while
# install.sh writes `tests/fixtures/` — the only path gate-validation and H1 reference.
# Evaluate the real function rather than trusting a grep of it.
PRECLASS="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"
if [ -f "$PRECLASS" ]; then
  maps_to() { bash -c "CONS=/nonexistent; $(awk '/^map_consumer\(\) \{/,/^\}/' "$PRECLASS"); map_consumer '$1'" 2>/dev/null; }
  # <core dir>|<the destination install.sh writes>. Every core/ subtree the installer
  # ALSO places must be listed, or the catch-all silently invents a second home for it.
  # Three entries here were live bugs: fixtures landed in .claude/fixtures/ (dead, while
  # H1 reads tests/fixtures/), ci-templates in .claude/ci-templates/ (dead, while
  # workflows run from .github/workflows/ — which is why a real consumer's CI gates sat
  # dormant and never once fired), and git-hooks in .claude/git-hooks/ (dead, while
  # install.sh writes .githooks/ — so v0.53.0's pre-push gate, the CI replacement, reached
  # the reference consumer at a path no runner, no git config, and no script reads).
  #
  # THE TABLE IS NOW BOUND AT BOTH ENDS, AND THAT IS THE POINT. Listing sites by hand is
  # what let git-hooks through: the check passed because the row was simply absent, and a
  # check that cannot fire reads exactly like a check that passed. So:
  #   (a) COMPLETENESS — every core/<dir>/ on disk must have a row here. A new subtree with
  #       no row is an ERROR, not a silent fall-through to the `core/*` catch-all.
  #   (b) AGREEMENT    — map_consumer() must send each subtree to its stated destination.
  #   (c) INSTALLER    — the stated destination must actually appear in install.sh, so a
  #       row cannot be satisfied by writing a destination the installer never uses.
  SITES_TABLE="$(cat <<'SITES'
ci-templates|.github/workflows
fixtures|tests/fixtures
git-hooks|.githooks
schemas|.claude/schemas
hooks|.claude/hooks
scripts|scripts
session-driver|.claude/session-driver
skills|.claude/skills
team-roles|.claude/team-roles
SITES
)"
  # (a) Completeness: every core/<dir>/ on disk is accounted for.
  for d in "$REPO_ROOT"/core/*/; do
    [ -d "$d" ] || continue
    cdir="$(basename "$d")"
    printf '%s\n' "$SITES_TABLE" | grep -q "^${cdir}|" || err "core/${cdir}/ has no destination row in I8's site table. map_consumer()'s \`core/*\` catch-all will file it under '.claude/${cdir}/' — add a row stating where install.sh actually writes it (or '.claude/${cdir}' if the catch-all is right). This is the check core/git-hooks/ slipped past by being absent."
  done
  # (b) Agreement + (c) installer binding.
  while IFS='|' read -r cdir dest; do
    [ -n "$cdir" ] || continue
    [ -d "$REPO_ROOT/core/$cdir" ] || continue
    got="$(maps_to "core/$cdir/PROBE")"
    [ "$got" = "$dest/PROBE" ] || err "the pull and the installer disagree on where core/$cdir/ goes: map_consumer() sends it to '$got', install.sh writes '$dest/'. The consumer gets two copies at two paths, and the one the pull keeps fresh is not the one anything reads."
    # Anchored at a path boundary, deliberately. A bare substring match is satisfied by
    # any destination that merely STARTS with this one (`.githooks-REMOVED` contains
    # `.githooks`), so the row would stay green against an installer that no longer
    # writes it — the check would be as hand-wavy as the list it replaced.
    dest_re="$(printf '%s' "$dest" | sed 's/[][\.^$*+?(){}|]/\\&/g')"
    grep -qE '\$PROJECT_ROOT/'"$dest_re"'([/"]|$)' "$REPO_ROOT/scripts/install.sh" || err "I8's site table says core/$cdir/ goes to '$dest/', but install.sh never writes \$PROJECT_ROOT/$dest. Either the row is wrong or the installer stopped shipping it."
  done <<< "$SITES_TABLE"
fi

# --- I4: no dormant binding ---------------------------------------------------
# enforcer + ci_workflow file paths (distribution layout). Restricted to actual
# value lines (enforcer list items and ci_workflow: values) so prose/comment
# mentions of a path never register as a binding.
paths="$( {
  grep -oE '^      - core/(scripts|ci-templates)/[A-Za-z0-9._/-]+\.(sh|yml)' "$MAP" | sed -E 's/^      - //'
  grep -oE '^    ci_workflow: core/[A-Za-z0-9._/-]+\.yml' "$MAP" | sed -E 's/^    ci_workflow: //'
} | sort -u)"
for p in $paths; do
  [ -f "$REPO_ROOT/$p" ] || err "dormant binding: '$p' referenced in map but not on disk"
done
# fixtures: map uses consumer-runtime paths (tests/fixtures/<name>); upstream
# they live under core/fixtures/<name>. Resolve by basename.
fixtures="$(grep -oE 'tests/fixtures/[A-Za-z0-9._-]+' "$MAP" | sed -E 's#tests/fixtures/##' | sort -u)"
for d in $fixtures; do
  [ -d "$REPO_ROOT/core/fixtures/$d" ] || err "fixture '$d' named in map but missing under core/fixtures/"
done

# --- I9: every script enforcer declares WHERE it is invoked -------------------
# The map recorded `enforcer:` (WHO enforces a rule) on every entry and
# `call_sites:` (WHERE the enforcer is actually invoked) on ONE of them. So
# "Enforced by validate-X.sh" was a CLAIM, and nothing could tell a claim from a
# wiring. Measured on the reference consumer at v0.51.0:
#
#   validate-steering-budget.sh   11 real starvation violations, worst 10.0 min
#                                 -- invoked from NO gate. implementation.md:152
#                                 says "fails the gate on it"; that sentence was
#                                 false at every gate, in every phase.
#
# That is the mechanism behind three consecutive half-wired releases. A rule whose
# enforcer is called from nowhere is indistinguishable, in this file, from one
# called everywhere. I9 makes the difference representable and then required.
#
# Scope: `adjudication: script` only. An `llm` check is adjudicated by the lead
# READING gate-validation.md, so that file is inherently its call site; demanding
# a call_sites list there would be ceremony.
sites_of() { # sites_of <block> -> the file token of each site:, one per line
  printf '%s' "$1" | awk '
    /^    call_sites:/ {f=1; next}
    f && /^    [a-z_]+:/ {f=0}
    f && /^      - site:/ { v=$0; sub(/^      - site:[ ]*/,"",v); print v }
  '
}
enforcers_of() {
  printf '%s' "$1" | grep -oE '^      - core/(scripts|hooks)/[A-Za-z0-9._-]+' | sed -E 's#^      - ##'
}

# Resolve a site's leading file token to a real path under the skill.
resolve_site_file() {
  case "$1" in
    SKILL.md*)            echo "$REPO_ROOT/core/skills/ai-dlc/SKILL.md" ;;
    enforcement-map.yaml*) echo "" ;;
    *.md*)                echo "$REPO_ROOT/core/skills/ai-dlc/steps/${1%%[ ]*}" ;;
    *)                    echo "" ;;
  esac
}

while IFS= read -r blk_id; do
  [ -n "$blk_id" ] || continue
  block="$(awk -v want="$blk_id" '
    $0 ~ "^  - id: \"?" want "\"?$" {f=1; print; next}
    f && /^  - id: / {f=0}
    f {print}
  ' "$MAP")"
  adj="$(printf '%s' "$block" | sed -nE 's/^    adjudication: ([a-z]+).*/\1/p' | head -1)"
  [ "$adj" = "script" ] || continue

  sites="$(sites_of "$block")"

  # W1 -- a script enforcer with no declared call site.
  if [ -z "$sites" ]; then
    err "enforcement-map entry '$blk_id' is adjudication:script but declares NO call_sites. Its enforcer may be invoked from nowhere and nothing would notice — this is exactly how validate-steering-budget.sh came to guard 11 live violations from zero gates. Declare where it runs, with a posture."
    continue
  fi

  # W2 -- a declared call site must at least NAME the enforcer in the file it
  # points at. This catches a fictional site: an entry claiming to run at a step
  # whose file has never heard of the script.
  #
  # What W2 deliberately does NOT do, stated so nobody reads it as covered: it
  # cannot distinguish an INVOCATION from a PROSE MENTION. `retro.md:639` is a real
  # indented command; `implementation.md:152` ("validate-steering-budget.sh fails
  # the gate") is a sentence that was false for every gate that ever ran -- and a
  # basename grep passes both. Telling them apart means parsing English, and a
  # heuristic that fails closed on a legitimate new phrasing is an unpassable gate,
  # which gets turned off.
  #
  # The teeth are therefore in W1 + the `posture:` field, not here: an author must
  # WRITE DOWN where the enforcer runs and what happens when it fails, and that
  # declaration is reviewable. W2 only stops the declaration from naming a file
  # that does not know the script exists.
  #
  # Accept the bare form (`scripts/validate-X.sh`) and the verdict.sh wrapper
  # (`verdict.sh validate-X`), which is how gate-validation.md legitimately invokes
  # artifact-budget -- a basename-only grep misses the wrapped call entirely.
  for enf in $(enforcers_of "$block"); do
    base="$(basename "$enf")"
    stem="${base%.sh}"
    case "$enf" in core/hooks/*) continue ;; esac   # hooks are wired in settings, not step files
    while IFS= read -r site; do
      [ -n "$site" ] || continue
      f="$(resolve_site_file "$site")"
      [ -n "$f" ] || continue
      if [ ! -f "$f" ]; then
        err "entry '$blk_id' names call site '$site', but $f does not exist"
        continue
      fi
      if ! grep -qE "(${base}|verdict\.sh ${stem}\b)" "$f"; then
        err "entry '$blk_id' declares call site '$site', but $(basename "$f") never mentions ${base} (nor 'verdict.sh ${stem}'). The site is fictional: the file it names has never heard of the enforcer."
      fi
    done <<SITES
$sites
SITES
  done
done <<IDS
$(awk '/^checks:/{c=1} c && /^  - id:/ { v=$0; sub(/^  - id:[ ]*/,"",v); gsub(/"/,"",v); print v }' "$MAP")
IDS

# --- I5: core_manifest copies in sync (prefix-normalized) --------------------
norm_core_manifest() {
  awk '
    /^core_manifest:/ {f=1; next}
    f && /^  - / {v=$0; sub(/^  - /,"",v); print v; next}
    f {f=0}
  ' "$1" | sed -E 's#^core/skills/ai-dlc/##; s#^core/##' | sort -u
}
cm="$(norm_core_manifest "$CORE_MANIFEST")"
ss="$(norm_core_manifest "$SETUP_SITES")"
if [ "$cm" != "$ss" ]; then
  err "core_manifest copies diverge (core-manifest.md vs reconcile/setup-sites.md):"
  diff <(printf '%s\n' "$cm") <(printf '%s\n' "$ss") >&2 || true
fi

# --- I12: unregistered-drift scan set is BOUND, not hand-listed ---------------
# reconcile/unregistered-drift.sh scans a HAND-LISTED set of core subtrees for in-place drift.
# Twice that list silently missed a subtree that carried silently-driftable content —
# ai-dlc-setup/ (v0.63.0) and schemas/ (this release) — each overwrite-on-pull, each undetected
# until a real pull hit it. A hand-list is exactly the shape that rots: the next core dir escapes
# the scan and reads, forever, like a dir with no drift. So bind the list to a REVIEWED per-subtree
# policy, and make a new core subtree FAIL the build until it is classified.
#
#   COMPLETENESS — every core/skills/<skill>/ and every other core/<dir>/ has a policy row.
#   SCAN-MATCH   — the rows marked `scan` are EXACTLY the subtrees the ls-tree scans.
# The reason string on each `exempt` row is the review: machinery breaks loudly (not silent prose
# drift), and the update skill self-updates its own tree — neither belongs in the drift scan.
UD="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
if [ -f "$UD" ]; then
  DRIFT_POLICY="$(cat <<'POL'
skills/ai-dlc|scan
skills/ai-dlc-setup|scan
skills/ai-dlc-update|exempt:self-update owns this subtree (step 2), not the drift scan
team-roles|scan
hooks|scan
schemas|scan
scripts|exempt:machinery — an in-place edit breaks loudly (a failing validator), not as silent prose drift
session-driver|exempt:machinery (automation shell), not consumer-read rulebook
ci-templates|exempt:CI templates run from .github/workflows, not consumer-read rulebook
git-hooks|exempt:machinery (git hook), not consumer-read rulebook
fixtures|exempt:adversarial test data, not consumer-authored rulebook
POL
)"
  # Subtrees actually scanned: the core/ paths on unregistered-drift's ls-tree pathspec line.
  ud_scanned="$(awk '/ls-tree -r --name-only/{f=1} f{print} /2>\/dev\/null/{f=0}' "$UD" \
    | grep -oE 'core/skills/[A-Za-z0-9_-]+|core/[A-Za-z0-9_-]+' | sed 's#^core/##' | sort -u)"
  # Units on disk: each skill under core/skills/, plus each other core/<dir>.
  ud_units="$( { for d in "$REPO_ROOT"/core/skills/*/; do [ -d "$d" ] && echo "skills/$(basename "$d")"; done
                 for d in "$REPO_ROOT"/core/*/; do b="$(basename "$d")"; [ "$b" = skills ] && continue; [ -d "$d" ] && echo "$b"; done; } | sort -u)"

  # COMPLETENESS — every unit on disk is classified.
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    printf '%s\n' "$DRIFT_POLICY" | grep -q "^${u}|" \
      || err "core/${u}/ has no drift-scan policy row in validate-enforcement-map.sh I12. Classify it 'scan' (prose/schema a consumer could silently drift) or 'exempt:<reason>' (machinery / self-updated). This is the guard that stops the unregistered-drift scan set rotting the way ai-dlc-setup/ and schemas/ did."
  done <<EOF
$ud_units
EOF
  # Stale rows — every policy row names a real subtree.
  while IFS='|' read -r u disp; do
    [ -n "$u" ] || continue
    [ -d "$REPO_ROOT/core/$u" ] || err "I12 drift-scan policy names core/$u/, which does not exist — stale row."
  done <<EOF
$DRIFT_POLICY
EOF
  # SCAN-MATCH — the scan-marked policy set equals the tool's actual scan set.
  scan_policy="$(printf '%s\n' "$DRIFT_POLICY" | awk -F'|' '$2=="scan"{print $1}' | sort -u)"
  miss_scan="$(comm -23 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$ud_scanned"))"
  extra_scan="$(comm -13 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$ud_scanned"))"
  [ -n "$miss_scan" ]  && err "I12: policy marks these core subtrees 'scan' but unregistered-drift.sh does NOT scan them: $(echo $miss_scan). A scan-marked dir the tool skips is a silent-drift hole."
  [ -n "$extra_scan" ] && err "I12: unregistered-drift.sh scans these but the policy does not mark them 'scan': $(echo $extra_scan). Add a 'scan' row or drop them from the ls-tree."
fi

# --- Verdict ------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  n="$(printf '%s\n' "$map_ids" | grep -c .)"
  echo "OK: enforcement-map.yaml in sync with gate-validation.md ($n catalog checks), all bindings live, core_manifest copies match, drift-scan set bound (I12)."
  exit 0
fi
exit 1
