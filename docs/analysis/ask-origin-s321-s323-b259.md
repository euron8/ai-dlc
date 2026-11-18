# Why the operator is asked, graph s321 to s323 (BL-972)

Batch 259, cluster C4d, 2026-11-18. The question, set by the operator: when the lead puts a question to the
operator, what prevented it from reaching the decision itself? The earlier framing of this reading, whether a
decision was knowable at planning, is kept as a secondary section.

## Answer

1. **Where the lead named a recommendation, the operator took it 41 times out of 45.** This is read from the
   transcripts and needs no judgment. 23 asks in which every answer was the lead's own recommendation waited
   859 of 2,770 minutes (31%). One is the 300-minute ask in s323's requirements step with 14 lanes behind it.
2. **For 26 to 29 of 145 questions (about 20%) nothing stopped the lead.** No rule, no missing fact, no
   outside effect: the lead held a decision or a recommendation and asked anyway, because the rule text makes
   it ask. This is the part a pipeline change removes. It is many questions and little wait: 17 to 173 minutes
   on the asks made only of them, depending on two asks the two readers class differently.
3. **Another 46 (32%) are reserved to the operator by rule, and 23 (16%) are go-aheads for an action with
   outside effect.** These two classes sit on most of the wait. A pipeline change does not remove them;
   narrowing what is reserved, or authorizing in advance, is the operator's decision.
4. **Facts only the operator holds and unclear earlier wording are 38 questions and almost no wait** (79
   minutes on the asks made only of them).
5. **Pipeline failures are 9 questions and 166 minutes**, none in s323's planning.

## Population and method

- Graph `/Users/n8/git/graph` transcripts, read only, at `EXTRACT_WIN_END=2026-11-18T17:54:00Z`. s321 and s322
  are complete. s323 is open (planning complete), so its figures are PROVISIONAL and its implementation and
  later steps are absent.
- Population: every lead `AskUserQuestion` in s321 to s323 from
  `docs/analysis/pipeline-efficiency-s323-provisional-b259/out/ask_split.txt`, less the asks that reader labels
  `pre-step`, which are in update sessions. 79 asks holding 145 questions and 2,770 minutes of answer wait;
  s321 45 asks, s322 19, s323 15.
- `scripts/ask_dump.py` joins each ask to its `tool_use` by timestamp for the question text and to its
  `tool_result` for the answer. Control: 79 of 79 population rows joined exactly one `tool_use` and none was
  denied or errored.
- **How the operator answered is mechanical** (`answer_kind` in `ask_dump.py`): whether an option label carried
  "(Recommended)", and whether the answer was that option, another option, the first-listed option of an
  unmarked question, or free text. 145 of 145 answers parsed.
- **What stopped the lead is a judgment**, made once per question from the question's own text and options,
  on rules fixed before any question was read:
  - **RULE.** The text says the decision is reserved to the operator: an operator-owned value, a waiver that
    is the operator's authority, scope, a named rule or locked requirement.
  - **ACT.** The lead needs a go-ahead for an action with outside or irreversible effect: a push, merge,
    deploy, live transaction or production configuration write.
  - **INFO.** The lead lacks a fact only the operator has: a value, a credential, an intent.
  - **AMBIG.** The operator's earlier words, or two documents, conflict or are unclear.
  - **DEFECT.** A pipeline or tooling failure the lead cannot resolve within its rules.
  - **NONE.** Nothing in the text prevents the lead deciding: it states its own decision or recommendation
    and asks for confirmation or a veto, or the choice is an ordinary engineering judgment.
- Two readers, one for odd-numbered asks and one for even, so reader and sprint are not confounded. Each
  question has one reading. The readers differ in mix (odd: INFO 17, NONE 11; even: INFO 7, NONE 18), so a
  class total is good to a few questions, not to one.
- A third reader (the tip adversary) classified 40 questions blind, the 18 in the ten long asks and 22 others,
  and agreed on 32. See "Second reading". Where its classes move a figure, both values are given.
- An ask's wait is counted once, on the ask. "Asks made only of X" are the asks whose every question is in X;
  that is the wait a change to X alone could remove. Wait is the operator's answer time.
- The question texts are not committed. `out/why.tsv` holds one row per question: header, class, the rule the
  text cites, the answer kind and a reason of at most ten words.

## What stopped the lead

Source: `out/why_tally.txt`, printed by `scripts/ask_why_tally.py` from `out/why.tsv`.

| Class | Questions | Asks made only of it | Wait on those asks | In how many more asks | Answer was the recommended option |
|---|--:|--:|--:|--:|---|
| RULE, reserved to the operator | 46 (32%) | 11 | 409 min (15%) | 23 | 8 of 9 marked |
| ACT, go-ahead for an outside effect | 23 (16%) | 11 | 964 min (35%) | 9 | 11 of 11 marked |
| NONE, nothing stopped the lead | 29 (20%) | 8 | 173 min (6%) | 14 | 13 of 14 marked |
| INFO, a fact only the operator holds | 24 (17%) | 7 | 22 min (1%) | 11 | 1 of 2 marked |
| AMBIG, unclear earlier wording | 14 (10%) | 4 | 32 min (1%) | 8 | none marked |
| DEFECT, a pipeline failure | 9 (6%) | 8 | 166 min (6%) | 1 | 8 of 9 marked |

By sprint: s321 RULE 25, ACT 20, NONE 9, INFO 17, AMBIG 5, DEFECT 5; s322 RULE 9, ACT 1, NONE 5, INFO 5,
AMBIG 2, DEFECT 4; s323 (planning only) RULE 12, ACT 2, NONE 15, INFO 2, AMBIG 7, DEFECT 0.

Combined: questions that are NONE, or that the operator answered with the lead's recommendation whatever
their class, are 57 of 145. The asks made only of such questions are 28 and waited 963 minutes (35%). That is
the most the wait could fall if the lead acted on every recommendation it already held; it includes reserved
decisions and go-aheads, so it is a bound and not a proposal.

100 of the 145 questions carried no recommended option. The operator chose the first-listed option in 67 of
them. Whether the first option was the lead's preference is not stated anywhere, so nothing is concluded from
it. 24 of the 100 say in their text that no option is recommended.

The ten asks over an hour, which hold 2,204 of the 2,770 minutes:

| Sprint, step | Minutes | Questions: class / how answered |
|---|--:|---|
| s321 deploy-validate | 645 | ACT / first option; ACT / first option |
| s322 carry-over evaluation | 340 | RULE / first option |
| s323 requirements | 300 | RULE / recommended; NONE / recommended |
| s321 deploy-validate | 264 | ACT / recommended |
| s323 carry-over evaluation | 200 | RULE / first option; NONE / first option; NONE / other option |
| s323 carry-over evaluation | 148 | NONE / recommended; NONE / recommended; AMBIG / first option; ACT / recommended |
| s321 gate[implementation] | 84 | NONE / free text |
| s321 deploy-validate | 83 | INFO / first option; ACT / other option |
| s322 implementation | 75 | DEFECT / recommended |
| s321 implementation | 65 | NONE / recommended |

## The rule text behind each class, and what changing it would have removed

Every removal figure below is an ESTIMATE on s321 to s323: it counts the questions of the class and the wait
of the asks made only of that class, and assumes the operator would not have overturned the lead. Dollars are
$0 throughout; the cost of an ask is wall clock.

### 1. NONE: the lead is told to ask a design choice it has a recommendation for (DEFECT, buildable)

- **Rule text.** `core/skills/ai-dlc/SKILL.md:454–455`: "A design choice no source settles is asked with one
  option `(Recommended)`." Rule 12 Tier 2 (`SKILL.md:404–413`), the escalation rule, has a trade-off with no
  objectively correct answer, or an implementation option among alternatives, decided, documented and
  continued. The two overlap for a value-neutral trade-off; they are not the same rule, and the sort at
  `:437–467` is the more specific one for a question on its way to the operator. It sends to Tier 2 only the
  choices a source settles (`:444–446`), and `:452–454` puts every choice that "sets, relaxes or widens a
  value, a limit or an authority" in the asked class, whether or not the operator owns the value.
  `SKILL.md:445–447` then sends each decided choice back through the blocking prompt: "add one veto line for
  it to the next `AskUserQuestion` you send".
- **Change.** A design choice no source settles, that sets, relaxes or widens no value, limit or authority, is
  decided on the lead's recommendation, recorded as a Tier 2 entry with its reason, and reported. The asked
  class of `SKILL.md:452–454` stays as it is. Veto lines go to the checkpoint's `### For Your Information`,
  where `SKILL.md:447–448` already sends them, and not into an `AskUserQuestion`.
- **Would have removed.** 26 to 29 questions, and between 17 and 173 minutes of wait. On the first reading 8
  asks are made only of NONE questions and waited 173 minutes (s321 5 asks 164 min, s322 1 ask 1 min, s323 2
  asks 8 min). 149 of those minutes are two asks that the change probably would not remove: the s321
  implementation ask "Story 5.6" (65 minutes) proposes deferring a story, which Rule 12 Tier 1
  (`SKILL.md:400`) makes a stop for sign-off, and the s321 gate ask "Matic stall" (84 minutes) is the one the
  operator answered by choosing none of the lead's options. Without the first the figure is 101 minutes over
  6 asks; without both, 17. 14 more asks would have been shorter but still asked. Six of the NONE questions
  carry the header "Veto lines" and a seventh offers a veto on a derived order.
- **What it would have lost.** In 25 of the 29 the operator's answer was the recommended or the first-listed
  option. The other four:
  - s321 requirements, "Unknown chain": unmarked, two options; the operator chose the second ("Leave silent").
  - s321 gate, "Matic stall": the operator answered in free text ("Check again") and chose none of the three
    read-only next steps.
  - s322 route, "Roll fix": the operator took the recommendation and added an instruction to file an upstream
    candidate.
  - s323 carry-over, "Proxy cert": unmarked, three options; the operator chose the third.
  So in two to three of 29 the lead's own pick would have differed from the operator's, and in one an added
  instruction would have arrived only when the operator read the report. Each would cost the rework after a
  veto. "Proxy cert" is not a neutral design choice: its options decide whether a production security change
  goes ahead, the third reader classed it ACT, and the next ask reopened its answer because the premise was
  false. Under the change as worded it stays asked, because it sets an authority.

### 2. RULE: decisions reserved to the operator (not a pipeline change)

- **Rule text.** `SKILL.md:340–347` and `:455–458`: a question that sets, relaxes, inherits or leaves in force
  a configuration leaf, a threshold or literal on a money path, a byte-pin, a locked requirement or a `D-<n>`
  decision is the operator's and is asked without a recommendation. `SKILL.md:462–467` adds scope
  confirmation, a locked requirement's boundary, and a gate STOP adjudication.
- **What the questions cite.** "Operator-owned value" 12 times; a locked requirement 3 times; a pinned hash,
  byte-pin or its ADR 3 times; a gate waiver that is the operator's authority twice; scope, a recorded safety
  invariant, a deferral to ratify and others once each. 20 of the 46 name no rule in their text.
- **Size.** 46 questions; 11 asks made only of them waited 409 minutes, 386 of those in s322 (one scope
  re-confirmation of 340). They sit in 23 more asks.
- **What the record shows.** Nine of the 46 carried a recommendation, against the rule, and the operator took
  it in eight. In the ninth (s322 handoff, "Push block") the lead recommended fixing three findings and
  pushing; the operator answered "Pause here."
- **Levers, both the operator's.** Narrow what counts as reserved; or keep the decision reserved and stop it
  holding the pipeline, which is BL-994's plain-text route in BL-972's owed list. Neither is proposed here.

### 3. ACT: go-aheads for an action with outside effect (the operator's to pre-authorize)

- **Rule text.** The questions cite graph's own rules ("Rule 916", its `CLAUDE.md` Rule (b)) and the deploy
  steps. Which core line requires each go-ahead was not located in this reading.
- **Size.** 23 questions; 11 asks made only of them waited 964 minutes, all in s321: 10 asks and 952 minutes
  in deploy-validate, 645 of them in one ask, and one ask of 12 minutes in requirements. The operator's answer was the recommended option in all 11 that had one, and the first-listed
  option in 9 of the 12 that did not.
- **Lever.** An authorization given at planning for a named action under stated conditions. That is the one
  place the earlier "declare it at planning" proposal fits. It is the operator's choice, per action.

### 4. DEFECT: the pipeline asking about its own failure (engine fixes, not a decide-first rule)

- 9 questions; 8 asks made only of them waited 166 minutes; 0 in s323's planning against 5 and 4 questions in
  s321 and s322.
- The operator took the lead's recommendation in 8 of 9. In the ninth (s321 implementation, "Gate refusal")
  the lead recommended a temporary local patch to a gate script and the operator chose to hold the two stories
  at the gate. A decide-first rule here would have patched the gate against the operator's wish, so it is not
  proposed. Each of the nine is an engine defect with, or owing, its own fix.

### 5. INFO and AMBIG: facts and wording only the operator can supply (cheap)

- 38 questions; the 13 asks made only of them waited 79 minutes. The 14 AMBIG questions come from an earlier
  answer or a locked requirement whose wording did not cover the case (7 of them in s323's planning).

### The four recommendations the operator did not take

| Ask | Class | Recommended | The operator's answer | Lost under change 1? |
|---|---|---|---|---|
| s321 implementation, "Gate refusal" | DEFECT | temporary local patch | hold the two stories at gate 1 | no: not in change 1 |
| s322 route, "Roll fix" | NONE | overwrite the archive | the recommendation, plus file an upstream candidate | the pick matches; the added instruction arrives at the report |
| s322 handoff, "Push block" | RULE | fix now, then push | "Pause here." | no: not in change 1 |
| s322 gate, "AWS login" | INFO | run the two commands now | a question back: why is this needed | no: not in change 1 |

Two are real overrides, and both are outside the class change 1 touches.

## Second reading

A third reader classified 40 questions from their text before seeing the classes above: the 18 questions of
the ten long asks and 22 from ten other asks. It agreed on 32. The eight disagreements:

| Ask, question | Above | Third reader | Its reason |
|---|---|---|---|
| s321 requirements, "Base service" | INFO | AMBIG | neither earlier answer says which |
| s321 requirements, "CLAUDE.md line" | AMBIG | RULE | the file is the operator's standing instruction file |
| s321 requirements, "HR-10" | RULE | AMBIG | the request conflicts with a recorded rule |
| s321 implementation, "Story 5.6" (65 min) | NONE | RULE | deferring a story needs sign-off |
| s321 deploy-validate, "Base save" (83 min) | INFO | ACT | the operator is asked to make a live save |
| s323 carry-over, "Proxy cert" (200 min) | NONE | ACT | every option decides a production change |
| s323 requirements, "Header premise" (300 min) | RULE | AMBIG | an earlier answer rested on a false premise |
| s323 requirements, "Check 928 AC" | NONE | AMBIG | a locked requirement has no defined observable |

On its sample three questions leave NONE and none enter: 29 becomes 26, the asks made only of NONE 8 becomes
6, and their wait 173 becomes 101 minutes. No disagreement moves a question into the class a pipeline change
removes. The 105 questions outside the sample have one reading.

The same reader recomputed every figure in the tables above from `out/why.tsv` and found none wrong, and
checked the quoted rule lines against `SKILL.md`.

## Secondary: when the decision became knowable

The first version of this reading classified each question by origin: planning-knowable (P), emergent evidence
(E), pipeline mechanics (M) or authorization (A). `out/classification.tsv` and `out/tally.txt` hold it.

- P 43 questions (30%), E 55 (38%), M 29 (20%), A 18 (12%).
- Asks made only of P questions waited 79 minutes; asks carrying any, 384. With A added: 912 and 1,077.
- A second reader classified the 18 questions of the ten long asks blind and disagreed on 7, six of them
  moving a question out of E. On its classes the figures are 144, 566, 1,060 and 1,342 minutes.
- That classification used two readers split along sprints (asks 1 to 40 are all s321), so its cross-sprint mix
  is not like-for-like.

It shows that asking the planning-knowable decisions as one batch reaches 3% to 20% of the wait. It does not
say why any question was asked, which is why it is no longer the lead finding.

## Not read

Each was available and not taken: a second reading of the 105 questions outside the third reader's sample; which core line requires each
go-ahead; the 20 RULE questions that name no rule, against the rule text; whether the first-listed option of
an unmarked question was the lead's preference; the s323 asks after planning, which do not exist yet at this
pin.

## Reproduce

```
D=docs/analysis/ask-origin-s321-s323-b259
python3 -I $D/scripts/ask_dump.py docs/analysis/pipeline-efficiency-s323-provisional-b259/out/ask_split.txt s321,s322,s323 > asks.jsonl
python3 -I $D/scripts/ask_why_tally.py $D/out/why.tsv
python3 -I $D/scripts/ask_origin_tally.py $D/out/classification.tsv
```

`ask_dump.py` prints the question texts and the mechanical `answer_kind`. The `why` and origin classes in the
two TSV files are readers' judgments and are not regenerated by a program.
