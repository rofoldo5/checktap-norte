# Hotfix Alembic - recurrencia de tareas

## Causa corregida

El proyecto real ya contiene una historia Alembic canonica que termina en:

```text
0006_user_self_registration
```

La revision anterior de recurrencia fue creada accidentalmente con `down_revision = None`, por lo que Alembic la interpretaba como una segunda base y mostraba dos heads.

## Historia correcta

```text
0001_initial
  -> 0002_offline_sync
  -> 0003_device_notifications
  -> 0004_departments_team_reports
  -> 0005_task_checklists
  -> 0006_user_self_registration
  -> 0007_task_recurrence
```

La revision nueva es:

```text
revision = "0007_task_recurrence"
down_revision = "0006_user_self_registration"
```

## Archivos obsoletos eliminados

- `backend/alembic/versions/20260813_01_add_task_recurrence.py`
- `backend/app/services/schema_compat.py`

Alembic queda como unica fuente de verdad para cambios del esquema.

## Aplicar la migracion

Antes de modificar una base de produccion, realice un respaldo.

Desde `backend/`:

```bash
alembic heads
alembic current
alembic upgrade head
alembic current
```

Despues de aplicar este hotfix, `alembic heads` debe mostrar solamente:

```text
0007_task_recurrence (head)
```

Si la base estaba en la version anterior del proyecto, `alembic current` antes del upgrade debe mostrar normalmente:

```text
0006_user_self_registration
```

Despues del upgrade:

```text
0007_task_recurrence (head)
```

No use `alembic merge heads` ni `alembic stamp head` para corregir el error anterior.

## Compatibilidad con el parche temporal 0.14.0

La migracion inspecciona las columnas e indices existentes. Si una instalacion llego a ejecutar el mecanismo temporal que agregaba columnas de recurrencia sin Alembic, la revision `0007_task_recurrence` registra correctamente la migracion y agrega solamente lo que falte.

## Docker / Portainer

`backend/entrypoint.sh` ya ejecuta `alembic upgrade head` antes de iniciar FastAPI o el scheduler. Una vez instalado este hotfix, reconstruya la imagen backend y recree `api` y `scheduler`.
