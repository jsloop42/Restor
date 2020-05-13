//
//  ProjectListState.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

class ProjectListState: GKState {
    lazy var coord: ProjectListCoordinator? = {
        guard let fsm = self.stateMachine as? EAUIStateMachine else { return nil }
        return ProjectListCoordinator(presenter: fsm.presenter)
    }()
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == RequestListState.self ||
            stateClass == WorkspaceListState.self
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - project list")
        if previousState == nil {
            self.coord?.start()
        } else {
            (self.stateMachine as? EAUIStateMachine)?.presenter.popToRootViewController(animated: true)
        }
    }
    
    override func willExit(to nextState: GKState) {
        Log.debug("[state] will exit - project list")
    }
}
