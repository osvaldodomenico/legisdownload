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
