//
//  main.swift
//  Restor
//
//  Created by jsloop on 03/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

let isRunningTests = NSClassFromString("XCTestCase") != nil
let appDelegateClass = isRunningTests ? NSStringFromClass(AppDelegateMock.self) : NSStringFromClass(AppDelegate.self)
CoreDataService.shared.bootstrap()
//CloudKitService.shared.setZoneCreated()
//CloudKitService.shared.createZoneIfNotExist { res in
//    switch res {
//    case .success(let zone):
//        Log.debug("zone obtained: \(zone)")
//    case .failure(let err):
//        Log.debug("zone error: \(err)")
//    }
//}
let ck = CloudKitService.shared
//let id = CKRecordZone.ID(zoneName: "restor-icloud", ownerName: ck.currentUsername())
//CloudKitService.shared.deleteZone(recordZoneId: id) { result in }

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, appDelegateClass)
