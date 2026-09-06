# Invariant index

GENERATED FILE — do not edit by hand. Rendered by `scripts/render-invariant-index.sh` from
the arm headers in `scripts/validate-enforcement-map.sh`, and byte-compared at pre-push, so
an invariant cannot be added, retired or renamed without this file moving with it.

An invariant is LIVE here when an arm header declares it — a comment opening with the ID and
closed by `:`, e.g. `# --- I54b: ... ---`. The renderer additionally asserts, every run,
that every `err`/`warn`/`fail` call in that file sits inside exactly one declared arm and
that every declared arm contains at least one such call. Neither direction may be non-zero.

To change this file, change the arm header it came from and re-run the renderer.

| ID | What it binds |
|----|---------------|
| I1 | set equality between the catalog anchor set and the map's check ids |
| I2 | set equality between the catalog anchor set and the map's check ids |
| I3 | GATE_MANIFEST (gate_type, check) pairs vs map gate_types |
| I4 | no dormant binding |
| I5 | core_manifest copies in sync (prefix-normalized) |
| I6 | heading form <-> anchor set |
| I7 | check-manifest-bypass fixture vs the manifest it exists to test |
| I8 | fixture packaging (core/fixtures == install loop == uninstall loop == |
| I9 | every script enforcer declares WHERE it is invoked |
| I10 | fixture hermeticity |
| I11 | the convergence-cycle scope list is DERIVED, not remembered |
| I12 | unregistered-drift scan set is BOUND, not hand-listed |
| I13 | every shipped hook is REGISTERED. install.sh copies core/hooks/*.sh by GLOB, so a |
| I14 | a registered hook must be COMMITTED EXECUTABLE. Registration (I13) proves a hook is |
| I15 | ONE anchor grammar. layer-drift.sh REPORTS a heading-number collision and |
| I16 | runtime-pipeline prose must cite CONSUMER paths, never `core/`-prefixed ones. |
| I17 | apply.sh's runtime composition writes where install.sh writes |
| I18 | ONE bold-anchor rule. The SAME split as I15, one function down. layer-drift.sh |
| I19 | SKILL.md Rule 8's intensity table is the ONLY place the validation-cycle |
| I20 | every fixture is DRIVEN, or declares in writing that it cannot be |
| I21 | ONE home for the reconcile helpers, and nothing may grow a second. |
| I22 | every role has a config entry, and every entry resolves. |
| I22b | the guard reads the blocks the template actually ships |
| I23 | every SHIPPED rule-prose file is in the audit corpus |
| I24 | H1's fixture set stays DERIVED, never restated in gate-validation.md |
| I25 | the core-path derivation is ONE rule, in two places, byte-identical |
| I26 | core-layer-immutability keeps the core set DERIVED, never restated |
| I27 | the in-flight marker is ONE path, written by apply.sh and read by pre-push |
| I28 | layer grain is DECLARED and PARTITIONS the manifest |
| I29 | ai-dlc-update names no helper that is not in reconcile/ |
| I30 | the two pre-push syntax globs are one set, mapped |
| I31 | every scan-marked subtree has a DISPOSITION in register-drift.sh |
| I32 | a Check 17 skill PIN names the skill its own step file invokes |
| I33 | a fixture never reaches a core subtree by walking up from a RESOLVED script |
| I33b | the same walk, with a VARIABLE in between |
| I33c | a SELF-ROOTED walk must name BOTH layouts |
| I34 | ONE rule grammar. The SAME split as I15, in the RULE namespace. |
| I35 | H1's fixture criterion states I20's contract, not a stricter one |
| I36 | the layer contract is joined to its enforcers, both ways |
| I37 | no prose-only clause. A clause must name a level, an enforcer and a code. |
| I38 | the layer contract is joined to its enforcers, both ways |
| I39 | the ledger status vocabulary is one set across emitter and rulebook |
| I40 | ONE reading of an anchor, across the linter and the pull classifier |
| I41 | a clause id is unique. |
| I42 | no clause is introduced at a contract_version the contract has not reached. |
| I43 | the consumer machinery home is ONE string across every surface |
| I44 | core never reads, never writes and never overwrites the home |
| I45 | core allocates below the reserved consumer band |
| I46 | the extension kind vocabulary is one set |
| I47 | ONE check-heading grammar, across the linter and the manifest resolver |
| I48 | the generated-region name is READ by both its writer and its reader |
| I49 | every core-paths.sh MODE a rule file tells someone to run actually exists |
| I50 | every scripts/ai-dlc/<script> a shipped file names is one core actually ships |
| I51 | the one commit Step 5b licenses has ONE subject across the schema and the step file |
| I52 | the drivability exemption marker is ONE string, and the second reader |
| I53 | the escalation-citation modes one core script asks another for actually exist |
| I54 | no shell variable is written into an EARLY-EXITING reader |
| I54b | nor does any PIPELINE, where the status is load-bearing |
| I55 | what the suite's content key does NOT cover stays uncovered |
| I56 | the model pin is ONE rule across the dispatch guard and the gate |
| I57 | a check that tells the lead an exit code decides it names its enforcer |
| I58 | the ADJUDICATED level is one token across the contract and the enforcer that acts |
| I59 | every mode a shipped script DISPATCHES is named in that script's own prose |
| I60 | every MODE one shipped file names on another shipped script is dispatched there |
| I61 | the prose home states the SAME SEVERITY the contract declares. |
| I62 | prose that NAMES a contract code cites the clause that claims it. |
| I63 | the contract PINS the files it absorbed, and each one still is what it says. |
| I64 | every clause's code reaches an ATTRIBUTABLE EMISSION SITE in its enforcer. |
| I65 | every clause names the FIXTURE that proves it, and that fixture can prove it. |
| I66 | ONE fixture-suite runner across both pre-push hooks |
| I67 | the crosswalk file is ONE string, and no reader restates it |
| I68 | core's own shipped files yield ZERO crosswalk rows |
| I69 | prose naming the declaration's HOME must name a file that carries it |
| I70 | the PR-class taxonomy is declared once and derived by every reader |
| I71 | no sed or grep expression uses a bracket class containing \t |
| I72 | the PR-class grammar is ONE key set across the parser and the template |
| I73 | the derivable story-field list is declared once and derived by every reader |
| I74 | install.sh DERIVES the ship set, and every `.dist-only` says why |
| I75 | a validator that consults a project root consults it through ONE block |
| I76 | every flat skill-root file is shipped AND claimed, or declared not-shipped |
| I77 | every shipped shell file is EXECUTABLE in git |
| I78 | the copyable example declares the CURRENT contract version |
| I79 | every rule below the re-attach cut declares what CARRIES it |
| I80 | an enumeration of the intensity SET names every member of it |
| I81 | the live adversarial series is derived ONE way, in both hooks |
| I82 | core's own artifact-path prescriptions obey core's own grammar |
| I82b | a DIRECTORY core prescribes under an area spells the sprint slot |
| I83 | the grammar's blocks have exactly ONE reader |
| I84 | the story corpus location is ONE declaration |
| I85 | no shipped script command-substitutes inside its own operator message |
| I86 | the adjudication row token and the keep-verdict name are resolved, never restated |
| I87 | a fixture cannot inherit a consumer's AI_DLC_* tunable and test the CONFIG |
| I89 | the procedure citation join, and the fix-imperative attribution |
| I90 | the procedure citation join, and the fix-imperative attribution |
| I91 | harness-origin prefixes are ONE declaration, never a second copy |
| I92 | the transcript-corpus predicate is one rule in four copies, byte-identical |
| I93 | an "examined nothing" verdict is ONE token across every emitter of it |
| I94 | the pause branch text and the handoff-intent PATTERNS are ONE declaration |
| I95 | every pipeline state path is CLASSIFIED transient or durable, in one place |
| I96 | the adversarial cycle's stopping rule is a VERDICT, never a pass count |
| I97 | only validate-locked-anchor.sh may MATCH a LOCKED_REQUIREMENTS marker |
| I98 | every hook that emits additionalContext marks it, and only the library spells the |
| I99 | a placeholder in a prescribed BASENAME that CONCEALS a sprint |
| I100 | no step file prescribes a BARE `git push` |
| I101 | the adversarial exit ceiling is ONE number, in the enforcer and in the role |
| I102 | a rotation destination is spelled the grammar's way, never as a dated archive |
| I103 | the operator-citation PARSER is one rule in four copies, byte-identical |
| I104 | the snapshot sprint_id READER is one expression in three copies |
| I105 | every reconcile detector is DRIVEN into the report region or declared exempt |
| I106 | a SHIPPING fixture never resolves its root by walking for VERSION (I33 family) |
| I107 | the in-force query Check 26's validator asks its sibling for is a mode that sibling dispatches |
| I108 | the derived-fence grammar is taught in ONE passage, and its EXAMPLE is what the reader accepts |
