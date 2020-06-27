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
    private let utils = EAUtils.shared
    
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
    
    func testURLRequestToCurlString() {
        var req = URLRequest(url: URL(string: "https://piperway.org/api/test")!)
        req.httpMethod = "POST"
        req.httpBody = "{\"hello\": \"world\"}".data(using: .utf8)
        req.allHTTPHeaderFields = ["fruit": "apple", "banana": "orange", "melon": "kiwi"]
        print(req.curl(pretty: false))
        XCTAssertEqual(req.curl(pretty: false), "curl -i -X POST -H \"banana: orange\" -H \"melon: kiwi\" -H \"fruit: apple\" -d \"{\"hello\": \"world\"}\" \"https://piperway.org/api/test\"")
        XCTAssertEqual(req.curl(pretty: true), "curl -i \\\n-X POST \\\n-H \"fruit: apple\" \\\n-H \"banana: orange\" \\\n-H \"melon: kiwi\" \\\n-d \"{\"hello\": \"world\"}\" \\n\"https://piperway.org/api/test\"")
    }
}
