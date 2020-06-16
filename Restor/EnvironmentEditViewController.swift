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
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueCell: EnvEditCell!
    @IBOutlet weak var doneBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    var mode: Mode = .addEnv
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
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
        case navViewCell
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
    
    func initUI() {
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.app.updateViewBackground(self.view)
        self.view.backgroundColor = App.Color.tableViewBg
        switch self.mode {
        case .addEnv:
            self.titleLabel.text = "Add Environment"
        case .editEnv:
            self.titleLabel.text = "Edit Environment"
        case .viewEnv:
            self.titleLabel.text = ""
        case .addEnvVar:
            self.titleLabel.text = "Add Variable"
        case .editEnvVar:
            self.titleLabel.text = "Edit Variable"
        case .viewEnvVar:
            self.titleLabel.text = ""
        }
        self.disableDoneButton()
    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func doneDidTap(_ sender: Any) {
        Log.debug("done btn did tap")
        if self.mode == .addEnv || self.mode == .addEnvVar {
            self.env = self.localDB.createEnv(name: self.name)
        } else {
            self.env?.name = self.name
            // TODO: handle value
        }
        self.localDB.saveMainContext()
        if let x = self.env { self.db.saveEnvToCloud(x) }
        self.close()
    }
    
    @objc func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        self.close()
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
        self.doneBtn.addTarget(self, action: #selector(self.doneDidTap(_:)), for: .touchDown)
        self.cancelBtn.addTarget(self, action: #selector(self.cancelDidTap(_:)), for: .touchDown)
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
            if let name = self.env?.name, name == text {  // same as existing name
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
            return 4
        case .addEnvVar, .editEnvVar, .viewEnvVar:
            return 6
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        switch self.mode {
        case .addEnv, .editEnv, .viewEnv:
            if row == CellId.navViewCell.rawValue || row == CellId.nameTitleCell.rawValue || row == CellId.nameCell.rawValue {
                return 44
            }
        case .addEnvVar, .editEnvVar, .viewEnvVar:
            if row == CellId.navViewCell.rawValue || row == CellId.nameTitleCell.rawValue || row == CellId.nameCell.rawValue {
                return 44
            }
            if row == CellId.navViewCell.rawValue || row == CellId.valueTitleCell.rawValue || row == CellId.valueCell.rawValue {
                return 44
            }
        }
        if row == CellId.spacerCell.rawValue {
            return 24
        }
        return 0
    }
}
