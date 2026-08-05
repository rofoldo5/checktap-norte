from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.user import User


def create_bootstrap_admin() -> None:
    with SessionLocal() as db:
        existing = db.scalar(
            select(User).where(User.email == settings.bootstrap_admin_email.lower())
        )
        if existing is not None:
            return

        admin = User(
            name=settings.bootstrap_admin_name,
            email=settings.bootstrap_admin_email.lower(),
            password_hash=hash_password(settings.bootstrap_admin_password),
            is_admin=True,
        )
        db.add(admin)
        db.commit()
