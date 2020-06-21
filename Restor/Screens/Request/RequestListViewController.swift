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
    private let utils = EAUtils.shared
    private let app: App = App.shared
    private lazy var localdb = { CoreDataService.shared }()
    private var frc: NSFetchedResultsController<ERequest>!
    private let cellReuseId = "requestCell"
    private lazy var db = { PersistenceService.shared }()
    private let nc = NotificationCenter.default
    var project: EProject?
    
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
        }
        self.reloadData()
    }
    
    func updateData() {
        if self.frc == nil { return }
        self.frc.delegate = nil
        try? self.frc.performFetch()
        self.frc.delegate = self
        self.tableView.reloadData()
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
    
    func reloadData() {
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        if AppState.editRequest == nil {
            let name = self.app.getNewRequestName()
            if let proj = self.project, let wsId = proj.workspace?.getId(),
                let req = self.localdb.createRequest(id: self.localdb.requestId(), wsId: wsId, name: name, ctx: self.localdb.mainMOC) {
                self.nc.post(name: .editRequestVCShouldPresent, object: self, userInfo: ["request": req])
            }
        }
    }
}

class RequestCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension RequestListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as! RequestCell
        let req = self.frc.object(at: indexPath)
        cell.nameLbl.text = req.name
        cell.descLbl.text = req.desc
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let req = self.frc.object(at: indexPath)
        self.nc.post(name: .requestVCShouldPresent, object: self, userInfo: ["request": req])
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
