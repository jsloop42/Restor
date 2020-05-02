//
//  EACommon.swift
//  Restor
//
//  Created by jsloop on 02/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

public struct EACommon {
    static var userInteractiveQueue = DispatchQueue(label: "com.estoapps.ios.restor.user-interactive", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var userInitiatedQueue = DispatchQueue(label: "com.estoapps.ios.restor.user-initiated", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var defaultQueue = DispatchQueue(label: "com.estoapps.ios.restor.default", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var utilityQueue = DispatchQueue(label: "com.estoapps.ios.restor.utility", qos: .utility, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var backgroundQueue = DispatchQueue(label: "com.estoapps.ios.restor.background", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
}

public enum EATimerState {
    case undefined
    case suspended
    case resumed
    case terminated
}
