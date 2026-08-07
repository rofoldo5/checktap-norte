# CheckTap Launcher Icon v0.11.1

Parche de interfaz Flutter para Café Mi Viejo.

## Aplicación

```bash
chmod +x APLICAR_HOTFIX.sh
./APLICAR_HOTFIX.sh /ruta/al/proyecto/flutter
```

## Validación

```bash
dart format .
flutter analyze
flutter test
```

El script crea un respaldo en `.backups/` antes de reemplazar archivos.
El logo oficial no debe modificarse.

## Cambios

- Amplia visualmente el icono de CheckTap en Ajustes/Gestion de aplicaciones y launcher.
- Agrega Adaptive Icon para Android 8+ y roundIcon.
- Agrega monochrome para iconos tematicos en Android 13+ reutilizando el vector de notificaciones existente.
- Regenera los mipmaps legacy con el mismo arte aprobado, recortando solo margen exterior del launcher.
- No modifica el logo oficial, Firebase, API, backend, sincronizacion ni permisos.
- Sube la version Flutter a 0.11.1+13 para facilitar la actualizacion del APK.
