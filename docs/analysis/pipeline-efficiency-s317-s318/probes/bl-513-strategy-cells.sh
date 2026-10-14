#!/usr/bin/env bash
# BL-513 receipt probe: is a Strategy Test IDs cell that a rename left pointing at a missing
# node refused before the sprint-review gate opens, and does it pass once re-bound?
#
#   PRECONDITION  sprint-review.md carries `### 4. Gate Validation and Proceed`, else 9
#   SUBJECT       core/scripts/validate-handoff-evidence.sh --strategy, driven against one
#                 seeded git world in three commits:
#                   cells resolve                                -> exit 0
#                   the test renamed, cell not re-bound          -> exit 1, `node-missing`
#                   cell re-bound to the new name                -> exit 0
#                   the test FILE moved, cell not re-bound       -> exit 1, `node-missing`
#                   cell re-bound to the new path                -> exit 0
#                 plus an empty `Resolves to` cell               -> exit 1, `empty-cell`
#                 and sprint-review §4 runs it before Seam B.
#   exit 0 fixed, 1 live (the script is absent, a commit scores wrong, or §4 is unwired).
#
# Measured at fe7d5ec2 (origin/main before the fix): no such script -> exit 1.
# Run from the repo root.
set -u
S=core/skills/ai-dlc/steps/sprint-review.md
[ -f "$S" ] && grep -q '^### 4\. Gate Validation and Proceed$' "$S" || exit 9
V=core/scripts/validate-handoff-evidence.sh
[ -f "$V" ] || exit 1
awk '/^### 4\. Gate Validation and Proceed$/{on=1; next} on && /^### /{exit} on{print}' "$S" \
  | tr '\n' ' ' | grep -qF 'validate-handoff-evidence.sh --strategy HEAD' || exit 1

d=$(mktemp -d)
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$d" -c user.name=p -c user.email=p@example.invalid \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
mkdir -p "$d/tests" "$d/stories" && g init -q || exit 9
row='| TS-1 | a | test | tests/test_x.py::TestA::test_old |'
printf 'class TestA:\n    def test_old(self):\n        pass\n' > "$d/tests/test_x.py"
printf '# S\n\n## Strategy Test IDs\n\n| Strategy id | Case | Kind | Resolves to |\n|---|---|---|---|\n%s\n' "$row" > "$d/stories/s.md"
g add -A && g commit -qm one || exit 9
bash "$V" -C "$d" --strategy HEAD stories/s.md >/dev/null 2>&1 || exit 1
printf 'class TestA:\n    def test_new(self):\n        pass\n' > "$d/tests/test_x.py"
g commit -qam rename || exit 9
o=$(bash "$V" -C "$d" --strategy HEAD stories/s.md 2>&1); [ $? -eq 1 ] || exit 1
case "$o" in *"REFUSED node-missing stories/s.md: TS-1 case a"*) ;; *) exit 1 ;; esac
sed 's/::test_old /::test_new /' "$d/stories/s.md" > "$d/s.tmp" && mv "$d/s.tmp" "$d/stories/s.md"
g commit -qam rebind || exit 9
bash "$V" -C "$d" --strategy HEAD stories/s.md >/dev/null 2>&1 || exit 1
g mv tests/test_x.py tests/test_y.py && g commit -qm move || exit 9
o=$(bash "$V" -C "$d" --strategy HEAD stories/s.md 2>&1); [ $? -eq 1 ] || exit 1
case "$o" in *"REFUSED node-missing stories/s.md: TS-1 case a"*"not tracked"*) ;; *) exit 1 ;; esac
sed 's#tests/test_x.py::#tests/test_y.py::#' "$d/stories/s.md" > "$d/s.tmp" && mv "$d/s.tmp" "$d/stories/s.md"
g commit -qam rebind-move || exit 9
bash "$V" -C "$d" --strategy HEAD stories/s.md >/dev/null 2>&1 || exit 1
# A second node in one cell is read too: the first resolves, the second does not.
printf '| TS-3 | b | test | tests/test_y.py::TestA::test_new, tests/test_y.py::TestA::test_gone |\n' >> "$d/stories/s.md"
g commit -qam second || exit 9
o=$(bash "$V" -C "$d" --strategy HEAD stories/s.md 2>&1); [ $? -eq 1 ] || exit 1
case "$o" in *"REFUSED node-missing stories/s.md: TS-3 case b"*"test_gone"*) ;; *) exit 1 ;; esac
grep -v '^| TS-3 ' "$d/stories/s.md" > "$d/s.tmp" && mv "$d/s.tmp" "$d/stories/s.md"
printf '| TS-2 | - | test |  |\n' >> "$d/stories/s.md"
g commit -qam empty || exit 9
o=$(bash "$V" -C "$d" --strategy HEAD stories/s.md 2>&1); [ $? -eq 1 ] || exit 1
case "$o" in *"REFUSED empty-cell stories/s.md: TS-2"*) ;; *) exit 1 ;; esac
exit 0
