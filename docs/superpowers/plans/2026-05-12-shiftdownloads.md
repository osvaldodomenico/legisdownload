# ShiftDownloads Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App de download de mídia (YouTube, Instagram, TikTok, Vimeo, Facebook) com interface Flutter (Web + Mobile iOS + Desktop) e backend Python FastAPI, formatos MP4 H.264 / MP3 / AAC compatíveis com CapCut e Premiere Pro.

**Architecture:** FastAPI com yt-dlp e BackgroundTasks para download assíncrono; estado de jobs em memória com limpeza automática a cada hora. Flutter único codebase compilado para Web (hospedado na VPS via Nginx), iOS e Desktop. Comunicação via REST API (HTTPS).

**Tech Stack:** Python 3.11, FastAPI, yt-dlp, uvicorn, APScheduler, aiofiles | Flutter 3.x, dio, shared_preferences, flutter_secure_storage, cached_network_image, google_fonts, share_plus, path_provider | Docker Compose, Nginx

---

## File Map

### Backend (`backend/`)
| Arquivo | Responsabilidade |
|---------|-----------------|
| `main.py` | FastAPI app, CORS, routers, lifespan (scheduler) |
| `models.py` | Pydantic schemas: InfoRequest, InfoResponse, DownloadRequest, JobStatus |
| `routers/info.py` | POST /info — metadata do vídeo via yt-dlp |
| `routers/download.py` | POST /download/start, GET /status/{id}, POST /job/{id}/cancel, GET /file/{id}, DELETE /job/{id} |
| `services/downloader.py` | Wrapper yt-dlp: extrair info, iniciar download, progress hook |
| `services/job_store.py` | Dict em memória: criar/ler/atualizar/deletar jobs + limpeza automática |
| `tests/test_info.py` | Testes POST /info |
| `tests/test_download.py` | Testes endpoints de download |
| `requirements.txt` | Dependências Python |
| `Dockerfile` | Imagem backend |

### Frontend (`frontend/shift_downloads/`)
| Arquivo | Responsabilidade |
|---------|-----------------|
| `lib/main.dart` | Entry point, MaterialApp com tema Mech Heavy |
| `lib/theme/mech_theme.dart` | Cores, tipografia, clip paths, botões — toda identidade visual |
| `lib/services/api_service.dart` | Chamadas HTTP à API: info, startDownload, pollStatus, downloadFile, cancel |
| `lib/services/history_service.dart` | CRUD de histórico local via SharedPreferences |
| `lib/services/file_save_service.dart` | Salvar arquivo: iOS (share_plus), Desktop (path_provider), Web (url_launcher) |
| `lib/screens/home_screen.dart` | Scaffold principal com TabBar de 5 plataformas |
| `lib/screens/download_screen.dart` | Tela de progresso + tela de conclusão (estados do mesmo job) |
| `lib/widgets/mech_button.dart` | Botão angular com gradiente amarelo Bumblebee |
| `lib/widgets/format_chip.dart` | Chip de formato com estilo angular selecionável |
| `lib/widgets/platform_tabs.dart` | TabBar estilizada com ícones de plataforma |
| `lib/widgets/url_input.dart` | Campo de URL com botão e validação básica |
| `lib/widgets/video_preview.dart` | Thumbnail + título + duração após /info |
| `lib/widgets/format_selector.dart` | Chips angulares de formato (MP4 4K, 1080p, 720p, MP3, AAC, sem marca d'água) |
| `lib/widgets/progress_bar.dart` | Barra de progresso gradiente + % + MB + botão abort |
| `lib/widgets/history_list.dart` | Lista dos últimos 20 downloads |
| `pubspec.yaml` | Dependências Flutter |

### Infra
| Arquivo | Responsabilidade |
|---------|-----------------|
| `docker-compose.yml` | Serviços: api + web + nginx |
| `nginx/nginx.conf` | Reverse proxy: `/api/` → backend:8000, `/` → Flutter Web |
| `frontend/Dockerfile` | Build Flutter Web + serve estático |
| `.gitignore` | node_modules, build, .superpowers, __pycache__, etc. |

---

## Chunk 1: Infraestrutura e Setup

### Task 1: Estrutura de pastas e .gitignore

**Files:**
- Create: `backend/` (dir)
- Create: `frontend/` (dir)
- Create: `nginx/` (dir)
- Create: `.gitignore`

- [ ] **Step 1: Criar estrutura de diretórios**

```bash
mkdir -p backend/routers backend/services backend/tests
mkdir -p nginx
```

- [ ] **Step 2: Criar .gitignore**

```
# Python
__pycache__/
*.pyc
.venv/
.env

# Flutter
frontend/shift_downloads/.dart_tool/
frontend/shift_downloads/build/
frontend/shift_downloads/.flutter-plugins
frontend/shift_downloads/.flutter-plugins-dependencies

# Docker
*.log

# Superpowers
.superpowers/

# Node (legado)
node_modules/
```

- [ ] **Step 3: Commit**

```bash
git init
git add .gitignore
git commit -m "chore: project structure and gitignore"
```

---

### Task 2: requirements.txt e Dockerfile do backend

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/Dockerfile`

- [ ] **Step 1: Criar requirements.txt**

```
fastapi==0.111.0
uvicorn[standard]==0.29.0
yt-dlp==2024.5.7
python-multipart==0.0.9
aiofiles==23.2.1
apscheduler==3.10.4
pytest==8.2.0
pytest-asyncio==0.23.6
httpx==0.27.0
```

- [ ] **Step 2: Criar Dockerfile do backend**

```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

> **Por que ffmpeg?** yt-dlp usa ffmpeg para mesclar streams de vídeo+áudio (necessário para 4K) e converter para MP3/AAC.

- [ ] **Step 3: Commit**

```bash
git add backend/requirements.txt backend/Dockerfile
git commit -m "chore: backend python dependencies and dockerfile"
```

---

### Task 3: Docker Compose + Nginx

**Files:**
- Create: `docker-compose.yml`
- Create: `nginx/nginx.conf`
- Create: `frontend/Dockerfile`

- [ ] **Step 1: Criar docker-compose.yml**

```yaml
version: "3.9"

services:
  api:
    build: ./backend
    restart: unless-stopped
    volumes:
      - /tmp/shiftdownloads:/tmp/shiftdownloads
    environment:
      - TMPDIR=/tmp/shiftdownloads

  web:
    build: ./frontend
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - api
      - web
```

- [ ] **Step 2: Criar nginx/nginx.conf**

```nginx
server {
    listen 80;

    location /api/ {
        proxy_pass http://api:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 600s;
        client_max_body_size 0;
    }

    location / {
        proxy_pass http://web:80/;
        proxy_set_header Host $host;
    }
}
```

> **proxy_read_timeout 600s:** downloads pesados podem demorar mais de 60s; sem isso o Nginx fecha a conexão durante o streaming do arquivo.

- [ ] **Step 3: Criar frontend/Dockerfile (placeholder — será completado no Chunk 3)**

```dockerfile
FROM nginx:alpine
COPY shift_downloads/build/web /usr/share/nginx/html
```

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml nginx/nginx.conf frontend/Dockerfile
git commit -m "chore: docker compose and nginx config"
```

---

## Chunk 2: Backend — Modelos, JobStore e Downloader

### Task 4: Pydantic models

**Files:**
- Create: `backend/models.py`

- [ ] **Step 1: Escrever test para validação dos modelos**

Criar `backend/tests/test_models.py`:

```python
import pytest
from models import InfoRequest, DownloadRequest, FormatInfo, JobStatus

def test_info_request_requires_url():
    with pytest.raises(Exception):
        InfoRequest()

def test_info_request_valid():
    req = InfoRequest(url="https://youtube.com/watch?v=abc")
    assert req.url == "https://youtube.com/watch?v=abc"

def test_download_request_defaults():
    req = DownloadRequest(url="https://youtube.com/watch?v=abc", format_id="mp4_1080")
    assert req.no_watermark is False

def test_job_status_progress_bounds():
    job = JobStatus(job_id="x", status="downloading", progress=67.4)
    assert 0 <= job.progress <= 100
```

- [ ] **Step 2: Rodar teste — deve falhar**

```bash
cd backend
python -m pytest tests/test_models.py -v
```
Expected: `ModuleNotFoundError: No module named 'models'`

- [ ] **Step 3: Criar backend/models.py**

```python
from pydantic import BaseModel
from typing import Optional, List


class InfoRequest(BaseModel):
    url: str


class FormatInfo(BaseModel):
    id: str
    label: str
    ext: str
    resolution: str


class InfoResponse(BaseModel):
    title: str
    thumbnail: Optional[str]
    duration: Optional[int]
    platform: str
    formats: List[FormatInfo]
    no_watermark: bool = False


class DownloadRequest(BaseModel):
    url: str
    format_id: str
    no_watermark: bool = False


class StartResponse(BaseModel):
    job_id: str
    status: str


class JobStatus(BaseModel):
    job_id: str
    status: str  # queued | downloading | processing | complete | error | cancelled
    progress: float = 0.0
    filename: Optional[str] = None
    filesize_mb: Optional[float] = None
    error: Optional[str] = None
```

- [ ] **Step 4: Rodar testes — devem passar**

```bash
python -m pytest tests/test_models.py -v
```
Expected: 4 passed

- [ ] **Step 5: Commit**

```bash
git add backend/models.py backend/tests/test_models.py
git commit -m "feat(backend): pydantic models for API contracts"
```

---

### Task 5: JobStore — estado em memória

**Files:**
- Create: `backend/services/job_store.py`
- Create: `backend/tests/test_job_store.py`

- [ ] **Step 1: Escrever testes**

```python
import pytest
from services.job_store import JobStore

def test_create_and_get_job():
    store = JobStore()
    job_id = store.create("https://youtube.com/watch?v=abc", "mp4_1080")
    job = store.get(job_id)
    assert job is not None
    assert job["status"] == "queued"
    assert job["progress"] == 0.0

def test_update_job_progress():
    store = JobStore()
    job_id = store.create("https://youtube.com/watch?v=abc", "mp4_1080")
    store.update(job_id, status="downloading", progress=45.0)
    job = store.get(job_id)
    assert job["status"] == "downloading"
    assert job["progress"] == 45.0

def test_get_nonexistent_returns_none():
    store = JobStore()
    assert store.get("nonexistent-id") is None

def test_delete_job():
    store = JobStore()
    job_id = store.create("https://youtube.com/watch?v=abc", "mp4_1080")
    store.delete(job_id)
    assert store.get(job_id) is None

def test_set_file_path():
    store = JobStore()
    job_id = store.create("https://youtube.com/watch?v=abc", "mp4_1080")
    store.update(job_id, status="complete", progress=100.0,
                 file_path="/tmp/shiftdownloads/abc/video.mp4",
                 filename="video.mp4", filesize_mb=67.4)
    job = store.get(job_id)
    assert job["file_path"] == "/tmp/shiftdownloads/abc/video.mp4"
    assert job["filesize_mb"] == 67.4
```

- [ ] **Step 2: Rodar — deve falhar**

```bash
python -m pytest tests/test_job_store.py -v
```
Expected: `ModuleNotFoundError`

- [ ] **Step 3: Criar backend/services/__init__.py e job_store.py**

```bash
touch backend/services/__init__.py backend/routers/__init__.py backend/tests/__init__.py
```

```python
# backend/services/job_store.py
import uuid
import time
from typing import Optional, Dict, Any


class JobStore:
    def __init__(self):
        self._jobs: Dict[str, Dict[str, Any]] = {}

    def create(self, url: str, format_id: str) -> str:
        job_id = str(uuid.uuid4())
        self._jobs[job_id] = {
            "job_id": job_id,
            "url": url,
            "format_id": format_id,
            "status": "queued",
            "progress": 0.0,
            "filename": None,
            "filesize_mb": None,
            "file_path": None,
            "error": None,
            "process": None,
            "created_at": time.time(),
        }
        return job_id

    def get(self, job_id: str) -> Optional[Dict[str, Any]]:
        return self._jobs.get(job_id)

    def update(self, job_id: str, **kwargs) -> None:
        if job_id in self._jobs:
            self._jobs[job_id].update(kwargs)

    def delete(self, job_id: str) -> None:
        self._jobs.pop(job_id, None)

    def cleanup_old_jobs(self, max_age_seconds: int = 3600) -> int:
        """Remove jobs older than max_age_seconds. Returns count removed."""
        now = time.time()
        to_delete = [
            jid for jid, job in self._jobs.items()
            if now - job["created_at"] > max_age_seconds
        ]
        for jid in to_delete:
            self.delete(jid)
        return len(to_delete)


# Singleton compartilhado entre routers
job_store = JobStore()
```

- [ ] **Step 4: Rodar testes — devem passar**

```bash
python -m pytest tests/test_job_store.py -v
```
Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add backend/services/ backend/routers/__init__.py backend/tests/__init__.py backend/tests/test_job_store.py
git commit -m "feat(backend): in-memory job store with cleanup"
```

---

### Task 6: Downloader service (yt-dlp wrapper)

**Files:**
- Create: `backend/services/downloader.py`

> Este serviço não tem testes unitários — yt-dlp faz chamadas reais à internet. Será testado via integração nos endpoints.

- [ ] **Step 1: Criar backend/services/downloader.py**

```python
import os
import re
import subprocess
import tempfile
from typing import Callable, Dict, Any, List
import yt_dlp

PLATFORMS = {
    "youtube.com": "youtube",
    "youtu.be": "youtube",
    "instagram.com": "instagram",
    "tiktok.com": "tiktok",
    "vimeo.com": "vimeo",
    "facebook.com": "facebook",
    "fb.watch": "facebook",
}

FORMAT_MAP = {
    "mp4_4k":   {"format": "bestvideo[height<=2160][ext=mp4]+bestaudio[ext=m4a]/best[height<=2160]", "ext": "mp4"},
    "mp4_1080": {"format": "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]", "ext": "mp4"},
    "mp4_720":  {"format": "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720]",  "ext": "mp4"},
    "mp3":      {"format": "bestaudio/best", "ext": "mp3",
                 "postprocessors": [{"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": "192"}]},
    "aac":      {"format": "bestaudio[ext=m4a]/bestaudio/best", "ext": "m4a"},
}


def detect_platform(url: str) -> str:
    for domain, platform in PLATFORMS.items():
        if domain in url:
            return platform
    return "unknown"


def get_info(url: str) -> Dict[str, Any]:
    ydl_opts = {"quiet": True, "no_warnings": True, "skip_download": True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)

    platform = detect_platform(url)
    formats = _build_format_list(info, platform)
    no_watermark = platform in ("tiktok", "instagram")

    return {
        "title": info.get("title", "Sem título"),
        "thumbnail": info.get("thumbnail"),
        "duration": info.get("duration"),
        "platform": platform,
        "formats": formats,
        "no_watermark": no_watermark,
    }


def _build_format_list(info: Dict, platform: str) -> List[Dict]:
    height = info.get("height") or 0
    available = []
    if platform not in ("instagram", "tiktok", "facebook"):
        if height >= 2160: available.append({"id": "mp4_4k",   "label": "MP4 4K",    "ext": "mp4", "resolution": "2160p"})
        if height >= 1080: available.append({"id": "mp4_1080", "label": "MP4 1080p", "ext": "mp4", "resolution": "1080p"})
    available.append({"id": "mp4_720",  "label": "MP4 720p",  "ext": "mp4", "resolution": "720p"})
    available.append({"id": "mp3",      "label": "MP3",        "ext": "mp3", "resolution": "audio"})
    available.append({"id": "aac",      "label": "AAC",        "ext": "m4a", "resolution": "audio"})
    return available


def start_download(job_id: str, url: str, format_id: str,
                   no_watermark: bool,
                   on_progress: Callable[[float, str, float], None]) -> str:
    """
    Inicia download síncrono (chamado dentro de BackgroundTask).
    Retorna path do arquivo gerado.
    on_progress(percent, filename, filesize_mb)
    """
    fmt = FORMAT_MAP.get(format_id, FORMAT_MAP["mp4_720"])
    out_dir = f"/tmp/shiftdownloads/{job_id}"
    os.makedirs(out_dir, exist_ok=True)

    def progress_hook(d):
        if d["status"] == "downloading":
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 1
            downloaded = d.get("downloaded_bytes", 0)
            pct = min(downloaded / total * 100, 99.0)
            fname = d.get("filename", "")
            size_mb = total / 1_000_000
            on_progress(pct, fname, size_mb)

    ydl_opts = {
        "format": fmt["format"],
        "outtmpl": f"{out_dir}/%(title)s.%(ext)s",
        "quiet": True,
        "no_warnings": True,
        "progress_hooks": [progress_hook],
        "merge_output_format": "mp4" if "mp4" in fmt["ext"] else None,
    }

    if format_id == "mp3":
        ydl_opts["postprocessors"] = fmt["postprocessors"]

    if no_watermark and "tiktok" in url:
        ydl_opts["format"] = "download_addr-2/bestvideo+bestaudio/best"

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    # Encontrar arquivo gerado
    files = os.listdir(out_dir)
    if not files:
        raise RuntimeError("yt-dlp não gerou nenhum arquivo")
    return os.path.join(out_dir, files[0])
```

- [ ] **Step 2: Verificar sintaxe**

```bash
cd backend
python -c "from services.downloader import get_info, start_download; print('OK')"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add backend/services/downloader.py
git commit -m "feat(backend): yt-dlp wrapper service for info and download"
```

---

## Chunk 3: Backend — Endpoints e App Principal

### Task 7: Router /info

**Files:**
- Create: `backend/routers/info.py`
- Create: `backend/tests/test_info.py`

- [ ] **Step 1: Criar backend/routers/info.py**

```python
from fastapi import APIRouter, HTTPException
from models import InfoRequest, InfoResponse, FormatInfo
from services.downloader import get_info

router = APIRouter()


@router.post("/info", response_model=InfoResponse)
async def info(req: InfoRequest):
    try:
        data = get_info(req.url)
        return InfoResponse(
            title=data["title"],
            thumbnail=data.get("thumbnail"),
            duration=data.get("duration"),
            platform=data["platform"],
            formats=[FormatInfo(**f) for f in data["formats"]],
            no_watermark=data["no_watermark"],
        )
    except Exception as e:
        raise HTTPException(status_code=422, detail=str(e))
```

- [ ] **Step 2: Criar backend/tests/test_info.py**

```python
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch
from main import app

client = TestClient(app)

MOCK_INFO = {
    "title": "Test Video",
    "thumbnail": "https://example.com/thumb.jpg",
    "duration": 120,
    "platform": "youtube",
    "formats": [
        {"id": "mp4_1080", "label": "MP4 1080p", "ext": "mp4", "resolution": "1080p"},
        {"id": "mp3", "label": "MP3", "ext": "mp3", "resolution": "audio"},
    ],
    "no_watermark": False,
}


def test_info_valid_url():
    with patch("routers.info.get_info", return_value=MOCK_INFO):
        response = client.post("/info", json={"url": "https://youtube.com/watch?v=abc"})
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Test Video"
    assert data["platform"] == "youtube"
    assert len(data["formats"]) == 2


def test_info_invalid_url_returns_422():
    with patch("routers.info.get_info", side_effect=Exception("Unsupported URL")):
        response = client.post("/info", json={"url": "https://invalid.example.com"})
    assert response.status_code == 422


def test_info_missing_url_returns_422():
    response = client.post("/info", json={})
    assert response.status_code == 422
```

- [ ] **Step 3: Rodar testes — vão falhar (main.py não existe)**

```bash
python -m pytest tests/test_info.py -v
```
Expected: `ModuleNotFoundError: No module named 'main'`

- [ ] **Step 4: Criar backend/main.py (mínimo para testes passarem)**

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from services.job_store import job_store
from routers import info, download


scheduler = AsyncIOScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler.add_job(job_store.cleanup_old_jobs, "interval", hours=1,
                      kwargs={"max_age_seconds": 3600})
    scheduler.start()
    yield
    scheduler.shutdown()


app = FastAPI(title="ShiftDownloads API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(info.router)
app.include_router(download.router)
```

- [ ] **Step 5: Criar backend/routers/download.py placeholder**

```python
from fastapi import APIRouter
router = APIRouter()
```

- [ ] **Step 6: Rodar testes info — devem passar**

```bash
python -m pytest tests/test_info.py -v
```
Expected: 3 passed

- [ ] **Step 7: Commit**

```bash
git add backend/routers/info.py backend/routers/download.py backend/main.py backend/tests/test_info.py
git commit -m "feat(backend): POST /info endpoint with tests"
```

---

### Task 8: Router /download — todos os endpoints

**Files:**
- Modify: `backend/routers/download.py`
- Create: `backend/tests/test_download.py`

- [ ] **Step 1: Criar backend/tests/test_download.py**

```python
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
from main import app
from services.job_store import job_store

client = TestClient(app)


def make_job(status="complete", progress=100.0, filename="video.mp4",
             file_path="/tmp/shiftdownloads/abc/video.mp4", filesize_mb=50.0):
    return {
        "job_id": "test-job-id",
        "url": "https://youtube.com/watch?v=abc",
        "format_id": "mp4_1080",
        "status": status,
        "progress": progress,
        "filename": filename,
        "filesize_mb": filesize_mb,
        "file_path": file_path,
        "error": None,
        "process": None,
        "created_at": 0,
    }


def test_start_download_returns_job_id():
    with patch("routers.download.start_download"):
        response = client.post("/download/start", json={
            "url": "https://youtube.com/watch?v=abc",
            "format_id": "mp4_1080"
        })
    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data
    assert data["status"] == "queued"


def test_status_returns_job():
    with patch.object(job_store, "get", return_value=make_job(status="downloading", progress=55.0)):
        response = client.get("/status/test-job-id")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "downloading"
    assert data["progress"] == 55.0


def test_status_unknown_job_returns_404():
    with patch.object(job_store, "get", return_value=None):
        response = client.get("/status/nonexistent")
    assert response.status_code == 404


def test_cancel_job():
    mock_job = make_job(status="downloading")
    mock_job["process"] = MagicMock()
    with patch.object(job_store, "get", return_value=mock_job):
        with patch.object(job_store, "update") as mock_update:
            response = client.post("/job/test-job-id/cancel")
    assert response.status_code == 200
    assert response.json()["status"] == "cancelled"


def test_delete_job():
    with patch.object(job_store, "get", return_value=make_job()):
        with patch.object(job_store, "delete") as mock_delete:
            response = client.delete("/job/test-job-id")
    assert response.status_code == 200
    mock_delete.assert_called_once_with("test-job-id")
```

- [ ] **Step 2: Rodar — deve falhar**

```bash
python -m pytest tests/test_download.py -v
```
Expected: falhas nos endpoints não implementados

- [ ] **Step 3: Implementar backend/routers/download.py**

```python
import os
import shutil
import aiofiles
from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from models import DownloadRequest, StartResponse, JobStatus
from services.job_store import job_store
from services.downloader import start_download as _start_download

router = APIRouter()


def _run_download(job_id: str, url: str, format_id: str, no_watermark: bool):
    def on_progress(pct: float, fname: str, size_mb: float):
        job_store.update(job_id,
                         status="downloading",
                         progress=pct,
                         filename=os.path.basename(fname),
                         filesize_mb=size_mb)
    try:
        file_path = _start_download(job_id, url, format_id, no_watermark, on_progress)
        size_mb = os.path.getsize(file_path) / 1_000_000
        job_store.update(job_id,
                         status="complete",
                         progress=100.0,
                         file_path=file_path,
                         filename=os.path.basename(file_path),
                         filesize_mb=round(size_mb, 2))
    except Exception as e:
        job_store.update(job_id, status="error", error=str(e))


@router.post("/download/start", response_model=StartResponse)
async def start(req: DownloadRequest, background_tasks: BackgroundTasks):
    job_id = job_store.create(req.url, req.format_id)
    background_tasks.add_task(_run_download, job_id, req.url, req.format_id, req.no_watermark)
    return StartResponse(job_id=job_id, status="queued")


@router.get("/status/{job_id}", response_model=JobStatus)
async def status(job_id: str):
    job = job_store.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job não encontrado")
    return JobStatus(
        job_id=job["job_id"],
        status=job["status"],
        progress=job["progress"],
        filename=job.get("filename"),
        filesize_mb=job.get("filesize_mb"),
        error=job.get("error"),
    )


@router.post("/job/{job_id}/cancel")
async def cancel(job_id: str):
    job = job_store.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job não encontrado")
    process = job.get("process")
    if process:
        try:
            process.terminate()
        except Exception:
            pass
    job_store.update(job_id, status="cancelled")
    out_dir = f"/tmp/shiftdownloads/{job_id}"
    if os.path.exists(out_dir):
        shutil.rmtree(out_dir, ignore_errors=True)
    return {"status": "cancelled"}


@router.get("/file/{job_id}")
async def download_file(job_id: str):
    job = job_store.get(job_id)
    if not job or job["status"] != "complete":
        raise HTTPException(status_code=404, detail="Arquivo não disponível")

    file_path = job["file_path"]
    filename = job["filename"]
    ext = filename.rsplit(".", 1)[-1].lower()

    content_types = {
        "mp4": "video/mp4",
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4",
        "webm": "video/webm",
    }
    content_type = content_types.get(ext, "application/octet-stream")

    async def file_stream():
        async with aiofiles.open(file_path, "rb") as f:
            while chunk := await f.read(1024 * 1024):
                yield chunk

    return StreamingResponse(
        file_stream(),
        media_type=content_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(os.path.getsize(file_path)),
        },
    )


@router.delete("/job/{job_id}")
async def delete_job(job_id: str):
    job = job_store.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job não encontrado")
    out_dir = f"/tmp/shiftdownloads/{job_id}"
    if os.path.exists(out_dir):
        shutil.rmtree(out_dir, ignore_errors=True)
    job_store.delete(job_id)
    return {"status": "deleted"}
```

- [ ] **Step 4: Rodar todos os testes backend**

```bash
python -m pytest tests/ -v
```
Expected: todos os testes passam (10+ testes)

- [ ] **Step 5: Commit**

```bash
git add backend/routers/download.py backend/tests/test_download.py
git commit -m "feat(backend): download endpoints (start, status, cancel, file, delete)"
```

---

## Chunk 4: Flutter — Setup, Tema e API Service

### Task 9: Inicializar projeto Flutter

**Files:**
- Create: `frontend/shift_downloads/` (Flutter project)

- [ ] **Step 1: Criar projeto Flutter**

```bash
cd frontend
flutter create shift_downloads --org com.shiftworks --platforms web,ios,macos,windows
```

- [ ] **Step 2: Atualizar pubspec.yaml**

```yaml
name: shift_downloads
description: Media downloader — YouTube, Instagram, TikTok, Vimeo, Facebook
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  dio: ^5.4.3
  shared_preferences: ^2.2.3
  flutter_secure_storage: ^9.0.0
  cached_network_image: ^3.3.1
  google_fonts: ^6.2.1
  share_plus: ^9.0.0
  path_provider: ^2.1.3
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.3

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Instalar dependências**

```bash
cd shift_downloads
flutter pub get
```
Expected: sem erros

- [ ] **Step 4: Rodar app vazio para verificar setup**

```bash
flutter run -d chrome
```
Expected: app Flutter padrão abre no browser

- [ ] **Step 5: Commit**

```bash
git add frontend/shift_downloads/pubspec.yaml frontend/shift_downloads/pubspec.lock
git commit -m "chore(flutter): project init and dependencies"
```

---

### Task 10: Tema Mech Heavy

**Files:**
- Create: `frontend/shift_downloads/lib/theme/mech_theme.dart` — cores, tipografia, ThemeData
- Create: `frontend/shift_downloads/lib/widgets/mech_button.dart` — botão angular reutilizável
- Create: `frontend/shift_downloads/lib/widgets/format_chip.dart` — chip de formato reutilizável

- [ ] **Step 1: Criar lib/theme/mech_theme.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechColors {
  static const background = Color(0xFF050810);
  static const surface = Color(0xFF0A1220);
  static const surfaceAlt = Color(0xFF080C14);
  static const border = Color(0xFF1A3A5C);
  static const borderAlt = Color(0xFF1E3A5F);
  static const accentYellow = Color(0xFFF5A623);
  static const accentYellowDim = Color(0x44F5A623);
  static const accentCyan = Color(0xFF00D4FF);
  static const accentCyanDim = Color(0x4400D4FF);
  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF3A6080);
  static const textMuted = Color(0xFF2A4A6A);
  static const error = Color(0xFFFF4444);
}

class MechTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MechColors.background,
        colorScheme: const ColorScheme.dark(
          primary: MechColors.accentYellow,
          secondary: MechColors.accentCyan,
          surface: MechColors.surface,
          error: MechColors.error,
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          const TextTheme(
            headlineSmall: TextStyle(
              color: MechColors.accentYellow,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
            bodyMedium: TextStyle(color: MechColors.textPrimary),
            bodySmall: TextStyle(color: MechColors.textSecondary, letterSpacing: 1.0),
            labelSmall: TextStyle(color: MechColors.textMuted, letterSpacing: 1.5),
          ),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: MechColors.accentCyan,
          unselectedLabelColor: MechColors.textMuted,
          indicator: BoxDecoration(
            border: Border(bottom: BorderSide(color: MechColors.accentCyan, width: 2)),
          ),
        ),
        dividerColor: MechColors.border,
      );
}

```

- [ ] **Step 2: Criar lib/widgets/mech_button.dart**

```dart
import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class MechButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const MechButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: CustomPaint(
        painter: _AngularBorderPainter(MechColors.accentYellow),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [MechColors.accentYellow, Color(0xFFE8850A)],
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          child: loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    fontSize: 13,
                  )),
        ),
      ),
    );
  }
}

class _AngularBorderPainter extends CustomPainter {
  final Color color;
  _AngularBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(6, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 6, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_) => false;
}
```

- [ ] **Step 3: Criar lib/widgets/format_chip.dart**

```dart
import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class FormatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FormatChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? MechColors.surface : Colors.transparent,
          border: Border.all(
            color: selected ? MechColors.accentYellow : MechColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? MechColors.accentYellow : MechColors.textMuted,
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verificar compilação**

```bash
flutter analyze lib/theme/ lib/widgets/mech_button.dart lib/widgets/format_chip.dart
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add frontend/shift_downloads/lib/theme/ frontend/shift_downloads/lib/widgets/mech_button.dart frontend/shift_downloads/lib/widgets/format_chip.dart
git commit -m "feat(flutter): mech heavy theme + MechButton + FormatChip as separate files"
```

---

### Task 11: ApiService

**Files:**
- Create: `frontend/shift_downloads/lib/services/api_service.dart`

- [ ] **Step 1: Criar lib/services/api_service.dart**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _baseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://localhost:8000');

class VideoInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String platform;
  final List<FormatOption> formats;
  final bool noWatermark;

  VideoInfo({required this.title, this.thumbnail, this.duration,
      required this.platform, required this.formats, required this.noWatermark});

  factory VideoInfo.fromJson(Map<String, dynamic> j) => VideoInfo(
        title: j['title'],
        thumbnail: j['thumbnail'],
        duration: j['duration'],
        platform: j['platform'],
        formats: (j['formats'] as List).map((f) => FormatOption.fromJson(f)).toList(),
        noWatermark: j['no_watermark'] ?? false,
      );
}

class FormatOption {
  final String id;
  final String label;
  final String ext;
  final String resolution;

  FormatOption({required this.id, required this.label,
      required this.ext, required this.resolution});

  factory FormatOption.fromJson(Map<String, dynamic> j) =>
      FormatOption(id: j['id'], label: j['label'], ext: j['ext'], resolution: j['resolution']);
}

class JobStatus {
  final String jobId;
  final String status;
  final double progress;
  final String? filename;
  final double? filesizeMb;
  final String? error;

  JobStatus({required this.jobId, required this.status,
      required this.progress, this.filename, this.filesizeMb, this.error});

  factory JobStatus.fromJson(Map<String, dynamic> j) => JobStatus(
        jobId: j['job_id'],
        status: j['status'],
        progress: (j['progress'] as num).toDouble(),
        filename: j['filename'],
        filesizeMb: j['filesize_mb'] != null ? (j['filesize_mb'] as num).toDouble() : null,
        error: j['error'],
      );
}

class ApiService {
  static Future<VideoInfo> getInfo(String url) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/info'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['detail'] ?? 'Erro ao buscar informações');
    }
    return VideoInfo.fromJson(jsonDecode(resp.body));
  }

  static Future<String> startDownload(String url, String formatId,
      {bool noWatermark = false}) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/download/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url, 'format_id': formatId, 'no_watermark': noWatermark}),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Falha ao iniciar download');
    return jsonDecode(resp.body)['job_id'] as String;
  }

  static Future<JobStatus> getStatus(String jobId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/status/$jobId'),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 404) throw Exception('job_not_found');
    if (resp.statusCode != 200) throw Exception('Erro ao verificar status');
    return JobStatus.fromJson(jsonDecode(resp.body));
  }

  static String fileUrl(String jobId) => '$_baseUrl/file/$jobId';

  static Future<void> cancelJob(String jobId) async {
    await http.post(Uri.parse('$_baseUrl/job/$jobId/cancel'))
        .timeout(const Duration(seconds: 10));
  }

  static Future<void> deleteJob(String jobId) async {
    await http.delete(Uri.parse('$_baseUrl/job/$jobId'))
        .timeout(const Duration(seconds: 10));
  }
}
```

- [ ] **Step 2: Verificar análise**

```bash
cd frontend/shift_downloads && flutter analyze lib/services/api_service.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Verificar que os modelos parseiam corretamente**

```bash
flutter test --plain-name "api_service"
```
> Se não houver testes ainda, verificar manualmente via `flutter run -d chrome` colando uma URL e confirmando que `/info` retorna resultado sem erros no console.

- [ ] **Step 4: Commit**

```bash
git add frontend/shift_downloads/lib/services/api_service.dart
git commit -m "feat(flutter): API service with typed models"
```

---

### Task 12: HistoryService e FileSaveService

**Files:**
- Create: `frontend/shift_downloads/lib/services/history_service.dart`
- Create: `frontend/shift_downloads/lib/services/file_save_service.dart`

- [ ] **Step 1: Criar lib/services/history_service.dart**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String platform;
  final String title;
  final String format;
  final DateTime downloadedAt;

  HistoryEntry({required this.platform, required this.title,
      required this.format, required this.downloadedAt});

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'title': title,
        'format': format,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        platform: j['platform'],
        title: j['title'],
        format: j['format'],
        downloadedAt: DateTime.parse(j['downloadedAt']),
      );
}

class HistoryService {
  static const _key = 'download_history';
  static const _maxEntries = 20;

  static Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => HistoryEntry.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> add(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > _maxEntries) raw.removeRange(_maxEntries, raw.length);
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

- [ ] **Step 2: Criar lib/services/file_save_service.dart**

```dart
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class FileSaveService {
  /// Salva o arquivo no dispositivo.
  /// - Web: abre URL de download diretamente no browser
  /// - iOS/macOS: baixa e abre share sheet nativo
  /// - Desktop: baixa e salva na pasta Downloads
  static Future<void> save(String fileUrl, String filename) async {
    if (kIsWeb) {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final response = await http.get(Uri.parse(fileUrl));
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar arquivo: ${response.statusCode}');
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'ShiftDownloads');
      return;
    }

    // Desktop (Windows, Linux, macOS não-share)
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
  }
}
```

- [ ] **Step 3: Verificar análise de todos os services**

```bash
cd frontend/shift_downloads && flutter analyze lib/services/
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add frontend/shift_downloads/lib/services/history_service.dart frontend/shift_downloads/lib/services/file_save_service.dart
git commit -m "feat(flutter): history service and platform-aware file save"
```

---

## Chunk 5: Flutter — Widgets e Telas

### Task 13: Widgets base

**Files:**
- Create: `lib/widgets/url_input.dart`
- Create: `lib/widgets/video_preview.dart`
- Create: `lib/widgets/format_selector.dart`
- Create: `lib/widgets/progress_bar.dart`
- Create: `lib/widgets/history_list.dart`
- Create: `lib/widgets/platform_tabs.dart`

- [ ] **Step 1: Criar lib/widgets/url_input.dart**

```dart
import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class UrlInput extends StatefulWidget {
  final String platformHint;
  final void Function(String url) onSubmit;
  final bool loading;

  const UrlInput({super.key, required this.platformHint,
      required this.onSubmit, this.loading = false});

  @override
  State<UrlInput> createState() => _UrlInputState();
}

class _UrlInputState extends State<UrlInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isNotEmpty) widget.onSubmit(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: MechColors.surface,
            border: const Border(left: BorderSide(color: MechColors.accentCyan, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(color: MechColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'URL://${widget.platformHint}',
                    hintStyle: const TextStyle(color: MechColors.textMuted, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (widget.loading)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MechColors.accentCyan)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MechButton(
          label: '⬇ EXECUTE DOWNLOAD',
          onPressed: widget.loading ? null : _submit,
          loading: widget.loading,
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Criar lib/widgets/video_preview.dart**

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/mech_theme.dart';

class VideoPreview extends StatelessWidget {
  final VideoInfo info;

  const VideoPreview({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MechColors.surface,
        border: Border.all(color: MechColors.border),
      ),
      child: Row(
        children: [
          if (info.thumbnail != null)
            CachedNetworkImage(
              imageUrl: info.thumbnail!,
              width: 80, height: 52,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(width: 80, height: 52, color: MechColors.surfaceAlt),
              errorWidget: (_, __, ___) => Container(width: 80, height: 52,
                  color: MechColors.surfaceAlt,
                  child: const Icon(Icons.play_circle_outline, color: MechColors.textMuted)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title,
                    style: const TextStyle(color: MechColors.textPrimary, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(info.platform.toUpperCase(),
                    style: const TextStyle(color: MechColors.accentCyan,
                        fontSize: 10, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Criar lib/widgets/format_selector.dart**

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/mech_theme.dart';

class FormatSelector extends StatelessWidget {
  final List<FormatOption> formats;
  final bool showNoWatermark;
  final String? selectedId;
  final bool noWatermark;
  final void Function(String id) onSelect;
  final void Function(bool value) onNoWatermarkToggle;

  const FormatSelector({super.key,
      required this.formats, required this.showNoWatermark,
      required this.selectedId, required this.noWatermark,
      required this.onSelect, required this.onNoWatermarkToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FORMATO:', style: TextStyle(color: MechColors.textMuted,
            fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: formats.map((f) => FormatChip(
            label: f.label,
            selected: selectedId == f.id,
            onTap: () => onSelect(f.id),
          )).toList(),
        ),
        if (showNoWatermark) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: noWatermark,
                onChanged: onNoWatermarkToggle,
                activeColor: MechColors.accentCyan,
              ),
              const Text('SEM MARCA D\'ÁGUA',
                  style: TextStyle(color: MechColors.textSecondary,
                      fontSize: 10, letterSpacing: 1.0)),
            ],
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Criar lib/widgets/progress_bar.dart**

```dart
import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class MechProgressBar extends StatelessWidget {
  final double progress; // 0..100
  final String? filename;
  final double? filesizeMb;
  final VoidCallback onAbort;

  const MechProgressBar({super.key,
      required this.progress, this.filename, this.filesizeMb,
      required this.onAbort});

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(filename ?? 'DOWNLOADING...',
                style: const TextStyle(color: MechColors.accentYellow,
                    fontSize: 10, letterSpacing: 1.0),
                overflow: TextOverflow.ellipsis),
            Text('${pct.toStringAsFixed(1)}%',
                style: const TextStyle(color: MechColors.accentYellow, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRect(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
                color: MechColors.surface,
                border: Border.all(color: MechColors.border)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct / 100,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MechColors.accentYellow, MechColors.accentCyan],
                  ),
                  boxShadow: [BoxShadow(color: MechColors.accentYellow, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
        if (filesizeMb != null) ...[
          const SizedBox(height: 4),
          Text('${(filesizeMb! * pct / 100).toStringAsFixed(1)} MB / ${filesizeMb!.toStringAsFixed(1)} MB',
              textAlign: TextAlign.right,
              style: const TextStyle(color: MechColors.textMuted, fontSize: 9)),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onAbort,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: MechColors.surface,
              border: Border.all(color: MechColors.border),
            ),
            child: const Text('✕ ABORT', textAlign: TextAlign.center,
                style: TextStyle(color: MechColors.textSecondary,
                    fontSize: 11, letterSpacing: 1.5)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Criar lib/widgets/history_list.dart**

```dart
import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../theme/mech_theme.dart';

class HistoryList extends StatelessWidget {
  final List<HistoryEntry> entries;

  const HistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: MechColors.border),
        const Text('RECENTES //',
            style: TextStyle(color: MechColors.textMuted,
                fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...entries.take(5).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(width: 4, height: 4,
                  decoration: const BoxDecoration(
                      color: MechColors.accentCyan, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(e.title,
                  style: const TextStyle(color: MechColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
              Text(e.format,
                  style: const TextStyle(color: MechColors.border, fontSize: 9)),
            ],
          ),
        )),
      ],
    );
  }
}
```

- [ ] **Step 6: Criar lib/widgets/platform_tabs.dart**

```dart
import 'package:flutter/material.dart';

const _platforms = [
  {'id': 'youtube',   'label': '▶ YT',  'hint': 'youtube.com/watch?v=...'},
  {'id': 'instagram', 'label': '◉ IG',  'hint': 'instagram.com/reel/...'},
  {'id': 'tiktok',    'label': '♪ TK',  'hint': 'tiktok.com/@user/video/...'},
  {'id': 'vimeo',     'label': '▣ VM',  'hint': 'vimeo.com/...'},
  {'id': 'facebook',  'label': 'f FB',  'hint': 'facebook.com/video/...'},
];

const platformTabs = [
  Tab(text: '▶ YT'),
  Tab(text: '◉ IG'),
  Tab(text: '♪ TK'),
  Tab(text: '▣ VM'),
  Tab(text: 'f FB'),
];

String platformHint(int index) => _platforms[index]['hint']!;
String platformId(int index) => _platforms[index]['id']!;
```

- [ ] **Step 7: Verificar análise**

```bash
flutter analyze lib/widgets/
```
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add frontend/shift_downloads/lib/widgets/
git commit -m "feat(flutter): base widgets (url_input, video_preview, format_selector, progress_bar, history_list, platform_tabs)"
```

---

### Task 14: HomeScreen e DownloadScreen

**Files:**
- Create: `lib/screens/home_screen.dart`
- Create: `lib/screens/download_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Criar lib/screens/download_screen.dart**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/file_save_service.dart';
import '../theme/mech_theme.dart';
import '../widgets/progress_bar.dart';

class DownloadScreen extends StatefulWidget {
  final String jobId;
  final String platform;
  final String title;
  final String formatLabel;

  const DownloadScreen({super.key,
      required this.jobId, required this.platform,
      required this.title, required this.formatLabel});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  JobStatus? _status;
  Timer? _timer;
  int _pollCount = 0;
  static const _maxPolls = 300; // 10 min a 2s
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _timer?.cancel();
      setState(() => _status = JobStatus(
          jobId: widget.jobId, status: 'error',
          progress: 0, error: 'Timeout — tente novamente'));
      return;
    }
    try {
      final status = await ApiService.getStatus(widget.jobId);
      setState(() => _status = status);
      if (status.status == 'complete' || status.status == 'error' ||
          status.status == 'cancelled') {
        _timer?.cancel();
      }
    } catch (e) {
      if (e.toString().contains('job_not_found')) {
        _timer?.cancel();
        setState(() => _status = JobStatus(
            jobId: widget.jobId, status: 'error',
            progress: 0, error: 'Job não encontrado (servidor reiniciado?)'));
      }
    }
  }

  Future<void> _abort() async {
    _timer?.cancel();
    await ApiService.cancelJob(widget.jobId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saveError = null; });
    try {
      final url = ApiService.fileUrl(widget.jobId);
      await FileSaveService.save(url, _status!.filename!);
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      backgroundColor: MechColors.background,
      appBar: AppBar(
        backgroundColor: MechColors.background,
        title: Text(widget.title,
            style: const TextStyle(color: MechColors.accentYellow,
                fontSize: 13, letterSpacing: 1.0),
            overflow: TextOverflow.ellipsis),
        iconTheme: const IconThemeData(color: MechColors.accentCyan),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: status == null
            ? const Center(child: CircularProgressIndicator(color: MechColors.accentCyan))
            : _buildBody(status),
      ),
    );
  }

  Widget _buildBody(JobStatus status) {
    if (status.status == 'complete') return _buildComplete(status);
    if (status.status == 'error') return _buildError(status.error ?? 'Erro desconhecido');
    if (status.status == 'cancelled') return _buildError('Download cancelado');
    return MechProgressBar(
      progress: status.progress,
      filename: status.filename,
      filesizeMb: status.filesizeMb,
      onAbort: _abort,
    );
  }

  Widget _buildComplete(JobStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: MechColors.surface,
              border: Border.all(color: MechColors.accentCyanDim)),
          child: Column(children: [
            const Text('✓ COMPLETE',
                style: TextStyle(color: MechColors.accentCyan,
                    fontSize: 12, letterSpacing: 2.0)),
            const SizedBox(height: 8),
            Text(status.filename ?? '',
                style: const TextStyle(color: MechColors.textPrimary, fontSize: 12),
                textAlign: TextAlign.center),
            if (status.filesizeMb != null)
              Text('${status.filesizeMb!.toStringAsFixed(1)} MB',
                  style: const TextStyle(color: MechColors.textMuted, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 16),
        MechButton(
          label: _saving ? '...' : '⬇ SALVAR NO DISPOSITIVO',
          onPressed: _saving ? null : _save,
          loading: _saving,
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(_saveError!,
              style: const TextStyle(color: MechColors.error, fontSize: 11)),
        ],
      ],
    );
  }

  Widget _buildError(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('✕ ERRO', style: TextStyle(color: MechColors.error,
            fontSize: 14, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: MechColors.textSecondary,
            fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        MechButton(label: '← VOLTAR', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
```

- [ ] **Step 2: Criar lib/screens/home_screen.dart**

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../theme/mech_theme.dart';
import '../widgets/url_input.dart';
import '../widgets/video_preview.dart';
import '../widgets/format_selector.dart';
import '../widgets/history_list.dart';
import '../widgets/platform_tabs.dart';
import 'download_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  VideoInfo? _info;
  bool _loadingInfo = false;
  String? _infoError;
  String? _selectedFormat;
  bool _noWatermark = false;
  bool _startingDownload = false;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadHistory();
  }

  void _onTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() { _info = null; _infoError = null; _selectedFormat = null; });
    }
  }

  Future<void> _loadHistory() async {
    final h = await HistoryService.load();
    setState(() => _history = h);
  }

  Future<void> _fetchInfo(String url) async {
    setState(() { _loadingInfo = true; _infoError = null; _info = null; _selectedFormat = null; });
    try {
      final info = await ApiService.getInfo(url);
      setState(() {
        _info = info;
        _selectedFormat = info.formats.isNotEmpty ? info.formats.first.id : null;
      });
    } catch (e) {
      setState(() => _infoError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loadingInfo = false);
    }
  }

  Future<void> _startDownload() async {
    final info = _info;
    final format = _selectedFormat;
    if (info == null || format == null) return;
    setState(() => _startingDownload = true);
    try {
      final jobId = await ApiService.startDownload(info.title, format,
          noWatermark: _noWatermark);
      final formatLabel = info.formats
          .firstWhere((f) => f.id == format, orElse: () => info.formats.first)
          .label;
      await HistoryService.add(HistoryEntry(
          platform: info.platform, title: info.title,
          format: formatLabel, downloadedAt: DateTime.now()));
      await _loadHistory();
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => DownloadScreen(
            jobId: jobId, platform: info.platform,
            title: info.title, formatLabel: formatLabel),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: MechColors.error));
    } finally {
      setState(() => _startingDownload = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: MechColors.background,
      appBar: AppBar(
        backgroundColor: MechColors.background,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHiFT//DOWNLOADS',
                style: TextStyle(color: MechColors.accentYellow,
                    fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
            Text('MEDIA EXTRACTION SYSTEM',
                style: TextStyle(color: MechColors.textMuted,
                    fontSize: 9, letterSpacing: 2.0)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '▶ YT'), Tab(text: '◉ IG'),
            Tab(text: '♪ TK'), Tab(text: '▣ VM'), Tab(text: 'f FB'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(5, (i) => _buildTab(i, isWide)),
      ),
    );
  }

  Widget _buildTab(int tabIndex, bool isWide) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UrlInput(
          platformHint: platformHint(tabIndex),
          onSubmit: _fetchInfo,
          loading: _loadingInfo,
        ),
        if (_infoError != null) ...[
          const SizedBox(height: 8),
          Text(_infoError!,
              style: const TextStyle(color: MechColors.error, fontSize: 11)),
        ],
        if (_info != null) ...[
          const SizedBox(height: 12),
          VideoPreview(info: _info!),
          const SizedBox(height: 12),
          FormatSelector(
            formats: _info!.formats,
            showNoWatermark: _info!.noWatermark,
            selectedId: _selectedFormat,
            noWatermark: _noWatermark,
            onSelect: (id) => setState(() => _selectedFormat = id),
            onNoWatermarkToggle: (v) => setState(() => _noWatermark = v),
          ),
          const SizedBox(height: 12),
          MechButton(
            label: '⬇ DOWNLOAD',
            onPressed: _startingDownload ? null : _startDownload,
            loading: _startingDownload,
          ),
        ],
        const SizedBox(height: 20),
        HistoryList(entries: _history),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: SingleChildScrollView(
              padding: const EdgeInsets.all(20), child: content)),
          Container(width: 1, color: MechColors.border),
          Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: HistoryList(entries: _history))),
        ],
      );
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: content);
  }
}
```

- [ ] **Step 3: Substituir lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'theme/mech_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ShiftDownloadsApp());
}

class ShiftDownloadsApp extends StatelessWidget {
  const ShiftDownloadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiftDownloads',
      theme: MechTheme.theme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 4: Analisar projeto completo**

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 5: Build Flutter Web para verificar**

```bash
flutter build web --dart-define=API_BASE_URL=/api
```
Expected: build completo sem erros em `build/web/`

- [ ] **Step 6: Commit**

```bash
git add frontend/shift_downloads/lib/
git commit -m "feat(flutter): home screen, download screen, main app"
```

---

## Chunk 6: Deploy na VPS

### Task 15: Build e deploy com Docker Compose

**Files:**
- Modify: `frontend/Dockerfile` (build completo)

- [ ] **Step 1: Atualizar frontend/Dockerfile com build multi-stage**

```dockerfile
# Stage 1 — build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY shift_downloads/pubspec.yaml shift_downloads/pubspec.lock ./shift_downloads/
RUN cd shift_downloads && flutter pub get

COPY shift_downloads/ ./shift_downloads/
RUN cd shift_downloads && flutter build web --dart-define=API_BASE_URL=/api --release

# Stage 2 — serve com Nginx
FROM nginx:alpine
COPY --from=builder /app/shift_downloads/build/web /usr/share/nginx/html
COPY nginx-web.conf /etc/nginx/conf.d/default.conf
```

- [ ] **Step 2: Criar frontend/nginx-web.conf (servidor do Flutter Web)**

Criar `frontend/nginx-web.conf` — mesmo diretório que o `frontend/Dockerfile`, pois o build context do Docker Compose é `./frontend`:

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

> `try_files` necessário para Flutter Web com rotas do lado cliente.
> O `COPY nginx-web.conf ...` no Dockerfile usa path relativo ao build context `./frontend` — o arquivo deve estar em `frontend/nginx-web.conf`.

- [ ] **Step 3: Verificar que o COPY path bate com o build context**

```bash
# Confirmar que o arquivo existe onde o Dockerfile espera
ls frontend/nginx-web.conf
# Expected: frontend/nginx-web.conf
```

- [ ] **Step 4: Commit**

```bash
git add frontend/Dockerfile frontend/nginx-web.conf
git commit -m "chore: multi-stage dockerfile for flutter web build"
```

---

### Task 16: Deploy na VPS

- [ ] **Step 1: Enviar código para a VPS**

```bash
# Na máquina local — substitua USER e IP pelos dados da sua VPS
rsync -avz --exclude '.git' --exclude '.superpowers' \
  "/Users/domenico/Documents/Documentos - MacBook Air de Osvaldo/Projetos/sistemas/ShiftDownloads/" \
  USER@IP:/opt/shiftdownloads/
```

- [ ] **Step 2: Criar pasta de tmp na VPS**

```bash
ssh USER@IP "mkdir -p /tmp/shiftdownloads && chmod 777 /tmp/shiftdownloads"
```

- [ ] **Step 3: Build e subir serviços**

```bash
ssh USER@IP "cd /opt/shiftdownloads && docker compose up -d --build"
```

- [ ] **Step 4: Verificar serviços rodando**

```bash
ssh USER@IP "docker compose ps"
```
Expected: `api`, `web`, `nginx` com status `Up`

- [ ] **Step 5: Testar API health**

```bash
curl http://SEU_DOMINIO/api/info -X POST \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```
Expected: JSON com título, thumbnail e lista de formatos

- [ ] **Step 6: Testar app no browser**

Abrir `http://SEU_DOMINIO` no browser. Verificar:
- Tabs das 5 plataformas aparecem
- Colar URL do YouTube, clicar Execute Download
- Preview do vídeo aparece com formatos disponíveis
- Iniciar download, barra de progresso aparece
- Download completo, botão "Salvar no Dispositivo" funciona

- [ ] **Step 7: Configurar HTTPS com Certbot (standalone, via volume Docker)**

> O Nginx roda em container, então `certbot --nginx` do host não funciona. Usar modo `standalone` do certbot temporariamente para emitir o certificado, depois montar o volume no container Nginx.

```bash
# Na VPS — parar Nginx temporariamente para liberar porta 80
ssh USER@IP "cd /opt/shiftdownloads && docker compose stop nginx"

# Gerar certificado com certbot standalone (host)
ssh USER@IP "apt-get install -y certbot && certbot certonly --standalone -d SEU_DOMINIO --non-interactive --agree-tos -m SEU_EMAIL"

# Subir Nginx novamente
ssh USER@IP "cd /opt/shiftdownloads && docker compose start nginx"
```

Atualizar `nginx/nginx.conf` para suportar HTTPS (adicionar bloco server 443):

```nginx
server {
    listen 80;
    server_name SEU_DOMINIO;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name SEU_DOMINIO;

    ssl_certificate /etc/letsencrypt/live/SEU_DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/SEU_DOMINIO/privkey.pem;

    location /api/ {
        proxy_pass http://api:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 600s;
        client_max_body_size 0;
    }

    location / {
        proxy_pass http://web:80/;
        proxy_set_header Host $host;
    }
}
```

Atualizar `docker-compose.yml` — montar certs no container Nginx e expor porta 443:

```yaml
  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - api
      - web
```

```bash
ssh USER@IP "cd /opt/shiftdownloads && docker compose up -d nginx"
```

- [ ] **Step 8: Verificar HTTPS**

```bash
curl https://SEU_DOMINIO/api/info -X POST \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```
Expected: JSON com título e formatos via HTTPS (sem erro de certificado)

- [ ] **Step 9: Configurar renovação automática do certificado (expira em 90 dias)**

```bash
ssh USER@IP "echo '0 3 * * * certbot renew --quiet && cd /opt/shiftdownloads && docker compose restart nginx' | crontab -"
```

- [ ] **Step 10: Commit final**

```bash
git add nginx/nginx.conf docker-compose.yml
git commit -m "feat: shiftdownloads MVP — FastAPI + Flutter Web deploy with HTTPS"
```

---

## Compilar app iOS (separado)

> Executar em Mac com Xcode instalado após deploy do backend na VPS.

- [ ] **Step 1: Configurar URL da API no build iOS**

```bash
cd frontend/shift_downloads
flutter build ios --dart-define=API_BASE_URL=https://SEU_DOMINIO/api --release
```

- [ ] **Step 2: Abrir no Xcode e distribuir via TestFlight ou cabo**

```bash
open ios/Runner.xcworkspace
```
Xcode → Product → Archive → Distribute

---

## Resumo de Testes a Rodar

| Momento | Comando |
|---------|---------|
| Após Task 4 | `cd backend && python -m pytest tests/test_models.py -v` |
| Após Task 5 | `cd backend && python -m pytest tests/test_job_store.py -v` |
| Após Task 7 | `cd backend && python -m pytest tests/test_info.py -v` |
| Após Task 8 | `cd backend && python -m pytest tests/ -v` |
| Após Task 10-13 | `cd frontend/shift_downloads && flutter analyze` |
| Após Task 14 | `flutter build web --dart-define=API_BASE_URL=/api` |
| Após Task 16 | `curl http://SEU_DOMINIO/api/info -X POST ...` |
