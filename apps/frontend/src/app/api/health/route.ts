/**
 * Frontend liveness endpoint.
 *
 * Deliberately does NOT call the backend: this reports whether the Next.js
 * server itself is up. Mixing in a dependency check here would make Cloud Run
 * restart healthy frontend containers during a backend outage.
 */

import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export function GET() {
  return NextResponse.json({
    status: 'ok',
    service: 'frontend',
    release: process.env.NEXT_PUBLIC_RELEASE ?? 'dev',
  });
}
