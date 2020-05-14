//
//  RequestTabBarViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let requestVCShouldPresent = Notification.Name("request-vc-should-present")
}

class RequestTabBarController: UITabBarController {
    var request: ERequest?
    
    override func viewDidLoad() {
        Log.debug("request tab bar controller")
    }
}
