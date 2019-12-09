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
    
    func addBorderWithColor(color: UIColor, width: CGFloat) {
        self.layer.cornerRadius = 5
        self.layer.borderWidth = width
        self.layer.borderColor = color.cgColor
    }
    
    func removeBorder() {
        self.layer.borderColor = UIColor.clear.cgColor
    }
}
