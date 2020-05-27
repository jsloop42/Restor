//
//  KVCell.swift
//  Restor
//
//  Created by jsloop on 23/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

/// A cell with two column layout which can be used for displaying key value pair data.
/// Example usage: display response header key value pairs.
class KVCell: UITableViewCell {
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
}
