import { BigQuery } from '@google-cloud/bigquery';

// Ensure we check both system env and Astro/Vite env
const projectId =
  process.env.GCP_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  import.meta.env.GCP_PROJECT_ID;

const keyFilename =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  import.meta.env.GOOGLE_APPLICATION_CREDENTIALS;

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
