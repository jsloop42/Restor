//
//  EALFUCache.swift
//  Restor
//
//  Created by jsloop on 25/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

public protocol EACacheValue: class {
    // Getters
    func value() -> Any
    /// The id pointing to the value in the cache list which can be correlated to the value field.
    func id() -> String
    func ts() -> Int64
    func accessCount() -> Int
    
    // Setters
    func setValue(_ any: Any)
    func setId(_ v: String)
    func setTs(_ v: Int64)
    func setAccessCount(_ c: Int)
}

public protocol EACacheListValue: class {
    // Getters
    func id() -> String
    func accessCount() -> Int
    // Setters
    func setId(_ v: String)
    func setAccessCount(_ c: Int)
}

/// A Least Frequently Used cache
public struct EALFUCache {
    public var cache: NSMutableDictionary = [:]
    public var cacheList: NSMutableArray = []  // Used in tracking LFU
    public var cacheHint: Data?
    public var maxLimit: Int = 8
    
    init() {}
    
    init(size: Int) {
        self.maxLimit = size
    }
    
    mutating func addToCache(_ value: EACacheValue) {
        if self.cacheList.count >= self.maxLimit {  // remove the least frequently used element
            if let last = self.cacheList.lastObject as? EACacheValue {
                self.cache.removeObject(forKey: last.id())
            }
        }
        var count = 0
        var val: EACacheValue
        let ts = Date().currentTimeNanos()
        let key = value.id()
        if let x = self.cache[key] { val = x as! EACacheValue } else { val = value }
        val.setTs(ts)
        val.setAccessCount(val.accessCount() + 1)
        count = val.accessCount()
        self.cache[key] = val
        let elem = cacheList.first { elem -> Bool in
            if let x = elem as? EACacheListValue { return x.id() == key }
            return false
        }
        if let x = elem as? CacheListValue { x.setAccessCount(count) }  // todo: check this gets updated
        self.updateCacheOrder()
    }
    
    /// Sort workspace cache
    mutating func updateCacheOrder() {
        self.cacheList.sortedArray({ (a, b, nil) -> Int in
            if let x = a as? EACacheListValue, let y = b as? EACacheListValue {
                if x.accessCount() > y.accessCount() { return ComparisonResult.orderedDescending.rawValue }
                if x.accessCount() < y.accessCount() { return ComparisonResult.orderedAscending.rawValue }
                return ComparisonResult.orderedSame.rawValue
            }
            return ComparisonResult.orderedSame.rawValue
        }, context: nil, hint: self.cacheHint)
        self.cacheHint = self.cacheList.sortedArrayHint
    }
    
    mutating func resetCache() {
        self.cache.removeAllObjects()
        self.cacheList.removeAllObjects()
        self.cacheHint = nil
    }
}
