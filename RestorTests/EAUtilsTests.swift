//
//  EAUtilsTests.swift
//  RestorTests
//
//  Created by jsloop on 29/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import XCTest
import Foundation
@testable import Restor

class EAUtilsTests: XCTestCase {
    private let utils = Utils.shared
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testMD5ofData() {
        let data = "hello world".data(using: .utf8)
        XCTAssertNotNil(data)
        let md5 = self.utils.md5(data: data!)
        XCTAssertEqual(md5, "5eb63bbbe01eeed093cb22bb8f5acdc3")
    }
    
    func testGenRandom() {
        let x = self.utils.genRandomString()
        XCTAssertEqual(x.count, 22)
    }
    
    func testUUIDCompressDecompress() {
        let uuid = UUID()
        let comp = self.utils.compress(uuid: uuid)
        let decomp = self.utils.decompress(shortId: comp)
        XCTAssertEqual(decomp, uuid.uuidString)
    }
    
    func testSysInfo() {
        let mem: Float = EASystem.memoryFootprint() ?? 0.0
        Log.debug("mem: \(mem / 1024 / 1024)")
        Log.debug("phy mem: \(EASystem.totalMemory())")
        Log.debug("active cpu: \(EASystem.activeProcessorCount())")
        Log.debug("total cpu: \(EASystem.processorCount())")
        XCTAssertTrue(mem > 0.0)
    }
}
