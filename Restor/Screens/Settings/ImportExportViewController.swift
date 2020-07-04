//
//  ImportExportViewController.swift
//  Restor
//
//  Created by jsloop on 30/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class ImportExportViewController: UIViewController {
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var actionBtn: UIButton!
    @IBOutlet weak var textView: EATextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var titleLabel: UILabel!
    var mode: Mode = .import
    private lazy var app = { App.shared }()
    private lazy var localDB = { CoreDataService.shared }()
    private var isOpInProgress = false
    
    enum Mode {
        case `import`
        case export
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.textView.isEditable = self.mode == .import
        self.textView.font = App.Font.monospace14
        self.updateUI()
    }
    
    func updateUI() {
        if self.mode == .import {
            self.titleLabel.text = "Import Data"
            if self.textView.text.isEmpty { self.textView.placeholder = "Paste exported JSON data" }
            self.actionBtn.setTitle("Import", for: .normal)
        } else if self.mode == .export {
            self.titleLabel.text = "Export Data"
            if self.textView.text.isEmpty {
                self.textView.placeholder = "Tap export to generate the JSON data"
                self.actionBtn.setTitle("Export", for: .normal)
            } else {
                self.actionBtn.setTitle("Copy", for: .normal)
            }
        }
        if self.isOpInProgress {
            self.cancelBtn.isEnabled = false
            self.displayActivityIndicator()
        } else {
            self.cancelBtn.isEnabled = true
            self.hideActivityIndicator()
        }
    }
    
    func displayActivityIndicator() {
        UIView.animate(withDuration: 0.3) {
            self.actionBtn.isHidden = true
            self.activityIndicator.isHidden = false
            self.activityIndicator.startAnimating()
        }
    }
    
    func hideActivityIndicator() {
        UIView.animate(withDuration: 0.3) {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.actionBtn.isHidden = false
        }
    }
    
    func initEvents() {
        self.actionBtn.addTarget(self, action: #selector(self.actionButtonDidTap(_:)), for: .touchUpInside)
        self.cancelBtn.addTarget(self, action: #selector(self.cancelButtonDidTap(_:)), for: .touchUpInside)
    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func cancelButtonDidTap(_ sender: Any) {
        Log.debug("cancel button did tap")
        if !self.isOpInProgress {
            self.close()
        }
    }
    
    @objc func actionButtonDidTap(_ sender: Any) {
        Log.debug("action button did tap")
        if self.mode == .import {  // import button tapped
            guard let text = self.textView.text, !text.isEmpty else { return }
            // if valid JSON, parse it into dict
            self.isOpInProgress = true
            if let data = text.data(using: .utf8), let xs = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: Any]] {
                xs.forEach { dict in
                    if let _ = EWorkspace.fromDictionary(dict) {
                        self.localDB.saveMainContext()
                    }
                }
                self.isOpInProgress = false
                UI.viewToast("Workspaces imported successfully", hideSec: 2, vc: self, completion: {
                    self.cancelBtn.setTitle("Done", for: .normal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.close()
                    }
                })
            }
        } else if self.mode == .export {
            if self.textView.text.isEmpty {  // export JSON
                self.isOpInProgress = true
                let wsxs = self.localDB.getAllWorkspaces()
                var acc: [[String: Any]] = [] // list of workspaces
                wsxs.forEach { ws in
                    acc.append(ws.toDictionary())
                }
                if let data = try? JSONSerialization.data(withJSONObject: acc, options: .fragmentsAllowed), let json = String(data: data, encoding: .utf8) {
                    self.textView.text = json
                    self.isOpInProgress = false
                    self.updateUI()
                }
            } else {  // copy to clipboard
                UIPasteboard.general.string = self.textView.text!
                UI.viewToast("Copied to clipboard", hideSec: 2, vc: self)
                self.cancelBtn.setTitle("Done", for: .normal)
                self.isOpInProgress = false
            }
        }
    }
}
