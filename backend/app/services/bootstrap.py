from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.user import ACCOUNT_STATUS_APPROVED, User
from app.services.department_service import ensure_default_memberships


def create_bootstrap_admin() -> None:
    with SessionLocal() as db:
        existing = db.scalar(
            select(User).where(User.email == settings.bootstrap_admin_email.lower())
        )
        if existing is None:
            existing = User(
                name=settings.bootstrap_admin_name,
                email=settings.bootstrap_admin_email.lower(),
                password_hash=hash_password(settings.bootstrap_admin_password),
                is_admin=True,
                is_active=True,
                account_status=ACCOUNT_STATUS_APPROVED,
            )
            db.add(existing)
            db.flush()

        ensure_default_memberships(db)
        db.commit()
