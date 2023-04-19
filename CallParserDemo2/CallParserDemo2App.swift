//
//  CallParserDemo2App.swift
//  CallParserDemo2
//
//  Created by Peter Bourget on 4/18/23.
//

import SwiftUI

@main
struct CallParserDemo2App: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject var model = Model()

    var body: some Scene {
        WindowGroup {
          ContentView()
            .environmentObject(model)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
