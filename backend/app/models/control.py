from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Table, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


control_check_assignees = Table(
    "control_check_assignees",
    Base.metadata,
    Column(
        "check_id",
        ForeignKey("control_checks.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "user_id",
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "assigned_at",
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        nullable=False,
    ),
)


class ControlSection(Base):
    __tablename__ = "control_sections"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon_key: Mapped[str] = mapped_column(String(40), default="folder", nullable=False)
    department_id: Mapped[UUID] = mapped_column(
        ForeignKey("departments.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_by_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        nullable=False,
    )

    department: Mapped["Department"] = relationship(lazy="joined")
    created_by: Mapped["User"] = relationship(foreign_keys=[created_by_id])
    checks: Mapped[list["ControlCheck"]] = relationship(
        back_populates="section",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="selectin",
        order_by=lambda: (ControlCheck.due_at, ControlCheck.title),
    )


class ControlCheck(Base):
    __tablename__ = "control_checks"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    section_id: Mapped[UUID] = mapped_column(
        ForeignKey("control_sections.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    reference: Mapped[str | None] = mapped_column(String(300), nullable=True)
    contact: Mapped[str | None] = mapped_column(String(300), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    priority: Mapped[str] = mapped_column(String(10), default="MEDIA", nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), default="PENDIENTE", nullable=False, index=True)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    timezone: Mapped[str] = mapped_column(String(80), default="UTC", nullable=False)
    recurrence_type: Mapped[str] = mapped_column(
        String(20), default="NONE", nullable=False, index=True
    )
    recurrence_interval: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    recurrence_unit: Mapped[str | None] = mapped_column(String(12), nullable=True)
    recurrence_anchor_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    recurrence_anchor_month: Mapped[int | None] = mapped_column(Integer, nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_by_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    completed_by_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        nullable=False,
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    section: Mapped[ControlSection] = relationship(back_populates="checks")
    created_by: Mapped["User"] = relationship(foreign_keys=[created_by_id])
    completed_by: Mapped["User | None"] = relationship(foreign_keys=[completed_by_id])
    assignees: Mapped[list["User"]] = relationship(
        secondary=control_check_assignees,
        lazy="selectin",
        order_by="User.name",
    )
    reminders: Mapped[list["ControlCheckReminder"]] = relationship(
        back_populates="check",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="selectin",
        order_by="ControlCheckReminder.minutes_before.desc()",
    )
    history: Mapped[list["ControlCheckHistory"]] = relationship(
        back_populates="check",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="selectin",
        order_by="ControlCheckHistory.completed_at.desc()",
    )


class ControlCheckReminder(Base):
    __tablename__ = "control_check_reminders"
    __table_args__ = (
        UniqueConstraint("check_id", "minutes_before", name="uq_control_check_reminder"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    check_id: Mapped[UUID] = mapped_column(
        ForeignKey("control_checks.id", ondelete="CASCADE"), nullable=False, index=True
    )
    minutes_before: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )

    check: Mapped[ControlCheck] = relationship(back_populates="reminders")


class ControlCheckHistory(Base):
    __tablename__ = "control_check_history"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    check_id: Mapped[UUID] = mapped_column(
        ForeignKey("control_checks.id", ondelete="CASCADE"), nullable=False, index=True
    )
    completed_by_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    next_due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completion_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    check: Mapped[ControlCheck] = relationship(back_populates="history")
    completed_by: Mapped["User | None"] = relationship(foreign_keys=[completed_by_id])
