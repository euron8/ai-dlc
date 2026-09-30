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
