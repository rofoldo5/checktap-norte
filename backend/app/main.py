from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    auth,
    checklists,
    departments,
    devices,
    health,
    notifications,
    reports,
    sync,
    tasks,
    users,
    websocket,
)
from app.core.config import settings
from app.services.bootstrap import create_bootstrap_admin
from app.services.notification_service import notification_service
from app.services.schema_compat import ensure_recurring_task_schema


@asynccontextmanager
async def lifespan(_: FastAPI):
    ensure_recurring_task_schema()
    create_bootstrap_admin()
    notification_service.initialize()
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router, prefix=settings.api_prefix)
app.include_router(users.router, prefix=settings.api_prefix)
app.include_router(departments.router, prefix=settings.api_prefix)
app.include_router(tasks.router, prefix=settings.api_prefix)
app.include_router(checklists.router, prefix=settings.api_prefix)
app.include_router(sync.router, prefix=settings.api_prefix)
app.include_router(reports.router, prefix=settings.api_prefix)
app.include_router(devices.router, prefix=settings.api_prefix)
app.include_router(notifications.router, prefix=settings.api_prefix)
app.include_router(websocket.router, prefix=settings.api_prefix)
