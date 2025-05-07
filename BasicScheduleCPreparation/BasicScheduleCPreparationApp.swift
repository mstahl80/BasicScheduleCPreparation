//
//  BasicScheduleCPreparationApp.swift
//  BasicScheduleCPreparation
//
//  Created by Matthew Stahl on 5/7/25.
//

import SwiftUI

@main
struct BasicScheduleCPreparationApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
