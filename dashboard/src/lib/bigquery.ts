import { BigQuery } from '@google-cloud/bigquery';

const projectId = import.meta.env.GCP_PROJECT_ID;
const keyFilename = import.meta.env.GOOGLE_APPLICATION_CREDENTIALS;

export const bq = new BigQuery({
  projectId,
  // If keyFilename is provided (local dev), use it.
  // If not (Firebase), it falls back to Application Default Credentials.
  ...(keyFilename ? { keyFilename } : {}),
});

export async function runQuery(query: string, params = {}) {
  const [rows] = await bq.query({ query, params });
  return rows;
}
