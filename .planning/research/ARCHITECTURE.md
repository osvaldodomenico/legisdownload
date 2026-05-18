# Architecture Patterns

**Domain:** VPS Backup Management System (Optimus Backup Manager)
**Researched:** 2026-05-18
**Confidence:** HIGH (established patterns, verified against multiple sources)

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Web UI                           │
│              (Dashboard, Status, Restore Wizard)                │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS / JWT
┌────────────────────────────▼────────────────────────────────────┐
│                    FastAPI (Control Plane)                       │
│    /api/v1/servers  /api/v1/backups  /api/v1/restores           │
│    /api/v1/schedules  /api/v1/storage  /api/v1/jobs             │
└────────┬──────────────────────────────────────────┬─────────────┘
         │ Task enqueue                              │ DB read/write
┌────────▼────────────┐                ┌────────────▼─────────────┐
│   Redis (Broker     │                │   PostgreSQL              │
│   + Result backend) │                │   (servers, jobs,         │
└────────┬────────────┘                │   schedules, snapshots)   │
         │                             └──────────────────────────-┘
┌────────▼────────────────────────────────────────────────────────┐
│                  Celery Workers (Orchestration)                  │
│  - backup.trigger   - backup.verify   - restore.run             │
│  - agent.poll       - storage.sync    - report.generate         │
└────────┬────────────────────────────────────────────────────────┘
         │ SSH (restricted key) or HTTPS callback
┌────────▼────────────────────────────────────────────────────────┐
│              VPS Agent (lightweight Python daemon)              │
│              Runs on each managed VPS                           │
│  - Executes restic/borg backup commands                         │
│  - Reports status via HTTPS POST to control plane               │
│  - Manages local retention policy                               │
└────────┬────────────────────────────────────────────────────────┘
         │ restic/borg native protocols
┌────────▼────────────────────────────────────────────────────────┐
│              Storage Backends                                    │
│   S3 / Backblaze B2 / SFTP / local NFS                         │
└─────────────────────────────────────────────────────────────────┘
```

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| Flutter Web UI | Display server status, backup history, trigger restores, manage schedules | FastAPI (HTTPS/JWT) |
| FastAPI | REST API, auth, input validation, job submission, status query | Flutter UI, Celery, PostgreSQL, Redis |
| PostgreSQL | Persistent state: servers, credentials, backup jobs, schedules, snapshots | FastAPI |
| Redis | Celery broker + result backend, short-lived job state | FastAPI, Celery workers |
| Celery workers | Async orchestration: trigger backups, verify integrity, run restores, poll agents | Redis, VPS agents (SSH or HTTPS), storage backends |
| VPS agent | Execute backup tool (restic/borg) locally, report results back to control plane | Celery workers (receives commands), FastAPI (reports status via HTTPS POST) |
| Storage backends | Immutable snapshot storage (S3, B2, SFTP, local) | VPS agent (writes), Celery workers (reads for integrity checks) |

## Agent Communication Model

### Recommended: HTTPS Callback (Push from Agent)

The agent on each VPS executes backup jobs and POSTs results back to the control plane. This avoids keeping long-lived inbound connections open on managed VPS instances.

```
Celery worker  ──SSH trigger──▶  VPS agent
                                      │
                              executes restic
                                      │
                          HTTPS POST /api/v1/jobs/{id}/report
                                      ▼
                               FastAPI updates DB
```

**Why this over pure pull (Celery SSHes in to check):**
- Agents report immediately on completion — no polling latency
- SSH connections only needed for trigger, not persistent
- Agent can buffer reports if control plane is temporarily unreachable

**SSH trigger constraints (least-privilege keys):**

```
# ~/.ssh/authorized_keys on managed VPS
command="optimus-agent --run-job",no-pty,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAA...
```

Each managed VPS gets a unique ed25519 key pair. Private key stored encrypted in PostgreSQL (AES-256-GCM, key from environment secret). Never stored in plaintext.

## Data Flow

### Backup Trigger Flow

```
User clicks "Run Backup Now" in Flutter
    → POST /api/v1/backups/trigger  (JWT auth)
    → FastAPI validates, creates Job record (status=pending)
    → FastAPI enqueues backup.trigger task in Redis
    → Celery worker picks up task
    → Worker decrypts SSH key from DB
    → Worker SSHes to VPS with restricted command
    → VPS agent executes restic/borg backup
    → Agent POSTs result to /api/v1/jobs/{id}/report (with HMAC-SHA256 token)
    → FastAPI updates Job record (status=complete|failed)
    → Flutter polls /api/v1/jobs/{id} or WebSocket for live status
```

### Scheduled Backup Flow

```
Celery Beat (scheduler)
    → Enqueues backup.trigger tasks per saved schedule
    → Same flow as manual trigger from Worker step onward
```

### Restore Flow

```
User selects snapshot in Flutter restore wizard
    → POST /api/v1/restores  (snapshot_id, target_path, server_id)
    → FastAPI creates Restore Job record
    → Celery worker triggers restore via SSH restricted command
    → Agent executes restic restore / borg extract
    → Agent reports completion with file counts and duration
    → Flutter shows restore completion status
```

### Integrity Validation Flow

```
Celery Beat (daily schedule)
    → Enqueues backup.verify tasks per stored repository
    → Worker calls restic check / borg check via agent SSH
    → Results stored in SnapshotIntegrity table
    → Alerts raised if check fails (email / webhook)
```

## Security Boundaries

### Authentication Layers

| Boundary | Mechanism | Notes |
|----------|-----------|-------|
| Flutter → FastAPI | JWT (RS256) + short expiry (15 min) + refresh tokens | Standard OAuth2 with refresh |
| FastAPI → PostgreSQL | Connection string from env, never in code | Use secret manager in prod |
| FastAPI → Redis | Password-protected Redis, TLS in prod | |
| Celery → VPS agent SSH | Ed25519 keys, restricted authorized_keys | One key pair per managed VPS |
| Agent → FastAPI callback | HMAC-SHA256 shared secret per agent, passed in Authorization header | Prevents spoofed job reports |
| Agent → Storage backend | restic/borg encryption passphrase (AES-256), stored encrypted in DB | Never passed over SSH |

### SSH Key Lifecycle

```
1. User adds VPS to Optimus
2. FastAPI generates ed25519 key pair
3. Public key shown to user for placement in authorized_keys
4. Private key AES-256-GCM encrypted with master key (env var)
5. Encrypted private key stored in PostgreSQL
6. Worker decrypts on use, holds in memory only during SSH session
7. On VPS removal: revoke public key instruction shown to user
```

### Network Topology

```
┌─ Private network / Docker Compose ─────────────────────────────┐
│  FastAPI ←→ PostgreSQL                                          │
│  FastAPI ←→ Redis                                               │
│  Celery  ←→ Redis                                               │
│  Celery  ←→ PostgreSQL                                          │
└─────────────────────────────────────────────────────────────────┘
         │ Outbound only: SSH to managed VPS (port 22)
         │ Inbound: HTTPS from managed VPS agents (agent callback)
```

## Patterns to Follow

### Pattern 1: Job Record Before Execution

Create the Job DB record before enqueueing the Celery task. The job ID travels with the task, preventing orphaned jobs if the worker crashes before writing.

```python
# FastAPI endpoint
job = await db.create_job(server_id=server_id, status="pending")
task = backup_trigger.delay(job_id=job.id, server_id=server_id)
await db.update_job(job.id, celery_task_id=task.id)
return {"job_id": job.id}
```

### Pattern 2: Agent HMAC Verification

Each agent has a shared secret (32-byte random, stored in DB). All callbacks include `Authorization: HMAC-SHA256 <token>` computed over `{job_id}:{timestamp}:{status}`. Replay window: 60 seconds.

```python
# FastAPI callback handler
def verify_agent_callback(server_id: str, payload: dict, auth_header: str):
    secret = db.get_agent_secret(server_id)
    expected = hmac_sha256(secret, f"{payload['job_id']}:{payload['ts']}:{payload['status']}")
    if not hmac.compare_digest(expected, auth_header):
        raise HTTPException(403)
    if abs(time.time() - payload['ts']) > 60:
        raise HTTPException(403, "Replay detected")
```

### Pattern 3: Restic Repository Per Server

One restic repository per managed VPS, stored in the chosen backend (S3/B2/SFTP). Repository password stored encrypted per-server in DB. This isolates failures and enables per-server retention policies.

```
s3://backup-bucket/{org_id}/{server_id}/
```

### Pattern 4: Celery Task Idempotency

All Celery tasks check job status before executing. If job is already `complete` or `running`, skip. This prevents double-execution on Celery retry.

## Anti-Patterns to Avoid

### Anti-Pattern 1: SSH Private Keys in Environment Variables
**What:** Storing all SSH private keys as env vars in the worker container.
**Why bad:** Leaks all managed server access in a single breach; no per-server revocation.
**Instead:** Encrypt per-key in DB, decrypt in memory at runtime only.

### Anti-Pattern 2: Agent Polling the Control Plane
**What:** Agent repeatedly GETs /api/v1/jobs?server_id=X to check for work.
**Why bad:** Polling interval creates latency; hammers API; hard to secure (agent holds auth token).
**Instead:** Push model — Celery triggers agent via SSH command, agent pushes results back.

### Anti-Pattern 3: Running restic in FastAPI Request Handler
**What:** FastAPI endpoint directly SSHes to VPS and runs backup synchronously.
**Why bad:** Request timeouts (backups take minutes); blocks API workers; no retry logic.
**Instead:** Always enqueue as Celery task.

### Anti-Pattern 4: Shared Restic Repository Across Servers
**What:** All servers push snapshots to one repo with different tags.
**Why bad:** One corrupted repo disables all backups; one leaked password exposes all data.
**Instead:** Isolated repository per server.

## Build Order (Dependencies Drive Sequence)

```
Phase 1: Data Layer + Core API
  PostgreSQL schema (servers, jobs, schedules, snapshots, credentials)
  FastAPI skeleton + auth (JWT)
  Basic CRUD endpoints for server registration
  Reason: Everything else depends on DB and auth

Phase 2: Celery + Job Orchestration
  Redis setup
  Celery app configuration + Beat scheduler
  Job lifecycle management (create → queue → complete/fail)
  Flower for task monitoring
  Reason: Worker infrastructure needed before agent integration

Phase 3: VPS Agent
  Agent daemon (Python, systemd service)
  SSH restricted key installation workflow
  Agent callback to control plane (HMAC-verified HTTPS POST)
  Restic integration on agent
  Reason: Agent needs job IDs from Phase 2; SSH keys from Phase 1

Phase 4: Storage Integration
  S3/B2 backend configuration per server
  Restic repository initialization via agent
  Encrypted credential storage
  Reason: Agent must exist before storage can be configured per-server

Phase 5: Flutter Web UI
  Server management screens
  Backup job history + live status (WebSocket or polling)
  Schedule management
  Reason: API is stable; can build UI against real endpoints

Phase 6: Integrity Validation
  Celery Beat daily restic check jobs
  SnapshotIntegrity table + alerting
  Reason: Needs stable backup flow; adds observability layer

Phase 7: Restore System
  Restore wizard in Flutter
  Restore Celery task + agent restore command
  Partial restore (path selection) via restic --include
  Reason: Last — depends on all prior phases; highest-risk operation
```

## Scalability Considerations

| Concern | At 10 servers | At 100 servers | At 1K+ servers |
|---------|---------------|----------------|----------------|
| Celery workers | 1 worker, 4 concurrency | 2-4 workers | Dedicated worker pools per task type |
| Job scheduling | Celery Beat on single node | Beat + Redis lock for HA | Consider replacing Beat with APScheduler + DB lock |
| DB connections | Default pool | PgBouncer | PgBouncer + read replicas |
| Agent callbacks | Single FastAPI | Multiple FastAPI behind LB | Same (stateless handlers) |
| SSH key throughput | Negligible | Negligible | Parallelize Celery SSH tasks |

## Technology Decisions

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Backup tool | restic | Multi-backend (S3/B2/SFTP/local), REST API support, no server requirement, active development |
| API framework | FastAPI | Async, auto-docs, Pydantic validation, Python ecosystem for Celery integration |
| Task queue | Celery + Redis | Production-proven, retries, scheduling via Beat, Flower monitoring |
| Agent transport | SSH (trigger) + HTTPS POST (callback) | Least-privilege SSH for trigger; HTTPS callback avoids persistent inbound connections |
| Storage | PostgreSQL | ACID for job state; JSONB for flexible snapshot metadata |
| Frontend | Flutter Web | Existing project context; single codebase for potential mobile admin app |

## Sources

- [BorgBackup Pull Backup Deployment](https://github.com/borgbackup/borg/blob/master/docs/deployment/pull-backup.rst) — MEDIUM confidence (official borg docs)
- [Restic Backup Agent REST API pattern](https://github.com/misterjoshua/restic-backup-agent) — MEDIUM confidence (community reference implementation)
- [Celery + FastAPI Production Guide 2025](https://medium.com/@dewasheesh.rana/celery-redis-fastapi-the-ultimate-2025-production-guide-broker-vs-backend-explained-5b84ef508fa7) — MEDIUM confidence
- [SSH Key Management Best Practices 2026](https://www.jumpserver.com/blog/ssh-key-management-best-practices) — HIGH confidence (JumpServer enterprise PAM)
- [VPS Backup Ultimate Guide 2026](https://www.mvps.net/docs/ultimate-guide-to-vps-backups-in-2026-tools-automation-strategies) — MEDIUM confidence
- [FastAPI + Celery Official Pattern](https://testdriven.io/courses/fastapi-celery/app-factory/) — HIGH confidence (TestDriven.io reference)
