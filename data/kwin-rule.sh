#!/usr/bin/env bash
# Regra do KWin: as notas autoadesivas do notas-w11 ficam fora da barra de tarefas
# (são adesivos, não janelas do app) — fechar o app pela barra fecha só a lista.
#   kwin-rule.sh install | remove
set -euo pipefail
RC=kwinrulesrc
ID=notas-w11-adesivos

case "${1:-install}" in
install)
    kwriteconfig6 --file $RC --group $ID --key Description "notas-w11: adesivos fora da barra de tarefas"
    kwriteconfig6 --file $RC --group $ID --key wmclass "notas-w11"
    kwriteconfig6 --file $RC --group $ID --key wmclassmatch 1
    # toda janela do notas-w11 menos a lista "Notas Autoadesivas"
    kwriteconfig6 --file $RC --group $ID --key title '^(?!Notas Autoadesivas$).*'
    kwriteconfig6 --file $RC --group $ID --key titlematch 3
    kwriteconfig6 --file $RC --group $ID --key skiptaskbar true
    kwriteconfig6 --file $RC --group $ID --key skiptaskbarrule 2
    rules=$(kreadconfig6 --file $RC --group General --key rules)
    case ",$rules," in *",$ID,"*) ;; *) rules="${rules:+$rules,}$ID" ;; esac
    kwriteconfig6 --file $RC --group General --key rules "$rules"
    kwriteconfig6 --file $RC --group General --key count "$(echo "$rules" | tr ',' '\n' | grep -c .)"
    ;;
remove)
    kwriteconfig6 --file $RC --group $ID --key Description --delete 2>/dev/null || true
    python3 - <<'PY'
import configparser, os
p = os.path.expanduser("~/.config/kwinrulesrc")
c = configparser.RawConfigParser(); c.optionxform = str; c.read(p)
if c.has_section("notas-w11-adesivos"): c.remove_section("notas-w11-adesivos")
if c.has_section("General"):
    rules = [r for r in c.get("General", "rules", fallback="").split(",") if r and r != "notas-w11-adesivos"]
    c.set("General", "rules", ",".join(rules)); c.set("General", "count", str(len(rules)))
with open(p, "w") as f: c.write(f, space_around_delimiters=False)
PY
    ;;
esac
qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
