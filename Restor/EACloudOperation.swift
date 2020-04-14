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
    var record: CKRecord?
    var type: String
    var zoneID: CKRecordZone.ID
    var recordID: CKRecord.ID
    var error: Error?
    
    public enum State: String {
        case ready, executing, finished

        fileprivate var keyPath: String {
            return "is" + rawValue.capitalized
        }
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
    
    init(type: String, recordID: CKRecord.ID, zoneID: CKRecordZone.ID) {
        self.type = type
        self.recordID = recordID
        self.zoneID = zoneID
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
        self.fetch()
    }
    
    private func fetch() {
        Log.debug("op fetching")
        CloudKitService.shared.fetchRecords(recordIDs: [self.recordID]) { [weak self] result in
            Log.debug("op fetch complete")
            guard let self = self else { return }
            switch result {
            case .success(let hm):
                self.record = hm[self.recordID]
            case .failure(let error):
                self.error = error
            }
            if self.isCancelled { self.state = .finished; return }
            self.state = .finished
        }
    }
}
