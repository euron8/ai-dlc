<!-- return-wrong.md: the present-but-wrong seed. return-nearmiss.md with one clause per R arm altered (R1 the ON-DISK test, R2 a bare --delete-branch, R3 a widened grammar, R4 the PR base), plus two R1 shapes no single-line removal holds: an ADDITIVE filter after sort -zu and a REORDER that runs the DELETE before the remote-tip lookup. Every R unit is present. -->
1. **Preflight (near-miss seed for arms R1-R4, a respelled correct text).**
   - **No remote
     configured** (`git remote` empty) → a note, then proceed. On a skill branch there is
     no PR to read: STOP, name the branch, and give the local merge remedy: step 8's RETURN
     PROCEDURE in its ABANDON form to `<cut-from>`, then `git merge --ff-only <skill-branch>`.
   - **Current branch is a skill
     branch** — its name matches
     `^ai-dlc-update/[a-z0-9.-]+`; an
     operator-named branch such as `ai-dlc-update/pc-update-deliver-no-return-20261111` does
     not match and makes no `gh` call. On a match run
     `gh pr list --head <b> --state all --json number,state,baseRefName,headRefOid,isCrossRepository --jq '.[]|select(.isCrossRepository|not)|[.number,.state,.baseRefName,.headRefOid]|@tsv'`
     and apply four ordered tests. (1) A row in state `OPEN`: STOP with "merge or close it,
     then re-invoke from this branch", and never check out the base yourself.
     (2) The distinct `baseRefName` set of the `MERGED` rows holds exactly one branch, which does
     not match the skill-branch grammar. (3) `git rev-parse HEAD` is equal to the `headRefOid`
     of a `MERGED` row. (4) When the reflog gives the branch this one was cut from, the row's
     `baseRefName` equals it; otherwise STOP naming both, and
     offer step 8's RETURN PROCEDURE to that `baseRefName` or its ABANDON form, running neither.
     When (2) and (3) both hold and (4) passed, run step 8's RETURN PROCEDURE for that PR, then
     STOP this invocation and re-invoke `/ai-dlc-update` with the original arguments.
     Any other result (no rows, several bases, a skill-branch base, a tip matching no head, or
     `gh` failing) is a STOP naming the branch and the rows; it reads
     `.claude/.ai-dlc-applying` to say whether an apply is unfinished and runs no continuation.
     The branch it was cut from: in `git reflog --format=%gs`,
     take the OLDEST line that begins with `checkout: moving from ` and ends with the fixed string ` to <skill-branch>`, with
     `git reflog --format=%gs | awk -v s=" to <skill-branch>" 'index($0, "checkout: moving from ") == 1 && length($0) > length(s) && substr($0, length($0) - length(s) + 1) == s' | tail -1`.
   - **Remote exists but the current branch has no upstream** → AUTO-PUSH with
     `git push -u origin <branch>`.
   - **Branch AHEAD of its upstream** → AUTO-PUSH with `git push`.

2. **Self-update.**

     **A push that fails
     here discards the cycle.** On a `TRANSPORT` exit, make the next move as step 8's RETURN
     PROCEDURE in its ABANDON form to `<original-branch>`: the checkout on the next line is that
     form's (d), run once; if the check prints a line, ABANDON STOPs and so does this invocation.
     run `git checkout <original-branch>`;

     **On a `HOOK-REFUSED`
     exit the branch is discarded the same way.** make the next move as step 8's RETURN
     PROCEDURE in its ABANDON form to `<original-branch>`: the checkout on the next line is that
     form's (d), run once; if the check prints a line, ABANDON STOPs and so does this invocation.
     run `git checkout <original-branch>`;

   - **After the auto-merge, return the
     checkout before the re-invoke.** Merge with
     `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>` (never a bare
     `--delete-branch`). Next, then run step 8's RETURN PROCEDURE for that PR. With no remote
     configured there is no PR: run step 8's RETURN PROCEDURE in its ABANDON form to
     `<original-branch>`, then `git merge --ff-only <self-update-branch>`. Any STOP the
     procedure raises stops the re-invoke as well. When the PR is not `MERGED`, say the
     self-update is not merged, not that it landed, and do not re-invoke. Open it with
     `gh pr create --base <original-branch>`; the return after the merge STOPs when the PR's
     `baseRefName` is not `<original-branch>`.
   - **Then STOP this invocation and
     re-invoke `/ai-dlc-update` automatically.** The self-update landed, so the fresh
     invocation loads the new text.

8. **Deliver.**
   - **The PR's base is named, never
     defaulted:** `gh pr create`, with `<cut-from>` derived from HEAD's
     reflog exactly as step 1's skill-branch bullet states, never remembered. Before
     any merge, refuse to create the PR if `<cut-from>` matches step 1's skill-branch grammar.
   - **The merge command
     is literal:** `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`.
   - **RETURN PROCEDURE: after every merge, return the checkout
     to the working branch.** Each clause reads state first, so a second run is a no-op that
     reports "already on <working> at origin/<working>". (a)
     `gh pr view <n> --json state,baseRefName,headRefName,headRefOid`; `<working>` is the PR's
     `baseRefName` and `<skill-branch>` is the PR's `headRefName`, never a remembered value
     and never `@{u}`. STOP, naming the state and the base, when the state is not `MERGED` or
     when `<working>` matches step 1's skill-branch grammar. (b)
     `git fetch origin "+refs/heads/<working>:refs/remotes/origin/<working>"`; a failed fetch
     STOPs with its error. (c) Next run the working-tree check, a named, self-contained block;
     its output contract is that ANY output line is a STOP:
     ```
     ( cd "$(git rev-parse --show-toplevel)" || { echo "STOP cannot cd to the repository toplevel"; exit; }
       { git rev-parse -q --verify "refs/heads/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD <working>
         git rev-parse -q --verify "refs/remotes/origin/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD origin/<working>; } |
       sort -zu | grep -zv "^tmp/" |
       while IFS= read -r -d '' p; do
         if ! git diff --quiet HEAD -- ":(literal)$p"; then echo "DIRTY $p"
         elif false; then echo "ON-DISK $p"
         fi
       done )
     ```
     For `ON-DISK <path>`: move the file aside. For `DIRTY <path>`: copy the file elsewhere, then run `git restore --staged --worktree -- <path>`;
     no commit clears a path, and the procedure never stashes or forces. (d) If not on
     `<working>`, `git checkout <working>` with no `-f`, no stash and no
     `git switch --discard-changes`; if git refuses, STOP with its error and nothing is lost.
     (e) `git merge --ff-only origin/<working>`; on refusal STOP with git's error and the
     `git rev-list --left-right --count origin/<working>...<working>` counts, adding step 1's
     diverged remedy only if ahead is greater than 0. (f) Delete a surviving local skill
     branch with `git branch -D <skill-branch>` ONLY when `git rev-parse <skill-branch>` equals
     the PR's `headRefOid`; otherwise STOP naming it. When the local branch is already gone, print `REMOTE-KEPT <skill-branch>: no local branch to gate on` and delete nothing. Then:
     ```
     ( e="$(mktemp)" && o="$(mktemp)" || { echo "REMOTE-KEPT <skill-branch>: mktemp failed"; exit; }
       if ! gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>" >/dev/null 2>"$e"; then :; elif ! gh api "repos/{owner}/{repo}/git/ref/heads/<skill-branch>" --jq .object.sha >"$o" 2>"$e"; then
         grep -qF '(HTTP 404)' "$e" || echo "REMOTE-KEPT <skill-branch>: remote tip unreadable: $(tail -1 "$e")"
       elif [ "$(cat "$o")" != "<headRefOid>" ]; then echo "REMOTE-KEPT <skill-branch>: remote tip moved"
       elif ! gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>" >/dev/null 2>"$e"; then
         grep -qF 'Reference does not exist' "$e" || echo "REMOTE-DELETE-FAILED <skill-branch>: $(tail -1 "$e")"
       fi )
     ```
     A `REMOTE-DELETE-FAILED` line is never silent and never a STOP.
     Its ABANDON form moves the checkout off an unmerged skill branch: (c), (d) and (e) only;
     it skips (a) and never runs (f). When (b)'s fetch fails, ABANDON reports the fetch error as a note, skips (b) and (e), and runs (c) and (d);
     a failed fetch is never an ABANDON STOP.

9. **Safety.**

   Both literal `gh pr merge` commands pass `--delete-branch=false`; the RETURN PROCEDURE in step 8 is the only move onto a
   working branch, and its gated delete removes only a tip the merge took.
