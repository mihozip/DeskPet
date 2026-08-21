/**
 * DeskPet API Gateway v3
 * 獨立 Google Apps Script 專案使用。
 *
 * 用途：
 * - 管理台 Web App 繼續維持原本 Workspace / Google 登入保護。
 * - 本 Gateway 單獨部署成「執行身分：我」「誰可以存取：任何人」。
 * - Gateway 不提供管理頁，只接受 JSON API，並以 DESKPET_API_TOKEN 驗證。
 * - 附掛到已完成 school-admin-daily-dashboard 安裝的試算表。
 * - 不建立、不遷移、不覆寫 Dashboard 工作表結構。
 */

const GATEWAY_CONFIG = Object.freeze({
  TIMEZONE: 'Asia/Taipei',
  TASK_SHEET: '任務清單',
  LOG_SHEET: '工作紀錄',
  SETTINGS_SHEET: '系統設定',
  OPTIONS_SHEET: '選項清單',
  API_VERSION: '3',
  DASHBOARD_SCHEMA: 'school-admin-daily-dashboard/v1',
});

const GATEWAY_TASK_HEADERS = Object.freeze([
  '任務ID', '任務名稱', '類型', '狀態', '優先級', '截止日期', '截止時間',
  '下一步行動', '等待對象', '最近進度', '負責人', '負責人Email',
  '看板顯示', '顯示排序', '詳細連結', '建立時間', '更新時間', '完成時間', '封存',
]);

const GATEWAY_LOG_HEADERS = Object.freeze([
  '紀錄ID', '任務ID', '動作', '變更前', '變更後', '操作者', '時間',
]);

const GATEWAY_FALLBACK_OPTIONS = Object.freeze({
  category: ['其他'],
  status: ['未開始', '進行中', '等待他人', '待確認', '已完成', '暫停', '取消'],
  priority: ['高', '中', '低'],
  boardDisplay: ['自動', '強制顯示', '隱藏'],
});

/**
 * 公開 GET 只回服務狀態，不回任何任務資料。
 */
function doGet() {
  return jsonResponse_({
    ok: true,
    service: 'DeskPet API Gateway',
    apiVersion: GATEWAY_CONFIG.API_VERSION,
    message: 'Gateway is running. Use HTTPS POST with a valid API token.',
  });
}

/**
 * DeskPet JSON API。
 * request:
 * {
 *   apiVersion: '1' | '2' | '3',
 *   action: 'ping' | 'createTask' | 'taskDigest' | 'updateTask',
 *   token: '...',
 *   clientTaskId?: '...',
 *   source?: 'deskpet-macos',
 *   rawText?: '...',
 *   task?: {...}
 * }
 */
function doPost(e) {
  try {
    const bodyText = String(e && e.postData && e.postData.contents || '').trim();
    if (!bodyText) throw apiError_('EMPTY_BODY', '缺少 JSON request body。');

    let request;
    try {
      request = JSON.parse(bodyText);
    } catch (_) {
      throw apiError_('INVALID_JSON', 'Request body 不是有效 JSON。');
    }

    const requestVersion = String(request.apiVersion || '');
    if (!['1', '2', '3'].includes(requestVersion)) {
      throw apiError_('UNSUPPORTED_VERSION', '不支援的 DeskPet API 版本。');
    }

    verifyToken_(request.token);

    switch (String(request.action || '').trim()) {
      case 'ping':
        const pingSpreadsheet = openSpreadsheet_();
        const integration = validateDashboardContract_(pingSpreadsheet);
        return jsonResponse_({
          ok: true,
          message: 'DeskPet 已連上校務行政每日任務管理系統',
          apiVersion: GATEWAY_CONFIG.API_VERSION,
          integration,
          serverTime: formatDateTime_(new Date()),
        });

      case 'createTask':
        return jsonResponse_(createTask_(request));

      case 'taskDigest':
        return jsonResponse_(buildTaskDigest_(request));

      case 'updateTask':
        return jsonResponse_(updateTask_(request));

      default:
        throw apiError_('UNKNOWN_ACTION', `不支援的 action：${request.action || '(empty)'}`);
    }
  } catch (error) {
    return jsonResponse_({
      ok: false,
      error: {
        code: error && error.code ? String(error.code) : 'INTERNAL_ERROR',
        message: error && error.message ? String(error.message) : String(error),
      },
    });
  }
}

/**
 * 儲存目標 Spreadsheet ID，並驗證 school-admin-daily-dashboard 契約。
 * 若初始化失敗，會還原原本設定，避免留下無法使用的 ID。
 *
 * 注意：Apps Script 編輯器的函式選單無法傳入參數。
 * 一般安裝請改用 Script Properties + setupDeskPetGateway()。
 */
function configureDeskPetGateway(spreadsheetId) {
  const id = String(spreadsheetId || '').trim();
  if (!/^[A-Za-z0-9_-]{20,}$/.test(id)) {
    throw apiError_('INVALID_SPREADSHEET_ID', 'Spreadsheet ID 格式不正確。');
  }

  const props = PropertiesService.getScriptProperties();
  const previousId = props.getProperty('DESKPET_SPREADSHEET_ID');
  props.setProperty('DESKPET_SPREADSHEET_ID', id);

  try {
    return setupDeskPetGateway();
  } catch (error) {
    if (previousId) {
      props.setProperty('DESKPET_SPREADSHEET_ID', previousId);
    } else {
      props.deleteProperty('DESKPET_SPREADSHEET_ID');
    }
    throw error;
  }
}

/**
 * Apps Script 編輯器可直接執行的無參數安裝入口。
 *
 * 執行順序刻意先建立 Token，再處理 Spreadsheet / Dashboard 驗證：
 * 即使 Spreadsheet 尚未設定或 Dashboard schema 有問題，DESKPET_API_TOKEN
 * 仍會先保存到 Script Properties，不會因初始化失敗而完全拿不到 Token。
 *
 * 第一次安裝建議：
 * 1. Project Settings → Script Properties 新增 DESKPET_SPREADSHEET_ID。
 * 2. 從函式選單執行 setupDeskPetGateway。
 * 3. 回到 Script Properties 複製 DESKPET_API_TOKEN。
 */
function setupDeskPetGateway() {
  const tokenState = createDeskPetApiToken();
  const props = PropertiesService.getScriptProperties();
  const spreadsheetId = String(props.getProperty('DESKPET_SPREADSHEET_ID') || '').trim();

  if (!spreadsheetId) {
    console.info('DeskPet API Token 已建立／確認存在；請設定 DESKPET_SPREADSHEET_ID 後再次執行 setupDeskPetGateway。');
    return {
      ok: true,
      spreadsheetConfigured: false,
      dashboardContractValid: false,
      tokenConfigured: tokenState.tokenConfigured,
      tokenCreated: tokenState.tokenCreated,
      apiVersion: GATEWAY_CONFIG.API_VERSION,
      integration: null,
      message: 'Token 已建立／確認存在。請在 Project Settings → Script Properties 新增 DESKPET_SPREADSHEET_ID，再次執行 setupDeskPetGateway。',
    };
  }

  if (!/^[A-Za-z0-9_-]{20,}$/.test(spreadsheetId)) {
    throw apiError_('INVALID_SPREADSHEET_ID', 'DESKPET_SPREADSHEET_ID 格式不正確。');
  }

  const ss = SpreadsheetApp.openById(spreadsheetId);
  const integration = validateDashboardContract_(ss);
  console.info('DeskPet Gateway 初始化完成；Token 與 Dashboard 均已設定。');

  return {
    ok: true,
    spreadsheetConfigured: true,
    dashboardContractValid: true,
    tokenConfigured: tokenState.tokenConfigured,
    tokenCreated: tokenState.tokenCreated,
    apiVersion: GATEWAY_CONFIG.API_VERSION,
    integration,
  };
}

/**
 * 相容舊版函式名稱；實際初始化統一交給 setupDeskPetGateway()。
 */
function initializeDeskPetGateway() {
  return setupDeskPetGateway();
}

/**
 * 建立或取得目前的 DeskPet API Token。
 * - 第一次執行：建立 DESKPET_API_TOKEN。
 * - 已存在 Token：保留原值，不旋轉，避免重新部署後既有 DeskPet 失效。
 * - 此函數只供 Apps Script 編輯器手動執行，不會透過 doGet/doPost 對外暴露。
 *
 * 執行後可在 Project Settings → Script Properties → DESKPET_API_TOKEN 複製。
 */
function createDeskPetApiToken() {
  const props = PropertiesService.getScriptProperties();
  let token = String(props.getProperty('DESKPET_API_TOKEN') || '').trim();
  const tokenCreated = !token;

  if (tokenCreated) {
    token = generateToken_();
    props.setProperty('DESKPET_API_TOKEN', token);
  }

  console.info(tokenCreated
    ? 'DeskPet API Token 已建立，請到 Project Settings → Script Properties 複製 DESKPET_API_TOKEN。'
    : 'DeskPet API Token 已存在，沿用原 Token。');

  return {
    ok: true,
    token,
    tokenConfigured: Boolean(token),
    tokenCreated,
    message: tokenCreated
      ? '已建立 DeskPet API Token。請將此 Token 貼到白帥帥設定。'
      : 'DeskPet API Token 已存在，沿用原 Token；重新部署不需要換 Token。',
  };
}

/**
 * 強制重新產生 Token；舊 Token 立即失效。
 * 只有需要輪替憑證或現有 Token 已外洩／遺失時才使用。
 */
function resetDeskPetApiToken() {
  const token = generateToken_();
  PropertiesService.getScriptProperties().setProperty('DESKPET_API_TOKEN', token);
  return {
    ok: true,
    token,
    tokenConfigured: true,
    tokenRotated: true,
    message: '已重新產生 DeskPet API Token；舊 Token 已失效。請同步更新白帥帥設定。',
  };
}

/** 回傳 Gateway 設定狀態，不輸出秘密值。 */
function getDeskPetGatewayStatus() {
  const props = PropertiesService.getScriptProperties();
  const spreadsheetConfigured = Boolean(String(props.getProperty('DESKPET_SPREADSHEET_ID') || '').trim());
  let integration = null;
  let validationError = '';
  if (spreadsheetConfigured) {
    try {
      integration = validateDashboardContract_(openSpreadsheet_());
    } catch (error) {
      validationError = error && error.message ? String(error.message) : String(error);
    }
  }
  return {
    spreadsheetConfigured,
    dashboardContractValid: Boolean(integration),
    tokenConfigured: Boolean(String(props.getProperty('DESKPET_API_TOKEN') || '').trim()),
    apiVersion: GATEWAY_CONFIG.API_VERSION,
    integration,
    validationError,
  };
}


function createTask_(request) {
  const clientTaskId = cleanText_(request.clientTaskId, 120);
  if (!clientTaskId) throw apiError_('MISSING_CLIENT_TASK_ID', 'createTask 必須提供 clientTaskId。');

  const taskId = createDeskPetTaskId_(clientTaskId);
  const source = cleanText_(request.source, 80) || 'deskpet-macos';
  const rawText = cleanText_(request.rawText, 1000);
  const incoming = request.task || {};

  const lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    const ss = openSpreadsheet_();
    const taskSheet = requireSheet_(ss, GATEWAY_CONFIG.TASK_SHEET);
    const headerMap = headerMap_(taskSheet);
    assertRequiredHeaders_(headerMap);
    const optionLists = readDashboardOptionLists_(ss);

    const existingRow = findTaskRowById_(taskSheet, headerMap, taskId);
    if (existingRow) {
      const existing = rowToTask_(taskSheet, existingRow, headerMap);
      return {
        ok: true,
        message: '此 DeskPet 任務先前已建立',
        created: false,
        duplicate: true,
        task: existing,
      };
    }

    const defaults = readDefaults_(ss);
    const data = normalizeTask_({
      taskId,
      name: incoming.name,
      category: incoming.category,
      status: incoming.status,
      priority: incoming.priority,
      dueDate: incoming.dueDate,
      dueTime: incoming.dueTime,
      nextAction: incoming.nextAction || rawText,
      waitingFor: incoming.waitingFor,
      progress: incoming.progress,
      owner: incoming.owner || defaults.DEFAULT_OWNER,
      ownerEmail: incoming.ownerEmail || defaults.DEFAULT_OWNER_EMAIL,
      boardDisplay: incoming.boardDisplay,
      sortOrder: incoming.sortOrder,
      detailUrl: incoming.detailUrl,
    });
    data.taskId = taskId;
    data.category = allowedValueOrFallback_(data.category, optionLists.category, '其他');
    data.status = allowedValueOrFallback_(data.status, optionLists.status, '未開始');
    data.priority = allowedValueOrFallback_(data.priority, optionLists.priority, '中');
    data.boardDisplay = allowedValueOrFallback_(data.boardDisplay, optionLists.boardDisplay, '自動');
    validateTask_(data, optionLists);

    const now = new Date();
    data.createdAt = now;
    data.updatedAt = now;
    data.completedAt = data.status === '已完成' ? now : '';
    data.archived = '否';

    const rowNumber = Math.max(taskSheet.getLastRow() + 1, 2);
    taskSheet.getRange(rowNumber, 1, 1, GATEWAY_TASK_HEADERS.length)
      .setValues([taskToRow_(data, headerMap)]);
    applyRowFormats_(taskSheet, rowNumber, headerMap);

    const after = rowToTask_(taskSheet, rowNumber, headerMap);
    appendLog_(ss, taskId, 'DeskPet 新增任務', '', after, source);
    SpreadsheetApp.flush();

    return {
      ok: true,
      message: '任務已加入校務行政每日任務系統',
      created: true,
      duplicate: false,
      task: after,
    };
  } finally {
    lock.releaseLock();
  }
}


/**
 * 由 DeskPet 人工確認後更新既有任務。
 * 只允許有限欄位，避免桌寵改寫任務名稱、分類、負責人等核心資料。
 * request.update 可包含：status / dueDate / dueTime / nextAction / waitingFor / progress
 */
function updateTask_(request) {
  const taskId = cleanText_(request.taskId, 120);
  if (!taskId) throw apiError_('MISSING_TASK_ID', 'updateTask 必須提供 taskId。');

  const incoming = request.update && typeof request.update === 'object' ? request.update : {};
  const source = cleanText_(request.source, 80) || 'deskpet-macos';
  const reason = cleanText_(request.reason, 120) || '更新任務';

  const allowedKeys = ['status', 'dueDate', 'dueTime', 'nextAction', 'waitingFor', 'progress'];
  const requestedKeys = Object.keys(incoming);
  const unsupported = requestedKeys.filter(key => !allowedKeys.includes(key));
  if (unsupported.length) {
    throw apiError_('UNSUPPORTED_UPDATE_FIELD', '不允許更新欄位：' + unsupported.join('、'));
  }
  if (!requestedKeys.length) throw apiError_('EMPTY_UPDATE', '沒有可更新的欄位。');

  const lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    const ss = openSpreadsheet_();
    const sheet = requireSheet_(ss, GATEWAY_CONFIG.TASK_SHEET);
    const headerMap = headerMap_(sheet);
    assertRequiredHeaders_(headerMap);
    const optionLists = readDashboardOptionLists_(ss);

    const rowNumber = findTaskRowById_(sheet, headerMap, taskId);
    if (!rowNumber) throw apiError_('TASK_NOT_FOUND', '找不到指定任務。');

    const before = rowToTask_(sheet, rowNumber, headerMap);
    if (before.archived === '是') throw apiError_('TASK_ARCHIVED', '此任務已封存，DeskPet 不修改封存任務。');

    const now = new Date();

    if (Object.prototype.hasOwnProperty.call(incoming, 'status')) {
      const value = cleanText_(incoming.status, 30);
      if (!optionLists.status.includes(value)) throw apiError_('INVALID_STATUS', '任務狀態不在 Dashboard 選項清單中。');
      sheet.getRange(rowNumber, headerMap['狀態']).setValue(value);
      sheet.getRange(rowNumber, headerMap['完成時間']).setValue(value === '已完成' ? now : '');
    }

    if (Object.prototype.hasOwnProperty.call(incoming, 'dueDate')) {
      const value = normalizeDate_(incoming.dueDate);
      if (incoming.dueDate && !value) throw apiError_('INVALID_DUE_DATE', '截止日期格式不正確。');
      sheet.getRange(rowNumber, headerMap['截止日期']).setValue(value ? parseDate_(value) : '');
    }

    if (Object.prototype.hasOwnProperty.call(incoming, 'dueTime')) {
      const value = normalizeTime_(incoming.dueTime);
      if (incoming.dueTime && !value) throw apiError_('INVALID_DUE_TIME', '截止時間格式不正確。');
      sheet.getRange(rowNumber, headerMap['截止時間']).setValue(value ? parseTime_(value) : '');
    }

    if (Object.prototype.hasOwnProperty.call(incoming, 'nextAction')) {
      sheet.getRange(rowNumber, headerMap['下一步行動']).setValue(cleanText_(incoming.nextAction, 1000));
    }

    if (Object.prototype.hasOwnProperty.call(incoming, 'waitingFor')) {
      sheet.getRange(rowNumber, headerMap['等待對象']).setValue(cleanText_(incoming.waitingFor, 200));
    }

    if (Object.prototype.hasOwnProperty.call(incoming, 'progress')) {
      sheet.getRange(rowNumber, headerMap['最近進度']).setValue(cleanText_(incoming.progress, 1000));
    }

    sheet.getRange(rowNumber, headerMap['更新時間']).setValue(now);
    applyRowFormats_(sheet, rowNumber, headerMap);

    const after = rowToTask_(sheet, rowNumber, headerMap);
    appendLog_(ss, taskId, 'DeskPet：' + reason, before, after, source);
    SpreadsheetApp.flush();

    return {
      ok: true,
      message: '任務已更新',
      updated: true,
      task: after,
    };
  } finally {
    lock.releaseLock();
  }

}


/**
 * 讀取 DeskPet 桌寵需要的唯讀任務摘要。
 * 此 API 只回傳未封存任務，且必須先通過 API Token。
 */
function buildTaskDigest_(request) {
  const limit = clampNumber_(request && request.limit, 1, 30, 12);
  const ss = openSpreadsheet_();
  const sheet = requireSheet_(ss, GATEWAY_CONFIG.TASK_SHEET);
  const headerMap = headerMap_(sheet);
  assertRequiredHeaders_(headerMap);

  const allTasks = listTasksForDigest_(sheet, headerMap);
  const active = allTasks.filter(task => !isDoneStatus_(task.status));
  const today = Utilities.formatDate(new Date(), GATEWAY_CONFIG.TIMEZONE, 'yyyy-MM-dd');

  const decorated = active.map(task => {
    const flags = [];
    if (task.dueDate && task.dueDate < today) flags.push('overdue');
    if (task.dueDate === today) flags.push('dueToday');
    if (task.priority === '高') flags.push('urgent');
    if (isWaitingStatus_(task.status)) flags.push('waiting');
    return Object.assign({}, task, { flags });
  });

  decorated.sort(compareDigestTasks_);

  return {
    ok: true,
    message: 'DeskPet 任務摘要已更新',
    apiVersion: GATEWAY_CONFIG.API_VERSION,
    summary: {
      active: active.length,
      dueToday: decorated.filter(task => task.flags.includes('dueToday')).length,
      overdue: decorated.filter(task => task.flags.includes('overdue')).length,
      urgent: decorated.filter(task => task.flags.includes('urgent')).length,
      waiting: decorated.filter(task => task.flags.includes('waiting')).length,
    },
    tasks: decorated.slice(0, limit),
    integration: buildIntegrationMetadata_(ss),
    serverTime: formatDateTime_(new Date()),
  };
}

function listTasksForDigest_(sheet, headerMap) {
  if (sheet.getLastRow() < 2) return [];
  const values = sheet.getRange(2, 1, sheet.getLastRow() - 1, GATEWAY_TASK_HEADERS.length).getValues();
  return values
    .map(row => rowArrayToTask_(row, headerMap))
    .filter(task => task.name)
    .filter(task => task.archived !== '是');
}

function compareDigestTasks_(a, b) {
  const tier = task => {
    if (task.flags.includes('overdue')) return 0;
    if (task.flags.includes('dueToday')) return 1;
    if (task.flags.includes('urgent')) return 2;
    if (task.flags.includes('waiting') || task.waitingFor) return 3;
    return 4;
  };

  const tierDiff = tier(a) - tier(b);
  if (tierDiff !== 0) return tierDiff;

  const dateA = a.dueDate || '9999-12-31';
  const dateB = b.dueDate || '9999-12-31';
  if (dateA !== dateB) return dateA.localeCompare(dateB);

  const timeA = a.dueTime || '23:59';
  const timeB = b.dueTime || '23:59';
  if (timeA !== timeB) return timeA.localeCompare(timeB);

  const priorityRank = priority => priority === '高' ? 0 : (priority === '中' ? 1 : (priority === '低' ? 2 : 3));
  const priorityDiff = priorityRank(a.priority) - priorityRank(b.priority);
  if (priorityDiff !== 0) return priorityDiff;

  const updatedDiff = (a.updatedAt || '').localeCompare(b.updatedAt || '');
  if (updatedDiff !== 0) return updatedDiff;
  return String(a.taskId || '').localeCompare(String(b.taskId || ''));
}

function isDoneStatus_(status) {
  return ['已完成', '取消'].includes(String(status || ''));
}

function isWaitingStatus_(status) {
  return ['等待他人', '待確認'].includes(String(status || ''));
}

function clampNumber_(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.round(number)));
}

function verifyToken_(providedToken) {
  const expected = String(PropertiesService.getScriptProperties().getProperty('DESKPET_API_TOKEN') || '').trim();
  if (!expected) throw apiError_('API_NOT_CONFIGURED', 'Gateway 尚未建立 API Token。');

  const actual = String(providedToken || '').trim();
  if (!actual || !constantTimeEquals_(actual, expected)) {
    throw apiError_('UNAUTHORIZED', 'DeskPet API Token 無效。');
  }
}

function normalizeTask_(task) {
  return {
    taskId: cleanText_(task.taskId, 80),
    name: cleanText_(task.name, 200),
    category: cleanText_(task.category, 50) || '其他',
    status: cleanText_(task.status, 30) || '未開始',
    priority: cleanText_(task.priority, 20) || '中',
    dueDate: normalizeDate_(task.dueDate),
    dueTime: normalizeTime_(task.dueTime),
    nextAction: cleanText_(task.nextAction, 1000),
    waitingFor: cleanText_(task.waitingFor, 200),
    progress: cleanText_(task.progress, 1000),
    owner: cleanText_(task.owner, 100),
    ownerEmail: cleanText_(task.ownerEmail, 200),
    boardDisplay: cleanText_(task.boardDisplay, 30) || '自動',
    sortOrder: Number(task.sortOrder) || 9999,
    detailUrl: sanitizeUrl_(task.detailUrl),
    archived: '否',
  };
}

function validateTask_(task, optionLists) {
  if (!task.name) throw apiError_('INVALID_TASK', '請填寫任務名稱。');
  if (!optionLists.category.includes(task.category)) throw apiError_('INVALID_CATEGORY', '任務類型不在 Dashboard 選項清單中。');
  if (!optionLists.status.includes(task.status)) throw apiError_('INVALID_STATUS', '任務狀態不在 Dashboard 選項清單中。');
  if (!optionLists.priority.includes(task.priority)) throw apiError_('INVALID_PRIORITY', '優先級不在 Dashboard 選項清單中。');
  if (!optionLists.boardDisplay.includes(task.boardDisplay)) throw apiError_('INVALID_BOARD_DISPLAY', '看板顯示設定無效。');
  if (task.ownerEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(task.ownerEmail)) {
    throw apiError_('INVALID_EMAIL', '負責人 Email 格式不正確。');
  }
}

function readDefaults_(ss) {
  const settings = readDashboardSettings_(ss);
  return {
    DEFAULT_OWNER: settings.DEFAULT_OWNER || settings.ROLE_NAME || '',
    DEFAULT_OWNER_EMAIL: settings.DEFAULT_OWNER_EMAIL || '',
  };
}

function allowedValueOrFallback_(value, allowed, preferred) {
  if (allowed.includes(value)) return value;
  if (allowed.includes(preferred)) return preferred;
  return allowed[0] || preferred;
}

function taskToRow_(task, headerMap) {
  const row = Array(GATEWAY_TASK_HEADERS.length).fill('');
  const set = (header, value) => {
    const col = headerMap[header];
    if (col) row[col - 1] = value;
  };

  set('任務ID', task.taskId);
  set('任務名稱', task.name);
  set('類型', task.category);
  set('狀態', task.status);
  set('優先級', task.priority);
  set('截止日期', task.dueDate ? parseDate_(task.dueDate) : '');
  set('截止時間', task.dueTime ? parseTime_(task.dueTime) : '');
  set('下一步行動', task.nextAction);
  set('等待對象', task.waitingFor);
  set('最近進度', task.progress);
  set('負責人', task.owner);
  set('負責人Email', task.ownerEmail);
  set('看板顯示', task.boardDisplay);
  set('顯示排序', task.sortOrder);
  set('詳細連結', task.detailUrl);
  set('建立時間', task.createdAt || new Date());
  set('更新時間', task.updatedAt || new Date());
  set('完成時間', task.completedAt || '');
  set('封存', task.archived || '否');
  return row;
}

function rowToTask_(sheet, rowNumber, headerMap) {
  const row = sheet.getRange(rowNumber, 1, 1, GATEWAY_TASK_HEADERS.length).getValues()[0];
  const task = rowArrayToTask_(row, headerMap);
  task.rowNumber = rowNumber;
  return task;
}

function rowArrayToTask_(row, headerMap) {
  const get = header => row[headerMap[header] - 1];
  return {
    taskId: String(get('任務ID') || '').trim(),
    name: String(get('任務名稱') || '').trim(),
    category: String(get('類型') || '').trim(),
    status: String(get('狀態') || '').trim(),
    priority: String(get('優先級') || '').trim(),
    dueDate: formatDate_(get('截止日期')),
    dueTime: formatTime_(get('截止時間')),
    nextAction: String(get('下一步行動') || '').trim(),
    waitingFor: String(get('等待對象') || '').trim(),
    progress: String(get('最近進度') || '').trim(),
    owner: String(get('負責人') || '').trim(),
    ownerEmail: String(get('負責人Email') || '').trim(),
    boardDisplay: String(get('看板顯示') || '自動').trim(),
    sortOrder: Number(get('顯示排序')) || 9999,
    detailUrl: String(get('詳細連結') || '').trim(),
    createdAt: formatDateTime_(get('建立時間')),
    updatedAt: formatDateTime_(get('更新時間')),
    completedAt: formatDateTime_(get('完成時間')),
    archived: String(get('封存') || '否').trim(),
  };
}

function appendLog_(ss, taskId, action, before, after, actor) {
  const sheet = requireSheet_(ss, GATEWAY_CONFIG.LOG_SHEET);
  const summarize = value => {
    if (value === null || value === undefined || value === '') return '';
    const text = typeof value === 'string' ? value : JSON.stringify(value);
    return text.length > 5000 ? text.slice(0, 4997) + '...' : text;
  };
  sheet.appendRow([
    'LOG-' + Utilities.getUuid(),
    taskId || '',
    action || '',
    summarize(before),
    summarize(after),
    actor || 'deskpet-macos',
    new Date(),
  ]);
}

function applyRowFormats_(sheet, rowNumber, headerMap) {
  sheet.getRange(rowNumber, headerMap['截止日期']).setNumberFormat('yyyy/mm/dd');
  sheet.getRange(rowNumber, headerMap['截止時間']).setNumberFormat('hh:mm');
  ['建立時間', '更新時間', '完成時間'].forEach(header => {
    sheet.getRange(rowNumber, headerMap[header]).setNumberFormat('yyyy/mm/dd hh:mm:ss');
  });
}

function configuredSpreadsheetId_() {
  const id = String(PropertiesService.getScriptProperties().getProperty('DESKPET_SPREADSHEET_ID') || '').trim();
  if (!id) {
    throw apiError_('GATEWAY_NOT_CONFIGURED', '尚未設定 DESKPET_SPREADSHEET_ID。請先執行 setupDeskPetGateway()，並依提示設定 Spreadsheet ID。');
  }
  return id;
}

function openSpreadsheet_() {
  return SpreadsheetApp.openById(configuredSpreadsheetId_());
}

function requireSheet_(ss, name) {
  const sheet = ss.getSheetByName(name);
  if (!sheet) throw apiError_('DASHBOARD_NOT_INSTALLED', `找不到工作表「${name}」。請先依 school-admin-daily-dashboard README 完成安裝。`);
  return sheet;
}

function validateDashboardContract_(ss) {
  const taskSheet = requireSheet_(ss, GATEWAY_CONFIG.TASK_SHEET);
  const logSheet = requireSheet_(ss, GATEWAY_CONFIG.LOG_SHEET);
  const settingsSheet = requireSheet_(ss, GATEWAY_CONFIG.SETTINGS_SHEET);
  const optionsSheet = requireSheet_(ss, GATEWAY_CONFIG.OPTIONS_SHEET);
  assertHeaders_(taskSheet, GATEWAY_TASK_HEADERS);
  assertHeaders_(logSheet, GATEWAY_LOG_HEADERS);
  assertHeaders_(settingsSheet, ['設定項目', '設定值']);
  assertHeaders_(optionsSheet, ['類型', '狀態', '優先級', '看板顯示']);
  const settings = readDashboardSettings_(ss);
  const missingSettings = ['SYSTEM_NAME', 'OFFICE_KEY', 'OFFICE_NAME', 'ROLE_KEY', 'ROLE_NAME']
    .filter(key => !(key in settings));
  if (missingSettings.length) {
    throw apiError_('DASHBOARD_SETTINGS_MISMATCH', '系統設定缺少項目：' + missingSettings.join('、'));
  }
  return buildIntegrationMetadata_(ss);
}

function assertRequiredHeaders_(headerMap) {
  const missing = GATEWAY_TASK_HEADERS.filter(header => !headerMap[header]);
  if (missing.length) throw apiError_('MISSING_HEADERS', '任務清單缺少欄位：' + missing.join('、'));
}

function assertHeaders_(sheet, requiredHeaders) {
  const map = headerMap_(sheet);
  const missing = requiredHeaders.filter(header => !map[header]);
  if (missing.length) {
    throw apiError_('DASHBOARD_SCHEMA_MISMATCH', `工作表「${sheet.getName()}」缺少欄位：${missing.join('、')}`);
  }
}

function readDashboardSettings_(ss) {
  const sheet = requireSheet_(ss, GATEWAY_CONFIG.SETTINGS_SHEET);
  const result = {};
  if (sheet.getLastRow() < 2) return result;
  sheet.getRange(2, 1, sheet.getLastRow() - 1, 2).getDisplayValues().forEach(row => {
    const key = String(row[0] || '').trim();
    if (key) result[key] = String(row[1] || '').trim();
  });
  return result;
}

function readDashboardOptionLists_(ss) {
  const sheet = requireSheet_(ss, GATEWAY_CONFIG.OPTIONS_SHEET);
  if (sheet.getLastRow() < 2 || sheet.getLastColumn() < 1) {
    throw apiError_('DASHBOARD_OPTIONS_EMPTY', '選項清單尚未建立，請先在 Dashboard 執行安裝或重新套用工作表格式。');
  }

  const values = sheet.getDataRange().getDisplayValues();
  const headers = values[0].map(value => String(value || '').trim());
  const readColumn = (header, fallback) => {
    const index = headers.indexOf(header);
    if (index < 0) return [...fallback];
    const items = values.slice(1)
      .map(row => String(row[index] || '').trim())
      .filter(Boolean);
    return items.length ? [...new Set(items)] : [...fallback];
  };

  return {
    category: readColumn('類型', GATEWAY_FALLBACK_OPTIONS.category),
    status: readColumn('狀態', GATEWAY_FALLBACK_OPTIONS.status),
    priority: readColumn('優先級', GATEWAY_FALLBACK_OPTIONS.priority),
    boardDisplay: readColumn('看板顯示', GATEWAY_FALLBACK_OPTIONS.boardDisplay),
  };
}

function buildIntegrationMetadata_(ss) {
  const settings = readDashboardSettings_(ss);
  const options = readDashboardOptionLists_(ss);
  return {
    schema: GATEWAY_CONFIG.DASHBOARD_SCHEMA,
    systemName: settings.SYSTEM_NAME || '校務行政每日任務管理系統',
    schoolName: settings.SCHOOL_NAME || '',
    officeKey: settings.OFFICE_KEY || '',
    officeName: settings.OFFICE_NAME || '',
    roleKey: settings.ROLE_KEY || '',
    roleName: settings.ROLE_NAME || '',
    categories: options.category,
    statuses: options.status,
    priorities: options.priority,
    boardDisplayOptions: options.boardDisplay,
  };
}

function headerMap_(sheet) {
  const headers = sheet.getRange(1, 1, 1, Math.max(sheet.getLastColumn(), 1)).getDisplayValues()[0];
  const map = {};
  headers.forEach((header, index) => {
    const key = String(header || '').trim();
    if (key) map[key] = index + 1;
  });
  return map;
}

function findTaskRowById_(sheet, headerMap, taskId) {
  if (!taskId || sheet.getLastRow() < 2) return 0;
  const match = sheet
    .getRange(2, headerMap['任務ID'], sheet.getLastRow() - 1, 1)
    .createTextFinder(String(taskId))
    .matchEntireCell(true)
    .findNext();
  return match ? match.getRow() : 0;
}

function createDeskPetTaskId_(clientTaskId) {
  const compact = String(clientTaskId || '').replace(/[^A-Za-z0-9]/g, '').toUpperCase();
  if (compact.length >= 16) return 'DP-' + compact.slice(0, 24);

  const digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    String(clientTaskId || ''),
    Utilities.Charset.UTF_8
  );
  const hex = digest.slice(0, 12)
    .map(byte => ((byte + 256) % 256).toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase();
  return 'DP-' + hex;
}

function generateToken_() {
  return (Utilities.getUuid() + Utilities.getUuid()).replace(/-/g, '');
}

function constantTimeEquals_(a, b) {
  const left = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(a), Utilities.Charset.UTF_8);
  const right = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(b), Utilities.Charset.UTF_8);
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}

function normalizeDate_(value) {
  if (!value) return '';
  const text = String(value).trim();
  const match = text.match(/(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})/);
  if (!match) return '';
  return `${match[1]}-${String(match[2]).padStart(2, '0')}-${String(match[3]).padStart(2, '0')}`;
}

function normalizeTime_(value) {
  if (!value) return '';
  const text = String(value).trim();
  const match = text.match(/(?:^|\s)(\d{1,2}):(\d{2})(?::\d{2})?$/) || text.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return '';
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return '';
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function parseDate_(value) {
  const normalized = normalizeDate_(value);
  if (!normalized) return '';
  const parts = normalized.split('-').map(Number);
  return new Date(parts[0], parts[1] - 1, parts[2], 12, 0, 0);
}

function parseTime_(value) {
  const normalized = normalizeTime_(value);
  if (!normalized) return '';
  const parts = normalized.split(':').map(Number);
  return new Date(1899, 11, 30, parts[0], parts[1], 0);
}

function formatDate_(value) {
  if (!value) return '';
  const date = value instanceof Date ? value : parseDate_(value);
  return date && !Number.isNaN(date.getTime())
    ? Utilities.formatDate(date, GATEWAY_CONFIG.TIMEZONE, 'yyyy-MM-dd')
    : '';
}

function formatTime_(value) {
  if (!value) return '';
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return Utilities.formatDate(value, GATEWAY_CONFIG.TIMEZONE, 'HH:mm');
  }
  return normalizeTime_(value);
}

function formatDateTime_(value) {
  if (!value) return '';
  const date = value instanceof Date ? value : new Date(value);
  return date && !Number.isNaN(date.getTime())
    ? Utilities.formatDate(date, GATEWAY_CONFIG.TIMEZONE, 'yyyy-MM-dd HH:mm:ss')
    : '';
}

function cleanText_(value, maxLength) {
  const text = String(value || '')
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text.slice(0, maxLength);
}

function sanitizeUrl_(value) {
  const text = cleanText_(value, 1000);
  if (!text) return '';
  if (!/^https:\/\//i.test(text)) throw apiError_('INVALID_URL', '詳細連結只允許 https:// 網址。');
  return text;
}

function apiError_(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

function jsonResponse_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}