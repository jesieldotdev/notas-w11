#!/usr/bin/env bash
# notas-w11 — as Notas Autoadesivas do Windows 11 no KDE Plasma, sincronizadas
# com o Google Keep (no celular: o app Google Keep e os widgets dele).
#
#   ./install.sh               instala (pede senha para as dependências)
#   ./install.sh --skip-deps   não instala dependências do sistema
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/notas-w11"
BIN="$HOME/.local/bin"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merro:\033[0m %s\n' "$*" >&2; exit 1; }
as_root() {
    if [ "$(id -u)" = 0 ]; then "$@"
    elif [ -t 0 ] && command -v sudo >/dev/null; then sudo "$@"   # no terminal: sudo
    else pkexec "$@"; fi                                           # sem terminal: janela de senha
}

if [ "${1:-}" != "--skip-deps" ]; then
    info "Dependências (PySide6 com WebEngine)"
    if command -v dnf >/dev/null; then
        as_root dnf -y -q install python3-pyside6 qt6-qtwebengine
    elif command -v pacman >/dev/null; then
        as_root pacman -S --needed --noconfirm pyside6 qt6-webengine python
    elif command -v apt-get >/dev/null; then
        as_root apt-get install -y python3-pyside6.qtquick python3-pyside6.qtwebenginewidgets python3-venv
    else
        echo "Distribuição desconhecida: instale o PySide6 (com WebEngine) e rode com --skip-deps."
    fi
fi
python3 -c "import PySide6.QtQuick, PySide6.QtWebEngineWidgets" 2>/dev/null || die "PySide6 (com WebEngine) não encontrado."

info "App e biblioteca do Keep (gkeepapi)"
mkdir -p "$DATA/app" "$BIN"
rm -rf "$DATA/app/notas_w11"
cp -r "$HERE/notas_w11" "$DATA/app/"
[ -x "$DATA/venv/bin/python" ] || python3 -m venv --system-site-packages "$DATA/venv"
"$DATA/venv/bin/pip" install -q --upgrade gkeepapi keyring

cat > "$BIN/notas-w11" <<SH
#!/bin/sh
# notas-w11 (ver $HERE)
PYTHONPATH="$DATA/app" exec "$DATA/venv/bin/python" -m notas_w11.app "\$@"
SH
chmod 755 "$BIN/notas-w11"

info "Atalho no menu e início automático"
mkdir -p "$HOME/.local/share/applications" "$HOME/.config/autostart"
sed "s|@BIN@|$BIN|g" "$HERE/data/notas-w11.desktop" > "$HOME/.local/share/applications/notas-w11.desktop"
# no início da sessão reabre as notas que estavam abertas, como no Windows
sed "s|@BIN@|$BIN|g; s|^Exec=.*|Exec=$BIN/notas-w11 --background|" "$HERE/data/notas-w11.desktop" \
    > "$HOME/.config/autostart/notas-w11.desktop"
kbuildsycoca6 >/dev/null 2>&1 || true

info "Adesivos fora da barra de tarefas (regra do KWin)"
bash "$HERE/data/kwin-rule.sh" install

info "Widget do Plasma (painel e área de trabalho)"
if kpackagetool6 -t Plasma/Applet -s org.kde.notasw11 >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -u "$HERE/plasmoid/org.kde.notasw11" >/dev/null
else
    kpackagetool6 -t Plasma/Applet -i "$HERE/plasmoid/org.kde.notasw11" >/dev/null
fi

info "Pronto."
echo "  • Abra \"Notas Autoadesivas\" pelo menu e entre com a conta Google (uma vez só)."
echo "  • Widget: botão direito no painel ou na área de trabalho › Adicionar widgets › Notas Autoadesivas."
echo "  • No celular: o app Google Keep (as notas são as mesmas, com os widgets dele)."
