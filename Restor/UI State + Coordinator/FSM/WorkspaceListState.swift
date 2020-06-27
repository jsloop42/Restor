//
//  WorkspaceListState.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

class WorkspaceListState: GKState {
    var coord: WorkspaceListCoordinator?
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        let status = stateClass == ProjectListState.self
        if !status { Log.debug("[state] workspace -> invalid state (\(stateClass))") }
        return status
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - ws list")
        if previousState?.classForCoder == ProjectListState.self {
            guard let fsm = self.stateMachine as? EAUIStateMachine else { return }
            // guard let projListVC = fsm.presenter.viewControllers.first else { return }
            // self.coord = WorkspaceListCoordinator(presenter: projListVC)
            self.coord = WorkspaceListCoordinator(presenter: fsm.presenter)
            self.coord?.start()
        }
    }
    
    override func willExit(to nextState: GKState) {
        Log.debug("[state] will exit - ws listt")
    }
}
