#!/usr/bin/env bash
# merge-review-shards.sh -- join a sharded gate-1 code review, or a sharded gate-2 QA
# validation, into the ONE review file Check 1 reads.
#
# USAGE
#   merge-review-shards.sh <shard-dir> --gate code-review|qa --out <review-file>
#   merge-review-shards.sh <shard-dir> --gate code-review|qa --check-shard <file>.md [--findings <n>]
#   merge-review-shards.sh --read-verdict <file> --gate code-review|qa
#
#   --check-shard runs the merge's OWN per-shard check (one function, `check_shard`, which the
#   merge calls for every shard) over ONE shard, after the same manifest/map re-derivation and
#   cross-group read, so its ordinal range, CROSS_FIRST and part/cross role are the merge's. It
#   skips the shard-set staging: the key comes from the target's basename alone, and a target
#   outside <shard-dir> (`--mark`'s pre-write snapshot) is keyed the same way. It covers every
#   per-shard rule in SHARD GRAMMAR, VERDICT BACKING, the marker's count, (d)'s key check and the LEGACY rule
#   (SEAT-COMPLETE), and the content seal for a target inside <shard-dir> checked without
#   --findings (with --findings, the caller is --mark, which runs the seal itself). The owner-duplicate
#   check reads the owner's sibling only when that sibling ends in a marker whose `sha=` reads
#   sealed; otherwise it is skipped and the full merge is the backstop. NOT covered: set
#   completeness, the hand-over join, conservation and the Check 1 read-back.
#   `--findings <n>` holds the shard to n as its marker count (in place of any marker it carries,
#   and with (d) and the LEGACY rule not applied): the count `--mark` is about to write.
#   Where the full merge's first refusal is a per-shard refusal of that shard, --check-shard's
#   REFUSED line is byte-equal to it on the same input; a set-level refusal has no counterpart.
#   Owner-duplicate refusals are COLLECTED (OWNER TAILS): --check-shard prints every one its target
#   carries, then any later per-shard refusal of it, and exits 2 before SHARD-OK, so `--mark` (which
#   keys on the exit) never seals a shard carrying a duplicate.
#
#   Per gate:                 code-review                      qa
#     role file               code-reviewer.md                 qa.md
#     <shard-dir> basename    <idx>-code-review-<sha12>[-p<M>] <idx>-qa-validation-<sha12>[-p<M>]
#     <review-file> basename  <idx>-code-review[-p<M>].md      <idx>-qa-validation[-p<M>].md
#     worst-of order          BLOCKED > NEEDS_REWORK > APPROVED  NEEDS_REWORK > PASS
#     merged title            # Code Review: <idx> (merged...)   # QA Validation: <idx> (merged...)
#   Any other --gate is REFUSED.
#
#   <shard-dir> lives under `docs/reviews/s<N>/shards/`, written in the frozen dev worktree:
#   `.manifest` (by `partition-review-diff.sh --map ... --shard-dir`), one `<ordinal>.md` per
#   part, and the CROSS SHARDS (below). <sha12> is the first 12 characters of the manifest's
#   frozen sha.
#
# THE CROSS SHARDS. Two shapes, both accepted at ANY K, never mixed. The DISPATCHED shape is ONE
#   cross reviewer reading every part, writing `cross.md`. The GROUPED shape (the dispatch before
#   that, still merged) is one shard per row of `partition-document.sh --cross-groups <K>` (K =
#   the part count of the re-derived map), named `cross-<g>.md`, and `cross.md` iff that table has
#   exactly one row (G=1, i.e. K=2). The table is read from that one speller, never restated here.
#   A grouped set must be complete; a partial `cross-<g>` set, a `cross-<g>` the table does not
#   print, `cross.md` beside any `cross-<g>.md`, and `cross-<g>.md` when G=1 are each REFUSED.
#   Every reader below takes the DELIVERED shape (`cross_shape`): a lone `cross.md` is the one
#   cross key, its execution owner and the owner of every cross finding, and the title counts it
#   as one shard.
#   THE OWNER RULE. The groups overlap, so each cross finding citing two or more parts has one
#   owner, the shard `partition-document.sh --cross-owner <K> <cited ordinals>` names (`cross`
#   when the set delivered one cross shard). A cross reviewer reads the WHOLE diff and may cite
#   any part, so a finding outside
#   its owner's shard is accepted, and REFUSED only when the owner's shard carries a finding
#   citing the IDENTICAL set -- the one case the two are the same finding.
#   THE FIRST CROSS SHARD (`cross` when one was delivered, else `cross-1`) is the EXECUTION owner: it alone
#   runs in the frozen worktree, which nothing else may mutate -- the one canonical suite run and
#   every handed-over replay -- and under --gate qa it alone carries the per-AC table and the
#   deferred record. Every other cross shard executes nothing and reports interaction findings
#   only. The mutation-RED replays are NOT the execution owner's: under BOTH gates each part
#   shard replays the ones anchored in its part, in its own detached worktree at the frozen sha,
#   and hands over (HAND-OVERS below) only an AC that worktree cannot bring to a GREEN baseline.
#   A hand-over is defined by that failure, so a per-group copy of the worktree would only repeat
#   it; the execution owner runs it in the frozen worktree, and that residue stays on one agent.
#   SEAT-COMPLETE. A shard dispatched under the early-write brief ends, as its LAST NON-BLANK
#   line, in `seat-complete: <step> <seat> <shard> key=<k> sha=<hex> findings=<n>`, written once
#   as its final write by `wait-for-deliverable.sh --mark`. <shard> and <k> are the shard's own KEY,
#   its basename without `.md` (`03`, `cross`, `cross-2`). A marker carrying `key=` is held to it:
#   exactly one `key=`, and both <k> and <shard> equal the file's key under ordinal normalisation,
#   else REFUSED ("re-dispatch the reviewer for that shard"). THE LEGACY RULE: a marker WITHOUT
#   `key=` is accepted only when the frozen tree predates the key= engine -- the manifest's sha,
#   read in the manifest's worktree (`git --no-replace-objects`, `rev-parse --verify` first) at
#   `scripts/ai-dlc/wait-for-deliverable.sh` then `core/scripts/wait-for-deliverable.sh`, is present
#   and does NOT carry the line `# MARK-KEY-WRITER v1`. Then stdout carries
#       LEGACY: <file> accepted without key= only because reviewed sha <full sha> predates the key= engine
#   The sentinel present, the commit unreadable, or the file in neither layout is REFUSED, never
#   acquitted. A shard ending in no marker at all is not held to (d) or the legacy rule, but the
#   engine at the frozen sha is still read for it: the sentinel present takes the NON-legacy seal
#   below (a row required), so stripping every marker from a set does not reopen the legacy window.
#   THE CONTENT SEAL. Every shard is passed to the sibling `content-seal.sh --review-shard <file>`,
#   with `--legacy` unless its marker carries `key=`. Exit 0 is accepted; exit 3 (no seal row) is
#   accepted only under `--legacy`; exit 1 is REFUSED with its text; exit 4 (`SEAL-UNAVAILABLE`: jq
#   absent, the shard not placeable in a git worktree, a ledger that does not parse) is REFUSED
#   `[owner: lead]` naming the environment, never a re-dispatch; any other exit is REFUSED.
#   So a key= shard with no seal row is refused, and a legacy or unmarked shard is still compared
#   wherever a row exists. Its limit: a legacy shard, or an unmarked one whose frozen sha's engine
#   lacks the sentinel or cannot be read, with NO row is merged unsealed.
#   If ANY shard in the directory ends in that line, every shard must,
#   and one that does not is REFUSED as unfinished; a marker whose `findings=<n>` differs from
#   the findings parsed in its shard is REFUSED as truncated. Keyed on the
#   marker's presence in the directory, as merge-adversarial-shards.sh keys it: a directory whose
#   shards predate the brief carries no marker anywhere and merges as before. Its limit: a set in
#   which NO shard has finished carries no marker either, so this is the belt and
#   `wait-for-deliverable.sh --complete` at the join is the braces. The marker line is dropped
#   from the merged body. The seal reader --check-shard uses (has_marker, content_hash, seal_body,
#   seal_of) is a COPY of wait-for-deliverable.sh's, which executes on load and cannot be sourced;
#   the copies are byte-identical to it today, and that duplication is owed a fixture byte-compare.
#
# VERDICT BACKING. A shard's verdict must be backed by its OWN findings, read off the merge's own
#   --gate (never inferred from the path). It is a per-shard rule inside check_shard(), so the merge,
#   --check-shard and `--mark` (through --check-shard --findings) all apply it:
#     THE SEVERITY BOUNDARY (qa). The judging rule is lifted from the CURRENT qa.md, but WHETHER a
#       shard is held to it is read off a record the shard did not write: qa.md as installed at the
#       manifest's frozen sha, read in the manifest's worktree (`git --no-replace-objects show
#       <sha>:.claude/team-roles/qa.md`, then `core/team-roles/qa.md`), run through the same
#       container lift. No container there: the shard is held to COUNT-ONLY, stdout carries
#           LEGACY: <shard> held to the count-only QA rule only because the frozen sha <sha>'s <path> declares no severity containers
#       and the merge goes on (exit 0 when nothing else refuses). Any container there, or that qa.md
#       UNREADABLE (no commit, or the file in neither layout): the severity rule applies -- an
#       unreadable record never acquits, as the key= rule's unreadable engine never does. The merge
#       and --check-shard (and so --mark) re-derive the manifest and apply it; --check-serial reads
#       no manifest and applies no severity rule.
#     SEVERITY MODE (code-review always; qa when qa.md's template declares the three containers)
#       NEEDS_REWORK, and under code-review BLOCKED, needs at least one `#### ` finding under the
#       Critical or Important container; APPROVED or PASS carries NO finding under Critical
#       (Important under it is allowed). A `#### ` under `## Findings` with no `### ` container
#       above it in that section is REFUSED, under both gates, as unclassed.
#     COUNT-ONLY MODE (qa, when qa.md's template declares NO container: the qa.md a consumer has
#       installed until the reconcile merge delivers the template)
#       NEEDS_REWORK needs at least one `#### ` finding under `## Findings`, in any container or
#       none; PASS has no condition. stdout carries, once, before any other line,
#           LEGACY: <qa.md path> declares no severity containers; QA verdict backing is count-only
#   The container names are LIFTED, by ONE function for both gates, from the role file's `## Findings`
#   template after its first `## Verdict` -- the first word of each `### ` heading, matched
#   case-insensitively by prefix -- never retyped. code-reviewer.md must declare exactly three; qa.md
#   exactly three or none; any other count is REFUSED. A NEEDS_REWORK/BLOCKED refusal names both
#   exits, owner first: set the gate's best verdict and let the owning shard carry the finding,
#   otherwise file the finding here with a parts set this shard may own; in severity mode it also
#   names the one-edit remedy, moving a finding the shard already carries under Critical or Important.
#   An APPROVED/PASS-with-Critical refusal names both: downgrade the finding with evidence, or set
#   NEEDS_REWORK. Each takes `[owner: <key>]`, the shard's own.
#
# FAIL ROWS (--gate qa, set-level, in the merge; --check-shard has no set to read, and --check-serial
#   applies them to its one file). The per-AC
#   table is the first cross shard's Acceptance Criteria section (a `## ` or `### ` heading whose
#   text begins with "Acceptance Criteria", case-insensitively -- the grammar the section count above
#   uses -- to the next `## ` or `### ` heading), read outside fences. Its result column is
#   the one whose header cell reads `Result` or `Verdict` (case-insensitive, trimmed, `*` stripped),
#   its AC column the one headed `AC`, else the first; a table with no such result column is not
#   read. A data row FAILS when its result cell, trimmed with `*` and backticks stripped, begins with
#   `FAIL` or `FAILED` (case-insensitive) followed by a non-letter or nothing: `FAIL`, `**FAIL**`,
#   `FAILED` and `FAIL (no RED)` do, a FAIL in any other column does not. The row's AC id is the
#   leading token (`[A-Za-z0-9][A-Za-z0-9._-]*`) of its AC cell, `*` and backticks stripped.
#   A finding NAMES the AC when the id appears with no letter, digit or `.` beside it (`AC-4.1` does
#   not name `AC-4`), on any line of the finding but its `parts:`, `handover:` and `handover-run:`
#   lines.
#   For each FAIL row, two refusals, each `[owner: <the first cross shard>]` and each naming the
#   correct-the-row exit beside its own:
#     the merged verdict (after any forced NEEDS_REWORK) is not NEEDS_REWORK -> REFUSED: set
#       NEEDS_REWORK with a backing finding naming the AC;
#     no `#### ` finding of ANY shard names the AC id as a whole token, in its heading or its body
#       (`AC1` is not named by `AC10`), outside fences -> REFUSED as an orphan FAIL row. Its remedy is
#       satisfiable under the owner rule: the finding goes in the shard that owns its cause -- a part
#       shard under its own ordinal, a cross shard under a set it owns, or the owning group's shard
#       names the AC in the finding it already carries.
#
# CHECK-SERIAL. `merge-review-shards.sh --check-serial <file> --gate code-review|qa` runs, over ONE
#   serial review or validation file, the merge's own Check 1 read-back (check1_read: the derived
#   pattern, the value read the Check 1 way) under gate 3's count policy, no stricter: at least one
#   match, every match reading the SAME value (two matches reading one value are one verdict), and
#   that value a member of the gate's lifted verdict set. So `Verdict: PASS (all ACs)` and `PASS.`
#   under `## Verdict` pass; `PASS-pending`, no match, and two different values are refused. Under
#   --gate qa it then applies the FAIL ROWS rules to the file's own table, verdict and findings. It
#   does NOT apply VERDICT BACKING (a per-shard rule). stdout `SERIAL-OK: <file> verdict=<v>`, exit
#   0; else one `REFUSED: ... [owner: serial]` line, exit 2 -- the serial seat's own file, fixed and
#   checked again. It reads no shard directory and no manifest. The MERGE keeps its stricter count:
#   the assembled file carries exactly one match.
#
# READ-VERDICT. `merge-review-shards.sh --read-verdict <file> --gate code-review|qa` is a READ, not a seat
#   check: the same check1_read and the same lifted verdict set as --check-serial, over ONE review file,
#   serial or merged, and nothing else. At least one match of Check 1's pattern, every match reading the
#   SAME value, and that value a member of the gate's lifted set: stdout `VERDICT: <file> verdict=<v>`,
#   exit 0. Otherwise one `REFUSED: ... [owner: serial]` line, exit 2. It applies NO advisor line, FAIL
#   ROWS, canonical-run, Class or backing rule (those bind the seat's own file, and a merged review
#   carries one advisor line per shard, which --check-serial refuses), and it writes nothing. Its caller
#   is gate-transition.sh's gate-2 Rule A, reading the latest gate-1 re-review's verdict.
#   THE LEAD'S RE-RUN. `--check-serial <file> --gate qa [--story <f>] --lead-range <seat base> <go-signal>` is the
#   same check run by the lead on its own inputs (implementation.md, "The lead re-runs a serial QA's check"), so a
#   seat's SERIAL-OK binds nothing it chose. The base is the `dispatch:` line of the story's LEAD RECORD,
#   `<git common dir>/ai-dlc/stories/s<N>-<story-index>` (<story-index> by rec_idx_ok: any index the lead dispatches
#   under, letters and slugs included, never `/`, `.` or a leading `-`; one file per story, plain `key: value` lines, every reader
#   and writer through lead_record_path / lead_record_put / lead_record_get), named from the review's own verified
#   slot and index and written once at dev dispatch by `--record-dispatch s<N>-<story-index> <sha>` (a second call
#   keeps the first value, `RECORD-KEPT:`). With a record, <seat base> is never read. With none (a story dispatched
#   before the record existed, or a missed write), stdout carries exactly one
#       LEGACY-UNRECORDED: s<N>-<idx> has no dispatch record at <path>; checked over the seat base <b> as 0.994.0 did ...
#   and the check runs over <seat base> as the seat's own --range run does, STORY-BIND included. REFUSED, [owner:
#   serial]: a go-signal sha that does not descend from the record's dispatch sha, a review path whose PHYSICAL directory is not exactly
#   <its repository>/docs/reviews/s<N>/ with <N> read from the directory as spelled (a relative `./<file>` spells no
#   slot, and a symlink spelling another sprint's slot differs from its target). THE REVIEWED SHA: when qa.md AT
#   THE BASE prescribes the serial line (RSHA_SENTINEL), the file carries exactly one column-0 `reviewed-sha:` outside
#   fences (parse_shard's reader) whose whole value is the go-signal sha; otherwise stdout carries
#       LEGACY: reviewed-sha not checked: <qa.md read> prescribes no column-0 `reviewed-sha: <full go-signal sha>` line
#   Under --range and --lead-range alike, qa.md is read at the BASE (tracked, `.claude/team-roles/` then
#   `core/team-roles/`, else on disk), never at the frozen sha and never off the working tree when the base tracks it,
#   so a commit inside the range cannot move the rule the review is held to.
#
# CANONICAL RUN (--gate qa only; the merge over CROSS_FIRST's file, the execution owner's, and
#   --check-serial over its one file). Read only when the verdict (merged after any forced
#   NEEDS_REWORK, or the serial file's) is PASS: a NEEDS_REWORK with no counts is a legitimate early
#   REJECT (qa.md Handoff Evidence Precondition). Labels are record-only-diff.sh's LABEL grammar
#   (column 0 or after one `- `/`* ` bullet, outside fences, the first one read):
#       Canonical run: <invocation and working directory>
#       Canonical result: <the run's summary line, with counts>
#   REFUSED, [owner: <CROSS_FIRST>] in the merge and [owner: serial] in --check-serial: a PASS with no
#   `Canonical run:` line; a run whose invocation narrows the collection (record-only-diff.sh
#   RUN-FILTER: `-k` in every spelling, `--deselect`, `-t`, `-run`, `--ignore`, `--lf`, `-x --ff`, a
#   file, node-id or test-file-suffix argument to any runner, an argument after `--`, and a `-m`
#   marker or path argument the project's `docs/coding-conventions.md` does not declare canonical;
#   with no conventions file `-m` is accepted and a path refused); no `Canonical result:` line; a
#   result carrying no `<n> passed|failed|collected|error(s)` count, or reading `not finished`, `in
#   progress` or `still running`. Counts on any other line (a RED replay, a part's targeted run) are
#   not read.
#   THE EXEMPTION. A `Canonical run:` value that is not a run (record-only-diff.sh RUN-SHAPE, given
#   the conventions file so its declared canonical command counts as a runner) is a no-run claim, however it is spelled (`none,
#   <reason>`, `N/A`, `TBD`, empty). It is accepted, with no result line, only when
#   `record-only-diff.sh paths <story> <base> <frozen>` exits 0: the same record-only partition the
#   dev's full-collection line is held to, decided over the WHOLE story on every pass. <story> is
#   `--story <f>` (repo-relative). In the merge <base> <frozen> is the manifest's base and sha, read
#   in the manifest's worktree; the gate-2 partition's base is gate 1's base on every pass, so that
#   range is the whole story, and the merge refuses `--range`. In --check-serial the seat passes
#   `--range <b> <f>` (no manifest exists), read in the serial file's own repository, and <b> is held
#   to a gate-1 base's shape: an ancestor of <f>, at which the story is absent or carries no
#   `Full-collection run:` line and is not `review` or `done` (record-only-diff.sh STORY-BASE); the
#   seat passes <f> as story-base's third operand, so a story that is no file at <b> or at <f> (a typo,
#   a directory, a path inside .git/) is UNEVALUABLE and REFUSED rather than read as absent. A
#   claimed exemption with no --story or no range is REFUSED; a bare `none` is REFUSED.
#   THE WAIVER. After every STORY-BIND check below and before `paths`, `record-only-diff.sh waiver <story> <base>
#   <value>` decides `none, <AC-id> waives it`: exit 0 (the story AT <base>, never at <frozen>, carries
#   `- **<AC-id>** waives the canonical run` under `## Canonical-run waivers`) accepts with no result line, 1 falls
#   through to `paths`, any other exit REFUSES. It is honoured only over a LEAD-WRITTEN base: the merge's base when the
#   lead's partition record named it, or --lead-range over a recorded dispatch. Under a seat's --range, an unrecorded
#   --lead-range or an unrecorded merge, a value the test reads WAIVED is REFUSED naming --record-dispatch (serial) or
#   --record-partition (merge).
#   `--story` must be the story file sprint-status lists at the frozen sha, and its basename must
#   carry the review's index (`story-<idx>.md`, or `story-<idx>-<slug>.md` whose slug does not open
#   with a digit, so index `1` never names `story-1-2-y.md`) OR the view's row naming it at the frozen
#   sha must be keyed under that index (THE ROW STEM RULE, BL-956: the key with the REVIEW's sprint
#   stripped from the slot after `story-` only, sprint-status.sh stem-names, is `story-<idx>`, so
#   `6-qa-validation.md` binds `story-1-6-<slug>.md` under row `story-<N>-6`, and `story-3-3` in sprint 3
#   names index 3), else STORY-BIND REFUSES. The one-story and history checks below count an entry under
#   the index by the same two rules (stem_rows); and on the no-run exemption claim, when --story binds by
#   the row alone, the history check holds --story's pairs to the index from --base to frozen (every row a
#   version of the view in that window pairs with --story's basename must be keyed under the index), so a
#   range that re-keys the view cannot bind another story's file, and read its waiver, under this index,
#   while a re-key the lead made in planning, before --base, binds. The review's
#   <idx> is `-`-joined components, each digits with at most one trailing lower-case letter (`1-1`,
#   `2-3a`), so a review named for a slug (`1-1-z-qa-validation.md`) carries no index; or a letter-led index (`B1`,
#   `B-1`, `DASH`), any text with no `/`, `.` or whitespace, bound the same way: the index is compared with --story's
#   basename and the view's entries LITERALLY (no pattern is built from it), so an index the view lists under no story
#   is REFUSED by the row and basename checks. Empty and a leading `-` carry no index. And --story must
#   be the ONLY story under that index: every entry of the implementation view at <base> and at
#   <frozen> (`sprint-status.sh list-stories --ref`) whose declared `file:` or resolved file passes the
#   same index rule is REFUSED unless it IS --story, WHATEVER its status; and a view that gives no
#   answer at either ref (absent, no `sprint:`, a `stories:` block that is not ok) is REFUSED, never
#   read as "nothing listed". A range that adds a fresh story under the index, and lists it under
#   another key or by repointing the row's `file:`, still has the real story named at <base>; a base
#   one record-only commit made by deleting the view, stripping the row's status, naming the story
#   twice or renaming its file (the row keeps its `file:`) is refused the same way. And every `file:`
#   value that a commit of the implementation view added or removed between the commit that created
#   --story's directory and <frozen> (`sprint-status.sh view-history`, which owns the view's path and
#   grammar) refuses when it is under the index, in this sprint and not --story, so a base whose row
#   was deleted or repointed off the index still has the real story named in the view's history; a
#   history that cannot be read is REFUSED, and a key-only row (no `file:`) is not seen. THE SPRINT is the review's own:
#   <N> of its lead-assigned slot `docs/reviews/s<N>/` (qa.md; in the merge, the shard directory's
#   `docs/reviews/s<N>/shards/` parent), and a claimed exemption on a review path carrying no `s<N>` is REFUSED. The
#   view's `sprint:` must read <N> at <base> and at <frozen>, and --story must sit in stories_dir(<N>), so a seat
#   that rolls the view to another sprint cannot move the directory the walk starts from. That walk starts at
#   stories_dir(<N>)'s creation, chosen by ancestry and refused when ambiguous, and refuses a shallow repository; at
#   that creation commit only, a `file:` value its parent's view (an earlier sprint) resolves into that sprint's own
#   stories directory (sprint-status.sh resolve_story_file) is the earlier sprint's story retired by the roll and is
#   not named. Replace objects and grafts are ignored by every git call that reads it, sprint-status.sh is called
#   with the seat's AI_DLC_SPRINT_STATUS_SCHEMA and AI_DLC_PROJECT_ROOT unset (so it reads the schema its own install
#   ships), the merge unsets git's GIT_DIR and GIT_WORK_TREE family at entry, and --check-serial reads <N> from the
#   review's logical directory, so a relative review path names its slot. A slot is named exactly `s<N>`, `s` then
#   digits and nothing else (`s2x`, `s2.Ab12` carry no sprint). Measured on
#   the reference consumer's 109 bound QA reviews (s317-s320), each driven as a none claim with its
#   bound story: 0 STORY-BIND refusals at every recorded, recovered or derived gate-1 base, the same
#   109 verdicts as the binding before this rule.
#   LEGACY. The merge holds a set to this rule only when qa.md AS INSTALLED at the manifest's frozen
#   sha (`.claude/team-roles/qa.md`, then `core/team-roles/qa.md`, read in the manifest's worktree),
#   or, when neither is TRACKED there, the on-disk copy in that worktree (the one QA read), carries
#   the phrase in CANON_SENTINEL; installed without it, stdout carries
#       LEGACY: canonical-run lines not checked: <path> prescribes no column-0 `Canonical run:` label
#   and the rule is skipped. Neither tracked nor on disk is held to the rule, and each refusal names
#   both paths tried. --check-serial reads no manifest and keys on the qa.md it already reads
#   (ROLE_MD), the same way, except that ROLE_MD lives under a root the environment may name
#   (AI_DLC_PROJECT_ROOT, CLAUDE_PROJECT_DIR), so it can hold the rule but never skip it: LEGACY also
#   needs the review's own repository (its git toplevel) to carry a qa.md, read at the range's base as THE LEAD'S
#   RE-RUN reads it (on disk when no range is given), either layout, that lacks the phrase; one carrying it, or none,
#   holds the rule and every refusal says why. Under --lead-range with qa.md a tracked blob at the dispatch base, that
#   blob alone decides, as the merge decides from qa.md at its sha; sr_era is the one decision, shared with THE RUN
#   RECORD's era.
#   OVERRIDES. A consumer `overrides/` entry shadowing qa.md's `Validation Checklist` (the section
#   holding the sentinel) is not composed here: no existing program composes a role file with its
#   overrides. After the pull the rule holds while QA reads the override's checklist, so the
#   reconcile's HARD-OVERRIDE-DRIFT-SECTION adjudication adopts the two `Canonical run` lines into
#   the override; until it does, the first PASS refuses with a message naming that fix.
#   STORY-BIND ON THE RUN BRANCH. The index rule and the view-row rule above also hold a `Canonical run:` that IS a
#   run, whenever --story and a frozen sha are given (the merge always has its manifest's sha), so a run claim never
#   carries another story's --story. The one-story, history and record-only rules stay the exemption's own.
#   THE PARTITION RECORD. `--record-partition <qa shard-dir>`, run by the lead right after the gate-2 partition and
#   before any QA is dispatched, writes the story's `partition-base`, `partition-sha` (the manifest's) and `qa-era`
#   (`held` when qa.md as installed AT THE BASE, tracked first, else on disk in the manifest's worktree at that moment,
#   carries CANON_SENTINEL or is unreadable; else `legacy`) as `key: value` lines in the lead's story record,
#   `<git common dir>/ai-dlc/stories/s<N>-<idx>` (lead_record_path), named by the shard directory's physical
#   `docs/reviews/s<N>/shards/` parent and its <idx>. Each key carries the shard directory's basename
#   (`partition-sha.<idx>-qa-validation-<sha12>[-p<M>]`), so every pass has its own and a later pass, recorded or not,
#   is never compared with an earlier one's; re-recording one shard directory replaces its three keys and no other. The
#   --gate qa merge reads them back from the same name: .manifest's base and sha must equal the record's, else
#   REFUSED [owner: lead] naming the re-partition (implementation.md Gate-2 dispatch) and a re-dispatch; and LEGACY
#   (above) also needs the record's era to be `legacy`, so a range that strips, deletes or rewrites qa.md, tracked or
#   on disk, holds the rule. A shard directory with no recorded keys (partitioned before 0.995.0, or re-partitioned
#   without --record-partition) merges as before, with one `LEGACY-UNRECORDED: story <idx> (s<N>-<idx>) ...` line. The record lives outside the story
#   worktree and outside base..sha, in the .git the seat shares, so a deliberate overwrite is not defended.
#   THE RUN RECORD (BL-905). `--record-run <qa shard-dir> [--dir <subdir>] -- <invocation...>` or `--record-run
#   <serial review file> --frozen <go-signal sha> [--dir <subdir>] -- <invocation...>`,
#   run by the execution owner (cross / cross-1, or the serial seat) from the lead checkout, is the canonical run
#   itself: the record name s<N>-<idx> and the frozen sha come from the shard directory (shard_slot, .manifest's
#   `worktree` and `sha`) or the review path (docs/reviews/s<N>/ in its repository) and --frozen, the full go-signal
#   sha taken literally (nothing records it before the run, and the worktree's own HEAD would compare with itself); it
#   REFUSES when the worktree's HEAD is not the frozen sha (untracked files never refuse) and a --dir that is absolute
#   or carries `..`; it runs the invocation in <worktree>/<dir>, never refuses on its exit, and takes the summary line
#   (OSC, SGR and CR stripped; vitest's last `Test Files` line joined to the next `Tests` line with `; `, else
#   pytest's last `=== ... in <n>s` session line, else the last line carrying the count grammar above that is no
#   per-test line -- no `::`, no ` PASSED`/` FAILED` with a `[ NN%]` tail; `=` runs and blanks trimmed). No summary
#   line writes nothing and refuses.
#   It writes run.<key>.sha, .exit, .dir, .invocation and .result (key: the shard directory's or review file's
#   basename; the latest run wins; the invocation is the argv as one shell line, rr_quote, every argument that is not a
#   bare word single-quoted, so `-m 'a and b'` stays the marker the conventions declare) and prints `RECORDED-RESULT: <line>` and `RECORDED-RUN: <invocation> (in <dir>,
#   sha <sha>)`. The binding (run_bind) sits on canon_gate's RUN branch after the result's count check; a no-run
#   claim never reaches it. ERA: held when qa.md prescribes RUN_SENTINEL -- in the merge, the partition record's
#   run-era (written by --record-partition from qa.md at the base, unreadable held), else qa.md at the manifest's
#   base (neither readable: legacy); in --check-serial, held when ROLE_MD carries it (it can hold, never acquit) or
#   the review repository's qa.md at the range's base or on disk (SR_QA_AT) does -- except under --lead-range with
#   qa.md a tracked blob at the dispatch base, where that blob alone decides, as the merge's base read does. Unheld: one `LEGACY: canonical-run record not checked: <qa.md read> prescribes no <RUN_SENTINEL> line`
#   and the merge proceeds. Held: the story record must carry a run at the frozen sha (the manifest's, or the
#   go-signal sha, else the review repository's HEAD) -- this pass's key first, then any earlier pass's key at the
#   same sha, then (with --story only) an earlier pass's run whose change to the frozen sha is record-only by
#   `record-only-diff.sh paths` (exit 0 only; 1 and 2 refuse) -- else REFUSED naming the shas found, the
#   predicate's lines and the --record-run remedy. The recorded invocation is held to RUN-FILTER; the `Canonical
#   run:` invocation (the span RUN-FILTER reads, `record-only-diff.sh run-span`) must equal the recorded invocation,
#   and the `Canonical result:` value the recorded result, each pair with backticks and `=` removed and whitespace
#   collapsed, else REFUSED naming both. RESIDUAL: a seat that records a stub (`--record-run -- printf '5561 passed'`)
#   and copies its invocation is not stopped; binding the invocation to the conventions' declared one would.
#
# OWNER TAILS. Every REFUSED line ends in `[owner: <key>...]`, naming the shard whose FILE must
#   change; the lead re-dispatches that seat with the line verbatim and never edits its shard.
#   A per-shard refusal names that shard. The owner-duplicate refusal names the NON-owning shard,
#   and it is the one refusal that does not stop the run: every duplicate in every shard is printed,
#   each in the same `REFUSED: ... [owner: <key>]` form, the checks go on, and the run exits 2 after
#   the per-shard loop. A later per-shard refusal still prints and exits at once, after the
#   duplicates already printed; an earlier shard's per-shard refusal stops the run before any later
#   duplicate is read. So one run can print several REFUSED lines, two of them naming one shard: the
#   lead re-dispatches each named seat with EVERY REFUSED line that names it.
#   A missing shard names its key; an unfinished shard in a marked set names it. A duplicate key
#   names both filenames. The hand-over join names both the part and CROSS_FIRST. A Check 1
#   multi-match names every shard whose body matches the pattern outside a fence, else `lead`.
#   A bad name, a non-regular file, and every set-level input (manifest, map, pass marker, --out,
#   role and gate files, conservation, an absent content-seal.sh) take `lead`.
#   THE PASS MARKER. Pass 1 carries none; pass M (M a decimal integer >= 2, no leading zero)
#   appends `-p<M>` to BOTH the shard directory and the review file. The merge REFUSES unless
#   the two markers are equal and --out's basename is the gate's review-file shape for the
#   directory's <idx>: a shard directory partitioned for one pass is never merged into
#   another pass's review file. `-p1` is refused -- pass 1 has no marker.
#
# WHY IT EXISTS. A sharded review is N part reviewers plus one cross reviewer per cross group; Check 1 in
#   gate-validation.md keeps reading exactly one review file. This is the deterministic JOIN
#   that writes it. Shard verdicts are ADVISORY inputs; the merged verdict is RECOMPUTED as the
#   worst of them in the gate's order above. Never a count, never the cross shard alone,
#   never the last one read. Under either gate an unmet hand-over replay (HAND-OVERS below)
#   also raises it to at least NEEDS_REWORK.
#
# THE PART SET IS RE-DERIVED, NEVER READ OFF THE DIRECTORY. The manifest's worktree, base, sha,
#   min-files and max-parts are handed back to partition-review-diff.sh --map (sibling of this
#   file); its map must byte-match the manifest's `part` lines. A listing of the shard directory
#   is the set of shards that ARRIVED, not the set that was owed.
#
# SHARD GRAMMAR (the role file's "As a shard" clause cites this; it does not restate it).
#   Outside ``` / ~~~ fences, at column 0, each shard carries EXACTLY ONE of each:
#       reviewed-sha: <full frozen sha>        must equal the manifest's sha (40 or 64 hex
#                                              characters -- never a go-signal's short sha)
#       shard-verdict: APPROVED | NEEDS_REWORK | BLOCKED     (--gate code-review)
#       shard-verdict: PASS | NEEDS_REWORK                   (--gate qa)
#   A shard carries NO line Check 1's grep matches. Shapes that DO match, and so must not appear
#   in a shard outside a fence: any heading whose text is or ends in `Verdict` or `Decision`
#   (`## Verdict`, `### QA Decision`), a label `Verdict:` or `<Word> verdict: ...` (`QA verdict:
#   PASS`), and the same in bold (`**Verdict:** PASS`). A pipe-led table row does not match, so
#   QA's per-AC results are a table (`| AC | Result | Expected | Got |`, qa.md's shape; a column
#   headed `Verdict` is read the same way as `Result`), one row per AC. The merge does not
#   police that per shard; it counts Check 1's matches over the ASSEMBLED file and refuses
#   unless there is exactly one, which is the property that matters.
#   --gate qa ONLY, counted outside fences, case-insensitively, on a `## ` or `### ` heading
#   whose text BEGINS with the section name, whatever follows it -- `## Acceptance Criteria:`,
#   `##  acceptance criteria`, `### Deferred ACs` and `## Deferred / operator-owned` all count.
#   A `#### ` heading never counts: that level is a FINDING, and a finding titled
#   `#### Acceptance criteria ...` is a finding, not a second per-AC section:
#       the FIRST cross shard carries EXACTLY ONE `## Acceptance Criteria` (the story's per-AC
#       table) and AT MOST ONE `## Deferred ACs` (every deferred-AC discharge predicate); a part
#       shard and every other cross shard carry NEITHER. The closing writer reads both from the
#       merged file, so a second copy, or one in another shard, is a second answer to one question.
#   A FINDING is a `#### ` heading inside the shard's `## Findings` section (to the next `## `),
#   under the template's `### Critical / Important / Suggestions` containers. Each finding
#   carries EXACTLY ONE line
#       parts: <ordinal>[, <ordinal>...]
#   before the next heading. A part shard cites ONLY its own ordinal; a cross shard cites two
#   or more DISTINCT ordinals (the owner rule above). Ordinals compare numerically
#   (`1` and `01` are one ordinal).
#   Every shard carries a `## Findings` section, even an empty one; a shard without one is
#   REFUSED. A `parts:` line anywhere else -- under another `## ` section, before the first
#   `#### `, indented, or behind a list bullet (`- parts: 3`) -- is REFUSED, never skipped: a
#   finding written as a bullet or under `## Critical Issues` would otherwise merge uncited.
#   HAND-OVERS, BOTH GATES (a code-review part shard replays its part's mutation-REDs exactly as
#   a QA part shard does, so the grammar, the declared count and the join are one). A part shard
#   whose mutation-RED replay for an AC cannot reach a GREEN baseline hands that AC to the FIRST
#   cross shard (the execution owner: the replay runs in the frozen worktree) with a finding
#   (under `### Important`, never `### Deferred...`) carrying its one `parts: <own ordinal>` line
#   and EXACTLY ONE column-0 line
#       handover: <AC-id>
#   The first cross shard runs each handed-over replay and records it inside a `#### ` finding as
#   one column-0 line per replay
#       handover-run: <ordinal> <AC-id> RED | GREEN-SURVIVED | NO-BASELINE
#   A cross finding carrying `handover-run:` lines cites exactly the ordinals those lines name,
#   one or more, and is exempt from the owner rule; every other cross finding still cites two or
#   more. <AC-id> is one token of
#   letters, digits, `.`, `_`, `-` that BEGINS with a letter or digit. Both lines count only
#   outside fences. REFUSED: a `handover:` line in any cross shard; a `handover-run:` line in a
#   part shard or in any cross shard but the first; either line outside a `#### ` finding,
#   indented, bulleted or in another case; a
#   MALFORMED hand-over line anywhere -- the label decorated (`**handover:**`, `*handover*:`),
#   quoted (`` `handover: AC7` ``, `> handover: AC7`), hyphenated (`hand-over:`) or, at column 0,
#   missing its colon (`handover AC7`, `handover - AC7`); a `handover:` line naming more than one
#   AC, or none; two `handover:` lines in one finding; the
#   same hand-over twice; and any hand-over (keyed `<ordinal> <AC-id>`) not matched by exactly
#   one `handover-run:`, or a `handover-run:` matching no hand-over.
#   THE DECLARED COUNT. Every PART shard carries, beside `reviewed-sha:` and `shard-verdict:`,
#   EXACTLY ONE column-0 line outside fences
#       handovers: <n>
#   with <n> a non-negative decimal integer (`0` when it handed nothing over) equal to the number
#   of `handover:` lines the merge PARSED in that shard. REFUSED: a part shard with no such line or
#   two, a non-integer <n>, an <n> that differs from the parsed count, and any `handovers:` line in
#   any cross shard. This is the fail-closed half: a hand-over spelled any way the parser does not
#   read is not counted, so it disagrees with its writer's declaration whatever the spelling. The
#   malformed-line refusals above stay, for the precise message on the common forms; the no-colon
#   form there takes any run of non-alphanumerics as its separator (` - `, an em or en dash, `=`,
#   `->`), ends at the AC-id's token boundary rather than the end of the line, and both it and the
#   decorated form allow a numbered-list prefix (`1. `). A hand-over is not a verdict
#   of its own, but its replay is a HARD GATE: a `handover-run:` result of GREEN-SURVIVED (the
#   mutation did not turn the test RED) or NO-BASELINE (the cross shard could not reach GREEN
#   either) raises the merged verdict to NEEDS_REWORK whatever the shard verdicts say, and never
#   lowers one: under --gate code-review a BLOCKED shard keeps the merge BLOCKED.
#   EXACTLY ONCE. Each hand-over is keyed `<ordinal> <AC-id>` and joined in both directions: a
#   hand-over no replay names, a replay no hand-over names, the same hand-over handed over twice and
#   the same replay recorded twice are each REFUSED, so every handed-over replay is accounted for
#   exactly once, counted, across the part shards and the execution owner.
#   THE ADVISOR LINE, BOTH GATES. Every shard, part and cross, carries outside fences EXACTLY ONE
#   column-0 line
#       advisor: called | unavailable
#   `called` when an advisor call returned a result; `unavailable` when the tool was absent, or every
#   call errored or was rate-limited (remediator.md's meanings). It is checked PER SHARD, never on the
#   merged file, which carries one per delivered shard. Under --check-serial the review file carries one.
#   REFUSED in every era: two such lines; a value outside the two (trailing blanks and CR tolerated, as
#   join-remediator-shards.sh tolerates them); and the label indented, bulleted (the remediator's own
#   `- advisor: called` is the near-miss), decorated (`**advisor:**`) or numbered. The label is matched
#   in lower case only, so a prose `Advisor: ...` sentence is neither the line nor a malformed one.
#   THE ERA. A shard with NO such line is refused only when the gate's role file (qa.md under --gate qa,
#   code-reviewer.md under --gate code-review) carries the sentinel ADVISOR_SENTINEL as the shards were
#   briefed on it: read with `git show` at the manifest's frozen sha, consumer layout first, the way
#   the SEVERITY BOUNDARY reads qa.md. The reference consumer (graph) tracks both role files, so the
#   frozen-sha read is the live path there. A role file tracked at the sha without the sentinel prints
#   one `LEGACY: advisor: line not checked: <path> prescribes no column-0 \`advisor:\` label` line and
#   accepts the absence; a file unreadable at the sha holds it. A role file UNTRACKED at the sha falls
#   back to the on-disk installed copy in the manifest's worktree, as the CANONICAL RUN arm does: without
#   the sentinel, LEGACY; with it, the absence is REFUSED naming the fallback (`untracked at <sha>, read
#   on disk`) and its remedy, commit `.claude/team-roles/`, because the on-disk copy may postdate the
#   shards. --check-serial keys on the INSTALLED role file, as its canonical-run branch does.
#   THE CLASS LINE, BOTH GATES. A `#### ` finding under a Critical or Important container in
#   `## Findings` carries at most one column-0 line outside fences
#       Class: <one member of the set the gate's role file's template declares>
#   The set is LIFTED from the gate's installed role file (code-reviewer.md under --gate
#   code-review, qa.md under --gate qa: ROLE_MD) by CLASS_SET_AWK, byte-identical to the
#   renderer's, never retyped; I129 holds qa.md's set equal to code-reviewer.md's and both gates
#   to this one lift. REFUSED: a present value outside that set, and two `Class:` lines in one
#   finding. A finding with NO `Class:` line is ACCEPTED: old-engine findings carry none, and an
#   unclassed finding is fail-closed downstream (partition-review-diff.sh --route sends the next
#   pass to a full re-review or re-validation), so an omission costs a pass and never a miss. An
#   installed role file declaring no `Class:` template line (a consumer between the engine pull
#   and the reconcile merge, at either gate) declares no set, and no `Class:` line is checked.
#   Checked per shard by the merge and --check-shard, and on the one file by --check-serial.
#   THE FILES LINE, BOTH GATES, read by the same pass as THE CLASS LINE (so a role file declaring no
#   Class set checks neither). A CODE or TEST finding carries at most one column-0 line outside fences
#       Files: <repo-relative path>[, <repo-relative path>...]
#   REFUSED: a `Files:` line on a finding whose Class is not CODE or TEST (none included); two in one
#   finding; an empty list; an entry carrying a backtick, `:`, `,` or a blank, a leading `/` or `./`,
#   or a `..` component; and, under the merge and --check-shard, an entry that is neither tracked at
#   the manifest's frozen sha nor a path <base>..<sha> changes (a deleted file is allowed). Matched
#   whole, never by basename, and never read off HEAD. --check-serial has no frozen sha and runs the
#   syntactic refusals only; a path naming no file there moves that file between the narrowed set and
#   its residue, both of which are reviewed. A CODE or TEST finding with NO `Files:` line is ACCEPTED:
#   partition-review-diff.sh --narrow answers FULL on it, so an omission costs a narrowing, never a miss.
#   THE NARROWED MANIFEST. A manifest carrying `narrow-from\t<repo-relative path>` is re-derived with
#   `--narrow-from <that path>`, resolved under the shard directory's work tree. A narrowed manifest
#   whose narrow-from line is dropped is re-derived flagless, and is REFUSED by the map cmp whenever that
#   map differs from its own part lines; when the residue is empty the two partitions are identical
#   and the merge accepts it.
#
# CHECK 1'S PATTERN IS DERIVED, NEVER RETYPED. It is lifted from gate-validation.md's own
#   `grep -inE '<pattern>' <review-file>` directive the way core/fixtures/gate-verdict-grep-shape
#   lifts it, and the lift must find exactly ONE directive. The verdict set is lifted from the
#   gate's role file's `## Verdict` template line by the expression render-vocabulary-index.sh
#   uses, and must be exactly the values the gate's ranking above orders -- code-reviewer.md's
#   three, qa.md's two -- so an added value refuses rather than being ranked by accident. Both
#   files are located under the project root (AI_DLC_PROJECT_ROOT, else a walk up from this
#   file, else CLAUDE_PROJECT_DIR, else a walk up from the cwd), consumer layout first.
#
# THE OUTPUT. The gate's merged title, a summary naming the range and shard count, the
#   `## Verdict` heading with the worst-of value on the next line (the template's own shape), a
#   table of shard verdicts, the part map, then every shard body in ordinal order, the cross
#   shards last in group order (`## Shard: cross` for one delivered cross shard,
#   `## Shard: cross-<g> (<ordinals>)` for each group otherwise).
#   CONSERVATION: every finding heading of every shard appears in the output, counted.
#   The assembled file must match Check 1's pattern exactly once, and the value read back Check
#   1's way (the value rule gate-validation.md Check 1 states) must equal the recomputed verdict.
#
# EXIT
#   0  merged (stdout `MERGED: ...`), or <review-file> already exists byte-identical (`UNCHANGED:`);
#      under --check-shard, stdout `SHARD-OK: <path> findings=<n>`. Either may be preceded by
#      `LEGACY: ...` lines: one per legacy marker (SEAT-COMPLETE), and, under --gate qa over a qa.md
#      declaring no severity container, one `LEGACY: <qa.md> declares no severity containers; QA
#      verdict backing is count-only` line first (VERDICT BACKING).
#   2  REFUSED (stdout one `REFUSED: <reason> [owner: <key>...]` line, or several when owner
#      duplicates were collected: OWNER TAILS) -- nothing written at <review-file>.
#      An existing <review-file> that differs is refused: a review the gate may already have read
#      is never silently overwritten. --check-shard writes nothing in either case.
#   --check-serial: 0 with stdout `SERIAL-OK: <file> verdict=<v>` (under --gate qa possibly preceded
#      by the container-mode LEGACY line), 2 with one `REFUSED: ... [owner: serial]`; it writes nothing.
#   REQUIRES jq on PATH and every shard inside a git worktree: the content seal reads its rows
#   with jq from the ledger it locates through git. Without them each shard's seal is
#   SEAL-UNAVAILABLE and the merge is REFUSED `[owner: lead]` -- an environment the lead repairs,
#   never a shard a reviewer rewrites.
set -u

refuse() { printf 'REFUSED: %s [owner: %s]\n' "$*" "$OWNER"; exit 2; }

refuse_to() { OWNER="$1"; shift; refuse "$*${CG_NOTE:-}"; }

# A sibling script asked in process: <sibling path> <its entry function> <its arguments>. The sibling is sourced
# (its BASH_SOURCE guard returns before it runs) and its entry called inside a subshell, so its `exit`, its
# EXIT trap and every variable it sets end with the call; stdin, stdout and stderr are the caller's redirections.
mrs_sib() { ( _sib_s="$1"; _sib_f="$2"; shift 2; . "$_sib_s" && "$_sib_f" "$@" ); }

collect_dup() { printf 'REFUSED: %s [owner: %s]\n' "$*" "$OWNER"; DUP_N=$((DUP_N + 1)); }

# ---- the project root and the two files the merge derives from --------------------------
# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

# THE SEVERITY CONTAINERS, lifted from the same template the verdict set is (the role file's
# `## Findings` block after its first `## Verdict`, to the next `## `), never retyped: the first word
# of each `### ` heading, in order -- the first is the Critical class, the second the Important
# class, the third the class an APPROVED or PASS shard downgrades to. ONE lift for both gates.
# code-reviewer.md declares three. qa.md declares three, or -- the qa.md a consumer runs this engine
# against from pull step 3 until the reconcile merge -- none: then SEV is 0, every container classes
# "other", and the QA rule is count-only (header: VERDICT BACKING).
lift_containers() { # <role file> -> the first word of each `### ` heading in its ## Findings template
  awk '/^## Verdict$/ { v = 1; next }
       v && /^## Findings[ \t]*$/ { on = 1; next }
       on && /^## / { exit }
       on && /^### / { s = $0; sub(/^###[ \t]+/, "", s); sub(/[^A-Za-z].*$/, "", s); print s }' "$1" \
    | tr '\n' ' '
}

rank() {
  case "$GATE:$1" in
    code-review:APPROVED) echo 1 ;;
    code-review:NEEDS_REWORK) echo 2 ;;
    code-review:BLOCKED) echo 3 ;;
    qa:PASS) echo 1 ;;
    qa:NEEDS_REWORK) echo 2 ;;
    *) echo 0 ;;
  esac
}

# ---- THE CHECK 1 READ-BACK, ONE value reader for the merge and --check-serial; each caller applies its
# own count policy (the merge: exactly one match; --check-serial: every match reads the same value,
# gate-validation.md Check 1's "two matches reading the same value are one verdict").
# check1_read <file> -> C1N, the count of Check 1's pattern matches (grep -ciE, the gate's own count);
# C1V, the value the FIRST match reads; C1D, the number of DISTINCT values the matches read; C1L, those
# values, blank-separated. The value is read Check 1's way: after the `:` on the matched line, else at
# the next non-blank line; spaces and `*` skipped; the run of capitals and underscores there, when the
# character after it is the end of the line, a space, `.`, `,`, `(`, `)` or `*`; otherwise the whole
# whitespace-delimited token (so `PASS-pending` reads `PASS-pending`, outside every set).
check1_read() {
  C1N="$(grep -ciE -- "$PAT" "$1")" || C1N=0
  C1V=""; C1D=0; C1L=""
  [ "$C1N" -ge 1 ] || return 0
  c1_out_="$(PAT_="$PAT" awk '
    function val(s,   r, nx) {
      sub(/^[ \t*]+/, "", s)
      if (match(s, /^[A-Z_]+/)) { r = substr(s, 1, RLENGTH); nx = substr(s, RLENGTH + 1, 1)
        if (nx == "" || index(" \t.,()*", nx) > 0) return r }
      if (match(s, /^[^ \t]+/)) return substr(s, 1, RLENGTH)
      return "" }
    { L[NR] = $0 }
    END {
      p = tolower(ENVIRON["PAT_"])
      for (i = 1; i <= NR; i++) {
        if (tolower(L[i]) !~ p) continue
        if (index(L[i], ":") > 0) s = substr(L[i], index(L[i], ":") + 1)
        else { s = ""; for (j = i + 1; j <= NR; j++) if (L[j] ~ /[^ \t]/) { s = L[j]; break } }
        v = val(s); if (v == "") v = "<none>"
        if (first == "") first = v
        if (!(v in seen)) { seen[v] = 1; nd++; lst = lst (lst == "" ? "" : " ") v }
      }
      printf "%d\t%s\t%s\n", nd + 0, first, lst }' "$1")" \
    || refuse_to lead "reading the verdict value of $1 did not run (awk failed); repair the environment in the lead checkout and check again"
  C1D="${c1_out_%%	*}"; c1_out_="${c1_out_#*	}"; C1V="${c1_out_%%	*}"; C1L="${c1_out_#*	}"
  [ "$C1D" -ge 1 ] 2>/dev/null \
    || refuse_to lead "reading the verdict value of $1 returned no value for $C1N match(es); the value reader is broken, not the file"
}

# ---- FAIL ROWS (header). fail_rows <file> -> "<line> <AC-id>" per data row of the file's
# `## Acceptance Criteria` table(s), outside fences, whose result column reads FAIL; `-` for an AC
# cell carrying no id. Each table's header row names its columns; a table with no `Result` or
# `Verdict` column is not read.
fail_rows() {
  awk '
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
    !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    f { next }
    /^##?#?[ \t]/ { lc = tolower($0); sec = (lc ~ /^###?[ \t]+acceptance criteria/); hdr = 0; next }
    !sec { next }
    !/^[ \t]*\|/ { hdr = 0; next }
    { n = split($0, c, "|")
      if (!hdr) { hdr = 1; rc = 0; ac = 0
        for (i = 2; i <= n; i++) { h = c[i]; gsub(/[*]/, "", h); gsub(/^[ \t]+|[ \t]+$/, "", h); h = tolower(h)
          if (!rc && (h == "result" || h == "verdict")) rc = i
          if (!ac && h == "ac") ac = i }
        if (!ac) ac = 2
        next }
      if ($0 ~ /^[ \t]*\|[ \t:|-]*$/ || !rc || rc > n) next
      v = c[rc]; gsub(/[*`]/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v); v = tolower(v)
      if (v !~ /^fail(ed)?([^a-z]|$)/) next
      a = c[ac]; gsub(/[*`]/, "", a); sub(/^[ \t]+/, "", a)
      if (match(a, /^[A-Za-z0-9][A-Za-z0-9._-]*/)) a = substr(a, 1, RLENGTH); else a = "-"
      print NR, a }' "$1"
}

# ac_named <AC-id> <file> -> 0 when a `#### ` finding under the file's `## Findings`, outside fences,
# names the id as a WHOLE token (no letter, digit or `.` on either side, so `AC-4.1` does not name
# `AC-4`), in its heading or its body. Its `parts:`, `handover:` and `handover-run:` lines are the
# merge's own grammar, not prose about the AC, and are not read.
ac_named() {
  AC_="$1" awk '
    function tok(s, o,   i, p, q) {
      while ((i = index(s, o)) > 0) {
        p = (i > 1) ? substr(s, i - 1, 1) : ""; q = substr(s, i + length(o), 1)
        if (p !~ /[A-Za-z0-9.]/ && q !~ /[A-Za-z0-9.]/) return 1
        s = substr(s, i + 1) }
      return 0 }
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
    !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    f { next }
    /^## / { inf = ($0 ~ /^## Findings[ \t]*$/); inx = 0; next }
    /^#/ { inx = (inf && $0 ~ /^#### /) }
    /^(parts|handover|handover-run):/ { next }
    inx && tok($0, ENVIRON["AC_"]) { hit = 1; exit }
    END { exit !hit }' "$2"
}

# fail_gate <table file> <owner> <list of files whose findings may name the AC>: the FAIL ROWS rules
# over <table file>'s per-AC table, against the verdict in WORST. One function for the merge and
# --check-serial.
fail_gate() {
  fg_x_="$1"; fg_o_="$2"; fg_l_="$3"
  fail_rows "$fg_x_" > "$T/failrows" || refuse_to "$fg_o_" "reading the per-AC table of $fg_x_ did not run"
  while read -r fg_n_ fg_a_; do
    [ "$fg_a_" != "-" ] \
      || refuse_to "$fg_o_" "$fg_x_:$fg_n_ is a per-AC row reading FAIL whose AC cell carries no AC id; begin the cell with the AC's id"
    [ "$WORST" = NEEDS_REWORK ] \
      || refuse_to "$fg_o_" "$fg_x_:$fg_n_ per-AC row $fg_a_ reads FAIL but the QA verdict is $WORST; a FAIL row is an unmet acceptance criterion. Either set NEEDS_REWORK in the file that owns the failure, backed by a '#### ' finding naming $fg_a_ under '### ${CRIT_NAME:-Critical}' or '### ${IMP_NAME:-Important}', or correct the row with the evidence that $fg_a_ passes"
    fg_hit_=0
    while IFS= read -r fg_f_; do ac_named "$fg_a_" "$fg_f_" && { fg_hit_=1; break; }; done < "$fg_l_"
    [ "$fg_hit_" = 1 ] \
      || refuse_to "$fg_o_" "$fg_x_:$fg_n_ per-AC row $fg_a_ reads FAIL but no '#### ' finding names $fg_a_; a FAIL row is backed by a finding. File one naming $fg_a_ where its cause is owned -- a part shard under its own ordinal, a cross shard under a 'parts:' set it owns (partition-document.sh --cross-owner), or name $fg_a_ in the finding the owning shard already carries -- or correct the row with the evidence that $fg_a_ passes"
  done < "$T/failrows"
}

adv_has() { grep -qF -- "$ADVISOR_SENTINEL" "$1"; } # <role file> -> 0 when it prescribes the line

# story_idx_ok <basename> <idx>: 0 when <basename> carries story index <idx> (header: THE EXEMPTION), as
# `story-<idx>.md` or `story-<idx>-<slug>.md` whose slug does not open with a digit (index 1 is not story-1-2-y.md).
# Every comparison against <idx> is a LITERAL string comparison: no pattern is built from the index text, so an index
# carrying `*`, `?` or `[` names only itself.
story_idx_ok() {
  si_p_="story-$2"
  [ "$1" != "$si_p_.md" ] || return 0
  [ "${1:0:${#si_p_}+1}" = "$si_p_-" ] || return 1
  si_r_="${1:${#si_p_}+1}"
  case "$si_r_" in [0-9]*) return 1 ;; esac
  case "$si_r_" in ?*.md) return 0 ;; esac
  return 1
}

# idx_ok <idx>: 0 when <idx> is a story index (header: THE EXEMPTION). A digit-led index is `-`-joined components, each
# digits with at most one trailing lower-case letter (`1-1`, `2-3a`), so a review named for a slug
# (`1-1-z-qa-validation.md`) carries no index. A letter-led index (`B1`, `B-1`, `DASH`, `SR1`) is any text with no `/`,
# `.` or whitespace; STORY-BIND then binds it as it binds a numeric one, by story_idx_ok's literal match against
# --story and the implementation view's row listing that story, so a letter-led index no listed story carries is REFUSED
# there. Empty and a leading `-` are refused by the digit-led grammar.
idx_ok() {
  ix_s_="$1"
  case "$ix_s_" in [ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]*) case "$ix_s_" in */* | *.* | *[[:space:]]*) return 1 ;; esac; return 0 ;; esac
  while :; do
    ix_c_="${ix_s_%%-*}"; case "$ix_c_" in *[a-z]) ix_c_="${ix_c_%?}" ;; esac
    case "$ix_c_" in '' | *[!0-9]*) return 1 ;; esac
    [ "$ix_s_" != "${ix_s_#*-}" ] || return 0
    ix_s_="${ix_s_#*-}"
  done
}

# review_sprint <dir>: the sprint <N> a review path files under, from its lead-assigned slot directory, named exactly
# `s<N>` (`s` then digits and nothing else, so `s2x` and `s2.Ab12` are no slot); nothing when <dir> is no slot.
review_sprint() {
  rs_d_="${1%/}"; rs_d_="${rs_d_##*/}"
  case "$rs_d_" in s[0-9]*) ;; *) return 1 ;; esac
  rs_n_="${rs_d_#s}"
  case "$rs_n_" in *[!0-9]*) return 1 ;; esac
  printf '%s' "$rs_n_"
}
# rec_idx_ok <idx>: 0 when <idx> may key a lead record, its own grammar beside idx_ok: any story index the lead
# dispatches under (`1-1`, `B1`, `B6-rebind`, `5-browser-smoke`), ASCII letters, digits, `_` and `-`, opening with a
# letter or digit. Never `/`, `.`, whitespace, a leading `-` or empty: the name is one path component under stories/.
# idx_ok stays STORY-BIND's grammar, so a digit-led slug-named review (`1-1-z`, `5-browser-smoke`) carries no index there.
rec_idx_ok() {
  case "$1" in '' | -* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-]*) return 1 ;; esac
}
# THE LEAD RECORD (header: CHECK-SERIAL, THE LEAD'S RE-RUN): one file per story, `<git common dir>/ai-dlc/stories/<name>`,
# <name> `s<N>-<story-index>`, plain `key: value` lines. Every writer and reader of the directory goes through these
# three helpers, so its path and format live here once. lead_record_path <repo or dir> <name> -> the path (0), or 1
# when <name> is not `s<digits>-<index>` (<index> by rec_idx_ok) or git names no common dir there.
lead_record_path() {
  case "$2" in s[0-9]*-?*) ;; *) return 1 ;; esac
  lr_n_="${2%%-*}"; lr_n_="${lr_n_#s}"; lr_i_="${2#*-}"
  case "$lr_n_" in '' | *[!0-9]*) return 1 ;; esac
  rec_idx_ok "$lr_i_" || return 1
  lr_c_="$(cd "$1" 2> /dev/null && unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR && git rev-parse --git-common-dir 2> /dev/null < /dev/null)" || return 1
  case "$lr_c_" in /*) ;; ?*) lr_c_="$(cd "$1" && cd "$lr_c_" 2> /dev/null && pwd -P)" || return 1 ;; *) return 1 ;; esac
  printf '%s/ai-dlc/stories/%s' "$lr_c_" "$2"
}
# common_dir_phys <path> -> the physical git common dir of <path> (0), or 1 when git names none there (header: THE
# LEAD CHECKOUT). One subshell: enter <path>, ask git, enter the answer (relative or absolute) and print pwd -P.
common_dir_phys() {
  ( cd "$1" 2> /dev/null && unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR && cdp_c_="$(git rev-parse --git-common-dir 2> /dev/null < /dev/null)" \
      && [ -n "$cdp_c_" ] && cd "$cdp_c_" 2> /dev/null && pwd -P )
}
# lead_checkout_only <path> <what>: REFUSED [owner: lead] unless <path>'s physical git common dir is this run's working
# directory's (header: THE LEAD CHECKOUT). The lead record lives under the lead checkout's common dir, so a reviewed or
# shard repository keyed elsewhere (a redirected gitfile, a clone, a run from another checkout) would read no record.
lead_checkout_only() {
  lc_h_="$(common_dir_phys .)" || lc_h_=""; lc_t_="$(common_dir_phys "$1")" || lc_t_=""
  [ -n "$lc_h_" ] && [ "$lc_h_" = "$lc_t_" ] \
    || refuse_to lead "$2 $1 keeps its git common dir at ${lc_t_:-<none>}, and this run's working directory $(pwd) keeps it at ${lc_h_:-<none>}, so the lead record cannot be read: run it again from the lead checkout (the repository the dev worktrees were added from); no re-dispatch is needed"
}
# slot_rel <dir as given> -> <dir>'s path below its worktree top (0); 1 when that path reads differently through the
# spelling given (logical) and physically (pwd -P), 3 when <dir> is not enterable or git names no top there. Both
# sides are taken RELATIVE TO THE TOP, never as absolute paths, so a checkout reached through a symlinked prefix
# (/tmp on macOS) is one path: the logical spelling must end in the physical path below the top.
slot_rel() {
  ( cd "$1" 2> /dev/null || exit 3
    sl_l_="$(pwd)"; sl_p_="$(pwd -P)"
    sl_t_="$(unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR; git rev-parse --show-toplevel 2> /dev/null < /dev/null)" && [ -n "$sl_t_" ] \
      && sl_t_="$(cd "$sl_t_" 2> /dev/null && pwd -P)" || exit 3
    case "$sl_p_" in "$sl_t_"/?*) sl_r_="${sl_p_#"$sl_t_"/}" ;; *) exit 3 ;; esac
    case "$sl_l_" in */"$sl_r_") ;; *) exit 1 ;; esac
    printf '%s' "$sl_r_" )
}
# shard_slot <shard dir as given> <what> -> SS_N, the sprint <N> of the lead record name s<N>-<idx> (header: THE
# PARTITION RECORD), read off the shard directory's own path below its worktree top, which must be exactly
# docs/reviews/s<N>/shards/<dir>. REFUSED [owner: lead] when the directory is reached through a symlink (a seat that
# moves it under another slot or out of shards/ and links it back would move the record name), and when the path
# names no slot: that is no lead-assigned shard directory, never a partition recorded before 0.995.0.
shard_slot() {
  SS_N=""
  ss_r_="$(slot_rel "$1")"; ss_c_=$?
  [ "$ss_c_" != 1 ] || refuse_to lead "$2 $1 is reached through a symlink: its path below the worktree top reads differently as given and physically, so the record name it derives is not the one the lead assigned. The shard directory must not be reached through a symlink: re-run from the lead checkout with the shard directory in place (no symlink); no re-dispatch is needed"
  [ "$ss_c_" = 0 ] || refuse_to lead "$2 $1 is not enterable or git names no worktree top there, so it names no lead record: re-run from the lead checkout with the shard directory in place (no symlink); no re-dispatch is needed"
  ss_t_="${ss_r_#docs/reviews/}"; ss_s_="${ss_t_%%/*}"; ss_b_="${ss_t_#"$ss_s_"/shards/}"
  case "$ss_b_" in "$ss_t_" | "" | */*) ;; *) SS_N="$(review_sprint "$ss_s_")" || SS_N="" ;; esac
  [ "$ss_t_" != "$ss_r_" ] && [ -n "$SS_N" ] \
    || refuse_to lead "$2 $1 sits at $ss_r_ below its worktree top, not at docs/reviews/s<N>/shards/<dir>, so it names no story record s<N>-<idx>: partition into the path implementation.md names (Gate-2 dispatch: partition-review-diff.sh --map, then --record-partition) and run from the lead checkout"
}
# lead_record_put <repo or dir> <name> <key> <value>: replaces <key>'s line (or appends it), keeping every other key.
lead_record_put() {
  lp_f_="$(lead_record_path "$1" "$2")" || return 1
  mkdir -p "${lp_f_%/*}" || return 1
  { [ ! -f "$lp_f_" ] || awk -v k="$3: " 'index($0, k) != 1' "$lp_f_"; printf '%s: %s\n' "$3" "$4"; } > "$lp_f_.tmp.$$" \
    && mv "$lp_f_.tmp.$$" "$lp_f_"
}
# lead_record_get <repo or dir> <name> <key> -> the value of <key>'s first line (0), or 1 when the file or key is absent.
lead_record_get() {
  lg_f_="$(lead_record_path "$1" "$2")" && [ -f "$lg_f_" ] || return 1
  awk -v k="$3: " 'index($0, k) == 1 { print substr($0, length(k) + 1); f = 1; exit } END { exit !f }' "$lg_f_"
}
# sr_qa_at <repo> <commit or empty> -> 0 with $T/qa-at-b holding the review repository's qa.md AT <commit> (tracked,
# `.claude/team-roles/` then `core/team-roles/`), else its on-disk copy in <repo>; SR_QA_AT names what was read (the
# bare on-disk path when no commit was given). 1, SR_QA_AT empty, when neither exists (header: CHECK-SERIAL, THE LEAD'S
# RE-RUN). SR_QA_TRK is 1 only when $T/qa-at-b is the tracked blob at <commit>, else 0.
# sr_era <sentinel> <base decides: 1 or 0> -> SR_ERA, after sr_qa_at, the one era decision of --check-serial's canonical
# lines and run record (header: CANONICAL RUN, LEGACY; THE RUN RECORD). With <base decides> 1 (--lead-range, qa.md a
# tracked blob at the dispatch base) that blob alone decides: `base` when it carries <sentinel>, else `legacy`.
# Otherwise `role` when ROLE_MD carries it (it can hold, never acquit), `absent` when sr_qa_at read no qa.md, `base`
# when the qa.md it read carries it, else `legacy`. Each caller maps `absent` itself.
sr_era() {
  if [ "$2" = 1 ]; then
    if grep -qF -- "$1" "$T/qa-at-b"; then SR_ERA=base; else SR_ERA=legacy; fi
    return 0
  fi
  if grep -qF -- "$1" "$ROLE_MD"; then SR_ERA=role
  elif [ -z "$SR_QA_AT" ]; then SR_ERA=absent
  elif grep -qF -- "$1" "$T/qa-at-b"; then SR_ERA=base
  else SR_ERA=legacy; fi
}
sr_qa_at() {
  SR_QA_AT=""; SR_QA_TRK=0
  [ -n "$1" ] || return 1
  if [ -n "$2" ]; then
    for sq_p_ in ".claude/team-roles/$ROLE_NAME" "core/team-roles/$ROLE_NAME"; do
      git --no-replace-objects -C "$1" cat-file -e "${2}:${sq_p_}" 2> /dev/null < /dev/null || continue
      git --no-replace-objects -C "$1" show "${2}:${sq_p_}" > "$T/qa-at-b" 2> /dev/null < /dev/null || return 1
      SR_QA_AT="$sq_p_ at $2"; SR_QA_TRK=1; return 0
    done
  fi
  for sq_p_ in "$1/.claude/team-roles/$ROLE_NAME" "$1/core/team-roles/$ROLE_NAME"; do
    [ -r "$sq_p_" ] || continue
    cp "$sq_p_" "$T/qa-at-b" || return 1
    SR_QA_AT="$sq_p_"; [ -z "$2" ] || SR_QA_AT="$sq_p_ (on disk, untracked at $2)"; return 0
  done
  return 1
}
# ss_bound <args...>: sprint-status.sh beside this script, in this shell's subshell, with the seat's schema override
# ignored, so STORY-BIND reads stories_dir from the schema the install ships (header: THE EXEMPTION). AI_DLC_PROJECT_ROOT
# is ignored for the same reason: in the consumer layout it is what locates .claude/schemas/, so a seat-set root would
# choose the schema; without it sprint-status.sh walks up from its own install path.
ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA AI_DLC_PROJECT_ROOT; . "$cg_ss_" && ss_main "$@" ); }
# stem_rows <entry keys, one per line>: THE ROW STEM RULE (BL-956), the one helper every STORY-BIND site that binds a
# view row by its KEY calls, each after the literal story_idx_ok rule. Prints, one per line, each key whose
# sprint-stripped stem is `story-<cg_i_>` under the REVIEW's sprint cg_n_ (never the view's), as sprint-status.sh
# stem-names decides it, so no second key grammar exists here; non-zero when that gives no answer.
# A caller tests a key's membership in the printed set as a literal string.
stem_rows() { [ -n "$1" ] || return 0; ss_bound stem-names --sprint "$cg_n_" --keys "$1" "$cg_i_" < /dev/null; }

# pr_record <qa shard-dir>: `--record-partition`, written through the lead-record helpers above (the one copy of the
# record's path and format). Run by the lead right after the gate-2 partition writes the shard
# directory and before any QA is dispatched, so the manifest it copies is the partition's own. Writes the story's
# partition-base, partition-sha (the manifest's base and sha) and qa-era (`held` or `legacy`: qa.md as installed AT
# THE BASE, tracked first, else on disk in the manifest's worktree now; neither readable is `held`) into the record
# named by the shard directory's physical `docs/reviews/s<N>/shards/` parent and its <idx>. A re-partition replaces
# these three keys and touches no other.
pr_record() {
  [ "$#" -eq 1 ] && [ -n "$1" ] || refuse "usage: merge-review-shards.sh --record-partition <qa shard-dir>"
  pr_d_="${1%/}"
  [ -d "$pr_d_" ] || refuse "shard directory $pr_d_ does not exist; run partition-review-diff.sh --map ... --shard-dir <it> first"
  pr_l_="$pr_d_"; pr_d_="$(cd "$pr_d_" && pwd -P)" || refuse "shard directory $1 is not enterable"
  lead_checkout_only "$pr_d_" "--record-partition: the shard directory"
  shard_slot "$pr_l_" "--record-partition: the shard directory"; pr_n_="$SS_N"
  MF="$pr_d_/.manifest"
  [ -f "$MF" ] || refuse "no manifest at $MF; --record-partition runs right after the partition writes it"
  for k in worktree base sha; do
    [ "$(awk -F'\t' -v k="$k" '$1 == k { n++ } END { print n + 0 }' "$MF")" = 1 ] || refuse "$MF carries no single '$k' line"
  done
  pr_wt_="$(mf worktree)"; pr_b_="$(mf base)"; pr_s_="$(mf sha)"
  for pr_x_ in "$pr_b_" "$pr_s_"; do
    case "$pr_x_" in *[!0-9a-f]*|"") refuse "$MF names '$pr_x_', not a full hex object name" ;; esac
    git --no-replace-objects -C "$pr_wt_" rev-parse -q --verify "${pr_x_}^{commit}" > /dev/null 2>&1 < /dev/null \
      || refuse "$pr_x_ is not a commit in the manifest's worktree $pr_wt_"
  done
  pr_sb_="${pr_d_##*/}"; pr_12_="$(printf '%s' "$pr_s_" | cut -c1-12)"
  case "$pr_sb_" in
    *-qa-validation-"$pr_12_") pr_i_="${pr_sb_%-qa-validation-"$pr_12_"}" ;;
    *-qa-validation-"$pr_12_"-p*) pr_i_="${pr_sb_%-qa-validation-"$pr_12_"-p*}" ;;
    *) refuse "shard directory $pr_sb_ is not <idx>-qa-validation-<sha12>[-p<M>] for the manifest's sha $pr_s_" ;;
  esac
  rec_idx_ok "$pr_i_" || refuse "shard directory $pr_sb_ names no story index"
  pr_e_=held; pr_at_=""
  for pr_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
    git --no-replace-objects -C "$pr_wt_" cat-file -e "${pr_b_}:${pr_p_}" 2> /dev/null < /dev/null || continue
    pr_at_=1; git --no-replace-objects -C "$pr_wt_" show "${pr_b_}:${pr_p_}" 2> /dev/null < /dev/null | grep -qF -- 'column-0 `Canonical run:`' || pr_e_=legacy
    break
  done
  if [ -z "$pr_at_" ]; then
    for pr_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
      [ -r "$pr_wt_/$pr_p_" ] || continue
      grep -qF -- 'column-0 `Canonical run:`' "$pr_wt_/$pr_p_" || pr_e_=legacy
      break
    done
  fi
  pr_nm_="s$pr_n_-$pr_i_"
  # THE RUN RECORD's era (header: CANONICAL RUN, THE RUN RECORD), read at the base as qa-era is; unreadable is held.
  pr_re_="$(era_at "$pr_wt_" "$pr_b_" "$RUN_SENTINEL")"; [ "$pr_re_" = legacy ] || pr_re_=held
  lead_record_put "$pr_d_" "$pr_nm_" "partition-base.$pr_sb_" "$pr_b_" && lead_record_put "$pr_d_" "$pr_nm_" "partition-sha.$pr_sb_" "$pr_s_" \
    && lead_record_put "$pr_d_" "$pr_nm_" "qa-era.$pr_sb_" "$pr_e_" && lead_record_put "$pr_d_" "$pr_nm_" "run-era.$pr_sb_" "$pr_re_" \
    || refuse "cannot write the partition record $pr_nm_ under the git common dir of $pr_d_"
  printf 'RECORDED: %s partition-base=%s partition-sha=%s qa-era=%s run-era=%s\n' "$(lead_record_path "$pr_d_" "$pr_nm_")" "$pr_b_" "$pr_s_" "$pr_e_" "$pr_re_"
}

# era_at <worktree> <commit> <sentinel> -> `held` or `legacy` when qa.md AT <commit> (tracked, `.claude/team-roles/`
# then `core/team-roles/`) carries <sentinel> or not, else the same of its on-disk copy in <worktree>; `none` when
# neither is readable. Each caller decides what `none` means (header: CANONICAL RUN, THE RUN RECORD).
era_at() {
  for ea_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
    git --no-replace-objects -C "$1" cat-file -e "${2}:${ea_p_}" 2> /dev/null < /dev/null || continue
    if git --no-replace-objects -C "$1" show "${2}:${ea_p_}" 2> /dev/null < /dev/null | grep -qF -- "$3"; then echo held; else echo legacy; fi
    return 0
  done
  for ea_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
    [ -r "$1/$ea_p_" ] || continue
    if grep -qF -- "$3" "$1/$ea_p_"; then echo held; else echo legacy; fi
    return 0
  done
  echo none
}
# rr_summary <capture> -> the run's summary line (0), or 1 when the capture carries none (header: THE RUN RECORD). OSC
# (ESC ] ... BEL) and SGR escapes and CRs stripped; a vitest run's last `Test Files` line joined to the `Tests` line
# after it with `; `, else pytest's last session line (`=== ... passed|failed|error ... in <n>s`), else the last line
# carrying canon_gate's count that is no per-test line (no `::`, no ` PASSED`/` FAILED` with a `[ NN%]` progress tail);
# leading and trailing runs of `=` and whitespace stripped from each part.
rr_summary() {
  awk -v esc="$(printf '\033')" -v bel="$(printf '\007')" '
    function trim(s) { sub(/^[[:space:]=]+/, "", s); sub(/[[:space:]=]+$/, "", s); return s }
    { gsub(esc "\\][^" bel "]*" bel, ""); gsub(esc "\\[[0-9;?]*[A-Za-z]", ""); gsub(/\r/, ""); l[NR] = $0
      if ($0 ~ /^=+ .*(passed|failed|errors?).* in [0-9.]+s/) ps = NR
      if (tolower($0) ~ /[0-9]+[[:space:]]+(passed|failed|collected|errors?)([^a-z]|$)/ && $0 !~ /::/ && $0 !~ /( PASSED| FAILED).*\[ *[0-9]+%\]/) c = NR
      if ($0 ~ /^[[:space:]]*Test Files[[:space:]]/) tf = NR }
    END { if (tf) { s = trim(l[tf]); if (l[tf + 1] ~ /^[[:space:]]*Tests[[:space:]]/) s = s "; " trim(l[tf + 1]) }
          else if (ps) s = trim(l[ps])
          else if (c) s = trim(l[c])
          if (s == "") exit 1
          print s }' "$1"
}
# rr_norm <text> -> the text with backticks and `=` removed, whitespace collapsed and trimmed: the one comparison form
# of a recorded result and a `Canonical result:` value.
rr_norm() {
  awk '{ gsub(/[`=\r]/, ""); gsub(/[[:space:]]+/, " "); sub(/^ /, ""); sub(/ $/, ""); print }' <<<"$1"
}
# rr_quote <arg...> -> RR_Q, the argv as one shell line a seat can copy and re-run: an argument of only
# [A-Za-z0-9_./=:,+@-] bare, any other single-quoted (an embedded ' as '\''), joined by one space. Not `printf %q`: its
# `a\ and\ b` is read by RUN-FILTER's marker scan as the marker `a\`, while `'a and b'` is read as `a and b`, the value
# a conventions file's `-m "a and b"` declares. No fork.
rr_quote() {
  local a sq="'" rp="'\\''"
  RR_Q=""
  for a in "$@"; do
    case "$a" in ''|*[!A-Za-z0-9_./=:,+@-]*) a="'${a//$sq/$rp}'" ;; esac
    RR_Q="$RR_Q${RR_Q:+ }$a"
  done
}
# rr_record <qa shard-dir | serial review file> [--dir <subdir>] -- <invocation...>: `--record-run` (header: THE RUN
# RECORD). Runs the invocation in the frozen worktree and writes its summary line into the lead's story record.
rr_record() {
  rr_u_="usage: merge-review-shards.sh --record-run <qa shard-dir> [--dir <relative subdir>] -- <invocation...> | --record-run <serial review file> --frozen <go-signal sha> [--dir <relative subdir>] -- <invocation...>"
  [ "$#" -ge 1 ] && [ -n "$1" ] || refuse "$rr_u_"
  rr_a_="$1"; shift; rr_sub_=""; rr_fz_=""
  while [ "${1:-}" = --dir ] || [ "${1:-}" = --frozen ]; do
    [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "$rr_u_"
    if [ "$1" = --dir ]; then rr_sub_="$2"; else rr_fz_="$2"; fi
    shift 2
  done
  [ "${1:-}" = -- ] && [ "$#" -ge 2 ] || refuse "$rr_u_"
  shift
  [ -z "$rr_sub_" ] || case "/$rr_sub_/" in //*|*/../*) refuse "--record-run --dir '$rr_sub_' is absolute or climbs out with '..'; name the subdirectory of the frozen worktree the canonical run starts in" ;; esac
  if [ -d "$rr_a_" ]; then
    [ -z "$rr_fz_" ] || refuse "--record-run --frozen is read only with a serial review file; a shard directory's frozen sha is its manifest's"
    rr_l_="${rr_a_%/}"; rr_d_="$(cd "$rr_l_" && pwd -P)" || refuse "shard directory $rr_a_ is not enterable"
    lead_checkout_only "$rr_d_" "--record-run: the shard directory"
    shard_slot "$rr_l_" "--record-run: the shard directory"; rr_n_="$SS_N"
    MF="$rr_d_/.manifest"
    [ -f "$MF" ] || refuse "no manifest at $MF; --record-run takes the shard directory the gate-2 partition wrote"
    for k in worktree sha; do
      [ "$(awk -F'\t' -v k="$k" '$1 == k { n++ } END { print n + 0 }' "$MF")" = 1 ] || refuse "$MF carries no single '$k' line"
    done
    rr_wt_="$(mf worktree)"; rr_s_="$(mf sha)"
    case "$rr_s_" in *[!0-9a-f]*|"") refuse "$MF names '$rr_s_', not a full hex object name" ;; esac
    rr_sb_="${rr_d_##*/}"; rr_12_="$(printf '%s' "$rr_s_" | cut -c1-12)"
    case "$rr_sb_" in
      *-qa-validation-"$rr_12_") rr_i_="${rr_sb_%-qa-validation-"$rr_12_"}" ;;
      *-qa-validation-"$rr_12_"-p*) rr_i_="${rr_sb_%-qa-validation-"$rr_12_"-p*}" ;;
      *) refuse "shard directory $rr_sb_ is not <idx>-qa-validation-<sha12>[-p<M>] for the manifest's sha $rr_s_" ;;
    esac
    rr_rp_="$rr_d_"; rr_k_="run.$rr_sb_"
  else
    # A serial review file: it need not exist yet, its docs/reviews/s<N>/ directory must, in the frozen worktree.
    rr_pd_="$(cd "$(dirname "$rr_a_")" 2> /dev/null && pwd -P)" || refuse "the directory of $rr_a_ does not exist; --record-run takes the shard directory or the serial validation file's path at docs/reviews/s<N>/ in the frozen worktree"
    rr_wt_="$(cd "$rr_pd_" && unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR && git rev-parse --show-toplevel 2> /dev/null < /dev/null)" \
      || refuse "$rr_a_ is not inside a git worktree; --record-run takes the serial validation file's path in the frozen worktree"
    lead_checkout_only "$rr_wt_" "--record-run: the review's repository"
    rr_n_="$(review_sprint "$(dirname "$rr_a_")")" && [ "$rr_pd_" = "$(cd "$rr_wt_" && pwd -P)/docs/reviews/s$rr_n_" ] \
      || refuse "$rr_a_ is not at docs/reviews/s<N>/ in its own repository $rr_wt_; pass the validation file's path qa.md names"
    rr_sb_="$(basename "$rr_a_")"; rr_i_=""
    case "$rr_sb_" in
      ?*-qa-validation.md) rr_i_="${rr_sb_%-qa-validation.md}" ;;
      ?*-qa-validation-p*.md) rr_i_="${rr_sb_%-qa-validation-p*.md}" ;;
    esac
    # The frozen sha is the go-signal sha the lead sent, taken literally and never resolved, so the HEAD check below
    # compares the worktree against it (a sha read off the worktree's own HEAD would compare HEAD with HEAD).
    case "$rr_fz_" in
      "") refuse "--record-run on a serial review file takes --frozen <the full go-signal sha>; $rr_u_" ;;
      *[!0-9a-f]*) refuse "--record-run --frozen '$rr_fz_' is not a full lowercase hex sha; pass the full sha of the gate-2 go-signal" ;;
    esac
    { [ "${#rr_fz_}" = 40 ] || [ "${#rr_fz_}" = 64 ]; } || refuse "--record-run --frozen '$rr_fz_' is not a full sha; pass the full sha of the gate-2 go-signal"
    rr_s_="$rr_fz_"; rr_rp_="$rr_wt_"; rr_k_="run.$rr_sb_"
  fi
  rec_idx_ok "$rr_i_" || refuse "$rr_a_ names no story index the lead record can be keyed on"
  rr_nm_="s$rr_n_-$rr_i_"
  rr_f_="$(lead_record_path "$rr_rp_" "$rr_nm_")" || refuse "--record-run: '$rr_nm_' names no lead record under the git common dir of $rr_rp_"
  # The run tests the frozen tree only when the worktree's HEAD is the frozen sha; untracked files never refuse.
  rr_h_="$(git --no-replace-objects -C "$rr_wt_" rev-parse -q --verify HEAD 2> /dev/null < /dev/null)" || rr_h_=""
  [ -n "$rr_s_" ] && [ "$rr_h_" = "$rr_s_" ] \
    || refuse "--record-run: the frozen worktree $rr_wt_ is at HEAD ${rr_h_:-<none>}, not the frozen sha ${rr_s_:-<none>}, so the run would test other code; nothing was recorded. Check out the frozen sha there (nothing else mutates the frozen worktree) and run it again"
  rr_wd_="$rr_wt_${rr_sub_:+/$rr_sub_}"
  [ -d "$rr_wd_" ] || refuse "--record-run: $rr_wd_ is not a directory of the frozen worktree; nothing was recorded"
  rr_t_="$(mktemp -d "${TMPDIR:-/tmp}/record-run.XXXXXX")" || refuse "--record-run: mktemp failed"
  rr_cap_="$rr_t_/capture.txt"
  ( cd "$rr_wd_" && exec "$@" ) > "$rr_cap_" 2>&1 < /dev/null; rr_rc_=$?
  # The exit is recorded and never refused on: a PASS may carry the story's permitted pre-existing failures.
  rr_res_="$(rr_summary "$rr_cap_")" \
    || refuse "--record-run: the run exited $rr_rc_ and its output ($rr_cap_) carries no summary line with a count, so it timed out, was interrupted or never finished; nothing was recorded. Run it again to completion"
  rr_quote "$@"; rr_inv_="${RR_Q//$'\n'/ }"
  lead_record_put "$rr_rp_" "$rr_nm_" "$rr_k_.sha" "$rr_s_" && lead_record_put "$rr_rp_" "$rr_nm_" "$rr_k_.exit" "$rr_rc_" \
    && lead_record_put "$rr_rp_" "$rr_nm_" "$rr_k_.dir" "$rr_wd_" && lead_record_put "$rr_rp_" "$rr_nm_" "$rr_k_.invocation" "$rr_inv_" \
    && lead_record_put "$rr_rp_" "$rr_nm_" "$rr_k_.result" "$rr_res_" \
    || refuse "--record-run: cannot write the run record $rr_f_"
  printf 'RECORDED-RESULT: %s\n' "$rr_res_"
  printf 'RECORDED-RUN: %s (in %s, sha %s)\n' "$rr_inv_" "$rr_wd_" "$rr_s_"
  printf 'RECORDED-CAPTURE: %s (exit %s, record %s key %s)\n' "$rr_cap_" "$rr_rc_" "$rr_f_" "$rr_k_"
}
# run_bind <file> <owner> <Canonical result: value> <conventions file or empty> <Canonical run: value>: THE RUN RECORD's binding (header), on canon_gate's
# run branch. The caller sets RB_ERA (`legacy` acquits), RB_AT (named in the LEGACY line), RB_REPO and RB_NAME (the
# lead record), RB_KEY (this pass's run key), RB_SHA (this pass's frozen sha), RB_WT (the repository the frozen sha is
# read in), RB_ARG (the --record-run operand the remedy names) and RB_FZ (the serial form's --frozen sha, empty for a
# shard directory).
run_bind() {
  if [ "$RB_ERA" = legacy ]; then
    printf 'LEGACY: canonical-run record not checked: %s prescribes no %s line\n' "$RB_AT" "$RUN_SENTINEL"; return 0
  fi
  rb_rr_="merge-review-shards.sh --record-run $RB_ARG${RB_FZ:+ --frozen $RB_FZ} [--dir <subdir>] --<the canonical invocation>, run from the lead checkout, and copy its RECORDED-RESULT line verbatim and alone into 'Canonical result:'"
  rb_f_=""; [ -z "$RB_NAME" ] || [ -z "$RB_SHA" ] || rb_f_="$(lead_record_path "$RB_REPO" "$RB_NAME")" || rb_f_=""
  [ -n "$rb_f_" ] || refuse_to "$2" "$1 reads PASS, and its canonical run cannot be looked up: no lead record name or no frozen sha (record ${RB_NAME:-<none>}, sha ${RB_SHA:-<none>}); write the review at the path qa.md names with its reviewed-sha: line, and run $rb_rr_"
  # Every recorded run of the story, `<key>\t<sha>`, from the record's `run.<key>.sha` lines.
  rb_all_="$(awk '/^run\..*\.sha: / { k = $1; sub(/^run\./, "", k); sub(/\.sha:$/, "", k); print k "\t" $2 }' "$rb_f_" 2> /dev/null)" || rb_all_=""
  [ -n "$rb_all_" ] || refuse_to "$2" "$1 reads PASS, and no canonical run is recorded for this story ($rb_f_ holds none); run $rb_rr_"
  # This pass's own key at the frozen sha first, then any earlier pass's run at the same sha.
  rb_k_="$(awk -F'\t' -v k="${RB_KEY#run.}" -v s="$RB_SHA" '$1 == k && $2 == s { print $1; f = 1; exit } $2 == s && e == "" { e = $1 } END { if (!f && e != "") print e }' <<<"$rb_all_")"
  if [ -z "$rb_k_" ]; then
    rb_shas_="$(awk -F'\t' '{ printf "%s%s", (NR > 1 ? ", " : ""), $2 }' <<<"$rb_all_")"
    [ -n "$STORY_F" ] \
      || refuse_to "$2" "$1 reads PASS, and no canonical run is recorded at the frozen sha $RB_SHA (recorded at: $rb_shas_); an earlier pass's run is reused only over a record-only change, decided with --story: pass --story <story file>, or run $rb_rr_"
    rb_why_=""
    while IFS=$'\t' read -r rb_ek_ rb_es_; do
      # An earlier pass's run, reused when the change since it is record-only by the exemption's own predicate.
      rb_po_="$(mrs_sib "$RO" ro_main paths -C "$RB_WT" "$STORY_F" "$rb_es_" "$RB_SHA" 2>&1 < /dev/null)" && { rb_k_="$rb_ek_"; break; }
      rb_why_="$rb_why_; $rb_es_..$RB_SHA: ${rb_po_%%$'\n'*}"
    done <<<"$rb_all_"
    [ -n "$rb_k_" ] \
      || refuse_to "$2" "$1 reads PASS, and no canonical run is recorded at the frozen sha $RB_SHA, and no earlier pass's run is reusable (record-only-diff.sh paths${rb_why_}); an earlier pass's run is accepted only when it ran at this frozen sha or the change since it is record-only: run $rb_rr_"
  fi
  rb_rv_="$(lead_record_get "$RB_REPO" "$RB_NAME" "run.$rb_k_.result")" || rb_rv_=""
  rb_ri_="$(lead_record_get "$RB_REPO" "$RB_NAME" "run.$rb_k_.invocation")" || rb_ri_=""
  # The recorded invocation is held to the canonical profile as the `Canonical run:` line is (record-only-diff.sh RUN-FILTER).
  rb_rf_="$(mrs_sib "$RO" ro_main run-filter "\`$rb_ri_\`" ${4:+"$4"})" \
    || refuse_to "$2" "$1 reads PASS, and the recorded run (run.$rb_k_) invoked \`$rb_ri_\`, which $rb_rf_; run $rb_rr_ with the full collection"
  # The `Canonical run:` invocation (the span RUN-FILTER reads, record-only-diff.sh run-span) is the recorded one, so a
  # recorded replay of an old capture cannot stand behind a review naming the canonical command.
  rb_rs_="$(mrs_sib "$RO" ro_main run-span "$5")" || rb_rs_=""
  [ "$(rr_norm "$rb_rs_")" = "$(rr_norm "$rb_ri_")" ] \
    || refuse_to "$2" "$1 'Canonical run: \`$rb_rs_\`' is not the recorded run's invocation \`$rb_ri_\` (run.$rb_k_ in $rb_f_); copy the RECORDED-RUN invocation into 'Canonical run:', or run $rb_rr_"
  [ "$(rr_norm "$3")" = "$(rr_norm "$rb_rv_")" ] \
    || refuse_to "$2" "$1 'Canonical result: $3' is not the recorded run's result '$rb_rv_' (run.$rb_k_ in $rb_f_, sha $(awk -F'\t' -v k="$rb_k_" '$1 == k { print $2; exit }' <<<"$rb_all_")); copy the RECORDED-RESULT line verbatim and alone, commentary on the next line"
  return 0
}

canon_gate() {
  cg_f_="$1"; cg_o_="$2"; cg_r_="$3"; cg_b_="$4"; cg_z_="$5"; cg_c_="${6:-}"; cg_i_="${7:-}"; cg_n_="${8:-}"; cg_lw_="${9:-}"
  [ "$WORST" = PASS ] || return 0
  [ -f "$RO" ] || refuse_to lead "record-only-diff.sh is not beside this script at $AI_DLC_SELF_DIR; the canonical-run check reads its grammar there"
  cg_run_="$(mrs_sib "$RO" ro_main label 'Canonical run:' < "$cg_f_")" \
    || refuse_to "$cg_o_" "$cg_f_ reads PASS and carries no 'Canonical run:' line; a PASS waits for QA's own canonical full-collection run: write 'Canonical run: <invocation and working directory>' and 'Canonical result: <its summary line with counts>' (or 'Canonical run: none, <reason>' when the story's diff is record-only). A consumer whose overrides/ entry shadows qa.md's Validation Checklist adopts these two lines into it (the reconcile's HARD-OVERRIDE-DRIFT-SECTION adjudication)"
  # A value that is not a run (record-only-diff.sh RUN-SHAPE) is a no-run claim, however it is spelled.
  cg_x_=0
  if ! mrs_sib "$RO" ro_main run-shape "$cg_run_" ${cg_c_:+"$cg_c_"}; then
    cg_x_=1
    mrs_sib "$RO" ro_main none-reason "$cg_run_" 2>/dev/null; cg_nr_=$?
    [ "$cg_nr_" -ne 1 ] \
      || refuse_to "$cg_o_" "$cg_f_ 'Canonical run: $cg_run_' gives no reason; write 'none, <reason>' (accepted only on a record-only diff), 'none, <AC-id> waives it' (accepted only when the story at a lead-written base carries that AC's '## Canonical-run waivers' entry) or the run itself"
    [ -n "$STORY_F" ] && [ -n "$cg_b_" ] && [ -n "$cg_z_" ] \
      || refuse_to "$cg_o_" "$cg_f_ 'Canonical run: ${cg_run_:-<empty>}' records no run (no backticked invocation, \`\$ \` line or count), so it claims the record-only exemption, and no --story and --range were given to decide it; re-run with --story <story file> --range <base> <frozen>, or record the run"
  fi
  # STORY-BIND ON BOTH BRANCHES (header: THE EXEMPTION): the index and view-row binding below runs for a no-run claim
  # and for a run claim alike whenever --story and a frozen sha are given (the merge always has the manifest's sha), so
  # a run claim cannot carry another story's --story. The one-story, history and record-only checks stay the exemption's.
  if [ "$cg_x_" = 1 ] || { [ -n "$STORY_F" ] && [ -n "$cg_z_" ]; }; then
    # STORY-BIND (header: THE EXEMPTION): --story is the story file the implementation view lists at <frozen>.
    [ -n "$cg_i_" ] && idx_ok "$cg_i_" \
      || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption and its name carries no story index (<idx>-$DSUF.md or <idx>-$DSUF-p<M>.md, <idx> digits joined by '-', each with at most one trailing letter, or opening with a letter and carrying no '/', '.' or whitespace); write the review at the path qa.md names"
    [ -n "$cg_n_" ] \
      || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption and its path carries no sprint (docs/reviews/s<N>/, the slot qa.md names); write the review at the path qa.md names"
    cg_sr_="$(ME=record-only-diff mrs_sib "$RO" ro_story_rel "$cg_r_" "$STORY_F" 2>&1)" \
      || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption and --story $STORY_F is not a path inside the repository ($cg_sr_); pass the story file"
    cg_ss_="$AI_DLC_SELF_DIR/sprint-status.sh"
    [ -f "$cg_ss_" ] \
      || refuse_to "$cg_o_" "STORY-BIND: sprint-status.sh is not beside this script at $AI_DLC_SELF_DIR; the record-only exemption binds --story to its sprint-status row there"
    cg_row_="$(ss_bound story-status --ref "$cg_z_" --root "$cg_r_" "$cg_sr_" 2>&1 < /dev/null)"
    # THE INDEX (BL-956): --story carries the review's index literally, else the view's row naming --story at <frozen>
    # (the row read below) is keyed under that index (stem_rows), so `6-qa-validation.md` binds story-1-6-<slug>.md
    # when row story-<N>-6 names it. The row is not required at <base>.
    if ! story_idx_ok "${cg_sr_##*/}" "$cg_i_"; then
      cg_rk_="$(awk -F'\t' '$1 == "row" { n++; s = $2; k = $3 } END { if (n == 1 && s != "") { sub(/ \(.*$/, "", k); print k } }' <<<"$cg_row_")"
      { [ -n "$cg_rk_" ] && cg_sk_="$(stem_rows "$cg_rk_")" && [ "$cg_sk_" = "$cg_rk_" ]; } \
        || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and --story $STORY_F is not story-$cg_i_.md or story-$cg_i_-*.md, or its slug opens with a digit (a longer index); pass the story file the review is for"
    fi
    # Keyed on the `row` line naming an entry with a status, never on the exit: story-status exits 0
    # on a path no entry names.
    cg_rw_="$(awk -F'\t' '$1 == "row" { n++; s = $2; w = $3 } END { if (n == 1 && s != "") print "ok"; else if (n == 1) print w; else print "story-status printed " n + 0 " row line(s)" }' <<<"$cg_row_")"
    [ "$cg_rw_" = ok ] \
      || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption, and --story $cg_sr_ is not a story the implementation view lists at $cg_z_ (${cg_rw_:-$cg_row_}); pass the lead's own story file for this review (implementation.md, the lead re-runs a serial QA's check), which the view must list at $cg_z_ under a row keyed for index $cg_i_; on the no-run exemption claim STORY-BIND also holds --story's pairs to the index from --base to frozen, because inside the range the view is a record the dev writes, so a row moved there is no authority"
    STORY_F="$cg_sr_"
  fi
  if [ "$cg_x_" = 1 ]; then
    if [ "$cg_o_" = serial ]; then
      # The seat supplies its own range, so its base is held to a gate-1 base's shape (header).
      GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts git -C "$cg_r_" merge-base --is-ancestor "$cg_b_" "$cg_z_" 2> /dev/null < /dev/null \
        || refuse_to "$cg_o_" "$cg_f_ claims the record-only exemption over --range $cg_b_ $cg_z_, and $cg_b_ is not an ancestor of $cg_z_; pass the base gate 1 used"
      cg_sb_="$(mrs_sib "$RO" ro_main story-base -C "$cg_r_" "$STORY_F" "$cg_b_" "$cg_z_" 2>&1)" \
        || refuse_to "$cg_o_" "$cg_f_ claims the record-only exemption over --range $cg_b_ $cg_z_, and $cg_b_ is not the story's gate-1 base ($cg_sb_); the exemption is decided over the WHOLE story, from the base gate 1 used, on every pass"
    fi
    # STORY-BIND, ONE STORY PER INDEX (header: THE EXEMPTION): no OTHER entry of the implementation view at <base> or at
    # <frozen> names a file under the review's index, by its declared `file:` or its resolved file, WHATEVER its status;
    # a view that gives no answer at either ref (absent, no `sprint:`, a `stories:` block that is not ok) is REFUSED,
    # never read as "nothing listed". It runs after the serial base checks, so a base that is no gate-1 base is refused
    # with that remedy, not this one.
    for cg_ref_ in "$cg_b_" "$cg_z_"; do
      cg_ls_="$(ss_bound list-stories --ref "$cg_ref_" --root "$cg_r_" 2>&1 < /dev/null)" \
        || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and the implementation view gives no answer at $cg_ref_ (${cg_ls_##*$'\n'}), so the stories under that index are unknown; the exemption is decided only over a range whose view lists the sprint's stories at both ends"
      # THE ROW STEM RULE (BL-956): the keys of the entries naming a file that is not --story, asked of stem_rows once
      # per ref; an entry under one of them counts for the index as a literal basename does. An entry naming NO file
      # (no declared and no resolved file) is not a candidate: at a base before --story existed, --story's own key-only
      # row resolves to nothing, and counting it would refuse a story that bound before BL-956 (receipt-bl956.sh
      # lit-keyonly). Such a row names no other story, so the literal rule never counted it either.
      cg_ok_=""
      while IFS=$'\t' read -r cg_ck_ cg_cs_ cg_cd_ cg_cp_; do
        [ -n "$cg_ck_" ] && [ "$cg_cp_" != "$STORY_F" ] && [ "${cg_cd_##*/}" != "${STORY_F##*/}" ] && { [ "$cg_cp_" != - ] || [ "$cg_cd_" != - ]; } \
          && cg_ok_="$cg_ok_$cg_ck_"$'\n'
      done <<<"$cg_ls_"
      cg_sk_="$(stem_rows "$cg_ok_" 2>&1)" \
        || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and the implementation view's keys at $cg_ref_ cannot be read under that index (${cg_sk_##*$'\n'}); the exemption is decided only where every entry's index is known"
      while IFS=$'\t' read -r cg_k_ cg_s_ cg_d_ cg_p_; do
        { [ "${cg_d_##*/}" != "${STORY_F##*/}" ] && story_idx_ok "${cg_d_##*/}" "$cg_i_"; } \
          || { [ "$cg_p_" != "$STORY_F" ] && story_idx_ok "${cg_p_##*/}" "$cg_i_"; } \
          || { [ "$cg_p_" != "$STORY_F" ] && [ "${cg_d_##*/}" != "${STORY_F##*/}" ] && [ -n "$cg_k_" ] && case $'\n'"$cg_sk_"$'\n' in *$'\n'"$cg_k_"$'\n'*) : ;; *) false ;; esac; } || continue
        refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and --story $STORY_F is not the only story under that index: the implementation view's entry $cg_k_ (status $cg_s_, file $cg_d_) names another story under it at $cg_ref_; pass the story the view listed for this index before the range, and decide the exemption over it"
      done <<<"$cg_ls_"
    done
    # STORY-BIND, THE VIEW'S HISTORY (header: THE EXEMPTION): every `file:` value a commit of the implementation view added
    # or removed, from the commit that created --story's directory to <frozen> (`sprint-status.sh view-history`, which
    # owns the view's path and grammar), under the index, in this sprint and not --story, refuses; no `since` line refuses.
    # A value is under the index by its literal basename or, BL-956, by the key of the row that named it (stem_rows over
    # the keys of `view-history --with-key`); --story's own pairs are held to the index from --base to frozen (THE RE-KEY, below).
    cg_vh_="$(ss_bound view-history --with-key --ref "$cg_z_" --base "$cg_b_" --sprint "$cg_n_" --root "$cg_r_" "$STORY_F" 2>&1 < /dev/null)" \
      && [ "${cg_vh_%%$'\t'*}" = since ] \
      || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and the implementation view's history up to $cg_z_ is unknown (${cg_vh_##*$'\n'}); the exemption is decided only where that history can be read"
    cg_bd_="${cg_vh_%%$'\n'*}"; cg_bd_="${cg_bd_#since$'\t'}"
    cg_ok_=""
    while IFS=$'\t' read -r cg_k_ cg_hk_ cg_d_; do
      { [ "$cg_k_" = file ] || [ "$cg_k_" = window ]; } && [ -n "$cg_hk_" ] && cg_ok_="$cg_ok_$cg_hk_"$'\n'
    done <<<"${cg_vh_}"
    cg_sk_="$(stem_rows "$cg_ok_" 2>&1)" \
      || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and the implementation view's history keys up to $cg_z_ cannot be read under that index (${cg_sk_##*$'\n'}); the exemption is decided only where every entry's index is known"
    while IFS=$'\t' read -r cg_k_ cg_hk_ cg_d_; do
      [ "$cg_k_" = file ] || [ "$cg_k_" = window ] || continue
      # THE RE-KEY (BL-956): --story's own file, when --story does not carry the index literally, binds only by its row,
      # so every row a version of the view from --base to <frozen> pairs with its basename (the `window` lines) must be
      # keyed under the index: a range that moves another story's file onto this index's key (the row it had at <base>
      # keyed elsewhere, or absent) binds that story, whose waiver is then read. Neither the literal rule nor the key's
      # stem naming <idx> is a key under ANOTHER index. A version BEFORE --base is the lead's planning, not the range's,
      # so a story the lead re-keyed there binds; the other stories' values stay the `file` lines, from the creation.
      cg_rx_=""
      if [ "${cg_d_##*/}" = "${STORY_F##*/}" ]; then
        [ "$cg_k_" = window ] || continue
        story_idx_ok "${cg_d_##*/}" "$cg_i_" && continue
        [ -n "$cg_hk_" ] && case $'\n'"$cg_sk_"$'\n' in *$'\n'"$cg_hk_"$'\n'*) continue ;; esac
        cg_rx_=rekey
      else
        [ "$cg_k_" = file ] || continue
      fi
      [ -n "$cg_rx_" ] || story_idx_ok "${cg_d_##*/}" "$cg_i_" \
        || { [ -n "$cg_hk_" ] && case $'\n'"$cg_sk_"$'\n' in *$'\n'"$cg_hk_"$'\n'*) : ;; *) false ;; esac; } || continue
      # This sprint only: the declared directory, its leading ../ and ./ stripped, is a component suffix of --story's.
      cg_dd_="${cg_d_%/*}"; [ "$cg_dd_" != "$cg_d_" ] || cg_dd_=""
      while :; do case "$cg_dd_" in ../*) cg_dd_="${cg_dd_#../}" ;; ./*) cg_dd_="${cg_dd_#./}" ;; *) break ;; esac; done
      case "/${STORY_F%/*}" in "/$cg_dd_" | *"/$cg_dd_") : ;; *) [ -z "$cg_dd_" ] || continue ;; esac
      [ -z "$cg_rx_" ] \
        || refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and the implementation view keyed --story's file $cg_d_ under row ${cg_hk_:-<none>}, not under that index, in a version of the view between --base $cg_b_ and $cg_z_: --story binds this index only by its row, and the no-run exemption claim holds --story's pairs to the index from --base to frozen; pass the lead's own story file for this review"
      refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and the implementation view named $cg_d_ under that index between ${cg_bd_:0:12} (where ${STORY_F%/*} was created) and $cg_z_; pass the story the view listed for this index, and decide the exemption over it"
    done <<<"$cg_vh_"
    # THE WAIVER (record-only-diff.sh WAIVER): `none, <AC-id> waives it`, read against the story AT THE BASE, never at
    # <frozen>: the story is a record path inside the range, so an entry added there is the judged party's own. 0 accepts,
    # 1 falls through to the record-only exemption below, any other exit refuses. Honoured only over a LEAD-WRITTEN base
    # (cg_lw_ = lead: the merge's .manifest base cross-checked against the lead's partition record, or --lead-range
    # over a recorded dispatch); a seat-supplied base cannot choose the story text that waives its own run.
    cg_wv_="$(mrs_sib "$RO" ro_main waiver -C "$cg_r_" "$STORY_F" "$cg_b_" "$cg_run_" 2>&1)" && cg_wr_=0 || cg_wr_=$?
    case "$cg_wr_" in
      0)
        if [ "$cg_lw_" != lead ]; then
          if [ "$cg_o_" = serial ]; then cg_wm_="record the story's dispatch with 'merge-review-shards.sh --record-dispatch s<N>-<idx> <dispatch sha>' from the lead checkout and re-run with --lead-range, so the base is the lead's"
          else cg_wm_="record the partition with 'merge-review-shards.sh --record-partition <shard-dir>' from the lead checkout at the gate-2 partition, so the base is the lead's"; fi
          refuse_to "$cg_o_" "$cg_f_ 'Canonical run: $cg_run_' claims a canonical-run waiver (${cg_wv_}), and the base $cg_b_ it is read at was not written by the lead; a waiver is honoured only over a lead-written base: $cg_wm_"
        fi
        return 0 ;;
      1) : ;;
      *) refuse_to "$cg_o_" "$cg_f_ 'Canonical run: $cg_run_': the canonical-run waiver test could not decide over $STORY_F at $cg_b_ (exit $cg_wr_: ${cg_wv_}); repair the story or the range and check again" ;;
    esac
    cg_ro_="$(mrs_sib "$RO" ro_main paths -C "$cg_r_" "$STORY_F" "$cg_b_" "$cg_z_" 2>&1)" \
      || refuse_to "$cg_o_" "$cg_f_ 'Canonical run: ${cg_run_:-<empty>}' claims the record-only exemption, and $cg_b_..$cg_z_ is not record-only for $STORY_F (${cg_ro_}); run the canonical full collection and record it, or waive it from planning: a '- **<AC-id>** waives the canonical run: <reason>' entry under '## Canonical-run waivers' in the story at the base, claimed as 'Canonical run: none, <AC-id> waives it'"
    return 0
  fi
  cg_rf_="$(mrs_sib "$RO" ro_main run-filter "$cg_run_" ${cg_c_:+"$cg_c_"})" \
    || refuse_to "$cg_o_" "$cg_f_ 'Canonical run: $cg_run_' $cg_rf_; the canonical run is the full collection the project's conventions declare${cg_c_:+ ($cg_c_)}"
  cg_res_="$(mrs_sib "$RO" ro_main label 'Canonical result:' < "$cg_f_")" \
    || refuse_to "$cg_o_" "$cg_f_ reads PASS with no 'Canonical result:' line; a PASS waits for the canonical run's summary line: write 'Canonical result: <its counts>'"
  grep -qiE 'not[[:space:]]+finished|in[[:space:]]+progress|still[[:space:]]+running' <<<"$cg_res_" \
    && refuse_to "$cg_o_" "$cg_f_ 'Canonical result: $cg_res_' says the run has not finished; a PASS waits for the run's summary line"
  grep -qiE '[0-9]+[[:space:]]+(passed|failed|collected|errors?)([^A-Za-z]|$)' <<<"$cg_res_" \
    || refuse_to "$cg_o_" "$cg_f_ 'Canonical result: $cg_res_' carries no count; copy the run's summary line (e.g. '812 passed, 3 skipped')"
  # THE RUN RECORD (header): the result is a recorded run's, in an era whose qa.md prescribes --record-run.
  run_bind "$cg_f_" "$cg_o_" "$cg_res_" "$cg_c_" "$cg_run_"
  return 0
}

adv_gate() {
  ad_o_="$(awk '
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
    !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    f { next }
    /^advisor:/ { n++; if (n == 1) { v = $0; sub(/^advisor:[ \t]*/, "", v); sub(/[ \t\r]+$/, "", v); gsub(/[ \t]+/, "_", v); av = v }; next }
    /^[ \t>*_`+-]*([0-9]+\.[ \t]*)?[ \t>*_`+-]*advisor[*_` \t]*:/ { if (!m) m = NR }
    END { printf "%d %s %d\n", n + 0, (av == "" ? "-" : av), m + 0 }' "$1")" \
    || refuse_to lead "reading the advisor line of $1 did not run (awk failed); repair the environment in the lead checkout and check again"
  read -r ad_n_ ad_v_ ad_m_ <<<"$ad_o_"
  [ "${ad_n_:-0}" -le 1 ] \
    || refuse "$1 carries $ad_n_ 'advisor:' lines outside a fence; it carries exactly one column-0 'advisor: called' or 'advisor: unavailable'"
  [ "${ad_m_:-0}" = 0 ] \
    || refuse "$1:$ad_m_ is a malformed advisor line (indented, bulleted or decorated); write it bare at column 0 as 'advisor: called' or 'advisor: unavailable' -- not the remediator's bulleted '- advisor: called'"
  if [ "${ad_n_:-0}" = 1 ]; then
    case "$ad_v_" in
      called|unavailable) ;;
      *) refuse "$1 'advisor: ${ad_v_//_/ }' is not called or unavailable; 'called' when an advisor call returned a result, 'unavailable' when the tool was absent or every call errored or was rate-limited" ;;
    esac
    return 0
  fi
  if [ "$ADV_AT" = legacy ]; then
    [ -n "$ADV_LEG" ] || printf 'LEGACY: advisor: line not checked: %s prescribes no %s label\n' "$ADV_AT_PATH" "$ADVISOR_SENTINEL"
    ADV_LEG=1
  else refuse "$1 carries no column-0 'advisor:' line${ADV_WHY}: write 'advisor: called' when an advisor call returned a result, 'advisor: unavailable' when the tool was absent or every call errored or was rate-limited"
  fi
}

# ---- THE CLASS LINE (header: SHARD GRAMMAR, THE CLASS LINE). class_gate <file>: one function for the
# per-shard check and --check-serial, both gates. Fences are read as adv_gate reads them.
class_gate() {
  [ -n "$CLASS_SET" ] || return 0
  cg_o_="$(CG_SET=" $CLASS_SET" awk '
    function close_f(   i, n, a, e) {
      if (inf && ncls == 0) print "ABSENT\t" fl
      if (inf && nfl > 1) print "FDUP\t" fln2
      else if (inf && nfl == 1) {
        if (cv != "CODE" && cv != "TEST") print "FNC\t" fln1 "\t" cv
        else if (fv == "") print "FEMPTY\t" fln1
        else { n = split(fv, a, /, /)
               for (i = 1; i <= n; i++) { e = a[i]
                 if (e == "" || e ~ /[`:,[:blank:]]/ || e ~ /^\// || e ~ /^\.\// || e ~ /(^|\/)\.\.(\/|$)/) { print "FBAD\t" fln1 "\t" e; break }
                 print "FPATH\t" fln1 "\t" e } } }
      inf = 0; ncls = 0; nfl = 0; cv = ""; fv = ""
    }
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
    !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    f { next }
    /^# / || /^## / { close_f(); fs = ($0 ~ /^## [ \t]*[Ff]indings/); sev = 0; next }
    /^### / { close_f(); h = tolower(substr($0, 5)); sub(/^[ \t*]+/, "", h); sev = fs && (h ~ /^(critical|important)/); next }
    /^#### / { close_f(); if (sev) { inf = 1; fl = NR }; next }
    inf && /^Class:/ { ncls++; v = $0; sub(/^Class:[ \t]*/, "", v); sub(/[ \t\r]+$/, "", v)
                       if (ncls == 1) cv = v
                       if (ncls > 1) print "DUP\t" NR
                       else if (v == "" || v ~ /[ \t]/ || index(ENVIRON["CG_SET"] " ", " " v " ") == 0) print "BAD\t" NR "\t" v }
    inf && /^Files:/ { nfl++; if (nfl == 1) { fln1 = NR; v = $0; sub(/^Files:[ \t]*/, "", v); sub(/[ \t\r]+$/, "", v); fv = v } else fln2 = NR }
    END { close_f() }' "$1")" \
    || refuse_to lead "reading the Class lines of $1 did not run (awk failed); repair the environment in the lead checkout and check again"
  cg_fp_=""
  while IFS="$TAB" read -r cg_k_ cg_l_ cg_v_; do
    case "$cg_k_" in
      ABSENT) continue ;; # an unclassed finding is accepted; partition-review-diff.sh --route sends the next pass full
      FDUP) refuse "$1:$cg_l_ is a second 'Files:' line in one finding; a CODE or TEST finding carries one, its paths separated by ', '" ;;
      FNC) refuse "$1:$cg_l_ is a 'Files:' line on a Class ${cg_v_:-<none>} finding; only a CODE or TEST finding names its files" ;;
      FEMPTY) refuse "$1:$cg_l_ 'Files:' names no path; write 'Files: <repo-relative path>[, <repo-relative path>...]', or no Files: line at all" ;;
      FBAD) refuse "$1:$cg_l_ 'Files:' entry '$cg_v_' is not a bare repo-relative path (no backtick, ':', ',' or blank inside an entry, no leading '/' or './', no '..'); entries are separated by ', '" ;;
      FPATH) cg_fp_="$cg_fp_$cg_l_$TAB$cg_v_$NL_" ;;
      DUP) refuse "$1:$cg_l_ is a second 'Class:' line in one finding; a Critical or Important finding carries one, a member of ${CLASS_SET% } ($ROLE_NAME's template)" ;;
      BAD) refuse "$1:$cg_l_ 'Class: $cg_v_' is not one of ${CLASS_SET% } ($ROLE_NAME's template); TEST is code-class, and a finding admitting any code fix is CODE" ;;
    esac
  done <<<"$cg_o_"
  # THE FILES LINE's path rule needs the frozen sha, so it runs only where a manifest names one (the
  # merge and --check-shard, never --check-serial). Read lazily: a shard naming no file pays nothing.
  [ -n "$cg_fp_" ] && [ -n "${M_SHA:-}" ] || return 0
  if [ -z "${FILES_KNOWN:-}" ]; then
    { git -C "$M_WT" -c core.quotePath=false ls-tree -r --name-only "$M_SHA" && git -C "$M_WT" -c core.quotePath=false diff --name-only --no-renames "${M_BASE}..${M_SHA}"; } \
      > "$T/files-known" 2>/dev/null < /dev/null \
      || refuse_to lead "cannot list the files tracked at $M_SHA or changed in ${M_BASE}..${M_SHA} in $M_WT, so no Files: path can be checked"
    FILES_KNOWN=1
  fi
  while IFS="$TAB" read -r cg_l_ cg_v_; do
    [ -n "$cg_v_" ] || continue
    grep -qxF -- "$cg_v_" "$T/files-known" \
      || refuse "$1:$cg_l_ 'Files:' entry '$cg_v_' is neither tracked at the frozen sha $M_SHA nor a path the range ${M_BASE:0:12}..${M_SHA:0:12} changes; write the full repo-relative path"
  done <<<"$cg_fp_"
}

mf() { awk -F'\t' -v k="$1" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }' "$MF"; }

# A pass marker is a decimal integer >= 2 with no leading zero; pass 1 carries none.
pass_ok() { case "$1" in ""|0*|1|*[!0-9]*) return 1 ;; esac; return 0; }

pass_name() { if [ -n "$1" ]; then printf 'pass %s' "$1"; else printf 'pass 1 (no marker)'; fi; }

norm_ord() { # "003" -> 03 at width W; empty unless digits within 1..K
  case "$1" in ""|*[!0-9]*) return 0 ;; esac
  local n=$((10#$1))
  [ "$n" -ge 1 ] && [ "$n" -le "$K" ] || return 0
  printf '%0*d' "$W" "$n"
}

# THE DELIVERED SHAPE (header: THE CROSS SHARDS). XTABLE_KEYS is the table's grouped spelling and
# names what a `cross-<g>` may be; CROSS_KEYS, CROSS_FIRST and XG are the shape the set DELIVERED --
# the table's until the staging (or --check-shard's target) reads a lone `cross.md`, then `cross`,
# `cross` and 1. Every set-level reader below reads these three, never G.
cross_shape() { # <grouped|lone>
  if [ "$1" = lone ]; then CROSS_KEYS="cross"; XG=1; else CROSS_KEYS="$XTABLE_KEYS"; XG="$G"; fi
  CROSS_FIRST="${CROSS_KEYS%% *}"
}

is_cross() { case "$1" in cross|cross-*) return 0 ;; esac; return 1; }

# ---- THE SHARD KEY: one grammar, read by the staging below, by --check-shard's target and by the
# marker's key check (d). <basename> -> KEY_OF; rc 1 not a shard name, rc 2 an ordinal outside 1..K.
key_of_name() {
  KEY_OF=""
  case "$1" in
    cross.md) KEY_OF="cross" ;;
    cross-*.md)
      kn_g_="${1#cross-}"; kn_g_="${kn_g_%.md}"
      case "$kn_g_" in ""|*[!0-9]*|??????????*) return 1 ;; esac
      KEY_OF="cross-$((10#$kn_g_))" ;;
    *.md)
      case "${1%.md}" in ""|*[!0-9]*) return 1 ;; esac
      KEY_OF="$(norm_ord "${1%.md}")"
      [ -n "$KEY_OF" ] || return 2 ;;
    *) return 1 ;;
  esac
  return 0
}

key_refuse() { # <rc of key_of_name> <path> -- the staging's own refusal texts, owner lead
  if [ "$1" -eq 2 ]; then b_="$(basename "$2")"; refuse "$2 names ordinal ${b_%.md}, outside 1..$K"; fi
  refuse "$2 is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)"
}

has_marker() {  # $1 = path
  MT_="$MARK_TOKEN" awk '
    # A fence opens on a run of 3+ backticks (info string carrying no backtick) or 3+ tildes; it closes only on a run of the SAME
    # character at least as long, with nothing but blanks after it.
    match($0, /^[ \t]*(```+|~~~+)/) {
      r = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", r)
      if (fc == "") { if (!(substr(r, 1, 1) == "`" && substr($0, RSTART + RLENGTH) ~ /`/)) { fc = substr(r, 1, 1); fl = length(r) } }
      else if (substr(r, 1, 1) == fc && length(r) >= fl && substr($0, RSTART + RLENGTH) ~ /^[ \t\r]*$/) { fc = ""; fl = 0 }
    }
    NF { l = $0 }
    END { exit ((fc == "" && l !~ /\r/ && index(l, ENVIRON["MT_"]) == 1) ? 0 : 1) }' "$1" 2>/dev/null
}

content_hash() {  # $1 = path -> a content hash, empty when unreadable
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else cksum < "$1" 2>/dev/null | tr -d ' \t'; fi
}

seal_body() {  # $1 = path, $2 = 1 to keep the last non-blank line -> bytes on stdout
  awk -v k="${2:-0}" 'NF { L = NR } { a[NR] = $0 } END { if (k == 1) L++; for (i = 1; i < L; i++) print a[i] }' "$1" 2>/dev/null
}

seal_of() {
  so_s_="$(awk 'NF { l = $0 } END { n = split(l, w, /[ \t]+/); f = "N"
    for (i = 1; i <= n; i++) if (w[i] ~ /^sha=/) { f = "Y"; s = substr(w[i], 5) }; print f s }' "$1" 2>/dev/null)"
  case "$so_s_" in
    Y*) so_s_="${so_s_#Y}" ;;
    *) SEAL_V="legacy"; return 2 ;;
  esac
  so_d_="$(seal_body "$1" | content_hash /dev/stdin)"
  if [ -n "$so_s_" ] && [ -n "$so_d_" ] && [ "$so_s_" = "$so_d_" ]; then SEAL_V="sealed"; return 0; fi
  SEAL_V="broken"; return 1
}

engine_at_sha() {
  [ -z "$ENGINE" ] || return 0
  ENGINE="unreadable"
  command -v git >/dev/null 2>&1 || return 0
  git --no-replace-objects -C "$M_WT" rev-parse -q --verify "${M_SHA}^{commit}" > /dev/null 2>&1 < /dev/null || return 0
  for ea_p_ in scripts/ai-dlc/wait-for-deliverable.sh core/scripts/wait-for-deliverable.sh; do
    git --no-replace-objects -C "$M_WT" cat-file -e "${M_SHA}:${ea_p_}" 2> /dev/null < /dev/null || continue
    git --no-replace-objects -C "$M_WT" show "${M_SHA}:${ea_p_}" > "$T/engine" 2> /dev/null < /dev/null || return 0
    ENGINE_AT="$ea_p_"
    if grep -qF -- '# MARK-KEY-WRITER v1' "$T/engine"; then ENGINE="present"; else ENGINE="absent"; fi
    return 0
  done
  return 0
}

qa_at_sha() {
  [ -z "$QA_AT" ] || return 0
  QA_AT="unreadable"
  command -v git >/dev/null 2>&1 || return 0
  git --no-replace-objects -C "$M_WT" rev-parse -q --verify "${M_SHA}^{commit}" > /dev/null 2>&1 < /dev/null || return 0
  for qa_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
    git --no-replace-objects -C "$M_WT" cat-file -e "${M_SHA}:${qa_p_}" 2> /dev/null < /dev/null || continue
    git --no-replace-objects -C "$M_WT" show "${M_SHA}:${qa_p_}" > "$T/qa-at" 2> /dev/null < /dev/null || return 0
    QA_AT_PATH="$qa_p_"
    if [ -z "$(lift_containers "$T/qa-at" | tr -d ' ')" ]; then QA_AT="legacy"; else QA_AT="severity"; fi
    return 0
  done
  return 0
}

adv_at_sha() {
  [ -z "$ADV_AT" ] || return 0
  ADV_AT="unreadable"
  ADV_WHY="; $ROLE_NAME cannot be read at the frozen sha $M_SHA in $M_WT (tracked, or on disk, in either layout), so the shard cannot be shown to predate the line"
  command -v git >/dev/null 2>&1 || return 0
  if git --no-replace-objects -C "$M_WT" rev-parse -q --verify "${M_SHA}^{commit}" > /dev/null 2>&1 < /dev/null; then
    for ad_p_ in ".claude/team-roles/$ROLE_NAME" "core/team-roles/$ROLE_NAME"; do
      git --no-replace-objects -C "$M_WT" cat-file -e "${M_SHA}:${ad_p_}" 2> /dev/null < /dev/null || continue
      git --no-replace-objects -C "$M_WT" show "${M_SHA}:${ad_p_}" > "$T/adv-at" 2> /dev/null < /dev/null || return 0
      ADV_AT_PATH="$ad_p_ at $M_SHA"
      if adv_has "$T/adv-at"; then ADV_AT="present"; ADV_WHY="; $ADV_AT_PATH prescribes it"; else ADV_AT="legacy"; fi
      return 0
    done
  fi
  # Untracked at the frozen sha (a consumer that does not commit .claude/team-roles/): the on-disk copy.
  for ad_p_ in ".claude/team-roles/$ROLE_NAME" "core/team-roles/$ROLE_NAME"; do
    [ -r "$M_WT/$ad_p_" ] || continue
    ADV_AT_PATH="$M_WT/$ad_p_ (on disk, untracked at $M_SHA)"
    if adv_has "$M_WT/$ad_p_"; then ADV_AT="disk"
      ADV_WHY="; $ROLE_NAME is untracked at $M_SHA, read on disk at $M_WT/$ad_p_, which prescribes it. The on-disk copy may postdate the shards: commit .claude/team-roles/ so the frozen sha decides, or write the line"
    else ADV_AT="legacy"; fi
    return 0
  done
  return 0
}

# ---- per-shard parse --------------------------------------------------------------------
# Emits: R <n> <first value>   V <n> <first value>   X <line> <n-parts-lines> <parts>   C <findings>
#        F <has ## Findings>   S <first stray parts: line>   A <## Acceptance Criteria count>
#        D <## Deferred ACs count>   (A and D are read under --gate qa only)
#        HO <line> <finding line> <AC>   HR <line> <finding line> <ordinal> <AC> <result> [extra]
#        H <first stray handover:/handover-run: line>   HM <first malformed hand-over line>
#        N <handovers: count> <first value>   (HO, HR, H, HM, N and X's last two fields --
#        handover: and handover-run: lines in that finding -- are read under both gates)
#        K <findings under the Critical container> <findings under the Important container>
#          <line of the first `#### ` under ## Findings with no `### ` above it there, 0 if none>
#        (the container of a `#### ` is the last `### ` above it inside ## Findings, classed by a
#        case-insensitive PREFIX match of its text against CRIT_NAME / IMP_NAME, lifted above; any
#        other container, or none, is "other". C counts every finding whatever its container.)
parse_shard() {
  PS_CRIT_="$CRIT_NAME" PS_IMP_="$IMP_NAME" awk '
    function cls(t, n) { n = tolower(n); return (n != "" && index(t, n) == 1 && substr(t, length(n) + 1, 1) !~ /[a-z0-9]/) }
    function flush() { if (fl > 0) printf "X %d %d %s %d %d\n", fl, fn, (fst == "" ? "-" : fst), fh + 0, fr + 0; fl = 0 }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    fence { next }
    /^reviewed-sha:/ { nr++; if (nr == 1) { v = $0; sub(/^reviewed-sha:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); rv = v } }
    /^shard-verdict:/ { nv++; if (nv == 1) { v = $0; sub(/^shard-verdict:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); vv = v } }
    /^handovers:/ { nh++; if (nh == 1) { v = $0; sub(/^handovers:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); gsub(/[ \t]+/, "_", v); hv = v } }
    { lc = tolower($0) }
    lc ~ /^###?[ \t]+acceptance criteria/ { nac++ }
    lc ~ /^###?[ \t]+deferred/ { nda++ }
    /^## / { flush(); infind = ($0 ~ /^## Findings[ \t]*$/); if (infind) hasfind = 1; cc = ""; hasc = 0; next }
    /^### / { flush(); t = lc; sub(/^###[ \t]+/, "", t); hasc = 1
              cc = cls(t, ENVIRON["PS_CRIT_"]) ? "crit" : (cls(t, ENVIRON["PS_IMP_"]) ? "imp" : ""); next }
    infind && /^#### / { flush(); fl = NR; fn = 0; fst = ""; fh = 0; fr = 0; nfind++
                         if (!hasc && !unc) unc = NR
                         if (cc == "crit") ncrit++; else if (cc == "imp") nimp++; next }
    infind && fl > 0 && /^parts:/ { fn++; v = $0; sub(/^parts:[ \t]*/, "", v); gsub(/[ \t]+/, "", v); fst = v; next }
    infind && fl > 0 && /^handover:/ { fh++; v = $0; sub(/^handover:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
                                       printf "HO %d %d %s\n", NR, fl, (v == "" ? "-" : v); next }
    infind && fl > 0 && /^handover-run:/ { fr++; v = $0; sub(/^handover-run:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
                                           printf "HR %d %d %s\n", NR, fl, (v == "" ? "-" : v); next }
    lc ~ /^[ \t]*([-*+][ \t]+)?handover(-run)?[ \t]*:/ { if (!hstray) hstray = NR; next }
    lc ~ /^[ \t>*_`+-]*([0-9]+\.[ \t]*)?[ \t>*_`+-]*hand[- ]?over(-run)?[*_` \t]*:/ \
      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over[^a-z0-9]+[a-z0-9][a-z0-9._-]*[0-9][a-z0-9._-]*([^a-z0-9._-]|$)/ \
      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over-run[^a-z0-9]+[0-9]+[^a-z0-9]+[a-z0-9]/ { if (!hbad) hbad = NR }
    /^[ \t]*([-*+][ \t]+)?parts:/ { if (!stray) stray = NR }
    END { flush(); printf "R %d %s\n", nr + 0, (rv == "" ? "-" : rv); printf "V %d %s\n", nv + 0, (vv == "" ? "-" : vv); printf "C %d\n", nfind + 0
          printf "F %d\n", hasfind + 0; printf "S %d\n", stray + 0; printf "H %d\n", hstray + 0; printf "HM %d\n", hbad + 0
          printf "N %d %s\n", nh + 0, (hv == "" ? "-" : hv)
          printf "A %d\n", nac + 0; printf "D %d\n", nda + 0; printf "K %d %d %d\n", ncrit + 0, nimp + 0, unc + 0 }
  ' "$1"
}

# same_set <file> <label> <ordinals, blank-separated> -> 0 when a column-0 `<label>:` line outside
# a fence in <file> cites exactly that set of ordinals (order, padding and repeats free).
same_set() {
  awk -v lab="$2:" -v want="$3" '
    BEGIN { n = split(want, w, /[ \t]+/); for (i = 1; i <= n; i++) if (w[i] != "") { W[w[i] + 0] = 1; nw++ } }
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
    !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    f || index($0, lab) != 1 { next }
    { v = substr($0, length(lab) + 1); m = split(v, a, /[ ,\t]+/); delete G; ng = 0; ok = 1
      for (i = 1; i <= m; i++) if (a[i] ~ /^[0-9]+$/ && !((a[i] + 0) in G)) { G[a[i] + 0] = 1; ng++; if (!((a[i] + 0) in W)) ok = 0 }
      if (ok && ng == nw) { hit = 1; exit } }
    END { exit !hit }' "$1"
}

# ---- THE PER-SHARD CHECK: one function, called by the merge for every shard in key order and by
# --check-shard for its one target, so the two cannot apply different grammars. Reads the globals
# `key` and `sf` (never positional parameters: the body re-binds them with `set --`), and `scn`, the
# marker count to hold the shard to (empty: no marker and no --findings). Every refusal inside it
# names `key` as its owner unless the site names another.
check_shard() {
  OWNER="$key"
  P="$T/parse.$key"
  parse_shard "$sf" > "$P" || refuse "parsing $sf did not run"
  set -- $(awk '$1 == "R" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] || refuse "$sf carries ${1:-0} 'reviewed-sha:' line(s) outside a fence; a shard carries exactly one"
  [ "${2:-}" = "$M_SHA" ] || refuse "$sf reviewed ${2:-<none>}, not the frozen sha $M_SHA; the shard reviewed another tree"
  set -- $(awk '$1 == "V" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] || refuse "$sf carries ${1:-0} 'shard-verdict:' line(s) outside a fence; a shard carries exactly one"
  v="${2:-}"; r="$(rank "$v")"
  [ "$r" -gt 0 ] || refuse "$sf shard-verdict '${v:-<none>}' is not one of $RANKED"
  if [ "$r" -gt "$WORST_R" ]; then WORST_R="$r"; WORST="$v"; fi
  printf '| %s | %s |\n' "$key" "$v" >> "$T/vtable" || refuse "cannot stage the verdict table"
  adv_at_sha; adv_gate "$sf"
  class_gate "$sf"
  nf="$(awk '$1 == "C" { print $2 }' "$P")"; NFIND=$((NFIND + ${nf:-0}))
  # The marker's count against the findings parsed here: a shard truncated after its marker, or
  # marked before its findings, disagrees. `scn` is set by the caller (the staged marker, or under
  # --check-shard the target's own marker, else --findings).
  [ -z "$scn" ] || [ "$scn" = "${nf:-0}" ] \
    || refuse "$sf ends in 'seat-complete: ... findings=$scn' but its ## Findings section heads ${nf:-0} finding(s); the marker is written once, last, counting the shard's findings"
  [ "$(awk '$1 == "F" { print $2 }' "$P")" = "1" ] \
    || refuse "$sf carries no '## Findings' section; a shard reports its findings there, even when it has none"
  sl="$(awk '$1 == "S" { print $2 }' "$P")"
  [ "${sl:-0}" = "0" ] \
    || refuse "$sf:$sl carries a 'parts:' line outside a '#### ' finding under '## Findings' (indented, bulleted, or under another section); every finding is a '#### ' heading there"
  if [ "$GATE" = "qa" ]; then
    nac="$(awk '$1 == "A" { print $2 }' "$P")"; nda="$(awk '$1 == "D" { print $2 }' "$P")"
    if [ "$key" = "$CROSS_FIRST" ]; then
      [ "${nac:-0}" = "1" ] \
        || refuse "$sf carries ${nac:-0} '## Acceptance Criteria' section(s) outside a fence; the cross shard carries exactly one, the story's per-AC table"
      [ "${nda:-0}" -le 1 ] \
        || refuse "$sf carries ${nda:-0} '## Deferred ACs' sections outside a fence; the cross shard carries at most one"
    elif is_cross "$key"; then
      [ "${nac:-0}" = "0" ] \
        || refuse "$sf ($key) carries a '## Acceptance Criteria' section; only $CROSS_FIRST, the execution owner, writes the per-AC table"
      [ "${nda:-0}" = "0" ] \
        || refuse "$sf ($key) carries a '## Deferred ACs' section; only $CROSS_FIRST, the execution owner, writes the deferred-AC discharge predicates"
    else
      [ "${nac:-0}" = "0" ] \
        || refuse "$sf (part shard $key) carries a '## Acceptance Criteria' section; only the cross shard writes the per-AC table"
      [ "${nda:-0}" = "0" ] \
        || refuse "$sf (part shard $key) carries a '## Deferred ACs' section; only the cross shard writes the deferred-AC discharge predicates"
    fi
  fi

  { # HAND-OVERS, read under both gates (header)
    hl="$(awk '$1 == "H" { print $2 }' "$P")"
    [ "${hl:-0}" = "0" ] \
      || refuse "$sf:$hl carries a 'handover:' or 'handover-run:' line outside a '#### ' finding under '## Findings' (indented, bulleted, another case, or under another section); each sits at column 0 inside its finding"
    hm="$(awk '$1 == "HM" { print $2 }' "$P")"
    # THE DECLARED COUNT, before the malformed-line refusal: a hand-over spelled any way the parser
    # does not read is not counted, so it disagrees with the count its writer declared, and this
    # refusal needs no list of bad spellings. A count that agrees leaves the precise message below.
    # READ, NEVER WORD-SPLIT: `set -- $(...)` globbed the value, so `handovers: ?` became `0` in a
    # cwd holding a file named `0` and merged PASS over a hidden hand-over (measured).
    nhd=""; hdv=""
    read -r nhd hdv <<<"$(awk '$1 == "N" { print $2, $3 }' "$P")"
    nhd="${nhd:-0}"; hdv="${hdv:--}"
    nho_s="$(grep -c '^HO ' "$P")" || nho_s=0
    hmnote=""; [ "${hm:-0}" = "0" ] || hmnote=" ($sf:$hm is a malformed hand-over line)"
    if is_cross "$key"; then
      [ "$nhd" = "0" ] \
        || refuse "$sf carries a 'handovers:' line; only a part shard declares a hand-over count, the cross shard records its replays as 'handover-run:'"
    else
      [ "$nhd" = "1" ] \
        || refuse "$sf (part shard $key) carries $nhd 'handovers:' line(s) outside a fence; a part shard carries exactly one column-0 'handovers: <n>', 0 when it handed nothing over"
      case "$hdv" in *[!0-9]*|??????????*) refuse "$sf (part shard $key) 'handovers: ${hdv//_/ }' is not a non-negative integer" ;; esac
      [ "$((10#$hdv))" -eq "$nho_s" ] \
        || refuse "$sf (part shard $key) declares 'handovers: $hdv' but the merge parsed $nho_s 'handover:' line(s); a hand-over is counted only as a bare column-0 'handover: <AC-id>' line inside its '#### ' finding$hmnote"
    fi
    [ "${hm:-0}" = "0" ] \
      || refuse "$sf:$hm is a malformed hand-over line (decorated, quoted, hyphenated or missing its colon); a hand-over is written bare as 'handover: <AC-id>' or 'handover-run: <ordinal> <AC-id> <result>' at column 0"
    while read -r tag hline hfl a1 a2 a3 a4; do
      case "$tag" in
        HO)
          ! is_cross "$key" || refuse "$sf:$hline carries a 'handover:' line; only a part shard hands an AC over, the cross shard records the replay as 'handover-run:'"
          [ -z "${a2:-}" ] || refuse "$sf:$hline handover: '${a1:-} ${a2:-}' names more than one AC; a hand-over line names exactly one <AC-id>"
          [[ ${a1:-} =~ $RE_AC ]] || refuse "$sf:$hline handover: '${a1:-}' is not an <AC-id> (one token beginning with a letter or digit)"
          printf '%s %s\n' "$key" "$a1" >> "$T/hand" || refuse "cannot stage the hand-over set" ;;
        HR)
          is_cross "$key" || refuse "$sf:$hline (part shard $key) carries a 'handover-run:' line; only the cross shard runs a handed-over replay"
          [ "$key" = "$CROSS_FIRST" ] \
            || refuse "$sf:$hline ($key) carries a 'handover-run:' line; only $CROSS_FIRST, the execution owner, runs a handed-over replay in the frozen worktree"
          o="$(norm_ord "${a1:-}")"
          [ -n "$o" ] && [[ ${a2:-} =~ $RE_AC ]] && [ -z "${a4:-}" ] \
            || refuse "$sf:$hline handover-run: '${a1:-} ${a2:-} ${a3:-} ${a4:-}' is not <ordinal 1..$K> <AC-id> <result>"
          case "${a3:-}" in
            RED) ;;
            GREEN-SURVIVED|NO-BASELINE) FORCE="${FORCE:-$o $a2 $a3}" ;;
            *) refuse "$sf:$hline handover-run result '${a3:-}' is not RED, GREEN-SURVIVED or NO-BASELINE" ;;
          esac
          printf '%s %s\n' "$o" "$a2" >> "$T/runs" || refuse "cannot stage the hand-over replay set"
          printf '%s %s\n' "$hfl" "$o" >> "$T/runords" || refuse "cannot stage the hand-over replay set"
          printf '| %s | %s | %s |\n' "$o" "$a2" "$a3" >> "$T/htable" || refuse "cannot stage the hand-over replay table" ;;
      esac
    done < "$P"
  } # end HAND-OVERS

  while read -r tag line nlines cited nho nhr; do
    [ "$tag" = "X" ] || continue
    [ "$nlines" = "1" ] || refuse "$sf:$line finding carries $nlines 'parts:' lines; each finding carries exactly one"
    [[ $cited =~ $RE_CITED ]] || refuse "$sf:$line parts: '$cited' is not <ordinal>[, <ordinal>...]"
    distinct=""
    for c in $(printf '%s' "$cited" | tr ',' ' '); do
      o="$(norm_ord "$c")"
      [ -n "$o" ] || refuse "$sf:$line cites part $c, outside 1..$K"
      case " $distinct " in *" $o "*) ;; *) distinct="$distinct $o" ;; esac
    done
    [ "${nho:-0}" -le 1 ] || refuse "$sf:$line finding carries $nho 'handover:' lines; a hand-over finding names exactly one AC"
    if is_cross "$key" && [ "${nhr:-0}" -gt 0 ]; then
      want="$(awk -v f="$line" '$1 == f { print $2 }' "$T/runords" | sort -u | tr '\n' ' ')"
      got="$(printf '%s\n' $distinct | sort -u | tr '\n' ' ')"
      [ "$want" = "$got" ] \
        || refuse "$sf:$line (cross shard) cites$distinct but its 'handover-run:' lines name ${want% }; a hand-over replay finding cites exactly the parts it ran replays for"
      continue
    fi
    set -- $distinct
    if is_cross "$key"; then
      [ $# -ge 2 ] || refuse "$sf:$line (cross shard) cites only$distinct; a cross finding cites two or more parts, a one-part finding belongs to that part's shard"
      # THE OWNER RULE: the one group --cross-owner names, never any other that also covers it.
      own="$(mrs_sib "$XPART" pdoc_main --cross-owner "$K" "$(printf '%s' "${distinct# }" | tr ' ' ',')" 2> "$T/own.err" < /dev/null)" \
        || refuse "partition-document.sh --cross-owner $K on$distinct failed: $(head -1 "$T/own.err")"
      if [ "$XG" -eq 1 ]; then ownk="cross"; else ownk="cross-$own"; fi
      # A cross reviewer reads the whole diff and may cite any part, so a finding outside its
      # owner's shard is accepted -- unless the owner's shard carries the IDENTICAL cited set.
      if [ "$ownk" != "$key" ]; then
        # The owner's file: the staged one under the merge; under --check-shard the sibling in the
        # directory, read ONLY when it is finished and sealed (has_marker, and seal_of reads sealed)
        # -- an owner still being written is not yet a duplicate, and the merge stays the backstop.
        osf=""
        if [ -z "$CHECK" ]; then osf="$(awk -F'\t' -v k="$ownk" '$1 == k { print $2; exit }' "$T/shards")"
        else
          for o_f_ in "$SDIR"/cross*.md; do
            [ -f "$o_f_" ] && key_of_name "$(basename "$o_f_")" && [ "$KEY_OF" = "$ownk" ] || continue
            has_marker "$o_f_" && seal_of "$o_f_" && osf="$o_f_"; break
          done
        fi
        [ -z "$osf" ] || ! same_set "$osf" parts "$distinct" \
          || collect_dup "$sf:$line ($key) cites$distinct, a finding owned by $ownk (partition-document.sh --cross-owner), whose shard carries the identical set; one finding is reported once, or the merged verdict and finding count depend on the cover"
      fi
    else
      [ $# -eq 1 ] && [ "$1" = "$key" ] \
        || refuse "$sf:$line (shard $key) cites$distinct; a part shard reports only findings citing its own part alone"
    fi
  done < "$P"

  # ---- THE VERDICT IS BACKED BY THE SHARD'S OWN FINDINGS (header: VERDICT BACKING). After every
  # grammar and owner refusal, so a finding the remedy tells the seat to file is one this shard may own.
  read -r kc_ ki_ ku_ <<<"$(awk '$1 == "K" { print $2, $3, $4 }' "$P")"
  kc_="${kc_:-0}"; ki_="${ki_:-0}"; ku_="${ku_:-0}"; best_="${RANKED%% *}"
  # THE SEVERITY BOUNDARY: a qa shard of a set frozen over a qa.md that declared no container is
  # held to the count-only rule, with a LEGACY line, whatever the current qa.md declares.
  sev_="$SEV"
  if [ "$SEV" = 1 ] && [ "$GATE" = qa ]; then
    qa_at_sha
    if [ "$QA_AT" = legacy ]; then sev_=0
      printf 'LEGACY: %s held to the count-only QA rule only because the frozen sha %s'"'"'s %s declares no severity containers\n' "$sf" "$M_SHA" "$QA_AT_PATH"
    fi
  fi
  if [ "$sev_" = 1 ]; then
    [ "$ku_" = 0 ] \
      || refuse "$sf:$ku_ is a '#### ' finding under '## Findings' with no '### ' container above it; every finding sits under '### $CRIT_NAME', '### $IMP_NAME' or '### $SUG_NAME', the $ROLE_NAME ## Findings template: put it under the container its severity names"
    case "$v" in
      NEEDS_REWORK|BLOCKED)
        [ "$((kc_ + ki_))" -ge 1 ] \
          || refuse "$sf carries 'shard-verdict: $v' but no '#### ' finding under '### $CRIT_NAME' or '### $IMP_NAME' in its '## Findings'; a shard's verdict is backed by its own findings. If the finding belongs to another shard, set 'shard-verdict: $best_' here and let that shard's verdict carry it; otherwise file the finding that makes it $v here, as a '#### ' heading under '### $CRIT_NAME' or '### $IMP_NAME' with a 'parts:' set this shard may own (one the owning group's shard does not already carry), or move the finding this shard already files under '### $SUG_NAME' there" ;;
      APPROVED|PASS)
        [ "$kc_" -eq 0 ] \
          || refuse "$sf carries 'shard-verdict: $v' but $kc_ '#### ' finding(s) under '### $CRIT_NAME'; a Critical finding is not approvable. Either downgrade the finding to '### $IMP_NAME' or '### $SUG_NAME' with the evidence that it is not Critical, or set 'shard-verdict: NEEDS_REWORK'" ;;
    esac
  else
    case "$v" in
      NEEDS_REWORK)
        [ "${nf:-0}" -ge 1 ] \
          || refuse "$sf carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding in its '## Findings'; a shard's verdict is backed by its own findings. If the finding belongs to another shard, set 'shard-verdict: $best_' here and let that shard's verdict carry it; otherwise file the finding that makes it NEEDS_REWORK here, as a '#### ' heading under '## Findings' (any '### ' container, or none) with a 'parts:' set this shard may own (one the owning group's shard does not already carry)" ;;
    esac
  fi

  # ---- THE MARKER'S KEY (d) and the LEGACY rule (header: SEAT-COMPLETE). Not applied when
  # --findings stands in for the marker: --mark drops the old marker and writes its own.
  SEAL_MODE="--legacy"
  mk_l_=""
  [ -n "$CHECK" ] && [ "$CHECK_N_SET" = 1 ] \
    || mk_l_="$(awk 'NF { l = $0 } END { if (l ~ /^seat-complete: /) print l }' "$sf")"
  if [ -n "$mk_l_" ]; then
    set -f; set -- $mk_l_; set +f
    mk_sh_="${4:-}"; mk_k_=""; mk_nk_=0
    for mk_w_ in "$@"; do case "$mk_w_" in key=*) mk_nk_=$((mk_nk_ + 1)); mk_k_="${mk_w_#key=}" ;; esac; done
    if [ "$mk_nk_" -gt 0 ]; then
      [ "$mk_nk_" -eq 1 ] \
        || refuse "$sf's seat-complete marker carries $mk_nk_ 'key=' tokens; the marker --mark writes carries one: re-dispatch the reviewer for that shard"
      key_of_name "$mk_k_.md" && [ "$KEY_OF" = "$key" ] \
        || refuse "$sf's seat-complete marker carries key=$mk_k_, not this shard's key $key (its file name); the marker belongs to another shard: re-dispatch the reviewer for that shard"
      key_of_name "$mk_sh_.md" && [ "$KEY_OF" = "$key" ] \
        || refuse "$sf's seat-complete marker names shard '$mk_sh_', not this shard's key $key (its file name); the <shard> field is the shard's own key: re-dispatch the reviewer for that shard"
      SEAL_MODE=""
    else
      engine_at_sha
      case "$ENGINE" in
        absent) LEGACY_LINE="LEGACY: $sf accepted without key= only because reviewed sha $M_SHA predates the key= engine" ;;
        present) refuse "$sf's seat-complete marker carries no key=, but the frozen sha $M_SHA's $ENGINE_AT is the key= engine, whose --mark always writes key=; the marker was not written by --mark: re-dispatch the reviewer for that shard" ;;
        *) refuse "$sf's seat-complete marker carries no key=, and wait-for-deliverable.sh cannot be read at the frozen sha $M_SHA in $M_WT (in neither scripts/ai-dlc/ nor core/scripts/), so the marker cannot be shown to predate the key= engine: re-dispatch the reviewer for that shard" ;;
      esac
    fi
  else
    # AN UNMARKED SHARD is read against the engine at the frozen sha too: over the key= engine
    # (`present`) it takes the NON-legacy seal, which requires a row, so stripping every marker from
    # a set cannot reopen the legacy window. `absent` or `unreadable` keeps --legacy, as before.
    engine_at_sha
    [ "$ENGINE" != present ] || SEAL_MODE=""
  fi

  # ---- THE CONTENT SEAL (content-seal.sh --review-shard, beside this script) ----------------
  # Skipped under --findings and for a target outside the directory: both are --mark's call, which
  # runs `content-seal.sh --review-shard` (non-legacy) itself over the pre-write bytes (B4).
  if [ -z "$CHECK" ] || { [ "$CHECK_IN" = 1 ] && [ "$CHECK_N_SET" = 0 ]; }; then
  [ -f "$SEAL_SH" ] || refuse_to lead "cannot read the content seal of $sf: $SEAL_SH is absent; reinstall ai-dlc"
  seal_out_="$(mrs_sib "$SEAL_SH" seal_main --review-shard "$sf" $SEAL_MODE 2>&1 < /dev/null)"; seal_rc_=$?
  seal_out_="$(printf '%s' "$seal_out_" | tr '\n' ' ')"; seal_out_="${seal_out_% }"
  case "$seal_rc_:$SEAL_MODE" in
    0:*|3:--legacy) ;;
    1:*) refuse "$seal_out_" ;;
    4:*) refuse_to lead "$sf: the content seal cannot be read in this environment ($seal_out_); the merge needs jq on PATH, the shard inside a git worktree and a ledger that parses: repair the environment in the lead checkout and merge again, never re-dispatch a reviewer for it" ;;
    *) refuse "$sf: content-seal.sh --review-shard${SEAL_MODE:+ $SEAL_MODE} exited $seal_rc_ (${seal_out_:-no output}); a shard whose seal cannot be read is not merged: re-dispatch the reviewer for that shard" ;;
  esac
  fi
  if [ -n "${LEGACY_LINE:-}" ]; then printf '%s\n' "$LEGACY_LINE"; LEGACY_LINE=""; fi
  OWNER="lead"
}

# The owner of a multi-match: every shard whose body matches PAT outside a fence, else the lead.
pat_owners() {
  po_=""
  for key in $ORDINALS $CROSS_KEYS; do
    sf="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/shards")"
    PAT_="$PAT" awk '
      f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
      !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
      f || /^seat-complete: / { next }
      tolower($0) ~ tolower(ENVIRON["PAT_"]) { hit = 1; exit }
      END { exit !hit }' "$sf" && po_="$po_${po_:+ }$key"
  done
  printf '%s' "${po_:-lead}"
}

mrs_main() {
export LC_ALL=C
# Git's repository discovery is the review file's and the manifest's own (`-C`, `--show-toplevel`), never the seat's
# environment: a GIT_WORK_TREE or GIT_DIR left in it would point every read at another checkout (header: THE EXEMPTION).
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
# THE RUN RECORD's era sentinel (header: CANONICAL RUN, THE RUN RECORD): qa.md's prescription of --record-run. Set here,
# inside mrs_main, so --record-partition, --record-run and canon_gate all read it; an empty one would hold every era.
RUN_SENTINEL='column-0 `Canonical result:` copied from `--record-run`'
[ -n "$RUN_SENTINEL" ] || { echo "REFUSED: RUN_SENTINEL is empty [owner: lead]"; exit 2; }
# --record-partition (header: THE PARTITION RECORD) is its own mode, taken before the argument loop.
if [ "$#" -gt 0 ] && [ "$1" = "--record-partition" ]; then OWNER="lead"; shift; pr_record "$@"; exit $?; fi
# --record-run (header: THE RUN RECORD) likewise.
if [ "$#" -gt 0 ] && [ "$1" = "--record-run" ]; then OWNER="lead"; shift; rr_record "$@"; exit $?; fi

# Every refusal names the shard whose file must CHANGE (header: OWNER TAILS). OWNER is `lead`
# outside the per-shard function and that shard's key inside it; refuse_to names it explicitly.
OWNER="lead"
# collect_dup: the owner-duplicate refusal, printed in refuse's exact form but not exiting; every shard
# is still checked, and the run exits 2 at the DUP barrier after the per-shard loop (and after the one
# --check-shard target), so one pass names every duplicate (header: OWNER TAILS).
DUP_N=0
CG_NOTE=""
USAGE="usage: merge-review-shards.sh <shard-dir> --gate code-review|qa --out <review-file> [--story <f>] | <shard-dir> --gate code-review|qa --check-shard <file>.md [--findings <n>] | --check-serial <file> --gate code-review|qa [--story <f> --range <base> <frozen>] | --check-serial <absolute file> --gate qa [--story <f>] --lead-range <seat base> <go-signal sha> | --read-verdict <file> --gate code-review|qa | --record-dispatch s<N>-<story-index> <sha> | --record-partition <qa shard-dir> | --record-run <qa shard-dir> [--dir <subdir>] -- <invocation...> | --record-run <serial review file> --frozen <go-signal sha> [--dir <subdir>] -- <invocation...>"

SDIR=""; GATE=""; OUT=""; CHECK=""; CHECK_N=""; CHECK_N_SET=0; SERIAL=""; STORY_F=""; R_BASE=""; R_FROZEN=""; LEAD=0
SEAT_B=""; RD_NAME=""; RD_SHA=""; RV=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
    --gate) [ "$#" -ge 2 ] || refuse "$USAGE"; GATE="$2"; shift 2 ;;
    --out) [ "$#" -ge 2 ] || refuse "$USAGE"; OUT="$2"; shift 2 ;;
    --check-serial) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "$USAGE"; SERIAL="$2"; shift 2 ;;
    --check-shard) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "$USAGE"; CHECK="$2"; shift 2 ;;
    --read-verdict) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "$USAGE"; RV="$2"; shift 2 ;;
    --findings) [ "$#" -ge 2 ] || refuse "$USAGE"; CHECK_N="$2"; CHECK_N_SET=1; shift 2 ;;
    --story) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "$USAGE"; STORY_F="${2#./}"; shift 2 ;;
    --range) [ "$#" -ge 3 ] && [ -n "$2" ] && [ -n "$3" ] && [ "$LEAD$R_BASE" = 0 ] || refuse "$USAGE"; R_BASE="$2"; R_FROZEN="$3"; shift 3 ;;
    --lead-range) [ "$#" -ge 3 ] && [ -n "$3" ] && [ "$LEAD$R_BASE" = 0 ] || refuse "$USAGE"; LEAD=1; SEAT_B="$2"; R_FROZEN="$3"; shift 3 ;;
    --record-dispatch) [ "$#" -ge 3 ] && [ -n "$2" ] && [ -n "$3" ] || refuse "$USAGE"; RD_NAME="$2"; RD_SHA="$3"; shift 3 ;;
    --*) refuse "unknown flag $1; $USAGE" ;;
    *) [ -z "$SDIR" ] || refuse "unexpected argument $1; $USAGE"; SDIR="$1"; shift ;;
  esac
done
# ---- --record-dispatch (header: CHECK-SERIAL, THE LEAD'S RE-RUN): the dispatch step writes the story's dispatch sha to
# its lead record, once (a rework keeps the original), through the shared record helpers. Run from the lead checkout.
if [ -n "$RD_NAME" ]; then
  [ -z "$SERIAL$SDIR$GATE$OUT$CHECK$STORY_F$R_BASE$R_FROZEN$RV" ] && [ "$LEAD" = 0 ] || refuse "--record-dispatch takes no other argument; $USAGE"
  rd_sha_="$(git --no-replace-objects rev-parse -q --verify "${RD_SHA}^{commit}" 2> /dev/null < /dev/null)" \
    || refuse "--record-dispatch: $RD_SHA is not a commit in $(pwd); pass the sprint-branch HEAD the dev worktree was cut from"
  rd_f_="$(lead_record_path . "$RD_NAME")" || refuse "--record-dispatch: '$RD_NAME' is not s<N>-<story-index>, or $(pwd) is not in a git repository"
  if rd_v_="$(lead_record_get . "$RD_NAME" dispatch)"; then
    printf 'RECORD-KEPT: %s dispatch: %s\n' "$rd_f_" "$rd_v_"; exit 0
  fi
  lead_record_put . "$RD_NAME" dispatch "$rd_sha_" || refuse "--record-dispatch: cannot write $rd_f_"
  printf 'RECORDED: %s dispatch: %s\n' "$rd_f_" "$rd_sha_"; exit 0
fi
if [ -n "$RV" ]; then
  OWNER="serial"
  [ -z "$SERIAL$SDIR$OUT$CHECK$STORY_F$R_BASE$R_FROZEN" ] && [ "$CHECK_N_SET$LEAD" = 00 ] && [ -n "$GATE" ] \
    || refuse "--read-verdict takes only --gate; $USAGE"
  [ -f "$RV" ] || refuse "$RV is not a regular file; name the review file whose verdict is read"
elif [ -n "$SERIAL" ]; then
  OWNER="serial"
  [ -z "$SDIR" ] && [ -z "$OUT" ] && [ -z "$CHECK" ] && [ "$CHECK_N_SET" = 0 ] && [ -n "$GATE" ] \
    || refuse "--check-serial takes only --gate, --story and --range; $USAGE"
  [ -f "$SERIAL" ] || refuse "$SERIAL is not a regular file; write the review file, then check it"
  [ "$LEAD" = 0 ] || [ "$GATE" = qa ] || refuse "--lead-range is read only under --gate qa; $USAGE"
elif [ "$LEAD" = 1 ]; then
  refuse "--lead-range is read only by --check-serial; $USAGE"
elif [ -n "$CHECK" ]; then
  [ -n "$SDIR" ] && [ -n "$GATE" ] && [ -z "$OUT" ] || refuse "--check-shard takes no --out; $USAGE"
  [ -z "$STORY_F$R_BASE" ] || refuse "--story and --range are read only by the qa merge and --check-serial; $USAGE"
  if [ "$CHECK_N_SET" = 1 ]; then
    case "$CHECK_N" in ""|*[!0-9]*|??????????*) refuse "--findings '$CHECK_N' is not a non-negative integer" ;; esac
    CHECK_N="$((10#$CHECK_N))"
  fi
else
  [ "$CHECK_N_SET" = 0 ] || refuse "--findings is read only with --check-shard; $USAGE"
  [ -n "$SDIR" ] && [ -n "$GATE" ] && [ -n "$OUT" ] || refuse "$USAGE"
fi
# The per-gate table in the header, as data. RANKED is the worst-of order, best first; WANT_VSET
# is the same set sorted the way the lift below sorts it.
case "$GATE" in
  code-review) ROLE_NAME="code-reviewer.md"; DSUF="code-review"; TITLE="Code Review"
               RANKED="APPROVED NEEDS_REWORK BLOCKED"; WANT_VSET="APPROVED BLOCKED NEEDS_REWORK "; NWORD="three" ;;
  qa)          ROLE_NAME="qa.md"; DSUF="qa-validation"; TITLE="QA Validation"
               RANKED="PASS NEEDS_REWORK"; WANT_VSET="NEEDS_REWORK PASS "; NWORD="two" ;;
  *) refuse "--gate '$GATE' is not code-review or qa" ;;
esac
[ "$GATE" = qa ] || [ -z "$STORY_F$R_BASE" ] || refuse "--story and --range are read only under --gate qa; $USAGE"
# The merge decides the exemption over the manifest's base..sha, the whole story on every pass; a
# caller-supplied range could only narrow it.
[ -n "$SERIAL" ] || [ -z "$R_BASE" ] || refuse "--range is read only by --check-serial; the merge decides the record-only exemption over the manifest's base and sha (the whole story's range on every pass); $USAGE"
# ONE SPRINT PER PATH (STORY-BIND, --gate qa). --check-serial reads the sprint <N> from the review's logical directory
# and the merge from the shard directory's physical `docs/reviews/s<N>/shards/` parent, so a symlinked directory naming
# another s<M> would choose the sprint for either reader. one_sprint <slot dir, logical> <slot dir, physical> refuses
# when the two spellings name different sprints (compared as review_sprint answers, never as paths), naming both.
one_sprint() {
  os_l_="$(review_sprint "$1")" || os_l_=""; os_p_="$(review_sprint "$2")" || os_p_=""
  [ "$os_l_" = "$os_p_" ] \
    || refuse "STORY-BIND: the review path names two sprints: the logical directory $1 reads sprint ${os_l_:-<none>} and the physical directory $2 reads sprint ${os_p_:-<none>}; write the review at the path qa.md names, with no symlink choosing its sprint"
}
[ -z "$SERIAL" ] || [ "$GATE" != qa ] || one_sprint "$(cd "$(dirname "$SERIAL")" 2> /dev/null && pwd)" "$(cd "$(dirname "$SERIAL")" 2> /dev/null && pwd -P)"
if [ -n "$SERIAL$RV" ]; then :
else
SDIR="${SDIR%/}"
[ -d "$SDIR" ] || refuse "shard directory $SDIR does not exist"
[ "$GATE" != qa ] || one_sprint "$(cd "$SDIR/../.." 2> /dev/null && pwd)" "$(cd "$SDIR/../.." 2> /dev/null && pwd -P)"
SDIR_IN="$SDIR"; SDIR="$(cd "$SDIR" && pwd -P)" || refuse "shard directory is not enterable"
if [ -z "$CHECK" ]; then
case "$OUT" in */) refuse "--out $OUT names a directory" ;; esac
OUT_DIR="$(dirname "$OUT")"
[ -d "$OUT_DIR" ] || refuse "the directory of --out ($OUT_DIR) does not exist"
OUT="$(cd "$OUT_DIR" && pwd -P)/$(basename "$OUT")" || refuse "the directory of --out is not enterable"
case "$OUT" in "$SDIR"/*) refuse "--out $OUT is inside the shard directory" ;; esac
else
  # The target's KEY is its basename alone. A target inside the shard directory is spelled exactly as
  # the merge's own staging spells it (the physical SDIR), so a refusal text is byte-equal to the
  # full merge's. A target OUTSIDE it is --mark's pre-write snapshot: it is checked against this
  # directory's map and siblings, and its content seal is --mark's own call on the real file.
  CHECK_DIR="$(cd "$(dirname "$CHECK")" 2>/dev/null && pwd -P)" || refuse "the directory of --check-shard $CHECK is not enterable"
  CHECK="$CHECK_DIR/$(basename "$CHECK")"
  CHECK_IN=0; [ "$CHECK_DIR" = "$SDIR" ] && CHECK_IN=1
fi
fi # end the shard-directory resolution (skipped by --check-serial)

T="$(mktemp -d "${TMPDIR:-/tmp}/merge-review-shards.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT
TAB="$(printf '\t')"
NL_='
'

AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "REFUSED: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or"
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root."
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
SELF_DIR="$AI_DLC_SELF_DIR"; ROOT="$AI_DLC_ROOT"
GATE_MD=""
for c in "$ROOT/.claude/skills/ai-dlc/steps/gate-validation.md" "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"; do
  [ -r "$c" ] && { GATE_MD="$c"; break; }
done
[ -n "$GATE_MD" ] || refuse "gate-validation.md is not readable in either layout under $ROOT"
ROLE_MD=""
for c in "$ROOT/.claude/team-roles/$ROLE_NAME" "$ROOT/core/team-roles/$ROLE_NAME"; do
  [ -r "$c" ] && { ROLE_MD="$c"; break; }
done
[ -n "$ROLE_MD" ] || refuse "$ROLE_NAME is not readable in either layout under $ROOT"

PATS="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE_MD")"
n_pat="$(printf '%s\n' "$PATS" | grep -c .)" || n_pat=0
[ "$n_pat" = "1" ] || refuse "found $n_pat \`grep -inE '<pattern>' <review-file>\` directives in $GATE_MD (want exactly 1); Check 1's pattern is derived, never retyped"
PAT="$PATS"

# Byte-identical to vocab_extract_review_verdicts in scripts/render-vocabulary-index.sh.
VSET="$(awk '/^## Verdict$/ { on = 1; next }
       on && /^[A-Z_]+( \| [A-Z_]+)+$/ { n = split($0, m, /[[:blank:]]*\|[[:blank:]]*/)
                                         for (i = 1; i <= n; i++) print m[i]; exit }' "$ROLE_MD" \
    | LC_ALL=C sort -u | tr '\n' ' ')"
[ "$VSET" = "$WANT_VSET" ] \
  || refuse "$ROLE_NAME's ## Verdict template declares '${VSET% }', not exactly $RANKED; the worst-of ranking orders only those $NWORD"
# ---- --read-verdict (header: READ-VERDICT). check1_read and the lifted set, nothing else; before the severity lift,
# so a qa read prints no container LEGACY line.
if [ -n "$RV" ]; then
  check1_read "$RV"
  [ "$C1N" -ge 1 ] || refuse "$RV matches Check 1's verdict pattern 0 time(s), so it carries no verdict to read"
  [ "$C1D" -eq 1 ] || refuse "$RV matches Check 1's verdict pattern $C1N time(s) reading $C1D different values ($C1L); one review file carries one verdict"
  rv_in_=0
  for rv_v_ in $RANKED; do [ "$rv_v_" != "$C1V" ] || rv_in_=1; done
  [ "$rv_in_" = 1 ] || refuse "Check 1 reads '$C1V' from $RV, which is not one of $RANKED ($ROLE_NAME's ## Verdict set)"
  printf 'VERDICT: %s verdict=%s\n' "$RV" "$C1V"
  exit 0
fi
# THE FINDING-CLASS SET (header: SHARD GRAMMAR, THE CLASS LINE). Byte-identical to CLASS_SET_AWK in
# scripts/render-vocabulary-index.sh (I129). Lifted for BOTH gates from the gate's own role file;
# empty when the installed role file declares none.
CLASS_SET_AWK='/^Class: [A-Z_]+( \| [A-Z_]+)+$/ { n = split(substr($0, 8), m, /[[:blank:]]*\|[[:blank:]]*/); for (i = 1; i <= n; i++) print m[i]; exit }'
CLASS_SET="$(awk "$CLASS_SET_AWK" "$ROLE_MD" | LC_ALL=C sort -u | tr '\n' ' ')"
CRIT_NAME=""; IMP_NAME=""; SUG_NAME=""; SEV=1
CNAMES="$(lift_containers "$ROLE_MD")"
set -f; set -- $CNAMES; set +f
if [ "$GATE" = qa ] && [ "$#" -eq 0 ]; then
  SEV=0
  printf 'LEGACY: %s declares no severity containers; QA verdict backing is count-only\n' "$ROLE_MD"
else
  [ "$#" -eq 3 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] \
    || refuse "$ROLE_NAME's ## Findings template declares $# severity container(s) ('${CNAMES% }'), not exactly three; the verdict-backing rule reads the first two as the Critical and Important classes"
  CRIT_NAME="$1"; IMP_NAME="$2"; SUG_NAME="$3"
fi

# ---- CANONICAL RUN (header). canon_gate <file> <owner> <repo or empty> <base or empty> <frozen or empty>:
# under a PASS in WORST, the file must carry QA's own canonical run and its summary with counts, or the
# record-only exemption over <base>..<frozen>. The partition and both grammars are record-only-diff.sh's.
CANON_SENTINEL='column-0 `Canonical run:`'
# THE ADVISOR LINE's era sentinel (header: SHARD GRAMMAR, ADVISOR LINE), matched as CANON_SENTINEL is.
ADVISOR_SENTINEL='column-0 `advisor:`'
# The serial reviewed-sha line's era sentinel (header: CHECK-SERIAL, THE LEAD'S RE-RUN), qa.md's own prescription.
RSHA_SENTINEL='column-0 `reviewed-sha: <full go-signal sha>`'
RO="$AI_DLC_SELF_DIR/record-only-diff.sh"
# ---- THE ADVISOR LINE (header: SHARD GRAMMAR). adv_gate <file>: one function for the per-shard check
# and --check-serial. The caller sets ADV_AT (`legacy` acquits an absent line; any other value holds
# it), ADV_AT_PATH (named in the LEGACY line) and ADV_WHY (appended to the absence refusal) first.
# The label is matched CASE-SENSITIVELY: graph's s319 shards carry 8 prose lines opening `Advisor:` or
# `- Advisor:` and 0 lowercase ones, so a case-insensitive malformed-line refusal would refuse a
# legacy shard in every era (BL-790 body).
ADV_LEG=""
# ---- --check-serial (header: CHECK-SERIAL). The merge's own Check 1 read-back and set membership on
# ONE serial file, then, under --gate qa, the FAIL ROWS rules over its own table and findings.
if [ -n "$SERIAL" ]; then
  check1_read "$SERIAL"
  [ "$C1N" -ge 1 ] \
    || refuse "$SERIAL matches Check 1's verdict pattern 0 time(s); write the verdict as '## Verdict' with the value alone on the next non-blank line, or as one 'Verdict: <VALUE>' line"
  [ "$C1D" = 1 ] \
    || refuse "$SERIAL matches Check 1's verdict pattern $C1N time(s) reading $C1D different values ($C1L); matches reading one value are one verdict, different values fail Check 1. Write the verdict in one form, never both, and keep every other line off that pattern (per-AC results go in a pipe-led table)"
  case " $RANKED " in
    *" $C1V "*) ;;
    *) refuse "Check 1 reads '$C1V' from $SERIAL, which is not one of $RANKED ($ROLE_NAME's ## Verdict set); write the value alone, a member of that set" ;;
  esac
  # THE ADVISOR LINE, both gates, keyed on the INSTALLED role file (the seat runs this before it returns).
  ADV_AT_PATH="$ROLE_MD"; ADV_WHY="; $ROLE_MD prescribes it"
  if adv_has "$ROLE_MD"; then ADV_AT="present"; else ADV_AT="legacy"; fi
  adv_gate "$SERIAL"
  class_gate "$SERIAL"
  if [ "$GATE" = qa ]; then
    WORST="$C1V"
    printf '%s\n' "$SERIAL" > "$T/serialfiles" || refuse "cannot stage the serial file"
    fail_gate "$SERIAL" serial "$T/serialfiles"
    sr_repo_="$(git -C "$(dirname "$SERIAL")" rev-parse --show-toplevel 2>/dev/null < /dev/null)" || sr_repo_=""
    # THE RANGE'S TWO COMMITS (header: CHECK-SERIAL, THE LEAD'S RE-RUN): qa.md is read at the base, never at the frozen
    # sha the seat's range ends at, so a commit inside the range cannot change the rule the review is held to.
    sr_b_=""; sr_f_=""
    if [ -n "$sr_repo_" ]; then
      [ -z "$R_BASE" ] || sr_b_="$(git --no-replace-objects -C "$sr_repo_" rev-parse -q --verify "${R_BASE}^{commit}" 2> /dev/null < /dev/null)" || sr_b_=""
      [ -z "$R_FROZEN" ] || sr_f_="$(git --no-replace-objects -C "$sr_repo_" rev-parse -q --verify "${R_FROZEN}^{commit}" 2> /dev/null < /dev/null)" || sr_f_=""
    fi
    if [ "$LEAD" = 1 ]; then
      # THE LEAD'S RE-RUN (header: CHECK-SERIAL): the review is the lead-assigned file at its physical docs/reviews/s<N>/
      # slot in its own repository, the go-signal sha the frozen end, and the base the story's lead record's `dispatch:`
      # (written by --record-dispatch at dev dispatch). With no record, LEGACY-UNRECORDED: the seat's base, as before.
      [ -n "$sr_repo_" ] || refuse "$SERIAL is not inside a git worktree; the lead re-runs the check on the review file at the path it assigned"
      lead_checkout_only "$sr_repo_" "--lead-range: the review's repository"
      [ -n "$sr_f_" ] || refuse "--lead-range go-signal sha '${R_FROZEN}' is not a commit in $sr_repo_; pass the full sha the lead recorded at the gate-2 go-signal"
      sr_top_="$(cd "$sr_repo_" 2> /dev/null && pwd -P)" && sr_pd_="$(cd "$(dirname "$SERIAL")" 2> /dev/null && pwd -P)" \
        && sr_ln_="$(review_sprint "$(dirname "$SERIAL")")" && [ "$sr_pd_" = "$sr_top_/docs/reviews/s$sr_ln_" ] \
        || refuse "$SERIAL is not at docs/reviews/s<N>/ in its own repository $sr_repo_ (physically ${sr_pd_:-unresolved}); the lead re-runs the check on the review path it assigned, never on a path the seat reports"
      sr_li_=""; sr_rec_=0
      case "$(basename "$SERIAL")" in
        ?*-"$DSUF".md) sr_li_="$(basename "$SERIAL" ".md")"; sr_li_="${sr_li_%-"$DSUF"}" ;;
        ?*-"$DSUF"-p*.md) sr_li_="$(basename "$SERIAL" ".md")"; sr_li_="${sr_li_%-"$DSUF"-p*}" ;;
      esac
      sr_rn_="s$sr_ln_-$sr_li_"
      sr_rp_="$(lead_record_path "$sr_repo_" "$sr_rn_")" || refuse "$SERIAL names no story index the lead record can be keyed on (s$sr_ln_-${sr_li_:-<none>}); write the review at the path qa.md names"
      if sr_rd_="$(lead_record_get "$sr_repo_" "$sr_rn_" dispatch)" \
        && sr_b_="$(git --no-replace-objects -C "$sr_repo_" rev-parse -q --verify "${sr_rd_}^{commit}" 2> /dev/null < /dev/null)"; then
        GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts git -C "$sr_repo_" merge-base --is-ancestor "$sr_b_" "$sr_f_" 2> /dev/null < /dev/null \
          || refuse "the go-signal sha $sr_f_ does not descend from the dispatch sha $sr_b_ in $sr_rp_, so $SERIAL reviewed a history the story was not dispatched on; send the story back to the dev to rebuild it on its dispatched branch"
        sr_rec_=1
      else
        sr_b_=""
        [ -z "$SEAT_B" ] || [ "$SEAT_B" = - ] \
          || sr_b_="$(git --no-replace-objects -C "$sr_repo_" rev-parse -q --verify "${SEAT_B}^{commit}" 2> /dev/null < /dev/null)" || sr_b_=""
        printf 'LEGACY-UNRECORDED: %s has no dispatch record at %s; checked over the seat base %s as 0.994.0 did (the dispatch step writes it with --record-dispatch)\n' "$sr_rn_" "$sr_rp_" "${SEAT_B:--}"
      fi
      R_BASE="$sr_b_"
    fi
    sr_qa_at "$sr_repo_" "$sr_b_" || SR_QA_AT=""
    if [ "$LEAD" = 1 ]; then
      # THE REVIEWED SHA (header: CHECK-SERIAL, THE LEAD'S RE-RUN), held when qa.md at the dispatch sha prescribes the
      # serial line; LEGACY otherwise. Exactly one column-0 line outside fences, its value the go-signal sha alone.
      if [ -n "$SR_QA_AT" ] && grep -qF -- "$RSHA_SENTINEL" "$T/qa-at-b"; then
        # The merge's own per-shard reader (parse_shard's R line: the count, then the first value, `-` when empty).
        sr_rl_="$(parse_shard "$SERIAL" | awk '$1 == "R" { n = $2; sub(/^R [0-9]+ /, ""); print n "\t" $0; exit }')" \
          || refuse "parsing $SERIAL did not run"
        [ "${sr_rl_%%$'\t'*}" = 1 ] \
          || refuse "$SERIAL carries ${sr_rl_%%$'\t'*} 'reviewed-sha:' line(s) outside a fence; $SR_QA_AT prescribes exactly one, naming the go-signal sha $sr_f_"
        sr_rv_="${sr_rl_#*$'\t'}"
        [ "$sr_rv_" = "$sr_f_" ] \
          || refuse "$SERIAL reviewed '${sr_rv_:-<empty>}', not the go-signal sha $sr_f_ alone; the validation is of another tree, or its reviewed-sha: line carries more than the full sha"
      else
        printf 'LEGACY: reviewed-sha not checked: %s prescribes no %s line\n' "${SR_QA_AT:-$ROLE_NAME (absent at $sr_b_ and on disk)}" "$RSHA_SENTINEL"
      fi
    fi
    # ROLE_MD sits under a root the environment may choose (AI_DLC_PROJECT_ROOT, CLAUDE_PROJECT_DIR), so it can hold
    # the rule but never acquit it: LEGACY also needs the checked repo's own qa.md (at the range's base, else on disk,
    # either layout) to lack the sentinel. An unreadable one holds (header: CANONICAL RUN, LEGACY). Under --lead-range
    # with qa.md a tracked blob at the dispatch base, that blob alone decides (sr_era), as the merge decides from qa.md
    # at its frozen sha and as the run record's era is decided below. The blob decides only when the dispatch record
    # named the base: a LEGACY-UNRECORDED story's base is the seat's own, and a seat must not choose its era by choosing
    # an old base, so there the installed qa.md holds as before and its refusal names the remedy (sr_rh_).
    sr_bd_=0; if [ "$LEAD" = 1 ] && [ "${SR_QA_TRK:-0}" = 1 ] && [ "${sr_rec_:-0}" = 1 ]; then sr_bd_=1; fi
    sr_rh_=0; sr_unrec_=0; [ "$LEAD" = 0 ] || [ "${sr_rec_:-0}" = 1 ] || sr_unrec_=1
    sr_era "$CANON_SENTINEL" "$sr_bd_"; sr_held_=1; sr_leg_="$ROLE_MD"
    [ "$sr_unrec_" = 0 ] || [ "$SR_ERA" != role ] || grep -qF -- "$CANON_SENTINEL" "$T/qa-at-b" || sr_rh_=1
    case "$SR_ERA" in
      role) : ;;
      absent) CG_NOTE=" (held: $ROLE_MD prescribes no $CANON_SENTINEL label, and the checked repo ${sr_repo_:-<none>} has no $ROLE_NAME in either layout${sr_b_:+ at $sr_b_ or on disk})" ;;
      base) grep -qF -- "$CANON_SENTINEL" "$ROLE_MD" || CG_NOTE=" (held: $SR_QA_AT prescribes the $CANON_SENTINEL label; $ROLE_MD, under the project root, does not)" ;;
      *) sr_held_=0; sr_leg_="$SR_QA_AT" ;;
    esac
    if [ "$sr_held_" = 1 ]; then
      [ -z "$R_BASE" ] || [ -n "$sr_repo_" ] || refuse "--range was given and $SERIAL is not inside a git worktree to read it in"
      sr_conv_=""; [ -z "$sr_repo_" ] || [ ! -r "$sr_repo_/docs/coding-conventions.md" ] || sr_conv_="$sr_repo_/docs/coding-conventions.md"
      sr_idx_=""
      case "$(basename "$SERIAL")" in
        ?*-"$DSUF".md) sr_idx_="$(basename "$SERIAL" ".md")"; sr_idx_="${sr_idx_%-"$DSUF"}" ;;
        ?*-"$DSUF"-p*.md) sr_idx_="$(basename "$SERIAL" ".md")"; case "${sr_idx_##*-"$DSUF"-p}" in ''|*[!0-9]*) sr_idx_="" ;; *) sr_idx_="${sr_idx_%-"$DSUF"-p*}" ;; esac ;;
      esac
      sr_n_="$(cd "$(dirname "$SERIAL")" 2> /dev/null && review_sprint "$(pwd)")" || sr_n_=""
      # THE RUN RECORD (header): the era is qa.md at the range's base in the review's repository (SR_QA_AT, on disk with
      # no range), else the installed ROLE_MD; the frozen sha is the go-signal sha, else the review repository's HEAD.
      # ROLE_MD can hold the era and never acquit it, as for the canonical lines: a seat that strips the sentinel from the
      # review repository's on-disk qa.md does not reach LEGACY while the lead's installed qa.md prescribes --record-run.
      # Under --lead-range, when qa.md is a tracked blob at the dispatch base, that blob ALONE decides, as the merge decides
      # from qa.md at its base: a seat cannot edit a committed base, and a lead whose install moved past the base (a pull
      # mid-sprint) must not hold a serial story the merge would read LEGACY for the same base.
      # The decision is sr_era's, shared with the canonical lines above; only an absent qa.md differs (legacy here).
      RB_ERA=legacy; RB_AT="${SR_QA_AT:-$ROLE_MD}"
      sr_era "$RUN_SENTINEL" "$sr_bd_"
      case "$SR_ERA" in role|base) RB_ERA=held ;; esac
      [ "$sr_unrec_" = 0 ] || [ "$SR_ERA" != role ] || grep -qF -- "$RUN_SENTINEL" "$T/qa-at-b" || sr_rh_=1
      [ "$sr_rh_" = 0 ] || CG_NOTE="$CG_NOTE (held by the installed $ROLE_MD, not by qa.md at the seat base ${SEAT_B:--}: $sr_rn_ has no dispatch record, and a seat-supplied base never decides the era; record the dispatch with 'merge-review-shards.sh --record-dispatch $sr_rn_ <dispatch sha>' from the lead checkout, or re-run QA at the current base)"
      RB_SHA="$sr_f_"; [ -n "$RB_SHA" ] || [ -z "$sr_repo_" ] || RB_SHA="$(git --no-replace-objects -C "$sr_repo_" rev-parse -q --verify HEAD 2> /dev/null < /dev/null)" || RB_SHA=""
      RB_REPO="$sr_repo_"; RB_NAME=""; [ -z "$sr_n_" ] || [ -z "$sr_idx_" ] || RB_NAME="s$sr_n_-$sr_idx_"
      RB_KEY="run.$(basename "$SERIAL")"; RB_WT="$sr_repo_"; RB_ARG="$SERIAL"; RB_FZ="${sr_f_:-<the full go-signal sha>}"
      # THE WAIVER's base (canon_gate): lead-written only under --lead-range over a recorded dispatch.
      sr_lw_=seat; if [ "$LEAD" = 1 ] && [ "${sr_rec_:-0}" = 1 ]; then sr_lw_=lead; fi
      canon_gate "$SERIAL" serial "$sr_repo_" "$R_BASE" "$R_FROZEN" "$sr_conv_" "$sr_idx_" "$sr_n_" "$sr_lw_"
    else
      printf 'LEGACY: canonical-run lines not checked: %s prescribes no %s label\n' "$sr_leg_" "$CANON_SENTINEL"
    fi
  fi
  printf 'SERIAL-OK: %s verdict=%s\n' "$SERIAL" "$C1V"
  exit 0
fi

# ---- the manifest, and the re-derived part map ------------------------------------------
MF="$SDIR/.manifest"
[ -f "$MF" ] || refuse "no manifest at $MF (partition-review-diff.sh --map ... --shard-dir writes it)"
for k in worktree base sha min-files max-parts; do
  n="$(awk -F'\t' -v k="$k" '$1 == k { n++ } END { print n + 0 }' "$MF")"
  [ "$n" = "1" ] || refuse "$MF carries $n '$k' line(s); want exactly 1"
done
M_WT="$(mf worktree)"; M_BASE="$(mf base)"; M_SHA="$(mf sha)"; M_MIN="$(mf min-files)"; M_MAX="$(mf max-parts)"
case "$M_SHA" in *[!0-9a-f]*|"") refuse "$MF sha '$M_SHA' is not a full hex object name" ;; esac
[ "${#M_SHA}" -eq 40 ] || [ "${#M_SHA}" -eq 64 ] || refuse "$MF sha '$M_SHA' is not a FULL object name (40 or 64)"
awk -F'\t' '$1 == "part" { sub(/^part\t/, ""); print }' "$MF" > "$T/mfmap" || refuse "cannot stage the manifest map"
grep -q . "$T/mfmap" || refuse "$MF lists no part"
SB="$(basename "$SDIR")"
S12="$(printf '%s' "$M_SHA" | cut -c1-12)"
DPASS=""
case "$SB" in
  *-"$DSUF-$S12") IDX="${SB%-"$DSUF-$S12"}" ;;
  *-"$DSUF-$S12"-p*) IDX="${SB%-"$DSUF-$S12"-p*}"; DPASS="${SB##*-"$DSUF-$S12"-p}" ;;
  *) refuse "shard directory $SB is not <idx>-$DSUF-<sha12> for the manifest's sha $M_SHA (a later pass appends -p<M>)" ;;
esac
[ -n "$IDX" ] || refuse "shard directory $SB names no story index"
[ -z "$DPASS" ] || pass_ok "$DPASS" \
  || refuse "shard directory $SB carries pass marker -p$DPASS; a pass marker is -p<M> with M an integer >= 2 (pass 1 carries none)"
if [ -z "$CHECK" ]; then
OB="$(basename "$OUT")"
OPASS=""
case "$OB" in
  "$IDX-$DSUF.md") ;;
  "$IDX-$DSUF"-p*.md) OPASS="${OB#"$IDX-$DSUF"-p}"; OPASS="${OPASS%.md}"
    pass_ok "$OPASS" \
      || refuse "--out $OB carries pass marker -p$OPASS; a pass marker is -p<M> with M an integer >= 2 (pass 1 carries none)" ;;
  *) refuse "--out $OB is not $IDX-$DSUF.md or $IDX-$DSUF-p<M>.md, the --gate $GATE review file for shard directory $SB" ;;
esac
[ "$OPASS" = "$DPASS" ] \
  || refuse "pass marker mismatch: shard directory $SB is $(pass_name "$DPASS") and --out $OB is $(pass_name "$OPASS"); a shard directory is merged only into its own pass's review file"
fi
# THE PARTITION RECORD (header), --gate qa merge only: the lead's record of the partition, named by the shard
# directory's s<N> (shard_slot: its docs/reviews/s<N>/shards/ path below the worktree top, read the same through the
# spelling given and physically) and $IDX, decides the base, the sha and (with the frozen tree) the canonical-run era.
# No record, or one missing a key: LEGACY-UNRECORDED and the 0.994.0 merge. A record: .manifest's base and sha must equal it.
PR_ERA=""
if [ "$GATE" = qa ] && [ -z "$CHECK" ]; then
  lead_checkout_only "$SDIR" "the qa merge: the shard directory"
  shard_slot "$SDIR_IN" "the qa merge: the shard directory"; pr_n_="$SS_N"
  pr_nm_="s$pr_n_-$IDX"; pr_b_=""; pr_s_=""
  # Keyed PER SHARD DIRECTORY (<idx>-qa-validation-<sha12>[-p<M>]): each pass's partition has its own keys, so an
  # earlier pass's values are never compared with a later pass's manifest.
  pr_k_="$SB"
  pr_b_="$(lead_record_get "$SDIR" "$pr_nm_" "partition-base.$pr_k_")" || pr_b_=""
  pr_s_="$(lead_record_get "$SDIR" "$pr_nm_" "partition-sha.$pr_k_")" || pr_s_=""
  PR_ERA="$(lead_record_get "$SDIR" "$pr_nm_" "qa-era.$pr_k_")" || PR_ERA=""
  if [ -z "$pr_b_" ] || [ -z "$pr_s_" ] || [ -z "$PR_ERA" ]; then
    PR_ERA=""
    printf 'LEGACY-UNRECORDED: story %s (%s) has no partition record for %s (merge-review-shards.sh --record-partition, at the gate-2 partition); base, sha and the canonical-run era are read from %s and the frozen tree as before 0.995.0\n' "$IDX" "$pr_nm_" "$SB" "$MF"
  else
    [ "$PR_ERA" = legacy ] || PR_ERA=held
    [ "$pr_b_" = "$M_BASE" ] \
      || refuse "the lead's partition record $pr_nm_ names base $pr_b_, and $MF names base $M_BASE: this shard directory is not the partition the lead recorded. Remove it, re-partition (implementation.md Gate-2 dispatch: partition-review-diff.sh --map, then --record-partition) and re-dispatch every QA seat of the story"
    [ "$pr_s_" = "$M_SHA" ] \
      || refuse "the lead's partition record $pr_nm_ names sha $pr_s_, and $MF names sha $M_SHA: this shard directory is not the partition the lead recorded. Remove it, re-partition (implementation.md Gate-2 dispatch: partition-review-diff.sh --map, then --record-partition) and re-dispatch every QA seat of the story"
  fi
fi

PART="$SELF_DIR/partition-review-diff.sh"
[ -f "$PART" ] || refuse "cannot re-derive the part map: $PART is absent"
# A NARROWED manifest (`narrow-from\t<path>`, partition-review-diff.sh THE NARROWED RE-REVIEW) is
# re-derived with that prior handed back, resolved against the shard directory's work tree, where the
# review files live. Without it the map is re-derived flagless, and the cmp below refuses whenever that
# map differs; an empty residue makes the two partitions identical, and the cmp accepts it.
n_nf="$(awk -F'\t' '$1 == "narrow-from" { n++ } END { print n + 0 }' "$MF")"
[ "$n_nf" -le 1 ] || refuse "$MF carries $n_nf 'narrow-from' line(s); want at most 1"
NF_ARGS=()
if [ "$n_nf" = 1 ]; then
  M_NF="$(mf narrow-from)"
  NF_TOP="$(git -C "$SDIR" rev-parse --show-toplevel 2>/dev/null < /dev/null)" \
    || refuse "$MF is narrowed from $M_NF, but $SDIR is not inside a git work tree to resolve it in"
  [ -f "$NF_TOP/$M_NF" ] || refuse "$MF is narrowed from $M_NF, which is not a file under $NF_TOP"
  NF_ARGS=(--narrow-from "$NF_TOP/$M_NF")
fi
mrs_sib "$PART" prd_main --map "$M_WT" "$M_BASE" "$M_SHA" --min-files "$M_MIN" --max-parts "$M_MAX" ${NF_ARGS[@]+"${NF_ARGS[@]}"} > "$T/map" 2> "$T/map.err"; prc=$?
[ "$prc" -eq 0 ] || refuse "partition-review-diff.sh --map re-run exited $prc: $(head -1 "$T/map") $(head -1 "$T/map.err")"
cmp -s "$T/map" "$T/mfmap" || refuse "the part map re-derived from $MF's inputs differs from the map it records; the shards were briefed on another partition"
K="$(grep -c . "$T/map")" || K=0
[ "$K" -ge 2 ] || refuse "the part map has $K part(s); a merge needs two or more"
W=${#K}
ORDINALS="$(cut -f1 "$T/map" | tr '\n' ' ')"; ORDINALS="${ORDINALS% }"

# ---- the cross groups, read from their one speller ----------------------------------------
# CROSS_KEYS is `cross` when the table has one row (K=2) and `cross-1 .. cross-<G>` otherwise;
# nothing here restates the construction. CROSS_FIRST is the execution owner (header).
XPART="$SELF_DIR/partition-document.sh"
[ -f "$XPART" ] || refuse "cannot read the cross groups: $XPART is absent"
mrs_sib "$XPART" pdoc_main --cross-groups "$K" > "$T/groups" 2> "$T/groups.err" < /dev/null; grc=$?
[ "$grc" -eq 0 ] || refuse "partition-document.sh --cross-groups $K exited $grc: $(head -1 "$T/groups.err")"
G="$(grep -c . "$T/groups")" || G=0
[ "$G" -ge 1 ] || refuse "partition-document.sh --cross-groups $K printed no group"
i=0
while IFS="$TAB" read -r gg gl; do
  i=$((i + 1))
  [ "$gg" = "$i" ] && [[ $gl =~ ^[0-9]+(,[0-9]+)+$ ]] \
    || refuse "partition-document.sh --cross-groups $K printed row $i as '$gg	$gl'; want <g>\\t<ordinal,ordinal,...> with g = 1..G in order"
done < "$T/groups"
if [ "$G" -eq 1 ]; then XTABLE_KEYS="cross"
else XTABLE_KEYS="$(awk '{ printf "%scross-%d", (NR > 1 ? " " : ""), NR }' "$T/groups")"; fi
cross_shape grouped


# ---- THE SEAL READER, for the owner-duplicate check under --check-shard ---------------------
# Copied, not sourced: wait-for-deliverable.sh executes on load and exports no library. Each body
# is byte-identical to its definition there (has_marker, content_hash, seal_body, seal_of); the
# byte-compare that binds the copies is owed by the fixture (header: SEAT-COMPLETE).
MARK_TOKEN="seat-complete: "

# ---- THE KEY= ENGINE AT THE FROZEN SHA (the legacy rule, header: SEAT-COMPLETE) ---------------
# Set-level, so read once and memoised. ENGINE is `present` (the frozen tree's wait-for-deliverable.sh
# carries the sentinel the key= writer carries), `absent` (the file is there without it: the tree
# predates the key= engine) or `unreadable` (no commit, or the file in neither layout) -- which
# never acquits.
ENGINE=""; ENGINE_AT=""
# ---- qa.md AT THE FROZEN SHA (the SEVERITY BOUNDARY, header: VERDICT BACKING) -------------------
# Set-level, memoised. QA_AT is `legacy` when the frozen tree's installed qa.md (consumer layout
# first, then the distribution's) lifts NO severity container -- the shards were briefed on a qa.md
# that never asked for one; `severity` when it lifts any; `unreadable` when the commit or the file in
# both layouts cannot be read. Only `legacy` acquits; `unreadable` never does, as the key= rule's
# `unreadable` engine never acquits a marker. The rule that judges stays the CURRENT qa.md's.
QA_AT=""; QA_AT_PATH=""
# ---- THE GATE'S ROLE FILE AT THE FROZEN SHA (the ADVISOR LINE's era, header: SHARD GRAMMAR) --------
# Set-level, memoised, one reader for both gates (ROLE_NAME). ADV_AT is `legacy` when the role file the
# shards were written under carries no ADVISOR_SENTINEL, `present` when it carries it, `disk` when the
# file is untracked at the frozen sha and the ON-DISK installed copy in the manifest's worktree carries
# it, `unreadable` when neither the commit nor either layout on disk can be read. Only `legacy`
# acquits an absent line. The on-disk read is the canonical-run arm's own fallback, taken only when the
# file is tracked in neither layout at the sha; a copy found there decides, as there.
ADV_AT=""; ADV_AT_PATH=""; ADV_WHY=""
SEAL_SH="$SELF_DIR/content-seal.sh"

# ---- the shard set ----------------------------------------------------------------------
# --check-shard skips this staging: its one shard's key is taken from the target's own name.
if [ -z "$CHECK" ]; then
: > "$T/shards" || refuse "cannot stage the shard set"
for f in "$SDIR"/*; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$f" ] || refuse "$f is not a regular file; the shard directory holds only <ordinal>.md and the cross shards ($CROSS_KEYS)"
  key_of_name "$b" || key_refuse "$?" "$f"
  key="$KEY_OF"
  printf '%s\t%s\n' "$key" "$f" >> "$T/shards" || refuse "cannot stage the shard set"
done
dup="$(cut -f1 "$T/shards" | sort | uniq -d | head -1)"
[ -z "$dup" ] || refuse_to "$(awk -F'\t' -v k="$dup" '$1 == k { b = $2; sub(/.*\//, "", b); printf "%s%s", (n++ ? " " : ""), b }' "$T/shards")" \
  "shard $dup was delivered more than once in $SDIR"
# The cross shards delivered are ONE of two shapes at any K: a lone `cross.md`, or EXACTLY the
# table's `cross-1..G` (`cross.md` again when G=1). A mix of the two, a `cross-<g>` the table does
# not print, and a partial `cross-<g>` set (the missing-shard loop) are each refused by name.
x_plain=0; x_num=0
while IFS="$TAB" read -r xk xf; do
  case "$xk" in
    cross) x_plain=1 ;;
    cross-*) x_num=1
      case " $XTABLE_KEYS " in *" $xk "*) ;; *) refuse "$xf is $xk, which partition-document.sh --cross-groups $K does not print (the cross shards for K=$K are: $XTABLE_KEYS, or one cross.md)" ;; esac ;;
  esac
done < "$T/shards"
[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \
  && refuse "$SDIR mixes cross.md with cross-<g>.md; a shard set is one cross shape or the other (for K=$K: one cross.md, or $XTABLE_KEYS)"
if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi
x_alt=""; [ "$XTABLE_KEYS" = cross ] || [ "$CROSS_KEYS" = cross ] || x_alt=", or one cross.md in place of the groups"
for idx in $ORDINALS $CROSS_KEYS; do
  [ -n "$(awk -F'\t' -v k="$idx" '$1 == k { print; exit }' "$T/shards")" ] \
    || refuse_to "$idx" "shard $idx is missing from $SDIR (expected: $ORDINALS and $CROSS_KEYS$x_alt)"
done

# ---- seat-complete (the belt; the join beat's --complete is the braces) --------------------
# If ANY shard's last non-blank line is the marker, every shard's must be. See the header.
: > "$T/sc" || refuse "cannot stage the completion check"
while IFS="$TAB" read -r sk sf_; do
  # Y carries the marker's declared count (`findings=<n>`, `-` when absent), checked per shard below.
  if awk 'NF { l = $0 } END { exit !(l ~ /^seat-complete: /) }' "$sf_"; then
    printf 'Y\t%s\t%s\n' "$sk" "$(awk 'NF { l = $0 } END { if (match(l, /findings=[0-9]+[ \t]*$/)) { v = substr(l, RSTART + 9); sub(/[ \t]+$/, "", v); print v } else print "-" }' "$sf_")" >> "$T/sc"
  else printf 'N\t%s\t%s\n' "$sk" "$sf_" >> "$T/sc"; fi || refuse "cannot stage the completion check"
done < "$T/shards"
if grep -q '^Y' "$T/sc" && grep -q '^N' "$T/sc"; then
  sc_bad="$(awk -F'\t' '$1 == "N" { print $3; exit }' "$T/sc")"
  refuse_to "$(awk -F'\t' '$1 == "N" { print $2; exit }' "$T/sc")" \
    "$sc_bad does not end in 'seat-complete: ' while another shard in $SDIR does; that shard is unfinished (its last non-blank line must be 'seat-complete: <step> <seat> <shard>')"
fi
fi # end the shard-set staging (skipped by --check-shard)

RE_CITED='^[0-9]+(,[0-9]+)*$'
RE_AC='^[A-Za-z0-9][A-Za-z0-9._-]*$'
WORST=""; WORST_R=0; NFIND=0; FORCE=""
: > "$T/hand" && : > "$T/runs" && : > "$T/runords" && : > "$T/htable" || refuse "cannot stage the hand-over set"
: > "$T/body" || refuse "cannot stage the merged body"
: > "$T/vtable" || refuse "cannot stage the verdict table"

if [ -n "$CHECK" ]; then
  # --check-shard: the one target, keyed by its own name; the set-level joins are the merge's.
  key_of_name "$(basename "$CHECK")" || key_refuse "$?" "$CHECK"
  key="$KEY_OF"; sf="$CHECK"
  # The delivered shape is the target's own: a `cross.md` target is the lone cross shard at any K,
  # so it is the execution owner and the owner of every cross finding (as the merge reads it).
  if [ "$key" = cross ]; then cross_shape lone; fi
  [ -f "$sf" ] || refuse_to "$key" "$sf is not a regular file; write the shard, then check it"
  scn=""
  if [ "$CHECK_N_SET" = 1 ]; then scn="$CHECK_N"
  elif awk 'NF { l = $0 } END { exit !(l ~ /^seat-complete: /) }' "$sf"; then
    scn="$(awk 'NF { l = $0 } END { if (match(l, /findings=[0-9]+[ \t]*$/)) { v = substr(l, RSTART + 9); sub(/[ \t]+$/, "", v); print v } else print "-" }' "$sf")"
  fi
  check_shard
  [ "$DUP_N" -eq 0 ] || exit 2
  printf 'SHARD-OK: %s findings=%s\n' "$sf" "${nf:-0}"
  exit 0
fi

for key in $ORDINALS $CROSS_KEYS; do
  sf="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/shards")"
  scn="$(awk -F'\t' -v k="$key" '$1 == "Y" && $2 == k { print $3; exit }' "$T/sc")"
  check_shard
  if [ "$key" = "cross" ]; then printf '\n## Shard: cross\n\n' >> "$T/body" || refuse "cannot stage the merged body"
  elif is_cross "$key"; then
    printf '\n## Shard: %s (%s)\n\n' "$key" "$(awk -F'\t' -v g="${key#cross-}" '$1 == g { print $2; exit }' "$T/groups")" >> "$T/body" \
      || refuse "cannot stage the merged body"
  else printf '\n## Shard: part %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  # The seat-complete marker is dropped: inside the merged file it would read as the merge's own.
  awk '!/^seat-complete: /' "$sf" >> "$T/body" || refuse "cannot stage the body of $sf"
done
# THE DUP BARRIER: every owner-duplicate refusal was printed above; none reaches the set-level joins.
[ "$DUP_N" -eq 0 ] || exit 2

# ---- the hand-over join (both gates) -----------------------------------------------------
# Every part hand-over is matched by EXACTLY ONE cross replay, and every replay by a hand-over.
# Keys are `<ordinal> <AC-id>`, the ordinal normalised, compared under LC_ALL=C.
{
  d1="$(sort "$T/hand" | uniq -d | head -1)"
  [ -z "$d1" ] || refuse_to "${d1%% *}" "hand-over '$d1' (<ordinal> <AC-id>) is handed over more than once"
  d1="$(sort "$T/runs" | uniq -d | head -1)"
  [ -z "$d1" ] || refuse_to "$CROSS_FIRST" "hand-over '$d1' has more than one 'handover-run:' line in $CROSS_FIRST.md; each hand-over is run exactly once"
  sort -u "$T/hand" > "$T/hand.s" && sort -u "$T/runs" > "$T/runs.s" || refuse "cannot sort the hand-over sets"
  # The join's two halves live in two files, so a broken pair names BOTH: the part and CROSS_FIRST.
  d1="$(comm -23 "$T/hand.s" "$T/runs.s" | head -1)"
  [ -z "$d1" ] || refuse_to "${d1%% *} $CROSS_FIRST" "hand-over '$d1' (part shard $(printf '%s' "$d1" | cut -d' ' -f1)) has no 'handover-run:' line in $CROSS_FIRST.md; the cross shard runs every handed-over replay before the merge"
  d1="$(comm -13 "$T/hand.s" "$T/runs.s" | head -1)"
  [ -z "$d1" ] || refuse_to "${d1%% *} $CROSS_FIRST" "$CROSS_FIRST.md carries 'handover-run: $d1' but part shard $(printf '%s' "$d1" | cut -d' ' -f1) handed over no such AC"
  NHAND="$(grep -c . "$T/hand.s")" || NHAND=0
  # An unmet HARD GATE: the replay did not go RED, or never reached a GREEN baseline. It raises
  # the verdict to NEEDS_REWORK and never lowers one (a code-review BLOCKED stays BLOCKED).
  if [ -n "$FORCE" ] && [ "$WORST_R" -lt "$(rank NEEDS_REWORK)" ]; then WORST="NEEDS_REWORK"; WORST_R="$(rank NEEDS_REWORK)"; fi
}

# ---- FAIL ROWS (--gate qa, set-level; header): CROSS_FIRST's per-AC table against the merged verdict
# and every shard's findings.
if [ "$GATE" = qa ]; then
  cut -f2 "$T/shards" > "$T/shardfiles" || refuse "cannot stage the shard list"
  fail_gate "$(awk -F'\t' -v k="$CROSS_FIRST" '$1 == k { print $2; exit }' "$T/shards")" "$CROSS_FIRST" "$T/shardfiles"
  # CANONICAL RUN (header), on the execution owner's file, held only when qa.md as installed at the
  # frozen sha prescribes the label; unreadable is held.
  cr_inst_=""; cr_held_=1
  if git --no-replace-objects -C "$M_WT" rev-parse -q --verify "${M_SHA}^{commit}" > /dev/null 2>&1 < /dev/null; then
    for cr_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
      git --no-replace-objects -C "$M_WT" cat-file -e "${M_SHA}:${cr_p_}" 2> /dev/null < /dev/null || continue
      cr_inst_="$cr_p_ at $M_SHA"
      git --no-replace-objects -C "$M_WT" show "${M_SHA}:${cr_p_}" 2> /dev/null < /dev/null | grep -qF -- "$CANON_SENTINEL" || cr_held_=0
      break
    done
  fi
  # Not tracked at the frozen sha (a consumer that does not commit .claude/team-roles/): QA read the
  # ON-DISK installed copy in that worktree, so that copy decides.
  if [ -z "$cr_inst_" ]; then
    for cr_p_ in .claude/team-roles/qa.md core/team-roles/qa.md; do
      [ -r "$M_WT/$cr_p_" ] || continue
      cr_inst_="$M_WT/$cr_p_ (on disk, untracked at $M_SHA)"
      grep -qF -- "$CANON_SENTINEL" "$M_WT/$cr_p_" || cr_held_=0
      break
    done
  fi
  # Neither readable: held (an unreadable role file never acquits), and every refusal names both paths tried.
  [ -n "$cr_inst_" ] || CG_NOTE=" (held: qa.md is neither tracked at ${M_SHA}:.claude/team-roles/qa.md nor on disk at $M_WT/.claude/team-roles/qa.md, either layout)"
  # LEGACY also needs the lead's recorded era to be legacy (header: THE PARTITION RECORD): a held record holds the rule
  # whatever the range did to qa.md at the frozen sha or on disk.
  [ "$PR_ERA" != held ] || cr_held_=1
  if [ "$cr_held_" = 0 ]; then
    printf 'LEGACY: canonical-run lines not checked: %s prescribes no %s label\n' "$cr_inst_" "$CANON_SENTINEL"
  else
    # The exemption is decided over the WHOLE story: the manifest's base is gate 1's base on every
    # pass (implementation.md Gate-2 dispatch), and the merge takes no --range to narrow it.
    cr_conv_=""; [ ! -r "$M_WT/docs/coding-conventions.md" ] || cr_conv_="$M_WT/docs/coding-conventions.md"
    # The merge's sprint is the dispatch path's: <shard-dir> is docs/reviews/s<N>/shards/<idx>-...-<sha12>[-p<M>].
    cr_n_=""; [ "$(basename "$(dirname "$SDIR")")" != shards ] || cr_n_="$(review_sprint "$(dirname "$(dirname "$SDIR")")")" || cr_n_=""
    # THE RUN RECORD (header): its era is the partition record's run-era, else qa.md at the manifest's base (none: legacy).
    RB_ERA="$(lead_record_get "$SDIR" "s$pr_n_-$IDX" "run-era.$SB")" || RB_ERA=""; RB_AT="the partition record s$pr_n_-$IDX (run-era.$SB)"
    if [ -z "$PR_ERA" ] || [ -z "$RB_ERA" ]; then
      RB_ERA="$(era_at "$M_WT" "$M_BASE" "$RUN_SENTINEL")"; RB_AT="qa.md at the base $M_BASE in $M_WT"
      [ "$RB_ERA" != none ] || { RB_ERA=legacy; RB_AT="$M_WT (no qa.md at the base $M_BASE or on disk)"; }
    fi
    RB_REPO="$SDIR"; RB_NAME="s$pr_n_-$IDX"; RB_KEY="run.$SB"; RB_SHA="$M_SHA"; RB_WT="$M_WT"; RB_ARG="$SDIR_IN"; RB_FZ=""
    # THE WAIVER's base (canon_gate): lead-written only when the lead's partition record named it (THE PARTITION RECORD).
    cr_lw_=seat; [ -z "$PR_ERA" ] || cr_lw_=lead
    canon_gate "$(awk -F'\t' -v k="$CROSS_FIRST" '$1 == k { print $2; exit }' "$T/shards")" "$CROSS_FIRST" "$M_WT" "$M_BASE" "$M_SHA" "$cr_conv_" "$IDX" "$cr_n_" "$cr_lw_"
  fi
  CG_NOTE=""
fi

{
  printf '# %s: %s (merged from %s shards)\n\n' "$TITLE" "$IDX" "$((K + XG))"
  printf '## Summary\n\n'
  if [ "$XG" -eq 1 ]; then XWORD="one cross shard"; else XWORD="$XG cross shards"; fi
  printf 'Merged by merge-review-shards.sh from %s part shards and %s, all reviewing\n' "$K" "$XWORD"
  printf '`%s..%s`. The verdict below is RECOMPUTED as the worst shard verdict; the\n' "$M_BASE" "$M_SHA"
  printf 'shard verdicts in the table are advisory inputs to it.\n\n'
  if [ -n "$FORCE" ]; then
    printf 'A handed-over replay is an unmet HARD GATE (%s), so the verdict is at least NEEDS_REWORK\n' "$FORCE"
    printf 'whatever the shard verdicts say.\n\n'
  fi
  printf '## Verdict\n%s\n\n' "$WORST"
  printf '## Shard verdicts\n\n| shard | shard-verdict |\n|---|---|\n'
  cat "$T/vtable"
  if [ -s "$T/htable" ]; then
    printf '\n## Hand-over replays\n\n| part | AC | handover-run |\n|---|---|---|\n'
    sort "$T/htable"
  fi
  printf '\n## Part map\n\n```text\n'
  cat "$T/map"
  printf '```\n'
  cat "$T/body"
} > "$T/out" || refuse "cannot stage the merged review"

# ---- conservation and the Check 1 read-back ---------------------------------------------
n_out="$(parse_shard "$T/out" | awk '$1 == "C" { print $2 }')"
[ "$n_out" = "$NFIND" ] || refuse "the merged review carries $n_out finding heading(s) where the shards carry $NFIND; a finding was lost or invented"
check1_read "$T/out"; n1="$C1N"
[ "$n1" = "1" ] || refuse_to "$(pat_owners)" "the merged review matches Check 1's verdict pattern $n1 time(s), want exactly 1 (a shard body carrying a verdict line such as '## Verdict' is the usual cause; shards write 'shard-verdict:')"
READ="$C1V"
[ "$READ" = "$WORST" ] || refuse "Check 1 would read '$READ' from the merged review, not the recomputed $WORST"

if [ -e "$OUT" ]; then
  if cmp -s "$T/out" "$OUT"; then printf 'UNCHANGED: %s verdict=%s\n' "$OUT" "$WORST"; exit 0; fi
  refuse "$OUT already exists and differs from this merge; a review file is never overwritten"
fi
cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || { rm -f "$OUT.merge-tmp.$$"; refuse "writing $OUT failed"; }
printf 'MERGED: %s verdict=%s parts=%s findings=%s sha=%s\n' "$OUT" "$WORST" "$K" "$NFIND" "$M_SHA"
exit 0
}
# The program runs only when executed; sourced (a fixture asking a decision in process), it defines
# the functions above and mrs_main, and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
mrs_main "$@"
