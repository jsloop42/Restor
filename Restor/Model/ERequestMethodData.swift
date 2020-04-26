//
//  ERequestMethodData.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestMethodData: NSManagedObject, Entity {
    public var recordType: String { return "RequestMethodData" }
    
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
    
    func updateCKRecord(_ record: CKRecord, project: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["changeTag"] = self.changeTag as CKRecordValue
        record["id"] = self.getId() as CKRecordValue
        record["wsId"] = self.getWsId() as CKRecordValue
        record["isCustom"] = self.isCustom as CKRecordValue
        record["name"] = (self.name ?? "") as CKRecordValue
        record["shouldDelete"] = self.shouldDelete as CKRecordValue
        record["version"] = self.version as CKRecordValue
        let ref = CKRecord.Reference(record: project, action: .none)
        record["project"] = ref as CKRecordValue
    }
    
    static func getProject(_ record: CKRecord, ctx: NSManagedObjectContext) -> EProject? {
        if let ref = record["project"] as? CKRecord.Reference {
            return CoreDataService.shared.getProject(id: CloudKitService.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["changeTag"] as? Int64 { self.changeTag = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["isCustom"] as? Bool { self.isCustom = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["shouldDelete"] as? Bool { self.shouldDelete = x }
        if let x = record["version"] as? Int64 { self.version = x }
        if let proj = ERequestMethodData.getProject(record, ctx: ctx) { self.project = proj }
    }
}
