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
cd "$WORK" || exit 2
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
# ...and one that gives no sprint at all, in its NAME or in its BODY. It is REFUSED by path rather
# than moved under a guess. The body is asserted to be silent: the recovery below reads the file,
# so a body mentioning a sprint would move this file and this refusal arm would go vacuous.
mk _bmad-output/planning-artifacts/stories/bug-mobile-layout.md           "story"

# --- RECOVERY: the sprint is in the FILE where the PATH does not carry one ----
# Every shape here is measured on the reference consumer, where 19 of the 23 files this class once
# refused are recoverable and the operator's own migration commit places all 23 as PURE DIRECTORY
# MOVES -- proving the old refusal's "rename it" was never what anyone did.
#
# HEADER-RECOVERABLE, AND IT IS THE PRECEDENCE CASE. The basename opens with 124, the header says
# 72, and the operator filed it under s72: on the consumer this is `bug-124-deployed-range-overwrite.md`,
# whose leading number is a CARRY-OVER ITEM and not a sprint. A recovery that asks the basename
# first files it under s124 silently, so this one file is what separates the two orders.
mk _bmad-output/planning-artifacts/stories/bug-124-deployed-range.md \
   '# Deployed range overwrite

**Sprint:** 72
**Status:** done'
# HEADER-RECOVERABLE with trailing prose on the header line, which four of the consumer's six
# header hits carry in some form (`**Sprint:** 18 (carry-over eligible)`).
mk _bmad-output/planning-artifacts/stories/bug-dashboard-portfolio.md \
   '# Dashboard portfolio fixes

**Sprint:** 18 (carry-over eligible)'
# SUBJECT-RECOVERABLE: no header at all, and a bare leading number. Six consumer files
# (`192-ff-A-...`) have exactly this shape.
mk _bmad-output/planning-artifacts/stories/192-ff-A-token-decimals.md    "no header, leading number"
# A DECOY THE HEADER CHANNEL MUST NOT READ. `**Epic:** Sprint 131b` and `**QA agent:** Sprint
# 158-hotfix` both appear in the consumer population, and a header expression not anchored to the
# line start reads either as a declaration. This file's ONLY recoverable sprint is its basename's
# 158, so if the decoy were read it would land under s131 instead and the arm below would see it.
mk _bmad-output/planning-artifacts/stories/hotfix-158-1-token0-fixes.md \
   '# Token0 fixes

**Epic:** Sprint 131b — a mid-line mention, not a declaration
**QA agent:** Sprint 158-hotfix'
# --- HEADER SPELLINGS THAT ARE PRESENT BUT NOT A BARE NUMBER -------------------
# EVERY BASENAME BELOW LEADS WITH A CARRY-OVER ITEM NUMBER, deliberately. That is what makes these
# discriminating: if the header channel declines and falls through, each lands under its ITEM
# rather than its sprint -- silently, and worse than the refusal the recovery replaced.
#
# `S`-PREFIXED, WHICH THE CONSUMER USES 46 times at HEAD and 30 at the pre-migration ref, against a
# control of 817 bare-digit headers. It must resolve, and beat the basename's 124.
mk _bmad-output/planning-artifacts/stories/bug-124-s-prefix-hdr.md \
   '# S-prefixed header

**Sprint:** S270 (carry-over from 269)'
# UNPARSEABLE BUT PRESENT -- a range, a placeholder value, and the value the shipped story template
# scaffolds. Each must REFUSE rather than fall through.
mk _bmad-output/planning-artifacts/stories/bug-311-range-hdr.md \
   '# Range header

**Sprint:** 53-54'
mk _bmad-output/planning-artifacts/stories/bug-312-tbd-hdr.md \
   '# Undecided header

**Sprint:** TBD'
mk _bmad-output/planning-artifacts/stories/bug-313-placeholder-hdr.md \
   '# Unfilled template

**Sprint:** [sprint ID/name]'
# NON-CANONICAL AND NON-SPRINT NUMERIC VALUES. `007` is sprint 7 spelt long -- it must land in the
# ONE slot s7/, never mint a second home at s007/. `0` names no sprint at all and refuses.
mk _bmad-output/planning-artifacts/stories/bug-314-leading-zeros-hdr.md \
   '# Leading zeros

**Sprint:** 007'
mk _bmad-output/planning-artifacts/stories/bug-315-zero-hdr.md \
   '# Zero

**Sprint:** 0'

# SUFFIXED SPRINT -- RECOVERABLE BY NEITHER, DELIBERATELY. `131b` is not spellable as the reserved
# slot `^s[0-9]+$`, so truncating it to s131 would merge a distinct sprint into another's slot on a
# guess. It is REFUSED, which is the one place this fix trades a placement for a refusal.
mk _bmad-output/planning-artifacts/stories/story-131b-1-hr12-retirement.md "suffixed sprint, no header"
# THE `--follow` BOUND. THE SUBJECT MUST BE A *LEGACY* PATH OR THE ARM CANNOT REACH THE MECHANISM.
# The first cut of this seed put the file under `s121/stories/`, which is conforming -- and
# `legacy_story()` returns FALSE for it (measured: `not-leg`, against a control of `LEGACY` for
# `bug-mobile-layout.md`), so the file skipped the recovery block entirely and the arm passed
# without ever reaching the code it claims to guard. An adversary proved it by adding a real
# `git log --follow` third channel to the shipping script; the arm still passed.
#
# So the subject sits in a LEGACY `stories/` directory with NO `s<N>/` above it, giving no sprint
# in its name and no header. It reaches the recovery, both channels decline, and it must be
# REFUSED. Its history (below) carries a crossing rename out of a sprint-71 path, so a recovery
# that consulted `git log --follow` would find 71 and PLACE it -- which is what the arm detects.
#
# IT IS BORN HERE, ON THE SPRINT-71 PATH, and moved to `stories/` in a LATER commit. That ordering
# is the whole hazard: `git log` on the final path then starts at the MOVE, while `--follow`
# crosses it and reaches this creation commit. Created directly at the `stories/` path instead --
# which is what the first cut did -- both readings return the same oldest commit and the control
# below correctly fails, because there is no crossing to inherit.
mk _bmad-output/planning-artifacts/s71-cooldown-sentinel-followbait.md "no sprint in name, no header"
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

# --- A PRIOR MIGRATION, IN THE HISTORY, SO THE `--follow` HAZARD IS REAL -------
#
# The follow-bait file was committed under a sprint-71 path; this second commit moves it into the
# LEGACY `stories/` directory, exactly as an earlier reorganisation would have. `git log --follow`
# on its current path now crosses this rename and reports the commit that created the s71 path, so
# a recovery reading history would answer 71 for a file whose own name and body say nothing.
# Reproduced on the reference consumer, on `s121/stories/story-2-sg1-cooldown-sentinel-fix.md`,
# which `--follow` traces back to a Sprint 71 commit while the tree says 121.
#
# Seeding the rename rather than asserting the absence of a history channel is what makes the arm
# able to fail: without this commit `--follow` and `git log` agree and a history-reading recovery
# would pass. The subject is legacy, so it REACHES the recovery block -- which the first cut of
# this seed did not, and that is the defect this shape fixes.
mkdir -p _bmad-output/planning-artifacts/stories
git mv _bmad-output/planning-artifacts/s71-cooldown-sentinel-followbait.md \
       _bmad-output/planning-artifacts/stories/cooldown-sentinel-followbait.md
git commit -q -m "an earlier reorganisation moved it off its sprint-71 path into legacy stories/"

printf '%s\n' "$WORK"
