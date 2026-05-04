# Retro Finding-Class Tracking Template

## Findings by Pass

| Pass | Finding ID | Severity | Finding Class | Description | Action |
|------|-----------|----------|---------------|-------------|--------|
| AR1 | F-AR-1 | IMPORTANT | regression | | |
| AR1 | F-AR-2 | MODERATE | schema-drift | | |
| AR2 | F-AR-3 | IMPORTANT | process-gap | | |
| PM | F-PM-1 | IMPORTANT | spec-ambiguity | | |
| TEA | F-TEA-1 | IMPORTANT | test-coverage | | |
| QA | F-QA-1 | IMPORTANT | gate-escape | | |
| DV | F-DV-1 | IMPORTANT | deploy-safety | | |
| SM | F-SM-1 | MODERATE | process-tracking | | |

## Finding Class Definitions

| Class | Description | Typical Source |
|-------|-------------|----------------|
| `regression` | Functionality that previously worked now fails | AR, QA |
| `schema-drift` | Data model diverged from spec without explicit decision | AR, TEA |
| `process-gap` | Pipeline step or gate failed to catch a known anti-pattern | AR, SM |
| `spec-ambiguity` | Requirement was unclear, leading to rework | PM, AR |
| `test-coverage` | Missing or inadequate test for a critical path | TEA, QA |
| `gate-escape` | Defect passed gate validation that should have caught it | QA, AR |
| `deploy-safety` | Deploy process risked or caused production issue | DV |
| `process-tracking` | Sprint tracking or status reporting was inaccurate | SM |
| `narrative-drift` | Rule text accumulated origin stories or soft language | AR (audit) |
| `dormant-gate` | Gate/CI check existed but never fired on relevant PRs | AR (audit) |
