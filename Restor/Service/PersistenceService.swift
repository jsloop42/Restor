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

fileprivate class CacheValue: EACacheValue {
    private var _key: String
    private var _value: CKRecord
    private var _ts: Int64
    private var _accessCount: Int
    
    init(key: String, value: CKRecord, ts: Int64, accessCount: Int) {
        self._key = key
        self._value = value
        self._ts = ts
        self._accessCount = accessCount
    }
    
    func value() -> Any {
        return self._value as Any
    }
    
    func key() -> String {
        self._key
    }
    
    func ts() -> Int64 {
        self._ts
    }
    
    func accessCount() -> Int {
        self._accessCount
    }
    
    func setValue(_ v: Any) {
        self._value = v as! CKRecord
    }
    
    func setKey(_ k: String) {
        self._key = k
    }
    
    func setTs(_ v: Int64) {
        self._ts = v
    }
    
    func setAccessCount(_ c: Int) {
        self._accessCount = c
    }
}

struct DeferredSaveModel: Hashable {
    var record: CKRecord
    var entity: Entity
    /// Entity id
    var id: String
    var completion: (() -> Void)?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }
    
    static func == (lhs: DeferredSaveModel, rhs: DeferredSaveModel) -> Bool {
        return lhs.id == rhs.id
    }
}

class PersistenceService {
    static let shared = PersistenceService()
    private lazy var localdb = { return CoreDataService.shared }()
    private lazy var ck = { return CloudKitService.shared }()
    var wsCache = EALFUCache(size: 8)
    var projCache = EALFUCache(size: 16)
    var reqCache = EALFUCache(size: 32)
    var reqDataCache = EALFUCache(size: 64)  // assuming we have one header and a param for a request, the size is double
    var reqBodyCache = EALFUCache(size: 32)  // same as req
    var reqMethodCache = EALFUCache(size: 16)
    var fileCache = EALFUCache(size: 16)
    var imageCache = EALFUCache(size: 16)
    var saveQueueCompletionHandler: (([CKRecord]) -> Void)!
    var saveQueue: EAQueue<DeferredSaveModel>!
    private let nc = NotificationCenter.default
    
    enum SubscriptionId: String {
        case fileChange = "file-change"
        case imageChange = "image-change"
        case projectChange = "project-change"
        case requestChange = "request-change"
        case requestBodyChange = "request-body-change"
        case requestDataChange = "request-data-change"
        case requestMethodChange = "request-method-change"
        case workspaceChange = "workspace-change"
        case databaseChange = "database-change"
        
        static var allCases: [String] {
            return [SubscriptionId.fileChange.rawValue, SubscriptionId.imageChange.rawValue, SubscriptionId.projectChange.rawValue,
                    SubscriptionId.requestChange.rawValue, SubscriptionId.requestBodyChange.rawValue, SubscriptionId.requestDataChange.rawValue,
                    SubscriptionId.requestMethodChange.rawValue, SubscriptionId.workspaceChange.rawValue, SubscriptionId.databaseChange.rawValue]
        }
    }
    
    enum RecordType: String {
        case file = "File"
        case image = "Image"
        case project = "Project"
        case request = "Request"
        case requestBodyData = "RequestBodyData"
        case requestData = "RequestData"
        case requestMethodData = "RequestMethodData"
        case workspace = "Workspace"
    }
    
    init() {
        self.initSaveQueue()
    }
    
    func initDefaultWorkspace() -> EWorkspace? {
        if !isRunningTests { return self.localdb.getDefaultWorkspace() }
        return nil
    }
    
    func clearCache() {
        self.wsCache.resetCache()
        self.projCache.resetCache()
        self.reqCache.resetCache()
        self.reqBodyCache.resetCache()
        self.reqDataCache.resetCache()
        self.reqMethodCache.resetCache()
        self.fileCache.resetCache()
        self.imageCache.resetCache()
    }
    
    // MARK: - CloudKit
    
    func initSaveQueue() {
        self.saveQueue = EAQueue<DeferredSaveModel>(interval: 4.0, completion: { elems in
            guard !elems.isEmpty else { return }
            var records: [CKRecord] = []
            var entityMap: [CKRecord.ID: DeferredSaveModel] = [:]
            elems.forEach { records.append($0.record); entityMap[$0.record.recordID] = $0 }
            self.ck.saveRecords(records) { result in
                switch result {
                case .success(let xs):
                    Log.debug("Save to cloud success")
                    // Update the entities' attribute and cache
                    xs.forEach { record in
                        if let map = entityMap[record.recordID] {
                            let entity = map.entity
                            entity.setIsSynced(true)
                            if let type = RecordType(rawValue: record.recordType) {
                                self.addToCache(record: record, entityId: entity.getId(), type: type)
                                map.completion?()
                            }
                        }
                    }
                case .failure(let error):
                    Log.error("Error saving to cloud: \(error)")
                }
            }
        })
    }
    
    func subscribeToCloudKitEvents() {
        Log.debug("subscribe to cloudkit events")
        self.ck.subscribeToDBChanges(subId: SubscriptionId.databaseChange.rawValue)
        //self.subscribeToWorkspaceChange(self.localdb.getDefaultWorkspace().getId())
    }
    
    func subscribeToWorkspaceChange(_ wsId: String) {
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let subID = self.ck.subscriptionID(self.getSubscriptionIdForRecordType(.workspace), zoneID: zoneID)
        self.ck.subscribe(subID, recordType: RecordType.workspace.rawValue, zoneID: zoneID)
    }
    
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
        case .requestData:
            return SubscriptionId.requestDataChange.rawValue
        case .requestBodyData:
            return SubscriptionId.requestBodyChange.rawValue
        case .requestMethodData:
            return SubscriptionId.requestMethodChange.rawValue
        case .workspace:
            return SubscriptionId.workspaceChange.rawValue
        }
    }
    
    func getFromCache(entityId: String, type: RecordType) -> EACacheValue? {
        switch type {
        case .workspace:
            return self.wsCache.get(entityId)
        case .project:
            return self.projCache.get(entityId)
        case .request:
            return self.reqCache.get(entityId)
        case .requestData:
            return self.reqDataCache.get(entityId)
        case .requestBodyData:
            return self.reqBodyCache.get(entityId)
        case .requestMethodData:
            return self.reqMethodCache.get(entityId)
        case .file:
            return self.fileCache.get(entityId)
        case .image:
            return self.imageCache.get(entityId)
        }
    }
    
    func addToCache(record: CKRecord, entityId: String, type: RecordType) {
        switch type {
        case .workspace:
            self.wsCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .project:
            self.projCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .request:
            self.reqCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .requestData:
            self.reqDataCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .requestBodyData:
            self.reqBodyCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .requestMethodData:
            self.reqMethodCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .file:
            self.fileCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        case .image:
            self.imageCache.add(CacheValue(key: entityId, value: record, ts: Date().currentTimeNanos(), accessCount: 0))
        }
    }
    
    /// Check if server record is latest. Cases were a record is created locally, but failed to sync, new record gets added from another device, and then the
    /// former record gets saved, in which case the server copy is latest.
    func isServerLatest(local: CKRecord, server: CKRecord) -> Bool {
        if let lts = local["modified"] as? Int64, let rts = server["modified"] as? Int64 { return rts > lts }
        return false
    }
    
    func mergeWorkspace(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeProject(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }
    
    func mergeRequest(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }
    
    func mergeRequestBodyData(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }

    func mergeRequestData(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }
    
    func mergeRequestMethodData(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }
    
    func mergeFileData(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }
    
    func mergeImageData(local: CKRecord, server: CKRecord) -> CKRecord {
        return local
    }
    
    func mergeRecords(local: CKRecord?, server: CKRecord?, recordType: String) -> CKRecord? {
        guard let client = local, let remote = server, let type = RecordType(rawValue: recordType) else { return nil }
        switch type {
        case .workspace:
            return self.mergeWorkspace(local: client, server: remote)
        case .project:
            return self.mergeProject(local: client, server: remote)
        case .request:
            return self.mergeRequest(local: client, server: remote)
        case .requestData:
            return self.mergeRequestData(local: client, server: remote)
        case .requestBodyData:
            return self.mergeRequestBodyData(local: client, server: remote)
        case .requestMethodData:
            return self.mergeRequestMethodData(local: client, server: remote)
        case .file:
            return self.mergeFileData(local: client, server: remote)
        case .image:
            return self.mergeImageData(local: client, server: remote)
        }
    }
    
    func updateWorkspaceFromCloud(_ record: CKRecord) {
        let wsId = record.id()
        let moc = self.localdb.getChildMOC()
        if let ws = self.localdb.getWorkspace(id: wsId, ctx: moc) {
            if ws.isSyncEnabled && ws.modified <= record.modified() {  // => server has new copy
                ws.updateFromCKRecord(record)
                self.localdb.saveChildContext(moc)
                Log.debug("Workspace synced")
                self.nc.post(Notification(name: NotificationKey.workspaceDidSync))
            }
        } else {  // workspace not found, create one
            if self.localdb.createWorkspace(id: wsId, index: record.index().toInt(), name: record.name(), desc: record.desc(), isSyncEnabled: record.isSyncEnabled(), ctx: moc) != nil {
                self.localdb.saveChildContext(moc)
                Log.debug("Workspace synced")
                self.nc.post(Notification(name: NotificationKey.workspaceDidSync))
            }
        }
    }
    
    func updateProjectFromCloud(_ record: CKRecord) {
        let projId = record.id()
        let moc = self.localdb.getChildMOC()
        if let proj = self.localdb.getProject(id: projId, ctx: moc) {
            if proj.modified <= record.modified() {  // => server has new copy
                proj.updateFromCKRecord(record)
                self.localdb.saveChildContext(moc)
                Log.debug("Project synced")
                self.nc.post(Notification(name: NotificationKey.projectDidSync))
            }
        } else {  // project not found, create one
            if self.localdb.createProject(id: record.id(), index: record.index().toInt(), name: record.name(), desc: record.desc(), checkExists: false, ctx: moc) != nil {
                self.localdb.saveChildContext(moc)
                Log.debug("Project synced")
                self.nc.post(Notification(name: NotificationKey.projectDidSync))
            }
        }
    }
    
    func updateRequestFromCloud(_ record: CKRecord) {
        let moc = self.localdb.getChildMOC()
        guard let proj = ERequest.getProject(record, ctx: moc) else { Log.error("Error getting project"); return }
        let reqId = record.id()
        if let req = self.localdb.getRequest(id: reqId, ctx: moc) {
            if req.modified <= record.modified() {  // => server has new copy
                req.updateFromCKRecord(record)
                req.project = proj
                self.localdb.saveChildContext(moc)
                Log.debug("Request synced")
                self.nc.post(Notification(name: NotificationKey.requestDidSync))
            }
        } else {  // request not found, create one
            if self.localdb.createRequest(id: record.id(), index: record.index().toInt(), name: record.name(), project: proj, checkExists: false, ctx: moc) != nil {
                self.localdb.saveChildContext(moc)
                Log.debug("Request synced")
                self.nc.post(Notification(name: NotificationKey.projectDidSync))
            }
        }
    }
        
    func updateRequestBodyDataFromCloud(_ record: CKRecord) {
        
    }
    
    func updateRequestDataFromCloud(_ record: CKRecord) {
        
    }
    
    func updateRequestMethodDataFromCloud(_ record: CKRecord) {
        
    }
    
    func updateFileDataFromCloud(_ record: CKRecord) {
        
    }
    
    func updateImageDataFromCloud(_ record: CKRecord) {
        
    }
    
    func cloudRecordDidChange(_ record: CKRecord) {
        let type = RecordType(rawValue: record.recordType)
        switch type {
        case .workspace:
            self.updateWorkspaceFromCloud(record)
        case .project:
            self.updateProjectFromCloud(record)
        case .request:
            self.updateRequestFromCloud(record)
        case .requestBodyData:
            self.updateRequestBodyDataFromCloud(record)
        case .requestData:
            self.updateRequestDataFromCloud(record)
        case .requestMethodData:
            self.updateRequestMethodDataFromCloud(record)
        case .file:
            self.updateFileDataFromCloud(record)
        case .image:
            self.updateImageDataFromCloud(record)
        case .none:
            Log.error("Unknow record: \(record)")
        }
    }
    
    func syncFromCloud() {
        self.ck.fetchAllZones { result in
            switch result {
            case .success(let (_, new)):
                self.fetchWorkspaces(zones: new, completion: self.workspacesFetchHandler(_:))
            case .failure(let err):
                Log.error("Error fetching all zones: \(err)")
            }
        }
    }
    
    func workspacesFetchHandler(_ result: Result<[CKRecord], Error>) {
        switch result {
        case .success(let records):
            records.forEach { record in
                self.updateWorkspaceFromCloud(record)
                let projIDs = EWorkspace.getProjectRecordIDs(record)
                self.fetchRecords(recordIDs: projIDs,completion: self.projectsFetchHandler(_:))
            }
            break
        case .failure(let err):
            Log.error("Error fetching workspaces: \(err)")
        }
    }
    
    func projectsFetchHandler(_ result: Result<[CKRecord], Error>) {
        switch result {
        case .success(let records):
            records.forEach { record in
                self.updateProjectFromCloud(record)
                let reqIDs = EProject.getRequestRecordIDs(record)
                self.fetchRecords(recordIDs: reqIDs,completion: self.projectsFetchHandler(_:))
            }
            break
        case .failure(let err):
            Log.error("Error fetching projects: \(err)")
        }
    }
    
    func requestsFetchHandler(_ result: Result<[CKRecord], Error>) {
        switch result {
        case .success(let records):
            records.forEach { record in
                self.updateRequestFromCloud(record)
                // TODO: fetch nested data
            }
            break
        case .failure(let err):
            Log.error("Error fetching projects: \(err)")
        }
    }
    
    // MARK: - Fetch
    
    /// Checks if the record is present in cache. If present, returns, else fetch from cloud, adds to the cache and returns.
    func fetchRecord(_ entity: Entity, type: RecordType, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let id = entity.getId()
        if let cached = self.getFromCache(entityId: id, type: type) as? CacheValue, let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: entity.getZoneID())
        self.ck.fetchRecords(recordIDs: [recordID]) { result in
            switch result {
            case .success(let hm):
                if let record = hm[recordID] {
                    self.addToCache(record: record, entityId: id, type: type)
                    completion(.success(record))
                } else {
                    completion(.failure(AppError.fetch))
                }
            case .failure(let error):
                Log.error("Error fetching record \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func fetchRecords(recordIDs: [CKRecord.ID], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        self.ck.fetchRecords(recordIDs: recordIDs) { result in
            switch result {
            case .success(let hm):
                let records = hm.allValues()
                records.forEach { record in self.addToCache(record: record, entityId: record.id(), type: RecordType(rawValue: record.type())!) }
                completion(.success(records))
            case .failure(let error):
                Log.error("Error fetching record \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Fetches workspaces from cloud and caches the result.
    func fetchWorkspaces(zones: [CKRecordZone], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        self.ck.fetchRecords(recordIDs: self.ck.recordIDs(zones: zones)) { result in
            switch result {
            case .success(let hm):
                let zones = hm.allValues()
                zones.forEach { record in self.addToCache(record: record, entityId: record.id(), type: .workspace) }
                completion(.success(zones))
            case .failure(let error):
                Log.error("Error fetching record \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Save
    
    func saveToCloud(record: CKRecord, entity: Entity, completion: (() -> Void)? = nil) {
        self.saveQueue.enqueue(DeferredSaveModel(record: record, entity: entity, id: entity.getId(), completion: completion))
    }
    
    func saveToCloud(_ models: [DeferredSaveModel]) {
        self.saveQueue.enqueue(models)
    }
    
    /// Saves the given workspace to the cloud
    func saveWorkspaceToCloud(_ ws: EWorkspace) {
        let wsId = ws.getId()
        let zoneID = ws.getZoneID()
        let recordID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
        let record = self.ck.createRecord(recordID: recordID, recordType: RecordType.workspace.rawValue)
        ws.updateCKRecord(record)
        self.saveToCloud(record: record, entity: ws, completion: { self.subscribeToWorkspaceChange(wsId) })
    }
    
    /// Save the given project and updates the associated workspace to the cloud.
    func saveProjectToCloud(_ proj: EProject) {
        let projId = proj.getId()
        let zoneID = proj.getZoneID()
        let recordID = self.ck.recordID(entityId: projId, zoneID: zoneID)
        let ckproj = self.ck.createRecord(recordID: recordID, recordType: RecordType.project.rawValue)
        guard let ws = proj.workspace else { Log.error("Workspace is empty for project"); return }
        self.fetchRecord(ws, type: .workspace) { result in
            switch result {
            case .success(let ckws):
                self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws)
            case .failure(let err):
                Log.error("Error getting workspace from cloud: \(err)")
            }
        }
    }
    
    /// Save the given request and updates the associated project to the cloud.
    func saveRequestToCloud(_ req: ERequest) {
        guard let reqId = req.id else { Log.error("ERequest id is nil"); return }
        guard let wsId = req.project?.workspace?.id else { Log.error("Error getting workspace id"); return }
        guard let projId = req.project?.id else { Log.error("Error getting project id"); return }
        guard let proj = self.localdb.getProject(id: projId) else { Log.error("Error getting project"); return }
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let ckReqID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        let ckreq = self.ck.createRecord(recordID: ckReqID, recordType: req.recordType)
        self.fetchRecord(proj, type: .project) { result in
            switch result {
            case .success(let ckproj):
                self.saveRequestToCloudImp(ckreq: ckreq, req: req, ckproj: ckproj, proj: proj)
            case .failure(let error):
                Log.error("Error fetching project record: \(error)")
                if let err = error as? CKError {
                    if !err.isRecordExists() {
                        Log.error("Project record does not exist. Retrying with new record.")
                        let projID = self.ck.recordID(entityId: projId, zoneID: zoneID)
                        let ckproj = self.ck.createRecord(recordID: projID, recordType: RecordType.project.rawValue)
                        self.saveRequestToCloudImp(ckreq: ckreq, req: req, ckproj: ckproj, proj: proj)
                    }
                }
            }
        }
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveProjectToCloudImp(ckproj: CKRecord, proj: EProject, ckws: CKRecord, ws: EWorkspace) {
        proj.updateCKRecord(ckproj, workspace: ckws)
        EWorkspace.addProjectReference(to: ckws, project: ckproj)
        let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
        let wsModel = DeferredSaveModel(record: ckws, entity: ws, id: ws.getId())
        self.saveToCloud([projModel, wsModel])
        // TODO: subscribe to project change
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveRequestToCloudImp(ckreq: CKRecord, req: ERequest, ckproj: CKRecord, proj: EProject) {
        req.updateCKRecord(ckreq, project: ckproj)
        EProject.addRequestReference(to: ckproj, request: ckreq)
        let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
        let reqModel = DeferredSaveModel(record: ckreq, entity: req, id: req.getId())
        self.saveToCloud([reqModel, projModel])  // we need to save this in the same request so that the deps are created and referrenced properly.
        // TODO: subscribe to request change
    }
    
    /*
     
     1. Check if CKRecord is present in cache. If present, return, else fetch from cloud, add to cache, return
     2. If when saving, the server updated error is given, resolve conflict, save record, add to cache.
     3. Maintain separate cache for each entity type: workspace, project, request
     4. Cache size:
     
     */
}
