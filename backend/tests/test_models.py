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
