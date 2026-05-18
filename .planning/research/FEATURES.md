# Feature Landscape

**Domain:** VPS / Server Backup Management System
**Project:** Optimus Backup Manager
**Researched:** 2026-05-18
**Sources:** Veeam v13, BorgBackup 1.4/2.0b, Bacula Enterprise 18, Acronis Cyber Protect 2026, Restic/Duplicati/Kopia comparisons, market pitfall analyses

---

## Table Stakes

Features users expect. Missing = product feels incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Scheduled backups (cron-style) | Core promise of any backup tool | Low | Daily/weekly/monthly + custom cron expression |
| Incremental / differential backups | Storage efficiency; every tool does this | Medium | Full + incremental chain; deduplication is now expected |
| Client-side encryption | Security baseline; all serious tools do AES-256 | Medium | Key management is the hard part, not the cipher |
| Multi-storage-destination support | S3, SFTP, local, B2 are standard targets | Medium | At minimum: S3-compatible + SFTP |
| Backup integrity verification (checksums) | Users must trust their backups | Medium | Automated post-backup hash verification |
| Restore workflow (full + file-level) | Backups are worthless without verified restores | High | Full image restore AND selective file restore |
| Multi-VPS / multi-server management | Single pane of glass is expected by ops teams | High | Agents on each host reporting to central controller |
| Email / webhook notifications | Silent failures kill trust | Low | On success, failure, and warnings |
| Retention policies | Automatic pruning by age / count | Medium | GFS (Grandfather-Father-Son) is the common pattern |
| Backup job status dashboard | Ops need visibility without SSHing into servers | Medium | Per-server status, last run time, next run time |
| Audit log / history | Compliance and debugging | Low | Who triggered what, when, outcome |

---

## Differentiators

Features that provide competitive advantage. Not universally expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Backup integrity test-restore (sandbox) | Veeam SureBackup equivalent; verify restores actually work | Very High | Spin up isolated environment, boot VM/container, test |
| Deduplication across servers | Significant storage savings for fleets with similar base OS | High | Requires shared chunked repository (Duplicacy model) |
| Bandwidth throttling per schedule | Avoid saturating production network during business hours | Low-Medium | Configurable rate limits per job |
| Ransomware detection (anomaly alerting) | Detects unusual backup size spikes indicating encryption | High | Statistical anomaly on delta size; Acronis Active Protection model |
| Append-only repository mode | Backup server compromise cannot delete old backups | Medium | BorgBase model; critical for air-gap-like protection |
| One-click restore to new VPS | Disaster recovery UX; provision + restore in single flow | Very High | Requires cloud provider API integration |
| Pre/post backup hooks | Custom scripts before/after backup runs | Low | `pre_backup.sh`, `post_backup.sh` per job |
| Backup from snapshot (zero-downtime) | DB-consistent backups without stopping services | High | LVM snapshot or filesystem freeze integration |
| Web UI with mobile-responsive design | Ops can monitor from anywhere | Medium | Not CLI-only; accessible dashboard |
| Slack / PagerDuty / Telegram notifications | Modern teams use chat-ops, not just email | Low | Webhook-based; easy to add channels |
| Cost estimation per storage destination | Show projected cost before committing to S3 storage | Medium | Requires storage pricing APIs |
| Backup diff viewer | See what files changed between backup snapshots | Medium | File tree diff; useful for auditing |

---

## Anti-Features

Features to explicitly NOT build (scope creep, complexity traps, or poor ROI).

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Built-in deduplication engine from scratch | Restic, Borg, and Kopia already do this well; reimplementing is 6+ months of correctness work | Wrap restic or borg as the backup engine; own the orchestration layer |
| Built-in cloud storage (own S3-compatible backend) | Infrastructure product with massive operational burden | Delegate to Backblaze B2, Wasabi, or user-supplied S3 |
| Backup of SaaS apps (Google Workspace, M365) | Entirely different integration surface, licensing model, API rate limits | Out of scope for VPS-focused product |
| Hypervisor-level agentless backup (VMware vSphere API) | Requires deep VMware SDK integration, licensing, and testing matrix | Focus on agent-based OS-level backups via SSH/agent |
| Built-in tape backup support | Niche, requires physical hardware integration | Explicitly unsupported; reference Bacula for tape needs |
| GUI backup chain editor (visual drag-drop scheduling) | Over-engineered for ops audience; they prefer declarative config | YAML/TOML job definitions + simple web form |
| Multi-tenancy / MSP billing | Transforms product into a platform; separate product surface | Single-org focus for v1; multi-tenancy is a v2+ decision |
| AI-generated backup policies | Marketing fluff; ops don't trust AI deciding what gets backed up | Provide sensible defaults + opinionated templates |
| Certificate authority / PKI management | Out of scope; assume TLS handled externally (Nginx, Caddy) | Document setup with existing reverse proxies |

---

## Feature Dependencies

```
Backup Engine (restic/borg wrapper)
  → Scheduled Jobs (requires engine)
    → Retention Policies (requires scheduled jobs to prune)
    → Notifications (requires job execution events)
    → Audit Log (requires job execution events)

Multi-VPS Management
  → Agent on each VPS (requires agent install)
    → Central Dashboard (requires agent reporting)
      → Backup Status per Server (requires dashboard)

Client-side Encryption
  → Key Management (encryption requires key storage strategy)
    → Restore Workflow (restore requires key access)

Backup Integrity Verification
  → Restore Workflow (verification is a test restore subset)
    → Sandbox Test-Restore (full verification requires isolated environment)

Multi-storage Destination
  → S3-compatible support (baseline)
  → SFTP support (baseline)
  → Retention Policies (each destination needs its own policy)
```

---

## MVP Recommendation

**Prioritize (Phase 1-2):**
1. Backup engine wrapper (restic) with scheduled jobs
2. Multi-VPS agent + central controller
3. Client-side encryption with key management
4. S3-compatible + SFTP storage destinations
5. Retention policies (keep-last-N + GFS)
6. Email + webhook notifications
7. Backup integrity verification (checksum post-backup)
8. Web dashboard: job status, last run, next run

**Phase 3:**
9. File-level restore UI
10. Pre/post hooks
11. Append-only repository mode
12. Bandwidth throttling

**Defer (v2+):**
- Sandbox test-restore (Very High complexity)
- Cross-server deduplication (architectural decision with tradeoffs)
- One-click restore to new VPS (cloud API integration per provider)
- Ransomware anomaly detection

---

## Competitive Reference Notes

| Product | Positioning | Key Lesson |
|---------|-------------|------------|
| Veeam v13 | Enterprise VM backup; complex agent topology | Immutable repos + RBAC are now expected at enterprise; overkill for VPS focus |
| BorgBase | Managed Borg hosting; append-only mode | Append-only is a high-value security feature with low implementation cost |
| Bacula Enterprise | Flat pricing, HPC scale | Catalog in PostgreSQL/MySQL avoids scaling walls; relevant for large fleets |
| Acronis Cyber Protect | Swiss-army-knife with ransomware defense | Bundling anti-malware with backup is bloat for ops-focused product |
| Restic | CLI backup tool, no UI | Best-in-class engine to wrap; do not rewrite |
| Duplicati | GUI backup tool | UI is good; reliability has historically been problematic (db corruption issues) |
| Kopia | Modern Borg alternative | Faster, better UI than Borg; worth evaluating as engine over Borg |

---

## Sources

- [Veeam Backup & Replication User Guide](https://helpcenter.veeam.com/docs/vbr/userguide/overview.html) — HIGH confidence
- [BorgBackup Documentation](https://borgbackup.readthedocs.io/) — HIGH confidence
- [BorgBase — Simple and Secure Offsite Backups](https://www.borgbase.com/) — HIGH confidence
- [Bacula Systems Enterprise](https://www.baculasystems.com/) — MEDIUM confidence
- [Acronis Cyber Protect — VM Backup](https://www.acronis.com/en/solutions/backup/virtual/) — MEDIUM confidence
- [Restic vs BorgBackup vs Kopia on VPS 2025](https://onidel.com/blog/restic-vs-borgbackup-vs-kopia-2025) — MEDIUM confidence (WebSearch verified)
- [7 Backup Mistakes Companies Still Making in 2025](https://www.catalogicsoftware.com/blog/7-backup-mistakes-companies-still-making-in-2025) — MEDIUM confidence
- [Duplicacy vs Restic vs Borg 2025](https://mangohost.net/blog/duplicacy-vs-restic-vs-borg-which-backup-tool-is-right-in-2025/) — MEDIUM confidence
