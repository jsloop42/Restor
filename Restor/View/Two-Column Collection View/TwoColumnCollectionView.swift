//
//  TwoColumnCollectionView.swift
//  Restor
//
//  Created by jsloop on 22/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class TwoColumnCollectionView: UICollectionView {
    let cellId = "twoColumnCell"
    var isInit = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.bootstrap()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
    }
    
    func bootstrap() {
        if !self.isInit {
            self.initUI()
            self.isInit = true
        }
    }
    
    func initUI() {
        let nib = UINib(nibName: "TwoColumnCollectionViewCell", bundle: nil)
        self.register(nib, forCellWithReuseIdentifier: self.cellId)
    }
}

extension TwoColumnCollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var height: CGFloat = 17
        let width: CGFloat = collectionView.frame.width / 2
        var font: UIFont!
        let text: String = {
            let row = indexPath.row
            let section = indexPath.section
            var keyRow = 0
            var valRow = 0
            if row % 2 == 0 {  // left cell
                keyRow = row
                valRow = row + 1
            } else {
                keyRow = row - 1
                valRow = row
            }
            let keyCell = collectionView.cellForItem(at: IndexPath(row: keyRow, section: section)) as! TwoColumnCollectionViewCell
            let valCell = collectionView.cellForItem(at: IndexPath(row: valRow, section: section)) as! TwoColumnCollectionViewCell
            font = valCell.titleLabel.font
            let keyText = keyCell.titleLabel.text ?? ""
            let valText = valCell.titleLabel.text ?? ""
            return keyText.count <= valText.count ? valText : keyText
        }()
        height = UI.getTextHeight(text, width: width, font: font)
        if height < 17 { height = 17 }
        Log.debug("collection view cell width: \(width) - height: \(height)")
        return CGSize(width: width, height: height)
    }
}
