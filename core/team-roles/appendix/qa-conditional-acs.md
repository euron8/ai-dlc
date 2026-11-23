# QA appendix: conditional ACs

Validation Checklist items for a story that carries the AC, allowance or live path each item names:

- [ ] **Protective-direction check (HARD GATE).** Any AC guarding a
  bound / limit / ceiling MUST assert the bound in the protective direction —
  the side that constrains the risk — not merely the absence of the known
  failure mode. REJECT if the AC stays green under a wrong-side bound.
  Catches a bound assertion that still passes when the guard is inverted;
  false positive is a symmetric bound where either direction is protective
  (record which side is asserted); remove when bound ACs are generated from
  a directional template.
- [ ] **Perf-bound input-shape regime (HARD GATE).** Any AC bounding a
  performance metric (latency, throughput, memory, query/allocation count)
  MUST name the input-shape regime in which the bound holds — the concrete
  size parameters that drive cost (e.g. collection size, fan-out /
  cardinality, nesting or recursion depth) — and MUST be tested against a
  fixture at the UPPER BOUND of observed / expected production load for
  those parameters, not a convenience-sized fixture. A perf AC with no named
  regime is unfalsifiable (it passes at any size the author picks); a perf
  AC tested only at a small fixture is green by under-load and says nothing
  about production. REJECT either. Catches a perf bound "proven" at a
  fixture smaller than production, so the metric blows the bound live while
  the AC stays green; false positive is a regime-independent bound (a
  constant-time operation — name the exemption); remove when perf ACs are
  generated against a load fixture derived from measured production
  percentiles.
- [ ] **Permitted pre-existing failures are enumerated by test ID (HARD GATE).**
  If the story allows the suite to be non-green on failures it did not cause,
  the allowance MUST list the failing test IDs, and the run MUST fail exactly
  those. A count is not an identity: "11 failed" matching a baseline of "11
  failed" can be a completely different 11, and a regression introduced by this
  story then lands looking like the baseline. Catches a new failure swapping
  places with a tolerated one; false positive is a parametrized ID that changes
  legitimately (record the new ID and why); remove when the baseline is stored
  as a machine-checked ID set rather than prose.
- [ ] **Live-run attempted under envvar gate (HARD GATE):** For stories whose smoke tests include a live-against-production path gated by an envvar (e.g., `SMOKE_TESTS_LIVE=1`), verify the Dev Agent Record documents that the live run was attempted (not merely that the code path exists). Missing live-run attempt evidence = REJECT. A passing test suite run with the envvar unset does NOT satisfy this gate — the live path was skipped, not exercised.
