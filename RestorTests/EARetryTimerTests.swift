//
//  EARetryTimerTests.swift
//  RestorTests
//
//  Created by jsloop on 17/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import XCTest
@testable import Restor

class EARetryTimerTests: XCTestCase {
    var timer: EARetryTimer!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRetryTimer() {
        let exp = expectation(description: "retry timer execution")
        var c = 0
        self.timer = EARetryTimer(block: {
            c += 1
            if c == 3 {
                XCTAssertEqual(self.timer.retries(), 3)
                self.timer.stop()
                XCTAssertEqual(self.timer.retries(), 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.timer.start()
                }
            } else if c == 4 {
                XCTAssertEqual(self.timer.retries(), 1)
                self.timer.done()
                exp.fulfill()
            }
        }, interval: 1.0, limit: 5)
        waitForExpectations(timeout: 40, handler: nil)
    }
}
