//
//  CloudKitTests.swift
//  RestorTests
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import XCTest
@testable import Restor
import CloudKit

class CloudKitTests: XCTestCase {
    private let ck = CloudKitService.shared
    private let localdb = CoreDataService.shared
    private var zoneIDs: Set<CKRecordZone.ID> = Set()
    static var testsCount = testInvocations.count
    
    override func setUp() {
        super.setUp()
        CloudKitTests.testsCount -= 1
    }
    
    override func tearDown() {
        if CloudKitTests.testsCount == 0 {
            let sema = DispatchSemaphore(value: 0)
            var res: [Bool] = []
            let len = zoneIDs.count
            var count = 0
            self.zoneIDs.forEach { zoneID in
                self.ck.deleteZone(recordZoneId: zoneID) { result in
                    if case(.failure(_)) = result { res.append(false) } else { res.append(true) }
                    count += 1
                    if count == len { sema.signal() }
                }
            }
            sema.wait()
        }
        super.tearDown()
    }
    
    func testZoneCreatedKV() {
        let zId = self.ck.zoneID(with: "restor-test-kv")
        self.ck.setZoneCreated(zId)
        XCTAssertTrue(self.ck.isZoneCreated(zId))
        self.ck.removeZoneCreated(zId)
        XCTAssertFalse(self.ck.isZoneCreated(zId))
    }
    
    func testSaveRecord() {
        let exp = expectation(description: "save record")
        let wsId = "default-workspace"
        let recordType = "Workspace"
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let recordID = self.ck.recordID(entityId: "test-request-1", zoneID: zoneID)
        Log.debug("record name: \(recordID.recordName)")
        let record = CKRecord(recordType: recordType, recordID: recordID)
        self.ck.saveRecord(record, recordType: recordType) { result in
            if case .failure(_) = result { XCTFail() }
            self.ck.deleteRecord(recordID: recordID) { result in
                switch result {
                case .success(_):
                    exp.fulfill()
                case .failure(let error):
                    Log.error("Error: \(error)")
                    XCTFail()
                    exp.fulfill()
                }
            }
        }
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testSaveRecordFromEntity() {
        let exp = expectation(description: "save record from core data entity")
        let wsId = "workspace-id-1"
        let recordType = "Workspace"
        let reqId = "test-request-2"
        let zoneID = self.ck.zoneID(with: wsId)
        let recordID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        Log.debug("record name: \(recordID.recordName)")
        let record = CKRecord(recordType: recordType, recordID: recordID)
        guard let req = self.localdb.createRequest(id: reqId, index: 0, name: reqId) else { XCTFail(); exp.fulfill(); return }
        req.updateCKRecord(record)
        self.ck.saveRecord(record, recordType: recordType) { result in
            if case .failure(_) = result { XCTFail() }
            self.ck.deleteRecord(recordID: recordID) { result in
                switch result {
                case .success(_):
                    exp.fulfill()
                case .failure(let error):
                    Log.error("Error: \(error)")
                    XCTFail()
                    exp.fulfill()
                }
            }
        }
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
}
