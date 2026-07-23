# shadowed-local-validators Fixture

Discriminating self-test for
`core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh`, the signal that a
local validator fork's divergence has been upstreamed.

`run.sh` builds a throwaway consumer tree under `mktemp`: a synthetic push-candidate ledger
(closed and open entries, heading shape), a `local/` dir of forks, and a `core/` dir of the
validators they shadow. It drives the script through `--root/--ledger/--local-dir/--core-dir`
and asserts a fork is flagged RETIRE-CANDIDATE on exactly one condition set:

- **flagged** — the ledger entry is CLOSED (`ADOPTED UPSTREAM`), the fork exists, AND it
  shadows a real core validator (`validate-foo.sh`).
- **not flagged** — the entry is OPEN (`validate-bar.sh`), the fork is absent
  (`validate-nofork.sh`), the fork shadows no core validator (`some-tool.sh`), or there is no
  ledger entry at all (`validate-orphan.sh`).
- **never blocks** — exit 0 always.

The MUTATION control drops the CLOSED gate in the entry-walk (`if (closed && …)` ->
`if (…)`) and requires the OPEN `validate-bar.sh` fork to then be flagged — proving the
`ADOPTED UPSTREAM` gate is what suppresses open entries, not a coincidence. Run `run.sh` to
reproduce.
