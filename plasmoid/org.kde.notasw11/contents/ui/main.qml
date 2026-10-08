/*
    Widget das Notas Autoadesivas (notas-w11).

    No painel: o ícone abre a lista das notas e o "+" de nota nova.
    Na área de trabalho: os cartões das notas ficam à vista.
    Lê o arquivo que o app mantém atualizado e abre as notas pelo comando
    notas-w11 (que conversa com o app já aberto).
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    property var notes: []
    readonly property string cmd: "\"$HOME/.local/bin/notas-w11\""

    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation
    toolTipMainText: "Notas Autoadesivas"
    toolTipSubText: notes.length === 1 ? "1 nota" : notes.length + " notas"
    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    // paleta escura do Keep (a mesma do app)
    readonly property var bodyColors: ({ DEFAULT: "#2b2c30", RED: "#77172e", ORANGE: "#692b17", YELLOW: "#7c4a03",
        GREEN: "#264d3b", TEAL: "#0c625d", BLUE: "#256377", CERULEAN: "#284255", PURPLE: "#472e5b",
        PINK: "#6c394f", BROWN: "#4b443a", GRAY: "#3c3f43" })
    readonly property var barColors: ({ DEFAULT: "#4a4c52", RED: "#b4294a", ORANGE: "#b4501f", YELLOW: "#c58a12",
        GREEN: "#3f8b62", TEAL: "#159b92", BLUE: "#3a95b2", CERULEAN: "#41698a", PURPLE: "#7a4f9c",
        PINK: "#a95a7c", BROWN: "#7d7262", GRAY: "#62666c" })

    function run(args) { runner.connectSource(cmd + " " + args); }

    // lê as notas: rápido com a lista à vista, devagar no resto do tempo
    Plasma5Support.DataSource {
        id: feed
        engine: "executable"
        readonly property string source: "cat \"$HOME/.local/share/notas-w11/notes.json\" 2>/dev/null"
        connectedSources: [source]
        interval: root.expanded || root.onDesktop ? 3000 : 30000
        onNewData: (sourceName, data) => {
            try {
                const parsed = JSON.parse(data["stdout"] || "{}");
                root.notes = parsed.notes || [];
            } catch (e) { }
        }
    }
    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }
    onExpandedChanged: if (expanded) feed.connectSource(feed.source)

    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: "knotes"
            active: parent.containsMouse
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: "Notas Autoadesivas"
                }
                PlasmaComponents.ToolButton {
                    icon.name: "list-add"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: "Nova nota"
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: root.run("--new")
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-list-details"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: "Todas as notas"
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: root.run("")
                }
            }
        }

        PlasmaComponents.ScrollView {
            anchors.fill: parent
            ListView {
                id: list
                model: root.notes
                spacing: Kirigami.Units.smallSpacing
                topMargin: Kirigami.Units.smallSpacing
                clip: true

                delegate: Item {
                    id: cardItem
                    required property var modelData
                    required property int index
                    readonly property string preview: modelData.isList
                        ? modelData.items.map(i => (i.checked ? "☑ " : "☐ ") + i.text).join("\n")
                        : modelData.text
                    width: ListView.view.width
                    height: card.height

                    // os cartões entram deslizando, um depois do outro
                    Component.onCompleted: { card.opacity = 0; appear.start(); }
                    SequentialAnimation {
                        id: appear
                        PauseAnimation { duration: Math.max(0, Math.min(cardItem.index, 8)) * 30 }
                        ParallelAnimation {
                            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180 }
                            NumberAnimation { target: shift; property: "y"; from: 10; to: 0; duration: 220; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        id: card
                        width: parent.width
                        height: column.implicitHeight + Kirigami.Units.largeSpacing * 2
                        radius: 6
                        transform: Translate { id: shift }
                        readonly property color base: root.bodyColors[cardItem.modelData.color] || root.bodyColors.DEFAULT
                        color: mouse.containsMouse ? Qt.lighter(base, 1.12) : base
                        clip: true
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: parent.width
                            height: 4
                            color: root.barColors[cardItem.modelData.color] || root.barColors.DEFAULT
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run("--open " + cardItem.modelData.id)
                        }
                        ColumnLayout {
                            id: column
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Kirigami.Units.largeSpacing
                            spacing: 2
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: (cardItem.modelData.pinned ? "📌 " : "") + (cardItem.modelData.title || "")
                                color: "white"
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: cardItem.preview || "Nota vazia"
                                color: Qt.rgba(1, 1, 1, cardItem.preview ? 0.85 : 0.5)
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: list.count === 0
                    iconName: "knotes"
                    text: "Nenhuma nota"
                    helpfulAction: Kirigami.Action {
                        icon.name: "list-add"
                        text: "Nova nota"
                        onTriggered: root.run("--new")
                    }
                }
            }
        }
    }
}
