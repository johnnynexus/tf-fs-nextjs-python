/**
 * The table view.
 *
 * Required, not decorative: the palette validator flags light-mode aqua
 * below 3:1, and the documented relief for that is visible labels or a
 * table. It also gives screen-reader users and anyone who prefers numbers a
 * complete, non-visual path to the same data.
 */

import { AlertChip } from '@/components/dashboard/AlertChip';
import type { QuakeEvent } from '@/lib/api';
import { formatMagnitude, formatTimestamp } from '@/lib/viz';

export function EventsTable({ events }: { events: QuakeEvent[] }) {
  if (events.length === 0) {
    return (
      <p className="py-6 text-center text-xs" style={{ color: 'var(--text-muted)' }}>
        No events in this window.
      </p>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-left text-xs">
        <caption className="sr-only">
          Most recent significant earthquakes in the selected window
        </caption>
        <thead>
          <tr style={{ color: 'var(--text-muted)' }}>
            <th scope="col" className="py-2 pr-3 font-medium">
              Magnitude
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">
              Location
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">
              Depth
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">
              When
            </th>
            <th scope="col" className="py-2 font-medium">
              Alert
            </th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => (
            <tr key={event.id} style={{ borderTop: '1px solid var(--border-subtle)' }}>
              <td className="py-2 pr-3">
                <span
                  className="font-mono font-semibold tabular-nums"
                  style={{ color: 'var(--text-primary)' }}
                >
                  {formatMagnitude(event.magnitude)}
                </span>
                {event.tsunami && (
                  <span
                    className="ml-2 rounded px-1.5 py-0.5 text-[10px] font-medium"
                    style={{
                      color: 'var(--text-primary)',
                      border: '1px solid var(--status-serious)',
                    }}
                  >
                    Tsunami
                  </span>
                )}
              </td>
              <td className="py-2 pr-3" style={{ color: 'var(--text-secondary)' }}>
                {event.url ? (
                  <a
                    href={event.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="underline decoration-dotted underline-offset-2"
                  >
                    {event.place}
                  </a>
                ) : (
                  event.place
                )}
              </td>
              <td
                className="py-2 pr-3 font-mono tabular-nums"
                style={{ color: 'var(--text-secondary)' }}
              >
                {event.depth_km.toFixed(1)} km
              </td>
              <td className="py-2 pr-3" style={{ color: 'var(--text-secondary)' }}>
                {formatTimestamp(event.time)}
              </td>
              <td className="py-2">
                <AlertChip level={event.alert} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
