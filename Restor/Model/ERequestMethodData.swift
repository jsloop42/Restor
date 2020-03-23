//
//  ERequestMethodData.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestMethodData: NSManagedObject, Entity {
    public func getId() -> String? {
        return self.id
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
    
    func updateCKRecord(_ record: CKRecord, project: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["id"] = self.id! as CKRecordValue
        record["index"] = self.index as CKRecordValue
        record["isCustom"] = self.isCustom as CKRecordValue
        record["name"] = (self.name ?? "") as CKRecordValue
        record["shouldDelete"] = self.shouldDelete as CKRecordValue
        record["version"] = self.version as CKRecordValue
        let ref = CKRecord.Reference(record: project, action: .none)
        record["project"] = ref as CKRecordValue
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["index"] as? Int64 { self.index = x }
        if let x = record["isCustom"] as? Bool { self.isCustom = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["shouldDelete"] as? Bool { self.shouldDelete = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}
