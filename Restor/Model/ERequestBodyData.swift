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
        return created
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
    
    func updateCKRecord(_ record: CKRecord, request: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["json"] = (self.json ?? "") as CKRecordValue
            record["raw"] = (self.raw ?? "") as CKRecordValue
            record["selected"] = self.selected as CKRecordValue
            record["version"] = self.version as CKRecordValue
            record["xml"] = (self.xml ?? "") as CKRecordValue
            let ref = CKRecord.Reference(record: request, action: .none)
            record["request"] = ref as CKRecordValue
        }
    }
    
    static func addBinaryToRequestBodyData(_ reqBodyData: CKRecord, binary: CKRecord) {
        let ref = CKRecord.Reference(record: binary, action: .deleteSelf)
        reqBodyData["binary"] = ref
    }
    
    static func getRequestBodyDataFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequestBodyData? {
        let reqBodyDataId = EACloudKit.shared.entityID(recordID: ref.recordID)
        if let bodyData = CoreDataService.shared.getRequestBodyData(id: reqBodyDataId, ctx: ctx) { return bodyData }
        let bodyData = CoreDataService.shared.createRequestBodyData(id: reqBodyDataId, wsId: record.getWsId(), checkExists: false, ctx: ctx)
        bodyData?.changeTag = 0
        return bodyData
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            if let x = record["created"] as? Int64 { self.created = x }
            if let x = record["modified"] as? Int64 { self.modified = x }
            if let x = record["changeTag"] as? Int64 { self.changeTag = x }
            if let x = record["id"] as? String { self.id = x }
            if let x = record["json"] as? String { self.json = x }
            if let x = record["raw"] as? String { self.raw = x }
            if let x = record["selected"] as? Int64 { self.selected = x }
            if let x = record["version"] as? Int64 { self.version = x }
            if let x = record["xml"] as? String { self.xml = x }
            if let ref = record["request"] as? CKRecord.Reference, let req = ERequest.getRequestFromReference(ref, record: record, ctx: moc) { self.request = req }
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ERequestBodyData? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        let db = CoreDataService.shared
        guard let body = db.createRequestBodyData(id: id, wsId: wsId, ctx: db.mainMOC) else { return nil }
        if let x = dict["created"] as? Int64 { body.created = x }
        if let x = dict["modified"] as? Int64 { body.modified = x }
        if let x = dict["changeTag"] as? Int64 { body.changeTag = x }
        if let x = dict["json"] as? String { body.json = x }
        if let x = dict["raw"] as? String { body.raw = x }
        if let x = dict["selected"] as? Int64 { body.selected = x }
        if let x = dict["xml"] as? String { body.xml = x }
        if let x = dict["version"] as? Int64 { body.version = x }
        if let hm = dict["binary"] as? [String: Any] {
            body.binary = ERequestData.fromDictionary(hm)
            body.binary?.binary = body
        }
        if let xs = dict["form"] as? [[String: Any]] {
            xs.forEach { hm in
                if let form = ERequestData.fromDictionary(hm) {
                    form.form = body
                }
            }
        }
        if let xs = dict["multipart"] as? [[String: Any]] {
            xs.forEach { hm in
                if let mp = ERequestData.fromDictionary(hm) {
                    mp.multipart = body
                }
            }
        }
        body.markForDelete = false
        db.saveMainContext()
        return body
    }
    
    public func toDictionary() -> [String : Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["id"] = self.id
        dict["wsId"] = self.wsId
        dict["json"] = self.json
        dict["raw"] = self.raw
        dict["selected"] = self.selected
        dict["xml"] = self.xml
        dict["version"] = self.version
        if let bin = self.binary {
            dict["binary"] = bin.toDictionary()
        }
        var acc: [[String: Any]] = []
        if let xs = self.form?.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.markForDelete { acc.append(reqData.toDictionary()) }
            }
            dict["form"] = acc
        }
        acc = []
        if let xs = self.multipart?.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.markForDelete { acc.append(reqData.toDictionary()) }
            }
            dict["multipart"] = acc
        }
        return dict
    }
}
