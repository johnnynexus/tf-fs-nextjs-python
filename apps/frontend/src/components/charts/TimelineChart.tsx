'use client';

/**
 * Events over time - a single-series area chart with a crosshair.
 *
 * Area (not line) because there is one series and the filled region reads as
 * volume. Every bucket in the window is plotted, including empty ones, so
 * quiet periods are visible rather than silently collapsed.
 */

import { useState } from 'react';

import { Tooltip } from '@/components/charts/Tooltip';
import type { TimeBucket, TimeWindow } from '@/lib/api';
import {
  areaPath,
  formatBucketLabel,
  formatMagnitude,
  formatTimestamp,
  linePath,
  niceDomain,
  niceTicks,
  scaleLinear,
  type Point,
} from '@/lib/viz';

const WIDTH = 720;
const HEIGHT = 240;
const MARGIN = { top: 12, right: 16, bottom: 28, left: 40 };

/**
 * Hover state carries the datum index plus the pointer position in *CSS
 * pixels* relative to the container. The SVG scales via viewBox, so its
 * internal units are not CSS pixels - positioning the HTML tooltip from
 * viewBox coordinates would drift as the chart resizes.
 */
interface HoverState {
  index: number;
  px: number;
  py: number;
  containerWidth: number;
}

export function TimelineChart({
  buckets,
  window,
}: {
  buckets: TimeBucket[];
  window: TimeWindow;
}) {
  const [hover, setHover] = useState<HoverState | null>(null);

  const innerWidth = WIDTH - MARGIN.left - MARGIN.right;
  const innerHeight = HEIGHT - MARGIN.top - MARGIN.bottom;

  const maxCount = Math.max(1, ...buckets.map((bucket) => bucket.count));
  const [, yMax] = niceDomain(0, maxCount, 4);

  const x = scaleLinear([0, Math.max(1, buckets.length - 1)], [0, innerWidth]);
  const y = scaleLinear([0, yMax], [innerHeight, 0]);

  const points: Point[] = buckets.map((bucket, index) => ({
    x: x(index),
    y: y(bucket.count),
  }));

  const yTicks = niceTicks(0, yMax, 4);

  /*
    Label stride is chosen so each label lands on a meaningful boundary, not
    just an even division of the bucket count. A generic "about six labels"
    rule put week labels 30 hours apart, which made weekday names drift and
    repeat ("Mon ... Mon" with no Tue). These strides are one label per day
    for the week view and per four hours for the day view.
  */
  const labelEvery = window === 'day' ? 4 : window === 'week' ? 4 : 5;

  const active = hover ? buckets[hover.index] : undefined;

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="w-full"
        role="img"
        aria-label={`Earthquake count per time bucket over the past ${window}`}
        onMouseLeave={() => setHover(null)}
        onMouseMove={(event) => {
          const rect = event.currentTarget.getBoundingClientRect();
          const offsetX = event.clientX - rect.left;
          // Convert CSS pixels into viewBox units to find the datum...
          const localX = (offsetX / rect.width) * WIDTH - MARGIN.left;
          const index = Math.round(x.invert(localX));
          if (index < 0 || index >= buckets.length) {
            setHover(null);
            return;
          }
          // ...but keep CSS pixels for placing the HTML tooltip.
          setHover({
            index,
            px: offsetX,
            py: event.clientY - rect.top,
            containerWidth: rect.width,
          });
        }}
      >
        <defs>
          <linearGradient id="timeline-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--seq-4)" stopOpacity="0.38" />
            <stop offset="100%" stopColor="var(--seq-4)" stopOpacity="0.04" />
          </linearGradient>
        </defs>

        <g transform={`translate(${MARGIN.left},${MARGIN.top})`}>
          {/* Recessive gridlines, behind the data. */}
          {yTicks.map((tick) => (
            <g key={tick}>
              <line
                x1={0}
                x2={innerWidth}
                y1={y(tick)}
                y2={y(tick)}
                stroke="var(--grid)"
                strokeWidth={1}
              />
              <text
                x={-8}
                y={y(tick)}
                textAnchor="end"
                dominantBaseline="middle"
                fontSize={10}
                fill="var(--text-muted)"
              >
                {tick}
              </text>
            </g>
          ))}

          <path d={areaPath(points, innerHeight)} fill="url(#timeline-fill)" />
          {/* 2px line, per the mark spec. */}
          <path
            d={linePath(points)}
            fill="none"
            stroke="var(--seq-4)"
            strokeWidth={2}
            strokeLinejoin="round"
            strokeLinecap="round"
          />

          {active && hover && (
            <g>
              <line
                x1={x(hover.index)}
                x2={x(hover.index)}
                y1={0}
                y2={innerHeight}
                stroke="var(--axis)"
                strokeWidth={1}
                strokeDasharray="3 3"
              />
              {/* 2px surface ring keeps the marker legible over the fill. */}
              <circle
                cx={x(hover.index)}
                cy={y(active.count)}
                r={5}
                fill="var(--seq-5)"
                stroke="var(--surface-2)"
                strokeWidth={2}
              />
            </g>
          )}

          <line
            x1={0}
            x2={innerWidth}
            y1={innerHeight}
            y2={innerHeight}
            stroke="var(--axis)"
            strokeWidth={1}
          />

          {buckets.map((bucket, index) =>
            index % labelEvery === 0 ? (
              <text
                key={bucket.start}
                x={x(index)}
                y={innerHeight + 16}
                textAnchor="middle"
                fontSize={10}
                fill="var(--text-muted)"
              >
                {formatBucketLabel(bucket.start, window)}
              </text>
            ) : null,
          )}
        </g>
      </svg>

      <Tooltip
        visible={active != null}
        x={hover?.px ?? 0}
        y={hover?.py ?? 0}
        width={hover?.containerWidth ?? WIDTH}
        title={active ? `${formatTimestamp(new Date(active.start).getTime())} UTC` : ''}
        rows={
          active
            ? [
                { label: 'Events', value: String(active.count) },
                { label: 'Strongest', value: formatMagnitude(active.max_magnitude) },
              ]
            : []
        }
      />
    </div>
  );
}
