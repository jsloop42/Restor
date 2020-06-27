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
    /// The key pointing to the value in the cache list which can be correlated to the value field.
    func key() -> String
    func ts() -> Int64
    func accessCount() -> Int
    
    // Setters
    func setValue(_ v: Any)
    func setKey(_ k: String)
    func setTs(_ v: Int64)
    func setAccessCount(_ c: Int)
}

public protocol EACacheListValue: class {
    // Getters
    /// The key
    func key() -> String
    func accessCount() -> Int
    // Setters
    func setKey(_ k: String)
    func setAccessCount(_ c: Int)
}

private final class CacheListValue: EACacheListValue {
    private var _key: String
    private var _accessCount: Int

    init(key: String, accessCount: Int) {
        self._key = key
        self._accessCount = accessCount
    }
    
    func key() -> String {
        return self._key
    }
    
    func accessCount() -> Int {
        return self._accessCount
    }
    
    func setKey(_ k: String) {
        self._key = k
    }
    
    func setAccessCount(_ c: Int) {
        self._accessCount = c
    }
}

/// A Least Frequently Used cache
public struct EALFUCache {
    public var cache: NSMutableDictionary = [:]
    public var cacheList: NSMutableArray = []  // Used in tracking LFU [EACacheListValue]
    public var cacheHint: Data?
    public var maxLimit: Int = 8
    
    init() {}
    
    init(size: Int) {
        self.maxLimit = size
    }
    
    mutating func maintainCacheSize() {
        if self.cacheList.count >= self.maxLimit {  // remove the least frequently used element
            if let last = self.cacheList.lastObject as? EACacheListValue {
                self.cache.removeObject(forKey: last.key())
                self.cacheList.removeLastObject()
            }
        }
    }
    
    mutating func add(_ value: EACacheValue) {
        self.maintainCacheSize()
        if let val = self.cache[value.key()] as? EACacheValue {
            value.setAccessCount(val.accessCount())
        } else {
            self.cacheList.add(CacheListValue(key: value.key(), accessCount: value.accessCount()))
        }
        self.cache[value.key()] = value
    }
    
    mutating func get(_ key: String) -> EACacheValue? {
        guard let val = self.cache[key] as? EACacheValue else { return nil }
        let key = val.key()
        let ts = Date().currentTimeNanos()
        val.setTs(ts)
        val.setAccessCount(val.accessCount() + 1)
        self.cache[key] = val
        let elem = cacheList.first { elem -> Bool in
            if let x = elem as? EACacheListValue { return x.key() == key }
            return false
        }
        if let x = elem as? CacheListValue { x.setAccessCount(val.accessCount()) }  // todo: check this gets updated
        self.updateCacheOrder()
        return val
    }
    
    /// Return the element from the cache without incrementing the counter.
    func peek(_ key: String) -> EACacheValue? {
        return self.cache[key] as? EACacheValue
    }
    
    /// Check if the given key is present in the cache.
    func contains(_ key: String) -> Bool {
        return self.peek(key) != nil
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
