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
    static var workspaces: [EWorkspace] = []
    static var selectedWorkspace: Int = 0
    static var totalworkspaces = 0
    static var selectedProject: Int? = nil
    static var activeScreen: Screen = .projectListing
    static var isKeyboardActive = false
    static var keyboardHeight: CGFloat = 0.0
    static var currentWorkspace: EWorkspace?
    static var currentProject: EProject?
    /// The request which is currently being added or edited.
    static var editRequest: ERequest?
    /// Current attachment info being processed.
    static var binaryAttachmentInfo = AttachmentInfo()
    /// If any request is begin currently edited, in which case, we delay saving context, until done.
    static var isRequestEdit = false
    static var editRequestSaveTs: Int64 = Date().currentTimeNanos()
    
    static func workspace(forIndex index: Int) -> EWorkspace? {
        if index < self.workspaces.count {
            return self.workspaces[index]
        }
        return nil
    }
    
    static func project(forIndex index: Int) -> EProject? {
        self.selectedProject = index
        if let ws = self.workspace(forIndex: self.selectedWorkspace), let projects = ws.projects {
            if index < projects.count {
                return projects.allObjects[index] as? EProject
            }
        }
        return nil
    }
        
    static func request(forIndex index: Int) -> ERequest? {
        if let pIdx = self.selectedProject, let project = self.project(forIndex: pIdx), let requests = project.requests {
            if index < requests.count {
                return requests.allObjects[index] as? ERequest
            }
        }
        return nil
    }
    
    static func updateEditRequestSaveTs() {
        self.editRequestSaveTs = Date().currentTimeNanos()
    }
}

struct DocumentPickerState {
    /// List of URLs for document attachment type
    static var docs: [URL] = []
    /// Photo or camera attachment
    static var image: UIImage?
    /// The image name with extension
    static var imageName: String = ""
    /// kUTTypeImage
    static var imageType: String = "png"
    /// If camera is chosen
    static var isCameraMode: Bool = false
    /// The index of data in the model
    static var modelIndex: Int = 0
    /// The body form field model `RequestData` id.
    static var reqDataId = ""
    
    static func clear() {
        DocumentPickerState.docs = []
        DocumentPickerState.image = nil
        DocumentPickerState.imageType = "png"
        DocumentPickerState.isCameraMode = false
        DocumentPickerState.modelIndex = 0
        DocumentPickerState.reqDataId = ""
    }

    static var debugDescription: String {
        return
            """
            DocumentPickerState
            docs: \(DocumentPickerState.docs)
            image: \(String(describing: DocumentPickerState.image))
            imageName: \(DocumentPickerState.imageName)
            imageType: \(DocumentPickerState.imageType)
            isCameraMode: \(DocumentPickerState.isCameraMode)
            modelIndex: \(DocumentPickerState.modelIndex)
            reqDataId: \(DocumentPickerState.reqDataId)
            """
    }
}
