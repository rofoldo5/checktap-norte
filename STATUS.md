# Estado de CheckTap

Version: 0.6.0

## Implementado

- Autenticacion JWT.
- Usuarios y tareas compartidas.
- PostgreSQL y migraciones Alembic.
- WebSocket para actualizaciones.
- Informe diario PDF.
- Offline 1: sesion y lectura local.
- Offline 2: escritura local y cola SQLite.
- Offline 3: sincronizacion ordenada y automatica.
- Offline 4: idempotencia, versiones y conflictos.
- Offline 5: reintentos, ciclo de vida y trabajo en segundo plano.
- Validaciones de texto y proteccion contra campos nulos invalidos.
- Permisos por creador, responsable y administrador.
- Detalle y edicion offline de tareas.
- Administracion de usuarios para administradores.
- Informe PDF generado y compartido desde Flutter.

## Validado automaticamente

- 6 pruebas backend aprobadas.
- Permisos y validaciones aprobados.
- Sincronizacion de `UPDATE_TASK` aprobada.
- Administracion de usuarios aprobada.
- Endpoint PDF aprobado.
- Estructura Flutter verificada.

## Pendiente de validacion en dispositivo

- `flutter analyze` con el SDK local.
- Compilacion e instalacion Android.
- Edicion offline y sincronizacion posterior.
- Prueba de permisos con dos usuarios.
- Comparticion real del PDF.

## Siguiente bloque funcional

- Firebase Cloud Messaging.
- Recordatorios diarios.
- Notificaciones de asignacion y finalizacion.
- Preparacion posterior para Portainer.
