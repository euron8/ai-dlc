# Batch 177 — backlog release contracts, built to the adversary stage and then stopped

**A RECORD, not a plan.** Batch 177 scoped these eight releases from a whole-backlog adjudication, ran
contract adversaries on them, and stopped them unbuilt when the operator put the consumer's sprint-315
filings first. Only R4's adversary findings are folded in; R1, R2+R3 and R5-R8 were stopped before
their adversaries reported. BL-390 moved into 0.674.0 and shipped there. Every line is a hypothesis
about the tree at `144c41b8`; re-derive before building from it. Scratchpad paths named below no longer exist.


---

## Batch 177 — rules every contract inherits

Repo: /Users/n8/git/ai-dlc, base origin/main 144c41b8 (VERSION 0.673.0). /Users/n8/git/graph is READ ONLY.

- A fix commit names NO `PC-` id. The release commit (lead's) names closed ids.
- Builders never write `**LANDED` annotations; they add a line `Held note (batch 177): <what shipped>` inside the entry. The post-merge close commit annotates and rotates.
- Every entry closed gets a replacement `verify: sh` receipt scored four ways and reported: tip (must exit 1), fix (0), and two plausible wrong fixes (each must exit non-zero). Exit 9 = precondition moved.
- Every behaviour change gets fixture arms plus at least one mutant per arm, in the fixture that already owns the subject. Assert VALUES, not row counts.
- A new fixture directory needs `.claude/rules/fixture-ship-decl.md` read first.
- Bootstrapping = any path under `core/skills/ai-dlc-update/`. Each bootstrapping release touches only the files its contract names.
- No hand runs the fixture suite or `.githooks/pre-push`; running ONE fixture as `bash core/fixtures/<name>/run.sh` from the repo root is fine. A hand touching hooks runs `bash scripts/validate-enforcement-map.sh` before reporting.
- Never run `rm -rf` on a variable path; build each scratch copy into a fresh `mktemp -d` under the scratchpad and do not delete it; anything that must be cleared names a literal absolute path.
- Never run a bare `git config`. Never `git stash`.
- Tool shell is zsh: run loops through `bash`. bash is 3.2 (no mapfile, declare -A; empty array under set -u errors).
- Findings as TEXT in the final message, never a report file. Report branch name and every commit sha.

---

## R1 — non-bootstrapping release (0.674.0 candidate)

Touches no path under core/skills/ai-dlc-update/. Also carries the operator's read-set trace (`.ai-dlc-fixture-readsets.tsv`, already modified in the main checkout) in its first commit.

## BL-390 (operator-ruled remedy): NOMATCH-TRANSCRIPT-PRUNED
- File: core/scripts/validate-steering-budget.sh, node `--cite` block, final NOMATCH path (~:704-705).
- New stdout token `NOMATCH-TRANSCRIPT-PRUNED`, exit 2 unchanged. Emitted only when the verdict would be plain NOMATCH AND (1) the answers log `_bmad-output/operator-answers-history.md` (written by core/hooks/ai-dlc-answer-capture.sh:231-240) has an entry whose fenced body, normalised as the needle is, contains the needle; AND (2) that entry's `- Session: <id>` names no `<id>.jsonl` ON DISK in the corpus dir (disk, not the `--since`-filtered scan list).
- Log resolution: `CLAUDE_PROJECT_DIR`, else walk up from cwd for the marker set `ai_dlc_resolve_root` uses; if unresolvable, one stderr line saying the pruned-check was skipped.
- Readers (verified unchanged): validate-adversarial-convergence.sh:1171 exact-compares `NOMATCH-NO-RECORDS` so the new token denies (correct); validate-escalation-resolution.sh:445, validate-gate-adjudication.sh:638, ai-dlc-gate-remediation-guard.sh:856/:1072 read status only.
- Receipt: draft at scratchpad/r390.sh (tip 1, prototype 0, wrong-A quote-anywhere 1, wrong-B since-filtered 1). Add: a call with CLAUDE_PROJECT_DIR unset from a subdirectory. Fixture: add a pruned-session world to core/fixtures/askuserquestion-citation.
- File a NOTE (held for close commit, do not file in release): the `--cite` stdout vocabulary has no owner in docs/vocabulary-index.md.

## BL-083: the rule names the wrong root marker
- Edit .claude/rules/verification-discipline.md "Resolve the repo root by walking up for a marker": name `ai_dlc_resolve_root()` (core/scripts/validate-provenance-block.sh:138) and its marker set, and state VERSION exists only in the distribution. Check the rulebook byte ceiling (scripts/validate-claude-rules.sh arm A6) still passes.
- Close the entry's population claim as refuted with the measurement (32 `/VERSION"` hits are seed trees; 4 shipping fixtures PASS in an installed layout).
- Replacement receipt keyed on the rule line (the old one can never pass).

## BL-159 claim 4 only: HANDOFF_ON_DISK is unreachable without a transcript
- core/hooks/ai-dlc-continue.sh: `HANDOFF_ON_DISK` set at :421, all readers (:471, :817, :818) inside the `-f "$TRANSCRIPT"` block (:430-:919). Hoist the handoff arm so it fires with no transcript. Claim 1 (push check ignores working tree) stays open, FP set unmeasured. Entry stays PARTIAL.
- Run bash scripts/validate-enforcement-map.sh.

## BL-093 partial: declare the unbounded logs
- One header line "LOG — unbounded by design; rotation does not apply" in CHANGELOG.md and in the readsets TSV's generator header (core/scripts/derive-fixture-readsets.sh emits it — change the EMITTER, then the operator's next trace re-renders; do not hand-edit the TSV beyond what the generator would write). docs/context-hardening-notes.md gets the same LOG header (operator ruling: log, not queue), so BL-093 closes.

## BL-381: layer-adjudication-tier Part 11 world E packed-store flake
- Add `-c gc.auto=0` to the P11 world's git calls, or export GIT_CONFIG_PARAMETERS-equivalent in that world only. Do not touch preamble.sh globally unless the adversary shows a second world needs it. Entry closes only with a note that the cause was not reproduced; if that is not a close, keep it open with the mitigation recorded.

## BL-375 smallest buildable step
- core/scripts/derive-fixture-readsets.sh: add `--tracer both` that runs fs_usage and sandbox in one pass per fixture and prints the per-fixture miss-set diff outside `.git/**` and gitignored paths, writing no map. Entry stays open for the operator's sudo run, which is now one command.
- THE INTERFACE IS FIXED — the operator has already been given this exact command to schedule, so build to it and do not rename anything:
  `sudo bash core/scripts/derive-fixture-readsets.sh --all --tracer both`
  It must: accept `--tracer both` alongside `--all` and `--list`; NEVER write `.ai-dlc-fixture-readsets.tsv` in that mode (assert the file's md5 is unchanged, in the fixture); print one line per fixture with the two miss counts, then a closing verdict line `SANDBOX-MISSES-NOTHING` or `SANDBOX-MISSES <n> path(s) across <m> fixture(s)`; exit 0 on the first, 1 on the second, 2 on a refusal (e.g. not root, a `log stream` drop — name the dropped fixtures). It refuses in a linked worktree exactly as the existing modes do.

## Operator rulings recorded this batch (for the close commit, not for builders)
- BL-132: leave it this batch (operator took the recommendation).
- BL-093: docs/context-hardening-notes.md is a LOG, unbounded like CHANGELOG — so BL-093 CLOSES in R1 with the header on all three files, not partially.
- BL-007: stays open for the archive-interior hole. BL-390: distinct verdict (this contract).

## BL-360 strike
- Strike the carried DEFECT bullet (bad theirs ref disarms tier at rc 0): shipped as BL-370 in 0.664.0 (layer-drift.sh:290, :690). Edit only the backlog entry.

---

## R2 — lib.sh + preclassify.sh (bootstrapping)

Files: core/skills/ai-dlc-update/reconcile/lib.sh, core/skills/ai-dlc-update/reconcile/preclassify.sh. Nothing else under core/skills/ai-dlc-update/.

## BL-374: a missing subtree is cached as ABSENT
- lib.sh:966-969 `_ai_dlc_memo_absent` uses `rev-parse -q --verify`, so a failed lookup is recorded as absent (receipt: p1=128 p2=128). Rewrite to the `ls-tree --full-tree` rule (empty output with rc 0 = absent; rc != 0 = failure, never cached). Apply the same rule to preclassify.sh's MISSING bucket via memo_rev_parse. Add a preclassify cell to the receipt.

## BL-310 lib half: memo_has_path returns 128 for "present but unreadable"
- lib.sh:1065. When the memo says present but `cat-file -e` fails, return 125 (distinct failure). NOTE ledger-reverify.sh:1935 currently reads any non-zero as absent; its refusal arm for 125 ships in R3 (ledger-reverify release), which runs AFTER this one. So in R2 the observable change in ledger-reverify is none; state that in the entry. BL-310 closes on R3.

## BL-355: case fold is ASCII-only; IFS NOTE
- norm_lines: fold case in the caller's locale only when `iconv` validates the stream; spell PIPESTATUS as an array (IFS=$'\n' breaks `return`). Measured reach today: 0 rulebook files with a non-ASCII capital (23 with an em-dash) — state it, ship anyway.

## BL-100: a mode-only change in --untangle reads ALREADY-AT-THEIRS
- preclassify.sh:460 compares content only. Add a mode conjunct reading the mode at $BASE (mode_at_theirs at :391 cannot be reused: base==theirs in --untangle). Route content-equal-mode-differs to the bucket the non-untangle arm uses for the same case (:703, content at theirs but bit not -> UPSTREAM-ONLY, apply delivers the bit). Adversary: confirm UPSTREAM-ONLY is correct in --untangle's caller, or name the right existing bucket.
- BL-364: if any site touched here is one of BL-364's 29 unquoted listing sites, flip it only with every join that reads it; otherwise leave BL-364 alone.

---

## R3 — ledger-reverify.sh (bootstrapping). Ships after R2.

File: core/skills/ai-dlc-update/reconcile/ledger-reverify.sh only.

## BL-092: receipt_absent_subjects splits rev-specs into bogus paths
- :789 split drops `:`; :863 prefix whitelist admits docs/*, so `$THEIRS:docs/backlog.md` yields `bad=' docs/backlog.md'`. Strip rev-spec tokens (`$THEIRS:`, `${THEIRS}:`, `<sha>:`) before splitting in receipt_absent_subjects (:855); correct the stale comment at :773-774. Existing receipt is bidirectional; keep it.

## BL-066: named_ambiguous emits entry count, not commits
- :697-701 returns `<newest sha> <entry count>`. Emit `<n> <sha,sha,…>` like named_absorbed (:641-651) and update the row message at :1872. Receipt must be REPLACED: the current one tests `$1 = "0.3.0"` and field 1 is now slug/prefix, so it rejects the correct fix. Fixture arms: core/fixtures/ledger-reverify/run.sh:1538-1558 must assert the commit count and list, not only presence.

## BL-145: NAMED-UPSTREAM fires on docs-only commits
- :611 bare `log -F --grep`. The fix the entry names: a naming commit counts toward NAMED-UPSTREAM only if it touches core/ (or the consumer-mapped machinery set); a docs-only mention emits a distinct NOTE, never NAMED-UPSTREAM. Re-derive the anchor table (S295 docs-only 1/0; S336, S312, S305 now 2 commits with 1 touching core; S334 and S340-SAFE-STOP docs-only). Replace the receipt (half its table has moved). Interaction with BL-066: both change named_* output; the adversary must check the two together.

## BL-310 ledger-reverify half
- :1935 `if ! theirs_has_path` treats R2's new 125 as absent and retries by basename. Add a refusal arm: 125 -> refuse the row (NEEDS-REVIEW / explicit unreadable), never the basename retry. Closes BL-310 with R2.

---

## R4 — apply.sh (bootstrapping). ADVERSARY FINDINGS FOLDED.

File: core/skills/ai-dlc-update/reconcile/apply.sh, plus core/skills/ai-dlc-update/SKILL.md ONLY for the one-sentence disposition line at ~:1788 if BL-119's new kind needs it (NOTE; optional). Owning fixtures: apply-legacy-script-path (BL-099), a finisher fixture for BL-103 (find the one that drives `--finish` with hook_registration_row), apply-drift-after-write (BL-119), apply-drift-refile (BL-336). EVERY new fixture arm needs a SKIP branch when its subject is absent (pattern: apply-drift-refile/run.sh:182) — the fixture reaches a consumer one pull ahead of the code.

## BL-099: exec-bit mirror arm
- Audit at :1718-1730 keeps only 100755. Add the mirror: 100644 blobs whose consumer copy is -x. FP set measured on graph at THEIRS=144c41b8: 0 of 170 present (control: 0 of 380 in the 100755 direction; -x test proven live).
- NEW row kind (not `not-executable`, whose message at :1735-1736 says "upstream ships this 100755"). Remedy text: `chmod -x <path>`; do NOT say "re-run". Count it into mech_fail (consistent with preclassify.sh:396, which treats 100644+exec as not-at-theirs). State in the entry that `--finish` skips the audit either way.
- Receipt + fixture seeds in apply-legacy-script-path: (i) 100644 chmod +x is NAMED under the new kind; (ii) a non-exec 100644 sibling is NOT named; (iii) 100755 chmod -x still named under the old kind. Wrong fix 1 (`$1=="100755"||$1=="100644"` with the old `[ -x ] && continue`) names every non-exec 100644 -> killed by (ii). Wrong fix 2 (inverted test) killed by (i). A mutant per seed.

## BL-103: unregistered ai-dlc-* hook wedges --finish
- The row STAYS GATING. (A non-gating row lets --finish stamp while the consumer's pre-push, core/git-hooks/pre-push:227-229 -> validate-hook-registration.sh, stays red.)
- Partition: a hook name NOT in the THEIRS template AND NOT in `${THEIRS}:core/hooks/` gets a NEW WORKLIST kind; anything shipped in core/hooks keeps the existing row (I13's subject; the three sourced libs ai-dlc-context-provenance.sh, ai-dlc-handoff-pending.sh, ai-dlc-window.sh are validator-exempt and must not change behaviour).
- Remedy names three exits: (1) delete the file; (2) rename it out of the `ai-dlc-` namespace; (3) register it in `.claude/settings.local.json` (validator counts it at :286-287; settings-merge.sh never touches it). Note: settings-merge.sh:179-187 strips ai-dlc-* blocks from settings.json, which is why exit 3 must name settings.local.json.
- No change to settings-merge.sh.
- Receipt: finisher world with such a hook -> --finish withholds and emits the new kind; apply remedy exit 3 (or 1), re-run --finish -> stamp written; control: an unregistered hook the template DOES carry still withholds under the old row.

## BL-119: adjudicated non-keep verdict emits no actor
- At :1266-1270 (extension loop): for `retire` AND `contradicts-core`, emit a NOTE-severity row (NOT WORKLIST — graph has 5 live extension files with already-executed section-grain retirements that a gating row could never clear).
  - retire text: "delete the entry per Rule 27(b), or cut the retired section; either edit respends the digest."
  - contradicts-core text (LC-E5, extensions/README.md): "refile the entry as an override with a base_sha, or edit it."
- still-additive (ADJ_KEEP_VERDICT) keeps today's `NOTE extension-adjudicated`.
- Fixture apply-drift-after-write: add `retire` and `contradicts-core` seeds as separate cases asserting kind AND named actor text; mutant deleting the ADJ_KEEP_VERDICT comparison in the extension loop; mutant swapping the two verdict texts.
- Receipt must reject the INVERTED fix (remedy on still-additive, not on retire): assert per-verdict output, not "retire output differs from keep output".
- Optional: one sentence at update SKILL.md ~:1788 on disposing the new kinds.

## BL-336: staging-failed remedy at :958
- Premise correction: :931-933 name no procedure. In BL-336's state the stamp is withheld at BASE, so a bare re-run is refused at :301.
- Pick by MEASUREMENT, not argument: force the state (unwritable TMPDIR -> AP_TMP empty at :465 -> staging-failed at :952/:957) in apply-drift-refile, then follow each candidate remedy — (a) re-run dry run at THEIRS, re-approve, apply, per :301; (b) refile by hand then run the `--finish` command the restamp-withheld row at :1925 already prints — and ship the text of whichever advances the stamp (if both, prefer (b): matches every other DECISION row). Report both outcomes.
- Replace `verify: manual` with a `verify: sh` receipt that follows the shipped remedy and asserts the stamp advances.
- Same-kind siblings at :1526 and :1736 ("chmod +x and re-run"): fix only if the measurement shows the same defect; otherwise report as a NOTE.

---

## R5..R8 — four single-file bootstrapping releases

Each ships alone, in this order after R4: R5, R6, R7, R8.

## R5 ledger-rotate.sh — BL-006 consumer half
- core/skills/ai-dlc-update/reconcile/ledger-rotate.sh has no ledger size ceiling. Add an entry-count refusal (or WARN — adversary to decide which is safe on a consumer whose ledger is legitimately large; the consumer's live ledger today has 15 live headings, archive ~290). Replace C8 of the receipt: it is satisfied by any parser limit. Plans half already discharged (P8).

## R6 update SKILL.md — BL-391
- core/skills/ai-dlc-update/SKILL.md:519 "If there is no remote / push fails, commit locally and note it". The pre-push probe (:443-456) already turns a hook refusal into DEFER. Remaining case: transport failure after the hook passed. Remedy: do not keep a local commit that advances skill_version; discard the branch and emit DEFER, matching BL-389's UN-SYNCED marking. Fixture: core/fixtures/update-preflight-push.

## R7 layer-drift.sh — BL-376
- Unguarded base reads at :2091, :2205, :2413 ($BASE) and :1750, :1910 ($base_sha). Gate each on `have "$BASE" "$cp"` (BL-370's refusing reader at :690). Fixture: layer-drift's world with an unreadable base path must refuse, not report clean.

## R8 retired detectors — BL-333
- core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh: delete :330-333 so a shapeless base falls through to :398 (which already decides on both subtractions; :380 covers an unresolvable file). NEW finding: :332 swallows a true retired-path row — a world whose base rulebook has no contract shape and deletes b.md emits 0 rows; with one shape at base it emits 1. Receipt: the shapeless world emits the path row. Also reconcile the comment at :157-159 with the message at :331.
- core/skills/ai-dlc-update/reconcile/retired-tokens.sh:149 exit 0 on base==theirs refusal -> exit 2; emit-report.sh:445 renders exit 2 as DETECTOR-REFUSED; apply.sh:692-700 reads it via detector_refused. Adversary: confirm no caller treats rt's exit 2 as fatal on a legitimate base==theirs run (a no-op pull).
