const TONES = {
  ok: 'bg-emerald-100 text-emerald-800 ring-emerald-600/20',
  error: 'bg-rose-100 text-rose-800 ring-rose-600/20',
  pending: 'bg-slate-100 text-slate-700 ring-slate-500/20',
} as const;

export type StatusTone = keyof typeof TONES;

export function StatusBadge({ tone, children }: { tone: StatusTone; children: string }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset ${TONES[tone]}`}
    >
      {children}
    </span>
  );
}
