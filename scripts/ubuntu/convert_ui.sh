#!/usr/bin/env bash
# Generate PySide6 UI Python files required before first run.
# main_window.py and media_rc.py are gitignored.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

UI_FILE="app/ui/core/MainWindow.ui"
PY_FILE="app/ui/core/main_window.py"
QRC_FILE="app/ui/core/media.qrc"
RCC_PY_FILE="app/ui/core/media_rc.py"

if ! command -v pyside6-uic >/dev/null 2>&1; then
    echo "ERROR: pyside6-uic not found. Activate venv and install PySide6 first."
    exit 1
fi

pyside6-uic "$UI_FILE" -o "$PY_FILE"
pyside6-rcc "$QRC_FILE" -o "$RCC_PY_FILE"

# Match convert_ui_to_py.bat import fix
sed -i 's/^import media_rc$/from app.ui.core import media_rc/' "$PY_FILE"

echo "UI codegen complete:"
echo "  $PY_FILE"
echo "  $RCC_PY_FILE"
