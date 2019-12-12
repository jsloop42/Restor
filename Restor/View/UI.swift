//
//  UI.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit

class UI {
    static func setGlobalStyle() {
        self.clearBackButtonText()
    }
    
static func clearBackButtonText() {
    // Clear back button text
    let BarButtonItemAppearance = UIBarButtonItem.appearance()
    BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .normal)
    BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .highlighted)
    BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .selected)
}
    
    static func roundTopCornersWithBorder(view: UIView, borderColor: UIColor? = nil, name: String) {
        // Round corners with mask
        let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners:[.topLeft, .topRight], cornerRadii: CGSize(width: 12.0, height: 12.0))
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        view.layer.mask = layer

        // Remove border if present
        if let layers = view.layer.sublayers {
            for layer in layers {
                if layer.name == name {
                    Log.debug("removed border layer")
                    layer.removeFromSuperlayer()
                    break
                }
            }
        }

        // Add border
        let borderLayer = CAShapeLayer()
        borderLayer.name = name
        borderLayer.path = layer.path
        borderLayer.fillColor = UIColor.clear.cgColor
        Log.debug("updating top border")
        borderLayer.frame = view.bounds
        view.layer.addSublayer(borderLayer)
    }
    
    static func pushScreen(_ navVC: UINavigationController, storyboardId: String) {
        if let storyboard = navVC.storyboard {
            let vc = storyboard.instantiateViewController(withIdentifier: storyboardId)
            navVC.pushViewController(vc, animated: true)
        }
    }
    
    static func isDarkMode() -> Bool {
        return UIScreen.main.traitCollection.userInterfaceStyle == .dark
    }
}

extension UIView {
    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
        }
    }

    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }

    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }

    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }

    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }
    
    func addTopBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }

    func addRightBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: self.frame.size.width - width, y: 0, width: width, height: self.frame.size.height)
        self.layer.addSublayer(border)
    }

    func addBottomBorderWithColor(color: UIColor, width: CGFloat, name: String) {
        let border = CALayer()
        border.name = name
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - width, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }
    
    func addLeftBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: 0, width: width, height: self.frame.size.height)
        self.layer.addSublayer(border)
    }
    
    func removeBottomBorder(name: String) {
        self.layer.sublayers?.forEach({ aLayer in
            if aLayer.name == name {
                aLayer.removeFromSuperlayer()
                return
            }
        })
    }

    func addBorderWithColor(color: UIColor, width: CGFloat) {
        self.layer.cornerRadius = 5
        self.layer.borderWidth = width
        self.layer.borderColor = color.cgColor
    }

    func removeBorder() {
        self.layer.borderColor = UIColor.clear.cgColor
    }
}

extension UILabel {
    func textWidth() -> CGFloat {
        return UILabel.textWidth(label: self)
    }
    
    class func textWidth(label: UILabel) -> CGFloat {
        return textWidth(label: label, text: label.text!)
    }
    
    class func textWidth(label: UILabel, text: String) -> CGFloat {
        return textWidth(font: label.font, text: text)
    }
    
    class func textWidth(font: UIFont, text: String) -> CGFloat {
        let myText = text as NSString
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let labelSize = myText.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(labelSize.width)
    }
}

extension UITableView {
    func reloadData(completion: @escaping () -> ()) {
        UIView.animate(withDuration: 0, animations: { self.reloadData() }, completion: { _ in
            completion()
        })
    }
}
