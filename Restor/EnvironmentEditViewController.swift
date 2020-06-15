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
}

class EnvEditCell: UITableViewCell, UITextFieldDelegate {
    @IBOutlet weak var textField: EATextField!
    private let nc = NotificationCenter.default
    
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
    
    @objc func textFieldDidChange(_ sender: Any) {
        Log.debug("text field did change")
        self.nc.post(name: .envEditCellTextDidChange, object: self, userInfo: ["text": self.textField.text ?? ""])
    }
}

class EnvironmentEditViewController: UITableViewController {
    var mode: Mode = .addEnv
    private let localDB = CoreDataService.shared
    lazy var doneBtn: UIButton = {
        let btn = UI.getNavbarTopDoneButton()
        btn.addTarget(self, action: #selector(self.doneDidTap), for: .touchUpInside)
        return btn
    }()
    private let nc = NotificationCenter.default
    var envName = ""
    
    deinit {
        Log.debug("deinit EnvironmentEditViewController")
        self.nc.removeObserver(self)
    }
    
    enum Mode {
        case addEnv
        case editEnv
        case addEnvVar
        case editEnvVar
    }
    
    enum CellId: Int {
        case nameTitleCell
        case nameCell
        case valueTitleCell
        case valueCell
        case spacerCell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("env edit vc")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        switch self.mode {
        case .addEnv:
            self.navigationItem.title = "Add Environment"
        case .editEnv:
            self.navigationItem.title = "Edit Environment"
        case .addEnvVar:
            self.navigationItem.title = "Add a Variable"
        case .editEnvVar:
            self.navigationItem.title = "Edit a Variable"
        }
        self.addNavigationBarDoneButton()
    }
    
    /// Add a back button with custom image for navigation bar back button
    func addNavigationBarDoneButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.doneBtn)
        self.disableDoneButton()
    }
    
    func close() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func doneDidTap(_ sender: Any) {
        Log.debug("done btn did tap")
        DispatchQueue.main.async {
            if self.envName.isEmpty { self.disableDoneButton(); return }
            _ = self.localDB.createEnv(name: self.envName)
            self.localDB.saveMainContext()
            self.close()
        }
    }
    
    func enableDoneButton() {
        self.doneBtn.setTitleColor(self.doneBtn.tintColor, for: .normal)
        self.doneBtn.isEnabled = true
    }
    
    func disableDoneButton() {
        self.doneBtn.setTitleColor(App.Color.requestEditDoneBtnDisabled, for: .normal)
        self.doneBtn.isEnabled = false
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.envEditCellTextDidChange(_:)), name: .envEditCellTextDidChange, object: nil)
    }
    
    func initData() {
        
    }
    
    func updateUI() {
        
    }
    
    @objc func envEditCellTextDidChange(_ notif: Notification) {
        Log.debug("env edit cell text did change notification")
        if let info = notif.userInfo as? [String: String], let text = info["text"] {
            if text.trim().isEmpty {
                self.envName = ""
                self.disableDoneButton()
                return
            }
            self.envName = text
            self.enableDoneButton()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.mode {
        case .addEnv, .editEnv:
            return 3
        case .addEnvVar, .editEnvVar:
            return 5
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        switch self.mode {
        case .addEnv, .editEnv:
            if row == CellId.nameTitleCell.rawValue || row == CellId.nameCell.rawValue {
                return 44
            }
        case .addEnvVar, .editEnvVar:
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
