//
//  ERequest.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequest: NSManagedObject, Entity {
    public var recordType: String { return "Request" }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getIndex() -> Int {
        return self.index.toInt()
    }
    
    public func getName() -> String? {
        return self.name
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
        return CloudKitService.shared.zoneID(workspaceId: self.project!.workspace!.id!)
    }
    
    func updateCKRecord(_ record: CKRecord, project: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["desc"] = (self.desc ?? "") as CKRecordValue
        record["id"] = self.id! as CKRecordValue
        record["index"] = self.index as CKRecordValue
        record["name"] = self.name! as CKRecordValue
        record["selectedMethodIndex"] = self.selectedMethodIndex as CKRecordValue
        record["url"] = (self.url ?? "") as CKRecordValue
        record["version"] = self.version as CKRecordValue
        let ref = CKRecord.Reference(record: project, action: .none)
        record["project"] = ref
    }
    
    static func updateRequestDataReference(to request: CKRecord, requestData: CKRecord, type: RequestDataType) {
        let key: String = {
            if type == .header { return "headers" }
            if type == .param { return "params" }
            return ""
        }()
        guard !key.isEmpty else { Log.error("Wrong request data type passed: \(type.rawValue)"); return }
        let ref = CKRecord.Reference(record: requestData, action: .deleteSelf)
        var xs = request[key] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
        if !xs.contains(ref) {
            xs.append(ref)
            request[key] = xs as CKRecordValue
        }
    }
    
    static func updateBodyReference(_ request: CKRecord, body: CKRecord) {
        let ref = CKRecord.Reference(record: body, action: .deleteSelf)
        request["body"] = ref as CKRecordValue
    }
    
    static func getProject(_ record: CKRecord, ctx: NSManagedObjectContext) -> EProject? {
        if let ref = record["project"] as? CKRecord.Reference {
            return CoreDataService.shared.getProject(id: CloudKitService.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["index"] as? Int64 { self.index = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["selectedMethodIndex"] as? Int64 { self.selectedMethodIndex = x }
        if let x = record["url"] as? String { self.url = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}
