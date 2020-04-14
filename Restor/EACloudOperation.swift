//
//  EACloudOperation.swift
//  Restor
//
//  Created by jsloop on 02/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

/// A class to work with CloudKit record fetch using Operation.
class EACloudOperation: Operation {
    var parentId: String!
    var record: CKRecord?
    var savedRecords: [CKRecord] = []
    var deletedRecordIDs: [CKRecord.ID] = []
    var recordType: RecordType
    var opType: OpType = .fetchRecord
    var predicate: NSPredicate?
    var cursor: CKQueryOperation.Cursor?
    var limit = 50
    var zoneID: CKRecordZone.ID!
    var error: Error?
    var completionHandler: ((Result<[CKRecord], Error>) -> Void)!
    
    public enum State: String {
        case ready, executing, finished

        fileprivate var keyPath: String {
            return "is" + rawValue.capitalized
        }
    }
    
    public enum OpType {
        case fetchRecord
        case queryRecord
        case fetchZoneChange
    }
    
    public var state = State.ready {
        willSet {
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
    
    init(recordType: RecordType, opType: OpType, zoneID: CKRecordZone.ID, parentId: String, predicate: NSPredicate, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        self.recordType = recordType
        self.opType = opType
        self.zoneID = zoneID
        self.parentId = parentId
        self.predicate = predicate
        self.completionHandler = completion
    }
    
    override var isAsynchronous: Bool { return true }

    override var isExecuting: Bool { return state == .executing }

    override var isFinished: Bool { return state == .finished }

    override func start() {
        if self.isCancelled { return }
        main()
        state = .executing
    }
    
    override func main() {
        if self.isCancelled { return }
        switch self.opType {
        case .fetchRecord:
            self.fetchRecord()
        case .queryRecord:
            self.queryRecord()
        case .fetchZoneChange:
            self.fetchZoneChanges()
        }
    }
    
    private func fetchRecord() {
    }
    
    private func queryRecord() {
        PersistenceService.shared.queryRecords(zoneID: self.zoneID, type: self.recordType, parentId: self.parentId) { result in
            if self.isCancelled { return }
            self.state = .finished
            self.completionHandler(result)
        }
    }
    
    private func fetchZoneChanges() {
        
    }
}
