//
//  KVCell.swift
//  Restor
//
//  Created by jsloop on 23/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

/// A cell with two column layout which can be used for displaying key value pair data. Accompanied by the `KVCell.xib` file.
/// Example usage: display response header key value pairs.
class KVCell: UITableViewCell {
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var bottomBorder: UIView!
    
    func displayBottomBorder() {
        self.bottomBorder.isHidden = false
    }
    
    /// For the last cell, we can hide the bottom border so that the cell's bottom border displays properly.
    func hideBottomBorder() {
        self.bottomBorder.isHidden = true
    }
}
