# Self-update: the slice derivation and the push refusals

Read on demand from `SKILL.md` step 2: read it in consecutive bounded native Read chunks (offset+limit) of at most 16 KB, never `ctx_*`, and re-read it on need after a compaction. "Step N" means SKILL.md step N.

## The slice derivation

   **That declaration does NOT extend to the rest of the machinery set, and reading it as
   if it did is how this step overwrites a consumer edit.** Machinery is upstream-OWNED —
   a statement about who decides its content, not a claim that no consumer has ever edited
   its copy. The reference consumer edited its `.githooks/pre-push`, a `machinery:` entry,
   and this cycle would otherwise have written `theirs` over it autonomously and
   auto-merged the result. The second subtraction below is what disposes of that state,
   and `reconcile/self-update-gate.sh` names every such path in its output. Where the
   two sentences here and at "only the paths that diff names" below appear to conflict,
   the subtraction is the resolution: a consumer-modified machinery path is never written
   by this cycle.

   Diff `base→theirs` restricted to **the MACHINERY set** — read
   `reconcile/setup-sites.md`'s `machinery:` list (the manifest, `git-hooks/pre-push`,
   hooks, `scripts/ai-dlc/*`, schemas, session-driver, templates, and the `ai-dlc-setup` /
   `ai-dlc-update` subtrees) — **plus the fixtures that cover THE CHANGED PATHS**: every
   `core/fixtures/<dir>/` whose `*.sh` names one of the machinery paths **this diff actually
   touched**, EXCLUDING — read AT `theirs` — any dir carrying a `.dist-only` marker (never
   shipped, so it cannot run on a consumer) and any dir **upstream does not ship at `theirs`**
   (nothing to write; a dir upstream ships with no `run.sh`, such as the shared `lib/` or a
   seed-only dir, is written whole). Derive both sets rather than enumerating either here, and grep
   `seed.sh` as well as `run.sh` (a fixture commonly resolves the tooling path in its seed,
   so a run.sh-only derivation misses it).

   **BOTH exclusions bind BOTH terms, not only the first.** The
   enforcer applies them to every fixture directory the self-update commit writes, so a dir
   reaching this term through the grep — legitimately, because the grep reads `seed.sh` and a dir
   may carry a `seed.sh` and no `run.sh` — and written here is refused at the push when it
   carries `.dist-only` or does not exist at `theirs`, when it has a `run.sh` at `theirs`
   that the write omits, or when its state at `theirs` cannot be read (UNCONFIRMED).

   **The fixture term has a SECOND half, and the first cannot see it: every
   `core/fixtures/<dir>/` THE DIFF ITSELF TOUCHES.** The grep above runs over the fixtures
   and keys on machinery that MOVED, so a fixture the pull REPAIRS — one whose only change
   is its own `run.sh` or `seed.sh` — names no moved machinery path and is outside the slice
   by construction. The consumer's pre-push runs the WHOLE suite, not the slice, so its
   unrepaired copy stays red and blocks the very push this cycle is making. Measured over 69
   release-to-release ranges of the distribution: **16 carry at least one SHIPPING fixture in
   exactly that state**. Two exclusions, both read AT `theirs`, and both stated as the
   ENFORCER spells them rather than as a paraphrase: a dir carrying `.dist-only` never ships,
   and a dir **upstream does not ship at `theirs`** has nothing to write. A dir upstream ships
   with no `run.sh` (a support dir: the shared `lib/`, seed-only dirs) is written whole like any
   other covered path and is not refused; a dir with a `run.sh` at `theirs` is written with it.
   That second exclusion is not "a dir the diff deletes" — deriving this term by hand from the
   looser wording yields a slice the push then refuses. **Subtract every path `preclassify.sh` buckets `DIST-ONLY-SKIP` from the write set,
   and write each fixture directory WHOLE, its `run.sh` included.** The gate-record checker the
   push runs (`reconcile/self-update-fixtures.sh`, called by `reconcile/self-update-push.sh`)
   refuses a self-update commit that wrote a fixture directory carrying `.dist-only` at `theirs`,
   a dir upstream does not ship at `theirs`, a dir whose `run.sh` at `theirs` the commit omits,
   or a dir whose state at `theirs` cannot be read (UNCONFIRMED), before any hook runs and before
   anything is pushed. That refusal exists
   because a hand derivation on the reference consumer named `backlog-size-ceiling`, which carries
   `.dist-only`, and wrote it into that consumer's `tests/fixtures/` as a RETIRED-FIXTURE-ORPHAN.

   **Against the CHANGED paths, not the whole machinery list — the difference is two orders
   of magnitude.** `machinery:` carries `core/scripts/ai-dlc/*`, which the substitution below
   turns into *every distribution script*; and a fixture's whole job is to invoke a validator,
   so naming a `core/scripts/…` path is the norm. Measured at 0.168.1: **45 of 66** shippable
   fixtures name one, so a whole-list reading demands 45 fixture runs to gate a one-script
   change and is indistinguishable from "run the entire suite." The changed-paths reading
   yields the one covering fixture, which is what the step means and what makes the write
   instruction below — "the covering fixtures, never the derived set per directory" — a
   distinction the reader can act on rather than a contradiction.

   **One entry is CONSUMER-shaped; translate it and match dist-to-dist.** `machinery:`
   entries carry a `core/` prefix and are otherwise consumer-shaped, which matters for
   exactly one of them: `core/scripts/ai-dlc/*` is where a validator LANDS, while upstream
   it is `core/scripts/<name>`. Testing a `git diff` path against that entry directly
   matches `scripts/` not at all and silently yields an EMPTY slice. Every other machinery
   entry is already a valid distribution glob (verified: only that one resolves to zero
   files under `git ls-files`). So substitute `core/scripts/ai-dlc/` → `core/scripts/`
   and match the diff paths against the result.

   Do NOT reach for `to_consumer_glob()` here. It lives in `core/scripts/core-paths.sh`
   and `core/hooks/ai-dlc-core-guard.sh` — outside `reconcile/`, so this skill's HARD
   CONSTRAINT forbids reading it, and an earlier draft of this step sent the reader there
   anyway. The one substitution above needs no helper.

   **The whole machinery set moves together, not just this skill.** Machinery is exactly
   the core with no layer grain — no `overrides/` shadow, no `extensions/` entry, nothing
   for an operator to adjudicate — which is the same property that makes this cycle
   autonomous in the first place. `validate-enforcement-map.sh` I28 asserts the
   `machinery:`/`rulebook:` lists partition the manifest, so the set cannot silently
   narrow. The rulebook stays operator-gated at step 8.

   **The tooling and the fixtures that guard it move together or the suite goes red on a
   pull that broke nothing.** Pulling `reconcile/*` alone leaves the consumer running new
   tooling against fixtures written for the old, and the suite fails on a fixture correctly
   reporting that its subject changed underneath it — not a regression, not consumer-caused,
   and it blocks the run before the reconcile that would have shipped the matching fixture.
   A self-update that carries a validator without the fixture asserting its behaviour
   strands the fixture against code it no longer describes.

   **Restricting the slice to this skill was itself that bug.** A fixture covering
   `ai-dlc-update` can depend on machinery elsewhere, and two of them do: `check-15-bypass`
   resolves `scripts/ai-dlc/core-paths.sh` and `core-manifest.md`, `core-write-guard`
   resolves the core guard hook. Pulling only `skills/ai-dlc-update/**` left both asserting
   against machinery this cycle did not carry, and a red derived fixture DEFERS the
   cycle — so the self-update wedged on a pull that broke nothing. The machinery set is the
   smallest slice that closes that ~~, because a fixture's subject is always machinery~~.

   **CORRECTED — "a fixture's subject is always machinery" is FALSE, and widening the slice
   cannot fix it, because the only thing left to widen into is the rulebook this step
   deliberately excludes.** Measured on the reference consumer pulling 0.249.0 → 0.261.0:
   **7 of that tree's 109 fixtures are red in the state this step constructs**, and the
   operator had to cut a branch, write the 17-path slice and run 43 derived fixtures to
   find out. Three distinct couplings, all real:

   - **`enforcement-map.yaml` is machinery; its `CHECK_LOADED` anchors are rulebook.** A
     release that adds a check makes the incoming map reference an anchor that does not
     exist in the consumer's `steps/gate-validation.md` yet, so `validate-enforcement-map.sh`
     fails on the consumer's own tree and every fixture driving it goes red. Measured:
     checks 33, 34 and 35.
   - **Some fixtures assert on rulebook directly.** `postcompact-rulebook-recovery` runs
     `validate-reattach-budget.sh` against the SHIPPED `SKILL.md` and mutates its mandate.
     Its subject is rulebook, so it cannot be green while machinery is at theirs and
     rulebook at ours — whatever the slice contains.
   - **A fixture file the pull deletes stays in the consumer's tree.** This step never
     deletes, so the slice ships a deleted fixture file's new siblings beside the stale copy,
     and a sibling that enumerates its own directory runs or asserts on the file upstream
     removed. Only the step-7 gated apply performs the deletion (`UPSTREAM-DELETED`). The
     gate's `deletion-coupled-fixtures` row names each deleted `core/fixtures/` path the
     consumer still holds at its `tests/fixtures/` mapping; a deleted path the consumer
     already lacks is quiet.

   **So the deferral is structural, not exceptional**, and for any pull spanning a
   check-adding release it is the expected outcome. `reconcile/self-update-gate.sh` now
   detects all three couplings BEFORE the branch is cut and returns `SELF-UPDATE-DEFER`, so the
   slice folds into the gated apply without the branch/write/run/revert cycle. Its two
   rulebook arms fire only when the rulebook is ALSO about to change (verified against 0.256.0
   → 0.257.0, which touches no rulebook file), and its deletion arm only when the pull deletes
   a fixture file the consumer still holds: a machinery-only pull that deletes no held fixture
   file still proceeds autonomously.

   **EMPTY is a CONTENT question, not a diff question — or this step never terminates.**
   The slice is `git diff base→theirs`, and `base` is the stamp's `commit`, which advances
   only under a gated `apply` at step 7. So once a self-update has written every machinery
   path, the diff STILL lists them on the next bare invocation: the cycle re-runs, re-invokes,
   and re-runs again. Measured on the reference consumer after both its self-update PRs
   merged — the diff still yielded every machinery path while a per-path content check
   reported all of them already at `theirs`.

## The gate record and the push refusals

   The gate's verdict is a DIFFERENTIAL — the incoming script and the consumer's current one, run
   under identical conditions — so a script that merely fails to resolve from a temp path cannot
   masquerade as a new finding and strand the slice for no reason.

   **A push failure that predates the pull is NOT a differential, and the gate does not judge it.**
   It sits outside every incoming-versus-current comparison by construction, so it is answered at
   the push, by `reconcile/self-update-push.sh`, which runs the consumer's pre-push hook EXACTLY
   ONCE per self-update: the hook git would run (resolved by `git rev-parse --git-path
   hooks/pre-push`, so `core.hooksPath` and a `.git/hooks/` shim both count, and a hook git would
   skip is skipped), on the WRITTEN tree, with the hook the slice may just have replaced, fed the
   ref line the push sends. That is the push's own run of the hook, not a rehearsal of it: the
   wrapper pushes with `--no-verify` only after that run exited 0. A non-zero run is
   `HOOK-REFUSED` (exit 3) with nothing pushed, and the push paragraph below discards the branch
   and DEFERs. The gate never runs the hook; its only `pre-push` rows are UNDECIDED — a consumer
   that is a subdirectory of an enclosing repository (the push would run that repository's hook),
   or a range whose hook change could not be read. **The one hook run is the consumer's whole
   pre-push and can take minutes; it is the run the push would have made anyway.**

   **The push REFUSES without that record.** `reconcile/self-update-push.sh` runs the gate-record
   checker `reconcile/self-update-fixtures.sh` (the name is historical; it runs no fixture) before
   the consumer's pre-push hook. The checker looks for a recorded `# verdict: OK` whose range
   matches its own — compared as RESOLVED COMMITS, so a tag and the sha it names are the same
   range — and exits 2 with a `GATE-RECORD:` line naming the exact gate command when there is
   none; the wrapper then exits 2 with `GATE-RECORD-REFUSED`, runs no hook and pushes nothing.
   That is what makes the gate's verdict load-bearing rather than advisory: a classifier printing
   to stdout can refuse nothing, and the program this step must call to push is the one that can.

   **The record also binds the CONSUMER TREE its verdict was taken against, not just the range.**
   The verdict is a differential against the consumer's own copies, so the same command over one
   range answers differently once this cycle has written the slice — the record therefore names
   every consumer file the verdict read, with its digest and the core path it maps from, and the
   checker re-reads each one.

   **A script a PRIOR self-update landed is not pre-written.** The gate identifies it by the
   stamp's `skill_commit` and the consumer's committed copy, and reports it as `SELF-UPDATE-OK …
   landed by the prior self-update`. A script that is already at theirs but that the hook only
   mentions and never runs reads `not gating`. In both cases the slice still subtracts the script
   as ALREADY-AT-THEIRS and does not write it.

   **One tolerance, and it exists because a fix to a bootstrapping step cannot be delivered by that
   step.** On the pull that delivers the recording gate the OLD gate runs and records nothing, so
   the checker proceeds with a `NOT-REQUIRED` line when no record exists AND the gate at `base` —
   the engine the consumer installed — carries no record-writing site. Where that gate does record,
   an empty record directory is a refusal: the records were deleted or the gate was never run.

## The carried pair

     **The pair advances even on a cycle that CARRIED a path, and that is what the gate's
     `GATE_CARRY_STATE` refusal compensates for.** A carried path is the one thing this cycle
     did not write, so the advanced `skill_commit` then attests machinery that did not
     land; nothing here corrects it, because the correction would need per-path granularity
     the stamp has no field for. `machinery_at_or_past()` in
     `reconcile/self-update-gate.sh` therefore refuses on the carry row instead of on the
     stamp, so the SAFE-STOP acquittal is withheld on the runs where the stamp is ahead of
     the tree. Do NOT hand-hold the stamp back — the carry row already reaches the operator
     and step 7's gated apply is what closes it.

## Citations in this step

     **CITED BY TOKEN AND NOT BY LINE NUMBER, DELIBERATELY.** A consumer runs whatever version it
     last installed, so a line number written into shipped prose resolves against a DIFFERENT file
     on every tree that is not at this exact release — it does not fail, it silently lands on
     unrelated text. Caught by the reference consumer against a citation in this very passage.
     Cite something greppable.

     **THE FIRST COUNT OF HOW MANY OTHERS EXIST WAS WRONG, BY A GRAMMAR THAT COULD NOT SPELL ITS
     OWN SUBJECT.** It matched the path-plus-number form and not the bare colon-number form this
     passage had used, so it scored this very citation as a non-instance and reported it as the
     only one. Re-run over both forms, with a seeded positive control and a negative control, FOUR
     remain across shipped core prose. Point a search grammar at its own subject before believing
     its number, and re-run the scan rather than taking this paragraph as the corpus. Note also
     that writing either form here as an EXAMPLE would make this passage an instance of its own
     subject, which is why neither is spelled out.
