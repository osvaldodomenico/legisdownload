from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from services.job_store import job_store
from routers import info, download, admin


scheduler = AsyncIOScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler.add_job(job_store.cleanup_old_jobs, "interval", hours=1,
                      kwargs={"max_age_seconds": 3600})
    scheduler.start()
    yield
    scheduler.shutdown()


app = FastAPI(
    title="ShiftDownloads API",
    lifespan=lifespan,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
    redoc_url="/api/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(info.router, prefix="/api")
app.include_router(download.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
