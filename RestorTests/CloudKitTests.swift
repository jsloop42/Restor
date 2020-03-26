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
            _ = self.deleteZones()
        }
        super.tearDown()
    }
    
    func deleteZones() -> Bool {
        let sema = DispatchSemaphore(value: 0)
        self.ck.deleteZone(recordZoneIds: self.zoneIDs.toArray()) { _ in sema.signal() }
        sema.wait()
        return true
    }
    
    func testDeleteZone() {
        self.zoneIDs.insert(self.ck.zoneID(with: "workspace-id-1"))
        self.zoneIDs.insert(self.ck.zoneID(with: "ws-default-workspace"))
        XCTAssertTrue(self.deleteZones())
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
            self.ck.deleteRecords(recordIDs: [recordID]) { result in
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
        let wsRecordID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
        let projRecordID = self.ck.recordID(entityId: projId, zoneID: zoneID)
        let reqRecordID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        guard let ws = self.localdb.createWorkspace(id: wsId, index: 0, name: wsId, desc: "test workspace", isSyncEnabled: true) else { XCTFail(); return }
        guard let proj = self.localdb.createProject(id: projId, index: 0, name: projId, desc: "test project description") else { XCTFail(); return }
        proj.workspace = ws
        guard let req = self.localdb.createRequest(id: reqId, index: 0, name: reqId) else { XCTFail(); exp.fulfill(); return }
        req.project = proj
        req.desc = "test request description"
        let ckws = self.ck.createRecord(recordID: wsRecordID, recordType: "Workspace")
        ws.updateCKRecord(ckws)
        let ckproj = self.ck.createRecord(recordID: projRecordID, recordType: "Project")
        proj.updateCKRecord(ckproj, workspace: ckws)
        EWorkspace.addProjectReference(to: ckws, project: ckproj)  // add project reference to workspace
        let ckreq = self.ck.createRecord(recordID: reqRecordID, recordType: "Request")
        req.updateCKRecord(ckreq, project: ckproj)
        EProject.addRequestReference(to: ckproj, request: ckreq)  // add req reference to project
        self.ck.saveRecords([ckws, ckproj, ckreq]) { result in
            if case .failure(_) = result { XCTFail("Error saving record") }
            self.ck.deleteRecords(recordIDs: [wsRecordID, projRecordID, reqRecordID]) { result in
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
    
    func testCKRecordFromRequestDataWithFile() {
        let exp = expectation(description: "save ckrecord from request data with file attachment")
        let text = "Freedom is priceless"
        guard let data = text.data(using: .utf8, allowLossyConversion: false) else { XCTFail("data is empty"); return }
        let reqId = "test-req-data-file"
        let fileId = "test-file"
        let zoneID = self.ck.zoneID(with: "workspace-id-1")
        guard let reqData = self.localdb.createRequestData(id: reqId, index: 0, type: .binary, fieldFormat: .file) else { XCTFail("ERequestData creation error"); return }
        guard let file = self.localdb.createFile(data: data, index: 0, name: "test-file", path: URL(fileURLWithPath: "/tmp")) else { XCTFail("EFile creation error"); return }
        reqData.addToFiles(file)
        let ckFileID = self.ck.recordID(entityId: fileId, zoneID: zoneID)
        let ckReqDataID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        let ckReqData = self.ck.createRecord(recordID: ckReqDataID, recordType: "RequestData")
        let ckFile = self.ck.createRecord(recordID: ckFileID, recordType: "File")
        reqData.updateCKRecord(ckReqData)
        ERequestData.addFileReference(ckReqData, file: ckFile)
        file.updateCKRecord(ckFile)
        EFile.addRequestDataReference(ckFile, reqData: ckReqData)
        self.ck.saveRecords([ckFile, ckReqData]) { result in
            switch result {
            case .success(let res):
                XCTAssertTrue(!res.isEmpty)
            case .failure(_):
                XCTFail("Error saving record")
            }
            self.ck.deleteRecords(recordIDs: [ckFileID, ckReqDataID]) { result in
                switch result {
                case .success(let res):
                    XCTAssertTrue(res)
                case .failure(_):
                    XCTFail("Error deleting record")
                }
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
