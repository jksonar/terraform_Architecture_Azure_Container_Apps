# TaskFlow — Django Task Manager

A Django 5.1.4 task management app with sub-tasks, priority levels, per-user task lists, and automatic completion tracking. Served by **uvicorn** (ASGI) with multi-environment Docker support.

---

## Features

- User registration and login
- Task lists with overall % completion bars
- Tasks with sub-tasks (self-referential model)
- Priority levels: Low / Medium / High / Urgent
- One-click completion toggle (completing a parent auto-completes all sub-tasks)
- Priority and status filters on each task list

---

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Docker | 24.0 |
| Docker Compose plugin | 2.20 (`docker compose version`) |
| Python | 3.12 (bare-Python dev only) |

---

## Environments

| Environment | Settings module | Database | DEBUG | Purpose |
|-------------|----------------|----------|-------|---------|
| **local** | `taskmanager.settings.local` | SQLite | True | Developer laptops |
| **dev** | `taskmanager.settings.dev` | PostgreSQL | True | Shared dev server |
| **uat** | `taskmanager.settings.uat` | PostgreSQL | False | User acceptance testing |
| **prod** | `taskmanager.settings.prod` | PostgreSQL | False | Production |

---

## Project Structure

```
django_todo_app/
├── requirements/
│   ├── base.txt          # shared dependencies (Django, uvicorn, whitenoise…)
│   ├── local.txt         # base only (SQLite — no extra adapter)
│   ├── dev.txt           # base + psycopg2-binary
│   ├── uat.txt           # base + psycopg2-binary
│   └── prod.txt          # base + psycopg2-binary
├── taskmanager/
│   ├── settings/
│   │   ├── base.py       # shared settings (no DATABASES)
│   │   ├── local.py      # SQLite, DEBUG=True
│   │   ├── dev.py        # PostgreSQL, DEBUG=True
│   │   ├── uat.py        # PostgreSQL, DEBUG=False, no HTTPS headers
│   │   └── prod.py       # PostgreSQL, DEBUG=False, full HTTPS headers
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
├── tasks/                # core domain app
├── accounts/             # auth app
├── templates/
├── static/
├── Dockerfile            # multi-stage build
├── entrypoint.sh         # migrate → collectstatic → uvicorn
├── docker-compose.yml         # local (default, SQLite, hot-reload)
├── docker-compose.dev.yml     # dev (PostgreSQL)
├── docker-compose.uat.yml     # uat (PostgreSQL)
├── docker-compose.prod.yml    # prod (PostgreSQL, 4 workers)
└── .env.example          # template — copy to .env.<environment>
```

---

## Quick Start

### Local (Docker — SQLite, hot-reload)

```bash
# First run: copy the env template
cp .env.example .env.local          # Linux/macOS
Copy-Item .env.example .env.local   # Windows PowerShell

docker compose up --build
```

Open http://localhost:8000

### Dev server (Docker — PostgreSQL)

```bash
cp .env.example .env.dev
# Edit .env.dev — fill in SECRET_KEY, POSTGRES_* with real values

docker compose -f docker-compose.dev.yml up --build -d
docker compose -f docker-compose.dev.yml exec web python manage.py createsuperuser
```

### UAT server (Docker — PostgreSQL)

```bash
cp .env.example .env.uat
# Edit .env.uat — fill in SECRET_KEY, POSTGRES_*, ALLOWED_HOSTS

docker compose -f docker-compose.uat.yml up --build -d
docker compose -f docker-compose.uat.yml exec web python manage.py createsuperuser
```

### Production (Docker — PostgreSQL, 4 workers, HTTPS headers)

```bash
cp .env.example .env.prod
# Edit .env.prod — fill in ALL values with real secrets and your domain

docker compose -f docker-compose.prod.yml up --build -d
docker compose -f docker-compose.prod.yml exec web python manage.py createsuperuser
```

---

## Bare-Python Local Development (no Docker)

```bash
# Windows
python -m venv .venv
.venv\Scripts\Activate.ps1
Copy-Item .env.local .env        # python-decouple reads a file named ".env"
pip install -r requirements/local.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

```bash
# Linux / macOS
python3 -m venv .venv
source .venv/bin/activate
cp .env.local .env
pip install -r requirements/local.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

---

## Common Docker Commands

| Task | Local | Dev | UAT | Prod |
|------|-------|-----|-----|------|
| Build & start | `docker compose up --build` | `docker compose -f docker-compose.dev.yml up --build -d` | `docker compose -f docker-compose.uat.yml up --build -d` | `docker compose -f docker-compose.prod.yml up --build -d` |
| Stop | `docker compose down` | `docker compose -f docker-compose.dev.yml down` | `docker compose -f docker-compose.uat.yml down` | `docker compose -f docker-compose.prod.yml down` |
| View logs | `docker compose logs -f` | `docker compose -f docker-compose.dev.yml logs -f web` | same pattern | same pattern |
| Django shell | `docker compose exec web python manage.py shell` | same with `-f docker-compose.dev.yml` | same | same |
| Run migrations | `docker compose exec web python manage.py migrate` | same with `-f docker-compose.dev.yml` | same | same |
| Create superuser | `docker compose exec web python manage.py createsuperuser` | same with `-f docker-compose.dev.yml` | same | same |

---

## Environment Variable Reference

| Variable | Required by | Description |
|----------|-------------|-------------|
| `DJANGO_SETTINGS_MODULE` | all | e.g. `taskmanager.settings.prod` |
| `SECRET_KEY` | all | Long random string — generate with command below |
| `DEBUG` | all | `True` for local/dev, `False` for uat/prod |
| `ALLOWED_HOSTS` | all | Comma-separated hostnames |
| `POSTGRES_DB` | dev / uat / prod | PostgreSQL database name |
| `POSTGRES_USER` | dev / uat / prod | PostgreSQL username |
| `POSTGRES_PASSWORD` | dev / uat / prod | PostgreSQL password |
| `DB_HOST` | dev / uat / prod | PostgreSQL host (default: `db`) |
| `DB_PORT` | dev / uat / prod | PostgreSQL port (default: `5432`) |
| `APP_PORT` | all | Host port exposed by compose (default: `8000`) |
| `UVICORN_WORKERS` | prod | Number of uvicorn worker processes (default: `1`) |
| `UVICORN_LOG_LEVEL` | prod | uvicorn log level (default: `info`) |
| `EMAIL_HOST` | prod | SMTP hostname |
| `EMAIL_PORT` | prod | SMTP port (default: `587`) |
| `EMAIL_USE_TLS` | prod | `True` / `False` |
| `EMAIL_HOST_USER` | prod | SMTP username |
| `EMAIL_HOST_PASSWORD` | prod | SMTP password |

### Generate a SECRET_KEY

**Recommended — Python `secrets` module (no Django required):**

```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

This uses the Python standard library's cryptographically secure random number generator and works even before Django is installed. It produces a 67-character URL-safe string that exceeds Django's minimum key entropy requirements.

**Alternative — Django's built-in utility (requires Django installed):**

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

Both produce a strong key. Prefer the `secrets` approach when generating keys outside an activated virtual environment (e.g. on a server before setup).

> **Never commit a real `SECRET_KEY` to git.** Always store it in your `.env.*` file and ensure that file is listed in `.gitignore`.

---

## Notes

- **SQLite + workers:** The local environment uses SQLite which does not support concurrent writes. `UVICORN_WORKERS` is intentionally fixed at 1 for local. PostgreSQL handles multiple workers safely.
- **HSTS in production:** `prod.py` sets `SECURE_HSTS_PRELOAD=True`. Only point your domain at the production container after TLS/HTTPS is fully configured — HSTS is difficult to reverse.
- **Static files:** WhiteNoise serves static files directly from the uvicorn process. For high-traffic deployments, place nginx in front and have it serve `staticfiles/` directly.
- **entrypoint.sh line endings:** The file must use Unix LF endings. `.gitattributes` enforces this automatically on git checkout/commit. If you edit it on Windows without git, ensure your editor saves with LF.
