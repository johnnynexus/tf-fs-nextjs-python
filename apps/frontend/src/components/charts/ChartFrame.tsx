/**
 * Shared chrome for every panel: surface, title, optional subtitle, and the
 * "what am I looking at" caption.
 *
 * The title names the series, which is why single-series charts here carry
 * no legend box - identity is already unambiguous.
 */

export function ChartFrame({
  title,
  subtitle,
  caption,
  children,
  className = '',
}: {
  title: string;
  subtitle?: string;
  caption?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section
      className={`rounded-xl border p-5 ${className}`}
      style={{
        backgroundColor: 'var(--surface-2)',
        borderColor: 'var(--border-subtle)',
      }}
    >
      <header className="mb-4">
        <h2 className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
          {title}
        </h2>
        {subtitle && (
          <p className="mt-0.5 text-xs" style={{ color: 'var(--text-secondary)' }}>
            {subtitle}
          </p>
        )}
      </header>

      {children}

      {caption && (
        <p className="mt-3 text-xs" style={{ color: 'var(--text-muted)' }}>
          {caption}
        </p>
      )}
    </section>
  );
}
