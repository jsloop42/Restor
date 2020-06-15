//
//  EnvironmentEditViewController.swift
//  Restor
//
//  Created by jsloop on 15/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let envEditCellTextDidChange = Notification.Name("env-edit-cell-text-did-change")
    static let envEditCellGetVCMode = Notification.Name("env-edit-cell-get-vc-mode")
    static let envEditVCMode = Notification.Name("env-edit-vc-mode")
}

class EnvEditCell: UITableViewCell, UITextFieldDelegate {
    @IBOutlet weak var textField: EATextField!
    private let nc = NotificationCenter.default
    var mode: EnvironmentEditViewController.Mode = .addEnv
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.textField.isColor = false
        self.textField.delegate = self
    }
    
    func initEvents() {
        self.textField.addTarget(self, action: #selector(EnvEditCell.textFieldDidChange(_:)), for: .editingChanged)
    }
    
    func updateUI() {
        switch self.mode {
        case .addEnv, .addEnvVar:
            self.textField.isUserInteractionEnabled = true
        case .editEnv, .editEnvVar:
            self.textField.isUserInteractionEnabled = true
        case .viewEnv, .viewEnvVar:
            self.textField.isUserInteractionEnabled = false
        }
    }
    
    @objc func textFieldDidChange(_ sender: Any) {
        Log.debug("text field did change")
        self.nc.post(name: .envEditCellTextDidChange, object: self, userInfo: ["text": self.textField.text ?? ""])
    }
}

class EnvironmentEditViewController: UITableViewController {
    @IBOutlet weak var nameCell: EnvEditCell!
    @IBOutlet weak var valueCell: EnvEditCell!
    var mode: Mode = .addEnv
    private let localDB = CoreDataService.shared
    lazy var doneBtn: UIButton = {
        let btn = UI.getNavbarTopDoneButton()
        btn.addTarget(self, action: #selector(self.doneDidTap), for: .touchUpInside)
        return btn
    }()
    lazy var editBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Edit", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        btn.addTarget(self, action: #selector(self.editDidTap), for: .touchUpInside)
        return btn
    }()
    lazy var cancelBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        btn.addTarget(self, action: #selector(self.cancelDidTap), for: .touchUpInside)
        return btn
    }()
    private let app = App.shared
    private let nc = NotificationCenter.default
    var name = ""
    var value = ""
    var backBtnItem: UIBarButtonItem?
    var env: EEnv?
    
    deinit {
        Log.debug("deinit EnvironmentEditViewController")
        self.nc.removeObserver(self)
    }
    
    enum Mode {
        case addEnv
        case editEnv
        case viewEnv
        case addEnvVar
        case editEnvVar
        case viewEnvVar
    }
    
    enum CellId: Int {
        case nameTitleCell
        case nameCell
        case valueTitleCell
        case valueCell
        case spacerCell
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("env edit vc")
        self.initUI()
        self.initEvents()
    }
    
    override func shouldPopOnBackButton() -> Bool {
        if self.mode == .editEnv || self.mode == .editEnvVar { return false }
        return true
    }
    
    override func willMove(toParent parent: UIViewController?) {
        Log.debug("will move")
        if parent == nil { // When the user swipe to back, the parent is nil
            return
        }
        super.willMove(toParent: parent)
    }
    
    func initUI() {
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.app.updateViewBackground(self.view)
        self.view.backgroundColor = App.Color.tableViewBg
        switch self.mode {
        case .addEnv:
            self.navigationItem.title = "Add Environment"
        case .editEnv:
            self.navigationItem.title = "Edit Environment"
        case .viewEnv:
            self.navigationItem.title = ""
        case .addEnvVar:
            self.navigationItem.title = "Add a Variable"
        case .editEnvVar:
            self.navigationItem.title = "Edit a Variable"
        case .viewEnvVar:
            self.navigationItem.title = ""
        }
        if self.mode != .viewEnv && self.mode != .viewEnvVar {
            self.addNavigationBarDoneButton()
        } else {
            self.addNavigationBarEditButton()
        }
        self.backBtnItem = self.navigationItem.leftBarButtonItem
    }
    
    /// Add a done button to nav bar right
    func addNavigationBarDoneButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.doneBtn)
        self.disableDoneButton()
    }
    
    /// Add a done button to nav bar right
    func addNavigationBarEditButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.editBtn)
    }
    
    func close() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func doneDidTap(_ sender: Any) {
        Log.debug("done btn did tap")
        DispatchQueue.main.async {
            if self.mode == .addEnv || self.mode == .addEnvVar {
                _ = self.localDB.createEnv(name: self.name)
            } else {
                if self.mode == .editEnv {
                    self.mode = .viewEnv
                } else if self.mode == .editEnvVar {
                    self.mode = .viewEnvVar
                }
                self.env?.name = self.name
                self.nameCell.mode = self.mode
                self.valueCell.mode = self.mode
                self.nameCell.updateUI()
                self.valueCell.updateUI()
                self.tableView.reloadData()
            }
            self.localDB.saveMainContext()
            if self.mode == .addEnv || self.mode == .addEnvVar {
                self.close()
            } else {
                self.updateCancelToBackButton()
                self.addNavigationBarEditButton()
            }
        }
    }
    
    @objc func editDidTap(_ sender: Any) {
        Log.debug("edit did tap")
        self.addNavigationBarDoneButton()
        self.updateBackButtonToCancel()
        if self.mode == .viewEnv {
            self.mode = .editEnv
        } else if self.mode == .viewEnvVar {
            self.mode = .editEnvVar
        }
        self.nameCell.mode = self.mode
        self.valueCell.mode = self.mode
        self.nameCell.updateUI()
        if self.mode == .viewEnvVar || self.mode == .addEnvVar || self.mode == .editEnvVar {
            self.valueCell.updateUI()
        }
        self.tableView.reloadData()
    }
    
    @objc func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        if self.mode == .editEnv {
            self.mode = .viewEnv
        } else if self.mode == .editEnvVar {
            self.mode = .viewEnvVar
        }
        self.updateCancelToBackButton()
        UIView.animate(withDuration: 0.3) {
            self.addNavigationBarEditButton()
        }
    }
    
    func updateCancelToBackButton() {
        UI.endEditing()
        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.backBarButtonItem = self.backBtnItem
    }
    
    func updateBackButtonToCancel() {
        self.navigationItem.backBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: self.cancelBtn)
    }
    
    func enableDoneButton() {
        UIView.animate(withDuration: 0.3) {
            self.doneBtn.setTitleColor(self.doneBtn.tintColor, for: .normal)
            self.doneBtn.isEnabled = true
        }
    }
    
    func disableDoneButton() {
        UIView.animate(withDuration: 0.3) {
            self.doneBtn.setTitleColor(App.Color.requestEditDoneBtnDisabled, for: .normal)
            self.doneBtn.isEnabled = false
        }
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.envEditCellTextDidChange(_:)), name: .envEditCellTextDidChange, object: nil)
    }
    
    func initData() {
        
    }
    
    func updateUI() {
        if self.mode == .viewEnv || self.mode == .editEnv {
            self.nameCell.textField.text = self.env != nil ? self.env!.name : self.name
        }
        self.nameCell.mode = self.mode
        self.valueCell.mode = self.mode
        self.nameCell.updateUI()
        if self.mode == .viewEnvVar || self.mode == .addEnvVar || self.mode == .editEnvVar {
            self.valueCell.updateUI()
        }
    }
    
    @objc func envEditCellTextDidChange(_ notif: Notification) {
        Log.debug("env edit cell text did change notification")
        if let info = notif.userInfo as? [String: String], let text = info["text"] {
            if text.trim().isEmpty {
                self.name = ""
                self.disableDoneButton()
                return
            }
            self.name = text  // TODO: handle value
            self.enableDoneButton()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.mode {
        case .addEnv, .editEnv, .viewEnv:
            return 3
        case .addEnvVar, .editEnvVar, .viewEnvVar:
            return 5
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        switch self.mode {
        case .addEnv, .editEnv, .viewEnv:
            if row == CellId.nameTitleCell.rawValue || row == CellId.nameCell.rawValue {
                return 44
            }
        case .addEnvVar, .editEnvVar, .viewEnvVar:
            if row == CellId.nameTitleCell.rawValue || row == CellId.nameCell.rawValue {
                return 44
            }
            if row == CellId.valueTitleCell.rawValue || row == CellId.valueCell.rawValue {
                return 44
            }
        }
        if row == CellId.spacerCell.rawValue {
            return 24
        }
        return 0
    }
}
