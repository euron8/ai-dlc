# Detector rows and their dispositions

Read on demand from `SKILL.md` steps 3 and 7: read it in consecutive bounded native Read chunks (offset+limit) of at most 16 KB, never `ctx_*`, and re-read it on need after a compaction. `reconcile/pull.sh` runs every
detector named here once per invocation and prints the rows; this file says what each row means
and what you do with it. A decision this file leaves to you is recorded in
`_bmad-output/ai-dlc-update/pull-decisions.tsv` (SKILL.md, "The driver"), never asked, unless its
family is in `reconcile/ask-families.tsv`. "Step N" means SKILL.md step N.

## Steps 3-3ea: the detectors

3. **Mechanical pre-classification** (cheap, deterministic — no agents):
   run `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   **Exit 2 is a refusal, not a result.** When a git call it depends on fails, it exits 2 and
   prints one stderr line naming that call. Any rows it printed before stopping are partial and
   must not be read as buckets. Fix what the line names and re-run.
   It hashes base/theirs/ours per changed file and buckets each into:
   - `UPSTREAM-ONLY-ADD` (net-new upstream, consumer lacks it) → **apply (pure)**
   - `UPSTREAM-ONLY` (upstream changed, consumer untouched vs base) → **apply**
   - `ALREADY-AT-THEIRS` / `ALREADY-PRESENT` → **noop**
   - `UPSTREAM-DELETED` (upstream removed it, consumer untouched vs base) →
     **delete the consumer file (gated — destructive, see step 7)**
   - `UPSTREAM-DELETED-NOOP` (upstream removed it, consumer already lacks it) → **noop**
   - `PRE-RELOCATION-NOOP` (a changed `core/scripts/*` path on a consumer still holding
     it at the pre-relocation `scripts/<name>`; the relocation pass owns that copy) → **noop**
   - `CONSUMER-MISSING-NOOP` (the consumer opted out of this destination — today only
     `.github/workflows/`, which `install.sh` has always written *only* if the directory
     already exists) → **noop**. Updating a workflow a consumer HAS is a fix; creating
     CI on a consumer that has none is a change nobody asked the pull to make.
   - `ORPHANED-RELOCATED` (status `O`) — a file at a consumer path an earlier release of
     this distribution wrote and the current one no longer targets, whose content still hash-matches the blob
     we shipped, so it is provably our copy → **delete the consumer file (gated —
     destructive, see step 7)**. When a core subtree's destination changes, the copies
     already written to the old path do not move and do not vanish; every later pull
     refreshes only the new path, so the orphan silently diverges from the file it is a
     copy of. Retiring it is the pull's job — a migration note in a CHANGELOG is how it
     never gets done. Emitted **level-triggered**: an orphan is a *state* of the consumer
     tree, not an event in the upstream diff, so a pull that touches no file in the moved
     subtree must still report it.
   - `ORPHANED-UNKNOWN` / `ORPHANED-RELOCATED+consumer-modified` → **needs semantic
     classify, never auto-deleted.** The orphan is either something upstream never
     shipped or something the consumer edited. The pull only ever proposes destroying a
     file whose bytes it can prove it wrote.
   - `BOTH-CHANGED` / `BOTH-ADDED` / `UPSTREAM-MOD+consumer-deleted` /
     `UPSTREAM-DELETED+consumer-modified` → **needs semantic classify**
3a-ii. **Retired contract tokens** (cheap, deterministic — no agents):
   run `reconcile/retired-tokens.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   Every `CLASSIFY` file's semantic merge MUST clear this before it counts as done.
   It names the one merge defect no other detector here can see: upstream retired a
   shared contract (a channel, a scratch path, a state file) and the consumer's own
   code — inside the same upstream-maintained file — still speaks the old one. That
   merges cleanly, parses cleanly, and yields a gate that cannot fire. It happened:
   on the 0.114.0 → 0.118.2 pull a consumer's pool block kept writing to a retired
   temp path and its budget gate reported PASS at **1212% of budget, exit 0**. Nothing
   flagged it; a person found it by hand-building a functional test.
   **A non-empty result means the merge is NOT complete.** Re-point the consumer's
   reference at whatever THEIRS replaced it with, then re-run until the output is
   empty — or record in the report why a survivor is safe. `apply.sh` carries the
   token list on the worklist item itself, so the obligation arrives with the work.
   Note what it does NOT catch: a consumer path upstream never had (there is no
   retirement to detect). A clean result is not proof the merge is semantically whole.
   **Read its stderr, not only its rows.** A pull that lists no `CLASSIFY` file (every
   path already at theirs, or untouched by the consumer) opens nothing, and its zero
   rows are byte-identical to a full scan that matched nothing; the NOTE it prints in
   that state, the `M of N … opened` denominator it prints when it opened files and
   matched nothing, and the refusal it prints when `preclassify.sh` listed nothing at
   all are the difference between a scan that found nothing and a scan that never ran.
3a-iii. **Retired contract shapes in consumer layer files** (cheap, deterministic
   — no agents): run `reconcile/retired-layer-contract.sh <dist-repo> <base-sha>
   <theirs-ref> <consumer-root>`. `retired-tokens.sh` above scans only `CLASSIFY`
   core files, so `overrides/` and `extensions/` are outside every bucket and no
   detector opens them. A layer file that shadows, quotes, or restates a core
   construct upstream retired therefore survives the pull unreported, and the layer
   is what the teammate reads.
   Output is `RETIRED-LAYER-CONTRACT<TAB><layer-path><TAB><shape>`. Each row is a
   layer file to re-read against `theirs`: either re-point it at the replacement
   construct, or record in the report why the stale reference is harmless.
   **Read its stderr, not only its rows.** When the release retired no shape it opens
   no layer file at all, and says so; that NOTE is the difference between a scan that
   found nothing and a scan that never ran.
3a-iv. **Retired core PASSAGES still carried by a layer file** (cheap, deterministic
   — no agents): run `reconcile/retired-layer-passage.sh <dist-repo> <base-sha>
   <theirs-ref> <consumer-root>`. 3a-iii matches retired contract SHAPES — labelled
   directives and `{token}` placeholders — and cannot see a layer file that reproduces
   a retired core directive as ordinary prose. This one asks the complementary question:
   does a layer file still contain a LINE core carried at base and deleted by theirs?
   Output is `RETIRED-LAYER-PASSAGE<TAB><layer-path>:<line><TAB><deleted core line>`.
   Each row is a passage the layer reproduces and core no longer has — **RE-POINT it at
   the wording core carries now.** Do not delete it. This detector's input is one path
   glob's removed-line set, so it cannot tell a MOVE from a retirement, and on a release
   that re-sites text every row cites wording core still carries somewhere else.
   Its limit, and read its stderr for the same reason: it matches reproductions, not
   paraphrases. Reword any clause and the line stops matching.
   **This does NOT block the apply** — a layer file is consumer-owned and the pull
   does not rewrite it.
   **Step 7's apply emits a `WORKLIST retired-layer-passage` row for this same class**,
   from its own run of this detector, so the work is tracked there whether or not you
   run the scan here. Running it now is the earlier look, not a second finding; the row
   is what the re-stamp waits on. The row's own detail is authoritative about the remedy
   — work the row, not this paragraph.
   Note what it does NOT catch: a shape the consumer invented that core never had,
   and a layer file that paraphrases a retired construct without using its literal
   shape. A clean result is not proof every layer file survived the release.
3a-v. **Core fixtures the consumer still carries after core stopped shipping them**
   (cheap, deterministic — no agents): run
   `reconcile/retired-fixtures.sh <dist-repo> <theirs-ref> <consumer-root>`.
   `install.sh` and `apply.sh` copy a core fixture into the consumer; when core later
   marks it `.dist-only` or deletes it, both stop copying it — correctly — and the copy
   already installed becomes unreachable by every mechanism core has. It is not drift
   (nobody edited it) and not a missing file (the consumer has one), so no bucket claims
   it, and it freezes at whatever core last shipped.
   Output is `RETIRED-FIXTURE-ORPHAN<TAB><consumer-path><TAB><remedy>`.
   **This does NOT block the apply**, and core does not remove the directory — the file
   is the consumer's. Each row is a model decision, recorded as a decisions row: a `rm -rf`,
   or a rename if the consumer has adopted the fixture as its own.
   Two rows are NOT orphans and mean the scan was incomplete: `HARD-RETIRED-FIXTURE-
   SCAN-UNAVAILABLE` (the path mapper could not be loaded — nothing was scanned) and
   `RETIRED-FIXTURE-HISTORY-UNAVAILABLE` (a shallow clone, so a fixture core DELETED
   cannot be told from one the consumer wrote; the `.dist-only` half is unaffected).
   Note what it does NOT catch: a core fixture the consumer RENAMED, which by design
   reads as the consumer's own.
3a-vi. **Retired status tokens reused in a layer file's own prose** (cheap, deterministic
   — no agents): run `reconcile/retired-layer-token.sh <dist-repo> <base-sha>
   <theirs-ref> <consumer-root>`. 3a-iii matches contract SHAPES and 3a-iv matches whole
   deleted core LINES; a consumer sentence that merely REUSES a status word core renamed
   is neither, and both print their clean NOTE over it. It happened: on the
   0.373.0 → 0.378.0 pull `VACUOUS` became `EXAMINED NOTHING`, an override's rendered
   body still read `stock exits 78 VACUOUS`, and every mechanical signal was clean — a
   person found it by grepping the body.
   The retired set is derived, never listed: every ALL-CAPS word of four or more
   characters that the core rulebook carried at base and carries nowhere at theirs, kept
   when it is JOINED (`-` or `_`, the shape emphasis never has) or when some core program
   printed it at base and stopped in that same file at theirs — a plain word with neither
   witness is read as emphasis and the NOTE names it. Output is
   `RETIRED-LAYER-TOKEN<TAB><layer-path>:<line><TAB><token>`.
   Each row is a sentence to re-read against `theirs`: re-point it at the replacement
   token, or record in the report why the old word is still correct there. A row inside
   a layer file's frontmatter `reason:` is usually a stale grep control and is owed the
   same re-read.
   **Read its stderr, not only its rows.** When the release retired no token it opens no
   layer file at all and says so; a scanned-but-no-match run prints both counts; an
   unreadable rulebook at either ref is a refusal with exit 2, never a clean line — an
   unresolvable theirs would otherwise retire every token — and the report renders that
   section as `DETECTOR-REFUSED`, which must not be approved.
   **This does NOT block the apply** — a layer file is consumer-owned. It is a worklist
   item, owed before the pull counts as done.
   Note what it does NOT catch: a token the consumer invented that core never had, a
   word core still carries anywhere in its rulebook at theirs, a plain word no core
   program ever printed, a vocabulary whose owner sits outside the rulebook (a
   `layer-contract.yaml` clause code, a ledger status) unless the rulebook also spells
   it, a space-separated status whose other word survived (matched one word at a time),
   a hyphen chain the layer carries only a prefix or one segment of (a chain is one token,
   retired whole), and a paraphrase that drops the literal word. A clean result is not
   proof every layer file survived the release.

3b. **Template pre-classification** (the generated files outside `core/`):
   `reconcile/emit-report.sh` runs `reconcile/preclassify.sh <dist-repo>
   <base-sha> <theirs-ref> <consumer-root> --templates` for you and renders
   its rows into the step-5 region's **Template pre-classification** section.
   You do not run it and you do not narrate its rows; run it by hand only to
   investigate a `DETECTOR-REFUSED` line. The `core/` reconcile above never sees
   `CLAUDE.md`, `docs/coding-conventions.md`, `QUICKSTART.md`, or
   `.claude/settings.json` — they are generated from `templates/*.template`
   and filled with consumer config, so an upstream edit to the template
   boilerplate (a removed section, a reworded rule) would otherwise never
   reach a consumer. This pass buckets each per `reconcile/template-sites.md`:
   - `TEMPLATE-UNCHANGED-NOOP` (upstream template boilerplate identical vs base) → **noop**
   - `CONSUMER-MISSING-NOOP` (consumer lacks the generated file) → **skip**
   - `TEMPLATE-PROSE-MERGE` (token-prose file, boilerplate changed) → **marker-anchored mask/reinject (step 7)**
   - `TEMPLATE-JSON-MERGE` (`settings.json`, changed) → **jq strip/merge (step 7)**
   Reconciling these is per `template-sites.md`'s transforms; the consumer's
   filled config is preserved, only upstream boilerplate is synced.
3c. **Layer-drift detection** (cheap, deterministic — no agents):
   run `reconcile/layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   This MECHANIZES the "Layered consumers" rule below. Do NOT
   hand-verify overrides with ad-hoc `git diff` calls: a hand check is what lets a
   consumer accumulate overrides
   whose `base_sha` pointed at its OWN repo — every diff would have died on
   `fatal: bad revision`, and two shipped upstream changes were discarded unseen.
   Statuses:
   - `HARD-OVERRIDE-BASE-CONSUMER-SHA` / `HARD-OVERRIDE-BASE-UNRESOLVABLE` →
     **blocks `apply`** (see step 7). The `base_sha` is unusable, so drift for
     that override is undecidable. Never skip it; never "assume unchanged."
     Resolution: operator re-stamps `base_sha` to the correct distribution sha.
   - `HARD-OVERRIDE-DRIFT-SECTION` → the shadowed section changed upstream, so the
     override is now shadowing **a rule that no longer exists**. **Blocks `apply`**
     (see step 7). Resolution is not freehand — run the re-adoption workflow:

         reconcile/readopt-override.sh <dist> <theirs> <consumer> <override>

     It prints the dossier (the core section's `base_sha..theirs` diff, the override's
     body, its stated `reason:`, and the superseded core lines still sitting in that
     body) and asks the one question that decides the outcome: **does upstream's change
     supersede the reason this override exists?** Three outcomes, all ending in a
     re-stamped `base_sha`: `--stamp retire` (upstream absorbed it), `--stamp readopt`
     (merge the new core text into the override, preserving the consumer's delta),
     `--stamp reaffirm --note "<why>"` (the override still stands).

     **`--merge` performs the re-adoption: run it ONLY as `reconcile/pull.sh merge <dist> <base>
     <consumer> <theirs> <override>`, never `readopt-override.sh --merge` directly, and do not
     hand-edit the body.** It is a
     three-way merge (base = core@`base_sha`, ours = the override body, theirs =
     core@`theirs`), so upstream's change lands and the consumer's delta survives. A
     conflict leaves markers and is the only case needing a human. A shadowed section that
     is a load-pointer stub at theirs is never merged: `pull.sh merge` exits 3 relaying
     `OVERRIDE-SHADOWS-POINTER-STUB` (below), and that row's remedy replaces the merge.

     **`--stamp readopt` is REFUSED while the body still carries core text `theirs`
     superseded, or while conflict markers remain.** Drift is computed
     `base_sha..theirs`, so a bare re-stamp makes the HARD status evaporate with nothing
     migrated — the lead reads the OVERRIDE, not core, and would go on obeying the rule
     the fix replaced. Doing nothing is not an available outcome.

     The full procedure — **you do the surgery, and the decision is recorded** — is the
     adjudication loop below. Do not hand the operator a blocker list.
     **Why this blocks, when a check-number collision does not.** A collision is
     cosmetic and consumer-fixable. This changes **the rules the lead obeys**: the
     lead reads the override, not core, so an un-adjudicated drift means the core fix
     landed on disk and the pipeline went on running the rule it replaced. That is
     not hypothetical: a core fix routinely targets a section some consumer shadows
     verbatim, and under an advisory status the fix is inert on exactly the pipelines
     it was written for.
   - `OVERRIDE-DRIFT-FILE` → the anchor is not a locatable heading AND the file
     changed, so the section cannot be *proven* safe. Surface for re-confirmation.
     Conservative on purpose — an unprovable section is never reported as OK.
   - `OVERRIDE-ANCHOR-UNRESOLVED` → upstream restructured the anchor away.
   - `OVERRIDE-DELEGATES-INTO-SHADOW` → the override's body names a construct
     defined INSIDE a section it shadows, so precedence deletes the delegation
     target along with the section. **Report-only, never blocking** — pointing the
     lead at core is sometimes deliberate. Every other status here asks whether
     UPSTREAM moved; this one is true or false today, independent of any pull, so a
     clean drift result says nothing about it. Record it and offer the three
     remedies: restate the construct in the override, narrow `shadows:` to the
     sub-headings actually rewritten, or delegate to something outside the span.
     Left alone, every future change to that construct silently fails to arrive.
   - `OVERRIDE-ASSERTS-SHADOW-SURVIVES` → the body states that the span it shadows
     is unchanged and still governs. The sibling of the above and the same mechanism:
     precedence replaces the WHOLE span, so that sentence is false about the entry's
     own effect. **Report-only.** Remedy: narrow `shadows:`, or restate the surviving
     text in the body.
   - `OVERRIDE-BODY-UNCLAIMED` → a section of the body that NO `shadows:` anchor
     claims. Both rows above ask whether the body describes its own effect truthfully;
     this asks whether the body is REACHED. The body is sliced per anchor, so a section
     no anchor names is applied by nothing — it renders nowhere while still reading as
     live consumer machinery. **Report-only.** It is reached by REMOVING an anchor and
     leaving the body, so it is the companion row to an `OVERRIDE-SUPERSEDED` narrowing:
     read them together before executing one. Remedy: restore the anchor, move the text
     under a section an anchor does claim, or delete it.
   - `OVERRIDE-LOOSE-ANCHOR` → a `shadows:` anchor resolves only by the REVERSE arm
     of the containment match, so it names something finer than a heading and quietly
     widens the shadow to the whole section. **Report-only.** The row names the exact
     heading to substitute. E7 errors on this at authoring time; that validator is
     consumer-run and skippable, and this pull is not.
   - `OVERRIDE-SHADOWS-POINTER-STUB` → a section the override shadows is, at theirs, a
     load-pointer stub: it carries the `READ AND FOLLOW rule-bodies/rule-N.md` sentence
     (`lib.sh` `rule_body_pointers`) naming another file as the rule's binding text. The entry
     replaces the pointer, not the rule, and the binding file carries none of its change.
     **Report-only** (LC-O17), and true or false at theirs, independent of any pull. While
     `shadows:` names the stub, `readopt-override.sh` refuses `--merge` and `--stamp
     readopt|reaffirm` on the entry (exit 1, nothing written), `--check` reads `BLOCKED` (exit 1),
     and `pull.sh merge` relays that refusal row and its remedy verbatim and exits 3 with no
     decision row; `--stamp retire` stays open. The same refusal fires on a body that says READ
     AND FOLLOW its own shadow target (`shadows:` naming `rule-bodies/rule-N.md`). The row and the
     refusal carry the remedy, verbatim: "run readopt-override.sh <dist> <theirs> <consumer>
     <override> --stamp retire, then file this override's rows upstream as a change to the
     intensity table of the stub that owns the rule (the SKILL.md stub, per distribution
     invariants I19 and I131; rule-bodies/rule-N.md holds a copy)." Re-pointing `shadows:` at the rule-body file is not a remedy.
   - `OVERRIDE-DOUBLE-SHADOW` → two entries declare the same (file, anchor). Each is
     well-formed alone; precedence picks one body silently, and every commit touching
     the span invalidates BOTH stamps, so reconciling one looks complete.
     **Report-only** — a deliberate split is allowed, but it has to be stated in the
     bodies. Filed under EVERY participating entry, not just the first.
   - `EXTENSION-RETIRE-CANDIDATE` → upstream **absorbed** a section this extension
     defines: the titles agree (never merely the number — consumer gate-check numbers
     are a sanctioned separate namespace) and core did not carry it at `base`. The
     match is number-agnostic, so it fires even when upstream absorbed the check under
     a *different* number. Per Rule 27(b) the consumer MUST retire the entry; list it
     in the report's retirement list. Without this signal every successful absorption
     leaves a duplicate behind.
   - `EXTENSION-RESTATES-CORE` → the same title agreement, but core already carried
     the section **at `base`**. The consumer has been duplicating a core section for
     some number of releases without being told. The retirement signal is
     level-triggered: it fires on every pull while the duplication stands, not only on
     the pull that landed the absorption. Rule 27(c) forbids restating core (the copy
     cannot drift-check against the original, so it forks silently and then contradicts
     it). List it in the retirement list too, but the remedy is a judgement: retire it
     if it merely duplicates core; refile it in `overrides/` with a `base_sha` if it
     hardens or restricts core.
   - `EXTENSION-CHECK-NUMBER-COLLISION` → core defines this extension's check *number*
     with a **different title**. Extensions are additive, so the two catalogs render
     into one merged list under one integer and the bare `Check N` the lead commits to
     the gate log stops having a referent. The exact complement of the absorption
     signal. Tagged `NEW-THIS-PULL` (this pull created it — route to the
     needs-confirmation list so the operator acknowledges it) or `PRE-EXISTING` (the
     migration worklist). **Report-only: it never blocks `apply`.** A collision is
     decidable and consumer-fixable, and a consumer must never be unable to take a
     security fix because its own catalog needs relabelling.
   - `EXTENSION-HOOK-DRIFT` → the hooked core file changed. Extensions have no
     section anchor (`hooks:` is file-grain), so this is the strongest statement
     available: re-read the entry against the new core text. Its clause is at
     `level: ADJUDICATED`, so the re-read must be RECORDED — see the two statuses below
     and step 7.
   - `HARD-LAYER-ADJUDICATION-MISSING` and `HARD-REGISTER-CONTRADICTION` → stated in SKILL.md
     step 3, the home of their layer clauses.
   - `EXTENSION-HOOK-MISSING`, `OVERRIDE-OK`, `EXTENSION-OK` → as named.
   - **Exit 2 with `layer-drift: REFUSED — a row could not be written to stdout after N row(s)
     were`** → the scan stopped at that write, and every entry after it went unscanned. The rows
     you have are NOT the result, and a missing `HARD-` row is not an absence. Re-run it with a
     writable stdout. `apply.sh` renders this exit as `DECISION layer-drift-refused`.
   - **Exit 1 with `layer-drift: REFUSED — <input> could not be staged`** → an input the scan
     reads (the layer contract, a core file an override shadows, a producer's output) could not
     be written to its staging file or did not run, so reading on would have treated it as EMPTY
     and reported the layer cleaner than it is. **Exit 1 with `layer-drift: REFUSED — … carries N
     clause(s) at level ADJUDICATED and the code set read out of it is EMPTY`** → the adjudication
     tier would have been switched off. Both usually mean `ulimit -f` or a full or read-only
     `$TMPDIR`; clear that and re-run. `--adjudicated-codes` refuses the same way, so its empty
     output is an answer only when it exits 0.
   - **Exit 1 with `layer-drift: REFUSED — <base|theirs> ref '<value>' does not resolve to a
     commit`** → the ref names nothing in the distribution clone: a typo, a ref it never fetched,
     or a consumer sha passed where a distribution one belongs. THEIRS is checked in all three
     modes and BASE in classify and list mode, before anything is read. Fetch the ref or correct
     it, and re-run. **Exit 1 with `layer-drift: REFUSED — <path> at <ref> could not be
     read`** → an object the scan needs is missing from the distribution clone's
     object store, and reading on would have treated a present file as an absent one. Repair the
     clone (re-fetch, or re-clone) and re-run. A path genuinely ABSENT at theirs, which the
     tree does not name, is not a refusal, and neither is a `hooks:` or `shadows:` path spelled
     other than the tree spells it (`steps/./x.md`): that is the advisory absent row. Exit 2 with a `usage:` line, or exit 1 with any other
     reason, is a refusal to start. Any other run exits 0, whatever it found.

3d. **Unregistered core drift — the layer system's blind spot.** `layer-drift.sh`
   walks `overrides/` and `extensions/`. A core file edited **in place** appears in
   neither, so no entry describes it, no `base_sha` tracks it, and `apply` — which
   overwrites upstream-owned core — **deletes it without a word.** Run:

       reconcile/unregistered-drift.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref>

   **Pass `<theirs-ref>`.** Without it the absorption check cannot run, and a consumer
   whose hardening upstream just adopted keeps being told to refile a delta core already
   carries — forever.

   - `HARD-CORE-DRIFT-ABSORBED` → **upstream took this change.** Lines the consumer added
     (absent from core at `base`) are present in core at `theirs`. The remedy is a
     **revert**, not an override, and telling the operator to refile it would be actively
     wrong advice. It still **blocks**: a revert DELETES consumer text, so the operator
     confirms the upstream version covers their delta first. Show them the diff, then run
     the `git -C <dist> show …` command the status carries, substituting the consumer root
     for its literal `<consumer>` placeholder. This is the core-drift twin of
     `EXTENSION-RETIRE-CANDIDATE`. **Any read of the distribution at a ref is
     `git -C <dist> show "${ref}:core/…"`, naming the CORE path** (the Path mapping table
     above, read backwards), never the consumer's `scripts/ai-dlc/…`. In the consumer a bare
     `git show "${dist_sha}:…"` exits 128 because the consumer does not hold that commit, and
     behind `2>/dev/null` that failure is an empty read that every count scores as 0.

   - `HARD-CORE-BEHIND` → **this copy is STALE, not forked.** It best-matches a historical
     blob of that path which is a strict ancestor of `base` and older than it, so the file
     predates the consumer's own stamp and most of what reads as consumer drift is
     upstream's change since then. The remedy is **take theirs**. It still **blocks**,
     because the residual against that ancestor IS the consumer's: show them that diff —
     the status carries the command — and confirm nothing in it is still wanted before
     overwriting. **Do not adjudicate this row from the base-relative line count**; that
     number grows with staleness on its own. A file excluded from `apply` by a standing
     per-entry acceptance is the usual way one gets here, and the acceptance is then
     self-perpetuating: each pull it skips makes the next pull's diff larger and the
     "fork" reading more convincing.

   - `HARD-UNREGISTERED-CORE-DRIFT` → **blocks `apply`** (step 7). Undecidable by the
     tool (deliberate hardening → refile as an `overrides/` entry with a `base_sha`;
     accident → revert) and lossy if ignored. Same bar as the other `HARD-` statuses.
     Reached only after `HARD-CORE-BEHIND` has been ruled out, so the consumer's copy is
     anchored at `base` and the delta really is its own.
     **`reconcile/register-drift.sh <dist> <base> <consumer> <core-rel-path> --apply`
     does the refiling**: it authors the override from the consumer's own changed
     sections, anchors it to real headings, stamps `base_sha` at **base**, and reverts
     core. It leaves `reason:` as `TODO` — write one and record it as a decisions row.
     Hooks are refused by design (no override grain exists for them); say so plainly.
   - `CORE-TEMPLATE-SUBSTITUTED` → differs only where the distribution carries a
     `{token}` site. That is what `install.sh` does; it is not drift, and it must
     never be reported as such.
   - `CORE-OK` → byte-identical to the distribution at base.
   - `CORE-AT-THEIRS` → byte-identical to the distribution at `theirs`: already applied,
     never drift. A row here is the tell that the base passed in was stale.
   - `CORE-AT-SELF-UPDATE` → byte-identical to the distribution at `skill_commit`, the OTHER
     sha in this consumer's own stamp. **Not drift, and no action.** Step 2's autonomous
     self-update writes the `base→theirs` diff RESTRICTED to the MACHINERY set — not the whole
     set, and minus whatever arm C carried out of the slice — so on a multi-hop pull the files
     it did write sit at an INTERMEDIATE ref while `commit` — the base every predicate here
     measures against — stays where it was. **41 files are in both the machinery set and this
     scan** (control: 88 machinery files are outside it; both sides derived, neither
     hand-listed), and without this row each one reads as a consumer
     edit and draws a HARD status whose printed remedy is to revert upstream's own text.
     Reproduced at ground truth on the distribution's own history: the same file at the
     intermediate ref gives `HARD-CORE-DRIFT-ABSORBED`, and at base gives `CORE-OK`.
     The script reads `skill_commit` from the stamp ITSELF rather than taking it as an
     argument — a fifth argument is a fifth thing a caller can omit, and step 7 below records
     what that cost the last time one instruction had to be remembered for two scripts.
   - `CORE-MACHINERY-CARRIED` → a machinery path `reconcile/self-update-gate.sh`'s arm C
     CARRIED out of step 2's autonomous slice: the consumer diverged on it, so step 2 refused
     to write `theirs` over it and handed it to this gated apply. **Not drift, and the action
     is elsewhere** — `apply` already emits a `WORKLIST semantic-merge` row for the same path
     off the same preclassify bucket, which the row names verbatim. Do NOT refile it as an
     override and do NOT act on the drift remedy; do the worklist row. Without this row one
     path draws two contradictory instructions in one report, and for a hook there is no
     override grain to refile into at all. Non-blocking. It is the LAST specific status:
     `HARD-CORE-BEHIND` still wins (a stale copy has no residual to merge), and
     `HARD-CORE-DRIFT-ABSORBED` wins only when absorption is TOTAL — on a partially absorbed
     carried path that row's whole-file revert would delete the lines upstream did not take.
   - `HARD-DRIFT-SCAN-UNAVAILABLE` → **blocks `apply`**. The scan could not load its path
     mapper, so it scanned NOTHING and its empty output is not a clean tree. Restore
     `reconcile/preclassify.sh` beside `unregistered-drift.sh` and re-run.
   - **Exit 2 with `unregistered-drift: REFUSED — a row could not be written to stdout after N
     row(s) were`** → the scan stopped at that write, and every path after it went unscanned.
     The rows you have are NOT the result, and a
     missing HARD row is not an absence. Re-run it with a writable stdout. Any other run exits 0,
     whatever it found.

3e. **Consumer-catalog collisions.** Run `reconcile/relabel-extension-checks.sh
   <consumer-root> --dist <dist-repo> --theirs <theirs-ref>` (dry-run). Every extension
   check whose number core also defines needs the labelled form `### <n>. [ext:<id>]
   <title>`. **Pass `--dist`/`--theirs`** so the number set is the UNION of the installed
   core and the INCOMING core: a collision the pull *creates* (upstream adds `### 26.`
   while an extension already carries it) is invisible to a plain dry-run — the installed
   core does not carry the new number yet — so without theirs the tool reports "none"
   while the needs-confirmation list flags it, and the operator gets no relabel preview at
   the one moment they can decide it. An exit 2 with a `relabel: REFUSED —` line means an
   anchor set could not be staged for reading, and it is no verdict, not "none". **Report-only
   here; it never blocks `apply`** — a
   collision is decidable and consumer-fixable, and a consumer must never be unable to take
   a fix because its own catalog needs relabelling. The updater OFFERS the rewrite at step
   7. The integer never moves; only the label is added, so existing gate history maps by
   identity.

3ea. **Extension checks the incoming core makes newly-unloadable.** Run
   `reconcile/adopt-extension-checks.sh <consumer-root>` (dry-run). It lists, per
   `kind: check` extension entry, the check ids defined only as a HEADING — no
   `<!-- CHECK_LOADED: <id> -->` anchor, named by no manifest row — which is
   `validate-gate-manifest.sh`'s GM1 finding: neither MISSING nor an ORPHAN, so every
   gate passes without ever running them. **Report-only; it never blocks `apply`** — a
   consumer must never be unable to take a fix because the fix newly-fails its own
   content. The updater OFFERS the write at step 7.
   **The two writes are atomic and that is the reason a tool exists.** An anchor with no
   `gate_types:` is an ORPHAN (exit 1); a `gate_types:` with no anchor trips GM2 (exit 2).
   A hand edit doing one half trades one FAIL for another, so an operator working down a
   23-item list is red the whole way and cannot tell progress from regression.
   **`--apply` requires `--gate-types` and there is no default.** The anchor is derivable
   from the heading id; the gate slice is not. The only inferable default, `universal`,
   would promote every adopted check to run at every gate — unauthorised, and invisible
   afterwards because an over-broad slice passes vacuously. The dry-run prints the
   question once per ENTRY (`gate_types:` is entry frontmatter), which is why the
   reference consumer's 23 checks are 4 questions and not 23.


## Step 3g: predicate reclassification

3g. **Predicate reclassification — what this pull re-decides about artifacts nobody touched.**
   Run `reconcile/predicate-differential.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.

   Every other detector in `reconcile/` compares TEXT: core against core, or core against a
   consumer layer file. A release that moves an ADJUDICATION PREDICATE produces no text
   difference at all on the consumer's side — the stored artifacts do not change, and only the
   verdict the incoming script renders on them does. So every bucket reads clean while the
   consumer's own history quietly comes to mean something else. Measured on the reference
   consumer at `0.438.0 -> 0.443.0` and filed as
   `PC-S307-PULL-CANNOT-SEE-WHAT-A-PREDICATE-CHANGE-RECLASSIFIES`: 0.442.0 moved one ceiling
   constant and turned 33 of 105 stored adversarial series from pass to fail, three of them in a
   sprint that had been PAUSED, with the pull reporting 15 UPSTREAM-ONLY pure applies and zero
   conflicts. It was caught by hand.

   **IT COMPARES THE RANGE'S ENDPOINTS, AND THAT IS NOT THE SAME QUESTION AS "WHAT DID ANY
   RELEASE IN HERE DO".** A release inside the range that reclassifies and a later one that
   corrects it CANCEL. Measured on the reference consumer over one corpus of 119 series:
   `0.441.0 -> 0.442.0` moves 48, and `0.438.0 -> 0.443.0` — the real pull, spanning both the
   regression and its repair — moves 1. Both are correct. The endpoint answer is the one that
   matters for accepting a pull, because it describes the state you will be IN; if you need
   per-release visibility, walk the release commits the way `self-update-gate.sh --safe-stop`
   does. **Do not read a small count as the detector having missed something.**

   **A PREDICATE IS ITS READ-SET, NOT ITS SCRIPT.** `predicate-sites.md` declares `reads:` — the
   script AND every schema whose content decides a verdict — because a script-only comparison is
   vacuous for a predicate that resolves a schema at runtime.
   `core/scripts/validate-provenance-block.sh` says "THE SCHEMA IS NOT IN THIS FILE" in its own
   header, and `v0.382.0` changed `core/schemas/provenance-block.json` while leaving that script
   BYTE-IDENTICAL. A script differential returns 0 there by construction rather than by
   measurement, which is the failure this step exists to catch.

   The predicates in scope are declared in `reconcile/predicate-sites.md`; the script reads that
   manifest and nothing else. Statuses:
   - `PREDICATE-RECLASSIFIES` → the incoming predicate renders a different verdict on stored
     artifacts, and the row names each one. **Report-only; never blocks `apply`.** Accepting a
     reclassification is a legitimate call — the criteria may genuinely have moved and the new
     verdict may genuinely be the right one. What must not happen is that it go unremarked.
     **The count is a FLOOR, never a census**: an artifact written UNDER the incoming predicate
     agrees with it by construction and cannot discriminate, so the discriminating subset is the
     one predating the change and it is not fully derivable here.
   - `PREDICATE-STABLE` → either the predicate is byte-identical across the range, or it moved
     and no stored artifact changes verdict. The row says WHICH, because they are different
     answers: the first measured nothing and the second measured something.
   - `PREDICATE-UNDECIDABLE` → the differential could not attribute an answer — an absent or
     unparsable manifest, a corpus pattern matching no file, a verdict grammar matching no
     output, one-sided silence (on a site that declares `pass:`, one side yields no verdict token
     and no pass line on any series while the other side does; the row names the silent side, and
     a `pass: -` site abstains because a fail-only grammar cannot tell "every series now passes"
     from "the predicate crashed"), or a corpus that moved mid-run because the consumer's own
     pipeline is live. Every
     one of those produces no reclassification row while having measured nothing, so it is
     reported rather than folded into `PREDICATE-STABLE`. **A detector that cannot read its own
     subject must not return clean.**

   **Every row carries its population.** `population: root=… corpus=… series=…` names the
   consumer directory, file pattern and series key the site used. A row whose corpus was read adds
   `records= series= compared=`, then either `passed= unclassified=` or, for a site whose
   validator prints no pass line, `unclassified=n/a (grammar spells failures only)` — there a
   series with no verdict token may be a pass or an unparseable output, and nothing says which.
   In the step-5 report a STABLE site renders as one line carrying only the population
   definition, so a null can be re-derived rather than read as `none`. The counts stay in the
   detector's own output: they come from a live corpus, and the report region is byte-compared
   at step 7.

   **This check cannot be sited upstream and that is structural, not an oversight.**
   `consumer-boundary.md` is unconditional: no gate in the distribution reaches a consumer tree.
   The distribution DID run the same differential over its own fixture seeds before shipping
   0.442.0 and could not tell the intended effect from the regression, because one session had
   authored both the predicate and the seed declaring the result correct. The pull is the only
   process holding `base`, `theirs` and the consumer root at once.


## The adjudication loop (step 7: `HARD-*` and `override-readopt` rows)

   Work the `HARD-*` rows **one at a time**. For each:

   **(1) Build the evidence.** Run `reconcile/readopt-override.sh <dist> <theirs>
   <consumer> <override>` with no flag. It prints the dossier: the core section's
   `base_sha..theirs` diff, the override's body, its stated `reason:`, the superseded
   core lines still sitting in that body, and the lines core ADDED to the shadowed
   section that the body does not carry. Read both panels: a purely additive upstream
   change leaves the first empty and the second full.

   **(2) Decide, against the dossier, and say which and why in ONE sentence:**
   - upstream's change makes the override redundant → **retire**
   - the override's `reason:` still holds AND upstream changed the shadowed text →
     **readopt**
   - the override's `reason:` still holds AND upstream changed only text this override
     does not depend on (e.g. a prose/rationale edit elsewhere in the section) →
     **reaffirm**

   **(3) DO IT.**
   - **readopt** → `reconcile/pull.sh merge <dist> <base> <consumer> <theirs> <override>`,
     never `readopt-override.sh --merge` directly. This is a three-way merge (base =
     core@`base_sha`, ours = the override body, theirs = core@`theirs`): it applies
     upstream's change and keeps the consumer's delta. **Never hand-edit the body when
     `--merge` can do it** — a hand-merge is where half an upstream clause gets
     silently dropped. On CONFLICT, markers are left in the body and that is the one
     place a human is genuinely required; present the conflict hunk, nothing else.
     On exit 3 with a relayed `OVERRIDE-SHADOWS-POINTER-STUB` row nothing was written and
     no readopt is available: **retire**, and file the rows upstream as that row says.
   - **`HARD-UNREGISTERED-CORE-DRIFT`** → `reconcile/register-drift.sh <dist> <base>
     <consumer> <core-rel-path> --apply`. It authors the `overrides/` entry from the
     consumer's own sections, anchors it to real headings, stamps `base_sha` at **base**
     (where the delta forked from — NOT the sha being pulled; stamping `theirs` would
     claim the consumer had already read a change it has not), and reverts core.
     **Then write the `reason:` line, which it leaves as `TODO`** — write one from the
     diff and record it as a decisions row. An override whose reason nobody stated is
     one nobody can ever retire.
     If the delta merely **duplicates an existing override**, do not register a second
     one: revert core and say which override already carries it.
     `register-drift.sh` refuses by design on **two** classes, and both refusals are
     structural rather than a missing case. If it is a **hook**, the layer system has no
     override grain for hooks. If it is **`skills/ai-dlc-setup/*` or `schemas/*`**, the
     same is true for a different reason: overrides shadow a HEADING inside the ai-dlc
     skill, and a second core skill and schema data have no heading to shadow. Both are
     `scan`-marked, so the pull DOES report them and hands you this command — which then
     refuses. `validate-enforcement-map.sh` I31 binds the two lists so a newly scan-marked
     subtree cannot reach an unnamed refusal. In both cases the dispositions are: keep the
     consumer's version (accept per-entry, and it re-reports every pull), or upstream it.
     Reverting destroys the divergence; say so before anyone chooses it.
     Its other exit-2 refusals are NOT structural. In every one, core was NOT reverted and the
     edit is still in place, in a dry run and under `--apply` alike. Never revert core to get
     past one; that deletes the edit the refusal kept. The refusal's last line says which kind
     it is:
     - **`Re-run; if it repeats, register by hand`: a step failed mid-run.** Re-run it. These
       are `cannot classify section '<h>': diff did not run`; `cannot list the headings`;
       `cannot read the consumer's section` or `core's section`; `conservation: diff of core
       at <base> … did not run`; `conservation: the staged override is empty` (or `extension`);
       `conservation: cannot resolve core's span`; `conservation: the check did not run` or `did
       not report`; and any `cannot stage`, `cannot write`, `cannot create`, `cannot set the
       mode` or `cannot move`. One of them differs: `the revert did not land` means the override
       IS written and the edit is in both places, so remove nothing — re-run to finish the revert.
     - **`re-running without changing the file refuses the same way`: a verdict on the file.** Do
       not re-run; change the file or choose a disposition.
       - `conservation: the consumer DELETED core heading "<h>" (core line N)`. Follow its `Way
         through`: put the heading back with a body stating the retirement, then run it again.
         The section is then a changed section, and the override carries it.
       - `conservation: core line N (…) was changed or removed by the consumer…` and `conservation:
         consumer line N (…) is carried by nothing that was written…`. These cover a preamble edit,
         a heading an earlier heading's name swallows (`## Review` below `## Review Process`), a
         repeated heading, and a consumer-only heading whose name resolves to a core one.
         Overrides anchor by heading name, so do what the message says: move the edit into a
         uniquely named `##` / `###` section, or upstream it.
       - `conservation: the override shadows '<h>', which resolves to no heading`, and `<path>
         exists and is not a regular file`. Clear the path, or fix the heading, before running it
         again.
     Exit 1, `no ## / ### section differs`, writes nothing. The delta is outside every heading, and
     that includes an EOF append with no other edit.
     Check the row's status before you conclude anything:
     if it is `HARD-CORE-DRIFT-ABSORBED`, the disposition below applies. Otherwise say
     so, and let the operator keep it (it will report every pull) or upstream it. Do not
     paper over it.
   - **`HARD-CORE-BEHIND`** → **the copy is stale; the remedy is TAKE THEIRS.** Do not reach
     for `register-drift.sh`: there is little here to refile, and an override authored from a
     three-month-old blob anchors to headings upstream may have rewritten. Read the residual
     the detail names — `git -C <dist> show "${ancestor}:<core-path>" | diff - <consumer-path>` —
     and dispose of THAT, not of the base-relative diff. Typically the residual is small and
     already absorbed upstream by another route, in which case take theirs and say which
     upstream mechanism now carries each piece. If part of it is genuinely still consumer-only,
     that part — not the whole file — is the override candidate.
     **A recurring per-entry acceptance on a `HARD-` row is the signal to check for this.**
     An acceptance excludes the file from `apply`, which is what freezes it, which is what
     makes the next pull's diff larger. Three consecutive pulls on the reference consumer
     accepted a "genuine fork" that was a stale file whose two additions upstream had already
     absorbed elsewhere.
   - **`HARD-CORE-DRIFT-ABSORBED`** → **upstream took this change; the remedy is a REVERT,
     not an override.** `unregistered-drift.sh` proves the consumer's added lines are
     already present in core at `theirs` (it reports the hit count and percentage). So the
     delta is not consumer-specific behavior to preserve — it is a duplicate of core, and
     keeping it means carrying a fork of a file upstream now maintains. Revert with the
     command the detail string hands you:
     `git -C <dist> show "${theirs}:<core-path>" > <consumer-path>`.
     **Before you propose it, prove nothing is destroyed**: diff ours against theirs and
     confirm no consumer-only guard, path, flag, or exit code exists in ours that theirs
     lacks. If something does, it is a genuine consumer delta wearing an absorbed file's
     clothes — escalate it as such and do not revert. This is the one `HARD-*` row whose
     resolution DELETES consumer text, so its decisions row carries the diff as its evidence.

   **(4) Record THAT ONE disposition** as a decisions row: the verdict, its one-line reason,
   and the evidence you used, `decider` = `model`. It is not asked: the operator's merge of
   the update PR approves it.

   **(5) Stamp**: `--stamp readopt` / `--stamp reaffirm --note "<their words>"` /
   `--stamp retire`. `--stamp readopt` is refused while superseded core text or
   conflict markers remain, so a stamp cannot outrun the merge. `--stamp readopt` and
   `--stamp reaffirm` are both refused while a shadowed section is a load-pointer stub
   (`OVERRIDE-SHADOWS-POINTER-STUB`); `--stamp retire` is not.

   Then **re-run `layer-drift.sh` and `unregistered-drift.sh` and require ZERO `HARD-*`
   rows from runs that both exited 0.** Either one exits 2 with a `: REFUSED` line when a row
   could not be written, and `layer-drift.sh` exits 1 with one when an input could not be staged
   or read, or a base or theirs ref does not resolve;
   its short output is then not a zero. Do not carry forward your memory of having discussed them: the re-run is the
   evidence, and re-stamping is what makes it pass. A `HARD-` status that clears because
   you decided it was fine is the check-that-cannot-fail defect, in the tool built to
   prevent it.

   **THE TWO SCRIPTS TAKE DIFFERENT BASES ON THIS RE-RUN, and one instruction for both
   disarmed one of them.** The unqualified instruction *"pass `theirs` as the base on this
   re-run, not the pull's base"* is right for one script and
   wrong for the other, and the wrong half is silent.

   - **`unregistered-drift.sh` — pass `theirs`.** It measures the consumer against
     `<base-sha>` and presumes core still sits there. Core is now at `theirs`, so the pull's
     original base reports every line upstream ADDED as a consumer addition upstream
     absorbed — `HARD-CORE-DRIFT-ABSORBED` on a file `apply` just wrote, whose remedy is a
     revert to what it already is. The post-apply base IS `theirs`; that is the only base
     against which "consumer edits vs base" means what these status names claim.
     `CORE-AT-THEIRS` rows are the tell that the base was stale.
   - **`layer-drift.sh` — pass the PULL's base.** Its subject is what moved between base and
     theirs, not what the consumer edited. Most `ADJUDICATED` clauses are computed over
     that range, and `HARD-LAYER-ADJUDICATION-MISSING` (**LC-A1**) is demanded only on rows
     a clause at that level produces. With `base == theirs` those arms find no drift, so no
     adjudication is demanded, so the check cannot fail, and `hard-blockers.sh` prints a clean
     sheet on a tree where the verdicts are still owed. **Do not read a clause list here — a
     list of that set has already gone stale once, on the release that changed it.** Not every
     clause at this level is range-keyed: **LC-O15** (`OVERRIDE-SUPERSEDED`) compares a
     declaration at theirs against the entry on disk, so a degenerate range leaves its duty
     live and its rows above are real. Ask the reader which codes the version you are pulling
     holds you to: `layer-drift.sh --adjudicated-codes <dist> <theirs>`.
     Reported by the reference consumer — `0 HARD blockers.`
     with eighteen adjudications unrecorded — and reproduced on a scratch consumer: same
     tree, the pull's base gives `EXTENSION-HOOK-DRIFT` + `HARD-LAYER-ADJUDICATION-MISSING`,
     `theirs` gives `EXTENSION-OK` and nothing else. The register's own digest is
     spend-on-move, so re-running on the pull base cannot re-demand a verdict recorded this
     run.

   **You do not have to remember this.** `layer-drift.sh` emits `DRIFT-RANGE-DEGENERATE` when
   its two refs resolve to the same commit, naming the arms that cannot fire. If you see that
   row, the run said nothing about the layer — re-run it with the pull's base.

   **Re-running the WRAPPER post-apply takes a flag, and without it the wrapper is wrong
   whichever base you give it.** `reconcile/hard-blockers.sh` drives both detectors, so a single
   base has to be wrong for one of them: the pull's base makes `unregistered-drift.sh` report
   `HARD-UNREGISTERED-CORE-DRIFT` against text `apply` itself just wrote, and `theirs` disarms
   the arm above. Post-apply, call it as
   `reconcile/hard-blockers.sh --post-apply <dist> <pull-base> <consumer> <theirs>` — it passes
   `theirs` to `unregistered-drift.sh` and keeps the pull's base for `layer-drift.sh`.
   `reconcile/post-write-gates.sh` runs exactly this call as its `hard-blockers` gate. It also
   renders the `DRIFT-RANGE-DEGENERATE` row, which a `HARD-`-only filter would discard;
   a `0 HARD blockers.` line with that row beneath it is not a clean sheet.

   **Dispose of every `WORKLIST extension-reread` row — this is *the layer conformance
   adjudication*.** `apply.sh` emits one per `EXTENSION-HOOK-DRIFT`: the core file the extension
   hooks changed, and an extension has no section anchor, so nothing can locate what to
   re-merge. Read the entry against the new core text and record a verdict per entry —
   **still-additive**, **contradicts-core**, or **retire** — with the evidence of that read:
   `read.entry_line` and `read.core_line`, each ONE line copied verbatim from what you read (the
   entry's body, never its frontmatter, and the core text the blocking row names for its clause), at
   least 20 characters with at least 10 letters or digits, and not
   a heading. A verdict without them does not clear the row. A grep with no hit gives you nothing
   to quote, which is the point: the row never prints a line that would pass.

   **ORDER: make every edit this pull prescribes for the entry FIRST, then read the digest from a
   fresh run, then record.** Recording before an edit to the same entry spends the record you just
   wrote: the digest covers the entry's bytes, so the row re-fires under a new key and the verdict
   you wrote is addressed to text that no longer exists.

   **Recording is now the mechanism, not a note to self.** `layer-contract.yaml` carries these
   clauses at `level: ADJUDICATED`: the candidate set is mechanized and the verdict is yours.
   `layer-drift.sh` emits `HARD-LAYER-ADJUDICATION-MISSING` (**LC-A1**) for every such row with
   no recorded verdict, and a `HARD-` status blocks `apply`. Write one JSON object per line into
   `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`, shape in
   `.claude/schemas/layer-adjudication-register.json`, copying `clause` AND `subject_digest`
   **verbatim from the blocking row** — the row prints both, and the example below is one
   clause of several that produce these rows, so its `LC-E4` is an illustration and never the
   value to reuse:

   ```json
   {"clause":"LC-E4","entry":".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md","subject_digest":"<copied from the row>","verdict":"still-additive","recorded_utc":"2026-07-29T10:00:00Z","reason":"core's change was to the gate-type enum; this entry adds a check row and does not restate it","read":{"entry_line":"<one line of the entry, verbatim>","core_line":"<one line of the core text the row names, verbatim>"}}
   ```

   **Where `core_line` comes from depends on the clause**, and the blocking row says which:
   LC-E4 / LC-E6, an added or removed line of the range diff of the hooked file (marker
   stripped); LC-E14, a line of the declared `extends:` span at base or theirs; LC-O15, a line of
   the shadowed section at the entry's `base_sha` or at theirs; LC-E19, a line of the matched core
   section at theirs. A record that exists and does not clear says so in the row and in
   `--list-adjudications` (`recorded, not clearing: <which half>`): append a NEW record with
   `read`, never edit the old one.

   **If the verdict leaves work OWED, declare it — do not write it into `reason`.** A
   `still-additive` that is only true because somebody intends to fix something has recorded a
   decision and lost the obligation. Add an `owed` object (`id`, `what`, optional `closes_when`)
   and a later row discharges it by naming the id in `closes_owed`; the register is append-only,
   so a debt is never closed by editing the row that opened it. Measured on the reference
   consumer before this existed: 46 rows, verdict distribution 45 `still-additive` / 1
   `contradicts-core` / 0 `retire`, with four rows carrying obligations reachable only by
   grepping prose — one of which said, in as many words, *"Nothing but this reason field is
   tracking that debt."*

   ```json
   {"clause":"LC-E4","entry":"…","subject_digest":"…","verdict":"still-additive","recorded_utc":"…","reason":"…","read":{"entry_line":"…","core_line":"…"},"owed":{"id":"OWED-921-SPLIT","what":"split Check 921 into an overrides/ entry shadowing core Check 20","closes_when":"after this pull's apply"}}
   ```

   **Run `scripts/ai-dlc/audit-layer-debt.sh` and put its OPEN, UNDECLARED and
   CONTRADICTS-CORE-WITHOUT-AN-`owed` lists in the report, every pull.** OPEN is what this
   consumer owes; UNDECLARED is the migration backlog — rows whose prose reads like an
   obligation while declaring none. A debt nothing enumerates is a debt nobody acts on, which is
   the whole reason the field exists.

   The third list is the one that cannot be re-derived. A `contradicts-core` verdict is a
   judgement no detector can reach — that is stated where the verdict is defined below — and it
   is keyed on a `subject_digest` that expires the next time the entry or its hooked core file
   moves. After that the ruling is not overwritten; it is unaddressable, and every later row on
   the entry carries a different digest and so disagrees with nothing. `owed` is the only handle
   in this register that survives a digest change, because the debt join reads `owed.id` and
   never a digest. **Scoped per ENTRY, not per row**: the register is append-only, so a
   historical row can never acquire an `owed`, and the debt is declared by a later row — which
   is how both real ones on the reference consumer were in fact recorded.

   **TO RE-READ A KEY YOU HAVE ALREADY RECORDED A VERDICT UNDER, run
   `layer-drift.sh --list-adjudications <dist> <base> <theirs> <consumer>`.** It prints every
   keyed subject this pass can see — entry, target, `subject_digest`, the recorded verdict
   if there is one, and the `clause` id in the last column — and nothing else: no classification
   rows, no blockers, and no dependence on
   whether the row is still blocking. Pass the SAME base the pull uses, for the reason step 7
   states per script: base decides which rows the pass produces, so a degenerate range gives a
   short listing rather than a visibly missing one. **Do not withhold the register to re-fire the
   block.** That was the only way to read a key before this mode existed, and it means
   deliberately breaking your own gate state to read a value the tool already computed. You need
   the key AFTER the first write more often than before it: updating an `owed` object, and
   re-verifying a subject, both name it.

   The digest covers the entry AND the core file it hooks at `theirs`, so a verdict is spent the
   next time either one moves. It is a record of a reading, not an exemption for a path — which
   is why the register is keyed per SUBJECT and never per run. Changing your mind is allowed and
   has to be declared: a second record under one key stating a different verdict needs
   `supersedes` and a `reason`, or it is `HARD-REGISTER-CONTRADICTION` (**LC-A2**), because
   otherwise a lookup answers with whichever record happened to be read last.

   `contradicts-core` is the verdict `layer-drift.sh` cannot reach on its own. It emits
   `EXTENSION-RESTATES-CORE` when an extension COPIES a core section, but an extension that
   asserts the opposite of core in its own words restates nothing and matches nothing —
   `extensions/README.md`'s "Additive only" has no detector, and an extension carries no
   `base_sha` to compute one against. This re-read is that check. Do not add a textual
   contradiction detector instead: agreement between two prose rules is not a substring
   property, and a scanner that guesses would fire on every extension that legitimately
   narrows a core default.

   **Post-apply, verify against the RENDERED pipeline, never against core alone.** A
   core fix is effective only if it survives `overrides > extensions > core`
   resolution. After the core overwrite, for every override you re-adopted, grep the
   OVERRIDE for the new clause — that is the text the lead actually obeys. Core
   containing the fix proves nothing about a section the consumer shadows.

   **Offer the catalog relabel (step 3e).** Run `reconcile/relabel-extension-checks.sh
   <consumer-root> --apply` once core is in place, since the collision set is defined
   against the NEW core. An exit 2 with a `relabel: REFUSED —` line moved no file for the
   extension it names, and it is not "nothing to label": clear its cause and re-run it.
   Then run `scripts/ai-dlc/validate-layer-entries.sh` and report its
   errors/warnings in the apply summary. This never blocks the apply.

   **Offer the extension-check adoption (step 3ea).** Run
   `reconcile/adopt-extension-checks.sh <consumer-root>` once core is in place — the
   anchor set it subtracts against is the NEW core's, so a check the incoming release
   started anchoring drops out on its own. Decide each entry's `gate_types:` from the
   check's own text, record it as a decisions row, and apply it one entry at a time:
   `--apply --gate-types <list>`. Never guess the slice; refusing is what the tool does
   on its own if you pass `--apply` without it. Re-run
   `scripts/ai-dlc/validate-gate-manifest.sh` afterwards and report its verdict in the
   apply summary. This never blocks the apply.


## Per-bucket apply actions (step 7)

   **Flagged-block checkpoint (mid-apply, every block, not just conflicts).**
   Before executing a block's mechanical bucket action, check whether it (or
   its file, if flagged at file grain) carries `needs_operator_confirmation:
   true` from `classify-block.md` — this is orthogonal to bucket; a
   `domain-local` or `innovation` block can still need one. Being inside an
   authorized `apply` run on the step-6 branch does NOT waive this: writing is
   authorized here, but a specific judgment call the classifier flagged is
   not resolved by that authorization. When you reach such a block: STOP
   before acting on it. A `confirmation_kind: blend` block is an ASK family: present its
   specific question to the operator (same footing as a conflict) and apply only their
   explicit answer for that block. A `judgment` block is yours: decide it and record it
   as a decisions row. Never silently fall through to the
   bucket's default action because the rest of the run is "obviously fine" to
   continue. A real run hit this: two blocks a dry-run report explicitly
   flagged for operator review (a naming/kind decision, a genuine 3-way
   prose blend) reached `apply` with no formal gate forcing the question to
   actually be asked — nothing stopped the bucket's default action from
   silently deciding them. This checkpoint is that gate. Applies identically
   in untangle's 7u (`reconcile/untangle.md`).
   - apply-bucket blocks → write theirs into ours (path-mapped). If the file
     is listed in `reconcile/setup-sites.md`, run the **mask/reinject
     transform** (`reconcile/mask-reinject.md`) instead of a blind overwrite — extract the
     consumer's live values at each declared site before writing theirs, then
     reinject them at the same sites afterward. A blind overwrite of a
     manifest-listed file blanks the consumer's real model strings/ownership
     paths/deploy commands back to `{placeholder}` tokens — this happened
     once (the reverted Phase-2B spike) and must not happen again.
   - `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE` → **a NEW core file carrying
     setup-substitution sites. mask/reinject CANNOT do this one**: that transform
     reinjects the CONSUMER's live values, and a file the consumer does not have yet
     has none to extract. A blind copy leaves `{token}` on a live line, and the
     leftover-token gate below then blocks delivery after every other write has
     landed. Substitute BEFORE the write: for each site `setup-sites.md` declares on
     that path, **decide it yourself**: take the value the
     consumer already uses for its nearest-equivalent role and record it as a decisions row (a new
     team-role's model and effort are not such a site: they come from its
     `aiDlcRoles` entry, never from the role file). Then write theirs with those values substituted in.
     Every role file predates the consumer's install, so `ai-dlc-setup` filled these
     tokens once and the pull never had to. This bucket exists for the case that
     breaks: a template-bearing core file that postdates the consumer's install, of
     which `team-roles/remediator.md` is one.
   - keep/domain-local/innovation blocks → leave ours; for domain-local, layer
     theirs' non-conflicting additions; for innovation, append to the
     push-candidate ledger. **The push asymmetry between those two is a
     decision, not a default, and it is the same one the untangle bucket list
     makes in `reconcile/untangle.md`.** Before leaving a block as domain-local, answer the
     dependency question against `theirs`: does any core text at the block's
     hook target — a gate, a breach message, a budget row, a cross-reference —
     presuppose the machinery being kept local? If it does, core is incomplete
     without the block; treat it as innovation and append it to the ledger.
     A block left domain-local is the positive claim that nothing core does.
   - conflicts → apply only operator-adjudicated resolutions.
   - `UPSTREAM-DELETED` files (upstream removed the file, consumer untouched vs base) → inside
     `pull.sh apply` the script `git rm`s the path (never `-f`) only when the working-tree file
     still hashes to the base blob, re-checked immediately before the rm, and records a decisions
     row. Any other state reaches you as an `ASK deletion` row: ask it, one question per path, and
     delete only on an explicit yes. A `UPSTREAM-DELETED-NOOP` path (consumer already lacks it) is a
     silent noop. A `UPSTREAM-DELETED+consumer-modified` path is an ASK family: the consumer's
     modifications may be an un-pushed innovation worth preserving as an extension; default
     keep-ours.
   - `ORPHANED-RELOCATED` files (this distribution moved where it ships a subtree; the copy left
     at the old consumer path still hash-matches the blob we wrote there) → the script `git rm`s
     the stale copy only when the working-tree file equals that blob, re-checked before the rm,
     and records it; any other state is an `ASK deletion` row, whose question states the new
     path. `ORPHANED-UNKNOWN` and `ORPHANED-RELOCATED+consumer-modified` are **never deleted** by
     the pull: both are ASK families, default keep-ours.
   - `TEMPLATE-PROSE-MERGE` files (from step 3b, listed by name in the report
     region's "Template pre-classification" section) → run the **marker-anchored mask/reinject
     transform** in `reconcile/template-sites.md`: capture the consumer's
     filled config at each `{token}` fill region, apply the upstream
     base→theirs boilerplate delta, reinject the captured config. The
     boilerplate-only shortcut applies when the delta touches no fill region
     (the Context-Mode Usage removal is this case). On anchor-drift (a
     base-template token/marker not locatable in the consumer file), STOP and
     treat that file as a classify conflict (an ASK family) — never best-effort-place a
     preserved value.
     `apply.sh` hands each such file back as a `WORKLIST template-prose-merge` row, which
     withholds the re-stamp, and records the file as the pull found it on a `template:` line
     (under a `template-hashes:` line) in `.claude/.ai-dlc-applying`. `--finish` re-checks the
     record: the file's bytes or its mode must have moved, or it prints
     `WORKLIST finish-template-unmerged` and withholds. A file deleted since the record clears
     it, because a deletion is a disposition. The deliberate-no-op exit is deleting that file's
     own `template:` line.

## The owed-derivations record (step 7)

   **`apply.sh` runs the derivation differential on every ordinary pull and records what it finds; you do not run it for the record.** After its writes and before the stamp it executes `derivation-differential.sh --record-owed _bmad-output/ai-dlc-update/owed-derivations.tsv --log-name <name>` itself (not under `--finish`). A derivation this pull broke is RECORDED OWED by that run and drawn as a `WORKLIST artifact-derivations` row (one row per cause: when a fence named a moved path it carries the finding; otherwise `WORKLIST artifact-derivations-owed`), so LEAVING it needs no further step. A refused measurement is a `DECISION artifact-derivations-differential` row and leaves the record ABSENT: a refusal is no measurement. An absent record means no reconcile measured the tree and a present one with 0 OWED rows means measured, nothing owed. **The log name:** `apply.sh` mints `reconcile-log-<UTC stamp>.md` once per pull, passes it as `--log-name`, and prints it as the path of a `NOTE reconcile-log-name` row; write your reconcile log at exactly that path (step 7), because the record's last field (field 7) carries that name and the reader's OPEN line points at it. A re-run of the same range reuses the name already on its OWED rows. Do not run the helper by hand with `--record-owed` unless a DECISION row tells you to, and then pass `--log-name` with the name you will use for your log: the record dedups on key and range, never on field 7, so a wrong name cannot be repaired by a later run. The record is append-only with no status cell; `scripts/ai-dlc/check-owed-derivations.sh` derives which rows are still open. Only CURRENT-sprint and living-document artifacts are recorded; a past sprint's file or a history file is named by the differential's `INFO out-of-scope` row and is neither run, recorded nor enforced. **The differential's own rows reach the manifest as `NOTE` rows**, from every run whatever its exit: each `INFO <kind>` row as `NOTE derivation-info-<kind>` (the out-of-scope one as `NOTE derivation-info-out-of-scope`), each `NOTE` row as `NOTE derivation-note` with its key or path in the path field, each `UNASSESSABLE` row as `NOTE derivation-unassessable` with the derivation's key in the path field, and its `SUMMARY` row as `NOTE derivation-summary`. A `derivation-unassessable` row is a derivation the validator refused on either side, so no verdict cleared it: adjudicate each one by hand, and relay EACH IN FULL, one by one with its key and detail, never only as a count. To close a row, append `REPOINTED<TAB><old file:line><TAB><new file:line><TAB>$ <new command>` to the record: the reader re-derives the new derivation on every read, so the row closes only if it reproduces.

## Post-write gates (step 7)

   **A gate whose exit code was not observed is UNDECIDED, and UNDECIDED is never a pass.** Not on
   a clean-looking last line, not on "each check's own output reports clean", not on an empty
   `rc=`. A pipe (`| tail -3`, `| head`, `| grep`) makes the status you read the status of the last
   stage and cuts away the lines a refusal is printed on; a consumer session passed two gates
   exactly that way, on `rc=` with nothing after it.

   **If `reconcile/post-write-gates.sh` is absent**, run each gate below on its own line, UNPIPED,
   with its output sent to a file, and capture the code on the very next statement:
   `<gate> > <file> 2>&1` then `rc=$?`. Read `rc` before anything else; then read the whole file (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB, never `ctx_*`).
   On a pull whose step 2 self-update landed, the re-invocation step 2 prescribes already runs
   this text and this script, so it is present. It is absent only when step 2 returned
   `SELF-UPDATE-DEFER` or the skill's branch was not synced — the pull then runs the skill copy
   that predates it, and this fallback form is the capture.

   **Leftover-token gate — hard, runs after the last write, blocks delivery.**
   After every overwrite above and BEFORE the re-stamp, grep the consumer's core
   for a template token that survived on a LIVE line:

   ```
   grep -rn '{[a-z_]*}' <consumer>/.claude/team-roles/ | grep -v '<!--'
   ```

   `post-write-gates.sh` runs this as `post-write-gates.sh --leftover-tokens <consumer>`, which
   stages the first grep's output to a file so that its own exit 2 (unreadable) is a refusal: in
   the two-stage pipe above the status is the second grep's and says nothing about the first.

   A hit is a FAIL. STOP before the re-stamp and name the file and the token — then
   tell the two causes APART, because they have opposite remedies:

   - **The site is NOT declared in `setup-sites.md`.** The overwrite blanked a live
     consumer value back to its `{placeholder}`. Add the missing site to
     `setup-sites.md` and redo that file's overwrite through **mask/reinject**
     (`reconcile/mask-reinject.md`).
   - **The site IS declared, and the file is NEW to this consumer** (bucket
     `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE`). Nothing was blanked — the file has
     simply never been through `ai-dlc-setup`, so there was no consumer value to
     reinject and mask/reinject is the WRONG tool. Substitute the declared sites from
     the operator's answer (step 7), then rewrite the file.

   Do not deliver a tree that dispatches a teammate against an unfilled `{token}`.

   Exclude `<!-- ... -->` doc comments — those legitimately carry the token text
   and MUST survive from `theirs` (per the mask/reinject transform in
   `reconcile/mask-reinject.md`, the doc
   comment is not part of the captured span). The token only matters on a live
   line. Match the same idea for non-role manifest files (`steps/*.md`), whose
   sites are commands and paths rather than `/model` strings.

   **Setup-site drift gate — the OTHER direction, and it is a script.** The gate
   above catches theirs' `{token}` surviving where the consumer's value belonged.
   This catches the reverse: OURS surviving where THEIRS's content belonged.

   ```
   reconcile/setup-site-drift.sh <dist> <consumer> <theirs>
   ```

   Exit 0 required — observed as `post-write-gates.sh`'s `GATE setup-site-drift PASS` line, or
   by the unpiped fallback form above; never read off the tail of its output. Same place in the
   sequence — after the last write, before the re-stamp. It asserts that every file declaring a setup site equals `theirs`
   byte-for-byte outside that file's declared spans, and names the file and line
   where it does not.

   **Its failure direction is upstream content NOT ARRIVING**, which is why it is
   worth a program: the pull reports success and the consumer is quietly behind,
   with nothing downstream disagreeing. Measured on the reference consumer during
   the 0.297.0 → 0.300.0 hop, `deploy-validate.md` kept OURS at line 26 — outside
   both of that file's declared spans — and the line it kept prescribed the OLD
   artifact-path grammar that release had just replaced. It surfaced only because
   `HARD-CORE-BEHIND` flagged it independently: the safety net working, not the
   mechanism working.

   **This existed as prose and the prose was not enough.** §7v criterion 5
   (`reconcile/untangle.md`) states
   exactly this rule, was untangle-only, and has already reported PASS on an
   instance of it (`dev.md`, three of theirs' model-option comment lines) — because
   the agent asked to check the transform is the agent that just performed it.

   *Why this exists.* `untangle`'s §7v criterion 4 (`reconcile/untangle.md`) already asserts "zero remaining
   `{...}` tokens in any team-role file" — but 7v is untangle-only, and the
   ORDINARY pull had no equivalent, so a manifest miss landed silently on the one
   path consumers actually run. It did: a role file carrying model tokens shipped
   while `setup-sites.md` went untouched for nine minor versions, so the manifest
   did not declare that role's model sites at all. The first
   consumer pull to touch that file would have overwritten a live
   a live model string with that role's unfilled placeholder and broken
   every adversary dispatch — with nothing in the run to catch it. A manifest is a
   hand-maintained list and WILL go stale again; this gate is what makes the next
   staleness loud instead of silent.

   Role files carry no model string, so no model site can be omitted from the
   manifest. This gate covers the sites that remain — ownership paths and
   deploy/smoke commands.

   **Hook-registration gate — hard, runs after the last write, blocks delivery.**

   ```
   scripts/ai-dlc/validate-hook-registration.sh
   ```

   Exit 0 required — observed as `post-write-gates.sh`'s `GATE hook-registration PASS` line, or
   by the unpiped fallback form above. Same place in the sequence as the two gates above — after
   the last write, before delivery. It asserts that every `.claude/hooks/ai-dlc-*.sh`
   on disk is registered in `.claude/settings.json`, and that every registration
   names a hook that is there. Both sides are derived; nothing is hand-listed.

   A nonzero exit is a FAIL. STOP and run the settings reconcile — the
   `TEMPLATE-JSON-MERGE` bullet above is the same command — then re-run this gate
   until it exits 0. Exit 2 means the check could not run at all, which is a FAIL
   for the same reason: an unknown reads exactly like a clean.

   *Why this exists.* The two halves of a hook delivery are enforced differently.
   `apply.sh` writes the hook FILE mechanically, with a manifest row. The
   REGISTRATION is `settings-merge.sh`, and its only invocation sites in the whole
   distribution are prose — the two in this file. A pull that skips them ships a
   hook that is on disk, looks installed, and never fires, with no error and no
   absence anywhere to notice. `apply.sh` now emits a `WORKLIST settings-merge` row
   naming each such hook at the moment it creates the state; this is the gate that
   makes the row impossible to walk past.

   *Why it does not key on the `TEMPLATE-JSON-MERGE` bucket.* That bucket is a
   DELTA — preclassify emits it only when the template itself moved between `base`
   and `theirs`, and `TEMPLATE-UNCHANGED-NOOP` otherwise. A consumer whose
   settings.json went stale on an EARLIER pull produces no delta at all, so the
   bucket is silent on exactly the tree that is already broken. This gate reads
   disk state, so it fires on that tree too. Measured on the reference consumer
   while it was written: `ai-dlc-rules-floor.sh` — which `install.sh` calls "the
   SINGLE detector, running every session" — present and unregistered for six
   releases, across pulls that reported success.

   **Taught-schema gate — hard, runs after the last write, blocks delivery.**

   ```
   AI_DLC_PROJECT_ROOT=<consumer> bash <consumer>/scripts/ai-dlc/sync-taught-schema.sh --check > <file> 2>&1; rc=$?
   ```

   Exit 0 required — observed as `post-write-gates.sh`'s `GATE taught-schema PASS` line, or by
   the unpiped fallback form above. Same place in the sequence as the gates above — after the
   last write, before delivery. It asserts that every generated taught-schema example under
   `.claude/skills` and `.claude/team-roles`, extensions included, is rendered from the schemas
   in `.claude/schemas/`. It only checks and writes nothing. Its `FAIL` lines go to stderr, so
   capture both streams. An absent script is UNDECIDED; exit 2 (root unresolved) is a FAIL.

   A `FAIL` naming a STALE example is cleared by `bash scripts/ai-dlc/sync-taught-schema.sh` (no
   arguments; it rewrites only the generated regions). Run it only after every semantic-merge
   and `finish-unapplied` row is resolved, because the merge brings theirs' region and a sync
   before it moves the file's blob; then re-run this gate. A hand-written example, an unknown
   profile or a region never closed is not cleared by the sync: edit the file as the check's
   `FIX` text says, then re-run this gate. Re-run `pull.sh finish` after it only while the
   `.claude/.ai-dlc-applying` marker stands (every driver apply leaves it); a direct apply that
   already stamped owes no re-stamp.


## The finish (step 7)

     *Why this is a flag.* A stale `skill_commit` is not cosmetic.
     `unregistered-drift.sh` suppresses a machinery file as `CORE-AT-SELF-UPDATE`
     when it is byte-identical to the distribution at `skill_commit`, which it reads
     from this stamp. Leave the field behind and every machinery file this apply
     wrote from theirs reads as consumer drift on the next pull, with a printed
     remedy that reverts upstream's own text. That is the same false-drift failure
     the intermediate-ref suppression exists to prevent, reaching the operator
     through the stamp instead of through the scan.
     **THE STAMP IS WITHHELD WHILE ANY ROW IS OUTSTANDING, AND `--finish` IS HOW YOU
     ADVANCE IT. THIS IS A REQUIRED STEP, NOT A RECOVERY PATH.** The first `apply.sh`
     run of a pull that hands back ANY `WORKLIST` or `DECISION` row now emits
     `DECISION restamp-withheld` instead of `RESOLVED restamp`, leaves the stamp at
     `<base>`, and leaves `.claude/.ai-dlc-applying` in place — so the consumer's
     `pre-push` keeps refusing the fixture suite. That is correct: the tree really is
     a mixture until you have done the rows. **Under the pull driver the ordinary run never
     stamps, rows or none:** `pull.sh apply` passes `--stamp-at-finish`, and with nothing
     outstanding that run writes no stamp field (neither pair), keeps the marker with its
     `theirs:`, classify and template records, prints no `RESOLVED restamp` or `RESOLVED
     consistent` row, and writes one `STAMP-DEFERRED<TAB><base><TAB><theirs>` line on stderr,
     from which the driver prints `NEXT pull.sh finish [--carried-machinery-slice] <dist> <base>
     <consumer> <theirs>`. That line is the next step, not a decision. The finish with that same
     `<base>` is then the one write of the stamp, so its tree check runs against the base the
     pull started from. `--stamp-at-finish` combined with `--finish` is a usage error (exit 2).
     A direct `apply.sh` run without the flag stamps as described here. **When every
     `WORKLIST` and `DECISION` row above is disposed, run
     `reconcile/pull.sh finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>`**
     (it runs `apply.sh --finish`, and only the driver rewrites the record deliver compares).
     It checks the tree, then does the stamp and the marker clear — it runs no resolution
     phase and writes no core file, so it cannot undo or redo your merges. Carry `--carried-machinery-slice`
     through to it if the first run had it; the withheld row prints the exact command,
     flag included.

     **`restamp-withheld` has two forms, and one of them does NOT name `--finish`.** When an
     outstanding row's remedy is a step only a fresh ordinary run performs — the known_skills
     refile whose diff did not run, an exec-bit finding, a staging refusal after the writes — the
     row says to re-render the report with `emit-report.sh` and re-run apply with the same four
     arguments, and that `--finish` is not the next step. This is the one path where a re-render
     is still the remedy, because this run already wrote the tree. Re-run apply: it compares the
     re-rendered region against the one step 5 recorded, and when a re-approval is owed it prints
     the question and the option label. Ask exactly that question with AskUserQuestion, offering
     exactly that label, wait for the answer, and re-run apply. The finisher re-checks those rows
     and withholds while they are undone. It does not re-check a `scaffold-ignored` row; take that row's own exit, or the next pull raises it again.

     **`restamp-withheld` on a stamped tree.** Under `--finish` on a tree whose stamp already reads
     `<theirs>` with no `.ai-dlc-applying` (an earlier apply stamped it), both forms replace the
     "Left at `<base>`, and `.ai-dlc-applying` is deliberately left in place" sentence with: "The
     stamp already reads `<theirs>` (an earlier apply or finish wrote it) and `.ai-dlc-applying` is absent;
     this run changed neither." Every other state keeps the old sentence.

     **`pull.sh record` rows.** `record` runs no `apply.sh` check and writes no stamp. On a finished
     pull whose record names `<theirs>` it prints `NOTE pull-writes-recorded <n> <theirs>` (exit 0).
     It prints `REFUSED record-pull-unfinished rc=2` while `.ai-dlc-applying` exists and `REFUSED
     record-no-record rc=2` when the record is absent or names another `<theirs>`. It re-records only
     the paths named after `--` (`pull.sh record <dist> <base> <consumer> <theirs> -- <path>...`): a
     recorded path whose content moved and that is not named prints `NOTE pull-writes-moved <path>
     recorded <blob> now <blob>`, then `REFUSED record-path-unnamed rc=2`, and nothing is written.
     Each named path that moved is listed in `<git-dir>/ai-dlc-pull/pull-writes.rerecorded`, and
     deliver discloses it as `NOTE pull-writes-rerecorded <path>` in the commit message and the PR
     body. `record -- <path>` is the remedy of `REFUSED deliver-pull-writes-moved`; `REFUSED
     apply-pull-writes-moved` keeps `pull.sh finish`.
     A delivered pull writes `<git-dir>/ai-dlc-pull/pull-writes.delivered`, and the unfinished check
     skips a record whose `<theirs>` it names.

     **`deliver-dirty-overlap` and `--whole`.** A file dirty at the snapshot that the pull also changed
     is committed as the pull's change only (a three-way merge), staged or not. Where the merge
     overlaps or the pre-pull content was not recorded, deliver prints `NOTE deliver-dirty-overlap
     <path> overlap|unrecorded` per path, then `REFUSED deliver-dirty-overlap rc=2`, before any write;
     staging the file does not lift it. `pull.sh deliver --whole <path> ...` (repeatable) commits each
     named path whole as the worktree holds it and writes `NOTE deliver-dirty-whole <path> delivered
     whole at the operator's request; your uncommitted edits in it are in this commit` into the commit
     message and the PR body.

     *Why a second invocation rather than a smarter first one.* The rows are work YOU
     complete after this program has exited, so there is no moment during the first run
     at which the stamp is true. And the finisher cannot simply re-run the phases: a file
     you semantically merged keeps a consumer delta by definition, so it re-buckets
     `BOTH-CHANGED->CLASSIFY` on every subsequent run and the hand-back would never
     clear. Filed by the reference consumer as
     `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE`, reproduced across two pulls
     a month apart — one run printed `RESOLVED restamp` beside 37 outstanding rows. The
     stamp is the next pull's merge base, so an abandoned apply left a tree claiming to
     be at theirs, and the un-merged files then read as `ALREADY-AT-THEIRS` to every
     detector that compares against it.

     *What `--finish` checks before it stamps.* It does not take your word that the rows
     are done. In this order, and every failure is a `WORKLIST` row that withholds the
     stamp and leaves the marker in place:

     1. **`<theirs>` is the ref this tree was written from.** It compares the `core/` tree
        of the `theirs:` recorded in `.claude/.ai-dlc-applying` against the `<theirs>` you
        typed. On a mismatch it prints `DECISION restamp-identity-mismatch`, writes nothing,
        and skips the two checks below — an unapplied set computed against the wrong ref
        names content this tree was never approved for.
     2. **`<base>` is the base the tree started from.** It must resolve to a commit, and its
        `core/` tree must equal that of the stamp's own `commit:`. Otherwise
        `WORKLIST finish-base-unverified`: re-run with the stamp's own `commit:` as `<base>`, except
        when that commit is `<theirs>` and no marker is left, where the row says there is nothing
        left to verify and to deliver.
        The `DECISION restamp-withheld` row beside it echoes the `<base>` you typed, so do
        not copy its command on this row.
        A `<base>` typed as `<theirs>` makes every range empty, so this is not optional.
        On a driver pull the stamp still reads the `<base>` the apply was given, so this check
        fails only on a mistyped `<base>`, or when the apply that wrote the tree had already
        stamped: an apply run by an engine that predates `--stamp-at-finish` (the pull that
        delivers it under `SELF-UPDATE-DEFER` or `SELF-UPDATE-UNDECIDED`, when that apply
        handed back nothing), or a second `finish` after one that stamped. There the stamp's
        `commit:` is `<theirs>`; re-running with it exits 0 over an empty range, which checks
        nothing that the earlier stamp did not, so record that finish as unchecked.
     3. **No file still reads as a pure apply.** It runs `preclassify.sh` with the same four
        arguments, and every row still bucketed `UPSTREAM-ONLY`, `UPSTREAM-ONLY-ADD` or
        `…SETUP-TOKENS…` is a `WORKLIST finish-unapplied` row naming the file — missing,
        still at base, or lacking theirs' exec bit. Write theirs' copy and re-run `--finish`.
        A file bucketed `…CLASSIFY` never counts HERE, so a merged file — which keeps a
        consumer delta by definition — cannot wedge this check; a `.dist-only` fixture at
        `<theirs>` is skipped. If `preclassify.sh` fails, or returns nothing while the range
        moves `core/`, that is `WORKLIST finish-unverified-tree`, never a pass.
     4. **No file handed back as a semantic merge is still untouched.** The ordinary run
        records, in `.claude/.ai-dlc-applying`, the consumer blob AND exec bit of every file it
        handed back under a `…CLASSIFY` bucket, as `classify: <blob> <755|644><TAB><path>`. A
        recorded file whose blob and mode both still match is `WORKLIST finish-classify-unmerged`:
        the merge was never done. Do it and re-run `--finish`. A file you merged by hand differs
        from the record in its bytes or its mode (a merge that is only `chmod +x` counts), so it
        does not hold the finisher up; one you deleted does not either. A marker that exists and
        could not be read, an unreadable record, or an unreadable file is
        `WORKLIST finish-classify-unverified`.

        The record is written once per BASE: a later ordinary run from the same `base:` — the
        re-run a withheld row prescribes, a pull re-pointed at a newer `<theirs>`, a second pull
        before finishing — keeps every line already there and adds only new paths, so a copy you
        already merged never becomes the reference. `UPSTREAM-DELETED+consumer-modified` and
        `ORPHANED-UNKNOWN` files are still handed back but are NOT recorded, because keeping the
        consumer's copy is their normal disposition.
        Such a later pull runs from the working branch, never from the reconcile branch an
        unfinished apply left checked out: step 1 stops on a skill branch whose PR is not
        merged and names the continuations.

        **If keeping a recorded copy as it is IS the disposition** — the merge is deliberately a
        no-op, which is common for `BOTH-ADDED` — delete that file's own `classify: … <path>`
        line from `.claude/.ai-dlc-applying` and re-run `--finish`. Every other check still runs,
        and the marker keeps the fixture suite blocked until the stamp clears it. Removing the
        whole marker (`rm .claude/.ai-dlc-applying`) is the LAST resort: it unblocks the fixture
        suite on a tree that may still be mid-pull, and stamps with
        `DECISION restamp-identity-unchecked`, forfeiting check 1 and this check for every other
        handed-back file.

        A marker written by an apply that predates the record carries no `classify-hashes:`
        line, and a later run from the same base leaves it that way (the tree may already hold
        your merges, so nothing read then is the copy the apply found). `--finish` then says so on
        a `NOTE finish-classify-unrecorded` and does not withhold, so this check cannot fire on
        that marker. On the pull that delivers the record that happens only under
        `SELF-UPDATE-DEFER` or a leftover same-base marker; when step 2's self-update lands, step 7
        runs the new apply and the check is live. A path carrying a TAB or a `"` reaches the record C-quoted by
        `preclassify.sh` and is not recorded either; confirm such a file's merge by hand.
     5. **No template-derived file handed back as a merge is still untouched.** The ordinary
        run records, under its own `template-hashes: <n>` line, the consumer blob AND exec bit of
        every `TEMPLATE-PROSE-MERGE` file, and the path of every `TEMPLATE-JSON-MERGE` file whose
        merge is owed or could not be tested, as `template: <blob> <755|644><TAB><path>`. A prose
        file whose blob and mode both still match is `WORKLIST finish-template-unmerged`; a change
        to either clears it, and so does deleting the file, because a deletion is a disposition. A
        recorded `settings.json` is
        judged by `settings-merge.sh` run on a copy, never by its blob, and a copy that still
        changes is `WORKLIST finish-template-json-unmerged`. A marker that exists and could not be
        read, a record that could not be read, or a recorded file that could not, is
        `WORKLIST finish-template-unverified`; an absent marker is not checked. An ordinary run
        whose `preclassify.sh --templates` scan refused records nothing and writes
        `template-hashes: refused`; `--finish` withholds on that with
        `WORKLIST finish-template-unscanned`, which a fresh ordinary run with the same four
        arguments clears, once the cause of the refusal is fixed. That run's completed scan
        replaces the `refused` line with the record. Deleting the `template-hashes: refused`
        line from `.claude/.ai-dlc-applying` and re-running `--finish` is the LAST resort: it
        stamps with only `NOTE finish-template-unrecorded`, forfeiting this check for this pull,
        so every template-derived file's merge is then confirmed by hand. `--finish` does
        not re-run the template classification, which reads the same on a merged tree as on an
        untouched one. The record is written once per base, exactly as in check 4. Nothing
        compares file content to the template, because a correctly merged file keeps consumer
        edits that any such comparison would count against it.

        **If leaving the file as it is IS the disposition**, delete that file's own
        `template: … <path>` line from `.claude/.ai-dlc-applying` and re-run `--finish`. Every
        other check still runs.

        A marker written by an apply that predates the record carries no `template-hashes:`
        line, and a later run from the same base leaves it that way. `--finish` then says so on a
        `NOTE finish-template-unrecorded` and does not withhold, so this check cannot fire on
        that marker.
     6. **The two remedies only a fresh ordinary run performs are done.** A known_skills entry
        the consumer added in place and never refiled is `WORKLIST finish-refile-owed`; a refile
        check that could not run is `WORKLIST finish-refile-unverified`; a shipped file whose
        exec bit disagrees with upstream is `WORKLIST finish-exec-owed`.

     A changed setup-sited file never byte-matches base or theirs, so it usually buckets
     CLASSIFY; `--finish` checks it with `setup-site-drift.sh --file` and, when that does not
     pass, names it on a `NOTE finish-unverified` row and does not withhold,
     and check 4 does not record it. Confirm those by hand.
     Every `NOTE` row `--finish` prints is read, worked and relayed as step 7's `NOTE` bullet says.
     Nothing here checks that a merge is
     CORRECT — only that no file the ordinary run would have overwritten from theirs is still
     waiting for it, and that no handed-back file is still the copy the apply found.

     It does not gate on a `DECISION` row:
     those you have already adjudicated, or they are the tool saying it could not look,
     and gating on one that cannot clear would wedge the consumer with no exit.
     After the stamp it runs the hook-registration validator, the transient-ignore check, the
     agent-definitions check and the taught-schema check, as the ordinary run does. Their
     `WORKLIST` rows are advisory: they print (`pull.sh finish` reports each as
     `DECIDE <kind> <path> advisory`), but they never hold the stamp or keep
     `.claude/.ai-dlc-applying`. Do their work before deliver.

     The taught-schema check runs the consumer's `scripts/ai-dlc/sync-taught-schema.sh --check`
     and names a `WORKLIST taught-schema` row (each file whose generated example is stale; the remedy is
     the sync, after every merge row is done) or a `WORKLIST taught-schema-region` row (`file:line`
     of a hand-written example, an unknown profile or an unclosed region; the remedy is a hand
     edit). A stale file still owed a semantic merge is named on a `NOTE taught-schema-merge-first`
     row instead of the sync row: merge it first. Either WORKLIST row's remedy ends in one of two
     forms. While the marker stands (a `--finish` or an ordinary apply that withheld, or any
     driver apply, which never stamps) it ends "then re-run post-write-gates, then re-run
     `pull.sh finish` (it runs `apply.sh --finish`)". On a run
     that stamped, the row prints after the stamp and ends "then re-run post-write-gates; this
     apply already stamped, so no re-stamp is owed": do not run `--finish` there, because with
     no marker it records the re-stamp as `DECISION restamp-identity-unchecked`. A check that
     could not run or be read is a `DECISION taught-schema-unchecked`, `taught-schema-unparsed`
     or `taught-schema-unreadable` row and does not withhold.

     **Every row `--finish` can emit that withholds the stamp**, derived from the `say WORKLIST`
     sites `--finish` runs before the stamp, plus `staging-refused`, which
     `ap_staging_refused` emits as a `WORKLIST` under `--finish`: `finish-marker-directory` (the marker's path is a directory), `finish-base-unverified`,
     `finish-unverified-tree`, `finish-unapplied`, `finish-classify-unmerged`,
     `finish-classify-unverified`, `finish-template-unmerged`, `finish-template-json-unmerged`,
     `finish-template-unverified`, `finish-template-unscanned`, `finish-refile-owed`,
     `finish-refile-unverified`,
     `finish-exec-owed`, `staging-refused`. The advisory rows printed after the stamp never
     withhold: `hook-unshipped`, `settings-merge`, `settings-local-dangling`, `transient-ignore`,
     `transient-ignore-tracked`, `agent-definitions`, `taught-schema`, `taught-schema-region` (and
     a `staging-refused` from their own staging). Three `DECISION` rows stop it without stamping, because they write
     nothing: `restamp-identity-mismatch`, `restamp-unresolvable` and `restamp-absent` (no stamp
     file at all). `restamp-failed` and `skill-restamp-failed` also leave the stamp short of
     `<theirs>`, but only after a write was attempted.

     *Why this is its own bullet.* It stays out of the re-stamp paragraph above: one
     sentence after "**`apply.sh` does this; you do not edit the stamp**", a reader
     reasonably attributes both to the tool, and the reference consumer filed exactly that
     (`PC-S329-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG`). Measured when they did: **zero
     occurrences of the token in `apply.sh` against nine files here that name the artifact** —
     the contract stated everywhere except in the program a reader took to be honouring it.
     The run succeeded, the stamp advanced, and the only durable record of what the apply
     decided was absent.

     *Why the tool does not write it instead.* Every section above except the manifest and the
     stamp is outside what `apply.sh` can observe. A skeleton it could fill would ship a file
     whose empty sections read as written ones. **It says so on every successful run** — naming
     this path and stating that it does not write it — because prose alone is what failed here
     the first time.
