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
    private var recordType: RecordType! = .none
    private var _recordType: String!
    public var opType: OpType = .fetchRecord
    private var _opType: String!
    private var predicate: NSPredicate = NSPredicate(value: true)
    private var cursor: CKQueryOperation.Cursor?
    private var changeTag: Int = 0
    private var limit = 50
    private var zoneID: CKRecordZone.ID!
    private var error: Error?
    public var completionHandler: ((Result<[CKRecord], Error>) -> Void)!
    private var block: ((EACloudOperation?) -> Void)?
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
    ///   - changeTag: Modified timestamp value when given will fetch record changes starting from that point. If none specified or 0, all changes will be fetched.
    ///   - completion: The callback function on completion.
    init(recordType: RecordType, opType: OpType, zoneID: CKRecordZone.ID, parentId: String, predicate: NSPredicate? = nil, changeTag: Int? = 0, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        self.recordType = recordType
        self._recordType = self.recordType.rawValue
        self.opType = opType
        self._opType = self.opType.rawValue
        self.zoneID = zoneID
        self.parentId = parentId
        if predicate != nil { self.predicate = predicate! }
        self.changeTag = changeTag ?? 0
        self.completionHandler = completion
    }
    
    init(recordType: RecordType, opType: OpType, zoneID: CKRecordZone.ID, parentId: String? = nil, predicate: NSPredicate? = nil, changeTag: Int? = 0, block: ((EACloudOperation?) -> Void)? = nil) {
        self.recordType = recordType
        self._recordType = self.recordType.rawValue
        self.opType = opType
        self._opType = self.opType.rawValue
        self.zoneID = zoneID
        self.parentId = parentId ?? ""
        if predicate != nil { self.predicate = predicate! }
        self.changeTag = changeTag ?? 0
        //self.completionHandler = completion
        self.block = block
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
    init(deleteRecordIDs: [CKRecord.ID], block: ((EACloudOperation?) -> Void)? = nil) {
        self.recordIDs = deleteRecordIDs
        self.opType = .deleteRecord
        self._opType = self.opType.rawValue
        self.block = block
    }
    
    /// Initialises in block opertion mode.
    /// - Parameter block: The block to be executed.
    init(block: @escaping (EACloudOperation?) -> Void) {
        self.block = block
        self.opType = .block
    }
    
    func getKey() -> String {
        return "\(self.recordType.rawValue)-\(self.opType)-\(self.parentId)"
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(self._recordType, forKey: "_recordType")
        coder.encode(self._opType, forKey: "_opType")
        if self.zoneID != nil { coder.encode(self.zoneID.encode(), forKey: "zoneID") }
        coder.encode(self.parentId, forKey: "parentId")
        coder.encode(self.predicate, forKey: "predicate")
        coder.encode(self.changeTag, forKey: "changeTag")
        coder.encode(self.recordIDs, forKey: "recordIDs")
    }
    
    required public init?(coder: NSCoder) {
        if let x = coder.decodeObject(forKey: "_recordType") as? String { self.recordType = RecordType(rawValue: x)! }
        if let x = coder.decodeObject(forKey: "_opType") as? String { self.opType = OpType(rawValue: x)! }
        if let data = coder.decodeObject(forKey: "zoneID") as? Data, let x = CKRecordZone.ID.decode(data) { self.zoneID = x }
        if let x = coder.decodeObject(forKey: "parentId") as? String { self.parentId = x }
        if let x = coder.decodeObject(forKey: "predicate") as? NSPredicate { self.predicate = x }
        if let x = coder.decodeObject(forKey: "changeTag") as? Int { self.changeTag = x }
        if let xs = coder.decodeObject(forKey: "recordIDs") as? [CKRecord.ID] { self.recordIDs = xs }
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
        self.block?(self)
    }
}
