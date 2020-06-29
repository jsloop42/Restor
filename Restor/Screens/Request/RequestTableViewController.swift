//
//  RequestTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestTableViewController: RestorTableViewController {
    private let app = App.shared
    private lazy var localdb = { CoreDataService.shared }()
    private let utils = EAUtils.shared
    private let nc = NotificationCenter.default
    var request: ERequest?
    var headers: [ERequestData] = []
    var params: [ERequestData] = []
    var requestBody: ERequestBodyData?
    var bodyForms: [ERequestData] = []
    var multipart: [ERequestData] = []
    var binary: ERequestData?
    var binaryFiles: [EFile] = []
    private var tabbarController: RequestTabBarController { self.tabBarController as! RequestTabBarController }
    @IBOutlet weak var envBtn: UIButton!
    @IBOutlet var headerKVTableViewManager: KVTableViewManager!
    @IBOutlet var paramsKVTableViewManager: KVTableViewManager!
    @IBOutlet weak var headersTableView: EADynamicSizeTableView!
    @IBOutlet weak var paramsTableView: EADynamicSizeTableView!
    @IBOutlet weak var methodView: UIView!
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var bodyTitleLabel: UILabel!
    @IBOutlet weak var bodyRawLabel: UILabel!
    @IBOutlet weak var bodyFieldTableView: KVBodyFieldTableView!
    @IBOutlet weak var binaryTextFieldView: UIView!
    @IBOutlet weak var binaryImageView: UIImageView!
    @IBOutlet weak var binaryCollectionView: UICollectionView!
    @IBOutlet weak var goBtn: UIButton!
    private unowned var reqMan: RequestManager?
    private let sendImage = UIImage(named: "send")
    private let stopImage = UIImage(named: "stop")
    private var isRequestInProgress = false
    lazy var activityIndicator = { UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 20, height: 20)) }()
    lazy var activityBarButton = { UIBarButtonItem(customView: self.activityIndicator) }()
    private var selectedEnvIndex = -1
    private var env: EEnv?
    private let defaultEnvText = "env: none"
    
    enum TableType: String {
        case header = "request-header-table-view"
        case param = "request-param-table-view"
    }
    
    enum CellId: Int {
        case env = 0
        case url = 1
        case spacerAfterUrl = 2
        case name = 3
        case headerTitle = 4
        case header = 5
        case paramTitle = 6
        case params = 7
        case bodyTitle = 8
        case body = 9
        case spacerAfterBody = 10
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.request)
        self.tabbarController.hideNavbarSegment()
        self.initData()
        self.initManager()
        self.updateData()
        self.reloadAllTableViews()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc - did load")
        self.initData()
        self.initUI()
        self.initEvents()
        self.updateData()
    }
    
    func initManager() {
        if let req = self.request {
            self.reqMan = AppState.getFromRequestState(req.getId())
            if self.reqMan == nil {
                let man = RequestManager(request: req, env: self.env)
                AppState.addToRequestState(man)
                self.reqMan = man
            }
        }
        if let man = self.reqMan {
            guard let state = man.fsm.currentState else {
                self.displayRequestDidCompleteUIChanges()
                return
            }
            if state.classForCoder != RequestCancelState.self {
                self.displayRequestInProgressUIChanges()
            }
        }
    }
    
    func initData() {
        self.request = self.tabbarController.request
        if let envId = self.request?.envId, let env = self.localdb.getEnv(id: envId) {
            self.env = env
            self.updateEnv()
        }
    }
    
    func initUI() {
        self.tabbarController.hideNavbarSegment()
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.view.backgroundColor = App.Color.tableViewBg
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.bodyRawLabel.font = App.Font.monospace13
        self.renderTheme()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.requestDidChange(_:)), name: .requestDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.editButtonDidTap(_:)), name: .editRequestDidTap, object: nil)
        self.nc.addObserver(self, selector: #selector(self.dynamicSizeTableViewHeightDidChange(_:)), name: .dynamicSizeTableViewHeightDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.responseDidReceive(_:)), name: .responseDidReceive, object: nil)
        self.nc.addObserver(self, selector: #selector(self.requestDidCancel(_:)), name: .requestDidCancel, object: nil)
        self.nc.addObserver(self, selector: #selector(self.envDidSelect(_:)), name: .envDidSelect, object: nil)
        self.nc.addObserver(self, selector: #selector(self.extrapolateDidFail(_:)), name: .extrapolateDidFail, object: nil)
    }
    
    func initHeadersTableViewManager() {
        self.headersTableView.tableViewId = TableType.header.rawValue
        self.headerKVTableViewManager.request = self.request
        self.headerKVTableViewManager.kvTableView = self.headersTableView
        self.headerKVTableViewManager.delegate = self
        self.headerKVTableViewManager.tableViewType = .header
        self.headerKVTableViewManager.bootstrap()
        self.headerKVTableViewManager.reloadData()
    }
    
    func initParamsTableViewManager() {
        self.paramsTableView.tableViewId = TableType.param.rawValue
        self.paramsKVTableViewManager.request = self.request
        self.paramsKVTableViewManager.kvTableView = self.paramsTableView
        self.paramsKVTableViewManager.delegate = self
        self.paramsKVTableViewManager.tableViewType = .params
        self.paramsKVTableViewManager.bootstrap()
        self.paramsKVTableViewManager.reloadData()
    }
    
    func renderTheme() {
        //self.methodView.backgroundColor = App.Color.requestMethodBg
    }
    
    func reloadAllTableViews() {
        DispatchQueue.main.async {
            self.headerKVTableViewManager.reloadData()
            self.paramsKVTableViewManager.reloadData()
            self.reloadData()
        }
    }
    
    @objc func dynamicSizeTableViewHeightDidChange(_ notif: Notification) {
        Log.debug("request screen - dynamic table view height did change")
        if let info = notif.userInfo as? [String: Any], let tableViewId = info["tableViewId"] as? String, let height = info["height"] as? CGFloat,
            let tableType = TableType(rawValue: tableViewId) {
            switch tableType {
            case .header:
                Log.debug("request header cell height updated: \(height)")
                self.headersTableView.shouldReload = false
                self.reloadAllTableViews()
                self.headersTableView.shouldReload = true
            case .param:
                Log.debug("request param cell height updated: \(height)")
                self.paramsTableView.shouldReload = false
                self.reloadAllTableViews()
                self.paramsTableView.shouldReload = true
            }
        }
    }
    
    @IBAction func envBtnDidTap(_ sender: Any) {
        Log.debug("env btn did tap")
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.envPickerVC.rawValue) as? EnvironmentPickerViewController {
            vc.selectedIndex = self.selectedEnvIndex
            vc.env = self.env
            self.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func envDidSelect(_ notif: Notification) {
        Log.debug("env did select notification")
        if let info = notif.userInfo as? [String: Any], let idx = info["index"] as? Int {
            DispatchQueue.main.async {
                Log.debug("env did change")
                self.env = info["env"] as? EEnv
                self.selectedEnvIndex = idx
                if let env = self.env {
                    self.request?.envId = env.getId()
                } else {
                    self.request?.envId = ""
                }
                self.localdb.saveMainContext()
                self.updateEnv()
            }
        }
    }

    func updateEnv() {
        if let env = self.env {
            let name = env.getName()
            self.envBtn.setTitle("env: \(name)", for: .normal)
        } else {
            self.envBtn.setTitle(self.defaultEnvText, for: .normal)
        }
    }

    @objc func editButtonDidTap(_ notif: Notification) {
        Log.debug("edit button did tap")
        guard let info = notif.userInfo, let req = info["request"] as? ERequest, req.getId() == self.request?.getId() else { return }
        DispatchQueue.main.async { self.viewEditRequestVC() }
    }
    
    @objc func requestDidChange(_ notif: Notification) {
        Log.debug("request did change notif")
        DispatchQueue.main.async {
            if let info = notif.userInfo as? [String: Any], let req = info["request"] as? ERequest, req.getId() == self.request?.getId() {
                self.request = req
                self.tabbarController.request = req
                Log.debug("current request did change - reloading views")
                if let reqMan = AppState.getFromRequestState(req.getId()) {  // On edit request, cancel existing one and remove the current manager from state
                    reqMan.cancelRequest()
                    self.reqMan = nil
                    AppState.removeFromRequestState(req.getId())
                }
                self.initData()
                self.updateData()
                self.reloadAllTableViews()
            }
        }
    }
    
    @objc func responseDidReceive(_ notif: Notification) {
        Log.debug("response did receive")
        if let info = notif.userInfo as? [String: Any], let respData = info["data"] as? ResponseData, let reqId = self.request?.getId(), reqId == respData.requestId {
            DispatchQueue.main.async {
                self.isRequestInProgress = false
                UIView.animate(withDuration: 0.3) {
                    self.displayRequestDidCompleteUIChanges()
                }
            }
        }
    }
    
    @objc func requestDidCancel(_ notif: Notification) {
        Log.debug("request did cancel")
        if let info = notif.userInfo as? [String: Any], let request = info["request"] as? ERequest, let reqId = self.request?.getId(), request.getId() == reqId {
            DispatchQueue.main.async {
                self.isRequestInProgress = false
                UIView.animate(withDuration: 0.3) {
                    self.displayRequestDidCompleteUIChanges()
                }
            }
        }
    }
    
    @objc func extrapolateDidFail(_ notif: Notification) {
        Log.debug("extrapolate did fail notif")
        if let info = notif.userInfo as? [String: String], let msg = info["msg"] {
            DispatchQueue.main.async {
                UI.viewToast(msg, hideSec: 3, vc: self, completion: nil)
            }
        }
    }
    
    @IBAction func goButtonDidTap(_ sender: Any) {
        Log.debug("go button did tap")
        guard let man = self.reqMan else { return }
        if self.isRequestInProgress {
            man.cancelRequest()
            return
        }
        self.initManager()
        self.reqMan?.env = self.env
        man.start()
        self.isRequestInProgress = true
        UIView.animate(withDuration: 0.3) {
            self.displayRequestInProgressUIChanges()
        }
    }
    
    func displayRequestInProgressUIChanges() {
        self.displayCancelButton()
        self.displayActivityIndicator()
    }
    
    func displayRequestDidCompleteUIChanges() {
        self.displaySendButton()
        self.hideActivityIndicator()
    }
    
    func displaySendButton() {
        self.goBtn.layer.opacity = 0.5
        self.goBtn.setImage(self.sendImage, for: .normal)
        self.goBtn.layer.opacity = 1.0
    }
    
    func displayCancelButton() {
        self.goBtn.layer.opacity = 0.5
        self.goBtn.setImage(self.stopImage, for: .normal)
        self.goBtn.layer.opacity = 1.0
    }
    
    func displayActivityIndicator() {
        self.tabbarController.navigationItem.rightBarButtonItem = nil
        self.tabbarController.navigationItem.setRightBarButton(self.activityBarButton, animated: true)
        self.activityIndicator.startAnimating()
    }
    
    func hideActivityIndicator() {
        self.activityIndicator.stopAnimating()
        self.tabBarController?.navigationItem.rightBarButtonItem = nil
        self.tabbarController.addNavigationBarEditButton()
    }
    
    func viewEditRequestVC() {
        Log.debug("view edit request vc")
        if let req = self.request { self.nc.post(name: .editRequestVCShouldPresent, object: self, userInfo: ["request": req]) }
    }
    
    func updateData() {
        Log.debug("request vc - \(String(describing: self.request))")
        guard let request = self.request else { return }
        let reqId = request.getId()
        self.headers = self.localdb.getHeadersRequestData(reqId)
        self.params = self.localdb.getParamsRequestData(reqId)
        self.headerKVTableViewManager.kvTableView?.resetMeta()
        self.paramsKVTableViewManager.kvTableView?.resetMeta()
        guard let proj = request.project else { return }
        if let method = self.localdb.getRequestMethodData(at: request.selectedMethodIndex.toInt(), projId: proj.getId()) {
            self.methodLabel.text = method.name
        } else {
            self.methodLabel.text = "GET"
        }
        self.urlLabel.text = request.url
        self.nameLabel.text = request.name
        self.nameLabel.sizeToFit()
        self.descLabel.text = request.desc
        self.descLabel.sizeToFit()
        self.requestBody = request.body
        guard let body = self.requestBody else { return }
        guard let bodyType = RequestBodyType(rawValue: body.selected.toInt()) else { return }
        self.bodyForms = []
        self.multipart = []
        self.binaryCollectionView.delegate = nil
        self.binaryCollectionView.dataSource = nil
        self.binaryImageView.isHidden = true
        if bodyType == .form {
            self.bodyForms = self.localdb.getFormRequestData(body.getId(), type: .form)
        } else if bodyType == .multipart {
            self.multipart = self.localdb.getFormRequestData(body.getId(), type: .multipart)
        } else if bodyType == .binary {
            if let bin = body.binary {
                self.binary = bin
                if let files = bin.files, !files.isEmpty {
                    self.binaryFiles = self.localdb.getFiles(bin.getId(), type: .binary)
                }
            }
        }
        self.setBodyTitleLabel(RequestBodyType.toString(body.selected.toInt()))
        self.updateBodyCell()
        self.reloadAllTableViews()
    }
    
    func updateBodyCell() {
        guard let body = self.requestBody else { return }
        guard let bodyType = RequestBodyType(rawValue: body.selected.toInt()) else { return }
        switch bodyType {
        case .json:
            self.bodyRawLabel.text = body.json
            self.bodyRawLabel.isHidden = false
            self.bodyFieldTableView.resetTableView()
            self.bodyFieldTableView.isHidden = true
            self.binaryTextFieldView.isHidden = true
        case .xml:
            self.bodyRawLabel.text = body.xml
            self.bodyRawLabel.isHidden = false
            self.bodyFieldTableView.resetTableView()
            self.bodyFieldTableView.isHidden = true
            self.binaryTextFieldView.isHidden = true
        case .raw:
            self.bodyRawLabel.text = body.raw
            self.bodyRawLabel.isHidden = false
            self.bodyFieldTableView.resetTableView()
            self.bodyFieldTableView.isHidden = true
            self.binaryTextFieldView.isHidden = true
        case .form:
            if self.bodyForms.isEmpty { return }
            self.bodyRawLabel.isHidden = true
            self.bodyFieldTableView.isHidden = false
            self.bodyFieldTableView.body = body
            self.bodyFieldTableView.bodyType = bodyType
            self.bodyFieldTableView.forms = self.bodyForms
            self.bodyFieldTableView.request = self.request
            self.binaryTextFieldView.isHidden = true
        case .multipart:
            if self.multipart.isEmpty { return }
            self.bodyRawLabel.isHidden = true
            self.bodyFieldTableView.isHidden = false
            self.bodyFieldTableView.body = body
            self.bodyFieldTableView.bodyType = bodyType
            self.bodyFieldTableView.multipart = self.multipart
            self.bodyFieldTableView.request = self.request
            self.binaryTextFieldView.isHidden = true
        case .binary:
            self.bodyFieldTableView.resetTableView()
            self.bodyFieldTableView.isHidden = true
            self.bodyRawLabel.isHidden = true
            self.binaryCollectionView.delegate = self
            self.binaryCollectionView.dataSource = self
            if self.binaryFiles.isEmpty { self.resetBinaryCollectionView() }
            self.binaryCollectionView.isHidden = self.binaryFiles.isEmpty
            self.binaryTextFieldView.isHidden = false
            self.binaryCollectionView.reloadData()
            self.binaryImageView.isHidden = true
            if let bin = self.requestBody?.binary, let image = bin.image, let data = image.data {
                self.binaryImageView.image = UIImage(data: data)
                self.binaryImageView.isHidden = false
            }
        }
        self.bodyFieldTableView.reloadData()
        self.tableView.reloadData()
    }
}

extension RequestTableViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func resetBinaryCollectionView() {
        self.binaryFiles = []
        self.binaryCollectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.binaryFiles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        Log.debug("file collection view cell")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fileCell", for: indexPath) as! FileCollectionViewCell
        let row = indexPath.row
        let elem = self.binaryFiles[row]
        cell.nameLabel.text = elem.getName()
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 50
        if let cell = collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell {
            width = cell.frame.width
        } else {
            let row = indexPath.row
            let elem = self.binaryFiles[row]
            let name = elem.getName()
            let lbl = UILabel(frame: CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: 19.5))
            lbl.text = name
            lbl.layoutIfNeeded()
            width = lbl.textWidth()
        }
        Log.debug("width: \(width)")
        return CGSize(width: width, height: 23.5)
    }
}

// MARK: - Tableview delegates
extension RequestTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 54
        if indexPath.row == CellId.env.rawValue {
            height = 40
        } else if indexPath.row == CellId.url.rawValue {
            height = 54
        } else if indexPath.row == CellId.spacerAfterUrl.rawValue {
            height = 12
        } else if indexPath.row == CellId.name.rawValue {
            height = max(self.nameLabel.frame.size.height + self.descLabel.frame.size.height + 93.5, 167)
        } else if indexPath.row == CellId.headerTitle.rawValue {
            height = 44
            if self.headers.isEmpty { height = 0 }
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            if self.headers.isEmpty {  // static branch prediction always assumes branches to be false
                height = 0
            } else {
                height = self.headerKVTableViewManager.getHeight()
            }
        } else if indexPath.row == CellId.paramTitle.rawValue {
            height = 44
            if self.params.isEmpty { height = 0 }
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            if self.params.isEmpty {
                height = 0
            } else {
                height = self.paramsKVTableViewManager.getHeight()
                //height = self.paramCellHeight
            }
        } else if indexPath.row == CellId.bodyTitle.rawValue {
            if self.requestBody == nil { return 0 }
            height = 44
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            if self.requestBody == nil { return 0 }
            guard let bodyType = RequestBodyType(rawValue: self.requestBody!.selected.toInt()) else { return 0 }
            switch bodyType {
            case .json, .xml, .raw:
                self.bodyFieldTableView.resetTableView()
                self.bodyRawLabel.sizeToFit()
                height = UITableView.automaticDimension
            case .form, .multipart:
                self.bodyFieldTableView.layoutIfNeeded()
                height = max(self.bodyFieldTableView.contentSize.height, 54)
            case .binary:
                height = 54
            }
        } else if indexPath.row == CellId.spacerAfterBody.rawValue {
            height = 12
        } else {
            height = UITableView.automaticDimension
        }
        Log.debug("height: \(String(describing: height)) for index: \(indexPath)")
        return height
    }
}

// MARK: - KVTableViewManager Delegate
extension RequestTableViewController: KVTableViewManagerDelegate {
    func getHeaders() -> [ERequestData] {
        return self.headers
    }
    
    func getParams() -> [ERequestData] {
        return self.params
    }
    
    func getHeadersCount() -> Int {
        return self.headers.count
    }
    
    func getParamsCount() -> Int {
        return self.params.count
    }
    
    func getBody() -> ERequestBodyData? {
        return self.requestBody
    }
    
    func getBodyForms() -> [ERequestData] {
        return self.bodyForms
    }
    
    func getBodyFormsCount() -> Int {
        return self.bodyForms.count
    }
    
    func setBodyTitleLabel(_ text: String) {
        self.bodyTitleLabel.text = "BODY (\(text))"
        self.tableView.reloadRows(at: [IndexPath(item: CellId.bodyTitle.rawValue, section: 0)], with: .none)
    }
    
    func reloadData() {
        //self.updateData()
        self.tableView.reloadData()
    }
}

class KVHeaderCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
}

class KVContentCell: UITableViewCell {
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
}

class KVBodyFieldTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var fieldImageView: UIImageView!
    @IBOutlet weak var fileCollectionView: UICollectionView!
    @IBOutlet weak var fieldTypeBtn: UIButton!
    var fieldType: RequestBodyFormFieldFormatType = .text
    var files: [EFile] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.fileCollectionView.delegate = self
        self.fileCollectionView.dataSource = self
        self.fileCollectionView.isHidden = true
        self.fieldImageView.isHidden = true
        self.hideFieldTypeUI()
    }
    
    func updateFieldTypeUI() {
        self.fieldTypeBtn.isHidden = false
        if self.fieldType == .text {
            self.fieldTypeBtn.setImage(UIImage(named: "text"), for: .normal)
        } else {
            self.fieldTypeBtn.setImage(UIImage(named: "file"), for: .normal)
        }
    }
    
    func hideFieldTypeUI() {
        self.fieldTypeBtn.isHidden = true
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.files.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        Log.debug("file collection view cell")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fileCell", for: indexPath) as! FileCollectionViewCell
        let row = indexPath.row
        let elem = self.files[row]
        cell.nameLabel.text = elem.getName()
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 50
        if let cell = collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell {
            width = cell.frame.width
        } else {
            let row = indexPath.row
            let elem = self.files[row]
            let name = elem.getName()
            let lbl = UILabel(frame: CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: 19.5))
            lbl.text = name
            lbl.layoutIfNeeded()
            width = lbl.textWidth()
        }
        Log.debug("width: \(width)")
        return CGSize(width: width, height: 23.5)
    }
}

class KVBodyFieldTableView: EADynamicSizeTableView, UITableViewDelegate, UITableViewDataSource {
    var request: ERequest?
    var body: ERequestBodyData?
    var bodyType: RequestBodyType = .json
    var forms: [ERequestData] = []
    var multipart: [ERequestData] = []
    private let app = App.shared
    let labelFont = UIFont.systemFont(ofSize: 14)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Log.debug("kvbodyfieldtableview init")
        self.estimatedRowHeight = 44
        self.delegate = self
        self.dataSource = self
    }
    
    /// Clears all table view data
    func resetTableView() {
        self.forms = []
        self.multipart = []
        self.bodyType = .json
        self.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.bodyType == .form { return self.forms.count }
        if self.bodyType == .multipart { return self.multipart.count }
        return 0
    }
    
    func updateCell(_ cell: KVBodyFieldTableViewCell, indexPath: IndexPath) {
        let row = indexPath.row
        cell.keyLabel.clear()
        cell.valueLabel.clear()
        cell.valueLabel.isHidden = false
        cell.fieldImageView.isHidden = true
        if self.bodyType == .form {
            let elem = forms[row]
            cell.fieldType = RequestBodyFormFieldFormatType(rawValue: elem.fieldFormat.toInt()) ?? .text
            cell.keyLabel.text = self.app.getKVText(elem.key)
            cell.valueLabel.text = self.app.getKVText(elem.value)
            cell.updateFieldTypeUI()
            Log.debug("body form name: \(String(describing: cell.keyLabel.text))")
            Log.debug("body value name: \(String(describing: cell.valueLabel.text))")
            if let img = elem.image, let data = img.data {
                cell.fieldImageView.image = UIImage(data: data)
                cell.valueLabel.isHidden = true
                cell.fieldImageView.isHidden = false
                cell.fileCollectionView.isHidden = true
            }
            if let set = elem.files, !set.isEmpty, let files = set.allObjects as? [EFile] {
                cell.files = files
                cell.fileCollectionView.reloadData()
                cell.fileCollectionView.isHidden = false
                cell.fieldImageView.isHidden = true
                cell.valueLabel.isHidden = true
            }
        } else if self.bodyType == .multipart {
            let elem = multipart[row]
            cell.keyLabel.text = self.app.getKVText(elem.key)
            cell.valueLabel.text = self.app.getKVText(elem.value)
            cell.hideFieldTypeUI()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bodyFieldTableViewCell", for: indexPath) as! KVBodyFieldTableViewCell
        self.updateCell(cell, indexPath: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - Table view manager

protocol KVTableViewManagerDelegate: class {
    func getHeaders() -> [ERequestData]
    func getParams() -> [ERequestData]
    func getHeadersCount() -> Int
    func getParamsCount() -> Int
    func getBody() -> ERequestBodyData?
    func getBodyForms() -> [ERequestData]
    func getBodyFormsCount() -> Int
    /// Sets the body title header text
    func setBodyTitleLabel(_ text: String)
    func reloadData()
}

class KVTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: EADynamicSizeTableView?
    var tableViewType: KVTableViewType = .header
    weak var request: ERequest?
    weak var delegate: KVTableViewManagerDelegate?
    private let app = App.shared
    private let labelFont = UIFont.systemFont(ofSize: 14)
    
    func bootstrap() {
        self.kvTableView?.estimatedRowHeight = 44
    }
    
    func getHeight() -> CGFloat {
        var height = self.kvTableView?.height ?? 0
        if height == 0 { height = self.kvTableView?.contentSize.height ?? 1 }  // A positive height is set so that the table view renders properly later on.
        return height
    }
    
    func reloadData() {
        self.kvTableView?.reloadData()
    }
    
    // MARK: - Table view delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.tableViewType {
        case .header:
            return self.delegate?.getHeadersCount() ?? 0
        case .params:
            return self.delegate?.getParamsCount() ?? 0
        default:
            return 0
        }
    }
    
    func getContentCellId() -> String {
        switch self.tableViewType {
        case .header:
            return "kvHeaderContentCell"
        case .params:
            return "kvParamsContentCell"
        case .body:
            return "bodyContentCell"
        }
    }
    
    func getElem(_ indexPath: IndexPath) -> ERequestData? {
        var elem: ERequestData?
        let row = indexPath.row
        switch self.tableViewType {
        case .header:
            if let xs = self.delegate?.getHeaders() { elem = xs[row] }
        case .params:
            if let xs = self.delegate?.getParams() { elem = xs[row] }
        default:
            break
        }
        return elem
    }
    
    func getHeight(_ indexPath: IndexPath, tableView: UITableView) -> CGFloat {
        var height: CGFloat = 0.0
        if let elem = self.getElem(indexPath) {
            let key = self.app.getKVText(elem.key)
            let value = self.app.getKVText(elem.value)
            // compute height
            let width = tableView.frame.width
            height = 85 + UI.getTextHeight(key, width: width, font: labelFont) + UI.getTextHeight(value, width: width, font: labelFont)  // 85 is the padding around UI elements
        }
        return height
    }
    
    /// Returns the height of the cell.
    func updateCell(_ cell: KVContentCell, indexPath: IndexPath) {
        cell.keyLabel.clear()
        cell.valueLabel.clear()
        if let elem = self.getElem(indexPath) {
            cell.keyLabel.text = self.app.getKVText(elem.key)
            cell.valueLabel.text = self.app.getKVText(elem.value)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.getContentCellId(), for: indexPath) as! KVContentCell
        self.updateCell(cell, indexPath: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height: CGFloat = self.getHeight(indexPath, tableView: tableView)
        Log.debug("computed height: \(height)")
        self.kvTableView!.setHeight(height, forRowAt: indexPath)
        return height
    }
}
