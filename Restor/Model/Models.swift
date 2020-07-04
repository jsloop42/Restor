//
//  Models.swift
//  Restor
//
//  Created by jsloop on 17/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CloudKit

/// Used to hold the current attachment details being processed to avoid duplicates
struct AttachmentInfo {
    /// List of URLs for document attachment type
    var docs: [URL] = []
    /// Contains the file name for comparison. Cannot compare URL as the path gets auto generated each time.
    var docNames: [String] = []
    /// Photo or camera attachment
    var image: UIImage?
    /// kUTTypeImage
    var imageType: String = "png"
    /// If camera is chosen
    var isCameraMode: Bool = false
    /// The index of data in the model
    var modelIndex: Int = 0
    /// The body form field model `RequestData` id.
    var reqDataId = ""
    
    mutating func copyFromState() {
        self.docs = DocumentPickerState.docs
        self.docNames = self.docs.map({ url -> String in App.shared.getFileName(url) })
        self.image = DocumentPickerState.image
        self.imageType = DocumentPickerState.imageType
        self.isCameraMode = DocumentPickerState.isCameraMode
        self.modelIndex = DocumentPickerState.modelIndex
        self.reqDataId = DocumentPickerState.reqDataId
    }
    
    /// Checks if the current state is same as the picker state
    func isSame() -> Bool {
        if DocumentPickerState.image != nil {
            return self.image == DocumentPickerState.image
        } else {
            if self.image == nil && DocumentPickerState.docs.isEmpty { return true }
        }
        let len = DocumentPickerState.docs.count
        if self.docs.count != len { return false }
        for i in 0..<len {
            if self.docNames[i] != App.shared.getFileName(DocumentPickerState.docs[i]) { return false }
        }
        return true
    }
    
    mutating func clear() {
        self.docs = []
        self.docNames = []
        self.image = nil
        self.imageType = "png"
        self.isCameraMode = false
        self.modelIndex = 0
        self.reqDataId = ""
    }
}

public protocol Entity: NSManagedObject {
    var recordType: String { get }
    func getId() -> String
    func getWsId() -> String
    func setWsId(_ id: String)
    func getName() -> String
    func getCreated() -> Int64
    func getModified() -> Int64
    /// The modified fields get update on changing any property or relation. But for syncing with cloud, we need to use the change tag value as we we do not
    /// take into account relation changes for the given entity for syncing.
    func setModified(_ ts: Int64?)
    func getChangeTag() -> Int64
    /// If any property changes, the change tag value will be updated.
    func setChangeTag(_ ts: Int64?)
    func getVersion() -> Int64
    func getZoneID() -> CKRecordZone.ID
    func getRecordID() -> CKRecord.ID
    func setIsSynced(_ status: Bool)
    func setMarkedForDelete(_ status: Bool)
    func willSave()
//    func fromDictionary(_ dict: [String: Any])
//    func toDictionary() -> [String: Any]
}

extension Entity {
    public func setModified(_ ts: Int64? = nil) {
        return setModified(Date().currentTimeNanos())
    }
    
    public func setChangeTag(_ ts: Int64? = nil) {
        return setChangeTag(Date().currentTimeNanos())
    }
    
    public func setChangeTagWithEditTs() {
        self.setModified(AppState.editRequestSaveTs)
        return setChangeTag(AppState.editRequestSaveTs)
    }
    
    public func getZoneID() -> CKRecordZone.ID {
        return EACloudKit.shared.zoneID(workspaceId: self.getWsId())
    }
    
    public func getRecordID() -> CKRecord.ID {
        return EACloudKit.shared.recordID(entityId: self.getId(), zoneID: self.getZoneID())
    }
}
