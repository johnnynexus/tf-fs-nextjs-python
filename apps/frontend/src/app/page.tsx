import Link from 'next/link';

import { BackendHealthCard } from '@/components/BackendHealthCard';
import { HelloForm } from '@/components/HelloForm';

// Health is checked per request, so the page must not be statically
// prerendered at build time (when no backend exists).
export const dynamic = 'force-dynamic';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-6 px-6 py-16">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">
          Next.js → FastAPI connectivity
        </h1>
        <p className="mt-2 text-sm text-slate-600 dark:text-slate-400">
          Two independent round trips to the backend: one from the Next.js server during
          render, one from your browser. Both must be green for the stack to be wired
          correctly.
        </p>
      </header>

      {/* Server Component - runs during SSR, inside the frontend container. */}
      <BackendHealthCard />

      {/* Client Component - runs in the browser. */}
      <HelloForm />

      <Link
        href="/dashboard"
        className="group rounded-xl border border-slate-200 bg-white p-5 transition hover:border-slate-400 dark:border-slate-800 dark:bg-slate-900 dark:hover:border-slate-600"
      >
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="text-base font-semibold">Seismic dashboard →</h2>
            <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Live USGS earthquake data, aggregated by the backend and charted without a
              charting library.
            </p>
          </div>
        </div>
      </Link>

      <footer className="text-xs text-slate-500 dark:text-slate-400">
        Backend API docs: <code className="font-mono">/docs</code> on the backend service.
      </footer>
    </main>
  );
}
