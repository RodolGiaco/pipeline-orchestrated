#!/usr/bin/env bash
#
# PreToolUse hook: keeps the main branch read-only for the agent.
#
# Registered in .claude/settings.json for the Edit, Write and Bash tools. It enforces at runtime
# what the permission list expresses as policy, so the protection holds even against a prompt
# that asks the agent to disregard it.
#
# On main:
#   Edit and Write are denied outright.
#   Bash is denied except for the project quality gate and read-only git inspection.
#
# A detached HEAD is denied as well, because the destination of a change cannot be determined.
# On any other branch the hook allows the call and exits silently.
#
# Input  : PreToolUse event JSON on stdin
# Output : a permission decision on stdout when the call is denied; nothing when it is allowed
#

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