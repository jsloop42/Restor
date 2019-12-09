//
//  State.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

struct State {
    static var workspaces: [Workspace] = []
    static var selectedWorkspace: Int? = nil
    
    static func workspace(forIndex index: Int) -> Workspace? {
        if index < self.workspaces.count {
            return self.workspaces[index]
        }
        return nil
    }
}
