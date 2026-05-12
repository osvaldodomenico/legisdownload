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
