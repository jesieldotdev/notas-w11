/*
    Conectar ao Google Keep: um botão "Entrar com o Google", que abre a
    página de login do Google e conecta sozinho quando ela termina.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: panel

    readonly property bool busy: notas.status === "syncing" || notas.loginWindowOpen

    // entra subindo um pouco, como as outras telas
    Component.onCompleted: enter.start()
    ParallelAnimation {
        id: enter
        NumberAnimation { target: column; property: "opacity"; from: 0; to: 1; duration: 220 }
        NumberAnimation { target: shift; property: "y"; from: 14; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.min(parent.width, 320)
        spacing: 14
        transform: Translate { id: shift }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "🗒"
            font.pixelSize: 54
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: "white"
            font.pointSize: 13
            font.weight: Font.DemiBold
            text: "Suas notas em todo lugar"
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Qt.rgba(1, 1, 1, 0.7)
            text: "As notas ficam no Google Keep: no celular, é só usar o app do Keep (e os widgets dele)."
        }

        // botão no estilo "Entrar com o Google"
        AbstractButton {
            id: signIn
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            implicitWidth: 240
            implicitHeight: 42
            enabled: !panel.busy
            hoverEnabled: true
            onClicked: notas.signIn()
            scale: down ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            background: Rectangle {
                radius: 21
                color: signIn.hovered ? "#f1f3f4" : "white"
                opacity: signIn.enabled ? 1 : 0.6
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: RowLayout {
                spacing: 10
                Item { Layout.fillWidth: true }
                Label { text: "G"; font.pixelSize: 18; font.weight: Font.Bold; color: "#4285F4" }
                Label {
                    text: notas.loginWindowOpen ? "Termine o login na janela…" : "Entrar com o Google"
                    color: "#1f1f1f"
                    font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
            }
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: notas.status === "syncing"
            visible: running
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: notas.statusMessage.length > 0 && notas.status === "login" && notas.statusMessage.indexOf("Entre com") !== 0
            color: "#ff99a4"
            text: notas.statusMessage
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pointSize: 8
            text: "Você entra na página do próprio Google; a senha não passa pelo app. O acesso fica guardado no KWallet."
        }
    }
}
