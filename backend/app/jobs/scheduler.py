from __future__ import annotations

import logging
import signal
import time
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.department import Department
from app.services.notification_service import notification_service
from app.services.report_service import generate_department_daily_report

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("checktap.scheduler")
_running = True


def _stop(*_: object) -> None:
    global _running
    _running = False


def _due(now: datetime) -> bool:
    hour, minute = (int(part) for part in settings.daily_report_time.split(":"))
    return (now.hour, now.minute) >= (hour, minute)


def run_once() -> int:
    if not settings.daily_report_enabled:
        return 0
    local_now = datetime.now(ZoneInfo(settings.report_timezone))
    if not _due(local_now):
        return 0

    generated_count = 0
    with SessionLocal() as db:
        departments = list(
            db.scalars(
                select(Department)
                .where(Department.is_active.is_(True))
                .order_by(Department.name.asc())
            ).all()
        )
        for department in departments:
            try:
                report, generated = generate_department_daily_report(
                    db,
                    department.id,
                    local_now.date(),
                )
                if not generated:
                    continue
                generated_count += 1
                delivery = notification_service.notify_report_ready(
                    department_id=department.id,
                    report_id=report.id,
                    report_date=report.report_date,
                )
                logger.info(
                    "Informe %s generado para %s; dispositivos=%s exitos=%s fallos=%s",
                    report.report_date,
                    department.name,
                    delivery.attempted,
                    delivery.success_count,
                    delivery.failure_count,
                )
            except Exception:
                db.rollback()
                logger.exception("No fue posible generar el informe de %s", department.name)
    return generated_count


def main() -> None:
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    logger.info(
        "Scheduler iniciado: hora=%s zona=%s intervalo=%ss",
        settings.daily_report_time,
        settings.report_timezone,
        settings.scheduler_poll_seconds,
    )
    while _running:
        run_once()
        for _ in range(max(settings.scheduler_poll_seconds, 1)):
            if not _running:
                break
            time.sleep(1)
    logger.info("Scheduler detenido")


if __name__ == "__main__":
    main()
