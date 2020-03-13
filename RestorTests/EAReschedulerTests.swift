//
//  EAReschedulerTests.swift
//  RestorTests
//
//  Created by jsloop on 14/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import XCTest
import Foundation
@testable import Restor

class EAReschedulerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRescheduler() {
        let exp = expectation(description: "execute the reschedule block with every fn callback")
        var r = EARescheduler(interval: 1.0, repeats: false, type: .everyFn)
        var acc: [Bool] = []
        let count = 3
        let lock = NSLock()
        var isok = false
        let validate: () -> Void = {
            if acc.count == count && (acc.allSatisfy { (status) -> Bool in status }) {
                lock.lock()
                if !isok { exp.fulfill(); isok = true }
                lock.unlock()
            }
        }
        var fn = EAReschedulerFn(id: "fn-a", block: { (x: Any) -> Bool in
            acc.append(true)
            return true
        }, callback: { res in
            XCTAssertTrue(res)
            validate()
        }, arg: "")
        r.schedule(fn: fn)
        fn.id = "fn-b"
        r.schedule(fn: fn)
        fn.id = "fn-c"
        r.schedule(fn: fn)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
