//
//  ERequestData.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestData: NSManagedObject, Entity {
    public var recordType: String { return "RequestData" }
    
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
        let type = RequestDataType(rawValue: self.type.toInt())!
        let wsId: String
        switch type {
        case .header:
            wsId = self.header!.project!.workspace!.id!
        case .param:
            wsId = self.param!.project!.workspace!.id!
        case .form:
            wsId = self.form!.request!.project!.workspace!.id!
        case .multipart:
            wsId = self.multipart!.request!.project!.workspace!.id!
        case .binary:
            wsId = self.binary!.request!.project!.workspace!.id!
        }
        return CloudKitService.shared.zoneID(workspaceId: wsId)
    }
    
    func updateCKRecord(_ record: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["desc"] = (self.desc ?? "") as CKRecordValue
        record["fieldFormat"] = self.fieldFormat as CKRecordValue
        record["id"] = self.id! as CKRecordValue
        record["index"] = self.index as CKRecordValue
        record["key"] = (self.key ?? "") as CKRecordValue
        record["type"] = self.type as CKRecordValue
        record["value"] = (self.value ?? "") as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    /// Adds a to-one reference to the `binary` field.
    static func addBinaryReference(_ requestData: CKRecord, binary: CKRecord) {
        let ref = CKRecord.Reference(record: binary, action: .none)
        requestData["binary"] = ref
    }
    
    /// Adds a to-many reference to `file` field.
    static func addFileReference(_ requestData: CKRecord, file: CKRecord) {
        var xs = requestData["file"] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
        let ref = CKRecord.Reference(record: file, action: .deleteSelf)
        if !xs.contains(ref) {
            xs.append(ref)
            requestData["files"] = xs
        }
    }
    
    /// Adds a to-one reference to `form` field.
    static func addFormReference(_ requestData: CKRecord, form: CKRecord, type: RequestDataType) {
        let ref = CKRecord.Reference(record: form, action: .deleteSelf)
        let key: String = {
            if type == .form { return "form" }
            if type == .multipart { return "multipart" }
            return ""
        }()
        guard !key.isEmpty else { Log.error("Wrong type passed: \(type.rawValue)"); return }
        requestData[key] = ref
    }
    
    /// Adds a to-one reference to `image` field.
    static func addImageReference(_ requestData: CKRecord, image: CKRecord) {
        let ref = CKRecord.Reference(record: image, action: .deleteSelf)
        requestData["image"] = ref
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["desc"] as? String { self.desc = x }
        if let x = record["fieldFormat"] as? Int64 { self.fieldFormat = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["index"] as? Int64 { self.index = x }
        if let x = record["key"] as? String { self.key = x }
        if let x = record["type"] as? Int64 { self.type = x }
        if let x = record["value"] as? String { self.value = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}
