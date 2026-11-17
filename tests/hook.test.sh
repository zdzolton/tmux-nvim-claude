#!/usr/bin/env bash
# Test the auto-allow git hook from claude/settings.template.json.
# The hook only prints a decision. This test runs no git command.
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
CODE=/code-dir-for-test
fail=0

HOOK=$(CODE_DIR="$CODE" "$REPO/install.sh" --print-settings | jq -r '.hooks.PreToolUse[0].hooks[0].command')
decide() {
	local out
	out=$(printf '{"tool_input":{"command":"%s"}}' "$1" | bash -c "$HOOK" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
	echo "${out:-none}"
}
check() {
	local got
	got=$(decide "$2")
	if [ "$got" = "$1" ]; then echo "ok   - $1: $2"; else echo "FAIL - want $1, got $got: $2"; fail=1; fi
}

check allow "git -C $CODE/repo status"
check allow "git -C $CODE/repo log --oneline -5"
check allow "git -C $CODE/repo diff HEAD~1"
check allow "git -C $CODE/repo show HEAD"
check allow "git -C $CODE/repo rev-parse --show-toplevel"
check none "git -C $CODE/repo diff --output=/some/file"
check none "git -C $CODE/repo log --output=/some/file"
check none "git -C $CODE/repo show --output /some/file HEAD"
check none "git -C $CODE/repo diff --ext-diff"
check none "git -C $CODE/repo diff --no-index a b"
check none "git -C $CODE/repo push"
check none "git -C $CODE/repo commit -m x"
check none "git -C /elsewhere/repo status"
check none "git -C $CODE/repo status && echo hi"
check none "git -C $CODE/repo status; echo hi"
check none "git -C \$(echo $CODE/repo) status"

exit "$fail"
