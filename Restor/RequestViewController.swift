//
//  RequestViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit
import InfiniteLayout

class HeaderCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    
    func update(index: Int, text: String) {
        self.nameLbl.text = text
    }
}

class RequestViewController: UITableViewController {
    @IBOutlet weak var headerCollectionView: InfiniteCollectionView!
    let header: [String] = ["Description", "Headers", "URL Params", "Body", "Auth", "Options"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc did load")
        self.headerCollectionView.infiniteLayout.isEnabled = false
        self.headerCollectionView.reloadData()
    }
}

extension RequestViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.header.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "headerCell", for: indexPath) as! HeaderCollectionViewCell
        let path = self.headerCollectionView.indexPath(from: indexPath)
        cell.update(index: path.row, text: self.header[path.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 0
        let row = indexPath.row
        if self.header.count > row {
            let text = self.header[row]
            width = UILabel.textWidth(font: UIFont.systemFont(ofSize: 16), text: text)
        }
        Log.debug("label width: \(width)")
        return CGSize(width: width, height: 22)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
