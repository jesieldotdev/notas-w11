"""Login do Google para o Keep, num clique: "Entrar com o Google".

Abre a página de login do Google (EmbeddedSetup) numa janela do app. Quando
o login termina, o Google grava o cookie "oauth_token" — é ele que vira o
token do Keep. O e-mail é lido do campo que a pessoa preencheu na própria
página. A janela usa um perfil temporário: nada fica salvo nela.
"""

from PySide6.QtCore import QTimer, QUrl, Signal
from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineProfile
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import QInputDialog

URL = "https://accounts.google.com/EmbeddedSetup"

# e-mail digitado na página (tela "E-mail ou telefone") ou mostrado nas telas seguintes
READ_EMAIL = """
(function () {
    var f = document.querySelector('input[type=email], #identifierId');
    if (f && f.value) return f.value;
    var shown = document.querySelector('[data-email], [data-identifier]');
    if (shown) return shown.getAttribute('data-email') || shown.getAttribute('data-identifier');
    return '';
})();
"""


class EmbeddedLogin(QWebEngineView):
    loggedIn = Signal(str, str)   # e-mail, oauth_token
    cancelled = Signal()

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Entrar com o Google")
        self.resize(460, 640)
        self.profile = QWebEngineProfile(self)  # sem nome = temporário
        self.setPage(QWebEnginePage(self.profile, self))
        self.profile.cookieStore().cookieAdded.connect(self._cookie)
        self.email = ""
        self._done = False

        # vai guardando o e-mail enquanto a pessoa digita
        self.poll = QTimer(self)
        self.poll.setInterval(600)
        self.poll.timeout.connect(self._readEmail)
        self.poll.start()
        self.loadFinished.connect(lambda ok: self._readEmail())
        self.setUrl(QUrl(URL))

    def _readEmail(self):
        def got(value):
            if value and "@" in value:
                self.email = value.strip()
        self.page().runJavaScript(READ_EMAIL, 0, got)

    def _cookie(self, cookie):
        if self._done or bytes(cookie.name().data()) != b"oauth_token":
            return
        self._done = True
        self.poll.stop()
        token = bytes(cookie.value().data()).decode()
        email = self.email
        if not email:
            email, ok = QInputDialog.getText(self, "Entrar com o Google", "Qual o e-mail da conta que você usou?")
            if not ok or "@" not in email:
                self.close()
                return
        self.loggedIn.emit(email.strip(), token)
        self.close()

    def closeEvent(self, event):
        if not self._done:
            self.cancelled.emit()
        super().closeEvent(event)
