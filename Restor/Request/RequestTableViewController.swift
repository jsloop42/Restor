//
//  RequestTableViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import InfiniteLayout

class RequestTableViewController: UITableViewController {
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var goBtn: UIButton!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var descTextView: EATextView!
    @IBOutlet var headerKVTableViewManager: KVTableViewManager!
    @IBOutlet var paramsKVTableViewManager: KVTableViewManager!
    @IBOutlet var bodyKVTableViewManager: KVTableViewManager!
    @IBOutlet weak var headersTableView: UITableView!
    @IBOutlet weak var paramsTableView: UITableView!
    @IBOutlet weak var bodyTableView: UITableView!
    /// Whether the request is running, in which case, we don't remove any listeners
    var isActive = false
    
    enum CellId: Int {
        case url = 0
        case name = 1
        case header = 2
        case params = 3
        case body = 4
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if !self.isActive {
            self.headerKVTableViewManager.destroy()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request table vc view did load")
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
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
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("request table view did select")
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
            height = 152
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            height = self.headerKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            height = self.paramsKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            height = self.bodyKVTableViewManager.getHeight()
        } else {
            height = UITableView.automaticDimension
        }
        Log.debug("height: \(height)")
        return height
    }
}

extension RequestTableViewController: KVTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
    
    func presentOptionsVC(_ data: [String], selected: Int) {
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.optionsDelegate = self
            OptionsPickerState.data = data
            OptionsPickerState.selected = selected
            self.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
}

extension RequestTableViewController: OptionsPickerViewDelegate {
    func reloadOptionsData() {
        self.bodyKVTableViewManager.reloadData()
        self.tableView.reloadRows(at: [IndexPath(row: CellId.body.rawValue, section: 0)], with: .none)
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
    func clearEditing()
    func deleteRow(indexPath: IndexPath)
    func presentOptionsVC(_ data: [String], selected: Int)
}

protocol KVContentCellType: class {
    func getDeleteView() -> UIView
    func getContainerView() -> UIView
}

class KVContentCell: UITableViewCell, KVContentCellType {
    @IBOutlet weak var keyTextField: UITextField!
    @IBOutlet weak var valueTextField: UITextField!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var containerView: UIView!
    weak var delegate: KVContentCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvcontentcell awake from nib")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.deleteView.isHidden = true
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
        self.delegate?.clearEditing()
        self.delegate?.enableEditing(indexPath: IndexPath(row: self.tag, section: 0))
        UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
            self.deleteView.isHidden = false
        }, completion: nil)
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
}

class KVBodyContentCell: UITableViewCell, KVContentCellType {
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var typeNameBtn: UIButton!
    @IBOutlet weak var kvStackView: UIStackView!
    @IBOutlet weak var rawStackView: UIStackView!
    @IBOutlet weak var keyTextField: UITextField!
    @IBOutlet weak var valueTypeBtn: UIButton!
    @IBOutlet weak var valueTextField: UITextField!
    @IBOutlet weak var rawTextView: EATextView!
    @IBOutlet var bodyLabelViewWidth: NSLayoutConstraint!
    @IBOutlet weak var typeLabel: UILabel!
    weak var delegate: KVContentCellDelegate?
    private var optionsData: [String] = ["json", "xml", "raw", "form", "multipart", "binary"]
    private struct State {
        var json: String = ""
        var xml: String = ""
        var raw: String = ""
        var form: Any?
        var multipart: Any?
        var binary: Data?
        var selected: Int = OptionsPickerState.selected
    }
    private var state: State = State()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvcontentcell awake from nib")
        self.rawTextView.delegate = self
        self.initUI()
        self.initEvents()
        self.updateState()
    }
    
    func initUI() {
        self.kvStackView.isHidden = true
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
        self.delegate?.clearEditing()
        self.delegate?.enableEditing(indexPath: IndexPath(row: self.tag, section: 0))
        UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
            self.deleteView.isHidden = false
        }, completion: nil)
    }
    
    @objc func deleteViewDidTap() {
        Log.debug("delete view did tap")
        self.delegate?.deleteRow(indexPath: IndexPath(row: self.tag, section: 0))
    }
    
    @IBAction func typeBtnDidTap(_ sender: Any) {
        Log.debug("type name did tap")
        self.delegate?.presentOptionsVC(self.optionsData, selected: OptionsPickerState.selected)
    }
    
    func getDeleteView() -> UIView {
        return self.deleteView
    }
    
    func getContainerView() -> UIView {
        return self.containerView
    }
    
    func updateState() {
        let idx = OptionsPickerState.selected
        self.typeLabel.text = "(\(self.optionsData[idx]))"
        self.bodyLabelViewWidth.isActive = false
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
        switch OptionsPickerState.selected {
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

class KVTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: UITableView?
    weak var delegate: KVTableViewDelegate?
    var model: [RequestDataProtocol] = []
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
        self.model.append(data)
        Log.debug("model count: \(self.model.count)")
    }
    
    func removeRequestDataFromModel(_ index: Int) {
        if self.model.count > index {
            self.model.remove(at: index)
        }
    }
    
    func reloadData() {
        self.kvTableView?.reloadData()
    }
    
    func getHeight() -> CGFloat {
        if self.tableViewType == .body {
            if let tv = self.kvTableView {
                let h = tv.contentSize.height
                if h < 300 {
                    return 300
                }
                if h > 500 {
                    return 500
                }
            }
            return 300
        }
        return CGFloat(self.model.count * 114 + 44)
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
        if section == 0 {
            return self.model.count
        }
        if self.tableViewType == .body && self.model.count > 0 {
            return 0
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if self.tableViewType == .body {
                let cell = tableView.dequeueReusableCell(withIdentifier: "bodyContentCell", for: indexPath) as! KVBodyContentCell
                cell.delegate = self
                let row = indexPath.row
                self.hideDeleteRowView(cell: cell)
                if self.model.count > row {
                    let data = self.model[row]
                    cell.tag = row
                    cell.keyTextField.text = data.getKey()
                    cell.valueTextField.text = data.getValue()
                    cell.updateState()
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "kvContentCell", for: indexPath) as! KVContentCell
                cell.delegate = self
                let row = indexPath.row
                self.hideDeleteRowView(cell: cell)
                if self.model.count > row {
                    let data = self.model[row]
                    cell.keyTextField.text = data.getKey()
                    cell.valueTextField.text = data.getValue()
                    cell.tag = row
                }
                return cell
            }
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "kvTitleCell", for: indexPath) as! KVHeaderCell
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("kvTableView row did select")
        self.clearEditing()
        if indexPath.section == 1 {  // header
            self.addRequestDataToModel(RequestData())
            self.disableEditing(indexPath: indexPath)
            self.reloadData()
            self.delegate?.reloadData()
        }
    }
    
    func previewActions(forCellAt indexPath: IndexPath) {
        guard let tv = self.kvTableView else { return }
        guard let cell: KVContentCellType = tv.cellForRow(at: indexPath) as? KVContentCellType else { return }
        UIView.animate(withDuration: 0.3, animations: {
            cell.getContainerView().transform = CGAffineTransform.identity.translatedBy(x: -64, y: 0)
        }, completion: nil)
    }
    
    func hideDeleteRowView(cell: KVContentCellType) {
        cell.getContainerView().transform = CGAffineTransform.identity
        cell.getDeleteView().isHidden = true
    }
    
    func hideActions(forCellAt indexPath: IndexPath) {
        Log.debug("hide actions")
        guard let cell = self.kvTableView?.cellForRow(at: indexPath) as? KVContentCell else { return }
        UIView.animate(withDuration: 0.3, animations: {
            self.hideDeleteRowView(cell: cell)
        }, completion: nil)
    }
}

extension KVTableViewManager: KVContentCellDelegate {
    func enableEditing(indexPath: IndexPath) {
        self.editingIndexPath = indexPath
        self.previewActions(forCellAt: indexPath)
    }
    
    func disableEditing(indexPath: IndexPath) {
        self.editingIndexPath = nil
        self.hideActions(forCellAt: indexPath)
    }
    
    func clearEditing() {
        if let indexPath = self.editingIndexPath {
            self.hideActions(forCellAt: indexPath)
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

