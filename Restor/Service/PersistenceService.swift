//
//  PersistenceService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class CacheValue: EACacheValue {
    /// The record object
    private var record: CKRecord
    private var key: String
    /// The last access time.
    private var _ts: Int64 = 0
    /// Cache hits.
    private var _accessCount: Int = 0
    
    init(_ record: CKRecord) {
        self.record = record
        self.key = record.recordID.recordName
    }
    
    func value() -> Any {
        return self.record as Any
    }
    
    func id() -> String {
        return self.key
    }
    
    func ts() -> Int64 {
        return self._ts
    }
    
    func accessCount() -> Int {
        return self._accessCount
    }
    
    func setValue(_ any: Any) {
        self.record = any as! CKRecord
    }
    
    func setId(_ v: String) {
        self.key = v
    }
    
    func setTs(_ v: Int64) {
        self._ts = v
    }
    
    func setAccessCount(_ c: Int) {
        self._accessCount = c
    }
}

class CacheListValue: EACacheListValue {
    var recordName: String
    var _accessCount: Int
    
    init(recordName: String, accessCount: Int) {
        self.recordName = recordName
        self._accessCount = accessCount
    }
    
    func id() -> String {
        return self.recordName
    }
    
    func accessCount() -> Int {
        return self._accessCount
    }
    
    func setId(_ v: String) {
        self.recordName = v
    }
    
    func setAccessCount(_ c: Int) {
        self._accessCount = c
    }
}

class PersistenceService {
    static let shared = PersistenceService()
    private lazy var localdb = { return CoreDataService.shared }()
    private lazy var ck = { return CloudKitService.shared }()
    var wsCache = EALFUCache(size: 8)
    var projCache = EALFUCache(size: 16)
    var reqCache = EALFUCache(size: 32)
    
    enum SubscriptionId: String {
        case fileChange = "file-change"
        case imageChange = "image-change"
        case projectChange = "project-change"
        case requestChange = "request-change"
        case requestMethodChange = "request-method-change"
        case workspaceChange = "workspace-change"
        
        static var allCases: [String] {
            return [SubscriptionId.fileChange.rawValue, SubscriptionId.imageChange.rawValue, SubscriptionId.projectChange.rawValue,
                    SubscriptionId.requestChange.rawValue, SubscriptionId.requestMethodChange.rawValue, SubscriptionId.workspaceChange.rawValue]
        }
    }
    
    enum RecordType: String {
        case file = "File"
        case image = "Image"
        case project = "Project"
        case request = "Request"
        case requestMethod = "RequestMethod"
        case workspace = "Workspace"
    }
    
    func initDefaultWorkspace() -> EWorkspace? {
        if !isRunningTests { return self.localdb.getDefaultWorkspace() }
        return nil
    }
    
    func clearCache() {
        self.wsCache.resetCache()
        self.projCache.resetCache()
        self.reqCache.resetCache()
    }
    
    // MARK: - CloudKit
    
    func getSubscriptionIdForRecordType(_ type: RecordType) -> String {
        switch type {
        case .file:
            return SubscriptionId.fileChange.rawValue
        case .image:
            return SubscriptionId.imageChange.rawValue
        case .project:
            return SubscriptionId.projectChange.rawValue
        case .request:
            return SubscriptionId.requestChange.rawValue
        case .requestMethod:
            return SubscriptionId.requestMethodChange.rawValue
        case .workspace:
            return SubscriptionId.workspaceChange.rawValue
        }
    }
    
    func fetchProject(_ proj: EProject, completion: (Result<CKRecord, Error>) -> Void) {
        
    }
    
    func saveRequestToCloud(_ req: ERequest) {
        guard let id = req.id else { Log.error("ERequest id is nil"); return }
        guard let wsId = req.project?.workspace?.id else { Log.error("Error getting workspace id"); return }
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let ckReqID = self.ck.recordID(entityId: id, zoneID: zoneID)
        let ckReq = self.ck.createRecord(recordID: ckReqID, recordType: req.recordType)
        // todo: get project
        // let ckProj = fetchProject()
        //req.updateCKRecord(ckReq, project: ckProj)
    }
    
    /*
     
     1. Check if CKRecord is present in cache. If present, return, else fetch from cloud, add to cache, return
     2. If when saving, the server updated error is given, resolve conflict, save record, add to cache.
     3. Maintain separate cache for each entity type: workspace, project, request
     4. Cache size:
     
     */
}
