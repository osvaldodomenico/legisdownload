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
