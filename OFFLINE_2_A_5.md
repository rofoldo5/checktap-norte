# CheckTap Offline 2 a 5

Version objetivo: 0.5.0

## Arquitectura

PostgreSQL continua como fuente central. Cada dispositivo mantiene una base SQLite con las tareas, usuarios y una cola ordenada de operaciones.

Flujo de escritura:

1. La interfaz modifica SQLite inmediatamente.
2. Se registra una operacion con UUID en `sync_queue`.
3. La tarea se muestra como pendiente.
4. Al recuperar conexion, Flutter envia las operaciones en orden.
5. FastAPI aplica cada operacion de forma idempotente.
6. PostgreSQL incrementa la version de la tarea.
7. Flutter reemplaza el registro local con la version confirmada.

## Offline 2 - Escritura local

Incluye:

- Crear tareas sin servidor.
- Iniciar, completar y reabrir tareas sin servidor.
- Persistencia despues de cerrar o reiniciar la app.
- Estados locales: SYNCED, PENDING, SYNCING, ERROR y CONFLICT.
- Contador de operaciones pendientes.

## Offline 3 - Sincronizacion

Incluye:

- Cola FIFO en SQLite.
- Sincronizacion manual.
- Sincronizacion al recuperar conectividad.
- Sincronizacion al volver al primer plano.
- Reintento periodico en primer plano.
- Actualizacion por WebSocket cuando el servidor informa cambios.

La conectividad del sistema solo activa un intento. La respuesta real de FastAPI determina si el servidor esta disponible.

## Offline 4 - Idempotencia y conflictos

Incluye:

- UUID de tarea generado en Flutter.
- UUID unico por operacion.
- Tabla `processed_operations` en PostgreSQL.
- Campo `tasks.version`.
- Repetir una operacion devuelve el resultado anterior sin duplicar datos.
- Una version obsoleta devuelve CONFLICT y la tarea vigente del servidor.

Politica inicial: prevalece la version confirmada por el servidor. El usuario puede aceptar esa version desde la tarjeta de tarea.

## Offline 5 - Reintentos y segundo plano

Incluye:

- Reintentos al abrir la app y al volver al primer plano.
- Trabajo unico Android despues de una mutacion.
- Trabajo periodico Android con restriccion de red.
- Background Fetch configurado en iOS.
- Sesion en almacenamiento seguro.

El sistema operativo decide el momento exacto de la ejecucion en segundo plano. La sincronizacion al abrir o reanudar la app sigue siendo el mecanismo principal y determinista.

## Migracion de base de datos

Alembic agrega:

- `tasks.version` con valor inicial 1.
- Tabla `processed_operations`.

La migracion conserva usuarios y tareas existentes.

## Verificacion

Ejecutar por fase:

```bash
./VERIFICAR_OFFLINE_2.sh
./VERIFICAR_OFFLINE_3.sh
./VERIFICAR_OFFLINE_4.sh
./VERIFICAR_OFFLINE_5.sh
```

O ejecutar todas:

```bash
./VALIDAR_OFFLINE_2_A_5.sh
```

Para inspeccionar la SQLite del telefono en una compilacion debug:

```bash
./INSPECCIONAR_OFFLINE_DISPOSITIVO.sh
```
