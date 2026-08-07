# QA móvil CheckTap

## Automatización

```bash
./scripts/run_mobile_qa.sh
./scripts/run_mobile_performance_test.sh
API_BASE_URL=http://192.168.30.51:8082 ./scripts/profile_mobile_startup.sh
```

## Lista manual mínima

### Teléfonos objetivo

- Android 6–8, 2 GB RAM, pantalla 360 × 640.
- Android 11–13, pantalla 360 × 800.
- Android 14–16, pantalla 412 × 915.
- iPhone SE (2.ª/3.ª generación).
- iPhone 13/14/15.
- Tablet Android de 8–11 pulgadas.

### Flujos

- Inicio de sesión válido, inválido y servidor no disponible.
- Teclado abierto en todos los formularios; botones siempre visibles.
- Crear tarea, doble toque rápido y validación de campos vacíos.
- Cambiar departamento y filtrar estados.
- Buscar con 500+ tareas sin llamadas de red por pulsación.
- Abrir, iniciar, completar y reabrir una tarea.
- Crear/editar usuarios y departamentos.
- Descargar/compartir informe.
- Activar notificaciones y ejecutar prueba local/servidor.
- Crear y completar tareas sin red; recuperar red y verificar sincronización.
- Forzar conflicto de versión y comprobar mensaje comprensible.
- Cerrar y reabrir la aplicación con sesión offline.

### Accesibilidad

- Escala de texto 100 %, 130 % y 200 %.
- TalkBack/VoiceOver: recorrido y etiquetas de acciones críticas.
- Áreas táctiles mínimas de 48 × 48 dp.
- Contraste de chips, botones, errores y estados.
- No depender únicamente del color para comunicar prioridad o estado.
- Orientación vertical; revisar horizontal en formularios y tablet.

### Aprobación

No liberar si existe un error de `flutter analyze`, una excepción visual,
pérdida de datos offline, duplicación de tareas o un flujo sin posibilidad de
volver atrás.
