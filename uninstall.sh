#!/usr/bin/env bash
# Remove o notas-w11. As notas continuam no Google Keep; a cópia local fica,
# a menos que se use --purge.
set -euo pipefail
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/notas-w11"
pgrep -f "python[0-9.]* -m notas_w11[.]app" | xargs -r kill 2>/dev/null || true
bash "$(dirname "$0")/data/kwin-rule.sh" remove 2>/dev/null || true
kpackagetool6 -t Plasma/Applet -r org.kde.notasw11 >/dev/null 2>&1 || true
rm -rf "$DATA/app" "$DATA/venv" "$HOME/.local/bin/notas-w11" \
       "$HOME/.local/share/applications/notas-w11.desktop" "$HOME/.config/autostart/notas-w11.desktop"
if [ "${1:-}" = "--purge" ]; then
    rm -rf "$DATA" "${XDG_CONFIG_HOME:-$HOME/.config}/notas-w11"
    python3 -c "import keyring; keyring.delete_password('notas-w11', 'google-keep')" 2>/dev/null || true
fi
kbuildsycoca6 >/dev/null 2>&1 || true
echo "notas-w11 removido."
