# syntax=docker/dockerfile:1

# =============================================================================
# Multi-stage build for the Next.js frontend.
#
# deps    - installs node_modules from the lockfile only, so this layer is
#           reused whenever application source changes but dependencies do not.
# builder - runs `next build`, producing .next/standalone (a self-contained
#           server bundling only the modules actually imported).
# runner  - copies the standalone output onto a clean base. No npm, no
#           devDependencies, no source.
# =============================================================================

ARG NODE_VERSION=22

# -----------------------------------------------------------------------------
# Stage 1: dependencies
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine AS deps
WORKDIR /app

# `npm ci` requires the lockfile and installs exactly what it pins.
COPY package.json package-lock.json ./
RUN npm ci

# -----------------------------------------------------------------------------
# Stage 1b: dev server (used only by docker-compose, never deployed)
#
# `next build` output cannot hot-reload, so local development needs a stage
# that runs `next dev` against bind-mounted source instead.
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine AS dev
WORKDIR /app
ENV NODE_ENV=development \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000

# Lets `docker compose up --wait` actually wait for Next to finish its first
# compile, instead of reporting ready as soon as the process starts. The
# start period is generous because `next dev` compiles on demand.
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=12 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["npm", "run", "dev"]

# -----------------------------------------------------------------------------
# Stage 2: build
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine AS builder
WORKDIR /app

# NEXT_PUBLIC_* values are inlined into the client bundle at build time, which
# is why they are build args rather than runtime env vars. Leave
# NEXT_PUBLIC_API_BASE_URL empty to use the same-origin /api/backend proxy -
# the recommended path, because it avoids baking the backend URL into the
# image before Terraform has even created the backend service.
ARG NEXT_PUBLIC_API_BASE_URL=""
ARG NEXT_PUBLIC_RELEASE="dev"
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL} \
    NEXT_PUBLIC_RELEASE=${NEXT_PUBLIC_RELEASE} \
    NEXT_TELEMETRY_DISABLED=1

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# -----------------------------------------------------------------------------
# Stage 3: runtime
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=8080 \
    # The standalone server binds to localhost by default, which is
    # unreachable from outside the container.
    HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 --ingroup nodejs nextjs

COPY --from=builder /app/public ./public

# The standalone output already contains a minimal node_modules and server.js.
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
# Static assets are emitted outside the standalone bundle and must be copied
# separately, or every CSS/JS request 404s.
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 8080

# Used by docker-compose. Cloud Run uses its own probes (see Terraform).
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
