/**
 * Server Component: fetches the backend health endpoint during SSR.
 *
 * This is the server-to-server half of the connectivity proof. It runs inside
 * the Next.js container and talks to BACKEND_INTERNAL_URL directly, so it
 * exercises a completely different network path than the browser call in
 * HelloForm - useful for telling "backend is down" apart from "CORS/proxy is
 * misconfigured".
 */

import { StatusBadge } from '@/components/StatusBadge';
import { ApiError, BACKEND_INTERNAL_URL, fetchBackendHealth } from '@/lib/api';

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 py-1.5">
      <dt className="text-sm text-slate-500 dark:text-slate-400">{label}</dt>
      <dd className="font-mono text-sm">{value}</dd>
    </div>
  );
}

export async function BackendHealthCard() {
  try {
    const health = await fetchBackendHealth();

    return (
      <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900">
        <header className="mb-4 flex items-center justify-between">
          <h2 className="text-base font-semibold">Server-side health check</h2>
          <StatusBadge tone="ok">connected</StatusBadge>
        </header>

        <dl className="divide-y divide-slate-100 dark:divide-slate-800">
          <Row label="Service" value={health.service} />
          <Row label="Environment" value={health.environment} />
          <Row label="Release" value={health.release} />
          <Row label="Upstream" value={BACKEND_INTERNAL_URL} />
        </dl>
      </section>
    );
  } catch (error) {
    const message =
      error instanceof ApiError ? error.message : 'Unexpected error contacting backend';

    return (
      <section className="rounded-xl border border-rose-200 bg-rose-50 p-6 dark:border-rose-900 dark:bg-rose-950/40">
        <header className="mb-3 flex items-center justify-between">
          <h2 className="text-base font-semibold">Server-side health check</h2>
          <StatusBadge tone="error">unreachable</StatusBadge>
        </header>
        <p className="text-sm text-rose-800 dark:text-rose-200">{message}</p>
        <p className="mt-3 text-xs text-rose-700/80 dark:text-rose-300/80">
          Tried <code className="font-mono">{BACKEND_INTERNAL_URL}/health</code>. Check
          that the backend is running and that{' '}
          <code className="font-mono">BACKEND_INTERNAL_URL</code> is set correctly.
        </p>
      </section>
    );
  }
}
