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
    var queue: [T] = []
    var timer: Timer?  // timer
    public var interval: TimeInterval = 4.0  // seconds
    public var completion: ([T]) -> Void
    private let accessq = DispatchQueue(label: "com.estoapps.ios.restor.access-queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    
    init(interval: TimeInterval, completion: @escaping ([T]) -> Void) {
        self.interval = interval
        self.completion = completion
    }
    
    public func enqueue(_ x: T) {
        Log.debug("enqueue: \(x)")
        if self.queue.isEmpty && self.timer == nil {
            self.timer = Timer(timeInterval: self.interval, repeats: true, block: { [weak self] _ in
                guard let this = self else { return }
                Log.debug("in timer queue len: \(this.queue.count)")
                if this.isEmpty() {
                    this.timer?.invalidate()
                    this.completion([])
                    return
                }
                this.accessq.sync {
                    this.completion(this.queue)
                    this.queue.removeAll()
                }
            })
            self.accessq.sync { self.queue.append(x); Log.debug("enqueued: \(x)") }
            if let x = self.timer { RunLoop.main.add(x, forMode: .common) }
        } else {
            self.accessq.sync { self.queue.append(x); Log.debug("enqueued: \(x)") }
        }
    }
    
    public func dequeue() -> T? {
        var x: T?
        self.accessq.sync { x = self.queue.popLast() }
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
