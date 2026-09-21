'use client';

/**
 * The interactive dashboard.
 *
 * Receives server-rendered data as `initial`, so the first paint is complete
 * HTML with no spinner and no client waterfall. Changing the time window
 * refetches in the browser through the same-origin /api/backend proxy -
 * which means this one page exercises both data paths the architecture
 * provides.
 */

import { useCallback, useEffect, useState, useTransition } from 'react';

import { ChartFrame } from '@/components/charts/ChartFrame';
import { DepthScatter } from '@/components/charts/DepthScatter';
import { MagnitudeChart } from '@/components/charts/MagnitudeChart';
import { RegionChart } from '@/components/charts/RegionChart';
import { TimelineChart } from '@/components/charts/TimelineChart';
import { AlertChip } from '@/components/dashboard/AlertChip';
import { EventsTable } from '@/components/dashboard/EventsTable';
import { StatTile } from '@/components/dashboard/StatTile';
import {
  ApiError,
  fetchQuakeSummary,
  type QuakeSummary,
  type TimeWindow,
} from '@/lib/api';
import { formatMagnitude, formatRelative } from '@/lib/viz';

const WINDOWS: { value: TimeWindow; label: string }[] = [
  { value: 'day', label: '24 hours' },
  { value: 'week', label: '7 days' },
  { value: 'month', label: '30 days' },
];

/**
 * True only after the first client render. Used to gate clock-dependent
 * output ("3m ago"), which cannot match between server and client and would
 * otherwise be a hydration mismatch.
 */
function useMounted(): boolean {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  return mounted;
}

export function DashboardView({ initial }: { initial: QuakeSummary }) {
  const mounted = useMounted();
  const [summary, setSummary] = useState(initial);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [loadingWindow, setLoadingWindow] = useState<TimeWindow | null>(null);

  const selectWindow = useCallback(
    (next: TimeWindow) => {
      if (next === summary.window) return;
      setLoadingWindow(next);
      setError(null);

      void fetchQuakeSummary(next, summary.min_magnitude)
        .then((data) => startTransition(() => setSummary(data)))
        .catch((caught: unknown) => {
          setError(
            caught instanceof ApiError
              ? caught.message
              : 'Could not load data for that range.',
          );
        })
        .finally(() => setLoadingWindow(null));
    },
    [summary.window, summary.min_magnitude],
  );

  const { stats } = summary;
  const busy = pending || loadingWindow !== null;

  return (
    <div className="space-y-5">
      {/* Filters live in one row above the charts. */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          className="inline-flex rounded-lg border p-0.5"
          role="group"
          aria-label="Time range"
          style={{ borderColor: 'var(--border-subtle)' }}
        >
          {WINDOWS.map((option) => {
            const selected = option.value === summary.window;
            return (
              <button
                key={option.value}
                type="button"
                onClick={() => selectWindow(option.value)}
                disabled={busy}
                aria-pressed={selected}
                // Generous hit target, well above the 8px floor.
                className="rounded-md px-3 py-1.5 text-xs font-medium transition disabled:opacity-60"
                style={{
                  backgroundColor: selected ? 'var(--seq-4)' : 'transparent',
                  color: selected ? '#ffffff' : 'var(--text-secondary)',
                }}
              >
                {loadingWindow === option.value ? 'Loading…' : option.label}
              </button>
            );
          })}
        </div>

        <p className="text-xs" style={{ color: 'var(--text-muted)' }}>
          M{summary.min_magnitude}+ · times in UTC
          {/* Clock-dependent, so client-only. */}
          {mounted && ` · updated ${formatRelative(summary.generated_at)}`}
          {summary.cached && ' · cached'}
        </p>
      </div>

      {error && (
        <div
          className="rounded-lg border px-4 py-3 text-sm"
          role="alert"
          style={{
            borderColor: 'var(--status-critical)',
            color: 'var(--text-primary)',
          }}
        >
          {error}
        </div>
      )}

      {/* Content dims during a refetch rather than collapsing to a
          skeleton - no layout jump, and the previous numbers stay readable
          while the new ones load. */}
      <div
        className="space-y-5 transition-opacity duration-200"
        style={{ opacity: busy ? 0.55 : 1 }}
      >
        {/* Hero figure: the one number the page leads with. */}
        <section
          className="rounded-xl border p-6"
          style={{
            backgroundColor: 'var(--surface-2)',
            borderColor: 'var(--border-subtle)',
          }}
        >
          <p
            className="text-[11px] font-medium uppercase tracking-wide"
            style={{ color: 'var(--text-muted)' }}
          >
            Strongest event
          </p>
          <div className="mt-1 flex flex-wrap items-baseline gap-x-4 gap-y-1">
            {/* Same sans as everything else, proportional figures. */}
            <span
              className="text-5xl font-semibold tracking-tight"
              style={{ color: 'var(--text-primary)' }}
            >
              {formatMagnitude(stats.max_magnitude)}
            </span>
            <span className="text-sm" style={{ color: 'var(--text-secondary)' }}>
              {stats.strongest?.place ?? 'No events recorded'}
            </span>
            {stats.strongest?.alert && <AlertChip level={stats.strongest.alert} />}
          </div>
        </section>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatTile
            label="Total events"
            value={stats.total_events.toLocaleString()}
            detail={`in the last ${summary.window === 'day' ? '24 hours' : summary.window === 'week' ? '7 days' : '30 days'}`}
            spark={summary.timeline.map((bucket) => bucket.count)}
          />
          <StatTile
            label="Significant"
            value={stats.significant_count.toLocaleString()}
            detail="magnitude 4.5 or greater"
          />
          <StatTile
            label="Median depth"
            value={stats.median_depth_km == null ? '—' : `${stats.median_depth_km} km`}
            detail="half were shallower"
          />
          <StatTile
            label="Tsunami flagged"
            value={stats.tsunami_count.toLocaleString()}
            detail="events with a tsunami notice"
          />
        </div>

        <ChartFrame
          title="Events over time"
          subtitle={`Count per ${summary.window === 'day' ? 'hour' : summary.window === 'week' ? '6 hours' : 'day'}`}
          caption="Hover for the exact count and strongest event in each bucket. Empty periods are shown, not skipped."
        >
          <TimelineChart buckets={summary.timeline} window={summary.window} />
        </ChartFrame>

        <div className="grid gap-4 lg:grid-cols-2">
          <ChartFrame
            title="Magnitude distribution"
            subtitle="Events per magnitude band"
            caption="Colour tracks the magnitude band; bar height is how many events fell in it."
          >
            <MagnitudeChart bins={summary.magnitude_bins} />
          </ChartFrame>

          <ChartFrame
            title="Most active regions"
            subtitle="Top regions by event count"
            caption="Regions are derived from the USGS place description."
          >
            <RegionChart regions={summary.top_regions} />
          </ChartFrame>
        </div>

        <ChartFrame
          title="Depth versus magnitude"
          subtitle={`${summary.depth_magnitude.length} strongest events`}
          caption="Depth increases downward, so the earth's surface is at the top. Most quakes are shallow; deep events cluster along subduction zones."
        >
          <DepthScatter points={summary.depth_magnitude} />
        </ChartFrame>

        <ChartFrame
          title="Recent significant events"
          subtitle="Magnitude 4.5 and above, most recent first"
          caption="The same data in tabular form — also the accessible path to everything plotted above."
        >
          <EventsTable events={summary.recent_significant} />
        </ChartFrame>
      </div>
    </div>
  );
}
