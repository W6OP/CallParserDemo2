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
  @StateObject var model = Model(loggingLevel: true)

    var body: some Scene {
        WindowGroup {
          ContentView()
            .environmentObject(model)
            .task {
              // Hand the AppDelegate a shutdown hook so it can cleanly log off
              // before the process exits.
              appDelegate.shutdownAction = { @MainActor [model] in
                await model.logoffFromQRZ()
              }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  /// Closure invoked from `applicationShouldTerminate(_:)` before the process exits.
  var shutdownAction: (@MainActor @Sendable () async -> Void)?

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let action = shutdownAction else { return .terminateNow }
    Task { @MainActor in
      await action()
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
