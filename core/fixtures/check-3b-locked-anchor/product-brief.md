<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
- LR-1: The reconcile step MUST refuse to run when the local branch is
  ahead of or behind its upstream by any commit, printing the exact
  divergence count and the remediation command, and MUST NOT fall back to
  a three-way merge under any circumstance including a clean working tree.
- LR-2: The post-compact re-attach budget MUST be capped at 5,000 Claude
  tokens measured against the recovery protocol region, and the validator
  MUST fail the commit when the region exceeds that ceiling.
<!-- END LOCKED_REQUIREMENTS -->

# Product Brief (fixture source-of-record)

This is the byte-verbatim source of record for the check-3b fixture. The
full requirement text above is what an honest story `full_text_source:`
citation must resolve to verbatim.
