### Rule 11 -- Seek clarity when ambiguous -- HARD_BLOCK severity

This file is the full text of Rule 11 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Two observable requirements.

**(a) Ambiguity resolution.** Ask for clarification when you detect
genuine ambiguity in the user's request, requirements, or intent. Do
not ask about matters resolvable by reading existing artifacts,
project memory, or applying professional defaults. **Relief for a live
defect that only the operator can apply is an operator-only decision and
is ALWAYS asked** (`bug-investigation.md` §2b): professional defaults and
Rule 12 Tier 2 do not reach it, because Tier 2 covers choices the lead
can carry out itself.

**Put the question to the operator with `AskUserQuestion`, the
recommended option first unless the question is unbadged (below), and set
NO pause flag for it.** The option
constraint on every `AskUserQuestion` is stated in Rule 3's pause-point
section and is not restated here.

**Every option states its concrete effect, INCLUDING the value it leaves
in force** -- on the option itself, not only in the question: *"inherit
the offramp leaves: swap skipped for balances <= 0.01 token0"*, not
*"inherit and say so"*. **A question is UNBADGED -- options presented
neutrally, none marked `(Recommended)` and none placed first as the
pick -- when it decides a value the operator alone owns and no operator
words fix: its options set, relax, inherit or leave in force a config
leaf, a threshold or literal on a money path, a byte-pin, an `LR-` or
`LRC-` id, or a `D-<n>` operator decision in the spine.** Those values
are the operator's to own, and a badge on one hands the
operator's decision back to the lead under the operator's name. A question typed as prose at the end
of a reply, followed by ending the turn, reads as narration: the
operator sees a paragraph of recap, not a decision that is theirs to
take, and the decision is never taken. The tool holds the turn open, so
the Stop hook never runs and a flag set here is a pause nobody clears --
the same reason Rule 3 gives for (d).

**Before any question reaches the operator, do four things to it.**
(1) Search for a prior answer in the sprint's `LOCKED_REQUIREMENTS`
block, `_bmad-output/operator-requests-history.md` (the operator's typed
words, the initial prompt included) and
`_bmad-output/operator-answers-history.md`; a value found there is
applied with its citation, not asked again. (2) Derive what the tree,
the config or a read-only chain or API read can give -- an address, a
band, a list of entries -- and put the derivation to the operator for
veto instead of asking for the value; when the derived value is a config
leaf, a money threshold or literal, an address, or an `LR-` or `D-<n>`
value, that veto question goes out UNBADGED, as above. (3) Gloss every project-internal
term in the question text itself: a check number, a band, a gap or
evaluation id, a `D-<n>`, `LR-` or `FR-` id gets a plain-language clause
saying what it is, because the operator reads the question, not the
artifact behind it. (4) Dispatch, then ask, as the `#### Operator decisions: dispatch, then ask` subsection below.

**Item (3)'s plain-language duty binds every piece of lead prose the
operator reads, not only question text:** the Production Validation
Checkpoint and every other checkpoint or pause presentation, status
reports, answers to the operator's own questions, and the handoff,
resume and next-sprint prompts the operator reads or pastes. In that
prose a label the lead coined itself -- in its planning artifacts or
earlier in the session, such as a name it gave one piece of an
operator's item -- is replaced by the plain phrase it stands for;
defining the label beside it does not satisfy this rule. Every id that
names a requirement, check, record, story or decision -- an `LR-`,
`CO-`, `HB-`, `D-<n>`, escalation, story or check id -- carries a
plain-language clause saying what it is, whether or not the operator
has seen it before; one clause may cover a contiguous range or a class
of ids. A commit sha or an image digest is not such an id. Where a
template slot or another rule requires the id or label itself -- a
verbatim quote of a requirement bullet, a cited entry id, a disposition
key, failing output -- keep it unchanged and put the plain-language
clause beside it or after the quotation, never inside the quoted text.

**One shape for every operator decision, the sort before asking, and no re-ask of an attested act** -- stated in full under the four `#### Operator decisions` subsections that close this file; apply all four to every question you put to the operator.

**(b) In-flight interpretation preamble.** The first line of the
agent's response to ANY user message that arrives during or after an
execution phase MUST be a one-sentence interpretation stating whether
the message is being treated as a question or a directive. Example:
*"Reading this as a question about the escalation decision --
answering below, not acting."* A missing first-line interpretation is
a rule violation, not a soft fail.

**Absolute.** The preamble requirement has no exceptions. "The intent
seems clear" is not a valid reason to skip it. A known degradation
mode in long sessions: as the conversation accumulates execution
turns, the lead starts pattern-matching on recent behavior and
misreads user questions as directives. The preamble requirement is
the mitigation -- forcing the lead to state its interpretation out
loud makes the misread visible before it becomes action.
Rationalizing around this rule is itself the failure mode the rule
catches.

#### Operator decisions: sort before asking (Rule 11(a))

**Sort every question three ways before it is asked.** (i) **A design
choice a source settles is decided, not asked.** The sources are the
operator's own words -- a prior answer of any length in
`_bmad-output/operator-answers-history.md`, a request in
`_bmad-output/operator-requests-history.md`, or an operator quote inside
a `LOCKED_REQUIREMENTS` entry -- and, for WHERE and HOW only (a code
path, a check's placement, which component reads what), the tree. It is
a HOW decision under Rule 13 (`rule-bodies/rule-13.md`): record it as a
Rule 12 Tier 2 `DECIDED_AUTONOMOUSLY` entry naming its source and a
one-line reason; it reaches the operator only under `### For Your
Information` at the checkpoint (`steps/deploy-validate.md` §5). The
standing-rulings record `_bmad-output/operator-standing-rulings.md` is
consulted before a question is asked (`scripts/ai-dlc/standing-rulings.sh
lookup <header>`; a hook denies a `AskUserQuestion` whose header equals an
active row's `match:`, until the question text carries `not SR-<n>:
<reason>`). A header match is a consult: if the row's `ruling:` decides the
question, record a Rule 12 Tier 2 `DECIDED_AUTONOMOUSLY` entry citing the
row instead of asking; if it does not, re-ask with `not SR-<n>: <reason>`.
A row is created only from the operator's answer to a proposal whose text
carries `Standing ruling proposal: match=<match>; class=<class>`, where
`<match>` is the row's `match:` exactly and `<class>` is `pipeline-family`
or `update-family`; a proposal naming a class of this sort's Outside list
(`scope-confirmation`, `gate-stop`, `operator-relief`, `tier1`,
`locked-requirement`, `step-reserved`), no class or another class never
becomes a row, and a row never decides a question on that list. `source:`
cites one of two entries: the answer's `operator-answers-history.md` entry
for an `AskUserQuestion` proposal, or the `operator-requests-history.md`
entry tagged `- Pending decision: DP-<s>-<n>` for a pending decision whose
Decision/Question line carries the same marker; `ruling:` is the reply
verbatim. This holds on a money path, a config leaf or a pinned span, PROVIDED the
choice leaves every operator-owned value in force or sets it to the
operator's verbatim value or that value exactly converted between units.
Such a choice decides no value, so Rule 11(a)'s UNBADGED trigger does
not reach it. A choice that otherwise sets, relaxes or widens a value, a
limit or an authority is settled by no source. (ii) **A design choice no
source settles is decided on the lead's recommendation only when every
one of these holds:** no operator answer, request or
`LOCKED_REQUIREMENTS` entry speaks to it, however unclearly (one that
does is a Rule 11(a) ambiguity and is asked); it needs no fact only the
operator holds (what they meant, intend or observed); none of its
options sets, relaxes or widens a value, a limit or an authority, or
keeps one in force that another option would change, where a value is
any value Rule 11(a)'s UNBADGED trigger names (a config leaf, a
threshold or literal on a money path, a byte-pin, an `LR-` or `LRC-` id,
a `D-<n>` decision), an address, an enable flag, a cap, a ceiling, a
timeout, a retry count or a rate, and an authority is who or what may
act, sign, spend, deploy, waive, patch or re-baseline a check, or reach
a secret; it changes no story, acceptance criterion or requirement in
scope; it decides no action on a live system (a deploy, a fire, a write
to live data, a spend) and no security, authentication, certificate or
trust behaviour, whether written now or shipped as code; none of its
options changes what the deployed system shows or does for a user, an
operator or an external party; and its effect can be undone after the
checkpoint. Record it as a Rule 12 Tier 2
`DECIDED_AUTONOMOUSLY` entry whose `**Decision/Question:**` line opens
`source: recommendation`, naming the options weighed and a one-line
reason; it reaches the operator under
`### For Your Information` at the checkpoint, not as a question. Any
other design choice no source settles is asked with one option
`(Recommended)`. (iii) **Only
a value the operator alone owns and no operator words fix is asked
UNBADGED, as Rule 11(a) says** -- a number, an address, a limit, an
enable flag, a secret, wallet or security config. **The tree never
settles a value**: a literal found in config, code or a staged artifact
is a derivation to put for veto under Rule 11(a)'s item (2), not a
source; and words a lead wrote into a `LOCKED_REQUIREMENTS` entry are no
source for what they add. **Outside this sort, each asked as its own
rule says:** the sprint-scope confirmation (`steps/route-fresh-start.md` Step 6),
operator relief (Rule 11(a), `bug-investigation.md` §2b), a choice that
moves a locked requirement's boundary (Rule 13), any Rule 12 Tier 1
matter (a choice that contradicts an operator-approved decision, a
requirement divergence, or a carry-over deferral), a gate STOP
adjudication (`steps/_gate-procedures.md`), and any other decision a step
reserves to the operator.

#### Operator decisions: one shape (Rule 11(a))

**Every decision put to the operator has one shape, wherever it is
asked** -- an `AskUserQuestion`, a checkpoint's `### Decisions for You`
item (`steps/deploy-validate.md` §5), a disposition at any step. It names
the decision asked,
gives every option with its effect and the consequence of choosing it,
and marks exactly one option `(Recommended)`. A question that carries no
badge -- an UNBADGED question (Rule 11(a)), or the sprint-scope confirmation
(`steps/route-fresh-start.md` Step 6) --
says so in its own text, with the reason,
so the missing badge does not read as an omission.
Each premise the question states as fact carries one `path:line`
evidence locator.

#### Operator decisions: an attested act is not raised again (Rule 11(a))

**An act the operator has attested is not raised again.** When the
operator says an act has happened -- a press, a deploy, a fired
operation -- read the record that would attest it before asking
anything further, and ask again only when that record is absent, naming
the record you read and did not find. Once you have accepted the
operator's word on an act,
no later step puts it back to the operator:
if you still want the record, read it yourself before any later
question, and carry the act as attested. An escalation entry the act
resolves still cites the operator's own message (`escalations.md`); the
record replaces the re-ask, not the citation.
A record read afterwards that shows the act did not occur is an authorization-premise invalidation (`escalations.md`), not a re-ask.

#### Operator decisions: dispatch, then ask (Rule 11(a))

**Immediately before every `AskUserQuestion`, dispatch, then ask.** Join
every lane whose completion has arrived: read the completion and record
it. Acting on its output is itself a ready action, dispatched below, not
work to finish before asking. Dispatch every ready action the question
does not hold, in the background (Rule 29), and arm its join. An action
is ready when its inputs exist now, and the question holds it only when
it reads the answer. Name the lanes held in your output beside the
question, not inside it. Then send the question at once, in
`AskUserQuestion`, unchanged by the lane state. Never wait for a running
lane before asking, and never hold back, defer or drop a question, or
fold it into a later one, to suit the lanes.

#### Operator decisions: proceed on the recommendation (Rule 11(a))

**A decision whose work is cheap to redo may be put as a pending decision instead of a question.** Number it `DP-<sprint>-<n>`, file a Rule 12 Tier 2 entry in `docs/escalations/pending.md` with `**Status:** DECIDED_AUTONOMOUSLY`, a `**Decision/Question:**` line opening `source: recommendation`, and `**Veto window:** open — DP-<sprint>-<n>`, dispatch the work under the `(Recommended)` option, then end the turn on a block whose heading line is `DECISION PENDING — DP-<sprint>-<n> — proceeding on (Recommended) unless you veto`, followed only by the option lines. The Stop hook then does not raise the Rule 11(a) warning for that turn. The window stays open until you close it: read the operator's reply, clear the pause flag, record the answer, and set the window to `closed — DP-<sprint>-<n> — _bmad-output/operator-requests-history.md:<heading line of the reply's entry>`. The window has no age limit and survives a resume; a resumed lead may re-ask an open decision with `AskUserQuestion`, and that answer closes it. A decision whose work is not cheap to redo is asked with `AskUserQuestion`.
