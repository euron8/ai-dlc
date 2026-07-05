---
name: deploy-validate
description: Deploy to production, run smoke tests, present production validation checkpoint to human
nextStepFile: STOP or next sprint
---
<!-- STEP_LOADED_TOKEN: deploy-validate -->

# Deploy and Validate (Phase 4+)

**Purpose:** Deploy all sprint changes to production, validate the
deployment, and present the Production Validation Checkpoint to the human.

## EXECUTION SEQUENCE

### 1. Pre-Deployment Check

Verify all sprint stories have passed all three gates (code review, QA,
story validation). If any story has not passed, do not deploy — go back
to implementation.

**Sprint-overall PR pre-staging verification.** Per `sprint-review.md`
"Sprint-Overall PR Incremental Pre-Staging" mandate, verify that the
sprint-overall PR was assembled incrementally throughout the sprint,
not post-hoc at sprint-close. Audit: carry-over candidates and
partial-close accounting MUST appear in
`_bmad-output/implementation-artifacts/sprint-<N>-*.md` files
committed during the sprint, not added in the final sprint-overall
commit. Final sprint-overall PR assembly MUST be merge + diff check
only, not composition. This rule applies UNIVERSALLY to all
sprint-overall PRs, not gated on anchor count or story count.

### 2. Deploy

<!-- {deploy_command}: Your project's deployment command.
     Examples:
     - docker compose build <service> && docker compose up -d <service>
     - kubectl apply -f k8s/
     - vercel deploy --prod
     - ./scripts/deploy.sh production
     Adapt the deployment steps below to match your infrastructure. -->

Run the project's deployment command:
```
{deploy_command}
```

If your project requires pre-deployment configuration checks (e.g.,
environment selection, resource scaling, migration status), run those
before deploying.

### 2b. Deploy-freshness gate (Hard Gate — where deploy exposes a running-artifact digest)

**Placement: AFTER deploy, BEFORE smoke tests.** For EVERY deployable
unit with changed paths in the sprint diff, the lead MUST prove the
just-built artifact is the one actually running before smoke tests run.

<!-- {running_digest_command}: read the CONTENT DIGEST of the artifact
     currently running in the target environment (e.g. the image digest
     of a running container/task, a build hash from a version endpoint).
     If your deploy model has NO queryable running artifact (static site,
     serverless function, published library), you have no digest to read:
     skip the digest equality check and assert freshness via the
     fallback below (rollout/publish timestamp > merge timestamp). -->

1. Read the CONTENT DIGEST of the artifact currently running in the
   target environment ({running_digest_command}).
2. It MUST equal the content digest of the artifact just built and
   pushed for this sprint; also confirm the rollout/start timestamp is
   newer than the merge.
3. If the running digest does NOT match the built digest for any changed
   unit, the deploy did NOT happen: the gate FAILS, smoke tests MUST NOT
   run, and the lead returns to the deploy step.

**Where the deploy model exposes no running-artifact digest**, this gate
does not vacuously pass: assert freshness on the rollout/publish
timestamp instead — it MUST be newer than the sprint merge — and record
in the gate log that no digest was available.

**Freshness MUST be asserted on the running-artifact CONTENT DIGEST (or,
in the fallback, the rollout timestamp), never on a re-pointable
pointer** (image tag, deployment/task revision id, release id or
handle). A force-redeploy re-pulls the SAME revision, so such a pointer
is EXPECTED to stay UNCHANGED after a successful redeploy — asserting
freshness on an unchanged pointer is a FALSE-FAIL that masks a real
deploy.

**Minimum mechanism (Rule 26(c)).** Failure caught: merge succeeded but
the new build never became the running artifact (stale deploy), so smoke
would green-light the previous sprint's code. False-positive cost: a
legitimate no-op redeploy where the built digest genuinely equals the
prior running digest — resolve by confirming the rollout timestamp is
post-merge, not by digest alone. Removal condition: retire only if
deploy tooling is made to fail closed on a non-fresh rollout.

### 3. Smoke Tests (Hard Gate — Non-Skippable)

**Hard smoke enforcement.** The smoke test full profile MUST run at
every deploy-validate regardless of which paths changed. "No service
deploy" does NOT exempt the sprint from smoke verification — scripts
modifying smoke-test infrastructure, thresholds, or operational
behavior MUST be verified against live infrastructure. A deploy-validate
gate log entry without `smoke_run_evidence` (the tee'd output path or
CI run ID) FAILS the gate unconditionally.

If live infrastructure is unreachable (VPN down, SSM broken, cloud
outage), file HARD_BLOCK — do NOT present PVC without smoke evidence.

<!-- {smoke_test_command}: Your project's live smoke test command.
     Examples:
     - python3 -m pytest tests/test_smoke.py -v
     - npm run test:smoke
     - ./scripts/smoke-test.sh
     The command should test the live deployed instance, not a dev server. -->

Run live smoke tests and **capture output**:
```bash
{smoke_test_command} 2>&1 | tee test-results/smoke-test-output.txt
```

**Smoke tests MUST pass.** If any smoke test fails:
1. Do NOT proceed to the Production Validation Checkpoint.
2. Diagnose the failure — is it a deployment issue or a code issue?
3. If code issue: route back to the dev teammate to fix, re-deploy,
   and re-run smoke tests.
4. If deployment issue: fix the deployment and re-run smoke tests.
5. Repeat until all smoke tests pass.
A deployment with failing smoke tests is a broken deployment. Do not
present it to the human for validation.

Verify the deployed build contains expected changes:
```bash
# Adapt verification to your deployment type:
# - Web app: grep deployed JS/CSS bundle for expected component/function names
# - API: curl health endpoint and verify response
# - Service: check version endpoint or deployment metadata
```

**Log all command outputs.** Gate validation check #8 requires this
evidence. Do not summarize — capture the actual output.

### 3b. Function Verification (Hard Gate — Non-Skippable)

Smoke tests verify availability; this gate verifies FUNCTION. A
dead-but-warm service passes health checks and smoke tests while
doing no work. Before presenting the PVC, probe the production
work-execution telemetry (execution log, processed-work counters,
job/queue completion records — whatever records the system doing
its job) and verify the deployed feature has actually executed its
function.

<!-- {function_verification_command}: A read-only probe of your
     production work-execution telemetry. Examples:
     - count rows in an execution/audit log table since deploy
     - query a processed-work or completion-event metric
     - grep production logs for completion events on the changed path -->

- Expected work appears in the telemetry → PASS.
- Attempts present with zero successes, or expected activity
  absent → FAIL. HARD_BLOCK: do NOT present the PVC; root-cause
  first.
- Zero expected activity in the window (quiet ≠ broken) → PASS;
  record the reasoning.

**Config-gated feature activation check.** For every requirement
whose behavior depends on a configuration or feature-flag value, the
pipeline MUST trace that flag to its actual PRODUCTION value and
confirm it holds the state the requirement needs before reporting the
requirement verified. "The feature exists in the code" is NOT evidence
it is active in production — a config-gated requirement is unverified
until its live value is read. Read the value from the running
production system (the config, environment, or parameter store the
deployed code actually consumes), never from a repo default or the
intended value. Catches: a requirement that passed code review, QA,
and smoke while its gating flag stays off, or set wrong, in
production — the feature ships dark and its regression or absence
passes every green gate undetected. False-positive cost: one
read-only lookup of each gating flag's live value; no write, no deploy
risk. Remove when: no deployed requirement's behavior depends on a
configuration or feature-flag value.

**Post-activation live-log check (gated features).** When a feature
is activated during deploy-validate by writing a config flag, env
var, or runtime parameter, read PRODUCTION logs after activation and
confirm the newly-reachable code path actually fired. Silence is not
proof of success, and test output is NOT evidence of production
firing; the evidence MUST be production log lines anchored to a real
post-activation event. Catches: an activation that silently no-ops —
the deploy reports success while the newly-reachable path never runs.
False-positive cost: one read-only production log or telemetry read
after activation. Remove when: deploys no longer activate features by
changing configuration at deploy time.

Capture probe output verbatim in the gate log under
`function_verification_evidence`. A deploy-validate gate log entry
without it FAILS the gate.

### 4. Visual Verification (UI Sprints — Evidence Required)

If `is_ui_epic == true`:
- Fetch deployed application endpoints
- Verify every new/modified UI surface renders correctly with production data
- Compare against documented mockups (from ui-direction step)
- For any drift: fix directly, redeploy, re-verify
- **Document results:** List each surface verified, whether it matched
  the mockup, and any drift found/fixed. Gate validation check #9
  requires this evidence.

### 4b. Deferred-AC discharge verification (Hard Gate — Non-Skippable)

Every AC deferred at an earlier gate with a `deploy-pending` discharge
predicate (see `qa.md` "Deferred-AC discharge predicate") comes due here.
For EACH such AC, the lead MUST run its named discharge predicate against
production and confirm the stated result — GREEN — before the sprint is
done. Capture each predicate's command/query and its live output in the
gate log under `deferred_ac_discharge`. A deferred AC whose predicate is
not run, or runs non-green, BLOCKS done: it is either a HARD_BLOCK (the
promised behavior is absent in production) or a re-deferral with a fresh
recorded predicate — never a silent pass.

**Minimum mechanism (Rule 26(c)).** Failure caught: an AC deferred to
"verify after deploy" that no step ever re-checks, so the sprint closes
with an unverified acceptance criterion. False-positive cost: one
predicate run per deferred AC — the predicate the AC already named.
Removal condition: retire once deferred-AC predicates are collected and
run automatically at deploy time.

### 5. Production Validation Checkpoint

Present to the human:

```
## Production Validation Checkpoint

**Sprint:** [sprint ID/name]
**Status:** Deployed and smoke-tested

### What Was Built
[Bullet list of features/fixes delivered]

### Deployment
- Services deployed: [list]
- Smoke tests: PASSED / FAILED
- Function verification: PASSED / FAILED
- Visual verification: PASSED / N/A

### Gate Log
See: _bmad-output/implementation-artifacts/gate-log.md

### Escalation Log
See: docs/escalations/pending.md
- DECIDED_AUTONOMOUSLY entries: [count] — review recommended
- DEFERRAL_REQUEST entries: [count] — approval needed
- HARD_BLOCK entries: [count, should be 0 or resolved]

### Next Steps
[If multi-sprint: "Sprint 1 of N complete. Awaiting your validation
before proceeding to Sprint 2."]
[If single sprint: "Sprint complete. Retro will run next."]
```

### 6. Wait for Human

**STOP.** Wait for the human to:
1. Review the deployed production instance
2. Review any `DECIDED_AUTONOMOUSLY` entries
3. Approve or override autonomous decisions
4. Approve any `DEFERRAL_REQUEST` entries (or reject and require implementation)
5. Confirm validation or request fixes

### 7. Post-Validation Routing

After human validates:

- If **human requests fixes:** Apply fixes, redeploy, re-validate, and
  present the checkpoint again.

- If **multi-sprint and more sprints remain:** Update sprint-status.yaml,
  then route the next sprint's stories through validation before
  implementation. The stories were created during initial planning but
  MUST be validated before each sprint begins — context from the
  previous sprint's implementation may surface issues that affect
  upcoming stories.

  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/sprint-review-next.md`

- If **single sprint or final sprint:** Proceed to retro.
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/retro.md`
