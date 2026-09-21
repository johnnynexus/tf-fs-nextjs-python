'use client';

/**
 * Floating tooltip positioned inside the chart's bounding box.
 *
 * Clamped to the container so a mark near the right edge does not push the
 * tooltip off-screen - the single most common hover-layer bug.
 */

export interface TooltipRow {
  label: string;
  value: string;
}

export function Tooltip({
  x,
  y,
  width,
  title,
  rows,
  visible,
}: {
  x: number;
  y: number;
  /** Container width, used to decide which side to flip to. */
  width: number;
  title: string;
  rows: TooltipRow[];
  visible: boolean;
}) {
  if (!visible) return null;

  const TOOLTIP_WIDTH = 190;
  // Flip to the left of the cursor when close to the right edge.
  const flip = x + TOOLTIP_WIDTH + 16 > width;
  const left = flip ? x - TOOLTIP_WIDTH - 12 : x + 12;

  return (
    <div
      role="tooltip"
      className="pointer-events-none absolute z-10 rounded-lg border px-3 py-2 text-xs shadow-lg"
      style={{
        left: Math.max(4, left),
        top: Math.max(4, y - 8),
        width: TOOLTIP_WIDTH,
        backgroundColor: 'var(--surface-2)',
        borderColor: 'var(--border-subtle)',
        color: 'var(--text-primary)',
      }}
    >
      <p className="mb-1 font-medium leading-snug">{title}</p>
      {rows.map((row) => (
        <div key={row.label} className="flex justify-between gap-3">
          <span style={{ color: 'var(--text-secondary)' }}>{row.label}</span>
          {/* Values wear text tokens, never the series colour. */}
          <span className="font-mono" style={{ color: 'var(--text-primary)' }}>
            {row.value}
          </span>
        </div>
      ))}
    </div>
  );
}
