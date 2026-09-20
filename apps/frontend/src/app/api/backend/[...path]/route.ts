/**
 * Same-origin proxy to the backend.
 *
 * `/api/backend/<path>`  ->  `${BACKEND_INTERNAL_URL}/api/v1/<path>`
 *
 * Why this exists: the browser bundle is produced by `next build`, but the
 * backend's Cloud Run URL is only known after Terraform applies. Reading the
 * target here - on the server, at request time - means the same image works in
 * every environment, and the browser makes same-origin requests (no CORS
 * preflight, no backend URL leaked into client JS).
 */

import { NextResponse, type NextRequest } from 'next/server';

import { BACKEND_INTERNAL_URL } from '@/lib/api';

// Never prerender or cache: this route must read env and forward live.
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

const UPSTREAM_TIMEOUT_MS = 10_000;

/** Methods the proxy is willing to forward. */
const ALLOWED_METHODS = new Set(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);

/**
 * Request headers that must not be forwarded upstream: hop-by-hop headers and
 * anything describing the original connection rather than the payload.
 */
const STRIPPED_REQUEST_HEADERS = new Set([
  'host',
  'connection',
  'keep-alive',
  'transfer-encoding',
  'upgrade',
  'content-length',
]);

async function proxy(
  request: NextRequest,
  context: { params: Promise<{ path: string[] }> },
): Promise<NextResponse> {
  if (!ALLOWED_METHODS.has(request.method)) {
    return NextResponse.json({ detail: 'Method not allowed' }, { status: 405 });
  }

  // In Next 15 route params are async and must be awaited.
  const { path } = await context.params;

  // Rebuild the upstream URL, preserving the query string.
  const suffix = path.map(encodeURIComponent).join('/');
  const search = request.nextUrl.search;
  const target = `${BACKEND_INTERNAL_URL}/api/v1/${suffix}${search}`;

  const headers = new Headers();
  request.headers.forEach((value, key) => {
    if (!STRIPPED_REQUEST_HEADERS.has(key.toLowerCase())) {
      headers.set(key, value);
    }
  });

  const hasBody = !['GET', 'HEAD'].includes(request.method);

  try {
    const upstream = await fetch(target, {
      method: request.method,
      headers,
      body: hasBody ? await request.text() : undefined,
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      cache: 'no-store',
    });

    // Stream the body back untouched, preserving status and content type.
    const body = await upstream.arrayBuffer();
    return new NextResponse(body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: {
        'content-type': upstream.headers.get('content-type') ?? 'application/json',
        'cache-control': 'no-store',
      },
    });
  } catch (error) {
    // 502: the frontend is healthy, the upstream is not.
    console.error(`[proxy] ${request.method} ${target} failed`, error);
    return NextResponse.json(
      {
        detail: 'Backend request failed',
        error: error instanceof Error ? error.message : 'unknown error',
      },
      { status: 502 },
    );
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
