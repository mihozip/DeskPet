# DeskPet Privacy Notes

DeskPet is designed as a local-first desktop assistant. This document describes the data paths in the open-source version.

## Local data

DeskPet stores its working data under the current macOS user account:

```text
~/Library/Application Support/DeskPet/inbox.json
~/Library/Application Support/DeskPet/work-events.json
```

Preferences such as pet size, animation intensity, shortcut preset, Gemini model selection and GAS polling settings use macOS `UserDefaults`.

RC1.0 snoozes also use `UserDefaults` and contain only a GAS task ID plus a local expiration date. Snoozing does not change the remote task or its deadline.

The non-secret Dashboard integration metadata and an optional local administrative-title override also use `UserDefaults`.

## Keychain secrets

The following values are stored in macOS Keychain rather than source code or JSON data files:

- Gemini API Key
- DeskPet GAS Gateway API Token

The Keychain service name follows the running app's Bundle Identifier. Diagnostic output reports only whether a credential is configured; it must not print the credential value.

## Gemini

Gemini is optional. When enabled, text that requires AI interpretation may be sent to the Google Gemini API, including Smart Inbox content or natural-language task commands.

The Work Diary itself is not automatically uploaded merely because it exists locally. A future analysis feature must make its transmission scope explicit before sending diary data to an external AI service.

RC1.1 Calendar Intelligence does not send Calendar events to Gemini. Calendar query parsing and event filtering are performed locally.

## Voice

Voice commands use macOS microphone and Speech Recognition APIs. The transcribed text is passed into the same task-understanding flow. macOS permission prompts apply.

## Calendar and Reminders

DeskPet uses EventKit. It should not write Calendar events or Reminder items until the user confirms the proposed action.

RC1.1 adds a read-only Calendar Intelligence surface. Full Calendar event access is requested only when the user actively performs a calendar query. DeskPet then reads the selected date range from calendars visible to macOS, filters the event title, location, notes and calendar name locally, and displays matching results. Calendar Intelligence does not modify Calendar events.

A Google Calendar is visible to Calendar Intelligence only when it is already available through the macOS Calendar app / EventKit account configuration.

## Google Apps Script

GAS integration is optional. The user configures their own HTTPS `/exec` deployment URL and API token. DeskPet can read task digests and, after confirmation, create or update tasks.

The public source repository must not contain a real Spreadsheet ID, deployment URL or API token.

## Diagnostics and bug reports

Before posting a public bug report, remove:

- API keys and GAS tokens
- private GAS deployment URLs
- Spreadsheet IDs
- names, emails, schools or organizations
- Inbox / Diary content containing personal or work-confidential information

## Software updates

DeskPet checks the public GitHub repository `VERSION` file at most once per day and when the user requests a manual check. This request does not include Inbox, Diary, Calendar, Reminder, GAS task or credential content. Installing an update downloads the public source archive and writes progress to `~/Library/Logs/DeskPet/update.log`; the log must not contain Keychain secrets.
