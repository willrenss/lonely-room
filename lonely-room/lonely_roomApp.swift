//
//  lonely_roomApp.swift
//  lonely-room
//
//  Created by William Lourensius on 13/03/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - AppDelegate — force landscape
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
    -> UIInterfaceOrientationMask {
        return .landscape
    }
}
#endif

@main
struct lonely_roomApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
