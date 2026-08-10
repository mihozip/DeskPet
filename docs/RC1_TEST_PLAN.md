# DeskPet RC1.0 Test Plan

Release Candidate version: `1.0.0.0`.

## Automated commands

```bash
swift test
swift build
node --check GAS/DeskPet_GAS_API_Gateway_v3.js
node tests/gateway_contract.test.js
./tests/updater_cli.test.sh
./tests/update_progress_contract.test.sh
./tests/administrative_title_ui.test.sh
./tests/app_icon_contract.test.sh
./script/check_public_repo.sh
DESKPET_SKIP_LAUNCH=1 ./script/build_and_run.sh
./script/build_release.sh
```

On a macOS File Provider workspace that automatically reattaches Finder metadata, set `DESKPET_RELEASE_DIR` to a writable directory outside that volume before running `./script/build_release.sh`.

CI runs the unit tests before packaging the app.

## Unit coverage

- Today Brief: tier order, deadline/priority/update-time tie breakers, deterministic order, and five-item cap through the snapshot.
- Next Action: local natural-language draft, no write before submit, confirmed payload, success event ordering, and failure without a success event.
- Waiting Radar: empty target on non-waiting status, status-based waiting, age calculation, heuristic marking, snooze hiding, and expiry restoration.
- Daily Wrap: event classification, Asia/Taipei midnight boundary, empty day, and all five counters.
- Weekly Review: Monday boundary, Asia/Taipei timezone, empty week, and event grouping.
- Pet Work State: overdue, due today, long waiting, success, normal, idle, and sleep.
- Persistence: pre-RC Inbox JSON, pre-RC WorkEvent JSON, missing optional fields, invalid snooze payload, and snooze expiry.
- Gateway: unchanged 19-column schema, `nextAction` allow-list, unsupported-field rejection contract, token validation, and deterministic `clientTaskId` identity.

## Manual acceptance

1. Disable Gemini and open **今日工作**; verify all four Daily Work sections render.
2. Use `冷氣工程報價拿到了，下一步請校長確認預算。`; verify the proposal does not write until confirmation.
3. Cancel the confirmation and confirm that GAS and Work Diary are unchanged.
4. Confirm it and verify both `最近進度`, `下一步行動`, and one WorkEvent.
5. Snooze a waiting task and verify its deadline is unchanged in Dashboard.
6. Advance or wait beyond snooze expiry and verify the task returns.
7. Exercise follow-up, change-waiting, and clear-waiting; verify every path opens confirmation.
8. Disable GAS and Gemini; verify Inbox, Daily Wrap, Weekly Review, and empty-state Today Brief remain usable.
9. Install over a prior build with populated `inbox.json` and `work-events.json`; verify both load.
10. Run the in-app updater check and the updater CLI regression without replacing user data.

## Release blockers

- Any failed unit or existing contract test.
- Failure to build or sign the release app.
- Any silent GAS, Calendar, or Reminder mutation.
- Any credential-shaped value found by the public-repository check.
- Any inability to decode prior Inbox or WorkEvent files.
