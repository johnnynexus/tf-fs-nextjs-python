'use client';

/**
 * Magnitude distribution - columns, coloured on the sequential ramp.
 *
 * The bands are an *ordered* scale, so this uses the ordinal ramp rather
 * than categorical hues (which would imply the bands are unrelated
 * identities) or the sequential ramp (whose lightest steps are allowed to
 * recede into the surface - fine for a continuous heatmap, wrong for a
 * discrete bar that must stay visible).
 *
 * Every ordinal step clears 2:1 against its surface; see --ord-* in
 * globals.css.
 */

import { useState } from 'react';

import { Tooltip } from '@/components/charts/Tooltip';
import type { MagnitudeBin } from '@/lib/api';
import { barPath, niceDomain, niceTicks, scaleBand, scaleLinear } from '@/lib/viz';

const WIDTH = 460;
const HEIGHT = 240;
const MARGIN = { top: 12, right: 12, bottom: 34, left: 36 };

interface HoverState {
  index: number;
  px: number;
  py: number;
  containerWidth: number;
}

export function MagnitudeChart({ bins }: { bins: MagnitudeBin[] }) {
  const [hover, setHover] = useState<HoverState | null>(null);

  const innerWidth = WIDTH - MARGIN.left - MARGIN.right;
  const innerHeight = HEIGHT - MARGIN.top - MARGIN.bottom;

  const maxCount = Math.max(1, ...bins.map((bin) => bin.count));
  const [, yMax] = niceDomain(0, maxCount, 4);
  const y = scaleLinear([0, yMax], [innerHeight, 0]);
  // padding 0.28 gives a clear surface gap between adjacent bars.
  const band = scaleBand(bins.length, [0, innerWidth], 0.28);
  const total = bins.reduce((sum, bin) => sum + bin.count, 0);

  const active = hover ? bins[hover.index] : undefined;

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="w-full"
        role="img"
        aria-label="Distribution of earthquakes by magnitude band"
        onMouseLeave={() => setHover(null)}
        onMouseMove={(event) => {
          const rect = event.currentTarget.getBoundingClientRect();
          const offsetX = event.clientX - rect.left;
          const localX = (offsetX / rect.width) * WIDTH - MARGIN.left;
          const index = band.indexAt(localX);
          if (index < 0) {
            setHover(null);
            return;
          }
          setHover({
            index,
            px: offsetX,
            py: event.clientY - rect.top,
            containerWidth: rect.width,
          });
        }}
      >
        <g transform={`translate(${MARGIN.left},${MARGIN.top})`}>
          {niceTicks(0, yMax, 4).map((tick) => (
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

          {bins.map((bin, index) => {
            const height = innerHeight - y(bin.count);
            // Step follows the band's position on the magnitude scale, not
            // its count: colour encodes magnitude, height encodes frequency.
            // Five bands map to the five validated ordinal steps, 1:1.
            const step = Math.min(5, index + 1);
            return (
              <g key={bin.label}>
                <path
                  d={barPath(band.at(index), y(bin.count), band.bandwidth, height, 4)}
                  fill={`var(--ord-${step})`}
                  opacity={hover && hover.index !== index ? 0.55 : 1}
                />
                {/* Direct label - also the relief the contrast WARN requires. */}
                {bin.count > 0 && (
                  <text
                    x={band.center(index)}
                    y={y(bin.count) - 6}
                    textAnchor="middle"
                    fontSize={10}
                    fill="var(--text-secondary)"
                  >
                    {bin.count}
                  </text>
                )}
                <text
                  x={band.center(index)}
                  y={innerHeight + 16}
                  textAnchor="middle"
                  fontSize={9}
                  fill="var(--text-muted)"
                >
                  {bin.label}
                </text>
              </g>
            );
          })}

          <line
            x1={0}
            x2={innerWidth}
            y1={innerHeight}
            y2={innerHeight}
            stroke="var(--axis)"
            strokeWidth={1}
          />
        </g>
      </svg>

      <Tooltip
        visible={active != null}
        x={hover?.px ?? 0}
        y={hover?.py ?? 0}
        width={hover?.containerWidth ?? WIDTH}
        title={active ? `Magnitude ${active.label}` : ''}
        rows={
          active
            ? [
                { label: 'Events', value: String(active.count) },
                {
                  label: 'Share',
                  value: total ? `${((active.count / total) * 100).toFixed(1)}%` : '—',
                },
              ]
            : []
        }
      />
    </div>
  );
}
