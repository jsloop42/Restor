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
    var request: ERequest?
    private var tabbarController: RequestTabBarController { self.tabBarController as! RequestTabBarController }
    
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
        self.request = self.tabbarController.request
        Log.debug("request vc - \(String(describing: self.request))")
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.view.backgroundColor = App.Color.tableViewBg
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
    }
}
