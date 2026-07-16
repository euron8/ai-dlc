# Fixture: setup-config-drift

Adversarial self-test for `reconcile/unregistered-drift.sh`'s coverage of
`ai-dlc-setup/SKILL.md` and its **setup-config-region exemption**.

## The bypass scenario

`ai-dlc-setup/SKILL.md` is overwrite-on-pull core, but it sat **outside** the drift detector's
scan. So an in-place edit there was invisible to the HARD refile-or-revert gate and fell to the
both-changed classifier, whose default is **keep-ours** — silently perpetuating the in-place core
drift the layer system (Rule 27) forbids. Only an operator who knew the rule caught it; the tool
left it to chance.

The fix scans `ai-dlc-setup` **and** exempts the one region that is genuinely operator config —
`## STEP 2: API Tier and Model Strings` (the model-strategy mode + tier-per-role table + token
guidance) — declared as a `heading-block` setup-site. Config is exempt *by declaration*; the rest
of the wizard is guarded.

## What it proves

- a byte-identical consumer → `CORE-OK`;
- an edit **inside** STEP 2 (a real per-project strategy choice, e.g. Full → Balanced) →
  `CORE-TEMPLATE-SUBSTITUTED` (declared config, exempt);
- an in-place edit **outside** STEP 2 (rulebook prose) → `HARD-UNREGISTERED-CORE-DRIFT` (blocks);
- restore → `CORE-OK`;
- and that `setup-sites.md` actually declares the `setup-model-strategy` site (the exemption
  rests on a real declaration, not a hope).

The fake distribution's `SKILL.md` carries the **real** STEP 2 / STEP 3 headings, so the **real**
`setup-sites.md` site applies — this tests the actual declaration end-to-end.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped reconcile script); `run.sh`
resolves both the distribution and consumer layouts.
