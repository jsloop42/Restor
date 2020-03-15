//
//  RestorTests.swift
//  RestorTests
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import XCTest
@testable import Restor
import CoreData

class RestorTests: XCTestCase {
    private var localdb = CoreDataService.shared
    private let utils = Utils.shared
    private let serialQueue = DispatchQueue(label: "serial-queue")
    private let app = App.shared

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func testGenRandom() {
        let x = self.utils.genRandomString()
        XCTAssertEqual(x.count, 20)
    }
    
    // MARK: - CoreData tests
    
    func testCoreDataSetupCompletion() {
        let exp = expectation(description: "CoreData setup completion")
        self.localdb.setup { exp.fulfill() }
        waitForExpectations(timeout: 1.0) { _ in XCTAssertTrue(self.localdb.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0) }
    }
    
    func testCoreDataPersistenceStoreCreated() {
        let exp = expectation(description: "CoreData setup create store")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            XCTAssertTrue(self.localdb.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testCoreDataPersistenceLoadedOnDisk() {
        let exp = expectation(description: "CoreData persistence container loaded on disk")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.persistentContainer.persistentStoreDescriptions.first?.type, NSSQLiteStoreType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0) { _ in
            let pc = self.localdb.persistentContainer.persistentStoreCoordinator
            let url = pc.url(for: pc.persistentStores.first!)
            _ = try? pc.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: [:])
        }
    }
    
    func testCoreDataBackgroundContextConcurrencyType() {
        let exp = expectation(description: "background context")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.bgMOC.concurrencyType, .privateQueueConcurrencyType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testCoreDataMainContextConcurrencyType() {
        let exp = expectation(description: "main context")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.mainMOC.concurrencyType, .mainQueueConcurrencyType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testCoreData() {
        let exp = expectation(description: "test core data")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let lws = self.localdb.createWorkspace(id: "test-ws", index: 0, name: "test-ws", desc: "")
                XCTAssertNotNil(lws)
                guard let ws = lws else { return }
                XCTAssertEqual(ws.name, "test-ws")
                self.localdb.saveBackgroundContext()
                self.localdb.deleteEntity(ws)
                let aws = self.localdb.getWorkspace(id: "test-ws")
                XCTAssertNil(aws)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testEntitySorting() {
        let exp = expectation(description: "test core data sorting")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let wsname = "test-ws"
                let rws = self.localdb.createWorkspace(id: wsname, index: 0, name: wsname, desc: "")
                XCTAssertNotNil(rws)
                guard let ws = rws else { return }
                ws.name = wsname
                ws.desc = "test description"
                let wproj1 = self.localdb.createProject(id: "test-project-22", index: 0, name: "test-project-22", desc: "")
                XCTAssertNotNil(wproj1)
                guard let proj1 = wproj1 else { return }
                let wproj2 = self.localdb.createProject(id: "test-project-11", index: 1, name: "test-project-11", desc: "")
                XCTAssertNotNil(wproj2)
                guard let proj2 = wproj2 else { return }
                let wproj3 = self.localdb.createProject(id: "test-project-33", index: 2, name: "test-project-33", desc: "")
                XCTAssertNotNil(wproj3)
                guard let proj3 = wproj3 else { return }
                ws.projects = NSSet(array: [proj1, proj2, proj3])
                self.localdb.saveBackgroundContext()
                
                // ws2
                let wsname2 = "test-ws-2"
                let rws2 = self.localdb.createWorkspace(id: wsname2, index: 1, name: wsname2, desc: "")
                XCTAssertNotNil(rws2)
                guard let ws2 = rws2 else { return }
                ws2.name = wsname2
                ws2.desc = "test description 2"
                let wproj21 = self.localdb.createProject(id: "ws2-test-project-22", index: 0, name: "ws2-test-project-22", desc: "")
                XCTAssertNotNil(wproj21)
                guard let proj21 = wproj21 else { return }
                let wproj22 = self.localdb.createProject(id: "ws2-test-project-11", index: 1, name: "ws2-test-project-11", desc: "")
                XCTAssertNotNil(wproj22)
                guard let proj22 = wproj22 else { return }
                let wproj23 = self.localdb.createProject(id: "ws2-test-project-33", index: 2, name: "ws2-test-project-33", desc: "")
                XCTAssertNotNil(wproj23)
                guard let proj23 = wproj23 else { return }
                ws2.projects = NSSet(array: [proj21, proj22, proj23])
                self.localdb.saveBackgroundContext()
                
                let lws = self.localdb.getWorkspace(id: wsname)
                XCTAssertNotNil(lws)
                let projxs = self.localdb.getProjects(wsId: ws.getId()!)
                XCTAssert(projxs.count == 3)
                Log.debug("projxs: \(projxs)")
                XCTAssertEqual(projxs[0].name, "test-project-22")
                XCTAssertEqual(projxs[1].name, "test-project-11")
                XCTAssertEqual(projxs[2].name, "test-project-33")
                
                let lws2 = self.localdb.getWorkspace(id: wsname2)
                XCTAssertNotNil(lws2)
                let projxs2 = self.localdb.getProjects(wsId: ws2.getId()!)
                XCTAssert(projxs2.count == 3)
                Log.debug("projxs: \(projxs2)")
                XCTAssertEqual(projxs2[0].name, "ws2-test-project-22")
                XCTAssertEqual(projxs2[1].name, "ws2-test-project-11")
                XCTAssertEqual(projxs2[2].name, "ws2-test-project-33")
                
                // cleanup
                projxs.forEach { p in self.localdb.deleteEntity(p) }
                projxs2.forEach { p in self.localdb.deleteEntity(p) }
                self.localdb.deleteEntity(ws)
                self.localdb.deleteEntity(ws)
                self.localdb.saveBackgroundContext()
                self.localdb.discardChanges(in: self.localdb.bgMOC)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testMD5ofData() {
        let data = "hello world".data(using: .utf8)
        XCTAssertNotNil(data)
        let md5 = self.utils.md5(data: data!)
        XCTAssertEqual(md5, "5eb63bbbe01eeed093cb22bb8f5acdc3")
    }
    
    func testEntityCRUD() {
        let exp = expectation(description: "Test core data CRUD")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let moc = self.localdb.bgMOC
                let mreq = self.localdb.createRequest(id: "edit-req", index: 0, name: "Edit request", ctx: moc)
                XCTAssertNotNil(mreq)
                guard let req = mreq else { XCTFail(); return }
                guard let reqId = req.id else { XCTFail(); return }
                let ctx = req.managedObjectContext!
                let mh0 = self.localdb.createRequestData(id: "header-data-0", index: 0, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(mh0)
                guard let h0 = mh0 else { XCTFail(); return }
                h0.key = "h0"
                h0.value = "v0"
                req.addToHeaders(h0)
                XCTAssertNotNil(req.headers)
                XCTAssertEqual(req.headers!.count, 1)
                let mh1 = self.localdb.createRequestData(id: "header-data-1", index: 1, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(mh1)
                guard let h1 = mh1 else { XCTFail(); return }
                h1.key = "h1"
                h1.value = "v1"
                req.addToHeaders(h1)
                XCTAssertNotNil(req.headers)
                XCTAssertEqual(req.headers!.count, 2)
                let mh2 = self.localdb.createRequestData(id: "header-data-2", index: 2, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(mh2)
                guard let h2 = mh2 else { XCTFail(); return }
                h2.key = "h2"
                h2.value = "v2"
                req.addToHeaders(h2)
                XCTAssertNotNil(req.headers)
                XCTAssertEqual(req.headers!.count, 3)
                var x = self.localdb.getRequestData(at: 1, reqId: reqId, type: .header, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id!, h1.id!)
                x = self.localdb.getRequestData(at: 0, reqId: reqId, type: .header, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id!, h0.id!)
                x = self.localdb.getRequestData(at: 2, reqId: reqId, type: .header, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id!, h2.id!)
                XCTAssertNoThrow(self.localdb.saveBackgroundContext())
                var id = h1.id!
                _ = self.localdb.deleteRequestData(dataId: id, req: req, type: .header, ctx: ctx)
                XCTAssertEqual(req.headers!.count, 2)
                x = self.localdb.getRequestData(id: id, ctx: ctx)
                XCTAssertNil(x)
                id = h2.id!
                x = self.localdb.getRequestData(id: id, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id, id)
                self.localdb.deleteEntity(req)
                XCTAssertNil(self.localdb.getRequest(id: reqId, ctx: ctx))
                // cleaup
                self.localdb.deleteEntity(h0)
                self.localdb.deleteEntity(h1)
                self.localdb.deleteEntity(h2)
                XCTAssertNoThrow(self.localdb.saveBackgroundContext())
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testGetImageType() {
        let filePrivJPEG = "file:///private/var/mobile/Containers/Data/Application/0BD3B416-B9D5-4498-9781-08127199163F/tmp/60FA8CBF-2F96-464D-8DE4-C1D7FF59F698.jpeg"  // simulator
        let filePrivPNG = "file:///private/var/mobile/Containers/Data/Application/0BD3B416-B9D5-4498-9781-08127199163F/tmp/60FA8CBF-2F96-464D-8DE4-C1D7FF59F698.png"
        let filePrivJPEG1 = "file:///private/var/mobile/Containers/Data/Application/33784EF2-28F4-44A3-9278-F066DACD1717/tmp/8A0D19B0-2D08-47C3-BACD-AC788CBCD33E.jpeg"  // device
        var url = URL(fileURLWithPath: filePrivJPEG)
        var type = self.utils.getImageType(url)
        XCTAssertNotNil(type)
        XCTAssertEqual(type!, .jpeg)
        url = URL(fileURLWithPath: filePrivPNG)
        type = self.utils.getImageType(url)
        XCTAssertNotNil(type)
        XCTAssertEqual(type!, .png)
        url = URL(fileURLWithPath: filePrivJPEG1)
        type = self.utils.getImageType(url)
        XCTAssertNotNil(type)
        XCTAssertEqual(type!, .jpeg)
    }
    
    func testFileRead() {
        let exp = expectation(description: "read file")
        if let path = Bundle.init(for: type(of: self)).path(forResource: "IMG_6109", ofType: "jpeg") {
            Log.debug("path: \(path)")
            let fm = EAFileManager(url: URL(fileURLWithPath: path))
            fm.readToEOF { result in
                switch result {
                case .success(let data):
                    Log.debug("data: \(data)")
                    XCTAssert(data.count > 0)
                case .failure(let error):
                    Log.error("error: \(error)")
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testBackgroundWorker() {
        let exp = self.expectation(description: "test background worker")
        let w = BackgroundWorker()
        w.start {
            var acc: [Bool] = []
            for _ in 0...4 {
                acc.append(true)
            }
            w.stop()
            XCTAssertEqual(acc.count, 5)
            exp.fulfill()
        }
        self.waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRequestToDictionary() {
        let exp = expectation(description: "Test core data CRUD")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let ctx = self.localdb.bgMOC
                let file = self.localdb.createFile(data: Data(), index: 0, name: "test-file", path: URL(fileURLWithPath: "/tmp"), checkExists: false, ctx: ctx)
                XCTAssertNotNil(file)
                let req = self.localdb.createRequest(id: self.utils.genRandomString(), index: 0, name: "test-request", project: nil, checkExists: true, ctx: ctx)
                XCTAssertNotNil(req)
                let reqData = self.localdb.createRequestData(id: self.utils.genRandomString(), index: 0, type: .form, fieldFormat: .file, checkExists: false, ctx: ctx)
                XCTAssertNotNil(reqData)
                file!.requestData = reqData
                req!.body = self.localdb.createRequestBodyData(id: self.utils.genRandomString(), index: 0, checkExists: false, ctx: ctx)
                XCTAssertNotNil(req!.body)
                req!.body!.addToForm(reqData!)
                let hm = self.localdb.requestToDictionary(req!)
                XCTAssertEqual(hm.count, 12)
                XCTAssertNotNil(hm["body"])
                XCTAssertEqual((hm["body"] as! [String: Any]).count, 12)
                XCTAssertEqual(((hm["body"] as! [String: Any])["form"] as! [[String: Any]]).count, 1)
                XCTAssertEqual((((hm["body"] as! [String: Any])["form"] as! [[String: Any]])[0]).count, 11)
                XCTAssertEqual((((hm["body"] as! [String: Any])["form"] as! [[String: Any]])[0]["files"] as! [[String: Any]]).count, 1)
                XCTAssertEqual(((((hm["body"] as! [String: Any])["form"] as! [[String: Any]])[0]["files"] as! [[String: Any]])[0]).count, 8)
                self.localdb.discardChanges(in: ctx)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testRequestDidChange() {
        let exp = expectation(description: "Test request did change")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let ctx = self.localdb.bgMOC
                let req = self.localdb.createRequest(id: self.utils.genRandomString(), index: 0, name: "test-request-change", project: nil, checkExists: false, ctx: ctx)
                XCTAssertNotNil(req)
                let reqhma = self.localdb.requestToDictionary(req!)
                XCTAssertNotNil(reqhma)
                XCTAssert(reqhma.count > 0)
                let areq = req!
                var status = self.app.didRequestChangeImp(areq, request: reqhma)
                XCTAssertFalse(status)
                areq.url = "https://example.com"
                status = self.app.didRequestURLChangeImp(areq.url ?? "", request: reqhma)
                XCTAssertTrue(status)
                status = self.app.didRequestChangeImp(areq, request: reqhma)
                XCTAssertTrue(status)
                let breq = areq
                let reqhmb = self.localdb.requestToDictionary(breq)
                XCTAssertNotNil(reqhmb)
                XCTAssert(reqhmb.count > 0)
                status = self.app.didRequestChangeImp(areq, request: reqhmb)
                XCTAssertFalse(status)
                let reqData = self.localdb.createRequestData(id: self.utils.genRandomString(), index: 0, type: .header, fieldFormat: .text)
                XCTAssertNotNil(reqData)
                breq.addToHeaders(reqData!)
                XCTAssertNotNil(breq.headers)
                let reqDataxs = breq.headers!.allObjects as! [Restor.ERequestData]
                XCTAssertTrue(self.app.didAnyRequestHeaderChangeImp(reqDataxs, request: reqhmb))
                XCTAssertTrue(self.app.didRequestChangeImp(areq, request: reqhmb))
                breq.removeFromHeaders(reqData!)
                XCTAssertFalse(self.app.didRequestChangeImp(areq, request: reqhmb))
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testFileAttachmentDelete() {
        let exp = expectation(description: "Test setting to-many to a new set deletes the contained entities")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let moc = self.localdb.bgMOC
                let mreq = self.localdb.createRequest(id: "edit-req", index: 0, name: "Edit request", ctx: moc)
                XCTAssertNotNil(mreq)
                guard let req = mreq, let ctx = req.managedObjectContext else { XCTFail(); return }
                let abody = self.localdb.createRequestBodyData(id: "edit-req-body", index: 0, checkExists: false, ctx: ctx)
                XCTAssertNotNil(abody)
                guard let body = abody else { XCTFail(); return }
                let mf0 = self.localdb.createRequestData(id: "body-form-data-0", index: 0, type: .header, fieldFormat: .text, ctx: ctx)
                body.request = req
                XCTAssertNotNil(mf0)  // managed form object 0
                guard let f0 = mf0 else { XCTFail(); return }
                body.addToForm(f0)
                XCTAssertNotNil(body.form)
                XCTAssertEqual(body.form!.count, 1)
                let mfile0 = self.localdb.createFile(data: Data(), index: 0, name: "file-0", path: URL(fileURLWithPath: "/tmp"), checkExists: false, ctx: ctx)
                XCTAssertNotNil(mfile0)
                f0.addToFiles(mfile0!)
                XCTAssertNotNil(f0.files)
                XCTAssertEqual(f0.files!.count, 1)
                f0.files = NSSet()  // Removing the to-many relation, does not delete the entities in it.
                XCTAssertEqual(f0.files!.count, 0)
                let xfile0 = self.localdb.getFileData(id: "file-0", ctx: ctx)
                XCTAssertNil(xfile0)
                let ereq = self.localdb.getRequest(id: "edit-req")
                XCTAssertNotNil(ereq)
                self.localdb.discardChanges(in: moc)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func notestPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

public extension NSManagedObject {
    /// Change init to method to use insertInto method.
    convenience init(usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext)!
        self.init(entity: entity, insertInto: usedContext)
    }
}
