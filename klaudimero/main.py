from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI

from .scheduler import get_scheduler, load_and_schedule_all_jobs
from .routers import jobs, executions, devices, heartbeat, chat, soul

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    from .heartbeat import ensure_heartbeat_prompt, schedule_heartbeat
    from .soul import ensure_soul_prompt
    from .storage import load_heartbeat_config

    scheduler = get_scheduler()
    load_and_schedule_all_jobs()

    # Soul + Heartbeat setup
    ensure_soul_prompt()
    ensure_heartbeat_prompt()
    hb_config = load_heartbeat_config()
    if hb_config.enabled:
        schedule_heartbeat(hb_config)

    scheduler.start()
    logging.getLogger("klaudimero").info("Scheduler started")
    yield
    scheduler.shutdown()
    logging.getLogger("klaudimero").info("Scheduler shut down")


app = FastAPI(title="Klaudimero", version="0.1.0", lifespan=lifespan)

app.include_router(jobs.router)
app.include_router(executions.router)
app.include_router(devices.router)
app.include_router(heartbeat.router)
app.include_router(chat.router)
app.include_router(soul.router)


@app.get("/")
async def root():
    return {"service": "klaudimero", "status": "running"}
