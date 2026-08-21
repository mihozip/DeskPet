const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(
  path.join(root, 'GAS', 'DeskPet_GAS_API_Gateway_v3.js'),
  'utf8',
);

const scriptProperties = new Map([
  ['DESKPET_API_TOKEN', 'secret-token'],
]);
let uuidCounter = 0;

const context = vm.createContext({
  console,
  PropertiesService: {
    getScriptProperties: () => ({
      getProperty: (key) => scriptProperties.get(key) || '',
      setProperty: (key, value) => scriptProperties.set(key, String(value)),
      deleteProperty: (key) => scriptProperties.delete(key),
    }),
  },
  SpreadsheetApp: {},
  Utilities: {
    DigestAlgorithm: { SHA_256: 'SHA_256' },
    Charset: { UTF_8: 'UTF_8' },
    computeDigest: (_algorithm, value) => Array.from(crypto.createHash('sha256').update(String(value)).digest()),
    getUuid: () => {
      uuidCounter += 1;
      return `00000000-0000-4000-8000-${String(uuidCounter).padStart(12, '0')}`;
    },
  },
});
vm.runInContext(source, context);

const taskHeaders = [
  '任務ID', '任務名稱', '類型', '狀態', '優先級', '截止日期', '截止時間',
  '下一步行動', '等待對象', '最近進度', '負責人', '負責人Email',
  '看板顯示', '顯示排序', '詳細連結', '建立時間', '更新時間', '完成時間', '封存',
];
const logHeaders = ['紀錄ID', '任務ID', '動作', '變更前', '變更後', '操作者', '時間'];

function makeSheet(name, values) {
  return {
    getName: () => name,
    getLastRow: () => values.length,
    getLastColumn: () => Math.max(...values.map((row) => row.length)),
    getDataRange: () => ({ getDisplayValues: () => values }),
    getRange: (row, column, rowCount, columnCount) => ({
      getDisplayValues: () => values
        .slice(row - 1, row - 1 + rowCount)
        .map((item) => item.slice(column - 1, column - 1 + columnCount)),
    }),
  };
}

const sheets = {
  任務清單: makeSheet('任務清單', [taskHeaders]),
  工作紀錄: makeSheet('工作紀錄', [logHeaders]),
  系統設定: makeSheet('系統設定', [
    ['設定項目', '設定值', '說明'],
    ['SYSTEM_NAME', '光明國小｜教務處｜教務主任每日任務系統', ''],
    ['SCHOOL_NAME', '光明國小', ''],
    ['OFFICE_KEY', 'academic_affairs', ''],
    ['OFFICE_NAME', '教務處', ''],
    ['ROLE_KEY', 'director', ''],
    ['ROLE_NAME', '教務主任', ''],
    ['DEFAULT_OWNER', '教務主任', ''],
  ]),
  選項清單: makeSheet('選項清單', [
    ['類型', '狀態', '優先級', '看板顯示', '封存'],
    ['課程教學', '未開始', '高', '自動', '否'],
    ['學籍註冊', '進行中', '中', '強制顯示', '是'],
    ['其他', '已完成', '低', '隱藏', ''],
  ]),
};

const spreadsheet = {
  getSheetByName: (name) => sheets[name] || null,
};
context.SpreadsheetApp.openById = () => spreadsheet;

const metadata = context.validateDashboardContract_(spreadsheet);
assert.equal(metadata.schema, 'school-admin-daily-dashboard/v1');
assert.equal(metadata.schoolName, '光明國小');
assert.equal(metadata.officeKey, 'academic_affairs');
assert.equal(metadata.roleName, '教務主任');
assert.deepEqual(Array.from(metadata.categories), ['課程教學', '學籍註冊', '其他']);
assert.deepEqual(Array.from(metadata.priorities), ['高', '中', '低']);

const options = context.readDashboardOptionLists_(spreadsheet);
assert.equal(context.allowedValueOrFallback_('課程教學', options.category, '其他'), '課程教學');
assert.equal(context.allowedValueOrFallback_('採購', options.category, '其他'), '其他');

const taskWithTitleOverride = context.normalizeTask_({
  name: '確認課務會議',
  category: '課程教學',
  status: '未開始',
  priority: '高',
  owner: '代理教務主任',
  boardDisplay: '自動',
});
context.validateTask_(taskWithTitleOverride, options);
assert.equal(taskWithTitleOverride.owner, '代理教務主任');

assert.throws(
  () => context.validateDashboardContract_({ getSheetByName: () => null }),
  /school-admin-daily-dashboard README/,
);

assert.match(source, /allowedKeys = \['status', 'dueDate', 'dueTime', 'nextAction', 'waitingFor', 'progress'\]/);
assert.match(source, /headerMap\['下一步行動'\]/);
assert.match(source, /function setupDeskPetGateway\(\)/);
assert.match(source, /function createDeskPetApiToken\(\)/);
assert.match(source, /function resetDeskPetApiToken\(\)/);

assert.throws(() => context.verifyToken_('wrong-token'), /Token 無效/);
assert.doesNotThrow(() => context.verifyToken_('secret-token'));

scriptProperties.delete('DESKPET_SPREADSHEET_ID');
const setupWithoutSpreadsheet = context.setupDeskPetGateway();
assert.equal(setupWithoutSpreadsheet.ok, true);
assert.equal(setupWithoutSpreadsheet.spreadsheetConfigured, false);
assert.equal(setupWithoutSpreadsheet.dashboardContractValid, false);
assert.equal(setupWithoutSpreadsheet.tokenConfigured, true);
assert.equal(scriptProperties.get('DESKPET_API_TOKEN'), 'secret-token');

scriptProperties.delete('DESKPET_API_TOKEN');
scriptProperties.set('DESKPET_SPREADSHEET_ID', '12345678901234567890');
const normalOpenById = context.SpreadsheetApp.openById;
context.SpreadsheetApp.openById = () => ({ getSheetByName: () => null });
assert.throws(() => context.setupDeskPetGateway(), /school-admin-daily-dashboard README/);
assert.equal(Boolean(scriptProperties.get('DESKPET_API_TOKEN')), true);
context.SpreadsheetApp.openById = normalOpenById;

const setupWithSpreadsheet = context.setupDeskPetGateway();
assert.equal(setupWithSpreadsheet.ok, true);
assert.equal(setupWithSpreadsheet.spreadsheetConfigured, true);
assert.equal(setupWithSpreadsheet.dashboardContractValid, true);
assert.equal(setupWithSpreadsheet.tokenConfigured, true);

scriptProperties.set('DESKPET_API_TOKEN', 'secret-token');
const existingToken = context.createDeskPetApiToken();
assert.equal(existingToken.token, 'secret-token');
assert.equal(existingToken.tokenCreated, false);
assert.equal(scriptProperties.get('DESKPET_API_TOKEN'), 'secret-token');

scriptProperties.delete('DESKPET_API_TOKEN');
const createdToken = context.createDeskPetApiToken();
assert.equal(createdToken.ok, true);
assert.equal(createdToken.tokenCreated, true);
assert.equal(createdToken.tokenConfigured, true);
assert.equal(createdToken.token.length, 64);
assert.equal(scriptProperties.get('DESKPET_API_TOKEN'), createdToken.token);

const reusedToken = context.createDeskPetApiToken();
assert.equal(reusedToken.tokenCreated, false);
assert.equal(reusedToken.token, createdToken.token);

const rotatedToken = context.resetDeskPetApiToken();
assert.equal(rotatedToken.ok, true);
assert.equal(rotatedToken.tokenRotated, true);
assert.notEqual(rotatedToken.token, createdToken.token);
assert.equal(scriptProperties.get('DESKPET_API_TOKEN'), rotatedToken.token);

const status = context.getDeskPetGatewayStatus();
assert.equal(status.tokenConfigured, true);
assert.equal(Object.prototype.hasOwnProperty.call(status, 'token'), false);

assert.equal(
  context.createDeskPetTaskId_('12345678-1234-1234-1234-123456789012'),
  context.createDeskPetTaskId_('12345678-1234-1234-1234-123456789012'),
);
assert.match(source, /UNSUPPORTED_UPDATE_FIELD/);
assert.match(source, /if \(existingRow\)[\s\S]*duplicate: true/);

console.log('DeskPet Gateway dashboard contract tests passed');
