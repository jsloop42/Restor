//
//  EARepeatTimer.swift
//  Restor
//
//  Created by jsloop on 17/04/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

/// A class that repeats the given block which uses DispatchSourceTimer
class EARepeatTimer {
    let interval: TimeInterval
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + self.interval, repeating: self.interval)
        t.setEventHandler(handler: { [weak self] in self?.eventHandler() })
        return t
    }()
    /// A code block to be executed when the timer triggers.
    var block: (() -> Void)?
    /// When the timer completes or the limit is reached, the done block will be executed.
    var done: (() -> Void)?
    /// The maximum number of times the timer should repeat.
    var limit: Int = 8
    /// The repeat counter.
    private (set) var counter: Int = 0
    
    private enum State {
        case suspended
        case resumed
    }
    
    private var state: State = .suspended
    
    deinit {
        self.stop()
    }
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    init(block: @escaping () -> Void, interval: TimeInterval, limit: Int) {
        self.block = block
        self.interval = interval
        self.limit = limit
    }
    
    func stop() {
        self.timer.setEventHandler {}
        self.timer.cancel()  // If the timer is suspended, we should call resume after calling cancel to prevent a crash.
        self.resume()  // https://forums.developer.apple.com/thread/15902
        self.block = nil
        self.done = nil
    }
    
    func resume() {
        if self.state == .resumed { return }
        self.state = .resumed
        self.timer.resume()
    }

    func suspend() {
        if self.state == .suspended { return }
        self.state = .suspended
        self.timer.suspend()
    }
    
    func eventHandler() {
        Log.debug("repeat timer: event handler")
        self.counter += 1
        if self.counter > self.limit {
            self.done?()
            self.stop()
            return
        }
        self.block?()
    }
}
