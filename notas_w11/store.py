"""Notas do Google Keep, com cópia local.

A conexão com o Keep (gkeepapi, não oficial) fica numa linha de execução só
dela (KeepWorker), porque a biblioteca não é segura entre threads. A interface
manda pedidos por sinais e recebe de volta "fotos" das notas (dicionários
simples). Depois de cada sincronização o estado inteiro vai para o disco:
o app abre na hora e funciona sem internet; nada se perde se a Google mudar
algo na API.
"""

import json
import os
import time
import uuid

import gkeepapi
from gkeepapi import node
from PySide6.QtCore import (QAbstractListModel, QByteArray, QModelIndex, QObject,
                            QThread, QTimer, Qt, Signal, Slot, Property)

from . import credentials, paths

# Cores do Keep na ordem da paleta dele
COLORS = ["DEFAULT", "RED", "ORANGE", "YELLOW", "GREEN", "TEAL", "BLUE",
          "CERULEAN", "PURPLE", "PINK", "BROWN", "GRAY"]


def snapshot(n):
    """Uma nota como dicionário simples (o que a interface e o widget usam)."""
    is_list = isinstance(n, node.List)
    items = []
    if is_list:
        items = [{"id": i.id, "text": i.text, "checked": bool(i.checked)}
                 for i in n.items if not i.deleted]
    updated = n.timestamps.updated.timestamp() if n.timestamps.updated else 0
    return {
        "id": n.id,
        "title": n.title or "",
        "text": n.text if not is_list else "",
        "color": n.color.value if n.color else "DEFAULT",
        "pinned": bool(n.pinned),
        "archived": bool(n.archived),
        "isList": is_list,
        "items": items,
        "updated": updated,
    }


class KeepWorker(QObject):
    """Dona do objeto gkeepapi.Keep: tudo que toca nele roda aqui."""

    notesReady = Signal(list)          # lista de snapshots
    statusChanged = Signal(str, str)   # estado ("offline", "syncing", "ok", "error", "login"), mensagem
    created = Signal(str)              # id da nota nova (para abrir a janela dela)

    def __init__(self):
        super().__init__()
        self.keep = gkeepapi.Keep()
        self.email = None
        self.ready = False   # autenticado
        self.dirty = False

    # ── início ─────────────────────────────────────────────────────────────
    @Slot()
    def start(self):
        self.syncTimer = QTimer(self)
        self.syncTimer.setSingleShot(True)
        self.syncTimer.timeout.connect(self.sync)
        self.periodic = QTimer(self)
        self.periodic.setInterval(120_000)
        self.periodic.timeout.connect(self.sync)

        state = None
        try:
            with open(paths.state_file()) as f:
                state = json.load(f)
            self.keep.restore(state)      # mostra as notas na hora, mesmo sem internet
            self._publish()
        except (OSError, ValueError):
            self._publish()  # sem cópia local: publica a lista vazia (fecha janelas de notas que não existem)

        creds = credentials.load()
        if not creds:
            self.statusChanged.emit("login", "Entre com sua conta Google para sincronizar com o Keep.")
            return
        self._authenticate(creds["email"], creds["token"], state)

    def _authenticate(self, email, token, state=None):
        self.email = email
        self.statusChanged.emit("syncing", "Conectando ao Google Keep…")
        try:
            self.keep.authenticate(email, token, state=state, sync=True, device_id=paths.device_id())
            self.ready = True
            self._saveState()
            self._publish()
            self.statusChanged.emit("ok", f"Sincronizado com {email}")
            self.periodic.start()
        except gkeepapi.exception.LoginException as e:
            self.statusChanged.emit("login", f"O Google recusou o login ({e}). Entre de novo.")
        except Exception as e:  # sem internet etc.: continua com a cópia local
            self.statusChanged.emit("offline", f"Sem conexão com o Keep: {e}")
            self.retryLogin = (email, token)
            QTimer.singleShot(60_000, lambda: self._authenticate(email, token, self.keep.dump()))

    @Slot(str, str)
    def login(self, email, oauthToken):
        """oauth_token da página EmbeddedSetup → master token do Keep (gpsoauth)."""
        import gpsoauth
        self.statusChanged.emit("syncing", "Conectando ao Google Keep…")
        try:
            res = gpsoauth.exchange_token(email, oauthToken, paths.device_id())
            token = res.get("Token")
            if not token:
                raise RuntimeError(res.get("Error", "resposta sem token"))
        except Exception as e:
            self.statusChanged.emit("login", f"Não foi possível entrar: {e}")
            return
        credentials.save(email, token)
        # leva junto o que já existe aqui (notas criadas antes do login sobem na sincronia)
        self._authenticate(email, token, self.keep.dump())

    @Slot()
    def logout(self):
        credentials.clear()
        self.ready = False
        self.periodic.stop()
        self.statusChanged.emit("login", "Desconectado. As notas continuam neste computador.")

    # ── sincronia ──────────────────────────────────────────────────────────
    @Slot()
    def sync(self):
        if not self.ready:
            return
        self.statusChanged.emit("syncing", "Sincronizando…")
        try:
            self.keep.sync()
            self.dirty = False
            self._saveState()
            self._publish()
            self.statusChanged.emit("ok", f"Sincronizado com {self.email}")
        except Exception as e:
            self.statusChanged.emit("offline", f"Não sincronizou agora ({e}); tento de novo em instantes.")
            self.syncTimer.start(30_000)

    def _changed(self):
        """Depois de uma edição: salva a cópia local já e sincroniza em seguida."""
        self.dirty = True
        self._saveState()
        self._publish()
        self.syncTimer.start(2_000)

    def _saveState(self):
        try:
            paths.write_json(paths.state_file(), self.keep.dump())
        except Exception:
            pass

    def _publish(self):
        notes = [snapshot(n) for n in self.keep.all() if not n.trashed and not n.deleted]
        notes.sort(key=lambda n: (not n["pinned"], -n["updated"]))
        # o widget do Plasma lê este arquivo (só as notas ativas)
        paths.write_json(paths.feed_file(), {"notes": [n for n in notes if not n["archived"]],
                                             "updated": time.time()})
        self.notesReady.emit(notes)

    # ── edições ────────────────────────────────────────────────────────────
    @Slot(str, bool)
    def create(self, color, isList):
        n = self.keep.createList("", []) if isList else self.keep.createNote("", "")
        if color in COLORS:
            n.color = node.ColorValue(color)
        self._changed()
        self.created.emit(n.id)

    def _note(self, noteId):
        n = self.keep.get(noteId)
        return n if n and not n.deleted else None

    @Slot(str, str, str)
    def update(self, noteId, title, text):
        n = self._note(noteId)
        if not n:
            return
        if n.title != title:
            n.title = title
        if not isinstance(n, node.List) and n.text != text:
            n.text = text
        self._changed()

    @Slot(str, str)
    def setColor(self, noteId, color):
        n = self._note(noteId)
        if n and color in COLORS:
            n.color = node.ColorValue(color)
            self._changed()

    @Slot(str, bool)
    def setPinned(self, noteId, pinned):
        n = self._note(noteId)
        if n:
            n.pinned = pinned
            self._changed()

    @Slot(str)
    def trash(self, noteId):
        n = self._note(noteId)
        if n:
            n.trash()
            self._changed()

    # listas de tarefas
    @Slot(str, str, bool)
    def addItem(self, noteId, text, checked):
        n = self._note(noteId)
        if isinstance(n, node.List):
            n.add(text, checked, node.NewListItemPlacementValue.Bottom)
            self._changed()

    @Slot(str, str, str, bool)
    def setItem(self, noteId, itemId, text, checked):
        n = self._note(noteId)
        if isinstance(n, node.List):
            for i in n.items:
                if i.id == itemId:
                    if i.text != text:
                        i.text = text
                    if bool(i.checked) != checked:
                        i.checked = checked
            self._changed()

    @Slot(str, str)
    def removeItem(self, noteId, itemId):
        n = self._note(noteId)
        if isinstance(n, node.List):
            for i in n.items:
                if i.id == itemId:
                    i.delete()
            self._changed()


ROLES = ["noteId", "title", "text", "color", "pinned", "archived", "isList", "items", "updated"]


class NotesModel(QAbstractListModel):
    """As notas para o QML (lista de todas, janelas das notas)."""

    countChanged = Signal()

    def __init__(self):
        super().__init__()
        self._notes = []

    def roleNames(self):
        return {Qt.UserRole + i: QByteArray(r.encode()) for i, r in enumerate(ROLES)}

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._notes)

    def data(self, index, role):
        if not index.isValid() or role < Qt.UserRole:
            return None
        n = self._notes[index.row()]
        key = ROLES[role - Qt.UserRole]
        return n["id"] if key == "noteId" else n.get(key)

    def setNotes(self, notes):
        # troca as linhas sem recriar a lista inteira, para as animações não pularem
        old = {n["id"]: i for i, n in enumerate(self._notes)}
        if [n["id"] for n in notes] == [n["id"] for n in self._notes]:
            self._notes = notes
            if notes:
                self.dataChanged.emit(self.index(0), self.index(len(notes) - 1))
            return
        self.beginResetModel()
        self._notes = notes
        self.endResetModel()
        self.countChanged.emit()

    @Property(int, notify=countChanged)
    def count(self):
        return len(self._notes)

    def note(self, noteId):
        return next((n for n in self._notes if n["id"] == noteId), None)
