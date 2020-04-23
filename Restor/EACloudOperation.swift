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
public class EACloudOperation: Operation, NSSecureCoding {
    private var parentId: String = ""
    private var record: CKRecord?
    private var savedRecords: [CKRecord] = []
    private var deletedRecordIDs: [CKRecord.ID] = []
    private var recordType: RecordType!
    private var _recordType: String!
    public var opType: OpType = .fetchRecord
    private var _opType: String!
    private var predicate: NSPredicate = NSPredicate(value: true)
    private var cursor: CKQueryOperation.Cursor?
    private var modified: Int = 0
    private var limit = 50
    private var zoneID: CKRecordZone.ID!
    private var error: Error?
    public var completionHandler: ((Result<[CKRecord], Error>) -> Void)!
    private var block: (() -> Void)?
    private var recordIDs: [CKRecord.ID] = []
    private var deleteRecordBlock: ((Result<[CKRecord.ID], Error>) -> Void)?
    
    public enum State: String {
        case ready, executing, finished

        fileprivate var keyPath: String {
            return "is" + rawValue.capitalized
        }
    }
    
    public enum OpType: String {
        case fetchRecord
        case queryRecord
        case deleteRecord
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
    
    /// Initialise for query record changes operation.
    /// - Parameters:
    ///   - recordType: The record type.
    ///   - opType: The operation type.
    ///   - zoneID: The zone ID for the records.
    ///   - parentId: The parent id for the record.
    ///   - predicate: An optional predicate statement.
    ///   - modified: Modified timestamp value when given will fetch record changes starting from that point. If none specified or 0, all changes will be fetched.
    ///   - completion: The callback function on completion.
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
    
    
    /// Initialise with fetch zone changes.
    /// - Parameters:
    ///   - recordType: The record type.
    ///   - opType: The operation.
    ///   - zoneID: The zone ID for the record.
    init(recordType: RecordType, opType: OpType, zoneID: CKRecordZone.ID) {
        self.recordType = recordType
        self._recordType = self.recordType.rawValue
        self.opType = opType
        self._opType = self.opType.rawValue
        self.zoneID = zoneID
    }
    
    /// Initialise with delete records operation.
    /// - Parameters:
    ///   - deleteRecordIDs: The ID of the records.
    ///   - zoneID: The zone ID for the records.
    ///   - completion: The completion callback function.
    init(deleteRecordIDs: [CKRecord.ID], zoneID: CKRecordZone.ID, completion: ((Result<[CKRecord.ID], Error>) -> Void)? = nil) {
        self.recordIDs = deleteRecordIDs
        self.zoneID = zoneID
        self.opType = .deleteRecord
        self._opType = self.opType.rawValue
        self.deleteRecordBlock = completion
    }
    
    
    /// Initialises in block opertion mode.
    /// - Parameter block: The block to be executed.
    init(block: @escaping () -> Void) {
        self.block = block
        self.opType = .block
    }
    
    func getKey() -> String {
        return "\(self.recordType.rawValue)-\(self.opType)-\(self.parentId)"
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(self._recordType, forKey: "_recordType")
        coder.encode(self._opType, forKey: "_opType")
        coder.encode(self.zoneID.encode(), forKey: "zoneID")
        coder.encode(self.parentId, forKey: "parentId")
        coder.encode(self.predicate, forKey: "predicate")
        coder.encode(self.modified, forKey: "modified")
    }
    
    required public init?(coder: NSCoder) {
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
    
    public static var supportsSecureCoding: Bool = true
    
    override public var isAsynchronous: Bool { return true }

    override public var isExecuting: Bool { return state == .executing }

    override public var isFinished: Bool { return state == .finished }

    override public func start() {
        if self.isCancelled { return }
        main()
        state = .executing
    }
    
    override public func main() {
        if self.isCancelled { return }
        switch self.opType {
        case .fetchRecord:
            self.fetchRecord()
        case .queryRecord:
            self.queryRecord()
        case .deleteRecord:
            self.deleteRecords()
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
        PersistenceService.shared.queryRecords(zoneID: self.zoneID, type: self.recordType, parentId: self.parentId, modified: self.modified) { [weak self] result in
            guard let self = self else { return }
            if self.isCancelled { return }
            self.state = .finished
            self.completionHandler(result)
        }
    }
    
    private func deleteRecords() {
        CloudKitService.shared.deleteRecords(recordIDs: self.recordIDs) { [weak self] result in self?.deleteRecordBlock?(result) }
    }
    
    private func fetchZoneChanges() {
        PersistenceService.shared.fetchZoneChanges(zoneIDs: [self.zoneID], isDeleteOnly: true)
    }
}
