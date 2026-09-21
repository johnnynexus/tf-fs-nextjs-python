/**
 * A single headline number.
 *
 * Deliberately not a chart: a lone value is read faster as text than as a
 * one-bar bar chart. The optional sparkline carries trend without turning
 * the tile into a full panel.
 */

import { linePath, scaleLinear, type Point } from '@/lib/viz';

export function StatTile({
  label,
  value,
  detail,
  spark,
  accent = 'var(--seq-4)',
}: {
  label: string;
  value: string;
  detail?: string;
  /** Optional trend values, rendered as a bare sparkline. */
  spark?: number[];
  accent?: string;
}) {
  return (
    <div
      className="rounded-xl border p-4"
      style={{ backgroundColor: 'var(--surface-2)', borderColor: 'var(--border-subtle)' }}
    >
      <p
        className="text-[11px] font-medium uppercase tracking-wide"
        style={{ color: 'var(--text-muted)' }}
      >
        {label}
      </p>
      {/* Proportional sans, not mono/tabular: equal-width digits make a
          large standalone number look loose. tabular-nums is for columns
          that align vertically - table rows and axis ticks. */}
      <p className="mt-1 text-2xl font-semibold" style={{ color: 'var(--text-primary)' }}>
        {value}
      </p>
      {detail && (
        <p className="mt-0.5 text-xs" style={{ color: 'var(--text-secondary)' }}>
          {detail}
        </p>
      )}
      {spark && spark.length > 1 && <Sparkline values={spark} accent={accent} />}
    </div>
  );
}

function Sparkline({ values, accent }: { values: number[]; accent: string }) {
  const width = 120;
  const height = 24;
  const max = Math.max(1, ...values);
  const x = scaleLinear([0, values.length - 1], [0, width]);
  const y = scaleLinear([0, max], [height - 1, 1]);
  const points: Point[] = values.map((value, index) => ({ x: x(index), y: y(value) }));

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="mt-2 w-full"
      // Decorative: the number above already states the value.
      aria-hidden="true"
      preserveAspectRatio="none"
    >
      <path d={linePath(points)} fill="none" stroke={accent} strokeWidth={1.5} />
    </svg>
  );
}
