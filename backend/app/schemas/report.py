from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.department import DepartmentSummary


class DailyReportGenerate(BaseModel):
    department_id: UUID | None = None
    report_date: date | None = None


class DailyReportRead(BaseModel):
    id: UUID
    department: DepartmentSummary
    report_date: date
    status: str
    file_size: int
    created_count: int
    completed_count: int
    pending_count: int
    in_progress_count: int
    error: str | None
    generated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DailyReportList(BaseModel):
    reports: list[DailyReportRead] = Field(default_factory=list)
