#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/Sources/DeskPet/Stores/AIConfigurationStore.swift"

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

echo "DeskPet Gemini model contract passed"
