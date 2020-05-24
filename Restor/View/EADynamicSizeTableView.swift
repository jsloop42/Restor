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
    /// Returns height of the whole table view.
    public var height: CGFloat { self.heightForAllSections() }
    private var previousHeight: CGFloat = 0.0
    public var tableViewId: String = "dynamic-size-tableview"
    public var nc = NotificationCenter.default
    public var shouldReload = true {
        didSet { Log.debug("table view: \(self.tableViewId) should reload: \(self.shouldReload)") }
    }
    private var isInit = false
    /// Draw top and bottom borders.
    public var drawBorders = false {
        didSet { self._drawBorders() }
    }
    private let bottomBorderId = "ea-bottom-border"
    private var heightInfo: [Int: HeightInfo] = [:]  // [Section: [Row: Height]]
    
    private struct HeightInfo {
        var section: Int = 0
        var height: CGFloat = 0.0
        var previousHeight: CGFloat = 0.0
        var heightMap: [Int: CGFloat] = [:]
        var numberOfRows = 0
        /// Indicates whether the height for all rows has been computed
        var computed = false
        /// If the meta related to the model has been set, like the model count.
        var isMetaSet = false
    }
    
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
        self.estimatedRowHeight = 44
    }
    
    private func _drawBorders() {
        if self.drawBorders {
            self.borderColor = UIColor(named: "cell-separator-bg")
            self.borderWidth = 0.8
            self.addTopBorderWithColor(color: self.borderColor!, width: self.borderWidth)
            self.updateBottomBorder()
        } else {
            self.removeBorder()
        }
    }
    
    func updateBottomBorder() {
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
        self.updateBottomBorder()
        if self.computedHeight(forIndexPath: indexPath) != nil { return }
        let section = indexPath.section
        let row = indexPath.row
        var secMap = self.heightInfo[section] ?? HeightInfo()
        secMap.section = section
        secMap.heightMap[row] = height
        self.heightInfo[section] = secMap
        if !secMap.isMetaSet { secMap.numberOfRows = self.numberOfRows(inSection: section); secMap.isMetaSet = true }
        if secMap.numberOfRows == secMap.heightMap.count {
            let h = secMap.heightMap.allValues().reduce(into: 0.0, { acc, height in acc += height })
            secMap.height = h
            if secMap.previousHeight != h {
                self.updateBottomBorder()
                secMap.computed = true
                self.nc.post(name: .dynamicSizeTableViewHeightDidChange, object: self, userInfo: ["tableViewId": self.tableViewId, "height": h])
                secMap.previousHeight = h
                self.heightInfo[section] = secMap
            }
        }
    }
    
    /// Returns the height for the given section.
    public func height(forSection section: Int) -> CGFloat {
        var height: CGFloat = 0.0
        if let secMap = self.heightInfo[section] { height = secMap.heightMap.allValues().reduce(into: 0.0) { acc, height in acc +=  height } }
        if height == 0.0 && self.numberOfRows(inSection: section) > 0 { return self.estimatedRowHeight }
        return height
    }
    
    /// Returns the height for all sections of the table view, same as height of the table view.
    public func heightForAllSections() -> CGFloat {
        var isEmptyTable = true
        let height: CGFloat = self.heightInfo.allValues().reduce(into: 0.0) { height, secMap in
            if isEmptyTable { isEmptyTable = self.numberOfRows(inSection: secMap.section) == 0 }
            height += secMap.heightMap.allValues().reduce(into: 0.0) { acc, height in acc +=  height }
        }
        return height == 0 && !isEmptyTable ? self.estimatedRowHeight : height
    }
    
    /// If the model did not change and all height had been already computed once, then the height need not be computed again.
    /// Returns the height if it's already computed or nil.
    /// NB: When using this in heightForRow there is a mismatch of one item being short on table view reload. So it's used internally.
    private func computedHeight(forIndexPath indexPath: IndexPath) -> CGFloat? {
        if let secMap = self.heightInfo[indexPath.section], secMap.computed { return secMap.height }
        return nil
    }
    
    /// When underlying model data changes, invoke this so that we get updated meta like, height info.
    public func resetMeta() {
        self.heightInfo = [:]
    }
    
    public override func reloadData() {
        if self.shouldReload {
            let offset = self.contentOffset  // Save the offset so that after reload, the table view maintains the same scroll offset
            super.reloadData()
            let offsetY = self.contentSize.height >= offset.y ? offset.y : self.contentSize.height
            self.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
        }
    }
}
