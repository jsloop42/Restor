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
    @IBOutlet weak var goBtn: UIButton!
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
    private let app = App.shared
    var isEndEditing = false
    var isOptionFromNotif = false
    private let docPicker = DocumentPicker.shared
    private let utils = Utils.shared
    private let db = PersistenceService.shared
    private var localdb = CoreDataService.shared
    
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
        AppState.editRequest = nil
        RequestTableViewController.shared = nil
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
    }
        
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        if let req = AppState.editRequest, let methods = req.methods, let data = methods.allObjects[Int(req.selectedMethodIndex)] as? ERequestMethodData {
            self.methodLabel.text = data.name
        }
        self.urlTextField.delegate = self
        self.nameTextField.delegate = self
        self.descTextView.delegate = self
        // Set bottom border
        //self.app.updateTextFieldWithBottomBorder(self.urlTextField)
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
        self.nc.addObserver(self, selector: #selector(self.reloadTableView), name: NotificationKey.requestTableViewReload, object: nil)
        self.nc.addObserver(self, selector: #selector(self.clearEditing), name: NotificationKey.requestViewClearEditing, object: nil)
        let methodTap = UITapGestureRecognizer(target: self, action: #selector(self.methodViewDidTap))
        self.methodView.addGestureRecognizer(methodTap)
        self.nc.addObserver(self, selector: #selector(self.requestMethodDidChange(_:)), name: NotificationKey.requestMethodDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentOptionsScreen(_:)), name: NotificationKey.optionScreenShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentDocumentMenuPicker(_:)), name: NotificationKey.documentPickerMenuShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentDocumentPicker(_:)), name: NotificationKey.documentPickerShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentImagePicker(_:)), name: NotificationKey.imagePickerShouldPresent, object: nil)
    }

    func initState() {
        // using child context
        // TODO:
        //AppState.editRequest = ERequest.create(id: self.utils.genRandomString(), in: self.localdb.childMOC)
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
    
    @objc func methodViewDidTap() {
        Log.debug("method view did tap")
        if let req = AppState.editRequest, let methods = req.methods {
            OptionsPickerState.requestData = methods.allObjects as? [ERequestMethodData] ?? []
            OptionsPickerState.selected = req.selectedMethodIndex.toInt()
        }
        OptionsPickerState.title = "Request Method"
        self.app.presentOptionPicker(.requestMethod, storyboard: self.storyboard, delegate: nil, navVC: self.navigationController)
    }
    
    @objc func requestMethodDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let name = info[Const.requestMethodNameKey] as? String, let idx = info[Const.optionSelectedIndexKey] as? Int {
            DispatchQueue.main.async {
                self.methodLabel.text = name
                AppState.editRequest?.selectedMethodIndex = idx.toInt32()
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }
    }
    
    @objc func presentOptionsScreen(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let opt = info[Const.optionTypeKey] as? Int, let type = OptionPickerType(rawValue: opt) {
            DispatchQueue.main.async {
                self.app.presentOptionPicker(type, storyboard: self.storyboard!, delegate: self, navVC: self.navigationController!)
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
            if let body = AppState.editRequest!.body, body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue {
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        RequestVC.shared?.clearEditing()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == self.urlTextField {
            AppState.editRequest!.url = textField.text ?? ""
        } else if textField == self.nameTextField {
            AppState.editRequest!.name = textField.text ?? ""
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        RequestVC.shared?.clearEditing()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == self.descTextView {
            AppState.editRequest!.desc = textView.text ?? ""
        }
    }
    
    static func addRequestBodyToState() {
        if let req = AppState.editRequest, let moc = req.managedObjectContext {
            if req.body == nil {
                // TODO:
                //req.body = ERequestBodyData.create(id: Utils.shared.genRandomString(), in: moc)
                AppState.editRequest!.body?.request = AppState.editRequest
            }
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
    
    func presentOptionsVC(_ data: [String], selected: Int) {
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.optionsDelegate = self
            RequestVC.addRequestBodyToState()
            AppState.editRequest?.body?.selected = selected.toInt32()
            OptionsPickerState.selected = selected
            OptionsPickerState.data = data
            self.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
}

extension RequestTableViewController: OptionsPickerViewDelegate {
    func reloadOptionsData() {
        if !self.isOptionFromNotif {
            self.bodyKVTableViewManager.reloadData()
            self.tableView.reloadRows(at: [IndexPath(row: CellId.body.rawValue, section: 0)], with: .none)
        }
    }
    
    func optionDidSelect(_ row: Int) {
        if !self.isOptionFromNotif {
            AppState.editRequest!.body!.selected = Int32(row)
        }
    }
}

enum KVTableViewType {
    case header
    case params
    case body
}

protocol KVTableViewDelegate: class {
    func reloadData()
    func presentOptionsVC(_ data: [String], selected: Int)
}

class KVHeaderCell: UITableViewCell {
    @IBOutlet weak var headerTitleBtn: UIButton!
}

protocol KVContentCellDelegate: class {
    func enableEditing(indexPath: IndexPath)
    func disableEditing(indexPath: IndexPath)
    func clearEditing(completion: ((Bool) -> Void)?)
    func deleteRow(indexPath: IndexPath)
    func presentOptionsVC(_ data: [String], selected: Int)
    func dataDidChange(_ data: ERequestData, row: Int)
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
    var data: ERequestData?
    var type: RequestHeaderInfo = .headers
    
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
        self.delegate?.deleteRow(indexPath: IndexPath(row: self.tag, section: 0))
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
        self.data?.key = self.keyTextField.text
        self.data?.value = self.valueTextField.text
        guard let data = self.data else { return }
        self.delegate?.dataDidChange(data, row: self.tag)
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
        self.delegate?.deleteRow(indexPath: IndexPath(row: self.tag, section: 0))
        self.bodyFieldTableView.reloadData()
    }
    
    @IBAction func typeBtnDidTap(_ sender: Any) {
        Log.debug("type name did tap")
        var selected: Int! = 0
        if let body = AppState.editRequest!.body {
            selected = Int(body.selected)
        }
        self.delegate?.presentOptionsVC(self.optionsData, selected: selected)
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
        // TODO:
        //self.bodyFieldTableView.selectedType = ERequestBodyType(rawValue: AppState.editRequest!.body!.selected)!
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
            self.bodyLabelViewWidth.constant = 60
        case 1:  // xml
            self.rawTextView.text = data.xml
            self.bodyLabelViewWidth.constant = 60
        case 2:  // raw
            self.rawTextView.text = data.raw
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
    var selectedFieldType: RequestBodyFormFieldType = .text

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
        OptionsPickerState.modelIndex = self.tag
        OptionsPickerState.selected = self.selectedFieldType.rawValue
        OptionsPickerState.data = RequestBodyFormFieldType.allCases
        self.nc.post(name: NotificationKey.optionScreenShouldPresent, object: self,
                     userInfo: [Const.optionTypeKey: OptionPickerType.requestBodyFormField.rawValue])
    }
    
    @objc func presentDocPicker() {
        DocumentPickerState.modelIndex = self.tag
        if let body = AppState.editRequest?.body, let form = body.form, let data = form.allObjects[self.tag] as? ERequestData {
            if data.image != nil {
                DocumentPickerState.isCameraMode = data.image!.isCameraMode
                self.nc.post(Notification(name: NotificationKey.imagePickerShouldPresent))
                return
            }
            if let files = data.files, files.allObjects.count > 0 {
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
        if self.selectedFieldType == .file && textField == self.valueTextField {
            self.presentDocPicker()
            return false
        }
        return true
    }
    
    // MARK: - Delegate text field
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        Log.debug("textfield did end editing")
        // TODO:
//        if textField == self.keyTextField {
//            self.delegate?.updateState(RequestData(key: textField.text ?? "", value: self.valueTextField.text ?? ""), row: self.tag)
//        } else if textField == self.valueTextField {
//            self.delegate?.updateState(RequestData(key: self.keyTextField.text ?? "", value: textField.text ?? ""), row: self.tag)
//        }
    }
    
    // MARK: - Delegate collection view
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO:
//        if self.selectedFieldType == .file {
//            if let data = AppState.editRequest?.body?.form[self.tag].files {
//                return data.count
//            }
//        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        Log.debug("file collection view cell")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fileCell", for: indexPath) as! FileCollectionViewCell
        var name = ""
        // TODO:
//        if let data = AppState.editRequest?.body?.form[self.tag] {
//            name = data.files[indexPath.row].lastPathComponent
//        }
        cell.nameLabel.text = name
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 50
        if let cell = collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell {
            width = cell.nameLabel.textWidth()
        } else {
            // TODO:
//            if let name = AppState.editRequest?.body?.form[self.tag].files[indexPath.row].lastPathComponent {
//                let lbl = UILabel(frame: CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: 19.5))
//                lbl.text = name
//                lbl.layoutIfNeeded()
//                width = lbl.textWidth()
//            }
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
        self.nc.addObserver(self, selector: #selector(self.bodyFormFieldTypeDidChange(_:)), name: NotificationKey.bodyFormFieldTypeDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.imageAttachmentDidReceive(_:)), name: NotificationKey.documentPickerImageIsAvailable, object: nil)
        self.nc.addObserver(self, selector: #selector(self.documentAttachmentDidReceive(_:)), name: NotificationKey.documentPickerFileIsAvailable, object: nil)
    }
    
    @objc func bodyFormFieldTypeDidChange(_ notif: Notification) {
        Log.debug("body form field type did change notif received")
        // TODO:
//        if selectedType == .form {
//            let data = AppState.editRequest!.body!.form[OptionsPickerState.modelIndex]
//            if let t = RequestBodyFormFieldType(rawValue: OptionsPickerState.selected) {
//                data.setFieldType(t)
//                AppState.editRequest!.body!.form[OptionsPickerState.modelIndex] = data
//            }
//        }
        self.reloadData()
    }
    
    @objc func imageAttachmentDidReceive(_ notif: Notification) {
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            if let req = AppState.editRequest, let moc = req.managedObjectContext, let body = req.body, let form = body.form, form.count > row, let data = form.allObjects[row] as? ERequestData {
                data.type = Int32(RequestBodyFormFieldType.file.rawValue)
                // TODO: create image
//                form[row].image = DocumentPickerState.image
//                form[row].isCameraMode = DocumentPickerState.isCameraMode
                self.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }
    }
    
    @objc func documentAttachmentDidReceive(_ notif: Notification) {
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            // TODO:
//            if AppState.editRequest!.body!.form.count > row {
//                AppState.editRequest!.body!.form[row].type = .file
//                AppState.editRequest!.body!.form[row].files = DocumentPickerState.docs
//                self.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
//            }
        }
    }
    
    func addFields() {
        // TODO:
//        let data = RequestData(key: "", value: "")
//        if AppState.editRequest!.body != nil {
//            if AppState.editRequest!.body!.selected == RequestBodyType.form.rawValue {
//                AppState.editRequest!.body!.form.append(data)
//            } else if AppState.editRequest!.body!.selected == RequestBodyType.multipart.rawValue {
//                AppState.editRequest!.body!.multipart.append(data)
//            }
//        }
//        self.reloadData()
//        RequestVC.shared?.bodyKVTableViewManager.reloadData()
//        RequestVC.shared?.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if self.selectedType == .form || self.selectedType == .multipart {
            return 2
        }
        return 1
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let body = AppState.editRequest!.body else { return 0 }
        if section == 1 {  // title
            return 1
        }
        // TODO:
//        let data: [ERequestData] = {
//            if self.selectedType == .form {
//                if body.form.count == 0 {
//                    AppState.editRequest!.body!.form.append(RequestData(key: "", value: ""))
//                    return AppState.editRequest!.body!.form
//                }
//                return body.form
//            }
//            if body.multipart.count == 0 {
//                AppState.editRequest!.body!.multipart.append(RequestData(key: "", value: ""))
//                return AppState.editRequest!.body!.multipart
//            }
//            return body.multipart
//        }()
//        return data.count
        return 0
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
        // TODO:
//        var data: [RequestDataProtocol] = []
//        if let body = AppState.editRequest!.body {
//            if self.selectedType == .form {
//                data = body.form
//            } else if self.selectedType == .multipart {
//                data = body.multipart
//            }
//        }
//        cell.keyTextField.text = ""
//        cell.valueTextField.text = ""
//        cell.imageFileView.image = nil
//        self.hideImageAttachment(cell: cell)
//        self.hideFileAttachment(cell: cell)
//        if data.count > row {
//            let x = data[row]
//            cell.keyTextField.text = x.getKey()
//            cell.valueTextField.text = x.getValue()
//            cell.selectedFieldType = x.getFieldType()
//            if x.getFieldType() == .text {
//                cell.fieldTypeBtn.setImage(UIImage(named: "text"), for: .normal)
//                self.hideImageAttachment(cell: cell)
//                self.hideFileAttachment(cell: cell)
//            } else if x.getFieldType() == .file {
//                cell.fieldTypeBtn.setImage(UIImage(named: "file"), for: .normal)
//                if let image = x.getImage() {
//                    cell.imageFileView.image = image
//                    self.displayImageAttachment(cell: cell)
//                } else {
//                    self.hideImageAttachment(cell: cell)
//                    let xs = x.getFiles()
//                    if xs.count > 0 {
//                        cell.initCollectionViewEvents()
//                        cell.fileCollectionView.layoutIfNeeded()
//                        cell.fileCollectionView.reloadData()
//                        self.displayFileAttachment(cell: cell)
//                    } else {
//                        self.hideFileAttachment(cell: cell)
//                    }
//                }
//            }
//        }
        self.updateCellPlaceholder(cell)
        return cell
    }
    
    func updateCellPlaceholder(_ cell: KVBodyFieldTableViewCell) {
        if cell.selectedFieldType == .file {
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
            guard let body = AppState.editRequest!.body else { completion(false); return }
            var shouldReload = false
            if self.selectedType == .form {
                if let form = body.form, form.allObjects.count > indexPath.row {
                    // TODO:
                    // AppState.editRequest!.body!.form.remove(at: indexPath.row)
                    shouldReload = true
                }
            } else if self.selectedType == .multipart {
                if let multipart = body.multipart, multipart.allObjects.count > indexPath.row {
                    // TODO:
                    // AppState.editRequest!.body!.multipart.remove(at: indexPath.row)
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
                    if let form = body.form, form.allObjects.count <= 1 {
                        return false
                    }
                } else if self.selectedType == .multipart {
                    if let multipart = body.multipart, multipart.allObjects.count <= 1 {
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
        guard let body = AppState.editRequest!.body else { return }
        // TODO:
//        body.selected = self.selectedType.rawValue
//        if self.selectedType == .form {
//            if body.form.count == 0 {
//                body.form.append(data)
//            } else if body.form.count > row {
//                body.form[row].key = data.key
//                body.form[row].value = data.value
//            }
//        } else if self.selectedType == .multipart {
//            if body.multipart.count == 0 {
//                body.multipart.append(data)
//            } else if body.multipart.count > row {
//                body.form[row].key = data.key
//                body.form[row].value = data.value
//            }
//        }
        AppState.editRequest!.body = body
    }
}

// MARK: - Table view manager

class KVTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: UITableView?
    weak var delegate: KVTableViewDelegate?
    var height: CGFloat = 44
    var editingIndexPath: IndexPath?
    var tableViewType: KVTableViewType = .header
    
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
    
    func addRequestDataToModel(_ data: ERequestData) {
        // TODO:
//        switch self.tableViewType {
//        case .header:
//            if let aData = data {
//                AppState.editRequest!.headers.append(aData)
//            }
//        case .params:
//            if let aData = data as? ERequestData {
//                AppState.editRequest!.params.append(aData)
//            }
//        case .body:
//            if AppState.editRequest!.body == nil {
//                RequestVC.addRequestBodyToState()
//            }
//            if let aData = data as? ERequestData {
//                if AppState.editRequest!.body!.selected == RequestBodyType.form.rawValue {
//                    AppState.editRequest!.body!.form.append(aData)
//                } else if AppState.editRequest!.body!.selected == RequestBodyType.multipart.rawValue {
//                    AppState.editRequest!.body!.multipart.append(aData)
//                }
//            }
//        }
    }
    
    func removeRequestDataFromModel(_ index: Int) {
        // TODO:
//        switch self.tableViewType {
//        case .header:
//            if AppState.editRequest!.headers.count > index {
//                AppState.editRequest!.headers.remove(at: index)
//            }
//        case .params:
//            if AppState.editRequest!.params.count > index {
//                AppState.editRequest!.params.remove(at: index)
//            }
//        case .body:
//            AppState.editRequest!.body = nil
//            OptionsPickerState.selected = 0
//        }
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
            if let headers = AppState.editRequest!.headers {
                if headers.allObjects.count == 0 {
                    height = 48
                } else {
                    height = CGFloat(Double(headers.count) * 92.5 + 50)
                }
            }
        case .params:
            if let params = AppState.editRequest!.params {
                if params.count == 0 {
                    height = 48
                } else {
                    height = CGFloat(Double(params.count) * 92.5 + 50)
                }
            }
        case .body:
            if let body = AppState.editRequest!.body {
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
                return state.headers?.allObjects.count ?? 0
            case .params:
                return state.params?.allObjects.count ?? 0
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
                    cell.updateState(AppState.editRequest!.body!)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "kvContentCell", for: indexPath) as! KVContentCell
                let row = indexPath.row
                cell.tag = row
                cell.delegate = self
                self.hideDeleteRowView(cell: cell)
                switch self.tableViewType {
                case .header:
                    if let headers = AppState.editRequest?.headers, headers.allObjects.count > row, var data = headers.allObjects[row] as? ERequestData {
                        cell.keyTextField.text = data.key
                        cell.valueTextField.text = data.value
                    }
                case .params:
                    if let params = AppState.editRequest?.params, params.allObjects.count > row, let data = params.allObjects[row] as? ERequestData {
                        cell.keyTextField.text = data.key
                        cell.valueTextField.text = data.value
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
            // TODO:
            //self.addRequestDataToModel(RequestData())
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
    
    func deleteRow(indexPath: IndexPath) {
        self.removeRequestDataFromModel(indexPath.row)
        self.reloadData()
        self.delegate?.reloadData()
    }
    
    func presentOptionsVC(_ data: [String], selected: Int) {
        self.delegate?.presentOptionsVC(data, selected: selected)
    }
    
    func dataDidChange(_ data: ERequestData, row: Int) {
        if let req = AppState.editRequest {
            if self.tableViewType == .header {
                req.addToHeaders(data)
            } else if self.tableViewType == .params {
                req.addToParams(data)
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

