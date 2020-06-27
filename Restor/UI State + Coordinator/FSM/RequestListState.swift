//
//  RequestListState.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

class RequestListState: GKState {
    var coord: RequestListCoordinator?
    var project: EProject?
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        let status = stateClass == ProjectListState.self || stateClass == RequestState.self || stateClass == EditRequestState.self
        if !status { Log.debug("[state] request list -> invalid state (\(stateClass))") }
        return status
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - request list")
        if previousState?.classForCoder == ProjectListState.self {
            guard let fsm = self.stateMachine as? EAUIStateMachine else { return }
            guard let proj = self.project else { return }
            self.coord = RequestListCoordinator(presenter: fsm.presenter, project: proj)
            self.coord?.start()
        }
    }
    
    override func willExit(to nextState: GKState) {
        Log.debug("[state] will exit - request list")
    }
}