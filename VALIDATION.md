# Validacion CheckTap 0.5.0

## Backend ejecutado

- Compilacion Python: aprobada.
- Pruebas pytest: 4 aprobadas.
- Migracion Alembic 0001 -> 0002: aprobada sobre base limpia.
- Endpoint de sincronizacion en vivo: aprobado.
- UUID generado por cliente: aprobado.
- Reintento de la misma operacion: aprobado sin duplicados.
- Version de tarea: 1 -> 2 -> 3 aprobada.
- Conflicto por version obsoleta: aprobado.
- Registro de usuario que completa: aprobado.

## Flutter

Se realizo revision estructural de fuentes y scripts. El entorno de construccion usado para preparar el parche no contiene Flutter, por lo que la compilacion definitiva debe ejecutarse en la computadora del proyecto con:

```bash
./VALIDAR_OFFLINE_2_A_5.sh
```

## Scripts

- `VERIFICAR_OFFLINE_2.sh`: estructura local, cola y flutter analyze.
- `VERIFICAR_OFFLINE_3.sh`: pruebas backend y servicios de sincronizacion.
- `VERIFICAR_OFFLINE_4.sh`: servidor temporal, migracion y prueba viva de idempotencia/conflicto.
- `VERIFICAR_OFFLINE_5.sh`: dependencias, segundo plano e inspeccion ADB.
- `INSPECCIONAR_OFFLINE_DISPOSITIVO.sh`: extrae y consulta SQLite de una app debug.

## CheckTap v0.6

- `pytest`: 6 pruebas aprobadas.
- Validaciones de usuario y tarea: aprobadas.
- Permisos de tarea: aprobados.
- Operacion offline `UPDATE_TASK`: aprobada.
- Administracion de usuarios: aprobada.
- Informe PDF: aprobado.

Ejecutar:

```bash
./VALIDAR_ESTABILIZACION_V0_6.sh
```
