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
    
    public func getIndex() -> Int {
        return self.index.toInt()
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
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIndex(_ i: Int) {
        self.index = i.toInt64()
    }
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func getZoneID() -> CKRecordZone.ID {
        return CloudKitService.shared.zoneID(workspaceId: self.request!.project!.workspace!.id!)
    }
    
    func updateCKRecord(_ record: CKRecord, request: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["id"] = self.id! as CKRecordValue
        record["index"] = self.index as CKRecordValue
        record["json"] = (self.json ?? "") as CKRecordValue
        record["raw"] = (self.raw ?? "") as CKRecordValue
        record["selected"] = self.selected as CKRecordValue
        record["version"] = self.version as CKRecordValue
        record["xml"] = (self.xml ?? "") as CKRecordValue
        let ref = CKRecord.Reference(record: request, action: .none)
        record["request"] = ref as CKRecordValue
    }
    
    static func addBinaryToRequestBodyData(_ reqBodyData: CKRecord, binary: CKRecord) {
        let ref = CKRecord.Reference(record: binary, action: .deleteSelf)
        reqBodyData["binary"] = ref
    }
    
    static func getRequest(_ record: CKRecord, ctx: NSManagedObjectContext) -> ERequest? {
        if let ref = record["request"] as? CKRecord.Reference {
            return CoreDataService.shared.getRequest(id: CloudKitService.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["index"] as? Int64 { self.index = x }
        if let x = record["json"] as? String { self.json = x }
        if let x = record["raw"] as? String { self.raw = x }
        if let x = record["selected"] as? Int64 { self.selected = x }
        if let x = record["version"] as? Int64 { self.version = x }
        if let x = record["xml"] as? String { self.xml = x }
        if let req = ERequestBodyData.getRequest(record, ctx: ctx) { self.request = req }
    }
}
