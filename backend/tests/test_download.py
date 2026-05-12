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
    with patch("routers.download._start_download"):
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
