import pytest
from pydantic import ValidationError

from app.schemas.department import DepartmentCreate, DepartmentUpdate
from app.schemas.task import TaskCreate, TaskUpdate
from app.schemas.user import UserCreate, UserUpdate


def test_department_names_reject_blank_values() -> None:
    with pytest.raises(ValidationError):
        DepartmentCreate(name="   ")
    with pytest.raises(ValidationError):
        DepartmentUpdate(name="\n\t  ")


def test_user_names_and_passwords_reject_blank_values() -> None:
    with pytest.raises(ValidationError):
        UserCreate(
            name="   ",
            email="user@example.com",
            password="Secret123!",
        )
    with pytest.raises(ValidationError):
        UserCreate(
            name="Usuario Valido",
            email="user@example.com",
            password="      ",
        )
    with pytest.raises(ValidationError):
        UserUpdate(name="   ")
    with pytest.raises(ValidationError):
        UserUpdate(password="      ")


def test_task_titles_reject_blank_and_descriptions_are_normalized() -> None:
    with pytest.raises(ValidationError):
        TaskCreate(title="   ")
    with pytest.raises(ValidationError):
        TaskUpdate(title="   ")

    task = TaskCreate(title="  Revisar   servidor  ", description="   ")
    assert task.title == "Revisar servidor"
    assert task.description is None
