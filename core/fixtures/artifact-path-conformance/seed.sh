#!/usr/bin/env bash
# Seed a consumer-shaped git tree for the conformance validator, and print the WORK dir.
#
#   seed.sh [<grammar-file>] [--empty]   -> prints WORK
#
# `--empty` seeds a git tree with NO artifact under any scan root -- a greenfield consumer on its
# first push. It is a case, not an absence: a validator that FAILS there makes the grammar
# unadoptable, and one that prints PASS there has verified nothing and said the opposite.
#
# EVERY OTHER FILE HERE IS A SHAPE THE REFERENCE CONSUMER ACTUALLY CONTAINS. Four of them exist
# for one arm each and are worth naming, because three of the four are things that must NOT be
# reported and a validator asserting only its positives would pass without them:
#
#   * conforming under a DECLARED area                planning-artifacts/s301/…
#   * conforming under an INFERRED area               brainstorming/s301/…      <- 92 false
#     positives on the reference consumer when the slot was resolved against declared areas
#     alone, on a tree whose migration planned ZERO moves. An area nobody has declared yet is
#     still the area the migration anchors the slot to.
#   * durable, at an area root, no sprint anywhere    planning-artifacts/prd.md
#   * a sprint token in a component that is NOT the slot, under a conforming slot
set -eu

GRAMMAR_SRC=""
EMPTY=0
for a in "$@"; do
  case "$a" in
    --empty) EMPTY=1 ;;
    *) GRAMMAR_SRC="$a" ;;
  esac
done

# Absolute BEFORE the cd, for migrate-artifact-paths.sh's reason exactly.
if [ -n "$GRAMMAR_SRC" ]; then
  case "$GRAMMAR_SRC" in /*) : ;; *) GRAMMAR_SRC="$(pwd)/$GRAMMAR_SRC" ;; esac
  [ -f "$GRAMMAR_SRC" ] || { echo "FIXTURE ERROR: seed cannot read grammar at $GRAMMAR_SRC" >&2; exit 2; }
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apconf-fx-XXXXXX")"
cd "$WORK"
git -c init.defaultBranch=main init -q .
git config user.email f@example.com; git config user.name Fixture; git config commit.gpgsign false

mk() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

if [ "$EMPTY" -eq 1 ]; then
  mk README.md "a consumer that has produced no artifact yet"
else
  # --- BLOCKING: non-conforming, unambiguous, area derivable, outside stories/ ---
  mk _bmad-output/planning-artifacts/s301-research-notes.md                 "basename token, prefix"
  mk _bmad-output/party-mode-transcripts/sprint-301-retro.md                "basename token, word form"
  mk _bmad-output/implementation-artifacts/gate-log-archive-s301.md         "basename token, SUFFIX"
  mk docs/retro/sprint-301.md                                              "basename strips to nothing"
  mk _bmad-output/implementation-artifacts/sprint-301/smoke-evidence/shot.png "DIRECTORY token"
  mk docs/reviews/S301-1-code-review.md                                     "uppercase S"
  # a correctly-spelled slot with a token in a component BELOW it -- the slot exemption is
  # positional, and a validator exempting `s<N>` anywhere would miss this
  mk _bmad-output/planning-artifacts/s301/s301-cycle-1/notes.md             "token under the slot"

  # --- CONFORMING: must not be reported at all -----------------------------------
  mk _bmad-output/planning-artifacts/s301/architecture-context.md           "declared area, right slot"
  mk _bmad-output/planning-artifacts/prd.md                                 "durable, no sprint"
  mk _bmad-output/brainstorming/s301/discovery-brainstorming.md             "INFERRED area, right slot"
  mk docs/retro/s300/retro.md                                               "declared area, right slot"

  # --- AMBIGUOUS: reported, never blocking ---------------------------------------
  mk _bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md    "two adjacent tokens"
  mk _bmad-output/planning-artifacts/archive/s300-cycle-1/notes-s295.md     "dir 300, file 295"

  # --- NO-AREA: reported, never blocking -----------------------------------------
  mk _bmad-output/s177/wave-1-dispatch-status.md                            "no area to anchor to"

  # --- the story corpus. BLOCKING in both spellings, because both are migratable ---
  # The corpus is no longer deferred as a class: a `stories/` directory with no `s<N>/` above it
  # predates the grammar whatever its files are called, so the leading number IS the sprint.
  mk _bmad-output/planning-artifacts/stories/story-S301-1-alpha.md          "explicit token"
  mk _bmad-output/planning-artifacts/stories/story-297-1-beta.md            "bare leading number"
  # ...and the one shape that survives, per FILE rather than per directory: no sprint anywhere in
  # the name, so the migration has nowhere to put it and nothing here can clear it.
  mk _bmad-output/planning-artifacts/stories/bug-mobile-layout.md           "no sprint in the name"
  # A story ALREADY on the grammar whose basename leads with a number. Conforming, and it must not
  # be re-read: the `s<N>/` above it is what says so.
  mk _bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md      "conforming story"
fi

if [ -n "$GRAMMAR_SRC" ]; then
  mkdir -p .claude/skills/ai-dlc
  cp "$GRAMMAR_SRC" .claude/skills/ai-dlc/artifact-path-grammar.md
fi

# The contract, because the resolver reaches the consumer's own area declaration through it
# rather than restating the path. The file it names is deliberately NOT created: that is the
# state the reference consumer was actually in, and it is what makes `brainstorming` an
# INFERRED area rather than a declared one.
mkdir -p .claude/skills/ai-dlc
cat > .claude/skills/ai-dlc/layer-contract.yaml <<'EOF'
contract_version: 16
consumer_artifact_paths_file: .claude/skills/ai-dlc/artifact-paths.md
EOF

git add -A
git commit -q -m "seed"
printf '%s\n' "$WORK"
