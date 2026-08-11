# Notificaciones de solicitudes de acceso — CheckTap 0.13

## Comportamiento

1. El colaborador envía su solicitud desde **Crear una cuenta**.
2. Si autorizó notificaciones, la app adjunta el token FCM de ese teléfono a la cuenta pendiente.
3. La API mantiene la cuenta sin acceso y emite `access_request.created` por WebSocket a los administradores conectados.
4. Los administradores activos con un dispositivo registrado reciben además una notificación push.
5. El contador del menú y la pantalla **Solicitudes de acceso** se actualizan en tiempo real, al volver a primer plano y mediante comprobación periódica.
6. Al aprobar o rechazar, el solicitante recibe una notificación push en el teléfono asociado. La decisión también sigue visible al intentar iniciar sesión.

La asociación del dispositivo no concede sesión, JWT, permisos ni acceso WebSocket. Una cuenta `PENDING`, `REJECTED` o `SUSPENDED` continúa bloqueada.

## Eventos

| Canal | Evento | Destinatario |
| --- | --- | --- |
| WebSocket | `access_request.created` | Administradores conectados |
| WebSocket | `access_request.reviewed` | Administradores conectados |
| FCM | `access_request_created` | Administradores activos |
| FCM | `access_request_approved` | Solicitante aprobado |
| FCM | `access_request_rejected` | Solicitante rechazado |

Las conexiones WebSocket administrativas se identifican en el servidor, por lo que los eventos de solicitudes no se transmiten a colaboradores.

## Endpoints

| Método | Ruta | Autenticación |
| --- | --- | --- |
| `POST` | `/api/v1/auth/register` | Pública; acepta `device_registration` opcional |
| `GET` | `/api/v1/users/access-requests` | Administrador |
| `GET` | `/api/v1/users/access-requests/count` | Administrador |
| `POST` | `/api/v1/users/{id}/approve` | Administrador |
| `POST` | `/api/v1/users/{id}/reject` | Administrador |

## Requisitos para push

- `FIREBASE_ENABLED=true` en el backend.
- Credencial de servicio disponible en `GOOGLE_APPLICATION_CREDENTIALS`.
- Configuración FlutterFire válida en la aplicación móvil.
- Permiso de notificaciones concedido en el teléfono.
- El administrador debe haber iniciado sesión al menos una vez en ese dispositivo.

Sin Firebase, el flujo de aprobación continúa funcionando. Los administradores con la app abierta reciben los eventos por WebSocket y la interfaz también comprueba periódicamente el contador.

## Verificación

```bash
cd backend
python -m pytest -q

cd ../mobile
dart format lib test
flutter analyze --fatal-infos
flutter test test/ui/access_request_badge_test.dart
flutter test
```
