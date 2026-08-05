#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

for required in backend mobile deploy scripts; do
  if [ ! -d "$required" ]; then
    echo "ERROR: No se encontro la carpeta '$required'."
    echo "Ejecuta este script desde la raiz del proyecto o pasa la ruta como argumento."
    exit 1
  fi
done

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="backups/rebrand_checktap_${STAMP}"
mkdir -p "$BACKUP_DIR"

echo "Creando respaldo en $BACKUP_DIR/project_before_rebrand.tar.gz ..."
tar -czf "$BACKUP_DIR/project_before_rebrand.tar.gz" \
  --exclude='./backups' \
  --exclude='./backend/.venv' \
  --exclude='./backend/__pycache__' \
  --exclude='./backend/.pytest_cache' \
  --exclude='./backend/.ruff_cache' \
  --exclude='./mobile/.dart_tool' \
  --exclude='./mobile/build' \
  --exclude='./mobile/android/.gradle' \
  --exclude='./mobile/ios/Pods' \
  .

python3 - <<'PY'
from __future__ import annotations

from pathlib import Path

root = Path.cwd()
excluded_files = {
    "APLICAR_CAMBIO_NOMBRE_CHECKTAP.sh",
    "MIGRAR_POSTGRES_A_CHECKTAP.sh",
    "VERIFICAR_CHECKTAP.sh",
    "APLICAR.md",
}

excluded_dirs = {
    ".git",
    ".venv",
    ".dart_tool",
    ".gradle",
    "build",
    "Pods",
    "ephemeral",
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    "backups",
}

replacements = (
    ("com.sistemasnorte.taskflow", "com.sistemasnorte.checktap"),
    ("TaskFlowApp", "CheckTapApp"),
    ("TASKFLOW", "CHECKTAP"),
    ("TaskFlow", "CheckTap"),
    ("Taskflow", "CheckTap"),
    ("taskflow", "checktap"),
)

changed: list[str] = []
for path in root.rglob("*"):
    if not path.is_file():
        continue
    if path.name in excluded_files:
        continue
    if any(part in excluded_dirs for part in path.parts):
        continue
    try:
        raw = path.read_bytes()
    except OSError:
        continue
    if b"\x00" in raw:
        continue
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        continue

    updated = text
    for old, new in replacements:
        updated = updated.replace(old, new)

    # Nombre visible correcto en Android e iOS.
    if path.as_posix().endswith("mobile/android/app/src/main/AndroidManifest.xml"):
        updated = updated.replace('android:label="checktap"', 'android:label="CheckTap"')
    if path.as_posix().endswith("mobile/ios/Runner/Info.plist"):
        updated = updated.replace("<string>checktap</string>", "<string>CheckTap</string>")

    if updated != text:
        path.write_text(updated, encoding="utf-8")
        changed.append(str(path.relative_to(root)))

# Renombrar el paquete Kotlin de Android.
old_kotlin = root / "mobile/android/app/src/main/kotlin/com/sistemasnorte/taskflow"
new_kotlin = root / "mobile/android/app/src/main/kotlin/com/sistemasnorte/checktap"
if old_kotlin.exists():
    new_kotlin.parent.mkdir(parents=True, exist_ok=True)
    if new_kotlin.exists():
        for source in old_kotlin.rglob("*"):
            if source.is_file():
                target = new_kotlin / source.relative_to(old_kotlin)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read_bytes())
        for source in sorted(old_kotlin.rglob("*"), reverse=True):
            if source.is_file():
                source.unlink()
            elif source.is_dir():
                source.rmdir()
        old_kotlin.rmdir()
    else:
        old_kotlin.rename(new_kotlin)

# Renombrar archivos tecnicos que todavia contienen el nombre anterior.
renames = (
    (root / "mobile/android/taskflow_android.iml", root / "mobile/android/checktap_android.iml"),
    (root / "backend/taskflow.db", root / "backend/checktap.db"),
)
for old, new in renames:
    if old.exists() and not new.exists():
        old.rename(new)

print(f"Archivos de texto actualizados: {len(changed)}")
for item in changed:
    print(f"  - {item}")
PY

# Eliminar artefactos generados que pueden conservar el namespace anterior.
rm -rf \
  mobile/.dart_tool \
  mobile/build \
  mobile/android/.gradle \
  mobile/ios/Pods \
  mobile/ios/Flutter/ephemeral \
  backend/.pytest_cache \
  backend/.ruff_cache
find backend -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find backend -type f -name '*.pyc' -delete 2>/dev/null || true

cat <<'MSG'

Cambio de nombre aplicado al codigo fuente.

Nombre visible:          CheckTap
Paquete Flutter:         checktap
Android applicationId:  com.sistemasnorte.checktap
iOS bundle identifier:  com.sistemasnorte.checktap
Backend/Swagger:         CheckTap
Administrador local:    admin@checktap.com

IMPORTANTE:
La configuracion ahora usa la base, usuario y contenedor CheckTap.
Para conservar los datos existentes, ejecuta a continuacion:

  ./MIGRAR_POSTGRES_A_CHECKTAP.sh

No levantes FastAPI antes de completar esa migracion.
MSG
