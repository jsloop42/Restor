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
class EACloudOperation: Operation, NSSecureCoding {
    var parentId: String!
    var record: CKRecord?
    var savedRecords: [CKRecord] = []
    var deletedRecordIDs: [CKRecord.ID] = []
    var recordType: RecordType!
    private var _recordType: String!
    var opType: OpType = .fetchRecord
    private var _opType: String!
    var predicate: NSPredicate = NSPredicate(value: true)
    var cursor: CKQueryOperation.Cursor?
    var modified: Int!
    var limit = 50
    var zoneID: CKRecordZone.ID!
    var error: Error?
    var completionHandler: ((Result<[CKRecord], Error>) -> Void)!
    var block: (() -> Void)?
    
    public enum State: String {
        case ready, executing, finished

        fileprivate var keyPath: String {
            return "is" + rawValue.capitalized
        }
    }
    
    public enum OpType: String {
        case fetchRecord
        case queryRecord
        case fetchZoneChange
        case block
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
    
    /// Query record changes
    init(recordType: RecordType, opType: OpType, zoneID: CKRecordZone.ID, parentId: String, predicate: NSPredicate? = nil, modified: Int? = 0, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        self.recordType = recordType
        self._recordType = self.recordType.rawValue
        self.opType = opType
        self._opType = self.opType.rawValue
        self.zoneID = zoneID
        self.parentId = parentId
        if predicate != nil { self.predicate = predicate! }
        self.modified = modified ?? 0
        self.completionHandler = completion
    }
    
    /// Fetch zone changes
    init(recordType: RecordType, opType: OpType, zoneID: CKRecordZone.ID) {
        self.recordType = recordType
        self._recordType = self.recordType.rawValue
        self.opType = opType
        self._opType = self.opType.rawValue
        self.zoneID = zoneID
        self.parentId = ""
        self.modified = modified ?? 0
    }
    
    init(block: @escaping () -> Void) {
        self.block = block
        self.opType = .block
    }
    
    func getKey() -> String {
        return "\(self.recordType.rawValue)-\(self.opType)-\(self.parentId ?? "")"
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(self._recordType, forKey: "_recordType")
        coder.encode(self._opType, forKey: "_opType")
        coder.encode(self.zoneID.encode(), forKey: "zoneID")
        coder.encode(self.parentId, forKey: "parentId")
        coder.encode(self.predicate, forKey: "predicate")
        coder.encode(self.modified, forKey: "modified")
    }
    
    required init?(coder: NSCoder) {
        if let x = coder.decodeObject(forKey: "_recordType") as? String { self.recordType = RecordType(rawValue: x)! }
        if let x = coder.decodeObject(forKey: "_opType") as? String { self.opType = OpType(rawValue: x)! }
        if let data = coder.decodeObject(forKey: "zoneID") as? Data, let x = CKRecordZone.ID.decode(data) { self.zoneID = x }
        if let x = coder.decodeObject(forKey: "parentId") as? String { self.parentId = x }
        if let x = coder.decodeObject(forKey: "predicate") as? NSPredicate { self.predicate = x }
        if let x = coder.decodeObject(forKey: "modified") as? Int { self.modified = x }
    }
    
    static func encode(_ op: EACloudOperation) -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: op, requiringSecureCoding: true)
    }
    
    func encode() -> Data? {
        return EACloudOperation.encode(self)
    }
    
    static func decode(_ data: Data) -> EACloudOperation? {
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: EACloudOperation.self, from: data)
    }
    
    static var supportsSecureCoding: Bool = true
    
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
        case .block:
            self.execBlock()
        }
    }
    
    private func execBlock() {
        if let block = self.block { block() }
    }
    
    private func fetchRecord() {
        fatalError("not implemented")
    }
    
    private func queryRecord() {
        PersistenceService.shared.queryRecords(zoneID: self.zoneID, type: self.recordType, parentId: self.parentId, modified: self.modified) { result in
            if self.isCancelled { return }
            self.state = .finished
            self.completionHandler(result)
        }
    }
    
    private func fetchZoneChanges() {
        PersistenceService.shared.fetchZoneChanges(zoneIDs: [self.zoneID], isDeleteOnly: true)
    }
}
