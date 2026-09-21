/**
 * Backend API client.
 *
 * There are two ways the browser can reach the backend, and this file makes
 * the choice explicit:
 *
 *  1. Same-origin proxy (default). The browser calls `/api/backend/*` on the
 *     Next.js server, which forwards to the backend using a *runtime* env var.
 *     No CORS preflight, and the backend URL is not baked into the JS bundle -
 *     which matters because Terraform only knows the Cloud Run URL after the
 *     image has already been built.
 *
 *  2. Direct cross-origin calls. Set NEXT_PUBLIC_API_BASE_URL at *build* time
 *     and the browser talks to the backend directly. This is why the backend
 *     configures CORS. It costs a preflight and requires rebuilding the image
 *     whenever the backend URL changes.
 *
 * Server Components always use `BACKEND_INTERNAL_URL` directly - no proxy hop.
 */

/** Server-side only. Never sent to the browser (no NEXT_PUBLIC_ prefix). */
// `||` not `??`: an unset Docker ARG becomes an empty string, and an empty
// string must fall back to the default rather than produce a broken URL.
export const BACKEND_INTERNAL_URL =
  process.env.BACKEND_INTERNAL_URL || 'http://localhost:8000';

/**
 * Base URL the browser uses. Defaults to the same-origin proxy route.
 * Inlined at build time by Next, so it cannot be changed after `next build`.
 */
export const PUBLIC_API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api/backend';

/** Default timeout so a hung backend cannot hang a page render. */
const DEFAULT_TIMEOUT_MS = 5_000;

/** Dashboard calls traverse an upstream API, so they get a longer budget. */
const DASHBOARD_TIMEOUT_MS = 15_000;

export interface HealthResponse {
  status: 'ok';
  service: string;
  environment: string;
  release: string;
}

export interface HelloResponse {
  message: string;
  environment: string;
  name: string;
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

/** fetch + timeout + JSON parsing + typed errors. */
export async function apiFetch<T>(
  url: string,
  init: RequestInit = {},
  timeoutMs: number = DEFAULT_TIMEOUT_MS,
): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...init,
      signal: controller.signal,
      headers: { Accept: 'application/json', ...init.headers },
      // Health and greeting data must never be served from a stale cache.
      cache: 'no-store',
    });

    if (!response.ok) {
      throw new ApiError(
        `Backend responded with ${response.status} ${response.statusText}`,
        response.status,
      );
    }

    return (await response.json()) as T;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error instanceof Error && error.name === 'AbortError') {
      throw new ApiError(`Request to ${url} timed out after ${timeoutMs}ms`);
    }
    throw new ApiError(
      error instanceof Error ? error.message : `Unknown error calling ${url}`,
    );
  } finally {
    clearTimeout(timeout);
  }
}

/** Server-side health check. Called from a Server Component. */
export function fetchBackendHealth(): Promise<HealthResponse> {
  return apiFetch<HealthResponse>(`${BACKEND_INTERNAL_URL}/health`);
}

/** Browser-side greeting call. Goes through the proxy unless overridden. */
export function fetchHello(name: string): Promise<HelloResponse> {
  const query = new URLSearchParams({ name });
  return apiFetch<HelloResponse>(`${PUBLIC_API_BASE_URL}/hello?${query.toString()}`);
}

// --- Seismic dashboard -------------------------------------------------------

export type TimeWindow = 'day' | 'week' | 'month';
export type AlertLevel = 'green' | 'yellow' | 'orange' | 'red';

export interface QuakeEvent {
  id: string;
  magnitude: number;
  place: string;
  /** Milliseconds since epoch; formatted client-side in the viewer's locale. */
  time: number;
  depth_km: number;
  longitude: number;
  latitude: number;
  url: string;
  alert: AlertLevel | null;
  tsunami: boolean;
  significance: number;
}

export interface TimeBucket {
  start: string;
  count: number;
  max_magnitude: number | null;
}

export interface MagnitudeBin {
  lower: number;
  upper: number;
  label: string;
  count: number;
}

export interface RegionCount {
  region: string;
  count: number;
  max_magnitude: number;
}

export interface DepthMagnitudePoint {
  depth_km: number;
  magnitude: number;
  place: string;
}

export interface QuakeStats {
  total_events: number;
  max_magnitude: number | null;
  strongest: QuakeEvent | null;
  significant_count: number;
  tsunami_count: number;
  median_depth_km: number | null;
}

export interface QuakeSummary {
  window: TimeWindow;
  min_magnitude: number;
  generated_at: string;
  cached: boolean;
  stats: QuakeStats;
  timeline: TimeBucket[];
  magnitude_bins: MagnitudeBin[];
  top_regions: RegionCount[];
  depth_magnitude: DepthMagnitudePoint[];
  recent_significant: QuakeEvent[];
}

/**
 * Server-side fetch, used by the dashboard Server Component so the first
 * paint is fully rendered with no client waterfall.
 */
export function fetchQuakeSummarySSR(
  window: TimeWindow,
  minMagnitude = 2.5,
): Promise<QuakeSummary> {
  const query = new URLSearchParams({
    window,
    min_magnitude: String(minMagnitude),
  });
  return apiFetch<QuakeSummary>(
    `${BACKEND_INTERNAL_URL}/api/v1/quakes/summary?${query.toString()}`,
    {},
    DASHBOARD_TIMEOUT_MS,
  );
}

/**
 * Browser-side fetch for the window filter. Goes through the same-origin
 * proxy by default, so changing the range needs no CORS and no rebuild.
 */
export function fetchQuakeSummary(
  window: TimeWindow,
  minMagnitude = 2.5,
): Promise<QuakeSummary> {
  const query = new URLSearchParams({
    window,
    min_magnitude: String(minMagnitude),
  });
  return apiFetch<QuakeSummary>(
    `${PUBLIC_API_BASE_URL}/quakes/summary?${query.toString()}`,
    {},
    DASHBOARD_TIMEOUT_MS,
  );
}
