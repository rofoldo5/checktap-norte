from datetime import UTC, date, datetime, time, timedelta
from io import BytesIO
from zoneinfo import ZoneInfo

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen.canvas import Canvas
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.models.task import Task


def daily_report_pdf(db: Session, report_date: date) -> bytes:
    timezone = ZoneInfo(settings.report_timezone)
    start_local = datetime.combine(report_date, time.min, timezone)
    end_local = start_local + timedelta(days=1)
    start_utc = start_local.astimezone(UTC)
    end_utc = end_local.astimezone(UTC)

    tasks = list(
        db.scalars(
            select(Task)
            .options(
                joinedload(Task.created_by),
                joinedload(Task.assigned_to),
                joinedload(Task.completed_by),
            )
            .where(Task.completed_at >= start_utc, Task.completed_at < end_utc)
            .order_by(Task.completed_at.asc())
        ).all()
    )

    buffer = BytesIO()
    canvas = Canvas(buffer, pagesize=A4)
    width, height = A4
    y = height - 50

    canvas.setTitle(f"Informe diario {report_date.isoformat()}")
    canvas.setFont("Helvetica-Bold", 16)
    canvas.drawString(50, y, "INFORME DIARIO DE TAREAS")
    y -= 24
    canvas.setFont("Helvetica", 11)
    canvas.drawString(50, y, f"Fecha: {report_date.isoformat()}")
    y -= 18
    canvas.drawString(50, y, f"Tareas completadas: {len(tasks)}")
    y -= 30

    if not tasks:
        canvas.drawString(50, y, "No se completaron tareas durante este dia.")
    else:
        for index, task in enumerate(tasks, start=1):
            if y < 120:
                canvas.showPage()
                y = height - 50

            canvas.setFont("Helvetica-Bold", 11)
            canvas.drawString(50, y, f"{index}. {task.title[:80]}")
            y -= 16
            canvas.setFont("Helvetica", 9)
            canvas.drawString(65, y, f"Prioridad: {task.priority}")
            y -= 13
            canvas.drawString(65, y, f"Creada por: {task.created_by.name}")
            y -= 13
            assigned = task.assigned_to.name if task.assigned_to else "Sin asignar"
            canvas.drawString(65, y, f"Asignada a: {assigned}")
            y -= 13
            completed = task.completed_by.name if task.completed_by else "No registrado"
            canvas.drawString(65, y, f"Completada por: {completed}")
            y -= 23

    canvas.save()
    return buffer.getvalue()
