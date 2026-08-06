import os
from pathlib import Path

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///./test.db"
os.environ["JWT_SECRET"] = "test-secret-key-with-at-least-thirty-two-bytes"
os.environ["BOOTSTRAP_ADMIN_EMAIL"] = "admin@example.com"
os.environ["BOOTSTRAP_ADMIN_PASSWORD"] = "Admin123!"
os.environ["DEFAULT_DEPARTMENT_NAME"] = "Programacion"
os.environ["REPORT_STORAGE_PATH"] = "./test-reports"
os.environ["FIREBASE_ENABLED"] = "false"

from app.core.database import Base, engine  # noqa: E402
from app.models import (  # noqa: E402,F401
    DailyReport,
    Department,
    DepartmentMember,
    DeviceRegistration,
    NotificationDelivery,
    NotificationEvent,
    ProcessedOperation,
    Task,
    User,
)


def pytest_sessionstart(session):
    Path("test.db").unlink(missing_ok=True)
    reports = Path("test-reports")
    if reports.exists():
        import shutil

        shutil.rmtree(reports)
    Base.metadata.create_all(bind=engine)


def pytest_sessionfinish(session, exitstatus):
    Base.metadata.drop_all(bind=engine)
    engine.dispose()
    Path("test.db").unlink(missing_ok=True)
    reports = Path("test-reports")
    if reports.exists():
        import shutil

        shutil.rmtree(reports)
