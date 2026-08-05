# CheckTap

Aplicacion colaborativa de tareas con Flutter, FastAPI y PostgreSQL.

## Alcance actual

Cada tarea contiene titulo, descripcion, estado, prioridad, creador, usuario asignado y usuario que la completo.

La version 0.6.0 incluye:

- Arquitectura offline-first con SQLite y cola de sincronizacion.
- Sincronizacion REST, WebSocket y trabajo en segundo plano.
- Idempotencia, versiones y deteccion de conflictos.
- Validaciones consistentes en Flutter y FastAPI.
- Permisos por creador, responsable y administrador.
- Detalle y edicion offline de tareas.
- Administracion basica de usuarios.
- Generacion y comparticion del informe PDF desde Flutter.

## Desarrollo local

```bash
./scripts/setup_local.sh
./scripts/run_backend_local.sh
```

Backend:

```text
http://127.0.0.1:8000
```

Telefono fisico por USB:

```bash
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Validaciones

```bash
./VALIDAR_OFFLINE_2_A_5.sh
./VALIDAR_ESTABILIZACION_V0_6.sh
```

Consultar:

- `LOCAL_DEVELOPMENT.md`
- `OFFLINE_2_A_5.md`
- `ESTABILIZACION_V0_6.md`
- `STATUS.md`
- `VALIDATION.md`
