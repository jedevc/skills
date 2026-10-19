#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"

mkdir -p "$dest"
for skill in "$root"/skills/*/; do
	skill="${skill%/}"
	target="$dest/$(basename "$skill")"
	if [[ -e "$target" && ! -L "$target" ]]; then
		echo "error: $target already exists and isn't a symlink" >&2
		exit 1
	fi
	ln -sfn "$skill" "$target"
	echo "installed $(basename "$skill") -> $target"
done
