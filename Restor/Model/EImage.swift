//
//  EImage.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EImage: NSManagedObject, Entity {
    public var recordType: String { return "Image" }
    
    public func getId() -> String {
        return self.id ?? ""
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
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func getZoneID() -> CKRecordZone.ID {
        return self.requestData!.getZoneID()
    }
    
    func updateCKRecord(_ record: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        if let name = self.name, let data = self.data {
            let url = EAFileManager.getTemporaryURL(name)
            do {
                try data.write(to: url)
                record["data"] = CKAsset(fileURL: url)
            } catch let error {
                Log.error("Error: \(error)")
            }
        }
        record["id"] = self.id! as CKRecordValue
        record["index"] = self.index as CKRecordValue
        record["isCameraMode"] = self.isCameraMode as CKRecordValue
        record["name"] = (self.name ?? "") as CKRecordValue
        record["type"] = (self.type ?? "") as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["data"] as? CKAsset, let url = x.fileURL {
            do { self.data = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
        }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["index"] as? Int64 { self.index = x }
        if let x = record["isCameraMode"] as? Bool { self.isCameraMode = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["type"] as? String { self.type = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}
