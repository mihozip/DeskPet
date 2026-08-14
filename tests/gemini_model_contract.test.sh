#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/Sources/DeskPet/Stores/AIConfigurationStore.swift"
PARSER="$ROOT_DIR/Sources/DeskPet/Services/GeminiResponseParser.swift"
INTENT="$ROOT_DIR/Sources/DeskPet/Services/GeminiIntentInterpreter.swift"
TASK="$ROOT_DIR/Sources/DeskPet/Services/GeminiNaturalTaskActionInterpreter.swift"

# DeskPet should default to the latest stable Flash model used by this release.
grep -qF 'static let defaultModelID = "gemini-3.6-flash"' "$CONFIG"

# The user-facing picker is intentionally limited to the current supported 3.5+
# text models used by DeskPet's structured-output workflows.
grep -qF 'ModelOption(id: "gemini-3.6-flash"' "$CONFIG"
grep -qF 'ModelOption(id: "gemini-3.5-flash"' "$CONFIG"
grep -qF 'ModelOption(id: "gemini-3.5-flash-lite"' "$CONFIG"

# Gemini 2.x selections are retired. Do not reintroduce them as picker options or
# as the fallback default.
if grep -qE 'ModelOption\(id: "gemini-2|defaultModelID = "gemini-2' "$CONFIG"; then
  echo "ERROR: retired Gemini 2.x model remains in DeskPet model configuration" >&2
  exit 1
fi

# Do not invent an unreleased 3.7 API model. Add it only after Google publishes
# an official model ID and the contract is deliberately updated.
if grep -qE 'ModelOption\(id: "gemini-3\.7' "$CONFIG"; then
  echo "ERROR: speculative Gemini 3.7 model ID must not be exposed" >&2
  exit 1
fi

# Existing users with a retired saved model must migrate to the current default.
grep -qF 'migrateRetiredModelSelectionIfNeeded()' "$CONFIG"
grep -qF 'UserDefaults.standard.set(Self.defaultModelID, forKey: DefaultsKey.modelID)' "$CONFIG"

# Gemini 3 can return thought parts. DeskPet must ignore them and combine only
# final-answer text before decoding structured JSON.
grep -qF 'let thought: Bool?' "$PARSER"
grep -qF 'part.thought != true' "$PARSER"
grep -qF 'stripMarkdownFence' "$PARSER"

if grep -qF 'compactMap(\.text).first' "$INTENT" "$TASK"; then
  echo "ERROR: Gemini parser still assumes first text part is the final answer" >&2
  exit 1
fi

grep -qF 'GeminiResponseParser.finalAnswerText(from: parts)' "$INTENT"
grep -qF 'GeminiResponseParser.finalAnswerText(from: parts)' "$TASK"
grep -qF 'GeminiResponseParser.decodeStructuredOutput' "$INTENT"
grep -qF 'GeminiResponseParser.decodeStructuredOutput' "$TASK"

# These are extraction/classification requests, so minimal thinking is preferred
# and the output cap must leave enough room for the final JSON payload.
grep -qF '"thinkingConfig": ["thinkingLevel": "minimal"]' "$INTENT"
grep -qF '"thinkingConfig": ["thinkingLevel": "minimal"]' "$TASK"
grep -qF '"maxOutputTokens": 1200' "$INTENT"
grep -qF '"maxOutputTokens": 1800' "$TASK"

echo "DeskPet Gemini model and response-parser contract passed"
