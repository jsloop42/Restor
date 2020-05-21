//
//  ResponseViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class ResponseCell: UITableViewCell {
    @IBOutlet weak var responseTitleLabel: UILabel!
    @IBOutlet weak var responseHeaderTitleLabel: UILabel!
    @IBOutlet weak var rawLabel: UILabel!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerView: UIView!
    var mode: ResponseMode = .preview
    var history: EHistory?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.initUI()
    }
    
    func initUI() {
        self.updateUI()
    }
    
    func updateUI() {
        switch self.mode {
        case .raw:
            UIView.animate(withDuration: 0.3) {
                self.webView.isHidden = true
                self.rawLabel.isHidden = false
                self.headerView.isHidden = false
                self.rawLabel.text = self.history?.response
                self.rawLabel.sizeToFit()
            }
        case .preview:
            UIView.animate(withDuration: 0.3) {
                self.rawLabel.isHidden = true
                self.webView.isHidden = false
                self.headerView.isHidden = true
                self.webView.loadHTMLString(self.history?.response ?? "", baseURL: nil)
                self.webView.sizeToFit()
            }
        }
    }
}

enum ResponseMode: Int {
    case raw
    case preview
}

class ResponseViewController: RestorViewController {
    private let nc = NotificationCenter.default
    private lazy var ck = { EACloudKit.shared }()
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var utils = { EAUtils.shared }()
    private lazy var tabbarController = { self.tabBarController as! RequestTabBarController }()
    var mode: ResponseMode = .preview
    var status = 0
    var size = 0
    var time = 0  // rtt
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var responseTableView: UITableView!
    @IBOutlet weak var statusCodeView: UIView!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var statusMessageLabel: UILabel!
    @IBOutlet weak var statusSizeLabel: UILabel!
    var request: ERequest?
    var history: EHistory?
    
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
        self.initUI()
        self.initEvents()
        
        self.nameLabel.text = "Get the list of all users filtered by active sorted by first name grouped by location joined by demographics segemented by geolocation"
        self.urlLabel.text = "https://piperway.com/rest/list/user/sort/filter/group?param=search&name=first"
//        self.nameLabel.text = "Get list of all users"
//        self.urlLabel.text = "https://piperway.com/test/list/user"
    }
    
    func initUI() {
        if let tb = self.tabBarController as? RequestTabBarController {
            self.mode = ResponseMode(rawValue: tb.segView.selectedSegmentIndex) ?? .preview
            tb.viewNavbarSegment()
        }
        self.responseTableView.delegate = self
        self.responseTableView.dataSource = self
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.segmentDidChange(_:)), name: .responseSegmentDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.viewRequestHistoryDidTap(_:)), name: .viewRequestHistoryDidTap, object: nil)
        self.nc.addObserver(self, selector: #selector(self.responseDidReceive(_:)), name: .responseDidReceive, object: nil)
    }
    
    func updateUI() {
        guard let history = self.history, let request = self.request else { return }
        self.nameLabel.text = request.name
        self.urlLabel.text = request.url
        if history.statusCode > 0 {
            self.statusCodeLabel.text = "\(history.statusCode)"
            self.statusMessageLabel.text = HTTPStatusCode(rawValue: history.statusCode.toInt())?.toString() ?? ""
            if (200..<299) ~= history.statusCode {
                self.statusCodeView.backgroundColor = UIColor(named: "green")
            } else if (300..<399) ~= history.statusCode {
                self.statusCodeView.backgroundColor = UIColor(named: "purple")
            } else if (400..<500) ~= history.statusCode {
                self.statusCodeView.backgroundColor = UIColor(named: "orange")
            } else if (500..<600) ~= history.statusCode {
                self.statusCodeView.backgroundColor = UIColor(named: "red")
            }
        } else {
            self.statusCodeView.backgroundColor = UIColor(named: "help-text-fg")
        }
        let ts = self.formatElapsed(history.elapsed)
        if history.size > 0 {
            self.statusSizeLabel.text = "\(ts), \(self.utils.bytesToReadable(history.size))"
        } else {
            self.statusSizeLabel.text = "\(ts)"
        }
        self.responseTableView.reloadData()
    }
    
    func formatElapsed(_ elapsed: Int64) -> String {
        var ts = "\(elapsed) ms"
        if elapsed > 60000 {  // minutes
            ts = String(format: "%.2f m", Double(elapsed) / 60000.0)
        } else if elapsed > 1000 {  // second
            ts = String(format: "%.2f s", Double(elapsed) / 1000)
        }
        let xs = ts.components(separatedBy: " ")
        var str = ts
        print("ts: \(ts)")
        print("xs: \(xs)")
        if xs[0].contains(".00") {
            str = "\(xs[0].prefix(xs[0].count - 3)) \(xs[1])"
        }
        if xs[0].suffix(1) == "0" {
            str = "\(xs[0].prefix(xs[0].count - 1)) \(xs[1])"
        }
        return str
    }
    
    @objc func segmentDidChange(_ notif: Notification) {
        Log.debug("segment did change notif")
        if let info = notif.userInfo, let idx = info["index"] as? Int {
            self.ck.saveValue(key: Const.responseSegmentIndexKey, value: idx)
            self.mode = ResponseMode(rawValue: idx) ?? .preview
            self.updateUI()
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
                self.updateUI()
            }
        }
    }
}

extension ResponseViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "responseCell", for: indexPath) as! ResponseCell
        cell.history = self.history
        cell.mode = self.mode
        cell.updateUI()
        return cell
    }
}
