//
//  ProjectListCoordinator.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class ProjectListCoordinator: EACoordinator {
    private let presenter: UINavigationController
    
    init(presenter: UINavigationController) {
        self.presenter = presenter
    }
    
    func start() {
        Log.debug("proj list coord - start")
        if let vc = UIStoryboard.projectListVC {
            self.presenter.pushViewController(vc, animated: true)
        }
    }
}
