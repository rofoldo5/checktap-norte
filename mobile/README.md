# CheckTap Flutter

Cliente movil offline-first de CheckTap.

## Telefono Android por USB

Con FastAPI activo en el puerto 8000:

```bash
adb reverse --remove-all
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Android Emulator

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Telefono por red local

```bash
flutter run --dart-define=API_BASE_URL=http://IP_LOCAL_DEL_EQUIPO:8000
```

## Modo offline

El primer ingreso requiere FastAPI. Despues de sincronizar por primera vez, la aplicacion conserva la sesion y la cache local. Cerrar sesion elimina la autorizacion local y vuelve a requerir conexion.

Las tareas creadas o modificadas offline quedan en SQLite y se sincronizan al recuperar acceso al backend.

## Comprobacion

```bash
flutter clean
flutter pub get
dart format lib
flutter analyze
```
