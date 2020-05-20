//
//  EHistory.swift
//  Restor
//
//  Created by jsloop on 20/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class EHistory: NSManagedObject, Entity {
    public var recordType: String { return "History" }
    
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
        return ""
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
        
    }
    
    public func updateCKRecord(_ record: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["request"] = (self.request ?? "") as CKRecordValue
            record["requestId"] = (self.requestId ?? "") as CKRecordValue
            record["response"] = (self.response ?? "") as CKRecordValue
            record["responseHeaders"] = (self.responseHeaders ?? "") as CKRecordValue
            record["statusCode"] = self.statusCode as CKRecordValue
            record["version"] = self.version as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
        }
    }
    
    public func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["request"] as? String { self.request = x }
                if let x = record["requestId"] as? String { self.requestId = x }
                if let x = record["response"] as? String { self.response = x }
                if let x = record["responseHeaders"] as? String { self.responseHeaders = x }
                if let x = record["statusCode"] as? Int64 { self.statusCode = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let x = record["wsId"] as? String { self.wsId = x }
            }
        }
    }
}
