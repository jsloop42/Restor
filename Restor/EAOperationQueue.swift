//
//  EAOperationQueue.swift
//  Restor
//
//  Created by jsloop on 02/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

class EACloudOperation: Operation {
    var record: CKRecord?
    var type: String
    var zoneID: CKRecordZone.ID
    var recordID: CKRecord.ID
    var error: Error?
    
    init(type: String, recordID: CKRecord.ID, zoneID: CKRecordZone.ID) {
        self.type = type
        self.recordID = recordID
        self.zoneID = zoneID
    }
    
    override func main() {
        if self.isCancelled { return }
        self.fetch()
    }
    
    private func fetch() {
        CloudKitService.shared.fetchRecords(recordIDs: [self.recordID]) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let hm):
                self.record = hm[self.recordID]
            case .failure(let error):
                self.error = error
            }
        }
    }
}
