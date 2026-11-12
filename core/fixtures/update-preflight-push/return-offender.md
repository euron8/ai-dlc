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
     `origin` would strand them; publishing first removes the hazard. **A failed
     push is NOT fatal** (auth, network, protected branch, remote rejected): report
     the exact `git push` error and its remedy in one line, mark the branch
     **UN-SYNCED** for this invocation, and continue — see the UN-SYNCED paragraph
     below for what that state may and may not reach.
   - **Branch AHEAD of its upstream** (unpushed commits) → **AUTO-PUSH**: run
     `git push` to bring `origin` in sync, then proceed. Ahead-only means the
     remote has not moved, so this is a clean fast-forward on `origin` and the
     exact remedy the operator would run by hand. **A rejected or failed push is
     NOT fatal**: report the `git push` error in one line, mark the branch
     **UN-SYNCED** for this invocation, and continue. A rejection because the
     remote advanced between check and push means the branch is now diverged, so
     the remedy to report is the diverged one — pull/rebase, then re-invoke.
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
   operator knows what to run, then re-invoke. A branch in sync with its
   upstream — reached directly or via the auto-push — is the only state that
   proceeds to step 2's push or to `apply`. **Step 1 does not check the working
   tree**, because it runs on every bare dry-run and a dirty tree does not make a
   read-only report wrong. A dirty tree is refused for `apply` at step 6, and step 2
   never commits a path it did not write: it stages by explicit pathspec, so an
   uncommitted consumer edit is never swept into the self-update commit.

     commits it. The restored directory is
     carried whole to the step-7 gated apply under the ONE-UNIT rule. This re-runs the wrapper,
     not the gate, so the rule against re-running the gate on the written tree still holds. The
     HOOK-REFUSED sequence with `SELF-UPDATE-DEFER` remains a safe fallback.
   - **Then STOP this invocation and re-invoke `/ai-dlc-update` automatically —
     do NOT ask whether to.** The self-update landed, but THIS invocation is
     still executing the PRE-update logic — its reconcile/classify/apply behavior
     is stale, and an in-flight agent cannot hot-reload its own instructions. So
     do NOT proceed to step 3 on stale logic. Instead: report in one line that
     the self-update landed (merged PR ref) + what changed (`reconcile/` — the
     engine — vs prose/docs), then **immediately re-invoke the `ai-dlc-update`
     skill (Skill tool), carrying the operator's original arguments IN FULL** — a
     bare run re-invokes bare (fresh dry-run), an `apply` run re-invokes `apply`,
     and **a run that named a `<ref>` re-invokes with that same `<ref>`**. The
     fresh invocation loads the updated logic and runs the reconcile on it.
   - **Open a PR** into the working branch (`gh pr create`), body = the reconcile
     report summary (buckets, conflicts, push-candidates).
   - **Merge ONLY on explicit operator approval of the PR.** This is a second,
     independent gate — separate from the `apply` arg that authorized the write.
     The skill does NOT auto-merge. None of the following authorize a merge: zero
     conflicts, a clean diff, the `apply` arg already given, or inferred intent.
     Present the PR and wait for the operator to approve it.
     If you hold the advisor tool, call it in a message of its own before `gh pr merge`.
     Only then merge
     (squash, delete branch). On merge, the re-stamp + log + changes reach the
     working branch.
9. **Safety.** Three independent recover layers: the step-6 reconcile **branch**
   (the working branch is never touched), the consumer's
   `docs/pre-ai-dlc/<ts>/_divergence/` archive (written by install), and the
   dry-run report. Nothing is destroyed without an operator confirm.

