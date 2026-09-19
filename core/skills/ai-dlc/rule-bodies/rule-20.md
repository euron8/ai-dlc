### Rule 20 -- Validation evaluations run in independent subagents with provenance

This file is the full text of Rule 20 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Validation evaluations -- the four sub-skills (`/bmad-party-mode`,
`/bmad-advanced-elicitation`, `/bmad-review-adversarial-general`,
`/bmad-prd`) **and the native `ai-dlc-adversary-review` convergence
review** -- MUST be evaluated by **real, independent subagents** -- never
roleplayed solo in the lead's own context. Independence is the point: a single LLM
evaluating an artifact it (or its own conversation) authored produces convergent
opinions and defeats the validation, and it absorbs delegable work into the lead's
context (Rule 28). The `mode` field of the emitted provenance block MUST be
`subagent` for ALL FIVE; `mode: solo` is forbidden for every one of them (not only
party-mode) and FAILS gate-validation Check 17.

Three provenance-bearing execution shapes, all `mode: subagent` (plus a fourth native shape
(iv) below, which carries its own schema instead of a provenance block):

**(i) Persona-spawning (`/bmad-party-mode --mode subagent --non-interactive`).**
The lead invokes it via the Skill tool in its own conversation, **with both flags**;
the sub-skill then spawns real persona subagents internally (bound by the
role-manifest preamble below), and those internal spawns satisfy independence.

**The flags are the mechanism. Without them this shape does not hold.**
`bmad-party-mode` ships `party_mode = "session"` in its `customize.toml` —
documented there as *"never spawn — one mind voices every persona inline"* — which
is precisely the solo roleplay this rule forbids. Only `--mode subagent` overrides
it. For 30+ sprints ai-dlc asserted the internal spawn as a fact, hardcoded
`mode: subagent` into the provenance template, and had Check 17 fail `mode: solo`
— while passing no flag and nothing ever observing the actual mode. The block the
lead writes is a self-declaration, so the check could only ever confirm what the
lead already believed.

`--non-interactive` is not optional and not cosmetic. The sub-skill's own contract
is *"a party is interactive and open-ended… it runs round after round until the
**user** signals done,"* with `--non-interactive` named as the one exception. Under
the old solo default that was absorbed — the lead voiced the personas in its own
context and simply stopped. Under `subagent` it is a live stall. **The two flags
must be passed together or the fix creates the deadlock.**

If a future harness drops Skill arguments, this shape is void and party-mode
personas must be dispatched by the lead as ordinary Agent spawns on per-seat
deliverables (the shape `carry-over-evaluation.md` already produces; their path
is prescribed once, in `steps/_gate-procedures.md` under "Validation cycle", and
is not restated here). Verify with `/bmad-party-mode --list-groups`:
it returns the group menu and starts no party. If a party starts instead, the
arguments did not arrive.

**(ii) Single-voice (`/bmad-advanced-elicitation`,
`/bmad-review-adversarial-general`, `/bmad-prd`).** These have no
internal spawn, so the lead MUST dispatch the invocation to ONE spawned
`adversary` teammate (Rule 19 binding to `.claude/team-roles/adversary.md` --
the role purpose-built for independent validation of a planning artifact: no
ownership stake, the sub-skill drives the method, the role supplies the
independence + model). The `adversary` invokes the named sub-skill in its OWN
context and writes the provenance block with `mode: subagent`; the lead applies
the returned findings. One role serves all three single-voice sub-skills -- the
binding does not vary by sub-skill (the sub-skill selects the method; the role
is constant). `code-reviewer` (diff-scoped) and `analyst` (read-only,
non-adversarial) are the WRONG bind here -- neither is an independent critic of
a planning artifact. Inline invocation of a single-voice sub-skill is
solo by construction (there is no internal spawn to make it independent), which
is exactly the failure this rule forbids. In ai-dlc's autonomous mode
(Rules 9/10: no mid-pipeline human dialogue) advanced-elicitation runs without
operator back-and-forth, so subagent dispatch does not break an interactive loop.

**(iii) Native convergence review (`ai-dlc-adversary-review`).** The Rule 8 cycle
invokes **no Skill at all**. The lead dispatches ONE `adversary` per pass (same
Rule 19 binding as (ii)); the METHOD is `team-roles/adversary.md` itself.
Procedure: `_gate-procedures.md`, "Adversarial review dispatch".
**Why it is not a sub-skill:** the bmad review skill demands *at least ten
findings*, *HALTs on zero*, and emits *no severity or ranking* -- so a loop whose
exit criteria are a bounded severity residue has no fixed point under it, and the
skill forbids the very severity fields Check 24 adjudicates. The counts the gate
reads had no source of truth. bmad remains correct, and still runs, for the
ONE-SHOT reviews (`bug-investigation`, `sprint-review`, the test-strategy sweep),
where nothing loops and no verdict is counted.

**(iv) Gate-check adjudication (`gate-adjudicator`, native — no provenance block).** At
every gate the lead dispatches ONE `gate-adjudicator` (Rule 19 binding to
`.claude/team-roles/gate-adjudicator.md`) that evaluates every `adjudication: llm` check for
the gate type in a fresh Opus context and delivers a `GATE_ADJUDICATION_VERDICT v1` file (its
own schema, `.claude/schemas/gate-adjudication-verdict.json`). This is NOT one of the five validation
sub-skills: no Skill runs, and it emits no `SKILL_INVOCATION_PROVENANCE` block — it is off the
Check 17 path. The lead adopts its per-check verdicts ONLY through fail-closed Check 26 and
never evaluates an `llm` check inline; roleplaying those judgments in the lead's own context
is exactly the solo failure this rule forbids, and escalating them to a fresh Opus context is
what lets a cheaper-model lead run the gate without weakening it. Procedure:
`_gate-procedures.md`, "Gate-adjudication dispatch".

**Provenance block.** Every invocation MUST emit a
`SKILL_INVOCATION_PROVENANCE v1` block into the artifact it produces,
**including `findings_critical` / `findings_major` / `findings_minor` —
what this evaluation actually found, at each severity.** All five owe the
counts, not only the convergence review; zero is a valid reading and the
honest one when nothing surfaced. Do NOT stamp a `verdict` unless you are
a Rule 8 convergence pass: a verdict enrols the block in a pass series
(Check 24). An evaluation that records no residue cannot be told apart
from one that found nothing, which is how a validation step accumulates
cost nobody can defend or cut on evidence.
The block's field schema lives in `.claude/schemas/provenance-block.json`, which
the reader loads and every taught example is rendered from.
`scripts/ai-dlc/validate-provenance-block.sh` parses the block;
`scripts/ai-dlc/validate-retro-evidence.sh` enforces transcript artifact +
byte-matched SHA citation for retro party-mode (see
`gate-validation.md` Check 17). Both run at the Step 5c pre-commit gate;
a consumer that ships `.github/workflows/validate-retro-compliance.yml`
also re-runs them on the retro PR, but a script-based consumer with no
`.github/workflows/` enforces them locally only — the local gate is
authoritative either way. Absence of the block at gate-validation is a
HARD_BLOCK.

**Forbidden failure mode.** Skill-shaped output (role-played personas,
findings lists) WITHOUT Skill tool invocation and WITHOUT provenance
block is a rule violation. "The findings are real" is not a valid
rationalization — the process IS the validation.

**The brief names the file.** Every dispatch that expects content back MUST state
the exact path the teammate writes to, in the brief itself. A brief whose delivery
contract is a chat reply ("reply with your analysis", "return your findings") is
MALFORMED and MUST NOT be issued. This rule and Rule 29 already say the file is the
handle; nothing stopped a dispatch from not having one.

The failure is not that the content is lost — it is that the loss is unreadable. A
teammate told to reply produces an idle notification and no file, and the post-compact
guidance then correctly reads unreachability as handle-loss rather than death. So the
lead sees a symptom that means "you lost the handle" for a teammate that never had a
deliverable to lose, and re-dispatches. A teammate whose contract names a path
delivers on the next beat with no re-dispatch; the same teammate on a chat-reply
contract returns nothing. The contract, not the teammate, decides this.

The path in the brief is the same path that goes in the In-Flight Teammates row at
dispatch (`_gate-procedures.md`, "Sub-step snapshot update") and the same path the
bounded join is armed over (Rule 29). One value, written once, in three places that
must agree — so a dispatch with no path produces no row, and there is nothing to arm the
join over, which is exactly the observed failure.

**File-write deliverable.** A party-mode persona delivers its verdict by
writing it to the canonical output/transcript path the invocation
defines and returning ONLY that path. A text-only final message from a
subagent is an unreliable transport; the lead MUST treat an absent file
as non-delivery and re-dispatch. Build no detector for this — the lead's
own read of the expected path is the check (Rule 26: audit before adding
mechanism).

*How long to wait for that file is not a judgment call.* The `Skill` tool
returns no `task_id`, so Rule 29's `TaskOutput` join cannot reach a persona.
Wait for it with Rule 29's **bounded file-wait beat** — never with a single
open-ended poll.

**Solo mode is forbidden -- for ALL FIVE evaluations.** Every validation
evaluation MUST run with real subagents (shape (i), (ii) or (iii) above), never
roleplayed inline. Roleplaying perspectives / running a single-voice pass or a
convergence review in the lead's own context (solo mode) produces convergent
opinions from a single LLM and defeats independent evaluation. Any evaluation
that emits `mode: solo` -- or generates evaluation output without a real
subagent -- is a rule violation and FAILS Check 17 (enforced by
`scripts/ai-dlc/validate-provenance-block.sh`, which rejects `mode: solo` on **any**
provenance block, unconditionally).

**Role-manifest preamble (persona-spawning sub-skills).** A validation
sub-skill that spawns personas (`/bmad-party-mode`) spawns real
subagents whose perspective must be governed by an ai-dlc role contract,
not left to the sub-skill's generic persona. Every such invocation MUST
carry this preamble, defined ONCE here and *referenced* (never restated)
by the call sites -- same single-source-of-truth discipline as Rule 19:

> Each participant persona MUST, as its FIRST action, Read and follow
> its ai-dlc role contract file, then debate from that lens:
> PM -> `.claude/team-roles/pm.md`,
> Architect -> `.claude/team-roles/architect.md`,
> Dev -> `.claude/team-roles/dev.md`,
> QA -> `.claude/team-roles/qa.md`,
> TEA -> `.claude/team-roles/tea.md`,
> UX -> `.claude/team-roles/ux.md`,
> SM -> `.claude/team-roles/sm.md`,
> CIS -> `.claude/team-roles/cis.md`.
> A persona not in this map debates as its BMAD default.

Pass only the map rows for the personas that invocation actually
convenes. Injection reaches the personas through the invocation context;
ai-dlc does not own `/bmad-party-mode` internals, so the mandate is
"MUST pass the preamble," not "MUST verify the sub-skill obeyed it."
Absence of the preamble at a persona-spawning call site is a
lead-conduct retro finding.
