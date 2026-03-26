require('dotenv').config();

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const qs = require('querystring');
const { BigQuery } = require('@google-cloud/bigquery');

const PARKRUN_API_BASE = 'https://api.parkrun.com';
const PARKRUN_USER_AGENT = 'parkrun/1.2.7 CFNetwork/1121.2.2 Darwin/19.3.0';
const PARKRUN_VERSION = '2.0.1';
const PAGE_SIZE = 100;
const FALLBACK_ROLE_REGEX = /(^|, )Role \d+/;

const {
  GCP_PROJECT_ID,
  GOOGLE_CREDENTIALS_PATH,
  GOOGLE_APPLICATION_CREDENTIALS,
  PARKRUN_CLIENT_ID,
  PARKRUN_CLIENT_SECRET,
  BIGQUERY_DATASET_ID = 'parkrun_data',
  BIGQUERY_VOLUNTEERS_TABLE = 'volunteers',
  BIGQUERY_JUNIOR_VOLUNTEERS_TABLE = 'junior_volunteers',
  PARKRUN_USERNAME,
  PARKRUN_PASSWORD,
  PARKRUN_EVENT_ID,
  JUNIOR_USERNAME,
  JUNIOR_PASSWORD,
  JUNIOR_EVENT_ID,
  GET_ALL_START_OFFSET = '0',
  GET_ALL_RETRY_403_MS = '100000',
  GET_ALL_PROGRESS_EVERY_PAGES = '10',
  RUN_FETCH_DELAY_MS = '250',
} = process.env;

const START_OFFSET_DEFAULT = Math.max(
  0,
  parseInt(GET_ALL_START_OFFSET, 10) || 0,
);
const RETRY_403_MS = Math.max(
  1000,
  parseInt(GET_ALL_RETRY_403_MS, 10) || 100000,
);
const PROGRESS_EVERY_PAGES_DEFAULT = Math.max(
  1,
  parseInt(GET_ALL_PROGRESS_EVERY_PAGES, 10) || 10,
);
const RUN_FETCH_DELAY_MS_DEFAULT = Math.max(
  0,
  parseInt(RUN_FETCH_DELAY_MS, 10) || 250,
);

function parseArgs(argv) {
  const args = {
    dryRun: false,
    junior: false,
    reportPath: null,
    startOffset: START_OFFSET_DEFAULT,
    maxPages: null,
    progressEveryPages: PROGRESS_EVERY_PAGES_DEFAULT,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--dry-run') {
      args.dryRun = true;
      continue;
    }

    if (arg === '--junior') {
      args.junior = true;
      continue;
    }

    if (arg === '--help' || arg === '-h') {
      args.help = true;
      continue;
    }

    if (arg === '--report') {
      args.reportPath = argv[index + 1] || null;
      index += 1;
      continue;
    }

    if (arg === '--start-offset') {
      args.startOffset = parseOptionalInt(argv[index + 1]) ?? 0;
      index += 1;
      continue;
    }

    if (arg === '--max-pages') {
      args.maxPages = parseOptionalInt(argv[index + 1]);
      index += 1;
      continue;
    }

    if (arg === '--progress-every-pages') {
      args.progressEveryPages =
        parseOptionalInt(argv[index + 1]) ?? PROGRESS_EVERY_PAGES_DEFAULT;
      index += 1;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return args;
}

function printUsage() {
  console.log('Usage: node utilities/reload-volunteer-history.js [options]');
  console.log('');
  console.log('Options:');
  console.log(
    '  --dry-run                   Fetch and map volunteer history without writing to BigQuery',
  );
  console.log(
    '  --junior                    Use junior credentials, event id, and table',
  );
  console.log('  --report <path>             Write a JSON summary report');
  console.log(
    '  --start-offset <N>          Resume the broad volunteers endpoint from this offset',
  );
  console.log(
    '  --max-pages <N>             Stop after N pages (useful for test runs)',
  );
  console.log('  --progress-every-pages <N>  Log progress every N pages');
  console.log('  --help, -h                  Show this help text');
  console.log('');
  console.log('Examples:');
  console.log('  node utilities/reload-volunteer-history.js --dry-run');
  console.log(
    '  node utilities/reload-volunteer-history.js --dry-run --max-pages 5',
  );
  console.log(
    '  node utilities/reload-volunteer-history.js --report utilities/reload-volunteer-history-report.json',
  );
}

function parseOptionalInt(value) {
  if (value == null || value === '') return null;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseNullableInt(value) {
  if (value == null || value === '') return null;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function toDateString(value) {
  if (!value) return null;
  const normalized = typeof value === 'string' ? value : value.toISOString();
  return normalized.split('T')[0];
}

function parseVolunteerRoleIds(rawRoleIds) {
  if (!rawRoleIds || String(rawRoleIds).trim() === '') return [];
  return String(rawRoleIds)
    .split(',')
    .map(value => parseInt(value.trim(), 10))
    .filter(Number.isFinite);
}

function mapVolunteerRoleIdsCsv(roleIds) {
  if (roleIds.length === 0) return null;
  return roleIds.join(',');
}

function firstNonEmptyString(values) {
  for (const value of values) {
    if (value == null) continue;
    const normalized = String(value).trim();
    if (normalized) return normalized;
  }
  return '';
}

function getVolunteerRoleNameFromRaw(raw) {
  return firstNonEmptyString([
    raw?.TaskName,
    raw?.taskName,
    raw?.task_name,
    raw?.VolunteerRoleName,
    raw?.volunteerRoleName,
    raw?.VolunteerRole,
    raw?.volunteerRole,
  ]);
}

function buildRoleNameById(rosterRows) {
  const roleNameById = new Map();

  for (const row of rosterRows) {
    const rawId =
      row?.taskid ??
      row?.taskId ??
      row?.TaskId ??
      row?.TaskID ??
      row?.roleId ??
      row?.RoleId ??
      row?.RoleID;
    const id = parseNullableInt(rawId);
    const name = firstNonEmptyString([
      row?.TaskName,
      row?.taskName,
      row?.taskname,
      row?.VolunteerRoleName,
      row?.volunteerRoleName,
      row?.VolunteerRole,
      row?.volunteerRole,
      row?.Name,
      row?.name,
    ]);

    if (Number.isFinite(id) && name && !roleNameById.has(id)) {
      roleNameById.set(id, name);
    }
  }

  return roleNameById;
}

function volunteerInsertKey(row) {
  return `${row.event_number}-${row.run_id}-${row.event_date}-${row.athlete_id}-${row.task_id}-${row.roster_id}`;
}

function getBigQueryClient() {
  const keyFilename = GOOGLE_CREDENTIALS_PATH || GOOGLE_APPLICATION_CREDENTIALS;
  if (!GCP_PROJECT_ID) {
    throw new Error('Missing required environment variable: GCP_PROJECT_ID');
  }

  return new BigQuery({
    projectId: GCP_PROJECT_ID,
    ...(keyFilename ? { keyFilename: path.resolve(keyFilename) } : {}),
  });
}

function getConfig(args) {
  const eventId = args.junior ? JUNIOR_EVENT_ID : PARKRUN_EVENT_ID;
  const username = args.junior ? JUNIOR_USERNAME : PARKRUN_USERNAME;
  const password = args.junior ? JUNIOR_PASSWORD : PARKRUN_PASSWORD;
  const volunteersTable = args.junior
    ? BIGQUERY_JUNIOR_VOLUNTEERS_TABLE
    : BIGQUERY_VOLUNTEERS_TABLE;

  const missing = [
    ['PARKRUN_CLIENT_ID', PARKRUN_CLIENT_ID],
    ['PARKRUN_CLIENT_SECRET', PARKRUN_CLIENT_SECRET],
    ['eventId', eventId],
    ['username', username],
    ['password', password],
  ].filter(([, value]) => !value);

  if (missing.length > 0) {
    throw new Error(
      `Missing required configuration: ${missing.map(([key]) => key).join(', ')}`,
    );
  }

  return {
    label: args.junior ? 'junior' : 'main',
    eventId: parseInt(eventId, 10),
    username: username.trim(),
    password: password.trim(),
    volunteersTable,
    runFetchDelayMs: RUN_FETCH_DELAY_MS_DEFAULT,
  };
}

async function parkrunAuth(username, password) {
  const body = qs.stringify({
    username,
    password,
    scope: 'app',
    grant_type: 'password',
  });

  const maxAttempts = 4;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const response = await axios.post(
        `${PARKRUN_API_BASE}/user_auth.php`,
        body,
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': PARKRUN_USER_AGENT,
            'X-Powered-By': `parkrun.js/${PARKRUN_VERSION} (https://parkrun.js.org/)`,
          },
          auth: {
            username: PARKRUN_CLIENT_ID,
            password: PARKRUN_CLIENT_SECRET,
          },
        },
      );

      if (!response.data?.access_token) {
        throw new Error('Authentication failed: no access_token in response');
      }

      return response.data.access_token;
    } catch (err) {
      const status = err?.response?.status;
      const retriable =
        status === 403 ||
        status === 429 ||
        status === 500 ||
        status === 502 ||
        status === 503 ||
        status === 504;

      if (!retriable || attempt === maxAttempts) throw err;

      const waitMs = status === 403 ? RETRY_403_MS : attempt * 5000;
      console.warn(
        `Auth: HTTP ${status} attempt ${attempt}/${maxAttempts}; retrying in ${Math.round(waitMs / 1000)}s...`,
      );
      await sleep(waitMs);
    }
  }

  throw new Error('Authentication failed after retries');
}

function makeAuthedClient(accessToken) {
  return axios.create({
    baseURL: PARKRUN_API_BASE,
    headers: {
      'User-Agent': PARKRUN_USER_AGENT,
      'X-Powered-By': `parkrun.js/${PARKRUN_VERSION} (https://parkrun.js.org/)`,
    },
    params: {
      access_token: accessToken,
      scope: 'app',
      expandedDetails: true,
    },
  });
}

async function getWithRetry(client, url, params, label) {
  const maxAttempts = 6;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await client.get(url, { params });
    } catch (err) {
      const status = err?.response?.status;
      const retriable =
        status === 403 ||
        status === 429 ||
        status === 500 ||
        status === 502 ||
        status === 503 ||
        status === 504;

      if (!retriable || attempt === maxAttempts) throw err;

      const waitMs =
        status === 403 ? RETRY_403_MS : Math.max(3000, attempt * 5000);
      console.warn(
        `${label}: HTTP ${status} attempt ${attempt}/${maxAttempts}; retrying in ${Math.round(waitMs / 1000)}s...`,
      );
      await sleep(waitMs);
    }
  }

  throw new Error(`Request failed: ${label}`);
}

async function fetchRunRostersWithRetry(client, eventId, runId) {
  const endpoint = `/v1/events/${eventId}/runs/${runId}/rosters`;
  const maxAttempts = 5;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const firstResponse = await client.get(endpoint, {
        params: { limit: 100, offset: 0 },
      });
      let rows = firstResponse.data?.data?.Rosters || [];
      const range = firstResponse.data?.['Content-Range']?.RostersRange?.[0];
      const total = parseNullableInt(range?.max) || rows.length;

      for (let offset = rows.length; offset < total; offset += 100) {
        const response = await client.get(endpoint, {
          params: { limit: 100, offset },
        });
        rows = rows.concat(response.data?.data?.Rosters || []);
      }

      return rows;
    } catch (err) {
      const status = err?.response?.status;
      const retriable =
        status === 403 ||
        status === 429 ||
        status === 500 ||
        status === 502 ||
        status === 503 ||
        status === 504;

      if (!retriable || attempt === maxAttempts) throw err;

      const waitMs = Math.max(RUN_FETCH_DELAY_MS_DEFAULT, 1000) * attempt;
      console.warn(
        `rosters run ${runId}: HTTP ${status} attempt ${attempt}/${maxAttempts}; retrying in ${Math.round(waitMs / 1000)}s...`,
      );
      await sleep(waitMs);
    }
  }

  return [];
}

async function getRoleNameByRunId(client, config, cache, runId) {
  if (!Number.isFinite(runId)) return new Map();
  if (cache.has(runId)) return cache.get(runId);

  const rosterRows = await fetchRunRostersWithRetry(
    client,
    config.eventId,
    runId,
  );
  const roleNameById = buildRoleNameById(rosterRows);
  cache.set(runId, roleNameById);
  return roleNameById;
}

async function mapVolunteerPageRows(rows, client, config, roleNameCache) {
  const runIdsNeedingRoster = [
    ...new Set(
      rows
        .filter(row => !getVolunteerRoleNameFromRaw(row))
        .map(row => parseNullableInt(row.RunId))
        .filter(Number.isFinite),
    ),
  ];

  for (const runId of runIdsNeedingRoster) {
    await getRoleNameByRunId(client, config, roleNameCache, runId);
    if (config.runFetchDelayMs > 0) {
      await sleep(config.runFetchDelayMs);
    }
  }

  return rows
    .map(row => {
      const roleIds = parseVolunteerRoleIds(row.volunteerRoleIds);
      const runId = parseNullableInt(row.RunId);
      const roleNameById = Number.isFinite(runId)
        ? roleNameCache.get(runId) || new Map()
        : new Map();
      const directName = getVolunteerRoleNameFromRaw(row);
      const taskName =
        directName ||
        (roleIds.length > 0
          ? roleIds.map(id => roleNameById.get(id) || `Role ${id}`).join(', ')
          : 'No role recorded');

      return {
        roster_id: parseNullableInt(row.VolID),
        event_number: parseNullableInt(row.EventNumber),
        run_id: runId,
        event_date: toDateString(row.EventDate),
        athlete_id: parseNullableInt(row.AthleteID),
        task_id: roleIds.length > 0 ? roleIds[0] : null,
        task_ids: mapVolunteerRoleIdsCsv(roleIds),
        task_name: taskName,
        first_name: row.FirstName || null,
        last_name: row.LastName || null,
      };
    })
    .filter(row => row.roster_id != null && row.event_date);
}

async function deleteRowsForEvent(bq, config) {
  const query = [
    `DELETE FROM \`${GCP_PROJECT_ID}.${BIGQUERY_DATASET_ID}.${config.volunteersTable}\``,
    'WHERE event_number = @eventNumber',
  ].join(' ');

  try {
    await bq.query({
      query,
      params: { eventNumber: config.eventId },
      useLegacySql: false,
    });
    return true;
  } catch (err) {
    const message = String(err?.message || err);
    if (message.toLowerCase().includes('streaming buffer')) {
      console.warn(
        `Delete skipped for ${config.volunteersTable} due to streaming buffer; using dedupe fallback.`,
      );
      return false;
    }
    throw err;
  }
}

async function getExistingKeysForEvent(bq, config) {
  const query = [
    `SELECT CONCAT(CAST(event_number AS STRING), '-', CAST(run_id AS STRING), '-', CAST(event_date AS STRING), '-', CAST(athlete_id AS STRING), '-', CAST(task_id AS STRING), '-', CAST(roster_id AS STRING)) AS dedupe_key`,
    `FROM \`${GCP_PROJECT_ID}.${BIGQUERY_DATASET_ID}.${config.volunteersTable}\``,
    'WHERE event_number = @eventNumber',
  ].join(' ');

  const [rows] = await bq.query({
    query,
    params: { eventNumber: config.eventId },
    useLegacySql: false,
  });
  return new Set(rows.map(row => row.dedupe_key).filter(Boolean));
}

async function insertRows(bq, config, rows) {
  if (rows.length === 0) return 0;

  const table = bq.dataset(BIGQUERY_DATASET_ID).table(config.volunteersTable);
  const batchSize = 500;

  for (let index = 0; index < rows.length; index += batchSize) {
    const batch = rows.slice(index, index + batchSize);
    await table.insert(
      batch.map(row => ({ insertId: volunteerInsertKey(row), json: row })),
      {
        raw: true,
        skipInvalidRows: false,
        ignoreUnknownValues: false,
      },
    );
  }

  return rows.length;
}

async function fetchPaged(client, url, options) {
  const {
    dataKey,
    rangeKey,
    baseParams,
    label,
    startOffset,
    maxPages,
    onPage,
  } = options;

  const normalizedStart = Math.floor(startOffset / PAGE_SIZE) * PAGE_SIZE;
  const firstResponse = await getWithRetry(
    client,
    url,
    { ...baseParams, limit: PAGE_SIZE, offset: normalizedStart },
    `${label} offset=${normalizedStart}`,
  );

  const firstRows = firstResponse.data?.data?.[dataKey] || [];
  const range = firstResponse.data?.['Content-Range']?.[rangeKey]?.[0];
  const total = parseNullableInt(range?.max);

  if (!Number.isFinite(total)) {
    throw new Error(`${label}: missing/invalid Content-Range ${rangeKey}.max`);
  }

  if (normalizedStart >= total) {
    return { totalRows: 0, totalPages: 0, fetchedPages: 0 };
  }

  const totalPages = Math.ceil((total - normalizedStart) / PAGE_SIZE);
  let totalRows = 0;
  let fetchedPages = 0;

  async function processPage(rows) {
    fetchedPages += 1;
    totalRows += rows.length;
    await onPage(rows, { fetchedPages, totalPages });
  }

  await processPage(firstRows);
  if (maxPages !== null && fetchedPages >= maxPages) {
    return { totalRows, totalPages, fetchedPages };
  }

  for (
    let offset = normalizedStart + PAGE_SIZE;
    offset < total;
    offset += PAGE_SIZE
  ) {
    const response = await getWithRetry(
      client,
      url,
      { ...baseParams, limit: PAGE_SIZE, offset },
      `${label} offset=${offset}`,
    );
    const rows = response.data?.data?.[dataKey] || [];
    await processPage(rows);
    if (maxPages !== null && fetchedPages >= maxPages) {
      break;
    }
  }

  return { totalRows, totalPages, fetchedPages };
}

async function writeReport(reportPath, payload) {
  const absolutePath = path.resolve(reportPath);
  await fs.promises.mkdir(path.dirname(absolutePath), { recursive: true });
  await fs.promises.writeFile(absolutePath, JSON.stringify(payload, null, 2));
  console.log(`Wrote report: ${absolutePath}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printUsage();
    return;
  }

  const config = getConfig(args);
  const bq = getBigQueryClient();

  console.log(
    `Reloading volunteer history (${config.label}) into ${config.volunteersTable}${args.dryRun ? ' [dry-run]' : ''}.`,
  );
  console.log(
    `start_offset=${args.startOffset}, max_pages=${args.maxPages ?? 'all'}, progress_every_pages=${args.progressEveryPages}`,
  );

  const token = await parkrunAuth(config.username, config.password);
  const client = makeAuthedClient(token);
  const roleNameCache = new Map();

  let existingKeys = null;
  if (!args.dryRun) {
    const deleted = await deleteRowsForEvent(bq, config);
    if (!deleted) {
      existingKeys = await getExistingKeysForEvent(bq, config);
    }
  }

  let insertedRows = 0;
  let mappedRowsTotal = 0;
  let unresolvedRowsTotal = 0;
  const unresolvedTaskIds = new Map();

  const fetchSummary = await fetchPaged(client, '/v1/volunteers', {
    dataKey: 'Volunteers',
    rangeKey: 'VolunteersRange',
    baseParams: { eventNumber: config.eventId },
    label: `[${config.label}] volunteers reload`,
    startOffset: args.startOffset,
    maxPages: args.maxPages,
    onPage: async (rows, pageMeta) => {
      const mappedRows = await mapVolunteerPageRows(
        rows,
        client,
        config,
        roleNameCache,
      );
      mappedRowsTotal += mappedRows.length;

      const unresolvedRows = mappedRows.filter(row =>
        FALLBACK_ROLE_REGEX.test(row.task_name || ''),
      );
      unresolvedRowsTotal += unresolvedRows.length;
      for (const row of unresolvedRows) {
        if (!Number.isFinite(row.task_id)) continue;
        unresolvedTaskIds.set(
          row.task_id,
          (unresolvedTaskIds.get(row.task_id) || 0) + 1,
        );
      }

      let rowsToInsert = mappedRows;
      if (existingKeys) {
        rowsToInsert = mappedRows.filter(row => {
          const key = volunteerInsertKey(row);
          if (existingKeys.has(key)) return false;
          existingKeys.add(key);
          return true;
        });
      }

      if (!args.dryRun && rowsToInsert.length > 0) {
        insertedRows += await insertRows(bq, config, rowsToInsert);
      }

      if (
        pageMeta.fetchedPages % args.progressEveryPages === 0 ||
        pageMeta.fetchedPages === pageMeta.totalPages ||
        (args.maxPages !== null && pageMeta.fetchedPages === args.maxPages)
      ) {
        console.log(
          `[${config.label}] page ${pageMeta.fetchedPages}/${pageMeta.totalPages}: mapped ${mappedRowsTotal} row(s), unresolved ${unresolvedRowsTotal}${args.dryRun ? '' : `, inserted ${insertedRows}`}.`,
        );
      }
    },
  });

  const report = {
    generated_at: new Date().toISOString(),
    dry_run: args.dryRun,
    label: config.label,
    event_id: config.eventId,
    volunteers_table: config.volunteersTable,
    start_offset: args.startOffset,
    max_pages: args.maxPages,
    fetched_pages: fetchSummary.fetchedPages,
    fetched_rows: fetchSummary.totalRows,
    mapped_rows: mappedRowsTotal,
    inserted_rows: insertedRows,
    unresolved_rows_after_mapping: unresolvedRowsTotal,
    unresolved_task_ids: [...unresolvedTaskIds.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([taskId, count]) => ({ task_id: taskId, row_count: count })),
  };

  if (args.reportPath) {
    await writeReport(args.reportPath, report);
  }

  console.log('');
  console.log(`Fetched rows: ${fetchSummary.totalRows}`);
  console.log(`Mapped rows: ${mappedRowsTotal}`);
  console.log(`Unresolved rows after mapping: ${unresolvedRowsTotal}`);
  if (!args.dryRun) {
    console.log(`Inserted rows: ${insertedRows}`);
  }
}

main().catch(err => {
  console.error(err?.stack || err?.message || String(err));
  process.exit(1);
});
