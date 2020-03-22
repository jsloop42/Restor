//
//  AppDelegate.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import UIKit
import CloudKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    //private let keyboardManager = IQKeyboardManager.shared
    private let app = App.shared
    private lazy var ck = { return CloudKitService.shared }()
    private lazy var db = { return PersistenceService.shared }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UI.setGlobalStyle()
        self.app.updateWindowBackground(self.window)
        application.registerForRemoteNotifications()
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // TODO: handle any editing state
        Log.debug("application will terminate")
        self.app.saveState()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let info = userInfo as? [String: NSObject], let notif = CKNotification(fromRemoteNotificationDictionary: info) {
            if let sub = (self.ck.subscriptions.first { sub -> Bool in sub.subscriptionID == notif.subscriptionID }) {
                if let zoneID = self.ck.zoneSubscriptions[sub.subscriptionID] {
                    self.ck.handleNotification(zoneID: zoneID)
                    completionHandler(.newData)
                    return
                }
            } else {
                completionHandler(.noData)
            }
        }
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

