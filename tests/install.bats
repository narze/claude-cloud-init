#!/usr/bin/env bats
#
# E2E tests for install.sh: each test runs the real script against a real
# local git fixture repo (via a file:// URL), the same way install.sh clones
# a real GitHub repo. No parts of install.sh are mocked.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  INSTALL_SH="$REPO_ROOT/install.sh"

  WORKDIR="$(mktemp -d)"
  FIXTURE_REPO="$WORKDIR/fixture-repo"
  DEST="$WORKDIR/dest"

  mkdir -p "$FIXTURE_REPO/.agents/skills/example-skill"
  echo "# Fixture CLAUDE.md" >"$FIXTURE_REPO/CLAUDE.template.md"
  echo "example skill" >"$FIXTURE_REPO/.agents/skills/example-skill/SKILL.md"
  echo '{"version":1}' >"$FIXTURE_REPO/skills-lock.json"
  ln -s .agents/skills "$FIXTURE_REPO/skills"

  git -C "$FIXTURE_REPO" -c init.defaultBranch=main init -q
  git -C "$FIXTURE_REPO" -c user.email=test@example.com -c user.name=test add -A
  git -C "$FIXTURE_REPO" -c user.email=test@example.com -c user.name=test commit -q -m init

  FIXTURE_URL="file://$FIXTURE_REPO"
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "refuses to run outside Claude Cloud" {
  run env -u CLAUDE_CODE_REMOTE -u ALLOW_ANY_ENV bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 3 ]
  [[ "$output" == *"only runs inside a Claude Cloud environment"* ]]
  [ ! -e "$DEST" ]
}

@test "runs when CLAUDE_CODE_REMOTE is set" {
  run env -u ALLOW_ANY_ENV CLAUDE_CODE_REMOTE=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ -f "$DEST/CLAUDE.md" ]
}

@test "runs when ALLOW_ANY_ENV=1 is set" {
  run env -u CLAUDE_CODE_REMOTE ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ -f "$DEST/CLAUDE.md" ]
}

@test "installs CLAUDE.md and skills into DEST, but not skills-lock.json" {
  run env ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ "$(cat "$DEST/CLAUDE.md")" = "# Fixture CLAUDE.md" ]
  [ -f "$DEST/skills/example-skill/SKILL.md" ]
  [ ! -e "$DEST/skills-lock.json" ]
}

@test "merges into an existing DEST/skills instead of replacing it" {
  mkdir -p "$DEST/skills/preexisting-skill"
  echo "keep me" >"$DEST/skills/preexisting-skill/SKILL.md"

  run env ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ -f "$DEST/skills/preexisting-skill/SKILL.md" ]
  [ -f "$DEST/skills/example-skill/SKILL.md" ]
}

@test "overwrites an existing CLAUDE.md" {
  mkdir -p "$DEST"
  echo "old content" >"$DEST/CLAUDE.md"

  run env ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ "$(cat "$DEST/CLAUDE.md")" = "# Fixture CLAUDE.md" ]
}

@test "positional args override TEMPLATE_REPO and DEST env vars" {
  local other_dest="$WORKDIR/other-dest"
  local ignored_dest="$WORKDIR/ignored-dest"

  run env ALLOW_ANY_ENV=1 TEMPLATE_REPO="not-a-real-repo-should-be-ignored" DEST="$ignored_dest" \
    bash "$INSTALL_SH" "$FIXTURE_URL" "$other_dest"
  [ "$status" -eq 0 ]
  [ -f "$other_dest/CLAUDE.md" ]
  [ ! -e "$ignored_dest" ]
}

@test "rejects a TEMPLATE_REPO that is not owner/repo or a git URL" {
  run env ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "not-a-valid-repo-spec" "$DEST"
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be owner/repo or a git URL"* ]]
  [ ! -e "$DEST" ]
}

@test "fails with a clear error when git is missing" {
  local jail="$WORKDIR/jail-bin"
  mkdir -p "$jail"
  for tool in bash sh; do
    local path
    path="$(command -v "$tool")" || continue
    ln -s "$path" "$jail/$tool"
  done

  run env -i PATH="$jail" HOME="$HOME" ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"git is required"* ]]
}

@test "installs a specific TEMPLATE_REF" {
  git -C "$FIXTURE_REPO" -c user.email=test@example.com -c user.name=test checkout -qb other-branch
  echo "# Other branch CLAUDE.md" >"$FIXTURE_REPO/CLAUDE.template.md"
  git -C "$FIXTURE_REPO" -c user.email=test@example.com -c user.name=test commit -qam "other branch"

  run env ALLOW_ANY_ENV=1 TEMPLATE_REF=other-branch bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ "$(cat "$DEST/CLAUDE.md")" = "# Other branch CLAUDE.md" ]
}

@test "resolves relative symlinks in the template (e.g. skills -> .agents/skills)" {
  run env ALLOW_ANY_ENV=1 bash "$INSTALL_SH" "$FIXTURE_URL" "$DEST"
  [ "$status" -eq 0 ]
  [ -f "$DEST/skills/example-skill/SKILL.md" ]
  [ ! -L "$DEST/skills" ]
}
