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
    private var isPopupActive = false
    private let localdb = CoreDataService.shared
    
    deinit {
        Log.debug("option picker vc deinit")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch self.pickerType {
        case .requestBodyForm:
            AppState.setCurrentScreen(.requestBodyFormTypeList)
        case .requestBodyFormField:
            AppState.setCurrentScreen(.requestBodyFormTypeList)
        case .requestMethod:
            AppState.setCurrentScreen(.requestMethodList)
        }
        self.isPopupActive = false
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
        self.nc.addObserver(self, selector: #selector(self.optionPickerShouldReload(_:)), name: .optionPickerShouldReload, object: nil)
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
        Log.debug("option picker should reload")
        if let info = notif.userInfo as? [String: Any], let action = info[Const.optionDataActionKey] as? OptionDataAction {
            if action == .add, let data = info[Const.optionModelKey] as? ERequestMethodData, let name = data.name {
                if !self.data.contains(name) {
                    self.data.append(name)
                    self.modelxs.append(data)
                    self.cancelBtn.setTitle("Done", for: .normal)
                }
            } else if action == .delete, let id = info[Const.dataKey] as? String {
                if let idx = (self.modelxs.firstIndex(where: { x -> Bool in
                    if let y = x as? ERequestMethodData { return y.id == id }
                    return false
                })) {
                    self.modelxs.remove(at: idx)
                    self.data.remove(at: idx)
                    self.selectedIndex = info[Const.optionSelectedIndexKey] as? Int ?? 0
                    self.cancelBtn.setTitle("Done", for: .normal)
                }
            }
        }
        self.tableView.reloadData()
    }
    
    /// Add custom request method
    @objc func footerDidTap() {
        Log.debug("footer did tap")
        if !self.isPopupActive {
            self.isPopupActive = true
            self.app.viewPopupScreen(self, model: PopupModel(title: "New Method", helpText: Const.helpTextForAddNewRequestMethod, descFieldEnabled: false,
                                                             shouldValidate: true, shouldDisplayHelp: true, doneHandler: { model in
                Log.debug("model: \(model)")
                self.isPopupActive = false
                self.nc.post(name: .customRequestMethodDidAdd, object: self, userInfo: [Const.requestMethodNameKey: model.name, Const.modelIndexKey: self.data.count])
            }, validateHandler: { model in
                if model.name.trim().isEmpty { return false }
                return self.data.first { x -> Bool in x == model.name } == nil
            }), completion: {
                self.isPopupActive = false
            })
            self.isPopupActive = true
        }
    }
    
    @IBAction func cancelButtonDidTap() {
        Log.debug("cancel button did tap")
        self.close(true)
    }
    
    func close(_ isCancel: Bool) {
        if !isCancel {
            if self.pickerType == .requestMethod {
                self.postRequestMethodChangeNotification()
            } else if self.pickerType == .requestBodyFormField {
                self.postRequestBodyFieldChangeNotification()
            } else if self.pickerType == .requestBodyForm {
                self.postRequestBodyChangeNotification()
            }
        } else {
            if self.pickerType == .requestMethod {
                self.postRequestMethodChangeNotification()
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    func postRequestMethodChangeNotification() {
        if self.data.isEmpty { return }
        self.nc.post(name: .requestMethodDidChange, object: self,
                     userInfo: [Const.optionSelectedIndexKey: self.selectedIndex, Const.modelIndexKey: self.modelIndex,
                                Const.requestMethodNameKey: self.data[self.selectedIndex]])
    }
    
    func postRequestBodyChangeNotification() {
        self.nc.post(name: .requestBodyTypeDidChange, object: self,
                     userInfo: [Const.optionSelectedIndexKey: self.selectedIndex, Const.modelIndexKey: self.modelIndex])
    }
    
    func postRequestBodyFieldChangeNotification() {
        self.nc.post(name: .requestBodyFormFieldTypeDidChange, object: self,
                     userInfo: [Const.optionSelectedIndexKey: self.selectedIndex, Const.modelIndexKey: self.modelIndex,
                                Const.optionModelKey: self.model as Any])
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
            self.postRequestBodyChangeNotification()
        } else if self.pickerType == .requestMethod {
            self.postRequestMethodChangeNotification()
        } else if self.pickerType == .requestBodyFormField {
            self.postRequestBodyFieldChangeNotification()
        }
        self.close(false)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let row = indexPath.row
        if self.pickerType == .requestMethod {
            if self.modelxs.count > row {
                if AppState.editRequest?.project == nil { return false }
                return (self.modelxs[row] as? ERequestMethodData)?.isCustom ?? false
            }
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let row = indexPath.row
        let elem = self.modelxs[row] as? ERequestMethodData
        let projId = AppState.editRequest!.project!.getId()
        let count = self.localdb.getRequestsCountForRequestMethodData(projId: projId, ctx: elem?.managedObjectContext)
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            if count > 0, let name = elem?.name {
                UI.viewAlert(vc: self, title: "Delete \"HEAD\"?",
                             message: "\"\(name)\" is associated with \(count) other \(count > 1 ? "requests" : "request"). Deleting this will reset it to \"GET\".",
                             cancelText: "Cancel", otherButtonText: "Delete", cancelStyle: .cancel, otherStyle: .destructive,
                             cancelCallback: { completion(true) },
                             otherCallback: { self.deleteRequestDataMethod(row); completion(true) })
            } else {
                self.deleteRequestDataMethod(row)
                completion(true)
            }
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
    
    func deleteRequestDataMethod(_ index: Int) {
        if self.pickerType == .requestMethod {
            if self.selectedIndex == index {  // The selected index is being deleted. So assign selected to the first item.
                self.selectedIndex = 0
                self.postRequestMethodChangeNotification()
            }
            self.nc.post(name: .customRequestMethodShouldDelete, object: self,
                         userInfo: [Const.optionModelKey: self.modelxs[index], Const.indexKey: index])
        }
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
