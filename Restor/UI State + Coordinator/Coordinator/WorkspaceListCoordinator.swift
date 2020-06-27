//
//  WorkspaceListCoordinator.swift
//  Restor
//
//  Created by jsloop on 15/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class WorkspaceListCoordinator: EACoordinator {
    private let presenter: UIViewController
    
    init(presenter: UIViewController) {
        self.presenter = presenter
    }
    
    func start() {
        Log.debug("ws list coord - start")
        if let vc = UIStoryboard.workspaceListVC {
            self.presenter.present(vc, animated: true, completion: nil)
        }
    }
}
