# Domain Pitfalls

**Domain:** VPS Backup Management System (Optimus Backup Manager)
**Researched:** 2026-05-18

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or complete project failure.

---

### Pitfall 1: Backup Integrity Never Verified — Backups Are Assumed Good

**What goes wrong:** The system records "backup succeeded" based on process exit code, but never verifies that the resulting archive is actually restorable. BorgBackup borg check --verify-data is not run. Silent corruption from disk I/O errors, interrupted transfers, or repository inconsistencies go undetected until a restore is attempted — typically during an emergency.

**Why it happens:** Backup job completion is confused with backup integrity. Exit code 0 from `borg create` does not guarantee a healthy repository; it means the process finished without a fatal error.

**Consequences:** Data loss at restore time. Weeks or months of "successful" backups that cannot actually restore. Discovered only when a server is down and time is critical.

**Prevention:**
- Run `borg check` and `borg check --verify-data` on a scheduled basis (weekly at minimum) as a separate Celery task, not part of the backup task itself
- Store check results in the database and surface them in the UI as a distinct health status (separate from "last backup ran")
- Alert on check failures immediately via the notification system

**Detection warning signs:**
- Job log says "success" but no check task follows
- UI shows "last backed up: today" with no integrity score
- `borg info` shows inconsistent archive counts vs database records

**Phase:** Foundation (backup execution core) — integrity verification must be designed in from the start, not added later.

---

### Pitfall 2: Restore Is Never Tested — The Backup System Has No Verified Value

**What goes wrong:** The entire system ships with a "restore" button that has never been executed against a real server. Restore paths contain subtle errors — wrong permissions, missing sudo grants, path mismatches — that are invisible until a real restore is needed.

**Why it happens:** Backup and restore are treated as symmetric inverse operations. They are not. Restore exercises different code paths, different SSH interactions, different filesystem states.

**Consequences:** The product promises data safety but cannot deliver it. Customer trust destroyed on first recovery attempt.

**Prevention:**
- Build restore functionality in the same phase as backup execution, not later
- Create an automated restore test harness: provision a clean container or VM, execute restore, verify file checksums against original
- Add a "test restore" feature in the UI that restores to an isolated path and reports a checksum diff

**Detection warning signs:**
- Restore feature is listed as "Phase 4 or later"
- No test coverage for restore code paths
- Restore has never been run against a real BorgBackup repository during development

**Phase:** Backup Execution Core — restore must be co-developed, not deferred.

---

### Pitfall 3: BorgBackup Repository Locking and Multi-Client Access

**What goes wrong:** Multiple Celery workers attempt parallel Borg operations against the same repository. BorgBackup holds an exclusive lock during `borg create` and `borg delete`. Concurrent access from multiple workers causes lock contention, stale lock files after worker crashes, and repository corruption risk.

**Why it happens:** Celery distributes tasks across workers by default. Without explicit concurrency guards, two backup jobs for the same repository can start simultaneously.

**Consequences:** Stale lock files that block all future backups until manually cleared. Potential repository corruption. Backup jobs failing silently if lock timeout is not handled.

**Prevention:**
- Implement per-repository Celery task locking (Redis-based distributed lock or Celery chord/chain per repository)
- Set explicit lock timeout in BorgBackup config (`--lock-wait`)
- Handle `LockTimeout` exceptions explicitly and surface them in the UI, not as generic failures
- Never run more than one Borg operation per repository concurrently

**Detection warning signs:**
- No mention of per-repository locking in task design
- Multiple Celery workers share work queue without routing by repository ID
- Error logs showing `LockTimeout` with no automated recovery

**Phase:** Backup Execution Core.

---

### Pitfall 4: BorgBackup Encryption Key Loss = Permanent Data Loss

**What goes wrong:** BorgBackup repositories are initialized with encryption keys (repokey or keyfile mode). The key is never separately backed up. The server running the agent is lost (the scenario the backup is meant to protect against), taking the key with it. The remote repository exists but is permanently unreadable.

**Why it happens:** Key management is treated as the user's problem. The system backs up data but not the means to decrypt it.

**Consequences:** Complete and irrecoverable data loss even though the backup exists. Catastrophic trust failure.

**Prevention:**
- Export and escrow the BorgBackup key (`borg key export`) during repository initialization
- Store the exported key encrypted in the Optimus database, distinct from the repository
- Force users through a key verification step before marking a repository as active
- Document key recovery procedure prominently

**Detection warning signs:**
- No `borg key export` call in repository initialization code
- No key storage model in database schema
- Key management section absent from design documents

**Phase:** Repository & Agent Setup — non-negotiable, must be in the same phase as repository initialization.

---

### Pitfall 5: Celery Beat Single Point of Failure — Schedules Stop Silently

**What goes wrong:** Celery Beat (the scheduler) is a single process. If it crashes or is not restarted after a deploy, all scheduled backup jobs stop running. No alert fires. The UI still shows "next backup scheduled" based on the database record, but no job is ever dispatched.

**Why it happens:** Beat's health is not monitored. Flower (Celery's monitoring tool) does not monitor Beat. Backup schedules appear configured but are silently inactive.

**Consequences:** Days or weeks of missed backups. Discovered only when a user notices the "last backup" timestamp is stale.

**Prevention:**
- Use a heartbeat job: a trivial Celery task dispatched by Beat every 5 minutes that writes a timestamp. Monitor this timestamp externally.
- Alert if "last heartbeat" is older than 10 minutes
- Use a process supervisor (systemd, supervisord) with auto-restart for Beat
- Display Beat health status in the admin dashboard

**Detection warning signs:**
- No Beat health monitoring in architecture design
- Celery Beat runs as a standalone process without supervision
- "Next run" time in the UI is computed from schedule without verifying Beat is alive

**Phase:** Scheduling Infrastructure.

---

### Pitfall 6: SSH Keys for Agents with Overly Broad Permissions

**What goes wrong:** The Optimus agent is installed on VPS servers and connects back via SSH (or the server SSHes in). The SSH key grants full root/sudo access to the remote server. If the Optimus server is compromised, every managed VPS is compromised.

**Why it happens:** Full access is easier to implement. Scoping SSH keys to specific commands requires more initial design effort.

**Consequences:** Single point of compromise across all managed servers. A breach of the backup manager = breach of every customer VPS.

**Prevention:**
- Use `command=` restriction in `authorized_keys` to limit SSH keys to the specific Borg command only
- Example: `command="borg serve --restrict-to-path /backup/repo",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...`
- Generate per-server SSH key pairs, not a single shared key
- Store private keys encrypted at rest in the Optimus database
- Use ed25519 keys, not RSA

**Detection warning signs:**
- Single SSH key used for all agents
- No `command=` restriction in authorized_keys template
- Agent setup grants unrestricted sudo

**Phase:** Security & Agent Architecture — must be designed before first agent deployment.

---

### Pitfall 7: Storage Cost Explosion from Unconstrained Retention

**What goes wrong:** BorgBackup deduplication works well within a single repository, but retention policies are never enforced. Old archives accumulate indefinitely. Cloud storage bills grow unbounded. Users are not warned as storage approaches configured limits.

**Why it happens:** `borg prune` is not run after `borg create`. Retention policy configuration is deferred. Storage quota enforcement is not built in.

**Consequences:** Unexpected cloud storage bills. Full storage volumes causing backup failures. Users with no visibility into how much storage their backups consume.

**Prevention:**
- Always run `borg prune` as part of the backup task chain (after `borg create`, before `borg compact`)
- Expose retention policy configuration per repository (daily/weekly/monthly keep counts)
- Store and display repository size from `borg info` after each backup
- Alert when repository size exceeds a user-defined threshold
- Note: API request charges and egress fees are separate from storage volume — monitor all three

**Detection warning signs:**
- `borg prune` not in the backup task chain
- No storage quota field in repository configuration
- Repository size not stored in the database

**Phase:** Backup Execution Core and Storage/Retention configuration.

---

## Moderate Pitfalls

### Pitfall 1: Celery Task Acknowledgment Before Completion

**What goes wrong:** Celery's default `acks_late=False` acknowledges the task as received before it completes. If a worker process is killed (OOM, deploy restart) mid-backup, the task is not retried. The backup silently never finishes.

**Prevention:**
- Set `acks_late=True` on all backup tasks
- Set `reject_on_worker_lost=True` to requeue tasks if the worker dies
- For long-running backups, use a heartbeat mechanism to detect stale in-progress jobs

**Phase:** Backup Execution Core.

---

### Pitfall 2: Redis maxmemory Policy Drops Backup Tasks

**What goes wrong:** If Redis is configured with `allkeys-lru`, `allkeys-lfu`, or `allkeys-random` as the maxmemory eviction policy, Redis will silently drop queued tasks when memory is exhausted. A backup task is enqueued, Redis evicts it, the backup never runs, no error is raised.

**Prevention:**
- Configure Redis with `maxmemory-policy noeviction` for Celery broker use
- Set `maxmemory` to a safe limit and alert before it is reached
- Separate Redis instances for Celery broker and result backend if also used for caching

**Phase:** Infrastructure Setup.

---

### Pitfall 3: Large File Transfer Timeouts and SSH ControlMaster

**What goes wrong:** Large backups over SSH time out due to idle connection resets from firewalls or NAT devices, even though data is still transferring. Each new Borg segment requires a new SSH negotiation without connection reuse, adding latency overhead.

**Prevention:**
- Configure `ServerAliveInterval` and `ServerAliveCountMax` in SSH config for agent connections
- Use `ControlMaster auto` and `ControlPersist` to reuse SSH connections across Borg operations
- Set appropriate `ConnectTimeout` values

**Phase:** Agent Communication Design.

---

### Pitfall 4: Borg 2.x Is Not Production-Ready

**What goes wrong:** Borg 2.0 is still in beta (latest 1.4 stable is 1.4.4 as of 2026-03-19). Using Borg 2.x in production introduces risk of repository format changes, known stability issues, and limited community troubleshooting resources.

**Prevention:**
- Pin to Borg 1.4.x (latest stable) for all production deployments
- Track Borg 2.x progress for future migration but do not target it in initial phases
- Include the Borg version used in repository metadata to enable future migration paths

**Phase:** Technology Selection (Phase 0).

---

### Pitfall 5: BorgBackup CDC Attack (2025 Research Finding)

**What goes wrong:** Research published in 2025 demonstrated that content-defined chunking parameters (including Borg's chunker secret) can be extracted by a repo-side attacker, enabling fingerprinting attacks to identify which known files are backed up.

**Prevention:**
- Treat the Borg repository storage location as untrusted infrastructure
- Use `repokey-blake2` or `keyfile-blake2` encryption modes
- Do not store repositories on infrastructure that the client VPS owners also control

**Phase:** Security Architecture.

---

## Minor Pitfalls

### Pitfall 1: Backup Job Logs Not Streamed — Debugging Is Impossible

**What goes wrong:** Backup jobs are long-running. Without real-time log streaming from Celery tasks, users and administrators cannot tell if a job is progressing or hung. The only feedback is "running" until it eventually fails with a timeout.

**Prevention:**
- Use Celery task `update_state` to emit progress metadata
- Store Borg output (stdout/stderr) incrementally to the database or a log store
- Expose job log streaming in the UI

**Phase:** Backup Execution Core UI.

---

### Pitfall 2: No Notification for Missed Schedules

**What goes wrong:** The system sends alerts for backup failures but not for missed backups. If the schedule fires but no job is dispatched (Beat down, Redis unavailable, queue full), no alert fires. Users believe backups are running because they have not received a failure alert.

**Prevention:**
- Implement "expected heartbeat" monitoring: if no backup job starts within X minutes of the scheduled time, fire an alert
- This is distinct from failure alerts — it catches cases where the job never starts

**Phase:** Notification System.

---

### Pitfall 3: File Permission Errors on Agent Install

**What goes wrong:** The Borg binary or repository directory is installed with incorrect permissions on the remote VPS. Subsequent backups fail with permission errors that are cryptic and hard to diagnose remotely.

**Prevention:**
- Include a preflight check task that verifies Borg binary permissions, repository path access, and SSH connectivity before the first backup runs
- Surface preflight results in the onboarding UI

**Phase:** Agent Onboarding.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Repository initialization | Encryption key not escrowed | Implement `borg key export` + database storage on init |
| Backup task execution | No integrity verification | Add `borg check` as a scheduled follow-up task |
| Celery worker design | Lock contention on shared repos | Per-repository distributed locking from day one |
| Scheduling infrastructure | Beat single point of failure | Heartbeat job + external monitoring |
| SSH agent communication | Overly broad key permissions | `command=` restriction in authorized_keys template |
| Storage management | Unbounded retention | `borg prune` + `borg compact` in task chain |
| Redis infrastructure | Task eviction under memory pressure | `maxmemory-policy noeviction` |
| Restore feature | Never tested against real repos | Co-develop with backup, not as a later phase |
| Notifications | Silent missed backups (Beat down) | "Expected heartbeat" monitoring separate from failure alerts |
| Technology selection | Borg 2.x instability | Pin to Borg 1.4.x stable |

---

## Sources

- [BorgBackup FAQ — 1.4.4 stable](https://borgbackup.readthedocs.io/en/stable/faq.html) — HIGH confidence (official docs)
- [BorgBackup CDC issues 2025 — GitHub Wiki](https://github.com/borgbackup/borg/wiki/CDC-issues-reported-2025) — HIGH confidence (official project wiki)
- [Celery Task Resilience — GitGuardian](https://blog.gitguardian.com/celery-tasks-retries-errors/) — MEDIUM confidence
- [Advanced Celery for Django — Vinta Software](https://www.vintasoftware.com/blog/guide-django-celery-tasks) — MEDIUM confidence
- [Celery Tasks documentation](https://docs.celeryq.dev/en/stable/userguide/tasks.html) — HIGH confidence (official docs)
- [Why Encrypted Backups Don't Guarantee Recoverability — Bacula Systems](https://www.baculasystems.com/blog/why-encrypted-backups-do-not-guarantee-recovery/) — MEDIUM confidence
- [Cloud Backup Costs: 3 Overlooked Charges — Eon](https://www.eon.io/blog/cloud-backup-costs) — MEDIUM confidence
- [Why Cloud Storage Costs Are Unpredictable in 2026 — Medium/Orbon Cloud](https://medium.com/@orboncloud/why-cloud-storage-costs-are-so-unpredictable-in-2026-and-what-to-do-about-it-39da22447c6c) — LOW confidence (single source, Medium blog)
- [SSH Key Management Best Practices — blackMORE Ops 2025](https://www.blackmoreops.com/2025/04/25/ssh-key-management-best-practices/) — MEDIUM confidence
- [Timeouts, Retries and Backoff with Jitter — AWS Builder's Library](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — HIGH confidence (official AWS)
- [7 Backup Mistakes Companies Still Making in 2025 — Catalogic Software](https://www.catalogicsoftware.com/blog/7-backup-mistakes-companies-still-making-in-2025) — MEDIUM confidence
- [Rsync Large Files Optimization — TutorialPedia](https://www.tutorialpedia.org/blog/speed-up-rsync-with-simultaneous-concurrent-file-transfers/) — LOW confidence
