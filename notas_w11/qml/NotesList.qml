/*
    A lista "Notas Autoadesivas", como no Windows 11: "+" para nota nova,
    pesquisa e os cartões das notas (com a cor, o começo do texto e quando
    foi editada). Também é onde fica o login do Google Keep.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "colors.js" as Palette

Window {
    id: list

    required property int revision
    width: 380
    height: 620
    minimumWidth: 300
    minimumHeight: 360
    title: "Notas Autoadesivas"
    color: "#202020"

    readonly property bool needsLogin: notas.status === "login"
    property string filter: ""

    function showAndRaise() {
        visible = true;
        raise();
        requestActivate();
        enterAnim.restart();
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: shift; property: "y"; from: 16; to: 0; duration: 240; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        transform: Translate { id: shift }

        // ── cabeçalho ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Notas Autoadesivas"; font.pointSize: 15; font.weight: Font.DemiBold; color: "white"; Layout.fillWidth: true }
            ToolButton { text: "＋"; font.pixelSize: 18; ToolTip.text: "Nova nota"; ToolTip.visible: hovered; onClicked: notas.newNote("", false) }
            ToolButton { text: "☑"; font.pixelSize: 16; ToolTip.text: "Nova lista de tarefas"; ToolTip.visible: hovered; onClicked: notas.newNote("", true) }
            ToolButton { text: "⟳"; font.pixelSize: 16; ToolTip.text: "Sincronizar agora"; ToolTip.visible: hovered; enabled: notas.status !== "login"; onClicked: notas.syncNow() }
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Pesquisar…"
            visible: !list.needsLogin
            onTextChanged: list.filter = text.toLowerCase()
        }

        // ── login do Google Keep ───────────────────────────────────────────
        LoginPanel {
            visible: list.needsLogin
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ── as notas ───────────────────────────────────────────────────────
        ListView {
            id: cards
            visible: !list.needsLogin
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: notas.model
            ScrollBar.vertical: ScrollBar {}
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 150 } }

            delegate: Item {
                id: cardItem
                required property string noteId
                required property string title
                required property string text
                required property string color
                required property bool pinned
                required property bool archived
                required property bool isList
                required property var items
                required property real updated
                required property int index

                readonly property string preview: isList
                    ? items.map(i => (i.checked ? "☑ " : "☐ ") + i.text).join("\n") : text
                readonly property bool matches: !archived && (list.filter.length === 0
                    || (title + "\n" + preview).toLowerCase().indexOf(list.filter) >= 0)

                width: ListView.view.width
                height: matches ? cardRect.height : 0
                visible: matches

                // entra deslizando um pouco, um depois do outro
                Component.onCompleted: { cardRect.opacity = 0; appear.start(); }
                SequentialAnimation {
                    id: appear
                    PauseAnimation { duration: Math.max(0, Math.min(cardItem.index, 8)) * 30 }
                    ParallelAnimation {
                        NumberAnimation { target: cardRect; property: "opacity"; to: 1; duration: 180 }
                        NumberAnimation { target: cardShift; property: "y"; from: 10; to: 0; duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    id: cardRect
                    width: parent.width
                    height: cardColumn.implicitHeight + 20
                    radius: 6
                    color: cardMouse.containsMouse ? Qt.lighter(Palette.body(cardItem.color), 1.12) : Palette.body(cardItem.color)
                    clip: true
                    transform: Translate { id: cardShift }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle { width: parent.width; height: 4; color: Palette.bar(cardItem.color) }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notas.openNote(cardItem.noteId)
                    }

                    ColumnLayout {
                        id: cardColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        anchors.topMargin: 12
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: (cardItem.pinned ? "📌 " : "") + (cardItem.title || "")
                                visible: text.length > 0
                                color: "white"; font.weight: Font.DemiBold; elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: true; visible: !cardItem.title && !cardItem.pinned }
                            Label { text: Palette.when(cardItem.updated); color: Qt.rgba(1, 1, 1, 0.55); font.pointSize: 8 }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: cardItem.preview || "Nota vazia"
                            color: Qt.rgba(1, 1, 1, cardItem.preview ? 0.85 : 0.45)
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: notas.model.count === 0
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Qt.rgba(1, 1, 1, 0.6)
                text: "Nenhuma nota ainda.\nClique em ＋ para criar a primeira."
            }
        }

        // ── estado da sincronia ────────────────────────────────────────────
        Label {
            Layout.fillWidth: true
            text: (notas.status === "syncing" ? "⟳ " : notas.status === "ok" ? "✓ " : notas.status === "offline" ? "⚠ " : "") + notas.statusMessage
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pointSize: 8
            elide: Text.ElideRight
        }
    }
}
