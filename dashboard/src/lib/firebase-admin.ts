import {
  initializeApp,
  getApps,
  cert,
  type AppOptions,
} from 'firebase-admin/app';
import path from 'node:path';

/**
 * Initialize Firebase Admin SDK using Application Default Credentials.
 * For local development, it uses GOOGLE_APPLICATION_CREDENTIALS.
 * For Firebase App Hosting, it automatically uses ADC.
 */
if (!getApps().length) {
  // Check both process.env (Production) and import.meta.env (Local Dev)
  const keyFilename =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    import.meta.env.GOOGLE_APPLICATION_CREDENTIALS;
  const projectId =
    process.env.GCP_PROJECT_ID ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    import.meta.env.GCP_PROJECT_ID;

  if (!projectId) {
    console.error(
      'Firebase Admin: No Project ID detected in environment variables.',
    );
  }

  const options: AppOptions = {};
  if (projectId) options.projectId = projectId;
  if (keyFilename) options.credential = cert(path.resolve(keyFilename));

  initializeApp(options);
}
