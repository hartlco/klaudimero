from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI

from .scheduler import get_scheduler, load_and_schedule_all_jobs
from .routers import jobs, executions, devices

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = get_scheduler()
    load_and_schedule_all_jobs()
    scheduler.start()
    logging.getLogger("klaudimero").info("Scheduler started")
    yield
    scheduler.shutdown()
    logging.getLogger("klaudimero").info("Scheduler shut down")


app = FastAPI(title="Klaudimero", version="0.1.0", lifespan=lifespan)

app.include_router(jobs.router)
app.include_router(executions.router)
app.include_router(devices.router)


@app.get("/")
async def root():
    return {"service": "klaudimero", "status": "running"}
