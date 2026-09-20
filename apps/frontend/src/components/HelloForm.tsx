'use client';

/**
 * Client Component: the browser-side half of the connectivity proof.
 *
 * Calls the backend from the browser through whichever path
 * PUBLIC_API_BASE_URL resolves to (same-origin proxy by default, direct
 * cross-origin when NEXT_PUBLIC_API_BASE_URL is set at build time).
 */

import { useState } from 'react';

import { StatusBadge, type StatusTone } from '@/components/StatusBadge';
import { ApiError, PUBLIC_API_BASE_URL, fetchHello, type HelloResponse } from '@/lib/api';

export function HelloForm() {
  const [name, setName] = useState('world');
  const [result, setResult] = useState<HelloResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setError(null);

    try {
      setResult(await fetchHello(name));
    } catch (caught) {
      setResult(null);
      setError(
        caught instanceof ApiError ? caught.message : 'Unexpected error calling backend',
      );
    } finally {
      setLoading(false);
    }
  }

  const tone: StatusTone = error ? 'error' : result ? 'ok' : 'pending';
  const label = error ? 'failed' : result ? 'connected' : 'not called yet';

  return (
    <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900">
      <header className="mb-4 flex items-center justify-between">
        <h2 className="text-base font-semibold">Browser-side API call</h2>
        <StatusBadge tone={tone}>{label}</StatusBadge>
      </header>

      <form onSubmit={onSubmit} className="flex flex-wrap items-center gap-3">
        <label htmlFor="name" className="sr-only">
          Name to greet
        </label>
        <input
          id="name"
          value={name}
          onChange={(event) => setName(event.target.value)}
          maxLength={100}
          placeholder="world"
          className="min-w-0 flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-slate-500 focus:ring-2 focus:ring-slate-200 dark:border-slate-700 dark:bg-slate-950 dark:focus:ring-slate-800"
        />
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white transition hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-white"
        >
          {loading ? 'Calling…' : 'Call /hello'}
        </button>
      </form>

      {result && (
        <p className="mt-4 rounded-lg bg-slate-50 p-3 font-mono text-sm dark:bg-slate-950">
          {result.message}
        </p>
      )}

      {error && (
        <p className="mt-4 rounded-lg bg-rose-50 p-3 text-sm text-rose-800 dark:bg-rose-950/40 dark:text-rose-200">
          {error}
        </p>
      )}

      <p className="mt-4 text-xs text-slate-500 dark:text-slate-400">
        Requests go to <code className="font-mono">{PUBLIC_API_BASE_URL}/hello</code>
        {PUBLIC_API_BASE_URL.startsWith('/')
          ? ' (same-origin proxy — no CORS preflight).'
          : ' (direct cross-origin call — relies on backend CORS).'}
      </p>
    </section>
  );
}
