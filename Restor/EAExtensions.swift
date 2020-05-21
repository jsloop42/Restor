//
//  EAExtensions.swift
//  Restor
//
//  Created by jsloop on 23/01/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

public extension Date {
    func day() -> Int {
        return Calendar.current.component(.day, from: self)
    }
    
    /// Returns month as `Int` starting from `1...12`.
    func month() -> Int {
        return Calendar.current.component(.month, from: self)
    }
    
    /// Returns the year from the date.
    func year() -> Int {
        return Calendar.current.component(.year, from: self)
    }
    
    /// Get timestamp
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
    
    func currentTimeNanos() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000000)
    }
}

public extension String {
    subscript(_ i: Int) -> String {
        let idx1 = index(startIndex, offsetBy: i)
        let idx2 = index(idx1, offsetBy: 1)
        return String(self[idx1..<idx2])
    }

    subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return String(self[start ..< end])
    }

    subscript (r: CountableClosedRange<Int>) -> String {
        let startIndex =  self.index(self.startIndex, offsetBy: r.lowerBound)
        let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        return String(self[startIndex...endIndex])
    }
    
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension UIImage {
    /// Offset the image from left
    func imageWithLeftPadding(_ left: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        self.draw(in: CGRect(x: left, y: 0, width: self.size.width, height: self.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

public extension UITableView {
    func scrollToBottom(_ indexPath: IndexPath? = nil) {
        let idxPath = indexPath != nil ? indexPath! : IndexPath(row: self.numberOfRows(inSection: 0) - 1, section: 0)
        self.scrollToRow(at: idxPath, at: .bottom, animated: true)
    }
    
    func scrollToBottom(section: Int? = 0) {
        let sec = section != nil ? section! : 0
        let idxPath = IndexPath(row: self.numberOfRows(inSection: sec) - 1, section: sec)
        self.scrollToRow(at: idxPath, at: .bottom, animated: true)
    }
}

public extension UILabel {
    /// Set the text to empty string.
    func clear() {
        self.text = ""
    }
}

public extension NSFetchedResultsController {
    @objc func numberOfSections() -> Int {
        return self.sections?.count ?? 0
    }
    
    @objc func numberOfRows(in section: Int) -> Int {
        if let xs = self.sections, xs.count > section { return xs[section].numberOfObjects }
        return 0
    }
}

public extension Int32 {
    func toUInt8() -> UInt8 {
        return UInt8(self)
    }
    
    func toUInt32() -> UInt32 {
        return UInt32(self)
    }
    
    func toUInt() -> UInt {
        return UInt(self)
    }
    
    func toInt() -> Int {
        return Int(self)
    }
    
    func toInt64() -> Int64 {
        return Int64(self)
    }
    
    func toDouble() -> Double {
        return Double(self)
    }
}

public extension Int {
    func toUInt8() -> UInt8 {
        return UInt8(self)
    }
    
    func toUInt32() -> UInt32 {
        return UInt32(self)
    }
    
    func toUInt() -> UInt {
        return UInt(self)
    }
    
    func toInt32() -> Int32 {
        return Int32(self)
    }
    
    func toInt64() -> Int64 {
        return Int64(self)
    }
    
    func toDouble() -> Double {
        return Double(self)
    }
    
    /// Calls the given block n number of times.
    func times(block: () -> Void) {
        if self <= 0 { return }
        for _ in 0..<self { block() }
    }
}

public extension Int64 {
    func toUInt8() -> UInt8 {
        return UInt8(self)
    }
    
    func toUInt32() -> UInt32 {
        return UInt32(self)
    }
    
    func toUInt() -> UInt {
        return UInt(self)
    }
    
    func toInt() -> Int {
        return Int(self)
    }
    
    func toInt32() -> Int32 {
        return Int32(self)
    }
    
    func toDouble() -> Double {
        return Double(self)
    }
}

public extension UInt64 {
    func toUInt8() -> UInt8 {
        return UInt8(self)
    }
    
    func toUInt32() -> UInt32 {
        return UInt32(self)
    }
    
    func toUInt() -> UInt {
        return UInt(self)
    }
    
    func toInt() -> Int {
        return Int(self)
    }
    
    func toInt32() -> Int32 {
        return Int32(self)
    }
    
    func toInt64() -> Int64 {
        return Int64(self)
    }
    
    func toDouble() -> Double {
        return Double(self)
    }
}

public extension Float {
    func toUInt8() -> UInt8 {
        return UInt8(self)
    }
    
    func toUInt32() -> UInt32 {
        return UInt32(self)
    }
    
    func toUInt() -> UInt {
        return UInt(self)
    }
    
    func toInt() -> Int {
        return Int(self)
    }
    
    func toInt32() -> Int32 {
        return Int32(self)
    }
    
    func toInt64() -> Int64 {
        return Int64(self)
    }
    
    func toDouble() -> Double {
        return Double(self)
    }
}

public extension Set {
    var isEmpty: Bool { self.first == nil }
    
    func toArray() -> [Element] {
        return Array(self)
    }
}

public extension NSSet {
    var isEmpty: Bool { self.anyObject() == nil }
}

public extension Dictionary {
    func allKeys() -> [Key] {
        return Array(self.keys)
    }
    
    func allValues() -> [Value] {
        return Array(self.values)
    }
}

public extension Array {
    static func from<T>(_ data: UnsafePointer<T>, count: Int) -> [T] {
        let buff = UnsafeBufferPointer<T>(start: data, count: count)
        return Array<T>(buff)
    }
}

public extension UUID {
    var bytes: [UInt8] {
        let (u0,u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15) = self.uuid  // Is a tuple, so destructure.
        return [u0,u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15]
    }
    
    var data: Data { Data(self.bytes) }
    
    static func fromBytes(_ xs: [UInt8]) -> UUID {
        return UUID(uuid: (xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10], xs[11], xs[12], xs[13], xs[14], xs[15]))
    }
}

public extension Data {
    func toUnsafeBytes() -> UnsafePointer<UInt8>? {
        return self.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
    }
    
    func toBytes() -> [UInt8] {
        let count = self.count * MemoryLayout<UInt8>.size
        var ba: [UInt8] = Array(repeating: 0, count: count)
        ba = withUnsafeBytes { $0.compactMap { byte -> UInt8? in byte } }
        return ba
    }
}

public extension DispatchTime {
    func elapsedTime() -> Int {
        return Int(round(TimeInterval(DispatchTime.now().uptimeNanoseconds - self.uptimeNanoseconds) / 1e6))
    }
}

public extension Error {
    var code: Int { return (self as NSError).code }
    var domain: String { return (self as NSError).domain }
    var localizedFailureReason: String? { return (self as NSError).localizedFailureReason }
    var localizedRecoveryOptions: [String]? { return (self as NSError).localizedRecoveryOptions }
    var localizedRecoverySuggestion: String? { return (self as NSError).localizedRecoverySuggestion }
    var recoveryAttempter: Any? { return (self as NSError).recoveryAttempter }
    var userInfo: [String: Any] { return (self as NSError).userInfo }
}

/// Determine if view should be popped on navigation bar's back button tap
public protocol UINavigationBarBackButtonHandler {
    /// Should block the back button action
    func shouldPopOnBackButton() -> Bool
}

/// To not block the back button action by default
extension UIViewController: UINavigationBarBackButtonHandler {
    @objc public func shouldPopOnBackButton() -> Bool { return true }
}

extension UINavigationController: UINavigationBarDelegate {
    /// Check if current view controller should be popped on tapping the navigation bar back button.
    @objc public func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        guard let items = navigationBar.items else { return false }
        
        if self.viewControllers.count < items.count { return true }
        
        var shouldPop = true
        if let vc = topViewController, vc.responds(to: #selector(UIViewController.shouldPopOnBackButton)) {
            shouldPop = vc.shouldPopOnBackButton()
        }
        
        if shouldPop {
            DispatchQueue.main.async { self.popViewController(animated: true) }
        } else {
            for aView in navigationBar.subviews {
                if aView.alpha > 0 && aView.alpha < 1 { aView.alpha = 1.0 }
            }
        }
        
        return false
    }
}

extension UIViewController {
    var isNavigatedBack: Bool { !self.isBeingPresented && !self.isMovingToParent }
    var className: String { NSStringFromClass(self.classForCoder).components(separatedBy: ".").last! }
}
