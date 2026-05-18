# Roadmap: Optimus Backup Manager

## Overview

Optimus is built around one non-negotiable truth: backup sem restore comprovado nao existe. The roadmap flows from foundation (auth, infra, VPS management) through backup engine construction (jobs, databases, Docker, agent) to the integrity validation loop that is the product's core differentiator, then adds storage management, observability, and notifications. Each phase delivers a complete, verifiable capability before the next begins.

## Phases

- [ ] **Phase 1: Foundation** - Infrastructure, authentication, and VPS management running in Docker
- [ ] **Phase 2: Backup Engine** - Jobs, scheduling, database and Docker backup execution via agent
- [ ] **Phase 3: Integrity Validation** - Every backup verified, restore-tested, and status-rated
- [ ] **Phase 4: Storage Management** - Multi-provider S3-compatible storage with retention and cost visibility
- [ ] **Phase 5: Dashboard & Restore UI** - Full observability, restore workflows, and job management
- [ ] **Phase 6: Notifications** - Alerts via Telegram, Discord, email, and heartbeat monitoring

## Phase Details

### Phase 1: Foundation
**Goal**: Users can securely access the system and manage their VPS inventory in a production-grade Docker environment
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, AUTH-01, AUTH-02, AUTH-03, AUTH-04, VPS-01, VPS-02, VPS-03, VPS-04, VPS-05
**Success Criteria** (what must be TRUE):
  1. User can register, log in, and stay logged in across browser sessions via JWT with refresh token
  2. User can log out and have their token revoked immediately
  3. User can add a VPS with SSH credentials and verify connectivity before saving
  4. User can list, edit, and delete VPS entries; dashboard shows live online/offline status per VPS
  5. Entire system runs via docker-compose with HTTPS enforced and no secrets hardcoded
**Plans**: TBD

### Phase 2: Backup Engine
**Goal**: Users can define backup jobs for any combination of files, databases, and Docker volumes, which run on schedule or on demand via a secure agent
**Depends on**: Phase 1
**Requirements**: AGENT-01, AGENT-02, AGENT-03, AGENT-04, AGENT-05, AGENT-06, JOB-01, JOB-02, JOB-03, JOB-04, JOB-05, JOB-06, JOB-07, JOB-08, DB-01, DB-02, DB-03, DOCK-01, DOCK-02, DOCK-03
**Success Criteria** (what must be TRUE):
  1. User can create a backup job targeting directories, MySQL/MariaDB, PostgreSQL, MongoDB, and Docker volumes with configurable retention and exclusions
  2. User can set a cron schedule and trigger a manual backup at any time
  3. Backup agent is installed on the VPS via SSH and executes BorgBackup archives without granting full shell access
  4. Celery Beat executes scheduled jobs automatically; a heartbeat job detects if Beat dies silently
  5. Borg encryption keys are stored separately from the VPS and never transmitted in plaintext
**Plans**: TBD

### Phase 3: Integrity Validation
**Goal**: Every completed backup is automatically verified to be restorable, with a clear status and automatic retry on failure
**Depends on**: Phase 2
**Requirements**: INT-01, INT-02, INT-03, INT-04, INT-05, INT-06, INT-07
**Success Criteria** (what must be TRUE):
  1. Every archive receives a SHA256 hash immediately after creation
  2. Archive is uploaded to S3-compatible storage, re-downloaded, and hash is re-verified automatically
  3. System performs a decompression check (borg check) and a partial restore to a temp directory validating critical files
  4. Each backup is assigned a status of VERIFIED, PARTIAL, CORRUPTED, RESTORE_FAILED, or RETRYING — visible in the UI
  5. On failure, system retries up to 3 times; after 3 failures it marks the VPS as at-risk and sends a critical alert
**Plans**: TBD

### Phase 4: Storage Management
**Goal**: Users can manage where backups are stored, across multiple S3-compatible providers, with visibility into usage and cost
**Depends on**: Phase 3
**Requirements**: STR-01, STR-02, STR-03, STR-04
**Success Criteria** (what must be TRUE):
  1. User can configure one or more S3-compatible storage providers (AWS S3, Wasabi, Backblaze B2, MinIO) per VPS
  2. Dashboard shows storage usage in bytes and estimated cost per VPS
  3. Retention policy automatically prunes archives older than configured thresholds without user intervention
**Plans**: TBD

### Phase 5: Dashboard & Restore UI
**Goal**: Users can fully observe the backup system health and perform targeted restores (full, partial, or point-in-time)
**Depends on**: Phase 4
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06
**Success Criteria** (what must be TRUE):
  1. Dashboard shows all VPS with last backup time, next scheduled backup, storage usage, and integrity status at a glance
  2. User can browse the complete job history with detailed logs per execution
  3. User can initiate a full or partial restore (specific file, folder, or database) from any available backup
  4. User can select a point-in-time restore date and recover from that archive
  5. Dashboard shows a storage usage graph per VPS over time; user can view and manage all configured jobs
**Plans**: TBD

### Phase 6: Notifications
**Goal**: Users are proactively alerted to backup failures, corruption, and missed backups through their preferred channels
**Depends on**: Phase 5
**Requirements**: NOTF-01, NOTF-02, NOTF-03, NOTF-04
**Success Criteria** (what must be TRUE):
  1. User receives a Telegram message when any backup completes successfully or fails
  2. User receives a Discord webhook notification on backup completion or failure
  3. User receives an email alert on critical events: failure, corruption, or storage full
  4. System detects when a VPS has not produced a backup within its expected window and sends an alert
**Plans**: TBD

## Progress

**Execution Order:** 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/TBD | Not started | - |
| 2. Backup Engine | 0/TBD | Not started | - |
| 3. Integrity Validation | 0/TBD | Not started | - |
| 4. Storage Management | 0/TBD | Not started | - |
| 5. Dashboard & Restore UI | 0/TBD | Not started | - |
| 6. Notifications | 0/TBD | Not started | - |
