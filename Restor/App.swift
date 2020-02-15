//
//  App.swift
//  Restor
//
//  Created by jsloop on 23/01/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class App {
    static let shared: App = App()
    
    func addSettingsBarButton() -> UIBarButtonItem {
        if #available(iOS 13.0, *) {
            return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsBtnDidTap(_:)))
        }
        return UIBarButtonItem(image: UIImage(), style: .plain, target: self, action: #selector(self.settingsBtnDidTap(_:)))
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings btn did tap")
    }
    
    func initDefaultWorspace() {
        let ws = Workspace(name: "Default Workspace", desc: "Default workspace")
        let _ = Project(name: "Default Project", desc: "Default project", workspace: ws)
        AppState.workspaces.append(ws)
        AppState.selectedWorkspace = 0
        AppState.selectedProject = 0
    }

    func addWorkspace(_ ws: Workspace) {
        AppState.workspaces.append(ws)
    }
    
    func addProject(_ project: Project) {
        if let wsIdx = AppState.selectedWorkspace {
            AppState.workspaces[wsIdx].projects.append(project)
        }
    }
    
    /// Draws a bottom border to the given text field
    func updateTextFieldWithBottomBorder(_ tf: EATextField) {
        tf.borderStyle = .none
        if #available(iOS 13.0, *) {
            tf.tintColor = .secondaryLabel
        } else {
            tf.tintColor = .lightGray
        }
    }
}

enum TableCellId: String {
    case workspaceCell
    case projectCell
    case requestCell
}

enum StoryboardId: String {
    case workspaceVC
    case projectVC
    case requestListVC
    case requestVC
    case optionsPickerVC
    case optionsPickerNav
}

/// The request option elements
enum RequestHeaderInfo: Int {
    case description = 0
    case headers
    case urlParams
    case body
    case auth
    case options
}

enum Screen {
    case workspaceListing
    case projectListing
    case requestListing
    case request
    case requestEdit
    case optionListing
}
