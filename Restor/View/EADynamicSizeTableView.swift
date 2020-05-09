//
//  EADynamicSizeTableView.swift
//  Restor
//
//  Created by jsloop on 09/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

/// A table view that resizes itself to the content size. Useful when we use a table view within another table view and wants to display the inner table view to
/// its full height, making the outer one cell increase in height and making the view scrollable.
/// In the cell height delegate return `UITableView.automaticDimension` and on bootstrap, set the `estimatedRowHeight` to `44`.
class EADynamicSizeTableView: UITableView {
    override var intrinsicContentSize: CGSize { self.contentSize }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if self.bounds.size != self.intrinsicContentSize {
            self.invalidateIntrinsicContentSize()
        }
    }
}
