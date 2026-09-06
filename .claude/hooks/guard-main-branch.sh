#!/usr/bin/env bash

set -euo pipefail

input="$(cat)"
tool_name="$(jq -er '.tool_name' <<<"$input")"
branch="$(git branch --show-current 2>/dev/null || true)"

deny() {
    local reason="$1"

    jq -nc --arg reason "$reason" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'

    exit 0
}

if [[ -z "$branch" ]]; then
    deny "Workspace changes are not allowed in detached HEAD state."
fi

if [[ "$branch" != "main" ]]; then
    exit 0
fi

case "$tool_name" in
    Edit|Write)
        deny "File changes are not allowed directly on the main branch."
        ;;

    Bash)
        command="$(jq -er '.tool_input.command | select(type == "string" and length > 0)' <<<"$input")"

        case "$command" in
            "./mvnw -B -ntp test"|"./mvnw -B -ntp verify"|"git status"|"git status --short"|"git branch --show-current"|"git diff"|"git diff --staged")
                exit 0
                ;;
            *)
                deny "Bash commands are restricted on the main branch. Switch branches outside Claude Code before modifying the workspace."
                ;;
        esac
        ;;
esac

exit 0