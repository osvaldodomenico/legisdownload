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
