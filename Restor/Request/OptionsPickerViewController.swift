//
//  OptionsPickerViewController.swift
//  Restor
//
//  Created by jsloop on 08/02/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

protocol OptionsPickerViewDelegate: class {
    func optionDidSelect(_ row: Int)
    func reloadOptionsData()
}

enum OptionPickerType {
    case requestBodyForm
    case requestMethod
}

class OptionsPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    weak var optionsDelegate: OptionsPickerViewDelegate?
    private let app = App.shared
    var pickerType: OptionPickerType = .requestBodyForm
    private let nc = NotificationCenter.default
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerLabel: UILabel!
    
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
        self.optionsDelegate = nil
        self.nc.removeObserver(self)
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.titleLabel.text = OptionsPickerState.title
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
    
    @objc func footerDidTap() {
        Log.debug("footer did tap")
        self.app.viewPopup(type: .requestMethod, delegate: self, parentView: self.view, bottomView: self.view, vc: self)
    }
    
    @IBAction func cancelButtonDidTap() {
        Log.debug("cancel button did tap")
        self.close()
    }
    
    func close() {
        if self.pickerType == .requestMethod {
            RequestVC.state.methods = OptionsPickerState.requestData
            RequestVC.state.selectedMethodIndex = OptionsPickerState.selected
        }
        self.optionsDelegate?.reloadOptionsData()
        self.dismiss(animated: true, completion: nil)
    }
    
    func postRequestMethodChangeNotification(_ row: Int) {
        self.nc.post(name: NotificationKey.requestMethodDidChange, object: self,
                     userInfo: [Const.requestMethodNameKey: OptionsPickerState.requestData[row].name, Const.optionSelectedIndexKey: row])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.pickerType == .requestMethod { return OptionsPickerState.requestData.count }
        return OptionsPickerState.data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "optionsCell", for: indexPath) as! OptionsTableViewCell
        let row = indexPath.row
        let data: String = {
            if self.pickerType == .requestMethod {
                return OptionsPickerState.requestData[row].name
            }
            return OptionsPickerState.data[row]
        }()
        cell.titleLabel.text = data
        if row == OptionsPickerState.selected {
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
        if self.pickerType == .requestBodyForm {
            OptionsPickerState.selected = row
            self.optionsDelegate?.optionDidSelect(row)
        } else if self.pickerType == .requestMethod {
            if OptionsPickerState.requestData.count > row {
                self.postRequestMethodChangeNotification(row)
            }
        }
        self.close()
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if self.pickerType == .requestMethod {
            return OptionsPickerState.requestData[indexPath.row].isCustom
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            if self.pickerType == .requestMethod {
                let row = indexPath.row
                if OptionsPickerState.selected == row {
                    OptionsPickerState.selected = 0
                    self.postRequestMethodChangeNotification(0)
                }
                OptionsPickerState.requestData.remove(at: row)
                self.tableView.reloadData()
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
    
    func doneDidTap(_ text: String?) -> Bool {
        if self.pickerType == .requestMethod, let txt = text {
            OptionsPickerState.requestData.append(RequestMethodData(name: txt, isCustom: true, project: AppState.currentProject))
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
            if (OptionsPickerState.requestData.first { data -> Bool in data.name == text }) != nil {
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
