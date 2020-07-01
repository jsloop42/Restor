//
//  RequestListViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension Notification.Name {
    static let navigatedBackToRequestList = Notification.Name("navigated-back-to-request-list")
    static let requestListVCShouldPresent = Notification.Name("request-list-vc-should-present")
}

class RequestListViewController: RestorViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var filterBtn: UIBarButtonItem!
    @IBOutlet weak var windowBtn: UIBarButtonItem!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    @IBOutlet weak var helpTextLabel: UILabel!
    private let utils = EAUtils.shared
    private let app: App = App.shared
    private lazy var localdb = { CoreDataService.shared }()
    private var frc: NSFetchedResultsController<ERequest>!
    private let cellReuseId = "requestCell"
    private lazy var db = { PersistenceService.shared }()
    private let nc = NotificationCenter.default
    var project: EProject?
    var methods: [ERequestMethodData] = []
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.frc != nil { self.frc.delegate = nil }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.isNavigatedBack { self.nc.post(name: .navigatedBackToRequestList, object: self) }
        AppState.setCurrentScreen(.requestList)
        self.navigationItem.title = "Requests"
        if self.frc != nil { self.frc.delegate = self }
        self.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initData()
        self.initEvents()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.databaseWillUpdate(_:)), name: .databaseWillUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.databaseDidUpdate(_:)), name: .databaseDidUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.requestDidChange(_:)), name: .requestDidChange, object: nil)
    }
    
    func getFRCPredicate(_ projId: String) -> NSPredicate {
        return NSPredicate(format: "project.id == %@ AND name != %@ AND markForDelete == %hdd", projId, "", false)
    }
    
    func initData() {
        if self.frc == nil, let projId = self.project?.getId() {
            let predicate = self.getFRCPredicate(projId)
            if let _frc = self.localdb.getFetchResultsController(obj: ERequest.self, predicate: predicate, ctx: self.localdb.mainMOC) as? NSFetchedResultsController<ERequest> {
                self.frc = _frc
                self.frc.delegate = self
            }
            self.methods = self.localdb.getRequestMethodData(projId:  projId, ctx: self.localdb.mainMOC)
        }
        self.reloadData()
    }
    
    func updateData() {
        guard let projId = self.project?.getId() else { return }
        self.methods = self.localdb.getRequestMethodData(projId: projId, ctx: self.localdb.mainMOC)
        if self.frc == nil { return }
        self.frc.delegate = nil
        try? self.frc.performFetch()
        self.frc.delegate = self
        self.checkHelpShouldDisplay()
        self.tableView.reloadData()
    }
    
    @objc func requestDidChange(_ notif: Notification) {
        Log.debug("request did change - refreshing list")
        self.updateData()
    }
    
    @objc func databaseWillUpdate(_ notif: Notification) {
        DispatchQueue.main.async { self.frc.delegate = nil }
    }
    
    @objc func databaseDidUpdate(_ notif: Notification) {
        DispatchQueue.main.async {
            self.frc.delegate = self
            self.reloadData()
        }
    }
    
    func checkHelpShouldDisplay() {
        if self.frc.numberOfRows(in: 0) == 0 {
            self.displayHelpText()
        } else {
            self.hideHelpText()
        }
    }
    
    func reloadData() {
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
            self.checkHelpShouldDisplay()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    func displayHelpText() {
        UIView.animate(withDuration: 0.3) {
            self.helpTextLabel.isHidden = false
        }
    }
    
    func hideHelpText() {
        UIView.animate(withDuration: 0.3) {
            self.helpTextLabel.isHidden = true
        }
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        if AppState.editRequest == nil {
            let name = self.app.getNewRequestName()
            if let proj = self.project, let wsId = proj.workspace?.getId(),
                let req = self.localdb.createRequest(id: self.localdb.requestId(), wsId: wsId, name: name, ctx: self.localdb.mainMOC) {
                if let vc = UIStoryboard.editRequestVC {
                    AppState.editRequest = req
                    self.navigationController!.pushViewController(vc, animated: true)
                }
            }
        }
    }
}

class RequestCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
    @IBOutlet weak var bottomBorder: UIView!
    
    func hideBottomBorder() {
        self.bottomBorder.isHidden = true
    }
    
    func displayBottomBorder() {
        self.bottomBorder.isHidden = false
    }
}

extension RequestListViewController: UITableViewDelegate, UITableViewDataSource {
    func getDesc(req: ERequest) -> String {
        let method = self.methods[req.selectedMethodIndex.toInt()].getName()
        let url = req.url ?? ""
        var path = ""
        if !url.isEmpty {
            if url.firstIndex(of: "{") != nil {
                if let idx = url.firstIndex(of: "/") {
                    path = String(url.suffix(from: idx))
                }
            } else {
                path = URL(string: url)?.path ?? url
            }
        }
        return "\(method) \(path.isEmpty ? "/" : path)"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as! RequestCell
        let req = self.frc.object(at: indexPath)
        cell.nameLbl.text = req.name
        let desc = self.getDesc(req: req)
        cell.descLbl.text = desc
        if desc.isEmpty {
            cell.descLbl.isHidden = true
        } else {
            cell.descLbl.isHidden = false
        }
        if indexPath.row == self.frc.numberOfRows(in: indexPath.section) - 1 {
            cell.displayBottomBorder()
        } else {
            cell.hideBottomBorder()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let req = self.frc.object(at: indexPath)
        if let vc = UIStoryboard.requestTabBar {
            vc.request = req
            self.navigationController!.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            let req = self.frc.object(at: indexPath)
            self.localdb.markEntityForDelete(req)
            self.localdb.saveMainContext()
            self.db.deleteDataMarkedForDelete(req, ctx: self.localdb.mainMOC)
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let req = self.frc.object(at: indexPath)
        let name = req.name ?? ""
        let desc = self.getDesc(req: req)
        let w = tableView.frame.width
        let h1 = name.height(width: w, font: App.Font.font17) + 20
        let h2: CGFloat =  desc.isEmpty ? 0 : desc.height(width: w, font: App.Font.font15) + 10
        return max(h1 + h2, 46)
    }
}

extension RequestListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("requests list frc did change: \(anObject)")
        if AppState.currentScreen != .requestList { return }
        DispatchQueue.main.async {
            self.tableView.reloadData()
            switch type {
            case .insert:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.tableView.scrollToBottom(section: 0) }
            default:
                break
            }
        }
    }
}
