# Mantenimiento del sistema visual

- Agregar colores únicamente en `ui/theme/checktap_colors.dart`.
- Usar la escala de `CheckTapSpacing` y `CheckTapRadius`; evitar números aislados.
- Reutilizar componentes de `ui/components/` antes de crear variantes.
- No modificar el logo ni reemplazarlo por una imagen generada.
- Ningún componente visual debe llamar a Dio, SQLite o Firebase.
- Toda pantalla nueva debe cubrir carga, vacío, error, offline y guardado.
- Todo formulario debe bloquear doble envío y liberar sus controladores.
- Ejecutar `./scripts/run_mobile_qa.sh` antes de cada pull request.
