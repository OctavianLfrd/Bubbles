//
//  BubblesApp.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import SwiftUI

@main
struct BubblesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.colorScheme, .dark)
                .preferredColorScheme(.dark)
        }
    }
}
