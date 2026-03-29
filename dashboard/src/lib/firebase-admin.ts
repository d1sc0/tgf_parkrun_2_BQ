import { initializeApp, getApps, cert } from 'firebase-admin/app';
import path from 'node:path';

/**
 * Initialize Firebase Admin SDK using Application Default Credentials.
 * For local development, it uses GOOGLE_APPLICATION_CREDENTIALS.
 * For Firebase App Hosting, it automatically uses ADC.
 */
if (!getApps().length) {
  const keyFilename = import.meta.env.GOOGLE_APPLICATION_CREDENTIALS;
  const projectId =
    import.meta.env.GCP_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT;

  if (!projectId) {
    console.error(
      'Firebase Admin: No Project ID detected in environment variables.',
    );
  }

  initializeApp({
    projectId,
    ...(keyFilename ? { credential: cert(path.resolve(keyFilename)) } : {}),
  });
}
