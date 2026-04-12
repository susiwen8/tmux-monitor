#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_INPUT="${1:-}"
VERSION="${VERSION_INPUT#v}"
CHANGELOG_PATH="$ROOT_DIR/CHANGELOG.md"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version-or-tag>" >&2
  exit 1
fi

if [[ ! -f "$CHANGELOG_PATH" ]]; then
  exit 1
fi

awk -v version="$VERSION" '
  $0 ~ "^## "version" - " {capture=1; next}
  capture && $0 ~ "^## " {exit}
  capture {print}
' "$CHANGELOG_PATH" | sed '/^[[:space:]]*$/N;/^\n$/D'
