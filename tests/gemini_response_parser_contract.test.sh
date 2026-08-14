#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARSER="$ROOT_DIR/Sources/DeskPet/Services/GeminiResponseParser.swift"
INTENT="$ROOT_DIR/Sources/DeskPet/Services/GeminiIntentInterpreter.swift"
TASK="$ROOT_DIR/Sources/DeskPet/Services/GeminiNaturalTaskActionInterpreter.swift"

# Gemini 3 responses can contain thought parts. DeskPet must explicitly ignore
# them and parse only final-answer text.
grep -qF 'let thought: Bool?' "$PARSER"
grep -qF 'part.thought != true' "$PARSER"
grep -qF 'stripMarkdownFence' "$PARSER"

# Do not regress to assuming the first text part is the final answer.
if grep -qF 'compactMap(\.text).first' "$INTENT" "$TASK"; then
  echo "ERROR: Gemini parser still assumes first text part is the final answer" >&2
  exit 1
fi

grep -qF 'GeminiResponseParser.finalAnswerText(from: parts)' "$INTENT"
grep -qF 'GeminiResponseParser.finalAnswerText(from: parts)' "$TASK"
grep -qF 'GeminiResponseParser.decodeStructuredOutput' "$INTENT"
grep -qF 'GeminiResponseParser.decodeStructuredOutput' "$TASK"

# DeskPet's extraction/classification flows do not need medium/high reasoning.
# Minimal thinking reduces truncation risk and latency, while larger output caps
# leave enough room for the structured JSON payload.
grep -qF '"thinkingConfig": ["thinkingLevel": "minimal"]' "$INTENT"
grep -qF '"thinkingConfig": ["thinkingLevel": "minimal"]' "$TASK"
grep -qF '"maxOutputTokens": 1200' "$INTENT"
grep -qF '"maxOutputTokens": 1800' "$TASK"

echo "DeskPet Gemini 3 response parser contract passed"
