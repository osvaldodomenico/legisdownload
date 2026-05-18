# Requirements: Optimus Backup Manager

**Defined:** 2026-05-18
**Core Value:** Todo backup deve ser validado e restaurável — backup sem restore comprovado não existe.

## v1 Requirements

### Authentication & Users

- [ ] **AUTH-01**: Usuário pode criar conta com email e senha (admin inicial)
- [ ] **AUTH-02**: Usuário pode fazer login e manter sessão via JWT + Refresh Token
- [ ] **AUTH-03**: Usuário pode fazer logout e ter token revogado
- [ ] **AUTH-04**: Sessão persiste via refresh token com expiração configurável

### VPS Management

- [ ] **VPS-01**: Usuário pode cadastrar VPS com nome, IP, porta SSH, usuário SSH e chave privada
- [ ] **VPS-02**: Sistema armazena chave SSH criptografada com AES-256-GCM (nunca em texto plano)
- [ ] **VPS-03**: Usuário pode testar conectividade SSH ao cadastrar VPS
- [ ] **VPS-04**: Usuário pode listar, editar e remover VPS cadastradas
- [ ] **VPS-05**: Sistema exibe status online/offline de cada VPS no dashboard

### Backup Engine & Agent

- [ ] **AGENT-01**: Sistema instala/configura agente Python leve na VPS via SSH
- [ ] **AGENT-02**: Agente executa BorgBackup 1.4.x via subprocess para criar archives
- [ ] **AGENT-03**: Sistema usa chave SSH com restricted command para acionar agente (sem shell completo)
- [ ] **AGENT-04**: Agente envia resultado via HTTPS POST callback com HMAC de autenticação
- [ ] **AGENT-05**: Sistema mantém lock distribuído por repositório Borg (evitar corrupção paralela)
- [ ] **AGENT-06**: Chave de criptografia Borg é custodiada (escrowed) em local separado da VPS

### Backup Jobs & Scheduling

- [ ] **JOB-01**: Usuário pode criar job de backup FULL com diretórios, bancos e Docker volumes configuráveis
- [ ] **JOB-02**: Usuário pode criar job incremental (BorgBackup deduplicado)
- [ ] **JOB-03**: Usuário pode configurar schedule cron (horários personalizados)
- [ ] **JOB-04**: Sistema executa jobs automaticamente via Celery Beat com sqlalchemy-celery-beat
- [ ] **JOB-05**: Sistema monitora Celery Beat com heartbeat job (detectar Beat morto silenciosamente)
- [ ] **JOB-06**: Usuário pode acionar backup manual a qualquer momento
- [ ] **JOB-07**: Sistema configura retenção (diário, semanal, mensal, quantidade)
- [ ] **JOB-08**: Sistema suporta exclusões de diretórios por job

### Database Backup

- [ ] **DB-01**: Sistema realiza dump MySQL/MariaDB (mysqldump --all-databases)
- [ ] **DB-02**: Sistema realiza dump PostgreSQL (pg_dumpall)
- [ ] **DB-03**: Sistema realiza dump MongoDB (mongodump) quando disponível

### Docker Backup

- [ ] **DOCK-01**: Sistema faz backup de volumes Docker nomeados
- [ ] **DOCK-02**: Sistema inclui docker-compose.yml no backup
- [ ] **DOCK-03**: Sistema exporta lista de containers e imagens em uso

### Integrity Validation

- [ ] **INT-01**: Sistema gera SHA256 do archive após criação local
- [ ] **INT-02**: Sistema faz upload para S3-compatible e redownload automático para verificar hash
- [ ] **INT-03**: Sistema executa teste de descompressão (borg check / tar -tf)
- [ ] **INT-04**: Sistema executa restore parcial em diretório temporário e valida arquivos críticos
- [ ] **INT-05**: Sistema atribui status: VERIFIED / PARTIAL / CORRUPTED / RESTORE_FAILED / RETRYING
- [ ] **INT-06**: Sistema retenta automaticamente até 3 vezes em caso de falha
- [ ] **INT-07**: Após 3 falhas, marca VPS como risco e envia alerta crítico

### Storage

- [ ] **STR-01**: Sistema integra com S3-compatible (AWS S3, Wasabi, Backblaze B2, MinIO)
- [ ] **STR-02**: Usuário pode configurar múltiplos providers de storage por VPS
- [ ] **STR-03**: Sistema exibe uso de espaço e estimativa de custo por VPS
- [ ] **STR-04**: Sistema implementa política de retenção e limpeza automática de archives antigos

### Notifications

- [ ] **NOTF-01**: Sistema envia notificação Telegram em backup concluído/falho
- [ ] **NOTF-02**: Sistema envia notificação Discord (webhook) em backup concluído/falho
- [ ] **NOTF-03**: Sistema envia email em eventos críticos (falha, corrupção, storage lotado)
- [ ] **NOTF-04**: Sistema detecta VPS que não gerou backup no período esperado (expected-heartbeat)

### Dashboard & UI

- [ ] **UI-01**: Dashboard exibe status de todas as VPS, último backup, próximo, espaço e integridade
- [ ] **UI-02**: Usuário pode ver histórico completo de jobs com logs detalhados
- [ ] **UI-03**: Usuário pode acionar restore completo ou parcial (arquivo, pasta, banco)
- [ ] **UI-04**: Usuário pode escolher restore point-in-time (data específica)
- [ ] **UI-05**: Dashboard exibe gráfico de uso de storage por VPS ao longo do tempo
- [ ] **UI-06**: Usuário pode visualizar e gerenciar jobs de backup

### Infrastructure

- [ ] **INFRA-01**: Sistema dockerizado (frontend, backend, postgres, redis, celery, nginx)
- [ ] **INFRA-02**: HTTPS obrigatório com nginx reverse proxy
- [ ] **INFRA-03**: Variáveis de ambiente via .env para secrets (nunca hardcoded)

---

## v2 Requirements

### Advanced Restore

- **REST-V2-01**: Restore sandbox automático com ambiente Docker temporário completo
- **REST-V2-02**: Restore em 1 clique com validação automática pós-restore

### Monitoring

- **MON-V2-01**: Métricas Prometheus + Grafana dashboard
- **MON-V2-02**: Alertas baseados em CPU/RAM das VPS gerenciadas

### Enterprise

- **ENT-V2-01**: Multi-tenancy (múltiplas organizações)
- **ENT-V2-02**: Append-only repository mode (proteção ransomware)
- **ENT-V2-03**: Backup hooks (pre/post scripts customizados)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Suporte a Windows | Foco Linux VPS — Windows tem arquitetura de backup diferente |
| Proxmox / Kubernetes | Alta complexidade, fase enterprise futura |
| Snapshots LVM | Requer acesso root privilegiado específico — fora do MVP |
| WhatsApp | API instável/paga sem garantias — substituível por Telegram |
| Storage próprio (cloud) | Sem lock-in — usar S3-compatible existente |
| Tape backup | Contexto enterprise muito específico |
| Agentless backup | Requer hypervisor — fora do escopo VPS |
| BorgBackup 2.x | Ainda em beta (2026-03) — aguardar estabilização |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Pending |
| AUTH-02 | Phase 1 | Pending |
| AUTH-03 | Phase 1 | Pending |
| AUTH-04 | Phase 1 | Pending |
| VPS-01 | Phase 1 | Pending |
| VPS-02 | Phase 1 | Pending |
| VPS-03 | Phase 1 | Pending |
| VPS-04 | Phase 1 | Pending |
| VPS-05 | Phase 1 | Pending |
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Pending |
| AGENT-01 | Phase 2 | Pending |
| AGENT-02 | Phase 2 | Pending |
| AGENT-03 | Phase 2 | Pending |
| AGENT-04 | Phase 2 | Pending |
| AGENT-05 | Phase 2 | Pending |
| AGENT-06 | Phase 2 | Pending |
| JOB-01 | Phase 2 | Pending |
| JOB-02 | Phase 2 | Pending |
| JOB-03 | Phase 2 | Pending |
| JOB-04 | Phase 2 | Pending |
| JOB-05 | Phase 2 | Pending |
| JOB-06 | Phase 2 | Pending |
| JOB-07 | Phase 2 | Pending |
| JOB-08 | Phase 2 | Pending |
| DB-01 | Phase 2 | Pending |
| DB-02 | Phase 2 | Pending |
| DB-03 | Phase 2 | Pending |
| DOCK-01 | Phase 2 | Pending |
| DOCK-02 | Phase 2 | Pending |
| DOCK-03 | Phase 2 | Pending |
| INT-01 | Phase 3 | Pending |
| INT-02 | Phase 3 | Pending |
| INT-03 | Phase 3 | Pending |
| INT-04 | Phase 3 | Pending |
| INT-05 | Phase 3 | Pending |
| INT-06 | Phase 3 | Pending |
| INT-07 | Phase 3 | Pending |
| STR-01 | Phase 4 | Pending |
| STR-02 | Phase 4 | Pending |
| STR-03 | Phase 4 | Pending |
| STR-04 | Phase 4 | Pending |
| UI-01 | Phase 5 | Pending |
| UI-02 | Phase 5 | Pending |
| UI-03 | Phase 5 | Pending |
| UI-04 | Phase 5 | Pending |
| UI-05 | Phase 5 | Pending |
| UI-06 | Phase 5 | Pending |
| NOTF-01 | Phase 6 | Pending |
| NOTF-02 | Phase 6 | Pending |
| NOTF-03 | Phase 6 | Pending |
| NOTF-04 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 44 total
- Mapped to phases: 44
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-18*
*Last updated: 2026-05-18 — phase traceability expanded to per-requirement rows*