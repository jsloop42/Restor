//
//  EARescheduler.swift
//  Restor
//
//  Created by jsloop on 13/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

/// A class which provides a scheduler which gets rescheduled if invoked before the schedule.
class EARescheduler: NSObject {
    var timer: Timer?
    var interval: TimeInterval = 0.3
    var repeats: Bool = false
    var block: (() -> Void)?
    let queue = DispatchQueue(label: "com.estoapps.ios.rescheduler", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)

    override init() {
        super.init()
    }
    
    init(interval: TimeInterval, repeats: Bool, block: @escaping () -> Void) {
        self.interval = interval
        self.repeats = repeats
        self.block = block
        super.init()
    }
    
    /// Schedules the block to run on a private async concurrent queue at the given interval.
    /// - Parameters:
    ///   - interval: The schedule interval
    ///   - repeats: If the scheduler should repeat
    ///   - block: The callback function
    func schedule(withInterval interval: TimeInterval, repeats: Bool, block: @escaping () -> Void) {
        self.timer?.invalidate()
        self.block = block
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: { [weak self] _ in
            self?.timer?.invalidate()
            self?.queue.async { self?.block?() }
        })
    }
    
    /// Schedules the execution of the given block. This overwrites any existing block and invalidates current timer.
    /// - Parameter block: The callback function.
    func schedule(block: @escaping () -> Void) {
        self.block = block
        self.schedule(withInterval: self.interval, repeats: self.repeats, block: block)
    }
    
    /// Schedule the execution of the block at the given interval
    func schedule() {
        if let block = self.block { self.schedule(withInterval: self.interval, repeats: self.repeats, block: block) }
    }
}
