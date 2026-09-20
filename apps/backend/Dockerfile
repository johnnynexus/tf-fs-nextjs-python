# syntax=docker/dockerfile:1

# =============================================================================
# Multi-stage build for the FastAPI backend.
#
# Stage 1 (builder) installs dependencies into a self-contained virtualenv with
# a full toolchain available for any package that needs to compile.
# Stage 2 (runtime) copies just that virtualenv onto a clean slim base, so the
# final image carries no compilers, no build caches and no source tarballs.
# =============================================================================

# Pinned to a minor version for reproducibility; bump deliberately.
ARG PYTHON_VERSION=3.12

# -----------------------------------------------------------------------------
# Stage 1: builder
# -----------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

# build-essential covers source builds; most deps ship manylinux wheels, so
# this is a safety net rather than the common path.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# Everything lands in an isolated venv that stage 2 can copy wholesale.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build

# Copy only what the install needs first, so Docker's layer cache survives
# source-only edits.
COPY pyproject.toml ./
COPY app ./app

# Install the project and its pinned dependency ranges.
RUN pip install --upgrade pip setuptools wheel \
    && pip install .

# -----------------------------------------------------------------------------
# Stage 2: runtime
# -----------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

# Build metadata, stamped by CI. Surfaced through /health so a running
# revision can be traced back to its commit.
ARG RELEASE=dev
ENV RELEASE=${RELEASE}

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8080

# Run as an unprivileged user. Cloud Run does not require this, but it is the
# right default and matters if the same image ever runs on Kubernetes.
RUN groupadd --system --gid 1001 appuser \
    && useradd --system --uid 1001 --gid appuser --create-home appuser

COPY --from=builder /opt/venv /opt/venv

# The application itself was installed into the venv by stage 1, so there is
# no second copy of the source in the image. /app stays empty in production
# and exists only as a mount point: docker-compose bind-mounts the source
# there and sets PYTHONPATH=/app so edits are picked up by --reload, while
# the production image resolves `app` from site-packages deterministically.
WORKDIR /app

USER appuser

EXPOSE 8080

# Used by docker-compose to gate the frontend's startup. Cloud Run ignores
# HEALTHCHECK and uses its own probes, configured in Terraform.
# urlopen raises (non-zero exit) on any status other than 2xx, which is
# exactly the pass/fail signal Docker wants.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8080') + '/health', timeout=2)"

# Shell form so $PORT (injected by Cloud Run) is expanded at runtime; `exec`
# keeps uvicorn as PID 1 so it receives SIGTERM and shuts down gracefully.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers ${WEB_CONCURRENCY:-1} --no-access-log --proxy-headers --forwarded-allow-ips='*'"]
