from __future__ import annotations

import os
import textwrap
from datetime import UTC, date, datetime, time, timedelta
from io import BytesIO
from pathlib import Path
from uuid import UUID
from zoneinfo import ZoneInfo

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen.canvas import Canvas
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.config import settings
from app.models.checklist import TaskChecklist, TaskChecklistItem
from app.models.daily_report import DailyReport
from app.models.department import Department
from app.models.task import Task


def _day_bounds(report_date: date) -> tuple[datetime, datetime]:
    timezone = ZoneInfo(settings.report_timezone)
    start_local = datetime.combine(report_date, time.min, timezone)
    end_local = start_local + timedelta(days=1)
    return start_local.astimezone(UTC), end_local.astimezone(UTC)


def _task_query():
    return select(Task).options(
        joinedload(Task.department),
        joinedload(Task.created_by),
        joinedload(Task.completed_by),
        selectinload(Task.assignees),
        selectinload(Task.checklists).joinedload(TaskChecklist.created_by),
        selectinload(Task.checklists)
        .selectinload(TaskChecklist.items)
        .joinedload(TaskChecklistItem.completed_by),
    )


def _task_sets(
    db: Session,
    department_id: UUID,
    report_date: date,
) -> tuple[list[Task], list[Task], list[Task], list[Task]]:
    start_utc, end_utc = _day_bounds(report_date)
    created = list(
        db.scalars(
            _task_query()
            .where(
                Task.department_id == department_id,
                Task.created_at >= start_utc,
                Task.created_at < end_utc,
            )
            .order_by(Task.created_at.asc())
        ).unique().all()
    )
    completed = list(
        db.scalars(
            _task_query()
            .where(
                Task.department_id == department_id,
                Task.completed_at >= start_utc,
                Task.completed_at < end_utc,
            )
            .order_by(Task.completed_at.asc())
        ).unique().all()
    )
    pending = list(
        db.scalars(
            _task_query()
            .where(
                Task.department_id == department_id,
                Task.status == "PENDIENTE",
            )
            .order_by(Task.priority.desc(), Task.created_at.asc())
        ).unique().all()
    )
    in_progress = list(
        db.scalars(
            _task_query()
            .where(
                Task.department_id == department_id,
                Task.status == "EN_PROGRESO",
            )
            .order_by(Task.priority.desc(), Task.updated_at.asc())
        ).unique().all()
    )
    return created, completed, pending, in_progress


def _assignees(task: Task) -> str:
    if not task.assignees:
        return "Todo el equipo"
    return ", ".join(user.name for user in task.assignees)


def _write_wrapped(
    canvas: Canvas,
    text: str,
    *,
    x: float,
    y: float,
    width_chars: int = 94,
    line_height: int = 12,
) -> float:
    for line in textwrap.wrap(text, width=width_chars) or [""]:
        canvas.drawString(x, y, line)
        y -= line_height
    return y


def daily_report_pdf(
    db: Session,
    report_date: date,
    department_id: UUID,
) -> bytes:
    department = db.get(Department, department_id)
    if department is None:
        raise ValueError("Departamento no encontrado")
    created, completed, pending, in_progress = _task_sets(
        db,
        department_id,
        report_date,
    )

    buffer = BytesIO()
    canvas = Canvas(buffer, pagesize=A4)
    width, height = A4
    y = height - 48

    def new_page() -> None:
        nonlocal y
        canvas.showPage()
        y = height - 48

    def ensure_space(lines: int = 6) -> None:
        nonlocal y
        if y < 50 + lines * 12:
            new_page()

    def section(title: str, tasks: list[Task], empty: str) -> None:
        nonlocal y
        ensure_space(4)
        canvas.setFont("Helvetica-Bold", 12)
        canvas.drawString(50, y, title)
        y -= 18
        if not tasks:
            canvas.setFont("Helvetica-Oblique", 9)
            canvas.drawString(62, y, empty)
            y -= 18
            return
        for index, task in enumerate(tasks, start=1):
            ensure_space(7)
            canvas.setFont("Helvetica-Bold", 10)
            y = _write_wrapped(canvas, f"{index}. {task.title}", x=62, y=y, width_chars=78)
            canvas.setFont("Helvetica", 8.5)
            canvas.drawString(75, y, f"Estado: {task.status.replace('_', ' ')} | Prioridad: {task.priority}")
            y -= 11
            canvas.drawString(75, y, f"Creada por: {task.created_by.name}")
            y -= 11
            canvas.drawString(75, y, f"Responsables: {_assignees(task)}")
            y -= 11
            if task.completed_by is not None:
                canvas.drawString(75, y, f"Completada por: {task.completed_by.name}")
                y -= 11
            for checklist in task.checklists:
                ensure_space(4 + len(checklist.items))
                canvas.setFont("Helvetica-Bold", 8.5)
                progress = f"{checklist.completed_count}/{checklist.item_count}"
                y = _write_wrapped(
                    canvas,
                    f"Checklist: {checklist.title} ({progress})",
                    x=75,
                    y=y,
                    width_chars=78,
                    line_height=10,
                )
                canvas.setFont("Helvetica", 8)
                for item in checklist.items:
                    marker = "[x]" if item.is_completed else "[ ]"
                    actor = (
                        f" - {item.completed_by.name}"
                        if item.completed_by is not None
                        else ""
                    )
                    y = _write_wrapped(
                        canvas,
                        f"{marker} {item.title}{actor}",
                        x=88,
                        y=y,
                        width_chars=74,
                        line_height=10,
                    )
                y -= 3
            y -= 7

    canvas.setTitle(f"Informe {department.name} {report_date.isoformat()}")
    canvas.setFont("Helvetica-Bold", 16)
    canvas.drawString(50, y, "INFORME DIARIO CHECKTAP")
    y -= 23
    canvas.setFont("Helvetica-Bold", 11)
    canvas.drawString(50, y, f"Departamento: {department.name}")
    y -= 15
    canvas.setFont("Helvetica", 10)
    canvas.drawString(50, y, f"Fecha: {report_date.strftime('%d/%m/%Y')}")
    y -= 15
    canvas.drawString(50, y, f"Zona horaria: {settings.report_timezone}")
    y -= 24

    canvas.setFont("Helvetica-Bold", 11)
    canvas.drawString(50, y, "Resumen")
    y -= 16
    canvas.setFont("Helvetica", 9)
    summary = (
        f"Creadas: {len(created)}   |   Completadas: {len(completed)}   |   "
        f"Pendientes: {len(pending)}   |   En progreso: {len(in_progress)}"
    )
    y = _write_wrapped(canvas, summary, x=62, y=y, width_chars=92)
    y -= 14

    section("Tareas creadas durante el dia", created, "No se crearon tareas.")
    section("Tareas completadas durante el dia", completed, "No se completaron tareas.")
    section("Tareas actualmente en progreso", in_progress, "No hay tareas en progreso.")
    section("Tareas actualmente pendientes", pending, "No hay tareas pendientes.")

    canvas.save()
    return buffer.getvalue()


def generate_department_daily_report(
    db: Session,
    department_id: UUID,
    report_date: date,
) -> tuple[DailyReport, bool]:
    existing = db.scalar(
        select(DailyReport).where(
            DailyReport.department_id == department_id,
            DailyReport.report_date == report_date,
        )
    )
    if existing is not None and existing.status == "READY" and existing.file_path:
        if Path(existing.file_path).is_file():
            return existing, False

    report = existing or DailyReport(
        department_id=department_id,
        report_date=report_date,
        status="PROCESSING",
    )
    report.status = "PROCESSING"
    report.error = None
    db.add(report)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        concurrent = db.scalar(
            select(DailyReport).where(
                DailyReport.department_id == department_id,
                DailyReport.report_date == report_date,
            )
        )
        if concurrent is None:
            raise
        return concurrent, False
    db.refresh(report)

    try:
        created, completed, pending, in_progress = _task_sets(
            db,
            department_id,
            report_date,
        )
        content = daily_report_pdf(db, report_date, department_id)
        department_dir = Path(settings.report_storage_path) / str(department_id)
        department_dir.mkdir(parents=True, exist_ok=True)
        final_path = department_dir / f"{report_date.isoformat()}.pdf"
        temporary_path = final_path.with_suffix(".pdf.tmp")
        temporary_path.write_bytes(content)
        os.replace(temporary_path, final_path)

        report.status = "READY"
        report.file_path = str(final_path)
        report.file_size = len(content)
        report.created_count = len(created)
        report.completed_count = len(completed)
        report.pending_count = len(pending)
        report.in_progress_count = len(in_progress)
        report.generated_at = datetime.now(UTC)
        report.error = None
        db.add(report)
        db.commit()
        db.refresh(report)
        return report, True
    except Exception as exc:
        report.status = "FAILED"
        report.error = f"{type(exc).__name__}: {exc}"[:2000]
        report.generated_at = datetime.now(UTC)
        db.add(report)
        db.commit()
        raise
