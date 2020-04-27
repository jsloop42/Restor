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
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["changeTag"] = self.changeTag as CKRecordValue
        record["desc"] = (self.desc ?? "") as CKRecordValue
        record["fieldFormat"] = self.fieldFormat as CKRecordValue
        record["id"] = self.getId() as CKRecordValue
        record["wsId"] = self.getWsId() as CKRecordValue
        record["key"] = (self.key ?? "") as CKRecordValue
        record["type"] = self.type as CKRecordValue
        record["value"] = (self.value ?? "") as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    /// Adds binary (ERequestBodyData) back reference to ERequestData.
    static func addRequestBodyDataReference(_ reqBodyData: CKRecord, toBinary reqData: CKRecord) {
        let ref = CKRecord.Reference(record: reqBodyData, action: .none)
        reqData["binary"] = ref
    }
    
    /// Adds a to-one reference to `form` field.
    static func addRequestBodyDataReference(_ requestBody: CKRecord, toForm reqData: CKRecord, type: RequestDataType) {
        let ref = CKRecord.Reference(record: requestBody, action: .none)
        let key: String = {
            if type == .form { return "form" }
            if type == .multipart { return "multipart" }
            return ""
        }()
        guard !key.isEmpty else { Log.error("Wrong type passed: \(type.rawValue)"); return }
        reqData[key] = ref
    }
    
    static func addRequestReference(_ request: CKRecord, toheader reqData: CKRecord) {
        let ref = CKRecord.Reference(record: request, action: .none)
        reqData["header"] = ref
    }
    
    static func addRequestReference(_ request: CKRecord, toParam reqData: CKRecord) {
        let ref = CKRecord.Reference(record: request, action: .none)
        reqData["param"] = ref
    }
    
    static func getRecordType(_ record: CKRecord) -> RequestDataType? {
        guard let x = record["type"] as? Int64, let type = RequestDataType(rawValue: x.toInt()) else { return nil }
        return type
    }
    
    static func getFormFieldFormatType(_ record: CKRecord) -> RequestBodyFormFieldFormatType {
        guard let x = record["fieldFormat"] as? Int64, let type = RequestBodyFormFieldFormatType(rawValue: x.toInt()) else { return .text }
        return type
    }
    
    static func getRequestDataFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequestData? {
        let reqDataId = CloudKitService.shared.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let reqData = CoreDataService.shared.getRequestData(id: reqDataId, ctx: ctx) { return reqData }
        let reqData = CoreDataService.shared.createRequestData(id: reqDataId, wsId: wsId, type: .form, fieldFormat: .file, checkExists: false, ctx: ctx)
        reqData?.changeTag = 0
        return reqData
    }
    
    /// Adds back reference to CoreData entity.
    static func addBackReference(record: CKRecord, reqData: ERequestData, ctx: NSManagedObjectContext) {
        if let ref = record["header"] as? CKRecord.Reference {
            reqData.header = ERequest.getRequestFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.header.rawValue.toInt64()
            return
        }
        if let ref = record["param"] as? CKRecord.Reference {
            reqData.param = ERequest.getRequestFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.param.rawValue.toInt64()
            return
        }
        if let ref = record["form"] as? CKRecord.Reference {
            reqData.form = ERequestBodyData.getRequestBodyDataFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.form.rawValue.toInt64()
            return
        }
        if let ref = record["multipart"] as? CKRecord.Reference {
            reqData.multipart = ERequestBodyData.getRequestBodyDataFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.multipart.rawValue.toInt64()
            return
        }
        if let ref = record["binary"] as? CKRecord.Reference {
            reqData.binary = ERequestBodyData.getRequestBodyDataFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.binary.rawValue.toInt64()
            return
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["changeTag"] as? Int64 { self.changeTag = x }
        if let x = record["desc"] as? String { self.desc = x }
        if let x = record["fieldFormat"] as? Int64 { self.fieldFormat = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["key"] as? String { self.key = x }
        if let x = record["type"] as? Int64 { self.type = x }
        if let x = record["value"] as? String { self.value = x }
        if let x = record["version"] as? Int64 { self.version = x }
        ERequestData.addBackReference(record: record, reqData: self, ctx: ctx)
    }
}
