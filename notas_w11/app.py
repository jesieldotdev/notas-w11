"""notas-w11: as Notas Autoadesivas do Windows 11 no KDE Plasma, sincronizadas
com o Google Keep (no celular, o próprio app do Keep, com os widgets dele).

    notas-w11              abre a lista de notas
    notas-w11 --new        nota nova
    notas-w11 --open ID    abre a nota
    notas-w11 --background só reabre as notas que estavam abertas (início da sessão)

Uma instância só: chamar de novo manda o pedido para a que já está aberta.
"""

import json
import os
import sys

from PySide6.QtCore import (QCoreApplication, QObject, QSettings, QThread, QUrl, Qt,
                            Property, Signal, Slot)
from PySide6.QtGui import QIcon
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from .store import COLORS, KeepWorker, NotesModel

HERE = os.path.dirname(os.path.abspath(__file__))
SOCKET = f"notas-w11-{os.getuid()}"


class Notes(QObject):
    """O que o QML usa (objeto "notas")."""

    statusChanged = Signal()
    openNotesChanged = Signal()
    listRequested = Signal()
    loginRequested = Signal()
    # pedidos para a linha de execução do Keep
    _create = Signal(str, bool)
    _update = Signal(str, str, str)
    _setColor = Signal(str, str)
    _setPinned = Signal(str, bool)
    _trash = Signal(str)
    _addItem = Signal(str, str, bool)
    _setItem = Signal(str, str, str, bool)
    _removeItem = Signal(str, str)
    _login = Signal(str, str)
    _logout = Signal()
    _sync = Signal()

    def __init__(self):
        super().__init__()
        self._model = NotesModel()
        self._status = "offline"
        self._message = ""
        self.settings = QSettings("notas-w11", "notas-w11")
        self._open = [i for i in (self.settings.value("openNotes", []) or []) if i]
        if isinstance(self._open, str):
            self._open = [self._open]
        self._pendingOpen = None

        self.thread = QThread()
        self.worker = KeepWorker()
        self.worker.moveToThread(self.thread)
        self.thread.started.connect(self.worker.start)
        self.worker.notesReady.connect(self._onNotes)
        self.worker.statusChanged.connect(self._onStatus)
        self.worker.created.connect(self.openNote)
        for sig, slot in ((self._create, self.worker.create), (self._update, self.worker.update),
                          (self._setColor, self.worker.setColor), (self._setPinned, self.worker.setPinned),
                          (self._trash, self.worker.trash), (self._addItem, self.worker.addItem),
                          (self._setItem, self.worker.setItem), (self._removeItem, self.worker.removeItem),
                          (self._login, self.worker.login), (self._logout, self.worker.logout),
                          (self._sync, self.worker.sync)):
            sig.connect(slot)
        self.thread.start()

    # ── estado ─────────────────────────────────────────────────────────────
    def _onNotes(self, notes):
        self._model.setNotes(notes)
        # notas que sumiram (apagadas no celular) fecham a janela
        alive = {n["id"] for n in notes if not n["archived"]}
        still = [i for i in self._open if i in alive]
        if still != self._open:
            self._open = still
            self._saveOpen()

    def _onStatus(self, status, message):
        self._status, self._message = status, message
        self.statusChanged.emit()
        if status == "login":
            self.loginRequested.emit()

    @Property(QObject, constant=True)
    def model(self):
        return self._model

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=statusChanged)
    def statusMessage(self):
        return self._message

    @Property(list, constant=True)
    def colors(self):
        return COLORS

    @Property(list, notify=openNotesChanged)
    def openNotes(self):
        return self._open

    # ── janelas ────────────────────────────────────────────────────────────
    def _saveOpen(self):
        self.settings.setValue("openNotes", self._open)
        self.openNotesChanged.emit()

    @Slot(str)
    def openNote(self, noteId):
        if noteId and noteId not in self._open:
            self._open.append(noteId)
            self._saveOpen()

    @Slot(str)
    def closeNote(self, noteId):
        if noteId in self._open:
            self._open.remove(noteId)
            self._saveOpen()

    @Slot(str, result="QVariant")
    def note(self, noteId):
        return self._model.note(noteId)

    @Slot(str, result="QVariant")
    def geometry(self, noteId):
        g = self.settings.value(f"geometry/{noteId}")
        return json.loads(g) if g else None

    @Slot(str, int, int, int, int)
    def saveGeometry(self, noteId, x, y, w, h):
        self.settings.setValue(f"geometry/{noteId}", json.dumps([x, y, w, h]))

    @Slot()
    def showList(self):
        self.listRequested.emit()

    # ── edições (vão para a linha de execução do Keep) ─────────────────────
    @Slot(str, bool)
    def newNote(self, color="", isList=False):
        self._create.emit(color or "YELLOW", isList)

    @Slot(str, str, str)
    def update(self, noteId, title, text):
        self._update.emit(noteId, title, text)

    @Slot(str, str)
    def setColor(self, noteId, color):
        self._setColor.emit(noteId, color)

    @Slot(str, bool)
    def setPinned(self, noteId, pinned):
        self._setPinned.emit(noteId, pinned)

    @Slot(str)
    def trash(self, noteId):
        self.closeNote(noteId)
        self._trash.emit(noteId)

    @Slot(str, str, bool)
    def addItem(self, noteId, text, checked):
        self._addItem.emit(noteId, text, checked)

    @Slot(str, str, str, bool)
    def setItem(self, noteId, itemId, text, checked):
        self._setItem.emit(noteId, itemId, text, checked)

    @Slot(str, str)
    def removeItem(self, noteId, itemId):
        self._removeItem.emit(noteId, itemId)

    @Slot()
    def syncNow(self):
        self._sync.emit()

    # ── conta ──────────────────────────────────────────────────────────────
    @Slot(str, str)
    def login(self, email, oauthToken):
        self._login.emit(email.strip(), oauthToken.strip())

    loginWindowChanged = Signal()

    @Property(bool, notify=loginWindowChanged)
    def loginWindowOpen(self):
        return getattr(self, "_embedded", None) is not None

    @Slot()
    def signIn(self):
        """"Entrar com o Google": janela com o login do Google, que conecta sozinha ao terminar."""
        if getattr(self, "_embedded", None):
            self._embedded.raise_()
            self._embedded.activateWindow()
            return
        from .login import EmbeddedLogin
        self._embedded = EmbeddedLogin()
        self._embedded.loggedIn.connect(self.login)
        self._embedded.destroyed.connect(self._loginClosed)
        self._embedded.setAttribute(Qt.WA_DeleteOnClose)
        self._embedded.show()
        self.loginWindowChanged.emit()

    def _loginClosed(self):
        self._embedded = None
        self.loginWindowChanged.emit()

    @Slot()
    def logout(self):
        self._logout.emit()

    def shutdown(self):
        self.thread.quit()
        self.thread.wait(3000)


def handle_args(notes, args):
    if "--new" in args:
        notes.newNote("", False)
    elif "--open" in args:
        i = args.index("--open")
        if i + 1 < len(args):
            notes.openNote(args[i + 1])
    elif "--background" not in args:
        notes.showList()


def main():
    args = sys.argv[1:]

    # outra instância já aberta? manda os argumentos para ela e sai
    sock = QLocalSocket()
    sock.connectToServer(SOCKET)
    if sock.waitForConnected(300):
        sock.write(json.dumps(args).encode())
        sock.waitForBytesWritten(1000)
        return 0

    QCoreApplication.setAttribute(Qt.AA_ShareOpenGLContexts)  # para a janela de login (WebEngine)
    app = QApplication(sys.argv)
    app.setApplicationName("notas-w11")
    app.setApplicationDisplayName("Notas Autoadesivas")
    app.setDesktopFileName("notas-w11")
    app.setWindowIcon(QIcon.fromTheme("knotes", QIcon.fromTheme("note")))
    app.setQuitOnLastWindowClosed(False)  # fechar as notas não encerra a sincronia

    notes = Notes()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("notas", notes)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "qml", "Main.qml")))
    if not engine.rootObjects():
        return 1

    server = QLocalServer()
    QLocalServer.removeServer(SOCKET)
    server.listen(SOCKET)

    def on_connection():
        c = server.nextPendingConnection()
        if c.waitForReadyRead(1000):
            try:
                handle_args(notes, json.loads(bytes(c.readAll()).decode()))
            except ValueError:
                pass
        c.close()

    server.newConnection.connect(on_connection)
    handle_args(notes, args)
    rc = app.exec()
    notes.shutdown()
    return rc


if __name__ == "__main__":
    sys.exit(main())
