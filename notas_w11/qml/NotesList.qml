/*
    A lista "Notas Autoadesivas", no visual dos painéis do Windows 11:
    título e botões de ícone, pesquisa arredondada e cartões escuros com a
    faixa da cor da nota no topo. Também é onde fica o "Entrar com o Google".
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "colors.js" as Palette

Window {
    id: list

    required property int revision
    width: 380
    height: 640
    minimumWidth: 300
    minimumHeight: 380
    title: "Notas Autoadesivas"
    color: "#202020"

    readonly property bool needsLogin: notas.status === "login"
    property string filter: ""

    // camadas do Fluent (escuro)
    readonly property color layer: "#2b2b2b"
    readonly property color layerHover: "#323232"
    readonly property color stroke: Qt.rgba(1, 1, 1, 0.07)
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.62)

    function showAndRaise() {
        visible = true;
        raise();
        requestActivate();
        enterAnim.restart();
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: shift; property: "y"; from: 18; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 14
        spacing: 12
        transform: Translate { id: shift }

        // ── cabeçalho ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: "Notas Autoadesivas"
                font.pointSize: 16
                font.weight: Font.DemiBold
                color: "white"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            IconButton { iconName: "list-add"; tip: "Nova nota"; onClicked: notas.newNote("", false) }
            IconButton { iconName: "checkbox"; tip: "Nova lista de tarefas"; onClicked: notas.newNote("", true) }
            IconButton {
                iconName: "view-refresh"; tip: "Sincronizar agora"
                enabled: !list.needsLogin
                spinning: notas.status === "syncing"
                onClicked: notas.syncNow()
            }
        }

        // ── pesquisa ───────────────────────────────────────────────────────
        Rectangle {
            visible: !list.needsLogin
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 6
            color: search.activeFocus ? "#1c1c1c" : (searchHover.hovered ? "#323232" : list.layer)
            border.width: 1
            border.color: list.stroke
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: searchHover }
            Rectangle { // linha de baixo na cor de destaque ao digitar, como no Windows
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: search.activeFocus ? parent.width - 2 : 0
                height: 2
                radius: 1
                color: Kirigami.Theme.highlightColor
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            TextField {
                id: search
                anchors.fill: parent
                anchors.rightMargin: 34
                leftPadding: 12
                placeholderText: "Pesquisar…"
                placeholderTextColor: list.textSecondary
                color: "white"
                background: null
                onTextChanged: list.filter = text.toLowerCase()
                Keys.onEscapePressed: text = ""
            }
            Kirigami.Icon {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: search.text.length ? "edit-clear" : "search"
                color: list.textSecondary
                isMask: true
                MouseArea { anchors.fill: parent; enabled: search.text.length > 0; onClicked: search.text = "" }
            }
        }

        // ── "Entrar com o Google" ──────────────────────────────────────────
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
            spacing: 6
            model: notas.model
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
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

                width: ListView.view.width - 4
                height: matches ? cardRect.height : 0
                visible: matches

                // os cartões entram subindo, um depois do outro
                Component.onCompleted: { cardRect.opacity = 0; appear.start(); }
                SequentialAnimation {
                    id: appear
                    PauseAnimation { duration: Math.max(0, Math.min(cardItem.index, 8)) * 35 }
                    ParallelAnimation {
                        NumberAnimation { target: cardRect; property: "opacity"; to: 1; duration: 200 }
                        NumberAnimation { target: cardShift; property: "y"; from: 12; to: 0; duration: 240; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    id: cardRect
                    width: parent.width
                    height: cardColumn.implicitHeight + 26
                    radius: 8
                    color: cardHover.hovered ? list.layerHover : list.layer
                    border.width: 1
                    border.color: list.stroke
                    clip: true
                    transform: Translate { id: cardShift }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: cardHover }

                    // faixa da cor da nota no topo (com os cantos de cima arredondados)
                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 8
                        color: Palette.bar(cardItem.color)
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 4; color: cardRect.color }
                    }

                    TapHandler { onTapped: notas.openNote(cardItem.noteId) }

                    ColumnLayout {
                        id: cardColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        anchors.topMargin: 14
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Kirigami.Icon {
                                visible: cardItem.pinned
                                Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                source: "pin"
                                color: Kirigami.Theme.highlightColor
                                isMask: true
                            }
                            Label {
                                Layout.fillWidth: true
                                text: cardItem.title
                                visible: text.length > 0
                                color: "white"
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: true; visible: !cardItem.title }
                            Label {
                                text: Palette.when(cardItem.updated)
                                color: list.textSecondary
                                font.pointSize: 8
                                opacity: cardHover.hovered ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: cardItem.preview || "Nota vazia"
                            color: cardItem.preview ? Qt.rgba(1, 1, 1, 0.86) : list.textSecondary
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            lineHeight: 1.1
                        }
                    }

                    // ⋯ no hover (no lugar da data)
                    IconButton {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 8
                        anchors.rightMargin: 6
                        small: true
                        iconName: "overflow-menu-horizontal"
                        fallbackIcon: "view-more-horizontal-symbolic"
                        tip: "Mais opções"
                        opacity: cardHover.hovered || cardMenu.visible ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        onClicked: cardMenu.popup()
                    }

                    Menu {
                        id: cardMenu
                        MenuItem { text: "Abrir nota"; icon.name: "document-open"; onTriggered: notas.openNote(cardItem.noteId) }
                        MenuItem {
                            text: cardItem.pinned ? "Desafixar" : "Fixar no topo"
                            icon.name: "pin"
                            onTriggered: notas.setPinned(cardItem.noteId, !cardItem.pinned)
                        }
                        Menu {
                            title: "Cor"
                            Repeater {
                                model: notas.colors
                                MenuItem {
                                    required property string modelData
                                    text: Palette.name(modelData)
                                    checkable: true
                                    checked: cardItem.color === modelData
                                    onTriggered: notas.setColor(cardItem.noteId, modelData)
                                }
                            }
                        }
                        MenuSeparator {}
                        MenuItem { text: "Excluir nota"; icon.name: "edit-delete"; onTriggered: notas.trash(cardItem.noteId) }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: notas.model.count === 0
                spacing: 8
                Kirigami.Icon { anchors.horizontalCenter: parent.horizontalCenter; width: 48; height: 48; source: "knotes" }
                Label {
                    width: cards.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: list.textSecondary
                    text: "Nenhuma nota ainda.\nClique em + para criar a primeira."
                }
            }
        }

        // ── estado da sincronia ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Kirigami.Icon {
                Layout.preferredWidth: 14; Layout.preferredHeight: 14
                source: notas.status === "ok" ? "checkmark" : notas.status === "offline" ? "network-disconnect"
                        : notas.status === "syncing" ? "view-refresh" : "im-user-offline"
                color: notas.status === "offline" ? "#fce100" : list.textSecondary
                isMask: true
            }
            Label {
                Layout.fillWidth: true
                text: notas.statusMessage
                color: list.textSecondary
                font.pointSize: 8
                elide: Text.ElideRight
            }
        }
    }

    // botão de ícone do Fluent: quadrado arredondado que acende no hover
    component IconButton: AbstractButton {
        id: ib
        property string iconName
        property string fallbackIcon: ""
        property string tip
        property bool small: false
        property bool spinning: false
        implicitWidth: small ? 28 : 34
        implicitHeight: small ? 28 : 34
        hoverEnabled: true
        opacity: enabled ? 1 : 0.4
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: ib.small ? 16 : 18
                height: width
                source: ib.iconName
                fallback: ib.fallbackIcon
                color: "white"
                isMask: true
                RotationAnimation on rotation { running: ib.spinning; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
            }
        }
        background: Rectangle {
            radius: 5
            color: Qt.rgba(1, 1, 1, ib.down ? 0.04 : (ib.hovered ? 0.08 : 0))
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        ToolTip.text: tip
        ToolTip.visible: hovered && tip.length > 0
        ToolTip.delay: 600
    }
}
