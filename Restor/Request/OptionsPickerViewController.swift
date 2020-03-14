//
//  OptionsPickerViewController.swift
//  Restor
//
//  Created by jsloop on 08/02/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

enum OptionPickerType: Int {
    /// Body types: json, xml, raw, etc.
    case requestBodyForm
    /// GET, POST, etc.
    case requestMethod
    /// Text, file
    case requestBodyFormField
}

enum OptionDataAction: Int {
    case add
    case delete
}

class OptionsPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    private let app = App.shared
    var pickerType: OptionPickerType = .requestBodyForm
    private let nc = NotificationCenter.default
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerLabel: UILabel!
    var selectedIndex: Int = 0
    var modelIndex: Int = 0
    var data: [String] = []
    var reqMethodData: [ERequestMethodData] = []
    var name = ""
    var model: Any?  // Any model data, eg: RequestData associated with a body form field
    var modelxs: [Any] = []
    
    deinit {
        Log.debug("option picker vc deinit")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.activeScreen = .optionListing
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("options picker vc view did load")
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
        self.initUI()
        self.initEvent()
    }
    
    func destroy() {
        self.nc.removeObserver(self)
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.titleLabel.text = self.name
        if self.pickerType == .requestMethod {
            self.footerLabel.text = "add custom method"
            self.footerLabel.isHidden = false
        } else {
            self.footerLabel.isHidden = true
        }
    }
    
    func initEvent() {
        if self.pickerType == .requestMethod {
            let footerTap = UITapGestureRecognizer(target: self, action: #selector(self.footerDidTap))
            self.footerView.addGestureRecognizer(footerTap)
            self.nc.addObserver(self, selector: #selector(self.keyboardWillShow(notif:)), name: UIResponder.keyboardWillShowNotification, object: nil)
            self.nc.addObserver(self, selector: #selector(self.keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        self.nc.addObserver(self, selector: #selector(self.optionPickerShouldReload(_:)), name: NotificationKey.optionPickerShouldReload, object: nil)
    }
    
    @objc func keyboardWillShow(notif: Notification) {
        if let userInfo = notif.userInfo, let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            AppState.keyboardHeight = keyboardSize.cgRectValue.height
            if self.view.frame.origin.y == 0 {
                // We need to offset in this case because the popup is contrained to the bottom of the view
                self.view.frame.origin.y -=  AppState.keyboardHeight
            }
        }
    }
    
    @objc func keyboardWillHide(notif: Notification) {
        self.view.frame.origin.y = 0
    }
    
    @objc func optionPickerShouldReload(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let action = info[Const.optionDataActionKey] as? OptionDataAction {
            if action == .add, let data = info[Const.optionModelKey] as? ERequestMethodData, let name = data.name {
                if !self.data.contains(name) {
                    self.data.append(name)
                    self.modelxs.append(data)
                }
            } else if action == .delete, let id = info[Const.dataKey] as? String {
                if let idx = (self.modelxs.firstIndex(where: { x -> Bool in
                    if let y = x as? ERequestMethodData { return y.id == id }
                    return false
                })) {
                    self.modelxs.remove(at: idx)
                    self.data.remove(at: idx)
                }
            }
        }
        self.tableView.reloadData()
    }
    
    @objc func footerDidTap() {
        Log.debug("footer did tap")
        self.app.viewPopup(type: .requestMethod, delegate: self, parentView: self.view, bottomView: self.view, vc: self)
    }
    
    @IBAction func cancelButtonDidTap() {
        Log.debug("cancel button did tap")
        self.close(true)
    }
    
    func close(_ isCancel: Bool) {
        if !isCancel {
            if self.pickerType == .requestMethod {
                self.nc.post(name: NotificationKey.requestMethodDidChange, object: self,
                             userInfo: [Const.optionSelectedIndexKey: self.selectedIndex, Const.modelIndexKey: self.modelIndex,
                                        Const.requestMethodNameKey: self.data[self.selectedIndex]])
            } else if self.pickerType == .requestBodyFormField {
                self.nc.post(name: NotificationKey.requestBodyFormFieldTypeDidChange, object: self,
                             userInfo: [Const.optionSelectedIndexKey: self.selectedIndex, Const.modelIndexKey: self.modelIndex,
                                        Const.optionModelKey: self.model as Any])
            } else if self.pickerType == .requestBodyForm {
                self.nc.post(name: NotificationKey.requestBodyTypeDidChange, object: self,
                             userInfo: [Const.optionSelectedIndexKey: self.selectedIndex, Const.modelIndexKey: self.modelIndex])
            }
        }
        // self.optionsDelegate?.reloadOptionsData()
        self.dismiss(animated: true, completion: nil)
    }
    
    func postRequestMethodChangeNotification(_ row: Int) {
        self.nc.post(name: NotificationKey.requestMethodDidChange, object: self,
                     userInfo: [Const.requestMethodNameKey: self.data[row], Const.modelIndexKey: row])
    }
    
    func postRequestBodyChangeNotification(_ row: Int) {
        self.nc.post(name: NotificationKey.requestBodyTypeDidChange, object: self,
                     userInfo: [Const.optionSelectedIndexKey: row,
                                Const.modelIndexKey: self.modelIndex])
    }
    
    func postRequestBodyFieldChangeNotification(_ row: Int) {
        self.nc.post(name: NotificationKey.requestBodyFormFieldTypeDidChange, object: self,
                     userInfo: [Const.optionSelectedIndexKey: row,
                                Const.modelIndexKey: self.modelIndex])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "optionsCell", for: indexPath) as! OptionsTableViewCell
        let row = indexPath.row
        let elem = self.data[row]
        cell.titleLabel.text = elem
        if row == self.selectedIndex {
            cell.selectCell()
        } else {
            cell.deselectCell()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("option vc did select \(indexPath)")
        let row = indexPath.row
        self.selectedIndex = row
        if self.pickerType == .requestBodyForm {
            self.postRequestBodyChangeNotification(row)
        } else if self.pickerType == .requestMethod {
            self.postRequestMethodChangeNotification(row)
        } else if self.pickerType == .requestBodyFormField {
            self.postRequestBodyFieldChangeNotification(row)
        }
        self.close(false)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let row = indexPath.row
        if self.pickerType == .requestMethod {
            if self.modelxs.count > row {
                return (self.modelxs[row] as? ERequestMethodData)?.isCustom ?? false
            }
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            if self.pickerType == .requestMethod {
                let row = indexPath.row
                if self.selectedIndex == row {  // The selected index is being deleted. So assign selected to the first item.
                    self.selectedIndex = 0
                    self.postRequestMethodChangeNotification(0)
                }
                self.nc.post(name: NotificationKey.customRequestMethodShouldDelete, object: self,
                             userInfo: [Const.optionModelKey: self.modelxs[row], Const.indexKey: row])
            }
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
}

class OptionsTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func selectCell() {
        self.accessoryType = .checkmark
    }
    
    func deselectCell() {
        self.accessoryType = .none
    }
}

extension OptionsPickerViewController: PopupViewDelegate {
    func cancelDidTap(_ sender: Any) {
        self.app.addItemPopupView?.animateSlideOut()
    }
    
    func doneDidTap(name: String, desc: String) -> Bool {
        if self.pickerType == .requestMethod {
            if self.validateText(name) {
                self.nc.post(name: NotificationKey.customRequestMethodDidAdd, object: self,
                             userInfo: [Const.requestMethodNameKey: name, Const.modelIndexKey: self.data.count])
            }
        }
        self.app.addItemPopupView?.animateSlideOut()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        return true
    }
    
    func validateText(_ text: String?) -> Bool {
        guard let text = text else {
            self.app.addItemPopupView?.viewValidationError("Please enter a name")
            self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
            return false
        }
        if text.isEmpty {
            self.app.addItemPopupView?.viewValidationError("Please enter a name")
            self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
            return false
        }
        if text.trimmingCharacters(in: .whitespaces) == "" {
            self.app.addItemPopupView?.viewValidationError("Please enter a valid name")
            self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
            return false
        }
        if self.pickerType == .requestMethod {
            if (self.data.first { x -> Bool in x == text }) != nil {
                self.app.addItemPopupView?.viewValidationError("Method already exists")
                self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
                return false
            }
        }
        self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: false)
        return true
    }
    
    func popupStateDidChange(isErrorMode: Bool) {
        self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: isErrorMode)
    }
}
