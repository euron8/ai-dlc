#!/usr/bin/env bash
# process-rule-pins — pin three process rules to the SECTION that makes them bind.
#
# Usage: run.sh            full run: probes, near-misses, mutants, then the real corpus
#        run.sh --report   corpus verdict only (used by the cwd-invariance arm)
# Exit:  0 = every assertion holds, 1 = a pin regressed, 2 = fixture broken.
#
# THE SUBJECT. Three rules are prose with no mechanism behind them, so the text IS the rule:
#   - a state claim in Check 12's evidence carries its command (gate-validation.md);
#   - an operator attribution cites the operator's message (rule-13.md, discovery.md §4a,
#     and an adversary Severity rung);
#   - a later event invalidating an authorization premise returns to the operator
#     (escalations.md, and a second adversary Severity rung);
#   - the bug root-cause claim gets an adversarial pass in bug-investigation.md §2c, and the
#     folded-defect routes (route.md, stories-test-strategy.md) reach §2c;
#   - a party round's seats edit nothing and one repair writer applies their findings, every
#     entry carrying `source: <seat-file>#<finding-id>` (_gate-procedures.md "Validation cycle",
#     sprint-review.md §2, remediator.md). The srev-waves-cite row (a `para` pin; the paragraph opens with a backtick, not bold) pins
#     that §2 cites the waves bound rather than leaving the fan-out unbounded; keep its phrase on ONE line. The `source:` resolution itself is mechanised in
#     join-remediator-shards.sh and owned by remediator-shard-join; these rows pin the PROSE that
#     tells the seats not to write, which no program can read off a seat's behaviour;
#   - the capital-path / high-blast-radius criterion that escalates a review also escalates a
#     dev (stories-test-strategy.md routing map and Model escalation, dev-escalated.md), and the
#     lead's one upward tag write lands before the story's FIRST dev dispatch, committed before
#     the worktree is cut, for an absent or `false` tag (implementation.md Pre-dispatch routing).
#     The sts-esc-why and dve-capital rows are line-mode `contains` pins: keep each pinned phrase
#     on ONE line of its subject.
#   - elicitation takes the axis and shape of the step's adversarial pass for every subject: the
#     files axis per story plus ONE cross-story shard (`cross.md`) and never one serial-document voice, the sections axis
#     per part plus ONE cross-part shard (`cross.md`) or one serial-document voice on a SERIAL answer
#     (_gate-procedures.md "Validation cycle" item 2), and stories-test-strategy.md step 4 names
#     elicitation among the sharded passes. sts-elic-sharded is a line-mode `contains` pin: keep
#     that phrase on ONE line of step 4. The files-axis story ordinals come from
#     `merge-adversarial-shards.sh --map` over the next review pass's `<artifact>-p<M>/` (it
#     refuses the `-elicitation/` dir), a one-file `stories/` is `shard: 1/1`, and the
#     sections-axis repair split expects the sha every elicitation shard notarized.
#     KNOWN LIMIT (the "LEADS ARE NOT ENOUGH" note below, one step further): these para rows pin
#     that each clause is PRESENT in the lead's paragraph. A separate sentence appended after it
#     that contradicts it ("...; elicitation may instead run one voice") leaves every pinned
#     clause intact and passes. No para row can fail on an addition; a reviewer reads for that.
#     An `exact` row (below) fails an addition only inside its own span: a sentence appended to its
#     paragraph, or a second paragraph in the span. Text added outside the span is not its subject.
#     Inside its span an `exact` row does NOT catch three shapes:
#       - a drain instruction written as a `#####` sub-heading (headings are skipped);
#       - a drain instruction inside a fenced block;
#       - a drain instruction inside an HTML comment (fences and comments are invisible to every test).
#     The lead model reads raw markdown, so these are real survivors; closing them changes the
#     fixture's grammar for every pin, which is a separate change.
#   - a change that makes an existing name, role or unit resolve to a different value, party or
#     unit while its text stays the same prices every literal and threshold the re-bound value
#     flows into under both bindings, in the unit it is compared against, and records old -> new,
#     an untouched literal included: the adversary's Severity rung (a plain blocking MAJOR, never
#     underived), the code reviewer's severity classification, and the architect's
#     evidence-contract `derived` fence, which derives each input from a named source file. The
#     trigger and the `every literal` scope are pinned separately, so narrowing either fails.
#     Each lead sits on ONE line of its subject so the raw-file lead check can find it.
#   - an AC whose expected outcome omits an action a locked requirement's verbatim text requires
#     is a requirement-divergence HARD_BLOCK for the operator, never a PASS (qa.md Validation
#     Checklist): QA writes NEEDS_REWORK and the lead asks by AskUserQuestion before rework; the
#     exemptions (2) and (3) are pinned whole and (1) only by its tail; §5 of deploy-validate.md records an accepted degraded
#     branch as a `descope` of the omitted action, never `delivered`. The qa-lrdiv-* rows are line-mode pins because
#     the whole checklist is ONE paragraph to para mode (no blank line between its items): keep
#     each pinned phrase on ONE line of the item. dv-lrcov-degraded spans §5 to §6, not the
#     coverage lead, so relocating the paragraph out of §5 moves it out of the span.
#   - a worktree dev dispatch brief carries two standing lines: every git command is
#     `git -C <worktree>` (or a cd on every Bash call), and one story per dispatch, never a second
#     claimed from a task list (_dispatch-protocol.md "Worktree-explicit dev dispatch" point 3,
#     dev.md Responsibilities, and dev.md's HARD_BLOCK bullet going idle). Points 0-7 carry no blank line between them, so para mode reads
#     the whole list as ONE paragraph whose lead is point 0; the dp-* tokens pin point 3 inside it.
#   - a join refusal confined to one part is recovered by re-running that part as a NEW dispatch and
#     joining with `--rerun <part>.md@<S_P>`; the re-run's brief accounts for the whole section diff
#     against the split slice, and the lead reads S_P after the refused writer stopped and before the
#     re-dispatch (_gate-procedures.md "After a join refusal" item 1b, and the document and subject
#     "Join and assemble" steps). Those steps' items carry no blank line between them, so para mode
#     reads each list as ONE paragraph whose lead is item 1 ("Split."); gp-rerun-doc/subj pin inside it.
#   - the routing record's two cites (route.md Step 6, `user_request_cite` and `scope_confirmed_cite`)
#     are named as the 64 hex characters after `- SHA256: `, so a lead does not copy the label in.
#     route-cite-user and route-cite-scope are line-mode `contains` pins (the bullets are indented):
#     keep each field name and its bare-hex phrase on ONE line.
#   - the carry-over evaluation's review and repair stem is `coe` (shard dir `s<N>/shards/coe-p<M>/`),
#     never the full step name and never the series stem `coe-adversarial` (carry-over-evaluation.md
#     §3a). A blank line sets that bullet apart from the two above it, so `- The series is` is its
#     own paragraph's lead for the coe-stem-* rows.
#   - every kept carry-over round names the defect it caught in §3a's Minimum mechanism
#     paragraph (coe-26c-caught, a line-mode `contains` pin: its delete mutant removes every
#     `Failure caught:` line, which is the paragraph losing its subject), and the adversarial
#     loop's later passes keep their own line (coe-26c-loop, a `prefix` pin: keep it on ONE line).
#   - an adversary SHARD writes `tool_use_id: NOT_ACCESSIBLE` and the merge derives each shard's
#     dispatch id from the harness records (_gate-procedures.md "Adversarial review dispatch", the
#     "It writes findings to" paragraph; adversary.md Contract item 2, which item 1 runs into with no
#     blank line, so its paragraph's lead is item 1). The derivation itself is owned by
#     adversarial-shard-merge; these rows pin the prose that tells a shard not to self-report.
#   - a shard refused as two adversary dispatches after a re-dispatch is merged with `--rerun
#     <shard>.md@<dispatched-at>`, a refusal naming another shard's writer is a finding, and a
#     DOUBLE-WRITE refusal means no start exists (gp-shard-rerun*); the probe ledger is not rotated mid-round and a "predates transcript_path"
#     refusal is re-run, never hand-filled (gp-probe-ledger*). Same section, each its own paragraph.
#   - the architecture step's section 2-3 architect chain joins on its chain record with
#     `--complete`, never on the spine (architecture.md section 2; arch-chain-join). The spine is
#     seeded header-first, so a plain join on it delivers a header. The marker predicate itself is
#     wait-for-deliverable.sh's and its fixtures'; this row pins the join line the lead copies,
#     from "Join it with" so a negated imperative cannot keep the command; arch-chain-marker-last
#     pins that the marker is the architect's final write, after the last file of the chain.
#   - a repair PART closes with `--mark` and every axis's part join beat passes `--complete`
#     (_gate-procedures.md files, sections and subject "Join" steps; remediator.md item 1,
#     **Close your part with `--mark`**; gp-part-*, rem-part-mark), and a serial remediator whose
#     block appended a `(decision)` writes its SPEC Render line BEFORE `--mark-repair`
#     (gp-render-before-mark, rem-render-before-mark). The gp-part-complete-* token ends at
#     `--complete --`, so `--complete --since` and `--complete --dispatch` both pin and a plain
#     beat or `--complete-repair` does not. The marker predicate is wait-beat-liveness's
#     section 25; the stale-SPEC refusal is remediator-shard-join's SP11.
#   - every decision put to the operator has one shape, and an act the operator attested is not
#     raised again: Rule 11(a) carries a pointer to both (r11a-pointer), and Rule 12's two
#     `#### Operator decisions` subsections state them in full -- each option with its effect and
#     consequence (r11a-one-shape), a question carrying no badge says so in its own text with the
#     reason (r11a-say-why), and no later step puts an attested act back to the operator
#     (r11a-attested-act), and a record read afterwards showing the act did not occur is an
#     authorization-premise invalidation rather than a re-ask (r11a-premise), and immediately before
#     every `AskUserQuestion` the lead joins finished lanes, dispatches every lane the question does
#     not hold, and then asks at once, the question unchanged (r11a-dispatch-ask, an `exact` row: the
#     subsection holds ONE paragraph and it must EQUAL the pinned text, so a drain sentence appended
#     to it (named D2) or a drain paragraph added beside it (D-new) fails; named D1 rewrites it; a
#     paragraph added to the sibling attested-act subsection stays green, D-near). Rule 11(a) item (4) cites that
#     subsection (r11a-lanes-dispatch) and the pointer counts four subsections (r11a-pointer). Those subsection headings are their own paragraphs to para mode, so each
#     lead is the bold opening of the paragraph under them. route.md Step 6's **Option labels carry
#     no recommendation.** paragraph says in the question why its options carry none
#     (route-say-why). All five are para rows; each token sits on ONE line of its subject.
#   - Rule 11(a)'s sort-before-asking: the unbadged trigger names a value the operator alone owns
#     (r11a-value-trigger), and the `Sort every question three ways` paragraph pins its decide, provided-value,
#     no-widen, badged, tree-never-settles and outside-the-sort clauses, the tree's WHERE/HOW-only
#     scope, the lead-words exclusion, the scope confirmation kept outside the sort and the sentence
#     that a value-preserving choice decides no value (r11a-sort-*). All para rows. Their clause list
#     is also the receipt-bl876.sh clause list; keep the two byte-identical.
#   - SKILL.md Rule 32 touchpoint I cites the advisor gate's window, so one consult covers a run
#     of pushes, merges and deploys inside it (r32-i-window, a line-mode `contains` pin: keep the
#     phrase on ONE line, and not on the `- **I --` line itself, which opens the span). Section 4g
#     binds the window size the item STATES to the hook's `ADVISOR_GATE_WINDOW` default, so the
#     prose cannot drift from the hook it names.
#   - a discharge predicate that filters on a literal a component of this repository writes carries
#     a sha-pinned `derived` fence citing the producing line, and a literal written nowhere at that
#     sha is REJECT unless the predicate names its external source (qa.md Validation Checklist,
#     pred-lit-qa); pm.md names the AC requiring the literal and leaves the fence owed at gate 2
#     (pred-lit-pm); an ADR probe keyed on such a literal carries the same fence (architect.md
#     evidence contract, pred-lit-arch). qa.md's sha-pinned `git grep` fence form is pinned by
#     pred-lit-qa-fence; pm.md's gate-2 fence clause is pinned by pred-lit-pm-gate. pred-lit-qa,
#     pred-lit-qa-fence, pred-lit-pm and pred-lit-pm-gate are line-mode `contains` pins: keep each phrase on ONE line. The named mutant softens the REJECT to a note.
#   - at `done` the closing writer copies each deferred AC's id AND its predicate text into the
#     story file's `## Deferred ACs`, entries opening `- **<id>**`, `None.` for none, placed before
#     `## Dev Agent Record` (code-reviewer.md Ownership; qa.md's discharge-predicate item), and
#     deploy-validate.md §4b reads the predicate there, falls back to the QA verdict for a story
#     with no section, reports a missing entry as a closing-writer defect, and checks every literal
#     against the DEPLOYED sha, recording a correction as `old -> new` (def-copy-*). The cr and qa
#     rows are line-mode `contains` pins inside lists para mode cannot split: keep each pinned
#     phrase on ONE line. The named def-copy-cr-pred mutant is the ids-only rewrite.
#   - a visual-drift fix-forward in deploy-validate.md §4: the `dev` brief names the browser specs, the
#     dev records their run or why they could not run, and when they could not run the lead runs them
#     against the redeployed instance and records that run as the `playwright` evidence (the ff-specs
#     rows, para pins: the §4 list is ONE paragraph whose lead is its first line).
#   - the BMAD 6.11 call-site spellings that Check 32 cannot score, because it reads skill NAMES
#     only: each readiness site (architecture.md §3, stories-test-strategy.md §1) states
#     `intent=readiness` AND "do not create or modify sprint-status.yaml" (the *-ready-* rows, two
#     line-mode `contains` pins on the one line, neither lead a prefix of the other; two named m3
#     mutants drop the intent and the clause in turn, each with the other row as its twin); each
#     sprint-planning site states `intent=sprint-planning` (sts-plan-intent, bug-plan-intent); each one-shot dispatch site names the adversarial
#     lens (bug-2c-lens, bug-4-lens-*, srev-lens, arch-role-fold-lens); and each deep-recon call
#     states its type (rr-recon-*, req-recon-*). The two §4 one-shot rows are led by text unique
#     to their own line, so one site losing its lens cannot be covered by the other. Keep each
#     pinned phrase on ONE line.
#   - a wide leaf round may be run by ONE round-dispatcher (rule-28.md (a) and "A wide round is run
#     by a round-dispatcher", _dispatch-protocol.md "Round-dispatcher brief"): repair, code review and
#     QA rounds stay lead-dispatched, each excluded in its own sentence so a scope inversion fails;
#     the dispatcher joins in the FOREGROUND and ends in one return-file write; the lead joins that
#     file alone. The r28-rd-* and dp-rd-* rows are para pins, read by the corpus arm below (--report).
#   - a sharded party round is per-seat role-bound `Agent` spawns and an unsharded one stays on the
#     Skill (_gate-procedures.md "Validation cycle" item 1, rule-20.md (i) and (v), rule-28.md's
#     dispatcher scope, carry-over-evaluation.md §3, sprint-review.md §2); the record of a seat is
#     its spawn-ledger row and its `--mark` line, its seats write no provenance block, and Check 17
#     runs no arm on a seat file. The gp-party-*, r20-i-*, r20-v-*, gv17-seat-record,
#     coe-party-per-seat, srev-party-per-seat and r28-rd-party-skill rows are para pins, also
#     read by the corpus arm below (--report).
#   - gate-validation.md Check 9 at an `implementation` gate (BL-934): the header says "deployment
#     not claimed" is Check 8's scope clause alone (gv9-header-check8, a POSITIVE pin; `absent` mode
#     ignores spans, so no absence row is built); inside `### 9.`..`### 10.` the per-story lead and
#     "No `implementation` gate fetches a production URL." (gv9-perstory-*), a re-review pass's
#     gate-1 manifest base "is the prior reviewed sha and is never the range" (gv9-perstory-rereview),
#     every one-story gate's `<base>` is the PASS-1 gate-1 manifest's base (gv9-perstory-pass1base),
#     the UI-path command and its control run from the worktree top (gv9-uipath-toplevel), the multi-story UNION
#     rule in BOTH directions -- one no-UI story beside one UI story takes the UI branch
#     (gv9-union-overinc, gv9-union-binds, gv9-union-whole) and an all-no-UI union self-skips
#     (gv9-union-skip) -- the self-skip's non-zero pathspec control (gv9-skip-*, gv9-uipath-control),
#     the all-not-any test exemption (gv9-uipath-all), the MANDATORY source-vs-mockup comparison and
#     its FAIL bar (gv9-ui-*), "An OWED record is never itself a PASS" (gv9-owed-notpass), an absent
#     `is_ui_epic` is not a skip (gv9-absent-flag), and at a `retro` gate Check 9 adopts
#     deploy-validate.md §4's recorded evidence and the read-only adjudicator never fetches a
#     production URL (gv9-retro-adopt). All para rows; each token sits on ONE line of its subject. Section 4k moves
#     each paragraph to just ABOVE its span's start line, the boundary-adjacent near-miss the
#     generic relocate (to the end of the file) does not exercise, and binds Check 9's inline UI
#     pathspec and test-file filter to validate-mandatory-rules.sh Check 5's two lines, both sides
#     derived, so a drift in EITHER file fails. BL-868: zero load-dependent tests -- every arm is a
#     text pin over a file, nothing is timed or counted under load. KNOWN LIMIT (F3, as the
#     elicitation rows above): a pin proves the clause is PRESENT in its span, not that no sentence
#     contradicting it was appended; a reviewer reads for that.
#   - the retro gate is RUN and blocks (BL-939). Inside `### 9.`..`### 10.` the drift-not-fixed
#     sentence (gv9-retro-fyi) and the retro FAIL bar (gv9-retro-failbar) under the adoption lead;
#     inside `### 17.`..`### 18.` the Retro gate bullet's TWO-argument call (gv17-retro-args, whose
#     named mutant is the pre-fix one-argument form, byte-for-byte); inside retro.md
#     `### 5c.`..`### 6. Commit, Push, and PR` item 6 runs gate validation [retro] and its FAIL
#     blocks the commit (retro-gate-invoked), the escalation paragraph's widened check list
#     (retro-gate-blocks), check 6's disposition in the form Check 26 reads (retro-gate-d2), and
#     the six-check count (retro-gate-count). All para rows; each token sits on ONE line of its
#     subject. Section 4k's start-boundary near-miss covers every row of this bullet too, and
#     section 4l adds retro-gate-invoked's two named near-misses: the lowercase
#     `run gate validation [retro]` prose of the Gate type paragraph alone, item 6 deleted, and an
#     item negated to `6. **Do not run gate validation [retro]**`; neither may satisfy the row.
#     The retro acceptance clauses (gv9-retro-thissprint, -citednowhere, -livearchive, -composed,
#     -readarchive, -mockupmerged, -headersn,
#     -othersprint, -names, -archive, -supcite, -captured, -matchrc, -pruned, -dateonly, -onlyhere,
#     -nowhereelse, -supcheck, -supts, -mergecommit, -amendsha, -markupdev, -wholeanswer, -archivenames,
#     -resolvedfloor, -mergederive, -authsource): an escalation is cited
#     only from this sprint's gate-log sections, live or in its own s<N>/ archive, paths composed
#     from N and named exactly (gate-log-archive.md and its -2, -3 ordinals); read from pending.md or pending-archive.md; the cited entry alone verified, RESOLVED
#     and SUPPRESSED alike, by --cite ... --accept-captured, on rc 0 with MATCH on stdout; a pruned
#     transcript accepted only on an in-window captured answer the quote equals whole; a line with no
#     time of day never verifies; the flag passed only here; any cited entry post-dates the section
#     Timestamp: and a waiver names `[core] 9 — `; the mockup read as of the sprint's merge commit,
#     derived from retro.md Step 1's PR_HEAD; the quote and timestamp read from the entry's
#     Operator authorization line alone (-authsource); a later amendment counts only citing a verifying
#     RESOLVED id; a no-markup surface's added markup is a deviation; the §4 line is read from this
#     sprint's sections live or archived (-readarchive); the mockup compared is the merged one
#     (-mockupmerged); the cited entry's header names S<N> (-headersn). Section 4m deletes each and
#     asserts it fails ONLY its row.
#     BL-868: zero load-dependent tests -- these are text pins over files. KNOWN LIMIT (F3): a pin
#     proves the clause PRESENT in its span, never the absence of an appended contradiction.
#   - the retro gate's own gate-log entry is committed before the Step 6b push and archived by
#     7a-post's rotation. Inside retro.md `### 7.`..`3. Archive the WHOLE live log verbatim`,
#     7a-post item 2 names the retro gate's entry as one of the sprint's writes
#     (retro-7apost-own-entry) and says Step 5c check 6 appends one per dispatch
#     (retro-7apost-per-dispatch). Para rows bound to item 2 ALONE, twice over: a blank line
#     separates item 2 from item 3, so they are two paragraphs to para mode and to the flattener;
#     and the span ENDS at item 3's lead, so a scan flushes item 2 there even where that blank line
#     is gone. Without both, the clauses moved into item 3's first line (old sentence back in
#     item 2) still pinned. An `exact` row cannot do it: exact needs ONE non-heading paragraph in
#     its span, and the only span holding item 2 alone ends mid-paragraph in the flattened copy,
#     so the flattened control reads 0. Section 4a's named mutants restore the old "Retro appends
#     no gate entry; deploy-validate's was the last write." sentence against each row, and drop
#     the own-entry clause alone, whose twin keeps the per-dispatch row pinned in that copy; the
#     retro-7apost/moved block below them reproduces the move into item 3, blank line removed,
#     and must fail both rows while the moved clauses stay in the file.
#
# LEADS ARE NOT ENOUGH. A bold lead left intact over a body rewritten to say the opposite
# ("need NOT carry", "dropped only through a HARD_BLOCK", "an assertion is a sufficient
# disposition", a MAJOR downgraded to MINOR) passed every lead-only pin. The para rows pin
# the binding clause inside the lead's own paragraph, and a negation mutant proves each.
#
# WHY SECTION-BOUNDED. A whole-file grep closes on any mention anywhere, including a comment,
# a fenced example, or the same sentence moved into a section that does not bind. Every pin
# therefore requires its line INSIDE a named span, anchored at line start, outside fences and
# outside line-leading HTML comments. Each pin is shown to fail on a deletion mutant, on the
# line relocated outside its span, on the line wrapped in a fence, on the line wrapped in a
# comment, and (for line-start pins) on the line indented — all on mktemp copies, before the
# real corpus is read.
#
# TWO MODES THAT ARE NOT PRESENCE-IN-PROSE PINS. `fenced` counts a hit INSIDE a fenced block as
# well as outside (a template whose lines live in a fence), still bounded by the span; every
# other mode treats fenced lines as invisible. `absent` takes the token in the LEAD field, ignores
# the span fields and the fence and comment rules, and requires 0 hits anywhere in the file: it
# pins that a definition lives in one file only. `absent` catches a verbatim copy, not a
# paraphrase. It is a tripwire, not a guarantee. Both are keyed on the row's mode field alone.
#
# `exact` IS PARA MODE WITH AN END ANCHOR. It reads paragraphs exactly as `para` does (same span,
# fence and comment rules, whitespace collapsed, trailing blank dropped), and a hit is a paragraph
# that begins with the lead and EQUALS the token, the whole pinned paragraph. The span must also
# hold exactly ONE non-heading paragraph, or the row reads in-span 0. A `para` row passes a
# sentence appended after its clause or a paragraph added beside it; an `exact` row fails both.
# Its generic mutants are the para set plus `append` (a sentence added to the paragraph must
# fail). Section 2 probes it both ways.
#
# LAYOUTS. The subject exists on a consumer too, so this fixture ships. The root is found by
# walking up from this script for the skill directory — core/skills/ai-dlc in the
# distribution, .claude/skills/ai-dlc in an installed consumer — never by counting hops, and
# never from the cwd. The cwd arm at the end re-runs the corpus from a decoy tree and requires
# a byte-identical verdict.
set -uo pipefail
# Section 4g reads the advisor gate hook's TEXT and never runs it; no AI_DLC_* is read here (the root
# is walked up from this script), so the ambient set is scrubbed whole.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/$(basename "$0")"

# resolve_root <start-dir> [<ceiling>] -> prints "<layout> <root>", or fails. The ceiling
# exists for the probes only: it is the last directory examined, so a probe tree cannot be
# rescued by whatever happens to sit above the temp directory.
resolve_root() {
  local d="$1" ceil="${2:-}"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -d "$d/core/skills/ai-dlc" ] && [ -d "$d/core/team-roles" ]; then
      printf 'dist %s\n' "$d"; return 0
    fi
    if [ -d "$d/.claude/skills/ai-dlc" ] && [ -d "$d/.claude/team-roles" ]; then
      printf 'consumer %s\n' "$d"; return 0
    fi
    [ -n "$ceil" ] && [ "$d" = "$ceil" ] && return 1
    d="$(dirname "$d")"
  done
  return 1
}

dirs_for() { # dirs_for "<layout> <root>" -> sets SKILL_DIR ROLES_DIR ROOT LAYOUT
  LAYOUT="${1%% *}"; ROOT="${1#* }"
  case "$LAYOUT" in
    dist)     SKILL_DIR="$ROOT/core/skills/ai-dlc";    ROLES_DIR="$ROOT/core/team-roles" ;;
    consumer) SKILL_DIR="$ROOT/.claude/skills/ai-dlc"; ROLES_DIR="$ROOT/.claude/team-roles" ;;
    *) return 1 ;;
  esac
}

# pin_scan <file> <span-start-prefix|""> <span-end-prefix> <lead> <prefix|contains|para|exact> [<token>]
#   prints "<in-span hits> <whole-file hits> <span start line> <span end line> <first hit line>"
#   Fenced lines and <!-- --> comments are invisible to every test, the span markers
#   included. A comment opened MID-LINE hides everything after it until its close, exactly
#   as a renderer does. An empty start means the span opens at line 1. rc 2 on an
#   unbalanced fence or comment, which would otherwise make every later line invisible.
#
#   para mode tests PARAGRAPHS, not lines: blank-line separated, whitespace collapsed, so a
#   binding clause wrapped across lines is one string. A hit is a paragraph that BEGINS with
#   the lead and CONTAINS the token. That is what pins the binding sentence under a bold
#   lead, which a lead-only pin cannot see negated.
pin_scan() {
  PS_START="$2" PS_END="$3" PS_LEAD="$4" PS_MODE="$5" PS_TOK="${6:-}" awk '
  function flush(   q) {
    if (p == "") return
    q = p; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q)
    if (x) { sub(/ $/, "", q); h = (index(q, l) == 1 && q == k); if (pst == 1 && substr(q, 1, 1) != "#") np++ }
    else h = (index(q, l) == 1 && index(q, k) > 0)
    if (h) { whole++; if (fl == 0) fl = pl; if (pst == 1) ins++ }
    p = ""
  }
  BEGIN { s = ENVIRON["PS_START"]; e = ENVIRON["PS_END"]; l = ENVIRON["PS_LEAD"]; m = ENVIRON["PS_MODE"]
          k = ENVIRON["PS_TOK"]
          # exact is para with an end anchor: every para rule below applies, flush() alone differs.
          # np counts the non-heading paragraphs in span; an exact span holding any but one reads 0.
          x = 0; np = 0; if (m == "exact") { x = 1; m = "para" }
          fence = ""; com = 0; ins = 0; whole = 0; el = 0; fl = 0; p = ""
          if (s == "") { state = 1; sl = 1 } else { state = 0; sl = 0 } }
  {
    line = $0
    if (m == "absent") { if (index(line, l) > 0) { whole++; if (fl == 0) fl = NR }; next }
    if (com) { if (index(line, "-->")) com = 0; if (m == "para") flush(); next }
    t = line; sub(/^[ \t]+/, "", t)
    if (fence == "") {
      if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { fence = substr(t, 1, 3); if (m == "para") flush(); next }
    } else {
      if (substr(t, 1, 3) == fence) fence = ""
      else if (m == "fenced" && index(line, l) > 0) { whole++; if (fl == 0) fl = NR; if (state == 1) ins++ }
      next
    }
    if (substr(t, 1, 4) == "<!--") { if (index(substr(t, 5), "-->") == 0) com = 1; if (m == "para") flush(); next }
    c = index(line, "<!--")
    if (c > 0 && index(substr(line, c + 4), "-->") == 0) { line = substr(line, 1, c - 1); com = 1 }
    if (m == "para") {
      if (line ~ /^[ \t]*$/) { flush(); next }
      if (state == 0) { if (index(line, s) == 1) { flush(); state = 1; sl = NR }; if (p == "") { p = line; pl = NR; pst = state } else p = p " " line; next }
      if (state == 1 && index(line, e) == 1) { flush(); state = 2; el = NR; next }
      if (substr(line, 1, 1) == "#") { flush(); p = line; pl = NR; pst = state; flush(); next }
      if (p == "") { p = line; pl = NR; pst = state } else p = p " " line
      next
    }
    if (m == "contains" || m == "fenced") hit = (index(line, l) > 0); else hit = (index(line, l) == 1)
    if (hit) { whole++; if (fl == 0) fl = NR }
    if (state == 0) { if (index(line, s) == 1) { state = 1; sl = NR }; next }
    if (state == 1) {
      if (index(line, e) == 1) { state = 2; el = NR; next }
      if (hit) ins++
    }
  }
  END { if (m == "absent") { print whole, whole, 1, 1, fl; exit 0 }
        if (m == "para") flush()
        if (x && np != 1) ins = 0
        if (fence != "" || com) { print "UNBALANCED"; exit 2 }
        print ins, whole, sl, el, fl }' "$1"
}

# The pin table. Fields: id | S (skill dir) or R (roles dir) | relative file | span start
# (empty = top of file) | span end | lead | match mode | token (para mode only).
#
# The para rows pin the BINDING sentence beneath a lead: a lead-only pin passes a body
# rewritten to say the opposite. Each token is the clause whose negation inverts the rule.
# Two texts are deliberately NOT pinned because they are being reworded: the repair clause of
# the attribution rung, and the closing sentence of the §2c disposal paragraph.
#
# The pm-adr-* rows are line-mode `contains` pins inside one bullet list that `para` cannot
# split. The line breaks in that pm.md bullet and in its Context Loading item 3 exist to keep
# each pinned phrase on ONE line; reflowing either breaks the pin, so do not reflow them.
# A comment line cannot go inside the table below: every line between the markers is a row.
pins() {
  cat <<'PINS'
gv-series-form|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The series id is decided at dispatch, never from `close`.**|para|Its form is exactly `<gate_type>-<slug>-s<N>-<TS>` for a gate dispatched for exactly one story and exactly `<gate_type>-s<N>-<TS>` for every other gate, with nothing between the fields
gv-series-sprintid|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The series id is decided at dispatch, never from `close`.**|para|`<N>` is the `sprint_id` line of `_bmad-output/pipeline-snapshot.md` (not `sprint-status.sh sprint-id`) with no leading zero
gv-series-reset|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|If this dispatch is pass 1 of a **Gate Reset**, the id that reset minted wins.
gv-series-reuse|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|Otherwise, if that candidate did not pass, reuse its id byte-for-byte.
gv-series-wellformed|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The series id is decided at dispatch, never from `close`.**|para|`<slug>` is `story` followed by lowercase `[a-z0-9]`
gv-series-placement|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The series id is decided at dispatch, never from `close`.**|para|so the slug goes before the sprint field and never after it.
gv-series-slug|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The slug names the one story the gate was dispatched for.**|para|Its only source is the `<story-index>` the lead writes on this gate's adjudicator brief as its `story: <story-index>` line
gv-series-slugnorm|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The slug names the one story the gate was dispatched for.**|para|strip any trailing punctuation from the index, lowercase it and write each `.` or `-` as `x`, then prefix `story`
gv-series-unscoped|S|steps/gate-validation.md|## Validation Checklist|### 1.|**The slug names the one story the gate was dispatched for.**|para|A gate dispatched over several stories, or over none, carries no `story:` line and no slug, whichever gate number it is.
gv-series-lookup|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|whose `gate_series_id` is in that exact form for this `gate_type`, this gate's slug (or no slug) and the current `sprint_id`.
gv-series-notpassing|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|A pass whose parts never merged into a verdict counts as not passing.
gv-series-ledger|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|When its ledger `.gate-checkpoint/<its gate_nonce>.tsv` exists and has a `26` row, that row decides, never the verdict's per-check rows: `PASS` passes and any other value does not
gv-series-fallback|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|When the ledger is absent or has no `26` row, judge the verdict itself: a verdict with no `FAIL` row passes and one with any `FAIL` row does not, because the ledger is local to the checkout that ran the gate
gv-series-parts|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|A stem carrying another slug, another sprint or any other form is not a candidate, and neither is a part set whose parts disagree on the id or lack it.
gv-series-noreuse|S|steps/gate-validation.md|## Validation Checklist|### 1.|With no candidate, rule 3 mints|para|so a malformed id is never reused, and two stories' gates in flight together never share a series.
gv-reset-before|S|steps/gate-validation.md|## Gate Reset|## Not self-authorizable|A reset is performed BEFORE gate entry, before pass 1's `gate_nonce` is minted|contains
gv-reset-slug|S|steps/gate-validation.md|## Gate Reset|## Not self-authorizable|its slug, as `<gate_type>-<slug>-s<N>-<reset TS>`.|contains
gv-series-mint|S|steps/gate-validation.md|## Validation Checklist|### 1.|Find the newest stem|para|Otherwise mint the id in that form with `<TS>` this nonce's timestamp.
gv-series-noclose|S|steps/gate-validation.md|## Validation Checklist|### 1.|Whether `gate-checkpoint.sh close` ran plays no part in the choice.|para|a series still carrying an old-form id is not continued
gv-series-nononce|S|steps/gate-validation.md|## Validation Checklist|### 1.|Whether `gate-checkpoint.sh close` ran plays no part in the choice.|para|it is never passed to `gate-checkpoint.sh --nonce`
gv-series-exempt|S|steps/gate-validation.md|## Validation Checklist|### 1.|**Record every verdict the moment it is reached.**|para|The `gate_series_id` is exempt from that: the same-series rule above decides whether it carries forward.
gv-fail-series|S|steps/gate-validation.md|## Gate Failure|## Gate Reset|`gate_series_id` rides into that dispatch's brief under the same-series rule|contains
gv-reset-mint|S|steps/gate-validation.md|## Gate Reset|## Not self-authorizable|1. Mint the new id as `<gate_type>-s<N>-<reset TS>`|contains
gv-reset-legacy|S|steps/gate-validation.md|## Gate Reset|## Not self-authorizable|entry naming the retired `gate_series_id` (or `legacy` when the retired series|contains
gv-reset-stamp|S|steps/gate-validation.md|## Gate Reset|## Not self-authorizable|3. Run the gate from pass 1 under the new `gate_series_id`, which is stamped on the next dispatch's brief.|prefix
gp-missing-report|S|steps/_gate-procedures.md|## Bounded-join beat (referenced by step files)|## Gate-adjudication dispatch|**A missing completion report is not non-delivery.**|para|read the deliverable and `_bmad-output/.subagent-final/<agent_id>.txt` before treating it as non-delivery or re-dispatching.
gp-brief-series|S|steps/_gate-procedures.md|## Gate-adjudication dispatch|## Validation cycle|**Dispatch** ONE `gate-adjudicator`|para|the `gate_series_id` decided by the same-series rule in `gate-validation.md` "At gate entry"
gp-shard-series|S|steps/_gate-procedures.md|## Gate-adjudication dispatch|## Validation cycle|**Shard the worklist|para|the one `gate_series_id` every shard of this dispatch stamps, since `--merge` refuses parts that disagree on it
gp-story-series|S|steps/_gate-procedures.md|## Gate-adjudication dispatch|## Validation cycle|**Dispatch** ONE `gate-adjudicator`|para|When the gate is dispatched for exactly one story, the brief also carries a `story: <story-index>` line naming it, the only source of the series id's slug; a gate dispatched over several stories, or over none, carries no `story:` line.
gp-shardstory-series|S|steps/_gate-procedures.md|## Gate-adjudication dispatch|## Validation cycle|**Shard the worklist|para|the gate's `story: <story-index>` line when it has one
gp-advname-shard|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Adversarial repair name.**|para|never `<artifact>-adversarial-repair-p<M>` or `<artifact>-adversarial-p<k>-repair-p<M>`, and the join refuses an artifact ending in `-adversarial`
gp-advname-record|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Repair record name, again.**|para|never `<artifact>-adversarial-repair-p<M>.md` or `<artifact>-adversarial-p<k>-repair-p<M>.md`, whether a join or a serial remediator writes it; the join refuses the first of those wrong shapes
gp-redispatch-series|S|steps/_gate-procedures.md|## Gate-adjudication dispatch|## Validation cycle|**A re-dispatch is a whole new dispatch.**|para|The `gate_series_id` is exempt: the same-series rule decides it at dispatch, never `close`.
gadj-brief-series|R|gate-adjudicator.md|## Contract|## The verdict|The lead's dispatch gives you|para|(e) the `gate_series_id`
gadj-copy-series|R|gate-adjudicator.md|## The verdict|## Ownership|Write exactly the shape below.|para|`gate_series_id` is copied byte-for-byte from your brief, never invented
gadj-fail-surface|R|gate-adjudicator.md|## Contract|## The verdict|4. **Every verdict is PASS or FAIL with non-empty evidence.|para|comparison surface
gadj-fail-exhausted|R|gate-adjudicator.md|## Contract|## The verdict|4. **Every verdict is PASS or FAIL with non-empty evidence.|para|exhausted
gadj-fail-scope|R|gate-adjudicator.md|## Contract|## The verdict|4. **Every verdict is PASS or FAIL with non-empty evidence.|para|could evaluate
gv-body-must|S|steps/gate-validation.md|### 12.|### 13.|**A state claim MUST carry its command.**|para|MUST carry, in the same row
gv-body-output|S|steps/gate-validation.md|### 12.|### 13.|**A state claim MUST carry its command.**|para|the command that produced it and that command's output
r13-body-void|S|rule-bodies/rule-13.md||## HANDOFF PROTOCOL|**An operator attribution MUST cite the operator's message.**|para|never entered the locked set
r13-body-locator|S|rule-bodies/rule-13.md||## HANDOFF PROTOCOL|**An operator attribution MUST cite the operator's message.**|para|a verbatim quote of the operator's message and a locator
disc-body-struck|S|steps/discovery.md|### 4a.|### 4b|**Every operator attribution carries a quote and a locator**|para|is struck here and never enters `LOCKED_REQUIREMENTS`
esc-body-hardblock|S|escalations.md|**Permanent-default change disclosure.**|**Terminal-entry archival|**Authorization-premise invalidation disclosure.**|para|File a new `HARD_BLOCK` entry
esc-body-operator|S|escalations.md|**Permanent-default change disclosure.**|**Terminal-entry archival|**Authorization-premise invalidation disclosure.**|para|put the question back to the operator
bug-2b-included|S|steps/bug-investigation.md|### 2b.|### 2c.|**The lead cannot apply the relief, so nothing substitutes for asking.**|para|between section 2 and section 3, §2c included.
bug-2c-adversary|S|steps/bug-investigation.md|### 2c.|### 3.|**The root-cause claim gets an adversarial pass before section 3.**|para|Dispatch ONE `adversary`
bug-2c-path|S|steps/bug-investigation.md|### 2c.|### 3.|It writes findings to|para|`_bmad-output/planning-artifacts/bug-analysis-adversarial.md`
bug-2c-evidence|S|steps/bug-investigation.md|### 2c.|### 3.|**Dispose of every CRITICAL and MAJOR before section 3**|para|An assertion without evidence is not a disposition.
adv-attr-body|R|adversary.md|## Severity|## |**An operator attribution missing its quote or its locator is a MAJOR.**|para|An attribution missing either is a MAJOR
adv-prem-body|R|adversary.md|## Severity|## |**An authorization whose named outcome a later event contradicted is a MAJOR.**|para|file a MAJOR.
gv-state-claim|S|steps/gate-validation.md|### 12.|### 13.|**A state claim MUST carry its command.**|prefix
r13-attribution|S|rule-bodies/rule-13.md||## HANDOFF PROTOCOL|**An operator attribution MUST cite the operator's message.**|prefix
disc-attribution|S|steps/discovery.md|### 4a.|### 4b|**Every operator attribution carries a quote and a locator**|prefix
esc-locked-disposition|S|escalations.md|**Resolution lifecycle:**|**RESOLVED / OVERRIDDEN must CITE the operator.**|the lead records the operator's disposition on the entry with its `Operator authorization:` citation|contains
esc-lead-interp-resolved|S|escalations.md|**Resolution lifecycle:**|**RESOLVED / OVERRIDDEN must CITE the operator.**|The lead-interpretation `HARD_BLOCK` of `steps/requirements.md` §3 is the other exception: when the operator's captured answer is an exact Strike or Reword option, the lead files it `RESOLVED`|prefix
esc-premise|S|escalations.md|**Permanent-default change disclosure.**|**Terminal-entry archival|**Authorization-premise invalidation disclosure.**|prefix
bug-2c-title|S|steps/bug-investigation.md|### 2b.|### 3.|### 2c. Adversarial verification of the root-cause claim|prefix
bug-2c-pass|S|steps/bug-investigation.md|### 2c.|### 3.|**The root-cause claim gets an adversarial pass before section 3.**|prefix
bug-2c-dispose|S|steps/bug-investigation.md|### 2c.|### 3.|**Dispose of every CRITICAL and MAJOR before section 3**|prefix
adv-attr-rung|R|adversary.md|## Severity|## |### An uncited operator attribution is a MAJOR|prefix
adv-attr-lead|R|adversary.md|## Severity|## |**An operator attribution missing its quote or its locator is a MAJOR.**|prefix
adv-prem-rung|R|adversary.md|## Severity|## |### A premise a later event contradicted is a MAJOR|prefix
adv-prem-lead|R|adversary.md|## Severity|## |**An authorization whose named outcome a later event contradicted is a MAJOR.**|prefix
route-range|S|steps/route.md|### Step 4:|### Step 5:|sections 0–2c|contains
route-cite-user|S|steps/route.md|### Step 6:|## FAILURE MODES|`user_request_cite` — the 64 hex characters after `- SHA256: `|contains
route-cite-scope|S|steps/route.md|### Step 6:|## FAILURE MODES|`scope_confirmed_cite` — the 64 hex characters after `- SHA256: `|contains
sts-range|S|steps/stories-test-strategy.md|### 3a.|### 4.|sections 0–2c|contains
sts-names-2c|S|steps/stories-test-strategy.md|### 3a.|### 4.|§2c's adversarial verification of the root-cause|contains
party-seats-record|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**The seats edit nothing, in every case below.**|para|Each seat writes one findings file per (seat, shard)
party-seats-sections|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**The seats edit nothing, in every case below.**|para|carrying one `sections:` line
party-early-write|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Every seat writes its file early and closes it with a completion line.**|para|Write the file's header first
party-complete-line|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Every seat writes its file early and closes it with a completion line.**|para|Every beat that joins such a file passes `--complete`
gp-snap-program|S|steps/_gate-procedures.md|## Sub-step snapshot update|## Bounded-join beat|**Write items 1–3 with ONE `bash scripts/ai-dlc/snapshot-update.sh` call**, never one Edit per row:|para|runs the write-time stamp check on the lines it added, and writes nothing on a finding
gp-beat-status|S|steps/_gate-procedures.md|## Bounded-join beat|## Gate-adjudication dispatch|**A progress check between beats is `scripts/ai-dlc/wait-for-deliverable.sh --complete --status <the wave's paths>`**|para|It is never a grep for `seat-complete:`, nor a listing or count of the shard directory
party-one-writer|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|never back to a seat
party-source|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|carries `source: <seat-file>#<finding-id>`
party-unsharded|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**An unsharded round has the same write model.**|para|the seats still edit nothing, and ONE remediator
party-unsharded-check|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**An unsharded round has the same write model.**|para|join-remediator-shards.sh --sources <that record> --sprint <N>
srev-seats-record|S|steps/sprint-review.md|### 2. Sprint-Level Party Mode|### 3.|- Record every finding; the seats edit nothing|prefix
srev-waves-cite|S|steps/sprint-review.md|### 2. Sprint-Level Party Mode|### 3.|PM, Architect, Dev, TEA and QA walk through the|para|bounded by the waves sentence of `_gate-procedures.md`, "Validation cycle" item 1, and Rule 28's Waves paragraph
srev-party-per-seat|S|steps/sprint-review.md|### 2. Sprint-Level Party Mode|### 3.|PM, Architect, Dev, TEA and QA walk through the|para|so it is that item's per-seat role-bound `Agent` spawns, never the `/bmad-party-mode` Skill
coe-party-per-seat|S|steps/carry-over-evaluation.md|### 3. Party Mode Evaluation|### 3a. Validation cycle (Rule 8)|PM, Architect, Dev, TEA evaluate every item.|para|A sharded round is that item's per-seat role-bound `Agent` spawns, never the Skill
gp-party-shape|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|1. Party mode — the step's seats walk|para|A sharded round (the seats x parts, seats x sections and seats x subject-parts cases below) is per-seat role-bound `Agent` spawns
gp-party-writer|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**When the subject is two or more files**|para|The record of a sharded party round's seat is the dispatch guard's spawn-ledger row for its spawn, written by the hook, and the seat's `--mark` line
gp-party-noblock|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**When the subject is two or more files**|para|Its seats write no `SKILL_INVOCATION_PROVENANCE` block, and Check 17 runs no arm on a seat file. A block stamped onto a seat file after the fact is a forged record, never a remediation.
r20-i-unsharded|S|rule-bodies/rule-20.md|Three provenance-bearing execution shapes|**(ii) Single-voice|**(i) Persona-spawning|para|This shape is an unsharded party round only; a sharded party round is shape (v).
r20-v-writer|S|rule-bodies/rule-20.md|**(iv) Gate-check adjudication|**Provenance block.**|**(v) Per-seat sharded party round|para|The record of each seat is the dispatch guard's spawn-ledger row for its spawn, written by the hook, and the seat's `--mark` line
r20-v-noblock|S|rule-bodies/rule-20.md|**(iv) Gate-check adjudication|**Provenance block.**|**(v) Per-seat sharded party round|para|Its seats write no `SKILL_INVOCATION_PROVENANCE` block, and Check 17 runs no arm on a seat file; a block stamped onto a seat file after the fact is a forged record
gv17-seat-record|S|steps/gate-validation.md|### 17. Skill-invocation provenance|### 18.|**Scope.** Runs at the retro gate|para|the record of a seat is the dispatch guard's spawn-ledger row for its spawn, written by the hook, and the seat's `--mark` line (Rule 20 (v)). This check runs no arm on a seat file.
gv17-seat-join|S|steps/gate-validation.md|### 17. Skill-invocation provenance|### 18.|**Scope.** Runs at the retro gate|para|A sharded party round's seat record is joined by `join-remediator-shards.sh` (`seat_row_check`, in the party parts join and in `--sources`), which refuses any sharded seat file `<step>-<seat>-<ordinal|cross>.md` of a cited step that has no `spawn-ledger.jsonl` row of that sprint, role, `role_contract_cited: true` and shard `<ordinal>/<K>` or `cross/<K>`.
rem-party-source|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**A party repair names the seat finding behind every entry.**|para|every entry carries a `source:` line
rem-sib-field|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|carries a `- siblings:` field
rem-sib-own-files|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|Never grep the sprint slot, `shards/` or any repair record
rem-sib-control|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|whose output is 1 or more
rem-sib-own-only|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|A files-mode shard greps ONLY its own files
rem-sib-insertion|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|writes `- siblings: n/a (insertion)`
rem-sib-section|R|remediator.md|## Contract|## The evidence contract|**As a section shard**|para|carries `- siblings: n/a (section shard; re-checked by the serial remediator after assembly)`
rem-sib-subject|R|remediator.md|## Contract|## The evidence contract|**As a subject shard**|para|carries `- siblings: n/a (section shard; re-checked by the serial remediator after assembly)`
gp-esc-sources|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|In `--sources` mode the `ESCALATED:` lines are the lead's to adjudicate, never a re-dispatch of the serial remediator
gp-cross-sib|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Moved cites are the serial remediator's, after the join.**|para|It also owns the cross-file sibling grep
rem-esc-outside|R|remediator.md|## Contract|## The evidence contract|**A fix that lies outside your files is escalated, never set aside.**|para|report it in your part as escalated
rem-esc-split|R|remediator.md|## Contract|## The evidence contract|**A fix that lies outside your files is escalated, never set aside.**|para|A partial repair is TWO entries carrying the same `source:` token
rem-esc-never|R|remediator.md|## Contract|## The evidence contract|**A fix that lies outside your files is escalated, never set aside.**|para|is never dispositioned `repaired` on the grounds
gp-esc-dispatch|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|In every mode (files, sections, subject), dispatch the serial remediators after the join whenever SERIAL-REQUIRED or ESCALATED-COUNT is above 0
gp-serial-lanes|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|Dispatch ONE serial remediator per lane, in parallel
gp-serial-fanin|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|A `HIT` never joins lanes, and neither does an escalation
gp-serial-lane-rec|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|round one's record FIRST, because a lane closes round one's escalations in its own record
gp-esc-shardline|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|the line `shard: none (authoring-chain)` (Rule 28 exception 3
gp-serial-count|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|`SERIAL-REQUIRED: <n>`, the count of `repaired` entries with a real edit
gp-esc-closes|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|never by a shared `source:` token
gp-serial-why|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Moved cites are the serial remediator's, after the join.**|para|That is why SERIAL-REQUIRED dispatches it
gp-serial-lane-own|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Moved cites are the serial remediator's, after the join.**|para|A lane remediator runs it for its lane's entries and edits only its lane's files
rem-serial-lane-own|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**As the serial remediator after a join**|para|As a lane remediator you edit ONLY the files your `LANE:` line names
rem-sib-fence-after|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|run the fence after your last edit; its output is empty, or lists only sites you dispositioned not to change
rem-sib-text-fence|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|The fence is `text`, never `derived`
rem-sib-forms-only|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|Any other spelling of the field (`- siblings: checked`, a value with no fence, a `derived` fence) is refused
rem-esc-edit-form|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|that file as `- edit: <project-relative path>:<line(s)> (escalated)`
gp-esc-nonparty|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|join-remediator-shards.sh --escalations <the joined record> [--escalations <its -serial-repair record>] --sprint <N>
rem-sib-deletion|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**Re-check every sibling of the text you replaced.**|para|writes `- siblings: n/a (deletion)`
rem-serial-scope|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**As the serial remediator after a join**|para|after a files-mode join that is `_bmad-output/planning-artifacts/s<N>/stories _bmad-output/planning-artifacts/s<N>/epics`
rem-serial-closes|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**As the serial remediator after a join**|para|carries `- closes: <part> <heading>`, copied from the tail of its `ESCALATED:` line
gp-esc-brief|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Every escalated entry reaches the serial remediator.**|para|each brief carrying its `LANE:` line, its `LANE-ITEM:` lines and every `ESCALATED:` line verbatim
gp-moved-cites|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Moved cites are the serial remediator's, after the join.**|para|re-reads every cite into each edited file AFTER the join or assembly
gp-rerun-trigger|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|After a join refusal naming a file|para|or a file `written by more than one agent in the window`
gp-rerun-flag|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1b. **Re-run one part with `--rerun`.**|para|Keep the refused join's `--since <ISO>`, take a NEW `--until <ISO>` after the re-run part reports, and add `--rerun <part>.md@<S_P>`
gp-rerun-window|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1b. **Re-run one part with `--rerun`.**|para|S_P falls inside that window
gp-rerun-record|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1b. **Re-run one part with `--rerun`.**|para|the join refuses that record written after S_P by anyone else, or not at all by the re-run writer
gp-rerun-new|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1b. **Re-run one part with `--rerun`.**|para|The re-run is a NEW dispatch with a new agent id, never a continuation of the refused part's agent
gp-rerun-diff|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1b. **Re-run one part with `--rerun`.**|para|Its brief requires the re-run remediator to account for the whole section diff against the split slice
gp-rerun-sp|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1b. **Re-run one part with `--rerun`.**|para|The lead picks S_P by reading `date -u +%Y-%m-%dT%H:%M:%SZ` after the refused part's writer has stopped and immediately before sending the re-dispatch
gp-rerun-doc|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1. **Split.** `scripts/ai-dlc/partition-document.sh --split|para|When one section's remediator was re-run, add `--rerun <part>.md@<S_P>`
gp-rerun-subj|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1. **Split.** `scripts/ai-dlc/partition-subject.sh --split|para|When one part's remediator was re-run, add `--rerun <part>.md@<S_P>`
pm-adr-probe|R|pm.md|## Responsibilities|## The evidence contract|in the story implementing the decision the ADR records|contains
pm-adr-trigger|R|pm.md|## Responsibilities|## The evidence contract|carries as an unrun probe|contains
pm-adr-tag|R|pm.md|## Responsibilities|## The evidence contract|`probabilistic/passive-monitoring` AC, written at creation|contains
pm-adr-predicate|R|pm.md|## Responsibilities|## The evidence contract|with its discharge predicate named in the AC text|contains
pm-adr-scope|R|pm.md|## Responsibilities|## The evidence contract|added to existing scope, never a new capability|contains
pm-adr-context|R|pm.md|## Context Loading|## Communication|(the primary architecture document)|contains
pm-adr-context-read|R|pm.md|## Context Loading|## Communication|The architecture and ADR sections for the stories in scope|contains
sts-esc-why|S|steps/stories-test-strategy.md|**Routing map|Absent any routing tag|or whose owned paths are capital-path or high-blast-radius|contains
sts-esc-first|S|steps/stories-test-strategy.md|**Model escalation**|**Protected-path catalog**|- `escalate_model: true`|para|before the story's FIRST dev dispatch
impl-esc-cut|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|reachable on the dev's branch base
impl-esc-before|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|BEFORE the dev worktree is cut
impl-esc-keep|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|A story already dispatched keeps its route
impl-esc-false|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|is absent or `false`
dve-capital|R|dev-escalated.md|## Identity|## Contract|capital-path / high-blast-radius owned paths|contains
elic-shape-files|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|one `adversary` per story ordinal plus ONE cross-story `adversary` for stories elicitation, briefed with every ordinal and writing `cross.md`, never one per cross group and never one voice under `shard: none (serial-document)`
elic-shape-sections|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|one `adversary` per part plus ONE cross-part `adversary` writing `cross.md`; a `SERIAL:` answer is ONE `adversary` under `shard: none (serial-document)`
elic-shape-ordinals|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|The story ordinals are the ones `scripts/ai-dlc/merge-adversarial-shards.sh --map <shards-dir>` prints, `<shards-dir>` being the path `scripts/ai-dlc/partition-document.sh --shard-dir <artifact path> <M> [--sprint <N>]` prints for the next review pass (shaped `s<N>/shards/<artifact>-p<M>/`), which the lead runs first
elic-shape-onefile|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|A `stories/` holding ONE file is ONE `adversary` briefed `shard: 1/1 <story-index>`
gp-revised-seats|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|The remediator brief also carries `revised-seats:`
gp-revised-token|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|`REVISED-AFTER-MARKER <n> <path> --`
gp-revised-status|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|wait-for-deliverable.sh --complete --status --since <the round epoch> --dispatch <agentId>
rem-revised-seats|R|remediator.md|## Contract|## The evidence contract|**A brief that carries `revised-seats: <path>…`**|para|Re-read each named seat's findings from the file on disk
elic-shape-expectsha|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|split into that same shard dir with `--expect-sha` the sha every elicitation shard notarized
elic-shape-lead|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|a lighter shape is not the lead's to choose
sts-elic-sharded|S|steps/stories-test-strategy.md|### 4.|### 5.|Elicitation is sharded per|contains
gp-held-validator|S|steps/_gate-procedures.md|## Sub-step snapshot update|## Bounded-join beat|Run `scripts/ai-dlc/validate-held-stories.sh`. On exit 1,|para|dispatch or hold each UNACCOUNTED story before the next wave
dp-wave-held|S|steps/_dispatch-protocol.md|A blocking (`run_in_background: false`|**Minimum mechanism (Rule 26(c))|**Bounded-join ≠ serial execution.**|para|Every story not in wave 1 gets a `held:` line when the plan is written
impl-rr-delta|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|the partition runs with `<prior-sha>` in place of `<base>`
impl-rr-prior|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|column-0 `reviewed-sha:` of the pass M-1 review file
impl-rr-fanout|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|dispatches through this same fan-out
impl-rr-fallback|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|partitions the full `<base>..<frozen-sha>` range instead
impl-rr-never|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|never dispatches a `shard: 1/1` delta of no stated range
impl-rr-story|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|is briefed with the whole story record and the full `git diff <prior-sha>..<frozen-sha>` including scan-root paths
impl-rr-parts|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|every part reviewer gets the story record as context
impl-rr-carry|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|Every Critical and Important `#### ` finding of pass M-1 is carried
cr-serial-heading|R|code-reviewer.md|## Review Document Template|## As a Shard|**A serial review writes its findings the way a shard does.**|para|never a bullet
cr-serial-sha|R|code-reviewer.md|## Review Document Template|## As a Shard|**A serial review writes its findings the way a shard does.**|para|column-0 `reviewed-sha: <full frozen sha>` line
impl-serial-form|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|A serial review writes its findings the way a shard does, each a `#### ` heading under its container, never a bullet
impl-serial-sha|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|carries one column-0 `reviewed-sha: <full frozen sha>` line
impl-rr-list|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|Paste each carried-findings line the plan lists (the program ran `validate-carried-findings.sh --list` of the pass M-1 file) into the brief of the shard that carries that finding, verbatim
impl-rr-reemit|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|an `open` one is re-emitted as a finding of this pass
adv-rebind-rung|R|adversary.md|## Severity|## |### An unpriced rebind is a MAJOR|prefix
adv-rebind-trigger|R|adversary.md|## Severity|## |**A re-target prices every literal keyed on it, under both bindings.**|para|while its text stays the same, where a literal or threshold downstream is computed from or compared against it
adv-rebind-every|R|adversary.md|## Severity|## |**A re-target prices every literal keyed on it, under both bindings.**|para|every literal and threshold the re-bound value flows into
adv-rebind-unit|R|adversary.md|## Severity|## |**A re-target prices every literal keyed on it, under both bindings.**|para|in the unit it is compared against
adv-rebind-untouched|R|adversary.md|## Severity|## |**A re-target prices every literal keyed on it, under both bindings.**|para|A literal the diff does not touch is in scope for exactly that reason
adv-rebind-oldnew|R|adversary.md|## Severity|## |**A re-target prices every literal keyed on it, under both bindings.**|para|record `old -> new` for each
adv-rebind-major|R|adversary.md|## Severity|## |**An unpriced rebind is a plain MAJOR, and it never counts in `findings_major_underived`.**|para|the third test of that field fails: it blocks
cr-rebind-head|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|### A Rebind Without Priced Literals = Important (minimum)|prefix
cr-rebind-trigger|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|**A re-target prices every literal keyed on it, under both bindings.**|para|while its text stays the same, where a literal or threshold downstream is computed from or compared against it
cr-rebind-every|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|**A re-target prices every literal keyed on it, under both bindings.**|para|every literal and threshold the re-bound value flows into
cr-rebind-unit|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|**A re-target prices every literal keyed on it, under both bindings.**|para|in the unit it is compared against
cr-rebind-untouched|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|**A re-target prices every literal keyed on it, under both bindings.**|para|A literal the diff does not touch is in scope for exactly that reason
cr-rebind-sev|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|An unpriced keyed literal is **Important** at minimum.|para|derives each input the price depends on, meaning the literal's own line and the decimals or units entry under each binding, using commands that name the source file as an operand
cr-smoke-head|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|### Missing or Mismatched Smoke Test Updates = Critical|prefix
cr-smoke-cite|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|If a story introduces, modifies, or removes user-facing functionality|para|`qa.md` "Smoke test updates (HARD GATE)"
cr-smoke-defer|R|code-reviewer.md|## Mandatory Severity Classifications|## Self-Discrimination Map|This is non-deferrable. The smoke spec|para|`qa.md`'s "Deferred-AC discharge predicate (HARD GATE)"
arch-rebind-trigger|R|architect.md|## The evidence contract|## A fold architecture dispatch|**A re-target is priced in a `derived` fence, input by input.**|para|while its text stays the same, where a literal or threshold downstream is computed from or compared against it
arch-rebind-fence|R|architect.md|## The evidence contract|## A fold architecture dispatch|**A re-target is priced in a `derived` fence, input by input.**|para|derives each input the price depends on, meaning the literal's own line and the decimals or units entry under each binding, using commands that name the source file as an operand
arch-rebind-unit|R|architect.md|## The evidence contract|## A fold architecture dispatch|**A re-target is priced in a `derived` fence, input by input.**|para|in the unit it is compared against
arch-rebind-oldnew|R|architect.md|## The evidence contract|## A fold architecture dispatch|**A re-target is priced in a `derived` fence, input by input.**|para|records `old -> new` for each
arch-rebind-untouched|R|architect.md|## The evidence contract|## A fold architecture dispatch|**A re-target is priced in a `derived` fence, input by input.**|para|A literal the diff does not touch is in scope for exactly that reason
qa-verdict-exclusive|R|qa.md|## Verdict|## As a Shard|The two forms are EXCLUSIVE.|contains
qa-verdict-union|R|qa.md|## Verdict|## As a Shard|A `## Verdict` heading followed by `Verdict: PASS` fails Check 1 in `gate-validation.md`, which reads the heading's next non-blank line and gets `Verdict:`, not a member.|contains
qa-carried-sentence|R|qa.md|## Carried Findings|## Validation Checklist|`PASS`. Gate 2 runs `validate-carried-findings.sh` on the two validation files|contains
qa-carried-line|R|qa.md|## Carried Findings|## Validation Checklist|with one column-0 line outside a fence, `carried: <that string, verbatim> —|contains
qa-lrdiv-lead|R|qa.md|## Validation Checklist|## Communication|- [ ] **An AC that omits a locked requirement's action is a deviation for the operator (HARD GATE).**|prefix
qa-lrdiv-never-pass|R|qa.md|## Validation Checklist|## Communication|An AC whose expected outcome omits an action the text requires is a requirement divergence, never a PASS.|contains
qa-lrdiv-empty|R|qa.md|## Validation Checklist|## Communication|A precondition under which the required action has nothing to act on (an empty balance, an empty set)|contains
qa-lrdiv-rework|R|qa.md|## Validation Checklist|## Communication|QA writes `Verdict: NEEDS_REWORK` with a `####` finding naming the HARD_BLOCK id; the lead puts it to the operator by `AskUserQuestion` under Rule 3(a), with no flag, before dispatching dev rework.|contains
qa-lrdiv-outcome|R|qa.md|## Validation Checklist|## Communication|If the operator accepts the degraded branch (`descope` of the omitted action), QA re-validates to PASS citing the entry; `do-now` proceeds as rework.|contains
qa-lrdiv-exempt|R|qa.md|## Validation Checklist|## Communication|value), (2) a Tier 1 `HARD_BLOCK` with blocker type `requirement divergence` that cites this LR and names this degraded branch already carries a recorded operator disposition (cite that entry), or|contains
qa-lrdiv-exempt3|R|qa.md|## Validation Checklist|## Communication|(3) the AC's outcome performs none of the requirement's actions and reports that to the caller as a non-success (a refusal or error status, a disabled control, a dry-run marker), unless the requirement's verbatim text forbids that refusal.|contains
qa-lrdiv-other-type|R|qa.md|## Validation Checklist|## Communication|An entry of another blocker type, or one that names no LR, does not exempt.|contains
qa-sweep-class|R|qa.md|## Class Sweep (HARD GATE)|## Verdict|sweeps for that class, and lists EVERY instance it found on an `Instances:` line|contains
qa-sweep-shard|R|qa.md|## As a Shard|## Escalation Protocol|the first cross shard sweeps the captures it runs and replays|contains
qa-sweep-template|R|qa.md|## Findings Template|## As a Shard|The `Instances:` line is the `## Class Sweep (HARD GATE)` result|contains
gv-smoke-surface-def|S|steps/gate-validation.md|### 11. Smoke test coverage|### 11a.|**Smoke surface.**|para|one git pathspec per line
qa-sweep-template-lines|R|qa.md|## Findings Template|## As a Shard|Instances: <every instance of this finding's defect class, or `none` for a Suggestion>|fenced
qa-sweep-template-lines2|R|qa.md|## Findings Template|## As a Shard|Instances: <every instance of this finding's defect class>|fenced
smoke-def-absent-qa|R|qa.md|||one git pathspec per line|absent
smoke-def-absent-stories|S|steps/stories-test-strategy.md|||one git pathspec per line|absent
impl-rework-instances|S|steps/implementation.md|### 6. Orchestrate|### 7. All Gates Passed|The dev rework brief carries each finding's `Instances:` list verbatim.|contains
dev-dar-before-submit|R|dev.md|## Workflow Per Task|## QA Handoff Evidence|Populate the Dev Agent Record in the story file|contains
impl-dar-copy|S|steps/implementation.md|### 6. Orchestrate|### 7. All Gates Passed|copy the Dev Agent Record the dev wrote on the story branch|contains
impl-dar-no-report|S|steps/implementation.md|||from the dev's completion report|absent
sts-smoke-cite|S|steps/stories-test-strategy.md|### Story-Authoring Pre-Flight Checklist|### Story-AC Out-of-Scope Declaration Rule|Its surface is `gate-validation.md` Check 11, **Smoke surface.**|contains
sts-hardgate-map|S|steps/stories-test-strategy.md|### 2b.|### 3. Sprint Planning|an unmapped triggered item blocks story authoring.|contains
dv-lrcov-interp-struck|S|steps/deploy-validate.md|### 5. Production Validation Checkpoint|### 6. Wait for Human|**Locked-requirement coverage.**|para|one struck or reworded is marked `descoped` quoting its `HARD_BLOCK` id and `descope` token
dv-lrcov-interp-unanswered|S|steps/deploy-validate.md|### 5. Production Validation Checkpoint|### 6. Wait for Human|**Locked-requirement coverage.**|para|one still unanswered at the checkpoint is a requirements-gate defect: report it and treat the bullet as deferred, owing its `HARD_BLOCK`.
dv-lrcov-degraded|S|steps/deploy-validate.md|### 5. Production Validation Checkpoint|### 6. Wait for Human|**Locked-requirement coverage.**|para|An operator's acceptance of a degraded branch on a Tier 1 `requirement divergence` `HARD_BLOCK` (`qa.md` Validation Checklist) is a `descope` of the omitted action alone, never `delivered`: the bullet is marked `descoped`, and its line names that action and quotes the `HARD_BLOCK`'s id and its `descope` token.
r11a-effects|S|SKILL.md|### Rule 11 |### Rule 12 |**Every option states its concrete effect, INCLUDING the value it leaves|para|INCLUDING the value it leaves in force
r11a-unbadged|S|SKILL.md|### Rule 11 |### Rule 12 |**Every option states its concrete effect, INCLUDING the value it leaves|para|none marked `(Recommended)` and none placed first as the pick
r11a-pointer|S|SKILL.md|### Rule 11 |### Rule 12 |**One shape for every operator decision|para|stated in full under Rule 12's four `#### Operator decisions` subsections; apply all four to every question you put to the operator
r11a-four-things|S|SKILL.md|### Rule 11 |### Rule 12 |**Before any question reaches the operator, do|para|four things to it
r11a-lanes-dispatch|S|SKILL.md|### Rule 11 |### Rule 12 |**Before any question reaches the operator, do|para|(4) Dispatch, then ask, as Rule 12's `#### Operator decisions: dispatch, then ask`.
r11a-dispatch-ask|S|SKILL.md|#### Operator decisions: dispatch, then ask|### Rule 13 |**Immediately before every `AskUserQuestion`, dispatch, then ask.**|exact|**Immediately before every `AskUserQuestion`, dispatch, then ask.** Join every lane whose completion has arrived: read the completion and record it. Acting on its output is itself a ready action, dispatched below, not work to finish before asking. Dispatch every ready action the question does not hold, in the background (Rule 29), and arm its join. An action is ready when its inputs exist now, and the question holds it only when it reads the answer. Name the lanes held in your output beside the question, not inside it. Then send the question at once, in `AskUserQuestion`, unchanged by the lane state. Never wait for a running lane before asking, and never hold back, defer or drop a question, or fold it into a later one, to suit the lanes.
r11a-one-shape|S|SKILL.md|### Rule 12 |### Rule 13 |**Every decision put to the operator has one shape|para|gives every option with its effect and the consequence of choosing it
r11a-say-why|S|SKILL.md|### Rule 12 |### Rule 13 |**Every decision put to the operator has one shape|para|says so in its own text, with the reason,
r11a-attested-act|S|SKILL.md|### Rule 12 |### Rule 13 |**An act the operator has attested is not raised again.**|para|no later step puts it back to the operator:
r11a-premise|S|SKILL.md|### Rule 12 |### Rule 13 |**An act the operator has attested is not raised again.**|para|shows the act did not occur is an authorization-premise invalidation
r11a-value-trigger|S|SKILL.md|### Rule 11 |### Rule 12 |**Every option states its concrete effect, INCLUDING the value it leaves|para|decides a value the operator alone owns and no operator words fix
r11a-sort-decide|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|record it as a Rule 12 Tier 2 `DECIDED_AUTONOMOUSLY` entry naming its source and a one-line reason, add one veto line for it to the next `AskUserQuestion` you send
r11a-sort-provided|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|leaves every operator-owned value in force or sets it to the operator's verbatim value or that value exactly converted between units
r11a-sort-decides-no-value|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|Such a choice decides no value, so Rule 11(a)'s UNBADGED trigger does not reach it.
r11a-sort-no-widen|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|A choice that otherwise sets, relaxes or widens a value, a limit or an authority is settled by no source
r11a-sort-badged|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|A design choice no source settles is asked with one option `(Recommended)`
r11a-sort-tree-no-value|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|The tree never settles a value
r11a-sort-outside|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|Outside this sort, each asked as its own rule says:
r11a-sort-where-how|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|for WHERE and HOW only
r11a-sort-lead-words|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|words a lead wrote into a `LOCKED_REQUIREMENTS` entry are no source for what they add
r11a-sort-scope-outside|S|SKILL.md|### Rule 12 |### Rule 13 |**Sort every question three ways before it is asked.**|para|the sprint-scope confirmation (`steps/route.md` Step 6)
sts-part-mark|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|<lead engine>/wait-for-deliverable.sh --mark <part path> stories-epic-<n> pm none findings=0
sts-part-nohand|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|never a hand-appended `seat-complete:` line
sts-part-remark|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|is marked again with the same `--mark` call before any `--complete` join reads it
sts-part-complete|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|the lead's join beat passes `--complete`
route-say-why|S|steps/route.md|### Step 6:|## FAILURE MODES|**Option labels carry no recommendation.**|para|Say in the question that its options carry no recommendation, and why.
gp-2c-locked-effects|S|steps/_gate-procedures.md|## Divergence resolution dispatch|## Adversarial repair dispatch|a. **One sentence naming the decision.**|para|State each option's effect on that entry instead, including the value it leaves in force
gp-2c-locked-nobadge|S|steps/_gate-procedures.md|## Divergence resolution dispatch|## Adversarial repair dispatch|a. **One sentence naming the decision.**|para|**mark NO option `(Recommended)`.**
retro-lr-partial|S|steps/retro.md|### 4a. Close-Out Sweep|### 4b. Operator-steerability audit|The undelivered clauses of a bullet the checkpoint marked `partial` are read here as deferred bullets are, each owing its own recorded disposition.|prefix|
retro-gar-confirm|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|is an `AskUserQuestion` to the operator naming the id
retro-gar-block|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|a retro HARD_BLOCKS here whenever this sprint's selection is empty and an unmatchable series' newest member records a FAIL, re-runs included
retro-gar-rerun|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**After the last `--series` move, re-run `--sprint s<N> --apply` above; the close is done only when it exits 0.**|para|the close is done only when it exits 0
retro-gar-survivor|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**After the last `--series` move, re-run `--sprint s<N> --apply` above; the close is done only when it exits 0.**|para|exits 1 when it would leave one of them as a FAILing live pass, and that refusal is a HARD_BLOCK like any other
retro-gar-legacy|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**A `--series` run may itself exit 1 and print a `--legacy-through` remedy.**|para|then re-run the `--series` line before re-running the close
retro-gar-close|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|where a sprint has none, it is the merge commit of that sprint's retro PR
retro-gar-utc|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|Read `TZ=UTC git log --date=format-local:%Y%m%dT%H%M%SZ --format='%ad %s'` for this repo's sprint-close commits
retro-7apost-own-entry|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|3. Archive the WHOLE live log verbatim|2. Confirm no further gate-log writes remain this sprint.|para|the retro gate's own entry included
retro-7apost-per-dispatch|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|3. Archive the WHOLE live log verbatim|2. Confirm no further gate-log writes remain this sprint.|para|appends it, one entry per dispatch
dp-git-c|S|steps/_dispatch-protocol.md|**Worktree-explicit dev dispatch.**|**Bounded-join dispatch mandate (Rule 29).**|0. Lead MUST commit all planning artifacts|para|`git -C <worktree absolute path> <cmd>`, or the dev `cd`s into the worktree on EVERY Bash call
dp-one-story|S|steps/_dispatch-protocol.md|**Worktree-explicit dev dispatch.**|**Bounded-join dispatch mandate (Rule 29).**|0. Lead MUST commit all planning artifacts|para|The dev works only the story it was dispatched for, one story per dispatch, and never claims another from a task list
dev-one-story|R|dev.md|## Responsibilities|## As a party seat|- Implement the story the lead dispatched you for|para|Implement the story the lead dispatched you for: one story per dispatch.
dev-hardblock-idle|R|dev.md|## Escalation Protocol|## CI-vs-local divergence diagnostic order|- **HARD_BLOCK** (story contradicts architecture|para|and go idle; you do not pick up another story.
coe-stem-token|S|steps/carry-over-evaluation.md|### 3a. Validation cycle (Rule 8)|### 4. Deferral Handling|- The series is|para|`<artifact>` in `_gate-procedures.md`'s review and repair dispatch paths is `coe`
coe-stem-dir|S|steps/carry-over-evaluation.md|### 3a. Validation cycle (Rule 8)|### 4. Deferral Handling|- The series is|para|s<N>/shards/coe-p<M>/
coe-26c-caught|S|steps/carry-over-evaluation.md|### 3a. Validation cycle (Rule 8)|### 4. Deferral Handling|Failure caught:|contains|
coe-26c-loop|S|steps/carry-over-evaluation.md|### 3a. Validation cycle (Rule 8)|### 4. Deferral Handling|- Adversarial passes 2 and later: Failure caught:|prefix|
gp-shard-sentinel|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|It writes findings to|para|`tool_use_id: NOT_ACCESSIBLE`
gp-shard-derived|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|It writes findings to|para|the merge derives each shard's dispatch id
gp-shard-rerun|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|**A re-dispatched shard is merged with `--rerun`.**|para|run the same merge with `--rerun <shard>.md@<the re-dispatch's dispatched-at>`
gp-shard-rerun-finding|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|**A re-dispatched shard is merged with `--rerun`.**|para|a refusal naming a writer of another shard is a finding, never a timestamp to move
gp-shard-rerun-doublewrite|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|**A re-dispatched shard is merged with `--rerun`.**|para|A `REFUSED: DOUBLE-WRITE <shard>.md:` refusal means no start exists, because a writer kept writing after another writer's first row: follow its remedy, and never search for a start.
gp-probe-ledger|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|**The probe ledger is load-bearing until the consumer's hook writes `transcript_path`.**|para|Do not rotate or truncate `subagent-context.jsonl` mid-round
gp-probe-ledger-rerun|S|steps/_gate-procedures.md|## Adversarial review dispatch (referenced by step files)|## Divergence resolution dispatch|**The probe ledger is load-bearing until the consumer's hook writes `transcript_path`.**|para|is re-run after the next dispatch writes the new keys, never hand-filled
adv-shard-sentinel|R|adversary.md|## Contract|## Severity|1. **Run the evaluation you were dispatched for, in your own context.**|para|**A shard writes `tool_use_id: NOT_ACCESSIBLE`, never an id it was told or guessed.**
gp-derive-file|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|Every re-run names a FILE and never the slot directory.|para|`validate-artifact-derivations.sh <the joined repair record>`
gp-join-serial|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Join** with the bounded-join beat (above): `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair|para|--complete-repair --dispatch <agentId> <repair_record_path>
gp-part-complete-files|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Shard by file (Rule 28, "Split dispatch": files axis).**|para|Beat-join every part with `scripts/ai-dlc/wait-for-deliverable.sh --complete --
gp-part-complete-doc|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1. **Split.** `scripts/ai-dlc/partition-document.sh --split|para|Beat-join every part with `scripts/ai-dlc/wait-for-deliverable.sh --complete --
gp-part-complete-subj|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1. **Split.** `scripts/ai-dlc/partition-subject.sh --split|para|Beat-join every part with `scripts/ai-dlc/wait-for-deliverable.sh --complete --
gp-part-mark|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Join** with the bounded-join beat (above): `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair|para|A part remediator closes its part with `--mark` instead, and each axis's join step above beat-joins those parts with `--complete`
gp-render-before-mark|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Join** with the bounded-join beat (above): `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair|para|line before its `--mark-repair`, so the render lies inside the dispatch this beat joins
gp-part-dispatch-one-files|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**Shard by file (Rule 28, "Split dispatch": files axis).**|para|<part path>...` (one `--dispatch` per agent the round joined)
gp-part-dispatch-one-doc|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1. **Split.** `scripts/ai-dlc/partition-document.sh --split|para|<part path>...` (one `--dispatch` per agent the round joined)
gp-part-dispatch-one-subj|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|1. **Split.** `scripts/ai-dlc/partition-subject.sh --split|para|<part path>...` (one `--dispatch` per agent the round joined)
gp-stop-repair-part|S|steps/_gate-procedures.md|## Auto-handoff evaluation (referenced by step files)|## Context reminder threshold check|1. **Stop all in-flight teammates first.**|para|for seat, shard, cross and repair-part files
ho-stop-repair-part|S|steps/handoff.md|Execute this 5-step procedure in order:|**Resume is snapshot-driven.**|1. **Stop all in-flight teammates first.**|para|for seat, shard, cross and repair-part files
rem-part-mark|R|remediator.md|## Contract|## The evidence contract|**Close your part with `--mark`.**|para|<lead engine>/wait-for-deliverable.sh --mark <part path> <step> remediator <shard> findings=<n>
rem-render-before-mark|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**As the serial remediator, or as the one unsharded remediator**|para|line BEFORE your `--mark-repair`, never after it
rem-serial-replay|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|The two lines after each triple you write say which checks this dispatch ran.|para|The serial or unsharded remediator replays before its join, which runs before `--mark-repair`, and writes `replayed <n>` itself.
gp-redispatch-fresh|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**A completed record is never reopened by `SendMessage`.**|para|`TaskStop` the resident remediator and send ONE fresh `Agent` dispatch
gp-redispatch-never|S|steps/_gate-procedures.md|## Adversarial repair dispatch|## Auto-handoff evaluation|**A completed record is never reopened by `SendMessage`.**|para|Never resume the finished remediator with `SendMessage`
r28-no-reopen|S|rule-bodies/rule-28.md||**A dispatched teammate reaches the lead with `SendMessage` `to: "main"`.**|- **Retracted or narrowed scope.**|para|re-dispatches it fresh
r28-epoch-outside-round|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**A rejected spawn is undelivered, and holding it is not a retry.**|**The round's epoch is written down before wave 1.**|para|A beat outside a fan-out round, on an agent this session dispatched, has no round epoch and passes `--dispatch` alone, which sets the join to the dispatch
r28-epoch-recorded|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**A rejected spawn is undelivered, and holding it is not a retry.**|**The round's epoch is written down before wave 1.**|para|The `<epoch>` is the one recorded before wave 1, never one minted at the beat.
r28-serial-join|S|rule-bodies/rule-28.md|**A notification the live beat already covers is not a turn's work.**|**The join names what is missing, never what it counted.**|**The serial remediator's join is armed on the record it appends to.**|para|`**Join**`, with `--complete-repair` and `--dispatch` alone
r28-rd-carveout|S|rule-bodies/rule-28.md||**Everything else is delegated.**|- **(a) Orchestration** --|para|may be delegated to ONE round-dispatcher; the round's epoch, its join program, the Rule 20 re-dispatch decision and the disposition stay with the lead.
r28-rd-scope-in|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|An adversarial-pass round (files, sections and subject axes, with its cross agent), an elicitation round, and a sharded party round (seats x parts, seats x sections, seats x subject-parts) may be run by ONE round-dispatcher.
r28-rd-party-skill|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|An unsharded party round runs on the Skill and is not dispatcher-run.
r28-rd-repair-out|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|A repair round is lead-dispatched, never run by a dispatcher
r28-rd-review-out|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|A code review or QA round is lead-dispatched, never run by a dispatcher
r28-rd-foreground|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|joins them with FOREGROUND `wait-for-deliverable.sh --complete
r28-rd-shard-header|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|wait-for-deliverable.sh --complete [--shard-header <axis>] --since <epoch> --dispatch <agentId> --dispatch <agentId> ...
r28-rd-dispatch-each|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|(one `--dispatch` per member; `--shard-header convergence` for a `shards/<artifact>-p<M>/` round, `elicitation` for a `-elicitation/` round, none for party seats), never `run_in_background`
r28-rd-beatsecs|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|each prefixed `AI_DLC_WAIT_BEAT_SECS=540`
r28-rd-timeout|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|each passing the Bash `timeout: 600000`
r28-rd-missing|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|A member path the beat reports as NON-DELIVERY is not re-dispatched by the dispatcher: it is written as `MISSING <path> <agentId> <kind>`, `<kind>` being the exhaustion kind the beat printed for that path (`absent`, `UNFINISHED`, `UNSETTLED` or `UNCHANGED`), and only `absent` is Rule 20 non-delivery
r28-rd-grammar|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|one line per member path, `DELIVERED|MISSING|FAILED|REJECTED|UNLAUNCHED <path> <agentId|->`
r28-rd-rejected|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|one `rejected: <description> cap=<N>` line per refusal it received
r28-rd-return-path|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|`_bmad-output/planning-artifacts/s<N>/rounds/<round>.return`, outside `shards/`
r28-rd-reset|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|is re-armed with `--reset` only while the dispatcher is live
r28-rd-stalled|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**The round's epoch is written down before wave 1.**|**A wide round is run by a round-dispatcher.**|para|A dispatcher silent past that threshold with no return file is STALLED: the lead reads its last message, runs the round's join program over the member files that exist and treats expected minus delivered as Rule 20 non-delivery
r28-rd-return-dispatch|S|rule-bodies/rule-28.md|**Waves: the harness caps concurrent subagents.**|**A rejected spawn is undelivered, and holding it is not a retry.**|**The round's epoch is written down before wave 1.**|para|The lead's beat over a round-return file is exempt on every arm, a re-arm after a compaction included: it passes `--since <epoch>` alone
r28-rd-covered|S|rule-bodies/rule-28.md|**A wave that launched nothing still owes a beat.**|**The serial remediator's join is armed on the record it appends to.**|**A notification the live beat already covers is not a turn's work.**|para|While the lead's beat over a round-return file is live, every notification for that round's dispatcher, and for a member exiting after the return, is covered
r28-rd-covered-failed|S|rule-bodies/rule-28.md|**A wave that launched nothing still owes a beat.**|**The serial remediator's join is armed on the record it appends to.**|**A notification the live beat already covers is not a turn's work.**|para|a dispatcher notification whose status is failed is not covered
dp-rd-head|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|**Round-dispatcher brief.**|prefix
dp-rd-briefs|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|**Round-dispatcher brief.**|para|to `_bmad-output/planning-artifacts/s<N>/rounds/<round>/<i>.brief`, and the dispatcher brief LISTS every brief path and states their count
dp-rd-noglob|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|**Round-dispatcher brief.**|para|the dispatcher never globs that directory
dp-rd-noname|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|**Round-dispatcher brief.**|para|The dispatcher is spawned with no `name` and no `subagent_type`
dp-rd-tpl-noname|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|You are a round-dispatcher.|para|`run_in_background: true`, no `name`, the member's role as `subagent_type`
dp-rd-tpl-foreground|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|You are a round-dispatcher.|para|Join them with FOREGROUND Bash calls, each `timeout: 600000`, never `run_in_background`
dp-rd-tpl-shard-header|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|You are a round-dispatcher.|para|wait-for-deliverable.sh --complete [--shard-header <axis>] --since <epoch> --dispatch <agentId> --dispatch <agentId> ...
dp-rd-tpl-dispatch-each|S|steps/_dispatch-protocol.md|**Dispatch-prompt cache discipline.**|**Dev-brief bug-class checklist.**|You are a round-dispatcher.|para|(one `--dispatch` per member)
impl-cross-statedir|S|steps/implementation.md|### 6. Orchestrate|### 7.|**Gate-2 dispatch: the validation partitions by changed-file group too.**|para|a beat state directory of its own, given as an absolute path outside the shard directory, and never the lead's.
adv-ls-files|R|adversary.md|## Constraints|## Escalation|- **List a code path your brief does not cite before you open it.**|para|list it with `git ls-files <dir-or-glob>` and read only what that returns.
adv-grep-error|R|adversary.md|## Constraints|## Escalation|- **A search that errors found nothing, and nothing is not an absence.**|para|searched nothing, so its silence is not an absence
elic-header-region|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|The brief carries the shard header as the generated `provenance-block/elicitation` region below: copy this region verbatim
elic-header-strip|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|The shard copies the region verbatim and then deletes each line's trailing ` #` comment (the space, the `#` and everything after it), because the merge reads every value literally.
adv-header-strip|R|adversary.md|## The verdict|## |**A shard copies the region above verbatim and then deletes each line's trailing ` #` comment**|para|(the space, the `#` and everything after it), because the merge reads every value literally.
arch-lint-invoke|S|steps/architecture.md|### 2. Architecture Creation or Update|### 3.|`bmad-architecture` ships `scripts/lint_spine.py`|para|lint_spine.py --workspace <the run folder holding ARCHITECTURE-SPINE.md> -o <lint json>
arch-chain-join|S|steps/architecture.md|### 2. Architecture Creation or Update|### 3.|**Sections 2 and 3 run as ONE dispatched `architect` chain**|para|Join it with `scripts/ai-dlc/wait-for-deliverable.sh --complete --dispatch <agentId> _bmad-output/planning-artifacts/s<N>/architecture-chain.md`
arch-chain-marker-last|S|steps/architecture.md|### 2. Architecture Creation or Update|### 3.|**Sections 2 and 3 run as ONE dispatched `architect` chain**|para|only after the LAST file of the chain is written makes one final write, the ONE Bash call `<lead engine>/wait-for-deliverable.sh --mark <record> architecture architect none findings=0`
arch-role-chain-mark|R|architect.md|## As the architecture authoring chain|## |close the record with ONE Bash call, your final write, run from `<lead engine>` as defined in the section above:|contains
arch-chain-rearm-growth|S|steps/architecture.md|### 2. Architecture Creation or Update|### 3.|**Sections 2 and 3 run as ONE dispatched `architect` chain**|para|The record is growing when it has a new start or finish line since the previous beat
hand-architect-role|R|architect.md||## Escalation Protocol|## Architect handoff|contains
hand-architect-step|S|steps/architecture.md||### 5.|## Architect handoff|contains
hand-gaps-role|R|analyst.md||## Escalation|## Gaps|contains
hand-gaps-rule24|S|rule-bodies/rule-24.md||**Excluded.**|## Gaps|contains
hand-design-role|R|ux.md||## Escalation|## Design decisions|contains
hand-design-step|S|steps/ui-direction.md||### 5.|## Design decisions|contains
r32-i-window|S|SKILL.md|- **I -- before an irreversible step.**|Weigh what it returns.|the window of `ai-dlc-advisor-gate.sh` (`ADVISOR_GATE_WINDOW`|contains
r19-c22-impl|S|rule-bodies/rule-19.md||**Config is authoritative.**|**(a) Model.**|para|Check 22 records at the implementation gate.
r19-no-retro|S|rule-bodies/rule-19.md|||at retro|absent
pred-lit-qa|R|qa.md|## Validation Checklist|## Communication|A literal this repository writes nowhere at that sha is REJECT, unless the|contains
pred-lit-qa-fence|R|qa.md|## Validation Checklist|## Communication|`git grep -n -F '<literal>' <sha> -- <producing file>`, whose recorded|contains
pred-lit-pm|R|pm.md|## Responsibilities|## The evidence contract|so the predicate names the AC of this story that requires the literal, and|contains
pred-lit-pm-gate|R|pm.md|## Responsibilities|## The evidence contract|is owed at gate 2|contains
pred-lit-arch|R|architect.md|## The evidence contract|## A fold architecture dispatch|**An ADR probe keyed on a literal this repository writes cites its producer.**|para|carries a `derived` fence pinned to a sha, `git grep -n -F '<literal>' <sha> -- <producing file>`, whose recorded output is the producing line, or names the literal's external source
def-copy-cr-section|R|code-reviewer.md|## Ownership|## Responsibilities|At `done` the closing writer also writes a `## Deferred ACs` section into the story file.|contains
def-copy-cr-id|R|code-reviewer.md|## Ownership|## Responsibilities|Each entry opens with `- **<id>**`, the IDENTICAL string written to `deferred_acs`,|contains
def-copy-cr-pred|R|code-reviewer.md|## Ownership|## Responsibilities|and carries that AC's predicate text copied from the verdict file the gate-2 check read|contains
def-copy-cr-none|R|code-reviewer.md|## Ownership|## Responsibilities|A story with no deferred AC gets the section with body `None.`.|contains
def-copy-cr-place|R|code-reviewer.md|## Ownership|## Responsibilities|The section sits directly BEFORE `## Dev Agent Record`;|contains
def-copy-qa|R|qa.md|## Validation Checklist|## Communication|copies each id with its predicate text into the story file's `## Deferred ACs`,|contains
def-copy-dv-read|S|steps/deploy-validate.md|### 4b.|### 5.|**Read each owed predicate from the story file.**|para|predicate from the story file's `## Deferred ACs` section
def-copy-dv-absent|S|steps/deploy-validate.md|### 4b.|### 5.|**A story file with no `## Deferred ACs` section is a pre-migration story.**|para|Fall back to the QA verdict for its predicate and record the fallback under `deferred_ac_discharge`.
def-copy-dv-missing|S|steps/deploy-validate.md|### 4b.|### 5.|**A missing entry is a closing-writer defect.**|para|an owed id has no entry opening with that exact id, or the body is `None.` beside a non-empty `deferred_acs`
def-copy-dv-missing-run|S|steps/deploy-validate.md|### 4b.|### 5.|**A missing entry is a closing-writer defect.**|para|report it in the gate log as a closing-writer defect, then run the predicate from the QA verdict.
def-copy-dv-sha|S|steps/deploy-validate.md|### 4b.|### 5.|**Check every literal against the deployed sha before running the predicate.**|para|Check each literal the predicate names against the DEPLOYED sha
def-copy-dv-refence|S|steps/deploy-validate.md|### 4b.|### 5.|**Check every literal against the deployed sha before running the predicate.**|para|a pinned fence whose sha is not the deployed sha is re-run at the deployed sha first.
def-copy-dv-oldnew|S|steps/deploy-validate.md|### 4b.|### 5.|**Check every literal against the deployed sha before running the predicate.**|para|record the correction under `deferred_ac_discharge` as `old -> new`
def-copy-dv-silent|S|steps/deploy-validate.md|### 4b.|### 5.|**Check every literal against the deployed sha before running the predicate.**|para|Never a silent substitution.
ff-specs-brief|S|steps/deploy-validate.md|### 4. Visual Verification|### 4b.|If `is_ui_epic == true`:|para|names the browser spec files covering the drifted surface
ff-specs-record|S|steps/deploy-validate.md|### 4. Visual Verification|### 4b.|If `is_ui_epic == true`:|para|records either their run (invocation, pass/fail counts) or why they could not run
ff-specs-lead|S|steps/deploy-validate.md|### 4. Visual Verification|### 4b.|If `is_ui_epic == true`:|para|When they could not run, the lead runs them against the redeployed instance before re-verifying
ff-specs-evidence|S|steps/deploy-validate.md|### 4. Visual Verification|### 4b.|If `is_ui_epic == true`:|para|as the `playwright` evidence this section already names. A could-not-run record is not a pass.
arch-ready-intent|S|steps/architecture.md|### 3. Solutioning Gate|### 4.|Invoke `/bmad-sprint-planning intent=readiness`|contains
arch-ready-nostatus|S|steps/architecture.md|### 3. Solutioning Gate|### 4.|and do not create or modify sprint-status.yaml.|contains
sts-ready-intent|S|steps/stories-test-strategy.md|### 1. Implementation Readiness|### Story Routing Tags|Invoke `/bmad-sprint-planning intent=readiness`|contains
sts-ready-nostatus|S|steps/stories-test-strategy.md|### 1. Implementation Readiness|### Story Routing Tags|and do not create or modify sprint-status.yaml.|contains
sts-plan-intent|S|steps/stories-test-strategy.md|### 3. Sprint Planning|### 3a.|Invoke `/bmad-sprint-planning intent=sprint-planning`|contains
sts-lac-dbl-names|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A test double is named with what it changes.**|para|names the double and every request field it rewrites, drops or defaults relative to the request the code sends.
sts-lac-dbl-liveops|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A test double is named with what it changes.**|para|the story carries one `live_ops` AC that observes, read-only, the real system's handling of exactly those fields; the AC's own layer does not change.
sts-lac-dbl-deferred|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A test double is named with what it changes.**|para|is listed in the story's `deferred_acs` at gate 3 with a `deploy-pending` predicate unless gate 3 recorded the real system's response to it, so `deploy-validate.md` §4b owes its discharge.
sts-lac-dbl-writer|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A test double is named with what it changes.**|para|The closing writer copies the ids into `deferred_acs` (`qa.md` Deferred-AC discharge predicate), and `sprint-status.sh` reports each one still owed to §4b.
sts-lac-net-kinds|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A new chain or external network gets one read-only simulation per request kind.**|para|carries one `live_ops` AC per request kind, enumerated from the code paths that send them.
sts-lac-net-sim|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A new chain or external network gets one read-only simulation per request kind.**|para|Each such AC is a read-only simulation of that exact request against the real target, one that changes nothing, recorded with its response, and it names its precondition on the target
sts-lac-net-defer|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A new chain or external network gets one read-only simulation per request kind.**|para|is listed in `deferred_acs` with the simulation as its predicate and discharged at `deploy-validate.md` §4b once the precondition holds.
sts-lac-net-codefer|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A new chain or external network gets one read-only simulation per request kind.**|para|carries `defers_to: CO-S<N>-<descriptor>` on its own line inside that AC.
sts-lac-net-order|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**A new chain or external network gets one read-only simulation per request kind.**|para|The simulation of a request kind runs and its response is recorded before the first real request of that kind reaches the target, including a request an operator action the lead enables would send; a kind whose precondition is unmet stays disabled on that target until its simulation is recorded.
sts-lac-mm-caught|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**Minimum mechanism (Rule 26(c)).**|para|Failure caught: an AC passed against a test double that dropped a request field the real external system rejects
sts-lac-mm-fp|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**Minimum mechanism (Rule 26(c)).**|para|False-positive cost: one `live_ops` AC per named double and one per request kind
sts-lac-mm-removal|S|steps/stories-test-strategy.md|### Layered AC Verification Accounting|**Intensity gate|**Minimum mechanism (Rule 26(c)).**|para|Removal condition: retire once the gate-3 adjudicator diffs every double's request
bug-plan-intent|S|steps/bug-investigation.md|### 5. Sprint Setup|### 6.|Run `/bmad-sprint-planning intent=sprint-planning`|contains
bug-2c-lens|S|steps/bug-investigation.md|### 2c.|### 3.|Rule 19) to run `/bmad-review lenses=adversarial` on|prefix
bug-4-lens-adv|S|steps/bug-investigation.md|### 4. Validation|### 5. Sprint Setup|per SKILL.md Rule 19) to run `/bmad-review lenses=adversarial` on the fix story|prefix
bug-4-lens-arch|S|steps/bug-investigation.md|### 4. Validation|### 5. Sprint Setup|1. Runs `/bmad-review lenses=adversarial` on the fix story, scoped to|prefix
srev-lens|S|steps/sprint-review.md|### 1. Sprint-Level Adversarial Review|### 2. Sprint-Level Party Mode|`/bmad-review lenses=adversarial` — final adversarial pass on the|prefix
arch-role-fold-lens|R|architect.md|## A fold architecture dispatch|## As a party seat|1. **Run `/bmad-review lenses=adversarial` yourself, via the Skill tool**|prefix
rr-recon-domain|S|steps/research-requirements.md|### 1. Research|### 2. PRD Creation|1. `/bmad-deep-recon type=domain intent=run|prefix
rr-recon-market|S|steps/research-requirements.md|### 1. Research|### 2. PRD Creation|2. `/bmad-deep-recon type=market intent=run|prefix
rr-recon-technical|S|steps/research-requirements.md|### 1. Research|### 2. PRD Creation|3. `/bmad-deep-recon type=technical intent=run|prefix
req-recon-dommkt|S|steps/requirements.md|### 4. Authoring Dispatch|### 5.|**Research runs.** `/bmad-deep-recon type=domain`, `/bmad-deep-recon type=market` and|prefix
req-recon-technical|S|steps/requirements.md|### 4. Authoring Dispatch|### 5.|`/bmad-deep-recon type=technical`, each with `intent=run|prefix
gv9-header-check8|S|steps/gate-validation.md|## Gate-type manifest|**Universal core|**Deployment / schema / UI applicability is NOT a separate type.**|para|"deployment not claimed" is Check 8's scope clause alone, never Check 9's.
gv9-absent-flag|S|steps/gate-validation.md|### 9.|### 10.|**Check 9 skips at every gate when `is_ui_epic == false`.**|para|An absent flag is not a skip.
gv9-perstory-nourl|S|steps/gate-validation.md|### 9.|### 10.|**At every `implementation` gate, Check 9 is decided per story by the UI-path rule.**|para|No `implementation` gate fetches a production URL.
gv9-perstory-nofail|S|steps/gate-validation.md|### 9.|### 10.|**At every `implementation` gate, Check 9 is decided per story by the UI-path rule.**|para|the absence of a deployment is never a Check 9 FAIL at an `implementation` gate.
gv9-perstory-rereview|S|steps/gate-validation.md|### 9.|### 10.|**At every `implementation` gate, Check 9 is decided per story by the UI-path rule.**|para|is the prior reviewed sha and is never the range
gv9-perstory-pass1base|S|steps/gate-validation.md|### 9.|### 10.|**At every `implementation` gate, Check 9 is decided per story by the UI-path rule.**|para|`<base>` is the PASS-1 gate-1 partition manifest's `base`, the parent of the dev's first commit
gv9-union-skip|S|steps/gate-validation.md|### 9.|### 10.|**A gate over several stories, or over none, decides on the UNION of the gate|para|If that union touches no UI path, the whole gate self-skips (PASS).
gv9-union-whole|S|steps/gate-validation.md|### 9.|### 10.|**A gate over several stories, or over none, decides on the UNION of the gate|para|Otherwise the UI branch applies to the whole gate.
gv9-union-binds|S|steps/gate-validation.md|### 9.|### 10.|**A gate over several stories, or over none, decides on the UNION of the gate|para|Over-inclusion is the accepted failure mode and it binds
gv9-union-overinc|S|steps/gate-validation.md|### 9.|### 10.|**A gate over several stories, or over none, decides on the UNION of the gate|para|takes the UI branch with it
gv9-uipath-all|S|steps/gate-validation.md|### 9.|### 10.|**The UI path is defined here, inline, as `validate-mandatory-rules.sh` Check 5 defines it.**|para|The test-only exemption needs ALL changed web files to be tests
gv9-uipath-control|S|steps/gate-validation.md|### 9.|### 10.|**The UI path is defined here, inline, as `validate-mandatory-rules.sh` Check 5 defines it.**|para|a pathspec that returned at least one path.
gv9-uipath-toplevel|S|steps/gate-validation.md|### 9.|### 10.|**The UI path is defined here, inline, as `validate-mandatory-rules.sh` Check 5 defines it.**|para|The UI-path command and its pathspec control both run from the worktree top
gv9-skip-control|S|steps/gate-validation.md|### 9.|### 10.|**No UI path in the decided diff is a self-skip, which is a PASS.**|para|the pathspec control that returned non-zero.
gv9-skip-nocontrol|S|steps/gate-validation.md|### 9.|### 10.|**No UI path in the decided diff is a self-skip, which is a PASS.**|para|An empty UI diff without a non-zero control beside it is not a self-skip.
gv9-ui-compare|S|steps/gate-validation.md|### 9.|### 10.|**A UI path in the decided diff makes the source-vs-mockup comparison MANDATORY at that gate.**|para|on copy, element structure, attributes (including `role` and `aria-*`) and class names.
gv9-ui-failbar|S|steps/gate-validation.md|### 9.|### 10.|**A UI path in the decided diff makes the source-vs-mockup comparison MANDATORY at that gate.**|para|The gate FAILS if that comparison was not performed, or if drift was found and not fixed.
gv9-owed-notpass|S|steps/gate-validation.md|### 9.|### 10.|**Only layout and production rendering are OWED to `deploy-validate.md` §4 ("Visual Verification").**|para|An OWED record is never itself a PASS
req-lr-own-bullet|S|steps/requirements.md|### 3. Locked Requirements|### 4.|**A clause the lead adds is its own labelled bullet.** A clause no source above states|prefix
req-lr-after-id|S|steps/requirements.md|### 3. Locked Requirements|### 4.|with its own next unused whole-number id and the label right after the id:|prefix
req-lr-form|S|steps/requirements.md|### 3. Locked Requirements|### 4.|`- LR-S<N>-<m> (lead interpretation, of LR-S<N>-<k>): <clause>`, where `LR-S<N>-<k>` is the bullet it interprets.|prefix
req-lr-whole-number|S|steps/requirements.md|### 3. Locked Requirements|### 4.|The id is a whole number, never a letter or dotted suffix:|prefix
req-lr-not-labelled|S|steps/requirements.md|### 3. Locked Requirements|### 4.|NOT labelled: operator text; a gloss restating an operator answer that it cites by `file:line`;|prefix
req-lr-gloss-body|S|steps/requirements.md|### 3. Locked Requirements|### 4.|The cited operator answer is the record's fenced answer body only: words that appear only on its `- Question` line are the lead's own, and a clause carrying them is labelled.|prefix
req-lr-position|S|steps/requirements.md|### 3. Locked Requirements|### 4.|**The position is fixed by the parsers.** `validate-request-coverage.sh` and `validate-spec-join.sh` count a bullet only when its id opens it,|prefix
req-lr-drop|S|steps/requirements.md|### 3. Locked Requirements|### 4.|so a label before the id (`- (lead interpretation) LR-S<N>-<m> ...`) silently drops the bullet from both.|prefix
req-lr-3b|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Check 3b (`validate-locked-anchor.sh`) byte-matches each `full_text_source:` bullet against this slot, so the label reaches every story|prefix
req-lr-carrier|S|steps/requirements.md|### 3. Locked Requirements|### 4.|and that is how dev and QA learn the clause is the lead's, not the operator's.|prefix
req-lr-26c-caught|S|steps/requirements.md|### 3. Locked Requirements|### 4.|**Minimum mechanism (Rule 26(c)).** Failure caught: a clause the lead wrote into a locked bullet|prefix
req-lr-26c-fp|S|steps/requirements.md|### 3. Locked Requirements|### 4.|False-positive cost: one extra bullet and id per lead-added clause;|prefix
req-lr-26c-removal|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Removal condition: retire when each locked bullet's author is recorded by a mechanism|prefix
req-lr-template|S|steps/requirements.md|### 3. Locked Requirements|### 4.|- LR-S<N>-<m> (lead interpretation, of LR-S<N>-<k>): [a clause the lead added that no source states]|fenced
req-lr-ask-lead|S|steps/requirements.md|### 3. Locked Requirements|### 4.|**Every lead-interpretation bullet is put to the operator before the gate.** Once the block is written, and before section 4,|prefix
req-lr-ask-one|S|steps/requirements.md|### 3. Locked Requirements|### 4.|ask one `AskUserQuestion` question per `(lead interpretation)` bullet, its text opening `LR-S<N>-<m> (lead interpretation): `|prefix
req-lr-ask-badge|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Per Rule 11(a) the lead badges `Confirm LR-S<N>-<m>` `(Recommended)` when it believes the clause is the operator's intent; otherwise it badges nothing and the question says why.|prefix
req-lr-ask-hook|S|steps/requirements.md|### 3. Locked Requirements|### 4.|`ai-dlc-answer-capture.sh` records each answer in `_bmad-output/operator-answers-history.md`|prefix
req-lr-ask-oneid|S|steps/requirements.md|### 3. Locked Requirements|### 4.|The question names no other LR id: a question naming two ids answers neither, and a question naming only the parent|prefix
req-lr-derive|S|steps/requirements.md|### 3. Locked Requirements|### 4.|This derives each bullet's state from the newest record whose question opens with its exact id and names no other:|prefix
req-lr-derive-prog|S|steps/requirements.md|### 3. Locked Requirements|### 4.|awk -v id='LR-S<N>-<m>' 'BEGIN { q = "- Question (lead-authored, NOT covered by the hash): " id " (lead interpretation): "|fenced
req-lr-derive-ownid|S|steps/requirements.md|### 3. Locked Requirements|### 4.|index($0, q) == 1 { t = $0 " "; gsub(id "[^0-9]", " ", t); if (t !~ /LR-S[0-9]+-[0-9]+/) { f = 1; next } }|fenced
req-lr-derive-badge|S|steps/requirements.md|### 3. Locked Requirements|### 4.|c = b; sub(/ [(]Recommended[)]$/, "", c); v = (c == "Confirm " id) ? "CONFIRMED" : (c == "Strike " id |fenced
req-lr-derive-body|S|steps/requirements.md|### 3. Locked Requirements|### 4.|f == 2 { b = b s $0; s = "\n"; next }|fenced
req-lr-unanswered|S|steps/requirements.md|### 3. Locked Requirements|### 4.|`UNANSWERED` is a Rule 12 `HARD_BLOCK` before the requirements gate, through section 4(b)'s open-question channel.|prefix
req-lr-decision-line|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Every lead-interpretation `HARD_BLOCK` entry, whether filed paused on `UNANSWERED` or `UNDECIDED`, filed `RESOLVED` at the first ask, or resolved later, writes on its `Decision/Question:` line the bullet's id and label in the exact form `LR-S<N>-<m> (lead interpretation)`|prefix
req-lr-decision-paused|S|steps/requirements.md|### 3. Locked Requirements|### 4.|While the entry is paused on `UNANSWERED` or `UNDECIDED`, that is the decision asked: `**Decision/Question:** LR-S<N>-<m> (lead interpretation) -- awaiting operator: Confirm, Strike or Reword "<the clause>"`.|prefix
req-lr-decision-resolved|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Once it is resolved, that is the disposition, `confirm` or `descope`, and the captured answer's `file:line`: `**Decision/Question:** LR-S<N>-<m> (lead interpretation) -- confirm, <answer file:line>`|prefix
req-lr-decision-descope|S|steps/requirements.md|### 3. Locked Requirements|### 4.|or `**Decision/Question:** LR-S<N>-<m> (lead interpretation) -- descope, <answer file:line>`.|contains
req-lr-decision-scope|S|steps/requirements.md|### 3. Locked Requirements|### 4.|the file's "append, do not overwrite" rule governs entries, not a field of one.|contains
req-lr-decision-inplace|S|steps/requirements.md|### 3. Locked Requirements|### 4.|On resolution the lead rewrites that line in place, in the same edit that flips `**Status:**` to `RESOLVED`|prefix
req-lr-absent|S|steps/requirements.md|### 3. Locked Requirements|### 4.|An absent `_bmad-output/operator-answers-history.md` makes the program print nothing and exit 2, and the lead reads that as `UNANSWERED`.|prefix
req-lr-confirmed|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Only `CONFIRMED`, which a whole answer body of exactly `Confirm LR-S<N>-<m>` prints, with or without its ` (Recommended)` badge, keeps the bullet in force; `DESCOPE`, which a whole body of exactly `Strike LR-S<N>-<m>` or `Reword LR-S<N>-<m>` prints, badged the same way, takes the `descope` path.|prefix
req-lr-undecided|S|steps/requirements.md|### 3. Locked Requirements|### 4.|`UNDECIDED`, which any other body prints (free text, or an option followed by more text), is treated as `UNANSWERED`: a paused Rule 12 `HARD_BLOCK`, the lead puts the question again, and the free text is never filed as a disposition.|prefix
req-lr-uncaptured|S|steps/requirements.md|### 3. Locked Requirements|### 4.|A reply typed outside `AskUserQuestion` is not captured, so the lead asks again by `AskUserQuestion` to obtain the decision.|prefix
req-lr-later-answer|S|steps/requirements.md|### 3. Locked Requirements|### 4.|A bullet that read `UNANSWERED` and is answered later already has its `HARD_BLOCK` filed and the pipeline paused: on `CONFIRMED` the lead marks that entry `RESOLVED`, its `Operator authorization:` line quoting the captured answer body|prefix
req-lr-descope|S|steps/requirements.md|### 3. Locked Requirements|### 4.|**The `descope` path.** The lead records the answer as the operator's `descope` disposition on that bullet's `HARD_BLOCK` entry, status `RESOLVED`, its `Operator authorization:` line quoting the captured answer body under that record's `## ` timestamp|prefix
req-lr-descope-first|S|steps/requirements.md|### 3. Locked Requirements|### 4.|When the operator's captured answer at a bullet's first ask is an exact `Strike` or `Reword` option, the bullet never read `UNANSWERED` and has no `HARD_BLOCK` yet: the lead files its Tier 1 `HARD_BLOCK` in `docs/escalations/pending.md` already `RESOLVED`|prefix
req-lr-descope-nostory|S|steps/requirements.md|### 3. Locked Requirements|### 4.|No requirement, story or acceptance criterion is authored from a bullet on that path, and at the checkpoint it is marked `descoped`|prefix
req-lr-descope-next|S|steps/requirements.md|### 3. Locked Requirements|### 4.|In the next sprint's block a struck bullet takes `<!-- NOT-IN-SCOPE: <id> — struck by the operator, <answer file:line> -->`|prefix
req-lr-descope-noslot|S|steps/requirements.md|### 3. Locked Requirements|### 4.|No slot is edited, and no bullet is copied into a later slot.|prefix
req-lr-ask-26c-caught|S|steps/requirements.md|### 3. Locked Requirements|### 4.|**Minimum mechanism (Rule 26(c)).** Failure caught: one question about one clause of a locked bullet was read as ratifying the whole bullet|prefix
req-lr-ask-26c-ruling|S|steps/requirements.md|### 3. Locked Requirements|### 4.|The stop blocks by operator ruling: a question asked while the build proceeds is answered after the clause is already built.|prefix
req-lr-ask-26c-fp|S|steps/requirements.md|### 3. Locked Requirements|### 4.|False-positive cost: one operator stop per sprint that has a lead clause, one question per labelled bullet|prefix
req-lr-ask-26c-removal|S|steps/requirements.md|### 3. Locked Requirements|### 4.|Removal condition: retire when a mechanism records each bullet's author and the operator's confirmation and the gate reads it|prefix
req-oq-lead-interp|S|steps/requirements.md|### 4. Authoring Dispatch|### 5.|- A section 3 `(lead interpretation)` bullet that is unanswered is escalated the same way, as a Rule 12 `HARD_BLOCK` before the gate|prefix
gv9-retro-adopt|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|The adjudicator is read-only and never fetches a production URL
gv9-retro-fyi|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|A drift recorded as FYI is drift not fixed.
gv9-retro-fixed|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|the operator accepted that deviation in an escalation whose id the evidence cites
gv9-retro-suppressed|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|a `SUPPRESSED` waiver that meets the waiver rule below
gv9-retro-nonote|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|A lead's or seat's own note is never acceptance, and an escalation the evidence does not cite accepts nothing.
gv9-retro-nomarkup|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|a surface whose mockup section states it adds no markup and no CSS is compared on its source alone
gv9-retro-floor|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|Check 5's tokens are a floor, not the verdict
cli-content-arm|S|steps/gate-validation.md|### Core-layer immutability|### 26.|Exit 0 = no core path edited in place|para|every touched core path's mode and blob equal those of an `/ai-dlc-update` reconcile commit
gv9-retro-failbar|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|The gate FAILS if §4 recorded no evidence, if the mockup comparison was not performed, or if drift was found and not fixed.
gv9-retro-thissprint|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|An escalation is cited only when its id appears in this sprint's `## Gate Log: Sprint <N>` section
gv9-retro-citednowhere|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|and an id cited nowhere accepts nothing.
gv9-retro-livearchive|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|or in `_bmad-output/implementation-artifacts/s<N>/gate-log-archive.md`
gv9-retro-composed|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|both paths composed from N and not searched
gv9-retro-othersprint|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|An id that appears only under another sprint's header or in another sprint's `s<M>/` archive is not cited
gv9-retro-archive|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|is read from `docs/escalations/pending.md` or `docs/escalations/pending-archive.md`
gv9-retro-supcite|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|That entry alone is verified, `RESOLVED` and `SUPPRESSED` alike, by `validate-steering-budget.sh --dir
gv9-retro-captured|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|--authorized-at <that line's timestamp> --accept-captured`
gv9-retro-matchrc|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|It verifies only on exit 0 with a `MATCH <ts>` line on stdout.
gv9-retro-pruned|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|captured in `_bmad-output/operator-answers-history.md` within the citation's window
gv9-retro-dateonly|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|without a time of day, hours and minutes, does not verify.
gv9-retro-onlyhere|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|`--accept-captured` is passed only here
gv9-retro-nowhereelse|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|`NOMATCH-TRANSCRIPT-PRUNED` acquits nothing anywhere else.
gv9-retro-names|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|The cited entry names that surface and that deviation
gv9-retro-supcheck|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|counts only if it also carries `**Suppresses:** [core] 9 — `
gv9-retro-supts|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|timestamp is at or after the `Timestamp:` of the `## Gate Log: Sprint <N>` section that first records that deviation
gv9-retro-mergecommit|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|as of the sprint's merge commit to main
gv9-retro-amendsha|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|A mockup amendment made after that merge counts only in a commit whose message cites a `RESOLVED` escalation id that itself meets every acceptance rule here
gv9-retro-markupdev|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|a markup or CSS line that surface's diff adds is a deviation from that statement
gv9-retro-readarchive|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|sections wherever the citation rule below reads them, live or archived
gv9-retro-mockupmerged|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|against the mockup named below (as of the sprint's merge commit)
gv9-retro-headersn|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|its header names `S<N>`, this sprint, so a prior sprint's escalation accepts nothing
gv9-retro-wholeanswer|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|the quote, normalised, equals a whole answer
gv9-retro-archivenames|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|and its ordinal forms `s<N>/gate-log-archive-2.md`, `s<N>/gate-log-archive-3.md` and onward
gv9-retro-resolvedfloor|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|Any cited entry, `RESOLVED` or `SUPPRESSED`, counts only if its
gv9-retro-mergederive|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|whose tree equals `PR_HEAD`'s tree (a squash), or the merge commit whose second parent is `PR_HEAD`
gv9-retro-authsource|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|line alone, never from its `**Resolution:**` or `**Context:**` text and never from `_bmad-output/operator-answers-history.md`
gv9-retro-slotquote|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|is not the quote and is never verified in its place, so a line whose slot quote is lead-written fails
gv9-retro-everyline|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|line on the cited entry must verify, each by its own slot quote and its own timestamp, and the timestamp floor below is taken against the earliest of their timestamps
gv9-retro-bodyfloor|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|the floor is the latest ISO-8601 timestamp in that section's body, the one that bounds the section's write time from below, and where the body carries none the floor is unmet and the acceptance fails
gv9-retro-timeofday|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|with a time of day counts toward that floor, written `YYYY-MM-DDTHH:MM` with a `T` and optional seconds and zone; a date-only value or a space-separated date and time is not counted
gv9-retro-addendum|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|This fallback over-reaches by any addendum appended to the section after the deviation, whose later timestamp raises the floor, so it fails closed; §4 writes a `Timestamp:` line on its own section
gv9-retro-noslot|S|steps/gate-validation.md|### 9.|### 10.|**At a `retro` gate, Check 9 adopts `deploy-validate.md` §4's recorded evidence instead of a fresh fetch.**|para|A line with no slot quote does not verify, and where one line carries several timestamp-and-quote pairs every pair is verified, each by its own quote and its own timestamp.
gv17-retro-args|S|steps/gate-validation.md|### 17. Skill-invocation provenance|### 18.|- **Retro gate:**|para|`scripts/ai-dlc/validate-retro-evidence.sh ai-dlc/retro/sprint-<N> <N>`.
retro-gate-invoked|S|steps/retro.md|### 5c. Pre-Commit Validation Gate|### 6. Commit, Push, and PR|6. **Run gate validation [retro]**|para|A gate FAIL blocks the Step 6 commit, as a failing check 2-5 does.
retro-gate-blocks|S|steps/retro.md|### 5c. Pre-Commit Validation Gate|### 6. Commit, Push, and PR|**An unclearable check in this gate escalates; it never self-clears.**|para|(checks 2, 3, 4, 5 and 6)
retro-gate-d2|S|steps/retro.md|### 5c. Pre-Commit Validation Gate|### 6. Commit, Push, and PR|**An unclearable check in this gate escalates; it never self-clears.**|para|For check 6 the operator's disposition on a gate FAIL is recorded in the form `gate-validation.md` Check 26 reads
retro-gate-count|S|steps/retro.md|### 5c. Pre-Commit Validation Gate|### 6. Commit, Push, and PR|Before committing retro artifacts,|para|run all six checks in order.
PINS
}

pin_path() { case "$1" in S) printf '%s/%s\n' "$SKILL_DIR" "$2" ;; R) printf '%s/%s\n' "$ROLES_DIR" "$2" ;; esac; }

# The retired range. Alternation, never a bracket class: the en dash is multibyte.
RANGE_OLD='0(–|-)2b'
RANGE_NEW='0(–|-)2c'
range_count() { # range_count <regex> <dir>... -> matching line count across the dirs
  local re="$1" n; shift
  n="$(grep -rhE "$re" "$@" 2>/dev/null | wc -l | tr -d ' ')" || n=0
  printf '%s\n' "${n:-0}"
}

# consumer_owned — basenames of the consumer-owned scaffolds beside the core flat files,
# DERIVED from the layer contract's consumer_*_file keys rather than hand-listed. An
# installed tree lays those scaffolds down next to core's own files, and their content is
# the consumer's, which this fixture has no standing over.
consumer_owned() {
  local lc="$SKILL_DIR/layer-contract.yaml"
  [ -f "$lc" ] || return 1
  awk '/^consumer_[a-z_]*_file:[ \t]/ { v = $2; n = split(v, a, "/"); print a[n] }' "$lc"
}

range_scope() { # the core-installed paths only; paths carry no whitespace in either layout
  local p b own
  own=" $(consumer_owned | tr '\n' ' ') "
  for p in "$SKILL_DIR"/*.md "$SKILL_DIR/steps" "$SKILL_DIR/rule-bodies" "$ROLES_DIR"; do
    [ -e "$p" ] || continue
    b="$(basename "$p")"
    case "$own" in *" $b "*) continue ;; esac
    printf '%s ' "$p"
  done
}

# --- the lead's address ---------------------------------------------------------
# A teammate told to "message the lead" with no address sends `to: "lead"`, which the harness
# does not register: measured 0 of 15 delivered on the reference consumer, against 167 of 167
# for `to: "main"`. Teammates do not load rule bodies, so the address is carried at EVERY site
# that tells a teammate to message or escalate to the lead, and Rule 28 holds only the reason.
# The literal is DERIVED from Rule 28's own lead sentence, so a site and the rule cannot carry
# two different addresses; an empty derivation fails, never passes.
#
# THE UNIT IS THE JOINED ITEM. Blank lines, headings, fences, comments and every list-item
# opener end an item; continuation lines join into it, whitespace collapsed. A site whose
# instruction and literal sit on different wrapped lines of one bullet is one string.
#
# THE PREDICATE, three shapes over the lowercased item:
#   P1  message/messages/messaging/escalate, then optional to/with, optional the, then lead
#       (bold or not): "message lead", "Message **lead**", "Escalate to the lead".
#   P2  "message the <words> and the lead" -- no punctuation between, so a sentence that merely
#       mentions a message and later the lead cannot join (pm.md "dev teammate and the lead").
#   P3  sendmessage, then no period, then "to the lead" -- the Deliver-before-idle bullets,
#       including the shape where `SendMessage` is followed by a backtick and a line wrap.
#   P4  hand/hands/handed/handing, then plain words only, then "to the lead" -- code-reviewer.md
#       "HAND THE REVIEW TO THE LEAD TO PERSIST". Words only (no punctuation) between verb and
#       object, so "handoff" and "the lead hands it back" cannot join.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO. A broader predicate (message within a sentence of
# lead) flagged eight sentences that describe the lead receiving or judging a message rather
# than instructing a send: remediator.md "Measured: a repair removed...", pm-escalated.md
# "Where a gap in the input...", adversary.md item 3 and its operator_authorization paragraph,
# gate-adjudicator.md item 3, rule-20.md "File-write deliverable", deploy-validate.md "Minimum
# mechanism", escalations.md "RESOLVED / OVERRIDDEN". Requiring the verb to be IMMEDIATELY
# followed by its object (P1), a punctuation-free object list (P2), or "to the lead" after
# SendMessage (P3) drops all eight. P4 measured alone over the same corpus hits exactly one item,
# the code-reviewer.md send instruction, against 239 items carrying a bare "hand" word. Measured
# over lead_files (below) AND over core/**/*.md less fixtures and ai-dlc-update -- the wider set
# adds 11 files and 0 hits: every hit is a send instruction, plus Rule 28's own paragraph, which
# carries the literal. FP set: empty. The probes below seed the "text-only final message ...
# and the lead treats an absent file" shape, which a looser P2 accepted, as a near-miss.
#
# THE CORPUS is lead_files: the install-scoped flat skill files, steps/, rule-bodies/ and the
# roles -- never extensions/ or overrides/, which on a consumer hold consumer-owned prose this
# fixture has no standing over (the reference consumer carries bare sites there). The BL-520
# receipt reads this corpus through --lead-verdict with no file list.
LEAD_FLOOR=23
# The MEASURED address. Deriving the literal from Rule 28 binds the sites to the rule; this binds
# the rule to the measurement, so a rule and its sites rewritten together to `to: "lead"` (the
# address that failed 15 of 15) still fail. Change it only with a new measurement.
LEAD_ADDR_MEASURED='to: "main"'
lead_addr() { # <rule-28 path> -> the address literal in its lead sentence, or nothing
  [ -f "$1" ] || return 0
  awk 'index($0, "**A dispatched teammate reaches the lead with") == 1 {
         if (match($0, /to: "[^"]*"/)) { print substr($0, RSTART, RLENGTH); exit } }' "$1"
}
lead_scan() { # <addr> <files...> -> one "<file>:<line><TAB>HAS|BARE" row per site item
  LS_ADDR="$1" awk '
  function flush(   q, lq) {
    if (p == "") return
    q = p; gsub(/[ \t]+/, " ", q); lq = tolower(q)
    if (lq ~ /(^|[^a-z])(messag(e|es|ing)|escalate) +((to|with) +)?(the +)?\**lead\**([^a-z0-9_-]|$)/ \
     || lq ~ /(^|[^a-z])messag(e|ing) the [a-z ]+ and (the +)?\**lead\**([^a-z0-9_-]|$)/ \
     || lq ~ /(^|[^a-z])sendmessage[^.]*to +(the +)?\**lead\**([^a-z0-9_-]|$)/ \
     || lq ~ /(^|[^a-z])hand(s|ed|ing)? +([a-z0-9-]+ +)*to +(the +)?\**lead\**([^a-z0-9_-]|$)/) {
      has = (index(q, A) > 0)
      printf "%s:%d\t%s\n", pf, pl, (has ? "HAS" : "BARE")
    }
    p = ""
  }
  BEGIN { A = ENVIRON["LS_ADDR"] }
  FNR == 1 { flush(); fence = ""; com = 0 }
  {
    t = $0; sub(/^[ \t]+/, "", t)
    if (com) { if (index($0, "-->")) com = 0; flush(); next }
    if (fence != "") { if (substr(t, 1, 3) == fence) fence = ""; next }
    if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { flush(); fence = substr(t, 1, 3); next }
    if (substr(t, 1, 4) == "<!--") { if (!index(substr(t, 5), "-->")) com = 1; flush(); next }
    if (t == "" || substr(t, 1, 1) == "#") { flush(); next }
    if (t ~ /^([-*+]|[0-9]+[.)]) /) flush()
    if (p == "") { pf = FILENAME; pl = FNR; p = t } else p = p " " t
  }
  END { flush() }' "${@:2}"
}
lead_verdict() { # <floor> <addr> <files...> -> one "PASS ..." or "FAIL ..." line; rc 0 or 1
  local fl="$1" a="$2" rows n nb; shift 2
  # One guard owns both failures: an empty derivation (Rule 28's lead sentence gone) and a wrong one.
  [ "$a" = "$LEAD_ADDR_MEASURED" ] || { echo "FAIL lead-address: Rule 28's lead sentence names '${a:-<nothing>}', not the measured $LEAD_ADDR_MEASURED"; return 1; }
  [ "$#" -ge 1 ] || { echo "FAIL lead-address: empty corpus"; return 1; }
  rows="$(lead_scan "$a" "$@")"
  n="$(grep -c . <<<"$rows")" || n=0
  nb="$(grep -c "$(printf '\t')BARE\$" <<<"$rows")" || nb=0
  if [ "$n" -lt "$fl" ]; then
    echo "FAIL lead-address: $n site(s) found, floor $fl -- the predicate cannot see the sites it guards, so its zero is no finding"; return 1
  fi
  if [ "$nb" -gt 0 ]; then
    echo "FAIL lead-address: $nb of $n site(s) tell a teammate to message the lead without $a: $(grep "BARE\$" <<<"$rows" | cut -f1 | sed "s|^${ROOT:-@@}/||" | tr '\n' ' ')"; return 1
  fi
  echo "PASS lead-address: $n of $n site(s) carry Rule 28's $a (floor $fl)"
}
lead_files() { # the install-scoped markdown corpus, sorted; no path carries a blank
  # shellcheck disable=SC2046 # range_scope prints blank-separated paths on purpose
  find $(range_scope) -type f -name '*.md' 2>/dev/null | LC_ALL=C sort
}

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# corpus_report — the verdict over the resolved tree. Printed identically by --report.
corpus_report() {
  printf '  root: %s (%s)\n' "$ROOT" "$LAYOUT"
  local id base rel s e lead mode tok f out rc ins whole sl el fl
  while IFS='|' read -r id base rel s e lead mode tok; do
    f="$(pin_path "$base" "$rel")"
    [ -f "$f" ] || { bad "$id: subject file absent: ${f#"$ROOT/"}"; continue; }
    out="$(pin_scan "$f" "$s" "$e" "$lead" "$mode" "$tok")"; rc=$?
    [ "$rc" -eq 0 ] || { bad "$id: ${f#"$ROOT/"} has an unbalanced fence or comment"; continue; }
    read -r ins whole sl el fl <<<"$out"
    if [ "$mode" = "absent" ]; then
      [ "$whole" -eq 0 ] && ok "$id: absent from ${f#"$ROOT/"}" \
                         || bad "$id: token present in ${f#"$ROOT/"} at line $fl ($whole hit(s)) — the definition must live once"
    elif [ "$sl" -eq 0 ] || [ "$el" -eq 0 ]; then
      bad "$id: span [${s:-<top>} .. $e] not found in ${f#"$ROOT/"} (start=$sl end=$el)"
    elif [ "$ins" -ge 1 ]; then
      ok "$id: pinned inside [${s:-<top>} .. $e] of ${f#"$ROOT/"}"
    else
      bad "$id: not inside [${s:-<top>} .. $e] of ${f#"$ROOT/"} (whole-file hits: $whole)"
    fi
  done <<<"$(pins)"

  # §2b precedes §2c precedes §3 — the title pin above proves §2c sits between §2b and §3;
  # this proves the three headings appear in that order as first occurrences.
  local bf="$SKILL_DIR/steps/bug-investigation.md" b2 c2 t3
  if [ -f "$bf" ]; then
    b2="$(pin_scan "$bf" "" "@@never@@" "### 2b." prefix | awk '{print $5}')"
    c2="$(pin_scan "$bf" "" "@@never@@" "### 2c." prefix | awk '{print $5}')"
    t3="$(pin_scan "$bf" "" "@@never@@" "### 3." prefix | awk '{print $5}')"
    if [ "${b2:-0}" -gt 0 ] && [ "${c2:-0}" -gt "${b2:-0}" ] && [ "${t3:-0}" -gt "${c2:-0}" ]; then
      ok "order: §2b (line $b2) < §2c (line $c2) < §3 (line $t3)"
    else
      bad "order: §2b=${b2:-?} §2c=${c2:-?} §3=${t3:-?} — §2c must sit after §2b and before §3"
    fi
  else
    bad "order: bug-investigation.md absent"
  fi

  # No retired 0–2b range remains; the 0–2c count beside it proves the scan reads the tree.
  # Scope: what install.sh lays down — the flat skill files, steps/, rule-bodies/ and the
  # roles. Never extensions/ or overrides/, which on a consumer hold consumer-owned prose
  # this fixture has no standing over.
  local old new scope nown
  nown="$(consumer_owned | grep -c .)" || nown=0
  [ "$nown" -ge 1 ] || bad "range: no consumer_*_file key derivable from layer-contract.yaml — consumer scaffolds cannot be excluded"
  scope="$(range_scope)"
  old="$(range_count "$RANGE_OLD" $scope)"
  new="$(range_count "$RANGE_NEW" $scope)"
  if [ "$old" -gt 0 ]; then
    bad "range: $old line(s) still carry the retired 0–2b range"
  elif [ "$new" -lt 2 ]; then
    bad "range: control found only $new line(s) carrying 0–2c — the scan cannot see the tree, its zero is no finding"
  else
    ok "range: 0 lines carry the retired 0–2b range (control: $new carry 0–2c)"
  fi

  # Every site telling a teammate to message the lead carries Rule 28's address literal.
  local la lout
  la="$(lead_addr "$SKILL_DIR/rule-bodies/rule-28.md")"
  # shellcheck disable=SC2046 # lead_files prints one path per line, none with a blank
  lout="$(lead_verdict "$LEAD_FLOOR" "$la" $(lead_files))"
  case "$lout" in PASS*) ok "${lout#PASS }" ;; *) bad "${lout#FAIL }" ;; esac
}

RESOLVED="$(resolve_root "$HERE" || true)"
# --lead-verdict <floor|-> <addr|-> [<files...>] -- the lead-address arm alone, over the files
# given, or over lead_files of the resolved tree when none are. `-` takes LEAD_FLOOR and the
# literal derived from the resolved tree's Rule 28. Used by the mutants below and by the BL-520
# receipt. Exit 0 pass, 1 fail, 2 no root where one is needed.
if [ "${1:-}" = "--lead-verdict" ]; then
  lv_f="${2:-}"; lv_a="${3:-}"; shift 3 2>/dev/null || exit 2
  [ "$lv_f" = "-" ] && lv_f="$LEAD_FLOOR"
  if [ "$lv_a" = "-" ] || [ "$#" -eq 0 ]; then
    [ -n "$RESOLVED" ] && dirs_for "$RESOLVED" || exit 2
  fi
  [ "$lv_a" = "-" ] && lv_a="$(lead_addr "$SKILL_DIR/rule-bodies/rule-28.md")"
  if [ "$#" -eq 0 ]; then
    # shellcheck disable=SC2046 # lead_files prints one path per line, none with a blank
    lead_verdict "$lv_f" "$lv_a" $(lead_files); exit $?
  fi
  lead_verdict "$lv_f" "$lv_a" "$@"; exit $?
fi
if [ "${1:-}" = "--report" ]; then
  [ -n "$RESOLVED" ] && dirs_for "$RESOLVED" || { echo "FIXTURE ERROR: no ai-dlc skill dir above $HERE" >&2; exit 2; }
  corpus_report
  [ "$fails" -eq 0 ] && exit 0 || exit 1
fi

. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: core/fixtures/lib/mutant.sh is absent" >&2; exit 2; }
B_rscope=0; B_join=0; B_slot=0; B_bm=0; B_le=0; B_win=0; B_mscope=0; B_epgp=0; B_epho=0; B_dv=0; B_mruns=0; B_mdl=0; B_cwd=0
echo "process-rule-pins"
[ -n "$RESOLVED" ] && echo "HERMETIC-CONSUMED core/skills/ai-dlc/"
WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

# --- 1. resolver probes, every root shape --------------------------------------
LAY="$WORK/lay"
mkdir -p "$LAY/dist/core/skills/ai-dlc" "$LAY/dist/core/team-roles" "$LAY/dist/core/fixtures/x" \
         "$LAY/cons/.claude/skills/ai-dlc" "$LAY/cons/.claude/team-roles" "$LAY/cons/tests/fixtures/x" \
         "$LAY/none/tests/fixtures/x" || exit 2
got="$(resolve_root "$LAY/dist/core/fixtures/x" || true)"
[ "$got" = "dist $LAY/dist" ] && ok "resolver: distribution layout from core/fixtures/<name>" \
                              || bad "resolver: distribution layout — got '${got:-<none>}'"
got="$(resolve_root "$LAY/cons/tests/fixtures/x" || true)"
[ "$got" = "consumer $LAY/cons" ] && ok "resolver: consumer layout from tests/fixtures/<name>" \
                                  || bad "resolver: consumer layout — got '${got:-<none>}'"
# Fail-closed: ceilinged at the probe tree, so nothing above the temp dir can answer. The
# exit status AND the empty output are both asserted; either alone admits an invented root.
got="$(resolve_root "$LAY/none/tests/fixtures/x" "$LAY/none")"; rc=$?
[ "$rc" -eq 1 ] && [ -z "$got" ] && ok "resolver: fails closed (rc=1, no root) on a tree with neither layout" \
                                 || bad "resolver: did not fail closed on a tree with neither layout — rc=$rc got='$got'"
got="$(resolve_root "$LAY/cons/tests/fixtures/x" "$LAY/cons")"; rc=$?
[ "$rc" -eq 0 ] && [ "$got" = "consumer $LAY/cons" ] && ok "CONTROL: the same ceiling still admits a root that IS inside it" \
                                                   || bad "CONTROL: the ceiling refused a root inside it — rc=$rc got='$got'"

# --- 2. engine probes, both directions, on synthetic text ----------------------
P="$WORK/probe"; mkdir -p "$P" || exit 2
probe() { # probe <label> <expected-ins> <file> <start> <end> <lead> <mode> [<token>]
  local label="$1" want="$2" out rc ins
  out="$(pin_scan "$3" "$4" "$5" "$6" "$7" "${8:-}")"; rc=$?
  [ "$rc" -eq 0 ] || { bad "engine: $label — scan returned rc=$rc"; return; }
  ins="${out%% *}"
  [ "$ins" = "$want" ] && ok "engine: $label (in-span=$ins)" || bad "engine: $label — in-span=$ins, wanted $want"
}
printf '# t\n## A\n**LEAD.** in span\n## B\n**LEAD.** after\n' > "$P/hit.md"
probe "a lead inside the span is found" 1 "$P/hit.md" "## A" "## B" "**LEAD.**" prefix
printf '# t\n## A\nprose\n## B\n**LEAD.** after\n' > "$P/out.md"
probe "a lead only outside the span is not found" 0 "$P/out.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n```\n**LEAD.** fenced\n```\n## B\n' > "$P/fence.md"
probe "a fenced lead is not found" 0 "$P/fence.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n<!--\n**LEAD.** commented\n-->\n<!-- **LEAD.** one-line -->\n## B\n' > "$P/com.md"
probe "a commented lead is not found" 0 "$P/com.md" "## A" "## B" "**LEAD.**" prefix
# Mode probes, both directions, before any corpus row. fenced: a fenced hit inside the span passes,
# the deleted file and a fenced hit outside the span fire. absent: a seeded copy (fenced or not)
# fires, a near-miss one word short stays quiet.
printf '## A\n```\nT: fenced token\n```\n## B\n' > "$P/fd-in.md"
probe "fenced mode: a fenced token inside the span is found" 1 "$P/fd-in.md" "## A" "## B" "T: fenced" fenced
printf '## A\nprose\n## B\n```\nT: fenced token\n```\n' > "$P/fd-out.md"
probe "fenced mode: a fenced token outside the span is not found" 0 "$P/fd-out.md" "## A" "## B" "T: fenced" fenced
printf '## A\n```\nsomething else\n```\n## B\n' > "$P/fd-del.md"
probe "fenced mode: the deleted token is not found" 0 "$P/fd-del.md" "## A" "## B" "T: fenced" fenced
printf '## A\n```\nT: fenced token\n```\n## B\n' > "$P/fd-prefix.md"
probe "prefix mode still ignores a fenced token (fenced mode changed no other mode)" 0 "$P/fd-prefix.md" "## A" "## B" "T: fenced" prefix
# fenced mode with two fenced lines, each pinned by its own row on a token distinct to it: the
# intact file passes both, and deleting EACH line alone fires exactly that line's row.
printf '## A\n```\nT: one <x>\nT: two <y>\n```\n## B\n' > "$P/fd2-both.md"
printf '## A\n```\nT: two <y>\n```\n## B\n' > "$P/fd2-no1.md"
printf '## A\n```\nT: one <x>\n```\n## B\n' > "$P/fd2-no2.md"
probe "two fenced lines: the intact file finds line 1" 1 "$P/fd2-both.md" "## A" "## B" "T: one <x>" fenced
probe "two fenced lines: the intact file finds line 2" 1 "$P/fd2-both.md" "## A" "## B" "T: two <y>" fenced
probe "two fenced lines: deleting line 1 alone fires its row" 0 "$P/fd2-no1.md" "## A" "## B" "T: one <x>" fenced
probe "two fenced lines: deleting line 1 alone leaves line 2 found" 1 "$P/fd2-no1.md" "## A" "## B" "T: two <y>" fenced
probe "two fenced lines: deleting line 2 alone fires its row" 0 "$P/fd2-no2.md" "## A" "## B" "T: two <y>" fenced
probe "two fenced lines: deleting line 2 alone leaves line 1 found" 1 "$P/fd2-no2.md" "## A" "## B" "T: one <x>" fenced
printf 'one git pathspec per line here\n' > "$P/ab-copy.md"
probe "absent mode: a seeded verbatim copy fires" 1 "$P/ab-copy.md" "" "" "one git pathspec per line" absent
printf 'a\n```\none git pathspec per line\n```\n' > "$P/ab-fence.md"
probe "absent mode: a seeded copy inside a fence fires" 1 "$P/ab-fence.md" "" "" "one git pathspec per line" absent
printf 'one git pathspec per\nline of text\n' > "$P/ab-near.md"
probe "absent mode: a near-miss (wrapped, one word short) stays quiet" 0 "$P/ab-near.md" "" "" "one git pathspec per line" absent
printf '## A\n  **LEAD.** indented\nsee **LEAD.** mid-line\n## B\n' > "$P/indent.md"
probe "an indented or mid-line lead is not a line-start pin" 0 "$P/indent.md" "## A" "## B" "**LEAD.**" prefix
probe "a mid-line token IS found in contains mode" 2 "$P/indent.md" "## A" "## B" "**LEAD.**" contains
printf '## A\n```\n## B fenced end marker\n```\n**LEAD.** after fenced marker\n## B\n' > "$P/fend.md"
probe "a fenced span-end marker does not close the span" 1 "$P/fend.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n### sub\n**LEAD.** under a subheading\n## B\n' > "$P/sub.md"
probe "a ### heading does not close a ## span" 1 "$P/sub.md" "## A" "## " "**LEAD.**" prefix
printf '**LEAD.** top\n## B\n**LEAD.** after\n' > "$P/top.md"
probe "an empty start opens the span at line 1" 1 "$P/top.md" "" "## B" "**LEAD.**" prefix
out="$(pin_scan "$P/out.md" "## Z" "## B" "**LEAD.**" prefix)"
[ "$(printf '%s' "$out" | awk '{print $3}')" = "0" ] && ok "engine: a missing span start is reported as start=0" \
                                                     || bad "engine: missing span start not reported — '$out'"
printf '## A\n```\n**LEAD.**\n## B\n' > "$P/unbal.md"
pin_scan "$P/unbal.md" "## A" "## B" "**LEAD.**" prefix >/dev/null; rc=$?
[ "$rc" -eq 2 ] && ok "engine: an unbalanced fence is a broken file (rc=2), not a missing pin" \
                || bad "engine: unbalanced fence returned rc=$rc"
# A comment opened mid-line hides the rest of the line and what follows until it closes.
printf '## A\nprose <!--\n**LEAD.** hidden\n-->\n## B\n' > "$P/midcom.md"
probe "a lead after a mid-line comment opener is hidden" 0 "$P/midcom.md" "## A" "## B" "**LEAD.**" prefix

# Paragraph mode: lead and token joined across a line wrap, both directions.
printf '## A\n\n**LEAD.** the rule MUST\ncarry it here.\n\n## B\n' > "$P/para.md"
probe "para: a token wrapped across lines under the lead is found" 1 "$P/para.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule need NOT\ncarry it here.\n\n## B\n' > "$P/paraneg.md"
probe "para: the same paragraph with the clause negated is not found" 0 "$P/paraneg.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule.\n\nMUST carry it, in another paragraph.\n\n## B\n' > "$P/parasplit.md"
probe "para: the token in a DIFFERENT paragraph from the lead is not found" 0 "$P/parasplit.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule.\n\n## B\n\n**LEAD.** MUST carry it.\n' > "$P/paraout.md"
probe "para: lead and token together but outside the span are not found" 0 "$P/paraout.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule\n<!-- MUST carry it -->\n\n## B\n' > "$P/paracom.md"
probe "para: the token inside a comment is not found" 0 "$P/paracom.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n**LEAD.** the rule\n## B\nMUST carry it\n' > "$P/parahead.md"
probe "para: a heading ends a paragraph, so a token beyond the span end does not join" 0 "$P/parahead.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
# Exact mode, both directions: the whole paragraph wrapped across lines equals the pin; the same
# paragraph with one sentence appended does not (para mode, the control, still passes it); a second
# paragraph in the span fails it; a paragraph added outside the span leaves it found; the pinned
# paragraph outside the span is not found.
printf '## A\n\n**LEAD.** the rule MUST\ncarry it here.\n\n## B\n' > "$P/ex.md"
probe "exact: the whole paragraph wrapped across lines equals the pin" 1 "$P/ex.md" "## A" "## B" "**LEAD.**" exact "**LEAD.** the rule MUST carry it here."
printf '## A\n\n**LEAD.** the rule MUST\ncarry it here. But not always.\n\n## B\n' > "$P/exapp.md"
probe "exact: the paragraph with a sentence appended is not found" 0 "$P/exapp.md" "## A" "## B" "**LEAD.**" exact "**LEAD.** the rule MUST carry it here."
probe "exact: CONTROL, para mode still finds that appended paragraph" 1 "$P/exapp.md" "## A" "## B" "**LEAD.**" para "the rule MUST carry it here."
printf '## A\n\n**LEAD.** the rule MUST\ncarry it here.\n\nAnother paragraph.\n\n## B\n' > "$P/exnear.md"
probe "exact: two paragraphs in the span fail the pin" 0 "$P/exnear.md" "## A" "## B" "**LEAD.**" exact "**LEAD.** the rule MUST carry it here."
printf '## A\n\n**LEAD.** the rule MUST\ncarry it here.\n\n## B\n\nAnother paragraph.\n' > "$P/exside.md"
probe "exact: a paragraph added outside the span leaves the pinned one found" 1 "$P/exside.md" "## A" "## B" "**LEAD.**" exact "**LEAD.** the rule MUST carry it here."
printf '## A\n\nprose\n\n## B\n\n**LEAD.** the rule MUST carry it here.\n' > "$P/exout.md"
probe "exact: the paragraph outside the span is not found" 0 "$P/exout.md" "## A" "## B" "**LEAD.**" exact "**LEAD.** the rule MUST carry it here."

# Range scan probe, both directions.
mkdir -p "$P/r1" "$P/r2" || exit 2
printf 'sections 0–2b for the defect\nsections 0-2b ascii\n' > "$P/r1/a.md"
printf 'sections 0–2c here; §2b stays; section 2b too\n' > "$P/r2/a.md"
n="$(range_count "$RANGE_OLD" "$P/r1")"
[ "$n" = "2" ] && ok "range probe: en-dash and hyphen spellings of 0–2b both found (2)" || bad "range probe: found $n of 2 seeded 0–2b lines"
n="$(range_count "$RANGE_OLD" "$P/r2")"
[ "$n" = "0" ] && ok "range probe: 0–2c and a bare §2b are not the retired range (0)" || bad "range probe: near-miss scored $n"
# Scope probe: a consumer-owned extension carrying the old range is out of scope; the same
# text in steps/ is in scope.
mkdir -p "$P/sc/sk/extensions" "$P/sc/sk/steps" "$P/sc/roles" || exit 2
printf 'sections 0–2b in an extension\n' > "$P/sc/sk/extensions/x.md"
n="$( SKILL_DIR="$P/sc/sk" ROLES_DIR="$P/sc/roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "0" ] && ok "range scope: extensions/ is not scanned (0)" || bad "range scope: extensions/ scanned ($n)"
printf 'sections 0–2b in a step\n' > "$P/sc/sk/steps/s.md"
n="$( SKILL_DIR="$P/sc/sk" ROLES_DIR="$P/sc/roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "1" ] && ok "range scope: steps/ is scanned (1)" || bad "range scope: steps/ not scanned ($n)"
# Consumer-layout scope: a consumer-owned scaffold beside the core flat files, declared by a
# consumer_*_file key, is out of scope; a core flat file beside it is in scope; and with the
# key removed the same scaffold IS read, which proves the exclusion is the derivation.
CS="$P/cs/.claude/skills/ai-dlc"; mkdir -p "$CS/steps" "$P/cs/.claude/team-roles" || exit 2
printf 'consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md\n' > "$CS/layer-contract.yaml"
printf 'sections 0–2b in a consumer crosswalk\n' > "$CS/crosswalk.md"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "0" ] && ok "range scope (consumer): crosswalk.md, declared consumer-owned, is not scanned (0)" \
               || bad "range scope (consumer): consumer-owned crosswalk.md scanned ($n)"
printf 'sections 0–2b in a core flat file\n' > "$CS/escalations.md"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "1" ] && { ok "range scope (consumer): a core flat file beside it is scanned (1)"; B_rscope=1; } \
               || bad "range scope (consumer): core flat file not scanned ($n)"
printf 'unrelated: 1\n' > "$CS/layer-contract.yaml"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "2" ] && mutant_killed "$B_rscope" rscope-nokey "MUTANT range scope: without the consumer_*_file key the crosswalk IS read (2) — the exclusion is the derivation" \
               || bad "MUTANT range scope: removing the key left the count at $n — the exclusion is not what the probe credited"

# --- 3. resolve the real tree --------------------------------------------------
[ -n "$RESOLVED" ] && dirs_for "$RESOLVED" || {
  echo "FIXTURE ERROR: no ai-dlc skill dir found walking up from $HERE" >&2; exit 2; }

# --- 4. per-pin near-misses and deletion mutants, on copies of the real files ---
# mutate <mode> <src> <dst> <lead> <match>  — rewrites every line carrying the lead
mutate() {
  MU_MODE="$1" MU_LEAD="$4" MU_MATCH="$5" awk '
  BEGIN { m = ENVIRON["MU_MODE"]; l = ENVIRON["MU_LEAD"]; k = ENVIRON["MU_MATCH"]; n = 0 }
  {
    if (k == "contains") hit = (index($0, l) > 0); else hit = (index($0, l) == 1)
    if (!hit) { print; next }
    if (m == "delete")   next
    if (m == "relocate") { held[++n] = $0; next }
    if (m == "fence")    { print "```"; print; print "```"; next }
    if (m == "comment")  { print "<!--"; print; print "-->"; next }
    if (m == "indent")   { print "  " $0; next }
    print
  }
  END { for (i = 1; i <= n; i++) print held[i] }' "$2" > "$3"
}
# flatten <src> <dst> — every paragraph outside fences and comments onto ONE line. The para
# mutants edit this form so a token wrapped across lines can be negated or moved whole; a
# control asserts the flattened copy scores exactly as the original does before any mutant
# verdict is read.
flatten() {
  awk '
  function out() { if (p != "") print p; p = "" }
  {
    t = $0; sub(/^[ \t]+/, "", t)
    if (com) { print; if (index($0, "-->")) com = 0; next }
    if (fence != "") { print; if (substr(t, 1, 3) == fence) fence = ""; next }
    if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { out(); fence = substr(t, 1, 3); print; next }
    if (index($0, "<!--") && !index(substr($0, index($0, "<!--") + 4), "-->")) { out(); com = 1; print; next }
    if (t == "") { out(); print; next }
    if (substr(t, 1, 1) == "#") { out(); print; next }
    p = (p == "" ? $0 : p " " $0)
  }
  END { out() }' "$1" > "$2"
}
# pmutate <mode> <flat-src> <dst> <lead> <token> — acts on the one paragraph line that begins
# with the lead and carries the token.
pmutate() {
  MU_MODE="$1" MU_LEAD="$4" MU_TOK="$5" awk '
  BEGIN { m = ENVIRON["MU_MODE"]; l = ENVIRON["MU_LEAD"]; k = ENVIRON["MU_TOK"]; n = 0 }
  {
    # Collapsed and left-trimmed exactly as pin_scan flush() does, so a paragraph indented under
    # a numbered list item is the same string to the mutator as to the scanner.
    q = $0; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q)
    if (!(index(q, l) == 1 && index(q, k) > 0)) { print; next }
    if (m == "negate")   { i = index(q, k); print substr(q, 1, i - 1) "NEGATED-CLAUSE" substr(q, i + length(k)); next }
    if (m == "append")   { print q " APPENDED-SENTENCE."; next }
    if (m == "relocate") { held[++n] = q; next }
    if (m == "fence")    { print "```"; print q; print "```"; next }
    if (m == "comment")  { print "<!--"; print q; print "-->"; next }
    print
  }
  END { for (i = 1; i <= n; i++) { print ""; print held[i] } }' "$2" > "$3"
}

M="$WORK/mut"; mkdir -p "$M" || exit 2
while IFS='|' read -r id base rel s e lead mode tok; do
  f="$(pin_path "$base" "$rel")"
  [ -f "$f" ] || { bad "$id: subject ${f#"$ROOT/"} absent — no near-miss or mutant can be built"; continue; }
  if [ "$mode" = "absent" ]; then
    # MUTANT: the token copied into the file (inside a fence, to prove fences are not an exemption) must fire.
    dst="$M/$id.copy.md"; { cat "$f"; printf '\n```\n%s\n```\n' "$lead"; } > "$dst"
    o0="$(pin_scan "$f" "" "" "$lead" absent)"; o1="$(pin_scan "$dst" "" "" "$lead" absent)"
    B_copy=0
    if [ "${o0%% *}" = "0" ]; then ok "$id/copy: control: the unmutated file carries no copy of the token (reads 0)"; B_copy=1; fi
    if [ "${o0%% *}" = "0" ] && [ "${o1%% *}" -ge 1 ]; then
      mutant_killed "${B_copy:-0}" "$id/copy" "$id/copy: the token copied into the file fires (original 0, mutant ${o1%% *})"
    else bad "$id/copy: original='${o0%% *}' mutant='${o1%% *}' (wanted 0 and >=1)"; fi
    continue
  fi
  if [ "$mode" = "fenced" ]; then
    # MUTANT: every line carrying the token deleted must score 0 in-span and 0 whole-file.
    o0="$(pin_scan "$f" "$s" "$e" "$lead" fenced)"
    dst="$M/$id.delete.md"; mutate delete "$f" "$dst" "$lead" contains
    if cmp -s "$f" "$dst"; then bad "$id/delete: mutation did not apply"; continue; fi
    o1="$(pin_scan "$dst" "$s" "$e" "$lead" fenced)"; read -r ins whole sl el fl <<<"$o1"
    B_fdel=0
    if [ "${o0%% *}" -ge 1 ]; then ok "$id/delete: control: the unmutated file pins the fenced lead in span (${o0%% *})"; B_fdel=1; fi
    if [ "${o0%% *}" -ge 1 ] && [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then
      mutant_killed "${B_fdel:-0}" "$id/delete" "$id/delete: every fenced line deleted fires (original in-span ${o0%% *}, mutant $ins)"
    else bad "$id/delete: original in-span='${o0%% *}' mutant in-span=$ins whole=$whole"; fi
    continue
  fi
  raw="$(grep -cF -- "$lead" "$f")" || raw=0
  [ "$raw" -ge 1 ] || { bad "$id: lead absent from ${f#"$ROOT/"} — mutants have no subject"; continue; }
  if [ "$mode" = "para" ] || [ "$mode" = "exact" ]; then
    flat="$M/$id.flat.md"; flatten "$f" "$flat"
    o1="$(pin_scan "$f" "$s" "$e" "$lead" "$mode" "$tok")"; o2="$(pin_scan "$flat" "$s" "$e" "$lead" "$mode" "$tok")"
    B_para=0
    if [ "${o1%% *}" = "1" ] && [ "${o2%% *}" = "1" ]; then
      ok "$id: control: original and flattened copy both pin the paragraph in span (1)"; B_para=1
    else
      bad "$id: CONTROL — original in-span=${o1%% *}, flattened in-span=${o2%% *}; both must be 1 before a mutant is read"; continue
    fi
    pmodes="negate relocate fence comment"
    [ "$mode" = "exact" ] && pmodes="$pmodes append"
    for mm in $pmodes; do
      dst="$M/$id.$mm.md"
      pmutate "$mm" "$flat" "$dst" "$lead" "$tok"
      if cmp -s "$flat" "$dst"; then bad "$id/$mm: mutation did not apply"; continue; fi
      out="$(pin_scan "$dst" "$s" "$e" "$lead" "$mode" "$tok")"; rc=$?
      [ "$rc" -eq 0 ] || { bad "$id/$mm: mutated copy unbalanced (rc=$rc)"; continue; }
      read -r ins whole sl el fl <<<"$out"
      case "$mm" in
        negate)   if [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then mutant_killed "${B_para:-0}" "$id/negate" "$id/negate: binding clause rewritten under an intact lead"
                    else bad "$id/negate: SURVIVED (in-span=$ins whole=$whole)"; fi ;;
        append)   if [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then mutant_killed "${B_para:-0}" "$id/append" "$id/append: a sentence appended to the exact paragraph fails it"
                    else bad "$id/append: SURVIVED (in-span=$ins whole=$whole)"; fi ;;
        relocate) [ "$ins" -eq 0 ] && [ "$whole" -ge 1 ] && ok "$id/relocate: paragraph outside the span fails though it is still in the file" \
                    || bad "$id/relocate: in-span=$ins whole=$whole — span does not discriminate" ;;
        fence|comment)
                  [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/$mm: wrapped paragraph is invisible though still present" \
                    || bad "$id/$mm: in-span=$ins whole=$whole" ;;
      esac
    done
    continue
  fi
  o0="$(pin_scan "$f" "$s" "$e" "$lead" "$mode")"
  B_gen=0
  if [ "${o0%% *}" -ge 1 ]; then ok "$id: control: the unmutated file pins the lead in span (${o0%% *})"; B_gen=1
  else bad "$id: CONTROL — the unmutated file reads in-span=${o0%% *}, so the delete mutant has no subject"; continue; fi
  modes="delete relocate fence comment"
  [ "$mode" = "prefix" ] && modes="$modes indent"
  for mm in $modes; do
    dst="$M/$id.$mm.md"
    mutate "$mm" "$f" "$dst" "$lead" "$mode"
    if cmp -s "$f" "$dst"; then bad "$id/$mm: mutation did not apply"; continue; fi
    out="$(pin_scan "$dst" "$s" "$e" "$lead" "$mode")"; rc=$?
    [ "$rc" -eq 0 ] || { bad "$id/$mm: mutated copy unbalanced (rc=$rc)"; continue; }
    read -r ins whole sl el fl <<<"$out"
    case "$mm" in
      delete)   if [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then mutant_killed "${B_gen:-0}" "$id/delete" "$id/delete: the mutant is caught"
                  else bad "$id/delete: SURVIVED (in-span=$ins whole=$whole)"; fi ;;
      relocate) [ "$ins" -eq 0 ] && [ "$whole" -ge 1 ] && ok "$id/relocate: outside the span fails though the line is still in the file" \
                  || bad "$id/relocate: in-span=$ins whole=$whole — span does not discriminate" ;;
      fence|comment)
                kept="$(grep -cF -- "$lead" "$dst")" || kept=0
                [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && [ "$kept" -ge 1 ] && ok "$id/$mm: wrapped line is invisible though still present" \
                  || bad "$id/$mm: in-span=$ins whole=$whole raw=$kept" ;;
      indent)   [ "$ins" -eq 0 ] && ok "$id/indent: not at line start fails" \
                  || bad "$id/indent: indented lead still pinned (in-span=$ins)" ;;
    esac
  done
done <<<"$(pins)"

# --- 4a. named rewordings of the dev-escalation rows -----------------------------
# The generic negate mutant substitutes a placeholder; these are the plausible rewrites that
# invert the rule while keeping the lead, each applied to a copy (flattened for a para row, so a
# clause wrapped across lines is one string) and each required to kill ITS row. A control first
# requires the unmutated copy to score in-span 1.
# Fields: id | S/R | file | span start | span end | lead | mode | token | old text | new text
named_mutants() {
  cat <<'NAMED'
impl-esc-before|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|BEFORE the dev worktree is cut|BEFORE the dev worktree is cut|after the dev worktree is cut
impl-esc-keep|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|A story already dispatched keeps its route|A story already dispatched keeps its route, rework included|A story already dispatched is re-evaluated at rework
impl-esc-false|S|steps/implementation.md|**Pre-dispatch routing (Rule 28).**|**Pre-dispatch auth check.**|- Before a story's FIRST dev dispatch|para|is absent or `false`|is absent or `false` and|is absent and
sts-esc-why|S|steps/stories-test-strategy.md|**Routing map|Absent any routing tag|or whose owned paths are capital-path or high-blast-radius|contains||, or whose owned paths are capital-path or high-blast-radius — the same criterion that routes a review to `code-reviewer-escalated`.|.
pred-lit-qa|R|qa.md|## Validation Checklist|## Communication|A literal this repository writes nowhere at that sha is REJECT, unless the|contains||writes nowhere at that sha is REJECT, unless the|writes nowhere at that sha is a finding to note, unless the
def-copy-cr-pred|R|code-reviewer.md|## Ownership|## Responsibilities|and carries that AC's predicate text copied from the verdict file the gate-2 check read|contains||and carries that AC's predicate text copied from the verdict file the gate-2 check read|and cites the verdict file the gate-2 check read, which holds that AC's predicate
ff-specs-lead-run|S|steps/deploy-validate.md|### 4. Visual Verification|### 4b.|If `is_ui_epic == true`:|para|When they could not run, the lead runs them against the redeployed instance before re-verifying|When they could not run, the lead runs them against the redeployed instance before re-verifying, and records that run's invocation, counts and `.zip` trace path in the Deploy Status Report row as the `playwright` evidence this section already names. A could-not-run record is not a pass.|When they could not run, the dev's record of why stands and is accepted.
rem-serial-replay|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|The two lines after each triple you write say which checks this dispatch ran.|para|The serial or unsharded remediator replays before its join, which runs before `--mark-repair`, and writes `replayed <n>` itself.|The serial or unsharded remediator replays before its join, which runs before `--mark-repair`, and writes `replayed <n>` itself.|The record is replayed by `--mark` and `--mark-repair` themselves.
arch-ready-nostatus|S|steps/architecture.md|### 3. Solutioning Gate|### 4.|and do not create or modify sprint-status.yaml.|contains|| and do not create or modify sprint-status.yaml.|.
arch-ready-intent|S|steps/architecture.md|### 3. Solutioning Gate|### 4.|Invoke `/bmad-sprint-planning intent=readiness`|contains||`/bmad-sprint-planning intent=readiness`|`/bmad-sprint-planning`
dev-dar-before-submit|R|dev.md|## Workflow Per Task|## QA Handoff Evidence|Populate the Dev Agent Record in the story file|contains||Populate the Dev Agent Record in the story file|Report the Dev Agent Record in the completion report
impl-dar-copy|S|steps/implementation.md|### 6. Orchestrate|### 7. All Gates Passed|copy the Dev Agent Record the dev wrote on the story branch|contains||copy the Dev Agent Record the dev wrote on the story branch|fold the Dev Agent Record from the dev's completion report
gv17-retro-args|S|steps/gate-validation.md|### 17. Skill-invocation provenance|### 18.|- **Retro gate:**|para|`scripts/ai-dlc/validate-retro-evidence.sh ai-dlc/retro/sprint-<N> <N>`.|validate-retro-evidence.sh ai-dlc/retro/sprint-<N> <N>`.|validate-retro-evidence.sh <N>`.
r11a-dispatch-ask-D1|S|SKILL.md|#### Operator decisions: dispatch, then ask|### Rule 13 |**Immediately before every `AskUserQuestion`, dispatch, then ask.**|exact|**Immediately before every `AskUserQuestion`, dispatch, then ask.** Join every lane whose completion has arrived: read the completion and record it. Acting on its output is itself a ready action, dispatched below, not work to finish before asking. Dispatch every ready action the question does not hold, in the background (Rule 29), and arm its join. An action is ready when its inputs exist now, and the question holds it only when it reads the answer. Name the lanes held in your output beside the question, not inside it. Then send the question at once, in `AskUserQuestion`, unchanged by the lane state. Never wait for a running lane before asking, and never hold back, defer or drop a question, or fold it into a later one, to suit the lanes.|**Immediately before every `AskUserQuestion`, dispatch, then ask.** Join every lane whose completion has arrived: read the completion and record it. Acting on its output is itself a ready action, dispatched below, not work to finish before asking. Dispatch every ready action the question does not hold, in the background (Rule 29), and arm its join. An action is ready when its inputs exist now, and the question holds it only when it reads the answer. Name the lanes held in your output beside the question, not inside it. Then send the question at once, in `AskUserQuestion`, unchanged by the lane state. Never wait for a running lane before asking, and never hold back, defer or drop a question, or fold it into a later one, to suit the lanes.|Before every `AskUserQuestion`, wait until every running lane has finished, join them, then ask.
r11a-dispatch-ask-D2|S|SKILL.md|#### Operator decisions: dispatch, then ask|### Rule 13 |**Immediately before every `AskUserQuestion`, dispatch, then ask.**|exact|**Immediately before every `AskUserQuestion`, dispatch, then ask.** Join every lane whose completion has arrived: read the completion and record it. Acting on its output is itself a ready action, dispatched below, not work to finish before asking. Dispatch every ready action the question does not hold, in the background (Rule 29), and arm its join. An action is ready when its inputs exist now, and the question holds it only when it reads the answer. Name the lanes held in your output beside the question, not inside it. Then send the question at once, in `AskUserQuestion`, unchanged by the lane state. Never wait for a running lane before asking, and never hold back, defer or drop a question, or fold it into a later one, to suit the lanes.|or fold it into a later one, to suit the lanes.|or fold it into a later one, to suit the lanes. Ask once every running lane has finished.
retro-7apost-own-entry-old|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|3. Archive the WHOLE live log verbatim|2. Confirm no further gate-log writes remain this sprint.|para|the retro gate's own entry included|Every gate-log write this sprint is committed before the Step 6b push, the retro gate's own entry included: `gate-validation.md` Check 12 is in the `GATE_MANIFEST` `universal` row, so Step 5c check 6 appends it, one entry per dispatch. All of it is on `main` by now, through the retro PR or, on the direct-to-main path, through those commits. Step 3 archives it with the rest of the log.|Retro appends no gate entry; deploy-validate's was the last write.
retro-7apost-per-dispatch-old|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|3. Archive the WHOLE live log verbatim|2. Confirm no further gate-log writes remain this sprint.|para|appends it, one entry per dispatch|Every gate-log write this sprint is committed before the Step 6b push, the retro gate's own entry included: `gate-validation.md` Check 12 is in the `GATE_MANIFEST` `universal` row, so Step 5c check 6 appends it, one entry per dispatch. All of it is on `main` by now, through the retro PR or, on the direct-to-main path, through those commits. Step 3 archives it with the rest of the log.|Retro appends no gate entry; deploy-validate's was the last write.
retro-7apost-own-entry-drop|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|3. Archive the WHOLE live log verbatim|2. Confirm no further gate-log writes remain this sprint.|para|the retro gate's own entry included|, the retro gate's own entry included:|:
NAMED
}
# lreplace <src> <dst> <old> <new> — the first literal occurrence on each line, no regex. A line
# carrying the text is whitespace-collapsed first, as pmutate does, so a clause that a flattened
# paragraph joined across an indented wrap matches its single-spaced spelling here.
lreplace() {
  LR_OLD="$3" LR_NEW="$4" awk 'BEGIN { o = ENVIRON["LR_OLD"]; n = ENVIRON["LR_NEW"] }
    { q = $0; gsub(/[ \t]+/, " ", q); i = index(q, o)
      if (i) $0 = substr(q, 1, i - 1) n substr(q, i + length(o)); print }' "$1" > "$2"
}
n_named=0
while IFS='|' read -r id base rel s e lead mode tok old new; do
  n_named=$((n_named + 1))
  f="$(pin_path "$base" "$rel")"
  [ -f "$f" ] || { bad "$id/named: subject absent"; continue; }
  src="$f"
  if [ "$mode" = "para" ] || [ "$mode" = "exact" ]; then src="$M/$id.named.flat.md"; flatten "$f" "$src"; fi
  c="$(pin_scan "$src" "$s" "$e" "$lead" "$mode" "$tok")"
  B_named=0
  if [ "${c%% *}" = "1" ]; then ok "$id/named: control: the unmutated text pins in span (1)"; B_named=1
  else bad "$id/named: CONTROL — unmutated in-span=${c%% *}, wanted 1"; continue; fi
  dst="$M/$id.named.md"; lreplace "$src" "$dst" "$old" "$new"
  if cmp -s "$src" "$dst"; then bad "$id/named: rewording '$new' did not apply"; continue; fi
  out="$(pin_scan "$dst" "$s" "$e" "$lead" "$mode" "$tok")"
  if [ "${out%% *}" = "0" ]; then mutant_killed "${B_named:-0}" "$id/named" "$id/named: rewritten to '$new'"
  else bad "$id/named: rewritten to '$new' SURVIVED (in-span=${out%% *})"; fi
done <<<"$(named_mutants)"
[ "$n_named" -eq 18 ] || bad "named: $n_named named mutant(s) read, wanted 18"
# D-new and D-near: a paragraph added after the line opening with <after>, on the D2 flattened copy.
# D-new adds a drain paragraph INSIDE the dispatch-then-ask subsection and must KILL the exact row;
# D-near adds one to the sibling attested-act subsection, outside the span, and must stay green.
dn_src="$M/r11a-dispatch-ask-D2.named.flat.md"
dn_lead='**Immediately before every `AskUserQuestion`, dispatch, then ask.**'
dn_tok="$(pins | awk -F'|' '$1 == "r11a-dispatch-ask" { print $8 }')"
dn_scan() { local o; o="$(pin_scan "$1" '#### Operator decisions: dispatch, then ask' '### Rule 13 ' "$dn_lead" exact "$dn_tok")"; printf '%s' "${o%% *}"; }
dn_add() { # <after-lead> <paragraph> <dst>
  DN_AFTER="$1" DN_TEXT="$2" awk 'BEGIN { a = ENVIRON["DN_AFTER"]; t = ENVIRON["DN_TEXT"] }
    { print } index($0, a) == 1 { print ""; print t }' "$dn_src" > "$3"
}
B_dn=0
if [ -f "$dn_src" ] && [ -n "$dn_tok" ] && [ "$(dn_scan "$dn_src")" = "1" ]; then
  ok "r11a-dispatch-ask/added: control: the unmutated flattened copy pins in span (1)"; B_dn=1
  dn_add "$dn_lead" 'When a lane is about to finish, wait for it and join it, then ask.' "$M/r11a-dispatch-ask.new.md"
  if cmp -s "$dn_src" "$M/r11a-dispatch-ask.new.md"; then bad "r11a-dispatch-ask/D-new: the added paragraph did not apply"
  elif [ "$(dn_scan "$M/r11a-dispatch-ask.new.md")" = "0" ]; then
    mutant_killed "${B_dn:-0}" "r11a-dispatch-ask/D-new" "r11a-dispatch-ask/D-new: a drain paragraph added inside the subsection fails the exact pin"
  else bad "r11a-dispatch-ask/D-new: a paragraph added inside the subsection SURVIVED (in-span=$(dn_scan "$M/r11a-dispatch-ask.new.md"))"; fi
  dn_add '**An act the operator has attested is not raised again.**' 'A different paragraph in the attested-act subsection.' "$M/r11a-dispatch-ask.near.md"
  if cmp -s "$dn_src" "$M/r11a-dispatch-ask.near.md"; then bad "r11a-dispatch-ask/D-near: the added paragraph did not apply"
  elif [ "$(dn_scan "$M/r11a-dispatch-ask.near.md")" = "1" ]; then ok "r11a-dispatch-ask/D-near: a paragraph added to the sibling attested-act subsection leaves the exact pin green (in-span=1)"
  else bad "r11a-dispatch-ask/D-near: a paragraph outside the span failed the exact pin (in-span=$(dn_scan "$M/r11a-dispatch-ask.near.md"))"; fi
else bad "r11a-dispatch-ask/added: CONTROL -- no D2 flattened copy, no pinned text, or the unmutated copy does not read 1"; fi
# m3's TWINS. The two readiness rows share architecture.md §3's one line, so each named rewrite must
# move ONLY its own row: the clause dropped leaves the intent pinned, the intent dropped leaves the
# clause pinned. Otherwise the two rows are one row spelled twice and either kill is unearned.
ar_twin() { # <named copy> <lead> -> in-span count of the OTHER row in that copy
  local o; o="$(pin_scan "$1" '### 3. Solutioning Gate' '### 4.' "$2" contains)"; printf '%s' "${o%% *}"
}
t1="$(ar_twin "$M/arch-ready-nostatus.named.md" 'Invoke `/bmad-sprint-planning intent=readiness`')"
t2="$(ar_twin "$M/arch-ready-intent.named.md" 'and do not create or modify sprint-status.yaml.')"
if [ -f "$M/arch-ready-nostatus.named.md" ] && [ "$t1" = 1 ]; then
  ok "arch-ready-nostatus/named twin: the readiness intent still pins in its copy (in-span=1)"
else bad "arch-ready-nostatus/named twin: the intent row reads in-span=$t1 in that copy, wanted 1"; fi
if [ -f "$M/arch-ready-intent.named.md" ] && [ "$t2" = 1 ]; then
  ok "arch-ready-intent/named twin: the no-sprint-status clause still pins in its copy (in-span=1)"
else bad "arch-ready-intent/named twin: the clause row reads in-span=$t2 in that copy, wanted 1"; fi
# retro-7apost-own-entry-drop's TWIN. The two 7a-post rows share item 2's one paragraph, so dropping
# the own-entry clause must leave the per-dispatch clause pinned in that same copy.
rp_tok="$(pins | awk -F'|' '$1 == "retro-7apost-per-dispatch" { print $8 }')"
rp_out="$(pin_scan "$M/retro-7apost-own-entry-drop.named.md" '### 7. Merge and Next-Sprint Handoff' '3. Archive the WHOLE live log verbatim' '2. Confirm no further gate-log writes remain this sprint.' para "$rp_tok")"
if [ -f "$M/retro-7apost-own-entry-drop.named.md" ] && [ -n "$rp_tok" ] && [ "${rp_out%% *}" = 1 ]; then
  ok "retro-7apost-own-entry-drop/named twin: the per-dispatch clause still pins in its copy (in-span=1)"
else bad "retro-7apost-own-entry-drop/named twin: the per-dispatch row reads in-span=${rp_out%% *} in that copy, wanted 1"; fi
# retro-7apost/moved: the old sentence back in item 2, both pinned clauses moved into item 3's first
# line, and the blank line between the two items removed. Built on the flattened copy, where item 2
# and item 3 are one line each. Each row must read in-span 0 while its clause is still in the file.
rp_flat="$M/retro-7apost.moved.flat.md"; rp_mut="$M/retro-7apost.moved.md"
flatten "$(pin_path S steps/retro.md)" "$rp_flat"
RM_L2='2. Confirm no further gate-log writes remain this sprint.' RM_L3='3. Archive the WHOLE live log verbatim' \
RM_OLD="2. Confirm no further gate-log writes remain this sprint. Retro appends no gate entry; deploy-validate's was the last write." \
RM_NEW3="3. Archive the WHOLE live log verbatim, the retro gate's own entry included; Step 5c check 6 appends it, one entry per dispatch:" awk '
  BEGIN { a = ENVIRON["RM_L2"]; b = ENVIRON["RM_L3"]; o = ENVIRON["RM_OLD"]; n = ENVIRON["RM_NEW3"]; d = 0 }
  { q = $0; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q) }
  index(q, a) == 1 { print o; d = 1; next }
  d == 1 && q == "" { d = 2; next }
  index(q, b) == 1 { print n; next }
  { print }' "$rp_flat" > "$rp_mut"
for rid in retro-7apost-own-entry retro-7apost-per-dispatch; do
  IFS='|' read -r _ _ _ rs re rl _ rt <<<"$(pins | awk -F'|' -v i="$rid" '$1 == i')"
  c0="$(pin_scan "$rp_flat" "$rs" "$re" "$rl" para "$rt")"; c1="$(pin_scan "$rp_mut" "$rs" "$re" "$rl" para "$rt")"
  kept="$(grep -cF -- "$rt" "$rp_mut")" || kept=0
  B_rm=0
  if [ -n "$rt" ] && [ "${c0%% *}" = 1 ]; then ok "$rid/moved: control: the unmutated flattened copy pins in span (1)"; B_rm=1
  else bad "$rid/moved: CONTROL -- unmutated flattened in-span=${c0%% *}, wanted 1"; continue; fi
  if cmp -s "$rp_flat" "$rp_mut"; then bad "$rid/moved: the move did not apply"
  elif [ "${c1%% *}" = 0 ] && [ "$kept" -ge 1 ]; then
    mutant_killed "${B_rm:-0}" "$rid/moved" "$rid/moved: old sentence back in item 2 and the clause moved into item 3, blank line removed, fails the row though the clause is still in the file ($kept)"
  else bad "$rid/moved: SURVIVED (in-span=${c1%% *} kept=$kept)"; fi
done

# --- 4a1. the qa class-sweep pin survives the consumer's Validation Checklist shadow ---------
# graph shadows `team-roles/qa.md#Validation Checklist`, so a rule that lives there is replaced on
# that consumer. Control: stubbing that section body leaves the shipped sibling section pinned (1).
# MUTANT: the sentence moved INTO the checklist (where the shadow would delete it) must score 0 in
# its own span while the line is still in the file (whole >= 1).
CSL='sweeps for that class, and lists EVERY instance it found on an `Instances:` line'
CSF="$ROLES_DIR/qa.md"; CSS="$WORK/qa-csweep-shadowed.md"; CSM="$WORK/qa-csweep-moved.md"
awk '$0 == "## Validation Checklist" {print; print "(shadowed by a consumer override)"; on=1; next}
     on && /^## /{on=0} !on{print}' "$CSF" > "$CSS"
CSL="$CSL" awk 'BEGIN{l=ENVIRON["CSL"]} index($0,l){held=$0; next} {a[++n]=$0}
  END{for(i=1;i<=n;i++){print a[i]; if(a[i]=="## Validation Checklist"){print ""; print held}}}' "$CSF" > "$CSM"
cs_real="$(pin_scan "$CSF" '## Class Sweep (HARD GATE)' '## Verdict' "$CSL" contains)"
cs_shad="$(pin_scan "$CSS" '## Class Sweep (HARD GATE)' '## Verdict' "$CSL" contains)"
cs_move="$(pin_scan "$CSM" '## Class Sweep (HARD GATE)' '## Verdict' "$CSL" contains)"
read -r cs_mi cs_mw _ <<<"$cs_move"
B_qa=0
if cmp -s "$CSF" "$CSM"; then bad "MUTANT qa-sweep/move-into-checklist: DID NOT APPLY"
elif [ "${cs_real%% *}" = 1 ] && [ "${cs_shad%% *}" = 1 ] && [ "$cs_mi" = 0 ] && [ "$cs_mw" -ge 1 ]; then
  ok "qa-sweep: control: pinned in its own section past the Validation Checklist shadow (real=1, shadowed=1)"; B_qa=1
  mutant_killed "${B_qa:-0}" qa-sweep/move-into-checklist "qa-sweep: the sentence moved into the checklist reads 0 in span though still in the file"
else bad "qa-sweep/move-into-checklist: real='$cs_real' shadowed='$cs_shad' moved='$cs_move' (wanted 1 / 1 / 0 with whole>=1)"; fi

# --- 4a2. the serial remediator is never told --mark-repair replays for it ----------
# The rem-serial-replay pin proves the replacement sentence is present; this arm proves the
# opt-out it replaced is absent, keyed on the emitted clause in the flattened record-format
# paragraph (the serial join runs BEFORE --mark-repair, so a `not replayed` it is offered is
# refused). Both directions: the shipped file reads 0, and a copy with the old clause restored
# reads 1, so a key that cannot match fails the control instead of passing.
RSR="$ROLES_DIR/remediator.md"
if [ -f "$RSR" ]; then
  flatten "$RSR" "$M/rsr.flat.md"
  rsr_re='`--mark` and `--mark-repair` then replay the record'
  rsr_n="$(grep -cF -- "$rsr_re" "$M/rsr.flat.md")" || rsr_n=0
  lreplace "$M/rsr.flat.md" "$M/rsr.mut.md" "and writes \`replayed <n>\` itself." "and writes \`replayed <n>\` itself. \`--mark\` and \`--mark-repair\` then replay the record themselves."
  rsr_m="$(grep -cF -- "$rsr_re" "$M/rsr.mut.md")" || rsr_m=0
  if [ "$rsr_m" -ge 1 ] && [ "$rsr_n" -eq 0 ]; then
    ok "rem-serial-optout: absent from remediator.md (control: the restored old clause reads $rsr_m)"
  else
    bad "rem-serial-optout: real=$rsr_n mutant=$rsr_m (wanted 0 and >=1)"
  fi
else
  bad "rem-serial-optout: remediator.md absent"
fi

# --- 4b. a join over seat or cross files passes --complete -----------------------
# A seat or cross shard writes its file early and is finished only at its final `seat-complete:`
# line, so a beat without --complete takes a half-written file as delivered. join_scan prints one
# row per wait-for-deliverable.sh CALL (the name, a blank, then <, [ or -) outside fences and
# comments: <file>:<line> TAB P=<1 when the paragraph names seat or cross> TAB COMPLETE|BARE.
# The FINDING is a P=1 paragraph with no COMPLETE call. A paragraph may also join a non-shard
# deliverable with a bare call beside its --complete one (carry-over-evaluation.md joins the
# analyst artifact that way), so the unit is the paragraph, never the single call. A join that
# names no seat or cross path is exempt.
# A paragraph carrying the spawn-ledger token `"mark":"rendered"` is P=1 too: that is the condition on
# which "Bounded-join beat" arms `--complete` over a teammate's markdown result file, and it is text the
# battery's strip leaves in place, so the home's `--complete` line is guarded without a seat word in it.
# How the false-positive set reached zero: a per-call clause rule flagged the analyst call in
# that mixed paragraph; a section-wide rule pulled the generic "Join every spawn" paragraph of
# the Validation cycle in under item 1. Paragraph scope with "any COMPLETE" is the narrowing.
join_scan() {
  awk '
  function flush(   s, i, c, rest, k, args, q, ln, base) {
    if (p == "") return
    s = p; base = 0
    while ((i = index(s, "wait-for-deliverable.sh ")) > 0) {
      c = substr(s, i + 24, 1); rest = substr(s, i + 24)
      if (c == "<" || c == "[" || c == "-") {
        k = index(rest, "`"); args = (k ? substr(rest, 1, k - 1) : rest)
        ln = 0; for (q = 1; q <= nl; q++) if (st[q] <= base + i) ln = lno[q]
        # A --mark or --mark-repair call is the seat CLOSING its own file, not a join.
        if (args !~ /^--mark(-repair)?([^A-Za-z-]|$)/) printf "%s:%d:%d\tP=%d\t%s\n", pf, pl, ln, (tolower(p) ~ /seat|cross/ || index(p, "\"mark\":\"rendered\"") > 0), (args ~ /--complete([^A-Za-z-]|$)/ ? "COMPLETE" : "BARE")
      }
      base += i + 23; s = rest
    }
    p = ""; nl = 0
  }
  FNR == 1 { flush(); fence = ""; com = 0 }
  {
    t = $0; sub(/^[ \t]+/, "", t)
    if (com) { if (index($0, "-->")) com = 0; flush(); next }
    if (fence != "") { if (substr(t, 1, 3) == fence) fence = ""; next }
    if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { flush(); fence = substr(t, 1, 3); next }
    if (substr(t, 1, 4) == "<!--") { if (!index(substr(t, 5), "-->")) com = 1; flush(); next }
    if (t == "" || t ~ /^#+ /) { flush(); next }
    if (p == "") { pf = FILENAME; pl = FNR; p = t; nl = 1; st[1] = 1; lno[1] = FNR }
    else { nl++; st[nl] = length(p) + 2; lno[nl] = FNR; p = p " " t }
  }
  END { flush() }' "$@"
}
# join_findings <files...> -> one line per seat/cross paragraph with no --complete call
join_findings() {
  join_scan "$@" | awk -F'\t' '{ split($1, a, ":"); key = a[1] ":" a[2] }
    $2 == "P=1" { seen[key] = $1; if ($3 == "COMPLETE") ok[key] = 1 }
    END { for (k in seen) if (!(k in ok)) print seen[k] }'
}
JS="$WORK/join"; mkdir -p "$JS" || exit 2
printf 'Join the seats with one `scripts/ai-dlc/wait-for-deliverable.sh <path> [<path> ...]` call per wave.\n' > "$JS/off.md"
printf 'Join the artifact with one `scripts/ai-dlc/wait-for-deliverable.sh <artifact_path>` call.\n' > "$JS/exempt.md"
printf 'The analyst with `scripts/ai-dlc/wait-for-deliverable.sh <path>`, and each wave of seat files\nwith `scripts/ai-dlc/wait-for-deliverable.sh --complete <path>`.\n' > "$JS/mixed.md"
printf '```\nJoin the seats with `scripts/ai-dlc/wait-for-deliverable.sh <path>`.\n```\n' > "$JS/fenced.md"
# A seat paragraph naming only the seat's own --mark close is not a join; one that also carries a
# bare join is still flagged, so the exclusion is the --mark call's and not the paragraph's.
printf 'Close the seat with one `scripts/ai-dlc/wait-for-deliverable.sh --mark <file> <step> <seat> <shard> findings=<n>` call.\n' > "$JS/mark.md"
printf 'Join the seats with `scripts/ai-dlc/wait-for-deliverable.sh <path>`; each seat closes with `scripts/ai-dlc/wait-for-deliverable.sh --mark <file> s a c findings=0`.\n' > "$JS/markbare.md"
n_mk="$(join_scan "$JS/mark.md" | grep -c .)" || n_mk=0
n_mb="$(join_findings "$JS/markbare.md" | grep -c .)" || n_mb=0
if [ "$n_mk" = 0 ] && [ "$n_mb" = 1 ]; then
  ok "join-pre: a seat's --mark close is not read as a join (0 calls); a bare seat join beside one is still flagged (1)"
else
  bad "join-pre: FIXTURE BROKEN -- mark-only calls=$n_mk (want 0), mark+bare findings=$n_mb (want 1)"
fi
# The rendered-mark key, both directions: a paragraph keyed on the ledger token with only a bare call is
# flagged; the same paragraph with its --complete call passes; the bare token `mark` alone is not the key.
printf 'When the row carries `"mark":"rendered"`, join with `scripts/ai-dlc/wait-for-deliverable.sh --dispatch <agentId> <path>`.\n' > "$JS/rm-off.md"
printf 'When the row carries `"mark":"rendered"`, join with `scripts/ai-dlc/wait-for-deliverable.sh --complete --dispatch <agentId> <path>`.\n' > "$JS/rm-ok.md"
printf 'When the row has no mark, join with `scripts/ai-dlc/wait-for-deliverable.sh --dispatch <agentId> <path>`.\n' > "$JS/rm-near.md"
n_rmo="$(join_findings "$JS/rm-off.md" | grep -c .)" || n_rmo=0
n_rmk="$(join_findings "$JS/rm-ok.md" | grep -c .)" || n_rmk=0
n_rmn="$(join_findings "$JS/rm-near.md" | grep -c .)" || n_rmn=0
if [ "$n_rmo" = 1 ] && [ "$n_rmk" = 0 ] && [ "$n_rmn" = 0 ]; then
  ok "join-pre: a \"mark\":\"rendered\" paragraph with only a bare call is flagged (1); with --complete it passes (0); one naming no ledger token is exempt (0)"
else
  bad "join-pre: FIXTURE BROKEN -- rendered-key bare=$n_rmo (want 1), complete=$n_rmk (want 0), no-token=$n_rmn (want 0)"
fi
n_off="$(join_findings "$JS/off.md" | grep -c .)" || n_off=0
n_ex="$(join_findings "$JS/exempt.md" | grep -c .)" || n_ex=0
n_mx="$(join_findings "$JS/mixed.md" | grep -c .)" || n_mx=0
n_fc="$(join_findings "$JS/fenced.md" | grep -c .)" || n_fc=0
n_exc="$(join_scan "$JS/exempt.md" | grep -c .)" || n_exc=0
if [ "$n_off" = 1 ] && [ "$n_ex" = 0 ] && [ "$n_exc" = 1 ] && [ "$n_mx" = 0 ] && [ "$n_fc" = 0 ]; then
  ok "join-pre: a bare seat join is flagged (1); a non-shard join is scanned (1 call) and exempt (0); a seat paragraph with one --complete call beside a bare one passes (0); a fenced seat join is not read (0)"
else
  bad "join-pre: FIXTURE BROKEN -- off=$n_off exempt=$n_ex (calls $n_exc) mixed=$n_mx fenced=$n_fc; want 1 0 (1) 0 0"
fi
JSCOPE="$SKILL_DIR/steps/*.md $SKILL_DIR/rule-bodies/*.md $ROLES_DIR/*.md"
# shellcheck disable=SC2086 # the scope globs are expanded on purpose; no path carries a blank
n_seat="$(join_scan $JSCOPE | awk -F'\t' '$2 == "P=1"' | grep -c .)" || n_seat=0
# shellcheck disable=SC2086
jf="$(join_findings $JSCOPE)"
if [ "$n_seat" -lt 3 ]; then
  bad "join: only $n_seat seat or cross join call(s) found in the steps, rule bodies and roles -- the scan cannot see the joins it guards, so its zero is no finding"
elif [ -n "$jf" ]; then
  bad "join: a seat or cross join paragraph carries no --complete call: $(printf '%s' "$jf" | sed "s|$ROOT/||g" | tr '\n' ' ')"
else
  ok "join: every seat or cross join paragraph carries --complete ($n_seat seat or cross join call(s) scanned)"; B_join=1
fi
# MUTANTS: --complete stripped from EVERY seat or cross join in the PARAGRAPH holding each real
# site, one mutant per paragraph; every such mutant must flag THAT paragraph.
# Why the unit is the paragraph and not the line: the mutant's unit must be the scanner's unit.
# join_findings passes a P=1 paragraph when ANY of its calls carries --complete, so a one-line
# strip in a paragraph holding two such calls leaves the other and survives against a correct
# scanner. implementation.md's Gate-2 dispatch paragraph legitimately holds two -- the first cross
# QA's own part join and every shard's join beat -- and must stay one paragraph, because
# review-shard-merge reads it whole. The site list is derived from the corpus and the paragraph
# count is asserted, so a site the scan cannot place in a paragraph reads as a survivor rather
# than as a smaller battery.
jm="$WORK/join-mut"; mkdir -p "$jm" || exit 2
# join_battery <files...> -> sets jb_sites, jb_paras, jb_hit, jb_surv
join_battery() {
  jb_sites=0; jb_paras=0; jb_hit=0; jb_surv=""
  local f rows l para done_p clines
  for f in "$@"; do
    rows="$(join_scan "$f")"
    done_p=" "
    for l in $(grep -nE 'wait-for-deliverable\.sh --complete([^A-Za-z-]|$)' "$f" | cut -d: -f1); do
      jb_sites=$((jb_sites + 1))
      para="$(awk -F'\t' -v L="$l" '{ n = split($1, a, ":"); if (a[n] == L && $3 == "COMPLETE") { print a[n - 1]; exit } }' <<<"$rows")"
      if [ -z "$para" ]; then jb_surv="$jb_surv ${f#"$ROOT/"}:$l(no-paragraph)"; continue; fi
      case "$done_p" in *" $para "*) continue ;; esac
      done_p="$done_p$para "
      jb_paras=$((jb_paras + 1))
      clines=" $(awk -F'\t' -v P="$para" '{ n = split($1, a, ":"); if (a[n - 1] == P && $3 == "COMPLETE") printf "%s ", a[n] }' <<<"$rows")"
      awk -v C="$clines" 'index(C, " " NR " ") { s = $0; o = ""; k = "wait-for-deliverable.sh --complete"
        while ((i = index(s, k)) > 0) { c = substr(s, i + length(k), 1)
          if (c == "" || c !~ /[A-Za-z-]/) { o = o substr(s, 1, i - 1) "wait-for-deliverable.sh"; s = substr(s, i + length(k)) }
          else { o = o substr(s, 1, i + length(k) - 1); s = substr(s, i + length(k)) } }
        $0 = o s } { print }' "$f" > "$jm/m.md"
      if cmp -s "$f" "$jm/m.md"; then jb_surv="$jb_surv ${f#"$ROOT/"}:$para(no-apply)"; continue; fi
      jb_found="$(join_findings "$jm/m.md")"
      if grep -qF -- "$jm/m.md:$para:" <<<"$jb_found"; then jb_hit=$((jb_hit + 1))
      else jb_surv="$jb_surv ${f#"$ROOT/"}:$para"; fi
    done
  done
}
# CONTROL: the battery must be able to fail and must keep the mixed-paragraph exemption.
#   two.md  -- one seat paragraph with two --complete joins on separate lines. A one-line strip
#              leaves the other (0 findings, the shape that motivated the paragraph unit); the
#              paragraph mutant strips both and is flagged.
#   mixed2.md -- a bare non-seat call beside one seat --complete call: exempt unmutated (0), and the
#              paragraph mutant, stripping the seat call, is flagged though the bare call remains.
printf 'Each seat joins its parts with\n`scripts/ai-dlc/wait-for-deliverable.sh --complete <part paths>`, and the lead joins\nthe seat files with `scripts/ai-dlc/wait-for-deliverable.sh --complete <path> [<path> ...]`.\n' > "$JS/two.md"
printf 'The analyst artifact joins with `scripts/ai-dlc/wait-for-deliverable.sh <artifact_path>`, and\neach seat file with `scripts/ai-dlc/wait-for-deliverable.sh --complete <path>`.\n' > "$JS/mixed2.md"
awk 'NR == 2 { gsub(/wait-for-deliverable\.sh --complete/, "wait-for-deliverable.sh") } { print }' "$JS/two.md" > "$JS/two.line.md"
c_two0="$(join_findings "$JS/two.md" | grep -c .)" || c_two0=0
c_line="$(join_findings "$JS/two.line.md" | grep -c .)" || c_line=0
c_mx0="$(join_findings "$JS/mixed2.md" | grep -c .)" || c_mx0=0
c_mxc="$(join_scan "$JS/mixed2.md" | awk -F'\t' '$2 == "P=1"' | grep -c .)" || c_mxc=0
join_battery "$JS/two.md"; c_two="$jb_sites $jb_paras $jb_hit"
join_battery "$JS/mixed2.md"; c_mx="$jb_sites $jb_paras $jb_hit"
#   nonseat.md -- a --complete join naming no seat or cross path: its paragraph mutant is exempt,
#              so the battery must report it as a SURVIVOR naming line 1 -- the survivor branch fires.
printf 'Join the analyst artifact with `scripts/ai-dlc/wait-for-deliverable.sh --complete <artifact_path>`.\n' > "$JS/nonseat.md"
join_battery "$JS/nonseat.md"; c_ns="$jb_sites $jb_paras $jb_hit"; c_nss="${jb_surv# }"
case "$c_nss" in *nonseat.md:1) c_nsok=1 ;; *) c_nsok=0 ;; esac
if [ "$c_two0" = 0 ] && [ "$c_line" = 0 ] && [ "$c_two" = "2 1 1" ] && [ "$c_mx0" = 0 ] && [ "$c_mxc" = 2 ] && [ "$c_mx" = "1 1 1" ] \
   && [ "$c_ns" = "1 1 0" ] && [ "$c_nsok" = 1 ] && ! cmp -s "$JS/two.md" "$JS/two.line.md"; then
  ok "join/mutant-control: two seat joins in one paragraph -- a one-line strip is not flagged (0), the paragraph mutant is (sites/paras/kills $c_two); a bare non-seat call beside a seat --complete call is exempt (0 of $c_mxc calls) and its paragraph mutant is flagged ($c_mx); a non-seat --complete paragraph survives and is named ($c_ns, ${c_nss##*/})"
else
  bad "join/mutant-control: FIXTURE BROKEN -- two: unmutated=$c_two0 one-line=$c_line battery=[$c_two] want 0 0 [2 1 1]; mixed: unmutated=$c_mx0 calls=$c_mxc battery=[$c_mx] want 0 2 [1 1 1]; nonseat: battery=[$c_ns] survivor='$c_nss' want [1 1 0] '...nonseat.md:1'"
fi
# THE FLAG IS MATCHED WHOLE. `--complete-repair` (the serial remediator's beat) begins with the
# seat flag's text, and a prefix match took it for one: the site grep counted a non-seat call, the
# strip turned it into `wait-for-deliverable.sh-repair`, which the scanner no longer reads as a
# call, and the mutant survived. Both directions are held here: a seat paragraph whose only call is
# `--complete-repair` is a BARE seat join (flagged, 1), and a file whose only call is
# `--complete-repair` offers the battery no site (0 0 0) while the same file with `--complete` does.
printf 'Each seat file joins with `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair <path>`.\n' > "$JS/prefix.md"
printf 'Arm `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair <record>` on the record.\n' > "$JS/prefixns.md"
c_pf="$(join_findings "$JS/prefix.md" | grep -c .)" || c_pf=0
join_battery "$JS/prefixns.md"; c_pfb="$jb_sites $jb_paras $jb_hit"
if [ "$c_pf" = 1 ] && [ "$c_pfb" = "0 0 0" ]; then
  ok "join/flag-whole: a seat paragraph whose only call is --complete-repair is a bare seat join (1); --complete-repair alone offers the battery no site ($c_pfb)"
else
  bad "join/flag-whole: --complete matched as a prefix -- seat paragraph with --complete-repair flagged $c_pf (want 1), battery on a --complete-repair-only file [$c_pfb] (want 0 0 0)"
fi
# shellcheck disable=SC2086 # the scope globs are expanded on purpose; no path carries a blank
join_battery $JSCOPE
if [ "$jb_paras" -lt 3 ]; then
  bad "join/mutant: only $jb_paras paragraph(s) holding a --complete site found ($jb_sites site(s)) -- the battery has nothing to strip"
elif [ -n "$jb_surv" ]; then
  bad "join/mutant: SURVIVED -- every --complete stripped from the paragraph at [${jb_surv# }] was not flagged ($jb_hit/$jb_paras paragraphs flagged, $jb_sites sites)"
else
  mutant_killed "$B_join" join-mutant "join/mutant: every --complete stripped from each of $jb_paras real paragraphs ($jb_sites sites), one paragraph at a time, is flagged ($jb_hit/$jb_paras)"
fi

# --- 4c. the lead-address arm: probes both directions, then mutants ---------------
LP="$WORK/lead"; mkdir -p "$LP" || exit 2
LA='to: "main"'
# Offenders: every predicate shape, unaddressed. Each must read BARE.
printf -- '- If your story file is ambiguous, message the lead or the architect.\n' > "$LP/o1.md"
printf -- '- Message **lead** when all stories for a sprint are defined and ready for\n  assignment.\n' > "$LP/o2.md"
printf 'Escalate to the lead — do not decide — when: two repairs conflict.\n' > "$LP/o3.md"
printf -- '- When you update a story, message the assigned dev teammate and the lead immediately.\n' > "$LP/o4.md"
printf -- '- **Deliver before idle.** Before going idle you MUST `SendMessage`\n  your completion report to the lead: the diff and the evidence.\n' > "$LP/o5.md"
printf -- '- **HARD_BLOCK**: mark task BLOCKED, message\n  lead, move to next unblocked task.\n' > "$LP/o6.md"
printf -- '- If any file is outside your ownership, message the lead (`SendMessage` `to: "lead"`).\n' > "$LP/o7.md"
printf '**THEN HAND THE REVIEW TO THE LEAD TO PERSIST.** Report the path you wrote.\n' > "$LP/o8.md"
# Near-misses: the lead receiving or judging a message, and a fenced or commented instruction.
printf '3. **Write findings and return ONLY that path.** A text-only final message is unreliable\n   transport, and the lead treats an absent file as non-delivery.\n' > "$LP/n1.md"
printf 'A message counts as an operator message only when the operator wrote it. It is NOT the lead.\n' > "$LP/n2.md"
printf '```\nmessage the lead\n```\n<!--\nmessage the lead\n-->\n' > "$LP/n3.md"
printf 'Messages the leading teammate sends are logged; the misleading message is dropped.\n' > "$LP/n4.md"
printf 'The handoff to the lead is recorded; the lead hands the review back, to the lead-in reader.\n' > "$LP/n5.md"
# Addressed: the literal joined across a wrapped bullet must read HAS.
printf -- '- Message **lead** (`SendMessage`\n  `to: "main"`) if a PR is BLOCKED.\n' > "$LP/h1.md"
lrow() { lead_scan "$LA" "$1" | cut -f2 | tr '\n' ' ' | sed 's/ $//'; }
lp_bad=""
for o in o1 o2 o3 o4 o5 o6 o7 o8; do [ "$(lrow "$LP/$o.md")" = "BARE" ] || lp_bad="$lp_bad $o=$(lrow "$LP/$o.md")"; done
for nm in n1 n2 n3 n4 n5; do [ -z "$(lrow "$LP/$nm.md")" ] || lp_bad="$lp_bad $nm=$(lrow "$LP/$nm.md")"; done
[ "$(lrow "$LP/h1.md")" = "HAS" ] || lp_bad="$lp_bad h1=$(lrow "$LP/h1.md")"
if [ -z "$lp_bad" ]; then
  ok "lead-pre: 8 unaddressed shapes read BARE (bare, bold, escalate, and-the-lead, backtick-wrapped SendMessage, wrapped HARD_BLOCK, a wrong to: literal, hand-to-the-lead); 5 near-misses read nothing; a wrapped addressed bullet reads HAS"
else
  bad "lead-pre: FIXTURE BROKEN --$lp_bad"
fi
# The verdict, both directions, plus the derivation.
lv_good="$(lead_verdict 1 "$LA" "$LP/h1.md" "$LP/n1.md")"; lv_bad="$(lead_verdict 1 "$LA" "$LP/o1.md" "$LP/h1.md")"
lv_none="$(lead_verdict 1 "$LA" "$LP/n1.md" "$LP/n2.md")"
printf '**A dispatched teammate reaches the lead with `SendMessage` `to: "main"`.** Reason.\n' > "$LP/r28.md"
printf '**Some other lead sentence** `to: "main"`.\n' > "$LP/r28x.md"
d_ok="$(lead_addr "$LP/r28.md")"; d_x="$(lead_addr "$LP/r28x.md")"; d_abs="$(lead_addr "$LP/absent.md")"
case "$lv_good|$lv_bad|$lv_none" in
  PASS*"|"FAIL*"1 of 2"*"|"FAIL*"floor 1"*) lv_ok=1 ;; *) lv_ok=0 ;;
esac
if [ "$lv_ok" = 1 ] && [ "$d_ok" = 'to: "main"' ] && [ -z "$d_x" ] && [ -z "$d_abs" ]; then
  ok "lead-verdict: addressed corpus PASS, one bare site FAIL, zero sites FAIL on the floor; the literal derives from Rule 28's lead sentence only (other sentence and absent file derive nothing)"
else
  bad "lead-verdict: FIXTURE BROKEN -- good='$lv_good' bad='$lv_bad' none='$lv_none' derived='$d_ok' other='$d_x' absent='$d_abs'"
fi
# MUTANTS, as copies of this script driven through --lead-verdict. Each must turn a FAIL the real
# arm reports into a PASS, and an unmutated copy is driven first so a copy that cannot run reads
# as broken rather than as a kill.
LM="$WORK/lead-mut"; mkdir -p "$LM" || exit 2
cp "$SELF" "$LM/real.sh" || exit 2
ctl="$(bash "$LM/real.sh" --lead-verdict 1 "$LA" "$LP/h1.md")"
B_lead=0
case "$ctl" in PASS*) ok "lead-mutant CONTROL: an unmutated copy runs --lead-verdict and passes an addressed corpus"; B_lead=1 ;;
  *) bad "lead-mutant CONTROL: unmutated copy did not pass ('$ctl') -- no mutant verdict below is evidence" ;; esac
# lead_mut <name> <sed-expr> <floor> <addr> <files...>: real must FAIL, mutant must PASS
lead_mut() {
  local nm="$1" ex="$2" fl="$3" a="$4" r m; shift 4
  sed -e "$ex" "$SELF" > "$LM/$nm.sh"
  if cmp -s "$SELF" "$LM/$nm.sh"; then bad "MUTANT lead/$nm: DID NOT APPLY"; return; fi
  r="$(bash "$LM/real.sh" --lead-verdict "$fl" "$a" "$@")"; m="$(bash "$LM/$nm.sh" --lead-verdict "$fl" "$a" "$@")"
  case "$r|$m" in FAIL*"|"PASS*) mutant_killed "${B_lead:-0}" "lead/$nm" "MUTANT lead/$nm: caught (real: ${r%%:*}, mutant: ${m%%:*})" ;;
    *) bad "MUTANT lead/$nm: SURVIVED or broken (real='$r' mutant='$m')" ;; esac
}
lead_mut floor-dropped 's/^  if \[ "\$n" -lt "\$fl" \]; then$/  if false; then/' 1 "$LA" "$LP/n1.md" "$LP/n2.md"
lead_mut literal-mismatch 's/^      has = (index(q, A) > 0)$/      has = (index(q, "to: \\"") > 0)/' 1 "$LA" "$LP/o7.md" "$LP/h1.md"
lead_mut p4-dropped 's/hand(s|ed|ing)? +/hand@@never@@ +/' 1 "$LA" "$LP/o8.md" "$LP/h1.md"
# A rule and a site agreeing on the address that failed: the measured-address check owns it.
printf -- '- Message **lead** (`SendMessage` `to: "lead"`) if a PR is BLOCKED.\n' > "$LP/wrong.md"
lead_mut measured-dropped 's/^  \[ "\$a" = "\$LEAD_ADDR_MEASURED" \] ||/  true ||/' 1 'to: "lead"' "$LP/wrong.md"

# --- 4d. BL-529 (G1): the derivation re-run never names the slot directory ---------------------
# `_gate-procedures.md` re-runs `validate-artifact-derivations.sh` after a repair join. A SLOT target
# (`.../s<N>/`) is a directory walk that skips the frozen records a repair edits, so it can never reach
# the cites the repair moved; the re-run names FILE targets. The gp-derive-file pin above holds the
# PRESENT half (prose, outside the fence, which pin_scan does not read); this arm holds the ABSENT half
# over the fence too. slot_hits counts invocations whose target ends in `s<digits-or-N>/`; file_hits
# counts invocations naming a placeholder file, the positive conjunct a silent subject cannot satisfy.
# FP set: the real file carries 0 slot targets after the edit and 2 file targets in the fence.
slot_hits() { grep -cE 'validate-artifact-derivations\.sh +[^ ]*/s(<N>|[0-9]+)/?( |`|$)' "$1" || true; }
file_hits() { grep -cE 'validate-artifact-derivations\.sh +<' "$1" || true; }
SD="$WORK/slot"; mkdir -p "$SD" || exit 2
printf '```\nscripts/ai-dlc/validate-artifact-derivations.sh _bmad-output/planning-artifacts/s<N>/\n```\n' > "$SD/off.md"
printf '```\nscripts/ai-dlc/validate-artifact-derivations.sh _bmad-output/planning-artifacts/s319/\n```\n' > "$SD/off2.md"
printf '```\nscripts/ai-dlc/validate-artifact-derivations.sh <the joined repair record>\nscripts/ai-dlc/validate-artifact-derivations.sh <assembled document path>\n```\nA directory target such as s<N>/ skips frozen records.\n' > "$SD/near.md"
GPF="$SKILL_DIR/steps/_gate-procedures.md"
sd_off="$(slot_hits "$SD/off.md")"; sd_off2="$(slot_hits "$SD/off2.md")"; sd_near="$(slot_hits "$SD/near.md")"; sd_nf="$(file_hits "$SD/near.md")"
if [ "$sd_off" = 1 ] && [ "$sd_off2" = 1 ] && [ "$sd_near" = 0 ] && [ "$sd_nf" = 2 ]; then
  sd_real_slot="$(slot_hits "$GPF")"; sd_real_file="$(file_hits "$GPF")"
  if [ "$sd_real_slot" = 0 ] && [ "$sd_real_file" -ge 2 ]; then
    ok "slot-target: the derivation re-run names $sd_real_file file target(s) and no slot directory (probe: s<N>/ and s319/ read 1 each, file targets and prose read 0)"; B_slot=1
  else
    bad "slot-target: _gate-procedures.md carries $sd_real_slot slot target(s) (want 0) and $sd_real_file file target(s) (want >= 2)"
  fi
  # MUTANT: restore the slot line in a copy; the arm must read it. cmp -s guards a sed that matched nothing.
  sed 's|^scripts/ai-dlc/validate-artifact-derivations.sh <the joined repair record>$|scripts/ai-dlc/validate-artifact-derivations.sh _bmad-output/planning-artifacts/s<N>/|' "$GPF" > "$SD/gp-mut.md"
  if cmp -s "$GPF" "$SD/gp-mut.md"; then bad "MUTANT slot-target: DID NOT APPLY"
  elif [ "$(slot_hits "$SD/gp-mut.md")" = 1 ]; then mutant_killed "$B_slot" slot-target "MUTANT slot-target: the restored slot line is read (1) where the real file reads 0"
  else bad "MUTANT slot-target: SURVIVED (read $(slot_hits "$SD/gp-mut.md"))"; fi
else
  bad "slot-target: FIXTURE BROKEN -- offenders $sd_off/$sd_off2 (want 1/1), near-miss $sd_near (want 0), near-miss file targets $sd_nf (want 2)"
fi

# --- 4e. BL-738: no role or step file tells a seat to hand-write a marker ------------------------
# A hand-written `seat-complete:` / `repair-complete:` line carries no sha= and no seal row, so any writer
# can mint one. carriers() counts lines that name the retired `unknown arg: --mark` fallback or spell a
# marker with no sha=. FP set over core/team-roles + core/skills/ai-dlc/steps: 0 carriers after the edit,
# and `bare line` is NOT keyed on (qa.md carries it in an unrelated sentence). Positive control: the same
# files carry `sha=<hex>` descriptions, so a scan that read nothing cannot score 0.
BM_RE='unknown arg: --mark|(seat|repair)-complete: [a-z<][^ ]* [a-z<][^ ]*( [^ ]*)? (findings=|none)|repair-complete: serial <pass>([^ ]| ?$| [^s])'
carriers() { { grep -hE "$BM_RE" "$@" 2>/dev/null || true; } | { grep -vc 'sha=' || true; }; }
BM="$WORK/bm"; mkdir -p "$BM" || exit 2
printf 'If that call fails with `unknown arg: --mark`, append the line.\n' > "$BM/off1.md"
printf 'append the bare line `seat-complete: <step> <seat> <shard> findings=<n>` instead\n' > "$BM/off2.md"
printf 'append, with Edit, the bare line\n`repair-complete: serial <pass>` instead, which the join accepts\n' > "$BM/off3.md"
printf 'It appends `seat-complete: <step> <seat> <shard> sha=<hex> findings=<n>`, whose `sha=` binds every line.\nappends `repair-complete: serial <pass> sha=<hex>`, the line only --complete-repair waits for\nthe bare line of a table\n' > "$BM/near.md"
bm1="$(carriers "$BM/off1.md")"; bm2="$(carriers "$BM/off2.md")"; bm3="$(carriers "$BM/off3.md")"; bmn="$(carriers "$BM/near.md")"
if [ "$bm1" = 1 ] && [ "$bm2" = 1 ] && [ "$bm3" = 1 ] && [ "$bmn" = 0 ]; then
  bm_real="$(carriers "$ROLES_DIR"/*.md "$SKILL_DIR"/steps/*.md)"
  bm_ctl="$(cat "$ROLES_DIR"/*.md "$SKILL_DIR"/steps/*.md | grep -c 'sha=<hex>')" || bm_ctl=0
  if [ "$bm_real" = 0 ] && [ "$bm_ctl" -ge 1 ]; then
    ok "bare-marker: 0 hand-written-marker carriers across the role and step files (control: $bm_ctl sha=<hex> descriptions; probe: fallback and bare spellings read 1 each, sha= description reads 0)"; B_bm=1
  else
    bad "bare-marker: $bm_real carrier(s) (want 0), $bm_ctl sha=<hex> control line(s) (want >= 1)"
  fi
  # MUTANT: re-insert the retired fallback sentence into a copy of dev.md; the scan must read it.
  cp "$ROLES_DIR/dev.md" "$BM/dev-mut.md"
  printf 'If that call fails with `unknown arg: --mark`, append the bare line `seat-complete: <step> <seat> <shard> findings=<n>` instead.\n' >> "$BM/dev-mut.md"
  bm_mut="$(carriers "$BM/dev-mut.md")"
  if cmp -s "$ROLES_DIR/dev.md" "$BM/dev-mut.md"; then bad "MUTANT bare-marker: DID NOT APPLY"
  elif [ "$bm_mut" -ge 1 ]; then mutant_killed "$B_bm" bare-marker "MUTANT bare-marker: the re-inserted fallback is read ($bm_mut) where the real files read 0"
  else bad "MUTANT bare-marker: SURVIVED"; fi
else
  bad "bare-marker: FIXTURE BROKEN -- offenders $bm1/$bm2/$bm3 (want 1/1/1), near-miss $bmn (want 0)"
fi

# --- 4f. every `<lead engine>` is scoped inside its own paragraph or numbered item ---------------
# A second absolute path in a prompt contradicts _dispatch-protocol.md rule 3 unless the text says when it applies,
# so each occurrence needs, in its own block (lines between blanks), EITHER form 1: a worktree-isolation condition
# (`worktree` with `lead's engine`), OR form 2: an in-place definition (`the lead checkout's `scripts/ai-dlc`` with
# `carries`), the wording code-reviewer.md, qa.md and implementation.md already use. Occurrences are derived per file
# at run time. FP set measured over the role and step files: 0 flagged on the tree once architect.md item 3 carried
# its own sentence (it had pointed at "the section above", which the block-local rule correctly refused). The awk
# program holds no apostrophe (the \047 escapes), since one would close the shell literal.
le_scan() { # le_scan <file>... -> one `file:line form=1|2|NONE` per occurrence
  awk '
  function flush(   i, f1, f2, form) {
    if (n_occ > 0) {
      f1 = (para ~ /worktree/ && para ~ /lead\047?s engine/)
      f2 = (para ~ /[Ll][Ee][Aa][Dd] checkout\047?s `scripts\/ai-dlc`/ && para ~ /carries/)
      form = f1 ? "1" : (f2 ? "2" : "NONE")
      for (i = 1; i <= n_occ; i++) print fname ":" occ[i] " form=" form
    }
    para = ""; n_occ = 0
  }
  FNR == 1 { flush(); fname = FILENAME }
  /^[ \t]*$/ { flush(); next }
  { para = para "\n" $0; if (index($0, "<lead engine>") > 0) { n_occ++; occ[n_occ] = FNR } }
  END { flush() }' "$@"
}
LE="$WORK/le"; mkdir -p "$LE" || exit 2
printf 'Run the call.\n   `<lead engine>/x.sh --mark`\n   `<lead engine>` is the path your brief carries when you run in a worktree; otherwise `scripts/ai-dlc` is the lead\047s engine.\n' > "$LE/f1.md"
printf 'Run both from `<lead engine>`, the lead checkout\047s `scripts/ai-dlc` path your brief carries.\n' > "$LE/f2.md"
printf 'Run the call from `<lead engine>` as defined in the section above.\n\nA later paragraph says the lead checkout\047s `scripts/ai-dlc` path your brief carries, and a worktree is the lead\047s engine.\n' > "$LE/bad.md"
le1="$(le_scan "$LE/f1.md" | grep -c 'form=1')" || le1=0
le2="$(le_scan "$LE/f2.md" | grep -c 'form=2')" || le2=0
leb="$(le_scan "$LE/bad.md" | grep -c 'form=NONE')" || leb=0
LE_FILES=( "$ROLES_DIR"/*.md "$SKILL_DIR"/steps/*.md )
if [ "$le1" = 2 ] && [ "$le2" = 1 ] && [ "$leb" = 1 ]; then
  le_out="$(le_scan "${LE_FILES[@]}")"
  le_occ="$(grep -c 'form=' <<<"$le_out")" || le_occ=0
  le_none="$(grep -c 'form=NONE' <<<"$le_out")" || le_none=0
  if [ "${#LE_FILES[@]}" -gt 0 ] && [ "$le_occ" -ge 1 ] && [ "$le_none" = 0 ]; then
    ok "lead-engine: all $le_occ occurrence(s) over ${#LE_FILES[@]} file(s) are scoped in their own block (probe: form 1 and form 2 read quiet, an unscoped occurrence flagged)"; B_le=1
  else
    bad "lead-engine: $le_none unscoped of $le_occ occurrence(s) over ${#LE_FILES[@]} file(s): $(grep 'form=NONE' <<<"$le_out" | tr '\n' ' ')"
  fi
  # MUTANT form 1: remove dev.md's worktree-condition sentence in a copy; form 2: remove qa.md's in-place definition.
  awk '!/when you run in a worktree/' "$ROLES_DIR/dev.md" > "$LE/dev-mut.md"
  awk '{ gsub(/the lead checkout.s `scripts\/ai-dlc` path your brief carries/, "the engine path"); print }' "$ROLES_DIR/qa.md" > "$LE/qa-mut.md"
  if cmp -s "$ROLES_DIR/dev.md" "$LE/dev-mut.md"; then bad "MUTANT lead-engine form 1: DID NOT APPLY"
  elif [ "$(le_scan "$LE/dev-mut.md" | grep -c 'form=NONE')" -ge 1 ]; then mutant_killed "$B_le" lead-engine-form1 "MUTANT lead-engine form 1: dev.md without its worktree sentence is flagged"
  else bad "MUTANT lead-engine form 1: SURVIVED"; fi
  if cmp -s "$ROLES_DIR/qa.md" "$LE/qa-mut.md"; then bad "MUTANT lead-engine form 2: DID NOT APPLY"
  elif [ "$(le_scan "$LE/qa-mut.md" | grep -c 'form=NONE')" -ge 1 ]; then mutant_killed "$B_le" lead-engine-form2 "MUTANT lead-engine form 2: qa.md without its in-place definition is flagged"
  else bad "MUTANT lead-engine form 2: SURVIVED"; fi
else
  bad "lead-engine: FIXTURE BROKEN -- probe form1=$le1 form2=$le2 unscoped=$leb (want 2/1/1)"
fi

# --- 4g. the window size touchpoint I states is the hook's ADVISOR_GATE_WINDOW default ----------
# Rule 32 touchpoint I states the advisor gate's window in the hook's own terms, because a deploy is
# not hook-gated and a lead judges it from the prose alone. The stated number is bound here to the
# hook's `WIN="${ADVISOR_GATE_WINDOW:-N}"` line (extracted as I79 extracts BUDGET), so changing either
# side alone fails. The skill side is read from the I item only: its `- **I --` line to the next
# `- **` line or blank line, HTML comments stripped, whitespace squeezed so a reflow between
# `default` and the number still reads. win_skill prints the number, MULTI when the item states more
# than one count, or nothing; win_hook prints the number or nothing; win_verdict prints MATCH, DRIFT,
# AMBIGUOUS or ABSENT. The hook carries the default twice, in the `WIN="${ADVISOR_GATE_WINDOW:-N}"`
# line and in the non-numeric fallback `case "$WIN" in ...) WIN=N ;; esac`; each is read on its own
# line shape, exactly one line each, and two that disagree read HOOK-SPLIT. MATCH needs all three
# equal. Presence-shaped: an absent hook, an absent item or an item that states no count is ABSENT,
# never MATCH. FP set: the real pair reads MATCH 10. Mutants move the fallback alone, the hook's
# two sites together, and the skill's count, each by one.
win_skill() {
  awk '
  { line = $0
    if (com) { c = index(line, "-->"); if (!c) next; line = substr(line, c + 3); com = 0 }
    while ((c = index(line, "<!--")) > 0) {
      r = substr(line, c + 4); d = index(r, "-->")
      if (d) line = substr(line, 1, c - 1) substr(r, d + 3); else { line = substr(line, 1, c - 1); com = 1 }
    }
    if (!on) { if (index(line, "- **I --") == 1) { on = 1; span = line }; next }
    if (line ~ /^[ \t]*$/ || index(line, "- **") == 1) exit
    span = span " " line }
  END { gsub(/[[:space:]]+/, " ", span); n = 0; rest = span
        while (match(rest, /`ADVISOR_GATE_WINDOW`, default [0-9]+/)) {
          s = substr(rest, RSTART, RLENGTH); sub(/.* /, "", s); n++; rest = substr(rest, RSTART + RLENGTH) }
        if (n == 1) print s; else if (n > 1) print "MULTI" }' "$1"
}
win_hook() { # the default site, `WIN="${ADVISOR_GATE_WINDOW:-N}"`, exactly one line
  local n
  n="$(grep -c '^WIN="${ADVISOR_GATE_WINDOW:-[0-9]*}"$' "$1" 2>/dev/null)" || n=0
  [ "$n" = 1 ] || return 0
  sed -n 's/^WIN="${ADVISOR_GATE_WINDOW:-\([0-9]*\)}"$/\1/p' "$1"
}
win_fallback() { # the non-numeric fallback site, `case "$WIN" in ...) WIN=N ;; esac`, exactly one line
  local n
  n="$(grep -c '^case "\$WIN" in .*) WIN=[0-9][0-9]* ;; esac$' "$1" 2>/dev/null)" || n=0
  [ "$n" = 1 ] || return 0
  sed -n 's/^case "\$WIN" in .*) WIN=\([0-9][0-9]*\) ;; esac$/\1/p' "$1"
}
win_verdict() { # <skill file> <hook file>
  local s h fb
  s="$(win_skill "$1")"; h="$(win_hook "$2")"; fb="$(win_fallback "$2")"
  if [ -n "$h" ] && [ "$h" != "$fb" ]; then printf 'HOOK-SPLIT default=%s fallback=%s\n' "$h" "${fb:-none}"
  elif [ "$s" = "MULTI" ]; then printf 'AMBIGUOUS skill=more-than-one-count hook=%s\n' "${h:-none}"
  elif [ -z "$s" ] || [ -z "$h" ]; then printf 'ABSENT skill=%s hook=%s\n' "${s:-none}" "${h:-none}"
  elif [ "$s" = "$h" ]; then printf 'MATCH %s\n' "$s"
  else printf 'DRIFT skill=%s hook=%s\n' "$s" "$h"; fi
}
WD="$WORK/win"; mkdir -p "$WD" || exit 2
printf -- '- **I -- before.** Call it\n  inside the window (`ADVISOR_GATE_WINDOW`, default 7, in\n  messages).\n' > "$WD/s7.md"
printf -- '- **I -- before.** Call it.\n\nThe window (`ADVISOR_GATE_WINDOW`, default 7) is elsewhere.\n<!-- - **I -- x** (`ADVISOR_GATE_WINDOW`, default 7) -->\n' > "$WD/sfar.md"
printf '#!/bin/sh\nWIN="${ADVISOR_GATE_WINDOW:-7}"\ncase "$WIN" in %s|*[!0-9]*) WIN=7 ;; esac\n' "''" > "$WD/h7.sh"
printf '#!/bin/sh\nWIN="${ADVISOR_GATE_WINDOW:-8}"\ncase "$WIN" in %s|*[!0-9]*) WIN=8 ;; esac\n' "''" > "$WD/h8.sh"
printf '#!/bin/sh\nWIN="${ADVISOR_GATE_WINDOW:-7}"\ncase "$WIN" in %s|*[!0-9]*) WIN=9 ;; esac\n' "''" > "$WD/hsplit.sh"
wv1="$(win_verdict "$WD/s7.md" "$WD/h7.sh")"; wv2="$(win_verdict "$WD/s7.md" "$WD/h8.sh")"
printf -- '- **I -- before.** Call it inside the window (`ADVISOR_GATE_WINDOW`, default\n  7, in messages).\n' > "$WD/swrap.md"
printf -- '- **I -- before.** Call it inside the window (`ADVISOR_GATE_WINDOW`, default 7), or\n  (`ADVISOR_GATE_WINDOW`, default 9) on a deploy.\n' > "$WD/stwo.md"
wv3="$(win_verdict "$WD/sfar.md" "$WD/h7.sh")"; wv4="$(win_verdict "$WD/s7.md" "$WD/absent.sh")"
wv5="$(win_verdict "$WD/swrap.md" "$WD/h7.sh")"; wv6="$(win_verdict "$WD/stwo.md" "$WD/h7.sh")"
wv7="$(win_verdict "$WD/s7.md" "$WD/hsplit.sh")"
if [ "$wv1" = "MATCH 7" ] && [ "$wv2" = "DRIFT skill=7 hook=8" ] && [ "$wv3" = "ABSENT skill=none hook=7" ] && [ "$wv4" = "ABSENT skill=7 hook=none" ] \
   && [ "$wv5" = "MATCH 7" ] && [ "${wv6%% *}" = "AMBIGUOUS" ] && [ "$wv7" = "HOOK-SPLIT default=7 fallback=9" ]; then
  case "$LAYOUT" in
    dist) WGATE="$ROOT/core/hooks/ai-dlc-advisor-gate.sh" ;;
    *)    WGATE="$ROOT/.claude/hooks/ai-dlc-advisor-gate.sh" ;;
  esac
  if [ -f "$WGATE" ]; then
    echo "HERMETIC-CONSUMED core/hooks/ai-dlc-advisor-gate.sh"
  fi
  wv_real="$(win_verdict "$SKILL_DIR/SKILL.md" "$WGATE")"
  case "$wv_real" in
    MATCH*) ok "window-count: touchpoint I states the hook's ADVISOR_GATE_WINDOW default ($wv_real; probe: match, drift, an out-of-item count, an absent hook, a wrapped count, two counts and a split hook each read as built)"; B_win=1 ;;
    *)      bad "window-count: touchpoint I against ${WGATE#"$ROOT/"} reads $wv_real (want MATCH)" ;;
  esac
  # MUTANT, fallback only: the hook's non-numeric fallback moved one up in a copy, the default untouched.
  wf="$(win_fallback "$WGATE")"; wfm=$(( ${wf:-0} + 1 ))
  sed "s/^\(case \"\\\$WIN\" in .*) WIN=\)[0-9][0-9]*\( ;; esac\)\$/\1$wfm\2/" "$WGATE" > "$WD/gate-fb-mut.sh" 2>/dev/null
  wv_fb="$(win_verdict "$SKILL_DIR/SKILL.md" "$WD/gate-fb-mut.sh")"
  if [ ! -f "$WGATE" ] || [ -z "$wf" ] || cmp -s "$WGATE" "$WD/gate-fb-mut.sh"; then bad "MUTANT window-count fallback: DID NOT APPLY"
  else
    case "$wv_fb" in
      HOOK-SPLIT*"fallback=$wfm") mutant_killed "$B_win" window-count-fallback "MUTANT window-count fallback: a fallback of $wfm reads $wv_fb" ;;
      *)                          bad "MUTANT window-count fallback: SURVIVED ($wv_fb)" ;;
    esac
  fi
  # MUTANT: the hook's default AND fallback moved one up in a copy; the arm must read DRIFT where the real pair reads MATCH.
  wh="$(win_hook "$WGATE")"; wm=$(( ${wh:-0} + 1 ))
  sed -e "s/^WIN=\"\${ADVISOR_GATE_WINDOW:-[0-9]*}\"\$/WIN=\"\${ADVISOR_GATE_WINDOW:-$wm}\"/" \
      -e "s/^\(case \"\\\$WIN\" in .*) WIN=\)[0-9][0-9]*\( ;; esac\)\$/\1$wm\2/" "$WGATE" > "$WD/gate-mut.sh" 2>/dev/null
  wv_mut="$(win_verdict "$SKILL_DIR/SKILL.md" "$WD/gate-mut.sh")"
  if [ ! -f "$WGATE" ] || [ -z "$wh" ] || cmp -s "$WGATE" "$WD/gate-mut.sh"; then bad "MUTANT window-count: DID NOT APPLY"
  else
    case "$wv_mut" in
      DRIFT*"hook=$wm") mutant_killed "$B_win" window-count-hook "MUTANT window-count: a hook default of $wm reads $wv_mut" ;;
      *)             bad "MUTANT window-count: SURVIVED ($wv_mut)" ;;
    esac
  fi
  # MUTANT, skill side: the item's stated count moved one up in a copy of SKILL.md; the hook untouched.
  ws="$(win_skill "$SKILL_DIR/SKILL.md")"
  case "$ws" in ''|*[!0-9]*) ws="" ;; esac
  wsm=$(( ${ws:-0} + 1 ))
  WS_OLD="\`ADVISOR_GATE_WINDOW\`, default $ws" WS_NEW="\`ADVISOR_GATE_WINDOW\`, default $wsm" awk '
    BEGIN { o = ENVIRON["WS_OLD"]; n = ENVIRON["WS_NEW"] }
    { if (!done && (c = index($0, o)) > 0) { $0 = substr($0, 1, c - 1) n substr($0, c + length(o)); done = 1 }; print }' \
    "$SKILL_DIR/SKILL.md" > "$WD/skill-mut.md"
  wv_smut="$(win_verdict "$WD/skill-mut.md" "$WGATE")"
  if [ -z "$ws" ] || cmp -s "$SKILL_DIR/SKILL.md" "$WD/skill-mut.md"; then bad "MUTANT window-count skill side: DID NOT APPLY"
  else
    case "$wv_smut" in
      DRIFT*"skill=$wsm "*) mutant_killed "$B_win" window-count-skill "MUTANT window-count skill side: a stated count of $wsm reads $wv_smut" ;;
      *)                    bad "MUTANT window-count skill side: SURVIVED ($wv_smut)" ;;
    esac
  fi
else
  bad "window-count: FIXTURE BROKEN -- probe '$wv1' / '$wv2' / '$wv3' / '$wv4' / '$wv5' / '$wv6'"
fi

# --- 4h. the join contract for a teammate's markdown result file ------------------------------------
# "Bounded-join beat" in _gate-procedures.md is the ONE home of the contract: every brief naming such a
# file closes with a rendered `--mark` line copied from there, and the beat is `--complete --dispatch` only
# when the dispatch's spawn-ledger row carries `"mark":"rendered"` (a teammate briefed without the line
# writes no marker, and `--complete` would read its file UNFINISHED until the cap). The defect these arms
# exist for: a `--mark` line retyped as `rows=<n>` exited 64 and wrote nothing, and a beat with no
# `--complete` read a header-only file as DELIVERED.
#   (a) home: the slice carries exactly one rendered `--mark` span, `<lead engine>`-rooted, `findings=<n>`
#       last, plus the `"mark":"rendered"` condition and its `--complete --dispatch` call.
#   (b) deploy-validate.md: every dispatch site reads and follows the home. GRAMMAR: a match of
#       `[Dd]ispatch (its |the |a )?(`<role>`|closing writer)` that STARTS on a line (the next line is
#       joined so a wrapped `dispatch its` / `closing writer` is read); outside fences. The site's UNIT is
#       its list item (a `- ` or `<n>. ` line up to the next item or blank) or its paragraph, with
#       whitespace collapsed; it must carry `READ AND FOLLOW` and `"Bounded-join beat"`.
#   (c) every block carrying `<lead engine>/wait-for-deliverable.sh --mark <file>` names `<deliverable>`.
#   (d) the rendered span, EXTRACTED from the home and filled in, runs against a scratch file and seals.
gp_home() { awk '/^#+ Bounded-join beat/{f=1;print;next} f&&/^#{1,3} /{exit} f{print}' "$1"; }
home_spans() { gp_home "$1" | grep -oE '`<lead engine>/wait-for-deliverable\.sh --mark [^`]*`' | tr -d '`'; }
home_verdict() { # home_verdict <gp file> -> "<spans> <findings-last> <rendered-token> <complete-dispatch>"
  local sp h n fl rt cd
  sp="$(home_spans "$1")"; h="$(gp_home "$1")"
  n="$(grep -c . <<<"$sp")" || n=0
  fl=0; [ "$n" = 1 ] && case "$sp" in *' findings=<n>') fl=1 ;; esac
  rt="$(grep -cF '"mark":"rendered"' <<<"$h")" || rt=0
  cd="$(grep -cF 'wait-for-deliverable.sh --complete --dispatch <agentId>' <<<"$h")" || cd=0
  printf '%s %s %s %s' "$n" "$fl" "$rt" "$cd"
}
GP4G="$SKILL_DIR/steps/_gate-procedures.md"
MG="$WORK/mark-contract"; mkdir -p "$MG" || exit 2
set -- $(home_verdict "$GP4G")
if [ "$1" = 1 ] && [ "$2" = 1 ] && [ "$3" -ge 1 ] && [ "$4" -ge 1 ]; then
  ok "mark-home: \"Bounded-join beat\" renders one <lead engine> --mark line ending findings=<n>, and arms --complete --dispatch on \"mark\":\"rendered\" ($3 token line(s))"
else
  bad "mark-home: \"Bounded-join beat\" spans=$1 (want 1), findings-last=$2 (want 1), \"mark\":\"rendered\" lines=$3 (want >=1), --complete --dispatch lines=$4 (want >=1)"
fi
# (a2) home scope: the row decides only a non-shard teammate's result file, so seat, shard, cross and
# repair-part files keep --complete whatever the row says (a seat whose row predates the key would
# otherwise get a bare beat and a header-only file reads DELIVERED); and the read line's third outcome,
# empty output from an unresolved meta file, is `bare`. Read on the home with whitespace collapsed.
MS_CARVE='seat, shard, cross and repair-part files keep `--complete`'
MS_EPIC='as do epic part files'
MS_BARE='Any output but `rendered`, empty too, is `bare`.'
mark_scope() { # mark_scope <gp file> -> "<carve-out> <not-rendered-is-bare> <epic-parts-named>"
  local h c=0 b=0 e=0; h="$(gp_home "$1" | tr '\n' ' ' | tr -s ' ')"
  case "$h" in *"$MS_CARVE"*) c=1 ;; esac
  case "$h" in *"$MS_BARE"*) b=1 ;; esac
  case "$h" in *"$MS_EPIC"*) e=1 ;; esac
  printf '%s %s %s' "$c" "$b" "$e"
}
set -- $(mark_scope "$GP4G")
if [ "$1" = 1 ] && [ "$2" = 1 ] && [ "$3" = 1 ]; then
  ok "mark-scope: \"Bounded-join beat\" keeps --complete for seat, shard, cross, repair-part and epic part files whatever the row, and reads any output but rendered as bare"; B_mscope=1
else
  bad "mark-scope: \"Bounded-join beat\" carve-out=$1 (want 1), not-rendered-is-bare=$2 (want 1), epic-parts-named=$3 (want 1)"
fi
#   M-s1 drop the carve-out clause; M-s2 drop the not-rendered-is-bare sentence; M-s3 drop the epic-part phrase: mark-scope names each.
awk -v s="$MS_CARVE" '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f && index($0, s)) sub(/seat, shard, cross and repair-part files keep `--complete`/, "files keep"); print }' "$GP4G" > "$MG/gp-nocarve.md"
awk -v s="$MS_BARE" '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f && (i = index($0, s))) $0 = substr($0, 1, i - 1) substr($0, i + length(s)); print }' "$GP4G" > "$MG/gp-nobare.md"
awk -v s="$MS_EPIC" '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f && (i = index($0, s))) $0 = substr($0, 1, i - 1) substr($0, i + length(s)); print }' "$GP4G" > "$MG/gp-noepic.md"
for ms in nocarve:1 nobare:2 noepic:3; do
  mf="$MG/gp-${ms%%:*}.md"
  if cmp -s "$GP4G" "$mf"; then bad "MUTANT mark/${ms%%:*}: DID NOT APPLY"; continue; fi
  set -- $(mark_scope "$mf")
  case "${ms##*:}" in 1) mv="$1" ;; 2) mv="$2" ;; *) mv="$3" ;; esac
  if [ "$mv" = 0 ]; then mutant_killed "$B_mscope" "mark-${ms%%:*}" "MUTANT mark/${ms%%:*}: the home without that clause is named by mark-scope ($1 $2)"
  else bad "MUTANT mark/${ms%%:*}: SURVIVED mark-scope ($1 $2)"; fi
done

# (a3) the two COPIES of the `--complete` carve-out list (the auto-handoff procedure in _gate-procedures.md
# and handoff.md step 1) name epic part files in the same list sentence as the home does. Each site's
# paragraph is read with the span bounds the gp-stop-repair-part / ho-stop-repair-part rows use, whitespace
# collapsed; the sentence is the `--complete <path> ...` list ending at `and for a teammate's markdown`.
EP_SENT='for seat, shard, cross and repair-part files, epic part files and for a teammate'
site_epic() { # site_epic <file> <span start prefix> <span end prefix> -> 1 if the list sentence names epic part files
  local p; p="$(awk -v a="$2" -v b="$3" '
    index($0, a) == 1 { f = 1 }
    f && index($0, b) == 1 { exit }
    f { print }' "$1" | tr '\n' ' ' | tr -s ' ')"
  case "$p" in *"$EP_SENT"*) printf 1 ;; *) printf 0 ;; esac
}
HO4G="$SKILL_DIR/steps/handoff.md"
GP_A='## Auto-handoff evaluation (referenced by step files)'; GP_B='## Context reminder threshold check'
HO_A='Execute this 5-step procedure in order:'; HO_B='**Resume is snapshot-driven.**'
if [ "$(site_epic "$GP4G" "$GP_A" "$GP_B")" = 1 ]; then
  ok "mark-epic-gp: the auto-handoff procedure in _gate-procedures.md names epic part files in the --complete list sentence"; B_epgp=1
else
  bad "mark-epic-gp: the auto-handoff procedure in _gate-procedures.md does not carry 'epic part files' in the --complete list sentence"
fi
if [ "$(site_epic "$HO4G" "$HO_A" "$HO_B")" = 1 ]; then
  ok "mark-epic-ho: handoff.md step 1 names epic part files in the --complete list sentence"; B_epho=1
else
  bad "mark-epic-ho: handoff.md step 1 does not carry 'epic part files' in the --complete list sentence"
fi
#   M-e1 delete `epic part files ` from the _gate-procedures.md auto-handoff list only: mark-epic-gp names it.
#   M-e2 delete it from handoff.md only: mark-epic-ho names it.
awk -v a="$GP_A" -v b="$GP_B" 'index($0, a) == 1 { f = 1 } f && index($0, b) == 1 { f = 0 } { if (f && (i = index($0, "epic part files "))) $0 = substr($0, 1, i - 1) substr($0, i + 16); print }' "$GP4G" > "$MG/gp-noepic-ho-site.md"
awk -v a="$HO_A" -v b="$HO_B" 'index($0, a) == 1 { f = 1 } f && index($0, b) == 1 { f = 0 } { if (f && (i = index($0, "epic part files "))) $0 = substr($0, 1, i - 1) substr($0, i + 16); print }' "$HO4G" > "$MG/ho-noepic.md"
if cmp -s "$GP4G" "$MG/gp-noepic-ho-site.md"; then bad "MUTANT mark/epic-gp: DID NOT APPLY"
elif [ "$(site_epic "$MG/gp-noepic-ho-site.md" "$GP_A" "$GP_B")" = 0 ]; then mutant_killed "$B_epgp" mark-epic-gp "MUTANT mark/epic-gp: the auto-handoff list without epic part files is named by mark-epic-gp"
else bad "MUTANT mark/epic-gp: SURVIVED mark-epic-gp"; fi
if cmp -s "$HO4G" "$MG/ho-noepic.md"; then bad "MUTANT mark/epic-ho: DID NOT APPLY"
elif [ "$(site_epic "$MG/ho-noepic.md" "$HO_A" "$HO_B")" = 0 ]; then mutant_killed "$B_epho" mark-epic-ho "MUTANT mark/epic-ho: the handoff.md list without epic part files is named by mark-epic-ho"
else bad "MUTANT mark/epic-ho: SURVIVED mark-epic-ho"; fi

# (d) The engine is the one this layout ships: core/scripts in the distribution, scripts/ai-dlc installed.
case "$LAYOUT" in
  dist) WFD="$ROOT/core/scripts/wait-for-deliverable.sh" ;;
  *)    WFD="$ROOT/scripts/ai-dlc/wait-for-deliverable.sh" ;;
esac
# run_rendered <gp file> <scratch dir> -> "<rc> <last line>"; the span is filled in, never retyped here.
run_rendered() {
  local sp line rc d="$2"
  sp="$(home_spans "$1")"
  [ "$(grep -c . <<<"$sp")" = 1 ] || { printf 'NOSPAN'; return; }
  printf '# Result\n\nfinding text\n' > "$d/result.md"
  line="${sp//<lead engine>/$(dirname "$WFD")}"
  line="${line//<file>/$d/result.md}"; line="${line//<step>/deploy-validate}"
  line="${line//<role>/dev}"; line="${line//<shard>/none}"; line="${line//<n>/0}"
  case "$line" in *'<'*|*'>'*) printf 'UNFILLED %s' "$line"; return ;; esac
  set -f; set -- $line; set +f
  bash "$@" >/dev/null 2>&1; rc=$?
  printf '%s %s' "$rc" "$(awk 'NF { l = $0 } END { print l }' "$d/result.md")"
}
if [ ! -f "$WFD" ]; then
  bad "mark-runs: FIXTURE BROKEN -- the engine $WFD is absent, so the rendered line could not be run"
else
  echo "HERMETIC-CONSUMED $(cd "$(dirname "$WFD")" && pwd)/$(basename "$WFD")"
  mkdir -p "$MG/real" || exit 2
  mr="$(run_rendered "$GP4G" "$MG/real")"
  if [[ "$mr" =~ ^0\ seat-complete:\ deploy-validate\ dev\ none\ sha=[0-9a-f]+\ findings=0$ ]]; then
    ok "mark-runs: the --mark line extracted from \"Bounded-join beat\", filled in, exits 0 and seals (${mr#0 })"; B_mruns=1
  else
    bad "mark-runs: the rendered --mark line from \"Bounded-join beat\" did not seal a scratch file: '$mr' (want '0 seat-complete: deploy-validate dev none sha=<hex> findings=0')"
  fi
fi

# (b) deploy-validate.md dispatch sites.
dv_sites() { # dv_sites <file> -> one "<line>\t<0|1 cites the home>" per dispatch site
  awk '
  { L[NR] = $0 }
  END {
    u = 0; fence = 0
    for (i = 1; i <= NR; i++) {
      t = L[i]; sub(/^[ \t]+/, "", t)
      if (substr(t, 1, 3) == "```") { fence = !fence; F[i] = 1; u++; continue }
      if (fence) { F[i] = 1; continue }
      if (t == "") { u++; U[i] = -1; continue }
      if (t ~ /^([0-9]+\.|-) /) u++
      U[i] = u; T[u] = T[u] " " t
    }
    re = "[Dd]ispatch (its |the |a )?(`[a-z-]+`|closing writer)"
    for (i = 1; i <= NR; i++) {
      if (F[i] || U[i] == -1) continue
      j = L[i]; if (i < NR && !F[i + 1]) { n = L[i + 1]; sub(/^[ \t]+/, "", n); j = j " " n }
      if (match(j, re) && RSTART <= length(L[i])) {
        q = T[U[i]]; gsub(/[ \t]+/, " ", q)
        print i "\t" ((index(q, "READ AND FOLLOW") && index(q, "\"Bounded-join beat\"")) ? 1 : 0)
      }
    }
  }' "$1"
}
DV="$MG/dv"; mkdir -p "$DV" || exit 2
printf '%s\n' 'Each remedial dispatch is one repair between two smoke runs.' '"Split dispatch" serial exception 2.' \
  'past gate 3: dispatch its' 'closing writer and re-run.' '' 'no dispatch of a teammate.' \
  '3. If code issue: dispatch `dev` to fix the code; the lead' '   then re-deploys. The lead work here is the dispatch, the' \
  '4. If deployment issue: dispatch the `ops` teammate to fix it.' '' '- For drift: dispatch a `dev` teammate to correct' \
  '  the source.' '' 'a code-reviewer dispatched after gate 3.' '```' 'dispatch `dev` inside a fence' '```' > "$DV/probe.md"
dv_probe="$(dv_sites "$DV/probe.md" | cut -f1 | tr '\n' ' ')"
if [ "$dv_probe" = "3 7 9 11 " ]; then
  DVF="$SKILL_DIR/steps/deploy-validate.md"
  dv_out="$(dv_sites "$DVF")"
  dv_n="$(grep -c . <<<"$dv_out")" || dv_n=0
  dv_unc="$(awk -F'\t' '$2 == 0 { printf "%s ", $1 }' <<<"$dv_out")"
  if [ "$dv_n" = 5 ] && [ -z "$dv_unc" ]; then
    ok "mark-dv: deploy-validate.md has 5 dispatch sites by the stated grammar, each reading and following \"Bounded-join beat\" (probe: 4 shapes read, 6 near-misses and a fenced line not)"; B_dv=1
  else
    bad "mark-dv: deploy-validate.md has $dv_n dispatch site(s) by the stated grammar (want 5); uncited at line(s): ${dv_unc:-none}"
  fi
  # MUTANT: the ops site loses its citation; the arm must name that site.
  awk '{ if (index($0, "dispatch the `ops` teammate")) ops = 1; if (ops && index($0, "(READ AND FOLLOW")) { sub(/ \(READ AND FOLLOW `_gate-procedures.md`, "Bounded-join beat"$/, ""); ops = 2 } if (ops == 2 && index($0, "for its brief and join), re-deploy")) { sub(/for its brief and join\), re-deploy/, "re-deploy"); ops = 0 } print }' "$DVF" > "$DV/dv-mut.md"
  if cmp -s "$DVF" "$DV/dv-mut.md"; then bad "MUTANT mark-dv: DID NOT APPLY"
  elif [ "$(dv_sites "$DV/dv-mut.md" | awk -F'\t' '$2 == 0' | grep -c .)" = 1 ]; then mutant_killed "$B_dv" mark-dv "MUTANT mark-dv: the ops site without its citation is named by mark-dv"
  else bad "MUTANT mark-dv: SURVIVED ($(dv_sites "$DV/dv-mut.md" | tr '\t\n' ': '))"; fi
else
  bad "mark-dv: FIXTURE BROKEN -- the grammar read probe lines [$dv_probe], want [3 7 9 11 ]"
fi

# (c) every isolated-brief block naming the seat or teammate --mark close names <deliverable>.
dl_scan() { # dl_scan <files...> -> "<file>:<first line> deliverable=0|1" per block holding the close
  awk '
  function flush() { if (hit) print fn ":" st " deliverable=" (index(para, "<deliverable>") ? 1 : 0); para = ""; hit = 0; st = 0 }
  FNR == 1 { flush(); fn = FILENAME }
  /^[ \t]*$/ { flush(); next }
  { if (st == 0) st = FNR; para = para "\n" $0; if (index($0, "<lead engine>/wait-for-deliverable.sh --mark <file>")) hit = 1 }
  END { flush() }' "$@"
}
dl_out="$(dl_scan "$ROLES_DIR"/*.md "$SKILL_DIR"/steps/*.md "$SKILL_DIR"/rule-bodies/*.md)"
dl_n="$(grep -c 'deliverable=' <<<"$dl_out")" || dl_n=0
dl_bad="$(grep 'deliverable=0' <<<"$dl_out" | sed "s|$ROOT/||" | tr '\n' ' ')"
dl_dev="$(grep -c "/dev.md:.* deliverable=1" <<<"$dl_out")" || dl_dev=0
dl_home="$(grep -c "_gate-procedures.md:.* deliverable=1" <<<"$dl_out")" || dl_home=0
if [ "$dl_n" -ge 5 ] && [ -z "$dl_bad" ] && [ "$dl_dev" -ge 1 ] && [ "$dl_home" -ge 2 ]; then
  ok "mark-deliverable: all $dl_n block(s) carrying the <lead engine> --mark <file> close name <deliverable> (dev.md and both _gate-procedures.md blocks among them)"; B_mdl=1
else
  bad "mark-deliverable: $dl_n block(s), unnamed: [${dl_bad:-none}], dev.md=$dl_dev (want >=1), _gate-procedures.md=$dl_home (want >=2)"
fi

# MUTANTS of the contract, each a copy guarded by cmp -s, each scored on its killing arm.
#   M-a drop --complete from the home's rendered call: the widened join scan (4b) flags the home paragraph.
awk '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f) gsub(/wait-for-deliverable\.sh --complete --dispatch/, "wait-for-deliverable.sh --dispatch"); print }' "$GP4G" > "$MG/gp-nocomplete.md"
if cmp -s "$GP4G" "$MG/gp-nocomplete.md"; then bad "MUTANT mark/no-complete: DID NOT APPLY"
elif mnc_o="$(join_findings "$MG/gp-nocomplete.md")"; grep -q . <<<"$mnc_o"; then mutant_killed "$B_join" mark-no-complete "MUTANT mark/no-complete: the home without --complete is flagged by join (the \"mark\":\"rendered\" paragraph key)"
else bad "MUTANT mark/no-complete: SURVIVED -- the home lost --complete and the join scan stayed quiet"; fi
#   M-b render rows=<n>: mark-runs (d) refuses it; mark-home (a) reads findings= no longer last.
awk '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f) gsub(/<shard> findings=<n>`/, "<shard> rows=<n>`"); print }' "$GP4G" > "$MG/gp-rows.md"
if cmp -s "$GP4G" "$MG/gp-rows.md"; then bad "MUTANT mark/rows: DID NOT APPLY"
elif [ ! -f "$WFD" ]; then bad "MUTANT mark/rows: FIXTURE BROKEN -- no engine to run"
else
  mkdir -p "$MG/rows" || exit 2
  mrr="$(run_rendered "$MG/gp-rows.md" "$MG/rows")"
  case "$mrr" in 0\ seat-complete:*) bad "MUTANT mark/rows: SURVIVED mark-runs ('$mrr')" ;;
    *) mutant_killed "$B_mruns" mark-rows "MUTANT mark/rows: the rendered rows=<n> line is refused by the engine (mark-runs: '${mrr%% *}'), not sealed" ;; esac
fi
#   M-c drop the <deliverable> clause from dev.md: mark-deliverable (c) names the block.
awk '{ sub(/ A worktree brief also carries `<deliverable>`.*$/, ""); print }' "$ROLES_DIR/dev.md" > "$MG/dev-nodeliv.md"
if cmp -s "$ROLES_DIR/dev.md" "$MG/dev-nodeliv.md"; then bad "MUTANT mark/no-deliverable: DID NOT APPLY"
elif mnd_o="$(dl_scan "$MG/dev-nodeliv.md")"; grep -q 'deliverable=0' <<<"$mnd_o"; then mutant_killed "$B_mdl" mark-no-deliverable "MUTANT mark/no-deliverable: dev.md without its <deliverable> clause is named by mark-deliverable"
else bad "MUTANT mark/no-deliverable: SURVIVED"; fi

# --- 4i. the review-shard step and role pins (moved from review-shard-merge, BL-918) ---------------
# implementation.md's Gate-1/Gate-2 dispatch paragraphs, the closing writer, qa.md's and code-reviewer.md's
# As a Shard clauses, and partition-review-diff.sh's THRESHOLD header, each read as prose (no subject runs). The
# threshold key and the built-in default are DERIVED from the partition script, exactly as review-shard-merge's
# lib.sh derives them, so a moved default moves both fixtures together. The partition resolves as the engine in
# 4h does: core/scripts in the distribution, scripts/ai-dlc installed.
STEP_MD="$SKILL_DIR/steps/implementation.md"; QA_MD="$ROLES_DIR/qa.md"; ROLE_MD="$ROLES_DIR/code-reviewer.md"
case "$LAYOUT" in
  dist) PART="$ROOT/core/scripts/partition-review-diff.sh" ;;
  *)    PART="$ROOT/scripts/ai-dlc/partition-review-diff.sh" ;;
esac
for _f in "$STEP_MD" "$QA_MD" "$ROLE_MD" "$PART"; do
  [ -f "$_f" ] || { echo "FIXTURE ERROR: 4i: $_f is absent; nothing in 4i was asserted" >&2; exit 2; }
done
KEY="$(sed -n 's/.*"\${\(AI_DLC_[A-Z0-9_]*\):-}".*/\1/p' "$PART" | head -1)"
[ -n "$KEY" ] || { echo "FIXTURE STALE: 4i: no \"\${AI_DLC_...:-}\" dereference in $PART" >&2; exit 2; }
DFLT_N="$(grep -c '^REVIEW_SHARD_DEFAULT_MIN_FILES=' "$PART")" || DFLT_N=0
DFLT="$(sed -n 's/^REVIEW_SHARD_DEFAULT_MIN_FILES=\([0-9][0-9]*\)$/\1/p' "$PART")"
[ "$DFLT_N" = "1" ] && [ -n "$DFLT" ] && [ "$DFLT" -ge 2 ] \
  || { echo "FIXTURE STALE: 4i: $PART carries $DFLT_N 'REVIEW_SHARD_DEFAULT_MIN_FILES=<n>' line(s) (want 1, n >= 2)" >&2; exit 2; }
# THE PROGRAMS ARE NOTHING IF THE LEAD IS NEVER TOLD TO RUN THEM. Every arm above drives the two
# programs directly, so a release that built them and never rewired the step file passes all of
# them and every consumer keeps dispatching one reviewer. Keyed on the EMISSION SITE: the
# paragraph implementation.md opens with `**Gate-1 dispatch:`, read outside fences, must name
# both programs -- a whole-file grep is satisfied by a mention anywhere, including a fence.
# The same for the role clause: the `## As a Shard` section must name the three grammar tokens
# the merge refuses without, or a shard written as the role file says is refused at the join.
step_para() { # <file> -> the Gate-1 dispatch paragraph, fenced lines dropped
  awk '/^```/ { f = !f; next } f { next }
       /^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { exit } p { print }' "$1"
}
p_step() { # <file>
  local t; t="$(step_para "$1")"
  [ -n "$t" ] && grep -qF 'partition-review-diff.sh' <<<"$t" && grep -qF 'merge-review-shards.sh' <<<"$t"
}
role_sect() { awk '/^## As a Shard/ { p = 1; next } p && /^## / { exit } p { print }' "$1"; }
p_role() { # <file>
  local t; t="$(role_sect "$1")"
  [ -n "$t" ] && grep -qF 'shard-verdict:' <<<"$t" && grep -qF 'reviewed-sha:' <<<"$t" && grep -qF 'parts:' <<<"$t"
}
# Self-probes, both directions, on copies: the names removed from the paragraph, and the names
# present only inside a fence, must each fail; the shipped file must pass.
sed -e '/^\*\*Gate-1 dispatch:/,/^[[:space:]]*$/s/merge-review-shards\.sh/MERGE-GONE/g' "$STEP_MD" > "$WORK/step-strip.md"
{ printf '%s\n' '**Gate-1 dispatch: decoy.** one reviewer.' '' '```' 'partition-review-diff.sh merge-review-shards.sh' '```'; } > "$WORK/step-fence.md"
sed -e '/^## As a Shard/,/^## /s/reviewed-sha:/REVIEWED-GONE/g' "$ROLE_MD" > "$WORK/role-strip.md"
if cmp -s "$STEP_MD" "$WORK/step-strip.md" || cmp -s "$ROLE_MD" "$WORK/role-strip.md"; then
  bad "S0: FIXTURE STALE -- a structural probe's sed matched nothing, so the probe would score the shipped text"
elif p_step "$WORK/step-strip.md" || p_step "$WORK/step-fence.md" || p_role "$WORK/role-strip.md"; then
  bad "S0: FIXTURE BROKEN -- a structural predicate passed a copy with a program or token removed, or present only in a fence"
else
  ok "S0: the structural predicates refuse a paragraph missing the merge, names only inside a fence, and a role clause missing reviewed-sha:"
fi
# THE STEP SAYS SHARDING IS ON BY DEFAULT, in the paragraph the lead acts on. A reverted step
# tells every consumer lead the old contract while the script shards anyway. Read as one joined
# line, so a wrapped sentence still matches. Two refusals inside THIS paragraph only:
#   - the word "opt-in";
#   - opt-in BEHAVIOUR without the word: a clause gating the partition on the variable being set,
#     "only when|if ... is set" or "unless ... is set", up to the clause's end.
# LIMIT, STATED: this arm pins WORDING, not behaviour. A paraphrase of the opt-in contract outside
# both shapes ("run the partition after configuring the variable") passes it. The behaviour is
# held by P2/P2b, which run the shipping script with the variable unset.
p_step_dflt() { # <file>
  local t; t="$(step_para "$1" | tr '\n' ' ' | tr -s ' ')"
  [ -n "$t" ] && ! grep -qi 'opt-in' <<<"$t" && grep -qF 'Review sharding is on by default' <<<"$t" \
    && grep -qF 'setting it to `0` turns review sharding off' <<<"$t" \
    && ! grep -qiE 'only (when|if) [^.;]*is set|unless [^.;]*is set' <<<"$t"
}
# Offender: the paragraph's default-on sentence reverted to the opt-in text.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { p = 0 }
     p && /^Review sharding is on by default/ { print "Review sharding is opt-in: the program answers `SERIAL:` (exit 3) unless"; next }
     { print }' "$STEP_MD" > "$WORK/step-optin.md"
# Offender: default-on kept, "opt-in" added inside the paragraph. Near-miss: "opt-in" in a
# paragraph of its own after the dispatch paragraph, which the arm must NOT read as a finding.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Older releases made review sharding opt-in."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-optin-in.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) { print; print "Older releases made review sharding opt-in." }; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-optin-out.md"
# Offenders without the word (W4): "only when ... is set" and "unless ... is set" added to the
# paragraph. Near-miss: the same "only when ... is set" sentence in the NEXT paragraph.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Run the partition only when `AI_DLC_REVIEW_SHARD_MIN_FILES` is set; otherwise dispatch one serial reviewer."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-onlywhen.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Dispatch one serial reviewer unless the variable is set."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-unless.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) { print; print "Older releases ran the partition only when the variable is set." }; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-onlywhen-out.md"
_s6s=0
for _f in step-optin.md step-optin-in.md step-optin-out.md step-onlywhen.md step-unless.md step-onlywhen-out.md; do
  cmp -s "$STEP_MD" "$WORK/$_f" && _s6s=1
done
if [ "$_s6s" -ne 0 ]; then
  bad "S6-pre: FIXTURE STALE -- a default-on probe's edit matched nothing, so the probe would score the shipped text"
elif p_step_dflt "$WORK/step-optin.md" || p_step_dflt "$WORK/step-optin-in.md" \
     || p_step_dflt "$WORK/step-onlywhen.md" || p_step_dflt "$WORK/step-unless.md"; then
  bad "S6-pre: FIXTURE BROKEN -- the default-on predicate passed a paragraph reverted to opt-in, carrying 'opt-in', or gating the partition on the variable being set"
elif ! p_step_dflt "$WORK/step-optin-out.md" || ! p_step_dflt "$WORK/step-onlywhen-out.md"; then
  bad "S6-pre: FIXTURE BROKEN -- the default-on predicate refused 'opt-in' or 'only when ... is set' OUTSIDE the dispatch paragraph (near-misses)"
else
  ok "S6-pre: the default-on predicate refuses the reverted sentence, 'opt-in', 'only when ... is set' and 'unless ... is set' inside the paragraph, and accepts 'opt-in' and 'only when ... is set' in the next paragraph"
fi
if p_step_dflt "$STEP_MD"; then
  ok "S6: implementation.md's Gate-1 dispatch paragraph says review sharding is on by default and that \`0\` turns it off, and neither says opt-in nor gates the partition on the variable being set"
else
  bad "S6: implementation.md's Gate-1 dispatch paragraph does not state default-on sharding, or says opt-in, or gates the partition on the variable being set"
fi
if p_step "$STEP_MD"; then
  ok "S1: implementation.md's Gate-1 dispatch paragraph names partition-review-diff.sh and merge-review-shards.sh outside a fence"
else
  bad "S1: implementation.md's Gate-1 dispatch paragraph does not name both programs outside a fence -- the lead is never told to shard"
fi
if p_role "$ROLE_MD"; then
  ok "S2: code-reviewer.md's '## As a Shard' clause names shard-verdict:, reviewed-sha: and parts:, the grammar the merge refuses without"
else
  bad "S2: code-reviewer.md's '## As a Shard' clause does not carry the merge's shard grammar -- a shard written to it is refused at the join"
fi

# GATE 2 AT THE EMISSION SITE. The paragraph implementation.md opens with `**Gate-2 dispatch:`,
# fenced lines dropped, must name the partition, the merge and `--gate qa`; qa.md's `## As a Shard`
# must name the three grammar tokens plus `## Acceptance Criteria`, the one section the merge
# requires of the cross shard. And neither file may carry the serial-gate-2 sentences anywhere:
# `Gate 2 is dispatched serially` (the consumer's receipt is a substring match on qa.md) and
# `it has no shard merge`.
step2_para() { awk '/^```/ { f = !f; next } f { next }
       /^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { exit } p { print }' "$1"; }
p_step2() { local t; t="$(step2_para "$1")"
  [ -n "$t" ] && grep -qF 'partition-review-diff.sh' <<<"$t" && grep -qF 'merge-review-shards.sh' <<<"$t" \
    && grep -qF -- '--gate qa' <<<"$t"; }
p_qrole() { local t; t="$(role_sect "$1")"
  [ -n "$t" ] && grep -qF 'shard-verdict:' <<<"$t" && grep -qF 'reviewed-sha:' <<<"$t" && grep -qF 'parts:' <<<"$t" \
    && grep -qF '## Acceptance Criteria' <<<"$t"; }
# Read WHITESPACE-NORMALISED: the base text wrapped "Gate 2" / "is dispatched serially" across
# two lines, so a per-line match was already true of the tree it was written to refuse.
p_noserial() { local t; t="$(tr -s '[:space:]' ' ' < "$1")"
  ! grep -qiF 'Gate 2 is dispatched serially' <<<"$t" && ! grep -qiF 'it has no shard merge' <<<"$t"; }
sed -e '/^\*\*Gate-2 dispatch:/,/^[[:space:]]*$/s/--gate qa/--gate QA-GONE/g' "$STEP_MD" > "$WORK/step2-strip.md"
{ printf '%s\n' '**Gate-2 dispatch: decoy.** one QA.' '' '```' 'partition-review-diff.sh merge-review-shards.sh --gate qa' '```'; } > "$WORK/step2-fence.md"
sed -e '/^## As a Shard/,/^## /s/## Acceptance Criteria/## AC-GONE/g' "$QA_MD" > "$WORK/qrole-strip.md"
awk '{ print } /^## Context Loading$/ && !d { print ""; print "Gate 2 is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial.md"
awk '{ print } /^\*\*DAR-fold preflight before gate-2 dispatch\.\*\*/ && !d { print "Gate 2 is dispatched `shard: 1/1 <story-index>`; it has no shard merge."; d = 1 }' "$STEP_MD" > "$WORK/step-nomerge.md"
# The serial sentences WRAPPED, each in the shape base shipped: implementation.md's qa bullet broke
# after "Gate 2" (base lines 127-128), and the no-merge clause wrapped after "it has no". A
# per-line match misses all three; that miss is asserted below so the kill is the normalisation's.
awk '/^- \*\*qa\*\* from `qa\.md`\./ && !d { print "- **qa** from `qa.md`. Validates acceptance criteria, runs tests. Gate 2"; print "  is dispatched serially, `shard: 1/1 <story-index>`."; d = 1; next } { print }' \
  "$STEP_MD" > "$WORK/step-serial-wrap.md"
awk '{ print } /^\*\*DAR-fold preflight before gate-2 dispatch\.\*\*/ && !d { print "Gate 2 is dispatched `shard: 1/1 <story-index>`; it has no"; print "shard merge."; d = 1 }' "$STEP_MD" > "$WORK/step-nomerge-wrap.md"
awk '{ print } /^## Context Loading$/ && !d { print ""; print "Gate 2"; print "is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial-wrap.md"
# The serial sentence in LOWER CASE, which an exact-case match misses; that miss is asserted below.
awk '{ print } /^## Context Loading$/ && !d { print ""; print "gate 2 is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial-lower.md"
_s7w=0
grep -qF 'Gate 2 is dispatched serially' "$WORK/qa-serial-lower.md" && _s7w=1
for _f in step-serial-wrap step-nomerge-wrap qa-serial-wrap; do
  grep -qF 'Gate 2 is dispatched serially' "$WORK/$_f.md" && _s7w=1
  grep -qF 'it has no shard merge' "$WORK/$_f.md" && _s7w=1
done
if cmp -s "$STEP_MD" "$WORK/step2-strip.md" || cmp -s "$QA_MD" "$WORK/qrole-strip.md" \
   || cmp -s "$QA_MD" "$WORK/qa-serial.md" || cmp -s "$STEP_MD" "$WORK/step-nomerge.md" \
   || cmp -s "$STEP_MD" "$WORK/step-serial-wrap.md" || cmp -s "$STEP_MD" "$WORK/step-nomerge-wrap.md" \
   || cmp -s "$QA_MD" "$WORK/qa-serial-wrap.md" || cmp -s "$QA_MD" "$WORK/qa-serial-lower.md"; then
  bad "S7-pre: FIXTURE STALE -- a gate-2 structural probe's edit matched nothing, so the probe would score the shipped text"
elif [ "$_s7w" -ne 0 ]; then
  bad "S7-pre: FIXTURE BROKEN -- a wrapped or lowercase serial-sentence copy matches exact-case on one line, so it cannot tell a per-line or case-sensitive predicate from the shipped one"
elif p_step2 "$WORK/step2-strip.md" || p_step2 "$WORK/step2-fence.md" || p_qrole "$WORK/qrole-strip.md" \
     || p_noserial "$WORK/qa-serial.md" || p_noserial "$WORK/step-nomerge.md" \
     || p_noserial "$WORK/step-serial-wrap.md" || p_noserial "$WORK/step-nomerge-wrap.md" \
     || p_noserial "$WORK/qa-serial-wrap.md" || p_noserial "$WORK/qa-serial-lower.md"; then
  bad "S7-pre: FIXTURE BROKEN -- a gate-2 predicate passed a copy missing --gate qa, naming it only in a fence, a role clause missing '## Acceptance Criteria', or a re-inserted serial sentence, one-line, wrapped or lowercase"
else
  ok "S7-pre: the gate-2 predicates refuse a paragraph missing --gate qa, names only inside a fence, a qa clause missing '## Acceptance Criteria', and either serial sentence re-inserted on one line, WRAPPED as base wrapped it (which a per-line match misses), or in lower case (which an exact-case match misses)"
fi
if p_step2 "$STEP_MD"; then
  ok "S7: implementation.md's Gate-2 dispatch paragraph names partition-review-diff.sh, merge-review-shards.sh and --gate qa outside a fence"
else
  bad "S7: implementation.md's Gate-2 dispatch paragraph does not name the partition, the merge and --gate qa outside a fence -- the lead is never told to shard gate 2"
fi
if p_qrole "$QA_MD"; then
  ok "S8: qa.md's '## As a Shard' clause names shard-verdict:, reviewed-sha:, parts: and '## Acceptance Criteria'"
else
  bad "S8: qa.md's '## As a Shard' clause does not carry the merge's QA shard grammar"
fi
_ser=""
p_noserial "$STEP_MD" || _ser="$_ser implementation.md"
p_noserial "$QA_MD" || _ser="$_ser qa.md"
if [ -z "$_ser" ]; then
  ok "S9: neither 'Gate 2 is dispatched serially' nor 'it has no shard merge' appears anywhere in implementation.md or qa.md"
else
  bad "S9: [${_ser# }] still says gate 2 is serial or has no shard merge"
fi

# WHO MAKES THE CLOSING WRITES, AND WHEN. The `done` transition, `deferred_acs` (taken from QA's
# verdict, so unknowable before gate 2), the upstream close-out and the closing commit are made by
# ONE `code-reviewer` the lead dispatches AFTER GATE 3, for every story, serial or sharded -- a
# dispatched agent, so the gate-remediation guard's agent_id arm allows its story-file edit while
# a verdict is FAIL. No gate-1 reviewer makes them, and the lead does not. The gate-1 REVIEW
# commit, which persists the review file Check 1 reads, is a different commit and is unchanged.
#
# PINS, each read as one joined line with `**` dropped so a wrapped or emphasised sentence still
# matches: the step's task item 4 (dispatch, timing, the four duties, the catch-up for a story
# already past gate 3), its Gate-1 paragraph, its section 7 precondition; the role's Ownership
# pointer, Responsibilities bullet, As a Shard sentence and As the Closing Writer brief.
#
# AND A REFUSAL OVER EACH WHOLE FILE, As the Closing Writer included. The file is split into
# clauses at `. ` and `; `. A clause naming a closing write -- `done` transition, `status: done`,
# `deferred_acs`, the closing commit, or the review commit beside `done`/`deferred_acs` -- must have the closing
# writer as its subject, or negate the WRITE VERB itself (`do/does NOT make|perform`). Any other
# " not " acquits nothing. Clauses that only describe the field or the lifecycle (a value of
# `deferred_acs`, a `done` story, Dev's earlier write) are acquitted by enumerated shapes below.
# FALSE-POSITIVE SET, measured on the shipped files before this arm was pinned: every clause the
# grammar flagged was reworded to name its subject, so the shipped set is 0. The enumerated
# acquittals are the narrowing story; widening one widens what a wrong build can say.
joined() { tr '\n' ' ' | tr -s ' ' | sed -e 's/\*\*//g'; }
close_item() { awk '/^4\. Closing writer/ { p = 1 } p && (/^[[:space:]]*$/ || /^### /) { exit } p { print }' "$1"; }
sect7() { awk '/^### 7\. All Gates Passed/ { p = 1; next } p && /^### / { exit } p { print }' "$1"; }
role_named() { # <file> <section heading text> -> that section's body
  awk -v h="## $2" '$0 == h { p = 1; next } p && /^## / { exit } p { print }' "$1"; }
role_bullet() { # <file> <section> <bullet prefix> -> that bullet, continuation lines included
  role_named "$1" "$2" | awk -v b="$3" 'index($0, b) == 1 { p = 1; print; next } p && /^- / { exit } p { print }'; }
p_own_step() { local t g s
  t="$(close_item "$1" | joined)"; g="$(step_para "$1" | joined)"; s="$(sect7 "$1" | joined)"
  grep -qF 'Once gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer, `shard: 1/1 <story-index>`, for every story, serial or sharded.' <<<"$t" \
    && grep -qF 'the closing writer makes exactly these writes and nothing else' <<<"$t" \
    && grep -qF 'deferred_acs` in both sprint-status views taken from the merged QA file'"'"'s `## Deferred ACs`, or the deferred record in the serial file, the upstream close-out section 5 requires, and the closing commit' <<<"$t" \
    && grep -qF 'The lead does NOT make these writes.' <<<"$t" \
    && grep -qF 'The closing writer is also owed to a story already past gate 3 without its closing writes' <<<"$t" \
    && grep -qF 'the lead dispatches it at the lead'"'"'s next turn' <<<"$t" \
    && grep -qF 'A gate-1 reviewer, serial or shard, does NOT make the `done` transition, `deferred_acs` or the closing commit; the closing writer does, after gate 3.' <<<"$g" \
    && grep -qF 'Persisting the gate-1 review file is unchanged' <<<"$g" \
    && grep -qF 'the closing writer has landed every story'"'"'s closing commit, leaving every story `done` with a `deferred_acs` field in both sprint-status views' <<<"$s" \
    && grep -qF 'The closing writer has not run for a story past gate 3 that is still `review`, or `done` with no `deferred_acs` field in a view: dispatch the closing writer now (section 3, item 4)' <<<"$s"; }
p_own_role() { local o r s c
  o="$(role_named "$1" Ownership | joined)"; s="$(role_sect "$1" | joined)"; c="$(role_named "$1" 'As the Closing Writer' | joined)"
  r="$(role_bullet "$1" Responsibilities '- Dispatched as the closing writer' | joined)"
  grep -qF 'The closing writes belong to the closing writer, and only to it.' <<<"$o" \
    && grep -qF 'A gate-1 reviewer — serial `shard: 1/1`, a part shard or the cross shard — does NOT make any of them. After gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer (see "As the Closing Writer")' <<<"$o" \
    && grep -qF 'in the review commit that Check 1 of `gate-validation.md` reads. That is unchanged, and the review commit carries no status write.' <<<"$o" \
    && grep -qF 'the closing writer updates the story file `Status:` header and `sprint-status.yaml` to `done`, writes the story'"'"'s `deferred_acs` beside `status: done` in both views, and makes the upstream close-out, all in the closing commit. As a gate-1 reviewer you do NOT make these writes.' <<<"$r" \
    && grep -qF 'you do NOT make the `done` transition, `deferred_acs` in both sprint-status views, or the closing commit; the closing writer does, after gate 3.' <<<"$s" \
    && grep -qF 'the lead dispatches you after gate 3 passes, for every story, serial or sharded' <<<"$c" \
    && grep -qF 'the closing writer makes exactly these writes and nothing else' <<<"$c" \
    && grep -qF 'the upstream close-out `implementation.md` section 5 requires' <<<"$c" \
    && grep -qF 'and the closing commit carrying all of them.' <<<"$c"; }
# One clause per line. Fenced lines and headings are dropped; `e.g.`/`i.e.` cannot split.
clauses() { awk '/^```/ { f = !f; next } f || /^#/ { next } { print }' "$1" | joined \
  | sed -e 's/e\.g\./eg/g' -e 's/i\.e\./ie/g' | awk '{ gsub(/\. /, ".\n"); gsub(/; /, ";\n"); print }'; }
# 0 when NO clause gives a closing write to anyone but the closing writer. Prints offenders on fd 3.
p_write_refuse() { # <file>
  clauses "$1" | awk '
    { s = tolower($0) }
    { w = (s ~ /`done` transition/ || s ~ /status: done/ || s ~ /deferred_acs/ || s ~ /closing commit/ \
           || (s ~ /review commit/ && (s ~ /`done`/ || s ~ /deferred_acs/))) }
    !w { next }
    s ~ /the closing writer/ { next }                                   # its subject is the writer
    s ~ /(do|does) not (make|perform)/ { next }                         # the WRITE VERB negated
    # Field and lifecycle descriptions, enumerated (the narrowing story):
    s ~ /^`?deferred_acs`? is not one single-line/ { next }
    s ~ /if the story has no deferred ac/ { next }
    s ~ /never a block list/ { next }
    s ~ /deploy-validate §4b clears/ { next }
    s ~ /`?deferred_acs: \[ac5, ac6\]`?\.?$/ { next }
    s ~ /^dev owns the earlier/ { next }
    { print > "/dev/fd/3"; bad = 1 } END { exit bad }'; }
# The header's THRESHOLD paragraph states the default, derived from the assignment, and the off
# spelling, and no longer calls sharding opt-in.
hdr_para() { awk '/^# THRESHOLD/ { p = 1; print; next } p && /^# [^ ]/ { exit } p { print }' "$1"; }
p_hdr() { local t; t="$(hdr_para "$1" | joined)"
  [ -n "$t" ] && ! grep -qi 'opt-in' <<<"$t" && grep -qF "the built-in default $DFLT" <<<"$t" && grep -qF "$KEY=0" <<<"$t"; }
# OFFENDERS, one per pinned or refused property, each a copy guarded by cmp -s.
#   step-early     item 4's dispatch moved before gate 3            (the tip adversary's W1, first round)
#   step-lead      the Gate-1 paragraph hands the writes to the lead
#   step-elsewhere item 4 de-timed, the pinned sentence added under another heading
#   step-noclose   the upstream close-out dropped from item 4's brief          (D1)
#   step-nocatch   the catch-up for a story already past gate 3 dropped       (D3)
#   step-s7        a section-7 clause where the LEAD makes the writes          (W3, step half)
#   role-nopointer the Ownership pointer bullet deleted                         (W2, first round)
#   role-resp      the Responsibilities bullet reverted to the pre-change text (W2)
#   role-incw      a clause INSIDE As the Closing Writer giving the serial gate-1 reviewer the writes (W1)
#   role-notlead   a clause giving the cross shard the writes, carrying an unrelated " not " (W3)
# NEAR-MISSES, which must pass:
#   role-negated   the role-notlead clause with its WRITE VERB negated
#   step-negated   a section-7 clause where the lead does NOT make the writes
sed -e 's/Once gate 3 passes, the lead/Once gate 2 passes, the lead/' "$STEP_MD" > "$WORK/own-step-early.md"
sed -e '/^\*\*Gate-1 dispatch:/,/^[[:space:]]*$/s/the closing writer does, after gate 3\./the lead performs them after the merge./' "$STEP_MD" > "$WORK/own-step-lead.md"
sed -e 's/Once gate 3 passes, the lead/Once gate 2 passes, the lead/' "$STEP_MD" \
  | awk '/^### 4\. Self-Validate/ { print "Once gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer, `shard: 1/1 <story-index>`, for every story, serial or sharded."; print "" } { print }' \
  > "$WORK/own-step-elsewhere.md"
sed -e 's/^   upstream close-out section 5 requires, and the closing commit carrying$/   and the closing commit carrying/' "$STEP_MD" > "$WORK/own-step-noclose.md"
# The pre-change sentence, line for line: "taken from QA's verdict, the upstream close-out ...".
awk '/^   `deferred_acs` in both sprint-status views taken from the merged QA file.s$/ { print "   `deferred_acs` in both sprint-status views taken from QA'"'"'s verdict, the"; skip = 1; next }
     skip { skip = 0; next } { print }' "$STEP_MD" > "$WORK/own-step-qaverdict.md"
sed -e 's/The closing writer is also owed to a story/A story is also owed/' "$STEP_MD" > "$WORK/own-step-nocatch.md"
awk '/^### 7\. All Gates Passed/ { print; print ""; print "Before routing, the lead writes `status: done` and `deferred_acs` for every story itself and makes the closing commit."; next } { print }' \
  "$STEP_MD" > "$WORK/own-step-s7.md"
awk '/^### 7\. All Gates Passed/ { print; print ""; print "Before routing, the lead does NOT make the `done` transition or the closing commit for any story."; next } { print }' \
  "$STEP_MD" > "$WORK/own-step-negated.md"
awk '/^- \*\*The closing writes belong to the closing writer/ { skip = 1; next }
     skip && /^- / { skip = 0 } !skip { print }' "$ROLE_MD" > "$WORK/own-role-nopointer.md"
awk '/^- Dispatched as the closing writer after gate 3 passes/ { skip = 1
       print "- After approving the final gate for a story, update `sprint-status.yaml`"
       print "  and the story file `Status:` header to `done` in the review commit, with"
       print "  the story'"'"'s `deferred_acs` written beside `status: done` in both views."; next }
     skip && (/^- / || /^$/) { skip = 0 } !skip { print }' "$ROLE_MD" > "$WORK/own-role-resp.md"
awk '{ print } /^the story file and to `carry-over-backlog\.md`\.$/ && !d { print "A gate-1 serial reviewer that approves makes the `done` transition, `deferred_acs` and the closing commit itself at gate 1; dispatch a closing writer only for a sharded review."; d = 1 }' \
  "$ROLE_MD" > "$WORK/own-role-incw.md"
awk '/^## Constraints$/ { print "As the cross shard you make the closing commit and the `done` transition, not the lead."; print "" } { print }' \
  "$ROLE_MD" > "$WORK/own-role-notlead.md"
awk '/^## Constraints$/ { print "As the cross shard you do NOT make the closing commit or the `done` transition."; print "" } { print }' \
  "$ROLE_MD" > "$WORK/own-role-negated.md"
sed -e '/^# THRESHOLD/s/ON BY DEFAULT/OPT-IN/' "$PART" > "$WORK/hdr-optin.sh"
sed -e "/^# THRESHOLD/,/^# THE PART SET/s/the built-in default $DFLT/the built-in default $((DFLT + 1))/" "$PART" > "$WORK/hdr-num.sh"
_stale=0
grep -qF 'Once gate 2 passes, the lead' "$WORK/own-step-elsewhere.md" || { _stale=1; echo "  (item 4 not de-timed in own-step-elsewhere.md)"; }
for _p in "$STEP_MD:own-step-early.md" "$STEP_MD:own-step-lead.md" "$STEP_MD:own-step-elsewhere.md" \
          "$STEP_MD:own-step-noclose.md" "$STEP_MD:own-step-qaverdict.md" "$STEP_MD:own-step-nocatch.md" "$STEP_MD:own-step-s7.md" "$STEP_MD:own-step-negated.md" \
          "$ROLE_MD:own-role-nopointer.md" "$ROLE_MD:own-role-resp.md" "$ROLE_MD:own-role-incw.md" \
          "$ROLE_MD:own-role-notlead.md" "$ROLE_MD:own-role-negated.md" \
          "$PART:hdr-optin.sh" "$PART:hdr-num.sh"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _stale=1; echo "  (unchanged probe: ${_p#*:})"; }
done
# Each offender must be refused by the arm that OWNS it; the pins and the refusal are scored apart
# so a wrong build that slips one is still named.
_own_fail=""
for _o in own-step-early own-step-lead own-step-elsewhere own-step-noclose own-step-qaverdict own-step-nocatch; do
  p_own_step "$WORK/$_o.md" && _own_fail="$_own_fail $_o"
done
p_write_refuse "$WORK/own-step-s7.md" 3>/dev/null && _own_fail="$_own_fail own-step-s7"
p_own_role "$WORK/own-role-nopointer.md" && _own_fail="$_own_fail own-role-nopointer"
p_own_role "$WORK/own-role-resp.md" && _own_fail="$_own_fail own-role-resp(pin)"
p_write_refuse "$WORK/own-role-resp.md" 3>/dev/null && _own_fail="$_own_fail own-role-resp(refuse)"
p_write_refuse "$WORK/own-role-incw.md" 3>/dev/null && _own_fail="$_own_fail own-role-incw"
p_write_refuse "$WORK/own-role-notlead.md" 3>/dev/null && _own_fail="$_own_fail own-role-notlead"
p_hdr "$WORK/hdr-optin.sh" && _own_fail="$_own_fail hdr-optin"
p_hdr "$WORK/hdr-num.sh" && _own_fail="$_own_fail hdr-num"
_nm_fail=""
{ p_write_refuse "$WORK/own-role-negated.md" 3>/dev/null && p_own_role "$WORK/own-role-negated.md"; } || _nm_fail="$_nm_fail own-role-negated"
{ p_write_refuse "$WORK/own-step-negated.md" 3>/dev/null && p_own_step "$WORK/own-step-negated.md"; } || _nm_fail="$_nm_fail own-step-negated"
if [ "$_stale" -ne 0 ]; then
  bad "S3-pre: FIXTURE STALE -- an ownership or header probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_own_fail" ]; then
  bad "S3-pre: FIXTURE BROKEN -- an ownership or header predicate passed offender(s) [${_own_fail# }]"
elif [ -n "$_nm_fail" ]; then
  bad "S3-pre: FIXTURE BROKEN -- a predicate refused near-miss(es) [${_nm_fail# }], a clause whose write verb is negated"
else
  ok "S3-pre: 13 offenders refused by the arm that owns each (dispatch before gate 3, writes to the lead, dispatch outside item 4, no close-out, deferred_acs taken from 'QA's verdict' rather than the merged file's '## Deferred ACs', no catch-up, a lead-writes clause in section 7, no Ownership pointer, the Responsibilities bullet reverted, a contradiction inside As the Closing Writer, an unrelated 'not', OPT-IN, another number); 2 near-misses with the write verb negated pass"
fi
if p_own_step "$STEP_MD"; then
  ok "S3: implementation.md's item 4 dispatches the closing writer after gate 3 for every story with its four duties and the catch-up, the Gate-1 paragraph gives no gate-1 reviewer the writes and keeps review-file persistence, and section 7 routes only after every closing commit"
else
  bad "S3: implementation.md does not pin the post-gate-3 closing writer at item 4, the Gate-1 paragraph and section 7"
fi
if p_own_role "$ROLE_MD"; then
  ok "S4: code-reviewer.md's Ownership, Responsibilities, As a Shard and As the Closing Writer give the closing writes to the closing writer alone, after gate 3, upstream close-out included, and keep the review commit"
else
  bad "S4: code-reviewer.md does not give the closing writes to the post-gate-3 closing writer at all four sites"
fi
_sref=""
p_write_refuse "$ROLE_MD" 3>/dev/null || _sref="$_sref code-reviewer.md"
p_write_refuse "$STEP_MD" 3>/dev/null || _sref="$_sref implementation.md"
if [ -z "$_sref" ]; then
  ok "S4b: no clause in code-reviewer.md or implementation.md, As the Closing Writer included, gives a closing write to anyone but the closing writer unless its write verb is negated"
else
  bad "S4b: a clause in [${_sref# }] gives a closing write to a subject other than the closing writer"
fi
if p_hdr "$PART"; then
  ok "S5: partition-review-diff.sh's THRESHOLD paragraph states the built-in default $DFLT and $KEY=0, and does not say opt-in"
else
  bad "S5: partition-review-diff.sh's THRESHOLD paragraph still says opt-in, or does not state the default $DFLT and the off spelling"
fi

# A PART SHARD'S WORKTREE HAS NO DEPENDENCIES, AND A PART SHARD DELIVERS A PATH, NOT ROWS. A fresh
# `git worktree add --detach` carries none of the project's gitignored dependencies, so a RED
# replayed there without setup fails for a reason the mutation does not own -- measured on the
# reference consumer: its canonical interpreter is absent (rc 127) until its documented setup
# runs (rc 0). PINS, each read joined with `**` dropped, at the two emission sites: qa.md's
# `## As a Shard` (setup first, GREEN baseline before any mutation, the hand-over to the cross
# shard as a `#### ` finding, and the cross shard owning the handed-over replays), the Gate-2
# dispatch paragraph (the same three duties), and qa.md's "Deliver before idle" bullet (a part
# shard delivers its shard file path and shard-verdict, never per-AC rows).
p_qsetup_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'in it you first run the project'"'"'s canonical dependency setup, the setup the dev'"'"'s QA Handoff Evidence records or else the story'"'"'s documented setup, and confirm the canonical run of the anchor'"'"'s test is GREEN there before any mutation.' <<<"$t" \
    && grep -qF 'An AC whose replay cannot reach a GREEN baseline in your worktree is handed to the cross shard rather than scored: list it under `## Findings` as a `#### ` finding citing `parts: <your ordinal>` that names the AC and the reason.' <<<"$t" \
    && grep -qF 'the RED replays for any AC whose anchor lies in no part'"'"'s files or that a part shard handed over' <<<"$t"; }
p_qsetup_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'a part QA first runs the project'"'"'s canonical dependency setup (the setup the dev'"'"'s QA Handoff Evidence records, or the story'"'"'s documented setup) and confirms the canonical run of the anchor'"'"'s test is GREEN there before any mutation.' <<<"$t" \
    && grep -qF 'An AC whose replay cannot reach a GREEN baseline in the part'"'"'s worktree is handed to the first cross QA, listed under the part shard'"'"'s findings with its reason, rather than scored.' <<<"$t" \
    && grep -qF 'the RED replays a part QA handed over' <<<"$t"; }
p_qdeliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'A part shard delivers its shard file'"'"'s absolute path and its `shard-verdict:` value instead, never per-AC rows, which only the first cross shard writes.' <<<"$t"; }
# OFFENDERS: each obligation dropped at its site; and each moved OUT of its section (into the
# paragraph after it), which a whole-file grep would still accept.
sed -e 's/^it you first run the project.s canonical dependency setup, the setup the dev.s$/it you run the replays directly, the setup the dev'"'"'s/' "$QA_MD" > "$WORK/qs-role-nosetup.md"
sed -e 's/^the canonical run of the anchor.s test is GREEN there before any mutation\. An$/the mutation directly. An/' "$QA_MD" > "$WORK/qs-role-nogreen.md"
sed -e 's/^AC whose replay cannot reach a GREEN baseline in your worktree is handed to the$/AC whose replay cannot reach a GREEN baseline in your worktree is scored REJECT by the/' "$QA_MD" > "$WORK/qs-role-nohand.md"
sed -e 's/^part.s files or that a part shard handed over, and the interactions between$/part'"'"'s files, and the interactions between/' "$QA_MD" > "$WORK/qs-role-nocross.md"
sed -e 's/^first runs the project.s canonical dependency setup (the setup the dev.s QA$/first runs the replays (the setup the dev'"'"'s QA/' "$STEP_MD" > "$WORK/qs-step-nosetup.md"
sed -e 's/^whose replay cannot reach a GREEN baseline in the part.s worktree is handed to$/whose replay cannot reach a GREEN baseline in the part'"'"'s worktree is REJECTed, not handed to/' "$STEP_MD" > "$WORK/qs-step-nohand.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "In that worktree a part QA first runs the project'"'"'s canonical dependency setup (the setup the dev'"'"'s QA Handoff Evidence records, or the story'"'"'s documented setup) and confirms the canonical run of the anchor'"'"'s test is GREEN there before any mutation."; d = 1; p = 0 }
     /^first runs the project.s canonical dependency setup \(the setup the dev.s QA$/ { print "first runs the replays (the setup the dev'"'"'s QA"; next } { print }' "$STEP_MD" > "$WORK/qs-step-moved.md"
# The moved copy must not still carry the sentence in place: assert the in-paragraph edit applied.
grep -q '^first runs the replays (the setup the dev.s QA$' "$WORK/qs-step-moved.md" || cp "$STEP_MD" "$WORK/qs-step-moved.md"
sed -e 's/^  path and its `shard-verdict:` value instead, never per-AC rows, which only$/  path, its `shard-verdict:` value and its per-AC rows, which only/' "$QA_MD" > "$WORK/qs-deliver-rows.md"
_s10s=0
for _p in "$QA_MD:qs-role-nosetup.md" "$QA_MD:qs-role-nogreen.md" "$QA_MD:qs-role-nohand.md" "$QA_MD:qs-role-nocross.md" \
          "$STEP_MD:qs-step-nosetup.md" "$STEP_MD:qs-step-nohand.md" "$STEP_MD:qs-step-moved.md" "$QA_MD:qs-deliver-rows.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s10s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s10f=""
for _o in qs-role-nosetup qs-role-nogreen qs-role-nohand qs-role-nocross; do p_qsetup_role "$WORK/$_o.md" && _s10f="$_s10f $_o"; done
for _o in qs-step-nosetup qs-step-nohand qs-step-moved; do p_qsetup_step "$WORK/$_o.md" && _s10f="$_s10f $_o"; done
p_qdeliver "$WORK/qs-deliver-rows.md" && _s10f="$_s10f qs-deliver-rows"
if [ "$_s10s" -ne 0 ]; then
  bad "S10-pre: FIXTURE STALE -- a part-shard setup or delivery probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s10f" ]; then
  bad "S10-pre: FIXTURE BROKEN -- a part-shard setup or delivery predicate passed offender(s) [${_s10f# }]"
else
  ok "S10-pre: 8 offenders refused (setup, GREEN baseline, hand-over or cross ownership dropped from qa.md; setup or hand-over dropped from the Gate-2 paragraph; setup moved out of that paragraph; a part shard delivering per-AC rows)"
fi
_s10=""
p_qsetup_role "$QA_MD" || _s10="$_s10 qa.md-As-a-Shard"
p_qsetup_step "$STEP_MD" || _s10="$_s10 implementation.md-Gate-2-dispatch"
p_qdeliver "$QA_MD" || _s10="$_s10 qa.md-Deliver-before-idle"
if [ -z "$_s10" ]; then
  ok "S10: qa.md's As a Shard and implementation.md's Gate-2 paragraph make a part shard run the canonical dependency setup and reach a GREEN baseline before any mutation, hand an unreachable AC to the cross shard, and the cross shard owns it; a part shard delivers its shard path and shard-verdict, not per-AC rows"
else
  bad "S10: [${_s10# }] does not carry the part shard's dependency setup, GREEN baseline, hand-over, or path-and-verdict delivery"
fi

# A HAND-OVER IS RUN BY NOBODY UNLESS THE CROSS QA IS DISPATCHED AFTER THE PARTS AND TOLD TO READ
# THEM. Parts and cross in one wave left the cross shard no file to read, and nothing told it to
# read one. PINS, joined with `**` dropped, at the emission sites: the Gate-2 paragraph (parts
# first, cross only after every part shard file exists, its brief naming them, and the cross QA
# reading them for `handover:` lines before scoring); qa.md's As a Shard (the hand-over's
# `handover:` line under `### Important`, never a Deferred container, and the cross shard reading
# every part shard and writing `handover-run:`); the Deliver-before-idle bullet (the first cross
# shard, cross-1, delivers the count of hand-overs it ran).
p_ho_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'ONE cross QA, briefed `shard: cross/<K> g1/1 <ordinals>` (K = N, `<ordinals>` every ordinal 1..K comma-joined without padding) with the whole map and the whole diff to read, writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in the first wave whatever the cap leaves for the rest, and the first cross QA'"'"'s brief names the absolute path of every part shard file, the round'"'"'s epoch and a beat state directory of its own' <<<"$t" \
    && grep -qF 'the first cross QA in the first wave whatever the cap leaves for the rest' <<<"$t" \
    && grep -qF 'and only then joins the part shard files itself with `AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete --since <epoch> <part paths>`' <<<"$t" \
    && grep -qF 'Once that join completes, the first cross QA reads every part shard file for `handover:` lines, runs each handed-over replay and records it as a `handover-run:` line' <<<"$t"; }
p_ho_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'The hand-over finding goes under `### Important`, never under a `### Deferred` container, and carries exactly one column-0 `handover: <AC-id>` line beside its `parts:` line.' <<<"$t" \
    && grep -qF 'You are dispatched in the same wave as the part shards, so the part files may not exist yet.' <<<"$t" \
    && grep -qF 'scripts/ai-dlc/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`, run in the background and re-armed until every path is DELIVERED.' <<<"$t" \
    && grep -qF 'Once the join completes, the cross shard reads every part shard `<ordinal>.md` its brief names for `handover:` lines, runs each handed-over replay in the frozen worktree after the project'"'"'s canonical dependency setup, and records each one as a column-0 `handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>` line' <<<"$t"; }
p_ho_deliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'The first cross shard (`cross`, or `cross-1` of a per-group set) delivers its shard file'"'"'s absolute path, its `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows stay in the file.' <<<"$t"; }
# OFFENDERS: the parts-first (two-wave) dispatch restored; the cross QA's own --complete join
# dropped; the cross-read dropped from each site; the hand-over placed under Deferred; the
# same-wave sentence moved out of its paragraph; the cross delivery dropped.
sed -e 's/^writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in$/writing `cross.md` there, is dispatched only after every part shard file exists, the first cross QA in/' "$STEP_MD" > "$WORK/ho-step-onewave.md"
sed -e 's/^`AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete --since <epoch> <part paths>`,$/`AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete <part paths>`,/' "$STEP_MD" > "$WORK/ho-step-nojoin.md"
sed -e 's/^the first wave whatever the cap leaves for the rest, and the first cross QA.s$/the wave after the parts, and the first cross QA'"'"'s/' "$STEP_MD" > "$WORK/ho-step-latewave.md"
sed -e 's/^completes, the first cross QA reads every part shard file for `handover:` lines, runs each$/completes, the first cross QA may read a part shard file for `handover:` lines, runs each/' "$STEP_MD" > "$WORK/ho-step-noread.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "ONE cross QA, briefed `shard: cross/<K> g1/1 <ordinals>` (K = N, `<ordinals>` every ordinal 1..K comma-joined without padding) with the whole map and the whole diff to read, writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in the first wave whatever the cap leaves for the rest, and the first cross QA'"'"'s brief names the absolute path of every part shard file, the round'"'"'s epoch and a beat state directory of its own"; d = 1; p = 0 }
     /^writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in$/ { print "writing `cross.md` there, is dispatched only after every part shard file exists, the first cross QA in"; next } { print }' "$STEP_MD" > "$WORK/ho-step-moved.md"
grep -q '^writing `cross.md` there, is dispatched only after every part shard file exists' "$WORK/ho-step-moved.md" || cp "$STEP_MD" "$WORK/ho-step-moved.md"
sed -e 's/^`### Important`, never under a `### Deferred` container, and carries exactly$/`### Deferred ACs`, and carries exactly/' "$QA_MD" > "$WORK/ho-role-deferred.md"
sed -e 's/^the join completes, the cross shard reads every part shard$/the join completes, the cross shard may read a part shard/' "$QA_MD" > "$WORK/ho-role-noread.md"
sed -e 's/^scripts\/ai-dlc\/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`,$/scripts\/ai-dlc\/wait-for-deliverable.sh --complete <part paths>`,/' "$QA_MD" > "$WORK/ho-role-nojoin.md"
sed -e 's/^  `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows$/  `shard-verdict:` value; its per-AC rows/' "$QA_MD" > "$WORK/ho-deliver-nocount.md"
_s11s=0
for _p in "$STEP_MD:ho-step-onewave.md" "$STEP_MD:ho-step-nojoin.md" "$STEP_MD:ho-step-latewave.md" "$STEP_MD:ho-step-noread.md" "$STEP_MD:ho-step-moved.md" \
          "$QA_MD:ho-role-deferred.md" "$QA_MD:ho-role-noread.md" "$QA_MD:ho-role-nojoin.md" "$QA_MD:ho-deliver-nocount.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s11s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s11f=""
for _o in ho-step-onewave ho-step-nojoin ho-step-latewave ho-step-noread ho-step-moved; do p_ho_step "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
for _o in ho-role-deferred ho-role-noread ho-role-nojoin; do p_ho_role "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
p_ho_deliver "$WORK/ho-deliver-nocount.md" && _s11f="$_s11f ho-deliver-nocount"
if [ "$_s11s" -ne 0 ]; then
  bad "S11-pre: FIXTURE STALE -- a hand-over ordering or cross-read probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s11f" ]; then
  bad "S11-pre: FIXTURE BROKEN -- a hand-over ordering or cross-read predicate passed offender(s) [${_s11f# }]"
else
  ok "S11-pre: 9 offenders refused (the cross QAs dispatched after the parts; the first cross QA out of the first wave; the cross QA's join without --since at the Gate-2 paragraph and at qa.md; the cross read dropped from each; the same-wave sentence moved out of the paragraph; the hand-over under '### Deferred ACs'; the cross delivery without its hand-over count)"
fi
_s11=""
p_ho_step "$STEP_MD" || _s11="$_s11 implementation.md-Gate-2-dispatch"
p_ho_role "$QA_MD" || _s11="$_s11 qa.md-As-a-Shard"
p_ho_deliver "$QA_MD" || _s11="$_s11 qa.md-Deliver-before-idle"
if [ -z "$_s11" ]; then
  ok "S11: the Gate-2 paragraph dispatches the cross QAs in the same wave as the parts, has the first cross QA join the part files with its own --complete beat and only then read them for hand-overs; qa.md says the same, places a hand-over under '### Important' and has the cross shard write 'handover-run:'; the cross shard delivers its hand-over count"
else
  bad "S11: [${_s11# }] does not carry the same-wave dispatch, the cross shard's own join, its hand-over read, or its hand-over count"
fi

# GATE 1 SHARDS ITS MUTATION-RED REPLAYS. Pinned at the two emission sites, read joined: the
# Gate-1 paragraph (one wave; each part reviewer replays its own part's REDs in its own detached
# worktree and declares `handovers: <n>`; the first cross reviewer joins the parts before running
# the hand-overs) and code-reviewer.md's As a Shard. A REVERT to "part reviewers EXECUTE NOTHING"
# is refused at both sites.
p_cr_step() { local t; t="$(step_para "$1" | joined)"
  ! grep -qi 'Part reviewers EXECUTE NOTHING' <<<"$t" \
    && grep -qF '(Rule 28, "Split dispatch": files axis), all in the same wave and the first cross reviewer in the first wave.' <<<"$t" \
    && grep -qF 'Each part reviewer replays, with `validate-mutation-red.sh`, the mutation-REDs whose anchor file lies in its part, in its own detached worktree at the frozen sha after the project'"'"'s canonical dependency setup' <<<"$t" \
    && grep -qF 'every part shard carries one header line `handovers: <n>`, `0` when it handed nothing over.' <<<"$t" \
    && grep -qF 'joins the part shard files as the first cross QA does below and runs every handed-over replay there, recorded as `handover-run:` lines' <<<"$t"; }
p_cr_role() { local t; t="$(role_sect "$1" | joined)"
  ! grep -qi 'As a part shard you EXECUTE NOTHING' <<<"$t" \
    && grep -qF 'in your OWN detached worktree at the frozen sha (`git worktree add --detach <tmp> <sha>`), never in the shared frozen worktree' <<<"$t" \
    && grep -qF 'As a part shard you also carry one column-0 `handovers: <n>` line beside `reviewed-sha:`, `0` when you handed nothing over.' <<<"$t" \
    && grep -qF 'scripts/ai-dlc/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`, backgrounded and re-armed until each is DELIVERED.' <<<"$t" \
    && grep -qF '`handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>`' <<<"$t"; }
sed -e 's/^Part reviewers run no suite and no build\. Each part reviewer replays, with$/Part reviewers EXECUTE NOTHING. Each part reviewer replays, with/' "$STEP_MD" > "$WORK/cr-step-exec.md"
sed -e 's/^(Rule 28, "Split dispatch": files axis), all in the same wave and$/(Rule 28, "Split dispatch": files axis), and/' "$STEP_MD" > "$WORK/cr-step-wave.md"
sed -e 's/^one header line `handovers: <n>`, `0` when it handed nothing over\. The first$/one header line, `0` when it handed nothing over. The first/' "$STEP_MD" > "$WORK/cr-step-nocount.md"
sed -e 's/^`parts:` set\. As a part shard you run no suite and no build\. You replay,$/`parts:` set. As a part shard you EXECUTE NOTHING. You replay,/' "$ROLE_MD" > "$WORK/cr-role-exec.md"
sed -e 's/^(`git worktree add --detach <tmp> <sha>`), never in the shared frozen$/in the shared frozen/' "$ROLE_MD" > "$WORK/cr-role-shared.md"
sed -e 's/^scripts\/ai-dlc\/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`,$/scripts\/ai-dlc\/wait-for-deliverable.sh --complete <part paths>`,/' "$ROLE_MD" > "$WORK/cr-role-nojoin.md"
_s13s=0
for _p in "$STEP_MD:cr-step-exec.md" "$STEP_MD:cr-step-wave.md" "$STEP_MD:cr-step-nocount.md" \
          "$ROLE_MD:cr-role-exec.md" "$ROLE_MD:cr-role-shared.md" "$ROLE_MD:cr-role-nojoin.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s13s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s13f=""
for _o in cr-step-exec cr-step-wave cr-step-nocount; do p_cr_step "$WORK/$_o.md" && _s13f="$_s13f $_o"; done
for _o in cr-role-exec cr-role-shared cr-role-nojoin; do p_cr_role "$WORK/$_o.md" && _s13f="$_s13f $_o"; done
if [ "$_s13s" -ne 0 ]; then
  bad "S13-pre: FIXTURE STALE -- a gate-1 execution-sharding probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s13f" ]; then
  bad "S13-pre: FIXTURE BROKEN -- a gate-1 execution-sharding predicate passed offender(s) [${_s13f# }]"
else
  ok "S13-pre: 6 offenders refused (part reviewers EXECUTE NOTHING restored at each site; the same wave dropped; the declared count dropped; the replay moved into the shared frozen worktree; the cross reviewer's re-armed join dropped)"
fi
_s13=""
p_cr_step "$STEP_MD" || _s13="$_s13 implementation.md-Gate-1-dispatch"
p_cr_role "$ROLE_MD" || _s13="$_s13 code-reviewer.md-As-a-Shard"
if [ -z "$_s13" ]; then
  ok "S13: the Gate-1 paragraph and code-reviewer.md's As a Shard dispatch every reviewer in one wave, have each part reviewer replay its part's mutation-REDs in its own detached worktree and declare 'handovers: <n>', and have the first cross reviewer join the parts before running the hand-overs"
else
  bad "S13: [${_s13# }] does not shard gate 1's mutation-RED replays across the part reviewers"
fi

# THE DECLARED COUNT AT THE EMISSION SITES. A part shard written to qa.md or briefed from the Gate-2
# paragraph without `handovers: <n>` is refused at the join, so both sites must tell it to write
# one: qa.md's `## As a Shard` and the Gate-2 dispatch paragraph, read joined with `**` dropped.
p_hc_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'A part shard also carries, beside those two lines, exactly one column-0 `handovers: <n>` line counting its hand-overs however written, `0` when it handed nothing over; the cross shard carries none.' <<<"$t"; }
p_hc_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'every part shard carries one header line `handovers: <n>` counting its hand-overs, `0` when it handed nothing over (the grammar is `merge-review-shards.sh`'"'"'s header).' <<<"$t"; }
sed -e 's/^exactly one column-0 `handovers: <n>` line counting its hand-overs however written, `0`$/exactly one column-0 line counting its hand-overs however written, `0`/' "$QA_MD" > "$WORK/hc-role-strip.md"
sed -e 's/^shard carries one header line `handovers: <n>` counting its hand-overs, `0` when$/shard counts its hand-overs, `0` when/' "$STEP_MD" > "$WORK/hc-step-strip.md"
if cmp -s "$QA_MD" "$WORK/hc-role-strip.md" || cmp -s "$STEP_MD" "$WORK/hc-step-strip.md"; then
  bad "S12-pre: FIXTURE STALE -- a declared-count probe's edit matched nothing, so the probe would score the shipped text"
elif p_hc_role "$WORK/hc-role-strip.md" || p_hc_step "$WORK/hc-step-strip.md"; then
  bad "S12-pre: FIXTURE BROKEN -- a declared-count predicate passed a copy with 'handovers: <n>' removed"
else
  ok "S12-pre: the declared-count predicates refuse qa.md's As a Shard and the Gate-2 paragraph with 'handovers: <n>' removed"
fi
_s12=""
p_hc_role "$QA_MD" || _s12="$_s12 qa.md-As-a-Shard"
p_hc_step "$STEP_MD" || _s12="$_s12 implementation.md-Gate-2-dispatch"
# XC-STEP (BL-808): every literal partition invocation in implementation.md -- gate 1, the pass-M>=2
# re-review, the narrowed re-review (BL-809 item 2) and gate 2 -- passes --exclude-captures ON THE SAME
# LINE as its `--map <worktree>`. The invocation count is held to exactly 4 (the control: a count below 4 means an invocation lost its
# literal and the per-line join would pass on fewer), and the flagged count must equal it. The
# offender drops the flag from the FIRST invocation only, on a copy.
xc_step_counts() { # <file> -> "<invocations> <flagged>"
  local a b
  a="$(grep -cF -- 'partition-review-diff.sh --map <worktree>' "$1")" || a=0
  b="$(grep -F -- 'partition-review-diff.sh --map <worktree>' "$1" | grep -cF -- '--exclude-captures')" || b=0
  printf '%s %s' "$a" "$b"
}
p_xc_step() { [ "$(xc_step_counts "$1")" = "0 0" ]; }
# gate-transition.sh now runs every partition call, so the step file carries none: a literal
# invocation reappearing there is a second, unflagged path beside the program.
{ cat "$STEP_MD"; printf '%s\n' 'partition-review-diff.sh --map <worktree> <base> <sha>'; } > "$WORK/xc-step-drop.md"
if cmp -s "$STEP_MD" "$WORK/xc-step-drop.md"; then
  bad "XC-STEP-pre: FIXTURE STALE -- the literal-invocation offender did not change the copy"
elif p_xc_step "$WORK/xc-step-drop.md"; then
  bad "XC-STEP-pre: FIXTURE BROKEN -- the step pin passed a copy carrying a literal unflagged partition invocation ($(xc_step_counts "$WORK/xc-step-drop.md"))"
else
  ok "XC-STEP-pre: the step pin refuses a copy carrying a literal unflagged partition invocation ($(xc_step_counts "$WORK/xc-step-drop.md"))"
fi
if p_xc_step "$STEP_MD"; then
  ok "XC-STEP: implementation.md carries no literal 'partition-review-diff.sh --map <worktree>' invocation; gate-transition.sh owns them"
else
  bad "XC-STEP: implementation.md's partition invocations and flagged ones read [$(xc_step_counts "$STEP_MD")], want [0 0]"
fi
if [ -z "$_s12" ]; then
  ok "S12: qa.md's As a Shard and implementation.md's Gate-2 paragraph tell every part shard to write 'handovers: <n>', 0 when it handed nothing over"
else
  bad "S12: [${_s12# }] does not tell a part shard to write its declared 'handovers: <n>' count"
fi

# --- 4j. derive-stories wiring and remedy prose (moved from story-fields-derive) ----------------
# Moved here so story-fields-derive keys only on the program it drives; this fixture already
# keys the whole skill tree, so the arms add no input row anywhere.
#
# THE MODE IS INVOKED BY A STEP FILE. v0.238.0, and it is the defect graph named
# as its second reason for not retiring: `derive-stories` had 0 invocation sites in the consumer
# against 9 for the generator it replaces, so retiring the consumer arm would have removed the
# only live enforcement of frontmatter-as-SSOT and put nothing in its place. A capability with no
# invocation site is not delivered, whatever the pull report says.
#
# BOTH SITES ARE ASSERTED AND THEY ARE DIFFERENT MODES ON PURPOSE. The gate runs `--check`, which
# reports and never writes; the write belongs where a human is already editing the story. A gate
# that edits the artifact it validates can pass a tree it just changed.
DS_STEPS="$SKILL_DIR/steps"
grep -rq -- 'sprint-status.sh derive-stories --check' "$DS_STEPS/gate-validation.md" 2>/dev/null \
  && ok "the gate invokes derive-stories in its READ-ONLY mode (--check)" \
  || bad "no gate step invokes derive-stories --check — the mode ships and nothing runs it"
# THE BACKTICK IS THE TERMINATOR, not end-of-line. Every command in these step files is written
# inside a code span, so an arm anchored on `$` matches nothing and reads exactly like a wiring
# that is present. The first cut of these two arms was anchored that way: one reported UNMUTATED
# under its own mutant — caught — and the other went GREEN under a mutation that added the
# writing form to the gate, which is the failure it exists to prevent.
grep -rq -- 'sprint-status.sh derive-stories`' "$DS_STEPS/implementation.md" 2>/dev/null \
  && ok "the WRITE is invoked from the authoring step, not from the gate" \
  || bad "no authoring step invokes the write — the derive can only ever be run by hand"
# The control: the gate must NOT carry the writing form. This is the arm that would catch a
# future edit collapsing the two sites into one.
grep -rq -- 'sprint-status.sh derive-stories`' "$DS_STEPS/gate-validation.md" 2>/dev/null \
  && bad "the GATE invokes the writing form — a gate that edits what it validates can pass a tree it just changed" \
  || ok "the gate does NOT carry the writing form (the read/write split is asserted, not assumed)"
# THE REMEDY PROSE AND THE TOOL AGREE ON WHAT THE TOOL DOES. The step file names
# this mode as the repair for a stale entry, so its description of the mode is part of the
# mode's contract: prose promising a capability the program refuses sends a session down a
# no-op and costs it a hand transcription. The PRESENCE arm is first and it is what makes the
# ABSENCE arm below safe — a missing or unreadable gate-validation.md reddens the presence arm
# rather than acquitting the absence one.
grep -q -- 'and NEVER creates one' "$DS_STEPS/gate-validation.md" 2>/dev/null \
  && ok "Check 5's stale-entry remedy states that derive-stories never creates an entry" \
  || bad "the gate's stale-entry remedy does not say the mode cannot create an entry — the prose promises what exit 3 refuses"
grep -q -- 'writes the entry from the story file' "$DS_STEPS/gate-validation.md" 2>/dev/null \
  && bad "the gate still describes derive-stories as writing the ENTRY from the story file — it writes VALUES into an entry that already exists" \
  || ok "the gate no longer describes the mode as writing the entry itself"
# THE NEGATIVE GREP IS A LITERAL AND IT IS NOT A COVERAGE CLAIM. The same wrong promise restated
# in new words — "the derive will lay the entry down for you" — passes both arms above. That is
# a stated limit, not a gap to close by enumerating wordings: a list of phrasings goes vacuous on
# the first paraphrase and reads as though it were exhaustive. The PRESENCE arm is what carries
# the correction; this one only stops the exact sentence coming back.
#
# THE CONFIRMATION TOKEN IS `--check`'s, NOT THE WRITE'S. The same bullet says
# Check 5 runs the read-only mode, so a remedy citing `N value(s) written` cites a mode the
# reader has just been told not to run — and the write is the wrong confirmation on its own
# terms: handed a WRONG transcription it rewrites it from the story file and exits 0, so the
# number that was supposed to confirm the entry is the number produced by silently replacing it.
grep -q -- '0 drifted key(s)' "$DS_STEPS/gate-validation.md" 2>/dev/null \
  && ok "the remedy confirms the hand-written entry with \`--check\`'s own token (\`0 drifted key(s)\`)" \
  || bad "the remedy names no read-only confirmation token — the reader is left to pick a mode"
grep -q -- '0 value(s) written' "$DS_STEPS/gate-validation.md" 2>/dev/null \
  && bad "the remedy cites the WRITE mode's token as the confirmation — that mode overwrites a wrong transcription and exits 0" \
  || ok "the remedy does NOT cite the write mode's token as a confirmation"

# --- 4k. Check 9 (BL-934): span-start near-misses, and the UI path bound to Check 5 -------------
# THE START-BOUNDARY NEAR-MISS. The generic relocate in section 4 moves a paragraph to the END of
# the file, past the span's end line; nothing there puts the clause just ABOVE the start line. For
# every gv9-* row, and every BL-939 row (gv17-retro-args, retro-gate-*), the pinned paragraph is
# moved, in a flattened copy, to sit immediately before the
# first line opening with the row's span start, with the start line itself untouched. The row must
# read in-span 0 while the paragraph is still in the file (whole >= 1); the flattened copy's own
# in-span 1 is the same-run control.
pmove_before() { # <flat-src> <dst> <lead> <token> <start-prefix>
  MB_LEAD="$3" MB_TOK="$4" MB_S="$5" awk '
  BEGIN { l = ENVIRON["MB_LEAD"]; k = ENVIRON["MB_TOK"]; s = ENVIRON["MB_S"]; n = 0 }
  { q = $0; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q)
    if (index(q, l) == 1 && index(q, k) > 0) { held[++n] = q; next }
    line[++m] = $0 }
  END { done = 0
        for (i = 1; i <= m; i++) {
          if (!done && index(line[i], s) == 1) { for (j = 1; j <= n; j++) { print held[j]; print "" }; done = 1 }
          print line[i] } }' "$1" > "$2"
}
n_gv9=0; n_939=0
while IFS='|' read -r id base rel s e lead mode tok; do
  case "$id" in gv9-*) n_gv9=$((n_gv9 + 1)) ;; gv17-retro-args|retro-gate-*) n_939=$((n_939 + 1)) ;; *) continue ;; esac
  f="$(pin_path "$base" "$rel")"
  [ -f "$f" ] || { bad "$id/before-start: subject absent"; continue; }
  flat="$M/$id.flat.md"; [ -f "$flat" ] || flatten "$f" "$flat"
  o0="$(pin_scan "$flat" "$s" "$e" "$lead" para "$tok")"
  [ "${o0%% *}" = "1" ] || { bad "$id/before-start: CONTROL -- flattened copy in-span=${o0%% *}, wanted 1"; continue; }
  dst="$M/$id.before-start.md"; pmove_before "$flat" "$dst" "$lead" "$tok" "$s"
  if cmp -s "$flat" "$dst"; then bad "$id/before-start: move did not apply"; continue; fi
  read -r ins whole sl el fl <<<"$(pin_scan "$dst" "$s" "$e" "$lead" para "$tok")"
  if [ "$ins" -eq 0 ] && [ "$whole" -ge 1 ] && [ "$fl" -lt "$sl" ]; then
    ok "$id/before-start: the paragraph just above '$s' (line $fl, span opens $sl) does not satisfy the row"
  else bad "$id/before-start: in-span=$ins whole=$whole first-hit=$fl span-start=$sl -- the start bound does not discriminate"; fi
done <<<"$(pins)"
[ "$n_gv9" -eq 59 ] || bad "before-start: $n_gv9 gv9-* row(s) read, wanted 59"
[ "$n_939" -eq 5 ] || bad "before-start: $n_939 BL-939 row(s) (gv17-retro-args, retro-gate-*) read, wanted 5"

# --- 4l. retro-gate-invoked (BL-939): two named near-misses on the real retro.md ----------------
# The gate is turned on by item 6 of retro.md §5c, and the Gate type paragraph above the list has
# long carried the lowercase prose `run gate validation [retro]`. (a) that prose alone, item 6
# deleted, and (b) item 6 negated to `6. **Do not run gate validation [retro]**` with its token
# kept, must each read in-span 0 and whole 0. Both are built on the flattened copy, whose own
# in-span 1 is the same-run control; each asserts the property it keeps is still present.
RGI_LEAD='6. **Run gate validation [retro]**'
RGI_TOK='A gate FAIL blocks the Step 6 commit, as a failing check 2-5 does.'
RGI_S='### 5c. Pre-Commit Validation Gate'; RGI_E='### 6. Commit, Push, and PR'
RGI_F="$SKILL_DIR/steps/retro.md"; RGI_FLAT="$M/retro-gate-invoked.nm.flat.md"
[ -f "$RGI_F" ] || { echo "FIXTURE ERROR: 4l: $RGI_F is absent" >&2; exit 2; }
flatten "$RGI_F" "$RGI_FLAT"
rgi0="$(pin_scan "$RGI_FLAT" "$RGI_S" "$RGI_E" "$RGI_LEAD" para "$RGI_TOK")"
B_rgi=0
if [ "${rgi0%% *}" = 1 ]; then ok "retro-gate-invoked/near-miss: control: the flattened copy pins item 6 in span (1)"; B_rgi=1
else bad "retro-gate-invoked/near-miss: CONTROL -- flattened copy in-span=${rgi0%% *}, wanted 1"; fi
if [ "$B_rgi" = 1 ]; then
  RL_LEAD="$RGI_LEAD" awk '{ q = $0; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q)
    if (index(q, ENVIRON["RL_LEAD"]) == 1) next; print }' "$RGI_FLAT" > "$M/rgi-lowercase-only.md"
  low="$(grep -cF 'run gate validation [retro]' "$M/rgi-lowercase-only.md")" || low=0
  read -r ins whole sl el fl <<<"$(pin_scan "$M/rgi-lowercase-only.md" "$RGI_S" "$RGI_E" "$RGI_LEAD" para "$RGI_TOK")"
  if cmp -s "$RGI_FLAT" "$M/rgi-lowercase-only.md"; then bad "retro-gate-invoked/near-miss (a): item 6 deletion did not apply"
  elif [ "$low" -ge 1 ] && [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then
    ok "retro-gate-invoked/near-miss (a): the lowercase 'run gate validation [retro]' prose alone ($low line(s)), item 6 deleted, does not satisfy the row"
  else bad "retro-gate-invoked/near-miss (a): lowercase=$low in-span=$ins whole=$whole -- the lowercase prose satisfies the row, or was not kept"; fi
  lreplace "$RGI_FLAT" "$M/rgi-negated.md" "$RGI_LEAD" '6. **Do not run gate validation [retro]**'
  kept="$(grep -cF -- "$RGI_TOK" "$M/rgi-negated.md")" || kept=0
  neg="$(grep -cF '6. **Do not run gate validation [retro]**' "$M/rgi-negated.md")" || neg=0
  read -r ins whole sl el fl <<<"$(pin_scan "$M/rgi-negated.md" "$RGI_S" "$RGI_E" "$RGI_LEAD" para "$RGI_TOK")"
  if cmp -s "$RGI_FLAT" "$M/rgi-negated.md"; then bad "retro-gate-invoked/near-miss (b): the negation did not apply"
  elif [ "$kept" -ge 1 ] && [ "$neg" -eq 1 ] && [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then
    ok "retro-gate-invoked/near-miss (b): item 6 negated to 'Do not run gate validation [retro]', its token kept, does not satisfy the row"
  else bad "retro-gate-invoked/near-miss (b): token=$kept negated=$neg in-span=$ins whole=$whole -- a negated item satisfies the row"; fi
fi

# THE UI PATH, BOUND ACROSS TWO FILES. Check 9 states the pathspec and the test-file filter inline
# (contract NOTE 1) and says it defines them as validate-mandatory-rules.sh Check 5 does. Both sides
# are DERIVED: the gate side from the one code-span line inside `### 9.`..`### 10.` that opens
# `git diff --name-only --no-renames` (fenced and commented lines invisible, as pin_scan reads them)
# and the one carrying `awk -F/ '`; the script side from its one `CHECK5_WEB_FILES=` line (file 457
# at this writing) and its one `CHECK5_WEB_NONTEST=` line (480). The pathspec is the text after
# ` -- ` up to the closing backtick or ` 2>/dev/null`; the filter is the `awk -F/ '...'` program.
# ui_verdict prints MATCH, DRIFT or ABSENT; a side that yields nothing, or more than one line, is
# ABSENT, never MATCH. FP set: the real pair reads MATCH. Mutants move each side once.
c9_gate() { # <gate file> <ps|awk> -> the inline value, or nothing
  awk -v want="$2" '
  { t = $0; sub(/^[ \t]+/, "", t)
    if (com) { if (index($0, "-->")) com = 0; next }
    if (fence != "") { if (substr(t, 1, 3) == fence) fence = ""; next }
    if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { fence = substr(t, 1, 3); next }
    if (substr(t, 1, 4) == "<!--") { if (!index(substr(t, 5), "-->")) com = 1; next }
    if (!on) { if (index($0, "### 9.") == 1) on = 1; next }
    if (index($0, "### 10.") == 1) exit
    if (want == "ps" && index($0, "`git diff --name-only --no-renames ") == 1) {
      v = $0; sub(/^[^`]*`[^`]*" -- /, "", v); sub(/`.*$/, "", v); n++; out = v }
    if (want == "awk" && (c = index($0, "`awk -F/ '\''")) > 0) {
      v = substr($0, c + 1); sub(/`.*$/, "", v); n++; out = v } }
  END { if (n == 1) print out }' "$1"
}
c9_script() { # <validate-mandatory-rules.sh> <ps|awk> -> Check 5's value, or nothing
  awk -v want="$2" '
  want == "ps" && index($0, "CHECK5_WEB_FILES=\"$(git diff --name-only --no-renames ") == 1 {
    v = $0; sub(/^.*" -- /, "", v); sub(/ 2>\/dev\/null.*$/, "", v); n++; out = v }
  want == "awk" && index($0, "CHECK5_WEB_NONTEST=") == 1 && (c = index($0, "awk -F/ '\''")) > 0 {
    v = substr($0, c); sub(/\)"$/, "", v); n++; out = v }
  END { if (n == 1) print out }' "$1"
}
ui_verdict() { # <gate file> <script file> -> MATCH | DRIFT <which> | ABSENT <which>
  local gp sp ga sa
  gp="$(c9_gate "$1" ps)"; sp="$(c9_script "$2" ps)"; ga="$(c9_gate "$1" awk)"; sa="$(c9_script "$2" awk)"
  if [ -z "$gp" ] || [ -z "$sp" ]; then printf 'ABSENT pathspec gate=[%s] script=[%s]\n' "$gp" "$sp"
  elif [ -z "$ga" ] || [ -z "$sa" ]; then printf 'ABSENT filter gate=[%s] script=[%s]\n' "$ga" "$sa"
  elif [ "$gp" != "$sp" ]; then printf 'DRIFT pathspec gate=[%s] script=[%s]\n' "$gp" "$sp"
  elif [ "$ga" != "$sa" ]; then printf 'DRIFT filter gate=[%s] script=[%s]\n' "$ga" "$sa"
  else printf 'MATCH [%s] [%s]\n' "$gp" "$ga"; fi
}
UV="$WORK/c9ui"; mkdir -p "$UV" || exit 2
# PROBES, both directions, on synthetic text. g1 carries the value inside Check 9; g2 carries it only
# ABOVE `### 9.` (a near-miss the span must refuse); g3 inside a fence. s1/s2 differ by one pathspec.
printf '%s\n' '### 9. v' "\`git diff --name-only --no-renames \"<b>..<f>\" -- 'web/**' 'web/src/**'\`" \
  "\`awk -F/ 'NF && \$NF !~ /x/ {print}'\`" '### 10. w' > "$UV/g1.md"
printf '%s\n' "\`git diff --name-only --no-renames \"<b>..<f>\" -- 'web/**' 'web/src/**'\`" \
  "\`awk -F/ 'NF && \$NF !~ /x/ {print}'\`" '### 9. v' '### 10. w' > "$UV/g2.md"
printf '%s\n' '### 9. v' '```' "\`git diff --name-only --no-renames \"<b>..<f>\" -- 'web/**' 'web/src/**'\`" '```' \
  "\`awk -F/ 'NF && \$NF !~ /x/ {print}'\`" '### 10. w' > "$UV/g3.md"
printf '%s\n' "CHECK5_WEB_FILES=\"\$(git diff --name-only --no-renames \"\${B}..HEAD\" -- 'web/**' 'web/src/**' 2>/dev/null)\"" \
  "CHECK5_WEB_NONTEST=\"\$(printf '%s\\n' \"\$X\" | awk -F/ 'NF && \$NF !~ /x/ {print}')\"" > "$UV/s1.sh"
printf '%s\n' "CHECK5_WEB_FILES=\"\$(git diff --name-only --no-renames \"\${B}..HEAD\" -- 'web/**' 2>/dev/null)\"" \
  "CHECK5_WEB_NONTEST=\"\$(printf '%s\\n' \"\$X\" | awk -F/ 'NF && \$NF !~ /x/ {print}')\"" > "$UV/s2.sh"
uv1="$(ui_verdict "$UV/g1.md" "$UV/s1.sh")"; uv2="$(ui_verdict "$UV/g1.md" "$UV/s2.sh")"
uv3="$(ui_verdict "$UV/g2.md" "$UV/s1.sh")"; uv4="$(ui_verdict "$UV/g3.md" "$UV/s1.sh")"
uv5="$(ui_verdict "$UV/g1.md" "$UV/absent.sh")"
if [ "${uv1%% *}" = MATCH ] && [ "${uv2%% *}" = DRIFT ] && [ "${uv3%% *}" = ABSENT ] && [ "${uv4%% *}" = ABSENT ] && [ "${uv5%% *}" = ABSENT ]; then
  ok "c9-ui-path: probe -- match, a one-pathspec drift, the value only above '### 9.', the value fenced and an absent script each read as built"
  B_c9ui_probe=1
else
  bad "c9-ui-path: FIXTURE BROKEN -- probe '$uv1' / '$uv2' / '$uv3' / '$uv4' / '$uv5'"; B_c9ui_probe=0
fi
case "$LAYOUT" in
  dist) VMR="$ROOT/core/scripts/validate-mandatory-rules.sh" ;;
  *)    VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh" ;;
esac
GV9="$SKILL_DIR/steps/gate-validation.md"
[ -f "$VMR" ] || { echo "FIXTURE ERROR: 4k: $VMR is absent; the Check 9 UI-path binding was not asserted" >&2; exit 2; }
[ -f "$GV9" ] || { echo "FIXTURE ERROR: 4k: $GV9 is absent" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-mandatory-rules.sh"
uv_real="$(ui_verdict "$GV9" "$VMR")"
B_c9ui=0
case "$uv_real" in
  MATCH*) if [ "$B_c9ui_probe" = 1 ]; then ok "c9-ui-path: Check 9's inline UI pathspec and test filter equal validate-mandatory-rules.sh Check 5's ($uv_real)"; B_c9ui=1
          else bad "c9-ui-path: real pair reads MATCH but the probe was red, so the MATCH is unproven"; fi ;;
  *)      bad "c9-ui-path: Check 9 against ${VMR#"$ROOT/"} reads $uv_real (want MATCH)" ;;
esac
# MUTANTS, one per side and value, each a copy guarded by cmp -s. The pathspec mutants drop
# `'web/tests/**'` from ONE file; the filter mutants drop `spec` from the alternation in ONE file.
c9_mut() { # <name> <src> <dst> <old> <new> <file: gate|script> <want: DRIFT pathspec|DRIFT filter>
  local name="$1" src="$2" dst="$3" g="$GV9" s="$VMR" v
  C9_OLD="$4" C9_NEW="$5" awk 'BEGIN { o = ENVIRON["C9_OLD"]; n = ENVIRON["C9_NEW"] }
    { if ((c = index($0, o)) > 0) $0 = substr($0, 1, c - 1) n substr($0, c + length(o)); print }' "$src" > "$dst"
  if cmp -s "$src" "$dst"; then bad "MUTANT $name: DID NOT APPLY"; return; fi
  if [ "$6" = gate ]; then g="$dst"; else s="$dst"; fi
  v="$(ui_verdict "$g" "$s")"
  case "$v" in
    "$7"*) mutant_killed "$B_c9ui" "$name" "MUTANT $name: reads $v" ;;
    *)     bad "MUTANT $name: SURVIVED ($v)" ;;
  esac
}
c9_mut c9-ui-gate-ps   "$GV9" "$UV/gate-ps.md"   " 'web/tests/**'\`" "\`" gate "DRIFT pathspec"
c9_mut c9-ui-script-ps "$VMR" "$UV/script-ps.sh" " 'web/tests/**' 2>/dev/null" " 2>/dev/null" script "DRIFT pathspec"
c9_mut c9-ui-gate-awk  "$GV9" "$UV/gate-awk.md"  "/\\.(test|spec)\\./ {print}'\`" "/\\.(test)\\./ {print}'\`" gate "DRIFT filter"
c9_mut c9-ui-script-awk "$VMR" "$UV/script-awk.sh" "/\\.(test|spec)\\./ {print}')\"" "/\\.(test)\\./ {print}')\"" script "DRIFT filter"
# NEAR-MISS on the real file: Check 9's UI-path line moved to just above `### 9.` must read ABSENT,
# so a pathspec stated elsewhere in gate-validation.md cannot satisfy the binding.
awk '{ l[++n] = $0 } END {
       for (i = 1; i <= n; i++) if (index(l[i], "`git diff --name-only --no-renames ") == 1) { hold = l[i]; skip = i }
       for (i = 1; i <= n; i++) { if (i == skip) continue; if (index(l[i], "### 9.") == 1 && hold != "") print hold; print l[i] } }' \
  "$GV9" > "$UV/gate-above.md"
uv_above="$(ui_verdict "$UV/gate-above.md" "$VMR")"
if ! cmp -s "$GV9" "$UV/gate-above.md" && [ "${uv_above%% *}" = ABSENT ]; then
  ok "c9-ui-path near-miss: the UI-path line moved just above '### 9.' reads ABSENT, not MATCH"
else bad "c9-ui-path near-miss: the line above '### 9.' reads '$uv_above' -- the span does not bound the gate side"; fi

# --- 4m. Check 9 retro acceptance (BL-939 fold): each clause deleted fails exactly its own row -----
# The generic negate in section 4 kills each row alone and says nothing about its neighbours. Here
# every gv9-retro-* row is scored on the flattened gate-validation.md first (all must read 1: the
# same-run base), then each BL-939-fold clause is deleted from a copy, guarded by cmp -s, and the
# copy must read in-span 0 on that row and 1 on every OTHER gv9-retro-* row. Two named near-misses
# on the whose-citation row: (a1) "this sprint's" alone deleted fails gv9-retro-thissprint, and
# (a2b) the cited-nowhere clause deleted fails gv9-retro-citednowhere. Three named near-misses:
# (n1) the archive-glob clause deleted fails gv9-retro-livearchive; (n2) "composed from N and not
# searched" deleted fails gv9-retro-composed, and the other sprint's archive deleted fails
# gv9-retro-othersprint; (n3) `--accept-captured` deleted from the --cite command fails
# gv9-retro-captured. Final fold: (s1) the lead-written-slot clause deleted, and (s2) "is not the
# quote" rewritten "is also a quote", each fail gv9-retro-slotquote, so a line whose quotes are all
# lead-written must FAIL; (e1) per-line verification deleted and (e2) "earliest" rewritten
# "latest" fail gv9-retro-everyline; (b1) the fail-closed clause deleted and (b2) "latest" rewritten "earliest"
# fail gv9-retro-bodyfloor; (t1) the date-only clause deleted and (t2) "with a time of day"
# dropped fail gv9-retro-timeofday; (d1) the fails-closed reason deleted fails gv9-retro-addendum;
# (q1) the no-slot clause and (q2) every-pair fail gv9-retro-noslot. The tokens are pairwise disjoint, which is what lets one deletion touch
# one row. BL-868: text pins over a file, nothing timed.
G9R_ROWS="$M/gv9r.rows"
pins | awk -F'|' 'index($1, "gv9-retro-") == 1' > "$G9R_ROWS"
G9R_F="$SKILL_DIR/steps/gate-validation.md"; G9R_FLAT="$M/gv9r.flat.md"
[ -f "$G9R_F" ] || { echo "FIXTURE ERROR: 4m: $G9R_F is absent" >&2; exit 2; }
flatten "$G9R_F" "$G9R_FLAT"
g9r_score() { # <file> -> "<id> <in-span>" per gv9-retro-* row
  while IFS='|' read -r id base rel s e lead mode tok; do
    printf '%s %s\n' "$id" "$(pin_scan "$1" "$s" "$e" "$lead" para "$tok" | awk '{print $1}')"
  done < "$G9R_ROWS"
}
g9r_n="$(grep -c . "$G9R_ROWS")" || g9r_n=0
g9r_base="$(g9r_score "$G9R_FLAT")"
g9r_ones="$(printf '%s\n' "$g9r_base" | awk '$2 == 1' | grep -c .)" || g9r_ones=0
B_gv9r=0
if [ "$g9r_n" -ge 1 ] && [ "$g9r_ones" -eq "$g9r_n" ]; then
  ok "gv9-retro/exact: control: all $g9r_n gv9-retro-* rows read 1 on the flattened copy"; B_gv9r=1
else bad "gv9-retro/exact: CONTROL -- $g9r_ones of $g9r_n gv9-retro-* rows read 1 on the flattened copy"; fi
g9r_del() { # <name> <target id> <old text> [<new text>, default empty]
  local dst="$M/gv9r.$1.md" sc z o
  G9_OLD="$3" G9_NEW="${4:-}" awk 'BEGIN { o = ENVIRON["G9_OLD"]; n = ENVIRON["G9_NEW"] } { if ((c = index($0, o)) > 0) $0 = substr($0, 1, c - 1) n substr($0, c + length(o)); print }' "$G9R_FLAT" > "$dst"
  if cmp -s "$G9R_FLAT" "$dst"; then bad "MUTANT $1: DID NOT APPLY"; return; fi
  sc="$(g9r_score "$dst")"
  z="$(printf '%s\n' "$sc" | awk -v t="$2" '$1 == t && $2 == 0' | grep -c .)" || z=0
  o="$(printf '%s\n' "$sc" | awk -v t="$2" '$1 != t && $2 == 1' | grep -c .)" || o=0
  if [ "$z" -eq 1 ] && [ "$o" -eq $((g9r_n - 1)) ]; then
    mutant_killed "${B_gv9r:-0}" "$1" "MUTANT $1: '$3' rewritten fails $2 alone ($o other row(s) still 1)"
  else bad "MUTANT $1: SURVIVED or spilled -- $2 at 0: $z, other rows at 1: $o of $((g9r_n - 1))"; fi
}
g9r_del gv9-retro-thissprint-a1 gv9-retro-thissprint "appears in this sprint's \`## Gate Log" "appears in \`## Gate Log"
g9r_del gv9-retro-citednowhere-a2b gv9-retro-citednowhere ", and an id cited nowhere accepts nothing"
g9r_del gv9-retro-names-del gv9-retro-names 'The cited entry names that surface and that deviation'
g9r_del gv9-retro-archive-del gv9-retro-archive ' or `docs/escalations/pending-archive.md`'
g9r_del gv9-retro-supcite-del gv9-retro-supcite '`RESOLVED` and `SUPPRESSED` alike, '
g9r_del gv9-retro-supcheck-del gv9-retro-supcheck '[core] 9 — `' '[core] 9`'
g9r_del gv9-retro-supts-del gv9-retro-supts 'the `Timestamp:` of the `## Gate Log: Sprint <N>` section that first records' 'the gate-log line that first recorded'
g9r_del gv9-retro-amendsha-del gv9-retro-amendsha ' whose message cites a `RESOLVED` escalation id that itself meets every acceptance rule here'
g9r_del gv9-retro-mergecommit-del gv9-retro-mergecommit ' as of the sprint'"'"'s merge commit to main, the squash or merge commit that landed the sprint,'
g9r_del gv9-retro-livearchive-n1 gv9-retro-livearchive ' or in `_bmad-output/implementation-artifacts/s<N>/gate-log-archive.md`'
g9r_del gv9-retro-composed-n2 gv9-retro-composed ' composed from N and not searched'
g9r_del gv9-retro-othersprint-n2 gv9-retro-othersprint ' or in another sprint'"'"'s `s<M>/` archive'
g9r_del gv9-retro-captured-n3 gv9-retro-captured ' --accept-captured`' '`'
g9r_del gv9-retro-matchrc-del gv9-retro-matchrc ' with a `MATCH <ts>` line on stdout'
g9r_del gv9-retro-pruned-del gv9-retro-pruned ' within the citation'"'"'s window'
g9r_del gv9-retro-dateonly-del gv9-retro-dateonly 'without a time of day, hours and minutes, does not verify.' 'without seconds does not verify.'
g9r_del gv9-retro-onlyhere-del gv9-retro-onlyhere '`--accept-captured` is passed only here' '`--accept-captured` is passed here'
g9r_del gv9-retro-nowhereelse-del gv9-retro-nowhereelse ', and `NOMATCH-TRANSCRIPT-PRUNED` acquits nothing anywhere else'
g9r_del gv9-retro-markupdev-del gv9-retro-markupdev ", and a markup or CSS line that surface's diff adds is a deviation from that statement"
g9r_del gv9-retro-readarchive-del gv9-retro-readarchive 'sections wherever the citation rule below reads them, live or archived, the live one being' 'section of `_bmad-output/implementation-artifacts/gate-log.md`,'
g9r_del gv9-retro-mockupmerged-del gv9-retro-mockupmerged ' named below (as of the sprint'"'"'s merge commit)'
g9r_del gv9-retro-headersn-del gv9-retro-headersn ', and its header names `S<N>`, this sprint, so a prior sprint'"'"'s escalation accepts nothing for this sprint'"'"'s drift'
g9r_del gv9-retro-suppressed-del gv9-retro-suppressed ', or a `SUPPRESSED` waiver that meets the waiver rule below'
g9r_del gv9-retro-wholeanswer-del gv9-retro-wholeanswer 'the quote, normalised, equals a whole answer' 'the quote appears in an answer'
g9r_del gv9-retro-archivenames-del gv9-retro-archivenames ' and its ordinal forms `s<N>/gate-log-archive-2.md`, `s<N>/gate-log-archive-3.md` and onward,' ' or any `s<N>/gate-log-archive*.md`,'
g9r_del gv9-retro-resolvedfloor-del gv9-retro-resolvedfloor 'Any cited entry, `RESOLVED` or `SUPPRESSED`, counts only if its' 'A `SUPPRESSED` waiver counts only if its'
g9r_del gv9-retro-mergederive-del gv9-retro-mergederive "whose tree equals \`PR_HEAD\`'s tree (a squash), or the merge commit whose second parent is \`PR_HEAD\`" 'whose subject names the sprint'
g9r_del gv9-retro-authsource-del gv9-retro-authsource ' alone, never from its `**Resolution:**` or `**Context:**` text and never from `_bmad-output/operator-answers-history.md`'
g9r_del gv9-retro-slotquote-del gv9-retro-slotquote ', so a line whose slot quote is lead-written fails even when its trailing text carries a captured answer'
g9r_del gv9-retro-slotquote-also gv9-retro-slotquote 'is not the quote' 'is also a quote'
g9r_del gv9-retro-everyline-del gv9-retro-everyline ', each by its own slot quote and its own timestamp, and the timestamp floor below is taken against the earliest of their timestamps'
g9r_del gv9-retro-everyline-latest gv9-retro-everyline 'taken against the earliest of their timestamps' 'taken against the latest of their timestamps'
g9r_del gv9-retro-bodyfloor-del gv9-retro-bodyfloor ', and where the body carries none the floor is unmet and the acceptance fails'
g9r_del gv9-retro-bodyfloor-earliest gv9-retro-bodyfloor 'the floor is the latest ISO-8601' 'the floor is the earliest ISO-8601'
g9r_del gv9-retro-timeofday-del gv9-retro-timeofday '; a date-only value or a space-separated date and time is not counted'
g9r_del gv9-retro-timeofday-drop gv9-retro-timeofday 'with a time of day '
g9r_del gv9-retro-addendum-del gv9-retro-addendum ', whose later timestamp raises the floor, so it fails closed'
g9r_del gv9-retro-noslot-del gv9-retro-noslot 'A line with no slot quote does not verify, and where' 'Where'
g9r_del gv9-retro-noslot-pairs gv9-retro-noslot ' every pair is verified, each by its own quote and its own timestamp.' ' the first pair is verified.'

# --- 5. the real corpus ---------------------------------------------------------
echo ""
echo "  corpus:"
REP_HERE="$(bash "$SELF" --report 2>&1)"; rc_here=$?
printf '%s\n' "$REP_HERE"
n_ok="$(grep -c '^  ok ' <<<"$REP_HERE")" || n_ok=0
n_bad="$(grep -c '^  FAIL ' <<<"$REP_HERE")" || n_bad=0
fails=$((fails + n_bad))
[ "$rc_here" -eq 0 ] || [ "$n_bad" -gt 0 ] || bad "corpus: --report exited $rc_here with no FAIL line"
n_want=$(( $(pins | wc -l) + 3 ))
[ "$n_ok" -eq "$n_want" ] || bad "corpus: $n_ok ok line(s), wanted $n_want (one per pin, plus order, range and lead-address) — a report that ran nothing is not a pass"

# --- 6. cwd-invariance: the same verdict from a decoy tree ----------------------
DECOY="$WORK/decoy"
mkdir -p "$DECOY/.claude/skills/ai-dlc/steps" "$DECOY/.claude/team-roles" || exit 2
printf '### 12. decoy\n### 13. decoy\n' > "$DECOY/.claude/skills/ai-dlc/steps/gate-validation.md"
REP_DECOY="$( cd "$DECOY" && bash "$SELF" --report 2>&1 )"; rc_decoy=$?
if [ "$REP_DECOY" = "$REP_HERE" ] && [ "$rc_decoy" -eq "$rc_here" ]; then
  ok "cwd: a decoy ai-dlc tree as cwd yields the byte-identical verdict (root: $ROOT)"; B_cwd=1
else
  bad "cwd: verdict changed with the cwd (rc $rc_here -> $rc_decoy)"
fi
got="$( cd "$DECOY" && resolve_root "$(pwd)" || true )"
[ "$got" = "consumer $DECOY" ] && ok "CONTROL: the decoy is a resolvable root, so a cwd-seeded resolver would have read it" \
                               || bad "CONTROL: the decoy did not resolve from its own cwd ('${got:-<none>}') — the cwd arm proves nothing"
MC="$WORK/mutcwd"; mkdir -p "$MC" || exit 2
anchor='RESOLVED="$(resolve_root "$HERE" || true)"'
na="$(grep -cxF -- "$anchor" "$SELF")" || na=0
if [ "$na" -ne 1 ]; then
  bad "MUTANT cwd: resolver anchor found $na times, wanted 1 — the cwd mutant cannot be built"
else
  sed -e 's@^RESOLVED="$(resolve_root "$HERE" || true)"$@RESOLVED="$(resolve_root "$(pwd)" || true)"@' "$SELF" > "$MC/run.sh"
  if cmp -s "$SELF" "$MC/run.sh"; then
    bad "MUTANT cwd: sed did not apply"
  else
    mout="$( cd "$DECOY" && bash "$MC/run.sh" --report 2>&1 )"
    case "$mout" in
      *"root: $DECOY (consumer)"*) mutant_killed "$B_cwd" cwd "MUTANT cwd: a resolver seeded from the cwd reads the decoy; the cwd arm kills it" ;;
      *) bad "MUTANT cwd: cwd-seeded resolver did not read the decoy — the cwd arm cannot fire" ;;
    esac
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "process-rule-pins: PASS"
  exit 0
fi
echo "process-rule-pins: FAIL ($fails assertion(s))"
exit 1
