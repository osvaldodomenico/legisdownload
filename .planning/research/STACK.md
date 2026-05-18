# Stack Research

**Domain:** VPS Backup Management Platform
**Researched:** 2026-05-18
**Confidence:** HIGH (core stack) / MEDIUM (BorgBackup API patterns)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| FastAPI | 0.115.x (latest stable 2026) | HTTP API / WebSocket | Best async Python framework; native Pydantic v2 integration; OpenAPI docs free; production-proven at scale |
| Celery | 5.4.x–5.6.x | Background task queue | Dominant Python task queue (90% of production deployments use it); Redis broker support; beat scheduler built-in |
| Redis | 7.x (server), redis-py 5.x (client) | Celery broker + result backend + caching | Official Redis Python client; `redis.asyncio` replaces deprecated `aioredis`; single dependency for broker + cache |
| PostgreSQL | 16.x | Primary datastore | JSONB for backup metadata; reliable; ACID; asyncpg delivers highest async throughput |
| BorgBackup CLI | 1.4.x (stable) | Deduplicating backup engine | 2.0 is still beta (do NOT use in production as of 2026); 1.4.4 released 2026-03-19; subprocess invocation is the standard — no Python API exists |
| Docker + Compose | Docker 26.x / Compose v2 | Deployment | Single-host VPS deployment; all services containerized; production-ready Compose configs available |

### Backend Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SQLAlchemy | 2.0.x | ORM + async DB sessions | Use `postgresql+asyncpg://` URL; `pool_size=20`, `pool_pre_ping=True`, `expire_on_commit=False` for async |
| asyncpg | 0.30.x | PostgreSQL async driver | Required for SQLAlchemy async engine; highest performance PostgreSQL driver for Python |
| alembic | 1.14.x | DB schema migrations | Use `async_engine_from_config` pattern in env.py; use from day one to avoid manual ALTER TABLE disasters |
| pydantic | 2.x | Request/response validation | FastAPI bundles it; use `pydantic-settings` for env config |
| pydantic-settings | 2.x | Environment config | `.env` file loading + typed config |
| uvicorn[standard] | 0.32.x | ASGI server | Run behind nginx in production; `--workers` flag for multi-process |
| aioboto3 | 13.x | Async S3 / S3-compatible storage | Wraps boto3 with asyncio; use for Wasabi, Backblaze B2, MinIO, AWS S3; context manager required |
| aiobotocore | 2.15.x | Low-level async AWS SDK | Underpins aioboto3; pin versions tightly (aioboto3 locks aiobotocore version) |
| asyncssh | 2.22.x | SSH connections to VPS targets | 15x faster than Paramiko for concurrent multi-host SSH; native asyncio; full SSHv2 + SFTP + SCP |
| sqlalchemy-celery-beat | 0.8.x | DB-backed Celery periodic schedule | Flask/FastAPI equivalent of django-celery-beat; stores schedules in PostgreSQL via SQLAlchemy |
| flower | 2.0.x | Celery task monitoring UI | Dev + staging visibility; exposes Prometheus metrics via `--prometheus_metrics` flag |
| celery-exporter | 1.x (danihodovic/grafana fork) | Prometheus metrics for Celery | Production monitoring; integrates with Grafana dashboard 10026 |
| passlib[bcrypt] | 1.7.x | Password hashing | FastAPI auth patterns |
| python-jose[cryptography] | 3.3.x | JWT tokens | API authentication |
| httpx | 0.28.x | Async HTTP client (tests + internal) | TestClient for FastAPI; async client for webhooks |

### Frontend Libraries (Flutter Web)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_riverpod | 3.x (released Sep 2025) | State management | Preferred over BLoC for admin dashboards; type-safe, context-free, testable; use with riverpod_generator |
| riverpod_generator | 2.x | Code generation for providers | Eliminates boilerplate; use with `build_runner` |
| dio | 5.x | HTTP client | Interceptors for auth tokens; CancelToken for request cancellation; better than `http` for dashboards |
| go_router | 14.x | Navigation / routing | Declarative; deep-link support; URL-based navigation for web |
| fl_chart | 0.69.x | Charts (line, bar, pie) | 6,200+ GitHub stars; community favorite; sufficient for backup size trends and job status |
| data_table_2 | 2.x | Advanced data tables | Sortable, paginated; better than built-in DataTable for large backup job lists |
| intl | 0.19.x | Date/number formatting | Backup timestamps, file sizes |
| freezed | 2.x | Immutable data models | Use with `json_serializable` for API response models |
| json_serializable | 6.x | JSON serialization | Auto-generate fromJson/toJson |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Docker Compose v2 | Local dev orchestration | Single `docker-compose.yml` spins up FastAPI, Celery worker, beat, Redis, PostgreSQL, Flower |
| pytest + pytest-asyncio | Backend testing | `asyncio_mode = "auto"` in pytest.ini; use httpx.AsyncClient for endpoint tests |
| Ruff | Python linter + formatter | Replaces Flake8 + Black + isort in one tool; 2025 standard |
| mypy | Python type checking | Strict mode recommended for async code paths |
| build_runner | Flutter code generation | Generates Riverpod providers, Freezed models, JSON serialization |
| pre-commit | Git hooks | Run Ruff + mypy before commit |
| MinIO | Local S3 emulation | Docker image for testing S3 upload/download without cloud costs |

---

## Installation

```bash
# Backend core
pip install fastapi[all] uvicorn[standard] sqlalchemy[asyncio] asyncpg alembic
pip install "celery[redis]==5.4.*" redis aioboto3 asyncssh
pip install sqlalchemy-celery-beat flower pydantic-settings
pip install passlib[bcrypt] python-jose[cryptography] httpx

# Dev dependencies
pip install pytest pytest-asyncio ruff mypy

# Flutter (pubspec.yaml)
# flutter_riverpod: ^3.0.0
# riverpod_generator: ^2.0.0
# dio: ^5.0.0
# go_router: ^14.0.0
# fl_chart: ^0.69.0
# data_table_2: ^2.0.0
# freezed: ^2.0.0
# json_serializable: ^6.0.0
# intl: ^0.19.0
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| asyncssh | paramiko | Only if you need Ansible-compatible patterns or the team already has paramiko expertise and doesn't need concurrency |
| asyncpg (via SQLAlchemy) | psycopg3 | psycopg3 has native async too; acceptable if team prefers it; performance comparable |
| aioboto3 | boto3 (sync) | Use sync boto3 only inside Celery worker tasks (sync context); never in FastAPI async endpoints |
| sqlalchemy-celery-beat | RedBeat (Redis-backed) | RedBeat is simpler but stores schedule in Redis; use if you want schedule data collocated with broker, not PostgreSQL |
| fl_chart | Syncfusion Flutter Charts | Syncfusion if you need 30+ chart types and have commercial license budget; fl_chart covers 90% of backup dashboard needs free |
| flutter_riverpod | flutter_bloc | BLoC if team has existing BLoC codebase or needs strict Redux-style discipline |
| BorgBackup 1.4.x | BorgBackup 2.0.x | 2.0 when it exits beta and reaches production stability (expected late 2026); breaking repo format change requires migration |
| Flower | celery-exporter + Grafana | Use celery-exporter for production-grade Prometheus + Grafana; Flower is sufficient for dev/staging |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| BorgBackup 2.0.x in production | Still in beta (b21 as of 2026-03); incompatible repo format with 1.x; CLI changed — all scripts break | BorgBackup 1.4.x (1.4.4 stable) |
| aioredis (standalone) | Officially deprecated; merged into redis-py; `redis.asyncio` is the replacement | `redis.asyncio` from redis-py 5.x |
| `postgresql://` URL in SQLAlchemy async engine | Silently blocks the event loop under load — no error, but kills performance | `postgresql+asyncpg://` URL |
| Paramiko for concurrent SSH | Synchronous; thread-per-connection model; 15x slower than asyncssh for multi-host operations | asyncssh |
| Provider (Flutter) | Superseded by Riverpod; context-dependent; harder to test | flutter_riverpod |
| Django + DRF | Heavyweight for a service-oriented backup platform; Django's ORM is sync-first; adds unnecessary complexity | FastAPI + SQLAlchemy 2.0 async |
| Celery 4.x | EOL; incompatible with Redis 7.x; use 5.x | Celery 5.4+ |
| APScheduler (standalone) | Acceptable for simple cron but doesn't survive multi-worker deploys without DB backend | sqlalchemy-celery-beat (integrates with Celery's infrastructure) |

---

## Stack Patterns by Variant

**If running multiple Celery workers (scale-out):**
- Use sqlalchemy-celery-beat, not the default file-based beat scheduler
- Only one beat process should run; separate it from workers in Docker Compose
- Pattern: `celery -A app.worker beat` as its own container, `celery -A app.worker worker -Q backups,maintenance` as separate containers

**If S3 target is self-hosted (MinIO/Ceph):**
- aioboto3 works identically; set `endpoint_url` in client config
- No additional library needed; S3 API is fully compatible

**If SSH targets use key-based auth (recommended):**
- Store private keys encrypted in PostgreSQL (use `pgcrypto` or application-level encryption)
- asyncssh loads keys with `asyncssh.read_private_key()` — supports Ed25519, RSA, ECDSA

**If backup job output streaming is required (live logs in UI):**
- Expose SSE (Server-Sent Events) endpoint in FastAPI with async generator
- Celery task writes log lines to Redis list; FastAPI SSE endpoint polls and streams to Flutter frontend

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| celery[redis] 5.4.x | redis-py 5.x | Use `celery[redis]` extra; do NOT install standalone `redis` separately — version conflict risk |
| aioboto3 13.x | aiobotocore 2.15.x | aioboto3 pins exact aiobotocore version; do not upgrade aiobotocore independently |
| SQLAlchemy 2.0.x | asyncpg 0.29–0.30.x | Use `sqlalchemy[asyncio]` extra |
| BorgBackup 1.4.x | Python 3.10+ | Subprocess calls; no Python API to worry about version-pinning |
| flutter_riverpod 3.x | Dart 3.x / Flutter 3.24+ | Riverpod 3 requires Dart 3 sound null safety |

---

## Sources

- [FastAPI Best Practices for Production: Complete 2026 Guide](https://fastlaunchapi.dev/blog/fastapi-best-practices-production-2026) — FastAPI versions, patterns (MEDIUM confidence)
- [How to Set Up a FastAPI + PostgreSQL + Celery Stack with Docker Compose](https://oneuptime.com/blog/post/2026-02-08-how-to-set-up-a-fastapi-postgresql-celery-stack-with-docker-compose/view) — Celery + FastAPI integration (MEDIUM confidence)
- [Building High-Performance Async APIs with FastAPI, SQLAlchemy 2.0, and Asyncpg](https://leapcell.io/blog/building-high-performance-async-apis-with-fastapi-sqlalchemy-2-0-and-asyncpg) — asyncpg patterns (MEDIUM confidence)
- [AsyncSSH documentation 2.22.0](https://asyncssh.readthedocs.io/) — AsyncSSH API (HIGH confidence)
- [borgbackup PyPI](https://pypi.org/project/borgbackup/) — Borg versions; 1.4.4 stable, 2.0 beta (HIGH confidence)
- [Borg 2.0 production status](https://www.borgbackup.org/releases/borg-2.0.html) — "Do not use in production" confirmation (HIGH confidence)
- [aioboto3 PyPI](https://pypi.org/project/aioboto3/) — aioboto3 versions and asyncpg dependency lock (HIGH confidence)
- [sqlalchemy-celery-beat PyPI](https://pypi.org/project/sqlalchemy-celery-beat/) — FastAPI-compatible beat scheduler (MEDIUM confidence)
- [Celery-exporter GitHub (grafana fork)](https://github.com/grafana/celery-exporter) — Prometheus metrics (MEDIUM confidence)
- [State Management in Flutter: Riverpod 3.0 vs BLoC 2025](https://medium.com/@sthomason/flutter-state-management-in-2025-why-mastering-bloc-and-riverpod-is-no-longer-optional-c63ef5e1f2be) — Flutter state management guidance (MEDIUM confidence)

---

*Stack research for: Optimus Backup Manager — VPS Backup Management Platform*
*Researched: 2026-05-18*
