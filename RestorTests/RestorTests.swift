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
    private let utils = Utils.shared
    private var localdb = CoreDataService.shared
    static let moc: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: RestorTests.self)])!
        return managedObjectModel
    }()
    private var inMemContainer: NSPersistentContainer?
    private let serialQueue = DispatchQueue(label: "serial-queue")

    override func setUp() {
        super.setUp()
//        if let container = try? NSPersistentContainer(name: "Restor", managedObjectModel: RestorTests.moc) {
//            container.loadPersistentStores(completionHandler: { storeDescription, error in
//                if let error = error {
//                    fatalError("Unresolved error \(error)")
//                }
//                container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
//                container.viewContext.automaticallyMergesChangesFromParent = true
//            })
//            self.localdb.persistentContainer = container
//            self.localdb.bgMOC = container.newBackgroundContext()
//        } else {
//            XCTFail()
//        }
        
        // Setup in-memory NSPersistentContainer
//        let storeURL = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("store")
//        let desc = NSPersistentStoreDescription(url: storeURL)
//        desc.shouldMigrateStoreAutomatically = true
//        desc.shouldInferMappingModelAutomatically = true
//        desc.shouldAddStoreAsynchronously = false
//        desc.type = NSSQLiteStoreType
//        let persistentContainer = NSPersistentContainer(name: "Restor", managedObjectModel: RestorTests.moc)
//        persistentContainer.persistentStoreDescriptions = [desc]
//        persistentContainer.loadPersistentStores { _, error in
//            if let error = error {
//                fatalError("Failed to create CoreData \(error.localizedDescription)")
//            } else {
//                Log.debug("CoreData set up with in-memory store type")
//            }
//        }
//        self.inMemContainer = persistentContainer
//        self.localdb.persistentContainer = self.inMemContainer!
    }

    override func tearDown() {
        
    }

    func testGenRandom() {
        let x = self.utils.genRandomString()
        XCTAssertEqual(x.count, 20)
    }
    
    // MARK: - CoreData tests
    
    func testCoreDataSetupCompletion() {
        let exp = expectation(description: "CoreData setup completion")
        self.localdb.setup {
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(self.localdb.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0)
        }
    }
    
    func testCoreDataPersistenceStoreCreated() {
        let exp = expectation(description: "CoreData setup create store")
        self.localdb.setup(storeType: NSInMemoryStoreType) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(self.localdb.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0)
        }
    }
    
    func testCoreDataPersistenceLoadedOnDisk() {
        let exp = expectation(description: "CoreData persistence container loaded on disk")
        self.localdb.setup {
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
    
    func testCoreDataPersistenceLoadedInMem() {
        let exp = expectation(description: "CoreData persistence container loaded in memory")
        self.localdb.setup(storeType: NSInMemoryStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.persistentContainer.persistentStoreDescriptions.first?.type, NSInMemoryStoreType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
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
                let lws = self.localdb.createWorkspace(id: "test-ws", name: "test-ws")
                XCTAssertNotNil(lws)
                guard let ws = lws else { return }
                XCTAssertEqual(ws.name, "test-ws")
                self.localdb.saveContext(ws)
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
                let rws = self.localdb.createWorkspace(id: wsname, name: wsname)
                XCTAssertNotNil(rws)
                guard let ws = rws else { return }
                //defer { self.localdb.deleteEntity(ws) }
                ws.name = wsname
                ws.desc = "test description"
                let wproj1 = self.localdb.createProject(id: "test-project-22", name: "test-project-22")
                XCTAssertNotNil(wproj1)
                guard let proj1 = wproj1 else { return }
                //defer { self.localdb.deleteEntity(proj1) }
                let wproj2 = self.localdb.createProject(id: "test-project-11", name: "test-project-11")
                XCTAssertNotNil(wproj2)
                guard let proj2 = wproj2 else { return }
                //defer { self.localdb.deleteEntity(proj2) }
                let wproj3 = self.localdb.createProject(id: "test-project-33", name: "test-project-33")
                XCTAssertNotNil(wproj3)
                guard let proj3 = wproj3 else { return }
                //defer { self.localdb.deleteEntity(proj3) }
                ws.projects = NSSet(array: [proj1, proj2, proj3])
                self.localdb.saveContext(ws)
                let lws = self.localdb.getWorkspace(id: wsname)
                XCTAssertNotNil(lws)
                let projxs = self.localdb.getProjects(in: ws)
                XCTAssert(projxs.count == 3)
                Log.debug("projxs: \(projxs)")
                XCTAssertEqual(projxs[0].name, "test-project-22")  // TODO: test ordering
                XCTAssertEqual(projxs[1].name, "test-project-11")
                XCTAssertEqual(projxs[2].name, "test-project-33")
                // cleanup
                projxs.forEach { p in self.localdb.deleteEntity(p) }
                self.localdb.deleteEntity(ws)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    // TODO: have multiple ws, test get projects of a workspace

    func notestPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

public extension NSManagedObject {
    convenience init(usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext)!
        self.init(entity: entity, insertInto: usedContext)
    }
}
