//
//  State.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

struct AppState {
    static var workspaces: [Workspace] = []
    static var selectedWorkspace: Int? = nil
    static var selectedProject: Int? = nil
    static var optionsPickerData: OptionsPickerState?
    static var activeScreen: Screen = .projectListing
    static var isKeyboardActive = false
    static var keyboardHeight: CGFloat = 0.0
    static var currentWorkspace: Workspace?
    static var currentProject: Project?
    /// The request which is currently being added or edited.
    static var editRequest: Request?
    
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
    
    static func currentWorkspaceName() -> String {
        if let ws = self.getCurrentWorkspace() {
            return ws.name
        } else if let ws = self.workspaces.first {
            return ws.name
        }
        return "Workspace"
    }
    
    static func getCurrentWorkspace() -> Workspace? {
        if let idx = self.selectedWorkspace {
            let ws = self.workspaces[idx]
            self.currentWorkspace = ws
            return ws
        }
        self.currentWorkspace = nil
        return nil
    }
    
    
}

struct OptionsPickerState {
    /// Generic model data
    static var data: [String] = []
    /// The model data for request method type
    static var requestData: [RequestMethodData] = []
    /// The selected index in the option picker data model
    static var selected: Int = 0
    static var title: String = "body"
    /// The index of data in the model
    static var modelIndex: Int = 0
}

struct DocumentPickerState {
    /// List of URLs for document attachment type
    static var docs: [URL] = []
    /// Photo or camera attachment
    static var image: UIImage?
    /// The index of data in the model
    static var modelIndex: Int = 0
}
