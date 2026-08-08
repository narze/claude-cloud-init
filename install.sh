#!/usr/bin/env bash
set -euo pipefail

main() {
  local repo="${TEMPLATE_REPO:-narze/claude-cloud-init}"
  local dest="${DEST:-$HOME/.claude}"
  local ref="${TEMPLATE_REF:-}"

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

  local tmp
  tmp="$(mktemp -d)"
  trap "rm -rf $(printf '%q' "$tmp")" EXIT

  local -a clone_args=(--depth 1 --quiet)
  [ -n "$ref" ] && clone_args+=(--branch "$ref")

  echo "> cloning $url${ref:+ ($ref)}"
  git clone "${clone_args[@]}" "$url" "$tmp/t"
  rm -rf "$tmp/t/.git"

  mkdir -p "$dest"
  cp -aL "$tmp/t/." "$dest/"

  echo "> seeded $dest from $url"
}

main "$@"
