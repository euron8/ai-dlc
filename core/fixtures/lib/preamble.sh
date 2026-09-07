# Fixture preamble. Sourced FIRST by every fixture run.sh that builds a scratch
# repository, before any git call.
#
# THE DEFECT THIS EXISTS FOR. Git exports GIT_DIR ABSOLUTE to any hook it runs
# from a linked worktree, and a fixture invoked DIRECTLY -- `bash
# core/fixtures/X/run.sh`, which is exactly what CLAUDE.md tells a session to do
# when debugging one -- inherits it. `git init` under an inherited GIT_DIR
# SILENTLY SUCCEEDS WITHOUT CREATING A REPOSITORY in the target directory: `.git`
# is absent afterwards, exit 0, no diagnostic. Every later git call in the fixture
# is then redirected onto the CALLER's repository.
#
# Measured on eight fixtures, fresh victim per trial, against an unarmed control
# that left all eight intact: 8 of 8 wiped a 757-entry index to single digits, and
# 6 of the 8 did it while exiting 0 with zero FAILs. The blast radius is the INDEX
# only -- HEAD, refs and worktree files survive, and `git reset --hard` recovers --
# but the victim reads as a catastrophic deletion until someone works that out.
#
# WHY A COUNT GUARD CANNOT CATCH IT, which is the part worth keeping. A fixture
# that seeds its victim under the leaked GIT_DIR has no repository there, so an arm
# reading that directory describes the OUTER repo instead -- both its before and
# after readings come from the wreckage, and `after -eq before` then holds BY
# CONSTRUCTION rather than by measurement. Such an arm prints "index intact" over
# the damage. Assert the victim IS a repository (`[ -d "$victim/.git" ]`), never
# just that a count did not move.
#
# The two pre-push hooks scrub before dispatch, so the SUITE was never exposed
# (.githooks/pre-push and core/git-hooks/pre-push, immediately before the fixture
# pool). A direct invocation passes through no seam at all, and creating one is
# what this file is. `scripts/validate-fixture-git-env.sh` reports which fixtures
# do not source it, under a ceiling that only ratchets down.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
