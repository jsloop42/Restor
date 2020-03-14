//
//  RequestTableViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

typealias RequestVC = RequestTableViewController

class RequestTableViewController: UITableViewController, UITextFieldDelegate, UITextViewDelegate {
    static weak var shared: RequestTableViewController?
    @IBOutlet weak var methodView: UIView!
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var urlTextField: EATextField!
    @IBOutlet weak var nameTextField: EATextField!
    @IBOutlet weak var descTextView: EATextView!
    @IBOutlet var headerKVTableViewManager: KVTableViewManager!
    @IBOutlet var paramsKVTableViewManager: KVTableViewManager!
    @IBOutlet var bodyKVTableViewManager: KVTableViewManager!
    @IBOutlet weak var headersTableView: UITableView!
    @IBOutlet weak var paramsTableView: UITableView!
    @IBOutlet weak var bodyTableView: UITableView!
    @IBOutlet weak var urlCellView: UIView!
    @IBOutlet weak var nameCellView: UIView!
    @IBOutlet weak var headerCellView: UIView!
    @IBOutlet weak var paramsCellView: UIView!
    @IBOutlet weak var bodyCellView: UIView!
    @IBOutlet weak var urlCell: UITableViewCell!
    @IBOutlet weak var nameCell: UITableViewCell!
    @IBOutlet weak var headerCell: UITableViewCell!
    @IBOutlet weak var paramsCell: UITableViewCell!
    @IBOutlet weak var bodyCell: UITableViewCell!
    /// Whether the request is running, in which case, we don't remove any listeners
    var isActive = false
    private let nc = NotificationCenter.default
    let app = App.shared
    var isEndEditing = false
    var isOptionFromNotif = false
    private let docPicker = DocumentPicker.shared
    private let utils = Utils.shared
    private let db = PersistenceService.shared
    private var localdb = CoreDataService.shared
    private lazy var doneBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle("Done", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        btn.setTitleColor(btn.tintColor, for: .normal)
        btn.addTarget(self, action: #selector(self.doneDidTap(_:)), for: .touchUpInside)
        return btn
    }()
    /// Indicates if the request is valid for saving (any changes made).
    private var isDirty = false
    var entityDict: [String: Any] = [:]
    
    enum CellId: Int {
        case url = 0
        case spacerAfterUrl = 1
        case name = 2
        case spacerAfterName = 3
        case header = 4
        case spacerAfterHeader = 5
        case params = 6
        case spacerAfterParams = 7
        case body = 8
        case spacerAfterBody = 9
    }
    
    deinit {
        Log.debug("request tableview deinit")
        RequestTableViewController.shared = nil
        AppState.editRequest = nil
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !self.isActive {
            self.headerKVTableViewManager.destroy()
            self.paramsKVTableViewManager.destroy()
            self.bodyKVTableViewManager.destroy()
            //RequestVC.shared = nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.activeScreen = .requestEdit
        RequestVC.shared = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RequestTableViewController.shared = self
        Log.debug("request table vc view did load")
        self.initState()
        self.initUI()
        self.initEvents()
        if let data = AppState.editRequest {
            self.entityDict = self.localdb.requestToDictionary(data)
            Log.debug("initial entity dic: \(self.entityDict)")
        }
    }
        
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        if let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext,
            let x = self.localdb.getRequestMethodData(at: 0, reqId: reqId, ctx: ctx) {
            self.methodLabel.text = x.name
        }
        self.urlTextField.delegate = self
        self.nameTextField.delegate = self
        self.descTextView.delegate = self
        // Set bottom border
        //self.app.updateTextFieldWithBottomBorder(self.urlTextField)
        self.addDoneButton()
        // Color
        self.urlTextField.isColor = false
        //self.nameTextField.borderOffsetY = 2
        self.nameTextField.isColor = false
        //self.app.updateTextFieldWithBottomBorder(self.nameTextField)
        // test
        self.urlCell.borderColor = .clear
        self.nameCell.borderColor = .clear
        self.headerCell.borderColor = .clear
        self.paramsCell.borderColor = .clear
        self.bodyCell.borderColor = .clear
        // end test
        self.renderTheme()
        self.tableView.reloadData()
    }
    
    func initEvents() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        self.urlTextField.addTarget(self, action: #selector(self.updateStateForTextField(_:)), for: .editingChanged)
        self.nameTextField.addTarget(self, action: #selector(self.updateStateForTextField(_:)), for: .editingChanged)
        self.nc.addObserver(self, selector: #selector(self.reloadTableView), name: NotificationKey.requestTableViewReload, object: nil)
        self.nc.addObserver(self, selector: #selector(self.clearEditing), name: NotificationKey.requestViewClearEditing, object: nil)
        let methodTap = UITapGestureRecognizer(target: self, action: #selector(self.methodViewDidTap))
        self.methodView.addGestureRecognizer(methodTap)
        self.nc.addObserver(self, selector: #selector(self.requestMethodDidChange(_:)), name: NotificationKey.requestMethodDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.customRequestMethodDidAdd(_:)), name: NotificationKey.customRequestMethodDidAdd, object: nil)
        self.nc.addObserver(self, selector: #selector(self.customRequestMethodShouldDelete(_:)), name: NotificationKey.customRequestMethodShouldDelete, object: nil)
        self.nc.addObserver(self, selector: #selector(self.requestBodyDidChange(_:)), name: NotificationKey.requestBodyTypeDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentOptionsScreen(_:)), name: NotificationKey.optionScreenShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentDocumentMenuPicker(_:)), name: NotificationKey.documentPickerMenuShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentDocumentPicker(_:)), name: NotificationKey.documentPickerShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentImagePicker(_:)), name: NotificationKey.imagePickerShouldPresent, object: nil)
    }

    func initState() {
        // using child context
//        if let proj = AppState.currentProject, let projId = proj.id {
//            let n = self.localdb.getRequestsCount(projectId: projId, ctx: proj.managedObjectContext)
//            AppState.editRequest = self.localdb.createRequest(id: self.utils.genRandomString(), index: n, name: "", ctx: self.localdb.childMOC)
//        }
        // TODO: save child context on request save
    }
    
    func initHeadersTableViewManager() {
        self.headerKVTableViewManager.kvTableView = self.headersTableView
        self.headerKVTableViewManager.delegate = self
        self.headerKVTableViewManager.tableViewType = .header
        self.headerKVTableViewManager.bootstrap()
        self.headerKVTableViewManager.reloadData()
    }
    
    func initParamsTableViewManager() {
        self.paramsKVTableViewManager.kvTableView = self.paramsTableView
        self.paramsKVTableViewManager.delegate = self
        self.paramsKVTableViewManager.tableViewType = .params
        self.paramsKVTableViewManager.bootstrap()
        self.paramsKVTableViewManager.reloadData()
    }
    
    func initBodyTableViewManager() {
        self.bodyKVTableViewManager.kvTableView = self.bodyTableView
        self.bodyKVTableViewManager.delegate = self
        self.bodyKVTableViewManager.tableViewType = .body
        self.bodyKVTableViewManager.bootstrap()
        self.bodyKVTableViewManager.reloadData()
    }
    
    func renderTheme() {
        self.methodView.backgroundColor = App.Color.requestMethodBg
    }
    
    func addDoneButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.doneBtn)
        self.disableDoneButton()
    }
    
    func enableDoneButton() {
        DispatchQueue.main.async {
            self.doneBtn.setTitleColor(self.doneBtn.tintColor, for: .normal)
            self.doneBtn.isEnabled = true
            self.isDirty = true
        }
    }
    
    func disableDoneButton() {
        DispatchQueue.main.async {
            self.doneBtn.setTitleColor(App.Color.requestEditDoneBtnDisabled, for: .normal)
            self.doneBtn.isEnabled = false
            self.isDirty = false
        }
    }
    
    func updateDoneButton(_ enabled: Bool) {
        DispatchQueue.main.async { enabled ? self.enableDoneButton() : self.disableDoneButton() }
    }
    
    func close() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func doneDidTap(_ sender: Any) {
        Log.debug("Done did tap")
        if self.isDirty && AppState.editRequest != nil {
            AppState.editRequest!.project = AppState.currentProject
            AppState.editRequest?.methods?.allObjects.forEach { method in AppState.editRequest?.project?.addToRequestMethods(method as! ERequestMethodData) }
            self.localdb.saveChildContext(AppState.editRequest!)
            self.isDirty = false
            self.close()
        }
    }
    
    @objc func methodViewDidTap() {
        Log.debug("method view did tap")
        guard let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext else { return }
        let xs = self.localdb.getRequestMethodData(reqId: reqId, ctx: ctx)
        let model: [String] = xs.compactMap { reqData -> String? in reqData.name }
        self.app.presentOptionPicker(type: .requestMethod, title: "Request Method", modelIndex: 0, selectedIndex: data.selectedMethodIndex.toInt(), data: model,
                                     modelxs: xs, storyboard: self.storyboard!, navVC: self.navigationController!)
    }
    
    @objc func requestMethodDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let name = info[Const.requestMethodNameKey] as? String,
            let idx = info[Const.optionSelectedIndexKey] as? Int {
            DispatchQueue.main.async {
                self.methodLabel.text = name
                let i = idx.toInt32()
                AppState.editRequest?.selectedMethodIndex = i
                self.app.didRequestChange(AppState.editRequest!, request: self.entityDict, callback: { [weak self] status in self?.updateDoneButton(status) })
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }
    }
    
    @objc func customRequestMethodDidAdd(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let name = info[Const.requestMethodNameKey] as? String,
            let idx = info[Const.modelIndexKey] as? Int, let data = AppState.editRequest, let ctx = data.managedObjectContext {
            if let method = self.localdb.createRequestMethodData(id: self.utils.genRandomString(), index: idx, name: name, checkExists: true, ctx: ctx) {
                method.request = data
                self.app.didRequestChange(AppState.editRequest!, request: self.entityDict, callback: { [weak self] status in self?.updateDoneButton(status) })
                self.nc.post(name: NotificationKey.optionPickerShouldReload, object: self,
                             userInfo: [Const.optionModelKey: method, Const.optionDataActionKey: OptionDataAction.add])
            }
        }
    }
    
    @objc func customRequestMethodShouldDelete(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let data = info[Const.optionModelKey] as? ERequestMethodData {
            if let id = data.id {
                data.project = nil
                data.request = nil
                self.localdb.deleteEntity(data)
                self.app.didRequestChange(AppState.editRequest!, request: self.entityDict, callback: { [weak self] status in self?.updateDoneButton(status) })
                self.nc.post(name: NotificationKey.optionPickerShouldReload, object: self,
                             userInfo: [Const.optionDataActionKey: OptionDataAction.delete, Const.dataKey: id])
            }
        }
    }
 
    @objc func requestBodyDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let idx = info[Const.optionSelectedIndexKey] as? Int {
            DispatchQueue.main.async {
                if let data = AppState.editRequest, let body = data.body {
                    AppState.editRequest?.body?.selected = idx.toInt32()
                    self.app.didRequestChange(AppState.editRequest!, request: self.entityDict, callback: { [weak self] status in self?.updateDoneButton(status) })
                    self.tableView.reloadRows(at: [IndexPath(row: RequestCellType.body.rawValue, section: 0)], with: .none)
                    self.bodyKVTableViewManager.reloadData()
                }
            }
        }
    }
    
    @objc func presentOptionsScreen(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any] {
            let opt = info[Const.optionTypeKey] as? Int ?? 0
            guard let type = OptionPickerType(rawValue: opt) else { return }
            let modelIndex = info[Const.modelIndexKey] as? Int ?? 0
            let selectedIndex = info[Const.optionSelectedIndexKey] as? Int ?? 0
            let data = info[Const.optionDataKey] as? [String] ?? []
            let title = info[Const.optionTitleKey] as? String ?? ""
            let model = info[Const.optionModelKey]
            DispatchQueue.main.async {
                self.app.presentOptionPicker(type: type, title: title, modelIndex: modelIndex, selectedIndex: selectedIndex, data: data, model: model,
                                             storyboard: self.storyboard!, navVC: self.navigationController!)
            }
        }
    }
    
    @objc func presentDocumentMenuPicker(_ notif: Notification) {
        self.docPicker.presentDocumentMenu(navVC: self.navigationController!, imagePickerDelegate: self, documentPickerDelegate: self)
    }
    
    @objc func presentDocumentPicker(_ notif: Notification) {
        self.docPicker.presentDocumentPicker(navVC: self.navigationController!, vc: self, completion: nil)
    }
    
    @objc func presentImagePicker(_ notif: Notification) {
        self.docPicker.presentPhotoPicker(navVC: self.navigationController!, isCamera: DocumentPickerState.isCameraMode, vc: self, completion: nil)
    }
    
    @objc func endEditing() {
        Log.debug("entity dict: \(self.entityDict)")
        Log.debug("edit request: \(AppState.editRequest)")
        Log.debug("end editing")
        self.isEndEditing = true
        UI.endEditing()
        self.clearEditing()
        DispatchQueue.main.async {
            self.isEndEditing = false
        }
    }
    
    @objc func clearEditing(_ completion: (() -> Void)? = nil) {
        var status = ["header": false, "params": false, "body": false]
        let cb: () -> Void = {
            if status.values.allSatisfy({ flag -> Bool in return flag }) {
                if completion != nil { completion!() }
            }
        }
        self.headerKVTableViewManager.clearEditing { _ in
            status["header"] = true
            cb()
        }
        self.paramsKVTableViewManager.clearEditing { _ in
            status["params"] = true
            cb()
        }
        self.bodyKVTableViewManager.clearEditing { _ in
            status["body"] = true
            cb()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("request table view did select")
        self.clearEditing()
        if indexPath.row == CellId.header.rawValue {
            if let tv = self.headerKVTableViewManager.kvTableView { self.headerKVTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        } else if indexPath.row == CellId.params.rawValue {
            if let tv = self.paramsKVTableViewManager.kvTableView {
                self.paramsKVTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        } else if indexPath.row == CellId.body.rawValue {
            if let tv = self.bodyKVTableViewManager.kvTableView {
                self.bodyKVTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat!
        if indexPath.row == CellId.url.rawValue {
            height = 54
        } else if indexPath.row == CellId.spacerAfterUrl.rawValue {
            height = 12
        } else if indexPath.row == CellId.name.rawValue {
            height = 167
        } else if indexPath.row == CellId.spacerAfterName.rawValue {
            height = 16
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            height = self.headerKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterHeader.rawValue {
            height = 12
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            height = self.paramsKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterParams.rawValue {
            height = 12
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            if let body = AppState.editRequest?.body, body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue {
                return RequestVC.bodyFormCellHeight()
            }
            height = self.bodyKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterBody.rawValue {
            height = 12
        } else {
            height = UITableView.automaticDimension
        }
        Log.debug("height: \(height) for index: \(indexPath)")
        return height
    }
    
    @objc func reloadTableView() {
        Log.debug("request table view reload")
        self.bodyKVTableViewManager.reloadData()
        self.reloadData()
    }
    
    func reloadAllTableViews() {
        self.headerKVTableViewManager.reloadData()
        self.paramsKVTableViewManager.reloadData()
        self.bodyKVTableViewManager.reloadData()
        self.tableView.reloadData()
    }
    
    @objc func updateStateForTextField(_ textField: UITextField) {
        if textField == self.urlTextField {
            AppState.editRequest!.url = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if textField == self.nameTextField {
            AppState.editRequest!.name = textField.text ?? ""
        }
        self.app.didRequestChange(AppState.editRequest!, request: self.entityDict, callback: { [weak self] status in self?.updateDoneButton(status) })
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        RequestVC.shared?.clearEditing()
        //self.updateStateForTextField(textField)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.updateStateForTextField(textField)
    }
        
    func textViewDidBeginEditing(_ textView: UITextView) {
        RequestVC.shared?.clearEditing()
        // TODO
        // self.updateDoneButton(self.app.didRequestDescriptionChange(textView.text ?? "", request: self.entityDict))
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == self.descTextView {
            AppState.editRequest!.desc = textView.text ?? ""
            self.app.didRequestChange(AppState.editRequest!, request: self.entityDict, callback: { [weak self] status in self?.updateDoneButton(status) })
        }
    }
    
    static func addRequestBodyToState() {
        if let req = AppState.editRequest, let moc = req.managedObjectContext {
            if req.body == nil {
                req.body = CoreDataService.shared.createRequestBodyData(id: Utils.shared.genRandomString(), index: 0, ctx: moc)
                AppState.editRequest!.body?.request = AppState.editRequest
            }
        }
        if let vc = RequestVC.shared {
            vc.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
        }
    }
    
    static func bodyFormCellHeight() -> CGFloat {
        if let body = AppState.editRequest!.body, let form = body.form {
            let count: Double = form.allObjects.count == 0 ? 1 : Double(form.allObjects.count)
            return CGFloat(count * 92.5) + 57  // 84: field cell, 81: title cell
        }
        return 92.5 + 57  // 84 + 77
    }
}

extension RequestTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        Log.debug("image picker controller delegate")
        self.docPicker.imagePickerController(picker, didFinishPickingMediaWithInfo: info)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Log.debug("image picker did cancel")
        self.docPicker.imagePickerControllerDidCancel(picker)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension RequestTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.docPicker.documentPicker(controller, didPickDocumentsAt: urls)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.docPicker.documentPickerWasCancelled(controller)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension RequestTableViewController: KVTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
}

enum KVTableViewType {
    case header
    case params
    case body
}

protocol KVTableViewDelegate: class {
    func reloadData()
    //func presentOptionsVC(_ data: [String], selected: Int)
}

class KVHeaderCell: UITableViewCell {
    @IBOutlet weak var headerTitleBtn: UIButton!
}

protocol KVContentCellDelegate: class {
    func enableEditing(indexPath: IndexPath)
    func disableEditing(indexPath: IndexPath)
    func clearEditing(completion: ((Bool) -> Void)?)
    //func deleteRow(indexPath: IndexPath)
    func deleteRow(_ reqDataId: String, type: RequestCellType)
    //func presentOptionsVC(_ data: [String], selected: Int)
    func dataDidChange(key: String, value: String, reqDataId: String, row: Int)
    func refreshCell(indexPath: IndexPath, cell: KVContentCellType)
}

protocol KVContentCellType: class {
    var isEditingActive: Bool { get set }
    var editingIndexPath: IndexPath? { get set }
    func getDeleteView() -> UIView
    func getContainerView() -> UIView
}

// MARK: - Key-Value content cell

class KVContentCell: UITableViewCell, KVContentCellType, UITextFieldDelegate {
    @IBOutlet weak var keyTextField: EATextField!
    @IBOutlet weak var valueTextField: EATextField!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var containerView: UIView!
    weak var delegate: KVContentCellDelegate?
    private let app = App.shared
    var editingIndexPath: IndexPath?
    var isEditingActive = false
    var reqDataId: String = ""
    var type: RequestCellType = .header
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvcontentcell awake from nib")
        self.keyTextField.delegate = self
        self.valueTextField.delegate = self
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.deleteView.isHidden = true
        self.keyTextField.isColor = false
        self.valueTextField.isColor = false
    }
    
    func initEvents() {
        let deleteBtnTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteBtnDidTap))
        deleteBtnTap.cancelsTouchesInView = false
        self.deleteBtn.addGestureRecognizer(deleteBtnTap)
        let deleteViewTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteViewDidTap))
        self.deleteView.addGestureRecognizer(deleteViewTap)
    }
    
    @objc func deleteBtnDidTap() {
        Log.debug("delete row did tap")
        RequestVC.shared?.clearEditing({
            let idxPath = IndexPath(row: self.tag, section: 0)
            self.editingIndexPath = idxPath
            self.delegate?.enableEditing(indexPath: idxPath)
            UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
                self.deleteView.isHidden = false
            }, completion: nil)
        })
    }
    
    @objc func deleteViewDidTap() {
        Log.debug("delete view did tap")
        self.delegate?.deleteRow(reqDataId, type: self.type)
    }
    
    func getDeleteView() -> UIView {
        return self.deleteView
    }
    
    func getContainerView() -> UIView {
        return self.containerView
    }
    
    // MARK: - Delegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        RequestVC.shared?.clearEditing()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let key = self.keyTextField.text ?? ""
        let value = self.valueTextField.text ?? ""
        self.delegate?.dataDidChange(key: key, value: value, reqDataId: reqDataId, row: self.tag)
    }
}

// MARK: - Body cell

class KVBodyContentCell: UITableViewCell, KVContentCellType {
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var typeNameBtn: UIButton!
    @IBOutlet weak var rawTextViewContainer: UIView!
    @IBOutlet weak var rawTextView: EATextView!
    @IBOutlet var bodyLabelViewWidth: NSLayoutConstraint!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var bodyFieldTableView: KVBodyFieldTableView!
    weak var delegate: KVContentCellDelegate?
    var optionsData: [String] = ["json", "xml", "raw", "form", "multipart", "binary"]
    var isEditingActive: Bool = false
    var editingIndexPath: IndexPath?
    var bodyDataId = ""
    private let nc = NotificationCenter.default
    private let localdb = CoreDataService.shared
    private let app = App.shared
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvcontentcell awake from nib")
        self.rawTextView.delegate = self
        self.initUI()
        self.initEvents()
        RequestVC.addRequestBodyToState()
        if RequestVC.shared != nil {
            self.updateState(AppState.editRequest!.body!)
        }
    }
    
    func initUI() {
        self.bodyFieldTableView.isHidden = true
        self.rawTextViewContainer.isHidden = false
        let font = UIFont(name: "Menlo-Regular", size: 13)
        self.rawTextView.font = font
        self.rawTextView.placeholderFont = font
    }
        
    func initEvents() {
        let deleteBtnTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteBtnDidTap))
        deleteBtnTap.cancelsTouchesInView = false
        self.deleteBtn.addGestureRecognizer(deleteBtnTap)
        let deleteViewTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteViewDidTap))
        self.deleteView.addGestureRecognizer(deleteViewTap)
        let typeLabelTap = UITapGestureRecognizer(target: self, action: #selector(self.typeBtnDidTap(_:)))
        self.typeLabel.addGestureRecognizer(typeLabelTap)
    }
    
    @objc func deleteBtnDidTap() {
        Log.debug("delete row did tap")
        RequestVC.shared?.clearEditing({
            self.delegate?.enableEditing(indexPath: IndexPath(row: self.tag, section: 0))
            UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
                self.deleteView.isHidden = false
            }, completion: nil)
        })
    }
    
    @objc func deleteViewDidTap() {
        Log.debug("delete view did tap")
        self.delegate?.deleteRow(self.bodyDataId, type: .body)
        self.bodyFieldTableView.reloadData()
    }
    
    @IBAction func typeBtnDidTap(_ sender: Any) {
        Log.debug("type name did tap")
        var selected: Int! = 0
        guard let ctx = AppState.editRequest?.managedObjectContext else { return }
        if let body = AppState.editRequest!.body { selected = Int(body.selected) }
        self.nc.post(name: NotificationKey.optionScreenShouldPresent, object: self,
                     userInfo: [Const.optionTypeKey: OptionPickerType.requestBodyForm.rawValue,
                                Const.modelIndexKey: self.tag,
                                Const.optionSelectedIndexKey: selected as Any,
                                Const.optionDataKey: RequestBodyType.allCases as [Any],
                                Const.optionModelKey: self.localdb.getRequestBodyData(id: self.bodyDataId, ctx: ctx) as Any])
    }
    
    func getDeleteView() -> UIView {
        return self.deleteView
    }
    
    func getContainerView() -> UIView {
        return self.containerView
    }
    
    func displayFormFields() {
        self.bodyFieldTableView.isHidden = false
        self.rawTextViewContainer.isHidden = true
        RequestVC.addRequestBodyToState()
        if let req = AppState.editRequest, let body = req.body, let type = RequestBodyType(rawValue: body.selected.toInt()) {
            self.bodyFieldTableView.selectedType = type
        }
        self.bodyFieldTableView.reloadData()
    }
    
    func hideFormFields() {
        self.bodyFieldTableView.isHidden = true
        self.rawTextViewContainer.isHidden = false
    }
    
    func updateState(_ data: ERequestBodyData) {
        let idx: Int = Int(data.selected)
        AppState.editRequest!.body!.selected = Int32(idx)
        self.typeLabel.text = "(\(self.optionsData[idx]))"
        self.bodyLabelViewWidth.isActive = false
        switch idx {
        case 0:  // json
            self.rawTextView.text = data.json
            self.rawTextView.placeholder = "{}"
            self.bodyLabelViewWidth.constant = 60
        case 1:  // xml
            self.rawTextView.text = data.xml
            self.rawTextView.placeholder = "<element/>"
            self.bodyLabelViewWidth.constant = 60
        case 2:  // raw
            self.rawTextView.text = data.raw
            self.rawTextView.placeholder = "{}"
            self.bodyLabelViewWidth.constant = 60
        case 3:  // form
            self.displayFormFields()
            self.bodyLabelViewWidth.constant = 63
        case 4:  // multipart
            self.bodyLabelViewWidth.constant = 78
        case 5:  // binary
            self.bodyLabelViewWidth.constant = 63
        default:
            break
        }
        self.bodyLabelViewWidth.isActive = true
        if let vc = RequestVC.shared {
            self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
        }
    }
}

// MARK: - Raw textview delegate
extension KVBodyContentCell: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        RequestVC.shared?.clearEditing()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let txt = textView.text ?? ""
        Log.debug("text changed: \(txt)")
        guard let body = AppState.editRequest!.body else { return }
        let selected = body.selected
        switch selected {
        case 0:
            body.json = txt
        case 1:
            body.xml = txt
        case 2:
            body.raw = txt
        default:
            break
        }
        AppState.editRequest!.body = body
        if let vc = RequestVC.shared {
            self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
        }
        self.delegate?.refreshCell(indexPath: IndexPath(row: self.tag, section: 0), cell: self)
    }
}

// MARK: - Body field table view

class FileCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

protocol KVBodyFieldTableViewCellDelegate: class {
    func updateState(_ data: ERequestData, row: Int)
}

class KVBodyFieldTableViewCell: UITableViewCell, UITextFieldDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var keyTextField: EATextField!
    @IBOutlet weak var valueTextField: EATextField!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var fieldTypeView: UIView!
    @IBOutlet weak var fieldTypeBtn: UIButton!
    @IBOutlet weak var imageFileView: UIImageView!
    @IBOutlet weak var fileCollectionView: UICollectionView!
    weak var delegate: KVBodyFieldTableViewCellDelegate?
    var isValueTextFieldActive = false
    var selectedType: RequestBodyType = .form
    var isKeyTextFieldActive = false
    private let nc = NotificationCenter.default
    var selectedFieldFormat: RequestBodyFormFieldFormatType = .text
    private let app = App.shared
    private let localdb = CoreDataService.shared
    private let utils = Utils.shared
    var reqDataId = ""  // Will be empty if there are no fields added

    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
        self.renderTheme()
        self.initEvents()
        self.fileCollectionView.reloadData()
    }
    
    func bootstrap() {
        self.keyTextField.delegate = self
        self.valueTextField.delegate = self
        self.keyTextField.isColor = false
        self.valueTextField.isColor = false
        self.imageFileView.isHidden = true
        self.fileCollectionView.delegate = self
        self.fileCollectionView.dataSource = self
    }
    
    func renderTheme() {
        //self.fieldTypeView.backgroundColor = App.Color.requestMethodBg
    }
    
    func initEvents() {
        let btnTap = UITapGestureRecognizer(target: self, action: #selector(self.fieldTypeViewDidTap(_:)))
        btnTap.cancelsTouchesInView = false
        self.fieldTypeView.addGestureRecognizer(btnTap)
        let cvTap = UITapGestureRecognizer(target: self, action: #selector(self.presentDocPicker))
        cvTap.cancelsTouchesInView = false
        self.imageFileView.addGestureRecognizer(cvTap)
        self.initCollectionViewEvents()
    }
    
    func initCollectionViewEvents() {
        let cvTap = UITapGestureRecognizer(target: self, action: #selector(self.presentDocPicker))
        cvTap.cancelsTouchesInView = false
        self.fileCollectionView.removeGestureRecognizer(cvTap)
        self.fileCollectionView.addGestureRecognizer(cvTap)
    }
    
    @objc func fieldTypeViewDidTap(_ recog: UITapGestureRecognizer) {
        Log.debug("field type view did tap")
        RequestVC.shared?.endEditing()
        guard let data = AppState.editRequest, let ctx = data.managedObjectContext else { return }
        RequestVC.addRequestBodyToState()
        var reqData: ERequestData?
        if self.reqDataId.isEmpty {
            let type: RequestDataType = self.selectedType == .form ? .form : .multipart
            if let req = self.localdb.createRequestData(id: self.utils.genRandomString(), index: 0, type: type, fieldFormat: self.selectedFieldFormat,
                                                        ctx: ctx) {
                data.body!.addToForm(req)
                self.reqDataId = req.id ?? ""
                reqData = req
                if let vc = RequestVC.shared {
                    self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { [weak self] status in vc.updateDoneButton(status) })
                }
            }
        } else {
            reqData = self.localdb.getRequestData(id: self.reqDataId, ctx: ctx)
        }
        self.nc.post(name: NotificationKey.optionScreenShouldPresent, object: self,
                     userInfo: [Const.optionTypeKey: OptionPickerType.requestBodyFormField.rawValue,
                                Const.modelIndexKey: self.tag,
                                Const.optionSelectedIndexKey: self.selectedFieldFormat.rawValue,
                                Const.optionDataKey: RequestBodyFormFieldFormatType.allCases,
                                Const.optionModelKey: reqData as Any])
    }
    
    @objc func presentDocPicker() {
        DocumentPickerState.modelIndex = self.tag
        if let data = AppState.editRequest, let ctx = data.managedObjectContext, let reqId = data.id,
            let elem = self.localdb.getRequestData(at: self.tag, reqId: reqId, type: .form, ctx: ctx) {
            DocumentPickerState.reqDataId = elem.id ?? ""
            if let image = elem.image {
                DocumentPickerState.isCameraMode = image.isCameraMode
                self.nc.post(Notification(name: NotificationKey.imagePickerShouldPresent))
                return
            }
            if let files = elem.files, files.count > 0 {
                self.nc.post(Notification(name: NotificationKey.documentPickerShouldPresent))
                return
            }
        }
        self.nc.post(Notification(name: NotificationKey.documentPickerMenuShouldPresent))
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        Log.debug("text field did begin editing")
        RequestVC.shared?.clearEditing()
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if self.selectedFieldFormat == .file && textField == self.valueTextField {
            self.presentDocPicker()
            return false
        }
        return true
    }
    
    // MARK: - Delegate text field
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        Log.debug("textfield did end editing")
        if let data = AppState.editRequest, let ctx = data.managedObjectContext, let req = self.localdb.getRequestData(id: self.reqDataId, ctx: ctx) {
            if textField == self.keyTextField {
                req.key = textField.text
            } else if textField == self.valueTextField {
                req.value = textField.text
            }
            self.delegate?.updateState(req, row: self.tag)
        }
    }
    
    // MARK: - Delegate collection view
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.selectedFieldFormat == .file {
            if let data = AppState.editRequest, let ctx = data.managedObjectContext {
                return self.localdb.getFilesCount(self.reqDataId, type: selectedType == .form ? .form : .multipart, ctx: ctx)
            }
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        Log.debug("file collection view cell")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fileCell", for: indexPath) as! FileCollectionViewCell
        var name = ""
        if let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext,
            let form = self.localdb.getRequestData(at: self.tag, reqId: reqId, type: self.selectedType == .form ? .form : .multipart, ctx: ctx),
            let formId = form.id, let file = self.localdb.getFile(at: indexPath.row, reqDataId: formId, ctx: ctx) {
            name = file.name ?? ""
        }
        cell.nameLabel.text = name
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 50
        if let cell = collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell {
            width = cell.nameLabel.textWidth()
        } else {
            var name = ""
            if let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext,
                let form = self.localdb.getRequestData(at: self.tag, reqId: reqId, type: self.selectedType == .form ? .form : .multipart, ctx: ctx),
                let formId = form.id, let file = self.localdb.getFile(at: indexPath.row, reqDataId: formId, ctx: ctx) {
                name = file.name ?? ""
                let lbl = UILabel(frame: CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: 19.5))
                lbl.text = name
                lbl.layoutIfNeeded()
                width = lbl.textWidth()
            }
        }
        Log.debug("width: \(width)")
        return CGSize(width: width, height: 23.5)
    }
}

class KVBodyFieldTableView: UITableView, UITableViewDelegate, UITableViewDataSource, KVBodyFieldTableViewCellDelegate {
    private let cellId = "kvBodyTableViewCell"
    var isCellRegistered = false
    private let nc = NotificationCenter.default
    var selectedType: RequestBodyType = .form
    private let app = App.shared
    private let localdb = CoreDataService.shared
    private let utils = Utils.shared
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        Log.debug("kvbodyfieldtableview init")
        self.bootstrap()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Log.debug("kvbodyfieldtableview init coder")
        self.bootstrap()
        self.initEvents()
    }
    
    func bootstrap() {
        self.delegate = self
        self.dataSource = self
        self.estimatedRowHeight = 44
        self.rowHeight = UITableView.automaticDimension
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.requestBodyFieldDidChange(_:)), name: NotificationKey.requestBodyFormFieldTypeDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.imageAttachmentDidReceive(_:)), name: NotificationKey.documentPickerImageIsAvailable, object: nil)
        self.nc.addObserver(self, selector: #selector(self.documentAttachmentDidReceive(_:)), name: NotificationKey.documentPickerFileIsAvailable, object: nil)
    }
    
    @objc func requestBodyFieldDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let idx = info[Const.optionSelectedIndexKey] as? Int,
            let reqData = info[Const.optionModelKey] as? ERequestData {
            if let vc = RequestVC.shared {
                self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
            }
            DispatchQueue.main.async {
                reqData.fieldFormat = idx.toInt32()
                self.reloadData()
            }
        }
    }
        
    @objc func imageAttachmentDidReceive(_ notif: Notification) {
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            if let data = AppState.editRequest, let ctx = data.managedObjectContext,
                let form = self.localdb.getRequestData(id: DocumentPickerState.reqDataId, ctx: ctx) {
                form.type = RequestBodyFormFieldFormatType.file.rawValue.toInt32()
                if let image = DocumentPickerState.image {
                    if let imageData = DocumentPickerState.imageType == ImageType.png.rawValue ? image.pngData() : image.jpegData(compressionQuality: 1.0) {
                        let eimage = self.localdb.createImage(data: imageData, index: 0, type: DocumentPickerState.imageType, ctx: ctx)
                        eimage?.requestData = form
                        eimage?.isCameraMode = DocumentPickerState.isCameraMode
                        if let vc = RequestVC.shared {
                            self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                        }
                    }
                }
                self.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                DocumentPickerState.clear()
            }
        }
    }
    
    @objc func documentAttachmentDidReceive(_ notif: Notification) {
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            if let data = AppState.editRequest, let ctx = data.managedObjectContext,
                let form = self.localdb.getRequestData(id: DocumentPickerState.reqDataId, ctx: ctx) {
                form.type = RequestBodyFormFieldFormatType.file.rawValue.toInt32()
                DocumentPickerState.docs.enumerated().forEach { args in
                    let (offset, element) = args
                    self.app.getDataForURL(element) { [weak self] result in  // if user exits before loading, it's the user action. So we don't retain self.
                        if self == nil { return}
                        switch result {
                        case .success(let x):
                            let name = self!.app.getFileName(element)
                            if let file = self!.localdb.createFile(data: x, index: offset, name: name, path: element,
                                                                   type: self!.selectedType == .form ? .form : .multipart, checkExists: true, ctx: ctx) {
                                file.requestData = form
                                if let vc = RequestVC.shared {
                                    self?.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                                }
                                DispatchQueue.main.async {
                                    self?.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                                }
                            }
                        case .failure(let error):
                            Log.debug("Error: \(error)")  // TODO: display alert
                        }
                        if self != nil { DocumentPickerState.clear() }
                    }
                }
            }
        }
    }
    
    func addFields() {
        if let data = AppState.editRequest, let body = data.body {
            if body.selected == RequestBodyType.form.rawValue {
                let count = body.form?.allObjects.count ?? 0
                let data = self.localdb.createRequestData(id: self.utils.genRandomString(), index: count, type: .form, fieldFormat: .text)
                if let x = data {
                    body.addToForm(x)
                    if let vc = RequestVC.shared {
                        self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                    }
                }
            } else if body.selected == RequestBodyType.multipart.rawValue {
                let count = body.multipart?.allObjects.count ?? 0
                let data = self.localdb.createRequestData(id: self.utils.genRandomString(), index: count, type: .multipart, fieldFormat: .text)
                if let x = data {
                    body.addToMultipart(x)
                    if let vc = RequestVC.shared {
                        self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                    }
                }
            }
        }
        self.reloadData()
        RequestVC.shared?.bodyKVTableViewManager.reloadData()
        RequestVC.shared?.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if self.selectedType == .form || self.selectedType == .multipart {
            return 2
        }
        return 1
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext else { return 0 }
        if section == 1 {  // title
            return 1
        }
        var num = 0
        var isInc = false
        if self.selectedType == .form {
            isInc = true
            num = self.localdb.getRequestDataCount(reqId: reqId, type: .form, ctx: ctx)
        }
        if self.selectedType == .multipart {
            isInc = true
            num = self.localdb.getRequestDataCount(reqId: reqId, type: .multipart, ctx: ctx)
        }
        return num == 0 && isInc ? 1 : num
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {  // title
            let cell = tableView.dequeueReusableCell(withIdentifier: "kvBodyFieldTitleCell", for: indexPath) as! KVHeaderCell
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellId, for: indexPath) as! KVBodyFieldTableViewCell
        let row = indexPath.row
        cell.tag = row
        cell.delegate = self
        cell.keyTextField.text = ""
        cell.valueTextField.text = ""
        cell.imageFileView.image = nil
        self.hideImageAttachment(cell: cell)
        self.hideFileAttachment(cell: cell)

        var elem: ERequestData?
        var reqBodyData: ERequestBodyData?
        if let data = AppState.editRequest, let ctx = data.managedObjectContext, let reqId = data.id, let body = data.body, let bodyId = body.id {
            if self.selectedType == .form {
                elem = self.localdb.getRequestData(at: row, reqId: reqId, type: .form, ctx: ctx)
                reqBodyData = elem?.form
            } else if self.selectedType == .multipart {
                // TODO:
//                elem = self.localdb.getFormRequestData(at: row, bodyDataId: bodyId, type: .multipart, ctx: ctx)
//                reqBodyData = elem?.multipart
            }
        }
        if let x = elem, let body = reqBodyData {
            x.index = row.toInt64()  // update the index
            cell.reqDataId = x.id ?? ""
            cell.keyTextField.text = x.key
            cell.valueTextField.text = x.value
            cell.selectedType = RequestBodyType(rawValue: body.selected.toInt()) ?? RequestBodyType.json
            cell.selectedFieldFormat = RequestBodyFormFieldFormatType(rawValue: x.fieldFormat.toInt()) ?? RequestBodyFormFieldFormatType.text
            if cell.selectedFieldFormat == .text {
                cell.fieldTypeBtn.setImage(UIImage(named: "text"), for: .normal)
                self.hideImageAttachment(cell: cell)
                self.hideFileAttachment(cell: cell)
            } else if cell.selectedFieldFormat == .file {
                cell.fieldTypeBtn.setImage(UIImage(named: "file"), for: .normal)
                if let image = x.image, let imgData = image.image {
                    cell.imageFileView.image = UIImage(data: imgData)
                    self.displayImageAttachment(cell: cell)
                } else {
                    self.hideImageAttachment(cell: cell)
                    if let xs = x.files, xs.count > 0 {
                        cell.initCollectionViewEvents()
                        cell.fileCollectionView.layoutIfNeeded()
                        cell.fileCollectionView.reloadData()
                        self.displayFileAttachment(cell: cell)
                    } else {
                        self.hideFileAttachment(cell: cell)
                    }
                }
            }
        }
        self.updateCellPlaceholder(cell)
        return cell
    }
    
    func updateCellPlaceholder(_ cell: KVBodyFieldTableViewCell) {
        if cell.selectedFieldFormat == .file {
            cell.valueTextField.placeholder = "select files"
            cell.valueTextField.text = ""
        } else {
            cell.valueTextField.placeholder = "form value"
        }
    }
    
    func displayImageAttachment(cell: KVBodyFieldTableViewCell) {
        cell.imageFileView.isHidden = false
        cell.fileCollectionView.isHidden = true
        cell.valueTextField.isHidden = true
        self.updateCellPlaceholder(cell)
    }
    
    func hideImageAttachment(cell: KVBodyFieldTableViewCell) {
        cell.imageFileView.image = nil
        cell.imageFileView.isHidden = true
        cell.valueTextField.isHidden = false
        self.updateCellPlaceholder(cell)
    }
    
    func displayFileAttachment(cell: KVBodyFieldTableViewCell) {
        cell.fileCollectionView.isHidden = false
        cell.imageFileView.isHidden = true
        cell.valueTextField.isHidden = true
        self.updateCellPlaceholder(cell)
    }
    
    func hideFileAttachment(cell: KVBodyFieldTableViewCell) {
        cell.fileCollectionView.isHidden = true
        cell.valueTextField.isHidden = false
        self.updateCellPlaceholder(cell)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 { return 44 }
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (self.selectedType == .form || self.selectedType == .multipart) && indexPath.section == 1 {  // title
            self.addFields()
        }
    }
    
    // Swipe to delete
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            guard let data = AppState.editRequest, let ctx = data.managedObjectContext else { completion(false); return }
            var shouldReload = false
            if let cell = tableView.cellForRow(at: indexPath) as? KVBodyFieldTableViewCell  {
                if !cell.reqDataId.isEmpty {
                    self.localdb.deleteRequestData(id: cell.reqDataId, ctx: ctx)
                    shouldReload = true
                }
            }
            if shouldReload {
                self.reloadAllTableViews()
            }
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            if let body = AppState.editRequest!.body {
                if self.selectedType == .form {
                    if let form = body.form, form.count <= 1 {
                        return false
                    }
                } else if self.selectedType == .multipart {
                    if let multipart = body.multipart, multipart.count <= 1 {
                        return false
                    }
                }
            }
            return true
        }
        return false
    }
    
    func reloadAllTableViews() {
        self.reloadData()
        RequestVC.shared?.reloadData()
        RequestVC.shared?.bodyKVTableViewManager.reloadData()
    }
    
    // MARK: - Delegate
    
    func updateState(_ data: ERequestData, row: Int) {
        RequestVC.addRequestBodyToState()
        AppState.editRequest!.body!.selected = self.selectedType.rawValue.toInt32()
        if self.selectedType == .form {
            if AppState.editRequest!.body!.form == nil { AppState.editRequest!.body!.form = NSSet() }
            AppState.editRequest!.body!.addToForm(data)
            if let vc = RequestVC.shared {
                self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
            }
        } else if self.selectedType == .multipart {
            if AppState.editRequest!.body!.multipart == nil { AppState.editRequest!.body!.multipart = NSSet() }
            AppState.editRequest!.body!.addToMultipart(data)
            if let vc = RequestVC.shared {
                self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
            }
        }
    }
}

// MARK: - Table view manager

class KVTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: UITableView?
    weak var delegate: KVTableViewDelegate?
    var height: CGFloat = 44
    var editingIndexPath: IndexPath?
    var tableViewType: KVTableViewType = .header
    private let localdb = CoreDataService.shared
    private let utils = Utils.shared
    private let app = App.shared
    
    deinit {
        Log.debug("kvTableViewManager deinit")
    }
    
    override init() {
        super.init()
        Log.debug("kvTableViewManger init")
    }
    
    func destroy() {
        self.delegate = nil
    }
    
    func bootstrap() {
        self.kvTableView?.estimatedRowHeight = 44
        self.kvTableView?.rowHeight = UITableView.automaticDimension
        self.kvTableView?.allowsMultipleSelectionDuringEditing = false
    }
    
    func addRequestDataToModel() {
        guard let data = AppState.editRequest, let ctx = data.managedObjectContext else { return }
        var index = 0
        var x: ERequestData?
        switch self.tableViewType {
        case .header:
            if data.headers == nil { AppState.editRequest!.headers = NSSet() }
            if let last = self.localdb.getLastRequestData(type: .header, ctx: ctx) { index = (last.index + 1).toInt() }
            x = self.localdb.createRequestData(id: self.utils.genRandomString(), index: index, type: .header, fieldFormat: .text, ctx: ctx)
            if let y = x {
                AppState.editRequest!.addToHeaders(y)
                if let vc = RequestVC.shared {
                    self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                }
            }
        case .params:
            if AppState.editRequest!.params == nil { AppState.editRequest!.params = NSSet() }
            if let last = self.localdb.getLastRequestData(type: .param, ctx: ctx) { index = (last.index + 1).toInt() }
            x = self.localdb.createRequestData(id: self.utils.genRandomString(), index: index, type: .param, fieldFormat: .text, ctx: ctx)
            if let y = x {
                AppState.editRequest!.addToParams(y)
                if let vc = RequestVC.shared {
                    self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                }
            }
        case .body:
            if AppState.editRequest!.body == nil { AppState.editRequest?.body = self.localdb.createRequestBodyData(id: self.utils.genRandomString(), index: 0) }
            if AppState.editRequest!.body!.selected == RequestBodyType.form.rawValue {
                if AppState.editRequest!.body!.form == nil { AppState.editRequest!.body!.form = NSSet() }
                if let last = self.localdb.getLastRequestData(type: .form, ctx: ctx) { index = (last.index + 1).toInt() }
                x = self.localdb.createRequestData(id: self.utils.genRandomString(), index: index, type: .form, fieldFormat: .text, ctx: ctx)
                if let y = x {
                    AppState.editRequest!.body!.addToForm(y)
                    if let vc = RequestVC.shared {
                        self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                    }
                }
            } else if AppState.editRequest!.body!.selected == RequestBodyType.multipart.rawValue {
                if AppState.editRequest!.body!.multipart == nil { AppState.editRequest!.body!.multipart = NSSet() }
                if let last = self.localdb.getLastRequestData(type: .multipart, ctx: ctx) { index = (last.index + 1).toInt() }
                x = self.localdb.createRequestData(id: self.utils.genRandomString(), index: index, type: .multipart, fieldFormat: .text, ctx: ctx)
                if let y = x {
                    AppState.editRequest!.body!.addToMultipart(y)
                    if let vc = RequestVC.shared {
                        self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                    }
                }
            }
        }
    }
    
    func removeRequestDataFromModel(_ id: String, type: RequestCellType) {
        guard let data = AppState.editRequest, let ctx = data.managedObjectContext else { return }
        self.localdb.deleteRequestData(dataId: id, req: AppState.editRequest!, type: type, ctx: ctx)
        if let vc = RequestVC.shared {
            self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
        }
    }
    
    func reloadData() {
        self.kvTableView?.reloadData()
    }
    
    /// Returns the raw textview cell height
    func getRowTextViewCellHeight() -> CGFloat {
        if let cell = self.kvTableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? KVBodyContentCell {
            height = cell.frame.size.height
        }
        Log.debug("raw text cell height: \(height)")
        return height
    }
    
    func getHeight() -> CGFloat {
        var height: CGFloat = 44
        switch self.tableViewType {
        case .header:
            if let headers = AppState.editRequest?.headers {
                if headers.allObjects.count == 0 {
                    height = 48
                } else {
                    height = CGFloat(Double(headers.count) * 92.5 + 50)
                }
            }
        case .params:
            if let params = AppState.editRequest?.params {
                if params.count == 0 {
                    height = 48
                } else {
                    height = CGFloat(Double(params.count) * 92.5 + 50)
                }
            }
        case .body:
            if let body = AppState.editRequest?.body {
                if body.selected == RequestBodyType.json.rawValue ||
                   body.selected == RequestBodyType.xml.rawValue ||
                   body.selected == RequestBodyType.raw.rawValue {
                    height = self.getRowTextViewCellHeight()
                } else if body.selected == RequestBodyType.form.rawValue {
                    height = RequestVC.bodyFormCellHeight()
                    Log.debug("form cell height: \(height)")
                } else if body.selected == RequestBodyType.multipart.rawValue {
                    height = RequestVC.bodyFormCellHeight()
                    Log.debug("multipart cell height: \(height)")
                } else if body.selected == RequestBodyType.binary.rawValue {
                    height = 300
                }
            } else {
                height = 44
            }
        }
        Log.debug("kvtableview getHeight: \(height) for type: \(self.tableViewType)")
        return height
    }
    
    func getContentCellId() -> String {
        switch self.tableViewType {
        case .header:
            fallthrough
        case .params:
            return "kvContentCell"
        case .body:
            return "bodyContentCell"
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let state = AppState.editRequest else { return 0 }
        if section == 0 {
            switch self.tableViewType {
            case .header:
                return state.headers?.count ?? 0
            case .params:
                return state.params?.count ?? 0
            case .body:
                if state.body == nil { return 0 }
                return 1
            }
        }
        // section 1 (header)
        if self.tableViewType == .body && AppState.editRequest!.body != nil {
            return 0
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if self.tableViewType == .body {
                let cell = tableView.dequeueReusableCell(withIdentifier: "bodyContentCell", for: indexPath) as! KVBodyContentCell
                let row = indexPath.row
                cell.tag = row
                cell.delegate = self
                self.hideDeleteRowView(cell: cell)
                let selectedIdx: Int = {
                    if let body = AppState.editRequest!.body {
                        return Int(body.selected)
                    }
                    return 0
                }()
                switch selectedIdx {
                case RequestBodyType.json.rawValue:
                    cell.rawTextView.text = AppState.editRequest!.body?.json ?? ""
                    cell.hideFormFields()
                case RequestBodyType.xml.rawValue:
                    cell.rawTextView.text = AppState.editRequest!.body?.xml ?? ""
                    cell.hideFormFields()
                case RequestBodyType.raw.rawValue:
                    cell.rawTextView.text = AppState.editRequest!.body?.raw ?? ""
                    cell.hideFormFields()
                case RequestBodyType.form.rawValue:
                    cell.displayFormFields()
                case RequestBodyType.multipart.rawValue:
                    cell.hideFormFields()
                case RequestBodyType.binary.rawValue:
                    cell.hideFormFields()
                default:
                    break
                }
                if AppState.editRequest!.body != nil {
                    cell.bodyDataId = AppState.editRequest!.body!.id ?? ""
                    cell.updateState(AppState.editRequest!.body!)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "kvContentCell", for: indexPath) as! KVContentCell
                let row = indexPath.row
                cell.tag = row
                cell.delegate = self
                self.hideDeleteRowView(cell: cell)
                cell.keyTextField.text = ""
                cell.valueTextField.text = ""
                cell.reqDataId = ""
                switch self.tableViewType {
                case .header:
                    if let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext {
                        let xs = self.localdb.getHeadersRequestData(reqId, ctx: ctx)
                        if xs.count > row {
                            let x = xs[row]
                            cell.keyTextField.text = x.key
                            cell.valueTextField.text = x.value
                            cell.reqDataId = x.id ?? ""
                            cell.type = .header
                        }
                    }
                case .params:
                    if let data = AppState.editRequest, let reqId = data.id, let ctx = data.managedObjectContext {
                        let xs = self.localdb.getParamsRequestData(reqId, ctx: ctx)
                        if xs.count > row {
                            let x = xs[row]
                            cell.keyTextField.text = x.key
                            cell.valueTextField.text = x.value
                            cell.reqDataId = x.id ?? ""
                            cell.type = .param
                        }
                    }
                default:
                    break
                }
                return cell
            }
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "kvTitleCell", for: indexPath) as! KVHeaderCell
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("kvTableView row did select")
        RequestVC.shared?.clearEditing()
        if let reqVC = RequestVC.shared, reqVC.isEndEditing {
            UI.endEditing()
            return
        }
        if indexPath.section == 1 {  // header
            self.addRequestDataToModel()
            self.disableEditing(indexPath: indexPath)
            self.reloadData()
            self.delegate?.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.tableViewType == .body {
            if let body = AppState.editRequest!.body {
                if indexPath.section == 1 { return 0 }
                if body.selected == RequestBodyType.form.rawValue {
                    return RequestVC.bodyFormCellHeight()
                }
            }
        }
        if indexPath.section == 1 { return 44 }  // Prevents the collapse warning
        return UITableView.automaticDimension
    }
    
    func previewActions(forCellAt indexPath: IndexPath) {
        guard let tv = self.kvTableView else { return }
        tv.reloadData()
        guard let cell: KVContentCellType = tv.cellForRow(at: indexPath) as? KVContentCellType else { return }
        UIView.animate(withDuration: 0.3, animations: {
            cell.getContainerView().transform = CGAffineTransform.identity.translatedBy(x: -64, y: 0)
        }, completion: nil)
    }
    
    func hideDeleteRowView(cell: KVContentCellType) {
        cell.getContainerView().transform = CGAffineTransform.identity
        cell.getDeleteView().isHidden = true
    }
    
    func hideActions(forCellAt indexPath: IndexPath, completion: ((Bool) -> Void)? = nil) {
        Log.debug("hide actions")
        var cell: KVContentCellType!
        if let aCell = self.kvTableView?.cellForRow(at: indexPath) as? KVContentCell {
            cell = aCell
        } else if let aCell = self.kvTableView?.cellForRow(at: indexPath) as? KVBodyContentCell {
            cell = aCell
        }
        if cell == nil {
            if let cb = completion { cb(false) }
            return
        }
        cell.isEditingActive = false
        cell.editingIndexPath = nil
        UIView.animate(withDuration: 0.3, animations: {
            self.hideDeleteRowView(cell: cell)
            self.editingIndexPath = nil
        }, completion: completion)
    }
}

extension KVTableViewManager: KVContentCellDelegate {
    func enableEditing(indexPath: IndexPath) {
        if self.editingIndexPath != nil {
            self.hideActions(forCellAt: self.editingIndexPath!) { _ in
                self.editingIndexPath = indexPath
                self.previewActions(forCellAt: indexPath)
            }
        } else {
            self.editingIndexPath = indexPath
            self.previewActions(forCellAt: indexPath)
        }
    }
    
    func disableEditing(indexPath: IndexPath) {
        self.hideActions(forCellAt: indexPath)
    }
    
    func clearEditing(completion: ((Bool) -> Void)? = nil) {
        if let indexPath = self.editingIndexPath {
            self.hideActions(forCellAt: indexPath, completion: completion)
        } else {
            if let cb = completion { cb(true) }
        }
    }
    
    func deleteRow(_ reqDataId: String, type: RequestCellType) {
        self.removeRequestDataFromModel(reqDataId, type: type)
        self.reloadData()
        self.delegate?.reloadData()
    }
    
    func dataDidChange(key: String, value: String, reqDataId: String, row: Int) {
        if let req = AppState.editRequest, let ctx = req.managedObjectContext {
            if self.tableViewType == .header {
                if let x = self.localdb.getRequestData(id: reqDataId, ctx: ctx) {
                    x.key = key
                    x.value = value
                    Log.debug("header updated: \(x)")
                    if let vc = RequestVC.shared {
                        self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                    }
                }
            } else if self.tableViewType == .params {
                if let x = self.localdb.getRequestData(id: reqDataId, ctx: ctx) {
                    x.key = key
                    x.value = value
                    if let vc = RequestVC.shared {
                        self.app.didRequestChange(AppState.editRequest!, request: vc.entityDict, callback: { status in vc.updateDoneButton(status) })
                    }
                }
            }
        }
    }
    
    /// Refreshes the cell and scroll to the end of the growing text view cell.
    func refreshCell(indexPath: IndexPath, cell: KVContentCellType) {
        Log.debug("refresh cell")
        UIView.setAnimationsEnabled(false)
        self.kvTableView?.beginUpdates()
        if let aCell = cell as? KVBodyContentCell {
            aCell.rawTextView.scrollRangeToVisible(NSMakeRange(aCell.rawTextView.text.count - 1, 0))
        }
        self.kvTableView?.endUpdates()
        UIView.setAnimationsEnabled(true)
        self.kvTableView?.scrollToRow(at: indexPath, at: .bottom, animated: false)
        let bodySpacerIdx = IndexPath(row: RequestVC.CellId.spacerAfterBody.rawValue, section: 0)
        UIView.setAnimationsEnabled(false)
        RequestVC.shared?.tableView.beginUpdates()
        RequestVC.shared?.tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
        if let vc = RequestVC.shared {
            vc.tableView.scrollToRow(at: bodySpacerIdx, at: .bottom, animated: false)
        }
    }
}

