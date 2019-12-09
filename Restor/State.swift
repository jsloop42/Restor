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
    static var selectedProject: Int? = nil
    
    static func workspace(forIndex index: Int) -> Workspace? {
        if index < self.workspaces.count {
            return self.workspaces[index]
        }
        return nil
    }
    
    static func project(forIndex index: Int) -> Project? {
        self.selectedProject = index
        if let wIdx = self.selectedWorkspace, let ws = self.workspace(forIndex: wIdx) {
            if index < ws.projects.count {
                return ws.projects[index]
            }
        }
        return nil
    }
        
    static func request(forIndex index: Int) -> Request? {
        if let pIdx = self.selectedProject, let project = self.project(forIndex: pIdx) {
            if index < project.requests.count {
                return project.requests[index]
            }
        }
        return nil
    }
}
