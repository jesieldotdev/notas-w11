"""Login do Google numa janela do próprio app (alternativa ao navegador).

Abre a página EmbeddedSetup e, quando o Google grava o cookie "oauth_token"
depois do login, entrega esse código (é o que vira o token do Keep).
A janela usa um perfil temporário: nada fica salvo nela.
"""

from PySide6.QtCore import QUrl, Signal
from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEnginePage
from PySide6.QtWebEngineWidgets import QWebEngineView

URL = "https://accounts.google.com/EmbeddedSetup"


class EmbeddedLogin(QWebEngineView):
    tokenFound = Signal(str)

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Entrar no Google Keep")
        self.resize(480, 680)
        self.profile = QWebEngineProfile(self)  # sem nome = temporário
        self.setPage(QWebEnginePage(self.profile, self))
        self.profile.cookieStore().cookieAdded.connect(self._cookie)
        self.setUrl(QUrl(URL))
        self._done = False

    def _cookie(self, cookie):
        if self._done or bytes(cookie.name().data()) != b"oauth_token":
            return
        self._done = True
        self.tokenFound.emit(bytes(cookie.value().data()).decode())
        self.close()
