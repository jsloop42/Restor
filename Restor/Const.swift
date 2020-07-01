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
    
    // User defaults keys
    static let selectedWorkspaceIdKey = "selectedWorkspaceId"
    /// The selected segment index in response screen.
    static let responseSegmentIndexKey = "responseSegmentIndex"
    
    /// The default number of methods added (`GET`, `POST`, `PUT`, `PATCH` and `DELETE`).
    static let defaultRequestMethodsCount = 5
    static let paginationOffset = 20
    static let fetchLimit = 30
    static let helpTextForAddNewRequestMethod = "The request method name will be available to all requests within the same project and should be unique."
    static let appId = "1496176309"
    static let feedbackEmail = "info@estoapps.com"
}

extension Notification.Name {
    static let requestTableViewReload = Notification.Name("request-table-view-reload")
    static let requestViewClearEditing = Notification.Name("request-view-clear-editing")
    static let requestMethodDidChange = Notification.Name("request-method-did-change")
    static let requestBodyFormFieldTypeDidChange = Notification.Name("request-body-form-field-type-did-change")
    static let requestBodyTypeDidChange = Notification.Name("request-body-type-did-change")
    static let customRequestMethodDidAdd = Notification.Name("custom-request-method-did-add")
    static let customRequestMethodShouldDelete = Notification.Name("custom-request-method-should-delete")
    static let optionScreenShouldPresent = Notification.Name("option-screen-should-present")
    static let optionPickerShouldReload = Notification.Name("option-picker-should-reload")
    static let documentPickerMenuShouldPresent = Notification.Name("document-picker-menu-should-present")
    static let documentPickerShouldPresent = Notification.Name("document-picker-should-present")
    static let imagePickerShouldPresent = Notification.Name("image-picker-should-present")
    static let documentPickerImageIsAvailable = Notification.Name("document-picker-image-is-available")
    static let documentPickerFileIsAvailable = Notification.Name("document-picker-file-is-available")
    static let workspaceDidSync = Notification.Name("workspace-did-sync")
    static let projectDidSync = Notification.Name("project-did-sync")
    static let requestDidSync = Notification.Name("request-did-sync")
    static let requestDataDidSync = Notification.Name("request-data-did-sync")
    static let requestBodyDataDidSync = Notification.Name("request-body-data-did-sync")
    static let requestMethodDataDidSync = Notification.Name("request-method-data-did-sync")
    static let fileDataDidSync = Notification.Name("file-data-did-sync")
    static let imageDataDidSync = Notification.Name("image-data-did-sync")
    static let historyDidSync = Notification.Name("history-did-sync")
    static let envDidSync = Notification.Name("env-did-sync")
    static let envVarDidSync = Notification.Name("env-var-did-sync")
    static let databaseWillUpdate = Notification.Name("database-will-update")
    static let databaseDidUpdate = Notification.Name("database-did-update")
}
