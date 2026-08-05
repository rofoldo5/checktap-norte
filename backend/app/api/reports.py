from datetime import datetime
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.services.report_service import daily_report_pdf

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/daily.pdf")
def daily_report(
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(get_current_user)],
    report_date: Annotated[str | None, Query(alias="date")] = None,
) -> Response:
    if report_date:
        try:
            selected_date = datetime.strptime(report_date, "%Y-%m-%d").date()
        except ValueError as exc:
            from fastapi import HTTPException

            raise HTTPException(
                status_code=422,
                detail="La fecha debe usar el formato YYYY-MM-DD",
            ) from exc
    else:
        selected_date = datetime.now(ZoneInfo(settings.report_timezone)).date()

    content = daily_report_pdf(db, selected_date)
    filename = f"informe-tareas-{selected_date.isoformat()}.pdf"
    return Response(
        content=content,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
