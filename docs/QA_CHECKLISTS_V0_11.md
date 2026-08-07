# QA manual CheckTap v0.11.0

## Inicio de sesion y notificaciones

- [ ] Instalar la app en Android 13+ y limpiar permisos.
- [ ] Iniciar sesion y confirmar que el dialogo del sistema aparece automaticamente.
- [ ] Aceptar el permiso y confirmar registro del dispositivo.
- [ ] Rechazar el permiso en otra instalacion y confirmar que el login continua.
- [ ] Cerrar y abrir una sesion existente sin bloqueos ni solicitudes duplicadas.

## Checklists

- [ ] Crear un checklist sin actividades.
- [ ] Crear un checklist con varias actividades iniciales.
- [ ] Validar campos vacios y textos formados solo por espacios.
- [ ] Agregar, editar y eliminar una actividad.
- [ ] Marcar una actividad y comprobar persona y hora.
- [ ] Reabrir una actividad.
- [ ] Marcar el checkbox principal y confirmar antes de completar todo.
- [ ] Ocultar y mostrar actividades completadas.
- [ ] Completar todos los checklists y confirmar que la tarea principal sigue abierta.
- [ ] Completar la tarea y confirmar que los checklists quedan en lectura.
- [ ] Reabrir la tarea y confirmar que los checklists vuelven a ser editables.

## Equipo, offline y sincronizacion

- [ ] Marcar actividades con dos usuarios del mismo departamento.
- [ ] Confirmar actualizacion por WebSocket en el segundo dispositivo.
- [ ] Completar un checklist y recibir un unico aviso departamental.
- [ ] Confirmar que no llega un aviso masivo por cada actividad individual.
- [ ] Crear y completar actividades sin red.
- [ ] Recuperar red y confirmar sincronizacion sin duplicados.
- [ ] Simular edicion concurrente y comprobar tratamiento de conflicto.

## Informes

- [ ] Generar el PDF diario.
- [ ] Verificar progreso por checklist.
- [ ] Verificar actividades completadas, pendientes y actores.
- [ ] Descargar y compartir el informe desde un usuario autorizado.

## Accesibilidad

- [ ] Probar texto al 130%.
- [ ] Verificar lector de pantalla en checkbox principal e items.
- [ ] Confirmar areas tactiles de al menos 48 px.
- [ ] Probar pantalla pequena y teclado abierto.
