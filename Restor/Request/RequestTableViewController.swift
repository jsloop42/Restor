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
    static var state: Request = Request()
    var isEndEditing = false
    
    enum CellId: Int {
        case url = 0
        case name = 1
        case header = 2
        case params = 3
        case body = 4
    }
    
    deinit {
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
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
        self.urlTextField.delegate = self
        self.nameTextField.delegate = self
        self.descTextView.delegate = self
        // Set bottom border
        self.app.updateTextFieldWithBottomBorder(self.urlTextField)
        self.app.updateTextFieldWithBottomBorder(self.nameTextField)
        // test
        self.urlCell.borderColor = .clear
        self.nameCell.borderColor = .clear
        self.headerCell.borderColor = .clear
        self.paramsCell.borderColor = .clear
        self.bodyCell.borderColor = .clear
        // end test
    }
    
    func initEvents() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        self.nc.addObserver(self, selector: #selector(self.reloadTableView), name: NotificationKey.requestTableViewReload, object: nil)
        self.nc.addObserver(self, selector: #selector(self.clearEditing), name: NotificationKey.requestViewClearEditing, object: nil)
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
        if indexPath.row == CellId.name.rawValue {
            height = 167
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            height = self.headerKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            height = self.paramsKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            if let body = RequestVC.state.body, body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue {
                return RequestVC.bodyFormCellHeight()
            }
            height = self.bodyKVTableViewManager.getHeight()
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
            RequestVC.state.url = textField.text ?? ""
        } else if textField == self.nameTextField {
            RequestVC.state.name = textField.text ?? ""
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        RequestVC.shared?.clearEditing()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == self.descTextView {
            RequestVC.state.desc = textView.text ?? ""
        }
    }
    
    static func addRequestBodyToState() {
        if self.state.body == nil {
            self.state.body = RequestBodyData()
        }
    }
    
    static func bodyFormCellHeight() -> CGFloat {
        if let body = RequestVC.state.body {
            let count = body.form.count == 0 ? 1 : body.form.count
            return CGFloat(count * 84) + 77  // 84: field cell, 77: title cell
        }
        return 161  // 84 + 77
    }
}

extension RequestTableViewController: KVTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
    
    func presentOptionsVC(_ data: [String], selected: Int) {
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.optionsDelegate = self
            if RequestVC.state.body == nil {
                RequestVC.state.body = RequestBodyData()
            }
            RequestVC.state.body!.selected = selected
            OptionsPickerState.data = data
            self.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
}

extension RequestTableViewController: OptionsPickerViewDelegate {
    func reloadOptionsData() {
        self.bodyKVTableViewManager.reloadData()
        self.tableView.reloadRows(at: [IndexPath(row: CellId.body.rawValue, section: 0)], with: .none)
    }
    
    func optionDidSelect(_ row: Int) {
        RequestVC.state.body!.selected = row
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
        self.app.updateTextFieldWithBottomBorder(self.keyTextField)
        self.app.updateTextFieldWithBottomBorder(self.valueTextField)
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
        //self.delegate?.clearEditing(completion: { _ in
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
}

// MARK: - Body cell

class KVBodyContentCell: UITableViewCell, KVContentCellType {
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var typeNameBtn: UIButton!
    @IBOutlet weak var rawStackView: UIStackView!
    @IBOutlet weak var rawTextView: EATextView!
    @IBOutlet var bodyLabelViewWidth: NSLayoutConstraint!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var bodyFieldTableView: KVBodyFieldTableView!
    weak var delegate: KVContentCellDelegate?
    var optionsData: [String] = ["json", "xml", "raw", "form", "multipart", "binary"]
    var state = RequestBodyData()
    var isEditingActive: Bool = false
    var editingIndexPath: IndexPath?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvcontentcell awake from nib")
        self.rawTextView.delegate = self
        self.initUI()
        self.initEvents()
        self.updateState(self.state)
    }
    
    func initUI() {
        self.bodyFieldTableView.isHidden = true
        self.rawStackView.isHidden = false
        let font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
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
//        self.delegate?.clearEditing(completion: { _ in
//            self.delegate?.enableEditing(indexPath: IndexPath(row: self.tag, section: 0))
//            UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
//                self.deleteView.isHidden = false
//            }, completion: nil)
//        })
    }
    
    @objc func deleteViewDidTap() {
        Log.debug("delete view did tap")
        self.delegate?.deleteRow(indexPath: IndexPath(row: self.tag, section: 0))
        self.bodyFieldTableView.reloadData()
    }
    
    @IBAction func typeBtnDidTap(_ sender: Any) {
        Log.debug("type name did tap")
        var selected: Int! = 0
        if let body = RequestVC.state.body {
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
        self.rawStackView.isHidden = true
        RequestVC.addRequestBodyToState()
        self.bodyFieldTableView.selectedType = RequestBodyType(rawValue: RequestVC.state.body!.selected)!
        self.bodyFieldTableView.reloadData()
    }
    
    func hideFormFields() {
        self.bodyFieldTableView.isHidden = true
        self.rawStackView.isHidden = false
    }
    
    func updateState(_ data: RequestBodyData) {
        let idx: Int = OptionsPickerState.selected
        RequestVC.addRequestBodyToState()
        RequestVC.state.body!.selected = idx
        self.typeLabel.text = "(\(self.optionsData[idx]))"
        self.bodyLabelViewWidth.isActive = false
        self.state.selected = idx
        switch idx {
        case 0:  // json
            self.bodyLabelViewWidth.constant = 60
            self.rawTextView.placeholder =
            """
            {
              "loc": "entangled",
              "num": "8",
              "state": "quasi"
            }
            """
            self.rawTextView.text = self.state.json
        case 1:  // xml
            self.bodyLabelViewWidth.constant = 60
            self.rawTextView.placeholder =
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <request code="zeta">
                  <messages>
                    <message key="input">42</message>
                  </messages>
                </response>
                """
            self.rawTextView.text = self.state.xml
        case 2:  // raw
            self.bodyLabelViewWidth.constant = 60
            self.rawTextView.placeholder =
                """
                {"sub":"api-test","res":"ok","code":"0"}
                """
            self.rawTextView.text = self.state.raw
        case 3:  // form
            self.bodyLabelViewWidth.constant = 63
            self.displayFormFields()
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

extension KVBodyContentCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let txt = textView.text ?? ""
        Log.debug("text changed: \(txt)")
        guard let body = RequestVC.state.body else { return }
        let selected = body.selected
        switch selected {
        case 0:
            self.state.json = txt
        case 1:
            self.state.xml = txt
        case 2:
            self.state.raw = txt
        default:
            break
        }
    }
}

// MARK: - Body field table view

protocol KVBodyFieldTableViewCellDelegate: class {
    func updateUIState(_ row: Int, callback: () -> Void)
    func updateState(_ data: RequestData)
}

class KVBodyFieldTableViewCell: UITableViewCell, UITextFieldDelegate {
    @IBOutlet weak var keyTextField: EATextField!
    @IBOutlet weak var valueTextField: EATextField!
    weak var delegate: KVBodyFieldTableViewCellDelegate?
    var isValueTextFieldActive = false
    var selectedType: RequestBodyType = .form
    var isKeyTextFieldActive = false

    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
    }
    
    func bootstrap() {
        self.keyTextField.delegate = self
        self.valueTextField.delegate = self
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        Log.debug("text field did begin editing")
        RequestVC.shared?.clearEditing()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        Log.debug("textfield did end editing")
        if textField == self.keyTextField {
            self.delegate?.updateState(RequestData(key: textField.text ?? "", value: self.valueTextField.text ?? ""))
        } else if textField == self.valueTextField {
            self.delegate?.updateState(RequestData(key: self.keyTextField.text ?? "", value: textField.text ?? ""))
        }
        // TODO: update state
    }
}

class KVBodyFieldTableView: UITableView, UITableViewDelegate, UITableViewDataSource, KVBodyFieldTableViewCellDelegate {
    private let cellId = "kvBodyTableViewCell"
    var isCellRegistered = false
    private let nc = NotificationCenter.default
    var selectedType: RequestBodyType = .form
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        Log.debug("kvbodyfieldtableview init")
        self.bootstrap()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Log.debug("kvbodyfieldtableview init coder")
        self.bootstrap()
    }
    
    func bootstrap() {
        self.delegate = self
        self.dataSource = self
        self.estimatedRowHeight = 44
        self.rowHeight = UITableView.automaticDimension
    }
    
    func addFields() {
        let data = RequestData(key: "", value: "")
        self.updateState(data)
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
        guard let body = RequestVC.state.body else { return 0 }
        if section == 1 {  // title
            return 1
        }
        let data: [RequestData] = {
            if self.selectedType == .form {
                return body.form
            }
            return body.multipart
        }()
        return data.count > 0 ? data.count : 1
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
        if let body = RequestVC.state.body {
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
        }
        return cell
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
            guard let body = RequestVC.state.body else { completion(false); return }
            var shouldReload = false
            if self.selectedType == .form {
                if body.form.count > indexPath.row {
                    RequestVC.state.body!.form.remove(at: indexPath.row)
                    shouldReload = true
                }
            } else if self.selectedType == .multipart {
                if body.multipart.count > indexPath.row {
                    RequestVC.state.body!.multipart.remove(at: indexPath.row)
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
            if let body = RequestVC.state.body {
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
    
    func updateUIState(_ row: Int, callback: () -> Void) {
        Log.debug("update UI state: \(row)")
        //self.scrollToRow(at: IndexPath(row: aRow, section: 0), at: .top, animated: true)
        RequestVC.shared?.bodyKVTableViewManager.reloadData()
        RequestVC.shared?.reloadData()
        callback()
    }
    
    func updateState(_ data: RequestData) {
        RequestVC.addRequestBodyToState()
        guard let body = RequestVC.state.body else { return }
        body.selected = self.selectedType.rawValue
        if self.selectedType == .form {
            if body.form.count == 0 {
                body.form.append(RequestData(key: "", value: ""))
            }
            body.form.append(data)
        } else if self.selectedType == .multipart {
            if body.multipart.count == 0 {
                body.multipart.append(RequestData(key: "", value: ""))
            }
            body.multipart.append(data)
        }
        RequestVC.state.body = body
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
                RequestVC.state.headers.append(aData)
            }
        case .params:
            if let aData = data as? RequestData {
                RequestVC.state.params.append(aData)
            }
        case .body:
            if RequestVC.state.body == nil {
                RequestVC.addRequestBodyToState()
            }
            if let aData = data as? RequestData {
                if RequestVC.state.body!.selected == RequestBodyType.form.rawValue {
                    RequestVC.state.body!.form.append(aData)
                } else if RequestVC.state.body!.selected == RequestBodyType.multipart.rawValue {
                    RequestVC.state.body!.multipart.append(aData)
                }
            }
        }
    }
    
    func removeRequestDataFromModel(_ index: Int) {
        switch self.tableViewType {
        case .header:
            if RequestVC.state.headers.count > index {
                RequestVC.state.headers.remove(at: index)
            }
        case .params:
            if RequestVC.state.params.count > index {
                RequestVC.state.params.remove(at: index)
            }
        case .body:
            RequestVC.state.body = nil
        }
    }
    
    func reloadData() {
        self.kvTableView?.reloadData()
    }
    
    func getTextHeight(_ txt: String) -> CGFloat {
        var height: CGFloat = UI.getTextHeight(txt, width: 283, font: UIFont.systemFont(ofSize: 14))
        if height > 300 {
            height = 300
        } else if height < 78 {
            height = 150
        }
        return height
    }
    
    func getHeight() -> CGFloat {
        var height: CGFloat = 44
        switch self.tableViewType {
        case .header:
            height = CGFloat(RequestVC.state.headers.count * 94 + 44)
        case .params:
            height = CGFloat(RequestVC.state.params.count * 94 + 48)
        case .body:
            if let body = RequestVC.state.body {
                if body.selected == RequestBodyType.json.rawValue {
                    let txt = RequestVC.state.body!.json ?? ""
                    height = self.getTextHeight(txt)
                } else if body.selected == RequestBodyType.xml.rawValue {
                    let txt = RequestVC.state.body!.xml ?? ""
                    height = self.getTextHeight(txt)
                } else if body.selected == RequestBodyType.raw.rawValue {
                    let txt = RequestVC.state.body!.raw ?? ""
                    height = self.getTextHeight(txt)
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
                height = 48
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
        let state = RequestVC.state
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
        if self.tableViewType == .body && RequestVC.state.body != nil {
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
                cell.state.selected = {
                    if let body = RequestVC.state.body {
                        return body.selected
                    }
                    return 0
                }()
                if cell.state.selected == 3 {  // form
                    cell.displayFormFields()
                } else {
                    cell.hideFormFields()
                }
                if RequestVC.state.body != nil {
                    cell.updateState(RequestVC.state.body!)
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
                    if RequestVC.state.headers.count > row {
                        let data = RequestVC.state.headers[row]
                        cell.keyTextField.text = data.getKey()
                        cell.valueTextField.text = data.getValue()
                    }
                case .params:
                    if RequestVC.state.params.count > row {
                        let data = RequestVC.state.params[row]
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
        //self.clearEditing()
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
            if let body = RequestVC.state.body, body.selected == RequestBodyType.form.rawValue {
                return RequestVC.bodyFormCellHeight()
            }
        }
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
}

