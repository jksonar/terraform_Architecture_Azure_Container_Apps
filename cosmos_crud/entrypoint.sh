#!/bin/sh
set -e

echo "==> Collecting static files..."
python manage.py collectstatic --noinput

echo "==> Starting uvicorn (workers=${UVICORN_WORKERS:-1}, log-level=${UVICORN_LOG_LEVEL:-info})..."
exec uvicorn cosmoscrud.asgi:application \
    --host 0.0.0.0 \
    --port 8000 \
    --workers ${UVICORN_WORKERS:-1} \
    --log-level ${UVICORN_LOG_LEVEL:-info}
