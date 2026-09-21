/**
 * USGS alert level, rendered with the reserved status palette.
 *
 * Status colours ship with an icon and a text label, never colour alone -
 * two of the four are deliberately sub-3:1 on the light surface, so the
 * label is what actually carries the meaning.
 */

import type { AlertLevel } from '@/lib/api';

const LEVELS: Record<AlertLevel, { token: string; label: string; icon: string }> = {
  green: { token: 'var(--status-good)', label: 'Green', icon: '●' },
  yellow: { token: 'var(--status-warning)', label: 'Yellow', icon: '▲' },
  orange: { token: 'var(--status-serious)', label: 'Orange', icon: '▲' },
  red: { token: 'var(--status-critical)', label: 'Red', icon: '■' },
};

export function AlertChip({ level }: { level: AlertLevel | null }) {
  if (!level) {
    return (
      <span className="text-xs" style={{ color: 'var(--text-muted)' }}>
        —
      </span>
    );
  }

  const { token, label, icon } = LEVELS[level];
  return (
    <span
      className="inline-flex items-center gap-1.5 text-xs font-medium"
      style={{ color: 'var(--text-primary)' }}
    >
      <span aria-hidden="true" style={{ color: token }}>
        {icon}
      </span>
      {label}
    </span>
  );
}
