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

public extension Calendar.Component {
    static let allCases: [Calendar.Component] = [.year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfYear]
}

public extension Date {
    /// Returns the year from the date.
    var year: Int { Calendar.current.component(.year, from: self) }
    
    /// Returns month as `Int` starting from `1...12`.
    var month: Int { Calendar.current.component(.month, from: self) }
    
    var week: Int { Calendar.current.component(.weekOfYear, from: self) }
    
    var weekday: Int { Calendar.current.component(.weekday, from: self) }
    
    var weekOfMonth: Int { Calendar.current.component(.weekOfMonth, from: self) }
    
    var day: Int { Calendar.current.component(.day, from: self) }
    
    var hour: Int { Calendar.current.component(.hour, from: self) }
    
    var minute: Int { Calendar.current.component(.minute, from: self) }
    
    var second: Int { Calendar.current.component(.second, from: self) }
    
    var nanos: Int { Calendar.current.component(.nanosecond, from: self) }
    
    /// Get timestamp
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
    
    func currentTimeNanos() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000000)
    }
    
    // Intervals in seconds
    static let minuteInSeconds: Double = 60
    static let hourInSeconds: Double = 3600
    static let dayInSeconds: Double = 86400
    static let weekInSeconds: Double = 604800
    static let yearInSeconds: Double = 31556926
    
    /// Returns the difference between the given dates in milliseconds (ms)
    static func msDiff(start: Date, end: Date) -> Double {
        return TimeInterval(end.currentTimeNanos() - start.currentTimeNanos()) / 1000.0
    }
    
    /// Returns the difference between the given dates in seconds (s)
    static func secondsDiff(start: Date, end: Date) -> Double {
        return TimeInterval(end.currentTimeNanos() - start.currentTimeNanos()) / 1_000_000.0
    }
    
    /// Returns the difference between the given dates in minutes (min)
    static func minuteDiff(start: Date, end: Date) -> Double {
        return TimeInterval(end.currentTimeNanos() - start.currentTimeNanos()) / 60_000_000.0
    }
    
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        let cal = Calendar.current
        var comp = DateComponents()
        comp.day = 1
        return cal.date(byAdding: comp, to: self.startOfDay)!.addingTimeInterval(-1)
    }
    
    /// The percentage of the day elapsed for the current date.
    var percentageOfDay: Double {
        let totalSec = self.endOfDay.timeIntervalSince(self.startOfDay) + 1
        let sec = self.timeIntervalSince(self.startOfDay)
        return max(min(sec / totalSec, 1.0), 0.0) * 100
    }
    
    var fmt_YYYY_MM_dd_HH_mm_ss: String { self.fmt("YYYY-MM-dd HH:mm:ss") }
    
    private func fmt(_ str: String) -> String {
        let df = DateFormatter()
        df.timeZone = TimeZone.current
        df.dateFormat = str
        return df.string(from: self)
    }
    
    enum DateComparisonType {
        // Day
        /// Checks if date today.
        case isToday
        /// Checks if date is tomorrow.
        case isTomorrow
        /// Checks if date is yesterday.
        case isYesterday
        /// Checks if the days are the same
        case isSameDay(as: Date)
        
        // Week
        /// Checks if the date is in this week.
        case isThisWeek
        /// Checks if the date is in next week.
        case isNextWeek
        /// Checks if the date is in last week.
        case isLastWeek
        /// Checks if the given date has the same week.
        case isSameWeek(as: Date)
        
        // Month
        /// Checks if the date is in this month.
        case isThisMonth
        /// Checks if the date is in next month.
        case isNextMonth
        /// Checks if the date is in last month.
        case isLastMonth
        /// Checks if the given months are the same
        case isSameMonth(as: Date)
        
        // Year
        /// Checks if the date is in this year.
        case isThisYear
        /// Checks if the date is in the next year.
        case isNextYear
        /// Checks if the date is in the last year.
        case isLastYear
        /// Checks if the given date has the same year.
        case isSameYear(as: Date)
        
        // Relative Time
        /// Checks if the fate is in the future.
        case isInTheFuture
        /// Checks if the date is in the past.
        case isInThePast
        /// Checks if the date is earlier than the given date.
        case isEarlier(than: Date)
        /// Checks if the date is in the future compared to the given date.
        case isLater(than: Date)
        /// Checks if the date is a weekday
        case isWeekday
        /// Checks if the date is a weekend
        case isWeekend
    }
    
    static func components(_ date: Date) -> DateComponents {
        return Calendar.current.dateComponents(Set(Calendar.Component.allCases), from: date)
    }
    
    func adjust(_ type: Calendar.Component, offset: Int) -> Date {
        var comp = DateComponents()
        comp.setValue(offset, for: type)
        return Calendar.current.date(byAdding: comp, to: self)!
    }
    
    func adjust(second: Int?, minute: Int?, hour: Int?, day: Int? = nil, month: Int? = nil) -> Date {
        var comp = Date.components(self)
        if let x = second { comp.second = x  }
        if let x = minute { comp.minute = x }
        if let x = hour { comp.hour = x }
        if let x = day { comp.day = x }
        if let x = month { comp.month = x }
        return Calendar.current.date(from: comp)!
    }

    func compare(_ type: DateComparisonType) -> Bool {
        switch type {
            case .isToday:
                return compare(.isSameDay(as: Date()))
            case .isTomorrow:
                let comp = Date().adjust(.day, offset:1)
                return compare(.isSameDay(as: comp))
            case .isYesterday:
                let comparison = Date().adjust(.day, offset: -1)
                return compare(.isSameDay(as: comparison))
            case .isSameDay(let date):
                let comp = Date.components(date)
                return comp.year == date.year && comp.month == date.month && comp.day == date.day
            case .isThisWeek:
                return self.compare(.isSameWeek(as: Date()))
            case .isNextWeek:
                let comparison = Date().adjust(.weekOfYear, offset: 1)
                return compare(.isSameWeek(as: comparison))
            case .isLastWeek:
                let comparison = Date().adjust(.weekOfYear, offset: -1)
                return compare(.isSameWeek(as: comparison))
            case .isSameWeek(let date):
                if self.week != date.week { return false }
                // Check if time interval is under a week
                return abs(self.timeIntervalSince(date)) < Date.weekInSeconds
            case .isThisMonth:
                return self.compare(.isSameMonth(as: Date()))
            case .isNextMonth:
                let comp = Date().adjust(.month, offset: 1)
                return compare(.isSameMonth(as: comp))
            case .isLastMonth:
                let comp = Date().adjust(.month, offset: -1)
                return compare(.isSameMonth(as: comp))
            case .isSameMonth(let date):
                return self.year == date.year && self.month == date.month
            case .isThisYear:
                return self.compare(.isSameYear(as: Date()))
            case .isNextYear:
                let comp = Date().adjust(.year, offset: 1)
                return compare(.isSameYear(as: comp))
            case .isLastYear:
                let comp = Date().adjust(.year, offset: -1)
                return compare(.isSameYear(as: comp))
            case .isSameYear(let date):
                return self.year == date.year
            case .isInTheFuture:
                return self.compare(.isLater(than: Date()))
            case .isInThePast:
                return self.compare(.isEarlier(than: Date()))
            case .isEarlier(let date):
                return (self as NSDate).earlierDate(date) == self
            case .isLater(let date):
                return (self as NSDate).laterDate(date) == self
        case .isWeekday:
            return !compare(.isWeekend)
        case .isWeekend:
            let range = Calendar.current.maximumRange(of: Calendar.Component.weekday)!
            return self.weekday == range.lowerBound || self.weekday == range.upperBound - range.lowerBound
        }
    }
    
    func since(_ date: Date, in component: Calendar.Component) -> Int64 {
        let cal = Calendar.current
        switch component {
        case .second:
            return self.timeIntervalSince(date).toInt64()
        case .minute:
            return (self.timeIntervalSince(date) / Date.minuteInSeconds).toInt64()
        case .hour:
            return (self.timeIntervalSince(date) / Date.hourInSeconds).toInt64()
        case .day:
            let end = cal.ordinality(of: .day, in: .era, for: self)
            let start = cal.ordinality(of: .day, in: .era, for: date)
            return (end! - start!).toInt64()
        case .weekday:
            let end = cal.ordinality(of: .weekday, in: .era, for: self)
            let start = cal.ordinality(of: .weekday, in: .era, for: date)
            return (end! - start!).toInt64()
        case .weekOfYear:
            let end = cal.ordinality(of: .weekOfYear, in: .era, for: self)
            let start = cal.ordinality(of: .weekOfYear, in: .era, for: date)
            return (end! - start!).toInt64()
        case .month:
            let end = cal.ordinality(of: .month, in: .era, for: self)
            let start = cal.ordinality(of: .month, in: .era, for: date)
            return (end! - start!).toInt64()
        case .year:
            let end = cal.ordinality(of: .year, in: .era, for: self)
            let start = cal.ordinality(of: .year, in: .era, for: date)
            return (end! - start!).toInt64()
        default:
            return 0
        }
    }
    
    func toRelativeFormat() -> String {
        let ts = self.timeIntervalSince1970
        let now = Date().timeIntervalSince1970
        let isPast = now - ts > 0
        
        let sec: Double = abs(now - ts)
        let min: Double = round(sec / 60)
        let hour: Double = round(min / 60)
        let day: Double = round(hour / 24)
        
        if sec < 60 {
            if sec < 10 { return isPast ? "just now" : "in a few seconds" }
            return String(format: isPast ? "%.f seconds ago" : "in %.f seconds", sec)
        }
        if min < 60 {
            if min == 1 { return isPast ? "1 minute ago" : "in 1 minute" }
            return String(format: isPast ? "%.f minutes ago" : "in %.f minutes", min)
        }
        if hour < 24 {
            if hour == 1 { return isPast ? "last hour" : "next hour" }
            return String(format: isPast ? "%.f hours ago" : "in %.f hours", hour)
        }
        if day < 7 {
            if day == 1 { return isPast ? "yesterday" : "tomorrow" }
            return String(format: isPast ? "%.f days ago" : "in %.f days", day)
        }
        if day < 28 {
            if isPast { return compare(.isLastWeek) ? "last week" : String(format: "%.f weeks ago", Double(abs(since(Date(), in: .weekOfYear)))) }
            return compare(.isNextWeek) ? "next week" : String(format: "in %.f weeks", Double(abs(since(Date(), in: .weekOfYear))))
        }
        if compare(.isThisYear) {
            if isPast { return compare(.isLastMonth) ? "last month" : String(format: "%.f months ago", Double(abs(since(Date(), in: .month)))) }
            return compare(.isNextMonth) ? "next month" : String(format: "in %.f months", Double(abs(since(Date(), in: .month))))
        }
        if isPast { return compare(.isLastYear) ? "last year" : String(format: "%.f years ago", Double(abs(since(Date(), in: .year)))) }
        return compare(.isNextYear) ? "next year" : String(format: "in %.f years", Double(abs(since(Date(), in: .year))))
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
    
    func ends(with string: String) -> Bool {
        let count = string.count
        return self.suffix(count) == string
    }
    
    func replace(pattern: String, with string: String) -> String {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .useUnixLineSeparators) {
            return regex.stringByReplacingMatches(in: self, options: [], range: NSRange(location: 0, length: self.count), withTemplate: string)
        }
        return self
    }
    
    func replaceAll(pattern: String, with string: String) -> String {
        return self.replacingOccurrences(of: pattern, with: string, options: .regularExpression)
    }
    
    func distance(of element: Element) -> Int? {
        return self.firstIndex(of: element)?.distance(in: self)
    }
    
    func distance<S: StringProtocol>(of string: S) -> Int? {
        return self.range(of: string)?.lowerBound.distance(in: self)
    }
    
    func slice(from: String, to: String) -> String? {
        if let r1 = self.range(of: from)?.upperBound, let r2 = self.range(of: to)?.lowerBound {
            return (String(self[r1..<r2]))
        }
        return nil
    }
}

public extension Collection {
    func distance(to index: Index) -> Int {
        return self.distance(from: startIndex, to: index)
    }
}

public extension String.Index {
    func distance<S: StringProtocol>(in string: S) -> Int { return string.distance(to: self) }
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

public extension Double {
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
    
    func toFloat() -> Float {
        return Float(self)
    }
    
    func toFloat32() -> Float32 {
        return Float32(self)
    }
    
    func toFloat64() -> Float64 {
        return Float64(self)
    }
    
    /// Returns the double rounded to `n` decimal places
    func rounded(_ n: Int) -> Double {
        let m = pow(10, n).toDouble()
        return (self * m).rounded() / m
    }
}

extension Decimal {
    func toDouble() -> Double {
        return NSDecimalNumber(decimal: self).doubleValue
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

extension HTTPCookie {
    static func fromData(_ x: Data) -> [HTTPCookie] {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: x) as? [HTTPCookie] ?? []
        } catch let error {
            Log.error("Error decoding from data: \(error)")
        }
        return []
    }
        
    static func toData(_ cookies: [HTTPCookie]) -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true)
    }
    
    static func toData(_ cookie: HTTPCookie) -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: cookie, requiringSecureCoding: true)
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
