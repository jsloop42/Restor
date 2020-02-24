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
    var state: Request = Request()
    var isEndEditing = false
    var isOptionFromNotif = false
    private let docPicker = DocumentPicker.shared
    
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
        self.state = Request()
        RequestTableViewController.shared = nil
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !self.isActive {
            self.headerKVTableViewManager.destroy()
            self.paramsKVTableViewManager.destroy()
            self.bodyKVTableViewManager.destroy()
            RequestVC.shared = nil
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
        self.methodLabel.text = self.state.methods[self.state.selectedMethodIndex].name
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
        self.nc.addObserver(self, selector: #selector(self.presentDocumentPicker(_:)), name: NotificationKey.documentPickerShouldPresent, object: nil)
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
        OptionsPickerState.requestData = self.state.methods
        OptionsPickerState.selected = self.state.selectedMethodIndex
        OptionsPickerState.title = "Request Method"
        self.app.presentOptionPicker(.requestMethod, storyboard: self.storyboard, delegate: nil, navVC: self.navigationController)
    }
    
    @objc func requestMethodDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let name = info[Const.requestMethodNameKey] as? String, let idx = info[Const.optionSelectedIndexKey] as? Int {
            DispatchQueue.main.async {
                self.methodLabel.text = name
                RequestVC.shared?.state.selectedMethodIndex = idx
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
    
    @objc func presentDocumentPicker(_ notif: Notification) {
        let docPicker = DocumentPicker()
        docPicker.presentDocumentMenu(navVC: self.navigationController!, vc: self)
        //docPicker.presentDocumentPicker(vc: self)
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
            if let body = RequestVC.shared?.state.body, body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue {
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
            RequestVC.shared?.state.url = textField.text ?? ""
        } else if textField == self.nameTextField {
            RequestVC.shared?.state.name = textField.text ?? ""
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        RequestVC.shared?.clearEditing()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == self.descTextView {
            RequestVC.shared?.state.desc = textView.text ?? ""
        }
    }
    
    static func addRequestBodyToState() {
        if RequestVC.shared != nil, RequestVC.shared!.state.body == nil {
            RequestVC.shared!.state.body = RequestBodyData()
        }
    }
    
    static func bodyFormCellHeight() -> CGFloat {
        if let body = RequestVC.shared?.state.body {
            let count: Double = body.form.count == 0 ? 1 : Double(body.form.count)
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

extension RequestTableViewController: KVTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
    
    func presentOptionsVC(_ data: [String], selected: Int) {
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.optionsDelegate = self
            RequestVC.addRequestBodyToState()
            RequestVC.shared?.state.body!.selected = selected
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
            RequestVC.shared?.state.body!.selected = row
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
    func dataDidChange(_ data: RequestData, row: Int)
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
        let data = RequestData(key: self.keyTextField.text ?? "", value: self.valueTextField.text ?? "")
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
            self.updateState(RequestVC.shared!.state.body!)
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
        if let body = RequestVC.shared?.state.body {
            selected = body.selected
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
        if RequestVC.shared != nil {
            self.bodyFieldTableView.selectedType = RequestBodyType(rawValue: RequestVC.shared!.state.body!.selected)!
        }
        self.bodyFieldTableView.reloadData()
    }
    
    func hideFormFields() {
        self.bodyFieldTableView.isHidden = true
        self.rawTextViewContainer.isHidden = false
    }
    
    func updateState(_ data: RequestBodyData) {
        let idx: Int = data.selected
        RequestVC.shared?.state.body!.selected = idx
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
        guard let body = RequestVC.shared?.state.body else { return }
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
        RequestVC.shared?.state.body = body
        self.delegate?.refreshCell(indexPath: IndexPath(row: self.tag, section: 0), cell: self)
    }
}

// MARK: - Body field table view

protocol KVBodyFieldTableViewCellDelegate: class {
    func updateState(_ data: RequestData, row: Int)
}

class KVBodyFieldTableViewCell: UITableViewCell, UITextFieldDelegate {
    @IBOutlet weak var keyTextField: EATextField!
    @IBOutlet weak var valueTextField: EATextField!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var fieldTypeView: UIView!
    @IBOutlet weak var fieldTypeBtn: UIButton!
    @IBOutlet weak var imageFileView: UIImageView!
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
    }
    
    func bootstrap() {
        self.keyTextField.delegate = self
        self.valueTextField.delegate = self
        self.keyTextField.isColor = false
        self.valueTextField.isColor = false
        self.imageFileView.isHidden = true
    }
    
    func renderTheme() {
        //self.fieldTypeView.backgroundColor = App.Color.requestMethodBg
    }
    
    func initEvents() {
        let btnTap = UITapGestureRecognizer(target: self, action: #selector(self.fieldTypeViewDidTap(_:)))
        btnTap.cancelsTouchesInView = false
        self.fieldTypeView.addGestureRecognizer(btnTap)
    }
    
    @objc func fieldTypeViewDidTap(_ recog: UITapGestureRecognizer) {
        Log.debug("field type view did tap")
        OptionsPickerState.modelIndex = self.tag
        OptionsPickerState.selected = self.selectedFieldType.rawValue
        OptionsPickerState.data = RequestBodyFormFieldType.allCases
        self.nc.post(name: NotificationKey.optionScreenShouldPresent, object: self,
                     userInfo: [Const.optionTypeKey: OptionPickerType.requestBodyFormField.rawValue])
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        Log.debug("text field did begin editing")
        RequestVC.shared?.clearEditing()
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if self.selectedFieldType == .file && textField == self.valueTextField {
            DocumentPickerState.modelIndex = self.tag
            self.nc.post(Notification(name: NotificationKey.documentPickerShouldPresent))
            return false
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        Log.debug("textfield did end editing")
        if textField == self.keyTextField {
            self.delegate?.updateState(RequestData(key: textField.text ?? "", value: self.valueTextField.text ?? ""), row: self.tag)
        } else if textField == self.valueTextField {
            self.delegate?.updateState(RequestData(key: self.keyTextField.text ?? "", value: textField.text ?? ""), row: self.tag)
        }
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
    }
    
    @objc func bodyFormFieldTypeDidChange(_ notif: Notification) {
        Log.debug("body form field type did change notif received")
        if selectedType == .form {
            if let data = RequestVC.shared?.state.body!.form[OptionsPickerState.modelIndex], let t = RequestBodyFormFieldType(rawValue: OptionsPickerState.selected) {
                data.setFieldType(t)
                RequestVC.shared?.state.body!.form[OptionsPickerState.modelIndex] = data
            }
        }
        self.reloadData()
    }
    
    @objc func imageAttachmentDidReceive(_ notif: Notification) {
        if RequestVC.shared == nil { return }
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            if RequestVC.shared!.state.body!.form.count > row {
                RequestVC.shared!.state.body!.form[row].image = DocumentPickerState.image
                self.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }
    }
    
    func addFields() {
        let data = RequestData(key: "", value: "")
        if RequestVC.shared?.state.body != nil {
            if RequestVC.shared?.state.body!.selected == RequestBodyType.form.rawValue {
                RequestVC.shared?.state.body!.form.append(data)
            } else if RequestVC.shared?.state.body!.selected == RequestBodyType.multipart.rawValue {
                RequestVC.shared?.state.body!.multipart.append(data)
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
        guard let state = RequestVC.shared?.state, let body = state.body else { return 0 }
        if section == 1 {  // title
            return 1
        }
        let data: [RequestData] = {
            if self.selectedType == .form {
                if body.form.count == 0 {
                    RequestVC.shared!.state.body!.form.append(RequestData(key: "", value: ""))
                    return RequestVC.shared!.state.body!.form
                }
                return body.form
            }
            if body.multipart.count == 0 {
                RequestVC.shared!.state.body!.multipart.append(RequestData(key: "", value: ""))
                return RequestVC.shared!.state.body!.multipart
            }
            return body.multipart
        }()
        return data.count
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
        var data: [RequestDataProtocol] = []
        if let body = RequestVC.shared?.state.body {
            if self.selectedType == .form {
                data = body.form
            } else if self.selectedType == .multipart {
                data = body.multipart
            }
        }
        cell.keyTextField.text = ""
        cell.valueTextField.text = ""
        if data.count > row {
            let x = data[row]
            cell.keyTextField.text = x.getKey()
            cell.valueTextField.text = x.getValue()
            cell.selectedFieldType = x.getFieldType()
            if x.getFieldType() == .text {
                cell.fieldTypeBtn.setImage(UIImage(named: "text"), for: .normal)
                cell.valueTextField.placeholder = "form value"
            } else if x.getFieldType() == .file {
                cell.fieldTypeBtn.setImage(UIImage(named: "file"), for: .normal)
                if let image = x.getImage() {
                    cell.imageFileView.image = image
                    cell.imageFileView.isHidden = false
                    cell.valueTextField.isHidden = true
                } else {
                    cell.valueTextField.placeholder = "select files"
                    cell.imageFileView.image = nil
                    cell.imageFileView.isHidden = true
                }
            }
        }
        return cell
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
            guard let body = RequestVC.shared?.state.body else { completion(false); return }
            var shouldReload = false
            if self.selectedType == .form {
                if body.form.count > indexPath.row {
                    RequestVC.shared?.state.body!.form.remove(at: indexPath.row)
                    shouldReload = true
                }
            } else if self.selectedType == .multipart {
                if body.multipart.count > indexPath.row {
                    RequestVC.shared?.state.body!.multipart.remove(at: indexPath.row)
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
            if let body = RequestVC.shared?.state.body {
                if (self.selectedType == .form && body.form.count <= 1) || (self.selectedType == .multipart && body.multipart.count <= 1) {
                    return false
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
    
    func updateState(_ data: RequestData, row: Int) {
        RequestVC.addRequestBodyToState()
        guard let body = RequestVC.shared?.state.body else { return }
        body.selected = self.selectedType.rawValue
        if self.selectedType == .form {
            if body.form.count == 0 {
                body.form.append(data)
            } else if body.form.count > row {
                body.form[row] = data
            }
        } else if self.selectedType == .multipart {
            if body.multipart.count == 0 {
                body.multipart.append(data)
            } else if body.multipart.count > row {
                body.multipart[row] = data
            }
        }
        RequestVC.shared?.state.body = body
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
    
    func addRequestDataToModel(_ data: RequestDataProtocol) {
        switch self.tableViewType {
        case .header:
            if let aData = data as? RequestData {
                RequestVC.shared?.state.headers.append(aData)
            }
        case .params:
            if let aData = data as? RequestData {
                RequestVC.shared?.state.params.append(aData)
            }
        case .body:
            if RequestVC.shared?.state.body == nil {
                RequestVC.addRequestBodyToState()
            }
            if let aData = data as? RequestData {
                if RequestVC.shared?.state.body!.selected == RequestBodyType.form.rawValue {
                    RequestVC.shared?.state.body!.form.append(aData)
                } else if RequestVC.shared?.state.body!.selected == RequestBodyType.multipart.rawValue {
                    RequestVC.shared?.state.body!.multipart.append(aData)
                }
            }
        }
    }
    
    func removeRequestDataFromModel(_ index: Int) {
        if RequestVC.shared == nil { return }
        switch self.tableViewType {
        case .header:
            if RequestVC.shared!.state.headers.count > index {
                RequestVC.shared!.state.headers.remove(at: index)
            }
        case .params:
            if RequestVC.shared!.state.params.count > index {
                RequestVC.shared!.state.params.remove(at: index)
            }
        case .body:
            RequestVC.shared!.state.body = nil
            OptionsPickerState.selected = 0
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
        if RequestVC.shared == nil { return 0.0 }
        var height: CGFloat = 44
        switch self.tableViewType {
        case .header:
            if RequestVC.shared!.state.headers.count == 0 {
                height = 48
            } else {
                height = CGFloat(Double(RequestVC.shared!.state.headers.count) * 92.5 + 50)
            }
        case .params:
            if RequestVC.shared?.state.params.count == 0 {
                height = 48
            } else {
                height = CGFloat(Double(RequestVC.shared!.state.params.count) * 92.5 + 50)
            }
        case .body:
            if let body = RequestVC.shared?.state.body {
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
        guard let state = RequestVC.shared?.state else { return 0 }
        if section == 0 {
            switch self.tableViewType {
            case .header:
                return state.headers.count
            case .params:
                return state.params.count
            case .body:
                if state.body == nil { return 0 }
                return 1
            }
        }
        // section 1 (header)
        if self.tableViewType == .body && RequestVC.shared?.state.body != nil {
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
                    if let body = RequestVC.shared?.state.body {
                        return body.selected
                    }
                    return 0
                }()
                switch selectedIdx {
                case RequestBodyType.json.rawValue:
                    cell.rawTextView.text = RequestVC.shared?.state.body?.json ?? ""
                    cell.hideFormFields()
                case RequestBodyType.xml.rawValue:
                    cell.rawTextView.text = RequestVC.shared?.state.body?.xml ?? ""
                    cell.hideFormFields()
                case RequestBodyType.raw.rawValue:
                    cell.rawTextView.text = RequestVC.shared?.state.body?.raw ?? ""
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
                if RequestVC.shared != nil, RequestVC.shared!.state.body != nil {
                    cell.updateState(RequestVC.shared!.state.body!)
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
                    if RequestVC.shared != nil, RequestVC.shared!.state.headers.count > row {
                        let data = RequestVC.shared!.state.headers[row]
                        cell.keyTextField.text = data.getKey()
                        cell.valueTextField.text = data.getValue()
                    }
                case .params:
                    if RequestVC.shared != nil, RequestVC.shared!.state.params.count > row {
                        let data = RequestVC.shared!.state.params[row]
                        cell.keyTextField.text = data.getKey()
                        cell.valueTextField.text = data.getValue()
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
            self.addRequestDataToModel(RequestData())
            self.disableEditing(indexPath: indexPath)
            self.reloadData()
            self.delegate?.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.tableViewType == .body {
            if let body = RequestVC.shared?.state.body {
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
    
    func dataDidChange(_ data: RequestData, row: Int) {
        if RequestVC.shared == nil { return }
        if self.tableViewType == .header {
            if RequestVC.shared!.state.headers.count > row {
                RequestVC.shared!.state.headers[row] = data
            } else {
                RequestVC.shared!.state.headers.append(data)
            }
        } else if self.tableViewType == .params {
            if RequestVC.shared!.state.params.count > row {
                RequestVC.shared!.state.params[row] = data
            } else {
                RequestVC.shared!.state.params.append(data)
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

