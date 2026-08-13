from fastapi import HTTPException, status

from app.models.control import ControlCheck, ControlSection
from app.models.user import User
from app.services.department_service import is_department_member


def can_view_control_section(user: User, section: ControlSection) -> bool:
    return is_department_member(user, section.department_id)


def can_manage_control_section(user: User, section: ControlSection | None = None) -> bool:
    return user.is_admin


def can_create_control_check(user: User, section: ControlSection) -> bool:
    return is_department_member(user, section.department_id)


def can_edit_control_check(user: User, check: ControlCheck) -> bool:
    return user.is_admin or check.created_by_id == user.id


def can_work_control_check(user: User, check: ControlCheck) -> bool:
    return is_department_member(user, check.section.department_id)


def require_control_section_view(user: User, section: ControlSection) -> None:
    if not can_view_control_section(user, section):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No pertenece al departamento de esta seccion",
        )


def require_control_section_manage(user: User, section: ControlSection | None = None) -> None:
    if not can_manage_control_section(user, section):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo un administrador puede administrar secciones de control",
        )


def require_control_check_create(user: User, section: ControlSection) -> None:
    if not can_create_control_check(user, section):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No pertenece al departamento de esta seccion",
        )


def require_control_check_edit(user: User, check: ControlCheck) -> None:
    if not can_edit_control_check(user, check):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el creador o un administrador puede editar este control",
        )


def require_control_check_work(user: User, check: ControlCheck) -> None:
    if not can_work_control_check(user, check):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo un miembro del departamento puede completar este control",
        )
