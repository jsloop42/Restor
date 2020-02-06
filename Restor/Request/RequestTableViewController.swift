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
    @IBOutlet weak var descTextView: UITextView!
    @IBOutlet var infoTableViewManager: InfoTableViewManager!
    @IBOutlet var kvTableViewManager: KVTableViewManager!
    @IBOutlet weak var kvTableView: UITableView!
    /// Whether the request is running, in which case, we don't remove any listeners
    var isActive = false
    
    override func viewWillDisappear(_ animated: Bool) {
        if !self.isActive {
            self.kvTableViewManager.destroy()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request table vc view did load")
//        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
//        self.view.addGestureRecognizer(tap)
        self.kvTableViewManager.kvTableView = self.kvTableView
        self.kvTableViewManager.delegate = self
        self.kvTableViewManager.bootstrap()
        self.kvTableViewManager.reloadData()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
    }
    
    @objc func endEditing() {
        Log.debug("end editing")
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("request table view did select")
        if indexPath.row == 2 {
            if let tv = self.kvTableViewManager.kvTableView { self.kvTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 2 {
            return self.kvTableViewManager.getHeight()
        }
        return UITableView.automaticDimension
    }
}

extension RequestTableViewController: KVTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
}

protocol KVTableViewDelegate: class {
    func reloadData()
}

class KVHeaderCell: UITableViewCell {
    @IBOutlet weak var headerTitleBtn: UIButton!
}

protocol KVContentCellDelegate: class {
    func enableEditing(indexPath: IndexPath)
    func disableEditing(indexPath: IndexPath)
    func clearEditing()
    func deleteRow(indexPath: IndexPath)
}

class KVContentCell: UITableViewCell {
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
}

class KVTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: UITableView?
    weak var delegate: KVTableViewDelegate?
    var model: [RequestDataProtocol] = []
    var height: CGFloat = 44
    var editingIndexPath: IndexPath?
    
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
        return CGFloat(self.model.count * 114 + 44)
    }
    
//    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
//        if indexPath == self.editingIndexPath {
//            return true
//        }
//        return false
//    }
    
//    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//        if indexPath.section == 0 {
//            if editingStyle == .delete {
//                let row = indexPath.row
//                if self.model.count > row {
//                    self.model.remove(at: row)
//                }
//            }
//        }
//    }
//
//    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, view: UIView, success: @escaping (Bool) -> Void) in
//            success(true)
//        }
//        deleteAction.backgroundColor = .red
//        return UISwipeActionsConfiguration(actions: [deleteAction])
//    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.model.count
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "kvHeaderCell", for: indexPath) as! KVHeaderCell
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
        guard let cell = self.kvTableView?.cellForRow(at: indexPath) as? KVContentCell else { return }

        UIView.animate(withDuration: 0.3, animations: {
            cell.containerView.transform = CGAffineTransform.identity.translatedBy(x: -64, y: 0)
        }, completion: nil)
    }
    
    func hideDeleteRowView(cell: KVContentCell) {
        cell.containerView.transform = CGAffineTransform.identity
        cell.deleteView.isHidden = true
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
}

//class HeaderCollectionViewCell: UICollectionViewCell {
//    @IBOutlet weak var nameLbl: UILabel!
//
//    func update(index: Int, text: String) {
//        self.nameLbl.text = text
//    }
//}

struct InfoField {
    var name: String
    var value: Any
}

//class RequestTableViewController: UITableViewController {
//    @IBOutlet weak var headerCollectionView: InfiniteCollectionView!
//    @IBOutlet weak var requestInfoCell: UITableViewCell!
//    @IBOutlet weak var descriptionTextView: UITextView!
//    @IBOutlet var infoTableViewManager: InfoTableViewManager!
//    @IBOutlet weak var infoTableView: UITableView!
//    let header: [String] = ["Description", "Headers", "URL Params", "Body", "Auth", "Options"]
//    lazy var infoxs: [UIView] = {
//        return [self.descriptionTextView, self.infoTableView]
//    }()
//    private var requestInfo: RequestHeaderInfo = .description
//    private var headerData: [InfoField] = []
//    private var urlParamsData: [InfoField] = []
//
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        self.navigationItem.title = "New Request"
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        Log.debug("request vc did load")
//        self.headerCollectionView.infiniteLayout.isEnabled = false
//        self.infoTableViewManager.delegate = self
////        self.infoTableView.delegate = self.infoTableViewManager
////        self.infoTableView.dataSource = self.infoTableViewManager
//        self.infoTableView.estimatedRowHeight = 44
//        self.infoTableView.rowHeight = UITableView.automaticDimension
//        self.headerCollectionView.reloadData()
//        self.hideInfoElements()
//        self.descriptionTextView.isHidden = false
//    }
//
//    func hideInfoElements() {
//        self.infoxs.forEach { v in v.isHidden = true }
//    }
//
//    func processCollectionViewTap(_ info: RequestHeaderInfo) {
//        Log.debug("selected element: \(String(describing: info))")
//        self.requestInfo = info
//        self.hideInfoElements()
//        switch info {
//        case .description:
//            self.descriptionTextView.isHidden = false
//        case .headers:
//            self.infoTableView.isHidden = false
//            self.infoTableView.reloadData()
//        default:
//            break
//        }
//    }
//
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        Log.debug("main table view did select \(indexPath.row)")
//    }
//}
//
//extension RequestTableViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return self.header.count
//    }
//
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "headerCell", for: indexPath) as! HeaderCollectionViewCell
//        let path = self.headerCollectionView.indexPath(from: indexPath)
//        cell.update(index: path.row, text: self.header[path.row])
//        return cell
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        var width: CGFloat = 0
//        let row = indexPath.row
//        if self.header.count > row {
//            let text = self.header[row]
//            width = UILabel.textWidth(font: UIFont.systemFont(ofSize: 16), text: text)
//        }
//        Log.debug("label width: \(width)")
//        return CGSize(width: width, height: 22)
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//        return 12
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//        return 4
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
//        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }
//
//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        Log.debug("collection view did select \(indexPath.row)")
//        self.processCollectionViewTap(RequestHeaderInfo(rawValue: indexPath.row) ?? .description)
//    }
//}
//
//extension RequestTableViewController: InfoTableViewDelegate {
//    func currentRequestInfo() -> RequestHeaderInfo {
//        return self.requestInfo
//    }
//
//    func model() -> [InfoField] {
//        switch self.requestInfo {
//        case .headers:
//            return self.headerData
//        case .urlParams:
//            return self.urlParamsData
//        default:
//            return []
//        }
//    }
//
//    func updateModel(_ info: InfoField, index: Int) {
//        switch self.requestInfo {
//        case .headers:
//            if self.headerData.count > index {
//                self.headerData[index] = info
//            } else {
//                self.headerData.append(info)
//            }
//        default:
//            break
//        }
//    }
//
//    func reloadInfoTableView(_ callback: @escaping () -> Void) {
//        self.infoTableView.reloadData {
//            callback()
//        }
//        //self.tableView.reloadData()
//    }
//
//    func reloadInfoTableView() {
//        self.infoTableView.reloadData()
//    }
//
//    func becomeFirstResponder(_ tag: Int) {
//        if let cell = self.infoTableView.cellForRow(at: IndexPath(row: tag, section: 0)) as? InfoTableCell {
//            cell.keyTextField.becomeFirstResponder()
//        }
//    }
//}

// MARK: - Header Info

protocol InfoTableViewDelegate: class {
    func currentRequestInfo() -> RequestHeaderInfo
    func model() -> [InfoField]
    func updateModel(_ info: InfoField, index: Int)
    func reloadInfoTableView(_ callback: @escaping () -> Void)
    func reloadInfoTableView()
    func becomeFirstResponder(_ tag: Int)
}

class InfoTableCell: UITableViewCell {
    @IBOutlet weak var keyTextField: EATextField!
    @IBOutlet weak var valueTextField: EATextField!
    @IBOutlet var keyTextFieldHeight: NSLayoutConstraint!
    @IBOutlet var valueTextFieldHeight: NSLayoutConstraint!
    var isTextFieldDelegateSet = false
}

class InfoTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: InfoTableViewDelegate?
    private let textFieldBorderColor: UIColor = UITextField(frame: .zero).borderColor!

    override init() {
        super.init()
        Log.debug("info table view manager init")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let delegate = self.delegate {
            return delegate.model().count + 2
        }
        return 2
    }

    func updateStyleForInfoFieldHeader(_ textField: EATextField, height: NSLayoutConstraint) {
        textField.isEnabled = false
        textField.isColor = false
        height.isActive = false
        height.constant = 32
        height.isActive = true
        textField.setNeedsDisplay()
    }

    func updateStyleForInfoField(_ textField: EATextField, height: NSLayoutConstraint) {
        textField.isEnabled = true
        textField.isColor = true
        height.isActive = false
        height.constant = 40
        height.isActive = true
        textField.setNeedsDisplay()
    }

    func updateStyleForInfoFieldRow(_ cell: InfoTableCell) {
        cell.keyTextField.borderStyle = .none
        cell.valueTextField.borderStyle = .none

        if cell.tag == 0 {
            self.updateStyleForInfoFieldHeader(cell.keyTextField, height: cell.keyTextFieldHeight)
            self.updateStyleForInfoFieldHeader(cell.valueTextField, height: cell.valueTextFieldHeight)
        } else {
            self.updateStyleForInfoField(cell.keyTextField, height: cell.keyTextFieldHeight)
            self.updateStyleForInfoField(cell.valueTextField, height: cell.valueTextFieldHeight)
            cell.keyTextField.returnKeyType = .next
            cell.valueTextField.returnKeyType = .done
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "infoCell", for: indexPath) as! InfoTableCell
        let row = indexPath.row
        cell.tag = row
        self.updateStyleForInfoFieldRow(cell)
        guard let delegate = self.delegate else { return cell }
        let model = delegate.model()

        switch delegate.currentRequestInfo() {
        case .headers:
            if row == 0 {
                cell.keyTextField.text = "Header Name"
                cell.valueTextField.text = "Header Value"
            }
            cell.keyTextField.placeholder = "Add Header Name"
            cell.valueTextField.placeholder = "Add Header Value"
        default:
            break
        }

        cell.keyTextField.tag = row * 2
        cell.valueTextField.tag = row * 2 + 1

        if !cell.isTextFieldDelegateSet {
            cell.keyTextField.delegate = self
            cell.valueTextField.delegate = self
            cell.isTextFieldDelegateSet = true
        }
        if row > 0 && row <= model.count {
            let x = model[row - 1]
            cell.keyTextField.text = x.name
            cell.valueTextField.text = String(describing: x.value)
        }
        return cell
    }

    func rowToIndex(_ row: Int) -> Int {
        return row % 2 == 0 ? row / 2 - 1 : (row - 1) / 2 - 1
    }
}

extension InfoTableViewManager: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        Log.debug("text field did end editing")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        Log.debug("text field should return")
        let row = textField.tag
        if let tf = textField.superview?.viewWithTag(row + 1) {
            tf.becomeFirstResponder()
        } else {
            var name = ""
            if let tf = textField.superview?.viewWithTag(row - 1) as? EATextField {
                name = tf.text ?? ""
            }
            if !name.isEmpty {
                self.delegate?.updateModel(InfoField(name: name, value: textField.text ?? ""), index: self.rowToIndex(row))
                self.delegate?.reloadInfoTableView()
            }
            textField.resignFirstResponder()
        }
        return false
    }
}
