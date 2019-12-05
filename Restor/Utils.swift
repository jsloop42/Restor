//
//  Utils.swift
//  Restor
//
//  Created by jsloop on 03/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Utils {
    static let shared: Utils = Utils()
    
}


struct Log {
    static func debug(_ msg: @autoclosure () -> Any) {
        #if DEBUG
        print("[DEBUG] \(msg())")
        #endif
    }
}
