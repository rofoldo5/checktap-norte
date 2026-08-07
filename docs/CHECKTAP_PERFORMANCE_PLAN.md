# Plan de rendimiento móvil CheckTap

## Objetivos

| Métrica | Objetivo |
|---|---:|
| Renderizado | 60 fps; p95 de build y raster < 16.67 ms |
| Entrada de texto local | < 50 ms percibidos; máximo 100 ms |
| Arranque en frío | < 2 s en dispositivo medio |
| Creación local de tarea | respuesta visual inmediata, sin esperar red |
| Memoria | sin crecimiento continuo tras 20 ciclos de navegación |

## Instrumentación incorporada

- `PerformanceMonitor` informa promedio, p95 y fotogramas sobre presupuesto en
  debug/profile cada 120 fotogramas.
- `integration_test/ui_performance_test.dart` desplaza una lista de 120 tareas y
  genera datos de timeline.
- `--trace-startup` produce métricas de arranque reproducibles.
- Las listas utilizan constructores perezosos y las tarjetas están aisladas con
  `RepaintBoundary`.
- La búsqueda es local y usa debounce; no dispara solicitudes por tecla.

## Perfilado

1. Ejecutar en modo `profile`, nunca en `debug` para decidir rendimiento.
2. Abrir DevTools > Performance y registrar Inicio, Tareas y Detalle.
3. Abrir DevTools > Memory; tomar snapshot inicial y luego de 20 ciclos.
4. Identificar frames > 16.67 ms y revisar rebuilds/rasterización.
5. Registrar modelo de dispositivo, SO, versión de Flutter y commit.

## Resultados

El entorno que generó este parche no contiene Flutter ni un dispositivo móvil,
por lo que no se fabrican cifras. Los scripts anteriores generan el informe en
`validation_reports/` y deben ejecutarse en el equipo de desarrollo y en al
menos un dispositivo de gama baja antes de liberar.
