   **Git preflight.** Check the current branch before step 2 and before any apply.
   - **Not a git repo** → STOP; no safe isolation (same as step 6).
   - **Remote exists but the current branch has no
     upstream** (never pushed) → **AUTO-PUSH** with `git push -u origin <branch>`.
     A push that is refused or fails does NOT stop the run: say so in one line
     with the error text and what to run, flag the branch UN-SYNCED, and keep
     going; the dry-run still completes and step 6 holds `apply` back.
   - **Branch AHEAD of its
     upstream** (unpushed commits) → **AUTO-PUSH** with `git push`. When the
     remote rejects it, or it fails otherwise, that is a report line and not a
     halt: record UN-SYNCED and carry on to the dry-run. A rejection caused by
     the remote moving means the branch has diverged; name pull/rebase as the fix.
   - **Branch BEHIND its upstream** → STOP; pull first, then re-invoke.
   - **Diverged** (both ahead and behind) → STOP; rebase first, then re-invoke.

   A branch flagged UN-SYNCED this way, one whose step-1
   auto-push failed, continues to the dry-run and no further: step 2 defers
   rather than cutting a branch, and step 6 holds `apply` back.
2. **Self-update.**

   On a branch step 1 left
   UN-SYNCED, the self-update defers: it never cuts its branch, never writes the
   slice and never advances the stamp, and says in one line why.

6. **Isolate — branch before ANY write (apply only, MANDATORY).**
   - Shell to git in the consumer tree. If it is not a git repo, STOP and tell
     the operator.
   - Re-confirm the step-1 git
     preflight before cutting the branch. Nothing is pushed from this bullet.
     Fetch, then recount ahead/behind; when the branch is not in sync, or step 1
     marked it UN-SYNCED, refuse `apply` with the counts and the remedy, which is
     `git push -u origin <branch>` for an upstream-less branch or a pull/rebase
     otherwise, and have the operator re-invoke.
   - `git checkout -b ai-dlc-update/<theirs-version>-reconcile-<ts>` off the
     current branch.
