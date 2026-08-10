# Autorregistro y aprobación de usuarios — CheckTap 0.12

## Flujo

1. El colaborador abre **Crear una cuenta** desde el inicio de sesión.
2. Registra nombre, correo, contraseña y departamento.
3. La API crea la cuenta como `PENDING`, sin permisos administrativos y sin acceso.
4. Un administrador abre **Solicitudes de acceso**.
5. El administrador confirma el departamento y aprueba o rechaza la solicitud.
6. Solo una cuenta `APPROVED` y activa puede obtener un token e ingresar.

Estados disponibles:

| Estado | Acceso | Uso |
| --- | --- | --- |
| `PENDING` | No | Solicitud por revisar |
| `APPROVED` | Sí | Cuenta habilitada |
| `REJECTED` | No | Solicitud rechazada |
| `SUSPENDED` | No | Cuenta aprobada posteriormente desactivada |

## Seguridad

- El endpoint público usa un esquema cerrado: rechaza campos adicionales como `is_admin`.
- El correo es único y no se crean solicitudes duplicadas.
- Solo un administrador autenticado puede listar, aprobar o rechazar solicitudes.
- La aprobación exige un departamento activo.
- Las cuentas anteriores a la migración conservan su acceso: las activas pasan a `APPROVED` y las inactivas a `SUSPENDED`.
- Una cuenta pendiente, rechazada o suspendida no recibe token JWT ni acceso WebSocket.

## Endpoints

| Método | Ruta | Autenticación |
| --- | --- | --- |
| `GET` | `/api/v1/auth/registration/departments` | Pública |
| `POST` | `/api/v1/auth/register` | Pública |
| `GET` | `/api/v1/users/access-requests` | Administrador |
| `POST` | `/api/v1/users/{id}/approve` | Administrador |
| `POST` | `/api/v1/users/{id}/reject` | Administrador |

## Despliegue

La migración `0006_user_self_registration` se aplica automáticamente al iniciar el contenedor de la API. En una instalación manual:

```bash
cd backend
alembic upgrade head
```

El autorregistro está habilitado por defecto. Para deshabilitarlo:

```env
SELF_REGISTRATION_ENABLED=false
```

## Verificación

```bash
cd backend
python -m pytest -q tests/test_self_registration.py

cd ../mobile
flutter analyze --fatal-infos
flutter test test/self_registration_model_test.dart
```
