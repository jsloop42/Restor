//
//  Const.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation

struct Const {
    static let requestMethodNameKey = "requestMethodName"
    static let optionSelectedIndexKey = "optionSelectedIndexKey"
}

struct NotificationKey {
    static let requestTableViewReload = Notification.Name("requestTableViewReload")
    static let requestViewClearEditing = Notification.Name("requestViewClearEditing")
    static let requestMethodDidChange = Notification.Name("requestMethodDidChange")
}
