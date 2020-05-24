//
//  EADynamicSizeTableView.swift
//  Restor
//
//  Created by jsloop on 09/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

public extension Notification.Name {
    static var dynamicSizeTableViewHeightDidChange = Notification.Name("ea-dynamic-size-table-view-height-did-change")
}

/// A table view that resizes itself to the content size. Useful when we use a table view within another table view and wants to display the inner table view to
/// its full height, making the outer one cell increase in height and making the view scrollable.
/// In the cell height delegate return `UITableView.automaticDimension` and on bootstrap, set the `estimatedRowHeight` to `44`.
public class EADynamicSizeTableView: UITableView {
    public override var intrinsicContentSize: CGSize { self.contentSize }
    private var heightMap: [Int: CGFloat] = [:]
    public var height: CGFloat { self.heightMap.allValues().reduce(into: 0.0) { (acc, x) in acc = acc + x } }
    private var previousHeight: CGFloat = 0.0
    public var tableViewId: String = "dynamic-size-tableview"
    public var nc = NotificationCenter.default
    public var shouldReload = true {
        didSet {
            Log.debug("table view: \(self.tableViewId) should reload: \(self.shouldReload)")
        }
    }
    private var isInit = false
    /// Draw top and bottom borders.
    public var drawBorders = false {
        didSet { self._drawBorders() }
    }
    private let bottomBorderId = "ea-bottom-border"
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.bootstrap()
    }
    
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.bootstrap()
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
    }
    
    public func bootstrap() {
        if !self.isInit {
            self.initUI()
            self.isInit = true
        }
    }
    
    public func initUI() {
        self._drawBorders()
    }
    
    private func _drawBorders() {
        if self.drawBorders {
            self.borderColor = UIColor(named: "cell-separator-bg")
            self.borderWidth = 0.8
            self.addTopBorderWithColor(color: self.borderColor!, width: self.borderWidth)
            self.addBottomBorder()
        } else {
            self.removeBorder()
        }
    }
    
    func addBottomBorder() {
        if self.drawBorders {
            self.removeBottomBorder(name: self.bottomBorderId)
            self.addBottomBorderWithColor(color: self.borderColor!, width: self.borderWidth, name: self.bottomBorderId)
        } else {
            self.removeBottomBorder(name: self.bottomBorderId)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if self.bounds.size != self.intrinsicContentSize {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    /// For each cell height computed from the table view delegate, call this method to save the height for the given index. Once the index of all the elements
    /// in the table view gets obtained, the height if not the same of the previous computed height, a notification will be posted with the table view
    /// identifier and the height. Listen to this notification and reload the container table view to update its height to display this table view in full
    /// within its cell.
    /// Set the `shouldReload` to `false` when reloading so that we avoid duplicate computation and once the parent table view completes the reload, toggle this
    /// back.
    public func setHeight(_ height: CGFloat, forRowAt indexPath: IndexPath) {
        self.heightMap[indexPath.row] = height
        self.addBottomBorder()
        if self.numberOfRows(inSection: indexPath.section) == self.heightMap.count {
            let h = self.height
            if self.previousHeight != h {
                self.addBottomBorder()
                self.nc.post(name: .dynamicSizeTableViewHeightDidChange, object: self, userInfo: ["tableViewId": self.tableViewId, "height": h])
                self.previousHeight = h
            }
        }
    }
    
    public override func reloadData() {
        if self.shouldReload { super.reloadData() }
    }
}
