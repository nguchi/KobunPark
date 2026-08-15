//
//  KobunParkApp.swift
//  KobunPark
import SwiftUI

@main
struct KobunParkApp: App {
    @StateObject private var history = WorkspaceHistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView(history: history)
        }
        .commands {
            WorkspaceUndoRedoCommands(history: history)
        }
    }
}
