# Untangle mode

## Untangle mode — one-time Phase-2 migration (`untangle` = dry-run, `untangle apply` = execute)

For a still-tangled consumer (core files mix upstream prose with in-place
consumer divergence — domain-local machinery, rewordings, un-pushed
innovations — because the Phase 2 layer split was never done), `untangle`
performs that split as a one-time migration, invoked from the consumer exactly
like the ordinary pull. It reuses the same self-contained, consumer-side
posture and the same shared classifier — it is one of the four jobs
`reconcile/classify-block.md` already serves (see SKILL.md's "Shared engine, thin orchestrator" section).

**Precondition check.** If `{skill}/extensions/` or `{skill}/overrides/`
already hold more than their scaffold `README.md`, this consumer has already
untangled — refuse and report that, rather than re-running blindly.

**Steps 1–4: identical to the pull procedure in SKILL.md's "Procedure" section**, with one change: step 3
runs `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> --untangle`.
This exists because untangle is typically invoked when the consumer's stamp
already equals upstream HEAD (`base == theirs` — no upstream delta to pull,
only accumulated in-place divergence to split out). A plain `base`→`theirs`
diff is empty in that case, so `--untangle` mode enumerates the core-manifest
file list from `reconcile/setup-sites.md` and, for the fixture entries,
`fixture-manifest.md` beside `reconcile/` instead, and buckets purely by
`ours` vs `base`. `classify-block.md` itself needs no changes: a manifest file
that lands in `BOTH-CHANGED->CLASSIFY` still gets diffed and classified
exactly as it is for an ordinary pull, and any block the consumer touched
while upstream (at `base`, standing in for `theirs`) did not is already
handled by the classifier's existing `consumer-only-in-block` bucket.

Before any block in a manifest-listed file reaches the classifier, mask
declared `setup-sites.md` sites (per `reconcile/mask-reinject.md`) so
setup config is never misclassified as rulebook divergence and never routed
into an `extensions/`/`overrides/` file.

**5u. Migration-plan dry-run.** Write
`_bmad-output/ai-dlc-update/untangle-plan.md` (own filename; coexists with the
ordinary pull's `reconcile-report.md` in the same directory) with a header
stating `Generated: <UTC timestamp> by ai-dlc-update skill_version <X> @
<sha>` — same reason as step 5's report: a fixed filename overwritten on
every run, so the stamp is the only way to tell a fresh plan from a stale one
left over from before a skill update. Then: per-file bucket
tally, proposed `extensions/`/`overrides/` file list (`hooks:`/`shadows:`+`id`
per the entry contracts in `extensions/README.md`/`overrides/README.md`),
push-candidate list, conflict list, a **needs-confirmation list** (every
`needs_operator_confirmation: true` block per `classify-block.md`, each with
its specific question — separate from the conflict list, same as step 5),
the masked-site list (so the operator can
catch a manifest miss before it's acted on), **and an explicit list of any
consumer-only files with no upstream equivalent at all** (e.g. an extra
team-role file, an extra subdirectory under the skill root) — name them, state
they will be left untouched and queued to the push-candidate ledger. Silence
on these reads as "not found," not "found and intentionally skipped" — say so
explicitly. **Unconditional stop unless invoked with `apply`** — identical
discipline to step 5: zero conflicts, an obviously-clean plan, inferred
intent, or convenience do NOT authorize proceeding. A bare `untangle` is a
dry-run, every time, no exceptions. **This includes conflict adjudication
given in conversation** — if the operator resolves the one conflict, or asks
for a specific fix, while reviewing this report, record their answer in the
plan for the `apply` run to act on; do NOT edit any file now (see step 5's
"Adjudication is not authorization to write" — the same rule, no exception for
untangle).

**6. Isolate branch.** Reused as-is (`git checkout -b
ai-dlc-update/untangle-<ts>` off the current branch).

**7u. Extract + mask-aware overwrite — reached ONLY when the invocation
carried `apply`.** The **flagged-block checkpoint** from step 7 applies here
unchanged: before executing any block's bucket action below, check
`needs_operator_confirmation` — if true, stop and get the operator's explicit
answer for that specific block before authoring anything for it, regardless
of bucket. This is not optional for untangle just because most blocks here
are mechanical — the two most consequential open items in graph's first
apply (a layer-`kind` naming decision, a genuine 3-way prose blend) were
exactly this shape. Per classify bucket, act:
- **rewording** → discard the consumer's version; core is restored to
  `theirs` at that block (rewording is by definition already-upstream in
  substance).
- **domain-local** → extract the block to `extensions/` with an explicit
  `push_candidate: false`, then restore core to `theirs` at that block. The
  flag is never omitted and never defaulted here: writing `false` is the
  positive claim that no core text at the entry's `hooks:` target — no gate, no
  breach message, no budget row, no cross-reference — depends on the machinery
  being kept local. Derive that claim against `theirs` before writing it; a
  flag written without asking is an unmade decision recorded as a made one. If
  core text DOES depend on it, core is incomplete without the block and the
  block is NOT domain-local: assign **un-pushed-innovation** and take the next
  bullet instead. `domain-local` carries no push route of its own, and that
  flag is the entire distinction between these two bullets. This decision is
  per-BLOCK, so it never reaches a consumer-only FILE (queued to the ledger
  below) or anything already sitting in `overrides/` — ask the same dependency
  question at those two sites, where no bucket is assigned to carry it.
- **un-pushed-innovation** → extract to `extensions/` with `push_candidate:
  true`, then restore core to `theirs`.
- **conflict** → extract to `overrides/` with `shadows: <file>#<id>` and
  `base_sha: <current stamp sha>`, then restore core to `theirs` (the override
  now shadows the core rule for this consumer; core itself stays
  byte-reconcilable with upstream).

Then apply the **mask/reinject transform** to every manifest-listed file as
part of its final overwrite. Files upstream has no equivalent for at all —
e.g. a consumer-only team-role file, or a whole consumer-only subdirectory
under the skill root — are left untouched entirely and queued to the
push-candidate ledger; core-overwrite by construction only ever touches paths
`theirs` actually has.

**The file-grain rows step 3 printed are acted on here too, and the bucket list
above never reaches them.** `ALREADY-AT-THEIRS` → write nothing.
`BOTH-CHANGED->CLASSIFY` → the per-block list above. `UPSTREAM-ONLY-ADD` →
write theirs' copy (path-mapped, through mask/reinject if manifest-listed) AND
set its exec bit from theirs. That bucket also holds a copy already carrying
base's bytes with the wrong bit, in either direction; for it the content write
changes nothing and the mode IS the action. Read the mode with `git -C <dist>
ls-tree <theirs> -- <path>`, where `<path>` is the row's second column exactly as step 3
printed it (it already begins with `core/`): `100755` → `chmod +x`, `100644` →
`chmod -x`, any other mode → leave the bit alone, and an EMPTY answer is a STOP, never a
no-op. The same rule binds every file this step
writes: a file the write creates takes the umask's mode, not theirs'.

**7v. Runtime-verification gate — hard, unconditional, blocks delivery on any
failure.** Byte-equality is not sufficient evidence the migration worked (this
is exactly what the reverted attempt got wrong). Before delivery:
1. For every `overrides/*` entry, resolve its `shadows: <file>#<id>` against
   the just-overwritten core file — FAIL on a dangling shadow (id not found).
2. For every `extensions/*` entry, confirm its `hooks:` target file exists in
   core. **Resolve the `hooks:` path via the core→consumer path mapping (the
   same one `preclassify.sh` uses), NOT skill-relative:** a `steps/<x>.md` or
   bare `SKILL.md` hook lives under the skill dir
   (`.claude/skills/ai-dlc/…`), but a `team-roles/<role>.md` hook (used by
   `roles/*` extensions) lives at `.claude/team-roles/<role>.md` — OUTSIDE
   the skill dir. A naive skill-relative join (`.claude/skills/ai-dlc/team-roles/…`)
   would falsely report every role extension's target MISSING. `hooks:` values
   mirror the `core/`-relative path convention (`team-roles/x`, `steps/x`,
   `SKILL.md`); map each the same way core files map to consumer files.
3. Render 2–3 sample overrides and extensions to show what Rule 27's
   precedence (`overrides > extensions > core`) would actually produce at
   load time — proof the shadow/addition takes effect, not just that the id
   string matches somewhere.
4. Confirm zero remaining `{...}` template tokens in any team-role file; that
   every role file has an `aiDlcRoles` entry in `.claude/settings.json`, that
   each entry's `model` resolves in `aiDlcModels`, and that each `effort` is one
   of `low`/`medium`/`high`/`xhigh`/`max`. The dispatch guard fails open on any
   of those, so a role would dispatch with nothing bound — silently. This is the
   concrete proof teammate dispatch will not break, the exact failure the
   reverted attempt caused.
5. **Run `reconcile/setup-site-drift.sh <dist> <consumer> <theirs>`; exit 0
   required** — observed, not inferred: run it unpiped with its output sent to a file and
   `rc=$?` on the very next statement, then read the whole file (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB, never `ctx_*`). Do not run
   `reconcile/post-write-gates.sh` here: that is the ordinary pull's step 7 runner, and its
   `hard-blockers --post-apply` gate needs the pull's base, which untangle does not have. A run
   whose exit code was not observed is UNDECIDED and fails this criterion. It diffs every file declaring a setup site against `theirs` over
   the WHOLE file and confirms every differing line falls INSIDE a span declared
   for that file in `reconcile/setup-sites.md` (a single-line site's matched
   line, or a heading-block site's span). A difference at ANY line outside a
   declared span — a dropped `<!-- {token} -->` config comment, a removed blank
   line, reordered prose — is a FAIL, even if the setup values themselves
   reinjected correctly: it means the overwrite kept `ours`'s structure instead
   of `theirs`'s and core is no longer byte-reconcilable.

   **This criterion was prose, and the prose was not enough.** A
   real run checked only the value lines and declared pass: `dev.md` lost three
   of theirs' model-option HTML comment lines and this criterion still reported
   PASS. Asking the agent that just performed the transform whether the transform
   was correct is not a check. The script is now the criterion, it also runs on
   the ORDINARY pull (step 7's post-write gate, where nothing equivalent existed
   at all), and a site it cannot locate FAILS rather than being skipped.

Any failure here STOPS the run before delivery — the branch holds the
in-progress state for inspection/fix, nothing is delivered. This gate is not
optional and not skippable by any of the same rationalizations forbidden at
step 5 (clean-looking result, zero conflicts, etc.).

**8, 9. Deliver, safety.** Reused as-is: branch → commit → push → PR →
operator-approved merge (PR body = the migration plan summary + the 7v gate
results); the same three recover layers (branch, `_divergence/` archive,
dry-run report — here, `untangle-plan.md`).

After the merge, step 8's RETURN PROCEDURE returns the checkout from
`ai-dlc-update/untangle-<ts>` to the working branch, exactly as on an ordinary pull.
