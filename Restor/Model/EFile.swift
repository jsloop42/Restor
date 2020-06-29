//
//  EFile.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EFile: NSManagedObject, Entity {
    public var recordType: String { return "File" }
    
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
        self.managedObjectContext?.performAndWait {
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
            record["name"] = (self.name ?? "") as CKRecordValue
            record["type"] = self.type as CKRecordValue
            record["version"] = self.version as CKRecordValue
        }
    }
    
    static func addRequestDataReference(_ file: CKRecord, reqData: CKRecord) {
        let ref = CKRecord.Reference(record: reqData, action: .none)
        file["requestData"] = ref as CKRecordValue
    }
    
    static func getRequestData(_ record: CKRecord, ctx: NSManagedObjectContext) -> ERequestData? {
        if let ref = record["requestData"] as? CKRecord.Reference {
            return CoreDataService.shared.getRequestData(id: EACloudKit.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["data"] as? CKAsset, let url = x.fileURL {
                    do { self.data = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["type"] as? Int64 { self.type = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["requestData"] as? CKRecord.Reference, let reqData = ERequestData.getRequestDataFromReference(ref, record: record, ctx: moc) {
                    self.requestData = reqData
                }
            }
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EFile? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String, let data = dict["data"] as? Data,
            let name = dict["name"] as? String, let _type = dict["type"] as? Int64, let type = RequestDataType(rawValue: _type.toInt()) else { return nil }
        let db = CoreDataService.shared
        guard let file = db.createFile(fileId: id, data: data, wsId: wsId, name: name, path: URL(fileURLWithPath: "/tmp/"), type: type, checkExists: true, ctx: db.mainMOC) else { return nil }
        if let x = dict["created"] as? Int64 { file.created = x }
        if let x = dict["modified"] as? Int64 { file.modified = x }
        if let x = dict["changeTag"] as? Int64 { file.changeTag = x }
        if let x = dict["version"] as? Int64 { file.version = x }
        return file
    }
    
    public func toDictionary() -> [String : Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["id"] = self.id
        dict["name"] = self.name
        dict["type"] = self.type
        dict["version"] = self.version
        dict["data"] = self.data
        dict["wsId"] = self.wsId
        return dict
    }
}
