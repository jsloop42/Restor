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
        let ts = history.elapsed > 0 ? self.app.formatElapsed(history.elapsed) : ""
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

enum ResponseKVTableType: String {
    case header = "response-header-table-view"
    case cookies = "response-cookies-table-view"
    case details = "response-details-table-view"
}

class ResponseKVCell: UITableViewCell, UITableViewDataSource, UITableViewDelegate {
    //@IBOutlet weak var tableView: EADynamicSizeTableView!
    var tableView: EADynamicSizeTableView!
    var isInit = false
    var request: ERequest?
    var history: EHistory?
    let cellId = "twoColumnCell"
    var tableType: ResponseKVTableType = .header {
        didSet {
            self.tableView.tableViewId = self.tableType.rawValue
        }
    }
    var headers: [String: String] = [:]
    var headerKeys: [String] = []
    var heightMap: [Int: CGFloat] = [:] // [Row: Height]
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
    }
    
    func bootstrap() {
        if !self.isInit {
            UIView.animate(withDuration: 0.3) { self.initUI() }
            self.isInit = true
        }
    }
    
    func initUI() {
        if self.tableView == nil {
            self.tableView = EADynamicSizeTableView(frame: self.contentView.frame, style: .plain)
            self.tableView.drawBorders = true
            self.tableView.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(self.tableView)
            NSLayoutConstraint.activate([
                self.tableView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
                self.tableView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
                self.tableView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
                self.tableView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
            ])
            self.tableView.tableViewId = ResponseKVTableType.header.rawValue
            self.tableView.register(UINib(nibName: "KVCell", bundle: nil), forCellReuseIdentifier: "kvCell")
            self.tableView.delegate = self
            self.tableView.dataSource = self
            self.tableView.estimatedRowHeight = 44
            self.tableView.rowHeight = UITableView.automaticDimension
            self.tableView.separatorStyle = .none
        }
    }
    
    func updateUI() {
        self.updateData()
        self.tableView.reloadData()
    }
    
    func updateData() {
        guard let history = self.history, let headers = history.responseHeaders else { return }
        if let hm = try? JSONSerialization.jsonObject(with: headers, options: .allowFragments) as? [String: String] {
            self.headers = hm
            self.headerKeys = self.headers.allKeys().sorted()
        }
    }

    // MARK: - Table view
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tableType == .header ? self.headerKeys.count : 12
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "kvCell", for: indexPath) as! KVCell
        let row = indexPath.row
        if self.tableType == .header {
            let key = self.headerKeys[row]
            cell.keyLabel.text = key
            //cell.keyLabel.text = "A machine is only as good as the man who programs it. A machine is only as good as the man who programs it"
            cell.valueLabel.text = self.headers[key]
            row == self.headerKeys.count - 1 ? cell.hideBottomBorder() : cell.displayBottomBorder()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        if self.tableType == .header {
            let key = self.headerKeys[row]
            let val = self.headers[key] ?? ""
            //key = "A machine is only as good as the man who programs it. A machine is only as good as the man who programs it"
            let text = val.count >= key.count ? val : key
            Log.debug("text: \(text)")
            let width = tableView.frame.width / 2 - 32
            var h = UI.getTextHeight(text, width: width, font: UIFont.systemFont(ofSize: 14)) + 20
            Log.debug("header cell height h: \(h)")
            if h < 55 { h = 55 }
            self.tableView.setHeight(h, forRowAt: indexPath)
            return h
        }
        return 44
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
    var mode: ResponseMode = .info
    @IBOutlet weak var infoCell: ResponseInfoCell!
    @IBOutlet weak var headersViewCell: ResponseKVCell!
    @IBOutlet weak var cookiesViewCell: ResponseKVCell!
    @IBOutlet weak var detailsViewCell: ResponseKVCell!
    @IBOutlet weak var helpCell: ResponseInfoCell!
    private var headerCellHeight: CGFloat = 0.0
    private var cookieCellHeight: CGFloat = 0.0
    private var detailsCellHeight: CGFloat = 0.0
    private var previousHeaderCellHeight: CGFloat = 0.0
    private var previousCookieCellHeight: CGFloat = 0.0
    private var previousDetailsCellHeight: CGFloat = 0.0
    
    var request: ERequest?
    var history: EHistory?
    
    enum InfoCellId: Int {
        case spacerBeforeInfoCell
        case infoCell
        case headerTitleCell
        case headersViewCell
        case cookiesTitleCell
        case cookiesViewCell
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
        self.initData()
        self.updateUI()
        self.tableView.reloadData()
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
        // info cell
        self.infoCell.request = req
        self.infoCell.history = self.history
        // headers cell
        self.headersViewCell.tableType = .header
        self.headersViewCell.request = req
        self.headersViewCell.history = self.history
        // cookies cell
        self.cookiesViewCell.tableType = .cookies
        self.cookiesViewCell.request = req
        self.cookiesViewCell.history = self.history
        // details cell
        self.detailsViewCell.tableType = .details
        self.detailsViewCell.request = req
        self.detailsViewCell.history = self.history
    }
    
    func initUI() {
        if let tb = self.tabBarController as? RequestTabBarController {
            self.mode = ResponseMode(rawValue: tb.segView.selectedSegmentIndex) ?? .info
            tb.viewNavbarSegment()
        }
        
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.segmentDidChange(_:)), name: .responseSegmentDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.viewRequestHistoryDidTap(_:)), name: .viewRequestHistoryDidTap, object: nil)
        self.nc.addObserver(self, selector: #selector(self.responseDidReceive(_:)), name: .responseDidReceive, object: nil)
        self.nc.addObserver(self, selector: #selector(self.dynamicSizeTableViewHeightDidChange(_:)), name: .dynamicSizeTableViewHeightDidChange, object: nil)
    }
    
    func updateUI() {
        Log.debug("update UI")
        if self.history == nil { return }
        if self.mode == .info {
            self.infoCell.updateUI()
            self.headersViewCell.updateUI()
            self.cookiesViewCell.updateUI()
            self.detailsViewCell.updateUI()
        }
    }
    
    /// Get the dynamic height of the inner table view
    func setHeight(_ height: CGFloat, type: ResponseKVTableType) {
        if type == .header {
            self.headerCellHeight = height
            // Once the height changes, reload the outer table view. Also prevents continuous reloading of the table view.
            if self.headerCellHeight != self.previousHeaderCellHeight {
                self.previousHeaderCellHeight = self.headerCellHeight
                self.tableView.reloadData()
            }
        } else if type == .details {
            self.detailsCellHeight = height
        }
    }
    
    @objc func dynamicSizeTableViewHeightDidChange(_ notif: Notification) {
        Log.debug("dynamic size table view height did change notification")
        if let info = notif.userInfo as? [String: Any], let tableViewId = info["tableViewId"] as? String, let type = ResponseKVTableType(rawValue: tableViewId),
            let height = info["height"] as? CGFloat {
            switch type {
            case .header:
                self.headerCellHeight = height
                self.headersViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.headersViewCell.tableView.shouldReload = true
            case .cookies:
                self.cookieCellHeight = height
                self.cookiesViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.cookiesViewCell.tableView.shouldReload = true
            case .details:
                self.detailsCellHeight = height
                self.detailsViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.detailsViewCell.tableView.shouldReload = true
            }
        }
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
                        if (self.history?.responseHeaders) == nil || self.history?.responseHeaders?.count == 0 { return 0 }
                        return 44
                    case .headersViewCell:
                        self.headersViewCell.tableView.invalidateIntrinsicContentSize()
                        self.headersViewCell.invalidateIntrinsicContentSize()
                        if (self.history?.responseHeaders) == nil || self.history?.responseHeaders!.count == 0 { return 0 }
                        return self.headerCellHeight == 0 ? UITableView.automaticDimension : self.headerCellHeight
                    case .cookiesTitleCell:
                        return 44
                    case .cookiesViewCell:
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
