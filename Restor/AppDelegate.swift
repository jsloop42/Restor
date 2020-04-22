//
//  AppDelegate.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    //private let keyboardManager = IQKeyboardManager.shared
    private let app = App.shared
    private lazy var ck = { return CloudKitService.shared }()
    private lazy var db = { return PersistenceService.shared }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UI.setGlobalStyle()
        self.app.updateWindowBackground(self.window)
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
//            if let error = error {
//                Log.error("Notification auth req err:  \(error.localizedDescription)")
//            } else {
//                DispatchQueue.main.async {
//                    application.registerForRemoteNotifications()
//                }
//            }
//        }
//        UNUserNotificationCenter.current().delegate = self
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
        Log.debug("Remote notification did receive: \(userInfo)")
        if let info = userInfo as? [String: NSObject], let notif = CKNotification(fromRemoteNotificationDictionary: info) {
            if let subID = notif.subscriptionID, self.ck.isSubscribed(to: subID) {
                if let ckhm = userInfo["ck"] as? [String: Any], let meta = ckhm["met"] as? [String: Any], let zid = meta["zid"] as? String {
                    let zoneID = self.ck.zoneID(with: zid)
                    self.db.fetchZoneChanges(zoneIDs: [zoneID], isDelayedFetch: true)
                    completionHandler(.newData)
                    return
                }
            }
            completionHandler(.noData)
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.debug("did register for remote notification with token: \(String(bytes: deviceToken, encoding: .utf8) ?? "")")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound, .badge])
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

