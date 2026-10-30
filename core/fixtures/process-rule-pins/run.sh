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
#     clause intact and passes. No row here can fail on an addition; a reviewer reads for that.
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
#     <shard>.md@<dispatched-at>`, and a refusal naming another shard's writer is a finding
#     (gp-shard-rerun*); the probe ledger is not rotated mid-round and a "predates transcript_path"
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
#     authorization-premise invalidation rather than a re-ask (r11a-premise). Those subsection headings are their own paragraphs to para mode, so each
#     lead is the bold opening of the paragraph under them. route.md Step 6's **Option labels carry
#     no recommendation.** paragraph says in the question why its options carry none
#     (route-say-why). All five are para rows; each token sits on ONE line of its subject.
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

# pin_scan <file> <span-start-prefix|""> <span-end-prefix> <lead> <prefix|contains|para> [<token>]
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
    if (index(q, l) == 1 && index(q, k) > 0) { whole++; if (fl == 0) fl = pl; if (pst == 1) ins++ }
    p = ""
  }
  BEGIN { s = ENVIRON["PS_START"]; e = ENVIRON["PS_END"]; l = ENVIRON["PS_LEAD"]; m = ENVIRON["PS_MODE"]
          k = ENVIRON["PS_TOK"]
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
srev-waves-cite|S|steps/sprint-review.md|### 2. Sprint-Level Party Mode|### 3.|`/bmad-party-mode --mode subagent --non-interactive` — PM, Architect|para|bounded by the waves sentence of `_gate-procedures.md`, "Validation cycle" item 1, and Rule 28's Waves paragraph
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
elic-shape-ordinals|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**|para|The story ordinals are the ones `scripts/ai-dlc/merge-adversarial-shards.sh --map <shards-dir>` prints, `<shards-dir>` being the next review pass's `s<N>/shards/<artifact>-p<M>/`, which the lead creates first
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
impl-rr-delta|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|run the partition with `<prior-sha>` in place of `<base>`
impl-rr-prior|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|column-0 `reviewed-sha:` of the pass M-1 review file
impl-rr-fanout|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|dispatches through this same fan-out
impl-rr-fallback|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|run the full `<base>..<frozen-sha>` partition instead
impl-rr-never|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|never dispatches a `shard: 1/1` delta of no stated range
impl-rr-story|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|is briefed with the whole story record and the full `git diff <prior-sha>..<frozen-sha>` including scan-root paths
impl-rr-parts|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|every part reviewer gets the story record as context
impl-rr-carry|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|Every Critical and Important `#### ` finding of pass M-1 is carried
cr-serial-heading|R|code-reviewer.md|## Review Document Template|## As a Shard|**A serial review writes its findings the way a shard does.**|para|never a bullet
cr-serial-sha|R|code-reviewer.md|## Review Document Template|## As a Shard|**A serial review writes its findings the way a shard does.**|para|column-0 `reviewed-sha: <full frozen sha>` line
impl-serial-form|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|A serial review writes its findings the way a shard does, each a `#### ` heading under its container, never a bullet
impl-serial-sha|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|carries one column-0 `reviewed-sha: <full frozen sha>` line
impl-rr-list|S|steps/implementation.md|**Pre-gate commit-presence check.**|**DAR-fold preflight before gate-2 dispatch.**|**Gate-1 dispatch: the review partitions by changed-file group.**|para|Run `scripts/ai-dlc/validate-carried-findings.sh --list <pass M-1 file>` and paste each line it prints into the brief of the shard that carries that finding, verbatim
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
sts-smoke-cite|S|steps/stories-test-strategy.md|### Story-Authoring Pre-Flight Checklist|### Story-AC Out-of-Scope Declaration Rule|Its surface is `gate-validation.md` Check 11, **Smoke surface.**|contains
sts-hardgate-map|S|steps/stories-test-strategy.md|### 2b.|### 3. Sprint Planning|an unmapped triggered item blocks story authoring.|contains
dv-lrcov-degraded|S|steps/deploy-validate.md|### 5. Production Validation Checkpoint|### 6. Wait for Human|**Locked-requirement coverage.**|para|An operator's acceptance of a degraded branch on a Tier 1 `requirement divergence` `HARD_BLOCK` (`qa.md` Validation Checklist) is a `descope` of the omitted action alone, never `delivered`: the bullet is marked `descoped`, and its line names that action and quotes the `HARD_BLOCK`'s id and its `descope` token.
r11a-effects|S|SKILL.md|### Rule 11 |### Rule 12 |**Every option states its concrete effect, INCLUDING the value it leaves|para|INCLUDING the value it leaves in force
r11a-unbadged|S|SKILL.md|### Rule 11 |### Rule 12 |**Every option states its concrete effect, INCLUDING the value it leaves|para|none marked `(Recommended)` and none placed first as the pick
r11a-pointer|S|SKILL.md|### Rule 11 |### Rule 12 |**One shape for every operator decision|para|apply all three to every question you put to the operator
r11a-four-things|S|SKILL.md|### Rule 11 |### Rule 12 |**Before any question reaches the operator, do|para|four things to it
r11a-lanes-dispatch|S|SKILL.md|### Rule 11 |### Rule 12 |**Before any question reaches the operator, do|para|Dispatch ready actions on free lanes, arm their joins, and name the lanes held
r11a-one-shape|S|SKILL.md|### Rule 12 |### Rule 13 |**Every decision put to the operator has one shape|para|gives every option with its effect and the consequence of choosing it
r11a-say-why|S|SKILL.md|### Rule 12 |### Rule 13 |**Every decision put to the operator has one shape|para|says so in its own text, with the reason,
r11a-attested-act|S|SKILL.md|### Rule 12 |### Rule 13 |**An act the operator has attested is not raised again.**|para|no later step puts it back to the operator:
r11a-premise|S|SKILL.md|### Rule 12 |### Rule 13 |**An act the operator has attested is not raised again.**|para|shows the act did not occur is an authorization-premise invalidation
sts-part-mark|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|<lead engine>/wait-for-deliverable.sh --mark <part path> stories-epic-<n> pm none findings=0
sts-part-nohand|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|never a hand-appended `seat-complete:` line
sts-part-remark|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|is marked again with the same `--mark` call before any `--complete` join reads it
sts-part-complete|S|steps/stories-test-strategy.md|### 2. Epics and Stories|### 2a.|**Per-epic part agents close their part with `--mark`.**|para|the lead's join beat passes `--complete`
route-say-why|S|steps/route.md|### Step 6:|## FAILURE MODES|**Option labels carry no recommendation.**|para|Say in the question that its options carry no recommendation, and why.
gp-2c-locked-effects|S|steps/_gate-procedures.md|## Divergence resolution dispatch|## Adversarial repair dispatch|a. **One sentence naming the decision.**|para|State each option's effect on that entry instead, including the value it leaves in force
gp-2c-locked-nobadge|S|steps/_gate-procedures.md|## Divergence resolution dispatch|## Adversarial repair dispatch|a. **One sentence naming the decision.**|para|**mark NO option `(Recommended)`.**
retro-gar-confirm|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|is an `AskUserQuestion` to the operator naming the id
retro-gar-block|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|a retro HARD_BLOCKS here whenever this sprint's selection is empty and an unmatchable series' newest member records a FAIL, re-runs included
retro-gar-rerun|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**After the last `--series` move, re-run `--sprint s<N> --apply` above; the close is done only when it exits 0.**|para|the close is done only when it exits 0
retro-gar-survivor|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**After the last `--series` move, re-run `--sprint s<N> --apply` above; the close is done only when it exits 0.**|para|exits 1 when it would leave one of them as a FAILing live pass, and that refusal is a HARD_BLOCK like any other
retro-gar-legacy|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**A `--series` run may itself exit 1 and print a `--legacy-through` remedy.**|para|then re-run the `--series` line before re-running the close
retro-gar-close|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|where a sprint has none, it is the merge commit of that sprint's retro PR
retro-gar-utc|S|steps/retro.md|### 7. Merge and Next-Sprint Handoff|6. **Verify no-loss per file:**|**Confirm every hinted sprint against the sprint-close commits before adding `--apply`.**|para|Read `TZ=UTC git log --date=format-local:%Y%m%dT%H%M%SZ --format='%ad %s'` for this repo's sprint-close commits
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
impl-cross-statedir|S|steps/implementation.md|### 6. Orchestrate|### 7.|**Gate-2 dispatch: the validation partitions by changed-file group too.**|para|a beat state directory of its own, given as an absolute path outside the shard directory, and never the lead's.
adv-ls-files|R|adversary.md|## Constraints|## Escalation|- **List a code path your brief does not cite before you open it.**|para|list it with `git ls-files <dir-or-glob>` and read only what that returns.
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
[ "$n" = "1" ] && ok "range scope (consumer): a core flat file beside it is scanned (1)" \
               || bad "range scope (consumer): core flat file not scanned ($n)"
printf 'unrelated: 1\n' > "$CS/layer-contract.yaml"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "2" ] && ok "MUTANT range scope: without the consumer_*_file key the crosswalk IS read (2) — the exclusion is the derivation" \
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
    if [ "${o0%% *}" = "0" ] && [ "${o1%% *}" -ge 1 ]; then
      ok "$id/copy: the token copied into the file fires (original 0, mutant ${o1%% *}) — killed"
    else bad "$id/copy: original='${o0%% *}' mutant='${o1%% *}' (wanted 0 and >=1)"; fi
    continue
  fi
  if [ "$mode" = "fenced" ]; then
    # MUTANT: every line carrying the token deleted must score 0 in-span and 0 whole-file.
    o0="$(pin_scan "$f" "$s" "$e" "$lead" fenced)"
    dst="$M/$id.delete.md"; mutate delete "$f" "$dst" "$lead" contains
    if cmp -s "$f" "$dst"; then bad "$id/delete: mutation did not apply"; continue; fi
    o1="$(pin_scan "$dst" "$s" "$e" "$lead" fenced)"; read -r ins whole sl el fl <<<"$o1"
    if [ "${o0%% *}" -ge 1 ] && [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ]; then
      ok "$id/delete: every fenced line deleted fires (original in-span ${o0%% *}, mutant $ins) — killed"
    else bad "$id/delete: original in-span='${o0%% *}' mutant in-span=$ins whole=$whole"; fi
    continue
  fi
  raw="$(grep -cF -- "$lead" "$f")" || raw=0
  [ "$raw" -ge 1 ] || { bad "$id: lead absent from ${f#"$ROOT/"} — mutants have no subject"; continue; }
  if [ "$mode" = "para" ]; then
    flat="$M/$id.flat.md"; flatten "$f" "$flat"
    o1="$(pin_scan "$f" "$s" "$e" "$lead" para "$tok")"; o2="$(pin_scan "$flat" "$s" "$e" "$lead" para "$tok")"
    if [ "${o1%% *}" != "1" ] || [ "${o2%% *}" != "1" ]; then
      bad "$id: CONTROL — original in-span=${o1%% *}, flattened in-span=${o2%% *}; both must be 1 before a mutant is read"; continue
    fi
    for mm in negate relocate fence comment; do
      dst="$M/$id.$mm.md"
      pmutate "$mm" "$flat" "$dst" "$lead" "$tok"
      if cmp -s "$flat" "$dst"; then bad "$id/$mm: mutation did not apply"; continue; fi
      out="$(pin_scan "$dst" "$s" "$e" "$lead" para "$tok")"; rc=$?
      [ "$rc" -eq 0 ] || { bad "$id/$mm: mutated copy unbalanced (rc=$rc)"; continue; }
      read -r ins whole sl el fl <<<"$out"
      case "$mm" in
        negate)   [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/negate: binding clause rewritten under an intact lead — killed" \
                    || bad "$id/negate: SURVIVED (in-span=$ins whole=$whole)" ;;
        relocate) [ "$ins" -eq 0 ] && [ "$whole" -ge 1 ] && ok "$id/relocate: paragraph outside the span fails though it is still in the file" \
                    || bad "$id/relocate: in-span=$ins whole=$whole — span does not discriminate" ;;
        fence|comment)
                  [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/$mm: wrapped paragraph is invisible though still present" \
                    || bad "$id/$mm: in-span=$ins whole=$whole" ;;
      esac
    done
    continue
  fi
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
      delete)   [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/delete: mutant killed" \
                  || bad "$id/delete: SURVIVED (in-span=$ins whole=$whole)" ;;
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
  if [ "$mode" = "para" ]; then src="$M/$id.named.flat.md"; flatten "$f" "$src"; fi
  c="$(pin_scan "$src" "$s" "$e" "$lead" "$mode" "$tok")"
  [ "${c%% *}" = "1" ] || { bad "$id/named: CONTROL — unmutated in-span=${c%% *}, wanted 1"; continue; }
  dst="$M/$id.named.md"; lreplace "$src" "$dst" "$old" "$new"
  if cmp -s "$src" "$dst"; then bad "$id/named: rewording '$new' did not apply"; continue; fi
  out="$(pin_scan "$dst" "$s" "$e" "$lead" "$mode" "$tok")"
  [ "${out%% *}" = "0" ] && ok "$id/named: rewritten to '$new' — killed" \
                         || bad "$id/named: rewritten to '$new' SURVIVED (in-span=${out%% *})"
done <<<"$(named_mutants)"
[ "$n_named" -eq 8 ] || bad "named: $n_named named mutant(s) read, wanted 8"

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
if cmp -s "$CSF" "$CSM"; then bad "MUTANT qa-sweep/move-into-checklist: DID NOT APPLY"
elif [ "${cs_real%% *}" = 1 ] && [ "${cs_shad%% *}" = 1 ] && [ "$cs_mi" = 0 ] && [ "$cs_mw" -ge 1 ]; then
  ok "qa-sweep: pinned in its own section past the Validation Checklist shadow (real=1, shadowed=1); the sentence moved into the checklist reads 0 in span though still in the file — killed"
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
  ok "join: every seat or cross join paragraph carries --complete ($n_seat seat or cross join call(s) scanned)"
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
# join_battery <files...> -> sets jb_sites, jb_paras, jb_killed, jb_surv
join_battery() {
  jb_sites=0; jb_paras=0; jb_killed=0; jb_surv=""
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
      if grep -qF -- "$jm/m.md:$para:" <<<"$jb_found"; then jb_killed=$((jb_killed + 1))
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
join_battery "$JS/two.md"; c_two="$jb_sites $jb_paras $jb_killed"
join_battery "$JS/mixed2.md"; c_mx="$jb_sites $jb_paras $jb_killed"
#   nonseat.md -- a --complete join naming no seat or cross path: its paragraph mutant is exempt,
#              so the battery must report it as a SURVIVOR naming line 1 -- the survivor branch fires.
printf 'Join the analyst artifact with `scripts/ai-dlc/wait-for-deliverable.sh --complete <artifact_path>`.\n' > "$JS/nonseat.md"
join_battery "$JS/nonseat.md"; c_ns="$jb_sites $jb_paras $jb_killed"; c_nss="${jb_surv# }"
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
join_battery "$JS/prefixns.md"; c_pfb="$jb_sites $jb_paras $jb_killed"
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
  bad "join/mutant: SURVIVED -- every --complete stripped from the paragraph at [${jb_surv# }] was not flagged ($jb_killed/$jb_paras paragraphs killed, $jb_sites sites)"
else
  ok "join/mutant: every --complete stripped from each of $jb_paras real paragraphs ($jb_sites sites), one paragraph at a time, is flagged ($jb_killed/$jb_paras)"
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
case "$ctl" in PASS*) ok "lead-mutant CONTROL: an unmutated copy runs --lead-verdict and passes an addressed corpus" ;;
  *) bad "lead-mutant CONTROL: unmutated copy did not pass ('$ctl') -- no mutant verdict below is evidence" ;; esac
# lead_mut <name> <sed-expr> <floor> <addr> <files...>: real must FAIL, mutant must PASS
lead_mut() {
  local nm="$1" ex="$2" fl="$3" a="$4" r m; shift 4
  sed -e "$ex" "$SELF" > "$LM/$nm.sh"
  if cmp -s "$SELF" "$LM/$nm.sh"; then bad "MUTANT lead/$nm: DID NOT APPLY"; return; fi
  r="$(bash "$LM/real.sh" --lead-verdict "$fl" "$a" "$@")"; m="$(bash "$LM/$nm.sh" --lead-verdict "$fl" "$a" "$@")"
  case "$r|$m" in FAIL*"|"PASS*) ok "MUTANT lead/$nm: killed (real: ${r%%:*}, mutant: ${m%%:*})" ;;
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
    ok "slot-target: the derivation re-run names $sd_real_file file target(s) and no slot directory (probe: s<N>/ and s319/ read 1 each, file targets and prose read 0)"
  else
    bad "slot-target: _gate-procedures.md carries $sd_real_slot slot target(s) (want 0) and $sd_real_file file target(s) (want >= 2)"
  fi
  # MUTANT: restore the slot line in a copy; the arm must read it. cmp -s guards a sed that matched nothing.
  sed 's|^scripts/ai-dlc/validate-artifact-derivations.sh <the joined repair record>$|scripts/ai-dlc/validate-artifact-derivations.sh _bmad-output/planning-artifacts/s<N>/|' "$GPF" > "$SD/gp-mut.md"
  if cmp -s "$GPF" "$SD/gp-mut.md"; then bad "MUTANT slot-target: DID NOT APPLY"
  elif [ "$(slot_hits "$SD/gp-mut.md")" = 1 ]; then ok "MUTANT slot-target: the restored slot line is read (1) where the real file reads 0"
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
    ok "bare-marker: 0 hand-written-marker carriers across the role and step files (control: $bm_ctl sha=<hex> descriptions; probe: fallback and bare spellings read 1 each, sha= description reads 0)"
  else
    bad "bare-marker: $bm_real carrier(s) (want 0), $bm_ctl sha=<hex> control line(s) (want >= 1)"
  fi
  # MUTANT: re-insert the retired fallback sentence into a copy of dev.md; the scan must read it.
  cp "$ROLES_DIR/dev.md" "$BM/dev-mut.md"
  printf 'If that call fails with `unknown arg: --mark`, append the bare line `seat-complete: <step> <seat> <shard> findings=<n>` instead.\n' >> "$BM/dev-mut.md"
  bm_mut="$(carriers "$BM/dev-mut.md")"
  if cmp -s "$ROLES_DIR/dev.md" "$BM/dev-mut.md"; then bad "MUTANT bare-marker: DID NOT APPLY"
  elif [ "$bm_mut" -ge 1 ]; then ok "MUTANT bare-marker: the re-inserted fallback is read ($bm_mut) where the real files read 0"
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
    ok "lead-engine: all $le_occ occurrence(s) over ${#LE_FILES[@]} file(s) are scoped in their own block (probe: form 1 and form 2 read quiet, an unscoped occurrence flagged)"
  else
    bad "lead-engine: $le_none unscoped of $le_occ occurrence(s) over ${#LE_FILES[@]} file(s): $(grep 'form=NONE' <<<"$le_out" | tr '\n' ' ')"
  fi
  # MUTANT form 1: remove dev.md's worktree-condition sentence in a copy; form 2: remove qa.md's in-place definition.
  awk '!/when you run in a worktree/' "$ROLES_DIR/dev.md" > "$LE/dev-mut.md"
  awk '{ gsub(/the lead checkout.s `scripts\/ai-dlc` path your brief carries/, "the engine path"); print }' "$ROLES_DIR/qa.md" > "$LE/qa-mut.md"
  if cmp -s "$ROLES_DIR/dev.md" "$LE/dev-mut.md"; then bad "MUTANT lead-engine form 1: DID NOT APPLY"
  elif [ "$(le_scan "$LE/dev-mut.md" | grep -c 'form=NONE')" -ge 1 ]; then ok "MUTANT lead-engine form 1: dev.md without its worktree sentence is flagged"
  else bad "MUTANT lead-engine form 1: SURVIVED"; fi
  if cmp -s "$ROLES_DIR/qa.md" "$LE/qa-mut.md"; then bad "MUTANT lead-engine form 2: DID NOT APPLY"
  elif [ "$(le_scan "$LE/qa-mut.md" | grep -c 'form=NONE')" -ge 1 ]; then ok "MUTANT lead-engine form 2: qa.md without its in-place definition is flagged"
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
    MATCH*) ok "window-count: touchpoint I states the hook's ADVISOR_GATE_WINDOW default ($wv_real; probe: match, drift, an out-of-item count, an absent hook, a wrapped count, two counts and a split hook each read as built)" ;;
    *)      bad "window-count: touchpoint I against ${WGATE#"$ROOT/"} reads $wv_real (want MATCH)" ;;
  esac
  # MUTANT, fallback only: the hook's non-numeric fallback moved one up in a copy, the default untouched.
  wf="$(win_fallback "$WGATE")"; wfm=$(( ${wf:-0} + 1 ))
  sed "s/^\(case \"\\\$WIN\" in .*) WIN=\)[0-9][0-9]*\( ;; esac\)\$/\1$wfm\2/" "$WGATE" > "$WD/gate-fb-mut.sh" 2>/dev/null
  wv_fb="$(win_verdict "$SKILL_DIR/SKILL.md" "$WD/gate-fb-mut.sh")"
  if [ ! -f "$WGATE" ] || [ -z "$wf" ] || cmp -s "$WGATE" "$WD/gate-fb-mut.sh"; then bad "MUTANT window-count fallback: DID NOT APPLY"
  else
    case "$wv_fb" in
      HOOK-SPLIT*"fallback=$wfm") ok "MUTANT window-count fallback: a fallback of $wfm reads $wv_fb" ;;
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
      DRIFT*"hook=$wm") ok "MUTANT window-count: a hook default of $wm reads $wv_mut" ;;
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
      DRIFT*"skill=$wsm "*) ok "MUTANT window-count skill side: a stated count of $wsm reads $wv_smut" ;;
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
  ok "mark-scope: \"Bounded-join beat\" keeps --complete for seat, shard, cross, repair-part and epic part files whatever the row, and reads any output but rendered as bare"
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
  if [ "$mv" = 0 ]; then ok "MUTANT mark/${ms%%:*}: the home without that clause is named by mark-scope ($1 $2)"
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
  ok "mark-epic-gp: the auto-handoff procedure in _gate-procedures.md names epic part files in the --complete list sentence"
else
  bad "mark-epic-gp: the auto-handoff procedure in _gate-procedures.md does not carry 'epic part files' in the --complete list sentence"
fi
if [ "$(site_epic "$HO4G" "$HO_A" "$HO_B")" = 1 ]; then
  ok "mark-epic-ho: handoff.md step 1 names epic part files in the --complete list sentence"
else
  bad "mark-epic-ho: handoff.md step 1 does not carry 'epic part files' in the --complete list sentence"
fi
#   M-e1 delete `epic part files ` from the _gate-procedures.md auto-handoff list only: mark-epic-gp names it.
#   M-e2 delete it from handoff.md only: mark-epic-ho names it.
awk -v a="$GP_A" -v b="$GP_B" 'index($0, a) == 1 { f = 1 } f && index($0, b) == 1 { f = 0 } { if (f && (i = index($0, "epic part files "))) $0 = substr($0, 1, i - 1) substr($0, i + 16); print }' "$GP4G" > "$MG/gp-noepic-ho-site.md"
awk -v a="$HO_A" -v b="$HO_B" 'index($0, a) == 1 { f = 1 } f && index($0, b) == 1 { f = 0 } { if (f && (i = index($0, "epic part files "))) $0 = substr($0, 1, i - 1) substr($0, i + 16); print }' "$HO4G" > "$MG/ho-noepic.md"
if cmp -s "$GP4G" "$MG/gp-noepic-ho-site.md"; then bad "MUTANT mark/epic-gp: DID NOT APPLY"
elif [ "$(site_epic "$MG/gp-noepic-ho-site.md" "$GP_A" "$GP_B")" = 0 ]; then ok "MUTANT mark/epic-gp: the auto-handoff list without epic part files is named by mark-epic-gp"
else bad "MUTANT mark/epic-gp: SURVIVED mark-epic-gp"; fi
if cmp -s "$HO4G" "$MG/ho-noepic.md"; then bad "MUTANT mark/epic-ho: DID NOT APPLY"
elif [ "$(site_epic "$MG/ho-noepic.md" "$HO_A" "$HO_B")" = 0 ]; then ok "MUTANT mark/epic-ho: the handoff.md list without epic part files is named by mark-epic-ho"
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
    ok "mark-runs: the --mark line extracted from \"Bounded-join beat\", filled in, exits 0 and seals (${mr#0 })"
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
    ok "mark-dv: deploy-validate.md has 5 dispatch sites by the stated grammar, each reading and following \"Bounded-join beat\" (probe: 4 shapes read, 6 near-misses and a fenced line not)"
  else
    bad "mark-dv: deploy-validate.md has $dv_n dispatch site(s) by the stated grammar (want 5); uncited at line(s): ${dv_unc:-none}"
  fi
  # MUTANT: the ops site loses its citation; the arm must name that site.
  awk '{ if (index($0, "dispatch the `ops` teammate")) ops = 1; if (ops && index($0, "(READ AND FOLLOW")) { sub(/ \(READ AND FOLLOW `_gate-procedures.md`, "Bounded-join beat"$/, ""); ops = 2 } if (ops == 2 && index($0, "for its brief and join), re-deploy")) { sub(/for its brief and join\), re-deploy/, "re-deploy"); ops = 0 } print }' "$DVF" > "$DV/dv-mut.md"
  if cmp -s "$DVF" "$DV/dv-mut.md"; then bad "MUTANT mark-dv: DID NOT APPLY"
  elif [ "$(dv_sites "$DV/dv-mut.md" | awk -F'\t' '$2 == 0' | grep -c .)" = 1 ]; then ok "MUTANT mark-dv: the ops site without its citation is named by mark-dv"
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
  ok "mark-deliverable: all $dl_n block(s) carrying the <lead engine> --mark <file> close name <deliverable> (dev.md and both _gate-procedures.md blocks among them)"
else
  bad "mark-deliverable: $dl_n block(s), unnamed: [${dl_bad:-none}], dev.md=$dl_dev (want >=1), _gate-procedures.md=$dl_home (want >=2)"
fi

# MUTANTS of the contract, each a copy guarded by cmp -s, each scored on its killing arm.
#   M-a drop --complete from the home's rendered call: the widened join scan (4b) flags the home paragraph.
awk '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f) gsub(/wait-for-deliverable\.sh --complete --dispatch/, "wait-for-deliverable.sh --dispatch"); print }' "$GP4G" > "$MG/gp-nocomplete.md"
if cmp -s "$GP4G" "$MG/gp-nocomplete.md"; then bad "MUTANT mark/no-complete: DID NOT APPLY"
elif mnc_o="$(join_findings "$MG/gp-nocomplete.md")"; grep -q . <<<"$mnc_o"; then ok "MUTANT mark/no-complete: the home without --complete is flagged by join (the \"mark\":\"rendered\" paragraph key)"
else bad "MUTANT mark/no-complete: SURVIVED -- the home lost --complete and the join scan stayed quiet"; fi
#   M-b render rows=<n>: mark-runs (d) refuses it; mark-home (a) reads findings= no longer last.
awk '/^#+ Bounded-join beat/{f=1} f&&/^## Gate-adjudication dispatch/{f=0} { if (f) gsub(/<shard> findings=<n>`/, "<shard> rows=<n>`"); print }' "$GP4G" > "$MG/gp-rows.md"
if cmp -s "$GP4G" "$MG/gp-rows.md"; then bad "MUTANT mark/rows: DID NOT APPLY"
elif [ ! -f "$WFD" ]; then bad "MUTANT mark/rows: FIXTURE BROKEN -- no engine to run"
else
  mkdir -p "$MG/rows" || exit 2
  mrr="$(run_rendered "$MG/gp-rows.md" "$MG/rows")"
  case "$mrr" in 0\ seat-complete:*) bad "MUTANT mark/rows: SURVIVED mark-runs ('$mrr')" ;;
    *) ok "MUTANT mark/rows: the rendered rows=<n> line is refused by the engine (mark-runs: '${mrr%% *}'), not sealed" ;; esac
fi
#   M-c drop the <deliverable> clause from dev.md: mark-deliverable (c) names the block.
awk '{ sub(/ A worktree brief also carries `<deliverable>`.*$/, ""); print }' "$ROLES_DIR/dev.md" > "$MG/dev-nodeliv.md"
if cmp -s "$ROLES_DIR/dev.md" "$MG/dev-nodeliv.md"; then bad "MUTANT mark/no-deliverable: DID NOT APPLY"
elif mnd_o="$(dl_scan "$MG/dev-nodeliv.md")"; grep -q 'deliverable=0' <<<"$mnd_o"; then ok "MUTANT mark/no-deliverable: dev.md without its <deliverable> clause is named by mark-deliverable"
else bad "MUTANT mark/no-deliverable: SURVIVED"; fi

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
  ok "cwd: a decoy ai-dlc tree as cwd yields the byte-identical verdict (root: $ROOT)"
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
      *"root: $DECOY (consumer)"*) ok "MUTANT cwd: a resolver seeded from the cwd reads the decoy; the cwd arm kills it" ;;
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
