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
    var entity: Entity? = nil
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
    var defaultZoneCursor: CKQueryOperation.Cursor?
    private let store = UserDefaults.standard
    private let lastSyncedKey = "last-synced-key"
    private let lastSyncTimeKey = "last-sync-time-key"
    private let defaultQueryCursorKey = "default-query-cursor-key"
    private let syncRecordKey = "sync-record-key"
    private let defaultZoneRecordFetchLimit = 50
    private let opqueue = EAOperationQueue()
    private var syncTimer: DispatchSourceTimer?
    private var previousSyncTime: Int = 0
    private var queryDefaultZoneRecordRepeatTimer: EARepeatTimer!
    private var fetchZoneChangesDelayTimer: EARescheduler!
    
    enum SubscriptionId: String {
        case fileChange = "file-change"
        case imageChange = "image-change"
        case projectChange = "project-change"
        case requestChange = "request-change"
        case requestBodyChange = "request-body-change"
        case requestDataChange = "request-data-change"
        case requestMethodChange = "request-method-change"
        case workspaceChange = "workspace-change"
        case zoneChange = "zone-change"  // default zone change
        case databaseChange = "database-change"
        
        static var allCases: [String] {
            return [SubscriptionId.fileChange.rawValue, SubscriptionId.imageChange.rawValue, SubscriptionId.projectChange.rawValue,
                    SubscriptionId.requestChange.rawValue, SubscriptionId.requestBodyChange.rawValue, SubscriptionId.requestDataChange.rawValue,
                    SubscriptionId.requestMethodChange.rawValue, SubscriptionId.workspaceChange.rawValue, SubscriptionId.databaseChange.rawValue]
        }
    }
    
    enum CursorKey: String {
        case workspace = "workspace-cursor-key"
        case project = "project-cursor-key"
        case request = "request-cursor-key"
        case requestBodyData = "request-body-data-cursor-key"
        case requestData = "request-data-cursor-key"
        case requestMethodData = "request-method-data-cursor-key"
        case file = "file-cursor-key"
        case image = "image-cursor-key"
        case zone = "zone-cursor-key"
        
        init(type: RecordType) {
            switch type {
            case .workspace:
                self = .workspace
            case .project:
                self = .project
            case .request:
                self = .request
            case .requestBodyData:
                self = .requestBodyData
            case .requestData:
                self = .requestData
            case .requestMethodData:
                self = .requestMethodData
            case .file:
                self = .file
            case .image:
                self = .image
            case .zone:
                self = .zone
            }
        }
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
            self.ck.saveRecords(records) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let xs):
                    Log.debug("Save to cloud success")
                    // Update the entities' attribute and cache
                    xs.forEach { record in
                        if let map = entityMap[record.recordID] {
                            if let entity = map.entity {
                                entity.setIsSynced(true)
                                if let type = RecordType(rawValue: record.recordType) {
                                    self.addToCache(record: record, entityId: entity.getId(), type: type)
                                    if type == .workspace {
                                        self.localdb.setWorkspaceActive(entity.getId())
                                    }
                                }
                            }
                            map.completion?()
                        }
                    }
                case .failure(let error):
                    Log.error("Error saving to cloud: \(error)")
                }
            }
        })
    }

    // MARK: - Cache
    
    func isSyncedOnce() -> Bool {
        return self.store.integer(forKey: self.lastSyncedKey) > 0
    }
    
    func setIsSyncedOnce() {
        self.store.set(Date().currentTimeNanos(), forKey: self.lastSyncedKey)
    }
    
    func removeIsSyncedOnce() {
        self.store.removeObject(forKey: self.lastSyncedKey)
    }
    
    // MARK: Query cursor cache
    
    func getCachedDefaultZoneQueryCursor() -> CKQueryOperation.Cursor? {
        guard let data = self.store.data(forKey: self.defaultQueryCursorKey) else { return nil }
        return CKQueryOperation.Cursor.decode(data)
    }
    
    func setDefaultZoneQueryCursorToCache(_ cursor: CKQueryOperation.Cursor) {
        if let data = cursor.encode() { self.store.set(data, forKey: self.defaultQueryCursorKey) }
    }
    
    func removeDefaultZoneQueryCursorFromCache() {
        self.store.removeObject(forKey: self.defaultQueryCursorKey)
    }
    
    func getQueryCursor(_ type: RecordType, zoneID: CKRecordZone.ID) -> CKQueryOperation.Cursor? {
        let key = CursorKey(type: type).rawValue
        if let zonesMap = self.store.dictionary(forKey: key), let data = zonesMap[zoneID.zoneName] as? Data {
            return CKQueryOperation.Cursor.decode(data)
        }
        return nil
    }
    
    func setQueryCursor(_ cursor: CKQueryOperation.Cursor, type: RecordType, zoneID: CKRecordZone.ID) {
        let key = CursorKey(type: type).rawValue
        var zonesMap = self.store.dictionary(forKey: key) ?? [:]
        zonesMap[zoneID.zoneName] = cursor.encode()
        self.store.set(zonesMap, forKey: key)
    }
    
    func removeQueryCursor(for type: RecordType) {
        self.store.removeObject(forKey: CursorKey(type: type).rawValue)
    }
    
    func removeQueryCursor(for type: RecordType, zoneID: CKRecordZone.ID) {
        let key = CursorKey(type: type).rawValue
        var zonesMap = self.store.dictionary(forKey: key) ?? [:]
        zonesMap.removeValue(forKey: zoneID.zoneName)
        self.store.set(zonesMap, forKey: key)
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
        case .zone:
            return nil
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
        case .zone:
            break
        }
    }
    
    func addSyncOpToLocal(_ op: EACloudOperation) {
        if self.syncTimer == nil {
            self.syncTimer = DispatchSource.makeTimerSource()
            self.syncTimer?.schedule(deadline: .now() + .milliseconds(1500))
            self.syncTimer?.setEventHandler(handler: {
                var hm = self.getSyncOpFromLocal()
                let xs = hm.allValues()
                xs.forEach { data in
                    if let op = EACloudOperation.decode(data) {
                        op.completionHandler = self.syncFromCloudHandler(_:)
                        if self.opqueue.add(op) { hm.removeValue(forKey: op.getKey()) }
                    }
                }
                self.store.set(hm, forKey: self.syncRecordKey)
                if hm.count == 0 { self.syncTimer?.cancel(); self.syncTimer = nil }
            })
            self.syncTimer?.resume()
        }
        if var hm = self.store.dictionary(forKey: self.syncRecordKey) {
            let key = op.getKey()
            if hm[key] == nil, let data = op.encode() {
                hm[key] = data
                self.store.set(hm, forKey: self.syncRecordKey)
            }
        } else {
            self.store.set([op.getKey(): op.encode()], forKey: self.syncRecordKey)
        }
    }
    
    func getSyncOpFromLocal() -> [String: Data] {
        return self.store.dictionary(forKey: self.syncRecordKey) as? [String: Data] ?? [:]
    }
    
    func removeSyncRecordFromLocal(_ op: EACloudOperation) {
        if var hm = self.store.dictionary(forKey: self.syncRecordKey) {
            hm.removeValue(forKey: op.getKey())
            self.store.set(hm, forKey: self.syncRecordKey)
        }
    }
    
    // MARK: - Sync
    
    func syncFromCloud() {
        Log.debug("sync from cloud")
        self.queryDefaultZoneRecords(completion: self.syncFromCloudHandler(_:))
    }
    
    func setLastSyncTime() {
        self.store.set(Date().currentTimeNanos(), forKey: self.lastSyncTimeKey)
    }
    
    func getLastSyncTime() -> Int {
        return self.store.integer(forKey: self.lastSyncTimeKey)
    }
    
    func syncFromCloudHandler(_ result: Result<[CKRecord], Error>) {
        Log.debug("sync from cloud handler")
        switch result {
        case .success(let records):
            Log.debug("sync from cloud handler: records \(records.count)")
            records.forEach { record in _ = syncRecordFromCloudHandler(record) }
        case .failure(let error):
            Log.error("Error syncing from cloud: \(error)")
        }
    }
    
    func syncRecordFromCloudHandler(_ record: CKRecord) -> Bool {
        let modified = self.isSyncedOnce() ? self.previousSyncTime : 0
        switch RecordType(rawValue: record.type()) {
        case .zone:
            fallthrough
        case .workspace:
            self.updateWorkspaceFromCloud(record)
            let wsId = record.id()
            let op = EACloudOperation(recordType: .project, opType: .queryRecord, zoneID: self.ck.zoneID(workspaceId: wsId), parentId: wsId, modified: modified, completion: self.syncFromCloudHandler(_:))
            op.completionBlock = { Log.debug("op completion: - query project") }
            if !self.opqueue.add(op) { self.addSyncOpToLocal(op); return false }
            return true
        case .project:
            self.updateProjectFromCloud(record)
            let zoneID = record.zoneID()
            let projId = record.id()
            var status = true
            let opreq = EACloudOperation(recordType: .request, opType: .queryRecord, zoneID: zoneID, parentId: projId, modified: modified, completion: self.syncFromCloudHandler(_:))
            opreq.completionBlock = { Log.debug("op completion: - query request") }
            if !self.opqueue.add(opreq) { self.addSyncOpToLocal(opreq); status = false }
            let opreqmeth = EACloudOperation(recordType: .requestMethodData, opType: .queryRecord, zoneID: zoneID, parentId: projId, modified: modified, completion: self.syncFromCloudHandler(_:))
            opreqmeth.completionBlock = { Log.debug("op completion: - query request method") }
            if !self.opqueue.add(opreqmeth) { self.addSyncOpToLocal(opreqmeth); status = false }
            return status
        case .request:
            self.updateRequestFromCloud(record)
            let zoneID = record.zoneID()
            let reqId = record.id()
            var status = false
            let opreq = EACloudOperation(recordType: .requestData, opType: .queryRecord, zoneID: zoneID, parentId: reqId, modified: modified, completion: self.syncFromCloudHandler(_:))
            opreq.completionBlock = { Log.debug("op completion: - query request") }
            if !self.opqueue.add(opreq) { self.addSyncOpToLocal(opreq); status = false }
            let opreqbody = EACloudOperation(recordType: .requestBodyData, opType: .queryRecord, zoneID: zoneID, parentId: reqId, modified: modified, completion: self.syncFromCloudHandler(_:))
            opreqbody.completionBlock = { Log.debug("op completion: - query request method") }
            if !self.opqueue.add(opreqbody) { self.addSyncOpToLocal(opreqbody); status = false }
            return status
        case .requestBodyData:
            self.updateRequestBodyDataFromCloud(record)
            let op = EACloudOperation(recordType: .requestData, opType: .queryRecord, zoneID: record.zoneID(), parentId: record.id(), modified: modified, completion: self.syncFromCloudHandler(_:))
            op.completionBlock = { Log.debug("op completion: - query request data") }
            if !self.opqueue.add(op) { self.addSyncOpToLocal(op); return false }
            return true
        case .requestData:
            self.updateRequestDataFromCloud(record)
            let zoneID = record.zoneID()
            let reqDataId = record.id()
            var status = false
            let opreq = EACloudOperation(recordType: .file, opType: .queryRecord, zoneID: zoneID, parentId: reqDataId, modified: modified, completion: self.syncFromCloudHandler(_:))
            opreq.completionBlock = { Log.debug("op completion: - query file") }
            if !self.opqueue.add(opreq) { self.addSyncOpToLocal(opreq); status = false }
            let opreqbody = EACloudOperation(recordType: .image, opType: .queryRecord, zoneID: zoneID, parentId: reqDataId, modified: modified, completion: self.syncFromCloudHandler(_:))
            opreqbody.completionBlock = { Log.debug("op completion: - query image") }
            if !self.opqueue.add(opreqbody) { self.addSyncOpToLocal(opreqbody); status = false }
            return status
        case .requestMethodData:
            self.updateRequestMethodDataFromCloud(record)
        case .file:
            self.updateFileDataFromCloud(record)
        case .image:
            self.updateImageDataFromCloud(record)
        case .none:
            Log.error("Unknown record: \(record)")
        }
        return true
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
        case .zone:
            return SubscriptionId.zoneChange.rawValue
        }
    }
    
    // MARK: - Cloud record merge (conflict)
    
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
        case .zone:
            return server
        }
    }
    
    // MARK: - Cloud record updated
    
    func updateWorkspaceFromCloud(_ record: CKRecord) {
        let wsId = record.id()
        let ctx = self.localdb.getChildMOC()
        var aws = self.localdb.getWorkspace(id: wsId, ctx: ctx)
        var isNew = false
        if aws == nil {
            aws = self.localdb.createWorkspace(id: wsId, index: record.index().toInt(), name: record.name(), desc: record.desc(), isSyncEnabled: record.isSyncEnabled(), ctx: ctx)
            isNew = true
        }
        guard let ws = aws else { return }
        if isNew || (ws.isSyncEnabled && (!ws.isActive || ws.modified <= record.modified())) {  // => server has new copy
            ws.updateFromCKRecord(record)
            ws.isSynced = true
            ws.isActive = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Workspace synced")
            self.nc.post(Notification(name: NotificationKey.workspaceDidSync))
        }
    }
    
    func updateProjectFromCloud(_ record: CKRecord) {
        let projId = record.id()
        let ctx = self.localdb.getChildMOC()
        var aproj = self.localdb.getProject(id: projId, ctx: ctx)
        var isNew = false
        if aproj == nil {
            aproj = self.localdb.createProject(id: record.id(), index: record.index().toInt(), name: record.name(), desc: record.desc(), checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let proj = aproj else { return }
        if isNew || proj.modified <= record.modified() {  // => server has new copy
            proj.updateFromCKRecord(record, ctx: ctx)
            proj.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Project synced")
            self.nc.post(Notification(name: NotificationKey.projectDidSync))
        }
    }
    
    func updateRequestFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        guard let proj = ERequest.getProject(record, ctx: ctx) else { Log.error("Error getting project"); return }
        let reqId = record.id()
        var areq = self.localdb.getRequest(id: reqId, ctx: ctx)
        var isNew = false
        if areq == nil {
            areq = self.localdb.createRequest(id: record.id(), index: record.index().toInt(), name: record.name(), project: proj, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let req = areq else { return }
        if isNew || req.modified <= record.modified() {  // => server has new copy
            req.updateFromCKRecord(record, ctx: ctx)
            req.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request synced")
            self.nc.post(Notification(name: NotificationKey.requestDidSync))
        }
    }
        
    func updateRequestBodyDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let reqId = record.id()
        var aReqBodyData = self.localdb.getRequestBodyData(id: reqId, ctx: ctx)
        var isNew = false
        if aReqBodyData == nil {
            aReqBodyData = self.localdb.createRequestBodyData(id: record.id(), index: record.index().toInt(), checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let reqBodyData = aReqBodyData else { return }
        if isNew || reqBodyData.modified <= record.modified() {  // => server has new copy
            reqBodyData.updateFromCKRecord(record, ctx: ctx)
            reqBodyData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request synced")
            self.nc.post(Notification(name: NotificationKey.requestBodyDataDidSync))
        }
    }
    
    func updateRequestDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        guard let type = ERequestData.getRecordType(record) else { return }
        let fieldType = ERequestData.getFormFieldFormatType(record)
        let reqId = record.id()
        var aData = self.localdb.getRequestData(id: reqId, ctx: ctx)
        var isNew = false
        if aData == nil {
            aData = self.localdb.createRequestData(id: reqId, index: record.index().toInt(), type: type, fieldFormat: fieldType, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let reqData = aData else { return }
        if isNew || reqData.modified <= record.modified() {  // => server has new copy
            reqData.updateFromCKRecord(record, ctx: ctx)
            reqData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request data synced")
            self.nc.post(Notification(name: NotificationKey.requestDataDidSync))
        }
    }
    
    func updateRequestMethodDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let reqMethodDataId = record.id()
        var aReqMethodData = self.localdb.getRequestMethodData(id: reqMethodDataId, ctx: ctx)
        var isNew = false
        if aReqMethodData == nil {
            aReqMethodData = self.localdb.createRequestMethodData(id: reqMethodDataId, index: record.index().toInt(), name: record.name(), isCustom: true, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let reqMethodData = aReqMethodData else { return }
        if isNew || reqMethodData.modified <= record.modified() {  // => server has new copy
            reqMethodData.updateFromCKRecord(record, ctx: ctx)
            reqMethodData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Request method data synced")
            self.nc.post(Notification(name: NotificationKey.requestMethodDataDidSync))
        }
    }
    
    func updateFileDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let fileId = record.id()
        var aFileData = self.localdb.getFileData(id: fileId, ctx: ctx)
        var isNew = false
        if aFileData == nil {
            aFileData = self.localdb.createFile(data: Data(), index: record.index().toInt(), name: record.name(), path: URL(fileURLWithPath: "/tmp/"), checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let fileData = aFileData else { return }
        if isNew || fileData.modified <= record.modified() {  // => server has new copy
            fileData.updateFromCKRecord(record, ctx: ctx)
            fileData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("File data synced")
            self.nc.post(Notification(name: NotificationKey.fileDataDidSync))
        }
    }
    
    func updateImageDataFromCloud(_ record: CKRecord) {
        let ctx = self.localdb.getChildMOC()
        let fileId = record.id()
        var aImageData = self.localdb.getImageData(id: fileId, ctx: ctx)
        var isNew = false
        if aImageData == nil {
            aImageData = self.localdb.createImage(data: Data(), name: record.name(), index: record.index().toInt(), type: ImageType.jpeg.rawValue, checkExists: false, ctx: ctx)
            isNew = true
        }
        guard let imageData = aImageData else { return }
        if isNew || imageData.modified <= record.modified() {  // => server has new copy
            imageData.updateFromCKRecord(record, ctx: ctx)
            imageData.isSynced = true
            self.localdb.saveChildContext(ctx)
            Log.debug("Image data synced")
            self.nc.post(Notification(name: NotificationKey.imageDataDidSync))
        }
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
        case .zone:
            self.updateWorkspaceFromCloud(record)
        case .none:
            Log.error("Unknown record: \(record)")
        }
    }
    
    // MARK: - Cloud record deleted
    
    func workspaceDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteWorkspace(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func projectDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteProject(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func requestDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequest(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
        
    func requestBodyDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequestBodyData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func requestDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequestData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func requestMethodDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteRequestMethodData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func fileDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteFileData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func imageDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.localdb.getChildMOC()
        self.localdb.deleteImageData(id: id, ctx: ctx)
        self.localdb.saveChildContext(ctx)
    }
    
    func cloudRecordDidDelete(_ recordID: CKRecord.ID) {
        Log.debug("cloud record did delete: \(recordID)")
        let id = self.ck.entityID(recordID: recordID)
        let type = RecordType.from(id: id)
        switch type {
        case .workspace:
            self.workspaceDidDeleteFromCloud(id)
        case .project:
            self.projectDidDeleteFromCloud(id)
        case .request:
            self.requestDidDeleteFromCloud(id)
        case .requestBodyData:
            self.requestBodyDataDidDeleteFromCloud(id)
        case .requestData:
            self.requestDataDidDeleteFromCloud(id)
        case .requestMethodData:
            self.requestMethodDataDidDeleteFromCloud(id)
        case .file:
            self.fileDataDidDeleteFromCloud(id)
        case .image:
            self.imageDataDidDeleteFromCloud(id)
        case .zone:
            break
        case .none:
            Log.error("Unknown record type: \(id)")
        }
    }
    
    func cloudRecordsDidDelete(_ recordsIDs: [CKRecord.ID]) {
        recordsIDs.forEach { self.cloudRecordDidDelete($0) }
    }
    
    // MARK: - Query
    
    func queryDefaultZoneRecords(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("query default zone records")
        self.ck.queryRecords(zoneID: self.ck.defaultZoneID(), recordType: RecordType.zone.rawValue, predicate: NSPredicate(format: "isSyncEnabled == %hdd", true),
                             cursor: self.getCachedDefaultZoneQueryCursor(), limit: self.defaultZoneRecordFetchLimit) { [weak self] result in
            Log.debug("query default zone records handler")
            guard let self = self else { return }
            switch result {
            case .success(let (records, cursor)):
                self.setIsSyncedOnce()
                if let cursor = cursor { self.setDefaultZoneQueryCursorToCache(cursor) }
                self.previousSyncTime = self.getLastSyncTime()
                self.setLastSyncTime()
                completion(.success(records))
            case .failure(let error):
                Log.error("Error querying default zone record: \(error)")
                completion(.failure(error))
                break
            }
        }
    }
    
    /// Fetch records belonging to the given record type with id in the given zone.
    /// - Parameters:
    ///   - zoneID: The zone in which the record exists
    ///   - type: The record type
    ///   - parentId: The parent Id of the record which is used in predicate
    ///   - isContinue: Should continue from the previous cursor if exists. If set to false, the cursor will be removed from the cache.
    ///   - modified: The last sync time which is used to fetch records modified after that
    ///   - completion: The completion handler.
    func queryRecords(zoneID: CKRecordZone.ID, type: RecordType, parentId: String, predicate: NSPredicate? = nil, isContinue: Bool? = true, modified: Int? = 0, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("query records: \(zoneID), type: \(type), parentId: \(parentId) modified: \(modified ?? 0)")
        let modified = modified ?? 0
        let cursor: CKQueryOperation.Cursor? = self.getQueryCursor(type, zoneID: zoneID)
        let predicate: NSPredicate = {
            if predicate != nil { return predicate! }
            var pred: NSPredicate!
            switch type {
            case .workspace:
                pred = NSPredicate(format: "modified >= %ld", modified)
            case .project:
                pred = NSPredicate(format: "workspace == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .request:
                pred = NSPredicate(format: "project == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .requestBodyData:
                pred = NSPredicate(format: "request == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .requestData:
                [NSPredicate(format: "binary == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified),
                 NSPredicate(format: "form == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified),
                 NSPredicate(format: "header == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified),
                 NSPredicate(format: "image == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified),
                 NSPredicate(format: "multipart == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)].forEach { pred in
                    self.queryRecords(zoneID: zoneID, type: type, parentId: parentId, predicate: pred, isContinue: isContinue, completion: completion)
                }
                pred = NSPredicate(format: "param == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .requestMethodData:
                pred = NSPredicate(format: "project == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .file:
                pred = NSPredicate(format: "requestData == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .image:
                pred = NSPredicate(format: "requestData == %@ AND modified >= %ld", CKRecord.Reference(recordID: self.ck.recordID(entityId: parentId, zoneID: zoneID), action: .none), modified)
            case .zone:
                pred = NSPredicate(format: "isSyncEnabled == %hdd AND modified >= %ld", true, modified)
            }
            return pred
        }()
        self.ck.queryRecords(zoneID: zoneID, recordType: type.rawValue, predicate: predicate,
                             cursor: cursor, limit: self.defaultZoneRecordFetchLimit) { [weak self] result in
            self?.queryRecordsHandler(zoneID: zoneID, type: type, parentId: parentId, isContinue: isContinue, result: result, completion: completion)
        }
    }
    
    func queryRecordsHandler(zoneID: CKRecordZone.ID, type: RecordType, parentId: String, isContinue: Bool? = true, result: Result<(records: [CKRecord], cursor: CKQueryOperation.Cursor?), Error>, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        switch result {
        case .success(let (records, cursor)):
            if let cursor = cursor {
                self.setQueryCursor(cursor, type: type, zoneID: zoneID)
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    self.queryRecords(zoneID: zoneID, type: type, parentId: parentId, isContinue: isContinue, completion: completion)
                }
            } else {
                self.removeQueryCursor(for: type, zoneID: zoneID)
            }
            completion(.success(records))
        case .failure(let error):
            Log.error("Error querying records: \(error)")
            completion(.failure(error))
            break
        }
    }
    
    // MARK: - Fetch
    
    func fetchZoneChanges(zoneIDs: [CKRecordZone.ID], isDelayedFetch: Bool? = false) {
        Log.debug("fetching zone changes for zoneIDs: \(zoneIDs) - isDelayedFetch: \(isDelayedFetch ?? false)")
        if isDelayedFetch != nil, isDelayedFetch! {
            if self.fetchZoneChangesDelayTimer == nil {
                self.fetchZoneChangesDelayTimer = EARescheduler(interval: 4.0, type: .everyFn, limit: 4)
                Log.debug("Delayed fetch of zones initialised")
            }
            self.fetchZoneChangesDelayTimer.schedule(fn: EAReschedulerFn(id: "fetch-zone-changes", block: { [weak self] in
                guard let self = self else { return false }
                self.ck.fetchZoneChanges(zoneIDs: zoneIDs, completion: self.zoneChangeHandler(_:))
                Log.debug("Delayed exec - fetch zones")
                return true
            }, callback: { _ in
                self.fetchZoneChangesDelayTimer = nil
                Log.debug("Delayed fetch exec - done")
            }, args: []))
        } else {
            self.ck.fetchZoneChanges(zoneIDs: zoneIDs, completion: self.zoneChangeHandler(_:))
        }
    }
    
    func zoneChangeHandler(_ result: Result<(saved: [CKRecord], deleted: [CKRecord.ID]), Error>) {
        switch result {
        case .success(let (saved, deleted)):
            saved.forEach { record in self.cloudRecordDidChange(record) }
            deleted.forEach { record in self.cloudRecordDidDelete(record) }
        case .failure(let error):
            Log.error("Error getting zone changes: \(error)")
        }
    }
    
    /// Checks if the record is present in cache. If present, returns, else fetch from cloud, adds to the cache and returns.
    func fetchRecord(_ entity: Entity, type: RecordType, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let id = entity.getId()
        if let cached = self.getFromCache(entityId: id, type: type) as? CacheValue, let record = cached.value() as? CKRecord { completion(.success(record)); return }
        // Not in cache, fetch from cloud
        let recordID = self.ck.recordID(entityId: id, zoneID: entity.getZoneID())
        self.ck.fetchRecords(recordIDs: [recordID]) { [weak self] result in
            guard let self = self else { return }
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
        self.ck.fetchRecords(recordIDs: recordIDs) { [weak self] result in
            guard let self = self else { return }
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
    func fetchWorkspaces(zoneIDs: [CKRecordZone.ID], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        Log.debug("fetching workspaces")
        self.ck.fetchRecords(recordIDs: self.ck.recordIDs(zoneIDs: zoneIDs)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let hm):
                let records = hm.allValues()
                records.forEach { record in self.addToCache(record: record, entityId: record.id(), type: .workspace) }
                completion(.success(records))
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
        if !ws.isSyncEnabled { return }
        let wsId = ws.getId()
        let zoneID = ws.getZoneID()
        let recordID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
        let record = self.ck.createRecord(recordID: recordID, recordType: RecordType.workspace.rawValue)
        ws.updateCKRecord(record)
        let wsModel = DeferredSaveModel(record: record, entity: ws, id: wsId)
        let zoneModel = self.zoneDeferredSaveModel(ws: ws)
        self.saveToCloud([wsModel, zoneModel])
    }
    
    /// Save the given project and updates the associated workspace to the cloud.
    func saveProjectToCloud(_ proj: EProject) {
        guard let ws = proj.workspace else { Log.error("Workspace is empty for project"); return }
        if !ws.isSyncEnabled { return }
        let projId = proj.getId()
        let zoneID = proj.getZoneID()
        let recordID = self.ck.recordID(entityId: projId, zoneID: zoneID)
        let ckproj = self.ck.createRecord(recordID: recordID, recordType: RecordType.project.rawValue)
        self.fetchRecord(ws, type: .workspace) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let ckws):
                self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws)
            case .failure(let error):
                Log.error("Error getting workspace from cloud: \(error)")
                if let err = error as? CKError {
                    if err.isZoneNotFound() {  // => workspace is not created
                        self.ck.createZone(recordZoneId: zoneID) { result in
                            switch result {
                            case .success(_):
                                let wsId = ws.getId()
                                let ckwsID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
                                let ckws = self.ck.createRecord(recordID: ckwsID, recordType: RecordType.workspace.rawValue)
                                ws.updateCKRecord(ckws)
                                self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws, isCreateZoneRecord: true)
                                //self.saveRecords(records, completion: completion)
                            case .failure(let error):
                                Log.error("Error creating zone: \(error)")
                            }
                        }
                    } else if err.isRecordNotFound() {
                        let ckws = self.ck.createRecord(recordID: self.ck.recordID(entityId: ws.getId(), zoneID: ckproj.zoneID()), recordType: RecordType.workspace.rawValue)
                        self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws)
                    }
                }
            }
        }
    }
    
    /// Save the given request and updates the associated project to the cloud.
    func saveRequestToCloud(_ req: ERequest) {
        if let ws = req.project?.workspace, !ws.isSyncEnabled { return }
        guard let reqId = req.id else { Log.error("ERequest id is nil"); return }
        guard let wsId = req.project?.workspace?.id else { Log.error("Error getting workspace id"); return }
        guard let projId = req.project?.id else { Log.error("Error getting project id"); return }
        guard let proj = self.localdb.getProject(id: projId) else { Log.error("Error getting project"); return }
        let zoneID = self.ck.zoneID(workspaceId: wsId)
        let ckReqID = self.ck.recordID(entityId: reqId, zoneID: zoneID)
        let ckreq = self.ck.createRecord(recordID: ckReqID, recordType: req.recordType)
        self.fetchRecord(proj, type: .project) { [weak self] result in
            guard let self = self else { return }
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
    
    func zoneDeferredSaveModel(ws: EWorkspace) -> DeferredSaveModel {
        let wsId = ws.getId()
        let zone = Zone(id: wsId, name: ws.getName(), desc: ws.desc ?? "", isSyncEnabled: ws.isSyncEnabled, created: ws.created, modified: ws.modified, version: ws.version)
        let recordID = self.ck.recordID(entityId: wsId, zoneID: self.ck.defaultZoneID())
        let ckzn = self.ck.createRecord(recordID: recordID, recordType: RecordType.zone.rawValue)
        zone.updateCKRecord(ckzn)
        return DeferredSaveModel(record: ckzn, id: ws.getId())
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveProjectToCloudImp(ckproj: CKRecord, proj: EProject, ckws: CKRecord, ws: EWorkspace, isCreateZoneRecord: Bool? = false) {
        proj.updateCKRecord(ckproj, workspace: ckws)
        let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
        let wsModel = DeferredSaveModel(record: ckws, entity: ws, id: ws.getId())
        if let createZoneRecord = isCreateZoneRecord, createZoneRecord {
            self.saveToCloud([projModel, wsModel, self.zoneDeferredSaveModel(ws: ws)])
        } else {
            self.saveToCloud([projModel, wsModel])
        }
        // TODO: subscribe to project change
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveRequestToCloudImp(ckreq: CKRecord, req: ERequest, ckproj: CKRecord, proj: EProject) {
        var acc: [DeferredSaveModel] = []
        let zoneID = ckreq.zoneID()
        req.updateCKRecord(ckreq, project: ckproj)
        //EProject.addRequestReference(to: ckproj, request: ckreq)
        let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
        let reqModel = DeferredSaveModel(record: ckreq, entity: req, id: req.getId())
        acc.append(contentsOf: [projModel, reqModel])
        if let set = req.headers, let xs = set.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.isSynced {
                    let hdrecord = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    reqData.updateCKRecord(hdrecord)
                    ERequestData.addRequestReference(ckreq, toheader: hdrecord)
                    acc.append(DeferredSaveModel(record: hdrecord, id: reqData.getId()))
                }
            }
        }
        if let set = req.params, let xs = set.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.isSynced {
                    let paramrecord = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    reqData.updateCKRecord(paramrecord)
                    ERequestData.addRequestReference(ckreq, toParam: paramrecord)
                    acc.append(DeferredSaveModel(record: paramrecord, id: reqData.getId()))
                }
            }
        }
        if let body = req.body {
            let ckbody = self.ck.createRecord(recordID: self.ck.recordID(entityId: body.getId(), zoneID: zoneID), recordType: RecordType.requestBodyData.rawValue)
            if !body.isSynced {
                body.updateCKRecord(ckbody, request: ckreq)
                acc.append(DeferredSaveModel(record: ckbody, id: ckbody.id()))
            }
            if let binary = body.binary {
                let ckbin = self.ck.createRecord(recordID: self.ck.recordID(entityId: binary.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                if let files = binary.files?.allObjects as? [EFile] {
                    files.forEach { file in
                        if !file.isSynced {
                            let ckfile = self.ck.createRecord(recordID: self.ck.recordID(entityId: file.getId(), zoneID: zoneID), recordType: RecordType.file.rawValue)
                            file.updateCKRecord(ckfile)
                            EFile.addRequestDataReference(ckfile, reqData: ckbin)
                            acc.append(DeferredSaveModel(record: ckfile, id: ckfile.id()))
                        }
                    }
                }
                if let image = binary.image, !image.isSynced {
                    let ckimage = self.ck.createRecord(recordID: self.ck.recordID(entityId: image.getId(), zoneID: zoneID), recordType: RecordType.image.rawValue)
                    image.updateCKRecord(ckimage)
                    EImage.addRequestDataReference(ckbin, image: ckimage)
                    acc.append(DeferredSaveModel(record: ckimage, id: ckimage.id()))
                }
                if !binary.isSynced {
                    binary.updateCKRecord(ckbin)
                    ERequestData.addRequestBodyDataReference(ckbody, toBinary: ckbin)
                    acc.append(DeferredSaveModel(record: ckbin, id: ckbin.id()))
                }
            }
            if let forms = body.form?.allObjects as? [ERequestData] {
                forms.forEach { reqData in
                    let ckform = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    if !reqData.isSynced {
                        reqData.updateCKRecord(ckform)
                        ERequestData.addRequestBodyDataReference(ckbody, toForm: ckform, type: .form)
                        acc.append(DeferredSaveModel(record: ckform, id: ckform.id()))
                    }
                    if let files = reqData.files?.allObjects as? [EFile] {
                        files.forEach { file in
                            if !file.isSynced {
                                let ckfile = self.ck.createRecord(recordID: self.ck.recordID(entityId: file.getId(), zoneID: zoneID), recordType: RecordType.file.rawValue)
                                file.updateCKRecord(ckfile)
                                EFile.addRequestDataReference(ckfile, reqData: ckform)
                                acc.append(DeferredSaveModel(record: ckfile, id: ckfile.id()))
                            }
                        }
                    }
                    if let image = reqData.image, !image.isSynced {
                        let ckimage = self.ck.createRecord(recordID: self.ck.recordID(entityId: image.getId(), zoneID: zoneID), recordType: RecordType.image.rawValue)
                        image.updateCKRecord(ckimage)
                        EImage.addRequestDataReference(ckform, image: ckimage)
                        acc.append(DeferredSaveModel(record: ckimage, id: ckimage.id()))
                    }
                }
            }
            if let multipart = body.multipart?.allObjects as? [ERequestData] {
                multipart.forEach { reqData in
                    if !reqData.isSynced {
                        let ckmpart = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                        reqData.updateCKRecord(ckmpart)
                        ERequestData.addRequestBodyDataReference(ckbody, toForm: ckmpart, type: .multipart)
                        acc.append(DeferredSaveModel(record: ckmpart, id: ckmpart.id()))
                    }
                }
            }
        }
        self.saveToCloud(acc)  // we need to save this in the same request so that the deps are created and referrenced properly.
        // TODO: subscribe to request change
    }
    
    /*
     
     1. Check if CKRecord is present in cache. If present, return, else fetch from cloud, add to cache, return
     2. If when saving, the server updated error is given, resolve conflict, save record, add to cache.
     3. Maintain separate cache for each entity type: workspace, project, request
     4. Cache size:
     
     */
}
