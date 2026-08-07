# Plan de corrección de incidencias móviles

## Clasificación

| Nivel | Ejemplo | Respuesta |
|---|---|---|
| P0 | pérdida de datos, bloqueo al abrir, autenticación inutilizable | detener despliegue, revertir parche, corregir y ejecutar suite completa |
| P1 | creación/edición imposible, sincronización duplicada, navegación rota | hotfix en 24 h, pruebas dirigidas y E2E del flujo |
| P2 | degradación visual, accesibilidad o rendimiento fuera de objetivo | incluir en el siguiente parche y añadir prueba de regresión |
| P3 | ajuste cosmético sin impacto operativo | agrupar en iteración de diseño |

## Flujo reproducible

1. Registrar versión de app, modelo, SO, red y departamento activo.
2. Adjuntar logs de Flutter y, cuando aplique, logs de `checktap-api`.
3. Crear una prueba que reproduzca el defecto antes de modificar código.
4. Corregir en el módulo responsable sin cambiar contratos API innecesariamente.
5. Ejecutar `./scripts/run_mobile_qa.sh`.
6. Para rendimiento, ejecutar en `profile` y comparar p95 de build/raster.
7. Validar manualmente offline, reconexión, teclado y lector de pantalla.
8. Generar parche reversible y documentar alcance.

## Umbrales de regresión

- No aceptar errores o advertencias nuevas de `flutter analyze --fatal-infos`.
- No aceptar frames p95 de build o raster superiores a 16.67 ms en el flujo medido.
- No aceptar incremento sostenido de memoria tras 20 ciclos de navegación.
- No aceptar doble creación por pulsación repetida.
- No aceptar pérdida o duplicación de operaciones offline.

## Reversión

Cada parche conserva los archivos anteriores en `.checktap_backups/`. Si aparece
una incidencia P0/P1, ejecutar el script de reversión del paquete, resolver
dependencias y reconstruir la aplicación con la versión estable anterior.
