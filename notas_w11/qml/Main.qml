/*
    Raiz do notas-w11: a lista de notas e uma janela por nota aberta.
*/
import QtQuick
import QtQml.Models

QtObject {
    id: root

    // muda a cada atualização das notas: as janelas releem a nota delas
    property int revision: 0
    property Connections modelWatch: Connections {
        target: notas.model
        function onDataChanged() { root.revision++; }
        function onModelReset() { root.revision++; }
    }

    property NotesList listWindow: NotesList {
        revision: root.revision
        visible: false
    }

    property Connections requests: Connections {
        target: notas
        function onListRequested() { root.listWindow.showAndRaise(); }
        function onLoginRequested() { root.listWindow.showAndRaise(); }
        function onOpenNotesChanged() { root.syncOpen(); }
    }

    // notas abertas: só a diferença entra/sai, as outras janelas ficam como estão
    property ListModel openModel: ListModel {}
    function syncOpen() {
        const wanted = notas.openNotes;
        for (let i = openModel.count - 1; i >= 0; --i) {
            if (wanted.indexOf(openModel.get(i).noteId) < 0) openModel.remove(i);
        }
        for (const id of wanted) {
            let found = false;
            for (let i = 0; i < openModel.count; ++i) if (openModel.get(i).noteId === id) found = true;
            if (!found) openModel.append({ noteId: id });
        }
    }
    Component.onCompleted: syncOpen()

    // uma janela por nota aberta (a lista de abertas é lembrada entre sessões)
    property Instantiator stickies: Instantiator {
        model: root.openModel
        delegate: StickyNote {
            noteId: model.noteId
            revision: root.revision
        }
    }
}
