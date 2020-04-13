//
//  EACommon.swift
//  Restor
//
//  Created by jsloop on 02/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

struct EACommon {
    static var userInteractiveQueue = DispatchQueue(label: "com.estoapps.ios.restor8.user-interactive", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var userInitiatedQueue = DispatchQueue(label: "com.estoapps.ios.restor8.user-initiated", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var defaultQueue = DispatchQueue(label: "com.estoapps.ios.restor8.default", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var backgroundQueue = DispatchQueue(label: "com.estoapps.ios.restor8.background", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
}
