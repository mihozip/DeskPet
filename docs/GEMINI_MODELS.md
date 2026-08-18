# DeskPet Gemini Model Policy

DeskPet only exposes Gemini model IDs that are published by Google for the Gemini API and fit the app's text / structured-output workflows.

Current picker:

- `gemini-3.6-flash` — default and recommended
- `gemini-3.5-flash` — higher-quality stable Flash option
- `gemini-3.5-flash-lite` — lower-cost, high-throughput option

Gemini 2.x options are retired from the user-facing picker. Existing saved model IDs that are no longer supported are migrated to `gemini-3.6-flash`.

## Gemini 3.7 verification

Checked on 2026-08-18 after reviewing the AI Studio Gemini 3.7 developer-guide URL supplied by the maintainer.

The public Gemini API model catalog and Google's current "latest Gemini models" guide still identify `gemini-3.6-flash` as the latest stable Flash API model and do not expose a verifiable Gemini 3.7 Flash model string. The Models API documentation also requires clients to use model names returned by `models.list`.

DeskPet therefore does **not** add a guessed `gemini-3.7-flash` identifier yet. Add Gemini 3.7 only after its exact API model ID can be verified from Google's Gemini API model catalog, Models API, or another first-party API reference.

Do not add guessed future model IDs to the picker.
