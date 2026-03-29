import { defineMiddleware } from 'astro:middleware';
import { getAuth } from 'firebase-admin/auth';
import './lib/firebase-admin'; // Ensure admin is initialized

export const onRequest = defineMiddleware(async (context, next) => {
  const sessionCookie = context.cookies.get('__session')?.value;

  if (sessionCookie) {
    try {
      const auth = getAuth();
      // Verify the session cookie.
      // Note: Setting the second parameter to 'true' (checkRevoked) requires the
      // App Hosting service account to have the 'Firebase Authentication Admin' role.
      // We'll set it to false temporarily to verify if IAM permissions are the bottleneck.
      const decodedClaims = await auth.verifySessionCookie(
        sessionCookie,
        false,
      );
      context.locals.user = decodedClaims;
    } catch (error) {
      console.error('Firebase Auth Middleware Error:', error);
      // If invalid, expired, or permission error, clear the cookie
      context.cookies.delete('__session', { path: '/' });
    }
  }

  // Redirect logic for protected pages
  const isProtected = context.url.pathname.startsWith('/top-lists');

  if (isProtected && !context.locals.user) {
    return context.redirect('/login');
  }

  // If trying to access login while already logged in
  if (context.url.pathname === '/login' && context.locals.user) {
    return context.redirect('/');
  }

  return next();
});
