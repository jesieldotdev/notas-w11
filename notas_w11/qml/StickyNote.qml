/*
    Uma nota autoadesiva, como no Windows 11: janela sem moldura, colorida,
    com a barra de cima (+ nova, ⋯ menu, × fechar) que vira uma faixa fina
    quando a nota não está em foco. O texto vai para o Google Keep.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "colors.js" as Palette

Window {
    id: win

    property string noteId
    property int revision            // muda a cada atualização das notas
    readonly property var n: revision >= 0 ? notas.note(noteId) : null
    readonly property string colorKey: n ? n.color : "YELLOW"
    readonly property bool expandedBar: win.active || hoverAll.hovered || menu.shown

    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: n && n.title ? n.title : "Nota"
    minimumWidth: 220
    minimumHeight: 160
    visible: true

    // ── posição e tamanho lembrados por nota ───────────────────────────────
    Component.onCompleted: {
        const g = notas.geometry(noteId);
        if (g) { x = g[0]; y = g[1]; width = g[2]; height = g[3]; }
        else {
            width = 320; height = 320;
            x = Screen.width / 2 - 160 + (Math.random() - 0.5) * 240;
            y = Screen.height / 2 - 200 + (Math.random() - 0.5) * 160;
        }
        openAnim.start();
        requestActivate();
    }
    onXChanged: saveTimer.restart()
    onYChanged: saveTimer.restart()
    onWidthChanged: saveTimer.restart()
    onHeightChanged: saveTimer.restart()
    Timer { id: saveTimer; interval: 500; onTriggered: notas.saveGeometry(win.noteId, win.x, win.y, win.width, win.height) }

    // ── abrir e fechar com animação ────────────────────────────────────────
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "scale"; to: 0.96; duration: 140 }
        }
        ScriptAction { script: notas.closeNote(win.noteId) }
    }
    function closeNote() { flush(); closeAnim.start(); }

    // ── salvar: espera a pessoa parar de digitar ───────────────────────────
    Timer { id: typingTimer; interval: 600; onTriggered: win.flush() }
    function flush() {
        if (!typingTimer.running && !dirty) return;
        typingTimer.stop();
        dirty = false;
        notas.update(noteId, titleField.text, n && n.isList ? "" : body.text);
    }
    property bool dirty: false
    function edited() { dirty = true; typingTimer.restart(); }

    HoverHandler { id: hoverAll }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 8
        color: Palette.body(win.colorKey)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        clip: true
        Behavior on color { ColorAnimation { duration: 200 } }

        // bordas para redimensionar (a janela não tem moldura)
        Repeater {
            model: [
                { e: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { e: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { e: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, c: Qt.SizeVerCursor },
                { e: Qt.BottomEdge | Qt.RightEdge, x: -10, y: -10, w: 10, h: 10, c: Qt.SizeFDiagCursor },
                { e: Qt.BottomEdge | Qt.LeftEdge, x: 0, y: -10, w: 10, h: 10, c: Qt.SizeBDiagCursor }
            ]
            delegate: MouseArea {
                required property var modelData
                z: 10
                x: modelData.x < 0 ? card.width + modelData.x : modelData.x
                y: modelData.y < 0 ? card.height + modelData.y : modelData.y
                width: modelData.w <= 0 ? card.width + modelData.w : modelData.w
                height: modelData.h <= 0 ? card.height + modelData.h : modelData.h
                cursorShape: modelData.c
                onPressed: win.startSystemResize(modelData.e)
            }
        }

        // ── barra de cima: faixa fina sem foco, barra com botões com foco ──
        Rectangle {
            id: bar
            width: parent.width
            height: win.expandedBar ? 34 : 6
            color: Palette.bar(win.colorKey)
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }

            MouseArea { // arrastar a nota
                anchors.fill: parent
                onPressed: win.startSystemMove()
                onDoubleClicked: win.showList()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                opacity: win.expandedBar ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                BarButton { glyph: "+"; tip: "Nova nota"; onClicked: notas.newNote(win.colorKey, false) }
                Item { Layout.fillWidth: true }
                BarButton { glyph: "⋯"; tip: "Menu"; onClicked: menu.shown = !menu.shown }
                BarButton { glyph: "✕"; tip: "Fechar"; onClicked: win.closeNote() }
            }
        }

        // ── conteúdo ───────────────────────────────────────────────────────
        ColumnLayout {
            anchors.top: bar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.margins: 12
            spacing: 4

            TextField {
                id: titleField
                Layout.fillWidth: true
                placeholderText: "Título"
                font.weight: Font.DemiBold
                font.pointSize: 12
                color: "white"
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.45)
                background: null
                padding: 0
                text: win.n ? win.n.title : ""
                onTextEdited: win.edited()
                Keys.onReturnPressed: body.forceActiveFocus()
                // atualização vinda do celular só quando ninguém está digitando aqui
                Connections {
                    target: win
                    function onNChanged() {
                        if (!titleField.activeFocus && win.n && titleField.text !== win.n.title) titleField.text = win.n.title;
                    }
                }
            }

            // texto
            ScrollView {
                visible: win.n && !win.n.isList
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextArea {
                    id: body
                    placeholderText: "Anote algo…"
                    wrapMode: TextEdit.Wrap
                    color: "white"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.45)
                    selectionColor: Palette.bar(win.colorKey)
                    background: null
                    padding: 0
                    text: win.n ? win.n.text : ""
                    onTextChanged: if (activeFocus) win.edited()
                    Connections {
                        target: win
                        function onNChanged() {
                            if (!body.activeFocus && win.n && body.text !== win.n.text) body.text = win.n.text;
                        }
                    }
                    Component.onCompleted: if (!win.n || (!win.n.text && !win.n.title)) forceActiveFocus()
                }
            }

            // lista de tarefas (notas de lista do Keep)
            ListView {
                id: listView
                visible: win.n && win.n.isList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: win.n && win.n.isList ? win.n.items : []
                spacing: 2
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
                delegate: RowLayout {
                    id: itemRow
                    required property var modelData
                    width: ListView.view.width
                    spacing: 6
                    CheckBox {
                        checked: itemRow.modelData.checked
                        onToggled: notas.setItem(win.noteId, itemRow.modelData.id, itemText.text, checked)
                    }
                    TextField {
                        id: itemText
                        Layout.fillWidth: true
                        text: itemRow.modelData.text
                        color: "white"
                        opacity: itemRow.modelData.checked ? 0.55 : 1
                        font.strikeout: itemRow.modelData.checked
                        background: null
                        padding: 0
                        onEditingFinished: if (text !== itemRow.modelData.text)
                            notas.setItem(win.noteId, itemRow.modelData.id, text, itemRow.modelData.checked)
                    }
                    BarButton {
                        glyph: "✕"; tip: "Remover item"; small: true
                        opacity: itemHover.hovered ? 0.8 : 0
                        onClicked: notas.removeItem(win.noteId, itemRow.modelData.id)
                    }
                    HoverHandler { id: itemHover }
                }
                footer: TextField {
                    width: ListView.view.width
                    placeholderText: "+ Item da lista"
                    color: "white"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.5)
                    background: null
                    leftPadding: 32
                    onAccepted: if (text.trim().length) { notas.addItem(win.noteId, text, false); text = ""; }
                }
            }
        }

        // ── rodapé: fixar e quando foi editada ─────────────────────────────
        RowLayout {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            height: 28
            opacity: win.expandedBar ? 1 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            BarButton {
                glyph: win.n && win.n.pinned ? "📌" : "📍"
                tip: win.n && win.n.pinned ? "Desafixar" : "Fixar no topo"
                onClicked: notas.setPinned(win.noteId, !(win.n && win.n.pinned))
            }
            Item { Layout.fillWidth: true }
            Label {
                text: win.n ? Palette.when(win.n.updated) : ""
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pointSize: 8
                Layout.rightMargin: 6
            }
        }

        // ── menu ⋯: desce por dentro da nota, como no Windows ──────────────
        Rectangle {
            id: menu
            property bool shown: false
            property bool confirmDelete: false
            onShownChanged: if (!shown) confirmDelete = false
            width: parent.width
            y: bar.height - (shown ? 0 : height)
            height: menuColumn.implicitHeight + 16
            color: Qt.darker(Palette.body(win.colorKey), 1.25)
            opacity: shown ? 1 : 0
            visible: opacity > 0
            z: 5
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            ColumnLayout {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 6

                // as cores do Keep
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: !menu.confirmDelete
                    Repeater {
                        model: notas.colors
                        delegate: Rectangle {
                            required property string modelData
                            width: 26; height: 26; radius: 13
                            color: Palette.bar(modelData)
                            border.width: win.colorKey === modelData ? 2 : (swatchMouse.containsMouse ? 1 : 0)
                            border.color: "white"
                            scale: swatchMouse.pressed ? 0.9 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            ToolTip.text: Palette.name(modelData)
                            ToolTip.visible: swatchMouse.containsMouse
                            ToolTip.delay: 600
                            MouseArea {
                                id: swatchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { notas.setColor(win.noteId, parent.modelData); menu.shown = false; }
                            }
                        }
                    }
                }
                MenuRow { visible: !menu.confirmDelete; text: "Lista de notas"; glyph: "☰"; onClicked: { menu.shown = false; notas.showList(); } }
                MenuRow { visible: !menu.confirmDelete; text: "Excluir nota"; glyph: "🗑"; onClicked: menu.confirmDelete = true }

                // confirmação, como o "Excluir esta nota?" do Windows
                Label { visible: menu.confirmDelete; text: "Excluir esta nota?"; color: "white"; font.weight: Font.DemiBold }
                Label {
                    visible: menu.confirmDelete; Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "Ela vai para a lixeira do Google Keep (dá para recuperar por lá)."
                    color: Qt.rgba(1, 1, 1, 0.7); font.pointSize: 8
                }
                RowLayout {
                    visible: menu.confirmDelete
                    Layout.alignment: Qt.AlignRight
                    Button { text: "Cancelar"; onClicked: menu.confirmDelete = false }
                    Button { text: "Excluir"; highlighted: true; onClicked: { menu.shown = false; notas.trash(win.noteId); } }
                }
            }
        }
    }

    function showList() { notas.showList(); }
    onActiveChanged: if (!active) { flush(); menu.shown = false; }

    // ── peças pequenas ─────────────────────────────────────────────────────
    component BarButton: AbstractButton {
        property string glyph
        property string tip
        property bool small: false
        implicitWidth: small ? 22 : 30
        implicitHeight: small ? 22 : 28
        hoverEnabled: true
        contentItem: Text {
            text: parent.glyph
            color: "white"
            font.pixelSize: parent.small ? 11 : 15
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 4
            color: Qt.rgba(1, 1, 1, parent.down ? 0.08 : (parent.hovered ? 0.16 : 0))
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        ToolTip.text: tip
        ToolTip.visible: hovered && tip.length > 0
        ToolTip.delay: 700
    }

    component MenuRow: AbstractButton {
        property string glyph
        Layout.fillWidth: true
        implicitHeight: 32
        hoverEnabled: true
        contentItem: RowLayout {
            spacing: 10
            Text { text: parent.parent.glyph; color: "white"; font.pixelSize: 14; Layout.leftMargin: 6 }
            Text { text: parent.parent.text; color: "white"; Layout.fillWidth: true }
        }
        background: Rectangle {
            radius: 4
            color: Qt.rgba(1, 1, 1, parent.down ? 0.06 : (parent.hovered ? 0.12 : 0))
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }
}
