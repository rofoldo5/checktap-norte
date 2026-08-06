from datetime import datetime
from pathlib import Path
from typing import Annotated
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.daily_report import DailyReport
from app.models.user import User
from app.schemas.report import DailyReportGenerate, DailyReportRead
from app.services.department_service import (
    active_department_ids,
    require_department_access,
    resolve_task_department,
)
from app.services.notification_service import notification_service
from app.services.report_service import daily_report_pdf, generate_department_daily_report

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("", response_model=list[DailyReportRead])
def list_reports(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    department_id: UUID | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> list[DailyReport]:
    query = (
        select(DailyReport)
        .options(joinedload(DailyReport.department))
        .where(DailyReport.status == "READY")
        .order_by(DailyReport.report_date.desc(), DailyReport.generated_at.desc())
        .limit(limit)
    )
    if department_id is not None:
        require_department_access(current_user, department_id)
        query = query.where(DailyReport.department_id == department_id)
    elif not current_user.is_admin:
        query = query.where(
            DailyReport.department_id.in_(active_department_ids(current_user))
        )
    return list(db.scalars(query).unique().all())


@router.post("/generate", response_model=DailyReportRead)
def generate_report(
    payload: DailyReportGenerate,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> DailyReport:
    department = resolve_task_department(db, current_user, payload.department_id)
    selected_date = payload.report_date or datetime.now(
        ZoneInfo(settings.report_timezone)
    ).date()
    report, generated = generate_department_daily_report(
        db,
        department.id,
        selected_date,
    )
    if generated:
        background_tasks.add_task(
            notification_service.notify_report_ready,
            department_id=department.id,
            report_id=report.id,
            report_date=report.report_date,
        )
    return report


@router.get("/{report_id}/download")
def download_generated_report(
    report_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    report = db.scalar(
        select(DailyReport)
        .options(joinedload(DailyReport.department))
        .where(DailyReport.id == report_id)
    )
    if report is None or report.status != "READY":
        raise HTTPException(status_code=404, detail="Informe no disponible")
    require_department_access(current_user, report.department_id)
    path = Path(report.file_path or "")
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Archivo de informe no disponible")
    filename = (
        f"checktap-{report.department.name.lower().replace(' ', '-')}-"
        f"{report.report_date.isoformat()}.pdf"
    )
    return Response(
        content=path.read_bytes(),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/daily.pdf")
def daily_report(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    report_date: Annotated[str | None, Query(alias="date")] = None,
    department_id: UUID | None = None,
) -> Response:
    if report_date:
        try:
            selected_date = datetime.strptime(report_date, "%Y-%m-%d").date()
        except ValueError as exc:
            raise HTTPException(
                status_code=422,
                detail="La fecha debe usar el formato YYYY-MM-DD",
            ) from exc
    else:
        selected_date = datetime.now(ZoneInfo(settings.report_timezone)).date()

    department = resolve_task_department(db, current_user, department_id)
    content = daily_report_pdf(db, selected_date, department.id)
    filename = f"informe-{department.name}-{selected_date.isoformat()}.pdf"
    return Response(
        content=content,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
