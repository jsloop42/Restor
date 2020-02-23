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
    /// The data model index
    static let optionSelectedIndexKey = "optionSelectedIndexKey"
    /// The option field item index
    static let optionSelectedFieldIndexKey = "optionSelectedFieldIndexKey"
    /// The option vc type
    static let optionTypeKey = "optionTypeKey"
}

struct NotificationKey {
    static let requestTableViewReload = Notification.Name("requestTableViewReload")
    static let requestViewClearEditing = Notification.Name("requestViewClearEditing")
    static let requestMethodDidChange = Notification.Name("requestMethodDidChange")
    static let optionScreenShouldPresent = Notification.Name("optionScreenShouldPresent")
    static let bodyFormFieldTypeDidChange = Notification.Name("bodyFormFieldTypeDidChange")
    static let documentPickerShouldPresent = Notification.Name("documentPickerShouldPresent")
}
