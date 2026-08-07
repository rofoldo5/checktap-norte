# CheckTap v0.11.0 - Checklists y permiso de notificaciones

## Alcance

Cada tarea puede contener uno o varios checklists. Cada checklist contiene un unico nivel de actividades verificables. Las actividades guardan autor, estado, persona que completo y fecha de finalizacion.

Completar todas las actividades no completa automaticamente la tarea principal. La tarea se cierra mediante su accion normal.

## Notificaciones

Cuando un checklist pasa de incompleto a completo, el backend genera un solo aviso para todos los dispositivos activos de los miembros del departamento. Marcar actividades individuales no genera avisos masivos.

Despues de un inicio de sesion exitoso, la app solicita automaticamente al sistema operativo el permiso de notificaciones. Android e iOS siempre conservan la decision final del usuario: la app puede abrir la solicitud, pero no conceder el permiso sin confirmacion.

## API

- `POST /api/v1/tasks/{task_id}/checklists`
- `PATCH /api/v1/tasks/{task_id}/checklists/{checklist_id}`
- `DELETE /api/v1/tasks/{task_id}/checklists/{checklist_id}`
- `POST /api/v1/tasks/{task_id}/checklists/{checklist_id}/items`
- `PATCH /api/v1/tasks/{task_id}/checklists/{checklist_id}/items/{item_id}`
- `DELETE /api/v1/tasks/{task_id}/checklists/{checklist_id}/items/{item_id}`
- `POST /api/v1/tasks/{task_id}/checklists/{checklist_id}/items/{item_id}/state`
- `POST /api/v1/tasks/{task_id}/checklists/{checklist_id}/state`

Todas las rutas requieren autenticacion y membresia/permisos sobre la tarea.

## Offline y conflictos

Las mutaciones se guardan primero en SQLite y se agregan a la cola de sincronizacion con identificadores UUID. El servidor conserva idempotencia mediante `processed_operations`. Cada cambio incrementa la version de la tarea; las operaciones posteriores actualizan su version base al sincronizar.

## Base de datos

La migracion `0005_task_checklists` agrega:

- `task_checklists`
- `task_checklist_items`

La migracion es aditiva y no elimina tareas, usuarios, departamentos ni asignaciones existentes.

En iOS, el cliente espera brevemente a que APNs entregue su token antes de pedir el token FCM. Si todavia no esta disponible, `onTokenRefresh` completa el registro posteriormente sin bloquear el acceso a la app.
