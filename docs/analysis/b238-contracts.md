# Batch 238 contracts (lead ai-dlc-fc, no-owner shape). Base origin/main 3234cf8ca.

Every cluster: its own branch `238-<cluster>` in its own worktree; each entry its own commit naming NO `PC-` id; its own
fixture arm + mutant; its `verify:` replaced by a receipt scored under `set -uo pipefail` against the fix (0), two
plausible regressions (non-zero), a second correct spelling (0). Remedies below are the adjudicating hands' readings;
the adversary tests them against the tree. "file:line" figures are from 3234cf8ca.

## C-R2 recover-gate: BL-687 + BL-688 (bootstrapping: core/hooks/)
- BL-687 (DEFECT, LIVE): `core/hooks/ai-dlc-recover-gate.sh` `snapshot)` arm (~:405) allows only the snapshot Read and
  the digest Read; a parallel full step Read whose hook runs before the snapshot call's stage write gets the FIRST
  deny. Fix per the entry: allow a full step Read in the `snapshot)` stage without advancing or satisfying the gate,
  marker left present. Receipt today exits 1.
- BL-688 (DEFECT, LIVE): same file ~:405-408, the stage write `{ printf 'step\n' ...; mv ...; } 2>/dev/null || rm -f ...
  || true; exit 0` is fail-open: under an unwritable `_bmad-output` the snapshot Read is allowed but the stage never
  advances, wedging every later step Read. Fix: the gate stands down (allows and disarms, or never arms) when the stage
  write fails, OR `core/hooks/ai-dlc-recover.sh` arms only when `_bmad-output` is writable. Receipt today exits 1.
- One release. Hooks ship to consumers via settings template registration (unchanged here) and the install copy.

## C-R3 enforcement-map greps: BL-674 + BL-697 (validator on the suite pole)
- BL-674 (DEFECT, LIVE): `scripts/validate-enforcement-map.sh:6719` `i55_roots='(REPO_ROOT|ROOT|D_ROOT|C_ROOT)'`; I55
  arm 3's reach scan recognises only four root variable names. Fix: derive the root names from `*ROOT=` assignments in
  each scanned file, with a two-direction self-probe seed. The entry's real-tree instance
  (`core/fixtures/gate-repair-record-mutants`) is gone; the self-probe must carry the case.
- BL-697 (NOTE, LIVE): `scripts/validate-enforcement-map.sh:11498` `i110_tokens` collects every backticked lowercase
  token within 6 lines after `In-Flight`. Fix: anchor on the In-Flight table's status column (or exclude role names),
  with the false-positive set measured over `core/skills/ai-dlc` and `core/hooks` before shipping. Receipt today exits 1.
- CLAUDE.md: a change to a validator the pole invokes is a change to the suite's wall clock. The lead approves ONE
  CPU-seconds differential (before/after, interleaved, same path), run by the lead in a slot after the batch's ready
  releases, per NO TIMING RUNS.

## C-S small, non-bootstrap, one hand each, one release per collection (or grouped as collected)
- BL-678 (NOTE): `scripts/plan-rotate.sh:937-938` rebuilds the archive pointer from this run's ranges only. Fix: merge
  ranges from the existing pointer; plan-rotate fixture arm asserting the first range survives; update the
  `core/fixtures/plan-rotate/run.sh:~691` header. Receipt today exits 1.
- BL-712 (NOTE, latent): `core/skills/ai-dlc-update/reconcile/layer-drift.sh:2037` reads a three-field TAB row with
  `IFS="$TAB" read`, which collapses an empty middle field. Fix: split by parameter expansion; fixture arm with an env
  key and no since. (ai-dlc-update engine: ships machinery-only; the consumer runs its installed copy.)
- BL-720 (NOTE): `merge-adversarial-shards.sh:1080` refusal says "re-dispatch the shard" when the SubagentStop probe
  row has not landed yet. Fix (minimal): the refusal names the wait (re-run the join beat), not a re-dispatch.
- BL-715 (NOTE): `join-remediator-shards.sh` checks `siblings:` only at the join (BADSIB :918, refused :1153). Fix: a
  per-part check mode reusing the join's classifier, and a one-line `core/team-roles/remediator.md` instruction to run it.
- BL-714 (NOTE): `core/skills/ai-dlc-update/reconcile/apply.sh:2014` re-emits LC-E19 `extension-title-match` as WORKLIST
  every pull with no register lookup. Fix: either a register lookup that suppresses a disposed row, or downgrade a
  pre-existing (unchanged since base) row to NOTE. Adversary picks the smaller correct one.
- BL-724 (NOTE, latent): `core/scripts/validate-cycle-commits.sh:633-634` keys `test strategy` to the `test-strategy`
  artifact; the coverage arm `:924-933` then demands a party-mode commit, which 0.890.0's Rule 8 carve-out removed for
  test-strategy.md. Fix: exempt the `test-strategy` artifact from the party-mode (and elicitation) cycle-type demand,
  citing the carve-out. (Lead ruling: in scope this batch; 52's hold was for 0.890.0 only.)
- BL-708 (DEFECT): ten fixture/script arms report ok with a required tool missing (sites listed in the entry). Fix: each
  arm fails (or is BROKEN) when its tool is absent, rather than passing; the hermetic-runner B4-B6 sub-claim stays
  out ("Not fixed here" in the entry).
- BL-707 (DEFECT): `core/fixtures/prepush-pool-depth/run.sh:171,211` reads `obs_d0_max` across a 0.3s window, so a
  slow box under-counts concurrency. Fix: each stub blocks until all six have entered (bounded wait), or read the
  dispatched width; mutant: a pool capped below 6 still fails the arm.

## C-H pre-push hook: BL-709 (+ BL-701 direction 1 only if the adversary names a buildable fix) (bootstrapping: .githooks/)
- BL-709 (DEFECT): a `core/scripts/hermetic-run.sh` change re-keys only the fixtures whose `inputs.decl` names the
  runner (6), so a runner change skips every other declared fixture. Fix B (runner span in every declared key) or C (a
  runner digest in the key record); `.githooks/pre-push` and `core/git-hooks/pre-push` are one program under I66.
- Pushed from the MAIN checkout detached at the release commit.

## C-D design-heavy: contract + adversary now; build only what the adversary makes nameable
- BL-692 (DEFECT): a hand re-render of the reconcile report passes `--verify` and apply writes unapproved rows. Owed fix
  per the entry: a digest of the approved region recorded at the first apply and compared at write time.
- BL-716 (DEFECT, efficiency): all SERIAL-REQUIRED repair items go to one serial remediator. Fix: partition into lanes
  by the parts each item touches.
- BL-721 (NOTE): a remediator with no deliverable file gives the bounded join nothing to wait on
  (`wait-for-deliverable.sh:1592`, `_dispatch-protocol.md:110-118`).
- BL-605 (DEFECT, PARTIAL): no arm judges an In-Flight row's `dispatched-at`; needs a `tool_use_id` in the row. Lead c8
  ruled no LATE arm ships — the adversary says whether anything else is buildable under that ruling.
- BL-719 -> BL-718 (DEFECT): emitters flip `=` to `@` only into a tree whose readers accept it; the open question is the
  use-time detection key.

## Not built this batch, with the measured reason (stated in the first ping)
BL-538, 583, 584 (owed 3), 587, 616, 706: each needs a consumer measurement or a gate log first. BL-553(b): its own
entry says not shippable as specified, FP set unrun. BL-685 (owner ai-dlc-69) and BL-699 (owner ai-dlc-77): owner
sessions are absent from ListAgents. BL-695: closes only on graph's next stories round. BL-691: design deferred by its
own entry. BL-701: direction 2 is a main-checkout `--reconcile` run by the lead; direction 1 rides C-H only if named.

## C-R1 (FIRST release, shortest gate): the derive grammar, the candidate's close, the register row
- Candidate `PC-S319-SELF-UPDATE-FIXTURES-RUNS-THE-COVERING-SET-SERIALLY-THEN-PRE-PUSH-RERUNS-IT-IN-PARALLEL` (graph
  ledger, committed 7a35abff0, 2026-10-19): ALREADY-FIXED in v0.886.0 (`f36ede45d`, BL-713). Serial loop at
  `2cb29a586:core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh:1154/:1194` and its pre-commit mandate at
  `SKILL.md:549` are gone at f36ede45d; the entry's own fix (b) shipped. Close channel: the id VERBATIM in the release
  commit message and in its CHANGELOG `###`.
- Its ledger receipt `theirs_lacks …/self-update-fixtures.sh "FIXTURE_POOL_BEGIN"` is mis-anchored on fix (a): the token
  is absent at every ref and present in graph's own hook, so reverify reads STILL-LIVE forever. Replacement for graph
  to adopt (a FINDING for the operator's brief, never a write to graph):
  `theirs_has core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh "\"$SU_HR_REL\" --root"`.
- Register: one post-pin row in `docs/reviews/graph-ledger-adjudication-data/post-pin-verdicts.tsv`
  (`437 <id> ALREADY-FIXED-v0.886.0 reconcile MIS-ANCHORED`), re-rendered by `render-register-tables.sh`, plus one prose
  paragraph under the table.
- Plan `lids()` (docs/plans/graph-ledger-full-drain.md, derive block): the BULLET arm admits an optional backtick before
  the id (`^-? ?\*\*\`?PC-[A-Z0-9]` / strip it in the sed), matching `ledger_entry_id()` (lib.sh:424). The heading arm is
  NOT widened (0 backticked headings in every ledger and archive). Measured: the old grammar hid the live candidate
  and the archived `PC-S319-ADJ-CORE-TEXT-DROPS-FILELESS-EXTENDS-ANCHOR-UNDER-IFS-TAB-READ`, which made 6 qualifying refs
  drop out and left CONVERGENCE-ADVERSARY reading live off a stale ref; corrected: refs 171, live 1, unfiled 1,
  DISCHARGED 0, TERMINAL 248, archive 372. The plan comment beside lids() records the measurement.

## C-R3 FOLD (adversary b238-adv-r3: 2 BLOCKER, 3 DEFECT, 3 NOTE — supersedes C-R3 above)
- BL-674: NOT the `*ROOT=` name grammar (3 FP: backlog-ledger/run.sh:201,:315 MROOT; ledger-reverify/seed.sh:888;
  2 false zeros). Roots are derived from the RHS SHAPE of an assignment: `$(cd "$HERE/../../.." …)` /
  `$(cd "$(dirname "$0")/../../.." …)`, a VERSION walk-up target, or an alias of an existing root; plus literal
  `$HERE/../../../<entry>` reads. Inside the existing one recursive grep + one awk of `i55_reach_scan` (no new fork, no
  per-file loop). Control at :6822 uses the same derivation. Measured corpus: 5 hits, 0 FP (scratch:
  cr3/bl674g.sh). Self-probe rows: flagged = climb-assigned root, walk-up, `$HERE` climb; acquitted = `TMPROOT="$(mktemp -d)"`.
- SAME RELEASE disposes of the two live hits, or the arm goes red: core/fixtures/schema-install-fallback/run.sh:87 and
  core/fixtures/enforcement-map-sites/run.sh:3054 — `+VERSION` in each fixture's inputs.decl (check the hook's
  READSET_KEYROWS span accepts a top-level `+VERSION`), or for :3054 stop copying the real VERSION into the decoy.
  Prefer `+VERSION` where the read is real.
- BL-697: anchor A6 — an `In-Flight` line opens the 6-line window only if it carries `In-Flight[`*]*[[:blank:]]+Teammates`
  or `[Ss]tatus`, or it ends in `In-Flight` and the next line begins `Teammates`; window measured as DISTANCE from the
  last good anchor (`grep -rHn -A6`), never an on/off flag. Measured: token set unchanged except `agent` (a column),
  8 reader files kept (scratch: cr3/bl697e.sh). Re-seed the near-miss at :11581 under a good anchor; add `ux`,
  `zz-near` (non-role) and a wrapped-heading positive to the self-probe AND the receipt. Rewrite header :11468-11475.
- Receipts: BL-674 extracts `i55_roots`/`i55_reach_scan` and runs on a mktemp tree: fix 0; shipped 4 names non-zero;
  `*ROOT=` name grammar non-zero; hand-added `D9_ROOT` name non-zero. BL-697: A6 0; shipped 1; role exclusion non-zero
  (zz-near); single-line Teammates anchor (A4) non-zero (wrapped positive).
- Arm title lines and vocabulary markers untouched, so invariant-index and vocabulary-index do not move.

## C-R1 FOLD (adversary b238-adv-r1: 1 BLOCKER, 4 DEFECT, 1 NOTE — supersedes C-R1 above)
- Close HOLDS (ALREADY-FIXED-v0.886.0, f36ede45d). Simulated on a scratch clone: after the release graph's reconcile
  prints NAMED-UPSTREAM-OFF-SUBJECT + STILL-LIVE (receipt mis-anchored), not a close.
- BLOCKER fixed: the replacement receipt is `verify: theirs_has core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh
  "DISPATCH: hermetic"` (quote-free; the backslash form is refused at ledger-reverify.sh:2681). Measured CLOSE-CANDIDATE
  at theirs=3234cf8ca. This goes to the operator as a finding for graph; ai-dlc writes nothing to graph.
- lids() class gains `_` in BOTH arms' sed (`[A-Z0-9_.-]`): `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX`
  truncated to `…-GIT`. Bullet grep `'^-? ?\*\*\`?PC-[A-Z0-9]'`, sed `'s/^-? ?\*\*\`?(PC-[A-Z0-9][A-Z0-9_.-]*).*/\1/'`;
  heading grep unchanged. With both, plan grammar == shipping grammar on live (1/1) and archive (372/372).
- Same-invocation control in the derive block: compare `lids "$f"` to a `ledger_entry_awk`-backed extraction
  (scratch cr1f.sh `ship()`), assert equal. No validator arm (KISS; measured both divergences would fire).
- Register: row in post-pin-verdicts.tsv, re-render + `--check`; rewrite the "three post-pin entries / none is a close"
  sentences at docs/reviews/graph-ledger-full-adjudication.md :86, :90, :277, :282, :398; paragraph names ref
  ae1fafcf8 (carry-over branch; not on graph main), the refused receipt, the replacement, both measured reverify rows.
  Do NOT touch render-brief.sh's pre-existing refusal (4357/4392/4435).
- Release text: id verbatim in the commit message and a CHANGELOG `###` (0.639.1 precedent form); NO `Not-discharged:`.
- Plan stays under P8 150000 (148127 now): comment <= 2 lines; `wc -c` after.

## C-R2 FOLD (adversary b238-adv-r2: 2 BLOCKER, 4 DEFECT, 3 NOTE — supersedes C-R2 above). Probe dir: scratchpad/cr2.zARksE/, scripts cr2-*.sh
ORDER: commit BL-688 FIRST, then BL-687 (same `snapshot)` arm; each receipt scored against the OTHER commit alone too).
- BL-688 fix: a per-call `[ -w "$STATE_DIR" ] || exit 0` in core/hooks/ai-dlc-recover-gate.sh beside the readability
  block (~:330), deleting nothing. The contract's two shapes FAIL (measured rc=1): clearing the marker cannot act in a
  555 dir; arming only when writable cannot see a chmod after arming. It also clears a SECOND wedge the entry does not
  name (dir goes unwritable after stage reached `step`: satisfying Read cannot remove the marker, every call SECOND).
  Second correct spelling: `[ -w "$STATE_DIR" ] && [ -x "$STATE_DIR" ] || exit 0`. Optional (N2): best-effort
  `rm -f "$MARKER"` in the `||` branch at :408 for ENOSPC; if added, `rp_s_killed` (fixture :2290) must still pass.
- BL-687 fix: in the `snapshot)` arm before the FIRST deny (~:426), allow a FULL (`is_full_read`) Read whose `FABS` ==
  `STEP_ABS`, writing NO stage, marker, `.recover-satisfied` or `.recover-advisor-owed` — EXCEPT keep the deny when
  `STEP_REL` matches `*/steps/handoff.md|steps/handoff.md` (else ai-dlc-handoff-entry.sh:179 arms .handoff-in-progress
  from a compelled Read; grain as handoff-entry.sh:168-169). Second spelling: fold `"$FABS" = "$STEP_ABS"` into the
  digest-allow `if` at :421-425.
- Fixture core/fixtures/postcompact-rulebook-recovery/run.sh: BL-687 turns arms rp_r_clear (:2322) and rp_r_ctl
  (:2328) red — retarget both to `$_rq/decoy.md`, re-measure M-684's flip set (:2465). New arms keyed ship-ahead with
  `skip` like the existing rc blocks, `rc_post`-style no-movement checks. BL-687 mutants: nofull, adv, sat, widen, drop.
  BL-688: snapshot-then-Edit and step-then-Edit under chmod 555 (restore 755 on EVERY exit path); mutants shape A,
  shape B, drop. core/fixtures/handoff-completion-assertion/run.sh: one arm that runs `edrive` only when the gate allowed.
- Receipts (rewrite both): the `z.md` liveness line becomes `|| exit 1` (exit 9 only for jq, missing hooks, mktemp, the
  marker precondition, the permissions-ignoring write test). BL-687 adds a bounded-step-Read (`limit:1`) deny check.
  BL-688 keys on `g Edit a.md` carrying neither FIRST nor SECOND under 555 after snapshot + step Reads, plus the
  wedge-2 seed. Score each: fix 0; two regressions non-zero (687: nofull, widen; 688: shape A, shape B); second
  spelling 0; the other commit's change alone non-zero.
- No install.sh or settings template change (install.sh:376 copies core/hooks/*.sh; template registers both hooks).

## C-S FOLD (adversary b238-adv-s — supersedes C-S above). Probe scripts: scratchpad/cs-*.sh
- BL-678: TWO sites. Old ranges are read from the existing pointer line (`line[pln[q]]`, :522) with PFX/SFX stripped,
  INSIDE the splitter awk; the same merged string feeds `ptr_cost()`/`render_ranges()` (:316-339) AND the writer
  (:937-938), or :956 refuses every second rotation. Append in run order, do not sort. Header at
  core/fixtures/plan-rotate/run.sh:~691 rewritten; two-rotation arm asserting the first range survives. Mutant: drop old
  ranges in render_ranges only. Receipt: the entry's own `verify:` (fix 0; today 1; writer-only merge 9; prepend 0).
- BL-712: split layer-drift.sh:2037 by parameter expansion. Arm in core/fixtures/layer-readopt-gate/run.sh (~:1731-1746):
  a 4th declaration with `settings_env_key: AI_DLC_WIDGET_NOSINCE` and no since; row carries
  `replaces_with=AI_DLC_WIDGET_NOSINCE`, not "ADOPTED ... nothing to configure"; the 3 existing declarations are the
  control. Mutant: restore the IFS read. Receipt drives layer-drift.sh over that world (fix 0; today non-zero; default-
  empty-since-but-IFS-read non-zero; awk -F'\t' / cut -f spelling 0). Commit names :1213, :2361, :2648, :2889 as
  same-shape TAB reads checked and out of scope (state the producer guarantee for each). ai-dlc-update engine.
- BL-720: rewrite only the tail after `recorded nothing for it:` at merge-adversarial-shards.sh:1080: name the wait first
  (re-run the merge once the writer's SubagentStop row lands), keep re-dispatch with `--rerun` as the remedy when the
  row stays absent. Correct the stale header :60-62 (a `sha=` seal is DELIVERED with no window,
  wait-for-deliverable.sh:345-347). Fixture: one `has` on the wait phrase in `p_probe_absent`
  (adversarial-shard-merge/lib.sh). Receipt drives the D4 world, keyed on a re-run token AND `re-dispatch`.
- BL-715: exclusive `--check-part <part>` mode in join-remediator-shards.sh, modeled on `--agent-writes` (:333-339):
  contract_probe, contract_check 0, contract_refusals 0, exit 2 with BADSIB text identical to :1153; NOSIB remedy
  (:1129 "re-dispatch the shards") suppressed/reworded in this mode; JR_ROOT and STATE_PARENT set so CTL resolves.
  core/team-roles/remediator.md: one line ordering check -> fix -> re-check -> `--mark` (:78-88 make --mark last);
  decide pm-escalated.md:106 and say why. Arm in core/fixtures/remediator-shard-join: near-miss `siblings: checked` part
  refused with BADSIB identical to the join's; well-formed part exits 0. Mutant: mode skips contract_check. Rulebook
  file => its own release (not with BL-712).
- BL-714: PREMISE EXPIRED — the register lookup exists (layer-drift.sh:2686-2690 `adj_lookup ...
  EXTENSION-TITLE-MATCHES-CORE`, v0.291.0 b6a714116; layer-title-join parts 6b/6c/6d). Build NO engine code. Build an
  apply-level arm: seed a verdict, run apply.sh, assert 0 `WORKLIST extension-title-match` rows for that entry and 1 for
  an undisposed control. If it reads 0 today, the entry closes as already-fixed with a corrected body and that receipt.
  If not, report — the premise holds after all.
- BL-724: carve-out for the `test-strategy` key in validate-cycle-commits.sh that `continue`s past ALL three arms
  (min_cycles=3 at :543/:914-918, party-mode :929, AR_RE :748 which does not match the 0.890.0 label), prints
  `EXEMPT (Rule 8 carve-out: convergence series, Check 24)` and appends to `exempt_current` (:939-942 require it). Not
  keyed on a version. validate-mandatory-rules.sh unchanged. Arm in cycle-commits-enforce with a seeded `Test Strategy`
  section + AR-only commits; mutant removes the carve-out. Receipt: fix 0; party-only exemption non-zero; spelling-only
  `test strategy` match non-zero against `Test-Strategy`; `## Sprint N -- test-strategy` section 0.
- BL-708: fix apply-legacy-script-path/run.sh:307,310 (cksum: before/after non-empty, one line per file);
  backlog-ledger/run.sh:772 (BROKEN on empty tail substitutions); relocation-preclassify/run.sh:243 and
  handoff-completion-assertion/run.sh:2089 (cmp exit >1 is BROKEN, keep 0/1 apart); route-read-required/run.sh:130
  (`cp … || broken`); scripts/plan-rotate.sh:689-690 (refuse exit 2 when either md5 is empty); readset-skip/run.sh:1847
  (failing `uname` BROKEN; perl stays an optional SKIP). LEAVE core/scripts/validate-artifact-budget.sh (SKIP on no jq
  is by design, ships). Re-measure budget-summary-verdict and backlog-receipt-binding under a restricted PATH before
  touching: adversary measured both already red with the tool absent — if so, no fix, the entry body says so.
  hermetic-runner B4-B6 out of scope.
- BL-707: driver-side barrier in core/fixtures/prepush-pool-depth/run.sh: each stub creates its flight file then waits for
  a release file (and self-releases on its own cap); the driver polls until 6 are in flight, ceiling ~30s, then
  releases; on timeout FAIL by name "N of 6 entered within 30s". Mutant: pool capped at 5 keeps obs_d0_max in the moved
  set. Do not change the hook (I66 lane).
- Releases: S1 machinery = BL-712, 720, 724, 678, 707, 708, 714. S2 = BL-715 (rulebook file).

## C-H FOLD (adversary b238-adv-h: 0 BLOCKER — supersedes C-H above). Receipt: scratchpad/ch-bl709-receipt.sh
- BL-709: fix B, one awk rule in `readset_decl_keys` (READSET_KEYROWS, .githooks/pre-push ~:1615-1617): a `.now` path equal
  to `core/scripts/hermetic-run.sh` or `scripts/ai-dlc/hermetic-run.sh` emits `out(f, p, v)` for every `f in FX` (out()
  emits only paths present in .now, and dedupes). Whole-file key, not the HR_SANDBOX span. hermetic-run.sh unchanged
  (it sources KEYROWS from the hook). Byte-identical in core/git-hooks/pre-push (I66; spans md5 8d620159… today). Comments
  at ~:1527-1533 and ~:1718-1725 updated in both hooks. Fix C REJECTED (a 4th header line breaks `tail -n +4` at :1753
  and the readset-skip header slices; store reuse silently dies).
- readset-skip/run.sh: placeholder `core/scripts/hermetic-run.sh` in `ckd_world` + cell `rchg` (one byte changed ->
  `run:k:ok`; regressions read skip), CKD_WANT (:5123-5142) and the mutant want (:5174); VS_WANT (:6032) ->
  `g=run/run/run/run/run/skip`; retire `vs_mut wholefile` (:6354) with the reason (the key now carries the whole-file sha);
  `ident-drops-keyrows` want (:6371-6372) -> `g=run/run/run/run/skip/skip`. Confirm census-hermetic-coverage:501.
- Receipt (one `verify: sh` line from ch-bl709-receipt.sh): fix 0; clause deleted 1; only the core/scripts literal 1;
  awk lookup-array spelling 0.
- Release: pushed from the MAIN checkout detached at the commit. Its own push runs every declared fixture once (key
  migration: every declared key gains the runner row). State it in the release text and ping. No .prev shim.
- BL-701 direction 1 ALREADY SHIPPED in 0.881.0 (829011111); not in C-H. Its receipt's `n` half measures committed `# digest`
  freshness, which the in-pool trace never writes, so it drifts with every tree change — the receipt is stale (lead's to
  re-scope at close: the `m` half plus a local-map clearing arm).

## C-D FOLD (adversary b238-adv-d) — supersedes C-D above
- BL-721 BUILDABLE (remedy shape): in `dispatch_live()` (wait-for-deliverable.sh ~:1590) the `[ "$COMPLETE_REPAIR" -eq 1 ] ||
  return 1` gate moves to gate only the GRANT; for any beat whose `--dispatch` resolved one agent, a LIVE or RECENT answer
  replaces the bare remedy (no grant, still exit 1; LIVE still grants only under --complete-repair). Third band: transcript
  older than IDLE_SECS under a resolved --dispatch with the path absent prints a STOPPED line (names the transcript; a writer
  with no deliverable file finishes without writing one; read its last message before any re-dispatch) in place of
  ~:2061-2062. Fixture: new arm in core/fixtures/wait-beat-liveness reusing receipt-bl605.sh's ledger/meta seeds,
  AI_DLC_MAX_WAIT_BEATS=1, plain `--dispatch <agentId>` on a never-written path, subject not first in the ledger: fresh
  transcript prints LIVE DISPATCH and not "Re-dispatch the teammate ONCE"; stale prints STOPPED. Mutants: gate restored
  (bare remedy back); widened to no-`--dispatch` beats (near-miss arm without --dispatch must still print the bare remedy).
  Second spelling: the `toolu_` id. Receipt: fix 0, both mutants non-zero, toolu_ spelling 0.
- BL-719 BUILDABLE in ONE release (+ BL-718 closes with it): a `--pair-sep` mode (in merge-adversarial-shards.sh) prints `@`
  only if (a) the sibling validate-adversarial-convergence.sh declares `^PAIR_SEP='[=@]'$` exactly once, (b) the sibling
  partition-subject.sh does the same, (c) the schema resolved by validate-provenance-block.sh's own chain (:164-169) has
  `.patterns.artifact_sha` containing `[=@]`; else `=`. partition-subject.sh gains `PAIR_SEP='[=@]'` and uses it in its case
  patterns (:271-276); the merge's own parser (:1289-1295) likewise. Emitters merge :701, :1328; join-remediator :2330,
  :2339 call the helper. Teachers (adversary.md:396, _gate-procedures.md :395 :502 :537 :716 :725 :817 :859 :1057 :1089,
  remediator.md) tell the model to write the separator `--pair-sep` prints. Shipped fixtures asserting `=` in emitter
  output move in the same release. Fixture: installed-layout tree; current readers -> `@`; three arms each swap in one
  reader from 8df9b8ae6~1 -> `=`; mutants dropping partition-subject or the schema from the key print `@` in their arm.
  Second spelling: core/ layout same answer. Receipt: fix 0, both drop-a-reader mutants non-zero, core/ layout 0.
- NOT built, measured reasons: BL-692 (first-wins approved-region record needs a consumer measurement: does graph's HEAD move
  between step 5 and apply within one apply invocation — readable from graph's committed reconcile branches; and the
  entry's own suggested fix fails its receipt). BL-716 (the correct lane key is connected components over edit: files +
  HIT + MOVED-CITE files; the joined record's per-stem before/after chain assumes one writer; needs the component count on
  S319's 148 items from consumer history first). BL-605 (only remaining item is the late arm lead c8 ruled out; its "no
  join key" premise is stale — dispatch_epoch_of already resolves it; needs c8's ruling scope confirmed).
