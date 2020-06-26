//
//  HistoryTableViewController.swift
//  Restor
//
//  Created by jsloop on 26/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class HistoryCell: UITableViewCell {
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var pathLabel: UILabel!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var pathScrollView: UIScrollView!
    @IBOutlet weak var bottomBorder: UIView!
    
    func hideBottomBorder() {
        self.bottomBorder.isHidden = true
    }
    
    func displayBottomBorder() {
        self.bottomBorder.isHidden = false
    }
}

class HistoryTableViewController: UITableViewController {
    private let app = App.shared
    private lazy var localDB = { CoreDataService.shared }()
    private var frc: NSFetchedResultsController<EHistory>!
    var request: ERequest?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initData()
        self.initUI()
        self.initEvents()
    }
    
    func initData() {
        if self.frc != nil { return }
        if let _frc = self.localDB.getFetchResultsController(obj: EHistory.self, predicate: self.getPredicate(), ctx: self.localDB.mainMOC) as? NSFetchedResultsController<EHistory> {
            self.frc = _frc
            self.frc.delegate = self
            try? self.frc.performFetch()
            self.tableView.reloadData()
        }
    }
    
    func getPredicate() -> NSPredicate {
        guard let reqId = self.request?.getId() else { return NSPredicate(value: true) }
        return NSPredicate(format: "requestId == %@", reqId)
    }
    
    func updateData() {
        if self.frc == nil { return }
        self.frc.delegate = nil
        try? self.frc.performFetch()
        self.frc.delegate = self
        self.tableView.reloadData()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = UITableView.automaticDimension
        self.tableView.rowHeight = 54
        self.navigationItem.title = "History"
    }
    
    func initEvents() {
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.frc.numberOfRows(in: section)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath) as! HistoryCell
        let history = self.frc.object(at: indexPath)
        cell.methodLabel.text = history.method
        if let urlStr = history.url, let url = URL(string: urlStr) {
            cell.pathLabel.text = url.path
        }
        cell.statusCodeLabel.text = history.statusCode > 0 ? "\(history.statusCode)" : ""
        cell.contentView.addGestureRecognizer(cell.pathScrollView.panGestureRecognizer)
        if indexPath.row == self.frc.numberOfRows(in: indexPath.section) - 1 {
            cell.displayBottomBorder()
        } else {
            cell.hideBottomBorder()
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let history = self.frc.object(at: indexPath)
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.responseVC.rawValue) as? ResponseTableViewController {
            vc.viewType = .historyResponse
            vc.data = ResponseData(history: history)
            vc.request = self.request
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
}

extension HistoryTableViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("history list frc did change")
        DispatchQueue.main.async {
            if self.navigationController?.topViewController == self {
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
}

