//
//  EATextField.swift
//  Restor
//
//  Created by jsloop on 12/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class EATextField: UITextField {
    var isColor = true
    /// Indiciates whether the textfield can resign as first responder.
    var canResign = true
    
    override var tintColor: UIColor! {
        didSet {
            setNeedsDisplay()
        }
    }

    /// Adds a bottom border if tint color is set.
    override func draw(_ rect: CGRect) {
        let startingPoint = CGPoint(x: rect.minX, y: rect.maxY)
        let endingPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        let path = UIBezierPath()
        path.move(to: startingPoint)
        path.addLine(to: endingPoint)
        path.lineWidth = 0.5
        if self.isColor {
            tintColor.setStroke()
        } else {
            UIColor.clear.setStroke()
        }
        path.stroke()
    }
    
    override var canResignFirstResponder: Bool {
        return self.canResign
    }
}
