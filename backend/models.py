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
    duration: Optional[float]
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
