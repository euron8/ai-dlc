When CI fails on a check that passes locally, FIRST run
`git ls-files <relevant-paths>` and `git check-ignore -v <paths>` BEFORE
iterating on bash version, locale, runner OS, or pipeline differences. A
`.gitignore` rule silently excluding test fixtures, scripts, or config files
is the canonical case — the files exist on the dev machine, are absent from the
CI checkout, and the failing check fails for unrelated-looking reasons.
