#!/usr/bin/env bash
#
# SessionStart hook: reports which branch the session is working on.
#
# Registered in .claude/settings.json for the startup and resume events. The branch determines
# what guard-main-branch.sh permits, so surfacing it up front keeps the agent from attempting
# work that would be denied.
#
# Output : a SessionStart context payload on stdout
#

set -u

branch="$(git branch --show-current 2>/dev/null || true)"

if [[ -z "$branch" ]]; then
    branch="detached-head"
fi

jq -nc \
    --arg branch "$branch" \
    '{
        hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: ("Current Git branch: " + $branch)
        }
    }'