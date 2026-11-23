    - [ ] **Cross-CI plugin-installation parity (HARD GATE):** If this
          story adds a pytest or vitest plugin dependency or CLI flag,
          grep `.github/workflows/**` for every `pytest` or `vitest`
          invocation. For each invocation, verify either (a) the plugin
          is installed in that job's deps install step, or (b) the flag
          is not applied to that invocation (co-located pattern).
          Log the grep output and plugin-install confirmation in the
          story file under "Cross-CI Parity". Violation = Critical
          code-review finding.
    - [ ] **Naming-implies-behavior assertion.** A method whose name asserts a
          behavior (`batched`/`bulk`/`atomic`/`chunked`/…) MUST be proven by
          `mock.call_count` / `call_args` on an N≥2 fixture, never by a
          source-string check (e.g. `assertIn("batch", body)`). A name-only
          test stays GREEN against a degenerate single-pass implementation;
          code-review classifies such an AC unimplemented and QA rejects.
    - [ ] **Wall-clock ordering evidence.** For an AC whose correctness
          depends on the wall-clock ordering of concurrent processes
          (process reaps, signal or parent-PID races, spawn-then-kill), the
          gate evidence is a repeated live or near-live harness: N≥10
          real-process runs, every one clean, with the command and all
          results logged in the story file. Mocked-timing unit tests and a
          single live run do not satisfy the AC; mocked tests MAY supplement.
