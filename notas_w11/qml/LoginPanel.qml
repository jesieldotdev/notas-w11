/*
    Login do Google Keep. Padrão: pelo navegador da pessoa (a página especial
    do Google grava o código "oauth_token" num cookie, que a pessoa copia e
    cola aqui, uma vez só). Alternativa: janela embutida, que pega sozinha.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: panel
    contentWidth: availableWidth

    ColumnLayout {
        width: panel.availableWidth
        spacing: 10

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: "white"
            font.pointSize: 12
            font.weight: Font.DemiBold
            text: "Sincronizar com o Google Keep"
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Qt.rgba(1, 1, 1, 0.75)
            text: "As notas ficam no Keep: no celular, use o app Google Keep (e os widgets dele). Isso é feito uma vez só."
        }

        TextField {
            id: email
            Layout.fillWidth: true
            placeholderText: "Seu e-mail do Google"
            inputMethodHints: Qt.ImhEmailCharactersOnly
        }

        // ── pelo navegador ─────────────────────────────────────────────────
        Label { text: "1. Entre no Google pelo navegador"; color: "white"; font.weight: Font.DemiBold; Layout.topMargin: 6 }
        Button {
            text: "Abrir a página de login do Google"
            highlighted: true
            onClicked: notas.openBrowserLogin()
        }
        Label { text: "2. Copie o código"; color: "white"; font.weight: Font.DemiBold; Layout.topMargin: 6 }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Qt.rgba(1, 1, 1, 0.75)
            textFormat: Text.StyledText
            text: "Depois de entrar (a página pode ficar carregando, tudo bem), aperte <b>F12</b> › "
                + "<b>Aplicativo</b> (Chrome) ou <b>Armazenamento</b> (Firefox) › <b>Cookies</b> › "
                + "<b>accounts.google.com</b> e copie o valor de <b>oauth_token</b> (começa com <i>oauth2_4/</i>)."
        }
        TextField {
            id: token
            Layout.fillWidth: true
            placeholderText: "Cole aqui o oauth_token"
            echoMode: TextInput.PasswordEchoOnEdit
        }
        Button {
            text: "Conectar"
            highlighted: true
            enabled: email.text.indexOf("@") > 0 && token.text.trim().length > 20 && notas.status !== "syncing"
            onClicked: notas.login(email.text, token.text)
        }

        // ── alternativa ────────────────────────────────────────────────────
        MenuSeparator { Layout.fillWidth: true; Layout.topMargin: 6 }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Qt.rgba(1, 1, 1, 0.6)
            text: "Ou entre numa janela do próprio app, que pega o código sozinha:"
        }
        Button {
            text: "Entrar numa janela do app"
            enabled: email.text.indexOf("@") > 0
            onClicked: notas.embeddedLogin(email.text)
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            visible: notas.statusMessage.length > 0
            color: notas.status === "login" ? "#ff99a4" : Qt.rgba(1, 1, 1, 0.7)
            text: notas.statusMessage
            Layout.topMargin: 8
        }
    }
}
