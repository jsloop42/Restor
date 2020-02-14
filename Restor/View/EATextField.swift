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
    /// Used during table view reload where we need to maintain the focus
    var canResign = true
    
    override var tintColor: UIColor! {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        let startingPoint = CGPoint(x: rect.minX, y: rect.maxY - 4)
        let endingPoint = CGPoint(x: rect.maxX, y: rect.maxY - 4)
        let path = UIBezierPath()
        path.move(to: startingPoint)
        path.addLine(to: endingPoint)
        path.lineWidth = 1.0
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
