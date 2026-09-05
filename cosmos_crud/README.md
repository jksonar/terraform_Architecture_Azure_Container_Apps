# Cosmos CRUD

A small Django app that does CRUD on Azure Cosmos DB (SQL API), served under
the `/cosmos_crud/` path prefix — the second workload behind the shared
Application Gateway alongside [`Django_todo_app`](../Django_todo_app), which
uses `/tasks/` and PostgreSQL instead.

There is no relational database here: all application data (`Item`s) lives in
a single Cosmos DB container, read and written directly through the
`azure-cosmos` SDK in [`items/cosmos_client.py`](items/cosmos_client.py).
Django's ORM, sessions, auth and admin apps are intentionally not installed
since nothing in this app needs a relational store.

## Endpoints

| Path                       | Purpose                              |
| -------------------------- | ------------------------------------- |
| `/cosmos_crud/`             | List items                            |
| `/cosmos_crud/create/`      | Create an item                        |
| `/cosmos_crud/<id>/`        | View an item                          |
| `/cosmos_crud/<id>/edit/`   | Update an item                        |
| `/cosmos_crud/<id>/delete/` | Delete an item (confirm page + POST)  |
| `/cosmos_crud/health/`      | Liveness probe — pings the container  |

`/cosmos_crud/health/` is what the Application Gateway backend health probe
should target.

## Configuration

All configuration comes from environment variables (via `python-decouple`),
see [`.env.example`](.env.example):

- `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS` — standard Django settings.
- `COSMOS_DB_ENDPOINT` — the Cosmos account's URI.
- `COSMOS_DB_KEY` — leave **blank** in Azure. The Container App authenticates
  with its managed identity instead (`DefaultAzureCredential`), which
  Terraform grants the **Cosmos DB Built-in Data Contributor** data-plane
  role. Set this only for local/key-based auth (e.g. the emulator).
- `COSMOS_DB_DATABASE` / `COSMOS_DB_CONTAINER` — default to `appdb` / `items`,
  matching the defaults in `modules/database`.

## Running locally

### Option A — Azure Cosmos DB Emulator

Start the [Cosmos DB Emulator](https://learn.microsoft.com/azure/cosmos-db/emulator),
then:

```bash
cp .env.example .env.local
python -m venv .venv && source .venv/bin/activate
pip install -r requirements/local.txt
python manage.py runserver
```

The `local` settings already default `COSMOS_DB_ENDPOINT`/`COSMOS_DB_KEY` to
the emulator's well-known local values, so this works with an empty
`.env.local` too.

### Option B — point at a real (dev) Cosmos account

Set `COSMOS_DB_ENDPOINT` (and optionally `COSMOS_DB_KEY`, or omit it and
`az login` first so `DefaultAzureCredential` picks up your identity — make
sure it's been granted data-plane access) in `.env.local`, then run as above.

### Docker Compose

```bash
docker compose up --build          # local, hot-reload
docker compose -f docker-compose.dev.yml up --build
```

## Image build & push

This app has no separate repository — it's built straight from this
directory as part of the Terraform repo's `scripts/build-and-push.sh`
(builds `django-todo` from `Django_todo_app/` and `cosmos-crud` from
`cosmos_crud/` and pushes both to ACR). See the root `Plan.md` for the full
foundation → build/push → workloads deployment flow.
