//
//  AppDelegateMock.swift
//  RestorTests
//
//  Created by jsloop on 03/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
@testable import Restor

class AppDelegateMock: NSObject {
    override init() {
        super.init()
        print("app delegate mock init")
    }
}
