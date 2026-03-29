import { defineMiddleware } from 'astro:middleware';
import { getAuth } from 'firebase-admin/auth';
import './lib/firebase-admin'; // Ensure admin is initialized

export const onRequest = defineMiddleware(async (context, next) => {
  const sessionCookie = context.cookies.get('__session')?.value;

  if (sessionCookie) {
    try {
      const auth = getAuth();
      // Verify the session cookie. The second parameter 'true' checks if the
      // user has been disabled or had their session revoked.
      const decodedClaims = await auth.verifySessionCookie(sessionCookie, true);
      context.locals.user = decodedClaims;
    } catch (error) {
      // If invalid or expired, clear the cookie
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
