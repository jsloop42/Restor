//
//  RequestTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestTableViewController: UITableViewController {
    private let app = App.shared
    private let localdb = CoreDataService.shared
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
    
    enum CellId: Int {
        case spaceAfterTop = 0
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc - did load")
        self.initData()
        self.initUI()
        self.initEvents()
        self.updateData()
        self.reloadAllTableViews()
    }
    
    func initData() {
        self.request = self.tabbarController.request
        guard let request = self.request else { return }
        let reqId = request.getId()
        self.headers = self.localdb.getHeadersRequestData(reqId)
        self.params = self.localdb.getParamsRequestData(reqId)
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
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.view.backgroundColor = App.Color.tableViewBg
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.addNavigationBarEditButton()
        self.bodyRawLabel.font = App.Font.monospace13
        self.renderTheme()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.requestDidChange(_:)), name: .requestDidChange, object: nil)
    }
    
    /// Display Edit button in navigation bar
    func addNavigationBarEditButton() {
        self.tabbarController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(self.editButtonDidTap(_:)))
    }
    
    func initHeadersTableViewManager() {
        self.headerKVTableViewManager.request = self.request
        self.headerKVTableViewManager.kvTableView = self.headersTableView
        self.headerKVTableViewManager.delegate = self
        self.headerKVTableViewManager.tableViewType = .header
        self.headerKVTableViewManager.bootstrap()
        self.headerKVTableViewManager.reloadData()
    }
    
    func initParamsTableViewManager() {
        self.paramsKVTableViewManager.request = self.request
        self.paramsKVTableViewManager.kvTableView = self.paramsTableView
        self.paramsKVTableViewManager.delegate = self
        self.paramsKVTableViewManager.tableViewType = .params
        self.paramsKVTableViewManager.bootstrap()
        self.paramsKVTableViewManager.reloadData()
    }
    
    func renderTheme() {
        self.methodView.backgroundColor = App.Color.requestMethodBg
    }
    
    func reloadAllTableViews() {
        self.headerKVTableViewManager.reloadData()
        self.paramsKVTableViewManager.reloadData()
        self.reloadData()
    }
    
    @objc func editButtonDidTap(_ sender: Any) {
        Log.debug("edit button did tap")
        self.viewEditRequestVC()
    }
    
    @objc func requestDidChange(_ notif: Notification) {
        Log.debug("request did change notif")
        DispatchQueue.main.async {
            if let info = notif.userInfo as? [String: String], let reqId = info["requestId"], reqId == self.request?.getId() {
                Log.debug("current request did change - reloading views")
                self.initData()
                self.updateData()
                self.reloadAllTableViews()
            }
        }
    }
    
    func viewEditRequestVC() {
        Log.debug("view edit request vc")
        AppState.editRequest = self.request
        UI.pushScreen(self.navigationController!, storyboardId: StoryboardId.editRequestVC.rawValue)
    }
    
    func updateData() {
        Log.debug("request vc - \(String(describing: self.request))")
        guard let req = self.request, let proj = req.project else { return }
        if let method = self.localdb.getRequestMethodData(at: req.selectedMethodIndex.toInt(), projId: proj.getId()) {
            self.methodLabel.text = method.name
        } else {
            self.methodLabel.text = "GET"
        }
        self.urlLabel.text = req.url
        // self.urlLabel.text = "https://example.com/api/image/2458C0A7-538A-4A4B-9788-971BD38934BD/olive/imCJHoKQhHRWStsT3MkGiPbg.jpg"
        self.nameLabel.text = req.name
        self.nameLabel.sizeToFit()
        self.descLabel.text = req.desc
        self.descLabel.text =
        """
        There's a place in my mind
        No one knows where it hides
        And my fantasy is flying
        It's a castle in the sky
        
        It's a world of our past
        Where the legend still lasts
        And the king wears the crown
        But the magic spell is law
        
        Take your sword and your shield
        There's a battle on the field
        You're a knight and you're right
        So with dragons now you'll fight
        
        And my fancy is flying
        It's a castle in the sky
        Or there's nothing out there
        These are castles in the air
        
        Fairytales live in me
        Fables coming from my memory
        Fantasy is not a crime
        Find your castle in the sky
        
        You've got the key
        Of the kingdom of the clouds
        Open the door
        Leaving back your doubts
        
        You've got the power
        To live another childhood
        So ride the wind
        That leads you to the moon 'cause...
        """
        self.descLabel.text = ""
        self.descLabel.sizeToFit()
//        self.urlTextField.text = req.url
//        self.nameTextField.text = req.name
//        if let x = req.desc, !x.isEmpty {
//            self.descTextView.text = x
//        } else {
//            self.descTextView.isHidden = true
//            self.descBorderView.isHidden = true
//        }
        self.updateBodyCell()
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
        if indexPath.row == CellId.spaceAfterTop.rawValue {
            height = 12
        } else if indexPath.row == CellId.url.rawValue {
            height = 54
        } else if indexPath.row == CellId.spacerAfterUrl.rawValue {
            height = 12
        } else if indexPath.row == CellId.name.rawValue {
            let h = self.nameLabel.frame.size.height + self.descLabel.frame.size.height + 93.5
            height = h > 167 ? h : 167  // 167
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
                height = self.bodyFieldTableView.contentSize.height
                height = height < 54 ? 54 : height
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
        self.updateData()
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
    
    func bootstrap() {
        self.kvTableView?.estimatedRowHeight = 44
    }
    
    func getHeight() -> CGFloat {
        let height: CGFloat = 44
        guard let tv = self.kvTableView else { return height }
        tv.layoutIfNeeded()
        let h = tv.contentSize.height
        Log.debug("kvtableview content size: \(h)")
        return h > 0 ? h + 4 : height
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
    
    func updateCell(_ cell: KVContentCell, indexPath: IndexPath) {
        let row = indexPath.row
        cell.keyLabel.clear()
        cell.valueLabel.clear()
        switch self.tableViewType {
        case .header:
            if let xs = self.delegate?.getHeaders() {
                let elem = xs[row]
                cell.keyLabel.text = self.app.getKVText(elem.key)
                //cell.keyLabel.text = "The sacrifice is hard son, but you're no stranger to it. The sacrifice is hard son, but you're no stranger to it. "
                cell.valueLabel.text = self.app.getKVText(elem.value)
            }
        case .params:
            if let xs = self.delegate?.getParams() {
                let elem = xs[row]
                cell.keyLabel.text = self.app.getKVText(elem.key)
                cell.valueLabel.text = self.app.getKVText(elem.value)
            }
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.getContentCellId(), for: indexPath) as! KVContentCell
        self.updateCell(cell, indexPath: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
