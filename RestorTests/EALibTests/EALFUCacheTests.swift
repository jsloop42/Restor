//
//  EALFUCacheTests.swift
//  RestorTests
//
//  Created by jsloop on 25/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import XCTest
import Foundation
@testable import Restor

class PersonCacheValue: EACacheValue {
    private var name: String
    private var _key: String
    private var accessed: Int64  // timestamp
    private var count: Int  // access count
    
    init(name: String, key: String, ts: Int64, accessCount: Int) {
        self.name = name
        self._key = key
        self.accessed = ts
        self.count = accessCount
    }
    
    func value() -> Any {
        return self.name
    }
    
    func key() -> String {
        return self._key
    }
    
    func ts() -> Int64 {
        return self.accessed
    }
    
    func accessCount() -> Int {
        return self.count
    }
    
    func setValue(_ v: Any) {
        if let x = v as? String { self.name = x }
    }
    
    func setKey(_ k: String) {
        self._key = k
    }
    
    func setTs(_ v: Int64) {
        self.accessed = v
    }
    
    func setAccessCount(_ c: Int) {
        self.count = c
    }
}

class EALFUCacheTests: XCTestCase {
    private var cache = EALFUCache(size: 2)
    private var val = PersonCacheValue(name: "Olive", key: "ea-olive", ts: Date().currentTimeNanos(), accessCount: 0)
    private var val1 = PersonCacheValue(name: "Olivia", key: "ea-olivia", ts: Date().currentTimeNanos(), accessCount: 0)
    private var val2 = PersonCacheValue(name: "Liv", key: "ea-live", ts: Date().currentTimeNanos(), accessCount: 0)
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testLFUAdd() {
        XCTAssertEqual(self.cache.cache.count, 0)
        XCTAssertEqual(self.cache.cacheList.count, 0)
        self.cache.add(self.val)
        XCTAssertEqual(self.cache.cache.count, 1)
        XCTAssertEqual(self.cache.cacheList.count, 1)
        self.cache.add(self.val1)
        XCTAssertEqual(self.cache.cache.count, 2)
        XCTAssertEqual(self.cache.cacheList.count, 2)
        XCTAssertNotNil(self.cache.get(val.key()))
        XCTAssertNotNil(self.cache.get(val.key()))
        guard let obj = self.cache.cacheList.firstObject as? EACacheListValue else { XCTFail("Error geting cache value"); return }
        XCTAssertEqual(obj.accessCount(), 2)
        self.cache.add(self.val2)
        XCTAssertEqual(self.cache.cache.count, 2)
        XCTAssertEqual(self.cache.cacheList.count, 2)
        self.cache.resetCache()
        XCTAssertEqual(self.cache.cache.count, 0)
        XCTAssertEqual(self.cache.cacheList.count, 0)
    }
}
