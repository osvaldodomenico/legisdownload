# Optimus Backup Manager

## What This Is

Plataforma completa de gerenciamento de backup para servidores VPS Linux, permitindo realizar backups FULL e incrementais de aplicações, bancos de dados, containers Docker e arquivos do sistema. O sistema garante integridade via SHA256, restore inteligente com sandbox de validação e monitoramento centralizado via painel web.

## Core Value

Todo backup deve ser validado e restaurável — backup sem restore comprovado não existe.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Cadastro e gerenciamento de VPS via SSH (IP, porta, usuário, chave)
- [ ] Backup FULL de /home, /var/www, /etc, databases e volumes Docker
- [ ] Backup incremental com BorgBackup/rsync
- [ ] Validação de integridade SHA256 pós-upload (download automático de verificação)
- [ ] Teste de descompressão automático após cada backup
- [ ] Restore sandbox — restaurar em ambiente temporário e validar arquivos críticos
- [ ] Scheduler automático com horários configuráveis
- [ ] Upload para storage S3-compatible (Wasabi, Backblaze, MinIO, AWS)
- [ ] Notificações via Telegram, Discord e Email
- [ ] Dashboard com status das VPS, último/próximo backup, espaço, integridade
- [ ] Política de retentiva configurável (diário, semanal, mensal)
- [ ] Recuperação automática com até 3 tentativas em caso de falha
- [ ] Criptografia AES-256 dos backups
- [ ] Autenticação JWT + Refresh Token
- [ ] Admin panel para gerenciamento centralizado

### Out of Scope

- Suporte a Windows — foco Linux VPS inicialmente
- Backup Proxmox/Kubernetes — fase futura
- Snapshots LVM — complexidade desnecessária no MVP
- WhatsApp notifications — dependência externa instável
- Restore em 1 clique com IA — fase enterprise

## Context

- Sistema inspirado em necessidade real: o usuário sofreu perda de dados em VPS (evento registrado em sessão anterior)
- Stack definida no planomestre.md: Flutter Web + FastAPI + Celery/Redis + PostgreSQL + BorgBackup
- Agente de backup leve instalado nas VPS via SSH
- Workers assíncronos para não bloquear o painel durante operações longas
- Regra 3-2-1 de armazenamento: 3 cópias, 2 mídias, 1 offsite

## Constraints

- **Stack**: Flutter Web (frontend), Python FastAPI (backend), Celery+Redis (workers), PostgreSQL (banco), BorgBackup+rsync (engine) — já definido pelo usuário
- **Storage**: S3-compatible (Wasabi/Backblaze/MinIO) — sem lock-in de vendor
- **SSH**: Autenticação APENAS por chave SSH — nunca salvar senha
- **Containers**: Docker/docker-compose para todos os serviços
- **Segurança**: AES-256 obrigatório, SHA256 obrigatório, JWT para API

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| BorgBackup como engine principal | Deduplicação nativa, validação `borg check`, compressão, snapshots | — Pending |
| Validação obrigatória pós-backup | Backup sem validação não é considerado concluído | — Pending |
| Agente instalado na VPS | Evita gargalo de transferência via API central | — Pending |
| Celery + Redis para workers | Backups assíncronos, sem bloquear UI | — Pending |
| Flutter Web para frontend | Consistência com outros projetos do usuário | — Pending |

---
*Last updated: 2026-05-18 after initialization*
