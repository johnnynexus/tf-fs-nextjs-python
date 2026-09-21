'use client';

/**
 * Depth versus magnitude.
 *
 * One series, so a single hue with the sequential ramp carrying magnitude -
 * the all-pairs categorical cap (three slots) never comes into play.
 *
 * Depth increases *downward*, matching physical intuition: the y-axis is
 * inverted so the surface sits at the top. Getting this backwards is the
 * classic mistake with seismic scatter plots.
 */

import { useState } from 'react';

import { Tooltip } from '@/components/charts/Tooltip';
import type { DepthMagnitudePoint } from '@/lib/api';
import { formatMagnitude, niceDomain, niceTicks, scaleLinear } from '@/lib/viz';

const WIDTH = 460;
const HEIGHT = 260;
const MARGIN = { top: 18, right: 16, bottom: 46, left: 44 };

interface HoverState {
  index: number;
  px: number;
  py: number;
  containerWidth: number;
}

export function DepthScatter({ points }: { points: DepthMagnitudePoint[] }) {
  const [hover, setHover] = useState<HoverState | null>(null);

  const innerWidth = WIDTH - MARGIN.left - MARGIN.right;
  const innerHeight = HEIGHT - MARGIN.top - MARGIN.bottom;

  const magnitudes = points.map((point) => point.magnitude);
  const maxMagnitude = Math.max(1, ...magnitudes);
  const minMagnitude = points.length ? Math.min(...magnitudes) : 0;
  const maxDepth = Math.max(10, ...points.map((point) => point.depth_km));

  /*
    The magnitude axis starts near the data, not at zero. The feed is
    filtered to M2.5+, so anchoring at M0 left roughly a third of the plot
    permanently empty and squashed the points that matter. Truncating a
    magnitude axis is safe: unlike a bar chart, a scatter encodes position,
    not length from a baseline, so no proportion is being misread.
  */
  const [xMin, xMax] = niceDomain(Math.max(0, minMagnitude - 0.5), maxMagnitude, 5);
  const [, yMax] = niceDomain(0, maxDepth, 5);

  const x = scaleLinear([xMin, xMax], [0, innerWidth]);
  // Range runs top-to-bottom: 0 km at the top, deepest at the bottom.
  const y = scaleLinear([0, yMax], [0, innerHeight]);

  const active = hover ? points[hover.index] : undefined;

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="w-full"
        role="img"
        aria-label="Earthquake depth plotted against magnitude"
      >
        <g transform={`translate(${MARGIN.left},${MARGIN.top})`}>
          {niceTicks(0, yMax, 5).map((tick) => (
            <g key={`y${tick}`}>
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

          {niceTicks(xMin, xMax, 5).map((tick) => (
            <text
              key={`x${tick}`}
              x={x(tick)}
              y={innerHeight + 16}
              textAnchor="middle"
              fontSize={10}
              fill="var(--text-muted)"
            >
              M{tick}
            </text>
          ))}

          {points.map((point, index) => {
            const isActive = hover?.index === index;
            return (
              <circle
                key={`${point.place}-${index}`}
                cx={x(point.magnitude)}
                cy={y(point.depth_km)}
                r={isActive ? 6.5 : 4}
                fill="var(--seq-4)"
                fillOpacity={isActive ? 1 : 0.5}
                // 2px surface ring on the active mark keeps it legible where
                // dots overlap.
                stroke="var(--surface-2)"
                strokeWidth={isActive ? 2 : 0.5}
                pointerEvents="none"
              />
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

          {/*
            Nearest-point hit layer.

            Requiring the pointer to land dead-centre on a 4px radius dot is
            a documented anti-pattern, but giving every dot a 24px target
            would overlap badly in the dense shallow band. One transparent
            rect plus a nearest-point search gives generous targeting
            everywhere, in a single DOM node instead of several hundred.
          */}
          <rect
            x={0}
            y={0}
            width={innerWidth}
            height={innerHeight}
            fill="transparent"
            onMouseLeave={() => setHover(null)}
            onMouseMove={(event) => {
              const svg = event.currentTarget.ownerSVGElement;
              if (!svg) return;
              const rect = svg.getBoundingClientRect();
              const localX =
                ((event.clientX - rect.left) / rect.width) * WIDTH - MARGIN.left;
              const localY =
                ((event.clientY - rect.top) / rect.height) * HEIGHT - MARGIN.top;

              let best = -1;
              let bestDistance = Infinity;
              points.forEach((point, index) => {
                const dx = x(point.magnitude) - localX;
                const dy = y(point.depth_km) - localY;
                const distance = dx * dx + dy * dy;
                if (distance < bestDistance) {
                  bestDistance = distance;
                  best = index;
                }
              });

              // ~24px reach in viewBox units, so the pointer never has to be
              // precise, but a far-away cursor does not latch onto a point.
              const REACH = 24;
              if (best < 0 || bestDistance > REACH * REACH) {
                setHover(null);
                return;
              }
              const point = points[best] as (typeof points)[number];
              setHover({
                index: best,
                px: ((x(point.magnitude) + MARGIN.left) / WIDTH) * rect.width,
                py: ((y(point.depth_km) + MARGIN.top) / HEIGHT) * rect.height,
                containerWidth: rect.width,
              });
            }}
          />
          {/* Axis titles, so neither scale depends on the caption to be
              read. Anchored at the plot edge rather than a negative x, which
              would render outside the viewBox and be clipped. */}
          <text x={0} y={-2} fontSize={10} fill="var(--text-muted)">
            Depth (km)
          </text>
          <text
            x={innerWidth}
            y={innerHeight + 30}
            textAnchor="end"
            fontSize={10}
            fill="var(--text-muted)"
          >
            Magnitude
          </text>
        </g>
      </svg>

      <Tooltip
        visible={active != null}
        x={hover?.px ?? 0}
        y={hover?.py ?? 0}
        width={hover?.containerWidth ?? WIDTH}
        title={active?.place ?? ''}
        rows={
          active
            ? [
                { label: 'Magnitude', value: formatMagnitude(active.magnitude) },
                { label: 'Depth', value: `${active.depth_km.toFixed(1)} km` },
              ]
            : []
        }
      />
    </div>
  );
}
