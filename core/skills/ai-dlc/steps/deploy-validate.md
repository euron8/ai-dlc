---
name: deploy-validate
description: Deploy to production, run smoke tests, present production validation checkpoint to human
nextStepFile: STOP or next sprint
---

# Deploy and Validate (Phase 4+)

**Purpose:** Deploy all sprint changes to production, validate the
deployment, and present the Production Validation Checkpoint to the human.

## EXECUTION SEQUENCE

### 1. Pre-Deployment Check

Verify all sprint stories have passed all three gates (code review, QA,
story validation). If any story has not passed, do not deploy — go back
to implementation.

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

### 3. Smoke Tests (Evidence Required)

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

Verify the deployed build contains expected changes:
```bash
# Adapt verification to your deployment type:
# - Web app: grep deployed JS/CSS bundle for expected component/function names
# - API: curl health endpoint and verify response
# - Service: check version endpoint or deployment metadata
```

**Log all command outputs.** Gate validation check #8 requires this
evidence. Do not summarize — capture the actual output.

### 4. Visual Verification (UI Sprints — Evidence Required)

If `is_ui_epic == true`:
- Fetch deployed application endpoints
- Verify every new/modified UI surface renders correctly with production data
- Compare against documented mockups (from ui-direction step)
- For any drift: fix directly, redeploy, re-verify
- **Document results:** List each surface verified, whether it matched
  the mockup, and any drift found/fixed. Gate validation check #9
  requires this evidence.

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
[If single sprint: "Sprint complete. Kick off /bmad-retrospective when
ready."]
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
  load next sprint's stories, and:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`

- If **single sprint or final sprint:** Proceed to retro.
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/retro.md`
