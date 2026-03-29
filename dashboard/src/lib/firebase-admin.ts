import { initializeApp, getApps, cert } from 'firebase-admin/app';
import path from 'node:path';

/**
 * Initialize Firebase Admin SDK using Application Default Credentials.
 * For local development, it uses GOOGLE_APPLICATION_CREDENTIALS.
 * For Firebase App Hosting, it automatically uses ADC.
 */
if (!getApps().length) {
  // Use process.env for reliable access to system variables in production SSR
  const keyFilename = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const projectId =
    process.env.GCP_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT;

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
