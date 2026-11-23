# QA appendix: locked requirements

Validation Checklist items for a story that carries a `LOCKED_REQUIREMENT`:

- [ ] **Per-locked-requirement adversarial null-impl (HARD GATE).** For each
  locked requirement in the story, QA names the simplest wrong
  (degenerate-but-type-valid) implementation and confirms ≥1 mapped AC REDs
  against it. If NO AC REDs against the named degenerate impl, the
  requirement is unimplemented-but-green — REJECT. Per-element ACs ("per
  item / per record / per element") MUST be verified on an N≥2 fixture
  asserting call-count / per-element args, never a source-string presence
  check. Catches a requirement satisfied only in appearance; false positive
  is a requirement whose only type-valid impl is the correct one (name it);
  remove when locked-requirement discrimination is enforced by a
  producer-side gate.
- [ ] **An AC that omits a locked requirement's action is a deviation for the operator (HARD GATE).**
  For each AC whose precondition falls inside the scope of a locked
  requirement's verbatim text, compare the AC's expected outcome with every
  action that text requires.
  An AC whose expected outcome omits an action the text requires is a requirement divergence, never a PASS.
  A precondition under which the required action has nothing to act on (an empty balance, an empty set) does not trigger this item.
  QA files a Tier 1 `HARD_BLOCK` with blocker type `requirement divergence`
  (SKILL.md Rule 12), quoting the LR id, its verbatim text and the omitted
  action, through `qa.md`'s Escalation Protocol.
  QA writes `Verdict: NEEDS_REWORK` with a `####` finding naming the HARD_BLOCK id; the lead puts it to the operator by `AskUserQuestion` under Rule 3(a), with no flag, before dispatching dev rework.
  If the operator accepts the degraded branch (`descope` of the omitted action), QA re-validates to PASS citing the entry; `do-now` proceeds as rework.
  Exempt only when (1) the degraded outcome is the one the requirement's own
  text prescribes (it asks to fail closed, or to degrade to exactly that
  value), (2) a Tier 1 `HARD_BLOCK` with blocker type `requirement divergence` that cites this LR and names this degraded branch already carries a recorded operator disposition (cite that entry), or
  (3) the AC's outcome performs none of the requirement's actions and reports that to the caller as a non-success (a refusal or error status, a disabled control, a dry-run marker), unless the requirement's verbatim text forbids that refusal.
  An entry of another blocker type, or one that names no LR, does not exempt.
  An answer to a trade-off is not a disposition of a requirement the AC no
  longer delivers. Catches a skip or degraded branch written into an AC
  against a locked requirement and passed as specified, so the requirement
  ships undelivered and the operator first learns of it live; false positive
  is an action the text requires only under a precondition the AC excludes
  (name the precondition); remove when the stories step refuses an AC that
  omits a locked requirement's action without a recorded disposition.
