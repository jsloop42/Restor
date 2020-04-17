//
//  EAQueueTests.swift
//  RestorTests
//
//  Created by jsloop on 26/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import XCTest
import Foundation
@testable import Restor

class EAQueueTests: XCTestCase {
    private var timer: Timer?
    private let ck = CloudKitService.shared
    private let opq = EAOperationQueue()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testQueue() {
        var count = 0
        var flag = 0
        let exp = expectation(description: "enqueue dequeue")
        let q = EAQueue<Int>(interval: 1.0) { xs in
            flag += 1
            if flag == 2 { exp.fulfill() }
        }
        self.timer = Timer(timeInterval: 0.2, repeats: true) { _ in
            q.enqueue(count)
            count += 1
            if count >= 10 { self.timer?.invalidate() }
        }
        RunLoop.main.add(self.timer!, forMode: .common)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testOpQueue() {
        let exp = expectation(description: "test operation queue")
        let op = EACloudOperation {
            exp.fulfill()
        }
        XCTAssertTrue(self.opq.add(op))
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
