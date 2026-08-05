# BG Demo

blue-green test

## Cookiecutter variables

Drives `.env`, `.env.example`, and Docker. Identity: `project_name`, `project_slug`, `description`. Runtime and DB: `node_env`, `port`, `api_prefix`, `db_*`, `compose_db_host`, `compose_internal_db_port`, `docker_app_host_port`, `docker_db_host_port`, `node_image`, `postgres_image`. Empty `db_database` defaults to `project_slug` with hyphens → underscores.

## Local

```bash
npm install
cp .env.example .env
npm run start:dev
```

Adjust `.env` for your Postgres host/port (see `DB_*` variables).

## Docker

Uses **Postgres** (`postgres`), **Redis**, **MinIO**, the **platform** API, and a **background-worker** for BullMQ. Compose builds both app images from the **monorepo root** so `pnpm install` resolves `workspace:*` (e.g. `@vyapti/core`). Run from this directory inside the repo (e.g. `generated/<project_slug>/`).

```bash
cp .env.example .env
docker compose up --build
```

The **platform** service listens on host port `4100` → container `3000`. Postgres is on host port `5433`. The **background-worker** uses the same image build as **platform** but starts `pnpm --filter <this package> run worker:prod` from `/workspace` so paths and `VYAPTI_REPO_ROOT=/workspace` match the cookiecutter Docker image. Ensure `.env` exists (compose mounts it via `env_file`).
