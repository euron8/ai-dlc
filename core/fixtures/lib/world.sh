# shellcheck shell=bash
# core/fixtures/lib/world.sh -- the scratch worlds a fixture builds its cases in. Source it after lib/preamble.sh.
#
#   world_git <git args...>          git with every leaked GIT_* location unset and a fixed identity: no hook, no
#                                    signing, no auto-maintenance, branch `main`. Use it for every git call on a world.
#   world_repo <dir>                 a new repository at <dir> (created if absent) with one empty root commit
#   world_commit <dir> <message>     stage everything under <dir> and commit it; 0 when a commit was made
#   world_install <root> <dir>       a consumer world: <root>/scripts/install.sh run into <dir> (created if absent),
#                                    stdin /dev/null, its log at <dir>.install.log; returns install.sh's status
#
# A world lives under the fixture's own `mktemp -d`; nothing here writes outside the directory it is handed.
world_git() {
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR -u GIT_OBJECT_DIRECTORY \
    git -c user.name=fixture -c user.email=fixture@invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null \
    -c init.defaultBranch=main -c maintenance.auto=false "$@"
}
world_repo() { # <dir>
  mkdir -p "$1" || return 1
  world_git init -q "$1" || return 1
  world_git -C "$1" commit -q --allow-empty -m root
}
world_commit() { # <dir> <message>
  world_git -C "$1" add -A || return 1
  world_git -C "$1" commit -q -m "$2"
}
world_install() { # <root> <dir>
  mkdir -p "$2" || return 1
  bash "$1/scripts/install.sh" "$2" < /dev/null > "$2.install.log" 2>&1
}
