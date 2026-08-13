# CheckTap 0.13.0 — notificaciones de solicitudes

Este parche añade avisos automáticos, contador y actualización en tiempo real al autorregistro de CheckTap 0.12. Requiere que el flujo de autorregistro anterior ya esté aplicado.

## Aplicación en tu proyecto

```bash
cd /ruta/donde/descomprimiste/checktap_notificaciones_solicitudes_v0_13
chmod +x APLICAR_HOTFIX.sh
./APLICAR_HOTFIX.sh "$HOME/Documents/checktap/system"
```

El instalador valida todos los archivos antes de modificar el proyecto y crea un respaldo dentro de `system/.backups/`.

## Después de aplicar

No existe una migración nueva de base de datos. Valida el backend y reinicia el servicio:

```bash
cd "$HOME/Documents/checktap/system/backend"
source .venv/bin/activate
python -m pytest -q
```

Valida y compila la app:

```bash
cd "$HOME/Documents/checktap/system/mobile"
flutter pub get
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter run
```

## Notificaciones push

Para recibir push con la app cerrada, el backend debe tener `FIREBASE_ENABLED=true`, la credencial de servicio configurada y el teléfono debe autorizar notificaciones. Sin Firebase, el contador y la lista siguen actualizándose por WebSocket y comprobación periódica mientras la app puede comunicarse con el servidor.

## Validación

- Backend: 24 pruebas aprobadas.
- Python: Ruff aprobado en todos los archivos modificados.
- Dart: 10 archivos modificados parseados y formateados.
- Flutter: debe ejecutarse `flutter analyze` y `flutter test` en la máquina que contiene el SDK.

## Cambios

- Envía una notificación push a todos los administradores activos cuando llega una solicitud de acceso.
- Muestra un contador ámbar de solicitudes pendientes en el botón de menú y dentro del menú administrativo.
- Actualiza el contador y la lista mediante WebSocket, al regresar a la app y con una comprobación periódica de respaldo.
- Permite asociar de forma opcional el token FCM del solicitante durante el autorregistro, sin conceder sesión ni acceso.
- Notifica al solicitante cuando su cuenta es aprobada o rechazada, incluido el motivo cuando exista.
- Abre directamente **Solicitudes de acceso** cuando un administrador toca el aviso correspondiente.
- Mantiene el flujo operativo sin Firebase: la aprobación, el contador en primer plano y el estado mostrado al iniciar sesión continúan funcionando.
- No requiere una migración nueva de base de datos; reutiliza los registros de dispositivos y eventos existentes.
- Actualiza la API, la app móvil y el despliegue a CheckTap 0.13.0.
