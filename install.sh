#!/usr/bin/env bash
set -euo pipefail

# Claude Cloud sets CLAUDE_CODE_REMOTE from container bootstrap onward, so it is
# present for setup scripts. CLAUDECODE=1 is not usable here: the claude process
# sets it on itself, so it is absent while the setup script runs.
require_claude_cloud() {
  [ -n "${ALLOW_ANY_ENV:-}" ] && return 0
  [ -n "${CLAUDE_CODE_REMOTE:-}" ] && return 0

  cat >&2 <<'EOF'
error: this script only runs inside a Claude Cloud environment.

  CLAUDE_CODE_REMOTE is not set, so this looks like a local machine. Running
  here would overwrite ~/.claude/CLAUDE.md and merge into ~/.claude/skills.

  Re-run with ALLOW_ANY_ENV=1 if you really mean to.
EOF
  return 3
}

main() {
  require_claude_cloud

  local repo="${TEMPLATE_REPO:-narze/claude-cloud-init}"
  local dest="${DEST:-$HOME/.claude}"
  local ref="${TEMPLATE_REF:-}"
  local claude_md_url="${CLAUDE_MD_URL:-}"

  [ "$#" -ge 1 ] && repo="$1"
  [ "$#" -ge 2 ] && dest="$2"

  local url
  case "$repo" in
  *://* | git@*) url="$repo" ;;
  */*) url="https://github.com/$repo" ;;
  *)
    echo "error: template must be owner/repo or a git URL, got: $repo" >&2
    return 2
    ;;
  esac

  command -v git >/dev/null 2>&1 || {
    echo "error: git is required" >&2
    return 1
  }

  if [ -n "$claude_md_url" ]; then
    command -v curl >/dev/null 2>&1 || {
      echo "error: curl is required to fetch CLAUDE_MD_URL" >&2
      return 1
    }
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap "rm -rf $(printf '%q' "$tmp")" EXIT

  local -a clone_args=(--depth 1 --quiet)
  [ -n "$ref" ] && clone_args+=(--branch "$ref")

  echo "> cloning $url${ref:+ ($ref)}"
  git clone "${clone_args[@]}" "$url" "$tmp/t"

  mkdir -p "$dest/skills"

  if [ -n "$claude_md_url" ]; then
    echo "> fetching CLAUDE.md from $claude_md_url"
    curl -fsSL "$claude_md_url" -o "$dest/CLAUDE.md"
  else
    [ -f "$tmp/t/CLAUDE.template.md" ] && cp -a "$tmp/t/CLAUDE.template.md" "$dest/CLAUDE.md"
  fi
  [ -d "$tmp/t/.agents/skills" ] && cp -a "$tmp/t/.agents/skills/." "$dest/skills/"

  echo "> seeded $dest from $url"
}

main "$@"
