# Project Research Summary

**Project:** Optimus Backup Manager
**Domain:** VPS / Server Backup Management Platform
**Researched:** 2026-05-18
**Confidence:** HIGH (stack + pitfalls) / MEDIUM (architecture patterns)

## Executive Summary

Optimus Backup Manager is a centralized VPS backup orchestration platform built on well-established open-source primitives. The recommended approach is to wrap BorgBackup 1.4.x (stable) as the backup engine rather than build deduplication from scratch, expose orchestration through a FastAPI control plane with Celery for async job execution, deploy a lightweight Python agent on each managed VPS, and present everything through the existing Flutter Web frontend. This is the dominant pattern used by serious backup platforms (BorgBase, Bacula); the "do not reimplement the engine" principle is non-negotiable.

The highest-risk aspect of this project is the gap between "backup succeeded" and "backup is actually restorable." Research consistently identifies this as the most common failure mode in backup systems. Integrity verification (scheduled `borg check`) and co-development of the restore workflow alongside the backup workflow are not optional polish — they are the core value proposition. A backup system that has never verified a restore is not a backup system.

Key infrastructure risks are: BorgBackup repository locking under concurrent Celery workers, Celery Beat as a silent single point of failure for schedules, encryption key escrow (key loss = permanent data loss even if backup exists), and Redis task eviction under memory pressure. All of these must be designed in from Phase 1, not addressed as incidents later.

---

## Key Findings

### Recommended Stack

The backend stack is FastAPI 0.115.x + Celery 5.4.x + Redis 7.x + PostgreSQL 16.x, all containerized with Docker Compose. BorgBackup 1.4.x (1.4.4, released 2026-03-19) is the backup engine — invoked via subprocess, as no Python API exists. BorgBackup 2.0 is still in beta and must not be used in production. asyncssh 2.22.x handles SSH connections to managed VPS targets (15x faster than paramiko for concurrent multi-host SSH). aioboto3 13.x handles async S3-compatible storage. SQLAlchemy 2.0 async with asyncpg is the ORM layer. The Flutter frontend uses Riverpod 3.x for state management with go_router 14.x and fl_chart 0.69.x.

**Core technologies:**
- FastAPI 0.115.x: HTTP API and WebSocket — async-native, auto-generates OpenAPI docs, Pydantic v2 integration
- Celery 5.4.x + Redis 7.x: task queue and broker — retry logic, Beat scheduler, Flower monitoring
- PostgreSQL 16.x: primary datastore — JSONB for snapshot metadata, ACID for job state
- BorgBackup 1.4.x: backup engine — deduplicating, encrypting, subprocess-invoked
- asyncssh 2.22.x: SSH to VPS agents — concurrent, async, Ed25519/RSA/ECDSA
- aioboto3 13.x: async S3/B2/MinIO access — requires context manager pattern
- flutter_riverpod 3.x: Flutter state management — type-safe, context-free, testable

**Critical version constraints:**
- Do NOT use BorgBackup 2.0.x (beta, breaking repo format)
- Do NOT use standalone `aioredis` (deprecated; use `redis.asyncio` from redis-py 5.x)
- Always use `postgresql+asyncpg://` URL (not `postgresql://`) to avoid silent event loop blocking
- Pin aioboto3 and aiobotocore together (aioboto3 locks exact aiobotocore version)

### Expected Features

**Must have (table stakes):**
- Scheduled backups (cron-style: daily/weekly/monthly + custom expressions)
- Incremental backups with deduplication (via BorgBackup)
- Client-side AES-256 encryption with key management and escrow
- Multi-storage destination support (S3-compatible + SFTP minimum)
- Backup integrity verification (scheduled `borg check`, not just exit code)
- Restore workflow — full and file-level (backups without verified restores have no value)
- Multi-VPS management (central controller + agent per VPS)
- Email + webhook notifications (success, failure, missed schedule)
- Retention policies (GFS pattern: keep-last-N + daily/weekly/monthly)
- Backup job status dashboard (per-server status, last run, next run)
- Audit log

**Should have (competitive differentiators):**
- Append-only repository mode (BorgBase model; high security value, moderate effort)
- Pre/post backup hooks per job
- Bandwidth throttling per schedule
- Backup diff viewer (file tree diff between snapshots)
- Live job log streaming in UI
- Slack/PagerDuty/Telegram webhook notifications
- Storage size tracking and cost estimation per destination

**Defer to v2+:**
- Sandbox test-restore (spin up isolated environment to verify boot) — Very High complexity
- Cross-server deduplication — architectural decision with significant tradeoffs
- One-click restore to new VPS (requires cloud provider API integration per provider)
- Ransomware anomaly detection (statistical delta size analysis)
- Multi-tenancy / MSP billing

**Anti-features (explicitly avoid):**
- Built-in deduplication engine from scratch (Borg does this; do not reimplement)
- Own S3-compatible backend (infrastructure burden; delegate to Wasabi/B2/user-supplied S3)
- SaaS app backup (Google Workspace etc.) — different surface entirely
- Hypervisor-level agentless backup (VMware SDK) — out of scope
- AI-generated backup policies — ops don't trust AI deciding what gets backed up

### Architecture Approach

The architecture is a hub-and-spoke control plane with push-trigger, push-callback agent communication. The FastAPI control plane manages all state in PostgreSQL and dispatches work via Celery tasks into Redis. Celery workers trigger VPS agents via restricted SSH commands; agents execute the backup locally and POST results back to the control plane via HMAC-verified HTTPS callbacks. This avoids persistent inbound connections on managed VPS instances. Storage backends (S3/B2/SFTP) are written to directly by the agent using restic/borg native protocols — the control plane never handles backup data.

**Major components:**
1. Flutter Web UI — server status, backup history, schedule management, restore wizard
2. FastAPI control plane — REST API, JWT auth, job creation, status queries; never executes backups directly
3. PostgreSQL — all persistent state: servers, jobs, schedules, snapshots, credentials, integrity results
4. Redis — Celery broker and result backend; must use `noeviction` policy
5. Celery workers + Beat — async orchestration, scheduled jobs, integrity checks, notifications
6. VPS agent (lightweight Python daemon) — executes borg/restic, reports via HTTPS POST with HMAC auth
7. Storage backends — S3/B2/SFTP; written directly by agent

**Key patterns:**
- Create Job DB record before enqueueing Celery task (prevents orphaned jobs on worker crash)
- Isolated restic repository per server (`s3://bucket/{org_id}/{server_id}/`) — no shared repos
- Per-repository distributed lock in Redis to prevent concurrent Borg operations
- SSH keys with `command=` restriction in authorized_keys (not unrestricted root access)
- Ed25519 per-server key pairs, private keys AES-256-GCM encrypted in PostgreSQL, decrypted in memory only
- Celery tasks: `acks_late=True` + `reject_on_worker_lost=True` for all backup tasks

### Critical Pitfalls

1. **Backup integrity never verified** — "exit code 0" is not a health check. Schedule `borg check --verify-data` as a separate weekly Celery task; store and surface results as a distinct "integrity" status in the UI. Design this in from Phase 1.

2. **Restore never tested** — co-develop restore with backup execution. Do not defer restore to a later phase. Add automated restore test harness early; a backup system with an untested restore path has no verified value.

3. **BorgBackup repository lock contention** — multiple Celery workers can attempt parallel Borg operations on the same repo. Implement per-repository Redis distributed lock before any worker parallelism. Handle `LockTimeout` explicitly in the UI, not as a generic failure.

4. **Encryption key loss = permanent data loss** — `borg key export` must be called during repository initialization and the exported key must be stored encrypted in the Optimus database, separate from the repository. This is non-negotiable and must be in the same phase as repository setup.

5. **Celery Beat silent failure** — Beat crashes silently; no Flower alert fires. Implement a heartbeat job (trivial task every 5 minutes that writes a timestamp); alert if heartbeat age exceeds 10 minutes. Display Beat health in the admin dashboard.

6. **Overly broad SSH key permissions** — use `command=` restriction in authorized_keys; generate per-server key pairs; never store unencrypted private keys in env vars or shared across servers.

7. **Unbounded retention = storage cost explosion** — always run `borg prune` + `borg compact` as part of the backup task chain; expose retention policy configuration per repository; store and display repository size after each backup.

8. **Redis task eviction** — configure `maxmemory-policy noeviction` for the Celery broker Redis instance. If Redis is also used for caching, use separate instances.

---

## Implications for Roadmap

Based on the dependency graph from ARCHITECTURE.md and the pitfall phase warnings, the natural build order is:

### Phase 1: Data Layer + Control Plane Foundation
**Rationale:** Everything depends on DB schema and auth. Establish the foundation before any execution logic.
**Delivers:** PostgreSQL schema (servers, jobs, schedules, snapshots, credentials, integrity), FastAPI skeleton with JWT auth, server CRUD endpoints, encrypted SSH key storage model, Alembic migrations from day one.
**Addresses:** Server registration (table stakes), key management foundation (pitfall 4 prevention).
**Avoids:** Schema debt that causes rewrites; no manual ALTER TABLE disasters without Alembic.
**Research flag:** Standard patterns — skip research-phase.

### Phase 2: Celery + Job Orchestration Infrastructure
**Rationale:** Worker infrastructure must exist before agent integration. Scheduling layer must be designed before backup tasks.
**Delivers:** Redis setup, Celery app config, Beat scheduler (sqlalchemy-celery-beat for DB-backed schedules), job lifecycle (pending → running → complete/failed), Flower monitoring, Beat heartbeat job.
**Addresses:** Scheduled backups (table stakes), Beat SPOF mitigation (critical pitfall 5).
**Avoids:** `allkeys-lru` Redis eviction (pitfall: configure `noeviction` here), acks_late on all tasks.
**Research flag:** Standard patterns — skip research-phase.

### Phase 3: VPS Agent + Backup Execution Core
**Rationale:** Requires job IDs from Phase 2 and SSH key infrastructure from Phase 1. This is the highest-complexity phase and must include integrity verification and restore co-development.
**Delivers:** Agent daemon (systemd service), SSH restricted key installation workflow, HMAC-verified HTTPS callback to control plane, restic/borg integration, backup execution task chain (create → prune → compact → check), per-repository Redis distributed lock, `borg key export` + escrow on repo init, file-level restore workflow, preflight check on agent onboarding.
**Addresses:** Backup engine (table stakes), integrity verification (critical pitfall 1), restore co-development (critical pitfall 2), repo locking (critical pitfall 3), key escrow (critical pitfall 4), SSH key scope (critical pitfall 6), retention (critical pitfall 7).
**Avoids:** Deferring restore; skipping integrity verification; assuming exit code 0 = healthy backup.
**Research flag:** Needs research-phase — agent deployment patterns, borg restricted SSH command options, HMAC callback security, restic vs borg engine decision for this use case.

### Phase 4: Storage Backend Integration
**Rationale:** Agent must exist before storage can be configured per-server. S3/B2/SFTP backends need agent for actual repository operations.
**Delivers:** S3-compatible + SFTP backend config per server, restic repository initialization via agent, encrypted credential storage, storage size tracking from `borg info`, retention policy configuration UI.
**Addresses:** Multi-storage destination support (table stakes), storage cost visibility (differentiator).
**Avoids:** Storage credential leakage (encrypted per-server in DB); unbounded storage bills (retention policy required before activation).
**Research flag:** Standard patterns — skip research-phase (aioboto3 patterns well-documented).

### Phase 5: Flutter Web UI
**Rationale:** API is stable after Phase 4; build UI against real endpoints, not mocks.
**Delivers:** Server management screens, backup job history + live status (SSE or WebSocket), schedule management, restore wizard (full + file-level), integrity health status display, Beat health indicator.
**Addresses:** Dashboard (table stakes), mobile-responsive web UI (differentiator), live log streaming (minor pitfall).
**Avoids:** Building UI before API is stable; using Provider instead of Riverpod.
**Research flag:** Standard patterns — Flutter Riverpod patterns are well-documented.

### Phase 6: Notifications + Observability
**Rationale:** Needs stable job execution events from Phase 3. Builds the alerting layer that makes the system trustworthy.
**Delivers:** Email + webhook notifications (success/failure/missed schedule), expected-heartbeat monitoring for missed backups, Celery Beat health alerting, Prometheus metrics via celery-exporter + Flower, Grafana dashboard.
**Addresses:** Notifications (table stakes), silent missed backup detection (minor pitfall 2).
**Avoids:** Alerting only on failures (missed schedules are invisible without expected-heartbeat monitoring).
**Research flag:** Standard patterns — skip research-phase.

### Phase 7: Differentiators (Post-MVP)
**Rationale:** All table stakes delivered; add competitive features.
**Delivers:** Append-only repository mode, pre/post backup hooks, bandwidth throttling, backup diff viewer, Slack/PagerDuty/Telegram integrations.
**Addresses:** Differentiator features from FEATURES.md.
**Research flag:** Append-only mode needs research into BorgBase/Borg serve pattern for implementation.

### Phase Ordering Rationale

- Phases 1-2 establish infrastructure that every other phase depends on; no shortcuts here.
- Phase 3 is the largest and riskiest phase. Restore and integrity verification MUST be in this phase, not split out later — this is the primary lesson from pitfalls research.
- Phase 4 (storage) depends on Phase 3 (agent) because repository initialization happens on the agent.
- Phase 5 (UI) is deferred until Phase 4 because building against a stable API prevents rework.
- Phase 6 (notifications) is separated from Phase 3 because it adds observability on top of a working system rather than being core execution logic.
- Phase 7 is explicitly post-MVP; the listed differentiators have value but none are table stakes.

### Research Flags

Phases needing deeper research during planning:
- **Phase 3 (Agent + Backup Execution):** Agent deployment and update patterns; borg restricted-mode SSH command configuration; restic vs borg final engine decision (restic has multi-backend native support, borg has stronger deduplication — requires decision before Phase 3 starts); HMAC callback security review.

Phases with standard patterns (skip research-phase):
- **Phase 1:** FastAPI + SQLAlchemy + Alembic patterns are extremely well-documented.
- **Phase 2:** Celery + Redis + Beat configuration is production-standard.
- **Phase 4:** aioboto3 + S3-compatible backends have comprehensive documentation.
- **Phase 5:** Flutter Riverpod + dio + go_router patterns are well-established.
- **Phase 6:** Notification webhooks and Celery monitoring patterns are standard.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core libraries verified against official PyPI and docs; version constraints confirmed (Borg 1.4.4 stable, Borg 2.0 beta, aioredis deprecated, asyncpg URL requirement) |
| Features | HIGH | Benchmarked against 6 competitor products (Veeam, BorgBase, Bacula, Acronis, Restic, Duplicati); table stakes are consistent across all |
| Architecture | MEDIUM | Hub-and-spoke + push/callback pattern is well-established; specific agent deployment and update mechanism needs deeper research in Phase 3 planning |
| Pitfalls | HIGH | Critical pitfalls corroborated across multiple independent sources (official Borg docs, Celery official docs, AWS Builders Library, enterprise backup vendors) |

**Overall confidence:** HIGH for technology decisions and feature scope; MEDIUM for agent deployment specifics.

### Gaps to Address

- **Restic vs BorgBackup engine decision:** FEATURES.md and ARCHITECTURE.md both reference restic as the primary engine choice (better multi-backend native support, no server requirement, REST API support) while STACK.md lists BorgBackup as the backup engine. This tension must be resolved before Phase 3. Recommendation: evaluate restic as primary engine given its native S3/B2/SFTP support without `borg serve` complexity, with BorgBackup as fallback for deduplication-heavy use cases. This decision affects the entire agent design.
- **Agent update and versioning mechanism:** How the lightweight Python agent is distributed and updated across managed VPS servers is not fully resolved. Options (pip install from private registry, single binary via PyInstaller, system package) each have different security and operational tradeoffs. Needs resolution in Phase 3 planning.
- **BorgBackup CDC fingerprinting (2025):** Research identified a 2025 finding about content-defined chunking parameter extraction enabling file-presence fingerprinting. Impact assessment needed: does this affect threat model for typical VPS backup customers? Mitigation (repokey-blake2, untrusted storage) should be validated against the restic engine decision.

---

## Sources

### Primary (HIGH confidence)
- [BorgBackup Documentation](https://borgbackup.readthedocs.io/) — engine behavior, lock model, key export, restricted SSH
- [borgbackup PyPI](https://pypi.org/project/borgbackup/) — version confirmation (1.4.4 stable, 2.0 beta)
- [AsyncSSH documentation 2.22.0](https://asyncssh.readthedocs.io/) — SSH patterns
- [aioboto3 PyPI](https://pypi.org/project/aioboto3/) — version pinning with aiobotocore
- [Celery Tasks documentation](https://docs.celeryq.dev/en/stable/userguide/tasks.html) — acks_late, reject_on_worker_lost
- [FastAPI + Celery Official Pattern](https://testdriven.io/courses/fastapi-celery/app-factory/) — production integration
- [SSH Key Management Best Practices](https://www.jumpserver.com/blog/ssh-key-management-best-practices) — command= restriction patterns
- [AWS Builder's Library — Timeouts, Retries and Backoff](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — resilience patterns

### Secondary (MEDIUM confidence)
- [FastAPI Best Practices for Production 2026](https://fastlaunchapi.dev/blog/fastapi-best-practices-production-2026) — FastAPI patterns
- [Building High-Performance Async APIs with FastAPI, SQLAlchemy 2.0, and Asyncpg](https://leapcell.io/blog/building-high-performance-async-apis-with-fastapi-sqlalchemy-2-0-and-asyncpg) — asyncpg patterns
- [Restic vs BorgBackup vs Kopia 2025](https://onidel.com/blog/restic-vs-borgbackup-vs-kopia-2025) — engine comparison
- [Duplicacy vs Restic vs Borg 2025](https://mangohost.net/blog/duplicacy-vs-restic-vs-borg-which-backup-tool-is-right-in-2025/) — engine comparison
- [Veeam Backup & Replication User Guide](https://helpcenter.veeam.com/docs/vbr/userguide/overview.html) — feature benchmarking
- [7 Backup Mistakes Companies Still Making in 2025](https://www.catalogicsoftware.com/blog/7-backup-mistakes-companies-still-making-in-2025) — pitfall validation
- [Celery + FastAPI Production Guide 2025](https://medium.com/@dewasheesh.rana/celery-redis-fastapi-the-ultimate-2025-production-guide-broker-vs-backend-explained-5b84ef508fa7)
- [State Management in Flutter: Riverpod 3.0 vs BLoC 2025](https://medium.com/@sthomason/flutter-state-management-in-2025-why-mastering-bloc-and-riverpod-is-no-longer-optional-c63ef5e1f2be)
- [VPS Backup Ultimate Guide 2026](https://www.mvps.net/docs/ultimate-guide-to-vps-backups-in-2026-tools-automation-strategies)
- [Why Encrypted Backups Don't Guarantee Recoverability — Bacula Systems](https://www.baculasystems.com/blog/why-encrypted-backups-do-not-guarantee-recovery/)
- [Cloud Backup Costs: 3 Overlooked Charges — Eon](https://www.eon.io/blog/cloud-backup-costs)
- [BorgBackup CDC issues 2025 — GitHub Wiki](https://github.com/borgbackup/borg/wiki/CDC-issues-reported-2025)

---
*Research completed: 2026-05-18*
*Ready for roadmap: yes*
