#!/usr/bin/env bash
# PreToolUse hook for Bash: before a `git commit` in a git worktree, link the main
# checkout's .pre-commit-config.yaml into it. The file is a gitignored link that
# `nix develop` makes in the main checkout only (modules/flake/git-hooks.nix), and the
# shared pre-commit hook fails every commit where it is missing. Claude Code turns git
# hooks off when it creates a worktree, so a post-checkout hook would not run.
set -u
input=$(cat)
case "$(jq -r '.tool_input.command // ""' <<<"$input")" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
cwd=$(jq -r '.cwd // ""' <<<"$input")
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -e "$top/.pre-commit-config.yaml" ] && exit 0
main=$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)")
[ -e "$main/.pre-commit-config.yaml" ] || exit 0
ln -s "$main/.pre-commit-config.yaml" "$top/.pre-commit-config.yaml"
exit 0
