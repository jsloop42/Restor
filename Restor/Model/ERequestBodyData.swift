//
//  ERequestBodyData.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestBodyData: NSManagedObject, Entity {
    public var recordType: String { return "RequestBodyData" }
    
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
        return self.id ?? ""
    }
    
    public func getCreated() -> Int64 {
        return created
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
    
    func updateCKRecord(_ record: CKRecord, request: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["json"] = (self.json ?? "") as CKRecordValue
            record["raw"] = (self.raw ?? "") as CKRecordValue
            record["selected"] = self.selected as CKRecordValue
            record["version"] = self.version as CKRecordValue
            record["xml"] = (self.xml ?? "") as CKRecordValue
            let ref = CKRecord.Reference(record: request, action: .none)
            record["request"] = ref as CKRecordValue
        }
    }
    
    static func addBinaryToRequestBodyData(_ reqBodyData: CKRecord, binary: CKRecord) {
        let ref = CKRecord.Reference(record: binary, action: .deleteSelf)
        reqBodyData["binary"] = ref
    }
    
    static func getRequestBodyDataFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequestBodyData? {
        let reqBodyDataId = EACloudKit.shared.entityID(recordID: ref.recordID)
        if let bodyData = CoreDataService.shared.getRequestBodyData(id: reqBodyDataId, ctx: ctx) { return bodyData }
        let bodyData = CoreDataService.shared.createRequestBodyData(id: reqBodyDataId, wsId: record.getWsId(), checkExists: false, ctx: ctx)
        bodyData?.changeTag = 0
        return bodyData
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            if let x = record["created"] as? Int64 { self.created = x }
            if let x = record["modified"] as? Int64 { self.modified = x }
            if let x = record["changeTag"] as? Int64 { self.changeTag = x }
            if let x = record["id"] as? String { self.id = x }
            if let x = record["json"] as? String { self.json = x }
            if let x = record["raw"] as? String { self.raw = x }
            if let x = record["selected"] as? Int64 { self.selected = x }
            if let x = record["version"] as? Int64 { self.version = x }
            if let x = record["xml"] as? String { self.xml = x }
            if let ref = record["request"] as? CKRecord.Reference, let req = ERequest.getRequestFromReference(ref, record: record, ctx: moc) { self.request = req }
        }
    }
}