# CheckTap 0.14.0 - Tareas recurrentes y recordatorios

## Objetivo

Agregar programación de tareas periódicas sin perder el historial de ejecuciones ni los checklists/subchecks asociados.

## Funcionalidad incluida

- Frecuencia de tarea:
  - No repetir.
  - Todos los días.
  - Una vez a la semana.
  - Cada 15 días.
  - Una vez al mes.
  - Personalizado: cada N días, semanas o meses (1 a 365).
- Fecha de inicio y hora programada.
- Zona horaria IANA del dispositivo.
- Recordatorio a responsables:
  - A la hora programada.
  - 15 minutos antes.
  - 1 hora antes.
  - 1 día antes.
- Recordatorios locales Android almacenados por el sistema para que puedan dispararse aunque haya un corte temporal de red después de sincronizar la programación.
- Si Android permite alarmas exactas se usan; si no, CheckTap utiliza programación inexacta como respaldo.
- Reprogramación automática de los próximos avisos al sincronizar tareas.
- Limpieza de recordatorios pendientes al cerrar sesión.
- Hasta 48 avisos futuros locales, priorizados cronológicamente, para no monopolizar la cola de notificaciones del dispositivo.

## Historial y subchecks

La tarea original es la tarea maestra de la serie. El scheduler crea nuevas ejecuciones con un nuevo ID cuando llega cada fecha programada.

Cada nueva ejecución:

- conserva título, descripción, prioridad, departamento y responsables;
- copia todos los checklists existentes en la tarea maestra;
- copia todos los subchecks;
- reinicia cada subcheck como pendiente;
- comienza en estado PENDIENTE;
- mantiene `recurrence_series_id` para identificar la serie;
- conserva `scheduled_for` para saber a qué ejecución corresponde.

Las ejecuciones anteriores permanecen en la base de datos y no se sobrescriben. La programación sólo se edita desde la tarea maestra; una ejecución generada muestra la programación como solo lectura.

## Reglas mensuales

Si la tarea se programa para un día que no existe en un mes, se utiliza el último día disponible sin perder el día original como ancla. Ejemplo para una tarea iniciada el día 31:

- 31 enero
- 28/29 febrero
- 31 marzo
- 30 abril
- 31 mayo

## Backend

Se añadieron campos de recurrencia a `tasks` y un servicio de generación de ocurrencias.

El proyecto entregado no contiene el directorio de versiones de Alembic aunque sí contiene `alembic.ini`. Para no destruir ni recrear datos existentes, se agregó una migración de compatibilidad aditiva e idempotente que agrega únicamente las columnas e índices que falten al iniciar la API. El scheduler también verifica el esquema al arrancar.

El scheduler de Portainer ya existente es quien genera las nuevas ejecuciones. Debe desplegarse/reiniciarse junto con la API.

## Mobile / Android

Se agregó `TaskRecurrence` al modelo local y a la cola offline. La configuración viaja también en operaciones creadas sin conexión y se reconcilia al sincronizar.

Android incorpora los receivers de `flutter_local_notifications` para conservar notificaciones programadas después de reiniciar el dispositivo y declara los permisos necesarios para alarmas programadas.

Dependencias nuevas directas:

- `flutter_timezone: ^5.1.0`
- `timezone: ^0.11.1`

No se incluye un `pubspec.lock` modificado porque debe regenerarse con el Flutter/Dart instalado en el equipo de desarrollo:

```bash
cd mobile
flutter pub get
```

## Versión

- Backend/API: `0.14.0`
- Flutter: `0.14.0+17`
- Imagen Portainer por defecto: `0.14.0`

## Hotfix anterior incluido

`task_detail_screen.dart` conserva también el hotfix que evita que la barra de acciones inferior cubra el detalle y los subchecks. Por tanto, este paquete puede aplicarse directamente sobre el `system_rolln.zip` original sin aplicar primero el ZIP anterior.

## Validación realizada antes de empaquetar

Backend:

```text
29 passed
```

Se validaron, entre otros:

- cada 15 días;
- comportamiento mensual del día 31;
- API de creación con recurrencia y recordatorio;
- clonación de checklist/subchecks y reinicio de estados;
- bloqueo de edición de programación en ocurrencias históricas;
- migración de compatibilidad aditiva e idempotente.

En el entorno donde se preparó el parche no está instalado el SDK de Flutter/Dart, por lo que `flutter analyze` y `flutter test` deben ejecutarse en el equipo de desarrollo después de `flutter pub get`.

## Aplicación

Desde la carpeta extraída del parche:

```bash
sh APLICAR_CAMBIO.sh /ruta/a/checktap/system
```

El script crea un respaldo de cada archivo reemplazado dentro de:

```text
.checktap_backups/tareas_recurrentes_v0.14.0_YYYYMMDD_HHMMSS/
```

## Validación después de aplicar

```bash
cd /ruta/a/checktap/system/backend
PYTHONPATH=. pytest -q

cd ../mobile
flutter pub get
dart format lib test
flutter analyze --fatal-infos
flutter test
```

Luego reconstruir la imagen backend `0.14.0` y desplegar tanto `api` como `scheduler` antes de distribuir el APK `0.14.0+17`.
