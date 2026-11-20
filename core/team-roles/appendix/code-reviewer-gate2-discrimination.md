# Code Reviewer appendix: Gate 2 self-discrimination map

Reviewer applies this map at Gate 2 for any PR carrying
discrimination-evidence acceptance criteria. Reviewer-PASS verdicts
on discrimination-evidence ACs MUST cite self-discrimination map
application by-name. Enforced by `gate-validation.md` Check 19.

**Enforce-flip PR Gate 2 discrimination.** PRs that flip a CI gate
from advisory mode to enforce-fail-on-detect MUST exercise the gate
against the PR's own content under the real `pull_request` trigger.
The PR's own FAIL→PASS commit sequence (initial enforce flip catches
own-PR violations; fix-forward refines detector scope without
weakening enforcement intent) constitutes primary discrimination
evidence. Run IDs MUST be cited in the discrimination review doc
verbatim.

**Self-discrimination map mandate.** Enforce-flip PR body MUST
include a "Self-Discrimination Map" section listing each detector
branch and which own-PR content triggers it. If the PR's organic
content does not exercise all detector branches, author MUST add
scaffolding commits or a companion same-sprint PR that does, and
document branch-to-commit mapping. Without this, the pattern
collapses to "lucky discrimination" and is fabrication-permissive.

Ephemeral-matrix dispatch (separate injection branches) is
permitted as supplementary evidence ONLY, never as primary AC
discrimination. Real `pull_request` event evidence is required for
AC closure.

### Self-reflexive Gate 2 failure patterns

Reviewer MUST scan its own draft Gate 2 verdict against each pattern
below before posting. A draft verdict matching any pattern is
NEEDS_REWORK against the reviewer itself; the reviewer revises
before issuing.

**Pattern 1 — Reviewer asserts PASS without re-running the test.**

- *Detection signal:* Verdict cites an "all assertions pass" or
  "test green" outcome with no `$ <command>` REPL line and no run
  ID, OR cites a stale run ID copied from the dev's DAR rather than
  the reviewer's own re-execution.
- *Reviewer remediation:* Re-run the test locally or re-trigger the
  CI workflow under the reviewer's own session; capture the verbatim
  `$ <command>` invocation and its complete output (PASS/FAIL counts
  and run ID) in the review doc; replace the assertion with the
  REPL trace.
- *Gate-validation enforcement reference:* `gate-validation.md`
  Check 19 (this map) + Check 17 (skill-invocation provenance).

**Pattern 2 — Reviewer fabricates ancestor-check output.**

- *Detection signal:* Verdict cites `git merge-base --is-ancestor`
  output (e.g., `OK` / `FAIL`) without the `$ git merge-base ...`
  prompt line preceding it inside a fenced code block, OR the
  ancestor SHAs cited do not match the actual PR HEAD and base
  refs verifiable via `git log`.
- *Reviewer remediation:* Run the ancestor check directly against
  the live PR refs; paste the verbatim `$ ` prompt line followed by
  the command output; if the ancestor relation does not hold,
  surface the failure to the lead — do not invent passing output.
- *Gate-validation enforcement reference:* `gate-validation.md`
  Check 19 (this map) + Rule 13c strict-ancestor squash-merge
  survivability sub-clause (SKILL.md).

**Pattern 3 — Reviewer rubber-stamps discrimination evidence
without verbatim REPL trace.**

- *Detection signal:* Verdict APPROVES a discrimination-evidence AC
  while citing only the dev's claim that the detector fired/silent,
  without the reviewer's own corpus run output, fixture content, or
  CI run ID demonstrating the FAIL→PASS sequence.
- *Reviewer remediation:* Execute the corpus harness against each
  named detector branch; capture verbatim `assert_detector_fires` /
  `assert_detector_silent` output (with case label and PASS/FAIL
  count); cross-reference each branch in the Self-Discrimination
  Map to the specific commit SHA or fixture file that exercises it;
  reject the PR if any branch lacks own-PR exercise.
- *Gate-validation enforcement reference:* `gate-validation.md`
  Check 19 (this map).
