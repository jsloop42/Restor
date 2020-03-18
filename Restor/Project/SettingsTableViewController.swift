//
//  SettingsTableViewController.swift
//  Restor
//
//  Created by jsloop on 18/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class SettingsTableViewController: UITableViewController {
    private let app = App.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("settings tv view did load")
        self.initUI()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.tableView.backgroundColor = App.Color.tableViewBg
    }
}
