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
    
    func updateCKRecord(_ record: CKRecord, workspace: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: workspace, action: .none)
            record["workspace"] = ref
        }
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
            return CoreDataService.shared.getWorkspace(id: EACloudKit.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    /// Returns project from the given record reference. If the project does not exists, one will be created.
    static func getProjectFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> EProject? {
        let projId = EACloudKit.shared.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let proj = CoreDataService.shared.getProject(id: projId, ctx: ctx) { return proj }
        let proj = CoreDataService.shared.createProject(id: projId, wsId: wsId, name: "", desc: "", checkExists: false, ctx: ctx)
        proj?.changeTag = 0
        return proj
    }
    
    static func getRequestRecordIDs(_ record: CKRecord) -> [CKRecord.ID] {
        if let xs = record["requests"] as? [CKRecord.Reference] {
            return xs.map { ref -> CKRecord.ID in ref.recordID }
        }
        return []
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["desc"] as? String { self.desc = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["wsId"] as? String { self.wsId = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ws = EProject.getWorkspace(record, ctx: moc) { self.workspace = ws }
            }
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EProject? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        let db = CoreDataService.shared
        guard let proj = db.createProject(id: id, wsId: wsId, name: "", desc: "", ctx: db.mainMOC) else { return nil }
        if let x = dict["created"] as? Int64 { proj.created = x }
        if let x = dict["modified"] as? Int64 { proj.modified = x }
        if let x = dict["changeTag"] as? Int64 { proj.changeTag = x }
        if let x = dict["desc"] as? String { proj.desc = x }
        if let x = dict["name"] as? String { proj.name = x }
        if let x = dict["version"] as? Int64 { proj.version = x }
        if let xs = dict["requests"] as? [[String: Any]] {
            xs.forEach { dict in
                if let req = ERequest.fromDictionary(dict) {
                    req.project = proj
                }
            }
        }
        if let xs = dict["methods"] as? [[String: Any]] {
            xs.forEach { dict in
                if let method = ERequestMethodData.fromDictionary(dict) {
                    method.project = proj
                }
            }
        }
        proj.markForDelete = false
        db.saveMainContext()
        return proj
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["desc"] = self.desc
        dict["id"] = self.id
        dict["wsId"] = self.wsId
        dict["name"] = self.name
        dict["version"] = self.version
        var xs: [[String: Any]] = []
        let db = CoreDataService.shared
        // requests
        let reqs = db.getRequests(projectId: self.getId())
        reqs.forEach { req in
            xs.append(req.toDictionary())
        }
        dict["requests"] = xs
        xs = []
        // request methods
        let reqMethods = db.getRequestMethodData(projId: self.getId())
        reqMethods.forEach { method in
            xs.append(method.toDictionary())
        }
        dict["methods"] = xs
        return dict
    }
}
