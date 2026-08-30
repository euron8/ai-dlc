#!/usr/bin/env bash
# seed.sh — write REAL transcripts, REAL git probe trees and REAL project layouts to disk.
# Prints the sandbox root on stdout.
#
# THE PROBE TREES ARE THE POINT OF THIS FILE.
#
# `handoff-resume-guard`'s drive() builds its project dir with a bare `mktemp -d`. That is not
# a git repo, so `git rev-parse --git-dir` fails inside ai-dlc-continue.sh and PUSH_OK is
# pinned at 1 for every case it will ever run; and it has no `steps/` directory, so
# ai-dlc-recover.sh's handoff override could never name a readable file. Push and recover
# assertions written against that shape pass VACUOUSLY. The trees below are real
# repositories and real installed layouts.
set -euo pipefail

# SCRUB GIT'S AMBIENT REPO POINTERS FIRST, IN THIS FILE, NOT ONLY IN THE CALLER.
#
# MEASURED, ON THIS REPOSITORY, WHILE BUILDING THIS FIXTURE. `GIT_DIR` takes precedence over
# `-C <dir>`, so with one exported every `git -C "$d"` below operates on the CALLER'S repo
# while reading as though it operates on a probe. It wrote four keys into that repo's local
# config -- including `core.hooksPath`, which DISARMED the pre-push gate -- staged a file from
# the temp directory and committed it to the checked-out branch. Nothing errored until the
# second `mkrepo` found nothing to commit. This file is executable on its own and prints a
# path, so it will be run by hand; the caller's scrub cannot be its protection.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE 2>/dev/null || true

ROOT="$(mktemp -d)"

# ---------------------------------------------------------------------------
# Transcripts (ai-dlc-continue.sh — a Stop event)
# ---------------------------------------------------------------------------
# One transcript = one JSONL file of {message:{role,content}} lines, which is the shape
# ai-dlc-continue.sh's jq actually reads.
mk() { # mk <name> <user-text> <assistant-text>
  local f="$ROOT/$1.jsonl"
  jq -nc --arg u "$2" '{message:{role:"user",content:$u}}'      >  "$f"
  jq -nc --arg a "$3" '{message:{role:"assistant",content:$a}}' >> "$f"
  printf '%s' "$f"
}

FENCE='```'
ASST_OK="Snapshot finalized.

${FENCE}
----
/ai-dlc resume
----
${FENCE}
"

# (1) A FULLY COMPLIANT handoff turn, transcript-triggered: the request is the last user
#     message and the assistant emitted the mandated resume block. Every push-arm case
#     drives this one, so the resume arm and the teammate arm are both satisfied and the
#     ONLY thing that can vary the verdict is the state of the git tree. A case carrying its
#     own transcript could differ on the resume block and the verdict would not say which
#     arm produced it.
mk req_ok "hand off the sprint" "$ASST_OK" > "$ROOT/.t_req_ok"

# (2) The same request with NO resume block. This is the POSITIVE CONTROL for every ALLOW
#     case: an allow is an empty stdout, and a hook that crashed on load is also an empty
#     stdout. Driving this in the same tree and requiring a BLOCK is what separates them.
mk req_noblk "hand off the sprint" \
  "Done. Everything is committed and the snapshot is updated." > "$ROOT/.t_req_noblk"

# (3) The on-disk battery's driver. The last user message is deliberately NOT a handoff
#     request -- it is the real phrase from the reported episode, asked AFTER the fact -- so
#     the transcript path of Check 0 is inert and any BLOCK must have come from disk. The
#     assistant emits no resume block, so once the on-disk trigger fires the resume arm is
#     what produces the BLOCK.
mk quiet "did the full handoff steps run" \
  "Yes. The snapshot is finalized and the teammates were swept." > "$ROOT/.t_quiet"

# ---------------------------------------------------------------------------
# Git probe trees (ai-dlc-continue.sh — the push arm)
# ---------------------------------------------------------------------------
# `core.hooksPath` is pointed at a directory that does not exist so a machine with a global
# hooksPath cannot run someone else's hooks inside a probe; user.email/user.name/gpgsign are
# set locally so these work on a clean machine with no git identity configured.
mkrepo() { # mkrepo <dir>
  local d="$1"
  git -c init.defaultBranch=main init -q "$d"
  # AND PROVE THE REPO IS WHERE WE ASKED FOR IT, BEFORE THE FIRST WRITE. The scrub above is a
  # precondition and this is the assertion that it held: `config`, `add` and `commit` are the
  # calls that did the damage, so the check has to sit ahead of all three. It makes a
  # hijacked target unconstructible rather than merely detectable afterwards.
  local want got
  want="$(cd "$d" && pwd -P)/.git"
  got="$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null || true)"
  if [ "$got" != "$want" ]; then
    echo "SEED ABORT: git resolved '$d' to git-dir '${got:-<none>}', not '$want'." >&2
    echo "  Something is redirecting git away from the probe tree, and the next command would" >&2
    echo "  write config and commit into that other repository. Refusing to continue." >&2
    exit 2
  fi
  git -C "$d" config user.email "fixture@ai-dlc.invalid"
  git -C "$d" config user.name  "ai-dlc fixture"
  git -C "$d" config commit.gpgsign false
  git -C "$d" config core.hooksPath "$ROOT/no-such-hooks-dir"
  echo seed > "$d/seed.txt"
  git -C "$d" add seed.txt
  git -C "$d" commit -q --no-verify -m "seed"
}

attach() { # attach <dir> <bare-remote>
  git -c init.defaultBranch=main init -q --bare "$2"
  git -C "$1" remote add origin "$2"
}

# (a) NOT A GIT REPO AT ALL. `steps/handoff.md` step 3 cannot be asserted here at all, and
#     the arm is fail-safe: it must preserve today's behaviour rather than invent a finding.
mkdir -p "$ROOT/proj-nogit"

# (b) A git repo with NO REMOTE. The environmental narrowing: step 3 names "no remote
#     configured" as one of three causes it forgives, and a repo with no remote can never
#     satisfy a push assertion, so blocking here would wedge every handoff in a local tree.
mkrepo "$ROOT/proj-noremote"

# (c) A remote exists and the branch has NEVER been pushed. This is v0.434.0's exact state:
#     a bare `git push` cannot succeed on it, which is why step 3 prescribes `-u origin HEAD`.
mkrepo "$ROOT/proj-unpushed"
attach "$ROOT/proj-unpushed" "$ROOT/remote-unpushed.git"

# (d) Pushed, upstream set, zero commits ahead. The satisfied state.
mkrepo "$ROOT/proj-pushed"
attach "$ROOT/proj-pushed" "$ROOT/remote-pushed.git"
git -C "$ROOT/proj-pushed" push -q --no-verify -u origin HEAD

# (e) Pushed once, then one more commit. The commits this handoff just made exist only on
#     this machine -- offline and protected-branch both land here too.
mkrepo "$ROOT/proj-ahead"
attach "$ROOT/proj-ahead" "$ROOT/remote-ahead.git"
git -C "$ROOT/proj-ahead" push -q --no-verify -u origin HEAD
echo more > "$ROOT/proj-ahead/more.txt"
git -C "$ROOT/proj-ahead" add more.txt
git -C "$ROOT/proj-ahead" commit -q --no-verify -m "unpushed work"

# The on-disk battery's tree. NOT a git repo, deliberately: the push arm is then skipped
# entirely and the only thing that can move those verdicts is the state under _bmad-output.
# It carries a steps/ directory because key 1's marker is produced by driving
# ai-dlc-handoff-entry.sh with a Read of a REAL handoff.md, never by touching the file here.
mkdir -p "$ROOT/proj-disk/core/skills/ai-dlc/steps" "$ROOT/proj-disk/_bmad-output"
printf '# Handoff Procedure\n\nThe five steps.\n' > "$ROOT/proj-disk/core/skills/ai-dlc/steps/handoff.md"
printf '# implementation\n\nThe step the handoff interrupted.\n' > "$ROOT/proj-disk/core/skills/ai-dlc/steps/implementation.md"

# The entry-hook battery's own tree, kept separate so removing its _bmad-output directory --
# which one case requires -- cannot disturb any other battery's state.
mkdir -p "$ROOT/proj-entry/core/skills/ai-dlc/steps" \
         "$ROOT/proj-entry/.claude/skills/ai-dlc/steps" \
         "$ROOT/proj-entry/docs" "$ROOT/proj-entry/_bmad-output"
printf '# Handoff Procedure\n' > "$ROOT/proj-entry/core/skills/ai-dlc/steps/handoff.md"
printf '# implementation\n'    > "$ROOT/proj-entry/core/skills/ai-dlc/steps/implementation.md"
printf '# Handoff Procedure\n' > "$ROOT/proj-entry/.claude/skills/ai-dlc/steps/handoff.md"
# A consumer's OWN unrelated handoff.md, which the hook's path match must not claim.
printf '# our team handoff notes\n' > "$ROOT/proj-entry/docs/handoff.md"

# ---------------------------------------------------------------------------
# Installed-layout project trees (ai-dlc-recover.sh — the step-file override)
# ---------------------------------------------------------------------------
# The override resolves `<root>/<cand>/handoff.md` against two candidate roots, in order:
# `.claude/skills/ai-dlc/steps` (a consumer) then `core/skills/ai-dlc/steps` (the
# distribution). A tree carrying only one of them exercises only one branch, and
# `consumer-boundary.md` is explicit that a path resolving in this tree can resolve nowhere
# in an installed one -- so both are built and both are asserted.
mklayout() { # mklayout <dir> <steps-subdir>
  mkdir -p "$1/$2" "$1/_bmad-output"
  printf '# implementation\n\nThe step the handoff interrupted.\n' > "$1/$2/implementation.md"
  printf '# Handoff Procedure\n\nThe five steps.\n'                > "$1/$2/handoff.md"
}
mklayout "$ROOT/proj-recover"        "core/skills/ai-dlc/steps"
mklayout "$ROOT/proj-recover-claude" ".claude/skills/ai-dlc/steps"

# ---------------------------------------------------------------------------
# Snapshots
# ---------------------------------------------------------------------------
# All three carry the same `current_step_file`, so the ONLY thing that varies between them is
# the handoff record. A snapshot differing in two places could not say which one moved the
# verdict.
snap() { # snap <outfile> <extra-section-body>
  cat > "$1" <<EOF
# Pipeline Snapshot

## Pipeline Position
current_step_file: implementation.md

## Sprint Context
sprint_id: 307

## Recent Activity
- gate 3 in progress

## Open Items
$2

## Locked Decisions
- none

## In-Flight Teammates

## Context Reminders
context_reminders_sent: none
EOF
}

# (i) No handoff record of any kind.
snap "$ROOT/snap-plain.md" "- none"

# ---------------------------------------------------------------------------
# KEY 2's SEEDS, AND WHY THE ORDER OF THESE TWO IS THE LESSON
# ---------------------------------------------------------------------------
# Key 2 is the only key with NO PRODUCER IN THIS TREE. A lead writes the record by hand while
# improvising a handoff; nothing shipped constructs it. So the first grammar's shape could only
# come from the reader -- it was written from the same imagination as its own test case, and it
# matched everything that was invented for it and nothing a consumer had actually written.
# Measured: it scored 0 against the reference consumer's live record, against a control of 1
# against a synthetic heading, isolated by prepending `## ` to that one line and nothing else.
#
# The producer-derived seed therefore comes FIRST here and is the primary one. Both are kept,
# and each says which side of that line it is on.

# (ii) PRIMARY, AND THE ONLY SEED IN THIS FIXTURE WITH A REAL-WORLD PRODUCER. Transcribed
#      verbatim from the reference consumer's live `_bmad-output/pipeline-snapshot.md`: a BOLD
#      PARAGRAPH LEAD-IN with no `#` at any level. It is the only instance of this record that
#      exists anywhere, and a grammar that demands a markdown heading misses it.
#
#      HARD-CODED ON PURPOSE. The fixture must not read that consumer's tree at runtime -- it
#      ships, and on a consumer that path does not exist, so a fixture that resolved it there
#      would silently degrade to asserting nothing on every tree but this machine's.
snap "$ROOT/snap-bold.md" "- none

**HANDOFF POINT (operator-requested, mid gate-3 for story-307-1).** Gate-3 evidence-gathering
was in progress when the operator asked for a handoff."

# (iii) SECONDARY, AND READER-DERIVED. A markdown heading is the shape the grammar was first
#       written for. Nothing has ever been observed writing one. Kept because it is a legal
#       spelling the key must still accept, but it is NOT the seed that guards the fix -- a
#       battery carrying only this one passes against the grammar that shipped broken.
snap "$ROOT/snap-heading.md" "- none

## HANDOFF POINT (operator-requested, mid gate-3 for story-307-1)

Gate-3 evidence-gathering was in progress when the operator asked for a handoff."

# (iv) A MENTION of the record MID-LINE, which is discussion and not a record. Producer-derived:
#      the reference consumer's push-candidate ledger discusses the section in prose in exactly
#      this shape, and the library's own header cites the same case. This is what the start-of-
#      line anchor exists to exclude.
snap "$ROOT/snap-mention.md" "- the HANDOFF POINT section records what the handoff actually reached, and
  this snapshot does not have one yet"

mkdir -p "$ROOT/logs"

printf '%s\n' "$ROOT"
