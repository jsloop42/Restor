//
//  ResponseTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class ResponseInfoCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var statusCodeView: UIView!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var statusMessageLabel: UILabel!
    @IBOutlet weak var statusSizeLabel: UILabel!
    @IBOutlet weak var infoView: UIView!
    var mode: ResponseMode = .preview
    var history: EHistory?
    var request: ERequest?
    private lazy var app = { App.shared }()
    private lazy var utils = { EAUtils.shared }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.updateUI()
    }
    
    func updateUI() {
        guard let req = self.request, let history = self.history else { return }
//        UIView.animate(withDuration: 0.3) {
//            self.topBorderView.isHidden = false
//            self.infoView.isHidden = false
//            self.bottomBorderView.isHidden = false
//            self.helpMsgView.isHidden = true
//        }
        
        self.nameLabel.text = req.name
        self.urlLabel.text = req.url // TODO: change this to consider env var
        
        //self.nameLabel.text = "Get the list of all users filtered by active sorted by first name grouped by location joined by demographics segemented by geolocation"
        //self.urlLabel.text = "https://piperway.com/rest/list/user/sort/filter/group?param=search&name=first"
        //self.nameLabel.text = "Get list of all users"
        //self.urlLabel.text = "https://piperway.com/test/list/user"
        
        var color: UIColor!
        if history.statusCode > 0 {
            self.statusCodeLabel.text = "\(history.statusCode)"
            self.statusMessageLabel.text = HTTPStatusCode(rawValue: history.statusCode.toInt())?.toString() ?? ""
            if history.statusCode == 200 {
                self.statusMessageLabel.textAlignment = .center
            } else {
                self.statusMessageLabel.textAlignment = .right
            }
            var is200 = false
            if (200..<299) ~= history.statusCode {
                color = UIColor(named: "http-status-200")
                is200 = true
            } else if (300..<399) ~= history.statusCode {
                color = UIColor(named: "http-status-300")
            } else if (400..<500) ~= history.statusCode {
                color = UIColor(named: "http-status-400")
            } else if (500..<600) ~= history.statusCode {
                color = UIColor(named: "http-status-500")
            }
            self.statusCodeView.backgroundColor = color
            self.statusMessageLabel.textColor = is200 ? UIColor(named: "http-status-text-200") : color
        } else {
            self.statusCodeView.backgroundColor = UIColor(named: "http-status-none")
            self.statusMessageLabel.textColor = UIColor(named: "help-text-fg")
        }
        let ts = self.app.formatElapsed(history.elapsed)
        if history.responseBodySize > 0 {
            self.statusSizeLabel.text = "\(ts), \(self.utils.bytesToReadable(history.responseBodySize))"
        } else {
            self.statusSizeLabel.text = "\(ts)"
        }
    }
    
    func displayNoResponse() {
        UIView.animate(withDuration: 0.3) {
//            self.topBorderView.isHidden = true
//            self.infoView.isHidden = true
//            self.bottomBorderView.isHidden = true
        }
    }
}

class ResponseCollectionViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource {
    var isInit = false
    var collectionView: TwoColumnCollectionView!
    var request: ERequest?
    var history: EHistory?
    let cellId = "twoColumnCell"
    var cellType: CellType = .header
    var headers: [String: String] = [:]
    
    enum CellType {
        case header
        case details
    }
    
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
        if self.collectionView == nil {
            self.collectionView = UINib(nibName: "TwoColumnCollectionView", bundle: nil).instantiate(withOwner: self, options: nil)[0] as? TwoColumnCollectionView
            self.collectionView.delegate = self
            self.collectionView.dataSource = self
        }
    }
    
    func updateData() {
        guard let history = self.history, let headers = history.responseHeaders else { return }
        if let hm = try? JSONSerialization.jsonObject(with: headers, options: .allowFragments) as? [String: String] {
            self.headers = hm
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.cellType == .header ? self.headers.count : 12
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: self.cellId, for: indexPath)
    }
}

enum ResponseMode: Int {
    case info
    case raw
    case preview
    
    static var allCases = ["Info", "Raw", "Preview"]
}

class ResponseTableViewController: RestorTableViewController {
    private let nc = NotificationCenter.default
    private lazy var ck = { EACloudKit.shared }()
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var utils = { EAUtils.shared }()
    private lazy var tabbarController = { self.tabBarController as! RequestTabBarController }()
    var mode: ResponseMode = .preview
    @IBOutlet weak var infoCell: ResponseInfoCell!
    @IBOutlet weak var headerTitleCell: KVHeaderCell!
    @IBOutlet weak var headersViewCell: UITableViewCell!
    @IBOutlet weak var detailsTitleCell: KVHeaderCell!
    @IBOutlet weak var detailsViewCell: UITableViewCell!
    @IBOutlet weak var helpCell: ResponseInfoCell!
    
    var request: ERequest?
    var history: EHistory?
    
    enum InfoCellId: Int {
        case spacerBeforeInfoCell
        case infoCell
        case headerTitleCell
        case headersViewCell
        case detailsTitleCell
        case detailsViewCell
        case helpCell
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("response vc did load")
        self.request = self.tabbarController.request
        self.initData()
        self.initUI()
        self.initEvents()
        self.updateUI()
        self.tableView.reloadData()
    }
    
    func initData() {
        guard let req = self.request else { return }
        if self.history == nil {
            self.history = self.localdb.getLatestHistory(reqId: req.getId(), includeMarkForDelete: nil, ctx: self.localdb.mainMOC)
        }
        self.infoCell.request = req
        self.infoCell.history = self.history
    }
    
    func initUI() {
        if let tb = self.tabBarController as? RequestTabBarController {
            self.mode = ResponseMode(rawValue: tb.segView.selectedSegmentIndex) ?? .preview
            tb.viewNavbarSegment()
        }
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.segmentDidChange(_:)), name: .responseSegmentDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.viewRequestHistoryDidTap(_:)), name: .viewRequestHistoryDidTap, object: nil)
        self.nc.addObserver(self, selector: #selector(self.responseDidReceive(_:)), name: .responseDidReceive, object: nil)
    }
    
    func updateUI() {
        Log.debug("update UI")
        if self.history == nil { return }
        if self.mode == .info {
            self.infoCell.updateUI()
        }
//        if self.mode == .info {
//            if self.history == nil {
//                UIView.animate(withDuration: 0.3) {
//                    [self.infoCell, self.headerTitleCell, self.headersViewCell, self.detailsTitleCell, self.detailsViewCell].forEach { $0?.isHidden = true }
//                    self.helpCell.isHidden = false
//                }
//            } else {
//                UIView.animate(withDuration: 0.3) {
//                    [self.infoCell, self.headerTitleCell, self.headersViewCell, self.detailsTitleCell, self.detailsViewCell].forEach { $0?.isHidden = false }
//                    self.helpCell.isHidden = true
//                    self.infoCell.updateUI()
//                }
//            }
//        }
    }
    
    @objc func segmentDidChange(_ notif: Notification) {
        Log.debug("segment did change notif")
        if let info = notif.userInfo, let idx = info["index"] as? Int {
            self.ck.saveValue(key: Const.responseSegmentIndexKey, value: idx)
            self.mode = ResponseMode(rawValue: idx) ?? .info
            Log.debug("response mode changed: \(self.mode)")
            self.updateUI()
            self.tableView.reloadData()
        }
    }
    
    @objc func viewRequestHistoryDidTap(_ notif: Notification) {
        Log.debug("view request history did tap")
        guard let info = notif.userInfo, let req = info["request"] as? ERequest, req.getId() == self.request?.getId() else { return }
        // TODO: display history page
    }
    
    @objc func responseDidReceive(_ notif: Notification) {
        Log.debug("response did receieve")
        if let info = notif.userInfo as? [String: Any], let histId = info["historyId"] as? String {
            DispatchQueue.main.async {
                self.history = self.localdb.getHistory(id: histId, ctx: self.localdb.mainMOC)
                //self.updateUI()
            }
        }
    }
}

extension ResponseTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.mode == .info && section == 0 { return 7 }
        if self.mode == .raw && section == 1 { return 2 }
        if self.mode == .preview && section == 2 { return 2 }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            if self.mode == .info {
                if self.history == nil {
                    if indexPath.row == InfoCellId.helpCell.rawValue { return 44 }
                    return 0
                } else {
                    let cellId = InfoCellId(rawValue: indexPath.row)
                    switch cellId {
                    case .spacerBeforeInfoCell:
                        return 24
                    case .infoCell:
                        return 81
                    case .headerTitleCell:
                        return 44
                    case .headersViewCell:
                        return 44
                    case .detailsTitleCell:
                        return 44
                    case .detailsViewCell:
                        return 44
                    default:
                        return 0
                    }
                }
            }
        case 1:
            return 0
        case 2:
            return 0
        default:
            return 0
        }
        return UITableView.automaticDimension
    }
}

//extension ResponseViewController: UITableViewDelegate, UITableViewDataSource {
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 1
//    }
//
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "responseCell", for: indexPath) as! ResponseCell
//        cell.history = self.history
//        cell.mode = self.mode
//        cell.updateUI()
//        return cell
//    }
//}
