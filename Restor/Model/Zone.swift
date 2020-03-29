//
//  Zone.swift
//  Restor
//
//  Created by jsloop on 29/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

/// This is a zone file which will be added as a record in the default zone against each custom zone created which corresponds to each workspace
/// This helps in fetching records with a cursor instead of having to fetch all custom zone to get the workspaces list.
struct Zone {
    var id: String  // The workspace Id
    /// Since zone corresponds to workspace, and we are fetching this, fields like name, desc are added here to make things faster. We don't however keep the
    /// workspace as such in the default zone because we need atomic operations and references.
    var name: String
    var desc: String
    var isSyncEnabled: Bool
    var created: Int64 = Date().currentTimeNanos()
    var modified: Int64 = Date().currentTimeNanos()
    var version: Int64 = 0
    
    func updateCKRecord(_ record: CKRecord) {
        record["id"] = self.id as CKRecordValue
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["name"] = self.name as CKRecordValue
        record["desc"] = self.desc as CKRecordValue
        record["isSyncEnabled"] = self.isSyncEnabled as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    mutating func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["id"] as? String { self.id = x }
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["desc"] as? String { self.desc = x }
        if let x = record["isSyncEnabled"] as? Bool { self.isSyncEnabled = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}
