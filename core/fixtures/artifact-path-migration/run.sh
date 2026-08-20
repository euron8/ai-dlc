#!/usr/bin/env bash
# artifact-path-migration — migrate-artifact-paths.sh moves every path onto the declared
# grammar, REFUSES what it cannot derive, and its own output conforms to the rule it enforces.
#
# THE DEFECTS THIS EXISTS TO CATCH, every one of them measured on the reference consumer while
# the script was being written. None was found by reading it.
#
#  - MATCHING THE WHOLE PATH WITH A COMPONENT REGEX. The token boundary is `^` or `-`, and a
#    path separator is neither, so `docs/retro/sprint-299.md` matched NOTHING. 668 files were
#    detected instead of 2551 and `docs/retro` was absent from the plan entirely.
#  - ADJACENT TOKENS HIDING EACH OTHER. `grep -o` and `sed ...g` both consume the separator the
#    next token needs, so `gate-log-archive-s291-s292.md` reported ONE sprint. That is not a
#    cosmetic miss: a file naming two sprints was planned as if it named one, and would have
#    been filed under the wrong sprint permanently.
#  - THE SLOT NESTED INSIDE THE TOKEN IT REPLACES. A basename-only transform produced
#    `implementation-artifacts/sprint-287/smoke-evidence/s287/foo.md` on 53 directories --
#    output that breaks the grammar the script exists to impose.
#  - A HALF-MIGRATED STORY CORPUS. `story-S298-1-x.md` carries a matchable token and
#    `story-297-1-x.md` does not, so a run over `stories/` moves one sibling and leaves the
#    other. Split conventions inside one sprint are worse than one wrong convention.
#
# THE VERDICT IS NEVER TRUSTED. Every assertion below reads the TREE -- what exists, what does
# not, and whether the bytes survived -- rather than the script's own summary line. A migration
# that printed "2670 verified" while moving nothing would pass a report-reading fixture.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }

# install.sh maps core/scripts/<x> -> scripts/ai-dlc/<x>; core/skills/ai-dlc/ -> .claude/skills/ai-dlc/.
MIG="$(pick "$HERE/../../scripts/migrate-artifact-paths.sh" \
            "$HERE/../../../scripts/ai-dlc/migrate-artifact-paths.sh" \
            "$HERE/../../core/scripts/migrate-artifact-paths.sh")"
GRAMMAR="$(pick "$HERE/../../skills/ai-dlc/artifact-path-grammar.md" \
                "$HERE/../../../.claude/skills/ai-dlc/artifact-path-grammar.md" \
                "$HERE/../../core/skills/ai-dlc/artifact-path-grammar.md")"
# The migration resolves the grammar, the areas and the sprint-token expression through this
# sibling rather than carrying its own copy, so every mutant tree below has to hold BOTH files.
# A lone copy exits 2 at its first line, emits nothing, and "no output" otherwise scores as a
# kill -- which is what the unmutated control exists to catch, and did.
CONFIG="$(pick "$HERE/../../scripts/artifact-path-config.sh" \
               "$HERE/../../../scripts/ai-dlc/artifact-path-config.sh" \
               "$HERE/../../core/scripts/artifact-path-config.sh")"
[ -n "$MIG" ] && [ -n "$GRAMMAR" ] && [ -n "$CONFIG" ] \
  || { echo "FIXTURE ERROR: cannot locate migrate-artifact-paths.sh, artifact-path-config.sh and/or artifact-path-grammar.md" >&2; exit 2; }

# Lay down a runnable PAIR: the migration and the resolver it calls, side by side the way
# install.sh puts them. Mutants sed one of the two in place afterwards.
lay_pair() { mkdir -p "$1"; cp "$MIG" "$1/m.sh"; cp "$CONFIG" "$1/artifact-path-config.sh"; }

fails=0; asserts=0
ok()  { asserts=$((asserts+1)); printf '  ok    %s\n' "$1"; }
bad() { asserts=$((asserts+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
has() { [ -f "$1/$2" ]; }

echo "artifact-path-migration:"

# =============================================================================
# 1. DRY RUN WRITES NOTHING. The default must be safe, or the first run of a
#    2600-file mover on a real tree is an experiment.
# =============================================================================
W="$(bash "$HERE/seed.sh" "$GRAMMAR")"
BEFORE="$(cd "$W" && git status --porcelain | wc -l | tr -d ' ')"
OUT="$(bash "$MIG" --root "$W" 2>&1)"; RC=$?
AFTER="$(cd "$W" && git status --porcelain | wc -l | tr -d ' ')"
[ "$RC" -eq 0 ] && ok "dry run exits 0 when there is work to do" \
                || bad "dry run exited $RC, expected 0"
[ "$BEFORE" = "0" ] && [ "$AFTER" = "0" ] \
  && ok "dry run left the work tree untouched (git reports no change)" \
  || bad "dry run MODIFIED the tree — porcelain went '$BEFORE' -> '$AFTER'"
has "$W" "docs/retro/sprint-301.md" \
  && ok "...and the source files are all still where they were" \
  || bad "a source file moved during a DRY RUN"
case "$OUT" in *"DRY RUN"*) ok "the dry run says so in its own output" ;;
               *) bad "the dry run does not announce itself; an operator cannot tell the two modes apart" ;; esac

# THE SELF-CHECK MUST BE PRESENT AND ZERO. It is the one arm that catches the script writing
# paths its own grammar rejects, and it reports on both roads.
case "$OUT" in
  *"outside the slot: 0"*) ok "self-check: no planned destination carries a token outside the slot" ;;
  *) bad "self-check missing or non-zero — the plan contains paths the grammar rejects" ;;
esac

# =============================================================================
# 2. APPLY — every transform property, asserted against the TREE.
# =============================================================================
OUT="$(bash "$MIG" --root "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "apply exits 0" || { bad "apply exited $RC"; printf '%s\n' "$OUT" | tail -5 | sed 's/^/        /'; }

# $1 label  $2 destination that MUST exist  $3 source that MUST be gone  $4 why
moved() {
  asserts=$((asserts+1))
  if has "$W" "$2" && ! has "$W" "$3"; then printf '  ok    %-26s %s\n' "$1" "$4"
  else fails=$((fails+1)); printf '  FAIL  %-26s %s\n           dest %s: %s / src %s: %s\n' "$1" "$4" \
       "$2" "$(has "$W" "$2" && echo present || echo MISSING)" \
       "$3" "$(has "$W" "$3" && echo STILL-THERE || echo gone)"; fi
}

moved "basename-prefix"  "_bmad-output/planning-artifacts/s301/research-notes.md" \
                         "_bmad-output/planning-artifacts/s301-research-notes.md" \
                         "s<N>- prefix moves into the directory"
moved "basename-word"    "_bmad-output/party-mode-transcripts/s301/retro.md" \
                         "_bmad-output/party-mode-transcripts/sprint-301-retro.md" \
                         "the sprint-<N>- word form too"
moved "basename-suffix"  "_bmad-output/implementation-artifacts/s301/gate-log-archive.md" \
                         "_bmad-output/implementation-artifacts/gate-log-archive-s301.md" \
                         "and the SUFFIX position, which is why a prefix filter was never enough"
moved "strips-to-nothing" "docs/retro/s301/retro.md" \
                         "docs/retro/sprint-301.md" \
                         "a nameless basename takes the name of what contained it"
moved "strips-to-nothing-2" "_bmad-output/implementation-artifacts/s301/sprint-status.yaml" \
                         "_bmad-output/implementation-artifacts/sprint-status/sprint-301.yaml" \
                         "...and the promoted directory does not also remain a directory"
moved "directory-token"  "_bmad-output/implementation-artifacts/s301/smoke-evidence/shot.png" \
                         "_bmad-output/implementation-artifacts/sprint-301/smoke-evidence/shot.png" \
                         "a token in a DIRECTORY moves too, subdirectories intact"
moved "dir-and-basename" "_bmad-output/planning-artifacts/s301/archive/cycle-1/prd-adversarial-p2.md" \
                         "_bmad-output/planning-artifacts/archive/s301-cycle-1/prd-adversarial-s301-p2.md" \
                         "both at once collapse to ONE slot under the area"
moved "root-log-archive" "_bmad-output/implementation-artifacts/s301/pipeline-continuation-log-archive.md" \
                         "_bmad-output/pipeline-continuation-log-archive-s301.md" \
                         "a rotation archive at _bmad-output/ root lands in implementation-artifacts"
moved "inferred-area"    "_bmad-output/brainstorming/s301/brainstorm-ideas.md" \
                         "_bmad-output/brainstorming/brainstorm-s301-ideas.md" \
                         "an UNDECLARED area still migrates"
moved "inferred-area-token" "_bmad-output/party-verdicts-retro/s301/pm.md" \
                         "_bmad-output/party-verdicts-s301-retro/pm.md" \
                         "an inferred area's OWN token is stripped before it anchors the slot"
moved "uppercase-S"      "docs/reviews/s301/1-code-review.md" \
                         "docs/reviews/S301-1-code-review.md" \
                         "S<N> normalises to the one legal spelling"

# ALREADY CONFORMING FILES ARE NOT TOUCHED. A migration that rewrites correct paths churns the
# tree and breaks citations for nothing.
has "$W" "_bmad-output/planning-artifacts/s301/architecture-context.md" \
  && ok "a path already in the slot is left alone" \
  || bad "an ALREADY CONFORMING path was moved"
has "$W" "_bmad-output/planning-artifacts/prd.md" \
  && ok "a durable area-root file with no sprint is left alone" \
  || bad "a durable file with no sprint token was moved"

# =============================================================================
# 3. REFUSALS — each one stays put, and is NAMED.
# =============================================================================
# $1 label  $2 path that must still exist  $3 reason token in the report  $4 why
refused() {
  asserts=$((asserts+1))
  if has "$W" "$2" && grep -q "$3" <<<"$OUT"; then printf '  ok    %-26s %s\n' "$1" "$4"
  else fails=$((fails+1)); printf '  FAIL  %-26s %s\n           still present: %s / report names %s: %s\n' "$1" "$4" \
       "$(has "$W" "$2" && echo yes || echo NO-IT-MOVED)" "$3" \
       "$(grep -q "$3" <<<"$OUT" && echo yes || echo NO)"; fi
}

refused "adjacent-tokens" "_bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md" \
        "AMBIGUOUS" "two ADJACENT tokens are seen as two sprints, not one"
refused "tokens-disagree" "_bmad-output/planning-artifacts/archive/s300-cycle-1/notes-s295.md" \
        "AMBIGUOUS" "a directory and a basename naming different sprints is refused"
refused "no-area"         "_bmad-output/s177/wave-1-dispatch-status.md" \
        "NO-AREA" "a sprint dir under a non-area scan root has nothing to anchor to"

# THE STORY CORPUS: BOTH SPELLINGS MOVE, OR NEITHER. Still the anti-half-migration arm; what
# changed is which side of it is correct. The explicit-token file and the bare-number file must
# reach the SAME shape under their own sprints, and the sprint must be gone from both basenames.
moved "story-token"      "_bmad-output/planning-artifacts/s301/stories/story-1-alpha.md" \
                         "_bmad-output/planning-artifacts/stories/story-S301-1-alpha.md" \
                         "an explicit-token story lands under its sprint, sprint out of the name"
moved "story-bare-number" "_bmad-output/planning-artifacts/s297/stories/story-1-beta.md" \
                         "_bmad-output/planning-artifacts/stories/story-297-1-beta.md" \
                         "a BARE-number story lands the same way — read from position, not name"

# A story already on the grammar is untouched, and its INDEX is not read as a sprint. Without the
# `s<N>/`-above-it test this file would be "migrated" to s12/, which is the reading the deferral
# was afraid of — correctly, just in the wrong place.
asserts=$((asserts+1))
if has "$W" "_bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md" \
   && ! has "$W" "_bmad-output/planning-artifacts/s299/stories/story-3-gamma.md"; then
  printf '  ok    %-26s %s\n' "story-index-not-sprint" "a conforming story is left alone; its index is not read as a sprint"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "story-index-not-sprint" "a story ALREADY under s299/ was re-read: index 12 became a sprint slot"
fi

refused "story-no-sprint" "_bmad-output/planning-artifacts/stories/bug-mobile-layout.md" \
        "STORY-NO-SPRINT" "a story basename with no sprint in it is refused by path, not guessed"

# =============================================================================
# 4. NOTHING WAS LOST. git is the witness, not the script's own verdict.
# =============================================================================
STATUS="$(cd "$W" && git status --porcelain=1 | cut -c1-2 | sort -u | tr -d ' \n')"
[ "$STATUS" = "R" ] && ok "git sees ONLY renames — no deletions, no additions, no content edits" \
                    || bad "git status letters were '$STATUS', expected only 'R' (renames)"
N_BEFORE="$(cd "$W" && git ls-files | wc -l | tr -d ' ')"
[ "$N_BEFORE" -gt 0 ] && ok "tracked file count is non-zero ($N_BEFORE) — the control on the arm above" \
                      || bad "zero tracked files; every assertion above is vacuous"

# =============================================================================
# 5. IDEMPOTENT. A second run must find nothing, or the transform is not a function.
# =============================================================================
(cd "$W" && git add -A && git commit -q -m migrated)
bash "$MIG" --root "$W" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "a second run exits 3 (nothing to migrate) — the transform is idempotent" \
                || bad "a second run exited $RC, expected 3; the first run left work behind"
rm -rf "$W"

# =============================================================================
# 6. MUTANTS. Each removes ONE mechanism and must flip exactly its own arm.
# =============================================================================
MUT="$(mktemp -d "${TMPDIR:-/tmp}/apmig-mut-XXXXXX")"
# $1 tag  $2 sed program  $3 shell test over $w that must be TRUE on the mutant  $4 claim
# Each mutant is a guarded COPY, and a sed that matches nothing is a failure rather than a
# silent pass. Each asserts a property of the TREE the mutant produced, not of its report.
mutate() {
  # Split, not one `local`: `local a="$1" d="$MUT/$a"` expands $a while it is still being
  # declared, which under `set -u` aborts the fixture with "unbound variable" — a harness
  # failure that reads like a mutant result.
  local tag="$1" prog="$2" test_expr="$3" claim="$4"
  local d="$MUT/$tag" w
  asserts=$((asserts+1))
  lay_pair "$d"
  sed -E "$prog" "$MIG" > "$d/m.sh"
  if cmp -s "$MIG" "$d/m.sh"; then
    fails=$((fails+1)); printf '  FAIL  MUTANT %-18s sed matched NOTHING — the mutant IS the original\n' "$tag"; return
  fi
  w="$(bash "$HERE/seed.sh" "$GRAMMAR")"
  bash "$d/m.sh" --root "$w" --apply >/dev/null 2>&1
  if eval "$test_expr"; then printf '  ok    MUTANT %-18s %s\n' "$tag" "$claim"
  else fails=$((fails+1)); printf '  FAIL  MUTANT %-18s did NOT flip: %s\n' "$tag" "$claim"; fi
  rm -rf "$w"
}

# Scan the whole path with the component regex instead of splitting on `/`. Every token a `/`
# precedes goes invisible, so `docs/retro/sprint-301.md` is never even seen.
mutate 'whole-path-scan' \
  "s@[|] tr '/' '.n' [|]@|@" \
  '[ -f "$w/docs/retro/sprint-301.md" ]' \
  'scanning the whole path leaves docs/retro/sprint-301.md unmigrated — the 668-vs-2551 defect'

# Disarm the ambiguity refusal. The file naming TWO sprints is then filed under one of them,
# which is the silently-wrong outcome, not a loud one.
mutate 'ambiguity-allowed' \
  's@^  if \[ "\$nhits" -gt 1 \]; then@  hits="$(printf "%s" "$hits" | head -1)"; nhits=1\n  if [ "$nhits" -gt 1 ]; then@' \
  '[ ! -f "$w/_bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md" ]' \
  'collapsing to the FIRST sprint instead of refusing files a two-sprint path under a guess'

# Stop normalising the bare leading number. The corpus then SPLITS — exactly the half-migration
# the whole-corpus deferral existed to prevent: the capital-S file moves, its bare-number sibling
# stays behind under a different convention.
# The anchor is the `s` in the REPLACEMENT half of the normalising expression — one occurrence in
# the whole file, checked. Removing it makes the rewrite an identity, which is precisely "the bare
# number is no longer read as a sprint" and nothing else.
mutate 'stories-half-migrated' \
  's@/story-s@/story-@' \
  '[ ! -f "$w/_bmad-output/planning-artifacts/stories/story-S301-1-alpha.md" ] && [ -f "$w/_bmad-output/planning-artifacts/stories/story-297-1-beta.md" ]' \
  'without the bare-number normalisation one sprint\x27s stories split across two conventions'

# Break the POSITIONAL test, so a story already under `s<N>/` is treated as legacy. Its INDEX is
# then read as a sprint and a conforming file is moved to a slot named after its own index.
mutate 'story-slot-blind' \
  's@^  local head=@  return 0\n  local head=@' \
  '[ ! -f "$w/_bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md" ]' \
  'a conforming story is re-migrated once the s<N>/-above-it test stops firing'

# UNMUTATED CONTROL, from the same directory: the harness itself must not be what fails. A lone
# copy that dies sourcing something emits nothing, and "no output" otherwise scores as a kill.
asserts=$((asserts+1))
lay_pair "$MUT/control"
wc="$(bash "$HERE/seed.sh" "$GRAMMAR")"
# HERE-STRING, NOT A PIPE, and this arm is where that was learned the hard way: as a pipe it
# reported the control BROKEN precisely when the control was working. `... | grep -q` under
# `pipefail` returns NON-ZERO on a MATCH -- grep leaves at its first hit, the writer takes
# SIGPIPE, and pipefail answers with the writer. It is a SIZE threshold, not a race, so the
# small greps above survived it and the one reading a whole migration report did not. I54/I54b
# bind the idiom across every shipped shell file.
ctl_out="$(bash "$MUT/control/m.sh" --root "$wc" 2>&1)"
if grep -q "outside the slot: 0" <<<"$ctl_out"; then
  ok "CONTROL: an unmutated copy in the mutant directory still passes its own self-check"
else
  bad "CONTROL: an unmutated copy FAILED — the mutant harness is what is broken, not the mutants"
fi
rm -rf "$wc" "$MUT"

# =============================================================================
# AREAS INFERRED — the remedy names the CONSUMER's file, and declaring an area
# there actually stops it being inferred.
#
# THE DEFECT. The report said "the grammar file is INCOMPLETE and should declare them", naming
# CORE's artifact-path-grammar.md — a file a pull overwrites, and the wrong home by core's own
# rule (the grammar's line 4 says the consumer declares its areas in the file named by
# `consumer_artifact_paths_file:`). A consumer session followed it literally and proposed adding
# nine consumer-specific areas to core.
#
# AND THE WORDING FIX ALONE WOULD HAVE BEEN WORSE THAN THE WRONG WORDING. Nothing read the
# consumer's file, so "declare them there" would have changed no verdict on any later run: the
# same areas would be inferred again, with a corrected sentence in front of an inert mechanism.
# The pair below is what proves the join is live.
# =============================================================================
wi="$(bash "$HERE/seed.sh" "$GRAMMAR")"

# ARM A — nothing declared, which is the state the reference consumer was in.
a_out="$(bash "$MIG" --root "$wi" 2>&1)"
grep -q "_bmad-output/brainstorming" <<<"$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$a_out")" \
  && ok "undeclared area is reported as inferred" \
  || bad "an undeclared area was NOT reported as inferred — the remaining arms cannot be attributed"
if grep -q "\.claude/skills/ai-dlc/artifact-paths.md" <<<"$a_out"; then
  ok "the remedy names the CONSUMER's own file, resolved from the contract"
else
  bad "the remedy did not name the consumer's declaration file"
fi
grep -q "INCOMPLETE and should declare them" <<<"$a_out" \
  && bad "the report still sends the operator to CORE's grammar, which a pull overwrites" \
  || ok "the report no longer sends the operator to core's grammar"

# ARM B — declare ONE of them in the consumer's own file. It must drop out of the inferred set,
# and the OTHER undeclared area must stay in it: a run that simply stopped reporting would
# satisfy a one-sided assertion.
mkdir -p "$wi/.claude/skills/ai-dlc"
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

areas:
  _bmad-output/brainstorming
EOF
b_inf="$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$(bash "$MIG" --root "$wi" 2>&1)")"
if grep -q "_bmad-output/brainstorming" <<<"$b_inf"; then
  bad "declaring the area in the consumer's file did NOT stop it being inferred — the remedy is inert"
elif ! grep -q "party-verdicts-retro" <<<"$b_inf"; then
  bad "the whole inferred set vanished, so the assertion above is satisfied by a report that stopped reporting"
else
  ok "declaring an area in the consumer's file removes it from the inferred set, and only it"
fi

# ARM B2 — THE UNREADABLE DECLARATION. The template shipped `area: <path>` one per line for
# seven releases while the resolver only ever read an `areas:` block, so a consumer following
# its own scaffolded documentation declared nothing and was told to declare it on every run.
# Correcting the template fixes nothing for a consumer that HAS one: install.sh preserves that
# file by design, so the correction cannot arrive by pull and the diagnosis has to.
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

area: _bmad-output/brainstorming
area: _bmad-output/test-artifacts
EOF
b2_out="$(bash "$MIG" --root "$wi" 2>&1)"
if grep -q "UNREADABLE DECLARATION" <<<"$b2_out"; then
  ok "an 'area:'-per-line declaration is reported as UNREADABLE, not silently ignored"
else
  bad "the documented-but-unreadable 'area:' form extracted nothing and said nothing — the consumer is told to declare an area they have already declared, on every run, forever"
fi
# and it must still be INFERRED, because nothing was read: a diagnosis that replaced the
# inferred row would hide the consequence it is diagnosing.
grep -q "_bmad-output/brainstorming" <<<"$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$b2_out")" \
  && ok "  and the area is STILL inferred — the diagnosis reports the state, it does not mask it" \
  || bad "  the diagnosis replaced the inferred row, so the report no longer shows what was lost"

# THE NEAR-MISS. A READABLE block that also mentions `area:` in its prose must stay silent, or
# the check fires on every correctly-declared file that happens to describe its own grammar.
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

An `area:` is a durable root; declare each one under the block below.

areas:
  _bmad-output/brainstorming
EOF
if grep -q "UNREADABLE DECLARATION" <<<"$(bash "$MIG" --root "$wi" 2>&1)"; then
  bad "a READABLE areas: block was reported as unreadable because the prose mentions 'area:' — the predicate is not the conjunction and every compliant file is a false positive"
else
  ok "  and a readable block that mentions 'area:' in prose stays silent"
fi

# Restore ARM B's state so the mutation below measures what it was written to measure.
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

areas:
  _bmad-output/brainstorming
EOF

# MUTATION — stop reading the consumer's file. ARM B must regress and ARM A must not move.
# THE SUBJECT IS THE RESOLVER, not the migration: the consumer-area join moved into
# artifact-path-config.sh so the conformance validator could not grow a second copy of it. The
# mutant therefore replaces the RESOLVER beside an unmutated migration, which is also the arm
# that proves the migration really goes through it rather than carrying a private fallback.
MUTI="$wi-mut"; rm -rf "$MUTI"; lay_pair "$MUTI"
sed 's@^  CONSUMER_AREAS="\$(areas_of "\$CONSUMER_AREAS_REL")"@  CONSUMER_AREAS=""@' \
  "$CONFIG" > "$MUTI/artifact-path-config.sh"
if cmp -s "$CONFIG" "$MUTI/artifact-path-config.sh"; then
  bad "FIXTURE ERROR: the consumer-areas mutation matched nothing, so ARM B proves nothing"
else
  m_inf="$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$(bash "$MUTI/m.sh" --root "$wi" 2>&1)")"
  if grep -q "_bmad-output/brainstorming" <<<"$m_inf"; then
    ok "MUTATION — without the consumer read, a declared area is inferred again: the join is load-bearing"
  else
    bad "MUTATION — the declared area stayed out even without reading the consumer's file, so ARM B is vacuous"
  fi
fi
rm -rf "$wi" "$MUTI"

echo
if [ "$fails" -eq 0 ]; then echo "artifact-path-migration: PASS ($asserts assertions)"; exit 0; fi
echo "artifact-path-migration: $fails of $asserts assertion(s) FAILED" >&2
exit 1
