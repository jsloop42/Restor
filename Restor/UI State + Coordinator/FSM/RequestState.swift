//
//  RequestState.swift
//  Restor
//
//  Created by jsloop on 14/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

class RequestState: GKState {
    var coord: RequestCoordinator?
    var request: ERequest?
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        let status = stateClass == RequestListState.self || stateClass == EditRequestState.self
        if !status { Log.debug("[state] request -> invalid state (\(stateClass))") }
        return status
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - request")
        if previousState?.classForCoder == RequestListState.self {
            guard let fsm = self.stateMachine as? EAUIStateMachine else { return }
            guard let req = self.request else { return }
            self.coord = RequestCoordinator(presenter: fsm.presenter, request: req)
            self.coord?.start()
        }
    }
    
    override func willExit(to nextState: GKState) {
        Log.debug("[state] will exit - request")
    }
}
