# CheckTap - Desarrollo local

Este flujo mantiene la aplicacion en localhost durante las primeras fases.
Portainer no se usa todavia.

## Arquitectura local

```text
Flutter / navegador / emulador
            |
            | HTTP y WebSocket
            v
FastAPI: http://localhost:8000
            |
            v
PostgreSQL Docker local: localhost:5433
```

El backend se ejecuta directamente con Python para obtener recarga automatica.
Solamente PostgreSQL se ejecuta en Docker local.

## Requisitos

- Ubuntu o Linux compatible.
- Python 3.12 o superior.
- Docker Engine y Docker Compose Plugin.
- Flutter SDK para la fase movil.

## Preparacion automatica

Desde la raiz del proyecto:

```bash
./scripts/setup_local.sh
```

Este script:

1. Inicia PostgreSQL local en el puerto 5433.
2. Crea `backend/.env`.
3. Crea `backend/.venv`.
4. Instala dependencias.
5. Ejecuta las migraciones Alembic.

## Ejecutar FastAPI

```bash
./scripts/run_backend_local.sh
```

URLs:

```text
API:     http://localhost:8000
Swagger: http://localhost:8000/docs
Health:  http://localhost:8000/health
```

Credenciales locales iniciales:

```text
Correo: admin@checktap.com
Clave:  Admin123!
```

## Pruebas

Con el backend detenido o en otra terminal:

```bash
./scripts/test_local_backend.sh
```

## Detener PostgreSQL

```bash
./scripts/stop_local.sh
```

Los datos permanecen en el volumen `checktap_postgres_local_data`.
Para eliminar tambien los datos:

```bash
docker compose -f deploy/compose.local.yaml down -v
```

## Flutter

Android Emulator:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Telefono fisico conectado a la misma red:

```bash
hostname -I
cd mobile
flutter run --dart-define=API_BASE_URL=http://IP_LOCAL_DEL_EQUIPO:8000
```

Flutter Linux o Web:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## Fases

### Fase 1 - Base local

- PostgreSQL local.
- FastAPI y Alembic.
- Autenticacion.
- Usuarios.
- Crear, asignar y completar tareas.

### Fase 2 - Flutter local

- Login.
- Lista de tareas.
- Formulario de tareas.
- Cambio de estado.

### Fase 3 - Tiempo real

- WebSocket.
- Dos usuarios y dos dispositivos.
- Reconexion.

### Fase 4 - Informes

- Resumen diario.
- PDF.
- Descarga desde Flutter.

### Fase 5 - Firebase

- Tokens FCM.
- Notificaciones de asignacion y finalizacion.
- Recordatorios diarios.

### Fase 6 - Preparacion de produccion

- Configuracion segura.
- Dockerfiles definitivos.
- Backups, health checks y logs.

### Fase 7 - Portainer

- Stack.
- Volumen PostgreSQL.
- Red interna.
- Acceso por LAN o dominio.

## Arquitectura offline 0.5.0

- Offline 1: sesion segura y lectura local.
- Offline 2: crear y cambiar tareas en SQLite.
- Offline 3: cola ordenada y sincronizacion automatica.
- Offline 4: idempotencia, versiones y conflictos.
- Offline 5: reintentos y segundo plano.

Validacion:

```bash
./VALIDAR_OFFLINE_2_A_5.sh
```

Prueba detallada en `PRUEBA_MANUAL_OFFLINE_2_A_5.md`.
