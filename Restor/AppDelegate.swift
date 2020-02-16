//
//  AppDelegate.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import UIKit
//import IQKeyboardManagerSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    //private let keyboardManager = IQKeyboardManager.shared
    private let app = App.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UI.setGlobalStyle()
        self.app.updateWindowBackground(self.window)
        //self.enableIQKeyboardManager()
        return true
    }
    
    func enableIQKeyboardManager() {
//        self.keyboardManager.enable = true
//        self.keyboardManager.enableAutoToolbar = false
    }

    // MARK: UISceneSession Lifecycle

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

