# Pruebas manuales - recurrencia y recordatorios

## 1. Tarea diaria
1. Crear una tarea con un checklist y al menos dos subchecks.
2. Elegir `Todos los días`.
3. Elegir una hora cercana para la prueba.
4. Activar `Notificar a los responsables` y `A la hora programada`.
5. Sincronizar.
6. Confirmar que la tarjeta muestra el icono de repetición y de notificación.
7. Confirmar que el detalle muestra Programación, Primera/Próxima ejecución y Recordatorio.

## 2. Cada 15 días
1. Crear una tarea con `Cada 15 días`.
2. Confirmar en detalle que se muestra `Cada 15 días`.
3. Confirmar en API que `recurrence_type=CUSTOM`, `recurrence_interval=15` y `recurrence_unit=DAYS`.

## 3. Personalizado
Probar al menos:
- cada 2 días;
- cada 2 semanas;
- cada 3 meses.

## 4. Checklist heredado
1. Crear una tarea recurrente maestra.
2. Agregar un checklist con varios subchecks.
3. Completar algunos o todos en la ejecución actual.
4. Cuando el scheduler genere la siguiente ocurrencia, confirmar que el nuevo registro contiene los mismos títulos pero todos los subchecks comienzan pendientes.
5. Confirmar que la ejecución anterior conserva sus resultados.

## 5. Edición de serie
1. Editar la tarea maestra y cambiar frecuencia/hora.
2. Confirmar que la próxima ejecución se recalcula.
3. Abrir una ocurrencia generada e intentar editarla.
4. Confirmar que la programación aparece como solo lectura.

## 6. Mensual día 31
1. Configurar una tarea mensual iniciando el día 31.
2. Validar que febrero utiliza el último día disponible.
3. Validar que marzo vuelve al día 31.

## 7. Recordatorio offline
1. Con conexión, crear/sincronizar una tarea recurrente con aviso próximo.
2. Cerrar la app.
3. Cortar Wi-Fi/datos antes de la hora del aviso.
4. Confirmar que Android muestra el recordatorio local.
5. Restablecer conexión y confirmar que la app sincroniza normalmente.

## 8. Cierre de sesión
1. Sincronizar una tarea con un recordatorio futuro.
2. Cerrar sesión.
3. Confirmar que los recordatorios locales pendientes de esa sesión se eliminan.

## 9. Reinicio del teléfono
1. Programar un aviso futuro.
2. Reiniciar el dispositivo.
3. Confirmar que el aviso sigue programado y se muestra a la hora prevista.

## 10. Permiso de alarma exacta
En Android compatible, si el sistema solicita acceso para alarmas exactas, concederlo y verificar puntualidad. Repetir denegando el permiso: la app debe continuar funcionando usando el modo inexacto, sin bloquear la creación de la tarea.
