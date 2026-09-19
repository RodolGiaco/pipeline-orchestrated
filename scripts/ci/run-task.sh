#!/usr/bin/env bash
#
# Runs the implementation agent and then the external quality gate, collapsing both into a
# single exit code and a single JSON result.
#
# This separation is the core of the pipeline. The agent's own "completed" claim never decides
# whether an implementation may be published; only ./mvnw -B -ntp verify does.
#
# Provider-specific environment variables are unset before the gate runs, so the build is never
# influenced by the model configuration used to produce the change.
#
# Input  : task prompt on stdin
# Output : {pipelineStatus, agent, qualityGate} on stdout
#
# Exit codes:
#   0   the agent completed and the quality gate passed  -> publishable
#   10  the agent reported itself blocked                -> the gate was not run
#   20  the agent execution failed
#   30  the agent completed but the quality gate failed  -> not publishable
#

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

AGENT_RUNNER="$PROJECT_ROOT/.claude/scripts/run-agent.sh"
QUALITY_GATE="./mvnw -B -ntp verify"

AGENT_RESULT="$(mktemp)"
QUALITY_LOG="$(mktemp)"

trap 'rm -f "$AGENT_RESULT" "$QUALITY_LOG"' EXIT

prompt="$(cat)"

cd "$PROJECT_ROOT"

set +e
printf '%s\n' "$prompt" | "$AGENT_RUNNER" > "$AGENT_RESULT"
agent_exit_code=$?
set -e

case "$agent_exit_code" in
    0)
      unset ANTHROPIC_API_KEY
      unset ANTHROPIC_AUTH_TOKEN
      unset ANTHROPIC_BASE_URL
      unset OPENROUTER_API_KEY
      unset CLAUDE_MODEL
      unset CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY
      unset CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK
      unset CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT
        ;;
    10)
        jq -c \
            --arg command "$QUALITY_GATE" \
            '{
                pipelineStatus: "blocked",
                agent: .,
                qualityGate: {
                    command: $command,
                    status: "not_run"
                }
            }' "$AGENT_RESULT"

        exit 10
        ;;
    *)
        printf 'ERROR: agent execution failed with status %d\n' "$agent_exit_code" >&2
        exit 20
        ;;
esac

set +e
$QUALITY_GATE > "$QUALITY_LOG" 2>&1
quality_gate_exit_code=$?
set -e

if [[ "$quality_gate_exit_code" -ne 0 ]]; then
    cat "$QUALITY_LOG" >&2

    jq -c \
        --arg command "$QUALITY_GATE" \
        '{
            pipelineStatus: "failed",
            agent: .,
            qualityGate: {
                command: $command,
                status: "failed"
            }
        }' "$AGENT_RESULT"

    exit 30
fi

jq -c \
    --arg command "$QUALITY_GATE" \
    '{
        pipelineStatus: "completed",
        agent: .,
        qualityGate: {
            command: $command,
            status: "passed"
        }
    }' "$AGENT_RESULT"

exit 0