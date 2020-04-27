//
//  EImage.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EImage: NSManagedObject, Entity {
    public var recordType: String { return "Image" }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.wsId ?? ""
    }
    
    public func setWsId(_ id: String) {
        self.wsId = id
    }
    
    public func getName() -> String {
        return self.name ?? ""
    }
    
    public func getCreated() -> Int64 {
        return self.created
    }
    
    public func getModified() -> Int64 {
        return self.modified
    }
    
    public func setModified(_ ts: Int64? = nil) {
        self.modified = ts ?? Date().currentTimeNanos()
    }
    
    public func getChangeTag() -> Int64 {
        return self.changeTag
    }
    
    public func setChangeTag(_ ts: Int64? = nil) {
        self.changeTag = ts ?? Date().currentTimeNanos()
    }
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func setMarkedForDelete(_ status: Bool) {
        self.markForDelete = status
    }
    
    public override func willSave() {
        //if self.modified < AppState.editRequestSaveTs { self.modified = AppState.editRequestSaveTs }
    }
    
    func updateCKRecord(_ record: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["changeTag"] = self.changeTag as CKRecordValue
        if let name = self.name, let data = self.data {
            let url = EAFileManager.getTemporaryURL(name)
            do {
                try data.write(to: url)
                record["data"] = CKAsset(fileURL: url)
            } catch let error {
                Log.error("Error: \(error)")
            }
        }
        record["id"] = self.getId() as CKRecordValue
        record["wsId"] = self.getWsId() as CKRecordValue
        record["isCameraMode"] = self.isCameraMode as CKRecordValue
        record["name"] = (self.name ?? "") as CKRecordValue
        record["type"] = (self.type ?? "") as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    static func addRequestDataReference(_ reqData: CKRecord, image: CKRecord) {
        let ref = CKRecord.Reference(record: reqData, action: .none)
        image["requestData"] = ref
    }
    
    static func getRequestData(_ record: CKRecord, ctx: NSManagedObjectContext) -> ERequestData? {
        if let ref = record["requestData"] as? CKRecord.Reference {
            return CoreDataService.shared.getRequestData(id: CloudKitService.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["changeTag"] as? Int64 { self.changeTag = x }
        if let x = record["data"] as? CKAsset, let url = x.fileURL {
            do { self.data = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
        }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["isCameraMode"] as? Bool { self.isCameraMode = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["type"] as? String { self.type = x }
        if let x = record["version"] as? Int64 { self.version = x }
        if let ref = record["requestData"] as? CKRecord.Reference, let reqData = ERequestData.getRequestDataFromReference(ref, record: record, ctx: ctx) {
            self.requestData = reqData
        }
    }
}
