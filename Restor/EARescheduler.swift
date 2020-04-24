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

public protocol EAReschedulable: class {
    var interval: TimeInterval { get set }
    var type: EAReschedulerType! { get set }
    
    init(interval: TimeInterval, type: EAReschedulerType)
    func schedule()
    func schedule(fn: EAReschedulerFn)
}

public struct EAReschedulerFn: Equatable, Hashable {
    /// The block identifier
    var id: String
    /// The block which needs to be executed returning a status which is passed to the callback function
    var block: () -> Bool
    /// The callback function after executing the block
    var callback: (Bool) -> Void
    var args: [AnyHashable] = []
    
    init(id: String, block: @escaping () -> Bool, callback: @escaping (Bool) -> Void, args: [AnyHashable]) {
        self.id = id
        self.block = block
        self.callback = callback
        self.args = args
    }
    
    public static func == (lhs: EAReschedulerFn, rhs: EAReschedulerFn) -> Bool {
        lhs.id == rhs.id && lhs.args == rhs.args
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id.hashValue)
    }
}

/// A class which provides a scheduler which gets rescheduled if invoked before the schedule.
public class EARescheduler: EAReschedulable {
    public typealias EAEquatable = String
    private var timer: DispatchSourceTimer!
    public var interval: TimeInterval = 0.3
    public var type: EAReschedulerType!
    private var blocks: [EAReschedulerFn] = []
    private let queue = EACommon.userInteractiveQueue
    private var limit: Int = 4
    private var isLimitEnabled = false
    private var counter = 0

    private enum State {
        case suspended
        case resumed
    }
    
    private var state: State = .suspended
    
    deinit {
        self.destroy()
        self.blocks = []
    }
    
    public required init(interval: TimeInterval, type: EAReschedulerType) {
        self.interval = interval
        self.type = type
    }
    
    init(interval: TimeInterval, type: EAReschedulerType, limit: Int) {
        self.interval = interval
        self.type = type
        self.limit = limit
        self.isLimitEnabled = true
    }
    
    private func initTimer() {
        if self.timer != nil { self.destroy() }
        self.timer = DispatchSource.makeTimerSource()
        self.timer.schedule(deadline: .now() + self.interval)
        self.timer.setEventHandler(handler: { [weak self] in self?.eventHandler() })
        self.timer.resume()
    }
    
    private func destroy() {
        if self.timer != nil {
            self.timer.setEventHandler {}
            self.timer.cancel()
        }
    }
    
    public func done() {
        self.destroy()
    }
    
    public func schedule() {
        self.initTimer()
        self.counter += 1
        if self.counter >= self.limit {
            self.eventHandler()
            self.done()
        }
    }
        
    func eventHandler() {
        Log.debug("scheduler exec block")
        if self.type == EAReschedulerType.everyFn {  // Invoke the callback function with the result of each block execution
            self.queue.async {
                self.blocks.forEach { fn in fn.callback(fn.block()) }
            }
        }
    }
    
    public func schedule(fn: EAReschedulerFn) {
        Log.debug("schedule - fn")
        self.addToBlock(fn)
        self.schedule()
    }
    
    private func addToBlock(_ fn: EAReschedulerFn) {
        Log.debug("add to block - fn")
        if let idx = (self.blocks.firstIndex { afn -> Bool in afn.id == fn.id }) {
            self.blocks[idx] = fn
        } else {
            self.blocks.append(fn)
        }
    }
}
