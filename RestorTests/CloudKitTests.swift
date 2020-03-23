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
        self.ck.saveRecords([record]) { result in
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
        let reqId = "test-request-2"
        let projId = "test-project-1"
        let zoneID = self.ck.zoneID(with: wsId)
        let recordID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        Log.debug("record name: \(recordID.recordName)")
        guard let ws = self.localdb.createWorkspace(id: wsId, index: 0, name: wsId, desc: "test workspace", isSyncEnabled: true) else { XCTFail(); return }
        guard let proj = self.localdb.createProject(id: projId, index: 0, name: projId, desc: "test project description") else { XCTFail(); return }
        proj.workspace = ws
        guard let req = self.localdb.createRequest(id: reqId, index: 0, name: reqId) else { XCTFail(); exp.fulfill(); return }
        req.project = proj
        req.desc = "test request description"
        let ckws = self.ck.createRecord(recordID: self.ck.recordID(entityId: wsId, zoneID: zoneID), recordType: "Workspace")
        ws.updateCKRecord(ckws)
        let ckproj = self.ck.createRecord(recordID: self.ck.recordID(entityId: projId, zoneID: zoneID), recordType: "Project")
        proj.updateCKRecord(ckproj, workspace: ckws)
        // TODO: add proj reference to workspace
        let ckreq = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqId, zoneID: zoneID), recordType: "Request")
        req.updateCKRecord(ckreq, project: ckproj)
        // TODO: add req reference to project
        self.ck.saveRecords([ckws, ckproj, ckreq]) { result in
            if case .failure(_) = result { XCTFail() }
            exp.fulfill()
//            self.ck.deleteRecord(recordID: recordID) { result in
//                switch result {
//                case .success(_):
//                    exp.fulfill()
//                case .failure(let error):
//                    Log.error("Error: \(error)")
//                    XCTFail()
//                    exp.fulfill()
//                }
//            }
        }
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
}
