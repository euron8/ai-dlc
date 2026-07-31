#!/usr/bin/env bash
# seed.sh — a REAL distribution git repo with THREE commits, and a consumer whose
# entries are held FIXED while the span moves under them.
#
# WHY THIS SEED IS NOT layer-qualifier-grain's. That fixture varies the ENTRY inside
# ONE span: three entries, three anchors, three verdicts from a single base..theirs.
# Every verdict there is attributable to something the entry declares, so a classifier
# that keyed on anything entry-intrinsic — the id, the basename, merely WHETHER
# `extends:` is present — reproduces its whole result table without ever reading a
# section body. This seed varies the SPAN instead. The same two entries are classified
# twice, and they SWAP verdicts. Nothing entry-intrinsic can produce that; only reading
# the declared anchor's bytes at both refs can.
#
#   BASE   demo.md defines Alpha, Beta, Gamma
#   MID    ONLY Beta's body is rewritten     -> Alpha's span is byte-identical BASE..MID
#   TIP    ONLY Alpha's body is rewritten    -> Beta's span is byte-identical MID..TIP
#
# The file therefore CHANGES in both spans, which is what makes silence something a
# classifier has to earn rather than fall into. Gamma never moves in either span, so
# neither span is a whole-file rewrite and "the anchor did not move" is a statement
# about the anchor rather than about the file being mostly static.
#
# demo.md is RENDERED from one template rather than written out three times. Written
# three times, the claim "only Beta moved between BASE and MID" would rest on three
# heredocs agreeing character for character, and a stray edit to Alpha's prose in the
# second copy would silently turn the load-bearing assertion into a tautology — the
# anchored entry would go quiet because its span had changed in a way the fixture no
# longer noticed it had. One template with two substituted bodies makes that
# unrepresentable: the untouched sections are the same bytes by construction.
#
# Prints the sandbox root on stdout.
set -euo pipefail

ROOT="$(mktemp -d)"
DIST="$ROOT/dist"
CONS="$ROOT/consumer"

SKILL_REL="core/skills/ai-dlc"
mkdir -p "$DIST/$SKILL_REL/steps"
git -C "$DIST" init -q
git -C "$DIST" config user.email f@x
git -C "$DIST" config user.name f

demo_md() { # demo_md <alpha-body> <beta-body>
  cat <<EOF
# Demo step

## Alpha gate

$1

## Beta review

$2

## Gamma notes

Gamma's body. It never changes in either span, so neither span is a whole-file
rewrite and "the declared anchor did not move" stays a claim about the anchor.
EOF
}

A_BASE="Alpha's body at BASE. Unchanged through MID: this is the span the load-bearing
assertion anchors to in run 1, and the span that MOVES in run 2."
A_TIP="Alpha's body at TIP — REWRITTEN. The same entry that went quiet in run 1 must
report here, because now it is its OWN declared span that moved."
B_BASE="Beta's body at BASE. This is the body that moves in run 1, which is what makes
run 1's file-level change real."
B_MID="Beta's body at MID — REWRITTEN. Unchanged through TIP, so in run 2 this entry is
the one that must stay quiet while its sibling reports."

demo_md "$A_BASE" "$B_BASE" > "$DIST/$SKILL_REL/steps/demo.md"
git -C "$DIST" add -A
git -C "$DIST" commit -qm "base"

demo_md "$A_BASE" "$B_MID" > "$DIST/$SKILL_REL/steps/demo.md"
git -C "$DIST" add -A
git -C "$DIST" commit -qm "mid: rewrite Beta only"

demo_md "$A_TIP" "$B_MID" > "$DIST/$SKILL_REL/steps/demo.md"
git -C "$DIST" add -A
git -C "$DIST" commit -qm "tip: rewrite Alpha only"

# ---------------------------------------------------------------------------
# The consumer. Core files are the BASE copies, as an installed tree would have.
# ---------------------------------------------------------------------------
CSKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$CSKILL/extensions" "$CSKILL/overrides" "$CSKILL/steps" "$CONS/.claude/team-roles"
git -C "$DIST" show "HEAD~2:$SKILL_REL/steps/demo.md" > "$CSKILL/steps/demo.md"

ext() { # ext <basename> <number> <frontmatter-body>
  local n="$1" num="$2"; shift 2
  { printf -- '---\n'; printf '%s\n' "$1"; printf -- '---\n\n'
    printf '### %s. [ext:%s] Consumer entry.\n\nBody.\n' "$num" "$n"
  } > "$CSKILL/extensions/$n.md"
}

# THE SUBJECT. Held fixed across both runs. Anchored to the section that is
# byte-identical BASE..MID and rewritten MID..TIP.
ext anchored-alpha 903 "kind: step-domain
hooks: steps/demo.md
id: anchored-alpha
push_candidate: false
extends: '#Alpha gate'"

# THE SIBLING. Also held fixed, anchored to the OTHER section — rewritten BASE..MID
# and byte-identical MID..TIP. It is the diagonal: in each run exactly one of these
# two reports, and which one it is inverts between the runs.
ext anchored-beta 904 "kind: step-domain
hooks: steps/demo.md
id: anchored-beta
push_candidate: false
extends: '#Beta review'"

# THE LIVENESS WITNESS. Declares no anchor, so its drift subject stays the whole file
# and it must report in BOTH runs. Every EXTENSION-OK asserted above is an absence of
# a drift row, and a classifier that had stopped emitting anything would satisfy all
# of them; this entry is what says the run happened at all — and, separately, that the
# narrowing was not applied to an entry that never asked for it.
ext unanchored 905 "kind: step-domain
hooks: steps/demo.md
id: unanchored
push_candidate: false"


# THE CONSUMER IS A GIT REPO, because a real one always is. E16 reads an entry's id
# history from the consumer's own git to decide whether an id it no longer defines was
# RETIRED or merely never there, and on a tree with no git it REFUSES — correctly, and
# loudly, since an unreadable history and a clean one are otherwise the same output. A
# seed without git would make this fixture assert "a well-formed consumer lints clean"
# against a shape no consumer has, and the refusal would read as a regression.
for _c in "$CONS"; do
  [ -d "$_c" ] || continue
  git init -q "$_c"
  git -C "$_c" config user.email fixture@example.invalid
  git -C "$_c" config user.name fixture
  git -C "$_c" config commit.gpgsign false
  git -C "$_c" add -A
  GIT_AUTHOR_DATE='2026-01-02T00:00:00+00:00' GIT_COMMITTER_DATE='2026-01-02T00:00:00+00:00' \
    git -C "$_c" -c user.email=fixture@example.invalid -c user.name=fixture \
      commit -q --no-verify -m 'seed: the consumer layer as authored'
done

printf '%s\n' "$ROOT"
