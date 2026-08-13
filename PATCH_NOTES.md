# CheckTap - Hotfix Alembic para tareas recurrentes

Este hotfix fue preparado contra el proyecto `system(4).zip` entregado el 2026-08-13.

## Cambios

- Elimina la revision independiente `20260813_01_add_task_recurrence.py`.
- Agrega `0007_task_recurrence.py` enlazada a `0006_user_self_registration`.
- Elimina `schema_compat.py` para que Alembic sea el unico mecanismo de cambio de esquema.
- Actualiza `tests/test_recurrence.py` para validar el ID y el `down_revision` reales.
- No cambia Flutter, API de tareas, modelos de recurrencia ni formato de datos.

## Validacion realizada

- `alembic heads`: un solo head (`0007_task_recurrence`).
- Migracion del `checktap.db` entregado: `0006_user_self_registration -> 0007_task_recurrence`.
- 11/11 columnas de recurrencia creadas.
- 5/5 indices de recurrencia creados.
- `alembic downgrade 0006_user_self_registration` y posterior `alembic upgrade head`: correcto.
- Bootstrap completo de una SQLite vacia desde `0001_initial` hasta `0007_task_recurrence`: correcto.
- Escenario con columnas/indices preexistentes del hook temporal v0.14.0: correcto.
- Backend: `29 passed` con `PYTHONPATH=. pytest -q`.
