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

   Detect
   with `git remote`, `git symbolic-ref -q HEAD` and the ahead/behind count. The
   working tree is NOT inspected here, since a dry-run only reads; step 6 refuses
   a dirty tree before `apply`.

   A branch flagged UN-SYNCED this way, one whose step-1
   auto-push failed, continues to the dry-run and no further: step 2 defers
   rather than cutting a branch, and step 6 holds `apply` back.
2. **Self-update.**

   On a branch step 1 left
   UN-SYNCED, the self-update defers: it never cuts its branch, never writes the
   slice and never advances the stamp, and says in one line why.

   - **Run the self-update
     cycle autonomously:** cut the branch, write the slice, commit, run the
     fixtures, push and auto-merge. When no remote exists, commit locally and say
     so. A push that fails is handled below and never leaves a commit behind.

     A push that fails
     here discards the cycle. Stage by pathspec only, naming each file this
     cycle wrote; never `git add -A`. Then `git checkout <original-branch>`;
     `git diff --name-only <original-branch> <self-update-branch>`; only if
     each name is one this cycle wrote, `git branch -D <self-update-branch>`;
     otherwise refuse, name the branch and stop. Say step 2 deferred, treat the
     branch as UN-SYNCED, and leave the stamp unchanged.

6. **Isolate — branch before ANY write (apply only, MANDATORY).**
   - Shell to git in the consumer tree. If it is not a git repo, STOP and tell
     the operator.
   - Re-confirm the step-1 git
     preflight before cutting the branch. Nothing is pushed from this bullet.
     Fetch, then recount ahead/behind; when the branch is not in sync, or step 1
     or step 2 marked it UN-SYNCED, refuse `apply` with the counts and the remedy, which is
     `git push -u origin <branch>` for an upstream-less branch or a pull/rebase
     otherwise, and have the operator re-invoke.
   - `git checkout -b ai-dlc-update/<theirs-version>-reconcile-<ts>` off the
     current branch.
