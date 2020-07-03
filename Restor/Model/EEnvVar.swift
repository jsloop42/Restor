//
//  EEnvVar.swift
//  Restor
//
//  Created by jsloop on 16/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class EEnvVar: NSManagedObject, Entity {
    public var recordType: String { return "EnvVar" }
    private let secureTrans = SecureTransformerString()
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.env?.getWsId() ?? ""
    }
    
    public func setWsId(_ id: String) {
        fatalError("Not implemented")
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
    
    func updateCKRecord(_ record: CKRecord, env: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            if let name = self.name, let str = self.value as? String, let data = self.secureTrans.transformedValue(str) as? Data {
                let url = EAFileManager.getTemporaryURL(name)
                do {
                    try data.write(to: url)
                    record["value"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: env, action: .none)
            record["env"] = ref
        }
    }
        
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["value"] as? CKAsset, let url = x.fileURL {
                    do {
                        let data = try Data(contentsOf: url)
                        if let str = self.secureTrans.reverseTransformedValue(data) as? String {
                            self.value = str as NSObject
                        }
                        
                    } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["env"] as? CKRecord.Reference, let env = EEnv.getEnvFromReference(ref, record: record, ctx: moc) {
                    self.env = env
                }
            }
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EEnvVar? {
        guard let id = dict["id"] as? String else { return nil }
        let db = CoreDataService.shared
        guard let envVar = db.createEnvVar(name: "", value: "", id: id, checkExists: true, ctx: db.mainMOC) else { return nil }
        if let x = dict["created"] as? Int64 { envVar.created = x }
        if let x = dict["modified"] as? Int64 { envVar.modified = x }
        if let x = dict["changeTag"] as? Int64 { envVar.changeTag = x }
        if let x = dict["name"] as? String { envVar.name = x }
        if let x = dict["value"] as? String { envVar.value = x as NSObject }
        if let x = dict["version"] as? Int64 { envVar.version = x }
        envVar.markForDelete = false
        return envVar
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["id"] = self.id
        dict["name"] = self.name
        dict["value"] = self.value as? String ?? ""
        return dict
    }
}
