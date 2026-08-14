# DeskPet Gemini Model Policy

DeskPet only exposes Gemini model IDs that are published by Google for the Gemini API and fit the app's text / structured-output workflows.

Current picker:

- `gemini-3.6-flash` — default and recommended
- `gemini-3.5-flash` — higher-quality stable Flash option
- `gemini-3.5-flash-lite` — lower-cost, high-throughput option

Gemini 2.x options are retired from the user-facing picker. Existing saved model IDs that are no longer supported are migrated to `gemini-3.6-flash`.

Do not add a guessed future model ID. In particular, Gemini 3.7 must not be exposed until Google publishes an official Gemini API model identifier.
