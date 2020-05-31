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
    static var appCoord: AppCoordinator!
    static var workspaces: [EWorkspace] = []
    static var selectedWorkspace: Int = 0
    static var totalworkspaces = 0
    static var selectedProject: Int? = nil
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
    static var editRequestSaveTs: Int64 = 0
    static private (set) var previousScreen: App.Screen = .projectList
    static private (set) var currentScreen: App.Screen = .projectList
    /// The state will own the manager so that even if the vc gets deallocated, the processing happens.
    static var requestState: [String: RequestManager] = [:]
    /// The response data cache for a given request. The key here is `requestId`.
    static var responseCache: [String: ResponseCache] = [:]
    
    static func addToRequestState(_ man: RequestManager) {
        self.requestState[man.request.getId()] = man
    }
    
    static func removeFromRequestState(_ reqId: String) {
        self.requestState.removeValue(forKey: reqId)
    }
    
    static func getFromRequestState(_ reqId: String) -> RequestManager? {
        self.requestState[reqId]
    }
    
    static func clearRequestState() {
        self.requestState = [:]
    }
    
    static func setCurrentScreen(_ screen: App.Screen) {
        if self.currentScreen == screen { return }
        if screen != .popup { self.previousScreen = self.currentScreen }
        self.currentScreen = screen
    }
    
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
    
    // MARK: - Response Cache
    
    static func getResponseCache(_ requestId: String) -> ResponseCache? {
        return self.responseCache[requestId]
    }
    
    static func setResponseCache(_ cache: ResponseCache, for requestId: String) {
        self.responseCache[requestId] = cache
    }
    
    static func clearResponseCache() {
        self.responseCache.allValues().forEach { cache in
            
        }
    }
}

/// Holds a map with the MD5 hash of the response data and the temporary file URL to the data.
struct ResponseCache {
    private var hashes: [String: EATemporaryFile] = [:]
    private lazy var utils = { EAUtils.shared }()
    
    mutating func getURL(_ data: Data) -> URL? {
        let hash = self.hash(data)
        return self.hashes[hash]?.fileURL
    }
    
    func getURL(_ hash: String) -> URL? {
        return self.hashes[hash]?.fileURL
    }

    /// Returns the rendered data for the given original data.
    mutating func getData(_ data: Data) -> Data? {
        let hash = self.hash(data)
        guard let url = self.getURL(hash) else { return nil }
        return try? Data(contentsOf: url)
    }
    
    mutating func addData(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        if let x = try? self.addData(data) { return x }
        return ""
    }
    
    // Currently for a request, we keep at the most 3 responses in cache.
    mutating func addData(_ data: Data) throws -> String {
        let hash = self.hash(data)
        if self.hashes[hash] == nil {
            if self.hashes.count > 3 {
                _ = self.hashes.first?.value.delete()
            }
            self.hashes[hash] = try self.writeToTemporaryURL(hash, data: data)
        }
        return hash
    }
    
    func cleanup(_ hash: String) {
        if self.hashes[hash] == nil {
            _ = self.hashes[hash]?.delete()
        }
    }
    
    func getAllKeys() -> [String] {
        return self.hashes.allKeys()
    }
    
    func getAllValues() -> [EATemporaryFile] {
        return self.hashes.allValues()
    }
    
    mutating func clear() {
        let keys = self.hashes.allKeys()
        keys.forEach { key in
            if let status = self.hashes[key]?.delete(), status {
                self.hashes.removeValue(forKey: key)
            }
        }
        if !self.hashes.isEmpty {
            Log.error("Error deleting cache of: \(self.hashes)")
        }
        self.hashes = [:]
    }
    
    mutating private func hash(_ string: String) -> String {
        return self.utils.md5(txt: string)
    }
    
    /// Hashes the original data as recevied from the server. This hash is used as the key to the rendered data.
    mutating private func hash(_ data: Data) -> String {
        return self.utils.md5(data: data)
    }
    
    private func writeToTemporaryURL(_ hash: String, data: Data) throws -> EATemporaryFile {
        let file = try EATemporaryFile(fileName: hash)
        try data.write(to: file.fileURL)
        return file
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
