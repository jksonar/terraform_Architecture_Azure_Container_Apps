# ── Stage 1: builder — compiles wheels ───────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Accept the requirements file as a build arg so each environment
# can pass its own file without changing this Dockerfile
ARG REQUIREMENTS_FILE=requirements/local.txt
COPY requirements/ requirements/
RUN pip install --upgrade pip && \
    pip wheel --no-cache-dir --wheel-dir /wheels -r ${REQUIREMENTS_FILE}


# ── Stage 2: runtime — lean image, no compiler ───────────────────────────────
FROM python:3.12-slim AS runtime

WORKDIR /app

ARG REQUIREMENTS_FILE=requirements/local.txt
COPY requirements/ requirements/
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r ${REQUIREMENTS_FILE} \
    && rm -rf /wheels

# Copy application source after pip install so code changes don't bust the pip cache
COPY . .

# Non-root user for security
RUN addgroup --system appgroup \
    && adduser --system --ingroup appgroup appuser \
    && chown -R appuser:appgroup /app \
    && chmod +x /app/entrypoint.sh

USER appuser

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
