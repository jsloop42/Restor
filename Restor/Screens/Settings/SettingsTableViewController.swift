//
//  SettingsTableViewController.swift
//  Restor
//
//  Created by jsloop on 18/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import StoreKit
import MessageUI

class SettingsTableViewController: RestorTableViewController {
    private let app = App.shared
    @IBOutlet weak var saveHistorySwitch: UISwitch!
    @IBOutlet weak var syncWorkspaceSwitch: UISwitch!
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
    private lazy var workspace = { self.app.getSelectedWorkspace() }()
    @IBOutlet weak var aboutTitle: UILabel!
    private lazy var utils = { EAUtils.shared }()
    
    enum CellId: Int {
        case spacerAfterTop
        case workspaceGroup
        case spacerAfterWorkspace
        case syncWorkspace
        case saveHistory
        case spacerAfterSaveHistory
        case toolsTitle
        case base64
        case spacerAfterTools
        case importData
        case exportData
        case spaceAfterExportData
        case rate
        case feedback
        case share
        case spacerAfterShare
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.settings)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("settings tv view did load")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.tableView.backgroundColor = App.Color.tableViewBg
        self.navigationItem.title = "Settings"
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.saveHistorySwitch.isOn = self.workspace.saveResponse
        self.syncWorkspaceSwitch.isOn = self.workspace.isSyncEnabled
        self.updateAbout()
    }
    
    func updateAbout() {
        let version = self.utils.appVersion() ?? ""
        let co = "by EstoApps OÜ"
        self.aboutTitle.text = version.isEmpty ? "Restor \(co)" : "Restor v\(version) \(co)"
    }
    
    func initEvents() {
        self.saveHistorySwitch.addTarget(self, action: #selector(self.saveHistorySwitchDidChange(_:)), for: .valueChanged)
        self.syncWorkspaceSwitch.addTarget(self, action: #selector(self.syncWorkspaceSwitchDidChange(_:)), for: .valueChanged)
    }
    
    func rateApp() {
        if #available(iOS 10.3, *) {
            SKStoreReviewController.requestReview()
        } else if let url = URL(string: "itms-apps://itunes.apple.com/app/" + Const.appId) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([Const.feedbackEmail])
            mail.setSubject("Restor Feedback")
            if let version = self.utils.appVersion() {
                mail.setMessageBody("<br /><p>App version: v\(version)</p>", isHTML: true)
            }
            self.present(mail, animated: true)
        } else {
            UI.viewToast("Unable to compose e-mail. Please send your feedback to \(Const.feedbackEmail).", vc: self)
        }
    }
    
    func shareLink() {
        if let url = URL(string: Const.appURL), let image = UIImage(named: "restor-icon") {
            let objectsToShare: [Any] = ["Restor - API endpoint testing on the go", url, image]
            let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let popup = activityVC.popoverPresentationController {
                    popup.sourceView = self.view
                    popup.sourceRect = CGRect(x: self.view.frame.size.width / 2, y: self.view.frame.size.height / 4, width: 0, height: 0)
                }
            }
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    @objc func syncWorkspaceSwitchDidChange(_ sender: UISwitch) {
        Log.debug("sync workspace switch did change")
        self.workspace.isSyncEnabled = self.syncWorkspaceSwitch.isOn
        self.localDB.saveMainContext()
        self.db.saveWorkspaceToCloud(self.workspace)
        if self.workspace.isSyncEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {  // sync any pending changes
                self.db.syncToCloud()
            }
        }
    }
    
    @objc func saveHistorySwitchDidChange(_ sender: UISwitch) {
        Log.debug("save history switch did change")
        self.workspace.saveResponse = self.saveHistorySwitch.isOn
        self.localDB.saveMainContext()
        self.db.saveWorkspaceToCloud(self.workspace)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == CellId.workspaceGroup.rawValue {
            UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.environmentGroupVC.rawValue)
        } else if indexPath.row == CellId.base64.rawValue {
            UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.base64VC.rawValue)
        } else if indexPath.row == CellId.importData.rawValue {
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.importExportVC.rawValue) as? ImportExportViewController {
                vc.mode = .import
                self.navigationController?.present(vc, animated: true, completion: nil)
            }
        } else if indexPath.row == CellId.exportData.rawValue {
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.importExportVC.rawValue) as? ImportExportViewController {
                vc.mode = .export
                self.navigationController?.present(vc, animated: true, completion: nil)
            }
        } else if indexPath.row == CellId.rate.rawValue {
            self.rateApp()
        } else if indexPath.row == CellId.feedback.rawValue {
            self.sendFeedback()
        } else if indexPath.row == CellId.share.rawValue {
            self.shareLink()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case CellId.spacerAfterTop.rawValue:
            return 36
        case CellId.workspaceGroup.rawValue:
            return 44
        case CellId.spacerAfterWorkspace.rawValue:
            return 24
        case CellId.syncWorkspace.rawValue:
            return 44
        case CellId.saveHistory.rawValue:
            return 44
        case CellId.spacerAfterSaveHistory.rawValue:
            return 24
        case CellId.toolsTitle.rawValue:
            return 24
        case CellId.base64.rawValue:
            return 44
        case CellId.spacerAfterTools.rawValue:
            return 24
        case CellId.importData.rawValue:
            return 44
        case CellId.exportData.rawValue:
            return 44
        case CellId.spaceAfterExportData.rawValue:
            return 24
        case CellId.rate.rawValue:
            return 44
        case CellId.feedback.rawValue:
            return 44
        case CellId.share.rawValue:
            return 44
        case CellId.spacerAfterShare.rawValue:
            return 50
        default:
            break
        }
        return UITableView.automaticDimension
    }
}

extension SettingsTableViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
