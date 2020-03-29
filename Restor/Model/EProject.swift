//
//  EProject.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EProject: NSManagedObject, Entity {
    public var recordType: String { return "Project" }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getIndex() -> Int {
        return self.index.toInt()
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
        return CloudKitService.shared.zoneID(workspaceId: self.workspace!.id!)
    }
    
    func updateCKRecord(_ record: CKRecord, workspace: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["desc"] = (self.desc ?? "") as CKRecordValue
        record["id"] = self.id! as CKRecordValue
        record["index"] = self.index as CKRecordValue
        record["name"] = (self.name ?? "") as CKRecordValue
        record["version"] = self.version as CKRecordValue
        let ref = CKRecord.Reference(record: workspace, action: .none)
        record["workspace"] = ref
    }
    
    static func addRequestReference(to project: CKRecord, request: CKRecord) {
        let ref = CKRecord.Reference(record: request, action: .deleteSelf)
        var xs = project["requests"] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
        if !xs.contains(ref) {
            xs.append(ref)
            project["requests"] = xs as CKRecordValue
        }
    }
    
    static func addRequestMethodReference(to project: CKRecord, requestMethod: CKRecord) {
        let ref = CKRecord.Reference(record: requestMethod, action: .deleteSelf)
        var xs = project["requestMethods"] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
        if !xs.contains(ref) {
            xs.append(ref)
            project["requestMethods"] = xs as CKRecordValue
        }
    }
    
    static func getWorkspace(_ record: CKRecord, ctx: NSManagedObjectContext) -> EWorkspace? {
        if let ref = record["workspace"] as? CKRecord.Reference {
            return CoreDataService.shared.getWorkspace(id: CloudKitService.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    static func getRequestRecordIDs(_ record: CKRecord) -> [CKRecord.ID] {
        if let xs = record["requests"] as? [CKRecord.Reference] {
            return xs.map { ref -> CKRecord.ID in ref.recordID }
        }
        return []
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["desc"] as? String { self.desc = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["index"] as? Int64 { self.index = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["version"] as? Int64 { self.version = x }
        if let ws = EProject.getWorkspace(record, ctx: ctx) { self.workspace = ws }
    }
}
