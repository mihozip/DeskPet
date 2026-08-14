# DeskPet RC1.1.3.4 — Gemini 3 Response Parser Fix

RC1.1.3.4 修正 Gemini 3 系列在 Smart Inbox 與自然語句任務操作中可能出現的 structured-output 解碼失敗。

## Fixed

- Gemini response parts 現在會辨識 `thought` metadata，只合併非 thought 的最終答案文字。
- 不再假設 `content.parts` 的第一個文字片段就是最終 JSON。
- 可容忍偶發的 Markdown JSON code fence，再交給 `JSONDecoder` 解碼。
- JSON schema 解碼失敗時會回報缺少欄位、型別不符或資料損壞等較具體原因。
- `MAX_TOKENS` 截斷會顯示明確訊息，不再落入模糊的「格式不正確」。

## Gemini 3 generation settings

DeskPet 的 Smart Inbox 與任務匹配屬於 extraction / classification 工作，不需要中高強度推理。RC1.1.3.4 對這兩條路徑使用 Gemini 3 `thinkingLevel=minimal`，並提高 structured JSON 的輸出上限，降低思考與答案競爭輸出額度而造成 JSON 截斷的機率。

目前模型選單維持：

- `gemini-3.6-flash`
- `gemini-3.5-flash`
- `gemini-3.5-flash-lite`

## Validation

- Gemini model/response-parser contract
- Swift tests
- Public repository checks
- Release app build and codesign verification
