//
//  lonely_roomApp.swift
//  lonely-room
//
//  Created by William Lourensius on 13/03/26.
//

import SwiftUI

// MARK: - AppDelegate — force landscape
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
    -> UIInterfaceOrientationMask {
        return .landscape
    }
}

@main
struct lonely_roomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
