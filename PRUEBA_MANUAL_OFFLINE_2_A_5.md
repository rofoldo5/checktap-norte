# Prueba manual CheckTap Offline 2 a 5

## Preparacion

En una terminal:

```bash
cd ~/Documents/checktap/system
./scripts/run_backend_local.sh
```

En otra terminal:

```bash
adb reverse --remove-all
adb reverse tcp:8000 tcp:8000
cd ~/Documents/checktap/system/mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Iniciar sesion y esperar la primera sincronizacion.

## Offline 2 - Escritura local

1. Detener FastAPI con Ctrl+C.
2. Crear una tarea con un titulo identificable.
3. Iniciar una tarea existente.
4. Completar otra tarea.
5. Cerrar CheckTap sin cerrar sesion.
6. Abrir CheckTap desde el icono.

Criterios:

- Las acciones permanecen visibles.
- Las tarjetas muestran Pendiente.
- El contador de operaciones pendientes aumenta.
- No aparece perdida de datos despues de reiniciar la app.

Inspeccion opcional:

```bash
cd ~/Documents/checktap/system
./INSPECCIONAR_OFFLINE_DISPOSITIVO.sh
```

## Offline 3 - Recuperacion y sincronizacion

1. Mantener CheckTap abierta con operaciones pendientes.
2. Levantar FastAPI.
3. Pulsar Sincronizar o volver a primer plano.
4. Esperar que el contador llegue a cero.
5. Abrir otra sesion o consultar Swagger.

Criterios:

- Las operaciones llegan en el mismo orden.
- La tarea creada existe una sola vez.
- Los estados locales pasan a Sincronizado.
- El otro dispositivo observa los cambios.

## Offline 4 - Conflicto

1. Sincronizar una tarea en dos dispositivos.
2. Desconectar el dispositivo A.
3. Modificar la tarea desde el dispositivo B y sincronizar.
4. Modificar la copia antigua desde A.
5. Reconectar A.

Criterios:

- FastAPI detecta la version obsoleta.
- La tarjeta en A muestra Conflicto.
- No se sobrescribe silenciosamente el cambio del dispositivo B.
- Aceptar servidor elimina el aviso de conflicto.

La prueba automatica de backend se ejecuta con:

```bash
./VERIFICAR_OFFLINE_4.sh
```

## Offline 5 - Reintento y segundo plano

1. Crear una tarea offline.
2. Enviar CheckTap a segundo plano.
3. Levantar FastAPI y recuperar red.
4. Esperar o volver a abrir CheckTap.
5. Consultar la tarea en otro dispositivo.

Criterios:

- Al reanudar, CheckTap intenta sincronizar.
- Android registra trabajos de WorkManager.
- Una ejecucion repetida no duplica la tarea.

Inspeccion Android:

```bash
./VERIFICAR_OFFLINE_5.sh
```

## Aprobacion final

```text
[ ] Escrituras offline persisten
[ ] Cola local conserva el orden
[ ] Recuperacion de red sincroniza
[ ] Reintentos no duplican tareas
[ ] Conflictos son visibles
[ ] Segundo plano o reanudacion procesa pendientes
[ ] Dos dispositivos convergen al mismo estado
```
