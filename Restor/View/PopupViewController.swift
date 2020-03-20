//
//  PopupViewController.swift
//  Restor
//
//  Created by jsloop on 20/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

struct PopupModel {
    var title: String
}

class PopupCell: UITableViewCell {
    @IBOutlet weak var nameView: UIView!
    @IBOutlet weak var descView: UIView!
    @IBOutlet weak var syncView: UIView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var descTextField: UITextField!
    @IBOutlet weak var iCloudSyncSwitch: UISwitch!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

class PopupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var navbarView: UIView!
    @IBOutlet weak var doneBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var tableView: UITableView!
    var model: PopupModel?
    
    enum CellId: Int {
        case nameText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
    }
    
    func initUI() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        if #available(iOS 13.0, *) { self.isModalInPresentation = true }  // Prevent dismissing popup by swiping down
        self.doneBtn.isEnabled = false
        // End editing on view tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func endEditing() {
        UI.endEditing()
    }
    
    @IBAction func cancelButtonDidTap(_ sender: Any) {
        self.close()
    }
    
    @IBAction func doneButtonDidTap(_ sender: Any) {
        self.close()
    }
    
    func initCellEvents(_ cell: PopupCell) {
        cell.nameTextField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
    }
        
    @objc func textFieldDidChange(_ textField: UITextField) {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.doneBtn.isEnabled = !text.isEmpty
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "popupCell", for: indexPath) as! PopupCell
        self.initCellEvents(cell)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 206
    }
}
