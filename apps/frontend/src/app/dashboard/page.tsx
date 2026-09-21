/**
 * Seismic dashboard.
 *
 * Server Component: the initial fetch happens inside the Next.js container
 * over the server-to-server path, so the browser receives fully rendered
 * HTML. The interactive shell below takes over for filter changes.
 */

import Link from 'next/link';

import { DashboardView } from '@/components/dashboard/DashboardView';
import { ApiError, fetchQuakeSummarySSR } from '@/lib/api';

// Live data: never statically prerendered, never cached between requests.
export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'Seismic activity · tf-fs-nextjs-python',
  description:
    'Live global earthquake activity, served through FastAPI from the USGS feed.',
};

export default async function DashboardPage() {
  let summary = null;
  let error: string | null = null;

  try {
    summary = await fetchQuakeSummarySSR('week');
  } catch (caught) {
    // A third-party outage degrades this page and nothing else - the rest of
    // the app, and both health endpoints, are unaffected.
    error =
      caught instanceof ApiError
        ? caught.message
        : 'Unexpected error loading earthquake data.';
  }

  return (
    <div className="viz-root min-h-screen">
      <div className="mx-auto max-w-5xl px-6 py-10">
        <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1
              className="text-2xl font-semibold tracking-tight"
              style={{ color: 'var(--text-primary)' }}
            >
              Global seismic activity
            </h1>
            <p className="mt-1 text-sm" style={{ color: 'var(--text-secondary)' }}>
              Live USGS data, fetched and aggregated by the FastAPI backend, rendered
              without a charting library.
            </p>
          </div>

          <Link
            href="/"
            className="rounded-lg border px-3 py-1.5 text-xs font-medium transition"
            style={{
              borderColor: 'var(--border-subtle)',
              color: 'var(--text-secondary)',
            }}
          >
            ← Connectivity check
          </Link>
        </header>

        {summary ? (
          <DashboardView initial={summary} />
        ) : (
          <div
            className="rounded-xl border p-8 text-center"
            style={{
              borderColor: 'var(--status-critical)',
              backgroundColor: 'var(--surface-2)',
            }}
          >
            <p className="text-sm font-medium" style={{ color: 'var(--text-primary)' }}>
              Earthquake data is unavailable right now.
            </p>
            <p className="mt-2 text-xs" style={{ color: 'var(--text-secondary)' }}>
              {error}
            </p>
            <p className="mt-4 text-xs" style={{ color: 'var(--text-muted)' }}>
              The backend is reachable — its upstream USGS feed is not. The rest of the
              application, including both health endpoints, is unaffected.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
