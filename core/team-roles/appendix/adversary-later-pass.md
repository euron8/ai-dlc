**A MAJOR the previous repair wrote does not block the exit; the merge decides which those
are, never you.** A MAJOR is repair-introduced when every one of its `quote:` spans is text
the repair between the previous pass and this one wrote. The merge computes that class from
the reviewed bytes and writes `findings_major_repair_introduced:`, `findings_major_unjoined:`
and `repair_introduced_keys:` (`<shard>#<id>`) into the pass header. You never write those
fields and never label a finding repair-introduced; grade and report every MAJOR on the
ladder above, and stamp your own verdict from the three bullets above on your own counts. The gate's blocking MAJOR count is
`findings_major - max(findings_major_underived, findings_major_repair_introduced)`, declared
in `validate-adversarial-convergence.sh`. A CRITICAL always blocks, whatever text it cites. A
repair-introduced MAJOR is still owed a repair: its key closes only as `repaired`, never as
`DEFERRED`.

**The bar for excluding a CRITICAL from `findings_critical_prior_scope`.** Name the
artifact `file:line` and assert that text did not exist at the previous pass. If you
cannot, **it counts as prior scope.** An unfalsifiable exclusion is not an exclusion
— the same three-part discipline the CRITICAL rung already demands. And
`findings_critical_prior_scope` may never exceed `findings_critical`: it is a subset
of your own count, not a second opinion about it.

## Later passes review the REPAIR, not the document again

Pass 1 reviews the artifact. **Pass 2 and beyond review what the previous pass
changed** — the repair is the artifact under review, including when your shard is one of
a full-width map (`merge-adversarial-shards.sh --derived-map` prints a `full width:` reason when it does not narrow).
In a stories (files-mode) pass, a shard whose story is unchanged since the previous pass reviews
the WHOLE story, not only the repair. You MUST:

1. **Verify the prior pass's findings were repaired**, one by one: for each, state
   `repaired` / `partially repaired` / `not repaired` / `repaired wrongly`. A
   half-applied rename or a fix that contradicts a neighbouring line is a defect the
   repair created, and it is the single most valuable thing you can find.
2. **Not re-litigate a settled disposition without NEW evidence.** The lead recorded
   a decision; re-opening it because you would have chosen differently is churn, not
   review. New evidence means new evidence, not a new opinion.
3. **Report divergence explicitly.** If you are finding more criticals **in scope the
   pass before you already reviewed**, say so in your first line and say why. That is
   a signal the repair step is injecting defects faster than review removes them —
   the lead needs to stop and change approach, not run another pass. Silence there
   turns a broken cycle into an endless one.

   Your first line **restates** `findings_critical_prior_scope`; it does not
   substitute for it. Prose the gate cannot read does not close the cycle.
