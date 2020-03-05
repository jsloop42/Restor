//
//  EAExtensions.swift
//  Restor
//
//  Created by jsloop on 23/01/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

extension Date {
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

extension String {
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
}

extension UIImage {
    /// Offset the image from left
    func imageWithLeftPadding(_ left: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        self.draw(in: CGRect(x: left, y: 0, width: self.size.width, height: self.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension Int32 {
    func toInt() -> Int {
        return Int(self)
    }
    
    func toInt64() -> Int64 {
        return Int64(self)
    }
}

extension Int {
    func toInt32() -> Int32 {
        return Int32(self)
    }
    
    func toInt64() -> Int64 {
        return Int64(self)
    }
}

extension Int64 {
    func toInt() -> Int {
        return Int(self)
    }
    
    func toInt32() -> Int32 {
        return Int32(self)
    }
}
