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
    @IBOutlet weak var requestInfoCell: UITableViewCell!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet var infoTableViewManager: InfoTableViewManager!
    @IBOutlet weak var infoTableView: UITableView!
    let header: [String] = ["Description", "Headers", "URL Params", "Body", "Auth", "Options"]
    lazy var infoxs: [UIView] = {
        return [self.descriptionTextView, self.infoTableView]
    }()
    private var requestInfo: RequestHeaderInfo = .description
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc did load")
        self.headerCollectionView.infiniteLayout.isEnabled = false
        self.infoTableViewManager.delegate = self
        self.infoTableView.delegate = self.infoTableViewManager
        self.infoTableView.dataSource = self.infoTableViewManager
        self.headerCollectionView.reloadData()
        self.hideInfoElements()
        self.descriptionTextView.isHidden = false
    }
    
    func hideInfoElements() {
        self.infoxs.forEach { v in v.isHidden = true }
    }
    
    func processCollectionViewTap(_ info: RequestHeaderInfo) {
        Log.debug("selected element: \(String(describing: info))")
        self.requestInfo = info
        self.hideInfoElements()
        switch info {
        case .description:
            self.descriptionTextView.isHidden = false
        case .headers:
            self.infoTableView.isHidden = false
        default:
            break
        }
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Log.debug("collection view did select \(indexPath.row)")
        self.processCollectionViewTap(RequestHeaderInfo(rawValue: indexPath.row) ?? .description)
    }
}

extension RequestViewController: InfoTableViewDelegate {
    func currentRequestInfo() -> RequestHeaderInfo {
        return self.requestInfo
    }
}

// MARK: - Header Info

protocol InfoTableViewDelegate: class {
    func currentRequestInfo() -> RequestHeaderInfo
}

class InfoTableCell: UITableViewCell {
    
}

class InfoTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: InfoTableViewDelegate?
    
    override init() {
        super.init()
        Log.debug("info table view manager init")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "infoCell", for: indexPath) as! InfoTableCell
        return cell
    }
}
