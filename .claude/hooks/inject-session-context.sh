#!/usr/bin/env bash

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