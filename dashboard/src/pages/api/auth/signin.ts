import type { APIRoute } from 'astro';
import { getAuth } from 'firebase-admin/auth';
import '../../../lib/firebase-admin';

export const POST: APIRoute = async ({ request, cookies }) => {
  const idToken = request.headers.get('Authorization')?.split('Bearer ')[1];
  if (!idToken) {
    return new Response('No token found', { status: 401 });
  }

  try {
    const auth = getAuth();
    await auth.verifyIdToken(idToken);

    // Create a session cookie valid for 5 days
    const expiresIn = 60 * 60 * 24 * 5 * 1000;
    const sessionCookie = await auth.createSessionCookie(idToken, {
      expiresIn,
    });

    // Note: Cookie name must be __session for Firebase Hosting to preserve it
    cookies.set('__session', sessionCookie, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'strict',
      maxAge: expiresIn / 1000,
    });

    return new Response(JSON.stringify({ status: 'success' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Auth Error:', error);
    return new Response('Unauthorized', { status: 401 });
  }
};
