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

extension NSFetchedResultsController {
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
}

/// Determine if view should be popped on navigation bar's back button tap
protocol  UINavigationBarBackButtonHandler {
    /// Should block the back button action
    func shouldPopOnBackButton() -> Bool
}

/// To not block the back button action by default
extension UIViewController: UINavigationBarBackButtonHandler {
    @objc func shouldPopOnBackButton() -> Bool { return true }
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
