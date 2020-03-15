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
    /// The data model index.
    static let modelIndexKey = "modelIndexKey"
    /// A generic index key.
    static let indexKey = "indexKey"
    /// Generic data key.
    static let dataKey = "dataKey"
    /// The option selected item index.
    static let optionSelectedIndexKey = "optionSelectedIndexKey"
    /// The option vc type.
    static let optionTypeKey = "optionTypeKey"
    /// The option picker data [String].
    static let optionDataKey = "optionDataKey"
    /// The option picker title key.
    static let optionTitleKey = "optionTitleKey"
    /// The model data (eg: `ERequestBodyData`).
    static let optionModelKey = "optionModelKey"
    /// The action for the data (add, delete, etc.).
    static let optionDataActionKey = "optionDataActionKey"
    
    /// The default number of methods added (`GET`, `POST`, `PUT`, `PATCH` and `DELETE`).
    static let defaultRequestMethodsCount = 5
}

struct NotificationKey {
    static let requestTableViewReload = Notification.Name("requestTableViewReload")
    static let requestViewClearEditing = Notification.Name("requestViewClearEditing")
    static let requestMethodDidChange = Notification.Name("requestMethodDidChange")
    static let requestBodyFormFieldTypeDidChange = Notification.Name("requestBodyFormFieldTypeDidChange")
    static let requestBodyTypeDidChange = Notification.Name("requestBodyTypeDidChange")
    static let customRequestMethodDidAdd = Notification.Name("customRequestMethodDidAdd")
    static let customRequestMethodShouldDelete = Notification.Name("customRequestMethodShouldDelete")
    static let optionScreenShouldPresent = Notification.Name("optionScreenShouldPresent")
    static let optionPickerShouldReload = Notification.Name("optionPickerShouldReload")
    static let documentPickerMenuShouldPresent = Notification.Name("documentPickerMenuShouldPresent")
    static let documentPickerShouldPresent = Notification.Name("documentPickerShouldPresent")
    static let imagePickerShouldPresent = Notification.Name("imagePickerShouldPresent")
    static let documentPickerImageIsAvailable = Notification.Name("documentPickerImageIsAvailable")
    static let documentPickerFileIsAvailable = Notification.Name("documentPickerFileIsAvailable")
}
