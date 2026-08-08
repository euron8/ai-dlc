#!/usr/bin/env bash
# Seed a consumer-shaped git tree carrying one instance of every case the migration must
# handle, and print the WORK dir.
#
#   seed.sh [<grammar-file>]   -> prints WORK
#
# EVERY FILE HERE IS A CASE THE REFERENCE CONSUMER ACTUALLY CONTAINS, not an invented one.
# The names are trimmed but the SHAPES are measured: a basename token, a directory token, a
# nested pair, a basename that strips to nothing, two adjacent tokens, a path naming two
# different sprints, a sprint directory under a non-area, an undeclared area, and the story
# corpus's two incompatible spellings.
set -eu

GRAMMAR_SRC="${1:-}"
# Absolute BEFORE the cd. This seed changes directory into the work tree, so a relative
# grammar path would be re-resolved against a tree that does not contain it -- the same
# defect the migration script itself carries a guard for.
if [ -n "$GRAMMAR_SRC" ]; then
  case "$GRAMMAR_SRC" in /*) : ;; *) GRAMMAR_SRC="$(pwd)/$GRAMMAR_SRC" ;; esac
  [ -f "$GRAMMAR_SRC" ] || { echo "FIXTURE ERROR: seed cannot read grammar at $GRAMMAR_SRC" >&2; exit 2; }
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/apmig-fx-XXXXXX")"
cd "$WORK"
git -c init.defaultBranch=main init -q .
git config user.email f@example.com; git config user.name Fixture; git config commit.gpgsign false

mk() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

# --- MOVES: one per transform property ---------------------------------------
# basename token, lowercase prefix
mk _bmad-output/planning-artifacts/s301-research-notes.md                 "research notes"
# basename token, `sprint-` word form
mk _bmad-output/party-mode-transcripts/sprint-301-retro.md                "transcript"
# basename token, SUFFIX position
mk _bmad-output/implementation-artifacts/gate-log-archive-s301.md         "gate log"
# basename strips to NOTHING -> takes the name of what contained it
mk docs/retro/sprint-301.md                                               "retro doc"
mk _bmad-output/implementation-artifacts/sprint-status/sprint-301.yaml    "sprint: 301"
# DIRECTORY token, with a clean basename inside
mk _bmad-output/implementation-artifacts/sprint-301/smoke-evidence/shot.png "png"
# BOTH a directory token and a basename token, same sprint
mk _bmad-output/planning-artifacts/archive/s301-cycle-1/prd-adversarial-s301-p2.md "pass 2"
# rotation archive at `_bmad-output/` ROOT -> implementation-artifacts
mk _bmad-output/pipeline-continuation-log-archive-s301.md                 "flow log"
# an area the grammar does not declare -> inferred, and reported
mk _bmad-output/brainstorming/brainstorm-s301-ideas.md                    "ideas"
# an undeclared area whose OWN name carries the sprint -> stripped before use as an area
mk _bmad-output/party-verdicts-s301-retro/pm.md                           "verdict"
# uppercase S
mk docs/reviews/S301-1-code-review.md                                     "review"

# --- ALREADY CONFORMING: must not move, and must not be counted as work -------
mk _bmad-output/planning-artifacts/s301/architecture-context.md           "already right"
mk _bmad-output/planning-artifacts/prd.md                                 "durable, no sprint"

# --- REFUSALS: one per reason -------------------------------------------------
# two ADJACENT tokens naming DIFFERENT sprints -- the case a `grep -o` cannot see, because
# the first match eats the separator the second one needs
mk _bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md    "spans two sprints"
# two tokens in different components, disagreeing
mk _bmad-output/planning-artifacts/archive/s300-cycle-1/notes-s295.md     "dir says 300, file says 295"
# a sprint directory directly under a scan root that is NOT an area
mk _bmad-output/s177/wave-1-dispatch-status.md                            "no area to anchor to"

# --- the story corpus, in THREE spellings -------------------------------------
# `story-S301-1` carries a token the transform matches directly; `story-297-1` spells the sprint
# as a bare number, readable only because the directory has no `s<N>/` above it and therefore
# predates the grammar. Both must land, and land the same way, or one sprint's stories end up
# split across two conventions — which is what the whole-corpus deferral existed to prevent.
mk _bmad-output/planning-artifacts/stories/story-S301-1-alpha.md          "story"
mk _bmad-output/planning-artifacts/stories/story-297-1-beta.md            "story"
# ...and one that gives no sprint at all. It is REFUSED by path rather than moved under a guess.
mk _bmad-output/planning-artifacts/stories/bug-mobile-layout.md           "story"
# A story ALREADY on the grammar, whose basename happens to lead with a number. It must not be
# touched: the `s<N>/` above it is what says so, and without that test the leading number would be
# re-read as a sprint. The number MATCHES the parent slot deliberately — with any other value the
# path would name two sprints and the mutant would produce an AMBIGUOUS refusal instead of a move,
# and this fixture's mutants assert on the TREE, never on the report.
mk _bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md     "story"

if [ -n "$GRAMMAR_SRC" ]; then
  mkdir -p .claude/skills/ai-dlc
  cp "$GRAMMAR_SRC" .claude/skills/ai-dlc/artifact-path-grammar.md
fi

# THE CONTRACT, because the migration resolves the CONSUMER's own area declaration through it
# rather than restating the path. Seeded with the key alone: the file it names is deliberately
# NOT created here, so the fixture's first arm is a consumer that has declared nothing — which
# is the state the reference consumer was actually in, its artifact-paths.md byte-identical to
# the scaffolded template. The second arm writes it.
mkdir -p .claude/skills/ai-dlc
cat > .claude/skills/ai-dlc/layer-contract.yaml <<'EOF'
contract_version: 16
consumer_artifact_paths_file: .claude/skills/ai-dlc/artifact-paths.md
EOF

git add -A
git commit -q -m "seed"
printf '%s\n' "$WORK"
