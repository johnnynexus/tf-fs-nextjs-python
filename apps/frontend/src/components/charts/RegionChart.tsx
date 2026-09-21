'use client';

/**
 * Top regions - horizontal bars.
 *
 * Horizontal because region names are long ("Papua New Guinea"); rotated
 * labels on a column chart are an anti-pattern.
 *
 * All bars share ONE hue. Regions are nominal - Alaska is not "more" than
 * Japan in any intrinsic order - so shading them darker-where-bigger would
 * double-encode bar length as colour, spending the only free channel on
 * information the length already carries. Value labels sit outside the bar
 * ends, where contrast against the fill is irrelevant.
 */

import { useState } from 'react';

import { Tooltip } from '@/components/charts/Tooltip';
import type { RegionCount } from '@/lib/api';
import { formatMagnitude, hBarPath, scaleLinear } from '@/lib/viz';

const WIDTH = 460;
const ROW_HEIGHT = 26;
const MARGIN = { top: 6, right: 44, bottom: 6, left: 116 };

interface HoverState {
  index: number;
  px: number;
  py: number;
  containerWidth: number;
}

export function RegionChart({ regions }: { regions: RegionCount[] }) {
  const [hover, setHover] = useState<HoverState | null>(null);

  const height = MARGIN.top + MARGIN.bottom + regions.length * ROW_HEIGHT;
  const innerWidth = WIDTH - MARGIN.left - MARGIN.right;
  const maxCount = Math.max(1, ...regions.map((region) => region.count));
  const x = scaleLinear([0, maxCount], [0, innerWidth]);

  const active = hover ? regions[hover.index] : undefined;

  if (regions.length === 0) {
    return (
      <p className="py-8 text-center text-xs" style={{ color: 'var(--text-muted)' }}>
        No regions in this window.
      </p>
    );
  }

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${WIDTH} ${height}`}
        className="w-full"
        role="img"
        aria-label="Regions with the most earthquakes in the selected window"
        onMouseLeave={() => setHover(null)}
        onMouseMove={(event) => {
          const rect = event.currentTarget.getBoundingClientRect();
          const offsetY = event.clientY - rect.top;
          const localY = (offsetY / rect.height) * height - MARGIN.top;
          const index = Math.floor(localY / ROW_HEIGHT);
          if (index < 0 || index >= regions.length) {
            setHover(null);
            return;
          }
          setHover({
            index,
            px: event.clientX - rect.left,
            py: offsetY,
            containerWidth: rect.width,
          });
        }}
      >
        <g transform={`translate(${MARGIN.left},${MARGIN.top})`}>
          {regions.map((region, index) => {
            // 2px surface gap between adjacent bars.
            const barHeight = ROW_HEIGHT - 8;
            const y = index * ROW_HEIGHT + 4;
            const barWidth = x(region.count);
            return (
              <g key={region.region}>
                <text
                  x={-10}
                  y={y + barHeight / 2}
                  textAnchor="end"
                  dominantBaseline="middle"
                  fontSize={11}
                  fill="var(--text-secondary)"
                >
                  {region.region.length > 18
                    ? `${region.region.slice(0, 17)}…`
                    : region.region}
                </text>
                <path
                  d={hBarPath(0, y, barWidth, barHeight, 4)}
                  fill="var(--series-1)"
                  opacity={hover && hover.index !== index ? 0.55 : 1}
                />
                <text
                  x={barWidth + 8}
                  y={y + barHeight / 2}
                  dominantBaseline="middle"
                  fontSize={11}
                  fill="var(--text-secondary)"
                >
                  {region.count}
                </text>
              </g>
            );
          })}
        </g>
      </svg>

      <Tooltip
        visible={active != null}
        x={hover?.px ?? 0}
        y={hover?.py ?? 0}
        width={hover?.containerWidth ?? WIDTH}
        title={active?.region ?? ''}
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
