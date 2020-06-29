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
    
    func updateCKRecord(_ record: CKRecord, project: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["envId"] = (self.envId ?? "") as CKRecordValue
            record["name"] = self.name! as CKRecordValue
            record["validateSSL"] = self.validateSSL as CKRecordValue
            record["selectedMethodIndex"] = self.selectedMethodIndex as CKRecordValue
            record["url"] = (self.url ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: project, action: .none)
            record["project"] = ref
        }
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
    
    static func getRequestFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequest? {
        let reqId = EACloudKit.shared.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let req = CoreDataService.shared.getRequest(id: reqId, ctx: ctx) { return req }
        let req = CoreDataService.shared.createRequest(id: reqId, wsId: wsId, name: "", checkExists: false, ctx: ctx)
        req?.changeTag = 0
        return req
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["wsId"] as? String { self.wsId = x }
                if let x = record["desc"] as? String { self.desc = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["validateSSL"] as? Bool { self.validateSSL = x }
                if let x = record["selectedMethodIndex"] as? Int64 { self.selectedMethodIndex = x }
                if let x = record["url"] as? String { self.url = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["project"] as? CKRecord.Reference, let proj = EProject.getProjectFromReference(ref, record: record, ctx: moc) { self.project = proj }
            }
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ERequest? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        let db = CoreDataService.shared
        guard let req = db.createRequest(id: id, wsId: wsId, name: "") else { return nil }
        if let x = dict["created"] as? Int64 { req.created = x }
        if let x = dict["modified"] as? Int64 { req.modified = x }
        if let x = dict["changeTag"] as? Int64 { req.changeTag = x }
        if let x = dict["desc"] as? String { req.desc = x }
        if let x = dict["name"] as? String { req.name = x }
        if let x = dict["validateSSL"] as? Bool { req.validateSSL = x }
        if let x = dict["selectedMethodIndex"] as? Int64 { req.selectedMethodIndex = x }
        if let x = dict["url"] as? String { req.url = x }
        if let x = dict["version"] as? Int64 { req.version = x }
        if let dict = dict["body"] as? [String: Any] {
            if let body = ERequestBodyData.fromDictionary(dict) {
                req.body = body
            }
        }
        if let xs = dict["headers"] as? [[String: Any]] {
            xs.forEach { dict in
                if let reqData = ERequestData.fromDictionary(dict) {
                    reqData.header = req
                }
            }
        }
        if let xs = dict["params"] as? [[String: Any]] {
            xs.forEach { dict in
                if let reqData = ERequestData.fromDictionary(dict) {
                    reqData.param = req
                }
            }
        }
        db.saveMainContext()
        return req
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["id"] = self.id
        dict["wsId"] = self.wsId
        dict["desc"] = self.desc
        dict["name"] = self.name
        dict["validateSSL"] = self.validateSSL
        dict["selectedMethodIndex"] = self.selectedMethodIndex
        dict["url"] = self.url
        dict["version"] = self.version
        if let body = self.body {
            dict["body"] = body.toDictionary()
        }
        let db = CoreDataService.shared
        let headers = db.getHeadersRequestData(self.getId())
        var xs: [[String: Any]] = []
        headers.forEach { header in
            xs.append(header.toDictionary())
        }
        dict["headers"] = xs
        xs = []
        let params = db.getParamsRequestData(self.getId())
        params.forEach { param in
            xs.append(param.toDictionary())
        }
        dict["params"] = xs
        xs = []
        return dict
    }
}
