/**
 * Minimal visualisation primitives.
 *
 * This is the whole reason no charting library is needed: scales, ticks and
 * path builders are about a hundred lines, and writing them directly means
 * the marks match the project's spec exactly instead of fighting a library's
 * defaults.
 *
 * Everything is pure and framework-agnostic, so it is trivially testable.
 */

export interface Scale {
  (value: number): number;
  /** Inverse mapping, used to turn a pointer position back into a datum. */
  invert(pixel: number): number;
  domain: readonly [number, number];
  range: readonly [number, number];
}

/** Continuous linear scale. Guards against a zero-width domain. */
export function scaleLinear(
  domain: readonly [number, number],
  range: readonly [number, number],
): Scale {
  const [d0, d1] = domain;
  const [r0, r1] = range;
  // A single-valued domain would divide by zero; map it to the range midpoint.
  const span = d1 - d0 || 1;

  const scale = ((value: number) => r0 + ((value - d0) / span) * (r1 - r0)) as Scale;
  scale.invert = (pixel: number) => d0 + ((pixel - r0) / (r1 - r0 || 1)) * span;
  scale.domain = domain;
  scale.range = range;
  return scale;
}

/**
 * Band scale for categorical axes. `padding` is the fraction of each slot
 * left empty, which produces the 2px-plus gap between adjacent bars that the
 * mark spec requires.
 */
export function scaleBand(
  count: number,
  range: readonly [number, number],
  padding = 0.2,
) {
  const [r0, r1] = range;
  const step = count > 0 ? (r1 - r0) / count : 0;
  const bandwidth = Math.max(step * (1 - padding), 1);
  return {
    step,
    bandwidth,
    /** Left edge of band `index`. */
    at: (index: number) => r0 + index * step + (step - bandwidth) / 2,
    /** Centre of band `index`, for tick labels and markers. */
    center: (index: number) => r0 + index * step + step / 2,
    /** Which band a pixel falls in; -1 when outside. */
    indexAt: (pixel: number) => {
      if (step <= 0) return -1;
      const index = Math.floor((pixel - r0) / step);
      return index >= 0 && index < count ? index : -1;
    },
  };
}

/**
 * "Nice" axis ticks: round numbers at a human-friendly interval, always
 * including the bounds. Raw min/max produce labels like 3.7143, which is the
 * kind of detail a library would handle and hand-rolled charts often skip.
 */
export function niceTicks(min: number, max: number, target = 5): number[] {
  if (!Number.isFinite(min) || !Number.isFinite(max) || min === max) {
    return [min];
  }
  const rawStep = (max - min) / Math.max(target, 1);
  const magnitude = 10 ** Math.floor(Math.log10(rawStep));
  const normalised = rawStep / magnitude;
  // Snap to 1, 2, 5 or 10 times a power of ten.
  const snapped =
    normalised >= 7.5 ? 10 : normalised >= 3 ? 5 : normalised >= 1.5 ? 2 : 1;
  const step = snapped * magnitude;

  const start = Math.ceil(min / step) * step;
  const ticks: number[] = [];
  for (let value = start; value <= max + step * 1e-9; value += step) {
    // Kill floating-point dust such as 0.30000000000000004.
    ticks.push(Number(value.toFixed(10)));
  }
  return ticks;
}

/** Rounds a domain outward to the next nice tick, so marks never clip. */
export function niceDomain(
  min: number,
  max: number,
  target = 5,
): readonly [number, number] {
  if (min === max) return [min, min + 1];
  const ticks = niceTicks(min, max, target);
  const step = ticks.length > 1 ? (ticks[1] as number) - (ticks[0] as number) : 1;
  return [Math.floor(min / step) * step, Math.ceil(max / step) * step];
}

export interface Point {
  x: number;
  y: number;
}

/** Polyline through the points. Straight segments - honest about the data. */
export function linePath(points: readonly Point[]): string {
  if (points.length === 0) return '';
  return points
    .map(
      (point, index) =>
        `${index === 0 ? 'M' : 'L'}${point.x.toFixed(2)},${point.y.toFixed(2)}`,
    )
    .join(' ');
}

/** Closed area between the line and a baseline. */
export function areaPath(points: readonly Point[], baseline: number): string {
  if (points.length === 0) return '';
  const first = points[0] as Point;
  const last = points[points.length - 1] as Point;
  return [
    linePath(points),
    `L${last.x.toFixed(2)},${baseline.toFixed(2)}`,
    `L${first.x.toFixed(2)},${baseline.toFixed(2)}`,
    'Z',
  ].join(' ');
}

/**
 * Bar with only its far end rounded, anchored to the baseline.
 * The spec asks for 4px rounded data-ends; a fully rounded rect would detach
 * the bar from its axis and misrepresent where zero is.
 */
export function barPath(
  x: number,
  y: number,
  width: number,
  height: number,
  radius = 4,
): string {
  if (height <= 0) return '';
  const r = Math.min(radius, width / 2, height);
  return [
    `M${x},${y + height}`,
    `L${x},${y + r}`,
    `Q${x},${y} ${x + r},${y}`,
    `L${x + width - r},${y}`,
    `Q${x + width},${y} ${x + width},${y + r}`,
    `L${x + width},${y + height}`,
    'Z',
  ].join(' ');
}

/** Horizontal variant: rounded on the right (value) end only. */
export function hBarPath(
  x: number,
  y: number,
  width: number,
  height: number,
  radius = 4,
): string {
  if (width <= 0) return '';
  const r = Math.min(radius, height / 2, width);
  return [
    `M${x},${y}`,
    `L${x + width - r},${y}`,
    `Q${x + width},${y} ${x + width},${y + r}`,
    `L${x + width},${y + height - r}`,
    `Q${x + width},${y + height} ${x + width - r},${y + height}`,
    `L${x},${y + height}`,
    'Z',
  ].join(' ');
}

// --- Formatting -------------------------------------------------------------

export function formatCount(value: number): string {
  return value >= 1000 ? `${(value / 1000).toFixed(1)}k` : String(value);
}

export function formatMagnitude(value: number | null | undefined): string {
  return value == null ? '—' : `M${value.toFixed(1)}`;
}

/**
 * All timestamps are rendered in **UTC**, deliberately.
 *
 * Two reasons. First, USGS reports seismic events in UTC and so does every
 * other seismology source, so it is the correct convention for this data.
 * Second, it makes formatting deterministic: the server renders in the
 * container's timezone and the browser in the viewer's, and any difference
 * between them is a React hydration mismatch. Pinning to UTC removes that
 * whole class of bug rather than papering over it with
 * suppressHydrationWarning.
 *
 * The UI labels the timezone so the choice is never ambiguous to a reader.
 */
const UTC: Intl.DateTimeFormatOptions = { timeZone: 'UTC' };

/** Bucket axis label, in UTC. */
export function formatBucketLabel(iso: string, window: 'day' | 'week' | 'month'): string {
  const date = new Date(iso);
  if (window === 'day') {
    return date.toLocaleTimeString('en-GB', { ...UTC, hour: '2-digit', hour12: false });
  }
  if (window === 'week') {
    return date.toLocaleDateString('en-GB', { ...UTC, weekday: 'short' });
  }
  return date.toLocaleDateString('en-GB', { ...UTC, month: 'short', day: 'numeric' });
}

/** Absolute event time, in UTC. */
export function formatTimestamp(epochMs: number): string {
  return new Date(epochMs).toLocaleString('en-GB', {
    ...UTC,
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

/**
 * Relative age, e.g. "3h ago".
 *
 * Depends on the current clock, so it differs between server render and
 * client hydration by definition. Call it only after mount - see the
 * `useMounted` guard in DashboardView.
 */
export function formatRelative(iso: string, now: number = Date.now()): string {
  const deltaSeconds = Math.max(0, (now - new Date(iso).getTime()) / 1000);
  if (deltaSeconds < 60) return 'just now';
  if (deltaSeconds < 3600) return `${Math.floor(deltaSeconds / 60)}m ago`;
  if (deltaSeconds < 86400) return `${Math.floor(deltaSeconds / 3600)}h ago`;
  return `${Math.floor(deltaSeconds / 86400)}d ago`;
}
