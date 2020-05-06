//
//  RequestTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestTableViewController: UITableViewController {
    private let app = App.shared
    private let localdb = CoreDataService.shared
    var request: ERequest?
    private var tabbarController: RequestTabBarController { self.tabBarController as! RequestTabBarController }
    @IBOutlet var headerKVTableViewManager: KVTableViewManager!
    @IBOutlet var paramsKVTableViewManager: KVTableViewManager!
    @IBOutlet var bodyKVTableViewManager: KVTableViewManager!
    @IBOutlet weak var headersTableView: UITableView!
    @IBOutlet weak var paramsTableView: UITableView!
    @IBOutlet weak var bodyTableView: UITableView!
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    
    enum CellId: Int {
        case spaceAfterTop = 0
        case url = 1
        case spacerAfterUrl = 2
        case name = 3
        case spacerAfterName = 4
        case header = 5
        case spacerAfterHeader = 6
        case params = 7
        case spacerAfterParams = 8
        case body = 9
        case spacerAfterBody = 10
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.request)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc - did load")
        self.initUI()
        self.updateData()
        self.reloadAllTableViews()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.view.backgroundColor = App.Color.tableViewBg
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.addNavigationBarEditButton()
    }
    
    /// Display Edit button in navigation bar
    func addNavigationBarEditButton() {
        self.tabbarController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(self.editButtonDidTap(_:)))
    }
    
    func initHeadersTableViewManager() {
        self.headerKVTableViewManager.kvTableView = self.headersTableView
        self.headerKVTableViewManager.delegate = self
        self.headerKVTableViewManager.tableViewType = .header
        self.headerKVTableViewManager.bootstrap()
        self.headerKVTableViewManager.reloadData()
    }
    
    func initParamsTableViewManager() {
        self.paramsKVTableViewManager.kvTableView = self.paramsTableView
        self.paramsKVTableViewManager.delegate = self
        self.paramsKVTableViewManager.tableViewType = .params
        self.paramsKVTableViewManager.bootstrap()
        self.paramsKVTableViewManager.reloadData()
    }
    
    func initBodyTableViewManager() {
        self.bodyKVTableViewManager.kvTableView = self.bodyTableView
        self.bodyKVTableViewManager.delegate = self
        self.bodyKVTableViewManager.tableViewType = .body
        self.bodyKVTableViewManager.bootstrap()
        self.bodyKVTableViewManager.reloadData()
    }
    
    func reloadAllTableViews() {
        self.tableView.reloadData()
    }
    
    @objc func editButtonDidTap(_ sender: Any) {
        Log.debug("edit button did tap")
    }
    
    func updateData() {
        self.request = self.tabbarController.request
        Log.debug("request vc - \(String(describing: self.request))")
        guard let req = self.request, let proj = req.project else { return }
        if let method = self.localdb.getRequestMethodData(at: req.selectedMethodIndex.toInt(), projId: proj.getId()) {
            self.methodLabel.text = method.name
        } else {
            self.methodLabel.text = "GET"
        }
        self.urlLabel.text = req.url
        self.urlLabel.text = "https://example.com/api/image/2458C0A7-538A-4A4B-9788-971BD38934BD/olive/imCJHoKQhHRWStsT3MkGiPbg.jpg"
//        self.urlTextField.text = req.url
//        self.nameTextField.text = req.name
//        if let x = req.desc, !x.isEmpty {
//            self.descTextView.text = x
//        } else {
//            self.descTextView.isHidden = true
//            self.descBorderView.isHidden = true
//        }
    }
}

// MARK: - Tableview delegates
extension RequestTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat!
        if indexPath.row == CellId.spaceAfterTop.rawValue {
            height = 12
        } else if indexPath.row == CellId.url.rawValue {
            height = 54  // 54
        } else if indexPath.row == CellId.spacerAfterUrl.rawValue {
            height = 12
        } else if indexPath.row == CellId.name.rawValue {
            height = 167
        } else if indexPath.row == CellId.spacerAfterName.rawValue {
            height = 16
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            height = self.headerKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterHeader.rawValue {
            height = 12
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            height = self.paramsKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterParams.rawValue {
            height = 12
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            if let body = AppState.editRequest?.body, !body.markForDelete, (body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue) {
                return RequestVC.bodyFormCellHeight()
            }
            if let body = AppState.editRequest?.body, !body.markForDelete, body.selected == RequestBodyType.binary.rawValue {
                return 60  // Only this one gets called.
            }
            height = self.bodyKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterBody.rawValue {
            height = 12
        } else {
            height = UITableView.automaticDimension
        }
//        Log.debug("height: \(height) for index: \(indexPath)")
        return height
    }
}

extension RequestTableViewController: KVTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
}
