import os
import urllib.parse
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
            "Content-Disposition": f"attachment; filename*=UTF-8''{urllib.parse.quote(filename)}",
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
