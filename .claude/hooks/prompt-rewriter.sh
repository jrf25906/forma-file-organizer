#!/bin/bash
# Prompt Rewriter Hook for Claude Code
# Enhances prompts by adding a meta-instruction for Claude to rewrite them

set -e

# Read the incoming hook data from stdin
input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt')

# Wrap the user's prompt with instructions for Claude to rewrite it
enhanced_prompt="First, rewrite the following prompt to be more specific, actionable, and clear. Transform vague requests into concrete tasks with clear deliverables. Then answer the rewritten prompt.

User's original prompt:
${prompt}"

# Update the prompt in the hook data and output
echo "$input" | jq --arg new_prompt "$enhanced_prompt" '.prompt = $new_prompt'
