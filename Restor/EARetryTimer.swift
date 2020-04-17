//
//  EARetryTimer.swift
//  Restor
//
//  Created by jsloop on 17/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

/// A class that retries the given block until invoked done or till the limit reaches.
public class EARetryTimer {
    private var block: (() -> Void)?
    private var interval: TimeInterval = 1.5
    /// Retry limit
    private var limit: Int = 8
    private var timer: Timer?
    private var counter = 0
    private var exhaution: (() -> Void)?
    
    init(block: @escaping () -> Void, interval: TimeInterval, limit: Int, exhaution: (() -> Void)? = nil) {
        self.block = block
        self.interval = interval
        self.limit = limit
        self.exhaution = exhaution
        self.start()
    }
    
    private func blockHandler(_ timer: Timer) {
        self.counter += 1
        if self.counter >= self.limit {
            self.cleanup()
            self.exhaution?()
            return
        }
        self.block?()
    }
    
    private func cleanup() {
        self.timer?.invalidate();
        self.timer = nil
        self.block = nil
    }
    
    /// Marks the task as complete. The timer gets stopped.
    public func done() {
        self.cleanup()
    }
    
    /// Stops the timer and resets any state like counter.
    public func stop() {
        self.counter = 0
        self.timer?.invalidate()
    }
    
    /// Stops the timer, but maintains the current state, like execution count.
    public func pause() {
        self.timer?.invalidate()
    }
    
    /// Starts the timer.
    public func start() {
        self.timer?.invalidate()
        self.timer = Timer(timeInterval: self.interval, repeats: true, block: self.blockHandler(_:))
        if isRunningTests { RunLoop.current.add(self.timer!, forMode: .common) } 
    }
    
    public func retries() -> Int {
        return self.counter
    }
}
