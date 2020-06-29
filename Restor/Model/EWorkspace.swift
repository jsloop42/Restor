//
//  EWorkspace.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EWorkspace: NSManagedObject, Entity {
    public var recordType: String { return "Workspace" }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.getId()
    }
    
    public func setWsId(_ id: String) {
        self.id = id
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
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["isActive"] = self.isActive as CKRecordValue
            record["isSyncEnabled"] = self.isSyncEnabled as CKRecordValue
            record["name"] = self.name! as CKRecordValue
            record["saveResponse"] = self.saveResponse as CKRecordValue
            record["version"] = self.version as CKRecordValue
        }
    }
    
    static func addProjectReference(to workspace: CKRecord, project: CKRecord) {
//        let ref = CKRecord.Reference(record: project, action: .deleteSelf)
//        var xs = workspace["projects"] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
//        if !xs.contains(ref) {
//            xs.append(ref)
//            workspace["projects"] = xs as CKRecordValue
//        }
    }
    
    static func getProjectRecordIDs(_ record: CKRecord) -> [CKRecord.ID] {
//        if let xs = record["projects"] as? [CKRecord.Reference] {
//            return xs.map { ref -> CKRecord.ID in ref.recordID }
//        }
        return []
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        self.managedObjectContext?.performAndWait {
            if let x = record["created"] as? Int64 { self.created = x }
            if let x = record["modified"] as? Int64 { self.modified = x }
            if let x = record["changeTag"] as? Int64 { self.changeTag = x }
            if let x = record["id"] as? String { self.id = x }
            if let x = record["isActive"] as? Bool { self.isActive = x }
            if let x = record["isSyncEnabled"] as? Bool { self.isSyncEnabled = x }
            if let x = record["name"] as? String { self.name = x }
            if let x = record["desc"] as? String { self.desc = x }
            if let x = record["saveResponse"] as? Bool { self.saveResponse = x }
            if let x = record["version"] as? Int64 { self.version = x }
        }
    }
    
    /// Checks if the default workspace does not have any change or is just after a reset (is new)
    var isInDefaultMode: Bool {
        let db = CoreDataService.shared
        return self.id == db.defaultWorkspaceId && self.name == db.defaultWorkspaceName && self.desc == db.defaultWorkspaceDesc && self.modified == self.changeTag && (self.projects == nil || self.projects!.isEmpty)
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EWorkspace? {
        guard let id = dict["id"] as? String else { return nil }
        let db = CoreDataService.shared
        let ctx = db.mainMOC
        guard let ws = db.createWorkspace(id: id, name: "", desc: "", isSyncEnabled: false, ctx: ctx) else { return nil }
        if let x = dict["created"] as? Int64 { ws.created = x }
        if let x = dict["modified"] as? Int64 { ws.modified = x }
        if let x = dict["changeTag"] as? Int64 { ws.changeTag = x }
        if let x = dict["isActive"] as? Bool { ws.isActive = x }
        if let x = dict["isSyncEnabled"] as? Bool { ws.isSyncEnabled = x }
        if let x = dict["name"] as? String { ws.name = x }
        if let x = dict["desc"] as? String { ws.desc = x }
        if let x = dict["saveResponse"] as? Bool { ws.saveResponse = x }
        if let x = dict["version"] as? Int64 { ws.version = x }
        db.saveMainContext()
        if let xs = dict["projects"] as? [[String: Any]] {
            xs.forEach { x in
                if let proj = EProject.fromDictionary(x) {
                    proj.workspace = ws
                }
            }
        }
        if let xs = dict["envs"] as? [[String: Any]] {
            xs.forEach { dict in
                _ = EEnv.fromDictionary(dict)
            }
        }
        db.saveMainContext()
        return ws
    }
    
    public func toDictionary() -> [String: Any] {
        let db = CoreDataService.shared
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["id"] = self.id
        dict["isActive"] = self.isActive
        dict["isSyncEnabled"] = self.isSyncEnabled
        dict["name"] = self.name
        dict["desc"] = self.desc
        dict["saveResponse"] = self.saveResponse
        dict["version"] = self.version
        var xs: [[String: Any]] = []
        let projs = CoreDataService.shared.getProjects(wsId: self.getId())
        projs.forEach { proj in
            xs.append(proj.toDictionary())
        }
        dict["projects"] = xs
        let envxs = db.getEnvs(wsId: self.getWsId())
        xs = []
        envxs.forEach { env in
            xs.append(env.toDictionary())
        }
        dict["envs"] = xs
        return dict
    }
}
