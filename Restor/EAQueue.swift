//
//  EAQueue.swift
//  Restor
//
//  Created by jsloop on 26/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

/// A queue implementation which dequeues based on time elapsed since enqueue.
public class EAQueue<T> {
    private var queue: [T] = []
    private var timer: DispatchSourceTimer?  // timer
    private var interval: TimeInterval = 4.0  // seconds
    public var completion: ([T]) -> Void
    private let accessq = EACommon.userInteractiveQueue
    public var count: Int = 0
    
    private enum State {
        case suspended
        case resumed
    }
    
    private var state: State = .suspended
    
    deinit {
        Log.debug("EAQueue deinit")
        self.timer?.cancel()
        self.timer?.resume()
        self.timer?.setEventHandler(handler: {})
        self.queue.removeAll()
    }
    
    init(interval: TimeInterval, completion: @escaping ([T]) -> Void) {
        self.interval = interval
        self.completion = completion
        self.initTimer()
    }
    
    private func initTimer() {
        self.timer = DispatchSource.makeTimerSource()
        self.timer?.schedule(deadline: .now() + self.interval, repeating: self.interval)
        self.timer?.setEventHandler(handler: { [weak self] in self?.eventHandler() })
    }
    
    private func eventHandler() {
        self.count = self.queue.count
        Log.debug("in timer queue len: \(self.queue.count)")
        if self.isEmpty() && self.state == .resumed {
            self.timer?.suspend()
            self.state = .suspended
            return
        }
        self.accessq.sync {
            self.completion(self.queue)
            Log.debug("EAQueue processed \(self.queue.count) items")
            self.queue.removeAll()
        }
    }
        
    public func updateTimer() {
        if !self.isEmpty() && self.state == .suspended {
            self.timer?.resume()
            self.state = .resumed
        }
        Log.debug("Queue state \(self.state) - count: \(self.queue.count)")
    }
    
    /// Enqueues the given list in one operation.
    public func enqueue(_ xs: [T]) {
        self.accessq.sync {
            self.queue.append(contentsOf: xs); Log.debug("enqueued: \(xs)")
            self.count = self.queue.count
            self.updateTimer()
        }
    }
    
    /// Enqueues the given element.
    public func enqueue(_ x: T) {
        Log.debug("enqueue: \(x)")
        self.accessq.sync {
            self.queue.append(x);
            self.count = self.queue.count
            Log.debug("enqueued: \(x)")
            self.updateTimer()
        }
    }
    
    public func dequeue() -> T? {
        var x: T?
        self.accessq.sync {
            x = self.queue.popLast()
            self.count = self.queue.count
        }
        Log.debug("dequeued: \(String(describing: x))")
        return x
    }
    
    func isEmpty() -> Bool {
        return self.queue.isEmpty
    }
    
    func peek() -> T? {
        return self.queue.first
    }
}
