//
//  WorkspaceUndoRedoCommands.swift
//  KobunPark
//

import SwiftUI

struct WorkspaceUndoRedoCommands: Commands {
    @ObservedObject var history: WorkspaceHistoryStore

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(history.undoCommandTitle, action: history.undo)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!history.canUndo)

            Button(history.redoCommandTitle, action: history.redo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!history.canRedo)
        }
    }
}
