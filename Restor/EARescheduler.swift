//
//  EARescheduler.swift
//  Restor
//
//  Created by jsloop on 13/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

public enum EAReschedulerType {
    /// All functions should produce a truthy value. If any function returns false, the evaluation short circuits.
    case allSatisfies
    /// At least one function should produce a truthy value.
    case anySatisfies
    /// Executes all functions regardless of their return value.
    case everyFn
}

public protocol EAReschedulable {
    var interval: TimeInterval { get set }
    var repeats: Bool { get set }
    var type: EAReschedulerType! { get set }
    
    init(interval: TimeInterval, repeats: Bool, type: EAReschedulerType)
    mutating func schedule()
    mutating func schedule(fn: EAReschedulerFn)
}

public struct EAReschedulerFn: Equatable, Hashable {
    /// The block identifier
    var id: String
    /// The block which needs to be executed
    var block: () -> Bool
    /// The callback function after executing the block
    var callback: (Bool) -> Void
    
    init(id: String, block: @escaping () -> Bool, callback: @escaping (Bool) -> Void) {
        self.id = id
        self.block = block
        self.callback = callback
    }
    
    public static func == (lhs: EAReschedulerFn, rhs: EAReschedulerFn) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id.hashValue)
    }
}

/// A class which provides a scheduler which gets rescheduled if invoked before the schedule.
public struct EARescheduler: EAReschedulable {
    private var timer: Timer?
    public var interval: TimeInterval = 0.3
    public var repeats: Bool = false
    public var type: EAReschedulerType!
    private var blocks: [EAReschedulerFn] = []
    private let queue = DispatchQueue(label: "com.estoapps.ios.rescheduler", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)

    public init(interval: TimeInterval, repeats: Bool, type: EAReschedulerType) {
        self.interval = interval
        self.repeats = repeats
        self.type = type
    }
    
    public mutating func schedule() {
        self.timer?.invalidate()
        let this = self
        self.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: self.repeats, block: { _ in
            this.timer?.invalidate()
            if this.type == EAReschedulerType.everyFn {  // Invoke the callback function with the result of each block execution
                this.queue.async {
                    this.blocks.forEach { fn in fn.callback(fn.block()) }
                }
            }
        })
    }
    
    public mutating func schedule(fn: EAReschedulerFn) {
        self.addToBlock(fn)
        self.schedule()
    }
    
    private mutating func addToBlock(_ fn: EAReschedulerFn) {
        if !self.blocks.contains(fn) { self.blocks.append(fn) }
    }
}
