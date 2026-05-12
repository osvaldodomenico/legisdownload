# ShiftDownloads — Design Spec
**Data:** 2026-05-12  
**Status:** Aprovado

---

## Visão Geral

App de download de mídia para video makers. Permite baixar vídeos e extrair áudio de YouTube, Instagram, TikTok, Vimeo e Facebook em formatos compatíveis com CapCut e Premiere Pro (iPhone/iOS). Interface com identidade visual Mech Heavy (Dark Neon estilo Transformers).

---

## Plataformas Alvo

### App (Flutter — único codebase)
| Target | Distribuição | Uso |
|--------|-------------|-----|
| Flutter Web | VPS (URL pública) | Acesso pelo browser, qualquer dispositivo |
| Flutter Mobile (iOS) | Compilado, sideload ou TestFlight | Uso na rua, iPhone |
| Flutter Desktop (macOS/Win) | Compilado | Uso no computador |

### Fontes de download suportadas
- YouTube (vídeos, Shorts)
- Instagram (Reels, Stories, posts, carrossel)
- TikTok (vídeos sem marca d'água)
- Vimeo (vídeos públicos)
- Facebook (vídeos públicos, Reels)

---

## Arquitetura

```
┌─────────────────────────────────────────────┐
│              VPS (Docker Compose)           │
│                                             │
│  ┌──────────────────┐  ┌─────────────────┐  │
│  │  Flutter Web     │  │  Python FastAPI  │  │
│  │  (porta 80/443)  │◄─►  (porta 8000)   │  │
│  │  Nginx reverse   │  │                 │  │
│  │  proxy           │  │  yt-dlp         │  │
│  └──────────────────┘  │  BackgroundTasks│  │
│                        │  /tmp/jobs/     │  │
│  Flutter Mobile (iOS)  └─────────────────┘  │
│  Flutter Desktop    ◄── REST API (HTTPS)     │
│  (apps compilados)                          │
└─────────────────────────────────────────────┘
```

### Componentes
- **FastAPI** — servidor async, endpoints REST
- **yt-dlp** — extração de mídia (suporta todas as 5 plataformas nativamente)
- **FastAPI BackgroundTasks** — jobs de download assíncronos sem Redis/Celery
- **job_store.py** — dicionário em memória com estado dos jobs; em caso de restart do servidor, jobs pendentes são perdidos e o cliente recebe `404` no polling, exibindo mensagem de erro ao usuário
- **Nginx** — reverse proxy + serve Flutter Web estático
- **Docker Compose** — orquestração dos serviços na VPS

---

## Backend — API Endpoints

### `POST /info`
Recebe URL, retorna metadata sem iniciar download.

**Request:**
```json
{ "url": "https://youtube.com/watch?v=..." }
```

**Response:**
```json
{
  "title": "Nome do vídeo",
  "thumbnail": "https://...",
  "duration": 180,
  "platform": "youtube",
  "formats": [
    { "id": "mp4_4k", "label": "MP4 4K", "ext": "mp4", "resolution": "2160p" },
    { "id": "mp4_1080", "label": "MP4 1080p", "ext": "mp4", "resolution": "1080p" },
    { "id": "mp4_720", "label": "MP4 720p", "ext": "mp4", "resolution": "720p" },
    { "id": "mp3", "label": "MP3", "ext": "mp3", "resolution": "audio" },
    { "id": "aac", "label": "AAC", "ext": "m4a", "resolution": "audio" }
  ]
}
```

### `POST /download/start`
Inicia download em background, retorna job_id imediatamente.

**Request:**
```json
{ "url": "https://...", "format_id": "mp4_4k" }
```

**Response:**
```json
{ "job_id": "uuid-aqui", "status": "queued" }
```

### `GET /status/{job_id}`
Polling de progresso. Frontend chama a cada 2 segundos.

**Response:**
```json
{
  "job_id": "uuid",
  "status": "downloading | processing | complete | error",
  "progress": 67.4,
  "filename": "video_title.mp4",
  "filesize_mb": 67.4,
  "error": null
}
```

### `GET /file/{job_id}`
Serve o arquivo para download (streaming). Disparado quando `status == complete`.

**Response headers:**
```
Content-Disposition: attachment; filename="titulo_do_video.mp4"
Content-Type: video/mp4  (ou audio/mpeg para MP3, audio/mp4 para AAC)
Content-Length: <bytes>
```

Flutter usa `dio` para baixar o arquivo com progresso. Após download:
- **iOS:** `share_plus` abre o share sheet nativo → usuário salva em Fotos ou Arquivos
- **Desktop:** `path_provider` + `file_picker` → salva em pasta escolhida pelo usuário
- **Web:** trigger de download padrão do browser via URL direta

### `POST /job/{job_id}/cancel`
Cancela download em andamento (mata o processo yt-dlp via `process.terminate()`) e remove arquivos temporários.

**Response:** `{ "status": "cancelled" }`

### `DELETE /job/{job_id}`
Limpeza manual de job completo. Também roda automaticamente após 1 hora via scheduler.

---

## Formatos de Saída

| Formato | Codec | Compatibilidade |
|---------|-------|-----------------|
| MP4 4K | H.264 | CapCut, Premiere, iPhone |
| MP4 1080p | H.264 | CapCut, Premiere, iPhone |
| MP4 720p | H.264 | CapCut, Premiere, iPhone |
| MP3 | MP3 | CapCut, Premiere |
| AAC | AAC/M4A | CapCut, Premiere, iPhone nativo |

Formatos específicos por plataforma:
- **TikTok/Instagram:** `POST /info` retorna `"no_watermark": true` quando disponível; `POST /download/start` aceita campo opcional `"no_watermark": true` para ativar — formato resultante continua sendo MP4 H.264

---

## Frontend Flutter

### Estrutura de Navegação
Tabs superiores por plataforma (5 abas fixas):
`YOUTUBE | INSTAGRAM | TIKTOK | VIMEO | FACEBOOK`

### Telas
1. **Tab principal** — URL input + preview + seletor de formato + botão download
2. **Download em progresso** — thumbnail + barra de progresso + % + MB/total + botão abort
3. **Download completo** — botão "Salvar nos Arquivos" (iOS) / "Salvar pasta" (desktop) + compartilhar

### Layout Responsivo
- **Mobile:** coluna única, tabs no topo, scroll vertical
- **Web/Desktop:** split — input/formatos à esquerda, preview/histórico à direita

### Identidade Visual — Mech Heavy
| Elemento | Valor |
|---------|-------|
| Fundo | `#050810` |
| Grid decorativo | `#0a1a2e` linhas |
| Accent primário | `#f5a623` (Bumblebee yellow) |
| Accent secundário | `#00d4ff` (ciano elétrico) |
| Bordas | `#1a3a5c` |
| Input border-left | `3px solid #00d4ff` |
| Botão principal | gradiente `#f5a623 → #e8850a` |
| Shapes | `clip-path` angulares (estilo cortado) |
| Tipografia | Monospace (`Courier New` / `JetBrains Mono`) |

> **Nota:** visual aprovado com observação de legibilidade pesada — refinar contraste e espaçamento em iteração futura.

### Fluxo de Uso
```
Cole URL → [POST /info] → Exibe preview + formatos disponíveis
→ Seleciona formato → [POST /download/start] → recebe job_id
→ Polling [GET /status/{job_id}] a cada 2s → barra de progresso (timeout: 10 min → exibe erro)
→ status == complete → [GET /file/{job_id}] → salva no dispositivo
```

### Histórico
- Armazenado localmente (SharedPreferences / flutter_secure_storage)
- Lista dos últimos 20 downloads: plataforma, título, formato, data
- Sem sincronização entre dispositivos (MVP)

---

## Autenticação

**MVP:** sem autenticação. API aberta.  
**Futuro:** JWT middleware no FastAPI já previsto. Flutter com tela de login/register. Histórico sincronizado por conta.

---

## Deployment — VPS

### Docker Compose
```yaml
services:
  api:       # FastAPI + yt-dlp, porta 8000
  web:       # Flutter Web build estático servido pelo Nginx
  nginx:     # Reverse proxy, SSL termination (porta 80/443)
```

### Requisitos mínimos da VPS
- 2 vCPU, 2GB RAM (downloads de vídeo são CPU-intensivos)
- 20GB disco (temp files, limpeza automática a cada hora)

---

## Estrutura de Pastas

```
ShiftDownloads/
├── backend/
│   ├── main.py              # FastAPI app
│   ├── routers/
│   │   ├── info.py          # POST /info
│   │   └── download.py      # POST /download/start, GET /status, GET /file, DELETE
│   ├── services/
│   │   ├── downloader.py    # yt-dlp wrapper
│   │   └── job_store.py     # in-memory job state (dict + cleanup scheduler)
│   ├── models.py            # Pydantic schemas
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   └── shift_downloads/     # Flutter project
│       ├── lib/
│       │   ├── main.dart
│       │   ├── screens/
│       │   │   ├── home_screen.dart
│       │   │   └── download_screen.dart
│       │   ├── widgets/
│       │   │   ├── platform_tabs.dart
│       │   │   ├── url_input.dart
│       │   │   ├── format_selector.dart
│       │   │   ├── video_preview.dart
│       │   │   └── progress_bar.dart
│       │   ├── services/
│       │   │   └── api_service.dart
│       │   └── theme/
│       │       └── mech_theme.dart
│       └── pubspec.yaml
├── nginx/
│   └── nginx.conf
├── docker-compose.yml
└── docs/
    └── superpowers/specs/
        └── 2026-05-12-shiftdownloads-design.md
```

---

## Dependências Principais

### Backend (Python)
```
fastapi
uvicorn[standard]
yt-dlp
python-multipart
aiofiles
apscheduler        # limpeza automática dos jobs
```

### Frontend (Flutter)
```
http                    # chamadas à API
dio                     # download de arquivo com progresso
shared_preferences      # histórico local
flutter_secure_storage  # token JWT (futuro — incluído no MVP build intencionalmente)
cached_network_image    # thumbnails
google_fonts            # JetBrains Mono
```

---

## Fora do Escopo (MVP)

- Login/autenticação (planejado para v2)
- Histórico sincronizado entre dispositivos
- Fila de múltiplos downloads simultâneos
- Playlists completas do YouTube
- Download de áudio de playlists em lote
- Download em lote de Stories/Carrossel do Instagram (zip)
- Refinamento de contraste e legibilidade do tema Mech Heavy (iteração futura de UI)
- App nas lojas (App Store / Google Play)
