   **Git preflight — the consumer branch must be in a reconcilable state.**
   Shell to git in the consumer tree and check the current branch BEFORE the
   self-update (step 2) or any apply. This runs on EVERY invocation: step 2's
   autonomous push→auto-merge writes to `origin` even on a bare dry-run, and
   steps 6–7 cut the reconcile branch off the current branch. If the current
   branch does not match `origin`, cutting a reconcile/self-update branch off it
   and merging that to `origin` diverges local from `origin` the instant it
   merges, and the NEXT update then reconciles against a base that no longer
   matches `origin` — the repeated-reconciliation this check exists to prevent.
   - **Not a git repo** → STOP; no safe isolation (same as step 6).
   - **No remote configured** (`git remote` empty) → non-blocking note; the
     origin-sync guarantees below do not apply. Proceed — step 2 falls back to
     its commit-locally path.
   - **Detached HEAD** → STOP; there is no branch to track or return to.
   - **Remote exists but the current branch has no upstream** (never pushed) →
     **AUTO-PUSH**: run `git push -u origin <branch>` to publish it, then proceed.
     Its commits are absent from `origin`, so a branch cut off it and merged to
     `origin` would strand them; publishing first removes the hazard. If the push
     fails (auth, network, protected branch, remote rejected) → STOP and report
     the exact `git push` error and remedy; do not proceed on an un-synced branch.
   - **Branch AHEAD of its upstream** (unpushed commits) → **AUTO-PUSH**: run
     `git push` to bring `origin` in sync, then proceed. Ahead-only means the
     remote has not moved, so this is a clean fast-forward on `origin` and the
     exact remedy the operator would run by hand. If the push is rejected
     (e.g. the remote advanced between check and push, making the branch actually
     diverged) or otherwise fails → STOP and report the `git push` error; the
     branch is then no longer ahead-only and needs a pull/rebase first.
   - **Branch BEHIND its upstream** → STOP; fast-forward/pull first, so the
     reconcile runs against current `origin`, not a stale local base. (Not
     auto-resolved: a pull can conflict and is not a push.)
   - **Diverged** (both ahead and behind) → STOP; operator pulls/rebases first.
     (Not auto-resolved: a rebase/merge can conflict; a bare push would be
     rejected.)

   Detect with: `git remote` (empty → no remote); `git symbolic-ref -q HEAD`
   (fails → detached); `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
   (non-zero exit → no upstream on this branch); and
   `git rev-list --left-right --count @{u}...HEAD` (prints `<behind>\t<ahead>`).
   For the two push-resolvable states (no-upstream, ahead-only) auto-push and
   report what was pushed in one line; for BEHIND/DIVERGED put the exact
   ahead/behind counts and the `git pull`/rebase remedy in the STOP so the
   operator knows what to run, then re-invoke. A clean tree on a branch in sync
   with its upstream — reached directly or via the auto-push — is the only state
   that proceeds.

6. **Isolate — branch before ANY write (apply only, MANDATORY).** The reconcile
   MUST NOT mutate the consumer's live branch in place. Before the first write
   in step 7:
   - Shell to git in the consumer tree. If it is not a git repo, STOP and tell
     the operator (no safe isolation possible).
   - If the working tree has uncommitted changes that would tangle the reconcile
     diff, STOP and report — let the operator stash/commit first. (A dirty tree
     unrelated to the rulebook may be fine; when in doubt, stop.)
   - Re-confirm the step-1 git preflight still holds: the branch is in sync with
     its upstream. Time may have passed since the dry-run, so if the branch has
     since drifted AHEAD of `origin` (or gained an upstream-less state),
     **auto-push** to re-sync exactly as in step 1 and continue; if it drifted
     BEHIND or diverged, STOP with the `git pull`/rebase remedy — the reconcile
     branch cut here must sit on a base that matches `origin`.
   - `git checkout -b ai-dlc-update/<theirs-version>-reconcile-<ts>` off the
     current branch. ALL step-7 writes land here, so the operator reviews a
     clean diff / opens a PR — never a silently-mutated working branch.
   This is a hard requirement, symmetric with the pipeline's own branch-per-unit
   discipline; the `_divergence/` archive (step 9) is a backstop, not a
   substitute for the branch.

   - **Run the self-update cycle autonomously:** cut a dedicated branch
     `ai-dlc-update/self-update-<theirs-version>-<ts>`, write from `theirs` **only the paths
     that diff names AND that survived both subtractions above** — never a path carried by a
     `SELF-UPDATE-CARRY` row — each at the consumer destination `map_consumer()` gives it, and
     `tests/fixtures/<dir>/` for the covering fixtures — never the derived set per
     directory, **update the stamp's
     `skill_version`/`skill_commit` to `theirs`** (rewrite the stamp in schema,
     preserving `version`/`commit`/`installed_at`/`upstream`), commit
     (`chore(ai-dlc-update): self-update <base-skill-ver> → <theirs-ver>`) — **including the
     gate record and the fixture log, which are this cycle's approval artifact** — **run the
     derived fixtures through
     `reconcile/self-update-fixtures.sh <dist> <base> <theirs> <consumer> <fixture>...`
     — each `<fixture>` is a bare fixture DIRECTORY NAME, one per argument; the
     `core/fixtures/<name>` and `tests/fixtures/<name>` forms this step derives the set in are
     also accepted, with or without a trailing slash, and the runner logs each rewrite. Any
     other slash form, and any single argument holding more than one name, is refused —
     **word-split the derived list explicitly**, because an unquoted variable holding a
     newline-joined list arrives as ONE argument under zsh —
     **and require green BEFORE the push**, push,
     open a PR, and **auto-merge (squash, delete branch)** — no operator gate (the
     step-1 git preflight confirmed the branch is in sync with `origin`, so this
     merge cannot strand local commits). If there is no remote / push fails,
     commit locally and note it; do not block the run. Advancing `skill_version` here is what keeps the stamp an honest record
     of the installed tool version — it is bookkeeping tied to the (already
     autonomous) self-update, and never touches `version`/`commit` (the rulebook
     base stays put until a gated apply).
