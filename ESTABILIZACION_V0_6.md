# CheckTap v0.6 - Estabilizacion funcional

## Incluido

- Validacion normalizada de nombres, titulos y campos nulos.
- Permisos de backend para editar, iniciar, completar y reabrir tareas.
- Detalle completo de tareas en Flutter.
- Edicion offline de titulo, descripcion, prioridad y responsable.
- Operacion sincronizable `UPDATE_TASK` con control de version.
- Administracion de usuarios para administradores.
- Activacion, desactivacion, cambio de rol y cambio de contrasena.
- Generacion y comparticion del informe PDF desde Flutter.
- Migracion SQLite local de version 5 a 6.

## Politica de permisos

| Accion | Permitido |
|---|---|
| Consultar tareas | Cualquier usuario autenticado |
| Crear tareas | Cualquier usuario autenticado |
| Editar o reasignar | Creador o administrador |
| Iniciar o completar | Responsable, creador o administrador |
| Reabrir | Creador o administrador |
| Administrar usuarios | Administrador |

## Verificacion

```bash
./VALIDAR_ESTABILIZACION_V0_6.sh
```

## Prueba manual

1. Iniciar sesion como administrador.
2. Abrir una tarea y editar sus datos.
3. Apagar FastAPI, editar otra tarea y confirmar que queda pendiente.
4. Levantar FastAPI y sincronizar.
5. Crear un usuario desde el menu Usuarios.
6. Iniciar sesion con el nuevo usuario y comprobar los permisos.
7. Abrir Informe diario, seleccionar fecha y compartir el PDF.
