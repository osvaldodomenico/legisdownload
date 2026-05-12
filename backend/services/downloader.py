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
